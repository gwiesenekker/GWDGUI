unit uGameDatabase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SQLite3Conn, SQLDB, SysUtils, uDraughtsBoard, uPdn;

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
    function ContinuationSummaryAvailable: Boolean;
    procedure CreateImportIndexes;
    procedure DropImportIndexes;
    procedure EnsureContinuationTable;
    procedure EnsureGameHashColumns;
    procedure ExecuteSql(const ASql: string);
    procedure SetBulkImportPragmas;
    procedure StartTransactionIfNeeded;
    function TableColumnExists(const ATableName, AColumnName: string): Boolean;
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
      const AWhiteFilter, ABlackFilter, AEventFilter, APlayerFilter: string;
      ASortColumn: TDatabaseGameSortColumn; ASortDescending: Boolean;
      out ATotalMatches: Integer);
    procedure LoadGames(AList: TList);
    function LoadGameById(AGameId: Integer): TPdnGame;
    function GamesForPositionExceedLimit(const APositionKey: string;
      ASideToMove: TDraughtsSide; ALimit: Integer; out AProbeCount: Integer): Boolean;
    procedure LoadGamesForPosition(const APositionKey: string;
      ASideToMove: TDraughtsSide; AList: TList; ALimit: Integer;
      out ATotalMatches: Integer);
    procedure RebuildContinuationSummary;
    procedure SearchPosition(const APositionKey: string; ASideToMove: TDraughtsSide;
      AList: TList);

    property FileName: string read FFileName;
  end;

implementation

type
  THash128 = record
    Lo: Int64;
    Hi: Int64;
  end;

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
    function GameHash: THash128;
    procedure ImportGame(AGame: TPdnGame; ABytesRead, ATotalBytes: Int64;
      var AStop: Boolean);
    function IsDuplicateGame(const AGameHash: THash128): Boolean;
    procedure InsertPosition(APly: Integer; const ANextMove: string);
    procedure LogDuplicate(const AGameHash: THash128);
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

function QWordAsInt64(AValue: QWord): Int64;
begin
  Result := 0;
  Move(AValue, Result, SizeOf(Result));
end;

function QWordLo32(AValue: QWord): QWord;
begin
  Result := AValue and QWord($FFFFFFFF);
end;

function QWordHi32(AValue: QWord): QWord;
begin
  Result := AValue shr 32;
end;

procedure Add128(var ALo, AHi: QWord; BLo, BHi: QWord);
var
  OldLo: QWord;
begin
  OldLo := ALo;
  ALo := ALo + BLo;
  AHi := AHi + BHi;
  if ALo < OldLo then
    Inc(AHi);
end;

procedure Mul128ByFNVPrime(var ALo, AHi: QWord);
var
  Carry: QWord;
  L0: QWord;
  L1: QWord;
  L2: QWord;
  L3: QWord;
  OldLo: QWord;
  Product: QWord;
  ShiftHi: QWord;
begin
  { FNV-1a-128 prime = 2^88 + 0x13B.  Modulo 2^128:
    hash * prime = (hash << 88) + (hash * 0x13B). }
  OldLo := ALo;

  Product := QWordLo32(ALo) * QWord($13B);
  L0 := QWordLo32(Product);
  Carry := QWordHi32(Product);

  Product := QWordHi32(ALo) * QWord($13B) + Carry;
  L1 := QWordLo32(Product);
  Carry := QWordHi32(Product);

  Product := QWordLo32(AHi) * QWord($13B) + Carry;
  L2 := QWordLo32(Product);
  Carry := QWordHi32(Product);

  Product := QWordHi32(AHi) * QWord($13B) + Carry;
  L3 := QWordLo32(Product);

  ALo := L0 or (L1 shl 32);
  AHi := L2 or (L3 shl 32);
  ShiftHi := OldLo shl 24;
  Add128(ALo, AHi, 0, ShiftHi);
end;

function Fnv1a128Value(const AText: string): THash128;
var
  HashHi: QWord;
  HashLo: QWord;
  I: Integer;
begin
  HashHi := (QWord($6C62272E) shl 32) or QWord($07BB0142);
  HashLo := (QWord($62B82175) shl 32) or QWord($6295C58D);
  for I := 1 to Length(AText) do
  begin
    HashLo := HashLo xor Ord(AText[I]);
    Mul128ByFNVPrime(HashLo, HashHi);
  end;
  Result.Lo := QWordAsInt64(HashLo);
  Result.Hi := QWordAsInt64(HashHi);
end;

function PositionStateDigit(AState: Char): QWord;
begin
  case AState of
    'e':
      Result := 0;
    'w':
      Result := 1;
    'b':
      Result := 2;
    'W':
      Result := 3;
    'B':
      Result := 4;
  else
    raise EConvertError.CreateFmt('Invalid position key square state: %s',
      [AState]);
  end;
end;

procedure Mul128By5Add(var ALo, AHi: QWord; ADigit: QWord);
var
  Carry: QWord;
  L0: QWord;
  L1: QWord;
  L2: QWord;
  L3: QWord;
  Product: QWord;
begin
  Product := QWordLo32(ALo) * 5 + ADigit;
  L0 := QWordLo32(Product);
  Carry := QWordHi32(Product);

  Product := QWordHi32(ALo) * 5 + Carry;
  L1 := QWordLo32(Product);
  Carry := QWordHi32(Product);

  Product := QWordLo32(AHi) * 5 + Carry;
  L2 := QWordLo32(Product);
  Carry := QWordHi32(Product);

  Product := QWordHi32(AHi) * 5 + Carry;
  L3 := QWordLo32(Product);

  ALo := L0 or (L1 shl 32);
  AHi := L2 or (L3 shl 32);
end;

function PackedPositionKey128Value(const APositionKey: string): THash128;
var
  KeyHi: QWord;
  KeyLo: QWord;
  I: Integer;
  SquareOffset: Integer;
begin
  if (Length(APositionKey) = 52) and (APositionKey[2] = '|') then
    SquareOffset := 2
  else if Length(APositionKey) = 51 then
    SquareOffset := 1
  else
    raise EConvertError.CreateFmt('Invalid position key length: %d',
      [Length(APositionKey)]);

  if APositionKey[1] = 'B' then
    KeyLo := 1
  else if APositionKey[1] = 'W' then
    KeyLo := 0
  else
    raise EConvertError.CreateFmt('Invalid position key side to move: %s',
      [APositionKey[1]]);
  KeyHi := 0;

  for I := SquareOffset + 1 to Length(APositionKey) do
    Mul128By5Add(KeyLo, KeyHi, PositionStateDigit(APositionKey[I]));

  Result.Lo := QWordAsInt64(KeyLo);
  Result.Hi := QWordAsInt64(KeyHi);
end;

function Hash128ToHex(const AHash: THash128): string;
var
  HashHi: QWord;
  HashLo: QWord;
begin
  HashHi := 0;
  HashLo := 0;
  Move(AHash.Hi, HashHi, SizeOf(HashHi));
  Move(AHash.Lo, HashLo, SizeOf(HashLo));
  Result := IntToHex(HashHi, 16) + IntToHex(HashLo, 16);
end;

procedure BindPositionKey(AQuery: TSQLQuery; const APositionKey: string);
var
  PositionKey: THash128;
begin
  PositionKey := PackedPositionKey128Value(APositionKey);
  AQuery.ParamByName('position_key_lo').AsLargeInt := PositionKey.Lo;
  AQuery.ParamByName('position_key_hi').AsLargeInt := PositionKey.Hi;
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
    'insert into games(game_hash_lo, game_hash_hi, white, black, event, result, starting_fen, moves_text, annotations_text, ply_count) ' +
    'values(:game_hash_lo, :game_hash_hi, :white, :black, :event, :result, :starting_fen, :moves_text, :annotations_text, :ply_count)';
  FHashQuery := FDatabase.Query;
  FHashQuery.SQL.Text :=
    'select id from games where game_hash_lo = :game_hash_lo and game_hash_hi = :game_hash_hi limit 1';
  FPositionInsertQuery := FDatabase.Query;
  FPositionInsertQuery.SQL.Text :=
    'insert into positions(game_id, ply, position_key_lo, position_key_hi, side_to_move, next_move, result) ' +
    'values(:game_id, :ply, :position_key_lo, :position_key_hi, :side_to_move, :next_move, :result)';
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

procedure TDatabasePdnImporter.LogDuplicate(const AGameHash: THash128);
var
  LPlyCount: Integer;
begin
  LPlyCount := MoveCountText(FGame.MovesText);
  if (LPlyCount = 0) and (FMoves <> nil) then
    LPlyCount := FMoves.Count;
  LogLine('duplicate' + #9 +
    'hash=' + LogField(Hash128ToHex(AGameHash)) + #9 +
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
        LineEnding + 'Legal moves:' + LineEnding + FBoard.LegalMovesText);
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

function TDatabasePdnImporter.GameHash: THash128;
var
  LHashText: string;
begin
  LHashText :=
    'gwdgui-db-v3-game-fnv1a128' + #10 +
    Trim(FGame.EventName) + #10 +
    Trim(FGame.WhiteName) + #10 +
    Trim(FGame.BlackName) + #10 +
    Trim(FGame.ResultText) + #10 +
    Trim(FGame.StartingFEN) + #10 +
    Trim(FGame.MovesText);
  Result := Fnv1a128Value(LHashText);
end;

function TDatabasePdnImporter.IsDuplicateGame(const AGameHash: THash128): Boolean;
begin
  FHashQuery.Close;
  FHashQuery.ParamByName('game_hash_lo').AsLargeInt := AGameHash.Lo;
  FHashQuery.ParamByName('game_hash_hi').AsLargeInt := AGameHash.Hi;
  FHashQuery.Open;
  try
    Result := not FHashQuery.EOF;
  finally
    FHashQuery.Close;
  end;
end;

procedure TDatabasePdnImporter.InsertPosition(APly: Integer;
  const ANextMove: string);
var
  PositionKey: THash128;
  SideText: string;
begin
  PositionKey := PackedPositionKey128Value(FBoard.PositionKey);
  SideText := SideToText(FBoard.SideToMove);
  FPositionInsertQuery.ParamByName('game_id').AsInteger := FGameId;
  FPositionInsertQuery.ParamByName('ply').AsInteger := APly;
  FPositionInsertQuery.ParamByName('position_key_lo').AsLargeInt := PositionKey.Lo;
  FPositionInsertQuery.ParamByName('position_key_hi').AsLargeInt := PositionKey.Hi;
  FPositionInsertQuery.ParamByName('side_to_move').AsString := SideText;
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
  LGameHash: THash128;
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

    FGameInsertQuery.ParamByName('game_hash_lo').AsLargeInt := LGameHash.Lo;
    FGameInsertQuery.ParamByName('game_hash_hi').AsLargeInt := LGameHash.Hi;
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

function TGameDatabase.ContinuationSummaryAvailable: Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  if not FConnection.Connected then
    Exit;

  Q := Query;
  try
    Q.SQL.Text := 'select 1 from continuations limit 1';
    Q.Open;
    Result := not Q.EOF;
    Q.Close;
  finally
    Q.Free;
  end;
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
  ExecuteSql('create unique index if not exists idx_games_hash on games(game_hash_lo, game_hash_hi)');
  ExecuteSql('create index if not exists idx_games_white on games(white)');
  ExecuteSql('create index if not exists idx_games_black on games(black)');
  ExecuteSql('create index if not exists idx_games_event on games(event)');
  ExecuteSql('create index if not exists idx_positions_search on positions(position_key_lo, position_key_hi, side_to_move, next_move, result)');
  ExecuteSql('create index if not exists idx_positions_game on positions(game_id)');
end;

procedure TGameDatabase.DropImportIndexes;
begin
  ExecuteSql('drop index if exists idx_positions_key');
  ExecuteSql('drop index if exists idx_positions_search');
  ExecuteSql('drop index if exists idx_positions_game');
  ExecuteSql('drop index if exists idx_positions_game_search');
end;

procedure TGameDatabase.EnsureContinuationTable;
begin
  ExecuteSql(
    'create table if not exists continuations (' +
    'position_key_lo integer not null,' +
    'position_key_hi integer not null,' +
    'side_to_move text not null,' +
    'next_move text not null,' +
    'game_count integer not null,' +
    'white_wins integer not null,' +
    'draws integer not null,' +
    'black_wins integer not null,' +
    'primary key(position_key_lo, position_key_hi, side_to_move, next_move))');
end;

procedure TGameDatabase.EnsureGameHashColumns;
begin
  if (not TableColumnExists('games', 'game_hash_lo')) or
    (not TableColumnExists('games', 'game_hash_hi')) then
    raise EInvalidOperation.Create(
      'This database uses the old game hash schema. Create a new database and reimport the PDN file.');
end;

function TGameDatabase.TableColumnExists(const ATableName,
  AColumnName: string): Boolean;
var
  Q: TSQLQuery;
begin
  Result := False;
  Q := Query;
  try
    Q.SQL.Text := 'pragma table_info(' + ATableName + ')';
    Q.Open;
    while not Q.EOF do
    begin
      if SameText(Q.FieldByName('name').AsString, AColumnName) then
      begin
        Result := True;
        Break;
      end;
      Q.Next;
    end;
    Q.Close;
  finally
    Q.Free;
  end;
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
      'game_hash_lo integer not null,' +
      'game_hash_hi integer not null,' +
      'white text, black text, event text, result text,' +
      'starting_fen text, moves_text text, annotations_text text,' +
      'ply_count integer)';
    Q.ExecSQL;
    EnsureGameHashColumns;
    Q.SQL.Text :=
      'create table if not exists positions (' +
      'id integer primary key autoincrement,' +
      'game_id integer not null,' +
      'ply integer not null,' +
      'position_key_lo integer not null,' +
      'position_key_hi integer not null,' +
      'side_to_move text not null,' +
      'next_move text,' +
      'result text)';
    Q.ExecSQL;
    if (not TableColumnExists('positions', 'position_key_lo')) or
      (not TableColumnExists('positions', 'position_key_hi')) then
      raise EInvalidOperation.Create(
        'This database uses the old position schema. Create a new database and reimport the PDN file.');
    EnsureContinuationTable;
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
      RebuildContinuationSummary;
      StartTransactionIfNeeded;
      CreateImportIndexes;
      CommitActiveTransaction;
    except
      if FTransaction.Active then
        FTransaction.Rollback;
      try
        RebuildContinuationSummary;
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

procedure TGameDatabase.RebuildContinuationSummary;
begin
  if not FConnection.Connected then
    raise EInvalidOperation.Create('No database is open');

  CommitActiveTransaction;
  StartTransactionIfNeeded;
  try
    EnsureContinuationTable;
    ExecuteSql('delete from continuations');
    ExecuteSql(
      'insert into continuations(position_key_lo, position_key_hi, side_to_move, next_move, game_count, white_wins, draws, black_wins) ' +
      'select position_key_lo, position_key_hi, side_to_move, next_move, count(*) as game_count, ' +
      'sum(case when result = ''2-0'' then 1 else 0 end) as white_wins, ' +
      'sum(case when result = ''1-1'' then 1 else 0 end) as draws, ' +
      'sum(case when result = ''0-2'' then 1 else 0 end) as black_wins ' +
      'from positions ' +
      'where coalesce(next_move, '''') <> '''' ' +
      'group by position_key_lo, position_key_hi, side_to_move, next_move');
    CommitActiveTransaction;
  except
    if FTransaction.Active then
      FTransaction.Rollback;
    raise;
  end;
end;

procedure TGameDatabase.LoadGames(AList: TList; ALimit: Integer;
  const AWhiteFilter, ABlackFilter, AEventFilter, APlayerFilter: string;
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

  procedure AddPlayerFilter;
  begin
    if Trim(APlayerFilter) = '' then
      Exit;
    if WhereSql = '' then
      WhereSql := ' where '
    else
      WhereSql := WhereSql + ' and ';
    WhereSql := WhereSql +
      '(lower(white) like :player_filter or lower(black) like :player_filter)';
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
    if Trim(APlayerFilter) <> '' then
      AQuery.ParamByName('player_filter').AsString :=
        '%' + AnsiLowerCase(Trim(APlayerFilter)) + '%';
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
  AddPlayerFilter;

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

procedure TGameDatabase.LoadGames(AList: TList);
var
  TotalMatches: Integer;
begin
  LoadGames(AList, 0, '', '', '', '', dgscId, False, TotalMatches);
end;

function TGameDatabase.LoadGameById(AGameId: Integer): TPdnGame;
var
  Q: TSQLQuery;
begin
  if not FConnection.Connected then
    raise EInvalidOperation.Create('No database is open');

  Result := nil;
  Q := Query;
  try
    Q.SQL.Text :=
      'select white, black, event, result, starting_fen, moves_text, annotations_text ' +
      'from games where id = :id';
    Q.ParamByName('id').AsInteger := AGameId;
    Q.Open;
    if Q.EOF then
      raise EInvalidOperation.Create('Game not found');

    Result := TPdnGame.Create;
    Result.WhiteName := Q.FieldByName('white').AsString;
    Result.BlackName := Q.FieldByName('black').AsString;
    Result.EventName := Q.FieldByName('event').AsString;
    Result.ResultText := Q.FieldByName('result').AsString;
    Result.StartingFEN := Q.FieldByName('starting_fen').AsString;
    Result.MovesText := Q.FieldByName('moves_text').AsString;
    Result.MoveAnnotationsText := Q.FieldByName('annotations_text').AsString;
    Q.Close;
  finally
    Q.Free;
    CommitActiveTransaction;
  end;
end;

function TGameDatabase.GamesForPositionExceedLimit(const APositionKey: string;
  ASideToMove: TDraughtsSide; ALimit: Integer; out AProbeCount: Integer): Boolean;
var
  Q: TSQLQuery;
begin
  AProbeCount := 0;
  Result := False;
  if not FConnection.Connected then
    Exit;
  if ALimit < 1 then
    Exit;

  Q := Query;
  try
    Q.SQL.Text :=
      'select p.game_id from positions p ' +
      'where p.position_key_lo = :position_key_lo and p.position_key_hi = :position_key_hi ' +
      'and p.side_to_move = :side_to_move ' +
      'group by p.game_id limit ' + IntToStr(ALimit + 1);
    BindPositionKey(Q, APositionKey);
    Q.ParamByName('side_to_move').AsString := SideToText(ASideToMove);
    Q.Open;
    while not Q.EOF do
    begin
      Inc(AProbeCount);
      Q.Next;
    end;
    Q.Close;
    Result := AProbeCount > ALimit;
  finally
    Q.Free;
    CommitActiveTransaction;
  end;
end;

procedure TGameDatabase.LoadGamesForPosition(const APositionKey: string;
  ASideToMove: TDraughtsSide; AList: TList; ALimit: Integer;
  out ATotalMatches: Integer);
var
  Info: TDatabaseGameInfo;
  Q: TSQLQuery;
begin
  ATotalMatches := 0;
  ClearObjectList(AList);
  if not FConnection.Connected then
    Exit;

  Q := Query;
  try
    Q.SQL.Text :=
      'select count(*) as game_count from (' +
      'select p.game_id from positions p ' +
      'where p.position_key_lo = :position_key_lo and p.position_key_hi = :position_key_hi ' +
      'and p.side_to_move = :side_to_move ' +
      'group by p.game_id)';
    BindPositionKey(Q, APositionKey);
    Q.ParamByName('side_to_move').AsString := SideToText(ASideToMove);
    Q.Open;
    ATotalMatches := Q.FieldByName('game_count').AsInteger;
    Q.Close;

    Q.SQL.Text :=
      'select g.id, g.white, g.black, g.event, g.result, g.starting_fen, ' +
      'g.ply_count, min(p.ply) as first_ply ' +
      'from positions p join games g on g.id = p.game_id ' +
      'where p.position_key_lo = :position_key_lo and p.position_key_hi = :position_key_hi ' +
      'and p.side_to_move = :side_to_move ' +
      'group by g.id, g.white, g.black, g.event, g.result, g.starting_fen, g.ply_count ' +
      'order by first_ply, g.id';
    if ALimit > 0 then
      Q.SQL.Text := Q.SQL.Text + ' limit ' + IntToStr(ALimit);
    BindPositionKey(Q, APositionKey);
    Q.ParamByName('side_to_move').AsString := SideToText(ASideToMove);
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
  UseSummary: Boolean;
begin
  ClearObjectList(AList);
  if not FConnection.Connected then
    Exit;

  UseSummary := ContinuationSummaryAvailable;
  Q := Query;
  try
    if UseSummary then
    begin
      if ASideToMove = dsBlack then
        Q.SQL.Text :=
          'select c.next_move, c.game_count, c.black_wins as wins, c.draws, c.white_wins as losses ' +
          'from continuations c ' +
          'where c.position_key_lo = :position_key_lo and c.position_key_hi = :position_key_hi ' +
          'and c.side_to_move = :side_to_move ' +
          'order by c.game_count desc, wins desc, c.next_move'
      else
        Q.SQL.Text :=
          'select c.next_move, c.game_count, c.white_wins as wins, c.draws, c.black_wins as losses ' +
          'from continuations c ' +
          'where c.position_key_lo = :position_key_lo and c.position_key_hi = :position_key_hi ' +
          'and c.side_to_move = :side_to_move ' +
          'order by c.game_count desc, wins desc, c.next_move';
      Q.ParamByName('side_to_move').AsString := SideToText(ASideToMove);
    end
    else if ASideToMove = dsBlack then
      Q.SQL.Text :=
        'select p.next_move, count(*) as game_count, ' +
        'sum(case when p.result = ''0-2'' then 1 else 0 end) as wins, ' +
        'sum(case when p.result = ''1-1'' then 1 else 0 end) as draws, ' +
        'sum(case when p.result = ''2-0'' then 1 else 0 end) as losses ' +
        'from positions p ' +
        'where p.position_key_lo = :position_key_lo and p.position_key_hi = :position_key_hi ' +
        'and p.side_to_move = :side_to_move ' +
        'and coalesce(p.next_move, '''') <> '''' ' +
        'group by p.next_move ' +
        'order by game_count desc, wins desc, p.next_move'
    else
      Q.SQL.Text :=
        'select p.next_move, count(*) as game_count, ' +
        'sum(case when p.result = ''2-0'' then 1 else 0 end) as wins, ' +
        'sum(case when p.result = ''1-1'' then 1 else 0 end) as draws, ' +
        'sum(case when p.result = ''0-2'' then 1 else 0 end) as losses ' +
        'from positions p ' +
        'where p.position_key_lo = :position_key_lo and p.position_key_hi = :position_key_hi ' +
        'and p.side_to_move = :side_to_move ' +
        'and coalesce(p.next_move, '''') <> '''' ' +
        'group by p.next_move ' +
        'order by game_count desc, wins desc, p.next_move';
    BindPositionKey(Q, APositionKey);
    Q.ParamByName('side_to_move').AsString := SideToText(ASideToMove);
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
