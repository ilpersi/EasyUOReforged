unit EuoConversion;

{
  Ported from the original Delphi 7 parser\conversion.pas, verbatim (pure logic, no
  OS dependency, no bitness-sensitive constructs). Already validated directly against
  this exact source during the migration plan's research phase: the Sys26 magic
  constants (xor 69, +7, base 26) and IsNumber's exact literal-syntax rules are
  unchanged from that verification.

  Every one of these functions is used throughout the interpreter for parsing/
  formatting values that flow between script text and native types -- this unit has
  no dependency on anything else in the interpreter, so it's the natural first piece
  to port and test in isolation.
}

{$mode delphi}{$H+}

interface

function IsNumber(Str : String) : Boolean;
function ReplaceStr(Str,RepWhat,RepWith : String) : String;

function SToCDef(S : String; Def : Cardinal) : Cardinal; overload;
function SToI64Def(S : String; Def : Int64) : Int64; overload;
function CardToSys26(Num : Cardinal) : String; overload;
function StrToSys26(NumStr : String) : String; overload;
function Sys26ToCard(Str26 : String) : Cardinal; overload;
function Sys26ToStr(Str26 : String) : String; overload;
function SToCol(S : String) : Integer; overload;

function SToCDef(S : String; Def : Cardinal; var ConvRes : Boolean) : Cardinal; overload;
function SToI64Def(S : String; Def : Int64; var ConvRes : Boolean) : Int64; overload;
function CardToSys26(Num : Cardinal; var ConvRes : Boolean) : String; overload;
function StrToSys26(NumStr : String; var ConvRes : Boolean) : String; overload;
function Sys26ToCard(Str26 : String; var ConvRes : Boolean) : Cardinal; overload;
function Sys26ToStr(Str26 : String; var ConvRes : Boolean) : String; overload;
function SToCol(S : String; var ConvRes : Boolean) : Integer; overload;

implementation
uses SysUtils, Graphics;

////////////////////////////////////////////////////////////////////////////////
function IsNumber(Str : String) : Boolean;
var
  Cnt1 : Integer;
begin
  Str:=Trim(Str); // Allow sloppy format!

  Result:=False;

  if Str='' then Exit;
  if Str[1] in ['+','-','$'] then
    if Length(Str)<2 then Exit;

  case Str[1] of
    '0'..'9': begin
                if Length(Str)>18 then Exit;
                for Cnt1:=2 to Length(Str) do
                  if not(Str[Cnt1] in ['0'..'9']) then Exit;
              end;
    '-','+' : begin
                if Length(Str)>19 then Exit;
                for Cnt1:=2 to Length(Str) do
                  if not(Str[Cnt1] in ['0'..'9']) then Exit;
              end;
    '$' :     begin
                if Length(Str)>16 then Exit;
                for Cnt1:=2 to Length(Str) do
                  if not(Str[Cnt1] in ['0'..'9','A'..'F','a'..'f']) then Exit;
              end;
    else Exit;
  end;

  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function ReplaceStr(Str,RepWhat,RepWith : String) : String;
var
  Cnt : Integer;
begin
  repeat
    Cnt:=Pos(RepWhat,Str);
    if Cnt<1 then Break;
    Delete(Str,Cnt,Length(RepWhat));
    Insert(RepWith,Str,Cnt);
  until False;
  Result:=Str;
end;

////////////////////////////////////////////////////////////////////////////////
function SToCDef(S : String; Def : Cardinal) : Cardinal;
var
  ConvRes : Boolean;
begin
  Result:=SToCDef(S,Def,ConvRes);
end;

////////////////////////////////////////////////////////////////////////////////
function SToI64Def(S : String; Def : Int64) : Int64;
var
  ConvRes : Boolean;
begin
  Result:=SToI64Def(S,Def,ConvRes);
end;

////////////////////////////////////////////////////////////////////////////////
function CardToSys26(Num : Cardinal) : String;
var
  ConvRes : Boolean;
begin
  Result:=CardToSys26(Num,ConvRes);
end;

////////////////////////////////////////////////////////////////////////////////
function StrToSys26(NumStr : String) : String;
var
  ConvRes : Boolean;
begin
  Result:=StrToSys26(NumStr,ConvRes);
end;

////////////////////////////////////////////////////////////////////////////////
function Sys26ToCard(Str26 : String) : Cardinal;
var
  ConvRes : Boolean;
begin
  Result:=Sys26ToCard(Str26,ConvRes);
end;

////////////////////////////////////////////////////////////////////////////////
function Sys26ToStr(Str26 : String) : String;
var
  ConvRes : Boolean;
begin
  Result:=Sys26ToStr(Str26,ConvRes);
end;

////////////////////////////////////////////////////////////////////////////////
function SToCol(S : String) : Integer;
var
  ConvRes : Boolean;
begin
  Result:=SToCol(S,ConvRes);
end;

////////////////////////////////////////////////////////////////////////////////
function SToCDef(S : String; Def : Cardinal; var ConvRes : Boolean) : Cardinal;
var
  i64Buf : Int64;
begin
  S:=Trim(S); // Allow sloppy format!

  Result:=Def;
  ConvRes:=False;

  if not IsNumber(S) then Exit;
  i64Buf:=StrToInt64(S);
  if i64Buf<0 then Exit;

  Result:=i64Buf;
  ConvRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function SToI64Def(S : String; Def : Int64; var ConvRes : Boolean) : Int64;
begin
  S:=Trim(S); // Allow sloppy format!

  Result:=Def;
  ConvRes:=False;

  if not IsNumber(S) then Exit;

  Result:=StrToInt64(S);
  ConvRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function CardToSys26(Num : Cardinal; var ConvRes : Boolean) : String;
const
  ZSys = 26;
var
  BNum   : Cardinal;
  Cnt1,
  Cnt2   : Integer;
  SysNum : Array[0..7] of Integer;
  NumStr : String;
begin
  BNum:=(Num xor 69)+7;

  Cnt1:=0;
  repeat
    SysNum[Cnt1]:=BNum mod ZSys;
    if BNum<ZSys then Break;
    BNum:=BNum div ZSys;
    Inc(Cnt1);
  until False;

  NumStr:='';
  for Cnt2:=0 to Cnt1 do
    NumStr:=NumStr+Char(65+SysNum[Cnt2]);

  Result:=NumStr;
  ConvRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function StrToSys26(NumStr : String; var ConvRes : Boolean) : String;
var
  Num : Int64;
begin
  Result:='';
  Num:=SToI64Def(NumStr,0,ConvRes);
  if not ConvRes then Exit;
  ConvRes:=False;
  if (Num<0) or (Num>$FFFFFFFF) then Exit;
  Result:=CardToSys26(Num);
end;

////////////////////////////////////////////////////////////////////////////////
function Sys26ToCard(Str26 : String; var ConvRes : Boolean) : Cardinal;
const
  ZSys = 26;
var
  Num     : Int64;
  Cnt     : Integer;
  Ch      : Byte;
begin
  Str26:=Trim(Str26); // Allow sloppy format!

  Result:=0;
  ConvRes:=False;
  Str26:=UpperCase(Str26);
  if Str26='' then Exit;

  Num:=0;
  for Cnt:=Length(Str26) downto 1 do
  begin
    Ch:=Byte(Str26[Cnt])-65;
    if not (Ch in [0..ZSys-1]) then Exit;

    Num:=Num*ZSys;
    Num:=Num+Ch;
  end;

  Num:=(Num-7)xor 69;
  if Num>$FFFFFFFF then Exit;
  ConvRes:=True;
  Result:=Num;
end;

////////////////////////////////////////////////////////////////////////////////
function Sys26ToStr(Str26 : String; var ConvRes : Boolean) : String;
var
  Num : Cardinal;
begin
  Result:='';
  Num:=Sys26ToCard(Str26,ConvRes);
  if ConvRes then Result:=IntToStr(Num);
end;

////////////////////////////////////////////////////////////////////////////////
function SToCol(S : String; var ConvRes : Boolean) : Integer;
begin
  S:=Trim(S); // Allow sloppy format!

  Result:=SToI64Def(S,0,ConvRes);
  if ConvRes then Exit;

  ConvRes:=True;
  try
    Result:=StringToColor('cl'+S);
  except
    ConvRes:=False;
    Result:=0;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
end.
