program game_tree_validation_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uGameTree, uGameTreeActor, uGameTreeBuilder,
  uGameTreePdn, uGameOrchestrator, uDraughtsBoard;
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
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Moves: TStringList;
  Board: TDraughtsBoard;
  Header: TGameTreeHeaderInput;
  NodeId: Int64;
begin
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
    RejectUnchanged(Actor, Actor.CreateStoreVariationLineCommand(1, 1,
      '19-23 46-41', 'must not leak', gmsHuman));
    RejectUnchanged(Actor, Actor.CreateStoreVariationLineCommand(10, 10,
      '32-28', '', gmsHuman));
    RejectUnchanged(Actor, Actor.CreateStoreMoveVariationCommand(
      Actor.GameTree.MainlineNode[1].NodeId, '37-32', gmsHuman));
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '20-24 37-32', '', gmsHuman));
    NodeId := Actor.GameTree.FindVariationNode(0, 2).NodeId;
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
    Command := Actor.CreateRebuildFromInputsCommand(Header,
      GameTreeMainlineInput(Moves, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', ''));
    Command.RebuildVariationLines.Add(TGameTreeVariationLine.Create(1, 1,
      '19-23 46-41', 'bad variation'));
    RejectUnchanged(Actor, Command);
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
