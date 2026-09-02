unit EuoCallStackFormatTests;

{
  Tests for EuoCallStackFormat.pas's FormatCallStack -- the pure formatter
  backing the new call-stack GUI panel (not present in the original Delphi 7
  app). Fully synchronous, no interpreter/executor involved, matching
  EuoScriptStackTests.pas's own "TScriptList alone is fully unit-testable"
  precedent.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoScriptStack, EuoCallStackFormat;

type
  TEuoCallStackFormatTests = class(TTestCase)
  published
    procedure TestBaseLevelOnlyReturnsOneEntry;
    procedure TestGosubNestingUnwindsInnermostFirst;
    procedure TestCallFrameNestingUnwindsInnermostFirst;
    procedure TestMixedCallAndGosubNesting;
    procedure TestReturnedListObjectsCarryLineNumbers;
    procedure TestCallerOwnsAndMustFreeTheResult;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallStackFormatTests.TestBaseLevelOnlyReturnsOneEntry;
var
  S : TScriptList;
  R : TStringList;
begin
  S := TScriptList.Create;
  try
    R := FormatCallStack(S,5);
    try
      AssertEquals(1, R.Count);
      AssertEquals('#0  main  (line 5)', R[0]);
      AssertEquals(PtrUInt(5), PtrUInt(R.Objects[0]));
    finally R.Free; end;
  finally S.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallStackFormatTests.TestGosubNestingUnwindsInnermostFirst;
var
  S : TScriptList;
  R : TStringList;
begin
  S := TScriptList.Create;
  try
    S.AddSub(10,'Sub1');
    S.AddSub(20,'Sub2');
    R := FormatCallStack(S,42); // 42 = the live line inside Sub2
    try
      AssertEquals(3, R.Count);
      AssertEquals('#0  Sub2  (line 42)', R[0]);
      AssertEquals('#1  Sub1  (line 20)', R[1]);
      AssertEquals('#2  main  (line 10)', R[2]);
    finally R.Free; end;
  finally S.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallStackFormatTests.TestCallFrameNestingUnwindsInnermostFirst;
var
  S : TScriptList;
  R : TStringList;
begin
  S := TScriptList.Create;
  try
    S.AddCall(3,'a.txt');
    S.AddCall(8,'b.txt');
    R := FormatCallStack(S,99);
    try
      AssertEquals(3, R.Count);
      AssertEquals('#0  b.txt  (line 99)', R[0]);
      AssertEquals('#1  a.txt  (line 8)', R[1]);
      AssertEquals('#2  main  (line 3)', R[2]);
    finally R.Free; end;
  finally S.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallStackFormatTests.TestMixedCallAndGosubNesting;
var
  S : TScriptList;
  R : TStringList;
begin
  S := TScriptList.Create;
  try
    S.AddSub(1,'L0Sub');
    S.AddCall(15,'a.txt'); // fresh call frame -- L0Sub's own entry is unaffected
    S.AddSub(4,'L1Sub');
    R := FormatCallStack(S,77);
    try
      AssertEquals(4, R.Count);
      AssertEquals('#0  L1Sub  (line 77)', R[0]);
      AssertEquals('#1  a.txt  (line 4)', R[1]);
      AssertEquals('#2  L0Sub  (line 15)', R[2]);
      AssertEquals('#3  main  (line 1)', R[3]);
    finally R.Free; end;
  finally S.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallStackFormatTests.TestReturnedListObjectsCarryLineNumbers;
var
  S : TScriptList;
  R : TStringList;
begin
  S := TScriptList.Create;
  try
    S.AddSub(1,'L0Sub');
    S.AddCall(15,'a.txt');
    S.AddSub(4,'L1Sub');
    R := FormatCallStack(S,77);
    try
      // Guards against a future edit changing the format string without
      // updating Objects[] in lockstep (or vice versa) -- the GUI panel
      // reads Objects[], not the formatted string.
      AssertEquals(PtrUInt(77), PtrUInt(R.Objects[0]));
      AssertEquals(PtrUInt(4),  PtrUInt(R.Objects[1]));
      AssertEquals(PtrUInt(15), PtrUInt(R.Objects[2]));
      AssertEquals(PtrUInt(1),  PtrUInt(R.Objects[3]));
    finally R.Free; end;
  finally S.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCallStackFormatTests.TestCallerOwnsAndMustFreeTheResult;
var
  S : TScriptList;
  R : TStringList;
begin
  S := TScriptList.Create;
  try
    R := FormatCallStack(S,1);
    R.Free; // must not raise -- caller genuinely owns this instance
  finally S.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoCallStackFormatTests);
end.
