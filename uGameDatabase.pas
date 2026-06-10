unit uGameDatabase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SQLite3Conn, SQLDB, SysUtils, uDraughtsBoard, uPdn;

type
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
    AImported, AErrors: Integer; var ACancel: Boolean) of object;

  TGameDatabase = class
  private
    FConnection: TSQLite3Connection;
    FFileName: string;
    FTransaction: TSQLTransaction;
    procedure ClearObjectList(AList: TList);
    procedure CommitActiveTransaction;
    procedure CreateImportIndexes;
    procedure DropImportIndexes;
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
      AErrors: Integer; AOnProgress: TDatabaseImportProgressEvent = nil);
    procedure LoadGames(AList: TList; ALimit: Integer = 0);
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
    FErrors: Integer;
    FGame: TPdnGame;
    FGameId: Integer;
    FGameInsertQuery: TSQLQuery;
    FIdQuery: TSQLQuery;
    FImported: Integer;
    FLastProgressTick: QWord;
    FMoves: TStringList;
    FOnProgress: TDatabaseImportProgressEvent;
    FPositionInsertQuery: TSQLQuery;
    procedure CanonicalizeMovesForImport;
    procedure CommitBatchIfNeeded;
    procedure ImportGame(AGame: TPdnGame; ABytesRead, ATotalBytes: Int64;
      var AStop: Boolean);
    procedure InsertPosition(APly: Integer; const ANextMove: string);
    procedure ReportProgress(ABytesRead, ATotalBytes: Int64;
      var ACancel: Boolean);
  public
    constructor Create(ADatabase: TGameDatabase;
      AOnProgress: TDatabaseImportProgressEvent);
    destructor Destroy; override;
    procedure Run(const AFileName: string);
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

function ResultPointsForSide(const AResult: string; ASide: TDraughtsSide): Integer;
begin
  if SameText(AResult, '1-1') then
    Exit(1);
  if SameText(AResult, '2-0') then
  begin
    if ASide = dsWhite then
      Exit(2);
    Exit(0);
  end;
  if SameText(AResult, '0-2') then
  begin
    if ASide = dsBlack then
      Exit(2);
    Exit(0);
  end;
  Result := -1;
end;

constructor TDatabasePdnImporter.Create(ADatabase: TGameDatabase;
  AOnProgress: TDatabaseImportProgressEvent);
begin
  inherited Create;
  FDatabase := ADatabase;
  FOnProgress := AOnProgress;
  FBoard := TDraughtsBoard.Create;
  FMoves := TStringList.Create;
  FGameInsertQuery := FDatabase.Query;
  FGameInsertQuery.SQL.Text :=
    'insert into games(white, black, event, result, starting_fen, moves_text, annotations_text, ply_count) ' +
    'values(:white, :black, :event, :result, :starting_fen, :moves_text, :annotations_text, :ply_count)';
  FPositionInsertQuery := FDatabase.Query;
  FPositionInsertQuery.SQL.Text :=
    'insert into positions(game_id, ply, position_key, side_to_move, next_move, result) ' +
    'values(:game_id, :ply, :position_key, :side_to_move, :next_move, :result)';
  FIdQuery := FDatabase.Query;
  FIdQuery.SQL.Text := 'select last_insert_rowid() as id';
end;

destructor TDatabasePdnImporter.Destroy;
begin
  FIdQuery.Free;
  FPositionInsertQuery.Free;
  FGameInsertQuery.Free;
  FMoves.Free;
  FBoard.Free;
  inherited Destroy;
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
  FOnProgress(ABytesRead, ATotalBytes, FImported, FErrors, ACancel);
end;

procedure TDatabasePdnImporter.ImportGame(AGame: TPdnGame; ABytesRead,
  ATotalBytes: Int64; var AStop: Boolean);
var
  Points: Integer;
begin
  FGame := AGame;
  try
    FMoves.Clear;
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(FGame.MovesText)),
      FMoves);
    CanonicalizeMovesForImport;
    FBoard.LoadFromFEN(FGame.StartingFEN);

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
  ExecuteSql('create index if not exists idx_positions_key on positions(position_key)');
  ExecuteSql('create index if not exists idx_positions_game on positions(game_id)');
end;

procedure TGameDatabase.DropImportIndexes;
begin
  ExecuteSql('drop index if exists idx_positions_key');
  ExecuteSql('drop index if exists idx_positions_game');
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
      'white text, black text, event text, result text,' +
      'starting_fen text, moves_text text, annotations_text text,' +
      'ply_count integer)';
    Q.ExecSQL;
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
  AErrors: Integer; AOnProgress: TDatabaseImportProgressEvent);
var
  Importer: TDatabasePdnImporter;
begin
  AImported := 0;
  AErrors := 0;
  if not FConnection.Connected then
    raise EInvalidOperation.Create('No database is open');

  Importer := TDatabasePdnImporter.Create(Self, AOnProgress);
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
    AErrors := Importer.Errors;
  finally
    Importer.Free;
  end;
end;

procedure TGameDatabase.LoadGames(AList: TList; ALimit: Integer);
var
  Info: TDatabaseGameInfo;
  Q: TSQLQuery;
begin
  ClearObjectList(AList);
  if not FConnection.Connected then
    Exit;

  Q := Query;
  try
    Q.SQL.Text :=
      'select id, white, black, event, result, starting_fen, ply_count ' +
      'from games order by id';
    if ALimit > 0 then
      Q.SQL.Text := Q.SQL.Text + ' limit ' + IntToStr(ALimit);
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
  MoveText: string;
  Points: Integer;
  ResultItem: TDatabaseSearchResult;
  Q: TSQLQuery;
begin
  ClearObjectList(AList);
  if not FConnection.Connected then
    Exit;

  Q := Query;
  try
    Q.SQL.Text :=
      'select next_move, result from positions ' +
      'where position_key = :position_key and coalesce(next_move, '''') <> ''''';
    Q.ParamByName('position_key').AsString := APositionKey;
    Q.Open;
    while not Q.EOF do
    begin
      MoveText := Q.FieldByName('next_move').AsString;
      ResultItem := nil;
      for Points := 0 to AList.Count - 1 do
        if SameText(TDatabaseSearchResult(AList[Points]).MoveText, MoveText) then
        begin
          ResultItem := TDatabaseSearchResult(AList[Points]);
          Break;
        end;
      if ResultItem = nil then
      begin
        ResultItem := TDatabaseSearchResult.Create;
        ResultItem.MoveText := MoveText;
        AList.Add(ResultItem);
      end;

      Inc(ResultItem.GameCount);
      Points := ResultPointsForSide(Q.FieldByName('result').AsString, ASideToMove);
      if Points = 2 then
        Inc(ResultItem.Wins)
      else if Points = 1 then
        Inc(ResultItem.Draws)
      else if Points = 0 then
        Inc(ResultItem.Losses);
      Q.Next;
    end;
    Q.Close;
  finally
    Q.Free;
    CommitActiveTransaction;
  end;
end;

end.
