unit uAnalyzerRunnerThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SyncObjs, SysUtils,
  uCancellationToken, uEngineBase, uGamePosition, uEngineRegistry, uGameTreeSearchRef,
  uDraughtsHubEngine, uPvSnapshot, uThreadMessageQueue;

type
  TAnalyzerRunMode = (
    armAnalyze,
    armMcts
  );

  TAnalyzerRunnerLogEvent = procedure(Sender: TObject; const AMessage: string) of object;
  TAnalyzerRunnerMoveEvent = procedure(Sender: TObject;
    const ASearch: TGameTreeSearchRef; const AMoveText: string) of object;
  TAnalyzerRunnerSnapshotEvent = procedure(Sender: TObject; ASnapshot: TPvSnapshot) of object;
  TAnalyzerRunnerFinishedEvent = procedure(Sender: TObject) of object;

  TAnalyzerRunnerThread = class(TThread)
  private
    FCommandQueue: TThreadMessageQueue;
    FEngine: THubEngine;
    FEngineLifetimeLock: TCriticalSection;
    FStopToken: TCancellationToken;
    FEngineDefinition: TExternalEngineDefinition;
    FLastPollTick: QWord;
    FLastPublishedPv: string;
    FPvGameTreeOnly: Boolean;
    FPvTransient: Boolean;
    FPvSearch: TGameTreeSearchRef;
    FOnFinished: TAnalyzerRunnerFinishedEvent;
    FOnLog: TAnalyzerRunnerLogEvent;
    FOnMove: TAnalyzerRunnerMoveEvent;
    FOnSnapshot: TAnalyzerRunnerSnapshotEvent;
    FRunMode: TAnalyzerRunMode;
    FFailureText: string;
    FStarted: Boolean;
    FPvBasePosition: TGamePosition; // nil when the request had none
    FPvBasePly: Integer;
    FPvLock: TCriticalSection;
    procedure ApplyPvContext(ACommand: TObject; AGameTreeOnly: Boolean);
    procedure DrainCommands;
    function DisplayName: string;
    procedure HandleCommand(ACommand: TObject);
    procedure PublishSnapshot;
    procedure RuntimeLog(Sender: TObject; const AMessage: string);
    procedure PostCommand(ACommand: TObject);
  protected
    procedure Execute; override;
    procedure DoTerminate; override;
  public
    constructor Create(AEngineDefinition: TExternalEngineDefinition;
      ALogEvent: TAnalyzerRunnerLogEvent;
      ASnapshotEvent: TAnalyzerRunnerSnapshotEvent;
      AFinishedEvent: TAnalyzerRunnerFinishedEvent;
      ARunMode: TAnalyzerRunMode = armAnalyze;
      AMoveEvent: TAnalyzerRunnerMoveEvent = nil);
    destructor Destroy; override;

    procedure PostAnalyze(const AStartingFEN, AMovesText: string;
      ABasePosition: TGamePosition; ABasePly: Integer; ATerminal: Boolean;
      const ASearch: TGameTreeSearchRef; ATransient: Boolean = False;
      AAnalyzeSeconds: Double = 1000);
    procedure PostThinkOnce(const AStartingFEN, AMovesText: string;
      ABasePosition: TGamePosition; ABasePly: Integer; AThinkSeconds: Double;
      const ASearch: TGameTreeSearchRef; ATransient: Boolean = False);
    procedure PostStopSearch;
    procedure PostShutdown;
    // Why the engine could not be started or stopped working ('' after a
    // normal close). Set before the finished event; read it from that event.
    property FailureText: string read FFailureText;
    // True once the engine was ready (a later failure stopped a working engine).
    property Started: Boolean read FStarted;
  end;

implementation

const
  AnalyzerPollIntervalMs = 200;

type
  TAnalyzerCommandKind = (
    accAnalyze,
    accThinkOnce,
    accStopSearch,
    accShutdown
  );

  TAnalyzerCommand = class(TThreadMessage)
  private
    FBasePosition: TGamePosition; // owned copy, nil when none was given
    FBasePly: Integer;
    FCommandKind: TAnalyzerCommandKind;
    FMovesText: string;
    FSearch: TGameTreeSearchRef;
    FStartingFEN: string;
    FTerminal: Boolean;
    FThinkSeconds: Double;
    FTransient: Boolean;
  public
    constructor Create(ACommandKind: TAnalyzerCommandKind); reintroduce;
    destructor Destroy; override;
    property BasePosition: TGamePosition read FBasePosition;
    property BasePly: Integer read FBasePly write FBasePly;
    property CommandKind: TAnalyzerCommandKind read FCommandKind;
    property MovesText: string read FMovesText write FMovesText;
    property Search: TGameTreeSearchRef read FSearch write FSearch;
    property StartingFEN: string read FStartingFEN write FStartingFEN;
    property Terminal: Boolean read FTerminal write FTerminal;
    property ThinkSeconds: Double read FThinkSeconds write FThinkSeconds;
    property Transient: Boolean read FTransient write FTransient;
  end;

constructor TAnalyzerCommand.Create(ACommandKind: TAnalyzerCommandKind);
const
  CommandNames: array[TAnalyzerCommandKind] of string = (
    'analyzer-analyze',
    'analyzer-think-once',
    'analyzer-stop-search',
    'analyzer-shutdown'
  );
begin
  inherited Create(CommandNames[ACommandKind]);
  FCommandKind := ACommandKind;
end;

destructor TAnalyzerCommand.Destroy;
begin
  FBasePosition.Free;
  inherited Destroy;
end;

constructor TAnalyzerRunnerThread.Create(AEngineDefinition: TExternalEngineDefinition;
  ALogEvent: TAnalyzerRunnerLogEvent; ASnapshotEvent: TAnalyzerRunnerSnapshotEvent;
  AFinishedEvent: TAnalyzerRunnerFinishedEvent; ARunMode: TAnalyzerRunMode;
  AMoveEvent: TAnalyzerRunnerMoveEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FEngineDefinition := TExternalEngineDefinition.Create;
  FEngineDefinition.Assign(AEngineDefinition);
  FCommandQueue := TThreadMessageQueue.Create(True);
  FEngineLifetimeLock := TCriticalSection.Create;
  FStopToken := TCancellationToken.Create;
  FPvLock := TCriticalSection.Create;
  FOnLog := ALogEvent;
  FOnSnapshot := ASnapshotEvent;
  FOnFinished := AFinishedEvent;
  FOnMove := AMoveEvent;
  FRunMode := ARunMode;
end;

destructor TAnalyzerRunnerThread.Destroy;
begin
  PostShutdown;
  // Finished is set before DoTerminate on FPC. Join explicitly on every platform
  // before freeing fields that completion callbacks can still access.
  WaitFor;
  FEngine.Free;
  FEngineLifetimeLock.Free;
  FStopToken.Free;
  FPvLock.Free;
  FPvBasePosition.Free;
  FCommandQueue.Free;
  FEngineDefinition.Free;
  inherited Destroy;
end;

function TAnalyzerRunnerThread.DisplayName: string;
begin
  if FRunMode = armMcts then
    Result := 'MCTS annotator'
  else
    Result := 'Annotator';
end;

procedure TAnalyzerRunnerThread.RuntimeLog(Sender: TObject; const AMessage: string);
var
  LPvText: string;
begin
  if Assigned(FOnLog) then
    FOnLog(Self, AMessage);
  if FEngine = nil then
    Exit;
  LPvText := FEngine.PrincipalVariation;
  FPvLock.Acquire;
  try
    if (Trim(LPvText) = '') or (LPvText = FLastPublishedPv) then
      Exit;
  finally
    FPvLock.Release;
  end;
  if not Terminated then
    PublishSnapshot;
end;

procedure TAnalyzerRunnerThread.PublishSnapshot;
var
  Snapshot: TPvSnapshot;
begin
  if FEngine = nil then
    Exit;
  Snapshot := TPvSnapshot.Create;
  FPvLock.Acquire;
  try
    Snapshot.SetDataWithSearch(FPvBasePosition, FPvBasePly,
      FEngine.PrincipalVariation, FEngine.LastScore, FEngine.LastDepth,
      FEngine.LastTimeText, FPvSearch, FPvGameTreeOnly, FPvTransient);
    FLastPublishedPv := FEngine.PrincipalVariation;
  finally
    FPvLock.Release;
  end;
  if Assigned(FOnSnapshot) then
    FOnSnapshot(Self, Snapshot)
  else
    Snapshot.Free;
end;

procedure TAnalyzerRunnerThread.ApplyPvContext(ACommand: TObject;
  AGameTreeOnly: Boolean);
var
  Command: TAnalyzerCommand;
begin
  if not (ACommand is TAnalyzerCommand) then
    Exit;
  Command := TAnalyzerCommand(ACommand);

  FPvLock.Acquire;
  try
    if Command.BasePosition = nil then
      FreeAndNil(FPvBasePosition)
    else
      AssignGamePosition(FPvBasePosition, Command.BasePosition);
    FPvBasePly := Command.BasePly;
    FPvSearch := Command.Search;
    FPvGameTreeOnly := AGameTreeOnly;
    FPvTransient := Command.Transient;
    FLastPublishedPv := '';
  finally
    FPvLock.Release;
  end;
end;

procedure TAnalyzerRunnerThread.HandleCommand(ACommand: TObject);
var
  Command: TAnalyzerCommand;
  MoveText: string;
  Moves: TStringList;
begin
  if not (ACommand is TAnalyzerCommand) then
    Exit;
  Command := TAnalyzerCommand(ACommand);
  case Command.CommandKind of
    accAnalyze:
      begin
        if FEngine = nil then
          Exit;
        Moves := TStringList.Create;
        try
          ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(Command.MovesText)),
            Moves);
          FEngine.StopSearch;
          FEngine.SetGamePosition(Command.StartingFEN, Moves);
          ApplyPvContext(Command, False);
          if Command.Terminal then
          begin
            PublishSnapshot;
            if Assigned(FOnLog) then
              FOnLog(Self, DisplayName + ' idle; terminal position');
            Exit;
          end;
          if FRunMode = armMcts then
            FEngine.StartMcts
          else
          begin
            FEngine.SetClockInfo(1, Command.ThinkSeconds, 0);
            FEngine.StartAnalyzing;
          end;
        finally
          Moves.Free;
        end;
      end;
    accThinkOnce:
      begin
        if FEngine = nil then
          Exit;
        Moves := TStringList.Create;
        try
          ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(Command.MovesText)),
            Moves);
          FEngine.StopSearch;
          FEngine.SetGamePosition(Command.StartingFEN, Moves);
          ApplyPvContext(Command, True);
          FEngine.SetClockInfo(1, Command.ThinkSeconds, 0);
          MoveText := Trim(FEngine.StartThinking);
        finally
          Moves.Free;
        end;
        if (MoveText <> '') and Assigned(FOnMove) then
          FOnMove(Self, Command.Search, MoveText);
      end;
    accStopSearch:
      begin
        if FEngine <> nil then
          FEngine.StopSearch;
      end;
    accShutdown:
      Terminate;
  end;
end;

procedure TAnalyzerRunnerThread.DrainCommands;
var
  CommandObject: TObject;
begin
  while not Terminated and FCommandQueue.TryPop(CommandObject) do
  begin
    try
      HandleCommand(CommandObject);
    finally
      CommandObject.Free;
    end;
  end;
end;

procedure TAnalyzerRunnerThread.PostCommand(ACommand: TObject);
begin
  if ACommand = nil then
    Exit;
  if FCommandQueue = nil then
  begin
    ACommand.Free;
    Exit;
  end;
  // An owning queue also destroys a command rejected after Close.
  FCommandQueue.TryPost(ACommand);
end;

procedure TAnalyzerRunnerThread.Execute;
var
  CommandObject: TObject;
  Tick: QWord;
begin
  try
    try
      if Terminated then Exit;
      FEngineLifetimeLock.Acquire;
      try
        FEngine := THubEngine.Create(FEngineDefinition);
        FEngine.StopToken := FStopToken;
      finally
        FEngineLifetimeLock.Release;
      end;
      if Terminated then Exit;
      FEngine.OnLog := @RuntimeLog;
      if Assigned(FOnLog) then
        FOnLog(Self, 'Opening ' + DisplayName + ': ' +
          EnginePickerDisplayName(FEngineDefinition, 0));
      if not FEngine.LaunchAndInit then
      begin
        FFailureText := Trim(FEngine.LastError);
        if FFailureText = '' then
          FFailureText := 'the engine did not start or did not answer the Hub handshake';
        if Assigned(FOnLog) then
          FOnLog(Self, DisplayName + ' launch failed: ' + FFailureText);
        Exit;
      end;
      FStarted := True;
      if Assigned(FOnLog) then
        FOnLog(Self, DisplayName + ' ready');

      while not Terminated do
      begin
        if FCommandQueue.WaitPop(CommandObject, 50) then
        begin
          try
            HandleCommand(CommandObject);
          finally
            CommandObject.Free;
          end;
          DrainCommands;
        end;
        if Terminated then
          Break;
        Tick := GetTickCount64;
        if (FLastPollTick = 0) or
          (Tick - FLastPollTick >= AnalyzerPollIntervalMs) then
        begin
          FLastPollTick := Tick;
          if FEngine <> nil then
            FEngine.PollOutput;
        end;
      end;
    except
      on E: Exception do
        if not Terminated then
        begin
          FFailureText := E.Message;
          if Assigned(FOnLog) then
            FOnLog(Self, DisplayName + ' failed: ' + E.ClassName + ': ' + E.Message);
        end;
    end;
  finally
    if FCommandQueue <> nil then
      FCommandQueue.Close;
    FEngineLifetimeLock.Acquire;
    try
      if FEngine <> nil then
      begin
        FEngine.OnLog := nil;
        FreeAndNil(FEngine);
      end;
    finally
      FEngineLifetimeLock.Release;
    end;
    if Assigned(FOnLog) then
      FOnLog(Self, DisplayName + ' closed');
  end;
end;

procedure TAnalyzerRunnerThread.DoTerminate;
begin
  // Runs even when the RTL bypasses Execute after an immediate shutdown.
  try
    if Assigned(FOnFinished) then FOnFinished(Self);
  finally inherited DoTerminate; end;
end;

procedure TAnalyzerRunnerThread.PostAnalyze(const AStartingFEN, AMovesText: string;
  ABasePosition: TGamePosition; ABasePly: Integer; ATerminal: Boolean;
  const ASearch: TGameTreeSearchRef; ATransient: Boolean;
  AAnalyzeSeconds: Double);
var
  Command: TAnalyzerCommand;
begin
  Command := TAnalyzerCommand.Create(accAnalyze);
  Command.StartingFEN := AStartingFEN;
  Command.MovesText := AMovesText;
  Command.BasePly := ABasePly;
  Command.Terminal := ATerminal;
  Command.Search := ASearch;
  Command.Transient := ATransient;
  Command.ThinkSeconds := AAnalyzeSeconds;
  if ABasePosition <> nil then
    Command.FBasePosition := ABasePosition.Clone;
  PostCommand(Command);
end;

procedure TAnalyzerRunnerThread.PostThinkOnce(const AStartingFEN,
  AMovesText: string; ABasePosition: TGamePosition; ABasePly: Integer;
  AThinkSeconds: Double; const ASearch: TGameTreeSearchRef;
  ATransient: Boolean);
var
  Command: TAnalyzerCommand;
begin
  Command := TAnalyzerCommand.Create(accThinkOnce);
  Command.StartingFEN := AStartingFEN;
  Command.MovesText := AMovesText;
  Command.BasePly := ABasePly;
  Command.ThinkSeconds := AThinkSeconds;
  Command.Search := ASearch;
  Command.Transient := ATransient;
  if ABasePosition <> nil then
    Command.FBasePosition := ABasePosition.Clone;
  PostCommand(Command);
end;

procedure TAnalyzerRunnerThread.PostStopSearch;
var
  Command: TAnalyzerCommand;
begin
  Command := TAnalyzerCommand.Create(accStopSearch);
  PostCommand(Command);
end;

procedure TAnalyzerRunnerThread.PostShutdown;
var
  Command: TAnalyzerCommand;
begin
  Terminate;
  FStopToken.Cancel;
  // Interrupt a worker waiting for a search/stop acknowledgement. Protect the
  // engine's lifetime while shutdown races with creation or final cleanup.
  FEngineLifetimeLock.Acquire;
  try
    if FEngine <> nil then
      FEngine.RequestStop;
  finally
    FEngineLifetimeLock.Release;
  end;
  Command := TAnalyzerCommand.Create(accShutdown);
  PostCommand(Command);
end;

end.
