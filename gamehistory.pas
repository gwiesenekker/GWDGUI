unit GameHistory;

{$mode objfpc}{$H+}

interface

uses
  DraughtsRules,
  GameClock,
  HubProtocol;

type
  TGameHistory = class
  public
    BaseBoard: TBoard;
    BaseSide: TSide;
    ClockSnapshots: TClockSnapshotArray;
    CurrentPly: Integer;
    MoveAnnotations: TTextArray;
    MoveLengths: TIntegerArray;
    Moves: TMoveArray;
    MoveStarts: TIntegerArray;
    procedure ResetFromPosition(const ABoard: TBoard; ASide: TSide);
    procedure TruncateToCurrentPly;
    function AddMove(const AMove: TMove; const AAnnotation: String;
      const AClockSnapshot: TClockSnapshot): Integer;
    function BuildPdnMoveText(const AResult: String;
      AStoreRanges: Boolean): String;
    function ClockAnnotation(APly: Integer): String;
    function ConsecutiveReversiblePlyCount: Integer;
    procedure HubRootForMoveList(ASendStartingPosition: Boolean;
      out ARootBoard: TBoard; out ARootSide: TSide; out AMoveStart: Integer);
    function PlyAtTextOffset(AOffset: Integer): Integer;
    procedure PositionAtPly(APly: Integer; out ABoard: TBoard;
      out ASide: TSide; out ALastMoveTargetSquare: Integer);
    function RepetitionCountForPosition(const ABoard: TBoard;
      ASide: TSide): Integer;
  end;

implementation

uses
  GameState,
  Math,
  Notation,
  SysUtils;

procedure TGameHistory.ResetFromPosition(const ABoard: TBoard; ASide: TSide);
begin
  BaseBoard := ABoard;
  BaseSide := ASide;
  CurrentPly := 0;
  SetLength(Moves, 0);
  SetLength(MoveAnnotations, 0);
  SetLength(ClockSnapshots, 0);
  SetLength(MoveStarts, 0);
  SetLength(MoveLengths, 0);
end;

procedure TGameHistory.TruncateToCurrentPly;
begin
  if CurrentPly < Length(Moves) then
  begin
    SetLength(Moves, CurrentPly);
    SetLength(MoveAnnotations, CurrentPly);
    SetLength(ClockSnapshots, CurrentPly);
  end;
end;

function TGameHistory.AddMove(const AMove: TMove; const AAnnotation: String;
  const AClockSnapshot: TClockSnapshot): Integer;
var
  Annotation: String;
begin
  TruncateToCurrentPly;

  SetLength(Moves, Length(Moves) + 1);
  SetLength(MoveAnnotations, Length(Moves));
  SetLength(ClockSnapshots, Length(Moves));
  CopyMove(AMove, Moves[High(Moves)]);
  Result := High(Moves);

  Annotation := AAnnotation;
  if AMove.Promotes then
  begin
    if Annotation <> '' then
      Annotation += ' ';
    Annotation += 'K';
  end;
  MoveAnnotations[Result] := Annotation;
  ClockSnapshots[Result] := AClockSnapshot;
  CurrentPly := Length(Moves);
end;

function TGameHistory.ClockAnnotation(APly: Integer): String;
begin
  Result := '';
  if (APly <= 0) or (APly > Length(ClockSnapshots)) or
    (not ClockSnapshots[APly - 1].HasClock) then
    Exit;

  Result := 'clock=[' +
    FormatClockAnnotationSeconds(ClockSnapshots[APly - 1].WhiteSeconds) +
    ', ' +
    FormatClockAnnotationSeconds(ClockSnapshots[APly - 1].BlackSeconds) +
    ']';
end;

function TGameHistory.ConsecutiveReversiblePlyCount: Integer;
var
  Board: TBoard;
  I: Integer;
  Reversible: Boolean;
  Side: TSide;
begin
  Result := 0;
  Board := BaseBoard;
  Side := BaseSide;

  for I := 0 to Min(CurrentPly, Length(Moves)) - 1 do
  begin
    Reversible := MoveIsReversibleOnBoard(Board, Moves[I]);
    ApplyMoveToBoard(Board, Side, Moves[I]);
    if Reversible then
      Inc(Result)
    else
      Result := 0;
  end;
end;

procedure TGameHistory.HubRootForMoveList(ASendStartingPosition: Boolean;
  out ARootBoard: TBoard; out ARootSide: TSide; out AMoveStart: Integer);
var
  Board: TBoard;
  I: Integer;
  Reversible: Boolean;
  Side: TSide;
begin
  Board := BaseBoard;
  Side := BaseSide;
  ARootBoard := Board;
  ARootSide := Side;
  AMoveStart := 0;

  if ASendStartingPosition then
    Exit;

  for I := 0 to Min(CurrentPly, Length(Moves)) - 1 do
  begin
    Reversible := MoveIsReversibleOnBoard(Board, Moves[I]);
    ApplyMoveToBoard(Board, Side, Moves[I]);
    if not Reversible then
    begin
      AMoveStart := I + 1;
      ARootBoard := Board;
      ARootSide := Side;
    end;
  end;
end;

function TGameHistory.BuildPdnMoveText(const AResult: String;
  AStoreRanges: Boolean): String;
var
  Annotation: String;
  Clocks: String;
  I: Integer;
  MoveNumber: Integer;
  MoveText: String;

  procedure AppendText(const AText: String);
  begin
    Result += AText;
  end;

  procedure AppendMove(APly: Integer; const APrefix, AMoveText: String);
  begin
    AppendText(APrefix);
    if AStoreRanges then
    begin
      MoveStarts[APly] := Length(Result);
      MoveLengths[APly] := Length(AMoveText);
    end;
    AppendText(AMoveText);
    if (APly > 0) and (APly <= Length(MoveAnnotations)) then
    begin
      Annotation := MoveAnnotations[APly - 1];
      Clocks := ClockAnnotation(APly);
      if Clocks <> '' then
      begin
        if Annotation <> '' then
          Annotation += ' ';
        Annotation += Clocks;
      end;
      if Annotation <> '' then
        AppendText(' {' + Annotation + '}');
    end;
    AppendText(' ');
  end;

begin
  Result := '';
  if AStoreRanges then
  begin
    SetLength(MoveStarts, Length(Moves) + 1);
    SetLength(MoveLengths, Length(Moves) + 1);
  end;

  for I := 0 to High(Moves) do
  begin
    MoveText := MoveToString(Moves[I]);
    if BaseSide = sideWhite then
    begin
      MoveNumber := (I div 2) + 1;
      if not Odd(I) then
        AppendMove(I + 1, Format('%d. ', [MoveNumber]), MoveText)
      else
        AppendMove(I + 1, '', MoveText);
    end
    else
    begin
      if I = 0 then
        AppendMove(I + 1, '1... ', MoveText)
      else if Odd(I) then
      begin
        MoveNumber := (I div 2) + 2;
        AppendMove(I + 1, Format('%d. ', [MoveNumber]), MoveText);
      end
      else
        AppendMove(I + 1, '', MoveText);
    end;
  end;

  AppendText(AResult);
  Result := Trim(Result);
end;

function TGameHistory.PlyAtTextOffset(AOffset: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to High(MoveStarts) do
    if (MoveLengths[I] > 0) and (AOffset >= MoveStarts[I]) and
      (AOffset <= MoveStarts[I] + MoveLengths[I]) then
      Exit(I);
end;

procedure TGameHistory.PositionAtPly(APly: Integer; out ABoard: TBoard;
  out ASide: TSide; out ALastMoveTargetSquare: Integer);
var
  I: Integer;
begin
  if APly < 0 then
    APly := 0;
  if APly > Length(Moves) then
    APly := Length(Moves);

  ABoard := BaseBoard;
  ASide := BaseSide;
  ALastMoveTargetSquare := 0;
  for I := 0 to APly - 1 do
  begin
    ApplyMoveToBoard(ABoard, ASide, Moves[I]);
    if Length(Moves[I].Squares) > 0 then
      ALastMoveTargetSquare := Moves[I].Squares[High(Moves[I].Squares)];
  end;
end;

function TGameHistory.RepetitionCountForPosition(const ABoard: TBoard;
  ASide: TSide): Integer;
var
  Board: TBoard;
  I: Integer;
  Key: String;
  Side: TSide;
  TargetKey: String;
begin
  Result := 0;
  TargetKey := PositionKeyFor(ABoard, ASide);
  Board := BaseBoard;
  Side := BaseSide;
  Key := PositionKeyFor(Board, Side);
  if Key = TargetKey then
    Inc(Result);

  for I := 0 to Min(CurrentPly, Length(Moves)) - 1 do
  begin
    ApplyMoveToBoard(Board, Side, Moves[I]);
    Key := PositionKeyFor(Board, Side);
    if Key = TargetKey then
      Inc(Result);
  end;
end;

end.
