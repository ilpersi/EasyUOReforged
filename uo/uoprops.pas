unit uoprops;
{ Port addition (scanprops, 2026-11-27): item tooltip text rebuilt from the client's property cache.

  `event property` asks the client for one item's tooltip per call: a code cave the client runs on its
  next main-loop pass, then up to a hundred 30 ms polls (~50-75 ms per item measured). The client
  already keeps every tooltip it has fetched in a cache (C_PROPCACHE), as cliloc numbers plus their
  argument text, and formats it only when it shows it. This unit does that formatting in Reforged, so
  `scanprops` reads all the items of a `finditem` from the cache with plain memory reads.

  The formatter is a port of client.exe 7.0.118.46's code, identical in 7.0.108.0, 7.0.117.33 and the
  betas 7.0.117.31 / 7.0.118.132 / 7.0.119.0 (the betas add the coin plural step); the addresses below
  are 7.0.118.46's. Compared byte for byte with the client's own text: 48/48 items there, 41/41 on the
  beta 7.0.119.0, 1,682/1,682 objects on a live shard (7.0.108.0). Older fixed-base builds differ a
  little (7.0.29.97 and 7.0.45.89 don't capitalise after '>'); the owner chose to apply this logic to
  them too. Left out on purpose (owner's choices): the client's word filter (0x5C8EA0), which masks
  words in player-written text; and the English-tooltips option (flag 0xA5D73E, template 0x5906F0).
  docs/property-cache-analysis.md has every finding.

    0x58B660 ItemName / 0x58B560 ItemProperties (E_ITEMNAMEADDR / E_ITEMPROPADDR)
    0x43F260 name builder (the first line), 0x43F530 properties builder (the others, <BR> between)
    0x58E7C0 -> 0x58E570 template: the cliloc text, or the two MegaCliloc error texts
    0x5907B0 filler, 0x590BD0 its argument splitter, 0x58C5F0 the ids whose '#' arguments stay literal
    0x5FDE40 title case, 0x5F6620 the client's UTF-8 reader, 0x5F69D0 wtoi
    beta 7.0.119.0: 0x426910 coin plural

  TPropFormatter and the helpers touch no process (unit tested on a fake cliloc table); PropScan runs
  the whole scan against a TPropSource, which uopropscan.pas implements on a live client. }

{$mode delphi}{$H+}

interface

uses SysUtils, Classes, Generics.Collections;

type
  TPropLine = record
    Cl   : Integer;            // the line's cliloc number
    Args : UnicodeString;      // its arguments, tab separated (empty: none)
  end;
  TPropLines = array of TPropLine;
  TPropIDs = array of Cardinal;
  TPropArgs = array of UnicodeString;

  // What the cache holds for an item: nothing usable (no entry, an empty one, or a read that failed),
  // a tooltip the server announced and the client hasn't fetched yet, or the tooltip's lines.
  TPropEntryState = (pesNone, pesAnnounced, pesFetched);

  // A cliloc's text: 0 = no such cliloc, 1 = the cliloc exists with no text, 2 = Text holds its bytes
  // (UTF-8, as the client keeps them).
  TPropClilocLookup = function(ID : Integer; out Text : RawByteString) : Integer of object;

  TPropFormatter = class(TObject)
  private
    FLookup    : TPropClilocLookup;
    FTemplates : TDictionary<Integer,UnicodeString>;
    function   Template(Cl : Integer) : UnicodeString;
    function   Fill(const T, Args : UnicodeString; Cl : Integer) : UnicodeString;
  public
    CoinPlural : Boolean;      // the betas' coin name step
    constructor Create(Lookup : TPropClilocLookup; ACoinPlural : Boolean);
    destructor Destroy; override;
    procedure  ClearTemplates;
    // The client's two strings: the name (first line) and the properties (<BR> between lines).
    procedure  FormatLines(const L : TPropLines; out Name, Props : UnicodeString);
    // What `event property` makes of them: #Property's text, one byte per letter (Latin-1).
    function   PropertyText(const L : TPropLines) : String;
  end;

  // Where PropScan gets its data (a live client in uopropscan.pas, a fake one in the tests).
  TPropSource = class(TObject)
  public
    function  Supported : Boolean; virtual; abstract;
    function  ReadEntry(ID : Cardinal; out Lines : TPropLines) : TPropEntryState; virtual; abstract;
    // Ask the server for these items' tooltips; False when the request could not be made.
    function  Request(const IDs : TPropIDs) : Boolean; virtual; abstract;
    // event property's #Property text for one item; False when there is no such fallback (the
    // caller stores '$', what event property gives for an item it gets no answer for).
    function  Fallback(ID : Cardinal; out Text : String) : Boolean; virtual; abstract;
    function  Lookup(ID : Integer; out Text : RawByteString) : Integer; virtual; abstract;
    function  CoinPlural : Boolean; virtual; abstract;
    function  NowMs : QWord; virtual;
    // Wait Ms; False when the script was stopped meanwhile.
    function  Pause(Ms : Cardinal) : Boolean; virtual;
  end;

  // Stored #FindProp texts by item ID (Latin-1, #Property's format).
  TPropStore = TDictionary<Cardinal,String>;

const
  PROP_POLL_MS  = 50;          // how often the waiting items are read again
  PROP_IDLE_MS  = 1000;        // the wait ends after this long with no new answer...
  PROP_IDLE_NONE_MS = 500;     // ...or this long once only items with no cache entry are left (the shard
                               // never answers for an object without properties: live, 2 in 1,175)
  PROP_CAP_MS   = 15000;       // ...and after this long in any case
  PROP_TEXT_MAX = 4000;        // GetFormStr reads 4000 UTF-16 units of a client string

// The pieces, for the tests.
function  PropClientUtf8(const S : RawByteString) : UnicodeString;
function  PropWToI(const S : UnicodeString; From : Integer) : Integer;
function  PropNoLookup(Cl : Integer) : Boolean;
procedure PropSplitArgs(const A : UnicodeString; out Argv : TPropArgs);
function  PropTitleCase(const S : UnicodeString) : UnicodeString;
function  PropCoinPlural(Cl : Integer; const A : UnicodeString) : UnicodeString;
// TUOEvent.GetFormStr's rules on a client string; then #Property's joining of the two.
function  PropFormStr(const W : UnicodeString) : String;
function  PropJoin(const S1, S2 : String) : String;

// Fill Store with the tooltip text of every item of IDs (Store is cleared first). Fetched entries are
// formatted at once; the others are requested from the server in one go and read again every
// PROP_POLL_MS while answers keep coming (PROP_IDLE_MS without one, PROP_IDLE_NONE_MS when only items
// with no entry are left, or PROP_CAP_MS in all, ends the wait). Announced items still waiting then store the lines they still have, or '$'; items with no
// entry go to Src.Fallback. With an unsupported source every item goes to Src.Fallback.
procedure PropScan(Src : TPropSource; const IDs : TPropIDs; Store : TPropStore);

implementation

uses Windows;

////////////////////////////////////////////////////////////////////////////////
function TPropSource.NowMs : QWord;
begin
  Result:=GetTickCount64;
end;

function TPropSource.Pause(Ms : Cardinal) : Boolean;
begin
  Sleep(Ms);
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
// 0x5F6620: the client's UTF-8 reader. No validation; at most $3FFE characters.
function PropClientUtf8(const S : RawByteString) : UnicodeString;
var
  I, N, B : Integer;
  C       : Word;

  function At(K : Integer) : Integer;
  begin
    if K<=Length(S) then Result:=Ord(S[K]) else Result:=0;
  end;

begin
  SetLength(Result,Length(S));
  N:=0;
  I:=1;
  while (I<=Length(S)) and (N<$3FFE) do
  begin
    B:=Ord(S[I]);
    if B<$80 then
    begin
      C:=B;
      Inc(I);
    end
    else if B<$E0 then
    begin
      C:=Word((B-$C0)*$40) or Word(At(I+1)-$80);
      Inc(I,2);
    end
    else begin
      C:=Word(B shl 12) or Word((At(I+1)-$80)*$40) or Word(At(I+2)-$80);
      Inc(I,3);
    end;
    Inc(N);
    Result[N]:=WideChar(C);
  end;
  SetLength(Result,N);
end;

////////////////////////////////////////////////////////////////////////////////
// 0x5F69D0: digits from From on; '-' flips the sign and '+' is skipped wherever they come.
function PropWToI(const S : UnicodeString; From : Integer) : Integer;
var
  I, Sg, V : Integer;
  C        : WideChar;
begin
  V:=0;
  Sg:=1;
  I:=From;
  while I<=Length(S) do
  begin
    C:=S[I];
    if C='-' then Sg:=-Sg
    else if (C>='0') and (C<='9') then V:=V*10+Ord(C)-48
    else if C<>'+' then Break;
    Inc(I);
  end;
  Result:=Sg*V;
end;

////////////////////////////////////////////////////////////////////////////////
// 0x58C5F0: the clilocs whose '#' arguments stay literal text.
function PropNoLookup(Cl : Integer) : Boolean;
begin
  case Cl of
    $FE441, $FE465, $FE4C1, $FEB69, $FF78E, $1005BD, $102FC2, $102FC4..$102FC6, $1030F8, $103307,
    $103631, $103634..$103636, $103651, $103662, $105682, $105CB1 : Result:=True;
  else Result:=False;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// 0x590BD0: tab separated arguments; a trailing tab adds no empty one, an empty text gives one.
procedure PropSplitArgs(const A : UnicodeString; out Argv : TPropArgs);
var
  I, S : Integer;
begin
  SetLength(Argv,0);
  S:=1;
  for I:=1 to Length(A) do
    if A[I]=#9 then
    begin
      SetLength(Argv,Length(Argv)+1);
      Argv[High(Argv)]:=Copy(A,S,I-S);
      S:=I+1;
    end;
  if S<=Length(A) then
  begin
    SetLength(Argv,Length(Argv)+1);
    Argv[High(Argv)]:=Copy(A,S,MaxInt);
  end
  else if Length(Argv)=0 then
  begin
    SetLength(Argv,1);
    Argv[0]:='';
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// 0x5FDE40: ASCII upper case for the first letter and every letter after ' ', '-', LF, '[' or '>'.
function PropTitleCase(const S : UnicodeString) : UnicodeString;
var
  I : Integer;
begin
  Result:=S;
  for I:=1 to Length(Result) do
    if (I=1) or (Result[I-1]=' ') or (Result[I-1]='-') or (Result[I-1]=#10) or
       (Result[I-1]='[') or (Result[I-1]='>') then
      if (Result[I]>='a') and (Result[I]<='z') then Result[I]:=WideChar(Ord(Result[I])-32);
end;

////////////////////////////////////////////////////////////////////////////////
// Beta 0x426910: for coins (graphics $28E, $EED, $EF0 in a 1050039 name) the name cliloc after the
// tab becomes +1 for an amount of 2-5 and +2 above 5. The amount is the first argument; digits right
// after the replaced number are dropped.
function PropCoinPlural(Cl : Integer; const A : UnicodeString) : UnicodeString;
var
  T, N, Amt, P, Add, G : Integer;
begin
  Result:=A;
  if Cl<>$1005B7 then Exit;
  T:=Pos(#9,A);
  if (T=0) or (T+1>Length(A)) or (A[T+1]<>'#') then Exit;
  N:=PropWToI(A,T+2);
  G:=N-$F9060;
  if (G<0) or (G>$3FFF) then Exit;
  if not ((G=$28E) or (G=$EED) or (G=$EF0)) then Exit;
  Amt:=PropWToI(A,1);
  if Amt<=1 then Exit;
  if Amt>5 then Add:=2 else Add:=1;
  P:=T+2;
  while (P<=Length(A)) and (A[P]>='0') and (A[P]<='9') do Inc(P);
  Result:=Copy(A,1,T)+UnicodeString('#'+IntToStr(N+Add))+Copy(A,P,MaxInt);
end;

////////////////////////////////////////////////////////////////////////////////
// TUOEvent.GetFormStr on the client's string: the low byte of each of at most 4000 characters (a
// zero low byte ends it), control characters to spaces, <BR> to CRLF, then up to 500 <...> removed.
function PropFormStr(const W : UnicodeString) : String;
var
  I, C1, C2, N : Integer;
  S            : String;
begin
  S:='';
  for I:=1 to Length(W) do
  begin
    if I>PROP_TEXT_MAX then Break;
    if (Ord(W[I]) and $FF)=0 then Break;
    S:=S+Char(Ord(W[I]) and $FF);
  end;
  for I:=1 to Length(S) do
    if S[I]<#32 then S[I]:=' ';
  S:=StringReplace(S,'<BR>',#13#10,[rfReplaceAll]);
  for N:=1 to 500 do
  begin
    C1:=Pos('<',S);
    C2:=Pos('>',S);
    if (C1=0) or (C2=0) then Break;
    if C2<C1 then Break;                // Delete with a negative count: no change, ever again
    Delete(S,C1,C2-C1+1);
  end;
  Result:=S;
end;

////////////////////////////////////////////////////////////////////////////////
// #Property's joining (EuoInterpreter case 098, before its Latin-1 to UTF-8 step).
function PropJoin(const S1, S2 : String) : String;
begin
  Result:=S1+'$';
  if S2<>'' then Result:=Result+S2+'$';
  Result:=StringReplace(Result,#13#10,'$',[rfReplaceAll]);
end;

////////////////////////////////////////////////////////////////////////////////
constructor TPropFormatter.Create(Lookup : TPropClilocLookup; ACoinPlural : Boolean);
begin
  inherited Create;
  FLookup:=Lookup;
  CoinPlural:=ACoinPlural;
  FTemplates:=TDictionary<Integer,UnicodeString>.Create;
end;

destructor TPropFormatter.Destroy;
begin
  FTemplates.Free;
  inherited Destroy;
end;

procedure TPropFormatter.ClearTemplates;
begin
  FTemplates.Clear;
end;

////////////////////////////////////////////////////////////////////////////////
// 0x58E570: the cliloc's text, or the client's error texts (the id in decimal).
function TPropFormatter.Template(Cl : Integer) : UnicodeString;
var
  Raw : RawByteString;
  K   : Integer;
begin
  if FTemplates.TryGetValue(Cl,Result) then Exit;
  Raw:='';
  if Assigned(FLookup) then K:=FLookup(Cl,Raw) else K:=0;
  case K of
    0 : Result:='Error (MegaCliloc) : StringId Not Found : '+UnicodeString(IntToStr(Cl));
    1 : Result:='Error (MegaCliloc) : Null String : '+UnicodeString(IntToStr(Cl));
  else Result:=PropClientUtf8(Raw);
  end;
  FTemplates.Add(Cl,Result);
end;

////////////////////////////////////////////////////////////////////////////////
function ErrTok(const Msg : UnicodeString; N, Cl : Integer) : UnicodeString;
begin
  Result:=Msg+UnicodeString(IntToStr(N)+' : '+IntToStr(Cl));
end;

// 0x5907B0: ~N_name~ is argument N (a '#id' argument becomes that cliloc's text, unless Cl keeps them
// literal); ~#id~ is that cliloc's text. Only ids 500000-1999999 are looked up, without filling them in
// turn. An escaped \~ appends 126 (the client appends the character's number in decimal). A bad token
// makes the whole line the client's error text.
function TPropFormatter.Fill(const T, Args : UnicodeString; Cl : Integer) : UnicodeString;
var
  Argv        : TPropArgs;
  I, J, K, N  : Integer;
  Piece       : UnicodeString;
  NoLook      : Boolean;
begin
  PropSplitArgs(Args,Argv);
  NoLook:=PropNoLookup(Cl);
  Result:='';
  I:=1;
  while I<=Length(T) do
  begin
    if T[I]='~' then
    begin
      if (I=1) or (T[I-1]<>'\') then
      begin
        J:=I+1;
        if (J<=Length(T)) and (T[J]='#') then
        begin
          J:=I+2;
          N:=PropWToI(T,J);
          if Cardinal(N-500000)<1500000 then Piece:=Template(N)
          else Exit(ErrTok('Error (TID): Token Out of Range : ',N,Cl));
        end
        else begin
          N:=PropWToI(T,J);
          if (N<1) or (N>Length(Argv)) then Exit(ErrTok('Error (TID): Token Out of Range : ',N,Cl));
          Piece:=Argv[N-1];
          if (Length(Piece)>0) and (Piece[1]='#') and not NoLook then
          begin
            N:=PropWToI(Piece,2);
            if Cardinal(N-500000)<1500000 then Piece:=Template(N)
            else Exit(ErrTok('Error (TID): Provided Token Out of Range : ',N,Cl));
          end;
        end;
        Result:=Result+Piece;
        K:=J+1;
        while (K<=Length(T)) and (T[K]<>'~') do Inc(K);
        I:=K;
      end
      else Result:=Result+'126';
    end
    else Result:=Result+T[I];
    Inc(I);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// 0x43F260 (the name: the first line) and 0x43F530 (the properties: the others, <BR> between). A
// 1076226 line is the cliloc its first argument names; 1062613, 1080418 and 1159561 get colour tags
// (GetFormStr removes them again), and 1062613 keeps its own casing.
procedure TPropFormatter.FormatLines(const L : TPropLines; out Name, Props : UnicodeString);
var
  I, Cl     : Integer;
  S, A      : UnicodeString;
  Argv      : TPropArgs;
  Rewritten : Boolean;
begin
  Name:='';
  Props:='';
  if Length(L)=0 then Exit;
  S:=Template(L[0].Cl);
  if L[0].Args<>'' then
  begin
    A:=L[0].Args;
    if CoinPlural then A:=PropCoinPlural(L[0].Cl,A);
    S:=Fill(S,A,L[0].Cl);
  end;
  Name:=PropTitleCase(S);
  for I:=1 to High(L) do
  begin
    Cl:=L[I].Cl;
    Rewritten:=False;
    if Cl=$106C02 then
    begin
      PropSplitArgs(L[I].Args,Argv);
      Cl:=PropWToI(Argv[0],1);
      Rewritten:=True;
    end;
    S:=Template(Cl);
    if L[I].Args<>'' then S:=Fill(S,L[I].Args,Cl);
    if Rewritten or (Cl<>$1036D5) then S:=PropTitleCase(S);
    if Cl=$1036D5 then S:='<BASEFONT COLOR=#FFCC33>'+S+'<BASEFONT COLOR=#FFFFFF>'
    else if Cl=$107C62 then S:='<BASEFONT COLOR=#40A4FE>'+S+'<BASEFONT COLOR=#FFFFFF>'
    else if Cl=$11B189 then S:='<BASEFONT COLOR=#b66dff>'+S+'<BASEFONT COLOR=#FFFFFF>';
    Props:=Props+S;
    if I<High(L) then Props:=Props+'<BR>';
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// EvProperty keeps the properties only when the name is not empty.
function TPropFormatter.PropertyText(const L : TPropLines) : String;
var
  N, P   : UnicodeString;
  S1, S2 : String;
begin
  FormatLines(L,N,P);
  S1:=PropFormStr(N);
  S2:='';
  if S1<>'' then S2:=PropFormStr(P);
  Result:=PropJoin(S1,S2);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PropScan(Src : TPropSource; const IDs : TPropIDs; Store : TPropStore);
var
  Fmt      : TPropFormatter;
  Waiting  : TPropIDs;
  Kinds    : array of TPropEntryState;
  Stale    : array of TPropLines;     // an announced entry's lines (the betas keep the old ones)
  L        : TPropLines;
  St       : TPropEntryState;
  I, N     : Integer;
  Txt      : String;
  Start,
  LastNew  : QWord;
  Idle     : QWord;
  Seen     : TDictionary<Cardinal,Boolean>;

  procedure Drop(K : Integer);
  begin
    Waiting[K]:=Waiting[High(Waiting)];
    Kinds[K]:=Kinds[High(Kinds)];
    Stale[K]:=Stale[High(Stale)];
    SetLength(Waiting,Length(Waiting)-1);
    SetLength(Kinds,Length(Kinds)-1);
    SetLength(Stale,Length(Stale)-1);
  end;

begin
  Store.Clear;
  if Length(IDs)=0 then Exit;
  if not Src.Supported then
  begin
    for I:=0 to High(IDs) do
      if not Store.ContainsKey(IDs[I]) then
      begin
        if not Src.Fallback(IDs[I],Txt) then Txt:='$';
        Store.AddOrSetValue(IDs[I],Txt);
      end;
    Exit;
  end;

  Fmt:=TPropFormatter.Create(Src.Lookup,Src.CoinPlural);
  Seen:=TDictionary<Cardinal,Boolean>.Create;
  try
    SetLength(Waiting,0);
    SetLength(Kinds,0);
    SetLength(Stale,0);
    for I:=0 to High(IDs) do
    begin
      if Seen.ContainsKey(IDs[I]) then Continue;
      Seen.Add(IDs[I],True);
      St:=Src.ReadEntry(IDs[I],L);
      if St=pesFetched then Store.AddOrSetValue(IDs[I],Fmt.PropertyText(L))
      else begin
        N:=Length(Waiting);
        SetLength(Waiting,N+1);
        SetLength(Kinds,N+1);
        SetLength(Stale,N+1);
        Waiting[N]:=IDs[I];
        Kinds[N]:=St;
        if St=pesAnnounced then Stale[N]:=L else SetLength(Stale[N],0);
      end;
    end;

    if (Length(Waiting)>0) and Src.Request(Waiting) then
    begin
      Start:=Src.NowMs;
      LastNew:=Start;
      while Length(Waiting)>0 do
      begin
        Idle:=PROP_IDLE_NONE_MS;
        for I:=0 to High(Kinds) do
          if Kinds[I]=pesAnnounced then
          begin
            Idle:=PROP_IDLE_MS;
            Break;
          end;
        if Src.NowMs-LastNew>=Idle then Break;
        if Src.NowMs-Start>=PROP_CAP_MS then Break;
        if not Src.Pause(PROP_POLL_MS) then Break;
        for I:=High(Waiting) downto 0 do
        begin
          St:=Src.ReadEntry(Waiting[I],L);
          if St=pesFetched then
          begin
            Store.AddOrSetValue(Waiting[I],Fmt.PropertyText(L));
            Drop(I);
            LastNew:=Src.NowMs;
          end
          else if St=pesAnnounced then
          begin
            Kinds[I]:=pesAnnounced;
            Stale[I]:=L;
          end;
        end;
      end;
    end;

    for I:=0 to High(Waiting) do
      if Kinds[I]=pesAnnounced then
      begin
        if Length(Stale[I])>0 then Store.AddOrSetValue(Waiting[I],Fmt.PropertyText(Stale[I]))
        else Store.AddOrSetValue(Waiting[I],'$');
      end
      else begin
        if not Src.Fallback(Waiting[I],Txt) then Txt:='$';
        Store.AddOrSetValue(Waiting[I],Txt);
      end;
  finally
    Seen.Free;
    Fmt.Free;
  end;
end;

end.
