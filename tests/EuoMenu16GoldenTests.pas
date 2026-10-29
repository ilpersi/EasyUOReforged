unit EuoMenu16GoldenTests;

{
  The 1.6 MENU logic against EasyUO 1.6 itself. Every probe in tests/fixtures/menu16 was run in
  the real EasyUO 1.6.0.337 by tests/tools/Record16MenuGolden.py, which wrote what it observed
  next to it (<probe>.json, <probe>.<name>.png). Here the same probe runs under Reforged's 1.6
  logic, with the same clicks, closes and restarts at the same points, and each observation is
  compared: the reports the probe writes into form captions, the forms' geometry and child
  windows, layered alpha, and the pixels of drawn images. All differences of a probe are listed
  in one failure.

  The probes give the recorder time (wait N; loops that wait a few seconds for a click). Here
  every action happens before the next line runs, so those waits are set to 0, which changes
  no result. #CurPath is EasyUO's own folder in both programs, so the image probe's golden.bmp
  is pointed at the fixture folder.

  The recording holds for the Windows build and DPI in recording.json. An edit's and a combo
  box's height come from font metrics and may differ by a few pixels. These tests show real
  windows; without a window station they report themselves ignored.
}

{$mode delphi}{$H+}

interface

uses
  Windows, Classes, SysUtils, Graphics, Forms, Controls, StdCtrls, ExtCtrls, fpjson, jsonparser,
  fpcunit, testregistry, EuoMenuSelect, EuoMenuCommon, EuoInterpreter;

type
  TEuoMenu16GoldenTests = class(TTestCase)
  private
    Interp  : TEuoInterpreter;
    Diffs   : TStringList;
    Skipped : TStringList;
    Probe   : String;
    procedure Replay(const Name : String);
    procedure Note(const S : String);
    function  FindForm(const Prefix : String) : TEuoMenuForm;
    function  PlayUntilReport(const Tag : String; out Report : String) : Boolean;
    procedure CompareReport(const Tag, Want, Got : String);
    procedure CompareForms(Want : TJSONArray);
    procedure CompareChildren(const Where : String; Want : TJSONArray; Box : TWinControl);
    procedure CompareSnap(Ev : TJSONObject);
    procedure CompareAlpha(Ev : TJSONObject);
    procedure Click(const Caption : String);
    procedure CloseForm(const Prefix : String);
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestAlign;
    procedure TestClose;
    procedure TestDefaults;
    procedure TestDefaultsStack;
    procedure TestDelete;
    procedure TestDeleteForm0;
    procedure TestDuplicates;
    procedure TestFont;
    procedure TestForms;
    procedure TestGetSet;
    procedure TestHideClear;
    procedure TestImage;
    procedure TestNames;
    procedure TestPanelsRadio;
    procedure TestParent;
    procedure TestPopup;
    procedure TestPropsGet;
    procedure TestPropsSet;
    procedure TestRestart;
    procedure TestShapes;
    procedure TestStale;
    procedure TestValidation;
    procedure TestWindow;
  end;

implementation

type
  TPixels = array of Cardinal;

function PrintWindow(hWnd : HWND; hdcBlt : HDC; nFlags : UINT) : BOOL; stdcall;
  external 'user32.dll';

function FixtureDir : String;
begin
  Result:=ExtractFilePath(ParamStr(0))+'fixtures'+PathDelim+'menu16'+PathDelim;
end;

function ReadText(const Path : String) : String;
var
  L : TStringList;
begin
  L:=TStringList.Create;
  try
    L.LoadFromFile(Path);
    Result:=L.Text;
  finally
    L.Free;
  end;
end;

// The probe as it runs here: waits set to 0 (see the unit header), golden.bmp from the
// fixture folder.
function PrepareScript(const Script : String) : String;
var
  L    : TStringList;
  Cnt  : Integer;
  Line : String;
  Lead : String;
  P    : Integer;
begin
  L:=TStringList.Create;
  try
    L.Text:=Script;
    for Cnt:=0 to L.Count-1 do
    begin
      Line:=L[Cnt];
      Lead:=Copy(Line,1,Length(Line)-Length(TrimLeft(Line)));
      if LowerCase(Copy(TrimLeft(Line),1,5))='wait ' then
        L[Cnt]:=Lead+'wait 0';
      P:=Pos('#scnt + ',Line);
      if P>0 then
        L[Cnt]:=Copy(Line,1,P+7)+'0';
      L[Cnt]:=StringReplace(L[Cnt],'#curpath , golden.bmp',FixtureDir+'golden.bmp',[]);
    end;
    Result:=L.Text;
  finally
    L.Free;
  end;
end;

// A report as KEY=value parts: a new part starts at "_" followed by an upper-case key and "=".
procedure SplitReport(const S : String; Parts : TStrings);
var
  Cnt   : Integer;
  Start : Integer;
  K     : Integer;
begin
  Parts.Clear;
  Start:=1;
  for Cnt:=1 to Length(S) do
    if (S[Cnt]='_') and (Cnt<Length(S)) and (S[Cnt+1] in ['A'..'Z']) then
    begin
      K:=Cnt+1;
      while (K<=Length(S)) and (S[K] in ['A'..'Z','0'..'9']) do Inc(K);
      if (K<=Length(S)) and (S[K]='=') then
      begin
        Parts.Add(Copy(S,Start,Cnt-Start));
        Start:=Cnt+1;
      end;
    end;
  Parts.Add(Copy(S,Start,MaxInt));
end;

// Differences from 1.6 that are kept on purpose; EuoMenu16.pas's header says why.
function IsKnownDifference(const S : String) : Boolean;
const
  Known : array[0..2] of String = (
    // a panel asked for a negative width: VCL kept -10 while the panel had no window
    'validation: report A: want V24W=-10, got V24W=0',
    // 1.6's OLE picture loader lost the bitmap's last column (x 15 of 16) to HIMETRIC rounding
    'image: snap im3: 8 of 800 pixels differ 15,0:',
    'image: snap im4: 8 of 512 pixels differ 23,4:');
var
  Cnt : Integer;
begin
  for Cnt:=Low(Known) to High(Known) do
    if Copy(S,1,Length(Known[Cnt]))=Known[Cnt] then Exit(True);
  Result:=False;
end;

function Shown(const S : String) : String;
begin
  Result:=StringReplace(StringReplace(S,#13,'\r',[rfReplaceAll]),#10,'\n',[rfReplaceAll]);
end;

// Our class for each class EasyUO 1.6's windows have.
function OurClass(const VclClass : String) : String;
begin
  if VclClass='TBitBtnWithColor' then Result:='TEuoMenuButton'
  else Result:=VclClass;
end;

// The window as Windows composes it (PrintWindow, PW_RENDERFULLCONTENT), as 32-bit BGRA
// pixels, top row first.
function CaptureWindow(Wnd : HWND; out W, H : Integer; out Px : TPixels) : Boolean;
var
  WR  : TRect;
  DC  : HDC;
  MDC : HDC;
  Bmp : HBITMAP;
  Old : HGDIOBJ;
  BI  : TBitmapInfo;
begin
  GetWindowRect(Wnd,WR);
  W:=WR.Right-WR.Left;
  H:=WR.Bottom-WR.Top;
  SetLength(Px,W*H);
  DC:=GetWindowDC(Wnd);
  MDC:=CreateCompatibleDC(DC);
  Bmp:=CreateCompatibleBitmap(DC,W,H);
  Old:=SelectObject(MDC,Bmp);
  Result:=PrintWindow(Wnd,MDC,2);
  SelectObject(MDC,Old);
  FillChar(BI,SizeOf(BI),0);
  BI.bmiHeader.biSize:=SizeOf(BI.bmiHeader);
  BI.bmiHeader.biWidth:=W;
  BI.bmiHeader.biHeight:=-H;
  BI.bmiHeader.biPlanes:=1;
  BI.bmiHeader.biBitCount:=32;
  BI.bmiHeader.biCompression:=BI_RGB;
  if Result and (W*H>0) then
    Result:=GetDIBits(MDC,Bmp,0,H,@Px[0],BI,DIB_RGB_COLORS)=H;
  DeleteObject(Bmp);
  DeleteDC(MDC);
  ReleaseDC(Wnd,DC);
end;

// Captures repeated until two in a row agree: a window just shown is not composed at once.
function StableCapture(Wnd : HWND; out W, H : Integer; out Px : TPixels) : Boolean;
var
  Cnt  : Integer;
  Prev : TPixels;
begin
  Prev:=nil;
  for Cnt:=1 to 20 do
  begin
    Application.ProcessMessages;
    Sleep(100);
    if not CaptureWindow(Wnd,W,H,Px) then Continue;
    if (Length(Prev)=Length(Px)) and (Length(Px)>0) and
       CompareMem(@Prev[0],@Px[0],Length(Px)*SizeOf(Cardinal)) then Exit(True);
    Prev:=Copy(Px);
  end;
  Result:=False;
end;

function PixelColor(P : Cardinal) : TColor;
begin
  Result:=TColor(((P shr 16) and $FF) or (P and $FF00) or ((P and $FF) shl 16));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenu16GoldenTests.SetUp;
begin
  Application.Initialize;   // console runner never does; registers the window classes
  Diffs:=TStringList.Create;
  Skipped:=TStringList.Create;
  Interp:=nil;
end;

procedure TEuoMenu16GoldenTests.TearDown;
begin
  Interp.Free;
  Application.ProcessMessages;
  Diffs.Free;
  Skipped.Free;
end;

procedure TEuoMenu16GoldenTests.Note(const S : String);
begin
  Diffs.Add(Probe+': '+S);
end;

////////////////////////////////////////////////////////////////////////////////
function TEuoMenu16GoldenTests.FindForm(const Prefix : String) : TEuoMenuForm;
var
  Cnt : Integer;
  F   : TCustomForm;
begin
  for Cnt:=0 to Screen.CustomFormCount-1 do
  begin
    F:=Screen.CustomForms[Cnt];
    if (F is TEuoMenuForm) and F.HandleAllocated and (Copy(F.Caption,1,Length(Prefix))=Prefix) then
      Exit(TEuoMenuForm(F));
  end;
  Result:=nil;
end;

function TEuoMenu16GoldenTests.PlayUntilReport(const Tag : String; out Report : String) : Boolean;
var
  Cnt : Integer;
  F   : TEuoMenuForm;
begin
  for Cnt:=0 to 200000 do
  begin
    F:=FindForm('R:'+Tag+':');
    if F<>nil then
    begin
      Report:=Copy(F.Caption,Length(Tag)+4,MaxInt);
      Exit(True);
    end;
    if (Interp.ResInt=RES_STOP) or (Interp.ResInt=RES_CLOSE) then Break;
    Interp.PlayLine;
  end;
  Report:='';
  Result:=False;
end;

procedure TEuoMenu16GoldenTests.CompareReport(const Tag, Want, Got : String);
var
  W, G : TStringList;
  Cnt  : Integer;
begin
  if Want=Got then Exit;
  W:=TStringList.Create;
  G:=TStringList.Create;
  try
    SplitReport(Want,W);
    SplitReport(Got,G);
    for Cnt:=0 to W.Count-1 do
      if Cnt>=G.Count then
        Note('report '+Tag+': missing '+Shown(W[Cnt]))
      else if W[Cnt]<>G[Cnt] then
        Note('report '+Tag+': want '+Shown(W[Cnt])+', got '+Shown(G[Cnt]));
    for Cnt:=W.Count to G.Count-1 do
      Note('report '+Tag+': extra '+Shown(G[Cnt]));
  finally
    W.Free;
    G.Free;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenu16GoldenTests.Click(const Caption : String);

  function Walk(Box : TWinControl) : TEuoMenuButton;
  var
    Cnt : Integer;
    C   : TControl;
  begin
    for Cnt:=0 to Box.ControlCount-1 do
    begin
      C:=Box.Controls[Cnt];
      if (C is TEuoMenuButton) and (C.Caption=Caption) then Exit(TEuoMenuButton(C));
      if C is TWinControl then
      begin
        Result:=Walk(TWinControl(C));
        if Result<>nil then Exit;
      end;
    end;
    Result:=nil;
  end;

var
  Cnt : Integer;
  B   : TEuoMenuButton;
begin
  for Cnt:=0 to Screen.CustomFormCount-1 do
    if Screen.CustomForms[Cnt] is TEuoMenuForm then
    begin
      B:=Walk(Screen.CustomForms[Cnt]);
      if B<>nil then
      begin
        if Assigned(B.OnClick) then B.OnClick(B);
        Exit;
      end;
    end;
  Note('click: no button "'+Caption+'"');
end;

procedure TEuoMenu16GoldenTests.CloseForm(const Prefix : String);
var
  F : TEuoMenuForm;
begin
  F:=FindForm(Prefix);
  if F=nil then
  begin
    Note('close: no form "'+Prefix+'"');
    Exit;
  end;
  SendMessage(F.Handle,WM_CLOSE,0,0);
  Application.ProcessMessages;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenu16GoldenTests.CompareForms(Want : TJSONArray);
var
  Ours  : TList;
  Cnt   : Integer;
  Cnt2  : Integer;
  WF    : TJSONObject;
  F     : TEuoMenuForm;
  Cap   : String;
  Where : String;
  WR    : TRect;
  CR    : TRect;

  procedure Check(const What : String; WantV, GotV : Integer);
  begin
    if WantV<>GotV then
      Note(Where+' '+What+': want '+IntToStr(WantV)+', got '+IntToStr(GotV));
  end;

begin
  Application.ProcessMessages;
  Ours:=TList.Create;
  try
    for Cnt:=0 to Screen.CustomFormCount-1 do
      if (Screen.CustomForms[Cnt] is TEuoMenuForm) and Screen.CustomForms[Cnt].HandleAllocated then
        Ours.Add(Screen.CustomForms[Cnt]);
    if Ours.Count<>Want.Count then
      Note('forms: want '+IntToStr(Want.Count)+', got '+IntToStr(Ours.Count));

    for Cnt:=0 to Want.Count-1 do
    begin
      WF:=Want.Objects[Cnt];
      Cap:=WF.Strings['caption'];
      Where:='form "'+Shown(Copy(Cap,1,30))+'"';
      F:=nil;
      for Cnt2:=0 to Ours.Count-1 do
        if (TEuoMenuForm(Ours[Cnt2]).Caption=Cap) and
           (TEuoMenuForm(Ours[Cnt2]).Left=WF.Integers['left']) then
        begin
          F:=TEuoMenuForm(Ours[Cnt2]);
          Break;
        end;
      if F=nil then
        for Cnt2:=0 to Ours.Count-1 do
          if TEuoMenuForm(Ours[Cnt2]).Caption=Cap then
          begin
            F:=TEuoMenuForm(Ours[Cnt2]);
            Break;
          end;
      if F=nil then
      begin
        Note(Where+': missing');
        Continue;
      end;
      Ours.Remove(F);

      if WF.Booleans['visible']<>IsWindowVisible(F.Handle) then
        Note(Where+' visible: want '+BoolToStr(WF.Booleans['visible'],True));
      if IsWindowVisible(F.Handle) then
      begin
        // the window as Windows has it (LCL's Width/Height of a form are its client size)
        GetWindowRect(F.Handle,WR);
        Windows.GetClientRect(F.Handle,CR);
        Check('left',WF.Integers['left'],WR.Left);
        Check('top',WF.Integers['top'],WR.Top);
        Check('width',WF.Integers['width'],WR.Right-WR.Left);
        Check('height',WF.Integers['height'],WR.Bottom-WR.Top);
        Check('client width',WF.Arrays['client'].Integers[0],CR.Right);
        Check('client height',WF.Arrays['client'].Integers[1],CR.Bottom);
      end
      else
      begin
        // LCL moves and sizes a hidden window only when it is shown: compare what it will be
        Check('left',WF.Integers['left'],F.Left);
        Check('top',WF.Integers['top'],F.Top);
        Check('client width',WF.Arrays['client'].Integers[0],F.ClientWidth);
        Check('client height',WF.Arrays['client'].Integers[1],F.ClientHeight);
      end;
      if WF.Booleans['visible'] then
        CompareChildren(Where,WF.Arrays['children'],F.Surface);
    end;

    for Cnt:=0 to Ours.Count-1 do
      Note('form "'+Shown(TEuoMenuForm(Ours[Cnt]).Caption)+'": not in the recording');
  finally
    Ours.Free;
  end;
end;

// The child windows of a shown form, matched by class and position. Labels and images are
// not windows, in VCL or here, so they are not in the list.
procedure TEuoMenu16GoldenTests.CompareChildren(const Where : String; Want : TJSONArray;
  Box : TWinControl);
var
  Cnt   : Integer;
  Cnt2  : Integer;
  WC    : TJSONObject;
  R     : TJSONArray;
  C     : TWinControl;
  Found : TWinControl;
  Cls   : String;
  Here  : String;
  Slack : Integer;
  Text  : String;
  Style : Cardinal;
begin
  for Cnt:=0 to Want.Count-1 do
  begin
    WC:=Want.Objects[Cnt];
    R:=WC.Arrays['rect'];
    Cls:=OurClass(WC.Strings['class']);
    Here:=Where+' '+Cls+' at '+IntToStr(R.Integers[0])+','+IntToStr(R.Integers[1]);
    Found:=nil;
    for Cnt2:=0 to Box.ControlCount-1 do
      if Box.Controls[Cnt2] is TWinControl then
      begin
        C:=TWinControl(Box.Controls[Cnt2]);
        if (C.ClassName=Cls) and (C.Left=R.Integers[0]) and (C.Top=R.Integers[1]) then
        begin
          Found:=C;
          Break;
        end;
      end;
    if Found=nil then
    begin
      Note(Here+': missing');
      Continue;
    end;

    if (Found is TEdit) or (Found is TComboBox) then Slack:=4 else Slack:=0;
    if Found.Width<>R.Integers[2] then
      Note(Here+' width: want '+IntToStr(R.Integers[2])+', got '+IntToStr(Found.Width));
    if Abs(Found.Height-R.Integers[3])>Slack then
      Note(Here+' height: want '+IntToStr(R.Integers[3])+', got '+IntToStr(Found.Height));
    if WC.Booleans['visible']<>Found.Visible then
      Note(Here+' visible: want '+BoolToStr(WC.Booleans['visible'],True));

    if Found is TEdit then Text:=TEdit(Found).Text
    else if (Found is TComboBox) or (Found is TListBox) or (Found is TPanel) then Text:=WC.Strings['text']
    else Text:=Found.Caption;
    if Text<>WC.Strings['text'] then
      Note(Here+' text: want "'+Shown(WC.Strings['text'])+'", got "'+Shown(Text)+'"');

    if (Found is TCheckBox) or (Found is TRadioButton) then
    begin
      Style:=Cardinal(StrToInt('$'+WC.Strings['style']));
      if ((Style and BS_LEFTTEXT)<>0)<>(TCustomCheckBox(Found).Alignment=taLeftJustify) then
        Note(Here+': text on the wrong side');
    end;

    if WC.Find('children')<>nil then
      CompareChildren(Here,WC.Arrays['children'],Found);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenu16GoldenTests.CompareSnap(Ev : TJSONObject);
var
  Args   : TJSONArray;
  F      : TEuoMenuForm;
  X, Y   : Integer;
  W, H   : Integer;
  WW, WH : Integer;
  Px     : TPixels;
  Png    : TPortableNetworkGraphic;
  WR     : TRect;
  Org    : TPoint;
  CX, CY : Integer;
  Bad    : Integer;
  First  : String;
  Want   : TColor;
  Got    : TColor;
begin
  Args:=Ev.Arrays['args'];
  F:=FindForm(Args.Strings[0]);
  if (F=nil) or not IsWindowVisible(F.Handle) or not StableCapture(F.Handle,WW,WH,Px) then
  begin
    Skipped.Add('snap '+Args.Strings[1]);
    Exit;
  end;
  X:=StrToInt(Args.Strings[2]);
  Y:=StrToInt(Args.Strings[3]);
  W:=StrToInt(Args.Strings[4]);
  H:=StrToInt(Args.Strings[5]);
  GetWindowRect(F.Handle,WR);
  Org:=Point(0,0);
  Windows.ClientToScreen(F.Handle,Org);
  X:=X+Org.X-WR.Left;
  Y:=Y+Org.Y-WR.Top;

  Png:=TPortableNetworkGraphic.Create;
  try
    Png.LoadFromFile(FixtureDir+Ev.Strings['file']);
    Bad:=0;
    First:='';
    for CY:=0 to H-1 do
      for CX:=0 to W-1 do
      begin
        Want:=ColorToRGB(Png.Canvas.Pixels[CX,CY]);
        Got:=PixelColor(Px[(Y+CY)*WW+X+CX]);
        if Want<>Got then
        begin
          Inc(Bad);
          if Bad<=6 then
            First:=First+Format(' %d,%d: want %.6x, got %.6x;',[CX,CY,Want,Got]);
        end;
      end;
    if Bad>0 then
      Note('snap '+Args.Strings[1]+': '+IntToStr(Bad)+' of '+IntToStr(W*H)+' pixels differ'+First);
  finally
    Png.Free;
  end;
end;

procedure TEuoMenu16GoldenTests.CompareAlpha(Ev : TJSONObject);
var
  F : TEuoMenuForm;
begin
  F:=FindForm(Ev.Arrays['args'].Strings[0]);
  if F=nil then
  begin
    Note('alpha: no form');
    Exit;
  end;
  if Ev.Booleans['layered']<>F.AlphaBlend then
    Note('alpha: layered want '+BoolToStr(Ev.Booleans['layered'],True));
  if (Ev.Find('alpha')<>nil) and (Ev.Integers['alpha']<>F.AlphaBlendValue) then
    Note('alpha: want '+IntToStr(Ev.Integers['alpha'])+', got '+IntToStr(F.AlphaBlendValue));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenu16GoldenTests.Replay(const Name : String);
var
  Doc    : TJSONData;
  Events : TJSONArray;
  Ev     : TJSONObject;
  Cnt    : Integer;
  Step   : String;
  Args   : String;
  Report : String;
  A      : TJSONArray;
  Cnt2   : Integer;
begin
  Probe:=Name;
  A:=nil;
  Doc:=GetJSON(ReadText(FixtureDir+Name+'.json'));
  try
    Interp:=TEuoInterpreter.Create(0);
    Interp.ScrList.Scr.Text:=PrepareScript(ReadText(FixtureDir+Name+'.euo'));
    Interp.Clear;
    Interp.NextLine:=0;
    AssertTrue(Name+' runs under the 1.6 logic',Interp.MenuLogic=mlMenu16);
    if FindForm('EUO Menu')=nil then
    begin
      Ignore('MENU windows cannot be created in this session');
      Exit;
    end;

    Events:=TJSONObject(Doc).Arrays['events'];
    for Cnt:=0 to Events.Count-1 do
    begin
      Ev:=Events.Objects[Cnt];
      Step:=Ev.Strings['step'];
      Args:='';
      if Ev.Find('args')<>nil then
      begin
        A:=Ev.Arrays['args'];
        for Cnt2:=0 to A.Count-1 do
          Args:=Trim(Args+' '+A.Strings[Cnt2]);
      end;

      if (Step='wait') or (Step='rewait') then
      begin
        if not PlayUntilReport(A.Strings[0],Report) then
          Note('report '+A.Strings[0]+' never came')
        else CompareReport(A.Strings[0],Ev.Strings['report'],Report);
      end
      else if Step='click' then Click(Args)
      else if Step='close' then CloseForm(Args)
      else if Step='forms' then CompareForms(Ev.Arrays['forms'])
      else if Step='snap' then CompareSnap(Ev)
      else if Step='alpha' then CompareAlpha(Ev)
      else if Step='start' then
      begin
        Interp.Clear;   // what Play does to a stopped script
        Interp.NextLine:=0;
      end;
      // stop and sleep: the script is not running between steps anyway
    end;
  finally
    Doc.Free;
  end;

  for Cnt:=Diffs.Count-1 downto 0 do
    if IsKnownDifference(Diffs[Cnt]) then Diffs.Delete(Cnt);
  if Diffs.Count>0 then Fail(Diffs.Text);
  if Skipped.Count>0 then Ignore(Name+': could not capture '+Skipped.CommaText);
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoMenu16GoldenTests.TestAlign;         begin Replay('align'); end;
procedure TEuoMenu16GoldenTests.TestClose;         begin Replay('close'); end;
procedure TEuoMenu16GoldenTests.TestDefaults;      begin Replay('defaults'); end;
procedure TEuoMenu16GoldenTests.TestDefaultsStack; begin Replay('defaults_stack'); end;
procedure TEuoMenu16GoldenTests.TestDelete;        begin Replay('delete'); end;
procedure TEuoMenu16GoldenTests.TestDeleteForm0;   begin Replay('delete_form0'); end;
procedure TEuoMenu16GoldenTests.TestDuplicates;    begin Replay('duplicates'); end;
procedure TEuoMenu16GoldenTests.TestFont;          begin Replay('font'); end;
procedure TEuoMenu16GoldenTests.TestForms;         begin Replay('forms'); end;
procedure TEuoMenu16GoldenTests.TestGetSet;        begin Replay('get_set'); end;
procedure TEuoMenu16GoldenTests.TestHideClear;     begin Replay('hide_clear'); end;
procedure TEuoMenu16GoldenTests.TestImage;         begin Replay('image'); end;
procedure TEuoMenu16GoldenTests.TestNames;         begin Replay('names'); end;
procedure TEuoMenu16GoldenTests.TestPanelsRadio;   begin Replay('panels_radio'); end;
procedure TEuoMenu16GoldenTests.TestParent;        begin Replay('parent'); end;
procedure TEuoMenu16GoldenTests.TestPopup;         begin Replay('popup'); end;
procedure TEuoMenu16GoldenTests.TestPropsGet;      begin Replay('props_get'); end;
procedure TEuoMenu16GoldenTests.TestPropsSet;      begin Replay('props_set'); end;
procedure TEuoMenu16GoldenTests.TestRestart;       begin Replay('restart'); end;
procedure TEuoMenu16GoldenTests.TestShapes;        begin Replay('shapes'); end;
procedure TEuoMenu16GoldenTests.TestStale;         begin Replay('stale'); end;
procedure TEuoMenu16GoldenTests.TestValidation;    begin Replay('validation'); end;
procedure TEuoMenu16GoldenTests.TestWindow;        begin Replay('window'); end;

////////////////////////////////////////////////////////////////////////////////
initialization
  RegisterTest(TEuoMenu16GoldenTests);
end.
