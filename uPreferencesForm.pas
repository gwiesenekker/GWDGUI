unit uPreferencesForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, ComCtrls, Controls, Dialogs, ExtCtrls, Forms, Graphics, StdCtrls,
  uPreferences, uNotationStyles;

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
    FSwatches: array[0..11] of TPanel;
    FNotationBold, FNotationItalic: array[TNotationStyle] of TCheckBox;
    FNotationSamples: array[TNotationStyle] of TLabel;
    procedure AddNotationRow(AParent: TWinControl; AStyle: TNotationStyle; ATop: Integer);
    procedure NotationChanged(Sender: TObject);
    procedure UpdateNotationSamples;
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
  LButtonPanel: TPanel;
  LCancelButton: TButton;
  LDefaultsButton: TButton;
  LGroup: TGroupBox;
  LPageControl: TPageControl;
  LTab: TTabSheet;
  S: TNotationStyle;
begin
  inherited Create(AOwner);
  Caption := 'Preferences';
  Position := poDesigned;
  BorderStyle := bsSizeable;
  Width := 520;
  Height := 647;
  Constraints.MinWidth := 520;
  Constraints.MinHeight := 587;

  FColorDialog := TColorDialog.Create(Self);

  LButtonPanel := TPanel.Create(Self);
  LButtonPanel.Parent := Self;
  LButtonPanel.Align := alBottom;
  LButtonPanel.Height := 52;
  LButtonPanel.BevelOuter := bvNone;
  LButtonPanel.BorderSpacing.Around := 8;

  LPageControl := TPageControl.Create(Self);
  LPageControl.Parent := Self;
  LPageControl.Align := alClient;
  LPageControl.BorderSpacing.Around := 8;

  LTab := TTabSheet.Create(Self);
  LTab.PageControl := LPageControl;
  LTab.Caption := 'Appearance';

  LGroup := TGroupBox.Create(Self);
  LGroup.Parent := LTab;
  LGroup.Align := alTop;
  LGroup.Height := 184;
  LGroup.BorderSpacing.Around := 8;
  LGroup.Caption := 'Board colours';
  AddColorRow(LGroup, 'Main board light', 0, 30);
  AddColorRow(LGroup, 'Main board dark', 1, 66);
  AddColorRow(LGroup, 'Analysis board light', 2, 102);
  AddColorRow(LGroup, 'Analysis board dark', 3, 138);

  LGroup := TGroupBox.Create(Self);
  LGroup.Parent := LTab;
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

  LTab := TTabSheet.Create(Self);
  LTab.PageControl := LPageControl;
  LTab.Caption := 'Evaluation';

  LGroup := TGroupBox.Create(Self);
  LGroup.Parent := LTab;
  LGroup.Align := alTop;
  LGroup.Height := 144;
  LGroup.BorderSpacing.Around := 8;
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

  LTab := TTabSheet.Create(Self);
  LTab.PageControl := LPageControl; LTab.Caption := 'Notation'; LTab.Name := 'NotationTab';
  with TLabel.Create(Self) do
  begin
    Parent := LTab; SetBounds(12, 12, 440, 48); WordWrap := True;
    Caption := 'Game moves use one font. Choose colours and bold/italic styles below.';
  end;
  LGroup := TGroupBox.Create(Self); LGroup.Parent := LTab;
  LGroup.SetBounds(8, 66, 464, 240); LGroup.Caption := 'Moves window';
  for S := Low(S) to High(S) do AddNotationRow(LGroup, S, 30+Ord(S)*46);

  LDefaultsButton := TButton.Create(Self);
  LDefaultsButton.Parent := LButtonPanel;
  LDefaultsButton.Align := alLeft;
  LDefaultsButton.Width := 96;
  LDefaultsButton.Caption := 'Defaults'; LDefaultsButton.Name := 'PreferencesDefaults';
  LDefaultsButton.OnClick := @DefaultsClick;

  LCancelButton := TButton.Create(Self);
  LCancelButton.Parent := LButtonPanel;
  LCancelButton.Align := alRight;
  LCancelButton.Width := 96;
  LCancelButton.Caption := 'Close';
  LCancelButton.OnClick := @CancelClick;

  LApplyButton := TButton.Create(Self);
  LApplyButton.Parent := LButtonPanel;
  LApplyButton.Align := alRight;
  LApplyButton.Width := 96;
  LApplyButton.BorderSpacing.Right := 8;
  LApplyButton.Caption := 'Save'; LApplyButton.Name := 'PreferencesApply';
  LApplyButton.OnClick := @ApplyClick;
end;

procedure TPreferencesForm.AddNotationRow(AParent: TWinControl; AStyle: TNotationStyle; ATop: Integer);
var Button: TButton; Index: Integer;
begin
  Index := 8+Ord(AStyle);
  FNotationSamples[AStyle] := TLabel.Create(Self);
  with FNotationSamples[AStyle] do
  begin Parent := AParent; SetBounds(12, ATop+4, 150, 24); Caption := NotationStyleNames[AStyle]; Name := 'NotationSample'+IntToStr(Ord(AStyle)); end;
  FSwatches[Index] := TPanel.Create(Self);
  with FSwatches[Index] do
  begin Parent := AParent; SetBounds(168, ATop, 30, 24); BevelOuter := bvLowered; end;
  Button := TButton.Create(Self);
  Button.Parent := AParent; Button.SetBounds(206, ATop, 76, 26);
  Button.Caption := 'Colour...'; Button.Tag := Index; Button.OnClick := @ChooseColorClick;
  FNotationBold[AStyle] := TCheckBox.Create(Self);
  with FNotationBold[AStyle] do
  begin
    Parent := AParent; SetBounds(296, ATop, 68, 26); Caption := 'Bold';
    Name := 'NotationBold'+IntToStr(Ord(AStyle)); OnChange := @NotationChanged;
  end;
  FNotationItalic[AStyle] := TCheckBox.Create(Self);
  with FNotationItalic[AStyle] do
  begin
    Parent := AParent; SetBounds(372, ATop, 72, 26); Caption := 'Italic';
    Name := 'NotationItalic'+IntToStr(Ord(AStyle)); OnChange := @NotationChanged;
  end;
end;
procedure TPreferencesForm.NotationChanged(Sender: TObject);
begin UpdateNotationSamples; end;
procedure TPreferencesForm.UpdateNotationSamples;
var S: TNotationStyle; Style: TFontStyles;
begin
  for S := Low(S) to High(S) do
    if (FNotationSamples[S] <> nil) and (FNotationBold[S] <> nil) and (FNotationItalic[S] <> nil) then
    begin
      Style := [];
      if FNotationBold[S].Checked then Include(Style, fsBold);
      if FNotationItalic[S].Checked then Include(Style, fsItalic);
      FNotationSamples[S].Font.Style := Style;
      FNotationSamples[S].Font.Color := FPreferences.NotationStyles[S].Color;
    end;
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
    8..11: Result := FPreferences.NotationStyles[TNotationStyle(AIndex-8)].Color;
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
    8..11: FPreferences.NotationStyles[TNotationStyle(AIndex-8)].Color := AColor;
  end;
end;

procedure TPreferencesForm.UpdateSwatches;
var
  I: Integer;
begin
  for I := Low(FSwatches) to High(FSwatches) do
    if FSwatches[I] <> nil then
      FSwatches[I].Color := ColorByIndex(I);
  UpdateNotationSamples;
end;

procedure TPreferencesForm.StartEdit(const APreferences: TGuiPreferences);
var S: TNotationStyle;
begin
  FPreferences := APreferences;
  for S := Low(S) to High(S) do
  begin
    FNotationBold[S].Checked := FPreferences.NotationStyles[S].Bold;
    FNotationItalic[S].Checked := FPreferences.NotationStyles[S].Italic;
  end;
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
begin StartEdit(DefaultGuiPreferences); end;

procedure TPreferencesForm.ApplyClick(Sender: TObject);
var
  MaxScore: Double;
  S: TNotationStyle;
begin
  for S := Low(S) to High(S) do
  begin
    FPreferences.NotationStyles[S].Bold := FNotationBold[S].Checked;
    FPreferences.NotationStyles[S].Italic := FNotationItalic[S].Checked;
  end;
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
