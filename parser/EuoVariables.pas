unit EuoVariables;

{
  Ported from the original Delphi 7 parser\variables.pas.

  Fix applied: FPC's TStringList.Find raises EListError unless Sorted:=True, but
  TStringList ALSO forbids Insert/InsertObject at an arbitrary index once
  Sorted:=True ("Operation not allowed on sorted list") -- confirmed empirically.
  Names/Values are kept in sorted order manually ("Find for insertion point, then
  Insert at that point", never .Add), so the two FPC requirements directly conflict.
  Fixed by leaving Sorted at its default False and using EuoSortedList.FindSortedPos
  (a plain binary search) wherever the original called .Find -- see that unit's
  header comment for the full story.

  _NSGlobal is the single most important thing to get exactly right in this unit: a
  literal unit-initialization-owned singleton TVarList that every TVars instance
  aliases (NOT a fresh instance per interpreter). This is DELIBERATE cross-script IPC
  -- NAMESPACE GLOBAL variables are shared by every simultaneously-running script/
  client instance in the process (e.g. multiple clients driven via UOXL NEW). Ported
  with the identical unit-init/final-owned pattern, wrapped behind the named
  NSGlobalSingleton function purely for discoverability (zero behavior change) so a
  future reader can't mistake the alias for a leaked/duplicated instance and "fix" it
  into a per-instance field. See EuoVariablesTests.pas for the test that would fail
  loudly if that ever happened by accident.
}

{$mode delphi}{$H+}

interface
uses SysUtils, Classes, Registry, SyncObjs, EuoSortedList;

type
  TVarList      = class(TObject)
  private
    CS          : TCriticalSection;
    Names       : TStringList;
    Values      : TStringList;
  public
    constructor Create;
    procedure   Free;
    procedure   Clear;
    procedure   SetVar(Name,Value : String);
    function    GetVar(Name : String) : String;
    function    ListVars(FindStr : String) : String;
    procedure   DelVars(FindStr : String; Exact : Boolean);
  end;

  TNSType       = (global,local);

  TVars         = class(TObject)
  private
    CS          : TCriticalSection;
    Reg         : TRegistry;
    sNSName     : String;
    function    GetNSName : String;
    procedure   SetNSName(Value : String);
  public
    UserVars    : TVarList;
    NSType      : TNSType;
    NSLocal     : TVarList;
    NSGlobal    : TVarList;
    constructor Create;
    procedure   Free;
    procedure   SetVar(Name,Value : String);
    function    GetVar(Name : String) : String;
    property    NSName : String read GetNSName write SetNSName;
  end;

// The one process-wide NAMESPACE GLOBAL store -- see the unit header comment.
function NSGlobalSingleton : TVarList;

implementation

var
  _NSGlobal     : TVarList;

////////////////////////////////////////////////////////////////////////////////
function NSGlobalSingleton : TVarList;
begin
  Result:=_NSGlobal;
end;

////////////////////////////////////////////////////////////////////////////////
/// TVarList ///////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TVarList.Create;
begin
  inherited Create;
  Names:=TStringList.Create;
  Values:=TStringList.Create;
  CS:=TCriticalSection.Create;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TVarList.Free;
begin
  CS.Free;
  Names.Free;
  Values.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TVarList.Clear;
begin
  CS.Enter;
  Names.Clear;
  Values.Clear;
  CS.Leave;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TVarList.SetVar(Name,Value : String);
var
  i : Integer;
begin
  CS.Enter;
  Name:=UpperCase(Name);
  if not FindSortedPos(Names,Name,i) then
  begin
    Names.Insert(i,Name);
    Values.Insert(i,Value);
  end
  else Values[i]:=Value;
  CS.Leave;
end;

////////////////////////////////////////////////////////////////////////////////
function TVarList.GetVar(Name : String) : String;
var
  i : Integer;
begin
  CS.Enter;
  Result:='N/A';
  if FindSortedPos(Names,UpperCase(Name),i) then
    Result:=Values[i];
  CS.Leave;
end;

////////////////////////////////////////////////////////////////////////////////
function TVarList.ListVars(FindStr : String) : String;
var
  i,len : Integer;
begin
  CS.Enter;
  FindStr:=UpperCase(FindStr);
  len:=Length(FindStr);
  Result:='';
  FindSortedPos(Names,FindStr,i);
  while i<Names.Count do
  begin
    if Copy(Names[i],1,len)<>FindStr then Break;
    Result:=Result+Copy(Names[i],len+1,999)+#13#10;
    Inc(i);
  end;
  Delete(Result,Length(Result)-1,2);
  CS.Leave;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TVarList.DelVars(FindStr : String; Exact : Boolean);
var
  i : Integer;
begin
  CS.Enter;
  FindStr:=UpperCase(FindStr);
  FindSortedPos(Names,FindStr,i);
  while i<Names.Count do
  begin
    if Copy(Names[i],1,Length(FindStr))<>FindStr then Break;
    Names.Delete(i);
    Values.Delete(i);
    if Exact then Break;
  end;
  CS.Leave;
end;

////////////////////////////////////////////////////////////////////////////////
/// TVars //////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

constructor TVars.Create;
begin
  inherited Create;
  UserVars:=TVarList.Create;
  NSLocal:=TVarList.Create;
  NSGlobal:=NSGlobalSingleton; //object reference is constant -- do NOT change this
                               //to NSGlobal:=TVarList.Create -- see unit header comment
  sNSName:='std';
  NSType:=local;
  Reg:=TRegistry.Create;
  Reg.OpenKey('\Software\EasyUO',True);
  CS:=TCriticalSection.Create;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TVars.Free;
begin
  CS.Free;
  Reg.CloseKey;
  Reg.Free;
  UserVars.Free;
  NSLocal.Free;
  inherited Free;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TVars.SetVar(Name,Value : String);
begin
  if Name<>'' then
  case Name[1] of
    '%' : UserVars.SetVar(Name,Value);
    '!' : begin
            CS.Enter;
            Name:='!'+sNSName+'~'+PChar(@Name[2]);
            CS.Leave;
            if NSType=local then NSLocal.SetVar(Name,Value)
            else NSGlobal.SetVar(Name,Value);
          end;
    '*' : begin
            CS.Enter;
            try Reg.WriteString(Name,Value); except end;
            CS.Leave;
          end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TVars.GetVar(Name : String) : String;
begin
  Result:='N/A';
  if Name<>'' then
  case Name[1] of
    '%' : Result:=UserVars.GetVar(Name);
    '!' : begin
            CS.Enter;
            Name:='!'+sNSName+'~'+PChar(@Name[2]);
            CS.Leave;
            if NSType=local then Result:=NSLocal.GetVar(Name)
            else Result:=NSGlobal.GetVar(Name);
          end;
    '*' : begin
            CS.Enter;
            if Reg.GetDataType(Name)=rdString then
              try Result:=Reg.ReadString(Name); except end;
            CS.Leave;
          end;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function TVars.GetNSName : String;
begin
  CS.Enter;
  Result:=sNSName;
  CS.Leave;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TVars.SetNSName(Value : String);
begin
  CS.Enter;
  sNSName:=Value;
  CS.Leave;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

initialization
  _NSGlobal:=TVarList.Create;
finalization
  _NSGlobal.Free;
end.
