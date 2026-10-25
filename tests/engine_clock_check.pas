program engine_clock_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uEngineBase, uEngineParamsJson, uHubEngine, uEngineRegistry,
  uDraughtsBoard, uGameMoveHistory, uGameOrchestrator;

type
  TClockProbe = class(TDraughtsEngine)
    Used: Double;
    Calls: Integer;
    function DoStartThinking: string; override;
    procedure SetClockInfo(Moves: Integer; Remaining, TotalUsed: Double); override;
  end;
function TClockProbe.DoStartThinking: string;
begin Result := ''; end;
procedure TClockProbe.SetClockInfo(Moves: Integer; Remaining, TotalUsed: Double);
begin Used := TotalUsed; Inc(Calls); end;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure CheckTypedClockCompatibility;
var Engine: TClockProbe;
begin
  Engine := TClockProbe.Create;
  try
    Engine.SetClockInfoWithIncrement(0, 90, 17, 2);
    Check((Engine.Used = 17) and (Engine.Calls = 1),
      'extended clock configuration must preserve used time for non-Hub adapters');
  finally Engine.Free; end;
end;

procedure FakeHub(const Mode: string);
var
  Line, MoveText: string;
  Recovered: Boolean;
begin
  Recovered := False;
  MoveText := '32-28';
  while not EOF(Input) do
  begin
    ReadLn(Line);
    if Line = 'hub' then
    begin
      WriteLn('id name=ClockHub');
      WriteLn('wait');
    end
    else if Line = 'init' then
    begin
      if Mode = '--slow-start-hub' then Sleep(5200);
      WriteLn('ready');
    end
    else if Pos('pos ', Line) = 1 then
    begin
      if Pos('18-23', Line) > 0 then
        MoveText := '37-32'
      else
        MoveText := '32-28';
    end
    else if Line = 'go think' then
    begin
      if Mode = '--long-hub' then
        Sleep(61000)
      else if Mode = '--delayed-hub' then
        Sleep(180);
      if Mode = '--history-hub' then
        WriteLn('info depth=17 time=0.12 score=0.42 pv="' + MoveText + '"');
      if (Mode <> '--silent-hub') and
        ((Mode <> '--recovering-hub') or Recovered) then
        WriteLn('done move=' + MoveText);
    end
    else if Line = 'stop' then
    begin
      Recovered := True;
      WriteLn('done move=' + MoveText);
    end
    else if Line = 'quit' then
      Exit;
    Flush(Output);
  end;
end;

function CreateEngine(const Mode: string): THubEngine;
var
  Definition: TExternalEngineDefinition;
begin
  Definition := TExternalEngineDefinition.Create;
  try
    Definition.Kind := eekHub;
    Definition.HubId := 'ClockHub';
    Definition.ExePath := ExpandFileName(ParamStr(0));
    Definition.Arguments := Mode;
    Result := THubEngine.Create(Definition);
  finally
    Definition.Free;
  end;
end;

procedure CheckHubLevel;
var Game: TGameOrchestrator; Engine: THubEngine; Clock: TTimeControl; Text: string;
begin
  Game := TGameOrchestrator.Create;
  try
    Engine := CreateEngine('--fast-hub');
    Game.Engine[dsWhite] := Engine;
    Check(Engine.LaunchAndInit, 'level fixture launch');
    Clock := DefaultTimeControl;
    Clock.MovesPerPeriod := 0;
    Clock.IncrementSeconds := 0.6;
    Game.TimeControl := Clock;
    Game.NewGame(DefaultStartingFEN);
    Game.PlayNextMove;
    Text := Engine.StateLog.Text;
    Check(Pos('message=level time=', Text) > 0, 'sudden-death level must omit moves');
    Check(Pos('inc=0.600', Text) > 0, 'Hub level must receive the active increment');
    Check(Pos('message=level moves=0', Text) = 0, 'Hub must never receive moves=0');
  finally Game.Free; end;
end;

procedure CheckStartupTimeout;
var Engine: THubEngine; Params: TEngineParamArray;
begin
  Params := nil;
  Check(EngineStartupTimeoutMs(Params) = 60000, 'cold engine startup default');
  AddOrUpdateParam(Params, 'gui-startup-timeout-ms', 'string', '7000', False);
  Check(EngineStartupTimeoutMs(Params) = 7000, 'per-engine startup override');
  Engine := CreateEngine('--slow-start-hub');
  try Check(Engine.LaunchAndInit, 'cold engine initialization must tolerate more than five seconds');
  finally Engine.Free; end;
end;

procedure CheckClockedThink(const Mode: string; Side: TDraughtsSide;
  Minutes, Increment: Double; ExpectedTimeout: Boolean);
var
  Game: TGameOrchestrator;
  Engine: THubEngine;
  Clock: TTimeControl;
  Fen, MoveText: string;
  Tick: QWord;
begin
  Game := TGameOrchestrator.Create;
  try
    Engine := CreateEngine(Mode);
    Game.Engine[Side] := Engine;
    Check(Engine.LaunchAndInit, 'clock fake Hub should initialize');
    Clock := DefaultTimeControl;
    Clock.MinutesPerPeriod := Minutes;
    Clock.IncrementSeconds := Increment;
    Clock.IncrementMode := cimFromStart;
    Game.TimeControl := Clock;
    Fen := DefaultStartingFEN;
    if Side = dsBlack then
      Fen[1] := 'B';
    Game.NewGame(Fen);
    Tick := GetTickCount64;
    MoveText := Game.PlayNextMove;
    if ExpectedTimeout then
    begin
      Check(GetTickCount64 - Tick < 2000, 'short clock must not wait sixty seconds');
      Check(Engine.MoveTimedOut, 'expired adapter deadline must be reported');
      Check((Game.State = gosGameOver) and (Game.MoveHistory.Count = 0),
        'a timed-out search must finish without accepting a move');
      if Side = dsWhite then
        Check(Game.GameResult = '0-2', 'White timeout must be a loss')
      else
        Check(Game.GameResult = '2-0', 'Black timeout must be a loss');
      Check((Game.RemainingSeconds[Side] = 0) and
        (Game.UsedSeconds[Side] > 0), 'flag fall must record clock usage');
      Check(Pos('send; message=stop', Engine.StateLog.Text) > 0,
        'Hub timeout must stop and fence the search');
      Check(Game.LastError = '', 'a clock loss must not become a runner error');
    end
    else
    begin
      Check((MoveText <> '') and (Game.MoveHistory.Count = 1),
        'a move within its clock budget must be accepted');
      Check(not Engine.MoveTimedOut, 'successful search must not be marked timed out');
      if Minutes >= 2 then
        Check(Engine.MoveTimeLimitMs > 60000,
          'long clock must configure a deadline beyond sixty seconds');
      if Mode = '--long-hub' then
        Check(GetTickCount64 - Tick >= 60000,
          'long-search regression must cross the previous fixed deadline');
    end;
  finally
    Game.Free;
  end;
end;

procedure CheckIncrementAfterMoveLimit;
var
  Game: TGameOrchestrator;
  Engine: THubEngine;
  Clock: TTimeControl;
begin
  Game := TGameOrchestrator.Create;
  try
    Engine := CreateEngine('--fast-hub');
    Game.Engine[dsWhite] := Engine;
    Check(Engine.LaunchAndInit, 'increment fake Hub should initialize');
    Clock := DefaultTimeControl;
    Clock.MinutesPerPeriod := 0.01;
    Clock.MovesPerPeriod := 2;
    Clock.IncrementSeconds := 10;
    Clock.IncrementMode := cimAfterMoveLimit;
    Game.TimeControl := Clock;
    Game.NewGame(DefaultStartingFEN);
    Check(Game.PlayNextMove <> '', 'first White move');
    Check(Engine.MoveTimeLimitMs < 1000,
      'increment must not enter deadline before the configured move limit');
    Game.PlayMove('18-23', dsBlack, 0, 'human');
    Check(Game.PlayNextMove <> '', 'second White move');
    Check(Engine.MoveTimeLimitMs > 10000,
      'increment must enter deadline when it becomes applicable');
  finally
    Game.Free;
  end;
end;

procedure CheckCompleteEngineHistory;
var
  Game: TGameOrchestrator;
  Engine: THubEngine;
  Moves: TGameMoveDataArray;
begin
  Game := TGameOrchestrator.Create;
  try
    Engine := CreateEngine('--history-hub');
    Game.Engine[dsWhite] := Engine;
    Check(Engine.LaunchAndInit, 'history engine must initialize');
    Game.NewGame(DefaultStartingFEN);
    Check(Game.PlayNextMove = '32-28', 'first engine history move');
    Game.PlayMove('18-23', dsBlack, 0.25, 'human');
    Check(Game.PlayNextMove = '37-32', 'second engine history move');
    Moves := Game.MoveHistory.ExportData;
    Check((Length(Moves) = 3) and (Moves[0].PrincipalVariation = '32-28') and
      (Moves[2].PrincipalVariation = '37-32'), 'each engine PV must survive later searches');
    Check((Moves[0].PvScore = '0.42') and (Moves[0].PvDepth = '17') and
      (Moves[0].PvTimeText <> '') and (Moves[2].PvDepth = '17'),
      'all completed moves must retain score, depth and analysis time');
    Check(Moves[0].HasClockInfo and Moves[1].HasClockInfo and Moves[2].HasClockInfo,
      'all engine and human moves must carry clocks');
    Check((Moves[1].SecondsUsed = 0.25) and (Moves[1].BlackUsedSeconds = 0.25) and
      (Moves[2].BlackUsedSeconds = 0.25) and
      (Moves[2].WhiteUsedSeconds >= Moves[0].WhiteUsedSeconds),
      'move times and both post-move clocks must be preserved independently');
    Check((Moves[1].PrincipalVariation = '') and (Moves[1].PvScore = ''),
      'human moves must not inherit a prior engine search');
  finally
    Game.Free;
  end;
end;

procedure CheckPeriodBoundary;
var
  Game: TGameOrchestrator;
  Clock: TTimeControl;
  Side: TDraughtsSide;
  Used, SourceIndex: Integer;
  Fen, FirstMove, Reply, LastMove, Source, BeforeMove: string;
begin
  for Side := Low(TDraughtsSide) to High(TDraughtsSide) do
    for SourceIndex := 0 to 1 do
      for Used := 49 to 51 do
      begin
        Game := TGameOrchestrator.Create;
        try
          Clock := DefaultTimeControl;
          Clock.MinutesPerPeriod := 1;
          Clock.MovesPerPeriod := 2;
          Clock.IncrementSeconds := 0;
          Game.TimeControl := Clock;
          Fen := DefaultStartingFEN;
          if Side = dsWhite then
          begin
            FirstMove := '32-28'; Reply := '18-23'; LastMove := '37-32';
          end
          else
          begin
            Fen[1] := 'B';
            FirstMove := '18-23'; Reply := '32-28'; LastMove := '23x32';
          end;
          if SourceIndex = 0 then Source := 'human' else Source := 'engine';
          Game.NewGame(Fen);
          Game.PlayMove(FirstMove, Side, 10, Source);
          Game.PlayMove(Reply, Game.Board.SideToMove, 0, 'human');
          BeforeMove := Game.Board.CurrentFEN;
          Game.PlayMove(LastMove, Side, Used, Source);
          if Used >= 50 then
          begin
            Check(Game.State = gosGameOver, 'period time must not rescue an exhausted clock');
            if Side = dsWhite then
              Check(Game.GameResult = '0-2', 'White loses on period-boundary flag')
            else
              Check(Game.GameResult = '2-0', 'Black loses on period-boundary flag');
            Check((Game.Board.CurrentFEN = BeforeMove) and (Game.MovesPlayed.Count = 2),
              'flagged boundary move must not enter the board or history');
            Check(Game.RemainingSeconds[Side] <= 0, 'flagged side must not receive next period');
          end
          else
          begin
            Check((Game.State = gosRunning) and (Game.MovesPlayed.Count = 3),
              'in-time boundary move must be accepted');
            Check(Abs(Game.RemainingSeconds[Side] - 61) < 0.001,
              'in-time boundary move must earn the next period allowance');
          end;
        finally
          Game.Free;
        end;
      end;
end;

procedure CheckReuseAfterClockTimeout;
var
  Game: TGameOrchestrator;
  Engine: THubEngine;
  Clock: TTimeControl;
begin
  Game := TGameOrchestrator.Create;
  try
    Engine := CreateEngine('--recovering-hub');
    Game.Engine[dsWhite] := Engine;
    Check(Engine.LaunchAndInit, 'recovering fake Hub should initialize');
    Clock := DefaultTimeControl;
    Clock.MinutesPerPeriod := 0.002;
    Game.TimeControl := Clock;
    Game.NewGame(DefaultStartingFEN);
    Check(Game.PlayNextMove = '', 'first search must reach its deadline');
    Check(Engine.MoveTimedOut, 'first game must report timeout');
    Clock.MinutesPerPeriod := 1;
    Game.TimeControl := Clock;
    Game.NewGame(DefaultStartingFEN);
    Check(Game.PlayNextMove = '32-28',
      'an acknowledged stopped search must not leak into the next game');
    Check((not Engine.MoveTimedOut) and (Game.State = gosRunning),
      'a new successful search must clear the preceding timeout status');
  finally
    Game.Free;
  end;
end;

begin
  if Pos('-hub', ParamStr(1)) > 0 then
  begin
    FakeHub(ParamStr(1));
    Halt(0);
  end;
  if ParamStr(1) = '--long-check' then
    CheckClockedThink('--long-hub', dsWhite, 2, 0, False)
  else
  begin
    CheckStartupTimeout;
    CheckTypedClockCompatibility;
    CheckHubLevel;
    CheckClockedThink('--silent-hub', dsWhite, 0.002, 0, True);
    CheckClockedThink('--silent-hub', dsBlack, 0.002, 0, True);
    CheckClockedThink('--fast-hub', dsWhite, 2, 0, False);
    CheckClockedThink('--delayed-hub', dsWhite, 0.002, 0.2, False);
    CheckIncrementAfterMoveLimit;
    CheckPeriodBoundary;
    CheckCompleteEngineHistory;
    CheckReuseAfterClockTimeout;
  end;
  WriteLn('OK');
end.
