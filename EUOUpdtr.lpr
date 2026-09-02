program EUOUpdtr;

{
  Ported from the original Delphi 7 tools\EUOUpdater\EUOUpdtr.dpr.
}

{$mode delphi}{$H+}
{$apptype GUI}

uses
  Interfaces,
  Forms,
  main in 'tools\EUOUpdater\main.pas' {MainForm};

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
