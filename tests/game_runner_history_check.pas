program game_runner_history_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, uDraughtsBoard, uGameOrchestrator, uGameMoveHistory,
  uGameTree, uGameTreeActor, uGameTreeBuilder, uGameTreePdn;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

procedure Execute(Actor: TGameTreeActor; Command: TGameTreeCommand);
begin
  try
    Actor.ExecuteCommand(Command);
    Check(Command.Accepted, Command.ErrorText);
  finally
    Command.Free;
  end;
end;

var
  Actor, Appended: TGameTreeActor;
  Moves: TStringList;
  Header: TGameTreeHeaderInput;
  Mainline: TGameTreeMainlineInput;
  Data: TGameMoveDataArray;
  Command: TGameTreeCommand;
  I: Integer;
  Text: string;

procedure CheckHistory(Tree: TGameTree);
begin
  Check(Tree.MainlineCount = 3, 'all batched moves must exist');
  Check((Tree.Root.EnginePV = '32-28 18-23') and
    (Tree.Root.EngineScore = '0.42') and (Tree.Root.EnginePVDepth = '17') and
    (Tree.Root.EnginePVTimeText = '0.12'), 'first engine search belongs to root');
  Check(Tree.MainlineNode[1].EnginePV = '', 'human move must not inherit engine analysis');
  Check(Tree.MainlineNode[2].EnginePV = '37-32 12-18', 'later engine search belongs to its parent');
  for I := 1 to 3 do
  begin
    Check(Tree.MainlineNode[I].HasClockInfo and Tree.MainlineNode[I].HasMoveTime,
      'every completed move must own clock and time fields');
    Check(Tree.MainlineNode[I].SecondsUsed = I, 'every move must retain its own time');
    Check(Tree.MainlineNode[I].WhiteRemainingSeconds = 300 - I,
      'every move must retain its own post-move clock');
  end;
end;

begin
  Actor := TGameTreeActor.Create;
  Appended := TGameTreeActor.Create;
  Moves := TStringList.Create;
  try
    Moves.Add('32-28'); Moves.Add('18-23'); Moves.Add('37-32');
    SetLength(Data, 3);
    for I := 0 to 2 do
    begin
      Data[I].MoveText := Moves[I];
      Data[I].SecondsUsed := I + 1;
      Data[I].HasClockInfo := True;
      Data[I].WhiteRemainingSeconds := 299 - I;
      Data[I].BlackRemainingSeconds := 298 - I;
      Data[I].WhiteUsedSeconds := I + 1;
      Data[I].BlackUsedSeconds := I;
    end;
    Data[0].PrincipalVariation := '32-28 18-23';
    Data[0].PvScore := '0.42'; Data[0].PvDepth := '17'; Data[0].PvTimeText := '0.12';
    Data[2].PrincipalVariation := '37-32 12-18';
    Data[2].PvScore := '0.56'; Data[2].PvDepth := '19';
    Header := GameTreeHeaderInput('history', 'History', 'White', 'Black', '*',
      DefaultStartingFEN, True, DefaultTimeControl, gosRunning);
    Mainline := GameTreeMainlineInput(Moves, nil, True, 250, 249, 50, 51);
    Mainline.MoveData := Copy(Data);
    Command := Actor.CreateRebuildFromInputsCommand(Header, Mainline,
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', ''));
    Mainline.MoveData[0].SecondsUsed := 999;
    Execute(Actor, Command);
    CheckHistory(Actor.GameTree);
    Mainline.MoveData := Copy(Data);
    // Identical moves with newly supplied historical data must not be signature-skipped.
    Mainline.MoveData[0].SecondsUsed := 7;
    Execute(Actor, Actor.CreateRebuildFromInputsCommand(Header, Mainline,
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
    Check(Actor.GameTree.MainlineNode[1].SecondsUsed = 7,
      'rebuild signature must include completed metadata');
    Mainline.MoveData := Copy(Data);
    Mainline.Moves := nil;
    Execute(Actor, Actor.CreateSetHeaderCommand(Header, Mainline));
    CheckHistory(Actor.GameTree);
    Check(Actor.GameTree.WhiteRemainingSeconds = 250,
      'live clock must remain separate from historical post-move clocks');
    // One coalesced snapshot can append several moves; future metadata waits for its node.
    for I := 0 to 2 do
      Execute(Appended, Appended.CreateAppendMainlineSnapshotMoveCommand(Header,
        Moves[I], '', Mainline, GameTreePvInput(False, 0, '', ''), gmsEngineMatch));
    CheckHistory(Appended.GameTree);
    Text := GameTreeToPdnText(Actor.GameTree);
    Check((Pos('emt: 1.000', Text) > 0) and (Pos('emt: 3.000', Text) > 0) and
      (Pos('clk: W=299.000', Text) > 0), 'PDN must export every move time and clock');
  finally
    Moves.Free;
    Appended.Free;
    Actor.Free;
  end;
  WriteLn('OK');
end.
