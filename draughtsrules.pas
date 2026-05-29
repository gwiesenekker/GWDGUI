unit DraughtsRules;

{$mode objfpc}{$H+}

interface

uses
  Classes;

type
  TPiece = (pcNone, pcWhiteMan, pcWhiteKing, pcBlackMan, pcBlackKing);
  TSide = (sideWhite, sideBlack);
  TBoard = array[1..50] of TPiece;

  TMove = record
    Squares: array of Integer;
    Captures: array of Integer;
    Promotes: Boolean;
  end;

  TMoveArray = array of TMove;

procedure GenerateLegalMoves(const ABoard: TBoard; ASide: TSide; out AMoves: TMoveArray);
function MoveToString(const AMove: TMove): String;
function MoveToHubString(const AMove: TMove;
  ASingleCapturesIncludeCapturedSquare: Boolean = True): String;
function PieceBelongsToSide(APiece: TPiece; ASide: TSide): Boolean;

implementation

uses
  SysUtils;

const
  DirectionCount = 4;
  DirectionRows: array[0..DirectionCount - 1] of Integer = (-1, -1, 1, 1);
  DirectionCols: array[0..DirectionCount - 1] of Integer = (-1, 1, -1, 1);

type
  TCapturedSet = array[1..50] of Boolean;
  TIntArray = array of Integer;

function OppositeSide(ASide: TSide): TSide;
begin
  if ASide = sideWhite then
    Result := sideBlack
  else
    Result := sideWhite;
end;

function IsKing(APiece: TPiece): Boolean;
begin
  Result := APiece in [pcWhiteKing, pcBlackKing];
end;

function PromotionRow(ASide: TSide): Integer;
begin
  if ASide = sideWhite then
    Result := 0
  else
    Result := 9;
end;

function PieceBelongsToSide(APiece: TPiece; ASide: TSide): Boolean;
begin
  case ASide of
    sideWhite: Result := APiece in [pcWhiteMan, pcWhiteKing];
    sideBlack: Result := APiece in [pcBlackMan, pcBlackKing];
  else
    Result := False;
  end;
end;

function IsOpponentPiece(APiece: TPiece; ASide: TSide): Boolean;
begin
  Result := PieceBelongsToSide(APiece, OppositeSide(ASide));
end;

procedure SquareToRowCol(ASquare: Integer; out ARow, ACol: Integer);
begin
  ARow := (ASquare - 1) div 5;
  if Odd(ARow) then
    ACol := ((ASquare - 1) mod 5) * 2
  else
    ACol := ((ASquare - 1) mod 5) * 2 + 1;
end;

function RowColToSquare(ARow, ACol: Integer): Integer;
begin
  if (ARow < 0) or (ARow > 9) or (ACol < 0) or (ACol > 9) or
    (not Odd(ARow + ACol)) then
    Exit(0);

  Result := (ARow * 5) + (ACol div 2) + 1;
end;

procedure AddMove(var AMoves: TMoveArray; const APath: array of Integer;
  const ACaptures: array of Integer; APromotes: Boolean);
var
  I: Integer;
  MoveIndex: Integer;
begin
  MoveIndex := Length(AMoves);
  SetLength(AMoves, MoveIndex + 1);
  SetLength(AMoves[MoveIndex].Squares, Length(APath));
  SetLength(AMoves[MoveIndex].Captures, Length(ACaptures));

  for I := 0 to High(APath) do
    AMoves[MoveIndex].Squares[I] := APath[I];
  for I := 0 to High(ACaptures) do
    AMoves[MoveIndex].Captures[I] := ACaptures[I];

  AMoves[MoveIndex].Promotes := APromotes;
end;

procedure CopyAndAppend(const ASource: array of Integer; AValue: Integer;
  out ADest: TIntArray);
var
  I: Integer;
begin
  SetLength(ADest, Length(ASource) + 1);
  for I := 0 to High(ASource) do
    ADest[I] := ASource[I];
  ADest[High(ADest)] := AValue;
end;

procedure GenerateManCaptures(const ABoard: TBoard; ASide: TSide;
  ASquare: Integer; const APath: array of Integer; const ACaptures: array of Integer;
  const ACapturedSet: TCapturedSet; var AMoves: TMoveArray);
var
  BoardAfter: TBoard;
  CapturedSetAfter: TCapturedSet;
  CaptureSquare: Integer;
  Dir: Integer;
  FromRow: Integer;
  FromCol: Integer;
  LandingRow: Integer;
  LandingCol: Integer;
  LandingSquare: Integer;
  NewCaptures: TIntArray;
  NewPath: TIntArray;
  Piece: TPiece;
  FoundCapture: Boolean;
begin
  FoundCapture := False;
  Piece := ABoard[ASquare];
  SquareToRowCol(ASquare, FromRow, FromCol);

  for Dir := 0 to DirectionCount - 1 do
  begin
    CaptureSquare := RowColToSquare(FromRow + DirectionRows[Dir],
      FromCol + DirectionCols[Dir]);
    LandingRow := FromRow + (2 * DirectionRows[Dir]);
    LandingCol := FromCol + (2 * DirectionCols[Dir]);
    LandingSquare := RowColToSquare(LandingRow, LandingCol);

    if (CaptureSquare = 0) or (LandingSquare = 0) then
      Continue;
    if ACapturedSet[CaptureSquare] then
      Continue;
    if (not IsOpponentPiece(ABoard[CaptureSquare], ASide)) or
      (ABoard[LandingSquare] <> pcNone) then
      Continue;

    FoundCapture := True;
    BoardAfter := ABoard;
    BoardAfter[ASquare] := pcNone;
    BoardAfter[LandingSquare] := Piece;

    CapturedSetAfter := ACapturedSet;
    CapturedSetAfter[CaptureSquare] := True;
    CopyAndAppend(APath, LandingSquare, NewPath);
    CopyAndAppend(ACaptures, CaptureSquare, NewCaptures);
    GenerateManCaptures(BoardAfter, ASide, LandingSquare, NewPath, NewCaptures,
      CapturedSetAfter, AMoves);
  end;

  if (not FoundCapture) and (Length(ACaptures) > 0) then
    AddMove(AMoves, APath, ACaptures, FromRow = PromotionRow(ASide));
end;

procedure GenerateKingCaptures(const ABoard: TBoard; ASide: TSide;
  ASquare: Integer; const APath: array of Integer; const ACaptures: array of Integer;
  const ACapturedSet: TCapturedSet; var AMoves: TMoveArray);
var
  BoardAfter: TBoard;
  CapturedSetAfter: TCapturedSet;
  CaptureSquare: Integer;
  Dir: Integer;
  FromRow: Integer;
  FromCol: Integer;
  LandingRow: Integer;
  LandingCol: Integer;
  LandingSquare: Integer;
  NewCaptures: TIntArray;
  NewPath: TIntArray;
  Piece: TPiece;
  ScanRow: Integer;
  ScanCol: Integer;
  ScanSquare: Integer;
  FoundCapture: Boolean;
begin
  FoundCapture := False;
  Piece := ABoard[ASquare];
  SquareToRowCol(ASquare, FromRow, FromCol);

  for Dir := 0 to DirectionCount - 1 do
  begin
    CaptureSquare := 0;
    ScanRow := FromRow + DirectionRows[Dir];
    ScanCol := FromCol + DirectionCols[Dir];

    while True do
    begin
      ScanSquare := RowColToSquare(ScanRow, ScanCol);
      if ScanSquare = 0 then
        Break;

      if ABoard[ScanSquare] <> pcNone then
      begin
        if IsOpponentPiece(ABoard[ScanSquare], ASide) and
          (not ACapturedSet[ScanSquare]) then
          CaptureSquare := ScanSquare;
        Break;
      end;

      Inc(ScanRow, DirectionRows[Dir]);
      Inc(ScanCol, DirectionCols[Dir]);
    end;

    if CaptureSquare = 0 then
      Continue;

    LandingRow := ScanRow + DirectionRows[Dir];
    LandingCol := ScanCol + DirectionCols[Dir];
    while True do
    begin
      LandingSquare := RowColToSquare(LandingRow, LandingCol);
      if LandingSquare = 0 then
        Break;
      if ABoard[LandingSquare] <> pcNone then
        Break;

      FoundCapture := True;
      BoardAfter := ABoard;
      BoardAfter[ASquare] := pcNone;
      BoardAfter[LandingSquare] := Piece;

      CapturedSetAfter := ACapturedSet;
      CapturedSetAfter[CaptureSquare] := True;
      CopyAndAppend(APath, LandingSquare, NewPath);
      CopyAndAppend(ACaptures, CaptureSquare, NewCaptures);
      GenerateKingCaptures(BoardAfter, ASide, LandingSquare, NewPath, NewCaptures,
        CapturedSetAfter, AMoves);

      Inc(LandingRow, DirectionRows[Dir]);
      Inc(LandingCol, DirectionCols[Dir]);
    end;
  end;

  if (not FoundCapture) and (Length(ACaptures) > 0) then
    AddMove(AMoves, APath, ACaptures, False);
end;

procedure GenerateCapturesForPiece(const ABoard: TBoard; ASide: TSide;
  ASquare: Integer; var AMoves: TMoveArray);
var
  CapturedSet: TCapturedSet;
  Captures: TIntArray;
  Path: TIntArray;
begin
  FillChar(CapturedSet, SizeOf(CapturedSet), 0);
  SetLength(Path, 1);
  Path[0] := ASquare;
  SetLength(Captures, 0);

  if IsKing(ABoard[ASquare]) then
    GenerateKingCaptures(ABoard, ASide, ASquare, Path, Captures, CapturedSet, AMoves)
  else
    GenerateManCaptures(ABoard, ASide, ASquare, Path, Captures, CapturedSet, AMoves);
end;

procedure GenerateQuietMoves(const ABoard: TBoard; ASide: TSide; var AMoves: TMoveArray);
var
  Col: Integer;
  Dir: Integer;
  ForwardRowDelta: Integer;
  FromCol: Integer;
  FromRow: Integer;
  FromSquare: Integer;
  LandingSquare: Integer;
  Path: TIntArray;
  Row: Integer;
begin
  if ASide = sideWhite then
    ForwardRowDelta := -1
  else
    ForwardRowDelta := 1;

  for FromSquare := Low(ABoard) to High(ABoard) do
  begin
    if not PieceBelongsToSide(ABoard[FromSquare], ASide) then
      Continue;

    SquareToRowCol(FromSquare, FromRow, FromCol);

    if IsKing(ABoard[FromSquare]) then
    begin
      for Dir := 0 to DirectionCount - 1 do
      begin
        Row := FromRow + DirectionRows[Dir];
        Col := FromCol + DirectionCols[Dir];
        while True do
        begin
          LandingSquare := RowColToSquare(Row, Col);
          if (LandingSquare = 0) or (ABoard[LandingSquare] <> pcNone) then
            Break;

          SetLength(Path, 2);
          Path[0] := FromSquare;
          Path[1] := LandingSquare;
          AddMove(AMoves, Path, [], False);

          Inc(Row, DirectionRows[Dir]);
          Inc(Col, DirectionCols[Dir]);
        end;
      end;
    end
    else
    begin
      for Dir := -1 to 1 do
      begin
        if Dir = 0 then
          Continue;
        LandingSquare := RowColToSquare(FromRow + ForwardRowDelta, FromCol + Dir);
        if (LandingSquare <> 0) and (ABoard[LandingSquare] = pcNone) then
        begin
          SetLength(Path, 2);
          Path[0] := FromSquare;
          Path[1] := LandingSquare;
          AddMove(AMoves, Path, [], (FromRow + ForwardRowDelta) = PromotionRow(ASide));
        end;
      end;
    end;
  end;
end;

procedure KeepOnlyLongestCaptures(var AMoves: TMoveArray);
var
  I: Integer;
  MaxCaptures: Integer;
  Kept: TMoveArray;
begin
  MaxCaptures := 0;
  for I := 0 to High(AMoves) do
    if Length(AMoves[I].Captures) > MaxCaptures then
      MaxCaptures := Length(AMoves[I].Captures);

  SetLength(Kept, 0);
  for I := 0 to High(AMoves) do
    if Length(AMoves[I].Captures) = MaxCaptures then
      AddMove(Kept, AMoves[I].Squares, AMoves[I].Captures, AMoves[I].Promotes);

  AMoves := Kept;
end;

procedure GenerateLegalMoves(const ABoard: TBoard; ASide: TSide; out AMoves: TMoveArray);
var
  Square: Integer;
begin
  SetLength(AMoves, 0);

  for Square := Low(ABoard) to High(ABoard) do
    if PieceBelongsToSide(ABoard[Square], ASide) then
      GenerateCapturesForPiece(ABoard, ASide, Square, AMoves);

  if Length(AMoves) > 0 then
  begin
    KeepOnlyLongestCaptures(AMoves);
    Exit;
  end;

  GenerateQuietMoves(ABoard, ASide, AMoves);
end;

function MoveToString(const AMove: TMove): String;
var
  I: Integer;
begin
  Result := '';
  if Length(AMove.Squares) = 0 then
    Exit;

  if Length(AMove.Captures) = 0 then
  begin
    if Length(AMove.Squares) >= 2 then
      Result := IntToStr(AMove.Squares[0]) + '-' +
        IntToStr(AMove.Squares[High(AMove.Squares)])
    else
      Result := IntToStr(AMove.Squares[0]);
  end
  else
  begin
    Result := IntToStr(AMove.Squares[0]) + 'x' +
      IntToStr(AMove.Squares[High(AMove.Squares)]);
    for I := 0 to High(AMove.Captures) do
      Result += 'x' + IntToStr(AMove.Captures[I]);
  end;

end;

function MoveToHubString(const AMove: TMove;
  ASingleCapturesIncludeCapturedSquare: Boolean): String;
var
  I: Integer;
begin
  Result := '';
  if Length(AMove.Squares) = 0 then
    Exit;

  if Length(AMove.Captures) = 0 then
    Exit(MoveToString(AMove));

  Result := IntToStr(AMove.Squares[0]) + 'x' +
    IntToStr(AMove.Squares[High(AMove.Squares)]);

  if (Length(AMove.Captures) = 1) and
    (not ASingleCapturesIncludeCapturedSquare) then
    Exit;

  for I := 0 to High(AMove.Captures) do
    Result += 'x' + IntToStr(AMove.Captures[I]);
end;

end.
