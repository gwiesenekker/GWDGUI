unit uEngineEditForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Dialogs, ExtCtrls, Forms, Graphics, Grids, StdCtrls,
  SysUtils, uDxpTestConnection, uEngineParamsJson, uEngineRegistry,
  uPlatformProcess;

type
  TEngineAcceptedEvent = procedure(Sender: TObject;
    AEngine: TExternalEngineDefinition; var AAccepted: Boolean) of object;

  TEngineEditForm = class(TForm)
  private
    FAcceptedEngine: TExternalEngineDefinition;
    FAcceptButton: TButton;
    FAllowHubIdAutoUpdate: Boolean;
    FArgsEdit: TEdit;
    FBrowseDialog: TOpenDialog;
    FAcceptingClose: Boolean;
    FCapturedParams: TEngineParamArray;
    FDirectoryDialog: TSelectDirectoryDialog;
    FDxpThread: TDxpTestConnectionThread;
    FDxpHostEdit: TEdit;
    FDxpIdEdit: TEdit;
    FDxpPortEdit: TEdit;
    FDxpRoleCombo: TComboBox;
    FExeEdit: TEdit;
    FHubIdEdit: TEdit;
    FInitMemo: TMemo;
    FKindCombo: TComboBox;
    FOnAccepted: TEngineAcceptedEvent;
    FParamsGrid: TStringGrid;
    FInlineParamCombo: TComboBox;
    FProcess: TPlatformProcess;
    FProcessPollTimer: TTimer;
    FSelectedParamRow: Integer;
    FStdoutMemo: TMemo;
    FTextBuffer: string;
    procedure AcceptClick(Sender: TObject);
    procedure ButtonPanelResize(Sender: TObject);
    procedure BrowseClick(Sender: TObject);
    procedure CancelClick(Sender: TObject);
    procedure CaptureHubLine(const ALine: string);
    procedure CloseRunningEngine;
    function CurrentEngineDefinition: TExternalEngineDefinition;
    procedure DxpLog(Sender: TObject; const AText: string);
    function FormatHubId(const AName, AVersion: string): string;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure HideInlineParamCombo(Sender: TObject);
    procedure InlineParamComboSelect(Sender: TObject);
    function IsBoolParamRow(ARow: Integer): Boolean;
    function IsDirParamRow(ARow: Integer): Boolean;
    function IsScorePerspectiveParamRow(ARow: Integer): Boolean;
    procedure KindChanged(Sender: TObject);
    procedure LaunchClick(Sender: TObject);
    procedure LoadParamsForExecutable;
    procedure LoadParamsGrid;
    procedure Log(const AText: string);
    procedure ParamsGridMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure ParamsGridSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
    procedure PrepareInlineParamComboForRow(ARow: Integer);
    procedure ProcessData(Sender: TObject; const AText: string);
    procedure ProcessPollTimer(Sender: TObject);
    procedure ReadForMs(AWaitMs: Integer);
    procedure SendHubParamsToProcess;
    procedure StopProcessFor(AEngine: TExternalEngineDefinition);
    procedure StoreParamsGrid;
    procedure UpdateFieldsFromParams;
    procedure UpdateKindFields;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure LoadEngine(AEngine: TExternalEngineDefinition);
    property OnAccepted: TEngineAcceptedEvent read FOnAccepted write FOnAccepted;
  end;

implementation

uses
  LCLType;

constructor TEngineEditForm.Create(AOwner: TComponent);
var
  LBrowseButton: TButton;
  LButtonPanel: TPanel;
  LCancelButton: TButton;
  LFieldsPanel: TPanel;
  LInitialEngine: TExternalEngineDefinition;
  LLabel: TLabel;
  LLaunchButton: TButton;
  LLeftPanel: TPanel;
  LParamsLabel: TLabel;
  LParamsPanel: TPanel;
  LParamsSplitter: TSplitter;
  LRightPanel: TPanel;
  LSplitter: TSplitter;
  LTop: Integer;
begin
  inherited Create(AOwner);

  Caption := 'Add engine';
  Position := poDesigned;
  Width := 860;
  Height := 620;
  Constraints.MinWidth := 700;
  Constraints.MinHeight := 480;
  OnClose := @FormClose;

  FProcess := TPlatformProcess.Create;
  FProcess.OnData := @ProcessData;
  FProcessPollTimer := TTimer.Create(Self);
  FProcessPollTimer.Enabled := False;
  FProcessPollTimer.Interval := 100;
  FProcessPollTimer.OnTimer := @ProcessPollTimer;
  FAcceptingClose := False;
  FAllowHubIdAutoUpdate := False;
  FSelectedParamRow := 0;
  FBrowseDialog := TOpenDialog.Create(Self);
  FBrowseDialog.Title := 'Select engine executable';
  {$IFDEF MSWINDOWS}
  FBrowseDialog.Filter := 'Executables (*.exe)|*.exe|All files (*.*)|*.*';
  FBrowseDialog.FilterIndex := 1;
  {$ELSE}
  FBrowseDialog.Filter := 'All files (*)|*';
  FBrowseDialog.FilterIndex := 1;
  {$ENDIF}
  FDirectoryDialog := TSelectDirectoryDialog.Create(Self);
  FDirectoryDialog.Title := 'Select parameter directory';

  LButtonPanel := TPanel.Create(Self);
  LButtonPanel.Parent := Self;
  LButtonPanel.Align := alBottom;
  LButtonPanel.Height := 46;
  LButtonPanel.BevelOuter := bvNone;
  LButtonPanel.BorderSpacing.Around := 6;
  LButtonPanel.OnResize := @ButtonPanelResize;

  LLaunchButton := TButton.Create(Self);
  LLaunchButton.Parent := LButtonPanel;
  LLaunchButton.SetBounds(0, 6, 130, 34);
  LLaunchButton.Anchors := [akLeft, akTop];
  LLaunchButton.Caption := 'Launch engine';
  LLaunchButton.OnClick := @LaunchClick;

  LCancelButton := TButton.Create(Self);
  LCancelButton.Parent := LButtonPanel;
  LCancelButton.SetBounds(LButtonPanel.ClientWidth - 90, 6, 90, 34);
  LCancelButton.Anchors := [akRight, akTop];
  LCancelButton.Caption := 'Cancel';
  LCancelButton.OnClick := @CancelClick;

  FAcceptButton := TButton.Create(Self);
  FAcceptButton.Parent := LButtonPanel;
  FAcceptButton.SetBounds((LButtonPanel.ClientWidth - 170) div 2, 6, 170, 34);
  FAcceptButton.Anchors := [akTop];
  FAcceptButton.Caption := 'Launched correctly';
  FAcceptButton.OnClick := @AcceptClick;

  LLeftPanel := TPanel.Create(Self);
  LLeftPanel.Parent := Self;
  LLeftPanel.Align := alLeft;
  LLeftPanel.Width := 360;
  LLeftPanel.Constraints.MinWidth := 320;
  LLeftPanel.BevelOuter := bvNone;
  LLeftPanel.BorderSpacing.Around := 8;

  LSplitter := TSplitter.Create(Self);
  LSplitter.Parent := Self;
  LSplitter.Align := alLeft;
  LSplitter.Width := 8;
  LSplitter.ResizeAnchor := akLeft;

  LRightPanel := TPanel.Create(Self);
  LRightPanel.Parent := Self;
  LRightPanel.Align := alClient;
  LRightPanel.BevelOuter := bvNone;
  LRightPanel.BorderSpacing.Around := 8;

  LFieldsPanel := LLeftPanel;
  LTop := 0;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LFieldsPanel;
  LLabel.SetBounds(0, LTop, 80, 22);
  LLabel.Caption := 'Executable';
  LLabel.Layout := tlCenter;

  LBrowseButton := TButton.Create(Self);
  LBrowseButton.Parent := LFieldsPanel;
  LBrowseButton.SetBounds(LFieldsPanel.Width - 82, LTop, 82, 28);
  LBrowseButton.Anchors := [akTop, akRight];
  LBrowseButton.Caption := 'Browse...';
  LBrowseButton.OnClick := @BrowseClick;

  FExeEdit := TEdit.Create(Self);
  FExeEdit.Parent := LFieldsPanel;
  FExeEdit.SetBounds(86, LTop, LFieldsPanel.Width - 176, 28);
  FExeEdit.Anchors := [akTop, akLeft, akRight];
  Inc(LTop, 36);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LFieldsPanel;
  LLabel.SetBounds(0, LTop, 80, 22);
  LLabel.Caption := 'Type';
  LLabel.Layout := tlCenter;

  FKindCombo := TComboBox.Create(Self);
  FKindCombo.Parent := LFieldsPanel;
  FKindCombo.SetBounds(86, LTop, 120, 28);
  FKindCombo.Style := csDropDownList;
  FKindCombo.Items.Add('hub');
  FKindCombo.Items.Add('DXP');
  FKindCombo.ItemIndex := 0;
  FKindCombo.OnChange := @KindChanged;
  Inc(LTop, 36);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LFieldsPanel;
  LLabel.SetBounds(0, LTop, 80, 22);
  LLabel.Caption := 'Hub id';
  LLabel.Layout := tlCenter;

  FHubIdEdit := TEdit.Create(Self);
  FHubIdEdit.Parent := LFieldsPanel;
  FHubIdEdit.SetBounds(86, LTop, LFieldsPanel.Width - 86, 28);
  FHubIdEdit.Anchors := [akTop, akLeft, akRight];
  Inc(LTop, 36);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LFieldsPanel;
  LLabel.SetBounds(0, LTop, 80, 22);
  LLabel.Caption := 'DXP id';
  LLabel.Layout := tlCenter;

  FDxpIdEdit := TEdit.Create(Self);
  FDxpIdEdit.Parent := LFieldsPanel;
  FDxpIdEdit.SetBounds(86, LTop, LFieldsPanel.Width - 86, 28);
  FDxpIdEdit.Anchors := [akTop, akLeft, akRight];
  Inc(LTop, 36);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LFieldsPanel;
  LLabel.SetBounds(0, LTop, 80, 22);
  LLabel.Caption := 'Host';
  LLabel.Layout := tlCenter;

  FDxpHostEdit := TEdit.Create(Self);
  FDxpHostEdit.Parent := LFieldsPanel;
  FDxpHostEdit.SetBounds(86, LTop, LFieldsPanel.Width - 86, 28);
  FDxpHostEdit.Anchors := [akTop, akLeft, akRight];
  FDxpHostEdit.Text := '127.0.0.1';
  Inc(LTop, 36);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LFieldsPanel;
  LLabel.SetBounds(0, LTop, 80, 22);
  LLabel.Caption := 'Port';
  LLabel.Layout := tlCenter;

  FDxpPortEdit := TEdit.Create(Self);
  FDxpPortEdit.Parent := LFieldsPanel;
  FDxpPortEdit.SetBounds(86, LTop, 90, 28);
  FDxpPortEdit.Text := '27531';

  FDxpRoleCombo := TComboBox.Create(Self);
  FDxpRoleCombo.Parent := LFieldsPanel;
  FDxpRoleCombo.SetBounds(186, LTop, LFieldsPanel.Width - 186, 28);
  FDxpRoleCombo.Anchors := [akTop, akLeft, akRight];
  FDxpRoleCombo.Style := csDropDownList;
  FDxpRoleCombo.Items.Add('listen');
  FDxpRoleCombo.Items.Add('connect');
  FDxpRoleCombo.ItemIndex := 0;
  Inc(LTop, 36);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LFieldsPanel;
  LLabel.SetBounds(0, LTop, 80, 22);
  LLabel.Caption := 'Arguments';
  LLabel.Layout := tlCenter;

  FArgsEdit := TEdit.Create(Self);
  FArgsEdit.Parent := LFieldsPanel;
  FArgsEdit.SetBounds(86, LTop, LFieldsPanel.Width - 86, 28);
  FArgsEdit.Anchors := [akTop, akLeft, akRight];
  Inc(LTop, 38);

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LFieldsPanel;
  LLabel.SetBounds(0, LTop, LFieldsPanel.Width, 22);
  LLabel.Anchors := [akTop, akLeft, akRight];
  LLabel.Caption := 'Edit init ({ip}, {host}, {port} are expanded)';
  LLabel.Layout := tlCenter;
  Inc(LTop, 24);

  FInitMemo := TMemo.Create(Self);
  FInitMemo.Parent := LFieldsPanel;
  FInitMemo.SetBounds(0, LTop, LFieldsPanel.Width, LFieldsPanel.Height - LTop);
  FInitMemo.Anchors := [akTop, akLeft, akRight, akBottom];
  FInitMemo.ScrollBars := ssAutoBoth;
  FInitMemo.WordWrap := False;
  FInitMemo.Text := 'init';

  FStdoutMemo := TMemo.Create(Self);
  FStdoutMemo.Parent := LRightPanel;
  FStdoutMemo.Align := alClient;
  FStdoutMemo.ReadOnly := True;
  FStdoutMemo.ScrollBars := ssAutoBoth;
  FStdoutMemo.WordWrap := False;

  LParamsPanel := TPanel.Create(Self);
  LParamsPanel.Parent := LRightPanel;
  LParamsPanel.Align := alBottom;
  LParamsPanel.Height := 230;
  LParamsPanel.Constraints.MinHeight := 140;
  LParamsPanel.BevelOuter := bvNone;

  LParamsSplitter := TSplitter.Create(Self);
  LParamsSplitter.Parent := LRightPanel;
  LParamsSplitter.Align := alBottom;
  LParamsSplitter.Height := 8;
  LParamsSplitter.ResizeAnchor := akBottom;

  LParamsLabel := TLabel.Create(Self);
  LParamsLabel.Parent := LParamsPanel;
  LParamsLabel.Align := alTop;
  LParamsLabel.Height := 22;
  LParamsLabel.Caption := 'Parameters';
  LParamsLabel.Layout := tlCenter;

  FParamsGrid := TStringGrid.Create(Self);
  FParamsGrid.Parent := LParamsPanel;
  FParamsGrid.Align := alClient;
  FParamsGrid.ColCount := 3;
  FParamsGrid.FixedRows := 1;
  FParamsGrid.Options := FParamsGrid.Options + [goEditing, goColSizing];
  FParamsGrid.OnMouseUp := @ParamsGridMouseUp;
  FParamsGrid.OnSelectCell := @ParamsGridSelectCell;
  FParamsGrid.Cells[0, 0] := 'name';
  FParamsGrid.Cells[1, 0] := 'type';
  FParamsGrid.Cells[2, 0] := 'value';
  FParamsGrid.ColWidths[0] := 260;
  FParamsGrid.ColWidths[1] := 90;
  FParamsGrid.ColWidths[2] := 260;

  FInlineParamCombo := TComboBox.Create(Self);
  FInlineParamCombo.Parent := FParamsGrid;
  FInlineParamCombo.Visible := False;
  FInlineParamCombo.Style := csDropDownList;
  FInlineParamCombo.OnSelect := @InlineParamComboSelect;
  FInlineParamCombo.OnCloseUp := @HideInlineParamCombo;
  FInlineParamCombo.OnExit := @HideInlineParamCombo;

  LInitialEngine := CurrentEngineDefinition;
  try
    SeedDefaultGuiParams(FCapturedParams, LInitialEngine);
  finally
    LInitialEngine.Free;
  end;
  LoadParamsGrid;
  UpdateKindFields;
end;

destructor TEngineEditForm.Destroy;
begin
  CloseRunningEngine;
  FAcceptedEngine.Free;
  FProcess.Free;
  inherited Destroy;
end;

procedure TEngineEditForm.LoadEngine(AEngine: TExternalEngineDefinition);
var
  Engine: TExternalEngineDefinition;
begin
  CloseRunningEngine;
  FStdoutMemo.Clear;
  FTextBuffer := '';
  SetLength(FCapturedParams, 0);

  if AEngine = nil then
  begin
    Caption := 'Add engine';
    FExeEdit.Text := '';
    FKindCombo.ItemIndex := 0;
    FHubIdEdit.Text := '';
    FDxpIdEdit.Text := '';
    FDxpHostEdit.Text := '127.0.0.1';
    FDxpPortEdit.Text := '27531';
    FDxpRoleCombo.ItemIndex := 0;
    FArgsEdit.Text := '';
    FInitMemo.Text := 'init';
  end
  else
  begin
    Caption := 'Edit engine';
    FExeEdit.Text := AEngine.ExePath;
    if AEngine.Kind = eekDxp then
      FKindCombo.ItemIndex := 1
    else
      FKindCombo.ItemIndex := 0;
    FHubIdEdit.Text := AEngine.HubId;
    FDxpIdEdit.Text := AEngine.DxpId;
    FArgsEdit.Text := AEngine.Arguments;
    FInitMemo.Text := AEngine.InitText;
    FDXpHostEdit.Text := AEngine.DxpHost;
    FDxpPortEdit.Text := IntToStr(AEngine.DxpPort);
    if AEngine.DxpRole = derConnect then
      FDxpRoleCombo.ItemIndex := 1
    else
      FDxpRoleCombo.ItemIndex := 0;
  end;

  Engine := CurrentEngineDefinition;
  try
    SeedDefaultGuiParams(FCapturedParams, Engine);
  finally
    Engine.Free;
  end;
  LoadParamsForExecutable;
  LoadParamsGrid;
  UpdateKindFields;
end;

procedure TEngineEditForm.AcceptClick(Sender: TObject);
var
  Accepted: Boolean;
begin
  StoreParamsGrid;
  FreeAndNil(FAcceptedEngine);
  FAcceptedEngine := CurrentEngineDefinition;
  Accepted := True;
  if Assigned(FOnAccepted) then
    FOnAccepted(Self, FAcceptedEngine, Accepted);
  if not Accepted then
    Exit;

  SaveEngineDefinitionParams(FAcceptedEngine, FCapturedParams);
  Log('[saved parameters to ' + EngineParamsFileName(FAcceptedEngine.ExePath) + ']');
  FAcceptingClose := True;
  CloseRunningEngine;
  Close;
  FAcceptingClose := False;
end;

procedure TEngineEditForm.ButtonPanelResize(Sender: TObject);
begin
  if FAcceptButton <> nil then
  begin
    FAcceptButton.Left := (TWinControl(Sender).ClientWidth -
      FAcceptButton.Width) div 2;
    if FAcceptButton.Left < 0 then
      FAcceptButton.Left := 0;
    FAcceptButton.Top := (TWinControl(Sender).ClientHeight -
      FAcceptButton.Height) div 2;
    if FAcceptButton.Top < 0 then
      FAcceptButton.Top := 0;
  end;
end;

procedure TEngineEditForm.BrowseClick(Sender: TObject);
begin
  if FBrowseDialog.Execute then
  begin
    FExeEdit.Text := FBrowseDialog.FileName;
    LoadParamsForExecutable;
    LoadParamsGrid;
    UpdateKindFields;
  end;
end;

procedure TEngineEditForm.CancelClick(Sender: TObject);
begin
  Close;
end;

procedure TEngineEditForm.CaptureHubLine(const ALine: string);
var
  LowerLine: string;
  HubIdText: string;
  NameText: string;
  TypeText: string;
  ValueText: string;
  VersionText: string;
begin
  LowerLine := LowerCase(Trim(ALine));
  if Copy(LowerLine, 1, 6) = 'param ' then
  begin
    NameText := ExtractHubArgument(ALine, 'name');
    TypeText := ExtractHubArgument(ALine, 'type');
    ValueText := ExtractHubArgument(ALine, 'value');
    if ValueText = '' then
      ValueText := ExtractHubArgument(ALine, 'default');
    AddOrUpdateParam(FCapturedParams, NameText, TypeText, ValueText, True);
    LoadParamsGrid;
  end
  else if (Copy(LowerLine, 1, 3) = 'id ') or
    (Copy(LowerLine, 1, 3) = 'id=') then
  begin
    NameText := ExtractHubArgument(ALine, 'name');
    VersionText := ExtractHubArgument(ALine, 'version');
    if (NameText = '') and (Copy(LowerLine, 1, 3) = 'id=') then
      NameText := Trim(Copy(ALine, 4, Length(ALine)));
    if (NameText = '') and (Copy(LowerLine, 1, 3) = 'id ') then
      NameText := Trim(Copy(ALine, 4, Length(ALine)));
    if (Length(NameText) >= 2) and (NameText[1] = '"') and
      (NameText[Length(NameText)] = '"') then
      NameText := Copy(NameText, 2, Length(NameText) - 2);
    HubIdText := FormatHubId(NameText, VersionText);
    if HubIdText <> '' then
      Log('[engine reports Hub id: ' + HubIdText + ']');
  end;
end;

procedure TEngineEditForm.CloseRunningEngine;
begin
  if FProcessPollTimer <> nil then
    FProcessPollTimer.Enabled := False;

  if FDxpThread <> nil then
  begin
    FDxpThread.StopConnection;
    FDxpThread.WaitFor;
    FreeAndNil(FDxpThread);
  end;

  if FProcess = nil then
    Exit;
  if FKindCombo.ItemIndex = 0 then
    FProcess.RequestQuit('quit', 800);
  if FProcess.IsRunning then
  begin
    Log('[process did not stop cleanly; terminating]');
    FProcess.Terminate(1000);
  end;
  FProcess.Close;
end;

function TEngineEditForm.CurrentEngineDefinition: TExternalEngineDefinition;
begin
  Result := TExternalEngineDefinition.Create;
  Result.ExePath := Trim(FExeEdit.Text);
  Result.ExecutableName := ExtractFileName(Result.ExePath);
  if FKindCombo.ItemIndex = 1 then
    Result.Kind := eekDxp
  else
    Result.Kind := eekHub;
  Result.HubId := Trim(FHubIdEdit.Text);
  Result.DxpId := Trim(FDxpIdEdit.Text);
  Result.DxpHost := Trim(FDxpHostEdit.Text);
  if Result.DxpHost = '' then
    Result.DxpHost := '127.0.0.1';
  Result.DxpPort := StrToIntDef(Trim(FDxpPortEdit.Text), 27531);
  if FDxpRoleCombo.ItemIndex = 1 then
    Result.DxpRole := derConnect
  else
    Result.DxpRole := derListen;
  Result.Arguments := Trim(FArgsEdit.Text);
  Result.InitText := FInitMemo.Text;
  Result.NormalizeIds;
end;

procedure TEngineEditForm.DxpLog(Sender: TObject; const AText: string);
begin
  Log(AText);
end;

function TEngineEditForm.FormatHubId(const AName, AVersion: string): string;
begin
  Result := Trim(AName);
  if (Result <> '') and (Trim(AVersion) <> '') then
    Result := Result + '_' + Trim(AVersion);
end;

procedure TEngineEditForm.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  if not FAcceptingClose then
    CloseRunningEngine;
end;

procedure TEngineEditForm.KindChanged(Sender: TObject);
var
  Engine: TExternalEngineDefinition;
begin
  StoreParamsGrid;
  Engine := CurrentEngineDefinition;
  try
    SeedDefaultGuiParams(FCapturedParams, Engine);
  finally
    Engine.Free;
  end;
  LoadParamsGrid;
  UpdateKindFields;
end;

procedure TEngineEditForm.HideInlineParamCombo(Sender: TObject);
begin
  FInlineParamCombo.Visible := False;
end;

procedure TEngineEditForm.InlineParamComboSelect(Sender: TObject);
begin
  if FInlineParamCombo.Visible and
    (FSelectedParamRow > 0) and
    (FSelectedParamRow < FParamsGrid.RowCount) and
    (IsBoolParamRow(FSelectedParamRow) or
    IsScorePerspectiveParamRow(FSelectedParamRow)) and
    (FInlineParamCombo.ItemIndex >= 0) then
    FParamsGrid.Cells[2, FSelectedParamRow] := FInlineParamCombo.Text;
end;

function TEngineEditForm.IsBoolParamRow(ARow: Integer): Boolean;
begin
  Result := (FParamsGrid <> nil) and (ARow > 0) and
    (ARow < FParamsGrid.RowCount) and
    SameText(FParamsGrid.Cells[1, ARow], 'bool');
end;

function TEngineEditForm.IsDirParamRow(ARow: Integer): Boolean;
var
  ParamName: string;
begin
  Result := False;
  if (FParamsGrid = nil) or (ARow <= 0) or
    (ARow >= FParamsGrid.RowCount) then
    Exit;

  ParamName := LowerCase(FParamsGrid.Cells[0, ARow]);
  Result := (Pos('dir', ParamName) > 0) or
    (Copy(ParamName, Length(ParamName) - 3, 4) = '-dir') or
    (Copy(ParamName, Length(ParamName) - 4, 5) = '-path');
end;

function TEngineEditForm.IsScorePerspectiveParamRow(ARow: Integer): Boolean;
begin
  Result := (FParamsGrid <> nil) and (ARow > 0) and
    (ARow < FParamsGrid.RowCount) and
    SameText(FParamsGrid.Cells[0, ARow], 'gui-score-perspective');
end;

procedure TEngineEditForm.LaunchClick(Sender: TObject);
var
  Args: TStringList;
  Engine: TExternalEngineDefinition;
  I: Integer;
  InitLines: TStringList;
begin
  Engine := CurrentEngineDefinition;
  Args := TStringList.Create;
  InitLines := TStringList.Create;
  try
    FStdoutMemo.Clear;
    FTextBuffer := '';
    StoreParamsGrid;
    FAllowHubIdAutoUpdate := False;
    StopProcessFor(Engine);

    if Engine.ExePath = '' then
    begin
      Log('[no executable selected]');
      Exit;
    end;
    if not FileExists(Engine.ExePath) then
    begin
      Log('[executable does not exist: ' + Engine.ExePath + ']');
      Exit;
    end;

    SplitLaunchArguments(ExpandEnginePlaceholders(Engine.Arguments, Engine), Args);
    Log('[launching ' + Engine.ExePath + ']');
    if Args.Count > 0 then
      Log('[arguments: ' + Args.DelimitedText + ']');
    FProcess.Start(Engine.ExePath, Args, ExtractFilePath(Engine.ExePath));
    FProcessPollTimer.Enabled := True;
    ReadForMs(250);

    if Engine.Kind = eekHub then
    begin
      Log('> hub');
      FProcess.WriteLine('hub');
      ReadForMs(1000);

      SendHubParamsToProcess;

      InitLines.Text := ExpandEnginePlaceholders(Engine.InitText, Engine);
      for I := 0 to InitLines.Count - 1 do
        if Trim(InitLines[I]) <> '' then
        begin
          Log('> ' + InitLines[I]);
          FProcess.WriteLine(InitLines[I]);
        end;
      ReadForMs(2500);
      if Trim(FHubIdEdit.Text) = '' then
        FHubIdEdit.Text := ExtractFileName(Engine.ExePath);
      FAllowHubIdAutoUpdate := False;
      Log('[hub launch test finished; verify ready/parameter lines above]');
    end
    else
    begin
      if Engine.DxpRole = derListen then
        Log('[DXP configured as listener on ' + Engine.DxpHost + ':' +
          IntToStr(Engine.DxpPort) + ']')
      else
        Log('[DXP configured to connect to ' + Engine.DxpHost + ':' +
          IntToStr(Engine.DxpPort) + ']');
      FreeAndNil(FDxpThread);
      FDxpThread := TDxpTestConnectionThread.Create(Engine.DxpHost,
        Engine.DxpPort, Engine.DxpRole, @DxpLog);
      if Trim(FDxpIdEdit.Text) = '' then
        FDxpIdEdit.Text := ExtractFileName(Engine.ExePath);
      ReadForMs(1000);
    end;
  finally
    FAllowHubIdAutoUpdate := False;
    InitLines.Free;
    Args.Free;
    Engine.Free;
  end;
end;

procedure TEngineEditForm.LoadParamsForExecutable;
var
  Engine: TExternalEngineDefinition;
  ParamsFileName: string;
  Section: string;
begin
  ParamsFileName := EngineParamsFileName(Trim(FExeEdit.Text));
  if ParamsFileName = '' then
    Exit;

  if FKindCombo.ItemIndex = 1 then
    Section := 'dxp'
  else
    Section := 'hub';

  SetLength(FCapturedParams, 0);
  LoadEngineParamsFromJson(ParamsFileName, Section, FCapturedParams);
  if Length(FCapturedParams) = 0 then
  begin
    if Section = 'hub' then
      Section := 'dxp'
    else
      Section := 'hub';
    LoadEngineParamsFromJson(ParamsFileName, Section, FCapturedParams);
  end;

  UpdateFieldsFromParams;
  Engine := CurrentEngineDefinition;
  try
    SeedDefaultGuiParams(FCapturedParams, Engine);
  finally
    Engine.Free;
  end;
end;

procedure TEngineEditForm.LoadParamsGrid;
var
  I: Integer;
begin
  if FParamsGrid = nil then
    Exit;

  SortEngineParams(FCapturedParams);
  FParamsGrid.RowCount := Length(FCapturedParams) + 1;
  for I := 0 to High(FCapturedParams) do
  begin
    FParamsGrid.Cells[0, I + 1] := FCapturedParams[I].Name;
    FParamsGrid.Cells[1, I + 1] := FCapturedParams[I].ParamType;
    FParamsGrid.Cells[2, I + 1] := FCapturedParams[I].Value;
  end;
end;

procedure TEngineEditForm.UpdateFieldsFromParams;
var
  Value: string;
begin
  Value := LowerCase(Trim(EngineParamValue(FCapturedParams,
    'gui-engine-type', '')));
  if Value = 'dxp' then
    FKindCombo.ItemIndex := 1
  else if Value = 'hub' then
    FKindCombo.ItemIndex := 0;

  FHubIdEdit.Text := EngineParamValue(FCapturedParams, 'gui-hub-id',
    FHubIdEdit.Text);
  FDxpIdEdit.Text := EngineParamValue(FCapturedParams, 'gui-dxp-id',
    FDxpIdEdit.Text);
  FDxpHostEdit.Text := EngineParamValue(FCapturedParams, 'gui-dxp-ip',
    FDxpHostEdit.Text);
  FDxpPortEdit.Text := EngineParamValue(FCapturedParams, 'gui-dxp-socket',
    FDxpPortEdit.Text);

  Value := LowerCase(Trim(EngineParamValue(FCapturedParams, 'gui-dxp-role',
    '')));
  if Value = 'connect' then
    FDxpRoleCombo.ItemIndex := 1
  else if Value = 'listen' then
    FDxpRoleCombo.ItemIndex := 0;

  if FKindCombo.ItemIndex = 1 then
    FArgsEdit.Text := EngineParamValue(FCapturedParams,
      'gui-dxp-launch-arguments', FArgsEdit.Text)
  else
    FArgsEdit.Text := EngineParamValue(FCapturedParams,
      'gui-hub-launch-argument', FArgsEdit.Text);
  FInitMemo.Text := EngineParamValue(FCapturedParams, 'gui-hub-init',
    FInitMemo.Text);
end;

procedure TEngineEditForm.Log(const AText: string);
begin
  FStdoutMemo.Lines.Add(AText);
  FStdoutMemo.SelStart := Length(FStdoutMemo.Text);
end;

procedure TEngineEditForm.ParamsGridMouseUp(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  CellRect: TRect;
  Col: LongInt;
  Row: LongInt;
begin
  if Button <> mbLeft then
    Exit;

  FParamsGrid.MouseToCell(X, Y, Col, Row);
  if (Row <= 0) or (Row >= FParamsGrid.RowCount) then
    Exit;

  FSelectedParamRow := Row;
  if (Col = 2) and
    (IsBoolParamRow(Row) or IsScorePerspectiveParamRow(Row)) then
  begin
    PrepareInlineParamComboForRow(Row);
    CellRect := FParamsGrid.CellRect(Col, Row);
    FInlineParamCombo.SetBounds(CellRect.Left, CellRect.Top,
      CellRect.Right - CellRect.Left, CellRect.Bottom - CellRect.Top);
    FInlineParamCombo.Visible := True;
    FInlineParamCombo.BringToFront;
    FInlineParamCombo.SetFocus;
    FInlineParamCombo.DroppedDown := True;
  end
  else if ((Col = 0) or (Col = 2)) and IsDirParamRow(Row) then
  begin
    FInlineParamCombo.Visible := False;
    FDirectoryDialog.InitialDir := FParamsGrid.Cells[2, Row];
    if FDirectoryDialog.Execute then
      FParamsGrid.Cells[2, Row] := FDirectoryDialog.FileName;
  end
  else
    FInlineParamCombo.Visible := False;
end;

procedure TEngineEditForm.ParamsGridSelectCell(Sender: TObject; aCol,
  aRow: Integer; var CanSelect: Boolean);
begin
  FSelectedParamRow := aRow;
  if (aCol <> 2) or
    not (IsBoolParamRow(aRow) or IsScorePerspectiveParamRow(aRow)) then
    FInlineParamCombo.Visible := False;
end;

procedure TEngineEditForm.PrepareInlineParamComboForRow(ARow: Integer);
var
  Value: string;
begin
  FInlineParamCombo.Items.Clear;
  if IsScorePerspectiveParamRow(ARow) then
  begin
    FInlineParamCombo.Items.Add('side-to-move');
    FInlineParamCombo.Items.Add('white');
    FInlineParamCombo.Items.Add('black');
    Value := LowerCase(FParamsGrid.Cells[2, ARow]);
    if Value = 'white' then
      FInlineParamCombo.ItemIndex := 1
    else if Value = 'black' then
      FInlineParamCombo.ItemIndex := 2
    else
      FInlineParamCombo.ItemIndex := 0;
  end
  else
  begin
    FInlineParamCombo.Items.Add('false');
    FInlineParamCombo.Items.Add('true');
    if SameText(FParamsGrid.Cells[2, ARow], 'true') then
      FInlineParamCombo.ItemIndex := 1
    else
      FInlineParamCombo.ItemIndex := 0;
  end;
end;

procedure TEngineEditForm.ProcessData(Sender: TObject; const AText: string);
var
  DelimiterLength: Integer;
  Line: string;
  LineEnd: Integer;
begin
  FStdoutMemo.Text := FStdoutMemo.Text + AText;
  FStdoutMemo.SelStart := Length(FStdoutMemo.Text);
  FTextBuffer += AText;

  while True do
  begin
    DelimiterLength := Length(LineEnding);
    LineEnd := Pos(LineEnding, FTextBuffer);
    if LineEnd = 0 then
    begin
      LineEnd := Pos(#10, FTextBuffer);
      DelimiterLength := 1;
    end;
    if LineEnd = 0 then
      Break;

    Line := Trim(Copy(FTextBuffer, 1, LineEnd - 1));
    Delete(FTextBuffer, 1, LineEnd + DelimiterLength - 1);
    CaptureHubLine(Line);
  end;
end;

procedure TEngineEditForm.ProcessPollTimer(Sender: TObject);
begin
  if FProcess = nil then
    Exit;
  if FProcess.NeedsPolling then
    FProcess.ReadAvailable;
  if FProcess.HasProcess and (not FProcess.IsRunning) then
  begin
    if FProcess.NeedsPolling then
      FProcess.ReadAvailable;
    FProcessPollTimer.Enabled := False;
  end;
end;

procedure TEngineEditForm.ReadForMs(AWaitMs: Integer);
var
  UntilTick: QWord;
begin
  UntilTick := GetTickCount64 + QWord(AWaitMs);
  repeat
    if FProcess.NeedsPolling then
      FProcess.ReadAvailable;
    Application.ProcessMessages;
    Sleep(25);
  until GetTickCount64 >= UntilTick;
  if FProcess.NeedsPolling then
    FProcess.ReadAvailable;
end;

procedure TEngineEditForm.SendHubParamsToProcess;
var
  Command: string;
  I: Integer;
begin
  for I := 0 to High(FCapturedParams) do
  begin
    if not EngineParamShouldSendToHub(FCapturedParams[I].Name) then
      Continue;
    Command := 'set-param name=' + HubParamQuote(FCapturedParams[I].Name) +
      ' value=' + HubParamQuote(FCapturedParams[I].Value);
    Log('> ' + Command);
    FProcess.WriteLine(Command);
  end;
end;

procedure TEngineEditForm.StopProcessFor(AEngine: TExternalEngineDefinition);
begin
  if FProcess = nil then
    Exit;

  if FProcessPollTimer <> nil then
    FProcessPollTimer.Enabled := False;

  if FDxpThread <> nil then
  begin
    Log('[closing previous DXP socket test]');
    FDxpThread.StopConnection;
    FDxpThread.WaitFor;
    FreeAndNil(FDxpThread);
  end;

  if not FProcess.HasProcess then
    Exit;

  if (AEngine <> nil) and (AEngine.Kind = eekHub) then
  begin
    Log('[stopping previous hub process with quit]');
    FProcess.RequestQuit('quit', 800);
  end
  else
    Log('[closing previous DXP/process test]');

  if FProcess.IsRunning then
  begin
    Log('[previous process still running; terminating]');
    FProcess.Terminate(1000);
  end;
  FProcess.Close;
end;

procedure TEngineEditForm.StoreParamsGrid;
var
  I: Integer;
  Row: Integer;
begin
  if FParamsGrid = nil then
    Exit;

  if FInlineParamCombo.Visible then
    InlineParamComboSelect(nil);
  FInlineParamCombo.Visible := False;
  SetLength(FCapturedParams, 0);
  for Row := 1 to FParamsGrid.RowCount - 1 do
  begin
    if Trim(FParamsGrid.Cells[0, Row]) = '' then
      Continue;
    I := Length(FCapturedParams);
    SetLength(FCapturedParams, I + 1);
    FCapturedParams[I].Name := Trim(FParamsGrid.Cells[0, Row]);
    FCapturedParams[I].ParamType := Trim(FParamsGrid.Cells[1, Row]);
    FCapturedParams[I].Value := FParamsGrid.Cells[2, Row];
  end;
end;

procedure TEngineEditForm.UpdateKindFields;
var
  IsDxp: Boolean;
begin
  IsDxp := FKindCombo.ItemIndex = 1;
  FHubIdEdit.Enabled := not IsDxp;
  FDxpIdEdit.Enabled := IsDxp;
  FDxpHostEdit.Enabled := IsDxp;
  FDxpPortEdit.Enabled := IsDxp;
  FDxpRoleCombo.Enabled := IsDxp;
end;

end.
