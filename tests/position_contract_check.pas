program position_contract_check;

{$mode objfpc}{$H+}

{ Contract checks for uGamePosition implementations.

  Every game implementation must pass RunContract with its own fixtures. The
  checks use only the abstract TGamePosition/TGameVariant API, so they test the
  boundary that generic units rely on. Usage: position_contract_check [--print-perft] }

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, uGamePosition, uDraughtsPosition, uCounterGamePosition;

type
  TPerftFixture = record
    FEN: string;
    Counts: array of QWord; // Counts[0] = perft(1), ...
  end;
  TPerftFixtures = array of TPerftFixture;

var
  Failures: Integer = 0;
  Checks: Integer = 0;
  PrintPerft: Boolean = False;
  Variant: TGameVariant = nil; // the implementation under test

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  Inc(Checks);
  if not ACondition then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', AMessage);
  end;
end;

function Perft(APosition: TGamePosition; ADepth: Integer): QWord;
var
  I: Integer;
  LChild: TGamePosition;
begin
  if ADepth = 0 then
    Exit(1);
  if ADepth = 1 then
    Exit(APosition.LegalMoveCount);
  Result := 0;
  LChild := APosition.Clone;
  try
    for I := 0 to APosition.LegalMoveCount - 1 do
    begin
      LChild.AssignFrom(APosition);
      LChild.PlayTrustedMove(APosition.LegalMove(I));
      Inc(Result, Perft(LChild, ADepth - 1));
    end;
  finally
    LChild.Free;
  end;
end;

procedure CheckPerft(AVariant: TGameVariant; const AFixtures: TPerftFixtures);
var
  I, D: Integer;
  LPosition: TGamePosition;
  LCount: QWord;
begin
  for I := 0 to High(AFixtures) do
  begin
    LPosition := AVariant.CreatePositionFromFEN(AFixtures[I].FEN);
    try
      for D := 0 to High(AFixtures[I].Counts) do
      begin
        LCount := Perft(LPosition, D + 1);
        if PrintPerft then
          WriteLn('perft ', AFixtures[I].FEN, ' depth ', D + 1, ' = ', LCount);
        Check(LCount = AFixtures[I].Counts[D], Format('perft(%d) of %s: got %d, expected %d',
          [D + 1, AFixtures[I].FEN, LCount, AFixtures[I].Counts[D]]));
      end;
    finally
      LPosition.Free;
    end;
  end;
end;

{ Per-position checks on every legal move. }
procedure CheckMovesOf(APosition: TGamePosition; const AContext: string);
var
  I, J, LFrom, LTo: Integer;
  LMove, LNotation, LParsed: string;
  LNotations, LBetween: TStringList;
  LChild, LTrusted: TGamePosition;
  LKeyBefore: string;
  LTrustedSquare: Integer;
begin
  LNotations := TStringList.Create;
  LBetween := TStringList.Create;
  LChild := APosition.Clone;
  LTrusted := APosition.Clone;
  try
    LNotations.Sorted := True;
    LNotations.Duplicates := dupAccept;
    for I := 0 to APosition.LegalMoveCount - 1 do
    begin
      LMove := APosition.LegalMove(I);
      Check((LMove <> '') and (Pos(' ', LMove) = 0) and (Pos(#9, LMove) = 0),
        AContext + ': canonical move without whitespace: "' + LMove + '"');
      Check(APosition.IsLegal(LMove), AContext + ': legal move is IsLegal: ' + LMove);
      Check(APosition.SameMove(LMove, LMove), AContext + ': SameMove is reflexive: ' + LMove);
      Check(Variant.SameMove(LMove, LMove), AContext + ': variant SameMove is reflexive: ' + LMove);
      Check(Variant.NormalizeMove(LMove) = LMove,
        AContext + ': NormalizeMove keeps canonical move ' + LMove);
      Check(APosition.TryParseMove(LMove, LParsed) and APosition.SameMove(LParsed, LMove),
        AContext + ': canonical move parses to itself: ' + LMove);

      LNotation := APosition.MoveNotation(LMove);
      Check(LNotation <> '', AContext + ': notation for ' + LMove);
      Check(APosition.TryParseMove(LNotation, LParsed) and APosition.SameMove(LParsed, LMove),
        AContext + ': notation "' + LNotation + '" parses back to ' + LMove);
      LNotations.Add(LNotation);
      LTrusted.AssignFrom(APosition);
      Check(LTrusted.PlayMoveText(LNotation) = LMove,
        AContext + ': PlayMoveText of "' + LNotation + '" returns the canonical move ' + LMove);

      for J := 0 to APosition.LegalMoveCount - 1 do
        if J <> I then
        begin
          Check(not APosition.SameMove(LMove, APosition.LegalMove(J)),
            AContext + ': distinct legal moves are not SameMove: ' + LMove + ' / ' +
            APosition.LegalMove(J));
          Check(not Variant.SameMove(LMove, APosition.LegalMove(J)),
            AContext + ': variant SameMove separates distinct legal moves');
        end;

      APosition.MoveSquares(LMove, LFrom, LTo);
      Check((LFrom > 0) and (LTo > 0), AContext + ': squares for ' + LMove);
      Variant.MoveSquares(LMove, J, LTrustedSquare);
      Check(((J = 0) and (LTrustedSquare = 0)) or ((J = LFrom) and (LTrustedSquare = LTo)),
        AContext + ': variant squares are absent or agree with the position for ' + LMove);
      APosition.MovesBetween(LFrom, LTo, LBetween);
      Check(LBetween.IndexOf(LMove) >= 0, AContext + ': MovesBetween contains ' + LMove);
      for J := 0 to LBetween.Count - 1 do
        Check(APosition.IsLegal(LBetween[J]), AContext + ': MovesBetween returns legal moves');

      LChild.AssignFrom(APosition);
      LChild.PlayMove(LMove);
      LTrusted.AssignFrom(APosition);
      LTrusted.PlayTrustedMove(LMove);
      Check(LChild.PositionKey = LTrusted.PositionKey,
        AContext + ': trusted and validated play agree for ' + LMove);
      Check(LChild.SideToMove = OppositeGameSide(APosition.SideToMove),
        AContext + ': side to move alternates after ' + LMove);
      Check(LChild.LegalMoveCount = LTrusted.LegalMoveCount,
        AContext + ': deferred legal moves match after ' + LMove);
    end;
    for I := 1 to LNotations.Count - 1 do
      Check(LNotations[I] <> LNotations[I - 1],
        AContext + ': notation is unique among legal moves: ' + LNotations[I]);

    // An illegal move raises and leaves the position unchanged.
    LKeyBefore := APosition.PositionKey;
    LChild.AssignFrom(APosition);
    try
      LChild.PlayMove('0-0-illegal');
      Check(False, AContext + ': illegal move must raise');
    except
      on E: EGamePositionError do ;
    end;
    Check(LChild.PositionKey = LKeyBefore, AContext + ': illegal move leaves position unchanged');
    try
      LChild.PlayMoveText('0-0-illegal');
      Check(False, AContext + ': illegal move text must raise');
    except
      on E: EGamePositionError do
        Check(Pos('Illegal move', E.Message) > 0, AContext + ': illegal move message');
    end;
    Check(LChild.PositionKey = LKeyBefore, AContext + ': illegal move text leaves position unchanged');
  finally
    LTrusted.Free;
    LChild.Free;
    LBetween.Free;
    LNotations.Free;
  end;
end;

procedure CheckFen(AVariant: TGameVariant; const AFens, ABadFens: array of string);
var
  I: Integer;
  LPosition, LCopy: TGamePosition;
  LKey: string;
begin
  LPosition := AVariant.CreatePosition;
  LCopy := AVariant.CreatePosition;
  try
    Check(LPosition.ToFEN <> '', 'CreatePosition gives the default position');
    Check(AVariant.SideFromFEN(AVariant.DefaultStartingFEN) = LPosition.SideToMove,
      'SideFromFEN matches the default position');
    for I := Low(AFens) to High(AFens) do
    begin
      LPosition.LoadFromFEN(AFens[I]);
      Check(AVariant.SideFromFEN(AFens[I]) = LPosition.SideToMove, 'SideFromFEN: ' + AFens[I]);
      LCopy.LoadFromFEN(LPosition.ToFEN);
      Check(LCopy.PositionKey = LPosition.PositionKey, 'FEN round trip: ' + AFens[I]);
      Check(LCopy.ToFEN = LPosition.ToFEN, 'ToFEN is stable: ' + AFens[I]);
    end;
    for I := Low(ABadFens) to High(ABadFens) do
    begin
      LKey := LPosition.PositionKey;
      try
        LPosition.LoadFromFEN(ABadFens[I]);
        Check(False, 'invalid FEN must raise: "' + ABadFens[I] + '"');
      except
        on E: EConvertError do ;
      end;
      Check(LPosition.PositionKey = LKey, 'invalid FEN leaves position unchanged: "' +
        ABadFens[I] + '"');
    end;
  finally
    LCopy.Free;
    LPosition.Free;
  end;
end;

{ Walk random lines with the move checks at every position. }
procedure CheckRandomLines(AVariant: TGameVariant; const AFens: array of string;
  ALines, APlies: Integer);
var
  I, L, P: Integer;
  LPosition, LReplay: TGamePosition;
  LMoves: TStringList;
begin
  RandSeed := 20261027;
  LMoves := TStringList.Create;
  try
    for I := Low(AFens) to High(AFens) do
      for L := 1 to ALines do
      begin
        LPosition := AVariant.CreatePositionFromFEN(AFens[I]);
        LReplay := AVariant.CreatePositionFromFEN(AFens[I]);
        LMoves.Clear;
        try
          for P := 1 to APlies do
          begin
            if LPosition.LegalMoveCount = 0 then
              Break;
            CheckMovesOf(LPosition, Format('%s line %d ply %d', [AFens[I], L, P]));
            LMoves.Add(LPosition.LegalMove(Random(LPosition.LegalMoveCount)));
            LPosition.PlayMove(LMoves[LMoves.Count - 1]);
          end;
          // Replaying the stored canonical line reaches the same position.
          for P := 0 to LMoves.Count - 1 do
            LReplay.PlayTrustedMove(LMoves[P]);
          Check(LReplay.PositionKey = LPosition.PositionKey,
            'trusted replay of a random line: ' + AFens[I]);
          Check(LReplay.ToFEN = LPosition.ToFEN, 'trusted replay gives the same FEN');
        finally
          LReplay.Free;
          LPosition.Free;
        end;
      end;
  finally
    LMoves.Free;
  end;
end;

{ Move-text equivalence (D16/P26): every pair is checked in both directions
  on the variant and on a position. A plain string comparison fails the "same"
  pairs; a too-loose one fails the "different" pairs. }
procedure CheckSpellings(const AFEN: string; const ASame, ADifferent: array of string);
var
  I: Integer;
  LPosition: TGamePosition;
begin
  Check(not Odd(Length(ASame)) and not Odd(Length(ADifferent)), 'spelling fixtures come in pairs');
  LPosition := Variant.CreatePositionFromFEN(AFEN);
  try
    I := 0;
    while I < High(ASame) do
    begin
      Check(Variant.SameMove(ASame[I], ASame[I + 1]) and Variant.SameMove(ASame[I + 1], ASame[I]),
        'variant: ' + ASame[I] + ' and ' + ASame[I + 1] + ' are the same move');
      Check(LPosition.SameMove(ASame[I], ASame[I + 1]) and LPosition.SameMove(ASame[I + 1], ASame[I]),
        'position: ' + ASame[I] + ' and ' + ASame[I + 1] + ' are the same move');
      Check(Variant.SameMove(Variant.NormalizeMove(ASame[I]), ASame[I]) and
        Variant.SameMove(Variant.NormalizeMove(ASame[I + 1]), ASame[I + 1]),
        'variant: NormalizeMove keeps the move of ' + ASame[I] + ' / ' + ASame[I + 1]);
      Inc(I, 2);
    end;
    I := 0;
    while I < High(ADifferent) do
    begin
      Check(not Variant.SameMove(ADifferent[I], ADifferent[I + 1]) and
        not Variant.SameMove(ADifferent[I + 1], ADifferent[I]),
        'variant: ' + ADifferent[I] + ' and ' + ADifferent[I + 1] + ' are different moves');
      Check(not LPosition.SameMove(ADifferent[I], ADifferent[I + 1]) and
        not LPosition.SameMove(ADifferent[I + 1], ADifferent[I]),
        'position: ' + ADifferent[I] + ' and ' + ADifferent[I + 1] + ' are different moves');
      Inc(I, 2);
    end;
  finally
    LPosition.Free;
  end;
end;

procedure AddFixture(var AFixtures: TPerftFixtures; const AFEN: string;
  const ACounts: array of QWord);
var
  I, N: Integer;
begin
  N := Length(AFixtures);
  SetLength(AFixtures, N + 1);
  AFixtures[N].FEN := AFEN;
  SetLength(AFixtures[N].Counts, Length(ACounts));
  for I := 0 to High(ACounts) do
    AFixtures[N].Counts[I] := ACounts[I];
end;

procedure RunDraughts;
var
  LFixtures: TPerftFixtures;
  LPosition: TGamePosition;
begin
  Variant := DraughtsVariant;
  WriteLn('-- ', Variant.Name);
  Check(DefaultGameVariant = Variant, 'linking the draughts unit registers it as the default variant');
  Check(Variant.Name <> '', 'variant has a name');
  // International draughts perft from the initial position (published values).
  LFixtures := nil;
  AddFixture(LFixtures, Variant.DefaultStartingFEN, [9, 81, 658, 4265, 27117, 167140]);
  CheckPerft(Variant, LFixtures);
  CheckFen(Variant,
    [Variant.DefaultStartingFEN, 'B:W31-50:B1-20', 'W:WK21:B31,39,14,17,19',
     'B:WK26:B14', 'W:W38,45:B33,24,K6', 'W:WK32:B27,28'],
    ['', 'X:W31:B1', 'W:W51:B1', 'W:W31,31:B1', 'W:Wx:B1']);
  CheckSpellings('W:WK21:B31,39,14,17,19',
    ['30x10x24x14', '30x10x14x24', '32-28', ' 32-28 ', '21x26x17x19x39x31', '21x26x31x39x19x17'],
    ['30x10x24x14', '30x10x24x15', '32-28', '32-27', '21x26x17x19x39x31', '21x26x17x14x39x31']);
  // Same-target captures (U8), king captures, black to move, promotions.
  LPosition := Variant.CreatePositionFromFEN('W:WK21:B31,39,14,17,19');
  try CheckMovesOf(LPosition, 'same-target captures'); finally LPosition.Free; end;
  CheckRandomLines(Variant,
    [Variant.DefaultStartingFEN, 'B:W31-50:B1-20', 'W:WK32:B27,28,18,19,8,9',
     'W:W6,7,8,K45:B44,43,42,K1'], 8, 60);
end;

{ The counter test game proves that the contract checks are not tied to draughts. }
procedure RunCounter;
var
  LFixtures: TPerftFixtures;
  LVariant: TCounterVariant;
begin
  LVariant := TCounterVariant.Create;
  try
    Variant := LVariant;
    WriteLn('-- ', Variant.Name);
    Check(DefaultGameVariant <> Variant, 'a test game does not replace the registered default');
    LFixtures := nil;
    // Sequences of +1/+2 steps from 0 that stay within the limit 5.
    AddFixture(LFixtures, 'W:0', [2, 4, 7, 5, 1, 0]);
    AddFixture(LFixtures, 'B:3', [2, 1, 0]);
    CheckPerft(Variant, LFixtures);
    CheckFen(Variant, ['W:0', 'B:0', 'W:5', 'B:4'], ['', 'W', 'X:1', 'W:6', 'W:-1', 'W:x']);
    CheckSpellings('W:0', ['+1', 'p1', '+2', 'TWO', 'one', ' +1 '], ['+1', '+2', 'p1', 'p2', '+1', '+3']);
    CheckRandomLines(Variant, ['W:0', 'B:1'], 4, 10);
  finally
    Variant := nil;
    LVariant.Free;
  end;
end;

begin
  PrintPerft := ParamStr(1) = '--print-perft';
  RunDraughts;
  RunCounter;
  if Failures > 0 then
  begin
    WriteLn(Failures, ' of ', Checks, ' position contract checks failed');
    Halt(1);
  end;
  WriteLn('Position contract checks passed (', Checks, ' checks)');
end.
