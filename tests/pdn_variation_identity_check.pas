program pdn_variation_identity_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uDraughtsBoard, uPdn, uGameTreeNodeData;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then raise Exception.Create(Text); end;
function ReadGame(const Text: string): TPdnGame;
var Name: string; Lines: TStringList; Games: TList;
begin
  Name := GetTempFileName(GetTempDir, 'gwd-alias'); Lines := TStringList.Create;
  Games := TList.Create; Result := nil;
  try
    Lines.Text := Text; Lines.SaveToFile(Name); LoadPdnGamesFromFile(Name, Games);
    Check(Games.Count = 1, 'fixture contains one game');
    Result := TPdnGame(Games[0]); Games.Delete(0);
  finally
    while Games.Count > 0 do begin TObject(Games[0]).Free; Games.Delete(0); end;
    Games.Free; Lines.Free; DeleteFile(Name);
  end;
end;
procedure CheckEquivalentSiblings;
var Game, Next: TPdnGame; Root, Node: TPdnMoveNode; Text, Previous: string;
  First, Second: TGameTreeNodeData; Cycle: Integer;
begin
  First := Default(TGameTreeNodeData); First.CommentText := 'first note';
  First.EngineScore := '0.1'; First.EnginePV := '6-11';
  Second := Default(TGameTreeNodeData); Second.CommentText := 'second note';
  Second.AnnotatorScore := '0.2'; Second.AnnotatorPV := '6-1';
  Text := '[FEN "W:W38:B33,24,K6"]' + LineEnding +
    '1. 38x20x33x24 {first note} {' + EncodeNodeData(First, 'first note') + '} 6-11 ' +
    '(1. 38x20x24x33 {second note} {' + EncodeNodeData(Second, 'second note') + '} 6-1) *';
  // A first-move alternative belongs immediately after that move.
  Text := StringReplace(Text, ' 6-11 (1.', ' (1.', []);
  Text := StringReplace(Text, ' 6-1) *', ' 6-1) 6-11 *', []);
  Game := ReadGame(Text); Previous := '';
  try
    for Cycle := 1 to 3 do
    begin
      Root := Game.BuildMoveTree;
      try
        Check(Root.ChildCount = 1, 'equivalent captures merge before export');
        Node := Root.Children[0];
        Check(Node.ChildCount = 2, 'both alternative continuations retained');
        Check((Pos('first note', Node.AnnotationText) > 0) and
          (Pos('second note', Node.AnnotationText) > 0), 'both alias comments preserved');
        Check(Node.HasNodeData and (Node.NodeData.EnginePV = '6-11') and
          (Node.NodeData.AnnotatorPV = '6-1'), 'independent analysis retained when aliases merge');
        Check((Pos('first note', Node.NodeData.CommentText) > 0) and
          (Pos('second note', Node.NodeData.CommentText) > 0), 'typed merged comments agree');
      finally Root.Free; end;
      Text := PdnGameToText(Game);
      if Previous <> '' then Check(Text = Previous, 'export stable after first normalization');
      Previous := Text;
      Next := ReadGame(Text); Game.Free; Game := Next;
    end;
  finally Game.Free; end;
end;
procedure CheckDistinctCaptures;
var Board: TDraughtsBoard; Game: TPdnGame; Root: TPdnMoveNode;
  First, Second: string;
begin
  Board := TDraughtsBoard.Create;
  try
    Board.LoadFromFEN('W:WK21:B31,39,14,17,19');
    First := Board.PdnMoveNotation('21x26x17x19x39x31');
    Second := Board.PdnMoveNotation('21x26x17x14x39x31');
    Game := ReadGame('[FEN "W:WK21:B31,39,14,17,19"]' + LineEnding +
      '1. ' + First + ' (1. ' + Second + ') *');
    try
      Root := Game.BuildMoveTree;
      try Check(Root.ChildCount = 2, 'same endpoint with different captured sets remains distinct');
      finally Root.Free; end;
    finally Game.Free; end;
  finally Board.Free; end;
end;
begin
  CheckEquivalentSiblings; CheckDistinctCaptures;
  Writeln('PDN variation identity checks passed');
end.
