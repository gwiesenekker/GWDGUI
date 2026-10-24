program analyzer_runner_shutdown_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils,
  uAnalyzerRunnerThread, uEngineRegistry;

type
  TRunnerObserver = class
  public
    Finished: Boolean;
    procedure RunnerFinished(Sender: TObject);
  end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    Writeln('FAIL: ', AMessage);
    Halt(1);
  end;
end;

procedure TRunnerObserver.RunnerFinished(Sender: TObject);
begin
  Finished := True;
end;

procedure CheckShutdownAfterRunnerFinished;
var
  Engine: TExternalEngineDefinition;
  Observer: TRunnerObserver;
  Runner: TAnalyzerRunnerThread;
begin
  Engine := TExternalEngineDefinition.Create;
  Observer := TRunnerObserver.Create;
  Runner := nil;
  try
    Engine.Kind := eekHub;
    Engine.HubId := 'Failing test annotator';
    {$IFDEF WINDOWS}
    Engine.ExePath := GetEnvironmentVariable('COMSPEC');
    Engine.Arguments := '/c exit 1';
    {$ELSE}
    Engine.ExePath := '/bin/false';
    {$ENDIF}

    Runner := TAnalyzerRunnerThread.Create(Engine, nil, nil,
      @Observer.RunnerFinished);
    Runner.Start;
    Runner.WaitFor;
    Check(Observer.Finished, 'finished callback should run');

    Runner.PostShutdown;
    FreeAndNil(Runner);
  finally
    Runner.Free;
    Observer.Free;
    Engine.Free;
  end;
end;

begin
  CheckShutdownAfterRunnerFinished;
  Writeln('OK');
end.
