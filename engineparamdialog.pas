unit EngineParamDialog;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Controls,
  Dialogs,
  EngineParams,
  ExtCtrls,
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
    FIniFileName: String;
    FIniLabel: TLabel;
    FIniMemo: TMemo;
    FIniPanel: TPanel;
    FOKButton: TButton;
    FParams: TEngineParamArray;
    FScorePerspectiveCombo: TComboBox;
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
    function FindIniFileForEngine(const AEngineFileName: String): String;
    function SaveIniFile: Boolean;
    procedure ScorePerspectiveComboChange(Sender: TObject);
    procedure SelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
    procedure StoreGrid;
    procedure UpdateRowControls;
    function IsBoolRow(ARow: Integer): Boolean;
    function IsDirRow(ARow: Integer): Boolean;
    function IsScorePerspectiveRow(ARow: Integer): Boolean;
    procedure PrepareInlineComboForRow(ARow: Integer);
  public
    constructor Create(AOwner: TComponent); override;
    procedure LoadIniFromEngineFile(const AEngineFileName: String);
    procedure SetParams(const AParams: TEngineParamArray);
    property Params: TEngineParamArray read FParams;
  end;

implementation

uses
  SysUtils;

const
  EngineIniFileParamName = 'gui-ini-file';

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

  FScorePerspectiveCombo := TComboBox.Create(EditPanel);
  FScorePerspectiveCombo.Parent := EditPanel;
  FScorePerspectiveCombo.Align := alLeft;
  FScorePerspectiveCombo.Width := 170;
  FScorePerspectiveCombo.Style := csDropDownList;
  FScorePerspectiveCombo.Items.Add('side-to-move');
  FScorePerspectiveCombo.Items.Add('white');
  FScorePerspectiveCombo.Items.Add('black');
  FScorePerspectiveCombo.BorderSpacing.Around := 8;
  FScorePerspectiveCombo.Enabled := False;
  FScorePerspectiveCombo.OnChange := @ScorePerspectiveComboChange;

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

  FIniPanel := TPanel.Create(Self);
  FIniPanel.Parent := Self;
  FIniPanel.Align := alBottom;
  FIniPanel.Height := 170;
  FIniPanel.BevelOuter := bvNone;
  FIniPanel.BorderSpacing.Around := 8;
  FIniPanel.Visible := False;

  FIniLabel := TLabel.Create(FIniPanel);
  FIniLabel.Parent := FIniPanel;
  FIniLabel.Align := alTop;
  FIniLabel.Height := 22;

  FIniMemo := TMemo.Create(FIniPanel);
  FIniMemo.Parent := FIniPanel;
  FIniMemo.Align := alClient;
  FIniMemo.ScrollBars := ssBoth;
  FIniMemo.WordWrap := False;

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

procedure TEngineParamDialog.ScorePerspectiveComboChange(Sender: TObject);
begin
  if (FSelectedRow <= 0) or (FSelectedRow >= FGrid.RowCount) then
    Exit;
  if FScorePerspectiveCombo.ItemIndex >= 0 then
    FGrid.Cells[2, FSelectedRow] := FScorePerspectiveCombo.Text;
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
  if (AResult = mrOK) and (not SaveIniFile) then
    Exit;
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

  if (Col = 2) and (IsBoolRow(Row) or IsScorePerspectiveRow(Row)) then
  begin
    PrepareInlineComboForRow(Row);
    CellRect := FGrid.CellRect(Col, Row);
    FInlineBoolCombo.SetBounds(CellRect.Left, CellRect.Top,
      CellRect.Right - CellRect.Left, CellRect.Bottom - CellRect.Top);
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

function TEngineParamDialog.FindIniFileForEngine(
  const AEngineFileName: String): String;
var
  EngineDir: String;
  Info: TSearchRec;
  PreferredName: String;
  PreferredStem: String;
begin
  Result := '';
  if AEngineFileName = '' then
    Exit;

  EngineDir := ExtractFilePath(AEngineFileName);
  if EngineDir = '' then
    Exit;

  PreferredStem := ChangeFileExt(ExtractFileName(AEngineFileName), '');
  PreferredName := EngineDir + PreferredStem + '.ini';
  if FileExists(PreferredName) then
    Exit(PreferredName);

  if FindFirst(EngineDir + '*', faAnyFile, Info) = 0 then
  try
    repeat
      if ((Info.Attr and faDirectory) = 0) and
        SameText(ChangeFileExt(Info.Name, ''), PreferredStem) and
        SameText(ExtractFileExt(Info.Name), '.ini') then
        Exit(EngineDir + Info.Name);
    until FindNext(Info) <> 0;
  finally
    FindClose(Info);
  end;

  if FindFirst(EngineDir + '*', faAnyFile, Info) = 0 then
  try
    repeat
      if ((Info.Attr and faDirectory) = 0) and
        SameText(ExtractFileExt(Info.Name), '.ini') then
        Exit(EngineDir + Info.Name);
    until FindNext(Info) <> 0;
  finally
    FindClose(Info);
  end;
end;

procedure TEngineParamDialog.LoadIniFromEngineFile(
  const AEngineFileName: String);
var
  I: Integer;
begin
  FIniFileName := '';
  for I := 0 to High(FParams) do
    if SameText(FParams[I].Name, EngineIniFileParamName) then
    begin
      FIniFileName := Trim(FParams[I].Value);
      Break;
    end;
  if FIniFileName = '' then
    FIniFileName := FindIniFileForEngine(AEngineFileName);
  FIniPanel.Visible := FIniFileName <> '';
  if FIniFileName = '' then
    Exit;

  FIniLabel.Caption := 'INI file: ' + FIniFileName;
  try
    FIniMemo.Lines.LoadFromFile(FIniFileName);
  except
    on E: Exception do
    begin
      FIniMemo.Clear;
      FIniMemo.Lines.Add('; Could not load INI file: ' + E.Message);
    end;
  end;
end;

function TEngineParamDialog.SaveIniFile: Boolean;
begin
  Result := True;
  if FIniFileName = '' then
    Exit;

  try
    FIniMemo.Lines.SaveToFile(FIniFileName);
  except
    on E: Exception do
    begin
      MessageDlg('Could not save INI file:' + LineEnding + FIniFileName +
        LineEnding + E.Message, mtError, [mbOK], 0);
      Result := False;
    end;
  end;
end;

procedure TEngineParamDialog.SetParams(const AParams: TEngineParamArray);
var
  I: Integer;
  J: Integer;
  Temp: TEngineParam;
begin
  SetLength(FParams, Length(AParams));
  for I := 0 to High(AParams) do
    FParams[I] := AParams[I];
  for I := 0 to High(FParams) - 1 do
    for J := I + 1 to High(FParams) do
      if CompareText(FParams[I].Name, FParams[J].Name) > 0 then
      begin
        Temp := FParams[I];
        FParams[I] := FParams[J];
        FParams[J] := Temp;
      end;
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
  IsScorePerspective: Boolean;
  Value: String;
begin
  IsBool := IsBoolRow(FSelectedRow);
  IsDir := IsDirRow(FSelectedRow);
  IsScorePerspective := IsScorePerspectiveRow(FSelectedRow);

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

  FScorePerspectiveCombo.Enabled := IsScorePerspective;
  if IsScorePerspective then
  begin
    Value := LowerCase(FGrid.Cells[2, FSelectedRow]);
    if Value = 'white' then
      FScorePerspectiveCombo.ItemIndex := 1
    else if Value = 'black' then
      FScorePerspectiveCombo.ItemIndex := 2
    else
      FScorePerspectiveCombo.ItemIndex := 0;
  end
  else
    FScorePerspectiveCombo.ItemIndex := -1;

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

function TEngineParamDialog.IsScorePerspectiveRow(ARow: Integer): Boolean;
begin
  Result := (ARow > 0) and (ARow < FGrid.RowCount) and
    SameText(FGrid.Cells[0, ARow], 'gui-score-perspective');
end;

procedure TEngineParamDialog.PrepareInlineComboForRow(ARow: Integer);
var
  Value: String;
begin
  FInlineBoolCombo.Items.Clear;
  if IsScorePerspectiveRow(ARow) then
  begin
    FInlineBoolCombo.Items.Add('side-to-move');
    FInlineBoolCombo.Items.Add('white');
    FInlineBoolCombo.Items.Add('black');
    Value := LowerCase(FGrid.Cells[2, ARow]);
    if Value = 'white' then
      FInlineBoolCombo.ItemIndex := 1
    else if Value = 'black' then
      FInlineBoolCombo.ItemIndex := 2
    else
      FInlineBoolCombo.ItemIndex := 0;
  end
  else
  begin
    FInlineBoolCombo.Items.Add('false');
    FInlineBoolCombo.Items.Add('true');
    if SameText(FGrid.Cells[2, ARow], 'true') then
      FInlineBoolCombo.ItemIndex := 1
    else
      FInlineBoolCombo.ItemIndex := 0;
  end;
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
