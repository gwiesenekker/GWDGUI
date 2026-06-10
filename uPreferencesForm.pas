unit uPreferencesForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Dialogs, ExtCtrls, Forms, Graphics, StdCtrls,
  uPreferences;

type
  TPreferencesAcceptedEvent = procedure(Sender: TObject;
    const APreferences: TGuiPreferences) of object;

  TPreferencesForm = class(TForm)
  private
    FColorDialog: TColorDialog;
    FEvaluationMaxEdit: TEdit;
    FEvaluationScaleGroup: TRadioGroup;
    FOnAccepted: TPreferencesAcceptedEvent;
    FPreferences: TGuiPreferences;
    FSwatches: array[0..7] of TPanel;
    procedure AddColorRow(AParent: TWinControl; const ACaption: string;
      AIndex: Integer; ATop: Integer);
    procedure ApplyClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure ChooseColorClick(Sender: TObject);
    function ColorByIndex(AIndex: Integer): TColor;
    procedure DefaultsClick(Sender: TObject);
    procedure SetColorByIndex(AIndex: Integer; AColor: TColor);
    procedure UpdateSwatches;
  public
    constructor Create(AOwner: TComponent); override;
    procedure StartEdit(const APreferences: TGuiPreferences);
    property OnAccepted: TPreferencesAcceptedEvent read FOnAccepted
      write FOnAccepted;
  end;

implementation

uses
  SysUtils;

constructor TPreferencesForm.Create(AOwner: TComponent);
var
  LApplyButton: TButton;
  LCancelButton: TButton;
  LDefaultsButton: TButton;
  LGroup: TGroupBox;
begin
  inherited Create(AOwner);
  Caption := 'Preferences';
  Position := poDesigned;
  BorderStyle := bsSizeable;
  Width := 500;
  Height := 647;
  Constraints.MinWidth := 460;
  Constraints.MinHeight := 587;

  FColorDialog := TColorDialog.Create(Self);

  LGroup := TGroupBox.Create(Self);
  LGroup.Parent := Self;
  LGroup.Align := alTop;
  LGroup.Height := 184;
  LGroup.BorderSpacing.Around := 8;
  LGroup.Caption := 'Board colours';
  AddColorRow(LGroup, 'Main board light', 0, 30);
  AddColorRow(LGroup, 'Main board dark', 1, 66);
  AddColorRow(LGroup, 'Analysis board light', 2, 102);
  AddColorRow(LGroup, 'Analysis board dark', 3, 138);

  LGroup := TGroupBox.Create(Self);
  LGroup.Parent := Self;
  LGroup.Align := alTop;
  LGroup.Height := 184;
  LGroup.BorderSpacing.Left := 8;
  LGroup.BorderSpacing.Right := 8;
  LGroup.BorderSpacing.Bottom := 8;
  LGroup.Caption := 'Highlights';
  AddColorRow(LGroup, 'Target square', 4, 30);
  AddColorRow(LGroup, 'Last move', 5, 66);
  AddColorRow(LGroup, 'PV move', 6, 102);
  AddColorRow(LGroup, 'Hint move', 7, 138);

  LGroup := TGroupBox.Create(Self);
  LGroup.Parent := Self;
  LGroup.Align := alTop;
  LGroup.Height := 144;
  LGroup.BorderSpacing.Left := 8;
  LGroup.BorderSpacing.Right := 8;
  LGroup.BorderSpacing.Bottom := 8;
  LGroup.Caption := 'Evaluation bar / score history';

  FEvaluationMaxEdit := TEdit.Create(Self);
  FEvaluationMaxEdit.Parent := LGroup;
  FEvaluationMaxEdit.SetBounds(250, 28, 80, 24);

  with TLabel.Create(Self) do
  begin
    Parent := LGroup;
    SetBounds(12, 32, 220, 22);
    Caption := 'Max score';
  end;

  FEvaluationScaleGroup := TRadioGroup.Create(Self);
  FEvaluationScaleGroup.Parent := LGroup;
  FEvaluationScaleGroup.SetBounds(12, 60, 318, 58);
  FEvaluationScaleGroup.Caption := 'Scale';
  FEvaluationScaleGroup.Columns := 2;
  FEvaluationScaleGroup.Items.Add('Linear');
  FEvaluationScaleGroup.Items.Add('Logarithmic');

  LDefaultsButton := TButton.Create(Self);
  LDefaultsButton.Parent := Self;
  LDefaultsButton.SetBounds(8, 306, 96, 28);
  LDefaultsButton.AnchorSide[akLeft].Control := Self;
  LDefaultsButton.AnchorSide[akBottom].Control := Self;
  LDefaultsButton.AnchorSide[akBottom].Side := asrBottom;
  LDefaultsButton.Anchors := [akLeft, akBottom];
  LDefaultsButton.BorderSpacing.Bottom := 12;
  LDefaultsButton.Caption := 'Defaults';
  LDefaultsButton.OnClick := @DefaultsClick;

  LCancelButton := TButton.Create(Self);
  LCancelButton.Parent := Self;
  LCancelButton.SetBounds(304, 306, 96, 28);
  LCancelButton.AnchorSide[akRight].Control := Self;
  LCancelButton.AnchorSide[akRight].Side := asrRight;
  LCancelButton.AnchorSide[akBottom].Control := Self;
  LCancelButton.AnchorSide[akBottom].Side := asrBottom;
  LCancelButton.Anchors := [akRight, akBottom];
  LCancelButton.BorderSpacing.Right := 12;
  LCancelButton.BorderSpacing.Bottom := 12;
  LCancelButton.Caption := 'Close';
  LCancelButton.OnClick := @CancelClick;

  LApplyButton := TButton.Create(Self);
  LApplyButton.Parent := Self;
  LApplyButton.SetBounds(200, 306, 96, 28);
  LApplyButton.AnchorSide[akRight].Control := LCancelButton;
  LApplyButton.AnchorSide[akRight].Side := asrLeft;
  LApplyButton.AnchorSide[akBottom].Control := Self;
  LApplyButton.AnchorSide[akBottom].Side := asrBottom;
  LApplyButton.Anchors := [akRight, akBottom];
  LApplyButton.BorderSpacing.Right := 8;
  LApplyButton.BorderSpacing.Bottom := 12;
  LApplyButton.Caption := 'Save';
  LApplyButton.OnClick := @ApplyClick;
end;

procedure TPreferencesForm.AddColorRow(AParent: TWinControl;
  const ACaption: string; AIndex: Integer; ATop: Integer);
var
  LButton: TButton;
  LLabel: TLabel;
begin
  LLabel := TLabel.Create(Self);
  LLabel.Parent := AParent;
  LLabel.SetBounds(12, ATop + 4, 220, 22);
  LLabel.Caption := ACaption;

  FSwatches[AIndex] := TPanel.Create(Self);
  FSwatches[AIndex].Parent := AParent;
  FSwatches[AIndex].SetBounds(250, ATop, 34, 24);
  FSwatches[AIndex].BevelOuter := bvLowered;

  LButton := TButton.Create(Self);
  LButton.Parent := AParent;
  LButton.SetBounds(294, ATop, 110, 24);
  LButton.Caption := 'Choose...';
  LButton.Tag := AIndex;
  LButton.OnClick := @ChooseColorClick;
end;

function TPreferencesForm.ColorByIndex(AIndex: Integer): TColor;
begin
  case AIndex of
    0: Result := FPreferences.MainBoardLightColor;
    1: Result := FPreferences.MainBoardDarkColor;
    2: Result := FPreferences.AnalysisBoardLightColor;
    3: Result := FPreferences.AnalysisBoardDarkColor;
    4: Result := FPreferences.TargetSquareColor;
    5: Result := FPreferences.LastMoveColor;
    6: Result := FPreferences.PvMoveColor;
    7: Result := FPreferences.HintMoveColor;
  else
    Result := clBlack;
  end;
end;

procedure TPreferencesForm.SetColorByIndex(AIndex: Integer; AColor: TColor);
begin
  case AIndex of
    0: FPreferences.MainBoardLightColor := AColor;
    1: FPreferences.MainBoardDarkColor := AColor;
    2: FPreferences.AnalysisBoardLightColor := AColor;
    3: FPreferences.AnalysisBoardDarkColor := AColor;
    4: FPreferences.TargetSquareColor := AColor;
    5: FPreferences.LastMoveColor := AColor;
    6: FPreferences.PvMoveColor := AColor;
    7: FPreferences.HintMoveColor := AColor;
  end;
end;

procedure TPreferencesForm.UpdateSwatches;
var
  I: Integer;
begin
  for I := Low(FSwatches) to High(FSwatches) do
    if FSwatches[I] <> nil then
      FSwatches[I].Color := ColorByIndex(I);
end;

procedure TPreferencesForm.StartEdit(const APreferences: TGuiPreferences);
begin
  FPreferences := APreferences;
  if FEvaluationMaxEdit <> nil then
    FEvaluationMaxEdit.Text := FormatFloat('0.###',
      FPreferences.EvaluationMaxScore);
  if FEvaluationScaleGroup <> nil then
  begin
    if FPreferences.EvaluationScale = ssLinear then
      FEvaluationScaleGroup.ItemIndex := 0
    else
      FEvaluationScaleGroup.ItemIndex := 1;
  end;
  UpdateSwatches;
end;

procedure TPreferencesForm.ChooseColorClick(Sender: TObject);
var
  Index: Integer;
begin
  if not (Sender is TButton) then
    Exit;
  Index := TButton(Sender).Tag;
  FColorDialog.Color := ColorByIndex(Index);
  if FColorDialog.Execute then
  begin
    SetColorByIndex(Index, FColorDialog.Color);
    UpdateSwatches;
  end;
end;

procedure TPreferencesForm.DefaultsClick(Sender: TObject);
begin
  FPreferences := DefaultGuiPreferences;
  if FEvaluationMaxEdit <> nil then
    FEvaluationMaxEdit.Text := FormatFloat('0.###',
      FPreferences.EvaluationMaxScore);
  if FEvaluationScaleGroup <> nil then
    FEvaluationScaleGroup.ItemIndex := 1;
  UpdateSwatches;
end;

procedure TPreferencesForm.ApplyClick(Sender: TObject);
var
  MaxScore: Double;
begin
  if (FEvaluationMaxEdit <> nil) and
    TryStrToFloat(Trim(FEvaluationMaxEdit.Text), MaxScore) and
    (MaxScore > 0.0) then
    FPreferences.EvaluationMaxScore := MaxScore;
  if FEvaluationScaleGroup <> nil then
  begin
    if FEvaluationScaleGroup.ItemIndex = 0 then
      FPreferences.EvaluationScale := ssLinear
    else
      FPreferences.EvaluationScale := ssLogarithmic;
  end;
  if Assigned(FOnAccepted) then
    FOnAccepted(Self, FPreferences);
end;

procedure TPreferencesForm.CancelClick(Sender: TObject);
begin
  Hide;
end;

end.
