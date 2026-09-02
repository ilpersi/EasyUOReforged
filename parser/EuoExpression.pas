unit EuoExpression;

{
  Extracted from the original Delphi 7 parser\parser.pas's TOldParser.Eval, ported
  as close to verbatim as the extraction allows -- this is deliberately NOT turned
  into a real recursive-descent expression parser. The original is an iterative,
  paren-scoped, six-fixed-precedence-pass algorithm operating destructively on the
  token list; that shape is preserved exactly, since rewriting it is exactly the
  class of "optimization" the original author's own guide.txt warns breaks scripts
  in unpredictable ways.

  Exact behavioral contract, verified directly against the source (see
  EuoExpressionTests.pas for the tests that pin each one down):
  - Bracket-finding locates the FIRST ')' at/after the start index, then the
    NEAREST preceding '(' before it -- this correctly resolves the innermost pair
    when parens are nested, without ever building a real parse tree.
  - Each of the six precedence passes (unary !/ABS ; * / % ; + - ; comparisons ;
    && ; ||) scans left-to-right (or right-to-left for the unary pass) and
    collapses "A op B" into a single token holding the computed Int64 result,
    re-stringified via CompleteInt so later passes see a normal numeric token.
  - Booleans are encoded as Int64 -1 (true) / 0 (false), NOT 1/0 -- this must
    survive arithmetic (e.g. a comparison result can be added to a number).
  - =/<> fall back to a case-INSENSITIVE (StrU) string comparison when either
    side isn't a valid number. </>/<=/>= do NOT fall back to a string compare at
    all -- they simply evaluate False when either side isn't a valid number. This
    asymmetry is easy to miss and easy to "fix" into a symmetric rule by accident.
  - IN/NOTIN test substring containment using the uppercased (StrU) forms of both
    sides: "A IN B" means B contains A.
  - && and || are raw Int64 bitwise operations (not short-circuit logical ops),
    which only produces textbook boolean semantics because of the -1/0 encoding.
  - Unary '!' is `not X` -- Pascal's BITWISE NOT on an Int64, not a logical
    negation. This only happens to double as logical negation because -1 is
    all-ones and 0 is all-zeros in two's complement, so bitwise-inverting either
    one produces exactly the other. Applying '!' to a non-boolean-shaped value
    (e.g. "! 5") is NOT normalized to 0/-1 -- it produces whatever `not 5` (-6)
    is, verbatim. Do not "fix" this into a normalized logical-NOT; a first draft
    of this port did exactly that and was wrong.
  - || also matches the literal two-byte sequence that decodes as bytes 0xA6 0xA6
    ("broken bar" in the source file's original codepage) -- NOT the ASCII string
    "||" a second time. Written here as Chr(166)+Chr(166) to remove any doubt
    about source-file byte encoding surviving the port, per the migration plan.
}

{$mode delphi}{$H+}

interface
uses EuoTokens;

// Evaluates ParList starting at token index FP through the end of the list (or up
// to the next unconsumed ')' the caller is responsible for having balanced),
// exactly as the original TOldParser.Eval(FP: Integer) does against its own
// ParList field. Operates destructively: collapses the evaluated range down to a
// single result token in place.
procedure Eval(ParList : TParList; FP : Integer);

implementation
uses SysUtils;

////////////////////////////////////////////////////////////////////////////////
procedure CompleteInt(Pars : PTPars);
begin
  Pars.Str:=IntToStr(Pars.Int);
  Pars.StrU:=Pars.Str;
  Pars.IntValid:=True;
  Pars.CardValid:=Pars.Int>=0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure Eval(ParList : TParList; FP : Integer);
var
  Cnt       : Integer;
  iFrom,iTo : Integer;
  bEnd      : Boolean;
  bRes      : Boolean;
begin
  repeat

    {find brackets}
    iTo:=-1;
    for Cnt:=FP to ParList.Count-1 do
      if ParList[Cnt].StrU=')' then
    begin
      iTo:=Cnt;
      Break;
    end;
    iFrom:=-1;
    for Cnt:=iTo-1 downto FP do
      if ParList[Cnt].StrU='(' then
    begin
      iFrom:=Cnt;
      Break;
    end;
    if (iFrom=-1) or (iTo=-1) then
    begin
      iFrom:=FP;
      iTo:=ParList.Count-1;
      bEnd:=True;
    end
    else begin
      ParList.Delete(iTo);
      ParList.Delete(iFrom);
      Dec(iTo,2);
      bEnd:=False;
    end;

    {priority 5}
    Cnt:=iTo;
    while Cnt>iFrom do
    begin
      Dec(Cnt);

      if ParList[Cnt].StrU='!' then
        ParList[Cnt+1].Int:=not ParList[Cnt+1].Int
      else if ParList[Cnt].StrU='ABS' then
        ParList[Cnt+1].Int:=Abs(ParList[Cnt+1].Int)
      else Continue;

      ParList.Delete(Cnt);
      Dec(iTo);
      CompleteInt(ParList[Cnt]);
    end;

    {priority 4}
    Cnt:=iFrom;
    while Cnt<iTo-1 do
    begin
      Inc(Cnt);

      if ParList[Cnt].StrU='*' then
        ParList[Cnt+1].Int:=ParList[Cnt-1].Int*ParList[Cnt+1].Int
      else if ParList[Cnt].StrU='/' then
        if ParList[Cnt+1].Int<>0 then
          ParList[Cnt+1].Int:=ParList[Cnt-1].Int div ParList[Cnt+1].Int
        else ParList[Cnt+1].Int:=0
      else if ParList[Cnt].StrU='%' then
        if ParList[Cnt+1].Int<>0 then
          ParList[Cnt+1].Int:=ParList[Cnt-1].Int mod ParList[Cnt+1].Int
        else ParList[Cnt+1].Int:=0
      else Continue;

      Dec(Cnt);
      ParList.Delete(Cnt);
      ParList.Delete(Cnt);
      Dec(iTo,2);
      CompleteInt(ParList[Cnt]);
    end;

    {priority 3}
    Cnt:=iFrom;
    while Cnt<iTo-1 do
    begin
      Inc(Cnt);

      if ParList[Cnt].StrU='+' then
        ParList[Cnt+1].Int:=ParList[Cnt-1].Int+ParList[Cnt+1].Int
      else if ParList[Cnt].StrU='-' then
        ParList[Cnt+1].Int:=ParList[Cnt-1].Int-ParList[Cnt+1].Int
      else Continue;

      Dec(Cnt);
      ParList.Delete(Cnt);
      ParList.Delete(Cnt);
      Dec(iTo,2);
      CompleteInt(ParList[Cnt]);
    end;

    {priority 2}
    Cnt:=iFrom;
    while Cnt<iTo-1 do
    begin
      Inc(Cnt);

      if ParList[Cnt].StrU='=' then
        if ParList[Cnt-1].IntValid and ParList[Cnt+1].IntValid then
          bRes:=ParList[Cnt-1].Int=ParList[Cnt+1].Int
        else bRes:=ParList[Cnt-1].StrU=ParList[Cnt+1].StrU
      else if ParList[Cnt].StrU='<>' then
        if ParList[Cnt-1].IntValid and ParList[Cnt+1].IntValid then
          bRes:=ParList[Cnt-1].Int<>ParList[Cnt+1].Int
        else bRes:=ParList[Cnt-1].StrU<>ParList[Cnt+1].StrU
      else if ParList[Cnt].StrU='<' then
        if ParList[Cnt-1].IntValid and ParList[Cnt+1].IntValid then
          bRes:=ParList[Cnt-1].Int<ParList[Cnt+1].Int
        else bRes:=False
      else if ParList[Cnt].StrU='>' then
        if ParList[Cnt-1].IntValid and ParList[Cnt+1].IntValid then
          bRes:=ParList[Cnt-1].Int>ParList[Cnt+1].Int
        else bRes:=False
      else if (ParList[Cnt].StrU='<=') or (ParList[Cnt].StrU='=<') then
        if ParList[Cnt-1].IntValid and ParList[Cnt+1].IntValid then
          bRes:=ParList[Cnt-1].Int<=ParList[Cnt+1].Int
        else bRes:=False
      else if (ParList[Cnt].StrU='>=') or (ParList[Cnt].StrU='=>') then
        if ParList[Cnt-1].IntValid and ParList[Cnt+1].IntValid then
          bRes:=ParList[Cnt-1].Int>=ParList[Cnt+1].Int
        else bRes:=False
      else if ParList[Cnt].StrU='IN' then
        bRes:=Pos(ParList[Cnt-1].StrU,ParList[Cnt+1].StrU)>0
      else if ParList[Cnt].StrU='NOTIN' then
        bRes:=Pos(ParList[Cnt-1].StrU,ParList[Cnt+1].StrU)<1
      else Continue;

      if bRes then ParList[Cnt+1].Int:=-1
      else ParList[Cnt+1].Int:=0;

      Dec(Cnt);
      ParList.Delete(Cnt);
      ParList.Delete(Cnt);
      Dec(iTo,2);
      CompleteInt(ParList[Cnt]);
    end;

    {priority 1}
    Cnt:=iFrom;
    while Cnt<iTo-1 do
    begin
      Inc(Cnt);

      if ParList[Cnt].StrU='&&' then
        ParList[Cnt+1].Int:=ParList[Cnt-1].Int and ParList[Cnt+1].Int
      else Continue;

      Dec(Cnt);
      ParList.Delete(Cnt);
      ParList.Delete(Cnt);
      Dec(iTo,2);
      CompleteInt(ParList[Cnt]);
    end;

    {priority 0}
    Cnt:=iFrom;
    while Cnt<iTo-1 do
    begin
      Inc(Cnt);

      if (ParList[Cnt].StrU='||') or (ParList[Cnt].StrU=Chr(166)+Chr(166)) then
        ParList[Cnt+1].Int:=ParList[Cnt-1].Int or ParList[Cnt+1].Int
      else Continue;

      Dec(Cnt);
      ParList.Delete(Cnt);
      ParList.Delete(Cnt);
      Dec(iTo,2);
      CompleteInt(ParList[Cnt]);
    end;

  until bEnd;
end;

////////////////////////////////////////////////////////////////////////////////
end.
