unit tables;

{
  Ported from the original Delphi 7 uo\tables.pas, with one bug fixed (required
  regardless of host bitness -- see migration plan).

  The original's generic Find(Str,Ptr,W,H) reinterpreted a TItem/TIndex array as
  "array of PChar" and stepped by a hardcoded literal stride W=4 ("item/index table
  width = 4"), which only happened to be correct on Win32 because every field of
  TItem/TIndex (PChar, Integer, Integer, PChar) is exactly pointer-width there, making
  the whole record exactly 4 pointer-widths. On Win64, Integer stays 4 bytes while
  PChar becomes 8, so the true record size stops being a clean multiple of that assumed
  stride -- silently wrong binary-search results.

  Fixed by deleting that reinterpretation entirely: FindItemAt/FindIndexAt below index
  a properly-typed PItemArray/PIndexArray pointer directly, so the compiler computes
  the real record stride on whatever platform it's built for. Every other user of a
  record's size in this file (PtrAdd's callers, Find_Next) already used SizeOf(TItem)
  correctly and needed no change. Find_First/Find_Next/Check/ParComp/TFindRes all keep
  their exact original signatures, so uowrap.pas's 140-row UOTbl/11-row Commands
  dispatch (built on top of this unit) recompiles with zero changes.
}

{$mode delphi}{$H+}

interface

uses
  stack, SysUtils;

type
  TIndex        = record
    N           : PChar;
    C           : Integer;
    T           : Pointer;
    H           : Integer;
  end;
  TDoc          = record
    P           : PChar;
    R           : PChar;
  end;
  TItem        = record
    N           : PChar;
    T           : Integer;
    C           : Integer;
    P           : PChar;
  end;
  TFindRes      = record
    I           : ^TItem;
    C           : Integer;
  end;
  TReq          = set of 0..31;

const
  RO = 01; RW = 02; ME = 03; EV = 04; CM = 05; QY = 06; PA = 31;

  function Find_First(var Res : TFindRes; Name : String; var Items : array of TItem) : Boolean; overload;
  function Find_First(var Res : TFindRes; Cls : TClass; Name : String; var Index : array of TIndex) : Boolean; overload;
  function Find_Next(var Res : TFindRes) : Boolean;
  function ParComp(Stack : TStack; i : Integer; Mask : PChar) : Boolean;
  function Check(var Res : TFindRes; Stack : TStack; Index : Integer; Req : TReq) : Integer;

implementation

type
  PItemArray  = ^TItemArrayBuf;
  TItemArrayBuf  = array[0..(MaxInt div SizeOf(TItem))-1] of TItem;
  PIndexArray = ^TIndexArrayBuf;
  TIndexArrayBuf = array[0..(MaxInt div SizeOf(TIndex))-1] of TIndex;

////////////////////////////////////////////////////////////////////////////////
function PtrAdd(Ptr : Pointer; Amount : Cardinal) : Pointer;
begin
  Result:=Pointer(PtrUInt(Ptr)+Amount);
end;

////////////////////////////////////////////////////////////////////////////////
function FindItemAt(Arr : PItemArray; H : Integer; Str : String) : Integer;     // Binary Search, operates on a properly-typed array
var                                                                              // pointer -- the compiler computes TItem's real
  a,m,z : Integer;                                                              // stride, so this is correct on any platform.
begin
  a:=0;
  z:=H;
  while a<z do
  begin
    m:=a+(z-a)shr 1;
    if CompareStr(Arr^[m].N,Str)<0 then a:=m+1
    else z:=m;
  end;
  Result:=-1;
  repeat                                                                        // Find first occurence!
    if CompareStr(Arr^[a].N,Str)<>0 then Exit;
    Result:=a;
    Dec(a);
  until a<0;
end;

////////////////////////////////////////////////////////////////////////////////
function FindIndexAt(Arr : PIndexArray; H : Integer; Str : String) : Integer;   // Same, for TIndex arrays.
var
  a,m,z : Integer;
begin
  a:=0;
  z:=H;
  while a<z do
  begin
    m:=a+(z-a)shr 1;
    if CompareStr(Arr^[m].N,Str)<0 then a:=m+1
    else z:=m;
  end;
  Result:=-1;
  repeat
    if CompareStr(Arr^[a].N,Str)<>0 then Exit;
    Result:=a;
    Dec(a);
  until a<0;
end;

////////////////////////////////////////////////////////////////////////////////
function Find_First(var Res : TFindRes; Name : String; var Items : array of TItem) : Boolean; // normal version
var
  i : Integer;
begin
  Res.I:=nil;
  Res.C:=0;
  Result:=False;
  i:=FindItemAt(PItemArray(@Items[0]),High(Items),Name);
  if i<0 then Exit;
  Res.I:=@Items[i];
  Res.C:=High(Items)-i;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function Find_First(var Res : TFindRes; Cls : TClass; Name : String; var Index : array of TIndex) : Boolean; // object version (with index)
var
  i,j : Integer;
begin
  Res.I:=nil;
  Res.C:=0;
  Result:=False;
  repeat
    i:=FindIndexAt(PIndexArray(@Index[0]),High(Index),Cls.ClassName);
    Cls:=Cls.ClassParent;
    if i<0 then Continue;
    if Index[i].T=nil then Continue;
    j:=FindItemAt(PItemArray(Index[i].T),Index[i].H,Name);
    if j<0 then Continue;
    Res.I:=PtrAdd(Index[i].T,j*SizeOf(TItem));
    Res.C:=Index[i].H-j;
    Result:=True;
  until (Cls=nil) or Result;
end;

////////////////////////////////////////////////////////////////////////////////
function Find_Next(var Res : TFindRes) : Boolean;
var
  I : ^TItem;
begin
  I:=PtrAdd(Res.I,SizeOf(TItem));
  if (Res.I<>nil)and(Res.C>0) then
    if CompareStr(Res.I^.N,I^.N)=0 then
  begin
    Res.I:=Pointer(I);
    Res.C:=Res.C-1;
    Result:=True;
    Exit;
  end;
  Res.I:=nil;
  Res.C:=0;
  Result:=False;
end;

////////////////////////////////////////////////////////////////////////////////
function ParComp(Stack : TStack; i : Integer; Mask : PChar) : Boolean; //checks parameters on the stack against a string mask
var
  cls : TClass;
  j   : Integer;
  s   : String;
  c   : Char;
begin
  Result:=False;
  j:=-1;
  Dec(i);
  repeat
    Inc(j);
    Inc(i);
    case Mask[j] of
      '?': Continue;
      '*': if Stack.GetTop()>=i-1 then Break
           else Exit;
      #0 : if Stack.GetTop()=i-1 then Break
           else Exit;
    end;
    case Stack.GetType(i) of
      T_NIL    : if Mask[j]<>'-' then
                 if Mask[j]<>'[' then Exit
                 else repeat
                   Inc(j);
                   if Mask[j]=#0 then Exit;
                 until Mask[j]=']';
      T_BOOLEAN: if Mask[j]<>'b' then Exit;
      T_NUMBER : if Mask[j]<>'n' then Exit;
      T_STRING : if Mask[j]<>'s' then Exit;
      T_POINTER: if Mask[j]<>'p' then
                 begin
                   c:=')';
                   if Mask[j]='[' then c:=']'
                   else if Mask[j]<>'(' then Exit;
                   cls:=TObject(Stack.GetPointer(i)).ClassType;
                   repeat
                     if cls=nil then Exit;
                     s:=cls.ClassName+c;
                     cls:=cls.ClassParent;
                   until StrLComp(@s[1],@Mask[j+1],Length(s))=0;
                   j:=j+Length(s);
                 end;
    end;
  until False;
  Result:=True;
end;

////////////////////////////////////////////////////////////////////////////////
function Check(var Res : TFindRes; Stack : TStack; Index : Integer; Req : TReq) : Integer; //uses all of the above functions to find a matching entry
begin
  Result:=-1;
  if Res.I<>nil then
  repeat
    if not(Res.I^.T in Req) then Continue;
    Result:=-2;
    if PA in Req then
      if not ParComp(Stack,Index,Res.I^.P) then Continue;
    Result:=Res.I^.C;
    Exit;
  until not Find_Next(Res);
end;

////////////////////////////////////////////////////////////////////////////////
end.
