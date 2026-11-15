unit EuoGumps;

{
  Port addition (SCANGUMPS, docs\gump-analysis.md): what the interpreter needs from a gump
  snapshot without a client, so all of it runs in the test suite. TUOCmd (uo\uocommands.pas, GUMP
  LIST) reads the client; this unit turns its TGumpInfo into the text a #Gump... variable shows.

  Formats, the way the matching #Cont... variables show them:
  - IDs (linked object, serial, type ID), the art ID and the kind: EUO literal text (CardToSys26);
  - minimized: #true / #false, i.e. -1 / 0;
  - position and size: plain numbers; the name with its spaces as _ (as #ContName).
  A value that is not there reads N/A (the function returns False): no gump selected, no art, no
  linked object, a serial or type ID of a gump that is not a server gump, or a field whose table
  offset is 0 on this client build.

  ScanGumps' filter words are read by uocommands.ParseGumpFilter, which uo.dll shares.
}

{$mode delphi}{$H+}

interface
uses
  SysUtils, uocommands, EuoConversion;

type
  TGumpField = (gfName, gfKind, gfPosX, gfPosY, gfSizeX, gfSizeY, gfArt, gfMin, gfObjID, gfSerial,
                gfTypeID);

// The text of field F of G (Valid: G is a selected entry). False = N/A.
function GumpFieldText(const G : TGumpInfo; Valid : Boolean; F : TGumpField; out Text : String) : Boolean;

implementation

////////////////////////////////////////////////////////////////////////////////
function GumpFieldText(const G : TGumpInfo; Valid : Boolean; F : TGumpField; out Text : String) : Boolean;
var
  I : Integer;
begin
  Text:='';
  Result:=Valid;
  if not Valid then Exit;
  case F of
    gfName  : begin
                Text:=G.Name;
                for I:=1 to Length(Text) do
                  if Text[I]=' ' then Text[I]:='_';
                Result:=Text<>'';
              end;
    gfKind  : Text:=CardToSys26(G.Kind);
    gfPosX  : Text:=IntToStr(G.X);
    gfPosY  : Text:=IntToStr(G.Y);
    gfSizeX : Text:=IntToStr(G.W);
    gfSizeY : Text:=IntToStr(G.H);
    gfArt   : begin
                Result:=G.ArtValid;
                if Result then Text:=CardToSys26(G.Art);
              end;
    gfMin   : begin
                Result:=G.MinValid;
                if not Result then Exit;
                if G.Minimized then Text:='-1' else Text:='0';
              end;
    gfObjID : begin
                Result:=G.ObjValid;
                if Result then Text:=CardToSys26(G.ObjID);
              end;
    gfSerial: begin
                Result:=G.ServerValid;
                if Result then Text:=CardToSys26(G.Serial);
              end;
    gfTypeID: begin
                Result:=G.ServerValid;
                if Result then Text:=CardToSys26(G.TypeID);
              end;
  end;
  if not Result then Text:='';
end;


end.
