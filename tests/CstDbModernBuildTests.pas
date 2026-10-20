unit CstDbModernBuildTests;

{ Tests for TCstDB.Update's handling of the relocatable ("modern", DYNAMIC_BASE) client
  builds -- see uoclidata.pas's MODERN section.

  Same fake-client technique as CstDbEventHookTests: a suspended child process with memory
  committed at $400000, here holding just a PE header (MZ/PE signatures, TimeDateStamp,
  DllCharacteristics, one executable section) -- the only things Update reads from a client
  to tell the builds apart. The child is a 64-bit cmd.exe, which has no 32-bit PEB, so
  access.GetImageBase answers its $400000 fallback and the relocation delta is 0 here; the
  non-zero-delta path needs a real WOW64 client (tests\tools / LiveClientTests). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Windows, fpcunit, testregistry, uoclidata, access, uoselector, uovariables,
  uoevents, uocommands;

type
  // A TUOCmd that reads the fake client process instead of requiring a selected client window:
  // lets the real buff-bar reader run against memory laid out like the live beta's.
  TFakeClientCmd = class(TUOCmd)
  public
    FakeHandle : Cardinal;
  protected
    procedure RWV(RW : Cardinal; MemPos : Cardinal; Buf : PChar; Length : Cardinal); override;
    function  ClientAttached : Boolean; override;
  end;

  // Opens up TUOEvent's protected cave builders so the code they generate can be inspected.
  TCaveEvent = class(TUOEvent)
  public
    procedure CavePrepare(Base : Cardinal);
    function  CaveDrag(Item, Amount : Cardinal) : String;
    function  CaveMacro(Par1, Par2 : Cardinal) : String;
    function  CaveMsg(Obj, Font, Color, Text : Cardinal; Gate : Boolean) : String;
    function  CaveBlock(X,Y,Z,W,H : Integer) : String;
    function  CavePath(X,Y : Cardinal; Z : Integer) : String;
    function  CaveProp(ID : Cardinal; First : Boolean) : String;
  end;

  TCstDbModernBuildTests = class(TTestCase)
  private
    Proc   : TProcessInformation;
    PHnd   : Cardinal;
    Ready  : Boolean;
    Why    : String;
    Cst    : TCstDB;
    Sel    : TUOSel;
    Vr     : TUOVar;
    Ev     : TCaveEvent;
    Cmd    : TFakeClientCmd;
    procedure Eq(const Msg : String; Expected, Actual : Int64);
    procedure OpenCave;
    procedure PutStr(Addr : Cardinal; const S : String);
    procedure PutWide(Addr : Cardinal; const W : UnicodeString);
    procedure PutDouble(Addr : Cardinal; D : Double);
    procedure PutNode(Addr, Left, Right, Key, Value : Cardinal);
    procedure PutBuffEntry(Addr, ID : Cardinal; Dur, TimerID : Integer; Title, Desc : Cardinal;
      const DescArgs : UnicodeString);
    procedure OpenBuffWorld(Stamp : Cardinal; GumpName : String = 'BuffIcons Gump');
    procedure WriteHeader(Stamp : Cardinal; DllChars : Word; CodeSize : Cardinal = $2D8548);
    procedure PutBytes(Addr : Cardinal; const Bytes : array of Byte);
    procedure PutDWord(Addr, Value : Cardinal);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestImageInfoReadsHeader;
    procedure TestKnownModernBuildGetsItsOwnAddresses;
    procedure TestUnknownModernBuildNeverInheritsFixedBaseAddresses;
    procedure TestFixedBaseBuildIsUntouched;
    procedure TestUnknownModernBuildFindsItsHookByScanning;
    procedure TestHookAddressThatIsNotACallIsRefused;
    procedure TestDragCaveReturnsToItsOwnFinalRet;
    procedure TestMacroCaveReturnsToItsRestoreCode;
    procedure TestMessageCaveJumpsAndCallsLandCorrectly;
    procedure TestBlockInfoCaveFitsBeforeItsData;
    procedure TestPropertyCaveBranchesToTheRequest;
    procedure TestPathfindCaveLayout;
    // buff bar (port addition)
    procedure TestModernLayoutHasTheBuffBarConstants;
    procedure TestBuffBarIsReadFromTheClientsMemory;
    procedure TestBuffBarRefreshFollowsTheSelectedBuff;
    procedure TestBuffBarFilterKeepsOnlyThatIcon;
    procedure TestBuffBarNeedsTheBuffWindow;
    procedure TestBuffBarUnsupportedOnABuildWithoutVerifiedAddresses;
    procedure TestBuffBarRejectsAVectorThatIsNotWholeEntries;
    procedure TestUnknownModernBuildFindsTheBuffBarAddressesByScanning;
    // buff bar on the fixed-base clients
    procedure TestFixedBaseBuffBarLayoutAndScan;
    procedure TestFixedBaseBuffBarIsReadWithItsOwnContainerLayout;
    procedure TestFixedBaseBuildWithoutTheScannedAddressesHasNoBuffBar;
  end;

implementation

procedure TFakeClientCmd.RWV(RW : Cardinal; MemPos : Cardinal; Buf : PChar; Length : Cardinal);
begin
  if RW=Read then
  begin
    ZeroMemory(Buf, Length);
    ReadMem(FakeHandle, MemPos, Buf, Length);
  end
  else WriteMem(FakeHandle, MemPos, Buf, Length);
end;
function TFakeClientCmd.ClientAttached : Boolean; begin Result:=True; end;

procedure TCaveEvent.CavePrepare(Base : Cardinal);
begin
  BaseAddr:=Base;
end;
function TCaveEvent.CaveDrag(Item, Amount : Cardinal) : String;  begin Result:=DragFastCode(Item,Amount); end;
function TCaveEvent.CaveMacro(Par1, Par2 : Cardinal) : String;   begin Result:=MacroFastCode(Par1,Par2); end;
function TCaveEvent.CaveMsg(Obj, Font, Color, Text : Cardinal; Gate : Boolean) : String;
begin Result:=NewMessageObject(Obj,Font,Color,Text,Gate); end;
function TCaveEvent.CaveBlock(X,Y,Z,W,H : Integer) : String;     begin Result:=BlockInfoFastCode(X,Y,Z,W,H); end;
function TCaveEvent.CavePath(X,Y : Cardinal; Z : Integer) : String; begin Result:=PathfindFastCode(X,Y,Z); end;
function TCaveEvent.CaveProp(ID : Cardinal; First : Boolean) : String; begin Result:=PropFastCode(ID,First); end;

const
  ImageBase   = $400000;
  KnownStamp  = $6AC94360;         // the 7.0.117.1 beta in uoclidata.pas's ModernBuilds
  PEOffset    = $80;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.WriteHeader(Stamp : Cardinal; DllChars : Word; CodeSize : Cardinal);
var
  H : array[0..$1FF] of Byte;
  P : Cardinal;
begin
  FillChar(H, SizeOf(H), 0);
  PWord(@H[0])^ := $5A4D;                              // MZ
  PCardinal(@H[$3C])^ := PEOffset;
  PCardinal(@H[PEOffset])^ := $00004550;               // PE\0\0
  PWord(@H[PEOffset + 6])^ := 1;                       // NumberOfSections
  PCardinal(@H[PEOffset + 8])^ := Stamp;
  PWord(@H[PEOffset + 20])^ := $E0;                    // SizeOfOptionalHeader
  PCardinal(@H[PEOffset + 24 + 28])^ := ImageBase;
  PCardinal(@H[PEOffset + 24 + 56])^ := $1AF8000;
  PWord(@H[PEOffset + 24 + 70])^ := DllChars;
  P := PEOffset + 24 + $E0;                            // first (and only) section header
  PCardinal(@H[P + 8])^ := CodeSize;                   // VirtualSize
  PCardinal(@H[P + 12])^ := $1000;                     // VirtualAddress
  PCardinal(@H[P + 36])^ := $60000020;                 // code | execute | read
  AssertTrue('write fake PE header', WriteMem(PHnd, ImageBase, PChar(@H[0]), SizeOf(H)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.PutBytes(Addr : Cardinal; const Bytes : array of Byte);
begin
  AssertTrue('write fake client memory', WriteMem(PHnd, Addr, PChar(@Bytes[0]), Length(Bytes)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.PutDWord(Addr, Value : Cardinal);
begin
  AssertTrue('write fake client memory', WriteMem(PHnd, Addr, PChar(@Value), 4));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.SetUp;
var
  SI   : TStartupInfo;
  Path : String;
begin
  Cst := TCstDB.Create;
  Sel := nil;
  Vr := nil;
  Ev := nil;
  Cmd := nil;
  Ready := False;
  PHnd := 0;
  ZeroMemory(@Proc, SizeOf(Proc));
  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);

  Path := SysUtils.GetEnvironmentVariable('SystemRoot') + '\System32\cmd.exe';
  if not CreateProcess(PChar(Path), nil, nil, nil, False, CREATE_SUSPENDED, nil, nil, SI, Proc) then
  begin
    Why := 'Cannot start helper process (Win32 error ' + IntToStr(GetLastError) + ').';
    Exit;
  end;
  PHnd := Proc.hProcess;

  if VirtualAllocEx(PHnd, Pointer(ImageBase), $660000, MEM_RESERVE or MEM_COMMIT,
                    PAGE_READWRITE) = nil then
  begin
    Why := 'Cannot map the fake client image at $400000 (Win32 error ' +
           IntToStr(GetLastError) + ').';
    Exit;
  end;
  Ready := True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TearDown;
begin
  if Cmd<>nil then Cmd.Free;               // TUOCmd.Free hides TObject.Free too
  Ev.Free;
  if Vr<>nil then Vr.Free;                 // TUOVar.Free is not nil-safe (it hides TObject.Free)
  if Sel<>nil then Sel.Free;
  if Proc.hProcess <> 0 then
  begin
    TerminateProcess(Proc.hProcess, 0);
    CloseHandle(Proc.hThread);
    CloseHandle(Proc.hProcess);
  end;
  Cst.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestImageInfoReadsHeader;
var
  Info : TImageInfo;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp, $8140);

  AssertTrue('header recognised', ReadImageInfo(PHnd, Info));
  AssertEquals('base', Cardinal(ImageBase), Info.Base);
  AssertEquals('stamp', KnownStamp, Info.TimeDateStamp);
  AssertEquals('dll characteristics', Word($8140), Info.DllChars);
  AssertEquals('code start', Cardinal(ImageBase + $1000), Info.CodeStart);
  AssertEquals('code end', Cardinal(ImageBase + $1000 + $2D8548), Info.CodeEnd);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestKnownModernBuildGetsItsOwnAddresses;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp, $8140);
  PutBytes($57C6F9, [$E8]);                           // the `call` the table says is the hook site

  Cst.Update('7.0.117.1', PHnd);

  AssertTrue('modern', Cst.ISMODERN);
  AssertEquals('image base', Cardinal(ImageBase), Cst.IMAGEBASE);
  AssertEquals('C_CHARPTR', Cardinal($00B33F44), Cst.CHARPTR);        // not the fixed-base $00A590C4
  AssertEquals('C_JOURNALPTR', Cardinal($00C8B8BC), Cst.JOURNALPTR);
  AssertEquals('E_REDIR', Cardinal($0057C6F9), Cst.EREDIR);
  AssertEquals('E_OLDDIR', Cardinal($006A1160), Cst.EOLDDIR);
  AssertEquals('B_ITEMID', Cardinal($118), Cst.BITEMID);
  AssertEquals('B_POS', Cardinal($48), Cst.BPOS);
  AssertEquals('F_SENDTHISCALL', Cardinal(1), Cst.FSENDTHISCALL);
  AssertEquals('C_LHANDID', Cardinal($00B01820), Cst.LHANDID);
  AssertEquals('last target id lives at its own offset', Cardinal($24), Cst.BLTARGID);
  AssertEquals('last skill sits BEFORE the cluster base', Cardinal($FFFFFE4C), Cst.BLSKILL);
  AssertEquals('window top is declared before its left', Cardinal($FFFFFFFC), Cst.BCLITOP);
  AssertEquals('E_MACROTAB', Cardinal($00B01848), Cst.EMACROTAB);
  AssertEquals('shop gump: first line pointer', Cardinal($15C), Cst.BSHOPCURRENT);
  AssertEquals('shop line: link', Cardinal($7C), Cst.BSHOPNEXT);
  AssertEquals('shop line: price', Cardinal($30), Cst.BSHOPPRICE);
  AssertEquals('bill gump: first entry', Cardinal($170), Cst.BBILLFIRST);
  AssertEquals('gump list link is inherited', Cardinal($58), Cst.BCONTNEXT);
  AssertEquals('notoriety byte', Cardinal($20C), Cst.BFINDREP);
  AssertEquals('client language string', Cardinal($200), Cst.BLANG);
  AssertEquals('left hand item for macro 24', Cardinal($18), Cst.BLHAND);
  AssertEquals('right hand item for macro 24', Cardinal($1C), Cst.BRHAND);
end;

////////////////////////////////////////////////////////////////////////////////
// A different build of the same version number must not be handed this beta's code
// addresses (nor the older build's): E_* are patched into the client's machine code.
procedure TCstDbModernBuildTests.TestUnknownModernBuildNeverInheritsFixedBaseAddresses;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp + 1, $8140);

  Cst.Update('7.0.117.1', PHnd);

  AssertTrue('modern', Cst.ISMODERN);
  AssertEquals('C_CHARPTR', Cardinal(0), Cst.CHARPTR);
  AssertEquals('C_SYSMSG', Cardinal(0), Cst.SYSMSG);
  AssertEquals('E_REDIR', Cardinal(0), Cst.EREDIR);
  AssertEquals('E_SENDPACKET', Cardinal(0), Cst.ESENDPACKET);
  AssertEquals('layout still applies', Cardinal($118), Cst.BITEMID);
  AssertEquals('tithing points offset (#tp)', Cardinal($7C), Cst.BTITHE);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestFixedBaseBuildIsUntouched;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp, $0000);                       // no DYNAMIC_BASE
  PutBytes($5AFC6D, [$E8]);

  Cst.Update('7.0.117.1', PHnd);

  AssertFalse('modern', Cst.ISMODERN);
  AssertEquals('C_CHARPTR', Cardinal($00A590C4), Cst.CHARPTR);
  AssertEquals('E_REDIR', Cardinal($005AFC6D), Cst.EREDIR);
  AssertEquals('B_ITEMID', Cardinal($A8), Cst.BITEMID);
  AssertEquals('B_POS (legacy default)', Cardinal($24), Cst.BPOS);
  AssertEquals('F_SENDTHISCALL', Cardinal(0), Cst.FSENDTHISCALL);
  // The legacy distances inside the last-target cluster are untouched.
  AssertEquals('legacy last target id offset', Cardinal($18), Cst.BLTARGID);
  AssertEquals('legacy last spell offset', Cardinal($10), Cst.BLSPELL);
  AssertEquals('legacy last skill offset', Cardinal($14), Cst.BLSKILL);
  AssertEquals('legacy window top offset', Cardinal(4), Cst.BCLITOP);
  AssertEquals('legacy next-container X offset', Cardinal(4), Cst.BNEXTCX);
  AssertEquals('E_MACROTAB', Cardinal(0), Cst.EMACROTAB);
  AssertEquals('buff bar: icon vector of the fixed-base builds', Cardinal($D0), Cst.BBUFFVEC);
  AssertEquals('buff bar: icon entry size', Cardinal($1B0), Cst.BBUFFSIZE);
  AssertEquals('buff bar: tree head sits behind a proxy', Cardinal(4), Cst.BSTLHEAD);
  AssertEquals('buff bar: cliloc node key', Cardinal($0C), Cst.BCLILOCKEY);
  AssertEquals('no cliloc address until the scan finds it', Cardinal(0), Cst.CLILOC);
  AssertEquals('no buff timer address until the scan finds it', Cardinal(0), Cst.BUFFTIMERS);
end;

////////////////////////////////////////////////////////////////////////////////
// The hook's signature from ScannerTable_Modern (the `call __alldiv` in the tick function), laid
// into a fake code section with the wildcard bytes (the rel32) filled in: a build this file has
// no addresses for must still find E_REDIR/E_OLDDIR by scanning, and nothing else.
procedure TCstDbModernBuildTests.TestUnknownModernBuildFindsItsHookByScanning;
const
  CallAt  = $401212;                 // where the E8 lands: pattern start + 12
  Target  = $004F1160;               // the function the call goes to
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp + 1, $8140, $2000);          // code = $401000..$403000
  PutBytes(CallAt - 12, [$6A,$00,$68,$E8,$03,$00,$00,$FF,$75,$C8,$6A,$00,$E8]);
  PutDWord(CallAt + 1, Target - (CallAt + 5));
  PutBytes(CallAt + 5, [$8B,$F0,$B8,$59,$17,$B7,$D1,$F7,$65,$C4]);

  Cst.Update('7.0.117.1', PHnd);

  AssertEquals('E_REDIR', Cardinal(CallAt), Cst.EREDIR);
  AssertEquals('E_OLDDIR', Cardinal(Target), Cst.EOLDDIR);
  AssertEquals('nothing else is guessed', Cardinal(0), Cst.CHARPTR);
end;

////////////////////////////////////////////////////////////////////////////////
// A build whose table says E_REDIR is $57C6F9 but where that address does not hold a `call`
// (a different binary with the same stamp, a patched exe, memory that is not there): InitEvents
// would overwrite five bytes of an unrelated instruction, so the hook is dropped.
procedure TCstDbModernBuildTests.TestHookAddressThatIsNotACallIsRefused;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp, $8140, $2000);              // known stamp -> the table's E_REDIR applies
  // ... but the fake client has only zeros at $57C6F9

  Cst.Update('7.0.117.1', PHnd);

  AssertEquals('E_REDIR refused', Cardinal(0), Cst.EREDIR);
  AssertEquals('E_OLDDIR refused', Cardinal(0), Cst.EOLDDIR);
  AssertEquals('the rest of the table still applies', Cardinal($00B33F44), Cst.CHARPTR);
end;

////////////////////////////////////////////////////////////////////////////////
// The cave builders, checked structurally and without a client. Two live crashes came from a fixed
// offset left stale when a variant's code changed length; these assert that every address the code
// pushes, every relative jump/call it makes and every data slot it reads lands where it says.
const
  CaveBase = $00E10600;            // the cave sits at ImageBase+$600; Code starts at CaveBase+$20

function Bt(const S : String; I : Integer) : Byte;       // 0-based byte of a generated string
begin
  Result:=Byte(S[I+1]);
end;

function Dw(const S : String; I : Integer) : Cardinal;   // 0-based little-endian dword
begin
  Result:=Bt(S,I) or (Bt(S,I+1) shl 8) or (Bt(S,I+2) shl 16) or (Bt(S,I+3) shl 24);
end;

function Rel8(const S : String; DispAt : Integer) : Integer;   // 0-based offset a short jump lands on
begin
  Result:=DispAt+1+ShortInt(Bt(S,DispAt));
end;

function CallTarget(const S : String; At : Integer) : Cardinal;  // absolute target of `call rel32` at At
begin
  Result:=Cardinal(CaveBase+$20+At+5+Int64(LongInt(Dw(S,At+1))));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.Eq(const Msg : String; Expected, Actual : Int64);
begin
  AssertEquals(Msg, Expected, Actual);
end;

////////////////////////////////////////////////////////////////////////////////
// A TUOEvent over a UOSel whose CstDB was filled from the fake beta header, cave at CaveBase.
procedure TCstDbModernBuildTests.OpenCave;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp, $8140, $2000);
  PutBytes($57C6F9, [$E8]);
  Sel:=TUOSel.Create;
  Sel.CstDB.Update('7.0.117.1', PHnd);
  Vr:=TUOVar.Create(Sel);
  Ev:=TCaveEvent.Create(Sel, Vr, nil);
  Ev.CavePrepare(CaveBase);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestDragCaveReturnsToItsOwnFinalRet;
var
  C : String;
begin
  OpenCave;
  C:=Ev.CaveDrag($93878A64, 1000);
  Eq('mov ecx', $B9, Bt(C,0));
  Eq('item', $93878A64, Dw(C,1));
  Eq('mov edx', $BA, Bt(C,5));
  Eq('amount', 1000, Dw(C,6));
  Eq('push below', $68, Bt(C,10));
  Eq('below is the last byte', CaveBase+$20+Length(C)-1, Dw(C,11));
  Eq('...and it is a ret', $C3, Bt(C,Length(C)-1));
  Eq('push func', $68, Bt(C,15));
  Eq('func', Sel.CstDB.EDRAGADDR, Dw(C,16));
  Eq('ret into func', $C3, Bt(C,20));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestMacroCaveReturnsToItsRestoreCode;
var
  C   : String;
  Pop : Integer;
begin
  OpenCave;
  C:=Ev.CaveMacro(17, 0);
  Pop:=Length(C)-13;                                    // pop [Tab+4] ; pop [Tab] ; ret
  Eq('first pop opcode', $8F, Bt(C,Pop));
  Eq('saves the table', Sel.CstDB.EMACROTAB, Dw(C,2));
  Eq('saves the index', Sel.CstDB.EMACROTAB+4, Dw(C,8));
  Eq('push below -> first pop', CaveBase+$20+Pop, Dw(C,33));
  Eq('func', Sel.CstDB.EMACROADDR, Dw(C,38));
  Eq('the table points at the one entry at +$70', CaveBase+$70, Dw(C,18));
  AssertTrue('code stays clear of the table at +$70', Length(C)<=$70-$20);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestMessageCaveJumpsAndCallsLandCorrectly;
var
  C    : String;
  P    : Integer;
  Gate : Boolean;
begin
  OpenCave;
  for Gate:=False to True do
  begin
    C:=Ev.CaveMsg(0, 3, $44C, CaveBase+$70, Gate);
    Eq('ends in ret', $C3, Bt(C,Length(C)-1));
    AssertTrue('ExMsg text at +$70 must stay clear of the code', Length(C)<=$70-$20);

    P:=Pos(#133#192#116, C);                            // test eax,eax ; je END
    AssertTrue('je after the allocation', P>0);
    Eq('allocation failure -> final ret', Length(C)-1, Rel8(C,P+2));
    Eq('last call is the constructor', Sel.CstDB.ESYSMSGADDR, CallTarget(C,Length(C)-6));
    Eq('mov ecx, eax before it', $8B, Bt(C,Length(C)-8));
    Eq('operator new', Sel.CstDB.ENEWOBJ, CallTarget(C,P-1-3-5));    // call ; add esp,4 ; test

    if Gate then
    begin
      Eq('gate: cmp opcode', $83, Bt(C,0));
      Eq('gate: cmp modrm', $3D, Bt(C,1));
      Eq('gate dword', Sel.CstDB.EMSGGATE, Dw(C,2));
      Eq('gate: je', $74, Bt(C,7));
      Eq('gate closed -> final ret', Length(C)-1, Rel8(C,8));
    end
    else
      Eq('no gate: starts with push 1800h', $68, Bt(C,0));
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestBlockInfoCaveFitsBeforeItsData;
var
  C     : String;
  Ende  : Integer;
  Weit  : Integer;
begin
  OpenCave;
  C:=Ev.CaveBlock(2563, 490, 7, 3, 3);                  // raises if the code would overrun its data
  Eq('code is padded up to the data, which holds 5 dwords', $60+20, Length(C));
  Eq('X', 2563, Dw(C,$60));
  Eq('Y', 490, Dw(C,$64));
  Eq('W', 3, Dw(C,$68));
  Eq('mov edx, row pointer', CaveBase+$FE+2*3*3, Dw(C,1));

  Eq('loop2 reads W where the data keeps it', CaveBase+$80+8, Dw(C,15));
  Ende:=Rel8(C,12);                                     // js ende
  Eq('js ende lands on the ret', $C3, Bt(C,Ende));
  Eq('inner js goes back to loop1', 10, Rel8(C,21));
  Eq('closing jmp goes back to loop2', 19, Rel8(C,Ende-1));
  Eq('the jmp opcode', $EB, Bt(C,Ende-2));

  Weit:=Pos(#131#196#16, C)-1;                          // add esp, 10h
  Eq('the call returns to the cleanup', CaveBase+$20+Weit,
     Dw(C,Pos(#104+NumStr(Sel.CstDB.BLOCKINFO,4,True)+#195, C)-1+1-5));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestPropertyCaveBranchesToTheRequest;
var
  First, Later : String;
  P, Req       : Integer;
begin
  OpenCave;
  First:=Ev.CaveProp($40000003, True);
  Later:=Ev.CaveProp($40000003, False);

  Eq('HaveProperties', Sel.CstDB.EITEMCHECKADDR, CallTarget(First,5));
  AssertTrue('strings at +$A0 must stay clear of the code', Length(First)<=$A0-$20);

  P:=Pos(#132#192#116, First);                          // test al,al ; jz REQUEST
  AssertTrue('jz present', P>0);
  Req:=Rel8(First,P+2);
  Eq('first pass: REQUEST starts with mov ecx', $B9, Bt(First,Req));
  Eq('first pass: ...then the request call', Sel.CstDB.EITEMREQADDR, CallTarget(First,Req+5));
  Eq('first pass: ...then ret', $C3, Bt(First,Length(First)-1));
  Eq('the code before REQUEST ends in ret', $C3, Bt(First,Req-1));

  P:=Pos(#132#192#116, Later);
  Eq('later passes: REQUEST is just the ret', Length(Later)-1, Rel8(Later,P+2));
  Eq('...which is a ret', $C3, Bt(Later,Length(Later)-1));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestPathfindCaveLayout;
var
  C     : String;
  L     : Integer;
  Below : Cardinal;
begin
  OpenCave;
  L:=Sel.CstDB.BPATHPROLOGUE;
  C:=Ev.CavePath(2569, 510, 7);
  Below:=Dw(C,5);                                       // push below
  Eq('two zero arguments first', $6A, Bt(C,0));
  Eq('below is the final ret', $C3, Bt(C,Below-(CaveBase+$20)));
  Eq('...which is the last code byte, before the tile data', Length(C)-6-1, Below-(CaveBase+$20));
  Eq('mov eax opcode after the prologue', $B8, Bt(C,9+L));
  Eq('fake tile object keeps X at +BPOS', Below+1-Sel.CstDB.BPOS, Dw(C,9+L+1));
  Eq('mid entry', Sel.CstDB.EPATHFINDMID, Dw(C,9+L+6));
  Eq('X', 2569, Bt(C,Length(C)-6) or (Bt(C,Length(C)-5) shl 8));
  Eq('Y', 510, Bt(C,Length(C)-4) or (Bt(C,Length(C)-3) shl 8));
  Eq('Z', 7, Bt(C,Length(C)-2) or (Bt(C,Length(C)-1) shl 8));
end;

////////////////////////////////////////////////////////////////////////////////
/// Buff bar (port addition) ///////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// The fake client below holds, at the beta's own addresses, the structures that were read from the
// live beta: the gump list with a "BuffIcons Gump", its vector of $1B0-byte icon entries, the cliloc
// manager (a std::map<int,char*>) and the buff-timer map. TUOCmd.ScanBuffs then runs unchanged.
const
  BuffHeap = $02000000;

procedure TCstDbModernBuildTests.PutStr(Addr : Cardinal; const S : String);
begin
  AssertTrue('write fake client memory', WriteMem(PHnd, Addr, PChar(S), Length(S) + 1));
end;

procedure TCstDbModernBuildTests.PutWide(Addr : Cardinal; const W : UnicodeString);
begin
  AssertTrue('write fake client memory', WriteMem(PHnd, Addr, PChar(PWideChar(W)), (Length(W) + 1) * 2));
end;

procedure TCstDbModernBuildTests.PutDouble(Addr : Cardinal; D : Double);
begin
  AssertTrue('write fake client memory', WriteMem(PHnd, Addr, PChar(@D), 8));
end;

// An MSVC std::map node as the beta lays it out: left +0, right +8, int key +$10, value +$14.
procedure TCstDbModernBuildTests.PutNode(Addr, Left, Right, Key, Value : Cardinal);
begin
  PutDWord(Addr, Left);
  PutDWord(Addr + 8, Right);
  PutDWord(Addr + $10, Key);
  PutDWord(Addr + $14, Value);
end;

procedure TCstDbModernBuildTests.PutBuffEntry(Addr, ID : Cardinal; Dur, TimerID : Integer;
  Title, Desc : Cardinal; const DescArgs : UnicodeString);
var
  B : array[0..$1AF] of Byte;
  I : Integer;
begin
  FillChar(B, SizeOf(B), 0);
  PCardinal(@B[0])^ := ID;
  PInteger(@B[4])^ := Dur;
  PInteger(@B[8])^ := TimerID;
  PCardinal(@B[$0C])^ := Title;
  PCardinal(@B[$DC])^ := Desc;
  for I := 1 to Length(DescArgs) do
    PWord(@B[$E0 + (I - 1) * 2])^ := Word(DescArgs[I]);
  AssertTrue('write fake client memory', WriteMem(PHnd, Addr, PChar(@B[0]), SizeOf(B)));
end;

procedure TCstDbModernBuildTests.OpenBuffWorld(Stamp : Cardinal; GumpName : String);
const
  Head  = BuffHeap + $6100;          // cliloc map head
  THead = BuffHeap + $8000;          // timer map head
begin
  if not Ready then Ignore(Why);
  WriteHeader(Stamp, $8140, $2000);
  PutBytes($57C6F9, [$E8]);
  if VirtualAllocEx(PHnd, Pointer(BuffHeap), $10000, MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE) = nil then
    Ignore('Cannot map the fake buff-bar heap (Win32 error ' + IntToStr(GetLastError) + ').');
  if VirtualAllocEx(PHnd, Pointer($05EAF000), $2000, MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE) = nil then
    Ignore('Cannot map the fake buff-timer global (Win32 error ' + IntToStr(GetLastError) + ').');

  Sel := TUOSel.Create;
  Sel.CstDB.Update('7.0.117.1', PHnd);
  Vr := TUOVar.Create(Sel);
  Cmd := TFakeClientCmd.Create(Sel, Vr, nil);
  Cmd.FakeHandle := PHnd;

  // gump list: menubar -> (GumpName), the way C_CONTPOS / +8 / +$58 describe it
  PutStr(BuffHeap + $100, 'menubar');
  PutStr(BuffHeap + $120, GumpName);
  PutDWord($8E25C0, BuffHeap + $1000);
  PutDWord(BuffHeap + $1000 + 8, BuffHeap + $100);
  PutDWord(BuffHeap + $1000 + $58, BuffHeap + $2000);
  PutDWord(BuffHeap + $2000 + 8, BuffHeap + $120);
  PutDWord(BuffHeap + $2000 + $15C, BuffHeap + $4000);                 // icon vector begin
  PutDWord(BuffHeap + $2000 + $160, BuffHeap + $4000 + 3 * $1B0);      // ... end: three icons

  PutBuffEntry(BuffHeap + $4000 + 0 * $1B0, $7565, 0, -1, 1075655, 1075656, '');          // Hiding
  PutBuffEntry(BuffHeap + $4000 + 1 * $1B0, $7542, 120, 4, 1075847, 1075848, '11'#9'11'#9'11');  // Bless
  PutBuffEntry(BuffHeap + $4000 + 2 * $1B0, $7548, 120, 99, 3999999, 3999998, '');        // no text, no timer

  // cliloc: C_CLILOC -> manager -> head; a small binary tree, leaves point back at the head
  PutDWord($7ED970, BuffHeap + $6000);
  PutDWord(BuffHeap + $6000, Head);
  PutDWord(Head + 4, BuffHeap + $6200);                                  // root
  PutNode(BuffHeap + $6200, BuffHeap + $6300, BuffHeap + $6400, 1075847, BuffHeap + $7100);
  PutNode(BuffHeap + $6300, BuffHeap + $6500, Head, 1075656, BuffHeap + $7080);
  PutNode(BuffHeap + $6500, Head, Head, 1075655, BuffHeap + $7000);
  PutNode(BuffHeap + $6400, Head, Head, 1075848, BuffHeap + $7110);
  PutStr(BuffHeap + $7000, 'Hidden/Stealthing');
  PutStr(BuffHeap + $7080, 'You are hidden.');
  PutStr(BuffHeap + $7100, 'Bless');
  PutStr(BuffHeap + $7110, '+~1_STR~% Strength.<br>+~2_DEX~% Dexterity.<br>+~3_INT~% Intelligence.');

  // buff timers: C_BUFFTIMERS holds the head; key = timer id, the double at +$28 = seconds left
  PutDWord($5EAF71C, THead);
  PutDWord(THead + 4, BuffHeap + $8100);
  PutNode(BuffHeap + $8100, THead, BuffHeap + $8200, 4, 0);
  PutDouble(BuffHeap + $8100 + $28, 104.75);
  PutNode(BuffHeap + $8200, THead, THead, 5, 0);
  PutDouble(BuffHeap + $8200 + $28, 55.5);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestModernLayoutHasTheBuffBarConstants;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp, $8140);
  PutBytes($57C6F9, [$E8]);
  Cst.Update('7.0.117.1', PHnd);

  Eq('icon vector begin pointer', $15C, Cst.BBUFFVEC);
  Eq('icon entry size', $1B0, Cst.BBUFFSIZE);
  Eq('containers keep their head in their first dword', 0, Cst.BSTLHEAD);
  Eq('cliloc key offset', $10, Cst.BCLILOCKEY);
  Eq('C_CLILOC', $007ED970, Cst.CLILOC);
  Eq('C_BUFFTIMERS', $05EAF71C, Cst.BUFFTIMERS);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestBuffBarIsReadFromTheClientsMemory;
begin
  OpenBuffWorld(KnownStamp);

  AssertTrue('the buff bar window is open', Cmd.BuffBarOpen);
  AssertTrue('the bar is readable', Cmd.ScanBuffs);
  Eq('buffs', 3, Cmd.BuffCnt);
  AssertTrue('first one selected', Cmd.BuffValid);
  Eq('Hiding: icon', $7565, Cmd.BuffRes.ID);
  Eq('Hiding: title cliloc', 1075655, Cmd.BuffRes.Cliloc);
  AssertEquals('Hiding: title', 'Hidden/Stealthing', Cmd.BuffRes.Name);
  AssertEquals('Hiding: description', 'You are hidden.', Cmd.BuffRes.Desc);
  Eq('Hiding: no timer', -1, Cmd.BuffRes.Time);

  Cmd.GetBuff(1);
  AssertTrue(Cmd.BuffValid);
  Eq('Bless: icon', $7542, Cmd.BuffRes.ID);
  AssertEquals('Bless: title', 'Bless', Cmd.BuffRes.Name);
  AssertEquals('Bless: description, arguments filled and <br> turned into spaces',
    '+11% Strength. +11% Dexterity. +11% Intelligence.', Cmd.BuffRes.Desc);
  Eq('Bless: whole seconds left (104.75 truncated like the tooltip)', 104, Cmd.BuffRes.Time);
  PutDouble(BuffHeap + $8100 + $28, 99.5);               // the client's countdown moves on
  Eq('...and #BuffTime reads it live, without a new ScanBuffs', 99, Cmd.BuffTimeNow);
  Cmd.GetBuff(0);
  Eq('a buff without a timer stays -1', -1, Cmd.BuffTimeNow);
  Cmd.GetBuff(1);

  Cmd.GetBuff(2);
  AssertTrue(Cmd.BuffValid);
  Eq('third: icon', $7548, Cmd.BuffRes.ID);
  AssertEquals('third: unknown cliloc reads as no text', '', Cmd.BuffRes.Name);
  Eq('third: a timer id the client does not know shows 0, as the tooltip does', 0, Cmd.BuffRes.Time);

  Cmd.GetBuff(3);
  AssertFalse('there is no fourth', Cmd.BuffValid);
end;

////////////////////////////////////////////////////////////////////////////////
// What a polled variable tree sees while buffs run out: the selected buff is followed to its new
// position when others leave, and reads as gone (N/A) once it leaves itself.
procedure TCstDbModernBuildTests.TestBuffBarRefreshFollowsTheSelectedBuff;
begin
  OpenBuffWorld(KnownStamp);
  AssertTrue(Cmd.ScanBuffs);
  Cmd.BuffSelect(2);                                     // Bless, second of three
  Cmd.BuffRefresh;
  Eq('nothing changed: still Bless at 2', 2, Cmd.BuffPos);
  AssertTrue(Cmd.BuffValid);

  // Hiding ends: the client drops the first entry, the others move up
  PutBuffEntry(BuffHeap + $4000, $7542, 120, 4, 1075847, 1075848, '11'#9'11'#9'11');
  PutBuffEntry(BuffHeap + $4000 + $1B0, $7548, 120, 99, 3999999, 3999998, '');
  PutDWord(BuffHeap + $2000 + $160, BuffHeap + $4000 + 2 * $1B0);
  Cmd.BuffRefresh;
  Eq('count follows the client', 2, Cmd.BuffCnt);
  Eq('Bless is now first', 1, Cmd.BuffPos);
  AssertTrue(Cmd.BuffValid);
  AssertFalse(Cmd.BuffGone);
  Eq('...with its icon', $7542, Cmd.BuffRes.ID);
  AssertEquals('...and text', 'Bless', Cmd.BuffRes.Name);

  // Bless runs out
  PutBuffEntry(BuffHeap + $4000, $7548, 120, 99, 3999999, 3999998, '');
  PutDWord(BuffHeap + $2000 + $160, BuffHeap + $4000 + $1B0);
  Cmd.BuffRefresh;
  Eq('count', 1, Cmd.BuffCnt);
  AssertFalse('the selected buff is gone', Cmd.BuffValid);
  AssertTrue(Cmd.BuffGone);
  Cmd.BuffRefresh;
  AssertTrue('and stays gone', Cmd.BuffGone);

  // selecting again clears it; a new ScanBuffs too
  Cmd.BuffSelect(1);
  AssertFalse(Cmd.BuffGone);
  AssertTrue(Cmd.BuffValid);
  Cmd.BuffRefresh;

  // the bar closes: nothing is left
  PutDWord(BuffHeap + $2000 + 8, BuffHeap + $100);       // the gump no longer answers to its name
  Cmd.BuffRefresh;
  Eq('count', 0, Cmd.BuffCnt);
  AssertFalse(Cmd.BuffValid);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestBuffBarFilterKeepsOnlyThatIcon;
begin
  OpenBuffWorld(KnownStamp);

  AssertTrue(Cmd.ScanBuffs($7542));       // the icon id is a plain number: $7542 = 30018
  Eq('only Bless', 1, Cmd.BuffCnt);
  Eq('...selected', $7542, Cmd.BuffRes.ID);
  Eq('...with its own timer', 104, Cmd.BuffRes.Time);

  AssertTrue('an icon that is not there is not an error', Cmd.ScanBuffs(1));
  Eq('none', 0, Cmd.BuffCnt);
  AssertFalse(Cmd.BuffValid);

  AssertTrue(Cmd.ScanBuffs(-1));
  Eq('no filter again', 3, Cmd.BuffCnt);
end;

////////////////////////////////////////////////////////////////////////////////
// The buff window not being open is not the same as an empty bar: nothing can be read.
procedure TCstDbModernBuildTests.TestBuffBarNeedsTheBuffWindow;
begin
  OpenBuffWorld(KnownStamp, 'paperdoll gump');

  AssertTrue('the layout is known...', Cmd.BuffAvailable);
  AssertFalse('...and the window is not open', Cmd.BuffBarOpen);
  AssertFalse(Cmd.ScanBuffs);
  Eq('count', 0, Cmd.BuffCnt);
  AssertFalse(Cmd.BuffValid);
end;

////////////////////////////////////////////////////////////////////////////////
// Another build of the same version has none of this beta's addresses: until the scanner finds
// the cliloc and timer globals the bar is unsupported rather than read from stale addresses.
procedure TCstDbModernBuildTests.TestBuffBarUnsupportedOnABuildWithoutVerifiedAddresses;
begin
  OpenBuffWorld(KnownStamp + 1);

  Eq('C_CLILOC', 0, Sel.CstDB.CLILOC);
  Eq('C_BUFFTIMERS', 0, Sel.CstDB.BUFFTIMERS);
  AssertFalse('unsupported', Cmd.BuffAvailable);
  AssertFalse('so it cannot be called open', Cmd.BuffBarOpen);
  AssertFalse(Cmd.ScanBuffs);
  Eq('count', 0, Cmd.BuffCnt);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TCstDbModernBuildTests.TestBuffBarRejectsAVectorThatIsNotWholeEntries;
begin
  OpenBuffWorld(KnownStamp);
  PutDWord(BuffHeap + $2000 + $160, BuffHeap + $4000 + 3 * $1B0 + 1);   // end not on an entry boundary

  AssertFalse(Cmd.ScanBuffs);
  Eq('count', 0, Cmd.BuffCnt);

  PutDWord(BuffHeap + $2000 + $160, BuffHeap + $4000 - 4);              // end before begin
  AssertFalse(Cmd.ScanBuffs);

  PutDWord(BuffHeap + $2000 + $160, BuffHeap + $4000 + 1000 * $1B0);    // absurd count
  AssertFalse(Cmd.ScanBuffs);
end;

////////////////////////////////////////////////////////////////////////////////
// The two signatures added to ScannerTable_Modern, laid into a fake code section with the wildcard
// bytes filled in: a build this file has no addresses for finds C_CLILOC / C_BUFFTIMERS by scanning.
procedure TCstDbModernBuildTests.TestUnknownModernBuildFindsTheBuffBarAddressesByScanning;
const
  ClilocAt = $401100;
  TimerAt  = $401200;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp + 1, $8140, $2000);          // code = $401000..$403000
  // push esi; push 0; mov esi,ecx; mov ecx,[manager global]; push edx; push esi; call find; mov eax,esi; pop esi; ret
  PutBytes(ClilocAt, [$56,$6A,$00,$8B,$F1,$8B,$0D]);
  PutDWord(ClilocAt + 7, $00E5D970);
  PutBytes(ClilocAt + 11, [$52,$56,$E8]);
  PutDWord(ClilocAt + 14, $00001234);
  PutBytes(ClilocAt + 18, [$8B,$C6,$5E,$C3]);
  // mov eax,[timer map head]; mov byte [ebp-4],2Eh; mov ecx,[ebp-60h]; cmp ecx,eax; je +0Bh
  PutBytes(TimerAt, [$A1]);
  PutDWord(TimerAt + 1, $0A5BF71C);
  PutBytes(TimerAt + 5, [$C6,$45,$FC,$2E,$8B,$4D,$A0,$3B,$C8,$74,$0B]);

  Cst.Update('7.0.117.1', PHnd);

  Eq('C_CLILOC', $00E5D970, Cst.CLILOC);
  Eq('C_BUFFTIMERS', $0A5BF71C, Cst.BUFFTIMERS);
  Eq('layout still applies', $15C, Cst.BBUFFVEC);
  Eq('nothing else is guessed', 0, Cst.CHARPTR);
end;

////////////////////////////////////////////////////////////////////////////////
/// Buff bar on the fixed-base clients /////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
// The two signatures added to ScannerTable_Post6062, with the bytes of the real client.exe
// (7.0.117.1) around them: the scanner resolves the same addresses the live client showed.
procedure TCstDbModernBuildTests.TestFixedBaseBuffBarLayoutAndScan;
const
  TimerAt  = $401200;
  ClilocAt = $401300;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp, $0000);                       // no DYNAMIC_BASE: a fixed-base build
  // mov edx,[eax+8]; push edx; mov ecx,TIMERMAP; call lookup; call ftol; push edi; mov ecx,esi; mov ebp,eax
  PutBytes(TimerAt, [$8B,$50,$08,$52,$B9]);
  PutDWord(TimerAt + 5, $01ECB63C);
  PutBytes(TimerAt + 9, [$E8]);
  PutDWord(TimerAt + 10, $00170BA5);
  PutBytes(TimerAt + 14, [$E8]);
  PutDWord(TimerAt + 15, $00199840);
  PutBytes(TimerAt + 19, [$57,$8B,$CE,$8B,$E8]);
  // the cliloc wrapper: setne al; push esi; mov esi,[esp+0Ch]; mov dword [esp+4],0; push eax; push ecx; mov ecx,[manager]; ...
  PutBytes(ClilocAt, [$0F,$94,$C0,$56,$8B,$74,$24,$0C,$C7,$44,$24,$04,$00,$00,$00,$00,$50,$51,$8B,$0D]);
  PutDWord(ClilocAt + 20, $00A01B9C);
  PutBytes(ClilocAt + 24, [$56,$E8]);
  PutDWord(ClilocAt + 26, $FFFFFD88);
  PutBytes(ClilocAt + 30, [$8B,$C6,$5E,$59,$C3]);

  Cst.Update('7.0.117.1', PHnd);

  AssertFalse('modern', Cst.ISMODERN);
  Eq('C_BUFFTIMERS', $01ECB63C, Cst.BUFFTIMERS);
  Eq('C_CLILOC', $00A01B9C, Cst.CLILOC);
  Eq('icon vector', $D0, Cst.BBUFFVEC);
  Eq('the rest of the fixed-base table is unchanged', $00A590C4, Cst.CHARPTR);
end;

////////////////////////////////////////////////////////////////////////////////
// Memory laid out the way client.exe has it (read live): the icon vector at gump+$D0, the tree heads
// one dword into the map objects, cliloc nodes with the key at +$0C and the text pointer at +$10.
procedure TCstDbModernBuildTests.TestFixedBaseBuffBarIsReadWithItsOwnContainerLayout;
const
  Heap    = BuffHeap;
  Head    = BuffHeap + $6100;
  THead   = BuffHeap + $8000;
  Manager = $00A01B9C;               // C_CLILOC: global -> manager object
  Timers  = $00A02000;               // C_BUFFTIMERS: the map object itself
var
  Next : Cardinal;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp, $0000, $2000);                 // fixed-base, code = $401000..$403000
  if VirtualAllocEx(PHnd, Pointer(BuffHeap), $10000, MEM_RESERVE or MEM_COMMIT, PAGE_READWRITE) = nil then
    Ignore('Cannot map the fake buff-bar heap (Win32 error ' + IntToStr(GetLastError) + ').');
  // the two scanned globals, as a scan would have found them
  PutBytes($401100, [$8B,$50,$08,$52,$B9]);
  PutDWord($401105, Timers);
  PutBytes($401109, [$E8,$00,$00,$00,$00,$E8,$00,$00,$00,$00,$57,$8B,$CE,$8B,$E8]);
  PutBytes($401200, [$0F,$94,$C0,$56,$8B,$74,$24,$0C,$C7,$44,$24,$04,$00,$00,$00,$00,$50,$51,$8B,$0D]);
  PutDWord($401214, Manager);
  PutBytes($401218, [$56,$E8,$00,$00,$00,$00,$8B,$C6,$5E,$59,$C3]);

  Sel := TUOSel.Create;
  Sel.CstDB.Update('7.0.117.1', PHnd);
  Vr := TUOVar.Create(Sel);
  Cmd := TFakeClientCmd.Create(Sel, Vr, nil);
  Cmd.FakeHandle := PHnd;
  Eq('C_CLILOC found by the scan', Manager, Sel.CstDB.CLILOC);
  Eq('C_BUFFTIMERS found by the scan', Timers, Sel.CstDB.BUFFTIMERS);
  Next := Sel.CstDB.BCONTNEXT;

  PutStr(Heap + $100, 'menubar');
  PutStr(Heap + $120, 'BuffIcons Gump');
  PutDWord(Sel.CstDB.CONTPOS, Heap + $1000);
  PutDWord(Heap + $1000 + 8, Heap + $100);
  PutDWord(Heap + $1000 + Next, Heap + $2000);
  PutDWord(Heap + $2000 + 8, Heap + $120);
  PutDWord(Heap + $2000 + $D0, Heap + $4000);
  PutDWord(Heap + $2000 + $D4, Heap + $4000 + 2 * $1B0);
  PutBuffEntry(Heap + $4000, $7565, 0, -1, 1075655, 1075656, '');
  PutBuffEntry(Heap + $4000 + $1B0, $7542, 120, 1, 1075847, 1075848, '11'#9'11'#9'11');

  // cliloc: manager -> object whose second dword is the head; node key +$0C, text pointer +$10
  PutDWord(Manager, Heap + $6000);
  PutDWord(Heap + $6000 + 4, Head);
  PutDWord(Head + 4, Heap + $6200);
  PutDWord(Heap + $6200, Heap + $6300);   PutDWord(Heap + $6200 + 8, Heap + $6400);
  PutDWord(Heap + $6200 + $0C, 1075847);  PutDWord(Heap + $6200 + $10, Heap + $7100);
  PutDWord(Heap + $6300, Heap + $6500);   PutDWord(Heap + $6300 + 8, Head);
  PutDWord(Heap + $6300 + $0C, 1075656);  PutDWord(Heap + $6300 + $10, Heap + $7080);
  PutDWord(Heap + $6500, Head);           PutDWord(Heap + $6500 + 8, Head);
  PutDWord(Heap + $6500 + $0C, 1075655);  PutDWord(Heap + $6500 + $10, Heap + $7000);
  PutDWord(Heap + $6400, Head);           PutDWord(Heap + $6400 + 8, Head);
  PutDWord(Heap + $6400 + $0C, 1075848);  PutDWord(Heap + $6400 + $10, Heap + $7110);
  PutStr(Heap + $7000, 'Hidden/Stealthing');
  PutStr(Heap + $7080, 'You are hidden.');
  PutStr(Heap + $7100, 'Bless');
  PutStr(Heap + $7110, '+~1_STR~% Strength.<br>+~2_DEX~% Dexterity.<br>+~3_INT~% Intelligence.');

  // buff timers: the map object -> (proxy dword) head; node key +$10, double +$28
  PutDWord(Timers + 4, THead);
  PutDWord(THead + 4, Heap + $8100);
  PutDWord(Heap + $8100, THead);  PutDWord(Heap + $8100 + 8, THead);
  PutDWord(Heap + $8100 + $10, 1);
  PutDouble(Heap + $8100 + $28, 70.0);

  AssertTrue('the bar is readable', Cmd.ScanBuffs);
  Eq('buffs', 2, Cmd.BuffCnt);
  AssertEquals('Hiding', 'Hidden/Stealthing', Cmd.BuffRes.Name);
  Eq('Hiding: no timer', -1, Cmd.BuffRes.Time);
  Cmd.GetBuff(1);
  Eq('Bless: icon', $7542, Cmd.BuffRes.ID);
  AssertEquals('Bless', 'Bless', Cmd.BuffRes.Name);
  AssertEquals('Bless: description', '+11% Strength. +11% Dexterity. +11% Intelligence.', Cmd.BuffRes.Desc);
  Eq('Bless: seconds left', 70, Cmd.BuffRes.Time);
end;

////////////////////////////////////////////////////////////////////////////////
// A fixed-base build whose code the scanner does not recognise gets the layout constants but no
// addresses: unsupported, so a buff bar that is open still reads as not available.
procedure TCstDbModernBuildTests.TestFixedBaseBuildWithoutTheScannedAddressesHasNoBuffBar;
begin
  if not Ready then Ignore(Why);
  WriteHeader(KnownStamp, $0000, $2000);
  Sel := TUOSel.Create;
  Sel.CstDB.Update('7.0.117.1', PHnd);
  Vr := TUOVar.Create(Sel);
  Cmd := TFakeClientCmd.Create(Sel, Vr, nil);
  Cmd.FakeHandle := PHnd;

  Eq('layout', $D0, Sel.CstDB.BBUFFVEC);
  Eq('C_CLILOC', 0, Sel.CstDB.CLILOC);
  AssertFalse(Cmd.ScanBuffs);
  Eq('count', 0, Cmd.BuffCnt);
end;

initialization
  RegisterTest(TCstDbModernBuildTests);
end.
