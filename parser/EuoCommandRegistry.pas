unit EuoCommandRegistry;

{
  Replaces the original parser.pas's two linear-scan-then-case-of-index dispatch
  tables (the 34-entry Cmd1 array + Interpret's case statement, and the 23-entry
  Cmd2 array + InterpretUO's case statement) with one name -> handler registry.

  Behavioral contract, preserved exactly: the original always runs the Cmd1 pass,
  then ALSO runs the Cmd2 (InterpretUO) pass whenever a client is selected
  (UOSel.Nr>0) -- as two independent scans over disjoint keyword sets, regardless
  of whether the Cmd1 pass matched anything. Here, every command is registered
  once with a RequiresClient flag (True for the original 23 Cmd2 names); Dispatch
  looks the token up once and invokes it only if RequiresClient is False or a
  client is currently selected. Because the original two keyword sets are
  disjoint, this is exactly equivalent to the original's "always scan table 1,
  also scan table 2 iff a client is selected" -- just one lookup instead of two,
  and each handler is now an independently callable/testable method instead of an
  unreachable branch inside a 2900-line procedure.

  StopCD/PlayCD are registered with an explicit no-op handler rather than being
  left unregistered: in the original, they ARE recognized Cmd1 keywords (present
  in the array) that simply have no case label in Interpret's case statement, so
  they're silent no-ops today -- not unrecognized words. Registering them
  explicitly preserves "recognized but does nothing" rather than quietly
  demoting them to "unrecognized" if this registry is ever extended with an
  unknown-command diagnostic.
}

{$mode delphi}{$H+}

interface
uses Classes, SysUtils;

type
  TEuoCommandProc = procedure of object;

  // Port addition: told the upper-case name of a blocked command a script reached.
  TEuoBlockedProc = procedure(const Name : String) of object;

  TEuoCommandEntry = class(TObject)
  public
    Handler        : TEuoCommandProc;
    RequiresClient : Boolean;
    Blocked        : Boolean;   // port addition, see SetBlocked; False unless a host asks
    constructor Create(AHandler : TEuoCommandProc; ARequiresClient : Boolean);
  end;

  TEuoCommandRegistry = class(TObject)
  private
    Names      : TStringList;   // Sorted:=True; Objects[i] = a TEuoCommandEntry
    FOnBlocked : TEuoBlockedProc;
  public
    // Port addition: how many lines were skipped because their command needs a client and
    // none was selected. Counted, never acted on: the skip itself is the original's.
    ClientSkips : Cardinal;
    constructor Create;
    procedure   Free;
    procedure   Register(const Name : String; Handler : TEuoCommandProc; RequiresClient : Boolean = False);
    // Looks up Name (case-insensitive); if found and (not RequiresClient or
    // ClientSelected), invokes the handler and returns True. Otherwise (not
    // found, OR found but client-gated with no client available) does nothing
    // and returns False -- matching the original's silent-no-op behavior in
    // both cases; callers don't need to distinguish them.
    function    Dispatch(const Name : String; ClientSelected : Boolean) : Boolean;
    // Port addition (the script checker, EuoLint.pas): every registered name, upper-case and
    // sorted, added to List; Objects[i] is non-nil for a name registered with RequiresClient.
    // Read-only: nothing here is used when a script runs.
    procedure   GetNames(List : TStrings);
    // Port addition (EUOCli run, docs\agent-support.md phase 3): a host that runs scripts for
    // an AI agent names the commands it will not run (EXECUTE, SHUTDOWN, ...). Dispatch then
    // calls OnBlocked with the name instead of the handler and returns False. Blocked replaces
    // the earlier list; a name that is no command is ignored. Nothing is blocked until a host
    // asks, so the editor and uo.dll dispatch exactly as before.
    procedure   SetBlocked(Blocked : TStrings; OnBlocked : TEuoBlockedProc);
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TEuoCommandEntry.Create(AHandler : TEuoCommandProc; ARequiresClient : Boolean);
begin
  inherited Create;
  Handler:=AHandler;
  RequiresClient:=ARequiresClient;
  Blocked:=False;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TEuoCommandRegistry.Create;
begin
  inherited Create;
  Names:=TStringList.Create;
  // Register and Dispatch both UpperCase the name, so every key and every probe is already
  // upper-case and a plain ordinal compare gives the same answer as the default
  // case-insensitive, locale-aware one. That default is AnsiCompareText ->
  // LazUTF8.UTF8CompareText -> UTF-16 conversion + Win32 CompareStringEx, run about six
  // times per executed script line (tests\PerfBenchTests.pas). CaseSensitive alone is not
  // enough: with UseLocale still on, Find calls AnsiCompareStr, the same Unicode path.
  // Both must be set before Sorted so the list is ordered by the comparison Find uses.
  Names.CaseSensitive:=True;
  Names.UseLocale:=False;
  Names.Sorted:=True;    // safe here: only ever populated via AddObject, never
  Names.Duplicates:=dupError;  // Insert-at-a-Find-returned-index -- see EuoSortedList.pas
  FOnBlocked:=nil;
  ClientSkips:=0;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCommandRegistry.Free;
var
  i : Integer;
begin
  for i:=0 to Names.Count-1 do
    Names.Objects[i].Free;
  Names.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCommandRegistry.Register(const Name : String; Handler : TEuoCommandProc; RequiresClient : Boolean = False);
begin
  Names.AddObject(UpperCase(Name),TEuoCommandEntry.Create(Handler,RequiresClient));
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoCommandRegistry.Dispatch(const Name : String; ClientSelected : Boolean) : Boolean;
var
  i : Integer;
  Entry : TEuoCommandEntry;
begin
  Result:=False;
  if not Names.Find(UpperCase(Name),i) then Exit;
  Entry:=TEuoCommandEntry(Names.Objects[i]);
  if Entry.RequiresClient and not ClientSelected then
  begin
    Inc(ClientSkips);   // port addition: counted for the host, the skip is the original's
    Exit;
  end;
  if Entry.Blocked then   // port addition: never True unless a host called SetBlocked
  begin
    if Assigned(FOnBlocked) then FOnBlocked(Names[i]);
    Exit;
  end;
  Entry.Handler;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCommandRegistry.SetBlocked(Blocked : TStrings; OnBlocked : TEuoBlockedProc);
var
  i, j : Integer;
begin
  for i:=0 to Names.Count-1 do
    TEuoCommandEntry(Names.Objects[i]).Blocked:=False;
  if Blocked<>nil then
    for i:=0 to Blocked.Count-1 do
      if Names.Find(UpperCase(Trim(Blocked[i])),j) then
        TEuoCommandEntry(Names.Objects[j]).Blocked:=True;
  FOnBlocked:=OnBlocked;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoCommandRegistry.GetNames(List : TStrings);
var
  i : Integer;
begin
  for i:=0 to Names.Count-1 do
    List.AddObject(Names[i],TObject(PtrUInt(Ord(TEuoCommandEntry(Names.Objects[i]).RequiresClient))));
end;

////////////////////////////////////////////////////////////////////////////////
end.
