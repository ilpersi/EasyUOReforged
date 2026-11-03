unit MainIconsTests;

{
  Tests for easyuo\mainicons.pas: every toolbar/menu icon in the generated
  mainiconsdata.pas decodes, and TagToImageIndex and the icons agree on the slots.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Types, Graphics, Controls, FPImage, IntfGraphics, fpcunit, testregistry,
  mainicons, mainiconsdata;

type
  TMainIconsTests = class(TTestCase)
  published
    procedure TestEveryIconIs16x16WithAlpha;
    procedure TestListHoldsEveryIcon;
    procedure TestEveryTagHasARealSlotAndEverySlotATag;
    procedure TestDisabledListHoldsEveryIcon;
    procedure TestGreyedIconsAreOneGreyWithTheirOwnAlpha;
    procedure TestAppIconHasEverySize;
  end;

implementation

procedure TMainIconsTests.TestEveryIconIs16x16WithAlpha;
var
  I   : Integer;
  Bmp : TBitmap;
begin
  for I:=Low(ToolbarIcons) to High(ToolbarIcons) do
  begin
    Bmp:=LoadPNGBitmap(ToolbarIcons[I]);
    try
      AssertEquals('icon '+IntToStr(I)+' width',16,Bmp.Width);
      AssertEquals('icon '+IntToStr(I)+' height',16,Bmp.Height);
      AssertTrue('icon '+IntToStr(I)+' keeps its alpha',Bmp.PixelFormat=pf32bit);
    finally
      Bmp.Free;
    end;
  end;
end;

procedure TMainIconsTests.TestListHoldsEveryIcon;
var
  L : TImageList;
begin
  L:=TImageList.Create(nil);
  try
    LoadToolbarIcons(L);
    AssertEquals('one image per icon',Length(ToolbarIcons),L.Count);
    AssertEquals('width',16,L.Width);
    AssertEquals('height',16,L.Height);
  finally
    L.Free;
  end;
end;

// Tags go up to 220 in main.pas; the range is wider so a new one is covered too.
procedure TMainIconsTests.TestEveryTagHasARealSlotAndEverySlotATag;
var
  Tag, Slot : Integer;
  Used      : array[Low(ToolbarIcons)..High(ToolbarIcons)] of Boolean;
begin
  for Slot:=Low(Used) to High(Used) do Used[Slot]:=False;
  for Tag:=0 to 1000 do
  begin
    Slot:=TagToImageIndex(Tag);
    if Slot=-1 then Continue;
    AssertTrue('tag '+IntToStr(Tag)+' points at an icon',(Slot>=Low(Used)) and (Slot<=High(Used)));
    Used[Slot]:=True;
  end;
  for Slot:=Low(Used) to High(Used) do
    AssertTrue('icon '+IntToStr(Slot)+' is used by a tag',Used[Slot]);
end;

procedure TMainIconsTests.TestDisabledListHoldsEveryIcon;
var
  L : TImageList;
begin
  L:=TImageList.Create(nil);
  try
    LoadDisabledToolbarIcons(L);
    AssertEquals('one image per icon',Length(ToolbarIcons),L.Count);
  finally
    L.Free;
  end;
end;

// Red, green and orange icons included: the point is that they all come out alike.
procedure TMainIconsTests.TestGreyedIconsAreOneGreyWithTheirOwnAlpha;
var
  I, X, Y, Seen : Integer;
  Grey          : Word;
  Norm, Dis     : TBitmap;
  INorm, IDis   : TLazIntfImage;
  C             : TFPColor;
begin
  Grey:=0;
  for I:=Low(ToolbarIcons) to High(ToolbarIcons) do
  begin
    Norm:=LoadPNGBitmap(ToolbarIcons[I]);
    Dis:=LoadGreyedPNGBitmap(ToolbarIcons[I]);
    INorm:=Norm.CreateIntfImage;
    IDis:=Dis.CreateIntfImage;
    try
      Seen:=0;
      for Y:=0 to 15 do
        for X:=0 to 15 do
        begin
          C:=IDis.Colors[X,Y];
          AssertEquals('icon '+IntToStr(I)+' keeps its alpha',INorm.Colors[X,Y].Alpha,C.Alpha);
          if C.Alpha=0 then Continue;
          Inc(Seen);
          if Grey=0 then Grey:=C.Red;
          AssertEquals('icon '+IntToStr(I)+' red',Grey,C.Red);
          AssertEquals('icon '+IntToStr(I)+' green',Grey,C.Green);
          AssertEquals('icon '+IntToStr(I)+' blue',Grey,C.Blue);
        end;
      AssertTrue('icon '+IntToStr(I)+' still draws something',Seen>0);
    finally
      IDis.Free;
      INorm.Free;
      Dis.Free;
      Norm.Free;
    end;
  end;
end;

// LCL has to read them all: bitmaps up to 64, the PNG at 256.
procedure TMainIconsTests.TestAppIconHasEverySize;
const
  Sizes : array[0..7] of Integer = (16,20,24,32,40,48,64,256);
var
  Ico : TIcon;
  I   : Integer;
begin
  Ico:=LoadAppIcon;
  try
    AssertEquals('one image per size',Length(Sizes),Ico.Count);
    for I:=Low(Sizes) to High(Sizes) do
    begin
      Ico.Current:=Ico.GetBestIndexForSize(Size(Sizes[I],Sizes[I]));
      AssertEquals('the icon has this size',Sizes[I],Ico.Width);
      AssertEquals('and it is square',Sizes[I],Ico.Height);
    end;
  finally
    Ico.Free;
  end;
end;

initialization
  RegisterTest(TMainIconsTests);

end.
