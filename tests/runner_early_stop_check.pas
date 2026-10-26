program runner_early_stop_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, uGameRunnerThread,
  uAnalyzerRunnerThread, uGameSetupTypes, uGameOrchestrator, uEngineRegistry, uDraughtsBoard;
type TObserver = class
  Count: Integer;
  procedure Finished(Sender: TObject);
end;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then begin WriteLn('FAIL: ', Text); Halt(1); end; end;
procedure TObserver.Finished(Sender: TObject);
begin
  Check(GetCurrentThreadID = TThread(Sender).ThreadID, 'completion remains a worker-thread notification');
  Inc(Count);
end;
var Setup: TGameSetup; Observer: TObserver; Runner: TGameRunnerThread;
  Analyzer: TAnalyzerRunnerThread; Definition: TExternalEngineDefinition; I, Mode: Integer;
begin
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
