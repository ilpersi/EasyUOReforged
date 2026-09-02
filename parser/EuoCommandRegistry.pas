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

  TEuoCommandEntry = class(TObject)
  public
    Handler        : TEuoCommandProc;
    RequiresClient : Boolean;
    constructor Create(AHandler : TEuoCommandProc; ARequiresClient : Boolean);
  end;

  TEuoCommandRegistry = class(TObject)
  private
    Names : TStringList;   // Sorted:=True; Objects[i] = a TEuoCommandEntry
  public
    constructor Create;
    procedure   Free;
    procedure   Register(const Name : String; Handler : TEuoCommandProc; RequiresClient : Boolean = False);
    // Looks up Name (case-insensitive); if found and (not RequiresClient or
    // ClientSelected), invokes the handler and returns True. Otherwise (not
    // found, OR found but client-gated with no client available) does nothing
    // and returns False -- matching the original's silent-no-op behavior in
    // both cases; callers don't need to distinguish them.
    function    Dispatch(const Name : String; ClientSelected : Boolean) : Boolean;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TEuoCommandEntry.Create(AHandler : TEuoCommandProc; ARequiresClient : Boolean);
begin
  inherited Create;
  Handler:=AHandler;
  RequiresClient:=ARequiresClient;
end;

////////////////////////////////////////////////////////////////////////////////
constructor TEuoCommandRegistry.Create;
begin
  inherited Create;
  Names:=TStringList.Create;
  Names.Sorted:=True;    // safe here: only ever populated via AddObject, never
  Names.Duplicates:=dupError;  // Insert-at-a-Find-returned-index -- see EuoSortedList.pas
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
  if Entry.RequiresClient and not ClientSelected then Exit;
  Entry.Handler;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
end.
