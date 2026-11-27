unit EuoTextEncoding;

{
  Port addition (2026-11-27, docs\text-encoding-analysis.md): one encoding inside the interpreter.

  EasyUO 1.5 held one byte per letter everywhere (Delphi 7, Windows-1252). Reforged's script text is
  UTF-8 (the editor and EUOCli read script files as UTF-8), so its accented letters are two bytes,
  while the client's texts keep one byte per letter (Latin-1: the low byte of each UTF-16 character,
  or the 8-bit text the server sent). A script literal "è" never equalled a client "è".

  The interpreter now converts at its edges, and uo\ (shared with uo.dll) is left as it is:
  - Latin1ToUtf8: client text coming in (#Property, #Journal, #SysMsg, #CharName, #Shard, …).
  - Utf8ToLatin1: script text going into the client's 8-bit fields (event SysMessage, ExMsg,
    exevent RenamePet).
  - ScriptTextToUtf8: script text from a file or stdin that is not UTF-8 (CALL, EUOCli run -), read
    as Windows-1252, the rule the editor has always used (scriptfile.pas).
  - The letter functions: STR counts letters, not bytes, so "è" is one position again as in 1.5.
    A letter is a well-formed UTF-8 sequence, or one byte that starts none: text with no UTF-8 in
    it counts byte by byte, exactly as before. Each one mirrors the RTL routine STR used (Copy,
    Delete, Insert, Pos) with the same clamping, in letters; text with no byte from $80 up takes
    the RTL routine itself.
}

{$mode delphi}{$H+}

interface

type
  TLetterStarts = array of Integer;

// The length of the well-formed UTF-8 sequence that starts at S[i] (RFC 3629: no overlong
// forms, no UTF-16 surrogates, nothing above U+10FFFF), or 0 when none starts there.
// LazUTF8's UTF8CodepointStrictSize accepts the overlong and surrogate forms, which a UTF-8
// reader then rejects, so it is not used here.
function Utf8SeqLen(const S : String; i : Integer) : Integer;

// True when S has no byte from $80 up.
function IsAsciiText(const S : String) : Boolean;

// One byte per letter (Latin-1) to UTF-8: byte $xx becomes U+00xx.
function Latin1ToUtf8(const S : String) : String;

// UTF-8 to one byte per letter (Latin-1): U+0000..U+00FF become that byte, anything above '?'.
// A byte that starts no well-formed sequence is kept as it is.
function Utf8ToLatin1(const S : String) : String;

// Script text as UTF-8: valid UTF-8 stays as it is, anything else is read as Windows-1252.
function ScriptTextToUtf8(const S : String) : String;

// The byte where each letter of S starts, then Length(S)+1.
function LetterStarts(const S : String) : TLetterStarts;
function LetterCount(const S : String) : Integer;
// Copy, Delete, Insert and Pos of the RTL, counting letters instead of bytes.
function LetterCopy(const S : String; Index, Count : Int64) : String;
procedure LetterDelete(var S : String; Index, Count : Int64);
procedure LetterInsert(const Src : String; var S : String; Index : Int64);
// The letter where Sub first starts in S, or 0. A match starts and ends on a letter boundary.
function LetterPos(const Sub, S : String) : Integer;

implementation

uses
  LazUTF8, LConvEncoding;

////////////////////////////////////////////////////////////////////////////////
function Utf8SeqLen(const S : String; i : Integer) : Integer;
var
  B0, B1 : Byte;
  Left   : Integer;

  function Cont(K : Integer) : Boolean;
  begin
    Result:=(K<Left) and ((Byte(S[i+K]) and $C0)=$80);
  end;

begin
  B0:=Byte(S[i]);
  if B0<$80 then Exit(1);
  Result:=0;
  Left:=Length(S)-i+1;
  if Left<2 then Exit;
  B1:=Byte(S[i+1]);
  case B0 of
    $C2..$DF          : if Cont(1) then Result:=2;
    $E0               : if (B1>=$A0) and (B1<=$BF) and Cont(2) then Result:=3;
    $E1..$EC,$EE,$EF  : if Cont(1) and Cont(2) then Result:=3;
    $ED               : if (B1>=$80) and (B1<=$9F) and Cont(2) then Result:=3;
    $F0               : if (B1>=$90) and (B1<=$BF) and Cont(2) and Cont(3) then Result:=4;
    $F1..$F3          : if Cont(1) and Cont(2) and Cont(3) then Result:=4;
    $F4               : if (B1>=$80) and (B1<=$8F) and Cont(2) and Cont(3) then Result:=4;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function IsAsciiText(const S : String) : Boolean;
var
  i : Integer;
begin
  for i:=1 to Length(S) do
    if Byte(S[i])>=$80 then Exit(False);
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function Latin1ToUtf8(const S : String) : String;
var
  i, n, Hi : Integer;
  B        : Byte;
begin
  Hi:=0;
  for i:=1 to Length(S) do
    if Byte(S[i])>=$80 then Inc(Hi);
  if Hi=0 then Exit(S);

  SetLength(Result,Length(S)+Hi);
  n:=0;
  for i:=1 to Length(S) do
  begin
    B:=Byte(S[i]);
    Inc(n);
    if B<$80 then Result[n]:=Chr(B)
    else begin
      Result[n]:=Chr($C0 or (B shr 6));
      Inc(n);
      Result[n]:=Chr($80 or (B and $3F));
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function Utf8ToLatin1(const S : String) : String;
var
  i, n, k : Integer;
  Cp      : Cardinal;
begin
  if IsAsciiText(S) then Exit(S);
  SetLength(Result,Length(S));
  n:=0;
  i:=1;
  while i<=Length(S) do
  begin
    k:=Utf8SeqLen(S,i);
    Inc(n);
    if k<=1 then
    begin
      Result[n]:=S[i];      // ASCII, or a byte that is not UTF-8: kept
      Inc(i);
      Continue;
    end;
    if k=2 then Cp:=((Byte(S[i]) and $1F) shl 6) or (Byte(S[i+1]) and $3F)
    else Cp:=$100;          // three and four bytes are all above U+00FF
    if Cp<=$FF then Result[n]:=Chr(Cp) else Result[n]:='?';
    Inc(i,k);
  end;
  SetLength(Result,n);
end;

////////////////////////////////////////////////////////////////////////////////
function ScriptTextToUtf8(const S : String) : String;
begin
  if FindInvalidUTF8Codepoint(PChar(S),Length(S))>=0 then
    Result:=CP1252ToUTF8(S)
  else
    Result:=S;
end;

////////////////////////////////////////////////////////////////////////////////
function LetterStarts(const S : String) : TLetterStarts;
var
  i, n, k : Integer;
begin
  SetLength(Result,Length(S)+1);
  n:=0;
  i:=1;
  while i<=Length(S) do
  begin
    Result[n]:=i;
    Inc(n);
    k:=Utf8SeqLen(S,i);
    if k=0 then k:=1;
    Inc(i,k);
  end;
  Result[n]:=Length(S)+1;
  SetLength(Result,n+1);
end;

////////////////////////////////////////////////////////////////////////////////
function LetterCount(const S : String) : Integer;
var
  i, k : Integer;
begin
  if IsAsciiText(S) then Exit(Length(S));
  Result:=0;
  i:=1;
  while i<=Length(S) do
  begin
    k:=Utf8SeqLen(S,i);
    if k=0 then k:=1;
    Inc(i,k);
    Inc(Result);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// As the RTL's Copy: Index below 1 starts at the first letter without shortening Count; past
// the end gives ''. (The guard on Index also stops the Index+Count overflow the RTL's own
// check can't catch.)
function LetterCopy(const S : String; Index, Count : Int64) : String;
var
  L : TLetterStarts;
  N : Int64;
begin
  if IsAsciiText(S) then Exit(Copy(S,Index,Count));
  L:=LetterStarts(S);
  N:=High(L);
  Dec(Index);
  if Index<0 then Index:=0;
  if Index>=N then Exit('');
  if (Count>N) or (Index+Count>N) then Count:=N-Index;
  if Count<=0 then Exit('');
  Result:=Copy(S,L[Index],L[Index+Count]-L[Index]);
end;

////////////////////////////////////////////////////////////////////////////////
// As the RTL's Delete: nothing for an Index outside the text or a Count below 1.
procedure LetterDelete(var S : String; Index, Count : Int64);
var
  L : TLetterStarts;
  N : Int64;
begin
  if IsAsciiText(S) then
  begin
    Delete(S,Index,Count);
    Exit;
  end;
  L:=LetterStarts(S);
  N:=High(L);
  if (Index>N) or (Index<=0) or (Count<=0) then Exit;
  if Count>N-Index then Count:=N-Index+1;
  Delete(S,L[Index-1],L[Index-1+Count]-L[Index-1]);
end;

////////////////////////////////////////////////////////////////////////////////
// As the RTL's Insert: an Index below 1 inserts at the start, past the end appends.
procedure LetterInsert(const Src : String; var S : String; Index : Int64);
var
  L : TLetterStarts;
  N : Int64;
begin
  if Src='' then Exit;
  if IsAsciiText(S) then
  begin
    Insert(Src,S,Index);
    Exit;
  end;
  L:=LetterStarts(S);
  N:=High(L);
  if Index<=0 then Index:=1;
  if Index>N then Index:=N+1;
  Insert(Src,S,L[Index-1]);
end;

////////////////////////////////////////////////////////////////////////////////
function LetterPos(const Sub, S : String) : Integer;
var
  L     : TLetterStarts;
  AtIdx : array of Integer;
  i, B  : SizeInt;
begin
  if IsAsciiText(S) then Exit(Pos(Sub,S));
  Result:=0;
  if (Sub='') or (S='') then Exit;
  L:=LetterStarts(S);
  SetLength(AtIdx,Length(S)+2);   // byte -> letter number where a letter starts, else 0
  for i:=0 to High(L) do AtIdx[L[i]]:=i+1;
  B:=Pos(Sub,S);
  while B>0 do
  begin
    if (AtIdx[B]>0) and (AtIdx[B+Length(Sub)]>0) then Exit(AtIdx[B]);
    B:=Pos(Sub,S,B+1);
  end;
end;

end.
