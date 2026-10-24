unit eufoldsyn;

{
  Code folding for the script editor -- a new addition, not present in the
  original Delphi 7 app at all.

  SynEdit folds only through a TSynCustomFoldHighlighter, and TSynUniSyn (the
  highlighter eusyntax.pas builds) derives from plain TSynCustomHighlighter, so
  it has no folding of its own. Rather than re-implement the coloring, TSynEUOSyn
  is a fold highlighter that WRAPS a private TSynUniSyn built by the unchanged
  BuildEUOHighlighter: every token method is forwarded to it, so what the editor
  colors is exactly what it colored before, and eusyntax.pas stays untouched.

  What folds, and where each block ends, comes from EuoBlocks.pas's
  EuoBlockStep -- the same rules Edit > Format Script indents by (see that
  unit's header for how each rule is read off the interpreter):
  - brace blocks: the fold marker sits on the opening-brace line, which EasyUO
    requires to be the line below its IF/ELSE/FOR/WHILE (collapsed, the
    header line stays visible above the brace line and its "[...]" marker);
  - subs: from SUB through the RETURN that ends it (or the closing brace of a
    braced sub). A sub left open by the next SUB folds up to the line before
    it: TSynCustomFoldHighlighter.FoldLineLength keeps a line visible when it
    both closes one fold and opens another;
  - REPEAT ... UNTIL.
  Blocks still open at the end of the script close on its last line (the base
  class reports level 0 there).

  State between lines: the fold-block stack itself (SynEdit's own, inspected
  with TopCodeFoldBlockType -- block types are Pointer(Ord(TEuoBlockKind))),
  the wrapped highlighter's current TSynRange (kept in RangeType, the pattern
  of Lazarus's own examples\SynEdit\NewHighlighterTutorial\foldhl.pas), and
  EuoBlockStep's Pending (in TSynEUORange, compared and copied with the rest so
  SynEdit's rescan stops at the right line).

  One inherited, pre-existing issue worth knowing about: the installed
  TSynUniSyn.SetLine GetMem's a working copy of every line it is given and
  never frees it. Wrapping it changes nothing there (the same lines are
  scanned as before); it is in the installed Lazarus package, not this
  project's source.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SynEditTypes, SynEditHighlighter, SynEditHighlighterFoldBase,
  SynUniHighlighter, EuoBlocks;

type
  TSynEUORange = class(TSynCustomHighlighterRange)
  private
    FPending : TEuoBodyPending;
  public
    function  Compare(Range : TSynCustomHighlighterRange) : Integer; override;
    procedure Assign(Src : TSynCustomHighlighterRange); override;
    procedure Clear; override;
    property  Pending : TEuoBodyPending read FPending write FPending;
  end;

  TSynEUOSyn = class(TSynCustomFoldHighlighter)
  private
    FInner  : TSynUniSyn;
    FCmdX1  : Integer;  // 0-based bounds of the line's command word, for the
    FCmdX2  : Integer;  // fold nodes SetLine creates (see GetTokenBounds)
    function EUORange : TSynEUORange;
  protected
    function  GetRangeClass : TSynCustomHighlighterRangeClass; override;
    function  GetIdentChars : TSynIdentChars; override;
    procedure GetTokenBounds(out LogX1, LogX2 : Integer); override;
  public
    constructor Create(AOwner : TComponent); override;
    destructor  Destroy; override;
    class function GetLanguageName : String; override;
    procedure SetLine(const NewValue : String; LineNumber : Integer); override;
    procedure Next; override;
    function  GetEol : Boolean; override;
    procedure GetTokenEx(out TokenStart : PChar; out TokenLength : Integer); override;
    function  GetToken : String; override;
    function  GetTokenPos : Integer; override;
    function  GetTokenKind : Integer; override;
    function  GetTokenAttribute : TSynHighlighterAttributes; override;
    function  GetDefaultAttribute(Index : Integer) : TSynHighlighterAttributes; override;
    function  GetRange : Pointer; override;
    procedure SetRange(Value : Pointer); override;
    procedure ResetRange; override;
    property  Inner : TSynUniSyn read FInner;
  end;

implementation

uses
  eusyntax;

////////////////////////////////////////////////////////////////////////////////
function TSynEUORange.Compare(Range : TSynCustomHighlighterRange) : Integer;
begin
  Result:=inherited Compare(Range);
  if Result<>0 then Exit;
  Result:=Ord(FPending)-Ord(TSynEUORange(Range).FPending);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSynEUORange.Assign(Src : TSynCustomHighlighterRange);
begin
  inherited Assign(Src);
  if Src is TSynEUORange then
    FPending:=TSynEUORange(Src).FPending
  else
    FPending:=ebpNone;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSynEUORange.Clear;
begin
  inherited Clear;
  FPending:=ebpNone;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TSynEUOSyn.Create(AOwner : TComponent);
begin
  // Built before inherited Create so no virtual call made from there can ever
  // see FInner unassigned.
  FInner:=TSynUniSyn.Create(nil);
  BuildEUOHighlighter(FInner);
  inherited Create(AOwner);
end;

////////////////////////////////////////////////////////////////////////////////
destructor TSynEUOSyn.Destroy;
begin
  inherited Destroy;
  FInner.Free;
end;

////////////////////////////////////////////////////////////////////////////////
class function TSynEUOSyn.GetLanguageName : String;
begin
  Result:='EasyUO';
end;

////////////////////////////////////////////////////////////////////////////////
function TSynEUOSyn.EUORange : TSynEUORange;
begin
  Result:=TSynEUORange(CodeFoldRange);
end;

////////////////////////////////////////////////////////////////////////////////
function TSynEUOSyn.GetRangeClass : TSynCustomHighlighterRangeClass;
begin
  Result:=TSynEUORange;
end;

////////////////////////////////////////////////////////////////////////////////
// The same formula TSynUniSyn.GetIdentChars uses (it is protected there).
function TSynEUOSyn.GetIdentChars : TSynIdentChars;
begin
  Result:=[#32..#255]-TSynRange(FInner.GetRange).TermSymbols;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSynEUOSyn.GetTokenBounds(out LogX1, LogX2 : Integer);
begin
  LogX1:=FCmdX1;
  LogX2:=FCmdX2;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSynEUOSyn.SetLine(const NewValue : String; LineNumber : Integer);
var
  Stack : array of TEuoBlockKind;
  Step  : TEuoLineStep;
  Cnt   : Integer;
begin
  inherited; // keeps NewValue alive for FInner's PChar, resets the line's minimum fold level
  FInner.SetLine(NewValue,LineNumber);

  SetLength(Stack,CodeFoldRange.CodeFoldStackSize);
  for Cnt:=0 to High(Stack) do
    Stack[High(Stack)-Cnt]:=TEuoBlockKind(PtrUInt(TopCodeFoldBlockType(Cnt)));

  Step:=EuoBlockStep(NewValue,EUORange.Pending,Stack);
  if Step.IsContinuation then Exit;

  FCmdX1:=0;
  while (FCmdX1<Length(NewValue)) and (NewValue[FCmdX1+1]<=' ') do Inc(FCmdX1);
  FCmdX2:=FCmdX1+Length(Step.Cmd);

  for Cnt:=1 to Step.Closes do
    EndCodeFoldBlock;
  if Step.Opens<>ebkNone then
    StartCodeFoldBlock(Pointer(PtrUInt(Ord(Step.Opens))));
  EUORange.Pending:=Step.Pending;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSynEUOSyn.Next;
begin
  FInner.Next;
end;

////////////////////////////////////////////////////////////////////////////////
function TSynEUOSyn.GetEol : Boolean;
begin
  Result:=FInner.GetEol;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSynEUOSyn.GetTokenEx(out TokenStart : PChar; out TokenLength : Integer);
begin
  FInner.GetTokenEx(TokenStart,TokenLength);
end;

////////////////////////////////////////////////////////////////////////////////
function TSynEUOSyn.GetToken : String;
begin
  Result:=FInner.GetToken;
end;

////////////////////////////////////////////////////////////////////////////////
function TSynEUOSyn.GetTokenPos : Integer;
begin
  Result:=FInner.GetTokenPos;
end;

////////////////////////////////////////////////////////////////////////////////
function TSynEUOSyn.GetTokenKind : Integer;
begin
  Result:=FInner.GetTokenKind;
end;

////////////////////////////////////////////////////////////////////////////////
function TSynEUOSyn.GetTokenAttribute : TSynHighlighterAttributes;
begin
  Result:=FInner.GetTokenAttribute;
end;

////////////////////////////////////////////////////////////////////////////////
function TSynEUOSyn.GetDefaultAttribute(Index : Integer) : TSynHighlighterAttributes;
begin
  Result:=FInner.GetDefaultAttribute(Index);
end;

////////////////////////////////////////////////////////////////////////////////
function TSynEUOSyn.GetRange : Pointer;
begin
  CodeFoldRange.RangeType:=FInner.GetRange;
  Result:=inherited GetRange;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSynEUOSyn.SetRange(Value : Pointer);
begin
  inherited SetRange(Value);
  if CodeFoldRange.RangeType<>nil then
    FInner.SetRange(CodeFoldRange.RangeType)
  else
    FInner.ResetRange;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TSynEUOSyn.ResetRange;
begin
  inherited ResetRange;
  FInner.ResetRange;
end;

end.
