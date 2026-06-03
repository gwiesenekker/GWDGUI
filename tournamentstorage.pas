unit TournamentStorage;

{$mode objfpc}{$H+}

interface

uses
  TournamentModel,
  TournamentPairing;

type
  TTournamentFileData = record
    EngineNames: TTournamentTextArray;
    Games: TTournamentPairingArray;
    GameNumbers: TTournamentIntArray;
    Minutes: Integer;
    Name: String;
    ResultReasons: TTournamentTextArray;
    Results: TTournamentTextArray;
    RoundNumbers: TTournamentIntArray;
    TournamentType: String;
  end;

procedure LoadTournamentFile(const AFileName: String; out AData: TTournamentFileData);
procedure SaveTournamentFile(const AFileName: String; const AData: TTournamentFileData);

implementation

uses
  Classes,
  FPJSON,
  JSONParser,
  SysUtils,
  TournamentTypes;

procedure ClearTournamentFileData(out AData: TTournamentFileData);
begin
  AData.Name := 'Tournament';
  AData.Minutes := 5;
  AData.TournamentType := TournamentTypeSingleRoundRobin;
  SetLength(AData.EngineNames, 0);
  SetLength(AData.Games, 0);
  SetLength(AData.GameNumbers, 0);
  SetLength(AData.ResultReasons, 0);
  SetLength(AData.Results, 0);
  SetLength(AData.RoundNumbers, 0);
end;

procedure AppendText(var AValues: TTournamentTextArray; const AValue: String);
var
  Index: Integer;
begin
  Index := Length(AValues);
  SetLength(AValues, Index + 1);
  AValues[Index] := AValue;
end;

procedure AppendGame(var AData: TTournamentFileData; ANumber, ARound: Integer;
  const AWhite, ABlack, AResult, AReason: String);
var
  Index: Integer;
begin
  Index := Length(AData.Games);
  SetLength(AData.Games, Index + 1);
  SetLength(AData.GameNumbers, Index + 1);
  SetLength(AData.ResultReasons, Index + 1);
  SetLength(AData.Results, Index + 1);
  SetLength(AData.RoundNumbers, Index + 1);
  AData.Games[Index].White := AWhite;
  AData.Games[Index].Black := ABlack;
  AData.GameNumbers[Index] := ANumber;
  AData.RoundNumbers[Index] := ARound;
  AData.Results[Index] := AResult;
  AData.ResultReasons[Index] := AReason;
end;

procedure LoadTournamentFile(const AFileName: String; out AData: TTournamentFileData);
var
  Data: TJSONData;
  Engines: TJSONData;
  Game: TJSONObject;
  Games: TJSONData;
  I: Integer;
  Lines: TStringList;
begin
  ClearTournamentFileData(AData);

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    Data := GetJSON(Lines.Text);
  finally
    Lines.Free;
  end;

  try
    if Data.JSONType <> jtObject then
      Exit;

    AData.Name := TJSONObject(Data).Get('name', 'Tournament');
    AData.Minutes := TJSONObject(Data).Get('minutes', 5);
    AData.TournamentType := TJSONObject(Data).Get('type',
      TournamentTypeSingleRoundRobin);

    Engines := TJSONObject(Data).Find('engines');
    if (Engines <> nil) and (Engines.JSONType = jtArray) then
      for I := 0 to TJSONArray(Engines).Count - 1 do
        AppendText(AData.EngineNames, TJSONArray(Engines).Strings[I]);

    Games := TJSONObject(Data).Find('games');
    if (Games <> nil) and (Games.JSONType = jtArray) then
      for I := 0 to TJSONArray(Games).Count - 1 do
        if TJSONArray(Games).Items[I].JSONType = jtObject then
        begin
          Game := TJSONObject(TJSONArray(Games).Items[I]);
          AppendGame(AData, Game.Get('number', I + 1),
            Game.Get('round', 1),
            Game.Get('white', ''), Game.Get('black', ''),
            Game.Get('result', '*'), Game.Get('reason', ''));
        end;
  finally
    Data.Free;
  end;
end;

procedure SaveTournamentFile(const AFileName: String; const AData: TTournamentFileData);
var
  Data: TJSONObject;
  EngineArray: TJSONArray;
  Game: TJSONObject;
  Games: TJSONArray;
  I: Integer;
  Lines: TStringList;
begin
  Data := TJSONObject.Create;
  try
    Data.Add('name', AData.Name);
    Data.Add('minutes', AData.Minutes);
    Data.Add('type', AData.TournamentType);

    EngineArray := TJSONArray.Create;
    Data.Add('engines', EngineArray);
    for I := 0 to High(AData.EngineNames) do
      EngineArray.Add(AData.EngineNames[I]);

    Games := TJSONArray.Create;
    Data.Add('games', Games);
    for I := 0 to High(AData.Games) do
    begin
      Game := TJSONObject.Create;
      Game.Add('number', AData.GameNumbers[I]);
      Game.Add('round', AData.RoundNumbers[I]);
      Game.Add('white', AData.Games[I].White);
      Game.Add('black', AData.Games[I].Black);
      Game.Add('result', AData.Results[I]);
      if (I <= High(AData.ResultReasons)) and
        (AData.ResultReasons[I] <> '') then
        Game.Add('reason', AData.ResultReasons[I]);
      Games.Add(Game);
    end;

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
