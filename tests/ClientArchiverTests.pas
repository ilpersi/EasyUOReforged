unit ClientArchiverTests;

{
  Tests for EUOClientArchiver's logic (tools\EUOClientArchiver\caarchive.pas, casha256.pas), the
  developer tool that archives client builds before the patcher overwrites them. No real client
  is used (none is in the repository or in CI): the archiving tests copy Windows' own cmd.exe,
  which has a version resource, into a temporary folder as client.exe, and change bytes of that
  copy where a variant is needed. Everything happens under the system temp folder and is removed
  afterwards.
}

{$mode delphi}{$H+}

interface

uses
  Windows, Classes, SysUtils, DateUtils, fpcunit, testregistry, zipper, caarchive, casha256;

type
  TClientArchiverTests = class(TTestCase)
  private
    Dir     : String;   // the test's own temp folder
    Clients : String;   // Dir\clients
    Arch    : String;   // Dir\archive (not created up front)
    Log     : TStringList;
    function  Src : String;
    procedure Put(const Path : String; const Bytes : RawByteString);
    function  Load(const Path : String) : RawByteString;
    function  Hash(const Path : String) : String;
    procedure CopyCmd(const Dest : String);
    procedure FlipByte(const Path : String; Offset : Int64);
    function  FirstSectionOffset(const Path : String) : Int64;
    function  Archive(const Note : String = '') : TArchiveCounts;
    function  VersionOf(const Path : String) : String;
    function  StampOf(const Path : String) : String;
    function  EntryText(const Zip, Entry : String) : String;
    function  FilesIn(const Folder : String) : String;
    function  Snapshot(const Folder : String) : String;
    function  MakePe(Stamp : Cardinal; DllChars : Word; OptSize : Word = $E0) : RawByteString;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestFindNoneInEmptyFolder;
    procedure TestFindClientOnly;
    procedure TestFindBoth;
    procedure TestFindIsCaseInsensitive;
    procedure TestFindIgnoresOtherClients;
    procedure TestFindMissingFolder;
    procedure TestVersionFormat;
    procedure TestPeReaderStampAndRelocatable;
    procedure TestPeReaderRejectsNonPe;
    procedure TestSha256Vectors;
    procedure TestTextFormatters;
    procedure TestDescribeClient;
    procedure TestInfoTextAndParse;
    procedure TestFindGitFolder;
    procedure TestNoVersionResourceWritesNothing;
    procedure TestRoundTrip;
    procedure TestSecondRunSkips;
    procedure TestSameVersionDifferentBytes;
    procedure TestArchivedStatus;
    procedure TestNote;
    procedure TestListArchivedBuilds;
  end;

implementation

const
  CRLF = #13#10;

////////////////////////////////////////////////////////////////////////////////
procedure RemoveTree(const Path : String);
var
  SR : TSearchRec;
begin
  if FindFirst(Path+PathDelim+'*',faAnyFile,SR)=0 then
  begin
    repeat
      if (SR.Name='.') or (SR.Name='..') then Continue;
      if (SR.Attr and faDirectory)<>0 then RemoveTree(Path+PathDelim+SR.Name)
      else SysUtils.DeleteFile(Path+PathDelim+SR.Name);
    until FindNext(SR)<>0;
    SysUtils.FindClose(SR);
  end;
  RemoveDir(Path);
end;

// The last-write time at full precision.
function WriteTime(const Path : String) : Int64;
var
  A : TWin32FileAttributeData;
begin
  Result:=-1;
  if GetFileAttributesExW(PWideChar(UnicodeString(Path)),GetFileExInfoStandard,@A) then
    Result:=(Int64(A.ftLastWriteTime.dwHighDateTime) shl 32) or A.ftLastWriteTime.dwLowDateTime;
end;

procedure TClientArchiverTests.SetUp;
begin
  Dir:=IncludeTrailingPathDelimiter(GetTempDir)+'euoclientarchiver-'+IntToStr(GetProcessID);
  RemoveTree(Dir);
  Clients:=Dir+PathDelim+'clients';
  Arch:=Dir+PathDelim+'archive';
  ForceDirectories(Clients);
  Log:=TStringList.Create;
end;

procedure TClientArchiverTests.TearDown;
begin
  Log.Free;
  RemoveTree(Dir);
end;

function TClientArchiverTests.Src : String;
begin
  Result:=Clients+PathDelim+'client.exe';
end;

procedure TClientArchiverTests.Put(const Path : String; const Bytes : RawByteString);
var
  FS : TFileStream;
begin
  FS:=TFileStream.Create(Path,fmCreate);
  try
    if Bytes<>'' then FS.WriteBuffer(Bytes[1],Length(Bytes));
  finally
    FS.Free;
  end;
end;

function TClientArchiverTests.Load(const Path : String) : RawByteString;
var
  FS : TFileStream;
begin
  FS:=TFileStream.Create(Path,fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result,FS.Size);
    if FS.Size>0 then FS.ReadBuffer(Result[1],FS.Size);
  finally
    FS.Free;
  end;
end;

function TClientArchiverTests.Hash(const Path : String) : String;
begin
  Result:=Sha256HexStr(Load(Path));
end;

// Windows' cmd.exe has a version resource: the stand-in for a client. Copied at run time, never
// checked in. CopyFileW keeps its last-write time.
procedure TClientArchiverTests.CopyCmd(const Dest : String);
var
  Cmd : UnicodeString;
begin
  Cmd:=UnicodeString(GetEnvironmentVariable('SystemRoot'))+'\System32\cmd.exe';
  AssertTrue('cmd.exe copied',CopyFileW(PWideChar(Cmd),PWideChar(UnicodeString(Dest)),False));
end;

procedure TClientArchiverTests.FlipByte(const Path : String; Offset : Int64);
var
  FS : TFileStream;
  B  : Byte;
begin
  FS:=TFileStream.Create(Path,fmOpenReadWrite);
  try
    FS.Position:=Offset;
    FS.ReadBuffer(B,1);
    B:=B xor $FF;
    FS.Position:=Offset;
    FS.WriteBuffer(B,1);
  finally
    FS.Free;
  end;
end;

// SizeOfHeaders: the first byte past the headers, the start of the first section's data. A byte
// changed there changes neither the PE stamp nor the version resource.
function TClientArchiverTests.FirstSectionOffset(const Path : String) : Int64;
var
  B  : RawByteString;
  PE : Cardinal;
begin
  B:=Load(Path);
  PE:=PCardinal(@B[$3C+1])^;
  Result:=PCardinal(@B[PE+$54+1])^;
end;

function TClientArchiverTests.Archive(const Note : String) : TArchiveCounts;
begin
  Log.Clear;
  Result:=ArchiveAll(Clients,Arch,Note,Log);
end;

function TClientArchiverTests.VersionOf(const Path : String) : String;
begin
  AssertTrue('version resource of '+Path,ReadFileVersion(Path,Result));
end;

function TClientArchiverTests.StampOf(const Path : String) : String;
var
  B : RawByteString;
begin
  B:=Load(Path);
  Result:=StampHex(ReadPeInfo(Pointer(B),Length(B)).Stamp);
end;

function TClientArchiverTests.EntryText(const Zip, Entry : String) : String;
var
  M : TMemoryStream;
begin
  M:=TMemoryStream.Create;
  try
    ExtractEntry(Zip,Entry,M);
    SetLength(Result,M.Size);
    if M.Size>0 then Move(M.Memory^,Result[1],M.Size);
  finally
    M.Free;
  end;
end;

// The file names in a folder, sorted, comma separated.
function TClientArchiverTests.FilesIn(const Folder : String) : String;
var
  SR : TSearchRec;
  L  : TStringList;
begin
  L:=TStringList.Create;
  try
    if FindFirst(IncludeTrailingPathDelimiter(Folder)+'*',faAnyFile,SR)=0 then
    begin
      repeat
        if (SR.Attr and faDirectory)=0 then L.Add(SR.Name);
      until FindNext(SR)<>0;
      SysUtils.FindClose(SR);
    end;
    L.Sort;
    Result:=L.CommaText;
  finally
    L.Free;
  end;
end;

// Every file of a folder with its time and hash: equal snapshots, nothing changed.
function TClientArchiverTests.Snapshot(const Folder : String) : String;
var
  L   : TStringList;
  Cnt : Integer;
  P   : String;
begin
  L:=TStringList.Create;
  try
    L.CommaText:=FilesIn(Folder);
    Result:='';
    for Cnt:=0 to L.Count-1 do
    begin
      P:=IncludeTrailingPathDelimiter(Folder)+L[Cnt];
      Result:=Result+L[Cnt]+' '+IntToStr(WriteTime(P))+' '+Hash(P)+LineEnding;
    end;
  finally
    L.Free;
  end;
end;

// A minimal PE header: e_lfanew $80, stamp at $88, SizeOfOptionalHeader at $94,
// DllCharacteristics at $DE.
function TClientArchiverTests.MakePe(Stamp : Cardinal; DllChars : Word; OptSize : Word) : RawByteString;
begin
  Result:=StringOfChar(#0,$200);
  Result[1]:='M';
  Result[2]:='Z';
  PCardinal(@Result[$3C+1])^:=$80;
  PCardinal(@Result[$80+1])^:=$00004550;
  PWord(@Result[$84+1])^:=$014C;
  PCardinal(@Result[$88+1])^:=Stamp;
  PWord(@Result[$94+1])^:=OptSize;
  PWord(@Result[$98+1])^:=$010B;
  PWord(@Result[$DE+1])^:=DllChars;
end;

////////////////////////////////////////////////////////////////////////////////
// Finding clients
////////////////////////////////////////////////////////////////////////////////
procedure TClientArchiverTests.TestFindNoneInEmptyFolder;
var
  Infos : TClientInfos;
  Err   : String;
begin
  AssertFalse(FindClients(Clients,Infos,Err));
  AssertEquals('No client.exe or client_beta.exe in this folder',Err);
end;

procedure TClientArchiverTests.TestFindClientOnly;
var
  Infos : TClientInfos;
  Err   : String;
begin
  Put(Src,'not a program');
  AssertTrue(FindClients(Clients,Infos,Err));
  AssertEquals(2,Length(Infos));
  AssertEquals('client.exe',Infos[0].Name);
  AssertTrue(Infos[0].Found);
  AssertEquals(Src,Infos[0].Path);
  AssertEquals('client_beta.exe',Infos[1].Name);
  AssertFalse(Infos[1].Found);
end;

procedure TClientArchiverTests.TestFindBoth;
var
  Infos : TClientInfos;
  Err   : String;
begin
  CopyCmd(Src);
  CopyCmd(Clients+PathDelim+'client_beta.exe');
  AssertTrue(FindClients(Clients,Infos,Err));
  AssertTrue(Infos[0].Found and Infos[1].Found);
  AssertTrue('client.exe can be archived',CanArchive(Infos[0]));
  AssertTrue('client_beta.exe can be archived',CanArchive(Infos[1]));
  AssertEquals(VersionOf(Src),Infos[0].Version);
  AssertEquals(Hash(Src),Infos[0].Sha256);
end;

procedure TClientArchiverTests.TestFindIsCaseInsensitive;
var
  Infos : TClientInfos;
  Err   : String;
begin
  Put(Clients+PathDelim+'CLIENT.EXE','x');
  AssertTrue(FindClients(Clients,Infos,Err));
  AssertTrue(Infos[0].Found);
  AssertEquals('the name as it is on disk','CLIENT.EXE',ExtractFileName(Infos[0].Path));
end;

procedure TClientArchiverTests.TestFindIgnoresOtherClients;
var
  Infos : TClientInfos;
  Err   : String;
begin
  Put(Clients+PathDelim+'client_tc.exe','x');
  Put(Clients+PathDelim+'client_noenc.exe','x');
  Put(Clients+PathDelim+'client_7.0.4.3.exe','x');
  AssertFalse('only other clients',FindClients(Clients,Infos,Err));
  Put(Clients+PathDelim+'client_beta.exe','x');
  AssertTrue(FindClients(Clients,Infos,Err));
  AssertFalse(Infos[0].Found);
  AssertTrue(Infos[1].Found);
  AssertEquals('client_beta.exe',ExtractFileName(Infos[1].Path));
end;

procedure TClientArchiverTests.TestFindMissingFolder;
var
  Infos : TClientInfos;
  Err   : String;
begin
  AssertFalse(FindClients(Dir+PathDelim+'nowhere',Infos,Err));
  AssertEquals('The folder does not exist',Err);
  AssertFalse(FindClients('',Infos,Err));
end;

////////////////////////////////////////////////////////////////////////////////
// Identifying
////////////////////////////////////////////////////////////////////////////////
procedure TClientArchiverTests.TestVersionFormat;
begin
  AssertEquals('7.0.117.33',FormatFileVersion($00070000,$00750021));
  AssertEquals('7.0.117.1',FormatFileVersion($00070000,$00750001));
  AssertEquals('65535.0.0.65535',FormatFileVersion($FFFF0000,$0000FFFF));
end;

procedure TClientArchiverTests.TestPeReaderStampAndRelocatable;
var
  B  : RawByteString;
  PE : TPeInfo;
begin
  B:=MakePe($6AD994F1,$0000);
  PE:=ReadPeInfo(Pointer(B),Length(B));
  AssertTrue(PE.Error,PE.Valid);
  AssertEquals('6AD994F1',StampHex(PE.Stamp));
  AssertFalse('fixed base',PE.Relocatable);

  B:=MakePe($6AD6CEB3,$8140);   // DYNAMIC_BASE among other bits
  PE:=ReadPeInfo(Pointer(B),Length(B));
  AssertTrue(PE.Valid);
  AssertEquals('6AD6CEB3',StampHex(PE.Stamp));
  AssertTrue('relocatable',PE.Relocatable);

  B:=MakePe(1,$8100);           // other bits, not $40
  AssertFalse(ReadPeInfo(Pointer(B),Length(B)).Relocatable);
end;

procedure TClientArchiverTests.TestPeReaderRejectsNonPe;

  procedure Rejects(const What, Why : String; const B : RawByteString);
  var
    PE : TPeInfo;
  begin
    PE:=ReadPeInfo(Pointer(B),Length(B));
    AssertFalse(What,PE.Valid);
    AssertEquals(What,Why,PE.Error);
  end;

var
  B : RawByteString;
begin
  Rejects('empty','no MZ header','');
  Rejects('text','no MZ header','This is a text file, not a program at all. '+StringOfChar('x',100));
  Rejects('short','no MZ header','MZ'+StringOfChar(#0,20));

  B:=MakePe(1,0);
  PCardinal(@B[$3C+1])^:=$1F0;  // the PE header would run past the end
  Rejects('e_lfanew past the end','bad e_lfanew',B);
  PCardinal(@B[$3C+1])^:=$FFFFFFF0;
  Rejects('huge e_lfanew','bad e_lfanew',B);

  B:=MakePe(1,0);
  B[$81]:='N';
  B[$82]:='E';
  Rejects('NE header','no PE signature',B);

  Rejects('short optional header','optional header too short',MakePe(1,0,16));
end;

procedure TClientArchiverTests.TestSha256Vectors;
begin
  AssertEquals('e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',Sha256HexStr(''));
  AssertEquals('ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',Sha256HexStr('abc'));
  AssertEquals('248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    Sha256HexStr('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'));
end;

////////////////////////////////////////////////////////////////////////////////
// Text
////////////////////////////////////////////////////////////////////////////////
procedure TClientArchiverTests.TestTextFormatters;
var
  Counts : TArchiveCounts;
begin
  Counts:=Default(TArchiveCounts);
  Counts.Skipped:=1;
  Counts.Failed:=2;
  AssertEquals('0 archived, 1 skipped, 2 failed',SummaryLine(Counts));
  AssertEquals('6AD994F1 (2026-10-22 04:45:37 UTC)',StampLine($6AD994F1));
  AssertEquals('0000002A',StampHex(42));
  AssertEquals('2026-11-15 10:12:03 UTC',UtcText(EncodeDateTime(2026,11,15,10,12,3,0)));
  AssertEquals('0',GroupThousands(0));
  AssertEquals('999',GroupThousands(999));
  AssertEquals('1,000',GroupThousands(1000));
  AssertEquals('3,616,768',GroupThousands(3616768));
  AssertEquals('4,492,288',GroupThousands(4492288));
  AssertEquals('1,234,567,890',GroupThousands(1234567890));
  AssertEquals('kept for tests',CleanNote('  kept'#9'for tests'#13#10));
  AssertEquals('',CleanNote(#13#10' '));
end;

function SampleInfo : TClientInfo;
begin
  Result:=Default(TClientInfo);
  Result.Name:='client.exe';
  Result.Found:=True;
  Result.Path:='D:\Program Files (x86)\Electronic Arts\Ultima Online Classic\client.exe';
  Result.Version:='7.0.117.33';
  Result.Pe.Valid:=True;
  Result.Pe.Stamp:=$6AD994F1;
  Result.Pe.Relocatable:=False;
  Result.Size:=3616768;
  Result.Sha256:='6eefcdc345fcfd54da00d63045b5b753d51ecd8b90e30c414fcf14a6f5929b80';
  Result.ModifiedUtc:=EncodeDateTime(2026,10,22,5,47,46,0);
end;

procedure TClientArchiverTests.TestDescribeClient;
var
  Info : TClientInfo;
begin
  Info:=SampleInfo;
  AssertEquals('client.exe       7.0.117.33  stamp 6AD994F1  3,616,768 bytes  archived',
    DescribeClient(Info,StatusArchived));
  AssertEquals('client.exe       7.0.117.33  stamp 6AD994F1  3,616,768 bytes  not archived yet',
    DescribeClient(Info,StatusNotArchived));
  AssertEquals('no status without an archive folder',
    'client.exe       7.0.117.33  stamp 6AD994F1  3,616,768 bytes',DescribeClient(Info,''));
  Info.Error:='no version resource, not archived';
  AssertEquals('client.exe       no version resource, not archived',DescribeClient(Info,''));
  Info:=Default(TClientInfo);
  Info.Name:='client_beta.exe';
  AssertEquals('client_beta.exe  not found',DescribeClient(Info,''));
end;

procedure TClientArchiverTests.TestInfoTextAndParse;
const
  Expected =
    'original name    client.exe'+CRLF+
    'original folder  D:\Program Files (x86)\Electronic Arts\Ultima Online Classic'+CRLF+
    'version          7.0.117.33'+CRLF+
    'PE stamp         6AD994F1 (2026-10-22 04:45:37 UTC)'+CRLF+
    'relocatable      False'+CRLF+
    'size             3616768'+CRLF+
    'sha256           6eefcdc345fcfd54da00d63045b5b753d51ecd8b90e30c414fcf14a6f5929b80'+CRLF+
    'last modified    2026-10-22 05:47:46 UTC'+CRLF+
    'archived         2026-11-15 10:12:03 UTC'+CRLF;
var
  T    : String;
  Keys : TStringList;
begin
  T:=InfoText(SampleInfo,'',EncodeDateTime(2026,11,15,10,12,3,0));
  AssertEquals('no note line for an empty note',Expected,T);
  T:=InfoText(SampleInfo,'  patched from the launcher ',EncodeDateTime(2026,11,15,10,12,3,0));
  AssertEquals(Expected+'note             patched from the launcher'+CRLF,T);

  Keys:=ParseInfoText(T);
  try
    AssertEquals('client.exe',Keys.Values['original name']);
    AssertEquals('D:\Program Files (x86)\Electronic Arts\Ultima Online Classic',Keys.Values['original folder']);
    AssertEquals('7.0.117.33',Keys.Values['version']);
    AssertEquals('6AD994F1 (2026-10-22 04:45:37 UTC)',Keys.Values['PE stamp']);
    AssertEquals('False',Keys.Values['relocatable']);
    AssertEquals('3616768',Keys.Values['size']);
    AssertEquals('2026-11-15 10:12:03 UTC',Keys.Values['archived']);
    AssertEquals('patched from the launcher',Keys.Values['note']);
  finally
    Keys.Free;
  end;

  // By key, not by line number: the order does not matter.
  Keys:=ParseInfoText('note             x = y'+CRLF+'version          1.2.3.4'+CRLF+'garbage'+CRLF);
  try
    AssertEquals('1.2.3.4',Keys.Values['version']);
    AssertEquals('x = y',Keys.Values['note']);
  finally
    Keys.Free;
  end;
end;

procedure TClientArchiverTests.TestFindGitFolder;
var
  Repo, Wt : String;
begin
  Repo:=Dir+PathDelim+'repo';
  ForceDirectories(Repo+PathDelim+'.git');
  ForceDirectories(Repo+PathDelim+'a'+PathDelim+'b');
  AssertEquals('the repository itself',Repo,FindGitFolder(Repo));
  AssertEquals('a folder inside it',Repo,FindGitFolder(Repo+PathDelim+'a'+PathDelim+'b'));
  AssertEquals('a folder not created yet',Repo,FindGitFolder(Repo+PathDelim+'new'+PathDelim+'folder'));

  Wt:=Dir+PathDelim+'worktree';
  ForceDirectories(Wt+PathDelim+'sub');
  Put(Wt+PathDelim+'.git','gitdir: elsewhere');
  AssertEquals('a worktree has a .git file',Wt,FindGitFolder(Wt+PathDelim+'sub'));

  ForceDirectories(Dir+PathDelim+'plain'+PathDelim+'x');
  AssertEquals('none: whatever is above the test folder',FindGitFolder(Dir),
    FindGitFolder(Dir+PathDelim+'plain'+PathDelim+'x'));
  AssertEquals('',FindGitFolder(''));
end;

////////////////////////////////////////////////////////////////////////////////
// Archiving
////////////////////////////////////////////////////////////////////////////////
procedure TClientArchiverTests.TestNoVersionResourceWritesNothing;
var
  C : TArchiveCounts;
begin
  Put(Src,'just text, named like a client');
  C:=Archive;
  AssertEquals(0,C.Archived);
  AssertEquals(0,C.Skipped);
  AssertEquals(1,C.Failed);
  AssertEquals(2,Log.Count);
  AssertEquals('client.exe: error: no version resource, not archived',Log[0]);
  AssertEquals('0 archived, 0 skipped, 1 failed',Log[1]);
  AssertFalse('not even the archive folder',DirectoryExists(Arch));
end;

procedure TClientArchiverTests.TestRoundTrip;
var
  V, Base, Zip, SrcHash, Txt : String;
  SrcTime, SrcSize           : Int64;
  C                          : TArchiveCounts;
  Names                      : TStringList;
  M                          : TMemoryStream;
  UZ                         : TUnZipper;
  Got                        : RawByteString;
  Diff                       : Double;
  SrcLocal                   : TDateTime;
begin
  CopyCmd(Src);
  V:=VersionOf(Src);
  Base:='client_'+V;
  SrcHash:=Hash(Src);
  SrcTime:=WriteTime(Src);
  SrcSize:=Length(Load(Src));

  C:=Archive;
  AssertEquals(Log.Text,1,C.Archived);
  AssertEquals(0,C.Skipped);
  AssertEquals(0,C.Failed);
  Zip:=Arch+PathDelim+Base+'.zip';
  AssertTrue('archive named after the version',FileExists(Zip));
  AssertTrue(Log[0],Pos('client.exe: archived to '+Zip+' (',Log[0])=1);
  AssertEquals('1 archived, 0 skipped, 0 failed',Log[1]);
  AssertEquals('nothing else in the archive folder: no .partial, no .tmp',Base+'.zip',FilesIn(Arch));

  Names:=TStringList.Create;
  M:=TMemoryStream.Create;
  try
    ZipEntryNames(Zip,Names);
    AssertEquals('exactly the exe and the .txt',Base+'.exe,'+Base+'.txt',Names.CommaText);
    ExtractEntry(Zip,Base+'.exe',M);
    SetLength(Got,M.Size);
    Move(M.Memory^,Got[1],M.Size);
    AssertTrue('the extracted bytes equal the source',Got=Load(Src));
  finally
    M.Free;
    Names.Free;
  end;

  // The entry date is the source's last-write time (local, as ZIP keeps it), at ZIP's 2-second
  // precision. Windows' DOS time, which zipper's own FindFirst path uses too, rounds an odd
  // second up, so the entry can be up to 2 s after the exact time as well as before it.
  SrcLocal:=UniversalTimeToLocal(IdentifyClient('client.exe',Src).ModifiedUtc);
  UZ:=TUnZipper.Create;
  try
    UZ.FileName:=Zip;
    UZ.Examine;
    Diff:=(SrcLocal-UZ.Entries[0].DateTime)*SecsPerDay;
    AssertTrue(Format('entry date %s, source %s',[DateTimeToStr(UZ.Entries[0].DateTime),
      DateTimeToStr(SrcLocal)]),Abs(Diff)<2);
  finally
    UZ.Free;
  end;

  Txt:=EntryText(Zip,Base+'.txt');
  AssertTrue(Txt,Pos('original name    client.exe'+CRLF,Txt)=1);
  AssertTrue(Txt,Pos('version          '+V+CRLF,Txt)>0);
  AssertTrue(Txt,Pos('PE stamp         '+StampOf(Src)+' (',Txt)>0);
  AssertTrue(Txt,Pos('size             '+IntToStr(SrcSize)+CRLF,Txt)>0);
  AssertTrue(Txt,Pos('sha256           '+SrcHash+CRLF,Txt)>0);
  AssertEquals('no note line',0,Pos('note',Txt));

  AssertEquals('source bytes unchanged',SrcHash,Hash(Src));
  AssertEquals('source time unchanged',SrcTime,WriteTime(Src));
  AssertEquals('source size unchanged',SrcSize,Length(Load(Src)));
end;

procedure TClientArchiverTests.TestSecondRunSkips;
var
  Zip, Before : String;
  C           : TArchiveCounts;
begin
  CopyCmd(Src);
  AssertEquals(1,Archive.Archived);
  Zip:=Arch+PathDelim+'client_'+VersionOf(Src)+'.zip';
  Before:=Snapshot(Arch);

  C:=Archive;
  AssertEquals(0,C.Archived);
  AssertEquals(1,C.Skipped);
  AssertEquals(0,C.Failed);
  AssertEquals('client.exe: already archived in '+Zip,Log[0]);
  AssertEquals('0 archived, 1 skipped, 0 failed',Log[1]);
  AssertEquals('the archive is untouched',Before,Snapshot(Arch));
end;

procedure TClientArchiverTests.TestSameVersionDifferentBytes;
var
  V, Stamp, Base, Main, Second, MainSnap, Both : String;
  Off                                         : Int64;
  C                                           : TArchiveCounts;
  Names                                       : TStringList;
  M                                           : TMemoryStream;
  Got                                         : RawByteString;
begin
  CopyCmd(Src);
  AssertEquals(1,Archive.Archived);
  V:=VersionOf(Src);
  Stamp:=StampOf(Src);
  Base:='client_'+V;
  Main:=Arch+PathDelim+Base+'.zip';
  MainSnap:=Snapshot(Arch);

  Off:=FirstSectionOffset(Src)+16;
  FlipByte(Src,Off);
  AssertEquals('same version',V,VersionOf(Src));
  AssertEquals('same stamp',Stamp,StampOf(Src));

  C:=Archive;
  AssertEquals(Log.Text,1,C.Archived);
  Second:=Arch+PathDelim+Base+'_'+Stamp+'.zip';
  AssertTrue('the stamp archive',FileExists(Second));
  AssertTrue(Log[0],Pos('client.exe: '+Base+'.zip holds a different build of the same version; '+
    'archived to '+Second,Log[0])=1);
  Names:=TStringList.Create;
  M:=TMemoryStream.Create;
  try
    ZipEntryNames(Second,Names);
    AssertEquals(Base+'_'+Stamp+'.exe,'+Base+'_'+Stamp+'.txt',Names.CommaText);
    ExtractEntry(Second,Base+'_'+Stamp+'.exe',M);
    SetLength(Got,M.Size);
    Move(M.Memory^,Got[1],M.Size);
    AssertTrue('the variant is in it',Got=Load(Src));
  finally
    M.Free;
    Names.Free;
  end;
  AssertTrue('the first archive is untouched',Pos(MainSnap,Snapshot(Arch))=1);

  // A third build with the same version and stamp: an error, and nothing changes.
  Both:=Snapshot(Arch);
  FlipByte(Src,Off+1);
  C:=Archive;
  AssertEquals(0,C.Archived);
  AssertEquals(0,C.Skipped);
  AssertEquals(1,C.Failed);
  AssertTrue(Log[0],Pos('client.exe: error: '+Base+'.zip and '+Base+'_'+Stamp+'.zip both hold a '+
    'different build',Log[0])=1);
  AssertTrue(Log[0],Pos('please look at them, nothing was overwritten',Log[0])>0);
  AssertEquals('nothing overwritten',Both,Snapshot(Arch));
  AssertEquals(ExtractFileName(Main)+','+ExtractFileName(Second),FilesIn(Arch));
end;

procedure TClientArchiverTests.TestArchivedStatus;
begin
  CopyCmd(Src);
  AssertEquals('no archive folder: no status','',ArchivedStatus(IdentifyClient('client.exe',Src),''));
  AssertEquals('before the first run',StatusNotArchived,ArchivedStatus(IdentifyClient('client.exe',Src),Arch));
  Archive;
  AssertEquals('after it',StatusArchived,ArchivedStatus(IdentifyClient('client.exe',Src),Arch));

  FlipByte(Src,FirstSectionOffset(Src)+16);
  AssertEquals('the same-name archive holds other bytes',StatusNotArchived,
    ArchivedStatus(IdentifyClient('client.exe',Src),Arch));
  AssertEquals(1,Archive.Archived);
  AssertEquals('only the stamp archive matches',StatusArchived,
    ArchivedStatus(IdentifyClient('client.exe',Src),Arch));

  Put(Clients+PathDelim+'client_beta.exe','text');
  AssertEquals('cannot be archived: no status','',
    ArchivedStatus(IdentifyClient('client_beta.exe',Clients+PathDelim+'client_beta.exe'),Arch));
end;

procedure TClientArchiverTests.TestNote;
var
  Base, Txt : String;
begin
  CopyCmd(Src);
  Base:='client_'+VersionOf(Src);
  AssertEquals(1,Archive(' kept'#9'for tests'#13#10).Archived);
  Txt:=EntryText(Arch+PathDelim+Base+'.zip',Base+'.txt');
  AssertTrue(Txt,Pos(CRLF+'note             kept for tests'+CRLF,Txt)>0);
end;

procedure TClientArchiverTests.TestListArchivedBuilds;
var
  V, Stamp, Base, Before, T0, T1, Reloc : String;
  L                                     : TArchivedBuilds;
  Z                                     : TZipper;
  S                                     : TStringStream;
  B                                     : RawByteString;
begin
  AssertEquals('a folder that does not exist',0,Length(ListArchivedBuilds(Arch)));
  CopyCmd(Src);
  V:=VersionOf(Src);
  Stamp:=StampOf(Src);
  Base:='client_'+V;
  B:=Load(Src);
  if ReadPeInfo(Pointer(B),Length(B)).Relocatable then Reloc:='True' else Reloc:='False';

  T0:=UtcText(UtcNow);
  AssertEquals(1,Archive('first one').Archived);
  FlipByte(Src,FirstSectionOffset(Src)+16);
  AssertEquals(1,Archive.Archived);
  T1:=UtcText(UtcNow);

  // A zip made by hand, with no .txt, and a text file that only looks like a zip.
  Z:=TZipper.Create;
  S:=TStringStream.Create('some bytes');
  try
    Z.FileName:=Arch+PathDelim+'handmade.zip';
    Z.Entries.AddFileEntry(S,'readme.bin');
    Z.ZipAllFiles;
  finally
    Z.Free;
    S.Free;
  end;
  Put(Arch+PathDelim+'junk.zip','this is not a zip');
  Put(Arch+PathDelim+'notes.txt','not listed');
  Before:=Snapshot(Arch);

  L:=ListArchivedBuilds(Arch);
  AssertEquals('every .zip, nothing else',4,Length(L));
  AssertEquals('sorted by name',Base+'.zip',L[0].ZipName);
  AssertEquals(Base+'_'+Stamp+'.zip',L[1].ZipName);
  AssertEquals('handmade.zip',L[2].ZipName);
  AssertEquals('junk.zip',L[3].ZipName);

  AssertTrue(L[0].HasInfo);
  AssertEquals(V,L[0].Version);
  AssertEquals(Stamp,L[0].Stamp);
  AssertEquals(Reloc,L[0].Relocatable);
  AssertEquals('first one',L[0].Note);
  AssertTrue(L[0].Archived+' >= '+T0,L[0].Archived>=T0);
  AssertTrue(L[0].Archived+' <= '+T1,L[0].Archived<=T1);

  AssertTrue(L[1].HasInfo);
  AssertEquals(V,L[1].Version);
  AssertEquals(Stamp,L[1].Stamp);
  AssertEquals('no note',L[1].Note,'');

  AssertFalse('a zip without a .txt: name only',L[2].HasInfo);
  AssertEquals('',L[2].Version);
  AssertFalse('not a zip: name only',L[3].HasInfo);
  AssertEquals('',L[3].Stamp);

  AssertEquals('reading changed nothing',Before,Snapshot(Arch));
end;

initialization
  RegisterTest(TClientArchiverTests);

end.
