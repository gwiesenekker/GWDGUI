unit uTournamentDialog;

{$mode objfpc}{$H+}

interface

uses
  CheckLst, Classes, Controls, ExtCtrls, Forms, Grids, StdCtrls, SysUtils,
  Menus, SyncObjs, Types, uEngineRegistry, uGameSetupForm;

type
  TTournamentRunningGame = class
  public
    Active: Boolean;
    GameId: Integer;
    PdnSaved: Boolean;
    Row: Integer;
  end;

  TTournamentStartGameEvent = procedure(Sender: TObject; const ASetup: TGameSetup;
    const ATitlePrefix: string; out AGame: TObject) of object;
  TTournamentSelectGameEvent = procedure(Sender: TObject; AGame: TObject) of object;

  TTournamentDialog = class(TForm)
  private
    FAcceptedTournamentSignature: string;
    FBlackEngines: TStringList;
    FClosing: Boolean;
    FCrossTableGrid: TStringGrid;
    FEngineCheckList: TCheckListBox;
    FEngines: TExternalEngineList;
    FFileName: string;
    FGrid: TStringGrid;
    FConcurrentGamesEdit: TEdit;
    FIncrementEdit: TEdit;
    FIncrementModeCombo: TComboBox;
    FInvalidationPanel: TPanel;
    FLoadingTournament: Boolean;
    FLastGameStartTick: QWord;
    FMinutesEdit: TEdit;
    FMovesEdit: TEdit;
    FOnSelectGame: TTournamentSelectGameEvent;
    FOnStartGame: TTournamentStartGameEvent;
    FPdnWriteLock: TCriticalSection;
    FRoundRobinGroup: TRadioGroup;
    FRunning: Boolean;
    FRunningGames: TList;
    FStartStopButton: TButton;
    FStartingFENEdit: TEdit;
    FTimer: TTimer;
    FTournamentNameEdit: TEdit;
    FWhiteEngines: TStringList;
    procedure AddLabelledEdit(AParent: TWinControl; const ACaption: string;
      AEdit: TEdit; var ATop: Integer);
    procedure AdjustPairingGridColumnWidths;
    procedure ApplyInvalidatingChange(Sender: TObject);
    procedure AppendTournamentGameToPdn(ARunningGame: TTournamentRunningGame;
      AGame: TObject);
    procedure ClearPairingsClick(Sender: TObject);
    procedure ClearStaleRunningReasons;
    procedure ClearTournamentGameRefs;
    procedure CollectPairingRows(AWhiteEngines, ABlackEngines,
      AResults: TStrings);
    procedure CollectRoundRows(ARounds: TStrings);
    procedure CollectSelectedEngines(AEngines: TStrings);
    procedure ConfigurePairingGridColumns;
    procedure CreatePairingClick(Sender: TObject);
    function DisplayNameForEngine(AEngine: TExternalEngineDefinition): string;
    function EngineByDisplayName(const AName: string): TExternalEngineDefinition;
    function EngineKeyForName(const AName: string): string;
    function ActiveRunningGameCount: Integer;
    function FindNextUnplayedRow: Integer;
    function FindTournamentGameByRow(ARow: Integer): TTournamentRunningGame;
    function GameSetupForRow(ARow: Integer; out ASetup: TGameSetup): Boolean;
    function HasNonByeResults: Boolean;
    function MaxConcurrentGames: Integer;
    procedure HighlightRow(ARow: Integer);
    procedure InvalidateTournamentResults(Sender: TObject);
    function IsRowRunning(ARow: Integer): Boolean;
    function IsRowStartable(ARow: Integer; ABusyEngineKeys: TStrings): Boolean;
    procedure LoadClick(Sender: TObject);
    procedure LoadTournamentFromFile(const AFileName: string);
    function PdnFileName: string;
    function PendingInvalidatingChange: Boolean;
    procedure PairingGridDrawCell(Sender: TObject; ACol, ARow: Integer;
      Rect: TRect; State: TGridDrawState);
    procedure PairingGridMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure PopulateEngines;
    procedure RescheduleSelectedGame(Sender: TObject);
    procedure RevertInvalidatingChange(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure SaveTournamentToFile(const AFileName: string);
    procedure SetSelectedResult(const AResultText: string);
    procedure SetSelectedResultClick(Sender: TObject);
    procedure StartStopClick(Sender: TObject);
    procedure StartPendingGames;
    procedure StopRunningGames;
    procedure TimerTick(Sender: TObject);
    function TournamentSignature: string;
    procedure UpdateButtons;
    procedure UpdateCrossTable;
  public
    procedure BeginShutdown;
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure GameStopped(AGame: TObject);
    function HasTournamentData: Boolean;
    function IsRunning: Boolean;
    function SaveTournamentWithDialog: Boolean;
    property OnSelectGame: TTournamentSelectGameEvent read FOnSelectGame write FOnSelectGame;
    property OnStartGame: TTournamentStartGameEvent read FOnStartGame write FOnStartGame;
  end;

implementation

uses
  Dialogs, FPJSON, Graphics, JSONParser, Math, uGameOrchestrator,
  uGuiDialogs, uMainForm, uTournamentGridModel, uTournamentModel,
  uTournamentPairing, uTournamentResults, uTournamentTypes;

procedure DrawGridText(AGrid: TStringGrid; ACol, ARow: Integer;
  const ARect: TRect);
var
  TextRect: TRect;
begin
  AGrid.Canvas.FillRect(ARect);
  TextRect := ARect;
  InflateRect(TextRect, -4, -2);
  AGrid.Canvas.TextRect(TextRect, TextRect.Left,
    TextRect.Top + Max(0, (TextRect.Height -
    AGrid.Canvas.TextHeight(AGrid.Cells[ACol, ARow])) div 2),
    AGrid.Cells[ACol, ARow]);
end;

function TournamentReasonIsTransient(const AReason: string): Boolean;
begin
  Result := SameText(Trim(AReason), 'Running') or
    SameText(Trim(AReason), 'Stopping');
end;

const
  TournamentLaunchStaggerMs = 1000;

procedure ApplyTournamentGameResultToRow(AGrid: TStringGrid; ARow: Integer;
  AGame: TRunningGame);
var
  ResultText: string;
begin
  if (AGrid = nil) or (AGame = nil) or (ARow <= 0) or
    (ARow >= AGrid.RowCount) then
    Exit;

  ResultText := AGame.ResultText;
  AGrid.Cells[TournamentColResult, ARow] := ResultText;
  if AGame.State = gosError then
    AGrid.Cells[TournamentColReason, ARow] := AGame.LastErrorText
  else if ResultText = '*' then
    AGrid.Cells[TournamentColReason, ARow] := 'Unknown result'
  else if ResultText = '1-1' then
    AGrid.Cells[TournamentColReason, ARow] := 'Draw'
  else
    AGrid.Cells[TournamentColReason, ARow] := 'Game finished';
end;

function TournamentRunningGameFor(AOwner: TComponent;
  ARunningGame: TTournamentRunningGame): TRunningGame;
begin
  Result := nil;
  if (ARunningGame = nil) or not (AOwner is TMainForm) then
    Exit;
  Result := TMainForm(AOwner).FindGameById(ARunningGame.GameId);
end;

function SafeFileNameText(const AText: string): string;
var
  I: Integer;
begin
  Result := Trim(AText);
  if Result = '' then
    Result := 'Tournament';
  for I := 1 to Length(Result) do
    if Result[I] in ['/', '\', ':', '*', '?', '"', '<', '>', '|'] then
      Result[I] := '_';
end;

constructor TTournamentDialog.Create(AOwner: TComponent);
var
  ButtonPanel: TPanel;
  ContentPanel: TPanel;
  CreateButton: TButton;
  ClearButton: TButton;
  CrossTablePanel: TPanel;
  EnginePanel: TPanel;
  GridPanel: TPanel;
  LabelControl: TLabel;
  LoadButton: TButton;
  PairingPanel: TPanel;
  PairingPopup: TPopupMenu;
  PanelButton: TButton;
  PanelLabel: TLabel;
  PopupItem: TMenuItem;
  SaveButton: TButton;
  Splitter: TSplitter;
  TopPos: Integer;
begin
  inherited Create(AOwner);

  Caption := 'Tournament';
  Position := poDesigned;
  Width := 980;
  Height := 680;
  Constraints.MinWidth := 760;
  Constraints.MinHeight := 520;

  FWhiteEngines := TStringList.Create;
  FBlackEngines := TStringList.Create;
  FEngines := TExternalEngineList.Create;
  FRunningGames := TList.Create;
  FPdnWriteLock := TCriticalSection.Create;

  ButtonPanel := TPanel.Create(Self);
  ButtonPanel.Parent := Self;
  ButtonPanel.Align := alTop;
  ButtonPanel.Height := 180;
  ButtonPanel.BevelOuter := bvNone;
  ButtonPanel.BorderSpacing.Around := 8;

  TopPos := 4;
  FTournamentNameEdit := TEdit.Create(Self);
  FTournamentNameEdit.Text := 'Tournament';
  AddLabelledEdit(ButtonPanel, 'Tournament name', FTournamentNameEdit, TopPos);

  FStartingFENEdit := TEdit.Create(Self);
  FStartingFENEdit.Text := 'W:W31-50:B1-20';
  FStartingFENEdit.OnChange := @InvalidateTournamentResults;
  AddLabelledEdit(ButtonPanel, 'Starting FEN', FStartingFENEdit, TopPos);

  FMovesEdit := TEdit.Create(Self);
  FMovesEdit.Text := '75';
  FMovesEdit.OnChange := @InvalidateTournamentResults;
  FMovesEdit.SetBounds(0, 132, 86, 24);
  FMovesEdit.Parent := ButtonPanel;
  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := ButtonPanel;
  LabelControl.SetBounds(0, 114, 86, 18);
  LabelControl.Caption := 'Moves';

  FMinutesEdit := TEdit.Create(Self);
  FMinutesEdit.Text := '5';
  FMinutesEdit.OnChange := @InvalidateTournamentResults;
  FMinutesEdit.SetBounds(96, 132, 86, 24);
  FMinutesEdit.Parent := ButtonPanel;
  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := ButtonPanel;
  LabelControl.SetBounds(96, 114, 86, 18);
  LabelControl.Caption := 'Time';

  FIncrementEdit := TEdit.Create(Self);
  FIncrementEdit.Text := '0';
  FIncrementEdit.OnChange := @InvalidateTournamentResults;
  FIncrementEdit.SetBounds(192, 132, 86, 24);
  FIncrementEdit.Parent := ButtonPanel;
  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := ButtonPanel;
  LabelControl.SetBounds(192, 114, 86, 18);
  LabelControl.Caption := 'Increment';

  FIncrementModeCombo := TComboBox.Create(Self);
  FIncrementModeCombo.Parent := ButtonPanel;
  FIncrementModeCombo.SetBounds(288, 132, 140, 24);
  FIncrementModeCombo.Style := csDropDownList;
  FIncrementModeCombo.Items.Add('From start');
  FIncrementModeCombo.Items.Add('After move limit');
  FIncrementModeCombo.ItemIndex := 0;
  FIncrementModeCombo.OnChange := @InvalidateTournamentResults;

  FConcurrentGamesEdit := TEdit.Create(Self);
  FConcurrentGamesEdit.Text := '1';
  FConcurrentGamesEdit.SetBounds(640, 98, 120, 24);
  FConcurrentGamesEdit.Parent := ButtonPanel;
  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := ButtonPanel;
  LabelControl.SetBounds(640, 82, 120, 18);
  LabelControl.Caption := 'Concurrent games';

  FRoundRobinGroup := TRadioGroup.Create(Self);
  FRoundRobinGroup.Parent := ButtonPanel;
  FRoundRobinGroup.SetBounds(442, 10, 180, 92);
  FRoundRobinGroup.Caption := 'Pairing';
  FRoundRobinGroup.Items.Add('Single round-robin');
  FRoundRobinGroup.Items.Add('Double round-robin');
  FRoundRobinGroup.Items.Add('Swiss');
  FRoundRobinGroup.ItemIndex := TournamentPairingIndexSingleRoundRobin;
  FRoundRobinGroup.OnClick := @InvalidateTournamentResults;

  CreateButton := TButton.Create(Self);
  CreateButton.Parent := ButtonPanel;
  CreateButton.SetBounds(640, 16, 120, 28);
  CreateButton.Caption := 'Create pairing';
  CreateButton.OnClick := @CreatePairingClick;

  FStartStopButton := TButton.Create(Self);
  FStartStopButton.Parent := ButtonPanel;
  FStartStopButton.SetBounds(640, 52, 120, 28);
  FStartStopButton.Caption := 'Play';
  FStartStopButton.OnClick := @StartStopClick;

  ClearButton := TButton.Create(Self);
  ClearButton.Parent := ButtonPanel;
  ClearButton.SetBounds(770, 16, 120, 28);
  ClearButton.Caption := 'Clear pairing';
  ClearButton.OnClick := @ClearPairingsClick;

  SaveButton := TButton.Create(Self);
  SaveButton.Parent := ButtonPanel;
  SaveButton.SetBounds(770, 52, 56, 28);
  SaveButton.Caption := 'Save...';
  SaveButton.OnClick := @SaveClick;

  LoadButton := TButton.Create(Self);
  LoadButton.Parent := ButtonPanel;
  LoadButton.SetBounds(834, 52, 56, 28);
  LoadButton.Caption := 'Load...';
  LoadButton.OnClick := @LoadClick;

  FInvalidationPanel := TPanel.Create(Self);
  FInvalidationPanel.Parent := Self;
  FInvalidationPanel.Align := alTop;
  FInvalidationPanel.Height := 40;
  FInvalidationPanel.BevelOuter := bvNone;
  FInvalidationPanel.BorderSpacing.Around := 6;
  FInvalidationPanel.Visible := False;

  PanelLabel := TLabel.Create(Self);
  PanelLabel.Parent := FInvalidationPanel;
  PanelLabel.Align := alClient;
  PanelLabel.Layout := tlCenter;
  PanelLabel.Caption := 'Tournament settings changed. Apply to clear current results, or revert.';

  PanelButton := TButton.Create(Self);
  PanelButton.Parent := FInvalidationPanel;
  PanelButton.Align := alRight;
  PanelButton.Width := 110;
  PanelButton.Caption := 'Revert';
  PanelButton.OnClick := @RevertInvalidatingChange;

  PanelButton := TButton.Create(Self);
  PanelButton.Parent := FInvalidationPanel;
  PanelButton.Align := alRight;
  PanelButton.Width := 110;
  PanelButton.BorderSpacing.Right := 8;
  PanelButton.Caption := 'Apply change';
  PanelButton.OnClick := @ApplyInvalidatingChange;

  ContentPanel := TPanel.Create(Self);
  ContentPanel.Parent := Self;
  ContentPanel.Align := alClient;
  ContentPanel.BevelOuter := bvNone;

  EnginePanel := TPanel.Create(Self);
  EnginePanel.Parent := ContentPanel;
  EnginePanel.Align := alLeft;
  EnginePanel.Width := 270;
  EnginePanel.BevelOuter := bvNone;
  EnginePanel.BorderSpacing.Around := 8;

  FEngineCheckList := TCheckListBox.Create(Self);
  FEngineCheckList.Parent := EnginePanel;
  FEngineCheckList.Align := alClient;

  GridPanel := TPanel.Create(Self);
  GridPanel.Parent := ContentPanel;
  GridPanel.Align := alClient;
  GridPanel.BevelOuter := bvNone;
  GridPanel.BorderSpacing.Around := 8;

  Splitter := TSplitter.Create(Self);
  Splitter.Parent := GridPanel;
  Splitter.Align := alTop;
  Splitter.Height := 8;
  Splitter.ResizeAnchor := akTop;

  CrossTablePanel := TPanel.Create(Self);
  CrossTablePanel.Parent := GridPanel;
  CrossTablePanel.Align := alTop;
  CrossTablePanel.Height := 150;
  CrossTablePanel.BevelOuter := bvNone;

  FCrossTableGrid := TStringGrid.Create(Self);
  FCrossTableGrid.Parent := CrossTablePanel;
  FCrossTableGrid.Align := alClient;
  FCrossTableGrid.ColCount := 4;
  FCrossTableGrid.RowCount := 2;
  FCrossTableGrid.FixedRows := 1;
  FCrossTableGrid.Options := FCrossTableGrid.Options - [goEditing] +
    [goColSizing, goRowSelect];

  PairingPanel := TPanel.Create(Self);
  PairingPanel.Parent := GridPanel;
  PairingPanel.Align := alClient;
  PairingPanel.BevelOuter := bvNone;

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := PairingPanel;
  FGrid.Align := alClient;
  FGrid.ColCount := 6;
  FGrid.RowCount := 2;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.Options := FGrid.Options + [goColSizing] - [goEditing, goRowSelect];
  FGrid.OnDrawCell := @PairingGridDrawCell;
  FGrid.OnMouseDown := @PairingGridMouseDown;
  PairingPopup := TPopupMenu.Create(Self);
  PopupItem := TMenuItem.Create(Self);
  PopupItem.Caption := '*';
  PopupItem.OnClick := @SetSelectedResultClick;
  PairingPopup.Items.Add(PopupItem);
  PopupItem := TMenuItem.Create(Self);
  PopupItem.Caption := '2-0';
  PopupItem.OnClick := @SetSelectedResultClick;
  PairingPopup.Items.Add(PopupItem);
  PopupItem := TMenuItem.Create(Self);
  PopupItem.Caption := '1-1';
  PopupItem.OnClick := @SetSelectedResultClick;
  PairingPopup.Items.Add(PopupItem);
  PopupItem := TMenuItem.Create(Self);
  PopupItem.Caption := '0-2';
  PopupItem.OnClick := @SetSelectedResultClick;
  PairingPopup.Items.Add(PopupItem);
  PopupItem := TMenuItem.Create(Self);
  PopupItem.Caption := '-';
  PairingPopup.Items.Add(PopupItem);
  PopupItem := TMenuItem.Create(Self);
  PopupItem.Caption := 'Reschedule selected game';
  PopupItem.OnClick := @RescheduleSelectedGame;
  PairingPopup.Items.Add(PopupItem);
  FGrid.PopupMenu := PairingPopup;
  FGrid.Cells[TournamentColGame, 0] := 'Game';
  FGrid.Cells[TournamentColRound, 0] := 'Round';
  FGrid.Cells[TournamentColWhite, 0] := 'White';
  FGrid.Cells[TournamentColBlack, 0] := 'Black';
  FGrid.Cells[TournamentColResult, 0] := 'Result';
  FGrid.Cells[TournamentColReason, 0] := 'Reason';
  FGrid.ColWidths[TournamentColGame] := 54;
  FGrid.ColWidths[TournamentColRound] := 54;
  FGrid.ColWidths[TournamentColWhite] := 260;
  FGrid.ColWidths[TournamentColBlack] := 260;
  FGrid.ColWidths[TournamentColResult] := 80;
  FGrid.ColWidths[TournamentColReason] := 180;
  ConfigurePairingGridColumns;
  AdjustPairingGridColumnWidths;

  ClearTournamentPairingGrid(FGrid);
  PopulateEngines;
  AdjustPairingGridColumnWidths;

  FTimer := TTimer.Create(Self);
  FTimer.Interval := 250;
  FTimer.Enabled := False;
  FTimer.OnTimer := @TimerTick;
  FAcceptedTournamentSignature := TournamentSignature;
  UpdateButtons;
end;

procedure TTournamentDialog.BeginShutdown;
begin
  FClosing := True;
  FRunning := False;
  if FTimer <> nil then
    FTimer.Enabled := False;
end;

function TTournamentDialog.HasTournamentData: Boolean;
begin
  Result := (Trim(FFileName) <> '') or
    (not TournamentPairingGridIsEmpty(FGrid)) or
    HasNonByeResults;
end;

function TTournamentDialog.IsRunning: Boolean;
begin
  Result := FRunning or (ActiveRunningGameCount > 0);
end;

function TTournamentDialog.SaveTournamentWithDialog: Boolean;
var
  Dialog: TSaveDialog;
begin
  Result := False;
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Title := 'Save tournament';
    Dialog.Filter := 'Tournament files (*.json)|*.json|All files (*.*)|*.*';
    Dialog.DefaultExt := 'json';
    if FFileName <> '' then
      Dialog.FileName := FFileName
    else
      Dialog.FileName := SafeFileNameText(FTournamentNameEdit.Text) + '.json';
    if not Dialog.Execute then
      Exit;

    SaveTournamentToFile(Dialog.FileName);
    FFileName := Dialog.FileName;
    Result := True;
  finally
    Dialog.Free;
  end;
end;

destructor TTournamentDialog.Destroy;
begin
  BeginShutdown;
  StopRunningGames;
  while FRunningGames.Count > 0 do
  begin
    TTournamentRunningGame(FRunningGames[0]).Free;
    FRunningGames.Delete(0);
  end;
  FRunningGames.Free;
  FPdnWriteLock.Free;
  FEngines.Free;
  FBlackEngines.Free;
  FWhiteEngines.Free;
  inherited Destroy;
end;

procedure TTournamentDialog.ClearTournamentGameRefs;
begin
  if FRunningGames = nil then
    Exit;
  while FRunningGames.Count > 0 do
  begin
    TTournamentRunningGame(FRunningGames[0]).Free;
    FRunningGames.Delete(0);
  end;
end;

procedure TTournamentDialog.AddLabelledEdit(AParent: TWinControl;
  const ACaption: string; AEdit: TEdit; var ATop: Integer);
var
  LLabel: TLabel;
begin
  LLabel := TLabel.Create(Self);
  LLabel.Parent := AParent;
  LLabel.SetBounds(0, ATop, 420, 20);
  LLabel.Caption := ACaption;
  Inc(ATop, 20);
  AEdit.Parent := AParent;
  AEdit.SetBounds(0, ATop, 420, 24);
  Inc(ATop, 34);
end;

procedure TTournamentDialog.AdjustPairingGridColumnWidths;
var
  EngineTextWidth: Integer;
  I: Integer;
  RequiredWidth: Integer;
  Row: Integer;
  TotalGridWidth: Integer;

  function TextWidth(const AText: string; AMinWidth: Integer): Integer;
  begin
    Result := Max(AMinWidth, FGrid.Canvas.TextWidth(AText) + 28);
  end;

begin
  if FGrid = nil then
    Exit;

  FGrid.Canvas.Font.Assign(FGrid.Font);
  EngineTextWidth := TextWidth('Widest player name', 260);
  if FEngineCheckList <> nil then
    for I := 0 to FEngineCheckList.Items.Count - 1 do
      EngineTextWidth := Max(EngineTextWidth,
        TextWidth(FEngineCheckList.Items[I], 260));
  for Row := 1 to FGrid.RowCount - 1 do
  begin
    EngineTextWidth := Max(EngineTextWidth,
      TextWidth(FGrid.Cells[TournamentColWhite, Row], 260));
    EngineTextWidth := Max(EngineTextWidth,
      TextWidth(FGrid.Cells[TournamentColBlack, Row], 260));
  end;

  FGrid.ColWidths[TournamentColGame] := TextWidth('Game 9999', 70);
  FGrid.ColWidths[TournamentColRound] := TextWidth('Round 999', 76);
  FGrid.ColWidths[TournamentColWhite] := EngineTextWidth;
  FGrid.ColWidths[TournamentColBlack] := EngineTextWidth;
  FGrid.ColWidths[TournamentColResult] := TextWidth('Result 0-2', 92);
  FGrid.ColWidths[TournamentColReason] := TextWidth('Unknown result', 180);

  if FGrid.Columns.Count >= FGrid.ColCount then
    for I := 0 to FGrid.ColCount - 1 do
      FGrid.Columns[I].Width := FGrid.ColWidths[I];

  TotalGridWidth := 0;
  for I := 0 to FGrid.ColCount - 1 do
    Inc(TotalGridWidth, FGrid.ColWidths[I]);
  RequiredWidth := 270 + TotalGridWidth + 96;
  if Constraints.MinWidth < RequiredWidth then
    Constraints.MinWidth := RequiredWidth;
  if Width < RequiredWidth then
    Width := RequiredWidth;
end;

function TTournamentDialog.DisplayNameForEngine(
  AEngine: TExternalEngineDefinition): string;
var
  I: Integer;
begin
  Result := '';
  if AEngine = nil then
    Exit;

  for I := 0 to FEngines.Count - 1 do
    if FEngines[I] = AEngine then
      Exit(EnginePickerDisplayName(AEngine, I + 1));

  Result := EnginePickerDisplayName(AEngine, 0);
end;

function TTournamentDialog.PdnFileName: string;
var
  BaseName: string;
  DirectoryName: string;
begin
  BaseName := SafeFileNameText(FTournamentNameEdit.Text);
  if not SameText(ExtractFileExt(BaseName), '.pdn') then
    BaseName := BaseName + '.pdn';
  DirectoryName := ExtractFilePath(FFileName);
  if DirectoryName <> '' then
    Result := DirectoryName + BaseName
  else
    Result := BaseName;
end;

procedure TTournamentDialog.AppendTournamentGameToPdn(
  ARunningGame: TTournamentRunningGame; AGame: TObject);
begin
  if (ARunningGame = nil) or ARunningGame.PdnSaved then
    Exit;
  if not (AGame is TRunningGame) then
    Exit;
  if not TRunningGame(AGame).HasPlayedMoves then
    Exit;
  if not (Owner is TMainForm) then
    Exit;

  FPdnWriteLock.Acquire;
  try
    if ARunningGame.PdnSaved then
      Exit;
    TMainForm(Owner).AppendRunningGameToPdn(TRunningGame(AGame), PdnFileName,
      FTournamentNameEdit.Text);
    ARunningGame.PdnSaved := True;
  finally
    FPdnWriteLock.Release;
  end;
end;

procedure TTournamentDialog.PopulateEngines;
var
  I: Integer;
begin
  FEngineCheckList.Clear;
  LoadExternalEngines(EnginesJsonFileName, FEngines);
  for I := 0 to FEngines.Count - 1 do
  begin
    FEngineCheckList.Items.AddObject(DisplayNameForEngine(FEngines[I]),
      FEngines[I]);
    FEngineCheckList.Checked[I] := True;
  end;
end;

function TTournamentDialog.EngineByDisplayName(
  const AName: string): TExternalEngineDefinition;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FEngines.Count - 1 do
    if SameText(EnginePickerDisplayName(FEngines[I], I + 1), AName) then
      Exit(FEngines[I]);
end;

function TTournamentDialog.EngineKeyForName(const AName: string): string;
var
  Engine: TExternalEngineDefinition;
begin
  Result := '';
  Engine := EngineByDisplayName(AName);
  if Engine <> nil then
    Result := EngineIdentityKey(Engine);
end;

procedure TTournamentDialog.CollectSelectedEngines(AEngines: TStrings);
begin
  CollectSelectedTournamentEngineNames(FEngineCheckList, AEngines);
end;

procedure TTournamentDialog.ConfigurePairingGridColumns;
  function AddColumn(const ATitle: string; AWidth: Integer;
    AReadOnly: Boolean): TGridColumn;
  begin
    Result := FGrid.Columns.Add;
    Result.Title.Caption := ATitle;
    Result.Width := AWidth;
    Result.ReadOnly := AReadOnly;
  end;

begin
  FGrid.Columns.Clear;
  AddColumn('Game', FGrid.ColWidths[TournamentColGame], True);
  AddColumn('Round', FGrid.ColWidths[TournamentColRound], True);
  AddColumn('White', FGrid.ColWidths[TournamentColWhite], True);
  AddColumn('Black', FGrid.ColWidths[TournamentColBlack], True);
  AddColumn('Result', FGrid.ColWidths[TournamentColResult], True);
  AddColumn('Reason', FGrid.ColWidths[TournamentColReason], True);

  FGrid.Cells[TournamentColGame, 0] := 'Game';
  FGrid.Cells[TournamentColRound, 0] := 'Round';
  FGrid.Cells[TournamentColWhite, 0] := 'White';
  FGrid.Cells[TournamentColBlack, 0] := 'Black';
  FGrid.Cells[TournamentColResult, 0] := 'Result';
  FGrid.Cells[TournamentColReason, 0] := 'Reason';
end;

procedure TTournamentDialog.CollectPairingRows(AWhiteEngines, ABlackEngines,
  AResults: TStrings);
begin
  CollectTournamentPairingRows(FGrid, AWhiteEngines, ABlackEngines, AResults);
end;

procedure TTournamentDialog.CollectRoundRows(ARounds: TStrings);
begin
  CollectTournamentRoundRows(FGrid, ARounds);
end;

procedure TTournamentDialog.CreatePairingClick(Sender: TObject);
var
  BlackEngines: TStringList;
  Engines: TStringList;
  PairingRound: TTournamentPairingRound;
  Results: TStringList;
  Rounds: TStringList;
  WhiteEngines: TStringList;
begin
  if PendingInvalidatingChange then
    Exit;
  Engines := TStringList.Create;
  WhiteEngines := TStringList.Create;
  BlackEngines := TStringList.Create;
  Results := TStringList.Create;
  Rounds := TStringList.Create;
  try
    CollectSelectedEngines(Engines);
    if Engines.Count < 2 then
    begin
      ShowGuiOkDialog(Self, 'Tournament', 'Select at least two engines.');
      Exit;
    end;
    CollectPairingRows(WhiteEngines, BlackEngines, Results);
    CollectRoundRows(Rounds);
    if not TournamentRoundRobinIndexIsSwiss(FRoundRobinGroup.ItemIndex) then
    begin
      ClearTournamentGameRefs;
      ClearTournamentPairingGrid(FGrid);
    end
    else if not TournamentAllResultsKnown(WhiteEngines, BlackEngines, Results) then
    begin
      ShowGuiOkDialog(Self, 'Tournament',
        'Finish the current Swiss round first.');
      Exit;
    end;

    PairingRound := BuildTournamentPairingRound(
      TournamentRoundRobinIndexIsSwiss(FRoundRobinGroup.ItemIndex),
      TournamentRoundRobinIndexIsDouble(FRoundRobinGroup.ItemIndex), Engines,
      WhiteEngines, BlackEngines, Results, Rounds);
    if PairingRound.HasRepeat and
      (ShowGuiConfirmationDialog(Self, 'Tournament',
      'A Swiss pairing without repeated opponents is no longer possible.' +
      LineEnding + 'Continue with repeated pairing?', 'Continue', '',
      mrCancel) <> mrYes) then
      Exit;
    ApplyTournamentPairingRoundToGrid(FGrid, PairingRound);
    FAcceptedTournamentSignature := TournamentSignature;
    if FInvalidationPanel <> nil then
      FInvalidationPanel.Visible := False;
    AdjustPairingGridColumnWidths;
    UpdateCrossTable;
  finally
    Rounds.Free;
    Results.Free;
    BlackEngines.Free;
    WhiteEngines.Free;
    Engines.Free;
  end;
end;

procedure TTournamentDialog.ClearPairingsClick(Sender: TObject);
begin
  if FRunning then
    Exit;
  if HasNonByeResults and
    (ShowGuiConfirmationDialog(Self, 'Clear pairing',
    'This will clear existing tournament results. Are you sure?', 'Yes',
    'No', mrNo) <> mrYes) then
    Exit;
  ClearTournamentGameRefs;
  ClearTournamentPairingGrid(FGrid);
  FAcceptedTournamentSignature := TournamentSignature;
  if FInvalidationPanel <> nil then
    FInvalidationPanel.Visible := False;
  UpdateCrossTable;
end;

procedure TTournamentDialog.ClearStaleRunningReasons;
var
  Row: Integer;
begin
  for Row := 1 to FGrid.RowCount - 1 do
    if TournamentReasonIsTransient(FGrid.Cells[TournamentColReason, Row]) and
      (not IsRowRunning(Row)) then
      FGrid.Cells[TournamentColReason, Row] := '';
end;

function TTournamentDialog.HasNonByeResults: Boolean;
var
  Row: Integer;
begin
  Result := False;
  for Row := 1 to FGrid.RowCount - 1 do
  begin
    if not TournamentGridHasPairingAtRow(FGrid, Row) then
      Continue;
    if TournamentReasonIsTransient(FGrid.Cells[TournamentColReason, Row]) and
      (not IsRowRunning(Row)) then
      FGrid.Cells[TournamentColReason, Row] := '';
    if SameText(Trim(FGrid.Cells[TournamentColReason, Row]), 'Bye') then
      Continue;
    if TournamentResultIsKnown(ParseTournamentResult(
      FGrid.Cells[TournamentColResult, Row])) then
      Exit(True);
  end;
end;

function TTournamentDialog.FindNextUnplayedRow: Integer;
var
  BlackEngines: TStringList;
  I: Integer;
  LatestRound: Integer;
  Results: TStringList;
  Rounds: TStringList;
  WhiteEngines: TStringList;
begin
  Result := 0;
  WhiteEngines := TStringList.Create;
  BlackEngines := TStringList.Create;
  Results := TStringList.Create;
  Rounds := TStringList.Create;
  try
    CollectPairingRows(WhiteEngines, BlackEngines, Results);
    CollectRoundRows(Rounds);
    LatestRound := 0;
    if TournamentRoundRobinIndexIsSwiss(FRoundRobinGroup.ItemIndex) then
      for I := 0 to Rounds.Count - 1 do
        if StrToIntDef(Rounds[I], 0) > LatestRound then
          LatestRound := StrToIntDef(Rounds[I], 0);

    for I := 0 to Results.Count - 1 do
    begin
      if TournamentRoundRobinIndexIsSwiss(FRoundRobinGroup.ItemIndex) and
        (StrToIntDef(Rounds[I], 0) <> LatestRound) then
        Continue;
      if IsRowRunning(I + 1) then
        Continue;
      if Trim(FGrid.Cells[TournamentColReason, I + 1]) <> '' then
        Continue;
      if not TournamentResultIsKnown(ParseTournamentResult(Results[I])) then
        Exit(I + 1);
    end;
  finally
    Rounds.Free;
    Results.Free;
    BlackEngines.Free;
    WhiteEngines.Free;
  end;
end;

function TTournamentDialog.ActiveRunningGameCount: Integer;
var
  I: Integer;
begin
  Result := 0;
  if FRunningGames = nil then
    Exit;
  for I := 0 to FRunningGames.Count - 1 do
    if TTournamentRunningGame(FRunningGames[I]).Active then
      Inc(Result);
end;

function TTournamentDialog.FindTournamentGameByRow(
  ARow: Integer): TTournamentRunningGame;
var
  I: Integer;
begin
  Result := nil;
  if FRunningGames = nil then
    Exit;
  for I := FRunningGames.Count - 1 downto 0 do
    if TTournamentRunningGame(FRunningGames[I]).Row = ARow then
      Exit(TTournamentRunningGame(FRunningGames[I]));
end;

function TTournamentDialog.IsRowRunning(ARow: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FRunningGames.Count - 1 do
    if TTournamentRunningGame(FRunningGames[I]).Active and
      (TTournamentRunningGame(FRunningGames[I]).Row = ARow) then
      Exit(True);
end;

function TTournamentDialog.IsRowStartable(ARow: Integer;
  ABusyEngineKeys: TStrings): Boolean;
var
  BlackKey: string;
  BlackEngine: TExternalEngineDefinition;
  CandidateKeys: TStringList;
  I: Integer;
  WhiteKey: string;
  WhiteEngine: TExternalEngineDefinition;
begin
  Result := False;
  if (ARow <= 0) or (ARow >= FGrid.RowCount) then
    Exit;
  if IsRowRunning(ARow) then
    Exit;
  if not TournamentGridHasPairingAtRow(FGrid, ARow) then
    Exit;
  if TournamentReasonIsTransient(FGrid.Cells[TournamentColReason, ARow]) and
    (not IsRowRunning(ARow)) then
    FGrid.Cells[TournamentColReason, ARow] := '';
  if TournamentResultIsKnown(ParseTournamentResult(
    FGrid.Cells[TournamentColResult, ARow])) then
    Exit;
  if Trim(FGrid.Cells[TournamentColReason, ARow]) <> '' then
    Exit;

  WhiteEngine := EngineByDisplayName(FGrid.Cells[TournamentColWhite, ARow]);
  BlackEngine := EngineByDisplayName(FGrid.Cells[TournamentColBlack, ARow]);
  WhiteKey := EngineIdentityKey(WhiteEngine);
  BlackKey := EngineIdentityKey(BlackEngine);
  if (WhiteKey = '') or (BlackKey = '') then
    Exit;
  if ABusyEngineKeys <> nil then
  begin
    CandidateKeys := TStringList.Create;
    try
      AddEngineReservationKeys(WhiteEngine, CandidateKeys);
      AddEngineReservationKeys(BlackEngine, CandidateKeys);
      for I := 0 to CandidateKeys.Count - 1 do
        if ABusyEngineKeys.IndexOf(CandidateKeys[I]) >= 0 then
          Exit;
    finally
      CandidateKeys.Free;
    end;
  end;
  Result := True;
end;

procedure TTournamentDialog.PairingGridDrawCell(Sender: TObject; ACol,
  ARow: Integer; Rect: TRect; State: TGridDrawState);
begin
  if ARow = 0 then
  begin
    FGrid.Canvas.Brush.Color := clBtnFace;
    FGrid.Canvas.Font.Color := clWindowText;
  end
  else if IsRowRunning(ARow) then
  begin
    FGrid.Canvas.Brush.Color := TColor($00CCFFFF);
    FGrid.Canvas.Font.Color := clBlack;
  end
  else
  begin
    FGrid.Canvas.Brush.Color := clWindow;
    FGrid.Canvas.Font.Color := clWindowText;
  end;
  DrawGridText(FGrid, ACol, ARow, Rect);
end;

procedure TTournamentDialog.PairingGridMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Col: Integer;
  Game: TRunningGame;
  Row: Integer;
  RunningGame: TTournamentRunningGame;
begin
  if FGrid = nil then
    Exit;

  FGrid.MouseToCell(X, Y, Col, Row);
  if (Col >= 0) and (Col < FGrid.ColCount) and (Row > 0) and
    (Row < FGrid.RowCount) then
  begin
    FGrid.Col := Col;
    FGrid.Row := Row;
    if Button = mbLeft then
    begin
      RunningGame := FindTournamentGameByRow(Row);
      Game := TournamentRunningGameFor(Owner, RunningGame);
      if (Game <> nil) and Assigned(FOnSelectGame) then
        FOnSelectGame(Self, Game);
    end;
  end;
end;

procedure TTournamentDialog.SetSelectedResult(const AResultText: string);
begin
  if (FGrid = nil) or (FGrid.Row <= 0) or
    (FGrid.Row >= FGrid.RowCount) or IsRowRunning(FGrid.Row) or
    (not TournamentGridHasPairingAtRow(FGrid, FGrid.Row)) then
    Exit;

  FGrid.Cells[TournamentColResult, FGrid.Row] := AResultText;
  if AResultText = '*' then
  begin
    if SameText(Trim(FGrid.Cells[TournamentColReason, FGrid.Row]),
      'Manual result') then
      FGrid.Cells[TournamentColReason, FGrid.Row] := '';
  end
  else if Trim(FGrid.Cells[TournamentColReason, FGrid.Row]) = '' then
    FGrid.Cells[TournamentColReason, FGrid.Row] := 'Manual result';
  UpdateCrossTable;
end;

procedure TTournamentDialog.SetSelectedResultClick(Sender: TObject);
begin
  if Sender is TMenuItem then
    SetSelectedResult(TMenuItem(Sender).Caption);
end;

procedure TTournamentDialog.RescheduleSelectedGame(Sender: TObject);
var
  Row: Integer;
begin
  Row := FGrid.Row;
  if (Row <= 0) or (Row >= FGrid.RowCount) then
    Exit;
  if IsRowRunning(Row) then
    Exit;
  if not TournamentGridHasPairingAtRow(FGrid, Row) then
    Exit;

  FGrid.Cells[TournamentColResult, Row] := '*';
  FGrid.Cells[TournamentColReason, Row] := '';
  FGrid.Invalidate;
  UpdateCrossTable;
  UpdateButtons;
end;

procedure TTournamentDialog.SaveClick(Sender: TObject);
begin
  SaveTournamentWithDialog;
end;

procedure TTournamentDialog.LoadClick(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  if FRunning then
    Exit;
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := 'Load tournament';
    Dialog.Filter := 'Tournament files (*.json)|*.json|All files (*.*)|*.*';
    Dialog.Options := Dialog.Options + [ofFileMustExist];
    if Dialog.Execute then
    begin
      LoadTournamentFromFile(Dialog.FileName);
      FFileName := Dialog.FileName;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TTournamentDialog.SaveTournamentToFile(const AFileName: string);
var
  Data: TJSONObject;
  EngineArray: TJSONArray;
  Game: TJSONObject;
  Games: TJSONArray;
  I: Integer;
  Lines: TStringList;
begin
  Data := TJSONObject.Create;
  try
    Data.Add('tournament_name', FTournamentNameEdit.Text);
    Data.Add('starting_fen', FStartingFENEdit.Text);
    Data.Add('moves_per_period', StrToIntDef(Trim(FMovesEdit.Text), 75));
    Data.Add('minutes_per_period', StrToFloatDef(Trim(FMinutesEdit.Text), 5));
    Data.Add('increment_seconds', StrToFloatDef(Trim(FIncrementEdit.Text), 0));
    Data.Add('concurrent_games', MaxConcurrentGames);
    if FIncrementModeCombo.ItemIndex = 1 then
      Data.Add('increment_mode', 'after-move-limit')
    else
      Data.Add('increment_mode', 'from-start');
    Data.Add('pairing_type',
      TournamentTypeForRoundRobinIndex(FRoundRobinGroup.ItemIndex));

    EngineArray := TJSONArray.Create;
    Data.Add('selected_engines', EngineArray);
    for I := 0 to FEngineCheckList.Items.Count - 1 do
      if FEngineCheckList.Checked[I] then
        EngineArray.Add(FEngineCheckList.Items[I]);

    Games := TJSONArray.Create;
    Data.Add('games', Games);
    for I := 1 to FGrid.RowCount - 1 do
      if TournamentGridHasPairingAtRow(FGrid, I) then
      begin
        Game := TJSONObject.Create;
        Game.Add('game', StrToIntDef(FGrid.Cells[TournamentColGame, I], I));
        Game.Add('round', StrToIntDef(FGrid.Cells[TournamentColRound, I], 1));
        Game.Add('white', FGrid.Cells[TournamentColWhite, I]);
        Game.Add('black', FGrid.Cells[TournamentColBlack, I]);
        Game.Add('result', FGrid.Cells[TournamentColResult, I]);
        Game.Add('reason', FGrid.Cells[TournamentColReason, I]);
        Games.Add(Game);
      end;

    Lines := TStringList.Create;
    try
      Lines.Text := Data.FormatJSON([], 2) + LineEnding;
      Lines.SaveToFile(AFileName);
    finally
      Lines.Free;
    end;
  finally
    Data.Free;
  end;
end;

procedure TTournamentDialog.LoadTournamentFromFile(const AFileName: string);
var
  Data: TJSONData;
  EngineName: string;
  Engines: TJSONData;
  Game: TJSONObject;
  Games: TJSONData;
  I: Integer;
  Lines: TStringList;
  Row: Integer;
  PairingType: string;
begin
  FLoadingTournament := True;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    Data := GetJSON(Lines.Text);
  finally
    Lines.Free;
  end;

  try
    if (Data = nil) or (Data.JSONType <> jtObject) then
      Exit;

    FTournamentNameEdit.Text := TJSONObject(Data).Get('tournament_name',
      'Tournament');
    FStartingFENEdit.Text := TJSONObject(Data).Get('starting_fen',
      'W:W31-50:B1-20');
    FMovesEdit.Text := IntToStr(TJSONObject(Data).Get('moves_per_period', 75));
    FMinutesEdit.Text := FloatToStr(TJSONObject(Data).Get('minutes_per_period', 5.0));
    FIncrementEdit.Text := FloatToStr(TJSONObject(Data).Get('increment_seconds', 0.0));
    FConcurrentGamesEdit.Text := IntToStr(TJSONObject(Data).Get('concurrent_games', 1));
    if SameText(TJSONObject(Data).Get('increment_mode', 'from-start'),
      'after-move-limit') then
      FIncrementModeCombo.ItemIndex := 1
    else
      FIncrementModeCombo.ItemIndex := 0;

    PairingType := TJSONObject(Data).Get('pairing_type',
      TournamentTypeSingleRoundRobin);
    if SameText(PairingType, TournamentTypeSwiss) then
      FRoundRobinGroup.ItemIndex := TournamentPairingIndexSwiss
    else if SameText(PairingType, TournamentTypeDoubleRoundRobin) then
      FRoundRobinGroup.ItemIndex := TournamentPairingIndexDoubleRoundRobin
    else
      FRoundRobinGroup.ItemIndex := TournamentPairingIndexSingleRoundRobin;

    for I := 0 to FEngineCheckList.Items.Count - 1 do
      FEngineCheckList.Checked[I] := False;
    Engines := TJSONObject(Data).Find('selected_engines');
    if (Engines <> nil) and (Engines.JSONType = jtArray) then
      for I := 0 to TJSONArray(Engines).Count - 1 do
      begin
        EngineName := TJSONArray(Engines).Strings[I];
        Row := FEngineCheckList.Items.IndexOf(EngineName);
        if Row >= 0 then
          FEngineCheckList.Checked[Row] := True;
      end;

    ClearTournamentGameRefs;
    ClearTournamentPairingGrid(FGrid);
    Games := TJSONObject(Data).Find('games');
    if (Games <> nil) and (Games.JSONType = jtArray) then
      for I := 0 to TJSONArray(Games).Count - 1 do
        if TJSONArray(Games).Items[I].JSONType = jtObject then
        begin
          Game := TJSONObject(TJSONArray(Games).Items[I]);
          Row := AddTournamentPairingRow(FGrid, Game.Get('white', ''),
            Game.Get('black', ''), Game.Get('round', 1));
          FGrid.Cells[TournamentColGame, Row] := IntToStr(Game.Get('game', Row));
          FGrid.Cells[TournamentColResult, Row] := Game.Get('result', '*');
          FGrid.Cells[TournamentColReason, Row] := Game.Get('reason', '');
        end;
    FAcceptedTournamentSignature := TournamentSignature;
    if FInvalidationPanel <> nil then
      FInvalidationPanel.Visible := False;
    AdjustPairingGridColumnWidths;
    UpdateCrossTable;
  finally
    FLoadingTournament := False;
    Data.Free;
  end;
end;

procedure TTournamentDialog.InvalidateTournamentResults(Sender: TObject);
begin
  if FLoadingTournament then
    Exit;
  if FGrid = nil then
    Exit;
  if TournamentPairingGridIsEmpty(FGrid) then
  begin
    FAcceptedTournamentSignature := TournamentSignature;
    Exit;
  end;
  if TournamentSignature = FAcceptedTournamentSignature then
  begin
    if FInvalidationPanel <> nil then
      FInvalidationPanel.Visible := False;
    Exit;
  end;

  if FInvalidationPanel <> nil then
    FInvalidationPanel.Visible := True;
  UpdateButtons;
end;

function TTournamentDialog.PendingInvalidatingChange: Boolean;
begin
  Result := (FInvalidationPanel <> nil) and FInvalidationPanel.Visible;
end;

function TTournamentDialog.TournamentSignature: string;
begin
  Result := Trim(FStartingFENEdit.Text) + '|' + Trim(FMovesEdit.Text) + '|' +
    Trim(FMinutesEdit.Text) + '|' + Trim(FIncrementEdit.Text) + '|' +
    IntToStr(FIncrementModeCombo.ItemIndex) + '|' +
    IntToStr(FRoundRobinGroup.ItemIndex);
end;

procedure TTournamentDialog.ApplyInvalidatingChange(Sender: TObject);
begin
  if FInvalidationPanel <> nil then
    FInvalidationPanel.Visible := False;

  if FRunning then
  begin
    FRunning := False;
    StopRunningGames;
    FTimer.Enabled := ActiveRunningGameCount > 0;
    UpdateButtons;
  end;

  ClearTournamentGameRefs;
  if FTimer <> nil then
    FTimer.Enabled := False;
  ClearTournamentPairingGrid(FGrid);
  FAcceptedTournamentSignature := TournamentSignature;
  UpdateCrossTable;
  UpdateButtons;
end;

procedure TTournamentDialog.RevertInvalidatingChange(Sender: TObject);
var
  Parts: TStringList;
begin
  if FInvalidationPanel <> nil then
    FInvalidationPanel.Visible := False;

  Parts := TStringList.Create;
  try
    Parts.Delimiter := '|';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := FAcceptedTournamentSignature;
    if Parts.Count >= 6 then
    begin
      FLoadingTournament := True;
      try
        FStartingFENEdit.Text := Parts[0];
        FMovesEdit.Text := Parts[1];
        FMinutesEdit.Text := Parts[2];
        FIncrementEdit.Text := Parts[3];
        FIncrementModeCombo.ItemIndex := StrToIntDef(Parts[4], 0);
        FRoundRobinGroup.ItemIndex := StrToIntDef(Parts[5], 0);
      finally
        FLoadingTournament := False;
      end;
    end;
  finally
    Parts.Free;
  end;
  UpdateButtons;
end;

function TTournamentDialog.GameSetupForRow(ARow: Integer;
  out ASetup: TGameSetup): Boolean;
begin
  Result := False;
  ASetup.StartingFEN := '';
  ASetup.WhitePlayer := pkRegistered;
  ASetup.BlackPlayer := pkRegistered;
  ASetup.WhiteEngine := nil;
  ASetup.BlackEngine := nil;
  ASetup.TimeControl := DefaultTimeControl;
  if not TournamentGridHasPairingAtRow(FGrid, ARow) then
    Exit;
  ASetup.WhiteEngine := EngineByDisplayName(FGrid.Cells[TournamentColWhite, ARow]);
  ASetup.BlackEngine := EngineByDisplayName(FGrid.Cells[TournamentColBlack, ARow]);
  if (ASetup.WhiteEngine = nil) or (ASetup.BlackEngine = nil) then
    Exit;
  ASetup.StartingFEN := Trim(FStartingFENEdit.Text);
  if ASetup.StartingFEN = '' then
    ASetup.StartingFEN := 'W:W31-50:B1-20';
  ASetup.WhitePlayer := pkRegistered;
  ASetup.BlackPlayer := pkRegistered;
  ASetup.TimeControl.MovesPerPeriod := StrToIntDef(Trim(FMovesEdit.Text), 75);
  ASetup.TimeControl.MinutesPerPeriod := StrToFloatDef(Trim(FMinutesEdit.Text), 5);
  ASetup.TimeControl.IncrementSeconds := StrToFloatDef(Trim(FIncrementEdit.Text), 0);
  if FIncrementModeCombo.ItemIndex = 1 then
    ASetup.TimeControl.IncrementMode := cimAfterMoveLimit
  else
    ASetup.TimeControl.IncrementMode := cimFromStart;
  Result := True;
end;

function TTournamentDialog.MaxConcurrentGames: Integer;
begin
  Result := StrToIntDef(Trim(FConcurrentGamesEdit.Text), 1);
  if Result < 1 then
    Result := 1;
end;

procedure TTournamentDialog.HighlightRow(ARow: Integer);
begin
  if (ARow > 0) and (ARow < FGrid.RowCount) then
  begin
    FGrid.Row := ARow;
    FGrid.TopRow := ARow;
  end;
end;

procedure TTournamentDialog.StartStopClick(Sender: TObject);
begin
  if FRunning then
  begin
    FRunning := False;
    StopRunningGames;
    FTimer.Enabled := ActiveRunningGameCount > 0;
    UpdateButtons;
    Exit;
  end;

  if PendingInvalidatingChange then
    Exit;

  ClearStaleRunningReasons;
  FRunning := True;
  FLastGameStartTick := 0;
  StartPendingGames;
  FTimer.Enabled := FRunning;
  UpdateButtons;
end;

procedure TTournamentDialog.StopRunningGames;
var
  Game: TRunningGame;
  I: Integer;
  RunningGame: TTournamentRunningGame;
begin
  for I := FRunningGames.Count - 1 downto 0 do
  begin
    RunningGame := TTournamentRunningGame(FRunningGames[I]);
    if not RunningGame.Active then
      Continue;
    Game := TournamentRunningGameFor(Owner, RunningGame);
    if Game <> nil then
    begin
      if Game.Lifecycle = rglFinished then
      begin
        ApplyTournamentGameResultToRow(FGrid, RunningGame.Row, Game);
        AppendTournamentGameToPdn(RunningGame, Game);
        RunningGame.Active := False;
      end
      else
      begin
        if Owner is TMainForm then
          TMainForm(Owner).MarkGameStopped(Game, 'Tournament stopped')
        else
          Game.Runner.PostStop;
        if (RunningGame.Row > 0) and (RunningGame.Row < FGrid.RowCount) then
        begin
          FGrid.Cells[TournamentColResult, RunningGame.Row] := '*';
          FGrid.Cells[TournamentColReason, RunningGame.Row] := 'Stopping';
        end;
        Continue;
      end;
    end;
    RunningGame.Active := False;
  end;
  if (not FClosing) and (FGrid <> nil) then
    FGrid.Invalidate;
  if not FClosing then
    UpdateCrossTable;
end;

procedure TTournamentDialog.GameStopped(AGame: TObject);
var
  I: Integer;
  RunningGame: TTournamentRunningGame;
begin
  for I := FRunningGames.Count - 1 downto 0 do
  begin
    RunningGame := TTournamentRunningGame(FRunningGames[I]);
    if not (AGame is TRunningGame) then
      Continue;
    if RunningGame.GameId <> TRunningGame(AGame).Id then
      Continue;

    if (RunningGame.Row > 0) and (RunningGame.Row < FGrid.RowCount) then
    begin
      if (AGame is TRunningGame) and
        (TRunningGame(AGame).Lifecycle = rglFinished) and
        (TRunningGame(AGame).State in [gosGameOver, gosError]) then
      begin
        ApplyTournamentGameResultToRow(FGrid, RunningGame.Row,
          TRunningGame(AGame));
        AppendTournamentGameToPdn(RunningGame, TRunningGame(AGame));
      end
      else
      begin
        FGrid.Cells[TournamentColResult, RunningGame.Row] := '*';
        if (AGame is TRunningGame) and
          (TRunningGame(AGame).Lifecycle <> rglFinished) then
          FGrid.Cells[TournamentColReason, RunningGame.Row] := 'Stopping'
        else
          FGrid.Cells[TournamentColReason, RunningGame.Row] := 'Stopped';
      end;
    end;
    if (not (AGame is TRunningGame)) or
      (TRunningGame(AGame).Lifecycle = rglFinished) then
      RunningGame.Active := False
    else if (AGame is TRunningGame) and
      (TRunningGame(AGame).Lifecycle = rglRemoveRequested) then
    begin
      RunningGame.Free;
      FRunningGames.Delete(I);
    end;
    Break;
  end;

  if (not FClosing) and (FGrid <> nil) then
    FGrid.Invalidate;
  if not FClosing then
  begin
    UpdateCrossTable;
    UpdateButtons;
  end;
end;

procedure TTournamentDialog.StartPendingGames;
var
  BusyEngineKeys: TStringList;
  GameObject: TObject;
  LatestRound: Integer;
  MaxGames: Integer;
  RunningGame: TTournamentRunningGame;
  Row: Integer;
  Setup: TGameSetup;
  StartedAny: Boolean;
begin
  if not FRunning then
    Exit;
  if not Assigned(FOnStartGame) then
    Exit;

  ClearStaleRunningReasons;
  StartedAny := False;
  MaxGames := MaxConcurrentGames;
  if (FLastGameStartTick > 0) and
    (GetTickCount64 - FLastGameStartTick < TournamentLaunchStaggerMs) then
    Exit;

  BusyEngineKeys := TStringList.Create;
  try
    BusyEngineKeys.Sorted := True;
    BusyEngineKeys.Duplicates := dupIgnore;
    if Owner is TMainForm then
      TMainForm(Owner).CollectBusyEngineKeys(BusyEngineKeys);

    LatestRound := 0;
    if TournamentRoundRobinIndexIsSwiss(FRoundRobinGroup.ItemIndex) then
      for Row := 1 to FGrid.RowCount - 1 do
        if StrToIntDef(FGrid.Cells[TournamentColRound, Row], 0) > LatestRound then
          LatestRound := StrToIntDef(FGrid.Cells[TournamentColRound, Row], 0);

    for Row := 1 to FGrid.RowCount - 1 do
    begin
      if ActiveRunningGameCount >= MaxGames then
        Break;
      if TournamentRoundRobinIndexIsSwiss(FRoundRobinGroup.ItemIndex) and
        (StrToIntDef(FGrid.Cells[TournamentColRound, Row], 0) <> LatestRound) then
        Continue;
      if not IsRowStartable(Row, BusyEngineKeys) then
        Continue;
      if not GameSetupForRow(Row, Setup) then
        Continue;

      GameObject := nil;
      FOnStartGame(Self, Setup, 'Tournament game', GameObject);
      if not (GameObject is TRunningGame) then
        Continue;

      RunningGame := TTournamentRunningGame.Create;
      RunningGame.Active := True;
      RunningGame.Row := Row;
      RunningGame.GameId := TRunningGame(GameObject).Id;
      FRunningGames.Add(RunningGame);
      FGrid.Cells[TournamentColReason, Row] := 'Running';
      FGrid.Invalidate;
      HighlightRow(Row);
      StartedAny := True;
      FLastGameStartTick := GetTickCount64;

      AddEngineReservationKeys(Setup.WhiteEngine, BusyEngineKeys);
      AddEngineReservationKeys(Setup.BlackEngine, BusyEngineKeys);
      Break;
    end;
  finally
    BusyEngineKeys.Free;
  end;

  if (not StartedAny) and (ActiveRunningGameCount = 0) and
    (FindNextUnplayedRow = 0) then
  begin
    FRunning := False;
    FTimer.Enabled := False;
    HighlightRow(0);
  end;
end;

procedure TTournamentDialog.TimerTick(Sender: TObject);
var
  Game: TRunningGame;
  I: Integer;
  RunningGame: TTournamentRunningGame;
begin
  if (not FRunning) and (ActiveRunningGameCount = 0) then
    Exit;

  for I := FRunningGames.Count - 1 downto 0 do
  begin
    RunningGame := TTournamentRunningGame(FRunningGames[I]);
    if not RunningGame.Active then
      Continue;
    Game := TournamentRunningGameFor(Owner, RunningGame);
    if Game = nil then
    begin
      RunningGame.Active := False;
      Continue;
    end;
    if Game.Lifecycle <> rglFinished then
      Continue;

    if Game.State in [gosGameOver, gosError] then
    begin
      ApplyTournamentGameResultToRow(FGrid, RunningGame.Row, Game);
      AppendTournamentGameToPdn(RunningGame, Game);
    end
    else if (RunningGame.Row > 0) and (RunningGame.Row < FGrid.RowCount) then
    begin
      FGrid.Cells[TournamentColResult, RunningGame.Row] := '*';
      if SameText(FGrid.Cells[TournamentColReason, RunningGame.Row], 'Stopping') then
        FGrid.Cells[TournamentColReason, RunningGame.Row] := 'Stopped'
      else
        FGrid.Cells[TournamentColReason, RunningGame.Row] := 'Unknown result';
    end;
    RunningGame.Active := False;
    FLastGameStartTick := GetTickCount64;
    FGrid.Invalidate;
  end;

  UpdateCrossTable;
  if FRunning then
    StartPendingGames
  else if ActiveRunningGameCount = 0 then
    FTimer.Enabled := False;
  UpdateButtons;
end;

procedure TTournamentDialog.UpdateButtons;
begin
  if FClosing then
    Exit;
  Caption := 'Tournament';
  if FRunning then
    Caption := Caption + ' - running'
  else if PendingInvalidatingChange then
    Caption := Caption + ' - settings changed';
  if FStartStopButton <> nil then
  begin
    if FRunning then
      FStartStopButton.Caption := 'Stop'
    else
      FStartStopButton.Caption := 'Play';
    FStartStopButton.Enabled := FRunning or (not PendingInvalidatingChange);
  end;
end;

procedure TTournamentDialog.UpdateCrossTable;
var
  BlackEngines: TStringList;
  Col: Integer;
  Engines: TStringList;
  I: Integer;
  J: Integer;
  Results: TStringList;
  Table: TTournamentCrossTable;
  WhiteEngines: TStringList;
begin
  if FClosing then
    Exit;
  if FCrossTableGrid = nil then
    Exit;

  Engines := TStringList.Create;
  WhiteEngines := TStringList.Create;
  BlackEngines := TStringList.Create;
  Results := TStringList.Create;
  try
    CollectSelectedEngines(Engines);
    CollectPairingRows(WhiteEngines, BlackEngines, Results);
    BuildTournamentCrossTable(Engines, WhiteEngines, BlackEngines, Results, Table);

    FCrossTableGrid.ColCount := Max(4, Length(Table.EngineNames) + 4);
    FCrossTableGrid.RowCount := Max(2, Length(Table.EngineNames) + 1);
    for I := 0 to FCrossTableGrid.ColCount - 1 do
      for J := 0 to FCrossTableGrid.RowCount - 1 do
        FCrossTableGrid.Cells[I, J] := '';

    FCrossTableGrid.Cells[0, 0] := 'Engine';
    for I := 0 to High(Table.Order) do
    begin
      FCrossTableGrid.Cells[I + 1, 0] :=
        CompactTournamentEngineHeader(Table.EngineNames[Table.Order[I]]);
      FCrossTableGrid.Cells[0, I + 1] := Table.EngineNames[Table.Order[I]];
    end;

    Col := Length(Table.EngineNames) + 1;
    FCrossTableGrid.Cells[Col, 0] := 'Points';
    FCrossTableGrid.Cells[Col + 1, 0] := '#Wins';
    FCrossTableGrid.Cells[Col + 2, 0] := 'SB';

    if Length(Table.EngineNames) = 0 then
    begin
      FCrossTableGrid.Cells[0, 1] := '';
      FCrossTableGrid.Cells[1, 1] := '0';
    end
    else
      for I := 0 to High(Table.Order) do
      begin
        for J := 0 to High(Table.Order) do
          FCrossTableGrid.Cells[J + 1, I + 1] :=
            Table.Matrix[Table.Order[I], Table.Order[J]];
        FCrossTableGrid.Cells[Col, I + 1] :=
          IntToStr(Table.Points[Table.Order[I]]);
        FCrossTableGrid.Cells[Col + 1, I + 1] :=
          IntToStr(Table.Wins[Table.Order[I]]);
        FCrossTableGrid.Cells[Col + 2, I + 1] :=
          FormatTournamentSB(Table.SB[Table.Order[I]]);
      end;

    FCrossTableGrid.ColWidths[0] := 260;
    for I := 1 to FCrossTableGrid.ColCount - 1 do
      FCrossTableGrid.ColWidths[I] := 72;
  finally
    Results.Free;
    BlackEngines.Free;
    WhiteEngines.Free;
    Engines.Free;
  end;
end;

end.
