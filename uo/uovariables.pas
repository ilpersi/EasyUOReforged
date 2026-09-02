unit uovariables;

{
  Ported from the original Delphi 7 uo\uovariables.pas (read in full, 1296 lines).
  TUOVar reads/writes named client state -- character stats, containers, targets,
  hands, journal/system messages, etc. -- at the raw memory offsets TCstDB (Phase
  1's uoclidata.pas) supplies for the attached client's exact version. Every
  accessor goes through Cst.XXXXX named fields, never a hardcoded offset, so
  Phase 1's TCstDB reshape (Values: array[TConstantNames] of Cardinal) is
  invisible here -- this file needed no changes for that.

  One required fix, the same conflict already found and fixed twice in Phase 2
  (parser\variables.pas's Names/Values, parser\scripts.pas's Info): ContList
  (IgnoreCont's ignore-list) is a manually-kept-sorted TStringList searched via
  .Find and inserted via .Insert at the found position, with Sorted left False --
  exactly the pattern FPC's TStringList can't support with Sorted itself (Find
  needs Sorted=True; Insert-at-arbitrary-index forbids it). Fixed with the same
  common\EuoSortedList.FindSortedPos helper, moved there from parser\ this phase
  specifically because uo\ needs it too and must not depend on parser\.

  Every RWV(Read,...)/RWV(Write,...) call is unchanged: RWV already gates on
  UOSel.Nr>0 and safely zero-fills on read failure, so every accessor here is a
  correct, harmless no-op with no client selected -- exactly the property the
  interpreter-core phase's test stubs relied on, and now true of the real
  engine too.

  Kept verbatim, not "fixed": the WriteTargCurs code-caving payload (TargetHandler)
  is raw x86-32 machine code as byte-literal DATA, not a Delphi asm block -- it
  runs on the always-32-bit remote client, so it needs no changes for a 64-bit
  host (matching uoevents.pas's same pattern, called out in CLAUDE.md). The
  VirtualProtectEx/ReadProcessMemory/WriteProcessMemory calls against the remote
  process's fixed address ($400000) are the officially-supported 64-bit-host/
  32-bit-target pattern confirmed in the migration plan.
}

{$mode delphi}{$H+}

interface
uses Windows, SysUtils, Classes, access, EuoSortedList, uoselector, uoclidata;

const
  Read  = 0;
  Write = 1;

type
  TUOVar          = class(TObject)
  private
    UOSel         : TUOSel;
    Cst           : TCstDB;
    ContList      : TStringList;
    BPID          : Cardinal;
    BPIDChar      : Cardinal;
    function      GetStat(var Addr : Cardinal) : Boolean;
    procedure     RWV(RW : Cardinal; MemPos : Cardinal; Buf : PChar; Length : Cardinal);
    ////////////////////////////////////////////////////////////////////////////
    function      ReadLShard : Cardinal;      procedure     WriteLShard(Value : Cardinal);
    function      ReadContPosX : Integer;     procedure     WriteContPosX(Value : Integer);
    function      ReadContPosY : Integer;     procedure     WriteContPosY(Value : Integer);
    function      ReadNextCPosX : Integer;    procedure     WriteNextCPosX(Value : Integer);
    function      ReadNextCPosY : Integer;    procedure     WriteNextCPosY(Value : Integer);
    function      ReadTargCurs : Boolean;     procedure     WriteTargCurs(Value : Boolean);
    function      ReadCliXRes : Cardinal;     procedure     WriteCliXRes(Value : Cardinal);
    function      ReadCliYRes : Cardinal;     procedure     WriteCliYRes(Value : Cardinal);
    function      ReadCliLeft : Cardinal;     procedure     WriteCliLeft(Value : Cardinal);
    function      ReadCliTop : Cardinal;      procedure     WriteCliTop(Value : Cardinal);
    function      ReadLastSpell : Cardinal;   procedure     WriteLastSpell(Value : Cardinal);
    function      ReadLastSkill : Cardinal;   procedure     WriteLastSkill(Value : Cardinal);
    function      ReadLTargetKind : Cardinal; procedure     WriteLTargetKind(Value : Cardinal);
    function      ReadLTargetTile : Cardinal; procedure     WriteLTargetTile(Value : Cardinal);
    function      ReadLTargetX : Integer;     procedure     WriteLTargetX(Value : Integer);
    function      ReadLTargetY : Integer;     procedure     WriteLTargetY(Value : Integer);
    function      ReadLTargetZ : Integer;     procedure     WriteLTargetZ(Value : Integer);
    function      ReadLTargetID : Cardinal;   procedure     WriteLTargetID(Value : Cardinal);
    function      ReadLHandID : Cardinal;     procedure     WriteLHandID(Value : Cardinal);
    function      ReadRHandID : Cardinal;     procedure     WriteRHandID(Value : Cardinal);
    function      ReadLObjectID : Cardinal;   procedure     WriteLObjectID(Value : Cardinal);
    function      ReadCliTitle : String;      procedure     WriteCliTitle(Value : String);
  public
    VarRes        : Boolean;
    constructor   Create(UOSelector : TUOSel);
    procedure     Free;
    function      GetContAddr(var Addr : Cardinal; Index : Integer = 0) : Boolean;
    procedure     IgnoreCont(s : String); overload;
    procedure     IgnoreCont(c : Cardinal); overload;
    ////////////////////////////////////////////////////////////////////////////
    function      CharPosX    : Integer;
    function      CharPosY    : Integer;
    function      CharPosZ    : Integer;
    function      CharID      : Cardinal;
    function      CharGhost   : Boolean;
    function      CharType    : Cardinal;
    function      CharStatus  : String;
    function      CharDir     : Cardinal;
    function      CharName    : String;
    function      Sex         : Integer;
    function      Str         : Integer;
    function      MaxWeight   : Integer;
    function      Dex         : Integer;
    function      Int         : Integer;
    function      Hits        : Integer;
    function      MaxHits     : Integer;
    function      Stamina     : Integer;
    function      MaxStam     : Integer;
    function      Mana        : Integer;
    function      MaxMana     : Integer;
    function      Gold        : Integer;
    function      Weight      : Integer;
    function      MaxStats    : Integer;
    function      AR          : Integer;
    function      Followers   : Integer;
    function      MaxFol      : Integer;
    function      FR          : Integer;
    function      CR          : Integer;
    function      PR          : Integer;
    function      ER          : Integer;
    function      Luck        : Integer;
    function      MaxDmg      : Integer;
    function      MinDmg      : Integer;
    function      TP          : Integer;
    function      Shard       : String;
    function      ContSizeX   : Cardinal;
    function      ContSizeY   : Cardinal;
    function      ContKind    : Cardinal;
    function      ContID      : Cardinal;
    function      ContType    : Cardinal;
    function      ContName    : String;
    function      CliLang     : String;
    function      CliVer      : String;
    function      CliLogged   : Boolean;
    function      CursKind    : Cardinal;
    function      EnemyHits   : Cardinal;
    function      EnemyID     : Cardinal;
    function      LObjectType : Cardinal;
    function      LLiftedID   : Cardinal;
    function      LLiftedType : Cardinal;
    function      LLiftedKind : Cardinal;
    function      SysMsg      : String;
    function      BackpackID  : Cardinal;
    function      CursorX     : Integer;
    function      CursorY     : Integer;
    ////////////////////////////////////////////////////////////////////////////
    property      LShard      : Cardinal read ReadLShard write WriteLShard;
    property      ContPosX    : Integer read ReadContPosX write WriteContPosX;
    property      ContPosY    : Integer read ReadContPosY write WriteContPosY;
    property      NextCPosX   : Integer read ReadNextCPosX write WriteNextCPosX;
    property      NextCPosY   : Integer read ReadNextCPosY write WriteNextCPosY;
    property      TargCurs    : Boolean read ReadTargCurs write WriteTargCurs;
    property      CliXRes     : Cardinal read ReadCliXRes write WriteCliXRes;
    property      CliYRes     : Cardinal read ReadCliYRes write WriteCliYRes;
    property      CliLeft     : Cardinal read ReadCliLeft write WriteCliLeft;
    property      CliTop      : Cardinal read ReadCliTop write WriteCliTop;
    property      LSpell      : Cardinal read ReadLastSpell write WriteLastSpell;
    property      LSkill      : Cardinal read ReadLastSkill write WriteLastSkill;
    property      LTargetKind : Cardinal read ReadLTargetKind write WriteLTargetKind;
    property      LTargetTile : Cardinal read ReadLTargetTile write WriteLTargetTile;
    property      LTargetX    : Integer read ReadLTargetX write WriteLTargetX;
    property      LTargetY    : Integer read ReadLTargetY write WriteLTargetY;
    property      LTargetZ    : Integer read ReadLTargetZ write WriteLTargetZ;
    property      LTargetID   : Cardinal read ReadLTargetID write WriteLTargetID;
    property      LHandID     : Cardinal read ReadLHandID write WriteLHandID;
    property      RHandID     : Cardinal read ReadRHandID write WriteRHandID;
    property      LObjectID   : Cardinal read ReadLObjectID write WriteLObjectID;
    property      CliTitle    : String read ReadCliTitle write WriteCliTitle;
  end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
implementation

const
  TargetHandler : Array[0..$2B] of Byte = (
    $56,                               // push esi
    $8B,$74,$24,$08,                   // mov esi, [esp+8]        sole parameter = clicked object
    $85,$F6,                           // test esi, esi           is it object or ground?
    $74,$21,                           // je 007FFF2A             don't do anything if not object!
    $8B,$06,                           // mov eax, [esi]
    $FF,$50,$2C,                       // call [eax+2C]           call the objects getClickable() function
    $85,$C0,                           // test eax, eax           0 or 1?
    $74,$18,                           // je 007FFF2A             don't do anything if 0!
    $8B,$86,$80,$00,$00,$00,           // mov eax, [esi+00000080]                ($14)
    $A3,$AA,$AA,$AA,$AA,               // mov [00DB6A1C], eax     #LTargetID=ID  ($19)
    $31,$C0,                           // xor eax, eax
    $A3,$BB,$BB,$BB,$BB,               // mov [00DDD790], eax     #TargCurs=0    ($20)
    $40,                               // inc eax
    $A3,$CC,$CC,$CC,$CC,               // mov [00DB6A30], eax     #LTargetKind=1 ($26)
    $5E,                               // pop esi
    $C3);                              // ret
  IgnoredConts =
    'BARK_GUMP'#13#10+
    'DAMAGENUMBERS_GUMP'#13#10+
    'DUMB_GUMP'#13#10+
    'GAMEAREAEDGEGUMP'#13#10+
    'MAP_GUMP'#13#10+
    'MENUBAR'#13#10+
    'MISSILE_GUMP'#13#10+
    'NEW_ITEM_PROP_GUMP'#13#10+
    'RETICLE_GUMP'#13#10+
    'TARGET_GUMP'#13#10+
    'UNICODE_BARK_GUMP';

////////////////////////////////////////////////////////////////////////////////
constructor TUOVar.Create(UOSelector : TUOSel);
begin
  inherited Create;
  UOSel:=UOSelector;
  Cst:=UOSel.CstDB;
  BPIDChar:=$00FFFFFF;
  ContList:=TStringList.Create;
  ContList.Text:=IgnoredConts;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOVar.Free;
begin
  ContList.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOVar.RWV(RW : Cardinal; MemPos : Cardinal; Buf : PChar; Length : Cardinal);
begin
  if RW=Read then
  begin
    ZeroMemory(Buf,Length);
    if UOSel.Nr>0 then
      ReadMem(UOSel.HProc,MemPos,Buf,Length);
    Exit;
  end;
  if UOSel.Nr>0 then
    WriteMem(UOSel.HProc,MemPos,Buf,Length);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.GetStat(var Addr : Cardinal) : Boolean;
begin
  RWV(Read,Cst.CHARPTR,@Addr,4);
  RWV(Read,Addr+Cst.BITEMID+$10,@Addr,4);
  Result:=Addr=0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure PrepareStr(var s : String);
var
  i : Integer;
begin
  s:=UpperCase(s);
  for i:=1 to Length(s) do
    if s[i]=' ' then s[i]:='_';
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.GetContAddr(var Addr : Cardinal; Index : Integer = 0) : Boolean;
var
  w : Word;
  i : Integer;
  c : Cardinal;
  s : String;
begin
  Result:=False;
  Addr:=Cst.CONTPOS-Cst.BCONTNEXT;
  repeat
    RWV(Read,Addr+Cst.BCONTNEXT,@Addr,4);
    if Addr=0 then Exit;

    RWV(Read,Addr,@w,2);
    if w=0 then Exit;
    if FindSortedPos(ContList,IntToStr(w),i) then Continue;

    RWV(Read,Addr+$08,@c,4);
    SetLength(s,64);
    RWV(Read,c,@s[1],64);
    s:=PChar(s);

    PrepareStr(s);
    if s<>'' then
      if FindSortedPos(ContList,s,i) then Continue;

    Dec(Index);
  until Index<0;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOVar.IgnoreCont(s : String);
var
  i : Integer;
begin
  PrepareStr(s);
  if not FindSortedPos(ContList,s,i) then
    ContList.Insert(i,s);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOVar.IgnoreCont(c : Cardinal);
begin
  case c of
    0: ContList.Clear;
    $FFFFFFFF: ContList.Text:=IgnoredConts;
    else IgnoreCont(IntToStr(c));
  end;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function TUOVar.CharPosX : Integer;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CHARPTR,@Buf,4);
  RWV(Read,Buf+$24,@Buf,2);
  Result:=SmallInt(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CharPosY : Integer;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CHARPTR,@Buf,4);
  RWV(Read,Buf+$26,@Buf,2);
  Result:=SmallInt(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CharPosZ : Integer;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CHARPTR,@Buf,4);
  RWV(Read,Buf+$28,@Buf,2);
  Result:=SmallInt(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CharID : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CHARPTR,@Buf,4);
  RWV(Read,Buf+Cst.BITEMID,@Buf,4);
  Result:=Buf;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CharGhost : Boolean;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CHARPTR,@Buf,4);
  RWV(Read,Buf+Cst.BITEMTYPE,@Buf,2);
  Result:=(Word(Buf)=$192) or (Word(Buf)=$193) or (Word(Buf)=607) or (Word(Buf)=608);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CharType : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CHARPTR,@Buf,4);
  RWV(Read,Buf+Cst.BITEMTYPE,@Buf,2);
  Result:=Word(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CharStatus : String;
var
  Cnt  : Integer;
  Buf  : Cardinal;
  Buf2 : Cardinal;
  sBuf : String;
begin
  RWV(Read,Cst.CHARPTR,@Buf2,4);
  RWV(Read,Buf2+Cst.BITEMID+Cst.BCHARSTATUS,@Buf,2);

  if Cst.FEXCHARSTATC>0 then
  begin
    RWV(Read,Buf2+Cst.BITEMID+Cst.BCHARSTATUS+Cst.FEXCHARSTATC,@Buf2,1);
    if Byte(Buf2)=1 then Buf:=Buf or 4;
  end;

  sBuf:='';
  for Cnt:=0 to 15 do
    if Boolean(Word(Buf) and (1 shl Cnt)) then
      sBuf:=Chr(65+Cnt)+sBuf;
  Result:=sBuf;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CharDir : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CHARDIR,@Buf,1);
  Result:=Byte(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CharName : String;
var
  Buf  : Cardinal;
  sBuf : String;
begin
  VarRes:=False;
  Result:='';
  if GetStat(Buf) then Exit;
  SetLength(sBuf,33);
  RWV(Read,Buf+Cst.BSTATNAME,@sBuf[1],33);
  Result:=PChar(@sBuf[1]);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Sex : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=-1;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+00,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Str : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+02,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.MaxWeight : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+02,@Buf,2);
  Result:=((7*SmallInt(Buf)) div 2)+40;
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Dex : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+04,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Int : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+06,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Hits : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+08,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.MaxHits : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+10,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Stamina : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+12,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.MaxStam : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+14,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Mana : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+16,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.MaxMana : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+18,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Gold : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+22,@Result,4);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Weight : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+Cst.BSTATWEIGHT,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.AR : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+Cst.BSTATAR+Cst.BSTATML,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.MaxStats : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+30+Cst.BSTATML,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Followers : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+32+Cst.BSTATML,@Buf,1);
  Result:=ShortInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.MaxFol : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+33+Cst.BSTATML,@Buf,1);
  Result:=ShortInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.FR : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+34+Cst.BSTATML,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CR : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+36+Cst.BSTATML,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.PR : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+38+Cst.BSTATML,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ER : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+40+Cst.BSTATML,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Luck : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+42+Cst.BSTATML+Cst.BSTAT1,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.MaxDmg : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+44+Cst.BSTATML+Cst.BSTAT1,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.MinDmg : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  if GetStat(Buf) then Exit;
  RWV(Read,Buf+Cst.BSTATNAME+$1E+46+Cst.BSTATML+Cst.BSTAT1,@Buf,2);
  Result:=SmallInt(Buf);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.TP : Integer;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if Cst.FEXTSTAT<>1 then Exit;
  RWV(Read,Cst.NEXTCPOS+Cst.BTITHE,@Buf,4);
  Result:=Buf;
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.Shard : String;
var
  sBuf : String;
begin
  SetLength(sBuf,33);
  RWV(Read,Cst.SHARDPOS,@sBuf[1],33);
  Result:=PChar(@sBuf[1]);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ContSizeX : Cardinal;
var
  Buf : Cardinal;
begin
  Result:=0;
  if GetContAddr(Buf) then
    RWV(Read,Buf+Cst.BCONTSIZEX,@Result,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ContSizeY : Cardinal;
var
  Buf : Cardinal;
begin
  Result:=0;
  if GetContAddr(Buf) then
    RWV(Read,Buf+Cst.BCONTSIZEX+4,@Result,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ContKind : Cardinal;
var
  Buf : Cardinal;
begin
  Result:=0;
  if GetContAddr(Buf) then
    RWV(Read,Buf,@Result,2);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ContID : Cardinal;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if not GetContAddr(Buf) then Exit;
  RWV(Read,Buf+Cst.BCONTITEM,@Buf,4);
  if Buf=0 then Exit;
  RWV(Read,Buf+Cst.BITEMID,@Result,4);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ContType : Cardinal;
var
  Buf : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  if not GetContAddr(Buf) then Exit;
  RWV(Read,Buf+Cst.BCONTITEM,@Buf,4);
  if Buf=0 then Exit;
  RWV(Read,Buf+Cst.BITEMTYPE,@Result,2);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ContName : String;
var
  Buf  : Cardinal;
  sBuf : String;
begin
  Result:='';
  if not GetContAddr(Buf) then Exit;
  RWV(Read,Buf+$08,@Buf,4);
  SetLength(sBuf,64);
  RWV(Read,Buf,@sBuf[1],64);
  Result:=PChar(sBuf);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CliLang : String;
var
  sBuf : String;
begin
  Result:='';
  // Was sBuf:='XXXX' in the original -- a string LITERAL assignment, not a
  // fresh allocation. Under FPC's copy-on-write AnsiString model, sBuf can
  // end up sharing memory with the read-only constant-pool literal itself;
  // @sBuf[1] handed to RWV as a WRITE target (ReadProcessMemory writing
  // directly into it) bypasses the normal Pascal-assignment path that would
  // trigger COW uniquing, so the write can land in read-only memory and
  // crash with an access violation -- confirmed live (this exact call
  // crashed every time; the very next line, sBuf[4], was never reached).
  // Delphi 7 apparently didn't share literals this way, so the original
  // never hit this. Fixed with SetLength, which guarantees a fresh,
  // unique, writable buffer -- the same pattern SysMsg (below) already
  // uses correctly for the same kind of RWV-into-string-buffer call.
  SetLength(sBuf,4);
  RWV(Read,Cst.LHANDID-Cst.BLANG,@sBuf[1],4);
  if sBuf[4]=#0 then Result:=PChar(@sBuf[1]);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CliVer : String;
begin
  Result:=UOSel.Ver;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CliLogged : Boolean;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CLILOGGED,@Buf,4);
  Result:=Buf=1;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CursKind : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CURSORKIND,@Buf,1);
  Result:=Byte(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.EnemyHits : Cardinal;
var
  Buf  : Cardinal;
  Buf2 : Cardinal;
begin
  VarRes:=False;
  Result:=0;
  RWV(Read,Cst.ENEMYHITS,@Buf,4);
  if Buf=0 then Exit;
  RWV(Read,Buf+4,@Buf2,4);
  if Buf2<>$FEEDBEEF then Exit;
  RWV(Read,Buf+Cst.BENEMYHPVAL,@Buf,2);
  Result:=Word(Buf)*4;
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.EnemyID : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.ENEMYID,@Buf,4);
  Result:=Buf;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.LObjectType : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+$08,@Buf,2);
  Result:=Word(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.LLiftedID : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LLIFTEDID,@Buf,4);
  Result:=Buf;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.LLiftedType : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LLIFTEDID-Cst.BLLIFTEDTYPE,@Buf,2);
  Result:=Word(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.LLiftedKind : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LLIFTEDID+Cst.BLLIFTEDKIND,@Buf,4);
  Result:=Buf;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.SysMsg : String;
var
  Cnt  : Integer;
  Buf  : Cardinal;
  sBuf : String;
begin
  VarRes:=False;
  Result:='';
  RWV(Read,Cst.SYSMSG,@Buf,4);
  if Buf=0 then Exit;
  // F_SYSMSGDIRECT (added during this migration, see uoclidata.pas): on clients where
  // this is set, the message object embeds its text inline at B_SYSMSGSTR rather than
  // holding a further pointer to it there -- skip the extra dereference the original
  // (pre-7.0.108.0) client layout required.
  if Cst.FSYSMSGDIRECT=0 then
    RWV(Read,Buf+Cst.BSYSMSGSTR,@Buf,4)
  else
    Buf:=Buf+Cst.BSYSMSGSTR;
  SetLength(sBuf,256);
  RWV(Read,Buf,@sBuf[1],256);
  if sBuf[2]=#0 then
    for Cnt:=128 downto 1 do
      Delete(sBuf,Cnt*2,1);
  Result:=PChar(@sBuf[1]);
  VarRes:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.BackpackID : Cardinal;
var
  Buf  : Cardinal;
  Buf2 : Cardinal;
  Buf3 : Cardinal;
  Buf4 : Cardinal;
begin
  VarRes:=True;
  Result:=BPID;
  RWV(Read,Cst.CHARPTR,@Buf,4);
  RWV(Read,Buf+Cst.BITEMID,@Buf2,4);
  if Buf2=BPIDChar then Exit;
  Result:=0;

  Buf4:=Buf;
  repeat
    RWV(Read,Buf+Cst.BITEMID+$C,@Buf,4);
    if Buf=0 then Break;
    RWV(Read,Buf+Cst.BITEMID+4,@Buf3,4);
    if Buf3<>Buf4 then Continue;

    Buf3:=0;
    RWV(Read,Buf+Cst.BITEMTYPE,@Buf3,2);
    if (Buf3<>3701)and(Buf3<>2482) then Continue;

    RWV(Read,Buf+Cst.BITEMID+Cst.BITEMSLOT,@Buf3,1);
    if Byte(Buf3)<>21 then Continue;

    RWV(Read,Buf+Cst.BITEMID,@BPID,4);
    BPIDChar:=Buf2;
    Result:=BPID;
    Exit;
  until False;
  VarRes:=False;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CursorX : Integer;
var
  CurPos : TPoint;
begin
  GetCursorPos(CurPos);
  ScreenToClient(UOSel.HWnd,CurPos);
  if CurPos.X>20000 then Result:=-1
  else Result:=CurPos.X;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.CursorY : Integer;
var
  CurPos : TPoint;
begin
  GetCursorPos(CurPos);
  ScreenToClient(UOSel.HWnd,CurPos);
  if CurPos.Y>20000 then Result:=-1
  else Result:=CurPos.Y;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function TUOVar.ReadLShard : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LSHARD,@Buf,4);
  Result:=Buf;
end;
procedure TUOVar.WriteLShard(Value : Cardinal);
begin
  RWV(Write,Cst.LSHARD,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadContPosX : Integer;
var
  Buf : Cardinal;
begin
  Result:=0;
  if GetContAddr(Buf) then
    RWV(Read,Buf+Cst.BCONTX,@Result,4);
end;
procedure TUOVar.WriteContPosX(Value : Integer);
var
  Buf : Cardinal;
begin
  if GetContAddr(Buf) then
    RWV(Write,Buf+Cst.BCONTX,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadContPosY : Integer;
var
  Buf : Cardinal;
begin
  Result:=0;
  if GetContAddr(Buf) then
    RWV(Read,Buf+Cst.BCONTX+4,@Result,4);
end;
procedure TUOVar.WriteContPosY(Value : Integer);
var
  Buf : Cardinal;
begin
  if GetContAddr(Buf) then
    RWV(Write,Buf+Cst.BCONTX+4,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadNextCPosX : Integer;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.NEXTCPOS+4,@Buf,4);
  Result:=Integer(Buf)+16;
end;
procedure TUOVar.WriteNextCPosX(Value : Integer);
begin
  Value:=Value-16;
  RWV(Write,Cst.NEXTCPOS+4,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadNextCPosY : Integer;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.NEXTCPOS+0,@Buf,4);
  Result:=Integer(Buf)+16;
end;
procedure TUOVar.WriteNextCPosY(Value : Integer);
begin
  Value:=Value-16;
  RWV(Write,Cst.NEXTCPOS+0,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadTargCurs : Boolean;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.TARGETCURS,@Buf,1);
  Result:=Byte(Buf)=1;
end;
procedure TUOVar.WriteTargCurs(Value : Boolean);
var
  sBuf  : String;
  Base  : Cardinal;
  Dummy : Cardinal;
begin
  SetLength(sBuf,SizeOf(TargetHandler));
  Move(TargetHandler,sBuf[1],Length(sBuf));
  Cardinal((@sBuf[1+$14])^):=Cst.BITEMID;
  Cardinal((@sBuf[1+$19])^):=Cst.LHANDID+$18; //LTargetID
  Cardinal((@sBuf[1+$20])^):=Cst.TARGETCURS;
  Cardinal((@sBuf[1+$26])^):=Cst.LHANDID+Cst.BLTARGTILE+$04; //LTargetKind

  //Base:=Cst.BMEMBASE-$100;
  Base:=$400600-$100;
  VirtualProtectEx(
    UOSel.HProc,
    Pointer($400000),
    $1000,
    PAGE_EXECUTE_READWRITE,
    @Dummy
   );

  RWV(Write,Base,@sBuf[1],Length(sBuf)); //install custom handler for next click (gets uninstalled
  RWV(Write,Cst.TARGETCURS+Cst.BTARGPROC,@Base,4); //automatically by normal client-initiated click)
  RWV(Write,Cst.TARGETCURS,@Value,1);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadCliXRes : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CLIXRES,@Buf,4);
  Result:=Buf;
end;
procedure TUOVar.WriteCliXRes(Value : Cardinal);
begin
  RWV(Write,Cst.CLIXRES,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadCliYRes : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CLIXRES+4,@Buf,4);
  Result:=Buf;
end;
procedure TUOVar.WriteCliYRes(Value : Cardinal);
begin
  RWV(Write,Cst.CLIXRES+4,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadCliLeft : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CLILEFT,@Buf,4);
  Result:=Buf;
end;
procedure TUOVar.WriteCliLeft(Value : Cardinal);
begin
  RWV(Write,Cst.CLILEFT,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadCliTop : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.CLILEFT+4,@Buf,4);
  Result:=Buf;
end;
procedure TUOVar.WriteCliTop(Value : Cardinal);
begin
  RWV(Write,Cst.CLILEFT+4,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadLastSpell : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+$10+0,@Buf,1);
  Result:=Byte(Buf);
end;
procedure TUOVar.WriteLastSpell(Value : Cardinal);
begin
  RWV(Write,Cst.LHANDID+$10+0,@Value,1);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadLastSkill : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+$10+4,@Buf,1);
  Result:=Byte(Buf);
end;
procedure TUOVar.WriteLastSkill(Value : Cardinal);
begin
  RWV(Write,Cst.LHANDID+$10+4,@Value,1);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadLTargetKind : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+Cst.BLTARGTILE+$04,@Buf,1);
  Result:=Byte(Buf);
end;
procedure TUOVar.WriteLTargetKind(Value : Cardinal);
begin
  RWV(Write,Cst.LHANDID+Cst.BLTARGTILE+$04,@Value,1);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadLTargetTile : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+Cst.BLTARGTILE,@Buf,2);
  Result:=Word(Buf);
end;
procedure TUOVar.WriteLTargetTile(Value : Cardinal);
begin
  RWV(Write,Cst.LHANDID+Cst.BLTARGTILE,@Value,2);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadLTargetX : Integer;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+Cst.BLTARGX+0,@Buf,2);
  Result:=SmallInt(Buf);
end;
procedure TUOVar.WriteLTargetX(Value : Integer);
begin
  RWV(Write,Cst.LHANDID+Cst.BLTARGX+0,@Value,2);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadLTargetY : Integer;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+Cst.BLTARGX+2,@Buf,2);
  Result:=SmallInt(Buf);
end;
procedure TUOVar.WriteLTargetY(Value : Integer);
begin
  RWV(Write,Cst.LHANDID+Cst.BLTARGX+2,@Value,2);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadLTargetZ : Integer;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+Cst.BLTARGX+4,@Buf,2);
  Result:=SmallInt(Buf);
end;
procedure TUOVar.WriteLTargetZ(Value : Integer);
begin
  RWV(Write,Cst.LHANDID+Cst.BLTARGX+4,@Value,2);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadLTargetID : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+$18,@Buf,4);
  Result:=Buf;
end;
procedure TUOVar.WriteLTargetID(Value : Cardinal);
begin
  RWV(Write,Cst.LHANDID+$18,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadLHandID : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID,@Buf,4);
  Result:=Buf;
end;
procedure TUOVar.WriteLHandID(Value : Cardinal);
begin
  RWV(Write,Cst.LHANDID,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadRHandID : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+4,@Buf,4);
  Result:=Buf;
end;
procedure TUOVar.WriteRHandID(Value : Cardinal);
begin
  RWV(Write,Cst.LHANDID+4,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadLObjectID : Cardinal;
var
  Buf : Cardinal;
begin
  RWV(Read,Cst.LHANDID+$0C,@Buf,4);
  Result:=Buf;
end;
procedure TUOVar.WriteLObjectID(Value : Cardinal);
begin
  RWV(Write,Cst.LHANDID+$0C,@Value,4);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOVar.ReadCliTitle : String;
var
  Buf : Array[0..65536] of Byte;
begin
  GetWindowText(UOSel.HWnd,@Buf,65536);
  Result:=PChar(@Buf);
end;
procedure TUOVar.WriteCliTitle(Value : String);
begin
  SetWindowText(UOSel.HWnd,PChar(Value));
end;

////////////////////////////////////////////////////////////////////////////////
end.
