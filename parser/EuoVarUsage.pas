unit EuoVarUsage;

{
  Port addition (not present in the original app): what the editor's Watches panel
  (easyuo\euwatch.pas) lists and marks. EasyUO 1.42 had watches and showed how a script's variables
  changed while stepping; the 1.5 source this port comes from had dropped both. A pure unit like
  EuoOutline.pas -- text and names in, lists out -- so it is unit-testable and sits at parser's lowest
  layer. The interpreter is NOT touched; what counts as a variable is read off it:

  - The variables a script uses (EuoScriptVarNames) are the words the interpreter substitutes:
    EuoScriptWords.IsVar, the test ParseLine makes, on the words ScanLineWords splits (spaces and tabs;
    a word starting with ';' ends the line), after JoinContinuation has joined the '+' lines. So '%',
    '!', '*' and '#' names, as written, outside comments. A name glued to another ("%list . %i",
    "abc%x") is only known at run time: the panel gets those from the run itself
    (TEuoInterpreter.GetUserVarNames).
  - '#' names the interpreter does not have read N/A and are left out (when the known names are
    given), and so are the constants #TRUE, #FALSE, #SPC, #SMC and #DOT, which never change.
  - Names are compared ignoring case, as the interpreter does; the first spelling met is kept.
  - EuoMergeVarNames is the order the panel shows: '%', then '!', '*' and '#' names, each A-Z
    ignoring case; a name written in the script keeps that spelling over the stored upper-case one.
  - EuoVarAt is the variable at a column of a line, for Add Watch at the caret.
  - EuoWatchesToText / EuoWatchesFromText are how a watch list is saved: the names separated by
    spaces (a variable name has none). Reading keeps only IsVar words, once each.
  - TEuoVarChanges keeps the values of the previous pause and says which changed: a name it had not
    seen counts as N/A, the value an unset variable reads.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

// The variables Lines uses, each once, in the order they first appear (see the header). SysNames
// holds the interpreter's '#' names without their '#' (TEuoInterpreter.GetVariableNames); nil
// keeps every '#' word but the constants.
procedure EuoScriptVarNames(Lines : TStrings; SysNames : TStrings; Names : TStrings);

// Written and Runtime together, each name once, in the panel's order (see the header).
procedure EuoMergeVarNames(Written, Runtime : TStrings; Names : TStrings);

// -1, 0 or 1: A before, with or after B in the panel's order.
function  EuoCompareVarNames(const A, B : String) : Integer;

// The variable at the 1-based column Col of Line (the character there, or the one before it, as a
// caret right after a name sits), or '' when there is none.
function  EuoVarAt(const Line : String; Col : Integer) : String;

function  EuoWatchesToText(Names : TStrings) : String;
procedure EuoWatchesFromText(const S : String; Names : TStrings);

type
  TEuoVarChanges = class(TObject)
  private
    FBase : TStringList;   // name#1value, the previous pause's values
    FOld  : TStringList;   // name#1value, the old value of each name that changed
    procedure Store(List : TStringList; const Name, Value : String);
  public
    constructor Create;
    destructor  Destroy; override;
    // A new run: Values (Values[i] is Names[i]'s) are the baseline, nothing has changed.
    procedure NewRun(Names, Values : TStrings);
    // A new pause: the names whose value differs from the baseline's have changed; Values become
    // the baseline.
    procedure NewPause(Names, Values : TStrings);
    // Name now has Value in the baseline (a watch added, a value set while paused), so the next
    // pause compares with it. What changed at this pause stays as it is.
    procedure Remember(const Name, Value : String);
    // Nothing has changed (the script runs on, or stopped).
    procedure ClearChanges;
    function  IsChanged(const Name : String; out Old : String) : Boolean;
    function  ChangedCount : Integer;
  end;

const
  EuoUnsetValue = 'N/A';

implementation

uses
  EuoScriptWords;

const
  NameChars = ['0'..'9','A'..'Z','a'..'z','_'];
  Sigils    = ['!','%','*','#'];
  ConstVars : array[0..4] of String = ('TRUE','FALSE','SPC','SMC','DOT');

////////////////////////////////////////////////////////////////////////////////
function IsConstVar(const NameU : String) : Boolean;
var
  Cnt : Integer;
begin
  Result:=True;
  for Cnt:=0 to High(ConstVars) do
    if NameU=ConstVars[Cnt] then Exit;
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
procedure EuoScriptVarNames(Lines : TStrings; SysNames : TStrings; Names : TStrings);
var
  Known : TStringList;
  Seen  : TStringList;
  Words : TEuoWords;
  Line  : String;
  i, w  : Integer;
  W1    : String;
  NameU : String;
begin
  Known:=nil;
  Seen:=TStringList.Create;
  try
    Seen.Sorted:=True;
    Seen.CaseSensitive:=False;
    if SysNames<>nil then
    begin
      Known:=TStringList.Create;
      Known.CaseSensitive:=False;
      Known.Assign(SysNames);
      Known.Sorted:=True;
    end;

    i:=0;
    while i<Lines.Count do
    begin
      Line:=JoinContinuation(Lines,i);
      ScanLineWords(Line,Words);
      for w:=0 to High(Words) do
      begin
        W1:=Words[w].Text;
        if not IsVar(W1) then Continue;
        if Seen.IndexOf(W1)>=0 then Continue;
        if W1[1]='#' then
        begin
          NameU:=UpperCase(Copy(W1,2,MaxInt));
          if IsConstVar(NameU) then Continue;
          if (Known<>nil) and (Known.IndexOf(NameU)<0) then Continue;
        end;
        Seen.Add(W1);
        Names.Add(W1);
      end;
    end;
  finally
    Seen.Free;
    Known.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function KindRank(const S : String) : Integer;
begin
  Result:=4;
  if S='' then Exit;
  case S[1] of
    '%' : Result:=0;
    '!' : Result:=1;
    '*' : Result:=2;
    '#' : Result:=3;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function EuoCompareVarNames(const A, B : String) : Integer;
begin
  Result:=KindRank(A)-KindRank(B);
  if Result=0 then Result:=CompareText(A,B);
  if Result<0 then Result:=-1
  else if Result>0 then Result:=1;
end;

function CompareVarItems(List : TStringList; Index1, Index2 : Integer) : Integer;
begin
  Result:=EuoCompareVarNames(List[Index1],List[Index2]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure EuoMergeVarNames(Written, Runtime : TStrings; Names : TStrings);
var
  All : TStringList;
  Idx : TStringList;  // sorted, case-insensitive: what All holds
  Cnt : Integer;

  procedure AddName(const S : String);
  begin
    if S='' then Exit;
    if Idx.IndexOf(S)>=0 then Exit;
    Idx.Add(S);
    All.Add(S);
  end;

begin
  All:=TStringList.Create;
  Idx:=TStringList.Create;
  try
    Idx.Sorted:=True;
    Idx.CaseSensitive:=False;
    if Written<>nil then
      for Cnt:=0 to Written.Count-1 do AddName(Written[Cnt]);
    if Runtime<>nil then
      for Cnt:=0 to Runtime.Count-1 do AddName(Runtime[Cnt]);
    All.CustomSort(CompareVarItems);
    Names.AddStrings(All);
  finally
    Idx.Free;
    All.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function EuoVarAt(const Line : String; Col : Integer) : String;
var
  Len, P, S, E : Integer;
begin
  Result:='';
  Len:=Length(Line);
  if Len=0 then Exit;
  P:=Col;
  if (P<1) or (P>Len) or not (Line[P] in Sigils+NameChars) then
  begin
    P:=Col-1;
    if (P<1) or (P>Len) or not (Line[P] in Sigils+NameChars) then Exit;
  end;

  if Line[P] in Sigils then S:=P
  else begin
    S:=P;
    while (S>1) and (Line[S-1] in NameChars) do Dec(S);
    if (S>1) and (Line[S-1] in Sigils) then Dec(S)
    else Exit;
  end;

  E:=S+1;
  while (E<=Len) and (Line[E] in NameChars) do Inc(E);
  Result:=Copy(Line,S,E-S);
  if not IsVar(Result) then Result:='';
end;

////////////////////////////////////////////////////////////////////////////////
function EuoWatchesToText(Names : TStrings) : String;
var
  Cnt : Integer;
begin
  Result:='';
  for Cnt:=0 to Names.Count-1 do
  begin
    if Result<>'' then Result:=Result+' ';
    Result:=Result+Names[Cnt];
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure EuoWatchesFromText(const S : String; Names : TStrings);
var
  i, Start : Integer;
  W        : String;

  function Has(const N : String) : Boolean;
  var
    k : Integer;
  begin
    Result:=True;
    for k:=0 to Names.Count-1 do
      if CompareText(Names[k],N)=0 then Exit;
    Result:=False;
  end;

begin
  i:=1;
  while i<=Length(S) do
  begin
    while (i<=Length(S)) and (S[i] in [#0..' ']) do Inc(i);
    Start:=i;
    while (i<=Length(S)) and not (S[i] in [#0..' ']) do Inc(i);
    if i>Start then
    begin
      W:=Copy(S,Start,i-Start);
      if IsVar(W) and not Has(W) then Names.Add(W);
    end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
/// TEuoVarChanges /////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function NewValueList : TStringList;
begin
  Result:=TStringList.Create;
  Result.NameValueSeparator:=#1;   // a value may hold '='; a name never holds #1
  Result.CaseSensitive:=False;
end;

constructor TEuoVarChanges.Create;
begin
  inherited Create;
  FBase:=NewValueList;
  FOld:=NewValueList;
end;

destructor TEuoVarChanges.Destroy;
begin
  FBase.Free;
  FOld.Free;
  inherited;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVarChanges.Store(List : TStringList; const Name, Value : String);
var
  i : Integer;
begin
  i:=List.IndexOfName(Name);
  if i>=0 then List[i]:=Name+#1+Value
  else List.Add(Name+#1+Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVarChanges.NewRun(Names, Values : TStrings);
var
  Cnt : Integer;
begin
  FBase.Clear;
  FOld.Clear;
  for Cnt:=0 to Names.Count-1 do
    Store(FBase,Names[Cnt],Values[Cnt]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVarChanges.NewPause(Names, Values : TStrings);
var
  Cnt, i : Integer;
  Old    : String;
begin
  FOld.Clear;
  for Cnt:=0 to Names.Count-1 do
  begin
    i:=FBase.IndexOfName(Names[Cnt]);
    if i>=0 then Old:=FBase.ValueFromIndex[i]
    else Old:=EuoUnsetValue;
    if Old<>Values[Cnt] then Store(FOld,Names[Cnt],Old);
  end;
  FBase.Clear;
  for Cnt:=0 to Names.Count-1 do
    Store(FBase,Names[Cnt],Values[Cnt]);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVarChanges.Remember(const Name, Value : String);
begin
  Store(FBase,Name,Value);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoVarChanges.ClearChanges;
begin
  FOld.Clear;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoVarChanges.IsChanged(const Name : String; out Old : String) : Boolean;
var
  i : Integer;
begin
  i:=FOld.IndexOfName(Name);
  Result:=i>=0;
  if Result then Old:=FOld.ValueFromIndex[i]
  else Old:='';
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoVarChanges.ChangedCount : Integer;
begin
  Result:=FOld.Count;
end;

end.
