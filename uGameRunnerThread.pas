unit uGameRunnerThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SyncObjs, SysUtils,
  uCancellationToken,
  uDraughtsBoard, uDxpEngine, uEngineBase, uEngineRegistry,
  uGameOrchestrator, uGameSetupForm, uHubEngine, uPvSnapshot,
  uThreadMessageQueue;

type
  TGameRunnerSnapshot = class
  private
    FBlackRemainingSeconds: Double;
    FBlackPlayerName: string;
    FBlackUsedSeconds: Double;
    FBoard: TDraughtsBoard;
    FCurrentSide: TDraughtsSide;
    FGameResult: string;
    FLastError: string;
    FLogLines: TStringList;
    FMoveAnnotationsText: string;
    FMovesPlayedText: string;
    FPlyCount: Integer;
    FPvSnapshot: TPvSnapshot;
    FState: TGameOrchestratorState;
    FStartingFEN: string;
    FWhiteRemainingSeconds: Double;
    FWhitePlayerName: string;
    FWhiteUsedSeconds: Double;
    function GetPrincipalVariation: string;
    function GetPvBaseBoard: TDraughtsBoard;
    function GetPvBasePly: Integer;
    function GetPvScore: string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AssignFrom(ASource: TGameRunnerSnapshot);
    procedure MarkStopped(const AReason: string);

    property BlackRemainingSeconds: Double read FBlackRemainingSeconds;
    property BlackPlayerName: string read FBlackPlayerName;
    property BlackUsedSeconds: Double read FBlackUsedSeconds;
    property Board: TDraughtsBoard read FBoard;
    property CurrentSide: TDraughtsSide read FCurrentSide;
    property GameResult: string read FGameResult;
    property LastError: string read FLastError;
    property LogLines: TStringList read FLogLines;
    property MoveAnnotationsText: string read FMoveAnnotationsText;
    property MovesPlayedText: string read FMovesPlayedText;
    property PlyCount: Integer read FPlyCount;
    property PvScore: string read GetPvScore;
    property PrincipalVariation: string read GetPrincipalVariation;
    property PvBaseBoard: TDraughtsBoard read GetPvBaseBoard;
    property PvBasePly: Integer read GetPvBasePly;
    property PvSnapshot: TPvSnapshot read FPvSnapshot;
    property State: TGameOrchestratorState read FState;
    property StartingFEN: string read FStartingFEN;
    property WhiteRemainingSeconds: Double read FWhiteRemainingSeconds;
    property WhitePlayerName: string read FWhitePlayerName;
    property WhiteUsedSeconds: Double read FWhiteUsedSeconds;
  end;

  TGameRunnerSnapshotEvent = procedure(Sender: TObject; ASnapshot: TGameRunnerSnapshot) of object;
  TGameRunnerFinishedEvent = procedure(Sender: TObject) of object;

  TGameRunnerThread = class(TThread)
  private
    FCommandQueue: TThreadMessageQueue;
    FGameLog: TStringList;
    FGameId: Integer;
    FHumanTurnStartTick: QWord;
    FOnFinished: TGameRunnerFinishedEvent;
    FOnSnapshot: TGameRunnerSnapshotEvent;
    FOrchestrator: TGameOrchestrator;
    FPaused: Boolean;
    FLastPrincipalVariation: string;
    FPvBaseBoard: TDraughtsBoard;
    FPvBasePly: Integer;
    FRunnerError: string;
    FRunnerFailed: Boolean;
    FSetup: TGameSetup;
    FShowStdout: Boolean;
    FSnapshotLock: TCriticalSection;
    FStopLogged: Boolean;
    FWhiteEngine: TExternalEngineDefinition;
    FBlackEngine: TExternalEngineDefinition;
    FLogLock: TCriticalSection;
    FStopToken: TCancellationToken;
    function PlayerDisplayName(AKind: TPlayerKind;
      AEngine: TExternalEngineDefinition): string;
    procedure AddGameLog(const AMessage: string);
    procedure AddGameLogLines(ALines: TStrings);
    procedure DrainCommands;
    procedure DetachRuntimeLogHandlers;
    procedure HandleCommand(ACommand: TObject);
    procedure PostCommand(ACommand: TObject);
    function CurrentPlayerKind: TPlayerKind;
    procedure CreateEngines;
    function CreateSnapshot: TGameRunnerSnapshot;
    procedure PublishSnapshot;
    procedure PublishFinished;
    procedure RequestStopFromRunner(const AReason: string);
    procedure RuntimeLog(Sender: TObject; const AMessage: string);
  protected
    procedure Execute; override;
  public
    constructor Create(const ASetup: TGameSetup; AGameId: Integer;
      ASnapshotEvent: TGameRunnerSnapshotEvent;
      AFinishedEvent: TGameRunnerFinishedEvent);
    destructor Destroy; override;
    procedure PostHumanMove(const AMove: string);
    procedure PostPause(AValue: Boolean);
    procedure PostShowStdout(AValue: Boolean);
    procedure PostStop;
    property GameId: Integer read FGameId;
  end;

implementation

type
  TGameRunnerCommandKind = (
    grcStop,
    grcSetPaused,
    grcSetShowStdout,
    grcHumanMove
  );

  TGameRunnerCommand = class(TThreadMessage)
  private
    FBoolValue: Boolean;
    FCommandKind: TGameRunnerCommandKind;
    FTextValue: string;
  public
    constructor Create(ACommandKind: TGameRunnerCommandKind;
      ABoolValue: Boolean = False); reintroduce;
    constructor CreateText(ACommandKind: TGameRunnerCommandKind;
      const ATextValue: string);
    property BoolValue: Boolean read FBoolValue;
    property CommandKind: TGameRunnerCommandKind read FCommandKind;
    property TextValue: string read FTextValue;
  end;

constructor TGameRunnerCommand.Create(ACommandKind: TGameRunnerCommandKind;
  ABoolValue: Boolean);
const
  CommandNames: array[TGameRunnerCommandKind] of string = (
    'stop',
    'set-paused',
    'set-show-stdout',
    'human-move'
  );
begin
  inherited Create(CommandNames[ACommandKind]);
  FCommandKind := ACommandKind;
  FBoolValue := ABoolValue;
end;

constructor TGameRunnerCommand.CreateText(ACommandKind: TGameRunnerCommandKind;
  const ATextValue: string);
begin
  Create(ACommandKind);
  FTextValue := Trim(ATextValue);
end;

constructor TGameRunnerSnapshot.Create;
begin
  inherited Create;
  FBoard := TDraughtsBoard.Create;
  FPvSnapshot := TPvSnapshot.Create;
  FLogLines := TStringList.Create;
  FGameResult := '*';
end;

destructor TGameRunnerSnapshot.Destroy;
begin
  FLogLines.Free;
  FPvSnapshot.Free;
  FBoard.Free;
  inherited Destroy;
end;

function TGameRunnerSnapshot.GetPrincipalVariation: string;
begin
  Result := FPvSnapshot.PrincipalVariation;
end;

function TGameRunnerSnapshot.GetPvBaseBoard: TDraughtsBoard;
begin
  Result := FPvSnapshot.BaseBoard;
end;

function TGameRunnerSnapshot.GetPvBasePly: Integer;
begin
  Result := FPvSnapshot.BasePly;
end;

function TGameRunnerSnapshot.GetPvScore: string;
begin
  Result := FPvSnapshot.Score;
end;

procedure TGameRunnerSnapshot.AssignFrom(ASource: TGameRunnerSnapshot);
begin
  if ASource = nil then
    Exit;
  FBlackPlayerName := ASource.FBlackPlayerName;
  FBlackRemainingSeconds := ASource.FBlackRemainingSeconds;
  FBlackUsedSeconds := ASource.FBlackUsedSeconds;
  FBoard.AssignFrom(ASource.FBoard);
  FCurrentSide := ASource.FCurrentSide;
  FGameResult := ASource.FGameResult;
  FLastError := ASource.FLastError;
  FLogLines.Assign(ASource.FLogLines);
  FMoveAnnotationsText := ASource.FMoveAnnotationsText;
  FMovesPlayedText := ASource.FMovesPlayedText;
  FPlyCount := ASource.FPlyCount;
  FPvSnapshot.AssignFrom(ASource.FPvSnapshot);
  FState := ASource.FState;
  FStartingFEN := ASource.FStartingFEN;
  FWhitePlayerName := ASource.FWhitePlayerName;
  FWhiteRemainingSeconds := ASource.FWhiteRemainingSeconds;
  FWhiteUsedSeconds := ASource.FWhiteUsedSeconds;
end;

procedure TGameRunnerSnapshot.MarkStopped(const AReason: string);
begin
  FState := gosStopped;
  FGameResult := '*';
  FLastError := AReason;
  if Trim(AReason) <> '' then
    FLogLines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
      ' [gui] stopped; reason=' + Trim(AReason));
end;

constructor TGameRunnerThread.Create(const ASetup: TGameSetup; AGameId: Integer;
  ASnapshotEvent: TGameRunnerSnapshotEvent;
  AFinishedEvent: TGameRunnerFinishedEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FGameId := AGameId;
  FOnSnapshot := ASnapshotEvent;
  FOnFinished := AFinishedEvent;
  FSetup := ASetup;
  FSetup.WhiteEngine := nil;
  FSetup.BlackEngine := nil;
  if ASetup.WhiteEngine <> nil then
  begin
    FWhiteEngine := TExternalEngineDefinition.Create;
    FWhiteEngine.Assign(ASetup.WhiteEngine);
  end;
  if ASetup.BlackEngine <> nil then
  begin
    FBlackEngine := TExternalEngineDefinition.Create;
    FBlackEngine.Assign(ASetup.BlackEngine);
  end;
  FGameLog := TStringList.Create;
  FLogLock := TCriticalSection.Create;
  FSnapshotLock := TCriticalSection.Create;
  FCommandQueue := TThreadMessageQueue.Create(True);
  FStopToken := TCancellationToken.Create;
  FPvBaseBoard := TDraughtsBoard.Create;
end;

destructor TGameRunnerThread.Destroy;
begin
  DetachRuntimeLogHandlers;
  FreeAndNil(FOrchestrator);
  FPvBaseBoard.Free;
  FCommandQueue.Free;
  FBlackEngine.Free;
  FWhiteEngine.Free;
  FStopToken.Free;
  FSnapshotLock.Free;
  FLogLock.Free;
  FGameLog.Free;
  inherited Destroy;
end;

procedure TGameRunnerThread.DetachRuntimeLogHandlers;
var
  LSide: TDraughtsSide;
begin
  if FOrchestrator = nil then
    Exit;

  FOrchestrator.OnLog := nil;
  for LSide := Low(TDraughtsSide) to High(TDraughtsSide) do
    if FOrchestrator.Engine[LSide] <> nil then
      FOrchestrator.Engine[LSide].OnLog := nil;
end;

procedure TGameRunnerThread.HandleCommand(ACommand: TObject);
var
  RunnerCommand: TGameRunnerCommand;
begin
  if not (ACommand is TGameRunnerCommand) then
    Exit;
  RunnerCommand := TGameRunnerCommand(ACommand);

  case RunnerCommand.CommandKind of
    grcStop:
      RequestStopFromRunner('command');
    grcSetPaused:
      begin
        if FPaused <> RunnerCommand.BoolValue then
        begin
          FPaused := RunnerCommand.BoolValue;
          if FPaused then
            AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
              ' [runner] command; kind=pause')
          else
            AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
              ' [runner] command; kind=resume');
        end;
      end;
    grcSetShowStdout:
      begin
        FShowStdout := RunnerCommand.BoolValue;
        AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
          ' [runner] command; kind=set-show-stdout; value=' +
          BoolToStr(FShowStdout, True));
      end;
    grcHumanMove:
      begin
        if FHumanTurnStartTick = 0 then
          FHumanTurnStartTick := GetTickCount64;
        if (FOrchestrator = nil) or (FOrchestrator.State <> gosRunning) then
          Exit;
        if CurrentPlayerKind <> pkHuman then
        begin
          AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
            ' [runner] ignored human move; reason=not human to move; move=' +
            RunnerCommand.TextValue);
          Exit;
        end;
        FOrchestrator.PlayMove(RunnerCommand.TextValue, FOrchestrator.CurrentSide,
          (GetTickCount64 - FHumanTurnStartTick) / 1000, 'human');
        FHumanTurnStartTick := 0;
        AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
          ' [runner] command; kind=human-move; move=' + RunnerCommand.TextValue);
      end;
  end;
end;

procedure TGameRunnerThread.DrainCommands;
var
  Command: TObject;
begin
  while FCommandQueue.TryPop(Command) do
  begin
    try
      HandleCommand(Command);
    finally
      Command.Free;
    end;
  end;
end;

procedure TGameRunnerThread.AddGameLog(const AMessage: string);
begin
  FLogLock.Acquire;
  try
    FGameLog.Add(AMessage);
  finally
    FLogLock.Release;
  end;
end;

procedure TGameRunnerThread.AddGameLogLines(ALines: TStrings);
begin
  if ALines = nil then
    Exit;
  FLogLock.Acquire;
  try
    FGameLog.AddStrings(ALines);
  finally
    FLogLock.Release;
  end;
end;

procedure TGameRunnerThread.PostCommand(ACommand: TObject);
var
  CommandName: string;
  CommandKind: TGameRunnerCommandKind;
  Posted: Boolean;
begin
  if ACommand = nil then
    Exit;
  if not (ACommand is TGameRunnerCommand) then
  begin
    ACommand.Free;
    Exit;
  end;

  CommandKind := TGameRunnerCommand(ACommand).CommandKind;
  CommandName := TGameRunnerCommand(ACommand).Kind;
  if CommandKind = grcStop then
  begin
    FStopToken.Cancel;
    Terminate;
  end;

  Posted := (FCommandQueue <> nil) and FCommandQueue.TryPost(ACommand);
  if not Posted then
  begin
    if FCommandQueue = nil then
      ACommand.Free;
    AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
      ' [runner] command dropped; kind=' + CommandName +
      '; reason=runner closed');
  end;
end;

procedure TGameRunnerThread.RequestStopFromRunner(const AReason: string);
begin
  FStopToken.Cancel;
  Terminate;
  if FOrchestrator <> nil then
    FOrchestrator.RequestStopEngines;
  if FStopLogged then
    Exit;

  FStopLogged := True;
  AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
    ' [runner] stop requested; reason=' + Trim(AReason));
end;

procedure TGameRunnerThread.PostStop;
begin
  PostCommand(TGameRunnerCommand.Create(grcStop));
end;

procedure TGameRunnerThread.PostHumanMove(const AMove: string);
begin
  PostCommand(TGameRunnerCommand.CreateText(grcHumanMove, AMove));
end;

procedure TGameRunnerThread.PostPause(AValue: Boolean);
begin
  PostCommand(TGameRunnerCommand.Create(grcSetPaused, AValue));
end;

procedure TGameRunnerThread.PostShowStdout(AValue: Boolean);
begin
  PostCommand(TGameRunnerCommand.Create(grcSetShowStdout, AValue));
end;

function TGameRunnerThread.PlayerDisplayName(AKind: TPlayerKind;
  AEngine: TExternalEngineDefinition): string;
begin
  case AKind of
    pkHuman:
      Result := 'Human';
    pkRegistered:
      begin
        Result := '';
        if AEngine <> nil then
        begin
          Result := Trim(AEngine.IdText);
          if Result = '' then
            Result := ChangeFileExt(AEngine.ExecutableName, '');
          if Result = '' then
            Result := ChangeFileExt(ExtractFileName(AEngine.ExePath), '');
        end;
        if Result = '' then
          Result := 'Engine';
      end;
  else
    Result := 'Player';
  end;
end;

function TGameRunnerThread.CurrentPlayerKind: TPlayerKind;
begin
  if FOrchestrator.CurrentSide = dsBlack then
    Result := FSetup.BlackPlayer
  else
    Result := FSetup.WhitePlayer;
end;

procedure TGameRunnerThread.CreateEngines;
var
  LEngine: TDraughtsEngine;

  procedure CreateRegisteredEngine(ASide: TDraughtsSide;
    ADefinition: TExternalEngineDefinition);
  begin
    if ADefinition = nil then
      raise EInvalidOperation.Create('No registered engine definition for ' +
        SideToString(ASide));

    if ADefinition.Kind = eekHub then
      LEngine := THubEngine.Create(ADefinition)
    else
      LEngine := TDxpEngine.Create(ADefinition);
    try
      LEngine.StopToken := FStopToken;
      AddGameLogLines(LEngine.StateLog);
      LEngine.OnLog := @RuntimeLog;
      if (LEngine is THubEngine) and (not THubEngine(LEngine).LaunchAndInit) then
        raise EInvalidOperation.Create(SideToString(ASide) +
          ' Hub engine did not launch correctly');
      if (LEngine is TDxpEngine) and (not TDxpEngine(LEngine).LaunchAndInit) then
        raise EInvalidOperation.Create(SideToString(ASide) +
          ' DXP engine did not launch correctly');
      FOrchestrator.Engine[ASide] := LEngine;
      LEngine := nil;
    finally
      LEngine.Free;
    end;
  end;
begin
  if FSetup.WhitePlayer = pkRegistered then
    CreateRegisteredEngine(dsWhite, FWhiteEngine);

  if FSetup.BlackPlayer = pkRegistered then
    CreateRegisteredEngine(dsBlack, FBlackEngine);
end;

function TGameRunnerThread.CreateSnapshot: TGameRunnerSnapshot;
var
  LPvDepth: string;
  LPvScore: string;
  LPvTimeText: string;
  LPvText: string;
  LPvEngine: TDraughtsEngine;
begin
  Result := TGameRunnerSnapshot.Create;
  if FOrchestrator = nil then
  begin
    Result.FState := gosError;
    Result.FGameResult := '*';
    Result.FLastError := FRunnerError;
    Result.FWhitePlayerName := PlayerDisplayName(FSetup.WhitePlayer,
      FWhiteEngine);
    Result.FBlackPlayerName := PlayerDisplayName(FSetup.BlackPlayer,
      FBlackEngine);
    FLogLock.Acquire;
    try
      Result.FLogLines.Assign(FGameLog);
    finally
      FLogLock.Release;
    end;
    Result.FStartingFEN := FSetup.StartingFEN;
    Exit;
  end;

  Result.FBoard.AssignFrom(FOrchestrator.Board);
  Result.FCurrentSide := FOrchestrator.CurrentSide;
  Result.FGameResult := FOrchestrator.GameResult;
  Result.FLastError := FOrchestrator.LastError;
  FLogLock.Acquire;
  try
    Result.FLogLines.Assign(FGameLog);
  finally
    FLogLock.Release;
  end;
  Result.FMovesPlayedText := FOrchestrator.MovesPlayedText;
  Result.FMoveAnnotationsText := FOrchestrator.MoveAnnotationsText;
  Result.FPlyCount := FOrchestrator.MoveHistory.Count;
  Result.FState := FOrchestrator.State;
  Result.FStartingFEN := FOrchestrator.StartingFEN;
  Result.FWhiteRemainingSeconds := FOrchestrator.RemainingSeconds[dsWhite];
  Result.FBlackRemainingSeconds := FOrchestrator.RemainingSeconds[dsBlack];
  Result.FWhiteUsedSeconds := FOrchestrator.UsedSeconds[dsWhite];
  Result.FBlackUsedSeconds := FOrchestrator.UsedSeconds[dsBlack];
  Result.FWhitePlayerName := PlayerDisplayName(FSetup.WhitePlayer,
    FWhiteEngine);
  Result.FBlackPlayerName := PlayerDisplayName(FSetup.BlackPlayer,
    FBlackEngine);
  LPvText := '';
  LPvScore := '';
  LPvDepth := '';
  LPvTimeText := '';
  LPvEngine := FOrchestrator.Engine[FOrchestrator.CurrentSide];
  if (LPvEngine <> nil) and (LPvEngine.PrincipalVariation <> '') then
  begin
    LPvText := LPvEngine.PrincipalVariation;
    LPvScore := LPvEngine.LastScore;
    LPvDepth := LPvEngine.LastDepth;
    LPvTimeText := LPvEngine.LastTimeText;
  end;
  if LPvText <> '' then
  begin
    if (LPvText <> FLastPrincipalVariation) or
      (FOrchestrator.Board.PositionKey <> FPvBaseBoard.PositionKey) then
    begin
      FLastPrincipalVariation := LPvText;
      FPvBaseBoard.AssignFrom(FOrchestrator.Board);
      FPvBasePly := FOrchestrator.MoveHistory.Count;
    end;
    Result.FPvSnapshot.SetData(FPvBaseBoard, FPvBasePly, LPvText, LPvScore,
      LPvDepth, LPvTimeText);
  end;

  if FRunnerFailed then
  begin
    Result.FState := gosError;
    Result.FGameResult := '*';
    Result.FLastError := FRunnerError;
  end;
end;

procedure TGameRunnerThread.PublishSnapshot;
var
  Snapshot: TGameRunnerSnapshot;
begin
  FSnapshotLock.Acquire;
  try
    Snapshot := CreateSnapshot;
    if Assigned(FOnSnapshot) then
      FOnSnapshot(Self, Snapshot)
    else
      Snapshot.Free;
  finally
    FSnapshotLock.Release;
  end;
end;

procedure TGameRunnerThread.PublishFinished;
begin
  if Assigned(FOnFinished) then
    FOnFinished(Self);
end;

procedure TGameRunnerThread.RuntimeLog(Sender: TObject; const AMessage: string);
begin
  if (not FShowStdout) and (Pos('stdout;', LowerCase(AMessage)) > 0) then
    Exit;
  AddGameLog(AMessage);
  PublishSnapshot;
end;

procedure TGameRunnerThread.Execute;
begin
  try
    try
      try
      FOrchestrator := TGameOrchestrator.Create;
      FOrchestrator.OnLog := @RuntimeLog;
      AddGameLogLines(FOrchestrator.Log);
      FOrchestrator.TimeControl := FSetup.TimeControl;
      CreateEngines;
      FOrchestrator.NewGame(FSetup.StartingFEN);
      DrainCommands;
      PublishSnapshot;

      while (not Terminated) and (FOrchestrator.State = gosRunning) do
      begin
        DrainCommands;
        if Terminated then
          Break;

        if FPaused then
        begin
          AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
            ' [runner] paused');
          PublishSnapshot;
          while (not Terminated) and (FOrchestrator.State = gosRunning) and FPaused do
          begin
            DrainCommands;
            Sleep(100);
          end;
          if (not Terminated) and (FOrchestrator.State = gosRunning) then
          begin
            AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
              ' [runner] resumed');
            PublishSnapshot;
          end;
          Continue;
        end;

        if CurrentPlayerKind = pkRegistered then
        begin
          FHumanTurnStartTick := 0;
          AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
            ' [runner] engine to move; side=' + SideToString(FOrchestrator.CurrentSide));
          PublishSnapshot;
          FOrchestrator.PlayNextMove;
          DrainCommands;
          PublishSnapshot;
        end
        else
        begin
          FHumanTurnStartTick := GetTickCount64;
          AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
            ' [runner] human to move; waiting');
          PublishSnapshot;
          while (not Terminated) and (FOrchestrator.State = gosRunning) and
            (CurrentPlayerKind = pkHuman) do
          begin
            DrainCommands;
            if (FOrchestrator.State <> gosRunning) or
              (CurrentPlayerKind <> pkHuman) then
              Break;
            Sleep(100);
          end;
        end;
      end;

      DrainCommands;
      PublishSnapshot;
    finally
      if FStopToken.IsCancelled or Terminated then
        RequestStopFromRunner('runner shutdown');
      FCommandQueue.Close;
      if FOrchestrator <> nil then
        FOrchestrator.StopEngines;
    end;
    except
      on E: Exception do
      begin
        FRunnerFailed := True;
        FRunnerError := E.Message;
        AddGameLog(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
          ' [runner] error; message=' + E.Message);
        PublishSnapshot;
      end;
    end;
  finally
    PublishFinished;
  end;
end;

end.
