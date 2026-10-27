unit uRunningGame;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uEngineRegistry, uGamePosition, uGameSetupTypes,
  uGameOrchestrator, uGameRunnerThread, uGameMoveHistory, uGameTree, uGameTreeActor;

type
  TRunningSnapshotTreeInput = record
    GameId: Integer;
    EventName: string;
    WhiteName: string;
    BlackName: string;
    ResultText: string;
    StartingFEN: string;
    StatusText: string;
    MovesText: string;
    AnnotationsText: string;
    MoveData: TGameMoveDataArray;
    State: TGameOrchestratorState;
    PrincipalVariation: string;
    PvScore: string;
    PvDepth: string;
    PvTimeText: string;
    PvBasePly: Integer;
    WhiteRemainingSeconds: Double;
    BlackRemainingSeconds: Double;
    WhiteUsedSeconds: Double;
    BlackUsedSeconds: Double;
    TimeControl: TTimeControl;
  end;

  TRunningSnapshotLogInput = record
    LogLinesText: string;
    LogLineCount: Integer;
  end;

  TRunningGameLifecycle = (
    rglStarting,
    rglRunning,
    rglStopRequested,
    rglRemoveRequested,
    rglFinished
  );

  TRunningGame = class
  private
    FId: Integer;
    FBlackEngineKey: string;
    FBlackPlayerKind: TPlayerKind;
    FGameTreeActor: TGameTreeActor;
    FGameTree: TGameTree;
    FReservationKeys: TStringList;
    FReleasingRunner: Boolean;
    FRunner: TGameRunnerThread;
    FLifecycle: TRunningGameLifecycle;
    FShowStdout: Boolean;
    FSnapshot: TGameRunnerSnapshot;
    FLastSnapshotTreePvSignature: string;
    FLastSnapshotTreeSyncSignature: string;
    FListCaption: string;
    FStopReason: string;
    FSetup: TGameSetup;
    FTitle: string;
    FWhiteEngineKey: string;
    FWhiteDisplayName: string;
    FWhitePlayerKind: TPlayerKind;
    FBlackDisplayName: string;
    procedure ClearSetup;
    procedure CopySetupFrom(const ASetup: TGameSetup);
    procedure ReleaseRunner;
    procedure WaitForRunnerFinished;
  public
    constructor Create(AId: Integer; const ATitle: string; ARunner: TGameRunnerThread;
      AWhitePlayerKind, ABlackPlayerKind: TPlayerKind; const AWhiteEngineKey,
      ABlackEngineKey, AWhiteDisplayName, ABlackDisplayName: string;
      AReservationKeys: TStrings; const ASetup: TGameSetup);
    destructor Destroy; override;

    function IsEngineReservationActive: Boolean;
    function CanEditGameTree: Boolean;
    function IsHumanToMove: Boolean;
    function GameTreeId: Int64;
    function ReservationSummary: string;
    function HasPlayedMoves: Boolean;
    function InitialClockSeconds: Double;
    function IsStopOrRemoveRequested: Boolean;
    function IsTournamentGame: Boolean;
    function ListCaptionMatches(const ACaption: string): Boolean;
    function BlackNameText: string;
    function LastErrorText: string;
    function MainlineCount: Integer;
    function ResultText: string;
    function SetupTimeControl: TTimeControl;
    function SnapshotPvSignatureMatches(const ASignature: string): Boolean;
    function SnapshotSyncSignatureMatches(const ASignature: string): Boolean;
    function State: TGameOrchestratorState;
    function BranchCount: Integer;
    function WhiteNameText: string;
    procedure AssignRunnerSnapshot(ASnapshot: TGameRunnerSnapshot);
    procedure AssignSetupTo(out ASetup: TGameSetup);
    procedure AddReservationKeysTo(AKeys: TStrings);
    procedure MarkFinished;
    procedure MarkRunningIfStarting;
    procedure MarkSnapshotStopped(const AReason: string);
    procedure RememberSnapshotPvSignature(const ASignature: string);
    procedure RememberSnapshotSyncSignature(const ASignature: string);
    procedure RequestRemoval;
    procedure RequestStop(const AReason: string);
    procedure SnapshotTreeInput(ASnapshot: TGameRunnerSnapshot;
      const AEventName: string;
      out AInput: TRunningSnapshotTreeInput);
    procedure SnapshotLogInput(out AInput: TRunningSnapshotLogInput);
    procedure UpdateListCaption(const ACaption: string);
    property Id: Integer read FId;
    property GameTreeActor: TGameTreeActor read FGameTreeActor;
    property GameTree: TGameTree read FGameTree;
    property Lifecycle: TRunningGameLifecycle read FLifecycle;
    property Runner: TGameRunnerThread read FRunner;
    property ShowStdout: Boolean read FShowStdout write FShowStdout;
    property StopReason: string read FStopReason;
    property Title: string read FTitle;
    property WhiteDisplayName: string read FWhiteDisplayName;
    property BlackDisplayName: string read FBlackDisplayName;
  end;

function RunningGameLifecycleToString(ALifecycle: TRunningGameLifecycle): string;

implementation

function RunningGameLifecycleToString(ALifecycle: TRunningGameLifecycle): string;
begin
  case ALifecycle of
    rglStarting:
      Result := 'starting';
    rglRunning:
      Result := 'running';
    rglStopRequested:
      Result := 'stop requested';
    rglRemoveRequested:
      Result := 'remove requested';
    rglFinished:
      Result := 'finished';
  else
    Result := 'unknown';
  end;
end;

function SideToMoveAfterPly(AGameTree: TGameTree; APlyCount: Integer): TGameSide;
begin
  Result := AGameTree.Variant.SideFromFEN(AGameTree.StartingFEN);
  if Odd(APlyCount) then
    Result := OppositeGameSide(Result);
end;

constructor TRunningGame.Create(AId: Integer; const ATitle: string;
  ARunner: TGameRunnerThread; AWhitePlayerKind, ABlackPlayerKind: TPlayerKind;
  const AWhiteEngineKey, ABlackEngineKey, AWhiteDisplayName,
  ABlackDisplayName: string; AReservationKeys: TStrings; const ASetup: TGameSetup);
begin
  inherited Create;
  FId := AId;
  FTitle := ATitle;
  FRunner := ARunner;
  FWhitePlayerKind := AWhitePlayerKind;
  FBlackPlayerKind := ABlackPlayerKind;
  FWhiteEngineKey := AWhiteEngineKey;
  FBlackEngineKey := ABlackEngineKey;
  FWhiteDisplayName := AWhiteDisplayName;
  FBlackDisplayName := ABlackDisplayName;
  FReservationKeys := TStringList.Create;
  FReservationKeys.Sorted := True;
  FReservationKeys.Duplicates := dupIgnore;
  if AReservationKeys <> nil then
    FReservationKeys.AddStrings(AReservationKeys);
  FGameTree := TGameTree.Create;
  FGameTreeActor := TGameTreeActor.Create(FGameTree, False);
  FSnapshot := TGameRunnerSnapshot.Create;
  CopySetupFrom(ASetup);
  FLifecycle := rglStarting;
end;

destructor TRunningGame.Destroy;
begin
  ReleaseRunner;
  ClearSetup;
  FGameTreeActor.Free;
  FGameTree.Free;
  FSnapshot.Free;
  FReservationKeys.Free;
  inherited Destroy;
end;

procedure TRunningGame.ClearSetup;
begin
  FreeAndNil(FSetup.WhiteEngine);
  FreeAndNil(FSetup.BlackEngine);
end;

procedure TRunningGame.CopySetupFrom(const ASetup: TGameSetup);
begin
  ClearSetup;
  FSetup := ASetup;
  FSetup.WhiteEngine := nil;
  FSetup.BlackEngine := nil;
  if ASetup.WhiteEngine <> nil then
  begin
    FSetup.WhiteEngine := TExternalEngineDefinition.Create;
    FSetup.WhiteEngine.Assign(ASetup.WhiteEngine);
  end;
  if ASetup.BlackEngine <> nil then
  begin
    FSetup.BlackEngine := TExternalEngineDefinition.Create;
    FSetup.BlackEngine.Assign(ASetup.BlackEngine);
  end;
end;

procedure TRunningGame.AssignSetupTo(out ASetup: TGameSetup);
begin
  ASetup := FSetup;
  ASetup.WhiteEngine := nil;
  ASetup.BlackEngine := nil;
  if FSetup.WhiteEngine <> nil then
  begin
    ASetup.WhiteEngine := TExternalEngineDefinition.Create;
    ASetup.WhiteEngine.Assign(FSetup.WhiteEngine);
  end;
  if FSetup.BlackEngine <> nil then
  begin
    ASetup.BlackEngine := TExternalEngineDefinition.Create;
    ASetup.BlackEngine.Assign(FSetup.BlackEngine);
  end;
end;

procedure TRunningGame.AddReservationKeysTo(AKeys: TStrings);
begin
  if AKeys <> nil then
    AKeys.AddStrings(FReservationKeys);
end;

procedure TRunningGame.ReleaseRunner;
begin
  if FRunner = nil then
    Exit;
  if FReleasingRunner then
    Exit;

  FReleasingRunner := True;
  try

    if FLifecycle <> rglFinished then
      FRunner.PostStop;
    WaitForRunnerFinished;
    FRunner.WaitFor;
    FreeAndNil(FRunner);
  finally
    FReleasingRunner := False;
  end;
end;

procedure TRunningGame.WaitForRunnerFinished;
const
  RunnerReleaseWarningMs = 10000;
var
  LastWarningTick: QWord;
  LPlyCount: Integer;
  LState: TGameOrchestratorState;
  WarningText: string;
begin
  if FRunner = nil then
    Exit;

  LastWarningTick := GetTickCount64;
  while not FRunner.Finished do
  begin
    CheckSynchronize(50);
    if GetTickCount64 - LastWarningTick >= RunnerReleaseWarningMs then
    begin
      LState := FGameTree.GameState;
      LPlyCount := FGameTree.MainlineCount;
      WarningText := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
        ' [gui] waiting for runner shutdown; game_id=' + IntToStr(FId) +
        '; title=' + FTitle +
        '; lifecycle=' + RunningGameLifecycleToString(FLifecycle) +
        '; state=' + OrchestratorStateToString(LState) +
        '; plies=' + IntToStr(LPlyCount) +
        '; reservations=' + ReservationSummary;
      FSnapshot.LogLines.Add(WarningText);
      WriteLn(WarningText);
      LastWarningTick := GetTickCount64;
    end;
    Sleep(10);
  end;
end;

function TRunningGame.IsEngineReservationActive: Boolean;
begin
  Result := FLifecycle <> rglFinished;
end;

function TRunningGame.CanEditGameTree: Boolean;
begin
  Result := FLifecycle = rglFinished;
end;

function TRunningGame.IsHumanToMove: Boolean;
var
  LCurrentSide: TGameSide;
begin
  LCurrentSide := SideToMoveAfterPly(FGameTree,
    FGameTree.MainlineCount);

  if LCurrentSide = gsBlack then
    Result := FBlackPlayerKind = pkHuman
  else
    Result := FWhitePlayerKind = pkHuman;
end;

function TRunningGame.GameTreeId: Int64;
begin
  if FGameTree <> nil then
    Result := FGameTree.GameTreeId
  else
    Result := 0;
end;

function TRunningGame.ReservationSummary: string;
begin
  Result := Trim(FReservationKeys.CommaText);
  if Result = '' then
    Result := 'none';
end;

function TRunningGame.HasPlayedMoves: Boolean;
begin
  Result := FGameTree.MainlineCount > 0;
end;

function TRunningGame.InitialClockSeconds: Double;
begin
  Result := FSetup.TimeControl.MinutesPerPeriod * 60;
end;

function TRunningGame.IsStopOrRemoveRequested: Boolean;
begin
  Result := FLifecycle in [rglStopRequested, rglRemoveRequested];
end;

function TRunningGame.IsTournamentGame: Boolean;
begin
  Result := (FTitle <> '') and (Pos('Tournament ', FTitle) = 1);
end;

function TRunningGame.ListCaptionMatches(const ACaption: string): Boolean;
begin
  Result := FListCaption = ACaption;
end;

function TRunningGame.BlackNameText: string;
begin
  Result := Trim(FGameTree.BlackName);
  if Result = '' then
    Result := Trim(FBlackDisplayName);
  if Result = '' then
    Result := 'Black';
end;

function TRunningGame.LastErrorText: string;
begin
  Result := Trim(FGameTree.StatusText);
  if Result = '' then
    Result := FSnapshot.LastError;
end;

function TRunningGame.MainlineCount: Integer;
begin
  if FGameTree <> nil then
    Result := FGameTree.MainlineCount
  else
    Result := 0;
end;

function TRunningGame.ResultText: string;
begin
  Result := Trim(FGameTree.ResultText);
  if Result = '' then
    Result := '*';
end;

function TRunningGame.SetupTimeControl: TTimeControl;
begin
  Result := FSetup.TimeControl;
end;

function TRunningGame.SnapshotPvSignatureMatches(
  const ASignature: string): Boolean;
begin
  Result := FLastSnapshotTreePvSignature = ASignature;
end;

function TRunningGame.SnapshotSyncSignatureMatches(
  const ASignature: string): Boolean;
begin
  Result := FLastSnapshotTreeSyncSignature = ASignature;
end;

function TRunningGame.State: TGameOrchestratorState;
begin
  Result := FGameTree.GameState;
end;

function TRunningGame.BranchCount: Integer;
begin
  if FGameTree <> nil then
    Result := FGameTree.BranchCount
  else
    Result := 0;
end;

function TRunningGame.WhiteNameText: string;
begin
  Result := Trim(FGameTree.WhiteName);
  if Result = '' then
    Result := Trim(FWhiteDisplayName);
  if Result = '' then
    Result := 'White';
end;

procedure TRunningGame.AssignRunnerSnapshot(ASnapshot: TGameRunnerSnapshot);
begin
  FSnapshot.AssignFrom(ASnapshot);
end;

procedure TRunningGame.MarkSnapshotStopped(const AReason: string);
begin
  FSnapshot.MarkStopped(AReason);
end;

procedure TRunningGame.RememberSnapshotPvSignature(const ASignature: string);
begin
  FLastSnapshotTreePvSignature := ASignature;
end;

procedure TRunningGame.RememberSnapshotSyncSignature(const ASignature: string);
begin
  FLastSnapshotTreeSyncSignature := ASignature;
end;

procedure TRunningGame.MarkFinished;
begin
  FLifecycle := rglFinished;
end;

procedure TRunningGame.MarkRunningIfStarting;
begin
  if FLifecycle = rglStarting then
    FLifecycle := rglRunning;
end;

procedure TRunningGame.RequestRemoval;
begin
  FLifecycle := rglRemoveRequested;
end;

procedure TRunningGame.RequestStop(const AReason: string);
begin
  if FRunner <> nil then
    FRunner.PostStop;
  if not (FLifecycle in [rglFinished, rglRemoveRequested]) then
    FLifecycle := rglStopRequested;
  FStopReason := AReason;
  MarkSnapshotStopped(FStopReason);
end;

procedure TRunningGame.SnapshotTreeInput(ASnapshot: TGameRunnerSnapshot;
  const AEventName: string;
  out AInput: TRunningSnapshotTreeInput);

  function ValueOrFallback(const AValue, AFallback: string): string;
  begin
    Result := Trim(AValue);
    if Result = '' then
      Result := AFallback;
  end;

var
  LSnapshot: TGameRunnerSnapshot;
begin
  LSnapshot := ASnapshot;
  if LSnapshot = nil then
    LSnapshot := FSnapshot;

  AInput.GameId := FId;
  AInput.EventName := ValueOrFallback(AEventName, '?');
  AInput.WhiteName := ValueOrFallback(LSnapshot.WhitePlayerName,
    ValueOrFallback(FWhiteDisplayName, 'White'));
  AInput.BlackName := ValueOrFallback(LSnapshot.BlackPlayerName,
    ValueOrFallback(FBlackDisplayName, 'Black'));
  AInput.ResultText := ValueOrFallback(LSnapshot.GameResult, '*');
  AInput.StartingFEN := ValueOrFallback(LSnapshot.StartingFEN,
    FSetup.StartingFEN);
  AInput.StatusText := Trim(LSnapshot.LastError);
  AInput.MovesText := LSnapshot.MovesPlayedText;
  AInput.AnnotationsText := LSnapshot.MoveAnnotationsText;
  AInput.MoveData := LSnapshot.MoveData;
  AInput.State := LSnapshot.State;
  AInput.PrincipalVariation := LSnapshot.PrincipalVariation;
  AInput.PvScore := LSnapshot.PvScore;
  AInput.PvDepth := LSnapshot.PvSnapshot.Depth;
  AInput.PvTimeText := LSnapshot.PvSnapshot.TimeText;
  AInput.PvBasePly := LSnapshot.PvBasePly;
  AInput.WhiteRemainingSeconds := LSnapshot.WhiteRemainingSeconds;
  AInput.BlackRemainingSeconds := LSnapshot.BlackRemainingSeconds;
  AInput.WhiteUsedSeconds := LSnapshot.WhiteUsedSeconds;
  AInput.BlackUsedSeconds := LSnapshot.BlackUsedSeconds;
  AInput.TimeControl := FSetup.TimeControl;
end;

procedure TRunningGame.SnapshotLogInput(out AInput: TRunningSnapshotLogInput);
begin
  AInput.LogLinesText := FSnapshot.LogLines.Text;
  AInput.LogLineCount := FSnapshot.LogLines.Count;
end;

procedure TRunningGame.UpdateListCaption(const ACaption: string);
begin
  FListCaption := ACaption;
end;

end.
