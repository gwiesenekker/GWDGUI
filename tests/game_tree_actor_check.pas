program game_tree_actor_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils,
  uGameTree, uGameTreeActor;

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
  Node: TGameTreePlyNode;
begin
  Actor := TGameTreeActor.Create;
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

    Command := Actor.CreateStoreVariationLineCommand(2, 1, '18-23', '',
      gmsAutorandom);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'store-variation command should be accepted');
      Check(Command.VariationIndex = 0,
        'first variation should get variation index 0');
      Check(Actor.GameTree.VariationLineCount = 1,
        'variation should be stored on game tree');
      Check(Actor.Revision = 3, 'third mutation should increment revision');
    finally
      Command.Free;
    end;

    Command := Actor.CreateClearStoredVariationsCommand;
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'clear-variations command should be accepted');
      Check(Actor.GameTree.VariationLineCount = 0,
        'clear-variations command should remove stored variations');
      Check(Actor.Revision = 4, 'clear mutation should increment revision');
    finally
      Command.Free;
    end;
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
  ResultMove: string;
  ResultNodeId: Int64;
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
        SearchId);
      try
        Actor.ExecuteCommand(StartCommand);
        Check(StartCommand.Accepted, 'start-search command should be accepted');
        Check(Actor.SearchState(SearchId, State), 'search state should exist');
        Check(State = gssActive, 'search should be active');
      finally
        StartCommand.Free;
      end;

      CancelCommand := Actor.CreateCancelSearchCommand(SearchId);
      try
        Actor.ExecuteCommand(CancelCommand);
        Check(CancelCommand.Accepted,
          'cancel-search command should be accepted');
        Check(Actor.SearchState(SearchId, State), 'cancelled search should exist');
        Check(State = gssCancelled, 'search should be cancelled');
      finally
        CancelCommand.Free;
      end;

      DoneCommand := Actor.CreateSearchDoneCommand(SearchId, '18-23');
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

      StartCommand := Actor.CreateStartSearchCommand(MoveCommand.CreatedNodeId,
        SearchId);
      try
        Actor.ExecuteCommand(StartCommand);
        Check(StartCommand.Accepted,
          'second start-search command should be accepted');
      finally
        StartCommand.Free;
      end;

      DoneCommand := Actor.CreateSearchDoneCommand(SearchId, '18-23');
      try
        Actor.ExecuteCommand(DoneCommand);
        Check(DoneCommand.Accepted,
          'done for active search should be accepted');
        Check(Actor.SearchState(SearchId, State), 'done search should exist');
        Check(State = gssDone, 'search should be done');
        Check(Actor.SearchResult(SearchId, ResultNodeId, ResultMove),
          'done search result should be available');
        Check(ResultNodeId = MoveCommand.CreatedNodeId,
          'done search result should keep target node id');
        Check(ResultMove = '18-23',
          'done search result should keep engine move text');
      finally
        DoneCommand.Free;
      end;

      DoneCommand := Actor.CreateSearchDoneCommand(SearchId, '20-24');
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
begin
  Actor := TGameTreeActor.Create;
  try
    Actor.GameTree.BeginRebuild('pv', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    Node := Actor.GameTree.RecordMainlineMove(1, '32-28');
    Check(Node <> nil, 'setup node should exist for PV command');

    Command := Actor.CreateRecordAnnotatorPVCommand(Node.NodeId, '0.12',
      '16-21 37-32');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'annotator PV command should be accepted');
      Check(Node.AnnotatorScore = '0.12',
        'annotator PV command should record score on target node');
      Check(Node.AnnotatorPV = '16-21 37-32',
        'annotator PV command should record PV on target node');
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
  SearchId: Int64;
  StartCommand: TGameTreeCommand;
  StoreCommand: TGameTreeCommand;
  VariationIndex: Integer;
  VariationNode: TGameTreePlyNode;
begin
  Actor := TGameTreeActor.Create;
  try
    Actor.GameTree.BeginRebuild('store-search', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');

    StartCommand := Actor.CreateStartSearchCommand(Actor.GameTree.Root.NodeId,
      SearchId);
    try
      Actor.ExecuteCommand(StartCommand);
      Check(StartCommand.Accepted, 'root search should start');
    finally
      StartCommand.Free;
    end;

    DoneCommand := Actor.CreateSearchDoneCommand(SearchId, '31-26');
    try
      Actor.ExecuteCommand(DoneCommand);
      Check(DoneCommand.Accepted, 'root search done should be accepted');
    finally
      DoneCommand.Free;
    end;

    StoreCommand := Actor.CreateStoreSearchMoveVariationCommand(SearchId,
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
      SearchId);
    try
      Actor.ExecuteCommand(StartCommand);
      Check(StartCommand.Accepted, 'variation search should start');
    finally
      StartCommand.Free;
    end;

    DoneCommand := Actor.CreateSearchDoneCommand(SearchId, '20-24');
    try
      Actor.ExecuteCommand(DoneCommand);
      Check(DoneCommand.Accepted, 'variation search done should be accepted');
    finally
      DoneCommand.Free;
    end;

    StoreCommand := Actor.CreateStoreSearchMoveVariationCommand(SearchId,
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

begin
  CheckActorCommands;
  CheckSearchLifecycle;
  CheckAnnotatorPvCommand;
  CheckStoreSearchMoveVariationCommand;
  CheckStoreMoveVariationCommand;
  Writeln('OK');
end.
