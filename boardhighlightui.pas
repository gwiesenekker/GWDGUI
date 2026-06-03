unit BoardHighlightUi;

{$mode objfpc}{$H+}

interface

uses
  Graphics,
  Types;

procedure DrawSquareOutline(ACanvas: TCanvas; const ASquareRect: TRect;
  AColor: TColor; APenWidth, AInset: Integer);
procedure DrawTargetCircle(ACanvas: TCanvas; const ASquareRect: TRect;
  AColor: TColor; APenWidth, AInset: Integer);

implementation

procedure BeginClearBrush(ACanvas: TCanvas; AColor: TColor; APenWidth: Integer);
begin
  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := AColor;
  ACanvas.Pen.Width := APenWidth;
end;

procedure EndClearBrush(ACanvas: TCanvas);
begin
  ACanvas.Brush.Style := bsSolid;
end;

procedure DrawSquareOutline(ACanvas: TCanvas; const ASquareRect: TRect;
  AColor: TColor; APenWidth, AInset: Integer);
begin
  BeginClearBrush(ACanvas, AColor, APenWidth);
  ACanvas.Rectangle(ASquareRect.Left + AInset, ASquareRect.Top + AInset,
    ASquareRect.Right - AInset, ASquareRect.Bottom - AInset);
  EndClearBrush(ACanvas);
end;

procedure DrawTargetCircle(ACanvas: TCanvas; const ASquareRect: TRect;
  AColor: TColor; APenWidth, AInset: Integer);
begin
  BeginClearBrush(ACanvas, AColor, APenWidth);
  ACanvas.Ellipse(ASquareRect.Left + AInset, ASquareRect.Top + AInset,
    ASquareRect.Right - AInset, ASquareRect.Bottom - AInset);
  EndClearBrush(ACanvas);
end;

end.
