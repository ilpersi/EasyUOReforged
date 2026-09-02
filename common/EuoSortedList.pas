unit EuoSortedList;

{
  A small shared helper, needed because of a genuine conflict discovered while
  porting parser\variables.pas (and needed again for parser.pas's SpeedVar,
  scripts.pas's per-frame Info list, and uo\uovariables.pas's ContList): the
  original code keeps several TStringLists in sorted order MANUALLY -- "Find
  (binary search) for the insertion point, then Insert/InsertObject at exactly
  that point" -- with Sorted left at its default False throughout.

  FPC's TStringList.Find raises EListError unless Sorted=True (confirmed against the
  actual RTL source, see the Phase 1 uoclidata.pas/access.pas work). But TStringList
  ALSO explicitly forbids Insert/InsertObject at an arbitrary index once Sorted=True
  ("Operation not allowed on sorted list") -- confirmed empirically, the hard way,
  by a first attempt at this fix that just flipped Sorted:=True and broke every
  Insert call site. The two FPC requirements directly conflict for lists that need
  both operations, so this specific pattern can't be fixed by touching the Sorted
  property at all.

  FindSortedPos replicates exactly what a sorted TStringList.Find would do (binary
  search, landing on the FIRST index of a run of equal entries), operating on a
  plain unsorted-flagged TStrings, so callers can keep the original's exact
  "Find then Insert at that index" structure with no restriction on Insert.

  Lives in common\ (not parser\, where it was first written during Phase 2)
  because uo\uovariables.pas needs the exact same fix for its ContList, and uo\
  must not depend on parser\ -- moved here once that dependency direction became
  clear, rather than duplicating the helper.
}

{$mode delphi}{$H+}

interface
uses Classes, SysUtils;

// Binary search over a TStrings assumed (by construction, not by the Sorted flag)
// to already be in ascending CompareStr order. Returns True and the exact index if
// found; False and the index a new entry should be Inserted at to keep the list
// sorted, otherwise. On duplicates, lands on the first matching index.
function FindSortedPos(List : TStrings; const S : String; out Index : Integer) : Boolean;

implementation

function FindSortedPos(List : TStrings; const S : String; out Index : Integer) : Boolean;
var
  L, H, M, C : Integer;
begin
  L := 0;
  H := List.Count - 1;
  Result := False;
  while L <= H do
  begin
    M := (L + H) shr 1;
    C := CompareStr(List[M], S);
    if C < 0 then L := M + 1
    else begin
      H := M - 1;
      if C = 0 then
      begin
        Result := True;
        L := M;
      end;
    end;
  end;
  Index := L;
end;

end.
