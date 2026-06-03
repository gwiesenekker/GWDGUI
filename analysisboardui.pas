unit AnalysisBoardUi;

{$mode objfpc}{$H+}

interface

uses
  DraughtsRules,
  Graphics,
  Types;

procedure DrawAnalysisMiniBoard(ACanvas: TCanvas; const AClient: TRect;
  const ABoard: TBoard; AHasBoard, ABoardFlipped: Boolean;
  ABackgroundColor, AWoodSquareColor: TColor);

implementation

uses
  BoardGeometry,
  Math;

procedure DrawAnalysisMiniBoard(ACanvas: TCanvas; const AClient: TRect;
  const ABoard: TBoard; AHasBoard, ABoardFlipped: Boolean;
  ABackgroundColor, AWoodSquareColor: TColor);
var
  Bitmap: Graphics.TBitmap;
  BoardPixels: Integer;
  BoardRect: TRect;
  CellSize: Integer;
  Col: Integer;
  MiniCanvas: TCanvas;
  PiecePosition: Integer;
  Row: Integer;
  SquareColor: TColor;
  SquareRect: TRect;
  X0: Integer;
  Y0: Integer;

  procedure DrawMiniPiece(const ASquare: TRect; APiece: TPiece);
  var
    MarkY: Integer;
    PieceRect: TRect;
  begin
    if APiece = pcNone then
      Exit;

    PieceRect := ASquare;
    InflateRect(PieceRect, -Max(1, CellSize div 5), -Max(1, CellSize div 5));
    if (PieceRect.Right <= PieceRect.Left) or
      (PieceRect.Bottom <= PieceRect.Top) then
      Exit;

    if APiece in [pcWhiteMan, pcWhiteKing] then
    begin
      MiniCanvas.Brush.Color := clWhite;
      MiniCanvas.Pen.Color := clBlack;
    end
    else
    begin
      MiniCanvas.Brush.Color := clBlack;
      MiniCanvas.Pen.Color := clWhite;
    end;
    MiniCanvas.Pen.Width := 1;
    MiniCanvas.Ellipse(PieceRect);

    if APiece in [pcWhiteKing, pcBlackKing] then
    begin
      MarkY := (PieceRect.Top + PieceRect.Bottom) div 2;
      if APiece = pcWhiteKing then
        MiniCanvas.Pen.Color := clBlack
      else
        MiniCanvas.Pen.Color := clWhite;
      MiniCanvas.Line(PieceRect.Left + 2, MarkY, PieceRect.Right - 2, MarkY);
    end;
  end;

begin
  Bitmap := Graphics.TBitmap.Create;
  try
    Bitmap.SetSize(AClient.Right - AClient.Left, AClient.Bottom - AClient.Top);
    MiniCanvas := Bitmap.Canvas;
    MiniCanvas.Brush.Color := ABackgroundColor;
    MiniCanvas.FillRect(Types.Rect(0, 0, Bitmap.Width, Bitmap.Height));

    BoardPixels := Min(Bitmap.Width, Bitmap.Height);
    BoardPixels := SnapBoardPixels(BoardPixels);
    if BoardPixels < BoardGeometrySize then
    begin
      ACanvas.Draw(AClient.Left, AClient.Top, Bitmap);
      Exit;
    end;

    CellSize := BoardPixels div BoardGeometrySize;
    X0 := (Bitmap.Width - BoardPixels) div 2;
    Y0 := (Bitmap.Height - BoardPixels) div 2;
    BoardRect := Types.Rect(X0, Y0, X0 + BoardPixels, Y0 + BoardPixels);

    for Row := 0 to BoardGeometrySize - 1 do
      for Col := 0 to BoardGeometrySize - 1 do
      begin
        if Odd(Row + Col) then
          SquareColor := AWoodSquareColor
        else
          SquareColor := clWhite;

        SquareRect := BoardCellRect(BoardRect, Row, Col);
        MiniCanvas.Brush.Color := SquareColor;
        MiniCanvas.FillRect(SquareRect);

        if Odd(Row + Col) and AHasBoard then
        begin
          PiecePosition := BoardSquareAtCell(Row, Col, ABoardFlipped);
          DrawMiniPiece(SquareRect, ABoard[PiecePosition]);
        end;
      end;

    MiniCanvas.Brush.Style := bsClear;
    MiniCanvas.Pen.Color := clBlack;
    MiniCanvas.Pen.Width := 1;
    MiniCanvas.Rectangle(BoardRect);
    MiniCanvas.Brush.Style := bsSolid;

    ACanvas.Draw(AClient.Left, AClient.Top, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

end.
