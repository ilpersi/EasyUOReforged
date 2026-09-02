unit stack;

{
  Ported from the original Delphi 7 uo\stack.pas essentially verbatim -- a small
  Lua-C-API-style stack machine (TStack) with no OS dependency and no bitness-sensitive
  pointer tricks. Integer/Double/string values are stored by boxing them into the
  Pointer-typed DA list (small ordinals cast directly into the pointer slot; Doubles and
  length-prefixed strings heap-allocated via New/GetMem, tagged via the parallel DT type
  list). This boxing works identically on Win64: Pointer is simply wider, and every
  round-trip (e.g. PushInteger/GetInteger casting Integer<->Pointer) only ever inspects
  the low 32 bits on the read side, so the upper bits of the wider pointer slot never
  matter. Verified directly (not just reasoned about) -- see
  Lazarus\tests\StackTests.pas, which specifically covers negative Integer round-trips.
}

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes;

const
  T_NIL         = 0;                                                            // types returned by GetType()
  T_BOOLEAN     = 1;
  T_POINTER     = 2;
  T_NUMBER      = 3;
  T_STRING      = 4;

type
  TStack        = class(TObject)
  private
    Marker      : Cardinal;                                                     // used for Mark() and Clean()
    DT          : TList;                                                        // Element Types
    DA          : TList;                                                        // Element Contents or Addresses
    function    GetIndex(Index : Integer; var Res : Integer) : LongBool;        // translates negative indices! (important)
  public
    constructor Create;
    procedure   Free;
    ///////////////////////////////////
    function    GetTop : Integer;                                               // Utility functions
    function    GetType(Index : Integer) : Integer;
    procedure   Insert(Index : Integer);
    ///////////////////////////////////
    procedure   PushNil;                                                        // Push procedures
    procedure   PushBoolean(Value : LongBool);
    procedure   PushPointer(Value : Pointer);
    procedure   PushPtrOrNil(Value : Pointer);
    procedure   PushInteger(Value : Integer);
    procedure   PushDouble(Value : Double);
    procedure   PushStrRef(Value : PChar);                                      // (PChar in Delphi = char* in C++)
    procedure   PushStrVal(Value : PChar);
    procedure   PushLStrRef(Value : PChar; Len : Integer);                      // Although you can specify length, must still
    procedure   PushLStrVal(Value : PChar; Len : Integer);                      // be terminated by a zero character!!!
    procedure   PushValue(Index : Integer);
    ///////////////////////////////////                                         // Get functions
    function    GetBoolean(Index : Integer) : LongBool;
    function    GetPointer(Index : Integer) : Pointer;
    function    GetInteger(Index : Integer) : Integer;
    function    GetDouble(Index : Integer) : Double;
    function    GetString(Index : Integer) : PChar;
    function    GetLString(Index : Integer; var Len : Integer) : PChar;
    ///////////////////////////////////
    procedure   Remove(Index : Integer);                                        // Remove functions
    procedure   SetTop(Index : Integer);
    procedure   Mark;
    procedure   Clean;
    ///////////////////////////////////
    procedure   MoveTo(Target : TStack; Index,Cnt : Integer);
  end;

implementation

type
  // MUST be packed: PushLStrVal/GetLString deliberately treat the storage location of
  // the P field itself as the start of an inline character buffer (see PushLStrVal),
  // which only lines up with GetMem(Buf,Len+5)'s allocation size if Offset(P)=SizeOf(L)
  // exactly, i.e. no alignment padding between the two fields. A plain (unpacked)
  // record would pad P to an 8-byte boundary on a 64-bit build (Integer=4 bytes,
  // Pointer=8), silently overflowing the allocation by 4 bytes. Verified directly --
  // Lazarus\tests\StackTests.pas exercises PushLStrVal/GetLString round-trips.
  TLStr         = packed record
    L           : Integer;
    P           : Pointer;
  end;
  PLStr         = ^TLStr;

const
  S_NIL         = 0;                                                            // types used internally,
  S_BOOLEAN     = 1;                                                            // stored in DT
  S_POINTER     = 2;
  S_INTEGER     = 3;
  S_DOUBLE      = 4;
  S_STRREF      = 5;
  S_LSTRREF     = 6;
  S_LSTRVAL     = 7;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TStack.Create;
begin
  inherited Create;
  DT:=TList.Create;                                                             // It's easier in Delphi to create two lists. You could
  DA:=TList.Create;                                                             // use a single list pointing to a structure in your
  Marker:=0;                                                                    // own implementation.
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.Free;
begin
  SetTop(0);                                                                    // Release all memory of remaining elements
  DT.Free;                                                                      // before freeing lists!
  DA.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function TStack.GetIndex(Index : Integer; var Res : Integer) : LongBool;        // THIS FUNCTION IS USED EVERYWHERE
begin                                                                           // Lists start with index 0. Adjust positive indices!
  if Index>=0 then Res:=Index-1                                                 // Can return -1 but Result will be false.
  else Res:=DT.Count+Index;                                                     // Convert negative into positive indices. Can be below
  Result:=(Res>=0)and(Res<DT.Count);                                            // 0 but again Result will be false.
end;                                                                            // Result is also false if index too high.

////////////////////////////////////////////////////////////////////////////////
function TStack.GetTop : Integer;
begin
  Result:=DT.Count;
end;

////////////////////////////////////////////////////////////////////////////////
function TStack.GetType(Index : Integer) : Integer;
var
  i : Integer;
begin
  Result:=T_NIL;                                                                // nil is standard value
  if GetIndex(Index,i) then                                                     // calculate index (cancel if invalid)
  case Integer(DT[i]) of
    S_BOOLEAN          : Result:=T_BOOLEAN;                                     // return official types based on internal types.
    S_POINTER          : Result:=T_POINTER;                                     // S_INTEGER and S_DOUBLE both return T_NUMBER.
    S_INTEGER,S_DOUBLE : Result:=T_NUMBER;                                      // dito with strings, user needn't know internal types.
    S_STRREF,S_LSTRREF,
    S_LSTRVAL          : Result:=T_STRING;
  end;
end;                                                                            // (if no match found, return standard)

////////////////////////////////////////////////////////////////////////////////
procedure TStack.Insert(Index : Integer);
var                                                                             // THIS ACTUALLY MOVES AN ELEMENT (NOT INSERT)
  i,t : Integer;                                                                // no alloc/dealloc required, simply move pointer
begin
  if not GetIndex(Index,i) then Exit;                                           // calculate index (cancel if invalid)
  t:=DT.Count-1;                                                                // save top position
  DT.Insert(i,DT[t]);
  DA.Insert(i,DA[t]);                                                           // insert top element (between 0 and t)
  DT.Delete(t+1);
  DA.Delete(t+1);                                                               // delete old top which is now at t+1
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TStack.PushNil;
begin
  DT.Add(Pointer(S_NIL));
  DA.Add(nil);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.PushBoolean(Value : LongBool);
begin
  DT.Add(Pointer(S_BOOLEAN));
  DA.Add(Pointer(Value));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.PushPointer(Value : Pointer);
begin
  DT.Add(Pointer(S_POINTER));
  DA.Add(Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.PushPtrOrNil(Value : Pointer);
begin
  if Value=nil then PushNil
  else PushPointer(Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.PushInteger(Value : Integer);
begin
  DT.Add(Pointer(S_INTEGER));
  DA.Add(Pointer(Value));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.PushDouble(Value : Double);
var
  P : ^Double;                                                                  // Pointer to Double
begin
  New(P);                                                                       // Allocate memory for Double (8 bytes) and
  P^:=Value;                                                                    // store value in dereferenced pointer.
  DT.Add(Pointer(S_DOUBLE));                                                    // New() is one of Delphi's alloc functions.
  DA.Add(P);                                                                    // S_DOUBLE type tells stack to dealloc later
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.PushStrRef(Value : PChar);
begin
  DT.Add(Pointer(S_STRREF));
  DA.Add(Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.PushStrVal(Value : PChar);
begin
  PushLStrVal(Value,Length(Value));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.PushLStrRef(Value : PChar; Len : Integer);
var
  Buf : PLStr;
begin
  New(Buf);
  Buf^.L:=Len;
  Buf^.P:=Value;
  DT.Add(Pointer(S_LSTRREF));
  DA.Add(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.PushLStrVal(Value : PChar; Len : Integer);
var
  Buf : PLStr;
begin
  GetMem(Buf,Len+5);
  Buf^.L:=Len;
  Move(Value^,Buf^.P,Len+1);
  DT.Add(Pointer(S_LSTRVAL));
  DA.Add(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.PushValue(Index : Integer);
var
  i : Integer;
begin
  if GetIndex(Index,i) then                                                     // calculate index (cancel if invalid)
  case Integer(DT[i]) of                                                        // special cases: Doubles and LStrings need their own memory.
    S_DOUBLE  : PushDouble(Double(DA[i]^));                                     // use existing Push functions to do it.
    S_LSTRREF : with PLStr(DA[i])^ do PushLStrRef(P,L);
    S_LSTRVAL : with PLStr(DA[i])^ do PushLStrVal(@P,L);
    else begin
      DT.Add(DT[i]);                                                            // for anything else: simple value copies will do.
      DA.Add(DA[i]);
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function TStack.GetBoolean(Index : Integer) : LongBool;
var
  i : Integer;
begin
  Result:=False;                                                                // false is standard value
  if GetIndex(Index,i) then                                                     // calculate index (cancel if invalid)
    if Integer(DT[i])=S_BOOLEAN then                                            //
      Result:=LongBool(DA[i]);                                         // return Boolean
end;                                                                            // (if no match found, return standard)

////////////////////////////////////////////////////////////////////////////////
function TStack.GetPointer(Index : Integer) : Pointer;
var
  i : Integer;
begin
  Result:=nil;                                                                  // nil is standard value
  if GetIndex(Index,i) then                                                     // calculate index (cancel if invalid)
    if Integer(DT[i])=S_POINTER then                                            //
      Result:=DA[i];                                                            // return Pointer
end;                                                                            // (if no match found, return standard)

////////////////////////////////////////////////////////////////////////////////
function TStack.GetInteger(Index : Integer) : Integer;
var
  i : Integer;
begin
  Result:=0;                                                                    // 0 is standard value
  if GetIndex(Index,i) then                                                     // calculate index (cancel if invalid)
  case Integer(DT[i]) of
    S_INTEGER : Result:=Integer(DA[i]);                                // return Integer
    S_DOUBLE  : Result:=Trunc(Double(DA[i]^));                                  // convert Double, return Integer
  end;
end;                                                                            // (if no match found, return standard)

////////////////////////////////////////////////////////////////////////////////
function TStack.GetDouble(Index : Integer) : Double;
var
  i : Integer;
begin
  Result:=0;                                                                    // 0 is standard value
  if GetIndex(Index,i) then                                                     // calculate index (cancel if invalid)
  case Integer(DT[i]) of
    S_INTEGER : Result:=Integer(DA[i]);                                // return Integer as Double
    S_DOUBLE  : Result:=Double(DA[i]^);                                        // return Double
  end;
end;                                                                            // (if no match found, return standard)

////////////////////////////////////////////////////////////////////////////////
function TStack.GetString(Index : Integer) : PChar;
var
  i : Integer;
begin
  Result:='';
  if GetIndex(Index,i) then
  case Integer(DT[i]) of
    S_STRREF  : Result:=DA[i];
    S_LSTRREF : with PLStr(DA[i])^ do Result:=P;
    S_LSTRVAL : with PLStr(DA[i])^ do Result:=@P;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TStack.GetLString(Index : Integer; var Len : Integer) : PChar;
var
  i : Integer;
begin
  Len:=0;
  Result:=PChar('');
  if GetIndex(Index,i) then
  case Integer(DT[i]) of
    S_STRREF  : begin
                  Len:=Length(PChar(DA[i]));
                  Result:=DA[i];
                end;
    S_LSTRREF : with PLStr(DA[i])^ do
                begin
                  Len:=L;
                  Result:=P;
                end;
    S_LSTRVAL : with PLStr(DA[i])^ do
                begin
                  Len:=L;
                  Result:=@P;
                end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TStack.Remove(Index : Integer);
var
  i : Integer;
begin
  if not GetIndex(Index,i) then Exit;                                           // calculate index (cancel if invalid)
  case Integer(DT[i]) of
    S_DOUBLE  : Dispose(DA[i]);                                                  // deallocate Double
    S_LSTRREF : Dispose(DA[i]);                                                  // deallocate LStrRef
    S_LSTRVAL : FreeMem(DA[i]);                                                  // deallocate LStrVal
  end;
  DT.Delete(i);                                                                 // remove simple values or old pointers
  DA.Delete(i);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.SetTop(Index : Integer);
var
  i : Integer;
begin
  GetIndex(Index,i);                                                            // calculate index BUT DO NOT CANCEL IF INVALID!
  if i<-1 then i:=-1;                                                           // cap at -1 if very large negative index was used
  while DT.Count-1<i do
    PushNil;                                                                    // expand
  while DT.Count-1>i do
    Remove(-1);                                                                 // shrink (cannot go below zero because of cap)
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.Mark;
begin
  Marker:=GetTop;                                                               // remember current top index
end;

////////////////////////////////////////////////////////////////////////////////
procedure TStack.Clean;
var
  i : Integer;
begin
  for i:=1 to Marker do                                                         // remove marked elements
    Remove(1);                                                                  // Remove() will do error checks!
  Marker:=0;                                                                    // reset marker (not necessary but nice)
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TStack.MoveTo(Target : TStack; Index,Cnt : Integer);
var
  i,j : Integer;
begin
  if not GetIndex(Index,i) then Exit;
  for j:=1 to Cnt do
  begin
    if i>=DT.Count then Break;
    Target.DT.Add(DT[i]);
    Target.DA.Add(DA[i]);
    DT.Delete(i);
    DA.Delete(i);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
end.
