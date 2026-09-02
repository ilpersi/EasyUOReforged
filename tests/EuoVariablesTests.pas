unit EuoVariablesTests;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoVariables;

type
  TEuoVariablesTests = class(TTestCase)
  published
    // TVarList
    procedure TestVarListSetGetRoundTrip;
    procedure TestVarListCaseInsensitiveNames;
    procedure TestVarListUnsetReturnsNA;
    procedure TestVarListOverwrite;
    procedure TestVarListListVarsPrefix;
    procedure TestVarListListVarsStripsPrefix;
    procedure TestVarListDelVarsExact;
    procedure TestVarListDelVarsPrefix;
    // TVars sigil dispatch
    procedure TestUserVarSigil;
    procedure TestNamespaceLocalSigil;
    procedure TestNamespaceDefaultsToLocalStd;
    procedure TestNamespaceSwitchLocalGlobal;
    // The critical one: NSGlobal is a real process-wide singleton
    procedure TestNSGlobalSharedAcrossInstances;
    procedure TestNSLocalIsPerInstance;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVariablesTests.TestVarListSetGetRoundTrip;
var L : TVarList;
begin
  L := TVarList.Create;
  try
    L.SetVar('FOO','bar');
    AssertEquals('bar', L.GetVar('FOO'));
  finally L.Free; end;
end;

procedure TEuoVariablesTests.TestVarListCaseInsensitiveNames;
var L : TVarList;
begin
  L := TVarList.Create;
  try
    L.SetVar('Foo','bar');
    AssertEquals('bar', L.GetVar('foo'));
    AssertEquals('bar', L.GetVar('FOO'));
  finally L.Free; end;
end;

procedure TEuoVariablesTests.TestVarListUnsetReturnsNA;
var L : TVarList;
begin
  L := TVarList.Create;
  try
    AssertEquals('N/A', L.GetVar('NEVERSET'));
  finally L.Free; end;
end;

procedure TEuoVariablesTests.TestVarListOverwrite;
var L : TVarList;
begin
  L := TVarList.Create;
  try
    L.SetVar('X','1');
    L.SetVar('X','2');
    AssertEquals('2', L.GetVar('X'));
  finally L.Free; end;
end;

procedure TEuoVariablesTests.TestVarListListVarsPrefix;
var
  L : TVarList;
  S : String;
begin
  L := TVarList.Create;
  try
    L.SetVar('AB1','1');
    L.SetVar('AB2','2');
    L.SetVar('ZZ','9');
    S := L.ListVars('AB');
    AssertTrue(Pos('1'#13#10,S) > 0);
    AssertTrue(Pos('2',S) > 0);
    AssertTrue('non-matching prefix must not appear', Pos('9',S) < 1);
  finally L.Free; end;
end;

procedure TEuoVariablesTests.TestVarListListVarsStripsPrefix;
var
  L : TVarList;
  S : String;
begin
  L := TVarList.Create;
  try
    L.SetVar('NS~ITEM','42');
    S := L.ListVars('NS~');
    AssertEquals('ITEM: 42', 'ITEM', Trim(S));
  finally L.Free; end;
end;

procedure TEuoVariablesTests.TestVarListDelVarsExact;
var L : TVarList;
begin
  L := TVarList.Create;
  try
    L.SetVar('AB','1');
    L.SetVar('ABC','2');
    L.DelVars('AB',True);
    AssertEquals('N/A', L.GetVar('AB'));
    AssertEquals('exact delete must not remove the longer prefix match', '2', L.GetVar('ABC'));
  finally L.Free; end;
end;

procedure TEuoVariablesTests.TestVarListDelVarsPrefix;
var L : TVarList;
begin
  L := TVarList.Create;
  try
    L.SetVar('AB1','1');
    L.SetVar('AB2','2');
    L.SetVar('ZZ','9');
    L.DelVars('AB',False);
    AssertEquals('N/A', L.GetVar('AB1'));
    AssertEquals('N/A', L.GetVar('AB2'));
    AssertEquals('9', L.GetVar('ZZ'));
  finally L.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVariablesTests.TestUserVarSigil;
var V : TVars;
begin
  V := TVars.Create;
  try
    V.SetVar('%myvar','42');
    AssertEquals('42', V.GetVar('%myvar'));
    AssertEquals('routed to UserVars, visible without the sigil too',
                 '42', V.UserVars.GetVar('%myvar'));
  finally V.Free; end;
end;

procedure TEuoVariablesTests.TestNamespaceLocalSigil;
var V : TVars;
begin
  V := TVars.Create;
  try
    V.SetVar('!x','hello');
    AssertEquals('hello', V.GetVar('!x'));
  finally V.Free; end;
end;

procedure TEuoVariablesTests.TestNamespaceDefaultsToLocalStd;
var V : TVars;
begin
  V := TVars.Create;
  try
    AssertTrue('defaults to local namespace type', V.NSType = local);
    AssertEquals('std', V.NSName);
    V.SetVar('!x','v');
    // stored under key "!std~X" in NSLocal -- confirmed indirectly via GetVar round-trip
    AssertEquals('v', V.NSLocal.GetVar('!std~x'));
  finally V.Free; end;
end;

procedure TEuoVariablesTests.TestNamespaceSwitchLocalGlobal;
var V : TVars;
begin
  V := TVars.Create;
  try
    V.NSName := 'myns';
    V.NSType := global;
    V.SetVar('!x','g');
    AssertEquals('g', V.NSGlobal.GetVar('!myns~x'));
    AssertEquals('N/A', V.NSLocal.GetVar('!myns~x'));
  finally V.Free; end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVariablesTests.TestNSGlobalSharedAcrossInstances;
var
  V1, V2 : TVars;
begin
  // The test that would fail loudly if a future "cleanup" ever made NSGlobal a
  // fresh per-instance TVarList instead of the deliberate process-wide singleton.
  V1 := TVars.Create;
  V2 := TVars.Create;
  try
    V1.NSType := global;
    V2.NSType := global;
    V1.NSName := 'shared';
    V2.NSName := 'shared';

    V1.SetVar('!ping','from-v1');
    AssertEquals('a second, independently-created TVars instance sees the write '+
                 'with no explicit wiring in this test',
                 'from-v1', V2.GetVar('!ping'));
  finally
    V1.Free;
    V2.Free;
  end;
end;

procedure TEuoVariablesTests.TestNSLocalIsPerInstance;
var
  V1, V2 : TVars;
begin
  V1 := TVars.Create;
  V2 := TVars.Create;
  try
    V1.SetVar('!local1','only-in-v1');
    AssertEquals('N/A', V2.GetVar('!local1'));
  finally
    V1.Free;
    V2.Free;
  end;
end;

initialization
  RegisterTest(TEuoVariablesTests);
end.
