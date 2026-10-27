program runner_early_stop_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, SyncObjs, uGameRunnerThread,
  uAnalyzerRunnerThread, uGameSetupTypes, uGameOrchestrator, uEngineRegistry, uDraughtsBoard, uDraughtsPosition;
type TObserver = class
  Count: Integer;
  procedure Finished(Sender: TObject);
end;
type
  TBlockedObserver = class
    Entered, ReleaseCallback, Exited: TSimpleEvent;
    constructor Create;
    destructor Destroy; override;
    procedure Finished(Sender: TObject);
  end;
  TFreeAnalyzer = class(TThread)
    Runner: TAnalyzerRunnerThread;
    Destroying, Disposed: TSimpleEvent;
    procedure Execute; override;
  end;
constructor TBlockedObserver.Create;
begin
  Entered := TSimpleEvent.Create;
  ReleaseCallback := TSimpleEvent.Create;
  Exited := TSimpleEvent.Create;
end;
destructor TBlockedObserver.Destroy;
begin Entered.Free; ReleaseCallback.Free; Exited.Free; inherited Destroy; end;
procedure TBlockedObserver.Finished(Sender: TObject);
begin
  Entered.SetEvent;
  ReleaseCallback.WaitFor(INFINITE);
  // The thread object must remain alive until this callback returns.
  if TThread(Sender).ThreadID <> GetCurrentThreadID then Halt(1);
  Exited.SetEvent;
end;
procedure TFreeAnalyzer.Execute;
begin
  Destroying.SetEvent;
  Runner.Free;
  Disposed.SetEvent;
end;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then begin WriteLn('FAIL: ', Text); Halt(1); end; end;
procedure TObserver.Finished(Sender: TObject);
begin
  Check(GetCurrentThreadID = TThread(Sender).ThreadID, 'completion remains a worker-thread notification');
  Inc(Count);
end;
procedure CheckDisposalDuringCompletion;
var Observer: TBlockedObserver; Definition: TExternalEngineDefinition;
  Disposer: TFreeAnalyzer; Runner: TAnalyzerRunnerThread;
begin
  Observer := TBlockedObserver.Create; Definition := TExternalEngineDefinition.Create;
  Disposer := TFreeAnalyzer.Create(True);
  Disposer.Destroying := TSimpleEvent.Create;
  Disposer.Disposed := TSimpleEvent.Create;
  try
    Runner := TAnalyzerRunnerThread.Create(Definition, nil, nil, @Observer.Finished);
    Runner.PostShutdown; Runner.Start;
    Check(Observer.Entered.WaitFor(3000) = wrSignaled, 'completion callback entered');
    Disposer.Runner := Runner; Disposer.Start;
    Check(Disposer.Destroying.WaitFor(3000) = wrSignaled, 'disposal starts during completion');
    Check(Disposer.Disposed.WaitFor(100) = wrTimeout, 'disposal must wait for the active completion callback');
    Observer.ReleaseCallback.SetEvent;
    Check(Disposer.Disposed.WaitFor(3000) = wrSignaled, 'disposal finishes after completion returns');
    Disposer.WaitFor;
    Check(Observer.Exited.WaitFor(0) = wrSignaled, 'callback finished before resources were freed');
  finally
    Observer.ReleaseCallback.SetEvent;
    Disposer.WaitFor; Disposer.Destroying.Free; Disposer.Disposed.Free; Disposer.Free;
    Definition.Free; Observer.Free;
  end;
end;
var Setup: TGameSetup; Observer: TObserver; Runner: TGameRunnerThread;
  Analyzer: TAnalyzerRunnerThread; Definition: TExternalEngineDefinition; I, Mode: Integer;
begin
  CheckDisposalDuringCompletion;
  Observer := TObserver.Create; Definition := TExternalEngineDefinition.Create;
  Setup := Default(TGameSetup); Setup.StartingFEN := DefaultStartingFEN;
  Setup.TimeControl := DefaultTimeControl; Setup.WhitePlayer := pkHuman; Setup.BlackPlayer := pkHuman;
  try
    for Mode := 0 to 1 do
      for I := 1 to 30 do
      begin
        Observer.Count := 0;
        Runner := TGameRunnerThread.Create(Setup, I, nil, @Observer.Finished);
        if Mode = 0 then Runner.PostStop;
        Runner.Start; Runner.PostStop; Runner.WaitFor;
        Check(Runner.Finished, 'game thread really terminates');
        Check(Observer.Count = 1, 'early-stopped game publishes completion exactly once');
        Runner.Free;
        Check(Observer.Count = 1, 'game disposal cannot publish a duplicate completion');
        Observer.Count := 0;
        Analyzer := TAnalyzerRunnerThread.Create(Definition, nil, nil, @Observer.Finished);
        if Mode = 0 then Analyzer.PostShutdown;
        Analyzer.Start; Analyzer.PostShutdown; Analyzer.WaitFor;
        Check(Analyzer.Finished, 'analyzer thread really terminates');
        Check(Observer.Count = 1, 'early-stopped analyzer publishes completion exactly once');
        Analyzer.Free;
        Check(Observer.Count = 1, 'analyzer disposal cannot publish duplicate completion');
      end;
  finally Observer.Free; Definition.Free; end;
  WriteLn('Early runner stop checks passed');
end.
