program EUOMenuDesigner;

{
  Port addition: the MENU Designer, a standalone program for laying out EasyUO MENU windows
  (the 1.6 MENU logic) and reading such scripts back. Design and rules in
  docs/menu-designer.md. `Interfaces` must be the first unit in an LCL program's uses clause.
  The executable carries EasyUO Reforged's own icon (easyuo\appicon.res).
}

{$mode delphi}{$H+}
{$apptype GUI}

{$R easyuo\appicon.res}

uses
  Interfaces,
  Forms, SysUtils, Classes,
  mdmain in 'tools\EUOMenuDesigner\mdmain.pas' {MdMainForm};

begin
  Application.Initialize;
  Application.CreateForm(TMdMainForm, MdMainForm);
  Application.Run;
end.
