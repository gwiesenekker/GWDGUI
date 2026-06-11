unit uGameDatabase;

{$mode objfpc}{$H+}

interface

uses
  Classes, MD5, SQLite3Conn, SQLDB, SysUtils, uDraughtsBoard, uPdn;

type
  TDatabaseGameSortColumn = (dgscId, dgscWhite, dgscBlack, dgscEvent);

  TDatabaseGameInfo = class
  public
    Id: Integer;
    WhiteName: string;
    BlackName: string;
    EventName: string;
    ResultText: string;
    StartingFEN: string;
    PlyCount: Integer;
  end;

  TDatabaseSearchResult = class
  public
    MoveText: string;
    GameCount: Integer;
    Wins: Integer;
    Draws: Integer;
    Losses: Integer;
  end;

  TDatabaseImportProgressEvent = procedure(ABytesRead, ATotalBytes: Int64;
    AImported, ADuplicates, AErrors: Integer; var ACancel: Boolean) of object;

  TGameDatabase = class
  private
    FConnection: TSQLite3Connection;
    FFileName: string;
    FTransaction: TSQLTransaction;
    procedure ClearObjectList(AList: TList);
    procedure CommitActiveTransaction;
    procedure CreateImportIndexes;
    procedure DropImportIndexes;
    procedure EnsureGameHashColumn;
    procedure ExecuteSql(const ASql: string);
    procedure SetBulkImportPragmas;
    procedure StartTransactionIfNeeded;
    function Query: TSQLQuery;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Close;
    procedure CreateDatabase(const AFileName: string);
    procedure OpenDatabase(const AFileName: string);
    procedure ImportPdnFile(const AFileName: string; out AImported,
      ADuplicates, AErrors: Integer;
      AOnProgress: TDatabaseImportProgressEvent = nil;
      const AImportLogFileName: string = '');
    procedure LoadGames(AList: TList; ALimit: Integer;
      const AWhiteFilter, ABlackFilter, AEventFilter: string;
      ASortColumn: TDatabaseGameSortColumn; ASortDescending: Boolean;
      out ATotalMatches: Integer);
    procedure SearchPosition(const APositionKey: string; ASideToMove: TDraughtsSide;
      AList: TList);

    property FileName: string read FFileName;
  end;

implementation

type
  TDatabasePdnImporter = class
  private
    FBoard: TDraughtsBoard;
    FDatabase: TGameDatabase;
    FDuplicates: Integer;
    FErrors: Integer;
    FGame: TPdnGame;
    FGameId: Integer;
    FGameInsertQuery: TSQLQuery;
    FHashQuery: TSQLQuery;
    FIdQuery: TSQLQuery;
    FImported: Integer;
    FLastProgressTick: QWord;
    FLogFile: TextFile;
    FLogFileName: string;
    FLogOpen: Boolean;
    FMoves: TStringList;
    FOnProgress: TDatabaseImportProgressEvent;
    FPositionInsertQuery: TSQLQuery;
    procedure CanonicalizeMovesForImport;
    procedure CommitBatchIfNeeded;
    function GameHash: string;
    procedure ImportGame(AGame: TPdnGame; ABytesRead, ATotalBytes: Int64;
      var AStop: Boolean);
    function IsDuplicateGame(const AGameHash: string): Boolean;
    procedure InsertPosition(APly: Integer; const ANextMove: string);
    procedure LogDuplicate(const AGameHash: string);
    procedure LogError(const AMessage: string);
    procedure LogLine(const ALine: string);
    procedure ReportProgress(ABytesRead, ATotalBytes: Int64;
      var ACancel: Boolean);
  public
    constructor Create(ADatabase: TGameDatabase;
      AOnProgress: TDatabaseImportProgressEvent;
      const AImportLogFileName: string);
    destructor Destroy; override;
    procedure Run(const AFileName: string);
    property Duplicates: Integer read FDuplicates;
    property Errors: Integer read FErrors;
    property Imported: Integer read FImported;
  end;

function SideToText(ASide: TDraughtsSide): string;
begin
  if ASide = dsBlack then
    Result := 'B'
  else
    Result := 'W';
end;

function MoveCountText(const AMovesText: string): Integer;
var
  LMoves: TStringList;
begin
  LMoves := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)), LMoves);
    Result := LMoves.Count;
  finally
    LMoves.Free;
  end;
end;

function LogField(const AText: string): string;
begin
  Result := StringReplace(AText, #9, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
end;

constructor TDatabasePdnImporter.Create(ADatabase: TGameDatabase;
  AOnProgress: TDatabaseImportProgressEvent; const AImportLogFileName: string);
begin
  inherited Create;
  FDatabase := ADatabase;
  FOnProgress := AOnProgress;
  FLogFileName := AImportLogFileName;
  if Trim(FLogFileName) <> '' then
  begin
    AssignFile(FLogFile, FLogFileName);
    Rewrite(FLogFile);
    FLogOpen := True;
  end;
  FBoard := TDraughtsBoard.Create;
  FMoves := TStringList.Create;
  FGameInsertQuery := FDatabase.Query;
  FGameInsertQuery.SQL.Text :=
    'insert into games(game_hash, white, black, event, result, starting_fen, moves_text, annotations_text, ply_count) ' +
    'values(:game_hash, :white, :black, :event, :result, :starting_fen, :moves_text, :annotations_text, :ply_count)';
  FHashQuery := FDatabase.Query;
  FHashQuery.SQL.Text :=
    'select id from games where game_hash = :game_hash limit 1';
  FPositionInsertQuery := FDatabase.Query;
  FPositionInsertQuery.SQL.Text :=
    'insert into positions(game_id, ply, position_key, side_to_move, next_move, result) ' +
    'values(:game_id, :ply, :position_key, :side_to_move, :next_move, :result)';
  FIdQuery := FDatabase.Query;
  FIdQuery.SQL.Text := 'select last_insert_rowid() as id';
end;

destructor TDatabasePdnImporter.Destroy;
begin
  if FLogOpen then
  begin
    LogLine('finished' + #9 + 'imported=' + IntToStr(FImported) + #9 +
      'duplicates=' + IntToStr(FDuplicates) + #9 + 'errors=' +
      IntToStr(FErrors));
    CloseFile(FLogFile);
    FLogOpen := False;
  end;
  FIdQuery.Free;
  FPositionInsertQuery.Free;
  FHashQuery.Free;
  FGameInsertQuery.Free;
  FMoves.Free;
  FBoard.Free;
  inherited Destroy;
end;

procedure TDatabasePdnImporter.LogLine(const ALine: string);
begin
  if not FLogOpen then
    Exit;
  Writeln(FLogFile, FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + #9 +
    ALine);
end;

procedure TDatabasePdnImporter.LogDuplicate(const AGameHash: string);
var
  LPlyCount: Integer;
begin
  LPlyCount := MoveCountText(FGame.MovesText);
  if (LPlyCount = 0) and (FMoves <> nil) then
    LPlyCount := FMoves.Count;
  LogLine('duplicate' + #9 +
    'hash=' + LogField(AGameHash) + #9 +
    'event=' + LogField(FGame.EventName) + #9 +
    'white=' + LogField(FGame.WhiteName) + #9 +
    'black=' + LogField(FGame.BlackName) + #9 +
    'result=' + LogField(FGame.ResultText) + #9 +
    'fen=' + LogField(FGame.StartingFEN) + #9 +
    'plies=' + IntToStr(LPlyCount));
  if FLogOpen then
  begin
    Writeln(FLogFile, '----- DUPLICATE PDN -----');
    Writeln(FLogFile, PdnGameToText(FGame));
    Writeln(FLogFile, '-------------------------');
  end;
end;

procedure TDatabasePdnImporter.LogError(const AMessage: string);
begin
  LogLine('error' + #9 + LogField(AMessage));
  if FLogOpen then
  begin
    Writeln(FLogFile, '----- PDN -----');
    Writeln(FLogFile, PdnGameToText(FGame));
    Writeln(FLogFile, '---------------');
  end;
end;

procedure TDatabasePdnImporter.CanonicalizeMovesForImport;
var
  LLegalMove: string;
  LMove: string;
  LMovesText: string;
  Points: Integer;
begin
  FBoard.LoadFromFEN(FGame.StartingFEN);
  for Points := 0 to FMoves.Count - 1 do
  begin
    LMove := FMoves[Points];
    if not FBoard.TryGetLegalMove(LMove, LLegalMove) then
      raise EInvalidOperation.Create('Illegal move: ' + NormalizeMoveNotation(LMove) +
        LineEnding + 'Ply: ' + IntToStr(Points + 1) +
        LineEnding + 'Position: ' + FBoard.CurrentFEN +
        LineEnding + 'Legal moves:' + LineEnding + FBoard.LegalMoves.Text);
    FMoves[Points] := LLegalMove;
    FBoard.PlayMove(LLegalMove, False, False);
  end;

  LMovesText := Trim(StringReplace(FMoves.Text, LineEnding, ' ', [rfReplaceAll]));
  FGame.MovesText := LMovesText;
end;

procedure TDatabasePdnImporter.CommitBatchIfNeeded;
begin
  if (FImported > 0) and ((FImported mod 10000) = 0) then
  begin
    FDatabase.CommitActiveTransaction;
    FDatabase.StartTransactionIfNeeded;
  end;
end;

function TDatabasePdnImporter.GameHash: string;
var
  LHashText: string;
begin
  LHashText :=
    'gwdgui-db-v2' + #10 +
    Trim(FGame.EventName) + #10 +
    Trim(FGame.WhiteName) + #10 +
    Trim(FGame.BlackName) + #10 +
    Trim(FGame.ResultText) + #10 +
    Trim(FGame.StartingFEN) + #10 +
    Trim(FGame.MovesText);
  Result := MD5Print(MD5String(LHashText));
end;

function TDatabasePdnImporter.IsDuplicateGame(const AGameHash: string): Boolean;
begin
  FHashQuery.Close;
  FHashQuery.ParamByName('game_hash').AsString := AGameHash;
  FHashQuery.Open;
  try
    Result := not FHashQuery.EOF;
  finally
    FHashQuery.Close;
  end;
end;

procedure TDatabasePdnImporter.InsertPosition(APly: Integer;
  const ANextMove: string);
begin
  FPositionInsertQuery.ParamByName('game_id').AsInteger := FGameId;
  FPositionInsertQuery.ParamByName('ply').AsInteger := APly;
  FPositionInsertQuery.ParamByName('position_key').AsString := FBoard.PositionKey;
  FPositionInsertQuery.ParamByName('side_to_move').AsString := SideToText(FBoard.SideToMove);
  FPositionInsertQuery.ParamByName('next_move').AsString := ANextMove;
  FPositionInsertQuery.ParamByName('result').AsString := FGame.ResultText;
  FPositionInsertQuery.ExecSQL;
end;

procedure TDatabasePdnImporter.ReportProgress(ABytesRead, ATotalBytes: Int64;
  var ACancel: Boolean);
begin
  if not Assigned(FOnProgress) then
    Exit;
  if (GetTickCount64 - FLastProgressTick < 250) and
    (ABytesRead < ATotalBytes) then
    Exit;
  FLastProgressTick := GetTickCount64;
  FOnProgress(ABytesRead, ATotalBytes, FImported, FDuplicates, FErrors,
    ACancel);
end;

procedure TDatabasePdnImporter.ImportGame(AGame: TPdnGame; ABytesRead,
  ATotalBytes: Int64; var AStop: Boolean);
var
  LGameHash: string;
  Points: Integer;
begin
  FGame := AGame;
  try
    FMoves.Clear;
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(FGame.MovesText)),
      FMoves);
    CanonicalizeMovesForImport;
    LGameHash := GameHash;
    if IsDuplicateGame(LGameHash) then
    begin
      Inc(FDuplicates);
      LogDuplicate(LGameHash);
      ReportProgress(ABytesRead, ATotalBytes, AStop);
      Exit;
    end;

    FBoard.LoadFromFEN(FGame.StartingFEN);

    FGameInsertQuery.ParamByName('game_hash').AsString := LGameHash;
    FGameInsertQuery.ParamByName('white').AsString := FGame.WhiteName;
    FGameInsertQuery.ParamByName('black').AsString := FGame.BlackName;
    FGameInsertQuery.ParamByName('event').AsString := FGame.EventName;
    FGameInsertQuery.ParamByName('result').AsString := FGame.ResultText;
    FGameInsertQuery.ParamByName('starting_fen').AsString := FGame.StartingFEN;
    FGameInsertQuery.ParamByName('moves_text').AsString := FGame.MovesText;
    FGameInsertQuery.ParamByName('annotations_text').AsString := FGame.MoveAnnotationsText;
    FGameInsertQuery.ParamByName('ply_count').AsInteger := FMoves.Count;
    FGameInsertQuery.ExecSQL;

    FIdQuery.Open;
    FGameId := FIdQuery.FieldByName('id').AsInteger;
    FIdQuery.Close;

    for Points := 0 to FMoves.Count do
    begin
      if Points < FMoves.Count then
        InsertPosition(Points, FMoves[Points])
      else
        InsertPosition(Points, '');
      if Points < FMoves.Count then
        FBoard.PlayMove(FMoves[Points], False, False, False);
    end;
    Inc(FImported);
    CommitBatchIfNeeded;
  except
    on E: Exception do
    begin
      Inc(FErrors);
      LogError(E.Message);
      raise EInvalidOperation.Create('Import stopped at first invalid game.' +
        LineEnding + LineEnding + 'Error: ' + E.Message + LineEnding +
        LineEnding + PdnGameToText(FGame));
    end;
  end;
  ReportProgress(ABytesRead, ATotalBytes, AStop);
end;

procedure TDatabasePdnImporter.Run(const AFileName: string);
begin
  FLastProgressTick := 0;
  LogLine('started' + #9 + 'file=' + LogField(AFileName));
  ReadPdnGamesFromFile(AFileName, @ImportGame);
end;

constructor TGameDatabase.Create;
begin
  inherited Create;
  FConnection := TSQLite3Connection.Create(nil);
  FTransaction := TSQLTransaction.Create(nil);
  FConnection.Transaction := FTransaction;
end;

destructor TGameDatabase.Destroy;
begin
  Close;
  FTransaction.Free;
  FConnection.Free;
  inherited Destroy;
end;

procedure TGameDatabase.ClearObjectList(AList: TList);
var
  I: Integer;
begin
  if AList = nil then
    Exit;
  for I := 0 to AList.Count - 1 do
    TObject(AList[I]).Free;
  AList.Clear;
end;

procedure TGameDatabase.CommitActiveTransaction;
begin
  if FTransaction.Active then
    FTransaction.Commit;
end;

procedure TGameDatabase.StartTransactionIfNeeded;
begin
  if not FTransaction.Active then
    FTransaction.StartTransaction;
end;

procedure TGameDatabase.ExecuteSql(const ASql: string);
var
  Q: TSQLQuery;
begin
  Q := Query;
  try
    Q.SQL.Text := ASql;
    Q.ExecSQL;
  finally
    Q.Free;
  end;
end;

procedure TGameDatabase.CreateImportIndexes;
begin
  ExecuteSql('create unique index if not exists idx_games_hash on games(game_hash)');
  ExecuteSql('create index if not exists idx_games_white on games(white)');
  ExecuteSql('create index if not exists idx_games_black on games(black)');
  ExecuteSql('create index if not exists idx_games_event on games(event)');
  ExecuteSql('create index if not exists idx_positions_key on positions(position_key)');
  ExecuteSql('create index if not exists idx_positions_game on positions(game_id)');
end;

procedure TGameDatabase.DropImportIndexes;
begin
  ExecuteSql('drop index if exists idx_positions_key');
  ExecuteSql('drop index if exists idx_positions_game');
end;

procedure TGameDatabase.EnsureGameHashColumn;
var
  Found: Boolean;
  Q: TSQLQuery;
begin
  Found := False;
  Q := Query;
  try
    Q.SQL.Text := 'pragma table_info(games)';
    Q.Open;
    while not Q.EOF do
    begin
      if SameText(Q.FieldByName('name').AsString, 'game_hash') then
      begin
        Found := True;
        Break;
      end;
      Q.Next;
    end;
    Q.Close;
  finally
    Q.Free;
  end;
  if not Found then
    ExecuteSql('alter table games add column game_hash text');
end;

procedure TGameDatabase.SetBulkImportPragmas;
begin
  CommitActiveTransaction;
  FConnection.ExecuteDirect('pragma temp_store=memory');
  FConnection.ExecuteDirect('pragma cache_size=-200000');
  CommitActiveTransaction;
end;

function TGameDatabase.Query: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConnection;
  Result.Transaction := FTransaction;
end;

procedure TGameDatabase.Close;
begin
  CommitActiveTransaction;
  FConnection.Connected := False;
  FFileName := '';
end;

procedure TGameDatabase.CreateDatabase(const AFileName: string);
var
  Q: TSQLQuery;
begin
  Close;
  FConnection.DatabaseName := AFileName;
  FConnection.Connected := True;
  StartTransactionIfNeeded;
  Q := Query;
  try
    Q.SQL.Text :=
      'create table if not exists games (' +
      'id integer primary key autoincrement,' +
      'game_hash text,' +
      'white text, black text, event text, result text,' +
      'starting_fen text, moves_text text, annotations_text text,' +
      'ply_count integer)';
    Q.ExecSQL;
    EnsureGameHashColumn;
    Q.SQL.Text :=
      'create table if not exists positions (' +
      'id integer primary key autoincrement,' +
      'game_id integer not null,' +
      'ply integer not null,' +
      'position_key text not null,' +
      'side_to_move text not null,' +
      'next_move text,' +
      'result text)';
    Q.ExecSQL;
    CreateImportIndexes;
    FTransaction.Commit;
    FFileName := AFileName;
  finally
    Q.Free;
  end;
end;

procedure TGameDatabase.OpenDatabase(const AFileName: string);
begin
  CreateDatabase(AFileName);
end;

procedure TGameDatabase.ImportPdnFile(const AFileName: string; out AImported,
  ADuplicates, AErrors: Integer; AOnProgress: TDatabaseImportProgressEvent;
  const AImportLogFileName: string);
var
  Importer: TDatabasePdnImporter;
begin
  AImported := 0;
  ADuplicates := 0;
  AErrors := 0;
  if not FConnection.Connected then
    raise EInvalidOperation.Create('No database is open');

  Importer := TDatabasePdnImporter.Create(Self, AOnProgress,
    AImportLogFileName);
  try
    try
      CommitActiveTransaction;
      SetBulkImportPragmas;
      StartTransactionIfNeeded;
      DropImportIndexes;
      CommitActiveTransaction;
      StartTransactionIfNeeded;
      Importer.Run(AFileName);
      CommitActiveTransaction;
      StartTransactionIfNeeded;
      CreateImportIndexes;
      CommitActiveTransaction;
    except
      if FTransaction.Active then
        FTransaction.Rollback;
      try
        StartTransactionIfNeeded;
        CreateImportIndexes;
        CommitActiveTransaction;
      except
        if FTransaction.Active then
          FTransaction.Rollback;
      end;
      raise;
    end;
    AImported := Importer.Imported;
    ADuplicates := Importer.Duplicates;
    AErrors := Importer.Errors;
  finally
    Importer.Free;
  end;
end;

procedure TGameDatabase.LoadGames(AList: TList; ALimit: Integer;
  const AWhiteFilter, ABlackFilter, AEventFilter: string;
  ASortColumn: TDatabaseGameSortColumn; ASortDescending: Boolean;
  out ATotalMatches: Integer);
var
  Info: TDatabaseGameInfo;
  OrderBy: string;
  Q: TSQLQuery;
  WhereSql: string;

  procedure AddFilter(const AColumn, AParamName, AValue: string);
  begin
    if Trim(AValue) = '' then
      Exit;
    if WhereSql = '' then
      WhereSql := ' where '
    else
      WhereSql := WhereSql + ' and ';
    WhereSql := WhereSql + 'lower(' + AColumn + ') like :' + AParamName;
  end;

  procedure BindFilters(AQuery: TSQLQuery);
  begin
    if Trim(AWhiteFilter) <> '' then
      AQuery.ParamByName('white_filter').AsString :=
        '%' + AnsiLowerCase(Trim(AWhiteFilter)) + '%';
    if Trim(ABlackFilter) <> '' then
      AQuery.ParamByName('black_filter').AsString :=
        '%' + AnsiLowerCase(Trim(ABlackFilter)) + '%';
    if Trim(AEventFilter) <> '' then
      AQuery.ParamByName('event_filter').AsString :=
        '%' + AnsiLowerCase(Trim(AEventFilter)) + '%';
  end;
begin
  ATotalMatches := 0;
  ClearObjectList(AList);
  if not FConnection.Connected then
    Exit;

  WhereSql := '';
  AddFilter('white', 'white_filter', AWhiteFilter);
  AddFilter('black', 'black_filter', ABlackFilter);
  AddFilter('event', 'event_filter', AEventFilter);

  case ASortColumn of
    dgscWhite:
      OrderBy := 'lower(white), lower(black), lower(event), id';
    dgscBlack:
      OrderBy := 'lower(black), lower(white), lower(event), id';
    dgscEvent:
      OrderBy := 'lower(event), lower(white), lower(black), id';
  else
    OrderBy := 'id';
  end;
  if ASortDescending then
    OrderBy := StringReplace(OrderBy, ',', ' desc,', [rfReplaceAll]) + ' desc';

  Q := Query;
  try
    Q.SQL.Text := 'select count(*) as game_count from games' + WhereSql;
    BindFilters(Q);
    Q.Open;
    ATotalMatches := Q.FieldByName('game_count').AsInteger;
    Q.Close;

    Q.SQL.Text :=
      'select id, white, black, event, result, starting_fen, ply_count ' +
      'from games' + WhereSql + ' order by ' + OrderBy;
    if ALimit > 0 then
      Q.SQL.Text := Q.SQL.Text + ' limit ' + IntToStr(ALimit);
    BindFilters(Q);
    Q.Open;
    while not Q.EOF do
    begin
      Info := TDatabaseGameInfo.Create;
      Info.Id := Q.FieldByName('id').AsInteger;
      Info.WhiteName := Q.FieldByName('white').AsString;
      Info.BlackName := Q.FieldByName('black').AsString;
      Info.EventName := Q.FieldByName('event').AsString;
      Info.ResultText := Q.FieldByName('result').AsString;
      Info.StartingFEN := Q.FieldByName('starting_fen').AsString;
      Info.PlyCount := Q.FieldByName('ply_count').AsInteger;
      AList.Add(Info);
      Q.Next;
    end;
    Q.Close;
  finally
    Q.Free;
    CommitActiveTransaction;
  end;
end;

procedure TGameDatabase.SearchPosition(const APositionKey: string;
  ASideToMove: TDraughtsSide; AList: TList);
var
  ResultItem: TDatabaseSearchResult;
  Q: TSQLQuery;
begin
  ClearObjectList(AList);
  if not FConnection.Connected then
    Exit;

  Q := Query;
  try
    if ASideToMove = dsBlack then
      Q.SQL.Text :=
        'select next_move, count(*) as game_count, ' +
        'sum(case when result = ''0-2'' then 1 else 0 end) as wins, ' +
        'sum(case when result = ''1-1'' then 1 else 0 end) as draws, ' +
        'sum(case when result = ''2-0'' then 1 else 0 end) as losses ' +
        'from positions ' +
        'where position_key = :position_key and coalesce(next_move, '''') <> '''' ' +
        'group by next_move ' +
        'order by game_count desc, wins desc, next_move'
    else
      Q.SQL.Text :=
        'select next_move, count(*) as game_count, ' +
        'sum(case when result = ''2-0'' then 1 else 0 end) as wins, ' +
        'sum(case when result = ''1-1'' then 1 else 0 end) as draws, ' +
        'sum(case when result = ''0-2'' then 1 else 0 end) as losses ' +
        'from positions ' +
        'where position_key = :position_key and coalesce(next_move, '''') <> '''' ' +
        'group by next_move ' +
        'order by game_count desc, wins desc, next_move';
    Q.ParamByName('position_key').AsString := APositionKey;
    Q.Open;
    while not Q.EOF do
    begin
      ResultItem := TDatabaseSearchResult.Create;
      ResultItem.MoveText := Q.FieldByName('next_move').AsString;
      ResultItem.GameCount := Q.FieldByName('game_count').AsInteger;
      ResultItem.Wins := Q.FieldByName('wins').AsInteger;
      ResultItem.Draws := Q.FieldByName('draws').AsInteger;
      ResultItem.Losses := Q.FieldByName('losses').AsInteger;
      AList.Add(ResultItem);
      Q.Next;
    end;
    Q.Close;
  finally
    Q.Free;
    CommitActiveTransaction;
  end;
end;

end.
