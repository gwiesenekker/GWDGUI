unit uDatabaseForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, Clipbrd, ComCtrls, Controls, Dialogs, ExtCtrls, Forms, Graphics,
  Grids, Math, Menus, StdCtrls, SysUtils, uBoardControl, uDraughtsBoard,
  uGameDatabase, uGuiDialogs, uPositionSetupForm, uPreferences;

type
  TDatabaseForm = class(TForm)
  private
    FBoard: TDraughtsBoard;
    FBoardControl: TDraughtsBoardControl;
    FApplyFilterButton: TButton;
    FBlackFilterEdit: TEdit;
    FDatabase: TGameDatabase;
    FEventFilterEdit: TEdit;
    FFenEdit: TEdit;
    FGameInfos: TList;
    FGameSortColumn: TDatabaseGameSortColumn;
    FGameSortDescending: Boolean;
    FGamesGrid: TStringGrid;
    FImportCancel: Boolean;
    FImportProgressBar: TProgressBar;
    FImportProgressForm: TForm;
    FImportProgressLabel: TLabel;
    FImportStartTick: QWord;
    FPreferences: TGuiPreferences;
    FResults: TList;
    FResultsGrid: TStringGrid;
    FRowLimitEdit: TEdit;
    FPositionSetupForm: TPositionSetupForm;
    FSearchButton: TButton;
    FStatusLabel: TLabel;
    FWhiteFilterEdit: TEdit;
    procedure ApplyFilterClick(Sender: TObject);
    procedure BoardCopyFenClick(Sender: TObject);
    procedure BoardPasteFenClick(Sender: TObject);
    procedure ClearObjectList(AList: TList);
    function CurrentGameFilterDescription: string;
    procedure FormCloseHandler(Sender: TObject; var CloseAction: TCloseAction);
    procedure GamesGridMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    function GameDisplayLimit: Integer;
    procedure ImportProgress(ABytesRead, ATotalBytes: Int64; AImported,
      ADuplicates, AErrors: Integer; var ACancel: Boolean);
    procedure ImportProgressCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ImportPdnClick(Sender: TObject);
    procedure PopulateGamesGrid;
    procedure PopulateResultsGrid;
    procedure SearchClick(Sender: TObject);
    procedure SetFenClick(Sender: TObject);
    procedure SetGameFilterControlsEnabled(AEnabled: Boolean);
    procedure SetupPositionAccepted(Sender: TObject; const AFEN: string);
    procedure SetupPositionClick(Sender: TObject);
    procedure StopImportClick(Sender: TObject);
    procedure UpdateBoardFromFen;
    procedure UpdateGamesGridHeaders;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyPreferences(const APreferences: TGuiPreferences);
    procedure CreateDatabase(const AFileName: string);
    procedure OpenDatabase(const AFileName: string);
    procedure SetSearchFEN(const AFEN: string);
  end;

implementation

const
  DefaultDatabaseGridGameLimit = 5000;

constructor TDatabaseForm.Create(AOwner: TComponent);
var
  LBoardPanel: TPanel;
  LBoardPopup: TPopupMenu;
  LFilterLabel: TLabel;
  LFilterPanel: TPanel;
  LMenuItem: TMenuItem;
  LRootPanel: TPanel;
  LSearchPanel: TPanel;
  LSplitter: TSplitter;
  LTopPanel: TPanel;
begin
  inherited Create(AOwner);

  Caption := 'Database';
  Position := poDesigned;
  Width := 900;
  Height := 620;
  Constraints.MinWidth := 680;
  Constraints.MinHeight := 420;
  OnClose := @FormCloseHandler;

  FDatabase := TGameDatabase.Create;
  FBoard := TDraughtsBoard.Create;
  FPreferences := DefaultGuiPreferences;
  FGameInfos := TList.Create;
  FResults := TList.Create;
  FGameSortColumn := dgscId;
  FGameSortDescending := False;

  LRootPanel := TPanel.Create(Self);
  LRootPanel.Parent := Self;
  LRootPanel.Align := alClient;
  LRootPanel.BevelOuter := bvNone;
  LRootPanel.BorderSpacing.Around := 8;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := LRootPanel;
  FStatusLabel.Align := alBottom;
  FStatusLabel.Height := 24;
  FStatusLabel.Layout := tlCenter;

  LTopPanel := TPanel.Create(Self);
  LTopPanel.Parent := LRootPanel;
  LTopPanel.Align := alTop;
  LTopPanel.Height := 260;
  LTopPanel.BevelOuter := bvNone;

  LFilterPanel := TPanel.Create(Self);
  LFilterPanel.Parent := LTopPanel;
  LFilterPanel.Align := alTop;
  LFilterPanel.Height := 36;
  LFilterPanel.BevelOuter := bvNone;

  LFilterLabel := TLabel.Create(Self);
  LFilterLabel.Parent := LFilterPanel;
  LFilterLabel.SetBounds(0, 7, 36, 22);
  LFilterLabel.Caption := 'White';
  LFilterLabel.Layout := tlCenter;

  FWhiteFilterEdit := TEdit.Create(Self);
  FWhiteFilterEdit.Parent := LFilterPanel;
  FWhiteFilterEdit.SetBounds(40, 4, 90, 26);

  LFilterLabel := TLabel.Create(Self);
  LFilterLabel.Parent := LFilterPanel;
  LFilterLabel.SetBounds(136, 7, 34, 22);
  LFilterLabel.Caption := 'Black';
  LFilterLabel.Layout := tlCenter;

  FBlackFilterEdit := TEdit.Create(Self);
  FBlackFilterEdit.Parent := LFilterPanel;
  FBlackFilterEdit.SetBounds(174, 4, 90, 26);

  LFilterLabel := TLabel.Create(Self);
  LFilterLabel.Parent := LFilterPanel;
  LFilterLabel.SetBounds(270, 7, 34, 22);
  LFilterLabel.Caption := 'Event';
  LFilterLabel.Layout := tlCenter;

  FEventFilterEdit := TEdit.Create(Self);
  FEventFilterEdit.Parent := LFilterPanel;
  FEventFilterEdit.SetBounds(308, 4, 100, 26);

  LFilterLabel := TLabel.Create(Self);
  LFilterLabel.Parent := LFilterPanel;
  LFilterLabel.SetBounds(416, 7, 70, 22);
  LFilterLabel.Caption := 'Show first';
  LFilterLabel.Layout := tlCenter;

  FRowLimitEdit := TEdit.Create(Self);
  FRowLimitEdit.Parent := LFilterPanel;
  FRowLimitEdit.SetBounds(490, 4, 60, 26);
  FRowLimitEdit.Text := IntToStr(DefaultDatabaseGridGameLimit);

  LFilterLabel := TLabel.Create(Self);
  LFilterLabel.Parent := LFilterPanel;
  LFilterLabel.SetBounds(554, 7, 32, 22);
  LFilterLabel.Caption := 'rows';
  LFilterLabel.Layout := tlCenter;

  FApplyFilterButton := TButton.Create(Self);
  FApplyFilterButton.Parent := LFilterPanel;
  FApplyFilterButton.SetBounds(590, 3, 86, 28);
  FApplyFilterButton.Caption := 'Apply filter';
  FApplyFilterButton.OnClick := @ApplyFilterClick;

  FGamesGrid := TStringGrid.Create(Self);
  FGamesGrid.Parent := LTopPanel;
  FGamesGrid.Align := alClient;
  FGamesGrid.FixedCols := 0;
  FGamesGrid.FixedRows := 1;
  FGamesGrid.ColCount := 7;
  FGamesGrid.RowCount := 2;
  FGamesGrid.Options := FGamesGrid.Options + [goRowSelect] -
    [goEditing, goRangeSelect];
  FGamesGrid.OnMouseDown := @GamesGridMouseDown;
  FGamesGrid.Cells[0, 0] := '#';
  FGamesGrid.Cells[1, 0] := 'White';
  FGamesGrid.Cells[2, 0] := 'Black';
  FGamesGrid.Cells[3, 0] := 'Event';
  FGamesGrid.Cells[4, 0] := 'Result';
  FGamesGrid.Cells[5, 0] := 'Starting FEN';
  FGamesGrid.Cells[6, 0] := 'Plies';
  FGamesGrid.ColWidths[0] := 55;
  FGamesGrid.ColWidths[1] := 160;
  FGamesGrid.ColWidths[2] := 160;
  FGamesGrid.ColWidths[3] := 280;
  FGamesGrid.ColWidths[4] := 70;
  FGamesGrid.ColWidths[5] := 190;
  FGamesGrid.ColWidths[6] := 60;
  UpdateGamesGridHeaders;

  LSplitter := TSplitter.Create(Self);
  LSplitter.Parent := LRootPanel;
  LSplitter.Align := alTop;
  LSplitter.Height := 8;

  LSearchPanel := TPanel.Create(Self);
  LSearchPanel.Parent := LRootPanel;
  LSearchPanel.Align := alClient;
  LSearchPanel.BevelOuter := bvNone;

  LBoardPanel := TPanel.Create(Self);
  LBoardPanel.Parent := LSearchPanel;
  LBoardPanel.Align := alRight;
  LBoardPanel.Width := 220;
  LBoardPanel.BevelOuter := bvNone;
  LBoardPanel.BorderSpacing.Left := 8;

  FFenEdit := TEdit.Create(Self);
  FFenEdit.Parent := LBoardPanel;
  FFenEdit.Align := alTop;
  FFenEdit.Text := FBoard.CurrentFEN;

  FSearchButton := TButton.Create(Self);
  FSearchButton.Parent := LBoardPanel;
  FSearchButton.Align := alTop;
  FSearchButton.Caption := 'Search';
  FSearchButton.OnClick := @SearchClick;

  LBoardPopup := TPopupMenu.Create(Self);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Copy FEN position to clipboard';
  LMenuItem.OnClick := @BoardCopyFenClick;
  LBoardPopup.Items.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Paste FEN position from clipboard';
  LMenuItem.OnClick := @BoardPasteFenClick;
  LBoardPopup.Items.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := '-';
  LBoardPopup.Items.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Setup position...';
  LMenuItem.OnClick := @SetupPositionClick;
  LBoardPopup.Items.Add(LMenuItem);

  FBoardControl := TDraughtsBoardControl.Create(Self);
  FBoardControl.Parent := LBoardPanel;
  FBoardControl.Align := alClient;
  FBoardControl.Board := FBoard;
  FBoardControl.ShowCoordinates := False;
  FBoardControl.PopupMenu := LBoardPopup;

  FResultsGrid := TStringGrid.Create(Self);
  FResultsGrid.Parent := LSearchPanel;
  FResultsGrid.Align := alClient;
  FResultsGrid.FixedCols := 0;
  FResultsGrid.FixedRows := 1;
  FResultsGrid.ColCount := 5;
  FResultsGrid.RowCount := 2;
  FResultsGrid.Options := FResultsGrid.Options + [goRowSelect] -
    [goEditing, goRangeSelect];
  FResultsGrid.Cells[0, 0] := 'Move';
  FResultsGrid.Cells[1, 0] := 'Games';
  FResultsGrid.Cells[2, 0] := 'Won';
  FResultsGrid.Cells[3, 0] := 'Draw';
  FResultsGrid.Cells[4, 0] := 'Lost';
  FResultsGrid.ColWidths[0] := 140;
  FResultsGrid.ColWidths[1] := 70;
  FResultsGrid.ColWidths[2] := 70;
  FResultsGrid.ColWidths[3] := 70;
  FResultsGrid.ColWidths[4] := 70;

  LBoardPopup := TPopupMenu.Create(Self);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Import PDN...';
  LMenuItem.OnClick := @ImportPdnClick;
  LBoardPopup.Items.Add(LMenuItem);
  PopupMenu := LBoardPopup;
end;

destructor TDatabaseForm.Destroy;
begin
  ClearObjectList(FResults);
  FResults.Free;
  ClearObjectList(FGameInfos);
  FGameInfos.Free;
  FPositionSetupForm.Free;
  FBoard.Free;
  FDatabase.Free;
  inherited Destroy;
end;

procedure TDatabaseForm.ApplyPreferences(const APreferences: TGuiPreferences);
begin
  FPreferences := APreferences;
  if FBoardControl = nil then
    Exit;
  FBoardControl.BoardLightColor := APreferences.MainBoardLightColor;
  FBoardControl.BoardDarkColor := APreferences.MainBoardDarkColor;
  FBoardControl.PvSourceSquareColor := APreferences.PvMoveColor;
  FBoardControl.HintSourceSquareColor := APreferences.HintMoveColor;
  FBoardControl.LastMoveTargetSquareColor := APreferences.LastMoveColor;
  FBoardControl.TargetSquareColor := APreferences.TargetSquareColor;
  if FPositionSetupForm <> nil then
    FPositionSetupForm.ApplyPreferences(APreferences);
end;

procedure TDatabaseForm.ClearObjectList(AList: TList);
var
  I: Integer;
begin
  if AList = nil then
    Exit;
  for I := 0 to AList.Count - 1 do
    TObject(AList[I]).Free;
  AList.Clear;
end;

procedure TDatabaseForm.FormCloseHandler(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

procedure TDatabaseForm.ImportProgress(ABytesRead, ATotalBytes: Int64;
  AImported, ADuplicates, AErrors: Integer; var ACancel: Boolean);
var
  ElapsedSeconds: Double;
  Percent: Integer;
begin
  ACancel := FImportCancel;
  if FImportProgressForm = nil then
    Exit;

  if ATotalBytes > 0 then
    Percent := Round((ABytesRead / ATotalBytes) * 1000)
  else
    Percent := 0;
  Percent := Max(0, Min(1000, Percent));
  FImportProgressBar.Position := Percent;

  ElapsedSeconds := (GetTickCount64 - FImportStartTick) / 1000;
  FImportProgressLabel.Caption :=
    Format('Games %d, errors %d, dups %d, %.1f/%.1f MB, %.1f s',
      [AImported, AErrors, ADuplicates, ABytesRead / 1048576,
      ATotalBytes / 1048576, ElapsedSeconds]);
  Application.ProcessMessages;
  ACancel := FImportCancel;
end;

procedure TDatabaseForm.ImportProgressCloseQuery(Sender: TObject;
  var CanClose: Boolean);
begin
  FImportCancel := True;
  CanClose := False;
end;

procedure TDatabaseForm.StopImportClick(Sender: TObject);
begin
  FImportCancel := True;
  if FImportProgressLabel <> nil then
    FImportProgressLabel.Caption := 'Stopping import...';
end;

procedure TDatabaseForm.CreateDatabase(const AFileName: string);
begin
  FDatabase.CreateDatabase(AFileName);
  Caption := 'Database - ' + ExtractFileName(AFileName);
  PopulateGamesGrid;
  PopulateResultsGrid;
end;

procedure TDatabaseForm.OpenDatabase(const AFileName: string);
begin
  FDatabase.OpenDatabase(AFileName);
  Caption := 'Database - ' + ExtractFileName(AFileName);
  PopulateGamesGrid;
  PopulateResultsGrid;
end;

procedure TDatabaseForm.SetSearchFEN(const AFEN: string);
begin
  FFenEdit.Text := AFEN;
  UpdateBoardFromFen;
end;

function TDatabaseForm.GameDisplayLimit: Integer;
begin
  Result := StrToIntDef(Trim(FRowLimitEdit.Text), DefaultDatabaseGridGameLimit);
  if Result < 1 then
    Result := DefaultDatabaseGridGameLimit;
  FRowLimitEdit.Text := IntToStr(Result);
end;

function TDatabaseForm.CurrentGameFilterDescription: string;

  procedure AddPart(var AText: string; const AName, AValue: string);
  begin
    if Trim(AValue) = '' then
      Exit;
    if AText <> '' then
      AText := AText + '; ';
    AText := AText + AName + '=' + Trim(AValue);
  end;

begin
  Result := '';
  AddPart(Result, 'white', FWhiteFilterEdit.Text);
  AddPart(Result, 'black', FBlackFilterEdit.Text);
  AddPart(Result, 'event', FEventFilterEdit.Text);
  if Result = '' then
    Result := 'none';
end;

procedure TDatabaseForm.SetGameFilterControlsEnabled(AEnabled: Boolean);
begin
  FWhiteFilterEdit.Enabled := AEnabled;
  FBlackFilterEdit.Enabled := AEnabled;
  FEventFilterEdit.Enabled := AEnabled;
  FRowLimitEdit.Enabled := AEnabled;
  FApplyFilterButton.Enabled := AEnabled;
  FGamesGrid.Enabled := AEnabled;
end;

procedure TDatabaseForm.UpdateGamesGridHeaders;
var
  Suffix: string;
begin
  FGamesGrid.Cells[0, 0] := '#';
  FGamesGrid.Cells[1, 0] := 'White';
  FGamesGrid.Cells[2, 0] := 'Black';
  FGamesGrid.Cells[3, 0] := 'Event';
  FGamesGrid.Cells[4, 0] := 'Result';
  FGamesGrid.Cells[5, 0] := 'Starting FEN';
  FGamesGrid.Cells[6, 0] := 'Plies';

  if FGameSortDescending then
    Suffix := ' v'
  else
    Suffix := ' ^';
  case FGameSortColumn of
    dgscWhite:
      FGamesGrid.Cells[1, 0] := 'White' + Suffix;
    dgscBlack:
      FGamesGrid.Cells[2, 0] := 'Black' + Suffix;
    dgscEvent:
      FGamesGrid.Cells[3, 0] := 'Event' + Suffix;
  end;
end;

procedure TDatabaseForm.PopulateGamesGrid;
var
  Info: TDatabaseGameInfo;
  Limit: Integer;
  Row: Integer;
  TotalMatches: Integer;
begin
  Limit := GameDisplayLimit;
  FDatabase.LoadGames(FGameInfos, Limit, FWhiteFilterEdit.Text,
    FBlackFilterEdit.Text, FEventFilterEdit.Text, FGameSortColumn,
    FGameSortDescending, TotalMatches);
  UpdateGamesGridHeaders;
  if FGameInfos.Count = 0 then
    FGamesGrid.RowCount := 2
  else
    FGamesGrid.RowCount := FGameInfos.Count + 1;
  for Row := 1 to FGamesGrid.RowCount - 1 do
  begin
    FGamesGrid.Cells[0, Row] := '';
    FGamesGrid.Cells[1, Row] := '';
    FGamesGrid.Cells[2, Row] := '';
    FGamesGrid.Cells[3, Row] := '';
    FGamesGrid.Cells[4, Row] := '';
    FGamesGrid.Cells[5, Row] := '';
    FGamesGrid.Cells[6, Row] := '';
  end;
  for Row := 1 to FGameInfos.Count do
  begin
    Info := TDatabaseGameInfo(FGameInfos[Row - 1]);
    FGamesGrid.Cells[0, Row] := IntToStr(Row);
    FGamesGrid.Cells[1, Row] := Info.WhiteName;
    FGamesGrid.Cells[2, Row] := Info.BlackName;
    FGamesGrid.Cells[3, Row] := Info.EventName;
    FGamesGrid.Cells[4, Row] := Info.ResultText;
    FGamesGrid.Cells[5, Row] := Info.StartingFEN;
    FGamesGrid.Cells[6, Row] := IntToStr(Info.PlyCount);
  end;
  if TotalMatches > FGameInfos.Count then
    FStatusLabel.Caption := IntToStr(TotalMatches) +
      ' game(s) found for filter: ' + CurrentGameFilterDescription +
      '; showing first ' + IntToStr(FGameInfos.Count)
  else
    FStatusLabel.Caption := IntToStr(TotalMatches) +
      ' game(s) found for filter: ' + CurrentGameFilterDescription;
end;

procedure TDatabaseForm.ApplyFilterClick(Sender: TObject);
begin
  SetGameFilterControlsEnabled(False);
  FStatusLabel.Caption := 'Filtering...';
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  try
    try
      PopulateGamesGrid;
    except
      on E: Exception do
      begin
        FStatusLabel.Caption := 'Filter failed';
        ShowGuiOkDialog(Self, 'Database filter', E.Message);
      end;
    end;
  finally
    Screen.Cursor := crDefault;
    SetGameFilterControlsEnabled(True);
  end;
end;

procedure TDatabaseForm.GamesGridMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  Col: Integer;
  Row: Integer;
  NewSortColumn: TDatabaseGameSortColumn;
begin
  if Button <> mbLeft then
    Exit;
  FGamesGrid.MouseToCell(X, Y, Col, Row);
  if Row <> 0 then
    Exit;
  case Col of
    1:
      NewSortColumn := dgscWhite;
    2:
      NewSortColumn := dgscBlack;
    3:
      NewSortColumn := dgscEvent;
  else
    Exit;
  end;
  if FGameSortColumn = NewSortColumn then
    FGameSortDescending := not FGameSortDescending
  else
  begin
    FGameSortColumn := NewSortColumn;
    FGameSortDescending := False;
  end;
  ApplyFilterClick(Sender);
end;

procedure TDatabaseForm.PopulateResultsGrid;
var
  Item: TDatabaseSearchResult;
  Row: Integer;
begin
  if FResults.Count = 0 then
    FResultsGrid.RowCount := 2
  else
    FResultsGrid.RowCount := FResults.Count + 1;
  for Row := 1 to FResultsGrid.RowCount - 1 do
  begin
    FResultsGrid.Cells[0, Row] := '';
    FResultsGrid.Cells[1, Row] := '';
    FResultsGrid.Cells[2, Row] := '';
    FResultsGrid.Cells[3, Row] := '';
    FResultsGrid.Cells[4, Row] := '';
  end;
  for Row := 1 to FResults.Count do
  begin
    Item := TDatabaseSearchResult(FResults[Row - 1]);
    FResultsGrid.Cells[0, Row] := Item.MoveText;
    FResultsGrid.Cells[1, Row] := IntToStr(Item.GameCount);
    FResultsGrid.Cells[2, Row] := IntToStr(Item.Wins);
    FResultsGrid.Cells[3, Row] := IntToStr(Item.Draws);
    FResultsGrid.Cells[4, Row] := IntToStr(Item.Losses);
  end;
end;

procedure TDatabaseForm.UpdateBoardFromFen;
begin
  FBoard.LoadFromFEN(Trim(FFenEdit.Text));
  FFenEdit.Text := FBoard.CurrentFEN;
  FBoardControl.Invalidate;
end;

procedure TDatabaseForm.SetFenClick(Sender: TObject);
begin
  try
    UpdateBoardFromFen;
  except
    on E: Exception do
      ShowGuiOkDialog(Self, 'Database', 'Invalid FEN: ' + E.Message);
  end;
end;

procedure TDatabaseForm.SearchClick(Sender: TObject);
begin
  if FSearchButton <> nil then
    FSearchButton.Enabled := False;
  FStatusLabel.Caption := 'Searching...';
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;
  try
    try
      UpdateBoardFromFen;
      FDatabase.SearchPosition(FBoard.PositionKey, FBoard.SideToMove, FResults);
      PopulateResultsGrid;
      FStatusLabel.Caption := IntToStr(FResults.Count) +
        ' continuation(s) found for ' + FBoard.CurrentFEN;
    except
      on E: Exception do
      begin
        FStatusLabel.Caption := 'Search failed';
        ShowGuiOkDialog(Self, 'Database search', E.Message);
      end;
    end;
  finally
    Screen.Cursor := crDefault;
    if FSearchButton <> nil then
      FSearchButton.Enabled := True;
  end;
end;

procedure TDatabaseForm.BoardPasteFenClick(Sender: TObject);
begin
  FFenEdit.Text := Clipboard.AsText;
  SetFenClick(Sender);
end;

procedure TDatabaseForm.BoardCopyFenClick(Sender: TObject);
begin
  Clipboard.AsText := FBoard.CurrentFEN;
end;

procedure TDatabaseForm.SetupPositionAccepted(Sender: TObject; const AFEN: string);
begin
  FFenEdit.Text := AFEN;
  SetFenClick(Sender);
end;

procedure TDatabaseForm.SetupPositionClick(Sender: TObject);
begin
  if FPositionSetupForm = nil then
  begin
    FPositionSetupForm := TPositionSetupForm.Create(Self);
    FPositionSetupForm.OnAccepted := @SetupPositionAccepted;
    FPositionSetupForm.ApplyPreferences(FPreferences);
  end;
  FPositionSetupForm.StartSetup(FBoard.CurrentFEN);
  ShowFormCenteredOnOwner(FPositionSetupForm, Self);
end;

procedure TDatabaseForm.ImportPdnClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  Duplicates: Integer;
  Errors: Integer;
  Imported: Integer;
  LButton: TButton;
  LogFileName: string;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := 'Import PDN';
    Dialog.Filter := 'PDN files|*.pdn|All files|*';
    if not Dialog.Execute then
      Exit;
    try
      LogFileName := ChangeFileExt(Dialog.FileName, '.import.log');
      FImportCancel := False;
      FImportStartTick := GetTickCount64;
      FImportProgressForm := TForm.Create(Self);
      try
        FImportProgressForm.Caption := 'Import PDN';
        FImportProgressForm.Position := poDesigned;
        FImportProgressForm.BorderStyle := bsDialog;
        FImportProgressForm.Width := 520;
        FImportProgressForm.Height := 140;
        FImportProgressForm.OnCloseQuery := @ImportProgressCloseQuery;

        FImportProgressLabel := TLabel.Create(FImportProgressForm);
        FImportProgressLabel.Parent := FImportProgressForm;
        FImportProgressLabel.SetBounds(12, 12, 488, 24);
        FImportProgressLabel.Caption := 'Preparing import...';

        FImportProgressBar := TProgressBar.Create(FImportProgressForm);
        FImportProgressBar.Parent := FImportProgressForm;
        FImportProgressBar.SetBounds(12, 42, 488, 22);
        FImportProgressBar.Min := 0;
        FImportProgressBar.Max := 1000;

        LButton := TButton.Create(FImportProgressForm);
        LButton.Parent := FImportProgressForm;
        LButton.SetBounds(410, 78, 90, 30);
        LButton.Caption := 'Stop';
        LButton.OnClick := @StopImportClick;

        ShowFormCenteredOnOwner(FImportProgressForm, Self);
        FDatabase.ImportPdnFile(Dialog.FileName, Imported, Duplicates, Errors,
          @ImportProgress, LogFileName);
      finally
        FreeAndNil(FImportProgressForm);
        FImportProgressBar := nil;
        FImportProgressLabel := nil;
      end;
      PopulateGamesGrid;
      if FImportCancel then
        FStatusLabel.Caption := 'Stopped after importing ' +
          IntToStr(Imported) + ' game(s), errors ' + IntToStr(Errors) +
          ', duplicates ' + IntToStr(Duplicates) + '; log ' +
          ExtractFileName(LogFileName)
      else
        FStatusLabel.Caption := 'Imported ' + IntToStr(Imported) +
          ' game(s), errors ' + IntToStr(Errors) +
          ', duplicates ' + IntToStr(Duplicates) + '; log ' +
          ExtractFileName(LogFileName);
    except
      on E: Exception do
        ShowGuiTextDialog(Self, 'Import PDN',
          E.Message + LineEnding + LineEnding + 'Import log: ' + LogFileName);
    end;
  finally
    Dialog.Free;
  end;
end;

end.
