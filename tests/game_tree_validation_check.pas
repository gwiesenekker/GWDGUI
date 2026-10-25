program game_tree_validation_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uGameTree, uGameTreeActor, uGameTreeBuilder,
  uGameTreePdn, uGameOrchestrator, uDraughtsBoard, uTreeTestUtils;
procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
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
procedure RejectUnchanged(Actor: TGameTreeActor; Command: TGameTreeCommand);
var
  BeforeText: string;
  Revision, RootId: Int64;
begin
  BeforeText := GameTreeToPdnText(Actor.GameTree);
  Revision := Actor.Revision;
  RootId := Actor.GameTree.Root.NodeId;
  try
    Actor.ExecuteCommand(Command);
    Check(not Command.Accepted, 'invalid command was accepted');
    Check((Command.ErrorText <> '') and not Command.TreeChanged,
      'rejection must explain the error without reporting a mutation');
    Check((Actor.Revision = Revision) and
      (Actor.GameTree.Root.NodeId = RootId) and
      (GameTreeToPdnText(Actor.GameTree) = BeforeText),
      'rejected command must preserve headers, nodes, annotations and revision');
  finally
    Command.Free;
  end;
end;
procedure CheckTypedBranchImport;
var
  Actor: TGameTreeActor;
  Data: TGameTreeImportMoves;
  Command: TGameTreeCommand;
  ParentId: Int64;
  Node: TGameTreePlyNode;
begin
  Actor := TGameTreeActor.Create;
  try
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('32-28', gmsHuman));
    ParentId := Actor.GameTree.MainlineNode[1].NodeId;
    Data := nil;
    RejectUnchanged(Actor, Actor.CreateImportBranchCommand(ParentId, Data));
    SetLength(Data, 2);
    Data[0].MoveText := '20-24';
    Data[0].AnnotationText := '@pdn-annotations:literal';
    Data[1].MoveText := '46-41';
    RejectUnchanged(Actor, Actor.CreateImportBranchCommand(ParentId, Data));
    Check(Actor.GameTree.BranchCount = 0, 'late invalid move must not leak a valid prefix');
    Data[1].MoveText := '38-32';
    Data[1].AnnotationText := 'Inner comment';
    Command := Actor.CreateImportBranchCommand(ParentId, Data);
    Data[0].MoveText := '1-50';
    Data[1].AnnotationText := 'Changed source';
    Execute(Actor, Command);
    Node := Actor.GameTree.FindChildByMove(Actor.GameTree.MainlineNode[1], '20-24');
    Check((Node.CommentText = '@pdn-annotations:literal') and
      (Node.Children[0].CommentText = 'Inner comment'),
      'typed command must own its move/annotation records and preserve literal comments');
  finally Actor.Free; end;
end;

procedure CheckLiteralNodeImport;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  ParentId, ChildId: Int64;
begin
  Actor := TGameTreeActor.Create;
  try
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('32-28', gmsHuman));
    ParentId := Actor.GameTree.MainlineNode[1].NodeId;
    RejectUnchanged(Actor, Actor.CreateImportNodeCommand(ParentId, '20-24 38-32', 'bad'));
    RejectUnchanged(Actor, Actor.CreateImportNodeCommand(High(Int64), '20-24', 'bad'));
    RejectUnchanged(Actor, Actor.CreateImportNodeCommand(ParentId, '1-50', 'bad'));
    Command := Actor.CreateImportNodeCommand(ParentId, '20-24', '@pdn-annotations:broken');
    Actor.ExecuteCommand(Command);
    Check(Command.Accepted, 'literal node comment must not be parsed as an array');
    ChildId := Command.CreatedNodeId;
    Command.Free;
    Check((Actor.GameTree.FindNodeById(ChildId).Parent.NodeId = ParentId) and
      (Actor.GameTree.FindNodeById(ChildId).CommentText = '@pdn-annotations:broken'),
      'node import must retain parent identity and exact literal comment');
    Command := Actor.CreateImportNodeCommand(ParentId, '20-24', '@pdn-annotations:broken');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted and not Command.TreeChanged and (Command.CreatedNodeId = ChildId),
        'repeated node import must reuse the same child without changing data');
    finally Command.Free; end;
  finally Actor.Free; end;
end;

procedure CheckRebuildKeepsOnlySurvivingParents;
var
  Actor: TGameTreeActor;
  Moves: TStringList;
  Header: TGameTreeHeaderInput;
  KeptId: Int64;

  procedure Rebuild(const Text: string; AnalysisNodeId: Int64 = 0);
  begin
    TextToMoveList(Text, Moves);
    Execute(Actor, Actor.CreateRebuildFromInputsCommand(Header,
      GameTreeMainlineInput(Moves, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', ''),
      AnalysisNodeId, '0.75', '38-32'));
  end;
begin
  Actor := TGameTreeActor.Create;
  Moves := TStringList.Create;
  try
    Header := GameTreeHeaderInput('carry', 'carry', '', '', '*', '', False,
      DefaultTimeControl);
    Rebuild('32-28 18-23 37-32 12-18');
    Execute(Actor, ImportBranch(Actor, 3, '13-18', '', gmsHuman));
    Execute(Actor, ImportBranch(Actor, 1,
      '20-24 38-32', '', gmsHuman));
    KeptId := Actor.GameTree.FindChildByMove(Actor.GameTree.MainlineNode[1], '20-24').NodeId;
    Rebuild('32-28 18-23', KeptId);
    Check((Actor.GameTree.MainlineCount = 2) and
      (Actor.GameTree.BranchCount = 1),
      'shorter reload must discard only branches whose parent no longer exists');
    Check((Actor.GameTree.FindBranchNode(0, 1).NodeId = KeptId) and
      (Actor.GameTree.FindBranchNode(0, 1).AnnotatorScore = '0.75'),
      'surviving branch identity and explicit PV target must survive index remapping');
    Execute(Actor, ImportBranch(Actor, 2,
      '38-32', '', gmsHuman));
    Rebuild('32-28 19-23');
    Check((Actor.GameTree.BranchCount = 1) and
      (Actor.GameTree.FindBranchNode(0, 1).NodeId = KeptId),
      'changing a parent path must not transplant its branches to the replacement');
  finally
    Moves.Free;
    Actor.Free;
  end;
end;

var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Moves: TStringList;
  Board: TDraughtsBoard;
  Header: TGameTreeHeaderInput;
  NodeId: Int64;
begin
  CheckTypedBranchImport;
  CheckLiteralNodeImport;
  CheckRebuildKeepsOnlySurvivingParents;
  Actor := TGameTreeActor.Create;
  Moves := TStringList.Create;
  Board := TDraughtsBoard.Create;
  try
    RejectUnchanged(Actor, Actor.CreateAddMainlineMoveCommand(5, '32-28', gmsHuman));
    RejectUnchanged(Actor, Actor.CreateAddMainlineMoveCommand(0, '32-28', gmsHuman));
    RejectUnchanged(Actor, Actor.CreateAppendMainlineMoveCommand('19-23', gmsHuman));
    RejectUnchanged(Actor, Actor.CreateAppendMainlineMoveCommand('nonsense', gmsHuman));
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('32-28', gmsHuman));
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('18-23', gmsHuman));
    Execute(Actor, Actor.CreateRecordAnnotatorPVCommand(
      Actor.GameTree.MainlineNode[1].NodeId, '0.5', '19-23'));
    RejectUnchanged(Actor, Actor.CreateAddMainlineMoveCommand(1, '19-23', gmsHuman));
    RejectUnchanged(Actor, ImportBranch(Actor, 1,
      '19-23 46-41', 'must not leak', gmsHuman));
    RejectUnchanged(Actor, ImportBranch(Actor, 10,
      '32-28', '', gmsHuman));
    RejectUnchanged(Actor, Actor.CreateStoreMoveVariationCommand(
      Actor.GameTree.MainlineNode[1].NodeId, '37-32', gmsHuman));
    Execute(Actor, ImportBranch(Actor, 1,
      '20-24 37-32', '', gmsHuman));
    NodeId := Actor.GameTree.FindBranchNode(0, 2).NodeId;
    RejectUnchanged(Actor, Actor.CreateStoreMoveVariationCommand(NodeId, '32-28', gmsHuman));
    Execute(Actor, Actor.CreateStoreMoveVariationCommand(NodeId, '14-20', gmsHuman));
    Header := GameTreeHeaderInput('invalid', 'must not replace', '', '', '2-0',
      DefaultStartingFEN, False, DefaultTimeControl, gosGameOver);
    RejectUnchanged(Actor, Actor.CreateAppendMainlineSnapshotMoveCommand(Header,
      '46-41', '', GameTreeMainlineInput(nil, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), gmsEngineMatch));
    TextToMoveList('32-28 18-23 46-41', Moves);
    RejectUnchanged(Actor, Actor.CreateRebuildFromInputsCommand(Header,
      GameTreeMainlineInput(Moves, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
    TextToMoveList('32-28', Moves);
    RejectUnchanged(Actor, ImportBranch(Actor, 1,
      '19-23 46-41', 'bad variation'));
    Header.StartingFEN := 'B:W99:B1';
    RejectUnchanged(Actor, Actor.CreateSetHeaderCommand(Header));
    Header.StartingFEN := 'B:W31-50:B1-20';
    RejectUnchanged(Actor, Actor.CreateSetHeaderCommand(Header));
    Check(Actor.PostCommand(Actor.CreateAppendMainlineMoveCommand('46-41', gmsHuman)),
      'queue invalid move');
    Check(Actor.PostCommand(Actor.CreateAppendMainlineMoveCommand('37-32', gmsHuman)),
      'queue valid move after invalid move');
    Check(Actor.ProcessCommands = 2, 'rejection must not interrupt the actor queue');
    Check(Actor.GameTree.MainlineCount = 3, 'only the valid queued move may be added');
    Moves.Clear;
    Header.StartingFEN := 'W:W37,45:B32,22,5';
    Execute(Actor, Actor.CreateRebuildFromInputsCommand(Header,
      GameTreeMainlineInput(Moves, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('37x17', gmsHuman));
    Check(Actor.GameTree.TryBuildBoardAtNode(Actor.GameTree.MainlineNode[1], Board),
      'legal short-form multiple captures must remain accepted and replayable');
  finally
    Board.Free;
    Moves.Free;
    Actor.Free;
  end;
  WriteLn('OK');
end.
