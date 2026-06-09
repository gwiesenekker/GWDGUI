program board_regression_check;

{$mode objfpc}{$H+}

uses
  SysUtils,
  uDraughtsBoard,
  uDxpProtocol;

const
  ReplayMoves: array[0..13] of string = (
    '34-30',
    '20-25',
    '32-28',
    '25x34x30',
    '39x30x34',
    '17-22',
    '28x17x22',
    '12x21x17',
    '37-32',
    '19-23',
    '44-39',
    '14-19',
    '31-26',
    '07-12'
  );

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

procedure CheckMoveNormalization;
begin
  CheckEqual(NormalizeMoveNotation('07-12'), '7-12',
    'quiet move notation is canonicalized');
  CheckEqual(NormalizeMoveNotation('025x034x030'), '25x34x30',
    'capture move notation is canonicalized');
end;

procedure CheckDxpMoveConversion;
var
  MoveText: string;
begin
  CheckEqual(DxpBuildMovePacket('07-12', 0), 'M0000071200',
    'DXP quiet move packet uses two-digit squares');
  Check(DxpMoveMessageToText('M0000071200', MoveText),
    'DXP quiet move packet parses');
  CheckEqual(MoveText, '7-12', 'DXP quiet move text is canonicalized');

  CheckEqual(DxpBuildMovePacket('025x034x030', 0), 'M000025340130',
    'DXP capture move packet uses captured-square list');
  Check(DxpMoveMessageToText('M000025340130', MoveText),
    'DXP capture move packet parses');
  CheckEqual(MoveText, '25x34x30', 'DXP capture move text is canonicalized');
end;

procedure CheckReplayAcceptsZeroPaddedMove;
var
  Board: TDraughtsBoard;
  I: Integer;
begin
  Board := TDraughtsBoard.Create;
  try
    Board.LoadFromFEN('W:W31-50:B1-20');
    for I := Low(ReplayMoves) to High(ReplayMoves) do
    begin
      Check(Board.IsLegalMove(ReplayMoves[I]), 'move should be legal at ply ' +
        IntToStr(I + 1) + ': ' + ReplayMoves[I]);
      Board.PlayMove(ReplayMoves[I], False);
    end;
    Check(Board.IsLegalMove('26x17x21'),
      'expected forced capture after zero-padded 07-12 replay');
  finally
    Board.Free;
  end;
end;

procedure CheckCapturedPiecesCanBeInAnyOrder;
var
  Board: TDraughtsBoard;
  LegalMove: string;
begin
  Board := TDraughtsBoard.Create;
  try
    Board.LoadFromFEN('W:WK30:B14,24');
    Check(Board.IsLegalMove('30x10x24x14'),
      'generated capture order should be legal');
    Check(Board.IsLegalMove('30x10x14x24'),
      'captured pieces may be listed in any order');
    Check(Board.TryGetLegalMove('30x10x14x24', LegalMove),
      'unordered captured-piece move should resolve to a generated legal move');
    CheckEqual(LegalMove, '30x10x24x14',
      'unordered captured-piece move resolves to canonical generated notation');
    Board.PlayMove('30x10x14x24', False);
    Check(Board[10] = pkWhiteKing,
      'order-insensitive capture should land the king on the target square');
    Check((Board[14] = pkEmpty) and (Board[24] = pkEmpty),
      'order-insensitive capture should remove all captured pieces');
  finally
    Board.Free;
  end;
end;

procedure CheckCurrentFenRoundTrip;
var
  Board: TDraughtsBoard;
  Fen: string;
  RoundTripBoard: TDraughtsBoard;
begin
  Board := TDraughtsBoard.Create;
  RoundTripBoard := TDraughtsBoard.Create;
  try
    Board.LoadFromFEN('B:W31,K32:B1,K2');
    Fen := Board.CurrentFEN;
    RoundTripBoard.LoadFromFEN(Fen);
    CheckEqual(RoundTripBoard.PositionKey, Board.PositionKey,
      'exported current FEN should load back to the same position');
  finally
    RoundTripBoard.Free;
    Board.Free;
  end;
end;

begin
  CheckMoveNormalization;
  CheckDxpMoveConversion;
  CheckReplayAcceptsZeroPaddedMove;
  CheckCapturedPiecesCanBeInAnyOrder;
  CheckCurrentFenRoundTrip;
  Writeln('OK');
end.
