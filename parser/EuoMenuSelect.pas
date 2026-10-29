unit EuoMenuSelect;

{
  Port addition (not in either original): which MENU logic a script runs under, EasyUO 1.5's or
  EasyUO 1.6's. See docs/menu-1.6-analysis.md, sections 6.2 and 6.3, for the rules and the
  evidence behind them.

  The choice is made once, from the script's text, before the run starts:
  1. "menu reforge mode 1.5" or "menu reforge mode 1.6" in the main script decides.
  2. Otherwise a line "menu <sub>" with one of the nine sub-commands only 1.6 has selects 1.6.
     Only the main script is read, unless it contains "menu reforge includecall #true"; then the
     files it CALLs by a literal name are read too, and the files they call, each once.
  3. Otherwise 1.5.

  Lines are split exactly as TEuoInterpreter.Parameterize splits them: on spaces and tabs, and a
  word that starts with ';' ends the line. Nothing here touches a variable or runs anything, so
  a value or a CALL name that only a variable can supply is not seen; that is by design.
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils;

type
  TMenuLogic = (mlMenu15, mlMenu16);

  // The file a CALL line would load, or '' when there is none (supplied by the interpreter,
  // which knows how CALL resolves a name).
  TMenuCallResolver = function(const Name : String) : String of object;

  TMenuSettings = record
    ModeSet     : Boolean;     // a "menu reforge mode" line with a valid value was found
    Mode        : TMenuLogic;
    IncludeCall : Boolean;     // "menu reforge includecall" with a true value; default False
  end;

const
  MenuLogicName : array[TMenuLogic] of String = ('1.5', '1.6');
  // A runaway include chain stops here; real scripts call a handful of files.
  MaxCallFiles = 256;

procedure SplitScriptLine(const Line : String; Words : TStrings);
function  IsMenu16Only(const SubU : String) : Boolean;
procedure ReadMenuSettings(Lines : TStrings; out Settings : TMenuSettings);
function  UsesMenu16(Lines : TStrings) : Boolean;
function  ChooseMenuLogic(Main : TStrings; Resolve : TMenuCallResolver; out Forced : Boolean) : TMenuLogic;

implementation

const
  Menu16Only : array[0..8] of String =
    ('FORM', 'PANEL', 'RADIO', 'GETPROP', 'SETPROP', 'GETDEF', 'SETDEF', 'PUSHDEF', 'POPDEF');

////////////////////////////////////////////////////////////////////////////////
// TEuoInterpreter.Parameterize's rules, kept identical so the scan sees the same words
// the interpreter will run.
procedure SplitScriptLine(const Line : String; Words : TStrings);
var
  Str  : String;
  sBuf : String;
  Cnt1 : Integer;
begin
  Str:=Trim(Line)+' ';

  for Cnt1:=1 to Length(Str) do
    if Str[Cnt1]=#9 then Str[Cnt1]:=#32;

  Words.Clear;
  repeat
    Cnt1:=Pos(#32,Str);
    if Cnt1<1 then Break;
    sBuf:=Copy(Str,1,Cnt1-1);
    Delete(Str,1,Cnt1);
    if sBuf='' then Continue;
    if sBuf[1]=';' then Break;
    Words.Add(sBuf);
  until False;
end;

////////////////////////////////////////////////////////////////////////////////
function IsMenu16Only(const SubU : String) : Boolean;
var
  Cnt : Integer;
begin
  Result:=True;
  for Cnt:=Low(Menu16Only) to High(Menu16Only) do
    if SubU=Menu16Only[Cnt] then Exit;
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
// For each setting the first line with a valid value wins. A value written as a variable
// cannot be read before the run and counts as invalid.
procedure ReadMenuSettings(Lines : TStrings; out Settings : TMenuSettings);
var
  Words   : TStringList;
  Cnt     : Integer;
  Key     : String;
  Value   : String;
  CallSet : Boolean;
begin
  Settings.ModeSet:=False;
  Settings.Mode:=mlMenu15;
  Settings.IncludeCall:=False;
  CallSet:=False;

  Words:=TStringList.Create;
  try
    for Cnt:=0 to Lines.Count-1 do
    begin
      SplitScriptLine(Lines[Cnt],Words);
      if Words.Count<4 then Continue;
      if UpperCase(Words[0])<>'MENU' then Continue;
      if UpperCase(Words[1])<>'REFORGE' then Continue;
      Key:=UpperCase(Words[2]);
      Value:=UpperCase(Words[3]);

      if (Key='MODE') and not Settings.ModeSet then
      begin
        if Value='1.5' then
        begin
          Settings.ModeSet:=True;
          Settings.Mode:=mlMenu15;
        end
        else if Value='1.6' then
        begin
          Settings.ModeSet:=True;
          Settings.Mode:=mlMenu16;
        end;
      end

      else if (Key='INCLUDECALL') and not CallSet then
      begin
        if (Value='#TRUE') or (Value='TRUE') or (Value='1') or (Value='-1') then
        begin
          CallSet:=True;
          Settings.IncludeCall:=True;
        end
        else if (Value='#FALSE') or (Value='FALSE') or (Value='0') then
          CallSet:=True;
      end;
    end;
  finally
    Words.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function UsesMenu16(Lines : TStrings) : Boolean;
var
  Words : TStringList;
  Cnt   : Integer;
begin
  Result:=False;
  Words:=TStringList.Create;
  try
    for Cnt:=0 to Lines.Count-1 do
    begin
      SplitScriptLine(Lines[Cnt],Words);
      if Words.Count<2 then Continue;
      if UpperCase(Words[0])<>'MENU' then Continue;
      if IsMenu16Only(UpperCase(Words[1])) then Exit(True);
    end;
  finally
    Words.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// The file names CALL lines give literally. A name taken from a variable, or glued
// together with the ',' or '.' operators, is only known at runtime and is skipped.
procedure AddCallNames(Lines : TStrings; Names : TStrings);
var
  Words : TStringList;
  Cnt   : Integer;
begin
  Words:=TStringList.Create;
  try
    for Cnt:=0 to Lines.Count-1 do
    begin
      SplitScriptLine(Lines[Cnt],Words);
      if Words.Count<2 then Continue;
      if UpperCase(Words[0])<>'CALL' then Continue;
      if Words[1][1] in ['%','!','#','*'] then Continue;
      if (Words.Count>2) and ((Words[2]=',') or (Words[2]='.')) then Continue;
      Names.Add(Words[1]);
    end;
  finally
    Words.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Files reached by CALL, breadth first, each read once (a call cycle cannot loop).
function CalledFilesUseMenu16(Main : TStrings; Resolve : TMenuCallResolver) : Boolean;
var
  Pending : TStringList;   // names still to resolve
  Seen    : TStringList;   // resolved paths already read
  Lines   : TStringList;
  Path    : String;
begin
  Result:=False;
  Pending:=TStringList.Create;
  Seen:=TStringList.Create;
  Lines:=TStringList.Create;
  try
    AddCallNames(Main,Pending);
    while (Pending.Count>0) and (Seen.Count<MaxCallFiles) do
    begin
      Path:=Resolve(Pending[0]);
      Pending.Delete(0);
      if Path='' then Continue;
      if Seen.IndexOf(UpperCase(Path))>=0 then Continue;
      Seen.Add(UpperCase(Path));

      try
        Lines.LoadFromFile(Path);
      except
        Continue;   // unreadable now; CALL itself will deal with it at runtime
      end;
      if UsesMenu16(Lines) then Exit(True);
      AddCallNames(Lines,Pending);
    end;
  finally
    Lines.Free;
    Seen.Free;
    Pending.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function ChooseMenuLogic(Main : TStrings; Resolve : TMenuCallResolver; out Forced : Boolean) : TMenuLogic;
var
  Settings : TMenuSettings;
begin
  ReadMenuSettings(Main,Settings);
  Forced:=Settings.ModeSet;
  if Forced then Exit(Settings.Mode);

  Result:=mlMenu16;
  if UsesMenu16(Main) then Exit;
  if Settings.IncludeCall and Assigned(Resolve) then
    if CalledFilesUseMenu16(Main,Resolve) then Exit;
  Result:=mlMenu15;
end;

end.
