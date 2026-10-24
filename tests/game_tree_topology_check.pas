program game_tree_topology_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uDraughtsBoard, uGameTree, uGameTreeActor,
  uGameTreeBuilder, uGameTreePdn, uGameOrchestrator;

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

procedure CheckSharedBranches;
var
  Actor: TGameTreeActor;
  Tree: TGameTree;
  ParentId, NestedId: Int64;
  Moves: TStringList;
  Changed: Boolean;
  Actual, Expected: TDraughtsBoard;
  I: Integer;
begin
  Actor := TGameTreeActor.Create;
  Moves := TStringList.Create;
  Actual := TDraughtsBoard.Create;
  Expected := TDraughtsBoard.Create;
  try
    Rebuild(Actor, 'shared', '', '32-28 18-23 37-32');
    Tree := Actor.GameTree;
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '20-24 37-32 14-20', '', gmsHuman));
    ParentId := Tree.FindVariationNode(0, 1).NodeId;
    Execute(Actor, Actor.CreateRecordEnginePVCommand(ParentId,
      '0.25', '37-32', '10', '0.2'));
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '20-24 38-32 14-20', '', gmsHuman));
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '20-24 38-32 18-22', '', gmsHuman));
    Check(Tree.FindVariationNode(0, 1) = Tree.FindVariationNode(1, 1),
      'shared prefix must have a single node');
    Check(Tree.FindVariationNode(1, 2) = Tree.FindVariationNode(2, 2),
      'nested prefix must have a single node');
    Check(Tree.FindVariationNode(0, 1).EnginePV = '37-32',
      'materializing another path must preserve shared analysis');
    Check(Tree.FindVariationNode(0, 1).ChildCount = 2, 'branch count');
    NestedId := Tree.FindVariationNode(2, 2).NodeId;
    Check(Tree.TryBuildBoardAtNode(Tree.FindVariationNode(2, 3), Actual),
      'nested replay must succeed');
    Check(Tree.CopyNodeMovesTo(Tree.FindVariationNode(2, 3), Moves),
      'nested path extraction');
    Expected.SetBeginPosition;
    for I := 0 to Moves.Count - 1 do
      Expected.PlayMove(Moves[I]);
    Check(Actual.CurrentFEN = Expected.CurrentFEN, 'nested replay path');
    Rebuild(Actor, 'shared', '', '32-28 18-23 37-32');
    Check(Tree.FindVariationNode(0, 1).NodeId = ParentId,
      'refresh must retain shared identity');
    Check(Tree.FindVariationNode(2, 2).NodeId = NestedId,
      'refresh must retain nested identity');
    Check(Tree.FindVariationNode(1, 1).EnginePV = '37-32',
      'refresh must retain shared analysis');
    Tree.StoreVariationLineAtIndex(0, 2, 1, '20-24', '', Changed);
    TextToMoveList('20-24', Moves);
    RecordGameTreeVariationLine(Tree, GameTreeVariationLineInput(
      Tree.VariationLine[0], 0, Moves, nil));
    Check(Tree.FindVariationNode(0, 2) = nil, 'shortened legacy path ends');
    Check(Tree.FindNodeById(NestedId) = Tree.FindVariationNode(1, 2),
      'shortening one path must preserve shared sibling subtree');
    Execute(Actor, Actor.CreateClearStoredVariationsCommand);
    Check(Tree.VariationLineCount = 0, 'clear removes aliases');
    Check(Tree.FindNodeById(NestedId) = nil, 'clear removes nested variations');
    Check(Tree.MainlineCount = 3, 'clear preserves mainline');
    Check(Tree.MainlineNode[3].Parent = Tree.MainlineNode[2],
      'clear preserves mainline chain');
  finally
    Expected.Free;
    Actual.Free;
    Moves.Free;
    Actor.Free;
  end;
end;

procedure CheckMetadataBelongsToNodes;
var
  Actor: TGameTreeActor;
  Tree: TGameTree;
  OldId, PrefixId, SharedId: Int64;
  Changed: Boolean;
  Moves: TStringList;

  procedure AddAnalysis(Node: TGameTreePlyNode);
  begin
    Execute(Actor, Actor.CreateRecordEnginePVCommand(Node.NodeId,
      '0.44', '37-32 12-18', '12', '1.2'));
    Execute(Actor, Actor.CreateRecordAnnotatorPVCommand(Node.NodeId,
      '0.55', '38-32 12-18', '9', '0.5'));
    Execute(Actor, Actor.CreateRecordAutoPlayPVCommand(Node.NodeId, '39-33'));
  end;

  procedure CheckEmpty(Node: TGameTreePlyNode);
  begin
    Check((Node.EnginePV = '') and (Node.EngineScore = '') and
      (Node.EnginePVDepth = '') and (Node.EnginePVTimeText = '') and
      (Node.AnnotatorPV = '') and (Node.AnnotatorScore = '') and
      (Node.AnnotatorPVDepth = '') and (Node.AnnotatorPVTimeText = '') and
      (Node.AutoPlayPV = '') and (not Node.HasClockInfo),
      'a replacement node must not inherit analysis or clocks');
  end;
begin
  Actor := TGameTreeActor.Create;
  Moves := TStringList.Create;
  try
    Rebuild(Actor, 'metadata', '', '32-28 18-23 37-32');
    Tree := Actor.GameTree;
    PrefixId := Tree.MainlineNode[1].NodeId;
    AddAnalysis(Tree.MainlineNode[1]);
    AddAnalysis(Tree.MainlineNode[2]);
    Tree.RecordClockState(2, 299, 298, 1, 2);
    OldId := Tree.MainlineNode[2].NodeId;
    Rebuild(Actor, 'metadata', '', '32-28 19-23 28x19');
    Check(Tree.FindNodeById(OldId) = nil, 'replaced node must disappear');
    CheckEmpty(Tree.MainlineNode[2]);
    Check(Tree.MainlineNode[1].NodeId = PrefixId, 'unchanged prefix identity');
    Check(Tree.MainlineNode[1].AnnotatorPV = '38-32 12-18',
      'unchanged prefix must retain its analysis');
    AddAnalysis(Tree.MainlineNode[3]);
    Tree.RecordClockState(3, 298, 298, 2, 2);
    Rebuild(Actor, 'metadata', '', '32-28 19-23');
    Rebuild(Actor, 'metadata', '', '32-28 19-23 28x19');
    CheckEmpty(Tree.MainlineNode[3]);
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '20-24 37-32', '', gmsHuman));
    AddAnalysis(Tree.FindVariationNode(0, 1));
    Execute(Actor, Actor.CreateClearStoredVariationsCommand);
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '17-21 37-32', '', gmsHuman));
    CheckEmpty(Tree.FindVariationNode(0, 1));
    AddAnalysis(Tree.FindVariationNode(0, 2));
    Tree.StoreVariationLineAtIndex(0, 2, 1, '17-21 38-32', '', Changed);
    TextToMoveList('17-21 38-32', Moves);
    RecordGameTreeVariationLine(Tree, GameTreeVariationLineInput(
      Tree.VariationLine[0], 0, Moves, nil));
    CheckEmpty(Tree.FindVariationNode(0, 2));
    AddAnalysis(Tree.FindVariationNode(0, 2));
    SharedId := Tree.FindVariationNode(0, 2).NodeId;
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '17-21 38-32 14-20', '', gmsHuman));
    Tree.StoreVariationLineAtIndex(0, 2, 1, '17-21', '', Changed);
    TextToMoveList('17-21', Moves);
    RecordGameTreeVariationLine(Tree, GameTreeVariationLineInput(
      Tree.VariationLine[0], 0, Moves, nil));
    Rebuild(Actor, 'metadata', '', '32-28 19-23 28x19');
    Check(Tree.FindVariationNode(1, 2).NodeId = SharedId,
      'shared node must survive its original path being shortened');
    Check(Tree.FindVariationNode(1, 2).EngineScore = '0.44',
      'analysis must survive a changed canonical variation address');
    Check(Tree.FindVariationNode(1, 2).AnnotatorPV = '38-32 12-18',
      'refresh must preserve shared-node analysis by identity');
    Check(Tree.FindVariationNode(1, 2).AutoPlayPV = '39-33',
      'refresh must preserve Auto Play analysis by identity');
  finally
    Moves.Free;
    Actor.Free;
  end;
end;

procedure CheckScoresDoNotCreepForward;
var
  Actor: TGameTreeActor;
  Lines, Moves: TStringList;
  I: Integer;
begin
  Actor := TGameTreeActor.Create;
  Lines := TStringList.Create;
  Moves := TStringList.Create;
  try
    Rebuild(Actor, 'scores', '', '32-28 18-23 37-32 12-18');
    Execute(Actor, Actor.CreateRecordAnnotatorPVCommand(
      Actor.GameTree.MainlineNode[1].NodeId, '0.50', '18-23'));
    Actor.GameTree.CopyMainlineMovesTo(Moves);
    for I := 1 to 20 do
    begin
      Lines.Text := GameTreeScoreAnnotationsText(Actor.GameTree);
      Check(Lines.Count = 4, 'score projection must retain empty ply slots');
      Check((Lines[1] = '') and (Lines[2] = '') and (Lines[3] = ''),
        'a missing score must not inherit the preceding position score');
      Execute(Actor, Actor.CreateRebuildFromInputsCommand(
        GameTreeHeaderInput('scores', '', '', '', '*', '', False,
          DefaultTimeControl),
        GameTreeMainlineInput(Moves, Lines, False, 0, 0, 0, 0),
        GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
      Check(Actor.GameTree.MainlineNode[1].AnnotatorScore = '0.50',
        'refresh must preserve the actual annotated position');
      Check(Actor.GameTree.MainlineNode[2].AnnotatorScore = '',
        'refresh must not move a score to another position');
    end;
  finally
    Moves.Free;
    Lines.Free;
    Actor.Free;
  end;
end;

begin
  CheckMainlineAndReplay;
  CheckSharedBranches;
  CheckMetadataBelongsToNodes;
  CheckScoresDoNotCreepForward;
  WriteLn('OK');
end.
