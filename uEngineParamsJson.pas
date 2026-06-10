unit uEngineParamsJson;

{$mode objfpc}{$H+}

interface

uses
  uEngineRegistry;

type
  TEngineParam = record
    Name: string;
    ParamType: string;
    Value: string;
  end;

  TEngineParamArray = array of TEngineParam;

procedure AddOrUpdateParam(var AParams: TEngineParamArray; const AName,
  AType, AValue: string; AKeepExistingValue: Boolean);
function EngineParamValue(const AParams: TEngineParamArray; const AName,
  ADefault: string): string;
function EngineParamsFileName(const AEngineFileName: string): string;
function EngineParamShouldSendToHub(const AName: string): Boolean;
function ExtractHubArgument(const ALine, AName: string): string;
function HubParamQuote(const AValue: string): string;
procedure LoadEngineParamsFromJson(const AFileName, ASection: string;
  var AParams: TEngineParamArray);
procedure SeedDefaultGuiParams(var AParams: TEngineParamArray;
  AEngine: TExternalEngineDefinition);
procedure SortEngineParams(var AParams: TEngineParamArray);
procedure SaveEngineParamsToJson(const AFileName, ASection: string;
  const AParams: TEngineParamArray);
procedure SaveEngineDefinitionParams(AEngine: TExternalEngineDefinition;
  const AParams: TEngineParamArray);

implementation

uses
  Classes, FPJSON, JSONParser, SysUtils;

function ParamIndexByName(const AParams: TEngineParamArray;
  const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AParams) do
    if SameText(AParams[I].Name, AName) then
      Exit(I);
  Result := -1;
end;

function NormalizeSectionName(const ASection: string): string;
begin
  if SameText(ASection, 'dxp') then
    Result := 'dxp'
  else
    Result := 'hub';
end;

function ParamsArrayToJson(const AParams: TEngineParamArray): TJSONArray;
var
  I: Integer;
  Item: TJSONObject;
begin
  Result := TJSONArray.Create;
  for I := 0 to High(AParams) do
  begin
    Item := TJSONObject.Create;
    Item.Add('name', AParams[I].Name);
    Item.Add('type', AParams[I].ParamType);
    Item.Add('value', AParams[I].Value);
    Result.Add(Item);
  end;
end;

function CloneJsonArray(AArray: TJSONArray): TJSONArray;
var
  Data: TJSONData;
begin
  if AArray = nil then
    Exit(TJSONArray.Create);

  Data := GetJSON(AArray.AsJSON);
  if Data.JSONType = jtArray then
    Result := TJSONArray(Data)
  else
  begin
    Data.Free;
    Result := TJSONArray.Create;
  end;
end;

function JsonObjectArray(AObject: TJSONObject; const AName: string): TJSONArray;
var
  Data: TJSONData;
begin
  Result := nil;
  if AObject = nil then
    Exit;
  Data := AObject.Find(AName);
  if (Data <> nil) and (Data.JSONType = jtArray) then
    Result := TJSONArray(Data);
end;

procedure JsonToParamsArray(AArray: TJSONArray; var AParams: TEngineParamArray);
var
  I: Integer;
  Item: TJSONObject;
begin
  SetLength(AParams, 0);
  if AArray = nil then
    Exit;

  SetLength(AParams, AArray.Count);
  for I := 0 to AArray.Count - 1 do
    if AArray.Items[I].JSONType = jtObject then
    begin
      Item := TJSONObject(AArray.Items[I]);
      AParams[I].Name := Item.Get('name', '');
      AParams[I].ParamType := Item.Get('type', '');
      AParams[I].Value := Item.Get('value', '');
    end;
end;

procedure AddOrUpdateParam(var AParams: TEngineParamArray; const AName,
  AType, AValue: string; AKeepExistingValue: Boolean);
var
  ExistingParam: Boolean;
  Index: Integer;
begin
  if AName = '' then
    Exit;

  Index := ParamIndexByName(AParams, AName);
  ExistingParam := Index >= 0;
  if Index < 0 then
  begin
    SetLength(AParams, Length(AParams) + 1);
    Index := High(AParams);
    AParams[Index].Name := AName;
  end;

  if AType <> '' then
    AParams[Index].ParamType := AType;
  if (not AKeepExistingValue) or (not ExistingParam) then
    AParams[Index].Value := AValue;
end;

function EngineParamValue(const AParams: TEngineParamArray; const AName,
  ADefault: string): string;
var
  Index: Integer;
begin
  Index := ParamIndexByName(AParams, AName);
  if Index >= 0 then
    Result := AParams[Index].Value
  else
    Result := ADefault;
end;

function EngineParamsFileName(const AEngineFileName: string): string;
begin
  if AEngineFileName = '' then
    Result := ''
  else
    Result := ChangeFileExt(AEngineFileName, '.params.json');
end;

function EngineParamShouldSendToHub(const AName: string): Boolean;
begin
  Result := (AName <> '') and (Copy(LowerCase(AName), 1, 4) <> 'gui-');
end;

function HubParamQuote(const AValue: string): string;
var
  I: Integer;
  NeedsQuotes: Boolean;
begin
  NeedsQuotes := AValue = '';
  for I := 1 to Length(AValue) do
    if AValue[I] in [' ', '=', '"'] then
      NeedsQuotes := True;

  if not NeedsQuotes then
    Exit(AValue);

  Result := '"';
  for I := 1 to Length(AValue) do
    if AValue[I] = '"' then
      Result += '\"'
    else
      Result += AValue[I];
  Result += '"';
end;

function ExtractHubArgument(const ALine, AName: string): string;
var
  LowerLine: string;
  LowerName: string;
  P: Integer;
  StartPos: Integer;
  StopPos: Integer;
begin
  Result := '';
  LowerLine := LowerCase(ALine);
  LowerName := LowerCase(AName);
  P := Pos(' ' + LowerName + '=', ' ' + LowerLine);
  if P = 0 then
    Exit;

  StartPos := P + Length(AName) + 1;
  if (StartPos <= Length(ALine)) and (ALine[StartPos] = '"') then
  begin
    Inc(StartPos);
    StopPos := StartPos;
    while (StopPos <= Length(ALine)) and (ALine[StopPos] <> '"') do
      Inc(StopPos);
    Result := Copy(ALine, StartPos, StopPos - StartPos);
  end
  else
  begin
    StopPos := StartPos;
    while (StopPos <= Length(ALine)) and (ALine[StopPos] > ' ') do
      Inc(StopPos);
    Result := Copy(ALine, StartPos, StopPos - StartPos);
  end;
end;

procedure LoadEngineParamsFromJson(const AFileName, ASection: string;
  var AParams: TEngineParamArray);
var
  Data: TJSONData;
  Lines: TStringList;
  Section: string;
begin
  SetLength(AParams, 0);
  if (AFileName = '') or (not FileExists(AFileName)) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    Data := GetJSON(Lines.Text);
  finally
    Lines.Free;
  end;
  try
    if Data.JSONType = jtObject then
    begin
      Section := NormalizeSectionName(ASection);
      JsonToParamsArray(JsonObjectArray(TJSONObject(Data), Section), AParams);
    end;
  finally
    Data.Free;
  end;
end;

procedure SeedDefaultGuiParams(var AParams: TEngineParamArray;
  AEngine: TExternalEngineDefinition);
var
  ProtocolText: string;
  RoleText: string;
begin
  if (AEngine <> nil) and (AEngine.Kind = eekDxp) then
    ProtocolText := 'dxp'
  else
    ProtocolText := 'hub';

  if (AEngine <> nil) and (AEngine.DxpRole = derConnect) then
    RoleText := 'connect'
  else
    RoleText := 'listen';

  AddOrUpdateParam(AParams, 'gui-engine-type', 'string', ProtocolText, False);
  if AEngine <> nil then
  begin
    AddOrUpdateParam(AParams, 'gui-hub-id', 'string', AEngine.HubId, False);
    AddOrUpdateParam(AParams, 'gui-hub-launch-argument', 'string',
      AEngine.Arguments, False);
    AddOrUpdateParam(AParams, 'gui-dxp-id', 'string', AEngine.DxpId, False);
    AddOrUpdateParam(AParams, 'gui-dxp-ip', 'string', AEngine.DxpHost, False);
    AddOrUpdateParam(AParams, 'gui-dxp-socket', 'int',
      IntToStr(AEngine.DxpPort), False);
    AddOrUpdateParam(AParams, 'gui-dxp-launch-arguments', 'string',
      AEngine.Arguments, False);
  end
  else
  begin
    AddOrUpdateParam(AParams, 'gui-hub-id', 'string', '', False);
    AddOrUpdateParam(AParams, 'gui-hub-launch-argument', 'string', '', False);
    AddOrUpdateParam(AParams, 'gui-dxp-id', 'string', '', False);
    AddOrUpdateParam(AParams, 'gui-dxp-ip', 'string', '127.0.0.1', False);
    AddOrUpdateParam(AParams, 'gui-dxp-socket', 'int', '27531', False);
    AddOrUpdateParam(AParams, 'gui-dxp-launch-arguments', 'string', '', False);
  end;
  AddOrUpdateParam(AParams, 'gui-dxp-role', 'string', RoleText, False);
  AddOrUpdateParam(AParams, 'gui-ini-file', 'string', '', True);
  AddOrUpdateParam(AParams, 'gui-send-starting-position', 'bool', 'true', True);
  AddOrUpdateParam(AParams, 'gui-single-captures-include-captured-square',
    'bool', 'true', True);
  AddOrUpdateParam(AParams, 'gui-engine-supports-mcts', 'bool', 'false', True);
  AddOrUpdateParam(AParams, 'gui-score-perspective', 'string',
    'side-to-move', True);
  AddOrUpdateParam(AParams, 'gui-evaluation-bar-depth-min', 'int', '4', True);
  AddOrUpdateParam(AParams, 'gui-evaluation-bar-score-max', 'int', '1000', True);
end;

function IsGuiParamName(const AName: string): Boolean;
begin
  Result := Copy(LowerCase(AName), 1, 4) = 'gui-';
end;

function CompareEngineParams(const ALeft, ARight: TEngineParam): Integer;
var
  LeftGui: Boolean;
  RightGui: Boolean;
begin
  LeftGui := IsGuiParamName(ALeft.Name);
  RightGui := IsGuiParamName(ARight.Name);
  if LeftGui and (not RightGui) then
    Exit(-1);
  if RightGui and (not LeftGui) then
    Exit(1);
  Result := CompareText(ALeft.Name, ARight.Name);
end;

procedure SortEngineParams(var AParams: TEngineParamArray);
var
  I: Integer;
  J: Integer;
  Temp: TEngineParam;
begin
  for I := 0 to High(AParams) - 1 do
    for J := I + 1 to High(AParams) do
      if CompareEngineParams(AParams[I], AParams[J]) > 0 then
      begin
        Temp := AParams[I];
        AParams[I] := AParams[J];
        AParams[J] := Temp;
      end;
end;

procedure SaveEngineParamsToJson(const AFileName, ASection: string;
  const AParams: TEngineParamArray);
var
  Data: TJSONObject;
  ExistingArray: TJSONArray;
  ExistingData: TJSONData;
  JsonText: string;
  Lines: TStringList;
  Section: string;
begin
  if AFileName = '' then
    Exit;

  Section := NormalizeSectionName(ASection);
  Data := TJSONObject.Create;
  try
    if FileExists(AFileName) then
    begin
      Lines := TStringList.Create;
      try
        Lines.LoadFromFile(AFileName);
        ExistingData := GetJSON(Lines.Text);
      finally
        Lines.Free;
      end;
      try
        if ExistingData.JSONType = jtObject then
        begin
          ExistingArray := JsonObjectArray(TJSONObject(ExistingData), 'hub');
          if ExistingArray <> nil then
            Data.Add('hub', CloneJsonArray(ExistingArray));
          ExistingArray := JsonObjectArray(TJSONObject(ExistingData), 'dxp');
          if ExistingArray <> nil then
            Data.Add('dxp', CloneJsonArray(ExistingArray));
        end;
      finally
        ExistingData.Free;
      end;
    end;

    if Data.Find(Section) <> nil then
      Data.Delete(Section);
    Data.Add(Section, ParamsArrayToJson(AParams));
    if Data.Find('active') <> nil then
      Data.Delete('active');
    Data.Add('active', Section);

    JsonText := Data.FormatJSON([], 2) + LineEnding;
    Lines := TStringList.Create;
    try
      Lines.Text := JsonText;
      Lines.SaveToFile(AFileName);
    finally
      Lines.Free;
    end;
  finally
    Data.Free;
  end;
end;

procedure SaveEngineDefinitionParams(AEngine: TExternalEngineDefinition;
  const AParams: TEngineParamArray);
var
  Params: TEngineParamArray;
  Section: string;
begin
  if AEngine = nil then
    Exit;

  Params := Copy(AParams);
  SeedDefaultGuiParams(Params, AEngine);
  SortEngineParams(Params);
  if AEngine.Kind = eekDxp then
  begin
    Section := 'dxp';
    AddOrUpdateParam(Params, 'gui-engine-type', 'string', 'dxp', False);
    AddOrUpdateParam(Params, 'gui-dxp-id', 'string', AEngine.DxpId, False);
    AddOrUpdateParam(Params, 'gui-dxp-ip', 'string', AEngine.DxpHost, False);
    AddOrUpdateParam(Params, 'gui-dxp-socket', 'int',
      IntToStr(AEngine.DxpPort), False);
    if AEngine.DxpRole = derConnect then
      AddOrUpdateParam(Params, 'gui-dxp-role', 'string', 'connect', False)
    else
      AddOrUpdateParam(Params, 'gui-dxp-role', 'string', 'listen', False);
    AddOrUpdateParam(Params, 'gui-dxp-launch-arguments', 'string',
      AEngine.Arguments, False);
  end
  else
  begin
    Section := 'hub';
    AddOrUpdateParam(Params, 'gui-engine-type', 'string', 'hub', False);
    AddOrUpdateParam(Params, 'gui-hub-id', 'string', AEngine.HubId, False);
    AddOrUpdateParam(Params, 'gui-hub-launch-argument', 'string',
      AEngine.Arguments, False);
    AddOrUpdateParam(Params, 'gui-hub-init', 'string', AEngine.InitText, False);
  end;

  SaveEngineParamsToJson(EngineParamsFileName(AEngine.ExePath), Section, Params);
end;

end.
