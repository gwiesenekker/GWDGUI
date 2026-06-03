unit EngineConfig;

{$mode objfpc}{$H+}

interface

uses
  EngineParams;

type
  TEngineProtocol = (epHub, epDxp);
  TEngineDxpRole = (edrListener, edrClient);

  TEngineProtocolConfig = record
    Protocol: TEngineProtocol;
    HubId: String;
    IniFileName: String;
    HubLaunchArgument: String;
    DxpId: String;
    DxpIpAddress: String;
    DxpSocketNumber: String;
    DxpLaunchArguments: String;
    DxpRole: TEngineDxpRole;
  end;

const
  EvalBarDefaultMaxScore = 1000.0;
  EngineTypeParamName = 'gui-engine-type';
  HubIdParamName = 'gui-hub-id';
  EngineIniFileParamName = 'gui-ini-file';
  EngineIniContentParamName = 'gui-ini-content';
  HubLaunchArgumentParamName = 'gui-hub-launch-argument';
  OldHubLaunchArgumentParamName = 'hub-launch-argument';
  OldLaunchWithHubArgumentParamName = 'launch-with-hub-argument';
  DxpIdParamName = 'gui-dxp-id';
  DxpIpParamName = 'gui-dxp-ip';
  DxpSocketParamName = 'gui-dxp-socket';
  DxpLaunchArgumentsParamName = 'gui-dxp-launch-arguments';
  DxpRoleParamName = 'gui-dxp-role';
  DxpDefaultIp = '127.0.0.1';
  DxpDefaultSocket = '27531';
  DxpConnectAttempts = 120;
  DxpConnectRetryDelayMs = 250;
  DxpConnectTimeoutMs = 1000;
  SendStartingPositionParamName = 'gui-send-starting-position';
  OldSendStartingPositionParamName = 'send-starting-position';
  SingleCapturesIncludeCapturedSquareParamName =
    'gui-single-captures-include-captured-square';
  OldSingleCapturesIncludeCapturedSquareParamName =
    'single-captures-include-captured-square';
  AnalyzeSendsInfoParamName = 'gui-analyze-sends-info';
  OldAnalyzeSendsInfoParamName = 'gui-ponder-sends-info';
  EngineSupportsMctsParamName = 'gui-engine-supports-mcts';
  ScorePerspectiveParamName = 'gui-score-perspective';
  EvaluationDepthMinParamName = 'gui-evaluation-bar-depth-min';
  OldEvaluationDepthMinParamName = 'gui-evaluation-depth-min';
  EvaluationBarMaxParamName = 'gui-evaluation-bar-score-max';
  OldEvaluationBarMaxParamName = 'gui-evaluation-bar-max';

procedure RemoveEngineParam(var AParams: TEngineParamArray; const AName: String);
function EngineConfigParamExists(const AParams: TEngineParamArray;
  const AName: String): Boolean;
function EngineConfigParamValue(const AParams: TEngineParamArray;
  const AName, ADefault: String): String;
function EngineConfigParamBool(const AParams: TEngineParamArray;
  const AName: String; ADefault: Boolean): Boolean;
function EngineConfigParamInt(const AParams: TEngineParamArray;
  const AName: String; ADefault: Integer): Integer;
function EngineConfigParamFloat(const AParams: TEngineParamArray;
  const AName: String; ADefault: Double): Double;
function EngineConfigParamsFileName(const ADisplayName, AEngineFileName,
  ADefaultDirectory: String): String;
function DefaultEngineProtocolConfig(AEngineIndex: Integer): TEngineProtocolConfig;
function LoadEngineProtocolConfig(const AParams: TEngineParamArray;
  AEngineIndex: Integer): TEngineProtocolConfig;
procedure SaveEngineProtocolConfig(var AParams: TEngineParamArray;
  const AConfig: TEngineProtocolConfig);
procedure SyncEngineParamWithLegacy(var AParams: TEngineParamArray;
  const ANewName, AOldName, AType, ADefaultValue: String);
function EngineParamShouldSendToHub(const AName: String): Boolean;

implementation

uses
  StrUtils,
  SysUtils;

procedure RemoveEngineParam(var AParams: TEngineParamArray; const AName: String);
var
  I: Integer;
  J: Integer;
begin
  for I := 0 to High(AParams) do
    if SameText(AParams[I].Name, AName) then
    begin
      for J := I to High(AParams) - 1 do
        AParams[J] := AParams[J + 1];
      SetLength(AParams, Length(AParams) - 1);
      Exit;
    end;
end;

function EngineConfigParamExists(const AParams: TEngineParamArray;
  const AName: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(AParams) do
    if SameText(AParams[I].Name, AName) then
      Exit(True);
end;

function EngineConfigParamValue(const AParams: TEngineParamArray;
  const AName, ADefault: String): String;
var
  I: Integer;
begin
  Result := ADefault;
  for I := 0 to High(AParams) do
    if SameText(AParams[I].Name, AName) then
      Exit(AParams[I].Value);
end;

function EngineConfigParamBool(const AParams: TEngineParamArray;
  const AName: String; ADefault: Boolean): Boolean;
var
  Value: String;
begin
  Value := LowerCase(Trim(EngineConfigParamValue(AParams, AName, '')));
  if Value = '' then
    Exit(ADefault);
  if (Value = 'true') or (Value = '1') or (Value = 'yes') or
    (Value = 'on') then
    Exit(True);
  if (Value = 'false') or (Value = '0') or (Value = 'no') or
    (Value = 'off') then
    Exit(False);
  Result := ADefault;
end;

function EngineConfigParamInt(const AParams: TEngineParamArray;
  const AName: String; ADefault: Integer): Integer;
begin
  Result := StrToIntDef(Trim(EngineConfigParamValue(AParams, AName, '')),
    ADefault);
end;

function EngineConfigParamFloat(const AParams: TEngineParamArray;
  const AName: String; ADefault: Double): Double;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  if not TryStrToFloat(Trim(EngineConfigParamValue(AParams, AName, '')),
    Result, FormatSettings) then
    Result := ADefault;
end;

function EngineConfigParamsFileName(const ADisplayName, AEngineFileName,
  ADefaultDirectory: String): String;
var
  BaseName: String;
  I: Integer;
  SafeName: String;
begin
  if AEngineFileName <> '' then
    SafeName := ChangeFileExt(ExtractFileName(AEngineFileName), '')
  else
    SafeName := Trim(ADisplayName);
  for I := 1 to Length(SafeName) do
    if not (SafeName[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.']) then
      SafeName[I] := '_';

  while Pos('__', SafeName) > 0 do
    SafeName := StringReplace(SafeName, '__', '_', [rfReplaceAll]);
  SafeName := Trim(SafeName);
  if SafeName = '' then
    SafeName := 'engine';

  if AEngineFileName <> '' then
    BaseName := ExtractFilePath(AEngineFileName)
  else
    BaseName := IncludeTrailingPathDelimiter(ADefaultDirectory);
  Result := BaseName + SafeName + '.params.json';
end;

function DefaultEngineProtocolConfig(AEngineIndex: Integer): TEngineProtocolConfig;
begin
  Result.Protocol := epHub;
  Result.HubId := 'Hub' + IntToStr(AEngineIndex);
  Result.IniFileName := '';
  Result.HubLaunchArgument := '';
  Result.DxpId := 'DXP' + IntToStr(AEngineIndex);
  Result.DxpIpAddress := DxpDefaultIp;
  Result.DxpSocketNumber := DxpDefaultSocket;
  Result.DxpLaunchArguments := '';
  Result.DxpRole := edrListener;
end;

function LoadEngineProtocolConfig(const AParams: TEngineParamArray;
  AEngineIndex: Integer): TEngineProtocolConfig;
var
  I: Integer;
  OldBoolValue: String;
  Value: String;
begin
  Result := DefaultEngineProtocolConfig(AEngineIndex);

  for I := 0 to High(AParams) do
  begin
    Value := AParams[I].Value;
    if SameText(AParams[I].Name, EngineTypeParamName) then
    begin
      if SameText(Value, 'dxp') then
        Result.Protocol := epDxp
      else
        Result.Protocol := epHub;
    end
    else if SameText(AParams[I].Name, HubIdParamName) then
      Result.HubId := Trim(Value)
    else if SameText(AParams[I].Name, EngineIniFileParamName) then
      Result.IniFileName := Trim(Value)
    else if SameText(AParams[I].Name, HubLaunchArgumentParamName) then
      Result.HubLaunchArgument := Value
    else if SameText(AParams[I].Name, OldHubLaunchArgumentParamName) then
      Result.HubLaunchArgument := Value
    else if SameText(AParams[I].Name, OldLaunchWithHubArgumentParamName) then
    begin
      OldBoolValue := Value;
      if SameText(OldBoolValue, 'true') then
        Result.HubLaunchArgument := 'hub'
      else
        Result.HubLaunchArgument := '';
    end
    else if SameText(AParams[I].Name, DxpIdParamName) then
      Result.DxpId := Trim(Value)
    else if SameText(AParams[I].Name, DxpIpParamName) and (Trim(Value) <> '') then
      Result.DxpIpAddress := Trim(Value)
    else if SameText(AParams[I].Name, DxpSocketParamName) and
      (Trim(Value) <> '') then
      Result.DxpSocketNumber := Trim(Value)
    else if SameText(AParams[I].Name, DxpLaunchArgumentsParamName) then
      Result.DxpLaunchArguments := Value
    else if SameText(AParams[I].Name, DxpRoleParamName) then
    begin
      if SameText(Value, 'client') or SameText(Value, 'connect') then
        Result.DxpRole := edrClient
      else
        Result.DxpRole := edrListener;
    end;
  end;

  if Trim(Result.HubId) = '' then
    Result.HubId := 'Hub' + IntToStr(AEngineIndex);
  if Trim(Result.DxpId) = '' then
    Result.DxpId := 'DXP' + IntToStr(AEngineIndex);
end;

procedure SaveEngineProtocolConfig(var AParams: TEngineParamArray;
  const AConfig: TEngineProtocolConfig);
var
  ProtocolText: String;
  RoleText: String;
begin
  if AConfig.Protocol = epDxp then
    ProtocolText := 'dxp'
  else
    ProtocolText := 'hub';
  if AConfig.DxpRole = edrClient then
    RoleText := 'connect'
  else
    RoleText := 'listen';

  AddOrUpdateParam(AParams, EngineTypeParamName, 'string', ProtocolText, False);
  AddOrUpdateParam(AParams, HubIdParamName, 'string', AConfig.HubId, False);
  AddOrUpdateParam(AParams, EngineIniFileParamName, 'string',
    AConfig.IniFileName, False);
  AddOrUpdateParam(AParams, HubLaunchArgumentParamName, 'string',
    AConfig.HubLaunchArgument, False);
  AddOrUpdateParam(AParams, DxpIdParamName, 'string', AConfig.DxpId, False);
  AddOrUpdateParam(AParams, DxpIpParamName, 'string',
    AConfig.DxpIpAddress, False);
  AddOrUpdateParam(AParams, DxpSocketParamName, 'int',
    AConfig.DxpSocketNumber, False);
  AddOrUpdateParam(AParams, DxpLaunchArgumentsParamName, 'string',
    AConfig.DxpLaunchArguments, False);
  AddOrUpdateParam(AParams, DxpRoleParamName, 'string', RoleText, False);
  RemoveEngineParam(AParams, OldHubLaunchArgumentParamName);
  RemoveEngineParam(AParams, OldLaunchWithHubArgumentParamName);
end;

procedure SyncEngineParamWithLegacy(var AParams: TEngineParamArray;
  const ANewName, AOldName, AType, ADefaultValue: String);
var
  I: Integer;
begin
  for I := 0 to High(AParams) do
    if SameText(AParams[I].Name, AOldName) then
    begin
      AddOrUpdateParam(AParams, ANewName, AType, AParams[I].Value, False);
      RemoveEngineParam(AParams, AOldName);
      Exit;
    end;
  AddOrUpdateParam(AParams, ANewName, AType, ADefaultValue, True);
end;

function EngineParamShouldSendToHub(const AName: String): Boolean;
begin
  Result := False;
  if AName = '' then
    Exit;
  if AnsiStartsText('gui-', AName) then
    Exit;
  if SameText(AName, OldHubLaunchArgumentParamName) then
    Exit;
  if SameText(AName, OldLaunchWithHubArgumentParamName) then
    Exit;
  if SameText(AName, OldSendStartingPositionParamName) then
    Exit;
  if SameText(AName, OldSingleCapturesIncludeCapturedSquareParamName) then
    Exit;
  if SameText(AName, OldAnalyzeSendsInfoParamName) then
    Exit;
  if SameText(AName, OldEvaluationDepthMinParamName) then
    Exit;
  if SameText(AName, OldEvaluationBarMaxParamName) then
    Exit;
  Result := True;
end;

end.
