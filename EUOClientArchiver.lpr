program EUOClientArchiver;

{
  Port addition: a developer tool, not shipped in the release zip. It archives client.exe and
  client_beta.exe, each renamed to carry its version inside its own ZIP, before the UO patcher
  overwrites them (page: website/src/content/docs/developers/archiving-clients.md). The logic is
  in tools\EUOClientArchiver\caarchive.pas, which the test suite calls directly; this program
  only opens the window. `Interfaces` must be the first unit in an LCL program's uses clause.
  The executable carries EasyUO Reforged's own icon (easyuo\appicon.res), which the LCL also
  uses for the window.
}

{$mode delphi}{$H+}
{$apptype GUI}

{$R easyuo\appicon.res}

uses
  Interfaces,
  Forms,
  camain in 'tools\EUOClientArchiver\camain.pas' {CaMainForm};

begin
  Application.Initialize;
  Application.CreateForm(TCaMainForm, CaMainForm);
  Application.Run;
end.
