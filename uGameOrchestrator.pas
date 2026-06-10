unit uGameOrchestrator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  uDraughtsBoard, uEngineBase, uGameMoveHistory, uPdn;

type
  TClockIncrementMode = (
    cimFromStart,
    cimAfterMoveLimit
  );

  TGameOrchestratorState = (
    gosWaiting,
    gosRunning,
    gosGameOver,
    gosStopped,
    gosError
  );

  TTimeControl = record
    MovesPerPeriod: Integer;
    MinutesPerPeriod: Double;
    IncrementSeconds: Double;
    IncrementMode: TClockIncrementMode;
  end;

  TOrchestratorLogEvent = procedure(Sender: TObject; const AMessage: string) of object;

  TGameOrchestrator = class
  private
    FBoard: TDraughtsBoard;
    FEngines: array[TDraughtsSide] of TDraughtsEngine;
    FGameResult: string;
    FLastError: string;
    FLog: TStringList;
    FLogTarget: TStrings;
    FConsecutiveReversiblePlyCount: Integer;
    FMovesInPeriod: array[TDraughtsSide] of Integer;
    FMoveHistory: TGameMoveHistory;
    FMovesPlayed: TStringList;
    FOnLog: TOrchestratorLogEvent;
    FPositionHistory: TStringList;
    FRemainingSeconds: array[TDraughtsSide] of Double;
    FStartingFEN: string;
    FState: TGameOrchestratorState;
    FTimeControl: TTimeControl;
    FTotalMovesBySide: array[TDraughtsSide] of Integer;
    FUsedSeconds: array[TDraughtsSide] of Double;
    procedure ApplyTimeUsed(ASide: TDraughtsSide; ASecondsUsed: Double);
    function BuildLevelMessage(ASide: TDraughtsSide): string;
    function BuildPositionMessage: string;
    procedure CheckDrawsAfterMove;
    procedure ChangeState(ANewState: TGameOrchestratorState; const AReason: string);
    function CountCurrentPositionRepetitions: Integer;
    function GetCurrentSide: TDraughtsSide;
    function ExtractDoneMove(const AResponse: string): string;
    procedure FinishGame(const AResult, AReason: string);
    function GetEngine(ASide: TDraughtsSide): TDraughtsEngine;
    function GetMovesRemaining(ASide: TDraughtsSide): Integer;
    function GetMoveAnnotationsText: string;
    function GetMovesPlayedText: string;
    function GetRemainingSeconds(ASide: TDraughtsSide): Double;
    function GetUsedSeconds(ASide: TDraughtsSide): Double;
    procedure LogMessage(const AMessage: string);
    procedure ReleaseEngines;
    procedure ResetClocks;
    procedure RefreshMovesPlayedCache;
    procedure SetEngine(ASide: TDraughtsSide; AEngine: TDraughtsEngine);
    procedure StartEngineSessions;
  public
    constructor Create;
    destructor Destroy; override;

    procedure NewGame(const AStartingFEN: string);
    procedure PlayMove(const AMove: string; ASide: TDraughtsSide;
      ASecondsUsed: Double; const ASource: string = 'move');
    function PlayNextMove: string;
    procedure RequestStopEngines;
    procedure StopEngines;

    property Board: TDraughtsBoard read FBoard;
    property CurrentSide: TDraughtsSide read GetCurrentSide;
    property Engine[ASide: TDraughtsSide]: TDraughtsEngine read GetEngine write SetEngine;
    property GameResult: string read FGameResult;
    property LastError: string read FLastError;
    property Log: TStringList read FLog;
    property LogTarget: TStrings read FLogTarget write FLogTarget;
    property MoveHistory: TGameMoveHistory read FMoveHistory;
    property MovesPlayed: TStringList read FMovesPlayed;
    property MoveAnnotationsText: string read GetMoveAnnotationsText;
    property MovesPlayedText: string read GetMovesPlayedText;
    property OnLog: TOrchestratorLogEvent read FOnLog write FOnLog;
    property RemainingSeconds[ASide: TDraughtsSide]: Double read GetRemainingSeconds;
    property StartingFEN: string read FStartingFEN;
    property State: TGameOrchestratorState read FState;
    property TimeControl: TTimeControl read FTimeControl write FTimeControl;
    property UsedSeconds[ASide: TDraughtsSide]: Double read GetUsedSeconds;
  end;

function DefaultTimeControl: TTimeControl;
function OrchestratorStateToString(AState: TGameOrchestratorState): string;
function SideToString(ASide: TDraughtsSide): string;

implementation

function DefaultTimeControl: TTimeControl;
begin
  Result.MovesPerPeriod := 75;
  Result.MinutesPerPeriod := 5;
  Result.IncrementSeconds := 0;
  Result.IncrementMode := cimFromStart;
end;

function OrchestratorStateToString(AState: TGameOrchestratorState): string;
begin
  case AState of
    gosWaiting:
      Result := 'waiting';
    gosRunning:
      Result := 'running';
    gosGameOver:
      Result := 'game over';
    gosStopped:
      Result := 'stopped';
    gosError:
      Result := 'error';
  else
    Result := 'unknown';
  end;
end;

function SideToString(ASide: TDraughtsSide): string;
begin
  if ASide = dsWhite then
    Result := 'white'
  else
    Result := 'black';
end;

function SecondsBetween(const AStartTime, AEndTime: TDateTime): Double;
begin
  Result := (AEndTime - AStartTime) * 24 * 60 * 60;
end;

constructor TGameOrchestrator.Create;
begin
  inherited Create;
  FBoard := TDraughtsBoard.Create;
  FLog := TStringList.Create;
  FMovesPlayed := TStringList.Create;
  FMoveHistory := TGameMoveHistory.Create;
  FPositionHistory := TStringList.Create;
  FTimeControl := DefaultTimeControl;
  FState := gosWaiting;
  FGameResult := '*';
  FStartingFEN := FBoard.StartingFEN;
  ResetClocks;
  LogMessage('created; state=' + OrchestratorStateToString(FState));
end;

destructor TGameOrchestrator.Destroy;
begin
  ReleaseEngines;
  FPositionHistory.Free;
  FMovesPlayed.Free;
  FMoveHistory.Free;
  FLog.Free;
  FBoard.Free;
  inherited Destroy;
end;

procedure TGameOrchestrator.ReleaseEngines;
var
  LSide: TDraughtsSide;
begin
  for LSide := Low(TDraughtsSide) to High(TDraughtsSide) do
    FreeAndNil(FEngines[LSide]);
end;

procedure TGameOrchestrator.StopEngines;
var
  LSide: TDraughtsSide;
begin
  LogMessage('stop engines requested');
  for LSide := Low(TDraughtsSide) to High(TDraughtsSide) do
    if FEngines[LSide] <> nil then
      FEngines[LSide].Stop;
end;

procedure TGameOrchestrator.RequestStopEngines;
var
  LSide: TDraughtsSide;
begin
  for LSide := Low(TDraughtsSide) to High(TDraughtsSide) do
    if FEngines[LSide] <> nil then
      FEngines[LSide].RequestStop;
end;

procedure TGameOrchestrator.LogMessage(const AMessage: string);
var
  LMessage: string;
begin
  LMessage := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
    ' [orchestrator] current_state=' + OrchestratorStateToString(FState) + '; ' + AMessage;
  FLog.Add(LMessage);
  if Assigned(FLogTarget) then
    FLogTarget.Add(LMessage);
  if Assigned(FOnLog) then
    FOnLog(Self, LMessage);
end;

procedure TGameOrchestrator.ChangeState(ANewState: TGameOrchestratorState;
  const AReason: string);
var
  LOldState: TGameOrchestratorState;
  LMessage: string;
begin
  if FState = ANewState then
    Exit;

  LOldState := FState;
  FState := ANewState;
  LMessage := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
    ' [orchestrator] transition; old_state=' + OrchestratorStateToString(LOldState) +
    '; new_state=' + OrchestratorStateToString(ANewState);
  if AReason <> '' then
    LMessage := LMessage + '; ' + AReason;
  FLog.Add(LMessage);
  if Assigned(FLogTarget) then
    FLogTarget.Add(LMessage);
  if Assigned(FOnLog) then
    FOnLog(Self, LMessage);
end;

function TGameOrchestrator.GetEngine(ASide: TDraughtsSide): TDraughtsEngine;
begin
  Result := FEngines[ASide];
end;

function TGameOrchestrator.GetCurrentSide: TDraughtsSide;
begin
  Result := FBoard.SideToMove;
end;

procedure TGameOrchestrator.SetEngine(ASide: TDraughtsSide; AEngine: TDraughtsEngine);
begin
  if FEngines[ASide] = AEngine then
    Exit;

  if FEngines[ASide] <> nil then
    LogMessage('engine released; side=' + SideToString(ASide) +
      '; engine=' + FEngines[ASide].EngineName);
  FreeAndNil(FEngines[ASide]);

  FEngines[ASide] := AEngine;
  if AEngine <> nil then
    LogMessage('engine assigned; side=' + SideToString(ASide) +
      '; engine=' + AEngine.EngineName)
  else
    LogMessage('engine cleared; side=' + SideToString(ASide));
end;

procedure TGameOrchestrator.ResetClocks;
var
  LSide: TDraughtsSide;
begin
  for LSide := Low(TDraughtsSide) to High(TDraughtsSide) do
  begin
    FRemainingSeconds[LSide] := FTimeControl.MinutesPerPeriod * 60;
    FUsedSeconds[LSide] := 0;
    FMovesInPeriod[LSide] := 0;
    FTotalMovesBySide[LSide] := 0;
  end;
end;

procedure TGameOrchestrator.NewGame(const AStartingFEN: string);
begin
  FStartingFEN := Trim(AStartingFEN);
  FBoard.LoadFromFEN(FStartingFEN);
  FMoveHistory.Clear;
  RefreshMovesPlayedCache;
  FPositionHistory.Clear;
  FPositionHistory.Add(FBoard.PositionKey);
  FConsecutiveReversiblePlyCount := 0;
  FLastError := '';
  FGameResult := '*';
  ResetClocks;
  ChangeState(gosRunning, 'new game');
  LogMessage('new game; fen=' + FStartingFEN +
    '; moves_per_period=' + IntToStr(FTimeControl.MovesPerPeriod) +
    '; minutes=' + FloatToStr(FTimeControl.MinutesPerPeriod) +
    '; increment_seconds=' + FloatToStr(FTimeControl.IncrementSeconds));
  StartEngineSessions;
end;

procedure TGameOrchestrator.StartEngineSessions;
var
  LSide: TDraughtsSide;
begin
  for LSide := Low(TDraughtsSide) to High(TDraughtsSide) do
    if FEngines[LSide] <> nil then
    begin
      LogMessage('begin engine game; side=' + SideToString(LSide) +
        '; engine=' + FEngines[LSide].EngineName +
        '; game_minutes=' + FloatToStr(FTimeControl.MinutesPerPeriod) +
        '; game_moves=' + IntToStr(FTimeControl.MovesPerPeriod));
      FEngines[LSide].BeginGame(FStartingFEN, LSide,
        FTimeControl.MinutesPerPeriod, FTimeControl.MovesPerPeriod);
    end;
end;

function TGameOrchestrator.GetMovesPlayedText: string;
begin
  Result := FMoveHistory.MovesText;
end;

function TGameOrchestrator.GetMoveAnnotationsText: string;
begin
  Result := FMoveHistory.AnnotationsText;
end;

procedure TGameOrchestrator.RefreshMovesPlayedCache;
begin
  FMoveHistory.FillPureMoves(FMovesPlayed);
end;

function TGameOrchestrator.BuildPositionMessage: string;
begin
  Result := 'pos=' + FStartingFEN + ' moves="' + MovesPlayedText + '"';
end;

function TGameOrchestrator.CountCurrentPositionRepetitions: Integer;
var
  I: Integer;
  LCurrentKey: string;
begin
  Result := 0;
  LCurrentKey := FBoard.PositionKey;
  for I := 0 to FPositionHistory.Count - 1 do
    if FPositionHistory[I] = LCurrentKey then
      Inc(Result);
end;

procedure TGameOrchestrator.CheckDrawsAfterMove;
const
  RepetitionDrawCount = 3;
  TwentyFiveMovesInPlies = 50;
var
  LRepetitionCount: Integer;
begin
  if FState <> gosRunning then
    Exit;

  LRepetitionCount := CountCurrentPositionRepetitions;
  if LRepetitionCount >= RepetitionDrawCount then
  begin
    FinishGame('1-1', 'draw by repetition; repetitions=' +
      IntToStr(LRepetitionCount));
    Exit;
  end;

  if FConsecutiveReversiblePlyCount >= TwentyFiveMovesInPlies then
    FinishGame('1-1', 'draw by 25-move rule; reversible_plies=' +
      IntToStr(FConsecutiveReversiblePlyCount));
end;

function FormatHubSeconds(ASeconds: Double): string;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  Result := Format('%.3f', [ASeconds], FormatSettings);
end;

function TGameOrchestrator.BuildLevelMessage(ASide: TDraughtsSide): string;
begin
  Result := 'level moves=' + IntToStr(GetMovesRemaining(ASide)) +
    ' time=' + FormatHubSeconds(FRemainingSeconds[ASide]);
end;

function TGameOrchestrator.GetMovesRemaining(ASide: TDraughtsSide): Integer;
begin
  if FTimeControl.MovesPerPeriod > 0 then
  begin
    Result := FTimeControl.MovesPerPeriod - FMovesInPeriod[ASide];
    if Result <= 0 then
      Result := FTimeControl.MovesPerPeriod;
  end
  else
    Result := 0;
end;

function TGameOrchestrator.ExtractDoneMove(const AResponse: string): string;
var
  LLowerResponse, LResponse: string;
  LMovePos: SizeInt;
begin
  LResponse := Trim(AResponse);
  LLowerResponse := LowerCase(LResponse);
  LMovePos := Pos('move=', LLowerResponse);
  if LMovePos = 0 then
    Exit('');
  Result := Trim(Copy(LResponse, LMovePos + Length('move='), MaxInt));
end;

procedure TGameOrchestrator.FinishGame(const AResult, AReason: string);
var
  LReason: string;
begin
  FGameResult := Trim(AResult);
  if FGameResult = '' then
    FGameResult := '*';

  LReason := 'result=' + FGameResult;
  if Trim(AReason) <> '' then
    LReason := LReason + '; ' + Trim(AReason);
  ChangeState(gosGameOver, LReason);
  LogMessage('game finished; result=' + FGameResult + '; reason=' + Trim(AReason));
end;

procedure TGameOrchestrator.ApplyTimeUsed(ASide: TDraughtsSide; ASecondsUsed: Double);
var
  LApplyIncrement: Boolean;
begin
  FUsedSeconds[ASide] := FUsedSeconds[ASide] + ASecondsUsed;
  FRemainingSeconds[ASide] := FRemainingSeconds[ASide] - ASecondsUsed;
  Inc(FMovesInPeriod[ASide]);
  Inc(FTotalMovesBySide[ASide]);

  LApplyIncrement := False;
  if FTimeControl.IncrementSeconds > 0 then
    case FTimeControl.IncrementMode of
      cimFromStart:
        LApplyIncrement := True;
      cimAfterMoveLimit:
        LApplyIncrement := (FTimeControl.MovesPerPeriod > 0) and
          (FTotalMovesBySide[ASide] >= FTimeControl.MovesPerPeriod);
    end;

  if LApplyIncrement then
    FRemainingSeconds[ASide] := FRemainingSeconds[ASide] + FTimeControl.IncrementSeconds;

  if (FTimeControl.MovesPerPeriod > 0) and
    (FMovesInPeriod[ASide] >= FTimeControl.MovesPerPeriod) then
  begin
    FMovesInPeriod[ASide] := 0;
    FRemainingSeconds[ASide] := FRemainingSeconds[ASide] +
      FTimeControl.MinutesPerPeriod * 60;
    LogMessage('time period reached; side=' + SideToString(ASide) +
      '; added_seconds=' + FloatToStr(FTimeControl.MinutesPerPeriod * 60));
  end;

  LogMessage('clock update; side=' + SideToString(ASide) +
    '; used_this_move=' + FormatFloat('0.000', ASecondsUsed) +
    '; total_used=' + FormatFloat('0.000', FUsedSeconds[ASide]) +
    '; remaining=' + FormatFloat('0.000', FRemainingSeconds[ASide]));

  if FRemainingSeconds[ASide] <= 0 then
  begin
    if ASide = dsWhite then
      FinishGame('0-2', 'flag fell for white')
    else
      FinishGame('2-0', 'flag fell for black');
  end;
end;

function TGameOrchestrator.PlayNextMove: string;
var
  LElapsedSeconds: Double;
  LEngine: TDraughtsEngine;
  LSide: TDraughtsSide;
  LStartTime: TDateTime;
begin
  Result := '';
  FLastError := '';
  if FState <> gosRunning then
    raise EInvalidOperation.Create('Cannot play a move unless the orchestrator is running');

  LSide := FBoard.SideToMove;
  if FBoard.LegalMoves.Count = 0 then
  begin
    if LSide = dsWhite then
      FinishGame('0-2', 'terminal position; no legal moves for white')
    else
      FinishGame('2-0', 'terminal position; no legal moves for black');
    LogMessage('not sending terminal position');
    Exit;
  end;

  LEngine := FEngines[LSide];
  if LEngine = nil then
    raise EInvalidOperation.Create('No engine assigned for ' + SideToString(LSide));

  try
    LogMessage('configure position; side=' + SideToString(LSide) +
      '; fen=' + FStartingFEN + '; move_count=' + IntToStr(FMoveHistory.Count));
    RefreshMovesPlayedCache;
    LEngine.SetGamePosition(FStartingFEN, FMovesPlayed);

    LogMessage('configure clock; side=' + SideToString(LSide) +
      '; moves_remaining=' + IntToStr(GetMovesRemaining(LSide)) +
      '; remaining_seconds=' + FormatHubSeconds(FRemainingSeconds[LSide]) +
      '; total_used_seconds=' + FormatHubSeconds(FUsedSeconds[LSide]));
    LEngine.SetClockInfo(GetMovesRemaining(LSide), FRemainingSeconds[LSide],
      FUsedSeconds[LSide]);

    LogMessage('start thinking; side=' + SideToString(LSide));
    LStartTime := Now;
    Result := LEngine.StartThinking;
    LElapsedSeconds := SecondsBetween(LStartTime, Now);
    LogMessage('move received; side=' + SideToString(LSide) + '; move=' + Result);
    if Result = '' then
    begin
      if LEngine.GameResult <> '*' then
        FinishGame(LEngine.GameResult, 'engine ended game; side=' +
          SideToString(LSide))
      else
        FinishGame('*', 'engine returned no move; side=' + SideToString(LSide));
      Exit;
    end;

    PlayMove(Result, LSide, LElapsedSeconds, 'engine');
  except
    on E: Exception do
    begin
      FLastError := E.Message;
      ChangeState(gosError, E.Message);
      raise;
    end;
  end;
end;

procedure TGameOrchestrator.PlayMove(const AMove: string; ASide: TDraughtsSide;
  ASecondsUsed: Double; const ASource: string);
var
  LLegalMove: string;
  LEngineSide: TDraughtsSide;
  LMoveAnnotation: string;
  LMove: string;
  LReversibleMove: Boolean;
begin
  LMove := NormalizeMoveNotation(AMove);
  if FState <> gosRunning then
    raise EInvalidOperation.Create('Cannot play a move unless the orchestrator is running');
  if LMove = '' then
    raise EInvalidOperation.Create('Cannot play an empty move');
  if FBoard.SideToMove <> ASide then
    raise EInvalidOperation.Create('Cannot play a move for ' + SideToString(ASide) +
      ' while ' + SideToString(FBoard.SideToMove) + ' is to move');
  if not FBoard.TryGetLegalMove(LMove, LLegalMove) then
    raise EInvalidOperation.Create('Illegal move: ' + LMove);
  LMove := LLegalMove;

  ApplyTimeUsed(ASide, ASecondsUsed);
  if FState = gosGameOver then
    Exit;

  LReversibleMove := FBoard.MoveIsReversible(LMove);
  FBoard.PlayMove(LMove, False);
  if LReversibleMove then
    Inc(FConsecutiveReversiblePlyCount)
  else
    FConsecutiveReversiblePlyCount := 0;
  FPositionHistory.Add(FBoard.PositionKey);
  LMoveAnnotation := '';
  if (Trim(ASource) = 'engine') and (FEngines[ASide] <> nil) and
    (FEngines[ASide].LastScore <> '') then
    LMoveAnnotation := AnnotationWithScore('', 'engine',
      FEngines[ASide].LastScore);
  if FEngines[ASide] <> nil then
    FMoveHistory.AddMove(LMove, ASide, ASecondsUsed, LMoveAnnotation,
      FEngines[ASide].PrincipalVariation)
  else
    FMoveHistory.AddMove(LMove, ASide, ASecondsUsed, LMoveAnnotation);
  for LEngineSide := Low(TDraughtsSide) to High(TDraughtsSide) do
    if FEngines[LEngineSide] <> nil then
    begin
      FEngines[LEngineSide].PrincipalVariation := '';
      FEngines[LEngineSide].LastScore := '';
      FEngines[LEngineSide].LastDepth := '';
      FEngines[LEngineSide].LastTimeText := '';
    end;
  RefreshMovesPlayedCache;
  LogMessage('move accepted; source=' + Trim(ASource) + '; side=' +
    SideToString(ASide) + '; move=' + LMove + '; annotation=' +
    LMoveAnnotation + '; move_number=' + IntToStr(FMoveHistory.Count));
  CheckDrawsAfterMove;
end;

function TGameOrchestrator.GetRemainingSeconds(ASide: TDraughtsSide): Double;
begin
  Result := FRemainingSeconds[ASide];
end;

function TGameOrchestrator.GetUsedSeconds(ASide: TDraughtsSide): Double;
begin
  Result := FUsedSeconds[ASide];
end;

end.
