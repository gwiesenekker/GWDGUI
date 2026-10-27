program analyzer_runner_shutdown_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, SyncObjs, uDraughtsBoard, uGameTreeSearchRef,
  uAnalyzerRunnerThread, uEngineRegistry, uDraughtsPosition;

type
  TRunnerObserver = class
  public
    Finished: Boolean;
    StopOnOpening: Boolean;
    Runner: TAnalyzerRunnerThread;
    Searching, Stopping, Failed: TEvent;
    constructor Create;
    destructor Destroy; override;
    procedure Log(Sender: TObject; const MessageText: string);
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

constructor TRunnerObserver.Create;
begin
  inherited Create;
  Searching := TEvent.Create(nil, True, False, '');
  Stopping := TEvent.Create(nil, True, False, '');
  Failed := TEvent.Create(nil, True, False, '');
end;

destructor TRunnerObserver.Destroy;
begin
  Failed.Free;
  Stopping.Free;
  Searching.Free;
  inherited Destroy;
end;

procedure TRunnerObserver.Log(Sender: TObject; const MessageText: string);
begin
  if StopOnOpening and (Pos('Opening ', MessageText) = 1) then
  begin
    StopOnOpening := False;
    Runner.PostShutdown;
  end;
  if Pos('message=go analyze', MessageText) > 0 then Searching.SetEvent;
  if Pos('stop sent; waiting for done', MessageText) > 0 then Stopping.SetEvent;
  if Pos('Annotator failed:', MessageText) > 0 then Failed.SetEvent;
end;

procedure FakeUnresponsiveHub;
var
  Line: string;
begin
  while not EOF(Input) do
  begin
    ReadLn(Line);
    if (ParamStr(1) = '--silent-launch-hub') and (Line <> 'quit') then Continue;
    if Line = 'hub' then WriteLn('wait')
    else if Line = 'init' then WriteLn('ready')
    else if Line = 'quit' then Exit;
    // Deliberately ignore both search and stop: no done fence ever arrives.
    Flush(Output);
  end;
end;

procedure CheckUnresponsiveSearch(ShutdownDuringStop: Boolean);
var
  Engine: TExternalEngineDefinition;
  Observer: TRunnerObserver;
  Runner: TAnalyzerRunnerThread;
  Board: TDraughtsPosition;
  Search: TGameTreeSearchRef;
  Tick: QWord;
begin
  Engine := TExternalEngineDefinition.Create;
  Observer := TRunnerObserver.Create;
  Board := TDraughtsPosition.Create;
  Runner := nil;
  try
    Engine.Kind := eekHub;
    Engine.ExePath := ExpandFileName(ParamStr(0));
    Engine.Arguments := '--unresponsive-hub';
    Runner := TAnalyzerRunnerThread.Create(Engine, @Observer.Log, nil,
      @Observer.RunnerFinished);
    Runner.Start;
    Board.LoadFromFEN(DefaultStartingFEN);
    Search := Default(TGameTreeSearchRef);
    Runner.PostAnalyze(DefaultStartingFEN, '', Board, 0, False, Search);
    Check(Observer.Searching.WaitFor(5000) = wrSignaled, 'fake annotator must start searching');
    Runner.PostAnalyze(DefaultStartingFEN, '', Board, 0, False, Search);
    Check(Observer.Stopping.WaitFor(5000) = wrSignaled, 'second position must wait for the stop fence');
    if ShutdownDuringStop then
    begin
      Tick := GetTickCount64;
      FreeAndNil(Runner);
      Check(GetTickCount64 - Tick < 2500, 'shutdown must interrupt the ten-second stop fence');
      Check(Observer.Finished, 'interrupted annotator must deliver finished callback');
    end
    else
    begin
      Check(Observer.Failed.WaitFor(13000) = wrSignaled, 'stop failure must be reported with an error log');
      Runner.WaitFor;
      Check(Observer.Finished, 'failed annotator must deliver finished callback');
      Check(Runner.FatalException = nil, 'command exceptions must be handled by the runner');
    end;
  finally
    Runner.Free;
    Board.Free;
    Observer.Free;
    Engine.Free;
  end;
end;

procedure CheckShutdownAtLaunch;
var Engine: TExternalEngineDefinition; Observer: TRunnerObserver;
  Runner: TAnalyzerRunnerThread; Tick: QWord;
begin
  Engine := TExternalEngineDefinition.Create;
  Observer := TRunnerObserver.Create;
  Runner := nil;
  try
    Engine.Kind := eekHub;
    Engine.ExePath := ExpandFileName(ParamStr(0));
    Engine.Arguments := '--silent-launch-hub';
    Observer.StopOnOpening := True;
    Runner := TAnalyzerRunnerThread.Create(Engine, @Observer.Log, nil, @Observer.RunnerFinished);
    Observer.Runner := Runner;
    Tick := GetTickCount64;
    Runner.Start;
    Runner.WaitFor;
    Check(GetTickCount64 - Tick < 2500, 'shutdown before launch must not be erased by initialization');
  finally Runner.Free; Observer.Free; Engine.Free; end;
end;

procedure CheckImmediateShutdown;
var
  Engine: TExternalEngineDefinition;
  Runner: TAnalyzerRunnerThread;
  I: Integer;
begin
  Engine := TExternalEngineDefinition.Create;
  try
    Engine.Kind := eekHub;
    Engine.ExePath := ExpandFileName(ParamStr(0));
    Engine.Arguments := '--unresponsive-hub';
    for I := 1 to 20 do
    begin
      Runner := TAnalyzerRunnerThread.Create(Engine, nil, nil, nil);
      Runner.Start;
      Runner.PostShutdown;
      Runner.Free;
    end;
  finally
    Engine.Free;
  end;
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
  if (ParamStr(1) = '--unresponsive-hub') or (ParamStr(1) = '--silent-launch-hub') then
  begin
    FakeUnresponsiveHub;
    Halt(0);
  end;
  CheckShutdownAtLaunch;
  CheckShutdownAfterRunnerFinished;
  CheckImmediateShutdown;
  CheckUnresponsiveSearch(True);
  CheckUnresponsiveSearch(False);
  Writeln('OK');
end.
