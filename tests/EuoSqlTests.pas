unit EuoSqlTests;

{
  Tests for the SQL command (port addition): EuoSql.pas's variable rewriting on its
  own, and the command end-to-end through the real interpreter, the same way
  EuoInterpreterTests.pas runs small literal scripts. Databases are :memory: or a
  temp file. Tests that need SQLite call NeedLibrary first and report themselves as
  ignored when neither sqlite3.dll (next to the exe) nor Windows' winsqlite3.dll
  loads -- same idea as LiveClientTests without a client.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Registry, fpcunit, testregistry, EuoInterpreter, EuoSql;

type
  TEuoSqlTests = class(TTestCase)
  private
    Interp : TEuoInterpreter;
    procedure PlayScript(const Script : String; MaxSteps : Integer = 500);
    procedure NeedLibrary;
    function  Rewrite(const Stmt : String; out Names : String) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    // Declared first on purpose: it can only prove anything while nothing earlier in
    // the run has loaded the library.
    procedure TestNonSqlScriptNeverLoadsTheLibrary;
    procedure TestSqlResIsNABeforeAnySqlCommand;
    procedure TestNoDatabaseOpen;
    procedure TestUnknownSubCommand;

    procedure TestRewriteLeavesOperatorsAlone;
    procedure TestRewriteBindsVariablesThatStartAWord;
    procedure TestRewriteSkipsQuotesAndComments;

    procedure TestRoundTripKeepsValuesByteForByte;
    procedure TestIntegerTextAndNullBinding;
    procedure TestAllVariableKindsBind;
    procedure TestRowNavigationAndCounters;
    procedure TestColumnNamesBecomeVariableNames;
    procedure TestSqlErrorsLandInSqlResAndTheScriptGoesOn;
    procedure TestTrailingCommentAndContinuationLines;
    procedure TestRelativePathResolvesAgainstCurPath;
    procedure TestSaveLoadDeletePersistAcrossInterpreters;
    procedure TestSaveRejectsOtherVariableKinds;
    procedure TestClearClosesTheDatabase;
    procedure TestBrkInterruptsARunningQuery;
  end;

implementation

const
  CRLF = #13#10;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.SetUp;
begin
  Interp := TEuoInterpreter.Create(0);
  Interp.Clear;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TearDown;
begin
  Interp.Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.PlayScript(const Script : String; MaxSteps : Integer);
var
  Cnt : Integer;
begin
  Interp.ScrList.Scr.Text := Script;
  Interp.NextLine := 0;
  Interp.ResInt := RES_OK;
  Cnt := 0;
  while (Interp.ResInt <> RES_STOP) and (Interp.ResInt <> RES_CLOSE) and (Cnt < MaxSteps) do
  begin
    Interp.PlayLine;
    Inc(Cnt);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.NeedLibrary;
begin
  if not SqlLibraryAvailable then
    Ignore('No SQLite library could be loaded (no sqlite3.dll next to the test exe, no winsqlite3.dll in System32).');
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoSqlTests.Rewrite(const Stmt : String; out Names : String) : String;
var
  List : TStringList;
begin
  List := TStringList.Create;
  try
    Result := SqlRewriteVars(Stmt, List);
    List.Delimiter := ' ';
    Names := List.DelimitedText;
  finally
    List.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestNonSqlScriptNeverLoadsTheLibrary;
begin
  if SqlLibraryLoaded then
    Ignore('An earlier test already loaded the SQLite library in this process.');
  PlayScript(
    'SET %x 1' + CRLF +
    'FOR %i 1 3' + CRLF +
    '  SET %x %x + 1' + CRLF +
    'STR LEN hello' + CRLF +
    'HALT');
  AssertFalse('a script without SQL lines must not load SQLite', SqlLibraryLoaded);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestSqlResIsNABeforeAnySqlCommand;
begin
  PlayScript('HALT');
  AssertEquals('N/A', Interp.GetVar('#SqlRes'));
  AssertEquals('0', Interp.GetVar('#SqlCnt'));
  AssertEquals('0', Interp.GetVar('#SqlChanges'));
  AssertEquals('0', Interp.GetVar('#SqlLastID'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestNoDatabaseOpen;
begin
  PlayScript(
    'SQL EXEC CREATE TABLE t(a)' + CRLF +
    'SET %after yes' + CRLF +
    'HALT');
  AssertEquals('no database open', Interp.GetVar('#SqlRes'));
  AssertEquals('yes', Interp.GetVar('%after'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestUnknownSubCommand;
begin
  PlayScript('sql frobnicate now' + CRLF + 'HALT');
  AssertEquals('unknown SQL command: frobnicate now', Interp.GetVar('#SqlRes'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestRewriteLeavesOperatorsAlone;
const
  Stmt = 'SELECT a % b, a%b, price*qty, price * qty, count(*), t.*, x != y, -%z FROM t';
var
  Names : String;
begin
  // Only "-%z" is a variable here: '-' is not a name character, so %z starts a word.
  AssertEquals('SELECT a % b, a%b, price*qty, price * qty, count(*), t.*, x != y, -?1 FROM t',
    Rewrite(Stmt, Names));
  AssertEquals('%z', Names);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestRewriteBindsVariablesThatStartAWord;
var
  Names : String;
begin
  AssertEquals('INSERT INTO t VALUES(?1, ?2, ?3, ?4, ?5)',
    Rewrite('INSERT INTO t VALUES(%petid, !owner, #charid, *g, %1)', Names));
  AssertEquals('%petid !owner #charid *g %1', Names);

  // "a %b" is read as a variable (and is then a syntax error in SQLite).
  AssertEquals('SELECT a ?1', Rewrite('SELECT a %b', Names));
  AssertEquals('%b', Names);

  // The same variable twice is bound twice.
  AssertEquals('WHERE a=?1 OR b=?2', Rewrite('WHERE a=%x OR b=%x', Names));
  AssertEquals('%x %x', Names);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestRewriteSkipsQuotesAndComments;
const
  Stmt = 'SELECT ''%a'', ''it''''s %b'', "%c", [%d], `%e` -- %f' + #10 +
         '/* %g */ %h LIKE ''%dog%''';
var
  Names : String;
begin
  AssertEquals('SELECT ''%a'', ''it''''s %b'', "%c", [%d], `%e` -- %f' + #10 +
               '/* %g */ ?1 LIKE ''%dog%''', Rewrite(Stmt, Names));
  AssertEquals('%h', Names);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestRoundTripKeepsValuesByteForByte;
const
  Tricky = 'it''s a,  b . c ; d %e';
begin
  NeedLibrary;
  Interp.SetVar('%tricky', Tricky);
  PlayScript(
    'sql open :memory:' + CRLF +
    'sql exec CREATE TABLE pets(id TEXT PRIMARY KEY, name TEXT, hp INTEGER)' + CRLF +
    'set %petid ABCDEF' + CRLF +
    'set %pethp 42' + CRLF +
    'sql exec INSERT INTO pets VALUES(%petid, %tricky, %pethp)' + CRLF +
    'sql query SELECT name, hp FROM pets WHERE id = %petid' + CRLF +
    'HALT');
  AssertEquals('OK', Interp.GetVar('#SqlRes'));
  AssertEquals('1', Interp.GetVar('#SqlCnt'));
  AssertEquals(Tricky, Interp.GetVar('%name'));
  AssertEquals('42', Interp.GetVar('%hp'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestIntegerTextAndNullBinding;
begin
  NeedLibrary;
  PlayScript(
    'sql open :memory:' + CRLF +
    'sql exec CREATE TABLE t(v)' + CRLF +
    'set %a 100' + CRLF +
    'set %b 9' + CRLF +
    'set %c 007' + CRLF +
    'sql exec INSERT INTO t VALUES(%a)' + CRLF +
    'sql exec INSERT INTO t VALUES(%b)' + CRLF +
    'sql query SELECT v FROM t ORDER BY v' + CRLF +
    'set %first %v' + CRLF +
    'sql query SELECT typeof(%a) AS ta, typeof(%c) AS tc, %c AS c, typeof(%unset) AS tn, %unset AS n' + CRLF +
    'HALT');
  AssertEquals('numeric ORDER BY', '9', Interp.GetVar('%first'));
  AssertEquals('integer', Interp.GetVar('%ta'));
  AssertEquals('non-canonical number stays text', 'text', Interp.GetVar('%tc'));
  AssertEquals('007', Interp.GetVar('%c'));
  AssertEquals('N/A binds as NULL', 'null', Interp.GetVar('%tn'));
  AssertEquals('NULL reads back as N/A', 'N/A', Interp.GetVar('%n'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestAllVariableKindsBind;
var
  Reg : TRegistry;
begin
  NeedLibrary;
  try
    PlayScript(
      'set %local L' + CRLF +
      'namespace local sqltest' + CRLF +
      'set !owner bob' + CRLF +
      'set *sqltestglobal G' + CRLF +
      'sql open :memory:' + CRLF +
      'sql query SELECT %local AS a, !owner AS b, #true AS c, *sqltestglobal AS d' + CRLF +
      'HALT');
    AssertEquals('OK', Interp.GetVar('#SqlRes'));
    AssertEquals('L', Interp.GetVar('%a'));
    AssertEquals('bob', Interp.GetVar('%b'));
    AssertEquals('-1', Interp.GetVar('%c'));
    AssertEquals('G', Interp.GetVar('%d'));
  finally
    // *variables live in the registry; don't leave the test's one behind.
    Reg := TRegistry.Create;
    try
      if Reg.OpenKey('\Software\EasyUO', False) then
        Reg.DeleteValue('*SQLTESTGLOBAL');
    finally
      Reg.Free;
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestRowNavigationAndCounters;
begin
  NeedLibrary;
  PlayScript(
    'sql open :memory:' + CRLF +
    'sql exec CREATE TABLE t(n INTEGER PRIMARY KEY, s TEXT)' + CRLF +
    'sql exec INSERT INTO t(s) VALUES(''one''), (''two''), (''three'')' + CRLF +
    'set %ins #SqlChanges' + CRLF +
    'set %lastid #SqlLastID' + CRLF +
    'sql query SELECT n, s FROM t ORDER BY n' + CRLF +
    'set %r1 %s' + CRLF +
    'sql row 2' + CRLF +
    'set %r2 %s' + CRLF +
    'sql row 4' + CRLF +
    'set %bad #SqlRes' + CRLF +
    'set %still %s' + CRLF +
    'sql exec UPDATE t SET s = ''x'' WHERE n > 1' + CRLF +
    'HALT');
  AssertEquals('3', Interp.GetVar('%ins'));
  AssertEquals('3', Interp.GetVar('%lastid'));
  AssertEquals('one', Interp.GetVar('%r1'));
  AssertEquals('two', Interp.GetVar('%r2'));
  AssertEquals('row 4 out of range (1..3)', Interp.GetVar('%bad'));
  AssertEquals('a bad row leaves the variables alone', 'two', Interp.GetVar('%still'));
  AssertEquals('an exec keeps the query snapshot', '3', Interp.GetVar('#SqlCnt'));
  AssertEquals('2', Interp.GetVar('#SqlChanges'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestColumnNamesBecomeVariableNames;
begin
  NeedLibrary;
  PlayScript(
    'sql open :memory:' + CRLF +
    'sql query SELECT count(*), 5 AS "my col", 6 AS Plain' + CRLF +
    'HALT');
  AssertEquals('1', Interp.GetVar('%count___'));
  AssertEquals('5', Interp.GetVar('%my_col'));
  AssertEquals('6', Interp.GetVar('%plain'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestSqlErrorsLandInSqlResAndTheScriptGoesOn;
begin
  NeedLibrary;
  PlayScript(
    'sql open :memory:' + CRLF +
    'sql exec CREATE TABLE t(a)' + CRLF +
    'sql exec SELEC 1' + CRLF +
    'set %e1 #SqlRes' + CRLF +
    'set %table t' + CRLF +
    'sql query SELECT * FROM %table' + CRLF +
    'set %e2 #SqlRes' + CRLF +
    'set %cnt #SqlCnt' + CRLF +
    'set %after yes' + CRLF +
    'HALT');
  AssertTrue('syntax error expected, got: ' + Interp.GetVar('%e1'),
    Pos('syntax error', Interp.GetVar('%e1')) > 0);
  AssertTrue('a table name cannot be bound, got: ' + Interp.GetVar('%e2'),
    Interp.GetVar('%e2') <> 'OK');
  AssertEquals('0', Interp.GetVar('%cnt'));
  AssertEquals('yes', Interp.GetVar('%after'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestTrailingCommentAndContinuationLines;
begin
  NeedLibrary;
  PlayScript(
    'sql open :memory:' + CRLF +
    'sql exec CREATE TABLE t(a, b) ; make the table' + CRLF +
    'sql exec INSERT INTO t VALUES(1,' + CRLF +
    '+ 2)' + CRLF +
    'sql query SELECT a + b AS s FROM t ; a comment with %vars and an unclosed '' quote' + CRLF +
    'HALT');
  AssertEquals('OK', Interp.GetVar('#SqlRes'));
  AssertEquals('3', Interp.GetVar('%s'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestRelativePathResolvesAgainstCurPath;
var
  FileName : String;
begin
  NeedLibrary;
  FileName := Interp.GetVar('#CurPath') + 'sqltest_relative.db';
  DeleteFile(FileName);
  try
    PlayScript(
      'sql open sqltest_relative.db' + CRLF +
      'sql exec CREATE TABLE t(a)' + CRLF +
      'sql close' + CRLF +
      'HALT');
    AssertEquals('OK', Interp.GetVar('#SqlRes'));
    AssertTrue(FileName + ' should exist', FileExists(FileName));
  finally
    DeleteFile(FileName);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestSaveLoadDeletePersistAcrossInterpreters;
var
  FileName : String;
  Second   : TEuoInterpreter;
  Saved    : TEuoInterpreter;
begin
  NeedLibrary;
  FileName := IncludeTrailingPathDelimiter(GetTempDir) + 'euo_sqltest_kv.db';
  DeleteFile(FileName);
  Second := TEuoInterpreter.Create(0);
  Saved := Interp;
  try
    Interp.SetVar('%kills', 'twelve, or so');
    PlayScript(
      'namespace local kv' + CRLF +
      'set !x 7' + CRLF +
      'sql open ' + FileName + CRLF +
      'sql save %KILLS !x ; persist them' + CRLF +
      'HALT');
    AssertEquals('OK', Interp.GetVar('#SqlRes'));
    AssertEquals('2', Interp.GetVar('#SqlChanges'));

    Second.Clear;
    Interp := Second;
    PlayScript(
      'namespace local kv' + CRLF +
      'sql open ' + FileName + CRLF +
      'sql load %kills !x %missing' + CRLF +
      'set %found #SqlChanges' + CRLF +
      'set %loaded %kills' + CRLF +
      'sql delete %kills' + CRLF +
      'set %deleted #SqlChanges' + CRLF +
      'set %kills gone' + CRLF +
      'sql load %kills' + CRLF +
      'HALT');
    AssertEquals('2', Interp.GetVar('%found'));
    AssertEquals('twelve, or so', Interp.GetVar('%loaded'));
    AssertEquals('1', Interp.GetVar('%deleted'));
    AssertEquals('7', Interp.GetVar('!x'));
    AssertEquals('a variable that was not saved is left alone', 'N/A', Interp.GetVar('%missing'));
    AssertEquals('a deleted entry no longer loads', 'gone', Interp.GetVar('%kills'));
    AssertEquals('0', Interp.GetVar('#SqlChanges'));
  finally
    Interp := Saved;
    Second.Free;
    DeleteFile(FileName);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestSaveRejectsOtherVariableKinds;
begin
  NeedLibrary;
  PlayScript(
    'sql open :memory:' + CRLF +
    'sql save %ok #charid' + CRLF +
    'set %e #SqlRes' + CRLF +
    'sql save' + CRLF +
    'HALT');
  AssertEquals('not a % or ! variable: #charid', Interp.GetVar('%e'));
  AssertEquals('no variables given', Interp.GetVar('#SqlRes'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestClearClosesTheDatabase;
begin
  NeedLibrary;
  PlayScript('sql open :memory:' + CRLF + 'HALT');
  AssertEquals('OK', Interp.GetVar('#SqlRes'));
  Interp.Clear;
  AssertEquals('N/A', Interp.GetVar('#SqlRes'));
  PlayScript('sql exec SELECT 1' + CRLF + 'HALT');
  AssertEquals('no database open', Interp.GetVar('#SqlRes'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoSqlTests.TestBrkInterruptsARunningQuery;
begin
  NeedLibrary;
  PlayScript('sql open :memory:' + CRLF + 'HALT');
  // Brk is what Stop and closing the tab set. The LIMIT keeps the test finite (a few
  // seconds) even if the interrupt were broken.
  Interp.Brk := True;
  try
    PlayScript(
      'sql query WITH RECURSIVE c(x) AS (SELECT 1 UNION ALL SELECT x+1 FROM c LIMIT 50000000) SELECT count(*) AS n FROM c' + CRLF +
      'HALT');
  finally
    Interp.Brk := False;
  end;
  AssertEquals('interrupted', Interp.GetVar('#SqlRes'));
  AssertEquals('0', Interp.GetVar('#SqlCnt'));
end;

initialization
  RegisterTest(TEuoSqlTests);
end.
