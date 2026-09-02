unit WearablesTests;

{ FPCUnit tests for uo\wearables.pas's GetWearableLayer. Expected (item, layer) pairs
  were computed independently (via a standalone script over the data table, not by
  hand-counting -- hand-counting an array like this is exactly how the FindPos smoke
  test's first draft got two expectations wrong), so these are trustworthy oracles. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, wearables;

type
  TWearablesTests = class(TTestCase)
  published
    procedure TestFirstItemInFirstBatch;
    procedure TestSecondItemSharesFirstBatchLayer;
    procedure TestVariousBatches;
    procedure TestLastItemHighestLayer;
    procedure TestUnknownItemReturnsZero;
  end;

implementation

procedure TWearablesTests.TestFirstItemInFirstBatch;
begin
  AssertEquals(1, GetWearableLayer(10148));
end;

procedure TWearablesTests.TestSecondItemSharesFirstBatchLayer;
begin
  AssertEquals(1, GetWearableLayer(10152));
end;

procedure TWearablesTests.TestVariousBatches;
begin
  AssertEquals(2, GetWearableLayer(9584));
  AssertEquals(8, GetWearableLayer(4234));
  AssertEquals(8, GetWearableLayer(7945));
  AssertEquals(9, GetWearableLayer(12120));
  AssertEquals(11, GetWearableLayer(8251));
end;

procedure TWearablesTests.TestLastItemHighestLayer;
begin
  AssertEquals(23, GetWearableLayer(9715));
end;

procedure TWearablesTests.TestUnknownItemReturnsZero;
begin
  AssertEquals(0, GetWearableLayer(1));
  AssertEquals(0, GetWearableLayer(65535));
end;

initialization
  RegisterTest(TWearablesTests);
end.
