unit EuoOutline;

{
  The index behind the editor's outline panel (easyuo\euoutline.pas): where a script's subs,
  labels and MENU windows are. Added during the Lazarus/FPC migration (not present in the
  original Delphi 7 app). A pure, string-in/records-out unit like EuoBlocks.pas and
  EuoJumpTarget.pas, so it is unit-testable and sits at parser's lowest layer. The interpreter
  is NOT touched; every rule below is read off it through those two units:
  - A sub is a line whose command (EuoLineCmd, the interpreter's GetCmd) is SUB; its name is
    the second word, as GoSubProc reads it (EuoFindSub).
  - A label is a line whose command ends with ':', the test GoToProc makes (EuoFindLabel), so
    "foo:;x" and "foo: ; comment" are labels too. A bare ':' is not.
  - A MENU window is "menu window title ..." (the main window, both MENU logics) or
    "menu form NAME ..." (another window, 1.6).
  - Where a sub ends comes from EuoBlockStep, the rules of code folding: its own-level RETURN,
    the closing brace of a braced sub, the line before the next SUB, or the end of the file.
    Labels and MENU windows inside that range belong to the sub; the others are top level.
  - A sub is Unused when no GOSUB names it with a name written in the script (the rule
    EuoJumpTarget.EuoStaticJumpName shares with Ctrl+click: a variable, a name glued with '.'
    or ',' or a line continued by '+' lines is only known at run time), or when a later sub has
    the same name, as GOSUB runs the last one. It is a hint: a sub reached through
    "gosub %next" or from another file through CALL is Unused here.
  Names are compared ignoring case, as the interpreter does. A '+' continuation line is part
  of the line before it and adds nothing.

  EuoOutlineItemAt is the entry the editor's caret is in (the outline follows it), and
  EuoOutlineRows the entries shown for a filter, in script or A-Z order. The filter's own
  matching (a regular expression) stays in the GUI layer.
}

{$mode delphi}{$H+}

interface

uses
  Classes;

type
  TEuoOutlineKind = (eokSub, eokLabel, eokMenu);

  TEuoOutlineItem = record
    Kind     : TEuoOutlineKind;
    Name     : String;   // the sub's or label's name, the window's title or form name, as written
    Text     : String;   // what the outline shows: 'sub Name', 'Name:', 'menu Title', 'menu form Name'
    Line     : Integer;  // 0-based
    LastLine : Integer;  // 0-based, the last line the entry covers
    Parent   : Integer;  // index of the sub it is in, -1 at top level
    Unused   : Boolean;  // subs only, see the header comment
  end;
  TEuoOutline = array of TEuoOutlineItem;

  TEuoOutlineRow = record
    Item  : Integer;     // index into the outline
    Depth : Integer;     // 0 top level, 1 inside a sub
  end;
  TEuoOutlineRows = array of TEuoOutlineRow;

// The outline of a script, its entries in line order (a sub before what it holds).
procedure EuoBuildOutline(Lines : TStrings; out Items : TEuoOutline);

// The innermost entry whose range holds Line (0-based), or -1. A sub covers its whole range;
// a label or MENU window from its line to the line before the next entry beside it, or to the
// end of its sub (of the script at top level).
function EuoOutlineItemAt(const Items : TEuoOutline; Line : Integer) : Integer;

// The entries to show, in order, each after its sub. Match (one per entry, or empty for all)
// says which entries the filter keeps; a sub stays when one of its entries does. Sorted orders
// the entries beside each other by name, ignoring case, keeping the script order for equal names.
function EuoOutlineRows(const Items : TEuoOutline; const Match : array of Boolean;
  Sorted : Boolean) : TEuoOutlineRows;

implementation

uses
  SysUtils, EuoBlocks, EuoScriptWords, EuoMenuSelect, EuoJumpTarget;

////////////////////////////////////////////////////////////////////////////////
// The index of the innermost open sub, or -1.
function OpenSub(const Item : array of Integer) : Integer;
var
  Cnt : Integer;
begin
  Result:=-1;
  for Cnt:=High(Item) downto 0 do
    if Item[Cnt]>=0 then
  begin
    Result:=Item[Cnt];
    Exit;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure EuoBuildOutline(Lines : TStrings; out Items : TEuoOutline);
var
  Stack   : array of TEuoBlockKind;
  OpenItm : array of Integer;  // per open block, the sub it is (ebkSub), else -1
  Pending : TEuoBodyPending;
  Step    : TEuoLineStep;
  Words   : TStringList;
  Used    : TStringList;
  i, j, N : Integer;
  Cmd     : String;
  sName   : String;
  sBuf    : String;

  function Add(Kind : TEuoOutlineKind; const AName, AText : String; ALine : Integer) : Integer;
  begin
    Result:=Length(Items);
    SetLength(Items,Result+1);
    Items[Result].Kind:=Kind;
    Items[Result].Name:=AName;
    Items[Result].Text:=AText;
    Items[Result].Line:=ALine;
    Items[Result].LastLine:=ALine;
    Items[Result].Parent:=-1;
    Items[Result].Unused:=False;
  end;

  // Not Items[Add(...)].Parent: Add can move the array before the index is used.
  procedure SetParent(Idx : Integer);
  begin
    Items[Idx].Parent:=OpenSub(OpenItm);
  end;

begin
  Items:=nil;
  Stack:=nil;
  OpenItm:=nil;
  Pending:=ebpNone;
  Words:=TStringList.Create;
  Used:=TStringList.Create;
  try
    Used.Sorted:=True;
    Used.Duplicates:=dupIgnore;
    Used.CaseSensitive:=False;

    for i:=0 to Lines.Count-1 do
    begin
      Step:=EuoBlockStep(Lines[i],Pending,Stack);
      if Step.IsContinuation then Continue;

      // blocks this line closes: a sub among them ends here, or on the line before
      // when the line is the next SUB
      for j:=1 to Step.Closes do
        if Length(Stack)>0 then
        begin
          N:=OpenItm[High(OpenItm)];
          if N>=0 then
            if Step.Cmd='SUB' then Items[N].LastLine:=i-1
            else Items[N].LastLine:=i;
          SetLength(Stack,Length(Stack)-1);
          SetLength(OpenItm,Length(OpenItm)-1);
        end;

      N:=-1;
      Cmd:=Step.Cmd;
      if Cmd='SUB' then
      begin
        SplitScriptLine(Lines[i],Words);
        sName:='';
        if Words.Count>1 then sName:=Words[1];
        N:=Add(eokSub,sName,Trim('sub '+sName),i);
      end
      else if (Length(Cmd)>1) and (Cmd[Length(Cmd)]=':') then
      begin
        sName:=Copy(Trim(Lines[i]),1,Length(Cmd)-1);
        SetParent(Add(eokLabel,sName,sName+':',i));
      end
      else if Cmd='MENU' then
      begin
        SplitScriptLine(Lines[i],Words);
        if Words.Count>=3 then
        begin
          sBuf:=UpperCase(Words[1]);
          if (sBuf='WINDOW') and (UpperCase(Words[2])='TITLE') then
          begin
            sName:='';
            for j:=3 to Words.Count-1 do
              if sName='' then sName:=Words[j]
              else sName:=sName+' '+Words[j];
            if sName='' then
              SetParent(Add(eokMenu,'','menu window',i))
            else
              SetParent(Add(eokMenu,sName,'menu '+sName,i));
          end
          else if sBuf='FORM' then
            SetParent(Add(eokMenu,Words[2],'menu form '+Words[2],i));
        end;
      end
      else if Cmd='GOSUB' then
        if EuoStaticJumpName(Lines,i,sBuf,sName) then
          if sBuf='GOSUB' then Used.Add(sName);

      if Step.Opens<>ebkNone then
      begin
        SetLength(Stack,Length(Stack)+1);
        Stack[High(Stack)]:=Step.Opens;
        SetLength(OpenItm,Length(OpenItm)+1);
        if Step.Opens=ebkSub then OpenItm[High(OpenItm)]:=N
        else OpenItm[High(OpenItm)]:=-1;
      end;
      Pending:=Step.Pending;
    end;

    // subs still open run to the end of the script
    for j:=0 to High(OpenItm) do
      if OpenItm[j]>=0 then Items[OpenItm[j]].LastLine:=Lines.Count-1;

    // a label or MENU window covers its line up to the next entry beside it
    for i:=0 to High(Items) do
    begin
      if Items[i].Kind=eokSub then Continue;
      if Items[i].Parent>=0 then Items[i].LastLine:=Items[Items[i].Parent].LastLine
      else Items[i].LastLine:=Lines.Count-1;
      for j:=i+1 to High(Items) do
        if (Items[j].Parent=Items[i].Parent) or (Items[j].Kind=eokSub) then
        begin
          if Items[j].Line-1<Items[i].LastLine then Items[i].LastLine:=Items[j].Line-1;
          Break;
        end;
    end;

    // subs no GOSUB reaches
    for i:=0 to High(Items) do
    begin
      if Items[i].Kind<>eokSub then Continue;
      Items[i].Unused:=(Items[i].Name='') or (Used.IndexOf(Items[i].Name)<0);
      if not Items[i].Unused then
        for j:=i+1 to High(Items) do
          if (Items[j].Kind=eokSub) and (CompareText(Items[j].Name,Items[i].Name)=0) then
          begin
            Items[i].Unused:=True;
            Break;
          end;
    end;
  finally
    Used.Free;
    Words.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Every entry's range lies inside its sub's, and the ranges beside each other do not
// overlap, so the last entry in line order that holds Line is the innermost.
function EuoOutlineItemAt(const Items : TEuoOutline; Line : Integer) : Integer;
var
  Cnt : Integer;
begin
  Result:=-1;
  for Cnt:=0 to High(Items) do
    if (Items[Cnt].Line<=Line) and (Line<=Items[Cnt].LastLine) then
      Result:=Cnt;
end;

////////////////////////////////////////////////////////////////////////////////
function EuoOutlineRows(const Items : TEuoOutline; const Match : array of Boolean;
  Sorted : Boolean) : TEuoOutlineRows;
var
  Shown : array of Boolean;
  Top   : array of Integer;
  Kids  : array of Integer;
  i, j  : Integer;

  // insertion sort: stable, and the lists are short
  procedure SortList(var L : array of Integer);
  var
    a, b, v : Integer;
  begin
    for a:=1 to High(L) do
    begin
      v:=L[a];
      b:=a-1;
      while (b>=0) and (CompareText(Items[L[b]].Name,Items[v].Name)>0) do
      begin
        L[b+1]:=L[b];
        Dec(b);
      end;
      L[b+1]:=v;
    end;
  end;

  procedure AddRow(Item, Depth : Integer);
  var
    N : Integer;
  begin
    N:=Length(Result);
    SetLength(Result,N+1);
    Result[N].Item:=Item;
    Result[N].Depth:=Depth;
  end;

begin
  Result:=nil;
  SetLength(Shown,Length(Items));
  for i:=0 to High(Items) do
    Shown[i]:=(Length(Match)=0) or ((i<=High(Match)) and Match[i]);
  for i:=0 to High(Items) do
    if Shown[i] and (Items[i].Parent>=0) then Shown[Items[i].Parent]:=True;

  Top:=nil;
  for i:=0 to High(Items) do
    if Shown[i] and (Items[i].Parent<0) then
    begin
      SetLength(Top,Length(Top)+1);
      Top[High(Top)]:=i;
    end;
  if Sorted then SortList(Top);

  for i:=0 to High(Top) do
  begin
    AddRow(Top[i],0);
    if Items[Top[i]].Kind<>eokSub then Continue;
    Kids:=nil;
    for j:=Top[i]+1 to High(Items) do
      if (Items[j].Parent=Top[i]) and Shown[j] then
      begin
        SetLength(Kids,Length(Kids)+1);
        Kids[High(Kids)]:=j;
      end;
    if Sorted then SortList(Kids);
    for j:=0 to High(Kids) do
      AddRow(Kids[j],1);
  end;
end;

end.
