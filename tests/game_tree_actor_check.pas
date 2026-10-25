program game_tree_actor_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, Math, uGameTreeNodeData,
  uDraughtsBoard, uGameTree, uGameTreeActor, uGameTreeBuilder,
  uGameTreeSearchRef, uPdn, uGameOrchestrator, uTreeTestUtils;

type
  TQueuedCommandObserver = class
  public
    AcceptedCount: Integer;
    RejectedCount: Integer;
    TreeChangedCount: Integer;
    procedure Observe(ACommand: TGameTreeCommand);
  end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    Writeln('FAIL: ', AMessage);
    Halt(1);
  end;
end;

procedure TQueuedCommandObserver.Observe(ACommand: TGameTreeCommand);
begin
  if ACommand = nil then
    Exit;
  if ACommand.Accepted then
    Inc(AcceptedCount)
  else
    Inc(RejectedCount);
  if ACommand.TreeChanged then
    Inc(TreeChangedCount);
end;

procedure CheckFreshGameTreeDefaults;
var
  GameTree: TGameTree;
begin
  GameTree := TGameTree.Create;
  try
    Check(GameTree.StartingFEN = DefaultStartingFEN,
      'fresh game tree should default to the initial position FEN');
    Check(GameTree.WhiteName = 'White',
      'fresh game tree should default white name');
    Check(GameTree.BlackName = 'Black',
      'fresh game tree should default black name');
    Check(GameTree.ResultText = '*',
      'fresh game tree should default result text');
  finally
    GameTree.Free;
  end;
end;

procedure CheckActorCommands;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  CustomTimeControl: TTimeControl;
  EmptyAnnotations: TStringList;
  Moves: TStringList;
  Node: TGameTreePlyNode;
  RevisionAfterHeader: Int64;
  RevisionAfterClock: Int64;
  RevisionAfterTimeControl: Int64;
  VariationNode: TGameTreePlyNode;
begin
  Actor := TGameTreeActor.Create;
  Moves := TStringList.Create;
  EmptyAnnotations := TStringList.Create;
  try
    Actor.GameTree.BeginRebuild('actor', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    Command := Actor.CreateAddMainlineMoveCommand(1, '32-28', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'add-mainline command should be accepted');
      Check(Command.TreeChanged,
        'add-mainline command should report tree change');
      Check(Command.CreatedNodeId > 0, 'add-mainline command should return node id');
      Node := Actor.GameTree.FindNodeById(Command.CreatedNodeId);
      Check(Node <> nil, 'created node id should resolve');
      Check(Node.MoveText = '32-28', 'created node should contain move');
      Check(Actor.Revision = 1, 'accepted mutation should increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateAppendMainlineMoveCommand('30-25', gmsHuman);
    try
      Command.GameTreeId := Command.GameTreeId + 1;
      Actor.ExecuteCommand(Command);
      Check(not Command.Accepted,
        'wrong game-tree command should be rejected');
      Check(not Command.TreeChanged,
        'rejected command should not report tree change');
      Check(Actor.Revision = 1,
        'wrong game-tree command should not increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateAppendMainlineMoveCommand('18-23', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'append-mainline command should be accepted');
      Check(Command.TreeChanged,
        'append-mainline command should report tree change');
      Check(Command.PlyNumber = 2,
        'append-mainline command should report appended ply');
      Check(Command.NodeId = Command.CreatedNodeId,
        'append-mainline command should report created node id');
      Node := Actor.GameTree.FindNodeById(Command.NodeId);
      Check(Node <> nil, 'appended node id should resolve');
      Check(Node.MoveText = '18-23', 'appended node should contain move');
    finally
      Command.Free;
    end;

    Command := Actor.CreateAppendMainlineSnapshotMoveCommand(
      GameTreeHeaderInput('snapshot', 'Match', 'Engine A', 'Engine B', '*',
        'W:W31-50:B1-20', True, DefaultTimeControl, gosWaiting,
        'engine warning'),
      '37-32', AnnotationWithScore('', 'engine', '0.37'),
      GameTreeMainlineInput(nil, nil, True, 299.0, 298.0, 1.0, 2.0),
      GameTreePvInput(True, 3, '0.37', '38-33', '8', '0.21'),
      gmsEngineMatch);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'append snapshot move command should be accepted');
      Check(Command.TreeChanged,
        'append snapshot move command should report tree change');
      Check(Command.PlyNumber = 3,
        'append snapshot move should report appended ply');
      Node := Actor.GameTree.MainlineNode[3];
      Check(Node <> nil, 'snapshot appended node should exist');
      Check(Node.MoveText = '37-32',
        'snapshot appended node should contain move');
      Check(Node.EngineScore = '0.37',
        'snapshot appended node should keep move annotation score');
      Check(Actor.GameTree.MainlineNode[3].EnginePV = '38-33',
        'snapshot appended node should record engine PV');
      Check(Actor.GameTree.MainlineNode[3].EngineScore = '0.37',
        'snapshot appended node should record engine PV score');
      Check(Actor.GameTree.MainlineNode[3].EnginePVDepth = '8',
        'snapshot appended node should record engine PV depth');
      Check(Actor.GameTree.MainlineNode[3].EnginePVTimeText = '0.21',
        'snapshot appended node should record engine PV time');
      Check(Node.HasClockInfo,
        'snapshot appended node should record clock state');
      Check(Abs(Node.WhiteRemainingSeconds - 299.0) < 0.001,
        'snapshot appended node should record white clock');
      Check(Actor.GameTree.EventName = 'Match',
        'snapshot append should update header');
      Check(Actor.GameTree.WhiteName = 'Engine A',
        'snapshot append should update white name');
      Check(Actor.GameTree.StatusText = 'engine warning',
        'snapshot append should update status text');
      Check(Actor.GameTree.MainlineNode[3].EnginePV = '38-33',
        'snapshot append should record engine PV');
    finally
      Command.Free;
    end;

    Command := ImportBranch(Actor, 1, '20-24',
      'annotator=0.22', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'store-variation command should be accepted');
      Check(Command.TreeChanged,
        'store-variation command should report tree change');
      Check(Command.CreatedNodeId > 0,
        'first variation should get variation index 0');
      Check(Actor.GameTree.BranchCount = 1,
        'variation should be stored on game tree');
      Check(Actor.GameTree.FindBranchNode(0, 1).AnnotatorScore = '0.22',
        'variation should store annotation text on game tree');
      Check(Actor.GameTree.BranchPath[0].OriginText = 'Human',
        'human variation should store human origin');
      Check(Actor.Revision = 4, 'fourth mutation should increment revision');
    finally
      Command.Free;
    end;

    Command := ImportBranch(Actor, 1, '20-24', '',
      gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'empty variation update should be accepted');
      Check(not Command.TreeChanged,
        'empty variation update should not report tree change');
      Check(Actor.GameTree.FindBranchNode(0, 1).AnnotatorScore = '0.22',
        'empty variation update should not clear annotation text');
      Check(Actor.Revision = 4,
        'unchanged variation update should not increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateClearBranchesCommand;
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'clear-variations command should be accepted');
      Check(Command.TreeChanged,
        'clear-variations command should report tree change');
      Check(Actor.GameTree.BranchCount = 0,
        'clear-variations command should remove stored variations');
      Check(Actor.Revision = 5, 'clear mutation should increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateClearBranchesCommand;
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'empty clear-variations command should be accepted');
      Check(not Command.TreeChanged,
        'empty clear-variations command should not report tree change');
      Check(Actor.Revision = 5,
        'empty clear-variations command should not increment revision');
    finally
      Command.Free;
    end;

    Command := ImportBranch(Actor, 1, '20-24',
      'annotator=0.22', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'setup variation before rebuild should be accepted');
      Check(Actor.GameTree.BranchCount = 1,
        'setup variation should be stored before rebuild');
      Check(Actor.GameTree.FindBranchNode(0, 1).AnnotatorScore = '0.22',
        'setup variation should store annotation text before rebuild');
      Check(Actor.GameTree.BranchPath[0].OriginText = 'Human',
        'setup variation should store origin before rebuild');
    finally
      Command.Free;
    end;

    Moves.Clear;
    Moves.Add('32-28');
    Moves.Add('18-23');
    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('actor-rebuild-new-signature', 'Event', 'White',
        'Black', '*', 'W:W31-50:B1-20', False, DefaultTimeControl),
      GameTreeMainlineInput(Moves, EmptyAnnotations, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', ''));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'rebuild with different signature should be accepted');
      Check(Command.TreeChanged,
        'rebuild with different signature should report tree change');
      Check(Actor.GameTree.BranchCount = 0,
        'rebuild of a different game should discard previous variation lines');
      VariationNode := Actor.GameTree.FindBranchNode(0, 1);
      Check(VariationNode = nil,
        'rebuild of a different game should not recreate old variation nodes');
    finally
      Command.Free;
    end;

    Command := Actor.CreateSetHeaderCommand(
      GameTreeHeaderInput('', 'New Event', 'Alice', 'Bob', '1-0',
        'W:W31-50:B1-20', False, DefaultTimeControl, gosWaiting,
        'manual adjudication'));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'set-header command should be accepted');
      Check(Command.TreeChanged,
        'set-header command should report tree change');
      Check(Actor.GameTree.EventName = 'New Event',
        'set-header command should update event');
      Check(Actor.GameTree.WhiteName = 'Alice',
        'set-header command should update white name');
      Check(Actor.GameTree.BlackName = 'Bob',
        'set-header command should update black name');
      Check(Actor.GameTree.ResultText = '1-0',
        'set-header command should update result');
      Check(Actor.GameTree.StatusText = 'manual adjudication',
        'set-header command should update status text');
      RevisionAfterHeader := Actor.Revision;
    finally
      Command.Free;
    end;

    Command := Actor.CreateSetHeaderCommand(
      GameTreeHeaderInput('', 'New Event', 'Alice', 'Bob', '1-0',
        'W:W31-50:B1-20', False, DefaultTimeControl, gosWaiting,
        'manual adjudication'));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'duplicate set-header command should be accepted');
      Check(not Command.TreeChanged,
        'duplicate set-header command should not report tree change');
      Check(Actor.GameTree.EventName = 'New Event',
        'duplicate set-header command should keep event');
      Check(Actor.Revision = RevisionAfterHeader,
        'duplicate set-header command should not increment revision');
    finally
      Command.Free;
    end;

    CustomTimeControl := DefaultTimeControl;
    CustomTimeControl.MovesPerPeriod := 40;
    CustomTimeControl.MinutesPerPeriod := 10;
    CustomTimeControl.IncrementSeconds := 1;
    CustomTimeControl.IncrementMode := cimAfterMoveLimit;
    Command := Actor.CreateSetHeaderCommand(
      GameTreeHeaderInput('', 'New Event', 'Alice', 'Bob', '1-0',
        'W:W31-50:B1-20', True, CustomTimeControl));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'set-header command with time control should be accepted');
      Check(Actor.GameTree.HasTimeControl,
        'set-header command should record time control');
      Check(Actor.GameTree.MovesPerPeriod = 40,
        'set-header command should record moves per period');
      Check(Actor.GameTree.MinutesPerPeriod = 10,
        'set-header command should record minutes per period');
      Check(Actor.GameTree.IncrementSeconds = 1,
        'set-header command should record increment seconds');
      Check(Actor.GameTree.IncrementModeText = 'after move limit',
        'set-header command should record increment mode');
      Check(Actor.Revision > RevisionAfterHeader,
        'set-header time-control change should increment revision');
      RevisionAfterTimeControl := Actor.Revision;
    finally
      Command.Free;
    end;

    Command := Actor.CreateSetHeaderCommand(
      GameTreeHeaderInput('', 'New Event', 'Alice', 'Bob', '1-0',
        'W:W31-50:B1-20', True, CustomTimeControl));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'duplicate set-header time-control command should be accepted');
      Check(Actor.Revision = RevisionAfterTimeControl,
        'duplicate set-header time-control command should not increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateSetHeaderCommand(
      GameTreeHeaderInput('', 'New Event', 'Alice', 'Bob', '1-0',
        'W:W31-50:B1-20', True, CustomTimeControl),
      GameTreeMainlineInput(nil, nil, True, 123.0, 234.0, 12.0, 23.0));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'set-header command with clock state should be accepted');
      Check(Actor.GameTree.HasClockInfo,
        'set-header command should record clock state');
      Check(Actor.GameTree.WhiteRemainingSeconds = 123.0,
        'set-header command should record white remaining time');
      Check(Actor.GameTree.BlackRemainingSeconds = 234.0,
        'set-header command should record black remaining time');
      Check(Actor.GameTree.WhiteUsedSeconds = 12.0,
        'set-header command should record white used time');
      Check(Actor.GameTree.BlackUsedSeconds = 23.0,
        'set-header command should record black used time');
      Check(Actor.Revision > RevisionAfterTimeControl,
        'set-header clock change should increment revision');
      RevisionAfterClock := Actor.Revision;
    finally
      Command.Free;
    end;

    Command := Actor.CreateSetHeaderCommand(
      GameTreeHeaderInput('', 'New Event', 'Alice', 'Bob', '1-0',
        'W:W31-50:B1-20', True, CustomTimeControl),
      GameTreeMainlineInput(nil, nil, True, 123.0, 234.0, 12.0, 23.0));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'duplicate set-header clock command should be accepted');
      Check(Actor.Revision = RevisionAfterClock,
        'duplicate set-header clock command should not increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('clock-rebuild', 'Clock Event', 'Alice', 'Bob',
        '*', 'W:W31-50:B1-20', True, CustomTimeControl),
      GameTreeMainlineInput(nil, nil, True, 321.0, 432.0, 21.0, 32.0),
      GameTreePvInput(False, 0, '', ''),
      GameTreePvInput(False, 0, '', ''));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'rebuild command with no moves and clock state should be accepted');
      Check(Actor.GameTree.HasClockInfo,
        'rebuild command with no moves should record clock state');
      Check(Actor.GameTree.WhiteRemainingSeconds = 321.0,
        'rebuild command with no moves should record white remaining time');
      Check(Actor.GameTree.BlackRemainingSeconds = 432.0,
        'rebuild command with no moves should record black remaining time');
      Check(Actor.GameTree.WhiteUsedSeconds = 21.0,
        'rebuild command with no moves should record white used time');
      Check(Actor.GameTree.BlackUsedSeconds = 32.0,
        'rebuild command with no moves should record black used time');
    finally
      Command.Free;
    end;
  finally
    EmptyAnnotations.Free;
    Moves.Free;
    Actor.Free;
  end;
end;

procedure CheckQueuedActorCommands;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Observer: TQueuedCommandObserver;
  ResultMove: string;
  ResultNodeId: Int64;
  Search: TGameTreeSearchRef;
  State: TGameTreeSearchState;
begin
  Actor := TGameTreeActor.Create;
  Observer := TQueuedCommandObserver.Create;
  try
    Actor.GameTree.BeginRebuild('queue', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');

    Command := Actor.CreateAppendMainlineMoveCommand('32-28', gmsHuman);
    Check(Actor.PostCommand(Command), 'queued append command should post');
    Command := nil;
    Check(Actor.ProcessCommands = 1, 'one queued command should process');
    Check(Actor.GameTree.MainlineCount = 1,
      'queued append command should mutate game tree');
    Check(Actor.GameTree.MainlineNode[1].MoveText = '32-28',
      'queued append command should record move');
    Check(Actor.Revision = 1,
      'accepted queued command should increment revision');

    Command := Actor.CreateAppendMainlineMoveCommand('31-27', gmsHuman);
    Command.GameTreeId := Command.GameTreeId + 1;
    Check(Actor.PostCommand(Command),
      'wrong game-tree queued command should post');
    Command := nil;
    Check(Actor.ProcessCommands = 1,
      'wrong game-tree queued command should process');
    Check(Actor.GameTree.MainlineCount = 1,
      'wrong game-tree queued command should not mutate game tree');
    Check(Actor.Revision = 1,
      'wrong game-tree queued command should not increment revision');

    Command := Actor.CreateStartSearchCommand(
      Actor.GameTree.MainlineNode[1].NodeId, Search);
    Check(Actor.PostCommand(Command), 'queued start-search should post');
    Command := nil;
    Check(Actor.ProcessCommands = 1,
      'queued start-search should process');
    Check(Actor.SearchState(Search, State),
      'queued start-search should create search');
    Check(State = gssActive,
      'queued start-search should create active search');

    Command := Actor.CreateSearchDoneCommand(Search, '18-23');
    Command.NodeId := Command.NodeId + 1;
    Check(Actor.PostCommand(Command),
      'mismatched queued search-done should post');
    Command := nil;
    Check(Actor.ProcessCommands = 1,
      'mismatched queued search-done should process');
    Check(Actor.SearchState(Search, State),
      'mismatched queued search-done should leave search available');
    Check(State = gssActive,
      'mismatched queued search-done should leave search active');

    Command := Actor.CreateSearchDoneCommand(Search, '18-23');
    Check(Actor.PostCommand(Command), 'queued search-done should post');
    Command := nil;
    Check(Actor.ProcessCommands = 1,
      'queued search-done should process');
    Check(Actor.SearchResult(Search, ResultNodeId, ResultMove),
      'queued search-done should store result');
    Check(ResultNodeId = Actor.GameTree.MainlineNode[1].NodeId,
      'queued search-done should keep searched node id');
    Check(ResultMove = '18-23',
      'queued search-done should keep move text');

    Command := Actor.CreateReleaseSearchCommand(Search);
    Check(Actor.PostCommand(Command), 'queued release-search should post');
    Command := nil;
    Check(Actor.ProcessCommands = 1,
      'queued release-search should process');
    Check(not Actor.SearchState(Search, State),
      'queued release-search should remove done search');

    Command := Actor.CreateAppendMainlineMoveCommand('18-23', gmsHuman);
    Check(Actor.PostCommand(Command),
      'observed queued append command should post');
    Command := nil;
    Command := Actor.CreateAppendMainlineMoveCommand('41-37', gmsHuman);
    Command.GameTreeId := Command.GameTreeId + 1;
    Check(Actor.PostCommand(Command),
      'observed rejected queued append command should post');
    Command := nil;
    Check(Actor.ProcessCommands(@Observer.Observe) = 2,
      'observed queued commands should process');
    Check(Observer.AcceptedCount = 1,
      'queued observer should see accepted command');
    Check(Observer.RejectedCount = 1,
      'queued observer should see rejected command');
    Check(Observer.TreeChangedCount = 1,
      'queued observer should see tree-changing command');
  finally
    Observer.Free;
    Actor.Free;
  end;
end;

procedure CheckQueuedSearchAnswerRejectedAfterTargetMutation;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  ResultMove: string;
  ResultNodeId: Int64;
  Search: TGameTreeSearchRef;
  State: TGameTreeSearchState;
begin
  Actor := TGameTreeActor.Create;
  try
    Actor.GameTree.BeginRebuild('queued-search-target', 'Event', 'White',
      'Black', '*', 'W:W31-50:B1-20');

    Command := Actor.CreateAddMainlineMoveCommand(1, '32-28', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'queued target setup move should be accepted');
    finally
      Command.Free;
    end;

    Command := Actor.CreateStartSearchCommand(
      Actor.GameTree.MainlineNode[1].NodeId, Search);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'queued target setup search should be accepted');
    finally
      Command.Free;
    end;

    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('queued-search-target-rebuild', 'Event', 'White',
        'Black', '*', 'W:W31-50:B1-20', False, DefaultTimeControl),
      GameTreeMainlineInput(nil, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''),
      GameTreePvInput(False, 0, '', ''));
    Check(Actor.PostCommand(Command),
      'queued target rebuild should post');
    Command := nil;

    Command := Actor.CreateSearchDoneCommand(Search, '18-23');
    Check(Actor.PostCommand(Command),
      'queued late search answer should post');
    Command := nil;

    Check(Actor.ProcessCommands = 2,
      'queued target rebuild and late answer should process');
    Check(Actor.SearchState(Search, State),
      'queued target rebuild should leave search queryable');
    Check(State = gssFailed,
      'queued target rebuild should fail active search');
    Check(not Actor.SearchResult(Search, ResultNodeId, ResultMove),
      'queued late answer should not create a search result');
  finally
    Actor.Free;
  end;
end;

procedure CheckSearchLifecycle;
var
  Actor: TGameTreeActor;
  CancelCommand: TGameTreeCommand;
  DoneCommand: TGameTreeCommand;
  MoveCommand: TGameTreeCommand;
  ReleaseCommand: TGameTreeCommand;
  ResultMove: string;
  ResultNodeId: Int64;
  BadSearch: TGameTreeSearchRef;
  Search: TGameTreeSearchRef;
  SearchId: Int64;
  StartCommand: TGameTreeCommand;
  State: TGameTreeSearchState;
begin
  Actor := TGameTreeActor.Create;
  try
    Actor.GameTree.BeginRebuild('search', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    MoveCommand := Actor.CreateAddMainlineMoveCommand(1, '32-28', gmsHuman);
    try
      Actor.ExecuteCommand(MoveCommand);
      Check(MoveCommand.Accepted, 'setup move command should be accepted');

      StartCommand := Actor.CreateStartSearchCommand(MoveCommand.CreatedNodeId,
        Search);
      try
        Actor.ExecuteCommand(StartCommand);
        Check(StartCommand.Accepted, 'start-search command should be accepted');
        Check(not StartCommand.TreeChanged,
          'start-search command should not report tree change');
        SearchId := Search.SearchId;
        Check(Actor.SearchState(SearchId, State), 'search state should exist');
        Check(State = gssActive, 'search should be active');
        Check(Actor.SearchState(Search, State),
          'search state should accept matching search ref');
        BadSearch := Search;
        BadSearch.NodeId := BadSearch.NodeId + 1;
        Check(not Actor.SearchState(BadSearch, State),
          'search state should reject mismatched search ref');
      finally
        StartCommand.Free;
      end;

      CancelCommand := Actor.CreateCancelSearchCommand(Search);
      try
        CancelCommand.NodeId := CancelCommand.NodeId + 1;
        Actor.ExecuteCommand(CancelCommand);
        Check(not CancelCommand.Accepted,
          'cancel with mismatched search ref should be rejected');
        Check(Actor.SearchState(Search, State),
          'mismatched cancel should leave search available');
        Check(State = gssActive,
          'mismatched cancel should leave search active');
      finally
        CancelCommand.Free;
      end;

      ReleaseCommand := Actor.CreateReleaseSearchCommand(Search);
      try
        Actor.ExecuteCommand(ReleaseCommand);
        Check(not ReleaseCommand.Accepted,
          'active search release should be rejected');
        Check(Actor.SearchState(SearchId, State),
          'active search should still exist after rejected release');
        Check(State = gssActive,
          'rejected release should keep search active');
      finally
        ReleaseCommand.Free;
      end;

      DoneCommand := Actor.CreateSearchDoneCommand(SearchId, '18-23');
      try
        DoneCommand.GameTreeId := DoneCommand.GameTreeId + 1;
        Actor.ExecuteCommand(DoneCommand);
        Check(not DoneCommand.Accepted,
          'wrong-tree search-id done should be rejected');
        Check(Actor.SearchState(Search, State),
          'wrong-tree search-id done should leave search available');
        Check(State = gssActive,
          'wrong-tree search-id done should leave search active');
      finally
        DoneCommand.Free;
      end;

      CancelCommand := Actor.CreateCancelSearchCommand(Search);
      try
        Actor.ExecuteCommand(CancelCommand);
        Check(CancelCommand.Accepted,
          'cancel-search command should be accepted');
        Check(not CancelCommand.TreeChanged,
          'cancel-search command should not report tree change');
        Check(Actor.SearchState(SearchId, State), 'cancelled search should exist');
        Check(State = gssCancelled, 'search should be cancelled');
      finally
        CancelCommand.Free;
      end;

      DoneCommand := Actor.CreateSearchDoneCommand(Search, '18-23');
      try
        Actor.ExecuteCommand(DoneCommand);
        Check(not DoneCommand.Accepted,
          'late done for cancelled search should be rejected');
        Check(Actor.SearchState(SearchId, State), 'late search should still exist');
        Check(State = gssCancelled,
          'late done should not change cancelled search state');
      finally
        DoneCommand.Free;
      end;

      ReleaseCommand := Actor.CreateReleaseSearchCommand(Search);
      try
        Actor.ExecuteCommand(ReleaseCommand);
        Check(ReleaseCommand.Accepted,
          'cancelled search release should be accepted');
        Check(not ReleaseCommand.TreeChanged,
          'search release command should not report tree change');
        Check(not Actor.SearchState(SearchId, State),
          'released cancelled search should be removed');
      finally
        ReleaseCommand.Free;
      end;

      StartCommand := Actor.CreateStartSearchCommand(MoveCommand.CreatedNodeId,
        Search);
      try
        Actor.ExecuteCommand(StartCommand);
        Check(StartCommand.Accepted,
          'second start-search command should be accepted');
        SearchId := Search.SearchId;
      finally
        StartCommand.Free;
      end;

      DoneCommand := Actor.CreateSearchDoneCommand(Search, '18-23');
      try
        DoneCommand.NodeId := DoneCommand.NodeId + 1;
        Actor.ExecuteCommand(DoneCommand);
        Check(not DoneCommand.Accepted,
          'done with mismatched search ref should be rejected');
        Check(Actor.SearchState(Search, State),
          'mismatched done should leave search available');
        Check(State = gssActive,
          'mismatched done should leave search active');
      finally
        DoneCommand.Free;
      end;

      DoneCommand := Actor.CreateSearchDoneCommand(Search, '18-23');
      try
        Actor.ExecuteCommand(DoneCommand);
        Check(DoneCommand.Accepted,
          'done for active search should be accepted');
        Check(not DoneCommand.TreeChanged,
          'search-done command should not report tree change');
        Check(Actor.SearchState(SearchId, State), 'done search should exist');
        Check(State = gssDone, 'search should be done');
        Check(Actor.SearchResult(SearchId, ResultNodeId, ResultMove),
          'done search result should be available');
        Check(Actor.SearchResult(Search, ResultNodeId, ResultMove),
          'done search result should accept matching search ref');
        Check(ResultNodeId = MoveCommand.CreatedNodeId,
          'done search result should keep target node id');
        Check(ResultMove = '18-23',
          'done search result should keep engine move text');
        BadSearch := Search;
        BadSearch.NodeId := BadSearch.NodeId + 1;
        Check(not Actor.SearchResult(BadSearch, ResultNodeId, ResultMove),
          'done search result should reject mismatched search ref');
      finally
        DoneCommand.Free;
      end;

      ReleaseCommand := Actor.CreateReleaseSearchCommand(Search);
      try
        ReleaseCommand.NodeId := ReleaseCommand.NodeId + 1;
        Actor.ExecuteCommand(ReleaseCommand);
        Check(not ReleaseCommand.Accepted,
          'release with mismatched search ref should be rejected');
        Check(Actor.SearchState(Search, State),
          'mismatched release should leave search available');
        Check(State = gssDone,
          'mismatched release should leave done search state');
      finally
        ReleaseCommand.Free;
      end;

      DoneCommand := Actor.CreateSearchDoneCommand(Search, '20-24');
      try
        Actor.ExecuteCommand(DoneCommand);
        Check(not DoneCommand.Accepted,
          'second done for completed search should be rejected');
        Check(Actor.SearchResult(SearchId, ResultNodeId, ResultMove),
          'original done search result should still be available');
        Check(ResultMove = '18-23',
          'rejected second done should not overwrite result move');
      finally
        DoneCommand.Free;
      end;

      ReleaseCommand := Actor.CreateReleaseSearchCommand(Search);
      try
        Actor.ExecuteCommand(ReleaseCommand);
        Check(ReleaseCommand.Accepted,
          'done search release should be accepted');
        Check(not ReleaseCommand.TreeChanged,
          'done search release should not report tree change');
        Check(not Actor.SearchState(SearchId, State),
          'released done search should be removed');
      finally
        ReleaseCommand.Free;
      end;
    finally
      MoveCommand.Free;
    end;
  finally
    Actor.Free;
  end;
end;

procedure CheckSearchAnswerRejectedAfterTargetRebuild;
var
  Actor: TGameTreeActor;
  DoneCommand: TGameTreeCommand;
  Moves: TStringList;
  RebuildCommand: TGameTreeCommand;
  ReleaseCommand: TGameTreeCommand;
  ResultMove: string;
  ResultNodeId: Int64;
  Search: TGameTreeSearchRef;
  StartCommand: TGameTreeCommand;
  State: TGameTreeSearchState;
begin
  Actor := TGameTreeActor.Create;
  Moves := TStringList.Create;
  try
    Actor.GameTree.BeginRebuild('search-rebuild', 'Event', 'White', 'Black',
      '*', 'W:W31-50:B1-20');
    Actor.GameTree.RecordMainlineMove(1, '32-28');

    StartCommand := Actor.CreateStartSearchCommand(
      Actor.GameTree.MainlineNode[1].NodeId, Search);
    try
      Actor.ExecuteCommand(StartCommand);
      Check(StartCommand.Accepted,
        'start-search before target rebuild should be accepted');
      Check(Actor.SearchState(Search, State),
        'search before target rebuild should exist');
      Check(State = gssActive,
        'search before target rebuild should be active');
    finally
      StartCommand.Free;
    end;

    Moves.Add('31-27');
    RebuildCommand := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('search-rebuild-different', 'Event', 'White',
        'Black', '*', 'W:W31-50:B1-20', False, DefaultTimeControl),
      GameTreeMainlineInput(Moves, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''),
      GameTreePvInput(False, 0, '', ''));
    try
      Actor.ExecuteCommand(RebuildCommand);
      Check(RebuildCommand.Accepted,
        'rebuild replacing searched target should be accepted');
      Check(RebuildCommand.TreeChanged,
        'rebuild replacing searched target should report tree change');
      Check(Actor.SearchState(Search, State),
        'rebuild replacing searched target should leave search queryable');
      Check(State = gssFailed,
        'rebuild replacing searched target should fail active search');
    finally
      RebuildCommand.Free;
    end;

    DoneCommand := Actor.CreateSearchDoneCommand(Search, '18-23');
    try
      Actor.ExecuteCommand(DoneCommand);
      Check(not DoneCommand.Accepted,
        'search answer for rebuilt-away target should be rejected');
      Check(Actor.SearchState(Search, State),
        'failed search should remain queryable');
      Check(State = gssFailed,
        'search answer for rebuilt-away target should mark search failed');
      Check(not Actor.SearchResult(Search, ResultNodeId, ResultMove),
        'failed search should not expose a result move');
      Check(Actor.GameTree.MainlineCount = 1,
        'rejected stale search answer should not append to tree');
      Check(Actor.GameTree.MainlineNode[1].MoveText = '31-27',
        'rejected stale search answer should preserve rebuilt mainline');
    finally
      DoneCommand.Free;
    end;

    ReleaseCommand := Actor.CreateReleaseSearchCommand(Search);
    try
      Actor.ExecuteCommand(ReleaseCommand);
      Check(ReleaseCommand.Accepted,
        'failed search release should be accepted');
      Check(not ReleaseCommand.TreeChanged,
        'failed search release should not report tree change');
      Check(not Actor.SearchState(Search, State),
        'released failed search should be removed');
    finally
      ReleaseCommand.Free;
    end;
  finally
    Moves.Free;
    Actor.Free;
  end;
end;

procedure CheckAnnotatorPvCommand;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Node: TGameTreePlyNode;
  RevisionAfterPV: Int64;
begin
  Actor := TGameTreeActor.Create;
  try
    Actor.GameTree.BeginRebuild('pv', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    Node := Actor.GameTree.RecordMainlineMove(1, '32-28');
    Check(Node <> nil, 'setup node should exist for PV command');

    Command := Actor.CreateRecordAnnotatorPVCommand(Node.NodeId, '0.12',
      '16-21 37-32', '9', '0.44');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'annotator PV command should be accepted');
      Check(Command.TreeChanged,
        'annotator PV command should report tree change');
      Check(Node.AnnotatorScore = '0.12',
        'annotator PV command should record score on target node');
      Check(Node.AnnotatorPV = '16-21 37-32',
        'annotator PV command should record PV on target node');
      Check(Node.AnnotatorPVDepth = '9',
        'annotator PV command should record depth on target node');
      Check(Node.AnnotatorPVTimeText = '0.44',
        'annotator PV command should record time on target node');
      RevisionAfterPV := Actor.Revision;
    finally
      Command.Free;
    end;

    Command := Actor.CreateRecordAnnotatorPVCommand(Node.NodeId, '0.12',
      '16-21 37-32', '9', '0.44');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'duplicate annotator PV command should be accepted');
      Check(not Command.TreeChanged,
        'duplicate annotator PV command should not report tree change');
      Check(Actor.Revision = RevisionAfterPV,
        'duplicate annotator PV command should not increment revision');
    finally
      Command.Free;
    end;

    Actor.GameTree.RecordMainlineAnnotation(Node.PlyNumber,
      AnnotationWithScore('', 'engine', '0.37'));
    Command := Actor.CreateRecordEnginePVCommand(Node.NodeId, '',
      '18-23 39-33', '11', '1.25');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'engine PV command should be accepted');
      Check(Command.TreeChanged,
        'engine PV command should report tree change');
      Check(Node.EngineScore = '0.37',
        'engine PV command with empty score should preserve move score');
      Check(Node.EnginePV = '18-23 39-33',
        'engine PV command should record PV on target node');
      Check(Node.EnginePVDepth = '11',
        'engine PV command should record depth on target node');
      Check(Node.EnginePVTimeText = '1.25',
        'engine PV command should record time on target node');
      RevisionAfterPV := Actor.Revision;
    finally
      Command.Free;
    end;

    Command := Actor.CreateRecordEnginePVCommand(Node.NodeId, '',
      '18-23 39-33', '11', '1.25');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'duplicate engine PV command should be accepted');
      Check(not Command.TreeChanged,
        'duplicate engine PV command should not report tree change');
      Check(Actor.Revision = RevisionAfterPV,
        'duplicate engine PV command should not increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateRecordEnginePVCommand(999999, '', '18-23');
    try
      Actor.ExecuteCommand(Command);
      Check(not Command.Accepted,
        'engine PV command should reject missing target node');
      Check(not Command.TreeChanged,
        'rejected engine PV command should not report tree change');
    finally
      Command.Free;
    end;

    Command := Actor.CreateRecordAnnotatorPVCommand(999999, '0.20',
      '18-23');
    try
      Actor.ExecuteCommand(Command);
      Check(not Command.Accepted,
        'annotator PV command should reject missing target node');
      Check(not Command.TreeChanged,
        'rejected annotator PV command should not report tree change');
    finally
      Command.Free;
    end;
  finally
    Actor.Free;
  end;
end;

procedure CheckStoreMoveVariationCommand;
var
  Actor: TGameTreeActor;
  Changed: Boolean;
  Command: TGameTreeCommand;
  MainlineNode: TGameTreePlyNode;
  VariationNode: TGameTreePlyNode;
begin
  Actor := TGameTreeActor.Create;
  try
    Actor.GameTree.BeginRebuild('store-move', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    MainlineNode := Actor.GameTree.RecordMainlineMove(1, '32-28');
    Actor.GameTree.RecordMainlineMove(2, '19-23');

    Command := Actor.CreateStoreMoveVariationCommand(MainlineNode.NodeId,
      '18-23', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'direct move variation command should be accepted');
      Check(Command.TreeChanged,
        'direct move variation command should report tree change');
      Check(Command.CreatedNodeId > 0,
        'direct move variation should create first variation');
      Check(Actor.GameTree.BranchPath[0].MovesText = '18-23',
        'direct move variation should store move');
      Check(Actor.GameTree.BranchPath[0].OriginText = 'Human',
        'move variation should store human origin');
      Check(Actor.GameTree.FindNodeById(Command.CreatedNodeId).Parent = MainlineNode,
        'direct move variation must attach to the selected parent node');
      VariationNode := Actor.GameTree.FindBranchNode(0, 1);
      Check(VariationNode <> nil,
        'direct move variation should create visible variation node');
      Check(VariationNode.Parent = MainlineNode,
        'direct move variation node should be child of selected node');
      Check(VariationNode.MoveText = '18-23',
        'direct move variation node should contain stored move');
    finally
      Command.Free;
    end;

    Command := Actor.CreateStoreMoveVariationCommand(VariationNode.NodeId,
      '37-32', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'move variation command from variation node should be accepted');
      Check(Command.TreeChanged,
        'move variation command from variation node should report tree change');
      Check(Command.CreatedNodeId > 0,
        'move variation command should extend existing variation');
      Check(Actor.GameTree.BranchPath[0].MovesText = '18-23 37-32',
        'move variation command should append from materialized variation node');
      Check(Actor.GameTree.FindBranchNode(0, 2) <> nil,
        'extended move variation should materialize second variation node');
    finally
      Command.Free;
    end;

    Command := Actor.CreateStoreMoveVariationCommand(VariationNode.NodeId,
      '38-32', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'move variation replacement from variation node should be accepted');
      Check(Command.TreeChanged,
        'move variation replacement should report tree change');
      Check(Actor.GameTree.BranchPath[0].MovesText = '18-23 37-32',
        'branching inside a variation must preserve its original continuation');
      Check(Actor.GameTree.BranchPath[1].MovesText = '18-23 38-32',
        'alternative continuation should be stored separately');
      VariationNode := Actor.GameTree.FindBranchNode(1, 2);
      Check(VariationNode <> nil,
        'replacement move variation should materialize replacement node');
      Check(VariationNode.MoveText = '38-32',
        'replacement variation node should contain replacement move');
    finally
      Command.Free;
    end;

  finally
    Actor.Free;
  end;
end;

procedure CheckRebuildFromInputsCommand;
var
  Actor: TGameTreeActor;
  Annotations: TStringList;
  Command: TGameTreeCommand;
  EnginePvDepth: string;
  EnginePvTimeText: string;
  Moves: TStringList;
  NodeId: Int64;
  NullTimeControl: TTimeControl;
  RevisionAfterRebuild: Int64;
  Search: TGameTreeSearchRef;
  SearchCommand: TGameTreeCommand;
  VariationPvDepth: string;
  VariationPvTimeText: string;
  VariationIndex: Integer;

  procedure CheckDuplicateRebuildDoesNotMutate(const AMessage: string);
  var
    DuplicateCommand: TGameTreeCommand;
    RevisionBeforeDuplicate: Int64;
  begin
    RevisionBeforeDuplicate := Actor.Revision;
    DuplicateCommand := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('rebuild', 'Event', 'White', 'Black', '*',
        'W:W31-50:B1-20', False, NullTimeControl),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(True, 2, '0.10', '37-32', EnginePvDepth,
        EnginePvTimeText),
      GameTreePvInput(False, 0, '', ''),
      Actor.GameTree.FindBranchNode(0, 1).NodeId, '0.20', '20-24', VariationPvDepth, VariationPvTimeText);
    try
      Actor.ExecuteCommand(DuplicateCommand);
      Check(DuplicateCommand.Accepted, AMessage + ' should be accepted');
      Check(not DuplicateCommand.TreeChanged,
        AMessage + ' should not report tree change');
      Check(Actor.Revision = RevisionBeforeDuplicate,
        AMessage + ' should not increment revision');
    finally
      DuplicateCommand.Free;
    end;
  end;
begin
  Actor := TGameTreeActor.Create;
  Moves := TStringList.Create;
  Annotations := TStringList.Create;
  try
    FillChar(NullTimeControl, SizeOf(NullTimeControl), 0);
    EnginePvDepth := '12';
    EnginePvTimeText := '1.20';
    VariationPvDepth := '7';
    VariationPvTimeText := '0.33';
    Actor.GameTree.BeginRebuild('rebuild', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    Actor.GameTree.RecordMainlineMove(1, '32-28');
    Command := ImportBranch(Actor, 1, '20-24', '', gmsHuman);
    Actor.ExecuteCommand(Command);
    Check(Command.Accepted, 'setup branch must be materialized before rebuilding');
    VariationIndex := 0;
    Command.Free;
    Check(VariationIndex = 0, 'setup variation should be stored');

    Moves.Add('32-28');
    Moves.Add('18-23');
    Annotations.Add('{old}');
    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('rebuild', 'Event', 'White', 'Black', '*',
        'W:W31-50:B1-20', False, NullTimeControl),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(True, 2, '0.10', '37-32', EnginePvDepth,
        EnginePvTimeText),
      GameTreePvInput(False, 0, '', ''),
      Actor.GameTree.FindBranchNode(0, 1).NodeId, '0.20', '20-24', VariationPvDepth, VariationPvTimeText);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'rebuild command should be accepted');
      Check(Command.TreeChanged,
        'rebuild command should report tree change');
      Check(Actor.GameTree.MainlineCount = 2,
        'rebuild command should record mainline count');
      Check(Actor.GameTree.MainlineNode[2].MoveText = '18-23',
        'rebuild command should record second move');
      Check(Actor.GameTree.MainlineNode[2].EnginePV = '37-32',
        'rebuild command should record engine PV');
      Check(Actor.GameTree.MainlineNode[2].EnginePVDepth = EnginePvDepth,
        'rebuild command should record engine PV depth');
      Check(Actor.GameTree.MainlineNode[2].EnginePVTimeText = EnginePvTimeText,
        'rebuild command should record engine PV time');
      Check(Actor.GameTree.BranchCount = 1,
        'rebuild command should preserve stored variation line');
      Check(Actor.GameTree.FindBranchNode(0, 1) <> nil,
        'rebuild command should rebuild variation nodes');
      Check(Actor.GameTree.FindBranchNode(0, 1).AnnotatorPV = '20-24',
        'rebuild command should record variation annotator PV');
      Check(Actor.GameTree.FindBranchNode(0, 1).AnnotatorPVDepth =
        VariationPvDepth,
        'rebuild command should record variation annotator PV depth');
      Check(Actor.GameTree.FindBranchNode(0, 1).AnnotatorPVTimeText =
        VariationPvTimeText,
        'rebuild command should record variation annotator PV time');
      NodeId := Actor.GameTree.MainlineNode[1].NodeId;
      RevisionAfterRebuild := Actor.Revision;
    finally
      Command.Free;
    end;

    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('rebuild', 'Event', 'White', 'Black', '*',
        'W:W31-50:B1-20', False, NullTimeControl),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(True, 2, '0.10', '37-32', EnginePvDepth,
        EnginePvTimeText),
      GameTreePvInput(False, 0, '', ''),
      Actor.GameTree.FindBranchNode(0, 1).NodeId, '0.20', '20-24', VariationPvDepth, VariationPvTimeText);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'duplicate rebuild command should be accepted');
      Check(not Command.TreeChanged,
        'duplicate rebuild command should not report tree change');
      Check(Actor.Revision = RevisionAfterRebuild,
        'duplicate rebuild command should not increment revision');
    finally
      Command.Free;
    end;

    EnginePvDepth := '13';
    EnginePvTimeText := '1.25';
    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('rebuild', 'Event', 'White', 'Black', '*',
        'W:W31-50:B1-20', False, NullTimeControl),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(True, 2, '0.10', '37-32', EnginePvDepth,
        EnginePvTimeText),
      GameTreePvInput(False, 0, '', ''),
      Actor.GameTree.FindBranchNode(0, 1).NodeId, '0.20', '20-24', VariationPvDepth, VariationPvTimeText);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'PV metadata-only rebuild command should be accepted');
      Check(Command.TreeChanged,
        'PV metadata-only rebuild command should report tree change');
      Check(Actor.Revision > RevisionAfterRebuild,
        'PV metadata-only rebuild should increment revision');
      Check(Actor.GameTree.MainlineNode[2].EnginePVDepth = EnginePvDepth,
        'PV metadata-only rebuild should record engine PV depth');
      Check(Actor.GameTree.MainlineNode[2].EnginePVTimeText =
        EnginePvTimeText,
        'PV metadata-only rebuild should record engine PV time');
      RevisionAfterRebuild := Actor.Revision;
    finally
      Command.Free;
    end;

    VariationPvDepth := '8';
    VariationPvTimeText := '0.40';
    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('rebuild', 'Event', 'White', 'Black', '*',
        'W:W31-50:B1-20', False, NullTimeControl),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(True, 2, '0.10', '37-32', EnginePvDepth,
        EnginePvTimeText),
      GameTreePvInput(False, 0, '', ''),
      Actor.GameTree.FindBranchNode(0, 1).NodeId, '0.20', '20-24', VariationPvDepth, VariationPvTimeText);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'variation PV metadata-only rebuild command should be accepted');
      Check(Command.TreeChanged,
        'variation PV metadata-only rebuild command should report tree change');
      Check(Actor.Revision > RevisionAfterRebuild,
        'variation PV metadata-only rebuild should increment revision');
      Check(Actor.GameTree.FindBranchNode(0, 1).AnnotatorPVDepth =
        VariationPvDepth,
        'variation PV metadata-only rebuild should record depth');
      Check(Actor.GameTree.FindBranchNode(0, 1).AnnotatorPVTimeText =
        VariationPvTimeText,
        'variation PV metadata-only rebuild should record time');
      RevisionAfterRebuild := Actor.Revision;
    finally
      Command.Free;
    end;

    SearchCommand := Actor.CreateStartSearchCommand(
      Actor.GameTree.MainlineNode[1].NodeId, Search);
    try
      Actor.ExecuteCommand(SearchCommand);
      Check(SearchCommand.Accepted,
        'start-search after rebuild should be accepted');
    finally
      SearchCommand.Free;
    end;
    CheckDuplicateRebuildDoesNotMutate(
      'duplicate rebuild after start-search');

    SearchCommand := Actor.CreateSearchDoneCommand(Search, '19-23');
    try
      Actor.ExecuteCommand(SearchCommand);
      Check(SearchCommand.Accepted,
        'search-done after rebuild should be accepted');
    finally
      SearchCommand.Free;
    end;
    CheckDuplicateRebuildDoesNotMutate(
      'duplicate rebuild after search-done');

    SearchCommand := Actor.CreateReleaseSearchCommand(Search);
    try
      Actor.ExecuteCommand(SearchCommand);
      Check(SearchCommand.Accepted,
        'release-search after rebuild should be accepted');
    finally
      SearchCommand.Free;
    end;
    CheckDuplicateRebuildDoesNotMutate(
      'duplicate rebuild after search lifecycle');

    Moves[1] := '20-24';
    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('rebuild', 'Event', 'White', 'Black', '*',
        'W:W31-50:B1-20', False, NullTimeControl),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''),
      GameTreePvInput(False, 0, '', ''));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'second rebuild command should be accepted');
      Check(Command.TreeChanged,
        'second rebuild command should report tree change');
      Check(Actor.GameTree.MainlineNode[1].NodeId = NodeId,
        'unchanged rebuilt node id should stay stable');
      Check(Actor.GameTree.MainlineNode[2].MoveText = '20-24',
        'changed rebuilt move should be applied');
    finally
      Command.Free;
    end;
  finally
    Annotations.Free;
    Moves.Free;
    Actor.Free;
  end;
end;

procedure CheckAutoPlayPvCommand;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Node: TGameTreePlyNode;
begin
  Actor := TGameTreeActor.Create;
  try
    Actor.GameTree.BeginRebuild('auto-play', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    Node := Actor.GameTree.Root;

    Command := Actor.CreateRecordAutoPlayPVCommand(Node.NodeId, '32-28');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'Auto Play PV should be accepted');
      Check(Command.TreeChanged, 'Auto Play PV should change tree');
      Check(Node.AutoPlayPV = '32-28',
        'Auto Play PV should be stored on its analysis node');
      Check(Node.ChildCount = 0,
        'Auto Play PV should not create structural move nodes');
    finally
      Command.Free;
    end;

    Command := Actor.CreateRecordAutoPlayPVCommand(Node.NodeId,
      '32-28 19-23');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'Auto Play PV extension should be accepted');
      Check(Node.AutoPlayPV = '32-28 19-23',
        'Auto Play PV extension should replace the analysis value');
      Check(Node.ChildCount = 0,
        'Auto Play PV extension should not create structural move nodes');
    finally
      Command.Free;
    end;
  finally
    Actor.Free;
  end;
end;

procedure CheckRestoreNodeData;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Data: TGameTreeNodeData;
  Rev: Int64;
begin
  Actor := TGameTreeActor.Create;
  try
    Data := Default(TGameTreeNodeData);
    Data.CommentText := 'restored'; Data.EnginePV := '32-28';
    Command := Actor.CreateRestoreNodeDataCommand(Actor.GameTree.Root.NodeId, Data);
    Data.CommentText := 'changed caller';
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'valid node metadata accepted');
      Check(Actor.GameTree.Root.CommentText = 'restored', 'command owns metadata copy');
    finally Command.Free; end;
    Rev := Actor.Revision;
    Command := Actor.CreateRestoreNodeDataCommand(-1, Data);
    try Actor.ExecuteCommand(Command); Check(not Command.Accepted, 'missing target rejected');
    finally Command.Free; end;
    Data.SecondsUsed := NaN;
    Command := Actor.CreateRestoreNodeDataCommand(Actor.GameTree.Root.NodeId, Data);
    try Actor.ExecuteCommand(Command); Check(not Command.Accepted, 'nonfinite clocks rejected');
    finally Command.Free; end;
    Check(Actor.Revision = Rev, 'rejected metadata leaves tree unchanged');
  finally Actor.Free; end;
end;

begin
  CheckRestoreNodeData;
  CheckFreshGameTreeDefaults;
  CheckActorCommands;
  CheckQueuedActorCommands;
  CheckQueuedSearchAnswerRejectedAfterTargetMutation;
  CheckSearchLifecycle;
  CheckSearchAnswerRejectedAfterTargetRebuild;
  CheckAnnotatorPvCommand;
  CheckStoreMoveVariationCommand;
  CheckAutoPlayPvCommand;
  CheckRebuildFromInputsCommand;
  Writeln('OK');
end.
