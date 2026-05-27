unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  Clipbrd,
  Controls,
  Dialogs,
  DraughtsRules,
  EasyLazFreeType,
  EngineParams,
  ExtCtrls,
  FPImage,
  Forms,
  GraphType,
  Graphics,
  IntfGraphics,
  LazFreeTypeIntfDrawer,
  LazFreeTypeFontCollection,
  Menus,
  PDNSaveDialog,
  Process,
  SetupDialog,
  Spin,
  StdCtrls,
  LCLType
  {$IFDEF MSWINDOWS}
  , Windows
  {$ENDIF}
  , Types;

type
  TMainWindow = class;

  TClockThread = class(TThread)
  private
    FOwner: TMainWindow;
    procedure Tick;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TMainWindow);
  end;

  {$IFDEF MSWINDOWS}
  TEngineReaderThread = class(TThread)
  private
    FChunk: String;
    FOwner: TMainWindow;
    FReadHandle: THandle;
    procedure DeliverChunk;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TMainWindow; AReadHandle: THandle);
  end;
  {$ENDIF}

  TIntegerArray = array of Integer;
  TTextArray = array of String;
  TClockSnapshot = record
    HasClock: Boolean;
    WhiteSeconds: Double;
    BlackSeconds: Double;
  end;
  TClockSnapshotArray = array of TClockSnapshot;
  TEngineState = (esIdle, esPondering, esMcts, esThinking);
  TEngineSearchMode = (esmIdle, esmPonder, esmMcts, esmAutoPlay,
    esmPlayGameThink, esmPlayGamePonder);

  TMainWindow = class(TForm)
  private
    FBoard: TBoard;
    FBoardRect: TRect;
    FAutoPlayActive: Boolean;
    FAutoPlayButton: TButton;
    FAutoPlayPlyCount: Integer;
    FEngineLogMemo: TMemo;
    FEngineMoveTimeSpin: TFloatSpinEdit;
    FEngineOpenDialog: TOpenDialog;
    FEngineParams: TEngineParamArray;
    FEngineParamsFileName: String;
    FEnginePanel: TPanel;
    {$IFDEF MSWINDOWS}
    FEngineInputWriteHandle: THandle;
    FEngineOutputReadHandle: THandle;
    FEngineProcessInfo: TProcessInformation;
    FEngineReaderThread: TEngineReaderThread;
    FEngineRunning: Boolean;
    {$ELSE}
    FEngineProcess: TProcess;
    {$ENDIF}
    FEnginePollTimer: TTimer;
    FEngineReady: Boolean;
    FEngineSearching: Boolean;
    FEngineSearchMode: TEngineSearchMode;
    FEngineFirstReadSeen: Boolean;
    FEngineLogPopupMenu: TPopupMenu;
    FEngineStartAfterReady: Boolean;
    FEngineState: TEngineState;
    FEngineTextBuffer: String;
    FEngineWaitingForInit: Boolean;
    FEngineStopRequested: Boolean;
    FEditEngineParamsMenuItem: TMenuItem;
    FEditMenu: TMenuItem;
    FEngineMenu: TMenuItem;
    FShuttingDown: Boolean;
    FIgnoreNextDoneMove: Boolean;
    FLastEngineDoneLine: String;
    FLastEngineInfoAnnotation: String;
    FGoButton: TButton;
    FMctsButton: TButton;
    FFileMenu: TMenuItem;
    FGameBlackName: String;
    FGameDirty: Boolean;
    FGameResult: String;
    FGameWhiteName: String;
    FBlackClockSeconds: Double;
    FBoardFlipped: Boolean;
    FButtonPanel: TPanel;
    FBoardPaintBox: TPaintBox;
    FBoardPanel: TPanel;
    FBoardTopClockLabel: TLabel;
    FBoardBottomClockLabel: TLabel;
    FClocksActive: Boolean;
    FClockLastTick: Double;
    FClockTimer: TTimer;
    {$IFDEF MSWINDOWS}
    FClockThread: TClockThread;
    {$ENDIF}
    FHistoryBaseBoard: TBoard;
    FHistoryBaseSide: TSide;
    FHistoryBlackEdit: TEdit;
    FHistoryBlackLabel: TLabel;
    FHistoryFenLabel: TLabel;
    FHistoryFenMemo: TMemo;
    FHistoryMemo: TMemo;
    FHistoryClockSnapshots: TClockSnapshotArray;
    FHistoryMoveAnnotations: TTextArray;
    FHistoryMoveLengths: TIntegerArray;
    FHistoryMoveStarts: TIntegerArray;
    FHistoryMoves: TMoveArray;
    FHistoryResultEdit: TEdit;
    FHistoryResultLabel: TLabel;
    FHistoryWhiteEdit: TEdit;
    FHistoryWhiteLabel: TLabel;
    FWhiteClockSeconds: Double;
    FInitialBlackClockSeconds: Double;
    FInitialWhiteClockSeconds: Double;
    FLastMoveTargetSquare: Integer;
    FOnlyMoveSourceSquare: Integer;
    FPonderBestSourceSquare: Integer;
    FCurrentPly: Integer;
    FCopyFenMenuItem: TMenuItem;
    FMainMenu: TMainMenu;
    FLegalMovesPanel: TPanel;
    FMoves: TMoveArray;
    FMovesMemo: TMemo;
    FMovePanel: TPanel;
    FOpenDialog: TOpenDialog;
    FOpenEngineMenuItem: TMenuItem;
    FOpenFenMenuItem: TMenuItem;
    FOpenPdnDialog: TOpenDialog;
    FOpenPdnMenuItem: TMenuItem;
    FPieceDrawer: TIntfFreeTypeDrawer;
    FPieceFont: TFreeTypeFont;
    FPieceImage: TLazIntfImage;
    FPendingAutoPlayStart: Boolean;
    FPendingPonderMode: TEngineSearchMode;
    FPendingPonderStart: Boolean;
    FPendingMctsStart: Boolean;
    FPendingPlayGameFromCurrent: Boolean;
    FPendingPlayGameMinutes: Double;
    FPendingPlayGameSide: TSide;
    FPendingPlayGameStart: Boolean;
    FPendingThinkMode: TEngineSearchMode;
    FPendingThinkStart: Boolean;
    FPlayGameActive: Boolean;
    FPlayGameBlackRadio: TRadioButton;
    FPlayGameButton: TButton;
    FPlayGameCurrentPositionRadio: TRadioButton;
    FPlayGameDialog: TForm;
    FPlayGameHumanSide: TSide;
    FPlayGameMinutesSpin: TFloatSpinEdit;
    FRootPanel: TPanel;
    FQuitMenuItem: TMenuItem;
    FSaveEngineLogDialog: TSaveDialog;
    FSaveEngineLogMenuItem: TMenuItem;
    FSavePdnDialog: TSaveDialog;
    FSavePdnMenuItem: TMenuItem;
    FSavePdnOptionsDialog: TPDNSaveDialog;
    FSelectedSquare: Integer;
    FSetupPositionDialog: TSetupPositionDialog;
    FShutdownAfterPdnSave: Boolean;
    FShutdownConfirmed: Boolean;
    FUnsavedGamePromptDialog: TForm;
    FAmbiguousTargetSquares: array[1..50] of Boolean;
    FTargetSquares: array[1..50] of Boolean;
    FSetupPositionMenuItem: TMenuItem;
    FSideToMove: TSide;
    FSideToMoveLabel: TLabel;
    FStopButton: TButton;
    procedure ApplyMove(const AMove: TMove);
    procedure AppendEngineLog(const AText: String);
    procedure BeginAutoPlay;
    procedure BeginPlayGame(AHumanSide: TSide; AGameMinutes: Double;
      AStartFromCurrent: Boolean;
      AStartSearch: Boolean = True);
    procedure BoardPaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure BoardPaintBoxPaint(Sender: TObject);
    procedure ClockTimerTimer(Sender: TObject);
    procedure ClearBoardSelection;
    procedure ClearBoard;
    procedure CopyFenMenuItemClick(Sender: TObject);
    procedure CloseEngine;
    procedure DrawBoard(ACanvas: TCanvas);
    procedure DrawBoardClockLabels(const ABoardRect: TRect);
    procedure DrawPiece(ACanvas: TCanvas; const ASquare: TRect;
      APiece: TPiece; ACellSize: Integer; ASquareColor: TColor);
    function BoardSquareAtCell(ARow, ACol: Integer): Integer;
    procedure EngineProcessReadData(Sender: TObject);
    procedure EnginePollTimerTimer(Sender: TObject);
    procedure EngineProcessTerminate(Sender: TObject);
    function EngineMoveIndex(const AEngineMove: String): Integer;
    function EngineMoveMatchesLegalMove(const AEngineMove: String;
      const ALegalMove: TMove): Boolean;
    function EngineIsRunning: Boolean;
    procedure AutoPlayButtonClick(Sender: TObject);
    procedure GoButtonClick(Sender: TObject);
    function PlayEngineMove(const AEngineMove: String): Boolean;
    function HubPositionString: String;
    function HubPositionStringFor(const ABoard: TBoard; ASide: TSide): String;
    function HubPositionCommand: String;
    function CurrentEngineRemainingTimeSeconds: Double;
    function IsPlayGameHumanTurn: Boolean;
    procedure InvalidateBoard;
    function BoardToFen(const ABoard: TBoard; ASide: TSide): String;
    function BuildPdnMoveText(const AResult: String; AStoreRanges: Boolean): String;
    function ClockAnnotation(APly: Integer): String;
    function EngineInfoAnnotation(const ALine: String): String;
    function GuessResultFromFinalPosition: String;
    procedure HistoryMemoClick(Sender: TObject);
    procedure HistoryMemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleEngineDoneMove(const AMoveText: String);
    procedure LoadFenFile(const AFileName: String);
    procedure LoadPdnFile(const AFileName: String);
    procedure LeavePlayGameMode;
    procedure MoveListMoveClick(Sender: TObject);
    procedure MctsButtonClick(Sender: TObject);
    procedure MovesMemoDblClick(Sender: TObject);
    procedure OpenEngineMenuItemClick(Sender: TObject);
    procedure OpenFenMenuItemClick(Sender: TObject);
    procedure OpenPdnMenuItemClick(Sender: TObject);
    procedure ParseFen(const AFen: String);
    procedure PlacePiece(APosition: Integer; APiece: TPiece);
    procedure PlayGameButtonClick(Sender: TObject);
    procedure PlayGameDialogButtonClick(Sender: TObject);
    procedure PlayGameDialogHide(Sender: TObject);
    procedure RebuildPositionToPly(APly: Integer);
    procedure RecordPlayedMove(const AMove: TMove; const AAnnotation: String = '');
    procedure RestoreClockSnapshot(APly: Integer);
    procedure ResetClocks;
    procedure ResetHistoryFromCurrentPosition;
    procedure NavigateHistoryToPly(APly: Integer);
    procedure MainWindowCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure MarkGameDirty;
    procedure QuitMenuItemClick(Sender: TObject);
    procedure SelectHistoryPly(APly: Integer);
    procedure SelectBoardSquare(ASquare: Integer);
    function SquareAtPoint(X, Y: Integer): Integer;
    procedure ProcessEngineOutput(const AText: String);
    procedure EditEngineParamsMenuItemClick(Sender: TObject);
    procedure EngineParamsDialogHide(Sender: TObject);
    procedure SendEngineParams;
    procedure SetupMenu;
    procedure SetupBoardArea;
    procedure SetupEngineLog;
    procedure SetupMoveList;
    procedure SetupPieceFont;
    procedure SetupPositionMenuItemClick(Sender: TObject);
    procedure SetupPositionDialogHide(Sender: TObject);
    procedure ShutdownApplication;
    procedure FinalizeShutdown;
    procedure ShowUnsavedGamePrompt;
    procedure UnsavedGamePromptButtonClick(Sender: TObject);
    procedure UnsavedGamePromptHide(Sender: TObject);
    procedure ShowPlayGameDialog;
    procedure StartGameClocks(AGameMinutes: Double);
    procedure StartPlayGameFromOptions(AHumanSide: TSide; AGameMinutes: Double;
      AStartFromCurrent: Boolean);
    procedure StartEngine(const AFileName: String);
    procedure SendEngineCommand(const ACommand: String);
    procedure SetEngineState(AState: TEngineState);
    procedure SendPlayGameHumanTurnPonder;
    procedure SendGoPonderToEngine(AMode: TEngineSearchMode = esmPonder);
    procedure SendGoMctsToEngine;
    procedure SendGoThinkToEngine(AMode: TEngineSearchMode = esmAutoPlay);
    procedure RestartEnginePonder;
    procedure SendStopToEngine;
    procedure SendPositionMenuItemClick(Sender: TObject);
    procedure SendPositionToEngine;
    procedure SavePdnMenuItemClick(Sender: TObject);
    procedure SavePdnOptionsDialogHide(Sender: TObject);
    procedure SaveEngineLogMenuItemClick(Sender: TObject);
    procedure SavePdnFile(const AFileName, AWhiteName, ABlackName, AResult: String);
    procedure StopButtonClick(Sender: TObject);
    procedure StopGameClocks;
    procedure ExecuteMoveFromList(AMoveIndex: Integer; AContinueEngine: Boolean);
    procedure ExecuteLegalMoveIndex(AMoveIndex: Integer; AContinueEngine: Boolean);
    procedure UpdateClockLabels;
    procedure UpdateGameClock;
    procedure UpdateHistoryList;
    procedure UpdateMoveList;
    procedure UpdatePonderBestMoveFromMoveText(const AMoveText: String);
    procedure UpdatePonderBestMoveFromInfo(const ALine: String);
  protected
    procedure KeyDown(var Key: Word; Shift: TShiftState); override;
    procedure Resize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  MainWindow: TMainWindow;

implementation

uses
  EngineParamDialog,
  FileUtil,
  Math,
  StrUtils,
  SysUtils;

const
  BoardSize = 10;
  LayoutMargin = 6;
  BoardMargin = 32;
  WoodSquareColor = TColor($00305E8B);
  PonderBestSourceColor = TColor($0000A5FF);

function EngineLogTimestamp: String; forward;

constructor TClockThread.Create(AOwner: TMainWindow);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  Start;
end;

procedure TClockThread.Tick;
begin
  if FOwner <> nil then
    FOwner.UpdateGameClock;
end;

procedure TClockThread.Execute;
begin
  while not Terminated do
  begin
    Sleep(250);
    if not Terminated then
      Synchronize(@Tick);
  end;
end;

{$IFDEF MSWINDOWS}
constructor TEngineReaderThread.Create(AOwner: TMainWindow; AReadHandle: THandle);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FReadHandle := AReadHandle;
  Start;
end;

procedure TEngineReaderThread.DeliverChunk;
begin
  if (FOwner <> nil) and (FChunk <> '') then
  begin
    if not FOwner.FEngineFirstReadSeen then
    begin
      FOwner.FEngineFirstReadSeen := True;
      FOwner.AppendEngineLog('[engine first read ' + EngineLogTimestamp +
        ' thread bytes=' + IntToStr(Length(FChunk)) + ']' + LineEnding);
    end;
    FOwner.AppendEngineLog(FChunk);
    FOwner.ProcessEngineOutput(FChunk);
  end;
end;

procedure TEngineReaderThread.Execute;
var
  Buffer: array[0..4095] of Byte;
  BytesRead: DWORD;
begin
  while (not Terminated) and (FReadHandle <> 0) do
  begin
    BytesRead := 0;
    if (not ReadFile(FReadHandle, Buffer[0], SizeOf(Buffer), BytesRead, nil)) or
      (BytesRead = 0) then
      Break;

    SetString(FChunk, PChar(@Buffer[0]), BytesRead);
    Synchronize(@DeliverChunk);
  end;
end;
{$ENDIF}

constructor TMainWindow.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Caption := 'International Draughts';
  Color := clBtnFace;
  Constraints.MinWidth := 700;
  Constraints.MinHeight := 440;
  Width := 1280;
  Height := 900;
  DoubleBuffered := True;
  KeyPreview := True;
  OnCloseQuery := @MainWindowCloseQuery;
  FBoardFlipped := False;
  FShuttingDown := False;
  FSideToMove := sideWhite;
  FGameWhiteName := 'White';
  FGameBlackName := 'Black';
  FGameResult := '*';
  FGameDirty := False;
  FShutdownAfterPdnSave := False;
  FShutdownConfirmed := False;
  ClearBoardSelection;

  ClearBoard;
  ResetHistoryFromCurrentPosition;
  FClockTimer := TTimer.Create(Self);
  FClockTimer.Enabled := False;
  FClockTimer.Interval := 250;
  FClockTimer.OnTimer := @ClockTimerTimer;
  FEnginePollTimer := TTimer.Create(Self);
  FEnginePollTimer.Enabled := False;
  FEnginePollTimer.Interval := 50;
  FEnginePollTimer.OnTimer := @EnginePollTimerTimer;
  {$IFDEF MSWINDOWS}
  FEngineInputWriteHandle := 0;
  FEngineOutputReadHandle := 0;
  FillChar(FEngineProcessInfo, SizeOf(FEngineProcessInfo), 0);
  FEngineReaderThread := nil;
  FEngineRunning := False;
  FClockThread := TClockThread.Create(Self);
  {$ENDIF}
  SetupMenu;
  SetupBoardArea;
  SetupEngineLog;
  SetupMoveList;
  SetupPieceFont;
  ResetClocks;
  UpdateMoveList;
  UpdateHistoryList;
end;

destructor TMainWindow.Destroy;
begin
  {$IFDEF MSWINDOWS}
  if FClockThread <> nil then
  begin
    FClockThread.Terminate;
    FClockThread.WaitFor;
    FreeAndNil(FClockThread);
  end;
  {$ENDIF}
  CloseEngine;
  FPieceFont.Free;
  FPieceDrawer.Free;
  FPieceImage.Free;
  inherited Destroy;
end;

procedure TMainWindow.ClearBoard;
var
  BoardPosition: Integer;
begin
  for BoardPosition := Low(FBoard) to High(FBoard) do
    FBoard[BoardPosition] := pcNone;
end;

procedure TMainWindow.ClearBoardSelection;
begin
  FSelectedSquare := 0;
  FillChar(FTargetSquares, SizeOf(FTargetSquares), 0);
  FillChar(FAmbiguousTargetSquares, SizeOf(FAmbiguousTargetSquares), 0);
  FPonderBestSourceSquare := 0;
end;

procedure TMainWindow.SetupMoveList;
var
  HistoryLabel: TLabel;
  HistoryMetaPanel: TPanel;
  HistoryPanel: TPanel;
  FenPanel: TPanel;
  RowPanel: TPanel;
  Splitter: TSplitter;
begin
  FMovePanel := TPanel.Create(FRootPanel);
  FMovePanel.Parent := FRootPanel;
  FMovePanel.Align := alRight;
  FMovePanel.Width := 420;
  FMovePanel.Constraints.MinWidth := 320;
  FMovePanel.BevelOuter := bvNone;
  FMovePanel.BorderSpacing.Right := LayoutMargin;

  Splitter := TSplitter.Create(FRootPanel);
  Splitter.Parent := FRootPanel;
  Splitter.Align := alRight;
  Splitter.ResizeAnchor := akRight;
  Splitter.Width := 6;

  FSideToMoveLabel := TLabel.Create(FMovePanel);
  FSideToMoveLabel.Parent := FMovePanel;
  FSideToMoveLabel.Align := alTop;
  FSideToMoveLabel.BorderSpacing.Around := 8;
  FSideToMoveLabel.Font.Style := [fsBold];

  FLegalMovesPanel := TPanel.Create(FBoardPanel);
  FLegalMovesPanel.Parent := FBoardPanel;
  FLegalMovesPanel.Align := alNone;
  FLegalMovesPanel.Width := 180;
  FLegalMovesPanel.Constraints.MinWidth := 150;
  FLegalMovesPanel.BevelOuter := bvNone;

  FMovesMemo := TMemo.Create(FLegalMovesPanel);
  FMovesMemo.Parent := FLegalMovesPanel;
  FMovesMemo.Align := alClient;
  FMovesMemo.ReadOnly := True;
  FMovesMemo.ScrollBars := ssVertical;
  FMovesMemo.WordWrap := False;
  FMovesMemo.TabStop := False;
  FMovesMemo.OnClick := @MoveListMoveClick;

  HistoryPanel := TPanel.Create(FMovePanel);
  HistoryPanel.Parent := FMovePanel;
  HistoryPanel.Align := alClient;
  HistoryPanel.BevelOuter := bvLowered;
  HistoryPanel.BorderSpacing.Left := 6;
  HistoryPanel.BorderSpacing.Right := 0;
  HistoryPanel.BorderSpacing.Bottom := 6;

  HistoryLabel := TLabel.Create(HistoryPanel);
  HistoryLabel.Parent := HistoryPanel;
  HistoryLabel.Align := alTop;
  HistoryLabel.Caption := 'Played moves';
  HistoryLabel.BorderSpacing.Left := 8;
  HistoryLabel.BorderSpacing.Right := 0;
  HistoryLabel.BorderSpacing.Bottom := 4;

  HistoryMetaPanel := TPanel.Create(HistoryPanel);
  HistoryMetaPanel.Parent := HistoryPanel;
  HistoryMetaPanel.Align := alTop;
  HistoryMetaPanel.Height := 178;
  HistoryMetaPanel.BevelOuter := bvNone;
  HistoryMetaPanel.BorderSpacing.Left := 8;
  HistoryMetaPanel.BorderSpacing.Right := 0;
  HistoryMetaPanel.BorderSpacing.Bottom := 4;

  RowPanel := TPanel.Create(HistoryMetaPanel);
  RowPanel.Parent := HistoryMetaPanel;
  RowPanel.SetBounds(0, 0, 190, 28);
  RowPanel.Anchors := [akLeft, akTop, akRight];
  RowPanel.BevelOuter := bvNone;

  FHistoryWhiteLabel := TLabel.Create(RowPanel);
  FHistoryWhiteLabel.Parent := RowPanel;
  FHistoryWhiteLabel.SetBounds(0, 4, 52, 20);
  FHistoryWhiteLabel.Caption := 'White:';

  FHistoryWhiteEdit := TEdit.Create(RowPanel);
  FHistoryWhiteEdit.Parent := RowPanel;
  FHistoryWhiteEdit.SetBounds(52, 0, 138, 28);
  FHistoryWhiteEdit.Anchors := [akLeft, akTop, akRight];
  FHistoryWhiteEdit.ReadOnly := True;

  RowPanel := TPanel.Create(HistoryMetaPanel);
  RowPanel.Parent := HistoryMetaPanel;
  RowPanel.SetBounds(0, 30, 190, 28);
  RowPanel.Anchors := [akLeft, akTop, akRight];
  RowPanel.BevelOuter := bvNone;

  FHistoryBlackLabel := TLabel.Create(RowPanel);
  FHistoryBlackLabel.Parent := RowPanel;
  FHistoryBlackLabel.SetBounds(0, 4, 52, 20);
  FHistoryBlackLabel.Caption := 'Black:';

  FHistoryBlackEdit := TEdit.Create(RowPanel);
  FHistoryBlackEdit.Parent := RowPanel;
  FHistoryBlackEdit.SetBounds(52, 0, 138, 28);
  FHistoryBlackEdit.Anchors := [akLeft, akTop, akRight];
  FHistoryBlackEdit.ReadOnly := True;

  RowPanel := TPanel.Create(HistoryMetaPanel);
  RowPanel.Parent := HistoryMetaPanel;
  RowPanel.SetBounds(0, 60, 190, 28);
  RowPanel.Anchors := [akLeft, akTop, akRight];
  RowPanel.BevelOuter := bvNone;

  FHistoryResultLabel := TLabel.Create(RowPanel);
  FHistoryResultLabel.Parent := RowPanel;
  FHistoryResultLabel.Align := alLeft;
  FHistoryResultLabel.Width := 52;
  FHistoryResultLabel.Caption := 'Result:';

  FHistoryResultEdit := TEdit.Create(RowPanel);
  FHistoryResultEdit.Parent := RowPanel;
  FHistoryResultEdit.Align := alClient;
  FHistoryResultEdit.ReadOnly := True;

  FenPanel := TPanel.Create(HistoryMetaPanel);
  FenPanel.Parent := HistoryMetaPanel;
  FenPanel.SetBounds(0, 92, 190, 82);
  FenPanel.Anchors := [akLeft, akTop, akRight];
  FenPanel.BevelOuter := bvNone;

  FHistoryFenLabel := TLabel.Create(FenPanel);
  FHistoryFenLabel.Parent := FenPanel;
  FHistoryFenLabel.SetBounds(0, 0, 52, 18);
  FHistoryFenLabel.Caption := 'FEN:';

  FHistoryFenMemo := TMemo.Create(FenPanel);
  FHistoryFenMemo.Parent := FenPanel;
  FHistoryFenMemo.SetBounds(0, 20, 190, 58);
  FHistoryFenMemo.Anchors := [akLeft, akTop, akRight];
  FHistoryFenMemo.ReadOnly := True;
  FHistoryFenMemo.ScrollBars := ssHorizontal;
  FHistoryFenMemo.WordWrap := False;

  FHistoryMemo := TMemo.Create(Self);
  FHistoryMemo.Parent := HistoryPanel;
  FHistoryMemo.Align := alClient;
  FHistoryMemo.ReadOnly := True;
  FHistoryMemo.ScrollBars := ssVertical;
  FHistoryMemo.WordWrap := True;
  FHistoryMemo.OnClick := @HistoryMemoClick;
  FHistoryMemo.OnKeyDown := @HistoryMemoKeyDown;
end;

procedure TMainWindow.SetupEngineLog;
var
  Splitter: TSplitter;
begin
  FEnginePanel := TPanel.Create(Self);
  FEnginePanel.Parent := Self;
  FEnginePanel.Align := alBottom;
  FEnginePanel.Height := 160;
  FEnginePanel.Constraints.MinHeight := 96;
  FEnginePanel.BevelOuter := bvNone;

  Splitter := TSplitter.Create(Self);
  Splitter.Parent := Self;
  Splitter.Align := alBottom;
  Splitter.ResizeAnchor := akBottom;
  Splitter.Height := 6;

  FEngineLogMemo := TMemo.Create(FEnginePanel);
  FEngineLogMemo.Parent := FEnginePanel;
  FEngineLogMemo.Align := alClient;
  FEngineLogMemo.BorderSpacing.Left := LayoutMargin;
  FEngineLogMemo.BorderSpacing.Right := LayoutMargin;
  FEngineLogMemo.BorderSpacing.Bottom := 6;
  FEngineLogMemo.ReadOnly := True;
  FEngineLogMemo.ScrollBars := ssBoth;
  FEngineLogMemo.WordWrap := False;
  FEngineLogMemo.TabStop := False;

  FEngineLogPopupMenu := TPopupMenu.Create(Self);
  FSaveEngineLogMenuItem := TMenuItem.Create(FEngineLogPopupMenu);
  FSaveEngineLogMenuItem.Caption := 'Save as...';
  FSaveEngineLogMenuItem.OnClick := @SaveEngineLogMenuItemClick;
  FEngineLogPopupMenu.Items.Add(FSaveEngineLogMenuItem);
  FEngineLogMemo.PopupMenu := FEngineLogPopupMenu;

  FEngineLogMemo.Lines.Add('Engine output');
end;

procedure TMainWindow.SetupBoardArea;
var
  ButtonPanel: TPanel;
  SpinPanel: TPanel;
  Toolbar: TPanel;
begin
  FRootPanel := TPanel.Create(Self);
  FRootPanel.Parent := Self;
  FRootPanel.Align := alClient;
  FRootPanel.BevelOuter := bvNone;

  FBoardPanel := TPanel.Create(FRootPanel);
  FBoardPanel.Parent := FRootPanel;
  FBoardPanel.Align := alClient;
  FBoardPanel.BevelOuter := bvNone;
  FBoardPanel.Color := Color;
  FBoardPanel.Constraints.MinWidth := 260;
  FBoardPanel.Constraints.MinHeight := 260;

  Toolbar := TPanel.Create(FBoardPanel);
  Toolbar.Parent := FBoardPanel;
  Toolbar.Align := alTop;
  Toolbar.Height := 48;
  Toolbar.BevelOuter := bvNone;
  Toolbar.BorderSpacing.Top := 6;
  Toolbar.BorderSpacing.Bottom := 6;

  ButtonPanel := TPanel.Create(Toolbar);
  FButtonPanel := ButtonPanel;
  ButtonPanel.Parent := Toolbar;
  ButtonPanel.Align := alNone;
  ButtonPanel.Width := 534;
  ButtonPanel.Height := 34;
  ButtonPanel.BevelOuter := bvLowered;
  ButtonPanel.SetBounds(LayoutMargin, 3, 534, 34);

  FPlayGameButton := TButton.Create(ButtonPanel);
  FPlayGameButton.Parent := ButtonPanel;
  FPlayGameButton.SetBounds(4, 4, 92, 26);
  FPlayGameButton.Anchors := [akLeft, akTop];
  FPlayGameButton.Caption := 'Play game';
  FPlayGameButton.OnClick := @PlayGameButtonClick;
  FPlayGameButton.Enabled := False;

  FAutoPlayButton := TButton.Create(ButtonPanel);
  FAutoPlayButton.Parent := ButtonPanel;
  FAutoPlayButton.SetBounds(104, 4, 92, 26);
  FAutoPlayButton.Anchors := [akLeft, akTop];
  FAutoPlayButton.Caption := 'Auto Play';
  FAutoPlayButton.OnClick := @AutoPlayButtonClick;
  FAutoPlayButton.Enabled := False;

  SpinPanel := TPanel.Create(ButtonPanel);
  SpinPanel.Parent := ButtonPanel;
  SpinPanel.SetBounds(204, 4, 94, 26);
  SpinPanel.Anchors := [akLeft, akTop];
  SpinPanel.BevelOuter := bvNone;

  FEngineMoveTimeSpin := TFloatSpinEdit.Create(SpinPanel);
  FEngineMoveTimeSpin.Parent := SpinPanel;
  FEngineMoveTimeSpin.SetBounds(0, 0, 82, 26);
  FEngineMoveTimeSpin.Anchors := [akLeft, akTop];
  FEngineMoveTimeSpin.DecimalPlaces := 3;
  FEngineMoveTimeSpin.Increment := 0.1;
  FEngineMoveTimeSpin.MinValue := 0.001;
  FEngineMoveTimeSpin.MaxValue := 3600;
  FEngineMoveTimeSpin.Value := 1.0;

  FStopButton := TButton.Create(ButtonPanel);
  FStopButton.Parent := ButtonPanel;
  FStopButton.SetBounds(462, 4, 70, 26);
  FStopButton.Anchors := [akLeft, akTop];
  FStopButton.Caption := 'STOP';
  FStopButton.OnClick := @StopButtonClick;
  FStopButton.Enabled := False;

  FGoButton := TButton.Create(ButtonPanel);
  FGoButton.Parent := ButtonPanel;
  FGoButton.SetBounds(384, 4, 70, 26);
  FGoButton.Anchors := [akLeft, akTop];
  FGoButton.Caption := 'Ponder';
  FGoButton.OnClick := @GoButtonClick;
  FGoButton.Enabled := False;

  FMctsButton := TButton.Create(ButtonPanel);
  FMctsButton.Parent := ButtonPanel;
  FMctsButton.SetBounds(306, 4, 70, 26);
  FMctsButton.Anchors := [akLeft, akTop];
  FMctsButton.Caption := 'MCTS';
  FMctsButton.OnClick := @MctsButtonClick;
  FMctsButton.Enabled := False;

  FBoardPaintBox := TPaintBox.Create(FBoardPanel);
  FBoardPaintBox.Parent := FBoardPanel;
  FBoardPaintBox.Align := alClient;
  FBoardPaintBox.OnPaint := @BoardPaintBoxPaint;
  FBoardPaintBox.OnMouseDown := @BoardPaintBoxMouseDown;

  FBoardTopClockLabel := TLabel.Create(FBoardPanel);
  FBoardTopClockLabel.Parent := FBoardPanel;
  FBoardTopClockLabel.AutoSize := False;
  FBoardTopClockLabel.Alignment := taCenter;
  FBoardTopClockLabel.Layout := tlCenter;
  FBoardTopClockLabel.Font.Style := [fsBold];
  FBoardTopClockLabel.Transparent := False;
  FBoardTopClockLabel.Color := clBtnFace;

  FBoardBottomClockLabel := TLabel.Create(FBoardPanel);
  FBoardBottomClockLabel.Parent := FBoardPanel;
  FBoardBottomClockLabel.AutoSize := False;
  FBoardBottomClockLabel.Alignment := taCenter;
  FBoardBottomClockLabel.Layout := tlCenter;
  FBoardBottomClockLabel.Font.Style := [fsBold];
  FBoardBottomClockLabel.Transparent := False;
  FBoardBottomClockLabel.Color := clBtnFace;
end;

procedure TMainWindow.SetupMenu;
begin
  FMainMenu := TMainMenu.Create(Self);
  Menu := FMainMenu;

  FFileMenu := TMenuItem.Create(FMainMenu);
  FFileMenu.Caption := '&File';
  FMainMenu.Items.Add(FFileMenu);

  FEditMenu := TMenuItem.Create(FMainMenu);
  FEditMenu.Caption := '&Edit';
  FMainMenu.Items.Add(FEditMenu);

  FEngineMenu := TMenuItem.Create(FMainMenu);
  FEngineMenu.Caption := 'E&ngine';
  FMainMenu.Items.Add(FEngineMenu);

  FOpenFenMenuItem := TMenuItem.Create(FMainMenu);
  FOpenFenMenuItem.Caption := '&Open FEN...';
  FOpenFenMenuItem.OnClick := @OpenFenMenuItemClick;
  FFileMenu.Add(FOpenFenMenuItem);

  FOpenPdnMenuItem := TMenuItem.Create(FMainMenu);
  FOpenPdnMenuItem.Caption := 'Open &PDN...';
  FOpenPdnMenuItem.OnClick := @OpenPdnMenuItemClick;
  FFileMenu.Add(FOpenPdnMenuItem);

  FSavePdnMenuItem := TMenuItem.Create(FMainMenu);
  FSavePdnMenuItem.Caption := 'Save &PDN...';
  FSavePdnMenuItem.OnClick := @SavePdnMenuItemClick;
  FFileMenu.Add(FSavePdnMenuItem);

  FFileMenu.AddSeparator;

  FQuitMenuItem := TMenuItem.Create(FMainMenu);
  FQuitMenuItem.Caption := '&Quit';
  FQuitMenuItem.ShortCut := ShortCut(VK_Q, [ssCtrl]);
  FQuitMenuItem.OnClick := @QuitMenuItemClick;
  FFileMenu.Add(FQuitMenuItem);

  FCopyFenMenuItem := TMenuItem.Create(FMainMenu);
  FCopyFenMenuItem.Caption := 'Copy &Position to Clipboard';
  FCopyFenMenuItem.OnClick := @CopyFenMenuItemClick;
  FEditMenu.Add(FCopyFenMenuItem);

  FSetupPositionMenuItem := TMenuItem.Create(FMainMenu);
  FSetupPositionMenuItem.Caption := '&Setup Position...';
  FSetupPositionMenuItem.OnClick := @SetupPositionMenuItemClick;
  FEditMenu.Add(FSetupPositionMenuItem);

  FOpenEngineMenuItem := TMenuItem.Create(FMainMenu);
  FOpenEngineMenuItem.Caption := 'Open &Engine...';
  FOpenEngineMenuItem.OnClick := @OpenEngineMenuItemClick;
  FEngineMenu.Add(FOpenEngineMenuItem);

  FEditEngineParamsMenuItem := TMenuItem.Create(FMainMenu);
  FEditEngineParamsMenuItem.Caption := 'Engine &Parameters...';
  FEditEngineParamsMenuItem.OnClick := @EditEngineParamsMenuItemClick;
  FEngineMenu.Add(FEditEngineParamsMenuItem);

  FOpenDialog := TOpenDialog.Create(Self);
  FOpenDialog.Title := 'Open FEN file';
  FOpenDialog.Filter := 'FEN files (*.fen)|*.fen|All files (*.*)|*.*';
  FOpenDialog.Options := FOpenDialog.Options + [ofFileMustExist];

  FOpenPdnDialog := TOpenDialog.Create(Self);
  FOpenPdnDialog.Title := 'Open PDN file';
  FOpenPdnDialog.Filter := 'PDN files (*.pdn)|*.pdn|All files (*.*)|*.*';
  FOpenPdnDialog.Options := FOpenPdnDialog.Options + [ofFileMustExist];

  FSavePdnDialog := TSaveDialog.Create(Self);
  FSavePdnDialog.Title := 'Save PDN file';
  FSavePdnDialog.Filter := 'PDN files (*.pdn)|*.pdn|All files (*.*)|*.*';
  FSavePdnDialog.DefaultExt := 'pdn';
  FSavePdnDialog.Options := FSavePdnDialog.Options + [ofOverwritePrompt];

  FSaveEngineLogDialog := TSaveDialog.Create(Self);
  FSaveEngineLogDialog.Title := 'Save engine log';
  FSaveEngineLogDialog.Filter := 'Text files (*.txt)|*.txt|All files (*.*)|*.*';
  FSaveEngineLogDialog.DefaultExt := 'txt';
  FSaveEngineLogDialog.Options := FSaveEngineLogDialog.Options + [ofOverwritePrompt];

  FEngineOpenDialog := TOpenDialog.Create(Self);
  FEngineOpenDialog.Title := 'Open engine';
  {$IFDEF MSWINDOWS}
  FEngineOpenDialog.Filter := 'Windows engine executables (*.exe)|*.exe|All files (*.*)|*.*';
  FEngineOpenDialog.DefaultExt := 'exe';
  {$ELSE}
  FEngineOpenDialog.Filter := 'Linux engine executables (*.out)|*.out|All files (*)|*';
  FEngineOpenDialog.DefaultExt := 'out';
  {$ENDIF}
  FEngineOpenDialog.Options := FEngineOpenDialog.Options + [ofFileMustExist];
end;

procedure TMainWindow.SetupPieceFont;
var
  FontFileName: String;
  FontFamilyName: String;
begin
  FontFileName := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'draughts.ttf';
  if not FileExists(FontFileName) then
    FontFileName := 'draughts.ttf';

  FPieceImage := TLazIntfImage.Create(0, 0, [riqfRGB]);
  FPieceDrawer := TIntfFreeTypeDrawer.Create(FPieceImage);

  if FileExists(FontFileName) then
  begin
    FontFamilyName := FontCollection.AddFile(FontFileName).Family.FamilyName;
    FPieceFont := TFreeTypeFont.Create;
    FPieceFont.Name := FontFamilyName;
    FPieceFont.Hinted := True;
    FPieceFont.ClearType := True;
    FPieceFont.Quality := grqHighQuality;
    FPieceFont.SmallLinePadding := False;
  end;
end;

procedure TMainWindow.Resize;
begin
  inherited Resize;
  InvalidateBoard;
end;

procedure TMainWindow.InvalidateBoard;
begin
  if FBoardPaintBox <> nil then
    FBoardPaintBox.Invalidate
  else
    Invalidate;
end;

procedure TMainWindow.BoardPaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  Square: Integer;
begin
  if Button <> mbLeft then
    Exit;

  Square := SquareAtPoint(X, Y);
  if Square = 0 then
  begin
    ClearBoardSelection;
    InvalidateBoard;
    Exit;
  end;

  SelectBoardSquare(Square);
end;

procedure TMainWindow.KeyDown(var Key: Word; Shift: TShiftState);
begin
  inherited KeyDown(Key, Shift);
  if Screen.ActiveCustomForm <> Self then
    Exit;
  if (Key = Ord('F')) and (Shift = []) then
  begin
    FBoardFlipped := not FBoardFlipped;
    ClearBoardSelection;
    UpdateClockLabels;
    InvalidateBoard;
    Key := 0;
  end;
end;

procedure TMainWindow.BoardPaintBoxPaint(Sender: TObject);
begin
  if FBoardPaintBox <> nil then
    DrawBoard(FBoardPaintBox.Canvas);
end;

function TMainWindow.BoardSquareAtCell(ARow, ACol: Integer): Integer;
var
  LogicalCol: Integer;
  LogicalRow: Integer;
begin
  if FBoardFlipped then
  begin
    LogicalRow := BoardSize - 1 - ARow;
    LogicalCol := BoardSize - 1 - ACol;
  end
  else
  begin
    LogicalRow := ARow;
    LogicalCol := ACol;
  end;

  if (LogicalRow < 0) or (LogicalRow >= BoardSize) or
    (LogicalCol < 0) or (LogicalCol >= BoardSize) or
    (not Odd(LogicalRow + LogicalCol)) then
    Exit(0);

  Result := (LogicalRow * 5) + (LogicalCol div 2) + 1;
end;

procedure TMainWindow.DrawBoard(ACanvas: TCanvas);
var
  BoardPixels: Integer;
  BoardArea: TRect;
  CellSize: Integer;
  Col: Integer;
  LegalGap: Integer;
  LegalLeft: Integer;
  LegalWidth: Integer;
  OffsetX: Integer;
  OffsetY: Integer;
  PiecePosition: Integer;
  Row: Integer;
  LeftPos: Integer;
  TopPos: Integer;
  SquareRect: TRect;
  SquareColor: TColor;
  UnitLeft: Integer;
begin
  ACanvas.Brush.Color := Color;
  if FBoardPaintBox <> nil then
    BoardArea := FBoardPaintBox.ClientRect
  else
    BoardArea := ClientRect;
  ACanvas.FillRect(BoardArea);
  if FBoardPaintBox <> nil then
  begin
    OffsetX := FBoardPaintBox.Left;
    OffsetY := FBoardPaintBox.Top;
  end
  else
  begin
    OffsetX := 0;
    OffsetY := 0;
  end;

  LegalGap := 10;
  LegalWidth := 180;
  if FLegalMovesPanel <> nil then
    LegalWidth := FLegalMovesPanel.Width;

  BoardPixels := Min((BoardArea.Right - BoardArea.Left) - (2 * LayoutMargin) -
    LegalWidth - LegalGap,
    (BoardArea.Bottom - BoardArea.Top) - (2 * BoardMargin));
  if BoardPixels < BoardSize then
  begin
    FBoardRect := Types.Rect(0, 0, 0, 0);
    if FLegalMovesPanel <> nil then
      FLegalMovesPanel.Visible := False;
    if FBoardTopClockLabel <> nil then
      FBoardTopClockLabel.Visible := False;
    if FBoardBottomClockLabel <> nil then
      FBoardBottomClockLabel.Visible := False;
    Exit;
  end;

  CellSize := BoardPixels div BoardSize;
  BoardPixels := CellSize * BoardSize;
  UnitLeft := BoardArea.Left + LayoutMargin;
  LegalLeft := UnitLeft;
  LeftPos := UnitLeft + LegalWidth + LegalGap;
  TopPos := BoardArea.Top + ((BoardArea.Bottom - BoardArea.Top - BoardPixels) div 2);
  FBoardRect := Types.Rect(LeftPos, TopPos, LeftPos + BoardPixels, TopPos + BoardPixels);
  if FButtonPanel <> nil then
  begin
    FButtonPanel.Left := Max(LayoutMargin, OffsetX + LeftPos +
      ((BoardPixels - FButtonPanel.Width) div 2));
    FButtonPanel.Top := 3;
  end;
  if FLegalMovesPanel <> nil then
  begin
    FLegalMovesPanel.SetBounds(OffsetX + LegalLeft, OffsetY + TopPos, LegalWidth,
      BoardPixels);
    FLegalMovesPanel.Visible := True;
    FLegalMovesPanel.BringToFront;
  end;
  DrawBoardClockLabels(FBoardRect);

  for Row := 0 to BoardSize - 1 do
    for Col := 0 to BoardSize - 1 do
    begin
      if Odd(Row + Col) then
        SquareColor := WoodSquareColor
      else
        SquareColor := clWhite;

      SquareRect := Types.Rect(
        FBoardRect.Left + (Col * CellSize),
        FBoardRect.Top + (Row * CellSize),
        FBoardRect.Left + ((Col + 1) * CellSize),
        FBoardRect.Top + ((Row + 1) * CellSize)
      );
      ACanvas.Brush.Color := SquareColor;
      ACanvas.FillRect(SquareRect);

      if Odd(Row + Col) then
      begin
        PiecePosition := BoardSquareAtCell(Row, Col);
        if PiecePosition = FSelectedSquare then
        begin
          ACanvas.Brush.Style := bsClear;
          ACanvas.Pen.Color := clYellow;
          ACanvas.Pen.Width := Max(2, CellSize div 16);
          ACanvas.Rectangle(SquareRect);
          ACanvas.Brush.Style := bsSolid;
        end
        else if FTargetSquares[PiecePosition] then
        begin
          ACanvas.Brush.Style := bsClear;
          if FAmbiguousTargetSquares[PiecePosition] then
            ACanvas.Pen.Color := clRed
          else
            ACanvas.Pen.Color := clLime;
          ACanvas.Pen.Width := Max(2, CellSize div 18);
          ACanvas.Ellipse(SquareRect.Left + (CellSize div 4),
            SquareRect.Top + (CellSize div 4), SquareRect.Right - (CellSize div 4),
            SquareRect.Bottom - (CellSize div 4));
          ACanvas.Brush.Style := bsSolid;
        end;
      end;

      if Odd(Row + Col) then
      begin
        PiecePosition := BoardSquareAtCell(Row, Col);
        DrawPiece(ACanvas, SquareRect, FBoard[PiecePosition], CellSize, SquareColor);
        if PiecePosition = FOnlyMoveSourceSquare then
        begin
          ACanvas.Brush.Style := bsClear;
          ACanvas.Pen.Color := clBlue;
          ACanvas.Pen.Width := Max(3, CellSize div 12);
          ACanvas.Rectangle(SquareRect.Left + 2, SquareRect.Top + 2,
            SquareRect.Right - 2, SquareRect.Bottom - 2);
          ACanvas.Brush.Style := bsSolid;
        end;
        if PiecePosition = FPonderBestSourceSquare then
        begin
          ACanvas.Brush.Style := bsClear;
          ACanvas.Pen.Color := PonderBestSourceColor;
          ACanvas.Pen.Width := Max(3, CellSize div 12);
          ACanvas.Rectangle(SquareRect.Left + (CellSize div 10),
            SquareRect.Top + (CellSize div 10), SquareRect.Right - (CellSize div 10),
            SquareRect.Bottom - (CellSize div 10));
          ACanvas.Brush.Style := bsSolid;
        end;
        if PiecePosition = FLastMoveTargetSquare then
        begin
          ACanvas.Brush.Style := bsClear;
          ACanvas.Pen.Color := clYellow;
          ACanvas.Pen.Width := Max(3, CellSize div 12);
          ACanvas.Rectangle(SquareRect.Left + 2, SquareRect.Top + 2,
            SquareRect.Right - 2, SquareRect.Bottom - 2);
          ACanvas.Brush.Style := bsSolid;
        end;
      end;
    end;

  ACanvas.Pen.Color := clBlack;
  ACanvas.Pen.Width := 2;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Rectangle(FBoardRect);
  ACanvas.Brush.Style := bsSolid;
end;

procedure TMainWindow.DrawBoardClockLabels(const ABoardRect: TRect);
const
  ClockHeight = 22;
  ClockGap = 4;
var
  BottomRect: TRect;
  OffsetX: Integer;
  OffsetY: Integer;
  TopRect: TRect;
begin
  if (FBoardTopClockLabel = nil) or (FBoardBottomClockLabel = nil) then
    Exit;

  if FBoardPaintBox <> nil then
  begin
    OffsetX := FBoardPaintBox.Left;
    OffsetY := FBoardPaintBox.Top;
  end
  else
  begin
    OffsetX := 0;
    OffsetY := 0;
  end;

  TopRect := Types.Rect(OffsetX + ABoardRect.Left,
    Max(0, OffsetY + ABoardRect.Top - ClockHeight - ClockGap),
    OffsetX + ABoardRect.Right,
    Max(ClockHeight, OffsetY + ABoardRect.Top - ClockGap));
  BottomRect := Types.Rect(OffsetX + ABoardRect.Left, OffsetY + ABoardRect.Bottom + ClockGap,
    OffsetX + ABoardRect.Right, OffsetY + ABoardRect.Bottom + ClockGap + ClockHeight);

  FBoardTopClockLabel.BoundsRect := TopRect;
  FBoardBottomClockLabel.BoundsRect := BottomRect;
  FBoardTopClockLabel.Visible := True;
  FBoardBottomClockLabel.Visible := True;
  FBoardTopClockLabel.BringToFront;
  FBoardBottomClockLabel.BringToFront;
end;

procedure TMainWindow.DrawPiece(ACanvas: TCanvas; const ASquare: TRect;
  APiece: TPiece; ACellSize: Integer; ASquareColor: TColor);
var
  Bitmap: Graphics.TBitmap;
  Glyph: String;
  MainColor: TFPColor;
  OutlineColor: TFPColor;
  Offset: Integer;
  TextX: Single;
  TextY: Single;
begin
  if (APiece = pcNone) or (FPieceFont = nil) then
    Exit;

  case APiece of
    pcWhiteMan: Glyph := 'g';
    pcWhiteKing: Glyph := 'b';
    pcBlackMan: Glyph := 'g';
    pcBlackKing: Glyph := 'b';
  else
    Glyph := '';
  end;

  if Glyph = '' then
    Exit;

  if (FPieceImage.Width <> ACellSize) or (FPieceImage.Height <> ACellSize) then
    FPieceImage.SetSize(ACellSize, ACellSize);

  FPieceDrawer.FillPixels(TColorToFPColor(ASquareColor));
  FPieceFont.SizeInPixels := ACellSize * 0.78;

  TextX := ACellSize / 2;
  TextY := ACellSize / 2;
  Offset := Max(1, ACellSize div 30);

  if APiece in [pcWhiteMan, pcWhiteKing] then
  begin
    MainColor := TColorToFPColor(clWhite);
    OutlineColor := TColorToFPColor(clBlack);

    FPieceDrawer.DrawText(Glyph, FPieceFont, TextX - Offset, TextY, OutlineColor,
      [ftaCenter, ftaVerticalCenter]);
    FPieceDrawer.DrawText(Glyph, FPieceFont, TextX + Offset, TextY, OutlineColor,
      [ftaCenter, ftaVerticalCenter]);
    FPieceDrawer.DrawText(Glyph, FPieceFont, TextX, TextY - Offset, OutlineColor,
      [ftaCenter, ftaVerticalCenter]);
    FPieceDrawer.DrawText(Glyph, FPieceFont, TextX, TextY + Offset, OutlineColor,
      [ftaCenter, ftaVerticalCenter]);
    FPieceDrawer.DrawText(Glyph, FPieceFont, TextX, TextY, MainColor,
      [ftaCenter, ftaVerticalCenter]);
  end
  else
  begin
    MainColor := TColorToFPColor(clBlack);
    OutlineColor := TColorToFPColor(clWhite);

    FPieceDrawer.DrawText(Glyph, FPieceFont, TextX - Offset, TextY, OutlineColor,
      [ftaCenter, ftaVerticalCenter]);
    FPieceDrawer.DrawText(Glyph, FPieceFont, TextX + Offset, TextY, OutlineColor,
      [ftaCenter, ftaVerticalCenter]);
    FPieceDrawer.DrawText(Glyph, FPieceFont, TextX, TextY - Offset, OutlineColor,
      [ftaCenter, ftaVerticalCenter]);
    FPieceDrawer.DrawText(Glyph, FPieceFont, TextX, TextY + Offset, OutlineColor,
      [ftaCenter, ftaVerticalCenter]);
    FPieceDrawer.DrawText(Glyph, FPieceFont, TextX, TextY, MainColor,
      [ftaCenter, ftaVerticalCenter]);
  end;

  Bitmap := Graphics.TBitmap.Create;
  try
    Bitmap.LoadFromIntfImage(FPieceImage);
    ACanvas.Draw(ASquare.Left, ASquare.Top, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TMainWindow.ApplyMove(const AMove: TMove);
var
  CaptureIndex: Integer;
  FromSquare: Integer;
  Piece: TPiece;
  ToSquare: Integer;
begin
  if Length(AMove.Squares) < 2 then
    Exit;

  FromSquare := AMove.Squares[0];
  ToSquare := AMove.Squares[High(AMove.Squares)];
  Piece := FBoard[FromSquare];

  FBoard[FromSquare] := pcNone;
  for CaptureIndex := 0 to High(AMove.Captures) do
    FBoard[AMove.Captures[CaptureIndex]] := pcNone;

  if AMove.Promotes then
  begin
    case Piece of
      pcWhiteMan: Piece := pcWhiteKing;
      pcBlackMan: Piece := pcBlackKing;
    end;
  end;

  FBoard[ToSquare] := Piece;
  FLastMoveTargetSquare := ToSquare;

  if FSideToMove = sideWhite then
    FSideToMove := sideBlack
  else
    FSideToMove := sideWhite;

  UpdateMoveList;
  InvalidateBoard;
end;

procedure CopyMove(const ASource: TMove; out ADest: TMove);
var
  I: Integer;
begin
  SetLength(ADest.Squares, Length(ASource.Squares));
  SetLength(ADest.Captures, Length(ASource.Captures));
  for I := 0 to High(ASource.Squares) do
    ADest.Squares[I] := ASource.Squares[I];
  for I := 0 to High(ASource.Captures) do
    ADest.Captures[I] := ASource.Captures[I];
  ADest.Promotes := ASource.Promotes;
end;

procedure TMainWindow.ResetHistoryFromCurrentPosition;
begin
  FHistoryBaseBoard := FBoard;
  FHistoryBaseSide := FSideToMove;
  FCurrentPly := 0;
  FLastMoveTargetSquare := 0;
  SetLength(FHistoryMoves, 0);
  SetLength(FHistoryMoveAnnotations, 0);
  SetLength(FHistoryClockSnapshots, 0);
end;

procedure TMainWindow.MarkGameDirty;
begin
  FGameDirty := True;
end;

procedure TMainWindow.RecordPlayedMove(const AMove: TMove; const AAnnotation: String);
var
  MoveIndex: Integer;
begin
  UpdateGameClock;

  if FCurrentPly < Length(FHistoryMoves) then
  begin
    SetLength(FHistoryMoves, FCurrentPly);
    SetLength(FHistoryMoveAnnotations, FCurrentPly);
    SetLength(FHistoryClockSnapshots, FCurrentPly);
  end;

  SetLength(FHistoryMoves, Length(FHistoryMoves) + 1);
  SetLength(FHistoryMoveAnnotations, Length(FHistoryMoves));
  SetLength(FHistoryClockSnapshots, Length(FHistoryMoves));
  CopyMove(AMove, FHistoryMoves[High(FHistoryMoves)]);
  MoveIndex := High(FHistoryMoves);
  FHistoryMoveAnnotations[MoveIndex] := AAnnotation;
  FHistoryClockSnapshots[MoveIndex].HasClock := FPlayGameActive;
  if FHistoryClockSnapshots[MoveIndex].HasClock then
  begin
    FHistoryClockSnapshots[MoveIndex].WhiteSeconds := FWhiteClockSeconds;
    FHistoryClockSnapshots[MoveIndex].BlackSeconds := FBlackClockSeconds;
  end;
  FCurrentPly := Length(FHistoryMoves);
  MarkGameDirty;
  UpdateHistoryList;
end;

procedure TMainWindow.RebuildPositionToPly(APly: Integer);
var
  I: Integer;
begin
  if APly < 0 then
    APly := 0;
  if APly > Length(FHistoryMoves) then
    APly := Length(FHistoryMoves);

  FBoard := FHistoryBaseBoard;
  FSideToMove := FHistoryBaseSide;
  FCurrentPly := 0;
  FLastMoveTargetSquare := 0;
  for I := 0 to APly - 1 do
  begin
    ApplyMove(FHistoryMoves[I]);
    Inc(FCurrentPly);
  end;

  FCurrentPly := APly;
  UpdateMoveList;
  UpdateHistoryList;
  InvalidateBoard;
end;

procedure TMainWindow.MovesMemoDblClick(Sender: TObject);
var
  MoveIndex: Integer;
begin
  MoveIndex := FMovesMemo.CaretPos.Y;
  ExecuteMoveFromList(MoveIndex, False);
end;

procedure TMainWindow.MoveListMoveClick(Sender: TObject);
var
  MoveIndex: Integer;
begin
  MoveIndex := FMovesMemo.CaretPos.Y;
  ExecuteMoveFromList(MoveIndex, True);
end;

procedure TMainWindow.HistoryMemoClick(Sender: TObject);
var
  Caret: Integer;
  I: Integer;
  Ply: Integer;
begin
  if FHistoryMemo = nil then
    Exit;

  Caret := FHistoryMemo.SelStart;
  Ply := 0;
  for I := 0 to High(FHistoryMoveStarts) do
    if (FHistoryMoveLengths[I] > 0) and (Caret >= FHistoryMoveStarts[I]) and
      (Caret <= FHistoryMoveStarts[I] + FHistoryMoveLengths[I]) then
    begin
      Ply := I;
      Break;
    end;

  if (Ply > 0) and (Ply <= Length(FHistoryMoves)) then
    NavigateHistoryToPly(Ply)
  else
    SelectHistoryPly(FCurrentPly);
end;

procedure TMainWindow.HistoryMemoKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_RIGHT:
    begin
      NavigateHistoryToPly(Min(FCurrentPly + 1, Length(FHistoryMoves)));
      Key := 0;
    end;
    VK_LEFT:
    begin
      NavigateHistoryToPly(Max(FCurrentPly - 1, 0));
      Key := 0;
    end;
  end;
end;

procedure TMainWindow.NavigateHistoryToPly(APly: Integer);
begin
  RebuildPositionToPly(APly);
  if FPlayGameActive then
    RestoreClockSnapshot(APly);
  SelectHistoryPly(APly);
  RestartEnginePonder;
end;

procedure TMainWindow.SelectHistoryPly(APly: Integer);
begin
  if FHistoryMemo = nil then
    Exit;

  if APly <= 0 then
  begin
    FHistoryMemo.SelStart := 0;
    FHistoryMemo.SelLength := 0;
    Exit;
  end;

  if (APly <= High(FHistoryMoveStarts)) and (FHistoryMoveLengths[APly] > 0) then
  begin
    FHistoryMemo.SelStart := FHistoryMoveStarts[APly];
    FHistoryMemo.SelLength := FHistoryMoveLengths[APly];
  end;
end;

function TMainWindow.SquareAtPoint(X, Y: Integer): Integer;
var
  CellSize: Integer;
  Col: Integer;
  Row: Integer;
begin
  Result := 0;
  if (FBoardRect.Right <= FBoardRect.Left) or (FBoardRect.Bottom <= FBoardRect.Top) then
    Exit;
  if (X < FBoardRect.Left) or (X >= FBoardRect.Right) or
    (Y < FBoardRect.Top) or (Y >= FBoardRect.Bottom) then
    Exit;

  CellSize := (FBoardRect.Right - FBoardRect.Left) div BoardSize;
  if CellSize <= 0 then
    Exit;

  Col := (X - FBoardRect.Left) div CellSize;
  Row := (Y - FBoardRect.Top) div CellSize;
  if (Row < 0) or (Row >= BoardSize) or (Col < 0) or (Col >= BoardSize) then
    Exit;

  Result := BoardSquareAtCell(Row, Col);
end;

procedure TMainWindow.SelectBoardSquare(ASquare: Integer);
var
  CountsByTarget: array[1..50] of Integer;
  I: Integer;
  MatchingMoveCount: Integer;
  MatchingMoveIndex: Integer;
  TargetSquare: Integer;
begin
  if (FSelectedSquare <> 0) and FTargetSquares[ASquare] then
  begin
    if FAmbiguousTargetSquares[ASquare] then
    begin
      InvalidateBoard;
      Exit;
    end;

    MatchingMoveCount := 0;
    MatchingMoveIndex := -1;
    for I := 0 to High(FMoves) do
      if (Length(FMoves[I].Squares) >= 2) and (FMoves[I].Squares[0] = FSelectedSquare) and
        (FMoves[I].Squares[High(FMoves[I].Squares)] = ASquare) then
      begin
        Inc(MatchingMoveCount);
        MatchingMoveIndex := I;
      end;

    if MatchingMoveCount = 1 then
      ExecuteLegalMoveIndex(MatchingMoveIndex, True)
    else
      SelectBoardSquare(ASquare);
    Exit;
  end;

  ClearBoardSelection;
  if (ASquare < Low(FBoard)) or (ASquare > High(FBoard)) then
  begin
    InvalidateBoard;
    Exit;
  end;

  MatchingMoveCount := 0;
  MatchingMoveIndex := -1;
  FillChar(CountsByTarget, SizeOf(CountsByTarget), 0);
  for I := 0 to High(FMoves) do
    if (Length(FMoves[I].Squares) >= 2) and (FMoves[I].Squares[0] = ASquare) then
    begin
      Inc(MatchingMoveCount);
      MatchingMoveIndex := I;
      FSelectedSquare := ASquare;
      TargetSquare := FMoves[I].Squares[High(FMoves[I].Squares)];
      if (TargetSquare >= Low(FTargetSquares)) and (TargetSquare <= High(FTargetSquares)) then
      begin
        Inc(CountsByTarget[TargetSquare]);
        FTargetSquares[TargetSquare] := True;
      end;
    end;

  for TargetSquare := Low(FTargetSquares) to High(FTargetSquares) do
    FAmbiguousTargetSquares[TargetSquare] := CountsByTarget[TargetSquare] > 1;

  if MatchingMoveCount = 1 then
    ExecuteLegalMoveIndex(MatchingMoveIndex, True)
  else
    InvalidateBoard;
end;

procedure TMainWindow.ExecuteMoveFromList(AMoveIndex: Integer; AContinueEngine: Boolean);
begin
  ExecuteLegalMoveIndex(AMoveIndex, AContinueEngine);
end;

procedure TMainWindow.ExecuteLegalMoveIndex(AMoveIndex: Integer; AContinueEngine: Boolean);
var
  PlayedMove: TMove;
begin
  if (AMoveIndex < 0) or (AMoveIndex > High(FMoves)) then
    Exit;

  UpdateGameClock;
  CopyMove(FMoves[AMoveIndex], PlayedMove);
  ClearBoardSelection;

  if FPlayGameActive and (not IsPlayGameHumanTurn) then
  begin
    AppendEngineLog('[not your turn]' + LineEnding);
    Exit;
  end;

  ApplyMove(PlayedMove);
  RecordPlayedMove(PlayedMove);

  if FPlayGameActive then
  begin
    AppendEngineLog('[human move ' + MoveToString(PlayedMove) +
      '; starting engine think]' + LineEnding);
    if FEngineState <> esIdle then
    begin
      FPendingAutoPlayStart := False;
      FPendingPonderStart := False;
      FPendingMctsStart := False;
      FPendingPlayGameStart := False;
      FPendingThinkMode := esmPlayGameThink;
      FPendingThinkStart := True;
      AppendEngineLog('[stopping previous search before engine think]' +
        LineEnding);
      SendStopToEngine;
    end
    else
      SendGoThinkToEngine(esmPlayGameThink);
  end
  else if AContinueEngine and EngineIsRunning and
    FEngineReady then
  begin
    AppendEngineLog('[played move ' + MoveToString(PlayedMove) +
      '; restarting ponder]' + LineEnding);
    RestartEnginePonder;
  end;
end;

procedure TMainWindow.AppendEngineLog(const AText: String);
begin
  if AText = '' then
    Exit;

  FEngineLogMemo.SelStart := Length(FEngineLogMemo.Text);
  FEngineLogMemo.SelText := AText;
  FEngineLogMemo.SelStart := Length(FEngineLogMemo.Text);
end;

function EngineLogTimestamp: String;
begin
  Result := FormatDateTime('hh:nn:ss.zzz', Now);
end;

function ClockTimestampSeconds: Double;
begin
  {$IFDEF MSWINDOWS}
  Result := GetTickCount64 / 1000.0;
  {$ELSE}
  Result := Now * 24 * 60 * 60;
  {$ENDIF}
end;

function TMainWindow.EngineIsRunning: Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result := FEngineRunning and (FEngineProcessInfo.hProcess <> 0) and
    (WaitForSingleObject(FEngineProcessInfo.hProcess, 0) = WAIT_TIMEOUT);
  if not Result then
    FEngineRunning := False;
  {$ELSE}
  Result := (FEngineProcess <> nil) and FEngineProcess.Running;
  {$ENDIF}
end;

procedure TMainWindow.ClockTimerTimer(Sender: TObject);
begin
  UpdateGameClock;
end;

procedure TMainWindow.UpdateGameClock;
var
  ElapsedSeconds: Double;
begin
  if not FClocksActive then
    Exit;

  ElapsedSeconds := ClockTimestampSeconds - FClockLastTick;
  FClockLastTick := ClockTimestampSeconds;
  if ElapsedSeconds <= 0 then
    Exit;

  if FSideToMove = sideWhite then
  begin
    FWhiteClockSeconds := Max(0, FWhiteClockSeconds - ElapsedSeconds);
    if FWhiteClockSeconds = 0 then
    begin
      FGameResult := '0-2';
      MarkGameDirty;
      LeavePlayGameMode;
      AppendEngineLog('[white clock expired]' + LineEnding);
      UpdateHistoryList;
      RestartEnginePonder;
    end;
  end
  else
  begin
    FBlackClockSeconds := Max(0, FBlackClockSeconds - ElapsedSeconds);
    if FBlackClockSeconds = 0 then
    begin
      FGameResult := '2-0';
      MarkGameDirty;
      LeavePlayGameMode;
      AppendEngineLog('[black clock expired]' + LineEnding);
      UpdateHistoryList;
      RestartEnginePonder;
    end;
  end;

  UpdateClockLabels;
end;

function FormatClockSeconds(ASeconds: Double): String;
var
  WholeSeconds: Integer;
begin
  WholeSeconds := Ceil(Max(0, ASeconds));
  Result := Format('%2.2d:%2.2d', [WholeSeconds div 60, WholeSeconds mod 60]);
end;

function FormatClockAnnotationSeconds(ASeconds: Double): String;
var
  WholeSeconds: Integer;
begin
  WholeSeconds := Ceil(Max(0, ASeconds));
  Result := Format('%2.2d:%2.2d:%2.2d',
    [WholeSeconds div 3600, (WholeSeconds div 60) mod 60, WholeSeconds mod 60]);
end;

procedure TMainWindow.ResetClocks;
begin
  FWhiteClockSeconds := 0;
  FBlackClockSeconds := 0;
  FInitialWhiteClockSeconds := 0;
  FInitialBlackClockSeconds := 0;
  StopGameClocks;
end;

procedure TMainWindow.StartGameClocks(AGameMinutes: Double);
begin
  FWhiteClockSeconds := Max(0, AGameMinutes * 60);
  FBlackClockSeconds := Max(0, AGameMinutes * 60);
  FInitialWhiteClockSeconds := FWhiteClockSeconds;
  FInitialBlackClockSeconds := FBlackClockSeconds;
  FClockLastTick := ClockTimestampSeconds;
  FClocksActive := (FWhiteClockSeconds > 0) and (FBlackClockSeconds > 0);
  if FClockTimer <> nil then
    {$IFDEF MSWINDOWS}
    FClockTimer.Enabled := False;
    {$ELSE}
    FClockTimer.Enabled := FClocksActive;
    {$ENDIF}
  UpdateClockLabels;
end;

procedure TMainWindow.StopGameClocks;
begin
  FClocksActive := False;
  if FClockTimer <> nil then
    FClockTimer.Enabled := False;
  UpdateClockLabels;
end;

procedure TMainWindow.LeavePlayGameMode;
begin
  FPlayGameActive := False;
  ResetClocks;
end;

procedure TMainWindow.RestoreClockSnapshot(APly: Integer);
begin
  if APly <= 0 then
  begin
    FWhiteClockSeconds := FInitialWhiteClockSeconds;
    FBlackClockSeconds := FInitialBlackClockSeconds;
  end
  else if (APly <= Length(FHistoryClockSnapshots)) and
    FHistoryClockSnapshots[APly - 1].HasClock then
  begin
    FWhiteClockSeconds := FHistoryClockSnapshots[APly - 1].WhiteSeconds;
    FBlackClockSeconds := FHistoryClockSnapshots[APly - 1].BlackSeconds;
  end
  else
    Exit;

  FClockLastTick := ClockTimestampSeconds;
  FClocksActive := FPlayGameActive and (FWhiteClockSeconds > 0) and
    (FBlackClockSeconds > 0);
  if FClockTimer <> nil then
    {$IFDEF MSWINDOWS}
    FClockTimer.Enabled := False;
    {$ELSE}
    FClockTimer.Enabled := FClocksActive;
    {$ENDIF}
  UpdateClockLabels;
  AppendEngineLog('[restored clocks ' + FormatClockSeconds(FWhiteClockSeconds) +
    ' / ' + FormatClockSeconds(FBlackClockSeconds) + ']' + LineEnding);
end;

procedure TMainWindow.UpdateClockLabels;

  procedure SetClockLabel(ALabel: TLabel; const AName: String; ASeconds: Double);
  begin
    if ALabel = nil then
      Exit;

    ALabel.Caption := AName + '  ' + FormatClockSeconds(ASeconds);
    if FClocksActive and (ASeconds > 0) then
      ALabel.Font.Color := clGreen
    else
      ALabel.Font.Color := clRed;
  end;

begin
  if FBoardFlipped then
  begin
    SetClockLabel(FBoardTopClockLabel, 'White', FWhiteClockSeconds);
    SetClockLabel(FBoardBottomClockLabel, 'Black', FBlackClockSeconds);
  end
  else
  begin
    SetClockLabel(FBoardTopClockLabel, 'Black', FBlackClockSeconds);
    SetClockLabel(FBoardBottomClockLabel, 'White', FWhiteClockSeconds);
  end;
end;

procedure TMainWindow.CloseEngine;
begin
  if FEnginePollTimer <> nil then
    FEnginePollTimer.Enabled := False;
  {$IFDEF MSWINDOWS}
  if FEngineRunning then
  begin
    AppendEngineLog('> quit' + LineEnding);
    SendEngineCommand('quit');
    WaitForSingleObject(FEngineProcessInfo.hProcess, 1000);
    if EngineIsRunning then
      TerminateProcess(FEngineProcessInfo.hProcess, 0);
  end;
  if FEngineInputWriteHandle <> 0 then
  begin
    CloseHandle(FEngineInputWriteHandle);
    FEngineInputWriteHandle := 0;
  end;
  if FEngineOutputReadHandle <> 0 then
  begin
    CloseHandle(FEngineOutputReadHandle);
    FEngineOutputReadHandle := 0;
  end;
  if FEngineReaderThread <> nil then
  begin
    FEngineReaderThread.Terminate;
    FEngineReaderThread.WaitFor;
    FreeAndNil(FEngineReaderThread);
  end;
  if FEngineProcessInfo.hThread <> 0 then
  begin
    CloseHandle(FEngineProcessInfo.hThread);
    FEngineProcessInfo.hThread := 0;
  end;
  if FEngineProcessInfo.hProcess <> 0 then
  begin
    CloseHandle(FEngineProcessInfo.hProcess);
    FEngineProcessInfo.hProcess := 0;
  end;
  FEngineRunning := False;
  {$ELSE}
  if FEngineProcess <> nil then
  begin
    if FEngineProcess.Running then
    begin
      AppendEngineLog('> quit' + LineEnding);
      SendEngineCommand('quit');
      FEngineProcess.WaitOnExit(1000);
      if FEngineProcess.Running then
        FEngineProcess.Terminate(0);
    end;
    FreeAndNil(FEngineProcess);
  end;
  {$ENDIF}
  FAutoPlayActive := False;
  FAutoPlayPlyCount := 0;
  FPendingAutoPlayStart := False;
  FPendingPonderStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  LeavePlayGameMode;
  if FAutoPlayButton <> nil then
    FAutoPlayButton.Enabled := False;
  if FPlayGameButton <> nil then
    FPlayGameButton.Enabled := False;
  if FGoButton <> nil then
    FGoButton.Enabled := False;
  if FMctsButton <> nil then
    FMctsButton.Enabled := False;
  if FStopButton <> nil then
    FStopButton.Enabled := False;
  FEngineSearching := False;
  FEngineSearchMode := esmIdle;
  SetEngineState(esIdle);
  FEngineState := esIdle;
end;

procedure TMainWindow.OpenEngineMenuItemClick(Sender: TObject);
begin
  if FEngineOpenDialog.Execute then
  begin
    try
      StartEngine(FEngineOpenDialog.FileName);
    except
      on E: Exception do
        MessageDlg('Open engine', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainWindow.EditEngineParamsMenuItemClick(Sender: TObject);
var
  Dialog: TEngineParamDialog;
begin
  Dialog := TEngineParamDialog.Create(Self);
  Dialog.SetParams(FEngineParams);
  Dialog.OnHide := @EngineParamsDialogHide;
  Dialog.Show;
end;

procedure TMainWindow.EngineParamsDialogHide(Sender: TObject);
var
  Dialog: TEngineParamDialog;
begin
  if not (Sender is TEngineParamDialog) then
    Exit;

  Dialog := TEngineParamDialog(Sender);
  if Dialog.ModalResult = mrOK then
  begin
    FEngineParams := Dialog.Params;
    if FEngineParamsFileName = '' then
      FEngineParamsFileName := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
        'engine.params.json';
    SaveParamsToJson(FEngineParamsFileName, FEngineParams);
    AppendEngineLog('[saved engine parameters to ' + FEngineParamsFileName + ']' +
      LineEnding);
  end;
  Dialog.Release;
end;

procedure TMainWindow.StartEngine(const AFileName: String);
{$IFDEF MSWINDOWS}
var
  Child2ParentRead: THandle;
  Child2ParentWrite: THandle;
  CommandLine: String;
  CurrentDir: String;
  Parent2ChildRead: THandle;
  Parent2ChildWrite: THandle;
  Security: TSecurityAttributes;
  StartupInfo: TStartupInfo;
{$ENDIF}
begin
  CloseEngine;
  FEngineLogMemo.Clear;
  FEngineLogMemo.Lines.Add('Engine: ' + AFileName);
  FEngineParamsFileName := AFileName + '.params.json';
  LoadParamsFromJson(FEngineParamsFileName, FEngineParams);
  if Length(FEngineParams) > 0 then
    FEngineLogMemo.Lines.Add('Loaded parameters: ' + FEngineParamsFileName);
  FEngineReady := False;
  if FAutoPlayButton <> nil then
    FAutoPlayButton.Enabled := False;
  if FPlayGameButton <> nil then
    FPlayGameButton.Enabled := False;
  if FGoButton <> nil then
    FGoButton.Enabled := False;
  if FMctsButton <> nil then
    FMctsButton.Enabled := False;
  if FStopButton <> nil then
    FStopButton.Enabled := False;
  FAutoPlayActive := False;
  FAutoPlayPlyCount := 0;
  FPendingAutoPlayStart := False;
  FPendingPonderStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  LeavePlayGameMode;
  FEngineSearching := False;
  FEngineSearchMode := esmIdle;
  FEngineState := esIdle;
  FEngineStartAfterReady := True;
  FEngineStopRequested := False;
  FEngineWaitingForInit := False;
  FIgnoreNextDoneMove := False;
  FEngineSearchMode := esmIdle;
  FEngineTextBuffer := '';
  FEngineFirstReadSeen := False;

  {$IFDEF MSWINDOWS}
  Parent2ChildRead := 0;
  Parent2ChildWrite := 0;
  Child2ParentRead := 0;
  Child2ParentWrite := 0;

  FillChar(Security, SizeOf(Security), 0);
  Security.nLength := SizeOf(Security);
  Security.bInheritHandle := True;

  if not CreatePipe(Parent2ChildRead, Parent2ChildWrite, @Security, 0) then
    RaiseLastOSError;
  if not SetHandleInformation(Parent2ChildWrite, HANDLE_FLAG_INHERIT, 0) then
    RaiseLastOSError;
  if not CreatePipe(Child2ParentRead, Child2ParentWrite, @Security, 0) then
    RaiseLastOSError;
  if not SetHandleInformation(Child2ParentRead, HANDLE_FLAG_INHERIT, 0) then
    RaiseLastOSError;

  FillChar(FEngineProcessInfo, SizeOf(FEngineProcessInfo), 0);
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.hStdError := Child2ParentWrite;
  StartupInfo.hStdInput := Parent2ChildRead;
  StartupInfo.hStdOutput := Child2ParentWrite;
  StartupInfo.dwFlags := STARTF_USESTDHANDLES;

  CommandLine := '"' + AFileName + '"';
  CurrentDir := ExtractFilePath(AFileName);
  AppendEngineLog('[engine execute begin ' + EngineLogTimestamp + ']' +
    LineEnding);
  AppendEngineLog('[engine cwd ' + CurrentDir + ']' + LineEnding);
  if not CreateProcess(nil, PChar(CommandLine), nil, nil, True,
    CREATE_NO_WINDOW, nil, PChar(CurrentDir), StartupInfo,
    FEngineProcessInfo) then
    RaiseLastOSError;

  CloseHandle(Parent2ChildRead);
  Parent2ChildRead := 0;
  CloseHandle(Child2ParentWrite);
  Child2ParentWrite := 0;
  FEngineInputWriteHandle := Parent2ChildWrite;
  FEngineOutputReadHandle := Child2ParentRead;
  FEngineRunning := True;
  FEngineReaderThread := TEngineReaderThread.Create(Self, FEngineOutputReadHandle);
  {$ELSE}
  FEngineProcess := TProcess.Create(Self);
  FEngineProcess.Executable := AFileName;
  FEngineProcess.CurrentDirectory := ExtractFilePath(AFileName);
  FEngineProcess.Options := [poUsePipes, poStderrToOutput];
  FEngineProcess.ShowWindow := swoHIDE;
  AppendEngineLog('[engine execute begin ' + EngineLogTimestamp + ']' +
    LineEnding);
  AppendEngineLog('[engine cwd ' + FEngineProcess.CurrentDirectory + ']' +
    LineEnding);
  FEngineProcess.Execute;
  if FEnginePollTimer <> nil then
    FEnginePollTimer.Enabled := True;
  {$ENDIF}
  AppendEngineLog('[engine execute returned ' + EngineLogTimestamp +
    ' running=' + BoolToStr(EngineIsRunning, True) + ']' + LineEnding);

  AppendEngineLog('> hub' + LineEnding);
  SendEngineCommand('hub');
  {$IFDEF MSWINDOWS}
  if Parent2ChildRead <> 0 then
    CloseHandle(Parent2ChildRead);
  if Child2ParentWrite <> 0 then
    CloseHandle(Child2ParentWrite);
  {$ENDIF}
end;

procedure TMainWindow.SendEngineCommand(const ACommand: String);
var
  {$IFDEF MSWINDOWS}
  BytesWritten: DWORD;
  {$ENDIF}
  CommandText: String;
begin
  if not EngineIsRunning then
    Exit;

  CommandText := ACommand + LineEnding;
  if CommandText <> '' then
  begin
    AppendEngineLog('[engine write ' + EngineLogTimestamp + ' bytes=' +
      IntToStr(Length(CommandText)) + ' command=' + ACommand + ']' +
      LineEnding);
    {$IFDEF MSWINDOWS}
    if (FEngineInputWriteHandle <> 0) and
      (not WriteFile(FEngineInputWriteHandle, CommandText[1],
        Length(CommandText), BytesWritten, nil)) then
      RaiseLastOSError;
    {$ELSE}
    FEngineProcess.Input.WriteBuffer(CommandText[1], Length(CommandText));
    {$ENDIF}
  end;
end;

function EngineStateText(AState: TEngineState): String;
begin
  case AState of
    esIdle: Result := 'idle';
    esPondering: Result := 'pondering';
    esMcts: Result := 'mcts';
    esThinking: Result := 'thinking';
  else
    Result := 'unknown';
  end;
end;

procedure TMainWindow.SetEngineState(AState: TEngineState);
begin
  if FEngineState = AState then
    Exit;

  FEngineState := AState;
  AppendEngineLog('[engine state: ' + EngineStateText(FEngineState) + ']' +
    LineEnding);
end;

procedure TMainWindow.SendEngineParams;
var
  Command: String;
  I: Integer;
begin
  for I := 0 to High(FEngineParams) do
  begin
    if FEngineParams[I].Name = '' then
      Continue;
    Command := 'set-param name=' + HubQuote(FEngineParams[I].Name) +
      ' value=' + HubQuote(FEngineParams[I].Value);
    AppendEngineLog('> ' + Command + LineEnding);
    SendEngineCommand(Command);
  end;
end;

procedure TMainWindow.EngineProcessReadData(Sender: TObject);
var
  Buffer: array[0..4095] of Byte;
  {$IFDEF MSWINDOWS}
  Available: DWORD;
  BytesReadWin: DWORD;
  {$ENDIF}
  BytesRead: LongInt;
  Chunk: String;
begin
  {$IFDEF MSWINDOWS}
  if FEngineOutputReadHandle = 0 then
    Exit;

  while True do
  begin
    Available := 0;
    if not PeekNamedPipe(FEngineOutputReadHandle, nil, 0, nil, @Available, nil) then
      Break;
    if Available = 0 then
      Break;

    if not FEngineFirstReadSeen then
    begin
      FEngineFirstReadSeen := True;
      AppendEngineLog('[engine first read ' + EngineLogTimestamp +
        ' available=' + IntToStr(Available) + ']' + LineEnding);
    end;

    BytesReadWin := 0;
    if not ReadFile(FEngineOutputReadHandle, Buffer[0], SizeOf(Buffer),
      BytesReadWin, nil) then
      Break;
    if BytesReadWin = 0 then
      Break;

    SetString(Chunk, PChar(@Buffer[0]), BytesReadWin);
    AppendEngineLog(Chunk);
    ProcessEngineOutput(Chunk);
  end;
  {$ELSE}
  if FEngineProcess = nil then
    Exit;

  while (FEngineProcess.Output <> nil) and
    (FEngineProcess.Output.NumBytesAvailable > 0) do
  begin
    if not FEngineFirstReadSeen then
    begin
      FEngineFirstReadSeen := True;
      AppendEngineLog('[engine first read ' + EngineLogTimestamp +
        ' available=' + IntToStr(FEngineProcess.Output.NumBytesAvailable) + ']' +
        LineEnding);
    end;
    BytesRead := FEngineProcess.Output.Read(Buffer, SizeOf(Buffer));
    if BytesRead <= 0 then
      Break;

    SetString(Chunk, PChar(@Buffer[0]), BytesRead);
    AppendEngineLog(Chunk);
    ProcessEngineOutput(Chunk);
  end;
  {$ENDIF}
end;

procedure TMainWindow.EnginePollTimerTimer(Sender: TObject);
begin
  {$IFDEF MSWINDOWS}
  if FEngineProcessInfo.hProcess = 0 then
  begin
    if FEnginePollTimer <> nil then
      FEnginePollTimer.Enabled := False;
    Exit;
  end;
  if not EngineIsRunning then
  begin
    EngineProcessTerminate(Sender);
    Exit;
  end;
  EngineProcessReadData(Sender);
  {$ELSE}
  if FEngineProcess = nil then
  begin
    if FEnginePollTimer <> nil then
      FEnginePollTimer.Enabled := False;
    Exit;
  end;

  if not FEngineProcess.Running then
  begin
    EngineProcessTerminate(Sender);
    Exit;
  end;

  EngineProcessReadData(Sender);
  {$ENDIF}
end;

procedure TMainWindow.EngineProcessTerminate(Sender: TObject);
begin
  if FEnginePollTimer <> nil then
    FEnginePollTimer.Enabled := False;
  EngineProcessReadData(Sender);
  FEngineReady := False;
  FAutoPlayActive := False;
  FPendingAutoPlayStart := False;
  FPendingMctsStart := False;
  FPendingPonderStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  LeavePlayGameMode;
  SetEngineState(esIdle);
  FEngineSearchMode := esmIdle;
  if FAutoPlayButton <> nil then
    FAutoPlayButton.Enabled := False;
  if FPlayGameButton <> nil then
    FPlayGameButton.Enabled := False;
  if FGoButton <> nil then
    FGoButton.Enabled := False;
  if FMctsButton <> nil then
    FMctsButton.Enabled := False;
  if FStopButton <> nil then
    FStopButton.Enabled := False;
  AppendEngineLog(LineEnding + '[engine process terminated]' + LineEnding);
end;

procedure AppendInteger(var AValues: TIntegerArray; AValue: Integer);
begin
  SetLength(AValues, Length(AValues) + 1);
  AValues[High(AValues)] := AValue;
end;

function ParseMoveNumbers(const AMoveText: String; out ANumbers: TIntegerArray;
  out AIsCapture: Boolean): Boolean;
var
  I: Integer;
  NumberStart: Integer;
begin
  Result := True;
  SetLength(ANumbers, 0);
  AIsCapture := Pos('x', AMoveText) > 0;
  I := 1;

  while I <= Length(AMoveText) do
  begin
    if AMoveText[I] in ['0'..'9'] then
    begin
      NumberStart := I;
      while (I <= Length(AMoveText)) and (AMoveText[I] in ['0'..'9']) do
        Inc(I);
      AppendInteger(ANumbers, StrToIntDef(Copy(AMoveText, NumberStart,
        I - NumberStart), 0));
    end
    else
      Inc(I);
  end;

  Result := Length(ANumbers) >= 2;
end;

function SameIntegerSet(const ALeft: array of Integer; const ARight: array of Integer): Boolean;
var
  I: Integer;
  J: Integer;
  Matched: array of Boolean;
begin
  if Length(ALeft) <> Length(ARight) then
    Exit(False);

  SetLength(Matched, Length(ARight));
  for I := 0 to High(ALeft) do
  begin
    Result := False;
    for J := 0 to High(ARight) do
      if (not Matched[J]) and (ALeft[I] = ARight[J]) then
      begin
        Matched[J] := True;
        Result := True;
        Break;
      end;

    if not Result then
      Exit(False);
  end;

  Result := True;
end;

function TMainWindow.EngineMoveMatchesLegalMove(const AEngineMove: String;
  const ALegalMove: TMove): Boolean;
var
  CapturedByEngine: TIntegerArray;
  I: Integer;
  IsCapture: Boolean;
  Numbers: TIntegerArray;
begin
  if (not ParseMoveNumbers(AEngineMove, Numbers, IsCapture)) or
    (Length(ALegalMove.Squares) < 2) then
    Exit(False);

  if Numbers[0] <> ALegalMove.Squares[0] then
    Exit(False);

  if Numbers[1] <> ALegalMove.Squares[High(ALegalMove.Squares)] then
    Exit(False);

  if IsCapture <> (Length(ALegalMove.Captures) > 0) then
    Exit(False);

  if not IsCapture then
    Exit(True);

  SetLength(CapturedByEngine, Length(Numbers) - 2);
  for I := 2 to High(Numbers) do
    CapturedByEngine[I - 2] := Numbers[I];

  Result := SameIntegerSet(CapturedByEngine, ALegalMove.Captures);
end;

function TMainWindow.EngineMoveIndex(const AEngineMove: String): Integer;
var
  I: Integer;
begin
  Result := -1;
  if AEngineMove = '' then
    Exit;

  for I := 0 to High(FMoves) do
    if EngineMoveMatchesLegalMove(AEngineMove, FMoves[I]) then
      Exit(I);
end;

function TMainWindow.PlayEngineMove(const AEngineMove: String): Boolean;
var
  Annotation: String;
  MoveIndex: Integer;
  MoveToPlay: TMove;
begin
  Result := False;
  MoveIndex := EngineMoveIndex(AEngineMove);
  if MoveIndex >= 0 then
  begin
    AppendEngineLog('[executing engine move ' + AEngineMove + ']' + LineEnding);
    UpdateGameClock;
    Annotation := FLastEngineInfoAnnotation;
    FLastEngineInfoAnnotation := '';
    CopyMove(FMoves[MoveIndex], MoveToPlay);
    ApplyMove(MoveToPlay);
    RecordPlayedMove(MoveToPlay, Annotation);
    SysUtils.Beep;
    Exit(True);
  end;

  AppendEngineLog('[engine move is not legal here: ' + AEngineMove + ']' + LineEnding);
end;

procedure TMainWindow.HandleEngineDoneMove(const AMoveText: String);
begin
  FEngineSearching := False;
  FEngineStopRequested := False;
  SetEngineState(esIdle);
  case FEngineSearchMode of
  esmAutoPlay:
  begin
    FEngineSearchMode := esmIdle;
    if PlayEngineMove(AMoveText) then
    begin
      Inc(FAutoPlayPlyCount);
      if Length(FMoves) = 0 then
      begin
        FAutoPlayActive := False;
        AppendEngineLog('[auto-play stopped: terminal position]' + LineEnding);
      end
      else if FAutoPlayPlyCount >= 255 then
      begin
        FAutoPlayActive := False;
        AppendEngineLog('[auto-play stopped: 255 moves reached]' + LineEnding);
      end
      else
        SendGoThinkToEngine(esmAutoPlay);
    end
    else
    begin
      FAutoPlayActive := False;
      AppendEngineLog('[auto-play stopped: engine move could not be played]' +
        LineEnding);
    end;
  end;
  esmPlayGameThink:
  begin
    FEngineSearchMode := esmIdle;
    if PlayEngineMove(AMoveText) then
    begin
      if Length(FMoves) = 0 then
      begin
        LeavePlayGameMode;
        AppendEngineLog('[play game stopped: terminal position]' + LineEnding);
      end
      else
        SendPlayGameHumanTurnPonder;
    end
    else
    begin
      LeavePlayGameMode;
      AppendEngineLog('[play game stopped: engine move could not be played]' +
        LineEnding);
    end;
  end;
  esmPonder, esmPlayGamePonder:
  begin
    FEngineSearchMode := esmIdle;
    if AMoveText <> '' then
    begin
      UpdatePonderBestMoveFromMoveText(AMoveText);
      AppendEngineLog('[ponder move ignored: ' + AMoveText + ']' + LineEnding)
    end
    else
      AppendEngineLog('[ponder done]' + LineEnding);
  end;
  esmMcts:
  begin
    FEngineSearchMode := esmIdle;
    if ExtractHubArgument(FLastEngineDoneLine, 'result') <> '' then
      AppendEngineLog('[mcts done: result=' +
        ExtractHubArgument(FLastEngineDoneLine, 'result') + ']' + LineEnding)
    else
      AppendEngineLog('[mcts done: nshootouts=' +
        ExtractHubArgument(FLastEngineDoneLine, 'nshootouts') + ' nwon=' +
        ExtractHubArgument(FLastEngineDoneLine, 'nwon') + ' ndraw=' +
        ExtractHubArgument(FLastEngineDoneLine, 'ndraw') + ' nlost=' +
        ExtractHubArgument(FLastEngineDoneLine, 'nlost') + ']' + LineEnding);
  end;
  else
    if (AMoveText <> '') and FAutoPlayActive and
      (EngineMoveIndex(AMoveText) >= 0) then
    begin
      AppendEngineLog('[recovering auto-play move in idle state]' + LineEnding);
      FEngineSearchMode := esmAutoPlay;
      HandleEngineDoneMove(AMoveText);
    end
    else if AMoveText <> '' then
      AppendEngineLog('[engine move ignored: ' + AMoveText + ']' + LineEnding)
    else
      AppendEngineLog('[engine done]' + LineEnding);
  end;
end;

procedure TMainWindow.ProcessEngineOutput(const AText: String);
var
  ErrorText: String;
  Line: String;
  LineEnd: Integer;
  MoveText: String;
begin
  FEngineTextBuffer += AText;

  while True do
  begin
    LineEnd := Pos(LineEnding, FEngineTextBuffer);
    if LineEnd = 0 then
      LineEnd := Pos(#10, FEngineTextBuffer);
    if LineEnd = 0 then
      Break;

    Line := Trim(Copy(FEngineTextBuffer, 1, LineEnd - 1));
    Delete(FEngineTextBuffer, 1, LineEnd);

    if Line = 'wait' then
    begin
      if not FEngineWaitingForInit then
      begin
        FEngineWaitingForInit := True;
        SendEngineParams;
        AppendEngineLog('> init' + LineEnding);
        SendEngineCommand('init');
      end;
    end
    else if Line = 'ready' then
    begin
      FEngineReady := True;
      FEngineWaitingForInit := False;
      if FAutoPlayButton <> nil then
        FAutoPlayButton.Enabled := True;
      if FPlayGameButton <> nil then
        FPlayGameButton.Enabled := True;
      if FGoButton <> nil then
        FGoButton.Enabled := True;
      if FMctsButton <> nil then
        FMctsButton.Enabled := True;
      if FStopButton <> nil then
        FStopButton.Enabled := True;
      AppendEngineLog('[engine ready]' + LineEnding);
      if FEngineParamsFileName <> '' then
        SaveParamsToJson(FEngineParamsFileName, FEngineParams);
      if FEngineStartAfterReady then
      begin
        FEngineStartAfterReady := False;
        SendGoPonderToEngine;
      end;
    end
    else if StartsText('param ', Line) then
      AddOrUpdateParam(FEngineParams, ExtractHubArgument(Line, 'name'),
        ExtractHubArgument(Line, 'type'), ExtractHubArgument(Line, 'value'), True)
    else if StartsText('info ', Line) then
    begin
      FLastEngineInfoAnnotation := EngineInfoAnnotation(Line);
      UpdatePonderBestMoveFromInfo(Line);
    end
    else if StartsText('error ', Line) then
    begin
      ErrorText := ExtractHubArgument(Line, 'message');
      if ErrorText = '' then
        ErrorText := Line;
      AppendEngineLog('[engine error: ' + ErrorText + ']' + LineEnding);
      FPendingAutoPlayStart := False;
      FPendingPonderStart := False;
      FPendingMctsStart := False;
      FPendingPlayGameStart := False;
      FPendingThinkStart := False;
      FIgnoreNextDoneMove := False;
      FEngineSearching := False;
      FEngineStopRequested := False;
      FEngineSearchMode := esmIdle;
      SetEngineState(esIdle);
    end
    else if StartsText('done ', Line) or (Line = 'done') then
    begin
      FLastEngineDoneLine := Line;
      MoveText := ExtractHubArgument(Line, 'move');
      if FPendingAutoPlayStart then
      begin
        FIgnoreNextDoneMove := False;
        FEngineSearching := False;
        FEngineStopRequested := False;
        FEngineSearchMode := esmIdle;
        SetEngineState(esIdle);
        if MoveText <> '' then
          AppendEngineLog('[ignored previous-search move ' + MoveText + ']' +
            LineEnding)
        else
          AppendEngineLog('[previous search stopped]' + LineEnding);
        BeginAutoPlay;
      end
      else if FPendingPonderStart then
      begin
        FIgnoreNextDoneMove := False;
        FEngineSearching := False;
        FEngineStopRequested := False;
        FEngineSearchMode := esmIdle;
        SetEngineState(esIdle);
        if MoveText <> '' then
          AppendEngineLog('[ignored previous-search move ' + MoveText + ']' +
            LineEnding)
        else
          AppendEngineLog('[previous search stopped]' + LineEnding);
        FPendingPonderStart := False;
        SendGoPonderToEngine(FPendingPonderMode);
      end
      else if FPendingMctsStart then
      begin
        FIgnoreNextDoneMove := False;
        FEngineSearching := False;
        FEngineStopRequested := False;
        FEngineSearchMode := esmIdle;
        SetEngineState(esIdle);
        if MoveText <> '' then
          AppendEngineLog('[ignored previous-search move ' + MoveText + ']' +
            LineEnding)
        else
          AppendEngineLog('[previous search stopped]' + LineEnding);
        FPendingMctsStart := False;
        SendGoMctsToEngine;
      end
      else if FPendingThinkStart then
      begin
        FIgnoreNextDoneMove := False;
        FEngineSearching := False;
        FEngineStopRequested := False;
        FEngineSearchMode := esmIdle;
        SetEngineState(esIdle);
        if MoveText <> '' then
          AppendEngineLog('[ignored previous-search move ' + MoveText + ']' +
            LineEnding)
        else
          AppendEngineLog('[previous search stopped]' + LineEnding);
        FPendingThinkStart := False;
        SendGoThinkToEngine(FPendingThinkMode);
      end
      else if FPendingPlayGameStart then
      begin
        FIgnoreNextDoneMove := False;
        FEngineSearching := False;
        FEngineStopRequested := False;
        FEngineSearchMode := esmIdle;
        SetEngineState(esIdle);
        if MoveText <> '' then
          AppendEngineLog('[ignored previous-search move ' + MoveText + ']' +
            LineEnding)
        else
          AppendEngineLog('[previous search stopped]' + LineEnding);
        BeginPlayGame(FPendingPlayGameSide, FPendingPlayGameMinutes,
          FPendingPlayGameFromCurrent);
      end
      else if FIgnoreNextDoneMove then
      begin
        FIgnoreNextDoneMove := False;
        FEngineSearching := False;
        FEngineStopRequested := False;
        FEngineSearchMode := esmIdle;
        SetEngineState(esIdle);
        if MoveText <> '' then
          AppendEngineLog('[ignored stopped-search move ' + MoveText + ']' + LineEnding)
        else
          AppendEngineLog('[ignored stopped-search done]' + LineEnding);
      end
      else
        HandleEngineDoneMove(MoveText);
    end;
  end;
end;

procedure TMainWindow.GoButtonClick(Sender: TObject);
begin
  FAutoPlayActive := False;
  FPendingAutoPlayStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  LeavePlayGameMode;
  if FEngineState <> esIdle then
  begin
    FPendingPonderMode := esmPonder;
    FPendingPonderStart := True;
    AppendEngineLog('[stopping previous search before manual GO]' + LineEnding);
    SendStopToEngine;
  end
  else
  begin
    FPendingPonderStart := False;
    AppendEngineLog('[manual GO: starting ponder]' + LineEnding);
    SendGoPonderToEngine(esmPonder);
  end;
end;

procedure TMainWindow.MctsButtonClick(Sender: TObject);
begin
  FAutoPlayActive := False;
  FPendingAutoPlayStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  LeavePlayGameMode;
  if FEngineState <> esIdle then
  begin
    FPendingPonderStart := False;
    FPendingMctsStart := True;
    AppendEngineLog('[stopping previous search before manual MCTS]' + LineEnding);
    SendStopToEngine;
  end
  else
  begin
    FPendingPonderStart := False;
    FPendingMctsStart := False;
    AppendEngineLog('[manual MCTS: starting mcts]' + LineEnding);
    SendGoMctsToEngine;
  end;
end;

procedure TMainWindow.AutoPlayButtonClick(Sender: TObject);
begin
  if not EngineIsRunning or (not FEngineReady) then
    Exit;

  if FCurrentPly < Length(FHistoryMoves) then
  begin
    SetLength(FHistoryMoves, FCurrentPly);
    SetLength(FHistoryMoveAnnotations, FCurrentPly);
    SetLength(FHistoryClockSnapshots, FCurrentPly);
    UpdateHistoryList;
  end;
  UpdateHistoryList;
  if FEngineState <> esIdle then
  begin
    FPendingAutoPlayStart := True;
    FPendingMctsStart := False;
    FPendingPonderStart := False;
    FPendingPlayGameStart := False;
    LeavePlayGameMode;
    FAutoPlayActive := False;
    FAutoPlayPlyCount := 0;
    AppendEngineLog('[stopping previous search before auto-play]' + LineEnding);
    SendStopToEngine;
    Exit;
  end;

  BeginAutoPlay;
end;

procedure TMainWindow.BeginAutoPlay;
begin
  FPendingAutoPlayStart := False;
  FPendingPonderStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FIgnoreNextDoneMove := False;
  LeavePlayGameMode;
  FAutoPlayActive := True;
  FAutoPlayPlyCount := 0;
  AppendEngineLog('[auto-play started]' + LineEnding);
  SendGoThinkToEngine(esmAutoPlay);
end;

procedure TMainWindow.StartPlayGameFromOptions(AHumanSide: TSide;
  AGameMinutes: Double; AStartFromCurrent: Boolean);
begin
  if AGameMinutes <= 0 then
    AGameMinutes := 5;
  if FEngineState <> esIdle then
  begin
    BeginPlayGame(AHumanSide, AGameMinutes, AStartFromCurrent, False);
    FPendingAutoPlayStart := False;
    FPendingMctsStart := False;
    FPendingPlayGameStart := False;
    if IsPlayGameHumanTurn then
    begin
      FPendingPonderMode := esmPlayGamePonder;
      FPendingPonderStart := True;
      FPendingThinkStart := False;
    end
    else
    begin
      FPendingPonderStart := False;
      FPendingThinkMode := esmPlayGameThink;
      FPendingThinkStart := True;
    end;
    FAutoPlayActive := False;
    AppendEngineLog('[stopping previous search before starting game]' + LineEnding);
    SendStopToEngine;
    Exit;
  end;

  BeginPlayGame(AHumanSide, AGameMinutes, AStartFromCurrent);
end;

procedure TMainWindow.BeginPlayGame(AHumanSide: TSide; AGameMinutes: Double;
  AStartFromCurrent: Boolean; AStartSearch: Boolean);
begin
  FPendingAutoPlayStart := False;
  FPendingPonderStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  FIgnoreNextDoneMove := False;
  ResetClocks;
  FPlayGameHumanSide := AHumanSide;
  FAutoPlayActive := False;
  FPlayGameActive := True;
  FGameWhiteName := 'White';
  FGameBlackName := 'Black';
  FGameResult := '*';
  if not AStartFromCurrent then
    ParseFen('W:W31-50:B1-20');
  ResetHistoryFromCurrentPosition;
  MarkGameDirty;
  StartGameClocks(AGameMinutes);
  UpdateMoveList;
  UpdateHistoryList;
  InvalidateBoard;
  if FPlayGameHumanSide = sideWhite then
    AppendEngineLog('[play game started: human=white, minutes=' +
      FormatFloat('0.###', AGameMinutes) + ']' + LineEnding)
  else
    AppendEngineLog('[play game started: human=black, minutes=' +
      FormatFloat('0.###', AGameMinutes) + ']' + LineEnding);

  if not AStartSearch then
    Exit;

  if IsPlayGameHumanTurn then
    SendPlayGameHumanTurnPonder
  else
    SendGoThinkToEngine(esmPlayGameThink);
end;

procedure TMainWindow.PlayGameButtonClick(Sender: TObject);
begin
  ShowPlayGameDialog;
end;

procedure TMainWindow.PlayGameDialogButtonClick(Sender: TObject);
begin
  if FPlayGameDialog = nil then
    Exit;
  if Sender is TButton then
    FPlayGameDialog.ModalResult := TButton(Sender).ModalResult
  else
    FPlayGameDialog.ModalResult := mrCancel;
  FPlayGameDialog.Hide;
end;

procedure TMainWindow.PlayGameDialogHide(Sender: TObject);
var
  Accepted: Boolean;
  Dialog: TForm;
  GameMinutes: Double;
  HumanSide: TSide;
  StartFromCurrent: Boolean;
begin
  if Sender is TForm then
    Dialog := TForm(Sender)
  else
    Dialog := FPlayGameDialog;

  Accepted := (Dialog <> nil) and (Dialog.ModalResult = mrOK);

  if Accepted then
  begin
    if (FPlayGameBlackRadio <> nil) and FPlayGameBlackRadio.Checked then
      HumanSide := sideBlack
    else
      HumanSide := sideWhite;
    StartFromCurrent := (FPlayGameCurrentPositionRadio <> nil) and
      FPlayGameCurrentPositionRadio.Checked;
    if FPlayGameMinutesSpin <> nil then
      GameMinutes := FPlayGameMinutesSpin.Value
    else
      GameMinutes := 5;
  end
  else
  begin
    HumanSide := sideWhite;
    StartFromCurrent := False;
    GameMinutes := 5;
  end;

  FPlayGameDialog := nil;
  FPlayGameBlackRadio := nil;
  FPlayGameCurrentPositionRadio := nil;
  FPlayGameMinutesSpin := nil;

  if Dialog <> nil then
    Dialog.Release;

  if Accepted then
    StartPlayGameFromOptions(HumanSide, GameMinutes, StartFromCurrent);
end;

procedure TMainWindow.ShowPlayGameDialog;
var
  ButtonPanel: TPanel;
  CancelButton: TButton;
  ColorGroup: TPanel;
  ColorLabel: TLabel;
  Dialog: TForm;
  MinutesLabel: TLabel;
  OKButton: TButton;
  PositionGroup: TPanel;
  PositionLabel: TLabel;
  StandardPositionRadio: TRadioButton;
  WhiteRadio: TRadioButton;
begin
  if FPlayGameDialog <> nil then
  begin
    FPlayGameDialog.BringToFront;
    Exit;
  end;

  Dialog := TForm.Create(Self);
  Dialog.BorderStyle := bsDialog;
  Dialog.Caption := 'Play game';
  Dialog.ClientWidth := 300;
  Dialog.ClientHeight := 280;
  Dialog.Color := clBtnFace;
  Dialog.Position := poOwnerFormCenter;
  Dialog.ModalResult := mrCancel;
  Dialog.OnHide := @PlayGameDialogHide;

  ColorLabel := TLabel.Create(Dialog);
  ColorLabel.Parent := Dialog;
  ColorLabel.SetBounds(16, 12, 120, 20);
  ColorLabel.Caption := 'Colour:';

  ColorGroup := TPanel.Create(Dialog);
  ColorGroup.Parent := Dialog;
  ColorGroup.SetBounds(16, 34, 268, 60);
  ColorGroup.BevelOuter := bvLowered;

  WhiteRadio := TRadioButton.Create(ColorGroup);
  WhiteRadio.Parent := ColorGroup;
  WhiteRadio.SetBounds(12, 6, 220, 24);
  WhiteRadio.Caption := 'Play as White';
  WhiteRadio.Checked := True;

  FPlayGameBlackRadio := TRadioButton.Create(ColorGroup);
  FPlayGameBlackRadio.Parent := ColorGroup;
  FPlayGameBlackRadio.SetBounds(12, 32, 220, 24);
  FPlayGameBlackRadio.Caption := 'Play as Black';

  PositionLabel := TLabel.Create(Dialog);
  PositionLabel.Parent := Dialog;
  PositionLabel.SetBounds(16, 104, 120, 20);
  PositionLabel.Caption := 'Start from:';

  PositionGroup := TPanel.Create(Dialog);
  PositionGroup.Parent := Dialog;
  PositionGroup.SetBounds(16, 126, 268, 60);
  PositionGroup.BevelOuter := bvLowered;

  StandardPositionRadio := TRadioButton.Create(PositionGroup);
  StandardPositionRadio.Parent := PositionGroup;
  StandardPositionRadio.SetBounds(12, 6, 250, 24);
  StandardPositionRadio.Caption := 'Beginning';
  StandardPositionRadio.Checked := True;

  FPlayGameCurrentPositionRadio := TRadioButton.Create(PositionGroup);
  FPlayGameCurrentPositionRadio.Parent := PositionGroup;
  FPlayGameCurrentPositionRadio.SetBounds(12, 32, 250, 24);
  FPlayGameCurrentPositionRadio.Caption := 'Current position';

  MinutesLabel := TLabel.Create(Dialog);
  MinutesLabel.Parent := Dialog;
  MinutesLabel.SetBounds(16, 202, 120, 24);
  MinutesLabel.Layout := tlCenter;
  MinutesLabel.Caption := 'Minutes:';

  FPlayGameMinutesSpin := TFloatSpinEdit.Create(Dialog);
  FPlayGameMinutesSpin.Parent := Dialog;
  FPlayGameMinutesSpin.SetBounds(136, 200, 100, 26);
  FPlayGameMinutesSpin.DecimalPlaces := 1;
  FPlayGameMinutesSpin.Increment := 1;
  FPlayGameMinutesSpin.MinValue := 0.1;
  FPlayGameMinutesSpin.MaxValue := 1440;
  FPlayGameMinutesSpin.Value := 5;

  ButtonPanel := TPanel.Create(Dialog);
  ButtonPanel.Parent := Dialog;
  ButtonPanel.Align := alBottom;
  ButtonPanel.Height := 42;
  ButtonPanel.BevelOuter := bvNone;
  ButtonPanel.ParentColor := True;

  OKButton := TButton.Create(ButtonPanel);
  OKButton.Parent := ButtonPanel;
  OKButton.Caption := 'OK';
  OKButton.ModalResult := mrOK;
  OKButton.OnClick := @PlayGameDialogButtonClick;
  OKButton.SetBounds(122, 8, 80, 26);
  Dialog.DefaultControl := OKButton;

  CancelButton := TButton.Create(ButtonPanel);
  CancelButton.Parent := ButtonPanel;
  CancelButton.Caption := 'Cancel';
  CancelButton.ModalResult := mrCancel;
  CancelButton.OnClick := @PlayGameDialogButtonClick;
  CancelButton.SetBounds(208, 8, 80, 26);
  Dialog.CancelControl := CancelButton;

  FPlayGameDialog := Dialog;
  Dialog.Show;
end;

procedure TMainWindow.StopButtonClick(Sender: TObject);
begin
  FAutoPlayActive := False;
  FPendingAutoPlayStart := False;
  FPendingPonderStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  AppendEngineLog('[manual STOP]' + LineEnding);
  LeavePlayGameMode;
  SendStopToEngine;
end;

function TMainWindow.HubPositionString: String;
begin
  Result := HubPositionStringFor(FBoard, FSideToMove);
end;

function TMainWindow.HubPositionStringFor(const ABoard: TBoard; ASide: TSide): String;
var
  Square: Integer;
begin
  if ASide = sideWhite then
    Result := 'W'
  else
    Result := 'B';

  for Square := Low(ABoard) to High(ABoard) do
    case ABoard[Square] of
      pcWhiteMan: Result += 'w';
      pcBlackMan: Result += 'b';
      pcWhiteKing: Result += 'W';
      pcBlackKing: Result += 'B';
    else
      Result += 'e';
    end;
end;

function TMainWindow.HubPositionCommand: String;
var
  I: Integer;
  MoveText: String;
begin
  Result := 'pos pos=' + HubPositionStringFor(FHistoryBaseBoard, FHistoryBaseSide);
  MoveText := '';
  for I := 0 to Min(FCurrentPly, Length(FHistoryMoves)) - 1 do
  begin
    if MoveText <> '' then
      MoveText += ' ';
    MoveText += MoveToString(FHistoryMoves[I]);
  end;
  if MoveText <> '' then
    Result += ' moves=' + HubQuote(MoveText);
end;

function TMainWindow.CurrentEngineRemainingTimeSeconds: Double;
begin
  UpdateGameClock;

  if FPlayGameHumanSide = sideWhite then
    Result := FBlackClockSeconds
  else
    Result := FWhiteClockSeconds;

  if Result < 0 then
    Result := 0;
end;

function TMainWindow.IsPlayGameHumanTurn: Boolean;
begin
  Result := FPlayGameActive and (FSideToMove = FPlayGameHumanSide);
end;

function TMainWindow.BoardToFen(const ABoard: TBoard; ASide: TSide): String;
var
  BlackText: String;
  Square: Integer;
  WhiteText: String;

  procedure AddPiece(var AText: String; ASquare: Integer; IsKing: Boolean);
  begin
    if AText <> '' then
      AText += ',';
    if IsKing then
      AText += 'K';
    AText += IntToStr(ASquare);
  end;

begin
  WhiteText := '';
  BlackText := '';

  for Square := Low(ABoard) to High(ABoard) do
    case ABoard[Square] of
      pcWhiteMan: AddPiece(WhiteText, Square, False);
      pcWhiteKing: AddPiece(WhiteText, Square, True);
      pcBlackMan: AddPiece(BlackText, Square, False);
      pcBlackKing: AddPiece(BlackText, Square, True);
    end;

  if ASide = sideWhite then
    Result := 'W'
  else
    Result := 'B';
  Result += ':W' + WhiteText + ':B' + BlackText;
end;

function TMainWindow.EngineInfoAnnotation(const ALine: String): String;
var
  DepthText: String;
  ScoreText: String;
  TimeText: String;
begin
  DepthText := ExtractHubArgument(ALine, 'depth');
  ScoreText := ExtractHubArgument(ALine, 'score');
  TimeText := ExtractHubArgument(ALine, 'time');

  Result := '';
  if DepthText <> '' then
    Result := 'depth=' + DepthText;
  if ScoreText <> '' then
  begin
    if Result <> '' then
      Result += ' ';
    Result += 'score=' + ScoreText;
  end;
  if TimeText <> '' then
  begin
    if Result <> '' then
      Result += ' ';
    Result += 'time=' + TimeText;
  end;
end;

procedure TMainWindow.UpdatePonderBestMoveFromInfo(const ALine: String);
begin
  if FEngineSearchMode = esmIdle then
    Exit;

  UpdatePonderBestMoveFromMoveText(ExtractHubArgument(ALine, 'pv'));
end;

procedure TMainWindow.UpdatePonderBestMoveFromMoveText(const AMoveText: String);
var
  MoveIndex: Integer;
  MoveText: String;
  NewSourceSquare: Integer;
begin
  MoveText := AMoveText;
  if MoveText = '' then
    Exit;
  if Pos(' ', MoveText) > 0 then
    MoveText := Copy(MoveText, 1, Pos(' ', MoveText) - 1);

  MoveIndex := EngineMoveIndex(MoveText);
  if (MoveIndex >= 0) and (Length(FMoves[MoveIndex].Squares) > 0) then
    NewSourceSquare := FMoves[MoveIndex].Squares[0]
  else
    NewSourceSquare := 0;

  if FPonderBestSourceSquare = NewSourceSquare then
    Exit;

  FPonderBestSourceSquare := NewSourceSquare;
  InvalidateBoard;
end;

function TMainWindow.ClockAnnotation(APly: Integer): String;
begin
  Result := '';
  if (APly <= 0) or (APly > Length(FHistoryClockSnapshots)) or
    (not FHistoryClockSnapshots[APly - 1].HasClock) then
    Exit;

  Result := 'clock=[' +
    FormatClockAnnotationSeconds(FHistoryClockSnapshots[APly - 1].WhiteSeconds) +
    ', ' +
    FormatClockAnnotationSeconds(FHistoryClockSnapshots[APly - 1].BlackSeconds) +
    ']';
end;

function TMainWindow.BuildPdnMoveText(const AResult: String;
  AStoreRanges: Boolean): String;
var
  Annotation: String;
  Clocks: String;
  I: Integer;
  MoveNumber: Integer;
  MoveText: String;

  procedure AppendText(const AText: String);
  begin
    Result += AText;
  end;

  procedure AppendMove(APly: Integer; const APrefix, AMoveText: String);
  begin
    AppendText(APrefix);
    if AStoreRanges then
    begin
      FHistoryMoveStarts[APly] := Length(Result);
      FHistoryMoveLengths[APly] := Length(AMoveText);
    end;
    AppendText(AMoveText);
    if (APly > 0) and (APly <= Length(FHistoryMoveAnnotations)) then
    begin
      Annotation := FHistoryMoveAnnotations[APly - 1];
      Clocks := ClockAnnotation(APly);
      if Clocks <> '' then
      begin
        if Annotation <> '' then
          Annotation += ' ';
        Annotation += Clocks;
      end;
      if Annotation <> '' then
        AppendText(' {' + Annotation + '}');
    end;
    AppendText(' ');
  end;

begin
  Result := '';
  if AStoreRanges then
  begin
    SetLength(FHistoryMoveStarts, Length(FHistoryMoves) + 1);
    SetLength(FHistoryMoveLengths, Length(FHistoryMoves) + 1);
  end;

  for I := 0 to High(FHistoryMoves) do
  begin
    MoveText := MoveToString(FHistoryMoves[I]);
    if FHistoryBaseSide = sideWhite then
    begin
      MoveNumber := (I div 2) + 1;
      if not Odd(I) then
        AppendMove(I + 1, Format('%d. ', [MoveNumber]), MoveText)
      else
        AppendMove(I + 1, '', MoveText);
    end
    else
    begin
      if I = 0 then
        AppendMove(I + 1, '1... ', MoveText)
      else if Odd(I) then
      begin
        MoveNumber := (I div 2) + 2;
        AppendMove(I + 1, Format('%d. ', [MoveNumber]), MoveText);
      end
      else
        AppendMove(I + 1, '', MoveText);
    end;
  end;

  AppendText(AResult);
  Result := Trim(Result);
end;

function TMainWindow.GuessResultFromFinalPosition: String;
var
  SavedBoard: TBoard;
  SavedMoves: TMoveArray;
  SavedPly: Integer;
  SavedSide: TSide;
begin
  SavedBoard := FBoard;
  SavedSide := FSideToMove;
  SavedPly := FCurrentPly;
  SavedMoves := FMoves;
  try
    RebuildPositionToPly(Length(FHistoryMoves));
    if Length(FMoves) = 0 then
      if FSideToMove = sideWhite then
        Result := '0-2'
      else
        Result := '2-0'
    else
      Result := '*';
  finally
    FBoard := SavedBoard;
    FSideToMove := SavedSide;
    FCurrentPly := SavedPly;
    FMoves := SavedMoves;
    UpdateMoveList;
    UpdateHistoryList;
    InvalidateBoard;
  end;
end;

procedure TMainWindow.CopyFenMenuItemClick(Sender: TObject);
var
  Fen: String;
begin
  Fen := BoardToFen(FBoard, FSideToMove);
  Clipboard.AsText := Fen;
  AppendEngineLog('[copied FEN ' + Fen + ']' + LineEnding);
end;

procedure TMainWindow.OpenFenMenuItemClick(Sender: TObject);
begin
  if FOpenDialog.Execute then
  begin
    try
      LoadFenFile(FOpenDialog.FileName);
    except
      on E: Exception do
        MessageDlg('Open FEN', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainWindow.OpenPdnMenuItemClick(Sender: TObject);
begin
  if FOpenPdnDialog.Execute then
  begin
    try
      LoadPdnFile(FOpenPdnDialog.FileName);
    except
      on E: Exception do
        MessageDlg('Open PDN', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainWindow.MainWindowCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := False;
  ShutdownApplication;
end;

procedure TMainWindow.QuitMenuItemClick(Sender: TObject);
begin
  ShutdownApplication;
end;

procedure TMainWindow.ShutdownApplication;
begin
  if FShuttingDown then
    Exit;

  if FGameDirty and (not FShutdownConfirmed) then
  begin
    ShowUnsavedGamePrompt;
    Exit;
  end;

  FinalizeShutdown;
end;

procedure TMainWindow.FinalizeShutdown;
begin
  if FShuttingDown then
    Exit;

  FShuttingDown := True;
  CloseEngine;
  Application.Terminate;
  Halt(0);
end;

procedure TMainWindow.ShowUnsavedGamePrompt;
var
  Button: TButton;
  Dialog: TForm;
  PromptLabel: TLabel;
begin
  if FUnsavedGamePromptDialog <> nil then
  begin
    FUnsavedGamePromptDialog.BringToFront;
    Exit;
  end;

  Dialog := TForm.Create(Self);
  FUnsavedGamePromptDialog := Dialog;
  Dialog.BorderStyle := bsDialog;
  Dialog.Caption := 'Unsaved game';
  Dialog.ClientWidth := 360;
  Dialog.ClientHeight := 150;
  Dialog.Color := clBtnFace;
  Dialog.Position := poOwnerFormCenter;
  Dialog.ModalResult := mrCancel;
  Dialog.OnHide := @UnsavedGamePromptHide;

  PromptLabel := TLabel.Create(Dialog);
  PromptLabel.Parent := Dialog;
  PromptLabel.SetBounds(16, 26, 328, 52);
  PromptLabel.WordWrap := True;
  PromptLabel.Caption := 'The current game has unsaved PDN changes.' +
    LineEnding + 'Save it before quitting?';

  Button := TButton.Create(Dialog);
  Button.Parent := Dialog;
  Button.Caption := 'Save';
  Button.ModalResult := mrYes;
  Button.SetBounds(80, 104, 80, 28);
  Button.OnClick := @UnsavedGamePromptButtonClick;
  Dialog.DefaultControl := Button;

  Button := TButton.Create(Dialog);
  Button.Parent := Dialog;
  Button.Caption := 'Don''t Save';
  Button.ModalResult := mrNo;
  Button.SetBounds(166, 104, 88, 28);
  Button.OnClick := @UnsavedGamePromptButtonClick;

  Button := TButton.Create(Dialog);
  Button.Parent := Dialog;
  Button.Caption := 'Cancel';
  Button.ModalResult := mrCancel;
  Button.SetBounds(260, 104, 80, 28);
  Button.OnClick := @UnsavedGamePromptButtonClick;
  Dialog.CancelControl := Button;

  Dialog.Show;
end;

procedure TMainWindow.UnsavedGamePromptButtonClick(Sender: TObject);
begin
  if FUnsavedGamePromptDialog = nil then
    Exit;
  if Sender is TButton then
    FUnsavedGamePromptDialog.ModalResult := TButton(Sender).ModalResult
  else
    FUnsavedGamePromptDialog.ModalResult := mrCancel;
  FUnsavedGamePromptDialog.Hide;
end;

procedure TMainWindow.UnsavedGamePromptHide(Sender: TObject);
var
  Dialog: TForm;
  PromptResult: Integer;
begin
  if Sender is TForm then
    Dialog := TForm(Sender)
  else
    Dialog := FUnsavedGamePromptDialog;

  if Dialog <> nil then
    PromptResult := Dialog.ModalResult
  else
    PromptResult := mrCancel;

  FUnsavedGamePromptDialog := nil;
  if Dialog <> nil then
    Dialog.Release;

  case PromptResult of
    mrYes:
    begin
      FShutdownAfterPdnSave := True;
      SavePdnMenuItemClick(nil);
    end;
    mrNo:
    begin
      FShutdownConfirmed := True;
      FinalizeShutdown;
    end;
  end;
end;

procedure TMainWindow.SendPositionMenuItemClick(Sender: TObject);
begin
  SendPositionToEngine;
end;

procedure TMainWindow.SendPositionToEngine;
var
  Command: String;
begin
  if not EngineIsRunning then
    Exit;
  if not FEngineReady then
    Exit;
  if Length(FMoves) = 0 then
  begin
    AppendEngineLog('[not sending terminal position]' + LineEnding);
    Exit;
  end;

  Command := HubPositionCommand;
  AppendEngineLog('> ' + Command + LineEnding);
  SendEngineCommand(Command);
end;

procedure TMainWindow.SendPlayGameHumanTurnPonder;
begin
  if not FPlayGameActive then
    Exit;
  if Length(FMoves) = 0 then
  begin
    LeavePlayGameMode;
    AppendEngineLog('[play game stopped: terminal position]' + LineEnding);
    Exit;
  end;

  if FEngineState <> esIdle then
  begin
    FPendingAutoPlayStart := False;
    FPendingMctsStart := False;
    FPendingPonderMode := esmPlayGamePonder;
    FPendingPonderStart := True;
    FPendingPlayGameStart := False;
    FPendingThinkStart := False;
    AppendEngineLog('[stopping previous search before play-game ponder]' +
      LineEnding);
    SendStopToEngine;
  end
  else
    SendGoPonderToEngine(esmPlayGamePonder);
end;

procedure TMainWindow.SendGoPonderToEngine(AMode: TEngineSearchMode);
var
  FormatSettings: TFormatSettings;
  LevelCommand: String;
  PositionCommand: String;
begin
  if not EngineIsRunning then
    Exit;
  if not FEngineReady then
    Exit;
  if Length(FMoves) = 0 then
  begin
    AppendEngineLog('[not starting search: terminal position]' + LineEnding);
    FEngineSearching := False;
    FEngineSearchMode := esmIdle;
    SetEngineState(esIdle);
    Exit;
  end;

  PositionCommand := HubPositionCommand;
  AppendEngineLog('> ' + PositionCommand + LineEnding);
  SendEngineCommand(PositionCommand);

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  LevelCommand := Format('level move-time=%.3f', [FEngineMoveTimeSpin.Value],
    FormatSettings);
  AppendEngineLog('> ' + LevelCommand + LineEnding);
  SendEngineCommand(LevelCommand);
  AppendEngineLog('> go ponder' + LineEnding);
  FLastEngineInfoAnnotation := '';
  FPonderBestSourceSquare := 0;
  InvalidateBoard;
  SendEngineCommand('go ponder');
  FEngineSearching := True;
  FEngineSearchMode := AMode;
  SetEngineState(esPondering);
end;

procedure TMainWindow.SendGoMctsToEngine;
var
  FormatSettings: TFormatSettings;
  LevelCommand: String;
  PositionCommand: String;
begin
  if not EngineIsRunning then
    Exit;
  if not FEngineReady then
    Exit;
  if Length(FMoves) = 0 then
  begin
    AppendEngineLog('[not starting search: terminal position]' + LineEnding);
    FEngineSearching := False;
    FEngineSearchMode := esmIdle;
    SetEngineState(esIdle);
    Exit;
  end;

  PositionCommand := HubPositionCommand;
  AppendEngineLog('> ' + PositionCommand + LineEnding);
  SendEngineCommand(PositionCommand);

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  LevelCommand := Format('level move-time=%.3f', [FEngineMoveTimeSpin.Value],
    FormatSettings);
  AppendEngineLog('> ' + LevelCommand + LineEnding);
  SendEngineCommand(LevelCommand);
  AppendEngineLog('> go mcts' + LineEnding);
  FLastEngineInfoAnnotation := '';
  FPonderBestSourceSquare := 0;
  InvalidateBoard;
  SendEngineCommand('go mcts');
  FEngineSearching := True;
  FEngineSearchMode := esmMcts;
  SetEngineState(esMcts);
end;

procedure TMainWindow.SendGoThinkToEngine(AMode: TEngineSearchMode);
var
  FormatSettings: TFormatSettings;
  LevelCommand: String;
  PositionCommand: String;
begin
  if not EngineIsRunning then
    Exit;
  if not FEngineReady then
    Exit;
  if Length(FMoves) = 0 then
  begin
    if FPlayGameActive then
      LeavePlayGameMode;
    FAutoPlayActive := False;
    FEngineSearching := False;
    FEngineSearchMode := esmIdle;
    SetEngineState(esIdle);
    AppendEngineLog('[not starting search: terminal position]' + LineEnding);
    Exit;
  end;

  PositionCommand := HubPositionCommand;
  AppendEngineLog('> ' + PositionCommand + LineEnding);
  SendEngineCommand(PositionCommand);

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  if AMode = esmPlayGameThink then
    LevelCommand := Format('level time=%.3f', [CurrentEngineRemainingTimeSeconds],
      FormatSettings)
  else
    LevelCommand := Format('level move-time=%.3f', [FEngineMoveTimeSpin.Value],
      FormatSettings);
  AppendEngineLog('> ' + LevelCommand + LineEnding);
  SendEngineCommand(LevelCommand);
  AppendEngineLog('> go think' + LineEnding);
  FLastEngineInfoAnnotation := '';
  if FPonderBestSourceSquare <> 0 then
  begin
    FPonderBestSourceSquare := 0;
    InvalidateBoard;
  end;
  SendEngineCommand('go think');
  FEngineSearching := True;
  FEngineSearchMode := AMode;
  SetEngineState(esThinking);
end;

procedure TMainWindow.RestartEnginePonder;
begin
  if not EngineIsRunning or (not FEngineReady) then
    Exit;
  if FAutoPlayActive or FPlayGameActive then
    Exit;

  if FEngineState <> esIdle then
  begin
    FPendingAutoPlayStart := False;
    FPendingMctsStart := False;
    FPendingPonderMode := esmPonder;
    FPendingPonderStart := True;
    FPendingPlayGameStart := False;
    FPendingThinkStart := False;
    AppendEngineLog('[stopping previous search before ponder]' + LineEnding);
    SendStopToEngine;
  end
  else
    SendGoPonderToEngine;
end;

procedure TMainWindow.SendStopToEngine;
var
  PreviousState: TEngineState;
begin
  if not EngineIsRunning then
    Exit;

  PreviousState := FEngineState;
  AppendEngineLog('> stop' + LineEnding);
  AppendEngineLog('[stop requested while engine state: ' +
    EngineStateText(PreviousState) + ']' + LineEnding);
  FIgnoreNextDoneMove := FEngineState <> esIdle;
  FEngineStopRequested := False;
  FEngineSearching := False;
  FEngineSearchMode := esmIdle;
  if PreviousState <> esIdle then
  begin
    FEngineState := esIdle;
    AppendEngineLog('[engine state: ' + EngineStateText(PreviousState) +
      ' -> idle]' + LineEnding);
  end
  else
    SetEngineState(esIdle);
  SendEngineCommand('stop');
end;

function PdnEscape(const AText: String): String;
begin
  Result := StringReplace(AText, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
end;

procedure TMainWindow.SavePdnMenuItemClick(Sender: TObject);
var
  Dialog: TPDNSaveDialog;
begin
  if FSavePdnOptionsDialog <> nil then
  begin
    FSavePdnOptionsDialog.BringToFront;
    Exit;
  end;

  Dialog := TPDNSaveDialog.Create(Self);
  FSavePdnOptionsDialog := Dialog;
  Dialog.SetDefaults(FGameWhiteName, FGameBlackName, GuessResultFromFinalPosition);
  Dialog.ModalResult := mrCancel;
  Dialog.OnHide := @SavePdnOptionsDialogHide;
  Dialog.Show;
end;

procedure TMainWindow.SavePdnOptionsDialogHide(Sender: TObject);
var
  Accepted: Boolean;
  BlackName: String;
  Dialog: TPDNSaveDialog;
  ResultText: String;
  WhiteName: String;
begin
  if Sender is TPDNSaveDialog then
    Dialog := TPDNSaveDialog(Sender)
  else
    Dialog := FSavePdnOptionsDialog;

  Accepted := (Dialog <> nil) and (Dialog.ModalResult = mrOK);
  if Accepted then
  begin
    WhiteName := Dialog.WhiteName;
    BlackName := Dialog.BlackName;
    ResultText := Dialog.ResultText;
  end
  else
  begin
    WhiteName := '';
    BlackName := '';
    ResultText := '';
  end;

  FSavePdnOptionsDialog := nil;
  if Dialog <> nil then
    Dialog.Release;

  if not Accepted then
  begin
    FShutdownAfterPdnSave := False;
    Exit;
  end;

  FGameWhiteName := WhiteName;
  FGameBlackName := BlackName;
  FGameResult := ResultText;
  MarkGameDirty;
  UpdateHistoryList;
  if FSavePdnDialog.Execute then
    SavePdnFile(FSavePdnDialog.FileName, WhiteName, BlackName, ResultText);

  if FShutdownAfterPdnSave then
  begin
    FShutdownAfterPdnSave := False;
    if not FGameDirty then
      FinalizeShutdown;
  end;
end;

procedure TMainWindow.SaveEngineLogMenuItemClick(Sender: TObject);
begin
  if (FSaveEngineLogDialog = nil) or (FEngineLogMemo = nil) then
    Exit;

  if FSaveEngineLogDialog.Execute then
  begin
    FEngineLogMemo.Lines.SaveToFile(FSaveEngineLogDialog.FileName);
    AppendEngineLog('[saved engine log ' + FSaveEngineLogDialog.FileName + ']' +
      LineEnding);
  end;
end;

procedure TMainWindow.SavePdnFile(const AFileName, AWhiteName, ABlackName,
  AResult: String);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('[Event "?"]');
    Lines.Add('[Site "?"]');
    Lines.Add('[Date "????.??.??"]');
    Lines.Add('[Round "?"]');
    Lines.Add('[White "' + PdnEscape(AWhiteName) + '"]');
    Lines.Add('[Black "' + PdnEscape(ABlackName) + '"]');
    Lines.Add('[Result "' + AResult + '"]');
    Lines.Add('[FEN "' + BoardToFen(FHistoryBaseBoard, FHistoryBaseSide) + '"]');
    Lines.Add('');
    Lines.Add(BuildPdnMoveText(AResult, False));
    Lines.SaveToFile(AFileName);
    FGameDirty := False;
    AppendEngineLog('[saved PDN ' + AFileName + ']' + LineEnding);
  finally
    Lines.Free;
  end;
end;

procedure TMainWindow.SetupPositionMenuItemClick(Sender: TObject);
var
  Dialog: TSetupPositionDialog;
begin
  if FSetupPositionDialog <> nil then
  begin
    FSetupPositionDialog.BringToFront;
    Exit;
  end;

  Dialog := TSetupPositionDialog.Create(Self);
  FSetupPositionDialog := Dialog;
  Dialog.SetPosition(FBoard, FSideToMove);
  Dialog.ModalResult := mrCancel;
  Dialog.OnHide := @SetupPositionDialogHide;
  Dialog.Show;
end;

procedure TMainWindow.SetupPositionDialogHide(Sender: TObject);
var
  Board: TBoard;
  Dialog: TSetupPositionDialog;
  Accepted: Boolean;
  SideToMove: TSide;
begin
  if Sender is TSetupPositionDialog then
    Dialog := TSetupPositionDialog(Sender)
  else
    Dialog := FSetupPositionDialog;

  Accepted := (Dialog <> nil) and (Dialog.ModalResult = mrOK);
  if Accepted then
  begin
    Board := Dialog.Board;
    SideToMove := Dialog.SideToMove;
  end;

  FSetupPositionDialog := nil;
  if Dialog <> nil then
    Dialog.Release;

  if not Accepted then
    Exit;

  FBoard := Board;
  FSideToMove := SideToMove;
  FGameWhiteName := 'White';
  FGameBlackName := 'Black';
  FGameResult := '*';
  LeavePlayGameMode;
  ResetHistoryFromCurrentPosition;
  MarkGameDirty;
  UpdateMoveList;
  UpdateHistoryList;
  InvalidateBoard;
  RestartEnginePonder;
end;

procedure TMainWindow.LoadFenFile(const AFileName: String);
var
  FenText: TStringList;
  I: Integer;
  Line: String;
begin
  FenText := TStringList.Create;
  try
    FenText.LoadFromFile(AFileName);
    Line := '';
    for I := 0 to FenText.Count - 1 do
    begin
      Line := Trim(FenText[I]);
      if (Line <> '') and (Line <> '*') then
        Break;
    end;

    if StartsText('[FEN ', Line) then
    begin
      Line := ExtractDelimited(2, Line, ['"']);
      if Line = '' then
        raise Exception.Create('Could not find a FEN string in the selected file.');
    end;

    ParseFen(Line);
    FGameWhiteName := 'White';
    FGameBlackName := 'Black';
    FGameResult := '*';
    LeavePlayGameMode;
    ResetHistoryFromCurrentPosition;
    FGameDirty := True;
    UpdateMoveList;
    UpdateHistoryList;
    Caption := 'International Draughts - ' + ExtractFileName(AFileName);
    InvalidateBoard;
    RestartEnginePonder;
  finally
    FenText.Free;
  end;
end;

function ExtractPdnTagValue(const ALines: TStrings; const ATagName: String): String;
var
  I: Integer;
  Line: String;
  Prefix: String;
begin
  Result := '';
  Prefix := '[' + ATagName + ' "';
  for I := 0 to ALines.Count - 1 do
  begin
    Line := Trim(ALines[I]);
    if StartsText(Prefix, Line) then
    begin
      Result := Copy(Line, Length(Prefix) + 1, MaxInt);
      if EndsText('"]', Result) then
        SetLength(Result, Length(Result) - 2);
      Result := StringReplace(Result, '\"', '"', [rfReplaceAll]);
      Result := StringReplace(Result, '\\', '\', [rfReplaceAll]);
      Exit;
    end;
  end;
end;

function StripPdnMoveText(const ALines: TStrings): String;
var
  Ch: Char;
  I: Integer;
  InComment: Boolean;
  InVariation: Integer;
  J: Integer;
  Line: String;
begin
  Result := '';
  InComment := False;
  InVariation := 0;

  for I := 0 to ALines.Count - 1 do
  begin
    Line := Trim(ALines[I]);
    if (Line = '') or StartsText('[', Line) then
      Continue;

    for J := 1 to Length(Line) do
    begin
      Ch := Line[J];
      if InComment then
      begin
        if Ch = '}' then
          InComment := False;
        Continue;
      end;
      if InVariation > 0 then
      begin
        if Ch = '(' then
          Inc(InVariation)
        else if Ch = ')' then
          Dec(InVariation);
        Continue;
      end;

      case Ch of
        '{': InComment := True;
        '(': InVariation := 1;
        ';': Break;
      else
        Result += Ch;
      end;
    end;
    Result += ' ';
  end;
end;

function PdnTokenMoveText(const AToken: String): String;
var
  DotPos: Integer;
  I: Integer;
begin
  Result := Trim(AToken);
  while (Result <> '') and (Result[1] in ['!', '?']) do
    Delete(Result, 1, 1);
  while (Result <> '') and (Result[Length(Result)] in ['!', '?', ',', ';']) do
    SetLength(Result, Length(Result) - 1);

  DotPos := 0;
  for I := Length(Result) downto 1 do
    if Result[I] = '.' then
    begin
      DotPos := I;
      Break;
    end;
  if DotPos > 0 then
    Delete(Result, 1, DotPos);
end;

function IsPdnResultToken(const AToken: String): Boolean;
begin
  Result := (AToken = '2-0') or (AToken = '1-1') or (AToken = '0-2') or
    (AToken = '*') or (AToken = '1-0') or (AToken = '0-1') or
    (AToken = '1/2-1/2');
end;

procedure TMainWindow.LoadPdnFile(const AFileName: String);
var
  FoundMove: Boolean;
  I: Integer;
  J: Integer;
  Lines: TStringList;
  MatchedMove: TMove;
  MoveText: String;
  StartFen: String;
  Token: String;
  Tokens: TStringArray;
begin
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    StartFen := ExtractPdnTagValue(Lines, 'FEN');
    if StartFen = '' then
      StartFen := 'W:W31-50:B1-20';
    FGameWhiteName := ExtractPdnTagValue(Lines, 'White');
    if FGameWhiteName = '' then
      FGameWhiteName := 'White';
    FGameBlackName := ExtractPdnTagValue(Lines, 'Black');
    if FGameBlackName = '' then
      FGameBlackName := 'Black';
    FGameResult := ExtractPdnTagValue(Lines, 'Result');
    if FGameResult = '' then
      FGameResult := '*';

    ParseFen(StartFen);
    LeavePlayGameMode;
    ResetHistoryFromCurrentPosition;
    UpdateMoveList;
    MoveText := StripPdnMoveText(Lines);
    Tokens := MoveText.Split([' ', #9, #10, #13], TStringSplitOptions.ExcludeEmpty);

    for I := 0 to High(Tokens) do
    begin
      Token := PdnTokenMoveText(Tokens[I]);
      if (Token = '') or IsPdnResultToken(Token) then
        Continue;

      UpdateMoveList;
      FoundMove := False;
      for J := 0 to High(FMoves) do
        if EngineMoveMatchesLegalMove(Token, FMoves[J]) then
        begin
          CopyMove(FMoves[J], MatchedMove);
          ApplyMove(MatchedMove);
          RecordPlayedMove(MatchedMove);
          FoundMove := True;
          Break;
        end;

      if not FoundMove then
        raise Exception.CreateFmt('Could not replay PDN move "%s".', [Token]);
    end;

    UpdateMoveList;
    UpdateHistoryList;
    Caption := 'International Draughts - ' + ExtractFileName(AFileName);
    FGameDirty := False;
    InvalidateBoard;
    RestartEnginePonder;
  finally
    Lines.Free;
  end;
end;

procedure TMainWindow.ParseFen(const AFen: String);
var
  CurrentSide: Char;
  Fen: String;
  FirstPieceSection: Integer;
  IsKing: Boolean;
  Piece: TPiece;
  PositionText: String;
  RangeEnd: Integer;
  RangeStart: Integer;
  Section: String;
  Sections: TStringArray;
  Token: String;
  Tokens: TStringArray;
  I: Integer;
  J: Integer;
  P: Integer;
begin
  Fen := Trim(StringReplace(AFen, LineEnding, '', [rfReplaceAll]));
  if Fen = '' then
    raise Exception.Create('The selected FEN file is empty.');

  ClearBoard;
  Sections := Fen.Split(':');
  FirstPieceSection := 0;

  if (Length(Sections) > 0) and (Length(Trim(Sections[0])) = 1) and
    (UpCase(Trim(Sections[0])[1]) in ['W', 'B']) then
  begin
    if UpCase(Trim(Sections[0])[1]) = 'W' then
      FSideToMove := sideWhite
    else
      FSideToMove := sideBlack;
    FirstPieceSection := 1;
  end;

  for I := FirstPieceSection to High(Sections) do
  begin
    Section := Trim(Sections[I]);
    if Section = '' then
      Continue;

    CurrentSide := UpCase(Section[1]);
    if not (CurrentSide in ['W', 'B']) then
      Continue;

    Delete(Section, 1, 1);
    Section := StringReplace(Section, ';', ',', [rfReplaceAll]);
    Tokens := Section.Split(',');

    for J := 0 to High(Tokens) do
    begin
      Token := Trim(Tokens[J]);
      if Token = '' then
        Continue;

      IsKing := UpCase(Token[1]) = 'K';
      if IsKing then
        Delete(Token, 1, 1);

      PositionText := Token;
      if Pos('-', PositionText) > 0 then
      begin
        RangeStart := StrToIntDef(Copy(PositionText, 1, Pos('-', PositionText) - 1), 0);
        RangeEnd := StrToIntDef(Copy(PositionText, Pos('-', PositionText) + 1, MaxInt), 0);
      end
      else
      begin
        RangeStart := StrToIntDef(PositionText, 0);
        RangeEnd := RangeStart;
      end;

      if (RangeStart < 1) or (RangeEnd > 50) or (RangeEnd < RangeStart) then
        raise Exception.CreateFmt('Invalid FEN position: %s', [Token]);

      for P := RangeStart to RangeEnd do
      begin
        if CurrentSide = 'W' then
          if IsKing then
            Piece := pcWhiteKing
          else
            Piece := pcWhiteMan
        else if IsKing then
          Piece := pcBlackKing
        else
          Piece := pcBlackMan;

        PlacePiece(P, Piece);
      end;
    end;
  end;
end;

procedure TMainWindow.PlacePiece(APosition: Integer; APiece: TPiece);
begin
  if (APosition < Low(FBoard)) or (APosition > High(FBoard)) then
    raise Exception.CreateFmt('Invalid board position: %d', [APosition]);

  FBoard[APosition] := APiece;
end;

procedure TMainWindow.UpdateHistoryList;
begin
  if FHistoryMemo = nil then
    Exit;

  FHistoryWhiteEdit.Text := FGameWhiteName;
  FHistoryBlackEdit.Text := FGameBlackName;
  FHistoryResultEdit.Text := FGameResult;
  FHistoryFenMemo.Text := BoardToFen(FHistoryBaseBoard, FHistoryBaseSide);
  FHistoryMemo.Text := BuildPdnMoveText(FGameResult, True);

  SelectHistoryPly(FCurrentPly);
end;

procedure TMainWindow.UpdateMoveList;
var
  I: Integer;
  SideName: String;
begin
  ClearBoardSelection;
  GenerateLegalMoves(FBoard, FSideToMove, FMoves);
  FOnlyMoveSourceSquare := 0;
  if (Length(FMoves) = 1) and (Length(FMoves[0].Squares) > 0) then
    FOnlyMoveSourceSquare := FMoves[0].Squares[0];

  if FSideToMove = sideWhite then
    SideName := 'White'
  else
    SideName := 'Black';

  FMovesMemo.Lines.BeginUpdate;
  try
    FSideToMoveLabel.Caption := SideName + ' to move';
    FMovesMemo.Clear;
    for I := 0 to High(FMoves) do
      FMovesMemo.Lines.Add(Format('%3d. %s', [I + 1, MoveToString(FMoves[I])]));

    if Length(FMoves) = 0 then
      FMovesMemo.Lines.Add('No legal moves');
  finally
    FMovesMemo.Lines.EndUpdate;
  end;
end;

end.
