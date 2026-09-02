unit uotypes;

{
  Shared types used across common\ + uo\ + parser\.

  TTargetAddr documents "this Cardinal is an address/offset inside the (always 32-bit)
  Ultima Online client process," as distinct from a native host pointer -- see the
  migration plan's bitness decision. Never store a target address in Pointer/PtrInt/
  PtrUInt; only cast to Pointer at the point of an actual WinAPI call.

  TDelayFunc was declared identically in both the original uocommands.pas and
  uoevents.pas; unified here to one declaration. It lets uo\'s blocking waits cooperate
  with the interpreter's Stop/Break/Pause state instead of doing a raw Sleep.
}

{$mode delphi}{$H+}

interface

type
  TTargetAddr = type Cardinal;

  TDelayFunc = function(Duration : Cardinal) : Boolean of object;

implementation

end.
