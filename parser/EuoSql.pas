unit EuoSql;

{
  Port addition (not in the original EasyUO): the engine behind the SQL command --
  one SQLite connection per interpreter, a row snapshot for SQL QUERY, and the
  euo_vars key-value table behind SQL SAVE/LOAD/DELETE. The script-facing command
  (EuoInterpreter.SqlProc) only parses the line and moves values in and out of
  script variables; everything that talks to SQLite is here. See docs\sql.md for
  the script-level reference.

  - The library is loaded lazily, on the first SQL line any script runs, and never
    unloaded: <exe dir>\sqlite3.dll if one was dropped there, else Windows' own
    <System32>\winsqlite3.dll (present since Windows 10). Full paths only, so the
    DLL search order can't pick up a stray copy. Nothing here runs at startup, so a
    script that never uses SQL never loads SQLite. FPC's sqlite3dyn declares every
    entry point cdecl; on Win64 there is only one calling convention, so that
    matches winsqlite3's exports as well.
  - Nothing raises. Every failure (library, open, prepare, step) ends up in
    LastError, which the interpreter publishes as #SqlRes -- an escaping exception
    would stop the script (TExeThread.Execute), and EasyUO commands are silent on
    bad input instead.
  - Script variables in a statement are bound, never pasted into its text:
    SqlRewriteVars turns each one into a numbered parameter ?N and returns the
    names in parameter order; Run then reads each through the caller's GetVar.
  - The connection's busy handler (waits up to BusyTimeoutMs for another
    connection's lock) and progress handler (aborts a running statement) both
    watch the interpreter's Brk flag -- what Stop and closing the tab already set
    (EuoExecutor.pas) -- so a long query or a lock wait ends promptly on Stop
    instead of TExecutor.Free falling back to TerminateThread mid-SQLite.
  - This class is only ever used by the script thread (and by the interpreter's
    Clear/Free while the script is stopped); the GUI reads the interpreter's own
    #Sql* backing fields, never this object.
}

{$mode delphi}{$H+}

interface
uses Windows, SysUtils, Classes, SyncObjs;

const
  BusyTimeoutMs = 5000;

type
  TEuoSqlGetVar = function(const Name : String) : String of object;

  TEuoSql = class(TObject)
  private
    FDb        : Pointer;      // psqlite3; nil = no database open
    FCols      : TStringList;  // snapshot column names, already made variable-safe
    FRows      : TList;        // snapshot rows, each a TStringList of cell values
    FChanges   : Int64;
    FLastID    : Int64;
    FLastError : String;       // '' = the last operation succeeded
    FBrk       : PBoolean;
    FBusyStart : QWord;
    procedure   ClearSnapshot;
    procedure   SetDbError;
    function    CheckOpen : Boolean;
    function    KvPrepare(const Sql : String; out Stmt : Pointer) : Boolean;
  public
    constructor Create(ABrk : PBoolean);
    procedure   Free;
    function    Open(const FileName : String) : Boolean;
    procedure   Close;
    function    IsOpen : Boolean;
    // Runs the first statement in Stmt. WantRows=True replaces the snapshot with the
    // rows it returns (an empty one on failure); False leaves the snapshot alone.
    function    Run(const Stmt : String; WantRows : Boolean; GetVar : TEuoSqlGetVar) : Boolean;
    // Key-value table euo_vars(name TEXT PRIMARY KEY, value). Names are stored as
    // given (the caller lower-cases them); Count = entries written/found/removed.
    function    KvSave(Names : TStrings; GetVar : TEuoSqlGetVar; out Count : Integer) : Boolean;
    function    KvLoad(Names, Values : TStrings; out Count : Integer) : Boolean;
    function    KvDelete(Names : TStrings; out Count : Integer) : Boolean;
    function    RowCount : Integer;
    function    ColCount : Integer;
    function    ColName(Col : Integer) : String;
    function    Cell(Row, Col : Integer) : String;   // both 0-based
    property    Changes : Int64 read FChanges;
    property    LastID : Int64 read FLastID;
    property    LastError : String read FLastError;
  end;

// Replaces every EasyUO variable (%x, !x, #x, *x -- the IsVar character set) that
// starts a word with ?1, ?2, ... and lists the variables in Names in that order.
// Text inside '...', "...", [...], `...`, -- comments and /* */ comments is copied
// unchanged, so LIKE '%dog%' stays a literal pattern.
function SqlRewriteVars(const Stmt : String; Names : TStrings) : String;

// Loads the library on the first call (thread-safe); False if neither DLL loads.
function SqlLibraryAvailable : Boolean;
// True once a load has succeeded -- never loads anything itself.
function SqlLibraryLoaded : Boolean;

implementation
uses ctypes, sqlite3dyn;

const
  SErrNoLibrary   = 'SQLite library not available';
  SErrNotOpen     = 'no database open';
  SErrNoStatement = 'no SQL statement given';
  SErrNoFile      = 'no database file given';

  NameChars = ['0'..'9','A'..'Z','a'..'z','_'];

var
  LibLock  : TCriticalSection;
  LibState : Integer = 0;   // 0 = not tried yet, 1 = loaded, -1 = no usable library

////////////////////////////////////////////////////////////////////////////////
/// Library ////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function EntryPointsPresent : Boolean;
begin
  Result:=Assigned(sqlite3_open_v2) and Assigned(sqlite3_close_v2) and
    Assigned(sqlite3_prepare_v2) and Assigned(sqlite3_step) and
    Assigned(sqlite3_finalize) and Assigned(sqlite3_reset) and
    Assigned(sqlite3_bind_parameter_count) and Assigned(sqlite3_bind_null) and
    Assigned(sqlite3_bind_int64) and Assigned(sqlite3_bind_text) and
    Assigned(sqlite3_column_count) and Assigned(sqlite3_column_name) and
    Assigned(sqlite3_column_type) and Assigned(sqlite3_column_text) and
    Assigned(sqlite3_column_bytes) and Assigned(sqlite3_errmsg) and
    Assigned(sqlite3_changes) and Assigned(sqlite3_total_changes) and
    Assigned(sqlite3_last_insert_rowid) and Assigned(sqlite3_busy_handler) and
    Assigned(sqlite3_progress_handler);
end;

////////////////////////////////////////////////////////////////////////////////
function TryLoad(const Path : String) : Boolean;
begin
  Result:=False;
  if not FileExists(Path) then Exit;
  if TryInitializeSqlite(UnicodeString(Path))<0 then Exit;
  if EntryPointsPresent then
  begin
    Result:=True;
    Exit;
  end;
  ReleaseSqlite;   // a DLL missing an entry point we call would crash later; try the next one
end;

////////////////////////////////////////////////////////////////////////////////
function SystemDir : String;
var
  Buf : array[0..MAX_PATH] of Char;
begin
  SetString(Result,PChar(@Buf[0]),GetSystemDirectory(@Buf[0],Length(Buf)));
end;

////////////////////////////////////////////////////////////////////////////////
function SqlLibraryAvailable : Boolean;
begin
  LibLock.Enter;
  try
    if LibState=0 then
    begin
      LibState:=-1;
      if TryLoad(ExtractFilePath(ParamStr(0))+'sqlite3.dll') then LibState:=1
      else if TryLoad(IncludeTrailingPathDelimiter(SystemDir)+'winsqlite3.dll') then LibState:=1;
    end;
    Result:=LibState=1;
  finally
    LibLock.Leave;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function SqlLibraryLoaded : Boolean;
begin
  LibLock.Enter;
  Result:=LibState=1;
  LibLock.Leave;
end;

////////////////////////////////////////////////////////////////////////////////
/// Variable rewriting /////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// Index just past a quoted run starting at Stmt[i]; a doubled closing quote is an
// escaped one (SQL's '' convention), except for [...] which has no escape.
function SkipQuoted(const Stmt : String; i : Integer) : Integer;
var
  Close : Char;
begin
  if Stmt[i]='[' then Close:=']' else Close:=Stmt[i];
  Result:=i+1;
  while Result<=Length(Stmt) do
  begin
    if Stmt[Result]=Close then
    begin
      if (Close<>']')and(Result<Length(Stmt))and(Stmt[Result+1]=Close) then
      begin
        Inc(Result,2);
        Continue;
      end;
      Inc(Result);
      Exit;
    end;
    Inc(Result);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function SqlRewriteVars(const Stmt : String; Names : TStrings) : String;
var
  i,j   : Integer;
  Start : Integer;
  n     : Integer;
begin
  Names.Clear;
  Result:='';
  n:=Length(Stmt);
  Start:=1;
  i:=1;
  while i<=n do
    case Stmt[i] of
      '''','"','`','[' :
        i:=SkipQuoted(Stmt,i);
      '-' :
        if (i<n)and(Stmt[i+1]='-') then
        begin
          while (i<=n)and not(Stmt[i] in [#10,#13]) do Inc(i);
        end
        else Inc(i);
      '/' :
        if (i<n)and(Stmt[i+1]='*') then
        begin
          j:=Pos('*/',Copy(Stmt,i+2,MaxInt));
          if j>0 then i:=i+2+j+1
          else i:=n+1;
        end
        else Inc(i);
      '%','!','#','*' :
        if (i<n)and(Stmt[i+1] in NameChars)and((i=1)or not(Stmt[i-1] in NameChars)) then
        begin
          j:=i+1;
          while (j<=n)and(Stmt[j] in NameChars) do Inc(j);
          Names.Add(Copy(Stmt,i,j-i));
          Result:=Result+Copy(Stmt,Start,i-Start)+'?'+IntToStr(Names.Count);
          i:=j;
          Start:=j;
        end
        else Inc(i);
    else
      Inc(i);
    end;
  Result:=Result+Copy(Stmt,Start,MaxInt);
end;

////////////////////////////////////////////////////////////////////////////////
/// Binding ////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// N/A (EasyUO's "no value") is NULL; a canonical integer is INTEGER, so numeric
// comparisons and ORDER BY work; anything else is TEXT, byte for byte.
procedure BindValue(Stmt : psqlite3_stmt; Ix : Integer; const Value : String);
var
  i : Int64;
begin
  if Value='N/A' then
    sqlite3_bind_null(Stmt,Ix)
  else if TryStrToInt64(Value,i) and (IntToStr(i)=Value) then
    sqlite3_bind_int64(Stmt,Ix,i)
  else
    sqlite3_bind_text(Stmt,Ix,PAnsiChar(Value),Length(Value),sqlite3_destructor_type(SQLITE_TRANSIENT));
end;

////////////////////////////////////////////////////////////////////////////////
// NULL reads back as N/A, the same as an unset variable.
function ColumnValue(Stmt : psqlite3_stmt; Col : Integer) : String;
var
  p : PAnsiChar;
begin
  if sqlite3_column_type(Stmt,Col)=SQLITE_NULL then
  begin
    Result:='N/A';
    Exit;
  end;
  p:=sqlite3_column_text(Stmt,Col);   // must come before column_bytes
  SetString(Result,p,sqlite3_column_bytes(Stmt,Col));
end;

////////////////////////////////////////////////////////////////////////////////
// A column name as a %variable name: anything outside the IsVar character set
// becomes '_', so count(*) is %count___ (use AS to pick a better one).
function SafeColName(const Name : String; Col : Integer) : String;
var
  i : Integer;
begin
  Result:=Name;
  for i:=1 to Length(Result) do
    if not(Result[i] in NameChars) then Result[i]:='_';
  if Result='' then Result:='col'+IntToStr(Col+1);
end;

////////////////////////////////////////////////////////////////////////////////
/// Callbacks //////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function SqlBusy(User : Pointer; Cnt : cint) : cint; cdecl;
begin
  Result:=0;
  with TEuoSql(User) do
  begin
    if Cnt=0 then FBusyStart:=GetTickCount64;
    if FBrk^ then Exit;
    if GetTickCount64-FBusyStart>=BusyTimeoutMs then Exit;
  end;
  Sleep(10);
  Result:=1;
end;

////////////////////////////////////////////////////////////////////////////////
function SqlProgress(User : Pointer) : cint; cdecl;
begin
  Result:=Ord(TEuoSql(User).FBrk^);
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoSql ////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TEuoSql.Create(ABrk : PBoolean);
begin
  inherited Create;
  FBrk:=ABrk;
  FDb:=nil;
  FCols:=TStringList.Create;
  FRows:=TList.Create;
  FChanges:=0;
  FLastID:=0;
  FLastError:='';
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSql.Free;
begin
  Close;
  FCols.Free;
  FRows.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSql.ClearSnapshot;
var
  i : Integer;
begin
  for i:=0 to FRows.Count-1 do
    TStringList(FRows[i]).Free;
  FRows.Clear;
  FCols.Clear;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSql.SetDbError;
begin
  FLastError:=sqlite3_errmsg(FDb);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSql.CheckOpen : Boolean;
begin
  Result:=FDb<>nil;
  if not Result then FLastError:=SErrNotOpen;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSql.IsOpen : Boolean;
begin
  Result:=FDb<>nil;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSql.Open(const FileName : String) : Boolean;
var
  Db   : psqlite3;
  Name : UTF8String;
begin
  Result:=False;
  Close;
  if FileName='' then
  begin
    FLastError:=SErrNoFile;
    Exit;
  end;
  if not SqlLibraryAvailable then
  begin
    FLastError:=SErrNoLibrary;
    Exit;
  end;

  Name:=UTF8String(FileName);   // SQLite wants UTF-8 file names
  Db:=nil;
  if sqlite3_open_v2(PAnsiChar(Name),@Db,
       SQLITE_OPEN_READWRITE or SQLITE_OPEN_CREATE or SQLITE_OPEN_FULLMUTEX,nil)<>SQLITE_OK then
  begin
    if Db<>nil then
    begin
      FLastError:=sqlite3_errmsg(Db);
      sqlite3_close_v2(Db);
    end
    else FLastError:='out of memory';
    Exit;
  end;

  sqlite3_busy_handler(Db,@SqlBusy,Self);
  sqlite3_progress_handler(Db,1000,@SqlProgress,Self);
  FDb:=Db;
  FLastError:='';
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
// close_v2 rolls back a transaction the script left open.
procedure TEuoSql.Close;
begin
  ClearSnapshot;
  if FDb<>nil then
    sqlite3_close_v2(FDb);
  FDb:=nil;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSql.Run(const Stmt : String; WantRows : Boolean; GetVar : TEuoSqlGetVar) : Boolean;
var
  Names  : TStringList;
  Sql    : String;
  S      : psqlite3_stmt;
  Tail   : PAnsiChar;
  rc     : Integer;
  i      : Integer;
  Cols   : Integer;
  Before : Integer;
  Row    : TStringList;
begin
  Result:=False;
  if WantRows then ClearSnapshot;
  if not CheckOpen then Exit;

  Names:=TStringList.Create;
  try
    Sql:=SqlRewriteVars(Stmt,Names);
    S:=nil;
    // Only the first statement is compiled; anything after its ';' (an EasyUO
    // comment, say) is left in Tail and ignored.
    if sqlite3_prepare_v2(FDb,PAnsiChar(Sql),Length(Sql),@S,@Tail)<>SQLITE_OK then
    begin
      SetDbError;
      Exit;
    end;
    if S=nil then   // only whitespace or a comment
    begin
      FLastError:=SErrNoStatement;
      Exit;
    end;

    try
      // A variable after the compiled statement (in a trailing comment) has a
      // number past the statement's parameter count and is never read.
      if Assigned(GetVar) then
        for i:=1 to sqlite3_bind_parameter_count(S) do
          if i<=Names.Count then
            BindValue(S,i,GetVar(Names[i-1]));

      Cols:=sqlite3_column_count(S);
      if WantRows then
        for i:=0 to Cols-1 do
          FCols.Add(SafeColName(sqlite3_column_name(S,i),i));

      Before:=sqlite3_total_changes(FDb);
      repeat
        rc:=sqlite3_step(S);
        if (rc=SQLITE_ROW)and WantRows then
        begin
          Row:=TStringList.Create;
          FRows.Add(Row);
          for i:=0 to Cols-1 do
            Row.Add(ColumnValue(S,i));
        end;
      until rc<>SQLITE_ROW;

      if rc<>SQLITE_DONE then
      begin
        SetDbError;
        if WantRows then ClearSnapshot;
        Exit;
      end;

      FChanges:=sqlite3_total_changes(FDb)-Before;
      FLastID:=sqlite3_last_insert_rowid(FDb);
      FLastError:='';
      Result:=True;
    finally
      sqlite3_finalize(S);
    end;
  finally
    Names.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSql.KvPrepare(const Sql : String; out Stmt : Pointer) : Boolean;
var
  S : psqlite3_stmt;
begin
  Stmt:=nil;
  Result:=False;
  if not CheckOpen then Exit;
  if not Run('CREATE TABLE IF NOT EXISTS euo_vars(name TEXT PRIMARY KEY, value)',False,nil) then Exit;
  S:=nil;
  if sqlite3_prepare_v2(FDb,PAnsiChar(Sql),Length(Sql),@S,nil)<>SQLITE_OK then
  begin
    SetDbError;
    Exit;
  end;
  Stmt:=S;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
// One SAVEPOINT around the whole list, so it is all-or-nothing whether or not the
// script already has a transaction open.
function TEuoSql.KvSave(Names : TStrings; GetVar : TEuoSqlGetVar; out Count : Integer) : Boolean;
var
  S   : Pointer;
  i   : Integer;
  Err : String;
begin
  Count:=0;
  Result:=False;
  if not KvPrepare('INSERT OR REPLACE INTO euo_vars(name,value) VALUES(?1,?2)',S) then Exit;
  try
    if not Run('SAVEPOINT euo_save',False,nil) then Exit;
    for i:=0 to Names.Count-1 do
    begin
      sqlite3_reset(S);
      BindValue(S,1,LowerCase(Names[i]));
      BindValue(S,2,GetVar(Names[i]));
      if sqlite3_step(S)<>SQLITE_DONE then
      begin
        SetDbError;
        Err:=FLastError;
        sqlite3_reset(S);
        Run('ROLLBACK TO euo_save',False,nil);
        Run('RELEASE euo_save',False,nil);
        FLastError:=Err;
        Count:=0;
        Exit;
      end;
      Inc(Count);
    end;
    sqlite3_reset(S);
    Result:=Run('RELEASE euo_save',False,nil);
    if not Result then Count:=0;
  finally
    sqlite3_finalize(S);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Values gets one Name=Value line per variable found, in Names' order.
function TEuoSql.KvLoad(Names, Values : TStrings; out Count : Integer) : Boolean;
var
  S  : Pointer;
  i  : Integer;
  rc : Integer;
begin
  Count:=0;
  Values.Clear;
  Result:=False;
  if not KvPrepare('SELECT value FROM euo_vars WHERE name=?1',S) then Exit;
  try
    for i:=0 to Names.Count-1 do
    begin
      sqlite3_reset(S);
      BindValue(S,1,LowerCase(Names[i]));
      rc:=sqlite3_step(S);
      if rc=SQLITE_ROW then
      begin
        Values.Add(Names[i]+'='+ColumnValue(S,0));
        Inc(Count);
      end
      else if rc<>SQLITE_DONE then
      begin
        SetDbError;
        Exit;
      end;
    end;
    FLastError:='';
    Result:=True;
  finally
    sqlite3_finalize(S);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSql.KvDelete(Names : TStrings; out Count : Integer) : Boolean;
var
  S : Pointer;
  i : Integer;
begin
  Count:=0;
  Result:=False;
  if not KvPrepare('DELETE FROM euo_vars WHERE name=?1',S) then Exit;
  try
    for i:=0 to Names.Count-1 do
    begin
      sqlite3_reset(S);
      BindValue(S,1,LowerCase(Names[i]));
      if sqlite3_step(S)<>SQLITE_DONE then
      begin
        SetDbError;
        Exit;
      end;
      Inc(Count,sqlite3_changes(FDb));
    end;
    FLastError:='';
    Result:=True;
  finally
    sqlite3_finalize(S);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSql.RowCount : Integer;
begin
  Result:=FRows.Count;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSql.ColCount : Integer;
begin
  Result:=FCols.Count;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSql.ColName(Col : Integer) : String;
begin
  Result:=FCols[Col];
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSql.Cell(Row, Col : Integer) : String;
begin
  Result:=TStringList(FRows[Row])[Col];
end;

////////////////////////////////////////////////////////////////////////////////
initialization
  LibLock:=TCriticalSection.Create;
finalization
  LibLock.Free;
end.
