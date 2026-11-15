unit uogumpreply;

{
  Port addition (exevent GumpReply, docs\gump-analysis.md section 11): answering a server gump the way a
  click on one of its buttons does. Shared by the interpreter and uo.dll. Everything but SendGumpReply
  needs no client, so the test suite pins it.

  What a click sends (docs\gump-analysis.md section 11): a $B1 packet with the gump's serial and type
  ID, the button, the IDs of the switches (checkboxes, radio buttons) that are on, and the text entries,
  each an ID and its text in UTF-16. Every number is big-endian. The length field after the opcode is
  written low byte first, the way every packet of uoevents.pas is and the client's own packet builder
  keeps it until the send function fixes it up (read in client.exe 7.0.118.46 and the beta). A text is
  cut at 239 characters, as the client cuts it.

  ModernUO accepts an answer only for a gump it has open with the same serial AND type ID, and the
  serial changes every time the server opens the gump. So the serial is never taken from a script or
  a snapshot: SendGumpReply looks the gump up in the client's list as it is now (TUOCmd.FindLiveGump)
  and reads it there. Then it answers it and closes the client's window in the same cave run, as the
  click path does (TUOEvent.ExEv_GumpReply), except for the type IDs $2410..$2462: for those OSI gumps
  the client keeps some windows open after some buttons, so Reforged leaves them all open.

  The answers a click sends are recorded by a hook on the client's send function (TUOEvent.GumpHookActive,
  which says how it stays safe); HookedReply reads the last one it kept and decodes it here. A host
  installs the hook on first use: a GumpReply, or a script reading the count.

  The words (ParseReplyArgs / ReplyArgsText), after the gump: button [switches] [id:text ...]
  - switches as one word 3/7, or - for none (a first text right after the button also means none);
  - each text as id:text, with a space written _, a real _ written \_ and a \ written \\; a character
    below 32 is \ and two hex digits. Any other \ stays as it is.
  A word that starts with digits and a colon never meets the interpreter's ',' / '.' glue, its ';'
  comment or its variable substitution, so every other character passes through as written.
}

{$mode delphi}{$H+}

interface
uses
  SysUtils, uoclidata, uocommands, uoevents;

const
  REPLY_TEXT_MAX   = 239;      // characters per text entry (the client's $EF)
  REPLY_PACKET_MAX = 2048;     // bytes; the event cave holds a little more

type
  TGumpReply = record
    TypeID   : Cardinal;
    Button   : Cardinal;
    Switches : array of Cardinal;
    TextIDs  : array of Word;
    Texts    : array of UnicodeString;
  end;

// "{button} [switches] [id:text ...]" -> R (TypeID left 0). False for anything that is not that.
function ParseReplyArgs(const Args : String; out R : TGumpReply) : Boolean;
// The same words back, switches always present ("-" for none).
function ReplyArgsText(const R : TGumpReply) : String;
function ReplySwitchesText(const R : TGumpReply) : String;
function ReplyTextsText(const R : TGumpReply) : String;
// One text to / from its word form (without the "id:").
function EncodeReplyText(const W : UnicodeString) : String;
function DecodeReplyText(const S : String) : UnicodeString;
// The packet a click on this gump would send.
function BuildReplyPacket(Serial : Cardinal; const R : TGumpReply) : String;
// A $B1 packet back to its serial and answer. False when it is not a whole $B1 packet.
function DecodeReplyPacket(const P : String; out Serial : Cardinal; out R : TGumpReply) : Boolean;
// The OSI gumps whose window the client keeps open after some buttons: left open after an answer.
function ReplyKeepsWindow(TypeID : Cardinal) : Boolean;
// Answers the server gump of type TypeID that is open now: the one at Addr when Addr<>0 (a ScanGumps
// entry, still open), else the frontmost one of that type. Returns 'sent', 'nogump' (no such gump
// open: nothing sent) or 'error' (this build can't: nothing sent). R.TypeID is set on 'sent'.
function SendGumpReply(Cst : TCstDB; Cmd : TUOCmd; Ev : TUOEvent; Addr, TypeID : Cardinal;
  var R : TGumpReply) : String;
// The click hook (TUOEvent.GumpHookActive): when it is on this client, Count is how many answers it has
// counted; and when that differs from Seen, R is the last one (Fresh), and Seen moves to Count.
// False when there is no hook (Install: put one there first).
function HookedReply(Ev : TUOEvent; Install : Boolean; var Seen : Int64; out Count : Cardinal;
  out R : TGumpReply; out Fresh : Boolean) : Boolean;

implementation

////////////////////////////////////////////////////////////////////////////////
function IsDigits(const S : String) : Boolean;
var
  I : Integer;
begin
  Result:=S<>'';
  for I:=1 to Length(S) do
    if not (S[I] in ['0'..'9']) then Exit(False);
end;

// a decimal number of at most Max, digits only
function ReadNum(const S : String; Max : Cardinal; out V : Cardinal) : Boolean;
var
  Q : QWord;
  I : Integer;
begin
  V:=0;
  Result:=IsDigits(S) and (Length(S)<=10);
  if not Result then Exit;
  Q:=0;
  for I:=1 to Length(S) do
    Q:=Q*10+Ord(S[I])-48;
  Result:=Q<=Max;
  if Result then V:=Cardinal(Q);
end;

function BE4(V : Cardinal) : String;
begin
  Result:=Chr(V shr 24)+Chr((V shr 16) and $FF)+Chr((V shr 8) and $FF)+Chr(V and $FF);
end;

function BE2(V : Word) : String;
begin
  Result:=Chr(V shr 8)+Chr(V and $FF);
end;

function GetBE(const P : String; Pos, Size : Integer) : Cardinal;
var
  I : Integer;
begin
  Result:=0;
  for I:=0 to Size-1 do
    Result:=(Result shl 8) or Ord(P[Pos+I]);
end;

////////////////////////////////////////////////////////////////////////////////
function EncodeReplyText(const W : UnicodeString) : String;
var
  U : UnicodeString;
  I : Integer;
  C : WideChar;
begin
  U:='';
  for I:=1 to Length(W) do
  begin
    C:=W[I];
    case C of
      ' ' : U:=U+'_';
      '_' : U:=U+'\_';
      '\' : U:=U+'\\';
    else
      if Ord(C)<32 then U:=U+UnicodeString('\'+IntToHex(Ord(C),2))
      else U:=U+C;
    end;
  end;
  Result:=UTF8Encode(U);
end;

function DecodeReplyText(const S : String) : UnicodeString;
var
  W : UnicodeString;
  I : Integer;
  H : Integer;
begin
  W:=UTF8Decode(S);
  Result:='';
  I:=1;
  while I<=Length(W) do
  begin
    if (W[I]='\') and (I<Length(W)) and ((W[I+1]='_') or (W[I+1]='\')) then
    begin
      Result:=Result+W[I+1];
      Inc(I,2);
      Continue;
    end;
    if (W[I]='\') and (I+2<=Length(W)) and
       TryStrToInt('$'+String(Copy(W,I+1,2)),H) and (H<32) and
       (Pos(String(W[I+1]),'0123456789ABCDEFabcdef')>0) and (Pos(String(W[I+2]),'0123456789ABCDEFabcdef')>0) then
    begin
      Result:=Result+WideChar(H);
      Inc(I,3);
      Continue;
    end;
    if W[I]='_' then Result:=Result+' '
    else Result:=Result+W[I];
    Inc(I);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function ParseReplyArgs(const Args : String; out R : TGumpReply) : Boolean;
var
  Words : array of String;
  Rest  : String;
  W, V  : String;
  P, I  : Integer;
  C     : Cardinal;
  T     : UnicodeString;
begin
  Result:=False;
  R.TypeID:=0;
  R.Button:=0;
  R.Switches:=nil;
  R.TextIDs:=nil;
  R.Texts:=nil;
  Words:=nil;
  Rest:=StringReplace(Trim(Args),#9,' ',[rfReplaceAll])+' ';
  while Rest<>'' do
  begin
    P:=Pos(' ',Rest);
    W:=Copy(Rest,1,P-1);
    Delete(Rest,1,P);
    if W='' then Continue;
    SetLength(Words,Length(Words)+1);
    Words[High(Words)]:=W;
  end;
  if Length(Words)=0 then Exit;
  if not ReadNum(Words[0],$FFFFFFFF,R.Button) then Exit;
  I:=1;
  if (I<=High(Words)) and (Pos(':',Words[I])=0) then
  begin
    W:=Words[I];
    Inc(I);
    if W<>'-' then
    begin
      W:=W+'/';
      while W<>'' do
      begin
        P:=Pos('/',W);
        V:=Copy(W,1,P-1);
        Delete(W,1,P);
        if not ReadNum(V,$FFFFFFFF,C) then Exit;
        SetLength(R.Switches,Length(R.Switches)+1);
        R.Switches[High(R.Switches)]:=C;
      end;
    end;
  end;
  while I<=High(Words) do
  begin
    W:=Words[I];
    Inc(I);
    P:=Pos(':',W);
    if P<2 then Exit;
    if not ReadNum(Copy(W,1,P-1),$FFFF,C) then Exit;
    T:=DecodeReplyText(Copy(W,P+1,MaxInt));
    if Length(T)>REPLY_TEXT_MAX then SetLength(T,REPLY_TEXT_MAX);
    SetLength(R.TextIDs,Length(R.TextIDs)+1);
    R.TextIDs[High(R.TextIDs)]:=Word(C);
    SetLength(R.Texts,Length(R.Texts)+1);
    R.Texts[High(R.Texts)]:=T;
  end;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function ReplySwitchesText(const R : TGumpReply) : String;
var
  I : Integer;
begin
  if Length(R.Switches)=0 then Exit('-');
  Result:='';
  for I:=0 to High(R.Switches) do
  begin
    if I>0 then Result:=Result+'/';
    Result:=Result+IntToStr(R.Switches[I]);
  end;
end;

function ReplyTextsText(const R : TGumpReply) : String;
var
  I : Integer;
begin
  Result:='';
  for I:=0 to High(R.Texts) do
  begin
    if I>0 then Result:=Result+' ';
    Result:=Result+IntToStr(R.TextIDs[I])+':'+EncodeReplyText(R.Texts[I]);
  end;
end;

function ReplyArgsText(const R : TGumpReply) : String;
begin
  Result:=IntToStr(R.Button)+' '+ReplySwitchesText(R);
  if Length(R.Texts)>0 then Result:=Result+' '+ReplyTextsText(R);
end;

////////////////////////////////////////////////////////////////////////////////
function BuildReplyPacket(Serial : Cardinal; const R : TGumpReply) : String;
var
  Body : String;
  I, J : Integer;
  T    : UnicodeString;
begin
  Body:=BE4(Serial)+BE4(R.TypeID)+BE4(R.Button)+BE4(Length(R.Switches));
  for I:=0 to High(R.Switches) do
    Body:=Body+BE4(R.Switches[I]);
  Body:=Body+BE4(Length(R.Texts));
  for I:=0 to High(R.Texts) do
  begin
    T:=R.Texts[I];
    if Length(T)>REPLY_TEXT_MAX then SetLength(T,REPLY_TEXT_MAX);
    Body:=Body+BE2(R.TextIDs[I])+BE2(Length(T));
    for J:=1 to Length(T) do
      Body:=Body+BE2(Ord(T[J]));
  end;
  I:=Length(Body)+3;
  Result:=#$B1+Chr(I and $FF)+Chr((I shr 8) and $FF)+Body;    // length low byte first, see the header
end;

////////////////////////////////////////////////////////////////////////////////
function DecodeReplyPacket(const P : String; out Serial : Cardinal; out R : TGumpReply) : Boolean;
var
  Pos, N, I, J, L : Integer;
  T               : UnicodeString;
begin
  Result:=False;
  Serial:=0;
  R.TypeID:=0;
  R.Button:=0;
  R.Switches:=nil;
  R.TextIDs:=nil;
  R.Texts:=nil;
  if (Length(P)<23) or (Ord(P[1])<>$B1) then Exit;
  Serial:=GetBE(P,4,4);
  R.TypeID:=GetBE(P,8,4);
  R.Button:=GetBE(P,12,4);
  N:=GetBE(P,16,4);
  Pos:=20;
  if (N<0) or (N>(Length(P)-Pos+1) div 4) then Exit;
  SetLength(R.Switches,N);
  for I:=0 to N-1 do
  begin
    R.Switches[I]:=GetBE(P,Pos,4);
    Inc(Pos,4);
  end;
  if Pos+3>Length(P) then Exit;
  N:=GetBE(P,Pos,4);
  Inc(Pos,4);
  if (N<0) or (N>(Length(P)-Pos+1) div 4) then Exit;
  SetLength(R.TextIDs,N);
  SetLength(R.Texts,N);
  for I:=0 to N-1 do
  begin
    if Pos+3>Length(P) then Exit;
    R.TextIDs[I]:=GetBE(P,Pos,2);
    L:=GetBE(P,Pos+2,2);
    Inc(Pos,4);
    if Pos+L*2-1>Length(P) then Exit;
    T:='';
    for J:=0 to L-1 do
      T:=T+WideChar(GetBE(P,Pos+J*2,2));
    R.Texts[I]:=T;
    Inc(Pos,L*2);
  end;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function ReplyKeepsWindow(TypeID : Cardinal) : Boolean;
begin
  Result:=(TypeID>=$2410) and (TypeID<=$2462);
end;

////////////////////////////////////////////////////////////////////////////////
function SendGumpReply(Cst : TCstDB; Cmd : TUOCmd; Ev : TUOEvent; Addr, TypeID : Cardinal;
  var R : TGumpReply) : String;
var
  G : TGumpInfo;
  P : String;
begin
  Result:='error';
  if (Cst.BGUMPSERIAL=0) or (Cst.BGUMPTYPE=0) or (Cst.ESENDPACKET=0) then Exit;
  if not Cmd.FindLiveGump(Addr,TypeID,G) then
  begin
    Result:='nogump';
    Exit;
  end;
  R.TypeID:=G.TypeID;
  P:=BuildReplyPacket(G.Serial,R);
  if Length(P)>REPLY_PACKET_MAX then Exit;
  if not Ev.ExEv_GumpReply(G.Addr,G.VTable,P,not ReplyKeepsWindow(G.TypeID)) then Exit;
  Result:='sent';
end;

////////////////////////////////////////////////////////////////////////////////
function HookedReply(Ev : TUOEvent; Install : Boolean; var Seen : Int64; out Count : Cardinal;
  out R : TGumpReply; out Fresh : Boolean) : Boolean;
var
  P      : String;
  Serial : Cardinal;
begin
  Fresh:=False;
  Count:=0;
  R.TypeID:=0;
  R.Button:=0;
  R.Switches:=nil;
  R.TextIDs:=nil;
  R.Texts:=nil;
  Result:=Ev.GumpHookActive(Install) and Ev.GumpHookRead(Count,P);
  if not Result then Exit;
  if Int64(Count)=Seen then Exit;
  Seen:=Count;
  Fresh:=DecodeReplyPacket(P,Serial,R);
end;

end.
