unit clidocs;

{
  Port addition (docs\agent-support.md, phase 4): "EUOCli docs", and the euo_docs tool of
  the MCP server. It looks a command, a #variable or a guide up in the agent pack: the
  folder agent\euo-script of a release, which holds the documentation site as markdown
  files and their list as reference.json (tools\docs\gen-agent-pack.mjs writes both).

  Nothing about the language is stored here: a name is found in reference.json and the
  answer is the page's own file. Without a pack there is nothing to look up, and the answer
  says where the same pages are on the web.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

const
  DOCS_URL = 'https://ilpersi.github.io/EasyUOReforged/llms.txt';
  DocsMaxHits = 25;

// The pack's folder, with its trailing delimiter: Override when given, otherwise the one
// that came with the program. '' when there is none.
function FindPack(const ExeDir, Override : String) : String;

// Name: the page of that command ("finditem", "event macro"), #variable or guide, in full.
// Query: the names and one-line descriptions that hold every word of it. One of the two.
// False when nothing was found (or there is no pack); Text then says so.
function DocsLookup(const PackDir, Name, Query : String; out Text : String) : Boolean;

function RunDocs(Args : TStrings; const ExeDir : String; Output : TStrings) : Integer;
procedure DocsHelp(Output : TStrings);

implementation

uses
  fpjson, jsonparser, clicheck;

////////////////////////////////////////////////////////////////////////////////
procedure DocsHelp(Output : TStrings);
begin
  Output.Add('EUOCli docs <name> [--pack <folder>]');
  Output.Add('EUOCli docs --search <words> [--pack <folder>]');
  Output.Add('');
  Output.Add('Prints the documentation page of a command, a #variable or a guide:');
  Output.Add('  EUOCli docs finditem        EUOCli docs "event macro"        EUOCli docs #FindKind');
  Output.Add('With --search, lists the names whose name or one-line description holds every word:');
  Output.Add('  EUOCli docs --search journal');
  Output.Add('');
  Output.Add('  --pack <folder>   the agent pack to read. Default: agent\euo-script next to EUOCli.exe');
  Output.Add('');
  Output.Add('Exit code: 0 found; 1 nothing found; 2 wrong command line, or there is no pack.');
end;

////////////////////////////////////////////////////////////////////////////////
function FindPack(const ExeDir, Override : String) : String;
const
  Places : array[0..2] of String = ('agent\euo-script','euo-script','website\dist\agent\euo-script');
var
  i : Integer;
begin
  Result:='';
  if Override<>'' then
  begin
    if FileExists(IncludeTrailingPathDelimiter(Override)+'reference.json') then
      Result:=IncludeTrailingPathDelimiter(Override);
    Exit;
  end;
  for i:=Low(Places) to High(Places) do
    if FileExists(IncludeTrailingPathDelimiter(ExeDir)+Places[i]+PathDelim+'reference.json') then
      Exit(IncludeTrailingPathDelimiter(ExeDir)+Places[i]+PathDelim);
end;

////////////////////////////////////////////////////////////////////////////////
// Lower case, one space between words, none at the ends.
function Squeeze(const S : String) : String;
var
  i : Integer;
begin
  Result:='';
  for i:=1 to Length(S) do
    if S[i] in [' ',#9,#13,#10] then
    begin
      if (Result<>'') and (Result[Length(Result)]<>' ') then Result:=Result+' ';
    end
    else Result:=Result+LowerCase(S[i]);
  Result:=Trim(Result);
end;

////////////////////////////////////////////////////////////////////////////////
function Joined(Arr : TJSONArray) : String;
var
  i : Integer;
begin
  Result:='';
  if Arr=nil then Exit;
  for i:=0 to Arr.Count-1 do Result:=Result+' '+Arr.Strings[i];
end;

////////////////////////////////////////////////////////////////////////////////
function ReadFileText(const FileName : String) : String;
var
  SL : TStringList;
begin
  SL:=TStringList.Create;
  try
    SL.LoadFromFile(FileName);
    Result:=SL.Text;
  finally
    SL.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// One line of a search result.
function HitLine(Item : TJSONObject) : String;
begin
  Result:=Item.Get('name',Item.Get('title',''));
  if Item.Get('needsClient',False) then Result:=Result+' [client]';
  if Item.Get('origin','')='reforged' then Result:=Result+' [new]';
  Result:=Result+': '+Item.Get('description','')+'  ('+Item.Get('file','')+')';
end;

////////////////////////////////////////////////////////////////////////////////
// The entries whose name, description or aliases hold every word of Query: the ones with
// the first word in their name first.
procedure Search(Root : TJSONObject; const Query : String; Hits : TStrings);
const
  Lists : array[0..2] of String = ('commands','variables','pages');
var
  Words     : TStringList;
  Later     : TStringList;
  l, i, w   : Integer;
  Arr       : TJSONArray;
  Item      : TJSONObject;
  Name, Hay : String;
  Fits      : Boolean;
begin
  Words:=TStringList.Create;
  Later:=TStringList.Create;
  try
    Words.Delimiter:=' ';
    Words.StrictDelimiter:=True;
    Words.DelimitedText:=Squeeze(Query);
    if Words.Count=0 then Exit;
    for l:=Low(Lists) to High(Lists) do
    begin
      Arr:=Root.Get(Lists[l],TJSONArray(nil));
      if Arr=nil then Continue;
      for i:=0 to Arr.Count-1 do
      begin
        Item:=Arr.Objects[i];
        Name:=LowerCase(Item.Get('name',Item.Get('title','')));
        Hay:=Name+' '+LowerCase(Item.Get('title','')+' '+Item.Get('description','')+' '+
          Item.Get('category','')+Joined(Item.Get('aliases',TJSONArray(nil))));
        Fits:=True;
        for w:=0 to Words.Count-1 do
          if Pos(Words[w],Hay)=0 then Fits:=False;
        if not Fits then Continue;
        if Pos(Words[0],Name)>0 then Hits.Add(HitLine(Item)) else Later.Add(HitLine(Item));
      end;
    end;
    Hits.AddStrings(Later);
  finally
    Later.Free;
    Words.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// The entry called Name: a command, a variable (with or without its #), an alias of one of
// them, or a guide by its title. nil when there is none.
function FindEntry(Root : TJSONObject; const Name : String) : TJSONObject;
const
  Lists : array[0..2] of String = ('commands','variables','pages');
var
  Key     : String;
  Pass    : Integer;
  l, i, k : Integer;
  Arr     : TJSONArray;
  Aliases : TJSONArray;
  Item    : TJSONObject;
  Own     : String;
begin
  Result:=nil;
  Key:=Squeeze(Name);
  if Key='' then Exit;
  // Names first, then aliases: "skill" is an alias of chooseskill, and must not hide a
  // command or variable that is really called that.
  for Pass:=0 to 1 do
    for l:=Low(Lists) to High(Lists) do
    begin
      Arr:=Root.Get(Lists[l],TJSONArray(nil));
      if Arr=nil then Continue;
      for i:=0 to Arr.Count-1 do
      begin
        Item:=Arr.Objects[i];
        if Pass=0 then
        begin
          Own:=Squeeze(Item.Get('name',Item.Get('title','')));
          if (Own=Key) or (Own='#'+Key) then Exit(Item);
        end
        else begin
          Aliases:=Item.Get('aliases',TJSONArray(nil));
          if Aliases=nil then Continue;
          for k:=0 to Aliases.Count-1 do
            if Squeeze(Aliases.Strings[k])=Key then Exit(Item);
        end;
      end;
    end;
end;

////////////////////////////////////////////////////////////////////////////////
function DocsLookup(const PackDir, Name, Query : String; out Text : String) : Boolean;
var
  Data  : TJSONData;
  Root  : TJSONObject;
  Item  : TJSONObject;
  Hits  : TStringList;
  FN    : String;
  Asked : String;
begin
  Result:=False;
  if (PackDir='') or not FileExists(PackDir+'reference.json') then
  begin
    Text:='The documentation files are not here: the agent pack (the folder agent\euo-script of an '+
      'EasyUO Reforged release) was not found next to EUOCli.exe. The same pages are on the web: '+DOCS_URL;
    Exit;
  end;
  Data:=nil;
  Hits:=TStringList.Create;
  try
    try
      Data:=GetJSON(ReadFileText(PackDir+'reference.json'));
    except
      on E : Exception do
      begin
        Text:='cannot read '+PackDir+'reference.json: '+E.Message;
        Exit;
      end;
    end;
    if not (Data is TJSONObject) then
    begin
      Text:=PackDir+'reference.json is not the list this program expects';
      Exit;
    end;
    Root:=TJSONObject(Data);

    Asked:=Query;
    if Trim(Name)<>'' then
    begin
      Item:=FindEntry(Root,Name);
      if Item<>nil then
      begin
        FN:=PackDir+StringReplace(Item.Get('file',''),'/',PathDelim,[rfReplaceAll]);
        if FileExists(FN) then Text:=ReadFileText(FN)
        else Text:=HitLine(Item)+LineEnding+Item.Get('url','');
        Exit(True);
      end;
      Asked:=Name;
    end;

    Search(Root,Asked,Hits);
    if Hits.Count=0 then
    begin
      Text:='Nothing in the documentation matches "'+Trim(Asked)+'". EasyUO has no such command or '+
        'variable under that name: search for one word of what it should do.';
      Exit;
    end;
    if Trim(Name)<>'' then Text:='No page is called "'+Trim(Name)+'". These mention it:'+LineEnding
    else Text:='';
    while Hits.Count>DocsMaxHits do Hits.Delete(Hits.Count-1);
    Text:=Text+Hits.Text+'Ask for one of these by its name to read its page.';
    // A search that found something is an answer; a name that was not found is not.
    Result:=Trim(Name)='';
  finally
    Hits.Free;
    Data.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function RunDocs(Args : TStrings; const ExeDir : String; Output : TStrings) : Integer;
var
  Pack, Words, A, Text : String;
  Search               : Boolean;
  i                    : Integer;

  function Fail(const Msg : String) : Integer;
  begin
    Output.Add('EUOCli docs: '+Msg);
    Output.Add('Try: EUOCli help docs');
    Result:=CLI_USAGE;
  end;

begin
  Pack:='';
  Words:='';
  Search:=False;
  i:=0;
  while i<Args.Count do
  begin
    A:=Args[i];
    if A='--search' then Search:=True
    else if A='--pack' then
    begin
      Inc(i);
      if i>=Args.Count then Exit(Fail('--pack needs a folder'));
      Pack:=Args[i];
    end
    else if Copy(A,1,2)='--' then Exit(Fail('unknown option '+A))
    else Words:=Trim(Words+' '+A);
    Inc(i);
  end;
  if Words='' then Exit(Fail('no name given'));

  A:=FindPack(ExeDir,Pack);
  if A='' then
  begin
    if Pack<>'' then Output.Add('EUOCli docs: there is no agent pack in '+Pack+' (no reference.json)')
    else DocsLookup('','','',Text);
    if Pack='' then Output.Add('EUOCli docs: '+Text);
    Exit(CLI_USAGE);
  end;

  if Search then
  begin
    if DocsLookup(A,'',Words,Text) then Result:=CLI_OK else Result:=CLI_WARNINGS;
  end
  else begin
    if DocsLookup(A,Words,'',Text) then Result:=CLI_OK else Result:=CLI_WARNINGS;
  end;
  Output.Text:=Text;
end;

end.
