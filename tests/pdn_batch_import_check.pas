program pdn_batch_import_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, Math,
  uDraughtsPdn, uDraughtsBoard, uGameTree, uGameTreeActor, uGameTreePdn, uDraughtsPosition;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then raise Exception.Create(Text); end;
procedure LegacyImport(Actor: TGameTreeActor; Source: TPdnMoveNode; Id: Int64;
  Warnings: TStrings; var Count: Integer);
var Command: TGameTreeCommand; I: Integer;
begin
  if Source.HasNodeData then
  begin
    Command := Actor.CreateRestoreNodeDataCommand(Id, Source.NodeData);
    try
      Actor.ExecuteCommand(Command);
      if not Command.Accepted then Warnings.Add('Cannot restore node data: ' + Command.ErrorText);
    finally Command.Free; end;
  end;
  for I := 0 to Source.ChildCount - 1 do
  begin
    Command := Actor.CreateImportNodeCommand(Id, Source.Children[I].MoveText,
      Source.Children[I].AnnotationText);
    try
      Actor.ExecuteCommand(Command);
      if Command.Accepted then
      begin
        Inc(Count);
        LegacyImport(Actor, Source.Children[I], Command.CreatedNodeId, Warnings, Count);
      end
      else Warnings.Add('Cannot load move ' + Source.Children[I].MoveText + ': ' + Command.ErrorText);
    finally Command.Free; end;
  end;
end;
procedure CompareImport(Root: TPdnMoveNode; const Fen: string;
  ExpectedWarnings, ExpectedMoves: Integer);
var OldActor, NewActor: TGameTreeActor; Command: TGameTreeCommand;
  Warnings: TStringList; Count: Integer;
begin
  OldActor := TGameTreeActor.Create; NewActor := TGameTreeActor.Create;
  Warnings := TStringList.Create;
  try
    OldActor.GameTree.BeginRebuild('test', '?', 'White', 'Black', '*', Fen);
    NewActor.GameTree.BeginRebuild('test', '?', 'White', 'Black', '*', Fen);
    Count := 0;
    LegacyImport(OldActor, Root, OldActor.GameTree.Root.NodeId, Warnings, Count);
    Command := NewActor.CreateImportPdnTreeCommand(Root);
    Root.Free; Root := nil; // The command must own its copied payload.
    try
      NewActor.ExecuteCommand(Command);
      Check(Command.Accepted, Command.ErrorText);
      Check(Command.ImportWarnings.Text = Warnings.Text, 'batch import preserves ordered legacy warnings');
      Check(Warnings.Count = ExpectedWarnings, 'fixture warning count');
      Check((Command.ImportedMoveCount = Count) and (Count = ExpectedMoves), 'same valid nodes imported');
      Check(Command.ValidatedMoveCount = Count + ExpectedWarnings - Ord(Pos('Cannot restore', Warnings.Text) > 0),
        'each visited move validated exactly once, invalid descendants skipped');
      Check(GameTreeToPdnText(NewActor.GameTree) = GameTreeToPdnText(OldActor.GameTree),
        'batch import preserves topology, captions, comments and complete node metadata');
    finally Command.Free; end;
  finally Root.Free; Warnings.Free; NewActor.Free; OldActor.Free; end;
end;
var Root, First, Branch, Nested, Leaf: TPdnMoveNode; I: Integer;
  Actor: TGameTreeActor; Command: TGameTreeCommand;
begin
  Root := TPdnMoveNode.Create;
  Root.HasNodeData := True; Root.NodeData.CommentText := 'root note';
  First := Root.AddMove('32-28', True);
  First.HasNodeData := True; First.NodeData.CommentText := 'move note';
  First.NodeData.EnginePV := '20-24 38-32'; First.NodeData.EngineScore := '0.25';
  First.NodeData.AutoPlayPV := '19-23'; First.NodeData.HasClockInfo := True;
  First.NodeData.WhiteRemainingSeconds := 240;
  First.AddMove('18-23', True).AddMove('37-32', True);
  Branch := First.AddMove('20-24', False);
  Branch.AnnotationText := 'valid alternative';
  Nested := Branch.AddMove('38-32', True);
  Nested.AddMove('14-20', True);
  Nested.AddMove('18-22', False).AnnotationText := 'nested sibling';
  Nested.AddMove('1-50', False).AddMove('31-26', True);
  Nested.AddMove('15-20', False).AnnotationText := 'valid sibling after malformed subtree';
  CompareImport(Root, DefaultStartingFEN, 1, 8);
  Root := TPdnMoveNode.Create;
  Root.HasNodeData := True; Root.NodeData.HasClockInfo := True;
  Root.NodeData.WhiteRemainingSeconds := NaN;
  Root.AddMove('032X021X012', True).AnnotationText := 'landing-path capture';
  CompareImport(Root, 'W:W32:B17,27', 1, 1);
  Root := TPdnMoveNode.Create; Leaf := Root;
  for I := 0 to 199 do
    case I mod 4 of
      0: Leaf := Leaf.AddMove('50-45', True);
      1: Leaf := Leaf.AddMove('1-6', True);
      2: Leaf := Leaf.AddMove('45-50', True);
      3: Leaf := Leaf.AddMove('6-1', True);
    end;
  CompareImport(Root, 'W:WK50:BK1', 0, 200);
  Actor := TGameTreeActor.Create;
  try
    Command := Actor.CreateImportPdnTreeCommand(nil);
    try
      Actor.ExecuteCommand(Command);
      Check(not Command.Accepted and (Actor.Revision = 0), 'missing payload rejected without mutation');
    finally Command.Free; end;
    Root := TPdnMoveNode.Create; Root.AddMove('32-28', True);
    Command := Actor.CreateImportPdnTreeCommand(Root); Root.Free;
    try
      Inc(Command.GameTreeId); Actor.ExecuteCommand(Command);
      Check(not Command.Accepted and (Actor.Revision = 0), 'wrong tree identity rejected without mutation');
    finally Command.Free; end;
  finally Actor.Free; end;
  Writeln('PDN batch import checks passed');
end.
