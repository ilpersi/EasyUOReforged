unit euoutput;

{
  Port addition (the LOG command, docs\agent-support.md phase 3): the text of the editor's
  Output panel, which shows what running scripts log. Two pure functions, apart from main.pas
  so they can be tested: what one line looks like, and how the panel's text stays bounded.

  The panel is one for the whole window. Every tab's lines go into it in the order they
  arrive, each with the time; when more than one tab is open, each also names its tab.

  EuoUtf8Text (2026-11-27): a script's text holds two encodings. What comes from the script
  itself is UTF-8 (the editor and EUOCli read script files as UTF-8), and so are ScanBuffs' and
  the gumps' texts; but the client's texts (#Property, the journal, #SysMsg) keep one byte per
  letter, the low byte of each UTF-16 character, so their accented letters are Latin-1 bytes
  that are not UTF-8. The LCL showed each of them as '?' in this panel, and EUOCli printed them
  as they are, which a UTF-8 reader (PowerShell, an AI agent over MCP) turned into U+FFFD.
  EuoUtf8Text makes the text valid UTF-8 for showing or printing; the panel's lines go through
  it (EuoOutputLine) and so does everything EUOCli.lpr writes. The script's own text is never
  changed: variables and comparisons keep their bytes.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, LConvEncoding;

const
  // The panel keeps this many lines; older ones go as new ones come.
  OUTPUT_MAX_LINES = 5000;

// S as valid UTF-8, to show or print it. A well-formed UTF-8 sequence stays as it is; every
// other byte from $80 up is read as Windows-1252, which for accented letters is Latin-1 (what
// the client's texts hold) and is how script files that are not UTF-8 are read
// (scriptfile.pas). It goes one character at a time, so a line that mixes a UTF-8 literal and a
// client text comes out right in both parts. The one guess it can get wrong: two Latin-1 letters
// that happen to form a UTF-8 sequence ("Ã" then "©") show as the one letter of that sequence.
function EuoUtf8Text(const S : String) : String;

// One line of the panel: "14:03:09  text", or "14:03:09  tab: text" when ShowTab. UTF-8
// (EuoUtf8Text), so the LCL shows every letter.
function EuoOutputLine(Time : TDateTime; const Tab, Text : String; ShowTab : Boolean) : String;

// Appends NewLines to Dest, then drops the oldest lines until at most MaxLines are left.
procedure EuoAppendOutput(Dest, NewLines : TStrings; MaxLines : Integer = OUTPUT_MAX_LINES);

implementation

////////////////////////////////////////////////////////////////////////////////
// The length of the well-formed UTF-8 sequence that starts at S[i] (RFC 3629: no overlong
// forms, no UTF-16 surrogates, nothing above U+10FFFF), or 0 when none starts there.
// LazUTF8's UTF8CodepointStrictSize accepts the overlong and surrogate forms, which a UTF-8
// reader then rejects, so it is not used here.
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
function EuoUtf8Text(const S : String) : String;
var
  i, n, Len, Done : Integer;
  Ch              : String;
begin
  Len:=Length(S);
  i:=1;
  while (i<=Len) and (Byte(S[i])<$80) do Inc(i);
  if i>Len then Exit(S);                    // plain ASCII, the common case

  // Byte copies only, so no code page conversion of the RTL's gets in the way. One byte
  // becomes at most 3 (Windows-1252's euro sign and the like); a sequence stays as long.
  SetLength(Result,Len*3);
  Done:=i-1;
  if Done>0 then Move(S[1],Result[1],Done);
  while i<=Len do
  begin
    n:=Utf8SeqLen(S,i);
    if n>0 then
    begin
      Move(S[i],Result[Done+1],n);
      Inc(Done,n);
      Inc(i,n);
    end
    else begin
      Ch:=CP1252ToUTF8(S[i]);
      if Ch<>'' then Move(Ch[1],Result[Done+1],Length(Ch));
      Inc(Done,Length(Ch));
      Inc(i);
    end;
  end;
  SetLength(Result,Done);
end;

////////////////////////////////////////////////////////////////////////////////
function EuoOutputLine(Time : TDateTime; const Tab, Text : String; ShowTab : Boolean) : String;
begin
  Result:=FormatDateTime('hh":"nn":"ss',Time)+'  ';
  if ShowTab then Result:=Result+Tab+': ';
  Result:=EuoUtf8Text(Result+Text);
end;

////////////////////////////////////////////////////////////////////////////////
procedure EuoAppendOutput(Dest, NewLines : TStrings; MaxLines : Integer);
var
  Drop, i : Integer;
begin
  if NewLines.Count=0 then Exit;
  Dest.BeginUpdate;
  try
    // More new lines than the panel holds: only the newest of them matter.
    if NewLines.Count>=MaxLines then
    begin
      Dest.Clear;
      for i:=NewLines.Count-MaxLines to NewLines.Count-1 do Dest.Add(NewLines[i]);
      Exit;
    end;
    Drop:=Dest.Count+NewLines.Count-MaxLines;
    for i:=1 to Drop do Dest.Delete(0);
    Dest.AddStrings(NewLines);
  finally
    Dest.EndUpdate;
  end;
end;

end.
