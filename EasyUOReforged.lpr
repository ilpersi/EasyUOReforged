program EasyUOReforged;

{
  Ported from the original Delphi 7 easyuo\EasyUO.dpr. `Interfaces` must be the
  first unit in an LCL program's uses clause -- it initializes the platform
  widget set (win32 here) before any form is created.
}

{$mode delphi}{$H+}
{$apptype GUI}

{
  Windows executable resource: the application icon (RT_GROUP_ICON "MAINICON"),
  carried over from the original easyuo\EasyUO.res. Regenerate appicon.res from
  appicon.rc / appicon.ico with fpcres if the icon ever changes:
    fpcres easyuo\appicon.rc -o easyuo\appicon.res -of res
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
