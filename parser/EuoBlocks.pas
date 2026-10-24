unit EuoBlocks;

{
  The block structure of an EasyUO script as the interpreter actually runs it,
  added during the Lazarus/FPC migration (not present in the original Delphi 7
  app at all) to back two editor features: code folding (easyuo\eufoldsyn.pas)
  and Edit > Format Script (easyuo\main.pas). Both run the same EuoBlockStep,
  so a fold and an indentation level can never disagree about where a block
  starts or ends.

  Deliberately a pure, string-in/string-out unit with no interpreter involved,
  the same reasoning EuoCallStackFormat.pas documents: trivially unit-testable,
  and it sits at parser's lowest dependency layer. EuoInterpreter.pas itself is
  NOT touched -- the rules below are read off it, not shared with it:
  - EuoLineCmd is an exact single-line copy of TEuoInterpreter.GetCmd: the first
    token of the trimmed line, uppercased, cut at the first space/tab/';'. A
    brace only counts when it is that first token (ScanForBlock and
    ContinueBreakProc both compare GetCmd against the bare brace).
  - IF/ELSE/FOR/WHILE/ONHOTKEY/CMPPIX (every command that calls ScanForBlock
    except SUB) own a brace block only when the opening brace is the VERY
    NEXT physical line (ScanForBlock looks at NextLine only); otherwise they
    govern exactly one physical line -- a blank or comment line included,
    since the interpreter skips one line, not one statement.
  - A line starting with '+' continues the line before it (ParseLine joins
    them), so a header's own continuation lines do not use up its body line.
  - SUB is a brace block when an opening brace follows directly, else it runs
    to a RETURN (SubProc). The RETURN that ends a sub is one at the sub's own level: an
    early RETURN inside braces, or as the one-line body of an IF, does not.
    A SUB line while another sub is still open ends that sub (subs do not
    nest; the next SUB is where its code visibly stops).
  - REPEAT ... UNTIL (UntilProc pairs them by counting, ignoring braces).

  Leading and trailing whitespace is never significant to the interpreter --
  every read of a script line goes through Trim (GetCmd, ParseLine,
  RawLineText, Parameterize) -- which is what makes EuoFormatLines safe: it
  changes nothing else on any line, and never the number of lines (so
  breakpoints, which are keyed by line number, stay where they are).
}

{$mode delphi}{$H+}

interface

uses
  Classes;

type
  TEuoBlockKind   = (ebkNone, ebkBrace, ebkSubBrace, ebkSub, ebkRepeat);
  TEuoBlockKinds  = set of TEuoBlockKind;

  // What the NEXT line is to its predecessor: the one-line body of an
  // IF/ELSE/FOR/WHILE/ONHOTKEY/CMPPIX (ebpHeader), or the first line after
  // SUB (ebpSub, where a '{' makes it a braced sub).
  TEuoBodyPending = (ebpNone, ebpHeader, ebpSub);

  TEuoLineStep = record
    Cmd            : String;          // EuoLineCmd of the line
    IsContinuation : Boolean;         // '+' line: nothing else below applies
    Closes         : Integer;         // innermost open blocks this line closes, before Opens
    Opens          : TEuoBlockKind;   // block this line opens (ebkNone = none)
    Pending        : TEuoBodyPending; // state for the next line
    IsBody         : Boolean;         // this line is the one-line body of a header (IF, ...)
  end;

// TEuoInterpreter.GetCmd for a single line -- see the header comment.
function EuoLineCmd(const Line : String) : String;

// Applies one line to the block state. Stack holds the open blocks, outermost
// first (Stack[High(Stack)] is the innermost). Pending is the previous
// non-continuation line's Result.Pending (ebpNone for the first line).
function EuoBlockStep(const Line : String; Pending : TEuoBodyPending;
  const Stack : array of TEuoBlockKind) : TEuoLineStep;

// Re-indents a whole script into Dst (Dst may be Src): IndentWidth spaces per
// level, blank lines emptied, trailing whitespace dropped, nothing else on a
// line changed, same number of lines.
procedure EuoFormatLines(Src : TStrings; IndentWidth : Integer; Dst : TStrings);

implementation

uses
  SysUtils;

////////////////////////////////////////////////////////////////////////////////
function EuoLineCmd(const Line : String) : String;
var
  Cnt : Integer;
begin
  Result:=UpperCase(Trim(Line));
  for Cnt:=1 to Length(Result) do
    if Result[Cnt] in [#9,#32,';'] then
  begin
    Result:=Copy(Result,1,Cnt-1);
    Break;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Distance from the innermost block (0 = innermost) of the nearest block of
// one of Kinds, searching outwards but not past a Barrier block; -1 if none.
function DepthOf(const Stack : array of TEuoBlockKind; Kinds, Barrier : TEuoBlockKinds) : Integer;
var
  Cnt : Integer;
begin
  Result:=-1;
  for Cnt:=High(Stack) downto Low(Stack) do
  begin
    if Stack[Cnt] in Kinds then
    begin
      Result:=High(Stack)-Cnt;
      Exit;
    end;
    if Stack[Cnt] in Barrier then Exit;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function EuoBlockStep(const Line : String; Pending : TEuoBodyPending;
  const Stack : array of TEuoBlockKind) : TEuoLineStep;
var
  Depth : Integer;
  Cmd   : String;
begin
  Cmd:=EuoLineCmd(Line);
  Result.Cmd:=Cmd;
  Result.IsContinuation:=Copy(Trim(Line),1,1)='+';
  Result.Closes:=0;
  Result.Opens:=ebkNone;
  Result.Pending:=Pending;
  Result.IsBody:=False;
  if Result.IsContinuation then Exit;

  Result.IsBody:=Pending=ebpHeader;
  Result.Pending:=ebpNone;

  if Cmd='{' then
  begin
    if Pending=ebpSub then Result.Opens:=ebkSubBrace
    else Result.Opens:=ebkBrace;
  end
  else if Cmd='}' then
  begin
    Depth:=DepthOf(Stack,[ebkBrace,ebkSubBrace],[]);
    if Depth>=0 then
    begin
      Result.Closes:=Depth+1;
      // a braced sub ends with its brace
      if Stack[High(Stack)-Depth]=ebkSubBrace then
        if (High(Stack)-Depth>0) and (Stack[High(Stack)-Depth-1]=ebkSub) then
          Inc(Result.Closes);
    end;
  end
  else if Cmd='SUB' then
  begin
    Depth:=DepthOf(Stack,[ebkSub],[]);
    if Depth>=0 then Result.Closes:=Depth+1;
    Result.Opens:=ebkSub;
    Result.Pending:=ebpSub;
  end
  else if Cmd='RETURN' then
  begin
    if (Pending<>ebpHeader) and (Length(Stack)>0) and (Stack[High(Stack)]=ebkSub) then
      Result.Closes:=1;
  end
  else if Cmd='REPEAT' then
    Result.Opens:=ebkRepeat
  else if Cmd='UNTIL' then
  begin
    Depth:=DepthOf(Stack,[ebkRepeat],[ebkSub,ebkSubBrace]);
    if Depth>=0 then Result.Closes:=Depth+1;
  end
  else if (Cmd='IF')or(Cmd='ELSE')or(Cmd='FOR')or(Cmd='WHILE')or
          (Cmd='ONHOTKEY')or(Cmd='CMPPIX') then
    Result.Pending:=ebpHeader;
end;

////////////////////////////////////////////////////////////////////////////////
// Levels: a line inside a block is one deeper than the line that opened it; a
// line that closes blocks (}, RETURN, UNTIL) sits at the level of the opener of
// the outermost block it closes; a one-line body is one deeper than its header,
// and a '{' right under a header lines up with it; the '{' of a braced sub lines
// up with SUB; a '+' continuation is one deeper than the line it continues.
procedure EuoFormatLines(Src : TStrings; IndentWidth : Integer; Dst : TStrings);
var
  Kinds     : array of TEuoBlockKind;
  OpenLvls  : array of Integer;      // level of the line that opened Kinds[i]
  Pending   : TEuoBodyPending;
  Step      : TEuoLineStep;
  Res       : TStringList;
  Cnt       : Integer;
  Level     : Integer;
  LastLevel : Integer;               // level of the last non-continuation line
  Base      : Integer;
  sBuf      : String;
begin
  Res:=TStringList.Create;
  try
    SetLength(Kinds,0);
    SetLength(OpenLvls,0);
    Pending:=ebpNone;
    LastLevel:=0;

    for Cnt:=0 to Src.Count-1 do
    begin
      sBuf:=Trim(Src[Cnt]);
      Step:=EuoBlockStep(sBuf,Pending,Kinds);

      if Step.IsContinuation then
        Level:=LastLevel+1
      else
      begin
        if Step.Closes>0 then
        begin
          Base:=OpenLvls[Length(Kinds)-Step.Closes];
          SetLength(Kinds,Length(Kinds)-Step.Closes);
          SetLength(OpenLvls,Length(OpenLvls)-Step.Closes);
        end
        else if Length(Kinds)>0 then
          Base:=OpenLvls[High(OpenLvls)]+1
        else
          Base:=0;

        if (Step.Closes>0) and (Step.Opens=ebkNone) then
          Level:=Base                       // }, RETURN, UNTIL
        else if Step.Closes>0 then          // SUB ending an open sub
        begin
          if Length(Kinds)>0 then Level:=OpenLvls[High(OpenLvls)]+1
          else Level:=0;
        end
        else if Step.Opens=ebkSubBrace then
          Level:=OpenLvls[High(OpenLvls)]  // its SUB line
        else if Step.IsBody and (Step.Cmd='{') then
          Level:=LastLevel
        else if Step.IsBody and (Step.Cmd<>'}') then
          Level:=LastLevel+1
        else
          Level:=Base;

        if Step.Opens<>ebkNone then
        begin
          SetLength(Kinds,Length(Kinds)+1);
          SetLength(OpenLvls,Length(OpenLvls)+1);
          Kinds[High(Kinds)]:=Step.Opens;
          OpenLvls[High(OpenLvls)]:=Level;
        end;
        LastLevel:=Level;
        Pending:=Step.Pending;
      end;

      if sBuf='' then Res.Add('')
      else Res.Add(StringOfChar(' ',Level*IndentWidth)+sBuf);
    end;

    Dst.Assign(Res);
  finally
    Res.Free;
  end;
end;

end.
