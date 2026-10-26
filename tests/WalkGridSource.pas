unit WalkGridSource;

{ Test helper for WalkRulesTests and PathPlanTests: a synthetic walkrules.TWalkSource -- a
  rectangle of flat land, with statics placed by hand, turned into TPathObj records by the same
  LandPathObj/StaticPathObj the file reader (walkmap.pas) uses. Flags are tiledata flags
  (TDF_*), so a test reads like the map it describes: a wall is TDF_IMPASSABLE, a floor
  TDF_SURFACE, stairs TDF_SURFACE or TDF_BRIDGE. }

{$mode objfpc}{$H+}

interface

uses
  walkrules;

const
  GRASS = 3;          // any land graphic that is not a void tile
  VOID  = 2;          // a void land graphic: no land object at all

type
  TGridLand = record
    Graphic : Word;
    Z       : Integer;
    Flags   : Cardinal;
  end;

  TGridSource = class(TWalkSource)
  private
    FW, FH  : Integer;
    FLand   : array of TGridLand;
    FExtra  : array of array of TPathObj;
  public
    Calls   : Integer;   // GetObjects calls, for the tests that count reads
    constructor Create(W, H : Integer; LandZ : Integer = 0);
    procedure SetLand(X, Y, Z : Integer; Flags : Cardinal = 0; Graphic : Word = GRASS);
    procedure AddObj(X, Y : Integer; const Obj : TPathObj);
    procedure AddStatic(X, Y, Z, Height : Integer; Flags : Cardinal);
    procedure AddStaticRect(X1, Y1, X2, Y2, Z, Height : Integer; Flags : Cardinal);
    function  GetObjects(X, Y : Integer; var List : TPathObjList) : Boolean; override;
  end;

implementation

constructor TGridSource.Create(W, H : Integer; LandZ : Integer);
var
  i : Integer;
begin
  inherited Create;
  FW := W;
  FH := H;
  SetLength(FLand, W*H);
  SetLength(FExtra, W*H);
  for i := 0 to W*H - 1 do
  begin
    FLand[i].Graphic := GRASS;
    FLand[i].Z := LandZ;
    FLand[i].Flags := 0;
  end;
end;

procedure TGridSource.SetLand(X, Y, Z : Integer; Flags : Cardinal; Graphic : Word);
begin
  FLand[Y*FW + X].Graphic := Graphic;
  FLand[Y*FW + X].Z := Z;
  FLand[Y*FW + X].Flags := Flags;
end;

procedure TGridSource.AddObj(X, Y : Integer; const Obj : TPathObj);
var
  i : Integer;
begin
  i := Y*FW + X;
  SetLength(FExtra[i], Length(FExtra[i]) + 1);
  FExtra[i][High(FExtra[i])] := Obj;
end;

procedure TGridSource.AddStatic(X, Y, Z, Height : Integer; Flags : Cardinal);
var
  Obj : TPathObj;
begin
  if StaticPathObj(Flags, Height, Z, Obj) then AddObj(X, Y, Obj);
end;

procedure TGridSource.AddStaticRect(X1, Y1, X2, Y2, Z, Height : Integer; Flags : Cardinal);
var
  X, Y : Integer;
begin
  for Y := Y1 to Y2 do
    for X := X1 to X2 do
      AddStatic(X, Y, Z, Height, Flags);
end;

function TGridSource.GetObjects(X, Y : Integer; var List : TPathObjList) : Boolean;
var
  Obj : TPathObj;
  i   : Integer;
begin
  Inc(Calls);
  List.Count := 0;
  Result := (X >= 0) and (Y >= 0) and (X < FW) and (Y < FH);
  if not Result then Exit;
  with FLand[Y*FW + X] do
    if LandPathObj(Graphic, Flags, Z, Obj) then AddPathObj(List, Obj);
  for i := 0 to High(FExtra[Y*FW + X]) do
    AddPathObj(List, FExtra[Y*FW + X][i]);
end;

end.
