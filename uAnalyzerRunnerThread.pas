unit uAnalyzerRunnerThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SyncObjs, SysUtils,
  uDraughtsBoard, uEngineBase, uEngineRegistry, uGameTreeSearchRef,
  uHubEngine, uPvSnapshot, uThreadMessageQueue;

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
    FPvBaseBoard: TDraughtsBoard;
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
  public
    constructor Create(AEngineDefinition: TExternalEngineDefinition;
      ALogEvent: TAnalyzerRunnerLogEvent;
      ASnapshotEvent: TAnalyzerRunnerSnapshotEvent;
      AFinishedEvent: TAnalyzerRunnerFinishedEvent;
      ARunMode: TAnalyzerRunMode = armAnalyze;
      AMoveEvent: TAnalyzerRunnerMoveEvent = nil);
    destructor Destroy; override;

    procedure PostAnalyze(const AStartingFEN, AMovesText: string;
      ABaseBoard: TDraughtsBoard; ABasePly: Integer; ATerminal: Boolean;
      const ASearch: TGameTreeSearchRef; ATransient: Boolean = False;
      AAnalyzeSeconds: Double = 1000);
    procedure PostThinkOnce(const AStartingFEN, AMovesText: string;
      ABaseBoard: TDraughtsBoard; ABasePly: Integer; AThinkSeconds: Double;
      const ASearch: TGameTreeSearchRef; ATransient: Boolean = False);
    procedure PostStopSearch;
    procedure PostShutdown;
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
    FBaseBoard: TDraughtsBoard;
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
    property BaseBoard: TDraughtsBoard read FBaseBoard;
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
  FBaseBoard := TDraughtsBoard.Create;
end;

destructor TAnalyzerCommand.Destroy;
begin
  FBaseBoard.Free;
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
  FPvBaseBoard := TDraughtsBoard.Create;
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
  WaitFor;
  FEngine.Free;
  FPvLock.Free;
  FPvBaseBoard.Free;
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
    Snapshot.SetDataWithSearch(FPvBaseBoard, FPvBasePly,
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
    FPvBaseBoard.AssignFrom(Command.BaseBoard);
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
        ApplyPvContext(Command, False);
        if FEngine = nil then
          Exit;
        if Command.Terminal then
        begin
          FEngine.StopSearch;
          PublishSnapshot;
          if Assigned(FOnLog) then
            FOnLog(Self, DisplayName + ' idle; terminal position');
          Exit;
        end;
        Moves := TStringList.Create;
        try
          ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(Command.MovesText)),
            Moves);
          FEngine.StopSearch;
          FEngine.SetGamePosition(Command.StartingFEN, Moves);
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
        ApplyPvContext(Command, True);
        if FEngine = nil then
          Exit;
        Moves := TStringList.Create;
        try
          ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(Command.MovesText)),
            Moves);
          FEngine.StopSearch;
          FEngine.SetGamePosition(Command.StartingFEN, Moves);
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
  while FCommandQueue.TryPop(CommandObject) do
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
  if (FCommandQueue = nil) or (not FCommandQueue.TryPost(ACommand)) then
    ACommand.Free;
end;

procedure TAnalyzerRunnerThread.Execute;
var
  CommandObject: TObject;
  Tick: QWord;
begin
  try
    FEngine := THubEngine.Create(FEngineDefinition);
    FEngine.OnLog := @RuntimeLog;
    if Assigned(FOnLog) then
      FOnLog(Self, 'Opening ' + DisplayName + ': ' +
        EnginePickerDisplayName(FEngineDefinition, 0));
    if not FEngine.LaunchAndInit then
    begin
      if Assigned(FOnLog) then
        FOnLog(Self, DisplayName + ' launch failed');
      Exit;
    end;
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
  finally
    if FCommandQueue <> nil then
      FCommandQueue.Close;
    if FEngine <> nil then
    begin
      FEngine.OnLog := nil;
      FEngine.Free;
      FEngine := nil;
    end;
    if Assigned(FOnLog) then
      FOnLog(Self, DisplayName + ' closed');
    if Assigned(FOnFinished) then
      FOnFinished(Self);
  end;
end;

procedure TAnalyzerRunnerThread.PostAnalyze(const AStartingFEN, AMovesText: string;
  ABaseBoard: TDraughtsBoard; ABasePly: Integer; ATerminal: Boolean;
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
  if ABaseBoard <> nil then
    Command.BaseBoard.AssignFrom(ABaseBoard);
  PostCommand(Command);
end;

procedure TAnalyzerRunnerThread.PostThinkOnce(const AStartingFEN,
  AMovesText: string; ABaseBoard: TDraughtsBoard; ABasePly: Integer;
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
  if ABaseBoard <> nil then
    Command.BaseBoard.AssignFrom(ABaseBoard);
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
  Command := TAnalyzerCommand.Create(accShutdown);
  PostCommand(Command);
  Terminate;
end;

end.
