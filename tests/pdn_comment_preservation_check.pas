program pdn_comment_preservation_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, uPdn, uGameTreeNodeData,
  uGameTreeActor, uGameTree;
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
begin
  CheckTrailingComment('root'); CheckTrailingComment('move'); CheckTrailingComment('variation');
  Writeln('PDN comment preservation checks passed');
end.
