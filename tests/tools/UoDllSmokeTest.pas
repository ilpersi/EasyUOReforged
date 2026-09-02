program UoDllSmokeTest;

{
  Standalone LoadLibrary-and-call smoke test for uo.dll, per the migration
  plan's explicit Phase 6 instruction ("verify decorated names/calling
  convention with a LoadLibrary-and-call smoke test"). Deliberately does NOT
  link against uowrap.pas/uodef.pas directly -- it loads uo.dll exactly the
  way a genuine external consumer would, resolving every export by its exact
  decorated name string and calling through raw stdcall function-pointer
  types, so a real mismatch in the exported name table or calling convention
  would show up here the same way it would for a real external tool.

  Covers: Version, Open/Close, the stack Push*/Get* round trip (PushInteger/
  GetInteger, PushStrVal/GetString, Mark/Clean), and Query's "GetFeatures"/
  "GetInit"/"GetCommands" commands (client-independent, so meaningful with no
  live UO client attached). Does not exercise Execute's MGet/MSet/MCall
  paths, which need a live client to mean anything beyond what Phases 3-4's
  own unit tests already cover against the real engine underneath.
}

{$mode delphi}{$H+}
uses Windows, SysUtils;

var
  Passed, Failed : Integer;

procedure Check(Cond : Boolean; const Msg : String);
begin
  if Cond then
  begin
    Inc(Passed);
    WriteLn('  OK   ', Msg);
  end
  else begin
    Inc(Failed);
    WriteLn('  FAIL ', Msg);
  end;
end;

type
  TVersion      = function : Integer; stdcall;
  TOpen         = function : PtrInt; stdcall;
  TClose        = procedure(Hnd : PtrInt); stdcall;
  TQuery        = function(Hnd : PtrInt) : Integer; stdcall;
  TExecute      = function(Hnd : PtrInt) : Integer; stdcall;
  TGetTop       = function(Hnd : PtrInt) : Integer; stdcall;
  TSetTop       = procedure(Hnd : PtrInt; Index : Integer); stdcall;
  TPushInteger  = procedure(Hnd : PtrInt; Value : Integer); stdcall;
  TGetInteger   = function(Hnd : PtrInt; Index : Integer) : Integer; stdcall;
  TPushStrVal   = procedure(Hnd : PtrInt; Value : PChar); stdcall;
  TGetString    = function(Hnd : PtrInt; Index : Integer) : PChar; stdcall;

var
  DllHnd       : THandle;
  Version      : TVersion;
  Open         : TOpen;
  Close        : TClose;
  Query        : TQuery;
  Execute      : TExecute;
  GetTop       : TGetTop;
  SetTop       : TSetTop;
  PushInteger  : TPushInteger;
  GetInteger   : TGetInteger;
  PushStrVal   : TPushStrVal;
  GetString    : TGetString;

  Hnd          : PtrInt;
  DllPath      : String;

function Load(const DecoratedName : String) : Pointer;
begin
  Result := GetProcAddress(DllHnd, PChar(DecoratedName));
  if Result = nil then
  begin
    WriteLn('  FAIL GetProcAddress("', DecoratedName, '") returned nil');
    Inc(Failed);
  end;
end;

begin
  Passed := 0;
  Failed := 0;

  DllPath := ExtractFilePath(ParamStr(0)) + 'uo.dll';
  if not FileExists(DllPath) then
    DllPath := 'uo.dll';

  WriteLn('Loading ', DllPath, ' ...');
  DllHnd := LoadLibrary(PChar(DllPath));
  if DllHnd = 0 then
  begin
    WriteLn('FAIL: LoadLibrary failed, GetLastError=', GetLastError);
    Halt(1);
  end;

  Version     := TVersion(Load('_UOVersion@0'));
  Open        := TOpen(Load('_UOOpen@0'));
  Close       := TClose(Load('_UOClose@4'));
  Query       := TQuery(Load('_UOQuery@4'));
  Execute     := TExecute(Load('_UOExecute@4'));
  GetTop      := TGetTop(Load('_UOGetTop@4'));
  SetTop      := TSetTop(Load('_UOSetTop@8'));
  PushInteger := TPushInteger(Load('_UOPushInteger@8'));
  GetInteger  := TGetInteger(Load('_UOGetInteger@8'));
  PushStrVal  := TPushStrVal(Load('_UOPushStrVal@8'));
  GetString   := TGetString(Load('_UOGetString@8'));

  if Failed > 0 then
  begin
    WriteLn('Aborting: not every export resolved.');
    FreeLibrary(DllHnd);
    Halt(1);
  end;

  Check(Version() = 3, 'Version() = 3');

  Hnd := Open();
  Check(Hnd <> 0, 'Open() returned a non-zero handle');

  SetTop(Hnd, 0);
  PushInteger(Hnd, 12345);
  Check(GetTop(Hnd) = 1, 'GetTop after one PushInteger = 1');
  Check(GetInteger(Hnd, 1) = 12345, 'GetInteger(1) round-trips 12345');

  SetTop(Hnd, 0);
  PushStrVal(Hnd, 'hello uo.dll');
  Check(StrPas(GetString(Hnd, 1)) = 'hello uo.dll', 'PushStrVal/GetString round-trips a string');

  // Query is client-independent for these three commands (pure metadata).
  // Query internally Marks at the command-name argument then Cleans it away
  // before returning, so its pushed result(s) end up at index 1, not 2 --
  // confirmed by reading TUOWrap.Query, not assumed.
  SetTop(Hnd, 0);
  PushStrVal(Hnd, 'GetFeatures');
  Check(Query(Hnd) = 0, 'Query("GetFeatures") returns RES_OK');
  Check((GetTop(Hnd) = 1) and (StrPas(GetString(Hnd, 1)) = 'CEIKD'),
    'Query("GetFeatures") pushed "CEIKD"');

  SetTop(Hnd, 0);
  PushStrVal(Hnd, 'GetInit');
  Check(Query(Hnd) = 0, 'Query("GetInit") returns RES_OK');
  Check(GetTop(Hnd) = 1, 'Query("GetInit") pushed exactly one result (the Lua bootstrap string)');

  SetTop(Hnd, 0);
  PushStrVal(Hnd, 'GetCommands');
  Check(Query(Hnd) = 0, 'Query("GetCommands") returns RES_OK');
  Check(GetTop(Hnd) >= 1, 'Query("GetCommands") pushed at least one command name');

  SetTop(Hnd, 0);
  WriteLn('About to call Close...'); Flush(Output);
  Close(Hnd);
  WriteLn('Close returned. About to call FreeLibrary...'); Flush(Output);
  FreeLibrary(DllHnd);
  WriteLn('FreeLibrary returned.'); Flush(Output);

  WriteLn;
  WriteLn(Passed, ' passed, ', Failed, ' failed.');
  if Failed > 0 then Halt(1);
end.
