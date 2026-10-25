unit eufind;

{
  New addition (not present in the original app): the search behind the
  editor's Find/Replace window (eufinddlg.pas), kept apart from the form so
  the tests can drive it against never-shown TSynEdits. The original used the
  stock Windows find/replace dialogs; the port first used LCL's
  TFindDialog/TReplaceDialog the same way.

  Finding does NOT go through TSynEdit.SearchReplace. SearchReplace starts at
  the caret or searches the editor's current selection, and neither is enough
  here: the Selection scope needs a range that outlives the selection itself
  (the first match found replaces the selection the user made), and
  wrap-around and the walk over every open script need explicit start/end
  points. So FindNext and CountMatches run their own TSynEditSearch -- the
  engine SearchReplace itself uses, set up in the same order SearchReplaceEx
  sets up its own (synedit.pp), with the editor's IdentChars as SynEdit gives
  it the highlighter's -- over Ed.Lines. Replacing still goes through
  SearchReplace: it keeps SynEdit's own regex substitution ($1), the
  OnReplaceText prompt and one undo step per editor.

  Positions are logical (byte) X and 1-based Y, as BlockBegin/BlockEnd and
  SearchReplaceEx use them.

  The window's "every match" highlight is TEuoHighlightAll below, not
  TSynEdit.SetHighlightSearch: SynEdit's own highlight markup restarts each
  search at the end of the previous match (TSynEditMarkupHighlightAll.
  FindMatches, syneditmarkuphighall.pp), so a regex that can match nothing
  (^, x*, ^$) finds the same empty match for ever and hangs the editor on
  its next paint -- which the live highlight reaches while ^ is being typed.
}

{$mode delphi}{$H+}

interface
uses Classes, SysUtils, Types, SynEdit, SynEditTypes, SynEditSearch, SynEditMarkupHighAll;

type
  TFindScope = (fsScript, fsSelection, fsAllScripts);

  TFindSettings = record
    FindText, ReplaceText : String;
    MatchCase, WholeWord, RegExpr, WrapAround, PromptOnReplace, Backwards : Boolean;
    Scope : TFindScope;
  end;

  // What FindNext remembers between calls. RangeEd/MatchEd are only ever
  // compared with live editors, never dereferenced, so a closed tab's stale
  // pointer is harmless.
  TFindState = record
    RangeEd              : TSynEdit;  // Selection scope: the editor the range is in, nil for none
    RangeStart, RangeEnd : TPoint;
    MatchEd              : TSynEdit;  // the span FindNext/ReplaceCurrent selected last
    MatchStart, MatchEnd : TPoint;
  end;

  TFindHit = record
    Index            : Integer;  // into the Editors array
    StartPos, EndPos : TPoint;
    Wrapped          : Boolean;  // went on from the other end
  end;

  // TSynEditMarkupHighlightAll with a FindMatches that steps over empty
  // matches (and paints none) instead of finding the same one for ever. One
  // per editor, owned by its markup manager; see SetFindHighlight.
  TEuoHighlightAll = class(TSynEditMarkupHighlightAll)
  private
    FEd     : TSynEdit;
    FSearch : TSynEditSearch;
  protected
    procedure FindInitialize; override;
    function  FindMatches(AStartPoint, AEndPoint : TPoint; var AIndex : Integer;
                AStopAfterLine : Integer = -1; ABackward : Boolean = False) : TPoint; override;
  public
    constructor Create(Ed : TSynEdit);
    destructor  Destroy; override;
  end;

const
  MaxHistory = 20;

function  SynOptions(const S : TFindSettings) : TSynSearchOptions;
function  CheckPattern(const S : TFindSettings; out Msg : String) : Boolean;
procedure ClearState(out St : TFindState);
procedure CaptureRange(var St : TFindState; Ed : TSynEdit);
function  HasRange(const St : TFindState; Ed : TSynEdit) : Boolean;
function  FindNext(const Editors : array of TSynEdit; Cur : Integer;
            const S : TFindSettings; var St : TFindState; out Hit : TFindHit) : Boolean;
function  CountMatches(const Editors : array of TSynEdit; Cur : Integer;
            const S : TFindSettings; var St : TFindState; out Index : Integer) : Integer;
function  ReplaceCurrent(Ed : TSynEdit; const S : TFindSettings; var St : TFindState) : Boolean;
function  ReplaceAllIn(Ed : TSynEdit; const S : TFindSettings; var St : TFindState;
            out Cancelled : Boolean) : Integer;
procedure AddToHistory(Items : TStrings; const S : String);
procedure SetFindHighlight(Ed : TSynEdit; const Pattern : String; Options : TSynSearchOptions);

implementation
uses Graphics, RegExpr, LazUTF8;

const
  NoPos : TPoint = (X: -1; Y: -1);

////////////////////////////////////////////////////////////////////////////////
function Before(const A, B : TPoint) : Boolean;
begin
  Result:=(A.Y<B.Y) or ((A.Y=B.Y) and (A.X<B.X));
end;

////////////////////////////////////////////////////////////////////////////////
function SamePos(const A, B : TPoint) : Boolean;
begin
  Result:=(A.X=B.X) and (A.Y=B.Y);
end;

////////////////////////////////////////////////////////////////////////////////
function TextEnd(Ed : TSynEdit) : TPoint;
begin
  if Ed.Lines.Count=0 then
    Result:=Point(1,1)
  else
    Result:=Point(Length(Ed.Lines[Ed.Lines.Count-1])+1,Ed.Lines.Count);
end;

////////////////////////////////////////////////////////////////////////////////
// Keeps a stored position inside the text after the text has changed.
function ClampPos(Ed : TSynEdit; const P : TPoint) : TPoint;
begin
  Result:=P;
  if Result.Y<1 then
    Result:=Point(1,1)
  else if Result.Y>Ed.Lines.Count then
    Result:=TextEnd(Ed)
  else if Result.X<1 then
    Result.X:=1
  else if Result.X>Length(Ed.Lines[Result.Y-1])+1 then
    Result.X:=Length(Ed.Lines[Result.Y-1])+1;
end;

////////////////////////////////////////////////////////////////////////////////
// Moves P one character on (back); False at the end (start) of the text.
function StepPos(Lines : TStrings; var P : TPoint; Forward : Boolean) : Boolean;
var
  L : String;
begin
  Result:=True;
  if Forward then
  begin
    L:=Lines[P.Y-1];
    if P.X<=Length(L) then
      Inc(P.X,UTF8CodepointSize(@L[P.X]))
    else if P.Y<Lines.Count then
      P:=Point(1,P.Y+1)
    else
      Result:=False;
  end
  else if P.X>1 then
  begin
    L:=Lines[P.Y-1];
    Dec(P.X);
    while (P.X>1) and ((Byte(L[P.X]) and $C0)=$80) do
      Dec(P.X);
  end
  else if P.Y>1 then
    P:=Point(Length(Lines[P.Y-2])+1,P.Y-1)
  else
    Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
function SynOptions(const S : TFindSettings) : TSynSearchOptions;
begin
  Result:=[];
  if S.MatchCase then Include(Result,ssoMatchCase);
  if S.WholeWord then Include(Result,ssoWholeWord);
  if S.RegExpr   then Include(Result,ssoRegExpr);
  if S.Backwards then Include(Result,ssoBackwards);
end;

////////////////////////////////////////////////////////////////////////////////
// TSynEditSearch raises on a bad regex in the middle of a search; compiling
// it here first, the way TSynEditSearch will (whole word wraps it in \b),
// turns that into a message for the status line -- without the engine's own
// "TRegExpr compile: ParseReg: " in front of it.
function CheckPattern(const S : TFindSettings; out Msg : String) : Boolean;
var
  R : TRegExpr;
  i : Integer;
begin
  Result:=True;
  Msg:='';
  if not S.RegExpr or (S.FindText='') then Exit;
  R:=TRegExpr.Create;
  try
    try
      R.ModifierI:=not S.MatchCase;
      if S.WholeWord then
        R.Expression:='\b'+S.FindText+'\b'
      else
        R.Expression:=S.FindText;
      R.Compile;
    except
      on E : Exception do
      begin
        Result:=False;
        Msg:=E.Message;
        for i:=Length(Msg)-1 downto 1 do
          if (Msg[i]=':') and (Msg[i+1]=' ') and (i+1<Length(Msg)) then
          begin
            Delete(Msg,1,i+1);
            Break;
          end;
      end;
    end;
  finally
    R.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure ClearState(out St : TFindState);
begin
  St.RangeEd:=nil;
  St.RangeStart:=NoPos;
  St.RangeEnd:=NoPos;
  St.MatchEd:=nil;
  St.MatchStart:=NoPos;
  St.MatchEnd:=NoPos;
end;

////////////////////////////////////////////////////////////////////////////////
// Selection scope: Ed's selection becomes the range to search in -- unless it
// is just the match FindNext selected last, which must not shrink the range
// down to that one match.
procedure CaptureRange(var St : TFindState; Ed : TSynEdit);
begin
  if not Ed.SelAvail then Exit;
  if (Ed=St.MatchEd) and SamePos(Ed.BlockBegin,St.MatchStart) and
     SamePos(Ed.BlockEnd,St.MatchEnd) then Exit;
  St.RangeEd:=Ed;
  St.RangeStart:=Ed.BlockBegin;
  St.RangeEnd:=Ed.BlockEnd;
end;

////////////////////////////////////////////////////////////////////////////////
function HasRange(const St : TFindState; Ed : TSynEdit) : Boolean;
begin
  Result:=(Ed<>nil) and (St.RangeEd=Ed);
end;

////////////////////////////////////////////////////////////////////////////////
procedure ScopeBounds(Ed : TSynEdit; const S : TFindSettings; const St : TFindState;
  out B, E : TPoint);
begin
  if S.Scope=fsSelection then
  begin
    B:=ClampPos(Ed,St.RangeStart);
    E:=ClampPos(Ed,St.RangeEnd);
  end
  else
  begin
    B:=Point(1,1);
    E:=TextEnd(Ed);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function NewSearch(const S : TFindSettings) : TSynEditSearch;
begin
  Result:=TSynEditSearch.Create;
  Result.Sensitive:=S.MatchCase;
  Result.Whole:=S.WholeWord;
  Result.Pattern:=S.FindText;
  Result.RegularExpressions:=S.RegExpr;
  Result.Replacement:=S.ReplaceText;
end;

////////////////////////////////////////////////////////////////////////////////
// The first match in [AFrom, ATo] (the last one, backwards). A zero-length
// match (regex ^ or x*) sitting exactly on Skip is passed over, or a
// repeated Find Next would stay on it for ever.
function SearchIn(Srch : TSynEditSearch; Ed : TSynEdit; AFrom, ATo : TPoint;
  Backwards : Boolean; const Skip : TPoint; out FS, FE : TPoint) : Boolean;

  // FindNextOne moves a start past the end of its line on to the next line
  // (FixRange), which at the end of the text is a line that isn't there --
  // where a zero-length regex still "matches". Only a match inside
  // [AFrom, ATo] counts.
  function Search : Boolean;
  begin
    Result:=not Before(ATo,AFrom) and
            Srch.FindNextOne(Ed.Lines,AFrom,ATo,FS,FE,True) and
            not Before(FS,AFrom) and not Before(ATo,FE);
  end;

begin
  FS:=NoPos;
  FE:=NoPos;
  Srch.Backwards:=Backwards;
  Srch.IdentChars:=Ed.IdentChars;
  Result:=Search;
  if Result and SamePos(FS,FE) and SamePos(FS,Skip) then
  begin
    if Backwards then
      Result:=StepPos(Ed.Lines,ATo,False)
    else
      Result:=StepPos(Ed.Lines,AFrom,True);
    Result:=Result and Search;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Same order as SearchReplaceEx's own SetFoundCaretAndSel (synedit.pp):
// the caret goes to the end the search moves on from.
procedure SelectMatch(Ed : TSynEdit; const FS, FE : TPoint; Backwards : Boolean;
  var St : TFindState);
begin
  Ed.BlockBegin:=FS;
  if Backwards then Ed.LogicalCaretXY:=FS;
  Ed.BlockEnd:=FE;
  if not Backwards then Ed.LogicalCaretXY:=FE;
  St.MatchEd:=Ed;
  St.MatchStart:=FS;
  St.MatchEnd:=FE;
end;

////////////////////////////////////////////////////////////////////////////////
// Finds and selects the next match from the selection (or caret) of
// Editors[Cur]: the rest of that script (or of the Selection-scope range);
// for All scripts, the scripts after it, in tab order; then, with
// WrapAround, the scripts before it and the whole of the current one. The
// hit may be in another editor: switching to its tab is the caller's job.
function FindNext(const Editors : array of TSynEdit; Cur : Integer;
  const S : TFindSettings; var St : TFindState; out Hit : TFindHit) : Boolean;
var
  Srch    : TSynEditSearch;
  Ed      : TSynEdit;
  O, B, E : TPoint;
  i       : Integer;
  Back    : Boolean;

  function TryIn(Idx : Integer; const AFrom, ATo, Skip : TPoint; Wrapped : Boolean) : Boolean;
  var
    FS, FE : TPoint;
  begin
    Result:=SearchIn(Srch,Editors[Idx],AFrom,ATo,Back,Skip,FS,FE);
    if not Result then Exit;
    Hit.Index:=Idx;
    Hit.StartPos:=FS;
    Hit.EndPos:=FE;
    Hit.Wrapped:=Wrapped;
    SelectMatch(Editors[Idx],FS,FE,Back,St);
  end;

  function TryWhole(Idx : Integer; Wrapped : Boolean) : Boolean;
  begin
    Result:=TryIn(Idx,Point(1,1),TextEnd(Editors[Idx]),NoPos,Wrapped);
  end;

begin
  Result:=False;
  Hit.Index:=-1;
  Hit.StartPos:=NoPos;
  Hit.EndPos:=NoPos;
  Hit.Wrapped:=False;
  if (S.FindText='') or (Cur<0) or (Cur>High(Editors)) then Exit;
  Ed:=Editors[Cur];
  Back:=S.Backwards;
  if S.Scope=fsSelection then
  begin
    CaptureRange(St,Ed);
    if not HasRange(St,Ed) then Exit;
  end;
  ScopeBounds(Ed,S,St,B,E);

  if Ed.SelAvail then
    if Back then O:=Ed.BlockBegin else O:=Ed.BlockEnd
  else
    O:=Ed.LogicalCaretXY;
  // the range itself still selected, or the caret outside it: start at its edge
  if S.Scope=fsSelection then
    if (Ed.SelAvail and SamePos(Ed.BlockBegin,B) and SamePos(Ed.BlockEnd,E)) or
       Before(O,B) or Before(E,O) then
      if Back then O:=E else O:=B;

  Srch:=NewSearch(S);
  try
    if Back then
      Result:=TryIn(Cur,B,O,O,False)
    else
      Result:=TryIn(Cur,O,E,O,False);

    if not Result and (S.Scope=fsAllScripts) then
    begin
      i:=Cur;
      repeat
        if Back then Dec(i) else Inc(i);
        if (i<0) or (i>High(Editors)) then Break;
        Result:=TryWhole(i,False);
      until Result;
    end;

    if not Result and S.WrapAround then
    begin
      if S.Scope=fsAllScripts then
      begin
        if Back then i:=High(Editors) else i:=0;
        while not Result and (i<>Cur) do
        begin
          Result:=TryWhole(i,True);
          if Back then Dec(i) else Inc(i);
        end;
      end;
      // the whole current script/range: a match the starting point sits
      // inside of is found here too
      if not Result then
        Result:=TryIn(Cur,B,E,NoPos,True);
    end;
  finally
    Srch.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Number of matches in the scope, and Index = the 1-based number of the one
// selected in Editors[Cur] (0 when the selection isn't a match).
function CountMatches(const Editors : array of TSynEdit; Cur : Integer;
  const S : TFindSettings; var St : TFindState; out Index : Integer) : Integer;
var
  Srch                : TSynEditSearch;
  Ed                  : TSynEdit;
  B, E, P, FS, FE     : TPoint;
  i, Lo, Hi           : Integer;
begin
  Result:=0;
  Index:=0;
  if (S.FindText='') or (Cur<0) or (Cur>High(Editors)) then Exit;
  if S.Scope=fsSelection then
  begin
    CaptureRange(St,Editors[Cur]);
    if not HasRange(St,Editors[Cur]) then Exit;
  end;
  if S.Scope=fsAllScripts then
  begin
    Lo:=0;
    Hi:=High(Editors);
  end
  else
  begin
    Lo:=Cur;
    Hi:=Cur;
  end;
  Srch:=NewSearch(S);
  try
    for i:=Lo to Hi do
    begin
      Ed:=Editors[i];
      ScopeBounds(Ed,S,St,B,E);
      P:=B;
      while SearchIn(Srch,Ed,P,E,False,NoPos,FS,FE) do
      begin
        Inc(Result);
        if (i=Cur) and SamePos(FS,Ed.BlockBegin) and SamePos(FE,Ed.BlockEnd) then
          Index:=Result;
        P:=FE;
        if SamePos(FS,FE) and not StepPos(Ed.Lines,P,True) then Break;
      end;
    end;
  finally
    Srch.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Replaces the selection if it is exactly a match (what Find Next selected),
// through SearchReplace limited to that selection, so regex $1 and undo work
// as SynEdit does them. SynEdit leaves the replacement selected; that span is
// recorded as "ours" so the Selection scope doesn't take it for a new range.
function ReplaceCurrent(Ed : TSynEdit; const S : TFindSettings; var St : TFindState) : Boolean;
var
  Srch   : TSynEditSearch;
  FS, FE : TPoint;
begin
  Result:=False;
  if (S.FindText='') or not Ed.SelAvail then Exit;
  Srch:=NewSearch(S);
  try
    if not (SearchIn(Srch,Ed,Ed.BlockBegin,Ed.BlockEnd,False,NoPos,FS,FE) and
            SamePos(FS,Ed.BlockBegin) and SamePos(FE,Ed.BlockEnd)) then Exit;
  finally
    Srch.Free;
  end;
  Result:=Ed.SearchReplace(S.FindText,S.ReplaceText,
            SynOptions(S)-[ssoBackwards]+[ssoReplace,ssoSelectedOnly])>0;
  if not Result then Exit;
  // keep the Selection-scope range covering the same text
  if (St.RangeEd=Ed) and not Before(St.RangeEnd,FE) then
  begin
    if St.RangeEnd.Y=FE.Y then
      St.RangeEnd.X:=St.RangeEnd.X-FE.X+Ed.BlockEnd.X;
    Inc(St.RangeEnd.Y,Ed.BlockEnd.Y-FE.Y);
  end;
  St.MatchEd:=Ed;
  St.MatchStart:=Ed.BlockBegin;
  St.MatchEnd:=Ed.BlockEnd;
end;

////////////////////////////////////////////////////////////////////////////////
// SearchReplace's result counts every match it stopped at, skipped and
// cancelled ones included. With prompting on, this sits in front of the
// editor's own OnReplaceText and counts the real replacements.
type
  TReplaceCounter = class
  private
    FEd       : TSynEdit;
    FOrig     : TReplaceTextEvent;
    FAsked    : Integer;
    FReplaced : Integer;
    FAllFrom  : Integer;  // the prompt answered "Yes to All", 0 for none
    FCancelled : Boolean;
    procedure ReplaceText(Sender : TObject; const ASearch, AReplace : String;
                Line, Column : Integer; var ReplaceAction : TSynReplaceAction);
  public
    constructor Create(Ed : TSynEdit);
    destructor  Destroy; override;
    function    Replaced(Found : Integer) : Integer;
  end;

constructor TReplaceCounter.Create(Ed : TSynEdit);
begin
  inherited Create;
  FEd:=Ed;
  FOrig:=Ed.OnReplaceText;
  Ed.OnReplaceText:=ReplaceText;
end;

destructor TReplaceCounter.Destroy;
begin
  FEd.OnReplaceText:=FOrig;
  inherited Destroy;
end;

procedure TReplaceCounter.ReplaceText(Sender : TObject; const ASearch, AReplace : String;
  Line, Column : Integer; var ReplaceAction : TSynReplaceAction);
begin
  Inc(FAsked);
  FOrig(Sender,ASearch,AReplace,Line,Column,ReplaceAction);
  case ReplaceAction of
    raReplace    : Inc(FReplaced);
    raReplaceAll : FAllFrom:=FAsked;
    raCancel     : FCancelled:=True;
  end;
end;

function TReplaceCounter.Replaced(Found : Integer) : Integer;
begin
  Result:=FReplaced;
  if FAllFrom>0 then
    Inc(Result,Found-FAllFrom+1);
end;

////////////////////////////////////////////////////////////////////////////////
// Replaces every match in Ed (the whole script, or the Selection-scope range)
// as one undo step, and returns how many were replaced; Cancelled says the
// prompt was answered Cancel. The range is selected again afterwards; its end
// is re-derived from the untouched text after it.
function ReplaceAllIn(Ed : TSynEdit; const S : TFindSettings; var St : TFindState;
  out Cancelled : Boolean) : Integer;
var
  Opts                  : TSynSearchOptions;
  B, E                  : TPoint;
  LinesAfter, CharsAfter : Integer;
  Prompted              : Boolean;
  Counter               : TReplaceCounter;
  Found                 : Integer;
begin
  Result:=0;
  Cancelled:=False;
  if S.FindText='' then Exit;
  Opts:=SynOptions(S)-[ssoBackwards]+[ssoReplace,ssoReplaceAll,ssoEntireScope];
  LinesAfter:=0;
  CharsAfter:=0;
  if S.Scope=fsSelection then
  begin
    CaptureRange(St,Ed);
    if not HasRange(St,Ed) then Exit;
    B:=ClampPos(Ed,St.RangeStart);
    E:=ClampPos(Ed,St.RangeEnd);
    if not Before(B,E) then Exit;
    LinesAfter:=Ed.Lines.Count-E.Y;
    CharsAfter:=Length(Ed.Lines[E.Y-1])+1-E.X;
    Ed.BlockBegin:=B;
    Ed.BlockEnd:=E;
    Include(Opts,ssoSelectedOnly);
  end;

  Prompted:=S.PromptOnReplace and Assigned(Ed.OnReplaceText);
  if Prompted then Include(Opts,ssoPrompt);
  Counter:=nil;
  if Prompted then Counter:=TReplaceCounter.Create(Ed);
  try
    Found:=Ed.SearchReplace(S.FindText,S.ReplaceText,Opts);
    if Prompted then
    begin
      Result:=Counter.Replaced(Found);
      Cancelled:=Counter.FCancelled;
    end
    else
      Result:=Found;
  finally
    Counter.Free;
  end;

  if S.Scope=fsSelection then
  begin
    St.RangeStart:=B;
    St.RangeEnd.Y:=Ed.Lines.Count-LinesAfter;
    St.RangeEnd.X:=Length(Ed.Lines[St.RangeEnd.Y-1])+1-CharsAfter;
    Ed.BlockBegin:=St.RangeStart;
    Ed.BlockEnd:=St.RangeEnd;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Most recent first, no duplicates (exact match: case matters, as it may for
// the search), at most MaxHistory entries.
procedure AddToHistory(Items : TStrings; const S : String);
var
  i : Integer;
begin
  if S='' then Exit;
  for i:=Items.Count-1 downto 0 do
    if Items[i]=S then
      Items.Delete(i);
  Items.Insert(0,S);
  while Items.Count>MaxHistory do
    Items.Delete(Items.Count-1);
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

// Pale yellow behind the syntax colours. SynEdit's own highlight-all default
// is the selection colour, which makes every match look selected.
constructor TEuoHighlightAll.Create(Ed : TSynEdit);
begin
  inherited Create(Ed);
  FEd:=Ed;
  FSearch:=TSynEditSearch.Create;
  MarkupInfo.Background:=RGBToColor(255,236,140);
  MarkupInfo.Foreground:=clNone;
  Ed.MarkupManager.AddMarkUp(Self);
end;

////////////////////////////////////////////////////////////////////////////////
destructor TEuoHighlightAll.Destroy;
begin
  FSearch.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
// As TSynEditMarkupHighlightAll's own, plus the editor's IdentChars (as
// SearchReplace has them) so Whole word agrees with Find Next.
procedure TEuoHighlightAll.FindInitialize;
begin
  FSearch.Pattern:=SearchString;
  FSearch.Sensitive:=ssoMatchCase in SearchOptions;
  FSearch.Whole:=ssoWholeWord in SearchOptions;
  FSearch.RegularExpressions:=ssoRegExpr in SearchOptions;
  FSearch.RegExprMultiLine:=ssoRegExprMultiLine in SearchOptions;
  FSearch.Backwards:=False;
  FSearch.IdentChars:=FEd.IdentChars;
end;

////////////////////////////////////////////////////////////////////////////////
// TSynEditMarkupHighlightAll.FindMatches, except for an empty match: there is
// nothing to paint, and the next search starts one character past it. The
// step is taken from the range's own end, and only moves it inwards:
// FindNextOne pushes an end on an empty line on to the next line (FixRange),
// so an empty match it finds there can lie outside the range, and stepping
// back from that match would find it again for ever.
function TEuoHighlightAll.FindMatches(AStartPoint, AEndPoint : TPoint; var AIndex : Integer;
  AStopAfterLine : Integer; ABackward : Boolean) : TPoint;
var
  FS, FE : TPoint;
begin
  FSearch.Backwards:=ABackward;
  while not Before(AEndPoint,AStartPoint) and
        FSearch.FindNextOne(Lines,AStartPoint,AEndPoint,FS,FE) do
  begin
    if SamePos(FS,FE) then
    begin
      if FS.Y>Lines.Count then Break;
      if ABackward then
      begin
        if Before(FS,AEndPoint) then AEndPoint:=FS;
        if not StepPos(Lines,AEndPoint,False) then Break;
      end
      else
      begin
        if Before(AStartPoint,FS) then AStartPoint:=FS;
        if not StepPos(Lines,AStartPoint,True) then Break;
      end;
      Continue;
    end;
    AStartPoint:=FE;
    Matches.Insert(AIndex,FS,FE);
    Inc(AIndex);
    if (AStopAfterLine>=0) and (FS.Y>AStopAfterLine) then
    begin
      AEndPoint:=FE;
      Break;
    end;
  end;
  Result:=AEndPoint;
end;

////////////////////////////////////////////////////////////////////////////////
// The Find window's "every match" highlight on Ed, in place of
// Ed.SetHighlightSearch (same arguments); an empty Pattern clears it. The
// markup is added to Ed the first time and stays, owned by Ed.
procedure SetFindHighlight(Ed : TSynEdit; const Pattern : String; Options : TSynSearchOptions);
var
  M : TEuoHighlightAll;
begin
  M:=TEuoHighlightAll(Ed.MarkupByClass[TEuoHighlightAll]);
  if M=nil then
  begin
    if Pattern='' then Exit;
    M:=TEuoHighlightAll.Create(Ed);
  end;
  M.SearchOptions:=Options;
  M.SearchString:=Pattern;
end;

end.
