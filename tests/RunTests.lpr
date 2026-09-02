program RunTests;

{$mode objfpc}{$H+}

uses
  Interfaces, // pulls in the LCL win32 widgetset registration; without this,
              // linking fails the moment any suite (transitively) pulls in
              // EuoMenu.pas's real LCL controls -- matching EasyUOReforged.lpr's own
              // uses clause, which needs it for the same reason.
  Classes, consoletestrunner,
  StackTests, TablesTests, WearablesTests, AccessTests, CstDbTests, TilesTests,
  EuoConversionTests, EuoTokensTests, EuoVariablesTests, EuoScriptStackTests,
  EuoCallStackFormatTests,
  EuoExpressionTests, EuoCommandRegistryTests, EuoInterpreterTests,
  EuoExecutorTests, UoScanVerTests, UoSelectorTests, UoVariablesTests,
  UoCommandsTests, UoEventsTests, LiveClientTests;

type
  TEasyUOTestRunner = class(TTestRunner)
  end;

var
  Application : TEasyUOTestRunner;

begin
  Application := TEasyUOTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'EasyUO Lazarus port - Phase 1 tests';
  Application.Run;
  Application.Free;
end.
