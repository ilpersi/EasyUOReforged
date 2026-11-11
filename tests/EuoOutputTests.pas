unit EuoOutputTests;

{
  Tests for easyuo\euoutput.pas: the text of the editor's Output panel, where the lines
  scripts write with LOG appear. What one line looks like, and that the panel's text stays
  bounded however much a script logs.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, euoutput;

type
  TEuoOutputTests = class(TTestCase)
  published
    procedure TestLineHasTheTime;
    procedure TestLineNamesItsTabWhenAsked;
    procedure TestAppendKeepsTheNewestLines;
    procedure TestAppendOfMoreThanThePanelHolds;
    procedure TestAppendOfNothing;
  end;

implementation

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

initialization
  RegisterTest(TEuoOutputTests);

end.
