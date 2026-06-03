unit EngineCommands;

{$mode objfpc}{$H+}

interface

uses
  DraughtsRules,
  EngineParams,
  GameHistory;

type
  THubGoCommand = (hgcAnalyze, hgcMcts, hgcThink);
  THubLevelCommand = (hlcMoveTime, hlcGameTime);

  THubSearchCommand = record
    PositionCommand: String;
    LevelCommand: String;
    GoCommand: String;
  end;

function BuildHubPositionCommand(AHistory: TGameHistory;
  ASendStartingPosition: Boolean;
  ASingleCapturesIncludeCapturedSquare: Boolean): String;
function BuildHubSearchCommand(AHistory: TGameHistory;
  ASendStartingPosition: Boolean;
  ASingleCapturesIncludeCapturedSquare: Boolean; ALevelCommand: THubLevelCommand;
  AMoveTimeSeconds, ARemainingTimeSeconds: Double; AGoCommand: THubGoCommand):
  THubSearchCommand;
function BuildDxpGameReqCommand(const ABoard: TBoard; ASideToMove,
  AEngineSide: TSide; AGameMinutes: Double;
  const AParams: TEngineParamArray): String;
function BuildDxpGameEndCommand(ACode: Char): String;
function BuildDxpMoveCommand(const AMove: TMove;
  ATotalTimeUsedSeconds: Integer): String;
function HubLevelCommandText(ALevelCommand: THubLevelCommand;
  AMoveTimeSeconds, ARemainingTimeSeconds: Double): String;
function HubGoCommandText(AGoCommand: THubGoCommand): String;

implementation

uses
  DxpProtocol,
  HubProtocol,
  Math,
  SysUtils;

function EngineParamIntValue(const AParams: TEngineParamArray;
  const AName: String; ADefault: Integer): Integer;
var
  P: Integer;
begin
  Result := ADefault;
  for P := 0 to High(AParams) do
    if SameText(AParams[P].Name, AName) then
      Exit(StrToIntDef(AParams[P].Value, ADefault));
end;

function HubGoCommandText(AGoCommand: THubGoCommand): String;
begin
  case AGoCommand of
    hgcAnalyze: Result := 'go analyze';
    hgcMcts: Result := 'go mcts';
    hgcThink: Result := 'go think';
  end;
end;

function HubLevelCommandText(ALevelCommand: THubLevelCommand;
  AMoveTimeSeconds, ARemainingTimeSeconds: Double): String;
begin
  case ALevelCommand of
    hlcMoveTime: Result := HubBuildMoveTimeLevelCommand(AMoveTimeSeconds);
    hlcGameTime: Result := HubBuildGameTimeLevelCommand(ARemainingTimeSeconds);
  end;
end;

function BuildHubPositionCommand(AHistory: TGameHistory;
  ASendStartingPosition: Boolean;
  ASingleCapturesIncludeCapturedSquare: Boolean): String;
var
  I: Integer;
  MoveStart: Integer;
  MoveText: String;
  RootBoard: TBoard;
  RootSide: TSide;
begin
  AHistory.HubRootForMoveList(ASendStartingPosition, RootBoard, RootSide,
    MoveStart);

  Result := 'pos pos=' + HubPositionStringFor(RootBoard, RootSide);
  MoveText := '';
  for I := MoveStart to Min(AHistory.CurrentPly, Length(AHistory.Moves)) - 1 do
  begin
    if MoveText <> '' then
      MoveText += ' ';
    MoveText += MoveToHubString(AHistory.Moves[I],
      ASingleCapturesIncludeCapturedSquare);
  end;
  if MoveText <> '' then
    Result += ' moves=' + HubQuote(MoveText);
end;

function BuildHubSearchCommand(AHistory: TGameHistory;
  ASendStartingPosition: Boolean;
  ASingleCapturesIncludeCapturedSquare: Boolean; ALevelCommand: THubLevelCommand;
  AMoveTimeSeconds, ARemainingTimeSeconds: Double; AGoCommand: THubGoCommand):
  THubSearchCommand;
begin
  Result.PositionCommand := BuildHubPositionCommand(AHistory,
    ASendStartingPosition, ASingleCapturesIncludeCapturedSquare);
  Result.LevelCommand := HubLevelCommandText(ALevelCommand, AMoveTimeSeconds,
    ARemainingTimeSeconds);
  Result.GoCommand := HubGoCommandText(AGoCommand);
end;

function BuildDxpGameReqCommand(const ABoard: TBoard; ASideToMove,
  AEngineSide: TSide; AGameMinutes: Double;
  const AParams: TEngineParamArray): String;
var
  GameMoves: Integer;
begin
  GameMoves := EngineParamIntValue(AParams, 'dxp_game_moves', 75);
  Result := DxpBuildGameReqPacket(ABoard, ASideToMove, AEngineSide,
    AGameMinutes, GameMoves, 'International Draughts GUI');
end;

function BuildDxpGameEndCommand(ACode: Char): String;
begin
  Result := DxpBuildGameEndPacket(ACode);
end;

function BuildDxpMoveCommand(const AMove: TMove;
  ATotalTimeUsedSeconds: Integer): String;
begin
  Result := DxpBuildMovePacket(AMove, ATotalTimeUsedSeconds);
end;

end.
