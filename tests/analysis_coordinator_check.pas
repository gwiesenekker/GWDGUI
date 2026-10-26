program analysis_coordinator_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, uAnalysisCoordinator,
  uGameTree, uGameTreeActor, uGameTreeSearchRef, uGameOrchestrator,
  uDraughtsBoard, uPvSnapshot, uTreeTestUtils;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then raise Exception.Create(Text); end;
procedure Execute(Actor: TGameTreeActor; Command: TGameTreeCommand);
begin
  try Actor.ExecuteCommand(Command); Check(Command.Accepted, Command.ErrorText);
  finally Command.Free; end;
end;
procedure CheckAutoPlay;
var Actor, Other: TGameTreeActor; AutoPlay: TAutoPlayCoordinator;
  Board: TDraughtsBoard; Command: TGameTreeCommand; Search: TGameTreeSearchRef;
  Node: TGameTreePlyNode; ErrorText: string;
begin
  Actor := TGameTreeActor.Create; Other := TGameTreeActor.Create;
  AutoPlay := TAutoPlayCoordinator.Create; Board := TDraughtsBoard.Create;
  try
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('32-28', gmsHuman));
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('18-23', gmsHuman));
    Node := Actor.GameTree.MainlineNode[1];
    Check(Actor.GameTree.TryBuildBoardAtNode(Node, Board), 'historical Auto Play board');
    AutoPlay.BeginLine(Actor.GameTree, Node);
    Check(AutoPlay.Active and (AutoPlay.BasePly = 1) and (AutoPlay.NodeId = Node.NodeId) and
      (AutoPlay.MoveCount = 0) and (AutoPlay.MovesText = ''), 'start resets temporary line at selected node');
    Check(AutoPlay.CanContinue(Actor.GameTree, gosStopped), 'same stopped tree can continue');
    Check(not AutoPlay.CanContinue(Other.GameTree, gosStopped), 'different selected game cannot continue');
    Check(not AutoPlay.CanContinue(Actor.GameTree, gosRunning), 'resumed game cannot continue');
    Check(StartAnalysisSearch(Actor, Node, Search, ErrorText), ErrorText);
    AutoPlay.TrackSearch(Search);
    Check(AutoPlay.SearchMatches(Search), 'Auto Play tracks one-shot identity');
    Command := AutoPlay.CreateMoveCommand(Actor, Actor.GameTree, Board, '20-24', ErrorText);
    Check(Command <> nil, ErrorText);
    try
      Check((AutoPlay.MoveCount = 0) and (Node.AutoPlayPV = ''), 'preparing move changes neither preview nor tree');
      Actor.ExecuteCommand(Command); Check(Command.Accepted, Command.ErrorText);
      AutoPlay.MoveStored(Command);
    finally Command.Free; end;
    Check((AutoPlay.MovesText = '20-24') and (AutoPlay.MoveCount = 1) and
      (Node.AutoPlayPV = '20-24'), 'accepted move advances preview and selected-node PV');
    Check((Actor.GameTree.MainlineCount = 2) and
      (Actor.GameTree.MainlineNode[2].MoveText = '18-23'), 'official continuation preserved');
    Board.PlayMove('20-24');
    Command := AutoPlay.CreateMoveCommand(Actor, Actor.GameTree, Board, '38-32', ErrorText);
    Check(Command <> nil, ErrorText);
    try
      Actor.ExecuteCommand(Command); Check(Command.Accepted, Command.ErrorText);
      AutoPlay.MoveStored(Command);
    finally Command.Free; end;
    Check((AutoPlay.MovesText = '20-24 38-32') and (AutoPlay.MoveCount = 2), 'subsequent move extends PV in order');
    Command := AutoPlay.CreateMoveCommand(Actor, Actor.GameTree, Board, '1-50', ErrorText);
    Check((Command = nil) and (Pos('illegal move', ErrorText) > 0), 'illegal engine move creates no command');
    Check(AutoPlay.MoveCount = 2, 'illegal engine move does not advance preview');
    Command := AutoPlay.CreateMoveCommand(Actor, Other.GameTree, Board, '38-32', ErrorText);
    Check((Command = nil) and (ErrorText = 'game tree is no longer active'), 'wrong tree cannot receive Auto Play');
    Command := AutoPlay.CreateMoveCommand(Actor, Actor.GameTree, Board, '38-32', ErrorText);
    Check(Command <> nil, ErrorText);
    try
      Command.NodeId := High(Int64); // Simulate a target removed before delivery.
      Actor.ExecuteCommand(Command); Check(not Command.Accepted, 'actor rejects a missing PV target');
      AutoPlay.MoveStored(Command);
    finally Command.Free; end;
    Check((AutoPlay.MoveCount = 2) and (Node.AutoPlayPV = '20-24 38-32'), 'rejected actor command preserves state and PV');
    AutoPlay.ClearSearch;
    Check(not AutoPlay.SearchMatches(Search), 'consumed search cannot match again');
    AutoPlay.TrackSearch(Search); AutoPlay.Stop;
    Check(not AutoPlay.Active and not AutoPlay.SearchMatches(Search) and
      (AutoPlay.TreeId = 0) and (AutoPlay.NodeId = 0), 'stopping fences late results');
    AutoPlay.BeginLine(Actor.GameTree, Actor.GameTree.Root);
    Check((AutoPlay.MoveCount = 0) and (AutoPlay.MovesText = ''), 'new run discards previous temporary line');
  finally Board.Free; AutoPlay.Free; Other.Free; Actor.Free; end;
end;

var Actor, Other: TGameTreeActor; Coordinator: TAnalysisCoordinator;
  Snapshot: TPvSnapshot; Board: TDraughtsBoard; Tree: TGameTree;
  Node, ResolvedNode: TGameTreePlyNode; Search, NewSearch: TGameTreeSearchRef;
  ErrorText, Key, Signature: string; State: TGameTreeSearchState;
begin
  CheckAutoPlay;
  Actor := TGameTreeActor.Create; Other := TGameTreeActor.Create;
  Coordinator := TAnalysisCoordinator.Create;
  Snapshot := TPvSnapshot.Create; Board := TDraughtsBoard.Create;
  try
    Tree := Actor.GameTree;
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('32-28', gmsHuman));
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('18-23', gmsHuman));
    Execute(Actor, ImportBranch(Actor, 1, '20-24 38-32 18-22', '', gmsHuman));
    Node := Tree.FindBranchNode(0, 3);
    Check(Tree.TryBuildBoardAtNode(Node, Board), 'nested analysis position');
    Check(not StartAnalysisSearch(nil, Node, Search, ErrorText) and
      not IsValidGameTreeSearchRef(Search), 'missing actor cannot start a search');
    Check(StartAnalysisSearch(Actor, Node, Search, ErrorText), ErrorText);
    Coordinator.TrackSearch(Search);
    Check(Coordinator.SearchMatches(Search), 'tracked search matches full identity');
    NewSearch := Search; Inc(NewSearch.SearchId);
    Check(not Coordinator.SearchMatches(NewSearch), 'different search ID does not match');
    Snapshot.SetDataWithSearch(Board, 1, '12-18', '0.2', '9', '0.1', Search, False);
    Key := AnalysisSnapshotKey(Snapshot);
    Check(ResolveActiveAnalysisSnapshot(Actor, Snapshot, Tree, ResolvedNode) and
      (ResolvedNode = Node), 'active snapshot resolves by node identity, not mismatched base ply');
    Check(not ResolveActiveAnalysisSnapshot(Other, Snapshot, Tree, ResolvedNode) and
      (Tree = nil) and (ResolvedNode = nil), 'foreign actor cannot resolve snapshot');
    Tree := Actor.GameTree;
    Check(TryResolveAnalyzerSnapshotNode(Tree, Snapshot, ResolvedNode) and
      (ResolvedNode = Node), 'browser snapshot uses nested identity');
    Check(CancelGameTreeSearch(Actor, Search), 'cancel search');
    Check(not ResolveActiveAnalysisSnapshot(Actor, Snapshot, Tree, ResolvedNode),
      'cancelled search snapshot is stale');
    Check(not AcceptSearchMove(Actor, Search, '12-18', ErrorText), 'late done rejected after cancellation');
    Check(ReleaseRejectedSearchIfFinished(Actor, Search), 'cancelled search queues release');
    Actor.ProcessCommands;
    Check(not Actor.SearchState(Search, State), 'release removes cancelled registration');
    Tree := Actor.GameTree;
    Coordinator.ClearSearch;
    Check(not Coordinator.SearchMatches(Search), 'clearing UI tracking rejects old identity');
    Check(StartAnalysisSearch(Actor, Node, NewSearch, ErrorText), ErrorText);
    Snapshot.SetDataWithSearch(Board, 1, '12-18', '0.2', '9', '0.1', NewSearch, False);
    Check(AnalysisSnapshotKey(Snapshot) <> Key, 'queue keys distinguish searches at the same node');
    Check(not ReleaseRejectedSearchIfFinished(Actor, NewSearch), 'active search must not release on unrelated rejection');
    Check(AcceptSearchMove(Actor, NewSearch, '12-18', ErrorText), ErrorText);
    Check(not ResolveActiveAnalysisSnapshot(Actor, Snapshot, Tree, ResolvedNode), 'done search snapshot is stale');
    Check(ReleaseGameTreeSearch(Actor, NewSearch), 'accepted search queues release');
    Actor.ProcessCommands;
    Check(not Actor.SearchState(NewSearch, State), 'done registration released');
    Tree := Actor.GameTree;
    Check(Tree.MainlineCount = 2, 'search completion does not append an official move');
    Snapshot.SetDataWithSearch(Board, 1, '20-24', '0.1', '1', '', EmptyGameTreeSearchRef, False, True);
    Check(AnalyzerSnapshotIsTransient(Snapshot) and
      (AnalysisSnapshotKey(Snapshot) = 'display'), 'transient snapshots coalesce as display updates');
    Check(TryResolveAnalyzerSnapshotNode(Tree, Snapshot, ResolvedNode) and
      (ResolvedNode = Tree.MainlineNode[1]), 'unscoped browser fallback preserves base ply');
    Check(AnalysisSnapshotKey(nil) = '', 'nil snapshot key');
    Check(not AnalyzerSnapshotIsTransient(nil), 'nil is not transient');
    Coordinator.TrackSearch(EmptyGameTreeSearchRef);
    Check(not IsValidGameTreeSearchRef(Coordinator.Search), 'invalid tracking clears identity');
    Signature := DisplayedPositionSignature(Tree, Node.NodeId, Tree.StartingFEN, '32-28 20-24 38-32 18-22', gosStopped);
    Check(Coordinator.RestartAnalyzerFor(Signature), 'first analyzer position restarts');
    Check(not Coordinator.RestartAnalyzerFor(Signature), 'same position does not restart');
    Check(Coordinator.RestartMctsFor(Signature), 'MCTS signature is independent');
    Coordinator.InvalidateAnalyzer;
    Check(Coordinator.RestartAnalyzerFor(Signature), 'invalidation forces analyzer restart');
    Check(not Coordinator.RestartMctsFor(Signature), 'analyzer invalidation preserves MCTS deduplication');
    Coordinator.InvalidateMcts;
    Check(Coordinator.RestartMctsFor(Signature), 'MCTS invalidation forces restart');
    Check(Signature <> DisplayedPositionSignature(Tree, Tree.Root.NodeId,
      Tree.StartingFEN, '32-28 20-24 38-32 18-22', gosStopped), 'node identity affects signature');
    Check(AnalysisPositionIsTerminal(False, True, 1, 2, 3, gosStopped), 'no legal moves is always terminal');
    Check(AnalysisPositionIsTerminal(True, False, -1, 3, 3, gosGameOver), 'following completed tip is terminal');
    Check(not AnalysisPositionIsTerminal(True, False, 1, 1, 3, gosGameOver), 'completed game historical position can analyze');
    Check(not AnalysisPositionIsTerminal(True, True, 3, 4, 3, gosGameOver), 'legal preview can analyze beyond completed tip');
  finally Board.Free; Snapshot.Free; Coordinator.Free; Other.Free; Actor.Free; end;
  Writeln('Analysis coordinator checks passed');
end.
