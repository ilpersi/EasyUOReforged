unit mainicons;

{
  Toolbar/menu icons and the main-window icon, restored from the original
  easyuo\main.dfm during the Lazarus/FPC migration. The original DFM's
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

  ImageIndex assignments below are copied directly from the original DFM's own
  TToolButton/TMenuItem ImageIndex properties, cross-referenced by Tag (every
  button/menu item in this port already sets Tag identically to the original --
  see main.pas's AddTool/AddMenu) rather than guessed from how each icon looks.
  Two of them independently self-confirm the mapping: ImageIndex 17/18 are
  literal "CLI NEW"/"CLI SWAP" text glyphs, and Tag 81/82 are exactly
  NewClient/SwapToNextClient.
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

// Populates AList with the 19 icons above, in ImageIndex order (0..18). Safe to
// call on a freshly-created, empty TImageList only.
procedure LoadToolbarIcons(AList : TImageList);

// Decodes the original 32x32 window icon.
function LoadAppIcon : TIcon;

implementation

uses
  base64;

const
  IconNew : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAS0lEQVR4nGNgGGjAiMT+T4Ja7Ab8' +
    '/4/dDEZGRpyGMBF2JNx0rK5kItYAJFegGMJCgu3oBpHmAlyAiYFCwDRqAAPFYUBKXsCljzIAAGy/' +
    'DhhDDuNiAAAAAElFTkSuQmCC';

  IconOpen : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAdUlEQVR4nMWTQQ7AIAgEWeMrfaDf' +
    'pFFjCq0W5FIOGtBZFxKJ/g4473GAWcIyf9aPgqdAFgWvRfUyWoF7qS0gfOOv03yLdi1ihsrnjo1y' +
    'EkaMfW+JRw/wtrFqAQouxQZrHWCSMziF1QwQgKX3EKwEnHH8D8y4AMJVKB3YzCqrAAAAAElFTkSu' +
    'QmCC';

  IconSave : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAX0lEQVR4nGNgoBAwQun/FOpn+B8V' +
    'BTaEGIP+I9NMZNoMt4iJHN1RUQg2E5kuGKwGREH89h8fRvY/CLCgm4iugBBgQRdYtox2scCInPLI' +
    'MYABG6DYAGQnkZOhMLxEMgAA+yIVlW1XrfwAAAAASUVORK5CYII=';

  IconCut : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAXUlEQVR4nGNgoBH4T4APB0yU2sRE' +
    'SwP+o9Ekg//EGMBEpCFkg/+EFDDhlrL8j0qTbAAYMCIMwW4QC6YQNoXHkQyCsbG6wBKqAFURTRMS' +
    'C2ElINfAvEWUy3AHGE0AAFvnGPK0aFKJAAAAAElFTkSuQmCC';

  IconCopy : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAgUlEQVR4nMWSYQ6AIAiFea5L2f1X' +
    'x6JVbCIC2Y/W29hU9JOnEP0tEBEnuTkAc88AMA0pUUKgPF0B5NY2rsGRfaiKPRFVd+0OxwKALmJr' +
    'G2lI0Z51WHCbrzJqEJZvMDFaGO28qCCyV542WbDtmSVplmun96AacgJS2RutUkB78Q91ALlBlJbX' +
    'z6FzAAAAAElFTkSuQmCC';

  IconPaste : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAqklEQVR4nLVTAQoEIQgco091T+mB' +
    'PeV6lodZZ1KxwXEDoZkzzgoL/Ag61PmyD3QggHuF9lSaE85Z0gSgohQlD+LIc9Z36SulfkWCtskj' +
    'GrkNpfZIc66kIWIIGlyRDwfzsIFoxeps7uMyDMsObBd+koftIM4OfJQFvtf108s5Cqa4s7uHCid+' +
    'dGAT4RxZLXEXqNefMd9FKHalKwcnoXZfT+InSM/xJxlL+js+jChyYIqnKpoAAAAASUVORK5CYII=';

  IconFind : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAjklEQVR4nKWTAQ6AIAhF+a5LdZXu' +
    'V0fpWjQbMihFNtmczPwPPkuixQARcfLeGMA8ZgAIISVRXQutAPiza2xTpbFn7OQB6IjSFgDQcexv' +
    'WpfknAJAxNd5Ox89CPdCL3nxb5glNNhaCaJEH01F7cSdRRZYbFiB5O4sBJhZ6GqQNofpW+iMw/3W' +
    '2dfoOK3zuj/+d4T8RAMBQQAAAABJRU5ErkJggg==';

  IconReplace : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAl0lEQVR4nJWTSw6AIAxEO8RLyZJr' +
    'udWrwbFqij9+QmkiqYQ3M9YAIqJ1JSZFhUAo95an8b6vYW1k5VAmYmiimKMJqwWAzyyE7J3VCXBD' +
    '4r5t1zNMACBzf/p9r8+anuObN+mHAjPwcAacwOkndQVYAakSoDFEtQAa8N8sTGuzHOL0X+g5Vmll' +
    'kdvonA6QOo6IfUt5QZQV2RO9ijueeaPWqQAAAABJRU5ErkJggg==';

  IconStart : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAU0lEQVR4nK3SUQqAMAwE0b3/nfZs' +
    'IwUF0VaarPl/QyCRfh+EDW3vgaMIJ+5GfMetCA9cjXiGSxEWeDfib7yxBQnW8gqFS5BgvT6x8Y0R' +
    'vhIBLs8BWdm1sSyhIYIAAAAASUVORK5CYII=';

  IconPause : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAVklEQVR4nGNgoBAwIpjV/6urGRha' +
    'W2H8VqLkmOBKoApANIRf/Z8YOSa4mVAFCFsQAJ8cEy5bkAE+OaZRFzCMhgEDFcMAphAXwCXHgqSE' +
    'ETmToGnHKQcAmiBdAKFszEsAAAAASUVORK5CYII=';

  IconStop : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAz0lEQVR4nJWSzQ3DIAyFn1EX6Ri9' +
    'pluwSnrtKtmiuWaMjEIVsJFtTKU+iSgYPv9gEwKtQInsb4C8jSJwyQ8s7uK+HXgGHGm4g/ejGU8+' +
    '3JQjQBxR/6wC/wC1Xq2cyicx9pRPBiewuQsgSfSatsCltCXy+5Z1PUneY0uMRlBsTsnsdNoamMCj' +
    'Ay1fwl8Oikpbl8Nt1Lr1P2mdgJjvvRNcnSi5P9l0fXjxxBZTwn49YI7rvCJKVB/djnLMD6BMoXHA' +
    'qmnxkAxi0HCzBs/6Ntz/AiPgVumKyj5CAAAAAElFTkSuQmCC';

  IconStopAll : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAA1ElEQVR4nHWT7RHDIAiGwXOhplt0' +
    'jO7RX3YOx+gWTUaip4gFRO7ywRseQKIIgRUAivQXAHoNI/DxvMHhAs96wT3gUMN/8LJ0VYkAJBHO' +
    'W5nwHtT25uV0Pol4eHAD9yWq9yTVZ9sNJOJLzPvcdf+Sluq9MVxB0Zxlw1UOpjaaBgyYWWK9D1G6' +
    'QUgeZnlteWdZO1KhJzBtk/mN2hJX9/J2yWsccAWKOvD+d50B2iHGR8DYx/lZqhdAs0FalZZQqkbw' +
    'MLNL2pP4ULGu30ec8Xej2q1lif8BF2ZhIiI6NVQAAAAASUVORK5CYII=';

  IconHelp : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAwklEQVR4nKWRSRLEIAhFwcrNcixc' +
    'yrHi1UiBmhjHrmoW4vS+HwT4M3B1SECimYGnd90KDhLKXJOKyU8OKMMefXeW3Tws7uAgDwAeqRNy' +
    'u5e9f8FaLJcFbmubCYBesHGAx67m8urIvikQkVTrpiGcHDQvX5fAeaYeurJZqxY4pF/sYDum9LVY' +
    'HGgJiPhp0AyO0QNz1QMNrV8kXWiFZrAOBzPrJJM2dkIz2ARytg0GHgrFOIa7RRVGPr0gGMIrgY/Q' +
    '6u4N2956lxsEiEQAAAAASUVORK5CYII=';

  IconWebsite : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAcUlEQVR4nMWSCwqAIBBEdxdP2f3v' +
    'MbGWoYs7QhI9MNR841fkY3CXyhHajjEZ8M8TNMWYrHoVFlKYXCvidZXWt1oBotw6u5WkAZjJSQhi' +
    'AJjMQnT8n8s9fibNLYtB4/4mGJupewcpJpvY7wHDLWy47zkB6WBHT/ZiHocAAAAASUVORK5CYII=';

  IconReopen : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAi0lEQVR4nJVSWw7AIAhbE0/qwbwq' +
    'iw8COnmsH264thYcnhxIvSOpuYp1TdqNfp7AfHQy0Sj7grljY/B1XcRwfiNizv6EOG9H4ExgiEyU' +
    'M4G0McXL/d4PwAa7uNa525oQT7Bx0Qm0+EZ2WoApTiWAI44S4PKnfcRWAh4iPH2UYM3AR+IWfEQz' +
    'cLWR+QvcSEFzOy+RoQAAAABJRU5ErkJggg==';

  IconSaveAll : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAhklEQVR4nJ1S2w3AIAg8DVP42bEY' +
    '0LH66Ro2NDbBZ6CXKBEF7pAAoMKHoA8kGzOQM1DusoxIV/oCp2LRUbkqW90JmA8SnNBM4JGwZEL6' +
    'ojXrFDQxIcPDbVL5OdJOcZwCVoinKjIXu9kwJfCgWhdzb2NL8H6J6FxptUj5zWTsgZtJN9cDExMe' +
    'cIhGyM6B3IMAAAAASUVORK5CYII=';

  IconClose : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAgElEQVR4nKWT4RKAIAiD2R3v/8p0' +
    'etHRgsjcH0PXx9QS2RTCsy14c4BZzgBQQvTF7NRrBDAK7CRwYSmBBTCvKwOqFJW0S9DBtTUNIM2Z' +
    'iOE8B+0SzFeB6Z7nwX65NS/2T1Dv/imBy9G8qlTntxCg/CW1/wJ3DnV9XQR4gLO53zoA8B84H5Ym' +
    'w8wAAAAASUVORK5CYII=';

  IconNewClient : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAXklEQVR4nMWTgQqAMAhEn/v/f74w' +
    'GJg5iox6IJNjO6dj0MQAdU3aN5io0HVjz86qDV1pgybjixmsXuwwgx4Cecw8almPZ94dooHlKq55' +
    'VJVPBhTEFmIBX7PxY/7/TBskGib4IBNzCwAAAABJRU5ErkJggg==';

  IconSwapClient : String =
    'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAZElEQVR4nMVTCQrAIAyL/f+fMzIo' +
    'dNJSWWELKD1iiBWBIRYATkXGDhxM6jzg3Kiuwa5mGMK+mEH1Yo8ZvAcBanm896rYc9O2GjsiixNF' +
    'PLe9kTmp3OmsZaqREHtRoHN9jP8/0wUxFSz61gyFuwAAAABJRU5ErkJggg==';

  AppIconData : String =
    'AAABAAEAICAQAAAAAADoAgAAFgAAACgAAAAgAAAAQAAAAAEABAAAAAAAgAIAAAAAAAAAAAAAAAAA' +
    'AAAAAAAAAAAAAACAAACAAAAAgIAAgAAAAIAAgACAgAAAgICAAMDAwAAAAP8AAP8AAAD//wD/AAAA' +
    '/wD/AP//AAD///8AAAAAAAAAAAkAAAAAAAAAAAAAAAAAAACZkAAAAAAAAAAAAAAAAAD/SUiAAAAA' +
    'AAAAAAAAAAD4dElEd/AAAAAAAAAAAAAPdECZkER/AAAAAAAAAAAA90CZmZmTR/AAAAAAAAAAD3QJ' +
    'AAkACQR/AAAAAAAAAHdwkAAAAACQR3AAAAAAAACHSQAAAAAACUfwAAAAAAAAhAkAAAAAAAkEgAAA' +
    'AAAACUSZAAAAAAAJlEkAAAAAAJmZmZAAAAAAmZmZkAAAAAAJRJkAAAAAAAmUSQAAAAAAAPQJAAAA' +
    'AAAJBHAAAAAAAAD3SQAAAAAACUeAAAAAAAAAD0CQAAAAAJBHAAAAAAAAAAh0CQAJAAkEfwAAAAAA' +
    'AAAA90CZSUmTR/AAAAAAAAAAAAh0RJCURI8AAAAAAAAAAAAAB0k0CUcAAAAAAAAAAAAAAH9kkJdP' +
    'cAAAAAAAAAAAAP+HZwkHZI/wAAAAAAAAAA+HZwAAAAdH/wAAAAAAAAD4dnAAAAAAdH/wAAAAAAAI' +
    '90cAAAAAAAdH+AAAAAAAAEQAAAAAAAAABEAAAAAAAAmZkAAAAAAAAJmZAAAAAAAAdAAAAAAAAAAE' +
    'QAAAAAAAAPdAAAAAAAAAR/AAAAAAAAAIdAAAAAAABHcAAAAAAAAAj/+AAAAAAP/4gAAAAAAAAAAA' +
    'AAAAAAAAAAAAAAD//H////Af///AB///gAP//wAB//4AAP/8AAB/+A7gP/gf8D/4H/A/8B/wH+AP' +
    '4A/wH/Af+B/wP/gf8D/8DuB//AAAf/4AAP//AAH//4AD//8AAf/+AAD//AKAf/gP4D/wH/Af8D/4' +
    'H/A/+B/wP/gf+D/4P/wf8H/4D+A//B/wfw==';

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
  Bmp : TBitmap;
begin
  AList.Width := 16;
  AList.Height := 16;

  Bmp := LoadPNGBitmap(IconNew); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconOpen); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconSave); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconCut); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconCopy); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconPaste); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconFind); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconReplace); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconStart); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconPause); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconStop); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconStopAll); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconHelp); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconWebsite); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconReopen); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconSaveAll); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconClose); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconNewClient); AList.Add(Bmp, nil); Bmp.Free;
  Bmp := LoadPNGBitmap(IconSwapClient); AList.Add(Bmp, nil); Bmp.Free;
  // 0=New 1=Open 2=Save 3=Cut 4=Copy 5=Paste 6=Find 7=Replace 8=Start 9=Pause
  // 10=Stop 11=StopAll 12=Help 13=Website 14=Reopen 15=SaveAll 16=Close
  // 17=NewClient 18=SwapClient -- matches TagToImageIndex above exactly.
end;

////////////////////////////////////////////////////////////////////////////////
function LoadAppIcon : TIcon;
var
  Raw : String;
  MS  : TMemoryStream;
begin
  Raw := DecodeStringBase64(AppIconData);
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
