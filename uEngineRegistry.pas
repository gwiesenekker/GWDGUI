unit uEngineRegistry;

{$mode objfpc}{$H+}

interface

uses
  Classes, FPJSON, SysUtils;

type
  TExternalEngineKind = (eekHub, eekDxp);
  TDxpEngineRole = (derListen, derConnect);

  TExternalEngineDefinition = class
  private
    FArguments: string;
    FDxpHost: string;
    FDxpId: string;
    FDxpPort: Word;
    FDxpRole: TDxpEngineRole;
    FExecutableName: string;
    FExePath: string;
    FHubId: string;
    FIniContent: string;
    FIniFileName: string;
    FInitText: string;
    FKind: TExternalEngineKind;
    procedure SetExePath(const AValue: string);
    procedure SetKind(AValue: TExternalEngineKind);
  public
    constructor Create;
    procedure Assign(Source: TExternalEngineDefinition);
    function IdText: string;
    function KindText: string;
    procedure NormalizeIds;

    property Arguments: string read FArguments write FArguments;
    property DxpHost: string read FDxpHost write FDxpHost;
    property DxpId: string read FDxpId write FDxpId;
    property DxpPort: Word read FDxpPort write FDxpPort;
    property DxpRole: TDxpEngineRole read FDxpRole write FDxpRole;
    property ExecutableName: string read FExecutableName write FExecutableName;
    property ExePath: string read FExePath write SetExePath;
    property HubId: string read FHubId write FHubId;
    property IniContent: string read FIniContent write FIniContent;
    property IniFileName: string read FIniFileName write FIniFileName;
    property InitText: string read FInitText write FInitText;
    property Kind: TExternalEngineKind read FKind write SetKind;
  end;

  TExternalEngineList = class
  private
    FItems: TList;
    function GetCount: Integer;
    function GetItem(Index: Integer): TExternalEngineDefinition;
  public
    constructor Create;
    destructor Destroy; override;
    function Add(AEngine: TExternalEngineDefinition): Integer;
    procedure Delete(Index: Integer);
    procedure Clear;
    property Count: Integer read GetCount;
    property Items[Index: Integer]: TExternalEngineDefinition read GetItem; default;
  end;

procedure SplitLaunchArguments(const AText: string; AArgs: TStrings);
function ExpandEnginePlaceholders(const AText: string;
  AEngine: TExternalEngineDefinition): string;
procedure WriteEngineIniFile(const AIniFileName, AIniContent: string;
  AEngine: TExternalEngineDefinition);
procedure AddEngineReservationKeys(AEngine: TExternalEngineDefinition;
  AKeys: TStrings);
function EnginesJsonFileName: string;
function EngineIdentityKey(AEngine: TExternalEngineDefinition): string;
function EnginePickerDisplayName(AEngine: TExternalEngineDefinition;
  ASlotIndex: Integer): string;
procedure LoadExternalEngines(const AFileName: string; AEngines: TExternalEngineList);
procedure SaveExternalEngines(const AFileName: string; AEngines: TExternalEngineList);

implementation

uses
  JSONParser;

constructor TExternalEngineDefinition.Create;
begin
  inherited Create;
  FKind := eekHub;
  FDxpHost := '127.0.0.1';
  FDxpPort := 27531;
  FDxpRole := derListen;
  FInitText := 'init';
end;

procedure TExternalEngineDefinition.Assign(Source: TExternalEngineDefinition);
begin
  if Source = nil then
    Exit;
  FArguments := Source.Arguments;
  FDxpHost := Source.DxpHost;
  FDxpId := Source.DxpId;
  FDxpPort := Source.DxpPort;
  FDxpRole := Source.DxpRole;
  FExecutableName := Source.ExecutableName;
  FExePath := Source.ExePath;
  FHubId := Source.HubId;
  FIniContent := Source.IniContent;
  FIniFileName := Source.IniFileName;
  FInitText := Source.InitText;
  FKind := Source.Kind;
end;

function TExternalEngineDefinition.IdText: string;
begin
  if FKind = eekHub then
    Result := FHubId
  else
    Result := FDxpId;
end;

function TExternalEngineDefinition.KindText: string;
begin
  if FKind = eekHub then
    Result := 'hub'
  else
    Result := 'DXP';
end;

procedure TExternalEngineDefinition.NormalizeIds;
begin
  if FKind = eekHub then
    FDxpId := ''
  else
    FHubId := '';
end;

procedure TExternalEngineDefinition.SetExePath(const AValue: string);
begin
  FExePath := AValue;
  if FExecutableName = '' then
    FExecutableName := ExtractFileName(FExePath);
end;

procedure TExternalEngineDefinition.SetKind(AValue: TExternalEngineKind);
begin
  FKind := AValue;
  NormalizeIds;
end;

constructor TExternalEngineList.Create;
begin
  inherited Create;
  FItems := TList.Create;
end;

destructor TExternalEngineList.Destroy;
begin
  Clear;
  FItems.Free;
  inherited Destroy;
end;

function TExternalEngineList.Add(AEngine: TExternalEngineDefinition): Integer;
begin
  Result := FItems.Add(AEngine);
end;

procedure TExternalEngineList.Delete(Index: Integer);
begin
  TObject(FItems[Index]).Free;
  FItems.Delete(Index);
end;

procedure TExternalEngineList.Clear;
var
  I: Integer;
begin
  for I := FItems.Count - 1 downto 0 do
    TObject(FItems[I]).Free;
  FItems.Clear;
end;

function TExternalEngineList.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TExternalEngineList.GetItem(Index: Integer): TExternalEngineDefinition;
begin
  Result := TExternalEngineDefinition(FItems[Index]);
end;

procedure SplitLaunchArguments(const AText: string; AArgs: TStrings);
var
  Current: string;
  I: Integer;
  InQuotes: Boolean;
  QuoteChar: Char;
begin
  if AArgs = nil then
    Exit;

  AArgs.Clear;
  Current := '';
  InQuotes := False;
  QuoteChar := #0;
  I := 1;
  while I <= Length(AText) do
  begin
    if InQuotes then
    begin
      if AText[I] = QuoteChar then
      begin
        InQuotes := False;
        QuoteChar := #0;
      end
      else if (AText[I] = '\') and (I < Length(AText)) then
      begin
        Inc(I);
        Current += AText[I];
      end
      else
        Current += AText[I];
    end
    else if AText[I] in ['"', ''''] then
    begin
      InQuotes := True;
      QuoteChar := AText[I];
    end
    else if AText[I] in [' ', #9, #10, #13] then
    begin
      if Current <> '' then
      begin
        AArgs.Add(Current);
        Current := '';
      end;
    end
    else
      Current += AText[I];
    Inc(I);
  end;

  if Current <> '' then
    AArgs.Add(Current);
end;

function ExpandEnginePlaceholders(const AText: string;
  AEngine: TExternalEngineDefinition): string;
begin
  Result := AText;
  if AEngine = nil then
    Exit;
  Result := StringReplace(Result, '{ip}', AEngine.DxpHost,
    [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{host}', AEngine.DxpHost,
    [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{port}', IntToStr(AEngine.DxpPort),
    [rfReplaceAll, rfIgnoreCase]);
end;

procedure WriteEngineIniFile(const AIniFileName, AIniContent: string;
  AEngine: TExternalEngineDefinition);
var
  Lines: TStringList;
begin
  if Trim(AIniFileName) = '' then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.Text := ExpandEnginePlaceholders(AIniContent, AEngine);
    Lines.SaveToFile(AIniFileName);
  finally
    Lines.Free;
  end;
end;

function EnginesJsonFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'engines.json';
end;

function EngineIdentityKey(AEngine: TExternalEngineDefinition): string;
begin
  Result := '';
  if AEngine = nil then
    Exit;

  Result := LowerCase(AEngine.KindText) + '|' +
    LowerCase(ExpandFileName(AEngine.ExePath)) + '|' +
    LowerCase(AEngine.IdText);
end;

procedure AddEngineReservationKeys(AEngine: TExternalEngineDefinition;
  AKeys: TStrings);
var
  HostText: string;
begin
  if (AEngine = nil) or (AKeys = nil) then
    Exit;

  AKeys.Add(EngineIdentityKey(AEngine));
  if AEngine.Kind <> eekDxp then
    Exit;

  if AEngine.DxpRole = derListen then
    AKeys.Add('dxp-listen-port|' + IntToStr(AEngine.DxpPort))
  else
  begin
    HostText := LowerCase(Trim(AEngine.DxpHost));
    if HostText = '' then
      HostText := '127.0.0.1';
    AKeys.Add('dxp-connect|' + HostText + '|' + IntToStr(AEngine.DxpPort));
  end;
end;

function EnginePickerDisplayName(AEngine: TExternalEngineDefinition;
  ASlotIndex: Integer): string;
var
  DisplayName: string;
begin
  if AEngine = nil then
    Exit('');

  DisplayName := Trim(AEngine.IdText);
  if DisplayName = '' then
    DisplayName := ChangeFileExt(AEngine.ExecutableName, '');
  if DisplayName = '' then
    DisplayName := ChangeFileExt(ExtractFileName(AEngine.ExePath), '');
  if DisplayName = '' then
    DisplayName := 'Engine';

  Result := DisplayName + ' (Engine ' + IntToStr(ASlotIndex) + ' ' +
    AEngine.KindText + ' engine)';
end;

function EngineFromJson(AObject: TJSONObject): TExternalEngineDefinition;
var
  KindText: string;
  RoleText: string;
begin
  Result := TExternalEngineDefinition.Create;
  if AObject = nil then
    Exit;

  Result.ExecutableName := AObject.Get('executable', '');
  if AObject.Get('path', '') <> '' then
    Result.ExePath := IncludeTrailingPathDelimiter(AObject.Get('path', '')) +
      Result.ExecutableName
  else
    Result.ExePath := AObject.Get('exe_path', '');
  if Result.ExecutableName = '' then
    Result.ExecutableName := ExtractFileName(Result.ExePath);

  Result.HubId := AObject.Get('hub_id', '');
  Result.DxpId := AObject.Get('dxp_id', '');
  Result.Arguments := AObject.Get('arguments', '');
  Result.InitText := AObject.Get('init', Result.InitText);
  Result.DxpHost := AObject.Get('dxp_host', Result.DxpHost);
  Result.DxpPort := AObject.Get('dxp_port', Result.DxpPort);

  KindText := LowerCase(AObject.Get('kind', AObject.Get('protocol', '')));
  if (KindText = 'dxp') or ((Result.DxpId <> '') and (Result.HubId = '')) then
    Result.Kind := eekDxp
  else
    Result.Kind := eekHub;

  RoleText := LowerCase(AObject.Get('dxp_role', 'listen'));
  if RoleText = 'connect' then
    Result.DxpRole := derConnect
  else
    Result.DxpRole := derListen;
  Result.NormalizeIds;
end;

function EngineToJson(AEngine: TExternalEngineDefinition): TJSONObject;
begin
  Result := TJSONObject.Create;
  if AEngine = nil then
    Exit;

  Result.Add('executable', AEngine.ExecutableName);
  Result.Add('path', ExtractFilePath(AEngine.ExePath));
  Result.Add('hub_id', AEngine.HubId);
  Result.Add('dxp_id', AEngine.DxpId);
  Result.Add('kind', LowerCase(AEngine.KindText));
  Result.Add('arguments', AEngine.Arguments);
  Result.Add('init', AEngine.InitText);
  Result.Add('dxp_host', AEngine.DxpHost);
  Result.Add('dxp_port', AEngine.DxpPort);
  if AEngine.DxpRole = derConnect then
    Result.Add('dxp_role', 'connect')
  else
    Result.Add('dxp_role', 'listen');
end;

procedure LoadExternalEngines(const AFileName: string; AEngines: TExternalEngineList);
var
  Data: TJSONData;
  I: Integer;
  Lines: TStringList;
begin
  if AEngines = nil then
    Exit;

  AEngines.Clear;
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
    if Data.JSONType <> jtArray then
      Exit;
    for I := 0 to TJSONArray(Data).Count - 1 do
      if TJSONArray(Data).Items[I].JSONType = jtObject then
        AEngines.Add(EngineFromJson(TJSONObject(TJSONArray(Data).Items[I])));
  finally
    Data.Free;
  end;
end;

procedure SaveExternalEngines(const AFileName: string; AEngines: TExternalEngineList);
var
  Data: TJSONArray;
  I: Integer;
  Lines: TStringList;
begin
  if (AFileName = '') or (AEngines = nil) then
    Exit;

  Data := TJSONArray.Create;
  try
    for I := 0 to AEngines.Count - 1 do
      Data.Add(EngineToJson(AEngines[I]));
    Lines := TStringList.Create;
    try
      Lines.Text := Data.FormatJSON([], 2) + LineEnding;
      Lines.SaveToFile(AFileName);
    finally
      Lines.Free;
    end;
  finally
    Data.Free;
  end;
end;

end.
