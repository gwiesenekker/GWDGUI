unit uScoreHistoryControl;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Forms, Graphics, LMessages, SysUtils, Types, uDraughtsBoard,
  uPdn, uPreferences;

type
  TScoreHistoryDisplayMode = (shdmAuto, shdmGraph, shdmBars);

  TScoreHistoryControl = class(TCustomControl)
  private
    FAnnotationsText: string;
    FCurrentPly: Integer;
    FDisplayMode: TScoreHistoryDisplayMode;
    FHintText: string;
    FMaxScore: Double;
    FPlyCount: Integer;
    FScale: TScoreScale;
    FShowEvaluationBar: Boolean;
    FStartingSide: TDraughtsSide;
    function BarPenWidth(APlotWidth, ACount: Integer): Integer;
    function ChartBounds(out APlotLeft, APlotRight: Integer): Boolean;
    function LayoutBounds(out ABarRect, AChartRect: TRect;
      out ADrawEvaluationBar: Boolean): Boolean;
    procedure DrawDenseMissingScoreMark(AX, AMidY, AHalfHeight: Integer;
      AColor: TColor);
    procedure DrawMissingScoreRect(ALeft, AMidY, AHalfHeight, AWidth: Integer;
      AColor: TColor);
    procedure DrawScoreRect(ALeft, AMidY, AY, AWidth: Integer;
      AColor: TColor);
    function MappedScore(AScore: Double): Double;
    function ScoreY(AScore: Double; AMidY, AHalfHeight: Integer): Integer;
    function WhitePerspectiveScoreText(AScore: Double): string;
    function MoveCount: Integer;
    function PlyLabel(APly: Integer): string;
    function PlyAtX(AX: Integer; out APly: Integer): Boolean;
    procedure ClearScoreHint;
    procedure SetAnnotationsText(const AValue: string);
    procedure SetCurrentPly(AValue: Integer);
    procedure SetDisplayMode(AValue: TScoreHistoryDisplayMode);
    procedure SetMaxScore(AValue: Double);
    procedure SetPlyCount(AValue: Integer);
    procedure SetScale(AValue: TScoreScale);
    procedure SetShowEvaluationBar(AValue: Boolean);
    procedure SetStartingSide(AValue: TDraughtsSide);
    function ScoreHintForPly(APly: Integer): string;
    procedure SetScoreHint(const AText: string; AX, AY: Integer);
    function TryAnnotationScoreTextInLines(ALines: TStrings; APly: Integer;
      const AName: string; out AScoreText: string): Boolean;
    function TryAnnotationScoreInLines(ALines: TStrings; APly: Integer;
      const AName: string; out AScore: Double): Boolean;
    function TryScoreInLines(ALines: TStrings; APly: Integer;
      out AScore: Double): Boolean;
    function TryVisibleAnnotatorScoreInLines(ALines: TStrings;
      out AScore: Double): Boolean;
    function TryVisibleScoreInLines(ALines: TStrings;
      out AScore: Double): Boolean;
  protected
    procedure CMMouseLeave(var Message: TLMessage); message CM_MOUSELEAVE;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure Paint; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property AnnotationsText: string read FAnnotationsText
      write SetAnnotationsText;
    property CurrentPly: Integer read FCurrentPly write SetCurrentPly;
    property DisplayMode: TScoreHistoryDisplayMode read FDisplayMode
      write SetDisplayMode;
    property MaxScore: Double read FMaxScore write SetMaxScore;
    property PlyCount: Integer read FPlyCount write SetPlyCount;
    property Scale: TScoreScale read FScale write SetScale;
    property ShowEvaluationBar: Boolean read FShowEvaluationBar
      write SetShowEvaluationBar;
    property StartingSide: TDraughtsSide read FStartingSide
      write SetStartingSide;
  published
    property Align;
    property Anchors;
    property Color;
    property Constraints;
    property Font;
    property ParentColor;
    property ParentFont;
    property Visible;
    property ShowHint;
  end;

function TryExtractScoreFromAnnotation(const AAnnotation: string;
  out AScore: Double): Boolean;

implementation

uses
  Math;

function TryExtractScoreFromAnnotation(const AAnnotation: string;
  out AScore: Double): Boolean;
var
  Code: Integer;
  FS: TFormatSettings;
  I: Integer;
  LowerText: string;
  ScoreText: string;
  StartPos: Integer;
begin
  Result := False;
  AScore := 0.0;
  LowerText := LowerCase(AAnnotation);
  StartPos := Pos('score=', LowerText);
  if StartPos <= 0 then
    Exit;
  Inc(StartPos, Length('score='));
  ScoreText := '';
  for I := StartPos to Length(AAnnotation) do
  begin
    if AAnnotation[I] in ['0'..'9', '+', '-', '.', ','] then
      ScoreText += AAnnotation[I]
    else
      Break;
  end;
  ScoreText := StringReplace(Trim(ScoreText), ',', '.', []);
  if ScoreText = '' then
    Exit;

  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Val(ScoreText, AScore, Code);
  if Code = 0 then
    Exit(True);
  Result := TryStrToFloat(ScoreText, AScore, FS);
end;

constructor TScoreHistoryControl.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  DoubleBuffered := True;
  Color := clWindow;
  Hint := 'Score history';
  ShowHint := True;
  Height := 84;
  FCurrentPly := -1;
  FDisplayMode := shdmAuto;
  FMaxScore := 10.0;
  FPlyCount := 0;
  FScale := ssLogarithmic;
  FShowEvaluationBar := True;
  FStartingSide := dsWhite;
end;

destructor TScoreHistoryControl.Destroy;
begin
  ClearScoreHint;
  inherited Destroy;
end;

function TScoreHistoryControl.BarPenWidth(APlotWidth, ACount: Integer): Integer;
var
  Spacing: Double;
begin
  Result := 1;
  if ACount <= 0 then
    Exit;
  Spacing := APlotWidth / ACount;
  Result := Max(1, Round(Spacing * 0.35));
  Result := Min(12, Result);
end;

function TScoreHistoryControl.ChartBounds(out APlotLeft,
  APlotRight: Integer): Boolean;
var
  BarRect: TRect;
  ChartRect: TRect;
  DrawEvaluationBar: Boolean;
begin
  Result := False;
  APlotLeft := 0;
  APlotRight := 0;
  if not LayoutBounds(BarRect, ChartRect, DrawEvaluationBar) then
    Exit;

  APlotLeft := ChartRect.Left + 3;
  APlotRight := ChartRect.Right - 3;
  Result := APlotRight >= APlotLeft;
end;

function TScoreHistoryControl.LayoutBounds(out ABarRect, AChartRect: TRect;
  out ADrawEvaluationBar: Boolean): Boolean;
begin
  Result := False;
  ADrawEvaluationBar := False;
  ABarRect := Types.Rect(0, 0, 0, 0);
  AChartRect := Types.Rect(0, 0, 0, 0);
  if (Width < 40) or (Height < 34) then
    Exit;

  if FShowEvaluationBar then
  begin
    ABarRect := Types.Rect(8, 6, 30, Height - 6);
    AChartRect := Types.Rect(42, 6, Width - 8, Height - 6);
    ADrawEvaluationBar := AChartRect.Right > AChartRect.Left + 12;
  end;

  if not ADrawEvaluationBar then
  begin
    ABarRect := Types.Rect(0, 0, 0, 0);
    AChartRect := Types.Rect(8, 6, Width - 8, Height - 6);
  end;

  Result := AChartRect.Right > AChartRect.Left + 12;
end;

procedure TScoreHistoryControl.CMMouseLeave(var Message: TLMessage);
begin
  inherited;
  ClearScoreHint;
end;

procedure TScoreHistoryControl.DrawDenseMissingScoreMark(AX, AMidY,
  AHalfHeight: Integer; AColor: TColor);
var
  Distance: Integer;
begin
  Distance := Max(1, Min(3, AHalfHeight div 12));
  Canvas.Pen.Color := AColor;
  Canvas.Line(AX, AMidY - Distance, AX, AMidY + Distance + 1);
end;

procedure TScoreHistoryControl.DrawMissingScoreRect(ALeft, AMidY, AHalfHeight,
  AWidth: Integer; AColor: TColor);
var
  Distance: Integer;
begin
  if AWidth < 1 then
    AWidth := 1;
  Distance := Max(1, AHalfHeight div 30);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := AColor;
  Canvas.Pen.Style := psClear;
  Canvas.Rectangle(ALeft, AMidY - Distance, ALeft + AWidth, AMidY + Distance + 1);
  Canvas.Pen.Style := psSolid;
end;

procedure TScoreHistoryControl.DrawScoreRect(ALeft, AMidY, AY, AWidth: Integer;
  AColor: TColor);
var
  LTop: Integer;
  LBottom: Integer;
begin
  if AWidth < 1 then
    AWidth := 1;
  LTop := Min(AMidY, AY);
  LBottom := Max(AMidY, AY);
  if LBottom = LTop then
    Inc(LBottom);
  Canvas.Brush.Style := bsSolid;
  Canvas.Brush.Color := AColor;
  Canvas.Pen.Style := psClear;
  Canvas.Rectangle(ALeft, LTop, ALeft + AWidth, LBottom + 1);
  Canvas.Pen.Style := psSolid;
end;

function TScoreHistoryControl.MappedScore(AScore: Double): Double;
var
  Limit: Double;
begin
  Limit := Max(0.001, FMaxScore);
  AScore := Max(-Limit, Min(Limit, AScore));
  if FScale = ssLogarithmic then
  begin
    { log1p-style mapping: 0 stays 0, while small scores get more space. }
    Result := Ln(1.0 + Abs(AScore)) / Ln(1.0 + Limit);
    if AScore < 0.0 then
      Result := -Result;
  end
  else
    Result := AScore / Limit;
end;

function TScoreHistoryControl.ScoreY(AScore: Double; AMidY,
  AHalfHeight: Integer): Integer;
var
  Distance: Integer;
begin
  Distance := Abs(Round(MappedScore(AScore) * AHalfHeight));
  if Distance < Max(2, AHalfHeight div 12) then
    Distance := Max(2, AHalfHeight div 12);
  if AScore >= 0.0 then
    Result := AMidY - Distance
  else
    Result := AMidY + Distance;
end;

function TScoreHistoryControl.WhitePerspectiveScoreText(
  AScore: Double): string;
begin
  if AScore > 0.0 then
    Result := '+' + FormatFloat('0.###', AScore)
  else
    Result := FormatFloat('0.###', AScore);
end;

function TScoreHistoryControl.MoveCount: Integer;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := FAnnotationsText;
    Result := Max(FPlyCount, Lines.Count);
  finally
    Lines.Free;
  end;
end;

function TScoreHistoryControl.PlyLabel(APly: Integer): string;
var
  LMoveNumber: Integer;
  LPlyFromWhiteStart: Integer;
  LSide: TDraughtsSide;
begin
  LPlyFromWhiteStart := APly;
  if FStartingSide = dsBlack then
    Inc(LPlyFromWhiteStart);
  LMoveNumber := ((LPlyFromWhiteStart - 1) div 2) + 1;
  if ((FStartingSide = dsWhite) and Odd(APly)) or
    ((FStartingSide = dsBlack) and (not Odd(APly))) then
    LSide := dsWhite
  else
    LSide := dsBlack;

  if LSide = dsWhite then
    Result := 'Move ' + IntToStr(LMoveNumber) + ' White'
  else
    Result := 'Move ' + IntToStr(LMoveNumber) + ' Black';
end;

procedure TScoreHistoryControl.ClearScoreHint;
begin
  FHintText := '';
  Hint := 'Score history';
  Application.CancelHint;
end;

procedure TScoreHistoryControl.MouseMove(Shift: TShiftState; X, Y: Integer);
var
  NewHint: string;
  Ply: Integer;
begin
  inherited MouseMove(Shift, X, Y);
  if PlyAtX(X, Ply) then
  begin
    NewHint := ScoreHintForPly(Ply)
  end
  else
  begin
    ClearScoreHint;
    Exit;
  end;
  SetScoreHint(NewHint, X, Y);
end;

function TScoreHistoryControl.PlyAtX(AX: Integer; out APly: Integer): Boolean;
var
  Count: Integer;
  PlotLeft: Integer;
  PlotRight: Integer;
  Ratio: Double;
begin
  Result := False;
  APly := 0;
  Count := MoveCount;
  if Count <= 0 then
    Exit;
  if not ChartBounds(PlotLeft, PlotRight) then
    Exit;
  if (AX < PlotLeft) or (AX > PlotRight) then
    Exit;

  if Count = 1 then
    APly := 1
  else
  begin
    Ratio := (AX - PlotLeft) / Max(1, PlotRight - PlotLeft);
    APly := 1 + Round(Ratio * (Count - 1));
    APly := Max(1, Min(Count, APly));
  end;
  Result := True;
end;

procedure TScoreHistoryControl.Paint;
var
  BarRect: TRect;
  BarScore: Double;
  InnerBarRect: TRect;
  MappedBarScore: Double;
  ChartRect: TRect;
  Count: Integer;
  DenseMode: Boolean;
  DrawEvaluationBar: Boolean;
  DrawnDenseScore: Boolean;
  HasAnnotatorScore: Boolean;
  HasEngineScore: Boolean;
  HasVisibleScore: Boolean;
  HalfHeight: Integer;
  I: Integer;
  MidY: Integer;
  PlotLeft: Integer;
  PlotRight: Integer;
  AnnotatorScore: Double;
  BarWidth: Integer;
  EngineColor: TColor;
  EngineY: Integer;
  LeftX: Integer;
  LColor: TColor;
  Lines: TStringList;
  PrevAnnotatorHasScore: Boolean;
  PrevAnnotatorX: Integer;
  PrevAnnotatorY: Integer;
  PrevEngineHasScore: Boolean;
  PrevEngineX: Integer;
  PrevEngineY: Integer;
  Score: Double;
  SplitY: Integer;
  X: Integer;
  Y: Integer;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  Lines := TStringList.Create;
  try
    Lines.Text := FAnnotationsText;

    if not LayoutBounds(BarRect, ChartRect, DrawEvaluationBar) then
      Exit;

    Canvas.Pen.Color := clSilver;
    Canvas.Brush.Style := bsClear;
    if DrawEvaluationBar then
      Canvas.Rectangle(BarRect);
    Canvas.Rectangle(ChartRect);
    MidY := (ChartRect.Top + ChartRect.Bottom) div 2;
    HalfHeight := (ChartRect.Bottom - ChartRect.Top) div 2;
    Canvas.Line(ChartRect.Left, MidY, ChartRect.Right, MidY);

    HasVisibleScore := TryVisibleScoreInLines(Lines, BarScore);
    if not HasVisibleScore then
      HasVisibleScore := TryVisibleAnnotatorScoreInLines(Lines, BarScore);
    if not HasVisibleScore then
      BarScore := 0.0;
    if DrawEvaluationBar then
    begin
      InnerBarRect := Types.Rect(BarRect.Left + 1, BarRect.Top + 1,
        BarRect.Right, BarRect.Bottom);
      MappedBarScore := MappedScore(BarScore);
      SplitY := InnerBarRect.Top + Round((InnerBarRect.Bottom -
        InnerBarRect.Top) * (0.5 - MappedBarScore / 2.0));
      SplitY := Max(InnerBarRect.Top, Min(InnerBarRect.Bottom, SplitY));
      Canvas.Pen.Style := psClear;
      Canvas.Brush.Style := bsSolid;
      Canvas.Brush.Color := clBlack;
      Canvas.Rectangle(InnerBarRect.Left, InnerBarRect.Top,
        InnerBarRect.Right, SplitY);
      Canvas.Brush.Color := clWhite;
      Canvas.Rectangle(InnerBarRect.Left, SplitY, InnerBarRect.Right,
        InnerBarRect.Bottom);
      Canvas.Pen.Style := psSolid;
    end;

    Count := Max(FPlyCount, Lines.Count);
    if Count <= 0 then
      Exit;

    PlotLeft := ChartRect.Left + 3;
    PlotRight := ChartRect.Right - 3;
    BarWidth := BarPenWidth(PlotRight - PlotLeft + 1, Count);
    case FDisplayMode of
      shdmGraph:
        DenseMode := True;
      shdmBars:
        DenseMode := False;
    else
      DenseMode := (Count > 8) and (Count * 2 > PlotRight - PlotLeft + 1);
    end;
    PrevEngineHasScore := False;
    PrevEngineX := 0;
    PrevEngineY := 0;
    PrevAnnotatorHasScore := False;
    PrevAnnotatorX := 0;
    PrevAnnotatorY := 0;
    for I := 1 to Count do
    begin
      if Count = 1 then
        X := (PlotLeft + PlotRight) div 2
      else
        X := PlotLeft + Round(((I - 1) / (Count - 1)) *
          (PlotRight - PlotLeft));

      HasEngineScore := TryScoreInLines(Lines, I, Score);
      HasAnnotatorScore := TryAnnotationScoreInLines(Lines, I, 'annotator',
        AnnotatorScore);
      LeftX := X - BarWidth;
      if LeftX < PlotLeft then
        LeftX := PlotLeft
      else if LeftX + BarWidth * 2 > PlotRight then
        LeftX := PlotRight - BarWidth * 2;
      if HasEngineScore then
      begin
        EngineY := ScoreY(Score, MidY, HalfHeight);
        if Score >= 0.0 then
          EngineColor := RGBToColor(54, 150, 79)
        else
          EngineColor := RGBToColor(190, 64, 64);
      end
      else if HasAnnotatorScore then
        EngineY := ScoreY(AnnotatorScore, MidY, HalfHeight)
      else
        EngineY := ScoreY(0.0, MidY, HalfHeight);

      if HasAnnotatorScore then
      begin
        Y := ScoreY(AnnotatorScore, MidY, HalfHeight);
        if AnnotatorScore >= 0.0 then
          LColor := RGBToColor(140, 210, 155)
        else
          LColor := RGBToColor(230, 145, 145);
      end
      else if HasEngineScore then
        Y := EngineY
      else
        Y := ScoreY(0.0, MidY, HalfHeight);

      if DenseMode then
      begin
        DrawnDenseScore := False;
        if HasEngineScore then
        begin
          Canvas.Pen.Color := EngineColor;
          if PrevEngineHasScore then
            Canvas.Line(PrevEngineX, PrevEngineY, X, EngineY)
          else
            Canvas.Line(X, MidY, X, EngineY);
          PrevEngineX := X;
          PrevEngineY := EngineY;
          PrevEngineHasScore := True;
          DrawnDenseScore := True;
        end;
        if HasAnnotatorScore then
        begin
          Canvas.Pen.Color := LColor;
          if PrevAnnotatorHasScore then
            Canvas.Line(PrevAnnotatorX, PrevAnnotatorY, X, Y)
          else
            Canvas.Line(X, MidY, X, Y);
          PrevAnnotatorX := X;
          PrevAnnotatorY := Y;
          PrevAnnotatorHasScore := True;
          DrawnDenseScore := True;
        end;
        if not DrawnDenseScore then
          DrawDenseMissingScoreMark(X, MidY, HalfHeight,
            RGBToColor(145, 165, 188));
      end
      else
      begin
        if HasEngineScore then
          DrawScoreRect(LeftX, MidY, EngineY, BarWidth, EngineColor)
        else
          DrawMissingScoreRect(LeftX, MidY, HalfHeight, BarWidth,
            RGBToColor(28, 74, 132));

        if HasAnnotatorScore then
          DrawScoreRect(LeftX + BarWidth, MidY, Y, BarWidth, LColor)
        else
          DrawMissingScoreRect(LeftX + BarWidth, MidY, HalfHeight, BarWidth,
            RGBToColor(102, 169, 220));
      end;
    end;

    if (FCurrentPly > 0) and (FCurrentPly <= Count) and (Count > 1) then
    begin
      X := PlotLeft + Round(((FCurrentPly - 1) / (Count - 1)) *
        (PlotRight - PlotLeft));
      Canvas.Pen.Color := clGray;
      Canvas.Line(X, ChartRect.Top, X, ChartRect.Bottom);
    end;
  finally
    Lines.Free;
  end;

end;

procedure TScoreHistoryControl.SetAnnotationsText(const AValue: string);
begin
  if FAnnotationsText = AValue then
    Exit;
  ClearScoreHint;
  FAnnotationsText := AValue;
  Invalidate;
end;

procedure TScoreHistoryControl.SetCurrentPly(AValue: Integer);
begin
  if FCurrentPly = AValue then
    Exit;
  ClearScoreHint;
  FCurrentPly := AValue;
  Invalidate;
end;

procedure TScoreHistoryControl.SetDisplayMode(
  AValue: TScoreHistoryDisplayMode);
begin
  if FDisplayMode = AValue then
    Exit;
  ClearScoreHint;
  FDisplayMode := AValue;
  Invalidate;
end;

procedure TScoreHistoryControl.SetMaxScore(AValue: Double);
begin
  if AValue <= 0.0 then
    AValue := 10.0;
  if Abs(FMaxScore - AValue) < 0.000001 then
    Exit;
  ClearScoreHint;
  FMaxScore := AValue;
  Invalidate;
end;

procedure TScoreHistoryControl.SetPlyCount(AValue: Integer);
begin
  if AValue < 0 then
    AValue := 0;
  if FPlyCount = AValue then
    Exit;
  ClearScoreHint;
  FPlyCount := AValue;
  Invalidate;
end;

procedure TScoreHistoryControl.SetScale(AValue: TScoreScale);
begin
  if FScale = AValue then
    Exit;
  ClearScoreHint;
  FScale := AValue;
  Invalidate;
end;

procedure TScoreHistoryControl.SetShowEvaluationBar(AValue: Boolean);
begin
  if FShowEvaluationBar = AValue then
    Exit;
  ClearScoreHint;
  FShowEvaluationBar := AValue;
  Invalidate;
end;

procedure TScoreHistoryControl.SetStartingSide(AValue: TDraughtsSide);
begin
  if FStartingSide = AValue then
    Exit;
  ClearScoreHint;
  FStartingSide := AValue;
  Invalidate;
end;

function TScoreHistoryControl.ScoreHintForPly(APly: Integer): string;
var
  AnnotatorScore: Double;
  EngineScore: Double;
  HasAnnotatorScore: Boolean;
  HasEngineScore: Boolean;
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := FAnnotationsText;
    HasEngineScore := TryAnnotationScoreInLines(Lines, APly, 'engine',
      EngineScore);
    HasAnnotatorScore := TryAnnotationScoreInLines(Lines, APly,
      'annotator', AnnotatorScore);
  finally
    Lines.Free;
  end;

  Result := PlyLabel(APly) + ': ';
  if (not HasEngineScore) and (not HasAnnotatorScore) then
  begin
    Result += 'no score';
    Exit;
  end;

  if HasEngineScore then
    Result += 'E: ' + WhitePerspectiveScoreText(EngineScore)
  else
    Result += 'E: no score';
  Result += '; ';
  if HasAnnotatorScore then
    Result += 'A: ' + WhitePerspectiveScoreText(AnnotatorScore)
  else
    Result += 'A: no score';
end;

procedure TScoreHistoryControl.SetScoreHint(const AText: string; AX,
  AY: Integer);
begin
  if Trim(AText) = '' then
  begin
    ClearScoreHint;
    Exit;
  end;
  if FHintText = AText then
    Exit;
  FHintText := AText;
  Hint := AText;
  Application.CancelHint;
  Application.ActivateHint(ClientToScreen(Point(AX, AY)), True);
end;

function TScoreHistoryControl.TryAnnotationScoreTextInLines(ALines: TStrings;
  APly: Integer; const AName: string; out AScoreText: string): Boolean;
var
  Score: Double;
begin
  Result := False;
  AScoreText := '';
  if (ALines = nil) or (APly <= 0) or (APly > ALines.Count) then
    Exit;

  AScoreText := ExtractAnnotationValue(ALines[APly - 1], AName);
  if (AScoreText = '') and SameText(AName, 'engine') then
    AScoreText := ExtractAnnotationValue(ALines[APly - 1], 'score');
  if (AScoreText = '') and SameText(AName, 'engine') and
    TryExtractScoreFromAnnotation('score=' + Trim(ALines[APly - 1]), Score) then
  begin
    AScoreText := Trim(ALines[APly - 1]);
    Exit(True);
  end;
  if AScoreText = '' then
    Exit;
  Result := TryExtractScoreFromAnnotation('score=' + AScoreText, Score);
  if not Result then
    AScoreText := '';
end;

function TScoreHistoryControl.TryAnnotationScoreInLines(ALines: TStrings;
  APly: Integer; const AName: string; out AScore: Double): Boolean;
var
  ScoreText: string;
begin
  Result := False;
  AScore := 0.0;
  if TryAnnotationScoreTextInLines(ALines, APly, AName, ScoreText) then
    Result := TryExtractScoreFromAnnotation('score=' + ScoreText, AScore);
end;

function TScoreHistoryControl.TryScoreInLines(ALines: TStrings; APly: Integer;
  out AScore: Double): Boolean;
begin
  Result := TryAnnotationScoreInLines(ALines, APly, 'engine', AScore);
end;

function TScoreHistoryControl.TryVisibleAnnotatorScoreInLines(ALines: TStrings;
  out AScore: Double): Boolean;
var
  I: Integer;
  Ply: Integer;
begin
  Result := False;
  AScore := 0.0;
  if ALines = nil then
    Exit;
  Ply := FCurrentPly;
  if (Ply < 0) or (Ply > ALines.Count) then
    Ply := ALines.Count;
  for I := Ply downto 1 do
    if TryAnnotationScoreInLines(ALines, I, 'annotator', AScore) then
      Exit(True);
end;

function TScoreHistoryControl.TryVisibleScoreInLines(ALines: TStrings;
  out AScore: Double): Boolean;
var
  I: Integer;
  Ply: Integer;
begin
  Result := False;
  AScore := 0.0;
  if ALines = nil then
    Exit;
  Ply := FCurrentPly;
  if (Ply < 0) or (Ply > ALines.Count) then
    Ply := ALines.Count;
  for I := Ply downto 1 do
    if TryScoreInLines(ALines, I, AScore) then
      Exit(True);
end;

end.
