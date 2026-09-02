unit EuoExpressionTests;

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoTokens, EuoConversion, EuoExpression;

type
  TEuoExpressionTests = class(TTestCase)
  private
    L : TParList;
    procedure Tok(const Tokens : array of String);
    function EvalInt(FP : Integer = 0) : Int64;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestSimpleAddition;
    procedure TestOperatorPrecedenceMulOverAdd;
    procedure TestParenthesesOverridePrecedence;
    procedure TestNestedParentheses;
    procedure TestDivByZeroIsZeroNotError;
    procedure TestModByZeroIsZeroNotError;
    procedure TestBooleanEncodingIsMinusOneNotOne;
    procedure TestBooleanResultUsableInArithmetic;
    procedure TestEqualityStringFallbackCaseInsensitive;
    procedure TestEqualityNumericWhenBothNumeric;
    procedure TestLessThanFalseWhenNotBothNumeric;
    procedure TestGreaterThanFalseWhenNotBothNumeric;
    procedure TestLessEqualBothSpellings;
    procedure TestGreaterEqualBothSpellings;
    procedure TestInSubstring;
    procedure TestNotIn;
    procedure TestBitwiseAnd;
    procedure TestBitwiseOrAsciiSpelling;
    procedure TestBitwiseOrByteSequenceSpelling;
    procedure TestUnaryNotIsBitwiseNotOnMinusOneZero;
    procedure TestUnaryNotOnNonBooleanIsRawBitwiseNot;
    procedure TestUnaryAbs;
    procedure TestFullPrecedenceChain;
  end;

implementation

procedure TEuoExpressionTests.SetUp;
begin
  L := TParList.Create;
end;

procedure TEuoExpressionTests.TearDown;
begin
  L.Free;
end;

// Mirrors exactly how TOldParser.ParseLine populates each token, using the
// already-ported, already-tested EuoConversion.SToI64Def.
procedure TEuoExpressionTests.Tok(const Tokens : array of String);
var
  i : Integer;
  ConvRes : Boolean;
begin
  L.Clear;   // several test methods call Tok() more than once per test -- each
             // call is a fresh expression, not an append to the previous one.
  for i := 0 to High(Tokens) do
  begin
    L.AddNew;
    L.Last.Str := Tokens[i];
    L.Last.StrU := UpperCase(Tokens[i]);
    L.Last.Int := SToI64Def(Tokens[i], 0, ConvRes);
    L.Last.IntValid := ConvRes;
    L.Last.CardValid := ConvRes and (L.Last.Int >= 0);
  end;
end;

function TEuoExpressionTests.EvalInt(FP : Integer) : Int64;
begin
  Eval(L, FP);
  Result := L[FP].Int;
end;

procedure TEuoExpressionTests.TestSimpleAddition;
begin
  Tok(['2','+','3']);
  AssertEquals(Int64(5), EvalInt);
end;

procedure TEuoExpressionTests.TestOperatorPrecedenceMulOverAdd;
begin
  Tok(['2','+','3','*','4']);
  AssertEquals('* binds tighter than +', Int64(14), EvalInt);
end;

procedure TEuoExpressionTests.TestParenthesesOverridePrecedence;
begin
  Tok(['(','2','+','3',')','*','4']);
  AssertEquals(Int64(20), EvalInt);
end;

procedure TEuoExpressionTests.TestNestedParentheses;
begin
  Tok(['(','(','1','+','2',')','*','(','3','+','4',')',')','-','1']);
  AssertEquals(Int64(20), EvalInt);   // (3*7)-1 = 20
end;

procedure TEuoExpressionTests.TestDivByZeroIsZeroNotError;
begin
  Tok(['5','/','0']);
  AssertEquals('div-by-zero yields 0, not an exception', Int64(0), EvalInt);
end;

procedure TEuoExpressionTests.TestModByZeroIsZeroNotError;
begin
  Tok(['5','%','0']);
  AssertEquals(Int64(0), EvalInt);
end;

procedure TEuoExpressionTests.TestBooleanEncodingIsMinusOneNotOne;
begin
  Tok(['1','=','1']);
  AssertEquals('true is Int64 -1, not 1', Int64(-1), EvalInt);
  Tok(['1','=','2']);
  AssertEquals(Int64(0), EvalInt);
end;

procedure TEuoExpressionTests.TestBooleanResultUsableInArithmetic;
begin
  // SET %y (%x + %x) where %x holds the boolean result of (1=1) -- i.e. -1 + -1.
  // This is exactly the kind of thing an accidental 0/1 "normalization" breaks.
  Tok(['(','1','=','1',')','+','(','1','=','1',')']);
  AssertEquals(Int64(-2), EvalInt);
end;

procedure TEuoExpressionTests.TestEqualityStringFallbackCaseInsensitive;
begin
  Tok(['Hello','=','HELLO']);
  AssertEquals('non-numeric = falls back to case-insensitive string compare',
               Int64(-1), EvalInt);
  Tok(['Hello','=','World']);
  AssertEquals(Int64(0), EvalInt);
end;

procedure TEuoExpressionTests.TestEqualityNumericWhenBothNumeric;
begin
  Tok(['007','=','7']);
  AssertEquals('numeric compare, not string compare, when both sides parse',
               Int64(-1), EvalInt);
end;

procedure TEuoExpressionTests.TestLessThanFalseWhenNotBothNumeric;
begin
  // Confirmed asymmetry against the actual source: unlike =/<>, </> never fall
  // back to a string compare -- they're just False when either side isn't numeric.
  Tok(['Apple','<','Banana']);
  AssertEquals('< does NOT fall back to string compare, unlike = and <>',
               Int64(0), EvalInt);
end;

procedure TEuoExpressionTests.TestGreaterThanFalseWhenNotBothNumeric;
begin
  Tok(['Banana','>','Apple']);
  AssertEquals(Int64(0), EvalInt);
end;

procedure TEuoExpressionTests.TestLessEqualBothSpellings;
begin
  Tok(['3','<=','3']);
  AssertEquals(Int64(-1), EvalInt);
  Tok(['3','=<','3']);
  AssertEquals('=< is accepted as an alternate spelling of <=', Int64(-1), EvalInt);
end;

procedure TEuoExpressionTests.TestGreaterEqualBothSpellings;
begin
  Tok(['3','>=','3']);
  AssertEquals(Int64(-1), EvalInt);
  Tok(['3','=>','3']);
  AssertEquals('=> is accepted as an alternate spelling of >=', Int64(-1), EvalInt);
end;

procedure TEuoExpressionTests.TestInSubstring;
begin
  Tok(['Cat','IN','Concatenate']);
  AssertEquals('"Cat" is a substring of "Concatenate"', Int64(-1), EvalInt);
  Tok(['Dog','IN','Concatenate']);
  AssertEquals(Int64(0), EvalInt);
end;

procedure TEuoExpressionTests.TestNotIn;
begin
  Tok(['Dog','NOTIN','Concatenate']);
  AssertEquals(Int64(-1), EvalInt);
end;

procedure TEuoExpressionTests.TestBitwiseAnd;
begin
  Tok(['-1','&&','-1']);   // true && true
  AssertEquals(Int64(-1), EvalInt);
  Tok(['-1','&&','0']);    // true && false
  AssertEquals(Int64(0), EvalInt);
end;

procedure TEuoExpressionTests.TestBitwiseOrAsciiSpelling;
begin
  Tok(['0','||','-1']);
  AssertEquals(Int64(-1), EvalInt);
end;

procedure TEuoExpressionTests.TestBitwiseOrByteSequenceSpelling;
begin
  // The alternate OR spelling is the literal byte sequence 0xA6 0xA6, not the
  // ASCII string "||" typed twice -- confirmed against the actual source bytes.
  Tok(['0', Chr(166)+Chr(166), '-1']);
  AssertEquals(Int64(-1), EvalInt);
end;

procedure TEuoExpressionTests.TestUnaryNotIsBitwiseNotOnMinusOneZero;
begin
  Tok(['!','0']);
  AssertEquals('not 0 = -1 (all bits set)', Int64(-1), EvalInt);
  Tok(['!','-1']);
  AssertEquals('not -1 = 0 (all bits cleared)', Int64(0), EvalInt);
end;

procedure TEuoExpressionTests.TestUnaryNotOnNonBooleanIsRawBitwiseNot;
begin
  // Deliberately NOT "normalized" to 0/-1 -- this is what the original does.
  Tok(['!','5']);
  AssertEquals('not 5 = -6, verbatim bitwise NOT, not a logical negation', Int64(-6), EvalInt);
end;

procedure TEuoExpressionTests.TestUnaryAbs;
begin
  Tok(['ABS','-5']);
  AssertEquals(Int64(5), EvalInt);
end;

procedure TEuoExpressionTests.TestFullPrecedenceChain;
begin
  // ABS(-2) * 3 + 1 = 7 ; 7 <= 10 -> -1 ; -1 && -1 -> -1 ; -1 || 0 -> -1
  Tok(['ABS','-2','*','3','+','1','<=','10','&&','-1','||','0']);
  AssertEquals(Int64(-1), EvalInt);
end;

initialization
  RegisterTest(TEuoExpressionTests);
end.
