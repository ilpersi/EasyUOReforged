unit uoevents;

{
  Ported from the original Delphi 7 uo\uoevents.pas (read in full, 773 lines).
  TUOEvent implements "code caving": it builds raw x86-32 opcode sequences as
  plain byte/string literals (via access.pas's NumStr, already ported and
  tested in Phase 1) and writes them into an unused executable page of the
  target process (VirtualProtectEx + WriteMem) to synthesize client-internal
  events the UO protocol doesn't otherwise expose, plus a handful of raw
  "ExEvent" network packets sent directly (SendExEvent).

  This is DATA, not a Delphi asm block (see CLAUDE.md and the migration plan) --
  every byte sequence here describes x86-32 instructions that will execute
  inside the always-32-bit remote client, so none of it needs to change for a
  64-bit host. Confirmed, not assumed: this phase's VirtualProtectEx/WriteMem
  calls against the fixed $400000 remote address are the exact same pattern
  already proven to compile and behave correctly in Phase 3's
  uovariables.pas.WriteTargCurs.

  Two required changes, both mechanical, matching prior phases' precedents:
  - The local TDelayFunc duplicate declaration is removed in favor of the one
    shared common\uotypes.pas declaration (same fix already applied to
    EuoStdCommands.pas and uocommands.pas).
  - The original's include directive pulling in wearables.inc is replaced with
    a plain "uses wearables" -- Phase 1 already promoted that original include
    file into a proper unit (uo\wearables.pas), per the migration plan's
    target layout; GetWearableLayer's signature is unchanged.

  Everything else -- every opcode byte sequence, every SendExEvent packet
  layout, FindID's linked-list walk, WaitTillProcessed's polling loop -- is
  ported byte-for-byte. This is the highest-blast-radius unit in the whole
  codebase (a wrong byte here writes bad machine code into a live game
  client's memory), so no unforced changes of any kind belong here; the two
  above are the only edits, and both are pure "identical replacement,"
  changing nothing at the byte-sequence level.

  Later port additions are marked where they are: the caves of the relocated
  "modern" builds (the *FastCode functions), StepInfo, and the LastDragID property
  (MOVEITEM: it reads and clears DragID; no byte sequence involved). One original byte
  sequence did change: BlockInfo's loop for the fixed-base clients, which
  passed the client's tile query one argument fewer than client.exe 7.0.117.1
  takes (see BlockInfoCode).

  Port addition (exevent GumpReply, uogumpreply.pas): ExEv_GumpReply sends a server gump's $B1 answer
  through E_SENDPACKET exactly as SendExEvent does, and in the same cave run deletes the client's window
  the way the client's own click path does after sending: [vtable+0], the deleting destructor, with 1,
  called on the gump the way ContTop calls E_CONTTOP. No new address: the destructor is read from the
  gump's vtable. The cave first checks that the object still carries $FEEDBEEF and the same vtable, and
  skips the delete otherwise. SendExEvent itself is unchanged; GumpReplyCode builds the bytes, so the
  test suite pins them.

  Port addition (the gump-answer hook, #GumpReply / #GumpReplyCnt): the client keeps no copy of a packet
  it sent, so recording the answer a click sends needs a hook. GumpHookActive puts one on E_SENDPACKET,
  the function every send goes through (the clicks and every exevent): a jmp over its first instructions
  into a page of its own (VirtualAllocEx, no fixed address). There the hook copies each packet that
  starts with $B1 into the page and counts it, then runs the instructions it replaced and jumps back.
  - It replaces only instructions it can move: HookPrologueLength accepts a short list of plain ones
    (push, mov between registers, mov from an absolute or a stack address, sub esp) and refuses anything
    relative (calls, jumps). On any other start the hook stays off and clicks are not recorded.
  - The jmp is written by the event cave, on the client's main thread, the thread that sends, so no
    thread is inside those first bytes while they change.
  - The page starts with a header (HOOK_MAGIC, the function, the bytes replaced). A second attach, or
    another Reforged after a restart, sees the jmp at E_SENDPACKET, finds that header behind it and uses
    the same page instead of hooking again. A jmp there that leads elsewhere is not ours: left alone.
  - Nothing removes it: it stays harmless until the client exits, as the event hook does.
}

{$mode delphi}{$H+}

interface
uses Windows, SysUtils, access, uotypes, uocommands, uovariables, uoselector,
     uoclidata, wearables, walkrules;

type
  TUOEvent      = class(TObject)
  private
    InitEventWnd : Cardinal;
    HookWnd      : Cardinal;         // port addition: the window HookPage belongs to
    HookPage     : Cardinal;         // port addition: the gump-answer hook's page in that client
    DragID       : Cardinal;
    DragType     : Cardinal;
    Delay        : TDelayFunc;
    procedure    InitEvents;
    function     ReplaceStr(Str,RepWhat,RepWith : String) : String;
    function     GetFormStr(StrAddr : Cardinal) : String;
    function     FindID(ID : Cardinal) : Cardinal;
    procedure    SendExEvent(Packet : String);
    procedure    WaitTillProcessed;
  protected
    // Everything the relocated-build caves are assembled from is protected rather than private so
    // tests/CstDbModernBuildTests can check the generated code's internal offsets without a client:
    // two live crashes came from a fixed offset left stale after a variant's length changed.
    UOSel        : TUOSel;
    UOVar        : TUOVar;
    Cst          : TCstDB;
    BaseAddr     : Cardinal;
    function     CallRel(Target, At : Cardinal) : String;
    function     BlockInfoFastCode(X,Y,Z,W,H : Integer) : String;
    function     BlockInfoCode(X,Y,Z,W,H : Integer) : String;
    function     StepInfoCode(N : Integer; Fast : Boolean) : String;
    function     PathfindFastCode(X,Y : Cardinal; Z : Integer) : String;
    function     PropFastCode(ID : Cardinal; FirstPass : Boolean) : String;
    function     NewMessageObject(Obj : Cardinal; Font, Color, TextAddr : Cardinal; Gate : Boolean) : String;
    function     DragFastCode(Item, Amount : Cardinal) : String;
    function     MacroFastCode(Par1, Par2 : Cardinal) : String;
    function     GumpReplyCode(Gump, VTable, Dtor : Cardinal; const Packet : String) : String;
    function     SendHookCode(Page, Func : Cardinal; const Orig : String) : String;
    function     SendHookInstallCode(Func, Page : Cardinal; N : Integer) : String;
  public
    PropStr1     : String;
    PropStr2     : String;
    BlockStr     : String;
    constructor  Create(UOS : TUOSel; UOV : TUOVar; DFunc : TDelayFunc);
    destructor   Destroy; override;
    procedure    ExMsg(ID,Font,Color : Cardinal; Msg : String);
    procedure    EvProperty(ID : Cardinal);
    procedure    Pathfind(X,Y : Cardinal; Z : Integer);
    procedure    Drag(ID : Cardinal);
    procedure    SysMessage(Msg : String; Col : Cardinal);
    procedure    Macro(Par1, Par2 : Cardinal; Str : String = '');
    procedure    ContTop(Index : Integer);
    procedure    StatBar(ID : Cardinal);
    procedure    BlockInfo(X,Y,Z,W,H : Integer);
    function     StepInfo(var Q : TStepChecks) : Boolean;
    /////////
    procedure    ExEv_Drag(ID : Cardinal; Amount : Cardinal = 1);
    procedure    ExEv_DropC(ContID : Cardinal; X : Integer = -1; Y : Integer = -1);
    procedure    ExEv_DropG(X,Y : Cardinal; Z : Integer = -1000);
    procedure    ExEv_DropPD;
    procedure    ExEv_SkillLock(SkillStr : String; Lock : Cardinal);
    procedure    ExEv_StatLock(Stat : String; Lock : Cardinal);
    procedure    ExEv_RenamePet(ID : Cardinal; Name : String);
    procedure    ExEv_PopUp(ID : Cardinal; X,Y : Integer);
    procedure    ExEv_Custom(Packet : String);
    // Port addition (exevent GumpReply): sends Packet and, when Close, deletes the gump's window in the
    // same cave run. False when nothing was sent (no send address, no event hook, not connected).
    function     ExEv_GumpReply(Gump, VTable : Cardinal; const Packet : String; Close : Boolean) : Boolean;
    // Port addition (the gump-answer hook): True when E_SENDPACKET carries Reforged's hook, found or (with
    // Install) put there now; GumpHookRead reads the answers it counted and the last one it kept.
    function     GumpHookActive(Install : Boolean) : Boolean;
    function     GumpHookRead(out Count : Cardinal; out Packet : String) : Boolean;
    // Port addition (MOVEITEM): the item the next ExEv_Drop* names, which ExEv_Drag and Drag set only
    // once they have found the item in the client's list. A caller clears it (0) before ExEv_Drag to
    // learn whether the drag was sent for its item.
    property     LastDragID : Cardinal read DragID write DragID;
  end;

// Port additions (the gump-answer hook), client-free so the test suite pins them.
const
  HOOK_MAGIC = 'EUORGRH1';         // the page's first 8 bytes
  HOOK_COUNT = $20;                // dword: answers counted
  HOOK_LEN   = $24;                // dword: bytes kept of the last one
  HOOK_BUF   = $28;                // the last one
  HOOK_MAX   = $800;               // bytes kept at most
  HOOK_CODE  = $900;               // the hook's code
  HOOK_PAGE  = $1000;

// How many bytes from the start of B (a function's first bytes) the hook can move: whole instructions
// of the accepted kinds, 5 at least; 0 when the start holds anything else.
function HookPrologueLength(const B : String) : Integer;
// The hook page a jmp at the start of Func leads to (First5 = its first five bytes), 0 when it is no jmp.
function HookPageOf(Func : Cardinal; const First5 : String) : Cardinal;
// The page header: magic, the function, how many bytes were replaced and those bytes.
function HookHeader(Func : Cardinal; const Orig : String) : String;
// Does Header (the first $20 bytes of a page) say it is Reforged's hook of Func?
function HookHeaderIsOurs(const Header : String; Func : Cardinal) : Boolean;

implementation

////////////////////////////////////////////////////////////////////////////////
function HookPrologueLength(const B : String) : Integer;
var
  I, L  : Integer;
  Op, M : Byte;
begin
  Result:=0;
  I:=1;
  while I<=Length(B) do
  begin
    if I-1>=5 then Break;
    Op:=Ord(B[I]);
    L:=0;
    if I<Length(B) then M:=Ord(B[I+1]) else M:=0;
    case Op of
      $50..$57 : L:=1;                                   // push reg
      $6A      : L:=2;                                   // push imm8
      $68      : L:=5;                                   // push imm32
      $A1      : L:=5;                                   // mov eax, [abs]
      $83      : if M=$EC then L:=3;                     // sub esp, imm8
      $81      : if M=$EC then L:=6;                     // sub esp, imm32
      $64      : if M=$A1 then L:=6;                     // mov eax, fs:[abs]
      $89, $8B :                                         // mov r/m32, r32 and mov r32, r/m32:
        case M shr 6 of
          3 : L:=2;                                      // register to register
          0 : if (M and 7)=5 then L:=6;                  // [abs]
          1 : if (M and 7)=4 then
              begin
                if (I+2<=Length(B)) and (Ord(B[I+2])=$24) then L:=4;   // [esp+disp8]
              end
              else L:=3;                                 // [reg+disp8]
        end;
    end;
    if L=0 then Exit(0);
    Inc(I,L);
  end;
  if (I-1>=5) and (I-1<=Length(B)) then Result:=I-1;
end;

////////////////////////////////////////////////////////////////////////////////
function HookPageOf(Func : Cardinal; const First5 : String) : Cardinal;
var
  Rel : Cardinal;
begin
  Result:=0;
  if (Length(First5)<5) or (First5[1]<>#$E9) then Exit;
  Rel:=PCardinal(@First5[2])^;
  Result:=Func+5+Rel-HOOK_CODE;
end;

////////////////////////////////////////////////////////////////////////////////
function HookHeader(Func : Cardinal; const Orig : String) : String;
var
  O : String;
begin
  O:=Orig;
  SetLength(O,16);
  if Length(Orig)<16 then FillChar(O[Length(Orig)+1],16-Length(Orig),0);
  Result:=HOOK_MAGIC+NumStr(Func,4,True)+NumStr(Length(Orig),4,True)+O;
end;

////////////////////////////////////////////////////////////////////////////////
function HookHeaderIsOurs(const Header : String; Func : Cardinal) : Boolean;
begin
  Result:=(Length(Header)>=$20) and (Copy(Header,1,8)=HOOK_MAGIC) and (PCardinal(@Header[9])^=Func) and
          (PCardinal(@Header[13])^>=5) and (PCardinal(@Header[13])^<=16);
end;

////////////////////////////////////////////////////////////////////////////////
constructor TUOEvent.Create(UOS : TUOSel; UOV : TUOVar; DFunc : TDelayFunc);
begin
  inherited Create;
  UOSel:=UOS;
  Cst:=UOSel.CstDB;
  UOVar:=UOV;
  Delay:=DFunc;

  BaseAddr:=0;
  InitEventWnd:=0;
  HookWnd:=0;
  HookPage:=0;
  DragID:=0;
end;

////////////////////////////////////////////////////////////////////////////////
destructor TUOEvent.Destroy;
begin
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.WaitTillProcessed;
var
  Cnt  : Integer;
  Flag : Word;
begin
  for Cnt:=1 to 20 do
  begin
    ReadMem(UOSel.HProc,BaseAddr-2,@Flag,2);               // Read flags
    if Flag=0 then Break;                                  // check flags
    if not Delay(25) then Exit;                            // Wait
  end;
end;

////////////////////////////////////////////////////////////////////////////////
/// Events /////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TUOEvent.InitEvents;
var
  sBuf  : String;
  Dummy : Cardinal;
begin
  if InitEventWnd=UOSel.HWnd then Exit;
  InitEventWnd:=UOSel.HWnd;

  //BaseAddr:=Cst.BMEMBASE;
  // Port change: relative to where the exe is actually loaded ($400000 for every fixed-base
  // client, so unchanged for them; relocated "modern" builds sit elsewhere). Also never
  // patch the client when there is no hook address -- a build whose addresses are unknown
  // must not get a code cave and a call rerouted to address 0.
  if Cst.EREDIR=0 then Exit;
  BaseAddr:=Cst.IMAGEBASE+$600;
  VirtualProtectEx(
    UOSel.HProc,
    Pointer(Cst.IMAGEBASE),
    $1000,
    PAGE_EXECUTE_READWRITE,
    @Dummy
   );

  sBuf:=
    #0#0#0#0+                                              // Flags
    #104+NumStr(Cst.EOLDDIR,4,True)+                       // push OldDirection
    #102#161+NumStr(BaseAddr-2,4,True)+                    // mov ax, word ptr [007FFFFE]
    #102#131#248#0+                                        // cmp ax, 0000
    #117#1+                                                // jne -> jump below ret
    #195+                                                  // ret
    #102#49#192+                                           // xor ax, ax
    #102#163+NumStr(BaseAddr-2,4,True)+                    // mov word ptr [007FFFFE], ax
    #144+                                                  // nop
    #144+                                                  // nop
    #144+                                                  // nop
    #144+                                                  // nop
    #144;                                                  // nop (nextaddr->20h);

  WriteMem(UOSel.HProc,BaseAddr-4,@sBuf[1],Length(sBuf));

  sBuf:=#232+NumStr(BaseAddr-Cst.EREDIR-5,4,True);         // call BaseAddr
  WriteMem(UOSel.HProc,Cst.EREDIR,@sBuf[1],5);             // Reroute!
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (relocated builds): pick up an item. E_DRAGADDR is a fastcall (item in ecx, amount in
// edx); an amount of 0 on a stack makes the client open its "how many" gump instead of lifting.
function TUOEvent.DragFastCode(Item, Amount : Cardinal) : String;
var
  s : String;
begin
  s:=#185+NumStr(Item,4,True)+                              // mov  ecx, PtrOnItem
     #186+NumStr(Amount,4,True);                            // mov  edx, Amount
  Result:=s+
     #104+NumStr(BaseAddr+$20+Length(s)+11,4,True)+         // push below ret (= after push, push, ret)
     #104+NumStr(Cst.EDRAGADDR,4,True)+                     // push Proc
     #195+                                                  // ret
     #195;                                                  // below: ret
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (relocated builds): the macro executor reads its table pointer and index from two
// adjacent globals instead of taking arguments: point them at our one-entry table (at BaseAddr+$70),
// call it, put the originals back. The index is at Tab+BMACROIDX: Tab+4 on the builds before
// 7.0.118.132, Tab-4 on that beta (with +4 there the client's own index stayed as its last macro left
// it, and the executor ran an empty step of our table).
// The 7.0.119.0 beta's executor takes the two as a fastcall instead (table in ecx, index in edx; the
// client's own step loads them from the same globals, and a one-entry call of its own passes an entry
// and 0), so the cave also loads ecx and edx. The older executors read the globals and never look at
// ecx / edx, which are scratch registers there: they run exactly as before.
function TUOEvent.MacroFastCode(Par1, Par2 : Cardinal) : String;
var
  s   : String;
  Idx : Cardinal;
begin
  Idx:=Cst.EMACROTAB+Cst.BMACROIDX;
  s:=#255#53+NumStr(Cst.EMACROTAB,4,True)+                  // push [Tab]          (save)
     #255#53+NumStr(Idx,4,True)+                            // push [Idx]          (save)
     #199#5+NumStr(Cst.EMACROTAB,4,True)+                   // mov  [Tab], 00800070
       NumStr(BaseAddr+$70,4,True)+                         //
     #199#5+NumStr(Idx,4,True)+                             // mov  [Idx], 0
       #0#0#0#0+                                            //
     #185+NumStr(BaseAddr+$70,4,True)+                      // mov  ecx, 00800070  (fastcall table)
     #49#210;                                               // xor  edx, edx       (fastcall index 0)
  Result:=s+
     #104+NumStr(BaseAddr+$20+Length(s)+11,4,True)+         // push below ret
     #104+NumStr(Cst.EMACROADDR,4,True)+                    // push Proc
     #195+                                                  // ret
     #143#5+NumStr(Idx,4,True)+                             // below: pop [Idx]    (restore)
     #143#5+NumStr(Cst.EMACROTAB,4,True)+                   // pop [Tab]           (restore)
     #195;                                                  // ret
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (relocated builds): `call rel32` from the instruction at absolute address At.
function TUOEvent.CallRel(Target, At : Cardinal) : String;
begin
  Result:=#232+NumStr(Target-(At+5),4,True);
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (relocated builds): item properties. If the client has the item's properties
// cached, make it fill two string objects (name at BaseAddr+$A0, properties at +$A4) and report 0
// into the result word; otherwise -- on the first pass only -- ask the server for them and leave the
// result at "not processed" so the caller keeps polling (the same protocol as the original cave).
function TUOEvent.PropFastCode(ID : Cardinal; FirstPass : Boolean) : String;
var
  s     : String;
  JzFix : Integer;
begin
  s:=#185+NumStr(ID,4,True);                                // mov  ecx, ID
  s:=s+CallRel(Cst.EITEMCHECKADDR,BaseAddr+$20+Length(s))+  // call HaveProperties(ecx)
       #132#192+                                            // test al, al
       #116#0;                                              // jz   REQUEST (fixed below)
  JzFix:=Length(s);
  s:=s+#199#5+NumStr(Cst.EITEMPROPID,4,True)+NumStr(ID,4,True);   // mov  [ItemPropID], ID
  s:=s+#106#1+                                              // push 1
       #104+NumStr(BaseAddr+$A0,4,True);                    // push @name
  s:=s+CallRel(Cst.EITEMNAMEADDR,BaseAddr+$20+Length(s));   // call ItemName (stdcall)
  s:=s+#106#1+                                              // push 1
       #104+NumStr(BaseAddr+$B0,4,True)+                    // push @props (own 16-byte string object)
       #185+NumStr(BaseAddr+$D4-Cst.BPROPFLAG,4,True);      // mov  ecx, fake this (flag lands at +$D4)
  s:=s+CallRel(Cst.EITEMPROPADDR,BaseAddr+$20+Length(s));   // call ItemProperties (thiscall, stdcall pops)
  s:=s+#49#192+                                             // xor  eax, eax
       #102#163+NumStr(BaseAddr-4,4,True)+                  // mov  [result], ax   (0 = done)
       #195;                                                // ret
  s[JzFix]:=Char(Length(s)-JzFix);                          // REQUEST:
  if FirstPass then
  begin
    s:=s+#185+NumStr(ID,4,True);                            // mov  ecx, ID
    s:=s+CallRel(Cst.EITEMREQADDR,BaseAddr+$20+Length(s));  // call RequestProperties(ecx)
  end;
  Result:=s+#195;                                           // ret   (result stays "not processed")
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (relocated builds): Pathfind. Same trick as the original -- enter the walk-to function
// after its tile lookup with a fake tile object holding X/Y/Z -- but the function builds an ebp frame
// with a security cookie and an SEH record, so the cave first runs a copy of those first
// B_PATHPROLOGUE bytes (read from the live client, so their absolute operands are already relocated).
// Stack on entry matches a real call: two zero arguments, the return address, then the frame.
function TUOEvent.PathfindFastCode(X,Y : Cardinal; Z : Integer) : String;
var
  Pro   : String;
  s     : String;
  Below : Cardinal;
begin
  SetLength(Pro,Cst.BPATHPROLOGUE);
  ReadMem(UOSel.HProc,Cst.EPATHFINDADDR,@Pro[1],Cst.BPATHPROLOGUE);
  // layout: 6A00 6A00 68 imm32 | prologue | B8 imm32 | 68 imm32 | C3 | C3 | X Y Z
  Below:=BaseAddr+$20+4+5+Cst.BPATHPROLOGUE+5+5+1;
  s:=#106#0#106#0+                                          // push 0 / push 0   (the two arguments)
     #104+NumStr(Below,4,True)+                             // push below        (return address)
     Pro+                                                   // the function's own prologue
     #184+NumStr(Below+1-Cst.BPOS,4,True)+                  // mov  eax, fake tile object (X at +BPOS)
     #104+NumStr(Cst.EPATHFINDMID,4,True)+                  // push mid
     #195+                                                  // ret  -> mid
     #195+                                                  // below: ret (function's ret 8 landed here)
     NumStr(X,2,True)+                                      // tile X
     NumStr(Y,2,True)+                                      // tile Y
     NumStr(Z,2,True);                                      // tile Z
  Result:=s;
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (relocated builds): BlockInfo's loop for a tile query that wants X in ecx, Y in
// edx and the four stack arguments Z, 0, @T, @flag (caller pops; the function stores a byte through the
// last one, on the 7.0.119.0 beta unconditionally). Same layout as the original: code
// padded to BaseAddr+$70, then the dwords X, Y, W, T that the code reads and writes.
function TUOEvent.BlockInfoFastCode(X,Y,Z,W,H : Integer) : String;
const
  DataOfs = $80;                   // the dwords X, Y, W, T and the output flag byte live here
var
  s      : String;
  Ende   : Integer;
  L1,L2  : Integer;
  Js1    : Integer;
  Weiter : Integer;
begin
  s:=#186+NumStr(BaseAddr+$FE+2*W*H,4,True)+                // mov   edx, _P_
     #191+NumStr(H,4,True);                                 // mov   edi, _H_
  L1:=Length(s);                                            // loop1:
  s:=s+#79+                                                 // dec   edi
       #120#0;                                              // js    ende (fixed below)
  Js1:=Length(s);
  s:=s+#139#53+NumStr(BaseAddr+DataOfs+8,4,True);           // mov   esi, W
  L2:=Length(s);                                            // loop2:
  s:=s+#78+                                                 // dec   esi
       #120+Char(L1-(Length(s)+3))+                         // js    loop1
       #96+                                                 // pushad
       #104+NumStr(BaseAddr+DataOfs+$10,4,True)+            // push  @flag   (the function stores a byte through it)
       #104+NumStr(BaseAddr+DataOfs+$C,4,True)+             // push  @T
       #106#0+                                              // push  0
       #104+NumStr(Z,4,True)+                               // push  _Z_
       #161+NumStr(BaseAddr+DataOfs+4,4,True)+              // mov   eax, Y
       #1#248+                                              // add   eax, edi
       #139#208+                                            // mov   edx, eax
       #161+NumStr(BaseAddr+DataOfs,4,True)+                // mov   eax, X
       #1#240+                                              // add   eax, esi
       #139#200;                                            // mov   ecx, eax
  Weiter:=Length(s)+5+5+1;                                  // after push weiter, push func, ret
  s:=s+#104+NumStr(BaseAddr+$20+Weiter,4,True)+             // push  weiter
       #104+NumStr(Cst.BLOCKINFO,4,True)+                   // push  func
       #195+                                                // ret
       #131#196#16+                                         // weiter: add esp, 10h
       #97+                                                 // popad
       #161+NumStr(BaseAddr+DataOfs+$C,4,True)+             // mov   eax, T
       #102#137#2+                                          // mov   [edx], ax
       #131#234#2;                                          // sub   edx, 2
  s:=s+#235+Char(L2-(Length(s)+2));                         // jmp   loop2
  Ende:=Length(s);
  s[Js1]:=Char(Ende-Js1);                                   // js    ende
  s:=s+#195;                                                // ende: ret
  // The code must end before the data it reads. This is exactly the kind of fixed-offset
  // contract a longer variant breaks silently, so it is checked rather than assumed.
  while Length(s)<DataOfs-$20 do s:=s+#144;
  if Length(s)>DataOfs-$20 then raise Exception.Create('BlockInfo cave code overlaps its data');
  Result:=s+
    NumStr(X,4,True)+                                       // dd    X
    NumStr(Y,4,True)+                                       // dd    Y
    NumStr(W,4,True)+                                       // dd    W
    #0#0#0#0+                                               // dd    T
    #0#0#0#0;                                               // dd    flag byte (+3 spare)
end;

////////////////////////////////////////////////////////////////////////////////
// Port change: BlockInfo's loop for the cdecl tile query of the fixed-base clients. The original
// pushed five arguments (X, Y, Z, 0, @T). client.exe 7.0.117.1's function takes a sixth, a pointer
// to a byte it writes (a door flag that never gets set while walking: the tile's object list doesn't
// carry the Door flag); its own callers push it and pop 18h. With five, the sixth was the row
// counter pushad had saved, and the client wrote its byte to an address below 32. This pushes @flag as well: a five-argument build ignores it, since a
// cdecl function never pops its own arguments (the original's add esp, 14h). The layout is
// BlockInfoFastCode's: code padded to BaseAddr+$80, then the dwords X, Y, W, T and the flag.
function TUOEvent.BlockInfoCode(X,Y,Z,W,H : Integer) : String;
const
  DataOfs = $80;
var
  s      : String;
  Ende   : Integer;
  L1,L2  : Integer;
  Js1    : Integer;
  Weiter : Integer;
begin
  s:=#186+NumStr(BaseAddr+$FE+2*W*H,4,True)+                // mov   edx, _P_
     #191+NumStr(H,4,True);                                 // mov   edi, _H_
  L1:=Length(s);                                            // loop1:
  s:=s+#79+                                                 // dec   edi
       #120#0;                                              // js    ende (fixed below)
  Js1:=Length(s);
  s:=s+#139#53+NumStr(BaseAddr+DataOfs+8,4,True);           // mov   esi, W
  L2:=Length(s);                                            // loop2:
  s:=s+#78+                                                 // dec   esi
       #120+Char(L1-(Length(s)+3))+                         // js    loop1
       #96+                                                 // pushad
       #104+NumStr(BaseAddr+DataOfs+$10,4,True)+            // push  @flag
       #104+NumStr(BaseAddr+DataOfs+$C,4,True)+             // push  @T
       #106#0+                                              // push  0
       #104+NumStr(Z,4,True)+                               // push  _Z_
       #161+NumStr(BaseAddr+DataOfs+4,4,True)+              // mov   eax, Y
       #1#248+                                              // add   eax, edi
       #80+                                                 // push  eax
       #161+NumStr(BaseAddr+DataOfs,4,True)+                // mov   eax, X
       #1#240+                                              // add   eax, esi
       #80;                                                 // push  eax
  Weiter:=Length(s)+5+5+1;                                  // after push weiter, push func, ret
  s:=s+#104+NumStr(BaseAddr+$20+Weiter,4,True)+             // push  weiter
       #104+NumStr(Cst.BLOCKINFO,4,True)+                   // push  func
       #195+                                                // ret
       #131#196#24+                                         // weiter: add esp, 18h
       #97+                                                 // popad
       #161+NumStr(BaseAddr+DataOfs+$C,4,True)+             // mov   eax, T
       #102#137#2+                                          // mov   [edx], ax
       #131#234#2;                                          // sub   edx, 2
  s:=s+#235+Char(L2-(Length(s)+2));                         // jmp   loop2
  Ende:=Length(s);
  s[Js1]:=Char(Ende-Js1);                                   // js    ende
  s:=s+#195;                                                // ende: ret
  while Length(s)<DataOfs-$20 do s:=s+#144;
  if Length(s)>DataOfs-$20 then raise Exception.Create('BlockInfo cave code overlaps its data');
  Result:=s+
    NumStr(X,4,True)+                                       // dd    X
    NumStr(Y,4,True)+                                       // dd    Y
    NumStr(W,4,True)+                                       // dd    W
    #0#0#0#0+                                               // dd    T
    #0#0#0#0;                                               // dd    flag byte (+3 spare)
end;

const
  STEPINFO_DONE = $F0;    // BaseAddr+$F0: the cave's last instruction sets it to 1
  STEPINFO_DATA = $100;   // BaseAddr+$100: the entries, 16 bytes each (where BlockInfo's output goes)

////////////////////////////////////////////////////////////////////////////////
// Port addition (the pathfinder, PATH CHECK): StepInfo's loop. It calls the tile query once per
// entry at BaseAddr+$100. Each entry is 16 bytes: the dwords X, Y, Z and Dir. The query writes the
// new height over Z, and its sixth argument's byte (see BlockInfoCode; unused) into byte 1 of Dir,
// after Dir was pushed. Fast: X in ecx, Y in edx, then Z, Dir, @newZ, @byte (the relocated builds,
// as BlockInfoFastCode). Else cdecl X, Y, Z, Dir, @newZ, @byte (as BlockInfoCode). Last, it sets the
// done dword, so that a client that never ran the event isn't read as having answered.
function TUOEvent.StepInfoCode(N : Integer; Fast : Boolean) : String;
var
  s      : String;
  L1     : Integer;
  Js1    : Integer;
  Weiter : Integer;
  Ende   : Integer;
begin
  s:=#190+NumStr(BaseAddr+STEPINFO_DATA,4,True)+            // mov   esi, entries
     #191+NumStr(N,4,True);                                 // mov   edi, N
  L1:=Length(s);                                            // loop:
  s:=s+#79+                                                 // dec   edi
       #120#0;                                              // js    ende (fixed below)
  Js1:=Length(s);
  s:=s+#96+                                                 // pushad
       #141#70#13+                                          // lea   eax, [esi+0Dh]   the sixth's byte
       #80+                                                 // push  eax
       #141#70#8+                                           // lea   eax, [esi+8]     new height (over Z)
       #80+                                                 // push  eax
       #255#118#12+                                         // push  dword [esi+0Ch]  Dir
       #255#118#8;                                          // push  dword [esi+8]    Z
  if Fast then
    s:=s+#139#14+                                           // mov   ecx, [esi]       X
         #139#86#4                                          // mov   edx, [esi+4]     Y
  else
    s:=s+#255#118#4+                                        // push  dword [esi+4]    Y
         #255#54;                                           // push  dword [esi]      X
  Weiter:=Length(s)+5+5+1;                                  // after push weiter, push func, ret
  s:=s+#104+NumStr(BaseAddr+$20+Weiter,4,True)+             // push  weiter
       #104+NumStr(Cst.BLOCKINFO,4,True)+                   // push  func
       #195;                                                // ret
  if Fast then s:=s+#131#196#16                             // weiter: add esp, 10h
  else s:=s+#131#196#24;                                    // weiter: add esp, 18h
  s:=s+#97+                                                 // popad
       #131#198#16;                                         // add   esi, 10h
  s:=s+#235+Char(L1-(Length(s)+2));                         // jmp   loop
  Ende:=Length(s);
  s[Js1]:=Char(Ende-Js1);                                   // js    ende
  s:=s+#199#5+NumStr(BaseAddr+STEPINFO_DONE,4,True)+        // ende: mov dword [done], 1
       NumStr(1,4,True)+
       #195;                                                // ret
  if Length(s)>STEPINFO_DONE-$20 then raise Exception.Create('StepInfo cave code overlaps its data');
  Result:=s;
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (relocated builds): the cave code the client's own inlined "say something"
// does -- allocate a $1800-byte message object and run its constructor
// ctor(Obj, Text, Color, Font, 0, 0) (thiscall, callee pops). Obj=0 is a system message and is
// subject to the client's "messages enabled" dword (Gate); an overhead message on Obj is not.
// Assembled for the cave at BaseAddr+$20.
function TUOEvent.NewMessageObject(Obj : Cardinal; Font, Color, TextAddr : Cardinal; Gate : Boolean) : String;
var
  s       : String;
  JeFix1  : Integer;
  JeFix2  : Integer;
begin
  s:='';
  JeFix1:=0;
  if Gate then
  begin
    s:=s+#131#61+NumStr(Cst.EMSGGATE,4,True)+#0+            // cmp  dword ptr [Gate], 0
         #116#0;                                            // je   END (fixed below)
    JeFix1:=Length(s);
  end;
  s:=s+#104#0#24#0#0;                                       // push 1800h
  if Cst.EMSGFLAGA<>0 then
    s:=s+#198#5+NumStr(Cst.EMSGFLAGA,4,True)+#1;            // mov  byte  ptr [FlagA], 1
  if Cst.EMSGFLAGB<>0 then
    s:=s+#199#5+NumStr(Cst.EMSGFLAGB,4,True)+#1#0#0#0;      // mov  dword ptr [FlagB], 1
  s:=s+CallRel(Cst.ENEWOBJ,BaseAddr+$20+Length(s))+         // call operator new
       #131#196#4+                                          // add  esp, 4
       #133#192+                                            // test eax, eax
       #116#0;                                              // je   END (fixed below)
  JeFix2:=Length(s);
  s:=s+#106#0+                                              // push 0
       #106#0+                                              // push 0
       #104+NumStr(Font,4,True)+                            // push Font
       #104+NumStr(Color,4,True)+                           // push Color
       #104+NumStr(TextAddr,4,True)+                        // push Text
       #104+NumStr(Obj,4,True)+                             // push Obj
       #139#200;                                            // mov  ecx, eax
  s:=s+CallRel(Cst.ESYSMSGADDR,BaseAddr+$20+Length(s));     // call ctor
  if Gate then s[JeFix1]:=Char(Length(s)-JeFix1);           // je END
  s[JeFix2]:=Char(Length(s)-JeFix2);                        // je END
  Result:=s+#195;                                           // END: ret
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ExMsg(ID,Font,Color : Cardinal; Msg : String);
var
  cBuf : Cardinal;
  sBuf : String;
begin
  if Cst.EEXMSGADDR=0 then Exit;                                       // address unknown for this build: never `push 0; ret` into the client
  InitEvents;

  Msg:=Msg+#0;                                             // Write text buffer
  WriteMem(UOSel.HProc,BaseAddr+$70,@Msg[1],Length(Msg));

  cBuf:=FindID(ID);
  if cBuf=0 then Exit;

  if Cst.ENEWOBJ<>0 then
    sBuf:=NewMessageObject(cBuf,Font,Color,BaseAddr+$70,False)
  else
  sBuf:=                                                   //
    #185+NumStr(cBuf,4,True)+                              // mov  ecx, ObjPtr
    #104#0#0#0#0+                                          // push 00000000
    #104#0#0#0#0+                                          // push 00000000
    #104+NumStr(Font,4,True)+                              // push Font
    #104+NumStr(Color,4,True)+                             // push Color
    #104+NumStr(BaseAddr+$70,4,True)+                      // push PtrOnMsg
    #104+NumStr(BaseAddr+$49,4,True)+                      // push N1
    #104+NumStr(Cst.EEXMSGADDR,4,True)+                    // push ExMsgAddr
    #195+                                                  // ret
    #195;                                                  // N1:ret

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#01#00,2);               // Start Event!
  WaitTillProcessed;                                       // Wait
end;

////////////////////////////////////////////////////////////////////////////////
function TUOEvent.ReplaceStr(Str,RepWhat,RepWith : String) : String;
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
function TUOEvent.GetFormStr(StrAddr : Cardinal) : String;
var
  Cnt,
  Cnt2,
  Cnt3  : Integer;
  sBuf  : String;
  sBuf2 : String;
begin
  SetLength(sBuf,8000);
  ReadMem(UOSel.HProc,StrAddr,@sBuf[1],8000);

  sBuf2:='';
  for Cnt:=0 to 3999 do
    sBuf2:=sBuf2+sBuf[1+Cnt*2];
  sBuf2:=PChar(@sBuf2[1]);

  for Cnt:=1 to Length(sBuf2) do
    if sBuf2[Cnt]<#32 then sBuf2[Cnt]:=#32; //remove possible control characters!

  sBuf2:=ReplaceStr(sBuf2,'<BR>',#13#10);

  for Cnt3:=1 to 500 do
  begin
    Cnt:=Pos('<',sBuf2);
    Cnt2:=Pos('>',sBuf2);
    if (Cnt=0)or(Cnt2=0) then Break;
    Delete(sBuf2,Cnt,Cnt2-Cnt+1);
  end;

  Result:=sBuf2;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.EvProperty(ID : Cardinal);
var
  Cnt   : Integer;
  sBuf  : String;
  cBuf  : Cardinal;
  cBuf2 : Cardinal;
begin
  PropStr1:='';
  PropStr2:='';
  if Cst.FEVPROPERTY=0 then Exit;
  if (Cst.EITEMCHECKADDR=0)or(Cst.EITEMNAMEADDR=0)or(Cst.EITEMPROPADDR=0)or
     (Cst.EITEMREQADDR=0)or(Cst.EITEMPROPID=0) then Exit;   // unknown for this build
  InitEvents;

  for Cnt:=1 to 100 do
  begin

    if Cnt>1 then
    begin
      if not Delay(30) then Exit;
      ReadMem(UOSel.HProc,BaseAddr-4,@cBuf,2);          // Get result
      case cBuf of
        0 : begin // Event successful!
              ReadMem(UOSel.HProc,BaseAddr+$A0,@cBuf,4);
              if Cst.FPROPFAST=1 then                       // the modern build's string objects are 16 bytes
                ReadMem(UOSel.HProc,BaseAddr+$B0,@cBuf2,4)  // wide, so the second one sits further on
              else
                ReadMem(UOSel.HProc,BaseAddr+$A4,@cBuf2,4);
              PropStr1:=GetFormStr(Cardinal(cBuf));
              if PropStr1<>'' then
              begin
                sBuf:=GetFormStr(Cardinal(cBuf2));
                PropStr2:=sBuf;
              end;
              Exit;
            end;
        2 : Continue; // Event not yet processed?
      end;
    end;

    if Cst.FPROPFAST=1 then
      sBuf:=PropFastCode(ID,Cnt=1)
    else begin
    sBuf:=
      //Is item already in memory?
      #104+NumStr(BaseAddr+$76,4,True)+                    // push End
      #185+NumStr(ID,4,True)+                              // mov ecx, ID
      #81+                                                 // push ecx
      #81+                                                 // push ecx
      #104+NumStr(BaseAddr+$37,4,True)+                    // push below ret
      #104+NumStr(Cst.EITEMCHECKADDR,4,True)+              // push ItemCheckAddr
      #195+                                                // ret
      #89+                                                 // pop ecx
      #89+                                                 // pop ecx
      #132#192+                                            // test al, al
      #102#184#1#0+                                        // mov ax, 1 (return value)
      #117#60+                                             // jne N1

      //Get the two str pointers ($A0 and $A4, $C0 is for temp buffer)
      #137#13+NumStr(Cst.EITEMPROPID,4,True)+              // mov [00D9CE28], ecx
      #81+                                                 // push ecx
      #106#1+                                              // push 1
      #104+NumStr(BaseAddr+$A0,4,True)+                    // push 008000A0
      #104+NumStr(BaseAddr+$5A,4,True)+                    // push unters ret
      #104+NumStr(Cst.EITEMNAMEADDR,4,True)+               // push ItemNameAddr
      #195+                                                // ret
      #106#1+                                              // push 1
      #104+NumStr(BaseAddr+$A4,4,True)+                    // push 008000A4
      #104+NumStr(BaseAddr+$71,4,True)+                    // push unters ret
      #104+NumStr(Cst.EITEMPROPADDR,4,True)+               // push ItemPropAddr
      #185+NumStr(BaseAddr+$C0-$B8,4,True)+                // mov ecx, Addr-B8 for overwriting
      #195+                                                // ret
      #131#196#4+                                          // add esp, 4
      #49#192+                                             // xor eax, eax (return value)

      //Finish Event and return result
      #102#163+NumStr(BaseAddr-4,4,True)+                  // End: mov [007FFFFC], ax
      #195;                                                // ret

    if Cnt=1 then sBuf:=sBuf+                              //
      //Request item strings from server                   //
      #81+                                                 // N1:push ecx
      #104+NumStr(BaseAddr+$89,4,True)+                    // push below ret
      #104+NumStr(Cst.EITEMREQADDR,4,True)+                // push ItemReqAddr
      #195+                                                // ret
      #131#196#4+                                          // add esp, 4
      #102#184#1#0;                                        // mov ax, 1 (return value)

    sBuf:=sBuf+#195;                                       // N1:ret (alternative N1)
    end;

    WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
    WriteMem(UOSel.HProc,BaseAddr-4,#2#0#1#0,4);        // Start Event!
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.Pathfind(X,Y : Cardinal; Z : Integer);
var
  sBuf : String;
begin
  if Cst.EPATHFINDADDR=0 then Exit;                                       // address unknown for this build: never `push 0; ret` into the client
  InitEvents;

  sBuf:=                                                   //
    #106#0+                                                //push 00000000
    #106#0+                                                //push 00000000
    #104+NumStr(BaseAddr+$39,4,True)+                      //push 00800043
    #81+                                                   //push ecx
    #83+                                                   //push ebx
    #85+                                                   //push ebp
    #86+                                                   //push esi
    #87+                                                   //push edi
    #104+NumStr(Cst.EPATHFINDADDR,4,True)+                 //push 00487B47
    #184+NumStr(BaseAddr+$3A-$24,4,True)+                  //mov eax, ...
    #195+                                                  //ret
    #195+                                                  //ret
    NumStr(X,2,True)+                                      //(mov ebp,) [eax+24]
    NumStr(Y,2,True)+                                      //(mov edx,) [eax+26]
    NumStr(Z,2,True);                                      //(mov eax,) [eax+28]

  if Cst.EPATHFINDMID<>0 then
    sBuf:=PathfindFastCode(X,Y,Z)
  else
  if Cst.FPATHFINDVER=1 then
  begin
    sBuf[11]:=#144; //nop (clients >=6.0.6.2 do not need regpops besides ecx!)
    sBuf[12]:=#144; //nop
    sBuf[13]:=#144; //nop
    sBuf[14]:=#144; //nop
  end;

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#1#0,2);                 //Start Event!
  WaitTillProcessed;                                       // Wait
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.Drag(ID : Cardinal);
var
  DragAmount : Cardinal;
  sBuf  : String;
  cBuf  : Cardinal;
  cBuf2 : Cardinal;
begin
  if Cst.EDRAGADDR=0 then Exit;                                       // address unknown for this build: never `push 0; ret` into the client
  InitEvents;
  if UOVar.LLiftedKind>0 then Exit;
  DragID:=ID;
  DragType:=0;

  cBuf:=Cst.CHARPTR-(Cst.BITEMID+$C);                      // Find item
  repeat                                                   //
    ReadMem(UOSel.HProc,cBuf+Cst.BITEMID+$C,@cBuf,4);      //
    if cBuf=0 then Exit;                                   //
    ReadMem(UOSel.HProc,cBuf+Cst.BITEMID,@cBuf2,4);        //
  until cBuf2=ID;                                          //

  if Cst.FDRAGFASTCALL=1 then
  begin
    DragAmount:=0;
    ReadMem(UOSel.HProc,cBuf+Cst.BITEMSTACK,@DragAmount,2);
    if DragAmount=0 then DragAmount:=1;
    sBuf:=DragFastCode(cBuf,DragAmount);
  end
  else begin
  sBuf:=                                                   //
    #104#0#0#0#0+                                          // push 0
    #104+NumStr(cBuf,4,True);                              // push PtrOnItem

  sBuf:=sBuf+                                              //
    #104+NumStr(BaseAddr+Length(sBuf)+$2B,4,True)+         // push below ret
    #104+NumStr(Cst.EDRAGADDR,4,True)+                     // push Proc
    #195+                                                  // ret
    #131#196+Char(8)+                                      // add esp, 8
    #195;                                                  // ret
  end;

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#1#0,2);                 // Start Event!
  WaitTillProcessed;                                       // Wait
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.SysMessage(Msg : String; Col : Cardinal);
var
  sBuf  : String;
begin
  if Cst.ESYSMSGADDR=0 then Exit;                                       // address unknown for this build: never `push 0; ret` into the client
  InitEvents;

  if Cst.ENEWOBJ<>0 then
    sBuf:=NewMessageObject(0,3,Col,BaseAddr+$100,True)
  else begin
  sBuf:=                                                   //
    #104+NumStr(BaseAddr+$100,4,True)+                     // push 00800100
    #104#3#0#0#0+                                          // push 3
    #104+NumStr(Col,4,True);                               // push SysMsgColor

  sBuf:=sBuf+                                              //
    #104+NumStr(BaseAddr+Length(sBuf)+$2B,4,True)+         // push below ret
    #104+NumStr(Cst.ESYSMSGADDR,4,True)+                   // push Proc
    #195+                                                  // ret
    #131#196+Char(12)+                                     // add esp, 12
    #195;                                                  // ret
  end;

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  sBuf:=Msg+#0;
  WriteMem(UOSel.HProc,BaseAddr+$100,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#1#0,2);                 // Start Event!
  WaitTillProcessed;                                       // Wait
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.Macro(Par1, Par2 : Cardinal; Str : String = '');
var
  sBuf  : String;
begin
  if Cst.EMACROADDR=0 then Exit;                                       // address unknown for this build: never `push 0; ret` into the client
  InitEvents;

  // Possible problem: If no object is being used but
  // you target something (22), a packet is probably sent that
  // should not be sent!!! -> detectable, could be prevented by checking #targcurs!!!

  {if Par1=22 then                                         // Event Macro 22 0 (TargetLast) must
    if UOVar.LTargetKind=1 then                            // be replaced with an ExEvent for
  begin                                                    // anti-detection purposes!
    ExEv_TargetObj(UOVar.LTargetID,False);                 //
    UOVar.TargCurs:=False;                                 //
    Exit;                                                  //
  end;}                                                    //

  if Par1=15 then                                          // Event Macro Mapping!
    if Cst.FMACROMAP in [1,2] then                         //
  begin                                                    //
    if Par2<100 then Inc(Par2);                            //
    if Par2 in[145..150,245..252] then Inc(Par2,256);      //
  end;                                                     //
                                                           //
  if Par1>25 then                                          //
    if Cst.FMACROMAP in [2] then                           //
  begin                                                    //
    if Par1 in [26,27] then Exit;                          //
    Dec(Par1,2);                                           //
  end;                                                     //

  if Cst.EMACROTAB=0 then
  begin
    sBuf:=                                                 //
      #104#0#0#0#0+                                        // push 0
      #104+NumStr(BaseAddr+$70,4,True);                    // push 00800070

    sBuf:=sBuf+                                            //
      #104+NumStr(BaseAddr+Length(sBuf)+$2B,4,True)+       // push below ret
      #104+NumStr(Cst.EMACROADDR,4,True)+                  // push Proc
      #195+                                                // ret
      #131#196+Char(8)+                                    // add esp, 8
      #195;                                                // ret
  end
  else begin
    // Port addition, relocated builds: the executor takes no arguments and reads the
    // macro table pointer and index from two adjacent globals. Point them at our one-entry
    // table for the call, then put the originals back.
    sBuf:=MacroFastCode(Par1,Par2);
  end;

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));

  sBuf:=                                                   //
    #80#0#0#0#0#0#25#0#0#0#0#0#1#0#0#0#0#0#0#0#1#0#0#0+    // MagicStr?
    NumStr(Par1,2,True)+#0#0+                              // Par1
    NumStr(Par2,2,True)+#0#0+                              // Par2
    NumStr(BaseAddr+$100,4,True);                          // StrBuf

  WriteMem(UOSel.HProc,BaseAddr+$70,@sBuf[1],Length(sBuf));

  SetLength(sBuf,256);                                     //
  StringToWideChar(Str,@sBuf[1],256);                      // Prepare Str

  WriteMem(UOSel.HProc,BaseAddr+$100,@sBuf[1],256);        //
  WriteMem(UOSel.HProc,BaseAddr-2,#1#0,2);                 // Start Event!
  WaitTillProcessed;                                       // Wait
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ContTop(Index : Integer);
var
  Addr : Cardinal;
  sBuf : String;
begin
  if Cst.ECONTTOP=0 then Exit;
  if not UOVar.GetContAddr(Addr,Index) then Exit;
  InitEvents;

  sBuf:=                                                   //
    #185+NumStr(Addr,4,True)+                              // mov  ecx, GumpPtr
    #104#0#0#0#0+                                          // push 00000000
    #104+NumStr(BaseAddr+$20+21,4,True)+                   // push N1
    #104+NumStr(Cst.ECONTTOP,4,True)+                      // push Proc
    #195+                                                  // ret
    #195;                                                  // N1:ret

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#01#00,2);               // Start Event!
  WaitTillProcessed;                                       // Wait
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.StatBar(ID : Cardinal);
var
  c    : Cardinal;
  sBuf : String;
begin
  if Cst.ESTATBAR=0 then Exit;
  c:=FindID(ID);
  if c=0 then Exit;
  InitEvents;

  sBuf:=                                                   //
    #185+NumStr(BaseAddr-$21,4,True)+                      // mov ecx, @NPCPtr-4C    PaperdollStruc
    #104+NumStr(Cst.ESTATBAR,4,True)+                      // push OpenStatBar       has NPCPtr at
    #195+                                                  // ret                    offset 4C!
    NumStr(c,4,True);                                      // NPCPtr DD ????

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#01#00,2);               // Start Event!
  WaitTillProcessed;                                       // Wait
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.BlockInfo(X,Y,Z,W,H : Integer);
var
  sBuf : String;
begin
  BlockStr:='';
  if W*H>32*32 then Exit;
  if Cst.BLOCKINFO=0 then                                  // address unknown for this build: never `push 0; ret`
  begin                                                    // into the client; answer like an unreadable block (zeros)
    SetLength(BlockStr,W*H*2);
    if Length(BlockStr)>0 then FillChar(BlockStr[1],Length(BlockStr),0);
    Exit;
  end;
  InitEvents;

  if Cst.FBLOCKINFOFAST=1 then
    sBuf:=BlockInfoFastCode(X,Y,Z,W,H)
  else
    sBuf:=BlockInfoCode(X,Y,Z,W,H);                       // port change: one argument more, see there

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#01#00,2);               // Start Event!
  WaitTillProcessed;                                       // Wait

  SetLength(BlockStr,W*H*2);
  ReadMem(UOSel.HProc,BaseAddr+$100,@BlockStr[1],W*H*2);
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (the pathfinder's walker, PATH CHECK): the client's own step check for up to
// STEP_CHECK_MAX steps in one event. C_BLOCKINFO is the client's CalculateNewZ (the one its own
// pathfinder and walk code call before every move): from height Z next to X,Y, can the character
// step onto it in Dir, and at what height does it land (-128: no)? False, and Q untouched, when the
// address is unknown, there is no client, or the client didn't run the event in time.
function TUOEvent.StepInfo(var Q : TStepChecks) : Boolean;
var
  sBuf : String;
  Buf  : array of LongWord;
  N, i : Integer;
  Done : LongWord;
begin
  Result:=False;
  N:=Length(Q);
  if (N=0) or (N>STEP_CHECK_MAX) then Exit;
  if Cst.BLOCKINFO=0 then Exit;                            // never `push 0; ret` into the client
  InitEvents;
  if BaseAddr=0 then Exit;                                 // no hook for this build: no event runs

  SetLength(Buf,N*4);
  for i:=0 to N-1 do
  begin
    Buf[i*4]:=LongWord(Q[i].X);
    Buf[i*4+1]:=LongWord(Q[i].Y);
    Buf[i*4+2]:=LongWord(Q[i].Z);
    Buf[i*4+3]:=LongWord(Q[i].Dir and 7);                  // byte 1 (the sixth's) zero going in
  end;
  sBuf:=StepInfoCode(N,Cst.FBLOCKINFOFAST=1);
  Done:=0;
  WriteMem(UOSel.HProc,BaseAddr+STEPINFO_DATA,@Buf[0],N*16);
  WriteMem(UOSel.HProc,BaseAddr+STEPINFO_DONE,@Done,4);
  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#01#00,2);               // Start Event!
  WaitTillProcessed;                                       // Wait

  Done:=0;
  if not ReadMem(UOSel.HProc,BaseAddr+STEPINFO_DONE,@Done,4) or (Done<>1) then Exit;
  if not ReadMem(UOSel.HProc,BaseAddr+STEPINFO_DATA,@Buf[0],N*16) then Exit;
  for i:=0 to N-1 do
    Q[i].NewZ:=LongInt(Buf[i*4+2]);
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
/// ExEvents ///////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TUOEvent.SendExEvent(Packet : String);
var
  sBuf   : String;
  cBuf   : Cardinal;
  AddEsp4: String;
begin
  AddEsp4:=#131#196#4;                                     // cdecl sender: caller pops its argument
  if Cst.FSENDTHISCALL=1 then AddEsp4:=#144#144#144;       // thiscall `ret 4`: already popped
  if Cst.ESENDPACKET=0 then Exit;                                       // address unknown for this build: never `push 0; ret` into the client
  InitEvents;                                              // Init Ex-/Events

  // Port addition: the network object must exist (not logged in / not connected -> nil), or
  // the thiscall below would run with this=0 inside the client.
  if (Cst.ESENDECX>0)and(Cst.FSENDTHISCALL=1) then
  begin
    ReadMem(UOSel.HProc,Cst.ESENDECX,@cBuf,4);
    if cBuf=0 then Exit;
  end;

  sBuf:='';                                                // Old client
  if Cst.ESENDLEN>0 then sBuf:=sBuf+                       // compatibility
    #199#5+NumStr(Cst.ESENDLEN,4,True)+                    //
    NumStr(Length(Packet),4,True);                         //
  if Cst.ESENDECX>0 then sBuf:=sBuf+                       //
    #139#13+NumStr(Cst.ESENDECX,4,True);                   //

  sBuf:=sBuf+                                              // ***Send***
    #104+NumStr(BaseAddr+$20+Length(sBuf)+20,4,True)+      // push PacketAddr
    #104+NumStr(BaseAddr+$20+Length(sBuf)+16,4,True)+      // push below ret
    #104+NumStr(Cst.ESENDPACKET,4,True)+                   // push PacketSender
    #195+                                                  // ret
    AddEsp4+                                               // add esp, 4 (nop x3 if the callee pops it)
    #195+                                                  // ret
    Packet;                                                // (Packet)

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#1#0,2);                 // Start Event!

  WaitTillProcessed;                                       // Wait
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (exevent GumpReply). The send part is SendExEvent's, byte for byte. With Dtor<>0 the
// return lands on the delete instead of a ret:
//   cmp dword [Gump+4], $FEEDBEEF ; jne Done     -- still a gump object ...
//   cmp dword [Gump], VTable      ; jne Done     -- ... of the same class
//   mov ecx, Gump ; push 1 ; push Done ; push Dtor ; ret   -- Dtor(1), a thiscall that pops its 1
//   Done: ret                                   -- back into E_OLDDIR
function TUOEvent.GumpReplyCode(Gump, VTable, Dtor : Cardinal; const Packet : String) : String;
const
  CLOSE_LEN = 42;
var
  Pre, AddEsp4, Close : String;
  Base, Done          : Cardinal;
begin
  AddEsp4:=#131#196#4;                                     // cdecl sender: caller pops its argument
  if Cst.FSENDTHISCALL=1 then AddEsp4:=#144#144#144;       // thiscall `ret 4`: already popped
  Pre:='';
  if Cst.ESENDLEN>0 then Pre:=Pre+
    #199#5+NumStr(Cst.ESENDLEN,4,True)+NumStr(Length(Packet),4,True);
  if Cst.ESENDECX>0 then Pre:=Pre+
    #139#13+NumStr(Cst.ESENDECX,4,True);
  Base:=BaseAddr+$20+Cardinal(Length(Pre));
  Close:='';
  if Dtor<>0 then
  begin
    Done:=Base+19+CLOSE_LEN;
    Close:=
      #129#61+NumStr(Gump+4,4,True)+NumStr($FEEDBEEF,4,True)+   // cmp dword [Gump+4], $FEEDBEEF
      #117+Chr(CLOSE_LEN-12)+                                    // jne Done
      #129#61+NumStr(Gump,4,True)+NumStr(VTable,4,True)+         // cmp dword [Gump], VTable
      #117+Chr(CLOSE_LEN-24)+                                    // jne Done
      #185+NumStr(Gump,4,True)+                                  // mov ecx, Gump
      #106#1+                                                    // push 1
      #104+NumStr(Done,4,True)+                                  // push Done
      #104+NumStr(Dtor,4,True)+                                  // push Dtor
      #195;                                                      // ret -> Dtor
  end;
  Result:=Pre+
    #104+NumStr(Base+20+Cardinal(Length(Close)),4,True)+   // push PacketAddr
    #104+NumStr(Base+16,4,True)+                           // push below ret
    #104+NumStr(Cst.ESENDPACKET,4,True)+                   // push PacketSender
    #195+                                                  // ret
    AddEsp4+                                               // add esp, 4 (nop x3 if the callee pops it)
    Close+                                                 // the delete (when Dtor<>0)
    #195+                                                  // Done: ret
    Packet;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOEvent.ExEv_GumpReply(Gump, VTable : Cardinal; const Packet : String; Close : Boolean) : Boolean;
var
  sBuf : String;
  cBuf : Cardinal;
  Dtor : Cardinal;
begin
  Result:=False;
  if Cst.ESENDPACKET=0 then Exit;
  if (Gump=0) or (VTable=0) or (Packet='') then Exit;
  InitEvents;
  if BaseAddr=0 then Exit;                                 // no event hook on this build
  if (Cst.ESENDECX>0)and(Cst.FSENDTHISCALL=1) then
  begin
    cBuf:=0;
    ReadMem(UOSel.HProc,Cst.ESENDECX,@cBuf,4);
    if cBuf=0 then Exit;                                   // not connected
  end;
  Dtor:=0;
  if Close then
    if not ReadMem(UOSel.HProc,VTable,@Dtor,4) then Dtor:=0;
  sBuf:=GumpReplyCode(Gump,VTable,Dtor,Packet);
  if Length(sBuf)>$1000-$620 then Exit;                    // past the cave page
  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#1#0,2);                 // Start Event!
  WaitTillProcessed;                                       // Wait
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (the gump-answer hook). The code at Page+HOOK_CODE; on entry [esp] is the caller's return
// address and [esp+4] the packet, with both calling conventions of the send function:
//   pushad ; pushfd ; mov esi,[esp+$28]          -- the packet (36 bytes pushed, then the return address)
//   test esi,esi ; jz Done ; cmp byte [esi],$B1 ; jne Done
//   movzx ecx, word [esi+1] ; cmp ecx,3 ; jb Done   -- its length, low byte first, as the client keeps it
//   cmp ecx,HOOK_MAX ; jbe +5 ; mov ecx,HOOK_MAX
//   mov [Page+HOOK_LEN],ecx ; mov edi,Page+HOOK_BUF ; cld ; rep movsb ; inc dword [Page+HOOK_COUNT]
//   Done: popfd ; popad ; <the instructions replaced> ; jmp Func+N
function TUOEvent.SendHookCode(Page, Func : Cardinal; const Orig : String) : String;
var
  Code : Cardinal;
begin
  Code:=Page+HOOK_CODE;
  Result:=
    #$60#$9C+                                              // pushad ; pushfd
    #$8B#$74#$24#$28+                                      // mov esi, [esp+$28]
    #$85#$F6+                                              // test esi, esi
    #$74+Chr(47)+                                          // jz Done
    #$80#$3E#$B1+                                          // cmp byte [esi], $B1
    #$75+Chr(42)+                                          // jne Done
    #$0F#$B7#$4E#$01+                                      // movzx ecx, word [esi+1]
    #$83#$F9#$03+                                          // cmp ecx, 3
    #$72+Chr(33)+                                          // jb Done
    #$81#$F9+NumStr(HOOK_MAX,4,True)+                      // cmp ecx, HOOK_MAX
    #$76#$05+                                              // jbe +5
    #$B9+NumStr(HOOK_MAX,4,True)+                          // mov ecx, HOOK_MAX
    #$89#$0D+NumStr(Page+HOOK_LEN,4,True)+                 // mov [Page+HOOK_LEN], ecx
    #$BF+NumStr(Page+HOOK_BUF,4,True)+                     // mov edi, Page+HOOK_BUF
    #$FC+                                                  // cld
    #$F3#$A4+                                              // rep movsb
    #$FF#$05+NumStr(Page+HOOK_COUNT,4,True)+               // inc dword [Page+HOOK_COUNT]
    #$9D#$61+                                              // Done: popfd ; popad
    Orig;                                                  // the instructions the jmp replaced
  Result:=Result+#$E9+NumStr(Func+Cardinal(Length(Orig))-(Code+Cardinal(Length(Result))+5),4,True);
end;

////////////////////////////////////////////////////////////////////////////////
// Port addition (the gump-answer hook). Run by the event cave, on the client's main thread:
//   mov eax, Func ; mov dword [eax+1], rel ; mov byte [eax], $E9 ; nop out the rest of the N bytes ; ret
function TUOEvent.SendHookInstallCode(Func, Page : Cardinal; N : Integer) : String;
var
  I : Integer;
begin
  Result:=
    #$B8+NumStr(Func,4,True)+                              // mov eax, Func
    #$C7#$40#$01+NumStr(Page+HOOK_CODE-(Func+5),4,True)+   // mov dword [eax+1], rel32 to the hook
    #$C6#$00#$E9;                                          // mov byte [eax], $E9 (jmp)
  for I:=5 to N-1 do
    Result:=Result+#$C6#$40+Chr(I)+#$90;                   // mov byte [eax+I], $90 (never reached)
  Result:=Result+#$C3;                                     // ret
end;

////////////////////////////////////////////////////////////////////////////////
function TUOEvent.GumpHookActive(Install : Boolean) : Boolean;
var
  Func, P, Old : Cardinal;
  B, H         : String;
  N            : Integer;
  sBuf         : String;
begin
  Result:=False;
  if Cst.ESENDPACKET=0 then Exit;
  if UOSel.HWnd=0 then Exit;
  if (HookWnd=UOSel.HWnd) and (HookPage<>0) then Exit(True);
  Func:=Cst.ESENDPACKET;
  SetLength(B,16);
  if not ReadMem(UOSel.HProc,Func,@B[1],16) then Exit;
  P:=HookPageOf(Func,B);
  if P<>0 then
  begin
    SetLength(H,$20);
    if ReadMem(UOSel.HProc,P,@H[1],$20) and HookHeaderIsOurs(H,Func) then
    begin
      HookWnd:=UOSel.HWnd;
      HookPage:=P;
      Result:=True;
    end;
    Exit;                                                  // a jmp that is not ours: leave it alone
  end;
  if not Install then Exit;
  N:=HookPrologueLength(B);
  if N=0 then Exit;
  InitEvents;
  if BaseAddr=0 then Exit;                                 // the install runs in the event cave
  P:=Cardinal(PtrUInt(VirtualAllocEx(UOSel.HProc,nil,HOOK_PAGE,MEM_RESERVE or MEM_COMMIT,PAGE_EXECUTE_READWRITE)));
  if P=0 then Exit;
  H:=HookHeader(Func,Copy(B,1,N))+NumStr(0,4,True)+NumStr(0,4,True);
  if not WriteMem(UOSel.HProc,P,@H[1],Length(H)) then Exit;
  sBuf:=SendHookCode(P,Func,Copy(B,1,N));
  if not WriteMem(UOSel.HProc,P+HOOK_CODE,@sBuf[1],Length(sBuf)) then Exit;
  Old:=0;
  if not VirtualProtectEx(UOSel.HProc,Pointer(PtrUInt(Func)),16,PAGE_EXECUTE_READWRITE,@Old) then Exit;
  sBuf:=SendHookInstallCode(Func,P,N);
  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#1#0,2);                 // Start Event!
  WaitTillProcessed;
  if ReadMem(UOSel.HProc,Func,@B[1],5) and (HookPageOf(Func,B)=P) then
  begin
    FlushInstructionCache(UOSel.HProc,Pointer(PtrUInt(Func)),16);
    VirtualProtectEx(UOSel.HProc,Pointer(PtrUInt(Func)),16,Old,@Old);
    HookWnd:=UOSel.HWnd;
    HookPage:=P;
    Result:=True;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOEvent.GumpHookRead(out Count : Cardinal; out Packet : String) : Boolean;
var
  C2, L : Cardinal;
  Try_  : Integer;
begin
  Result:=False;
  Count:=0;
  Packet:='';
  if not GumpHookActive(False) then Exit;
  for Try_:=1 to 3 do
  begin
    if not ReadMem(UOSel.HProc,HookPage+HOOK_COUNT,@Count,4) then Exit;
    L:=0;
    ReadMem(UOSel.HProc,HookPage+HOOK_LEN,@L,4);
    if L>HOOK_MAX then L:=0;
    SetLength(Packet,L);
    if L>0 then ReadMem(UOSel.HProc,HookPage+HOOK_BUF,@Packet[1],L);
    C2:=0;
    ReadMem(UOSel.HProc,HookPage+HOOK_COUNT,@C2,4);
    if C2=Count then Exit(True);                           // not changed while it was read
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOEvent.FindID(ID : Cardinal) : Cardinal;
var
  cBuf    : Cardinal;
  cBuf2   : Cardinal;
begin
  Result:=0;                                               //
  cBuf:=Cst.CHARPTR-(Cst.BITEMID+$C);                      // Find item
  repeat                                                   //
    ReadMem(UOSel.HProc,cBuf+Cst.BITEMID+$C,@cBuf,4);      //
    if cBuf=0 then Exit;                                   //
    ReadMem(UOSel.HProc,cBuf+Cst.BITEMID,@cBuf2,4);        //
  until cBuf2=ID;                                          //
  Result:=cBuf;                                            //
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ExEv_Drag(ID : Cardinal; Amount : Cardinal = 1);
var
  cBuf : Cardinal;
begin
  cBuf:=FindID(ID);                                        //
  if cBuf=0 then Exit;                                     //
  DragID:=ID;                                              //
  ReadMem(UOSel.HProc,cBuf+Cst.BITEMTYPE,@DragType,2);     //

  SendExEvent(                                             // ***Drag Packet***
    #7+                                                    // Cmd
    NumStr(ID,4,False)+                                    // ID
    NumStr(Amount,2,False));                               // Amount
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ExEv_DropC(ContID : Cardinal; X : Integer = -1; Y : Integer = -1);
var
  Fix : String;
begin
  Fix:=#0;
  if Cst.BPACKETVER>0 then Fix:=#0#255;

  if (X<0)or(Y<0) then
  begin
    X:=-1;
    Y:=-1;
  end;
  SendExEvent(                                             // ***Drop Packet***
    #8+                                                    // Cmd
    NumStr(DragID,4,False)+                                // ID
    NumStr(X,2,False)+                                     // X
    NumStr(Y,2,False)+                                     // Y
    Fix+                                                   // Z
    NumStr(ContID,4,False));                               // ContID
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ExEv_DropG(X,Y : Cardinal; Z : Integer = -1000);
var
  Fix : String;
begin
  if Z=-1000 then Z:=UOVar.CharPosZ;

  Fix:=Char(Z);
  if Cst.BPACKETVER>0 then
    Fix:=Fix+Char(Hi(Z));

  SendExEvent(                                             // ***Drop Packet***
    #8+                                                    // Cmd
    NumStr(DragID,4,False)+                                // ID
    NumStr(X,2,False)+                                     // X
    NumStr(Y,2,False)+                                     // Y
    Fix+                                                   // Z
    #255#255#255#255);                                     //
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ExEv_DropPD;
var
  Layer : Byte;
begin
  Layer:=GetWearableLayer(DragType);                       // Get ItemLayer
  if Layer=0 then Exit;                                    //

  SendExEvent(                                             // ***Drop Packet***
    #19+                                                   // Cmd
    NumStr(DragID,4,False)+                                // ID
    Char(Layer)+                                           // Layer
    NumStr(UOVar.CharID,4,False));                         // CharID
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ExEv_SkillLock(SkillStr : String; Lock : Cardinal);
var
  Cnt     : Integer;
begin
  if Lock>2 then Exit;
  SkillStr:=Copy(UpperCase(SkillStr),1,4);

  Cnt:=0;
  if not(SkillStr='ALL') then
  begin
    Cnt:=SkillFind(0,High(SkillList),SkillStr,SkillList);
    if Cnt<0 then Exit;
    Cnt:=SkillList[Cnt].Code;
  end;

  repeat
    WriteMem(UOSel.HProc,Cst.SKILLLOCK+Cnt,@Lock,1);         // Set client lock

    SendExEvent(                                             // ***SkillLock Packet***
      #58+                                                   // Cmd
      #06#00+                                                // Len
      NumStr(Cnt,2,False)+                                   // Skill
      Char(Lock));                                           // Lock

    Inc(Cnt);
  until (Cnt>High(SkillList)) or not (SkillStr='ALL');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ExEv_StatLock(Stat : String; Lock : Cardinal);
var
  Cnt     : Integer;
begin
  if Lock>2 then Exit;
  Stat:=UpperCase(Stat);
  InitEvents;

  Cnt:=-1;
  if Stat='STR' then Cnt:=0;
  if Stat='DEX' then Cnt:=1;
  if Stat='INT' then Cnt:=2;
  if Cnt<0 then Exit;

  SendExEvent(                                             // ***StatLock Packet***
    #191+                                                  // Cmd
    #07#00+                                                // Len
    #00#26+                                                // SubCmd
    Char(Cnt)+                                             // Stat
    Char(Lock));                                           // Lock
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ExEv_RenamePet(ID : Cardinal; Name : String);
var
  Cnt     : Integer;
begin
  if Name='' then Exit;                                    //
  if FindID(ID)=0 then Exit;                               //
  for Cnt:=Length(Name) to 29 do Name:=Name+#0;            //

  SendExEvent(                                             //
    #117+                                                  // Cmd
    NumStr(ID,4,False)+                                    // ID
    Name);                                                 // Name
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ExEv_PopUp(ID : Cardinal; X,Y : Integer);
var
  i : Integer;
  c : Cardinal;
  w : Word;
begin
  c:=FindID(ID);
  if c=0 then Exit;

  if Cst.POPUPID=0 then Exit;
  WriteMem(UOSel.HProc,Cst.POPUPID-8,
    PChar(NumStr(X,4,True)+NumStr(Y,4,True)+NumStr(ID,4,True)),12);

  SendExEvent(                                           // ***PopUp Packet***
    #191+                                                // Cmd
    #9#0+                                                // Len
    #0#19+                                               // SubCmd
    NumStr(ID,4,False));                                 // ID
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.ExEv_Custom(Packet : String);
begin
  SendExEvent(Packet);
end;

////////////////////////////////////////////////////////////////////////////////
end.
