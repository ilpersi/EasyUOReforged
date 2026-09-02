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
}

{$mode delphi}{$H+}

interface
uses Windows, SysUtils, access, uotypes, uocommands, uovariables, uoselector,
     uoclidata, wearables;

type
  TUOEvent      = class(TObject)
  private
    UOSel        : TUOSel;
    UOVar        : TUOVar;
    Cst          : TCstDB;
    BaseAddr     : Cardinal;
    InitEventWnd : Cardinal;
    DragID       : Cardinal;
    DragType     : Cardinal;
    Delay        : TDelayFunc;
    procedure    InitEvents;
    function     ReplaceStr(Str,RepWhat,RepWith : String) : String;
    function     GetFormStr(StrAddr : Cardinal) : String;
    function     FindID(ID : Cardinal) : Cardinal;
    procedure    SendExEvent(Packet : String);
    procedure    WaitTillProcessed;
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
  end;

implementation

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
  BaseAddr:=$400600;
  VirtualProtectEx(
    UOSel.HProc,
    Pointer($400000),
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
procedure TUOEvent.ExMsg(ID,Font,Color : Cardinal; Msg : String);
var
  cBuf : Cardinal;
  sBuf : String;
begin
  InitEvents;

  Msg:=Msg+#0;                                             // Write text buffer
  WriteMem(UOSel.HProc,BaseAddr+$70,@Msg[1],Length(Msg));

  cBuf:=FindID(ID);
  if cBuf=0 then Exit;

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

    WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
    WriteMem(UOSel.HProc,BaseAddr-4,#2#0#1#0,4);        // Start Event!
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.Pathfind(X,Y : Cardinal; Z : Integer);
var
  sBuf : String;
begin
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
  sBuf  : String;
  cBuf  : Cardinal;
  cBuf2 : Cardinal;
begin
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

  sBuf:=                                                   //
    #104#0#0#0#0+                                          // push 0
    #104+NumStr(cBuf,4,True);                              // push PtrOnItem

  sBuf:=sBuf+                                              //
    #104+NumStr(BaseAddr+Length(sBuf)+$2B,4,True)+         // push below ret
    #104+NumStr(Cst.EDRAGADDR,4,True)+                     // push Proc
    #195+                                                  // ret
    #131#196+Char(8)+                                      // add esp, 8
    #195;                                                  // ret

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#1#0,2);                 // Start Event!
  WaitTillProcessed;                                       // Wait
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOEvent.SysMessage(Msg : String; Col : Cardinal);
var
  sBuf  : String;
begin
  InitEvents;

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

  sBuf:=                                                   //
    #104#0#0#0#0+                                          // push 0
    #104+NumStr(BaseAddr+$70,4,True);                      // push 00800070

  sBuf:=sBuf+                                              //
    #104+NumStr(BaseAddr+Length(sBuf)+$2B,4,True)+         // push below ret
    #104+NumStr(Cst.EMACROADDR,4,True)+                    // push Proc
    #195+                                                  // ret
    #131#196+Char(8)+                                      // add esp, 8
    #195;                                                  // ret

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
  InitEvents;

  sBuf:=
    #186+NumStr(BaseAddr+$FE+2*W*H,4,True)+                // mov   edx, _P_
    #191+NumStr(H,4,True)+                                 // mov   edi, _H_
                                                           // loop1:
    #79+                                                   // dec   edi
    #120#66+                                               // js    ende
    #139#53+NumStr(BaseAddr+$78,4,True)+                   // mov   esi, W
                                                           // loop2:
    #78+                                                   // dec   esi
    #120#244+                                              // js    loop1

    #96+                                                   // pushad
    #104+NumStr(BaseAddr+$7C,4,True)+                      // push  @T
    #106#0+                                                // push  0
    #104+NumStr(Z,4,True)+                                 // push  _Z_
    #161+NumStr(BaseAddr+$74,4,True)+                      // mov   eax, Y
    #1#248+                                                // add   eax, edi
    #80+                                                   // push  eax
    #161+NumStr(BaseAddr+$70,4,True)+                      // mov   eax, X
    #1#240+                                                // add   eax, esi
    #80+                                                   // push  eax
    #104+NumStr(BaseAddr+$5E,4,True)+                      // push  weiter
    #104+NumStr(Cst.BLOCKINFO,4,True)+                           // push  func
    #195+                                                  // ret
                                                           // weiter:
    #131#196#20+                                           // add   esp, 14h
    #97+                                                   // popad

    #161+NumStr(BaseAddr+$7C,4,True)+                      // mov   eax, T
    #102#137#2+                                            // mov   [edx], ax
    #131#234#2+                                            // sub   edx, 2
    #235#196+                                              // jmp   loop2
                                                           // ende:
    #195+                                                  // ret
    NumStr(X,4,True)+                                      // dd    X
    NumStr(Y,4,True)+                                      // dd    Y
    NumStr(W,4,True)+                                      // dd    W
    #0#0#0#0;                                              // dd    T

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#01#00,2);               // Start Event!
  WaitTillProcessed;                                       // Wait

  SetLength(BlockStr,W*H*2);
  ReadMem(UOSel.HProc,BaseAddr+$100,@BlockStr[1],W*H*2);
end;

////////////////////////////////////////////////////////////////////////////////
/// ExEvents ///////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TUOEvent.SendExEvent(Packet : String);
var
  sBuf : String;
begin
  InitEvents;                                              // Init Ex-/Events

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
    #131#196#4+                                            // add esp, 4
    #195+                                                  // ret
    Packet;                                                // (Packet)

  WriteMem(UOSel.HProc,BaseAddr+$20,@sBuf[1],Length(sBuf));
  WriteMem(UOSel.HProc,BaseAddr-2,#1#0,2);                 // Start Event!

  WaitTillProcessed;                                       // Wait
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
