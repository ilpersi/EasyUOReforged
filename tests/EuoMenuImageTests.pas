unit EuoMenuImageTests;

{
  MENU IMAGE regression: images are colour-keyed ($FEEEED) so whatever is behind
  them shows through wherever the script has not drawn. With 32bpp bitmaps LCL's
  colour-key mask never matched (alpha is compared too), the images painted as
  opaque lavender blocks and hid e.g. SOS Master's blue sea. This renders a real
  (shown) MENU form -- painted once blank, then drawn into, as SOS Master does --
  and checks pixels, so it needs a window station; it reports
  itself ignored if the form cannot be realised.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Forms, fpcunit, testregistry, EuoMenu;

type
  TEuoMenuImageTests = class(TTestCase)
  published
    procedure TestImageIsTransparentWhereNotDrawn;
  end;

implementation

const
  SEA  = $FF5555;   // BGR, as a script's "$FF5555"
  LAND = $66FF66;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenuImageTests.TestImageIsTransparentWhereNotDrawn;
var
  M    : TMenuObj;
  Shot : TBitmap;
begin
  Application.Initialize;   // console runner never does; registers the window classes
  M := TMenuObj.Create;
  try
    M.Form.ClientWidth := 60;
    M.Form.ClientHeight := 40;
    M.ShapeCreate('sea', 0, 0, 60, 40, 3, 7, 1, SEA, 7, SEA);
    M.ImageCreate('img', 10, 0, 1, 40);
    M.ImageCreate('pix', 20, 0, 3, 40);
    M.Form.Show;
    Application.ProcessMessages;
    if not M.Form.Showing then
    begin
      Ignore('MENU form could not be shown in this session');
      Exit;
    end;
    // Paint once while the images are still blank (LCL caches the colour-key
    // mask at this point), THEN draw -- the order SOS Master uses.
    M.Form.GetFormImage.Free;
    M.ImageLine('img', 0, 10, 0, 20, LAND);
    M.ImagePixLine('pix', 0, 5, 'ZAAZAAZAA');   // R=200 G=0 B=0, 3 pixels
    Application.ProcessMessages;
    Shot := M.Form.GetFormImage;
    try
      AssertEquals('undrawn pixel shows what is behind the image', SEA,
        Shot.Canvas.Pixels[10, 30]);
      AssertEquals('drawn line pixel keeps its colour', LAND,
        Shot.Canvas.Pixels[10, 15]);
      AssertEquals('PIXLINE pixel keeps its colour', $0000C8,
        Shot.Canvas.Pixels[21, 5]);
      AssertEquals('undrawn pixel beside PIXLINE shows what is behind',
        SEA, Shot.Canvas.Pixels[21, 6]);
    finally
      Shot.Free;
    end;
  finally
    M.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoMenuImageTests);
end.
