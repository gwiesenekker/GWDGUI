program pdn_regression_check;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, uDraughtsBoard, uGameDatabase, uGameMoveHistory, uPdn;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    Writeln('FAIL: ', AMessage);
    Halt(1);
  end;
end;

procedure CheckEqual(const AActual, AExpected, AMessage: string);
begin
  Check(AActual = AExpected, AMessage + '; expected="' + AExpected +
    '"; actual="' + AActual + '"');
end;

procedure ClearGames(AGames: TList);
var
  I: Integer;
begin
  for I := 0 to AGames.Count - 1 do
    TObject(AGames[I]).Free;
  AGames.Clear;
end;

procedure CheckPdnLoadAndAppend;
var
  FileName: string;
  Game: TPdnGame;
  Games: TList;
  Lines: TStringList;
begin
  FileName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'gwdgui_pdn_regression_check.pdn';
  Lines := TStringList.Create;
  Games := TList.Create;
  try
    Lines.Add('[Event "First"]');
    Lines.Add('[White "Alpha"]');
    Lines.Add('[Black "Beta"]');
    Lines.Add('[Result "1-1"]');
    Lines.Add('[FEN "W:W31-50:B1-20"]');
    Lines.Add('');
    Lines.Add('1. 34-30 {score=0.12} 20-25 {comment} 2. 32-28 1-1');
    Lines.Add('');
    Lines.Add('[Event "Second"]');
    Lines.Add('[White "Gamma"]');
    Lines.Add('[Black "Delta"]');
    Lines.Add('[Result "*"]');
    Lines.Add('');
    Lines.Add('1. 33-28 18-22 *');
    Lines.SaveToFile(FileName);

    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 2, 'two games should be parsed');
    Game := TPdnGame(Games[0]);
    CheckEqual(Game.EventName, 'First', 'first game event');
    CheckEqual(Game.WhiteName, 'Alpha', 'first game white');
    CheckEqual(Game.BlackName, 'Beta', 'first game black');
    CheckEqual(Game.ResultText, '1-1', 'first game result');
    CheckEqual(Game.MovesText, '34-30 20-25 32-28',
      'first game main line moves');
    CheckEqual(Game.MoveAnnotationsText, 'score=0.12' + LineEnding +
      'comment' + LineEnding + LineEnding, 'first game score and comment annotations');

    Game := TPdnGame.Create;
    try
      Game.EventName := 'Saved';
      Game.WhiteName := 'White';
      Game.BlackName := 'Black';
      Game.ResultText := '2-0';
      Game.StartingFEN := 'W:W31-50:B1-20';
      Game.MovesText := '34-30 20-25';
      Game.MoveAnnotationsText := 'score=0.25' + LineEnding +
        'score=-0.10' + LineEnding;
      AppendPdnGameToFile(FileName, Game);
    finally
      Game.Free;
    end;

    ClearGames(Games);
    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 3, 'saved game should be appended');
    CheckEqual(TPdnGame(Games[2]).EventName, 'Saved',
      'appended game event');
    CheckEqual(TPdnGame(Games[2]).ResultText, '2-0',
      'appended game result should stay internal draughts notation');
    CheckEqual(TPdnGame(Games[2]).MoveAnnotationsText,
      'score=0.25' + LineEnding + 'score=-0.10' + LineEnding,
      'appended game score annotations');
    Lines.LoadFromFile(FileName);
    Check(Pos('[Result "1-0"]', Lines.Text) > 0,
      'saved PDN should export white win as 1-0');
    Check(Pos('1. 34-30 {score=0.25} 20-25 {score=-0.10} 1-0',
      Lines.Text) > 0, 'saved movetext should end with exported 1-0');
  finally
    ClearGames(Games);
    Games.Free;
    Lines.Free;
    if FileExists(FileName) then
      DeleteFile(FileName);
  end;
end;

procedure CheckPdnGluedMoveNumbers;
var
  FileName: string;
  Game: TPdnGame;
  Games: TList;
  Lines: TStringList;
begin
  FileName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'gwdgui_pdn_glued_move_numbers_check.pdn';
  Lines := TStringList.Create;
  Games := TList.Create;
  try
    Lines.Add('[Event "Glued"]');
    Lines.Add('[White "Alpha"]');
    Lines.Add('[Black "Beta"]');
    Lines.Add('[Result "2-0"]');
    Lines.Add('[FEN "W:W31-50:B1-20"]');
    Lines.Add('');
    Lines.Add('1.32-28 1...18-23 2.34-29 2-0');
    Lines.SaveToFile(FileName);

    LoadPdnGamesFromFile(FileName, Games);
    CheckEqual(IntToStr(Games.Count), '1',
      'glued move-number game should be parsed');
    Game := TPdnGame(Games[0]);
    CheckEqual(Game.MovesText, '32-28 18-23 34-29',
      'glued move-number tokens should produce moves');
    CheckEqual(Game.ResultText, '2-0',
      'internal draughts result token should be accepted');
  finally
    ClearGames(Games);
    Games.Free;
    Lines.Free;
    if FileExists(FileName) then
      DeleteFile(FileName);
  end;
end;

procedure CheckPdnVariationImportExport;
var
  BasePly: Integer;
  DisplayPly: Integer;
  FileName: string;
  Game: TPdnGame;
  Games: TList;
  Lines: TStringList;
  VariationAnnotations: TStringList;
  Variations: TStringList;
  MovesText: string;
  PdnText: string;
  VisibleAnnotation: string;
begin
  FileName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'gwdgui_pdn_variation_check.pdn';
  Lines := TStringList.Create;
  Games := TList.Create;
  VariationAnnotations := TStringList.Create;
  Variations := TStringList.Create;
  try
    Lines.Add('[Event "Variations"]');
    Lines.Add('[White "Alpha"]');
    Lines.Add('[Black "Beta"]');
    Lines.Add('[Result "*"]');
    Lines.Add('[FEN "W:W31-50:B1-20"]');
    Lines.Add('');
    Lines.Add('1. 32-28 (1... 18-23 {A: 0.10}) (1... 20-24 {A: 0.20}) 16-21 *');
    Lines.SaveToFile(FileName);

    LoadPdnGamesFromFile(FileName, Games);
    CheckEqual(IntToStr(Games.Count), '1',
      'variation game should be parsed');
    Game := TPdnGame(Games[0]);
    CheckEqual(Game.MovesText, '32-28 16-21',
      'variation import should keep main line only in MovesText');
    Variations.Text := Game.MoveVariationsText;
    VariationAnnotations.Text := Game.MoveVariationAnnotationsText;
    CheckEqual(IntToStr(Variations.Count), '2',
      'both same-ply variations should be stored');
    Check(DecodePdnVariationLine(Variations[0], VariationAnnotations[0], 0,
      DisplayPly, BasePly, MovesText, VisibleAnnotation),
      'first variation row should decode');
    CheckEqual(IntToStr(DisplayPly), '1',
      'first variation display ply');
    CheckEqual(IntToStr(BasePly), '1',
      'first variation base ply should come from 1...');
    CheckEqual(MovesText, '18-23', 'first variation moves');
    CheckEqual(VisibleAnnotation, 'A: 0.10',
      'first variation visible annotation');
    Check(DecodePdnVariationLine(Variations[1], VariationAnnotations[1], 0,
      DisplayPly, BasePly, MovesText, VisibleAnnotation),
      'second variation row should decode');
    CheckEqual(MovesText, '20-24', 'second variation moves');

    Game := TPdnGame.Create;
    try
      Game.EventName := 'Export';
      Game.WhiteName := 'Alpha';
      Game.BlackName := 'Beta';
      Game.ResultText := '*';
      Game.StartingFEN := 'W:W31-50:B1-20';
      Game.MovesText := '32-28 16-21';
      Game.MoveVariationsText := EncodePdnVariationLine(2, 1, '18-23') +
        LineEnding;
      Game.MoveVariationAnnotationsText := 'A: -0.03' + LineEnding;
      PdnText := PdnGameToText(Game);
      Check(Pos('1. 32-28 16-21 (1... 18-23 {A: -0.03})', PdnText) > 0,
        'explicit base ply should render after the display move; pdn="' +
        PdnText + '"');
      Check(Pos('base_ply', LowerCase(PdnText)) = 0,
        'internal variation metadata should not be exported as PDN comment');
    finally
      Game.Free;
    end;
  finally
    Variations.Free;
    VariationAnnotations.Free;
    ClearGames(Games);
    Games.Free;
    Lines.Free;
    if FileExists(FileName) then
      DeleteFile(FileName);
  end;
end;

procedure CheckMoveHistoryKeepsMoveAndAnnotationTogether;
var
  History: TGameMoveHistory;
  Moves: TStringList;
begin
  History := TGameMoveHistory.Create;
  Moves := TStringList.Create;
  try
    History.AddMove('034-030', dsWhite, 1.25, 'score=0.10', '30-25');
    History.AddMove('20-25', dsBlack, 0.75, 'score=-0.10', '');
    CheckEqual(History.MovesText, '34-30 20-25',
      'move history should expose pure canonical moves');
    CheckEqual(History.AnnotationsText, 'score=0.10' + LineEnding +
      'score=-0.10' + LineEnding,
      'move history should keep annotations aligned with moves');
    History.FillPureMoves(Moves);
    Check((Moves.Count = 2) and (Moves[0] = '34-30') and (Moves[1] = '20-25'),
      'move history should fill pure move lists for engine protocols');
  finally
    Moves.Free;
    History.Free;
  end;
end;

procedure CheckDatabaseImportSkipsExactDuplicates;
var
  Database: TGameDatabase;
  DbName: string;
  Duplicates: Integer;
  Errors: Integer;
  Games: TList;
  Imported: Integer;
  LogName: string;
  PdnName: string;
  Lines: TStringList;
begin
  DbName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'gwdgui_database_duplicate_check.sqlite';
  PdnName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'gwdgui_database_duplicate_check.pdn';
  LogName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'gwdgui_database_duplicate_check.import.log';
  Lines := TStringList.Create;
  Games := TList.Create;
  Database := TGameDatabase.Create;
  try
    if FileExists(DbName) then
      DeleteFile(DbName);
    if FileExists(LogName) then
      DeleteFile(LogName);
    Lines.Add('[Event "Duplicate Test"]');
    Lines.Add('[White "Alpha"]');
    Lines.Add('[Black "Beta"]');
    Lines.Add('[Result "*"]');
    Lines.Add('[FEN "W:W31-50:B1-20"]');
    Lines.Add('');
    Lines.Add('1. 34-30 20-25 *');
    Lines.Add('');
    Lines.Add('[Event "Duplicate Test"]');
    Lines.Add('[White "Alpha"]');
    Lines.Add('[Black "Beta"]');
    Lines.Add('[Result "*"]');
    Lines.Add('[FEN "W:W31-50:B1-20"]');
    Lines.Add('');
    Lines.Add('1. 34-30 20-25 *');
    Lines.Add('');
    Lines.Add('[Event "Duplicate Test"]');
    Lines.Add('[White "Alpha"]');
    Lines.Add('[Black "Beta"]');
    Lines.Add('[Result "2-0"]');
    Lines.Add('[FEN "W:W31-50:B1-20"]');
    Lines.Add('');
    Lines.Add('1. 34-30 20-25 2-0');
    Lines.Add('');
    Lines.Add('[Event "Duplicate Test"]');
    Lines.Add('[White "Gamma"]');
    Lines.Add('[Black "Delta"]');
    Lines.Add('[Result "*"]');
    Lines.Add('[FEN "W:W31-50:B1-20"]');
    Lines.Add('');
    Lines.Add('1. 34-30 20-25 *');
    Lines.SaveToFile(PdnName);

    Database.CreateDatabase(DbName);
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors, nil,
      LogName);
    CheckEqual(IntToStr(Imported), '3',
      'database import should keep same moves with different players or result');
    CheckEqual(IntToStr(Duplicates), '1',
      'database import should skip exact duplicate game');
    CheckEqual(IntToStr(Errors), '0',
      'database duplicate import should not count duplicates as errors');
    Database.LoadGames(Games);
    CheckEqual(IntToStr(Games.Count), '3',
      'database should contain only imported non-duplicate games');
    Lines.LoadFromFile(LogName);
    Check(Pos(#9 + 'duplicate' + #9, Lines.Text) > 0,
      'database import log should contain duplicate entry');
    Check(Pos(#9 + 'plies=2', Lines.Text) > 0,
      'database import log should contain duplicate ply count');
    Check(Pos('----- DUPLICATE PDN -----', Lines.Text) > 0,
      'database import log should contain duplicate PDN block');
  finally
    ClearGames(Games);
    Games.Free;
    Database.Free;
    Lines.Free;
    if FileExists(PdnName) then
      DeleteFile(PdnName);
    if FileExists(DbName) then
      DeleteFile(DbName);
    if FileExists(LogName) then
      DeleteFile(LogName);
  end;
end;

begin
  CheckPdnLoadAndAppend;
  CheckPdnGluedMoveNumbers;
  CheckPdnVariationImportExport;
  CheckMoveHistoryKeepsMoveAndAnnotationTogether;
  CheckDatabaseImportSkipsExactDuplicates;
  Writeln('OK');
end.
