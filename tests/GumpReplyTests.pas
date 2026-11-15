unit GumpReplyTests;

{ exevent GumpReply without a client (port addition, uo\uogumpreply.pas):
  - the $B1 packets for given words, against tests\fixtures\gumpreply\replies.txt, which
    tests\tools\GenerateGumpReplyFixture.ps1 builds from the client's layout, not from the Pascal code;
  - the round trip words -> answer -> words -> the same packet, and packet -> answer (what the click
    hook will decode), with the awkward characters;
  - words that must be refused. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, uogumpreply, uoevents;

type
  TGumpReplyTests = class(TTestCase)
  private
    Cases : TStringList;
    procedure Fields(Index : Integer; out Name, Words, Hex : String; out Serial, TypeID : Cardinal);
    function  ToHex(const S : String) : String;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure TestPacketsMatchTheFixture;
    procedure TestWordsRoundTripToTheSamePacket;
    procedure TestCanonicalWords;
    procedure TestPacketDecodesBackToTheAnswer;
    procedure TestTruncatedPacketsAreRefused;
    procedure TestBadWordsAreRefused;
    procedure TestTextEscapes;
    procedure TestTextIsCutAt239Characters;
    procedure TestOsiGumpsKeepTheirWindow;
    procedure TestHookMovesOnlyPlainInstructions;
    procedure TestHookPageIsFoundBehindItsJmp;
  end;

implementation

procedure TGumpReplyTests.SetUp;
var
  Path : String;
begin
  Cases := TStringList.Create;
  Path := ExtractFilePath(ParamStr(0)) + 'fixtures' + PathDelim + 'gumpreply' + PathDelim + 'replies.txt';
  if not FileExists(Path) then
    Fail('missing fixture ' + Path + ' (run tests\tools\GenerateGumpReplyFixture.ps1)');
  Cases.LoadFromFile(Path);     // UTF-8, as the strings of this program
end;

procedure TGumpReplyTests.TearDown;
begin
  Cases.Free;
end;

procedure TGumpReplyTests.Fields(Index : Integer; out Name, Words, Hex : String; out Serial, TypeID : Cardinal);
var
  P : TStringList;
begin
  P := TStringList.Create;
  try
    P.StrictDelimiter := True;
    P.Delimiter := '|';
    P.DelimitedText := Cases[Index];
    AssertEquals('five fields in line ' + IntToStr(Index + 1), 5, P.Count);
    Name := P[0];
    Serial := Cardinal(StrToInt64('$' + P[1]));
    TypeID := Cardinal(StrToInt64('$' + P[2]));
    Words := P[3];
    Hex := P[4];
  finally P.Free; end;
end;

function TGumpReplyTests.ToHex(const S : String) : String;
var
  I : Integer;
begin
  Result := '';
  for I := 1 to Length(S) do
    Result := Result + IntToHex(Ord(S[I]), 2);
end;

procedure TGumpReplyTests.TestPacketsMatchTheFixture;
var
  I              : Integer;
  Name, W, Hex   : String;
  Serial, TypeID : Cardinal;
  R              : TGumpReply;
begin
  AssertTrue('the fixture has cases', Cases.Count >= 10);
  for I := 0 to Cases.Count - 1 do
  begin
    Fields(I, Name, W, Hex, Serial, TypeID);
    AssertTrue(Name + ': words accepted', ParseReplyArgs(W, R));
    R.TypeID := TypeID;
    AssertEquals(Name, Hex, ToHex(BuildReplyPacket(Serial, R)));
  end;
end;

procedure TGumpReplyTests.TestWordsRoundTripToTheSamePacket;
var
  I              : Integer;
  Name, W, Hex   : String;
  Serial, TypeID : Cardinal;
  R, R2          : TGumpReply;
begin
  for I := 0 to Cases.Count - 1 do
  begin
    Fields(I, Name, W, Hex, Serial, TypeID);
    ParseReplyArgs(W, R);
    AssertTrue(Name + ': its own words read back', ParseReplyArgs(ReplyArgsText(R), R2));
    R2.TypeID := TypeID;
    AssertEquals(Name, Hex, ToHex(BuildReplyPacket(Serial, R2)));
  end;
end;

procedure TGumpReplyTests.TestCanonicalWords;
var
  R : TGumpReply;
begin
  ParseReplyArgs('0', R);
  AssertEquals('no switches: -', '0 -', ReplyArgsText(R));
  ParseReplyArgs('7   5:x', R);
  AssertEquals('a text right after the button', '7 - 5:x', ReplyArgsText(R));
  ParseReplyArgs('1 3/7 5:hello_world 6:', R);
  AssertEquals('1 3/7 5:hello_world 6:', ReplyArgsText(R));
  AssertEquals('3/7', ReplySwitchesText(R));
  AssertEquals('5:hello_world 6:', ReplyTextsText(R));
  ParseReplyArgs('2 - 1:a\_b\\c 2:50%_off;_see,_more.', R);
  AssertEquals('the escapes come back as written', '2 - 1:a\_b\\c 2:50%_off;_see,_more.', ReplyArgsText(R));
end;

procedure TGumpReplyTests.TestPacketDecodesBackToTheAnswer;
var
  I                    : Integer;
  Name, W, Hex, P      : String;
  Serial, TypeID, S2   : Cardinal;
  R, R2                : TGumpReply;
begin
  for I := 0 to Cases.Count - 1 do
  begin
    Fields(I, Name, W, Hex, Serial, TypeID);
    ParseReplyArgs(W, R);
    R.TypeID := TypeID;
    P := BuildReplyPacket(Serial, R);
    AssertTrue(Name + ': decodes', DecodeReplyPacket(P, S2, R2));
    AssertEquals(Name + ' serial', Serial, S2);
    AssertEquals(Name + ' type ID', TypeID, R2.TypeID);
    AssertEquals(Name + ' words', ReplyArgsText(R), ReplyArgsText(R2));
  end;
end;

procedure TGumpReplyTests.TestTruncatedPacketsAreRefused;
var
  R      : TGumpReply;
  P      : String;
  S      : Cardinal;
  N      : Integer;
begin
  ParseReplyArgs('1 3/7 5:hello_world 6:', R);
  R.TypeID := $1234;
  P := BuildReplyPacket(5, R);
  AssertTrue(DecodeReplyPacket(P, S, R));
  for N := 1 to Length(P) - 1 do
    AssertFalse('cut to ' + IntToStr(N) + ' bytes', DecodeReplyPacket(Copy(P, 1, N), S, R));
  P[1] := #$B0;
  AssertFalse('not $B1', DecodeReplyPacket(P, S, R));
end;

procedure TGumpReplyTests.TestBadWordsAreRefused;
const
  Bad : array[0..11] of String = ('', 'x', '-1', '4294967296', '1 a/b', '1 3//7', '1 3/', '1 - 5',
    '1 - :x', '1 - 65536:x', '1 - x:y', '1 3/7 8');
var
  I : Integer;
  R : TGumpReply;
begin
  for I := 0 to High(Bad) do
    AssertFalse('"' + Bad[I] + '"', ParseReplyArgs(Bad[I], R));
  AssertTrue('a tab separates too', ParseReplyArgs('1'#9'-', R));
end;

procedure TGumpReplyTests.TestTextEscapes;
var
  W : UnicodeString;
begin
  AssertEquals('a b', String(DecodeReplyText('a_b')));
  AssertEquals('a_b', String(DecodeReplyText('a\_b')));
  AssertEquals('a\b', String(DecodeReplyText('a\\b')));
  AssertEquals('another \ stays', 'a\xb', String(DecodeReplyText('a\xb')));
  AssertEquals('\ at the end stays', 'a\', String(DecodeReplyText('a\')));
  AssertEquals('only control characters are hex', 'a\41', String(DecodeReplyText('a\41')));
  W := 'line'#10'next'#9'tab \ _ ,;%.';
  AssertEquals('line\0Anext\09tab_\\_\__,;%.', EncodeReplyText(W));
  AssertTrue('round trip', DecodeReplyText(EncodeReplyText(W)) = W);
  W := UnicodeString(#$00E9#$4E2D);
  AssertTrue('non-ASCII round trip', DecodeReplyText(EncodeReplyText(W)) = W);
end;

procedure TGumpReplyTests.TestTextIsCutAt239Characters;
var
  R : TGumpReply;
begin
  AssertTrue(ParseReplyArgs('1 - 9:' + StringOfChar('y', 500), R));
  AssertEquals(239, Length(R.Texts[0]));
  R.Texts[0] := UnicodeString(StringOfChar('z', 300));      // set directly: the packet cuts too
  R.TypeID := 1;
  AssertEquals('3 + 20 + 4 + 239*2 bytes', 3 + 20 + 4 + 239 * 2, Length(BuildReplyPacket(1, R)));
end;

procedure TGumpReplyTests.TestOsiGumpsKeepTheirWindow;
begin
  AssertFalse(ReplyKeepsWindow($240F));
  AssertTrue(ReplyKeepsWindow($2410));
  AssertTrue(ReplyKeepsWindow($2462));
  AssertFalse(ReplyKeepsWindow($2463));
  AssertFalse('a ModernUO hash', ReplyKeepsWindow($9E26D92D));
end;

// The click hook replaces the send function's first instructions; only instructions that work anywhere
// may be moved: the starts of client.exe 7.0.118.46 and the beta 7.0.118.132, and a few more plain ones.
procedure TGumpReplyTests.TestHookMovesOnlyPlainInstructions;
begin
  AssertEquals('client.exe: mov ecx,[abs]', 6, HookPrologueLength(#$8B#$0D#$9C#$83#$A0#$00#$85#$C9#$74#$0A));
  AssertEquals('beta: push ebp/mov ebp,esp/push ebx/push esi', 5, HookPrologueLength(#$55#$8B#$EC#$53#$56#$57#$8B#$F9));
  AssertEquals('mov eax,[esp+4] / push eax: stops at 5', 5, HookPrologueLength(#$8B#$44#$24#$04#$50#$50#$C3));
  AssertEquals('sub esp,imm8 / push imm8', 5, HookPrologueLength(#$83#$EC#$10#$6A#$FF#$90));
  AssertEquals('fs:[0]', 6, HookPrologueLength(#$64#$A1#$00#$00#$00#$00));
  AssertEquals('push imm32', 5, HookPrologueLength(#$68#$01#$02#$03#$04));
  AssertEquals('a call is relative', 0, HookPrologueLength(#$55#$E8#$00#$00#$00#$00));
  AssertEquals('a short jump is relative', 0, HookPrologueLength(#$55#$8B#$EC#$74#$05#$90));
  AssertEquals('a jmp: already hooked', 0, HookPrologueLength(#$E9#$00#$00#$00#$00#$90));
  AssertEquals('mov eax,imm32 is not on the list', 0, HookPrologueLength(#$B8#$67#$ED#$69#$00#$E8));
  AssertEquals('too short', 0, HookPrologueLength(#$55#$8B#$EC));
end;

procedure TGumpReplyTests.TestHookPageIsFoundBehindItsJmp;
var
  J, H : String;
begin
  // jmp from $434930 to $0B000900: rel = $0B000900 - $434935
  J := #$E9 + Chr($CB) + Chr($BF) + Chr($BC) + Chr($0A);
  AssertEquals(IntToHex($0B000900 - $434935, 8), '0ABCBFCB');
  AssertEquals('the page', Int64($0B000000), Int64(HookPageOf($434930, J)));
  AssertEquals('no jmp, no page', Int64(0), Int64(HookPageOf($434930, #$55#$8B#$EC#$53#$56)));
  H := HookHeader($434930, #$55#$8B#$EC#$53#$56);
  AssertEquals('header size', $20, Length(H));
  AssertEquals('magic', 'EUORGRH1', Copy(H, 1, 8));
  AssertTrue('ours', HookHeaderIsOurs(H, $434930));
  AssertFalse('for another function', HookHeaderIsOurs(H, $434931));
  H[1] := 'X';
  AssertFalse('not our magic', HookHeaderIsOurs(H, $434930));
end;

initialization
  RegisterTest(TGumpReplyTests);
end.
