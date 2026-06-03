unit BoardUi;

{$mode objfpc}{$H+}

interface

uses
  DraughtsRules,
  StdCtrls,
  Types;

procedure HideBoardClockLabels(ATopLabel, ABottomLabel: TLabel);
procedure PositionBoardClockLabels(ATopLabel, ABottomLabel: TLabel;
  const ABoardRect: TRect; AOffsetX, AOffsetY: Integer);
function BoardSideToMoveMarkerRect(const ABoardRect: TRect; ACellSize,
  ASideMarkerGap, ASideMarkerWidth: Integer; ASideToMove: TSide;
  ABoardFlipped: Boolean; out APiece: TPiece): TRect;

implementation

uses
  Math;

const
  BoardClockHeight = 22;
  BoardClockGap = 2;

procedure HideBoardClockLabels(ATopLabel, ABottomLabel: TLabel);
begin
  if ATopLabel <> nil then
    ATopLabel.Visible := False;
  if ABottomLabel <> nil then
    ABottomLabel.Visible := False;
end;

procedure PositionBoardClockLabels(ATopLabel, ABottomLabel: TLabel;
  const ABoardRect: TRect; AOffsetX, AOffsetY: Integer);
var
  BottomRect: TRect;
  TopRect: TRect;
begin
  if (ATopLabel = nil) or (ABottomLabel = nil) then
    Exit;

  TopRect := Types.Rect(AOffsetX + ABoardRect.Left,
    Max(0, AOffsetY + ABoardRect.Top - BoardClockHeight - BoardClockGap),
    AOffsetX + ABoardRect.Right,
    Max(BoardClockHeight, AOffsetY + ABoardRect.Top - BoardClockGap));
  BottomRect := Types.Rect(AOffsetX + ABoardRect.Left,
    AOffsetY + ABoardRect.Bottom + BoardClockGap,
    AOffsetX + ABoardRect.Right,
    AOffsetY + ABoardRect.Bottom + BoardClockGap + BoardClockHeight);

  ATopLabel.BoundsRect := TopRect;
  ABottomLabel.BoundsRect := BottomRect;
  ATopLabel.Visible := True;
  ABottomLabel.Visible := True;
  ATopLabel.BringToFront;
  ABottomLabel.BringToFront;
end;

function BoardSideToMoveMarkerRect(const ABoardRect: TRect; ACellSize,
  ASideMarkerGap, ASideMarkerWidth: Integer; ASideToMove: TSide;
  ABoardFlipped: Boolean; out APiece: TPiece): TRect;
var
  MarkerAtBottom: Boolean;
  MarkerX: Integer;
  MarkerY: Integer;
begin
  MarkerX := ABoardRect.Right + ASideMarkerGap +
    ((ASideMarkerWidth - ACellSize) div 2);

  MarkerAtBottom := ((ASideToMove = sideWhite) and (not ABoardFlipped)) or
    ((ASideToMove = sideBlack) and ABoardFlipped);
  if ASideToMove = sideBlack then
    APiece := pcBlackMan
  else
    APiece := pcWhiteMan;

  if MarkerAtBottom then
    MarkerY := ABoardRect.Bottom - ACellSize
  else
    MarkerY := ABoardRect.Top;

  Result := Types.Rect(MarkerX, MarkerY, MarkerX + ACellSize,
    MarkerY + ACellSize);
end;

end.
