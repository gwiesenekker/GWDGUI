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
    FDatabase: TGameDatabase;
    FFenEdit: TEdit;
    FGameInfos: TList;
    FGamesGrid: TStringGrid;
    FImportCancel: Boolean;
    FImportProgressBar: TProgressBar;
    FImportProgressForm: TForm;
    FImportProgressLabel: TLabel;
    FImportStartTick: QWord;
    FPreferences: TGuiPreferences;
    FResults: TList;
    FResultsGrid: TStringGrid;
    FPositionSetupForm: TPositionSetupForm;
    FStatusLabel: TLabel;
    procedure BoardCopyFenClick(Sender: TObject);
    procedure BoardPasteFenClick(Sender: TObject);
    procedure ClearObjectList(AList: TList);
    procedure FormCloseHandler(Sender: TObject; var CloseAction: TCloseAction);
    procedure ImportProgress(ABytesRead, ATotalBytes: Int64; AImported,
      AErrors: Integer; var ACancel: Boolean);
    procedure ImportProgressCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure ImportPdnClick(Sender: TObject);
    procedure PopulateGamesGrid;
    procedure PopulateResultsGrid;
    procedure SearchClick(Sender: TObject);
    procedure SetFenClick(Sender: TObject);
    procedure SetupPositionAccepted(Sender: TObject; const AFEN: string);
    procedure SetupPositionClick(Sender: TObject);
    procedure StopImportClick(Sender: TObject);
    procedure UpdateBoardFromFen;
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
  DatabaseGridGameLimit = 5000;

constructor TDatabaseForm.Create(AOwner: TComponent);
var
  LBoardPanel: TPanel;
  LBoardPopup: TPopupMenu;
  LButton: TButton;
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

  FGamesGrid := TStringGrid.Create(Self);
  FGamesGrid.Parent := LTopPanel;
  FGamesGrid.Align := alClient;
  FGamesGrid.FixedCols := 0;
  FGamesGrid.FixedRows := 1;
  FGamesGrid.ColCount := 6;
  FGamesGrid.RowCount := 2;
  FGamesGrid.Options := FGamesGrid.Options + [goRowSelect] -
    [goEditing, goRangeSelect];
  FGamesGrid.Cells[0, 0] := 'White';
  FGamesGrid.Cells[1, 0] := 'Black';
  FGamesGrid.Cells[2, 0] := 'Event';
  FGamesGrid.Cells[3, 0] := 'Result';
  FGamesGrid.Cells[4, 0] := 'Starting FEN';
  FGamesGrid.Cells[5, 0] := 'Plies';
  FGamesGrid.ColWidths[0] := 160;
  FGamesGrid.ColWidths[1] := 160;
  FGamesGrid.ColWidths[2] := 280;
  FGamesGrid.ColWidths[3] := 70;
  FGamesGrid.ColWidths[4] := 190;
  FGamesGrid.ColWidths[5] := 60;

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

  LButton := TButton.Create(Self);
  LButton.Parent := LBoardPanel;
  LButton.Align := alTop;
  LButton.Caption := 'Search';
  LButton.OnClick := @SearchClick;

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
  AImported, AErrors: Integer; var ACancel: Boolean);
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
    Format('Imported %d game(s), errors %d, %.1f MB / %.1f MB, elapsed %.1f s',
      [AImported, AErrors, ABytesRead / 1048576, ATotalBytes / 1048576,
      ElapsedSeconds]);
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
  FStatusLabel.Caption := 'Created ' + AFileName;
end;

procedure TDatabaseForm.OpenDatabase(const AFileName: string);
begin
  FDatabase.OpenDatabase(AFileName);
  Caption := 'Database - ' + ExtractFileName(AFileName);
  PopulateGamesGrid;
  PopulateResultsGrid;
  FStatusLabel.Caption := 'Opened ' + AFileName;
end;

procedure TDatabaseForm.SetSearchFEN(const AFEN: string);
begin
  FFenEdit.Text := AFEN;
  UpdateBoardFromFen;
end;

procedure TDatabaseForm.PopulateGamesGrid;
var
  Info: TDatabaseGameInfo;
  Row: Integer;
begin
  FDatabase.LoadGames(FGameInfos, DatabaseGridGameLimit);
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
  end;
  for Row := 1 to FGameInfos.Count do
  begin
    Info := TDatabaseGameInfo(FGameInfos[Row - 1]);
    FGamesGrid.Cells[0, Row] := Info.WhiteName;
    FGamesGrid.Cells[1, Row] := Info.BlackName;
    FGamesGrid.Cells[2, Row] := Info.EventName;
    FGamesGrid.Cells[3, Row] := Info.ResultText;
    FGamesGrid.Cells[4, Row] := Info.StartingFEN;
    FGamesGrid.Cells[5, Row] := IntToStr(Info.PlyCount);
  end;
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
  try
    UpdateBoardFromFen;
    FDatabase.SearchPosition(FBoard.PositionKey, FBoard.SideToMove, FResults);
    PopulateResultsGrid;
    FStatusLabel.Caption := IntToStr(FResults.Count) +
      ' continuation(s) found for ' + FBoard.CurrentFEN;
  except
    on E: Exception do
      ShowGuiOkDialog(Self, 'Database search', E.Message);
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
  Errors: Integer;
  Imported: Integer;
  LButton: TButton;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := 'Import PDN';
    Dialog.Filter := 'PDN files|*.pdn|All files|*';
    if not Dialog.Execute then
      Exit;
    try
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
        FDatabase.ImportPdnFile(Dialog.FileName, Imported, Errors,
          @ImportProgress);
      finally
        FreeAndNil(FImportProgressForm);
        FImportProgressBar := nil;
        FImportProgressLabel := nil;
      end;
      PopulateGamesGrid;
      if FImportCancel then
        FStatusLabel.Caption := 'Stopped after importing ' +
          IntToStr(Imported) + ' game(s), errors ' + IntToStr(Errors)
      else
        FStatusLabel.Caption := 'Imported ' + IntToStr(Imported) +
          ' game(s), errors ' + IntToStr(Errors);
    except
      on E: Exception do
        ShowGuiTextDialog(Self, 'Import PDN', E.Message);
    end;
  finally
    Dialog.Free;
  end;
end;

end.
