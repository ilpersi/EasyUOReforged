unit eusyntax;

{
  Builds the EasyUO script syntax highlighter for TSynUniSyn, restoring
  what main.pas's FormCreate had disabled since commit 940e32f ("EUOSyn.hlr
  is incompatible with this SynUniHighlighter version"). That commit's own
  investigation was correct as far as it went: the original EUOSyn.hlr uses
  the Delphi-era UniHighlighter's file schema (Keywords/word/Set/Rule/
  Scheme/CopyRight tags, colors packed into one Attributes="R,G;Style"
  string), while the Lazarus-bundled SynUniHighlighter this migration wired
  in recognizes a different, more minimal tag vocabulary (KW/W instead of
  Keywords/word, colors as separate Fore/Back/Style child tags, no Set/Rule/
  Scheme/CopyRight at all) -- loading the original file raises immediately.

  Rather than convert EUOSyn.hlr to the new (thinly-documented) XML schema,
  this unit drives TSynUniSyn's underlying Pascal object model directly --
  the exact same TSynRange/TSynSymbolGroup/TSynHighlighterAttributes calls
  the file loader itself makes internally (confirmed by reading
  synunihighlighter.pas's real LoadFromStream implementation, not guessed).
  This sidesteps the schema entirely: no XML to get subtly wrong, and it's
  type-checked at compile time. Every keyword, range, and color value below
  is transcribed directly from the original EUOSyn.hlr (its Attributes
  colors are plain Delphi TColor integers -- e.g. clNone itself is
  536870911/$1FFFFFFF, confirmed against LCL's own Graphics.pp -- and LCL's
  TColor is bit-compatible with Delphi's, so they're copied here as literal
  numbers with no reinterpretation needed).

  Two narrow, deliberate gaps versus the original, both confirmed by reading
  TNumberSymbols.GetToken directly rather than assumed:
  - The original's root-level Number "Set" recognizes a leading +/- as part
    of a number token (Symbols="+-0123456789"). This component's number
    detection is hardcoded to '0'..'9' only (TNumberSymbols.GetToken), with
    no configurable character set at all -- a real capability gap in this
    SynUniHighlighter port, not something this unit can route around via
    the object model either (the digit set isn't data, it's compiled
    logic). Consequence: a leading sign character next to a number falls
    back to whatever an unclassified character renders as (the range's
    plain DefaultAttri), rather than being colored as part of the number.
  - Same root cause: the original's Hex range overrides its Number "Set" to
    accept hex digits (Symbols="0123456789ABCDEFabcdef"), so "$FF" would
    highlight "FF" distinctly within the hex-literal color. Not
    reproducible for the same reason; the hex digits still render correctly
    via the Hex range's own DefaultAttri, just without that extra distinct
    sub-highlight.
  Both are purely cosmetic (a slightly less granular color, never a parsing
  or functional difference), and are the only two things this unit could
  not carry over faithfully.

  One inert, pre-existing issue in the installed component worth flagging:
  TSynRange.FindSymbolOwner calls KeywordsList.Find without KeywordsList
  ever having Sorted:=True set (the exact "TStringList.Find needs
  Sorted:=True in FPC" pitfall the migration plan called out for this
  project's OWN TStringList usages elsewhere) -- but FindSymbolOwner is
  never actually called from anywhere in synunihighlighter.pas (confirmed
  by grepping the whole unit), so it's dead code today, not a live bug this
  highlighter definition can trigger. Flagged here in case a future version
  of the component starts calling it.
}

{$mode delphi}{$H+}

interface

uses
  Classes, Graphics, SynUniHighlighter;

// The script's command keywords and built-in #variables, transcribed from
// EUOSyn.hlr (see below) -- exposed here as the single shared source for
// both this unit's own BuildEUOHighlighter and eucomplete.pas's
// autocomplete word list, so the two can never drift apart from each other
// (they were already at risk of drifting from the actual parser/interpreter
// vocabulary -- see this unit's header comment -- no reason to also risk a
// second, independent copy for completion).
const
  CommandKeywords : array[0..54] of String = (
    'BREAK', 'CALL', 'CHOOSESKILL', 'CLICK', 'CMPPIX', 'CONTINUE', 'CONTPOS',
    'DELETEJOURNAL', 'DELETEVAR', 'DISPLAY', 'ELSE', 'EVENT', 'EXECUTE',
    'EXEVENT', 'EXIT', 'FINDITEM', 'FOR', 'GETSHOPINFO', 'GETUOTITLE',
    'GOSUB', 'GOTO', 'HALT', 'HIDEITEM', 'IF', 'IGNORECONT', 'IGNOREITEM',
    'KEY', 'MENU', 'MOVE', 'MSG', 'NAMESPACE', 'NEXTCPOS', 'ONHOTKEY',
    'PAUSE', 'REPEAT', 'RETURN', 'SAVEPIX', 'SCANJOURNAL', 'SEND', 'SET',
    'SETSHOPITEM', 'SETUOTITLE', 'SHUTDOWN', 'SLEEP', 'SOUND', 'STOP',
    'STR', 'SUB', 'TARGET', 'TERMINATE', 'TILE', 'UNTIL', 'UOXL', 'WAIT',
    'WHILE'
  );

  SystemKeywords : array[0..137] of String = (
    '#AR', '#BACKPACKID', '#CHARDIR', '#CHARGHOST', '#CHARID', '#CHARNAME',
    '#CHARPOSX', '#CHARPOSY', '#CHARPOSZ', '#CHARSTATUS', '#CLICNT',
    '#CLILANG', '#CLILEFT', '#CLILOGGED', '#CLINR', '#CLITOP', '#CLIVER',
    '#CLIXRES', '#CLIYRES', '#CONTHP', '#CONTID', '#CONTKIND', '#CONTNAME',
    '#CONTPOSX', '#CONTPOSY', '#CONTSIZEX', '#CONTSIZEY', '#CONTTYPE',
    '#CR', '#CURPATH', '#CURSKIND', '#CURSORX', '#CURSORY', '#DATE',
    '#DEX', '#DISPRES', '#DOT', '#ENEMYHITS', '#ENEMYID', '#ER', '#EUOVER',
    '#FALSE', '#FINDBAGID', '#FINDCNT', '#FINDCOL', '#FINDDIST', '#FINDID',
    '#FINDINDEX', '#FINDKIND', '#FINDMOD', '#FINDREP', '#FINDSTACK',
    '#FINDTYPE', '#FINDX', '#FINDY', '#FINDZ', '#FOLLOWERS', '#FR',
    '#GOLD', '#HITS', '#INT', '#JCOLOR', '#JINDEX', '#JOURNAL', '#LHANDID',
    '#LLIFTEDID', '#LLIFTEDKIND', '#LLIFTEDTYPE', '#LOBJECTID',
    '#LOBJECTTYPE', '#LPC', '#LSHARD', '#LSKILL', '#LSPELL', '#LTARGETID',
    '#LTARGETKIND', '#LTARGETTILE', '#LTARGETX', '#LTARGETY', '#LTARGETZ',
    '#LUCK', '#MANA', '#MAXDMG', '#MAXFOL', '#MAXHITS', '#MAXMANA',
    '#MAXSTAM', '#MAXSTATS', '#MENUBUTTON', '#MENURES', '#MINDMG',
    '#NEXTCPOSX', '#NEXTCPOSY', '#NSNAME', '#NSTYPE', '#OPTS', '#OSVER',
    '#PIXCOL', '#PR', '#PROPERTY', '#RANDOM', '#REFORGEDVER', '#RESULT',
    '#RHANDID',
    '#SCNT', '#SCNT2', '#SENDHEADER', '#SEX', '#SHARD', '#SHOPCNT',
    '#SHOPCURPOS', '#SHOPITEMID', '#SHOPITEMMAX', '#SHOPITEMNAME',
    '#SHOPITEMPRICE', '#SHOPITEMTYPE', '#SKILL', '#SKILLCAP', '#SKILLLOCK',
    '#SMC', '#SPC', '#STAMINA', '#STR', '#STRMAX', '#STRRES', '#SYSMSG',
    '#SYSMSGCOL', '#SYSTIME', '#TARGCURS', '#TILECNT', '#TILEFLAGS',
    '#TILENAME', '#TILETYPE', '#TILEZ', '#TIME', '#TP', '#TRUE', '#WEIGHT'
  );

// Populates Hilite's MainRules with the EasyUO script language definition.
// Call once, right after TSynUniSyn.Create -- safe to call on a freshly
// created highlighter only (mirrors LoadFromStream's own "Clear; ..." shape,
// but doesn't call Clear itself since a fresh TSynUniSyn is already empty).
procedure BuildEUOHighlighter(Hilite : TSynUniSyn);

implementation

////////////////////////////////////////////////////////////////////////////////
procedure AddKeywords(Range : TSynRange; const AName : String;
  const AWords : array of String; AFore, ABack : TColor; AStyle : TFontStyles);
var
  Grp : TSynSymbolGroup;
  i   : Integer;
begin
  Grp := TSynSymbolGroup.Create('', Range.AddNewAttribs(AName));
  Grp.Name := AName;
  Grp.Attribs.Foreground := AFore;
  Grp.Attribs.Background := ABack;
  Grp.Attribs.Style := AStyle;
  for i := Low(AWords) to High(AWords) do
    Grp.KeywordsList.Add(AWords[i]);
  Range.AddSymbolGroup(Grp);
end;

////////////////////////////////////////////////////////////////////////////////
function AddChildRange(Parent : TSynRange; const AName, AOpenSym, ACloseSym : String;
  ACloseOnTerm, ACloseOnEol : Boolean; AFore, ABack : TColor; AStyle : TFontStyles) : TSynRange;
begin
  Result := TSynRange.Create(AOpenSym, ACloseSym);
  Result.Name := AName;
  Result.CaseSensitive := True; // see the matching comment on Root in
                                 // BuildEUOHighlighter -- required per-range
                                 // to avoid SynEdit rendering everything in
                                 // this range as uppercase
  Result.CloseOnTerm := ACloseOnTerm;
  Result.CloseOnEol := ACloseOnEol;
  Result.DefaultAttri.Foreground := AFore;
  Result.DefaultAttri.Background := ABack;
  Result.DefaultAttri.Style := AStyle;
  Parent.AddRange(Result);
end;

////////////////////////////////////////////////////////////////////////////////
procedure BuildEUOHighlighter(Hilite : TSynUniSyn);
var
  Root, HexRange : TSynRange;
begin
  Root := Hilite.MainRules;
  Root.Name := 'Root';
  // Delimiters=";" in the original is already covered -- ';' is already
  // part of this component's own DefaultTermSymbols (confirmed directly in
  // synunihighlighter.pas), which every TSynRange gets by default.
  //
  // CaseSensitive:=True is NOT about wanting case-sensitive keyword
  // matching (EasyUO scripts are conventionally uppercase, and the original
  // EUOSyn.hlr's own "False:False." Attributes strings suggest the intent
  // was actually case-INsensitive matching) -- it's a required workaround
  // for a real display bug in this installed SynUniHighlighter version:
  // TSynRange.CaseFunct defaults to @UpCase (confirmed directly in
  // synunihighlighter.pas's TSynRange.Create), and SetLine uses it to build
  // the WORKING line buffer (FLine) that GetTokenEx -- the method SynEdit's
  // own paint routine actually calls to fetch text to draw -- reads from.
  // Left at the default, every character SynEdit renders is silently
  // uppercased on screen (typed text and file content both), even though
  // the real document buffer (Lines/FTrueLine) is untouched underneath.
  // CaseSensitive:=True switches CaseFunct to the identity function
  // (CaseNone), which is the only way to fix this from outside the
  // component -- it can't be patched in place (it's an installed Lazarus
  // package, not part of this project's own source). The cost is real but
  // minor: keyword coloring now only recognizes exact-case matches (a
  // script written in lowercase "if" won't be colored as a Command
  // keyword) -- purely cosmetic, and does not affect script execution at
  // all (that's the separate parser, not the editor's highlighter). Must
  // be set on every range below, not just Root -- CaseFunct is a per-range
  // field, and SetLine uses whichever range is currently active.
  Root.CaseSensitive := True;
  Root.DefaultAttri.Foreground := clNone;
  Root.DefaultAttri.Background := 16777215; // white
  Root.NumberAttri.Foreground := 54528;     // green
  Root.NumberAttri.Background := clNone;

  ////////////////////////////////////////////////////////////////////////////
  AddKeywords(Root, 'Operators', [
    '! ', 'ABS', '* ', '/', '% ', '+', '-', '=', '<>', '>', '<', '<=', '=<',
    '>=', '=>', 'IN', 'NOTIN', '&&', '||', Chr(166)+Chr(166), '.', ','
  ], 255 {red}, 16777215 {white}, []);

  AddKeywords(Root, 'Command', CommandKeywords, 0 {black}, 16777215 {white}, [fsBold]);

  AddKeywords(Root, 'System', SystemKeywords, 12615680 {teal}, 16777215 {white}, []);

  AddKeywords(Root, 'Bracket', [
    '{', '}', '(', ')', '[', ']'
  ], 255 {red}, 16777215 {white}, [fsBold]);

  ////////////////////////////////////////////////////////////////////////////
  AddChildRange(Root, 'Comment', ';', '', False, True,
    8421504 {gray}, 16777215 {white}, [fsItalic]);

  AddChildRange(Root, 'String', '"', '"', False, True,
    54528 {green}, 16777215 {white}, []);

  AddChildRange(Root, 'User', '%', '', True, True,
    12615680 {teal}, 16777215 {white}, []);

  AddChildRange(Root, 'Persistent', '*', '', True, True,
    12615680 {teal}, 16777215 {white}, []);

  AddChildRange(Root, 'Namespace', '!', '', True, True,
    12615680 {teal}, 16777215 {white}, []);

  HexRange := AddChildRange(Root, 'Hex', '$', '', True, True,
    clNone, clNone, []);
  HexRange.NumberAttri.Foreground := 54528; // green -- see header comment:
  HexRange.NumberAttri.Background := clNone; // hex-digit char-set override
                                              // not reproducible here
end;

end.
