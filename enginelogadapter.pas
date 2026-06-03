unit EngineLogAdapter;

{$mode objfpc}{$H+}

interface

uses
  StdCtrls;

procedure AppendEngineGuiLog(AMemo: TMemo; const AText: String;
  AShowTimestamps: Boolean);
procedure AppendEngineRawLog(AMemo: TMemo; const AText: String);
function FormatEngineOutputLog(const AText, AEngineName: String;
  AShowTimestamps: Boolean): String;

implementation

uses
  EngineLogging,
  EngineLogMemo;

procedure AppendEngineGuiLog(AMemo: TMemo; const AText: String;
  AShowTimestamps: Boolean);
begin
  AppendEngineLogMemoText(AMemo, PrefixLogLines(AText,
    EngineLogPrefix('GUI', AShowTimestamps)));
end;

procedure AppendEngineRawLog(AMemo: TMemo; const AText: String);
begin
  AppendEngineLogMemoText(AMemo, AText);
end;

function FormatEngineOutputLog(const AText, AEngineName: String;
  AShowTimestamps: Boolean): String;
begin
  Result := EngineLogging.EngineOutputLogText(AText, AEngineName,
    AShowTimestamps);
end;

end.
