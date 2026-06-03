unit EvalBarUi;

{$mode objfpc}{$H+}

interface

uses
  Graphics,
  Types;

function EvalBarRectForBoard(const ABoardRect: TRect; AGap, AWidth: Integer): TRect;
function EvalBarWhitePixels(const ABarRect: TRect; AScore, AMaxScore: Double): Integer;
procedure DrawEvalBar(ACanvas: TCanvas; const ABarRect: TRect; AScore,
  AMaxScore: Double; ABoardFlipped: Boolean; out AWhitePixels: Integer);
procedure RepaintEvalBarDelta(ACanvas: TCanvas; const ABarRect: TRect;
  AOldScore, ANewScore, AMaxScore: Double; ABoardFlipped: Boolean;
  out ANewWhitePixels: Integer);

implementation

uses
  Math;

function EvalBarRectForBoard(const ABoardRect: TRect; AGap, AWidth: Integer): TRect;
begin
  Result := Types.Rect(ABoardRect.Left - AGap - AWidth, ABoardRect.Top,
    ABoardRect.Left - AGap, ABoardRect.Bottom);
end;

function EvalBarWhitePixels(const ABarRect: TRect; AScore, AMaxScore: Double): Integer;
var
  ClampedScore: Double;
begin
  if AMaxScore <= 0 then
    AMaxScore := 1;
  ClampedScore := Max(-AMaxScore, Min(AMaxScore, AScore));
  Result := Round(((ClampedScore + AMaxScore) / (2.0 * AMaxScore)) *
    (ABarRect.Bottom - ABarRect.Top));
end;

procedure DrawEvalBar(ACanvas: TCanvas; const ABarRect: TRect; AScore,
  AMaxScore: Double; ABoardFlipped: Boolean; out AWhitePixels: Integer);
var
  FillRect: TRect;
  WhiteRect: TRect;
begin
  AWhitePixels := 0;
  if (ABarRect.Right <= ABarRect.Left) or
    (ABarRect.Bottom <= ABarRect.Top) then
    Exit;

  FillRect := ABarRect;
  InflateRect(FillRect, -1, -1);
  AWhitePixels := EvalBarWhitePixels(FillRect, AScore, AMaxScore);

  ACanvas.Brush.Color := clBlack;
  ACanvas.FillRect(FillRect);
  ACanvas.Brush.Color := clWhite;
  if ABoardFlipped then
    WhiteRect := Types.Rect(FillRect.Left, FillRect.Top, FillRect.Right,
      FillRect.Top + AWhitePixels)
  else
    WhiteRect := Types.Rect(FillRect.Left, FillRect.Bottom - AWhitePixels,
      FillRect.Right, FillRect.Bottom);
  ACanvas.FillRect(WhiteRect);

  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := clGray;
  ACanvas.Pen.Width := 1;
  ACanvas.Rectangle(ABarRect);
  ACanvas.Brush.Style := bsSolid;
end;

procedure RepaintEvalBarDelta(ACanvas: TCanvas; const ABarRect: TRect;
  AOldScore, ANewScore, AMaxScore: Double; ABoardFlipped: Boolean;
  out ANewWhitePixels: Integer);
var
  BlackRect: TRect;
  BarRect: TRect;
  OldPixels: Integer;
  WhiteRect: TRect;
begin
  ANewWhitePixels := -1;
  BarRect := ABarRect;
  InflateRect(BarRect, -1, -1);
  if (BarRect.Right <= BarRect.Left) or (BarRect.Bottom <= BarRect.Top) then
    Exit;

  OldPixels := EvalBarWhitePixels(BarRect, AOldScore, AMaxScore);
  ANewWhitePixels := EvalBarWhitePixels(BarRect, ANewScore, AMaxScore);
  if ANewWhitePixels = OldPixels then
    Exit;

  if ANewWhitePixels > OldPixels then
  begin
    ACanvas.Brush.Color := clWhite;
    if ABoardFlipped then
      WhiteRect := Types.Rect(BarRect.Left, BarRect.Top + OldPixels,
        BarRect.Right, BarRect.Top + ANewWhitePixels)
    else
      WhiteRect := Types.Rect(BarRect.Left, BarRect.Bottom - ANewWhitePixels,
        BarRect.Right, BarRect.Bottom - OldPixels);
    ACanvas.FillRect(WhiteRect);
  end
  else
  begin
    ACanvas.Brush.Color := clBlack;
    if ABoardFlipped then
      BlackRect := Types.Rect(BarRect.Left, BarRect.Top + ANewWhitePixels,
        BarRect.Right, BarRect.Top + OldPixels)
    else
      BlackRect := Types.Rect(BarRect.Left, BarRect.Bottom - OldPixels,
        BarRect.Right, BarRect.Bottom - ANewWhitePixels);
    ACanvas.FillRect(BlackRect);
  end;
end;

end.
