program game_tree_topology_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uDraughtsBoard, uGameTree, uGameTreeActor,
  uGameTreeBuilder, uGameTreePdn, uGameOrchestrator, uTreeTestUtils, uDraughtsPosition;

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

procedure CheckRenderedNodeHits(Tree: TGameTree);
var
  Render: TGameTreePdnRenderResult;
  Node: TGameTreePlyNode;
  I, Count: Integer;
begin
  RenderGameTreeMovesToPdn(Tree, DefaultGameTreePdnRenderOptions, Render);
  Check((Length(Render.VariationStarts) = Length(Render.VariationNodeIds)) and
    (Length(Render.VariationStarts) = Length(Render.VariationBeforeMoves)),
    'every variation caret range must carry its node identity');
  Count := 0;
  for I := 0 to High(Render.VariationNodeIds) do
    if Render.VariationNodeIds[I] > 0 then
    begin
      Inc(Count);
      Node := Tree.FindNodeById(Render.VariationNodeIds[I]);
      Check(Node <> nil, 'stored-variation caret must resolve to a surviving node');
      if Render.VariationBeforeMoves[I] then
        Check((Node.Parent <> nil) and
          (Pos('(', Copy(Render.Text, Render.VariationStarts[I] + 1,
            Render.VariationLengths[I])) > 0), 'variation prefix must select before its child')
      else
        Check(Copy(Render.Text, Render.VariationStarts[I] + 1,
          Render.VariationLengths[I]) = Node.MoveText, 'move caret must identify its exact node');
    end;
  Check(Count > 0, 'stored branches must provide node-based caret ranges');
end;

procedure CheckQueuedRebuildPreservesCurrentBranches;
var
  Actor: TGameTreeActor;
  Moves: TStringList;
  Command: TGameTreeCommand;
  Node: TGameTreePlyNode;
  Id: Int64;
begin
  Actor := TGameTreeActor.Create;
  Moves := TStringList.Create;
  try
    Rebuild(Actor, 'queued', '', '32-28 18-23');
    Execute(Actor, ImportBranch(Actor, 1, '20-24', '', gmsHuman));
    Node := Actor.GameTree.FindBranchNode(0, 1);
    Id := Node.NodeId;
    TextToMoveList('32-28 18-23 37-32', Moves);
    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('queued', '', '', '', '*', DefaultStartingFEN, False,
        DefaultTimeControl), GameTreeMainlineInput(Moves, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', ''));
    Execute(Actor, Actor.CreateStoreMoveVariationCommand(Id, '38-32', gmsHuman));
    Execute(Actor, Actor.CreateRecordAnnotatorPVCommand(Id, '0.70', '38-32'));
    Execute(Actor, Command);
    Node := Actor.GameTree.FindNodeById(Id);
    Check((Node <> nil) and (Node.ChildCount = 1) and
      (Node.Children[0].MoveText = '38-32') and (Node.AnnotatorScore = '0.70'),
      'queued mainline rebuild must retain later branch edits and node metadata');
  finally
    Moves.Free;
    Actor.Free;
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
  Command: TGameTreeCommand;
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
    Execute(Actor, ImportBranch(Actor, 1,
      '19-23 28x19', '', gmsHuman));
    Check(Tree.FindBranchNode(0, 1).Parent = Tree.MainlineNode[1],
      'variation belongs to its base position, not display position');
    Check(Tree.CopyNodeMovesTo(Tree.FindBranchNode(0, 2), Moves),
      'path extraction must succeed');
    Check(Moves.CommaText = '32-28,19-23,28x19x23', 'path must follow ancestry');
    Expected.SetBeginPosition;
    for I := 0 to Moves.Count - 1 do
      Expected.PlayMove(Moves[I]);
    Check(TryBuildDraughtsBoardAtNode(Tree, Tree.FindBranchNode(0, 2), Actual),
      'variation replay must succeed');
    Check(Actual.CurrentFEN = Expected.CurrentFEN, 'replay must match legal path');
    SavedFen := Actual.CurrentFEN;
    Command := ImportBranch(Actor, 1, '1-50', '', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(not Command.Accepted, 'illegal imported continuation must be rejected');
    finally
      Command.Free;
    end;
    Check(not TryBuildDraughtsBoardAtNode(Tree, Tree.FindBranchNode(1, 1), Actual),
      'illegal imported continuation must fail validation');
    Check(Actual.CurrentFEN = SavedFen, 'failed replay must leave board intact');
    Check(TryBuildDraughtsBoardAtNode(Tree, Tree.Root, Actual), 'root replay');
    Expected.SetBeginPosition;
    Check(Actual.CurrentFEN = Expected.CurrentFEN, 'root replay resets position');
    Rebuild(Actor, 'chain', '', '32-28');
    Check(Tree.MainlineCount = 1, 'trimming chain');
    Check(Tree.FindBranchNode(0, 2) <> nil,
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

procedure CheckFirstChildMainContinuation;
var
  Actor: TGameTreeActor;
  Tree: TGameTree;
  FirstId, SecondId: Int64;
begin
  Actor := TGameTreeActor.Create;
  try
    Rebuild(Actor, 'promotion', '', '');
    Tree := Actor.GameTree;
    Execute(Actor, ImportBranch(Actor, 0,
      '31-26 16-21', 'Keep this comment', gmsHuman));
    FirstId := Tree.FindBranchNode(0, 1).NodeId;
    SecondId := Tree.FindBranchNode(0, 2).NodeId;
    Execute(Actor, Actor.CreateRecordAnnotatorPVCommand(FirstId, '0.50', '16-21'));
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('31-26', gmsEngineMatch));
    Check((Tree.Root.ChildCount = 1) and (Tree.MainlineNode[1].NodeId = FirstId),
      'promoting an existing child must reuse its identity instead of duplicating it');
    Check(Tree.MainlineNode[1].AnnotatorPV = '16-21', 'promotion must retain node-owned analysis');
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('16-21', gmsEngineMatch));
    Check((Tree.MainlineNode[2].NodeId = SecondId) and
      (Tree.MainlineNode[1].Children[0] = Tree.MainlineNode[2]),
      'the next promoted move must reuse the first-child continuation');
    Check(Tree.MainlineNode[2].CommentText = 'Keep this comment', 'promotion must retain node-owned comments');
    Rebuild(Actor, 'ordering', '', '');
    Execute(Actor, ImportBranch(Actor, 0, '31-26', '', gmsHuman));
    FirstId := Tree.FindBranchNode(0, 1).NodeId;
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('32-28', gmsEngineMatch));
    Check((Tree.Root.ChildCount = 2) and (Tree.Root.Children[0] = Tree.MainlineNode[1]) and
      (Tree.Root.Children[1].NodeId = FirstId),
      'a later mainline insertion must precede an earlier alternative without deleting it');
  finally
    Actor.Free;
  end;
end;

procedure CheckMoveInsertionUsesRealAncestry;
var
  Actor: TGameTreeActor;
  Tree: TGameTree;
  Parent, Child: TGameTreePlyNode;
  Command: TGameTreeCommand;
  ChildId: Int64;
  Moves: TStringList;
begin
  Actor := TGameTreeActor.Create;
  Moves := TStringList.Create;
  try
    Rebuild(Actor, 'ancestry', '', '32-28 18-23');
    Tree := Actor.GameTree;
    // The import adapter includes an official move in its path. Actual branch
    // ancestry starts after that shared mainline node, regardless of alias base.
    Execute(Actor, ImportBranch(Actor, 0,
      '32-28 20-24', 'Keep branch comment', gmsHuman));
    Parent := Tree.FindBranchNode(0, 1);
    Command := Actor.CreateStoreMoveVariationCommand(Parent.NodeId, '37-32', gmsHuman);
    Actor.ExecuteCommand(Command);
    Check(Command.Accepted, Command.ErrorText);
    ChildId := Command.CreatedNodeId;
    Command.Free;
    Child := Tree.FindNodeById(ChildId);
    Check((Child <> nil) and (Child.Parent = Parent), 'new move must use its real parent');
    Check(Tree.CopyNodeMovesTo(Child, Moves) and
      (Moves.CommaText = '32-28,20-24,37-32'), 'new branch must follow real ancestry');
    Execute(Actor, Actor.CreateStoreMoveVariationCommand(Parent.NodeId, '38-32', gmsHuman));
    Check(Parent.ChildCount = 2, 'a second move must create one sibling');
    // Removing a separate sibling must not affect the selected parent's identity.
    Execute(Actor, ImportBranch(Actor, 0, '31-26', '', gmsHuman));
    Tree.RemoveBranch(Tree.FindChildByMove(Tree.Root, '31-26'));
    Command := Actor.CreateStoreMoveVariationCommand(Parent.NodeId, '37-32', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted and not Command.TreeChanged and (Command.CreatedNodeId = ChildId),
        'replaying a child after alias reindexing must find that node without mutation');
    finally
      Command.Free;
    end;
    Check(Parent.CommentText = 'Keep branch comment', 'branch editing must preserve parent comments');
    CheckRenderedNodeHits(Tree);
  finally
    Moves.Free;
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
    Execute(Actor, ImportBranch(Actor, 1,
      '20-24 37-32 14-20', '', gmsHuman));
    ParentId := Tree.FindBranchNode(0, 1).NodeId;
    Execute(Actor, Actor.CreateRecordEnginePVCommand(ParentId,
      '0.25', '37-32', '10', '0.2'));
    Execute(Actor, ImportBranch(Actor, 1,
      '20-24 38-32 14-20', '', gmsHuman));
    Execute(Actor, ImportBranch(Actor, 1,
      '20-24 38-32 18-22', '', gmsHuman));
    Check(Tree.FindBranchNode(0, 1) = Tree.FindBranchNode(1, 1),
      'shared prefix must have a single node');
    Check(Tree.FindBranchNode(1, 2) = Tree.FindBranchNode(2, 2),
      'nested prefix must have a single node');
    Check(Tree.FindBranchNode(0, 1).EnginePV = '37-32',
      'materializing another path must preserve shared analysis');
    Check(Tree.FindBranchNode(0, 1).ChildCount = 2, 'branch count');
    NestedId := Tree.FindBranchNode(2, 2).NodeId;
    Check(TryBuildDraughtsBoardAtNode(Tree, Tree.FindBranchNode(2, 3), Actual),
      'nested replay must succeed');
    Check(Tree.CopyNodeMovesTo(Tree.FindBranchNode(2, 3), Moves),
      'nested path extraction');
    Expected.SetBeginPosition;
    for I := 0 to Moves.Count - 1 do
      Expected.PlayMove(Moves[I]);
    Check(Actual.CurrentFEN = Expected.CurrentFEN, 'nested replay path');
    Rebuild(Actor, 'shared', '', '32-28 18-23 37-32');
    Check(Tree.FindBranchNode(0, 1).NodeId = ParentId,
      'refresh must retain shared identity');
    Check(Tree.FindBranchNode(2, 2).NodeId = NestedId,
      'refresh must retain nested identity');
    Check(Tree.FindBranchNode(1, 1).EnginePV = '37-32',
      'refresh must retain shared analysis');
    CheckRenderedNodeHits(Tree);
    Tree.RemoveBranch(Tree.FindBranchNode(0, 2));
    Check(Tree.FindNodeById(NestedId) = Tree.FindBranchNode(0, 2),
      'removing a sibling must preserve the shared nested subtree');
    CheckRenderedNodeHits(Tree);
    Execute(Actor, Actor.CreateClearBranchesCommand);
    Check(Tree.BranchCount = 0, 'clear removes aliases');
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
    Execute(Actor, ImportBranch(Actor, 1,
      '20-24 37-32', '', gmsHuman));
    AddAnalysis(Tree.FindBranchNode(0, 1));
    Execute(Actor, Actor.CreateClearBranchesCommand);
    Execute(Actor, ImportBranch(Actor, 1,
      '17-21 37-32', '', gmsHuman));
    CheckEmpty(Tree.FindBranchNode(0, 1));
    AddAnalysis(Tree.FindBranchNode(0, 2));
    Tree.RemoveBranch(Tree.FindBranchNode(0, 2));
    AddFixtureBranch(Tree, 1, '17-21 38-32', '');
    CheckEmpty(Tree.FindBranchNode(0, 2));
    AddAnalysis(Tree.FindBranchNode(0, 2));
    SharedId := Tree.FindBranchNode(0, 2).NodeId;
    Execute(Actor, ImportBranch(Actor, 1,
      '17-21 38-32 12-17', '', gmsHuman));
    Tree.RemoveBranch(Tree.FindBranchNode(0, 3));
    Rebuild(Actor, 'metadata', '', '32-28 19-23 28x19');
    Check(Tree.FindBranchNode(0, 2).NodeId = SharedId,
      'shared node must survive its original path being shortened');
    Check(Tree.FindBranchNode(0, 2).EngineScore = '0.44',
      'analysis must survive a changed canonical variation address');
    Check(Tree.FindBranchNode(0, 2).AnnotatorPV = '38-32 12-18',
      'refresh must preserve shared-node analysis by identity');
    Check(Tree.FindBranchNode(0, 2).AutoPlayPV = '39-33',
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
  CheckQueuedRebuildPreservesCurrentBranches;
  CheckMainlineAndReplay;
  CheckFirstChildMainContinuation;
  CheckMoveInsertionUsesRealAncestry;
  CheckSharedBranches;
  CheckMetadataBelongsToNodes;
  CheckScoresDoNotCreepForward;
  WriteLn('OK');
end.
