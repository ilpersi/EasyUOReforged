unit EuoJumpTarget;

{
  Where a GOSUB or GOTO in the editor leads, added during the Lazarus/FPC migration (not
  present in the original Delphi 7 app) for the editor's Ctrl+click on a sub or label name
  (easyuo\insthandler.pas). A pure, string-in/line-out unit like EuoBlocks.pas, so it is
  unit-testable and sits at parser's lowest layer. EuoInterpreter.pas is NOT touched -- the
  rules below are read off it, not shared with it, so the jump lands where the script would go:
  - GoSubProc scans the script from the LAST line up; the first line whose command (GetCmd)
    is SUB and whose second word (Parameterize), uppercased, equals the name wins. So with two
    subs of one name, the last one is the target.
  - GoToProc uppercases the name and appends ':' when it does not end with one, then searches
    outward from the GOTO line in both directions at once, the line below before the line above
    at each distance, for a line whose command (GetCmd) is that 'NAME:'.
  Both compare the name AFTER ParseLine, so a name that only exists at run time has no target
  here: a variable (IsVar, the exact test ParseLine substitutes on), a word glued to the next by
  '.' or ',', or a line continued by '+' lines.

  Words are split by Parameterize's rules (EuoScriptWords.ScanLineWords, which
  EuoMenuSelect.SplitScriptLine calls too): spaces and tabs separate words, and a word that
  starts with ';' ends the line. ScanLineWords keeps each word's position in the line.
}

{$mode delphi}{$H+}

interface

uses
  Classes;

// 0-based index of the line the GOSUB/GOTO name at (LineIdx, Col) leads to, or -1 when
// there is no name there or it leads nowhere. LineIdx is 0-based, Col a 1-based byte column
// anywhere inside the name.
function EuoJumpTargetAt(Lines : TStrings; LineIdx, Col : Integer) : Integer;

// GoSubProc's lookup: the line of the SUB that "gosub Name" runs, or -1.
function EuoFindSub(Lines : TStrings; const Name : String) : Integer;

// GoToProc's lookup: the line of the label that "goto Name" on line FromLine jumps to, or -1.
function EuoFindLabel(Lines : TStrings; FromLine : Integer; const Name : String) : Integer;

implementation

uses
  SysUtils, EuoBlocks, EuoScriptWords, EuoMenuSelect;

////////////////////////////////////////////////////////////////////////////////
function EuoFindSub(Lines : TStrings; const Name : String) : Integer;
var
  Cnt   : Integer;
  Words : TStringList;
begin
  Result:=-1;
  Words:=TStringList.Create;
  try
    for Cnt:=Lines.Count-1 downto 0 do
      if EuoLineCmd(Lines[Cnt])='SUB' then
    begin
      SplitScriptLine(Lines[Cnt],Words);
      if Words.Count<2 then Continue;
      if UpperCase(Words[1])<>UpperCase(Name) then Continue;
      Result:=Cnt;
      Exit;
    end;
  finally
    Words.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function EuoFindLabel(Lines : TStrings; FromLine : Integer; const Name : String) : Integer;
var
  i1, i2 : Integer;
  b1, b2 : Boolean;
  sBuf   : String;
begin
  Result:=-1;
  sBuf:=UpperCase(Name);
  if Copy(sBuf,Length(sBuf),1)<>':' then
    sBuf:=sBuf+':';

  i1:=FromLine;
  i2:=i1;
  repeat
    Inc(i1);
    Dec(i2);
    b1:=i1<Lines.Count;
    b2:=i2>=0;

    if b1 then
      if EuoLineCmd(Lines[i1])=sBuf then
    begin
      Result:=i1;
      Exit;
    end;

    if b2 then
      if EuoLineCmd(Lines[i2])=sBuf then
    begin
      Result:=i2;
      Exit;
    end;
  until not(b1 or b2);
end;

////////////////////////////////////////////////////////////////////////////////
function EuoJumpTargetAt(Lines : TStrings; LineIdx, Col : Integer) : Integer;
var
  W   : TEuoWords;
  Cmd : String;
begin
  Result:=-1;
  if (LineIdx<0) or (LineIdx>=Lines.Count) then Exit;

  ScanLineWords(Lines[LineIdx],W);
  if Length(W)<2 then Exit;
  Cmd:=UpperCase(W[0].Text);
  if (Cmd<>'GOSUB') and (Cmd<>'GOTO') then Exit;
  if (Col<W[1].Start) or (Col>=W[1].Start+Length(W[1].Text)) then Exit;

  // Names the script only knows at run time -- see the header comment.
  if IsVar(W[1].Text) then Exit;
  if Length(W)>2 then
    if (W[2].Text='.') or (W[2].Text=',') then Exit;
  if LineIdx+1<Lines.Count then
    if Copy(Trim(Lines[LineIdx+1]),1,1)='+' then Exit;

  if Cmd='GOSUB' then
    Result:=EuoFindSub(Lines,W[1].Text)
  else
    Result:=EuoFindLabel(Lines,LineIdx,W[1].Text);
end;

end.
