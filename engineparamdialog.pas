unit EngineParamDialog;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Controls,
  Dialogs,
  EngineParams,
  Forms,
  Grids,
  StdCtrls;

type
  TEngineParamDialog = class(TForm)
  private
    FCancelButton: TButton;
    FBoolCombo: TComboBox;
    FBrowseDirButton: TButton;
    FDirectoryDialog: TSelectDirectoryDialog;
    FGrid: TStringGrid;
    FInlineBoolCombo: TComboBox;
    FOKButton: TButton;
    FParams: TEngineParamArray;
    FSelectedRow: Integer;
    procedure BoolComboChange(Sender: TObject);
    procedure BrowseDirButtonClick(Sender: TObject);
    procedure CancelButtonClick(Sender: TObject);
    procedure CloseWithResult(AResult: Integer);
    procedure GridMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure HideInlineBoolCombo(Sender: TObject);
    procedure InlineBoolComboSelect(Sender: TObject);
    procedure OKButtonClick(Sender: TObject);
    procedure LoadGrid;
    procedure SelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
    procedure StoreGrid;
    procedure UpdateRowControls;
    function IsBoolRow(ARow: Integer): Boolean;
    function IsDirRow(ARow: Integer): Boolean;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetParams(const AParams: TEngineParamArray);
    property Params: TEngineParamArray read FParams;
  end;

implementation

uses
  ExtCtrls,
  SysUtils;

constructor TEngineParamDialog.Create(AOwner: TComponent);
var
  ButtonPanel: TPanel;
  EditPanel: TPanel;
begin
  inherited Create(AOwner);

  Caption := 'Engine Parameters';
  Width := 760;
  Height := 560;
  Position := poOwnerFormCenter;
  FSelectedRow := 0;

  ButtonPanel := TPanel.Create(Self);
  ButtonPanel.Parent := Self;
  ButtonPanel.Align := alBottom;
  ButtonPanel.Height := 44;
  ButtonPanel.BevelOuter := bvNone;

  FCancelButton := TButton.Create(ButtonPanel);
  FCancelButton.Parent := ButtonPanel;
  FCancelButton.Align := alRight;
  FCancelButton.Caption := 'Cancel';
  FCancelButton.Cancel := True;
  FCancelButton.OnClick := @CancelButtonClick;
  FCancelButton.BorderSpacing.Around := 8;
  CancelControl := FCancelButton;

  FOKButton := TButton.Create(ButtonPanel);
  FOKButton.Parent := ButtonPanel;
  FOKButton.Align := alRight;
  FOKButton.Caption := 'OK';
  FOKButton.Default := True;
  FOKButton.OnClick := @OKButtonClick;
  FOKButton.BorderSpacing.Around := 8;
  DefaultControl := FOKButton;

  EditPanel := TPanel.Create(Self);
  EditPanel.Parent := Self;
  EditPanel.Align := alBottom;
  EditPanel.Height := 44;
  EditPanel.BevelOuter := bvNone;

  FBoolCombo := TComboBox.Create(EditPanel);
  FBoolCombo.Parent := EditPanel;
  FBoolCombo.Align := alLeft;
  FBoolCombo.Width := 160;
  FBoolCombo.Style := csDropDownList;
  FBoolCombo.Items.Add('false');
  FBoolCombo.Items.Add('true');
  FBoolCombo.BorderSpacing.Around := 8;
  FBoolCombo.Enabled := False;
  FBoolCombo.OnChange := @BoolComboChange;

  FBrowseDirButton := TButton.Create(EditPanel);
  FBrowseDirButton.Parent := EditPanel;
  FBrowseDirButton.Align := alLeft;
  FBrowseDirButton.Caption := 'Browse directory...';
  FBrowseDirButton.Width := 170;
  FBrowseDirButton.BorderSpacing.Around := 8;
  FBrowseDirButton.Enabled := False;
  FBrowseDirButton.OnClick := @BrowseDirButtonClick;

  FDirectoryDialog := TSelectDirectoryDialog.Create(Self);
  FDirectoryDialog.Title := 'Select parameter directory';

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.ColCount := 3;
  FGrid.FixedRows := 1;
  FGrid.Options := FGrid.Options + [goEditing, goColSizing];
  FGrid.OnMouseUp := @GridMouseUp;
  FGrid.OnSelectCell := @SelectCell;
  FGrid.Cells[0, 0] := 'name';
  FGrid.Cells[1, 0] := 'type';
  FGrid.Cells[2, 0] := 'value';
  FGrid.ColWidths[0] := 260;
  FGrid.ColWidths[1] := 100;
  FGrid.ColWidths[2] := 340;

  FInlineBoolCombo := TComboBox.Create(FGrid);
  FInlineBoolCombo.Parent := FGrid;
  FInlineBoolCombo.Visible := False;
  FInlineBoolCombo.Style := csDropDownList;
  FInlineBoolCombo.Items.Add('false');
  FInlineBoolCombo.Items.Add('true');
  FInlineBoolCombo.OnSelect := @InlineBoolComboSelect;
  FInlineBoolCombo.OnCloseUp := @HideInlineBoolCombo;
  FInlineBoolCombo.OnExit := @HideInlineBoolCombo;

  EditPanel.BringToFront;
  ButtonPanel.BringToFront;
end;

procedure TEngineParamDialog.BoolComboChange(Sender: TObject);
begin
  if (FSelectedRow <= 0) or (FSelectedRow >= FGrid.RowCount) then
    Exit;
  if FBoolCombo.ItemIndex >= 0 then
    FGrid.Cells[2, FSelectedRow] := FBoolCombo.Text;
end;

procedure TEngineParamDialog.BrowseDirButtonClick(Sender: TObject);
begin
  if (FSelectedRow <= 0) or (FSelectedRow >= FGrid.RowCount) then
    Exit;

  FDirectoryDialog.InitialDir := FGrid.Cells[2, FSelectedRow];
  if FDirectoryDialog.Execute then
    FGrid.Cells[2, FSelectedRow] := FDirectoryDialog.FileName;
end;

procedure TEngineParamDialog.CancelButtonClick(Sender: TObject);
begin
  CloseWithResult(mrCancel);
end;

procedure TEngineParamDialog.CloseWithResult(AResult: Integer);
begin
  FInlineBoolCombo.Visible := False;
  FGrid.EditorMode := False;
  if AResult = mrOK then
    StoreGrid;
  ModalResult := AResult;
  Hide;
end;

procedure TEngineParamDialog.GridMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Col: LongInt;
  Row: LongInt;
  CellRect: TRect;
begin
  if Button <> mbLeft then
    Exit;

  FGrid.MouseToCell(X, Y, Col, Row);
  if (Row <= 0) or (Row >= FGrid.RowCount) then
    Exit;

  FSelectedRow := Row;
  UpdateRowControls;

  if (Col = 2) and IsBoolRow(Row) then
  begin
    CellRect := FGrid.CellRect(Col, Row);
    FInlineBoolCombo.SetBounds(CellRect.Left, CellRect.Top,
      CellRect.Right - CellRect.Left, CellRect.Bottom - CellRect.Top);
    if SameText(FGrid.Cells[2, Row], 'true') then
      FInlineBoolCombo.ItemIndex := 1
    else
      FInlineBoolCombo.ItemIndex := 0;
    FInlineBoolCombo.Visible := True;
    FInlineBoolCombo.BringToFront;
    FInlineBoolCombo.SetFocus;
    FInlineBoolCombo.DroppedDown := True;
  end
  else if ((Col = 0) or (Col = 2)) and IsDirRow(Row) then
  begin
    FDirectoryDialog.InitialDir := FGrid.Cells[2, Row];
    if FDirectoryDialog.Execute then
      FGrid.Cells[2, Row] := FDirectoryDialog.FileName;
  end
  else
    FInlineBoolCombo.Visible := False;
end;

procedure TEngineParamDialog.HideInlineBoolCombo(Sender: TObject);
begin
  FInlineBoolCombo.Visible := False;
end;

procedure TEngineParamDialog.InlineBoolComboSelect(Sender: TObject);
begin
  if (FSelectedRow > 0) and (FSelectedRow < FGrid.RowCount) and
    (FInlineBoolCombo.ItemIndex >= 0) then
    FGrid.Cells[2, FSelectedRow] := FInlineBoolCombo.Text;
end;

procedure TEngineParamDialog.OKButtonClick(Sender: TObject);
begin
  CloseWithResult(mrOK);
end;

procedure TEngineParamDialog.SetParams(const AParams: TEngineParamArray);
var
  I: Integer;
begin
  SetLength(FParams, Length(AParams));
  for I := 0 to High(AParams) do
    FParams[I] := AParams[I];
  LoadGrid;
end;

procedure TEngineParamDialog.LoadGrid;
var
  I: Integer;
begin
  FGrid.RowCount := Length(FParams) + 1;
  for I := 0 to High(FParams) do
  begin
    FGrid.Cells[0, I + 1] := FParams[I].Name;
    FGrid.Cells[1, I + 1] := FParams[I].ParamType;
    FGrid.Cells[2, I + 1] := FParams[I].Value;
  end;
  UpdateRowControls;
end;

procedure TEngineParamDialog.SelectCell(Sender: TObject; aCol, aRow: Integer;
  var CanSelect: Boolean);
begin
  FSelectedRow := aRow;
  UpdateRowControls;
end;

procedure TEngineParamDialog.UpdateRowControls;
var
  IsBool: Boolean;
  IsDir: Boolean;
  Value: String;
begin
  IsBool := IsBoolRow(FSelectedRow);
  IsDir := IsDirRow(FSelectedRow);

  FBoolCombo.Enabled := IsBool;
  if IsBool then
  begin
    Value := LowerCase(FGrid.Cells[2, FSelectedRow]);
    if Value = 'true' then
      FBoolCombo.ItemIndex := 1
    else
      FBoolCombo.ItemIndex := 0;
  end
  else
    FBoolCombo.ItemIndex := -1;

  FBrowseDirButton.Enabled := IsDir;
end;

function TEngineParamDialog.IsBoolRow(ARow: Integer): Boolean;
begin
  Result := (ARow > 0) and (ARow < FGrid.RowCount) and
    SameText(FGrid.Cells[1, ARow], 'bool');
end;

function TEngineParamDialog.IsDirRow(ARow: Integer): Boolean;
var
  ParamName: String;
begin
  Result := False;
  if (ARow <= 0) or (ARow >= FGrid.RowCount) then
    Exit;

  ParamName := LowerCase(FGrid.Cells[0, ARow]);
  Result := (Pos('dir', ParamName) > 0) or
    (Copy(ParamName, Length(ParamName) - 3, 4) = '-dir') or
    (Copy(ParamName, Length(ParamName) - 4, 5) = '-path');
end;

procedure TEngineParamDialog.StoreGrid;
var
  I: Integer;
begin
  SetLength(FParams, FGrid.RowCount - 1);
  for I := 1 to FGrid.RowCount - 1 do
  begin
    FParams[I - 1].Name := FGrid.Cells[0, I];
    FParams[I - 1].ParamType := FGrid.Cells[1, I];
    FParams[I - 1].Value := FGrid.Cells[2, I];
  end;
end;

end.
