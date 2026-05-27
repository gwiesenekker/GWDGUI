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
function HubQuote(const AValue: String): String;
procedure LoadParamsFromJson(const AFileName: String; var AParams: TEngineParamArray);
procedure SaveParamsToJson(const AFileName: String; const AParams: TEngineParamArray);

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

function HubQuote(const AValue: String): String;
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
  begin
    if AValue[I] = '"' then
      Result += '\"'
    else
      Result += AValue[I];
  end;
  Result += '"';
end;

procedure LoadParamsFromJson(const AFileName: String; var AParams: TEngineParamArray);
var
  Data: TJSONData;
  I: Integer;
  Item: TJSONObject;
  ParamsArray: TJSONArray;
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
    if Data.JSONType <> jtArray then
      Exit;

    ParamsArray := TJSONArray(Data);
    SetLength(AParams, ParamsArray.Count);
    for I := 0 to ParamsArray.Count - 1 do
    begin
      Item := ParamsArray.Objects[I];
      AParams[I].Name := Item.Get('name', '');
      AParams[I].ParamType := Item.Get('type', '');
      AParams[I].Value := Item.Get('value', '');
    end;
  finally
    Data.Free;
  end;
end;

procedure SaveParamsToJson(const AFileName: String; const AParams: TEngineParamArray);
var
  Data: TJSONArray;
  I: Integer;
  Item: TJSONObject;
  JsonText: String;
  Lines: TStringList;
begin
  Data := TJSONArray.Create;
  try
    for I := 0 to High(AParams) do
    begin
      Item := TJSONObject.Create;
      Item.Add('name', AParams[I].Name);
      Item.Add('type', AParams[I].ParamType);
      Item.Add('value', AParams[I].Value);
      Data.Add(Item);
    end;

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
