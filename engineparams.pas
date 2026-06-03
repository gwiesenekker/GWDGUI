unit EngineParams;

{$mode objfpc}{$H+}

interface

type
  TEngineParam = record
    Name: String;
    ParamType: String;
    Value: String;
  end;

  TEngineParamArray = array of TEngineParam;

procedure AddOrUpdateParam(var AParams: TEngineParamArray; const AName, AType,
  AValue: String; AKeepExistingValue: Boolean);
function ExtractHubArgument(const ALine, AName: String): String;
procedure LoadParamsFromJson(const AFileName: String; var AParams: TEngineParamArray);
procedure LoadParamsFromJson(const AFileName, ASection: String;
  var AParams: TEngineParamArray);
procedure SaveParamsToJson(const AFileName: String; const AParams: TEngineParamArray);
procedure SaveParamsToJson(const AFileName, ASection: String;
  const AParams: TEngineParamArray);

implementation

uses
  Classes,
  FPJSON,
  JSONParser,
  SysUtils;

function ParamIndexByName(const AParams: TEngineParamArray; const AName: String): Integer;
var
  I: Integer;
begin
  for I := 0 to High(AParams) do
    if SameText(AParams[I].Name, AName) then
      Exit(I);
  Result := -1;
end;

function ParamsSectionName(const AParams: TEngineParamArray): String;
var
  I: Integer;
begin
  Result := 'hub';
  for I := 0 to High(AParams) do
    if SameText(AParams[I].Name, 'gui-engine-type') then
    begin
      if SameText(AParams[I].Value, 'dxp') then
        Result := 'dxp'
      else
        Result := 'hub';
      Exit;
    end;
end;

function NormalizeSectionName(const ASection: String): String;
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
  begin
    if AArray.Items[I].JSONType = jtObject then
    begin
      Item := TJSONObject(AArray.Items[I]);
      AParams[I].Name := Item.Get('name', '');
      AParams[I].ParamType := Item.Get('type', '');
      AParams[I].Value := Item.Get('value', '');
    end;
  end;
end;

function CloneJsonArray(AArray: TJSONArray): TJSONArray;
var
  Data: TJSONData;
begin
  if AArray = nil then
  begin
    Result := TJSONArray.Create;
    Exit;
  end;

  Data := GetJSON(AArray.AsJSON);
  if Data.JSONType = jtArray then
    Result := TJSONArray(Data)
  else if Data <> nil then
  begin
    Data.Free;
    Result := TJSONArray.Create;
  end
  else
    Result := TJSONArray.Create;
end;

function JsonObjectArray(AObject: TJSONObject; const AName: String): TJSONArray;
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

procedure AddOrUpdateParam(var AParams: TEngineParamArray; const AName, AType,
  AValue: String; AKeepExistingValue: Boolean);
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

function ExtractHubArgument(const ALine, AName: String): String;
var
  P: Integer;
  StartPos: Integer;
  StopPos: Integer;
begin
  Result := '';
  P := Pos(' ' + AName + '=', ' ' + ALine);
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

procedure LoadParamsFromJson(const AFileName: String; var AParams: TEngineParamArray);
var
  Data: TJSONData;
  Section: String;
  Stream: TFileStream;
begin
  SetLength(AParams, 0);
  if not FileExists(AFileName) then
    Exit;

  Stream := TFileStream.Create(AFileName, fmOpenRead);
  try
    Data := GetJSON(Stream);
  finally
    Stream.Free;
  end;
  try
    if Data.JSONType = jtObject then
    begin
      Section := TJSONObject(Data).Get('active', '');
      if Section = '' then
        if TJSONObject(Data).Find('dxp') <> nil then
          Section := 'dxp'
        else
          Section := 'hub';
      LoadParamsFromJson(AFileName, Section, AParams);
    end;
  finally
    Data.Free;
  end;
end;

procedure LoadParamsFromJson(const AFileName, ASection: String;
  var AParams: TEngineParamArray);
var
  Data: TJSONData;
  ParamsArray: TJSONArray;
  Section: String;
  Stream: TFileStream;
begin
  SetLength(AParams, 0);
  if not FileExists(AFileName) then
    Exit;

  Stream := TFileStream.Create(AFileName, fmOpenRead);
  try
    Data := GetJSON(Stream);
  finally
    Stream.Free;
  end;
  try
    if Data.JSONType = jtObject then
    begin
      Section := NormalizeSectionName(ASection);
      ParamsArray := JsonObjectArray(TJSONObject(Data), Section);
      JsonToParamsArray(ParamsArray, AParams);
    end;
  finally
    Data.Free;
  end;
end;

procedure SaveParamsToJson(const AFileName: String; const AParams: TEngineParamArray);
begin
  SaveParamsToJson(AFileName, ParamsSectionName(AParams), AParams);
end;

procedure SaveParamsToJson(const AFileName, ASection: String;
  const AParams: TEngineParamArray);
var
  Data: TJSONObject;
  ExistingArray: TJSONArray;
  ExistingData: TJSONData;
  JsonText: String;
  Lines: TStringList;
  Section: String;
begin
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
        end
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

end.
