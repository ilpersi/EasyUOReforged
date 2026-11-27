unit EuoOutputTests;

{
  Tests for easyuo\euoutput.pas: the text of the editor's Output panel, where the lines
  scripts write with LOG appear. What one line looks like, that the panel's text stays
  bounded however much a script logs, and that a client text's one-byte letters become
  UTF-8 (EuoUtf8Text, which EUOCli prints through too).
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, LazUTF8, euoutput;

type
  TEuoOutputTests = class(TTestCase)
  published
    procedure TestLineHasTheTime;
    procedure TestLineNamesItsTabWhenAsked;
    procedure TestAppendKeepsTheNewestLines;
    procedure TestAppendOfMoreThanThePanelHolds;
    procedure TestAppendOfNothing;
    procedure TestUtf8TextKeepsUtf8AndReadsOtherBytesAsWindows1252;
    procedure TestUtf8TextIsAlwaysValidUtf8;
    procedure TestLineIsUtf8;
  end;

// The bytes of S in hex, "C3 A8": compared as text, so no code page conversion can hide a byte.
function Hex(const S : String) : String;

implementation

////////////////////////////////////////////////////////////////////////////////
function Hex(const S : String) : String;
var
  i : Integer;
begin
  Result:='';
  for i:=1 to Length(S) do
  begin
    if i>1 then Result:=Result+' ';
    Result:=Result+IntToHex(Byte(S[i]),2);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutputTests.TestLineHasTheTime;
begin
  AssertEquals('14:03:09  The sum is 15',
    EuoOutputLine(EncodeTime(14,3,9,0),'new1','The sum is 15',False));
  AssertEquals('an empty log line is the time alone','00:00:00  ',
    EuoOutputLine(EncodeTime(0,0,0,0),'new1','',False));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutputTests.TestLineNamesItsTabWhenAsked;
begin
  AssertEquals('09:30:00  loot.euo: Found 3',
    EuoOutputLine(EncodeTime(9,30,0,0),'loot.euo','Found 3',True));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutputTests.TestAppendKeepsTheNewestLines;
var
  Dest, More : TStringList;
begin
  Dest:=TStringList.Create;
  More:=TStringList.Create;
  try
    Dest.Add('1'); Dest.Add('2'); Dest.Add('3');
    More.Add('4'); More.Add('5');
    EuoAppendOutput(Dest,More,10);
    AssertEquals('room for all','1,2,3,4,5',Dest.CommaText);
    EuoAppendOutput(Dest,More,6);
    AssertEquals('the oldest go','2,3,4,5,4,5',Dest.CommaText);
  finally
    More.Free;
    Dest.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutputTests.TestAppendOfMoreThanThePanelHolds;
var
  Dest, More : TStringList;
  i          : Integer;
begin
  Dest:=TStringList.Create;
  More:=TStringList.Create;
  try
    Dest.Add('old');
    for i:=1 to 8 do More.Add(IntToStr(i));
    EuoAppendOutput(Dest,More,3);
    AssertEquals('6,7,8',Dest.CommaText);
    EuoAppendOutput(Dest,More,8);
    AssertEquals('exactly as many as it holds','1,2,3,4,5,6,7,8',Dest.CommaText);
  finally
    More.Free;
    Dest.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoOutputTests.TestAppendOfNothing;
var
  Dest, More : TStringList;
begin
  Dest:=TStringList.Create;
  More:=TStringList.Create;
  try
    Dest.Add('kept');
    EuoAppendOutput(Dest,More,1);
    AssertEquals('kept',Dest.CommaText);
    AssertEquals('the panel keeps 5000 lines',5000,OUTPUT_MAX_LINES);
  finally
    More.Free;
    Dest.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Client texts (#Property, the journal, #SysMsg) hold an accented letter as its one Latin-1
// byte; the script's own text and ScanBuffs' are UTF-8. Both must print as UTF-8.
procedure TEuoOutputTests.TestUtf8TextKeepsUtf8AndReadsOtherBytesAsWindows1252;
begin
  AssertEquals('ASCII as it is','Spada di ferro',EuoUtf8Text('Spada di ferro'));
  AssertEquals('nothing','',EuoUtf8Text(''));
  AssertEquals('UTF-8 as it is','C3 A8',Hex(EuoUtf8Text(#$C3#$A8)));
  AssertEquals('three-byte UTF-8 as it is','E2 82 AC',Hex(EuoUtf8Text(#$E2#$82#$AC)));
  AssertEquals('four-byte UTF-8 as it is','F0 9F 98 80',Hex(EuoUtf8Text(#$F0#$9F#$98#$80)));
  AssertEquals('Latin-1 e grave','C3 A8',Hex(EuoUtf8Text(#$E8)));
  AssertEquals('Latin-1 a grave','C3 A0',Hex(EuoUtf8Text(#$E0)));
  AssertEquals('Latin-1 degree sign','C2 B0',Hex(EuoUtf8Text(#$B0)));
  AssertEquals('Windows-1252 euro sign','E2 82 AC',Hex(EuoUtf8Text(#$80)));
  AssertEquals('a byte Windows-1252 leaves undefined: Latin-1','C2 81',Hex(EuoUtf8Text(#$81)));
  AssertEquals('a continuation byte alone','C2 A8',Hex(EuoUtf8Text(#$A8)));
  AssertEquals('a UTF-8 start with nothing after it','78 C3 83',Hex(EuoUtf8Text('x'#$C3)));
  AssertEquals('an overlong form is not UTF-8: two Windows-1252 bytes','C3 80 E2 82 AC',Hex(EuoUtf8Text(#$C0#$80)));
  AssertEquals('a UTF-16 surrogate is not UTF-8','C3 AD C2 A0 E2 82 AC',Hex(EuoUtf8Text(#$ED#$A0#$80)));
  AssertEquals('a UTF-8 literal and a client text on one line',
    Hex('Spada '#$C3#$A8' / P: Spada '#$C3#$A8' 5'#$C2#$B0),
    Hex(EuoUtf8Text('Spada '#$C3#$A8' / P: Spada '#$E8' 5'#$B0)));
end;

////////////////////////////////////////////////////////////////////////////////
// Every byte, and every pair of bytes, comes out as UTF-8 a strict reader accepts.
procedure TEuoOutputTests.TestUtf8TextIsAlwaysValidUtf8;
var
  a, b : Integer;
  S, U : String;
begin
  for a:=0 to 255 do
  begin
    U:=EuoUtf8Text('x'+Chr(a));
    AssertEquals('byte '+IntToHex(a,2)+' gives '+Hex(U),-1,FindInvalidUTF8Codepoint(PChar(U),Length(U)));
    if a<$80 then AssertEquals('ASCII byte '+IntToHex(a,2),Hex('x'+Chr(a)),Hex(U));
    for b:=0 to 255 do
    begin
      S:=Chr(a)+Chr(b);
      U:=EuoUtf8Text(S);
      if FindInvalidUTF8Codepoint(PChar(U),Length(U))<>-1 then
        Fail('bytes '+Hex(S)+' give '+Hex(U));
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// The LCL shows invalid UTF-8 as '?': the panel's line is UTF-8, its tab name too.
procedure TEuoOutputTests.TestLineIsUtf8;
begin
  AssertEquals(Hex('14:03:09  Spada '#$C3#$A8),
    Hex(EuoOutputLine(EncodeTime(14,3,9,0),'new1','Spada '#$E8,False)));
  AssertEquals(Hex('14:03:09  caccia'#$C3#$A0'.euo: 5'#$C2#$B0),
    Hex(EuoOutputLine(EncodeTime(14,3,9,0),'caccia'#$C3#$A0'.euo','5'#$B0,True)));
end;

initialization
  RegisterTest(TEuoOutputTests);

end.
