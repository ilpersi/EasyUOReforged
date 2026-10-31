unit scriptfile;

{
  Port addition: how the editor reads a script file, moved verbatim out of insthandler.pas so
  that the MENU designer (tools/EUOMenuDesigner) reads .euo files the same way, with the same
  code (docs/menu-designer.md, section 3.2). It has no GUI dependency.
}

{$mode delphi}{$H+}

interface
uses SysUtils, Classes, LazUTF8, LConvEncoding;

function LoadScriptFileAsUTF8(const FN : String) : String;

implementation

////////////////////////////////////////////////////////////////////////////////
// Added during this migration -- not needed by the original VCL/Delphi 7 app,
// which read script files as raw ANSI bytes throughout (matching how they
// were almost certainly authored: this tool predates UTF-8 becoming the
// default save encoding in most text editors). LCL's SynEdit renders text as
// Unicode and expects well-formed UTF-8 from Lines; a script file containing
// a raw high-byte ANSI/CP1252 character (e.g. one selecting a Wingdings icon
// glyph by character code -- confirmed live: the character a real script
// used was byte $D1, not valid UTF-8 on its own) never displays at all,
// because that lone invalid byte doesn't form a valid UTF-8 character for
// SynEdit's Unicode-aware paint/character-boundary logic to render.
//
// Reads the file's raw bytes and only converts them (CP1252->UTF-8) if
// they're NOT already valid UTF-8, so an already-UTF-8 script (or a plain
// old all-ASCII one, valid UTF-8 by definition) passes through completely
// unchanged. This keeps SynEdit.Lines always holding well-formed UTF-8,
// letting it render any character in the source correctly regardless of
// which encoding the file was actually saved in.
function LoadScriptFileAsUTF8(const FN : String) : String;
var
  FS : TFileStream;
begin
  FS:=TFileStream.Create(FN,fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result,FS.Size);
    if FS.Size>0 then
      FS.ReadBuffer(Result[1],FS.Size);
  finally
    FS.Free;
  end;

  if FindInvalidUTF8Codepoint(PChar(Result),Length(Result))>=0 then
    Result:=CP1252ToUTF8(Result);
end;

end.
