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

  Port addition (STR DECIMAL, DATE, CLOCK, DATETIME, DURATION), the time and number formatting scripts
  wrote by hand. Every result is the same on every computer: nothing comes from the Windows settings.
  - StrDecimal: a whole number of hundredths, tenths, ... written with Places decimals and '.'.
  - StrDate / StrClock / StrDateTime: #Date (yymmdd) and #Time (hhmmss) values, 1 to 6 digits, padded
    with zeros on the left (SET turns 093015 into 93015), into a format. The year is 20yy.
  - StrDuration: a number of seconds into a format; a negative number gets a '-' before it.
  A format is FPC's FormatDateTime's, run with FixedSettings (English names, '/' and ':', AM/PM), after
  PrepareFormat has put every word that is not made only of the operation's token letters between quotes,
  so a script writes text without quoting it. Letters that are tokens nowhere in Reforged (c, f, t, e, g:
  the shortcuts that read Windows formats, and the East-Asian era years) are always text. Anything that
  can't be read, and any error FPC raises, gives STR_NO_FIELD.
}

{$mode delphi}{$H+}

interface

uses
  SysUtils, StrUtils, DateUtils;

const
  STR_NO_FIELD     = 'N/A';
  STR_TRIM_DEFAULT = ' _';  // text holds real spaces (#Property) or '_' for them (#Journal)

function StrReplaceAll(const Text, Search, Repl : String) : String;
function StrField(const Text, Sep : String; N : Int64) : String;
function StrTrimChars(const Text, Chars : String) : String;
function StrUrlEncode(const Text : String) : String;
function StrJsonEscape(const Text : String) : String;

const
  STR_FMT_DATE     = 'yyyy-mm-dd';
  STR_FMT_CLOCK    = 'hh:nn:ss';
  STR_FMT_DATETIME = 'yyyy-mm-dd hh:nn:ss';
  STR_FMT_DURATION = '[h]:nn:ss';
  STR_FMT_MAX      = 255;    // FormatDateTime's buffer; a result this long is not trusted

type
  TStrTimeKind = (stkDate, stkClock, stkDateTime, stkDuration);

function StrDecimal(N : Int64; Places : Int64) : String;
function StrDate(const Date, Fmt : String) : String;
function StrClock(const Time, Fmt : String) : String;
function StrDateTime(const Date, Time, Fmt : String) : String;
function StrDuration(Secs : Int64; const Fmt : String) : String;
function PrepareFormat(const Fmt : String; Kind : TStrTimeKind; out Prepared : String) : Boolean;

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

////////////////////////////////////////////////////////////////////////////////
function StrDecimal(N : Int64; Places : Int64) : String;
var
  A : QWord;
  S : String;
begin
  Result:=STR_NO_FIELD;
  if (Places<0) or (Places>18) then Exit;
  if Places=0 then
  begin
    Result:=IntToStr(N);
    Exit;
  end;
  if N<0 then A:=QWord(-(N+1))+1 else A:=N;
  S:=IntToStr(A);
  while Length(S)<=Places do S:='0'+S;
  Insert('.',S,Length(S)-Places+1);
  if N<0 then S:='-'+S;
  Result:=S;
end;

////////////////////////////////////////////////////////////////////////////////
var
  FixedSettings : TFormatSettings;

procedure InitFixedSettings;
const
  ShortMonths : array[1..12] of String = ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
  LongMonths  : array[1..12] of String = ('January','February','March','April','May','June','July',
                                          'August','September','October','November','December');
  ShortDays   : array[1..7] of String = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
  LongDays    : array[1..7] of String = ('Sunday','Monday','Tuesday','Wednesday','Thursday','Friday','Saturday');
var
  i : Integer;
begin
  FixedSettings:=DefaultFormatSettings;
  FixedSettings.DateSeparator:='/';
  FixedSettings.TimeSeparator:=':';
  FixedSettings.DecimalSeparator:='.';
  FixedSettings.ThousandSeparator:=',';
  FixedSettings.TimeAMString:='AM';
  FixedSettings.TimePMString:='PM';
  FixedSettings.ShortDateFormat:=STR_FMT_DATE;
  FixedSettings.LongDateFormat:=STR_FMT_DATE;
  FixedSettings.ShortTimeFormat:='hh:nn';
  FixedSettings.LongTimeFormat:=STR_FMT_CLOCK;
  for i:=1 to 12 do
  begin
    FixedSettings.ShortMonthNames[i]:=ShortMonths[i];
    FixedSettings.LongMonthNames[i]:=LongMonths[i];
  end;
  for i:=1 to 7 do
  begin
    FixedSettings.ShortDayNames[i]:=ShortDays[i];
    FixedSettings.LongDayNames[i]:=LongDays[i];
  end;
end;

////////////////////////////////////////////////////////////////////////////////
// Fmt with every word (a run of letters) that is not made only of Kind's token letters put between
// double quotes, so FormatDateTime prints it as written. Quoted text, digits, spaces and punctuation stay
// as they are; an unclosed quote is closed. The am/pm words are kept for the kinds with an hour of day.
// In a clock or a duration m means minutes, so it is written n. False for a run of five or more d's
// (FPC's shortcuts for the Windows date formats).
function PrepareFormat(const Fmt : String; Kind : TStrTimeKind; out Prepared : String) : Boolean;
var
  Tokens : String;
  i, j   : Integer;
  k      : Integer;
  W, WL  : String;
  Q      : Char;
  AmPm   : Boolean;
  IsTok  : Boolean;
begin
  Result:=False;
  Prepared:='';
  case Kind of
    stkDate     : Tokens:='dmy';
    stkClock    : Tokens:='hnszm';
    stkDateTime : Tokens:='dmyhnsz';
  else            Tokens:='hnszm';
  end;
  AmPm:=Kind in [stkClock,stkDateTime];

  i:=1;
  while i<=Length(Fmt) do
  begin
    if Fmt[i] in ['''','"'] then
    begin
      Q:=Fmt[i];
      j:=i+1;
      while (j<=Length(Fmt)) and (Fmt[j]<>Q) do Inc(j);
      if j>Length(Fmt) then Prepared:=Prepared+Copy(Fmt,i,MaxInt)+Q
      else Prepared:=Prepared+Copy(Fmt,i,j-i+1);
      i:=j+1;
      Continue;
    end;

    if Fmt[i] in ['A'..'Z','a'..'z'] then
    begin
      if AmPm and AnsiStartsText('am/pm',Copy(Fmt,i,5)) then
      begin
        Prepared:=Prepared+Copy(Fmt,i,5);
        Inc(i,5);
        Continue;
      end;
      if AmPm and AnsiStartsText('a/p',Copy(Fmt,i,3)) then
      begin
        Prepared:=Prepared+Copy(Fmt,i,3);
        Inc(i,3);
        Continue;
      end;
      // A word ends where am/pm or a/p starts (h:nnam/pm), as FPC reads it.
      j:=i;
      while (j<=Length(Fmt)) and (Fmt[j] in ['A'..'Z','a'..'z']) do
      begin
        if (j>i) and AmPm and (AnsiStartsText('am/pm',Copy(Fmt,j,5)) or AnsiStartsText('a/p',Copy(Fmt,j,3))) then
          Break;
        Inc(j);
      end;
      W:=Copy(Fmt,i,j-i);
      WL:=LowerCase(W);
      i:=j;

      if AmPm and (WL='ampm') then
      begin
        Prepared:=Prepared+W;
        Continue;
      end;
      IsTok:=True;
      for k:=1 to Length(WL) do
        if Pos(WL[k],Tokens)=0 then IsTok:=False;
      if not IsTok then
      begin
        Prepared:=Prepared+'"'+W+'"';
        Continue;
      end;
      if Pos('ddddd',WL)>0 then Exit;
      if Kind in [stkClock,stkDuration] then
        W:=StringReplace(StringReplace(W,'m','n',[rfReplaceAll]),'M','N',[rfReplaceAll]);
      Prepared:=Prepared+W;
      Continue;
    end;

    Prepared:=Prepared+Fmt[i];
    Inc(i);
  end;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
// A #Date / #Time value: 1 to 6 digits, padded with zeros on the left, as three pairs.
function SplitSix(const V : String; out A, B, C : Word) : Boolean;
var
  S : String;
  i : Integer;
begin
  Result:=False;
  A:=0; B:=0; C:=0;
  if (Length(V)<1) or (Length(V)>6) then Exit;
  for i:=1 to Length(V) do
    if not (V[i] in ['0'..'9']) then Exit;
  S:=StringOfChar('0',6-Length(V))+V;
  A:=StrToInt(Copy(S,1,2));
  B:=StrToInt(Copy(S,3,2));
  C:=StrToInt(Copy(S,5,2));
  Result:=True;
end;

function FormatWith(const Fmt, Default : String; Kind : TStrTimeKind; DT : TDateTime) : String;
var
  F, P : String;
  Opts : TFormatDateTimeOptions;
begin
  Result:=STR_NO_FIELD;
  F:=Fmt;
  if Trim(F)='' then F:=Default;
  if not PrepareFormat(F,Kind,P) then Exit;
  Opts:=[];
  if Kind=stkDuration then Opts:=[fdoInterval];
  try
    Result:=FormatDateTime(P,DT,FixedSettings,Opts);
  except
    on Exception do Result:=STR_NO_FIELD;
  end;
  // FPC stops writing at 255 characters without saying so: a result that long may be cut short.
  if Length(Result)>=STR_FMT_MAX then Result:=STR_NO_FIELD;
end;

function DateOf6(const Date : String; out DT : TDateTime) : Boolean;
var
  Y, M, D : Word;
begin
  Result:=SplitSix(Date,Y,M,D) and TryEncodeDate(2000+Y,M,D,DT);
end;

function TimeOf6(const Time : String; out DT : TDateTime) : Boolean;
var
  H, N, S : Word;
begin
  Result:=SplitSix(Time,H,N,S) and TryEncodeTime(H,N,S,0,DT);
end;

////////////////////////////////////////////////////////////////////////////////
function StrDate(const Date, Fmt : String) : String;
var
  DT : TDateTime;
begin
  Result:=STR_NO_FIELD;
  if DateOf6(Date,DT) then Result:=FormatWith(Fmt,STR_FMT_DATE,stkDate,DT);
end;

function StrClock(const Time, Fmt : String) : String;
var
  DT : TDateTime;
begin
  Result:=STR_NO_FIELD;
  if TimeOf6(Time,DT) then Result:=FormatWith(Fmt,STR_FMT_CLOCK,stkClock,DT);
end;

function StrDateTime(const Date, Time, Fmt : String) : String;
var
  D, T : TDateTime;
begin
  Result:=STR_NO_FIELD;
  if DateOf6(Date,D) and TimeOf6(Time,T) then
    Result:=FormatWith(Fmt,STR_FMT_DATETIME,stkDateTime,ComposeDateTime(D,T));
end;

// FPC writes the totals [h] [n] [s] as a 32-bit Integer, so a duration stops at High(Integer) seconds
// (68 years); beyond that the answer is STR_NO_FIELD rather than a wrapped number.
function StrDuration(Secs : Int64; const Fmt : String) : String;
var
  A    : QWord;
  Days : QWord;
  Rest : QWord;
  DT   : TDateTime;
begin
  Result:=STR_NO_FIELD;
  if Secs<0 then A:=QWord(-(Secs+1))+1 else A:=Secs;
  if A>QWord(High(Integer)) then Exit;
  Days:=A div 86400;
  Rest:=A mod 86400;
  DT:=Days+EncodeTime(Rest div 3600,(Rest div 60) mod 60,Rest mod 60,0);
  Result:=FormatWith(Fmt,STR_FMT_DURATION,stkDuration,DT);
  if (Secs<0) and (Result<>STR_NO_FIELD) then Result:='-'+Result;
end;

initialization
  InitFixedSettings;
end.
