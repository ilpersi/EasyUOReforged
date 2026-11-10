unit EuoLintTests;

{
  Tests for EuoLint.pas, the script checker (docs\agent-support.md, phase 2): each rule with a
  script that triggers it and scripts that must not, and the words that only exist at run time,
  which must never be reported. The linter gets its names from a real interpreter
  (TEuoInterpreter.GetCommandNames / GetVariableNames), as EUOCli does, so these tests also
  cover those two accessors.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoInterpreter, EuoLint;

type
  TEuoLintTests = class(TTestCase)
  private
    Linter : TEuoLinter;
    Res    : TEuoLintResult;
    // Checks Src and returns the warnings as "rule@line rule@line", in order.
    function  Warn(const Src : array of String) : String;
    // The finding with this rule, or nil.
    function  Find(const Rule : String) : TEuoFinding;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestNamesComeFromTheInterpreter;
    procedure TestCleanScript;
    procedure TestUnknownCommand;
    procedure TestWordsThatAreNotCommandsButAllowed;
    procedure TestUnknownVariable;
    procedure TestUnknownSubcommand;
    procedure TestRunTimeWordsAreNeverReported;
    procedure TestGluedWords;
    procedure TestGluedWordsOnlyWhereTheCommandCalculates;
    procedure TestBraceOnHeaderLine;
    procedure TestStrayBrace;
    procedure TestUnbalancedBraces;
    procedure TestRepeatUntil;
    procedure TestMissingSubAndLabel;
    procedure TestMissingCallFile;
    procedure TestRestartsAtEnd;
    procedure TestMenuLogic;
    procedure TestNeedsClientNote;
    procedure TestLineAndColumn;
    procedure TestContinuationLines;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.SetUp;
var
  Interp       : TEuoInterpreter;
  Cmds, Vars   : TStringList;
begin
  Interp:=TEuoInterpreter.Create(0);
  Cmds:=TStringList.Create;
  Vars:=TStringList.Create;
  try
    Interp.GetCommandNames(Cmds);
    Interp.GetVariableNames(Vars);
    Linter:=TEuoLinter.Create(Cmds,Vars);
  finally
    Vars.Free;
    Cmds.Free;
    Interp.Free;
  end;
  Res:=nil;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TearDown;
begin
  Res.Free;
  Linter.Free;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLintTests.Warn(const Src : array of String) : String;
var
  SL  : TStringList;
  Cnt : Integer;
begin
  FreeAndNil(Res);
  Res:=TEuoLintResult.Create;
  SL:=TStringList.Create;
  try
    for Cnt:=Low(Src) to High(Src) do SL.Add(Src[Cnt]);
    Linter.Check(SL,Res);
  finally
    SL.Free;
  end;
  Result:='';
  for Cnt:=0 to Res.Count-1 do
    if Res[Cnt].Severity=lsWarning then
    begin
      if Result<>'' then Result:=Result+' ';
      Result:=Result+Res[Cnt].Rule+'@'+IntToStr(Res[Cnt].Line);
    end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLintTests.Find(const Rule : String) : TEuoFinding;
var
  Cnt : Integer;
begin
  Result:=nil;
  for Cnt:=0 to Res.Count-1 do
    if Res[Cnt].Rule=Rule then Exit(Res[Cnt]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestNamesComeFromTheInterpreter;
var
  Interp     : TEuoInterpreter;
  Cmds, Vars : TStringList;
  i          : Integer;
begin
  Interp:=TEuoInterpreter.Create(0);
  Cmds:=TStringList.Create;
  Vars:=TStringList.Create;
  try
    Interp.GetCommandNames(Cmds);
    Interp.GetVariableNames(Vars);

    i:=Cmds.IndexOf('FINDITEM');
    AssertTrue('FINDITEM is a command',i>=0);
    AssertTrue('FINDITEM needs a client',Cmds.Objects[i]<>nil);
    i:=Cmds.IndexOf('SET');
    AssertTrue('SET is a command',i>=0);
    AssertTrue('SET needs no client',Cmds.Objects[i]=nil);
    AssertTrue('WAITFOR is a command',Cmds.IndexOf('WAITFOR')>=0);
    AssertEquals('REPEAT is not registered: UNTIL looks for it',-1,Cmds.IndexOf('REPEAT'));

    i:=Vars.IndexOf('FindID');
    AssertTrue('#FindID is a variable',i>=0);
    AssertTrue('#FindID is read-only',Vars.Objects[i]=nil);
    i:=Vars.IndexOf('LPC');
    AssertTrue('#LPC is a variable',i>=0);
    AssertTrue('#LPC is read/write',Vars.Objects[i]<>nil);
    // every name answers: the list is exactly what GetVar knows
    for i:=0 to Vars.Count-1 do
      AssertTrue('#'+Vars[i]+' is known to the linter',Warn(['set %a #'+Vars[i],'halt'])='');
  finally
    Vars.Free;
    Cmds.Free;
    Interp.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestCleanScript;
begin
  AssertEquals('',Warn([
    '; a comment',
    'set %count 0',
    'mainloop:',
    '  gosub work 1 2',
    '  if ( %count > 3 ) && #true',
    '  {',
    '    set %count %count + 1',
    '  }',
    '  else',
    '    set %count 0',
    '  for %i 1 3',
    '    set %count %count + %i',
    '  repeat',
    '    set %count %count - 1',
    '  until %count < 2',
    'goto mainloop',
    '',
    'sub work',
    '  set %x %1 , _ , %2',
    '  set %name %item . %x',
    'return %x']));
  AssertEquals('no notes either: no client command, no menu',0,Res.Count);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestUnknownCommand;
begin
  AssertEquals('unknown-command@1',Warn(['finditm POF','halt']));
  AssertEquals('finditm',Find('unknown-command').Word);
  AssertEquals('print is another language''s','unknown-command@1',Warn(['print hello','halt']));
  // the first WORD is what the interpreter looks up: a parenthesis or a ; glued to it
  // makes it another word
  AssertEquals('unknown-command@2',Warn(['set %a 1','if(%a = 1)','halt']));
  AssertTrue('hint about the parenthesis',Pos('parenthesis',Find('unknown-command').Hint)>0);
  AssertEquals('unknown-command@1 restarts-at-end@1',Warn(['halt;stop here']));
  AssertTrue('hint about the comment',Pos(';',Find('unknown-command').Hint)>0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestWordsThatAreNotCommandsButAllowed;
begin
  AssertEquals('a label','',Warn(['start:','goto start']));
  AssertEquals('repeat is syntax','',Warn(['repeat','until #true','halt']));
  AssertEquals('initevents is ignored on purpose by old scripts','',Warn(['initevents','halt']));
  AssertEquals('case does not matter','',Warn(['SET %a 1','HaLt']));
  AssertEquals('stopcd is registered, as a no-op','',Warn(['stopcd','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestUnknownVariable;
begin
  AssertEquals('unknown-variable@1',Warn(['set %a #FindIdx','halt']));
  AssertEquals('#FindIdx',Find('unknown-variable').Word);
  AssertEquals('in any command, at any place','unknown-variable@1',Warn(['msg #nosuch hello$','halt']));
  AssertEquals('as the variable set assigns','unknown-variable@1',Warn(['set #nosuch 1','halt']));
  AssertEquals('a word that is more than a name is plain text','',Warn(['msg hello #nosuch$','halt']));
  AssertEquals('real ones, any case','',Warn(['set %a #findid , #SPC , #CharPosX','set #lpc 20','halt']));
  AssertEquals('% ! and * variables are the script''s own','',Warn(['set %a !b + *c','halt']));
  AssertEquals('a # that is no variable name is plain text','',Warn(['set %a #','display ok #1-2','halt']));
  AssertEquals('a name built with . at run time','',Warn(['set %a #find . %b','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestUnknownSubcommand;
begin
  AssertEquals('unknown-subcommand@1',Warn(['event macros 17 0','halt']));
  AssertEquals('macros',Find('unknown-subcommand').Word);
  AssertTrue('the hint lists the real ones',Pos('macro',Find('unknown-subcommand').Hint)>0);
  AssertEquals('unknown-subcommand@1',Warn(['str repalce %a b c','halt']));
  AssertEquals('unknown-subcommand@1',Warn(['sql select 1','halt']));
  AssertEquals('event sleep is not implemented','unknown-subcommand@1',Warn(['event sleep 100','halt']));
  AssertEquals('',Warn(['event Macro 17 0','exevent drag %id 1','str len abc','namespace push',
    'sql open :memory:','path stop','menu clear','menu font size 10','halt']));
  AssertEquals('other commands take anything','',Warn(['display nosuchword','wait 5','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestRunTimeWordsAreNeverReported;
begin
  AssertEquals('a command held in a variable','',Warn(['set %cmd halt','%cmd','halt']));
  AssertEquals('a command glued from pieces','',Warn(['h , a , l , t','halt']));
  AssertEquals('a sub-command held in a variable','',Warn(['set %e sysmessage','event %e hi','halt']));
  AssertEquals('a sub-command glued from pieces','',Warn(['event sys , message hi','halt']));
  AssertEquals('a sub or label held in a variable','',Warn(['set %s work','gosub %s','goto %s','halt']));
  AssertEquals('a sub name glued from pieces','',Warn(['gosub do , %n','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestGluedWords;
begin
  AssertEquals('glued-words@2 glued-words@2',Warn(['set %a 1','if (%a > 1)','  set %b 1','halt']));
  AssertEquals('glued-words@2',Warn(['set %b 1','set %a %b+1','halt']));
  AssertEquals('%b+1',Find('glued-words').Word);
  AssertEquals('glued-words@1',Warn(['if %a=1','  set %b 1','halt']));
  AssertEquals('glued-words@1',Warn(['if %a =1','  set %b 1','halt']));
  AssertEquals('glued-words@1',Warn(['if !%a','  set %b 1','halt']));
  AssertEquals('glued-words@1',Warn(['while #hits<50','  set %b 1','halt']));
  AssertEquals('glued-words@2',Warn(['repeat','until %a>=3','halt']));
  AssertEquals('glued-words@2',Warn(['sub x','return 2*3']));
  AssertEquals('glued-words@1',Warn(['waitfor #TargCurs=1 3s','halt']));

  AssertEquals('everything spaced','',Warn([
    'set %a ( %b + 1 ) * 2',
    'if ! ( %a = 1 ) && %c <> 2 || %d >= 3 || %e =< 4',
    'set %n -1',
    'set %n %n +',
    'set %flag ! %flag',
    'set %flag !flag',
    'set %hex $1A',
    'set %text hello_world',
    'set %id ABC_DEF',
    'if %text in a_b_c',
      '  set %ok #true',
    'halt']));

  AssertEquals('a pair around one operand','glued-words@1',Warn(['if (%a)','  set %b 1','halt']));
  AssertEquals('an operand after the operator','glued-words@1',Warn(['if %a =yes','  set %b 1','halt']));
  AssertEquals('a number divided by a variable','glued-words@1',Warn(['set %a 10/%n','halt']));

  // Text may hold any character. What does not look like operands and operators stuck
  // together is text, and so is every piece the , operator joins.
  AssertEquals('text is not an expression','',Warn([
    'set %none (none)',
    'set %rule ===$',
    'set %empty <empty>',
    'set %ask Did_it_work_(journal)?$(Press_Esc_first.)',
    'set %log %log , $=== , %1 , ===$ , (x , s)',
    'set %durability 120/125',
    'set %date 12/25/2020',
    'if %a = (none)',
    '  set %b 1',
    'halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestGluedWordsOnlyWhereTheCommandCalculates;
begin
  // WAIT does not calculate, so "%a+1" there is a word like any other. That it does not do
  // what it looks like is another matter, and not this rule's.
  AssertEquals('',Warn(['wait %a+1','display ok (done)','msg a=b$','event sysmessage x>y','halt']));
  AssertEquals('the variable set assigns is not part of its expression','',Warn(['set %a+b 1','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestBraceOnHeaderLine;
begin
  AssertEquals('brace-on-header-line@1 unbalanced-braces@3',Warn(['if %a = 1 {','  set %b 1','}','halt']));
  AssertEquals('brace-on-header-line@1 unbalanced-braces@3',Warn(['for %i 1 3 {','  set %b %i','}','halt']));
  AssertEquals('',Warn(['if %a = 1','{','  set %b 1','}','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestStrayBrace;
begin
  AssertEquals('a blank line between','stray-brace@3',Warn(['if %a = 1','','{','  set %b 1','}','halt']));
  AssertEquals('a comment between','stray-brace@3',Warn(['while %a = 1','; why','{','  set %a 2','}','halt']));
  AssertEquals('a block of its own','stray-brace@2',Warn(['set %a 1','{','  set %b 1','}','halt']));
  AssertEquals('after sub','',Warn(['halt','sub x','{','  set %b 1','}']));
  AssertEquals('repeat { } until is a way to write the loop','',
    Warn(['repeat','{','  set %a %a + 1','}','until %a > 3','halt']));
  AssertEquals('after else','',Warn(['if %a = 1','  set %b 1','else','{','  set %b 2','}','halt']));
  AssertEquals('after the + lines of its command','',Warn(['if %a = 1','+ && %b = 2','{','  set %c 1','}','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestUnbalancedBraces;
begin
  AssertEquals('unbalanced-braces@2',Warn(['set %a 1','}','halt']));
  AssertEquals('unbalanced-braces@2 restarts-at-end@4',Warn(['if %a = 1','{','  set %b 1','halt']));
  AssertEquals('nested, closed','',Warn(['if %a = 1','{','  if %b = 1','  {','    set %c 1','  }','}','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestRepeatUntil;
begin
  AssertEquals('repeat-until@2',Warn(['set %a 1','until %a > 3','halt']));
  AssertEquals('repeat-until@1',Warn(['repeat','set %a %a + 1','halt']));
  AssertEquals('',Warn(['repeat','  repeat','    set %a %a + 1','  until %a > 3','until %a > 5','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestMissingSubAndLabel;
begin
  AssertEquals('missing-sub@1',Warn(['gosub wrok','halt','sub work','return']));
  AssertEquals('wrok',Find('missing-sub').Word);
  AssertEquals('missing-label@1',Warn(['goto nowhere','halt']));
  AssertEquals('found, any case, with parameters','',Warn(['gosub WORK 1 2','halt','sub work','return']));
  AssertEquals('found above and below, with or without the colon','',
    Warn(['top:','goto bottom','goto top:','bottom:','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestMissingCallFile;
var
  Dir : String;
  SL  : TStringList;
begin
  Dir:=IncludeTrailingPathDelimiter(GetTempDir)+'euolint-'+IntToStr(GetProcessID);
  ForceDirectories(Dir);
  SL:=TStringList.Create;
  try
    SL.Add('exit');
    SL.SaveToFile(Dir+PathDelim+'here.euo');
    SL.SaveToFile(Dir+PathDelim+'plain.txt');

    AssertEquals('without CurPath, call lines are not checked','',Warn(['call nothere.euo','halt']));
    Linter.CurPath:=Dir;
    AssertEquals('missing-call-file@1',Warn(['call nothere.euo','halt']));
    AssertEquals('',Warn(['call here.euo','halt']));
    AssertEquals('.euo is tried','',Warn(['call here','halt']));
    AssertEquals('.txt is tried','',Warn(['call plain','halt']));
    AssertEquals('an absolute path','',Warn(['call '+Dir+PathDelim+'here.euo a b','halt']));
    AssertEquals('a name held in a variable','',Warn(['call %file','halt']));
  finally
    SL.Free;
    DeleteFile(Dir+PathDelim+'here.euo');
    DeleteFile(Dir+PathDelim+'plain.txt');
    RemoveDir(Dir);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestRestartsAtEnd;
begin
  AssertEquals('restarts-at-end@2',Warn(['set %a 1','set %b 2']));
  AssertEquals('',Warn(['set %a 1','halt']));
  AssertEquals('',Warn(['set %a 1','stop']));
  AssertEquals('an endless loop','',Warn(['loop:','set %a 1','goto loop']));
  AssertEquals('exit is a restart somebody wrote','',Warn(['set %a 1','exit']));
  AssertEquals('subs after the halt','',Warn(['gosub x','halt','','sub x','return']));
  AssertEquals('subs after an endless loop','',Warn(['loop:','gosub x','goto loop','sub x','return']));
  AssertEquals('the main part ends before the first sub','restarts-at-end@1',
    Warn(['gosub x','sub x','return']));
  AssertEquals('a halt an if governs can be skipped','restarts-at-end@3',
    Warn(['set %a 1','if %a = 2','  halt']));
  AssertEquals('a halt inside a block can be skipped','restarts-at-end@5',
    Warn(['set %a 1','if %a = 2','{','  halt','}']));
  AssertEquals('a file of subs is a library for call','',Warn(['sub a','return','sub b','return']));
  AssertEquals('an empty script','',Warn(['','; nothing']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestMenuLogic;
begin
  AssertEquals('',Warn(['menu clear','menu show','halt']));
  AssertEquals('1.5',Res.MenuLogic);
  AssertTrue('a note says which',Find('menu-logic-chosen')<>nil);

  AssertEquals('',Warn(['menu form f 0 0 100 100 Title','menu show','halt']));
  AssertEquals('1.6',Res.MenuLogic);

  AssertEquals('1.6 only, with 1.5 forced','menu-logic@2',
    Warn(['menu reforge mode 1.5','menu form f 0 0 100 100 Title','halt']));
  AssertEquals('1.5',Res.MenuLogic);

  AssertEquals('1.5 only, under 1.6','menu-logic@2',
    Warn(['menu form f 0 0 100 100 Title','menu hideeuo','halt']));

  AssertEquals('no menu line, no note','',Warn(['set %a 1','halt']));
  AssertEquals('',Res.MenuLogic);
  AssertTrue(Find('menu-logic-chosen')=nil);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestNeedsClientNote;
begin
  AssertEquals('',Warn(['finditem POF G_3','event macro 17 0','wait 5','halt']));
  AssertEquals('one note',1,Res.Notes);
  AssertEquals('needs-client',Res[0].Rule);
  AssertEquals('event'+LineEnding+'finditem'+LineEnding,Res.ClientCommands.Text);
  AssertTrue(Pos('event, finditem',Res[0].Message)>0);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestLineAndColumn;
var
  F : TEuoFinding;
begin
  Warn(['set %a 1','   set %b #nosuch + %a','  frobnicate 1','halt']);
  F:=Find('unknown-variable');
  AssertEquals(2,F.Line);
  AssertEquals(11,F.Column);
  F:=Find('unknown-command');
  AssertEquals(3,F.Line);
  AssertEquals(3,F.Column);
  AssertEquals('in line order','unknown-variable@2 unknown-command@3',
    Warn(['set %a 1','   set %b #nosuch + %a','  frobnicate 1','halt']));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLintTests.TestContinuationLines;
begin
  // a + line is part of the line before it, not a command of its own
  AssertEquals('',Warn(['set %a 1','+2','if %a = 12','+ && #true','  set %b 1','halt']));
  AssertEquals('what a + line adds is checked with its line','unknown-variable@1',
    Warn(['set %a 1 +','+ #nosuch','halt']));
end;

initialization
  RegisterTest(TEuoLintTests);

end.
