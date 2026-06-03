unit EngineLogMessages;

{$mode objfpc}{$H+}

interface

uses
  EngineConfig;

function EngineCommandSentLogText(const ACommand: String): String;

function EngineExecuteBeginLogText(const AEngineName: String): String;
function EngineExecuteCwdLogText(const AEngineName, ACurrentDir: String): String;
function EngineExecuteReturnedLogText(const AEngineName: String;
  ARunning: Boolean): String;
function EngineLaunchLogText(const AParamsFileName: String;
  AProtocol: TEngineProtocol; const ADxpId, ALaunchArgs: String): String;
function EngineLoadedParametersLogText(const AParamsFileName: String): String;
function EngineLaunchAbortedLogText(const AReason: String): String;
function EngineDxpLaunchDetailsLogText(const ADxpId: String;
  ARole: TEngineDxpRole; const AIpAddress, ASocketNumber,
  ALaunchArgs: String): String;
function EngineHubLaunchDetailsLogText(const AHubLaunchArgument: String): String;

function EngineFirstReadLogText(const AEngineName: String;
  AByteCount: Integer): String;
function EngineProcessTerminatedLogText(const AEngineName: String): String;

function EngineStopRequestedLogText(const AEngineName,
  APreviousStateText: String): String;
function EngineStopTransitionLogText(const AEngineName,
  APreviousStateText: String): String;

implementation

uses
  SysUtils;

function EngineCommandSentLogText(const ACommand: String): String;
begin
  Result := '> ' + ACommand + LineEnding;
end;

{ Launch and setup messages }

function EngineExecuteBeginLogText(const AEngineName: String): String;
begin
  Result := '[' + AEngineName + ' execute begin]' + LineEnding;
end;

function EngineExecuteCwdLogText(const AEngineName, ACurrentDir: String): String;
begin
  Result := '[' + AEngineName + ' cwd ' + ACurrentDir + ']' + LineEnding;
end;

function EngineExecuteReturnedLogText(const AEngineName: String;
  ARunning: Boolean): String;
begin
  Result := '[' + AEngineName + ' execute returned running=' +
    BoolToStr(ARunning, True) + ']' + LineEnding;
end;

function EngineLaunchLogText(const AParamsFileName: String;
  AProtocol: TEngineProtocol; const ADxpId, ALaunchArgs: String): String;
begin
  Result := '[launch params file: ' + AParamsFileName + ']' + LineEnding;
  if AProtocol = epDxp then
    Result += '[launch protocol: DXP]' + LineEnding +
      '[launch DXP id: ' + ADxpId + ']' + LineEnding +
      '[launch DXP args: ' + ALaunchArgs + ']' + LineEnding
  else
    Result += '[launch protocol: HUB]' + LineEnding +
      '[launch HUB args: ' + ALaunchArgs + ']' + LineEnding;
end;

function EngineLoadedParametersLogText(const AParamsFileName: String): String;
begin
  Result := 'Loaded parameters: ' + AParamsFileName;
end;

function EngineLaunchAbortedLogText(const AReason: String): String;
begin
  Result := '[engine launch aborted: ' + AReason + ']' + LineEnding;
end;

function EngineDxpLaunchDetailsLogText(const ADxpId: String;
  ARole: TEngineDxpRole; const AIpAddress, ASocketNumber,
  ALaunchArgs: String): String;
begin
  Result := '';
  if ADxpId <> '' then
    Result += '[DXP id=' + ADxpId + ']' + LineEnding;
  if ARole = edrClient then
    Result += '[DXP socket mode=listen ip=' + AIpAddress + ' socket=' +
      ASocketNumber + ']' + LineEnding
  else
    Result += '[DXP socket mode=connect ip=' + AIpAddress + ' socket=' +
      ASocketNumber + ']' + LineEnding;
  if ALaunchArgs <> '' then
    Result += '[DXP launch arguments: ' + ALaunchArgs + ']' + LineEnding;
end;

function EngineHubLaunchDetailsLogText(const AHubLaunchArgument: String): String;
begin
  Result := '';
  if AHubLaunchArgument <> '' then
    Result := '[hub launch argument: ' + AHubLaunchArgument + ']' + LineEnding;
end;

{ Runtime messages }

function EngineFirstReadLogText(const AEngineName: String;
  AByteCount: Integer): String;
begin
  Result := '[' + AEngineName + ' first read bytes=' + IntToStr(AByteCount) +
    ']' + LineEnding;
end;

function EngineProcessTerminatedLogText(const AEngineName: String): String;
begin
  Result := LineEnding + '[' + AEngineName + ' process terminated]' +
    LineEnding;
end;

{ Search/stop messages }

function EngineStopRequestedLogText(const AEngineName,
  APreviousStateText: String): String;
begin
  Result := '[' + AEngineName + ' stop requested while state: ' +
    APreviousStateText + ']' + LineEnding;
end;

function EngineStopTransitionLogText(const AEngineName,
  APreviousStateText: String): String;
begin
  Result := '[' + AEngineName + ' state: ' + APreviousStateText +
    ' -> idle]' + LineEnding;
end;

end.
