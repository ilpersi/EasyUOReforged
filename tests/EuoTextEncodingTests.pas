unit EuoTextEncodingTests;

{
  Tests for parser\EuoTextEncoding.pas: the conversions at the interpreter's edges (client text
  in as UTF-8, script text out as Latin-1, script files and stdin read as UTF-8) and the letters
  STR counts. The letter routines must give, on text with one byte per letter, exactly what the
  RTL routines STR used before (Copy, Delete, Insert, Pos): TestLettersMatchTheRtlOnOneByteText
  checks that on every short text over a small alphabet, both converted to UTF-8 (client text)
  and as raw bytes that are not UTF-8.
}

{$mode delphi}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, EuoTextEncoding;

type
  TEuoTextEncodingTests = class(TTestCase)
  published
    procedure TestLatin1ToUtf8;
    procedure TestUtf8ToLatin1;
    procedure TestLatin1RoundTripsEveryByte;
    procedure TestScriptTextToUtf8;
    procedure TestUtf8SeqLenIsStrict;
    procedure TestLetterCount;
    procedure TestLetterRoutinesOnUtf8;
    procedure TestLetterPosNeedsWholeLetters;
    procedure TestLettersMatchTheRtlOnOneByteText;
  end;

implementation

////////////////////////////////////////////////////////////////////////////////
// The bytes of S in hex, "C3 A8": compared as text, so no code page conversion can hide a byte.
function HexOf(const S : String) : String;
var
  i : Integer;
begin
  Result:='';
  for i:=1 to Length(S) do
  begin
    if i>1 then Result:=Result+' ';
    Result:=Result+IntToHex(Byte(S[i]),2);
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoTextEncodingTests.TestLatin1ToUtf8;
begin
  AssertEquals('empty','',Latin1ToUtf8(''));
  AssertEquals('ASCII stays','abc_1',Latin1ToUtf8('abc_1'));
  AssertEquals('è','C3 A8',HexOf(Latin1ToUtf8(#$E8)));
  AssertEquals('ÿ','C3 BF',HexOf(Latin1ToUtf8(#$FF)));
  AssertEquals('U+0080','C2 80',HexOf(Latin1ToUtf8(#$80)));
  AssertEquals('mixed','61 C3 A8 62 C2 B0',HexOf(Latin1ToUtf8('a'#$E8'b'#$B0)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoTextEncodingTests.TestUtf8ToLatin1;
begin
  AssertEquals('empty','',Utf8ToLatin1(''));
  AssertEquals('ASCII stays','abc',Utf8ToLatin1('abc'));
  AssertEquals('è','E8',HexOf(Utf8ToLatin1(#$C3#$A8)));
  AssertEquals('ÿ','FF',HexOf(Utf8ToLatin1(#$C3#$BF)));
  AssertEquals('’ is above U+00FF','3F',HexOf(Utf8ToLatin1(#$E2#$80#$99)));
  AssertEquals('ł is above U+00FF','3F',HexOf(Utf8ToLatin1(#$C5#$82)));
  AssertEquals('an emoji','3F',HexOf(Utf8ToLatin1(#$F0#$9F#$98#$80)));
  AssertEquals('a byte that is not UTF-8 is kept','61 E8 62',HexOf(Utf8ToLatin1('a'#$E8'b')));
  AssertEquals('a lead byte at the end is kept','61 C3',HexOf(Utf8ToLatin1('a'#$C3)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoTextEncodingTests.TestLatin1RoundTripsEveryByte;
var
  b : Integer;
  S : String;
begin
  for b:=0 to 255 do
  begin
    S:='x'+Chr(b)+'y';
    AssertEquals('byte '+IntToHex(b,2),HexOf(S),HexOf(Utf8ToLatin1(Latin1ToUtf8(S))));
  end;
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoTextEncodingTests.TestScriptTextToUtf8;
begin
  AssertEquals('empty','',ScriptTextToUtf8(''));
  AssertEquals('UTF-8 stays',HexOf('set %a '#$C3#$A8),HexOf(ScriptTextToUtf8('set %a '#$C3#$A8)));
  AssertEquals('Windows-1252 è','C3 A8',HexOf(ScriptTextToUtf8(#$E8)));
  AssertEquals('Windows-1252 ’','E2 80 99',HexOf(ScriptTextToUtf8(#$92)));
  AssertEquals('Windows-1252 €','E2 82 AC',HexOf(ScriptTextToUtf8(#$80)));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoTextEncodingTests.TestUtf8SeqLenIsStrict;
begin
  AssertEquals('ASCII',1,Utf8SeqLen('a',1));
  AssertEquals('è',2,Utf8SeqLen(#$C3#$A8,1));
  AssertEquals('’',3,Utf8SeqLen(#$E2#$80#$99,1));
  AssertEquals('emoji',4,Utf8SeqLen(#$F0#$9F#$98#$80,1));
  AssertEquals('overlong C0 80',0,Utf8SeqLen(#$C0#$80,1));
  AssertEquals('overlong E0 80 80',0,Utf8SeqLen(#$E0#$80#$80,1));
  AssertEquals('surrogate ED A0 80',0,Utf8SeqLen(#$ED#$A0#$80,1));
  AssertEquals('above U+10FFFF',0,Utf8SeqLen(#$F4#$90#$80#$80,1));
  AssertEquals('lone continuation',0,Utf8SeqLen(#$A8,1));
  AssertEquals('cut short',0,Utf8SeqLen(#$E2#$80,1));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoTextEncodingTests.TestLetterCount;
begin
  AssertEquals('empty',0,LetterCount(''));
  AssertEquals('ASCII',5,LetterCount('Hello'));
  AssertEquals('Mèrlin',6,LetterCount('M'#$C3#$A8'rlin'));
  AssertEquals('a’b',3,LetterCount('a'#$E2#$80#$99'b'));
  AssertEquals('x, emoji, y',3,LetterCount('x'#$F0#$9F#$98#$80'y'));
  AssertEquals('a stray byte is one letter',3,LetterCount('a'#$E8'b'));
  AssertEquals('a lead byte cut short',2,LetterCount('a'#$C3));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoTextEncodingTests.TestLetterRoutinesOnUtf8;
const
  Merlin = 'M'#$C3#$A8'rlin';
var
  S : String;
begin
  AssertEquals('left 2','M'#$C3#$A8,LetterCopy(Merlin,1,2));
  AssertEquals('mid 3 3','rli',LetterCopy(Merlin,3,3));
  AssertEquals('mid 2 1',#$C3#$A8,LetterCopy(Merlin,2,1));
  AssertEquals('from 0','M'#$C3#$A8,LetterCopy(Merlin,0,2));
  AssertEquals('past the end','',LetterCopy(Merlin,7,2));
  AssertEquals('count past the end','lin',LetterCopy(Merlin,4,99));
  AssertEquals('huge start','',LetterCopy(Merlin,High(Int64),2));
  S:=Merlin; LetterDelete(S,2,1);
  AssertEquals('del 2 1','Mrlin',S);
  S:=Merlin; LetterDelete(S,0,1);
  AssertEquals('del 0 does nothing',Merlin,S);
  S:=Merlin; LetterDelete(S,5,99);
  AssertEquals('del to the end','M'#$C3#$A8'rl',S);
  S:=Merlin; LetterInsert(#$C3#$A9,S,3);
  AssertEquals('ins at 3','M'#$C3#$A8#$C3#$A9'rlin',S);
  S:=Merlin; LetterInsert('x',S,99);
  AssertEquals('ins past the end appends',Merlin+'x',S);
  S:=Merlin; LetterInsert('x',S,0);
  AssertEquals('ins at 0 goes first','x'+Merlin,S);
  AssertEquals('pos r',3,LetterPos('r',Merlin));
  AssertEquals('pos è',2,LetterPos(#$C3#$A8,Merlin));
  AssertEquals('pos absent',0,LetterPos('z',Merlin));
  AssertEquals('emoji mid','y',LetterCopy('x'#$F0#$9F#$98#$80'y',3,1));
end;

////////////////////////////////////////////////////////////////////////////////
procedure TEuoTextEncodingTests.TestLetterPosNeedsWholeLetters;
begin
  AssertEquals('half of è does not match',0,LetterPos(#$A8,'M'#$C3#$A8));
  AssertEquals('the lead byte of è alone does not match',0,LetterPos(#$C3,'M'#$C3#$A8));
  AssertEquals('a stray byte matches itself',2,LetterPos(#$E8,'a'#$E8'b'));
  AssertEquals('later whole match found (è, x, then the stray byte)',3,LetterPos(#$A8,#$C3#$A8'x'#$A8));
end;

////////////////////////////////////////////////////////////////////////////////
// On text with one byte per letter the letter routines give what the RTL's gave: every text of up
// to 4 letters over a small alphabet, every start and count from -1 to 6, every search of 1 and 2
// letters. Once with the text converted to UTF-8 (client text, which is Latin-1), once as raw
// bytes that form no UTF-8 sequence (each byte is one letter).
procedure TEuoTextEncodingTests.TestLettersMatchTheRtlOnOneByteText;
const
  Latin1Alpha : array[0..5] of Char = ('a','B','_',#$E9,#$FF,#$C3);
  RawAlpha    : array[0..5] of Char = ('a','B',#$80,#$BF,#$C0,#$FF);

  procedure CheckAll(const Alpha : array of Char; Convert : Boolean);
  var
    Texts, Subs : TStringList;
    ti, k, i, n : Integer;
    S, U, T, V  : String;

    function Conv(const X : String) : String;
    begin
      if Convert then Result:=Latin1ToUtf8(X) else Result:=X;
    end;

    // Builds the message only on a mismatch: there are several hundred thousand checks.
    procedure Same(const What, Expected, Actual : String);
    begin
      if Expected<>Actual then
        Fail(What+': expected <'+HexOf(Expected)+'> but was <'+HexOf(Actual)+'>');
    end;

    procedure AddAll(List : TStringList; const Prefix : String; Left : Integer);
    var
      c : Integer;
    begin
      List.Add(Prefix);
      if Left=0 then Exit;
      for c:=0 to High(Alpha) do AddAll(List,Prefix+Alpha[c],Left-1);
    end;

  begin
    Texts:=TStringList.Create;
    Subs:=TStringList.Create;
    try
      AddAll(Texts,'',4);
      AddAll(Subs,'',2);
      for ti:=0 to Texts.Count-1 do
      begin
        S:=Texts[ti];
        U:=Conv(S);
        if LetterCount(U)<>Length(S) then Fail('count '+HexOf(S));
        for i:=-1 to 6 do
        begin
          for n:=-1 to 6 do
          begin
            T:=Conv(Copy(S,i,n));
            V:=LetterCopy(U,i,n);
            if T<>V then Same('copy '+HexOf(S)+' '+IntToStr(i)+' '+IntToStr(n),T,V);
            T:=S; Delete(T,i,n); T:=Conv(T);
            V:=U; LetterDelete(V,i,n);
            if T<>V then Same('delete '+HexOf(S)+' '+IntToStr(i)+' '+IntToStr(n),T,V);
          end;
          for k:=0 to High(Alpha) do
          begin
            T:=S; Insert(Alpha[k],T,i); T:=Conv(T);
            V:=U; LetterInsert(Conv(Alpha[k]),V,i);
            if T<>V then Same('insert '+HexOf(S)+' '+IntToStr(i),T,V);
          end;
        end;
        for k:=1 to Subs.Count-1 do
          if LetterPos(Conv(Subs[k]),U)<>Pos(Subs[k],S) then
            Fail('pos '+HexOf(Subs[k])+' in '+HexOf(S));
      end;
    finally
      Texts.Free;
      Subs.Free;
    end;
  end;

begin
  CheckAll(Latin1Alpha,True);
  CheckAll(RawAlpha,False);
end;

initialization
  RegisterTest(TEuoTextEncodingTests);
end.
