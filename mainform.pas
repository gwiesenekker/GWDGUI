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
    FEngineIndex: Integer;
    FOwner: TMainWindow;
    FReadHandle: THandle;
    procedure DeliverChunk;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TMainWindow; AReadHandle: THandle;
      AEngineIndex: Integer = 1);
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
  TEngineState = (esIdle, esPondering, esMcts, esThinking,
    esWaitingForOtherEngine);
  TEngineSearchMode = (esmIdle, esmPonder, esmMcts, esmAutoPlay,
    esmPlayGameThink, esmPlayGamePonder);
  TEngineSlot = class
  public
    Index: Integer;
    LogMemo: TMemo;
    DisplayName: String;
    FileName: String;
    Params: TEngineParamArray;
    ParamsFileName: String;
    {$IFDEF MSWINDOWS}
    InputWriteHandle: THandle;
    OutputReadHandle: THandle;
    ProcessInfo: TProcessInformation;
    ReaderThread: TEngineReaderThread;
    Running: Boolean;
    {$ELSE}
    Process: TProcess;
    {$ENDIF}
    Ready: Boolean;
    SearchMode: TEngineSearchMode;
    State: TEngineState;
    StateLabel: TLabel;
    IgnoreNextDoneMove: Boolean;
    PendingThinkStart: Boolean;
    TextBuffer: String;
    WaitingForInit: Boolean;
    FirstReadSeen: Boolean;
    LogPopupMenu: TPopupMenu;
    CloseMenuItem: TMenuItem;
    OpenMenuItem: TMenuItem;
    ParamsMenuItem: TMenuItem;
    PonderMenuItem: TMenuItem;
    SaveLogMenuItem: TMenuItem;
    ShowTimestampsMenuItem: TMenuItem;
    constructor Create(AIndex: Integer);
  end;
  TEngineSlotArray = array[1..4] of TEngineSlot;

  TMainWindow = class(TForm)
  private
    FBoard: TBoard;
    FBoardRect: TRect;
    FAutoPlayActive: Boolean;
    FAutoPlayButton: TButton;
    FAutoPlayPlyCount: Integer;
    FEngineMoveTimeSpin: TFloatSpinEdit;
    FEngineOpenDialog: TOpenDialog;
    FEngines: TEngineSlotArray;
    FEnginePanel: TPanel;
    FEnginePollTimer: TTimer;
    FEngineSearching: Boolean;
    FEnginePonderAutoDisabled: Boolean;
    FEnginePonderEnabled: Boolean;
    FEngineLogShowTimestamps: Boolean;
    FEngineStartAfterReady: Boolean;
    FEngineStopRequested: Boolean;
    FEditMenu: TMenuItem;
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
    FBoardMoveSplitter: TSplitter;
    FBoardTopClockLabel: TLabel;
    FBoardBottomClockLabel: TLabel;
    FBoardSideToMoveLabel: TLabel;
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
    FOpenFenMenuItem: TMenuItem;
    FOpenPdnDialog: TOpenDialog;
    FOpenPdnMenuItem: TMenuItem;
    FPasteFenMenuItem: TMenuItem;
    FPieceDrawer: TIntfFreeTypeDrawer;
    FPieceFont: TFreeTypeFont;
    FPieceImage: TLazIntfImage;
    FPendingAutoPlayStart: Boolean;
    FPendingPonderMode: TEngineSearchMode;
    FPendingPonderStart: Boolean;
    FPendingMctsStart: Boolean;
    FPendingPlayGameFromCurrent: Boolean;
    FPendingPlayGameMinutes: Double;
    FPendingPlayGameBlackIsEngine: Boolean;
    FPendingPlayGameBlackName: String;
    FPendingPlayGameStart: Boolean;
    FPendingPlayGameWhiteIsEngine: Boolean;
    FPendingPlayGameWhiteName: String;
    FPendingThinkMode: TEngineSearchMode;
    FPendingThinkStart: Boolean;
    FPlayGameActive: Boolean;
    FPlayGameBlackIsEngine: Boolean;
    FPlayGameBlackName: String;
    FPlayGameBlackPlayerCombo: TComboBox;
    FPlayGameButton: TButton;
    FPlayGameCurrentPositionRadio: TRadioButton;
    FPlayGameDialog: TForm;
    FPlayGameMinutesSpin: TFloatSpinEdit;
    FPlayGameWhiteIsEngine: Boolean;
    FPlayGameWhiteName: String;
    FPlayGameWhitePlayerCombo: TComboBox;
    FRootPanel: TPanel;
    FQuitMenuItem: TMenuItem;
    FSaveEngineLogDialog: TSaveDialog;
    FSavePdnDialog: TSaveDialog;
    FSavePdnMenuItem: TMenuItem;
    FSavePdnOptionsDialog: TPDNSaveDialog;
    FSelectedSquare: Integer;
    FSetupPositionDialog: TSetupPositionDialog;
    FShutdownAfterPdnSave: Boolean;
    FShutdownConfirmed: Boolean;
    FSuppressBoardUpdates: Boolean;
    FUnsavedGamePromptDialog: TForm;
    FAmbiguousTargetSquares: array[1..50] of Boolean;
    FTargetSquares: array[1..50] of Boolean;
    FSetupPositionMenuItem: TMenuItem;
    FSideToMove: TSide;
    FStopButton: TButton;
    procedure ApplyMove(const AMove: TMove);
    procedure AppendEngine2Log(const AText: String);
    procedure AppendEngine2RawLog(const AText: String);
    procedure AppendEngineLog(const AText: String);
    procedure AppendEngineRawLog(const AText: String);
    procedure BeginAutoPlay;
    procedure BeginPlayGame(AWhiteIsEngine, ABlackIsEngine: Boolean;
      const AWhiteName, ABlackName: String; AGameMinutes: Double; AStartFromCurrent: Boolean;
      AStartSearch: Boolean = True);
    procedure BoardPaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure BoardPaintBoxPaint(Sender: TObject);
    procedure ClockTimerTimer(Sender: TObject);
    procedure ClearBoardSelection;
    procedure ClearBoard;
    procedure CopyFenMenuItemClick(Sender: TObject);
    procedure CloseEngine;
    procedure CloseEngineMenuItemClick(Sender: TObject);
    procedure CloseSecondEngine;
    procedure CloseSecondEngineMenuItemClick(Sender: TObject);
    procedure CenterDialogOnMainWindow(ADialog: TCustomForm);
    procedure DrawBoard(ACanvas: TCanvas);
    procedure DrawBoardClockLabels(const ABoardRect: TRect);
    procedure DrawBoardSideToMoveLabel(const ABoardRect: TRect);
    procedure DrawBoardSideToMoveMarker(ACanvas: TCanvas; const ABoardRect: TRect;
      ACellSize: Integer);
    procedure DrawPiece(ACanvas: TCanvas; const ASquare: TRect;
      APiece: TPiece; ACellSize: Integer; ASquareColor: TColor);
    function BoardSquareAtCell(ARow, ACol: Integer): Integer;
    procedure EngineProcessReadData(Sender: TObject);
    procedure EngineProcessReadSecondEngineData;
    procedure EnginePollTimerTimer(Sender: TObject);
    procedure EngineProcessTerminate(Sender: TObject);
    function EngineMoveIndex(const AEngineMove: String): Integer;
    function EngineMoveMatchesLegalMove(const AEngineMove: String;
      const ALegalMove: TMove): Boolean;
    function EngineIsRunning: Boolean;
    function EngineLogPrefix(const AName: String): String;
    function EngineOutputLogText(const AText: String; AEngineIndex: Integer): String;
    function EngineParamsFileNameForDisplayName(const ADisplayName: String;
      const AEngineFileName: String = ''): String;
    function EngineStateCaption(AState: TEngineState): String;
    function SecondEngineIsRunning: Boolean;
    procedure AutoPlayButtonClick(Sender: TObject);
    procedure GoButtonClick(Sender: TObject);
    function PlayEngineMove(const AEngineMove: String;
      AEngineIndex: Integer = 1): Boolean;
    function CurrentPositionRepetitionCount: Integer;
    function HubPositionString: String;
    function HubPositionStringFor(const ABoard: TBoard; ASide: TSide): String;
    function HubPositionCommand: String;
    function PositionKeyFor(const ABoard: TBoard; ASide: TSide): String;
    function CurrentEngineRemainingTimeSeconds: Double;
    function HasPlayGameEnginePlayer: Boolean;
    function HasPlayGameHumanPlayer: Boolean;
    function IsPlayGameHumanTurn: Boolean;
    function IsPlayGameEngineTurn: Boolean;
    function IsPlayGameSecondEngineTurn: Boolean;
    function EngineLogName(AEngineIndex: Integer): String;
    function EngineStateLogText(AState: TEngineState): String;
    function PlayerNameToMove: String;
    procedure InvalidateBoard;
    function BoardToFen(const ABoard: TBoard; ASide: TSide): String;
    function BuildPdnMoveText(const AResult: String; AStoreRanges: Boolean): String;
    function ClockAnnotation(APly: Integer): String;
    function EngineInfoAnnotation(const ALine: String): String;
    function GuessResultFromFinalPosition: String;
    procedure HistoryMemoClick(Sender: TObject);
    procedure HistoryMemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure HandleEngineDoneMove(const AMoveText: String);
    procedure FormResize(Sender: TObject);
    procedure LoadFenFile(const AFileName: String);
    procedure LoadPdnFile(const AFileName: String);
    procedure LeavePlayGameMode;
    procedure MoveListMoveClick(Sender: TObject);
    procedure MctsButtonClick(Sender: TObject);
    procedure MovesMemoDblClick(Sender: TObject);
    procedure OpenEngineMenuItemClick(Sender: TObject);
    procedure OpenSecondEngineMenuItemClick(Sender: TObject);
    procedure OpenFenMenuItemClick(Sender: TObject);
    procedure OpenPdnMenuItemClick(Sender: TObject);
    procedure PasteFenMenuItemClick(Sender: TObject);
    procedure ParseFen(const AFen: String);
    procedure PlacePiece(APosition: Integer; APiece: TPiece);
    procedure PlayGameButtonClick(Sender: TObject);
    procedure PlayGameDialogButtonClick(Sender: TObject);
    procedure PlayGameDialogHide(Sender: TObject);
    procedure RebuildPositionToPly(APly: Integer);
    procedure RecordPlayedMove(const AMove: TMove; const AAnnotation: String = '');
    function CheckDrawByRepetition: Boolean;
    procedure LogPlayedMoveToEngineWindows(const AMove: TMove;
      AActorEngineIndex: Integer);
    procedure RestoreClockSnapshot(APly: Integer);
    procedure ResetClocks;
    procedure ResetHistoryFromCurrentPosition;
    procedure NavigateHistoryToPly(APly: Integer);
    procedure MainWindowCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure MarkGameDirty;
    procedure RefreshButtonToolbar(Data: PtrInt);
    procedure QuitMenuItemClick(Sender: TObject);
    procedure SelectHistoryPly(APly: Integer);
    procedure SelectBoardSquare(ASquare: Integer);
    function SquareAtPoint(X, Y: Integer): Integer;
    procedure ProcessEngineOutput(const AText: String);
    procedure ProcessSecondEngineOutput(const AText: String);
    procedure EditEngineParamsMenuItemClick(Sender: TObject);
    procedure EditSecondEngineParamsMenuItemClick(Sender: TObject);
    procedure EngineParamsDialogHide(Sender: TObject);
    procedure Engine2ParamsDialogHide(Sender: TObject);
    procedure HandleEngineIdLine(const ALine: String);
    procedure HandleEngine2IdLine(const ALine: String);
    procedure SendEngineParams;
    procedure SendSecondEngineParams;
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
    procedure StartPlayGameFromOptions(AWhiteIsEngine, ABlackIsEngine: Boolean;
      const AWhiteName, ABlackName: String; AGameMinutes: Double;
      AStartFromCurrent: Boolean);
    procedure StartEngine(const AFileName: String);
    procedure StartSecondEngine(const AFileName: String);
    procedure SendEngineCommand(const ACommand: String);
    procedure SendSecondEngineCommand(const ACommand: String);
    procedure SetEngineState(AState: TEngineState);
    procedure SetSecondEngineState(AState: TEngineState);
    procedure UpdateEngineStateLabels;
    procedure SendPlayGameHumanTurnPonder;
    procedure ContinuePlayGameSearch;
    procedure SendGoPonderToEngine(AMode: TEngineSearchMode = esmPonder);
    procedure SendGoPonderToSecondEngine(AMode: TEngineSearchMode = esmPonder);
    procedure SendGoMctsToEngine;
    procedure SendGoThinkToEngine(AMode: TEngineSearchMode = esmAutoPlay);
    procedure SendGoThinkToSecondEngine;
    procedure RestartEnginePonder;
    procedure SendStopToEngine;
    procedure SendStopToSecondEngine;
    procedure SendPositionMenuItemClick(Sender: TObject);
    procedure SendPositionToEngine;
    procedure SavePdnMenuItemClick(Sender: TObject);
    procedure SavePdnOptionsDialogHide(Sender: TObject);
    procedure SaveEngineLogMenuItemClick(Sender: TObject);
    procedure SaveSecondEngineLogMenuItemClick(Sender: TObject);
    procedure PonderMenuItemClick(Sender: TObject);
    procedure ShowTimestampsMenuItemClick(Sender: TObject);
    procedure SavePdnFile(const AFileName, AWhiteName, ABlackName, AResult: String);
    procedure StopButtonClick(Sender: TObject);
    procedure StopGameClocks;
    procedure ExecuteMoveFromList(AMoveIndex: Integer; AContinueEngine: Boolean);
    procedure ExecuteLegalMoveIndex(AMoveIndex: Integer; AContinueEngine: Boolean);
    procedure UpdateClockLabels;
    procedure UpdateGameClock;
    procedure UpdateHistoryList;
    procedure UpdateMovePanelWidth;
    procedure UpdateMoveList;
    procedure UpdatePonderMenuItems;
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
  BoardMoveSplitterWidth = 6;
  EngineStateLabelWidth = 96;
  MovePanelBaseWidth = 420;
  LegalMovesPanelWidth = 180;
  LegalMovesGap = 10;
  BoardSideMarkerGap = 10;
  BoardSideMarkerWidth = 104;
  BoardMargin = 32;
  WoodSquareColor = TColor($00305E8B);
  PonderBestSourceColor = TColor($0000A5FF);

function EngineLogTimestamp: String; forward;

constructor TEngineSlot.Create(AIndex: Integer);
begin
  inherited Create;
  Index := AIndex;
  if AIndex = 1 then
    DisplayName := 'Engine'
  else
    DisplayName := 'Engine ' + IntToStr(AIndex);
  SearchMode := esmIdle;
  State := esIdle;
end;

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
constructor TEngineReaderThread.Create(AOwner: TMainWindow; AReadHandle: THandle;
  AEngineIndex: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FEngineIndex := AEngineIndex;
  FOwner := AOwner;
  FReadHandle := AReadHandle;
  Start;
end;

procedure TEngineReaderThread.DeliverChunk;
begin
  if (FOwner <> nil) and (FChunk <> '') then
  begin
    if FEngineIndex = 2 then
    begin
      if not FOwner.FEngines[2].FirstReadSeen then
      begin
        FOwner.FEngines[2].FirstReadSeen := True;
        FOwner.AppendEngine2Log('[' + FOwner.EngineLogName(2) +
          ' first read thread bytes=' + IntToStr(Length(FChunk)) + ']' +
          LineEnding);
      end;
      FOwner.AppendEngine2RawLog(FOwner.EngineOutputLogText(FChunk, 2));
      FOwner.ProcessSecondEngineOutput(FChunk);
    end
    else
    begin
      if not FOwner.FEngines[1].FirstReadSeen then
      begin
        FOwner.FEngines[1].FirstReadSeen := True;
        FOwner.AppendEngineLog('[' + FOwner.EngineLogName(1) +
          ' first read thread bytes=' + IntToStr(Length(FChunk)) + ']' +
          LineEnding);
      end;
      FOwner.AppendEngineRawLog(FOwner.EngineOutputLogText(FChunk, 1));
      FOwner.ProcessEngineOutput(FChunk);
    end;
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
var
  I: Integer;
begin
  inherited Create(AOwner);

  for I := Low(FEngines) to High(FEngines) do
    FEngines[I] := TEngineSlot.Create(I);

  Caption := 'International Draughts';
  Color := clBtnFace;
  Constraints.MinWidth := 700;
  Constraints.MinHeight := 440;
  Width := 1280;
  Height := 900;
  DoubleBuffered := True;
  KeyPreview := True;
  OnCloseQuery := @MainWindowCloseQuery;
  OnResize := @FormResize;
  FBoardFlipped := False;
  FShuttingDown := False;
  FSideToMove := sideWhite;
  FEngines[1].FileName := '';
  FEngines[2].FileName := '';
  FEngines[2].IgnoreNextDoneMove := False;
  FEnginePonderAutoDisabled := False;
  FEnginePonderEnabled := True;
  FEngineLogShowTimestamps := False;
  FGameWhiteName := 'Human';
  FGameBlackName := 'Human';
  FGameResult := '*';
  FGameDirty := False;
  FShutdownAfterPdnSave := False;
  FShutdownConfirmed := False;
  FSuppressBoardUpdates := False;
  ClearBoardSelection;

  ParseFen('W:W31-50:B1-20');
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
  FEngines[1].InputWriteHandle := 0;
  FEngines[1].OutputReadHandle := 0;
  FEngines[2].InputWriteHandle := 0;
  FEngines[2].OutputReadHandle := 0;
  FillChar(FEngines[1].ProcessInfo, SizeOf(FEngines[1].ProcessInfo), 0);
  FillChar(FEngines[2].ProcessInfo, SizeOf(FEngines[2].ProcessInfo), 0);
  FEngines[1].ReaderThread := nil;
  FEngines[2].ReaderThread := nil;
  FEngines[1].Running := False;
  FEngines[2].Running := False;
  FClockThread := TClockThread.Create(Self);
  {$ENDIF}
  SetupMenu;
  SetupBoardArea;
  SetupEngineLog;
  SetupMoveList;
  UpdateMovePanelWidth;
  SetupPieceFont;
  ResetClocks;
  UpdateMoveList;
  UpdateHistoryList;
end;

destructor TMainWindow.Destroy;
var
  I: Integer;
begin
  {$IFDEF MSWINDOWS}
  if FClockThread <> nil then
  begin
    FClockThread.Terminate;
    FClockThread.WaitFor;
    FreeAndNil(FClockThread);
  end;
  {$ENDIF}
  CloseSecondEngine;
  CloseEngine;
  FPieceFont.Free;
  FPieceDrawer.Free;
  FPieceImage.Free;
  for I := Low(FEngines) to High(FEngines) do
    FreeAndNil(FEngines[I]);
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
begin
  FBoardMoveSplitter := TSplitter.Create(FRootPanel);
  FBoardMoveSplitter.Parent := FRootPanel;
  FBoardMoveSplitter.Align := alLeft;
  FBoardMoveSplitter.ResizeAnchor := akLeft;
  FBoardMoveSplitter.Width := BoardMoveSplitterWidth;

  FMovePanel := TPanel.Create(FRootPanel);
  FMovePanel.Parent := FRootPanel;
  FMovePanel.Align := alClient;
  FMovePanel.Width := MovePanelBaseWidth;
  FMovePanel.Constraints.MinWidth := 320;
  FMovePanel.BevelOuter := bvNone;
  FMovePanel.BorderSpacing.Right := LayoutMargin;

  FLegalMovesPanel := TPanel.Create(FBoardPanel);
  FLegalMovesPanel.Parent := FBoardPanel;
  FLegalMovesPanel.Align := alNone;
  FLegalMovesPanel.Width := LegalMovesPanelWidth;
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

procedure TMainWindow.FormResize(Sender: TObject);
begin
  UpdateMovePanelWidth;
end;

procedure TMainWindow.UpdateMovePanelWidth;
var
  BoardPixels: Integer;
  DesiredLeftWidth: Integer;
  MaxLeftWidth: Integer;
  NewLeftWidth: Integer;
  PaintHeight: Integer;
begin
  if (FRootPanel = nil) or (FBoardPanel = nil) then
    Exit;

  if FBoardPaintBox <> nil then
    PaintHeight := FBoardPaintBox.ClientHeight
  else
    PaintHeight := FRootPanel.ClientHeight;

  BoardPixels := Max(BoardSize, PaintHeight - (2 * BoardMargin));
  BoardPixels := (BoardPixels div BoardSize) * BoardSize;
  DesiredLeftWidth := (2 * LayoutMargin) + LegalMovesPanelWidth + LegalMovesGap +
    BoardPixels + BoardSideMarkerGap + BoardSideMarkerWidth;

  MaxLeftWidth := FRootPanel.ClientWidth - MovePanelBaseWidth -
    BoardMoveSplitterWidth - LayoutMargin;
  NewLeftWidth := Min(DesiredLeftWidth,
    Max(FBoardPanel.Constraints.MinWidth, MaxLeftWidth));

  if NewLeftWidth > 0 then
    FBoardPanel.Width := NewLeftWidth;
end;

procedure TMainWindow.SetupEngineLog;
var
  Engine1Panel: TPanel;
  Engine2Panel: TPanel;
  EngineLogSplitter: TSplitter;
  Splitter: TSplitter;
begin
  FEnginePanel := TPanel.Create(Self);
  FEnginePanel.Parent := Self;
  FEnginePanel.Align := alBottom;
  FEnginePanel.Height := 260;
  FEnginePanel.Constraints.MinHeight := 96;
  FEnginePanel.BevelOuter := bvNone;

  Splitter := TSplitter.Create(Self);
  Splitter.Parent := Self;
  Splitter.Align := alBottom;
  Splitter.ResizeAnchor := akBottom;
  Splitter.Height := 6;

  Engine1Panel := TPanel.Create(FEnginePanel);
  Engine1Panel.Parent := FEnginePanel;
  Engine1Panel.Align := alClient;
  Engine1Panel.BevelOuter := bvNone;

  FEngines[1].StateLabel := TLabel.Create(Engine1Panel);
  FEngines[1].StateLabel.Parent := Engine1Panel;
  FEngines[1].StateLabel.Align := alRight;
  FEngines[1].StateLabel.AutoSize := False;
  FEngines[1].StateLabel.Width := EngineStateLabelWidth;
  FEngines[1].StateLabel.BorderSpacing.Right := LayoutMargin;
  FEngines[1].StateLabel.BorderSpacing.Bottom := 6;
  FEngines[1].StateLabel.Alignment := taCenter;
  FEngines[1].StateLabel.Layout := tlCenter;
  FEngines[1].StateLabel.Font.Style := [fsBold];
  FEngines[1].StateLabel.Transparent := False;
  FEngines[1].StateLabel.Color := clBtnFace;

  FEngines[1].LogMemo := TMemo.Create(Engine1Panel);
  FEngines[1].LogMemo.Parent := Engine1Panel;
  FEngines[1].LogMemo.Align := alClient;
  FEngines[1].LogMemo.BorderSpacing.Left := LayoutMargin;
  FEngines[1].LogMemo.BorderSpacing.Right := 6;
  FEngines[1].LogMemo.BorderSpacing.Bottom := 6;
  FEngines[1].LogMemo.ReadOnly := True;
  FEngines[1].LogMemo.ScrollBars := ssBoth;
  FEngines[1].LogMemo.WordWrap := False;
  FEngines[1].LogMemo.TabStop := False;

  FEngines[1].LogPopupMenu := TPopupMenu.Create(Self);
  FEngines[1].OpenMenuItem := TMenuItem.Create(FEngines[1].LogPopupMenu);
  FEngines[1].OpenMenuItem.Caption := 'Open Engine...';
  FEngines[1].OpenMenuItem.OnClick := @OpenEngineMenuItemClick;
  FEngines[1].LogPopupMenu.Items.Add(FEngines[1].OpenMenuItem);

  FEngines[1].ParamsMenuItem := TMenuItem.Create(FEngines[1].LogPopupMenu);
  FEngines[1].ParamsMenuItem.Caption := 'Engine Parameters...';
  FEngines[1].ParamsMenuItem.OnClick := @EditEngineParamsMenuItemClick;
  FEngines[1].LogPopupMenu.Items.Add(FEngines[1].ParamsMenuItem);

  FEngines[1].CloseMenuItem := TMenuItem.Create(FEngines[1].LogPopupMenu);
  FEngines[1].CloseMenuItem.Caption := 'Close Engine';
  FEngines[1].CloseMenuItem.OnClick := @CloseEngineMenuItemClick;
  FEngines[1].LogPopupMenu.Items.Add(FEngines[1].CloseMenuItem);

  FEngines[1].LogPopupMenu.Items.AddSeparator;

  FEngines[1].PonderMenuItem := TMenuItem.Create(FEngines[1].LogPopupMenu);
  FEngines[1].PonderMenuItem.Caption := 'Ponder';
  FEngines[1].PonderMenuItem.AutoCheck := False;
  FEngines[1].PonderMenuItem.Checked := FEnginePonderEnabled;
  FEngines[1].PonderMenuItem.OnClick := @PonderMenuItemClick;
  FEngines[1].LogPopupMenu.Items.Add(FEngines[1].PonderMenuItem);

  FEngines[1].ShowTimestampsMenuItem := TMenuItem.Create(FEngines[1].LogPopupMenu);
  FEngines[1].ShowTimestampsMenuItem.Caption := 'Show timestamps';
  FEngines[1].ShowTimestampsMenuItem.AutoCheck := False;
  FEngines[1].ShowTimestampsMenuItem.Checked := FEngineLogShowTimestamps;
  FEngines[1].ShowTimestampsMenuItem.OnClick := @ShowTimestampsMenuItemClick;
  FEngines[1].LogPopupMenu.Items.Add(FEngines[1].ShowTimestampsMenuItem);

  FEngines[1].SaveLogMenuItem := TMenuItem.Create(FEngines[1].LogPopupMenu);
  FEngines[1].SaveLogMenuItem.Caption := 'Save as...';
  FEngines[1].SaveLogMenuItem.OnClick := @SaveEngineLogMenuItemClick;
  FEngines[1].LogPopupMenu.Items.Add(FEngines[1].SaveLogMenuItem);
  FEngines[1].LogMemo.PopupMenu := FEngines[1].LogPopupMenu;

  FEngines[1].LogMemo.Lines.Add('Engine output');

  EngineLogSplitter := TSplitter.Create(FEnginePanel);
  EngineLogSplitter.Parent := FEnginePanel;
  EngineLogSplitter.Align := alBottom;
  EngineLogSplitter.ResizeAnchor := akBottom;
  EngineLogSplitter.Height := 4;

  Engine2Panel := TPanel.Create(FEnginePanel);
  Engine2Panel.Parent := FEnginePanel;
  Engine2Panel.Align := alBottom;
  Engine2Panel.Height := (FEnginePanel.Height - EngineLogSplitter.Height) div 2;
  Engine2Panel.BevelOuter := bvNone;

  FEngines[2].StateLabel := TLabel.Create(Engine2Panel);
  FEngines[2].StateLabel.Parent := Engine2Panel;
  FEngines[2].StateLabel.Align := alRight;
  FEngines[2].StateLabel.AutoSize := False;
  FEngines[2].StateLabel.Width := EngineStateLabelWidth;
  FEngines[2].StateLabel.BorderSpacing.Right := LayoutMargin;
  FEngines[2].StateLabel.BorderSpacing.Bottom := 6;
  FEngines[2].StateLabel.Alignment := taCenter;
  FEngines[2].StateLabel.Layout := tlCenter;
  FEngines[2].StateLabel.Font.Style := [fsBold];
  FEngines[2].StateLabel.Transparent := False;
  FEngines[2].StateLabel.Color := clBtnFace;

  FEngines[2].LogMemo := TMemo.Create(Engine2Panel);
  FEngines[2].LogMemo.Parent := Engine2Panel;
  FEngines[2].LogMemo.Align := alClient;
  FEngines[2].LogMemo.BorderSpacing.Left := LayoutMargin;
  FEngines[2].LogMemo.BorderSpacing.Right := 6;
  FEngines[2].LogMemo.BorderSpacing.Bottom := 6;
  FEngines[2].LogMemo.ReadOnly := True;
  FEngines[2].LogMemo.ScrollBars := ssBoth;
  FEngines[2].LogMemo.WordWrap := False;
  FEngines[2].LogMemo.TabStop := False;

  FEngines[2].LogPopupMenu := TPopupMenu.Create(Self);
  FEngines[2].OpenMenuItem := TMenuItem.Create(FEngines[2].LogPopupMenu);
  FEngines[2].OpenMenuItem.Caption := 'Open Engine...';
  FEngines[2].OpenMenuItem.OnClick := @OpenSecondEngineMenuItemClick;
  FEngines[2].LogPopupMenu.Items.Add(FEngines[2].OpenMenuItem);

  FEngines[2].ParamsMenuItem := TMenuItem.Create(FEngines[2].LogPopupMenu);
  FEngines[2].ParamsMenuItem.Caption := 'Engine Parameters...';
  FEngines[2].ParamsMenuItem.OnClick := @EditSecondEngineParamsMenuItemClick;
  FEngines[2].LogPopupMenu.Items.Add(FEngines[2].ParamsMenuItem);

  FEngines[2].CloseMenuItem := TMenuItem.Create(FEngines[2].LogPopupMenu);
  FEngines[2].CloseMenuItem.Caption := 'Close Engine';
  FEngines[2].CloseMenuItem.OnClick := @CloseSecondEngineMenuItemClick;
  FEngines[2].LogPopupMenu.Items.Add(FEngines[2].CloseMenuItem);

  FEngines[2].LogPopupMenu.Items.AddSeparator;

  FEngines[2].PonderMenuItem := TMenuItem.Create(FEngines[2].LogPopupMenu);
  FEngines[2].PonderMenuItem.Caption := 'Ponder';
  FEngines[2].PonderMenuItem.AutoCheck := False;
  FEngines[2].PonderMenuItem.Checked := FEnginePonderEnabled;
  FEngines[2].PonderMenuItem.OnClick := @PonderMenuItemClick;
  FEngines[2].LogPopupMenu.Items.Add(FEngines[2].PonderMenuItem);

  FEngines[2].ShowTimestampsMenuItem := TMenuItem.Create(FEngines[2].LogPopupMenu);
  FEngines[2].ShowTimestampsMenuItem.Caption := 'Show timestamps';
  FEngines[2].ShowTimestampsMenuItem.AutoCheck := False;
  FEngines[2].ShowTimestampsMenuItem.Checked := FEngineLogShowTimestamps;
  FEngines[2].ShowTimestampsMenuItem.OnClick := @ShowTimestampsMenuItemClick;
  FEngines[2].LogPopupMenu.Items.Add(FEngines[2].ShowTimestampsMenuItem);

  FEngines[2].SaveLogMenuItem := TMenuItem.Create(FEngines[2].LogPopupMenu);
  FEngines[2].SaveLogMenuItem.Caption := 'Save as...';
  FEngines[2].SaveLogMenuItem.OnClick := @SaveSecondEngineLogMenuItemClick;
  FEngines[2].LogPopupMenu.Items.Add(FEngines[2].SaveLogMenuItem);
  FEngines[2].LogMemo.PopupMenu := FEngines[2].LogPopupMenu;

  FEngines[2].LogMemo.Lines.Add('Engine 2 output');
  UpdatePonderMenuItems;
  UpdateEngineStateLabels;
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
  FBoardPanel.Align := alLeft;
  FBoardPanel.Width := 740;
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
  FPlayGameButton.Enabled := True;

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

  FBoardSideToMoveLabel := TLabel.Create(FBoardPanel);
  FBoardSideToMoveLabel.Parent := FBoardPanel;
  FBoardSideToMoveLabel.AutoSize := False;
  FBoardSideToMoveLabel.Alignment := taCenter;
  FBoardSideToMoveLabel.Layout := tlCenter;
  FBoardSideToMoveLabel.Font.Style := [fsBold];
  FBoardSideToMoveLabel.Transparent := True;
  FBoardSideToMoveLabel.Color := Color;
  FBoardSideToMoveLabel.Font.Color := clBlack;
  FBoardSideToMoveLabel.Caption := 'White to move';
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

  FPasteFenMenuItem := TMenuItem.Create(FMainMenu);
  FPasteFenMenuItem.Caption := '&Paste Position from Clipboard';
  FPasteFenMenuItem.ShortCut := ShortCut(VK_V, [ssCtrl]);
  FPasteFenMenuItem.OnClick := @PasteFenMenuItemClick;
  FEditMenu.Add(FPasteFenMenuItem);

  FSetupPositionMenuItem := TMenuItem.Create(FMainMenu);
  FSetupPositionMenuItem.Caption := '&Setup Position...';
  FSetupPositionMenuItem.OnClick := @SetupPositionMenuItemClick;
  FEditMenu.Add(FSetupPositionMenuItem);

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
  Application.QueueAsyncCall(@RefreshButtonToolbar, 0);
end;

procedure TMainWindow.RefreshButtonToolbar(Data: PtrInt);
var
  I: Integer;
begin
  if FButtonPanel = nil then
    Exit;
  if WindowState = wsMinimized then
    Exit;

  if FButtonPanel.Parent <> nil then
  begin
    FButtonPanel.Parent.Invalidate;
    FButtonPanel.Parent.Update;
  end;
  FButtonPanel.Invalidate;
  for I := 0 to FButtonPanel.ControlCount - 1 do
    FButtonPanel.Controls[I].Invalidate;
  FButtonPanel.Update;
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
  SideGap: Integer;
  SideWidth: Integer;
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

  LegalGap := LegalMovesGap;
  LegalWidth := LegalMovesPanelWidth;
  if FLegalMovesPanel <> nil then
    LegalWidth := FLegalMovesPanel.Width;
  SideGap := BoardSideMarkerGap;
  SideWidth := BoardSideMarkerWidth;

  BoardPixels := Min((BoardArea.Right - BoardArea.Left) - (2 * LayoutMargin) -
    LegalWidth - LegalGap - SideGap - SideWidth,
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
    if FBoardSideToMoveLabel <> nil then
      FBoardSideToMoveLabel.Visible := False;
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
  DrawBoardSideToMoveLabel(FBoardRect);
  DrawBoardSideToMoveMarker(ACanvas, FBoardRect, CellSize);

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

procedure TMainWindow.DrawBoardSideToMoveLabel(const ABoardRect: TRect);
const
  SideGap = 10;
  SideHeight = 28;
  SideWidth = 104;
var
  LabelTop: Integer;
  OffsetX: Integer;
  OffsetY: Integer;
begin
  if FBoardSideToMoveLabel = nil then
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

  LabelTop := OffsetY + ABoardRect.Top +
    ((ABoardRect.Bottom - ABoardRect.Top - SideHeight) div 2);
  FBoardSideToMoveLabel.SetBounds(OffsetX + ABoardRect.Right + SideGap,
    LabelTop, SideWidth, SideHeight);
  FBoardSideToMoveLabel.Visible := True;
  FBoardSideToMoveLabel.BringToFront;
end;

procedure TMainWindow.DrawBoardSideToMoveMarker(ACanvas: TCanvas;
  const ABoardRect: TRect; ACellSize: Integer);
var
  MarkerAtBottom: Boolean;
  MarkerPiece: TPiece;
  MarkerRect: TRect;
  MarkerSize: Integer;
  MarkerX: Integer;
  MarkerY: Integer;
begin
  MarkerSize := ACellSize;
  MarkerX := ABoardRect.Right + BoardSideMarkerGap +
    ((BoardSideMarkerWidth - MarkerSize) div 2);

  MarkerAtBottom := ((FSideToMove = sideWhite) and (not FBoardFlipped)) or
    ((FSideToMove = sideBlack) and FBoardFlipped);
  if FSideToMove = sideBlack then
    MarkerPiece := pcBlackMan
  else
    MarkerPiece := pcWhiteMan;

  if MarkerAtBottom then
    MarkerY := ABoardRect.Bottom - MarkerSize
  else
    MarkerY := ABoardRect.Top;

  MarkerRect := Types.Rect(MarkerX, MarkerY, MarkerX + MarkerSize,
    MarkerY + MarkerSize);
  DrawPiece(ACanvas, MarkerRect, MarkerPiece, MarkerSize, Color);
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

  FPieceDrawer.FillPixels(TColorToFPColor(ColorToRGB(ASquareColor)));
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

  if not FSuppressBoardUpdates then
  begin
    UpdateMoveList;
    InvalidateBoard;
  end;
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
  Annotation: String;
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
  Annotation := AAnnotation;
  if AMove.Promotes then
  begin
    if Annotation <> '' then
      Annotation += ' ';
    Annotation += 'K';
  end;
  FHistoryMoveAnnotations[MoveIndex] := Annotation;
  FHistoryClockSnapshots[MoveIndex].HasClock := FPlayGameActive;
  if FHistoryClockSnapshots[MoveIndex].HasClock then
  begin
    FHistoryClockSnapshots[MoveIndex].WhiteSeconds := FWhiteClockSeconds;
    FHistoryClockSnapshots[MoveIndex].BlackSeconds := FBlackClockSeconds;
  end;
  FCurrentPly := Length(FHistoryMoves);
  MarkGameDirty;
  if not FSuppressBoardUpdates then
    UpdateHistoryList;
end;

procedure TMainWindow.LogPlayedMoveToEngineWindows(const AMove: TMove;
  AActorEngineIndex: Integer);
var
  ActorName: String;
  MoveText: String;
begin
  MoveText := MoveToString(AMove);
  case AActorEngineIndex of
    1: ActorName := FEngines[1].DisplayName;
    2: ActorName := FEngines[2].DisplayName;
  else
    ActorName := 'Human';
  end;

  if (AActorEngineIndex <> 1) and EngineIsRunning then
    AppendEngineLog('[' + ActorName + ' played ' + MoveText + ']' +
      LineEnding);
  if (AActorEngineIndex <> 2) and SecondEngineIsRunning then
    AppendEngine2Log('[' + ActorName + ' played ' + MoveText + ']' +
      LineEnding);
end;

function TMainWindow.PositionKeyFor(const ABoard: TBoard; ASide: TSide): String;
var
  Square: Integer;
begin
  if ASide = sideWhite then
    Result := 'W|'
  else
    Result := 'B|';

  for Square := Low(ABoard) to High(ABoard) do
    case ABoard[Square] of
      pcWhiteMan: Result += 'w';
      pcWhiteKing: Result += 'W';
      pcBlackMan: Result += 'b';
      pcBlackKing: Result += 'B';
    else
      Result += 'e';
    end;
end;

function TMainWindow.CurrentPositionRepetitionCount: Integer;
var
  Board: TBoard;
  I: Integer;
  Key: String;
  Side: TSide;
  TargetKey: String;

  procedure ApplyMoveTo(var ABoard: TBoard; var ASide: TSide; const AMove: TMove);
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
    Piece := ABoard[FromSquare];
    ABoard[FromSquare] := pcNone;
    for CaptureIndex := 0 to High(AMove.Captures) do
      ABoard[AMove.Captures[CaptureIndex]] := pcNone;
    if AMove.Promotes then
      case Piece of
        pcWhiteMan: Piece := pcWhiteKing;
        pcBlackMan: Piece := pcBlackKing;
      end;
    ABoard[ToSquare] := Piece;
    if ASide = sideWhite then
      ASide := sideBlack
    else
      ASide := sideWhite;
  end;

begin
  Result := 0;
  TargetKey := PositionKeyFor(FBoard, FSideToMove);
  Board := FHistoryBaseBoard;
  Side := FHistoryBaseSide;
  Key := PositionKeyFor(Board, Side);
  if Key = TargetKey then
    Inc(Result);

  for I := 0 to Min(FCurrentPly, Length(FHistoryMoves)) - 1 do
  begin
    ApplyMoveTo(Board, Side, FHistoryMoves[I]);
    Key := PositionKeyFor(Board, Side);
    if Key = TargetKey then
      Inc(Result);
  end;
end;

function TMainWindow.CheckDrawByRepetition: Boolean;
begin
  Result := False;
  if (not FPlayGameActive) and (not FAutoPlayActive) then
    Exit;
  if CurrentPositionRepetitionCount < 3 then
    Exit;

  Result := True;
  FGameResult := '1-1';
  FAutoPlayActive := False;
  MarkGameDirty;
  AppendEngineLog('[game drawn by repetition]' + LineEnding);
  if SecondEngineIsRunning then
    AppendEngine2Log('[game drawn by repetition]' + LineEnding);
  LeavePlayGameMode;
  UpdateHistoryList;
  SendStopToEngine;
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
  FSuppressBoardUpdates := True;
  try
    for I := 0 to APly - 1 do
    begin
      ApplyMove(FHistoryMoves[I]);
      Inc(FCurrentPly);
    end;
  finally
    FSuppressBoardUpdates := False;
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
  LogPlayedMoveToEngineWindows(PlayedMove, 0);
  if CheckDrawByRepetition then
    Exit;

  if FPlayGameActive then
  begin
    AppendEngineLog('[human move ' + MoveToString(PlayedMove) + ']' +
      LineEnding);
    ContinuePlayGameSearch;
  end
  else if AContinueEngine and EngineIsRunning and
    FEngines[1].Ready then
  begin
    AppendEngineLog('[played move ' + MoveToString(PlayedMove) +
      '; restarting ponder]' + LineEnding);
    RestartEnginePonder;
  end;
end;

function PrefixLogLines(const AText, APrefix: String): String;
var
  LineBody: String;
  LineEnd: String;
  LineStart: Integer;
  P: Integer;

  procedure AppendLine(const ALine: String);
  begin
    if Trim(ALine) <> '' then
      Result += APrefix + ALine
    else
      Result += ALine;
  end;

begin
  Result := '';
  LineStart := 1;
  P := 1;
  while P <= Length(AText) do
  begin
    if AText[P] in [#10, #13] then
    begin
      LineBody := Copy(AText, LineStart, P - LineStart);
      LineEnd := AText[P];
      if (AText[P] = #13) and (P < Length(AText)) and (AText[P + 1] = #10) then
      begin
        LineEnd += AText[P + 1];
        Inc(P);
      end;
      AppendLine(LineBody + LineEnd);
      LineStart := P + 1;
    end;
    Inc(P);
  end;

  if LineStart <= Length(AText) then
    AppendLine(Copy(AText, LineStart, MaxInt));
end;

procedure TMainWindow.AppendEngineRawLog(const AText: String);
begin
  if AText = '' then
    Exit;
  FEngines[1].LogMemo.SelStart := Length(FEngines[1].LogMemo.Text);
  FEngines[1].LogMemo.SelText := AText;
  FEngines[1].LogMemo.SelStart := Length(FEngines[1].LogMemo.Text);
end;

procedure TMainWindow.AppendEngineLog(const AText: String);
begin
  AppendEngineRawLog(PrefixLogLines(AText, EngineLogPrefix('GUI')));
end;

procedure TMainWindow.AppendEngine2RawLog(const AText: String);
begin
  if AText = '' then
    Exit;
  if FEngines[2].LogMemo = nil then
    Exit;

  FEngines[2].LogMemo.SelStart := Length(FEngines[2].LogMemo.Text);
  FEngines[2].LogMemo.SelText := AText;
  FEngines[2].LogMemo.SelStart := Length(FEngines[2].LogMemo.Text);
end;

procedure TMainWindow.AppendEngine2Log(const AText: String);
begin
  AppendEngine2RawLog(PrefixLogLines(AText, EngineLogPrefix('GUI')));
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
  Result := FEngines[1].Running and (FEngines[1].ProcessInfo.hProcess <> 0) and
    (WaitForSingleObject(FEngines[1].ProcessInfo.hProcess, 0) = WAIT_TIMEOUT);
  if not Result then
    FEngines[1].Running := False;
  {$ELSE}
  Result := (FEngines[1].Process <> nil) and FEngines[1].Process.Running;
  {$ENDIF}
end;

function TMainWindow.EngineLogPrefix(const AName: String): String;
begin
  if FEngineLogShowTimestamps then
    Result := '[' + AName + ' ' + EngineLogTimestamp + '] '
  else
    Result := '[' + AName + '] ';
end;

function TMainWindow.EngineOutputLogText(const AText: String;
  AEngineIndex: Integer): String;
var
  LineBody: String;
  LineEnd: String;
  LineStart: Integer;
  P: Integer;

  procedure AppendLine(const ALine: String);
  var
    TrimmedLine: String;
  begin
    TrimmedLine := Trim(ALine);
    if TrimmedLine <> '' then
      Result += EngineLogPrefix(EngineLogName(AEngineIndex)) + '< ' + ALine
    else
      Result += ALine;
  end;

begin
  Result := '';
  LineStart := 1;
  P := 1;
  while P <= Length(AText) do
  begin
    if AText[P] in [#10, #13] then
    begin
      LineBody := Copy(AText, LineStart, P - LineStart);
      LineEnd := AText[P];
      if (AText[P] = #13) and (P < Length(AText)) and (AText[P + 1] = #10) then
      begin
        LineEnd += AText[P + 1];
        Inc(P);
      end;
      AppendLine(LineBody + LineEnd);
      LineStart := P + 1;
    end;
    Inc(P);
  end;

  if LineStart <= Length(AText) then
    AppendLine(Copy(AText, LineStart, MaxInt));
end;

function TMainWindow.SecondEngineIsRunning: Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result := FEngines[2].Running and (FEngines[2].ProcessInfo.hProcess <> 0) and
    (WaitForSingleObject(FEngines[2].ProcessInfo.hProcess, 0) = WAIT_TIMEOUT);
  if not Result then
    FEngines[2].Running := False;
  {$ELSE}
  Result := (FEngines[2].Process <> nil) and FEngines[2].Process.Running;
  {$ENDIF}
end;

function TMainWindow.EngineParamsFileNameForDisplayName(
  const ADisplayName: String; const AEngineFileName: String): String;
var
  BaseName: String;
  I: Integer;
  SafeName: String;
begin
  SafeName := Trim(ADisplayName);
  for I := 1 to Length(SafeName) do
    if not (SafeName[I] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '-', '.']) then
      SafeName[I] := '_';

  while Pos('__', SafeName) > 0 do
    SafeName := StringReplace(SafeName, '__', '_', [rfReplaceAll]);
  SafeName := Trim(SafeName);
  if SafeName = '' then
    SafeName := 'engine';

  if AEngineFileName <> '' then
    BaseName := ExtractFilePath(AEngineFileName)
  else if FEngines[1].FileName <> '' then
    BaseName := ExtractFilePath(FEngines[1].FileName)
  else
    BaseName := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Result := BaseName + SafeName + '.params.json';
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
  if FEnginePonderAutoDisabled then
  begin
    FEnginePonderAutoDisabled := False;
    FEnginePonderEnabled := True;
  end;
  UpdatePonderMenuItems;
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
  if FEngines[1].Running then
  begin
    AppendEngineLog('> quit' + LineEnding);
    SendEngineCommand('quit');
    WaitForSingleObject(FEngines[1].ProcessInfo.hProcess, 1000);
    if EngineIsRunning then
      TerminateProcess(FEngines[1].ProcessInfo.hProcess, 0);
  end;
  if FEngines[1].InputWriteHandle <> 0 then
  begin
    CloseHandle(FEngines[1].InputWriteHandle);
    FEngines[1].InputWriteHandle := 0;
  end;
  if FEngines[1].OutputReadHandle <> 0 then
  begin
    CloseHandle(FEngines[1].OutputReadHandle);
    FEngines[1].OutputReadHandle := 0;
  end;
  if FEngines[1].ReaderThread <> nil then
  begin
    FEngines[1].ReaderThread.Terminate;
    FEngines[1].ReaderThread.WaitFor;
    FreeAndNil(FEngines[1].ReaderThread);
  end;
  if FEngines[1].ProcessInfo.hThread <> 0 then
  begin
    CloseHandle(FEngines[1].ProcessInfo.hThread);
    FEngines[1].ProcessInfo.hThread := 0;
  end;
  if FEngines[1].ProcessInfo.hProcess <> 0 then
  begin
    CloseHandle(FEngines[1].ProcessInfo.hProcess);
    FEngines[1].ProcessInfo.hProcess := 0;
  end;
  FEngines[1].Running := False;
  {$ELSE}
  if FEngines[1].Process <> nil then
  begin
    if FEngines[1].Process.Running then
    begin
      AppendEngineLog('> quit' + LineEnding);
      SendEngineCommand('quit');
      FEngines[1].Process.WaitOnExit(1000);
      if FEngines[1].Process.Running then
        FEngines[1].Process.Terminate(0);
    end;
    FreeAndNil(FEngines[1].Process);
  end;
  {$ENDIF}
  FAutoPlayActive := False;
  FAutoPlayPlyCount := 0;
  FPendingAutoPlayStart := False;
  FPendingPonderStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingPlayGameWhiteIsEngine := False;
  FPendingPlayGameBlackIsEngine := False;
  FPendingThinkStart := False;
  LeavePlayGameMode;
  if FAutoPlayButton <> nil then
    FAutoPlayButton.Enabled := False;
  if FGoButton <> nil then
    FGoButton.Enabled := False;
  if FMctsButton <> nil then
    FMctsButton.Enabled := False;
  if FStopButton <> nil then
    FStopButton.Enabled := False;
  FEngineSearching := False;
  FEngines[1].SearchMode := esmIdle;
  SetEngineState(esIdle);
end;

procedure TMainWindow.CloseSecondEngine;
begin
  {$IFDEF MSWINDOWS}
  if FEngines[2].Running then
  begin
    AppendEngine2Log('> quit' + LineEnding);
    SendSecondEngineCommand('quit');
    WaitForSingleObject(FEngines[2].ProcessInfo.hProcess, 1000);
    if SecondEngineIsRunning then
      TerminateProcess(FEngines[2].ProcessInfo.hProcess, 0);
  end;
  if FEngines[2].InputWriteHandle <> 0 then
  begin
    CloseHandle(FEngines[2].InputWriteHandle);
    FEngines[2].InputWriteHandle := 0;
  end;
  if FEngines[2].OutputReadHandle <> 0 then
  begin
    CloseHandle(FEngines[2].OutputReadHandle);
    FEngines[2].OutputReadHandle := 0;
  end;
  if FEngines[2].ReaderThread <> nil then
  begin
    FEngines[2].ReaderThread.Terminate;
    FEngines[2].ReaderThread.WaitFor;
    FreeAndNil(FEngines[2].ReaderThread);
  end;
  if FEngines[2].ProcessInfo.hThread <> 0 then
  begin
    CloseHandle(FEngines[2].ProcessInfo.hThread);
    FEngines[2].ProcessInfo.hThread := 0;
  end;
  if FEngines[2].ProcessInfo.hProcess <> 0 then
  begin
    CloseHandle(FEngines[2].ProcessInfo.hProcess);
    FEngines[2].ProcessInfo.hProcess := 0;
  end;
  FEngines[2].Running := False;
  {$ELSE}
  if FEngines[2].Process <> nil then
  begin
    if FEngines[2].Process.Running then
    begin
      AppendEngine2Log('> quit' + LineEnding);
      SendSecondEngineCommand('quit');
      FEngines[2].Process.WaitOnExit(1000);
      if FEngines[2].Process.Running then
        FEngines[2].Process.Terminate(0);
    end;
    FreeAndNil(FEngines[2].Process);
  end;
  {$ENDIF}
  FEngines[2].Ready := False;
  FEngines[2].PendingThinkStart := False;
  FEngines[2].SearchMode := esmIdle;
  FEngines[2].State := esIdle;
  UpdateEngineStateLabels;
  FEngines[2].TextBuffer := '';
  FEngines[2].WaitingForInit := False;
  FEngines[2].FirstReadSeen := False;
end;

procedure TMainWindow.CloseEngineMenuItemClick(Sender: TObject);
begin
  CloseEngine;
  AppendEngineLog('[' + EngineLogName(1) + ' closed]' + LineEnding);
end;

procedure TMainWindow.CloseSecondEngineMenuItemClick(Sender: TObject);
begin
  CloseSecondEngine;
  AppendEngine2Log('[' + EngineLogName(2) + ' closed]' + LineEnding);
end;

procedure TMainWindow.CenterDialogOnMainWindow(ADialog: TCustomForm);
var
  WorkArea: TRect;
begin
  if ADialog = nil then
    Exit;

  WorkArea := Monitor.WorkareaRect;
  ADialog.Position := poDesigned;
  ADialog.Left := Left + ((Width - ADialog.Width) div 2);
  ADialog.Top := Top + ((Height - ADialog.Height) div 2);

  if ADialog.Left < WorkArea.Left then
    ADialog.Left := WorkArea.Left;
  if ADialog.Top < WorkArea.Top then
    ADialog.Top := WorkArea.Top;
  if ADialog.Left + ADialog.Width > WorkArea.Right then
    ADialog.Left := Max(WorkArea.Left, WorkArea.Right - ADialog.Width);
  if ADialog.Top + ADialog.Height > WorkArea.Bottom then
    ADialog.Top := Max(WorkArea.Top, WorkArea.Bottom - ADialog.Height);
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

procedure TMainWindow.OpenSecondEngineMenuItemClick(Sender: TObject);
begin
  if FEngineOpenDialog.Execute then
  begin
    try
      StartSecondEngine(FEngineOpenDialog.FileName);
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
  Dialog.SetParams(FEngines[1].Params);
  Dialog.OnHide := @EngineParamsDialogHide;
  CenterDialogOnMainWindow(Dialog);
  Dialog.Show;
end;

procedure TMainWindow.EditSecondEngineParamsMenuItemClick(Sender: TObject);
var
  Dialog: TEngineParamDialog;
begin
  Dialog := TEngineParamDialog.Create(Self);
  Dialog.SetParams(FEngines[2].Params);
  Dialog.OnHide := @Engine2ParamsDialogHide;
  CenterDialogOnMainWindow(Dialog);
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
    FEngines[1].Params := Dialog.Params;
    if FEngines[1].ParamsFileName = '' then
      FEngines[1].ParamsFileName :=
        EngineParamsFileNameForDisplayName(FEngines[1].DisplayName);
    SaveParamsToJson(FEngines[1].ParamsFileName, FEngines[1].Params);
    AppendEngineLog('[saved engine parameters to ' + FEngines[1].ParamsFileName + ']' +
      LineEnding);
  end;
  Dialog.Release;
end;

procedure TMainWindow.Engine2ParamsDialogHide(Sender: TObject);
var
  Dialog: TEngineParamDialog;
begin
  if not (Sender is TEngineParamDialog) then
    Exit;

  Dialog := TEngineParamDialog(Sender);
  if Dialog.ModalResult = mrOK then
  begin
    FEngines[2].Params := Dialog.Params;
    if FEngines[2].ParamsFileName = '' then
      FEngines[2].ParamsFileName :=
        EngineParamsFileNameForDisplayName(FEngines[2].DisplayName, FEngines[2].FileName);
    SaveParamsToJson(FEngines[2].ParamsFileName, FEngines[2].Params);
    AppendEngine2Log('[saved engine parameters to ' + FEngines[2].ParamsFileName + ']' +
      LineEnding);
  end;
  Dialog.Release;
end;

procedure TMainWindow.HandleEngineIdLine(const ALine: String);
var
  NewDisplayName: String;
  NewParamsFileName: String;
  NameText: String;
  VersionText: String;
begin
  NameText := ExtractHubArgument(ALine, 'name');
  VersionText := ExtractHubArgument(ALine, 'version');

  if NameText = '' then
    Exit;

  NewDisplayName := NameText;
  if VersionText <> '' then
    NewDisplayName += '_' + VersionText;

  if NewDisplayName = FEngines[1].DisplayName then
    Exit;

  FEngines[1].DisplayName := NewDisplayName;
  NewParamsFileName := EngineParamsFileNameForDisplayName(FEngines[1].DisplayName);
  if NewParamsFileName <> FEngines[1].ParamsFileName then
  begin
    FEngines[1].ParamsFileName := NewParamsFileName;
    LoadParamsFromJson(FEngines[1].ParamsFileName, FEngines[1].Params);
    AppendEngineLog('[' + EngineLogName(1) + ' name: ' + FEngines[1].DisplayName + ']' + LineEnding);
    if Length(FEngines[1].Params) > 0 then
      AppendEngineLog('[loaded engine parameters from ' + FEngines[1].ParamsFileName +
        ']' + LineEnding);
  end;
end;

procedure TMainWindow.HandleEngine2IdLine(const ALine: String);
var
  NewDisplayName: String;
  NewParamsFileName: String;
  NameText: String;
  VersionText: String;
begin
  NameText := ExtractHubArgument(ALine, 'name');
  VersionText := ExtractHubArgument(ALine, 'version');

  if NameText = '' then
    Exit;

  NewDisplayName := NameText;
  if VersionText <> '' then
    NewDisplayName += '_' + VersionText;

  if NewDisplayName = FEngines[2].DisplayName then
    Exit;

  FEngines[2].DisplayName := NewDisplayName;
  NewParamsFileName := EngineParamsFileNameForDisplayName(FEngines[2].DisplayName,
    FEngines[2].FileName);
  if NewParamsFileName <> FEngines[2].ParamsFileName then
  begin
    FEngines[2].ParamsFileName := NewParamsFileName;
    LoadParamsFromJson(FEngines[2].ParamsFileName, FEngines[2].Params);
    AppendEngine2Log('[' + EngineLogName(2) + ' name: ' + FEngines[2].DisplayName + ']' + LineEnding);
    if Length(FEngines[2].Params) > 0 then
      AppendEngine2Log('[loaded engine parameters from ' + FEngines[2].ParamsFileName +
        ']' + LineEnding);
  end;
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
  FEngines[1].LogMemo.Clear;
  FEngines[1].LogMemo.Lines.Add('Engine: ' + AFileName);
  FEngines[1].FileName := AFileName;
  FEngines[1].DisplayName := ChangeFileExt(ExtractFileName(AFileName), '');
  FEngines[1].ParamsFileName := EngineParamsFileNameForDisplayName(FEngines[1].DisplayName);
  LoadParamsFromJson(FEngines[1].ParamsFileName, FEngines[1].Params);
  if Length(FEngines[1].Params) > 0 then
    FEngines[1].LogMemo.Lines.Add('Loaded parameters: ' + FEngines[1].ParamsFileName);
  FEngines[1].Ready := False;
  if FAutoPlayButton <> nil then
    FAutoPlayButton.Enabled := False;
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
  FEngines[1].SearchMode := esmIdle;
  FEngines[1].State := esIdle;
  UpdateEngineStateLabels;
  FEngineStartAfterReady := True;
  FEngineStopRequested := False;
  FEngines[1].WaitingForInit := False;
  FIgnoreNextDoneMove := False;
  FEngines[1].SearchMode := esmIdle;
  FEngines[1].TextBuffer := '';
  FEngines[1].FirstReadSeen := False;

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

  FillChar(FEngines[1].ProcessInfo, SizeOf(FEngines[1].ProcessInfo), 0);
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.hStdError := Child2ParentWrite;
  StartupInfo.hStdInput := Parent2ChildRead;
  StartupInfo.hStdOutput := Child2ParentWrite;
  StartupInfo.dwFlags := STARTF_USESTDHANDLES;

  CommandLine := '"' + AFileName + '"';
  CurrentDir := ExtractFilePath(AFileName);
  AppendEngineLog('[' + EngineLogName(1) + ' execute begin]' +
    LineEnding);
  AppendEngineLog('[' + EngineLogName(1) + ' cwd ' + CurrentDir + ']' + LineEnding);
  if not CreateProcess(nil, PChar(CommandLine), nil, nil, True,
    CREATE_NO_WINDOW, nil, PChar(CurrentDir), StartupInfo,
    FEngines[1].ProcessInfo) then
    RaiseLastOSError;

  CloseHandle(Parent2ChildRead);
  Parent2ChildRead := 0;
  CloseHandle(Child2ParentWrite);
  Child2ParentWrite := 0;
  FEngines[1].InputWriteHandle := Parent2ChildWrite;
  FEngines[1].OutputReadHandle := Child2ParentRead;
  FEngines[1].Running := True;
  FEngines[1].ReaderThread := TEngineReaderThread.Create(Self, FEngines[1].OutputReadHandle, 1);
  {$ELSE}
  FEngines[1].Process := TProcess.Create(Self);
  FEngines[1].Process.Executable := AFileName;
  FEngines[1].Process.CurrentDirectory := ExtractFilePath(AFileName);
  FEngines[1].Process.Options := [poUsePipes, poStderrToOutput];
  FEngines[1].Process.ShowWindow := swoHIDE;
  AppendEngineLog('[' + EngineLogName(1) + ' execute begin]' +
    LineEnding);
  AppendEngineLog('[' + EngineLogName(1) + ' cwd ' + FEngines[1].Process.CurrentDirectory + ']' +
    LineEnding);
  FEngines[1].Process.Execute;
  if FEnginePollTimer <> nil then
    FEnginePollTimer.Enabled := True;
  {$ENDIF}
  AppendEngineLog('[' + EngineLogName(1) + ' execute returned' +
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

procedure TMainWindow.StartSecondEngine(const AFileName: String);
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
  CloseSecondEngine;
  FEngines[2].LogMemo.Clear;
  FEngines[2].LogMemo.Lines.Add('Engine 2: ' + AFileName);
  FEngines[2].FileName := AFileName;
  FEngines[2].DisplayName := ChangeFileExt(ExtractFileName(AFileName), '');
  FEngines[2].ParamsFileName := EngineParamsFileNameForDisplayName(FEngines[2].DisplayName,
    FEngines[2].FileName);
  LoadParamsFromJson(FEngines[2].ParamsFileName, FEngines[2].Params);
  if Length(FEngines[2].Params) > 0 then
    FEngines[2].LogMemo.Lines.Add('Loaded parameters: ' + FEngines[2].ParamsFileName);
  FEngines[2].Ready := False;
  FEngines[2].PendingThinkStart := False;
  FEngines[2].SearchMode := esmIdle;
  FEngines[2].State := esIdle;
  UpdateEngineStateLabels;
  FEngines[2].WaitingForInit := False;
  FEngines[2].TextBuffer := '';
  FEngines[2].FirstReadSeen := False;

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

  FillChar(FEngines[2].ProcessInfo, SizeOf(FEngines[2].ProcessInfo), 0);
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.hStdError := Child2ParentWrite;
  StartupInfo.hStdInput := Parent2ChildRead;
  StartupInfo.hStdOutput := Child2ParentWrite;
  StartupInfo.dwFlags := STARTF_USESTDHANDLES;

  CommandLine := '"' + AFileName + '"';
  CurrentDir := ExtractFilePath(AFileName);
  AppendEngine2Log('[' + EngineLogName(2) + ' execute begin]' +
    LineEnding);
  AppendEngine2Log('[' + EngineLogName(2) + ' cwd ' + CurrentDir + ']' + LineEnding);
  if not CreateProcess(nil, PChar(CommandLine), nil, nil, True,
    CREATE_NO_WINDOW, nil, PChar(CurrentDir), StartupInfo,
    FEngines[2].ProcessInfo) then
    RaiseLastOSError;

  CloseHandle(Parent2ChildRead);
  Parent2ChildRead := 0;
  CloseHandle(Child2ParentWrite);
  Child2ParentWrite := 0;
  FEngines[2].InputWriteHandle := Parent2ChildWrite;
  FEngines[2].OutputReadHandle := Child2ParentRead;
  FEngines[2].Running := True;
  FEngines[2].ReaderThread := TEngineReaderThread.Create(Self, FEngines[2].OutputReadHandle, 2);
  {$ELSE}
  FEngines[2].Process := TProcess.Create(Self);
  FEngines[2].Process.Executable := AFileName;
  FEngines[2].Process.CurrentDirectory := ExtractFilePath(AFileName);
  FEngines[2].Process.Options := [poUsePipes, poStderrToOutput];
  FEngines[2].Process.ShowWindow := swoHIDE;
  AppendEngine2Log('[' + EngineLogName(2) + ' execute begin]' +
    LineEnding);
  AppendEngine2Log('[' + EngineLogName(2) + ' cwd ' + FEngines[2].Process.CurrentDirectory + ']' +
    LineEnding);
  FEngines[2].Process.Execute;
  if FEnginePollTimer <> nil then
    FEnginePollTimer.Enabled := True;
  {$ENDIF}
  AppendEngine2Log('[' + EngineLogName(2) + ' execute returned' +
    ' running=' + BoolToStr(SecondEngineIsRunning, True) + ']' + LineEnding);

  AppendEngine2Log('> hub' + LineEnding);
  SendSecondEngineCommand('hub');
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
    {$IFDEF MSWINDOWS}
    if (FEngines[1].InputWriteHandle <> 0) and
      (not WriteFile(FEngines[1].InputWriteHandle, CommandText[1],
        Length(CommandText), BytesWritten, nil)) then
      RaiseLastOSError;
    {$ELSE}
    FEngines[1].Process.Input.WriteBuffer(CommandText[1], Length(CommandText));
    {$ENDIF}
  end;
end;

procedure TMainWindow.SendSecondEngineCommand(const ACommand: String);
var
  {$IFDEF MSWINDOWS}
  BytesWritten: DWORD;
  {$ENDIF}
  CommandText: String;
begin
  if not SecondEngineIsRunning then
    Exit;

  CommandText := ACommand + LineEnding;
  if CommandText <> '' then
  begin
    {$IFDEF MSWINDOWS}
    if (FEngines[2].InputWriteHandle <> 0) and
      (not WriteFile(FEngines[2].InputWriteHandle, CommandText[1],
        Length(CommandText), BytesWritten, nil)) then
      RaiseLastOSError;
    {$ELSE}
    FEngines[2].Process.Input.WriteBuffer(CommandText[1], Length(CommandText));
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
    esWaitingForOtherEngine: Result := 'waiting for other engine';
  else
    Result := 'unknown';
  end;
end;

function TMainWindow.EngineStateCaption(AState: TEngineState): String;
begin
  case AState of
    esIdle: Result := 'Idle';
    esPondering: Result := 'Pondering';
    esMcts: Result := 'MCTS';
    esThinking: Result := 'Thinking';
    esWaitingForOtherEngine: Result := 'Waiting';
  else
    Result := 'Unknown';
  end;
end;

function EngineStateNeedsStop(AState: TEngineState): Boolean;
begin
  Result := AState in [esPondering, esMcts, esThinking];
end;

function TMainWindow.EngineLogName(AEngineIndex: Integer): String;
begin
  if AEngineIndex = 2 then
    Result := FEngines[2].DisplayName
  else
    Result := FEngines[1].DisplayName;
  if Result = '' then
    if AEngineIndex = 2 then
      Result := 'Engine 2'
    else
      Result := 'Engine';
end;

function TMainWindow.EngineStateLogText(AState: TEngineState): String;
begin
  if AState = esWaitingForOtherEngine then
    Result := 'wait for ' + PlayerNameToMove
  else
    Result := EngineStateText(AState);
end;

procedure TMainWindow.SetEngineState(AState: TEngineState);
begin
  if FEngines[1].State = AState then
    Exit;

  FEngines[1].State := AState;
  UpdateEngineStateLabels;
  AppendEngineLog('[' + EngineLogName(1) + ' state: ' +
    EngineStateLogText(FEngines[1].State) + ']' + LineEnding);
end;

procedure TMainWindow.SetSecondEngineState(AState: TEngineState);
begin
  if FEngines[2].State = AState then
    Exit;

  FEngines[2].State := AState;
  UpdateEngineStateLabels;
  AppendEngine2Log('[' + EngineLogName(2) + ' state: ' +
    EngineStateLogText(FEngines[2].State) + ']' + LineEnding);
end;

procedure TMainWindow.UpdateEngineStateLabels;
begin
  if FEngines[1].StateLabel <> nil then
    FEngines[1].StateLabel.Caption := EngineStateCaption(FEngines[1].State);
  if FEngines[2].StateLabel <> nil then
    FEngines[2].StateLabel.Caption := EngineStateCaption(FEngines[2].State);
end;

procedure TMainWindow.SendEngineParams;
var
  Command: String;
  I: Integer;
begin
  for I := 0 to High(FEngines[1].Params) do
  begin
    if FEngines[1].Params[I].Name = '' then
      Continue;
    Command := 'set-param name=' + HubQuote(FEngines[1].Params[I].Name) +
      ' value=' + HubQuote(FEngines[1].Params[I].Value);
    AppendEngineLog('> ' + Command + LineEnding);
    SendEngineCommand(Command);
  end;
end;

procedure TMainWindow.SendSecondEngineParams;
var
  Command: String;
  I: Integer;
begin
  for I := 0 to High(FEngines[2].Params) do
  begin
    if FEngines[2].Params[I].Name = '' then
      Continue;
    Command := 'set-param name=' + HubQuote(FEngines[2].Params[I].Name) +
      ' value=' + HubQuote(FEngines[2].Params[I].Value);
    AppendEngine2Log('> ' + Command + LineEnding);
    SendSecondEngineCommand(Command);
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
  if FEngines[1].OutputReadHandle = 0 then
    Exit;

  while True do
  begin
    Available := 0;
    if not PeekNamedPipe(FEngines[1].OutputReadHandle, nil, 0, nil, @Available, nil) then
      Break;
    if Available = 0 then
      Break;

    if not FEngines[1].FirstReadSeen then
    begin
      FEngines[1].FirstReadSeen := True;
      AppendEngineLog('[' + EngineLogName(1) + ' first read available=' +
        IntToStr(Available) + ']' + LineEnding);
    end;

    BytesReadWin := 0;
    if not ReadFile(FEngines[1].OutputReadHandle, Buffer[0], SizeOf(Buffer),
      BytesReadWin, nil) then
      Break;
    if BytesReadWin = 0 then
      Break;

    SetString(Chunk, PChar(@Buffer[0]), BytesReadWin);
    AppendEngineRawLog(EngineOutputLogText(Chunk, 1));
    ProcessEngineOutput(Chunk);
  end;
  {$ELSE}
  if FEngines[1].Process = nil then
    Exit;

  while (FEngines[1].Process.Output <> nil) and
    (FEngines[1].Process.Output.NumBytesAvailable > 0) do
  begin
    if not FEngines[1].FirstReadSeen then
    begin
      FEngines[1].FirstReadSeen := True;
      AppendEngineLog('[' + EngineLogName(1) + ' first read available=' +
        IntToStr(FEngines[1].Process.Output.NumBytesAvailable) + ']' +
        LineEnding);
    end;
    BytesRead := FEngines[1].Process.Output.Read(Buffer, SizeOf(Buffer));
    if BytesRead <= 0 then
      Break;

    SetString(Chunk, PChar(@Buffer[0]), BytesRead);
    AppendEngineRawLog(EngineOutputLogText(Chunk, 1));
    ProcessEngineOutput(Chunk);
  end;
  {$ENDIF}
end;

procedure TMainWindow.EngineProcessReadSecondEngineData;
{$IFNDEF MSWINDOWS}
var
  Buffer: array[0..4095] of Byte;
  BytesRead: LongInt;
  Chunk: String;
{$ENDIF}
begin
  {$IFNDEF MSWINDOWS}
  if FEngines[2].Process = nil then
    Exit;

  if not FEngines[2].FirstReadSeen then
  begin
    FEngines[2].FirstReadSeen := True;
    AppendEngine2Log('[' + EngineLogName(2) + ' first read available=' +
      IntToStr(FEngines[2].Process.Output.NumBytesAvailable) + ']' +
      LineEnding);
  end;
  BytesRead := FEngines[2].Process.Output.Read(Buffer, SizeOf(Buffer));
  if BytesRead <= 0 then
    Exit;

  SetString(Chunk, PChar(@Buffer[0]), BytesRead);
  AppendEngine2RawLog(EngineOutputLogText(Chunk, 2));
  ProcessSecondEngineOutput(Chunk);
  {$ENDIF}
end;

procedure TMainWindow.EnginePollTimerTimer(Sender: TObject);
begin
  {$IFDEF MSWINDOWS}
  if (FEngines[1].ProcessInfo.hProcess = 0) and (FEngines[2].ProcessInfo.hProcess = 0) then
  begin
    if FEnginePollTimer <> nil then
      FEnginePollTimer.Enabled := False;
    Exit;
  end;
  if (FEngines[1].ProcessInfo.hProcess <> 0) and (not EngineIsRunning) then
  begin
    EngineProcessTerminate(Sender);
  end;
  if FEngines[1].ProcessInfo.hProcess <> 0 then
    EngineProcessReadData(Sender);
  {$ELSE}
  if (FEngines[1].Process = nil) and (FEngines[2].Process = nil) then
  begin
    if FEnginePollTimer <> nil then
      FEnginePollTimer.Enabled := False;
    Exit;
  end;

  if (FEngines[1].Process <> nil) and (not FEngines[1].Process.Running) then
  begin
    EngineProcessTerminate(Sender);
  end
  else if FEngines[1].Process <> nil then
    EngineProcessReadData(Sender);

  if (FEngines[2].Process <> nil) and (not FEngines[2].Process.Running) then
  begin
    AppendEngine2Log(LineEnding + '[' + EngineLogName(2) + ' process terminated]' + LineEnding);
    FreeAndNil(FEngines[2].Process);
    FEngines[2].Ready := False;
  end
  else if FEngines[2].Process <> nil then
  begin
    while (FEngines[2].Process.Output <> nil) and
      (FEngines[2].Process.Output.NumBytesAvailable > 0) do
    begin
      EngineProcessReadSecondEngineData;
    end;
  end;
  {$ENDIF}
end;

procedure TMainWindow.EngineProcessTerminate(Sender: TObject);
begin
  if FEnginePollTimer <> nil then
    FEnginePollTimer.Enabled := False;
  EngineProcessReadData(Sender);
  FEngines[1].Ready := False;
  FAutoPlayActive := False;
  FPendingAutoPlayStart := False;
  FPendingMctsStart := False;
  FPendingPonderStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  LeavePlayGameMode;
  SetEngineState(esIdle);
  FEngines[1].SearchMode := esmIdle;
  if FAutoPlayButton <> nil then
    FAutoPlayButton.Enabled := False;
  if FGoButton <> nil then
    FGoButton.Enabled := False;
  if FMctsButton <> nil then
    FMctsButton.Enabled := False;
  if FStopButton <> nil then
    FStopButton.Enabled := False;
  AppendEngineLog(LineEnding + '[' + EngineLogName(1) + ' process terminated]' + LineEnding);
  if SecondEngineIsRunning and (FEnginePollTimer <> nil) then
    FEnginePollTimer.Enabled := True;
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

function TMainWindow.PlayEngineMove(const AEngineMove: String;
  AEngineIndex: Integer): Boolean;
var
  Annotation: String;
  MoveIndex: Integer;
  MoveToPlay: TMove;
begin
  Result := False;
  MoveIndex := EngineMoveIndex(AEngineMove);
  if MoveIndex >= 0 then
  begin
    if AEngineIndex = 2 then
      AppendEngine2Log('[' + EngineLogName(2) + ' executing move ' + AEngineMove + ']' + LineEnding)
    else
      AppendEngineLog('[' + EngineLogName(1) + ' executing move ' + AEngineMove + ']' + LineEnding);
    UpdateGameClock;
    Annotation := FLastEngineInfoAnnotation;
    FLastEngineInfoAnnotation := '';
    CopyMove(FMoves[MoveIndex], MoveToPlay);
    ApplyMove(MoveToPlay);
    RecordPlayedMove(MoveToPlay, Annotation);
    LogPlayedMoveToEngineWindows(MoveToPlay, AEngineIndex);
    SysUtils.Beep;
    CheckDrawByRepetition;
    Exit(True);
  end;

  if AEngineIndex = 2 then
    AppendEngine2Log('[' + EngineLogName(2) + ' move is not legal here: ' + AEngineMove + ']' +
      LineEnding)
  else
    AppendEngineLog('[' + EngineLogName(1) + ' move is not legal here: ' + AEngineMove + ']' +
      LineEnding);
end;

procedure TMainWindow.HandleEngineDoneMove(const AMoveText: String);
begin
  FEngineSearching := False;
  FEngineStopRequested := False;
  SetEngineState(esIdle);
  case FEngines[1].SearchMode of
  esmAutoPlay:
  begin
    FEngines[1].SearchMode := esmIdle;
    if PlayEngineMove(AMoveText) then
    begin
      if not FAutoPlayActive then
        Exit;
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
      AppendEngineLog('[auto-play stopped: ' + EngineLogName(1) + ' move could not be played]' +
        LineEnding);
    end;
  end;
  esmPlayGameThink:
  begin
    FEngines[1].SearchMode := esmIdle;
    if PlayEngineMove(AMoveText) then
    begin
      if not FPlayGameActive then
        Exit;
      if Length(FMoves) = 0 then
      begin
        LeavePlayGameMode;
        AppendEngineLog('[play game stopped: terminal position]' + LineEnding);
      end
      else
      begin
        if IsPlayGameSecondEngineTurn then
          SetEngineState(esWaitingForOtherEngine);
        ContinuePlayGameSearch;
      end;
    end
    else
    begin
      LeavePlayGameMode;
      AppendEngineLog('[play game stopped: ' + EngineLogName(1) + ' move could not be played]' +
        LineEnding);
    end;
  end;
  esmPonder, esmPlayGamePonder:
  begin
    FEngines[1].SearchMode := esmIdle;
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
    FEngines[1].SearchMode := esmIdle;
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
      FEngines[1].SearchMode := esmAutoPlay;
      HandleEngineDoneMove(AMoveText);
    end
    else if AMoveText <> '' then
      AppendEngineLog('[' + EngineLogName(1) + ' move ignored: ' + AMoveText + ']' + LineEnding)
    else
      AppendEngineLog('[' + EngineLogName(1) + ' done]' + LineEnding);
  end;
end;

procedure TMainWindow.ProcessEngineOutput(const AText: String);
var
  ErrorText: String;
  Line: String;
  LineEnd: Integer;
  MoveText: String;
begin
  FEngines[1].TextBuffer += AText;

  while True do
  begin
    LineEnd := Pos(LineEnding, FEngines[1].TextBuffer);
    if LineEnd = 0 then
      LineEnd := Pos(#10, FEngines[1].TextBuffer);
    if LineEnd = 0 then
      Break;

    Line := Trim(Copy(FEngines[1].TextBuffer, 1, LineEnd - 1));
    Delete(FEngines[1].TextBuffer, 1, LineEnd);

    if Line = 'wait' then
    begin
      if not FEngines[1].WaitingForInit then
      begin
        FEngines[1].WaitingForInit := True;
        SendEngineParams;
        AppendEngineLog('> init' + LineEnding);
        SendEngineCommand('init');
      end;
    end
    else if Line = 'ready' then
    begin
      FEngines[1].Ready := True;
      FEngines[1].WaitingForInit := False;
      if FAutoPlayButton <> nil then
        FAutoPlayButton.Enabled := True;
      if FGoButton <> nil then
        FGoButton.Enabled := True;
      if FMctsButton <> nil then
        FMctsButton.Enabled := True;
      if FStopButton <> nil then
        FStopButton.Enabled := True;
      AppendEngineLog('[' + EngineLogName(1) + ' ready]' + LineEnding);
      if FEngines[1].ParamsFileName <> '' then
        SaveParamsToJson(FEngines[1].ParamsFileName, FEngines[1].Params);
      if FEngineStartAfterReady then
      begin
        FEngineStartAfterReady := False;
        if FPlayGameActive then
          ContinuePlayGameSearch
        else
          SendGoPonderToEngine;
      end;
    end
    else if StartsText('param ', Line) then
      AddOrUpdateParam(FEngines[1].Params, ExtractHubArgument(Line, 'name'),
        ExtractHubArgument(Line, 'type'), ExtractHubArgument(Line, 'value'), True)
    else if StartsText('id ', Line) then
      HandleEngineIdLine(Line)
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
      AppendEngineLog('[' + EngineLogName(1) + ' error: ' + ErrorText + ']' + LineEnding);
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
        FEngines[1].SearchMode := esmIdle;
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
        FEngines[1].SearchMode := esmIdle;
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
        FEngines[1].SearchMode := esmIdle;
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
        FEngines[1].SearchMode := esmIdle;
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
        FEngines[1].SearchMode := esmIdle;
        SetEngineState(esIdle);
        if MoveText <> '' then
          AppendEngineLog('[ignored previous-search move ' + MoveText + ']' +
            LineEnding)
        else
          AppendEngineLog('[previous search stopped]' + LineEnding);
        BeginPlayGame(FPendingPlayGameWhiteIsEngine,
          FPendingPlayGameBlackIsEngine, FPendingPlayGameWhiteName,
          FPendingPlayGameBlackName, FPendingPlayGameMinutes,
          FPendingPlayGameFromCurrent);
      end
      else if FIgnoreNextDoneMove then
      begin
        FIgnoreNextDoneMove := False;
        FEngineSearching := False;
        FEngineStopRequested := False;
        FEngines[1].SearchMode := esmIdle;
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

procedure TMainWindow.ProcessSecondEngineOutput(const AText: String);
var
  ErrorText: String;
  Line: String;
  LineEnd: Integer;
  MoveText: String;
  SearchMode: TEngineSearchMode;
begin
  FEngines[2].TextBuffer += AText;

  while True do
  begin
    LineEnd := Pos(LineEnding, FEngines[2].TextBuffer);
    if LineEnd = 0 then
      LineEnd := Pos(#10, FEngines[2].TextBuffer);
    if LineEnd = 0 then
      Break;

    Line := Trim(Copy(FEngines[2].TextBuffer, 1, LineEnd - 1));
    Delete(FEngines[2].TextBuffer, 1, LineEnd);

    if Line = 'wait' then
    begin
      if not FEngines[2].WaitingForInit then
      begin
        FEngines[2].WaitingForInit := True;
        SendSecondEngineParams;
        AppendEngine2Log('> init' + LineEnding);
        SendSecondEngineCommand('init');
      end;
    end
    else if Line = 'ready' then
    begin
      FEngines[2].Ready := True;
      FEngines[2].WaitingForInit := False;
      AppendEngine2Log('[' + EngineLogName(2) + ' ready]' + LineEnding);
      if FEngines[2].ParamsFileName <> '' then
        SaveParamsToJson(FEngines[2].ParamsFileName, FEngines[2].Params);
      if FEngines[2].PendingThinkStart then
      begin
        FEngines[2].IgnoreNextDoneMove := False;
        FEngines[2].PendingThinkStart := False;
        FEngines[2].SearchMode := esmIdle;
        SetSecondEngineState(esIdle);
        AppendEngine2Log('[previous search stopped]' + LineEnding);
        SendGoThinkToSecondEngine;
        Continue;
      end;
      if FEnginePonderEnabled and (FEngines[1].State = esPondering) and
        (FEngines[1].SearchMode in [esmPonder, esmPlayGamePonder]) then
      begin
        AppendEngine2Log('[' + EngineLogName(2) + ' catching up to current ponder]' + LineEnding);
        SendGoPonderToSecondEngine(FEngines[1].SearchMode);
      end;
    end
    else if StartsText('param ', Line) then
      AddOrUpdateParam(FEngines[2].Params, ExtractHubArgument(Line, 'name'),
        ExtractHubArgument(Line, 'type'), ExtractHubArgument(Line, 'value'), True)
    else if StartsText('id ', Line) then
      HandleEngine2IdLine(Line)
    else if StartsText('error ', Line) then
    begin
      ErrorText := ExtractHubArgument(Line, 'message');
      if ErrorText = '' then
        ErrorText := Line;
      AppendEngine2Log('[' + EngineLogName(2) + ' error: ' + ErrorText + ']' + LineEnding);
    end
    else if StartsText('done ', Line) or (Line = 'done') then
    begin
      MoveText := ExtractHubArgument(Line, 'move');
      if FEngines[2].PendingThinkStart then
      begin
        FEngines[2].PendingThinkStart := False;
        FEngines[2].SearchMode := esmIdle;
        SetSecondEngineState(esIdle);
        if MoveText <> '' then
          AppendEngine2Log('[ignored previous-search move ' +
            MoveText + ']' + LineEnding)
        else
          AppendEngine2Log('[previous search stopped]' + LineEnding);
        SendGoThinkToSecondEngine;
        Continue;
      end;
      if FEngines[2].IgnoreNextDoneMove then
      begin
        FEngines[2].IgnoreNextDoneMove := False;
        FEngines[2].SearchMode := esmIdle;
        SetSecondEngineState(esIdle);
        if MoveText <> '' then
          AppendEngine2Log('[ignored stopped-search move ' +
            MoveText + ']' + LineEnding)
        else
          AppendEngine2Log('[ignored stopped-search done]' + LineEnding);
        Continue;
      end;
      SearchMode := FEngines[2].SearchMode;
      FEngines[2].SearchMode := esmIdle;
      SetSecondEngineState(esIdle);
      if FPlayGameActive and IsPlayGameSecondEngineTurn and
        (SearchMode = esmPlayGameThink) and (MoveText <> '') then
      begin
        if PlayEngineMove(MoveText, 2) then
        begin
          if not FPlayGameActive then
            Exit;
          if Length(FMoves) = 0 then
          begin
            LeavePlayGameMode;
            AppendEngine2Log('[play game stopped: terminal position]' + LineEnding);
          end
          else
          begin
            if IsPlayGameEngineTurn and (not IsPlayGameSecondEngineTurn) then
              SetSecondEngineState(esWaitingForOtherEngine);
            ContinuePlayGameSearch;
          end;
        end
        else
        begin
          LeavePlayGameMode;
          AppendEngine2Log('[play game stopped: ' + EngineLogName(2) + ' move could not be played]' +
            LineEnding);
        end;
      end
      else
      begin
        if MoveText <> '' then
          AppendEngine2Log('[ponder move ignored: ' +
            MoveText + ']' + LineEnding)
        else
          AppendEngine2Log('[' + EngineLogName(2) + ' done]' + LineEnding);
      end;
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
  if EngineStateNeedsStop(FEngines[1].State) then
  begin
    FPendingPonderMode := esmPonder;
    FPendingPonderStart := True;
    AppendEngineLog('[stopping previous search before manual GO]' + LineEnding);
    SendStopToEngine;
  end
  else
  begin
    FPendingPonderStart := False;
    if EngineStateNeedsStop(FEngines[2].State) then
      SendStopToEngine;
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
  if EngineStateNeedsStop(FEngines[1].State) then
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
  if not EngineIsRunning or (not FEngines[1].Ready) then
    Exit;

  if FCurrentPly < Length(FHistoryMoves) then
  begin
    SetLength(FHistoryMoves, FCurrentPly);
    SetLength(FHistoryMoveAnnotations, FCurrentPly);
    SetLength(FHistoryClockSnapshots, FCurrentPly);
    UpdateHistoryList;
  end;
  UpdateHistoryList;
  if EngineStateNeedsStop(FEngines[1].State) then
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

procedure TMainWindow.StartPlayGameFromOptions(AWhiteIsEngine,
  ABlackIsEngine: Boolean; const AWhiteName, ABlackName: String;
  AGameMinutes: Double; AStartFromCurrent: Boolean);
begin
  if AGameMinutes <= 0 then
    AGameMinutes := 5;
  if (not EngineStateNeedsStop(FEngines[1].State)) and
    EngineStateNeedsStop(FEngines[2].State) then
  begin
    BeginPlayGame(AWhiteIsEngine, ABlackIsEngine, AWhiteName, ABlackName,
      AGameMinutes, AStartFromCurrent, False);
    FAutoPlayActive := False;
    if FPlayGameActive and IsPlayGameSecondEngineTurn then
      FEngines[2].PendingThinkStart := True;
    AppendEngine2Log('[stopping previous search before starting game]' +
      LineEnding);
    SendStopToSecondEngine;
    if not (FPlayGameActive and IsPlayGameSecondEngineTurn) then
      ContinuePlayGameSearch;
    Exit;
  end;
  if EngineStateNeedsStop(FEngines[1].State) then
  begin
    BeginPlayGame(AWhiteIsEngine, ABlackIsEngine, AWhiteName, ABlackName,
      AGameMinutes,
      AStartFromCurrent, False);
    FPendingAutoPlayStart := False;
    FPendingMctsStart := False;
    FPendingPlayGameStart := False;
    FPendingPlayGameWhiteIsEngine := AWhiteIsEngine;
    FPendingPlayGameBlackIsEngine := ABlackIsEngine;
    FPendingPlayGameWhiteName := AWhiteName;
    FPendingPlayGameBlackName := ABlackName;
    if not IsPlayGameEngineTurn then
    begin
      if AWhiteIsEngine and ABlackIsEngine then
      begin
        FPendingPonderStart := False;
        FPendingThinkStart := False;
      end
      else if (AWhiteIsEngine or ABlackIsEngine) and FEnginePonderEnabled then
      begin
        FPendingPonderMode := esmPlayGamePonder;
        FPendingPonderStart := True;
        FPendingThinkStart := False;
      end
      else if FEnginePonderEnabled then
      begin
        FPendingPonderMode := esmPonder;
        FPendingPonderStart := True;
        FPendingThinkStart := False;
      end
      else
      begin
        FPendingPonderStart := False;
        FPendingThinkStart := False;
      end;
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

  BeginPlayGame(AWhiteIsEngine, ABlackIsEngine, AWhiteName, ABlackName,
    AGameMinutes, AStartFromCurrent);
end;

procedure TMainWindow.BeginPlayGame(AWhiteIsEngine, ABlackIsEngine: Boolean;
  const AWhiteName, ABlackName: String; AGameMinutes: Double;
  AStartFromCurrent: Boolean; AStartSearch: Boolean);
begin
  FPendingAutoPlayStart := False;
  FPendingPonderStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  FIgnoreNextDoneMove := False;
  ResetClocks;
  FPlayGameWhiteIsEngine := AWhiteIsEngine;
  FPlayGameBlackIsEngine := ABlackIsEngine;
  FPlayGameWhiteName := AWhiteName;
  FPlayGameBlackName := ABlackName;
  FAutoPlayActive := False;
  FPlayGameActive := True;
  if FPlayGameWhiteIsEngine and FPlayGameBlackIsEngine then
  begin
    FEnginePonderAutoDisabled := FEnginePonderEnabled;
    FEnginePonderEnabled := False;
    FPendingPonderStart := False;
    AppendEngineLog('[ponder disabled for engine-vs-engine game]' + LineEnding);
  end
  else if FEnginePonderAutoDisabled then
  begin
    FEnginePonderAutoDisabled := False;
    FEnginePonderEnabled := True;
  end;
  UpdatePonderMenuItems;
  if FPlayGameWhiteIsEngine then
    FGameWhiteName := FPlayGameWhiteName
  else
    FGameWhiteName := 'Human';
  if FPlayGameBlackIsEngine then
    FGameBlackName := FPlayGameBlackName
  else
    FGameBlackName := 'Human';
  FGameResult := '*';
  if not AStartFromCurrent then
    ParseFen('W:W31-50:B1-20');
  ResetHistoryFromCurrentPosition;
  MarkGameDirty;
  StartGameClocks(AGameMinutes);
  UpdateMoveList;
  UpdateHistoryList;
  InvalidateBoard;
  AppendEngineLog('[play game started: white=' + FGameWhiteName + ', black=' +
    FGameBlackName + ', minutes=' + FormatFloat('0.###', AGameMinutes) + ']' +
    LineEnding);

  if not AStartSearch then
    Exit;

  ContinuePlayGameSearch;
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
  BlackIsEngine: Boolean;
  BlackName: String;
  StartFromCurrent: Boolean;
  WhiteIsEngine: Boolean;
  WhiteName: String;
begin
  if Sender is TForm then
    Dialog := TForm(Sender)
  else
    Dialog := FPlayGameDialog;

  Accepted := (Dialog <> nil) and (Dialog.ModalResult = mrOK);

  if Accepted then
  begin
    WhiteIsEngine := (FPlayGameWhitePlayerCombo <> nil) and
      (FPlayGameWhitePlayerCombo.ItemIndex > 0);
    BlackIsEngine := (FPlayGameBlackPlayerCombo <> nil) and
      (FPlayGameBlackPlayerCombo.ItemIndex > 0);
    if WhiteIsEngine then
      WhiteName := FPlayGameWhitePlayerCombo.Text
    else
      WhiteName := 'Human';
    if BlackIsEngine then
      BlackName := FPlayGameBlackPlayerCombo.Text
    else
      BlackName := 'Human';
    StartFromCurrent := (FPlayGameCurrentPositionRadio <> nil) and
      FPlayGameCurrentPositionRadio.Checked;
    if FPlayGameMinutesSpin <> nil then
      GameMinutes := FPlayGameMinutesSpin.Value
    else
      GameMinutes := 5;
  end
  else
  begin
    WhiteIsEngine := False;
    BlackIsEngine := False;
    WhiteName := 'Human';
    BlackName := 'Human';
    StartFromCurrent := False;
    GameMinutes := 5;
  end;

  FPlayGameDialog := nil;
  FPlayGameWhitePlayerCombo := nil;
  FPlayGameBlackPlayerCombo := nil;
  FPlayGameCurrentPositionRadio := nil;
  FPlayGameMinutesSpin := nil;

  if Dialog <> nil then
    Dialog.Release;

  if Accepted then
    StartPlayGameFromOptions(WhiteIsEngine, BlackIsEngine, WhiteName,
      BlackName, GameMinutes, StartFromCurrent);
end;

procedure TMainWindow.ShowPlayGameDialog;
var
  ButtonPanel: TPanel;
  CancelButton: TButton;
  Dialog: TForm;
  BlackLabel: TLabel;
  MinutesLabel: TLabel;
  OKButton: TButton;
  PositionGroup: TPanel;
  PositionLabel: TLabel;
  StandardPositionRadio: TRadioButton;
  WhiteLabel: TLabel;
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

  WhiteLabel := TLabel.Create(Dialog);
  WhiteLabel.Parent := Dialog;
  WhiteLabel.SetBounds(16, 16, 72, 24);
  WhiteLabel.Layout := tlCenter;
  WhiteLabel.Caption := 'White:';

  FPlayGameWhitePlayerCombo := TComboBox.Create(Dialog);
  FPlayGameWhitePlayerCombo.Parent := Dialog;
  FPlayGameWhitePlayerCombo.SetBounds(96, 14, 160, 28);
  FPlayGameWhitePlayerCombo.Style := csDropDownList;
  FPlayGameWhitePlayerCombo.Items.Add('Human');
  if EngineIsRunning and FEngines[1].Ready then
    FPlayGameWhitePlayerCombo.Items.Add(FEngines[1].DisplayName);
  if SecondEngineIsRunning and FEngines[2].Ready then
    FPlayGameWhitePlayerCombo.Items.Add(FEngines[2].DisplayName);
  FPlayGameWhitePlayerCombo.ItemIndex := 0;

  BlackLabel := TLabel.Create(Dialog);
  BlackLabel.Parent := Dialog;
  BlackLabel.SetBounds(16, 52, 72, 24);
  BlackLabel.Layout := tlCenter;
  BlackLabel.Caption := 'Black:';

  FPlayGameBlackPlayerCombo := TComboBox.Create(Dialog);
  FPlayGameBlackPlayerCombo.Parent := Dialog;
  FPlayGameBlackPlayerCombo.SetBounds(96, 50, 160, 28);
  FPlayGameBlackPlayerCombo.Style := csDropDownList;
  FPlayGameBlackPlayerCombo.Items.Add('Human');
  if EngineIsRunning and FEngines[1].Ready then
    FPlayGameBlackPlayerCombo.Items.Add(FEngines[1].DisplayName);
  if SecondEngineIsRunning and FEngines[2].Ready then
    FPlayGameBlackPlayerCombo.Items.Add(FEngines[2].DisplayName);
  FPlayGameBlackPlayerCombo.ItemIndex := 0;

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
  CenterDialogOnMainWindow(Dialog);
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
    MoveText += MoveToHubString(FHistoryMoves[I]);
  end;
  if MoveText <> '' then
    Result += ' moves=' + HubQuote(MoveText);
end;

function TMainWindow.CurrentEngineRemainingTimeSeconds: Double;
begin
  UpdateGameClock;

  if FSideToMove = sideWhite then
    Result := FWhiteClockSeconds
  else
    Result := FBlackClockSeconds;

  if Result < 0 then
    Result := 0;
end;

function TMainWindow.HasPlayGameEnginePlayer: Boolean;
begin
  Result := FPlayGameWhiteIsEngine or FPlayGameBlackIsEngine;
end;

function TMainWindow.HasPlayGameHumanPlayer: Boolean;
begin
  Result := (not FPlayGameWhiteIsEngine) or (not FPlayGameBlackIsEngine);
end;

function TMainWindow.IsPlayGameHumanTurn: Boolean;
begin
  Result := FPlayGameActive and (not IsPlayGameEngineTurn);
end;

function TMainWindow.IsPlayGameEngineTurn: Boolean;
begin
  Result := FPlayGameActive and (((FSideToMove = sideWhite) and
    FPlayGameWhiteIsEngine) or ((FSideToMove = sideBlack) and
    FPlayGameBlackIsEngine));
end;

function TMainWindow.IsPlayGameSecondEngineTurn: Boolean;
begin
  Result := FPlayGameActive and (((FSideToMove = sideWhite) and
    FPlayGameWhiteIsEngine and (FPlayGameWhiteName = FEngines[2].DisplayName)) or
    ((FSideToMove = sideBlack) and FPlayGameBlackIsEngine and
    (FPlayGameBlackName = FEngines[2].DisplayName)));
end;

function TMainWindow.PlayerNameToMove: String;
begin
  if FSideToMove = sideWhite then
    Result := FGameWhiteName
  else
    Result := FGameBlackName;
  if Result = '' then
    Result := 'Human';
end;

procedure TMainWindow.ContinuePlayGameSearch;
begin
  if not FPlayGameActive then
    Exit;

  if IsPlayGameEngineTurn then
  begin
    if IsPlayGameSecondEngineTurn then
    begin
      AppendEngine2Log('[' + EngineLogName(2) + ' to move; starting think]' + LineEnding);
      if EngineStateNeedsStop(FEngines[2].State) then
      begin
        FEngines[2].PendingThinkStart := True;
        AppendEngine2Log('[synchronizing previous search before engine think]' +
          LineEnding);
        if EngineStateNeedsStop(FEngines[1].State) then
          SendStopToEngine
        else
          SendStopToSecondEngine;
      end
      else
        SendGoThinkToSecondEngine;
      Exit;
    end;
    AppendEngineLog('[' + EngineLogName(1) + ' to move; starting think]' + LineEnding);
    if EngineStateNeedsStop(FEngines[1].State) then
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
  else if HasPlayGameEnginePlayer and HasPlayGameHumanPlayer then
    SendPlayGameHumanTurnPonder
  else if HasPlayGameHumanPlayer and EngineIsRunning and FEngines[1].Ready then
  begin
    if EngineStateNeedsStop(FEngines[1].State) then
    begin
      FPendingAutoPlayStart := False;
      FPendingMctsStart := False;
      FPendingPonderMode := esmPonder;
      FPendingPonderStart := True;
      FPendingPlayGameStart := False;
      FPendingThinkStart := False;
      AppendEngineLog('[stopping previous search before human-vs-human ponder]' +
        LineEnding);
      SendStopToEngine;
    end
    else
      SendGoPonderToEngine(esmPonder);
  end;
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
  if FEngines[1].SearchMode = esmIdle then
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

procedure TMainWindow.PasteFenMenuItemClick(Sender: TObject);
var
  Fen: String;
begin
  Fen := Trim(Clipboard.AsText);
  if Fen = '' then
  begin
    MessageDlg('Paste Position', 'The clipboard does not contain a FEN string.',
      mtError, [mbOK], 0);
    Exit;
  end;

  try
    ParseFen(Fen);
    FGameWhiteName := 'Human';
    FGameBlackName := 'Human';
    FGameResult := '*';
    LeavePlayGameMode;
    ResetHistoryFromCurrentPosition;
    FGameDirty := True;
    UpdateMoveList;
    UpdateHistoryList;
    Caption := 'International Draughts';
    InvalidateBoard;
    AppendEngineLog('[pasted FEN ' + Fen + ']' + LineEnding);
    RestartEnginePonder;
  except
    on E: Exception do
      MessageDlg('Paste Position', E.Message, mtError, [mbOK], 0);
  end;
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
  CloseSecondEngine;
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

  CenterDialogOnMainWindow(Dialog);
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
  if not FEngines[1].Ready then
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
  if not (HasPlayGameEnginePlayer and HasPlayGameHumanPlayer) then
    Exit;
  if Length(FMoves) = 0 then
  begin
    LeavePlayGameMode;
    AppendEngineLog('[play game stopped: terminal position]' + LineEnding);
    Exit;
  end;

  if EngineStateNeedsStop(FEngines[1].State) then
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
  CanUseFirstEngine: Boolean;
  CanUseSecondEngine: Boolean;
  FormatSettings: TFormatSettings;
  LevelCommand: String;
  PositionCommand: String;
begin
  CanUseFirstEngine := EngineIsRunning and FEngines[1].Ready;
  CanUseSecondEngine := SecondEngineIsRunning and FEngines[2].Ready;
  if not CanUseFirstEngine and not CanUseSecondEngine then
    Exit;
  if not FEnginePonderEnabled then
  begin
    if CanUseFirstEngine then
      AppendEngineLog('[ponder disabled: not starting ponder]' + LineEnding);
    if CanUseSecondEngine then
      AppendEngine2Log('[ponder disabled: not starting ponder]' + LineEnding);
    Exit;
  end;

  if Length(FMoves) = 0 then
  begin
    if CanUseFirstEngine then
    begin
      AppendEngineLog('[' + EngineLogName(1) + ' not starting search: terminal position]' + LineEnding);
      FEngineSearching := False;
      FEngines[1].SearchMode := esmIdle;
      SetEngineState(esIdle);
    end;
    if CanUseSecondEngine then
    begin
      AppendEngine2Log('[' + EngineLogName(2) + ' not starting search: terminal position]' + LineEnding);
      FEngines[2].SearchMode := esmIdle;
      SetSecondEngineState(esIdle);
    end;
    Exit;
  end;

  PositionCommand := HubPositionCommand;
  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  LevelCommand := Format('level move-time=%.3f', [FEngineMoveTimeSpin.Value],
    FormatSettings);

  FLastEngineInfoAnnotation := '';
  FPonderBestSourceSquare := 0;
  InvalidateBoard;

  if CanUseFirstEngine then
  begin
    AppendEngineLog('> ' + PositionCommand + LineEnding);
    SendEngineCommand(PositionCommand);
    AppendEngineLog('> ' + LevelCommand + LineEnding);
    SendEngineCommand(LevelCommand);
    AppendEngineLog('> go ponder' + LineEnding);
    SendEngineCommand('go ponder');
    FEngineSearching := True;
    FEngines[1].SearchMode := AMode;
    SetEngineState(esPondering);
  end;

  if CanUseSecondEngine then
  begin
    AppendEngine2Log('> ' + PositionCommand + LineEnding);
    SendSecondEngineCommand(PositionCommand);
    AppendEngine2Log('> ' + LevelCommand + LineEnding);
    SendSecondEngineCommand(LevelCommand);
    AppendEngine2Log('> go ponder' + LineEnding);
    SendSecondEngineCommand('go ponder');
    FEngines[2].SearchMode := AMode;
    SetSecondEngineState(esPondering);
  end;
end;

procedure TMainWindow.SendGoPonderToSecondEngine(AMode: TEngineSearchMode);
var
  FormatSettings: TFormatSettings;
  LevelCommand: String;
  PositionCommand: String;
begin
  if not SecondEngineIsRunning then
    Exit;
  if not FEngines[2].Ready then
    Exit;
  if not FEnginePonderEnabled then
  begin
    AppendEngine2Log('[ponder disabled: not starting ponder]' + LineEnding);
    Exit;
  end;
  if Length(FMoves) = 0 then
  begin
    AppendEngine2Log('[' + EngineLogName(2) + ' not starting search: terminal position]' + LineEnding);
    FEngines[2].SearchMode := esmIdle;
    SetSecondEngineState(esIdle);
    Exit;
  end;

  PositionCommand := HubPositionCommand;
  AppendEngine2Log('> ' + PositionCommand + LineEnding);
  SendSecondEngineCommand(PositionCommand);

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  LevelCommand := Format('level move-time=%.3f', [FEngineMoveTimeSpin.Value],
    FormatSettings);
  AppendEngine2Log('> ' + LevelCommand + LineEnding);
  SendSecondEngineCommand(LevelCommand);
  AppendEngine2Log('> go ponder' + LineEnding);
  SendSecondEngineCommand('go ponder');
  FEngines[2].SearchMode := AMode;
  SetSecondEngineState(esPondering);
end;

procedure TMainWindow.SendGoMctsToEngine;
var
  FormatSettings: TFormatSettings;
  LevelCommand: String;
  PositionCommand: String;
begin
  if not EngineIsRunning then
    Exit;
  if not FEngines[1].Ready then
    Exit;
  if Length(FMoves) = 0 then
  begin
    AppendEngineLog('[' + EngineLogName(1) + ' not starting search: terminal position]' + LineEnding);
    FEngineSearching := False;
    FEngines[1].SearchMode := esmIdle;
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
  FEngines[1].SearchMode := esmMcts;
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
  if not FEngines[1].Ready then
    Exit;
  if Length(FMoves) = 0 then
  begin
    if FPlayGameActive then
      LeavePlayGameMode;
    FAutoPlayActive := False;
    FEngineSearching := False;
    FEngines[1].SearchMode := esmIdle;
    SetEngineState(esIdle);
    AppendEngineLog('[' + EngineLogName(1) + ' not starting search: terminal position]' + LineEnding);
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
  FEngines[1].SearchMode := AMode;
  SetEngineState(esThinking);
end;

procedure TMainWindow.SendGoThinkToSecondEngine;
var
  FormatSettings: TFormatSettings;
  LevelCommand: String;
  PositionCommand: String;
begin
  if not SecondEngineIsRunning then
    Exit;
  if not FEngines[2].Ready then
    Exit;
  if Length(FMoves) = 0 then
  begin
    if FPlayGameActive then
      LeavePlayGameMode;
    FEngines[2].SearchMode := esmIdle;
    SetSecondEngineState(esIdle);
    AppendEngine2Log('[' + EngineLogName(2) + ' not starting search: terminal position]' + LineEnding);
    Exit;
  end;

  PositionCommand := HubPositionCommand;
  AppendEngine2Log('> ' + PositionCommand + LineEnding);
  SendSecondEngineCommand(PositionCommand);

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  LevelCommand := Format('level time=%.3f', [CurrentEngineRemainingTimeSeconds],
    FormatSettings);
  AppendEngine2Log('> ' + LevelCommand + LineEnding);
  SendSecondEngineCommand(LevelCommand);
  AppendEngine2Log('> go think' + LineEnding);
  SendSecondEngineCommand('go think');
  FEngines[2].SearchMode := esmPlayGameThink;
  SetSecondEngineState(esThinking);
end;

procedure TMainWindow.RestartEnginePonder;
begin
  if not FEnginePonderEnabled then
    Exit;
  if (not (EngineIsRunning and FEngines[1].Ready)) and
    (not (SecondEngineIsRunning and FEngines[2].Ready)) then
    Exit;
  if FAutoPlayActive or FPlayGameActive then
    Exit;

  if EngineStateNeedsStop(FEngines[1].State) then
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
  begin
    if EngineStateNeedsStop(FEngines[2].State) then
      SendStopToEngine;
    SendGoPonderToEngine;
  end;
end;

procedure TMainWindow.SendStopToEngine;
var
  PreviousState: TEngineState;
begin
  SendStopToSecondEngine;

  if not EngineIsRunning then
    Exit;

  PreviousState := FEngines[1].State;
  AppendEngineLog('> stop' + LineEnding);
  AppendEngineLog('[' + EngineLogName(1) + ' stop requested while state: ' +
    EngineStateLogText(PreviousState) + ']' + LineEnding);
  FIgnoreNextDoneMove := EngineStateNeedsStop(FEngines[1].State);
  FEngineStopRequested := False;
  FEngineSearching := False;
  FEngines[1].SearchMode := esmIdle;
  if PreviousState <> esIdle then
  begin
    FEngines[1].State := esIdle;
    UpdateEngineStateLabels;
    AppendEngineLog('[' + EngineLogName(1) + ' state: ' + EngineStateLogText(PreviousState) +
      ' -> idle]' + LineEnding);
  end
  else
    SetEngineState(esIdle);
  SendEngineCommand('stop');
end;

procedure TMainWindow.SendStopToSecondEngine;
var
  PreviousState: TEngineState;
begin
  if not SecondEngineIsRunning then
    Exit;

  PreviousState := FEngines[2].State;
  AppendEngine2Log('> stop' + LineEnding);
  AppendEngine2Log('[' + EngineLogName(2) + ' stop requested while state: ' +
    EngineStateLogText(PreviousState) + ']' + LineEnding);
  FEngines[2].IgnoreNextDoneMove := EngineStateNeedsStop(FEngines[2].State);
  FEngines[2].SearchMode := esmIdle;
  if PreviousState <> esIdle then
  begin
    FEngines[2].State := esIdle;
    UpdateEngineStateLabels;
    AppendEngine2Log('[' + EngineLogName(2) + ' state: ' + EngineStateLogText(PreviousState) +
      ' -> idle]' + LineEnding);
  end
  else
    SetSecondEngineState(esIdle);
  SendSecondEngineCommand('stop');
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
  CenterDialogOnMainWindow(Dialog);
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
  if (FSaveEngineLogDialog = nil) or (FEngines[1].LogMemo = nil) then
    Exit;

  if FSaveEngineLogDialog.Execute then
  begin
    FEngines[1].LogMemo.Lines.SaveToFile(FSaveEngineLogDialog.FileName);
    AppendEngineLog('[saved engine log ' + FSaveEngineLogDialog.FileName + ']' +
      LineEnding);
  end;
end;

procedure TMainWindow.SaveSecondEngineLogMenuItemClick(Sender: TObject);
begin
  if (FSaveEngineLogDialog = nil) or (FEngines[2].LogMemo = nil) then
    Exit;

  if FSaveEngineLogDialog.Execute then
  begin
    FEngines[2].LogMemo.Lines.SaveToFile(FSaveEngineLogDialog.FileName);
    AppendEngine2Log('[saved engine log ' + FSaveEngineLogDialog.FileName + ']' +
      LineEnding);
  end;
end;

procedure TMainWindow.UpdatePonderMenuItems;
var
  DisablePonderToggle: Boolean;
begin
  DisablePonderToggle := FPlayGameActive and FPlayGameWhiteIsEngine and
    FPlayGameBlackIsEngine;
  if FEngines[1].PonderMenuItem <> nil then
  begin
    FEngines[1].PonderMenuItem.Checked := FEnginePonderEnabled;
    FEngines[1].PonderMenuItem.Enabled := not DisablePonderToggle;
  end;
  if FEngines[2].PonderMenuItem <> nil then
  begin
    FEngines[2].PonderMenuItem.Checked := FEnginePonderEnabled;
    FEngines[2].PonderMenuItem.Enabled := not DisablePonderToggle;
  end;
end;

procedure TMainWindow.PonderMenuItemClick(Sender: TObject);
begin
  if FPlayGameActive and FPlayGameWhiteIsEngine and FPlayGameBlackIsEngine then
    Exit;
  FEnginePonderAutoDisabled := False;
  FEnginePonderEnabled := not FEnginePonderEnabled;
  UpdatePonderMenuItems;
  if FEnginePonderEnabled then
  begin
    AppendEngineLog('[ponder enabled]' + LineEnding);
    if FAutoPlayActive then
      Exit;
    if FPlayGameActive then
    begin
      if not IsPlayGameEngineTurn then
        ContinuePlayGameSearch;
    end
    else
      RestartEnginePonder;
  end
  else
  begin
    AppendEngineLog('[ponder disabled]' + LineEnding);
    FPendingPonderStart := False;
    if (FEngines[1].State = esPondering) or (FEngines[2].State = esPondering) then
      SendStopToEngine;
  end;
end;

procedure TMainWindow.ShowTimestampsMenuItemClick(Sender: TObject);
begin
  FEngineLogShowTimestamps := not FEngineLogShowTimestamps;
  if FEngines[1].ShowTimestampsMenuItem <> nil then
    FEngines[1].ShowTimestampsMenuItem.Checked := FEngineLogShowTimestamps;
  if FEngines[2].ShowTimestampsMenuItem <> nil then
    FEngines[2].ShowTimestampsMenuItem.Checked := FEngineLogShowTimestamps;
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
  CenterDialogOnMainWindow(Dialog);
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
  FGameWhiteName := 'Human';
  FGameBlackName := 'Human';
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
    FGameWhiteName := 'Human';
    FGameBlackName := 'Human';
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
      FGameWhiteName := 'Human';
    FGameBlackName := ExtractPdnTagValue(Lines, 'Black');
    if FGameBlackName = '' then
      FGameBlackName := 'Human';
    FGameResult := ExtractPdnTagValue(Lines, 'Result');
    if FGameResult = '' then
      FGameResult := '*';

    ParseFen(StartFen);
    LeavePlayGameMode;
    ResetHistoryFromCurrentPosition;
    MoveText := StripPdnMoveText(Lines);
    Tokens := MoveText.Split([' ', #9, #10, #13], TStringSplitOptions.ExcludeEmpty);

    FSuppressBoardUpdates := True;
    try
      for I := 0 to High(Tokens) do
      begin
        Token := PdnTokenMoveText(Tokens[I]);
        if (Token = '') or IsPdnResultToken(Token) then
          Continue;

        GenerateLegalMoves(FBoard, FSideToMove, FMoves);
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
    finally
      FSuppressBoardUpdates := False;
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
  FHistoryMemo.Invalidate;
  FHistoryMemo.Update;
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

  if FBoardSideToMoveLabel <> nil then
  begin
    FBoardSideToMoveLabel.Caption := SideName + ' to move';
    FBoardSideToMoveLabel.Color := Color;
    FBoardSideToMoveLabel.Font.Color := clBlack;
  end;

  FMovesMemo.Lines.BeginUpdate;
  try
    FMovesMemo.Clear;
    for I := 0 to High(FMoves) do
      FMovesMemo.Lines.Add(Format('%3d. %s', [I + 1, MoveToString(FMoves[I])]));

    if Length(FMoves) = 0 then
      FMovesMemo.Lines.Add('No legal moves');
  finally
    FMovesMemo.Lines.EndUpdate;
  end;
  if FBoardSideToMoveLabel <> nil then
    FBoardSideToMoveLabel.Invalidate;
  FMovesMemo.Invalidate;
  FMovesMemo.Update;
end;

end.
