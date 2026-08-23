unit uDraughtsBoard;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TPieceColor = (pcNone, pcWhite, pcBlack);
  TDraughtsPieceKind = (pkEmpty, pkWhiteMan, pkBlackMan, pkWhiteKing, pkBlackKing);
  TDraughtsSide = (dsWhite, dsBlack);

const
  DefaultStartingFEN = 'W:W31-50:B1-20';

type
  TDraughtsBoardArray = array[1..50] of TDraughtsPieceKind;
  TCapturedSet = array[1..50] of Boolean;

  TDraughtsBoard = class
  private
    FSquares: TDraughtsBoardArray;
    FSideToMove: TDraughtsSide;
    FStartingFEN: string;
    FMovesPlayed: TStringList;
    FLegalMoves: TStringList;
    FMaxCaptureCount: Integer;
    function GetLegalMove(AIndex: Integer): string;
    function GetLegalMoveCount: Integer;
    function GetMovePlayed(AIndex: Integer): string;
    function GetMovesPlayedCount: Integer;
    function GetSquare(Index: Integer): TDraughtsPieceKind;
    procedure SetSquare(Index: Integer; Value: TDraughtsPieceKind);
    procedure AddLegalMove(const ANotation: string; ACaptureCount: Integer);
    procedure AddManQuietMoves(ASquare: Integer);
    procedure AddKingQuietMoves(ASquare: Integer);
    function FindCapturedSquare(AFromSquare, AToSquare: Integer): Integer;
    procedure GenerateManCaptures(const ABoard: TDraughtsBoardArray;
      const ACapturedSet: TCapturedSet; AStartSquare, ASquare: Integer;
      const ACapturedText: string; ACaptureCount: Integer);
    procedure GenerateKingCaptures(const ABoard: TDraughtsBoardArray;
      const ACapturedSet: TCapturedSet; AStartSquare, ASquare: Integer;
      const ACapturedText: string; ACaptureCount: Integer);
  public
    constructor Create;
    destructor Destroy; override;

    procedure AssignFrom(ASource: TDraughtsBoard);
    procedure Clear;
    procedure SetBeginPosition;
    procedure LoadFromFEN(const AFEN: string);
    procedure GenerateLegalMoves;
    procedure AddMove(const AMove: string);
    function IsLegalMove(const AMove: string): Boolean;
    function TryGetLegalMove(const AMove: string; out ALegalMove: string): Boolean;
    procedure PlayMove(const AMove: string; ARecordMove: Boolean = True;
      AValidateLegal: Boolean = True; AUpdateLegalMoves: Boolean = True);
    function HubPosition: string;
    function MoveIsReversible(const AMove: string): Boolean;
    function CurrentFEN: string;
    function MovesPlayedText: string;
    function LegalMovesText: string;
    function PositionKey: string;
    procedure CopyLegalMovesTo(ATarget: TStrings);
    procedure CopyMovesPlayedTo(ATarget: TStrings);

    property Squares[Index: Integer]: TDraughtsPieceKind read GetSquare write SetSquare; default;
    property SideToMove: TDraughtsSide read FSideToMove write FSideToMove;
    property StartingFEN: string read FStartingFEN write LoadFromFEN;
    property MovesPlayed[AIndex: Integer]: string read GetMovePlayed;
    property MovesPlayedCount: Integer read GetMovesPlayedCount;
    property LegalMoves[AIndex: Integer]: string read GetLegalMove;
    property LegalMoveCount: Integer read GetLegalMoveCount;
  end;

function SquareToRowCol(ASquare: Integer; out ARow, ACol: Integer): Boolean;
function RowColToSquare(ARow, ACol: Integer): Integer;
function OppositeSide(ASide: TDraughtsSide): TDraughtsSide;
function PieceColor(APiece: TDraughtsPieceKind): TPieceColor;
function NormalizeMoveNotation(const AMove: string): string;

implementation

const
  DiagonalDeltas: array[0..3, 0..1] of Integer = (
    (-1, -1), (-1, 1), (1, -1), (1, 1)
  );

function SquareToRowCol(ASquare: Integer; out ARow, ACol: Integer): Boolean;
var
  LIndexInRow: Integer;
begin
  Result := (ASquare >= 1) and (ASquare <= 50);
  if not Result then
    Exit;

  ARow := (ASquare - 1) div 5;
  LIndexInRow := (ASquare - 1) mod 5;
  ACol := LIndexInRow * 2 + 1 - (ARow mod 2);
end;

function RowColToSquare(ARow, ACol: Integer): Integer;
begin
  if (ARow < 0) or (ARow > 9) or (ACol < 0) or (ACol > 9) then
    Exit(0);
  if ((ARow + ACol) mod 2) = 0 then
    Exit(0);

  Result := ARow * 5 + (ACol div 2) + 1;
end;

function OppositeSide(ASide: TDraughtsSide): TDraughtsSide;
begin
  if ASide = dsWhite then
    Result := dsBlack
  else
    Result := dsWhite;
end;

function PieceColor(APiece: TDraughtsPieceKind): TPieceColor;
begin
  case APiece of
    pkWhiteMan, pkWhiteKing:
      Result := pcWhite;
    pkBlackMan, pkBlackKing:
      Result := pcBlack;
  else
    Result := pcNone;
  end;
end;

function OwnsPiece(APiece: TDraughtsPieceKind; ASide: TDraughtsSide): Boolean;
begin
  Result := ((ASide = dsWhite) and (APiece in [pkWhiteMan, pkWhiteKing])) or
    ((ASide = dsBlack) and (APiece in [pkBlackMan, pkBlackKing]));
end;

function IsOpponentPiece(APiece: TDraughtsPieceKind; ASide: TDraughtsSide): Boolean;
begin
  Result := ((ASide = dsWhite) and (APiece in [pkBlackMan, pkBlackKing])) or
    ((ASide = dsBlack) and (APiece in [pkWhiteMan, pkWhiteKing]));
end;

function IsKing(APiece: TDraughtsPieceKind): Boolean;
begin
  Result := APiece in [pkWhiteKing, pkBlackKing];
end;

function ManForwardDelta(ASide: TDraughtsSide): Integer;
begin
  if ASide = dsWhite then
    Result := -1
  else
    Result := 1;
end;

procedure ClearBoard(var ABoard: TDraughtsBoardArray);
var
  I: Integer;
begin
  for I := Low(ABoard) to High(ABoard) do
    ABoard[I] := pkEmpty;
end;

function NextToken(var S: string; ADelimiter: Char): string;
var
  P: SizeInt;
begin
  P := Pos(ADelimiter, S);
  if P = 0 then
  begin
    Result := S;
    S := '';
  end
  else
  begin
    Result := Copy(S, 1, P - 1);
    Delete(S, 1, P);
  end;
  Result := Trim(Result);
end;

procedure PlaceFENRange(var ABoard: TDraughtsBoardArray; const ARange: string;
  APiece: TDraughtsPieceKind);
var
  DashPos, FirstSquare, LastSquare, Square: Integer;
begin
  if ARange = '' then
    Exit;

  DashPos := Pos('-', ARange);
  if DashPos = 0 then
  begin
    Square := StrToInt(ARange);
    if (Square < Low(ABoard)) or (Square > High(ABoard)) then
      raise EConvertError.CreateFmt('FEN square out of range: %d', [Square]);
    ABoard[Square] := APiece;
  end
  else
  begin
    FirstSquare := StrToInt(Copy(ARange, 1, DashPos - 1));
    LastSquare := StrToInt(Copy(ARange, DashPos + 1, MaxInt));
    if FirstSquare > LastSquare then
      raise EConvertError.CreateFmt('Invalid FEN range: %s', [ARange]);
    for Square := FirstSquare to LastSquare do
    begin
      if (Square < Low(ABoard)) or (Square > High(ABoard)) then
        raise EConvertError.CreateFmt('FEN square out of range: %d', [Square]);
      ABoard[Square] := APiece;
    end;
  end;
end;

function ExtractMoveSquares(const AMove: string; ASquares: TStrings): Boolean;
var
  I: Integer;
  LToken: string;
begin
  ASquares.Clear;
  LToken := '';
  for I := 1 to Length(AMove) do
  begin
    if AMove[I] in ['0'..'9'] then
      LToken := LToken + AMove[I]
    else if AMove[I] in ['-', 'x', 'X'] then
    begin
      if LToken = '' then
        Exit(False);
      ASquares.Add(LToken);
      LToken := '';
    end
    else if AMove[I] > ' ' then
      Exit(False);
  end;

  if LToken <> '' then
    ASquares.Add(LToken);
  Result := ASquares.Count >= 2;
end;

function NormalizeMoveNotation(const AMove: string): string;
var
  I: Integer;
  IsCapture: Boolean;
  Separator: string;
  Squares: TStringList;
begin
  Result := Trim(AMove);
  Squares := TStringList.Create;
  try
    if not ExtractMoveSquares(Result, Squares) then
      Exit;

    IsCapture := Pos('x', LowerCase(Result)) > 0;
    if IsCapture then
      Separator := 'x'
    else
      Separator := '-';

    Result := IntToStr(StrToIntDef(Squares[0], 0));
    for I := 1 to Squares.Count - 1 do
      Result := Result + Separator + IntToStr(StrToIntDef(Squares[I], 0));
  finally
    Squares.Free;
  end;
end;

function SameCapturedSquaresIgnoringOrder(AMoveSquares, ALegalSquares: TStrings): Boolean;
var
  I: Integer;
  Index: Integer;
  Remaining: TStringList;
begin
  Result := False;
  if AMoveSquares.Count <> ALegalSquares.Count then
    Exit;

  Remaining := TStringList.Create;
  try
    for I := 2 to ALegalSquares.Count - 1 do
      Remaining.Add(ALegalSquares[I]);

    for I := 2 to AMoveSquares.Count - 1 do
    begin
      Index := Remaining.IndexOf(AMoveSquares[I]);
      if Index < 0 then
        Exit;
      Remaining.Delete(Index);
    end;

    Result := Remaining.Count = 0;
  finally
    Remaining.Free;
  end;
end;

function CaptureMoveAliasMatchesCanonical(const AAliasMove,
  ACanonicalMove: string): Boolean;
var
  AliasSquares: TStringList;
  CanonicalSquares: TStringList;
begin
  Result := False;
  if (Pos('x', LowerCase(AAliasMove)) = 0) or
    (Pos('x', LowerCase(ACanonicalMove)) = 0) then
    Exit;

  AliasSquares := TStringList.Create;
  CanonicalSquares := TStringList.Create;
  try
    if (not ExtractMoveSquares(AAliasMove, AliasSquares)) or
      (not ExtractMoveSquares(ACanonicalMove, CanonicalSquares)) then
      Exit;
    if (AliasSquares.Count < 2) or (CanonicalSquares.Count < 2) then
      Exit;
    if (AliasSquares[0] <> CanonicalSquares[0]) or
      (AliasSquares[1] <> CanonicalSquares[1]) then
      Exit;

    // Some PDN files write captures as source x final landing, omitting the
    // captured-square list that our canonical move notation stores.
    if AliasSquares.Count = 2 then
    begin
      Result := CanonicalSquares.Count >= 3;
      Exit;
    end;

    // Engines and databases may list captured pieces in another order.
    Result := SameCapturedSquaresIgnoringOrder(AliasSquares, CanonicalSquares);
  finally
    CanonicalSquares.Free;
    AliasSquares.Free;
  end;
end;

constructor TDraughtsBoard.Create;
begin
  inherited Create;
  FMovesPlayed := TStringList.Create;
  FLegalMoves := TStringList.Create;
  SetBeginPosition;
end;

destructor TDraughtsBoard.Destroy;
begin
  FLegalMoves.Free;
  FMovesPlayed.Free;
  inherited Destroy;
end;

function TDraughtsBoard.GetLegalMove(AIndex: Integer): string;
begin
  Result := FLegalMoves[AIndex];
end;

function TDraughtsBoard.GetLegalMoveCount: Integer;
begin
  Result := FLegalMoves.Count;
end;

function TDraughtsBoard.GetMovePlayed(AIndex: Integer): string;
begin
  Result := FMovesPlayed[AIndex];
end;

function TDraughtsBoard.GetMovesPlayedCount: Integer;
begin
  Result := FMovesPlayed.Count;
end;

procedure TDraughtsBoard.AssignFrom(ASource: TDraughtsBoard);
begin
  if ASource = nil then
    Exit;
  FSquares := ASource.FSquares;
  FSideToMove := ASource.FSideToMove;
  FStartingFEN := ASource.FStartingFEN;
  FMaxCaptureCount := ASource.FMaxCaptureCount;
  FMovesPlayed.Assign(ASource.FMovesPlayed);
  FLegalMoves.Assign(ASource.FLegalMoves);
end;

function TDraughtsBoard.GetSquare(Index: Integer): TDraughtsPieceKind;
begin
  if (Index < Low(FSquares)) or (Index > High(FSquares)) then
    raise ERangeError.CreateFmt('Draughts square index out of range: %d', [Index]);
  Result := FSquares[Index];
end;

procedure TDraughtsBoard.SetSquare(Index: Integer; Value: TDraughtsPieceKind);
begin
  if (Index < Low(FSquares)) or (Index > High(FSquares)) then
    raise ERangeError.CreateFmt('Draughts square index out of range: %d', [Index]);
  FSquares[Index] := Value;
  GenerateLegalMoves;
end;

procedure TDraughtsBoard.Clear;
begin
  ClearBoard(FSquares);
  FSideToMove := dsWhite;
  FMovesPlayed.Clear;
  FLegalMoves.Clear;
  FMaxCaptureCount := 0;
end;

procedure TDraughtsBoard.SetBeginPosition;
begin
  LoadFromFEN(DefaultStartingFEN);
end;

procedure TDraughtsBoard.LoadFromFEN(const AFEN: string);
var
  I: Integer;
  LBoard: TDraughtsBoardArray;
  LPart, LPieceList, LEntry: string;
  LPiece: TDraughtsPieceKind;
  LSideChar: Char;
begin
  if Trim(AFEN) = '' then
    raise EConvertError.Create('FEN cannot be empty');

  for I := Low(LBoard) to High(LBoard) do
    LBoard[I] := pkEmpty;
  LPieceList := Trim(AFEN);
  LPart := NextToken(LPieceList, ':');
  if Length(LPart) <> 1 then
    raise EConvertError.CreateFmt('Invalid FEN side-to-move field: %s', [LPart]);

  LSideChar := UpCase(LPart[1]);
  case LSideChar of
    'W':
      FSideToMove := dsWhite;
    'B':
      FSideToMove := dsBlack;
  else
    raise EConvertError.CreateFmt('Invalid FEN side to move: %s', [LPart]);
  end;

  while LPieceList <> '' do
  begin
    LPart := NextToken(LPieceList, ':');
    if LPart = '' then
      Continue;

    case UpCase(LPart[1]) of
      'W':
        LPiece := pkWhiteMan;
      'B':
        LPiece := pkBlackMan;
    else
      raise EConvertError.CreateFmt('Invalid FEN piece section: %s', [LPart]);
    end;

    Delete(LPart, 1, 1);
    while LPart <> '' do
    begin
      LEntry := NextToken(LPart, ',');
      if LEntry = '' then
        Continue;
      if UpCase(LEntry[1]) = 'K' then
      begin
        if LPiece = pkWhiteMan then
          LPiece := pkWhiteKing
        else
          LPiece := pkBlackKing;
        Delete(LEntry, 1, 1);
      end;
      PlaceFENRange(LBoard, LEntry, LPiece);
      if LPiece = pkWhiteKing then
        LPiece := pkWhiteMan
      else if LPiece = pkBlackKing then
        LPiece := pkBlackMan;
    end;
  end;

  FSquares := LBoard;
  FStartingFEN := Trim(AFEN);
  FMovesPlayed.Clear;
  GenerateLegalMoves;
end;

procedure TDraughtsBoard.AddLegalMove(const ANotation: string; ACaptureCount: Integer);
var
  I: Integer;
begin
  if ACaptureCount < FMaxCaptureCount then
    Exit;
  if ACaptureCount > FMaxCaptureCount then
  begin
    FLegalMoves.Clear;
    FMaxCaptureCount := ACaptureCount;
  end;
  if FLegalMoves.IndexOf(ANotation) < 0 then
  begin
    if Pos('x', LowerCase(ANotation)) > 0 then
      for I := 0 to FLegalMoves.Count - 1 do
        if CaptureMoveAliasMatchesCanonical(ANotation, FLegalMoves[I]) then
          Exit;
    FLegalMoves.Add(ANotation);
  end;
end;

procedure TDraughtsBoard.AddManQuietMoves(ASquare: Integer);
var
  LCol, LDirection, LRow, LTarget: Integer;
begin
  SquareToRowCol(ASquare, LRow, LCol);
  LDirection := ManForwardDelta(FSideToMove);

  LTarget := RowColToSquare(LRow + LDirection, LCol - 1);
  if (LTarget > 0) and (FSquares[LTarget] = pkEmpty) then
    AddLegalMove(IntToStr(ASquare) + '-' + IntToStr(LTarget), 0);

  LTarget := RowColToSquare(LRow + LDirection, LCol + 1);
  if (LTarget > 0) and (FSquares[LTarget] = pkEmpty) then
    AddLegalMove(IntToStr(ASquare) + '-' + IntToStr(LTarget), 0);
end;

procedure TDraughtsBoard.AddKingQuietMoves(ASquare: Integer);
var
  D, LCol, LRow, LTarget, LTargetCol, LTargetRow: Integer;
begin
  SquareToRowCol(ASquare, LRow, LCol);
  for D := Low(DiagonalDeltas) to High(DiagonalDeltas) do
  begin
    LTargetRow := LRow + DiagonalDeltas[D, 0];
    LTargetCol := LCol + DiagonalDeltas[D, 1];
    LTarget := RowColToSquare(LTargetRow, LTargetCol);
    while (LTarget > 0) and (FSquares[LTarget] = pkEmpty) do
    begin
      AddLegalMove(IntToStr(ASquare) + '-' + IntToStr(LTarget), 0);
      Inc(LTargetRow, DiagonalDeltas[D, 0]);
      Inc(LTargetCol, DiagonalDeltas[D, 1]);
      LTarget := RowColToSquare(LTargetRow, LTargetCol);
    end;
  end;
end;

function TDraughtsBoard.FindCapturedSquare(AFromSquare, AToSquare: Integer): Integer;
var
  LCol, LDirectionCol, LDirectionRow, LFromCol, LFromRow, LRow, LSquare, LToCol,
    LToRow: Integer;
begin
  Result := 0;
  if (not SquareToRowCol(AFromSquare, LFromRow, LFromCol)) or
    (not SquareToRowCol(AToSquare, LToRow, LToCol)) then
    Exit;

  if Abs(LToRow - LFromRow) <> Abs(LToCol - LFromCol) then
    Exit;

  if LToRow > LFromRow then
    LDirectionRow := 1
  else
    LDirectionRow := -1;
  if LToCol > LFromCol then
    LDirectionCol := 1
  else
    LDirectionCol := -1;

  LRow := LFromRow + LDirectionRow;
  LCol := LFromCol + LDirectionCol;
  while (LRow <> LToRow) and (LCol <> LToCol) do
  begin
    LSquare := RowColToSquare(LRow, LCol);
    if (LSquare > 0) and (FSquares[LSquare] <> pkEmpty) then
    begin
      if IsOpponentPiece(FSquares[LSquare], FSideToMove) then
      begin
        if Result <> 0 then
          Exit(0);
        Result := LSquare;
      end
      else
        Exit(0);
    end;
    Inc(LRow, LDirectionRow);
    Inc(LCol, LDirectionCol);
  end;
end;

procedure TDraughtsBoard.GenerateManCaptures(const ABoard: TDraughtsBoardArray;
  const ACapturedSet: TCapturedSet; AStartSquare, ASquare: Integer;
  const ACapturedText: string; ACaptureCount: Integer);
var
  LCapturedSet: TCapturedSet;
  D, LCol, LCaptured, LLanding, LRow: Integer;
  LNextBoard: TDraughtsBoardArray;
  LFound: Boolean;
  LNextCapturedText: string;
begin
  LFound := False;
  SquareToRowCol(ASquare, LRow, LCol);

  for D := Low(DiagonalDeltas) to High(DiagonalDeltas) do
  begin
    LCaptured := RowColToSquare(LRow + DiagonalDeltas[D, 0], LCol + DiagonalDeltas[D, 1]);
    LLanding := RowColToSquare(LRow + DiagonalDeltas[D, 0] * 2, LCol + DiagonalDeltas[D, 1] * 2);
    if (LCaptured > 0) and (LLanding > 0) and
      (not ACapturedSet[LCaptured]) and
      IsOpponentPiece(ABoard[LCaptured], FSideToMove) and (ABoard[LLanding] = pkEmpty) then
    begin
      LNextBoard := ABoard;
      LNextBoard[LLanding] := LNextBoard[ASquare];
      LNextBoard[ASquare] := pkEmpty;
      LCapturedSet := ACapturedSet;
      LCapturedSet[LCaptured] := True;
      LNextCapturedText := ACapturedText + 'x' + IntToStr(LCaptured);
      GenerateManCaptures(LNextBoard, LCapturedSet, AStartSquare, LLanding,
        LNextCapturedText, ACaptureCount + 1);
      LFound := True;
    end;
  end;

  if (not LFound) and (ACaptureCount > 0) then
    AddLegalMove(IntToStr(AStartSquare) + 'x' + IntToStr(ASquare) +
      ACapturedText, ACaptureCount);
end;

procedure TDraughtsBoard.GenerateKingCaptures(const ABoard: TDraughtsBoardArray;
  const ACapturedSet: TCapturedSet; AStartSquare, ASquare: Integer;
  const ACapturedText: string; ACaptureCount: Integer);
var
  LCapturedSet: TCapturedSet;
  D, LCol, LCaptured, LLanding, LRow, LScanCol, LScanRow: Integer;
  LNextBoard: TDraughtsBoardArray;
  LFound: Boolean;
  LNextCapturedText: string;
begin
  LFound := False;
  SquareToRowCol(ASquare, LRow, LCol);

  for D := Low(DiagonalDeltas) to High(DiagonalDeltas) do
  begin
    LCaptured := 0;
    LScanRow := LRow + DiagonalDeltas[D, 0];
    LScanCol := LCol + DiagonalDeltas[D, 1];
    LLanding := RowColToSquare(LScanRow, LScanCol);

    while LLanding > 0 do
    begin
      if ABoard[LLanding] <> pkEmpty then
      begin
        if IsOpponentPiece(ABoard[LLanding], FSideToMove) and
          (not ACapturedSet[LLanding]) then
          LCaptured := LLanding;
        Break;
      end;
      Inc(LScanRow, DiagonalDeltas[D, 0]);
      Inc(LScanCol, DiagonalDeltas[D, 1]);
      LLanding := RowColToSquare(LScanRow, LScanCol);
    end;

    if LCaptured = 0 then
      Continue;

    LScanRow := LScanRow + DiagonalDeltas[D, 0];
    LScanCol := LScanCol + DiagonalDeltas[D, 1];
    LLanding := RowColToSquare(LScanRow, LScanCol);
    while (LLanding > 0) and (ABoard[LLanding] = pkEmpty) do
    begin
      LNextBoard := ABoard;
      LNextBoard[LLanding] := LNextBoard[ASquare];
      LNextBoard[ASquare] := pkEmpty;
      LCapturedSet := ACapturedSet;
      LCapturedSet[LCaptured] := True;
      LNextCapturedText := ACapturedText + 'x' + IntToStr(LCaptured);
      GenerateKingCaptures(LNextBoard, LCapturedSet, AStartSquare, LLanding,
        LNextCapturedText, ACaptureCount + 1);
      LFound := True;

      Inc(LScanRow, DiagonalDeltas[D, 0]);
      Inc(LScanCol, DiagonalDeltas[D, 1]);
      LLanding := RowColToSquare(LScanRow, LScanCol);
    end;
  end;

  if (not LFound) and (ACaptureCount > 0) then
    AddLegalMove(IntToStr(AStartSquare) + 'x' + IntToStr(ASquare) +
      ACapturedText, ACaptureCount);
end;

procedure TDraughtsBoard.GenerateLegalMoves;
var
  LCapturedSet: TCapturedSet;
  I: Integer;
begin
  FLegalMoves.Clear;
  FMaxCaptureCount := 0;
  for I := Low(LCapturedSet) to High(LCapturedSet) do
    LCapturedSet[I] := False;

  for I := Low(FSquares) to High(FSquares) do
    if OwnsPiece(FSquares[I], FSideToMove) then
    begin
      if IsKing(FSquares[I]) then
        GenerateKingCaptures(FSquares, LCapturedSet, I, I, '', 0)
      else
        GenerateManCaptures(FSquares, LCapturedSet, I, I, '', 0);
    end;

  if FLegalMoves.Count > 0 then
    Exit;

  for I := Low(FSquares) to High(FSquares) do
    if OwnsPiece(FSquares[I], FSideToMove) then
    begin
      if IsKing(FSquares[I]) then
        AddKingQuietMoves(I)
      else
        AddManQuietMoves(I);
    end;
end;

procedure TDraughtsBoard.AddMove(const AMove: string);
begin
  if Trim(AMove) = '' then
    Exit;

  FMovesPlayed.Add(NormalizeMoveNotation(AMove));
end;

function TDraughtsBoard.IsLegalMove(const AMove: string): Boolean;
var
  LLegalMove: string;
begin
  Result := TryGetLegalMove(AMove, LLegalMove);
end;

function TDraughtsBoard.TryGetLegalMove(const AMove: string;
  out ALegalMove: string): Boolean;
var
  I: Integer;
  LMove: string;

  function TryFindCanonicalMoveAlias: Boolean;
  var
    AliasIndex: Integer;
    Ambiguous: Boolean;
    MatchedMove: string;
  begin
    Result := False;
    if Pos('x', LowerCase(LMove)) = 0 then
      Exit;

    Ambiguous := False;
    MatchedMove := '';
    for AliasIndex := 0 to FLegalMoves.Count - 1 do
      if CaptureMoveAliasMatchesCanonical(LMove, FLegalMoves[AliasIndex]) then
      begin
        if MatchedMove = '' then
          MatchedMove := FLegalMoves[AliasIndex]
        else if not CaptureMoveAliasMatchesCanonical(MatchedMove,
          FLegalMoves[AliasIndex]) then
          Ambiguous := True;
      end;
    if (MatchedMove <> '') and (not Ambiguous) then
    begin
      ALegalMove := MatchedMove;
      Result := True;
    end;
  end;

begin
  ALegalMove := '';
  LMove := NormalizeMoveNotation(AMove);

  I := FLegalMoves.IndexOf(LMove);
  if I >= 0 then
  begin
    ALegalMove := FLegalMoves[I];
    Exit(True);
  end;

  Result := TryFindCanonicalMoveAlias;
end;

procedure TDraughtsBoard.PlayMove(const AMove: string; ARecordMove: Boolean;
  AValidateLegal: Boolean; AUpdateLegalMoves: Boolean);
var
  I, LCaptured, LFromSquare, LRow, LToSquare: Integer;
  LIsCapture: Boolean;
  LLegalMove: string;
  LMove: string;
  LPiece: TDraughtsPieceKind;
  LSquares: TStringList;
begin
  LMove := NormalizeMoveNotation(AMove);
  if LMove = '' then
    Exit;
  if AValidateLegal then
  begin
    if not TryGetLegalMove(LMove, LLegalMove) then
      raise EInvalidOperation.Create('Illegal move: ' + LMove);
    LMove := LLegalMove;
  end;

  LSquares := TStringList.Create;
  try
    if not ExtractMoveSquares(LMove, LSquares) then
      raise EConvertError.CreateFmt('Invalid move notation: %s', [LMove]);

    LFromSquare := StrToInt(LSquares[0]);
    if (LFromSquare < Low(FSquares)) or (LFromSquare > High(FSquares)) then
      raise ERangeError.CreateFmt('Move square out of range: %d', [LFromSquare]);

    LPiece := FSquares[LFromSquare];
    if LPiece = pkEmpty then
      raise EInvalidOperation.CreateFmt('No piece on move source square: %d', [LFromSquare]);

    LIsCapture := Pos('x', LowerCase(LMove)) > 0;
    FSquares[LFromSquare] := pkEmpty;
    LToSquare := StrToInt(LSquares[1]);
    if (LToSquare < Low(FSquares)) or (LToSquare > High(FSquares)) then
      raise ERangeError.CreateFmt('Move square out of range: %d', [LToSquare]);
    if FSquares[LToSquare] <> pkEmpty then
      raise EInvalidOperation.CreateFmt('Move target square is occupied: %d', [LToSquare]);

    if LIsCapture then
    begin
      if LSquares.Count = 2 then
      begin
        LCaptured := FindCapturedSquare(LFromSquare, LToSquare);
        if LCaptured = 0 then
          raise EInvalidOperation.CreateFmt('No captured piece between %d and %d',
            [LFromSquare, LToSquare]);
        FSquares[LCaptured] := pkEmpty;
      end;
      for I := 2 to LSquares.Count - 1 do
      begin
        LCaptured := StrToInt(LSquares[I]);
        if (LCaptured < Low(FSquares)) or (LCaptured > High(FSquares)) then
          raise ERangeError.CreateFmt('Move square out of range: %d', [LCaptured]);
        if not IsOpponentPiece(FSquares[LCaptured], FSideToMove) then
          raise EInvalidOperation.CreateFmt('No opponent piece on captured square: %d',
            [LCaptured]);
        FSquares[LCaptured] := pkEmpty;
      end;
    end;

    if SquareToRowCol(LToSquare, LRow, I) then
    begin
      if (LPiece = pkWhiteMan) and (LRow = 0) then
        LPiece := pkWhiteKing
      else if (LPiece = pkBlackMan) and (LRow = 9) then
        LPiece := pkBlackKing;
    end;

    FSquares[LToSquare] := LPiece;
    FSideToMove := OppositeSide(FSideToMove);
    if ARecordMove then
      FMovesPlayed.Add(LMove);
    if AUpdateLegalMoves then
      GenerateLegalMoves
    else
      FLegalMoves.Clear;
  finally
    LSquares.Free;
  end;
end;

function TDraughtsBoard.HubPosition: string;
const
  PieceChars: array[TDraughtsPieceKind] of Char = ('e', 'w', 'b', 'W', 'B');
var
  I: Integer;
begin
  if FSideToMove = dsWhite then
    Result := 'W'
  else
    Result := 'B';

  for I := Low(FSquares) to High(FSquares) do
    Result := Result + PieceChars[FSquares[I]];
end;

function TDraughtsBoard.MoveIsReversible(const AMove: string): Boolean;
var
  LFromSquare, LToSquare: Integer;
  LMove: string;
  LSquares: TStringList;
begin
  Result := False;
  LMove := Trim(AMove);
  if (LMove = '') or (Pos('x', LowerCase(LMove)) > 0) then
    Exit;

  LSquares := TStringList.Create;
  try
    if not ExtractMoveSquares(LMove, LSquares) then
      Exit;

    LFromSquare := StrToIntDef(LSquares[0], 0);
    LToSquare := StrToIntDef(LSquares[1], 0);
    if (LFromSquare < Low(FSquares)) or (LFromSquare > High(FSquares)) or
      (LToSquare < Low(FSquares)) or (LToSquare > High(FSquares)) then
      Exit;

    Result := FSquares[LFromSquare] in [pkWhiteKing, pkBlackKing];
  finally
    LSquares.Free;
  end;
end;

function TDraughtsBoard.MovesPlayedText: string;
begin
  Result := FMovesPlayed.Text;
  Result := Trim(StringReplace(Result, LineEnding, ' ', [rfReplaceAll]));
end;

function TDraughtsBoard.LegalMovesText: string;
begin
  Result := FLegalMoves.Text;
end;

procedure TDraughtsBoard.CopyLegalMovesTo(ATarget: TStrings);
begin
  if ATarget <> nil then
    ATarget.AddStrings(FLegalMoves);
end;

procedure TDraughtsBoard.CopyMovesPlayedTo(ATarget: TStrings);
begin
  if ATarget <> nil then
    ATarget.AddStrings(FMovesPlayed);
end;

function TDraughtsBoard.CurrentFEN: string;

  procedure AppendPieces(APiece: TDraughtsPieceKind; const APrefix: string);
  var
    I: Integer;
    LFirst: Boolean;
  begin
    LFirst := True;
    for I := Low(FSquares) to High(FSquares) do
      if FSquares[I] = APiece then
      begin
        if LFirst then
        begin
          Result += ':' + APrefix;
          LFirst := False;
        end
        else
          Result += ',';
        Result += IntToStr(I);
      end;
  end;

begin
  if FSideToMove = dsWhite then
    Result := 'W'
  else
    Result := 'B';
  AppendPieces(pkWhiteMan, 'W');
  AppendPieces(pkWhiteKing, 'WK');
  AppendPieces(pkBlackMan, 'B');
  AppendPieces(pkBlackKing, 'BK');
end;

function TDraughtsBoard.PositionKey: string;
const
  PieceChars: array[TDraughtsPieceKind] of Char = ('e', 'w', 'b', 'W', 'B');
var
  I: Integer;
begin
  if FSideToMove = dsWhite then
    Result := 'W|'
  else
    Result := 'B|';

  for I := Low(FSquares) to High(FSquares) do
    Result := Result + PieceChars[FSquares[I]];
end;

end.
