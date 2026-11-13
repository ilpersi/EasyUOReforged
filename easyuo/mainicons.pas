unit mainicons;

{
  Toolbar/menu icons and the main-window icon. Both were first restored from the
  original easyuo\main.dfm during the Lazarus/FPC migration. The original DFM's
  ImageList.Bitmap and Icon.Data properties are Delphi-format binary property
  streams -- initially assumed "not reconstructable" (see main.pas's own header
  comment) and skipped, until closer inspection showed both use fully standard,
  well-documented formats underneath, not an exotic unrecoverable blob:
    - ImageList.Bitmap is Delphi's documented "IL" TImageList stream format
      (2-byte "IL" signature, version, image count, ...) wrapping two completely
      ordinary embedded BMP files back to back: a 64x96 16bpp color strip (24
      slots of 16x16, 19 actually used) immediately followed by a 64x96 1bpp
      AND-mask strip (mask pixel white = transparent, black = opaque).
    - Icon.Data is a plain standard .ico file (32x32), no wrapper at all.
  Both were extracted with a one-off Python script (parse the DFM's hex property
  blob, decode it, locate the embedded "BM"/ICONDIR signatures, decode with a
  standard image library, slice the color+mask strip into 16x16 RGBA PNGs per
  the mask), then re-encoded here as base64 so this port stays a single self-
  contained executable with no extra asset files to distribute -- consistent
  with the rest of this migration's "just run the exe" simplicity.

  Neither is the original any more. The toolbar/menu icons have since been redrawn
  in the MENU Designer's style: they are in mainiconsdata.pas, written by
  make_toolbar_icons.py. The window icon is now a multi-size one that keeps the
  original's emblem, with a gear for its ring: it is in appicondata.pas, written by
  make_app_icon.py, which also writes the executables' appicon.res (all in this
  folder) and the documentation site's favicon and home-page image.

  ImageIndex assignments below are copied directly from the original DFM's own
  TToolButton/TMenuItem ImageIndex properties, cross-referenced by Tag (every
  button/menu item in this port already sets Tag identically to the original --
  see main.pas's AddTool/AddMenu) rather than guessed from how each icon looks.
  The new icons kept those slots, so the mapping did not change.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Controls, ImgList;

// Tag -> ImageIndex, per the original DFM (-1 = no icon for this Tag, the LCL
// convention for no image). Shared by AddTool/AddMenu so every toolbar button
// and every menu item (MainMenu/TabPopupMenu/SynPopupMenu, which all already
// share one ImageList) picks up the right icon automatically from the same Tag
// they already set for click dispatch -- no per-call-site changes needed
// anywhere else in main.pas.
function TagToImageIndex(ATag : Integer) : Integer;

// Populates AList with the icons in mainiconsdata.pas, in ImageIndex order: the
// original 19 slots (0..18), plus this port's Format Script icon (19). Safe to
// call on a freshly-created, empty TImageList only.
procedure LoadToolbarIcons(AList : TImageList);

// The same icons, in the same order, each in one flat grey with its alpha, for
// TToolBar.DisabledImages. Windows' own disabled draw greys by brightness, which
// left red and green icons much darker than orange or cyan ones.
procedure LoadDisabledToolbarIcons(AList : TImageList);

// One icon as LoadDisabledToolbarIcons has it (the caller frees it).
function LoadGreyedPNGBitmap(const B64 : String) : TBitmap;

// Decodes the window icon, with all its sizes.
function LoadAppIcon : TIcon;

// A base64 PNG as a 32-bit bitmap with its alpha (the caller frees it). The MENU Designer's
// icons (tools\EUOMenuDesigner\mdicons.pas) are decoded by it too.
function LoadPNGBitmap(const B64 : String) : TBitmap;

implementation

uses
  base64, FPImage, IntfGraphics, mainiconsdata, appicondata;

const
  DisabledGrey = $A0A0;   // per channel, in FPImage's 16 bits

////////////////////////////////////////////////////////////////////////////////
function TagToImageIndex(ATag : Integer) : Integer;
begin
  case ATag of
    1   : Result :=  0; // New
    2   : Result :=  1; // Open
    3   : Result :=  2; // Save
    5   : Result := 15; // Save All
    6   : Result := 16; // Close
    9   : Result := 14; // Reopen
    22  : Result :=  3; // Cut
    23  : Result :=  4; // Copy
    24  : Result :=  5; // Paste
    27  : Result :=  6; // Find
    28  : Result :=  7; // Replace
    60  : Result :=  8; // Start
    61  : Result :=  9; // Pause
    62  : Result := 10; // Stop
    63  : Result := 11; // Stop All
    81  : Result := 17; // New Client
    82  : Result := 18; // Swap To Next Client
    100 : Result := 12; // Help
    101 : Result := 13; // Go To Website
    220 : Result := 19; // Format Script (new addition)
    else  Result := -1; // no icon for this Tag in the original DFM either
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function LoadPNGBitmap(const B64 : String) : TBitmap;
var
  Raw : String;
  MS  : TMemoryStream;
  Png : TPortableNetworkGraphic;
begin
  Raw := DecodeStringBase64(B64);
  MS := TMemoryStream.Create;
  Png := TPortableNetworkGraphic.Create;
  try
    MS.WriteBuffer(Raw[1], Length(Raw));
    MS.Position := 0;
    Png.LoadFromStream(MS);
    // Assign onto a real TBitmap (pf32bit, alpha preserved) -- ImageList.Add's
    // own ScaleImage reads per-pixel alpha straight off a 32bit source bitmap
    // when no separate Mask bitmap is passed (confirmed in imglist.inc), so this
    // needs no explicit mask handling here at all.
    Result := TBitmap.Create;
    Result.PixelFormat := pf32bit;
    Result.Assign(Png);
  finally
    Png.Free;
    MS.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure LoadToolbarIcons(AList : TImageList);
var
  I   : Integer;
  Bmp : TBitmap;
begin
  AList.Width := 16;
  AList.Height := 16;

  for I := Low(ToolbarIcons) to High(ToolbarIcons) do
  begin
    Bmp := LoadPNGBitmap(ToolbarIcons[I]);
    AList.Add(Bmp, nil);
    Bmp.Free;
  end;
  // 0=New 1=Open 2=Save 3=Cut 4=Copy 5=Paste 6=Find 7=Replace 8=Start 9=Pause
  // 10=Stop 11=StopAll 12=Help 13=Website 14=Reopen 15=SaveAll 16=Close
  // 17=NewClient 18=SwapClient 19=Format (new) -- matches TagToImageIndex
  // above exactly.
end;

////////////////////////////////////////////////////////////////////////////////
function LoadGreyedPNGBitmap(const B64 : String) : TBitmap;
var
  Img  : TLazIntfImage;
  X, Y : Integer;
  C    : TFPColor;
begin
  Result := LoadPNGBitmap(B64);
  Img := Result.CreateIntfImage;
  try
    for Y := 0 to Img.Height-1 do
      for X := 0 to Img.Width-1 do
      begin
        C := Img.Colors[X, Y];
        C.Red := DisabledGrey;
        C.Green := DisabledGrey;
        C.Blue := DisabledGrey;
        Img.Colors[X, Y] := C;
      end;
    Result.LoadFromIntfImage(Img);
  finally
    Img.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure LoadDisabledToolbarIcons(AList : TImageList);
var
  I   : Integer;
  Bmp : TBitmap;
begin
  AList.Width := 16;
  AList.Height := 16;

  for I := Low(ToolbarIcons) to High(ToolbarIcons) do
  begin
    Bmp := LoadGreyedPNGBitmap(ToolbarIcons[I]);
    AList.Add(Bmp, nil);
    Bmp.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function LoadAppIcon : TIcon;
var
  Raw : String;
  MS  : TMemoryStream;
begin
  Raw := DecodeStringBase64(AppIconIco);
  MS := TMemoryStream.Create;
  try
    MS.WriteBuffer(Raw[1], Length(Raw));
    MS.Position := 0;
    Result := TIcon.Create;
    Result.LoadFromStream(MS);
  finally
    MS.Free;
  end;
end;

end.
