program running_game_lifecycle_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces, Classes, SysUtils, SyncObjs, uMainForm, uGameRunnerThread,
  uGameSetupForm, uGameOrchestrator;

type
  TObserver = class
    Lock: TCriticalSection;
    Ready, Complete: TEvent;
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
  Last := TGameRunnerSnapshot.Create;
end;

destructor TObserver.Destroy;
begin
  Last.Free;
  Complete.Free;
  Ready.Free;
  Lock.Free;
  inherited Destroy;
end;

procedure TObserver.Snapshot(Sender: TObject; AData: TGameRunnerSnapshot);
begin
  Lock.Acquire;
  try
    Last.AssignFrom(AData);
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
  Runner: TGameRunnerThread;
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
  Runner := TGameRunnerThread.Create(Setup, 1, @Observer.Snapshot, nil);
  Game := nil;
  try
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

begin
  CheckCompletedResultSurvivesStop;
  WriteLn('OK');
end.
