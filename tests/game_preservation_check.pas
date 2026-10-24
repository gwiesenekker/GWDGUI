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
  WriteLn('OK');
end.
