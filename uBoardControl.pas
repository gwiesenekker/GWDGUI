unit uBoardControl;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Graphics, Math, SysUtils,
  uDraughtsBoard;

type
  TIntArray = array of Integer;

  TDraughtsBoardControl = class(TCustomControl)
  private
    FBoard: TDraughtsBoard;
    FBoardDarkColor: TColor;
    FBoardFlipped: Boolean;
    FBoardLightColor: TColor;
    FGridColor: TColor;
    FHintSourceSquare: Integer;
    FHintSourceSquareColor: TColor;
    FLastMoveTargetSquare: Integer;
    FLastMoveTargetSquareColor: TColor;
    FPvSourceSquare: Integer;
    FPvSourceSquareColor: TColor;
    FShowCoordinates: Boolean;
    FShowSideToMoveMarker: Boolean;
    FTargetSquareColor: TColor;
    FTargetSquares: TIntArray;
    procedure SetBoard(AValue: TDraughtsBoard);
    procedure SetBoardDarkColor(AValue: TColor);
    procedure SetBoardFlipped(AValue: Boolean);
    procedure SetBoardLightColor(AValue: TColor);
    procedure SetGridColor(AValue: TColor);
    procedure SetHintSourceSquare(AValue: Integer);
    procedure SetHintSourceSquareColor(AValue: TColor);
    procedure SetLastMoveTargetSquare(AValue: Integer);
    procedure SetLastMoveTargetSquareColor(AValue: TColor);
    procedure SetPvSourceSquare(AValue: Integer);
    procedure SetPvSourceSquareColor(AValue: TColor);
    procedure SetShowCoordinates(AValue: Boolean);
    procedure SetShowSideToMoveMarker(AValue: Boolean);
    procedure SetTargetSquareColor(AValue: TColor);
    function BoardRect: TRect;
    function CellSize: Integer;
    function IsTargetSquare(ASquare: Integer): Boolean;
    function SideMarkerGap: Integer;
    function SideMarkerSize: Integer;
  protected
    procedure Paint; override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    function BoardSquareSize: Integer;
    function SquareAtPoint(X, Y: Integer): Integer;
    procedure ClearTargetSquares;
    procedure SetTargetSquares(const ASquares: array of Integer);
    property Board: TDraughtsBoard read FBoard write SetBoard;
    property BoardFlipped: Boolean read FBoardFlipped write SetBoardFlipped;
    property HintSourceSquare: Integer read FHintSourceSquare
      write SetHintSourceSquare;
    property HintSourceSquareColor: TColor read FHintSourceSquareColor
      write SetHintSourceSquareColor;
    property LastMoveTargetSquare: Integer read FLastMoveTargetSquare
      write SetLastMoveTargetSquare;
    property LastMoveTargetSquareColor: TColor read FLastMoveTargetSquareColor
      write SetLastMoveTargetSquareColor;
    property PvSourceSquare: Integer read FPvSourceSquare write SetPvSourceSquare;
    property PvSourceSquareColor: TColor read FPvSourceSquareColor
      write SetPvSourceSquareColor;
    property TargetSquareColor: TColor read FTargetSquareColor
      write SetTargetSquareColor;
  published
    property Align;
    property Anchors;
    property Color;
    property Constraints;
    property Enabled;
    property Font;
    property OnDblClick;
    property OnMouseDown;
    property ParentColor;
    property ParentFont;
    property PopupMenu;
    property BoardDarkColor: TColor read FBoardDarkColor write SetBoardDarkColor;
    property BoardLightColor: TColor read FBoardLightColor write SetBoardLightColor;
    property GridColor: TColor read FGridColor write SetGridColor;
    property ShowCoordinates: Boolean read FShowCoordinates write SetShowCoordinates default True;
    property ShowSideToMoveMarker: Boolean read FShowSideToMoveMarker
      write SetShowSideToMoveMarker default False;
    property TabStop;
    property Visible;
  end;

implementation

procedure ShrinkRect(var ARect: TRect; DX, DY: Integer);
begin
  Inc(ARect.Left, DX);
  Inc(ARect.Top, DY);
  Dec(ARect.Right, DX);
  Dec(ARect.Bottom, DY);
end;

procedure DrawSquareOutline(ACanvas: TCanvas; ARect: TRect; AColor: TColor;
  AWidth, AInset: Integer);
begin
  ShrinkRect(ARect, AInset, AInset);
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := AColor;
  ACanvas.Pen.Width := Max(1, AWidth);
  ACanvas.Rectangle(ARect);
  ACanvas.Pen.Width := 1;
  ACanvas.Brush.Style := bsSolid;
end;

constructor TDraughtsBoardControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque, csReplicatable];
  DoubleBuffered := True;
  Color := clBtnFace;
  Width := 560;
  Height := 560;
  FBoardDarkColor := RGBToColor(98, 73, 53);
  FBoardLightColor := RGBToColor(228, 207, 176);
  FGridColor := RGBToColor(58, 44, 34);
  FHintSourceSquareColor := clRed;
  FLastMoveTargetSquareColor := clYellow;
  FPvSourceSquareColor := RGBToColor(255, 165, 0);
  FTargetSquareColor := clLime;
  FShowCoordinates := True;
  FShowSideToMoveMarker := False;
end;

function TDraughtsBoardControl.BoardSquareSize: Integer;
begin
  Result := CellSize;
end;

procedure TDraughtsBoardControl.SetBoard(AValue: TDraughtsBoard);
begin
  if FBoard = AValue then
    Exit;
  FBoard := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetBoardDarkColor(AValue: TColor);
begin
  if FBoardDarkColor = AValue then
    Exit;
  FBoardDarkColor := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetBoardFlipped(AValue: Boolean);
begin
  if FBoardFlipped = AValue then
    Exit;
  FBoardFlipped := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetBoardLightColor(AValue: TColor);
begin
  if FBoardLightColor = AValue then
    Exit;
  FBoardLightColor := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetGridColor(AValue: TColor);
begin
  if FGridColor = AValue then
    Exit;
  FGridColor := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetHintSourceSquare(AValue: Integer);
begin
  if FHintSourceSquare = AValue then
    Exit;
  FHintSourceSquare := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetHintSourceSquareColor(AValue: TColor);
begin
  if FHintSourceSquareColor = AValue then
    Exit;
  FHintSourceSquareColor := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetLastMoveTargetSquare(AValue: Integer);
begin
  if FLastMoveTargetSquare = AValue then
    Exit;
  FLastMoveTargetSquare := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetLastMoveTargetSquareColor(AValue: TColor);
begin
  if FLastMoveTargetSquareColor = AValue then
    Exit;
  FLastMoveTargetSquareColor := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetPvSourceSquare(AValue: Integer);
begin
  if FPvSourceSquare = AValue then
    Exit;
  FPvSourceSquare := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetPvSourceSquareColor(AValue: TColor);
begin
  if FPvSourceSquareColor = AValue then
    Exit;
  FPvSourceSquareColor := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetShowCoordinates(AValue: Boolean);
begin
  if FShowCoordinates = AValue then
    Exit;
  FShowCoordinates := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetTargetSquareColor(AValue: TColor);
begin
  if FTargetSquareColor = AValue then
    Exit;
  FTargetSquareColor := AValue;
  Invalidate;
end;

procedure TDraughtsBoardControl.SetShowSideToMoveMarker(AValue: Boolean);
begin
  if FShowSideToMoveMarker = AValue then
    Exit;
  FShowSideToMoveMarker := AValue;
  Invalidate;
end;

function TDraughtsBoardControl.SquareAtPoint(X, Y: Integer): Integer;
var
  LBoardRect: TRect;
  LCell: Integer;
  LCol: Integer;
  LRow: Integer;
begin
  Result := 0;
  LCell := CellSize;
  if LCell <= 0 then
    Exit;
  LBoardRect := BoardRect;
  if (X < LBoardRect.Left) or (X >= LBoardRect.Right) or
    (Y < LBoardRect.Top) or (Y >= LBoardRect.Bottom) then
    Exit;
  LRow := (Y - LBoardRect.Top) div LCell;
  LCol := (X - LBoardRect.Left) div LCell;
  if FBoardFlipped then
  begin
    LRow := 9 - LRow;
    LCol := 9 - LCol;
  end;
  Result := RowColToSquare(LRow, LCol);
end;

procedure TDraughtsBoardControl.ClearTargetSquares;
begin
  if Length(FTargetSquares) = 0 then
    Exit;
  SetLength(FTargetSquares, 0);
  Invalidate;
end;

procedure TDraughtsBoardControl.SetTargetSquares(const ASquares: array of Integer);
var
  I: Integer;
begin
  SetLength(FTargetSquares, Length(ASquares));
  for I := 0 to High(ASquares) do
    FTargetSquares[I] := ASquares[I];
  Invalidate;
end;

function TDraughtsBoardControl.IsTargetSquare(ASquare: Integer): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(FTargetSquares) do
    if FTargetSquares[I] = ASquare then
      Exit(True);
  Result := False;
end;

function TDraughtsBoardControl.CellSize: Integer;
var
  LMarkerGutter: Integer;
  LUsableWidth: Integer;
begin
  LMarkerGutter := 0;
  if FShowSideToMoveMarker then
    LMarkerGutter := Max(22, Min(ClientWidth, ClientHeight) div 12);
  LUsableWidth := Max(1, ClientWidth - LMarkerGutter);
  Result := Max(1, Min(LUsableWidth, ClientHeight) div 10);
end;

function TDraughtsBoardControl.SideMarkerGap: Integer;
begin
  Result := Max(4, CellSize div 10);
end;

function TDraughtsBoardControl.SideMarkerSize: Integer;
begin
  Result := Max(10, CellSize div 2);
end;

function TDraughtsBoardControl.BoardRect: TRect;
var
  LGutter: Integer;
  LSize: Integer;
  LUsableWidth: Integer;
begin
  LGutter := 0;
  if FShowSideToMoveMarker then
    LGutter := SideMarkerSize + SideMarkerGap;
  LUsableWidth := Max(1, ClientWidth - LGutter);
  LSize := CellSize * 10;
  Result.Left := (LUsableWidth - LSize) div 2;
  Result.Top := (ClientHeight - LSize) div 2;
  Result.Right := Result.Left + LSize;
  Result.Bottom := Result.Top + LSize;
end;

procedure TDraughtsBoardControl.Paint;
var
  LBoardRect, LCellRect, LPieceRect: TRect;
  LCell, LCol, LLogicalCol, LLogicalRow, LRow, LSquare: Integer;
  LMarkerAtBottom: Boolean;
  LMarkerRect: TRect;
  LMarkerSize: Integer;
  LPiece: TDraughtsPieceKind;
  LText: string;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  LCell := CellSize;
  LBoardRect := BoardRect;

  for LRow := 0 to 9 do
    for LCol := 0 to 9 do
    begin
      LCellRect := Rect(
        LBoardRect.Left + LCol * LCell,
        LBoardRect.Top + LRow * LCell,
        LBoardRect.Left + (LCol + 1) * LCell,
        LBoardRect.Top + (LRow + 1) * LCell
      );

      if ((LRow + LCol) mod 2) = 0 then
        Canvas.Brush.Color := FBoardLightColor
      else
        Canvas.Brush.Color := FBoardDarkColor;
      Canvas.FillRect(LCellRect);

      Canvas.Pen.Color := FGridColor;
      Canvas.Rectangle(LCellRect);

      LLogicalRow := LRow;
      LLogicalCol := LCol;
      if FBoardFlipped then
      begin
        LLogicalRow := 9 - LRow;
        LLogicalCol := 9 - LCol;
      end;
      LSquare := RowColToSquare(LLogicalRow, LLogicalCol);
      if (LSquare > 0) and FShowCoordinates then
      begin
        Canvas.Brush.Style := bsClear;
        Canvas.Font.Color := clWhite;
        Canvas.Font.Size := Max(7, LCell div 7);
        LText := IntToStr(LSquare);
        Canvas.TextOut(LCellRect.Left + 4, LCellRect.Top + 3, LText);
        Canvas.Brush.Style := bsSolid;
      end;

      if (FBoard <> nil) and (LSquare > 0) then
      begin
        LPiece := FBoard[LSquare];
        if LPiece <> pkEmpty then
        begin
          LPieceRect := LCellRect;
          ShrinkRect(LPieceRect, Max(4, LCell div 8), Max(4, LCell div 8));

          if PieceColor(LPiece) = pcWhite then
          begin
            Canvas.Brush.Color := RGBToColor(245, 241, 229);
            Canvas.Pen.Color := RGBToColor(70, 70, 70);
          end
          else
          begin
            Canvas.Brush.Color := RGBToColor(36, 37, 40);
            Canvas.Pen.Color := RGBToColor(10, 10, 10);
          end;

          Canvas.Ellipse(LPieceRect);
          ShrinkRect(LPieceRect, Max(2, LCell div 12), Max(2, LCell div 12));
          Canvas.Brush.Style := bsClear;
          Canvas.Pen.Color := RGBToColor(150, 132, 104);
          Canvas.Ellipse(LPieceRect);

          if LPiece in [pkWhiteKing, pkBlackKing] then
          begin
            Canvas.Font.Style := [fsBold];
            Canvas.Font.Size := Max(10, LCell div 3);
            if PieceColor(LPiece) = pcWhite then
              Canvas.Font.Color := RGBToColor(50, 50, 50)
            else
              Canvas.Font.Color := RGBToColor(235, 230, 220);
            LText := 'K';
            Canvas.TextOut(
              LCellRect.Left + (LCell - Canvas.TextWidth(LText)) div 2,
              LCellRect.Top + (LCell - Canvas.TextHeight(LText)) div 2,
              LText
            );
            Canvas.Font.Style := [];
          end;
          Canvas.Brush.Style := bsSolid;
        end;
      end;

      if LSquare > 0 then
      begin
        if LSquare = FPvSourceSquare then
          DrawSquareOutline(Canvas, LCellRect, FPvSourceSquareColor,
            Max(3, LCell div 12), LCell div 10);
        if LSquare = FHintSourceSquare then
          DrawSquareOutline(Canvas, LCellRect, FHintSourceSquareColor,
            Max(3, LCell div 12), LCell div 7);
        if LSquare = FLastMoveTargetSquare then
          DrawSquareOutline(Canvas, LCellRect, FLastMoveTargetSquareColor,
            Max(3, LCell div 12), 2);
        if IsTargetSquare(LSquare) then
          DrawSquareOutline(Canvas, LCellRect, FTargetSquareColor,
            Max(3, LCell div 12), LCell div 5);
      end;
    end;

  if FShowSideToMoveMarker and (FBoard <> nil) then
  begin
    LMarkerSize := SideMarkerSize;
    LMarkerRect.Left := LBoardRect.Right + SideMarkerGap;
    LMarkerRect.Right := LMarkerRect.Left + LMarkerSize;
    LMarkerAtBottom := ((FBoard.SideToMove = dsWhite) and (not FBoardFlipped)) or
      ((FBoard.SideToMove = dsBlack) and FBoardFlipped);
    if LMarkerAtBottom then
    begin
      LMarkerRect.Top := LBoardRect.Bottom - LMarkerSize;
      LMarkerRect.Bottom := LBoardRect.Bottom;
    end
    else
    begin
      LMarkerRect.Top := LBoardRect.Top;
      LMarkerRect.Bottom := LBoardRect.Top + LMarkerSize;
    end;

    if FBoard.SideToMove = dsWhite then
    begin
      Canvas.Brush.Color := RGBToColor(245, 241, 229);
      Canvas.Pen.Color := RGBToColor(70, 70, 70);
    end
    else
    begin
      Canvas.Brush.Color := RGBToColor(36, 37, 40);
      Canvas.Pen.Color := RGBToColor(10, 10, 10);
    end;
    Canvas.Ellipse(LMarkerRect);
  end;
end;

procedure TDraughtsBoardControl.Resize;
begin
  inherited Resize;
  Invalidate;
end;

end.
