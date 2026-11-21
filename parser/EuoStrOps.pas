unit EuoStrOps;

{
  Port addition (STR REPLACE, PART, TRIM): the text work of these operations, with no interpreter.
  TEuoInterpreter.StrProc gives them their words and puts the result in #StrRes.

  All three ignore case when matching, as STR POS, STR COUNT and the IN operator do, and return the
  original case of the text. UpperCase is ASCII-only and keeps the length, so a position in the
  uppercased copy is the same position in the text. A '_' doesn't match a real space, also as they
  do (#Journal reads spaces as '_', #Property holds real ones).

  - StrReplaceAll: every occurrence, left to right, not overlapping, the scan STR COUNT does. The
    replacement is never scanned, so it may contain the search text. An empty search finds nothing,
    as Pos does for STR POS and STR COUNT.
  - StrField: the N-th field between separators, counting from 1, or STR_NO_FIELD when there is no
    such field. A separator at either end or a doubled one makes an empty field, so a text always
    has STR COUNT + 1 fields. An empty separator finds nothing, so the text is its only field.
  - StrTrimChars: Text without any character of Chars at either end. Empty Chars strips nothing.

  Port addition (STR URLENCODE, JSONESCAPE), for the data SEND's new forms carry. Both work on bytes,
  so a UTF-8 text stays UTF-8, and neither cares about case:
  - StrUrlEncode: RFC 3986. The unreserved characters (A-Z a-z 0-9 - _ . ~) stay, every other byte
    becomes %XX (upper-case hex), a space too (%20, which both a query and form data read as a space).
  - StrJsonEscape: the text as it goes between the quotes of a JSON string: " and \ escaped, the
    control characters as \b \t \n \f \r or \u00XX, every other byte left alone.
}

{$mode delphi}{$H+}

interface

uses
  SysUtils, StrUtils;

const
  STR_NO_FIELD     = 'N/A';
  STR_TRIM_DEFAULT = ' _';  // text holds real spaces (#Property) or '_' for them (#Journal)

function StrReplaceAll(const Text, Search, Repl : String) : String;
function StrField(const Text, Sep : String; N : Int64) : String;
function StrTrimChars(const Text, Chars : String) : String;
function StrUrlEncode(const Text : String) : String;
function StrJsonEscape(const Text : String) : String;

implementation

////////////////////////////////////////////////////////////////////////////////
function StrReplaceAll(const Text, Search, Repl : String) : String;
var
  TextU   : String;
  SearchU : String;
  From    : Integer;
  At      : Integer;
begin
  Result:=Text;
  if Search='' then Exit;

  TextU:=UpperCase(Text);
  SearchU:=UpperCase(Search);

  Result:='';
  From:=1;
  repeat
    At:=PosEx(SearchU,TextU,From);
    if At<1 then Break;
    Result:=Result+Copy(Text,From,At-From)+Repl;
    From:=At+Length(SearchU);
  until False;
  Result:=Result+Copy(Text,From,MaxInt);
end;

////////////////////////////////////////////////////////////////////////////////
function StrField(const Text, Sep : String; N : Int64) : String;
var
  TextU : String;
  SepU  : String;
  From  : Integer;
  At    : Integer;
  Field : Int64;
begin
  Result:=STR_NO_FIELD;
  if N<1 then Exit;

  if Sep='' then
  begin
    if N=1 then Result:=Text;
    Exit;
  end;

  TextU:=UpperCase(Text);
  SepU:=UpperCase(Sep);

  From:=1;
  Field:=1;
  repeat
    At:=PosEx(SepU,TextU,From);
    if Field=N then
    begin
      if At<1 then Result:=Copy(Text,From,MaxInt)
      else Result:=Copy(Text,From,At-From);
      Exit;
    end;
    if At<1 then Exit;
    From:=At+Length(SepU);
    Inc(Field);
  until False;
end;

////////////////////////////////////////////////////////////////////////////////
function StrTrimChars(const Text, Chars : String) : String;
var
  TextU  : String;
  CharsU : String;
  First  : Integer;
  Last   : Integer;
begin
  TextU:=UpperCase(Text);
  CharsU:=UpperCase(Chars);

  First:=1;
  Last:=Length(Text);
  while (First<=Last) and (Pos(TextU[First],CharsU)>0) do Inc(First);
  while (Last>=First) and (Pos(TextU[Last],CharsU)>0) do Dec(Last);

  Result:=Copy(Text,First,Last-First+1);
end;

////////////////////////////////////////////////////////////////////////////////
function StrUrlEncode(const Text : String) : String;
const
  Hex : array[0..15] of Char = '0123456789ABCDEF';
var
  i : Integer;
  B : Byte;
begin
  Result:='';
  for i:=1 to Length(Text) do
  begin
    B:=Ord(Text[i]);
    if Chr(B) in ['A'..'Z','a'..'z','0'..'9','-','_','.','~'] then Result:=Result+Chr(B)
    else Result:=Result+'%'+Hex[B shr 4]+Hex[B and 15];
  end;
end;

////////////////////////////////////////////////////////////////////////////////
function StrJsonEscape(const Text : String) : String;
const
  Hex : array[0..15] of Char = '0123456789abcdef';
var
  i : Integer;
  C : Char;
begin
  Result:='';
  for i:=1 to Length(Text) do
  begin
    C:=Text[i];
    case C of
      '"' : Result:=Result+'\"';
      '\' : Result:=Result+'\\';
      #8  : Result:=Result+'\b';
      #9  : Result:=Result+'\t';
      #10 : Result:=Result+'\n';
      #12 : Result:=Result+'\f';
      #13 : Result:=Result+'\r';
      #0..#7,#11,#14..#31 : Result:=Result+'\u00'+Hex[Ord(C) shr 4]+Hex[Ord(C) and 15];
    else
      Result:=Result+C;
    end;
  end;
end;

end.
