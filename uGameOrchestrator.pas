unit uGameOrchestrator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  uEngineBase, uGameMoveHistory, uGamePosition, uPdnText;

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

  { Runs one game: clocks, engines, move flow. The game itself is reached only
    through its variant: the position, the end-of-game rules (TGameRules) and
    the result texts. }
  TGameOrchestrator = class
  private
    FVariant: TGameVariant;
    FPosition: TGamePosition;
    FPreviousPosition: TGamePosition; // reused for TGameRules.MovePlayed
    FRules: TGameRules;
    FEngines: array[TGameSide] of TGameEngine;
    FGameResult: string;
    FLastError: string;
    FLog: TStringList;
    FLogTarget: TStrings;
    FMovesInPeriod: array[TGameSide] of Integer;
    FMoveHistory: TGameMoveHistory;
    FMovesPlayed: TStringList;
    FOnLog: TOrchestratorLogEvent;
    FRemainingSeconds: array[TGameSide] of Double;
    FStartingFEN: string;
    FState: TGameOrchestratorState;
    FTimeControl: TTimeControl;
    FTotalMovesBySide: array[TGameSide] of Integer;
    FUsedSeconds: array[TGameSide] of Double;
    procedure ApplyTimeUsed(ASide: TGameSide; ASecondsUsed: Double);
    function BuildPositionMessage: string;
    procedure CheckOutcomeAfterMove;
    procedure ChangeState(ANewState: TGameOrchestratorState; const AReason: string);
    function GetCurrentSide: TGameSide;
    function ExtractDoneMove(const AResponse: string): string;
    procedure FinishGame(const AResult, AReason: string);
    procedure FinishWithOutcome(AOutcome: TGameOutcome; const AReason: string);
    // AExpired's time ran out with AExpired to move; the game's rules decide
    // the result (review M9).
    procedure FinishOnTimeout(AExpired: TGameSide; const AReason: string);
    function GetEngine(ASide: TGameSide): TGameEngine;
    function GetMovesRemaining(ASide: TGameSide): Integer;
    function GetMoveAnnotationsText: string;
    function GetMovesPlayedText: string;
    function GetRemainingSeconds(ASide: TGameSide): Double;
    function GetUsedSeconds(ASide: TGameSide): Double;
    procedure LogMessage(const AMessage: string);
    procedure ReleaseEngines;
    procedure ResetClocks;
    procedure RefreshMovesPlayedCache;
    procedure SetEngine(ASide: TGameSide; AEngine: TGameEngine);
    procedure StartEngineSessions;
  public
    // AVariant: the game; nil uses the registered default game.
    constructor Create(AVariant: TGameVariant = nil);
    destructor Destroy; override;

    procedure NewGame(const AStartingFEN: string);
    procedure PlayMove(const AMove: string; ASide: TGameSide;
      ASecondsUsed: Double; const ASource: string = 'move');
    function PlayNextMove: string;
    procedure RequestStopEngines;
    procedure StopEngines;

    // The current position; owned by the orchestrator, read only for callers.
    property Position: TGamePosition read FPosition;
    property Variant: TGameVariant read FVariant;
    property CurrentSide: TGameSide read GetCurrentSide;
    property Engine[ASide: TGameSide]: TGameEngine read GetEngine write SetEngine;
    property GameResult: string read FGameResult;
    property LastError: string read FLastError;
    property Log: TStringList read FLog;
    property LogTarget: TStrings read FLogTarget write FLogTarget;
    property MoveHistory: TGameMoveHistory read FMoveHistory;
    property MovesPlayed: TStringList read FMovesPlayed;
    property MoveAnnotationsText: string read GetMoveAnnotationsText;
    property MovesPlayedText: string read GetMovesPlayedText;
    property OnLog: TOrchestratorLogEvent read FOnLog write FOnLog;
    property RemainingSeconds[ASide: TGameSide]: Double read GetRemainingSeconds;
    property StartingFEN: string read FStartingFEN;
    property State: TGameOrchestratorState read FState;
    property TimeControl: TTimeControl read FTimeControl write FTimeControl;
    property UsedSeconds[ASide: TGameSide]: Double read GetUsedSeconds;
  end;

function DefaultTimeControl: TTimeControl;
function OrchestratorStateToString(AState: TGameOrchestratorState): string;
function SideToString(ASide: TGameSide): string;

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

function SideToString(ASide: TGameSide): string;
begin
  Result := GameSideName(ASide);
end;

constructor TGameOrchestrator.Create(AVariant: TGameVariant);
begin
  inherited Create;
  if AVariant = nil then
    AVariant := DefaultGameVariant;
  FVariant := AVariant;
  FPosition := FVariant.CreatePosition;
  FRules := FVariant.CreateRules;
  FLog := TStringList.Create;
  FMovesPlayed := TStringList.Create;
  FMoveHistory := TGameMoveHistory.Create;
  FTimeControl := DefaultTimeControl;
  FState := gosWaiting;
  FGameResult := '*';
  FStartingFEN := FVariant.DefaultStartingFEN;
  ResetClocks;
  LogMessage('created; state=' + OrchestratorStateToString(FState));
end;

destructor TGameOrchestrator.Destroy;
begin
  ReleaseEngines;
  FMovesPlayed.Free;
  FMoveHistory.Free;
  FLog.Free;
  FRules.Free;
  FPreviousPosition.Free;
  FPosition.Free;
  inherited Destroy;
end;

procedure TGameOrchestrator.ReleaseEngines;
var
  LSide: TGameSide;
begin
  for LSide := Low(TGameSide) to High(TGameSide) do
    FreeAndNil(FEngines[LSide]);
end;

procedure TGameOrchestrator.StopEngines;
var
  LSide: TGameSide;
begin
  LogMessage('stop engines requested');
  for LSide := Low(TGameSide) to High(TGameSide) do
    if FEngines[LSide] <> nil then
      FEngines[LSide].Stop;
end;

procedure TGameOrchestrator.RequestStopEngines;
var
  LSide: TGameSide;
begin
  for LSide := Low(TGameSide) to High(TGameSide) do
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

function TGameOrchestrator.GetEngine(ASide: TGameSide): TGameEngine;
begin
  Result := FEngines[ASide];
end;

function TGameOrchestrator.GetCurrentSide: TGameSide;
begin
  Result := FPosition.SideToMove;
end;

procedure TGameOrchestrator.SetEngine(ASide: TGameSide; AEngine: TGameEngine);
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
  LSide: TGameSide;
begin
  for LSide := Low(TGameSide) to High(TGameSide) do
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
  FPosition.LoadFromFEN(FStartingFEN);
  FMoveHistory.Clear;
  RefreshMovesPlayedCache;
  FRules.Reset(FPosition);
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
  LBeginGameIncrement: Double;
  LSide: TGameSide;
begin
  if FTimeControl.IncrementMode = cimFromStart then
    LBeginGameIncrement := FTimeControl.IncrementSeconds
  else
  begin
    LBeginGameIncrement := 0;
    if FTimeControl.IncrementSeconds > 0 then
      LogMessage('begin engine game; increment after move limit is not sent to engine session start');
  end;

  for LSide := Low(TGameSide) to High(TGameSide) do
    if FEngines[LSide] <> nil then
    begin
      LogMessage('begin engine game; side=' + SideToString(LSide) +
        '; engine=' + FEngines[LSide].EngineName +
        '; game_minutes=' + FloatToStr(FTimeControl.MinutesPerPeriod) +
        '; game_moves=' + IntToStr(FTimeControl.MovesPerPeriod) +
        '; begin_increment_seconds=' + FloatToStr(LBeginGameIncrement));
      FEngines[LSide].BeginGame(FStartingFEN, LSide,
        FTimeControl.MinutesPerPeriod, FTimeControl.MovesPerPeriod,
        LBeginGameIncrement);
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

procedure TGameOrchestrator.CheckOutcomeAfterMove;
var
  LOutcome: TGameOutcome;
  LReason: string;
begin
  if FState <> gosRunning then
    Exit;
  LOutcome := FRules.Outcome(FPosition, LReason);
  if LOutcome <> goOngoing then
    FinishWithOutcome(LOutcome, LReason);
end;

function FormatHubSeconds(ASeconds: Double): string;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  Result := Format('%.3f', [ASeconds], FormatSettings);
end;

function TGameOrchestrator.GetMovesRemaining(ASide: TGameSide): Integer;
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

procedure TGameOrchestrator.FinishOnTimeout(AExpired: TGameSide;
  const AReason: string);
var
  LReason: string;
begin
  LReason := AReason;
  FinishWithOutcome(FRules.TimeoutOutcome(FPosition, AExpired, LReason), LReason);
end;

procedure TGameOrchestrator.FinishWithOutcome(AOutcome: TGameOutcome;
  const AReason: string);
begin
  FinishGame(FVariant.ResultText(AOutcome), AReason);
end;

procedure TGameOrchestrator.ApplyTimeUsed(ASide: TGameSide; ASecondsUsed: Double);
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

  // The next period is earned only by completing this one in time. Keep the
  // applicable increment policy aligned with the engine's search deadline.
  if FRemainingSeconds[ASide] <= 0 then
  begin
    FinishOnTimeout(ASide, 'flag fell for ' + SideToString(ASide));
    Exit;
  end;

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


end;

function TGameOrchestrator.PlayNextMove: string;
var
  LElapsedSeconds: Double;
  LEngine: TGameEngine;
  LSide: TGameSide;
  LStartTick: QWord;
  LAvailableSeconds, LActiveIncrement: Double;
  LTimeoutMs: Integer;
  LSearchStarted: Boolean;
  LOutcome: TGameOutcome;
  LReason: string;

  procedure FinishOnEngineTimeout;
  begin
    FUsedSeconds[LSide] := FUsedSeconds[LSide] +
      (GetTickCount64 - LStartTick) / 1000;
    FRemainingSeconds[LSide] := 0;
    FinishOnTimeout(LSide, 'flag fell for ' + SideToString(LSide) +
      '; engine move deadline expired');
    Result := '';
  end;
begin
  Result := '';
  LSearchStarted := False;
  FLastError := '';
  if FState <> gosRunning then
    raise EInvalidOperation.Create('Cannot play a move unless the orchestrator is running');

  LSide := FPosition.SideToMove;
  if FPosition.LegalMoveCount = 0 then
  begin
    LOutcome := FRules.Outcome(FPosition, LReason);
    FinishWithOutcome(LOutcome, 'terminal position; no legal moves for ' +
      SideToString(LSide));
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
    LActiveIncrement := 0;
    if (FTimeControl.IncrementMode = cimFromStart) or
      ((FTimeControl.MovesPerPeriod > 0) and
       (FTotalMovesBySide[LSide] + 1 >= FTimeControl.MovesPerPeriod)) then
      LActiveIncrement := FTimeControl.IncrementSeconds;
    LEngine.SetClockInfoWithIncrement(GetMovesRemaining(LSide), FRemainingSeconds[LSide],
      FUsedSeconds[LSide], LActiveIncrement);

    LAvailableSeconds := FRemainingSeconds[LSide];
    if (FTimeControl.IncrementMode = cimFromStart) or
      ((FTimeControl.MovesPerPeriod > 0) and
       (FTotalMovesBySide[LSide] + 1 >= FTimeControl.MovesPerPeriod)) then
      if FTimeControl.IncrementSeconds > 0 then
        LAvailableSeconds := LAvailableSeconds + FTimeControl.IncrementSeconds;
    // Match the clock's increment allowance; the margin only bounds transport
    // and polling overhead. It does not add time to the player's clock.
    if LAvailableSeconds >= (High(Integer) - 250) / 1000 then
      LTimeoutMs := High(Integer)
    else if LAvailableSeconds <= 0 then
      LTimeoutMs := 1
    else
      LTimeoutMs := Round(LAvailableSeconds * 1000) + 250;
    LEngine.SetMoveTimeLimit(LTimeoutMs);
    LogMessage('start thinking; side=' + SideToString(LSide) +
      '; deadline_ms=' + IntToStr(LTimeoutMs));
    LStartTick := GetTickCount64;
    LSearchStarted := True;
    Result := LEngine.StartThinking;
    LElapsedSeconds := (GetTickCount64 - LStartTick) / 1000;
    if LEngine.MoveTimedOut then
    begin
      FinishOnEngineTimeout;
      Exit;
    end;
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
      if LSearchStarted and LEngine.MoveTimedOut then
        FinishOnEngineTimeout
      else
      begin
        FLastError := E.Message;
        ChangeState(gosError, E.Message);
        raise;
      end;
    end;
  end;
end;

procedure TGameOrchestrator.PlayMove(const AMove: string; ASide: TGameSide;
  ASecondsUsed: Double; const ASource: string);
var
  LLegalMove: string;
  LEngineSide: TGameSide;
  LMoveAnnotation: string;
  LMove: string;
  RecordedMove: TGameMove;
begin
  LMove := FVariant.NormalizeMove(AMove);
  if FState <> gosRunning then
    raise EInvalidOperation.Create('Cannot play a move unless the orchestrator is running');
  if LMove = '' then
    raise EInvalidOperation.Create('Cannot play an empty move');
  if FPosition.SideToMove <> ASide then
    raise EInvalidOperation.Create('Cannot play a move for ' + SideToString(ASide) +
      ' while ' + SideToString(FPosition.SideToMove) + ' is to move');
  if not FPosition.TryParseMove(LMove, LLegalMove) then
    raise EInvalidOperation.Create('Illegal move: ' + LMove);
  LMove := LLegalMove;

  ApplyTimeUsed(ASide, ASecondsUsed);
  if FState = gosGameOver then
    Exit;

  AssignGamePosition(FPreviousPosition, FPosition);
  FPosition.PlayTrustedMove(LMove);
  FRules.MovePlayed(FPreviousPosition, LMove, FPosition);
  LMoveAnnotation := '';
  if (Trim(ASource) = 'engine') and (FEngines[ASide] <> nil) and
    (FEngines[ASide].LastScore <> '') then
    LMoveAnnotation := AnnotationWithScore('', 'engine',
      FEngines[ASide].LastScore);
  if FEngines[ASide] <> nil then
    RecordedMove := FMoveHistory.AddMove(LMove, ASide, ASecondsUsed, LMoveAnnotation,
      FEngines[ASide].PrincipalVariation)
  else
    RecordedMove := FMoveHistory.AddMove(LMove, ASide, ASecondsUsed, LMoveAnnotation);
  RecordedMove.HasClockInfo := True;
  RecordedMove.WhiteRemainingSeconds := FRemainingSeconds[gsWhite];
  RecordedMove.BlackRemainingSeconds := FRemainingSeconds[gsBlack];
  RecordedMove.WhiteUsedSeconds := FUsedSeconds[gsWhite];
  RecordedMove.BlackUsedSeconds := FUsedSeconds[gsBlack];
  if FEngines[ASide] <> nil then
  begin
    RecordedMove.PvScore := FEngines[ASide].LastScore;
    RecordedMove.PvDepth := FEngines[ASide].LastDepth;
    RecordedMove.PvTimeText := FEngines[ASide].LastTimeText;
  end;
  for LEngineSide := Low(TGameSide) to High(TGameSide) do
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
  CheckOutcomeAfterMove;
end;

function TGameOrchestrator.GetRemainingSeconds(ASide: TGameSide): Double;
begin
  Result := FRemainingSeconds[ASide];
end;

function TGameOrchestrator.GetUsedSeconds(ASide: TGameSide): Double;
begin
  Result := FUsedSeconds[ASide];
end;

end.
