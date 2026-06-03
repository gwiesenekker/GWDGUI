unit ScoreHistoryUi;

{$mode objfpc}{$H+}

interface

uses
  Graphics,
  Types;

type
  TScoreForPlyEvent = function(APly: Integer; out AScore: Double): Boolean of object;

procedure DrawScoreHistoryGraph(ACanvas: TCanvas; const AClient: TRect;
  AMoveCount, ACurrentPly: Integer; AMaxScore: Double;
  AScoreForPly: TScoreForPlyEvent);

implementation

uses
  Math;

procedure DrawScoreHistoryGraph(ACanvas: TCanvas; const AClient: TRect;
  AMoveCount, ACurrentPly: Integer; AMaxScore: Double;
  AScoreForPly: TScoreForPlyEvent);
var
  BarHalfWidth: Integer;
  BarRect: TRect;
  Bitmap: Graphics.TBitmap;
  ChartRect: TRect;
  EvalCanvas: TCanvas;
  I: Integer;
  MidY: Integer;
  PlotLeft: Integer;
  PlotRight: Integer;
  Score: Double;
  X: Integer;
  Y: Integer;
begin
  Bitmap := Graphics.TBitmap.Create;
  try
    Bitmap.SetSize(AClient.Right - AClient.Left, AClient.Bottom - AClient.Top);
    EvalCanvas := Bitmap.Canvas;
    EvalCanvas.Brush.Color := clWhite;
    EvalCanvas.FillRect(Types.Rect(0, 0, Bitmap.Width, Bitmap.Height));

    if (Bitmap.Width < 32) or (Bitmap.Height < 24) then
    begin
      ACanvas.Draw(AClient.Left, AClient.Top, Bitmap);
      Exit;
    end;

    if AMaxScore <= 0 then
      AMaxScore := 1;

    ChartRect := Types.Rect(8, 8, Bitmap.Width - 8, Bitmap.Height - 8);
    MidY := (ChartRect.Top + ChartRect.Bottom) div 2;

    EvalCanvas.Pen.Color := clSilver;
    EvalCanvas.Pen.Width := 1;
    EvalCanvas.Rectangle(ChartRect);
    EvalCanvas.Line(ChartRect.Left, MidY, ChartRect.Right, MidY);

    if AMoveCount <= 0 then
    begin
      ACanvas.Draw(AClient.Left, AClient.Top, Bitmap);
      Exit;
    end;

    BarHalfWidth := Max(1, ((ChartRect.Right - ChartRect.Left) div
      Max(AMoveCount, 1)) div 3);
    PlotLeft := ChartRect.Left + BarHalfWidth + 1;
    PlotRight := ChartRect.Right - BarHalfWidth - 1;

    for I := 1 to AMoveCount do
    begin
      if AMoveCount = 1 then
        X := (PlotLeft + PlotRight) div 2
      else
        X := PlotLeft + Round(((I - 1) / (AMoveCount - 1)) *
          (PlotRight - PlotLeft));

      if Assigned(AScoreForPly) and AScoreForPly(I, Score) then
      begin
        Score := Max(-AMaxScore, Min(AMaxScore, Score));
        Y := MidY - Round((Score / AMaxScore) *
          ((ChartRect.Bottom - ChartRect.Top) / 2));

        if Score >= 0.0 then
        begin
          EvalCanvas.Brush.Color := clGreen;
          EvalCanvas.Pen.Color := clGreen;
          BarRect := Types.Rect(X - BarHalfWidth, Y, X + BarHalfWidth + 1,
            MidY);
        end
        else
        begin
          EvalCanvas.Brush.Color := clRed;
          EvalCanvas.Pen.Color := clRed;
          BarRect := Types.Rect(X - BarHalfWidth, MidY,
            X + BarHalfWidth + 1, Y);
        end;
        if BarRect.Bottom = BarRect.Top then
        begin
          Dec(BarRect.Top);
          Inc(BarRect.Bottom);
        end;
        EvalCanvas.Rectangle(BarRect);
      end
      else
      begin
        EvalCanvas.Brush.Color := clBlue;
        EvalCanvas.Pen.Color := clBlue;
        BarRect := Types.Rect(X - BarHalfWidth, MidY,
          X + BarHalfWidth + 1, MidY);
        Dec(BarRect.Top);
        Inc(BarRect.Bottom);
        EvalCanvas.Rectangle(BarRect);
      end;
    end;

    if (ACurrentPly > 0) and (ACurrentPly < AMoveCount) and
      (AMoveCount > 1) then
    begin
      X := PlotLeft + Round(((ACurrentPly - 1) / (AMoveCount - 1)) *
        (PlotRight - PlotLeft));
      EvalCanvas.Pen.Color := clGray;
      EvalCanvas.Pen.Width := 1;
      EvalCanvas.Line(X, ChartRect.Top, X, ChartRect.Bottom);
    end;

    ACanvas.Draw(AClient.Left, AClient.Top, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

end.
