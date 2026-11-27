unit uopropscan;
{ Port addition (scanprops, 2026-11-27): uoprops' scan on a live client. The script command and
  uo.dll's ScanProps both call ScanItemProps, so they behave the same.

  The cache is read with TUOCmd.ReadPropEntry, cliloc texts with TUOCmd.ClilocRaw; items the cache
  can't answer are asked for with TUOEvent.RequestProps. An item that still has no cache entry after
  the wait gets one `event property` on the fixed-base clients (which then name it from the object
  itself); on the relocated builds `event property` would only ask the server again and give `$` after
  3 s, so the scan stores `$` at once. When the cache can't be read at all (no C_PROPCACHE, or
  C_CLILOC missing) every item gets one `event property`, as a script would do by hand.
  docs/property-cache-analysis.md. }

{$mode delphi}{$H+}

interface

uses SysUtils, uoprops, uocommands, uoevents, uoclidata, uoselector, uotypes;

type
  TUOPropSource = class(TPropSource)
  private
    FCmd   : TUOCmd;
    FEv    : TUOEvent;
    FCst   : TCstDB;
    FDelay : TDelayFunc;
  public
    constructor Create(Cmd : TUOCmd; Ev : TUOEvent; Cst : TCstDB; DFunc : TDelayFunc);
    function  Supported : Boolean; override;
    function  ReadEntry(ID : Cardinal; out Lines : TPropLines) : TPropEntryState; override;
    function  Request(const IDs : TPropIDs) : Boolean; override;
    function  Fallback(ID : Cardinal; out Text : String) : Boolean; override;
    function  Lookup(ID : Integer; out Text : RawByteString) : Integer; override;
    function  CoinPlural : Boolean; override;
    function  Pause(Ms : Cardinal) : Boolean; override;
  end;

// Every item the last FilterItems (finditem) kept, into Store.
procedure ScanItemProps(Cmd : TUOCmd; Ev : TUOEvent; Cst : TCstDB; DFunc : TDelayFunc; Store : TPropStore);

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TUOPropSource.Create(Cmd : TUOCmd; Ev : TUOEvent; Cst : TCstDB; DFunc : TDelayFunc);
begin
  inherited Create;
  FCmd:=Cmd;
  FEv:=Ev;
  FCst:=Cst;
  FDelay:=DFunc;
end;

function TUOPropSource.Supported : Boolean;
begin
  Result:=FCmd.PropSupported;
end;

function TUOPropSource.ReadEntry(ID : Cardinal; out Lines : TPropLines) : TPropEntryState;
begin
  Result:=FCmd.ReadPropEntry(ID,Lines);
end;

function TUOPropSource.Request(const IDs : TPropIDs) : Boolean;
begin
  Result:=FEv.RequestProps(IDs);
end;

// event property's text, with PropStr1 / PropStr2 (what #Property shows) put back afterwards.
function TUOPropSource.Fallback(ID : Cardinal; out Text : String) : Boolean;
var
  S1, S2 : String;
begin
  Text:='';
  Result:=False;
  if FCmd.PropSupported and (FCst.FPROPFAST=1) then Exit;
  S1:=FEv.PropStr1;
  S2:=FEv.PropStr2;
  try
    FEv.EvProperty(ID);
    Text:=PropJoin(FEv.PropStr1,FEv.PropStr2);
    Result:=True;
  finally
    FEv.PropStr1:=S1;
    FEv.PropStr2:=S2;
  end;
end;

function TUOPropSource.Lookup(ID : Integer; out Text : RawByteString) : Integer;
begin
  Result:=FCmd.ClilocRaw(ID,Text);
end;

// The relocated builds (the betas 7.0.117.31 and newer) pluralise coin names; the fixed-base ones don't.
function TUOPropSource.CoinPlural : Boolean;
begin
  Result:=FCst.FPROPFAST=1;
end;

function TUOPropSource.Pause(Ms : Cardinal) : Boolean;
begin
  if Assigned(FDelay) then Result:=FDelay(Ms)
  else Result:=inherited Pause(Ms);
end;

////////////////////////////////////////////////////////////////////////////////
procedure ScanItemProps(Cmd : TUOCmd; Ev : TUOEvent; Cst : TCstDB; DFunc : TDelayFunc; Store : TPropStore);
var
  Src : TUOPropSource;
begin
  Src:=TUOPropSource.Create(Cmd,Ev,Cst,DFunc);
  try
    PropScan(Src,Cmd.FilterIDs,Store);
  finally
    Src.Free;
  end;
end;

end.
