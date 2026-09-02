unit uocommands;

{
  Ported from the original Delphi 7 uo\uocommands.pas (read in full, 1012 lines).
  TUOCmd implements the higher-level client actions (Click, Move, Key, FindItem's
  scan/filter engine, journal scanning, tile lookups via tiles.pas, shop/container
  inspection, OpenClient/CloseClient) on top of TUOVar's raw variable access.

  Three required fixes, all the same class of issue already found elsewhere
  (or, for the third, found live via this migration's own testing):
  - IgnoreIDs/IgnoreLists (IgnoreItem/IgnoreItemReset) are manually-kept-sorted
    TStringLists searched via .Find and inserted via .Insert/.InsertObject at the
    found position -- the same Sorted-vs-Find/Insert conflict fixed for
    uovariables.pas's ContList this same phase, and for parser\'s Names/Values/
    Info in Phase 2. Fixed with the same common\EuoSortedList.FindSortedPos.
  - The local TDelayFunc duplicate declaration is removed in favor of the one
    shared common\uotypes.pas declaration (unified in Phase 2 for
    EuoStdCommands.pas; uocommands.pas's copy was the other original duplicate
    the migration plan called out).
  - ScanItems's ItemList.Sort(@ListCompare) originally passed a NESTED
    function's address to TList.Sort. That compiles cleanly under FPC but
    crashes with an access violation the instant Sort actually calls it --
    a nested function's address implicitly carries its enclosing stack
    frame, which TList's plain TListSortCompare calling convention doesn't
    expect. Found live: FindItem (and anything else reaching ScanItems)
    reliably crashed/hung after correctly collecting every item (confirmed
    by instrumenting the collection loop itself, which completed normally
    every time) right at this call. Fixed by hoisting the comparator out to
    a top-level ItemListCompare function -- logic byte-for-byte unchanged,
    only its scope moved, since it never referenced any of ScanItems's own
    locals in the first place.

  TItemRes/PItemRes are unchanged -- they already match tests\stubs\uocommands.pas's
  shape exactly (that stub was deliberately written to mirror this file's real
  public surface), so nothing calling into TUOCmd needs to change when this
  replaces the stub.

  Kept verbatim: the raw byte-buffer field-extraction idiom throughout
  ScanItems/GetShopInfo/GetCont (Cardinal/Word/SmallInt((@Buf[N])^) -- proven
  to compile cleanly under FPC's Delphi mode in uovariables.pas this same
  phase, not just assumed here), and every RWV(Read/Write,...) call, which --
  like uovariables.pas's identical RWV helper -- already gates on UOSel.Nr>0
  and safely no-ops with no client selected.
}

{$mode delphi}{$H+}

interface
uses Windows, SysUtils, Messages, Classes, Registry, access, EuoSortedList,
     uotypes, uovariables, uoselector, uoclidata, tiles;

type
  TSkillEntry   = record
    Name        : String;
    Code        : Integer;
  end;

  TItemRes      = record
    ItemID      : Cardinal;
    ItemType    : Cardinal;
    ItemKind    : Integer;
    ContID      : Cardinal;
    ItemX       : Integer;
    ItemY       : Integer;
    ItemZ       : Integer;
    ItemStack   : Cardinal;
    ItemRep     : Cardinal;
    ItemCol     : Cardinal;
  end;
  PItemRes      = ^TItemRes;

  TUOCmd        = class(TObject)
  private
    UOSel       : TUOSel;
    Cst         : TCstDB;
    UOVar       : TUOVar;
    TileObj     : TTTBasic;
    JournalList : TStringList;
    Delay       : TDelayFunc;
    IgnoreIDs   : TStringList;
    IgnoreLists : TStringList;
    IgnoreCnt   : Cardinal;
    ItemList    : TList;
    FilterList  : TList;
    FilterID    : TList;
    FilterType  : TList;
    FilterCont  : TList;
    FilterGnd   : Cardinal;
    FilterAllC  : Boolean;
    FilterAllG  : Boolean;
    function    GetVK(KeyStr : String) : Cardinal;
    procedure   RWV(RW : Cardinal; MemPos : Cardinal; Buf : PChar; Length : Cardinal);
    procedure   ClearFilter;
    procedure   RefreshFilter;
  public
    ItemRes     : TItemRes;
    ItemCnt     : Cardinal;
    SkillReal   : Cardinal;
    SkillNorm   : Cardinal;
    SkillCap    : Cardinal;
    SkillLock   : Cardinal;
    JournalRef  : Cardinal;
    JournalCnt  : Cardinal;
    JournalStr  : String;
    JournalCol  : Cardinal;
    TileType    : Cardinal;
    TileZ       : Integer;
    TileName    : String;
    TileFlags   : Cardinal;
    ContKind    : Cardinal;
    ContName    : String;
    ContX       : Integer;
    ContY       : Integer;
    ContSX      : Cardinal;
    ContSY      : Cardinal;
    ContHP      : Cardinal;
    ContID      : Cardinal;
    ContType    : Cardinal;
    ShopPos     : Cardinal;
    ShopCnt     : Cardinal;
    ShopID      : Cardinal;
    ShopType    : Cardinal;
    ShopMax     : Cardinal;
    ShopPrice   : Cardinal;
    ShopName    : String;
    constructor Create(UOSelector : TUOSel; UOVariables : TUOVar; DFunc : TDelayFunc);
    procedure   Free;
    procedure   Key(KeyStr : String; Ctrl,Alt,Shift : Boolean);
    procedure   Click(X,Y : Cardinal; Cnt : Cardinal = 1; Left : Boolean = True; Down : Boolean = True;
                Up : Boolean = True; Fast : Boolean = False; MC : Boolean = False);
    function    Move(X,Y,Acc,Timeout : Cardinal) : Boolean;
    procedure   Msg(Str : String);
    procedure   GetSkill(SkillStr : String);
    function    GetPix(X,Y : Cardinal) : Cardinal;
    procedure   ScanItems(VisibleOnly : Boolean = True);
    procedure   FilterItems(Filter : Cardinal; Value : Cardinal = $FFFFFFFF);
    procedure   GetItem(Index : Cardinal);
    function    HideItem(ID : Cardinal) : Boolean;
    function    IgnoreItem(IDType : Cardinal; List : String = '') : Boolean;
    function    IgnoreItemReset(List : String = '') : Boolean;
    function    ScanJournal(OldRef : Cardinal) : Boolean;
    procedure   GetJournal(Index : Cardinal);
    function    TileInit(NoOverrides : Boolean = False) : Boolean;
    function    TileCnt(X,Y : Cardinal; Facet : Integer = -1) : Cardinal;
    function    TileGet(X,Y,Layer : Cardinal; Facet : Integer = -1) : Boolean;
    function    GetCont(Index : Cardinal) : Boolean;
    function    GetShopInfo : Boolean;
    function    SetShopItem(ID,Quantity : Cardinal) : Boolean;
    function    OpenClient(SwitchTo : Boolean) : Boolean;
    procedure   CloseClient;
  end;

  function SkillFind(A,Z : Integer; Name : String; var Table : array of TSkillEntry) : Integer;

var
  SkillList : array[0..57] of TSkillEntry = (
    (Name: 'ALCH'; Code: 000), (Name: 'ANAT'; Code: 001),
    (Name: 'ANIL'; Code: 002), (Name: 'ANIM'; Code: 035),
    (Name: 'ARCH'; Code: 031), (Name: 'ARMS'; Code: 004),
    (Name: 'BEGG'; Code: 006), (Name: 'BLAC'; Code: 007),
    (Name: 'BOWC'; Code: 008), (Name: 'BUSH'; Code: 052),
    (Name: 'CAMP'; Code: 010), (Name: 'CARP'; Code: 011),
    (Name: 'CART'; Code: 012), (Name: 'CHIV'; Code: 051),
    (Name: 'COOK'; Code: 013), (Name: 'DETE'; Code: 014),
    (Name: 'DISC'; Code: 015), (Name: 'EVAL'; Code: 016),
    (Name: 'FENC'; Code: 042), (Name: 'FISH'; Code: 018),
    (Name: 'FOCU'; Code: 050), (Name: 'FORE'; Code: 019),
    (Name: 'HEAL'; Code: 017), (Name: 'HERD'; Code: 020),
    (Name: 'HIDI'; Code: 021), (Name: 'IMBU'; Code: 056),
    (Name: 'INSC'; Code: 023), (Name: 'ITEM'; Code: 003),
    (Name: 'LOCK'; Code: 024), (Name: 'LUMB'; Code: 044),
    (Name: 'MACE'; Code: 041), (Name: 'MAGE'; Code: 025),
    (Name: 'MEDI'; Code: 046), (Name: 'MINI'; Code: 045),
    (Name: 'MUSI'; Code: 029), (Name: 'MYST'; Code: 055),
    (Name: 'NECR'; Code: 049), (Name: 'NINJ'; Code: 053),
    (Name: 'PARR'; Code: 005), (Name: 'PEAC'; Code: 009),
    (Name: 'POIS'; Code: 030), (Name: 'PROV'; Code: 022),
    (Name: 'REMO'; Code: 048), (Name: 'RESI'; Code: 026),
    (Name: 'SNOO'; Code: 028), (Name: 'SPEL'; Code: 054),
    (Name: 'SPIR'; Code: 032), (Name: 'STEA'; Code: 033),
    (Name: 'STLT'; Code: 047), (Name: 'SWOR'; Code: 040),
    (Name: 'TACT'; Code: 027), (Name: 'TAIL'; Code: 034),
    (Name: 'TAST'; Code: 036), (Name: 'THRO'; Code: 057),
    (Name: 'TINK'; Code: 037), (Name: 'TRAC'; Code: 038),
    (Name: 'VETE'; Code: 039), (Name: 'WRES'; Code: 043));

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TUOCmd.Create(UOSelector : TUOSel; UOVariables : TUOVar; DFunc : TDelayFunc);
begin
  inherited Create;
  UOSel:=UOSelector;
  Cst:=UOSel.CstDB;
  UOVar:=UOVariables;
  TileObj:=nil;
  Delay:=DFunc;
  JournalList:=TStringList.Create;
  IgnoreIDs:=TStringList.Create;
  IgnoreLists:=TStringList.Create;
  ItemList:=TList.Create;
  FilterList:=TList.Create;
  FilterID:=TList.Create;
  FilterType:=TList.Create;
  FilterCont:=TList.Create;
  ////////////////////
  ZeroMemory(@ItemRes,SizeOf(ItemRes));
  ItemCnt:=0;
  FilterGnd:=$FFFFFFFF;
  FilterAllC:=False;
  FilterAllG:=False;
  IgnoreCnt:=0;
  SkillReal:=0;
  SkillNorm:=0;
  SkillCap:=0;
  SkillLock:=0;
  JournalRef:=0;
  JournalCnt:=0;
  JournalStr:='';
  JournalCol:=0;
  TileType:=0;
  TileZ:=0;
  TileName:='';
  TileFlags:=0;
  ContKind:=0;
  ContName:='';
  ContX:=0;
  ContY:=0;
  ContSX:=0;
  ContSY:=0;
  ContHP:=0;
  ContID:=0;
  ContType:=0;
  ShopPos:=0;
  ShopCnt:=0;
  ShopID:=0;
  ShopType:=0;
  ShopMax:=0;
  ShopPrice:=0;
  ShopName:='';
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.Free;
var
  Cnt : Integer;
begin
  JournalList.Free;
  IgnoreIDs.Free;
  IgnoreLists.Free;
  for Cnt:=0 to ItemList.Count-1 do
    Dispose(ItemList[Cnt]);
  ItemList.Free;
  FilterList.Free;
  FilterID.Free;
  FilterType.Free;
  FilterCont.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.RWV(RW : Cardinal; MemPos : Cardinal; Buf : PChar; Length : Cardinal);
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
function TUOCmd.OpenClient(SwitchTo : Boolean) : Boolean;
type
  TScanStr = record
    Str      : String;
    Offs     : Integer;
    Joker    : Char;
  end;
const
  SplashRemover      : TScanStr =
    (Str: #139#1#36#1#139#1#36#1#137#134#192#0; Offs: 9; Joker: #1);
  MultiClientWarning : TScanStr =
    (Str: #133#192#139#29#1#1#1#1#116#1#106#4#104; Offs: 0; Joker: #1);
var
  Reg   : TRegistry;
  Path  : String;
  sInfo : TStartupInfo;
  pInfo : TProcessInformation;
  PHnd  : Cardinal;
  PID   : Cardinal;
  c     : Cardinal;
  i,j   : Integer;
begin
  Result:=False;

  Reg:=TRegistry.Create;
  Reg.OpenKey('\Software\EasyUO',True);
  Path:=UOSel.ExePath;
  try
    if Path='' then Path:=Reg.ReadString('ExePath')
    else Reg.WriteString('ExePath',Path);
  except
    Path:='';
  end;
  Reg.Free;
  if not FileExists(Path) then Exit;

  ZeroMemory(@sInfo,sizeof(sInfo));
  ZeroMemory(@pInfo,sizeof(pInfo));
  sInfo.cb:=sizeof(sInfo);
  sInfo.dwFlags:=STARTF_USESHOWWINDOW;
  sInfo.wShowWindow:=SW_SHOW;

  if not CreateProcess(
    {executable } PChar(Path),
    {cmdline    } nil,
    {secuattrib } nil,
    {threadattr } nil,
    {inherhandle} False,
    {creatflags } CREATE_SUSPENDED,
    {environment} nil,
    {currentdir } PChar(ExtractFilePath(Path)),
    {startupinfo} sInfo,
    {processinfo} pInfo) then Exit;

  PHnd:=pInfo.hProcess;

  with SplashRemover do c:=SearchMem(PHnd,Str,Joker)+Offs;
  if c>$FF then WriteMem(PHnd,c,#158,1);
  with MultiClientWarning do c:=SearchMem(PHnd,Str,Joker)+Offs;
  if c>$FF then WriteMem(PHnd,c,#49,1);

  PID:=pInfo.dwProcessId;
  ResumeThread(pInfo.hThread);

  if SwitchTo then
  for i:=1 to 40 do
  begin
    if not Delay(250) then Exit;
    for j:=1 to UOSel.Cnt do
    if UOSel.GetPID(j)=PID then
    begin
      UOSel.SelectClient(j);
      Result:=True;
      Exit;
    end;
  end;
  Result:=not SwitchTo;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.CloseClient;
begin
  SendMessage(UOSel.HWnd,WM_CLOSE,0,0);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.SetShopItem(ID,Quantity : Cardinal) : Boolean;
var
  Buf  : Cardinal;
  Buf2 : Cardinal;
  sBuf : String;
begin
  Result:=False;

  SetLength(sBuf,9);
  Buf:=Cst.CONTPOS-Cst.BCONTNEXT;
  repeat
    RWV(Read,Buf+Cst.BCONTNEXT,@Buf,4);
    if Buf=0 then Exit;
    RWV(Read,Buf+$08,@Buf2,4);
    RWV(Read,Buf2,@sBuf[1],9);
  until PChar(sBuf)='bill gump';

  RWV(Read,Buf+Cst.BBILLFIRST,@Buf,4);
  if Buf=0 then Exit;

  repeat
    RWV(Read,Buf+$04,@Buf2,4);
    if Buf2=ID then Break;
    RWV(Read,Buf+$0C,@Buf,4);
    if Buf=0 then Exit;
  until False;
  RWV(Write,Buf+$0A,@Quantity,2);

  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.GetShopInfo : Boolean;
var
  sBuf     : String;
  Buf      : Cardinal;
  Buf2     : Cardinal;
begin
  Result:=False;

  ShopPos:=0;
  ShopCnt:=0;
  ShopID:=0;
  ShopType:=0;
  ShopMax:=0;
  ShopPrice:=0;
  ShopName:='';

  SetLength(sBuf,9);
  Buf:=Cst.CONTPOS-Cst.BCONTNEXT;
  repeat
    RWV(Read,Buf+Cst.BCONTNEXT,@Buf,4);
    if Buf=0 then Exit;
    RWV(Read,Buf+$08,@Buf2,4);
    RWV(Read,Buf2,@sBuf[1],9);
  until PChar(sBuf)='shop gump';

  RWV(Read,Buf+Cst.BSHOPCURRENT,@Buf,4);
  if Buf=0 then Exit;

  ShopPos:=0;
  Buf2:=Buf;
  repeat
    RWV(Read,Buf2+Cst.BSHOPNEXT+$4,@Buf2,4); //FindFirst
    Inc(ShopPos);
  until Buf2=0;

  ShopCnt:=ShopPos-1;
  Buf2:=Buf;
  repeat
    RWV(Read,Buf2+Cst.BSHOPNEXT,@Buf2,4);
    Inc(ShopCnt);
  until Buf2=0;

  SetLength(sBuf,256);
  RWV(Read,Buf,@sBuf[1],256);

  ShopType:=Word((@sBuf[Cst.BITEMTYPE+1])^);
  ShopID:=Cardinal((@sBuf[Cst.BITEMID+1])^);
  ShopMax:=Word((@sBuf[Cst.BITEMSTACK+1])^);
  ShopPrice:=Cardinal((@sBuf[Cst.BITEMID+Cst.BSHOPPRICE+1])^);
  Buf2:=Cardinal((@sBuf[Cst.BITEMID+Cst.BSHOPPRICE-4+1])^);
  RWV(Read,Buf2,@sBuf[1],64);
  ShopName:=PChar(sBuf);

  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.GetCont(Index : Cardinal) : Boolean;
var
  Buf  : Cardinal;
  Buf2 : Cardinal;
begin
  ContKind:=0;
  ContName:='';
  ContX:=0;
  ContY:=0;
  ContSX:=0;
  ContSY:=0;
  ContID:=0;
  ContType:=0;
  ContHP:=0;

  Result:=False;
  if not UOVar.GetContAddr(Buf,Index) then Exit;
  Result:=True;

  RWV(Read,Buf,@ContKind,2);
  RWV(Read,Buf+Cst.BCONTX,@ContX,4);
  RWV(Read,Buf+Cst.BCONTX+4,@ContY,4);
  RWV(Read,Buf+Cst.BCONTSIZEX,@ContSX,4);
  RWV(Read,Buf+Cst.BCONTSIZEX+4,@ContSY,4);

  RWV(Read,Buf+$08,@Buf2,4);
  SetLength(ContName,64);
  RWV(Read,Buf2,@ContName[1],64);
  ContName:=PChar(@ContName[1]);

  if ContName='status gump' then
  begin
    RWV(Read,Buf+Cst.BCONTNEXT+$92,@ContHP,4);
    if ContHP shr 16 > 0 then
      ContHP:=Word(ContHP)*100 div (ContHP shr 16);
  end;

  RWV(Read,Buf+Cst.BCONTITEM,@Buf2,4);
  if Buf2=0 then Exit;
  RWV(Read,Buf2+Cst.BITEMID,@ContID,4);
  RWV(Read,Buf2+Cst.BITEMTYPE,@ContType,2);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.TileInit(NoOverrides : Boolean = False) : Boolean;
var
  Path : String;
begin
  Result:=False;
  Path:=ExtractFilePath(UOSel.ExePath);
  if not DirectoryExists(Path) then Exit;
  if TileObj<>nil then TileObj.Free;
  TileObj:=TTTBasic.init(Path,not NoOverrides,Cst);
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.TileCnt(X,Y : Cardinal; Facet : Integer = -1) : Cardinal;
var
  Cnt : Byte;
begin
  Result:=0;
  if TileObj=nil then Exit;
  if Facet<0 then Facet:=UOVar.CursKind;
  if not TileObj.GetLayerCount(X,Y,Facet,Cnt) then Exit;
  Result:=Cnt+1;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.TileGet(X,Y,Layer : Cardinal; Facet : Integer = -1) : Boolean;
var
  w : Word;
  i : ShortInt;
begin
  repeat
    if TileObj=nil then Break;
    if Facet<0 then Facet:=UOVar.CursKind;
    if not TileObj.GetTileData(X,Y,Facet,Layer-1,w,i,TileName,TileFlags) then Break;
    TileType:=w;
    TileZ:=i;
    Result:=True;
    Exit;
  until True;
  TileType:=0;
  TileZ:=0;
  TileName:='';
  TileFlags:=0;
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.GetJournal(Index : Cardinal);
begin
  JournalStr:='';
  JournalCol:=0;
  if Index>=JournalList.Count then Exit;
  JournalStr:=JournalList[Index];
  JournalCol:=Cardinal(JournalList.Objects[Index]);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.ScanJournal(OldRef : Cardinal) : Boolean;
type
  TItem  = packed record
    Pos  : Cardinal;
    Col  : Cardinal;
    Kind : Byte;
    Fill : array[9..27] of Byte;
    Next : Cardinal;
  end;
var
  i,j   : Integer;
  Item  : TItem;
  sBuf  : array[0..$FF] of Byte;
  Node  : Cardinal;
  NCol  : Cardinal;
  NKind : Cardinal;
begin
  Result:=False;
  OldRef:=OldRef xor $D1EBEEF;

  if Cst.FJOURNALDIRECT=1 then
  begin
    // New journal-node layout, added during this migration (client 7.0.108.0+
    // -- see uoclidata.pas's SysVar701080 comment for the full derivation,
    // confirmed via live disassembly). Text is embedded inline at the node's
    // own start (up to SizeOf(sBuf) bytes read here, same cap as the original
    // layout below), Col/Kind are full Cardinals at B_JCOL/B_JKIND (Kind is
    // still compared against exactly $12 to mean "unicode, de-interleave" --
    // same convention as the original Item.Kind=$12 check), and the chain
    // toward older entries runs through B_JNEXTPTR instead of a fixed
    // record's Next field.
    RWV(Read,Cst.JOURNALPTR,@Node,4);
    JournalRef:=Node xor $D1EBEEF;

    i:=0;
    JournalList.Clear;
    while Node<>0 do
    begin
      if Node=OldRef then
      begin
        JournalCnt:=i;
        Result:=True;
      end;
      RWV(Read,Node+Cst.BJCOL,@NCol,4);
      RWV(Read,Node+Cst.BJKIND,@NKind,4);
      RWV(Read,Node,@sBuf,SizeOf(sBuf));
      sBuf[$FE]:=0;
      if NKind=$12 then
        for j:=0 to $7F do sBuf[j]:=sBuf[j*2];
      JournalList.AddObject(PChar(@sBuf),Pointer(NCol));
      RWV(Read,Node+Cst.BJNEXTPTR,@Node,4);
      Inc(i);
    end;

    if not Result then JournalCnt:=JournalList.Count;
    Exit;
  end;

  // Original (pre-7.0.108.0) fixed-record layout, unchanged.
  RWV(Read,Cst.JOURNALPTR,@Item.Next,4);
  JournalRef:=Item.Next xor $D1EBEEF;

  i:=0;
  JournalList.Clear;
  while Item.Next<>0 do
  begin
    if Item.Next=OldRef then
    begin
      JournalCnt:=i;
      Result:=True;
    end;
    RWV(Read,Item.Next,@Item,SizeOf(Item));
    RWV(Read,Item.Pos,@sBuf,SizeOf(sBuf));
    sBuf[$FE]:=0;
    if Item.Kind=$12 then
      for j:=0 to $7F do sBuf[j]:=sBuf[j*2];
    JournalList.AddObject(PChar(@sBuf),Pointer(Item.Col));
    Inc(i);
  end;

  if not Result then JournalCnt:=JournalList.Count;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.IgnoreItemReset(List : String = '') : Boolean;
var
  i : Integer;
  j : Integer;
begin
  if List='' then
  begin
    IgnoreIDs.Clear;
    IgnoreLists.Clear;
    Result:=True;
    Exit;
  end;
  List:=UpperCase(List);
  Result:=FindSortedPos(IgnoreLists,List,i);
  if not Result then Exit;
  for j:=IgnoreIDs.Count-1 downto 0 do
    if IgnoreIDs.Objects[j]=IgnoreLists.Objects[i] then
      IgnoreIDs.Delete(j);
  IgnoreLists.Delete(i);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.IgnoreItem(IDType : Cardinal; List : String = '') : Boolean;
var
  s : String;
  i : Integer;
  j : Integer;
begin
  s:=IntToStr(IDType);
  List:=UpperCase(List);
  Result:=not FindSortedPos(IgnoreIDs,s,i);
  if Result then
  begin
    if not FindSortedPos(IgnoreLists,List,j) then
    begin
      Inc(IgnoreCnt);
      IgnoreLists.InsertObject(j,List,Pointer(IgnoreCnt));
    end;
    IgnoreIDs.InsertObject(i,s,IgnoreLists.Objects[j]);
  end
  else IgnoreIDs.Delete(i);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.HideItem(ID : Cardinal) : Boolean;
var
  Buf : Array[0..4] of Cardinal;
begin
  Result:=False;
  Buf[3]:=Cst.CHARPTR-Cst.BITEMID-$C;
  repeat
    Buf[4]:=Buf[3];
    RWV(Read,Buf[3]+Cst.BITEMID,@Buf,16);
    if Buf[0]=ID then Break;
    if Buf[3]=0 then Exit;
  until False;
  RWV(Write,Buf[4]+$24,#0#0#0#0,4);
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.GetItem(Index : Cardinal);
begin
  if Index>=FilterList.Count then
  begin
    ZeroMemory(@ItemRes,SizeOf(ItemRes));
    ItemRes.ItemKind:=-1;
  end
  else ItemRes:=TItemRes(FilterList[Index]^);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.ClearFilter;
begin
  FilterID.Clear;
  FilterType.Clear;
  FilterCont.Clear;
  FilterGnd:=$FFFFFFFF;
  FilterAllC:=False;
  FilterAllG:=False;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.RefreshFilter;
var
  i    : Integer;
  b1   : Boolean;
  b2   : Boolean;
  p    : PItemRes;
  a,b  : Cardinal;
  x,y  : Cardinal;
begin
  x:=UOVar.CharPosX;
  y:=UOVar.CharPosY;
  FilterList.Clear;
  for i:=0 to ItemList.Count-1 do
  begin
    p:=ItemList[i];

    b1:=True;
    if (FilterID.Count>0) or (FilterType.Count>0) then
    begin
      b1:=False;
      if FilterID.IndexOf(Pointer(p.ItemID))>=0 then b1:=True;
      if FilterType.IndexOf(Pointer(p.ItemType))>=0 then b1:=True;
    end;

    b2:=True;
    if (FilterCont.Count>0) or (FilterGnd<$FFFFFFFF) or FilterAllC or FilterAllG then
    begin
      b2:=False;

      if p.ItemKind=0 then
      begin
        if FilterAllC then b2:=True
        else if FilterCont.IndexOf(Pointer(p.ContID))>=0 then b2:=True;
      end;

      if p.ItemKind=1 then
      begin
        if FilterGnd<$FFFFFFFF then
        begin
          a:=Abs(p.ItemX-x);
          b:=Abs(p.ItemY-y);
          if b>a then a:=b;
          if a<=FilterGnd then b2:=True;
        end;
        if FilterAllG then b2:=True;
      end;

    end;

    if b1 and b2 then FilterList.Add(p);
  end;

  ZeroMemory(@ItemRes,SizeOf(ItemRes));
  ItemCnt:=FilterList.Count;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.FilterItems(Filter : Cardinal; Value : Cardinal = $FFFFFFFF);
const
  CLEAR     = 0;
  ITEMID    = 1;
  ITEMTYPE  = 2;
  CONTAINER = 3;
  GROUND    = 4;
begin
  case Filter of
    CLEAR     : ClearFilter;
    ITEMID    : if Value<$FFFFFFFF then FilterID.Add(Pointer(Value));
    ITEMTYPE  : if Value<$FFFFFFFF then FilterType.Add(Pointer(Value));
    CONTAINER : if Value<$FFFFFFFF then FilterCont.Add(Pointer(Value))
                else FilterAllC:=True;
    GROUND    : if Value<$FFFFFFFF then FilterGnd:=Value
                else FilterAllG:=True;
  end;
  RefreshFilter;
end;

////////////////////////////////////////////////////////////////////////////////
// Hoisted out of ScanItems (was a nested function there, ListCompare) to fix a
// real crash: TList.Sort expects a TListSortCompare (plain function(Item1,
// Item2: Pointer): Integer, no implicit parent-frame context), but a Pascal
// NESTED function's address carries an implicit reference to its enclosing
// stack frame -- incompatible with that plain function-pointer calling
// convention. Passing @ListCompare (nested) to ItemList.Sort compiled fine
// but crashed with an access violation the moment Sort actually invoked it
// (confirmed live: the item-collection loop above completed correctly --
// 876 real items collected -- and the crash traced to this exact call).
// This function is otherwise byte-for-byte the original ListCompare; only
// its scope changed, not its logic.
function ItemListCompare(Item1, Item2 : PItemRes) : Integer;
begin
  Result:=0;
  if Item1^.ItemID<Item2^.ItemID then Result:=+1;
  if Item1^.ItemID>Item2^.ItemID then Result:=-1;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.ScanItems(VisibleOnly : Boolean = True);
var
  Buf     : Array[0..$2FF] of Byte;
  cBuf    : Cardinal;
  Dat     : TItemRes;
  PDat    : PItemRes;
  Nxt     : Cardinal;
  i       : Integer;
begin
  for Nxt:=1 to ItemList.Count do
    Dispose(ItemList.Items[Nxt-1]);
  ItemList.Clear;

  RWV(Read,Cst.CHARPTR,@Nxt,4);
  while Nxt>0 do
  begin
    RWV(Read,Nxt,@Buf,Cst.BITEMID+Cst.BFINDREP+1);
    Nxt:=Cardinal((@Buf[Cst.BITEMID+$0C])^);

    Dat.ItemID:=Cardinal((@Buf[Cst.BITEMID])^);
    Dat.ItemType:=Word((@Buf[Cst.BITEMTYPE])^);
    Dat.ItemKind:=Buf[$20];
    Dat.ItemX:=SmallInt((@Buf[$24])^);
    Dat.ItemY:=SmallInt((@Buf[$26])^);
    Dat.ItemZ:=SmallInt((@Buf[$28])^);
    Dat.ItemStack:=Word((@Buf[Cst.BITEMSTACK])^);
    Dat.ItemRep:=Buf[Cst.BITEMID+Cst.BFINDREP];
    Dat.ItemCol:=Word((@Buf[Cst.BITEMSTACK+2])^);

    if FindSortedPos(IgnoreIDs,IntToStr(Dat.ItemID),i) then Continue;
    if FindSortedPos(IgnoreIDs,IntToStr(Dat.ItemType),i) then Continue;

    Dat.ContID:=0;
    if Dat.ItemKind=0 then
    begin
      Dat.ItemZ:=0;

      cBuf:=Cardinal((@Buf[Cst.BITEMID+$04])^); //PtrToContItemStruct
      if cBuf=0 then Continue;
      RWV(Read,cBuf,@Buf,Cst.BITEMID+Cst.BGUMPPTR+4);

      Dat.ContID:=Cardinal((@Buf[Cst.BITEMID])^);
      cBuf:=Cardinal((@Buf[Cst.BITEMID+Cst.BGUMPPTR])^); //PtrToContGumpStruct

      if cBuf<>0 then
      begin
        RWV(Read,cBuf+Cst.BCONTX,@Buf,8);
        Dat.ItemX:=Dat.ItemX+Integer((@Buf[0])^);
        Dat.ItemY:=Dat.ItemY+Integer((@Buf[4])^);
      end
      else begin
        if VisibleOnly then Continue;
        Dat.ItemX:=0;
        Dat.ItemY:=0;
      end;
    end;

    New(PDat);
    PDat^:=Dat;
    ItemList.Add(PDat);
  end;

  ItemList.Sort(@ItemListCompare);
  ClearFilter;
  RefreshFilter;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.GetPix(X,Y : Cardinal) : Cardinal;
var
  DC : HDC;
begin
  DC:=GetDC(UOSel.HWnd);
  Result:=GetPixel(DC,X,Y);
  ReleaseDC(UOSel.HWnd,DC);
end;

////////////////////////////////////////////////////////////////////////////////
function SkillFind(A,Z : Integer; Name : String; var Table : array of TSkillEntry) : Integer;
var M,i : Integer;
begin
  Result:=-1;
  if (Z<A) then Exit;
  M:=A+(Z-A)shr 1;
  i:=CompareStr(Table[M].Name,Name);
  if i>0 then Result:=SkillFind(A,M-1,Name,Table)
  else if i<0 then Result:=SkillFind(M+1,Z,Name,Table)
  else Result:=M;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.GetSkill(SkillStr : String);
var
  Cnt : Integer;
begin
  SkillReal:=0;
  SkillNorm:=0;
  SkillCap:=0;
  SkillLock:=0;

  Cnt:=SkillFind(0,High(SkillList),Copy(UpperCase(SkillStr),1,4),SkillList);
  if Cnt<0 then Exit;
  Cnt:=SkillList[Cnt].Code;

  RWV(Read,Cst.SKILLSPOS+Cnt*2,@SkillReal,2);
  RWV(Read,Cst.SKILLSPOS+Cnt*2+Cst.BSKILLDIST,@SkillNorm,2);
  RWV(Read,Cst.SKILLCAPS+Cnt*2,@SkillCap,2);
  RWV(Read,Cst.SKILLLOCK+Cnt,@SkillLock,1);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.Msg(Str : String);
var
  Cnt : Integer;
begin
  for Cnt:=1 to Length(Str) do
    PostMessage(UOSel.HWnd,WM_CHAR,Integer(Str[Cnt]),0);
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.Move(X,Y,Acc,Timeout : Cardinal) : Boolean;
const
  Dir : Array[0..7] of Integer = (VK_PRIOR,VK_RIGHT,VK_NEXT,
  VK_DOWN,VK_END,VK_LEFT,VK_HOME,VK_UP);
var
  dx,dy    : Integer;
  dist     : Cardinal;
  key      : Cardinal;
  spd      : Cardinal;
  olddist  : Cardinal;
  bcnt     : Integer;
  bcnt2    : Cardinal;
  e        : Boolean;
  cnt      : Integer;
  gtc      : Int64;
begin
  Result:=False;
  key:=0;
  e:=False;
  bcnt:=0;
  bcnt2:=0;
  olddist:=99999;

  Dec(TimeOut);
  gtc:=GetTickCount;

  repeat
    if GetTickCount>gtc+TimeOut then Exit;

    dx:=X-UOVar.CharPosX;
    dy:=Y-UOVar.CharPosY;
    dist:=Abs(dy);
    if Abs(dx)>Abs(dy) then dist:=Abs(dx);

    if dist<=Acc then
    begin
      if Acc>1 then Break;
      if e then Break;
      if not Delay(150) then Exit;
      e:=True;
      Continue;
    end;
    e:=False;

    if dist>1 then
    begin
      if Abs(dx)<=1 then dx:=0;
      if Abs(dy)<=1 then dy:=0;
    end;

    spd:=50;
    if dist<4 then spd:=150;
    if dist<2 then spd:=300;

    if (dx=0) and (dy<0) then key:=0;
    if (dx>0) and (dy<0) then key:=1;
    if (dx>0) and (dy=0) then key:=2;
    if (dx>0) and (dy>0) then key:=3;
    if (dx=0) and (dy>0) then key:=4;
    if (dx<0) and (dy>0) then key:=5;
    if (dx<0) and (dy=0) then key:=6;
    if (dx<0) and (dy<0) then key:=7;

    Inc(bcnt);
    if dist<olddist then
    begin
      olddist:=dist;
      bcnt:=0;
      bcnt2:=0;
    end;
    if bcnt>20 then
    begin
      key:=(key+(Random(2))*4-2) mod 8;
      bcnt:=15-(dist-olddist);
      if bcnt<5 then bcnt:=5;
      Inc(bcnt2,2);
      if bcnt2>20 then Exit;
      Spd:=100;
    end;

    for Cnt:=1 to 1+bcnt2 do
    begin
      PostMessage(UOSel.HWnd,WM_KEYDOWN,Dir[key],(1 shl 30)+1);
      if not Delay(spd) then Exit;
    end;
  until False;

  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.Click(X,Y : Cardinal; Cnt : Cardinal = 1; Left : Boolean = True;
  Down : Boolean = True; Up : Boolean = True; Fast : Boolean = False; MC : Boolean = False);
var
  Point1      : Cardinal;
  Point2      : TPoint;
  Cnt2        : Cardinal;
  MsgDown     : Cardinal;
begin
  Point1:=(Y shl 16)+X;
  Point2.X:=X;
  Point2.Y:=Y;
  CLIENTTOSCREEN(UOSel.HWnd,Point2);
  if Left then MsgDown:=WM_LBUTTONDOWN
  else MsgDown:=WM_RBUTTONDOWN;

  if MC then SetCursorPos(Point2.X,Point2.Y);

  for Cnt2:=1 to Cnt do
  begin
    if not Fast then
      if not Delay(150) then Exit;
    if Down then SendMessage(UOSel.HWnd,MsgDown,0,Point1);
    if Up then SendMessage(UOSel.HWnd,MsgDown+1,0,Point1);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOCmd.GetVK(KeyStr : String) : Cardinal;
const
  HKStr : Array[0..22] of String = (
    'F10','F11','F12','ESC','BACK','TAB','ENTER','PAUSE','CAPSLOCK','SPACE',
    'PGUP','PGDN','END','HOME','LEFT','RIGHT','UP','DOWN','PRNSCR','INSERT',
    'DELETE','NUMLOCK','SCROLLLOCK');
  HKVK : Array[0..22] of Cardinal = (
    VK_F10,VK_F11,VK_F12,VK_ESCAPE,VK_BACK,VK_TAB,VK_RETURN,VK_PAUSE,
    VK_CAPITAL,VK_SPACE,VK_PRIOR,VK_NEXT,VK_END,VK_HOME,VK_LEFT,VK_RIGHT,
    VK_UP,VK_DOWN,VK_SNAPSHOT,VK_INSERT,VK_DELETE,VK_NUMLOCK,VK_SCROLL);
var
  Cnt : Integer;
begin
  Result:=0;
  KeyStr:=UpperCase(KeyStr);
  if Length(KeyStr)=1 then
    if KeyStr[1] in ['A'..'Z','0'..'9'] then
      Result:=Byte(KeyStr[1]);
  if Length(KeyStr)=2 then
    if (KeyStr[1]='F')and(KeyStr[2] in ['1'..'9']) then
      Result:=Byte(VK_F1+Byte(KeyStr[2])-49);
  if Result=0 then
    for Cnt:=0 to High(HKStr) do
      if KeyStr=HKStr[Cnt] then
        Result:=HKVK[Cnt];
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOCmd.Key(KeyStr : String; Ctrl,Alt,Shift : Boolean);
var
  VK       : Cardinal;
  RC,RA,RS : Boolean;
begin
  VK:=GetVK(KeyStr);
  if VK=0 then Exit;

  if not(Ctrl or Alt or Shift) then
  begin
    PostMessage(UOSel.HWnd,WM_KEYDOWN,VK,0);
    Exit;
  end;

  ShowWindow(UOSel.HWnd,SW_SHOW);
  SetForegroundWindow(UOSel.HWnd);
  RC:=Hi(GetAsyncKeyState(VK_CONTROL))>127;
  RA:=Hi(GetAsyncKeyState(VK_MENU))>127;
  RS:=Hi(GetAsyncKeyState(VK_SHIFT))>127;

  if Ctrl<>RC then keybd_event(VK_CONTROL,0,Byte(RC)*KEYEVENTF_KEYUP,0);
  if Alt<>RA then keybd_event(VK_MENU,0,Byte(RA)*KEYEVENTF_KEYUP,0);
  if Shift<>RS then keybd_event(VK_SHIFT,0,Byte(RS)*KEYEVENTF_KEYUP,0);
  keybd_event(VK,0,0,0);
  keybd_event(VK,0,KEYEVENTF_KEYUP,0);
  if Ctrl<>RC then keybd_event(VK_CONTROL,0,Byte(Ctrl)*KEYEVENTF_KEYUP,0);
  if Alt<>RA then keybd_event(VK_MENU,0,Byte(Alt)*KEYEVENTF_KEYUP,0);
  if Shift<>RS then keybd_event(VK_SHIFT,0,Byte(Shift)*KEYEVENTF_KEYUP,0);
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  Randomize;
end.
