unit uowrap;

{
  Ported from the original Delphi 7 uo\uowrap.pas (read in full, 654 lines).
  TUOWrap is the generic, stack-based dispatch layer that uo.dll exports:
  the 140-entry UOTbl (name -> RO/RW/ME + numeric code + parameter-type-mask
  binary search table, via tables.pas's Find_First/Find_Next/Check already
  ported in Phase 1) plus MGet/MSet/MCall/MType/MHelp/Query/Execute and the
  embedded Lua bootstrap string (InitString) for the shelved Lua front-end
  this generic layer was originally built for.

  Ported byte-for-byte: every UOTbl row, every case-label mapping, the exact
  RES_OK/ERR_NOTFOUND/ERR_WRONGPAR/ERR_GENERIC error codes and ErrStrings
  table, MDelay's save-stack/restore-stack dance around the external
  DelayProc callback (a genuine "leaving the DLL" reentrancy hazard the
  original's own comment calls out, preserved as-is), and InitString's exact
  text. No bitness-sensitive code lives in this unit -- DelayProc's Pointer-
  typed assignment and PChar/Cardinal parameters are all already correctly
  widthed regardless of host bitness. The one place this DLL's ABI needed a
  real fix for a 64-bit host (the Integer-sized object handle in
  Open/Close/Query/etc.) lives in uodef.pas, not here -- see that unit's
  header comment.

  Port addition (not in the original): UOTbl's methods 057..066 (GetPath, PathCan, PathCheck,
  PathSet, PathBlock, PathUnblock, PathAvoid, PathLink, PathClear), the pathfinder's PATH FIND /
  CAN / CHECK / SET and rules for external programs (docs\pathfinding.md, phase 4). They plan and
  check; they don't walk. The work is in TUOCmd (PathFindFrom, PathCanAt, PathPacked,
  PathSetOption) and TUOEvent.StepInfo; MCall only reads the stack and pushes the answers. Their
  rows keep UOTbl in CompareStr order, as tables.pas's binary search needs.
}

{$mode delphi}{$H+}

interface
uses Windows, SysUtils, access, uotypes, stack, tables, uoselector,
     uovariables, uocommands, uoevents, walkrules, pathplan;

type
  TUOWrap      = class(TObject)
  private
    UOSel       : TUOSel;
    UOVar       : TUOVar;
    UOCmd       : TUOCmd;
    UOEvent     : TUOEvent;
    DelayInfo   : Pointer;
    DelayProc   : function(Duration : Cardinal; Info : Pointer) : Boolean; stdcall;
    function    MGet(Name : String) : Integer;
    function    MSet(Name : String) : Integer;
    function    MCall(Name : String) : Integer;
    function    MType(Name : String) : Integer;
    function    MDelay(Duration : Cardinal) : Boolean;
    function    MHelp : Integer;
  public
    Stack       : TStack;
    constructor Create;
    procedure   Free;
    function    Query : Integer;
    function    Execute : Integer;
  end;

implementation

const
  RES_OK       = -00;
  ERR_NOTFOUND = -01;
  ERR_WRONGPAR = -02;
  ERR_GENERIC  = -03;

  ErrStrings   : array[-03..00] of PChar = (
    'ERR_GENERIC',  //-03
    'ERR_WRONGPAR', //-02
    'ERR_NOTFOUND', //-01
    'RES_OK'        //-00
  );

  InitString   : PChar =
    ' local exec = ...'+
    ' local function ge(...) return exec("Get",...) end'+
    ' local function se(...) return exec("Set",...) end'+
    ' local function ca(...) return exec("Call",...) end'+
    ' local function ty(...) return exec("Type",...) end'+
    ' local function he(...) return exec("Help",...) end'+
    ' local mt = {'+
    '   __index = function(t,k)'+
    '     if ty(k)==3 then'+
    '       return function(...) return ca(k,...) end'+
    '     end'+
    '     return ge(k)'+
    '   end,'+
    '   __newindex = function(t,k,v)'+
    '     se(k,v)'+
    '   end,'+
    '   __help = he,'+
    ' }'+
    ' UO = setmetatable({},mt)'+
    ' return nil';


////////////////////////////////////////////////////////////////////////////////
/// Tables /////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

var
  UOTbl : array[0..168] of TItem = (
    (N: 'AR'          ;T: RO ;C: 206 ;P: 'n'        ),
    (N: 'BackpackID'  ;T: RO ;C: 224 ;P: 'n'        ),
    (N: 'BlockInfo'   ;T: ME ;C: 041 ;P: 'nnnnn'    ),
    (N: 'BuffBarOpen' ;T: RO ;C: 255 ;P: 'b'        ),
    (N: 'CR'          ;T: RO ;C: 212 ;P: 'n'        ),
    (N: 'CharDir'     ;T: RO ;C: 207 ;P: 'n'        ),
    (N: 'CharID'      ;T: RO ;C: 204 ;P: 'n'        ),
    (N: 'CharName'    ;T: RO ;C: 240 ;P: 's'        ),
    (N: 'CharPosX'    ;T: RO ;C: 246 ;P: 'n'        ),
    (N: 'CharPosY'    ;T: RO ;C: 232 ;P: 'n'        ),
    (N: 'CharPosZ'    ;T: RO ;C: 223 ;P: 'n'        ),
    (N: 'CharStatus'  ;T: RO ;C: 237 ;P: 's'        ),
    (N: 'CharType'    ;T: RO ;C: 201 ;P: 'n'        ),
    (N: 'CliCnt'      ;T: RO ;C: 247 ;P: 'n'        ),
    (N: 'CliDrag'     ;T: ME ;C: 012 ;P: 'n'        ),
    (N: 'CliLang'     ;T: RO ;C: 214 ;P: 's'        ),
    (N: 'CliLeft'     ;T: RW ;C: 199 ;P: 'n'        ),
    (N: 'CliLogged'   ;T: RO ;C: 211 ;P: 'b'        ),
    (N: 'CliNr'       ;T: RW ;C: 198 ;P: 'n'        ),
    (N: 'CliTitle'    ;T: RW ;C: 177 ;P: 's'        ),
    (N: 'CliTop'      ;T: RW ;C: 197 ;P: 'n'        ),
    (N: 'CliVer'      ;T: RO ;C: 205 ;P: 's'        ),
    (N: 'CliXRes'     ;T: RW ;C: 196 ;P: 'n'        ),
    (N: 'CliYRes'     ;T: RW ;C: 195 ;P: 'n'        ),
    (N: 'Click'       ;T: ME ;C: 003 ;P: 'nnnbbbbb' ),
     (N: 'Click'      ;T: ME ;C: 045 ;P: 'nn'       ),
     (N: 'Click'      ;T: ME ;C: 046 ;P: 'nnn'      ),
     (N: 'Click'      ;T: ME ;C: 047 ;P: 'nnnb'     ),
     (N: 'Click'      ;T: ME ;C: 048 ;P: 'nnnbbb'   ),
     (N: 'Click'      ;T: ME ;C: 049 ;P: 'nnbbbb'   ), //deprecated, for compatibility only!
    (N: 'CloseClient' ;T: ME ;C: 051 ;P: ''         ),
    (N: 'ContID'      ;T: RO ;C: 229 ;P: 'n'        ),
    (N: 'ContKind'    ;T: RO ;C: 238 ;P: 'n'        ),
    (N: 'ContName'    ;T: RO ;C: 220 ;P: 's'        ),
    (N: 'ContPosX'    ;T: RW ;C: 194 ;P: 'n'        ),
    (N: 'ContPosY'    ;T: RW ;C: 193 ;P: 'n'        ),
    (N: 'ContSizeX'   ;T: RO ;C: 213 ;P: 'n'        ),
    (N: 'ContSizeY'   ;T: RO ;C: 216 ;P: 'n'        ),
    (N: 'ContTop'     ;T: ME ;C: 033 ;P: 'n'        ),
    (N: 'ContType'    ;T: RO ;C: 236 ;P: 'n'        ),
    (N: 'CursKind'    ;T: RO ;C: 251 ;P: 'n'        ),
    (N: 'CursorX'     ;T: RO ;C: 253 ;P: 'n'        ),
    (N: 'CursorY'     ;T: RO ;C: 254 ;P: 'n'        ),
    (N: 'Custom'      ;T: ME ;C: 038 ;P: 's'        ),
    (N: 'Dex'         ;T: RO ;C: 202 ;P: 'n'        ),
    (N: 'Drag'        ;T: ME ;C: 015 ;P: 'nn'       ),
     (N:'Drag'        ;T: ME ;C: 015 ;P: 'n'        ),
    (N: 'DropC'       ;T: ME ;C: 016 ;P: 'nnn'      ),
     (N:'DropC'       ;T: ME ;C: 016 ;P: 'n'        ),
    (N: 'DropG'       ;T: ME ;C: 017 ;P: 'nnn'      ),
     (N:'DropG'       ;T: ME ;C: 017 ;P: 'nn'       ),
    (N: 'DropPD'      ;T: ME ;C: 028 ;P: ''         ),
    (N: 'ER'          ;T: RO ;C: 221 ;P: 'n'        ),
    (N: 'EnemyHits'   ;T: RO ;C: 249 ;P: 'n'        ),
    (N: 'EnemyID'     ;T: RO ;C: 241 ;P: 'n'        ),
    (N: 'Equip'       ;T: ME ;C: 037 ;P: '*'        ),
    (N: 'ExMsg'       ;T: ME ;C: 009 ;P: 'nnns'     ),
     (N:'ExMsg'       ;T: ME ;C: 039 ;P: 'ns'       ),
    (N: 'FR'          ;T: RO ;C: 225 ;P: 'n'        ),
    (N: 'FilterItems' ;T: ME ;C: 042 ;P: 'nn'       ),
     (N:'FilterItems' ;T: ME ;C: 043 ;P: 'n'        ),
    (N: 'Followers'   ;T: RO ;C: 203 ;P: 'n'        ),
    (N: 'GetBuff'     ;T: ME ;C: 056 ;P: 'n'        ),
    (N: 'GetCont'     ;T: ME ;C: 032 ;P: 'n'        ),
    (N: 'GetItem'     ;T: ME ;C: 024 ;P: 'n'        ),
    (N: 'GetJournal'  ;T: ME ;C: 027 ;P: 'n'        ),
    (N: 'GetPath'     ;T: ME ;C: 057 ;P: 'nnnnnnn'  ),    // port addition (the pathfinder)
     (N: 'GetPath'    ;T: ME ;C: 057 ;P: 'nnn'      ),
     (N: 'GetPath'    ;T: ME ;C: 057 ;P: 'nn'       ),
    (N: 'GetPix'      ;T: ME ;C: 008 ;P: 'nn'       ),
    (N: 'GetShop'     ;T: ME ;C: 034 ;P: ''         ),
    (N: 'GetSkill'    ;T: ME ;C: 007 ;P: 's'        ),
    (N: 'Gold'        ;T: RO ;C: 242 ;P: 'n'        ),
    (N: 'HideItem'    ;T: ME ;C: 025 ;P: 'n'        ),
    (N: 'Hits'        ;T: RO ;C: 208 ;P: 'n'        ),
    (N: 'IgnoreCont'  ;T: ME ;C: 052 ;P: 's'        ),
     (N:'IgnoreCont'  ;T: ME ;C: 053 ;P: 'n'        ),
    (N: 'Int'         ;T: RO ;C: 234 ;P: 'n'        ),
    (N: 'Key'         ;T: ME ;C: 004 ;P: 'sbbb'     ),
     (N:'Key'         ;T: ME ;C: 004 ;P: 's'        ),
    (N: 'LHandID'     ;T: RW ;C: 192 ;P: 'n'        ),
    (N: 'LLiftedID'   ;T: RO ;C: 217 ;P: 'n'        ),
    (N: 'LLiftedKind' ;T: RO ;C: 230 ;P: 'n'        ),
    (N: 'LLiftedType' ;T: RO ;C: 200 ;P: 'n'        ),
    (N: 'LObjectID'   ;T: RW ;C: 191 ;P: 'n'        ),
    (N: 'LObjectType' ;T: RO ;C: 252 ;P: 'n'        ),
    (N: 'LShard'      ;T: RW ;C: 190 ;P: 'n'        ),
    (N: 'LSkill'      ;T: RW ;C: 189 ;P: 'n'        ),
    (N: 'LSpell'      ;T: RW ;C: 188 ;P: 'n'        ),
    (N: 'LTargetID'   ;T: RW ;C: 187 ;P: 'n'        ),
    (N: 'LTargetKind' ;T: RW ;C: 186 ;P: 'n'        ),
    (N: 'LTargetTile' ;T: RW ;C: 185 ;P: 'n'        ),
    (N: 'LTargetX'    ;T: RW ;C: 184 ;P: 'n'        ),
    (N: 'LTargetY'    ;T: RW ;C: 183 ;P: 'n'        ),
    (N: 'LTargetZ'    ;T: RW ;C: 182 ;P: 'n'        ),
    (N: 'Luck'        ;T: RO ;C: 231 ;P: 'n'        ),
    (N: 'Macro'       ;T: ME ;C: 014 ;P: 'nns'      ),
     (N:'Macro'       ;T: ME ;C: 014 ;P: 'nn'       ),
    (N: 'Mana'        ;T: RO ;C: 215 ;P: 'n'        ),
    (N: 'MaxDmg'      ;T: RO ;C: 226 ;P: 'n'        ),
    (N: 'MaxFol'      ;T: RO ;C: 209 ;P: 'n'        ),
    (N: 'MaxHits'     ;T: RO ;C: 222 ;P: 'n'        ),
    (N: 'MaxMana'     ;T: RO ;C: 233 ;P: 'n'        ),
    (N: 'MaxStam'     ;T: RO ;C: 210 ;P: 'n'        ),
    (N: 'MaxStats'    ;T: RO ;C: 235 ;P: 'n'        ),
    (N: 'MaxWeight'   ;T: RO ;C: 239 ;P: 'n'        ),
    (N: 'MinDmg'      ;T: RO ;C: 244 ;P: 'n'        ),
    (N: 'Move'        ;T: ME ;C: 005 ;P: 'nnnn'     ),
     (N:'Move'        ;T: ME ;C: 005 ;P: 'nnn'      ),
     (N:'Move'        ;T: ME ;C: 005 ;P: 'nn'       ),
    (N: 'Msg'         ;T: ME ;C: 006 ;P: 's'        ),
    (N: 'NextCPosX'   ;T: RW ;C: 181 ;P: 'n'        ),
    (N: 'NextCPosY'   ;T: RW ;C: 180 ;P: 'n'        ),
    (N: 'OpenClient'  ;T: ME ;C: 050 ;P: 'b'        ),
    (N: 'PR'          ;T: RO ;C: 248 ;P: 'n'        ),
    (N: 'PathAvoid'   ;T: ME ;C: 064 ;P: 'nnnnnn'   ),    // port addition (the pathfinder)
     (N: 'PathAvoid'  ;T: ME ;C: 064 ;P: 'nnnnn'    ),
    (N: 'PathBlock'   ;T: ME ;C: 062 ;P: 'nnnnn'    ),
     (N: 'PathBlock'  ;T: ME ;C: 062 ;P: 'nnnn'     ),
     (N: 'PathBlock'  ;T: ME ;C: 062 ;P: 'nnn'      ),
     (N: 'PathBlock'  ;T: ME ;C: 062 ;P: 'nn'       ),
    (N: 'PathCan'     ;T: ME ;C: 058 ;P: 'nnn'      ),
     (N: 'PathCan'    ;T: ME ;C: 058 ;P: 'nn'       ),
    (N: 'PathCheck'   ;T: ME ;C: 059 ;P: 'nnnn'     ),
     (N: 'PathCheck'  ;T: ME ;C: 059 ;P: 'nnn'      ),
     (N: 'PathCheck'  ;T: ME ;C: 059 ;P: 'nn'       ),
    (N: 'PathClear'   ;T: ME ;C: 066 ;P: 's'        ),
     (N: 'PathClear'  ;T: ME ;C: 066 ;P: ''         ),
    (N: 'PathLink'    ;T: ME ;C: 065 ;P: 'nnnnnnnn' ),
     (N: 'PathLink'   ;T: ME ;C: 065 ;P: 'nnnnnnn'  ),
     (N: 'PathLink'   ;T: ME ;C: 065 ;P: 'nnnnnn'   ),
    (N: 'PathSet'     ;T: ME ;C: 060 ;P: 'sn'       ),
     (N: 'PathSet'    ;T: ME ;C: 061 ;P: 'ss'       ),
    (N: 'PathUnblock' ;T: ME ;C: 063 ;P: 'nnnnn'    ),
     (N: 'PathUnblock';T: ME ;C: 063 ;P: 'nnnn'     ),
     (N: 'PathUnblock';T: ME ;C: 063 ;P: 'nnn'      ),
     (N: 'PathUnblock';T: ME ;C: 063 ;P: 'nn'       ),
    (N: 'Pathfind'    ;T: ME ;C: 011 ;P: 'nnn'      ),
     (N: 'Pathfind'   ;T: ME ;C: 011 ;P: 'nn'       ),
    (N: 'Popup'       ;T: ME ;C: 036 ;P: 'nnn'      ),
     (N: 'Popup'      ;T: ME ;C: 036 ;P: 'n'        ),
    (N: 'Property'    ;T: ME ;C: 010 ;P: 'n'        ),
    (N: 'RHandID'     ;T: RW ;C: 179 ;P: 'n'        ),
    (N: 'RenamePet'   ;T: ME ;C: 020 ;P: 'ns'       ),
    (N: 'ScanBuffs'   ;T: ME ;C: 054 ;P: 'n'        ),
     (N:'ScanBuffs'   ;T: ME ;C: 055 ;P: ''         ),
    (N: 'ScanItems'   ;T: ME ;C: 023 ;P: 'b'        ),
     (N:'ScanItems'   ;T: ME ;C: 044 ;P: ''         ),
    (N: 'ScanJournal' ;T: ME ;C: 026 ;P: 'n'        ),
    (N: 'SetShop'     ;T: ME ;C: 035 ;P: 'nn'       ),
    (N: 'Sex'         ;T: RO ;C: 243 ;P: 'n'        ),
    (N: 'Shard'       ;T: RO ;C: 218 ;P: 's'        ),
    (N: 'SkillLock'   ;T: ME ;C: 018 ;P: 'sn'       ),
    (N: 'Stamina'     ;T: RO ;C: 245 ;P: 'n'        ),
    (N: 'StatBar'     ;T: ME ;C: 040 ;P: 'n'        ),
    (N: 'StatLock'    ;T: ME ;C: 019 ;P: 'sn'       ),
    (N: 'Str'         ;T: RO ;C: 227 ;P: 'n'        ),
    (N: 'SysMessage'  ;T: ME ;C: 013 ;P: 'sn'       ),
     (N:'SysMessage'  ;T: ME ;C: 013 ;P: 's'        ),
    (N: 'SysMsg'      ;T: RO ;C: 219 ;P: 's'        ),
    (N: 'TP'          ;T: RO ;C: 250 ;P: 'n'        ),
    (N: 'TargCurs'    ;T: RW ;C: 178 ;P: 'b'        ),
    (N: 'TileCnt'     ;T: ME ;C: 030 ;P: 'nnn'      ),
     (N:'TileCnt'     ;T: ME ;C: 030 ;P: 'nn'       ),
    (N: 'TileGet'     ;T: ME ;C: 031 ;P: 'nnnn'     ),
     (N:'TileGet'     ;T: ME ;C: 031 ;P: 'nnn'      ),
    (N: 'TileInit'    ;T: ME ;C: 029 ;P: 'b'        ),
     (N:'TileInit'    ;T: ME ;C: 029 ;P: ''         ),
    (N: 'Weight'      ;T: RO ;C: 228 ;P: 'n'        )
  );

////////////////////////////////////////////////////////////////////////////////
/// Main ///////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////


function TUOWrap.MGet(Name : String) : Integer;
var
  Res : TFindRes;
begin
  Result:=RES_OK;
  Find_First(Res,Name,UOTbl);
  with Stack,UOVar,UOSel do
  case Check(Res,Stack,3,[RO,RW]) of
    177: PushStrVal(PChar(CliTitle));
    178: PushBoolean(TargCurs);
    179: PushInteger(RHandID);
    180: PushInteger(NextCPosY);
    181: PushInteger(NextCPosX);
    182: PushInteger(LTargetZ);
    183: PushInteger(LTargetY);
    184: PushInteger(LTargetX);
    185: PushInteger(LTargetTile);
    186: PushInteger(LTargetKind);
    187: PushInteger(LTargetID);
    188: PushInteger(LSpell);
    189: PushInteger(LSkill);
    190: PushInteger(LShard);
    191: PushInteger(LObjectID);
    192: PushInteger(LHandID);
    193: PushInteger(ContPosY);
    194: PushInteger(ContPosX);
    195: PushInteger(CliYRes);
    196: PushInteger(CliXRes);
    197: PushInteger(CliTop);
    198: PushInteger(Nr);
    199: PushInteger(CliLeft);
    200: PushInteger(LLiftedType);
    201: PushInteger(CharType);
    202: PushInteger(Dex);
    203: PushInteger(Followers);
    204: PushInteger(CharID);
    205: PushStrVal(PChar(CliVer));
    206: PushInteger(AR);
    207: PushInteger(CharDir);
    208: PushInteger(Hits);
    209: PushInteger(MaxFol);
    210: PushInteger(MaxStam);
    211: PushBoolean(CliLogged);
    212: PushInteger(CR);
    213: PushInteger(ContSizeX);
    214: PushStrVal(PChar(CliLang));
    215: PushInteger(Mana);
    216: PushInteger(ContSizeY);
    217: PushInteger(LLiftedID);
    218: PushStrVal(PChar(Shard));
    219: PushStrVal(PChar(SysMsg));
    220: PushStrVal(PChar(ContName));
    221: PushInteger(ER);
    222: PushInteger(MaxHits);
    223: PushInteger(CharPosZ);
    224: PushInteger(BackpackID);
    225: PushInteger(FR);
    226: PushInteger(MaxDmg);
    227: PushInteger(Str);
    228: PushInteger(Weight);
    229: PushInteger(ContID);
    230: PushInteger(LLiftedKind);
    231: PushInteger(Luck);
    232: PushInteger(CharPosY);
    233: PushInteger(MaxMana);
    234: PushInteger(Int);
    235: PushInteger(MaxStats);
    236: PushInteger(ContType);
    237: PushStrVal(PChar(CharStatus));
    238: PushInteger(ContKind);
    239: PushInteger(MaxWeight);
    240: PushStrVal(PChar(CharName));
    241: PushInteger(EnemyID);
    242: PushInteger(Gold);
    243: PushInteger(Sex);
    244: PushInteger(MinDmg);
    245: PushInteger(Stamina);
    246: PushInteger(CharPosX);
    247: PushInteger(Cnt);
    248: PushInteger(PR);
    249: PushInteger(EnemyHits);
    250: PushInteger(TP);
    251: PushInteger(CursKind);
    252: PushInteger(LObjectType);
    253: PushInteger(CursorX);
    254: PushInteger(CursorY);
    255: PushBoolean(UOCmd.BuffBarOpen);          // port addition; False also when unsupported
    -01: Result:=ERR_NOTFOUND;
    -02: Result:=ERR_WRONGPAR;
    else Result:=ERR_GENERIC;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOWrap.MSet(Name : String) : Integer;
var
  Res : TFindRes;
begin
  Result:=RES_OK;
  Find_First(Res,Name,UOTbl);
  with Stack,UOVar,UOSel do
  case Check(Res,Stack,3,[RW,PA]) of
    177: CliTitle:=GetString(3);
    178: TargCurs:=GetBoolean(3);
    179: RHandID:=GetInteger(3);
    180: NextCPosY:=GetInteger(3);
    181: NextCPosX:=GetInteger(3);
    182: LTargetZ:=GetInteger(3);
    183: LTargetY:=GetInteger(3);
    184: LTargetX:=GetInteger(3);
    185: LTargetTile:=GetInteger(3);
    186: LTargetKind:=GetInteger(3);
    187: LTargetID:=GetInteger(3);
    188: LSpell:=GetInteger(3);
    189: LSkill:=GetInteger(3);
    190: LShard:=GetInteger(3);
    191: LObjectID:=GetInteger(3);
    192: LHandID:=GetInteger(3);
    193: ContPosY:=GetInteger(3);
    194: ContPosX:=GetInteger(3);
    195: CliYRes:=GetInteger(3);
    196: CliXRes:=GetInteger(3);
    197: CliTop:=GetInteger(3);
    198: SelectClient(GetInteger(3));
    199: CliLeft:=GetInteger(3);
    -01: Result:=ERR_NOTFOUND;
    -02: Result:=ERR_WRONGPAR;
    else Result:=ERR_GENERIC;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOWrap.MCall(Name : String) : Integer;
var
  Res : TFindRes;
  i   : Integer;
  s   : String;
  Q   : TStepChecks;

  // Port addition (the pathfinder): the facet a rule applies to, the character's when the call
  // gives none (stack position Index is past the top), 0 without a client.
  function RuleFacet(Index : Integer) : Integer;
  begin
    if Stack.GetTop>=Index then Result:=Stack.GetInteger(Index)
    else if UOSel.Nr>0 then Result:=UOVar.CursKind
    else Result:=0;
  end;

  // PathBlock / PathUnblock x y [x2 y2] [facet]
  procedure PathArea(Block : Boolean);
  var
    X2, Y2, F : Integer;
  begin
    X2:=Stack.GetInteger(3);
    Y2:=Stack.GetInteger(4);
    F:=RuleFacet(99);
    case Stack.GetTop of
      5: F:=Stack.GetInteger(5);
      6, 7: begin
              X2:=Stack.GetInteger(5);
              Y2:=Stack.GetInteger(6);
              F:=RuleFacet(7);
            end;
    end;
    if Block then UOCmd.PathPlanner.AddBlock(F,Stack.GetInteger(3),Stack.GetInteger(4),X2,Y2)
    else UOCmd.PathPlanner.RemoveBlocks(F,Stack.GetInteger(3),Stack.GetInteger(4),X2,Y2);
    Stack.PushStrVal('ok');
  end;

begin
  Result:=RES_OK;
  Find_First(Res,Name,UOTbl);
  with UOEvent,UOCmd,Stack do
  case Check(Res,Stack,3,[ME,PA]) of
    003: Click(GetInteger(3),GetInteger(4),GetInteger(5),GetBoolean(6),GetBoolean(7),GetBoolean(8),GetBoolean(9),GetBoolean(10));
    004: Key(GetString(3),GetBoolean(4),GetBoolean(5),GetBoolean(6));
    005: PushBoolean(Move(GetInteger(3),GetInteger(4),GetInteger(5),GetInteger(6)));
    006: Msg(GetString(3));
    007: begin
           GetSkill(GetString(3));
           PushInteger(SkillNorm);
           PushInteger(SkillReal);
           PushInteger(SkillCap);
           PushInteger(SkillLock);
         end;
    008: PushInteger(GetPix(GetInteger(3),GetInteger(4)));
    009: ExMsg(GetInteger(3),GetInteger(4),GetInteger(5),GetString(6));
    010: begin
           EvProperty(GetInteger(3));
           PushStrVal(PChar(PropStr1));
           PushStrVal(PChar(PropStr2));
         end;
    011: if GetTop=3 then Pathfind(GetInteger(3),GetInteger(4),GetInteger(5))
         else Pathfind(GetInteger(3),GetInteger(4),UOVar.CharPosZ);
    012: Drag(GetInteger(3));
    013: SysMessage(GetString(3),GetInteger(4));
    014: Macro(GetInteger(3),GetInteger(4),GetString(5));
    015: if GetTop=4 then ExEv_Drag(GetInteger(3),GetInteger(4))
         else ExEv_Drag(GetInteger(3));
    016: if GetTop=5 then ExEv_DropC(GetInteger(3),GetInteger(4),GetInteger(5))
         else ExEv_DropC(GetInteger(3));
    017: if GetTop=5 then ExEv_DropG(GetInteger(3),GetInteger(4),GetInteger(5))
         else ExEv_DropG(GetInteger(3),GetInteger(4));
    018: ExEv_SkillLock(GetString(3),GetInteger(4));
    019: ExEv_StatLock(GetString(3),GetInteger(4));
    020: ExEv_RenamePet(GetInteger(3),GetString(4));
    023: begin
           ScanItems(GetBoolean(3));
           PushInteger(ItemCnt);
         end;
    024: begin
           GetItem(GetInteger(3));
           PushInteger(ItemRes.ItemID);
           PushInteger(ItemRes.ItemType);
           PushInteger(ItemRes.ItemKind);
           PushInteger(ItemRes.ContID);
           PushInteger(ItemRes.ItemX);
           PushInteger(ItemRes.ItemY);
           PushInteger(ItemRes.ItemZ);
           PushInteger(ItemRes.ItemStack);
           PushInteger(ItemRes.ItemRep);
           PushInteger(ItemRes.ItemCol);
         end;
    025: HideItem(GetInteger(3));
    026: begin
           ScanJournal(GetInteger(3));
           PushInteger(JournalRef);
           PushInteger(JournalCnt);
         end;
    027: begin
           GetJournal(GetInteger(3));
           PushStrVal(PChar(JournalStr));
           PushInteger(JournalCol);
         end;
    028: ExEv_DropPD;
    029: PushBoolean(TileInit(GetBoolean(3)));
    030: if GetTop=5 then PushInteger(TileCnt(GetInteger(3),GetInteger(4),GetInteger(5)))
         else PushInteger(TileCnt(GetInteger(3),GetInteger(4)));
    031: begin
           if GetTop=6 then TileGet(GetInteger(3),GetInteger(4),GetInteger(5),GetInteger(6))
           else TileGet(GetInteger(3),GetInteger(4),GetInteger(5));
           PushInteger(TileType);
           PushInteger(TileZ);
           PushStrVal(PChar(TileName));
           PushInteger(TileFlags);
         end;
    032: if GetCont(GetInteger(3)) then
         begin
           PushStrVal(PChar(ContName));
           PushInteger(ContX);
           PushInteger(ContY);
           PushInteger(ContSX);
           PushInteger(ContSY);
           PushInteger(ContKind);
           PushInteger(ContID);
           PushInteger(ContType);
           PushInteger(ContHP);
         end
         else PushNil;
    033: ContTop(GetInteger(3));
    034: if GetShopInfo then
         begin
           PushBoolean(True);
           PushInteger(ShopPos);
           PushInteger(ShopCnt);
           PushInteger(ShopID);
           PushInteger(ShopType);
           PushInteger(ShopMax);
           PushInteger(ShopPrice);
           PushStrVal(PChar(ShopName));
         end
         else PushBoolean(False);
    035: PushBoolean(SetShopItem(GetInteger(3),GetInteger(4)));
    036: ExEv_PopUp(GetInteger(3),GetInteger(4),GetInteger(5));
    037: begin
           s:='';
           for i:=3 to GetTop do
             if GetType(i)=T_NUMBER then
               s:=s+NumStr(GetInteger(i),4,False);
           if s<>'' then ExEv_Custom(
             #236+
             NumStr(Length(s)  +  4,2,True)+
             NumStr(Length(s) div 4,1,True)+
             s);
         end;
    038: begin
           SetString(s,GetLString(3,i),i);
           ExEv_Custom(s);
         end;
    039: ExMsg(GetInteger(3),3,0,GetString(4));
    040: StatBar(GetInteger(3));
    041: begin
           BlockInfo(GetInteger(3),GetInteger(4),GetInteger(5),GetInteger(6),GetInteger(7));
           PushLStrVal(PChar(BlockStr),Length(BlockStr));
         end;
    042: begin
           FilterItems(GetInteger(3),GetInteger(4));
           PushInteger(ItemCnt);
         end;
    043: begin
           FilterItems(GetInteger(3));
           PushInteger(ItemCnt);
         end;
    044: begin
           ScanItems;
           PushInteger(ItemCnt);
         end;
    045: Click(GetInteger(3),GetInteger(4));
    046: Click(GetInteger(3),GetInteger(4),GetInteger(5));
    047: Click(GetInteger(3),GetInteger(4),GetInteger(5),GetBoolean(6));
    048: Click(GetInteger(3),GetInteger(4),GetInteger(5),GetBoolean(6),GetBoolean(7),GetBoolean(8));
    049: Click(GetInteger(3),GetInteger(4),1,GetBoolean(5),GetBoolean(6),GetBoolean(7),True,GetBoolean(8)); //deprecated, for compatibility only!
    050: PushBoolean(OpenClient(GetBoolean(3)));
    051: CloseClient;
    052: UOVar.IgnoreCont(GetString(3));
    053: UOVar.IgnoreCont(GetInteger(3));
    // Buff bar (port addition). ScanBuffs([iconID]) -> count; GetBuff(index, 0-based) -> id,
    // title cliloc, name, description, seconds left (-1 = no timer); nil when there is no such buff.
    054: begin
           ScanBuffs(GetInteger(3));
           PushInteger(BuffCnt);
         end;
    055: begin
           ScanBuffs;
           PushInteger(BuffCnt);
         end;
    056: begin
           GetBuff(GetInteger(3));
           if BuffValid then
           begin
             PushInteger(BuffRes.ID);
             PushInteger(BuffRes.Cliloc);
             PushStrVal(PChar(BuffRes.Name));
             PushStrVal(PChar(BuffRes.Desc));
             PushInteger(BuffRes.Time);
           end
           else PushNil;
         end;
    // Port addition (the pathfinder, docs\pathfinding.md phase 4): PATH FIND / CAN / CHECK / SET and
    // the rules, for external programs. Each pushes a state string first, as #PathState says it.
    057: begin                                             // GetPath x y [z] | x y z fromx fromy fromz facet
           if GetTop=9 then
             PathFindFrom(GetInteger(9),GetInteger(6),GetInteger(7),GetInteger(8),
               GetInteger(3),GetInteger(4),GetInteger(5),True,s)
           else
             PathFindFrom(RuleFacet(99),UOVar.CharPosX,UOVar.CharPosY,UOVar.CharPosZ,
               GetInteger(3),GetInteger(4),GetInteger(5),GetTop=5,s);
           PushStrVal(PChar(s));
           PushInteger(PathPlanner.StepCount);
           s:=PathPacked;
           PushLStrVal(PChar(s),Length(s));
         end;
    058: begin                                             // PathCan x y [z]
           i:=UOVar.CharPosZ;
           if GetTop=5 then i:=GetInteger(5);
           if not PathCanAt(RuleFacet(99),GetInteger(3),GetInteger(4),i,s) then i:=0;
           PushStrVal(PChar(s));
           PushInteger(i);
         end;
    059: begin                                             // PathCheck x y [z] [dir]
           SetLength(Q,1);
           Q[0].X:=GetInteger(3);
           Q[0].Y:=GetInteger(4);
           Q[0].Z:=UOVar.CharPosZ;
           if GetTop>=5 then Q[0].Z:=GetInteger(5);
           Q[0].Dir:=0;
           if GetTop>=6 then Q[0].Dir:=GetInteger(6) and 7;
           if UOSel.Nr=0 then s:='noclient'
           else if not StepInfo(Q) then s:='nocheck'
           else if Q[0].NewZ=-128 then s:='blocked'
           else s:='ok';
           PushStrVal(PChar(s));
           if s='ok' then PushInteger(Q[0].NewZ)
           else PushInteger(0);
         end;
    060: begin                                             // PathSet option number
           s:=PathSetOption(GetString(3),IntToStr(GetInteger(4)));
           PushStrVal(PChar(s));
         end;
    061: begin                                             // PathSet option text
           s:=PathSetOption(GetString(3),GetString(4));
           PushStrVal(PChar(s));
         end;
    062: PathArea(True);
    063: PathArea(False);
    064: begin                                             // PathAvoid x y x2 y2 cost [facet]
           PathPlanner.AddAvoid(RuleFacet(8),GetInteger(3),GetInteger(4),GetInteger(5),GetInteger(6),
             GetInteger(7));
           PushStrVal('ok');
         end;
    065: begin                                             // PathLink x y z x2 y2 z2 [cost] [facet]
           i:=PATH_STEP_COST;
           if GetTop>=9 then i:=GetInteger(9);
           PathPlanner.AddLink(RuleFacet(10),GetInteger(3),GetInteger(4),GetInteger(5),GetInteger(6),
             GetInteger(7),GetInteger(8),i);
           PushStrVal('ok');
         end;
    066: begin                                             // PathClear [what]
           s:=UpperCase(GetString(3));
           if (s='') or (s='ALL') then
           begin
             PathPlanner.ClearRules(True,True,True);
             PathLive.ClearLearned;
           end
           else if (s='BLOCKS') or (s='BLOCK') then PathPlanner.ClearRules(True,False,False)
           else if (s='AVOIDS') or (s='AVOID') then PathPlanner.ClearRules(False,True,False)
           else if (s='LINKS') or (s='LINK') then PathPlanner.ClearRules(False,False,True)
           else if s='LEARNED' then PathLive.ClearLearned
           else s:='?';
           if s='?' then PushStrVal('error: PathClear [blocks|avoid|links|learned|all]')
           else PushStrVal('ok');
         end;
    -01: Result:=ERR_NOTFOUND;
    -02: Result:=ERR_WRONGPAR;
    else Result:=ERR_GENERIC;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOWrap.MType(Name : String) : Integer;
var
  Res : TFindRes;
begin
  Result:=ERR_NOTFOUND;
  if not Find_First(Res,Name,UOTbl) then Exit;
  Stack.PushInteger(Res.I^.T);
  repeat
    Stack.PushStrRef(Res.I^.P);
  until not Find_Next(Res);
  Result:=RES_OK;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOWrap.MDelay(Duration : Cardinal) : Boolean;
var
  save : TStack;
begin
  if not Assigned(DelayProc) then
  begin
    Sleep(Duration);
    Result:=True;
    Exit;
  end;                                   // This is a way out of the DLL and thus
  save:=Stack;                           // always a bit delicate! If we don't
  Stack:=TStack.Create;                  // save the stack and the lock in
  Result:=DelayProc(Duration,DelayInfo); // DelayProc() triggers, another thread
  Stack.Free;                            // might access the DLL and destroy the
  Stack:=save;                           // old stack in the process.
end;

////////////////////////////////////////////////////////////////////////////////
function TUOWrap.MHelp : Integer;
begin
  Result:=RES_OK;
end;


////////////////////////////////////////////////////////////////////////////////
/// Control Object /////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////


var
  Commands : array[0..10] of TItem = (
    (N: 'Call'        ;T: CM ;C: 003 ;P: 's*'),
    (N: 'Get'         ;T: CM ;C: 001 ;P: 's' ),
    (N: 'GetCommands' ;T: QY ;C: 003 ;P: ''  ),
    (N: 'GetError'    ;T: QY ;C: 004 ;P: 'n' ),
    (N: 'GetFeatures' ;T: QY ;C: 005 ;P: ''  ),
    (N: 'GetInit'     ;T: QY ;C: 006 ;P: ''  ),
    (N: 'GetKeywords' ;T: QY ;C: 007 ;P: ''  ),
    (N: 'Help'        ;T: CM ;C: 005 ;P: 's' ),
    (N: 'Set'         ;T: CM ;C: 002 ;P: 's?'),
    (N: 'SetDelay'    ;T: QY ;C: 001 ;P: 'pp'),
    (N: 'Type'        ;T: CM ;C: 004 ;P: 's' )
  );

////////////////////////////////////////////////////////////////////////////////
constructor TUOWrap.Create;
begin
  inherited Create;
  Stack:=TStack.Create;
  UOSel:=TUOSel.Create;
  UOVar:=TUOVar.Create(UOSel);
  UOCmd:=TUOCmd.Create(UOSel,UOVar,MDelay);
  UOEvent:=TUOEvent.Create(UOSel,UOVar,MDelay);
  DelayProc:=nil;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TUOWrap.Free;
begin
  UOEvent.Free;
  UOCmd.Free;
  UOVar.Free;
  UOSel.Free;
  Stack.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOWrap.Query : Integer;
var
  Res : TFindRes;
  i   : Integer;
begin
  Stack.Mark;
  Result:=RES_OK;
  Find_First(Res,Stack.GetString(1),Commands);
  case Check(Res,Stack,2,[QY,PA]) of
    001: begin
           DelayProc:=Stack.GetPointer(2);
           DelayInfo:=Stack.GetPointer(3);
         end;
    003: for i:=0 to High(Commands) do
           if Commands[i].T=CM then
             Stack.PushStrRef(Commands[i].N);
    004: begin
           i:=Stack.GetInteger(2);
           if (i<Low(ErrStrings))or(i>0) then
             Stack.PushStrRef('ERR_UNKNOWNERR')
           else Stack.PushStrRef(ErrStrings[i]);
         end;
    005: Stack.PushStrRef('CEIKD');
    006: Stack.PushStrRef(InitString);
    007: begin
           Stack.PushStrRef(UOTbl[0].N);
           for i:=1 to High(UOTbl) do
             if UOTbl[i].N<>UOTbl[i-1].N then
               Stack.PushStrRef(UOTbl[i].N);
         end;
    -01: Result:=ERR_NOTFOUND;
    -02: Result:=ERR_WRONGPAR;
    else Result:=ERR_GENERIC;
  end;
  Stack.Clean;
end;

////////////////////////////////////////////////////////////////////////////////
function TUOWrap.Execute : Integer;
var
  Res  : TFindRes;
  name : String;
begin
  Stack.Mark;
  name:=Stack.GetString(2);
  Find_First(Res,Stack.GetString(1),Commands);
  case Check(Res,Stack,2,[CM,PA]) of
    001: Result:=MGet(name);
    002: Result:=MSet(name);
    003: Result:=MCall(name);
    004: Result:=MType(name);
    005: Result:=MHelp;
    -01: Result:=ERR_NOTFOUND;
    -02: Result:=ERR_WRONGPAR;
    else Result:=ERR_GENERIC;
  end;
  Stack.Clean;
end;


////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
end.
