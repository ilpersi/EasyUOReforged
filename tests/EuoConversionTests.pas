unit EuoConversionTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoConversion;

type
  TEuoConversionTests = class(TTestCase)
  published
    procedure TestIsNumberValidDecimal;
    procedure TestIsNumberValidHex;
    procedure TestIsNumberSignedDecimal;
    procedure TestIsNumberRejectsEmpty;
    procedure TestIsNumberRejectsLoneSign;
    procedure TestIsNumberRejectsBadChars;
    procedure TestIsNumberRejectsTooLong;
    procedure TestReplaceStrBasic;
    procedure TestReplaceStrMultipleOccurrences;
    procedure TestReplaceStrNoMatch;
    procedure TestSToCDefValid;
    procedure TestSToCDefRejectsNegative;
    procedure TestSToCDefDefaultOnInvalid;
    procedure TestSToI64DefNegativeAllowed;
    procedure TestSys26ZeroOracle;
    procedure TestSys26OneOracle;
    procedure TestSys26RoundTrip;
    procedure TestSys26CaseInsensitive;
    procedure TestSys26RejectsOutOfRange;
    procedure TestSToColNumeric;
    procedure TestSToColNamedColor;
    procedure TestSToColInvalid;
  end;

implementation

procedure TEuoConversionTests.TestIsNumberValidDecimal;
begin
  AssertTrue(IsNumber('12345'));
  AssertTrue(IsNumber('  42  '));  // Trim allows sloppy format
end;

procedure TEuoConversionTests.TestIsNumberValidHex;
begin
  AssertTrue(IsNumber('$1F4'));
  AssertTrue(IsNumber('$abc'));
end;

procedure TEuoConversionTests.TestIsNumberSignedDecimal;
begin
  AssertTrue(IsNumber('-123'));
  AssertTrue(IsNumber('+123'));
end;

procedure TEuoConversionTests.TestIsNumberRejectsEmpty;
begin
  AssertFalse(IsNumber(''));
  AssertFalse(IsNumber('   '));
end;

procedure TEuoConversionTests.TestIsNumberRejectsLoneSign;
begin
  AssertFalse(IsNumber('-'));
  AssertFalse(IsNumber('+'));
  AssertFalse(IsNumber('$'));
end;

procedure TEuoConversionTests.TestIsNumberRejectsBadChars;
begin
  AssertFalse(IsNumber('12a'));
  AssertFalse(IsNumber('1.5'));
  AssertFalse(IsNumber('$1G'));
end;

procedure TEuoConversionTests.TestIsNumberRejectsTooLong;
begin
  AssertFalse('19-digit plain decimal exceeds the 18-digit cap',
              IsNumber('1234567890123456789'));
  AssertTrue('19-digit SIGNED decimal is within its own 19-char cap',
             IsNumber('+123456789012345678'));
  AssertFalse('18 total chars ($+17 hex digits) exceeds the 16-char-total cap',
              IsNumber('$12345678901234567'));
end;

procedure TEuoConversionTests.TestReplaceStrBasic;
begin
  AssertEquals('hello CRLF world', ReplaceStr('hello $ world','$','CRLF'));
end;

procedure TEuoConversionTests.TestReplaceStrMultipleOccurrences;
begin
  AssertEquals('a-b-c', ReplaceStr('a b c',' ','-'));
end;

procedure TEuoConversionTests.TestReplaceStrNoMatch;
begin
  AssertEquals('unchanged', ReplaceStr('unchanged','$','X'));
end;

procedure TEuoConversionTests.TestSToCDefValid;
begin
  AssertEquals(Cardinal(42), SToCDef('42',0));
end;

procedure TEuoConversionTests.TestSToCDefRejectsNegative;
begin
  // Cardinal can't hold a negative -- SToCDef's own explicit check returns the default
  AssertEquals(Cardinal(99), SToCDef('-5',99));
end;

procedure TEuoConversionTests.TestSToCDefDefaultOnInvalid;
begin
  AssertEquals(Cardinal(7), SToCDef('notanumber',7));
end;

procedure TEuoConversionTests.TestSToI64DefNegativeAllowed;
begin
  AssertEquals(Int64(-5), SToI64Def('-5',0));
end;

procedure TEuoConversionTests.TestSys26ZeroOracle;
begin
  // Self-confirming against parser.pas's own #EnemyID getter, which special-cases
  // exactly 'YC' back to 'N/A' -- only makes sense if CardToSys26(0)='YC'.
  AssertEquals('YC', CardToSys26(0));
  AssertEquals(Cardinal(0), Sys26ToCard('YC'));
end;

procedure TEuoConversionTests.TestSys26OneOracle;
begin
  AssertEquals('XC', CardToSys26(1));
  AssertEquals(Cardinal(1), Sys26ToCard('XC'));
end;

procedure TEuoConversionTests.TestSys26RoundTrip;
var
  i : Cardinal;
  vals : array[0..4] of Cardinal;
begin
  vals[0]:=12345; vals[1]:=1; vals[2]:=$FFFFFFFF; vals[3]:=1000000; vals[4]:=42;
  for i:=0 to High(vals) do
    AssertEquals(vals[i], Sys26ToCard(CardToSys26(vals[i])));
end;

procedure TEuoConversionTests.TestSys26CaseInsensitive;
begin
  AssertEquals(Sys26ToCard('yc'), Sys26ToCard('YC'));
end;

procedure TEuoConversionTests.TestSys26RejectsOutOfRange;
var ConvRes : Boolean;
begin
  Sys26ToCard('1', ConvRes);   // '1' isn't in A..Z, must fail conversion
  AssertFalse(ConvRes);
end;

procedure TEuoConversionTests.TestSToColNumeric;
begin
  AssertEquals(255, SToCol('255'));
end;

procedure TEuoConversionTests.TestSToColNamedColor;
var ConvRes : Boolean;
begin
  SToCol('Red', ConvRes);
  AssertTrue('a valid VCL/LCL color name resolves', ConvRes);
end;

procedure TEuoConversionTests.TestSToColInvalid;
var ConvRes : Boolean;
begin
  SToCol('NotAColorName123', ConvRes);
  AssertFalse(ConvRes);
end;

initialization
  RegisterTest(TEuoConversionTests);
end.
