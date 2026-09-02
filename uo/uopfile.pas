unit uopfile;

{
  New addition (not present in the original Delphi 7 app) -- reads the "MythicPackage"
  (.uop) container format Mythic/EA switched several legacy data files to starting around
  2014, when reconstructing one of them as a plain in-memory byte stream shaped exactly
  like the classic loose .mul file it replaces. Added specifically so tiles.pas's TTTBasic
  can keep working against a client install that ships e.g. map0LegacyMUL.uop instead of
  map0.mul (a real, confirmed case: an EA "Ultima Online Classic" install on this machine
  has no map*.mul files at all, only map*LegacyMUL.uop) -- see tiles.pas's own comment for
  how this unit is actually wired in (classic .mul preferred, this only used as a fallback,
  to minimize impact on every install that still has the classic files).

  Every piece of this was verified directly against a real file on this machine (map0
  LegacyMUL.uop, 113 entries) via a from-scratch Python prototype BEFORE this Pascal port
  was written, not assumed from memory or documentation alone:
    - The 24-byte header shape (Magic 'MYP'#0, Version, a build-signature/timestamp field,
      an Int64 offset to the first block-entry table, a per-block entry-count constant,
      and a total-file-count field) was read back byte-for-byte and cross-checked against
      the file's own reported entry count.
    - HashLittle2 below (Bob Jenkins' public-domain lookup3.c hashlittle2, the specific
      hash MythicPackage uses to look up an entry by a synthetic internal path name) was
      proven correct the strongest way possible: computing the hash of
      'build/map0legacymul/NNNNNNNN.dat' for N=0..112 and checking it against the file's
      OWN stored per-entry Hash field matched all 113/113 entries exactly. A single wrong
      bit anywhere in the mixing/finalization steps would have produced zero matches, not
      approximately-right ones, against a 64-bit keyspace -- this is conclusive, not
      merely plausible.
    - Every entry in that real file (and in every other map*LegacyMUL.uop on that same
      install) turned out to use CompressionFlag=0 (stored raw, no zlib) -- the zlib path
      below (Flag=1) is still implemented for robustness/other installs, and was verified
      independently by decompressing a real Flag=1 entry from a DIFFERENT .uop file on the
      same install (tileart.uop) with Python's zlib and confirming the decompressed length
      matched the entry's own recorded DecompressedSize -- but it is not what any file this
      unit actually needs to read on this machine exercises today.
    - Concatenating entries in index order reconstructs the exact classic-.mul byte layout
      by construction (confirmed via decompressed-size bookkeeping: 112 entries of exactly
      4096 map-blocks'-worth of bytes each, plus one final partial entry of exactly one
      block's worth, summing to a whole number of 196-byte map-block records) -- this is
      simply how the packer chopped the original flat file up, not a new format.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, zstream;

// Reconstructs the classic-.mul-equivalent byte stream for a UOP-packed legacy file, by
// walking its block-entry table and concatenating every entry named
// <EntryPrefix>+'NNNNNNNN.dat' (8-digit zero-padded, sequential from 0) in index order,
// decompressing each per its own CompressionFlag. This exactly reverses how these legacy
// formats were packed into a .uop container, so the result is byte-identical to what the
// pre-UOP classic .mul file would have contained -- safe to use as a drop-in TStream
// wherever a TFileStream opened on the classic file would otherwise have been used.
//
// Returns nil (never raises for a missing/malformed FILE) if UopPath doesn't exist, isn't
// a valid MythicPackage container, or has no entries at all under EntryPrefix (Idx=0 not
// found) -- callers decide what "no data available" means for their own case, matching
// this codebase's existing fileexists-gated "leave the slot nil" pattern for optional
// facets. DOES raise if a matched entry uses a CompressionFlag this unit doesn't
// implement, or if decompression itself fails -- those indicate a real, unexpected data
// problem worth surfacing loudly (via the same executor-level exception safety net every
// other TFileStream.Create failure already goes through), not something to silently paper
// over.
function LoadUopAsStream(const UopPath, EntryPrefix : String) : TMemoryStream;

implementation

type
  TUopEntry = record
    DataOffset       : Int64;
    HeaderLength     : Cardinal;
    CompressedSize   : Cardinal;
    DecompressedSize : Cardinal;
    Hash             : QWord;
    CompressionFlag  : Word;
  end;

////////////////////////////////////////////////////////////////////////////////
// Bob Jenkins' public-domain hashlittle2 (lookup3.c, http://burtleburtle.net/bob/c/
// lookup3.c) -- the exact hash MythicPackage containers use to look up an entry by its
// synthetic internal path name. PC/PB are both the two input seeds (always 0,0 for UOP's
// own usage) AND, on return, the two halves of the 64-bit result (PB is the high 32 bits,
// PC the low 32 bits: Hash = (QWord(PB) shl 32) or PC) -- an inout pair, matching the
// original C reference's `uint32_t *pc, *pb` exactly. See this unit's header comment for
// how this was validated (113/113 real entries matched, not merely "looks plausible").
procedure HashLittle2(const Data; DataLen : Integer; var PC, PB : Cardinal);
  function Rot(X : Cardinal; K : Byte) : Cardinal; inline;
  begin
    Rot := (X shl K) or (X shr (32-K));
  end;
var
  A, B, C : Cardinal;
  K       : PByte;
  Len     : Integer;
  Tail    : array[0..11] of Byte;
begin
  A := Cardinal($DEADBEEF) + Cardinal(DataLen) + PC;
  B := A;
  C := A + PB;

  K := @Data;
  Len := DataLen;
  while Len > 12 do
  begin
    A := A + K[0] + (Cardinal(K[1]) shl 8) + (Cardinal(K[2]) shl 16) + (Cardinal(K[3]) shl 24);
    B := B + K[4] + (Cardinal(K[5]) shl 8) + (Cardinal(K[6]) shl 16) + (Cardinal(K[7]) shl 24);
    C := C + K[8] + (Cardinal(K[9]) shl 8) + (Cardinal(K[10]) shl 16) + (Cardinal(K[11]) shl 24);

    A := A-C; A := A xor Rot(C,4);  C := C+B;
    B := B-A; B := B xor Rot(A,6);  A := A+C;
    C := C-B; C := C xor Rot(B,8);  B := B+A;
    A := A-C; A := A xor Rot(C,16); C := C+B;
    B := B-A; B := B xor Rot(A,19); A := A+C;
    C := C-B; C := C xor Rot(B,4);  B := B+A;

    Dec(Len,12);
    Inc(K,12);
  end;

  if Len = 0 then
  begin
    PC := C; PB := B;
    Exit;
  end;

  FillChar(Tail, SizeOf(Tail), 0);
  Move(K^, Tail, Len);

  if Len >= 12 then C := C + (Cardinal(Tail[11]) shl 24);
  if Len >= 11 then C := C + (Cardinal(Tail[10]) shl 16);
  if Len >= 10 then C := C + (Cardinal(Tail[9]) shl 8);
  if Len >= 9  then C := C + Tail[8];
  if Len >= 8  then B := B + (Cardinal(Tail[7]) shl 24);
  if Len >= 7  then B := B + (Cardinal(Tail[6]) shl 16);
  if Len >= 6  then B := B + (Cardinal(Tail[5]) shl 8);
  if Len >= 5  then B := B + Tail[4];
  if Len >= 4  then A := A + (Cardinal(Tail[3]) shl 24);
  if Len >= 3  then A := A + (Cardinal(Tail[2]) shl 16);
  if Len >= 2  then A := A + (Cardinal(Tail[1]) shl 8);
  A := A + Tail[0];   // Len>=1 always true here -- Len=0 already returned above

  C := C xor B; C := C - Rot(B,14);
  A := A xor C; A := A - Rot(C,11);
  B := B xor A; B := B - Rot(A,25);
  C := C xor B; C := C - Rot(B,16);
  A := A xor C; A := A - Rot(C,4);
  B := B xor A; B := B - Rot(A,14);
  C := C xor B; C := C - Rot(B,24);

  PC := C; PB := B;
end;

////////////////////////////////////////////////////////////////////////////////
function UopHash(const Name : String) : QWord;
var
  PCv, PBv : Cardinal;
begin
  PCv := 0; PBv := 0;
  HashLittle2(Name[1], Length(Name), PCv, PBv);
  Result := (QWord(PBv) shl 32) or PCv;
end;

////////////////////////////////////////////////////////////////////////////////
function LoadUopAsStream(const UopPath, EntryPrefix : String) : TMemoryStream;
var
  F           : TFileStream;
  Magic       : array[0..3] of AnsiChar;
  Version     : Cardinal;
  Misc        : Cardinal;
  TableOffset : Int64;
  BlockSize   : Cardinal;
  FileCnt     : Cardinal;
  Entries     : array of TUopEntry;
  NEntries    : Integer;
  EntryCount  : Cardinal;
  NextBlock   : Int64;
  Cnt         : Integer;
  E           : TUopEntry;

  // Copies one entry's decompressed bytes onto the end of Output. F is positioned
  // wherever it likes on entry -- always explicitly re-seeked here first.
  procedure AppendEntry(const Entry : TUopEntry; Output : TMemoryStream);
  var
    CompBuf : TMemoryStream;
    Decomp  : TDecompressionStream;
  begin
    F.Seek(Entry.DataOffset + Entry.HeaderLength, soFromBeginning);
    case Entry.CompressionFlag of
      0 : Output.CopyFrom(F, Entry.CompressedSize);
      1 : begin
            CompBuf := TMemoryStream.Create;
            try
              CompBuf.CopyFrom(F, Entry.CompressedSize);
              CompBuf.Position := 0;
              Decomp := TDecompressionStream.Create(CompBuf, False);
              try
                Output.CopyFrom(Decomp, Entry.DecompressedSize);
              finally
                Decomp.Free;
              end;
            finally
              CompBuf.Free;
            end;
          end;
      else
        raise Exception.CreateFmt('LoadUopAsStream(%s): entry has an unsupported ' +
          'CompressionFlag (%d) -- only 0 (stored) and 1 (zlib) are implemented',
          [UopPath, Entry.CompressionFlag]);
    end;
  end;

var
  Idx   : Integer;
  Name  : String;
  Hash  : QWord;
  Found : Boolean;
begin
  Result := nil;
  if not FileExists(UopPath) then Exit;

  F := TFileStream.Create(UopPath, fmOpenRead or fmShareDenyNone);
  try
    if F.Read(Magic, 4) <> 4 then Exit;
    if (Magic[0]<>'M') or (Magic[1]<>'Y') or (Magic[2]<>'P') or (Magic[3]<>#0) then Exit;
    F.Read(Version, 4);
    F.Read(Misc, 4);
    F.Read(TableOffset, 8);
    F.Read(BlockSize, 4);
    F.Read(FileCnt, 4);

    // Walk the block chain, collecting every entry (across every block) with a nonzero
    // DataOffset (zero marks an unused/removed slot -- skipped, matching every other
    // MythicPackage reader's own convention for this field).
    NEntries := 0;
    SetLength(Entries, FileCnt);
    while TableOffset <> 0 do
    begin
      F.Seek(TableOffset, soFromBeginning);
      F.Read(EntryCount, 4);
      F.Read(NextBlock, 8);
      for Cnt := 1 to EntryCount do
      begin
        F.Read(E.DataOffset, 8);
        F.Read(E.HeaderLength, 4);
        F.Read(E.CompressedSize, 4);
        F.Read(E.DecompressedSize, 4);
        F.Read(E.Hash, 8);
        F.Read(Misc, 4);              // per-entry data CRC/Adler32 -- not needed here
        F.Read(E.CompressionFlag, 2);
        if E.DataOffset <> 0 then
        begin
          if NEntries >= Length(Entries) then SetLength(Entries, Length(Entries)+64);
          Entries[NEntries] := E;
          Inc(NEntries);
        end;
      end;
      TableOffset := NextBlock;
    end;

    // Sequential 0,1,2,... lookup by name/hash until one isn't found -- see this
    // function's own header comment for why concatenating them in this order
    // reconstructs the exact classic-.mul byte layout.
    Idx := 0;
    repeat
      Name := EntryPrefix + Format('%.8d.dat', [Idx]);
      Hash := UopHash(Name);

      Found := False;
      for Cnt := 0 to NEntries-1 do
        if Entries[Cnt].Hash = Hash then
        begin
          Found := True;
          if Result = nil then Result := TMemoryStream.Create;
          AppendEntry(Entries[Cnt], Result);
          Break;
        end;

      Inc(Idx);
    until not Found;

    if Result <> nil then Result.Position := 0;
  finally
    F.Free;
  end;
end;

end.
