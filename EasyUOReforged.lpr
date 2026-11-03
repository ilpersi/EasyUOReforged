program EasyUOReforged;

{
  Ported from the original Delphi 7 easyuo\EasyUO.dpr. `Interfaces` must be the
  first unit in an LCL program's uses clause -- it initializes the platform
  widget set (win32 here) before any form is created.
}

{$mode delphi}{$H+}
{$apptype GUI}

{
  Windows executable resource: the application icon (RT_GROUP_ICON "MAINICON").
  If the icon ever changes, easyuo\make_app_icon.py regenerates appicon.ico and
  appicon.res, and the windows' copy of it in easyuo\appicondata.pas.
}
{$R easyuo\appicon.res}

uses
  Interfaces,
  Forms, SysUtils, Classes,
  main in 'easyuo\main.pas' {MainForm},
  text in 'easyuo\text.pas' {TextForm};

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.CreateForm(TTextForm, TextForm);
  Application.Run;
end.
