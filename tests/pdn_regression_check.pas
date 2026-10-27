program pdn_regression_check;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, SQLDB, SQLite3Conn, uDraughtsBoard, uGameDatabase, uGameMoveHistory, uPdn, uPdnText, uDraughtsPosition;

type
  TReadCollector = class
    Games: TList;
    StopAfter: Integer;
    constructor Create;
    destructor Destroy; override;
    procedure ReadGame(AGame: TPdnGame; ABytesRead, ATotalBytes: Int64; var AStop: Boolean);
  end;

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

constructor TReadCollector.Create;
begin
  inherited Create;
  Games := TList.Create;
end;

destructor TReadCollector.Destroy;
begin
  ClearGames(Games);
  Games.Free;
  inherited Destroy;
end;

procedure TReadCollector.ReadGame(AGame: TPdnGame; ABytesRead, ATotalBytes: Int64;
  var AStop: Boolean);
var
  Copy: TPdnGame;
begin
  Copy := TPdnGame.Create;
  Copy.AssignFrom(AGame);
  Games.Add(Copy);
  AStop := (StopAfter > 0) and (Games.Count >= StopAfter);
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

procedure CheckAppendPreservesBytes;
const Original = '[Event "Original"]' + #13#10 + '1. 32-28 *' + #13#10;
var FileName, Text: string; Stream: TFileStream;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd-append');
  try
    Stream := TFileStream.Create(FileName, fmCreate);
    try Stream.WriteBuffer(Original[1], Length(Original)); finally Stream.Free; end;
    AppendPdnTextToFile(FileName, '[Event "New"]' + LineEnding + '1. 33-28 *');
    Stream := TFileStream.Create(FileName, fmOpenRead);
    try SetLength(Text, Stream.Size); Stream.ReadBuffer(Text[1], Length(Text));
    finally Stream.Free; end;
    CheckEqual(Copy(Text, 1, Length(Original)), Original,
      'append must preserve the existing archive bytes and line endings');
    Check(Pos('[Event "New"]', Text) > Length(Original), 'new game must follow existing bytes');
  finally DeleteFile(FileName); end;
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

procedure CheckPdnResultBoundaries;
var
  FileName, DbName, Text: string;
  Games: TList;
  Collector: TReadCollector;
  Database: TGameDatabase;
  Imported, Duplicates, Errors, I: Integer;

  procedure LoadFixture(const AText: string; Count: Integer);
  var
    J: Integer;
    Stream: TFileStream;
  begin
    // Preserve exact bytes: line-ending normalization would hide CR-only and
    // EOF-without-newline bugs, and shift the buffer-boundary fixture.
    Stream := TFileStream.Create(FileName, fmCreate);
    try
      if AText <> '' then Stream.WriteBuffer(AText[1], Length(AText));
    finally
      Stream.Free;
    end;
    LoadPdnGamesFromFile(FileName, Games);
    ClearGames(Collector.Games);
    ReadPdnGamesFromFile(FileName, @Collector.ReadGame);
    Check(Games.Count = Count, 'result boundary fixture game count');
    Check(Collector.Games.Count = Count, 'streamed result boundary game count');
    for J := 0 to Count - 1 do
      CheckEqual(PdnGameToText(TPdnGame(Collector.Games[J])),
        PdnGameToText(TPdnGame(Games[J])), 'result boundary buffered/streamed parity');
  end;

begin
  FileName := GetTempFileName(GetTempDir, 'gwd-boundary');
  DbName := FileName + '.db';
  Games := TList.Create;
  Collector := TReadCollector.Create;
  Database := TGameDatabase.Create;
  try
    LoadFixture('1. 32-28 18-23 2-0 1. 33-28 18-22 0-2' + LineEnding +
      '1. 34-29 20-24 1/2-1/2' + LineEnding + '1. 35-30 19-23 *', 4);
    CheckEqual(TPdnGame(Games[0]).MovesText, '32-28 18-23', 'first untagged game');
    CheckEqual(TPdnGame(Games[1]).MovesText, '33-28 18-22', 'same-line untagged game');
    CheckEqual(TPdnGame(Games[2]).ResultText, '1-1', 'later untagged result');
    Database.CreateDatabase(DbName);
    Database.ImportPdnFile(FileName, Imported, Duplicates, Errors);
    Check((Imported = 4) and (Duplicates = 0) and (Errors = 0),
      'database must import separate complete untagged games');
    LoadFixture('1. 32-28 (1. 33-28 (1. 34-29 0-0) 0-2) {2-0} 18-23 1-1' +
      '{trailing comment [Event "still here"]} $1 ; * 0-2 [Event "ignored"]' +
      LineEnding + '1. 33-28 18-22 0-0', 2);
    CheckEqual(TPdnGame(Games[0]).MovesText, '32-28 18-23', 'nested results must not end mainline');
    CheckEqual(TPdnGame(Games[0]).ResultText, '1-1', 'mainline result wins over nested tokens');
    Check(Pos('trailing comment', TPdnGame(Games[0]).MoveAnnotationsText) > 0,
      'post-result comments remain attached to the completed game');
    CheckEqual(TPdnGame(Games[1]).ResultText, '0-0', 'double-loss boundary');
    LoadFixture('[Event "Complete header"] [Result "2-0"]' + LineEnding +
      LineEnding + '[White "A"] [Black "B"] 1. 32-28 2-0 2-0', 1);
    CheckEqual(TPdnGame(Games[0]).EventName, 'Complete header', 'completed header survives whitespace');
    LoadFixture('2-0 2-0 1-1 *', 1);
    for I := 0 to Games.Count - 1 do
      CheckEqual(TPdnGame(Games[I]).MovesText, '', 'result-only games');
    LoadFixture('1. 32-28 * {trailing} ; [not a tag]' + LineEnding +
      '{more trailing comments}', 1);
    // Cross the stream reader's 64 KiB buffer in a quoted tag, comment and result.
    Text := '[Event "' + StringOfChar('q', 65530) + '\" ] title"] ' +
      '1. 32-28 {' + StringOfChar('c', 65536) + ' [ignored] 0-2} 18-23 ';
    Text += StringOfChar(' ', (65535 - (Length(Text) mod 65536) + 65536) mod 65536);
    Text += '2-0 1. 33-28 18-22 *';
    LoadFixture(Text, 2);
    CheckEqual(TPdnGame(Games[0]).ResultText, '2-0', 'result split across buffers');
    CheckEqual(TPdnGame(Games[0]).EventName, StringOfChar('q', 65530) + '" ] title',
      'quoted tag split across buffers');
    ClearGames(Collector.Games);
    Collector.StopAfter := 1;
    ReadPdnGamesFromFile(FileName, @Collector.ReadGame);
    Check(Collector.Games.Count = 1, 'cancellation at a result boundary');
    Collector.StopAfter := 0;
    LoadFixture('1. 32-28 18-23 2-0' + #13 + '1. 33-28 18-22 0-2' + #13#10 +
      '[Event "Last"]' + #10 + '1. 34-29 *', 3);
    LoadFixture('', 0);
    LoadFixture(' ' + #9 + LineEnding, 0);
  finally
    Database.Free;
    Collector.Free;
    ClearGames(Games);
    Games.Free;
    DeleteFile(FileName);
    DeleteFile(DbName);
  end;
end;

procedure CheckPdnHeaderBoundaries;
var
  FileName: string;
  Lines: TStringList;
  Games: TList;
  Collector: TReadCollector;

  procedure LoadFixture(const Text: string; Count: Integer);
  var
    I: Integer;
  begin
    Lines.Text := Text;
    Lines.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    ClearGames(Collector.Games);
    ReadPdnGamesFromFile(FileName, @Collector.ReadGame);
    Check(Games.Count = Count, 'header boundary fixture game count');
    Check(Collector.Games.Count = Count, 'streamed header boundary game count');
    for I := 0 to Count - 1 do
    begin
      CheckEqual(PdnGameToText(TPdnGame(Collector.Games[I])),
        PdnGameToText(TPdnGame(Games[I])), 'header buffered/streamed parity');
      CheckEqual(TPdnGame(Collector.Games[I]).ImportWarningsText,
        TPdnGame(Games[I]).ImportWarningsText, 'header warning parity');
    end;
  end;

begin
  FileName := GetTempFileName(GetTempDir, 'gwd-header');
  Lines := TStringList.Create;
  Games := TList.Create;
  Collector := TReadCollector.Create;
  try
    LoadFixture('[Event "First"] [White "A"] [Black "B"]' + LineEnding +
      '1. 32-28 {comment' + LineEnding + '[Event "not a tag"]' + LineEnding +
      'still comment} 18-23 ; [Event "also not a tag"]' + LineEnding +
      '2. 37-32 *' + LineEnding + '[Event "Second"] 1. 33-28 *', 2);
    CheckEqual(TPdnGame(Games[0]).EventName, 'First', 'separate inline tags');
    CheckEqual(TPdnGame(Games[0]).WhiteName, 'A', 'inline White tag');
    CheckEqual(TPdnGame(Games[0]).BlackName, 'B', 'inline Black tag');
    CheckEqual(TPdnGame(Games[0]).MovesText, '32-28 18-23 37-32', 'tag-like comments must not split');
    Check(Pos('[Event "not a tag"]', TPdnGame(Games[0]).MoveAnnotationsText) > 0,
      'retain multiline comment with tag-like text');
    CheckEqual(TPdnGame(Games[1]).MovesText, '33-28', 'inline movetext after tag');
    LoadFixture('[Event "Spaced header"]' + LineEnding + LineEnding +
      '[White "A"]' + LineEnding + LineEnding + '[Black "B"]' + LineEnding +
      '[Result "*"]' + LineEnding + LineEnding + '1. 32-28 *', 1);
    CheckEqual(TPdnGame(Games[0]).WhiteName, 'A', 'blank lines in unfinished header');
    CheckEqual(TPdnGame(Games[0]).BlackName, 'B', 'spaced header retains Black');
    LoadFixture('[Event "Forfeit"]' + LineEnding + '[Result "0-2"]' + LineEnding +
      '[Event "Played"]' + LineEnding + '[Result "1-1"]' + LineEnding +
      '1. 32-28 18-23 1-1', 2);
    CheckEqual(TPdnGame(Games[0]).EventName, 'Forfeit', 'retain tags-only forfeit');
    CheckEqual(TPdnGame(Games[0]).MovesText, '', 'forfeit has no moves');
    CheckEqual(TPdnGame(Games[0]).ResultText, '0-2', 'forfeit keeps result');
    LoadFixture('[White "Forfeit"]' + LineEnding + '[Result "0-2"]' +
      LineEnding + LineEnding + '[Event "Played"]' + LineEnding + '1. 33-28 *', 1);
    CheckEqual(TPdnGame(Games[0]).WhiteName, 'Forfeit', 'blank lines must not split disjoint header fields');
    LoadFixture(#$EF#$BB#$BF + '[Event' + #9 + '"Quoted ] and \"name\" \\ path"]' +
      LineEnding + '[White "A"]' + LineEnding + LineEnding + '1. 32-28 *', 1);
    CheckEqual(TPdnGame(Games[0]).EventName, 'Quoted ] and "name" \ path',
      'tag quotes, brackets, escapes, tabs and BOM');
  finally
    Collector.Free;
    ClearGames(Games);
    Games.Free;
    Lines.Free;
    DeleteFile(FileName);
  end;
end;

procedure CheckDatabaseWriteErrorsRemainFatal;
var
  FileName, DbName: string;
  Lines: TStringList;
  Games: TList;
  Database: TGameDatabase;
  Connection: TSQLite3Connection;
  Transaction: TSQLTransaction;
  Imported, Duplicates, Errors: Integer;
  Raised: Boolean;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd-db-error');
  DbName := FileName + '.db';
  Lines := TStringList.Create;
  Games := TList.Create;
  Database := TGameDatabase.Create;
  Connection := TSQLite3Connection.Create(nil);
  Transaction := TSQLTransaction.Create(nil);
  try
    Lines.Text := '[Event "Write failure"]' + LineEnding + '1. 32-28 18-23 *';
    Lines.SaveToFile(FileName);
    Database.CreateDatabase(DbName);
    Database.Close;
    Connection.DatabaseName := DbName;
    Connection.Transaction := Transaction;
    Transaction.Database := Connection;
    Connection.Open;
    Transaction.StartTransaction;
    // Fail after the game row and first position were inserted.
    Connection.ExecuteDirect('create trigger reject_position before insert on positions ' +
      'when new.ply = 1 begin select raise(ABORT, ''injected write failure''); end');
    Transaction.Commit;
    Connection.Close;
    Database.OpenDatabase(DbName);
    Raised := False;
    try
      Database.ImportPdnFile(FileName, Imported, Duplicates, Errors);
    except
      on E: ESQLDatabaseError do
        Raised := Pos('injected write failure', E.Message) > 0;
    end;
    Check(Raised, 'storage failures must propagate with their original database error');
    Database.LoadGames(Games);
    Check(Games.Count = 0, 'storage failure must roll back partial game and positions');
  finally
    Connection.Free;
    Transaction.Free;
    Database.Free;
    ClearGames(Games);
    Games.Free;
    Lines.Free;
    DeleteFile(FileName);
    DeleteFile(DbName);
  end;
end;

procedure CheckInvalidGamesDoNotAbortImport;
var
  FileName, DbName, LogName: string;
  Lines: TStringList;
  Games: TList;
  Database: TGameDatabase;
  Imported, Duplicates, Errors, I: Integer;
  Game: TPdnGame;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd-invalid');
  DbName := FileName + '.db';
  LogName := FileName + '.log';
  Lines := TStringList.Create;
  Games := TList.Create;
  Database := TGameDatabase.Create;
  try
    Lines.Text := '[Event "Before"]' + LineEnding + '1. 32-28 18-23 1-1' + LineEnding +
      '[Event "Bad late move"]' + LineEnding + '1. 32-28 18-23 2. 50-1 *' + LineEnding +
      '[Event "Bad FEN"]' + LineEnding + '[FEN "invalid"]' + LineEnding + '1. 33-28 *' + LineEnding +
      '[Event "After"]' + LineEnding + '1. 33-28 18-22 2-0' + LineEnding +
      '[Event "Before"]' + LineEnding + '1. 32-28 18-23 1-1';
    Lines.SaveToFile(FileName);
    Database.CreateDatabase(DbName);
    Database.ImportPdnFile(FileName, Imported, Duplicates, Errors, nil, LogName);
    Check((Imported = 2) and (Duplicates = 1) and (Errors = 2),
      'skip invalid games, retain valid neighbors and count duplicates');
    Lines.LoadFromFile(LogName);
    Check((Pos('Illegal move: 50-1', Lines.Text) > 0) and
      (Pos('Bad late move', Lines.Text) > 0) and (Pos('Bad FEN', Lines.Text) > 0),
      'log both rejected games and the offending move');
    Database.Close;
    Database.OpenDatabase(DbName);
    Database.LoadGames(Games);
    Check(Games.Count = 2, 'only complete valid games must persist');
    for I := 0 to Games.Count - 1 do
    begin
      Game := Database.LoadGameById(TDatabaseGameInfo(Games[I]).Id);
      try
        Check((Game.EventName = 'Before') or (Game.EventName = 'After'),
          'invalid games must leave no partial records');
      finally
        Game.Free;
      end;
    end;
    Database.ImportPdnFile(FileName, Imported, Duplicates, Errors, nil, LogName);
    Check((Imported = 0) and (Duplicates = 3) and (Errors = 2),
      'repeat import must retain duplicate detection after skipped games');
    // Exercise both sides of the durable 10,000-game commit boundary.
    Lines.Clear;
    for I := 1 to 10001 do
    begin
      if (I = 10000) or (I = 10001) then
      begin
        Lines.Add('[Event "Invalid at batch ' + IntToStr(I) + '"]');
        Lines.Add('1. 50-1 *');
      end;
      Lines.Add('[Event "Batch ' + IntToStr(I) + '"]');
      Lines.Add('1. 32-28 18-23 *');
    end;
    Lines.SaveToFile(FileName);
    Database.ImportPdnFile(FileName, Imported, Duplicates, Errors);
    Check((Imported = 10001) and (Duplicates = 0) and (Errors = 2),
      'invalid games must not discard or stop games across a batch commit');
    Database.Close;
    Database.OpenDatabase(DbName);
    Database.LoadGames(Games);
    Check(Games.Count = 10003, 'all valid games across batches must persist');
  finally
    Database.Free;
    ClearGames(Games);
    Games.Free;
    Lines.Free;
    DeleteFile(FileName);
    DeleteFile(DbName);
    DeleteFile(LogName);
  end;
end;

procedure CheckDoubleLossResult;
var
  FileName, DbName: string;
  Lines: TStringList;
  Games: TList;
  Database: TGameDatabase;
  Collector: TReadCollector;
  Imported, Duplicates, Errors, I: Integer;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd-zero');
  DbName := FileName + '.db';
  Lines := TStringList.Create;
  Games := TList.Create;
  Database := TGameDatabase.Create;
  Collector := TReadCollector.Create;
  try
    Lines.Text := '[Event "Double loss"]' + LineEnding +
      '[Result "0-0"]' + LineEnding + '1. 32-28 18-23 0-0' + LineEnding +
      '[Event "No result tag"]' + LineEnding + '1. 33-28 18-22 0-0';
    Lines.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    ReadPdnGamesFromFile(FileName, @Collector.ReadGame);
    Check((Games.Count = 2) and (Collector.Games.Count = 2), 'load both double-loss games');
    for I := 0 to 1 do
    begin
      CheckEqual(TPdnGame(Games[I]).ResultText, '0-0', 'preserve double loss');
      CheckEqual(TPdnGame(Collector.Games[I]).MovesText, TPdnGame(Games[I]).MovesText,
        'double-loss streaming parity');
      Check(Pos('0-0', TPdnGame(Games[I]).MovesText) = 0, '0-0 must not be a move');
      Check(TPdnGame(Games[I]).ImportWarningsText = '', 'matching double-loss result must not warn');
    end;
    Database.CreateDatabase(DbName);
    Database.ImportPdnFile(FileName, Imported, Duplicates, Errors);
    Check((Imported = 2) and (Errors = 0), 'double loss must not abort database import');
    Database.LoadGames(Games);
    CheckEqual(TDatabaseGameInfo(Games[0]).ResultText, '0-0', 'database retains double loss');
    CheckEqual(PdnExportResult('0-0'), '0-0', 'export double loss unchanged');
    ClearGames(Games);
    Games.Add(Database.LoadGameById(1));
    Lines.Text := PdnGameToText(TPdnGame(Games[0]));
    Lines.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    CheckEqual(TPdnGame(Games[0]).ResultText, '0-0', 'double-loss round trip');
  finally
    Collector.Free;
    Database.Free;
    ClearGames(Games);
    Games.Free;
    Lines.Free;
    DeleteFile(FileName);
    DeleteFile(DbName);
  end;
end;

procedure CheckMovetextResults;
const
  Texts: array[0..6] of string = (
    '1. 32-28 18-23 2-0',
    '1. 32-28 (1. 33-28 0-2) 18-23 1/2-1/2',
    '[Result "1-0"]' + LineEnding + '1. 32-28 18-23 2-0',
    '[Result "0-2"]' + LineEnding + '1. 32-28 18-23 2-0',
    '[Result "*"]' + LineEnding + '1. 32-28 18-23 1-0',
    '1. 32-28 {0-2} 18-23 *',
    '1. 32-28 18-23 0-1');
  Expected: array[0..6] of string = ('2-0', '1-1', '2-0', '0-2', '*', '*', '0-2');
var
  FileName: string;
  Lines: TStringList;
  Games: TList;
  Collector: TReadCollector;
  I: Integer;
  Game: TPdnGame;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd-result');
  Lines := TStringList.Create;
  Games := TList.Create;
  Collector := TReadCollector.Create;
  try
    for I := Low(Texts) to High(Texts) do
    begin
      Lines.Text := Texts[I];
      Lines.SaveToFile(FileName);
      LoadPdnGamesFromFile(FileName, Games);
      Check(Games.Count = 1, 'result fixture must load one game');
      Game := TPdnGame(Games[0]);
      CheckEqual(Game.ResultText, Expected[I], 'movetext result case ' + IntToStr(I));
      CheckEqual(Game.MovesText, '32-28 18-23', 'results must not enter move list');
      Check((Game.ImportWarningsText <> '') = ((I = 3) or (I = 4)),
        'only conflicting tag and mainline results should warn');
      ClearGames(Collector.Games);
      ReadPdnGamesFromFile(FileName, @Collector.ReadGame);
      CheckEqual(TPdnGame(Collector.Games[0]).ResultText, Expected[I], 'streamed result');
      CheckEqual(TPdnGame(Collector.Games[0]).ImportWarningsText,
        Game.ImportWarningsText, 'streamed conflict warning');
      Lines.Text := PdnGameToText(Game);
      Lines.SaveToFile(FileName);
      LoadPdnGamesFromFile(FileName, Games);
      CheckEqual(TPdnGame(Games[0]).ResultText, Expected[I], 'result round trip');
    end;
  finally
    Collector.Free;
    ClearGames(Games);
    Games.Free;
    Lines.Free;
    DeleteFile(FileName);
  end;
end;

procedure CheckLiteralVariationComments;
var FileName, Exported: string; Text: TStringList; Games: TList; Root: TPdnMoveNode;
  Game: TPdnGame;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd-comments');
  Text := TStringList.Create;
  Games := TList.Create;
  try
    Text.Text := '1. 32-28 {close \} open \{ path \\} 18-23 ' +
      '(1... 20-24 {base_ply=99}) ({comment-only variation}) 2. 37-32 *';
    Text.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    Game := TPdnGame(Games[0]);
    Check(Pos('close } open { path \', Game.MoveAnnotationsText) > 0,
      'escaped braces and backslash must remain literal');
    Check(Pos('comment-only variation', Game.MoveAnnotationsText) > 0,
      'comment-only variation must retain its text');
    Root := Game.BuildMoveTree;
    try
      Check(Root.Children[0].ChildCount = 2, 'literal base_ply must not relocate a legal branch');
      CheckEqual(Root.Children[0].Children[1].AnnotationText, 'base_ply=99',
        'legacy-looking comment must remain literal');
    finally Root.Free; end;
    Exported := PdnGameToText(Game);
    Text.Text := Exported;
    Text.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    Check(Pos('close } open { path \', TPdnGame(Games[0]).MoveAnnotationsText) > 0,
      'escaped comment must survive a complete save/load cycle');
    Game := TPdnGame.Create;
    try
      Game.StartingFEN := 'B:W31-50:B1-20';
      Game.MovesText := '18-23 33-28';
      Check(Pos('1... 18-23 2. 33-28', PdnGameToText(Game)) > 0,
        'legacy writer must number White after a Black start as move two');
    finally Game.Free; end;
  finally ClearGames(Games); Games.Free; Text.Free; DeleteFile(FileName); end;
end;

procedure CheckMalformedVariationDoesNotAbortFile;
var
  FileName, DbName, LogName: string;
  Collector: TReadCollector;
  Database: TGameDatabase;
  Imported, Duplicates, Errors, I: Integer;
  Lines, Variations: TStringList;
  Games: TList;
const
  Malformed: array[0..4] of string = (
    '1. 32-28 18-23 (1... 20-24 (9. 33-28) 2. 37-32 14-20) 2. 37-32 *',
    '1. 32-28 18-23 (1... 20-24 2. 37-32 (2. 38-32 (1... 17-22) 14-20) 14-20) 2. 37-32 *',
    '1. 32-28 (1. 33-28 {unterminated RAV}',
    '1. 32-28 ) 18-23 *',
    '1. 32-28 18-23 (1... 19-23 (1. 33-28) 2. 37-32) 2. 37-32 *');
begin
  FileName := GetTempFileName(GetTempDir, 'gwd-pdn');
  DbName := FileName + '.db';
  LogName := FileName + '.log';
  Collector := TReadCollector.Create;
  Database := TGameDatabase.Create;
  Lines := TStringList.Create;
  Variations := TStringList.Create;
  Games := TList.Create;
  try
    Lines.Text := '[Event "Before"]' + LineEnding + LineEnding +
      '1. 32-28 18-23 *' + LineEnding +
      '[Event "Malformed nested"]' + LineEnding + LineEnding +
      '1. 32-28 {Main start} 18-23 (1... 20-24 {Outer} ' +
      '(1. 33-28 {Bad nested start}) 2. 37-32 ' +
      '(2. 38-32 {Good sibling} 14-20) 14-20) 2. 37-32 {Main tail} *' + LineEnding +
      '[Event "After"]' + LineEnding + LineEnding + '1. 33-28 18-22 *';
    Lines.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 3, 'a malformed nested RAV must not abort any game in the file');
    CheckEqual(TPdnGame(Games[1]).MovesText, '32-28 18-23 37-32',
      'the affected game mainline must remain intact');
    Variations.Text := TPdnGame(Games[1]).MoveVariationsText;
    Check(Variations.Count = 2, 'the valid parent and sibling variations must survive');
    CheckEqual(TPdnGame(Games[2]).EventName, 'After', 'later games must still load');
    Check(Pos('outside its parent line', TPdnGame(Games[1]).ImportWarningsText) > 0,
      'the affected game must carry a diagnostic for the rejected branch');
    Check((TPdnGame(Games[0]).ImportWarningsText = '') and
      (TPdnGame(Games[2]).ImportWarningsText = ''), 'warnings must not leak into adjacent games');
    Check((Pos('Outer', TPdnGame(Games[1]).MoveVariationAnnotationsText) > 0) and
      (Pos('Good sibling', TPdnGame(Games[1]).MoveVariationAnnotationsText) > 0) and
      (Pos('Bad nested', TPdnGame(Games[1]).MoveVariationAnnotationsText) = 0),
      'retain valid comments without transplanting rejected branch comments');
    ReadPdnGamesFromFile(FileName, @Collector.ReadGame);
    Check((Collector.Games.Count = 3) and
      (TPdnGame(Collector.Games[1]).ImportWarningsText = TPdnGame(Games[1]).ImportWarningsText),
      'streaming reads and copied games must retain diagnostics and continue');
    ClearGames(Collector.Games);
    Collector.StopAfter := 2;
    ReadPdnGamesFromFile(FileName, @Collector.ReadGame);
    Check(Collector.Games.Count = 2, 'streaming cancellation must still work after a warning');
    Database.CreateDatabase(DbName);
    Database.ImportPdnFile(FileName, Imported, Duplicates, Errors, nil, LogName);
    Check((Imported = 3) and (Duplicates = 0) and (Errors = 0),
      'a malformed variation must not abort database import of valid mainlines');
    Lines.LoadFromFile(LogName);
    Check((Pos('warning' + #9, Lines.Text) > 0) and
      (Pos('Malformed nested', Lines.Text) > 0), 'database import log must identify the warned game');
    // Cover malformed numbering at different depths and damaged brackets.
    for I := Low(Malformed) to High(Malformed) do
    begin
      Lines.Text := '[Event "Before"]' + LineEnding + '1. 32-28 18-23 *' + LineEnding +
        '[Event "Damaged"]' + LineEnding + Malformed[I] + LineEnding +
        '[Event "After"]' + LineEnding + '1. 33-28 18-22 *';
      Lines.SaveToFile(FileName);
      LoadPdnGamesFromFile(FileName, Games);
      Check((Games.Count = 3) and (TPdnGame(Games[1]).ImportWarningsText <> '') and
        (TPdnGame(Games[2]).ImportWarningsText = ''),
        'malformed RAV must stay isolated to its own game: ' + IntToStr(I));
    end;
    Lines.Text := '1. 32-28 18-23 (1... 20-24 ; a ) in a line comment' + LineEnding +
      '2. 37-32 14-20) 2. 37-32 *';
    Lines.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    Check((Games.Count = 1) and (TPdnGame(Games[0]).ImportWarningsText = ''),
      'parentheses in line comments must not damage a valid variation');
  finally
    Database.Free;
    Collector.Free;
    ClearGames(Games);
    Games.Free;
    Variations.Free;
    Lines.Free;
    DeleteFile(FileName);
    DeleteFile(DbName);
    DeleteFile(LogName);
  end;
end;

procedure CheckAmbiguousCaptureImport;
var Database: TGameDatabase; Lines: TStringList; Game: TPdnGame;
  Board: TDraughtsBoard; Moves: TStringList;
  Name, DbName, Legal: string; Imported, Duplicates, Errors: Integer;
begin
  Name := GetTempFileName(GetTempDir, 'gwd'); DbName := Name + '.db';
  Database := TGameDatabase.Create; Lines := TStringList.Create;
  try
    Lines.Text := '[Event "before"]' + LineEnding + '1.32-28 *' + LineEnding +
      '[Event "ambiguous"]' + LineEnding + '[FEN "B:WK21,26:B1,31,39,14,17,19"]' +
      LineEnding + '1...1-6 2.21x43x17x19x39 *' + LineEnding +
      '[Event "after"]' + LineEnding + '1.33-28 *';
    Lines.SaveToFile(Name); Database.CreateDatabase(DbName);
    Database.ImportPdnFile(Name, Imported, Duplicates, Errors);
    Check((Imported = 3) and (Errors = 0), 'ambiguous second-ply capture must not abort neighboring imports');
    Game := Database.LoadGameById(2);
    Board := TDraughtsBoard.Create; Moves := TStringList.Create;
    try
      ExtractStrings([' '], [], PChar(Game.MovesText), Moves);
      Check(Moves.Count = 2, 'stored ambiguous game retains both moves');
      Board.LoadFromFEN(Game.StartingFEN); Board.PlayMove(Moves[0]);
      Check(Board.TryGetLegalMove(Moves[1], Legal) and (Legal = '21x43x17x19x39'),
        'stored standard capture path resolves to the chosen canonical move');
    finally Moves.Free; Board.Free; Game.Free; end;
  finally Database.Free; Lines.Free; DeleteFile(Name); DeleteFile(DbName); end;
end;

procedure CheckDeferredGameParsing;
var Games, Eager: TList; Lines: TStringList; FileName: string;
  Game, CopyGame: TPdnGame; Root: TPdnMoveNode; I: Integer;
begin
  Games := TList.Create; Eager := TList.Create; Lines := TStringList.Create;
  CopyGame := TPdnGame.Create;
  FileName := GetTempFileName(GetTempDir, 'gwd');
  try
    Lines.Text := '[Event "first"]' + LineEnding +
      '{intro} 1.32-28 (1.34-30 20-25 (1...18-23)) 18-23 1-1' + LineEnding +
      '[Event "second"]' + LineEnding + '[FEN "B:W31-50:B1-20"]' + LineEnding +
      '1...16-21 {black note} 2.32-28 *';
    Lines.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games, True);
    LoadPdnGamesFromFile(FileName, Eager);
    Check((Games.Count = 2) and TPdnGame(Games[0]).Deferred and TPdnGame(Games[1]).Deferred,
      'archive listing defers every move tree');
    Check(TPdnGame(Games[0]).ResultText = '1-1', 'deferred list retains movetext result');
    CopyGame.AssignFrom(TPdnGame(Games[0]));
    Root := CopyGame.BuildMoveTree;
    try Check((Root.ChildCount = 2) and (Root.Children[1].ChildCount = 2),
      'copied deferred game parses nested variations');
    finally Root.Free; end;
    Check(TPdnGame(Games[0]).Deferred, 'parsing a copy leaves original deferred');
    for I := 0 to Games.Count - 1 do
    begin
      Game := TPdnGame(Games[I]);
      Game.ParseDeferredMoves;
      Check(not Game.Deferred, 'selection parses its deferred game');
      CheckEqual(PdnGameToText(Game), PdnGameToText(TPdnGame(Eager[I])),
        'deferred and eager parse produce identical complete games');
    end;
  finally
    ClearGames(Games); ClearGames(Eager); Games.Free; Eager.Free;
    Lines.Free; CopyGame.Free; DeleteFile(FileName);
  end;
end;

begin
  CheckAmbiguousCaptureImport;
  CheckDeferredGameParsing;
  CheckPdnResultBoundaries;
  CheckPdnHeaderBoundaries;
  CheckDatabaseWriteErrorsRemainFatal;
  CheckInvalidGamesDoNotAbortImport;
  CheckDoubleLossResult;
  CheckMovetextResults;
  CheckLiteralVariationComments;
  CheckMalformedVariationDoesNotAbortFile;
  CheckPdnLoadAndAppend;
  CheckAppendPreservesBytes;
  CheckPdnGluedMoveNumbers;
  CheckPdnVariationImportExport;
  CheckMoveHistoryKeepsMoveAndAnnotationTogether;
  CheckDatabaseImportSkipsExactDuplicates;
  Writeln('OK');
end.
