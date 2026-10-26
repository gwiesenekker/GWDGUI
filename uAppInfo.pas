unit uAppInfo;
{$mode objfpc}{$H+}{$codepage utf8}
interface
function AppBuildCommit: string;
function AppAboutText: string;
function AppManualText: string;
implementation
uses Classes, SysUtils;
{$IFDEF GWDGUI_EMBEDDED_HELP}
{$I gwdgui-build.inc}
{$ELSE}
const
  BuildCommit = 'unavailable (build with build.sh to embed the commit)';
  BuildRevision = 'development build';
  BuildHasChanges = False;
  EmbeddedManual: UTF8String = '';
{$ENDIF}
function AppBuildCommit: string;
begin Result := BuildCommit; end;
function AppAboutText: string;
begin
  Result := 'GWDGUI' + LineEnding + 'International draughts' + LineEnding +
    LineEnding + 'Build: ' + BuildRevision + LineEnding + 'Commit: ' + BuildCommit;
  if BuildHasChanges then Result += LineEnding + 'Includes uncommitted changes.';
end;
function AppManualText: string;
var Lines: TStringList; Path: string;
begin
  Result := EmbeddedManual;
  if Result <> '' then Exit;
  // Direct IDE/source-archive builds can use a manual beside the executable.
  Path := IncludeTrailingPathDelimiter(ExtractFilePath(ExpandFileName(ParamStr(0)))) + 'MANUAL.md';
  Lines := TStringList.Create;
  try
    if FileExists(Path) then
    begin Lines.LoadFromFile(Path); Result := Lines.Text; end
    else Result := 'The manual is not included in this build.' + LineEnding +
      'Build with build.sh, or place MANUAL.md beside the application.';
  finally Lines.Free; end;
end;
end.
