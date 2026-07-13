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

procedure CheckInitialHumanMoveIsLegal;
var
  Board: TDraughtsBoard;
begin
  Board := TDraughtsBoard.Create;
  try
    Board.LoadFromFEN('W:W31-50:B1-20');
    Check(Board.IsLegalMove('33-28'),
      'expected 33-28 to be legal from the initial position');
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
    Check(Board.IsLegalMove('30x10'),
      'capture alias may omit the captured-square list');
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

procedure CheckSingleCaptureMayOmitCapturedSquare;
var
  Board: TDraughtsBoard;
  LegalMove: string;
begin
  Board := TDraughtsBoard.Create;
  try
    Board.LoadFromFEN('W:W28:B23');
    Check(Board.IsLegalMove('28x19'),
      'single-capture PDN may omit the captured square');
    Check(Board.TryGetLegalMove('28x19', LegalMove),
      'short single-capture move should resolve to generated legal move');
    CheckEqual(LegalMove, '28x19x23',
      'short single-capture move resolves to captured-square notation');
    Board.PlayMove('28x19', False);
    Check((Board[19] = pkWhiteMan) and (Board[23] = pkEmpty),
      'short single-capture move should land and remove the captured piece');
  finally
    Board.Free;
  end;
end;

procedure CheckKingCaptureKeepsCapturedPiecesAsBlockers;
var
  Board: TDraughtsBoard;
  LegalMove: string;
begin
  Board := TDraughtsBoard.Create;
  try
    Board.LoadFromFEN('B:W11,26,27,34,38,39:B15:BK45');
    Check(Board.TryGetLegalMove('45x49', LegalMove),
      'king capture alias should resolve to canonical capture');
    CheckEqual(LegalMove, '45x49x34x11x27x38',
      'king capture should keep captured pieces as blockers while generating');
    Check(not Board.IsLegalMove('45x34'),
      'king should not be allowed to land on a captured piece');
    Board.PlayMove('45x49', False);
    Check(Board[49] = pkBlackKing,
      'king capture alias should land on final square');
    Check((Board[34] = pkEmpty) and (Board[11] = pkEmpty) and
      (Board[27] = pkEmpty) and (Board[38] = pkEmpty),
      'king capture should remove captured pieces when played');
  finally
    Board.Free;
  end;
end;

procedure CheckEquivalentAliasMatchesAreNotAmbiguous;
var
  Board: TDraughtsBoard;
  LegalMove: string;
begin
  Board := TDraughtsBoard.Create;
  try
    Board.LoadFromFEN('B:W17,23,27,28,32,35,37,38:B16,31');
    Check(Board.LegalMoveCount = 2,
      'equivalent generated captures should be deduplicated');
    Check(Board.TryGetLegalMove('31x31', LegalMove),
      'equivalent generated capture aliases should not be ambiguous');
    CheckEqual(LegalMove, '31x31x27x28x38x37',
      '31x31 should resolve to first equivalent canonical capture');
    Board.PlayMove('31x31', False);
    Check(Board[31] = pkBlackMan,
      '31x31 alias should land on square 31');
    Check((Board[27] = pkEmpty) and (Board[28] = pkEmpty) and
      (Board[38] = pkEmpty) and (Board[37] = pkEmpty),
      '31x31 alias should remove the equivalent captured set');
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
  CheckInitialHumanMoveIsLegal;
  CheckReplayAcceptsZeroPaddedMove;
  CheckCapturedPiecesCanBeInAnyOrder;
  CheckSingleCaptureMayOmitCapturedSquare;
  CheckKingCaptureKeepsCapturedPiecesAsBlockers;
  CheckEquivalentAliasMatchesAreNotAmbiguous;
  CheckCurrentFenRoundTrip;
  Writeln('OK');
end.
