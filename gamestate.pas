unit GameState;

{$mode objfpc}{$H+}

interface

uses
  DraughtsRules;

procedure CopyMove(const ASource: TMove; out ADest: TMove);
procedure ApplyMoveToBoard(var ABoard: TBoard; var ASide: TSide;
  const AMove: TMove);
function MoveIsReversibleOnBoard(const ABoard: TBoard;
  const AMove: TMove): Boolean;
function PositionKeyFor(const ABoard: TBoard; ASide: TSide): String;

implementation

procedure ToggleSide(var ASide: TSide);
begin
  if ASide = sideWhite then
    ASide := sideBlack
  else
    ASide := sideWhite;
end;

procedure CopyMove(const ASource: TMove; out ADest: TMove);
var
  I: Integer;
begin
  SetLength(ADest.Squares, Length(ASource.Squares));
  SetLength(ADest.Captures, Length(ASource.Captures));
  for I := 0 to High(ASource.Squares) do
    ADest.Squares[I] := ASource.Squares[I];
  for I := 0 to High(ASource.Captures) do
    ADest.Captures[I] := ASource.Captures[I];
  ADest.Promotes := ASource.Promotes;
end;

procedure ApplyMoveToBoard(var ABoard: TBoard; var ASide: TSide;
  const AMove: TMove);
var
  CaptureIndex: Integer;
  FromSquare: Integer;
  Piece: TPiece;
  ToSquare: Integer;
begin
  if Length(AMove.Squares) < 2 then
    Exit;

  FromSquare := AMove.Squares[0];
  ToSquare := AMove.Squares[High(AMove.Squares)];
  Piece := ABoard[FromSquare];
  ABoard[FromSquare] := pcNone;
  for CaptureIndex := 0 to High(AMove.Captures) do
    ABoard[AMove.Captures[CaptureIndex]] := pcNone;
  if AMove.Promotes then
    case Piece of
      pcWhiteMan: Piece := pcWhiteKing;
      pcBlackMan: Piece := pcBlackKing;
    end;
  ABoard[ToSquare] := Piece;
  ToggleSide(ASide);
end;

function MoveIsReversibleOnBoard(const ABoard: TBoard;
  const AMove: TMove): Boolean;
var
  FromSquare: Integer;
begin
  Result := False;
  if Length(AMove.Squares) < 2 then
    Exit;

  FromSquare := AMove.Squares[0];
  Result := (Length(AMove.Captures) = 0) and (not AMove.Promotes) and
    (ABoard[FromSquare] in [pcWhiteKing, pcBlackKing]);
end;

function PositionKeyFor(const ABoard: TBoard; ASide: TSide): String;
var
  Square: Integer;
begin
  if ASide = sideWhite then
    Result := 'W|'
  else
    Result := 'B|';

  for Square := Low(ABoard) to High(ABoard) do
    case ABoard[Square] of
      pcWhiteMan: Result += 'w';
      pcWhiteKing: Result += 'W';
      pcBlackMan: Result += 'b';
      pcBlackKing: Result += 'B';
    else
      Result += 'e';
    end;
end;

end.
