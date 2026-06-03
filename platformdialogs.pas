unit PlatformDialogs;

{$mode objfpc}{$H+}

interface

function EngineExecutableDefaultExt: String;
function EngineExecutableFilter: String;

implementation

function EngineExecutableDefaultExt: String;
begin
  {$IFDEF MSWINDOWS}
  Result := 'exe';
  {$ELSE}
  Result := 'out';
  {$ENDIF}
end;

function EngineExecutableFilter: String;
begin
  {$IFDEF MSWINDOWS}
  Result := 'Windows engine executables (*.exe)|*.exe|All files (*.*)|*.*';
  {$ELSE}
  Result := 'Linux engine executables (*.out)|*.out|All files (*)|*';
  {$ENDIF}
end;

end.
