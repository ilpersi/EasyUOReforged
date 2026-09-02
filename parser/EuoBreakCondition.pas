unit EuoBreakCondition;

{
  Evaluates a conditional breakpoint's condition string against a live
  TEuoInterpreter, added during the Lazarus/FPC migration (not present in
  the original Delphi 7 app at all -- new debugging feature).

  Deliberately a SIMPLE, restricted grammar -- not the real EUO expression
  language (EuoExpression.pas's Eval): exactly one comparison,

    <#var-or-%var-or-*var-or-!var> <op> <literal>

  where <op> is one of =, <>, >, <, >=, <=. This is a deliberate scope
  decision, not a shortcut taken carelessly: EuoExpression.Eval only
  operates on an already-tokenized TParList built by TEuoInterpreter.
  ParseLine, which in turn only ever reads from the script's OWN line
  buffer (ScrList.Scr[NextLine]) -- there is no existing entry point to
  parse an arbitrary, user-typed string (a breakpoint condition typed into
  a dialog, not a real script line) without either injecting it as a fake
  line into the live script buffer (real risk: could corrupt GOTO/GOSUB
  navigation, NextLine bookkeeping, or the Info/CallList frame-tracking
  that already has its own carefully-preserved quirks -- see
  EuoScriptStack.pas's header comment) or adding a whole second parsing
  path to the interpreter. Given conditional breakpoints exist to answer
  "did this variable reach some value yet", not to run arbitrary script
  expressions, this simple grammar covers the realistic case without that
  risk. TEuoInterpreter.GetVar (already thread-safe -- it takes its own
  lock internally, confirmed by reading it directly) is used to read the
  variable's live value, which handles every real variable kind (#system,
  %user, *persistent, !namespace) uniformly, exactly the way script code
  itself would read it.

  Comparison: if both sides parse as Int64, compares numerically; otherwise
  falls back to a case-insensitive string comparison (matching this
  language's general case-insensitivity elsewhere). A literal may be
  wrapped in double quotes to force a string comparison even when it looks
  numeric (e.g. %code = "007") -- the quotes are stripped, not compared
  literally, mirroring the SET command's own quoting convention scripters
  already know.

  Known, accepted limitation: operator detection is a simple left-to-right
  substring search (longest operators checked first, so ">=" is never
  mis-split as ">" followed by "="), not a real tokenizer -- a quoted
  literal that itself contains an operator character (e.g. %msg = ">100")
  will be mis-parsed. Not worth a real tokenizer for a deliberately-simple
  feature; realistic breakpoint conditions are short numeric/variable
  comparisons, not string literals containing comparison operators.

  A malformed or unparseable condition defaults to Result:=True (always
  break) rather than False -- if the condition can't be understood, it's
  safer to stop and let the user notice something's off than to silently
  never trigger a breakpoint that looks like it should be active.
}

{$mode delphi}{$H+}

interface

uses
  EuoInterpreter;

function EvalBreakCondition(Parser : TEuoInterpreter; const Cond : String) : Boolean;

implementation

uses
  SysUtils;

const
  // Longest-first: '>=' / '<=' must be matched before the bare '>' / '<'
  // they contain, or they'd be mis-split.
  Operators : array[0..5] of String = ('<>', '>=', '<=', '=', '>', '<');

////////////////////////////////////////////////////////////////////////////////
function EvalBreakCondition(Parser : TEuoInterpreter; const Cond : String) : Boolean;
var
  s, VarName, Op, ValStr, VarVal : String;
  P, i : Integer;
  VarNum, LitNum : Int64;
begin
  Result := True; // malformed/empty -- see header comment
  s := Trim(Cond);
  if s = '' then Exit;

  Op := '';
  P := 0;
  for i := Low(Operators) to High(Operators) do
  begin
    P := Pos(Operators[i], s);
    if P > 0 then
    begin
      Op := Operators[i];
      Break;
    end;
  end;
  if P = 0 then Exit;

  VarName := Trim(Copy(s, 1, P - 1));
  ValStr := Trim(Copy(s, P + Length(Op), MaxInt));
  if (VarName = '') or (ValStr = '') then Exit;
  if not (VarName[1] in ['#', '%', '*', '!']) then Exit;

  VarVal := Parser.GetVar(VarName);

  if (Length(ValStr) >= 2) and (ValStr[1] = '"') and (ValStr[Length(ValStr)] = '"') then
    ValStr := Copy(ValStr, 2, Length(ValStr) - 2);

  if TryStrToInt64(VarVal, VarNum) and TryStrToInt64(ValStr, LitNum) then
  begin
    if Op = '='  then Result := VarNum = LitNum
    else if Op = '<>' then Result := VarNum <> LitNum
    else if Op = '>'  then Result := VarNum > LitNum
    else if Op = '<'  then Result := VarNum < LitNum
    else if Op = '>=' then Result := VarNum >= LitNum
    else if Op = '<=' then Result := VarNum <= LitNum;
  end
  else
  begin
    if Op = '='  then Result := AnsiCompareText(VarVal, ValStr) = 0
    else if Op = '<>' then Result := AnsiCompareText(VarVal, ValStr) <> 0
    else if Op = '>'  then Result := AnsiCompareText(VarVal, ValStr) > 0
    else if Op = '<'  then Result := AnsiCompareText(VarVal, ValStr) < 0
    else if Op = '>=' then Result := AnsiCompareText(VarVal, ValStr) >= 0
    else if Op = '<=' then Result := AnsiCompareText(VarVal, ValStr) <= 0;
  end;
end;

end.
