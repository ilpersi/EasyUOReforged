unit caarchive;

{
  Port addition: the logic of EUOClientArchiver, a developer tool that keeps a copy of each UO
  client build before the patcher overwrites it (brief: docs/client-archiver-prompt.md; page:
  website/src/content/docs/developers/archiving-clients.md). No LCL here: the window is camain.pas,
  and the test suite (tests/ClientArchiverTests.pas) calls this unit directly.

  - Finding: exactly the names in ClientNames, matched without regard to case.
  - Identifying: the version from VS_FIXEDFILEINFO (never the file name), the PE stamp and the
    relocatable bit from the PE header (the fields common/access.pas's ReadImageInfo reads from a
    process, here from the file), the size, the last-write time and the SHA-256.
  - Archiving: one ZIP per client, Deflate at clmax with FPC's zipper. The exe is renamed only inside
    the archive, to <base>_<version>.exe, beside a <base>_<version>.txt of "key  value" lines. The
    file is read once into memory with fmShareDenyNone and zipped from there: zipper itself opens
    disk files with a plain fmOpenRead, and the client may be running. Nothing is ever overwritten:
    a same-name archive with other bytes sends the build to <base>_<version>_<STAMP>.zip, and a
    clash there is an error. The archive is written as .partial, read back and compared before it
    gets its name.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

const
  // The client files the tool archives. Adding a name here is all it takes.
  ClientNames : array[0..1] of String = ('client.exe', 'client_beta.exe');

  StatusArchived    = 'archived';
  StatusNotArchived = 'not archived yet';

type
  TPeInfo = record
    Valid       : Boolean;
    Stamp       : Cardinal;   // FileHeader.TimeDateStamp
    Relocatable : Boolean;    // OptionalHeader.DllCharacteristics and $40 (DYNAMIC_BASE)
    Error       : String;     // why it is not a PE file, when not Valid
  end;

  TClientInfo = record
    Name          : String;     // the name in ClientNames
    Found         : Boolean;
    Path          : String;     // full path, the file name as it is on disk
    Version       : String;     // '' when the file has no version resource
    Pe            : TPeInfo;
    Size          : Int64;
    Sha256        : String;
    ModifiedUtc   : TDateTime;
    ModifiedLocal : TDateTime;  // the last-write time as zipper dates an entry from a disk file
    Error         : String;     // why it cannot be archived; '' when it can
  end;
  TClientInfos = array of TClientInfo;

  // Where a build stands against the archive folder (step 3 of the brief).
  TLookupKind = (lkWriteMain,    // no archive holds it: write <base>_<v>.zip
                 lkWriteStamp,   // <base>_<v>.zip holds other bytes: write <base>_<v>_<STAMP>.zip
                 lkArchived,     // one of the two holds these very bytes
                 lkClash,        // both hold other bytes
                 lkUnreadable);  // one of them cannot be read
  TLookup = record
    Kind    : TLookupKind;
    ZipPath : String;   // the matching zip, the one to write, or the one in question
    Error   : String;   // lkUnreadable
  end;

  TArchiveStatus = (arArchived, arSkipped, arFailed);
  TArchiveResult = record
    Status     : TArchiveStatus;
    ZipPath    : String;
    Line       : String;   // the log line
    SizeBefore : Int64;
    SizeAfter  : Int64;
  end;

  TArchiveCounts = record
    Archived, Skipped, Failed : Integer;
  end;

  // One row of the list of archived builds, read back from a zip's .txt.
  TArchivedBuild = record
    ZipName     : String;
    HasInfo     : Boolean;   // False: not a zip, or no .txt of ours in it
    Version     : String;
    Stamp       : String;    // 8 hex digits
    Relocatable : String;
    Archived    : String;
    Note        : String;
  end;
  TArchivedBuilds = array of TArchivedBuild;

// Identifying
function FormatFileVersion(MS, LS : Cardinal) : String;
function ReadFileVersion(const FileName : String; out Version : String) : Boolean;
function ReadPeInfo(Buf : Pointer; Len : SizeInt) : TPeInfo;
function IdentifyClient(const Name, Path : String) : TClientInfo;
function FindClients(const Folder : String; out Infos : TClientInfos; out Error : String) : Boolean;
function CanArchive(const Info : TClientInfo) : Boolean;

// The archive folder
function EntryBaseOf(const Name, Version : String) : String;
function LookUpArchive(const ArchiveFolder, EntryBase : String; Stamp : Cardinal;
  const Sha256 : String) : TLookup;
function ArchivedStatus(const Info : TClientInfo; const ArchiveFolder : String) : String;
function ArchiveClient(const Name, Path, ArchiveFolder, Note : String; NowUtc : TDateTime) : TArchiveResult;
function ArchiveAll(const ClientFolder, ArchiveFolder, Note : String; Log : TStrings;
  AfterLine : TNotifyEvent = nil) : TArchiveCounts;
function ListArchivedBuilds(const Folder : String) : TArchivedBuilds;
function FindGitFolder(const Folder : String) : String;

// Reading a zip without changing it
function ZipEntryNames(const ZipPath : String; Names : TStrings) : Boolean;
procedure ExtractEntry(const ZipPath, EntryName : String; Data : TMemoryStream);

// Text
function StampHex(Stamp : Cardinal) : String;
function StampLine(Stamp : Cardinal) : String;
function UtcText(DT : TDateTime) : String;
function UtcNow : TDateTime;
function GroupThousands(N : Int64) : String;
function CleanNote(const S : String) : String;
function DescribeClient(const Info : TClientInfo; const Status : String) : String;
function InfoText(const Info : TClientInfo; const Note : String; NowUtc : TDateTime) : String;
function ParseInfoText(const Text : String) : TStringList;
function SummaryLine(const Counts : TArchiveCounts) : String;

implementation

uses
  Windows, DateUtils, zipper, zstream, casha256;

const
  KeyWidth = 17;   // "original folder" and two spaces

var
  Fmt : TFormatSettings;   // fixed separators, whatever the locale

////////////////////////////////////////////////////////////////////////////////
// Text
////////////////////////////////////////////////////////////////////////////////
function StampHex(Stamp : Cardinal) : String;
begin
  Result:=IntToHex(Stamp,8);
end;

function UtcText(DT : TDateTime) : String;
begin
  Result:=FormatDateTime('yyyy-mm-dd hh:nn:ss',DT,Fmt)+' UTC';
end;

// The PE stamp is a Unix time: 6AD994F1 (2026-10-22 04:45:37 UTC).
function StampLine(Stamp : Cardinal) : String;
begin
  Result:=StampHex(Stamp)+' ('+UtcText(UnixToDateTime(Stamp))+')';
end;

function UtcNow : TDateTime;
var
  ST : TSystemTime;
begin
  GetSystemTime(ST);
  Result:=SystemTimeToDateTime(ST);
end;

function GroupThousands(N : Int64) : String;
var
  Cnt : Integer;
  Neg : Boolean;
begin
  Neg:=N<0;
  Result:=IntToStr(Abs(N));
  Cnt:=Length(Result)-3;
  while Cnt>0 do
  begin
    Insert(',',Result,Cnt+1);
    Dec(Cnt,3);
  end;
  if Neg then Result:='-'+Result;
end;

// One line of text: control characters become spaces, then it is trimmed.
function CleanNote(const S : String) : String;
var
  Cnt : Integer;
begin
  Result:=S;
  for Cnt:=1 to Length(Result) do
    if (Result[Cnt]<' ') or (Result[Cnt]=#127) then Result[Cnt]:=' ';
  Result:=Trim(Result);
end;

function BoolText(B : Boolean) : String;
begin
  if B then Result:='True' else Result:='False';
end;

function NameWidth : Integer;
var
  Cnt : Integer;
begin
  Result:=0;
  for Cnt:=0 to High(ClientNames) do
    if Length(ClientNames[Cnt])>Result then Result:=Length(ClientNames[Cnt]);
  Inc(Result,2);
end;

function PadTo(const S : String; Width : Integer) : String;
begin
  Result:=S;
  if Length(Result)<Width then Result:=Result+StringOfChar(' ',Width-Length(Result));
end;

// The window's line for one client, e.g.
// client.exe       7.0.117.33  stamp 6AD994F1  3,616,768 bytes  archived
function DescribeClient(const Info : TClientInfo; const Status : String) : String;
begin
  Result:=PadTo(Info.Name,NameWidth);
  if not Info.Found then Result:=Result+'not found'
  else if Info.Error<>'' then Result:=Result+Info.Error
  else
  begin
    Result:=Result+Info.Version+'  stamp '+StampHex(Info.Pe.Stamp)+'  '+
      GroupThousands(Info.Size)+' bytes';
    if Status<>'' then Result:=Result+'  '+Status;
  end;
end;

function FolderOf(const Path : String) : String;
begin
  Result:=ExcludeTrailingPathDelimiter(ExtractFilePath(Path));
  if (Result<>'') and (Result[Length(Result)]=':') then Result:=Result+'\';
end;

// The .txt beside the exe: "key  value" lines, CRLF. Read back by key (ParseInfoText).
function InfoText(const Info : TClientInfo; const Note : String; NowUtc : TDateTime) : String;
var
  N : String;

  procedure Add(const Key, Value : String);
  begin
    Result:=Result+PadTo(Key,KeyWidth)+Value+#13#10;
  end;

begin
  Result:='';
  Add('original name',ExtractFileName(Info.Path));
  Add('original folder',FolderOf(Info.Path));
  Add('version',Info.Version);
  Add('PE stamp',StampLine(Info.Pe.Stamp));
  Add('relocatable',BoolText(Info.Pe.Relocatable));
  Add('size',IntToStr(Info.Size));
  Add('sha256',Info.Sha256);
  Add('last modified',UtcText(Info.ModifiedUtc));
  Add('archived',UtcText(NowUtc));
  N:=CleanNote(Note);
  if N<>'' then Add('note',N);
end;

// key=value pairs (the caller frees the list). Keys hold single spaces only, so a line splits at
// its first double space.
function ParseInfoText(const Text : String) : TStringList;
var
  Lines : TStringList;
  Cnt   : Integer;
  P     : Integer;
  Line  : String;
begin
  Result:=TStringList.Create;
  Lines:=TStringList.Create;
  try
    Lines.Text:=Text;
    for Cnt:=0 to Lines.Count-1 do
    begin
      Line:=Lines[Cnt];
      P:=Pos('  ',Line);
      if P<2 then Continue;
      Result.Add(Trim(Copy(Line,1,P-1))+'='+Trim(Copy(Line,P,MaxInt)));
    end;
  finally
    Lines.Free;
  end;
end;

function SummaryLine(const Counts : TArchiveCounts) : String;
begin
  Result:=Format('%d archived, %d skipped, %d failed',[Counts.Archived,Counts.Skipped,Counts.Failed]);
end;

function PercentText(Part, Whole : Int64) : String;
begin
  if Whole<=0 then Result:='-'
  else Result:=FormatFloat('0.0',Part*100/Whole,Fmt)+' %';
end;

////////////////////////////////////////////////////////////////////////////////
// Identifying
////////////////////////////////////////////////////////////////////////////////
function FormatFileVersion(MS, LS : Cardinal) : String;
begin
  Result:=IntToStr(HiWord(MS))+'.'+IntToStr(LoWord(MS))+'.'+IntToStr(HiWord(LS))+'.'+
    IntToStr(LoWord(LS));
end;

// The file's VS_FIXEDFILEINFO version. False when it has none (never guessed).
function ReadFileVersion(const FileName : String; out Version : String) : Boolean;
var
  W, Root : UnicodeString;
  Size    : DWORD;
  Dummy   : DWORD;
  Buf     : array of Byte;
  Info    : PVSFixedFileInfo;
  Len     : UINT;
begin
  Result:=False;
  Version:='';
  W:=UnicodeString(FileName);
  Root:='\';
  Dummy:=0;
  Size:=GetFileVersionInfoSizeW(PWideChar(W),Dummy);
  if Size=0 then Exit;
  SetLength(Buf,Size);
  if not GetFileVersionInfoW(PWideChar(W),0,Size,@Buf[0]) then Exit;
  Info:=nil;
  Len:=0;
  if not VerQueryValueW(@Buf[0],PWideChar(Root),Pointer(Info),Len) then Exit;
  if (Info=nil) or (Len<SizeOf(TVSFixedFileInfo)) or (Info^.dwSignature<>$FEEF04BD) then Exit;
  Version:=FormatFileVersion(Info^.dwFileVersionMS,Info^.dwFileVersionLS);
  Result:=True;
end;

// The PE fields that identify a build, from the start of the file. DllCharacteristics sits at
// PE+$5E in both the 32-bit and the 64-bit optional header.
function ReadPeInfo(Buf : Pointer; Len : SizeInt) : TPeInfo;

  function At(Offset : SizeInt) : Pointer;
  begin
    Result:=Pointer(PtrUInt(Buf)+PtrUInt(Offset));
  end;

var
  PE : Cardinal;
begin
  Result.Valid:=False;
  Result.Stamp:=0;
  Result.Relocatable:=False;
  Result.Error:='';
  if (Buf=nil) or (Len<$40) or (PWord(Buf)^<>$5A4D) then        // 'MZ'
  begin
    Result.Error:='no MZ header';
    Exit;
  end;
  PE:=PCardinal(At($3C))^;                                      // e_lfanew
  if Int64(PE)+$60>Len then
  begin
    Result.Error:='bad e_lfanew';
    Exit;
  end;
  if PCardinal(At(PE))^<>$00004550 then                         // 'PE'#0#0
  begin
    Result.Error:='no PE signature';
    Exit;
  end;
  if PWord(At(PE+20))^<72 then                                  // SizeOfOptionalHeader
  begin
    Result.Error:='optional header too short';
    Exit;
  end;
  Result.Stamp:=PCardinal(At(PE+8))^;
  Result.Relocatable:=(PWord(At(PE+$5E))^ and $40)<>0;
  Result.Valid:=True;
end;

// Reads the file into Data (fmShareDenyNone: the client may be running) and identifies it.
function LoadClient(const Name, Path : String; Data : TMemoryStream) : TClientInfo;
var
  FS   : TFileStream;
  SR   : TSearchRec;
  Attr : TWin32FileAttributeData;
  ST   : TSystemTime;
begin
  Result:=Default(TClientInfo);
  Result.Name:=Name;
  Result.Path:=Path;
  Result.Found:=True;
  try
    FS:=TFileStream.Create(Path,fmOpenRead or fmShareDenyNone);
    try
      Data.LoadFromStream(FS);
    finally
      FS.Free;
    end;
  except
    on E : Exception do
    begin
      Result.Error:='cannot read it: '+E.Message;
      Exit;
    end;
  end;
  Data.Position:=0;
  Result.Size:=Data.Size;
  Result.Sha256:=Sha256Hex(Data.Memory,Data.Size);
  Result.Pe:=ReadPeInfo(Data.Memory,Data.Size);
  if GetFileAttributesExW(PWideChar(UnicodeString(Path)),GetFileExInfoStandard,@Attr) and
     FileTimeToSystemTime(Attr.ftLastWriteTime,ST) then
    Result.ModifiedUtc:=SystemTimeToDateTime(ST);
  // What zipper's own GetFileInfo would put into the entry for this disk file.
  if FindFirst(Path,faAnyFile,SR)=0 then
  begin
    Result.ModifiedLocal:=FileDateToDateTime(SR.Time);
    SysUtils.FindClose(SR);
  end;
  if not ReadFileVersion(Path,Result.Version) then
    Result.Error:='no version resource, not archived'
  else if not Result.Pe.Valid then
    Result.Error:='not a PE file ('+Result.Pe.Error+'), not archived';
end;

function IdentifyClient(const Name, Path : String) : TClientInfo;
var
  Data : TMemoryStream;
begin
  Data:=TMemoryStream.Create;
  try
    Result:=LoadClient(Name,Path,Data);
  finally
    Data.Free;
  end;
end;

function CanArchive(const Info : TClientInfo) : Boolean;
begin
  Result:=Info.Found and (Info.Error='');
end;

// One entry per ClientNames name, found or not. False, with the reason, when the folder does
// not exist or holds none of them.
function FindClients(const Folder : String; out Infos : TClientInfos; out Error : String) : Boolean;
var
  SR    : TSearchRec;
  Dir   : String;
  Cnt   : Integer;
  Any   : Boolean;
  Names : String;
begin
  Infos:=nil;
  Error:='';
  SetLength(Infos,Length(ClientNames));
  Names:='';
  for Cnt:=0 to High(ClientNames) do
  begin
    Infos[Cnt]:=Default(TClientInfo);
    Infos[Cnt].Name:=ClientNames[Cnt];
    if Cnt>0 then Names:=Names+' or ';
    Names:=Names+ClientNames[Cnt];
  end;
  Result:=False;
  if Trim(Folder)='' then
  begin
    Error:='No client folder';
    Exit;
  end;
  if not DirectoryExists(Folder) then
  begin
    Error:='The folder does not exist';
    Exit;
  end;
  Dir:=IncludeTrailingPathDelimiter(Folder);
  Any:=False;
  if FindFirst(Dir+'*',faAnyFile,SR)=0 then
  try
    repeat
      if (SR.Attr and faDirectory)<>0 then Continue;
      for Cnt:=0 to High(ClientNames) do
        if (not Infos[Cnt].Found) and SameText(SR.Name,ClientNames[Cnt]) then
        begin
          Infos[Cnt]:=IdentifyClient(ClientNames[Cnt],Dir+SR.Name);
          Any:=True;
        end;
    until FindNext(SR)<>0;
  finally
    SysUtils.FindClose(SR);
  end;
  if not Any then
  begin
    Error:='No '+Names+' in this folder';
    Exit;
  end;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
// Reading a zip into memory. TUnZipper writes nothing when a stream is supplied: no file is
// created and no time is set.
////////////////////////////////////////////////////////////////////////////////
type
  TMemTarget = class
  public
    Data : TMemoryStream;
    procedure CreateStream(Sender : TObject; var AStream : TStream; AItem : TFullZipFileEntry);
    procedure DoneStream(Sender : TObject; var AStream : TStream; AItem : TFullZipFileEntry);
  end;

procedure TMemTarget.CreateStream(Sender : TObject; var AStream : TStream; AItem : TFullZipFileEntry);
begin
  AStream:=TMemoryStream.Create;
end;

procedure TMemTarget.DoneStream(Sender : TObject; var AStream : TStream; AItem : TFullZipFileEntry);
begin
  // The unzipper lets go of the stream after this call: copy it out and free it.
  try
    if Data<>nil then
    begin
      Data.Clear;
      if AStream<>nil then Data.CopyFrom(AStream,0);
      Data.Position:=0;
    end;
  finally
    FreeAndNil(AStream);
  end;
end;

function ZipEntryNames(const ZipPath : String; Names : TStrings) : Boolean;
var
  UZ  : TUnZipper;
  Cnt : Integer;
begin
  Names.Clear;
  UZ:=TUnZipper.Create;
  try
    UZ.FileName:=ZipPath;
    UZ.Examine;
    for Cnt:=0 to UZ.Entries.Count-1 do Names.Add(UZ.Entries[Cnt].ArchiveFileName);
    Result:=True;
  finally
    UZ.Free;
  end;
end;

// The named entry's bytes, into Data. Raises when the zip cannot be read, the entry is missing
// or its CRC is wrong.
procedure ExtractEntry(const ZipPath, EntryName : String; Data : TMemoryStream);
var
  UZ     : TUnZipper;
  Target : TMemTarget;
  Names  : TStringList;
begin
  Names:=TStringList.Create;
  try
    ZipEntryNames(ZipPath,Names);
    if Names.IndexOf(EntryName)<0 then
      raise Exception.CreateFmt('it has no entry %s',[EntryName]);
  finally
    Names.Free;
  end;
  Data.Clear;
  Target:=TMemTarget.Create;
  UZ:=TUnZipper.Create;
  try
    Target.Data:=Data;
    UZ.OnCreateStream:=Target.CreateStream;
    UZ.OnDoneStream:=Target.DoneStream;
    UZ.UnZipFiles(ZipPath,[EntryName]);
  finally
    UZ.Free;
    Target.Free;
  end;
end;

// The first entry with the extension Ext, preferring Preferred.
function PickEntry(const ZipPath, Preferred, Ext : String) : String;
var
  Names : TStringList;
  Cnt   : Integer;
begin
  Result:='';
  Names:=TStringList.Create;
  try
    ZipEntryNames(ZipPath,Names);
    if Names.IndexOf(Preferred)>=0 then Exit(Preferred);
    for Cnt:=0 to Names.Count-1 do
      if SameText(ExtractFileExt(Names[Cnt]),Ext) then Exit(Names[Cnt]);
  finally
    Names.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// The archive folder
////////////////////////////////////////////////////////////////////////////////
function EntryBaseOf(const Name, Version : String) : String;
begin
  Result:=ChangeFileExt(Name,'')+'_'+Version;
end;

type
  TZipHolds = (zhSame, zhDifferent, zhUnreadable);

// Whether the zip's executable has this SHA-256.
function ZipHolds(const ZipPath, EntryName, Sha256 : String; out Error : String) : TZipHolds;
var
  Data  : TMemoryStream;
  Entry : String;
begin
  Error:='';
  Data:=TMemoryStream.Create;
  try
    try
      Entry:=PickEntry(ZipPath,EntryName,'.exe');
      if Entry='' then raise Exception.Create('it holds no .exe');
      ExtractEntry(ZipPath,Entry,Data);
      if Sha256Hex(Data.Memory,Data.Size)=Sha256 then Result:=zhSame
      else Result:=zhDifferent;
    except
      on E : Exception do
      begin
        Error:=E.Message;
        Result:=zhUnreadable;
      end;
    end;
  finally
    Data.Free;
  end;
end;

// Step 3 of the brief, shared by archiving and the window's status.
function LookUpArchive(const ArchiveFolder, EntryBase : String; Stamp : Cardinal;
  const Sha256 : String) : TLookup;
var
  Dir, Main, Second, SecondBase, Err : String;
begin
  Result.Error:='';
  Err:='';
  Dir:=IncludeTrailingPathDelimiter(ArchiveFolder);
  Main:=Dir+EntryBase+'.zip';
  SecondBase:=EntryBase+'_'+StampHex(Stamp);
  Second:=Dir+SecondBase+'.zip';

  // The main archive first; when it is missing the build may still sit in the stamp archive.
  if FileExists(Main) then
    case ZipHolds(Main,EntryBase+'.exe',Sha256,Err) of
      zhSame :
        begin
          Result.Kind:=lkArchived;
          Result.ZipPath:=Main;
          Exit;
        end;
      zhUnreadable :
        begin
          Result.Kind:=lkUnreadable;
          Result.ZipPath:=Main;
          Result.Error:=Err;
          Exit;
        end;
    end;

  if FileExists(Second) then
    case ZipHolds(Second,SecondBase+'.exe',Sha256,Err) of
      zhSame :
        begin
          Result.Kind:=lkArchived;
          Result.ZipPath:=Second;
          Exit;
        end;
      zhUnreadable :
        if FileExists(Main) then
        begin
          Result.Kind:=lkUnreadable;
          Result.ZipPath:=Second;
          Result.Error:=Err;
          Exit;
        end;
      zhDifferent :
        if FileExists(Main) then
        begin
          Result.Kind:=lkClash;
          Result.ZipPath:=Second;
          Exit;
        end;
    end;

  if not FileExists(Main) then
  begin
    Result.Kind:=lkWriteMain;
    Result.ZipPath:=Main;
  end
  else
  begin
    Result.Kind:=lkWriteStamp;
    Result.ZipPath:=Second;
  end;
end;

// 'archived', 'not archived yet', or '' when the client cannot be archived or no archive
// folder is set.
function ArchivedStatus(const Info : TClientInfo; const ArchiveFolder : String) : String;
begin
  Result:='';
  if (not CanArchive(Info)) or (Trim(ArchiveFolder)='') then Exit;
  if LookUpArchive(ArchiveFolder,EntryBaseOf(Info.Name,Info.Version),Info.Pe.Stamp,
       Info.Sha256).Kind=lkArchived then
    Result:=StatusArchived
  else
    Result:=StatusNotArchived;
end;

// The .partial holds exactly the two entries, and the exe has the source's size and SHA-256.
// '' when it does, else the reason.
function VerifyZip(const ZipPath, EntryBase : String; Size : Int64; const Sha256 : String) : String;
var
  Names : TStringList;
  Data  : TMemoryStream;
begin
  Result:='';
  Names:=TStringList.Create;
  Data:=TMemoryStream.Create;
  try
    try
      ZipEntryNames(ZipPath,Names);
      if (Names.Count<>2) or (Names[0]<>EntryBase+'.exe') or (Names[1]<>EntryBase+'.txt') then
        Exit('unexpected entries: '+Names.CommaText);
      ExtractEntry(ZipPath,EntryBase+'.exe',Data);
      if Data.Size<>Size then
        Exit(Format('the exe has %d bytes, not %d',[Data.Size,Size]));
      if Sha256Hex(Data.Memory,Data.Size)<>Sha256 then
        Exit('the exe has a different SHA-256');
    except
      on E : Exception do Result:=E.Message;
    end;
  finally
    Data.Free;
    Names.Free;
  end;
end;

function Utf8Bytes(const S : String) : RawByteString;
begin
  Result:=UTF8Encode(UnicodeString(S));
end;

function FileSizeOf(const Path : String) : Int64;
var
  SR : TSearchRec;
begin
  Result:=-1;
  if FindFirst(Path,faAnyFile,SR)=0 then
  begin
    Result:=SR.Size;
    SysUtils.FindClose(SR);
  end;
end;

function ArchiveClient(const Name, Path, ArchiveFolder, Note : String; NowUtc : TDateTime) : TArchiveResult;
var
  Data      : TMemoryStream;
  Txt       : TMemoryStream;
  Raw       : RawByteString;
  Info      : TClientInfo;
  Look      : TLookup;
  Prefix    : String;
  EntryBase : String;
  MainName  : String;
  Final     : String;
  Partial   : String;
  Err       : String;
  Z         : TZipper;
  Entry     : TZipFileEntry;

  procedure Fail(const Msg : String);
  begin
    Result.Status:=arFailed;
    Result.Line:=Prefix+'error: '+Msg;
  end;

begin
  Result:=Default(TArchiveResult);
  Result.Status:=arFailed;
  Prefix:=ExtractFileName(Path)+': ';
  Partial:='';
  Data:=TMemoryStream.Create;
  try
    try
      Info:=LoadClient(Name,Path,Data);
      Result.SizeBefore:=Info.Size;
      if Info.Error<>'' then
      begin
        Fail(Info.Error);
        Exit;
      end;

      EntryBase:=EntryBaseOf(Name,Info.Version);
      MainName:=EntryBase+'.zip';
      if Trim(ArchiveFolder)='' then
      begin
        Fail('no archive folder');
        Exit;
      end;
      Look:=LookUpArchive(ArchiveFolder,EntryBase,Info.Pe.Stamp,Info.Sha256);
      case Look.Kind of
        lkArchived :
          begin
            Result.Status:=arSkipped;
            Result.ZipPath:=Look.ZipPath;
            Result.Line:=Prefix+'already archived in '+Look.ZipPath;
            Exit;
          end;
        lkUnreadable :
          begin
            Fail('cannot read '+Look.ZipPath+' ('+Look.Error+'); nothing was written, please look at it');
            Exit;
          end;
        lkClash :
          begin
            Fail(Format('%s and %s both hold a different build of version %s, stamp %s; '+
              'please look at them, nothing was overwritten',
              [MainName,ExtractFileName(Look.ZipPath),Info.Version,StampHex(Info.Pe.Stamp)]));
            Exit;
          end;
        lkWriteStamp :
          EntryBase:=EntryBase+'_'+StampHex(Info.Pe.Stamp);
      end;
      Final:=Look.ZipPath;

      if not ForceDirectories(ArchiveFolder) then
      begin
        Fail('cannot create the archive folder '+ArchiveFolder);
        Exit;
      end;
      Partial:=Final+'.partial';
      if FileExists(Partial) and not SysUtils.DeleteFile(Partial) then
      begin
        Fail('cannot replace '+Partial);
        Partial:='';
        Exit;
      end;

      // The bytes go in as they are: a TStringStream would convert them to the ANSI code page.
      Raw:=Utf8Bytes(InfoText(Info,Note,NowUtc));
      Txt:=TMemoryStream.Create;
      if Raw<>'' then Txt.WriteBuffer(Raw[1],Length(Raw));
      Z:=TZipper.Create;
      try
        Z.FileName:=Partial;
        Z.InMemSize:=High(Int64);   // else zipper puts a <name>.zip00000.tmp beside the archive
        Data.Position:=0;
        Entry:=Z.Entries.AddFileEntry(Data,EntryBase+'.exe');
        Entry.DateTime:=Info.ModifiedLocal;
        Entry.CompressionLevel:=clmax;
        Txt.Position:=0;
        Entry:=Z.Entries.AddFileEntry(Txt,EntryBase+'.txt');
        Entry.CompressionLevel:=clmax;
        Z.ZipAllFiles;
      finally
        Z.Free;
        Txt.Free;
      end;

      Err:=VerifyZip(Partial,EntryBase,Info.Size,Info.Sha256);
      if Err<>'' then
      begin
        Fail('the archive did not verify ('+Err+'); it was deleted');
        Exit;
      end;
      if FileExists(Final) then
      begin
        Fail(Final+' appeared while archiving; nothing was overwritten');
        Exit;
      end;
      if not MoveFileW(PWideChar(UnicodeString(Partial)),PWideChar(UnicodeString(Final))) then
      begin
        Fail('cannot rename '+Partial+': '+SysErrorMessage(GetLastError));
        Exit;
      end;
      Partial:='';

      Result.Status:=arArchived;
      Result.ZipPath:=Final;
      Result.SizeAfter:=FileSizeOf(Final);
      Result.Line:=Prefix;
      if Look.Kind=lkWriteStamp then
        Result.Line:=Result.Line+MainName+' holds a different build of the same version; ';
      Result.Line:=Result.Line+'archived to '+Final+' ('+GroupThousands(Result.SizeBefore)+' -> '+
        GroupThousands(Result.SizeAfter)+' bytes, '+PercentText(Result.SizeAfter,Result.SizeBefore)+')';
    except
      on E : Exception do Fail(E.Message);
    end;
  finally
    if (Partial<>'') and FileExists(Partial) then SysUtils.DeleteFile(Partial);
    Data.Free;
  end;
end;

function ArchiveAll(const ClientFolder, ArchiveFolder, Note : String; Log : TStrings;
  AfterLine : TNotifyEvent) : TArchiveCounts;
var
  Infos  : TClientInfos;
  Err    : String;
  Cnt    : Integer;
  R      : TArchiveResult;
  NowUtc : TDateTime;

  procedure Emit(const Line : String);
  begin
    Log.Add(Line);
    if Assigned(AfterLine) then AfterLine(Log);
  end;

begin
  Result:=Default(TArchiveCounts);
  if not FindClients(ClientFolder,Infos,Err) then
  begin
    Emit('error: '+Err);
    Exit;
  end;
  if Trim(ArchiveFolder)='' then
  begin
    Emit('error: no archive folder');
    Exit;
  end;
  NowUtc:=UtcNow;
  for Cnt:=0 to High(Infos) do
  begin
    if not Infos[Cnt].Found then Continue;
    R:=ArchiveClient(Infos[Cnt].Name,Infos[Cnt].Path,ArchiveFolder,Note,NowUtc);
    case R.Status of
      arArchived : Inc(Result.Archived);
      arSkipped  : Inc(Result.Skipped);
      arFailed   : Inc(Result.Failed);
    end;
    Emit(R.Line);
  end;
  Emit(SummaryLine(Result));
end;

////////////////////////////////////////////////////////////////////////////////
// By name, ignoring case, the same on every machine (TStringList.Sort follows the locale).
function CompareNames(List : TStringList; Index1, Index2 : Integer) : Integer;
begin
  Result:=CompareText(List[Index1],List[Index2]);
end;

// Every .zip in the folder, sorted by name, with what its .txt says. Never raises, never writes.
function ListArchivedBuilds(const Folder : String) : TArchivedBuilds;
var
  SR    : TSearchRec;
  Dir   : String;
  Names : TStringList;
  Cnt   : Integer;
  B     : TArchivedBuild;
  Entry : String;
  Data  : TMemoryStream;
  Raw   : RawByteString;
  Keys  : TStringList;
begin
  Result:=nil;
  if (Trim(Folder)='') or not DirectoryExists(Folder) then Exit;
  Dir:=IncludeTrailingPathDelimiter(Folder);
  Names:=TStringList.Create;
  try
    if FindFirst(Dir+'*',faAnyFile,SR)=0 then
    try
      repeat
        // By the real extension: the *.zip wildcard also matches through 8.3 aliases.
        if ((SR.Attr and faDirectory)=0) and SameText(ExtractFileExt(SR.Name),'.zip') then
          Names.Add(SR.Name);
      until FindNext(SR)<>0;
    finally
      SysUtils.FindClose(SR);
    end;
    Names.CustomSort(CompareNames);
    SetLength(Result,Names.Count);
    for Cnt:=0 to Names.Count-1 do
    begin
      B:=Default(TArchivedBuild);
      B.ZipName:=Names[Cnt];
      try
        Entry:=PickEntry(Dir+B.ZipName,ChangeFileExt(B.ZipName,'')+'.txt','.txt');
        if Entry<>'' then
        begin
          Data:=TMemoryStream.Create;
          try
            ExtractEntry(Dir+B.ZipName,Entry,Data);
            SetLength(Raw,Data.Size);
            if Data.Size>0 then Move(Data.Memory^,Raw[1],Data.Size);
            SetCodePage(Raw,CP_UTF8,False);
          finally
            Data.Free;
          end;
          Keys:=ParseInfoText(String(Raw));
          try
            B.Version:=Keys.Values['version'];
            B.HasInfo:=B.Version<>'';
            if B.HasInfo then
            begin
              B.Stamp:=Copy(Keys.Values['PE stamp'],1,8);
              B.Relocatable:=Keys.Values['relocatable'];
              B.Archived:=Keys.Values['archived'];
              B.Note:=Keys.Values['note'];
            end;
          finally
            Keys.Free;
          end;
        end;
      except
        B.HasInfo:=False;   // not a zip, or a broken one: listed by name only
      end;
      if not B.HasInfo then
      begin
        B.Version:='';
        B.Stamp:='';
        B.Relocatable:='';
        B.Archived:='';
        B.Note:='';
      end;
      Result[Cnt]:=B;
    end;
  finally
    Names.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// The first folder, from Folder upwards, that holds a .git folder (or a .git file, as a git
// worktree has). '' when there is none. Folder need not exist yet.
function FindGitFolder(const Folder : String) : String;
var
  Dir, Parent : String;
begin
  Result:='';
  if Trim(Folder)='' then Exit;
  Dir:=ExcludeTrailingPathDelimiter(ExpandFileName(Folder));
  repeat
    if DirectoryExists(Dir+'\.git') or FileExists(Dir+'\.git') then Exit(Dir);
    Parent:=ExcludeTrailingPathDelimiter(ExtractFilePath(Dir));
    if (Parent='') or (Parent=Dir) then Break;
    Dir:=Parent;
  until False;
end;

initialization
  Fmt:=DefaultFormatSettings;
  Fmt.DecimalSeparator:='.';
  Fmt.ThousandSeparator:=',';
  Fmt.DateSeparator:='-';
  Fmt.TimeSeparator:=':';
end.
