unit EuoCompleteTests;

{
  Tests for easyuo\eucomplete.pas -- the editor's Ctrl+Space word list, in
  particular the sub-command lists offered after MENU, SQL, EVENT, ... (see
  that unit's header comment). SubCommandWords is plain string-in/list-out;
  BuildCompletionList is checked once against a real (never shown) TSynEdit,
  for the caret-line handling.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, Types, fpcunit, testregistry, SynEdit, eucomplete;

type
  TEuoCompleteTests = class(TTestCase)
  private
    function Words(const LineBeforeCaret : String) : String;
  published
    procedure TestMenuSubCommands;
    procedure TestTypedPrefixKeepsTheWholeList;
    procedure TestNestedSubCommands;
    procedure TestWildcardWords;
    procedure TestTabsSeparateWords;
    procedure TestOtherSpotsGetNoSubCommandList;
    procedure TestBuildCompletionListInAnEditor;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
// SubCommandWords' list as one comma-separated string, '' when it gives none.
function TEuoCompleteTests.Words(const LineBeforeCaret : String) : String;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    L.Sorted:=True;
    if SubCommandWords(LineBeforeCaret,L) then
    begin
      L.Delimiter:=',';
      L.StrictDelimiter:=True;
      Result:=L.DelimitedText;
    end
    else
    begin
      AssertEquals('nothing added when the result is False: '+LineBeforeCaret,0,L.Count);
      Result:='';
    end;
  finally
    L.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCompleteTests.TestMenuSubCommands;
begin
  // both MENU logics' sub-commands (the 1.6 ones and REFORGE included)
  AssertEquals('ACTIVATE,BUTTON,CHECK,CLEAR,COMBO,DELETE,EDIT,FONT,FORM,GET,GETDEF,GETNUM,'+
    'GETPROP,HIDE,HIDEEUO,IMAGE,LIST,MEMO,PANEL,POPDEF,PUSHDEF,RADIO,REFORGE,SET,SETDEF,'+
    'SETPROP,SHAPE,SHOW,TEXT,WINDOW',Words('menu '));
  AssertEquals('CLOSE,DELETE,EXEC,LOAD,OPEN,QUERY,ROW,SAVE',Words('SQL '));
  AssertEquals('CONTTOP,DRAG,EXMSG,MACRO,PATHFIND,PROPERTY,SKILLLOCK,STATBAR,SYSMESSAGE',
    Words('Event '));
  AssertEquals('OK,OKCANCEL,YESNO,YESNOCANCEL',Words('display '));
end;

////////////////////////////////////////////////////////////////////////////////
// The popup positions on the typed prefix itself; the list stays whole.
procedure TEuoCompleteTests.TestTypedPrefixKeepsTheWholeList;
begin
  AssertEquals(Words('menu '),Words('menu Win'));
  AssertEquals('the full word is still being completed',Words('menu '),Words('menu window'));
  AssertEquals('indented, mixed case',Words('sql '),Words('    Sql q'));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCompleteTests.TestNestedSubCommands;
begin
  AssertEquals('COLOR,SIZE,TITLE,TRANSPARENT',Words('menu window '));
  AssertEquals('ALIGN,BGCOLOR,COLOR,NAME,SIZE,STYLE,TRANSPARENT',Words('menu font '));
  AssertEquals('CENTER,LEFT,RIGHT',Words('menu Font Align '));
  AssertEquals('ADD,CLEAR,CREATE,SELECT',Words('menu combo '));
  AssertEquals('ADD,CLEAR,CREATE,SELECT',Words('menu list '));
  AssertEquals('CREATE,ELLIPSE,FILE,FLOODFILL,LINE,PIX,PIXLINE,POS,RECTANGLE',Words('menu image '));
  AssertEquals('INCLUDECALL,MODE',Words('menu reforge '));
  AssertEquals('ALIGNMENT,COLOR,FONTCOLOR,FONTNAME,FONTSIZE,FONTSTYLE,PARENT',Words('menu getdef '));
  AssertEquals(Words('menu getdef '),Words('menu setdef '));
  AssertEquals('NOOVERRIDES',Words('tile init '));
  AssertEquals('DEX,INT,STR',Words('exevent statlock '));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCompleteTests.TestWildcardWords;
begin
  AssertEquals('DOWN,LOCKED,UP',Words('exevent skilllock anat '));
  AssertEquals('DOWN,LOCKED,UP',Words('event SkillLock %skill '));
  AssertEquals('DOWN,LOCKED,UP',Words('exevent statlock dex '));
  AssertEquals('FROM,TO',Words('namespace copy result* '));
  AssertEquals('GLOBAL,LOCAL',Words('namespace copy * from '));
  AssertEquals('GLOBAL,LOCAL',Words('namespace copy * to '));
  AssertEquals('only FROM/TO lead on','',Words('namespace copy * into '));
  AssertEquals('ALIGNMENT,CHECKED,COLOR,ENABLED,FONTCOLOR,FONTNAME,FONTSIZE,FONTSTYLE,HEIGHT,'+
    'LEFT,PARENT,TEXT,TOOLTIP,TOP,VISIBLE,WIDTH',Words('menu getprop ok '));
  AssertEquals(Words('menu getprop ok '),Words('menu SetProp %btn '));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCompleteTests.TestTabsSeparateWords;
begin
  AssertEquals(Words('sql '),Words(#9'sql'#9));
  AssertEquals(Words('menu font '),Words('menu'#9' font  '));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCompleteTests.TestOtherSpotsGetNoSubCommandList;
begin
  AssertEquals('empty line','',Words(''));
  AssertEquals('still on the command word','',Words('menu'));
  AssertEquals('still on the command word, indented','',Words('  sql'));
  AssertEquals('a command without sub-commands','',Words('set '));
  AssertEquals('a free argument','',Words('menu window size '));
  AssertEquals('a free argument after a sub-command','',Words('str len '));
  AssertEquals('a word no sub-command starts with','',Words('menu %action'));
  AssertEquals('a word no sub-command starts with','',Words('display Hello'));
  AssertEquals('menu Test is left out','',Words('menu test'));
  AssertEquals('a comment','',Words('; menu '));
  AssertEquals('a comment after the command','',Words('menu ;note '));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCompleteTests.TestBuildCompletionListInAnEditor;
var
  Ed : TSynEdit;
  L  : TStringList;
begin
  Ed:=TSynEdit.Create(nil);
  L:=TStringList.Create;
  try
    Ed.Lines.Text:=
      'set %count 1'+LineEnding+   // 1
      'sql '+LineEnding+           // 2
      'display %co';               // 3

    Ed.LogicalCaretXY:=Point(5,2);
    BuildCompletionList(L,Ed);
    AssertEquals('only the SQL sub-commands',8,L.Count);
    AssertTrue('only the SQL sub-commands',L.IndexOf('OPEN')>=0);

    Ed.LogicalCaretXY:=Point(2,2);
    BuildCompletionList(L,Ed);
    AssertTrue('on the command word: the full list',L.Count>200);

    Ed.LogicalCaretXY:=Point(12,3);
    BuildCompletionList(L,Ed);
    AssertTrue('a %variable after display: the full list',L.IndexOf('%count')>=0);
    AssertTrue('a %variable after display: the full list',L.IndexOf('#FINDID')>=0);
    AssertTrue('a %variable after display: the full list',L.IndexOf('MENU')>=0);
  finally
    L.Free;
    Ed.Free;
  end;
end;

initialization
  RegisterTest(TEuoCompleteTests);
end.
