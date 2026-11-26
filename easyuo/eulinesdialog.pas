unit eulinesdialog;

{
  Port addition: the dialog that edits a list of lines, one per line, OK/Cancel. It was the MENU
  Designer's (tools/EUOMenuDesigner/mdinspector.pas: a combo's or list's Items, a text's lines, an
  image's drawing operations) and moved here, unchanged, when the editor's Watches panel
  (euwatch.pas) needed the same dialog to edit a script's list (LIST command): both use this unit.
}

{$mode delphi}{$H+}

interface
uses
  Classes, SysUtils, Controls, Forms, StdCtrls, ExtCtrls;

function LinesDialog(const Title, Hint : String; Lines : TStrings; out Memo : TMemo) : TForm;
function EditLines(const Title, Hint : String; Lines : TStrings) : Boolean;

implementation

// A small dialog with a memo: one line per item or drawing operation. EditLines shows it.
// The buttons are anchored to the panel's right edge and to each other: the panel has its
// width only once the window is shown, so positions worked out from it beforehand land outside.
function LinesDialog(const Title, Hint : String; Lines : TStrings; out Memo : TMemo) : TForm;
var
  F      : TForm;
  L      : TLabel;
  P      : TPanel;
  OK     : TButton;
  Cancel : TButton;
begin
  F:=TForm.CreateNew(nil);
  F.Caption:=Title;
  F.Position:=poScreenCenter;
  F.Width:=480;
  F.Height:=360;
  L:=TLabel.Create(F);
  L.Parent:=F;
  L.Align:=alTop;
  L.WordWrap:=True;
  L.BorderSpacing.Around:=6;
  L.Caption:=Hint;
  P:=TPanel.Create(F);
  P.Parent:=F;
  P.Align:=alBottom;
  P.Height:=40;
  P.BevelOuter:=bvNone;
  Cancel:=TButton.Create(F);
  Cancel.Parent:=P;
  Cancel.Caption:='Cancel';
  Cancel.ModalResult:=mrCancel;
  Cancel.Cancel:=True;
  Cancel.SetBounds(0,8,80,26);
  Cancel.AnchorSideRight.Control:=P;
  Cancel.AnchorSideRight.Side:=asrRight;
  Cancel.BorderSpacing.Right:=8;
  Cancel.Anchors:=[akTop,akRight];
  OK:=TButton.Create(F);
  OK.Parent:=P;
  OK.Caption:='OK';
  OK.ModalResult:=mrOK;
  OK.Default:=True;
  OK.SetBounds(0,8,80,26);
  OK.AnchorSideRight.Control:=Cancel;
  OK.AnchorSideRight.Side:=asrLeft;
  OK.BorderSpacing.Right:=6;
  OK.Anchors:=[akTop,akRight];
  Memo:=TMemo.Create(F);
  Memo.Parent:=F;
  Memo.Align:=alClient;
  Memo.ScrollBars:=ssAutoBoth;
  Memo.WordWrap:=False;
  Memo.Font.Name:='Courier New';
  Memo.Lines.Assign(Lines);
  Result:=F;
end;

function EditLines(const Title, Hint : String; Lines : TStrings) : Boolean;
var
  F : TForm;
  M : TMemo;
begin
  F:=LinesDialog(Title,Hint,Lines,M);
  try
    Result:=F.ShowModal=mrOK;
    if Result then Lines.Assign(M.Lines);
  finally
    F.Free;
  end;
end;

end.
