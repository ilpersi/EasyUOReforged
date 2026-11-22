unit EuoSearchPath;

{
  Port addition: where CALL looks for a script file and SQL OPEN for a database file. The original
  CALL looked for a relative name in #CurPath only (TEuoInterpreter.ResolveCallFile, from the
  original's CallProc); Reforged searches more folders after it, in this order:

    1. an absolute name (a drive, "X:\...", or a backslash, "\..." and "\\server\...") as written,
       and no folder is searched;
    2. #CurPath, as the original did;
    3. the editor's Search Folders list (Tools > Search Folders, in the registry), which EUOCli reads too;
    4. the folders of the EUOPATH environment variable;
    5. EUOCli only: its --euopath folders, then those of the MCP call's "euopath".

  In each place the name as written, then with each extension of the caller's list -- CALL: .txt,
  then .euo (CallExts, the original's); SQL OPEN: .db, then .sqlite (SqlExts) -- before the next
  place. So #CurPath is searched in full first, exactly as before, and a script that works today
  loads the same file whatever folders are added. Nothing found: '' (CALL does nothing, as always;
  SQL OPEN makes a new database where it always did).

  A folder list is written as PATH is: folders separated by ';'. Spaces around an entry are dropped,
  quotes are removed (a ';' inside quotes is part of the folder), empty entries are skipped and '/'
  is read as '\'. A relative folder starts from #CurPath, as a relative name does (EUOCli makes its
  own folders absolute from the current folder before they get here). A folder that does not exist
  finds nothing; one already searched, #CurPath included, is not searched again.

  The interpreter never reads the registry: a host reads the saved list (ReadSavedSearchPath) and
  hands it over (TEuoInterpreter.SearchPath), so the test suite does not depend on the machine's
  settings. EUOPATH is read at each lookup, in every host.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

const
  EuoPathEnvVar      = 'EUOPATH';
  // The original EasyUO's \Software\EasyUO is left alone, as for the Watches (euwatch.pas).
  SearchPathRegKey   = '\Software\EasyUO Reforged';
  SearchPathRegValue = 'SearchPath';
  // The extensions tried after the name as written, in order.
  CallExts : array[0..1] of String = ('.txt', '.euo');     // CALL: the original's
  SqlExts  : array[0..1] of String = ('.db', '.sqlite');   // SQL OPEN

// Text's folders, in order (see the header); relative ones are left relative.
procedure SplitSearchPath(const Text : String; List : TStrings);
// List's folders as one ';' list, without empty entries; a folder with a ';' is quoted.
function  JoinSearchPath(List : TStrings) : String;
// The original CALL's test for an absolute name: a drive ("X:\") or a leading backslash.
function  IsAbsoluteName(const Name : String) : Boolean;
// EUOPATH's value, '' when it is not set.
function  EnvEuoPath : String;
// The folders searched after #CurPath, in order: ListPath's, EUOPATH's, LastPath's.
procedure SearchFolders(const ListPath, LastPath : String; List : TStrings);
// The file a name stands for (see the header), or ''. CurPath is #CurPath, ending with '\';
// Exts are the extensions tried after the name as written (CallExts, SqlExts).
function  ResolveSearchName(const Name, CurPath : String; Folders : TStrings;
            const Exts : array of String) : String;
// The folder list the editor saved ('' when none), and saving it ('' removes it; False when the
// registry cannot be written).
function  ReadSavedSearchPath : String;
function  WriteSavedSearchPath(const Value : String) : Boolean;

implementation

uses
  Windows, Registry;

////////////////////////////////////////////////////////////////////////////////
procedure SplitSearchPath(const Text : String; List : TStrings);
var
  i       : Integer;
  Cur     : String;
  InQuote : Boolean;

  procedure Flush;
  var
    S : String;
  begin
    S:=Trim(StringReplace(Cur,'/','\',[rfReplaceAll]));
    if S<>'' then List.Add(S);
    Cur:='';
  end;

begin
  Cur:='';
  InQuote:=False;
  for i:=1 to Length(Text) do
    if Text[i]='"' then InQuote:=not InQuote
    else if (Text[i]=';') and not InQuote then Flush
    else Cur:=Cur+Text[i];
  Flush;
end;

////////////////////////////////////////////////////////////////////////////////
function JoinSearchPath(List : TStrings) : String;
var
  i : Integer;
  S : String;
begin
  Result:='';
  for i:=0 to List.Count-1 do
  begin
    S:=Trim(List[i]);
    if S='' then Continue;
    if Pos(';',S)>0 then S:='"'+S+'"';
    if Result<>'' then Result:=Result+';';
    Result:=Result+S;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function IsAbsoluteName(const Name : String) : Boolean;
begin
  Result:=(Copy(Name,2,2)=':\')or(Copy(Name,1,1)='\');
end;

////////////////////////////////////////////////////////////////////////////////
// Read through the wide API: a folder name may have letters outside the ANSI code page.
function EnvEuoPath : String;
var
  Name : UnicodeString;
  Buf  : UnicodeString;
  N    : DWORD;
begin
  Result:='';
  Name:=EuoPathEnvVar;
  N:=GetEnvironmentVariableW(PWideChar(Name),nil,0);
  if N=0 then Exit;
  SetLength(Buf,N);
  N:=GetEnvironmentVariableW(PWideChar(Name),PWideChar(Buf),N);
  SetLength(Buf,N);
  Result:=UTF8Encode(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
procedure SearchFolders(const ListPath, LastPath : String; List : TStrings);
begin
  SplitSearchPath(ListPath,List);
  SplitSearchPath(EnvEuoPath,List);
  SplitSearchPath(LastPath,List);
end;

////////////////////////////////////////////////////////////////////////////////
// Base, then Base with each of Exts, the first that exists; '' when none.
function FirstOf(const Base : String; const Exts : array of String) : String;
var
  i : Integer;
begin
  Result:=Base;
  if FileExists(Result) then Exit;
  for i:=Low(Exts) to High(Exts) do
  begin
    Result:=Base+Exts[i];
    if FileExists(Result) then Exit;
  end;
  Result:='';
end;

////////////////////////////////////////////////////////////////////////////////
function ResolveSearchName(const Name, CurPath : String; Folders : TStrings;
  const Exts : array of String) : String;
var
  Seen   : TStringList;
  i      : Integer;
  Folder : String;
  Key    : String;
begin
  // 1 and 2: the original CALL's lookup, character for character (with CallExts).
  if IsAbsoluteName(Name) then
  begin
    Result:=FirstOf(Name,Exts);
    Exit;
  end;
  Result:=FirstOf(CurPath+Name,Exts);
  if (Result<>'') or (Name='') or (Folders=nil) then Exit;

  // 3 to 5: the folders, each searched in full before the next.
  Seen:=TStringList.Create;
  try
    Seen.CaseSensitive:=False;
    if CurPath<>'' then Seen.Add(IncludeTrailingPathDelimiter(ExpandFileName(CurPath)));
    for i:=0 to Folders.Count-1 do
    begin
      Folder:=Trim(Folders[i]);
      if Folder='' then Continue;
      if not IsAbsoluteName(Folder) then Folder:=CurPath+Folder;
      Folder:=IncludeTrailingPathDelimiter(Folder);
      Key:=IncludeTrailingPathDelimiter(ExpandFileName(Folder));
      if Seen.IndexOf(Key)>=0 then Continue;
      Seen.Add(Key);
      Result:=FirstOf(Folder+Name,Exts);
      if Result<>'' then Exit;
    end;
  finally
    Seen.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function ReadSavedSearchPath : String;
var
  R : TRegistry;
begin
  Result:='';
  R:=TRegistry.Create;
  try
    try
      if R.OpenKeyReadOnly(SearchPathRegKey) then
        if R.GetDataType(SearchPathRegValue) in [rdString,rdExpandString] then
          Result:=R.ReadString(SearchPathRegValue);
    except
      Result:='';
    end;
  finally
    R.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function WriteSavedSearchPath(const Value : String) : Boolean;
var
  R : TRegistry;
begin
  Result:=False;
  R:=TRegistry.Create;
  try
    try
      if Value='' then
      begin
        if R.OpenKey(SearchPathRegKey,False) then
          if R.ValueExists(SearchPathRegValue) then R.DeleteValue(SearchPathRegValue);
        Result:=True;
      end
      else if R.OpenKey(SearchPathRegKey,True) then
      begin
        R.WriteString(SearchPathRegValue,Value);
        Result:=True;
      end;
    except
      Result:=False;
    end;
  finally
    R.Free;
  end;
end;

end.
