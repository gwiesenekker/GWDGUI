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
  Classes, SysUtils, uGamePosition, uDraughtsPosition;

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

procedure RunDraughts;
var
  LFixtures: TPerftFixtures;
  LVariant: TGameVariant;
  LPosition: TGamePosition;

  procedure AddFixture(const AFEN: string; const ACounts: array of QWord);
  var
    I, N: Integer;
  begin
    N := Length(LFixtures);
    SetLength(LFixtures, N + 1);
    LFixtures[N].FEN := AFEN;
    SetLength(LFixtures[N].Counts, Length(ACounts));
    for I := 0 to High(ACounts) do
      LFixtures[N].Counts[I] := ACounts[I];
  end;

begin
  LVariant := DraughtsVariant;
  Variant := LVariant;
  Check(DefaultGameVariant = LVariant, 'linking the draughts unit registers it as the default variant');
  Check(LVariant.Name <> '', 'variant has a name');
  // International draughts perft from the initial position (published values).
  AddFixture(LVariant.DefaultStartingFEN, [9, 81, 658, 4265, 27117, 167140]);
  CheckPerft(LVariant, LFixtures);
  CheckFen(LVariant,
    [LVariant.DefaultStartingFEN, 'B:W31-50:B1-20', 'W:WK21:B31,39,14,17,19',
     'B:WK26:B14', 'W:W38,45:B33,24,K6', 'W:WK32:B27,28'],
    ['', 'X:W31:B1', 'W:W51:B1', 'W:W31,31:B1', 'W:Wx:B1']);
  // Same-target captures (U8), king captures, black to move, promotions.
  LPosition := LVariant.CreatePositionFromFEN('W:WK21:B31,39,14,17,19');
  try CheckMovesOf(LPosition, 'same-target captures'); finally LPosition.Free; end;
  CheckRandomLines(LVariant,
    [LVariant.DefaultStartingFEN, 'B:W31-50:B1-20', 'W:WK32:B27,28,18,19,8,9',
     'W:W6,7,8,K45:B44,43,42,K1'], 8, 60);
end;

begin
  PrintPerft := ParamStr(1) = '--print-perft';
  RunDraughts;
  if Failures > 0 then
  begin
    WriteLn(Failures, ' of ', Checks, ' position contract checks failed');
    Halt(1);
  end;
  WriteLn('Position contract checks passed (', Checks, ' checks)');
end.
