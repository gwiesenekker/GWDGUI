unit EngineRegistry;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  FPJSON;

type
  TRegisteredEngine = record
    Executable: String;
    Path: String;
    HubId: String;
    DxpId: String;
  end;

  TRegisteredEngineArray = array of TRegisteredEngine;

function RegisteredEnginesFileNameForApplication(
  const AApplicationFileName: String): String;
function RegisteredEngineFromJson(AEngine: TJSONObject): TRegisteredEngine;
function RegisteredEngineToJson(const AEngine: TRegisteredEngine): TJSONObject;
function RegisteredEngineFileName(AEngine: TJSONObject): String;
function RegisteredEngineFileNameForDisplayName(const ARegistryFileName,
  ADisplayName: String): String;
function RegisteredEngineProtocolId(AEngine: TJSONObject;
  const AProtocol: String): String;
function RegisteredEngineProtocolIdForFileName(const ARegistryFileName,
  AEngineFileName, AProtocol: String): String;
function RegisteredDxpPortUsed(const ARegistryFileName, ASelectedEngineFileName,
  AIpAddress: String; APort: Integer): Boolean;
function RegisteredEngineSupportsProtocol(AEngine: TJSONObject;
  const AProtocol: String): Boolean;
function RegisteredEngineProtocolDisplayName(AEngine: TJSONObject;
  AIndex: Integer; const AProtocol: String): String;
function LoadRegisteredEngines(const AFileName: String): TJSONArray;
procedure LoadRegisteredTournamentEngines(const AFileName: String;
  ANames, AFileNames, AProtocols: TStrings);
procedure SaveRegisteredEngines(const AFileName: String; AData: TJSONArray);
procedure NormalizeRegisteredEngineEntries(var AEngines: TRegisteredEngineArray);
procedure NormalizeRegisteredEngineIdsInJson(AData: TJSONArray);
function AddRegisteredEngineExecutable(const ARegistryFileName,
  AEngineFileName, AHubId, ADxpId: String): Boolean;
function UpdateRegisteredEngineProtocolId(const ARegistryFileName,
  AEngineFileName, AEngineId, AProtocol: String): Boolean;

implementation

uses
  EngineConfig,
  EngineParams,
  JSONParser,
  SysUtils;

function RegisteredEnginesFileNameForApplication(
  const AApplicationFileName: String): String;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(AApplicationFileName)) +
    'engines.json';
end;

function RegisteredEngineFromJson(AEngine: TJSONObject): TRegisteredEngine;
begin
  Result.Executable := '';
  Result.Path := '';
  Result.HubId := '';
  Result.DxpId := '';
  if AEngine = nil then
    Exit;

  Result.Executable := AEngine.Get('executable', '');
  Result.Path := AEngine.Get('path', '');
  Result.HubId := AEngine.Get('hub_id', '');
  Result.DxpId := AEngine.Get('dxp_id', '');

  if (Result.HubId = '') and SameText(AEngine.Get('protocol', ''), 'hub') then
    Result.HubId := AEngine.Get('reported_id', AEngine.Get('id', ''));
  if (Result.DxpId = '') and SameText(AEngine.Get('protocol', ''), 'dxp') then
    Result.DxpId := AEngine.Get('reported_id', AEngine.Get('id', ''));
end;

function RegisteredEngineToJson(const AEngine: TRegisteredEngine): TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('executable', AEngine.Executable);
  Result.Add('path', AEngine.Path);
  Result.Add('hub_id', AEngine.HubId);
  Result.Add('dxp_id', AEngine.DxpId);
end;

function RegisteredEngineFileName(AEngine: TJSONObject): String;
var
  Entry: TRegisteredEngine;
begin
  Result := '';
  if AEngine = nil then
    Exit;

  Entry := RegisteredEngineFromJson(AEngine);
  if (Entry.Path = '') or (Entry.Executable = '') then
    Exit;
  Result := IncludeTrailingPathDelimiter(Entry.Path) + Entry.Executable;
end;

function RegisteredEngineFileNameForDisplayName(const ARegistryFileName,
  ADisplayName: String): String;
var
  Data: TJSONArray;
  DisplayText: String;
  EngineFileName: String;
  EngineObject: TJSONObject;
  ExeText: String;
  I: Integer;
  IdText: String;
begin
  Result := '';
  if (ADisplayName = '') or (ARegistryFileName = '') or
    (not FileExists(ARegistryFileName)) then
    Exit;

  Data := LoadRegisteredEngines(ARegistryFileName);
  try
    for I := 0 to Data.Count - 1 do
      if Data.Items[I].JSONType = jtObject then
      begin
        EngineObject := TJSONObject(Data.Items[I]);
        ExeText := EngineObject.Get('executable', '');
        IdText := EngineObject.Get('id', '');
        DisplayText := ChangeFileExt(ExeText, '');
        EngineFileName := RegisteredEngineFileName(EngineObject);
        if SameText(ExeText, ADisplayName) or
          SameText(ChangeFileExt(ExeText, ''), ADisplayName) or
          SameText(IdText, ADisplayName) or
          SameText(IdText + ' (' + ExeText + ')', ADisplayName) or
          SameText(DisplayText, ADisplayName) then
        begin
          Result := EngineFileName;
          Exit;
        end;
      end;
  finally
    Data.Free;
  end;
end;

function RegisteredEngineProtocolId(AEngine: TJSONObject;
  const AProtocol: String): String;
var
  IdText: String;
begin
  Result := '';
  if AEngine = nil then
    Exit;

  if SameText(AProtocol, 'hub') then
    Result := Trim(AEngine.Get('hub_id', ''))
  else if SameText(AProtocol, 'dxp') then
    Result := Trim(AEngine.Get('dxp_id', ''));

  if Result <> '' then
    Exit;

  IdText := Trim(AEngine.Get('id', ''));
  if SameText(AEngine.Get('protocol', ''), AProtocol) then
    Result := Trim(AEngine.Get('reported_id', IdText));
end;

function RegisteredEngineProtocolIdForFileName(const ARegistryFileName,
  AEngineFileName, AProtocol: String): String;
var
  Data: TJSONArray;
  EngineFileName: String;
  I: Integer;
  SelectedFileName: String;
begin
  Result := '';
  if (ARegistryFileName = '') or (AEngineFileName = '') or
    (not FileExists(ARegistryFileName)) then
    Exit;

  SelectedFileName := ExpandFileName(AEngineFileName);
  Data := LoadRegisteredEngines(ARegistryFileName);
  try
    for I := 0 to Data.Count - 1 do
      if Data.Items[I].JSONType = jtObject then
      begin
        EngineFileName := RegisteredEngineFileName(TJSONObject(Data.Items[I]));
        if EngineFileName = '' then
          Continue;
        if not SameText(ExpandFileName(EngineFileName), SelectedFileName) then
          Continue;
        Result := RegisteredEngineProtocolId(TJSONObject(Data.Items[I]),
          AProtocol);
        Exit;
      end;
  finally
    Data.Free;
  end;
end;

function RegisteredDxpPortUsed(const ARegistryFileName, ASelectedEngineFileName,
  AIpAddress: String; APort: Integer): Boolean;
var
  Data: TJSONArray;
  EngineFileName: String;
  I: Integer;
  Params: TEngineParamArray;
  ParamsFileName: String;
  SelectedFileName: String;
begin
  Result := False;
  Params := nil;
  if (ARegistryFileName = '') or (not FileExists(ARegistryFileName)) then
    Exit;

  SelectedFileName := ExpandFileName(ASelectedEngineFileName);
  Data := LoadRegisteredEngines(ARegistryFileName);
  try
    for I := 0 to Data.Count - 1 do
      if Data.Items[I].JSONType = jtObject then
      begin
        EngineFileName := RegisteredEngineFileName(TJSONObject(Data.Items[I]));
        if EngineFileName = '' then
          Continue;
        EngineFileName := ExpandFileName(EngineFileName);
        if SameText(EngineFileName, SelectedFileName) then
          Continue;

        ParamsFileName := EngineConfigParamsFileName('', EngineFileName, '');
        if not FileExists(ParamsFileName) then
          Continue;

        SetLength(Params, 0);
        LoadParamsFromJson(ParamsFileName, 'dxp', Params);
        if SameText(EngineConfigParamValue(Params, EngineTypeParamName, ''),
          'dxp') and
          SameText(EngineConfigParamValue(Params, DxpIpParamName, DxpDefaultIp),
          AIpAddress) and
          (StrToIntDef(EngineConfigParamValue(Params, DxpSocketParamName, ''),
          0) = APort) then
          Exit(True);
      end;
  finally
    Data.Free;
  end;
end;

function RegisteredEngineSupportsProtocol(AEngine: TJSONObject;
  const AProtocol: String): Boolean;
begin
  Result := RegisteredEngineProtocolId(AEngine, AProtocol) <> '';
end;

function RegisteredEngineProtocolDisplayName(AEngine: TJSONObject;
  AIndex: Integer; const AProtocol: String): String;
var
  ProtocolId: String;
  ProtocolText: String;
begin
  Result := '';
  ProtocolId := RegisteredEngineProtocolId(AEngine, AProtocol);
  if ProtocolId = '' then
    Exit;

  if SameText(AProtocol, 'dxp') then
    ProtocolText := 'DXP'
  else
    ProtocolText := 'Hub';
  Result := ProtocolId + ' (Engine ' + IntToStr(AIndex) + ' ' +
    ProtocolText + ' mode)';
end;

function LoadRegisteredEngines(const AFileName: String): TJSONArray;
var
  ExistingData: TJSONData;
  I: Integer;
  Lines: TStringList;
begin
  Result := TJSONArray.Create;
  if (AFileName = '') or (not FileExists(AFileName)) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    ExistingData := GetJSON(Lines.Text);
  finally
    Lines.Free;
  end;

  try
    if ExistingData.JSONType = jtArray then
      for I := 0 to TJSONArray(ExistingData).Count - 1 do
        if TJSONArray(ExistingData).Items[I].JSONType = jtObject then
          Result.Add(RegisteredEngineToJson(RegisteredEngineFromJson(
            TJSONObject(TJSONArray(ExistingData).Items[I]))));
  finally
    ExistingData.Free;
  end;
end;

procedure LoadRegisteredTournamentEngines(const AFileName: String;
  ANames, AFileNames, AProtocols: TStrings);
var
  Data: TJSONArray;
  DisplayText: String;
  EngineFileName: String;
  EngineObject: TJSONObject;
  I: Integer;
  IdText: String;
  SortedEngines: TStringList;

  procedure AddTournamentEngine(const ADisplayText, AEngineFileName,
    AProtocol: String);
  var
    BaseDisplayText: String;
    DirectoryText: String;
    Suffix: Integer;
  begin
    if ADisplayText = '' then
      Exit;

    BaseDisplayText := ADisplayText;
    DirectoryText := ExtractFileName(ExcludeTrailingPathDelimiter(
      ExtractFilePath(AEngineFileName)));
    if DirectoryText = '' then
      DirectoryText := ExtractFileName(AEngineFileName);
    if SortedEngines.IndexOf(BaseDisplayText) >= 0 then
      BaseDisplayText := ADisplayText + ' (' + DirectoryText + ')';
    Suffix := 2;
    while SortedEngines.IndexOf(BaseDisplayText) >= 0 do
    begin
      BaseDisplayText := ADisplayText + ' (' + DirectoryText + ' ' +
        IntToStr(Suffix) + ')';
      Inc(Suffix);
    end;

    SortedEngines.Add(BaseDisplayText);
    if AFileNames <> nil then
      AFileNames.Values[BaseDisplayText] := AEngineFileName;
    if AProtocols <> nil then
      AProtocols.Values[BaseDisplayText] := AProtocol;
  end;

begin
  if ANames <> nil then
    ANames.Clear;
  if AFileNames <> nil then
    AFileNames.Clear;
  if AProtocols <> nil then
    AProtocols.Clear;

  if (ANames = nil) or (AFileName = '') or (not FileExists(AFileName)) then
    Exit;

  Data := LoadRegisteredEngines(AFileName);
  try
    SortedEngines := TStringList.Create;
    try
      SortedEngines.Sorted := True;
      SortedEngines.Duplicates := dupAccept;

      for I := 0 to Data.Count - 1 do
        if Data.Items[I].JSONType = jtObject then
        begin
          EngineObject := TJSONObject(Data.Items[I]);
          EngineFileName := RegisteredEngineFileName(EngineObject);
          IdText := EngineObject.Get('id', '');

          if RegisteredEngineSupportsProtocol(EngineObject, 'hub') then
          begin
            DisplayText := RegisteredEngineProtocolDisplayName(EngineObject,
              I + 1, 'hub');
            AddTournamentEngine(DisplayText, EngineFileName, 'hub');
          end;
          if RegisteredEngineSupportsProtocol(EngineObject, 'dxp') then
          begin
            DisplayText := RegisteredEngineProtocolDisplayName(EngineObject,
              I + 1, 'dxp');
            AddTournamentEngine(DisplayText, EngineFileName, 'dxp');
          end;
          if (not RegisteredEngineSupportsProtocol(EngineObject, 'hub')) and
            (not RegisteredEngineSupportsProtocol(EngineObject, 'dxp')) then
          begin
            if IdText = '' then
              IdText := ChangeFileExt(EngineObject.Get('executable', ''), '');
            if IdText = '' then
              IdText := EngineObject.Get('executable', '');
            AddTournamentEngine(IdText, EngineFileName,
              LowerCase(Trim(EngineObject.Get('protocol', ''))));
          end;
        end;

      ANames.Assign(SortedEngines);
    finally
      SortedEngines.Free;
    end;
  finally
    Data.Free;
  end;
end;

procedure SaveRegisteredEngines(const AFileName: String; AData: TJSONArray);
var
  Lines: TStringList;
begin
  if (AFileName = '') or (AData = nil) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.Text := AData.FormatJSON([], 2) + LineEnding;
    Lines.SaveToFile(AFileName);
  finally
    Lines.Free;
  end;
end;

function StripRegisteredEngineNumericSuffix(const AText: String): String;
var
  P: Integer;
  Suffix: String;
begin
  Result := AText;
  P := Length(Result);
  while (P > 0) and (Result[P] in ['0'..'9']) do
    Dec(P);
  if (P > 1) and (Result[P] = '_') and (P < Length(Result)) then
  begin
    Suffix := Copy(Result, P + 1, Length(Result) - P);
    if StrToIntDef(Suffix, -1) > 0 then
      Result := Copy(Result, 1, P - 1);
  end;
end;

procedure NormalizeRegisteredEngineEntries(var AEngines: TRegisteredEngineArray);
var
  BaseIds: array of String;
  BaseText: String;
  Counts: TStringList;
  I: Integer;
  Seen: TStringList;
  SeenCount: Integer;

  procedure IncValue(AList: TStringList; const AKey: String);
  begin
    AList.Values[AKey] := IntToStr(StrToIntDef(AList.Values[AKey], 0) + 1);
  end;

begin
  BaseIds := nil;
  SetLength(BaseIds, Length(AEngines));
  Counts := TStringList.Create;
  Seen := TStringList.Create;
  try
    for I := 0 to High(AEngines) do
    begin
      BaseText := Trim(AEngines[I].DxpId);
      if BaseText = '' then
        BaseText := Trim(AEngines[I].HubId);
      if BaseText = '' then
        BaseText := StripRegisteredEngineNumericSuffix(Trim(AEngines[I].Executable));
      if BaseText = '' then
        BaseText := ChangeFileExt(ExtractFileName(AEngines[I].Path), '');
      if BaseText = '' then
        BaseText := Trim(AEngines[I].Path);
      BaseIds[I] := BaseText;
      if BaseText <> '' then
        IncValue(Counts, BaseText);
    end;

    for I := 0 to High(AEngines) do
      if BaseIds[I] <> '' then
      begin
        if StrToIntDef(Counts.Values[BaseIds[I]], 0) > 1 then
        begin
          SeenCount := StrToIntDef(Seen.Values[BaseIds[I]], 0) + 1;
          Seen.Values[BaseIds[I]] := IntToStr(SeenCount);
          AEngines[I].Executable := BaseIds[I] + '_' + IntToStr(SeenCount);
        end
        else
          AEngines[I].Executable := BaseIds[I];
      end;
  finally
    Counts.Free;
    Seen.Free;
  end;
end;

procedure NormalizeRegisteredEngineIdsInJson(AData: TJSONArray);
var
  Engines: TRegisteredEngineArray;
  I: Integer;
  Item: TJSONObject;
  ReportedId: String;

begin
  if AData = nil then
    Exit;

  Engines := nil;
  SetLength(Engines, AData.Count);
  for I := 0 to AData.Count - 1 do
    if AData.Items[I].JSONType = jtObject then
    begin
      Item := TJSONObject(AData.Items[I]);
      Engines[I].Executable := Trim(Item.Get('id', ''));
      Engines[I].Path := Trim(Item.Get('executable', ''));
      Engines[I].HubId := Trim(Item.Get('reported_id', ''));
      Engines[I].DxpId := '';
    end;

  NormalizeRegisteredEngineEntries(Engines);

  for I := 0 to AData.Count - 1 do
    if AData.Items[I].JSONType = jtObject then
    begin
      Item := TJSONObject(AData.Items[I]);
      ReportedId := StripRegisteredEngineNumericSuffix(Engines[I].Executable);
      Item.Strings['reported_id'] := ReportedId;
      Item.Strings['id'] := Engines[I].Executable;
    end;
end;

function AddRegisteredEngineExecutable(const ARegistryFileName,
  AEngineFileName, AHubId, ADxpId: String): Boolean;
var
  Data: TJSONArray;
  ExeText: String;
  I: Integer;
  Item: TJSONObject;
  PathText: String;
begin
  Result := False;
  if AEngineFileName = '' then
    Exit;

  PathText := ExcludeTrailingPathDelimiter(ExtractFilePath(AEngineFileName));
  ExeText := ExtractFileName(AEngineFileName);
  Data := LoadRegisteredEngines(ARegistryFileName);
  try
    for I := 0 to Data.Count - 1 do
      if (Data.Items[I].JSONType = jtObject) and
        SameText(TJSONObject(Data.Items[I]).Get('path', ''), PathText) and
        SameText(TJSONObject(Data.Items[I]).Get('executable', ''), ExeText) then
        Exit;

    Item := TJSONObject.Create;
    Item.Add('path', PathText);
    Item.Add('executable', ExeText);
    Item.Add('hub_id', AHubId);
    Item.Add('dxp_id', ADxpId);
    Data.Add(Item);
    SaveRegisteredEngines(ARegistryFileName, Data);
    Result := True;
  finally
    Data.Free;
  end;
end;

function UpdateRegisteredEngineProtocolId(const ARegistryFileName,
  AEngineFileName, AEngineId, AProtocol: String): Boolean;
var
  Data: TJSONArray;
  ExeText: String;
  I: Integer;
  Item: TJSONObject;
  PathText: String;
begin
  Result := False;
  if (ARegistryFileName = '') or (not FileExists(ARegistryFileName)) or
    (AEngineFileName = '') or (AEngineId = '') then
    Exit;

  PathText := ExcludeTrailingPathDelimiter(ExtractFilePath(AEngineFileName));
  ExeText := ExtractFileName(AEngineFileName);
  Data := LoadRegisteredEngines(ARegistryFileName);
  try
    for I := 0 to Data.Count - 1 do
      if Data.Items[I].JSONType = jtObject then
      begin
        Item := TJSONObject(Data.Items[I]);
        if SameText(Item.Get('path', ''), PathText) and
          SameText(Item.Get('executable', ''), ExeText) then
        begin
          if SameText(AProtocol, 'hub') and
            (Item.Get('hub_id', '') <> AEngineId) then
          begin
            Item.Strings['hub_id'] := AEngineId;
            Result := True;
          end
          else if SameText(AProtocol, 'dxp') and
            (Item.Get('dxp_id', '') <> AEngineId) then
          begin
            Item.Strings['dxp_id'] := AEngineId;
            Result := True;
          end;
        end;
      end;

    if Result then
      SaveRegisteredEngines(ARegistryFileName, Data);
  finally
    Data.Free;
  end;
end;

end.
