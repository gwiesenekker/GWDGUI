program running_game_lifecycle_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Classes, SysUtils, SyncObjs, uMainForm, uGameRunnerThread,
  uGameSetupForm, uGameMoveHistory, uGameOrchestrator, uGameTreeActor, uGameTreeBuilder;

type
  TLogRunner = class(TGameRunnerThread)
    procedure InjectWorkerLog;
  end;

  TObserver = class
    Lock: TCriticalSection;
    Ready, Complete, Rejected, TwoMoves: TEvent;
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
  Ready := TEvent.Create(nil, True, False, '');
  Complete := TEvent.Create(nil, True, False, '');
  Rejected := TEvent.Create(nil, True, False, '');
  TwoMoves := TEvent.Create(nil, True, False, '');
  Last := TGameRunnerSnapshot.Create;
end;

destructor TObserver.Destroy;
begin
  Last.Free;
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
  Check(GetCurrentThreadID = TGameRunnerThread(Sender).ThreadID,
    'snapshots must only be constructed/published on the owning runner thread');
  Lock.Acquire;
  try
    Last.AssignFrom(AData);
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

begin
  CheckCompletedResultSurvivesStop;
  CheckEditsWaitForRunner;
  CheckIllegalHumanInputIsRejected;
  WriteLn('OK');
end.
