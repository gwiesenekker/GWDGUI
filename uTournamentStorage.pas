unit uTournamentStorage;
{$mode objfpc}{$H+}
interface
uses FPJSON;
function ReadTournamentDocument(const AFileName: string): TJSONObject;
function TournamentDocumentText(AData: TJSONData): string;
function TournamentPdnTag(const AName, AValue: string): string;
function UnusedTournamentPdnPath(const ACandidate: string): string;
function TournamentPdnMatchesId(const AFileName, AId: string): Boolean;
implementation
uses Classes, SysUtils, JSONParser, uTournamentTypes, uTournamentResults, uPdn;

function TournamentDocumentText(AData: TJSONData): string;
var
  Output: TMemoryStream;

  procedure WriteText(const Text: RawByteString);
  begin
    if Text <> '' then Output.WriteBuffer(Text[1], Length(Text));
  end;

  procedure WriteValue(Value: TJSONData; Depth: Integer);
  var
    I: Integer;
    IsObject: Boolean;
  begin
    if Value = nil then
      WriteText('null')
    else if Value.JSONType in [jtObject, jtArray] then
    begin
      IsObject := Value.JSONType = jtObject;
      if IsObject then WriteText('{') else WriteText('[');
      for I := 0 to Value.Count - 1 do
      begin
        if I > 0 then WriteText(',');
        WriteText(LineEnding + StringOfChar(' ', (Depth + 1) * 2));
        if IsObject then
          WriteText('"' + StringToJSONString(TJSONObject(Value).Names[I]) + '": ');
        WriteValue(Value.Items[I], Depth + 1);
      end;
      if Value.Count > 0 then
        WriteText(LineEnding + StringOfChar(' ', Depth * 2));
      if IsObject then WriteText('}') else WriteText(']');
    end
    else
      WriteText(Value.AsJSON);
  end;

begin
  Output := TMemoryStream.Create;
  try
    WriteValue(AData, 0);
    WriteText(LineEnding);
    SetLength(Result, Output.Size);
    if Output.Size > 0 then Move(Output.Memory^, Result[1], Output.Size);
  finally
    Output.Free;
  end;
end;

type
  TTournamentPdnIdentityCheck = class
    Id: string;
    Matches: Boolean;
    procedure CheckGame(Game: TPdnGame; BytesRead, TotalBytes: Int64; var Stop: Boolean);
  end;

procedure TTournamentPdnIdentityCheck.CheckGame(Game: TPdnGame;
  BytesRead, TotalBytes: Int64; var Stop: Boolean);
begin
  if Game.TournamentId <> Id then
  begin
    Matches := False;
    Stop := True;
  end;
end;

function TournamentPdnMatchesId(const AFileName, AId: string): Boolean;
var Check: TTournamentPdnIdentityCheck;
begin
  Result := False;
  if (AId = '') or not FileExists(AFileName) then Exit;
  Check := TTournamentPdnIdentityCheck.Create;
  try
    Check.Id := AId;
    Check.Matches := True;
    try
      // Ownership needs headers, not move trees or large comment copies.
      ReadPdnGamesFromFile(AFileName, @Check.CheckGame, True);
      Result := Check.Matches;
    except Result := False; end;
  finally Check.Free; end;
end;

function UnusedTournamentPdnPath(const ACandidate: string): string;
var
  Id: TGUID;
  BaseName: string;
begin
  Result := ExpandFileName(ACandidate);
  BaseName := ChangeFileExt(Result, '');
  while FileExists(Result) or DirectoryExists(Result) do
  begin
    if CreateGUID(Id) <> 0 then
      raise EInOutError.Create('Could not create a tournament PDN name');
    Result := BaseName + '.' + GUIDToString(Id) + '.pdn';
  end;
end;

type
  TAllowedJsonTypes = set of TJSONType;

function TournamentPdnTag(const AName, AValue: string): string;
var
  Value: string;
begin
  Value := StringReplace(AValue, '\', '\\', [rfReplaceAll]);
  Value := StringReplace(Value, '"', '\"', [rfReplaceAll]);
  Value := StringReplace(Value, #13, ' ', [rfReplaceAll]);
  Value := StringReplace(Value, #10, ' ', [rfReplaceAll]);
  Result := '[' + AName + ' "' + Value + '"]';
end;

procedure CheckField(AObject: TJSONObject; const AName: string;
  ATypes: TAllowedJsonTypes);
var
  Value: TJSONData;
begin
  Value := AObject.Find(AName);
  if (Value <> nil) and not (Value.JSONType in ATypes) then
    raise EConvertError.Create('Invalid tournament field: ' + AName);
end;

procedure CheckInteger(AObject: TJSONObject; const AName: string; AMinimum: Integer);
var
  Value: TJSONData;
begin
  CheckField(AObject, AName, [jtNumber]);
  Value := AObject.Find(AName);
  if Value = nil then
    Exit;
  if (Value.AsFloat < AMinimum) or (Value.AsFloat > High(Integer)) or
    (Value.AsFloat <> Trunc(Value.AsFloat)) then
    raise EConvertError.Create('Invalid tournament integer: ' + AName);
end;

procedure ValidateRecord(Data: TJSONObject; AHistoryAllowed: Boolean);
var
  Items: TJSONArray;
  I: Integer;
  Value: string;
begin
  CheckInteger(Data, 'attempt', 1);
  CheckField(Data, 'pdn', [jtString]);
  CheckField(Data, 'capture_error', [jtString]);
  CheckField(Data, 'white_engine_key', [jtString]);
  CheckField(Data, 'black_engine_key', [jtString]);
  CheckField(Data, 'played_result', [jtString]);
  CheckField(Data, 'manual_result', [jtString]);
  Value := Data.Get('played_result', '');
  if (Value <> '') and (Value <> '*') and
    not TournamentResultIsKnown(ParseTournamentResult(Value)) then
    raise EConvertError.Create('Invalid played tournament result');
  Value := Data.Get('manual_result', '');
  if (Value <> '') and (Value <> '*') and
    not TournamentResultIsKnown(ParseTournamentResult(Value)) then
    raise EConvertError.Create('Invalid manual tournament result');
  CheckField(Data, 'history', [jtArray]);
  Items := TJSONArray(Data.Find('history'));
  if Items <> nil then
  begin
    if not AHistoryAllowed then
      raise EConvertError.Create('Tournament attempt history must not be nested');
    for I := 0 to Items.Count - 1 do
    begin
      if Items[I].JSONType <> jtObject then
        raise EConvertError.Create('Invalid tournament attempt history');
      ValidateRecord(TJSONObject(Items[I]), False);
    end;
  end;
end;

procedure ValidateDocument(Data: TJSONObject);
var
  Value: TJSONData;
  Games, Engines: TJSONArray;
  Game: TJSONObject;
  I: Integer;
  PairingType, ResultText: string;
  Seen: TStringList;
  PairingKey: string;
begin
  CheckInteger(Data, 'storage_version', 1);
  if Data.Get('storage_version', 1) > 2 then
    raise EConvertError.Create('Unsupported tournament storage version');
  if (Data.Find('tournament_id') <> nil) and
    (Data.Find('tournament_id').JSONType = jtString) and
    (Trim(Data.Find('tournament_id').AsString) = '') then
    raise EConvertError.Create('Empty tournament identity');
  CheckField(Data, 'legacy_pdn_file_name', [jtString]);
  CheckField(Data, 'tournament_name', [jtString]);
  CheckField(Data, 'starting_fen', [jtString]);
  CheckField(Data, 'tournament_id', [jtString]);
  CheckField(Data, 'pdn_file_name', [jtString]);
  CheckField(Data, 'pdn_owned', [jtBoolean]);
  CheckField(Data, 'pdn_published_hash', [jtString]);
  CheckInteger(Data, 'moves_per_period', 0);
  CheckInteger(Data, 'concurrent_games', 1);
  CheckField(Data, 'minutes_per_period', [jtNumber]);
  CheckField(Data, 'increment_seconds', [jtNumber]);
  Value := Data.Find('minutes_per_period');
  if (Value <> nil) and (Value.AsFloat < 0) then
    raise EConvertError.Create('Negative tournament time control');
  Value := Data.Find('increment_seconds');
  if (Value <> nil) and (Value.AsFloat < 0) then
    raise EConvertError.Create('Negative tournament increment');
  CheckField(Data, 'increment_mode', [jtString]);
  PairingType := Data.Get('increment_mode', 'from-start');
  if (PairingType <> 'from-start') and (PairingType <> 'after-move-limit') then
    raise EConvertError.Create('Unknown tournament increment mode');
  CheckField(Data, 'pairing_type', [jtString]);
  PairingType := Data.Get('pairing_type', TournamentTypeSingleRoundRobin);
  if (PairingType <> TournamentTypeSingleRoundRobin) and
    (PairingType <> TournamentTypeDoubleRoundRobin) and
    (PairingType <> TournamentTypeSwiss) then
    raise EConvertError.Create('Unknown tournament pairing type');
  CheckField(Data, 'selected_engines', [jtArray]);
  Engines := TJSONArray(Data.Find('selected_engines'));
  if Engines <> nil then
    for I := 0 to Engines.Count - 1 do
      if Engines[I].JSONType <> jtString then
        raise EConvertError.Create('Invalid selected tournament engine');
  CheckField(Data, 'selected_engine_keys', [jtArray]);
  Engines := TJSONArray(Data.Find('selected_engine_keys'));
  if Engines <> nil then
    for I := 0 to Engines.Count - 1 do
      if Engines[I].JSONType <> jtString then
        raise EConvertError.Create('Invalid selected tournament engine identity');
  CheckField(Data, 'games', [jtArray]);
  Games := TJSONArray(Data.Find('games'));
  if Games = nil then
    Exit;
  for I := 0 to Games.Count - 1 do
  begin
    if Games[I].JSONType <> jtObject then
      raise EConvertError.Create('Invalid tournament game');
    Game := TJSONObject(Games[I]);
    CheckField(Game, 'white_engine_key', [jtString]);
    CheckField(Game, 'black_engine_key', [jtString]);
    CheckField(Game, 'record', [jtObject]);
    if Game.Find('record') <> nil then
      ValidateRecord(TJSONObject(Game.Find('record')), True)
    else if Data.Get('storage_version', 1) >= 2 then
      raise EConvertError.Create('Tournament game record is missing');
    CheckInteger(Game, 'game', 1);
    CheckInteger(Game, 'round', 1);
    CheckField(Game, 'white', [jtString]);
    CheckField(Game, 'black', [jtString]);
    CheckField(Game, 'result', [jtString]);
    CheckField(Game, 'reason', [jtString]);
    ResultText := Game.Get('result', '*');
    if (ResultText <> '') and (ResultText <> '*') and
      not TournamentResultIsKnown(ParseTournamentResult(ResultText)) then
      raise EConvertError.Create('Invalid tournament game result');
  end;
  Seen := TStringList.Create;
  try
    Seen.Sorted := True;
    for I := 0 to Games.Count - 1 do
    begin
      Game := TJSONObject(Games[I]);
      PairingKey := IntToStr(Game.Get('round', 1)) + ':' +
        IntToStr(Game.Get('game', I + 1));
      if Seen.IndexOf(PairingKey) >= 0 then
        raise EConvertError.Create('Duplicate tournament pairing identity');
      Seen.Add(PairingKey);
    end;
  finally
    Seen.Free;
  end;
end;

function ReadTournamentDocument(const AFileName: string): TJSONObject;
var
  Lines: TStringList;
  Data: TJSONData;
begin
  Result := nil;
  Data := nil;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    Data := GetJSON(Lines.Text);
    if (Data = nil) or (Data.JSONType <> jtObject) then
      raise EConvertError.Create('Tournament document must be a JSON object');
    ValidateDocument(TJSONObject(Data));
    Result := TJSONObject(Data);
    Data := nil;
  finally
    Data.Free;
    Lines.Free;
  end;
end;
end.
