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

  TGameDatabase = class
  private
    FConnection: TSQLite3Connection;
    FFileName: string;
    FTransaction: TSQLTransaction;
    procedure ClearObjectList(AList: TList);
    function Query: TSQLQuery;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Close;
    procedure CreateDatabase(const AFileName: string);
    procedure OpenDatabase(const AFileName: string);
    procedure ImportPdnFile(const AFileName: string; out AImported,
      AErrors: Integer);
    procedure LoadGames(AList: TList);
    procedure SearchPosition(const APositionKey: string; ASideToMove: TDraughtsSide;
      AList: TList);

    property FileName: string read FFileName;
  end;

implementation

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

function TGameDatabase.Query: TSQLQuery;
begin
  Result := TSQLQuery.Create(nil);
  Result.DataBase := FConnection;
  Result.Transaction := FTransaction;
end;

procedure TGameDatabase.Close;
begin
  if FTransaction.Active then
    FTransaction.Commit;
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
  FTransaction.StartTransaction;
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
    Q.SQL.Text :=
      'create index if not exists idx_positions_key on positions(position_key)';
    Q.ExecSQL;
    Q.SQL.Text :=
      'create index if not exists idx_positions_game on positions(game_id)';
    Q.ExecSQL;
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
  AErrors: Integer);
var
  Board: TDraughtsBoard;
  Game: TPdnGame;
  GameId: Integer;
  Games: TList;
  I: Integer;
  Moves: TStringList;
  Points: Integer;
  Q: TSQLQuery;

  procedure InsertPosition(APly: Integer; const ANextMove: string);
  begin
    Q.SQL.Text :=
      'insert into positions(game_id, ply, position_key, side_to_move, next_move, result) ' +
      'values(:game_id, :ply, :position_key, :side_to_move, :next_move, :result)';
    Q.ParamByName('game_id').AsInteger := GameId;
    Q.ParamByName('ply').AsInteger := APly;
    Q.ParamByName('position_key').AsString := Board.PositionKey;
    Q.ParamByName('side_to_move').AsString := SideToText(Board.SideToMove);
    Q.ParamByName('next_move').AsString := ANextMove;
    Q.ParamByName('result').AsString := Game.ResultText;
    Q.ExecSQL;
  end;

begin
  AImported := 0;
  AErrors := 0;
  if not FConnection.Connected then
    raise EInvalidOperation.Create('No database is open');

  Games := TList.Create;
  Moves := TStringList.Create;
  Board := TDraughtsBoard.Create;
  Q := Query;
  try
    try
      LoadPdnGamesFromFile(AFileName, Games);
      FTransaction.StartTransaction;
      for I := 0 to Games.Count - 1 do
      begin
        Game := TPdnGame(Games[I]);
        try
          Moves.Clear;
          ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(Game.MovesText)),
            Moves);
          Board.LoadFromFEN(Game.StartingFEN);
          for Points := 0 to Moves.Count - 1 do
            Board.PlayMove(Moves[Points], False, True);
          Board.LoadFromFEN(Game.StartingFEN);

          Q.SQL.Text :=
            'insert into games(white, black, event, result, starting_fen, moves_text, annotations_text, ply_count) ' +
            'values(:white, :black, :event, :result, :starting_fen, :moves_text, :annotations_text, :ply_count)';
          Q.ParamByName('white').AsString := Game.WhiteName;
          Q.ParamByName('black').AsString := Game.BlackName;
          Q.ParamByName('event').AsString := Game.EventName;
          Q.ParamByName('result').AsString := Game.ResultText;
          Q.ParamByName('starting_fen').AsString := Game.StartingFEN;
          Q.ParamByName('moves_text').AsString := Game.MovesText;
          Q.ParamByName('annotations_text').AsString := Game.MoveAnnotationsText;
          Q.ParamByName('ply_count').AsInteger := Moves.Count;
          Q.ExecSQL;

          Q.SQL.Text := 'select last_insert_rowid() as id';
          Q.Open;
          GameId := Q.FieldByName('id').AsInteger;
          Q.Close;

          for Points := 0 to Moves.Count do
          begin
            if Points < Moves.Count then
              InsertPosition(Points, Moves[Points])
            else
              InsertPosition(Points, '');
            if Points < Moves.Count then
              Board.PlayMove(Moves[Points], False, True);
          end;
          Inc(AImported);
        except
          Inc(AErrors);
        end;
      end;
      FTransaction.Commit;
    except
      if FTransaction.Active then
        FTransaction.Rollback;
      raise;
    end;
  finally
    Q.Free;
    Board.Free;
    Moves.Free;
    ClearObjectList(Games);
    Games.Free;
  end;
end;

procedure TGameDatabase.LoadGames(AList: TList);
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
  end;
end;

end.
