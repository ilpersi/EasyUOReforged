unit uodef;

{
  Ported from the original Delphi 7 uo\uodef.pas -- the flat stdcall surface
  uo.dpr exports as uo.dll, one thin function per TUOWrap/TStack method,
  identified by an opaque "Hnd" handle that Open returns and every other call
  takes as its first parameter.

  One required fix, found while reading this file specifically for the 64-bit
  host decision (not a speculative "modernization"): the original's Hnd is
  Integer (32-bit signed) throughout, and Open implements it as
  "Result:=Integer(TUOWrap.Create)" -- i.e. the handle IS the object's raw
  heap pointer, truncated to 32 bits. That's safe on a 32-bit host (a pointer
  always fits in a 32-bit Integer) but silently corrupts on this migration's
  64-bit host: a real object allocated in a 64-bit process's heap commonly
  lives well above the 4GB boundary, so truncating it to Integer and later
  casting the truncated value back to TUOWrap(Hnd) would produce a wrong,
  dangling pointer -- not a theoretical risk, an near-certain one, the same
  class of bug already found and fixed in Phase 1 (access.pas's RPM/WPM byte-
  count parameter) and Phase 3 (uoscanver.pas's PSAPIHnd). Fixed by widening
  every Hnd parameter (and Open's return type) from Integer to PtrInt, FPC's
  signed pointer-sized integer type -- the exact same "handle is secretly a
  pointer" idiom, just correctly sized for this host's bitness.

  This does NOT attempt to preserve the exact old export-name decorations'
  literal meaning (see uo.lpr's header comment) -- Win64 has no stdcall name-
  decoration convention at all, so the original's hand-specified '_UOOpen@0'-
  style strings were already meaningless as byte-count annotations the
  moment this became a 64-bit build; they're kept only as literal alias
  strings in uo.lpr, in case any hypothetical consumer hardcoded them.

  Everything else -- the flat one-call-per-Stack-method shape, GetLString's
  var Len out-parameter, IsMultiThread/Set8087CW's exact initialization
  comments -- is unchanged.
}

{$mode delphi}{$H+}

interface
uses uowrap;

  function  Version : Integer; stdcall;
  function  Open : PtrInt; stdcall;
  procedure Close(Hnd : PtrInt); stdcall;
  function  Query(Hnd : PtrInt) : Integer; stdcall;
  function  Execute(Hnd : PtrInt) : Integer; stdcall;
  function  GetTop(Hnd : PtrInt) : Integer; stdcall;
  function  GetType(Hnd : PtrInt; Index : Integer) : Integer; stdcall;
  procedure Insert(Hnd : PtrInt; Index : Integer); stdcall;
  procedure PushNil(Hnd : PtrInt); stdcall;
  procedure PushBoolean(Hnd : PtrInt; Value : LongBool); stdcall;
  procedure PushPointer(Hnd : PtrInt; Value : Pointer); stdcall;
  procedure PushPtrOrNil(Hnd : PtrInt; Value : Pointer); stdcall;
  procedure PushInteger(Hnd : PtrInt; Value : Integer); stdcall;
  procedure PushDouble(Hnd : PtrInt; Value : Double); stdcall;
  procedure PushStrRef(Hnd : PtrInt; Value : PChar); stdcall;
  procedure PushStrVal(Hnd : PtrInt; Value : PChar); stdcall;
  procedure PushLStrRef(Hnd : PtrInt; Value : PChar; Len : Integer); stdcall;
  procedure PushLStrVal(Hnd : PtrInt; Value : PChar; Len : Integer); stdcall;
  procedure PushValue(Hnd : PtrInt; Index : Integer); stdcall;
  function  GetBoolean(Hnd : PtrInt; Index : Integer) : LongBool; stdcall;
  function  GetPointer(Hnd : PtrInt; Index : Integer) : Pointer; stdcall;
  function  GetInteger(Hnd : PtrInt; Index : Integer) : Integer; stdcall;
  function  GetDouble(Hnd : PtrInt; Index : Integer) : Double; stdcall;
  function  GetString(Hnd : PtrInt; Index : Integer) : PChar; stdcall;
  function  GetLString(Hnd : PtrInt; Index : Integer; var Len : Integer) : PChar; stdcall;
  procedure Remove(Hnd : PtrInt; Index : Integer); stdcall;
  procedure SetTop(Hnd : PtrInt; Index : Integer); stdcall;
  procedure Mark(Hnd : PtrInt); stdcall;
  procedure Clean(Hnd : PtrInt); stdcall;

implementation

////////////////////////////////////////////////////////////////////////////////
function Version : Integer;
begin
  Result:=3;
end;

////////////////////////////////////////////////////////////////////////////////
function Open : PtrInt;
begin
  Result:=PtrInt(TUOWrap.Create);
end;

////////////////////////////////////////////////////////////////////////////////
procedure Close(Hnd : PtrInt);
begin
  TUOWrap(Hnd).Free;
end;

////////////////////////////////////////////////////////////////////////////////
function Query(Hnd : PtrInt) : Integer;
begin
  Result:=TUOWrap(Hnd).Query;
end;

////////////////////////////////////////////////////////////////////////////////
function Execute(Hnd : PtrInt) : Integer;
begin
  Result:=TUOWrap(Hnd).Execute;
end;

////////////////////////////////////////////////////////////////////////////////
function GetTop(Hnd : PtrInt) : Integer;
begin
  Result:=TUOWrap(Hnd).Stack.GetTop;
end;

////////////////////////////////////////////////////////////////////////////////
function GetType(Hnd : PtrInt; Index : Integer) : Integer;
begin
  Result:=TUOWrap(Hnd).Stack.GetType(Index);
end;

////////////////////////////////////////////////////////////////////////////////
procedure Insert(Hnd : PtrInt; Index : Integer);
begin
  TUOWrap(Hnd).Stack.Insert(Index);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushNil(Hnd : PtrInt);
begin
  TUOWrap(Hnd).Stack.PushNil;
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushBoolean(Hnd : PtrInt; Value : LongBool);
begin
  TUOWrap(Hnd).Stack.PushBoolean(Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushPointer(Hnd : PtrInt; Value : Pointer);
begin
  TUOWrap(Hnd).Stack.PushPointer(Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushPtrOrNil(Hnd : PtrInt; Value : Pointer);
begin
  TUOWrap(Hnd).Stack.PushPtrOrNil(Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushInteger(Hnd : PtrInt; Value : Integer);
begin
  TUOWrap(Hnd).Stack.PushInteger(Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushDouble(Hnd : PtrInt; Value : Double);
begin
  TUOWrap(Hnd).Stack.PushDouble(Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushStrRef(Hnd : PtrInt; Value : PChar);
begin
  TUOWrap(Hnd).Stack.PushStrRef(Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushStrVal(Hnd : PtrInt; Value : PChar);
begin
  TUOWrap(Hnd).Stack.PushStrVal(Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushLStrRef(Hnd : PtrInt; Value : PChar; Len : Integer);
begin
  TUOWrap(Hnd).Stack.PushLStrRef(Value,Len);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushLStrVal(Hnd : PtrInt; Value : PChar; Len : Integer);
begin
  TUOWrap(Hnd).Stack.PushLStrVal(Value,Len);
end;

////////////////////////////////////////////////////////////////////////////////
procedure PushValue(Hnd : PtrInt; Index : Integer);
begin
  TUOWrap(Hnd).Stack.PushValue(Index);
end;

////////////////////////////////////////////////////////////////////////////////
function GetBoolean(Hnd : PtrInt; Index : Integer) : LongBool;
begin
  Result:=TUOWrap(Hnd).Stack.GetBoolean(Index);
end;

////////////////////////////////////////////////////////////////////////////////
function GetPointer(Hnd : PtrInt; Index : Integer) : Pointer;
begin
  Result:=TUOWrap(Hnd).Stack.GetPointer(Index);
end;

////////////////////////////////////////////////////////////////////////////////
function GetInteger(Hnd : PtrInt; Index : Integer) : Integer;
begin
  Result:=TUOWrap(Hnd).Stack.GetInteger(Index);
end;

////////////////////////////////////////////////////////////////////////////////
function GetDouble(Hnd : PtrInt; Index : Integer) : Double;
begin
  Result:=TUOWrap(Hnd).Stack.GetDouble(Index);
end;

////////////////////////////////////////////////////////////////////////////////
function GetString(Hnd : PtrInt; Index : Integer) : PChar;
begin
  Result:=TUOWrap(Hnd).Stack.GetString(Index);
end;

////////////////////////////////////////////////////////////////////////////////
function GetLString(Hnd : PtrInt; Index : Integer; var Len : Integer) : PChar;
begin
  Result:=TUOWrap(Hnd).Stack.GetLString(Index,Len);
end;

////////////////////////////////////////////////////////////////////////////////
procedure Remove(Hnd : PtrInt; Index : Integer);
begin
  TUOWrap(Hnd).Stack.Remove(Index);
end;

////////////////////////////////////////////////////////////////////////////////
procedure SetTop(Hnd : PtrInt; Index : Integer);
begin
  TUOWrap(Hnd).Stack.SetTop(Index);
end;

////////////////////////////////////////////////////////////////////////////////
procedure Mark(Hnd : PtrInt);
begin
  TUOWrap(Hnd).Stack.Mark;
end;

////////////////////////////////////////////////////////////////////////////////
procedure Clean(Hnd : PtrInt);
begin
  TUOWrap(Hnd).Stack.Clean;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  IsMultiThread:=True; //IMPORTANT: Activates multi-threading support for Delphi stack
  Set8087CW($27F);     //IMPORTANT: Disables floating point exceptions
end.
