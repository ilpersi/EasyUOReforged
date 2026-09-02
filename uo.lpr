library uo;

{
  Ported from the original Delphi 7 uo\uo.dpr. The hand-specified decorated
  export names (e.g. '_UOOpen@0') are kept as literal alias strings for
  continuity, in case any hypothetical external consumer hardcoded them --
  but see uodef.pas's header comment: Win64 has no stdcall name-decoration
  convention at all, so the '@N' byte-count suffixes are not meaningful
  calling-convention information on this target, just inert historical
  strings. This is also why the exported Hnd handle type had to change from
  Integer to PtrInt (uodef.pas) -- a 64-bit build's object handles are real
  64-bit heap pointers, and the original ABI was sized only for a 32-bit one.
}

{$mode delphi}{$H+}

uses uodef;

exports
  Version      ,Version      name '_UOVersion@0',
  Open         ,Open         name '_UOOpen@0',
  Close        ,Close        name '_UOClose@4',
  Query        ,Query        name '_UOQuery@4',
  Execute      ,Execute      name '_UOExecute@4',
  GetTop       ,GetTop       name '_UOGetTop@4',
  GetType      ,GetType      name '_UOGetType@8',
  Insert       ,Insert       name '_UOInsert@8',
  PushNil      ,PushNil      name '_UOPushNil@4',
  PushBoolean  ,PushBoolean  name '_UOPushBoolean@8',
  PushPointer  ,PushPointer  name '_UOPushPointer@8',
  PushPtrOrNil ,PushPtrOrNil name '_UOPushPtrOrNil@8',
  PushInteger  ,PushInteger  name '_UOPushInteger@8',
  PushDouble   ,PushDouble   name '_UOPushDouble@12',
  PushStrRef   ,PushStrRef   name '_UOPushStrRef@8',
  PushStrVal   ,PushStrVal   name '_UOPushStrVal@8',
  PushLStrRef  ,PushLStrRef  name '_UOPushLStrRef@12',
  PushLStrVal  ,PushLStrVal  name '_UOPushLStrVal@12',
  PushValue    ,PushValue    name '_UOPushValue@8',
  GetBoolean   ,GetBoolean   name '_UOGetBoolean@8',
  GetPointer   ,GetPointer   name '_UOGetPointer@8',
  GetInteger   ,GetInteger   name '_UOGetInteger@8',
  GetDouble    ,GetDouble    name '_UOGetDouble@8',
  GetString    ,GetString    name '_UOGetString@8',
  GetLString   ,GetLString   name '_UOGetLString@12',
  Remove       ,Remove       name '_UORemove@8',
  SetTop       ,SetTop       name '_UOSetTop@8',
  Mark         ,Mark         name '_UOMark@4',
  Clean        ,Clean        name '_UOClean@4';
end.
