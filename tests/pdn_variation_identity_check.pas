program pdn_variation_identity_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uDraughtsBoard, uPdn, uGameTreeNodeData, uGameDatabase;
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
procedure CheckConflictingMetadata;
var Game: TPdnGame; Root: TPdnMoveNode; First, Second: TGameTreeNodeData; Warnings, SourceText, DbName, PdnName, LogName: string;
  Database: TGameDatabase; Lines: TStringList; Imported, Duplicates, Errors: Integer;
begin
  First := Default(TGameTreeNodeData); First.EngineScore := '0.1'; First.EnginePV := '6-11';
  First.HasClockInfo := True; First.WhiteRemainingSeconds := 50;
  First.HasMoveTime := True; First.SecondsUsed := 1;
  Second := First; Second.EngineScore := '-3.5'; Second.EnginePV := '6-1';
  Second.AnnotatorScore := '0.2'; Second.WhiteRemainingSeconds := 40; Second.SecondsUsed := 2;
  SourceText := '[FEN "W:W38:B33,24,K6"]' + LineEnding +
    '1.38x20x33x24 {' + EncodeNodeData(First, '') + '} (1.38x20x24x33 {' +
    EncodeNodeData(Second, '') + '}) *';
  Game := ReadGame(SourceText);
  try
    Root := Game.BuildMoveTree;
    try
      Check((Root.ChildCount = 1) and (Root.Children[0].NodeData.EngineScore = '0.1') and
        (Root.Children[0].NodeData.EnginePV = '6-11') and
        (Root.Children[0].NodeData.AnnotatorScore = '0.2'), 'conflicts retain first values and independent analysis');
    finally Root.Free; end;
    Warnings := Game.ImportWarningsText;
    Check((Pos('at ply 1', Warnings) > 0) and (Pos('EngineScore', Warnings) > 0) and
      (Pos('EnginePV', Warnings) > 0) and (Pos('clocks', Warnings) > 0) and
      (Pos('move time', Warnings) > 0), 'merge warnings identify discarded conflicting fields and move');
    Check(Pos('AnnotatorScore', Warnings) = 0, 'independent metadata is not falsely reported as discarded');
    Root := Game.BuildMoveTree; Root.Free; Game.ValidateMoveTree;
    Check(Game.ImportWarningsText = Warnings, 'cached normalization and validation do not duplicate conflict warnings');
    DbName := GetTempFileName(GetTempDir, 'gwd-conflict-db');
    PdnName := GetTempFileName(GetTempDir, 'gwd-conflict-pdn');
    LogName := GetTempFileName(GetTempDir, 'gwd-conflict-log'); DeleteFile(DbName);
    Database := TGameDatabase.Create; Lines := TStringList.Create;
    try
      Lines.Text := SourceText; Lines.SaveToFile(PdnName); Database.CreateDatabase(DbName);
      Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors, nil, LogName);
      Check((Imported = 1) and (Errors = 0), 'conflicting alias metadata does not reject the game');
      Lines.LoadFromFile(LogName);
      Check((Pos('EngineScore', Lines.Text) > 0) and (Pos('kept first', Lines.Text) > 0),
        'database log includes conflicts discovered while generating canonical storage');
    finally
      Database.Free; Lines.Free; DeleteFile(DbName); DeleteFile(DbName + '-wal');
      DeleteFile(DbName + '-shm'); DeleteFile(PdnName); DeleteFile(LogName);
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
procedure CheckSiblingBoardRestoration;
var Game, Next: TPdnGame; Root: TPdnMoveNode; Storage: string; Cycle: Integer;
begin
  Game := ReadGame('1.32-28 (1.33-29 18-23 (1...20-24 2.29x20x24) 2.29x18x23) ' +
    '(1.34-30 20-25 2.32-28 25x34x30) 18-23 2.37-32 *');
  try
    Storage := PdnGameToStorageText(Game, nil);
    for Cycle := 1 to 3 do
    begin
      Root := Game.BuildMoveTree;
      try
        Check(Root.ChildCount = 3, 'multiple deep siblings survive normalization');
        Check((Root.Children[1].ChildCount = 2) and
          (Root.Children[1].Children[1].Children[0].MoveText <> ''), 'nested fork retains its continuation');
      finally Root.Free; end;
      Game.ValidateMoveTree; Check(Game.ImportWarningsText = '', 'every sibling uses its own fork position');
      Next := ReadGame(PdnGameToText(Game)); Game.Free; Game := Next;
      Check(PdnGameToStorageText(Game, nil) = Storage, 'nested capture identities stable after board reuse');
    end;
  finally Game.Free; end;
end;
procedure CheckDatabaseIdentity(const Fen, Moves: string);
var Database: TGameDatabase; Game: TPdnGame; Lines: TStringList;
  DbName, PdnName, Exported: string; Imported, Duplicates, Errors: Integer;
begin
  DbName := GetTempFileName(GetTempDir, 'gwd-identity'); DeleteFile(DbName);
  PdnName := GetTempFileName(GetTempDir, 'gwd-pdn');
  Database := TGameDatabase.Create; Lines := TStringList.Create;
  try
    Lines.Text := '[FEN "' + Fen + '"]' + LineEnding + Moves;
    Lines.SaveToFile(PdnName); Database.CreateDatabase(DbName);
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    Check((Imported = 1) and (Errors = 0), 'capture variation imported');
    Game := Database.LoadGameById(1);
    try Exported := PdnGameToText(Game); finally Game.Free; end;
    Lines.Text := Exported; Lines.SaveToFile(PdnName);
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    Check((Imported = 0) and (Duplicates = 1) and (Errors = 0),
      'exported capture variation retains database identity');
    Lines.Text := StringReplace(Exported, 'variation note', 'changed note', []);
    Lines.SaveToFile(PdnName);
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    Check((Imported = 1) and (Errors = 0), 'different variation content remains distinct');
  finally
    Database.Free; Lines.Free;
    DeleteFile(DbName); DeleteFile(DbName + '-wal'); DeleteFile(DbName + '-shm');
    DeleteFile(PdnName);
  end;
end;

begin
  CheckEquivalentSiblings; CheckConflictingMetadata; CheckDistinctCaptures; CheckSiblingBoardRestoration;
  CheckDatabaseIdentity('W:W38:B33,24,K6',
    '(1. 38x20x24x33 {variation note} 6-11) *');
  CheckDatabaseIdentity('W:W31-50:B1-20',
    '1. 32-28 (1. 33-29 18-23 2. 29x18x23 {variation note}) *');
  CheckDatabaseIdentity('W:WK21:B31,39,14,17,19',
    '1. 21x26x17x19x39x31 (1. 21x26x17x14x39x31 {variation note}) *');
  Writeln('PDN variation identity checks passed');
end.
