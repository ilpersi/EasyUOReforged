unit EuoMenu16;

{
  Port addition: the MENU command as EasyUO 1.6 (build 1.6.0.337) implements it -- the "1.6
  logic" a script runs under when EuoMenuSelect chooses it. Its behaviour, read from the closed
  binary and checked against it at runtime, is in docs/menu-1.6-analysis.md (section 3); the
  1.5 logic stays in EuoMenu.pas.

  So far only the part the logic selection needs: #MenuButton and #MenuRes as 1.6 keeps them.
  The windows, controls, properties, defaults and the dispatcher arrive with the 1.6 port
  (docs/menu-1.6-analysis.md, section 6.10, step 4); until then MENU lines do nothing under
  this logic.

  1.6 behaviour kept here:
  - #MenuButton is stored as written, but the exact string 'form0' reads back as 'CLOSED'
    (1.6 records the name of the form whose [X] was clicked, and form0 stands for the classic
    window). The comparison is case-sensitive: 'FORM0' reads back unchanged.
  - Both variables are emptied when a stopped script starts (ScriptStart).
}

{$mode delphi}{$H+}

interface

type
  TMenu16 = class(TObject)
  private
    FMenuButton : String;
  public
    MenuRes     : String;
    procedure   ScriptStart;
    function    GetMenuButton : String;
    procedure   SetMenuButton(const Value : String);
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.ScriptStart;
begin
  FMenuButton:='';
  MenuRes:='';
end;

////////////////////////////////////////////////////////////////////////////////
function TMenu16.GetMenuButton : String;
begin
  if FMenuButton='form0' then Result:='CLOSED'
  else Result:=FMenuButton;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TMenu16.SetMenuButton(const Value : String);
begin
  FMenuButton:=Value;
end;

end.
