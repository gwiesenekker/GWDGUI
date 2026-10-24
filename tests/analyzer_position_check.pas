program analyzer_position_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, SyncObjs, uAnalyzerRunnerThread, uEngineRegistry,
  uDraughtsBoard, uPvSnapshot, uGameTreeSearchRef;

type
  TObserver = class
    Lock: TCriticalSection;
    Seen: array[1..4] of TEvent;
    Errors: TStringList;
    constructor Create;
    destructor Destroy; override;
    procedure Snapshot(Sender: TObject; AData: TPvSnapshot);
    procedure Move(Sender: TObject; const ASearch: TGameTreeSearchRef;
      const AMove: string);
  end;

procedure FakeHub;
var
  Line, PV, Score: string;
  Searching: Boolean;
begin
  Searching := False;
  while not EOF(Input) do
  begin
    ReadLn(Line);
    if Line = 'hub' then
    begin
      WriteLn('id name=RegressionHub version=1');
      WriteLn('wait');
    end
    else if Line = 'init' then
      WriteLn('ready')
    else if Pos('pos ', Line) = 1 then
    begin
      if Pos('32-28', Line) > 0 then
      begin
        PV := '19-23 28x19';
        Score := '-0.50';
      end
      else
      begin
        PV := '32-28 19-23';
        Score := '0.25';
      end;
    end
    else if (Line = 'go analyze') or (Line = 'go mcts') then
    begin
      Searching := True;
      WriteLn('info depth=9 time=1 score=' + Score + ' pv="' + PV + '"');
    end
    else if Line = 'go think' then
    begin
      WriteLn('info depth=9 time=1 score=' + Score + ' pv="' + PV + '"');
      WriteLn('done move=' + Copy(PV, 1, Pos(' ', PV) - 1));
    end
    else if (Line = 'stop') and Searching then
    begin
      Searching := False;
      WriteLn('info depth=10 time=2 score=' + Score + ' pv="' + PV + '"');
      WriteLn('done move=' + Copy(PV, 1, Pos(' ', PV) - 1));
    end
    else if Line = 'quit' then
      Break;
    Flush(Output);
  end;
end;

constructor TObserver.Create;
var
  I: Integer;
begin
  inherited Create;
  Lock := TCriticalSection.Create;
  Errors := TStringList.Create;
  for I := Low(Seen) to High(Seen) do
    Seen[I] := TEvent.Create(nil, True, False, '');
end;

destructor TObserver.Destroy;
var
  I: Integer;
begin
  for I := Low(Seen) to High(Seen) do
    Seen[I].Free;
  Errors.Free;
  Lock.Free;
  inherited Destroy;
end;

procedure TObserver.Snapshot(Sender: TObject; AData: TPvSnapshot);
var
  Id: Integer;
  PV, FirstMove: string;
begin
  Lock.Acquire;
  try
    Id := AData.SearchId;
    PV := AData.PrincipalVariation;
    if Id = 3 then
    begin
      if (PV <> '') or (AData.Score <> '') or (AData.Depth <> '') or
        (AData.TimeText <> '') then
        Errors.Add('terminal position inherited analysis from the previous search');
      Seen[3].SetEvent;
    end
    else if (Id in [1, 2, 4]) and (PV <> '') then
    begin
      FirstMove := Copy(PV, 1, Pos(' ', PV + ' ') - 1);
      if not AData.BaseBoard.IsLegalMove(FirstMove) then
        Errors.Add('illegal PV attached to search ' + IntToStr(Id));
      if (AData.NodeId <> Id) or (AData.GameTreeId <> 1) then
        Errors.Add('snapshot search reference changed');
      if Id in [1, 4] then
      begin
        if (PV <> '32-28 19-23') or (AData.BaseBoard.SideToMove <> dsWhite) then
          Errors.Add('wrong analysis for the initial position');
        if Id = 1 then
          Seen[1].SetEvent;
      end
      else
      begin
        if (PV <> '19-23 28x19') or (AData.BaseBoard.SideToMove <> dsBlack) then
          Errors.Add('old analysis attached to the browsed position');
        if Id = 2 then
          Seen[2].SetEvent;
      end;
    end;
  finally
    AData.Free;
    Lock.Release;
  end;
end;

procedure TObserver.Move(Sender: TObject; const ASearch: TGameTreeSearchRef;
  const AMove: string);
begin
  Lock.Acquire;
  try
    if (ASearch.SearchId <> 4) or (AMove <> '32-28') then
      Errors.Add('wrong move or search reference from one-shot search');
    Seen[4].SetEvent;
  finally
    Lock.Release;
  end;
end;

procedure CheckPositionSwitches(AMode: TAnalyzerRunMode);
var
  Definition: TExternalEngineDefinition;
  Observer: TObserver;
  Runner: TAnalyzerRunnerThread;
  A, B: TDraughtsBoard;
  I: Integer;
  Received: array[1..4] of Boolean;
begin
  Definition := TExternalEngineDefinition.Create;
  Observer := TObserver.Create;
  A := TDraughtsBoard.Create;
  B := TDraughtsBoard.Create;
  Runner := nil;
  try
    Definition.Kind := eekHub;
    Definition.HubId := 'RegressionHub';
    Definition.ExePath := ExpandFileName(ParamStr(0));
    Definition.Arguments := '--fake-hub';
    B.PlayMove('32-28');
    Runner := TAnalyzerRunnerThread.Create(Definition, nil,
      @Observer.Snapshot, nil, AMode, @Observer.Move);
    Runner.Start;
    Runner.PostAnalyze(DefaultStartingFEN, '', A, 0, False,
      GameTreeSearchRef(1, 1, 1));
    Received[1] := Observer.Seen[1].WaitFor(5000) = wrSignaled;
    Runner.PostAnalyze(DefaultStartingFEN, '32-28', B, 1, False,
      GameTreeSearchRef(1, 2, 2));
    Received[2] := Observer.Seen[2].WaitFor(5000) = wrSignaled;
    Runner.PostThinkOnce(DefaultStartingFEN, '', A, 0, 1,
      GameTreeSearchRef(1, 4, 4));
    Received[4] := Observer.Seen[4].WaitFor(5000) = wrSignaled;
    Runner.PostAnalyze(DefaultStartingFEN, '', A, 0, True,
      GameTreeSearchRef(1, 3, 3));
    Received[3] := Observer.Seen[3].WaitFor(5000) = wrSignaled;
    Runner.PostShutdown;
    Runner.WaitFor;
    for I := Low(Received) to High(Received) do
      if not Received[I] then
        Observer.Errors.Add('search did not respond: ' + IntToStr(I));
    for I := 0 to Observer.Errors.Count - 1 do
      WriteLn('FAIL: ', Observer.Errors[I]);
    if Observer.Errors.Count <> 0 then
      Halt(1);
  finally
    Runner.Free;
    B.Free;
    A.Free;
    Observer.Free;
    Definition.Free;
  end;
end;

begin
  if ParamStr(1) = '--fake-hub' then
  begin
    FakeHub;
    Halt(0);
  end;
  CheckPositionSwitches(armAnalyze);
  CheckPositionSwitches(armMcts);
  WriteLn('OK');
end.
