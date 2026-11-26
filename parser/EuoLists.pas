unit EuoLists;

{
  Port addition (LIST): a script's named lists, with no interpreter. TEuoInterpreter.ListProc gives them
  their words and puts each answer in #ListRes. EasyUO 1.6 planned such a command but never shipped it
  (easyuo.exe 1.6.0.337 has no LIST command and no #ListRes), so the design is Reforged's own; the
  reference is the site's commands/list.md.

  - A list is an ordered run of values (texts), 1-based. Names ignore case; the first spelling a list was
    made with is kept for display (the editor's Watches panel, VarDump).
  - A list with no values does not exist: emptying one forgets it, and a name never used reads as an empty
    list. So Count is 0 for both, and the editor never shows an empty list.
  - Every comparison ignores case and never reads the Windows locale: values are upper-cased (UpperCase is
    ASCII only) and compared byte by byte, as the timer formats never read Windows settings either.
  - IndexOf: the first value from From on equal to Value. FindText: the first that contains Text. 0 = none.
  - Sort is stable. lsAuto sorts by number when every value is a whole number as arithmetic reads it
    (EuoConversion.SToI64Def, what TParList's IntValid uses), else as text; lsNumber reads a text as 0, as
    arithmetic does.
  - Split cuts a text at every Sep, matched ignoring case as STR PART does (EuoStrOps.StrField); empty fields
    are kept, and an empty text gives an empty list.
  - Merge, Intersect and Subtract never change their inputs: the result is built apart, then stored under the
    new name, which may be one of the inputs. A result holds each value once (the first spelling met is kept),
    except Merge with KeepDuplicates, which keeps every value of every list in order.
}

{$mode delphi}{$H+}

interface

uses
  SysUtils, Classes, StrUtils, EuoConversion;

type
  TEuoListSort = (lsAuto, lsText, lsNumber);

  // One list's values, with the name as it was first spelled.
  TEuoListValues = class(TStringList)
  public
    Name : String;
  end;

  TEuoLists = class(TObject)
  private
    FNames : TStringList;            // upper-case names, sorted, byte compare; Objects -> TEuoListValues
    function  Lookup(const Name : String) : TEuoListValues;
    function  Make(const Name : String) : TEuoListValues;
    procedure Store(const Name : String; Values : TEuoListValues);
  public
    constructor Create;
    destructor  Destroy; override;
    function    Count(const Name : String) : Integer;
    function    Get(const Name : String; Index : Integer; out Value : String) : Boolean;
    function    Add(const Name, Value : String) : Integer;
    function    Insert(const Name : String; Index : Integer; const Value : String) : Boolean;
    function    SetValue(const Name : String; Index : Integer; const Value : String) : Boolean;
    function    Delete(const Name : String; Index : Integer) : Boolean;
    function    IndexOf(const Name, Value : String; From : Integer) : Integer;
    function    FindText(const Name, Text : String; From : Integer) : Integer;
    procedure   Forget(const Name : String);
    function    Clone(const Name, Source : String) : Integer;
    function    Sort(const Name : String; Mode : TEuoListSort; Down : Boolean) : Integer;
    function    Split(const Name, Text, Sep : String) : Integer;
    function    Join(const Name, Sep : String) : String;
    function    Merge(const Name : String; Sources : TStrings; KeepDuplicates : Boolean) : Integer;
    function    Intersect(const Name : String; Sources : TStrings) : Integer;
    function    Subtract(const Name, Source, Other : String) : Integer;
    procedure   SetValues(const Name : String; Values : TStrings);
    procedure   Clear;
    procedure   Names(List : TStrings);
    procedure   Values(const Name : String; List : TStrings);
    function    ListCount : Integer;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
// A set of upper-cased values: sorted, byte compare, so a lookup never reads the locale.
function NewValueSet : TStringList;
begin
  Result:=TStringList.Create;
  Result.UseLocale:=False;
  Result.CaseSensitive:=True;
  Result.Sorted:=True;
  Result.Duplicates:=dupIgnore;
end;

function InSet(S : TStringList; const Value : String) : Boolean;
var
  i : Integer;
begin
  Result:=S.Find(UpperCase(Value),i);
end;

////////////////////////////////////////////////////////////////////////////////
constructor TEuoLists.Create;
begin
  inherited Create;
  FNames:=NewValueSet;
end;

destructor TEuoLists.Destroy;
begin
  Clear;
  FNames.Free;
  inherited;
end;

function TEuoLists.Lookup(const Name : String) : TEuoListValues;
var
  i : Integer;
begin
  Result:=nil;
  if FNames.Find(UpperCase(Name),i) then Result:=TEuoListValues(FNames.Objects[i]);
end;

function TEuoLists.Make(const Name : String) : TEuoListValues;
begin
  Result:=Lookup(Name);
  if Result<>nil then Exit;
  Result:=TEuoListValues.Create;
  Result.Name:=Name;
  FNames.AddObject(UpperCase(Name),Result);
end;

// Takes Values over and puts them in place of the list Name (keeping its spelling when it exists);
// no values forgets it.
procedure TEuoLists.Store(const Name : String; Values : TEuoListValues);
var
  Old : TEuoListValues;
begin
  if Values.Count=0 then
  begin
    Values.Free;
    Forget(Name);
    Exit;
  end;
  Old:=Lookup(Name);
  if Old=nil then
  begin
    Values.Name:=Name;
    FNames.AddObject(UpperCase(Name),Values);
  end
  else begin
    Old.Assign(Values);
    Values.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLists.Count(const Name : String) : Integer;
var
  L : TEuoListValues;
begin
  L:=Lookup(Name);
  if L=nil then Result:=0 else Result:=L.Count;
end;

function TEuoLists.Get(const Name : String; Index : Integer; out Value : String) : Boolean;
var
  L : TEuoListValues;
begin
  Value:='';
  L:=Lookup(Name);
  Result:=(L<>nil) and (Index>=1) and (Index<=L.Count);
  if Result then Value:=L[Index-1];
end;

function TEuoLists.Add(const Name, Value : String) : Integer;
var
  L : TEuoListValues;
begin
  L:=Make(Name);
  L.Add(Value);
  Result:=L.Count;
end;

function TEuoLists.Insert(const Name : String; Index : Integer; const Value : String) : Boolean;
begin
  Result:=(Index>=1) and (Index<=Count(Name)+1);
  if Result then Make(Name).Insert(Index-1,Value);
end;

function TEuoLists.SetValue(const Name : String; Index : Integer; const Value : String) : Boolean;
var
  L : TEuoListValues;
begin
  L:=Lookup(Name);
  Result:=(L<>nil) and (Index>=1) and (Index<=L.Count);
  if Result then L[Index-1]:=Value;
end;

function TEuoLists.Delete(const Name : String; Index : Integer) : Boolean;
var
  L : TEuoListValues;
begin
  L:=Lookup(Name);
  Result:=(L<>nil) and (Index>=1) and (Index<=L.Count);
  if not Result then Exit;
  L.Delete(Index-1);
  if L.Count=0 then Forget(Name);
end;

function TEuoLists.IndexOf(const Name, Value : String; From : Integer) : Integer;
var
  L : TEuoListValues;
  U : String;
  i : Integer;
begin
  Result:=0;
  L:=Lookup(Name);
  if (L=nil) or (From<1) then Exit;
  U:=UpperCase(Value);
  for i:=From-1 to L.Count-1 do
    if UpperCase(L[i])=U then Exit(i+1);
end;

function TEuoLists.FindText(const Name, Text : String; From : Integer) : Integer;
var
  L : TEuoListValues;
  U : String;
  i : Integer;
begin
  Result:=0;
  L:=Lookup(Name);
  if (L=nil) or (From<1) then Exit;
  U:=UpperCase(Text);
  for i:=From-1 to L.Count-1 do
    if Pos(U,UpperCase(L[i]))>0 then Exit(i+1);
end;

procedure TEuoLists.Forget(const Name : String);
var
  i : Integer;
begin
  if not FNames.Find(UpperCase(Name),i) then Exit;
  FNames.Objects[i].Free;
  FNames.Delete(i);
end;

function TEuoLists.Clone(const Name, Source : String) : Integer;
var
  R : TEuoListValues;
  S : TEuoListValues;
begin
  R:=TEuoListValues.Create;
  S:=Lookup(Source);
  if S<>nil then R.Assign(S);
  Result:=R.Count;
  Store(Name,R);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLists.Sort(const Name : String; Mode : TEuoListSort; Down : Boolean) : Integer;
var
  L      : TEuoListValues;
  N, i   : Integer;
  Nums   : array of Int64;
  Texts  : array of String;
  Idx    : array of Integer;
  Tmp    : array of Integer;
  ByNum  : Boolean;
  Ok     : Boolean;
  Orig   : TStringList;

  // <0 when value A sorts before value B
  function Cmp(A, B : Integer) : Integer;
  begin
    if ByNum then
    begin
      if Nums[A]<Nums[B] then Result:=-1
      else if Nums[A]>Nums[B] then Result:=1
      else Result:=0;
    end
    else Result:=CompareStr(Texts[A],Texts[B]);
    if Down then Result:=-Result;
  end;

  // stable merge sort of Idx[Lo..Hi]
  procedure MergeSort(Lo, Hi : Integer);
  var
    Mid, a, b, k : Integer;
  begin
    if Lo>=Hi then Exit;
    Mid:=(Lo+Hi) div 2;
    MergeSort(Lo,Mid);
    MergeSort(Mid+1,Hi);
    a:=Lo;
    b:=Mid+1;
    k:=Lo;
    while (a<=Mid) and (b<=Hi) do
    begin
      if Cmp(Idx[b],Idx[a])<0 then
      begin
        Tmp[k]:=Idx[b];
        Inc(b);
      end
      else begin
        Tmp[k]:=Idx[a];
        Inc(a);
      end;
      Inc(k);
    end;
    while a<=Mid do begin Tmp[k]:=Idx[a]; Inc(a); Inc(k); end;
    while b<=Hi do begin Tmp[k]:=Idx[b]; Inc(b); Inc(k); end;
    for k:=Lo to Hi do Idx[k]:=Tmp[k];
  end;

begin
  Result:=0;
  L:=Lookup(Name);
  if L=nil then Exit;
  N:=L.Count;
  SetLength(Nums,N);
  SetLength(Texts,N);
  SetLength(Idx,N);
  SetLength(Tmp,N);
  ByNum:=Mode=lsNumber;
  if Mode=lsAuto then ByNum:=True;
  for i:=0 to N-1 do
  begin
    Idx[i]:=i;
    Nums[i]:=SToI64Def(L[i],0,Ok);
    if not Ok and (Mode=lsAuto) then ByNum:=False;
    Texts[i]:=UpperCase(L[i]);
  end;
  MergeSort(0,N-1);

  Orig:=TStringList.Create;
  try
    Orig.Assign(L);
    for i:=0 to N-1 do L[i]:=Orig[Idx[i]];
  finally
    Orig.Free;
  end;
  Result:=N;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLists.Split(const Name, Text, Sep : String) : Integer;
var
  R            : TEuoListValues;
  TextU, SepU  : String;
  From, At     : Integer;
begin
  Result:=-1;
  if Sep='' then Exit;
  R:=TEuoListValues.Create;
  if Text<>'' then
  begin
    TextU:=UpperCase(Text);
    SepU:=UpperCase(Sep);
    From:=1;
    repeat
      At:=PosEx(SepU,TextU,From);
      if At<1 then
      begin
        R.Add(Copy(Text,From,MaxInt));
        Break;
      end;
      R.Add(Copy(Text,From,At-From));
      From:=At+Length(SepU);
    until False;
  end;
  Result:=R.Count;
  Store(Name,R);
end;

function TEuoLists.Join(const Name, Sep : String) : String;
var
  L : TEuoListValues;
  i : Integer;
begin
  Result:='';
  L:=Lookup(Name);
  if L=nil then Exit;
  for i:=0 to L.Count-1 do
  begin
    if i>0 then Result:=Result+Sep;
    Result:=Result+L[i];
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoLists.Merge(const Name : String; Sources : TStrings; KeepDuplicates : Boolean) : Integer;
var
  R    : TEuoListValues;
  Seen : TStringList;
  L    : TEuoListValues;
  s, i : Integer;
begin
  R:=TEuoListValues.Create;
  Seen:=NewValueSet;
  try
    for s:=0 to Sources.Count-1 do
    begin
      L:=Lookup(Sources[s]);
      if L=nil then Continue;
      for i:=0 to L.Count-1 do
      begin
        if not KeepDuplicates then
        begin
          if InSet(Seen,L[i]) then Continue;
          Seen.Add(UpperCase(L[i]));
        end;
        R.Add(L[i]);
      end;
    end;
  finally
    Seen.Free;
  end;
  Result:=R.Count;
  Store(Name,R);
end;

function TEuoLists.Intersect(const Name : String; Sources : TStrings) : Integer;
var
  R     : TEuoListValues;
  Seen  : TStringList;
  Sets  : array of TStringList;
  First : TEuoListValues;
  L     : TEuoListValues;
  s, i  : Integer;
  InAll : Boolean;
begin
  R:=TEuoListValues.Create;
  Seen:=NewValueSet;
  SetLength(Sets,Sources.Count);
  try
    for s:=1 to Sources.Count-1 do
    begin
      Sets[s]:=NewValueSet;
      L:=Lookup(Sources[s]);
      if L<>nil then
        for i:=0 to L.Count-1 do Sets[s].Add(UpperCase(L[i]));
    end;
    if Sources.Count>0 then First:=Lookup(Sources[0]) else First:=nil;
    if First<>nil then
      for i:=0 to First.Count-1 do
      begin
        if InSet(Seen,First[i]) then Continue;
        InAll:=True;
        for s:=1 to Sources.Count-1 do
          if not InSet(Sets[s],First[i]) then
          begin
            InAll:=False;
            Break;
          end;
        if not InAll then Continue;
        Seen.Add(UpperCase(First[i]));
        R.Add(First[i]);
      end;
  finally
    for s:=1 to High(Sets) do Sets[s].Free;
    Seen.Free;
  end;
  Result:=R.Count;
  Store(Name,R);
end;

function TEuoLists.Subtract(const Name, Source, Other : String) : Integer;
var
  R    : TEuoListValues;
  Seen : TStringList;
  Drop : TStringList;
  L    : TEuoListValues;
  i    : Integer;
begin
  R:=TEuoListValues.Create;
  Seen:=NewValueSet;
  Drop:=NewValueSet;
  try
    L:=Lookup(Other);
    if L<>nil then
      for i:=0 to L.Count-1 do Drop.Add(UpperCase(L[i]));
    L:=Lookup(Source);
    if L<>nil then
      for i:=0 to L.Count-1 do
      begin
        if InSet(Drop,L[i]) or InSet(Seen,L[i]) then Continue;
        Seen.Add(UpperCase(L[i]));
        R.Add(L[i]);
      end;
  finally
    Drop.Free;
    Seen.Free;
  end;
  Result:=R.Count;
  Store(Name,R);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLists.SetValues(const Name : String; Values : TStrings);
var
  R : TEuoListValues;
begin
  R:=TEuoListValues.Create;
  R.Assign(Values);
  Store(Name,R);
end;

procedure TEuoLists.Clear;
var
  i : Integer;
begin
  for i:=0 to FNames.Count-1 do
    FNames.Objects[i].Free;
  FNames.Clear;
end;

// The lists' names as first spelled, A-Z ignoring case.
procedure TEuoLists.Names(List : TStrings);
var
  i : Integer;
begin
  for i:=0 to FNames.Count-1 do
    List.Add(TEuoListValues(FNames.Objects[i]).Name);
end;

procedure TEuoLists.Values(const Name : String; List : TStrings);
var
  L : TEuoListValues;
begin
  L:=Lookup(Name);
  if L<>nil then List.AddStrings(L);
end;

function TEuoLists.ListCount : Integer;
begin
  Result:=FNames.Count;
end;

end.
