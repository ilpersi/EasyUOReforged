unit main;

{
  Ported from the original Delphi 7 tools\EUOUpdater\main.pas + main.dfm. Built
  via code, not an .lfm, for consistency with the rest of this migration's GUI
  work (see easyuo\main.pas's header comment) -- this form has no icon/bitmap
  resources at all, so there was no DFM-conversion risk here specifically, but
  building it the same way keeps every GUI shell in this migration consistent
  and auditable the same way.

  uoxloader.pas (TUOXL, launches a fresh UO client with a couple of anti-error-
  message byte patches) is NOT ported: it is genuinely dead code in the
  original -- neither main.pas nor EUOUpdtr.dpr's uses clause references it at
  all, and TUOXL is never instantiated anywhere reachable from the tool's
  actual entry point. Confirmed by reading every reference to it (there are
  none outside its own file), not assumed from the filename. Porting
  unreachable code would add real risk (its own hand-built byte patches are
  exactly the kind of thing that's easy to silently get wrong) for zero
  functional benefit, so it's left out and flagged here rather than silently
  dropped.
}

{$mode delphi}{$H+}

interface
uses Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms,
     Dialogs, access, UOSelector, ExtCtrls, StdCtrls;

type
  TMainForm = class(TForm)
  private
    procedure SysTimerTimer(Sender: TObject);
    procedure StartButtonClick(Sender: TObject);
    procedure BuildComponents;
  public
    MainPanel     : TPanel;
    SysTimer      : TTimer;
    ScanMemo      : TMemo;
    ResMemo       : TMemo;
    BottomPanel   : TPanel;
    StartButton   : TButton;
    ScanLabel     : TLabel;
    MainSplitter  : TSplitter;
    ResLabel      : TLabel;
    constructor Create(AOwner : TComponent); override;
  end;

var
  MainForm : TMainForm;
  UOSel    : TUOSel;

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TMainForm.Create(AOwner : TComponent);
begin
  inherited CreateNew(AOwner);

  Width := 744;
  Height := 516;
  Caption := 'EUO Updtr';
  Position := poScreenCenter;

  BuildComponents;

  SysTimer.Enabled := True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.BuildComponents;
begin
  MainPanel := TPanel.Create(Self);
  MainPanel.Parent := Self;
  MainPanel.Align := alClient;
  MainPanel.BevelOuter := bvNone;
  MainPanel.Visible := False;

  ScanMemo := TMemo.Create(Self);
  ScanMemo.Parent := MainPanel;
  ScanMemo.Align := alClient;
  ScanMemo.Font.Name := 'Courier New';
  ScanMemo.ScrollBars := ssBoth;
  ScanMemo.WantTabs := True;
  ScanMemo.WordWrap := False;

  MainSplitter := TSplitter.Create(Self);
  MainSplitter.Parent := MainPanel;
  MainSplitter.Align := alRight;

  ResMemo := TMemo.Create(Self);
  ResMemo.Parent := MainPanel;
  ResMemo.Align := alRight;
  ResMemo.Width := 370;
  ResMemo.Font.Name := 'Courier New';
  ResMemo.ScrollBars := ssBoth;
  ResMemo.WordWrap := False;

  BottomPanel := TPanel.Create(Self);
  BottomPanel.Parent := MainPanel;
  BottomPanel.Align := alBottom;
  BottomPanel.Height := 74;

  ScanLabel := TLabel.Create(Self);
  ScanLabel.Parent := BottomPanel;
  ScanLabel.Left := 8;
  ScanLabel.Top := 8;
  ScanLabel.Caption := 'Scan Strings:';

  ResLabel := TLabel.Create(Self);
  ResLabel.Parent := BottomPanel;
  ResLabel.Left := 365;
  ResLabel.Top := 8;
  ResLabel.Anchors := [akTop, akRight];
  ResLabel.Caption := 'Result List:';

  StartButton := TButton.Create(Self);
  StartButton.Parent := BottomPanel;
  StartButton.Left := 8;
  StartButton.Top := 32;
  StartButton.Width := 97;
  StartButton.Height := 25;
  StartButton.Caption := 'Start';
  StartButton.OnClick := StartButtonClick;

  SysTimer := TTimer.Create(Self);
  SysTimer.Enabled := False;
  SysTimer.Interval := 250;
  SysTimer.OnTimer := SysTimerTimer;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

procedure TMainForm.SysTimerTimer(Sender: TObject);
begin
  UOSel.Update;
  if UOSel.Nr>0 then Exit;

  if UOSel.Cnt>0 then
    UOSel.SelectClient(1);
  MainPanel.Visible:=UOSel.Cnt>0
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

function GetAddr(Str : String; var Res : Cardinal; var Desc : String) : Boolean;
var
  sBuf   : String;
  Cnt    : Cardinal;
  Cnt2   : Integer;
  sPar   : Array[1..6] of String;
begin
  Result:=False;

  sBuf:=Str+';';
  for Cnt:=1 to 6 do
  begin
    sPar[Cnt]:='';
    Cnt2:=Pos(';',sBuf);
    if Cnt2=0 then Continue;
    sPar[Cnt]:=UpperCase(Trim(Copy(sBuf,1,Cnt2-1)));
    Delete(sBuf,1,Cnt2);
  end;
  Desc:=sPar[6];

  sBuf:='';
  while sPar[1]<>'' do
  begin
    sBuf:=sBuf+Char(StrToIntDef('$'+Copy(sPar[1],1,2),0));
    Delete(sPar[1],1,2);
  end;

  sPar[2]:=Char(StrToIntDef('$'+sPar[2],1));
  Res:=SearchMem(UOSel.HProc,sBuf,sPar[2][1]);
  if Res<1 then Exit;

  Res:=Res+StrToIntDef(sPar[3],0);
  Cnt:=Res;
  if Copy(sPar[4],1,1)='C' then
    ReadMem(UOSel.HProc,Cnt,@Res,4);
  if Copy(sPar[4],2,1)='B' then
    Res:=Res+Cnt+4;

  Res:=Res+StrToIntDef(sPar[5],0);

  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMainForm.StartButtonClick(Sender: TObject);
var
  Cnt   : Integer;
  Res   : Cardinal;
  Desc  : String;
  sBuf  : String;
begin
  ResMemo.Clear;
  sBuf:='empty';
  for Cnt:=0 to ScanMemo.Lines.Count-1 do
  begin

    if Copy(ScanMemo.Lines[Cnt],1,2)='//' then Continue;

    if ScanMemo.Lines[Cnt]='' then
    begin
      ResMemo.Lines.Add('');
      Continue;
    end;

    if not GetAddr(ScanMemo.Lines[Cnt],Res,Desc) then
    begin
      if sBuf<>Desc then
        ResMemo.Lines.Add('N/A '+Desc);
    end
    else begin
      if sBuf=Desc then
        ResMemo.Lines.Delete(ResMemo.Lines.Count-1);
      ResMemo.Lines.Add('$'+IntToHex(Res,8)+' '+Desc);
    end;

    sBuf:=Desc;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////

initialization
  UOSel:=TUOSel.Create;
finalization
  UOSel.Free;
end.
