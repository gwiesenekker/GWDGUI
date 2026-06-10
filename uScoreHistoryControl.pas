unit uScoreHistoryControl;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Forms, Graphics, LMessages, SysUtils, uDraughtsBoard,
  uPdn, uPreferences;

type
  TScoreHistoryControl = class(TCustomControl)
  private
    FAnnotationsText: string;
    FCurrentPly: Integer;
    FHintText: string;
    FMaxScore: Double;
    FPlyCount: Integer;
    FScale: TScoreScale;
    FShowEvaluationBar: Boolean;
    FStartingSide: TDraughtsSide;
    function BarPenWidth(APlotWidth, ACount: Integer): Integer;
    function ChartBounds(out APlotLeft, APlotRight: Integer): Boolean;
    procedure DrawMissingScoreRect(ALeft, AMidY, AHalfHeight, AWidth: Integer;
      AColor: TColor);
    procedure DrawScoreRect(ALeft, AMidY, AY, AWidth: Integer;
      AColor: TColor);
    function MappedScore(AScore: Double): Double;
    function ScoreY(AScore: Double; AMidY, AHalfHeight: Integer): Integer;
    function MoveCount: Integer;
    function PlyLabel(APly: Integer): string;
    function PlyAtX(AX: Integer; out APly: Integer): Boolean;
    procedure ClearScoreHint;
    procedure SetAnnotationsText(const AValue: string);
    procedure SetCurrentPly(AValue: Integer);
    procedure SetMaxScore(AValue: Double);
    procedure SetPlyCount(AValue: Integer);
    procedure SetScale(AValue: TScoreScale);
    procedure SetShowEvaluationBar(AValue: Boolean);
    procedure SetStartingSide(AValue: TDraughtsSide);
    function ScoreHintForPly(APly: Integer): string;
    procedure SetScoreHint(const AText: string; AX, AY: Integer);
    function TryAnnotationScoreTextForPly(APly: Integer; const AName: string;
      out AScoreText: string): Boolean;
    function TryAnnotationScoreForPly(APly: Integer; const AName: string;
      out AScore: Double): Boolean;
    function TryScoreForPly(APly: Integer; out AScore: Double): Boolean;
    function TryVisibleAnnotatorScore(out AScore: Double): Boolean;
    function TryVisibleScore(out AScore: Double): Boolean;
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
  Math, Types;

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
  ChartLeft: Integer;
  ChartRight: Integer;
begin
  Result := False;
  APlotLeft := 0;
  APlotRight := 0;
  if (Width < 80) or (Height < 34) then
    Exit;
  if FShowEvaluationBar then
  begin
    ChartLeft := 42;
    ChartRight := Width - 8;
  end
  else
  begin
    ChartLeft := 8;
    ChartRight := Width - 8;
  end;
  if ChartRight <= ChartLeft + 12 then
    Exit;

  APlotLeft := ChartLeft + 3;
  APlotRight := ChartRight - 3;
  Result := APlotRight >= APlotLeft;
end;

procedure TScoreHistoryControl.CMMouseLeave(var Message: TLMessage);
begin
  inherited;
  ClearScoreHint;
end;

procedure TScoreHistoryControl.DrawMissingScoreRect(ALeft, AMidY, AHalfHeight,
  AWidth: Integer; AColor: TColor);
var
  Distance: Integer;
begin
  if AWidth < 1 then
    AWidth := 1;
  Distance := Max(1, AHalfHeight div 30);
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
  HasAnnotatorScore: Boolean;
  HasEngineScore: Boolean;
  HasVisibleScore: Boolean;
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
  Score: Double;
  SplitY: Integer;
  X: Integer;
  Y: Integer;
begin
  Canvas.Brush.Color := Color;
  Canvas.FillRect(ClientRect);

  if (Width < 80) or (Height < 34) then
    Exit;

  if FShowEvaluationBar then
  begin
    BarRect := Types.Rect(8, 6, 30, Height - 6);
    ChartRect := Types.Rect(42, 6, Width - 8, Height - 6);
  end
  else
  begin
    BarRect := Types.Rect(0, 0, 0, 0);
    ChartRect := Types.Rect(8, 6, Width - 8, Height - 6);
  end;
  if ChartRect.Right <= ChartRect.Left + 12 then
    Exit;

  Canvas.Pen.Color := clSilver;
  Canvas.Brush.Style := bsClear;
  if FShowEvaluationBar then
    Canvas.Rectangle(BarRect);
  Canvas.Rectangle(ChartRect);
  MidY := (ChartRect.Top + ChartRect.Bottom) div 2;
  Canvas.Line(ChartRect.Left, MidY, ChartRect.Right, MidY);

  HasVisibleScore := TryVisibleScore(BarScore);
  if not HasVisibleScore then
    HasVisibleScore := TryVisibleAnnotatorScore(BarScore);
  if not HasVisibleScore then
    BarScore := 0.0;
  if FShowEvaluationBar then
  begin
    InnerBarRect := Types.Rect(BarRect.Left + 1, BarRect.Top + 1,
      BarRect.Right, BarRect.Bottom);
    MappedBarScore := MappedScore(BarScore);
    SplitY := InnerBarRect.Top + Round((InnerBarRect.Bottom -
      InnerBarRect.Top) * (0.5 - MappedBarScore / 2.0));
    SplitY := Max(InnerBarRect.Top, Min(InnerBarRect.Bottom, SplitY));
    Canvas.Pen.Style := psClear;
    Canvas.Brush.Color := clWhite;
    Canvas.Rectangle(InnerBarRect);
    Canvas.Brush.Color := clBlack;
    Canvas.Rectangle(InnerBarRect.Left, SplitY, InnerBarRect.Right,
      InnerBarRect.Bottom);
    Canvas.Pen.Style := psSolid;
  end;

  Count := MoveCount;
  if Count <= 0 then
    Exit;

  PlotLeft := ChartRect.Left + 3;
  PlotRight := ChartRect.Right - 3;
  BarWidth := BarPenWidth(PlotRight - PlotLeft + 1, Count);
  for I := 1 to Count do
  begin
    if Count = 1 then
      X := (PlotLeft + PlotRight) div 2
    else
      X := PlotLeft + Round(((I - 1) / (Count - 1)) *
        (PlotRight - PlotLeft));

    HasEngineScore := TryScoreForPly(I, Score);
    HasAnnotatorScore := TryAnnotationScoreForPly(I, 'annotator',
      AnnotatorScore);
    LeftX := X - BarWidth;
    if LeftX < PlotLeft then
      LeftX := PlotLeft
    else if LeftX + BarWidth * 2 > PlotRight then
      LeftX := PlotRight - BarWidth * 2;
    if HasEngineScore then
    begin
      EngineY := ScoreY(Score, MidY, (ChartRect.Bottom - ChartRect.Top) div 2);
      if Score >= 0.0 then
        EngineColor := RGBToColor(54, 150, 79)
      else
        EngineColor := RGBToColor(190, 64, 64);
    end
    else if HasAnnotatorScore then
      EngineY := ScoreY(AnnotatorScore, MidY,
        (ChartRect.Bottom - ChartRect.Top) div 2)
    else
      EngineY := ScoreY(0.0, MidY, (ChartRect.Bottom - ChartRect.Top) div 2);

    if HasAnnotatorScore then
    begin
      Y := ScoreY(AnnotatorScore, MidY, (ChartRect.Bottom -
        ChartRect.Top) div 2);
      if AnnotatorScore >= 0.0 then
        LColor := RGBToColor(140, 210, 155)
      else
        LColor := RGBToColor(230, 145, 145);
    end
    else if HasEngineScore then
      Y := EngineY
    else
      Y := ScoreY(0.0, MidY, (ChartRect.Bottom - ChartRect.Top) div 2);

    if HasEngineScore then
      DrawScoreRect(LeftX, MidY, EngineY, BarWidth, EngineColor)
    else
      DrawMissingScoreRect(LeftX, MidY,
        (ChartRect.Bottom - ChartRect.Top) div 2, BarWidth,
        RGBToColor(28, 74, 132));

    if HasAnnotatorScore then
      DrawScoreRect(LeftX + BarWidth, MidY, Y, BarWidth, LColor)
    else
      DrawMissingScoreRect(LeftX + BarWidth, MidY,
        (ChartRect.Bottom - ChartRect.Top) div 2, BarWidth,
        RGBToColor(102, 169, 220));
  end;

  if (FCurrentPly > 0) and (FCurrentPly <= Count) and (Count > 1) then
  begin
    X := PlotLeft + Round(((FCurrentPly - 1) / (Count - 1)) *
      (PlotRight - PlotLeft));
    Canvas.Pen.Color := clGray;
    Canvas.Line(X, ChartRect.Top, X, ChartRect.Bottom);
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
  AnnotatorScoreText: string;
  EngineScoreText: string;
  HasAnnotatorScore: Boolean;
  HasEngineScore: Boolean;
begin
  HasEngineScore := TryAnnotationScoreTextForPly(APly, 'engine',
    EngineScoreText);
  HasAnnotatorScore := TryAnnotationScoreTextForPly(APly, 'annotator',
    AnnotatorScoreText);

  Result := PlyLabel(APly) + ': ';
  if (not HasEngineScore) and (not HasAnnotatorScore) then
  begin
    Result += 'no score';
    Exit;
  end;

  if HasEngineScore then
    Result += 'engine: ' + EngineScoreText
  else
    Result += 'engine: no score';
  Result += '; ';
  if HasAnnotatorScore then
    Result += 'annotator: ' + AnnotatorScoreText
  else
    Result += 'annotator: no score';
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

function TScoreHistoryControl.TryAnnotationScoreTextForPly(APly: Integer;
  const AName: string; out AScoreText: string): Boolean;
var
  Lines: TStringList;
  Score: Double;
begin
  Result := False;
  AScoreText := '';
  if APly <= 0 then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.Text := FAnnotationsText;
    if APly > Lines.Count then
      Exit;
    AScoreText := ExtractAnnotationValue(Lines[APly - 1], AName);
    if (AScoreText = '') and SameText(AName, 'engine') then
      AScoreText := ExtractAnnotationValue(Lines[APly - 1], 'score');
    if AScoreText = '' then
      Exit;
    Result := TryExtractScoreFromAnnotation('score=' + AScoreText, Score);
    if not Result then
      AScoreText := '';
  finally
    Lines.Free;
  end;
end;

function TScoreHistoryControl.TryAnnotationScoreForPly(APly: Integer;
  const AName: string; out AScore: Double): Boolean;
var
  ScoreText: string;
begin
  Result := False;
  AScore := 0.0;
  if TryAnnotationScoreTextForPly(APly, AName, ScoreText) then
    Result := TryExtractScoreFromAnnotation('score=' + ScoreText, AScore);
end;

function TScoreHistoryControl.TryScoreForPly(APly: Integer;
  out AScore: Double): Boolean;
begin
  Result := TryAnnotationScoreForPly(APly, 'engine', AScore);
end;

function TScoreHistoryControl.TryVisibleAnnotatorScore(out AScore: Double): Boolean;
var
  I: Integer;
  Lines: TStringList;
  Ply: Integer;
begin
  Result := False;
  AScore := 0.0;
  Lines := TStringList.Create;
  try
    Lines.Text := FAnnotationsText;
    Ply := FCurrentPly;
    if (Ply < 0) or (Ply > Lines.Count) then
      Ply := Lines.Count;
    for I := Ply downto 1 do
      if TryAnnotationScoreForPly(I, 'annotator', AScore) then
        Exit(True);
  finally
    Lines.Free;
  end;
end;

function TScoreHistoryControl.TryVisibleScore(out AScore: Double): Boolean;
var
  I: Integer;
  Lines: TStringList;
  Ply: Integer;
begin
  Result := False;
  AScore := 0.0;
  Lines := TStringList.Create;
  try
    Lines.Text := FAnnotationsText;
    Ply := FCurrentPly;
    if (Ply < 0) or (Ply > Lines.Count) then
      Ply := Lines.Count;
    for I := Ply downto 1 do
      if TryScoreForPly(I, AScore) then
        Exit(True);
  finally
    Lines.Free;
  end;
end;

end.
