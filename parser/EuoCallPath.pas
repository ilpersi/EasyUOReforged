unit EuoCallPath;

{
  Port addition: where CALL looks for a file. The original looked for a relative name in #CurPath
  only (TEuoInterpreter.ResolveCallFile, from the original's CallProc); Reforged searches more
  folders after it, in this order:

    1. an absolute name (a drive, "X:\...", or a backslash, "\..." and "\\server\...") as written,
       and no folder is searched;
    2. #CurPath, as the original did;
    3. the folder list the editor keeps (Tools > CALL Folders, in the registry), which EUOCli reads too;
    4. the folders of the EUOCALLPATH environment variable;
    5. EUOCli only: its --callpath folders, then those of the MCP call's "callpath".

  In each place the name as written, then with .txt, then with .euo, before the next place. So
  #CurPath is searched in full first, exactly as before, and a script that works today loads the
  same file whatever folders are added. Nothing found: '' (CALL does nothing, as always).

  A folder list is written as PATH is: folders separated by ';'. Spaces around an entry are dropped,
  quotes are removed (a ';' inside quotes is part of the folder), empty entries are skipped and '/'
  is read as '\'. A relative folder starts from #CurPath, as a relative CALL name does (EUOCli makes
  its own folders absolute from the current folder before they get here). A folder that does not
  exist finds nothing; one already searched, #CurPath included, is not searched again.

  The interpreter never reads the registry: a host reads the saved list (ReadSavedCallPath) and
  hands it over (TEuoInterpreter.CallPath), so the test suite does not depend on the machine's
  settings. EUOCALLPATH is read at each lookup, in every host.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

const
  CallPathEnvVar   = 'EUOCALLPATH';
  // The original EasyUO's \Software\EasyUO is left alone, as for the Watches (euwatch.pas).
  CallPathRegKey   = '\Software\EasyUO Reforged';
  CallPathRegValue = 'CallPath';

// Text's folders, in order (see the header); relative ones are left relative.
procedure SplitCallPath(const Text : String; List : TStrings);
// List's folders as one ';' list, without empty entries; a folder with a ';' is quoted.
function  JoinCallPath(List : TStrings) : String;
// The original's test for an absolute name: a drive ("X:\") or a leading backslash.
function  IsAbsoluteCallName(const Name : String) : Boolean;
// EUOCALLPATH's value, '' when it is not set.
function  EnvCallPath : String;
// The folders CALL searches after #CurPath, in order: ListPath's, EUOCALLPATH's, LastPath's.
procedure CallSearchFolders(const ListPath, LastPath : String; List : TStrings);
// The file a CALL of Name loads (see the header), or ''. CurPath is #CurPath, ending with '\'.
function  ResolveCallName(const Name, CurPath : String; Folders : TStrings) : String;
// The folder list the editor saved ('' when none), and saving it ('' removes it; False when the
// registry cannot be written).
function  ReadSavedCallPath : String;
function  WriteSavedCallPath(const Value : String) : Boolean;

implementation

uses
  Windows, Registry;

////////////////////////////////////////////////////////////////////////////////
procedure SplitCallPath(const Text : String; List : TStrings);
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
function JoinCallPath(List : TStrings) : String;
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
function IsAbsoluteCallName(const Name : String) : Boolean;
begin
  Result:=(Copy(Name,2,2)=':\')or(Copy(Name,1,1)='\');
end;

////////////////////////////////////////////////////////////////////////////////
// Read through the wide API: a folder name may have letters outside the ANSI code page.
function EnvCallPath : String;
var
  Name : UnicodeString;
  Buf  : UnicodeString;
  N    : DWORD;
begin
  Result:='';
  Name:=CallPathEnvVar;
  N:=GetEnvironmentVariableW(PWideChar(Name),nil,0);
  if N=0 then Exit;
  SetLength(Buf,N);
  N:=GetEnvironmentVariableW(PWideChar(Name),PWideChar(Buf),N);
  SetLength(Buf,N);
  Result:=UTF8Encode(Buf);
end;

////////////////////////////////////////////////////////////////////////////////
procedure CallSearchFolders(const ListPath, LastPath : String; List : TStrings);
begin
  SplitCallPath(ListPath,List);
  SplitCallPath(EnvCallPath,List);
  SplitCallPath(LastPath,List);
end;

////////////////////////////////////////////////////////////////////////////////
// Base, Base.txt or Base.euo, the first that exists; '' when none.
function FirstOf(const Base : String) : String;
begin
  Result:=Base;
  if FileExists(Result) then Exit;
  Result:=Base+'.txt';
  if FileExists(Result) then Exit;
  Result:=Base+'.euo';
  if FileExists(Result) then Exit;
  Result:='';
end;

////////////////////////////////////////////////////////////////////////////////
function ResolveCallName(const Name, CurPath : String; Folders : TStrings) : String;
var
  Seen   : TStringList;
  i      : Integer;
  Folder : String;
  Key    : String;
begin
  // 1 and 2: the original's lookup, character for character.
  if IsAbsoluteCallName(Name) then
  begin
    Result:=FirstOf(Name);
    Exit;
  end;
  Result:=FirstOf(CurPath+Name);
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
      if not IsAbsoluteCallName(Folder) then Folder:=CurPath+Folder;
      Folder:=IncludeTrailingPathDelimiter(Folder);
      Key:=IncludeTrailingPathDelimiter(ExpandFileName(Folder));
      if Seen.IndexOf(Key)>=0 then Continue;
      Seen.Add(Key);
      Result:=FirstOf(Folder+Name);
      if Result<>'' then Exit;
    end;
  finally
    Seen.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function ReadSavedCallPath : String;
var
  R : TRegistry;
begin
  Result:='';
  R:=TRegistry.Create;
  try
    try
      if R.OpenKeyReadOnly(CallPathRegKey) then
        if R.GetDataType(CallPathRegValue) in [rdString,rdExpandString] then
          Result:=R.ReadString(CallPathRegValue);
    except
      Result:='';
    end;
  finally
    R.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function WriteSavedCallPath(const Value : String) : Boolean;
var
  R : TRegistry;
begin
  Result:=False;
  R:=TRegistry.Create;
  try
    try
      if Value='' then
      begin
        if R.OpenKey(CallPathRegKey,False) then
          if R.ValueExists(CallPathRegValue) then R.DeleteValue(CallPathRegValue);
        Result:=True;
      end
      else if R.OpenKey(CallPathRegKey,True) then
      begin
        R.WriteString(CallPathRegValue,Value);
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
