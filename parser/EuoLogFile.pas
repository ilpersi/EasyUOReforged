unit EuoLogFile;

{
  Port addition (LOGFILE, PSL item 11): the logging system behind the LOGFILE command. A script
  sends messages at a level (debug, info, warning, error) to targets: the built-in "output" target
  (the queue LOG fills, which the editor's Output panel and EUOCli read) and files it opens. Each
  target has its own minimum level and line format; a file target can rotate by size and by day.
  WRITE puts a line into one target exactly as given, which is plain file writing: a config of SET
  lines written this way loads back with CALL.

  Why it is not built on TEventLog or LazLogger (both read for this, FPC 3.2.2 / Lazarus 3.6):
  - FCL's TEventLog opens its file fmShareDenyWrite, so a second script tab (or a second EasyUO)
    cannot write the same file; its line layout is fixed in a private, non-virtual
    FormatLogMessage, so it cannot write raw lines; it has no level filter and no rotation; its
    stdout/stderr targets would break EUOCli's JSON and MCP output.
  - LazLogger is one process-wide DebugLogger with one file, which the LCL writes to as well; a
    tab cannot have its own files or levels.
  What is taken from TEventLog: its level type (SysUtils.TEventType), its level names (the
  eventlog unit's SLogDebug/SLogInfo/SLogWarning/SLogError), its default timestamp pattern and its
  "[time Level]" layout, and the shape of its API (Log(EventType, Msg), Debug/Info/Warning/Error).

  Files: one Windows handle per file per process, shared by every target that opens it (in any
  tab), in a registry with its own lock. The handle is opened for appending (FILE_APPEND_DATA)
  with read, write and delete sharing, so each line is one WriteFile that lands whole at the end
  of the file, even with another program appending too, and Notepad can read the file meanwhile.
  Nothing is buffered: every line goes straight to Windows, so there is nothing to flush and
  nothing is lost if EasyUO dies. Text is written as the script has it (UTF-8, no BOM) with CRLF.

  Rotation, done under the file's lock before the line that needs it, closing the shared handle
  for the renames and opening it again: by size, run.log -> run.1.log -> run.2.log ...; by day,
  run.log (and the day's numbered files) -> run.2026-11-18.log (run.2026-11-18.1.log ...). The
  day a file holds is the day of its last line: read from the file's last-write time when it is
  first opened, then kept as lines are written. A rename that fails (another program holds the
  file without delete sharing) leaves the line on the current file and says so.

  Nothing here uses the LCL, a client or the interpreter: TEuoScriptLogger returns '' for success
  or the text the interpreter puts in #LogRes.
}

{$mode delphi}{$H+}

interface

uses
  Windows, SysUtils, Classes, SyncObjs, eventlog;

const
  // Level ranks: a message passes a minimum when its rank is at least the minimum's.
  LOG_DEBUG   = 0;
  LOG_INFO    = 1;
  LOG_WARNING = 2;
  LOG_ERROR   = 3;
  LOG_OFF     = 4;   // a minimum only: nothing passes

  LOG_ROTATE_KEEP = 3;   // numbered files kept by size rotation when no count is given
  LOG_DAILY_KEEP  = 7;   // days kept by daily rotation when no count is given

  LOG_OUTPUT = 'OUTPUT';   // the built-in target's name

type
  TEuoLogField  = (lfDate, lfTime, lfLevel, lfScript, lfLine);
  TEuoLogFields = set of TEuoLogField;

  // The clock rotation and timestamps read; tests put in their own.
  TEuoLogClock = function : TDateTime;
  // Where the output target's lines go (the interpreter's LOG queue), with the 1-based line.
  TEuoLogEmit  = procedure(const Text : String; Line : Integer) of object;

  // One file, shared by every target in the process that writes it.
  TEuoSharedFile = class(TObject)
  private
    FPath      : String;
    FKey       : String;
    FHandle    : THandle;
    FRefs      : Integer;
    FSize      : Int64;
    FDay       : Integer;    // Trunc of the local date of the last line, 0 = none yet
    FLock      : TCriticalSection;
    function  OpenHandle(out Err : String) : Boolean;
    procedure CloseHandle_;
    function  RotateBySize(out Err : String) : Boolean;
    function  RotateByDay(out Err : String) : Boolean;
    procedure PruneDays;
  public
    RotateSize : Int64;      // 0 = no size rotation
    RotateKeep : Integer;
    DailyKeep  : Integer;    // 0 = no daily rotation
    constructor Create(const APath : String);
    destructor  Destroy; override;
    // One line (CRLF added) at the end of the file, rotating first when due. '' or the reason.
    function  WriteLine(const S : String; T : TDateTime) : String;
    property  Path : String read FPath;
  end;

  TEuoLogTarget = class(TObject)
  public
    Name     : String;          // upper-case
    MinRank  : Integer;
    Fields   : TEuoLogFields;
    FileObj  : TEuoSharedFile;  // nil for the output target
  end;

  TEuoScriptLogger = class(TObject)
  private
    FLock    : TCriticalSection;
    FTargets : TStringList;     // Objects = TEuoLogTarget; the output target first
    FMinRank : Integer;
    FEmit    : TEuoLogEmit;
    function  Find(const Name : String) : TEuoLogTarget;
    function  NeedTarget(const Name : String; out T : TEuoLogTarget) : String;
    function  NeedFile(const Name : String; out T : TEuoLogTarget) : String;
    procedure Drop(Index : Integer);
    procedure AddOutput;
    function  ResolvePath(const FileName : String; out Full : String) : String;
    function  Emit(T : TEuoLogTarget; const Line : String; LineNr : Integer; Now_ : TDateTime) : String;
  public
    Clock        : TEuoLogClock;
    BaseDir      : String;      // where a relative name starts (#CurPath), with a trailing '\'
    ConfineFiles : Boolean;     // only relative names inside BaseDir (EUOCli without --allow logfile)
    constructor Create(Emit : TEuoLogEmit);
    destructor  Destroy; override;
    // Every file target closed and forgotten, the output target and the minimum back to defaults.
    procedure Reset;
    // Every file target closed and forgotten; the rest kept. For the end of a run.
    procedure CloseFiles;
    function  HasFiles : Boolean;
    function  Open(const Name, FileName : String; Overwrite : Boolean) : String;
    function  Close(const Name : String) : String;      // '' = every file target
    function  Write(const Name, Text : String; LineNr : Integer) : String;
    function  Log(Level : TEventType; const Text, Script : String; LineNr : Integer) : String; overload;
    function  SetMinLevel(const Word : String) : String;
    function  SetLevel(const Name, Word : String) : String;
    function  SetFormat(const Name : String; Words : TStrings) : String;
    function  SetRotate(const Name, SizeWord, KeepWord : String) : String;
    function  SetDaily(const Name, Word : String) : String;
    function  FormatLine(T : TEventType; const Text, Script : String; LineNr : Integer;
                         Fields : TEuoLogFields; Now_ : TDateTime) : String;
    // TEventLog's shape, for a Pascal caller: no script name, no line.
    procedure Log(EventType : TEventType; const Msg : String); overload;
    procedure Debug(const Msg : String);
    procedure Info(const Msg : String);
    procedure Warning(const Msg : String);
    procedure Error(const Msg : String);
    property  MinRank : Integer read FMinRank;
  end;

const
  LOG_FILE_FIELDS   : TEuoLogFields = [lfDate, lfTime, lfLevel, lfScript, lfLine];
  LOG_OUTPUT_FIELDS : TEuoLogFields = [lfLevel];

function  LevelRank(T : TEventType) : Integer;
function  LevelName(T : TEventType) : String;
// 'DEBUG', 'INFO', 'WARNING', 'ERROR' (and 'OFF' when AllowOff); False for another word.
function  ParseLevel(const Word : String; AllowOff : Boolean; out Rank : Integer) : Boolean;
// '1000', '64k', '5m' (case does not matter); False for another word.
function  ParseLogSize(const Word : String; out Size : Int64) : Boolean;
// The files the process has open now (tests).
function  OpenLogFileCount : Integer;
// The full name of FileName, relative to BaseDir (#CurPath, with a trailing '\') unless absolute, or
// the reason it is refused ('' when it is fine). With ConfineFiles (EUOCli without --allow logfile)
// only a relative name that stays inside BaseDir is fine. A logger's file targets go through it, and
// so does SEND DOWNLOAD's file.
function  ResolveScriptPath(const BaseDir, FileName : String; ConfineFiles : Boolean; out Full : String) : String;

implementation

var
  Registry     : TStringList = nil;   // sorted by key; Objects = TEuoSharedFile
  RegistryLock : TCriticalSection = nil;

////////////////////////////////////////////////////////////////////////////////
function DefaultClock : TDateTime;
begin
  Result:=Now;
end;

function W(const S : String) : UnicodeString;
begin
  Result:=UTF8Decode(S);
end;

// GetFileSizeEx is not in FPC 3.2.2's Windows unit.
function HandleSize(H : THandle; out Size : Int64) : Boolean;
var
  Lo, Hi : DWORD;
begin
  Hi:=0;
  Lo:=GetFileSize(H,@Hi);
  Result:=not ((Lo=INVALID_FILE_SIZE) and (GetLastError<>NO_ERROR));
  if Result then Size:=(Int64(Hi) shl 32) or Lo else Size:=0;
end;

function LastErrorText : String;
begin
  Result:=Trim(SysErrorMessage(GetLastError));
end;

function FileExistsW(const S : String) : Boolean;
var
  A : DWORD;
begin
  A:=GetFileAttributesW(PWideChar(W(S)));
  Result:=(A<>INVALID_FILE_ATTRIBUTES) and ((A and FILE_ATTRIBUTE_DIRECTORY)=0);
end;

function DeleteFileW_(const S : String) : Boolean;
begin
  Result:=DeleteFileW(PWideChar(W(S)));
end;

function MoveFileW_(const Src, Dst : String) : Boolean;
begin
  Result:=MoveFileExW(PWideChar(W(Src)),PWideChar(W(Dst)),MOVEFILE_REPLACE_EXISTING);
end;

// run.log + '1' -> run.1.log; a name without an extension gets the part at the end.
function PartName(const Path, Part : String) : String;
var
  Ext : String;
begin
  Ext:=ExtractFileExt(Path);
  Result:=Copy(Path,1,Length(Path)-Length(Ext))+'.'+Part+Ext;
end;

////////////////////////////////////////////////////////////////////////////////
function LevelRank(T : TEventType) : Integer;
begin
  case T of
    etDebug   : Result:=LOG_DEBUG;
    etWarning : Result:=LOG_WARNING;
    etError   : Result:=LOG_ERROR;
  else
    Result:=LOG_INFO;
  end;
end;

function LevelName(T : TEventType) : String;
begin
  case T of
    etDebug   : Result:=SLogDebug;
    etWarning : Result:=SLogWarning;
    etError   : Result:=SLogError;
  else
    Result:=SLogInfo;
  end;
end;

function ParseLevel(const Word : String; AllowOff : Boolean; out Rank : Integer) : Boolean;
var
  U : String;
begin
  U:=UpperCase(Word);
  Result:=True;
  if U='DEBUG' then Rank:=LOG_DEBUG
  else if U='INFO' then Rank:=LOG_INFO
  else if U='WARNING' then Rank:=LOG_WARNING
  else if U='ERROR' then Rank:=LOG_ERROR
  else if AllowOff and (U='OFF') then Rank:=LOG_OFF
  else Result:=False;
end;

function ParseLogSize(const Word : String; out Size : Int64) : Boolean;
var
  U    : String;
  Mult : Int64;
begin
  U:=UpperCase(Trim(Word));
  Mult:=1;
  if (U<>'') and (U[Length(U)] in ['K','M']) then
  begin
    if U[Length(U)]='K' then Mult:=1024 else Mult:=1024*1024;
    Delete(U,Length(U),1);
  end;
  Result:=(U<>'') and TryStrToInt64(U,Size) and (Size>=0) and (Size<=High(Int64) div Mult);
  if Result then Size:=Size*Mult;
end;

function OpenLogFileCount : Integer;
begin
  RegistryLock.Acquire;
  try
    Result:=Registry.Count;
  finally
    RegistryLock.Release;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoSharedFile /////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TEuoSharedFile.Create(const APath : String);
begin
  inherited Create;
  FPath:=APath;
  FKey:=UpperCase(APath);
  FHandle:=INVALID_HANDLE_VALUE;
  FLock:=TCriticalSection.Create;
  RotateKeep:=LOG_ROTATE_KEEP;
end;

destructor TEuoSharedFile.Destroy;
begin
  CloseHandle_;
  FLock.Free;
  inherited Destroy;
end;

// Opens (creating) the file for appending, and reads its size and the day it was last written.
function TEuoSharedFile.OpenHandle(out Err : String) : Boolean;
var
  Sz    : Int64;
  FT    : TFileTime;
  LT    : TFileTime;
  ST    : TSystemTime;
begin
  Err:='';
  if FHandle<>INVALID_HANDLE_VALUE then Exit(True);
  FHandle:=CreateFileW(PWideChar(W(FPath)),FILE_APPEND_DATA or FILE_READ_ATTRIBUTES,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,nil,OPEN_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
  Result:=FHandle<>INVALID_HANDLE_VALUE;
  if not Result then
  begin
    Err:='cannot open '+FPath+': '+LastErrorText;
    Exit;
  end;
  FSize:=0;
  if HandleSize(FHandle,Sz) then FSize:=Sz;
  FDay:=0;
  if (FSize>0) and GetFileTime(FHandle,nil,nil,@FT) and FileTimeToLocalFileTime(FT,LT) and
     FileTimeToSystemTime(LT,ST) then
    FDay:=Trunc(EncodeDate(ST.wYear,ST.wMonth,ST.wDay));
end;

procedure TEuoSharedFile.CloseHandle_;
begin
  if FHandle<>INVALID_HANDLE_VALUE then CloseHandle(FHandle);
  FHandle:=INVALID_HANDLE_VALUE;
end;

// run.log -> run.1.log, run.1.log -> run.2.log, ... up to RotateKeep; the oldest goes.
function TEuoSharedFile.RotateBySize(out Err : String) : Boolean;
var
  N : Integer;
begin
  Err:='';
  CloseHandle_;
  if RotateKeep<1 then
  begin
    // Nothing kept: the file starts again.
    Result:=DeleteFileW_(FPath);
    if not Result then Err:='cannot rotate '+FPath+': '+LastErrorText;
  end
  else begin
    DeleteFileW_(PartName(FPath,IntToStr(RotateKeep)));
    for N:=RotateKeep-1 downto 1 do
      if FileExistsW(PartName(FPath,IntToStr(N))) then
        MoveFileW_(PartName(FPath,IntToStr(N)),PartName(FPath,IntToStr(N+1)));
    Result:=MoveFileW_(FPath,PartName(FPath,'1'));
    if not Result then Err:='cannot rotate '+FPath+': '+LastErrorText;
  end;
  if not OpenHandle(Err) then Exit(False);
end;

// The day's file (and its numbered files) take the day's name; the oldest days go.
function TEuoSharedFile.RotateByDay(out Err : String) : Boolean;
var
  Day  : String;
  Dst  : String;
  N    : Integer;
  Src  : TFileStream;
  Dest : TFileStream;
begin
  Err:='';
  Result:=True;
  Day:=FormatDateTime('yyyy-mm-dd',FDay);
  CloseHandle_;
  try
    for N:=1 to RotateKeep do
      if FileExistsW(PartName(FPath,IntToStr(N))) then
        MoveFileW_(PartName(FPath,IntToStr(N)),PartName(FPath,Day+'.'+IntToStr(N)));
    Dst:=PartName(FPath,Day);
    if FileExistsW(Dst) then
    begin
      // That day already has a file (the log was rotated, then written again with the
      // same day): this one is added to its end, so a day stays one file.
      Src:=nil;
      Dest:=nil;
      try
        try
          Src:=TFileStream.Create(FPath,fmOpenRead or fmShareDenyNone);
          Dest:=TFileStream.Create(Dst,fmOpenWrite or fmShareDenyNone);
          Dest.Seek(0,soEnd);
          if Src.Size>0 then Dest.CopyFrom(Src,0);
        finally
          Src.Free;
          Dest.Free;
        end;
        if not DeleteFileW_(FPath) then
        begin
          Result:=False;
          Err:='cannot rotate '+FPath+': '+LastErrorText;
        end;
      except
        on E : Exception do
        begin
          Result:=False;
          Err:='cannot rotate '+FPath+': '+E.Message;
        end;
      end;
    end
    else if not MoveFileW_(FPath,Dst) then
    begin
      Result:=False;
      Err:='cannot rotate '+FPath+': '+LastErrorText;
    end;
    PruneDays;
  finally
    if not OpenHandle(Dst) then
    begin
      Result:=False;
      Err:=Dst;   // OpenHandle's reason
    end;
  end;
end;

// Keeps the DailyKeep newest days of run.yyyy-mm-dd*.log; the files of older days go.
procedure TEuoSharedFile.PruneDays;
var
  Dir, Base, Ext : String;
  SR    : TSearchRec;
  Days  : TStringList;
  Files : TStringList;
  D     : String;
  Dt    : TDateTime;
  i     : Integer;
begin
  Dir:=ExtractFilePath(FPath);
  Ext:=ExtractFileExt(FPath);
  Base:=ExtractFileName(FPath);
  Base:=Copy(Base,1,Length(Base)-Length(Ext))+'.';
  Days:=TStringList.Create;
  Files:=TStringList.Create;
  try
    Days.Sorted:=True;
    Days.Duplicates:=dupIgnore;
    if FindFirst(Dir+Base+'*'+Ext,faAnyFile and not faDirectory,SR)=0 then
    try
      repeat
        D:=Copy(SR.Name,Length(Base)+1,10);
        if (Length(D)=10) and (D[5]='-') and (D[8]='-') and
           TryEncodeDate(StrToIntDef(Copy(D,1,4),0),StrToIntDef(Copy(D,6,2),0),StrToIntDef(Copy(D,9,2),0),Dt) then
        begin
          Days.Add(D);
          Files.Add(D+'|'+SR.Name);
        end;
      until FindNext(SR)<>0;
    finally
      FindClose(SR);
    end;
    // Days is sorted oldest first; the newest DailyKeep stay.
    for i:=0 to Days.Count-1-DailyKeep do
      for D in Files do
        if Copy(D,1,10)=Days[i] then DeleteFileW_(Dir+Copy(D,12,MaxInt));
  finally
    Days.Free;
    Files.Free;
  end;
end;

function TEuoSharedFile.WriteLine(const S : String; T : TDateTime) : String;
var
  Line    : String;
  Done    : DWORD;
  Sz      : Int64;
  Err     : String;
  Today   : Integer;
begin
  Result:='';
  Line:=S+#13#10;
  Today:=Trunc(T);
  FLock.Acquire;
  try
    if not OpenHandle(Err) then Exit(Err);

    if (DailyKeep>0) and (FDay<>0) and (FDay<>Today) then
    begin
      // Another program may have written meanwhile: the size decides whether there is a day to keep.
      if HandleSize(FHandle,Sz) then FSize:=Sz;
      if FSize>0 then
        if not RotateByDay(Err) then Result:=Err;
      if FHandle=INVALID_HANDLE_VALUE then Exit;
    end;

    if RotateSize>0 then
    begin
      if HandleSize(FHandle,Sz) then FSize:=Sz;
      if (FSize>0) and (FSize+Length(Line)>RotateSize) then
        if not RotateBySize(Err) then Result:=Err;
      if FHandle=INVALID_HANDLE_VALUE then Exit;
    end;

    if not WriteFile(FHandle,Line[1],Length(Line),Done,nil) then
      Exit('write failed on '+FPath+': '+LastErrorText);
    Inc(FSize,Done);
    FDay:=Today;
  finally
    FLock.Release;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// The registry: one TEuoSharedFile per file. Overwrite empties the file first (as ">" did),
// whoever else has it open.
function AcquireFile(const Path : String; Overwrite : Boolean; out F : TEuoSharedFile) : String;
var
  Idx : Integer;
  H   : THandle;
begin
  Result:='';
  F:=nil;
  RegistryLock.Acquire;
  try
    if Overwrite then
    begin
      H:=CreateFileW(PWideChar(W(Path)),GENERIC_WRITE,FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE,
        nil,CREATE_ALWAYS,FILE_ATTRIBUTE_NORMAL,0);
      if H=INVALID_HANDLE_VALUE then Exit('cannot open '+Path+': '+LastErrorText);
      CloseHandle(H);
    end;

    if Registry.Find(UpperCase(Path),Idx) then
    begin
      F:=TEuoSharedFile(Registry.Objects[Idx]);
      F.FLock.Acquire;
      try
        if Overwrite then
        begin
          F.FSize:=0;
          F.FDay:=0;
        end;
      finally
        F.FLock.Release;
      end;
    end
    else begin
      F:=TEuoSharedFile.Create(Path);
      if not F.OpenHandle(Result) then
      begin
        FreeAndNil(F);
        Exit;
      end;
      Registry.AddObject(F.FKey,F);
    end;
    Inc(F.FRefs);
  finally
    RegistryLock.Release;
  end;
end;

procedure ReleaseFile(F : TEuoSharedFile);
var
  Idx : Integer;
begin
  if F=nil then Exit;
  RegistryLock.Acquire;
  try
    Dec(F.FRefs);
    if F.FRefs>0 then Exit;
    if Registry.Find(F.FKey,Idx) then Registry.Delete(Idx);
    F.Free;
  finally
    RegistryLock.Release;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoScriptLogger ///////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TEuoScriptLogger.Create(Emit : TEuoLogEmit);
begin
  inherited Create;
  FLock:=TCriticalSection.Create;
  FTargets:=TStringList.Create;
  FEmit:=Emit;
  Clock:=DefaultClock;
  BaseDir:='';
  ConfineFiles:=False;
  FMinRank:=LOG_DEBUG;
  AddOutput;
end;

destructor TEuoScriptLogger.Destroy;
begin
  while FTargets.Count>0 do Drop(FTargets.Count-1);
  FTargets.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TEuoScriptLogger.AddOutput;
var
  T : TEuoLogTarget;
begin
  T:=TEuoLogTarget.Create;
  T.Name:=LOG_OUTPUT;
  T.MinRank:=LOG_DEBUG;
  T.Fields:=LOG_OUTPUT_FIELDS;
  T.FileObj:=nil;
  FTargets.InsertObject(0,T.Name,T);
end;

procedure TEuoScriptLogger.Drop(Index : Integer);
var
  T : TEuoLogTarget;
begin
  T:=TEuoLogTarget(FTargets.Objects[Index]);
  FTargets.Delete(Index);
  ReleaseFile(T.FileObj);
  T.Free;
end;

procedure TEuoScriptLogger.Reset;
begin
  FLock.Acquire;
  try
    while FTargets.Count>0 do Drop(FTargets.Count-1);
    AddOutput;
    FMinRank:=LOG_DEBUG;
  finally
    FLock.Release;
  end;
end;

procedure TEuoScriptLogger.CloseFiles;
var
  i : Integer;
begin
  FLock.Acquire;
  try
    for i:=FTargets.Count-1 downto 0 do
      if TEuoLogTarget(FTargets.Objects[i]).FileObj<>nil then Drop(i);
  finally
    FLock.Release;
  end;
end;

function TEuoScriptLogger.HasFiles : Boolean;
begin
  FLock.Acquire;
  try
    Result:=FTargets.Count>1;
  finally
    FLock.Release;
  end;
end;

function TEuoScriptLogger.Find(const Name : String) : TEuoLogTarget;
var
  i : Integer;
begin
  Result:=nil;
  for i:=0 to FTargets.Count-1 do
    if FTargets[i]=UpperCase(Name) then Exit(TEuoLogTarget(FTargets.Objects[i]));
end;

function TEuoScriptLogger.NeedTarget(const Name : String; out T : TEuoLogTarget) : String;
begin
  Result:='';
  T:=nil;
  if Name='' then Exit('no target given');
  T:=Find(Name);
  if T=nil then Result:='no target '+Name;
end;

function TEuoScriptLogger.NeedFile(const Name : String; out T : TEuoLogTarget) : String;
begin
  Result:=NeedTarget(Name,T);
  if (Result='') and (T.FileObj=nil) then
    Result:='output is the Output panel, not a file';
end;

// The full name of a file target, or the reason it is refused.
function TEuoScriptLogger.ResolvePath(const FileName : String; out Full : String) : String;
begin
  Result:=ResolveScriptPath(BaseDir,FileName,ConfineFiles,Full);
end;

function ResolveScriptPath(const BaseDir, FileName : String; ConfineFiles : Boolean; out Full : String) : String;
var
  Abs   : Boolean;
  Parts : TStringList;
  i     : Integer;
  Root  : String;
begin
  Result:='';
  Full:='';
  if Trim(FileName)='' then Exit('no file given');
  Abs:=((Length(FileName)>=2) and (FileName[2]=':')) or (FileName[1] in ['\','/']);
  if ConfineFiles then
  begin
    if Abs then Exit('outside the program folder: '+FileName);
    Parts:=TStringList.Create;
    try
      Parts.Delimiter:='\';
      Parts.StrictDelimiter:=True;
      Parts.DelimitedText:=StringReplace(FileName,'/','\',[rfReplaceAll]);
      for i:=0 to Parts.Count-1 do
        if Trim(Parts[i])='..' then Exit('outside the program folder: '+FileName);
    finally
      Parts.Free;
    end;
  end;
  if Abs then Full:=FileName
  else Full:=BaseDir+FileName;
  Full:=ExpandFileName(StringReplace(Full,'/','\',[rfReplaceAll]));
  if ConfineFiles then
  begin
    Root:=IncludeTrailingPathDelimiter(ExpandFileName(BaseDir));
    if UpperCase(Copy(Full,1,Length(Root)))<>UpperCase(Root) then
      Exit('outside the program folder: '+FileName);
  end;
  if (Full='') or (Full[Length(Full)] in ['\','/']) then Exit('not a file: '+FileName);
  if DirectoryExists(Full) then Exit('a folder, not a file: '+FileName);
end;

function TEuoScriptLogger.Open(const Name, FileName : String; Overwrite : Boolean) : String;
var
  T    : TEuoLogTarget;
  Full : String;
  F    : TEuoSharedFile;
  Dir  : String;
  Idx  : Integer;
begin
  if Name='' then Exit('no target given');
  if UpperCase(Name)=LOG_OUTPUT then Exit('output is the Output panel: give the file another target name');
  Result:=ResolvePath(FileName,Full);
  if Result<>'' then Exit;

  Dir:=ExtractFileDir(Full);
  if (Dir<>'') and not DirectoryExists(Dir) then
    if not ForceDirectories(Dir) then Exit('cannot create the folder '+Dir);

  FLock.Acquire;
  try
    // Opening a name again replaces its file and settings.
    Idx:=FTargets.IndexOf(UpperCase(Name));
    if Idx>=0 then Drop(Idx);

    Result:=AcquireFile(Full,Overwrite,F);
    if Result<>'' then Exit;
    T:=TEuoLogTarget.Create;
    T.Name:=UpperCase(Name);
    T.MinRank:=LOG_DEBUG;
    T.Fields:=LOG_FILE_FIELDS;
    T.FileObj:=F;
    FTargets.AddObject(T.Name,T);
  finally
    FLock.Release;
  end;
end;

function TEuoScriptLogger.Close(const Name : String) : String;
var
  Idx : Integer;
  T   : TEuoLogTarget;
begin
  Result:='';
  if Name='' then
  begin
    CloseFiles;
    Exit;
  end;
  FLock.Acquire;
  try
    Result:=NeedFile(Name,T);
    if Result<>'' then
    begin
      if (T<>nil) and (T.FileObj=nil) then
        Result:='output cannot be closed: logfile set output level off silences it';
      Exit;
    end;
    Idx:=FTargets.IndexOfObject(T);
    Drop(Idx);
  finally
    FLock.Release;
  end;
end;

function TEuoScriptLogger.Emit(T : TEuoLogTarget; const Line : String; LineNr : Integer;
  Now_ : TDateTime) : String;
begin
  Result:='';
  if T.FileObj=nil then
  begin
    if Assigned(FEmit) then FEmit(Line,LineNr);
  end
  else
    Result:=T.FileObj.WriteLine(Line,Now_);
end;

function TEuoScriptLogger.Write(const Name, Text : String; LineNr : Integer) : String;
var
  T : TEuoLogTarget;
begin
  FLock.Acquire;
  try
    Result:=NeedTarget(Name,T);
    if Result='' then Result:=Emit(T,Text,LineNr,Clock());
  finally
    FLock.Release;
  end;
end;

function TEuoScriptLogger.FormatLine(T : TEventType; const Text, Script : String; LineNr : Integer;
  Fields : TEuoLogFields; Now_ : TDateTime) : String;
var
  Head : String;

  procedure Add(const S : String);
  begin
    if Head<>'' then Head:=Head+' ';
    Head:=Head+S;
  end;

begin
  Head:='';
  if lfDate in Fields then Add(FormatDateTime('yyyy-mm-dd',Now_));
  if lfTime in Fields then Add(FormatDateTime('hh:nn:ss.zzz',Now_));
  if lfLevel in Fields then Add('['+LevelName(T)+']');
  if (lfScript in Fields) and (lfLine in Fields) then Add(Script+':'+IntToStr(LineNr))
  else if lfScript in Fields then Add(Script)
  else if lfLine in Fields then Add('line '+IntToStr(LineNr));
  if Head='' then Result:=Text
  else if Text='' then Result:=Head
  else Result:=Head+' '+Text;
end;

function TEuoScriptLogger.Log(Level : TEventType; const Text, Script : String; LineNr : Integer) : String;
var
  i    : Integer;
  T    : TEuoLogTarget;
  Rank : Integer;
  Err  : String;
  Now_ : TDateTime;
begin
  Result:='';
  Rank:=LevelRank(Level);
  FLock.Acquire;
  try
    if Rank<FMinRank then Exit;
    Now_:=Clock();
    for i:=0 to FTargets.Count-1 do
    begin
      T:=TEuoLogTarget(FTargets.Objects[i]);
      if Rank<T.MinRank then Continue;
      Err:=Emit(T,FormatLine(Level,Text,Script,LineNr,T.Fields,Now_),LineNr,Now_);
      // The first failure is the one reported; the other targets still get the line.
      if (Err<>'') and (Result='') then Result:=Err;
    end;
  finally
    FLock.Release;
  end;
end;

procedure TEuoScriptLogger.Log(EventType : TEventType; const Msg : String);
begin
  Log(EventType,Msg,'',0);
end;

procedure TEuoScriptLogger.Debug(const Msg : String);   begin Log(etDebug,Msg); end;
procedure TEuoScriptLogger.Info(const Msg : String);    begin Log(etInfo,Msg); end;
procedure TEuoScriptLogger.Warning(const Msg : String); begin Log(etWarning,Msg); end;
procedure TEuoScriptLogger.Error(const Msg : String);   begin Log(etError,Msg); end;

function TEuoScriptLogger.SetMinLevel(const Word : String) : String;
var
  Rank : Integer;
begin
  Result:='';
  if not ParseLevel(Word,True,Rank) then Exit('unknown level '+Word+': debug, info, warning, error or off');
  FLock.Acquire;
  try
    FMinRank:=Rank;
  finally
    FLock.Release;
  end;
end;

function TEuoScriptLogger.SetLevel(const Name, Word : String) : String;
var
  T    : TEuoLogTarget;
  Rank : Integer;
begin
  if not ParseLevel(Word,True,Rank) then Exit('unknown level '+Word+': debug, info, warning, error or off');
  FLock.Acquire;
  try
    Result:=NeedTarget(Name,T);
    if Result='' then T.MinRank:=Rank;
  finally
    FLock.Release;
  end;
end;

function TEuoScriptLogger.SetFormat(const Name : String; Words : TStrings) : String;
var
  T      : TEuoLogTarget;
  Fields : TEuoLogFields;
  i      : Integer;
  U      : String;
begin
  Result:='';
  Fields:=[];
  if Words.Count=0 then Exit('no format given: raw, or any of date time level script line');
  for i:=0 to Words.Count-1 do
  begin
    U:=UpperCase(Words[i]);
    if U='RAW' then
    begin
      if Words.Count>1 then Exit('raw goes alone: it means no fields');
    end
    else if U='DATE' then Include(Fields,lfDate)
    else if U='TIME' then Include(Fields,lfTime)
    else if U='LEVEL' then Include(Fields,lfLevel)
    else if U='SCRIPT' then Include(Fields,lfScript)
    else if U='LINE' then Include(Fields,lfLine)
    else Exit('unknown format field '+Words[i]+': raw, or any of date time level script line');
  end;
  FLock.Acquire;
  try
    Result:=NeedTarget(Name,T);
    if Result='' then T.Fields:=Fields;
  finally
    FLock.Release;
  end;
end;

function TEuoScriptLogger.SetRotate(const Name, SizeWord, KeepWord : String) : String;
var
  T    : TEuoLogTarget;
  Size : Int64;
  Keep : Integer;
begin
  if not ParseLogSize(SizeWord,Size) then Exit('rotate needs a size: bytes, or with k or m, 0 = off');
  Keep:=LOG_ROTATE_KEEP;
  if KeepWord<>'' then
    if not (TryStrToInt(KeepWord,Keep) and (Keep>=0) and (Keep<=1000)) then
      Exit('rotate keeps 0 to 1000 files, not '+KeepWord);
  FLock.Acquire;
  try
    Result:=NeedFile(Name,T);
    if Result<>'' then Exit;
    T.FileObj.FLock.Acquire;
    try
      T.FileObj.RotateSize:=Size;
      T.FileObj.RotateKeep:=Keep;
    finally
      T.FileObj.FLock.Release;
    end;
  finally
    FLock.Release;
  end;
end;

function TEuoScriptLogger.SetDaily(const Name, Word : String) : String;
var
  T    : TEuoLogTarget;
  Keep : Integer;
begin
  Keep:=LOG_DAILY_KEEP;
  if UpperCase(Word)='OFF' then Keep:=0
  else if Word<>'' then
    if not (TryStrToInt(Word,Keep) and (Keep>=1) and (Keep<=3650)) then
      Exit('daily keeps 1 to 3650 days, or off, not '+Word);
  FLock.Acquire;
  try
    Result:=NeedFile(Name,T);
    if Result<>'' then Exit;
    T.FileObj.FLock.Acquire;
    try
      T.FileObj.DailyKeep:=Keep;
    finally
      T.FileObj.FLock.Release;
    end;
  finally
    FLock.Release;
  end;
end;

initialization
  Registry:=TStringList.Create;
  Registry.Sorted:=True;
  RegistryLock:=TCriticalSection.Create;

finalization
  while Registry.Count>0 do
  begin
    Registry.Objects[0].Free;
    Registry.Delete(0);
  end;
  Registry.Free;
  RegistryLock.Free;

end.
