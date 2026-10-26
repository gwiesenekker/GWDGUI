program pdn_comment_preservation_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, uPdn, uGameTreeNodeData,
  uGameTreeActor, uGameTree, uGameTreePdn;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then raise Exception.Create(Text); end;
function ReadGame(const Text: string): TPdnGame;
var Name: string; Lines: TStringList; Games: TList;
begin
  Name := GetTempFileName(GetTempDir, 'gwd-comment');
  Lines := TStringList.Create; Games := TList.Create; Result := nil;
  try
    Lines.Text := Text; Lines.SaveToFile(Name); LoadPdnGamesFromFile(Name, Games);
    Check(Games.Count = 1, 'fixture has one game');
    Result := TPdnGame(Games[0]); Games.Delete(0);
  finally
    while Games.Count > 0 do begin TObject(Games[0]).Free; Games.Delete(0); end;
    Games.Free; Lines.Free; DeleteFile(Name);
  end;
end;
procedure CheckTrailingComment(const Position: string);
var Data: TGameTreeNodeData; Game, Next: TPdnGame; Root, Node: TPdnMoveNode;
  Text, Expected: string; Cycle: Integer; Actor: TGameTreeActor; Command: TGameTreeCommand;
begin
  Data := Default(TGameTreeNodeData);
  Data.CommentText := 'note'; Data.EngineScore := '0.1'; Data.EnginePVDepth := '9';
  if Position = 'root' then Data.EnginePV := '32-28' else Data.EnginePV := '18-23';
  Text := '{note; E: 0.1} {' + EncodeNodeData(Data, 'note; E: 0.1') + '} {extra} {last}';
  if Position = 'root' then
  begin Text := Text + ' 1. 32-28 *'; Expected := 'note extra last'; end
  else if Position = 'move' then
  begin Text := '1. 32-28 ' + Text + ' 18-23 *'; Expected := 'note; extra; last'; end
  else
  begin Text := '1. 33-28 (1. 32-28 ' + Text + ' 18-23) 18-23 *'; Expected := 'note; extra; last'; end;
  Game := ReadGame('[Event "Trailing metadata comment"]' + LineEnding + Text);
  try
    for Cycle := 1 to 3 do
    begin
      Root := Game.BuildMoveTree;
      try
        Node := Root;
        if Position = 'move' then Node := Root.Children[0]
        else if Position = 'variation' then Node := Root.Children[1];
        Check(Node.HasNodeData and (Node.NodeData.CommentText = Expected), 'trailing comments survive metadata restoration: ' + Position);
        Check((Node.NodeData.EngineScore = '0.1') and (Node.NodeData.EnginePV = Data.EnginePV) and
          (Node.NodeData.EnginePVDepth = '9'), 'extra text retains independent analysis metadata');
        Actor := TGameTreeActor.Create;
        try
          Command := Actor.CreateImportPdnTreeCommand(Root);
          try
            Actor.ExecuteCommand(Command); Check(Command.Accepted, Command.ErrorText);
            if Position = 'root' then
              Check(Actor.GameTree.Root.CommentText = Expected, 'actor root restore retains extra comments')
            else if Position = 'move' then
              Check(Actor.GameTree.Root.Children[0].CommentText = Expected, 'actor move restore retains extra comments')
            else Check(Actor.GameTree.Root.Children[1].CommentText = Expected, 'actor variation restore retains extra comments');
          finally Command.Free; end;
        finally Actor.Free; end;
      finally Root.Free; end;
      Next := ReadGame(PdnGameToText(Game)); Game.Free; Game := Next;
    end;
  finally Game.Free; end;
end;
procedure CheckLiteralPrefixes;
const Plain: array[0..2] of string = ('[%gwd a user note]',
  '[%gwd h=not-a-checksum eval="0.1"]', '[%gwd-node a user note]');
var Game, Next: TPdnGame; Root: TPdnMoveNode; I, Cycle: Integer;
  Data: TGameTreeNodeData; Literal, Text: string; Tree: TGameTree;
begin
  for I := 0 to High(Plain) do
  begin
    Game := ReadGame('[Event "Literal comment"]' + LineEnding + '1. 32-28 {' + Plain[I] + '} *');
    try
      Check(Game.ImportWarningsText = '', 'ordinary metadata-like comment is not malformed metadata');
      Root := Game.BuildMoveTree;
      try Check(not Root.Children[0].HasNodeData and (Root.Children[0].AnnotationText = Plain[I]), 'raw literal prefix preserved');
      finally Root.Free; end;
    finally Game.Free; end;
  end;
  Data := Default(TGameTreeNodeData); Data.EnginePV := '32-28';
  Literal := EncodeNodeData(Data, ''); // A literal that is also a syntactically valid extension.
  for I := 0 to 2 do
  begin
    Game := TPdnGame.Create;
    Game.MovesText := '32-28'; Game.InitialCommentText := Literal;
    Game.MoveAnnotationsText := Literal + LineEnding;
    try
      for Cycle := 1 to 3 do
      begin
        if I = 0 then Text := PdnGameToText(Game)
        else if I = 1 then Text := PdnGameToStorageText(Game, nil)
        else
        begin
          Tree := TGameTree.Create;
          try
            Tree.RecordMainlineMove(1, '32-28');
            Data.CommentText := Literal; Data.EnginePV := '32-28';
            Tree.RestoreNodeData(Tree.Root.NodeId, Data);
            Data.EnginePV := '18-23'; Tree.RestoreNodeData(Tree.MainlineNode[1].NodeId, Data);
            Text := GameTreeToPdnText(Tree);
          finally Tree.Free; end;
        end;
        Next := ReadGame(Text); Game.Free; Game := Next;
        Check(Game.ImportWarningsText = '', 'escaped literal does not trigger edit warnings');
        Root := Game.BuildMoveTree;
        try
          Check((Root.AnnotationText = Literal) and (Root.Children[0].AnnotationText = Literal), 'literal extension survives both root and move comments');
          if I = 2 then Check(Root.NodeData.CommentText = Literal, 'typed metadata preserves literal note');
        finally Root.Free; end;
      end;
    finally Game.Free; end;
  end;
end;

begin
  CheckLiteralPrefixes;
  CheckTrailingComment('root'); CheckTrailingComment('move'); CheckTrailingComment('variation');
  Writeln('PDN comment preservation checks passed');
end.
