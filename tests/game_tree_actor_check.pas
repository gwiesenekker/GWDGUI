program game_tree_actor_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils,
  uGameTree, uGameTreeActor, uGameTreeBuilder, uGameTreeSearchRef, uPdn,
  uGameOrchestrator;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    Writeln('FAIL: ', AMessage);
    Halt(1);
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
      Check(Actor.Revision = 1,
        'wrong game-tree command should not increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateAppendMainlineMoveCommand('31-27', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'append-mainline command should be accepted');
      Check(Command.PlyNumber = 2,
        'append-mainline command should report appended ply');
      Check(Command.NodeId = Command.CreatedNodeId,
        'append-mainline command should report created node id');
      Node := Actor.GameTree.FindNodeById(Command.NodeId);
      Check(Node <> nil, 'appended node id should resolve');
      Check(Node.MoveText = '31-27', 'appended node should contain move');
    finally
      Command.Free;
    end;

    Command := Actor.CreateAppendMainlineSnapshotMoveCommand(
      GameTreeHeaderInput('snapshot', 'Match', 'Engine A', 'Engine B', '*',
        'W:W31-50:B1-20', True, DefaultTimeControl),
      '18-23', AnnotationWithScore('', 'engine', '0.37'),
      GameTreeMainlineInput(nil, nil, True, 299.0, 298.0, 1.0, 2.0),
      GameTreePvInput(True, 3, '0.37', '38-33', '8', '0.21'),
      gmsEngineMatch);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'append snapshot move command should be accepted');
      Check(Command.PlyNumber = 3,
        'append snapshot move should report appended ply');
      Node := Actor.GameTree.MainlineNode[3];
      Check(Node <> nil, 'snapshot appended node should exist');
      Check(Node.MoveText = '18-23',
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
      Check(Actor.GameTree.MainlineNode[3].EnginePV = '38-33',
        'snapshot append should record engine PV');
    finally
      Command.Free;
    end;

    Command := Actor.CreateStoreVariationLineCommand(2, 1, '18-23',
      'annotator=0.22', gmsAutorandom);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'store-variation command should be accepted');
      Check(Command.VariationIndex = 0,
        'first variation should get variation index 0');
      Check(Actor.GameTree.VariationLineCount = 1,
        'variation should be stored on game tree');
      Check(Actor.GameTree.VariationLine[0].AnnotationText = 'annotator=0.22',
        'variation should store annotation text on game tree');
      Check(Actor.Revision = 4, 'fourth mutation should increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateStoreVariationLineCommand(2, 1, '18-23', '',
      gmsAutorandom);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'empty variation update should be accepted');
      Check(Actor.GameTree.VariationLine[0].AnnotationText = 'annotator=0.22',
        'empty variation update should not clear annotation text');
      Check(Actor.Revision = 4,
        'unchanged variation update should not increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateClearStoredVariationsCommand;
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'clear-variations command should be accepted');
      Check(Actor.GameTree.VariationLineCount = 0,
        'clear-variations command should remove stored variations');
      Check(Actor.Revision = 5, 'clear mutation should increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateClearStoredVariationsCommand;
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'empty clear-variations command should be accepted');
      Check(Actor.Revision = 5,
        'empty clear-variations command should not increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateStoreVariationLineCommand(2, 1, '18-23',
      'annotator=0.22', gmsAutorandom);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'setup variation before rebuild should be accepted');
      Check(Actor.GameTree.VariationLineCount = 1,
        'setup variation should be stored before rebuild');
      Check(Actor.GameTree.VariationLine[0].AnnotationText = 'annotator=0.22',
        'setup variation should store annotation text before rebuild');
    finally
      Command.Free;
    end;

    Moves.Clear;
    Moves.Add('32-28');
    Moves.Add('31-27');
    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('actor-rebuild-new-signature', 'Event', 'White',
        'Black', '*', 'W:W31-50:B1-20', False, DefaultTimeControl),
      GameTreeMainlineInput(Moves, EmptyAnnotations, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', ''));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'rebuild with different signature should be accepted');
      Check(Actor.GameTree.VariationLineCount = 1,
        'rebuild should preserve stored variation lines');
      VariationNode := Actor.GameTree.FindVariationNode(0, 1);
      Check(VariationNode <> nil,
        'rebuild should recreate stored variation node');
      Check(VariationNode.MoveText = '18-23',
        'recreated variation node should contain stored move');
      Check(Actor.GameTree.VariationLine[0].AnnotationText = 'annotator=0.22',
        'rebuild should preserve stored variation annotation text');
      Check(VariationNode.AnnotatorScore = '0.22',
        'recreated variation node should preserve stored annotation');
    finally
      Command.Free;
    end;

    Command := Actor.CreateSetHeaderCommand(
      GameTreeHeaderInput('', 'New Event', 'Alice', 'Bob', '1-0',
        'W:W31-50:B1-20', False, DefaultTimeControl));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'set-header command should be accepted');
      Check(Actor.GameTree.EventName = 'New Event',
        'set-header command should update event');
      Check(Actor.GameTree.WhiteName = 'Alice',
        'set-header command should update white name');
      Check(Actor.GameTree.BlackName = 'Bob',
        'set-header command should update black name');
      Check(Actor.GameTree.ResultText = '1-0',
        'set-header command should update result');
      RevisionAfterHeader := Actor.Revision;
    finally
      Command.Free;
    end;

    Command := Actor.CreateSetHeaderCommand(
      GameTreeHeaderInput('', 'New Event', 'Alice', 'Bob', '1-0',
        'W:W31-50:B1-20', False, DefaultTimeControl));
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'duplicate set-header command should be accepted');
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
  ResultMove: string;
  ResultNodeId: Int64;
  Search: TGameTreeSearchRef;
  State: TGameTreeSearchState;
begin
  Actor := TGameTreeActor.Create;
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

      CancelCommand := Actor.CreateCancelSearchCommand(Search);
      try
        Actor.ExecuteCommand(CancelCommand);
        Check(CancelCommand.Accepted,
          'cancel-search command should be accepted');
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
    finally
      Command.Free;
    end;

    Command := Actor.CreateRecordAnnotatorPVCommand(999999, '0.20',
      '18-23');
    try
      Actor.ExecuteCommand(Command);
      Check(not Command.Accepted,
        'annotator PV command should reject missing target node');
    finally
      Command.Free;
    end;
  finally
    Actor.Free;
  end;
end;

procedure CheckStoreSearchMoveVariationCommand;
var
  Actor: TGameTreeActor;
  DoneCommand: TGameTreeCommand;
  MainlineNode: TGameTreePlyNode;
  Search: TGameTreeSearchRef;
  StartCommand: TGameTreeCommand;
  StoreCommand: TGameTreeCommand;
  RevisionAfterStore: Int64;
  VariationIndex: Integer;
  VariationNode: TGameTreePlyNode;
begin
  Actor := TGameTreeActor.Create;
  try
    Actor.GameTree.BeginRebuild('store-search', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');

    StartCommand := Actor.CreateStartSearchCommand(Actor.GameTree.Root.NodeId,
      Search);
    try
      Actor.ExecuteCommand(StartCommand);
      Check(StartCommand.Accepted, 'root search should start');
    finally
      StartCommand.Free;
    end;

    DoneCommand := Actor.CreateSearchDoneCommand(Search, '31-26');
    try
      Actor.ExecuteCommand(DoneCommand);
      Check(DoneCommand.Accepted, 'root search done should be accepted');
    finally
      DoneCommand.Free;
    end;

    StoreCommand := Actor.CreateStoreSearchMoveVariationCommand(Search,
      gmsAutoplay);
    try
      StoreCommand.NodeId := StoreCommand.NodeId + 1;
      Actor.ExecuteCommand(StoreCommand);
      Check(not StoreCommand.Accepted,
        'store search variation with mismatched ref should be rejected');
      Check(Actor.GameTree.VariationLineCount = 0,
        'mismatched store should not add a variation');
    finally
      StoreCommand.Free;
    end;

    StoreCommand := Actor.CreateStoreSearchMoveVariationCommand(Search,
      gmsAutoplay);
    try
      Actor.ExecuteCommand(StoreCommand);
      Check(StoreCommand.Accepted,
        'root search result should store as variation');
      Check(StoreCommand.VariationIndex = 0,
        'root search result should create first variation');
      Check(Actor.GameTree.VariationLine[0].BasePly = 0,
        'root search variation should have base ply 0');
      Check(Actor.GameTree.VariationLine[0].MovesText = '31-26',
        'root search variation should store result move');
      RevisionAfterStore := Actor.Revision;
    finally
      StoreCommand.Free;
    end;

    StoreCommand := Actor.CreateStoreSearchMoveVariationCommand(Search,
      gmsAutoplay);
    try
      Actor.ExecuteCommand(StoreCommand);
      Check(StoreCommand.Accepted,
        'duplicate root search variation store should be accepted');
      Check(Actor.Revision = RevisionAfterStore,
        'duplicate root search variation store should not increment revision');
    finally
      StoreCommand.Free;
    end;

    MainlineNode := Actor.GameTree.RecordMainlineMove(1, '32-28');
    VariationIndex := Actor.GameTree.StoreVariationLine(1, 1,
      '18-23 37-32', '');
    VariationNode := Actor.GameTree.RecordVariationMove(MainlineNode, 1, 1,
      VariationIndex, 1, '18-23');
    Check(VariationNode <> nil, 'variation node should exist for search');

    StartCommand := Actor.CreateStartSearchCommand(VariationNode.NodeId,
      Search);
    try
      Actor.ExecuteCommand(StartCommand);
      Check(StartCommand.Accepted, 'variation search should start');
    finally
      StartCommand.Free;
    end;

    DoneCommand := Actor.CreateSearchDoneCommand(Search, '20-24');
    try
      Actor.ExecuteCommand(DoneCommand);
      Check(DoneCommand.Accepted, 'variation search done should be accepted');
    finally
      DoneCommand.Free;
    end;

    StoreCommand := Actor.CreateStoreSearchMoveVariationCommand(Search,
      gmsAutoplay);
    try
      Actor.ExecuteCommand(StoreCommand);
      Check(StoreCommand.Accepted,
        'variation search result should store as variation');
      Check(StoreCommand.VariationIndex = VariationIndex,
        'variation search should update the same variation line');
      Check(Actor.GameTree.VariationLine[VariationIndex].MovesText =
        '18-23 20-24',
        'variation search should append after searched variation prefix');
      Check(StoreCommand.PlyNumber = 2,
        'variation search command should report resulting variation ply');
    finally
      StoreCommand.Free;
    end;
  finally
    Actor.Free;
  end;
end;

procedure CheckStoreMoveVariationCommand;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  MainlineNode: TGameTreePlyNode;
  RevisionAfterStore: Int64;
  VariationIndex: Integer;
  VariationNode: TGameTreePlyNode;
begin
  Actor := TGameTreeActor.Create;
  try
    Actor.GameTree.BeginRebuild('store-move', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    MainlineNode := Actor.GameTree.RecordMainlineMove(1, '32-28');

    Command := Actor.CreateStoreMoveVariationCommand(MainlineNode.NodeId,
      '18-23', gmsAutorandom);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'direct move variation command should be accepted');
      Check(Command.VariationIndex = 0,
        'direct move variation should create first variation');
      Check(Actor.GameTree.VariationLine[0].MovesText = '18-23',
        'direct move variation should store move');
      RevisionAfterStore := Actor.Revision;
    finally
      Command.Free;
    end;

    Command := Actor.CreateStoreMoveVariationCommand(MainlineNode.NodeId,
      '18-23', gmsAutorandom);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'duplicate direct move variation command should be accepted');
      Check(Actor.Revision = RevisionAfterStore,
        'duplicate direct move variation should not increment revision');
    finally
      Command.Free;
    end;

    VariationIndex := 0;
    VariationNode := Actor.GameTree.RecordVariationMove(MainlineNode, 1, 1,
      VariationIndex, 1, '18-23');
    Check(VariationNode <> nil, 'variation node should exist for direct append');

    Command := Actor.CreateStoreMoveVariationCommand(VariationNode.NodeId,
      '20-24', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted,
        'direct move from variation node should be accepted');
      Check(Actor.GameTree.VariationLine[VariationIndex].MovesText =
        '18-23 20-24',
        'direct move from variation node should append to variation line');
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
  Moves: TStringList;
  NodeId: Int64;
  NullTimeControl: TTimeControl;
  RevisionAfterRebuild: Int64;
  Search: TGameTreeSearchRef;
  SearchCommand: TGameTreeCommand;
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
      GameTreePvInput(True, 2, '0.10', '37-32'),
      GameTreePvInput(False, 0, '', ''),
      0, 1, '0.20', '20-24');
    try
      Actor.ExecuteCommand(DuplicateCommand);
      Check(DuplicateCommand.Accepted, AMessage + ' should be accepted');
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
    Actor.GameTree.BeginRebuild('rebuild', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    Actor.GameTree.RecordMainlineMove(1, '32-28');
    VariationIndex := Actor.GameTree.StoreVariationLine(2, 1, '18-23', '');
    Check(VariationIndex = 0, 'setup variation should be stored');

    Moves.Add('32-28');
    Moves.Add('18-23');
    Annotations.Add('{old}');
    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('rebuild', 'Event', 'White', 'Black', '*',
        'W:W31-50:B1-20', False, NullTimeControl),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(True, 2, '0.10', '37-32'),
      GameTreePvInput(False, 0, '', ''),
      0, 1, '0.20', '20-24');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'rebuild command should be accepted');
      Check(Actor.GameTree.MainlineCount = 2,
        'rebuild command should record mainline count');
      Check(Actor.GameTree.MainlineNode[2].MoveText = '18-23',
        'rebuild command should record second move');
      Check(Actor.GameTree.MainlineNode[2].EnginePV = '37-32',
        'rebuild command should record engine PV');
      Check(Actor.GameTree.VariationLineCount = 1,
        'rebuild command should preserve stored variation line');
      Check(Actor.GameTree.FindVariationNode(0, 1) <> nil,
        'rebuild command should rebuild variation nodes');
      Check(Actor.GameTree.FindVariationNode(0, 1).AnnotatorPV = '20-24',
        'rebuild command should record variation annotator PV');
      NodeId := Actor.GameTree.MainlineNode[1].NodeId;
      RevisionAfterRebuild := Actor.Revision;
    finally
      Command.Free;
    end;

    Command := Actor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('rebuild', 'Event', 'White', 'Black', '*',
        'W:W31-50:B1-20', False, NullTimeControl),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(True, 2, '0.10', '37-32'),
      GameTreePvInput(False, 0, '', ''),
      0, 1, '0.20', '20-24');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'duplicate rebuild command should be accepted');
      Check(Actor.Revision = RevisionAfterRebuild,
        'duplicate rebuild command should not increment revision');
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

begin
  CheckActorCommands;
  CheckQueuedActorCommands;
  CheckSearchLifecycle;
  CheckAnnotatorPvCommand;
  CheckStoreSearchMoveVariationCommand;
  CheckStoreMoveVariationCommand;
  CheckRebuildFromInputsCommand;
  Writeln('OK');
end.
