unit casha256;

{
  Port addition: SHA-256 for EUOClientArchiver, through Windows CNG (bcrypt.dll). FPC 3.2.2's
  hash package has only MD5, SHA-1 and CRC, so the six CNG calls are declared here by hand.
  The output is lowercase hex, the same text as (Get-FileHash <file>).Hash.ToLower().
}

{$mode delphi}{$H+}

interface

// The SHA-256 of Len bytes at Data, as 64 lowercase hex digits. Raises an exception that names
// the CNG call when one fails.
function Sha256Hex(Data : Pointer; Len : SizeUInt) : String;
function Sha256HexStr(const S : RawByteString) : String;

implementation

uses
  SysUtils;

type
  BCRYPT_HANDLE = Pointer;
  NTSTATUS      = LongInt;

const
  BCryptDll = 'bcrypt.dll';
  Chunk     = 1 shl 20;   // BCryptHashData takes a ULONG length

function BCryptOpenAlgorithmProvider(out phAlgorithm : BCRYPT_HANDLE; pszAlgId,
  pszImplementation : PWideChar; dwFlags : Cardinal) : NTSTATUS; stdcall;
  external BCryptDll name 'BCryptOpenAlgorithmProvider';
function BCryptCreateHash(hAlgorithm : BCRYPT_HANDLE; out phHash : BCRYPT_HANDLE;
  pbHashObject : PByte; cbHashObject : Cardinal; pbSecret : PByte; cbSecret : Cardinal;
  dwFlags : Cardinal) : NTSTATUS; stdcall; external BCryptDll name 'BCryptCreateHash';
function BCryptHashData(hHash : BCRYPT_HANDLE; pbInput : PByte; cbInput : Cardinal;
  dwFlags : Cardinal) : NTSTATUS; stdcall; external BCryptDll name 'BCryptHashData';
function BCryptFinishHash(hHash : BCRYPT_HANDLE; pbOutput : PByte; cbOutput : Cardinal;
  dwFlags : Cardinal) : NTSTATUS; stdcall; external BCryptDll name 'BCryptFinishHash';
function BCryptDestroyHash(hHash : BCRYPT_HANDLE) : NTSTATUS; stdcall;
  external BCryptDll name 'BCryptDestroyHash';
function BCryptCloseAlgorithmProvider(hAlgorithm : BCRYPT_HANDLE; dwFlags : Cardinal) : NTSTATUS;
  stdcall; external BCryptDll name 'BCryptCloseAlgorithmProvider';

procedure Check(Status : NTSTATUS; const Call : String);
begin
  if Status<>0 then
    raise Exception.CreateFmt('SHA-256: %s failed (status %.8x)',[Call,Cardinal(Status)]);
end;

////////////////////////////////////////////////////////////////////////////////
function Sha256Hex(Data : Pointer; Len : SizeUInt) : String;
const
  HexDigits : array[0..15] of Char = '0123456789abcdef';
var
  Alg, Hash : BCRYPT_HANDLE;
  Digest    : array[0..31] of Byte;
  P         : PByte;
  Part      : SizeUInt;
  Cnt       : Integer;
begin
  Alg:=nil;
  Hash:=nil;
  Check(BCryptOpenAlgorithmProvider(Alg,'SHA256',nil,0),'BCryptOpenAlgorithmProvider');
  try
    // A nil hash object lets CNG allocate it (Windows 7 and later).
    Check(BCryptCreateHash(Alg,Hash,nil,0,nil,0,0),'BCryptCreateHash');
    try
      P:=Data;
      while Len>0 do
      begin
        Part:=Len;
        if Part>Chunk then Part:=Chunk;
        Check(BCryptHashData(Hash,P,Part,0),'BCryptHashData');
        Inc(P,Part);
        Dec(Len,Part);
      end;
      Check(BCryptFinishHash(Hash,@Digest[0],SizeOf(Digest),0),'BCryptFinishHash');
    finally
      BCryptDestroyHash(Hash);
    end;
  finally
    BCryptCloseAlgorithmProvider(Alg,0);
  end;
  SetLength(Result,64);
  for Cnt:=0 to 31 do
  begin
    Result[Cnt*2+1]:=HexDigits[Digest[Cnt] shr 4];
    Result[Cnt*2+2]:=HexDigits[Digest[Cnt] and 15];
  end;
end;

function Sha256HexStr(const S : RawByteString) : String;
begin
  Result:=Sha256Hex(Pointer(S),Length(S));
end;

end.
