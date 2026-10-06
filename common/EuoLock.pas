unit EuoLock;

{
  Replacement for TMultiReadExclusiveWriteSynchronizer (Delphi's, and FPC's port of it)
  on the interpreter's hot path. Not in the original Delphi source.

  Why: sampling the interpreter with no client attached showed roughly half of all
  time spent in two kernel calls, NtSetEvent and NtClearEvent, plus a per-thread record
  allocated and freed around every outermost lock. FPC's MREW (see
  rtl\objpas\sysutils\sysuthrd.inc) resets/sets two event objects on every outermost
  BeginWrite/EndWrite and allocates a PMREWThreadInfo on every outermost Begin*. The
  interpreter takes its lock around every script line, TCstDB takes one around every offset
  accessor and TUOSel::Nr one around every client-gated command, so that cost is paid
  several times per executed line. See tests\PerfBenchTests.pas / tests\tools\RunBench.ps1.

  What this keeps: the BeginRead/EndRead/BeginWrite/EndWrite surface, recursion on one
  thread (a thread may nest any mix of Begin*/End*), and mutual exclusion between threads.

  What it gives up: concurrent readers. Every holder is exclusive. All three users hold
  the lock for a handful of memory reads or list lookups, so readers queuing behind one
  another is invisible; the interpreter's own lock was already a writer lock on the hot path.
  In exchange the uncontended path is an interlocked operation, with no syscall and no
  allocation.

  Also kept: FPC's MREW raises when End* is called without a matching Begin*. A recursive
  critical section would instead silently corrupt its count, so the owner/depth bookkeeping
  below (only touched while the lock is held) preserves that diagnostic.
}

{$mode delphi}{$H+}

interface

uses
  SysUtils;

type
  ELockError = class(Exception);

  TEuoLock = class
  private
    FLock  : TRTLCriticalSection;
    FOwner : TThreadID;     // valid only while FDepth > 0, and only touched while FLock is held
    FDepth : Integer;
    procedure Acquire;
    procedure Release(const What : String);
  public
    constructor Create;
    destructor Destroy; override;
    procedure BeginRead;
    procedure EndRead;
    procedure BeginWrite;
    procedure EndWrite;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TEuoLock.Create;
begin
  inherited Create;
  InitCriticalSection(FLock);
end;

////////////////////////////////////////////////////////////////////////////////
destructor TEuoLock.Destroy;
begin
  DoneCriticalSection(FLock);
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLock.Acquire;
begin
  EnterCriticalSection(FLock);
  FOwner := GetCurrentThreadId;
  Inc(FDepth);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLock.Release(const What : String);
begin
  // Reading FOwner/FDepth without the lock is a benign race for the "not the owner"
  // check: another thread can only ever see a value that is not its own thread id.
  if (FDepth <= 0) or (FOwner <> GetCurrentThreadId) then
    raise ELockError.Create(What + ' called before Begin' + Copy(What, 4, MaxInt));
  Dec(FDepth);
  LeaveCriticalSection(FLock);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLock.BeginRead;
begin
  Acquire;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLock.EndRead;
begin
  Release('EndRead');
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLock.BeginWrite;
begin
  Acquire;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoLock.EndWrite;
begin
  Release('EndWrite');
end;

////////////////////////////////////////////////////////////////////////////////
end.
