program hub_search_fence_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, uHubEngine, uEngineBase, uEngineRegistry, uDraughtsBoard;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AMessage);
    Halt(1);
  end;
end;

procedure FakeHub(ANeverStop: Boolean);
var
  Line, Move: string;
  Searching: Boolean;
begin
  Move := '32-28';
  Searching := False;
  while not EOF(Input) do
  begin
    ReadLn(Line);
    if Line = 'hub' then
    begin
      WriteLn('id name=SlowHub version=1');
      WriteLn('wait');
    end
    else if Line = 'init' then
      WriteLn('ready')
    else if Pos('pos ', Line) = 1 then
    begin
      if Pos('32-28', Line) > 0 then
        Move := '19-23'
      else
        Move := '32-28';
    end
    else if Line = 'go analyze' then
      Searching := True
    else if (Line = 'stop') and Searching then
    begin
      if not ANeverStop then
      begin
        Sleep(2300);
        Searching := False;
        WriteLn('done move=' + Move);
      end;
    end
    else if Line = 'go think' then
      WriteLn('done move=' + Move)
    else if Line = 'quit' then
      Break;
    Flush(Output);
  end;
end;

function CreateEngine(const AMode: string): THubEngine;
var
  Definition: TExternalEngineDefinition;
begin
  Definition := TExternalEngineDefinition.Create;
  try
    Definition.Kind := eekHub;
    Definition.HubId := 'SlowHub';
    Definition.ExePath := ExpandFileName(ParamStr(0));
    Definition.Arguments := AMode;
    Result := THubEngine.Create(Definition);
  finally
    Definition.Free;
  end;
end;

procedure CheckSlowStop;
var
  Engine: THubEngine;
  Moves: TStringList;
  Tick: QWord;
begin
  Engine := CreateEngine('--slow-hub');
  Moves := TStringList.Create;
  try
    Check(Engine.LaunchAndInit, 'fake engine should initialize');
    Engine.SetGamePosition(DefaultStartingFEN, Moves);
    Engine.StartAnalyzing;
    Tick := GetTickCount64;
    Engine.StopSearch;
    Check(GetTickCount64 - Tick >= 2200,
      'stop must wait for acknowledgement, even after the old two-second timeout');
    Moves.Add('32-28');
    Engine.SetGamePosition(DefaultStartingFEN, Moves);
    Check(Engine.StartThinking = '19-23',
      'the next search must return its own move, not the stopped search answer');
  finally
    Moves.Free;
    Engine.Free;
  end;
end;

procedure CheckMissingStop;
var
  Engine: THubEngine;
  Moves: TStringList;
  Raised: Boolean;
  I: Integer;
begin
  Engine := CreateEngine('--never-stop-hub');
  Moves := TStringList.Create;
  try
    Check(Engine.LaunchAndInit, 'unresponsive fake engine should initialize');
    Engine.SetGamePosition(DefaultStartingFEN, Moves);
    Engine.StartAnalyzing;
    Raised := False;
    try
      Engine.StopSearch;
    except
      on E: EInvalidOperation do
        Raised := True;
    end;
    Check(Raised, 'missing stop acknowledgement must fail explicitly');
    Check(Engine.CurrentState = esError,
      'failed stop must not report the engine ready');
    Moves.Add('32-28');
    for I := 0 to 3 do
    begin
      Raised := False;
      try
        case I of
          0: Engine.SetGamePosition(DefaultStartingFEN, Moves);
          1: Engine.StartAnalyzing;
          2: Engine.StartMcts;
          3: Engine.StartThinking;
        end;
      except
        on E: EInvalidOperation do
          Raised := True;
      end;
      Check(Raised, 'an unsynchronized engine must reject new positions and searches');
      Check(Engine.CurrentState = esError,
        'rejected reuse must leave the engine in error');
    end;
  finally
    Moves.Free;
    Engine.Free;
  end;
end;

begin
  if (ParamStr(1) = '--slow-hub') or (ParamStr(1) = '--never-stop-hub') then
  begin
    FakeHub(ParamStr(1) = '--never-stop-hub');
    Halt(0);
  end;
  CheckSlowStop;
  CheckMissingStop;
  WriteLn('OK');
end.
