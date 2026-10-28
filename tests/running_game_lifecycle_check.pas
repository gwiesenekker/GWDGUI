program running_game_lifecycle_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, SyncObjs, uThreadMessageQueue, uPvSnapshot, uAnalyzerRunnerThread, uGameTreeSearchRef, uRunningGame, uGameGuiMessages, uGameRunnerThread,
  uEngineRegistry, uDraughtsBoard, uGameSetupTypes, uGameMoveHistory, uGameOrchestrator, uGameTreeActor, uGameTreeBuilder, uDraughtsPosition, uDraughtsHubEngine, uDraughtsDxpEngine;

type
  TLogRunner = class(TGameRunnerThread)
    procedure InjectWorkerLog;
  end;

  TObserver = class
    Lock: TCriticalSection;
    Ready, Complete, Rejected, TwoMoves, Live, OneMove: TEvent;
    Last: TGameRunnerSnapshot;
    constructor Create;
    destructor Destroy; override;
    procedure Snapshot(Sender: TObject; AData: TGameRunnerSnapshot);
  end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AMessage);
    Halt(1);
  end;
end;

constructor TObserver.Create;
begin
  inherited Create;
  Lock := TCriticalSection.Create;
  Live := TEvent.Create(nil, True, False, '');
  OneMove := TEvent.Create(nil, True, False, '');
  Ready := TEvent.Create(nil, True, False, '');
  Complete := TEvent.Create(nil, True, False, '');
  Rejected := TEvent.Create(nil, True, False, '');
  TwoMoves := TEvent.Create(nil, True, False, '');
  Last := TGameRunnerSnapshot.Create;
end;

destructor TObserver.Destroy;
begin
  Last.Free;
  Live.Free; OneMove.Free;
  TwoMoves.Free;
  Rejected.Free;
  Complete.Free;
  Ready.Free;
  Lock.Free;
  inherited Destroy;
end;

procedure TLogRunner.InjectWorkerLog;
begin
  RuntimeLog(Self, 'asynchronous engine worker log');
end;

procedure TObserver.Snapshot(Sender: TObject; AData: TGameRunnerSnapshot);
begin
  Check(AData.LiveUpdate or (GetCurrentThreadID = TGameRunnerThread(Sender).ThreadID),
    'full position snapshots must only be constructed on the owning runner thread');
  Lock.Acquire;
  try
    Last.AssignFrom(AData);
    if AData.LiveUpdate and (AData.PrincipalVariation <> '') then
    begin
      Check((AData.PlyCount = 0) and (AData.Position is TDraughtsPosition) and
        (TDraughtsPosition(AData.Position).Board.MovesPlayedCount = 0) and
        (TDraughtsPosition(AData.Position).Board[32] = pkWhiteMan) and
        (TDraughtsPosition(AData.Position).Board[28] = pkEmpty) and
        (AData.PvBasePosition <> nil) and (AData.PvBasePosition.PositionKey = AData.Position.PositionKey) and (AData.PvBasePly = 0), 'live update must retain the last immutable position/history');
      Check((AData.PvScore = '0.4') and (AData.PvSnapshot.Depth = '15'),
        'live snapshot includes locked engine score and depth');
      Live.SetEvent;
    end;
    if AData.PlyCount = 1 then OneMove.SetEvent;
    if Pos('human move rejected', AData.LogLines.Text) > 0 then
      Rejected.SetEvent;
    if AData.PlyCount = 2 then
      TwoMoves.SetEvent;
    if AData.State = gosRunning then
      Ready.SetEvent;
    if AData.State = gosGameOver then
      Complete.SetEvent;
  finally
    AData.Free;
    Lock.Release;
  end;
end;

procedure FakeLiveHub;
var Line: string;
begin
  while not EOF(Input) do
  begin
    ReadLn(Line);
    if Line = 'hub' then begin WriteLn('id name=LiveHub'); WriteLn('wait'); end
    else if Line = 'init' then WriteLn('ready')
    else if Line = 'go think' then
    begin
      Sleep(600); // Let the initial state/log publication throttle expire.
      // One info line only: a later line must not be needed to publish this PV.
      WriteLn('info pv="32-28" score=0.4 depth=15 time=0.1'); Flush(Output);
      Sleep(2000);
      WriteLn('done move=32-28');
    end
    else if Line = 'quit' then Exit;
    Flush(Output);
  end;
end;

procedure CheckLiveInfoDuringThink(ShowStdout: Boolean);
var Setup: TGameSetup; Definition: TExternalEngineDefinition;
  Observer: TObserver; Runner: TGameRunnerThread;
begin
  Definition := TExternalEngineDefinition.Create; Observer := TObserver.Create;
  Setup := Default(TGameSetup);
  Setup.StartingFEN := DefaultStartingFEN; Setup.TimeControl := DefaultTimeControl;
  Setup.WhitePlayer := pkRegistered; Setup.BlackPlayer := pkHuman;
  Definition.Kind := eekHub; Definition.HubId := 'LiveHub';
  Definition.ExePath := ExpandFileName(ParamStr(0)); Definition.Arguments := '--live-hub';
  Setup.WhiteEngine := Definition;
  Runner := TGameRunnerThread.Create(Setup, 7, @Observer.Snapshot, nil);
  try
    Runner.PostShowStdout(ShowStdout);
    Runner.Start;
    Check(Observer.Ready.WaitFor(5000) = wrSignaled, 'live-info runner becomes ready');
    Check(Observer.Live.WaitFor(1500) = wrSignaled, 'PV/score/log must arrive before the think completes; stdout=' + BoolToStr(ShowStdout, True));
    Check(Observer.OneMove.WaitFor(0) <> wrSignaled, 'live update must precede accepted move');
    Check(Observer.OneMove.WaitFor(5000) = wrSignaled, 'runner publishes completed move after live updates');
  finally Runner.PostStop; Runner.WaitFor; Runner.Free; Observer.Free; Definition.Free; end;
end;

procedure CheckCompletedResultSurvivesStop;
var
  Setup: TGameSetup;
  Observer: TObserver;
  Runner: TLogRunner;
  Game: TRunningGame;
  Input: TRunningSnapshotTreeInput;
  Ready, Complete: Boolean;
begin
  Setup := Default(TGameSetup);
  Setup.StartingFEN := 'W:W31-50:B1-20';
  Setup.WhitePlayer := pkHuman;
  Setup.BlackPlayer := pkHuman;
  Setup.TimeControl := DefaultTimeControl;
  Setup.TimeControl.MinutesPerPeriod := 0;
  Observer := TObserver.Create;
  Runner := TLogRunner.Create(Setup, 1, @Observer.Snapshot, nil);
  Game := nil;
  try
    Runner.InjectWorkerLog;
    Runner.Start;
    Ready := Observer.Ready.WaitFor(5000) = wrSignaled;
    Runner.PostHumanMove('32-28');
    Complete := Observer.Complete.WaitFor(5000) = wrSignaled;
    if not Complete then
      Runner.PostStop;
    Runner.WaitFor;
    Check(Ready and Complete, 'runner must deliver a real completed game');
    Check((Observer.Last.State = gosGameOver) and
      (Observer.Last.GameResult = '0-2'), 'zero-clock game must end on time');
    Game := TRunningGame.Create(1, 'test', nil, pkHuman, pkHuman,
      '', '', 'White', 'Black', nil, Setup);
    Game.AssignRunnerSnapshot(Observer.Last);
    Game.RequestStop('Stop after final snapshot');
    Game.SnapshotTreeInput(nil, 'test', Input);
    Check((Input.State = gosGameOver) and (Input.ResultText = '0-2'),
      'Stop after the final snapshot must preserve the result and terminal state');
    Observer.Last.MarkStopped('Stop completed game again');
    Check((Observer.Last.State = gosGameOver) and
      (Observer.Last.GameResult = '0-2'), 'repeated Stop must preserve the result');
  finally
    Game.Free;
    Runner.Free;
    Observer.Free;
  end;
end;

procedure CheckEditsWaitForRunner;
var
  Setup: TGameSetup;
  Game: TRunningGame;
  Snapshot: TGameRunnerSnapshot;
  Command: TGameTreeCommand;
begin
  Setup := Default(TGameSetup);
  Setup.StartingFEN := 'W:W31-50:B1-20';
  Setup.TimeControl := DefaultTimeControl;
  Game := TRunningGame.Create(2, 'lifecycle', nil, pkHuman, pkHuman,
    '', '', 'White', 'Black', nil, Setup);
  Snapshot := TGameRunnerSnapshot.Create;
  try
    Check(not Game.CanEditGameTree, 'starting games must not allow tree edits');
    Game.MarkRunningIfStarting;
    Check(not Game.CanEditGameTree, 'running games must not allow tree edits');
    Game.RequestStop('test');
    Snapshot.MarkStopped('test');
    Game.AssignRunnerSnapshot(Snapshot);
    Command := Game.GameTreeActor.CreateSetHeaderCommand(
      GameTreeHeaderInput('lifecycle', 'test', 'White', 'Black', '*',
        Setup.StartingFEN, False, Setup.TimeControl, gosStopped, 'Stopped'));
    try
      Game.GameTreeActor.ExecuteCommand(Command);
      Check(Command.Accepted, 'stopped snapshot header should be accepted');
    finally
      Command.Free;
    end;
    Check(Game.State = gosStopped, 'tree can show stopped before runner finishes');
    Check(not Game.CanEditGameTree,
      'stopped tree must stay read-only until pending runner snapshots are drained');
    Command := Game.GameTreeActor.CreateSetHeaderCommand(
      GameTreeHeaderInput('lifecycle', 'test', 'White', 'Black', '0-2',
        Setup.StartingFEN, False, Setup.TimeControl, gosGameOver, 'Game over'));
    try
      Game.GameTreeActor.ExecuteCommand(Command);
      Check(Command.Accepted, 'completed snapshot header should be accepted');
    finally
      Command.Free;
    end;
    Check(not Game.CanEditGameTree,
      'game-over tree must also wait for the runner to finish');
    Game.MarkFinished;
    Check(Game.CanEditGameTree, 'finished games should allow tree exploration');
    Game.RequestRemoval;
    Check(not Game.CanEditGameTree, 'games pending removal must reject tree edits');
  finally
    Snapshot.Free;
    Game.Free;
  end;
end;

procedure CheckIllegalHumanInputIsRejected;
var
  Setup: TGameSetup;
  Observer: TObserver;
  Runner: TLogRunner;
  Rejected, Continued: Boolean;
  Moves: TGameMoveDataArray;
  CopySnapshot: TGameRunnerSnapshot;
begin
  Setup := Default(TGameSetup);
  Setup.StartingFEN := 'W:W31-50:B1-20';
  Setup.WhitePlayer := pkHuman;
  Setup.BlackPlayer := pkHuman;
  Setup.TimeControl := DefaultTimeControl;
  Observer := TObserver.Create;
  Runner := TLogRunner.Create(Setup, 2, @Observer.Snapshot, nil);
  try
    Runner.Start;
    Check(Observer.Ready.WaitFor(5000) = wrSignaled, 'human game should initialize');
    Sleep(600);
    Runner.InjectWorkerLog;
    Runner.PostHumanMove('1-50');
    Rejected := Observer.Rejected.WaitFor(3000) = wrSignaled;
    Observer.Lock.Acquire;
    try
      Check(Rejected, 'illegal human input should be reported as rejected');
      Check((Observer.Last.State = gosRunning) and (Observer.Last.PlyCount = 0),
        'rejection must leave the running position unchanged');
      Check(Observer.Last.LastError = '', 'rejection must not fail the runner');
    finally
      Observer.Lock.Release;
    end;
    Runner.PostHumanMove('32-28');
    Runner.PostHumanMove('32-28'); // stale duplicate, now Black is to move
    Runner.PostHumanMove('18-23');
    Continued := Observer.TwoMoves.WaitFor(5000) = wrSignaled;
    Observer.Lock.Acquire;
    try
      Check(Continued and (Observer.Last.State = gosRunning),
        'legal moves after rejected/stale commands must continue the game');
      Check(Observer.Last.MovesPlayedText = '32-28 18-23',
        'only the two legal commands should reach the game history');
      Check(Observer.Last.WhiteUsedSeconds >= 0.05,
        'rejecting input must not reset the human clock');
      Moves := Observer.Last.MoveData;
      Check((Length(Moves) = 2) and (Moves[0].MoveText = '32-28') and
        (Moves[1].MoveText = '18-23'), 'snapshot must carry all completed moves');
      Check((Moves[0].SecondsUsed >= 0.05) and Moves[0].HasClockInfo and
        (Moves[1].WhiteUsedSeconds = Moves[0].WhiteUsedSeconds) and
        (Moves[1].BlackUsedSeconds >= Moves[0].BlackUsedSeconds),
        'snapshot must retain move times and both clocks for each completed move');
      CopySnapshot := TGameRunnerSnapshot.Create;
      try
        CopySnapshot.AssignFrom(Observer.Last);
        Moves[0].MoveText := 'changed copy';
        Check((Observer.Last.MoveData[0].MoveText = '32-28') and
          (CopySnapshot.MoveData[0].MoveText = '32-28'),
          'snapshots and returned history arrays must own independent records');
      finally
        CopySnapshot.Free;
      end;
    finally
      Observer.Lock.Release;
    end;
  finally
    Runner.PostStop;
    Runner.WaitFor;
    Runner.Free;
    Observer.Free;
  end;
end;

type
  TCountedRunnerSnapshot = class(TGameRunnerSnapshot)
    destructor Destroy; override;
  end;
  TCountedPvSnapshot = class(TPvSnapshot)
    destructor Destroy; override;
  end;
  TCountedObject = class
    destructor Destroy; override;
  end;
var RunnerSnapshotsFreed, PvSnapshotsFreed, ObjectsFreed: Integer;
destructor TCountedRunnerSnapshot.Destroy;
begin Inc(RunnerSnapshotsFreed); inherited Destroy; end;
destructor TCountedPvSnapshot.Destroy;
begin Inc(PvSnapshotsFreed); inherited Destroy; end;
destructor TCountedObject.Destroy;
begin Inc(ObjectsFreed); inherited Destroy; end;

procedure CheckOwnedSetupAndSnapshot;
var Setup, CopySetup: TGameSetup; Game: TRunningGame;
  Snapshot: TGameRunnerSnapshot; Data: TRunningSnapshotTreeInput;
  Log: TRunningSnapshotLogInput; Keys: TStringList;
begin
  Setup := Default(TGameSetup); CopySetup := Default(TGameSetup);
  Setup.StartingFEN := DefaultStartingFEN; Setup.TimeControl := DefaultTimeControl;
  Setup.WhiteEngine := TExternalEngineDefinition.Create;
  Setup.BlackEngine := TExternalEngineDefinition.Create;
  Setup.WhiteEngine.Arguments := '--original-white'; Setup.BlackEngine.Arguments := '--original-black';
  Keys := TStringList.Create; Keys.Add('reserved-engine');
  Game := TRunningGame.Create(77, 'ownership', nil, pkRegistered, pkRegistered,
    'white-key', 'black-key', 'White', 'Black', Keys, Setup);
  Snapshot := TGameRunnerSnapshot.Create;
  try
    Setup.WhiteEngine.Arguments := 'mutated source';
    FreeAndNil(Setup.WhiteEngine); FreeAndNil(Setup.BlackEngine); Keys.Clear;
    Game.AssignSetupTo(CopySetup);
    Check((CopySetup.WhiteEngine.Arguments = '--original-white') and
      (CopySetup.BlackEngine.Arguments = '--original-black'), 'game owns independent setup definitions');
    CopySetup.WhiteEngine.Arguments := 'mutated output';
    FreeAndNil(CopySetup.WhiteEngine); FreeAndNil(CopySetup.BlackEngine);
    Game.AssignSetupTo(CopySetup);
    Check(CopySetup.WhiteEngine.Arguments = '--original-white', 'returned setup definitions are independent copies');
    Game.AddReservationKeysTo(Keys);
    Check((Keys.Count = 1) and (Keys[0] = 'reserved-engine'), 'game owns reservation-key copies');
    Snapshot.LogLines.Add('retained log');
    Snapshot.PvSnapshot.SetData(nil, 0, '32-28', '0.25', '12');
    Game.AssignRunnerSnapshot(Snapshot);
    Snapshot.LogLines.Clear; Snapshot.PvSnapshot.SetData(nil, 0, '34-30', '-1', '5');
    FreeAndNil(Snapshot);
    Game.SnapshotTreeInput(nil, 'ownership', Data); Game.SnapshotLogInput(Log);
    Check((Data.GameId = 77) and (Data.PrincipalVariation = '32-28') and
      (Data.PvScore = '0.25') and (Data.PvDepth = '12'), 'retained snapshot is independent of queued source lifetime');
    Check((Log.LogLineCount = 1) and (Pos('retained log', Log.LogLinesText) > 0), 'retained logs do not alias the delivered snapshot');
  finally
    CopySetup.WhiteEngine.Free; CopySetup.BlackEngine.Free;
    Setup.WhiteEngine.Free; Setup.BlackEngine.Free;
    Snapshot.Free; Game.Free; Keys.Free;
  end;
end;

procedure CheckGuiMessageOwnership;
var Queue: TThreadMessageQueue; Item: TObject; Snapshot: TCountedRunnerSnapshot;
  Pv: TCountedPvSnapshot; Borrowed: TCountedObject;
  Message: TRunnerSnapshotGuiMessage; Search: TGameTreeSearchRef; MoveMessage: TAnalyzerMoveGuiMessage;
begin
  RunnerSnapshotsFreed := 0; PvSnapshotsFreed := 0; ObjectsFreed := 0;
  Queue := TThreadMessageQueue.Create(True);
  try
    Snapshot := TCountedRunnerSnapshot.Create; Snapshot.LogLines.Add('queued');
    Queue.Post(TRunnerSnapshotGuiMessage.Create(9, Snapshot));
    Check(Queue.TryPop(Item), 'snapshot message is delivered');
    Message := TRunnerSnapshotGuiMessage(Item);
    Check((Message.GameId = 9) and (Message.Snapshot = Snapshot) and
      (Message.Snapshot.LogLines[0] = 'queued'), 'queue preserves message payload and ownership');
    Check(RunnerSnapshotsFreed = 0, 'popping does not destroy a snapshot before consumption');
    Item.Free;
    Check(RunnerSnapshotsFreed = 1, 'consumer disposal frees its owned runner snapshot exactly once');
    Pv := TCountedPvSnapshot.Create;
    Queue.Post(TAnalyzerSnapshotGuiMessage.Create(Pv)); Queue.Clear;
    Check(PvSnapshotsFreed = 1, 'clearing queued analysis frees its snapshot exactly once');
    Queue.Post(TRunnerSnapshotGuiMessage.Create(10, TCountedRunnerSnapshot.Create));
    Queue.Close;
    Check(not Queue.TryPost(TRunnerSnapshotGuiMessage.Create(11, TCountedRunnerSnapshot.Create)), 'closed queue rejects new snapshot messages');
    Check(RunnerSnapshotsFreed = 2, 'rejected owned snapshot is freed immediately');
    Queue.Clear;
    Check(RunnerSnapshotsFreed = 3, 'pending snapshot is freed when queue drains on shutdown');
    Borrowed := TCountedObject.Create;
    try
      // Finished notifications borrow an identity only; no runner methods are used.
      TAnalyzerFinishedGuiMessage.Create(TAnalyzerRunnerThread(Borrowed)).Free;
      TMctsFinishedGuiMessage.Create(TAnalyzerRunnerThread(Borrowed)).Free;
      Check(ObjectsFreed = 0, 'finished notifications must never own their runner');
    finally Borrowed.Free; end;
    Check(ObjectsFreed = 1, 'runner identity remains the session owner responsibility');
    Search := GameTreeSearchRef(1, 2, 3);
    MoveMessage := TAnalyzerMoveGuiMessage.Create(Search, ' 32-28 ');
    try Check(SameGameTreeSearchRef(MoveMessage.Search, Search) and (MoveMessage.MoveText = '32-28'), 'move message preserves exact search identity');
    finally MoveMessage.Free; end;
  finally Queue.Free; end;
end;

begin
  if ParamStr(1) = '--live-hub' then begin FakeLiveHub; Halt(0); end;
  CheckOwnedSetupAndSnapshot;
  CheckGuiMessageOwnership;
  CheckLiveInfoDuringThink(False);
  CheckLiveInfoDuringThink(True);
  CheckCompletedResultSurvivesStop;
  CheckEditsWaitForRunner;
  CheckIllegalHumanInputIsRejected;
  WriteLn('OK');
end.
