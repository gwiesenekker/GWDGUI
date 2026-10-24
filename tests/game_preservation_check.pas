program game_preservation_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uGameTree, uGameTreeActor, uGameTreeBuilder,
  uGameTreePdn, uGameOrchestrator, uPdn;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AMessage);
    Halt(1);
  end;
end;

procedure Execute(AActor: TGameTreeActor; ACommand: TGameTreeCommand);
begin
  try
    AActor.ExecuteCommand(ACommand);
    Check(ACommand.Accepted, 'command rejected: ' + ACommand.ErrorText);
  finally
    ACommand.Free;
  end;
end;

procedure Rebuild(AActor: TGameTreeActor; const ASignature, AFen,
  AMoves: string);
var
  Moves, Annotations: TStringList;
begin
  Moves := TStringList.Create;
  Annotations := TStringList.Create;
  try
    TextToMoveList(AMoves, Moves);
    Execute(AActor, AActor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput(ASignature, 'test', 'White', 'Black', '*', AFen,
        False, DefaultTimeControl),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
  finally
    Annotations.Free;
    Moves.Free;
  end;
end;

procedure CheckStoredVariationsAreExported;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Revision: Int64;
  Text: string;
begin
  Actor := TGameTreeActor.Create;
  try
    Rebuild(Actor, 'import', '', '32-28 18-23 37-32');
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '19-23 37-32 14-19', 'A: 0.10', gmsUnknown));
    Check(Actor.GameTree.FindVariationNode(0, 1) <> nil,
      'storing an imported variation must create its first node immediately');
    Check(Actor.GameTree.FindVariationNode(0, 3) <> nil,
      'all imported variation moves must be materialized');
    Text := GameTreeToPdnText(Actor.GameTree);
    Check(Pos('(1... 19-23', Text) > 0, 'export must retain the variation');
    Check(Pos('14-19 {A: 0.10}', Text) > 0,
      'export must retain its tail and annotation');
    Revision := Actor.Revision;
    Command := Actor.CreateStoreVariationLineCommand(2, 1,
      '19-23 37-32 14-19', 'A: 0.10', gmsUnknown);
    Execute(Actor, Command);
    Check(Actor.Revision = Revision, 'storing an unchanged line must be a no-op');
  finally
    Actor.Free;
  end;
end;

function ParseGame(const AText: string): TPdnGame;
var
  FileName: string;
  Lines: TStringList;
  Games: TList;
  I: Integer;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd');
  Lines := TStringList.Create;
  Games := TList.Create;
  try
    Lines.Text := AText;
    Lines.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 1, 'PDN should contain exactly one game');
    Result := TPdnGame.Create;
    Result.AssignFrom(TPdnGame(Games[0]));
  finally
    for I := 0 to Games.Count - 1 do
      TObject(Games[I]).Free;
    Games.Free;
    Lines.Free;
    DeleteFile(FileName);
  end;
end;

procedure CheckStandardVariationPlacement;
var
  Game: TPdnGame;
  Lines, Annotations: TStringList;
  Display, Base: Integer;
  Moves, AnnotationText, Text: string;
  Actor: TGameTreeActor;
begin
  Lines := TStringList.Create;
  Annotations := TStringList.Create;
  Actor := TGameTreeActor.Create;
  try
    Game := ParseGame('[Event "standard"]' + LineEnding + LineEnding +
      '1. 32-28 18-23 (1... 19-23) 2. 37-32 *');
    try
      Lines.Text := Game.MoveVariationsText;
      Annotations.Text := Game.MoveVariationAnnotationsText;
      Check(DecodePdnVariationLine(Lines[0], Annotations[0], 0,
        Display, Base, Moves, AnnotationText), 'standard RAV should decode');
      Check((Display = 2) and (Base = 1),
        'numbered RAV must branch before the move it replaces');
    finally
      Game.Free;
    end;
    Game := ParseGame('[Event "unnumbered"]' + LineEnding + LineEnding +
      '1. 32-28 18-23 (19-23) 2. 37-32 *');
    try
      Lines.Text := Game.MoveVariationsText;
      Annotations.Text := Game.MoveVariationAnnotationsText;
      DecodePdnVariationLine(Lines[0], Annotations[0], 0,
        Display, Base, Moves, AnnotationText);
      Check(Base = 1, 'unnumbered RAV must also replace the preceding move');
    finally
      Game.Free;
    end;
    Rebuild(Actor, 'placement', '', '32-28 18-23 37-32');
    Execute(Actor, Actor.CreateStoreVariationLineCommand(1, 1,
      '19-23', '', gmsHuman));
    Execute(Actor, Actor.CreateStoreMoveVariationCommand(
      Actor.GameTree.Root.NodeId, '33-28', gmsHuman));
    Text := GameTreeToPdnText(Actor.GameTree);
    Check(Pos('32-28 (1. 33-28)', Text) > 0,
      'root alternatives must be exported after the first move');
    Check(Pos('18-23 (1... 19-23)', Text) > 0,
      'GUI alternatives must be exported after the move they replace');
    Game := ParseGame(Text);
    try
      Lines.Text := Game.MoveVariationsText;
      Annotations.Text := Game.MoveVariationAnnotationsText;
      Check(Lines.Count = 2, 'save/load must preserve root and reply alternatives');
      DecodePdnVariationLine(Lines[0], Annotations[0], 0,
        Display, Base, Moves, AnnotationText);
      Check((Base = 0) and (Moves = '33-28'), 'root alternative must stay at root');
      DecodePdnVariationLine(Lines[1], Annotations[1], 0,
        Display, Base, Moves, AnnotationText);
      Check((Base = 1) and (Moves = '19-23'), 'reply alternative must stay a reply');
    finally
      Game.Free;
    end;
  finally
    Actor.Free;
    Annotations.Free;
    Lines.Free;
  end;
end;

procedure LoadParsedGame(AActor: TGameTreeActor; AGame: TPdnGame);
var
  Moves, Annotations, Variations, VariationAnnotations: TStringList;
  I, Display, Base: Integer;
  MoveText, AnnotationText, RawAnnotationText: string;
begin
  Moves := TStringList.Create;
  Annotations := TStringList.Create;
  Variations := TStringList.Create;
  VariationAnnotations := TStringList.Create;
  try
    TextToMoveList(AGame.MovesText, Moves);
    Annotations.Text := AGame.MoveAnnotationsText;
    Execute(AActor, AActor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('parsed game', AGame.EventName, AGame.WhiteName,
        AGame.BlackName, AGame.ResultText, AGame.StartingFEN,
        False, DefaultTimeControl, gosWaiting, '', AGame.InitialCommentText),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
    Execute(AActor, AActor.CreateClearStoredVariationsCommand);
    Variations.Text := AGame.MoveVariationsText;
    VariationAnnotations.Text := AGame.MoveVariationAnnotationsText;
    for I := 0 to Variations.Count - 1 do
    begin
      RawAnnotationText := '';
      if I < VariationAnnotations.Count then
        RawAnnotationText := VariationAnnotations[I];
      Check(DecodePdnVariationLine(Variations[I], RawAnnotationText, I,
        Display, Base, MoveText, AnnotationText), 'imported line should decode');
      Execute(AActor, AActor.CreateStoreVariationLineCommand(Display, Base,
        MoveText, AnnotationText, gmsUnknown));
    end;
  finally
    VariationAnnotations.Free;
    Variations.Free;
    Annotations.Free;
    Moves.Free;
  end;
end;

procedure CheckCommentRoundTrips;
var
  Game, Reloaded: TPdnGame;
  Actor: TGameTreeActor;
  Text: string;
  Pass: Integer;
begin
  Game := ParseGame('[Event "comments"]' + LineEnding + LineEnding +
    '{Introduction to this game} 1. 32-28 {Strong move!; E: 0.10} ' +
    '18-23 {Black reply} (1... 19-23 {First alternative comment} ' +
    '2. 37-32 {Middle comment;' + LineEnding + 'E: 0.20} ' +
    '14-19 {Last comment}) 2. 37-32 {Final mainline comment} *');
  Actor := TGameTreeActor.Create;
  try
    for Pass := 1 to 3 do
    begin
      LoadParsedGame(Actor, Game);
      Check(Actor.GameTree.Root.CommentText = 'Introduction to this game',
        'introduction must be stored on the root');
      Check(Actor.GameTree.MainlineNode[1].CommentText = 'Strong move!',
        'mixed score/comment must preserve its free text');
      Check(Actor.GameTree.MainlineNode[2].CommentText = 'Black reply',
        'reply comment must survive import');
      Check(Actor.GameTree.FindVariationNode(0, 1).CommentText =
        'First alternative comment', 'variation first comment must survive');
      Check(Actor.GameTree.FindVariationNode(0, 2).CommentText = 'Middle comment',
        'variation middle comment must survive alongside its score');
      Check(Actor.GameTree.FindVariationNode(0, 3).CommentText = 'Last comment',
        'variation last comment must survive');
      Text := GameTreeToPdnText(Actor.GameTree);
      Check(Pos('@pdn-annotations:', Text) = 0,
        'internal comment storage must never leak into exported PDN');
      Reloaded := ParseGame(Text);
      Game.Free;
      Game := Reloaded;
    end;
    Reloaded := ParseGame(PdnGameToText(Game));
    try
      LoadParsedGame(Actor, Reloaded);
      Check(Actor.GameTree.Root.CommentText = 'Introduction to this game',
        'legacy export must retain the introduction');
      Check(Actor.GameTree.FindVariationNode(0, 1).CommentText =
        'First alternative comment', 'legacy export must retain per-move comments');
    finally
      Reloaded.Free;
    end;
  finally
    Actor.Free;
    Game.Free;
  end;
end;

procedure CheckExplorationPreservesContinuations;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  First: TGameTreePlyNode;
  Original: string;
begin
  Actor := TGameTreeActor.Create;
  try
    Rebuild(Actor, 'exploration', '', '32-28 18-23 37-32');
    Original := '19-23 37-32 14-19 41-37';
    Execute(Actor, Actor.CreateStoreVariationLineCommand(1, 1,
      Original, 'Original tail', gmsHuman));
    First := Actor.GameTree.FindVariationNode(0, 1);
    Command := Actor.CreateStoreMoveVariationCommand(First.NodeId, '37-32', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted and (not Command.TreeChanged),
        'replaying the existing continuation should navigate without mutation');
      Check((Command.VariationIndex = 0) and (Command.PlyNumber = 2),
        'navigation should select the existing next variation node');
    finally
      Command.Free;
    end;
    Check(Actor.GameTree.VariationLine[0].MovesText = Original,
      'replaying a move must not truncate the original continuation');
    Execute(Actor, Actor.CreateStoreMoveVariationCommand(First.NodeId,
      '31-27', gmsHuman));
    Check(Actor.GameTree.VariationLineCount = 2,
      'an alternative inside a variation must create a separate continuation');
    Check(Actor.GameTree.VariationLine[0].MovesText = Original,
      'branching must leave the original variation intact');
    Check(Actor.GameTree.FindVariationNode(0, 4).CommentText = 'Original tail',
      'branching must preserve the original tail annotation');
    Check(Actor.GameTree.VariationLine[1].MovesText = '19-23 31-27',
      'the new branch should retain its prefix');
    Execute(Actor, Actor.CreateStoreMoveVariationCommand(
      Actor.GameTree.FindVariationNode(1, 2).NodeId, '14-19', gmsHuman));
    Check(Actor.GameTree.VariationLine[1].MovesText = '19-23 31-27 14-19',
      'a new move at the end should extend its own branch');
    Command := Actor.CreateStoreMoveVariationCommand(
      Actor.GameTree.MainlineNode[1].NodeId, '19-23', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted and (not Command.TreeChanged) and
        (Command.VariationIndex = 0), 'replaying an alternative must find its line');
    finally
      Command.Free;
    end;
    Command := Actor.CreateStoreMoveVariationCommand(
      Actor.GameTree.MainlineNode[1].NodeId, '18-23', gmsHuman);
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted and (not Command.TreeChanged) and
        (Command.VariationIndex = -1) and (Command.PlyNumber = 2),
        'replaying the mainline move must navigate without making a duplicate');
    finally
      Command.Free;
    end;
    Check((Actor.GameTree.VariationLineCount = 2) and
      (Actor.GameTree.VariationLine[0].MovesText = Original),
      'navigation must preserve both complete branches');
    Execute(Actor, Actor.CreateStoreMoveVariationCommand(
      Actor.GameTree.FindVariationNode(0, 4).NodeId, '20-24', gmsHuman));
    Check(Actor.GameTree.FindVariationNode(0, 4).CommentText = 'Original tail',
      'extending a line must keep the old final comment on its move');
    Check(Actor.GameTree.FindVariationNode(0, 5).CommentText = '',
      'the newly appended move must not inherit the old final comment');
  finally
    Actor.Free;
  end;
end;

procedure CheckNestedVariationPathsSurvive;
var
  Game, Reloaded: TPdnGame;
  Actor: TGameTreeActor;
  Pass: Integer;
  Text: string;
begin
  Game := ParseGame('[Event "nested"]' + LineEnding + LineEnding +
    '1. 32-28 18-23 (1... 19-23 {Outer reply} ' +
    '2. 37-32 {Original continuation} (2. 38-32 {Nested choice} ' +
    '14-19 {Nested tail} (2... 20-24 {Deeper choice})) ' +
    '14-19 {Original tail}) 2. 37-32 *');
  Actor := TGameTreeActor.Create;
  try
    for Pass := 1 to 3 do
    begin
      LoadParsedGame(Actor, Game);
      Check(Actor.GameTree.VariationLineCount = 3,
        'all three nested continuation paths must survive import');
      Check(Actor.GameTree.VariationLine[0].MovesText = '19-23 37-32 14-19',
        'outer continuation must remain intact');
      Check(Actor.GameTree.VariationLine[1].MovesText = '19-23 38-32 14-19',
        'nested continuation must retain its outer prefix');
      Check(Actor.GameTree.VariationLine[2].MovesText = '19-23 38-32 20-24',
        'deeper continuation must retain both prefixes');
      Check(Actor.GameTree.FindVariationNode(1, 2).CommentText = 'Nested choice',
        'nested commentary must stay on the nested move');
      Check(Actor.GameTree.FindVariationNode(2, 3).CommentText = 'Deeper choice',
        'deeper commentary must stay on its own move');
      Text := GameTreeToPdnText(Actor.GameTree);
      Reloaded := ParseGame(Text);
      Game.Free;
      Game := Reloaded;
    end;
  finally
    Actor.Free;
    Game.Free;
  end;
end;

procedure CheckCommentsStayWithTheirMoves;
var
  Game: TPdnGame;
  Annotations: TStringList;
begin
  Game := ParseGame('[Event "comments"]' + LineEnding + LineEnding +
    '1. 32-28 {Strong move!} {E: 0.10;' + LineEnding +
    'A: 0.20} 18-23 {Black reply} 2. 37-32 {E: 0.30} *');
  Annotations := TStringList.Create;
  try
    Annotations.Text := Game.MoveAnnotationsText;
    Check(Annotations.Count = 3, 'multiline comments must not create annotation slots');
    Check(Pos('Strong move!', Annotations[0]) > 0,
      'free text must survive alongside a separate score comment');
    Check(Annotations[1] = 'Black reply', 'reply comment must stay on the reply');
    Check(ExtractAnnotationValue(Annotations[2], 'engine') = '0.30',
      'later score must stay on its original move');
  finally
    Annotations.Free;
    Game.Free;
  end;
end;

procedure CheckVariationsBelongToTheirGame;
var
  Actor: TGameTreeActor;
begin
  Actor := TGameTreeActor.Create;
  try
    Rebuild(Actor, 'game A', '', '32-28 18-23');
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '19-23 37-32', 'A: 0.20', gmsUnknown));
    Rebuild(Actor, 'game A', '', '32-28 18-23');
    Check(Actor.GameTree.VariationLineCount = 1,
      'refreshing the same game must preserve its variation');
    Check(Actor.GameTree.FindVariationNode(0, 2).AnnotatorScore = '0.20',
      'refreshing the same game must preserve variation annotations');
    Rebuild(Actor, 'game B', '', '32-28 18-23');
    Check(Actor.GameTree.VariationLineCount = 0,
      'a different game must not inherit variations even with the same moves');
    Execute(Actor, Actor.CreateStoreMoveVariationCommand(
      Actor.GameTree.Root.NodeId, '33-28', gmsHuman));
    Rebuild(Actor, 'game C', 'W:W31,32:B19,20', '');
    Check((Actor.GameTree.VariationLineCount = 0) and
      (Actor.GameTree.Root.ChildCount = 0),
      'loading a new FEN must not inherit a previous root variation');
  finally
    Actor.Free;
  end;
end;

begin
  CheckStoredVariationsAreExported;
  CheckVariationsBelongToTheirGame;
  CheckStandardVariationPlacement;
  CheckCommentsStayWithTheirMoves;
  CheckCommentRoundTrips;
  CheckExplorationPreservesContinuations;
  CheckNestedVariationPathsSurvive;
  WriteLn('OK');
end.
