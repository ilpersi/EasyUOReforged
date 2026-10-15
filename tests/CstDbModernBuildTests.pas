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
  uoevents;

type
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
    procedure Eq(const Msg : String; Expected, Actual : Int64);
    procedure OpenCave;
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
  end;

implementation

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

initialization
  RegisterTest(TCstDbModernBuildTests);
end.
