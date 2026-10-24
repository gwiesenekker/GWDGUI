program game_tree_topology_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uDraughtsBoard, uGameTree, uGameTreeActor,
  uGameTreeBuilder, uGameOrchestrator;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
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

procedure Rebuild(Actor: TGameTreeActor; const Signature, Fen, Text: string);
var
  Moves: TStringList;
begin
  Moves := TStringList.Create;
  try
    TextToMoveList(Text, Moves);
    Execute(Actor, Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput(Signature, '', '', '', '*', Fen, False,
        DefaultTimeControl),
      GameTreeMainlineInput(Moves, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
  finally
    Moves.Free;
  end;
end;

procedure CheckMainlineAndReplay;
var
  Actor: TGameTreeActor;
  Tree: TGameTree;
  Actual, Expected: TDraughtsBoard;
  SavedFen: string;
  Moves: TStringList;
  I: Integer;
begin
  Actor := TGameTreeActor.Create;
  Actual := TDraughtsBoard.Create;
  Expected := TDraughtsBoard.Create;
  Moves := TStringList.Create;
  try
    Rebuild(Actor, 'chain', '', '32-28 18-23 37-32');
    Tree := Actor.GameTree;
    Check(Tree.Root.ChildCount = 1, 'mainline must have one root continuation');
    Check(Tree.MainlineNode[1].Parent = Tree.Root, 'first move parent');
    for I := 2 to Tree.MainlineCount do
      Check(Tree.MainlineNode[I].Parent = Tree.MainlineNode[I - 1],
        'mainline must be a parent chain');
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '19-23 28x19', '', gmsHuman));
    Check(Tree.FindVariationNode(0, 1).Parent = Tree.MainlineNode[1],
      'variation belongs to its base position, not display position');
    Check(Tree.CopyNodeMovesTo(Tree.FindVariationNode(0, 2), Moves),
      'path extraction must succeed');
    Check(Moves.CommaText = '32-28,19-23,28x19', 'path must follow ancestry');
    Expected.SetBeginPosition;
    for I := 0 to Moves.Count - 1 do
      Expected.PlayMove(Moves[I]);
    Check(Tree.TryBuildBoardAtNode(Tree.FindVariationNode(0, 2), Actual),
      'variation replay must succeed');
    Check(Actual.CurrentFEN = Expected.CurrentFEN, 'replay must match legal path');
    SavedFen := Actual.CurrentFEN;
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '1-50', '', gmsHuman));
    Check(not Tree.TryBuildBoardAtNode(Tree.FindVariationNode(1, 1), Actual),
      'illegal imported continuation must fail validation');
    Check(Actual.CurrentFEN = SavedFen, 'failed replay must leave board intact');
    Check(Tree.TryBuildBoardAtNode(Tree.Root, Actual), 'root replay');
    Expected.SetBeginPosition;
    Check(Actual.CurrentFEN = Expected.CurrentFEN, 'root replay resets position');
    Rebuild(Actor, 'chain', '', '32-28');
    Check(Tree.MainlineCount = 1, 'trimming chain');
    Check(Tree.FindVariationNode(0, 2) <> nil,
      'trimming later mainline must keep alternatives at surviving positions');
    Rebuild(Actor, 'black', 'B:W31-50:B1-20', '19-23 32-28');
    Check(Tree.MainlineNode[1].MoveNumber = 1, 'black first move number');
    Check(Tree.MainlineNode[2].MoveNumber = 2, 'white reply starts next number');
  finally
    Moves.Free;
    Expected.Free;
    Actual.Free;
    Actor.Free;
  end;
end;

begin
  CheckMainlineAndReplay;
  WriteLn('OK');
end.
