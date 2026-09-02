unit StackTests;

{ FPCUnit tests for uo\stack.pas's TStack -- the Lua-C-API-style stack machine every
  UO.xxx script call is dispatched through. Exhaustive per the migration plan's Tier-1
  testing strategy: every push/get pair, GetType's kind mapping, Insert/Remove/SetTop/
  Mark/Clean, negative-index translation, and MoveTo. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, stack;

type
  TStackTests = class(TTestCase)
  published
    procedure TestEmptyStack;
    procedure TestPushNil;
    procedure TestPushBooleanTrueFalse;
    procedure TestPushPointer;
    procedure TestPushPtrOrNil;
    procedure TestPushIntegerPositive;
    procedure TestPushIntegerNegative;    // the round-trip most at risk on a 64-bit build
    procedure TestPushDouble;
    procedure TestPushStrRefIsLiveReference;
    procedure TestPushStrValIsIndependentCopy;
    procedure TestPushLStrValWithEmbeddedContent;
    procedure TestManyLStrValPushesDontCorruptEachOther;
    procedure TestGetTypeMapping;
    procedure TestNegativeIndexing;
    procedure TestOutOfRangeReturnsDefaults;
    procedure TestInsertMovesTopToPosition;
    procedure TestRemove;
    procedure TestSetTopExpandsWithNil;
    procedure TestSetTopShrinks;
    procedure TestSetTopCapsAtMinusOne;
    procedure TestMarkAndClean;
    procedure TestPushValueDuplicatesTop;
    procedure TestMoveTo;
  end;

implementation

procedure TStackTests.TestEmptyStack;
var S : TStack;
begin
  S := TStack.Create;
  try
    AssertEquals('empty stack top', 0, S.GetTop);
  finally S.Free; end;
end;

procedure TStackTests.TestPushNil;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushNil;
    AssertEquals(1, S.GetTop);
    AssertEquals('T_NIL', T_NIL, S.GetType(-1));
  finally S.Free; end;
end;

procedure TStackTests.TestPushBooleanTrueFalse;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushBoolean(True);
    S.PushBoolean(False);
    AssertEquals(False, S.GetBoolean(-1));
    AssertEquals(True, S.GetBoolean(-2));
    AssertEquals(T_BOOLEAN, S.GetType(-1));
  finally S.Free; end;
end;

procedure TStackTests.TestPushPointer;
var
  S : TStack;
  Obj : TObject;
begin
  S := TStack.Create;
  Obj := TObject.Create;
  try
    S.PushPointer(Obj);
    AssertTrue('pointer round-trips', S.GetPointer(-1) = Pointer(Obj));
    AssertEquals(T_POINTER, S.GetType(-1));
  finally
    S.Free;
    Obj.Free;
  end;
end;

procedure TStackTests.TestPushPtrOrNil;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushPtrOrNil(nil);
    AssertEquals('nil pointer becomes T_NIL', T_NIL, S.GetType(-1));
    S.PushPtrOrNil(Pointer(1));
    AssertEquals('non-nil pointer becomes T_POINTER', T_POINTER, S.GetType(-1));
  finally S.Free; end;
end;

procedure TStackTests.TestPushIntegerPositive;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushInteger(42);
    AssertEquals(42, S.GetInteger(-1));
    AssertEquals(T_NUMBER, S.GetType(-1));
  finally S.Free; end;
end;

procedure TStackTests.TestPushIntegerNegative;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushInteger(-5);
    AssertEquals('negative Integer round-trip', -5, S.GetInteger(-1));
    S.PushInteger(Low(Integer));
    AssertEquals('Low(Integer) round-trip', Low(Integer), S.GetInteger(-1));
    S.PushInteger(High(Integer));
    AssertEquals('High(Integer) round-trip', High(Integer), S.GetInteger(-1));
  finally S.Free; end;
end;

procedure TStackTests.TestPushDouble;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushDouble(3.14159);
    AssertEquals(3.14159, S.GetDouble(-1), 1e-9);
    AssertEquals(T_NUMBER, S.GetType(-1));
    AssertEquals('GetInteger truncates a Double', 3, S.GetInteger(-1));
  finally S.Free; end;
end;

procedure TStackTests.TestPushStrRefIsLiveReference;
var
  S : TStack;
  Buf : String;
begin
  // "Ref" means PushStrRef stores the PChar pointer verbatim (vs. StrVal's own copy)
  // -- checked via pointer identity, not via mutating Buf afterward: Pascal's
  // reference-counted strings can reallocate on write even at refcount 1 in some
  // compiler-generated paths, so "does a later mutation propagate" isn't a property
  // PushStrRef ever promised (true in original Delphi too, same string mechanics).
  S := TStack.Create;
  Buf := 'hello';
  try
    S.PushStrRef(PChar(Buf));
    AssertTrue('stores the exact pointer passed in', S.GetString(-1) = PChar(Buf));
    AssertEquals('hello', String(S.GetString(-1)));
    AssertEquals(T_STRING, S.GetType(-1));
  finally S.Free; end;
end;

procedure TStackTests.TestPushStrValIsIndependentCopy;
var
  S : TStack;
  Buf : String;
begin
  S := TStack.Create;
  Buf := 'hello';
  try
    S.PushStrVal(PChar(Buf));
    Buf := 'changed';
    AssertEquals('StrVal is an independent copy', 'hello', String(S.GetString(-1)));
  finally S.Free; end;
end;

procedure TStackTests.TestPushLStrValWithEmbeddedContent;
var
  S : TStack;
  Buf : String;
  Len : Integer;
begin
  // PushLStrVal(Value,Len) copies exactly Len+1 bytes verbatim from Value -- it relies
  // on the CALLER's buffer being naturally Len characters long (so byte [Len] is
  // already a real null terminator); it does not itself truncate/terminate a longer
  // source. (A first draft of this test passed a longer 6-char buffer with Len=3 and
  // got back "abcd" plus luck-of-the-heap garbage -- that's this function working
  // exactly as designed on a misuse, not a bug.)
  S := TStack.Create;
  Buf := 'abc';
  try
    S.PushLStrVal(PChar(Buf), Length(Buf));
    AssertEquals('abc', String(S.GetString(-1)));
    S.GetLString(-1, Len);
    AssertEquals(3, Len);
  finally S.Free; end;
end;

procedure TStackTests.TestManyLStrValPushesDontCorruptEachOther;
var
  S : TStack;
  i : Integer;
  words : array[0..7] of String;
begin
  // Stress test for the TLStr packed-record fix: many back-to-back GetMem allocations
  // of varying small sizes, interleaved with reads, so a 4-byte overflow into the next
  // heap block (the bug the unpacked record had on Win64) would corrupt a NEIGHBOUR's
  // data rather than its own -- exactly the failure mode a single-string test can't see.
  words[0] := 'a';       words[1] := 'bb';      words[2] := 'ccc';     words[3] := 'dddd';
  words[4] := 'eeeee';   words[5] := 'ffffff';  words[6] := 'g';       words[7] := 'hh';
  S := TStack.Create;
  try
    for i := 0 to High(words) do
      S.PushLStrVal(PChar(words[i]), Length(words[i]));
    for i := 0 to High(words) do
      AssertEquals('slot ' + IntToStr(i), words[i], String(S.GetString(-8 + i)));
  finally S.Free; end;
end;

procedure TStackTests.TestGetTypeMapping;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushNil;      AssertEquals(T_NIL, S.GetType(-1));
    S.PushBoolean(True); AssertEquals(T_BOOLEAN, S.GetType(-1));
    S.PushPointer(Pointer(1)); AssertEquals(T_POINTER, S.GetType(-1));
    S.PushInteger(1); AssertEquals(T_NUMBER, S.GetType(-1));
    S.PushDouble(1.0); AssertEquals(T_NUMBER, S.GetType(-1));
    S.PushStrVal('x'); AssertEquals(T_STRING, S.GetType(-1));
  finally S.Free; end;
end;

procedure TStackTests.TestNegativeIndexing;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushInteger(1);
    S.PushInteger(2);
    S.PushInteger(3);
    AssertEquals('index 1 = bottom', 1, S.GetInteger(1));
    AssertEquals('index 3 = top', 3, S.GetInteger(3));
    AssertEquals('index -1 = top', 3, S.GetInteger(-1));
    AssertEquals('index -2 = one below top', 2, S.GetInteger(-2));
    AssertEquals('index -3 = bottom', 1, S.GetInteger(-3));
  finally S.Free; end;
end;

procedure TStackTests.TestOutOfRangeReturnsDefaults;
var S : TStack;
begin
  S := TStack.Create;
  try
    AssertEquals('out-of-range GetInteger', 0, S.GetInteger(1));
    AssertEquals('out-of-range GetBoolean', False, S.GetBoolean(1));
    AssertTrue('out-of-range GetPointer', S.GetPointer(1) = nil);
    AssertEquals('out-of-range GetType', T_NIL, S.GetType(99));
    AssertEquals('out-of-range negative index', T_NIL, S.GetType(-99));
  finally S.Free; end;
end;

procedure TStackTests.TestInsertMovesTopToPosition;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushInteger(1);
    S.PushInteger(2);
    S.PushInteger(3);   // top
    S.Insert(1);         // move top (3) to position 1
    AssertEquals(3, S.GetInteger(1));
    AssertEquals(1, S.GetInteger(2));
    AssertEquals(2, S.GetInteger(3));
    AssertEquals('count unchanged', 3, S.GetTop);
  finally S.Free; end;
end;

procedure TStackTests.TestRemove;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushInteger(1);
    S.PushInteger(2);
    S.PushInteger(3);
    S.Remove(2);
    AssertEquals(2, S.GetTop);
    AssertEquals(1, S.GetInteger(1));
    AssertEquals(3, S.GetInteger(2));
  finally S.Free; end;
end;

procedure TStackTests.TestSetTopExpandsWithNil;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushInteger(1);
    S.SetTop(4);
    AssertEquals(4, S.GetTop);
    AssertEquals(T_NIL, S.GetType(2));
    AssertEquals(T_NIL, S.GetType(3));
    AssertEquals(T_NIL, S.GetType(4));
  finally S.Free; end;
end;

procedure TStackTests.TestSetTopShrinks;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushInteger(1);
    S.PushInteger(2);
    S.PushInteger(3);
    S.SetTop(1);
    AssertEquals(1, S.GetTop);
    AssertEquals(1, S.GetInteger(1));
  finally S.Free; end;
end;

procedure TStackTests.TestSetTopCapsAtMinusOne;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushInteger(1);
    S.SetTop(-100);   // caps at -1, i.e. empties the stack
    AssertEquals(0, S.GetTop);
  finally S.Free; end;
end;

procedure TStackTests.TestMarkAndClean;
var S : TStack;
begin
  // Real contract (confirmed against uowrap.pas's TUOWrap.Query/Execute, the only
  // callers): Mark is taken while the CALLER's arguments are already on the stack;
  // the callee then pushes its RESULT(s) on top; Clean removes the Marker elements
  // from the BOTTOM (the now-consumed arguments), keeping whatever was pushed after
  // the mark (the results) -- a Lua-C-API-style "consume my args, leave my results"
  // convention. This is the opposite of a naive "rewind to the mark" reading.
  S := TStack.Create;
  try
    S.PushInteger(10);     // argument 1
    S.PushInteger(20);     // argument 2
    S.Mark;                // Marker := 2 (both arguments already present)
    S.PushInteger(99);     // the callee's result, pushed on top
    S.Clean;                // removes the 2 pre-mark elements (the arguments)
    AssertEquals('only the post-mark result remains', 1, S.GetTop);
    AssertEquals(99, S.GetInteger(-1));
  finally S.Free; end;
end;

procedure TStackTests.TestPushValueDuplicatesTop;
var S : TStack;
begin
  S := TStack.Create;
  try
    S.PushInteger(42);
    S.PushValue(-1);
    AssertEquals(2, S.GetTop);
    AssertEquals(42, S.GetInteger(-1));
    AssertEquals(42, S.GetInteger(-2));
  finally S.Free; end;
end;

procedure TStackTests.TestMoveTo;
var
  S1, S2 : TStack;
begin
  S1 := TStack.Create;
  S2 := TStack.Create;
  try
    S1.PushInteger(1);
    S1.PushInteger(2);
    S1.PushInteger(3);
    S1.MoveTo(S2, 2, 2);   // move index 2..3 ("2" and "3") over to S2
    AssertEquals('source shrank', 1, S1.GetTop);
    AssertEquals(1, S1.GetInteger(1));
    AssertEquals('target grew', 2, S2.GetTop);
    AssertEquals(2, S2.GetInteger(1));
    AssertEquals(3, S2.GetInteger(2));
  finally
    S1.Free;
    S2.Free;
  end;
end;

initialization
  RegisterTest(TStackTests);
end.
