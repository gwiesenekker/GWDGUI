program database_import_recovery_check;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, Process, SQLite3Conn, SQLDB, uDraughtsBoard, uGameDatabase, uPdn, uGameTreeNodeData;

type
  TImportObserver = class
    Database: TGameDatabase;
    CrashAfterBatch: Boolean;
    CrashAt: Integer;
    CancelAfter: Integer;
    RebuildDuringImport: Boolean;
    Calls: Integer;
    procedure Progress(ABytesRead, ATotalBytes: Int64; AImported, ADuplicates,
      AErrors: Integer; var ACancel: Boolean);
  end;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then raise Exception.Create(MessageText);
end;

procedure FreeItems(Items: TList);
var
  I: Integer;
begin
  for I := 0 to Items.Count - 1 do TObject(Items[I]).Free;
  Items.Clear;
end;

procedure CheckStats(Database: TGameDatabase; Draws: Integer);
var
  Board: TDraughtsBoard;
  Items: TList;
  Item: TDatabaseSearchResult;
begin
  Board := TDraughtsBoard.Create;
  Items := TList.Create;
  try
    Database.SearchPosition(Board.PositionKey, dsWhite, Items);
    Check(Items.Count = 1, 'root must have one continuation');
    Item := TDatabaseSearchResult(Items[0]);
    Check((Item.MoveText = '32-28') and (Item.GameCount = Draws + 1) and
      (Item.Wins = 1) and (Item.Draws = Draws) and (Item.Losses = 0),
      'White statistics must agree with imported games, including an old nonempty summary');
    Board.PlayMove('32-28');
    Database.SearchPosition(Board.PositionKey, dsBlack, Items);
    Check(Items.Count = 1, 'Black must have one continuation');
    Item := TDatabaseSearchResult(Items[0]);
    Check((Item.MoveText = '18-23') and (Item.GameCount = Draws + 1) and
      (Item.Wins = 0) and (Item.Draws = Draws) and (Item.Losses = 1),
      'Black statistics must agree with imported games');
  finally
    FreeItems(Items);
    Items.Free;
    Board.Free;
  end;
end;

procedure CheckIndexes(const FileName: string); forward;

procedure TImportObserver.Progress(ABytesRead, ATotalBytes: Int64;
  AImported, ADuplicates, AErrors: Integer; var ACancel: Boolean);
begin
  Inc(Calls);
  // Halt bypasses importer cleanup, database destruction and summary rebuild.
  if CrashAfterBatch then
  begin
    if AImported = CrashAt then Halt(73);
    Exit;
  end;
  CheckStats(Database, AImported);
  CheckIndexes(Database.FileName);
  if RebuildDuringImport and (AImported = 1) then
    Database.RebuildContinuationSummary;
  if CancelAfter > 0 then ACancel := AImported >= CancelAfter;
end;

procedure WriteGames(const FileName, Prefix: string; Count: Integer; const Score: string);
var
  Text: TStringList;
  I: Integer;
begin
  Text := TStringList.Create;
  try
    for I := 1 to Count do
    begin
      Text.Add('[Event "' + Prefix + IntToStr(I) + '"]');
      Text.Add('1. 32-28 18-23 ' + Score);
    end;
    Text.SaveToFile(FileName);
  finally
    Text.Free;
  end;
end;

procedure RawSQL(const FileName, SQL: string);
var
  Connection: TSQLite3Connection;
  Transaction: TSQLTransaction;
begin
  Connection := TSQLite3Connection.Create(nil);
  Transaction := TSQLTransaction.Create(nil);
  try
    Connection.DatabaseName := FileName;
    Connection.Transaction := Transaction;
    Transaction.Database := Connection;
    Connection.Open;
    Transaction.StartTransaction;
    Connection.ExecuteDirect(SQL);
    Transaction.Commit;
  finally
    Connection.Free;
    Transaction.Free;
  end;
end;

function Scalar(const FileName, SQL: string): Int64;
var
  Connection: TSQLite3Connection;
  Transaction: TSQLTransaction;
  Query: TSQLQuery;
begin
  Connection := TSQLite3Connection.Create(nil);
  Transaction := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Connection.DatabaseName := FileName;
    Connection.Transaction := Transaction;
    Transaction.Database := Connection;
    Query.Database := Connection;
    Query.Transaction := Transaction;
    Connection.Open;
    Query.SQL.Text := SQL;
    Query.Open;
    Result := Query.Fields[0].AsLargeInt;
    Query.Close;
    Transaction.Commit;
  finally
    Query.Free;
    Connection.Free;
    Transaction.Free;
  end;
end;

procedure CheckIndexes(const FileName: string);
begin
  Check(Scalar(FileName, 'select count(*) from sqlite_master where type=''index'' and name in (' +
    '''idx_games_hash'', ''idx_games_white'', ''idx_games_black'', ''idx_games_event'', ' +
    '''idx_positions_search'', ''idx_positions_game'')') = 6,
    'all import/search indexes must exist during import and after interruption');
end;

procedure CheckLiveSummary(const DbName, PdnName: string);
var
  Database: TGameDatabase;
  Observer: TImportObserver;
  Imported, Duplicates, Errors: Integer;
begin
  Database := TGameDatabase.Create;
  Observer := TImportObserver.Create;
  try
    Database.CreateDatabase(DbName);
    WriteGames(PdnName, 'Seed', 1, '2-0');
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    Observer.Database := Database;
    Observer.RebuildDuringImport := True;
    WriteGames(PdnName, 'Live', 3, '1-1');
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors, @Observer.Progress);
    Check((Imported = 3) and (Duplicates = 0) and (Errors = 0) and (Observer.Calls > 0),
      'live import fixture must report progress and import three games');
    CheckStats(Database, 3);
    Check(Scalar(DbName, 'select summary_dirty from database_state where id=1') = 0,
      'successful summary rebuild must atomically mark the summary clean');
    // Reset to the seed so the observer's expected totals remain independent.
    Database.Close;
    DeleteFile(DbName);
    Database.CreateDatabase(DbName);
    WriteGames(PdnName, 'Seed', 1, '2-0');
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    WriteGames(PdnName, 'Cancelled', 3, '1-1');
    Observer.CancelAfter := 1;
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors, @Observer.Progress);
    Check(Imported = 1, 'cancellation must stop after the requested game');
    CheckStats(Database, 1);
    Check(Scalar(DbName, 'select summary_dirty from database_state where id=1') = 0,
      'normal cancellation must finish with a clean summary for the committed games');
  finally
    Observer.Free;
    Database.Free;
  end;
end;

procedure CheckFailedRebuild(const DbName, PdnName: string);
var
  Database: TGameDatabase;
  Imported, Duplicates, Errors: Integer;
  Raised: Boolean;
begin
  Database := TGameDatabase.Create;
  try
    Database.CreateDatabase(DbName);
    WriteGames(PdnName, 'Seed', 1, '2-0');
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    Database.Close;
    RawSQL(DbName, 'create trigger reject_summary before insert on continuations ' +
      'begin select raise(ABORT, ''injected summary failure''); end');
    Database.OpenDatabase(DbName);
    WriteGames(PdnName, 'Failed rebuild', 2, '1-1');
    Raised := False;
    try
      Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    except
      on E: ESQLDatabaseError do
        Raised := Pos('injected summary failure', E.Message) > 0;
    end;
    Check(Raised, 'summary rebuild failure must propagate');
    Check(Scalar(DbName, 'select summary_dirty from database_state where id=1') = 1,
      'failed rebuild must never publish a clean flag');
    Check(Scalar(DbName, 'select sum(game_count) from continuations where next_move=''32-28''') = 1,
      'failed rebuild must roll back deletion and retain the prior summary');
    CheckStats(Database, 2);
    CheckIndexes(DbName);
    RawSQL(DbName, 'drop trigger reject_summary');
    Database.Close;
    Database.OpenDatabase(DbName);
    CheckStats(Database, 2);
    Check(Scalar(DbName, 'select summary_dirty from database_state where id=1') = 0,
      'subsequent open must recover a failed rebuild');
  finally
    Database.Free;
  end;
end;

procedure CheckAbruptRecovery(const DbName, PdnName: string);
var
  Database: TGameDatabase;
  Child: TProcess;
  Imported, Duplicates, Errors: Integer;
begin
  Database := TGameDatabase.Create;
  Child := TProcess.Create(nil);
  try
    Database.CreateDatabase(DbName);
    WriteGames(PdnName, 'Seed', 1, '2-0');
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    Database.Close;
    WriteGames(PdnName, 'Crash', 10000, '1-1');
    Child.Executable := ExpandFileName(ParamStr(0));
    Child.Parameters.Add('--crash-import');
    Child.Parameters.Add(DbName);
    Child.Parameters.Add(PdnName);
    Child.Options := [poWaitOnExit];
    Child.Execute;
    Check(Child.ExitStatus = 73, 'child must exit abruptly just after a committed import batch');
    CheckIndexes(DbName);
    Check(Scalar(DbName, 'select count(*) from games') = 10001,
      'the committed batch must survive abrupt process exit');
    Check(Scalar(DbName, 'select summary_dirty from database_state where id=1') = 1,
      'interrupted import must leave a durable dirty summary flag');
    Database.OpenDatabase(DbName);
    CheckStats(Database, 10000);
    Check(Scalar(DbName, 'select summary_dirty from database_state where id=1') = 0,
      'opening the interrupted database must repair and mark its summary clean');
    Database.Close;
    // Old databases have no freshness state: never trust their existing summary.
    RawSQL(DbName, 'drop table database_state');
    RawSQL(DbName, 'update continuations set game_count=999999');
    Database.OpenDatabase(DbName);
    CheckStats(Database, 10000);
    CheckIndexes(DbName);
    Database.Close;
    // Recovery of old interrupted imports must also restore missing indexes.
    RawSQL(DbName, 'drop index idx_positions_search');
    RawSQL(DbName, 'drop index idx_positions_game');
    Database.OpenDatabase(DbName);
    CheckIndexes(DbName);
    Database.Close;
    // Kill with one additional game still uncommitted after the durable batch.
    WriteGames(PdnName, 'Uncommitted', 10001, '1-1');
    Child.Parameters.Clear;
    Child.Parameters.Add('--crash-import');
    Child.Parameters.Add(DbName);
    Child.Parameters.Add(PdnName);
    Child.Parameters.Add('10001');
    Child.Execute;
    Check(Child.ExitStatus = 73, 'child must exit with an uncommitted partial batch');
    CheckIndexes(DbName);
    Check(Scalar(DbName, 'select count(*) from games') = 20001,
      'interruption must retain committed batches and roll back the final game');
    Check(Scalar(DbName, 'select count(*) from positions') = 60003,
      'the uncommitted game must not leave partial position rows');
    Database.OpenDatabase(DbName);
    CheckStats(Database, 20000);
    CheckIndexes(DbName);
  finally
    Child.Free;
    Database.Free;
  end;
end;

procedure CheckCompleteGameStorage(const DbName, PdnName: string);
var Database: TGameDatabase; Lines: TStringList; Game: TPdnGame;
  Items: TList; Matches: Integer;
  Root: TPdnMoveNode; Data: TGameTreeNodeData; Imported, Duplicates, Errors: Integer;
  Raised: Boolean;
begin
  Database := TGameDatabase.Create; Lines := TStringList.Create;
  try
    Data := Default(TGameTreeNodeData); Data.CommentText := 'branch note';
    Data.EnginePV := '20-25'; Data.EnginePVDepth := '20';
    Lines.Text := '[Event "Über"]' + LineEnding + '[White "Émile_50%"]' + LineEnding +
      '[Black "ИВАН"]' + LineEnding +
      '{introduction} 1.32-28 (1.34-30 {branch note} {' +
      EncodeNodeData(Data, 'branch note') + '} 20-25 (1...18-23)) 18-23 *';
    Lines.SaveToFile(PdnName);
    Database.CreateDatabase(DbName);
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    Check((Imported = 1) and (Errors = 0), 'complete import succeeds');
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    Check((Imported = 0) and (Duplicates = 1), 'complete duplicate recognized');
    Lines.Text := StringReplace(Lines.Text, 'introduction', 'revised introduction', []);
    Lines.SaveToFile(PdnName);
    Database.ImportPdnFile(PdnName, Imported, Duplicates, Errors);
    Check(Imported = 1, 'distinct annotation must not disappear as duplicate');
    Database.Close; Database.OpenDatabase(DbName);
    Game := Database.LoadGameById(1);
    try
      Root := Game.BuildMoveTree;
      try
        Check(Root.AnnotationText = 'introduction', 'database retains initial comment');
        Check(Root.ChildCount = 2, 'database retains root variation');
        Check(Root.Children[1].ChildCount = 2, 'database retains nested variation');
        Check(Root.Children[1].HasNodeData and
          (Root.Children[1].NodeData.EnginePVDepth = '20'), 'database retains typed analysis');
      finally Root.Free; end;
    finally Game.Free; end;
    Database.Close;
    Database.OpenDatabase(DbName);
    Items := TList.Create;
    try
      Database.LoadGames(Items, 0, 'émile_50%', 'иван', 'über', '', dgscId, False, Matches);
      Check(Matches = 2, 'Unicode filters match accents and Cyrillic across case');
      FreeItems(Items);
      Database.LoadGames(Items, 0, 'émileX50X', '', '', '', dgscId, False, Matches);
      Check(Matches = 0, 'percent and underscore are literal filter characters');
      FreeItems(Items);
      Database.LoadGames(Items, 0, '', '', '', 'иван', dgscWhite, False, Matches);
      Check(Matches = 2, 'either-player filter uses Unicode folding');
    finally FreeItems(Items); Items.Free; end;
    Database.Close;
    Check(Scalar(DbName, 'pragma user_version') = 4, 'complete schema version persisted');
    RawSQL(DbName, 'alter table games drop column full_pdn');
    RawSQL(DbName, 'pragma user_version=0');
    Database.OpenDatabase(DbName);
    Game := Database.LoadGameById(1);
    try Check(Game.MovesText = '32-28 18-23', 'legacy migration preserves canonical moves');
    finally Game.Free; end;
    Database.Close;
    Check(Scalar(DbName, 'pragma user_version') = 4, 'legacy schema migrated');
    Raised := False;
    try Database.CreateDatabase(DbName); except on E: EInvalidOperation do Raised := True; end;
    Check(Raised, 'create must not silently append to an existing database');
    Check(Scalar(DbName, 'select count(*) from games') = 2, 'refused create preserves games');
    RawSQL(DbName, 'pragma user_version=99');
    Raised := False;
    try Database.OpenDatabase(DbName); except on E: EInvalidOperation do Raised := True; end;
    Check(Raised, 'future database schema must be refused');
    Database.Close;
    Check(Scalar(DbName, 'pragma user_version') = 99, 'future version remains unchanged');
  finally Lines.Free; Database.Free; end;
end;

var
  DbName, PdnName: string;
  Database: TGameDatabase;
  Observer: TImportObserver;
  Imported, Duplicates, Errors: Integer;
begin
  if ParamStr(1) = '--crash-import' then
  begin
    Database := TGameDatabase.Create;
    Observer := TImportObserver.Create;
    Observer.Database := Database;
    Observer.CrashAfterBatch := True;
    Observer.CrashAt := StrToIntDef(ParamStr(4), 10000);
    Database.OpenDatabase(ParamStr(2));
    Database.ImportPdnFile(ParamStr(3), Imported, Duplicates, Errors, @Observer.Progress);
    Halt(74);
  end;
  PdnName := GetTempFileName(GetTempDir, 'gwd-recovery');
  DbName := PdnName + '.db';
  try
    CheckCompleteGameStorage(DbName, PdnName);
    DeleteFile(DbName);
    CheckLiveSummary(DbName, PdnName);
    DeleteFile(DbName);
    CheckFailedRebuild(DbName, PdnName);
    DeleteFile(DbName);
    CheckAbruptRecovery(DbName, PdnName);
  finally
    DeleteFile(PdnName);
    DeleteFile(DbName);
  end;
  Writeln('OK');
end.
