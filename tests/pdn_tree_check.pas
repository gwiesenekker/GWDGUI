program pdn_tree_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, uPdn, uDraughtsBoard, uDraughtsPosition;
procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;
function Child(Node: TPdnMoveNode; const Move: string): TPdnMoveNode;
var I: Integer;
begin
  Result := nil;
  for I := 0 to Node.ChildCount - 1 do
    if Node.Children[I].MoveText = Move then Exit(Node.Children[I]);
  raise Exception.Create('Missing parsed child: ' + Move);
end;
procedure CheckPaths(Node: TPdnMoveNode; Board: TDraughtsBoard);
var I: Integer; Next: TDraughtsBoard;
begin
  for I := 0 to Node.ChildCount - 1 do
  begin
    Check(Node.Children[I].Parent = Node, 'parsed child must own its real parent');
    Next := TDraughtsBoard.Create;
    try
      Next.AssignFrom(Board);
      Next.PlayMove(Node.Children[I].MoveText, True, True);
      CheckPaths(Node.Children[I], Next);
    finally Next.Free; end;
  end;
end;
function ReadGame(const Moves: string; const Fen: string = ''): TPdnGame;
var Name: string; Lines: TStringList; Games: TList; I: Integer;
begin
  Name := GetTempFileName(GetTempDir, 'gwd-pdn-tree');
  Lines := TStringList.Create;
  Games := TList.Create;
  Result := nil;
  try
    Lines.Text := '[Event "Tree regression"]' + LineEnding;
    if Fen <> '' then Lines.Add('[FEN "' + Fen + '"]');
    Lines.Add(Moves);
    Lines.SaveToFile(Name);
    LoadPdnGamesFromFile(Name, Games);
    Check(Games.Count = 1, 'tree fixture must contain one game');
    Result := TPdnGame.Create;
    Result.AssignFrom(TPdnGame(Games[0]));
  finally
    for I := 0 to Games.Count - 1 do TObject(Games[I]).Free;
    Games.Free; Lines.Free; DeleteFile(Name);
  end;
end;
procedure CheckNestedTree;
var Game, CopyGame: TPdnGame; Root, Again, Node: TPdnMoveNode; Board: TDraughtsBoard;
begin
  Game := ReadGame('1.32-28 {Main} 18-23 (1... {Branch intro} 20-24 {Outer} ' +
    '2.37-32 14-20 (2...18-22 {Deep}) (2.38-32 {Nested} 14-20)) 2.37-32 *');
  CopyGame := TPdnGame.Create;
  Board := TDraughtsBoard.Create;
  Root := nil; Again := nil;
  try
    Root := Game.BuildMoveTree;
    Check(Root.Children[0].MoveText = '32-28', 'first child is main continuation');
    Node := Child(Root, '32-28');
    Check(Node.AnnotationText = 'Main', 'main comment belongs to its node');
    Check(Node.Children[0].MoveText = '18-23', 'official reply stays first');
    Node := Child(Node, '20-24');
    Check((Pos('Branch intro', Node.AnnotationText) > 0) and
      (Pos('Outer', Node.AnnotationText) > 0), 'branch intro belongs to its first move');
    Check(Node.Children[0].MoveText = '37-32', 'branch continuation stays first');
    Check(Child(Child(Node, '37-32'), '18-22').AnnotationText = 'Deep',
      'deeper Black alternative must attach to its actual parent');
    Check(Child(Node, '38-32').AnnotationText = 'Nested', 'nested White alternative');
    Board.SetBeginPosition;
    CheckPaths(Root, Board);
    CopyGame.AssignFrom(Game);
    CopyGame.AssignFrom(CopyGame);
    FreeAndNil(Game);
    Again := CopyGame.BuildMoveTree;
    Root.Children[0].AnnotationText := 'Changed returned clone';
    Check(Again.Children[0].AnnotationText = 'Main', 'copied games must own independent nodes');
    FreeAndNil(Again);
    Again := CopyGame.BuildMoveTree;
    Check(Again.Children[0].AnnotationText = 'Main', 'returned tree must not mutate the parsed cache');
  finally
    Board.Free; Again.Free; Root.Free; CopyGame.Free; Game.Free;
  end;
end;
procedure CheckMalformedAndBlackStart;
var Game: TPdnGame; Root, Node: TPdnMoveNode; Board: TDraughtsBoard;
begin
  Game := ReadGame('1.32-28 18-23 (1...20-24 (1.33-28 {Bad}) ' +
    '2.37-32 (2.38-32 {Good}) 14-20) 2.37-32 *');
  Root := nil;
  Board := TDraughtsBoard.Create;
  try
    Root := Game.BuildMoveTree;
    Node := Child(Child(Root, '32-28'), '20-24');
    Check(Node.ChildCount = 2, 'skip bad nested branch and retain both valid continuations');
    Check(Child(Node, '38-32').AnnotationText = 'Good', 'valid sibling comment');
    Check(Game.ImportWarningsText <> '', 'malformed branch warning must remain available');
    Board.SetBeginPosition; CheckPaths(Root, Board);
  finally Root.Free; Game.Free; end;
  Game := ReadGame('1...18-23 2.32-28 (2.33-28 {White choice}) 23x32 ' +
    '3.37x28 (3.38x27 {Capture choice}) *', 'B:W31-50:B1-20');
  Root := nil;
  try
    Root := Game.BuildMoveTree;
    Node := Child(Root, '18-23');
    Check(Child(Node, '33-28').AnnotationText = 'White choice', 'Black-start White variation parent');
    Node := Child(Child(Node, '32-28'), '23x32');
    Check(Child(Node, '38x27').AnnotationText = 'Capture choice', 'Black-start capture parent');
    Board.LoadFromFEN(Game.StartingFEN); CheckPaths(Root, Board);
  finally Root.Free; Game.Free; Board.Free; end;
end;
procedure CheckEarlyBranchAndDatabaseCompatibility;
var Game: TPdnGame; Root: TPdnMoveNode;
begin
  Game := ReadGame('(1.31-26 {Early}) 1.32-28 18-23 *');
  Root := nil;
  try
    Root := Game.BuildMoveTree;
    Check((Root.ChildCount = 2) and (Root.Children[0].MoveText = '32-28'),
      'main continuation must precede an alternative parsed earlier');
    Check(Child(Root, '31-26').AnnotationText = 'Early', 'early branch must survive');
  finally Root.Free; Game.Free; end;
  Game := TPdnGame.Create;
  Root := nil;
  try
    Game.MovesText := '32-28 18-23';
    Game.MoveVariationsText := EncodePdnVariationLine(2, 1, '20-24 38-32');
    Game.MoveVariationAnnotationsText := 'Old database comment';
    Root := Game.BuildMoveTree;
    Check(Child(Child(Child(Root, '32-28'), '20-24'), '38-32').AnnotationText =
      'Old database comment', 'old database fields must still import correctly');
    FreeAndNil(Root);
    Game.MovesText := '31-26';
    Game.MoveVariationsText := '';
    Game.MoveVariationAnnotationsText := '';
    Root := Game.BuildMoveTree;
    Check((Root.ChildCount = 1) and (Root.Children[0].MoveText = '31-26'),
      'changing compatibility fields must invalidate the cached parsed tree');
  finally Root.Free; Game.Free; end;
end;
procedure CheckIllegalBranchWarnings;
var Game: TPdnGame; Root: TPdnMoveNode;
begin
  Game := TPdnGame.Create;
  try
    Game.MovesText := '32-28 18-23';
    Game.MoveVariationsText := EncodePdnVariationLine(2, 1, '18-24');
    Game.ValidateMoveTree;
    Check(Pos('18-24', Game.ImportWarningsText) > 0, 'rejected branch must carry a warning');
    Root := Game.BuildMoveTree;
    try Check(Root.ChildCount > 0, 'validation must retain original parsed content');
    finally Root.Free; end;
  finally Game.Free; end;
end;
begin
  CheckIllegalBranchWarnings;
  CheckNestedTree;
  CheckMalformedAndBlackStart;
  CheckEarlyBranchAndDatabaseCompatibility;
  WriteLn('OK');
end.
