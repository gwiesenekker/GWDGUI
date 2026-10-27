program gui_delivery_check;
{$mode objfpc}{$H+}
{$IFNDEF GWDGUI_NONINTERACTIVE_TEST}{$FATAL Build with its LPI project}{$ENDIF}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Interfaces, Forms, Classes, SysUtils, SyncObjs,
  uMainForm, uGameGuiMessages, uGameRunnerThread, uRunningGame, uDraughtsBoard,
  uGameSetupTypes, uGameOrchestrator, uGameTree, uThreadMessageQueue,
  uPvSnapshot, uAnalysisCoordinator, uGameTreeSearchRef, uDraughtsPosition, uHubEngine, uDxpEngine;
type
  TCollector = class
    Lock: TCriticalSection;
    Ready: TEvent;
    Samples: array[0..2] of TGameRunnerSnapshot;
    procedure Snapshot(Sender: TObject; Data: TGameRunnerSnapshot);
  end;
  TCountedSnapshot = class(TGameRunnerSnapshot)
    destructor Destroy; override;
  end;
  TCountedPv = class(TPvSnapshot)
    destructor Destroy; override;
  end;
  TAnalysisBarrier = class(TAnalyzerLogGuiMessage)
    A, B: TGameTree;
    destructor Destroy; override;
  end;
  TBarrier = class(TAnalyzerLogGuiMessage)
    Game: TRunningGame;
    ExpectedScore: string;
    destructor Destroy; override;
  end;
var Freed, PvFreed, Barriers: Integer;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then begin WriteLn('FAIL: ', Text); Flush(Output); Halt(1); end; end;
function ScoreOf(Game: TRunningGame): string;
var Input: TRunningSnapshotTreeInput;
begin Game.SnapshotTreeInput(nil, 'delivery fixture', Input); Result := Input.PvScore; end;
function LogOf(Game: TRunningGame): string;
var Input: TRunningSnapshotLogInput;
begin Game.SnapshotLogInput(Input); Result := Input.LogLinesText; end;
destructor TCountedPv.Destroy;
begin Inc(PvFreed); inherited Destroy; end;
destructor TAnalysisBarrier.Destroy;
begin
  Check((A.Root.AnnotatorScore = 'latest') and (B.Root.AnnotatorScore = 'B'),
    'analysis coalesces independently per search and flushes before other messages');
  inherited Destroy;
end;
destructor TCountedSnapshot.Destroy;
begin Inc(Freed); inherited Destroy; end;
destructor TBarrier.Destroy;
begin
  Check((Game.MainlineCount = 2) and (ScoreOf(Game) = ExpectedScore),
    'pending snapshots flush before a non-snapshot message');
  Inc(Barriers); inherited Destroy;
end;
procedure TCollector.Snapshot(Sender: TObject; Data: TGameRunnerSnapshot);
begin
  Lock.Acquire;
  try
    if not Data.LiveUpdate and (Data.State = gosRunning) and (Data.PlyCount <= 2) then
    begin
      Samples[Data.PlyCount].Free;
      Samples[Data.PlyCount] := TGameRunnerSnapshot.Create;
      Samples[Data.PlyCount].AssignFrom(Data);
      Ready.SetEvent;
    end;
  finally Lock.Release; Data.Free; end;
end;
procedure GetSamples(Collector: TCollector; const Setup: TGameSetup);
var Runner: TGameRunnerThread; I: Integer; Found: Boolean; Tick: QWord;
begin
  Runner := TGameRunnerThread.Create(Setup, 999, @Collector.Snapshot, nil);
  try
    Runner.Start;
    for I := 0 to 2 do
    begin
      Tick := GetTickCount64;
      repeat
        Collector.Lock.Acquire;
        try Found := Collector.Samples[I] <> nil; finally Collector.Lock.Release; end;
        if Found then Break;
        Collector.Ready.WaitFor(20); Collector.Ready.ResetEvent;
      until GetTickCount64 - Tick > 5000;
      Check(Found, 'real runner produces full history fixture');
      if I = 0 then Runner.PostHumanMove('32-28')
      else if I = 1 then Runner.PostHumanMove('18-23');
    end;
  finally Runner.PostStop; Runner.WaitFor; Runner.Free; end;
end;
function NewGame(Form: TMainForm; Id: Integer; const Setup: TGameSetup): TRunningGame;
begin
  Result := TRunningGame.Create(Id, 'delivery fixture', nil, pkHuman, pkHuman,
    '', '', 'White', 'Black', nil, Setup);
  Form.TestRegisterGame(Result);
end;
procedure Post(Form: TMainForm; Id: Integer; Sample: TGameRunnerSnapshot;
  Live: Boolean; const Score: string);
var Data: TCountedSnapshot; I: Integer;
begin
  Data := TCountedSnapshot.Create; Data.AssignFrom(Sample); Data.TestLiveUpdate := Live;
  Data.PvSnapshot.SetData(Data.Position, Data.PlyCount, '37-32', Score, '10');
  for I := 1 to Length(Score) do Data.LogLines.Add('delivery ' + Score);
  Form.TestGuiEventQueue.Post(TRunnerSnapshotGuiMessage.Create(Id, Data));
end;
procedure CheckDelivery(Collector: TCollector; const Setup: TGameSetup);
var Form: TMainForm; A, B: TRunningGame; Barrier: TBarrier; I, Base: Integer;
  Node: TGameTreePlyNode;
begin
  Form := TMainForm.Create(nil); Base := Freed;
  try
    A := NewGame(Form, 101, Setup); B := NewGame(Form, 102, Setup);
    Post(Form, A.Id, Collector.Samples[1], False, 'old');
    Post(Form, B.Id, Collector.Samples[2], True, 'B-live');
    Post(Form, A.Id, Collector.Samples[2], False, 'full');
    Post(Form, A.Id, Collector.Samples[2], True, 'latest');
    Barrier := TBarrier.Create('delivery barrier'); Barrier.Game := A; Barrier.ExpectedScore := 'latest';
    Form.TestGuiEventQueue.Post(Barrier);
    Post(Form, A.Id, Collector.Samples[2], True, 'after-barrier');
    Form.TestGuiEventQueue.Post(TRunnerFinishedGuiMessage.Create(A.Id));
    Form.TestDrainGuiEvents(True);
    Check((Freed - Base = 5) and (Barriers = 1), 'coalesced and applied messages are freed exactly once');
    Check((A.Lifecycle = rglFinished) and (ScoreOf(A) = 'after-barrier'),
      'final snapshot applied before completion');
    Check((B.MainlineCount = 2) and (ScoreOf(B) = 'B-live'), 'games coalesce independently');
    for I := 1 to 2 do
    begin
      Node := A.GameTree.MainlineNode[I];
      Check(Node.HasClockInfo and Node.HasMoveTime and
        (Node.SecondsUsed = Collector.Samples[2].MoveData[I-1].SecondsUsed),
        'live snapshot retains full move-clock history');
    end;
    Check(Pos('delivery after-barrier', LogOf(A)) > 0, 'latest logs retained');
    // A duplicate finish and pending updates for a removed identity are harmless.
    Form.RemoveGame(A); A := nil;
    Post(Form, 101, Collector.Samples[2], False, 'removed');
    Form.TestGuiEventQueue.Post(TRunnerFinishedGuiMessage.Create(101));
    Form.TestDrainGuiEvents(True);
    Check(Form.FindGameById(101) = nil, 'late messages cannot recreate removed game');
    B.RequestRemoval;
    Post(Form, B.Id, Collector.Samples[2], True, 'removing');
    Form.TestGuiEventQueue.Post(TRunnerFinishedGuiMessage.Create(B.Id));
    Form.TestDrainGuiEvents(True);
    Check(Form.FindGameById(102) = nil, 'pending snapshots drain before requested removal'); B := nil;
    Check(Freed - Base = 7, 'removed-game payloads freed exactly once');
  finally Form.Free; end;
end;
procedure PostAnalysis(Form: TMainForm; const Search: TGameTreeSearchRef; const Score: string);
var Data: TCountedPv; Board: TDraughtsPosition;
begin
  Data := TCountedPv.Create; Board := TDraughtsPosition.Create;
  try Data.SetDataWithSearch(Board, 0, '32-28', Score, '12', '0.1', Search, True);
  finally Board.Free; end;
  Form.TestGuiEventQueue.Post(TAnalyzerSnapshotGuiMessage.Create(Data));
end;
procedure CheckAnalysisDelivery(const Setup: TGameSetup);
var Form: TMainForm; A, B: TRunningGame; SA, SB: TGameTreeSearchRef;
  ErrorText: string; Barrier: TAnalysisBarrier; Base: Integer;
begin
  Form := TMainForm.Create(nil); Base := PvFreed;
  try
    A := NewGame(Form, 104, Setup); B := NewGame(Form, 105, Setup);
    A.MarkFinished; B.MarkFinished;
    Check(StartAnalysisSearch(A.GameTreeActor, A.GameTree.Root, SA, ErrorText), ErrorText);
    Check(StartAnalysisSearch(B.GameTreeActor, B.GameTree.Root, SB, ErrorText), ErrorText);
    PostAnalysis(Form, SA, 'old'); PostAnalysis(Form, SB, 'B'); PostAnalysis(Form, SA, 'latest');
    Barrier := TAnalysisBarrier.Create('analysis barrier'); Barrier.A := A.GameTree; Barrier.B := B.GameTree;
    Form.TestGuiEventQueue.Post(Barrier);
    Form.TestDrainGuiEvents(True);
    Check(PvFreed - Base = 3, 'superseded and applied analyzer payloads freed once');
    CancelGameTreeSearch(A.GameTreeActor, SA);
    PostAnalysis(Form, SA, 'stale'); Form.TestDrainGuiEvents(True);
    Check(A.GameTree.Root.AnnotatorScore = 'latest', 'late cancelled-search snapshot cannot overwrite accepted analysis');
  finally Form.Free; end;
end;
procedure CheckBudget(Collector: TCollector);
var Form: TMainForm; I, Base: Integer;
begin
  Form := TMainForm.Create(nil); Base := Freed + PvFreed;
  try
    for I := 1 to 205 do
      if Odd(I) then Post(Form, -1, Collector.Samples[2], True, IntToStr(I))
      else PostAnalysis(Form, EmptyGameTreeSearchRef, IntToStr(I));
    Form.TestDrainGuiEvents(False);
    Check((Form.TestGuiEventQueue.Count = 105) and (Freed + PvFreed - Base = 100), 'timer snapshot batches obey the 100-event cap');
    Form.TestDrainGuiEvents(False);
    Check((Form.TestGuiEventQueue.Count = 5) and (Freed + PvFreed - Base = 200), 'second timer tick resumes queued delivery');
    Form.TestDrainGuiEvents(True);
    Check((Form.TestGuiEventQueue.Count = 0) and (Freed + PvFreed - Base = 205), 'shutdown-style drain processes the remainder');
  finally Form.Free; end;
end;
procedure CheckClosing(Collector: TCollector; const Setup: TGameSetup);
var Form: TMainForm; Game: TRunningGame; Base: Integer;
begin
  Form := TMainForm.Create(nil); Base := Freed;
  Game := NewGame(Form, 103, Setup);
  Post(Form, Game.Id, Collector.Samples[2], False, 'closing');
  Form.TestGuiEventQueue.Post(TRunnerFinishedGuiMessage.Create(Game.Id));
  Form.Free;
  Check(Freed - Base = 1, 'form destruction drains pending snapshot and finish before freeing game');
end;
var Collector: TCollector; Setup: TGameSetup; I: Integer;
begin
  RequireDerivedFormResource := False; Application.Initialize;
  Collector := TCollector.Create; Collector.Lock := TCriticalSection.Create;
  Collector.Ready := TEvent.Create(nil, True, False, '');
  Setup := Default(TGameSetup); Setup.StartingFEN := DefaultStartingFEN;
  Setup.TimeControl := DefaultTimeControl; Setup.WhitePlayer := pkHuman; Setup.BlackPlayer := pkHuman;
  try
    GetSamples(Collector, Setup);
    CheckDelivery(Collector, Setup); CheckAnalysisDelivery(Setup); CheckBudget(Collector); CheckClosing(Collector, Setup);
    Writeln('GUI delivery checks passed');
  finally
    for I := 0 to 2 do Collector.Samples[I].Free;
    Collector.Ready.Free; Collector.Lock.Free; Collector.Free;
  end;
end.
