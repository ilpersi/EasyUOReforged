unit euoutput;

{
  Port addition (the LOG command, docs\agent-support.md phase 3): the text of the editor's
  Output panel, which shows what running scripts log. Two pure functions, apart from main.pas
  so they can be tested: what one line looks like, and how the panel's text stays bounded.

  The panel is one for the whole window. Every tab's lines go into it in the order they
  arrive, each with the time; when more than one tab is open, each also names its tab.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils;

const
  // The panel keeps this many lines; older ones go as new ones come.
  OUTPUT_MAX_LINES = 5000;

// One line of the panel: "14:03:09  text", or "14:03:09  tab: text" when ShowTab.
function EuoOutputLine(Time : TDateTime; const Tab, Text : String; ShowTab : Boolean) : String;

// Appends NewLines to Dest, then drops the oldest lines until at most MaxLines are left.
procedure EuoAppendOutput(Dest, NewLines : TStrings; MaxLines : Integer = OUTPUT_MAX_LINES);

implementation

////////////////////////////////////////////////////////////////////////////////
function EuoOutputLine(Time : TDateTime; const Tab, Text : String; ShowTab : Boolean) : String;
begin
  Result:=FormatDateTime('hh":"nn":"ss',Time)+'  ';
  if ShowTab then Result:=Result+Tab+': ';
  Result:=Result+Text;
end;

////////////////////////////////////////////////////////////////////////////////
procedure EuoAppendOutput(Dest, NewLines : TStrings; MaxLines : Integer);
var
  Drop, i : Integer;
begin
  if NewLines.Count=0 then Exit;
  Dest.BeginUpdate;
  try
    // More new lines than the panel holds: only the newest of them matter.
    if NewLines.Count>=MaxLines then
    begin
      Dest.Clear;
      for i:=NewLines.Count-MaxLines to NewLines.Count-1 do Dest.Add(NewLines[i]);
      Exit;
    end;
    Drop:=Dest.Count+NewLines.Count-MaxLines;
    for i:=1 to Drop do Dest.Delete(0);
    Dest.AddStrings(NewLines);
  finally
    Dest.EndUpdate;
  end;
end;

end.
