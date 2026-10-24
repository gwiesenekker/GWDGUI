unit uTournamentStorage;
{$mode objfpc}{$H+}
interface
uses FPJSON;
function ReadTournamentDocument(const AFileName: string): TJSONObject;
function TournamentPdnTag(const AName, AValue: string): string;
implementation
uses Classes, SysUtils, JSONParser, uTournamentTypes, uTournamentResults;

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

procedure ValidateDocument(Data: TJSONObject);
var
  Value: TJSONData;
  Games, Engines: TJSONArray;
  Game: TJSONObject;
  I: Integer;
  PairingType, ResultText: string;
begin
  CheckField(Data, 'tournament_name', [jtString]);
  CheckField(Data, 'starting_fen', [jtString]);
  CheckField(Data, 'tournament_id', [jtString]);
  CheckField(Data, 'pdn_file_name', [jtString]);
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
  CheckField(Data, 'games', [jtArray]);
  Games := TJSONArray(Data.Find('games'));
  if Games = nil then
    Exit;
  for I := 0 to Games.Count - 1 do
  begin
    if Games[I].JSONType <> jtObject then
      raise EConvertError.Create('Invalid tournament game');
    Game := TJSONObject(Games[I]);
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
