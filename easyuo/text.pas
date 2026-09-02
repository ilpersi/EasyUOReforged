unit text;

{
  Ported from the original Delphi 7 easyuo\text.pas + text.dfm (a small reusable
  modal text dialog used for VarDump/Manage VarList). Built entirely via code
  rather than an .lfm -- see main.pas's header comment for why (this migration
  builds every form in code, not by hand-adapting Delphi's binary-DFM property
  streams, which don't reliably translate to LCL's own streaming format).
}

{$mode delphi}{$H+}

interface
uses Classes, SysUtils, Graphics, Forms, Controls, StdCtrls, ExtCtrls;

type
  TTextForm = class(TForm)
  private
    procedure FormResize(Sender: TObject);
  public
    TextMemo     : TMemo;
    BottomPanel  : TPanel;
    BottomLabel  : TLabel;
    ButtonPanel  : TPanel;
    OKButton     : TButton;
    CancelButton : TButton;
    constructor Create(AOwner : TComponent); override;
  end;

var
  TextForm: TTextForm;

implementation

////////////////////////////////////////////////////////////////////////////////
constructor TTextForm.Create(AOwner : TComponent);
begin
  inherited CreateNew(AOwner);

  Width := 416;
  Height := 339;
  BorderIcons := [biSystemMenu, biMaximize];
  Caption := 'Text Window';
  Position := poScreenCenter;
  OnResize := FormResize;

  BottomPanel := TPanel.Create(Self);
  BottomPanel.Parent := Self;
  BottomPanel.Align := alBottom;
  BottomPanel.Height := 45;
  BottomPanel.BevelOuter := bvNone;

  BottomLabel := TLabel.Create(Self);
  BottomLabel.Parent := Self;
  BottomLabel.Align := alBottom;
  BottomLabel.Alignment := taCenter;
  BottomLabel.WordWrap := True;

  TextMemo := TMemo.Create(Self);
  TextMemo.Parent := Self;
  TextMemo.Align := alClient;
  TextMemo.Font.Name := 'Courier New';
  TextMemo.ScrollBars := ssBoth;
  TextMemo.WantTabs := True;
  TextMemo.WordWrap := False;

  ButtonPanel := TPanel.Create(Self);
  ButtonPanel.Parent := BottomPanel;
  ButtonPanel.Left := 88;
  ButtonPanel.Width := 233;
  ButtonPanel.Height := 41;
  ButtonPanel.BevelOuter := bvNone;

  OKButton := TButton.Create(Self);
  OKButton.Parent := ButtonPanel;
  OKButton.Left := 8;
  OKButton.Top := 6;
  OKButton.Width := 105;
  OKButton.Height := 25;
  OKButton.Caption := '&OK';
  OKButton.ModalResult := mrOK;

  CancelButton := TButton.Create(Self);
  CancelButton.Parent := ButtonPanel;
  CancelButton.Left := 120;
  CancelButton.Top := 6;
  CancelButton.Width := 105;
  CancelButton.Height := 25;
  CancelButton.Caption := '&Cancel';
  CancelButton.ModalResult := mrCancel;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TTextForm.FormResize(Sender: TObject);
begin
  ButtonPanel.Left:=(BottomPanel.Width-ButtonPanel.Width) div 2;
end;

////////////////////////////////////////////////////////////////////////////////
end.
