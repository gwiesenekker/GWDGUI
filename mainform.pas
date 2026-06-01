unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  CheckLst,
  Classes,
  Clipbrd,
  Controls,
  Dialogs,
  DraughtsRules,
  EasyLazFreeType,
  EngineParams,
  ExtCtrls,
  FPJSON,
  FPImage,
  Forms,
  GraphType,
  Graphics,
  Grids,
  IntfGraphics,
  LazFreeTypeIntfDrawer,
  LazFreeTypeFontCollection,
  Menus,
  PDNSaveDialog,
  Process,
  SetupDialog,
  ssockets,
  Spin,
  StdCtrls,
  JSONParser,
  LCLType
  {$IFDEF MSWINDOWS}
  , Windows
  {$ENDIF}
  , Types;

type
  TMainWindow = class;
  TEngineProtocol = (epHub, epDxp);
  TEngineDxpRole = (edrListener, edrClient);

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

  TEngineDxpConnectionThread = class(TThread)
  private
    FEngineIndex: Integer;
    FErrorMessage: String;
    FIncomingMessage: String;
    FIpAddress: String;
    FListening: Boolean;
    FOwner: TMainWindow;
    FPort: Word;
    FRole: TEngineDxpRole;
    FServer: TInetServer;
    FSocket: TSocketStream;
    procedure ServerConnect(Sender: TObject; Data: TSocketStream);
    procedure DeliverIncomingMessage;
    procedure NotifyConnected;
    procedure NotifyError;
    procedure ReadIncomingMessages;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TMainWindow; AEngineIndex: Integer;
      const AIpAddress: String; APort: Word; ARole: TEngineDxpRole);
    destructor Destroy; override;
    procedure StopConnection;
    property Listening: Boolean read FListening;
  end;

  TIntegerArray = array of Integer;
  TTextArray = array of String;
  TClockSnapshot = record
    HasClock: Boolean;
    WhiteSeconds: Double;
    BlackSeconds: Double;
  end;
  TClockSnapshotArray = array of TClockSnapshot;
  TGuiState = (gsIdle, gsAnalyzing, gsMcts, gsAutoPlaying,
    gsPlayGameHumanTurn, gsPlayGameEngineTurn, gsTournamentRunning,
    gsStopping, gsGameOver);
  TEngineState = (esIdle, esAnalyzing, esMcts, esThinking,
    esWaitingForOtherEngine);
  TEngineSearchMode = (esmIdle, esmAnalyze, esmMcts, esmAutoPlay,
    esmPlayGameThink, esmPlayGameAnalyze);
  TDxpGameState = (dgsIdle, dgsGameRequested, dgsWaitingForMoveOrGameEnd,
    dgsGameEnding, dgsWaitingForNextGame);
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
    Protocol: TEngineProtocol;
    HubId: String;
    IniFileName: String;
    HubLaunchArgument: String;
    DxpId: String;
    DxpIpAddress: String;
    DxpSocketNumber: String;
    DxpLaunchArguments: String;
    DxpRole: TEngineDxpRole;
    DxpThread: TEngineDxpConnectionThread;
    DxpSocket: TSocketStream;
    DxpGameState: TDxpGameState;
    DxpGameEndSent: Boolean;
    LogPopupMenu: TPopupMenu;
    CloseMenuItem: TMenuItem;
    OpenMenuItem: TMenuItem;
    ParamsMenuItem: TMenuItem;
    AnalyzeMenuItem: TMenuItem;
    SaveLogMenuItem: TMenuItem;
    ShowTimestampsMenuItem: TMenuItem;
    constructor Create(AIndex: Integer);
    procedure BeginSearch(AMode: TEngineSearchMode; AState: TEngineState);
    procedure FinishSearch;
    procedure ResetRuntimeState;
  end;
  TEngineSlotArray = array[1..4] of TEngineSlot;

  TTournamentDialog = class(TForm)
  private
    FCurrentGameStarted: Boolean;
    FCurrentBlackEngineIndex: Integer;
    FCurrentTournamentRow: Integer;
    FCurrentWhiteEngineIndex: Integer;
    FBodyPanel: TPanel;
    FCrossTableSectionPanel: TPanel;
    FDirty: Boolean;
    FEnginePairingPanel: TPanel;
    FEngineSectionPanel: TPanel;
    FEnginesFileName: String;
    FEngineFileNames: TStringList;
    FEngineProtocols: TStringList;
    FFileName: String;
    FCrossTableGrid: TStringGrid;
    FEngineCheckList: TCheckListBox;
    FGrid: TStringGrid;
    FLoadButton: TButton;
    FMinutesEdit: TSpinEdit;
    FNameEdit: TEdit;
    FPreviousMinutesValue: Integer;
    FPreviousRoundRobinIndex: Integer;
    FResultCombo: TComboBox;
    FRoundRobinGroup: TRadioGroup;
    FSaveButton: TButton;
    FStartButton: TButton;
    FStopButton: TButton;
    FSuppressMinutesChange: Boolean;
    FSuppressRoundRobinChange: Boolean;
    FTournamentRunning: Boolean;
    FTournamentTimer: TTimer;
    procedure AddPairing(const AWhite, ABlack: String);
    procedure AdjustSectionHeights;
    procedure CrossTableDrawCell(Sender: TObject; ACol, ARow: Integer;
      ARect: TRect; AState: TGridDrawState);
    procedure DialogClose(Sender: TObject; var CloseAction: TCloseAction);
    function EngineFileNameForName(const AName: String): String;
    function EngineProtocolForName(const AName: String): String;
    procedure GridClick(Sender: TObject);
    function GridIsEmpty: Boolean;
    procedure LoadButtonClick(Sender: TObject);
    procedure LoadEngineNames(AEngines: TStrings);
    procedure LoadSelectedEngineNames(AEngines: TStrings);
    procedure MarkDirty;
    procedure MinutesEditChange(Sender: TObject);
    procedure PopulateEngineCheckList;
    procedure ResultComboChange(Sender: TObject);
    procedure ResultComboExit(Sender: TObject);
    procedure RoundRobinGroupClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    function SaveTournament: Boolean;
    procedure SaveTournamentGamePdn(AGameNumber: Integer);
    function StartNextTournamentGame: Boolean;
    procedure StartButtonClick(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure TournamentTimerTick(Sender: TObject);
    procedure TournamentResize(Sender: TObject);
    procedure UpdateCrossTable;
  public
    constructor Create(AOwner: TComponent; const AEnginesFileName: String); reintroduce;
    destructor Destroy; override;
  end;

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
    FEngineEvalScoreWhite: Double;
    FEvalBarRect: TRect;
    FLastEvalBarWhitePixels: Integer;
    FEngineAnalyzeAutoDisabled: Boolean;
    FEngineAnalyzeEnabled: Boolean;
    FEngineLogShowTimestamps: Boolean;
    FEngineStartAfterReady: Boolean;
    FEngineStopRequested: Boolean;
    FEditMenu: TMenuItem;
    FShuttingDown: Boolean;
    FIgnoreNextDoneMove: Boolean;
    FLastEngineDoneLine: String;
    FLastEngineInfoAnnotation: String;
    FLastEngineInfoLine: String;
    FLastBoardLayoutHeight: Integer;
    FLastBoardLayoutLegalWidth: Integer;
    FLastBoardLayoutWidth: Integer;
    FLastClientLayoutHeight: Integer;
    FLastClientLayoutWidth: Integer;
    FGoButton: TButton;
    FGuiState: TGuiState;
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
    FHistoryEvalPaintBox: TPaintBox;
    FHistoryMemo: TMemo;
    FHistoryClockSnapshots: TClockSnapshotArray;
    FHistoryMoveAnnotations: TTextArray;
    FHistoryMoveLengths: TIntegerArray;
    FHistoryMoveStarts: TIntegerArray;
    FHistoryMoves: TMoveArray;
    FHistoryPvLabel: TLabel;
    FHistoryPvMiniBoardPanel: TPanel;
    FHistoryPvMiniBoardPaintBox: TPaintBox;
    FHistoryResultEdit: TEdit;
    FHistoryResultLabel: TLabel;
    FHistoryWhiteEdit: TEdit;
    FHistoryWhiteLabel: TLabel;
    FWhiteClockSeconds: Double;
    FInitialBlackClockSeconds: Double;
    FInitialWhiteClockSeconds: Double;
    FLastMoveTargetSquare: Integer;
    FOnlyMoveSourceSquare: Integer;
    FAnalyzeBestSourceSquare: Integer;
    FAnalyzeHintSourceSquare: Integer;
    FAnalyzeHintMove: String;
    FAnalyzePvMoves: TTextArray;
    FAnalyzePvBaseBoard: TBoard;
    FAnalyzePvBasePly: Integer;
    FAnalyzePvBaseSide: TSide;
    FAnalyzePvBrowseBoard: TBoard;
    FAnalyzePvBrowsePly: Integer;
    FAnalyzePvBrowseSide: TSide;
    FAnalyzePvHasBase: Boolean;
    FAnalyzePvLocked: Boolean;
    FAnalyzePvMoveLengths: TIntegerArray;
    FAnalyzePvMoveStarts: TIntegerArray;
    FAnalysisBoardForm: TForm;
    FAnalysisBoardPaintBox: TPaintBox;
    FAnalysisBoardPopupMenu: TPopupMenu;
    FShowAnalysisBoardMenuItem: TMenuItem;
    FCurrentPly: Integer;
    FCopyFenMenuItem: TMenuItem;
    FMainMenu: TMainMenu;
    FTournamentMenu: TMenuItem;
    FTournamentDialog: TTournamentDialog;
    FTournamentDialogMenuItem: TMenuItem;
    FRegisteredEnginesMenuItem: TMenuItem;
    FLegalMovesPanel: TPanel;
    FMoves: TMoveArray;
    FMovesMemo: TMemo;
    FPvMemo: TMemo;
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
    FPendingAnalyzeMode: TEngineSearchMode;
    FPendingAnalyzeStart: Boolean;
    FPendingMctsStart: Boolean;
    FPendingPlayGameFromCurrent: Boolean;
    FPendingPlayGameMinutes: Double;
    FPendingPlayGameBlackIsEngine: Boolean;
    FPendingPlayGameBlackEngineIndex: Integer;
    FPendingPlayGameBlackName: String;
    FPendingPlayGameStart: Boolean;
    FPendingPlayGameWhiteIsEngine: Boolean;
    FPendingPlayGameWhiteEngineIndex: Integer;
    FPendingPlayGameWhiteName: String;
    FPendingThinkMode: TEngineSearchMode;
    FPendingThinkStart: Boolean;
    FPlayGameActive: Boolean;
    FPlayGameBlackIsEngine: Boolean;
    FPlayGameBlackEngineIndex: Integer;
    FPlayGameBlackName: String;
    FPlayGameBlackPlayerCombo: TComboBox;
    FPlayGameButton: TButton;
    FPlayGameCurrentPositionRadio: TRadioButton;
    FPlayGameDialog: TForm;
    FPlayGameMinutesSpin: TFloatSpinEdit;
    FPlayGameWhiteIsEngine: Boolean;
    FPlayGameWhiteEngineIndex: Integer;
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
      AStartSearch: Boolean = True; AWhiteEngineIndex: Integer = 0;
      ABlackEngineIndex: Integer = 0);
    procedure BoardPaintBoxMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure BoardPaintBoxPaint(Sender: TObject);
    procedure HistoryEvalPaintBoxPaint(Sender: TObject);
    procedure HistoryPvMiniBoardPaintBoxPaint(Sender: TObject);
    procedure ClockTimerTimer(Sender: TObject);
    procedure ClearBoardSelection;
    procedure ClearBoard;
    procedure CopyFenMenuItemClick(Sender: TObject);
    procedure CloseEngine;
    procedure CloseEngineMenuItemClick(Sender: TObject);
    procedure CloseSecondEngine;
    procedure CloseSecondEngineMenuItemClick(Sender: TObject);
    procedure CenterDialogOnMainWindow(ADialog: TCustomForm);
    procedure DrawAnalysisBoard(ACanvas: TCanvas; const AClient: TRect);
    procedure DrawBoard(ACanvas: TCanvas);
    procedure DrawBoardClockLabels(const ABoardRect: TRect);
    procedure DrawEngineEvalBar(ACanvas: TCanvas; const ABoardRect: TRect);
    procedure DrawBoardSideToMoveMarker(ACanvas: TCanvas; const ABoardRect: TRect;
      ACellSize: Integer);
    procedure DrawPiece(ACanvas: TCanvas; const ASquare: TRect;
      APiece: TPiece; ACellSize: Integer; ASquareColor: TColor);
    function BoardSquareAtCell(ARow, ACol: Integer): Integer;
    procedure EngineProcessReadData(Sender: TObject);
    procedure EngineProcessReadSecondEngineData;
    procedure EnginePollTimerTimer(Sender: TObject);
    procedure EngineProcessTerminate(Sender: TObject);
    procedure HandleEngineProcessTerminated(AEngineIndex: Integer);
    procedure UpdateEnginePollTimer;
    procedure FormShow(Sender: TObject);
    procedure RefreshInitialLayout(Data: PtrInt);
    function EngineMoveIndex(const AEngineMove: String): Integer;
    function EngineMoveMatchesLegalMove(const AEngineMove: String;
      const ALegalMove: TMove): Boolean;
    function EngineIsRunning: Boolean;
    function EngineSlotAvailableForPlay(AEngineIndex: Integer): Boolean;
    function EngineLogPrefix(const AName: String): String;
    function EngineOutputLogText(const AText: String; AEngineIndex: Integer): String;
    function EngineParamsFileNameForDisplayName(const ADisplayName: String;
      const AEngineFileName: String = ''): String;
    function EngineStateCaption(AState: TEngineState): String;
    function GuiStateText(AState: TGuiState): String;
    function SecondEngineIsRunning: Boolean;
    function StartDxpConnection(AEngineIndex: Integer): Boolean;
    procedure StopDxpConnection(AEngineIndex: Integer);
    function DxpListenerPortInUse(AEngineIndex: Integer;
      out AOtherEngineIndex: Integer): Boolean;
    function DxpGameEndCodeForEngine(AEngineIndex: Integer): Char;
    function DxpResultFromGameEnd(AEngineIndex: Integer; ACode: Char): String;
    procedure SendDxpGameReqToEngine(AEngineIndex: Integer; AEngineSide: TSide;
      AGameMinutes: Double);
    procedure SendDxpGameEndToEngine(AEngineIndex: Integer; ACode: Char);
    procedure SendDxpGameEndToPlayingDxpEngines(
      AExcludeEngineIndex: Integer = 0);
    procedure SendDxpMoveToEngine(AEngineIndex: Integer; const AMove: TMove;
      ATimeUsedSeconds: Integer = 0);
    function DxpGameStateText(AState: TDxpGameState): String;
    procedure SetDxpGameState(AEngineIndex: Integer; AState: TDxpGameState);
    procedure MarkDxpWaitingForReply(AEngineIndex: Integer;
      AMode: TEngineSearchMode);
    function DxpShouldAcceptMove(AEngineIndex: Integer;
      ASearchMode: TEngineSearchMode): Boolean;
    procedure ProcessDxpMessage(AEngineIndex: Integer; const AMessage: String);
    procedure SyncHubLaunchArgumentParam(AEngineIndex: Integer);
    procedure SyncSendStartingPositionParam(AEngineIndex: Integer);
    procedure SyncSingleCapturesIncludeCapturedSquareParam(AEngineIndex: Integer);
    procedure SyncEngineSupportsMctsParam(AEngineIndex: Integer);
    procedure SyncScorePerspectiveParam(AEngineIndex: Integer);
    procedure SyncEvaluationDepthMinParam(AEngineIndex: Integer);
    procedure SyncEvaluationBarMaxParam(AEngineIndex: Integer);
    procedure LoadHubLaunchArgumentFromParams(AEngineIndex: Integer);
    function EngineSendStartingPosition(AEngineIndex: Integer): Boolean;
    function EngineSingleCapturesIncludeCapturedSquare(AEngineIndex: Integer): Boolean;
    procedure RemoveAnalyzeSendsInfoParam(AEngineIndex: Integer);
    function EngineSupportsMcts(AEngineIndex: Integer): Boolean;
    function EngineScorePerspective(AEngineIndex: Integer): String;
    function EngineEvaluationDepthMin(AEngineIndex: Integer): Double;
    function EngineEvaluationBarMax(AEngineIndex: Integer): Double;
    function EvalBarWhitePixels(const ABarRect: TRect; AScore: Double): Integer;
    procedure AutoPlayButtonClick(Sender: TObject);
    procedure GoButtonClick(Sender: TObject);
    function PlayEngineMove(const AEngineMove: String;
      AEngineIndex: Integer = 1): Boolean;
    function CurrentPositionRepetitionCount: Integer;
    function HubPositionString: String;
    function HubPositionStringFor(const ABoard: TBoard; ASide: TSide): String;
    function HubPositionCommand(AEngineIndex: Integer): String;
    function PositionKeyFor(const ABoard: TBoard; ASide: TSide): String;
    function CurrentEngineRemainingTimeSeconds: Double;
    function HasPlayGameEnginePlayer: Boolean;
    function HasPlayGameHumanPlayer: Boolean;
    function IsPlayGameHumanTurn: Boolean;
    function IsPlayGameEngineTurn: Boolean;
    function IsPlayGameSecondEngineTurn: Boolean;
    function EngineIsDxp(AEngineIndex: Integer): Boolean;
    function EngineLogName(AEngineIndex: Integer): String;
    function EngineStateLogText(AState: TEngineState): String;
    function PlayerNameToMove: String;
    procedure InvalidateBoard;
    procedure InvalidateBoardSquare(ASquare: Integer);
    procedure InvalidateEngineEvalBar;
    procedure RepaintEngineEvalBarDelta(AOldScore, ANewScore: Double);
    function BoardToFen(const ABoard: TBoard; ASide: TSide): String;
    function BuildPdnMoveText(const AResult: String; AStoreRanges: Boolean): String;
    function BuildAnalyzePvText(AStoreRanges: Boolean): String;
    function ClockAnnotation(APly: Integer): String;
    function EngineInfoAnnotation(const ALine: String): String;
    function HistoryAnnotationScoreWhite(APly: Integer; out AScore: Double): Boolean;
    function GuessResultFromFinalPosition: String;
    procedure HistoryMemoClick(Sender: TObject);
    procedure HistoryMemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure AnalyzePvMemoClick(Sender: TObject);
    procedure AnalyzePvMemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure AnalyzePvMemoKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure AnalysisBoardFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure AnalysisBoardPaintBoxPaint(Sender: TObject);
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
    procedure EnginePopupMenuPopup(Sender: TObject);
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
    procedure RegisterEngineExecutable(const AFileName: String);
    function RegisteredEnginesFileName: String;
    procedure RegisteredEnginesDialogClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure RegisteredEnginesDialogCloseButtonClick(Sender: TObject);
    procedure RegisteredEnginesDialogSaveButtonClick(Sender: TObject);
    procedure NormalizeRegisteredEngineIdsInGrid(AGrid: TStringGrid);
    procedure NormalizeRegisteredEngineIdsInJson(AData: TJSONArray);
    procedure SaveRegisteredEnginesDialog(ADialog: TCustomForm);
    function CheckDrawByRepetition: Boolean;
    procedure LogPlayedMoveToEngineWindows(const AMove: TMove;
      AActorEngineIndex: Integer);
    procedure RestoreClockSnapshot(APly: Integer);
    procedure RebuildAnalyzePvPositionToPly(APly: Integer);
    procedure ResetClocks;
    procedure ActivateGameClocks;
    procedure ResetHistoryFromCurrentPosition;
    procedure NavigateHistoryToPly(APly: Integer);
    procedure MainWindowCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure MarkGameDirty;
    procedure RefreshButtonToolbar(Data: PtrInt);
    procedure QuitMenuItemClick(Sender: TObject);
    procedure RegisteredEnginesMenuItemClick(Sender: TObject);
    procedure TournamentDialogMenuItemClick(Sender: TObject);
    procedure SelectHistoryPly(APly: Integer);
    procedure SelectAnalyzePvPly(APly: Integer);
    procedure SetAnalyzePvLocked(ALocked: Boolean);
    procedure SelectBoardSquare(ASquare: Integer);
    function ShowEngineLauncherDialog(AEngineIndex: Integer;
      out AFileName, APreferredProtocol: String): Boolean;
    function ShowEngineLaunchOptionsDialog(AEngineIndex: Integer;
      const APreferredProtocol: String = ''): Boolean;
    function SquareAtPoint(X, Y: Integer): Integer;
    procedure ProcessEngineOutput(const AText: String);
    procedure ProcessSecondEngineOutput(const AText: String);
    procedure EditEngineParamsMenuItemClick(Sender: TObject);
    procedure EditSecondEngineParamsMenuItemClick(Sender: TObject);
    procedure EngineParamsDialogHide(Sender: TObject);
    procedure Engine2ParamsDialogHide(Sender: TObject);
    procedure HandleEngineIdLine(const ALine: String);
    procedure HandleEngine2IdLine(const ALine: String);
    procedure EngineIniBrowseClick(Sender: TObject);
    procedure SendEngineParams;
    procedure SendSecondEngineParams;
    procedure SetupMenu;
    procedure SetupBoardArea;
    procedure SetupEngineLog;
    procedure SetupMoveList;
    procedure SetupPieceFont;
    procedure SetupPositionMenuItemClick(Sender: TObject);
    procedure SetupPositionDialogHide(Sender: TObject);
    procedure ShowAnalysisBoardMenuItemClick(Sender: TObject);
    procedure ShutdownApplication;
    procedure FinalizeShutdown;
    procedure ShowUnsavedGamePrompt;
    procedure UnsavedGamePromptButtonClick(Sender: TObject);
    procedure UnsavedGamePromptHide(Sender: TObject);
    procedure ShowPlayGameDialog;
    procedure StartGameClocks(AGameMinutes: Double);
    procedure StartPlayGameFromOptions(AWhiteIsEngine, ABlackIsEngine: Boolean;
      const AWhiteName, ABlackName: String; AGameMinutes: Double;
      AStartFromCurrent: Boolean; AWhiteEngineIndex: Integer = 0;
      ABlackEngineIndex: Integer = 0);
    procedure StartEngine(const AFileName: String; AUseCurrentParams: Boolean = False;
      AShowLaunchOptions: Boolean = False; const APreferredProtocol: String = '');
    procedure StartSecondEngine(const AFileName: String;
      AUseCurrentParams: Boolean = False; AShowLaunchOptions: Boolean = False;
      const APreferredProtocol: String = '');
    procedure SendEngineCommand(const ACommand: String);
    procedure SendSecondEngineCommand(const ACommand: String);
    procedure SetEngineState(AState: TEngineState);
    procedure SetSecondEngineState(AState: TEngineState);
    procedure SetEngineSlotState(AEngineIndex: Integer; AState: TEngineState);
    procedure SetGuiState(AState: TGuiState; const AReason: String);
    procedure BeginEngineSlotSearch(AEngineIndex: Integer;
      AMode: TEngineSearchMode; AState: TEngineState);
    procedure FinishEngineSlotSearch(AEngineIndex: Integer);
    procedure ResetEngineSlotRuntime(AEngineIndex: Integer);
    procedure UpdateEngineStateLabels;
    procedure UpdateRegisteredEngineId(const AFileName, AEngineId: String;
      const AProtocol: String = '');
    procedure UpdateRegisteredEngineProtocol(const AFileName,
      AProtocol: String);
    procedure SendPlayGameHumanTurnAnalyze;
    procedure ContinuePlayGameSearch;
    procedure SendDxpStartOrMoveToEngine(AEngineIndex: Integer;
      AMode: TEngineSearchMode);
    procedure SendGoAnalyzeToEngine(AMode: TEngineSearchMode = esmAnalyze);
    procedure SendGoAnalyzeToSecondEngine(AMode: TEngineSearchMode = esmAnalyze);
    procedure SendGoMctsToEngine;
    procedure SendGoThinkToEngine(AMode: TEngineSearchMode = esmAutoPlay);
    procedure SendGoThinkToSecondEngine;
    procedure RestartEngineAnalyze;
    procedure SendStopToEngine;
    procedure SendStopToSecondEngine;
    procedure SendStopToAllEngines;
    procedure SendPositionMenuItemClick(Sender: TObject);
    procedure SendPositionToEngine;
    procedure SavePdnMenuItemClick(Sender: TObject);
    procedure SavePdnOptionsDialogHide(Sender: TObject);
    procedure SaveEngineLogMenuItemClick(Sender: TObject);
    procedure SaveSecondEngineLogMenuItemClick(Sender: TObject);
    procedure AnalyzeMenuItemClick(Sender: TObject);
    procedure ShowTimestampsMenuItemClick(Sender: TObject);
    procedure SavePdnFile(const AFileName, AWhiteName, ABlackName,
      AResult: String; const AEvent: String = '?'; const ARound: String = '?';
      AAppend: Boolean = False);
    procedure SetTerminalResult;
    procedure StopButtonClick(Sender: TObject);
    procedure StopGameClocks;
    procedure ExecuteMoveFromList(AMoveIndex: Integer; AContinueEngine: Boolean);
    procedure ExecuteLegalMoveIndex(AMoveIndex: Integer; AContinueEngine: Boolean);
    procedure UpdateBoardLayout;
    procedure UpdateClockLabels;
    procedure UpdateGameClock;
    procedure UpdateHistoryList;
    procedure UpdateMovePanelWidth;
    procedure UpdateMoveList;
    procedure UpdateAnalyzePvList;
    procedure UnlockAnalyzePv;
    procedure UpdateEnginePopupMenuItems;
    procedure UpdateAnalyzeMenuItems;
    procedure UpdateAnalyzeBestMoveFromMoveText(const AMoveText: String);
    procedure UpdateAnalyzeBestMoveFromInfo(const ALine: String);
    procedure UpdateAnalyzePvFromMoveText(const APvText: String);
    procedure UpdateEngineEvalFromInfo(const ALine: String; AForce: Boolean = False);
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
  LCLIntf,
  Math,
  StrUtils,
  SysUtils;

const
  BoardSize = 10;
  LayoutMargin = 6;
  BoardMoveSplitterWidth = 6;
  EngineStateLabelWidth = 96;
  MovePanelBaseWidth = 500;
  LegalMovesPanelWidth = 140;
  LegalMovesGap = 4;
  EvalBarWidth = 18;
  EvalBarGap = 8;
  EvalBarDefaultMaxScore = 1000.0;
  BoardSideMarkerGap = 6;
  BoardSideMarkerWidth = 72;
  BoardMargin = 24;
  WoodSquareColor = TColor($00305E8B);
  AnalyzeBestSourceColor = TColor($0000A5FF);
  AnalyzeHintSourceColor = clRed;
  EngineTypeParamName = 'gui-engine-type';
  HubIdParamName = 'gui-hub-id';
  EngineIniFileParamName = 'gui-ini-file';
  HubLaunchArgumentParamName = 'gui-hub-launch-argument';
  OldHubLaunchArgumentParamName = 'hub-launch-argument';
  OldLaunchWithHubArgumentParamName = 'launch-with-hub-argument';
  DxpIdParamName = 'gui-dxp-id';
  DxpIpParamName = 'gui-dxp-ip';
  DxpSocketParamName = 'gui-dxp-socket';
  DxpLaunchArgumentsParamName = 'gui-dxp-launch-arguments';
  DxpRoleParamName = 'gui-dxp-role';
  DxpDefaultIp = '127.0.0.1';
  DxpDefaultSocket = '27531';
  SendStartingPositionParamName = 'gui-send-starting-position';
  OldSendStartingPositionParamName = 'send-starting-position';
  SingleCapturesIncludeCapturedSquareParamName =
    'gui-single-captures-include-captured-square';
  OldSingleCapturesIncludeCapturedSquareParamName =
    'single-captures-include-captured-square';
  AnalyzeSendsInfoParamName = 'gui-analyze-sends-info';
  OldAnalyzeSendsInfoParamName = 'gui-ponder-sends-info';
  EngineSupportsMctsParamName = 'gui-engine-supports-mcts';
  ScorePerspectiveParamName = 'gui-score-perspective';
  EvaluationDepthMinParamName = 'gui-evaluation-bar-depth-min';
  OldEvaluationDepthMinParamName = 'gui-evaluation-depth-min';
  EvaluationBarMaxParamName = 'gui-evaluation-bar-score-max';
  OldEvaluationBarMaxParamName = 'gui-evaluation-bar-max';

function EngineLogTimestamp: String; forward;
function CommandLineQuote(const AText: String): String; forward;
procedure EngineLaunchArguments(AEngine: TEngineSlot; AArgs: TStrings); forward;

constructor TTournamentDialog.Create(AOwner: TComponent;
  const AEnginesFileName: String);
var
  BodySplitter: TSplitter;
  ButtonPanel: TPanel;
  CrossTableLabel: TLabel;
  EngineSplitter: TSplitter;
  EnginesLabel: TLabel;
  MinutesLabel: TLabel;
  NameLabel: TLabel;
  PairingSectionPanel: TPanel;
  PairingLabel: TLabel;
  TopPanel: TPanel;
begin
  inherited Create(AOwner);
  FEnginesFileName := AEnginesFileName;
  FEngineFileNames := TStringList.Create;
  FEngineFileNames.NameValueSeparator := '=';
  FEngineProtocols := TStringList.Create;
  FEngineProtocols.NameValueSeparator := '=';
  FCurrentWhiteEngineIndex := 1;
  FCurrentBlackEngineIndex := 2;
  Caption := 'Tournament';
  Width := 760;
  Height := 520;
  Position := poDesigned;
  OnClose := @DialogClose;
  OnResize := @TournamentResize;

  TopPanel := TPanel.Create(Self);
  TopPanel.Parent := Self;
  TopPanel.Align := alTop;
  TopPanel.Height := 118;
  TopPanel.BevelOuter := bvNone;

  NameLabel := TLabel.Create(TopPanel);
  NameLabel.Parent := TopPanel;
  NameLabel.Caption := 'Name';
  NameLabel.SetBounds(10, 14, 56, 22);

  FNameEdit := TEdit.Create(TopPanel);
  FNameEdit.Parent := TopPanel;
  FNameEdit.Text := 'Tournament';
  FNameEdit.SetBounds(72, 10, 300, 26);
  FNameEdit.Anchors := [akLeft, akTop];

  FRoundRobinGroup := TRadioGroup.Create(TopPanel);
  FRoundRobinGroup.Parent := TopPanel;
  FRoundRobinGroup.Caption := 'Pairing';
  FRoundRobinGroup.Items.Add('Single round-robin');
  FRoundRobinGroup.Items.Add('Double round-robin');
  FRoundRobinGroup.ItemIndex := 0;
  FRoundRobinGroup.OnClick := @RoundRobinGroupClick;
  FRoundRobinGroup.SetBounds(72, 42, 250, 68);
  FPreviousRoundRobinIndex := FRoundRobinGroup.ItemIndex;
  FSuppressRoundRobinChange := False;

  MinutesLabel := TLabel.Create(TopPanel);
  MinutesLabel.Parent := TopPanel;
  MinutesLabel.Caption := 'Minutes';
  MinutesLabel.SetBounds(350, 62, 56, 22);

  FMinutesEdit := TSpinEdit.Create(TopPanel);
  FMinutesEdit.Parent := TopPanel;
  FMinutesEdit.MinValue := 1;
  FMinutesEdit.MaxValue := 10000;
  FMinutesEdit.Value := 5;
  FMinutesEdit.SetBounds(412, 58, 86, 26);
  FMinutesEdit.OnChange := @MinutesEditChange;
  FPreviousMinutesValue := FMinutesEdit.Value;
  FSuppressMinutesChange := False;

  ButtonPanel := TPanel.Create(Self);
  ButtonPanel.Parent := Self;
  ButtonPanel.Align := alTop;
  ButtonPanel.Height := 42;
  ButtonPanel.BevelOuter := bvNone;

  FLoadButton := TButton.Create(ButtonPanel);
  FLoadButton.Parent := ButtonPanel;
  FLoadButton.Caption := 'Open...';
  FLoadButton.SetBounds(10, 7, 86, 28);
  FLoadButton.OnClick := @LoadButtonClick;

  FSaveButton := TButton.Create(ButtonPanel);
  FSaveButton.Parent := ButtonPanel;
  FSaveButton.Caption := 'Save...';
  FSaveButton.SetBounds(104, 7, 86, 28);
  FSaveButton.OnClick := @SaveButtonClick;

  FStartButton := TButton.Create(ButtonPanel);
  FStartButton.Parent := ButtonPanel;
  FStartButton.Caption := 'Start';
  FStartButton.SetBounds(206, 7, 86, 28);
  FStartButton.OnClick := @StartButtonClick;

  FStopButton := TButton.Create(ButtonPanel);
  FStopButton.Parent := ButtonPanel;
  FStopButton.Caption := 'Stop';
  FStopButton.SetBounds(300, 7, 86, 28);
  FStopButton.OnClick := @StopButtonClick;

  FBodyPanel := TPanel.Create(Self);
  FBodyPanel.Parent := Self;
  FBodyPanel.Align := alClient;
  FBodyPanel.BevelOuter := bvNone;

  FCrossTableSectionPanel := TPanel.Create(FBodyPanel);
  FCrossTableSectionPanel.Parent := FBodyPanel;
  FCrossTableSectionPanel.Align := alTop;
  FCrossTableSectionPanel.Top := 0;
  FCrossTableSectionPanel.Height := 136;
  FCrossTableSectionPanel.BevelOuter := bvNone;

  CrossTableLabel := TLabel.Create(FCrossTableSectionPanel);
  CrossTableLabel.Parent := FCrossTableSectionPanel;
  CrossTableLabel.Align := alTop;
  CrossTableLabel.Height := 24;
  CrossTableLabel.Caption := 'Crosstable';
  CrossTableLabel.BorderSpacing.Left := 6;
  CrossTableLabel.Layout := tlCenter;

  FCrossTableGrid := TStringGrid.Create(FCrossTableSectionPanel);
  FCrossTableGrid.Parent := FCrossTableSectionPanel;
  FCrossTableGrid.Align := alClient;
  FCrossTableGrid.ColCount := 2;
  FCrossTableGrid.FixedCols := 0;
  FCrossTableGrid.FixedRows := 1;
  FCrossTableGrid.RowCount := 2;
  FCrossTableGrid.Options := FCrossTableGrid.Options - [goEditing] + [goColSizing, goRowSelect];
  FCrossTableGrid.OnDrawCell := @CrossTableDrawCell;
  FCrossTableGrid.Cells[0, 0] := 'Engine';
  FCrossTableGrid.Cells[1, 0] := 'Points';
  FCrossTableGrid.Cells[0, 1] := '';
  FCrossTableGrid.Cells[1, 1] := '0';
  FCrossTableGrid.ColWidths[0] := 580;
  FCrossTableGrid.ColWidths[1] := 80;

  BodySplitter := TSplitter.Create(FBodyPanel);
  BodySplitter.Parent := FBodyPanel;
  BodySplitter.Align := alTop;
  BodySplitter.Top := FCrossTableSectionPanel.Height + 1;
  BodySplitter.Height := 6;
  BodySplitter.ResizeAnchor := akTop;
  BodySplitter.MinSize := 48;

  FEnginePairingPanel := TPanel.Create(FBodyPanel);
  FEnginePairingPanel.Parent := FBodyPanel;
  FEnginePairingPanel.Align := alClient;
  FEnginePairingPanel.BevelOuter := bvNone;

  FEngineSectionPanel := TPanel.Create(FEnginePairingPanel);
  FEngineSectionPanel.Parent := FEnginePairingPanel;
  FEngineSectionPanel.Align := alTop;
  FEngineSectionPanel.Top := 0;
  FEngineSectionPanel.Height := 136;
  FEngineSectionPanel.BevelOuter := bvNone;

  EnginesLabel := TLabel.Create(FEngineSectionPanel);
  EnginesLabel.Parent := FEngineSectionPanel;
  EnginesLabel.Align := alTop;
  EnginesLabel.Height := 24;
  EnginesLabel.Caption := 'Engines';
  EnginesLabel.BorderSpacing.Left := 6;
  EnginesLabel.Layout := tlCenter;

  FEngineCheckList := TCheckListBox.Create(FEngineSectionPanel);
  FEngineCheckList.Parent := FEngineSectionPanel;
  FEngineCheckList.Align := alClient;
  PopulateEngineCheckList;

  EngineSplitter := TSplitter.Create(FEnginePairingPanel);
  EngineSplitter.Parent := FEnginePairingPanel;
  EngineSplitter.Align := alTop;
  EngineSplitter.Top := FEngineSectionPanel.Height + 1;
  EngineSplitter.Height := 6;
  EngineSplitter.ResizeAnchor := akTop;
  EngineSplitter.MinSize := 48;

  PairingSectionPanel := TPanel.Create(FEnginePairingPanel);
  PairingSectionPanel.Parent := FEnginePairingPanel;
  PairingSectionPanel.Align := alClient;
  PairingSectionPanel.BevelOuter := bvNone;

  PairingLabel := TLabel.Create(PairingSectionPanel);
  PairingLabel.Parent := PairingSectionPanel;
  PairingLabel.Align := alTop;
  PairingLabel.Height := 24;
  PairingLabel.Caption := 'Pairing';
  PairingLabel.BorderSpacing.Left := 6;
  PairingLabel.Layout := tlCenter;

  FGrid := TStringGrid.Create(PairingSectionPanel);
  FGrid.Parent := PairingSectionPanel;
  FGrid.Align := alClient;
  FGrid.ColCount := 4;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.RowCount := 2;
  FGrid.Options := FGrid.Options - [goEditing] + [goColSizing, goRowSelect];
  FGrid.Cells[0, 0] := 'Game';
  FGrid.Cells[1, 0] := 'White';
  FGrid.Cells[2, 0] := 'Black';
  FGrid.Cells[3, 0] := 'Result';
  FGrid.Cells[3, 1] := '*';
  FGrid.ColWidths[0] := 54;
  FGrid.ColWidths[1] := 280;
  FGrid.ColWidths[2] := 280;
  FGrid.ColWidths[3] := 90;
  FGrid.OnClick := @GridClick;

  FResultCombo := TComboBox.Create(FGrid);
  FResultCombo.Parent := FGrid;
  FResultCombo.Style := csDropDownList;
  FResultCombo.Items.Add('2-0');
  FResultCombo.Items.Add('1-1');
  FResultCombo.Items.Add('0-2');
  FResultCombo.Visible := False;
  FResultCombo.OnChange := @ResultComboChange;
  FResultCombo.OnExit := @ResultComboExit;

  FTournamentTimer := TTimer.Create(Self);
  FTournamentTimer.Enabled := False;
  FTournamentTimer.Interval := 250;
  FTournamentTimer.OnTimer := @TournamentTimerTick;
  UpdateCrossTable;
  AdjustSectionHeights;
end;

destructor TTournamentDialog.Destroy;
begin
  FreeAndNil(FEngineProtocols);
  FreeAndNil(FEngineFileNames);
  inherited Destroy;
end;

procedure TTournamentDialog.DialogClose(Sender: TObject;
  var CloseAction: TCloseAction);
var
  Answer: Integer;
begin
  if FDirty then
  begin
    Answer := MessageDlg('Tournament changed',
      'Tournament results have changed.' + LineEnding +
      'Save before closing?', mtConfirmation, [mbYes, mbNo, mbCancel], 0);
    case Answer of
      mrYes:
        if not SaveTournament then
        begin
          CloseAction := caNone;
          Exit;
        end;
      mrCancel:
      begin
        CloseAction := caNone;
        Exit;
      end;
    end;
  end;

  if FTournamentRunning then
    StopButtonClick(Self);
  if Owner is TMainWindow then
    TMainWindow(Owner).FTournamentDialog := nil;
  CloseAction := caFree;
end;

procedure TTournamentDialog.MarkDirty;
begin
  FDirty := True;
end;

procedure TTournamentDialog.AdjustSectionHeights;
const
  PairingMinHeight = 96;
  SectionMinHeight = 48;
  SplitterHeight = 6;
var
  BodyHeight: Integer;
  CrossHeight: Integer;
  EngineHeight: Integer;
  EnginePairingHeight: Integer;
  EngineRowHeight: Integer;
  MaxTopHeight: Integer;
  WantedCrossHeight: Integer;
  WantedEngineHeight: Integer;
  WantedTotalHeight: Integer;

  function GridContentHeight(AGrid: TStringGrid): Integer;
  var
    Row: Integer;
  begin
    Result := 0;
    if AGrid = nil then
      Exit;
    for Row := 0 to AGrid.RowCount - 1 do
      Result := Result + AGrid.RowHeights[Row];
  end;

begin
  if (FBodyPanel = nil) or (FCrossTableSectionPanel = nil) or
    (FEnginePairingPanel = nil) or (FEngineSectionPanel = nil) or
    (FCrossTableGrid = nil) or (FEngineCheckList = nil) then
    Exit;

  BodyHeight := FBodyPanel.ClientHeight;
  if BodyHeight <= 0 then
    Exit;

  WantedCrossHeight := 24 + GridContentHeight(FCrossTableGrid) + 10;
  if WantedCrossHeight < SectionMinHeight then
    WantedCrossHeight := SectionMinHeight;

  EngineRowHeight := FEngineCheckList.Canvas.TextHeight('Mg') + 6;
  if EngineRowHeight < 18 then
    EngineRowHeight := 18;
  WantedEngineHeight := 24 + (Max(1, FEngineCheckList.Items.Count) *
    EngineRowHeight) + 10;
  if WantedEngineHeight < SectionMinHeight then
    WantedEngineHeight := SectionMinHeight;

  MaxTopHeight := BodyHeight - PairingMinHeight - (2 * SplitterHeight);
  if MaxTopHeight < (2 * SectionMinHeight) then
    Exit;

  WantedTotalHeight := WantedCrossHeight + WantedEngineHeight;
  if WantedTotalHeight <= MaxTopHeight then
  begin
    CrossHeight := WantedCrossHeight;
    EngineHeight := WantedEngineHeight;
  end
  else
  begin
    CrossHeight := Round(MaxTopHeight * WantedCrossHeight /
      WantedTotalHeight);
    if CrossHeight < SectionMinHeight then
      CrossHeight := SectionMinHeight;
    if CrossHeight > MaxTopHeight - SectionMinHeight then
      CrossHeight := MaxTopHeight - SectionMinHeight;
    EngineHeight := MaxTopHeight - CrossHeight;
  end;

  FCrossTableSectionPanel.Height := CrossHeight;
  EnginePairingHeight := BodyHeight - CrossHeight - SplitterHeight;
  if EngineHeight > EnginePairingHeight - PairingMinHeight - SplitterHeight then
    EngineHeight := EnginePairingHeight - PairingMinHeight - SplitterHeight;
  if EngineHeight < SectionMinHeight then
    EngineHeight := SectionMinHeight;
  FEngineSectionPanel.Height := EngineHeight;
end;

procedure TTournamentDialog.TournamentResize(Sender: TObject);
begin
  AdjustSectionHeights;
end;

procedure TTournamentDialog.MinutesEditChange(Sender: TObject);
begin
  if FSuppressMinutesChange then
    Exit;
  if FMinutesEdit.Value = FPreviousMinutesValue then
    Exit;

  if (not GridIsEmpty) and
    (MessageDlg('Tournament',
    'Warning: you will lose all results if you change the time setting.' +
    LineEnding + 'Are you sure?', mtWarning, [mbYes, mbNo], 0) <> mrYes) then
  begin
    FSuppressMinutesChange := True;
    try
      FMinutesEdit.Value := FPreviousMinutesValue;
    finally
      FSuppressMinutesChange := False;
    end;
    Exit;
  end;

  FPreviousMinutesValue := FMinutesEdit.Value;
  if not GridIsEmpty then
  begin
    FGrid.RowCount := 2;
    FGrid.Cells[0, 1] := '';
    FGrid.Cells[1, 1] := '';
    FGrid.Cells[2, 1] := '';
    FGrid.Cells[3, 1] := '';
    UpdateCrossTable;
    MarkDirty;
  end;
end;

procedure TTournamentDialog.CrossTableDrawCell(Sender: TObject; ACol,
  ARow: Integer; ARect: TRect; AState: TGridDrawState);
var
  Grid: TStringGrid;
  TextRect: TRect;
begin
  Grid := TStringGrid(Sender);
  if (ARow > 0) and (ACol > 0) and (ACol = ARow) and
    (ACol < Grid.ColCount - 1) then
  begin
    Grid.Canvas.Brush.Color := clGray;
    Grid.Canvas.Font.Color := clWhite;
  end
  else if (ARow = 0) then
  begin
    Grid.Canvas.Brush.Color := clBtnFace;
    Grid.Canvas.Font.Color := clWindowText;
  end
  else
  begin
    Grid.Canvas.Brush.Color := clWindow;
    Grid.Canvas.Font.Color := clWindowText;
  end;

  Grid.Canvas.FillRect(ARect);
  TextRect := ARect;
  InflateRect(TextRect, -4, -2);
  Grid.Canvas.TextRect(TextRect, TextRect.Left,
    TextRect.Top + Max(0, (TextRect.Bottom - TextRect.Top -
    Grid.Canvas.TextHeight(Grid.Cells[ACol, ARow])) div 2),
    Grid.Cells[ACol, ARow]);
end;

procedure TTournamentDialog.AddPairing(const AWhite, ABlack: String);
var
  Row: Integer;
begin
  if (FGrid.RowCount = 2) and (FGrid.Cells[0, 1] = '') and
    (FGrid.Cells[1, 1] = '') and (FGrid.Cells[2, 1] = '') then
    Row := 1
  else
  begin
    Row := FGrid.RowCount;
    FGrid.RowCount := FGrid.RowCount + 1;
  end;

  FGrid.Cells[0, Row] := IntToStr(Row);
  FGrid.Cells[1, Row] := AWhite;
  FGrid.Cells[2, Row] := ABlack;
  FGrid.Cells[3, Row] := '*';
  UpdateCrossTable;
  MarkDirty;
end;

procedure TTournamentDialog.LoadEngineNames(AEngines: TStrings);
var
  Data: TJSONData;
  DisplayText: String;
  ExeText: String;
  EngineFileName: String;
  HubId: String;
  DxpId: String;
  IdText: String;
  I: Integer;
  Lines: TStringList;
  PathText: String;
  SortedEngines: TStringList;

  procedure AddTournamentEngine(const ADisplayText, AFileName,
    AProtocol: String);
  var
    BaseDisplayText: String;
    DirectoryText: String;
    Suffix: Integer;
  begin
    if ADisplayText = '' then
      Exit;

    BaseDisplayText := ADisplayText;
    DirectoryText := ExtractFileName(ExcludeTrailingPathDelimiter(
      ExtractFilePath(AFileName)));
    if DirectoryText = '' then
      DirectoryText := ExtractFileName(AFileName);
    if SortedEngines.IndexOf(BaseDisplayText) >= 0 then
      BaseDisplayText := ADisplayText + ' (' + DirectoryText + ')';
    Suffix := 2;
    while SortedEngines.IndexOf(BaseDisplayText) >= 0 do
    begin
      BaseDisplayText := ADisplayText + ' (' + DirectoryText + ' ' +
        IntToStr(Suffix) + ')';
      Inc(Suffix);
    end;

    SortedEngines.Add(BaseDisplayText);
    if FEngineFileNames <> nil then
      FEngineFileNames.Values[BaseDisplayText] := AFileName;
    if FEngineProtocols <> nil then
      FEngineProtocols.Values[BaseDisplayText] := AProtocol;
  end;
begin
  AEngines.Clear;
  if FEngineFileNames <> nil then
    FEngineFileNames.Clear;
  if FEngineProtocols <> nil then
    FEngineProtocols.Clear;
  if not FileExists(FEnginesFileName) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FEnginesFileName);
    Data := GetJSON(Lines.Text);
  finally
    Lines.Free;
  end;
  try
    if Data.JSONType <> jtArray then
      Exit;
    SortedEngines := TStringList.Create;
    try
      SortedEngines.Sorted := True;
      SortedEngines.Duplicates := dupAccept;
    for I := 0 to TJSONArray(Data).Count - 1 do
      if TJSONArray(Data).Items[I].JSONType = jtObject then
      begin
        ExeText := TJSONObject(TJSONArray(Data).Items[I]).Get('executable', '');
        PathText := TJSONObject(TJSONArray(Data).Items[I]).Get('path', '');
        EngineFileName := IncludeTrailingPathDelimiter(PathText) + ExeText;
        IdText := TJSONObject(TJSONArray(Data).Items[I]).Get('id', '');
        HubId := Trim(TJSONObject(TJSONArray(Data).Items[I]).Get('hub_id', ''));
        DxpId := Trim(TJSONObject(TJSONArray(Data).Items[I]).Get('dxp_id', ''));
        if (HubId = '') and
          SameText(TJSONObject(TJSONArray(Data).Items[I]).Get('protocol', ''), 'hub') then
          HubId := Trim(TJSONObject(TJSONArray(Data).Items[I]).Get('reported_id',
            IdText));
        if (DxpId = '') and
          SameText(TJSONObject(TJSONArray(Data).Items[I]).Get('protocol', ''), 'dxp') then
          DxpId := Trim(TJSONObject(TJSONArray(Data).Items[I]).Get('reported_id',
            IdText));

        if HubId <> '' then
        begin
          DisplayText := HubId + ' (Engine ' + IntToStr(I + 1) +
            ' Hub mode)';
          AddTournamentEngine(DisplayText, EngineFileName, 'hub');
        end;
        if DxpId <> '' then
        begin
          DisplayText := DxpId + ' (Engine ' + IntToStr(I + 1) +
            ' DXP mode)';
          AddTournamentEngine(DisplayText, EngineFileName, 'dxp');
        end;
        if (HubId = '') and (DxpId = '') then
        begin
          if IdText = '' then
            IdText := ChangeFileExt(ExeText, '');
          if IdText = '' then
            IdText := ExeText;
          AddTournamentEngine(IdText, EngineFileName,
            LowerCase(Trim(TJSONObject(TJSONArray(Data).Items[I]).Get('protocol', ''))));
        end;
      end;
      AEngines.Assign(SortedEngines);
    finally
      SortedEngines.Free;
    end;
  finally
    Data.Free;
  end;
end;

function TTournamentDialog.EngineProtocolForName(const AName: String): String;
begin
  Result := '';
  if (AName <> '') and (FEngineProtocols <> nil) then
    Result := LowerCase(Trim(FEngineProtocols.Values[AName]));
end;

function TTournamentDialog.EngineFileNameForName(const AName: String): String;
var
  Data: TJSONData;
  DisplayText: String;
  ExeText: String;
  IdText: String;
  I: Integer;
  Lines: TStringList;
  PathText: String;
begin
  Result := '';
  if AName = '' then
    Exit;
  if (FEngineFileNames <> nil) and (FEngineFileNames.Values[AName] <> '') then
    Exit(FEngineFileNames.Values[AName]);
  if not FileExists(FEnginesFileName) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FEnginesFileName);
    Data := GetJSON(Lines.Text);
  finally
    Lines.Free;
  end;
  try
    if Data.JSONType <> jtArray then
      Exit;
    for I := 0 to TJSONArray(Data).Count - 1 do
      if TJSONArray(Data).Items[I].JSONType = jtObject then
      begin
        ExeText := TJSONObject(TJSONArray(Data).Items[I]).Get('executable', '');
        IdText := TJSONObject(TJSONArray(Data).Items[I]).Get('id', '');
        DisplayText := ChangeFileExt(ExeText, '');
        if SameText(ExeText, AName) or SameText(ChangeFileExt(ExeText, ''), AName) or
          SameText(IdText, AName) or SameText(IdText + ' (' + ExeText + ')', AName) or
          SameText(DisplayText, AName) then
        begin
          PathText := TJSONObject(TJSONArray(Data).Items[I]).Get('path', '');
          Result := IncludeTrailingPathDelimiter(PathText) + ExeText;
          Exit;
        end;
      end;
  finally
    Data.Free;
  end;
end;

procedure TTournamentDialog.PopulateEngineCheckList;
var
  Engines: TStringList;
  I: Integer;
begin
  FEngineCheckList.Items.Clear;
  Engines := TStringList.Create;
  try
    LoadEngineNames(Engines);
    if Engines.Count = 0 then
    begin
      FEngineCheckList.Items.Add('(no registered engines)');
      FEngineCheckList.Checked[0] := False;
      Exit;
    end;
    for I := 0 to Engines.Count - 1 do
    begin
      FEngineCheckList.Items.Add(Engines[I]);
      FEngineCheckList.Checked[I] := True;
    end;
    AdjustSectionHeights;
  finally
    Engines.Free;
  end;
end;

procedure TTournamentDialog.LoadSelectedEngineNames(AEngines: TStrings);
var
  I: Integer;
begin
  AEngines.Clear;
  for I := 0 to FEngineCheckList.Items.Count - 1 do
    if FEngineCheckList.Checked[I] and
      (not AnsiStartsText('(', FEngineCheckList.Items[I])) then
      AEngines.Add(FEngineCheckList.Items[I]);
end;

procedure TTournamentDialog.UpdateCrossTable;
var
  BlackIndex: Integer;
  EngineNames: TStringList;
  I: Integer;
  Index: Integer;
  J: Integer;
  Matrix: array of array of String;
  Order: array of Integer;
  Points: array of Integer;
  ResultText: String;
  SB: array of Double;
  Temp: Integer;
  Wins: array of Integer;
  WhiteIndex: Integer;

  procedure EnsureEngine(const AName: String);
  begin
    if (AName = '') or AnsiStartsText('(', AName) then
      Exit;
    if EngineNames.IndexOf(AName) >= 0 then
      Exit;
    EngineNames.Add(AName);
    SetLength(Points, EngineNames.Count);
    SetLength(Wins, EngineNames.Count);
    SetLength(SB, EngineNames.Count);
  end;

  procedure AddPoints(const AName: String; APoints: Integer);
  begin
    Index := EngineNames.IndexOf(AName);
    if Index >= 0 then
      Inc(Points[Index], APoints);
  end;

  procedure AddWin(const AName: String);
  begin
    Index := EngineNames.IndexOf(AName);
    if Index >= 0 then
      Inc(Wins[Index]);
  end;

  procedure AddMarker(ARow, AOpponent: Integer; const AText: String);
  begin
    if (ARow < 0) or (AOpponent < 0) or (AText = '') then
      Exit;

    if Matrix[ARow, AOpponent] <> '' then
      Matrix[ARow, AOpponent] := Matrix[ARow, AOpponent] + '/' + AText
    else
      Matrix[ARow, AOpponent] := AText;
  end;

  function ComesBefore(AIndex, BIndex: Integer): Boolean;
  begin
    if Points[AIndex] <> Points[BIndex] then
      Exit(Points[AIndex] > Points[BIndex]);
    if Wins[AIndex] <> Wins[BIndex] then
      Exit(Wins[AIndex] > Wins[BIndex]);
    if Abs(SB[AIndex] - SB[BIndex]) > 0.0001 then
      Exit(SB[AIndex] > SB[BIndex]);
    Result := AnsiCompareText(EngineNames[AIndex], EngineNames[BIndex]) < 0;
  end;

  function FormatSB(AValue: Double): String;
  begin
    if Abs(AValue - Round(AValue)) < 0.0001 then
      Result := IntToStr(Round(AValue))
    else
      Result := FormatFloat('0.0', AValue);
  end;

  function CompactEngineHeader(const AName: String): String;
  const
    Marker = ' (Engine ';
  var
    IChar: Integer;
    NumberText: String;
    P: Integer;
  begin
    Result := Trim(AName);
    P := Pos(Marker, Result);
    if P <= 0 then
      Exit;

    NumberText := '';
    IChar := P + Length(Marker);
    while (IChar <= Length(Result)) and (Result[IChar] in ['0'..'9']) do
    begin
      NumberText := NumberText + Result[IChar];
      Inc(IChar);
    end;

    Result := Trim(Copy(Result, 1, P - 1));
    if NumberText <> '' then
      Result := Result + '#' + NumberText;
  end;

  procedure AutoSizeCrossTableColumns;
  const
    CellPadding = 18;
    MaxColumnWidth = 320;
    MinColumnWidth = 44;
  var
    Col: Integer;
    Row: Integer;
    TextWidth: Integer;
    Width: Integer;
  begin
    for Col := 0 to FCrossTableGrid.ColCount - 1 do
    begin
      Width := MinColumnWidth;
      for Row := 0 to FCrossTableGrid.RowCount - 1 do
      begin
        TextWidth := FCrossTableGrid.Canvas.TextWidth(
          FCrossTableGrid.Cells[Col, Row]) + CellPadding;
        if TextWidth > Width then
          Width := TextWidth;
      end;
      if Width > MaxColumnWidth then
        Width := MaxColumnWidth;
      FCrossTableGrid.ColWidths[Col] := Width;
    end;
  end;

begin
  if FCrossTableGrid = nil then
    Exit;

  EngineNames := TStringList.Create;
  try
    for I := 0 to FEngineCheckList.Items.Count - 1 do
      if FEngineCheckList.Checked[I] and
        (not AnsiStartsText('(', FEngineCheckList.Items[I])) then
        EnsureEngine(FEngineCheckList.Items[I]);

    for I := 1 to FGrid.RowCount - 1 do
    begin
      EnsureEngine(FGrid.Cells[1, I]);
      EnsureEngine(FGrid.Cells[2, I]);
    end;

    SetLength(Matrix, EngineNames.Count, EngineNames.Count);
    SetLength(Order, EngineNames.Count);
    for I := 0 to EngineNames.Count - 1 do
      Order[I] := I;

    for I := 1 to FGrid.RowCount - 1 do
    begin
      ResultText := FGrid.Cells[3, I];
      if (FGrid.Cells[1, I] = '') or (FGrid.Cells[2, I] = '') or
        (ResultText = '*') then
        Continue;

      if ResultText = '2-0' then
      begin
        AddPoints(FGrid.Cells[1, I], 2);
        AddWin(FGrid.Cells[1, I]);
      end
      else if ResultText = '1-1' then
      begin
        AddPoints(FGrid.Cells[1, I], 1);
        AddPoints(FGrid.Cells[2, I], 1);
      end
      else if ResultText = '0-2' then
      begin
        AddPoints(FGrid.Cells[2, I], 2);
        AddWin(FGrid.Cells[2, I]);
      end;
    end;

    for I := 1 to FGrid.RowCount - 1 do
    begin
      ResultText := FGrid.Cells[3, I];
      if (FGrid.Cells[1, I] = '') or (FGrid.Cells[2, I] = '') or
        (ResultText = '*') then
        Continue;

      WhiteIndex := EngineNames.IndexOf(FGrid.Cells[1, I]);
      BlackIndex := EngineNames.IndexOf(FGrid.Cells[2, I]);
      if (WhiteIndex < 0) or (BlackIndex < 0) then
        Continue;

      if ResultText = '2-0' then
      begin
        SB[WhiteIndex] := SB[WhiteIndex] + Points[BlackIndex];
        AddMarker(WhiteIndex, BlackIndex, '2W');
        AddMarker(BlackIndex, WhiteIndex, '0B');
      end
      else if ResultText = '1-1' then
      begin
        SB[WhiteIndex] := SB[WhiteIndex] + (Points[BlackIndex] / 2);
        SB[BlackIndex] := SB[BlackIndex] + (Points[WhiteIndex] / 2);
        AddMarker(WhiteIndex, BlackIndex, '1W');
        AddMarker(BlackIndex, WhiteIndex, '1B');
      end
      else if ResultText = '0-2' then
      begin
        SB[BlackIndex] := SB[BlackIndex] + Points[WhiteIndex];
        AddMarker(WhiteIndex, BlackIndex, '0W');
        AddMarker(BlackIndex, WhiteIndex, '2B');
      end;
    end;

    for I := 0 to High(Order) - 1 do
      for J := I + 1 to High(Order) do
        if not ComesBefore(Order[I], Order[J]) then
        begin
          Temp := Order[I];
          Order[I] := Order[J];
          Order[J] := Temp;
        end;

    FCrossTableGrid.ColCount := Max(4, EngineNames.Count + 4);
    FCrossTableGrid.RowCount := Max(2, EngineNames.Count + 1);
    for I := 0 to FCrossTableGrid.ColCount - 1 do
      for J := 0 to FCrossTableGrid.RowCount - 1 do
        FCrossTableGrid.Cells[I, J] := '';

    FCrossTableGrid.Cells[0, 0] := 'Engine';
    for I := 0 to EngineNames.Count - 1 do
    begin
      FCrossTableGrid.Cells[I + 1, 0] :=
        CompactEngineHeader(EngineNames[Order[I]]);
      FCrossTableGrid.Cells[0, I + 1] := EngineNames[Order[I]];
    end;
    FCrossTableGrid.Cells[EngineNames.Count + 1, 0] := 'Points';
    FCrossTableGrid.Cells[EngineNames.Count + 2, 0] := '#Wins';
    FCrossTableGrid.Cells[EngineNames.Count + 3, 0] := 'SB';

    if EngineNames.Count = 0 then
    begin
      FCrossTableGrid.Cells[0, 1] := '';
      FCrossTableGrid.Cells[1, 1] := '0';
    end;

    for I := 0 to EngineNames.Count - 1 do
    begin
      for J := 0 to EngineNames.Count - 1 do
        FCrossTableGrid.Cells[J + 1, I + 1] := Matrix[Order[I], Order[J]];
      FCrossTableGrid.Cells[EngineNames.Count + 1, I + 1] :=
        IntToStr(Points[Order[I]]);
      FCrossTableGrid.Cells[EngineNames.Count + 2, I + 1] :=
        IntToStr(Wins[Order[I]]);
      FCrossTableGrid.Cells[EngineNames.Count + 3, I + 1] :=
        FormatSB(SB[Order[I]]);
    end;

    AutoSizeCrossTableColumns;
    AdjustSectionHeights;
  finally
    EngineNames.Free;
  end;
end;

procedure TTournamentDialog.StartButtonClick(Sender: TObject);
var
  Engines: TStringList;
  I: Integer;
  J: Integer;
begin
  if FTournamentRunning then
    Exit;

  if GridIsEmpty then
  begin
    Engines := TStringList.Create;
    try
      LoadSelectedEngineNames(Engines);
      if Engines.Count < 2 then
      begin
        MessageDlg('Tournament', 'Select at least two engines for the tournament.',
          mtInformation, [mbOK], 0);
        Exit;
      end;

      FGrid.RowCount := 2;
      FGrid.Cells[0, 1] := '';
      FGrid.Cells[1, 1] := '';
      FGrid.Cells[2, 1] := '';
      FGrid.Cells[3, 1] := '';

      for I := 0 to Engines.Count - 2 do
        for J := I + 1 to Engines.Count - 1 do
        begin
          AddPairing(Engines[I], Engines[J]);
          if FRoundRobinGroup.ItemIndex = 1 then
            AddPairing(Engines[J], Engines[I]);
        end;
    finally
      Engines.Free;
    end;
  end;

  FTournamentRunning := StartNextTournamentGame;
  FTournamentTimer.Enabled := FTournamentRunning;
  if (Owner is TMainWindow) and FTournamentRunning then
    TMainWindow(Owner).SetGuiState(gsTournamentRunning, 'tournament started');
end;

procedure TTournamentDialog.StopButtonClick(Sender: TObject);
var
  Main: TMainWindow;
begin
  FTournamentRunning := False;
  if Owner is TMainWindow then
    TMainWindow(Owner).SetGuiState(gsStopping, 'tournament stop requested');
  FCurrentGameStarted := False;
  FCurrentTournamentRow := 0;
  FCurrentWhiteEngineIndex := 1;
  FCurrentBlackEngineIndex := 2;
  if FTournamentTimer <> nil then
    FTournamentTimer.Enabled := False;
  if Owner is TMainWindow then
  begin
    Main := TMainWindow(Owner);
    Main.StopButtonClick(Sender);
  end;
end;

function TTournamentDialog.StartNextTournamentGame: Boolean;
var
  BlackFileName: String;
  BlackLoadedIndex: Integer;
  BlackName: String;
  Main: TMainWindow;
  Row: Integer;
  WhiteProtocol: String;
  WhiteFileName: String;
  WhiteLoadedIndex: Integer;
  WhiteName: String;
  BlackProtocol: String;

  function SlotMatches(AIndex: Integer; const AName, AFileName: String): Boolean;
  begin
    Result := False;
    if (AIndex < Low(Main.FEngines)) or (AIndex > High(Main.FEngines)) then
      Exit;
    if (AIndex = 1) and (not Main.EngineIsRunning) then
      Exit;
    if (AIndex = 2) and (not Main.SecondEngineIsRunning) then
      Exit;
    Result := ((AFileName <> '') and
      SameFileName(Main.FEngines[AIndex].FileName, AFileName)) or
      SameText(Main.FEngines[AIndex].DisplayName, AName) or
      SameText(ChangeFileExt(ExtractFileName(Main.FEngines[AIndex].FileName), ''),
      AName) or SameText(AName, 'Engine' + IntToStr(AIndex)) or
      SameText(AName, 'Engine ' + IntToStr(AIndex));
  end;

  function LoadedSlotIndex(const AName, AFileName: String): Integer;
  begin
    if SlotMatches(1, AName, AFileName) then
      Exit(1);
    if SlotMatches(2, AName, AFileName) then
      Exit(2);
    Result := 0;
  end;

  function OtherSlot(AEngineIndex: Integer): Integer;
  begin
    if AEngineIndex = 1 then
      Result := 2
    else
      Result := 1;
  end;

  procedure LoadEngineIntoSlot(AEngineIndex: Integer; const AName,
    AFileName, AProtocol: String);
  var
    CandidateParams: TEngineParamArray;
    CandidateParamsFile: String;
    I: Integer;

    function ParamsMatchProtocol(const AParams: TEngineParamArray;
      const AProtocolText: String): Boolean;
    var
      P: Integer;
    begin
      Result := AProtocolText = '';
      for P := 0 to High(AParams) do
        if SameText(AParams[P].Name, EngineTypeParamName) then
          Exit(SameText(AParams[P].Value, AProtocolText));
    end;
  begin
    Main.FEngines[AEngineIndex].DisplayName := AName;
    Main.FEngines[AEngineIndex].ParamsFileName :=
      Main.EngineParamsFileNameForDisplayName(AName, AFileName);
    LoadParamsFromJson(Main.FEngines[AEngineIndex].ParamsFileName,
      Main.FEngines[AEngineIndex].Params);

    CandidateParamsFile := Main.EngineParamsFileNameForDisplayName(
      ChangeFileExt(ExtractFileName(AFileName), ''), AFileName);
    if (CandidateParamsFile <> Main.FEngines[AEngineIndex].ParamsFileName) and
      FileExists(CandidateParamsFile) then
    begin
      SetLength(CandidateParams, 0);
      LoadParamsFromJson(CandidateParamsFile, CandidateParams);
      if ParamsMatchProtocol(CandidateParams, AProtocol) then
      begin
        Main.FEngines[AEngineIndex].ParamsFileName := CandidateParamsFile;
        SetLength(Main.FEngines[AEngineIndex].Params, Length(CandidateParams));
        for I := 0 to High(CandidateParams) do
          Main.FEngines[AEngineIndex].Params[I] := CandidateParams[I];
      end;
    end;

    if SameText(AProtocol, 'dxp') then
      AddOrUpdateParam(Main.FEngines[AEngineIndex].Params,
        EngineTypeParamName, 'string', 'dxp', False)
    else if SameText(AProtocol, 'hub') then
      AddOrUpdateParam(Main.FEngines[AEngineIndex].Params,
        EngineTypeParamName, 'string', 'hub', False);
    if AEngineIndex = 2 then
      Main.StartSecondEngine(AFileName, True)
    else
      Main.StartEngine(AFileName, True);
  end;
begin
  Result := False;
  if not (Owner is TMainWindow) then
    Exit;

  Main := TMainWindow(Owner);

  for Row := 1 to FGrid.RowCount - 1 do
    if SameText(FGrid.Cells[3, Row], '*') then
    begin
      WhiteName := FGrid.Cells[1, Row];
      BlackName := FGrid.Cells[2, Row];
      WhiteFileName := EngineFileNameForName(WhiteName);
      BlackFileName := EngineFileNameForName(BlackName);
      WhiteProtocol := EngineProtocolForName(WhiteName);
      BlackProtocol := EngineProtocolForName(BlackName);
      WhiteLoadedIndex := LoadedSlotIndex(WhiteName, WhiteFileName);
      BlackLoadedIndex := LoadedSlotIndex(BlackName, BlackFileName);
      if (WhiteFileName = '') and (WhiteLoadedIndex <> 0) then
        WhiteFileName := Main.FEngines[WhiteLoadedIndex].FileName;
      if (BlackFileName = '') and (BlackLoadedIndex <> 0) then
        BlackFileName := Main.FEngines[BlackLoadedIndex].FileName;
      if (WhiteFileName = '') or (BlackFileName = '') then
      begin
        MessageDlg('Tournament',
          'Could not find engine executable for this pairing:' + LineEnding +
          'White: ' + WhiteName + LineEnding + 'Black: ' + BlackName,
          mtError,
          [mbOK], 0);
        Exit;
      end;

      FCurrentTournamentRow := Row;
      FCurrentGameStarted := False;

      Main.FGameResult := '*';

      WhiteLoadedIndex := LoadedSlotIndex(WhiteName, WhiteFileName);
      BlackLoadedIndex := LoadedSlotIndex(BlackName, BlackFileName);
      if (WhiteLoadedIndex <> 0) and (BlackLoadedIndex <> 0) and
        (WhiteLoadedIndex <> BlackLoadedIndex) then
      begin
        FCurrentWhiteEngineIndex := WhiteLoadedIndex;
        FCurrentBlackEngineIndex := BlackLoadedIndex;
        Result := True;
        Exit;
      end;

      if WhiteLoadedIndex <> 0 then
      begin
        FCurrentWhiteEngineIndex := WhiteLoadedIndex;
        FCurrentBlackEngineIndex := OtherSlot(WhiteLoadedIndex);
        LoadEngineIntoSlot(FCurrentBlackEngineIndex, BlackName, BlackFileName,
          BlackProtocol);
      end
      else if BlackLoadedIndex <> 0 then
      begin
        FCurrentBlackEngineIndex := BlackLoadedIndex;
        FCurrentWhiteEngineIndex := OtherSlot(BlackLoadedIndex);
        LoadEngineIntoSlot(FCurrentWhiteEngineIndex, WhiteName, WhiteFileName,
          WhiteProtocol);
      end
      else
      begin
        FCurrentWhiteEngineIndex := 1;
        FCurrentBlackEngineIndex := 2;
        LoadEngineIntoSlot(1, WhiteName, WhiteFileName, WhiteProtocol);
        LoadEngineIntoSlot(2, BlackName, BlackFileName, BlackProtocol);
      end;

      Result := True;
      Exit;
    end;
end;

procedure TTournamentDialog.TournamentTimerTick(Sender: TObject);
var
  Main: TMainWindow;
begin
  if not FTournamentRunning then
    Exit;
  if not (Owner is TMainWindow) then
    Exit;

  Main := TMainWindow(Owner);

  if not FCurrentGameStarted then
  begin
    if Main.EngineIsRunning and Main.SecondEngineIsRunning and
      Main.FEngines[1].Ready and Main.FEngines[2].Ready then
    begin
      FCurrentGameStarted := True;
      Main.StartPlayGameFromOptions(True, True,
        Main.FEngines[FCurrentWhiteEngineIndex].DisplayName,
        Main.FEngines[FCurrentBlackEngineIndex].DisplayName,
        FMinutesEdit.Value, False, FCurrentWhiteEngineIndex,
        FCurrentBlackEngineIndex);
    end;
    Exit;
  end;

  if (not Main.FPlayGameActive) and (Main.FGameResult <> '*') then
  begin
    if (FCurrentTournamentRow > 0) and
      (FCurrentTournamentRow < FGrid.RowCount) then
    begin
      FGrid.Cells[3, FCurrentTournamentRow] := Main.FGameResult;
      UpdateCrossTable;
      MarkDirty;
      SaveTournamentGamePdn(StrToIntDef(FGrid.Cells[0, FCurrentTournamentRow],
        FCurrentTournamentRow));
    end;

    FCurrentGameStarted := False;
    FCurrentTournamentRow := 0;

    FTournamentRunning := StartNextTournamentGame;
    FTournamentTimer.Enabled := FTournamentRunning;
  end;
end;

procedure TTournamentDialog.GridClick(Sender: TObject);
var
  CellRect: TRect;
begin
  if (FGrid.Row <= 0) or (FGrid.Col <> 3) then
  begin
    FResultCombo.Visible := False;
    Exit;
  end;

  CellRect := FGrid.CellRect(3, FGrid.Row);
  FResultCombo.SetBounds(CellRect.Left, CellRect.Top,
    CellRect.Right - CellRect.Left, CellRect.Bottom - CellRect.Top);
  FResultCombo.ItemIndex := FResultCombo.Items.IndexOf(FGrid.Cells[3, FGrid.Row]);
  FResultCombo.Visible := True;
  FResultCombo.BringToFront;
  FResultCombo.SetFocus;
  FResultCombo.DroppedDown := True;
end;

procedure TTournamentDialog.ResultComboChange(Sender: TObject);
begin
  if (FGrid.Row > 0) and (FGrid.Col = 3) and
    (FResultCombo.ItemIndex >= 0) and
    (FGrid.Cells[3, FGrid.Row] <> FResultCombo.Text) then
  begin
    FGrid.Cells[3, FGrid.Row] := FResultCombo.Text;
    UpdateCrossTable;
    MarkDirty;
  end;
end;

procedure TTournamentDialog.ResultComboExit(Sender: TObject);
begin
  FResultCombo.Visible := False;
end;

procedure TTournamentDialog.RoundRobinGroupClick(Sender: TObject);
begin
  if FSuppressRoundRobinChange then
    Exit;
  if FRoundRobinGroup.ItemIndex = FPreviousRoundRobinIndex then
    Exit;

  if (not GridIsEmpty) and
    (MessageDlg('Tournament',
    'Warning: you will lose all results if you change tournament type.' +
    LineEnding + 'Are you sure?', mtWarning, [mbYes, mbNo], 0) <> mrYes) then
  begin
    FSuppressRoundRobinChange := True;
    try
      FRoundRobinGroup.ItemIndex := FPreviousRoundRobinIndex;
    finally
      FSuppressRoundRobinChange := False;
    end;
    Exit;
  end;

  FPreviousRoundRobinIndex := FRoundRobinGroup.ItemIndex;
  if not GridIsEmpty then
  begin
    FGrid.RowCount := 2;
    FGrid.Cells[0, 1] := '';
    FGrid.Cells[1, 1] := '';
    FGrid.Cells[2, 1] := '';
    FGrid.Cells[3, 1] := '';
    UpdateCrossTable;
    MarkDirty;
  end;
end;

function TTournamentDialog.GridIsEmpty: Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 1 to FGrid.RowCount - 1 do
    if (FGrid.Cells[1, I] <> '') or (FGrid.Cells[2, I] <> '') then
    begin
      Result := False;
      Exit;
    end;
end;

procedure TTournamentDialog.SaveButtonClick(Sender: TObject);
begin
  SaveTournament;
end;

procedure TTournamentDialog.SaveTournamentGamePdn(AGameNumber: Integer);
var
  BaseDir: String;
  FileName: String;
  Main: TMainWindow;
  TournamentName: String;

  function SafeFileName(const AText: String): String;
  const
    InvalidChars = ['\', '/', ':', '*', '?', '"', '<', '>', '|'];
  var
    J: Integer;
  begin
    Result := Trim(AText);
    for J := 1 to Length(Result) do
      if Result[J] in InvalidChars then
        Result[J] := '_';
    if Result = '' then
      Result := 'Tournament';
  end;

begin
  if not (Owner is TMainWindow) then
    Exit;

  Main := TMainWindow(Owner);
  TournamentName := SafeFileName(FNameEdit.Text);
  if FFileName <> '' then
    BaseDir := ExtractFilePath(FFileName)
  else
    BaseDir := GetCurrentDir;

  FileName := IncludeTrailingPathDelimiter(BaseDir) + TournamentName + '.pdn';
  Main.SavePdnFile(FileName, Main.FGameWhiteName, Main.FGameBlackName,
    Main.FGameResult, Trim(FNameEdit.Text), IntToStr(AGameNumber), True);
end;

function TTournamentDialog.SaveTournament: Boolean;
var
  Data: TJSONObject;
  Games: TJSONArray;
  Game: TJSONObject;
  I: Integer;
  Lines: TStringList;
  SaveDialog: TSaveDialog;
  SelectedEngines: TJSONArray;
begin
  Result := False;
  SaveDialog := TSaveDialog.Create(Self);
  try
    SaveDialog.Title := 'Save tournament';
    SaveDialog.Filter := 'Tournament files (*.json)|*.json|All files (*.*)|*.*';
    SaveDialog.DefaultExt := 'json';
    if FFileName <> '' then
      SaveDialog.FileName := FFileName
    else if Trim(FNameEdit.Text) <> '' then
      SaveDialog.FileName := Trim(FNameEdit.Text) + '.json'
    else
      SaveDialog.FileName := 'Tournament.json';
    SaveDialog.Options := SaveDialog.Options + [ofOverwritePrompt];
    if not SaveDialog.Execute then
      Exit;

    Data := TJSONObject.Create;
    try
      Data.Add('name', FNameEdit.Text);
      Data.Add('minutes', FMinutesEdit.Value);
      if FRoundRobinGroup.ItemIndex = 1 then
        Data.Add('type', 'double-round-robin')
      else
        Data.Add('type', 'single-round-robin');

      SelectedEngines := TJSONArray.Create;
      Data.Add('engines', SelectedEngines);
      for I := 0 to FEngineCheckList.Items.Count - 1 do
        if FEngineCheckList.Checked[I] and
          (not AnsiStartsText('(', FEngineCheckList.Items[I])) then
          SelectedEngines.Add(FEngineCheckList.Items[I]);

      Games := TJSONArray.Create;
      Data.Add('games', Games);
      for I := 1 to FGrid.RowCount - 1 do
        if (FGrid.Cells[1, I] <> '') or (FGrid.Cells[2, I] <> '') then
        begin
          Game := TJSONObject.Create;
          Game.Add('number', StrToIntDef(FGrid.Cells[0, I], I));
          Game.Add('white', FGrid.Cells[1, I]);
          Game.Add('black', FGrid.Cells[2, I]);
          Game.Add('result', FGrid.Cells[3, I]);
          Games.Add(Game);
        end;

      Lines := TStringList.Create;
      try
        Lines.Text := Data.FormatJSON([], 2) + LineEnding;
        Lines.SaveToFile(SaveDialog.FileName);
        FFileName := SaveDialog.FileName;
        FDirty := False;
        Result := True;
      finally
        Lines.Free;
      end;
    finally
      Data.Free;
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TTournamentDialog.LoadButtonClick(Sender: TObject);
var
  Data: TJSONData;
  EngineName: String;
  Engines: TJSONData;
  Games: TJSONArray;
  I: Integer;
  J: Integer;
  Lines: TStringList;
  OpenDialog: TOpenDialog;
begin
  OpenDialog := TOpenDialog.Create(Self);
  try
    OpenDialog.Title := 'Load tournament';
    OpenDialog.Filter := 'Tournament files (*.json)|*.json|All files (*.*)|*.*';
    OpenDialog.Options := OpenDialog.Options + [ofFileMustExist];
    if not OpenDialog.Execute then
      Exit;

    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(OpenDialog.FileName);
      Data := GetJSON(Lines.Text);
    finally
      Lines.Free;
    end;
    try
      if Data.JSONType <> jtObject then
        Exit;

      FNameEdit.Text := TJSONObject(Data).Get('name', 'Tournament');
      FSuppressMinutesChange := True;
      try
        FMinutesEdit.Value := TJSONObject(Data).Get('minutes', 5);
        FPreviousMinutesValue := FMinutesEdit.Value;
      finally
        FSuppressMinutesChange := False;
      end;
      FSuppressRoundRobinChange := True;
      try
        if TJSONObject(Data).Get('type', 'single-round-robin') =
          'double-round-robin' then
          FRoundRobinGroup.ItemIndex := 1
        else
          FRoundRobinGroup.ItemIndex := 0;
        FPreviousRoundRobinIndex := FRoundRobinGroup.ItemIndex;
      finally
        FSuppressRoundRobinChange := False;
      end;

      Engines := TJSONObject(Data).Find('engines');
      if (Engines <> nil) and (Engines.JSONType = jtArray) then
      begin
        for I := 0 to FEngineCheckList.Items.Count - 1 do
          if not AnsiStartsText('(', FEngineCheckList.Items[I]) then
            FEngineCheckList.Checked[I] := False;
        for I := 0 to TJSONArray(Engines).Count - 1 do
        begin
          EngineName := TJSONArray(Engines).Strings[I];
          for J := 0 to FEngineCheckList.Items.Count - 1 do
            if SameText(FEngineCheckList.Items[J], EngineName) then
            begin
              FEngineCheckList.Checked[J] := True;
              Break;
            end;
        end;
      end;

      FGrid.RowCount := 2;
      FGrid.Cells[0, 1] := '';
      FGrid.Cells[1, 1] := '';
      FGrid.Cells[2, 1] := '';
      FGrid.Cells[3, 1] := '';
      if TJSONObject(Data).Find('games') = nil then
        Exit;
      if TJSONObject(Data).Find('games').JSONType <> jtArray then
        Exit;

      Games := TJSONArray(TJSONObject(Data).Find('games'));
      for I := 0 to Games.Count - 1 do
        if Games.Items[I].JSONType = jtObject then
        begin
          AddPairing(TJSONObject(Games.Items[I]).Get('white', ''),
            TJSONObject(Games.Items[I]).Get('black', ''));
          FGrid.Cells[0, FGrid.RowCount - 1] :=
            IntToStr(TJSONObject(Games.Items[I]).Get('number',
            FGrid.RowCount - 1));
          FGrid.Cells[3, FGrid.RowCount - 1] :=
            TJSONObject(Games.Items[I]).Get('result', '*');
        end;
      UpdateCrossTable;
      FFileName := OpenDialog.FileName;
      FDirty := False;
    finally
      Data.Free;
    end;
  finally
    OpenDialog.Free;
  end;
end;

constructor TEngineSlot.Create(AIndex: Integer);
begin
  inherited Create;
  Index := AIndex;
  if AIndex = 1 then
    DisplayName := 'Engine'
  else
    DisplayName := 'Engine ' + IntToStr(AIndex);
  Protocol := epHub;
  HubId := 'Hub' + IntToStr(AIndex);
  IniFileName := '';
  HubLaunchArgument := '';
  DxpId := 'DXP' + IntToStr(AIndex);
  DxpIpAddress := DxpDefaultIp;
  DxpSocketNumber := DxpDefaultSocket;
  DxpLaunchArguments := '';
  DxpRole := edrListener;
  DxpGameState := dgsIdle;
  DxpGameEndSent := False;
  SearchMode := esmIdle;
  State := esIdle;
end;

procedure TEngineSlot.BeginSearch(AMode: TEngineSearchMode;
  AState: TEngineState);
begin
  SearchMode := AMode;
  State := AState;
  IgnoreNextDoneMove := False;
end;

procedure TEngineSlot.FinishSearch;
begin
  SearchMode := esmIdle;
  State := esIdle;
  IgnoreNextDoneMove := False;
end;

procedure TEngineSlot.ResetRuntimeState;
begin
  Ready := False;
  SearchMode := esmIdle;
  State := esIdle;
  IgnoreNextDoneMove := False;
  PendingThinkStart := False;
  TextBuffer := '';
  WaitingForInit := False;
  FirstReadSeen := False;
  DxpGameState := dgsIdle;
  DxpGameEndSent := False;
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

constructor TEngineDxpConnectionThread.Create(AOwner: TMainWindow;
  AEngineIndex: Integer; const AIpAddress: String; APort: Word;
  ARole: TEngineDxpRole);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FEngineIndex := AEngineIndex;
  FIpAddress := AIpAddress;
  FPort := APort;
  FRole := ARole;
  FServer := nil;
  FSocket := nil;
  FListening := False;
  FIncomingMessage := '';
  FErrorMessage := '';
  Start;
end;

destructor TEngineDxpConnectionThread.Destroy;
begin
  StopConnection;
  inherited Destroy;
end;

procedure TEngineDxpConnectionThread.ServerConnect(Sender: TObject;
  Data: TSocketStream);
begin
  FSocket := Data;
  if FServer <> nil then
    FServer.StopAccepting(False);
end;

procedure TEngineDxpConnectionThread.DeliverIncomingMessage;
begin
  if (FOwner = nil) or Terminated then
    Exit;
  FOwner.ProcessDxpMessage(FEngineIndex, FIncomingMessage);
end;

procedure TEngineDxpConnectionThread.NotifyConnected;
begin
  if (FOwner = nil) or Terminated then
    Exit;

  if (FEngineIndex >= Low(FOwner.FEngines)) and
    (FEngineIndex <= High(FOwner.FEngines)) then
  begin
    FOwner.FEngines[FEngineIndex].DxpSocket := FSocket;
    FOwner.FEngines[FEngineIndex].Ready := True;
  end;

  if FEngineIndex = 2 then
  begin
    if FRole = edrClient then
      FOwner.AppendEngine2Log('[Connected to DXP socket peer]' + LineEnding)
    else
      FOwner.AppendEngine2Log('[Connected to DXP socket listener]' + LineEnding);
  end
  else
  begin
    if FRole = edrClient then
      FOwner.AppendEngineLog('[Connected to DXP socket peer]' + LineEnding)
    else
      FOwner.AppendEngineLog('[Connected to DXP socket listener]' + LineEnding);
  end;
end;

procedure TEngineDxpConnectionThread.NotifyError;
begin
  if (FOwner = nil) or Terminated then
    Exit;
  if FEngineIndex = 2 then
    FOwner.AppendEngine2Log('[DXP connection error: ' + FErrorMessage + ']' +
      LineEnding)
  else
    FOwner.AppendEngineLog('[DXP connection error: ' + FErrorMessage + ']' +
      LineEnding);
end;

procedure TEngineDxpConnectionThread.StopConnection;
begin
  Terminate;
  if FServer <> nil then
    FServer.StopAccepting(True);
end;

procedure TEngineDxpConnectionThread.ReadIncomingMessages;
var
  BytesRead: Longint;
  Ch: Char;
  MessageText: String;
begin
  if FSocket = nil then
    Exit;

  try
    FSocket.IOTimeout := 250;
  except
    on E: Exception do
      ;
  end;

  MessageText := '';
  while not Terminated do
  begin
    Ch := #0;
    try
      BytesRead := FSocket.Read(Ch, 1);
    except
      on E: Exception do
      begin
        if Terminated then
          Break;
        Sleep(10);
        Continue;
      end;
    end;
    if BytesRead = 0 then
      Break;
    if BytesRead < 0 then
    begin
      Sleep(10);
      Continue;
    end;

    if Ch = #0 then
    begin
      FIncomingMessage := MessageText;
      MessageText := '';
      Synchronize(@DeliverIncomingMessage);
    end
    else
      MessageText += Ch;
  end;
end;

procedure TEngineDxpConnectionThread.Execute;
var
  Attempt: Integer;
  Connected: Boolean;
  Socket: TInetSocket;
begin
  try
    if FRole = edrClient then
    begin
      FServer := TInetServer.Create('0.0.0.0', FPort);
      try
        FServer.ReuseAddress := True;
        FServer.MaxConnections := 1;
        FServer.OnConnect := @ServerConnect;
        FServer.Listen;
        FListening := True;
        FServer.StartAccepting;
      finally
        FreeAndNil(FServer);
      end;
      if not Terminated then
      begin
        if FSocket <> nil then
          Synchronize(@NotifyConnected)
        else
        begin
          FErrorMessage := 'DXP listener stopped before accepting a connection';
          Synchronize(@NotifyError);
        end;
      end;
    end
    else
    begin
      Connected := False;
      for Attempt := 1 to 30 do
      begin
        if Terminated then
          Exit;
        try
          Socket := TInetSocket.Create(FIpAddress, FPort, 1000);
          try
            Socket.Connect;
            FSocket := Socket;
            Socket := nil;
            Connected := True;
            Break;
          finally
            Socket.Free;
          end;
        except
          on E: Exception do
          begin
            FErrorMessage := E.Message;
            Sleep(250);
          end;
        end;
      end;
      if Terminated then
        Exit;
      if Connected then
        Synchronize(@NotifyConnected)
      else
        Synchronize(@NotifyError);
    end;
    if (not Terminated) and (FSocket <> nil) then
      ReadIncomingMessages;
  except
    on E: Exception do
    begin
      FErrorMessage := E.Message;
      if not Terminated then
        Synchronize(@NotifyError);
    end;
  end;
end;

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
  OnShow := @FormShow;
  FBoardFlipped := False;
  FGuiState := gsIdle;
  FEngineEvalScoreWhite := 0.0;
  FEvalBarRect := Types.Rect(0, 0, 0, 0);
  FLastEvalBarWhitePixels := -1;
  FLastBoardLayoutHeight := -1;
  FLastBoardLayoutLegalWidth := -1;
  FLastBoardLayoutWidth := -1;
  FLastClientLayoutHeight := -1;
  FLastClientLayoutWidth := -1;
  FShuttingDown := False;
  FSideToMove := sideWhite;
  FEngines[1].FileName := '';
  FEngines[2].FileName := '';
  FEngines[2].IgnoreNextDoneMove := False;
  FEngineAnalyzeAutoDisabled := False;
  FEngineAnalyzeEnabled := True;
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
  UpdateBoardLayout;
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
  FAnalyzeBestSourceSquare := 0;
  FAnalyzeHintSourceSquare := 0;
  FAnalyzeHintMove := '';
  SetLength(FAnalyzePvMoves, 0);
  FAnalyzePvHasBase := False;
  FAnalyzePvLocked := False;
  FAnalyzePvBrowsePly := 0;
  SetLength(FAnalyzePvMoveStarts, 0);
  SetLength(FAnalyzePvMoveLengths, 0);
end;

procedure TMainWindow.SetupMoveList;
var
  HistoryLabel: TLabel;
  HistoryMetaPanel: TPanel;
  HistoryPanel: TPanel;
  FenPanel: TPanel;
  PvPanel: TPanel;
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
  FMovePanel.Constraints.MinWidth := 400;
  FMovePanel.BevelOuter := bvNone;
  FMovePanel.BorderSpacing.Right := LayoutMargin;

  FLegalMovesPanel := TPanel.Create(FBoardPanel);
  FLegalMovesPanel.Parent := FBoardPanel;
  FLegalMovesPanel.Align := alNone;
  FLegalMovesPanel.Width := LegalMovesPanelWidth;
  FLegalMovesPanel.Constraints.MinWidth := 105;
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

  FHistoryEvalPaintBox := TPaintBox.Create(HistoryPanel);
  FHistoryEvalPaintBox.Parent := HistoryPanel;
  FHistoryEvalPaintBox.Align := alBottom;
  FHistoryEvalPaintBox.Height := 76;
  FHistoryEvalPaintBox.BorderSpacing.Top := 4;
  FHistoryEvalPaintBox.OnPaint := @HistoryEvalPaintBoxPaint;

  PvPanel := TPanel.Create(HistoryPanel);
  PvPanel.Parent := HistoryPanel;
  PvPanel.Align := alBottom;
  PvPanel.Height := 96;
  PvPanel.BevelOuter := bvNone;
  PvPanel.BorderSpacing.Left := 8;
  PvPanel.BorderSpacing.Right := 8;
  PvPanel.BorderSpacing.Top := 2;
  PvPanel.BorderSpacing.Bottom := 4;

  FHistoryPvMiniBoardPanel := TPanel.Create(PvPanel);
  FHistoryPvMiniBoardPanel.Parent := PvPanel;
  FHistoryPvMiniBoardPanel.Align := alRight;
  FHistoryPvMiniBoardPanel.Width := 96;
  FHistoryPvMiniBoardPanel.BevelOuter := bvLowered;
  FHistoryPvMiniBoardPanel.Caption := '';

  FAnalysisBoardPopupMenu := TPopupMenu.Create(Self);
  FShowAnalysisBoardMenuItem := TMenuItem.Create(FAnalysisBoardPopupMenu);
  FShowAnalysisBoardMenuItem.Caption := 'Show analysis board';
  FShowAnalysisBoardMenuItem.OnClick := @ShowAnalysisBoardMenuItemClick;
  FAnalysisBoardPopupMenu.Items.Add(FShowAnalysisBoardMenuItem);
  FHistoryPvMiniBoardPanel.PopupMenu := FAnalysisBoardPopupMenu;

  FHistoryPvMiniBoardPaintBox := TPaintBox.Create(FHistoryPvMiniBoardPanel);
  FHistoryPvMiniBoardPaintBox.Parent := FHistoryPvMiniBoardPanel;
  FHistoryPvMiniBoardPaintBox.Align := alClient;
  FHistoryPvMiniBoardPaintBox.BorderSpacing.Around := 3;
  FHistoryPvMiniBoardPaintBox.OnPaint := @HistoryPvMiniBoardPaintBoxPaint;
  FHistoryPvMiniBoardPaintBox.PopupMenu := FAnalysisBoardPopupMenu;

  FPvMemo := TMemo.Create(PvPanel);
  FPvMemo.Parent := PvPanel;
  FPvMemo.Align := alClient;
  FPvMemo.BorderSpacing.Left := 0;
  FPvMemo.BorderSpacing.Right := 6;
  FPvMemo.ReadOnly := True;
  FPvMemo.ScrollBars := ssVertical;
  FPvMemo.WordWrap := True;
  FPvMemo.TabStop := True;
  FPvMemo.OnClick := @AnalyzePvMemoClick;
  FPvMemo.OnKeyDown := @AnalyzePvMemoKeyDown;
  FPvMemo.OnKeyUp := @AnalyzePvMemoKeyUp;
  FPvMemo.Lines.Add('No PV');

  FHistoryPvLabel := TLabel.Create(HistoryPanel);
  FHistoryPvLabel.Parent := HistoryPanel;
  FHistoryPvLabel.Align := alBottom;
  FHistoryPvLabel.Caption := 'Score history';
  FHistoryPvLabel.BorderSpacing.Left := 8;
  FHistoryPvLabel.BorderSpacing.Right := 8;
  FHistoryPvLabel.BorderSpacing.Bottom := 2;

  FHistoryMemo := TMemo.Create(Self);
  FHistoryMemo.Parent := HistoryPanel;
  FHistoryMemo.Align := alClient;
  FHistoryMemo.BorderSpacing.Left := 8;
  FHistoryMemo.BorderSpacing.Right := 8;
  FHistoryMemo.ReadOnly := True;
  FHistoryMemo.ScrollBars := ssVertical;
  FHistoryMemo.WordWrap := True;
  FHistoryMemo.OnClick := @HistoryMemoClick;
  FHistoryMemo.OnKeyDown := @HistoryMemoKeyDown;
end;

procedure TMainWindow.FormResize(Sender: TObject);
begin
  if (FLastClientLayoutWidth = ClientWidth) and
    (FLastClientLayoutHeight = ClientHeight) then
    Exit;

  FLastClientLayoutWidth := ClientWidth;
  FLastClientLayoutHeight := ClientHeight;
  UpdateMovePanelWidth;
  UpdateBoardLayout;
  InvalidateBoard;
  Application.QueueAsyncCall(@RefreshButtonToolbar, 0);
end;

procedure TMainWindow.FormShow(Sender: TObject);
begin
  Application.QueueAsyncCall(@RefreshInitialLayout, 0);
end;

procedure TMainWindow.RefreshInitialLayout(Data: PtrInt);
begin
  FLastClientLayoutWidth := -1;
  FLastClientLayoutHeight := -1;
  FLastBoardLayoutWidth := -1;
  FLastBoardLayoutHeight := -1;
  FLastBoardLayoutLegalWidth := -1;
  UpdateMovePanelWidth;
  UpdateBoardLayout;
  Invalidate;
  InvalidateBoard;
  if FHistoryEvalPaintBox <> nil then
    FHistoryEvalPaintBox.Invalidate;
  if FHistoryPvMiniBoardPaintBox <> nil then
    FHistoryPvMiniBoardPaintBox.Invalidate;
  Application.QueueAsyncCall(@RefreshButtonToolbar, 0);
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

procedure TMainWindow.UpdateBoardLayout;
var
  BoardArea: TRect;
  BoardPixels: Integer;
  EvalGap: Integer;
  EvalWidth: Integer;
  LegalGap: Integer;
  LegalLeft: Integer;
  LegalWidth: Integer;
  LeftPos: Integer;
  LayoutHeight: Integer;
  LayoutWidth: Integer;
  OffsetX: Integer;
  OffsetY: Integer;
  SideGap: Integer;
  SideWidth: Integer;
  TopPos: Integer;
  UnitLeft: Integer;
begin
  if FBoardPaintBox <> nil then
    BoardArea := FBoardPaintBox.ClientRect
  else if FBoardPanel <> nil then
    BoardArea := FBoardPanel.ClientRect
  else
    BoardArea := ClientRect;

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
  EvalGap := EvalBarGap;
  EvalWidth := EvalBarWidth;
  LegalWidth := LegalMovesPanelWidth;
  if FLegalMovesPanel <> nil then
    LegalWidth := FLegalMovesPanel.Width;
  SideGap := BoardSideMarkerGap;
  SideWidth := BoardSideMarkerWidth;
  LayoutWidth := BoardArea.Right - BoardArea.Left;
  LayoutHeight := BoardArea.Bottom - BoardArea.Top;

  if (FBoardRect.Right > FBoardRect.Left) and
    (FLastBoardLayoutWidth = LayoutWidth) and
    (FLastBoardLayoutHeight = LayoutHeight) and
    (FLastBoardLayoutLegalWidth = LegalWidth) then
    Exit;

  FLastBoardLayoutWidth := LayoutWidth;
  FLastBoardLayoutHeight := LayoutHeight;
  FLastBoardLayoutLegalWidth := LegalWidth;

  BoardPixels := Min((BoardArea.Right - BoardArea.Left) - (2 * LayoutMargin) -
    LegalWidth - LegalGap - EvalWidth - EvalGap - SideGap - SideWidth,
    (BoardArea.Bottom - BoardArea.Top) - (2 * BoardMargin));
  if BoardPixels < BoardSize then
  begin
    FBoardRect := Types.Rect(0, 0, 0, 0);
    FEvalBarRect := Types.Rect(0, 0, 0, 0);
    if FLegalMovesPanel <> nil then
      FLegalMovesPanel.Visible := False;
    if FBoardTopClockLabel <> nil then
      FBoardTopClockLabel.Visible := False;
    if FBoardBottomClockLabel <> nil then
      FBoardBottomClockLabel.Visible := False;
    Exit;
  end;

  BoardPixels := (BoardPixels div BoardSize) * BoardSize;
  UnitLeft := BoardArea.Left + LayoutMargin;
  LegalLeft := UnitLeft;
  LeftPos := UnitLeft + LegalWidth + LegalGap + EvalWidth + EvalGap;
  TopPos := BoardArea.Top + ((BoardArea.Bottom - BoardArea.Top - BoardPixels) div 2);
  FBoardRect := Types.Rect(LeftPos, TopPos, LeftPos + BoardPixels,
    TopPos + BoardPixels);
  FEvalBarRect := Types.Rect(FBoardRect.Left - EvalBarGap - EvalBarWidth,
    FBoardRect.Top, FBoardRect.Left - EvalBarGap, FBoardRect.Bottom);

  if FButtonPanel <> nil then
  begin
    FButtonPanel.Left := Max(LayoutMargin, OffsetX + LeftPos +
      ((BoardPixels - FButtonPanel.Width) div 2));
    FButtonPanel.Top := 4;
  end;

  if FLegalMovesPanel <> nil then
  begin
    FLegalMovesPanel.SetBounds(OffsetX + LegalLeft, OffsetY + TopPos, LegalWidth,
      BoardPixels);
    FLegalMovesPanel.Visible := True;
    FLegalMovesPanel.BringToFront;
  end;

  DrawBoardClockLabels(FBoardRect);
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
  FEnginePanel.BorderSpacing.Bottom := LayoutMargin;

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
  FEngines[1].LogPopupMenu.OnPopup := @EnginePopupMenuPopup;
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

  FEngines[1].AnalyzeMenuItem := TMenuItem.Create(FEngines[1].LogPopupMenu);
  FEngines[1].AnalyzeMenuItem.Caption := 'Analyze';
  FEngines[1].AnalyzeMenuItem.AutoCheck := False;
  FEngines[1].AnalyzeMenuItem.Checked := FEngineAnalyzeEnabled;
  FEngines[1].AnalyzeMenuItem.OnClick := @AnalyzeMenuItemClick;
  FEngines[1].LogPopupMenu.Items.Add(FEngines[1].AnalyzeMenuItem);

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
  FEngines[2].LogPopupMenu.OnPopup := @EnginePopupMenuPopup;
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

  FEngines[2].AnalyzeMenuItem := TMenuItem.Create(FEngines[2].LogPopupMenu);
  FEngines[2].AnalyzeMenuItem.Caption := 'Analyze';
  FEngines[2].AnalyzeMenuItem.AutoCheck := False;
  FEngines[2].AnalyzeMenuItem.Checked := FEngineAnalyzeEnabled;
  FEngines[2].AnalyzeMenuItem.OnClick := @AnalyzeMenuItemClick;
  FEngines[2].LogPopupMenu.Items.Add(FEngines[2].AnalyzeMenuItem);

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
  UpdateAnalyzeMenuItems;
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
  Toolbar.Height := 42;
  Toolbar.BevelOuter := bvNone;
  Toolbar.BorderSpacing.Top := 3;
  Toolbar.BorderSpacing.Bottom := 3;

  ButtonPanel := TPanel.Create(Toolbar);
  FButtonPanel := ButtonPanel;
  ButtonPanel.Parent := Toolbar;
  ButtonPanel.Align := alNone;
  ButtonPanel.Width := 534;
  ButtonPanel.Height := 34;
  ButtonPanel.BevelOuter := bvLowered;
  ButtonPanel.SetBounds(LayoutMargin, 4, 534, 34);

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
  FGoButton.Caption := 'Analyze';
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

  FTournamentMenu := TMenuItem.Create(FMainMenu);
  FTournamentMenu.Caption := '&Tournament';
  FMainMenu.Items.Add(FTournamentMenu);

  FTournamentDialogMenuItem := TMenuItem.Create(FMainMenu);
  FTournamentDialogMenuItem.Caption := '&Tournament...';
  FTournamentDialogMenuItem.OnClick := @TournamentDialogMenuItemClick;
  FTournamentMenu.Add(FTournamentDialogMenuItem);

  FRegisteredEnginesMenuItem := TMenuItem.Create(FMainMenu);
  FRegisteredEnginesMenuItem.Caption := '&Engines...';
  FRegisteredEnginesMenuItem.OnClick := @RegisteredEnginesMenuItemClick;
  FTournamentMenu.Add(FRegisteredEnginesMenuItem);

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
  if (FLastClientLayoutWidth = ClientWidth) and
    (FLastClientLayoutHeight = ClientHeight) then
    Exit;

  FLastClientLayoutWidth := ClientWidth;
  FLastClientLayoutHeight := ClientHeight;
  UpdateMovePanelWidth;
  UpdateBoardLayout;
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

procedure TMainWindow.InvalidateBoardSquare(ASquare: Integer);
var
  CellSize: Integer;
  DisplayCol: Integer;
  DisplayRow: Integer;
  InvalidateArea: TRect;
  LogicalCol: Integer;
  LogicalRow: Integer;
begin
  if ASquare = 0 then
    Exit;
  if (FBoardPaintBox = nil) or (FBoardPaintBox.Parent = nil) or
    (FBoardRect.Right <= FBoardRect.Left) or
    (FBoardRect.Bottom <= FBoardRect.Top) then
  begin
    InvalidateBoard;
    Exit;
  end;

  LogicalRow := (ASquare - 1) div 5;
  LogicalCol := ((ASquare - 1) mod 5) * 2;
  if not Odd(LogicalRow) then
    Inc(LogicalCol);

  if FBoardFlipped then
  begin
    DisplayRow := BoardSize - 1 - LogicalRow;
    DisplayCol := BoardSize - 1 - LogicalCol;
  end
  else
  begin
    DisplayRow := LogicalRow;
    DisplayCol := LogicalCol;
  end;

  CellSize := (FBoardRect.Right - FBoardRect.Left) div BoardSize;
  InvalidateArea := Types.Rect(FBoardRect.Left + (DisplayCol * CellSize),
    FBoardRect.Top + (DisplayRow * CellSize),
    FBoardRect.Left + ((DisplayCol + 1) * CellSize),
    FBoardRect.Top + ((DisplayRow + 1) * CellSize));
  InflateRect(InvalidateArea, 3, 3);
  Types.OffsetRect(InvalidateArea, FBoardPaintBox.Left, FBoardPaintBox.Top);
  LCLIntf.InvalidateRect(FBoardPaintBox.Parent.Handle, @InvalidateArea, False);
end;

procedure TMainWindow.InvalidateEngineEvalBar;
var
  InvalidateArea: TRect;
begin
  if (FBoardPaintBox = nil) or (FBoardPaintBox.Parent = nil) or
    (FEvalBarRect.Right <= FEvalBarRect.Left) or
    (FEvalBarRect.Bottom <= FEvalBarRect.Top) then
  begin
    InvalidateBoard;
    Exit;
  end;

  InvalidateArea := FEvalBarRect;
  InflateRect(InvalidateArea, 2, 2);
  Types.OffsetRect(InvalidateArea, FBoardPaintBox.Left, FBoardPaintBox.Top);
  LCLIntf.InvalidateRect(FBoardPaintBox.Parent.Handle, @InvalidateArea, False);
end;

procedure TMainWindow.RepaintEngineEvalBarDelta(AOldScore, ANewScore: Double);
var
  BarRect: TRect;
  BlackRect: TRect;
  PaintCanvas: TCanvas;
  NewPixels: Integer;
  OldPixels: Integer;
  WhiteRect: TRect;
begin
  if (FBoardPaintBox = nil) or (FEvalBarRect.Right <= FEvalBarRect.Left) or
    (FEvalBarRect.Bottom <= FEvalBarRect.Top) then
  begin
    InvalidateEngineEvalBar;
    Exit;
  end;

  BarRect := FEvalBarRect;
  InflateRect(BarRect, -1, -1);
  if (BarRect.Right <= BarRect.Left) or (BarRect.Bottom <= BarRect.Top) then
    Exit;

  OldPixels := EvalBarWhitePixels(BarRect, AOldScore);
  NewPixels := EvalBarWhitePixels(BarRect, ANewScore);
  if NewPixels = OldPixels then
    Exit;

  PaintCanvas := FBoardPaintBox.Canvas;
  if NewPixels > OldPixels then
  begin
    PaintCanvas.Brush.Color := clWhite;
    if FBoardFlipped then
      WhiteRect := Types.Rect(BarRect.Left, BarRect.Top + OldPixels,
        BarRect.Right, BarRect.Top + NewPixels)
    else
      WhiteRect := Types.Rect(BarRect.Left, BarRect.Bottom - NewPixels,
        BarRect.Right, BarRect.Bottom - OldPixels);
    PaintCanvas.FillRect(WhiteRect);
  end
  else
  begin
    PaintCanvas.Brush.Color := clBlack;
    if FBoardFlipped then
      BlackRect := Types.Rect(BarRect.Left, BarRect.Top + NewPixels,
        BarRect.Right, BarRect.Top + OldPixels)
    else
      BlackRect := Types.Rect(BarRect.Left, BarRect.Bottom - OldPixels,
        BarRect.Right, BarRect.Bottom - NewPixels);
    PaintCanvas.FillRect(BlackRect);
  end;

  FLastEvalBarWhitePixels := NewPixels;
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
  if Screen.ActiveCustomForm <> Self then
    Exit;
  if (Key = VK_ESCAPE) and FAnalyzePvLocked then
  begin
    UnlockAnalyzePv;
    Key := 0;
    Exit;
  end;

  inherited KeyDown(Key, Shift);
  if (Key = Ord('F')) and (Shift = []) then
  begin
    FBoardFlipped := not FBoardFlipped;
    ClearBoardSelection;
    UpdateClockLabels;
    InvalidateBoard;
    if FHistoryPvMiniBoardPaintBox <> nil then
      FHistoryPvMiniBoardPaintBox.Invalidate;
    if FAnalysisBoardPaintBox <> nil then
      FAnalysisBoardPaintBox.Invalidate;
    Key := 0;
  end;
end;

procedure TMainWindow.BoardPaintBoxPaint(Sender: TObject);
begin
  if FBoardPaintBox <> nil then
    DrawBoard(FBoardPaintBox.Canvas);
end;

procedure TMainWindow.HistoryEvalPaintBoxPaint(Sender: TObject);
var
  BarHalfWidth: Integer;
  BarRect: TRect;
  Bitmap: Graphics.TBitmap;
  ChartRect: TRect;
  Client: TRect;
  EvalCanvas: TCanvas;
  I: Integer;
  MaxScore: Double;
  MidY: Integer;
  PlotLeft: Integer;
  PlotRight: Integer;
  Score: Double;
  X: Integer;
  Y: Integer;
begin
  if FHistoryEvalPaintBox = nil then
    Exit;

  Client := FHistoryEvalPaintBox.ClientRect;
  Bitmap := Graphics.TBitmap.Create;
  try
    Bitmap.SetSize(Client.Right - Client.Left, Client.Bottom - Client.Top);
    EvalCanvas := Bitmap.Canvas;
    EvalCanvas.Brush.Color := clWhite;
    EvalCanvas.FillRect(Types.Rect(0, 0, Bitmap.Width, Bitmap.Height));

    if (Bitmap.Width < 32) or (Bitmap.Height < 24) then
    begin
      FHistoryEvalPaintBox.Canvas.Draw(Client.Left, Client.Top, Bitmap);
      Exit;
    end;

    ChartRect := Types.Rect(8, 8, Bitmap.Width - 8, Bitmap.Height - 8);
    MidY := (ChartRect.Top + ChartRect.Bottom) div 2;

    EvalCanvas.Pen.Color := clSilver;
    EvalCanvas.Pen.Width := 1;
    EvalCanvas.Rectangle(ChartRect);
    EvalCanvas.Line(ChartRect.Left, MidY, ChartRect.Right, MidY);

    if Length(FHistoryMoves) = 0 then
    begin
      FHistoryEvalPaintBox.Canvas.Draw(Client.Left, Client.Top, Bitmap);
      Exit;
    end;

    MaxScore := EngineEvaluationBarMax(1);
    BarHalfWidth := Max(1, ((ChartRect.Right - ChartRect.Left) div
      Max(Length(FHistoryMoves), 1)) div 3);
    PlotLeft := ChartRect.Left + BarHalfWidth + 1;
    PlotRight := ChartRect.Right - BarHalfWidth - 1;

    for I := 1 to Length(FHistoryMoves) do
    begin
      if Length(FHistoryMoves) = 1 then
        X := (PlotLeft + PlotRight) div 2
      else
        X := PlotLeft + Round(((I - 1) / (Length(FHistoryMoves) - 1)) *
          (PlotRight - PlotLeft));

      if HistoryAnnotationScoreWhite(I, Score) then
      begin
        Score := Max(-MaxScore, Min(MaxScore, Score));
        Y := MidY - Round((Score / MaxScore) *
          ((ChartRect.Bottom - ChartRect.Top) / 2));

        if Score >= 0.0 then
        begin
          EvalCanvas.Brush.Color := clGreen;
          EvalCanvas.Pen.Color := clGreen;
          BarRect := Types.Rect(X - BarHalfWidth, Y, X + BarHalfWidth + 1, MidY);
        end
        else
        begin
          EvalCanvas.Brush.Color := clRed;
          EvalCanvas.Pen.Color := clRed;
          BarRect := Types.Rect(X - BarHalfWidth, MidY, X + BarHalfWidth + 1, Y);
        end;
        if BarRect.Bottom = BarRect.Top then
        begin
          Dec(BarRect.Top);
          Inc(BarRect.Bottom);
        end;
        EvalCanvas.Rectangle(BarRect);
      end
      else
      begin
        EvalCanvas.Brush.Color := clBlue;
        EvalCanvas.Pen.Color := clBlue;
        BarRect := Types.Rect(X - BarHalfWidth, MidY,
          X + BarHalfWidth + 1, MidY);
        Dec(BarRect.Top);
        Inc(BarRect.Bottom);
        EvalCanvas.Rectangle(BarRect);
      end;
    end;

    if (FCurrentPly > 0) and (FCurrentPly < Length(FHistoryMoves)) and
      (Length(FHistoryMoves) > 1) then
    begin
      X := PlotLeft + Round(((FCurrentPly - 1) / (Length(FHistoryMoves) - 1)) *
        (PlotRight - PlotLeft));
      EvalCanvas.Pen.Color := clGray;
      EvalCanvas.Pen.Width := 1;
      EvalCanvas.Line(X, ChartRect.Top, X, ChartRect.Bottom);
    end;

    FHistoryEvalPaintBox.Canvas.Draw(Client.Left, Client.Top, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TMainWindow.DrawAnalysisBoard(ACanvas: TCanvas; const AClient: TRect);
var
  Bitmap: Graphics.TBitmap;
  BoardPixels: Integer;
  CellSize: Integer;
  Col: Integer;
  MiniCanvas: TCanvas;
  PiecePosition: Integer;
  Row: Integer;
  SquareColor: TColor;
  SquareRect: TRect;
  X0: Integer;
  Y0: Integer;

  procedure DrawMiniPiece(const ASquare: TRect; APiece: TPiece);
  var
    MarkY: Integer;
    PieceRect: TRect;
  begin
    if APiece = pcNone then
      Exit;

    PieceRect := ASquare;
    InflateRect(PieceRect, -Max(1, CellSize div 5), -Max(1, CellSize div 5));
    if (PieceRect.Right <= PieceRect.Left) or
      (PieceRect.Bottom <= PieceRect.Top) then
      Exit;

    if APiece in [pcWhiteMan, pcWhiteKing] then
    begin
      MiniCanvas.Brush.Color := clWhite;
      MiniCanvas.Pen.Color := clBlack;
    end
    else
    begin
      MiniCanvas.Brush.Color := clBlack;
      MiniCanvas.Pen.Color := clWhite;
    end;
    MiniCanvas.Pen.Width := 1;
    MiniCanvas.Ellipse(PieceRect);

    if APiece in [pcWhiteKing, pcBlackKing] then
    begin
      MarkY := (PieceRect.Top + PieceRect.Bottom) div 2;
      if APiece = pcWhiteKing then
        MiniCanvas.Pen.Color := clBlack
      else
        MiniCanvas.Pen.Color := clWhite;
      MiniCanvas.Line(PieceRect.Left + 2, MarkY, PieceRect.Right - 2, MarkY);
    end;
  end;
begin
  Bitmap := Graphics.TBitmap.Create;
  try
    Bitmap.SetSize(AClient.Right - AClient.Left, AClient.Bottom - AClient.Top);
    MiniCanvas := Bitmap.Canvas;
    MiniCanvas.Brush.Color := Color;
    MiniCanvas.FillRect(Types.Rect(0, 0, Bitmap.Width, Bitmap.Height));

    BoardPixels := Min(Bitmap.Width, Bitmap.Height);
    BoardPixels := (BoardPixels div BoardSize) * BoardSize;
    if BoardPixels < BoardSize then
    begin
      ACanvas.Draw(AClient.Left, AClient.Top, Bitmap);
      Exit;
    end;

    CellSize := BoardPixels div BoardSize;
    X0 := (Bitmap.Width - BoardPixels) div 2;
    Y0 := (Bitmap.Height - BoardPixels) div 2;

    for Row := 0 to BoardSize - 1 do
      for Col := 0 to BoardSize - 1 do
      begin
        if Odd(Row + Col) then
          SquareColor := WoodSquareColor
        else
          SquareColor := clWhite;

        SquareRect := Types.Rect(X0 + (Col * CellSize), Y0 + (Row * CellSize),
          X0 + ((Col + 1) * CellSize), Y0 + ((Row + 1) * CellSize));
        MiniCanvas.Brush.Color := SquareColor;
        MiniCanvas.FillRect(SquareRect);

        if Odd(Row + Col) and FAnalyzePvHasBase then
        begin
          PiecePosition := BoardSquareAtCell(Row, Col);
          DrawMiniPiece(SquareRect, FAnalyzePvBrowseBoard[PiecePosition]);
        end;
      end;

    MiniCanvas.Brush.Style := bsClear;
    MiniCanvas.Pen.Color := clBlack;
    MiniCanvas.Pen.Width := 1;
    MiniCanvas.Rectangle(X0, Y0, X0 + BoardPixels, Y0 + BoardPixels);
    MiniCanvas.Brush.Style := bsSolid;

    ACanvas.Draw(AClient.Left, AClient.Top, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

procedure TMainWindow.HistoryPvMiniBoardPaintBoxPaint(Sender: TObject);
begin
  if FHistoryPvMiniBoardPaintBox <> nil then
    DrawAnalysisBoard(FHistoryPvMiniBoardPaintBox.Canvas,
      FHistoryPvMiniBoardPaintBox.ClientRect);
end;

procedure TMainWindow.AnalysisBoardPaintBoxPaint(Sender: TObject);
begin
  if FAnalysisBoardPaintBox <> nil then
    DrawAnalysisBoard(FAnalysisBoardPaintBox.Canvas,
      FAnalysisBoardPaintBox.ClientRect);
end;

procedure TMainWindow.AnalysisBoardFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  FAnalysisBoardPaintBox := nil;
  FAnalysisBoardForm := nil;
  CloseAction := caFree;
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
  BoardArea: TRect;
  CellSize: Integer;
  Col: Integer;
  PiecePosition: Integer;
  Row: Integer;
  SquareRect: TRect;
  SquareColor: TColor;
begin
  ACanvas.Brush.Color := Color;
  if FBoardPaintBox <> nil then
    BoardArea := FBoardPaintBox.ClientRect
  else
    BoardArea := ClientRect;
  ACanvas.FillRect(BoardArea);

  if (FBoardRect.Right <= FBoardRect.Left) or
    (FBoardRect.Bottom <= FBoardRect.Top) then
    Exit;

  CellSize := (FBoardRect.Right - FBoardRect.Left) div BoardSize;
  DrawBoardSideToMoveMarker(ACanvas, FBoardRect, CellSize);
  DrawEngineEvalBar(ACanvas, FBoardRect);

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
        if PiecePosition = FAnalyzeBestSourceSquare then
        begin
          ACanvas.Brush.Style := bsClear;
          ACanvas.Pen.Color := AnalyzeBestSourceColor;
          ACanvas.Pen.Width := Max(3, CellSize div 12);
          ACanvas.Rectangle(SquareRect.Left + (CellSize div 10),
            SquareRect.Top + (CellSize div 10), SquareRect.Right - (CellSize div 10),
            SquareRect.Bottom - (CellSize div 10));
          ACanvas.Brush.Style := bsSolid;
        end;
        if PiecePosition = FAnalyzeHintSourceSquare then
        begin
          ACanvas.Brush.Style := bsClear;
          ACanvas.Pen.Color := AnalyzeHintSourceColor;
          ACanvas.Pen.Width := Max(3, CellSize div 12);
          ACanvas.Rectangle(SquareRect.Left + (CellSize div 7),
            SquareRect.Top + (CellSize div 7), SquareRect.Right - (CellSize div 7),
            SquareRect.Bottom - (CellSize div 7));
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

function TMainWindow.EvalBarWhitePixels(const ABarRect: TRect; AScore: Double): Integer;
var
  ClampedScore: Double;
  MaxScore: Double;
begin
  MaxScore := EngineEvaluationBarMax(1);
  ClampedScore := Max(-MaxScore, Min(MaxScore, AScore));
  Result := Round(((ClampedScore + MaxScore) / (2.0 * MaxScore)) *
    (ABarRect.Bottom - ABarRect.Top));
end;

procedure TMainWindow.DrawEngineEvalBar(ACanvas: TCanvas; const ABoardRect: TRect);
var
  BarRect: TRect;
  FillRect: TRect;
  WhitePixels: Integer;
  WhiteRect: TRect;
begin
  if (ABoardRect.Right <= ABoardRect.Left) or
    (ABoardRect.Bottom <= ABoardRect.Top) then
    Exit;

  BarRect := Types.Rect(ABoardRect.Left - EvalBarGap - EvalBarWidth,
    ABoardRect.Top, ABoardRect.Left - EvalBarGap, ABoardRect.Bottom);
  FEvalBarRect := BarRect;
  FillRect := BarRect;
  InflateRect(FillRect, -1, -1);
  WhitePixels := EvalBarWhitePixels(FillRect, FEngineEvalScoreWhite);
  FLastEvalBarWhitePixels := WhitePixels;

  ACanvas.Brush.Color := clBlack;
  ACanvas.FillRect(FillRect);
  ACanvas.Brush.Color := clWhite;
  if FBoardFlipped then
    WhiteRect := Types.Rect(FillRect.Left, FillRect.Top, FillRect.Right,
      FillRect.Top + WhitePixels)
  else
    WhiteRect := Types.Rect(FillRect.Left, FillRect.Bottom - WhitePixels,
      FillRect.Right, FillRect.Bottom);
  ACanvas.FillRect(WhiteRect);

  ACanvas.Brush.Style := bsClear;
  ACanvas.Pen.Color := clGray;
  ACanvas.Pen.Width := 1;
  ACanvas.Rectangle(BarRect);
  ACanvas.Brush.Style := bsSolid;
end;

procedure TMainWindow.DrawBoardClockLabels(const ABoardRect: TRect);
const
  ClockHeight = 22;
  ClockGap = 2;
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

procedure ApplyMoveToBoard(var ABoard: TBoard; var ASide: TSide; const AMove: TMove);
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

function MoveIsReversibleOnBoard(const ABoard: TBoard; const AMove: TMove): Boolean;
var
  FromSquare: Integer;
begin
  Result := False;
  if Length(AMove.Squares) < 2 then
    Exit;

  FromSquare := AMove.Squares[0];
  Result := (Length(AMove.Captures) = 0) and (not AMove.Promotes) and
    (ABoard[FromSquare] in [pcWhiteKing, pcBlackKing]);
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
  begin
    AppendEngineLog('[' + ActorName + ' played ' + MoveText + ']' +
      LineEnding);
    if FPlayGameActive and EngineIsDxp(1) and
      (((FPlayGameWhiteIsEngine and (FPlayGameWhiteEngineIndex = 1)) or
      (FPlayGameBlackIsEngine and (FPlayGameBlackEngineIndex = 1)))) then
      SendDxpMoveToEngine(1, AMove);
  end;
  if (AActorEngineIndex <> 2) and SecondEngineIsRunning then
  begin
    AppendEngine2Log('[' + ActorName + ' played ' + MoveText + ']' +
      LineEnding);
    if FPlayGameActive and EngineIsDxp(2) and
      (((FPlayGameWhiteIsEngine and (FPlayGameWhiteEngineIndex = 2)) or
      (FPlayGameBlackIsEngine and (FPlayGameBlackEngineIndex = 2)))) then
      SendDxpMoveToEngine(2, AMove);
  end;
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
  SetGuiState(gsGameOver, 'draw by repetition');
  MarkGameDirty;
  AppendEngineLog('[game drawn by repetition]' + LineEnding);
  if SecondEngineIsRunning then
    AppendEngine2Log('[game drawn by repetition]' + LineEnding);
  SendDxpGameEndToPlayingDxpEngines;
  LeavePlayGameMode;
  UpdateHistoryList;
  SendStopToAllEngines;
end;

procedure TMainWindow.SetTerminalResult;
begin
  if Length(FMoves) <> 0 then
    Exit;

  if FSideToMove = sideWhite then
    FGameResult := '0-2'
  else
    FGameResult := '2-0';
  SetGuiState(gsGameOver, 'terminal position');
  MarkGameDirty;
  SendDxpGameEndToPlayingDxpEngines;
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

procedure TMainWindow.AnalyzePvMemoClick(Sender: TObject);
var
  Caret: Integer;
  I: Integer;
  Ply: Integer;
begin
  if FPvMemo = nil then
    Exit;

  Caret := FPvMemo.SelStart;
  Ply := FAnalyzePvBrowsePly;
  for I := 1 to High(FAnalyzePvMoveStarts) do
    if (FAnalyzePvMoveLengths[I] > 0) and
      (Caret >= FAnalyzePvMoveStarts[I]) and
      (Caret <= FAnalyzePvMoveStarts[I] + FAnalyzePvMoveLengths[I]) then
    begin
      Ply := I;
      Break;
    end;

  SetAnalyzePvLocked(Length(FAnalyzePvMoves) > 0);
  RebuildAnalyzePvPositionToPly(Ply);
  SelectAnalyzePvPly(Ply);
end;

procedure TMainWindow.AnalyzePvMemoKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_RIGHT:
    begin
      SetAnalyzePvLocked(Length(FAnalyzePvMoves) > 0);
      RebuildAnalyzePvPositionToPly(Min(FAnalyzePvBrowsePly + 1,
        Length(FAnalyzePvMoves)));
      SelectAnalyzePvPly(FAnalyzePvBrowsePly);
      Key := 0;
    end;
    VK_LEFT:
    begin
      SetAnalyzePvLocked(Length(FAnalyzePvMoves) > 0);
      RebuildAnalyzePvPositionToPly(Max(FAnalyzePvBrowsePly - 1, 0));
      SelectAnalyzePvPly(FAnalyzePvBrowsePly);
      Key := 0;
    end;
    VK_ESCAPE:
    begin
      UnlockAnalyzePv;
      Key := 0;
    end;
  end;
end;

procedure TMainWindow.AnalyzePvMemoKeyUp(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and FAnalyzePvLocked then
  begin
    UnlockAnalyzePv;
    Key := 0;
  end;
end;

procedure TMainWindow.NavigateHistoryToPly(APly: Integer);
begin
  RebuildPositionToPly(APly);
  if FPlayGameActive then
    RestoreClockSnapshot(APly);
  SelectHistoryPly(APly);
  RestartEngineAnalyze;
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

procedure TMainWindow.RebuildAnalyzePvPositionToPly(APly: Integer);
var
  LegalMoves: TMoveArray;
  MoveIndex: Integer;
  Ply: Integer;
begin
  if not FAnalyzePvHasBase then
    Exit;

  APly := Max(0, Min(APly, Length(FAnalyzePvMoves)));
  FAnalyzePvBrowseBoard := FAnalyzePvBaseBoard;
  FAnalyzePvBrowseSide := FAnalyzePvBaseSide;
  FAnalyzePvBrowsePly := 0;

  for Ply := 1 to APly do
  begin
    GenerateLegalMoves(FAnalyzePvBrowseBoard, FAnalyzePvBrowseSide, LegalMoves);
    MoveIndex := 0;
    while (MoveIndex <= High(LegalMoves)) and
      (not EngineMoveMatchesLegalMove(FAnalyzePvMoves[Ply - 1],
      LegalMoves[MoveIndex])) do
      Inc(MoveIndex);
    if MoveIndex > High(LegalMoves) then
      Break;

    ApplyMoveToBoard(FAnalyzePvBrowseBoard, FAnalyzePvBrowseSide,
      LegalMoves[MoveIndex]);
    FAnalyzePvBrowsePly := Ply;
  end;

  if FHistoryPvMiniBoardPaintBox <> nil then
    FHistoryPvMiniBoardPaintBox.Invalidate;
  if FAnalysisBoardPaintBox <> nil then
    FAnalysisBoardPaintBox.Invalidate;
end;

procedure TMainWindow.SelectAnalyzePvPly(APly: Integer);
begin
  if FPvMemo = nil then
    Exit;

  if APly <= 0 then
  begin
    FPvMemo.SelStart := 0;
    FPvMemo.SelLength := 0;
    Exit;
  end;

  if (APly <= High(FAnalyzePvMoveStarts)) and
    (FAnalyzePvMoveLengths[APly] > 0) then
  begin
    FPvMemo.SelStart := FAnalyzePvMoveStarts[APly];
    FPvMemo.SelLength := FAnalyzePvMoveLengths[APly];
  end;
end;

procedure TMainWindow.SetAnalyzePvLocked(ALocked: Boolean);
begin
  if FAnalyzePvLocked = ALocked then
    Exit;

  FAnalyzePvLocked := ALocked;
  if FAnalyzePvLocked then
    AppendEngineLog('[PV locked]' + LineEnding)
  else
    AppendEngineLog('[PV unlocked]' + LineEnding);
end;

procedure TMainWindow.UnlockAnalyzePv;
begin
  if not FAnalyzePvLocked then
    Exit;

  SetAnalyzePvLocked(False);
  SelectAnalyzePvPly(FAnalyzePvBrowsePly);
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
      '; restarting analysis]' + LineEnding);
    RestartEngineAnalyze;
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

function TMainWindow.EngineSlotAvailableForPlay(AEngineIndex: Integer): Boolean;
begin
  Result := False;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  if EngineIsDxp(AEngineIndex) then
  begin
    Result := FEngines[AEngineIndex].DxpSocket <> nil;
    Exit;
  end;

  case AEngineIndex of
    1: Result := EngineIsRunning;
    2: Result := SecondEngineIsRunning;
  else
    Result := False;
  end;
  if not Result then
    Exit;
  Result := FEngines[AEngineIndex].Ready;
end;

procedure TMainWindow.UpdateEnginePollTimer;
var
  HasEngineProcess: Boolean;
begin
  if FEnginePollTimer = nil then
    Exit;

  {$IFDEF MSWINDOWS}
  HasEngineProcess := False;
  {$ELSE}
  HasEngineProcess := (FEngines[1].Process <> nil) or
    (FEngines[2].Process <> nil);
  {$ENDIF}

  FEnginePollTimer.Enabled := HasEngineProcess;
end;

function TMainWindow.EngineParamsFileNameForDisplayName(
  const ADisplayName: String; const AEngineFileName: String): String;
var
  BaseName: String;
  I: Integer;
  SafeName: String;
begin
  if AEngineFileName <> '' then
    SafeName := ChangeFileExt(ExtractFileName(AEngineFileName), '')
  else
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
  if ElapsedSeconds > 10 then
    ElapsedSeconds := 0;

  if FSideToMove = sideWhite then
  begin
    FWhiteClockSeconds := Max(0, FWhiteClockSeconds - ElapsedSeconds);
    if FWhiteClockSeconds = 0 then
    begin
      FGameResult := '0-2';
      MarkGameDirty;
      SendDxpGameEndToPlayingDxpEngines;
      LeavePlayGameMode;
      AppendEngineLog('[white clock expired]' + LineEnding);
      UpdateHistoryList;
      RestartEngineAnalyze;
    end;
  end
  else
  begin
    FBlackClockSeconds := Max(0, FBlackClockSeconds - ElapsedSeconds);
    if FBlackClockSeconds = 0 then
    begin
      FGameResult := '2-0';
      MarkGameDirty;
      SendDxpGameEndToPlayingDxpEngines;
      LeavePlayGameMode;
      AppendEngineLog('[black clock expired]' + LineEnding);
      UpdateHistoryList;
      RestartEngineAnalyze;
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

function HubDoneResultIsDraw(const AResult: String): Boolean;
var
  ResultText: String;
begin
  ResultText := LowerCase(Trim(AResult));
  Result := (ResultText = 'draw') or (ResultText = '1-1') or
    (ResultText = '1/2-1/2') or (ResultText = '0.5-0.5');
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
  FClocksActive := False;
  if FClockTimer <> nil then
    {$IFDEF MSWINDOWS}
    FClockTimer.Enabled := False;
    {$ELSE}
    FClockTimer.Enabled := False;
    {$ENDIF}
  UpdateClockLabels;
end;

procedure TMainWindow.ActivateGameClocks;
begin
  if not FPlayGameActive then
    Exit;

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
  if FGuiState in [gsPlayGameHumanTurn, gsPlayGameEngineTurn,
    gsTournamentRunning, gsStopping] then
    SetGuiState(gsIdle, 'leave play-game mode');
  ResetClocks;
  if FEngineAnalyzeAutoDisabled then
  begin
    FEngineAnalyzeAutoDisabled := False;
    FEngineAnalyzeEnabled := True;
  end;
  UpdateAnalyzeMenuItems;
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
  StopDxpConnection(1);
  {$IFDEF MSWINDOWS}
  if FEngines[1].Running then
  begin
    if not EngineIsDxp(1) then
    begin
      AppendEngineLog('> quit' + LineEnding);
      SendEngineCommand('quit');
      WaitForSingleObject(FEngines[1].ProcessInfo.hProcess, 1000);
    end;
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
      if not EngineIsDxp(1) then
      begin
        AppendEngineLog('> quit' + LineEnding);
        SendEngineCommand('quit');
        FEngines[1].Process.WaitOnExit(1000);
      end;
      if FEngines[1].Process.Running then
        FEngines[1].Process.Terminate(0);
    end;
    FreeAndNil(FEngines[1].Process);
  end;
  {$ENDIF}
  FAutoPlayActive := False;
  FAutoPlayPlyCount := 0;
  FEngineEvalScoreWhite := 0.0;
  FPendingAutoPlayStart := False;
  FPendingAnalyzeStart := False;
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
  FinishEngineSlotSearch(1);
  UpdateEnginePollTimer;
  UpdateEnginePopupMenuItems;
end;

procedure TMainWindow.CloseSecondEngine;
var
  FirstEngineFileName: String;
  FirstEngineWasRunning: Boolean;
begin
  FirstEngineWasRunning := (not FShuttingDown) and EngineIsRunning;
  if FirstEngineWasRunning then
    FirstEngineFileName := FEngines[1].FileName
  else
    FirstEngineFileName := '';

  StopDxpConnection(2);
  {$IFDEF MSWINDOWS}
  if FEngines[2].Running then
  begin
    if not EngineIsDxp(2) then
    begin
      AppendEngine2Log('> quit' + LineEnding);
      SendSecondEngineCommand('quit');
      WaitForSingleObject(FEngines[2].ProcessInfo.hProcess, 1000);
    end;
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
      if not EngineIsDxp(2) then
      begin
        AppendEngine2Log('> quit' + LineEnding);
        SendSecondEngineCommand('quit');
        FEngines[2].Process.WaitOnExit(1000);
      end;
      if FEngines[2].Process.Running then
        FEngines[2].Process.Terminate(0);
    end;
    FreeAndNil(FEngines[2].Process);
  end;
  {$ENDIF}
  ResetEngineSlotRuntime(2);
  UpdateEnginePollTimer;

  if FirstEngineWasRunning and (FirstEngineFileName <> '') and
    (not EngineIsRunning) then
  begin
    AppendEngineLog('[engine 1 stopped while closing engine 2; restarting]' +
      LineEnding);
    StartEngine(FirstEngineFileName, True);
  end;
end;

procedure TMainWindow.CloseEngineMenuItemClick(Sender: TObject);
begin
  if SecondEngineIsRunning then
  begin
    AppendEngineLog('[please close engine 2 first]' + LineEnding);
    Exit;
  end;

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

function TMainWindow.RegisteredEnginesFileName: String;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'engines.json';
end;

procedure TMainWindow.RegisterEngineExecutable(const AFileName: String);
var
  AlreadyRegistered: Boolean;
  Data: TJSONArray;
  DidChange: Boolean;
  ExistingData: TJSONData;
  FileName: String;
  I: Integer;
  Item: TJSONObject;
  Lines: TStringList;
  PathText: String;
  ExeText: String;

  function CurrentHubId: String;
  begin
    Result := '';
    if SameFileName(FEngines[1].FileName, AFileName) then
    begin
      if FEngines[1].Protocol = epHub then
        Result := FEngines[1].HubId;
    end
    else if SameFileName(FEngines[2].FileName, AFileName) then
    begin
      if FEngines[2].Protocol = epHub then
        Result := FEngines[2].HubId;
    end;
  end;

  function CurrentDxpId: String;
  begin
    Result := '';
    if SameFileName(FEngines[1].FileName, AFileName) then
    begin
      if FEngines[1].Protocol = epDxp then
        Result := FEngines[1].DxpId;
    end
    else if SameFileName(FEngines[2].FileName, AFileName) then
    begin
      if FEngines[2].Protocol = epDxp then
        Result := FEngines[2].DxpId;
    end;
  end;
begin
  if AFileName = '' then
    Exit;

  PathText := ExcludeTrailingPathDelimiter(ExtractFilePath(AFileName));
  ExeText := ExtractFileName(AFileName);
  FileName := RegisteredEnginesFileName;
  Data := TJSONArray.Create;
  DidChange := False;
  try
    try
      if FileExists(FileName) then
      begin
        Lines := TStringList.Create;
        try
          Lines.LoadFromFile(FileName);
          ExistingData := GetJSON(Lines.Text);
        finally
          Lines.Free;
        end;
        try
          if ExistingData.JSONType = jtArray then
            for I := 0 to TJSONArray(ExistingData).Count - 1 do
              if TJSONArray(ExistingData).Items[I].JSONType = jtObject then
              begin
                Item := TJSONObject.Create;
                Item.Add('path', TJSONObject(TJSONArray(ExistingData).Items[I]).Get('path', ''));
                Item.Add('executable',
                  TJSONObject(TJSONArray(ExistingData).Items[I]).Get('executable', ''));
                Item.Add('hub_id',
                  TJSONObject(TJSONArray(ExistingData).Items[I]).Get('hub_id', ''));
                Item.Add('dxp_id',
                  TJSONObject(TJSONArray(ExistingData).Items[I]).Get('dxp_id', ''));
                if (Item.Get('hub_id', '') = '') and
                  SameText(TJSONObject(TJSONArray(ExistingData).Items[I]).Get('protocol', ''),
                  'hub') then
                  Item.Strings['hub_id'] :=
                    TJSONObject(TJSONArray(ExistingData).Items[I]).Get('reported_id',
                    TJSONObject(TJSONArray(ExistingData).Items[I]).Get('id', ''));
                if (Item.Get('dxp_id', '') = '') and
                  SameText(TJSONObject(TJSONArray(ExistingData).Items[I]).Get('protocol', ''),
                  'dxp') then
                  Item.Strings['dxp_id'] :=
                    TJSONObject(TJSONArray(ExistingData).Items[I]).Get('reported_id',
                    TJSONObject(TJSONArray(ExistingData).Items[I]).Get('id', ''));
                Data.Add(Item);
              end;
        finally
          ExistingData.Free;
        end;
      end;

      AlreadyRegistered := False;
      for I := 0 to Data.Count - 1 do
        if (Data.Items[I].JSONType = jtObject) and
          SameText(TJSONObject(Data.Items[I]).Get('path', ''), PathText) and
          SameText(TJSONObject(Data.Items[I]).Get('executable', ''), ExeText) then
        begin
          AlreadyRegistered := True;
          Break;
        end;

      if not AlreadyRegistered then
      begin
        Item := TJSONObject.Create;
        Item.Add('path', PathText);
        Item.Add('executable', ExeText);
        Item.Add('hub_id', CurrentHubId);
        Item.Add('dxp_id', CurrentDxpId);
        Data.Add(Item);
        DidChange := True;
      end;

      if DidChange then
      begin
        Lines := TStringList.Create;
        try
          Lines.Text := Data.FormatJSON([], 2) + LineEnding;
          Lines.SaveToFile(FileName);
        finally
          Lines.Free;
        end;
      end;
    except
      on E: Exception do
        AppendEngineLog('[could not update engines.json: ' + E.Message + ']' +
          LineEnding);
    end;
  finally
    Data.Free;
  end;
end;

procedure TMainWindow.UpdateRegisteredEngineId(const AFileName,
  AEngineId: String; const AProtocol: String);
var
  DidChange: Boolean;
  Data: TJSONArray;
  ExistingData: TJSONData;
  FileName: String;
  I: Integer;
  Item: TJSONObject;
  Lines: TStringList;
  PathText: String;
  ExeText: String;
begin
  if (AFileName = '') or (AEngineId = '') then
    Exit;

  PathText := ExcludeTrailingPathDelimiter(ExtractFilePath(AFileName));
  ExeText := ExtractFileName(AFileName);
  FileName := RegisteredEnginesFileName;
  if not FileExists(FileName) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    ExistingData := GetJSON(Lines.Text);
  finally
    Lines.Free;
  end;

  Data := TJSONArray.Create;
  DidChange := False;
  try
    try
      if ExistingData.JSONType = jtArray then
        for I := 0 to TJSONArray(ExistingData).Count - 1 do
          if TJSONArray(ExistingData).Items[I].JSONType = jtObject then
          begin
            Item := TJSONObject.Create;
            Item.Add('path', TJSONObject(TJSONArray(ExistingData).Items[I]).Get('path', ''));
            Item.Add('executable',
              TJSONObject(TJSONArray(ExistingData).Items[I]).Get('executable', ''));
            Item.Add('hub_id',
              TJSONObject(TJSONArray(ExistingData).Items[I]).Get('hub_id', ''));
            Item.Add('dxp_id',
              TJSONObject(TJSONArray(ExistingData).Items[I]).Get('dxp_id', ''));
            if (Item.Get('hub_id', '') = '') and
              SameText(TJSONObject(TJSONArray(ExistingData).Items[I]).Get('protocol', ''),
              'hub') then
              Item.Strings['hub_id'] :=
                TJSONObject(TJSONArray(ExistingData).Items[I]).Get('reported_id',
                TJSONObject(TJSONArray(ExistingData).Items[I]).Get('id', ''));
            if (Item.Get('dxp_id', '') = '') and
              SameText(TJSONObject(TJSONArray(ExistingData).Items[I]).Get('protocol', ''),
              'dxp') then
              Item.Strings['dxp_id'] :=
                TJSONObject(TJSONArray(ExistingData).Items[I]).Get('reported_id',
                TJSONObject(TJSONArray(ExistingData).Items[I]).Get('id', ''));
            if SameText(Item.Get('path', ''), PathText) and
              SameText(Item.Get('executable', ''), ExeText) then
            begin
              if SameText(AProtocol, 'hub') and
                (Item.Get('hub_id', '') <> AEngineId) then
              begin
                Item.Strings['hub_id'] := AEngineId;
                DidChange := True;
              end
              else if SameText(AProtocol, 'dxp') and
                (Item.Get('dxp_id', '') <> AEngineId) then
              begin
                Item.Strings['dxp_id'] := AEngineId;
                DidChange := True;
              end;
            end;
            Data.Add(Item);
          end;
    finally
      ExistingData.Free;
    end;

    if DidChange then
    begin
      Lines := TStringList.Create;
      try
        Lines.Text := Data.FormatJSON([], 2) + LineEnding;
        Lines.SaveToFile(FileName);
      finally
        Lines.Free;
      end;
    end;
  except
    on E: Exception do
      AppendEngineLog('[could not update engine id in engines.json: ' +
        E.Message + ']' + LineEnding);
  end;
  Data.Free;
end;

procedure TMainWindow.UpdateRegisteredEngineProtocol(const AFileName,
  AProtocol: String);
begin
  { Kept for older call sites. engines.json now stores hub_id/dxp_id directly;
    protocol is derived from which of those IDs is non-empty. }
end;

procedure TMainWindow.RegisteredEnginesDialogClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  if Sender is TCustomForm then
    SaveRegisteredEnginesDialog(TCustomForm(Sender));
  CloseAction := caFree;
end;

procedure TMainWindow.RegisteredEnginesDialogCloseButtonClick(Sender: TObject);
begin
  if (Sender is TControl) and (TControl(Sender).Parent <> nil) and
    (TControl(Sender).Parent.Parent is TCustomForm) then
    TCustomForm(TControl(Sender).Parent.Parent).Close;
end;

procedure TMainWindow.RegisteredEnginesDialogSaveButtonClick(Sender: TObject);
begin
  if (Sender is TControl) and (TControl(Sender).Parent <> nil) and
    (TControl(Sender).Parent.Parent is TCustomForm) then
    SaveRegisteredEnginesDialog(TCustomForm(TControl(Sender).Parent.Parent));
end;

procedure TMainWindow.NormalizeRegisteredEngineIdsInGrid(AGrid: TStringGrid);
var
  BaseIds: array of String;
  BaseText: String;
  Counts: TStringList;
  I: Integer;
  Seen: TStringList;
  SeenCount: Integer;

  procedure IncValue(AList: TStringList; const AKey: String);
  begin
    AList.Values[AKey] := IntToStr(StrToIntDef(AList.Values[AKey], 0) + 1);
  end;

  function StripNumericSuffix(const AText: String): String;
  var
    P: Integer;
    Suffix: String;
  begin
    Result := AText;
    P := Length(Result);
    while (P > 0) and (Result[P] in ['0'..'9']) do
      Dec(P);
    if (P > 1) and (Result[P] = '_') and (P < Length(Result)) then
    begin
      Suffix := Copy(Result, P + 1, Length(Result) - P);
      if StrToIntDef(Suffix, -1) > 0 then
        Result := Copy(Result, 1, P - 1);
    end;
  end;

begin
  if AGrid = nil then
    Exit;

  SetLength(BaseIds, AGrid.RowCount);
  Counts := TStringList.Create;
  Seen := TStringList.Create;
  try
    for I := 1 to AGrid.RowCount - 1 do
      if (AGrid.Cells[1, I] <> '') and (AGrid.Cells[1, I] <> '(none)') then
      begin
        if AGrid.ColCount > 4 then
          BaseText := Trim(AGrid.Cells[4, I])
        else if AGrid.ColCount > 3 then
          BaseText := Trim(AGrid.Cells[3, I])
        else
          BaseText := '';
        if BaseText = '' then
          BaseText := StripNumericSuffix(Trim(AGrid.Cells[0, I]));
        if BaseText = '' then
          BaseText := ChangeFileExt(ExtractFileName(AGrid.Cells[1, I]), '');
        if BaseText = '' then
          BaseText := Trim(AGrid.Cells[1, I]);
        BaseIds[I] := BaseText;
        IncValue(Counts, BaseText);
      end;

    for I := 1 to AGrid.RowCount - 1 do
      if BaseIds[I] <> '' then
      begin
        if StrToIntDef(Counts.Values[BaseIds[I]], 0) > 1 then
        begin
          SeenCount := StrToIntDef(Seen.Values[BaseIds[I]], 0) + 1;
          Seen.Values[BaseIds[I]] := IntToStr(SeenCount);
          AGrid.Cells[0, I] := BaseIds[I] + '_' + IntToStr(SeenCount);
        end
        else
          AGrid.Cells[0, I] := BaseIds[I];
      end;
  finally
    Counts.Free;
    Seen.Free;
  end;
end;

procedure TMainWindow.NormalizeRegisteredEngineIdsInJson(AData: TJSONArray);
var
  BaseIds: array of String;
  BaseText: String;
  Counts: TStringList;
  I: Integer;
  Item: TJSONObject;
  Seen: TStringList;
  SeenCount: Integer;

  procedure IncValue(AList: TStringList; const AKey: String);
  begin
    AList.Values[AKey] := IntToStr(StrToIntDef(AList.Values[AKey], 0) + 1);
  end;

  function StripNumericSuffix(const AText: String): String;
  var
    P: Integer;
    Suffix: String;
  begin
    Result := AText;
    P := Length(Result);
    while (P > 0) and (Result[P] in ['0'..'9']) do
      Dec(P);
    if (P > 1) and (Result[P] = '_') and (P < Length(Result)) then
    begin
      Suffix := Copy(Result, P + 1, Length(Result) - P);
      if StrToIntDef(Suffix, -1) > 0 then
        Result := Copy(Result, 1, P - 1);
    end;
  end;

begin
  if AData = nil then
    Exit;

  SetLength(BaseIds, AData.Count);
  Counts := TStringList.Create;
  Seen := TStringList.Create;
  try
    for I := 0 to AData.Count - 1 do
      if AData.Items[I].JSONType = jtObject then
      begin
        Item := TJSONObject(AData.Items[I]);
        BaseText := Trim(Item.Get('reported_id', ''));
        if BaseText = '' then
          BaseText := StripNumericSuffix(Trim(Item.Get('id', '')));
        if BaseText = '' then
          BaseText := ChangeFileExt(ExtractFileName(Item.Get('executable', '')), '');
        if BaseText = '' then
          BaseText := Trim(Item.Get('executable', ''));
        Item.Strings['reported_id'] := BaseText;
        BaseIds[I] := BaseText;
        if BaseText <> '' then
          IncValue(Counts, BaseText);
      end;

    for I := 0 to AData.Count - 1 do
      if (AData.Items[I].JSONType = jtObject) and (BaseIds[I] <> '') then
      begin
        Item := TJSONObject(AData.Items[I]);
        if StrToIntDef(Counts.Values[BaseIds[I]], 0) > 1 then
        begin
          SeenCount := StrToIntDef(Seen.Values[BaseIds[I]], 0) + 1;
          Seen.Values[BaseIds[I]] := IntToStr(SeenCount);
          Item.Strings['id'] := BaseIds[I] + '_' + IntToStr(SeenCount);
        end
        else
          Item.Strings['id'] := BaseIds[I];
      end;
  finally
    Counts.Free;
    Seen.Free;
  end;
end;

procedure TMainWindow.SaveRegisteredEnginesDialog(ADialog: TCustomForm);
var
  Data: TJSONArray;
  DxpId: String;
  DxpParams: TEngineParamArray;
  Grid: TStringGrid;
  HubId: String;
  HubParams: TEngineParamArray;
  I: Integer;
  Item: TJSONObject;
  Lines: TStringList;
  ParamsFileName: String;
begin
  if (ADialog = nil) or
    (not (ADialog.FindComponent('RegisteredEnginesGrid') is TStringGrid)) then
    Exit;

  Grid := TStringGrid(ADialog.FindComponent('RegisteredEnginesGrid'));
  Data := TJSONArray.Create;
  try
    for I := 1 to Grid.RowCount - 1 do
      if (Grid.Cells[0, I] <> '') and (Grid.Cells[0, I] <> '(none)') then
      begin
        HubId := '';
        DxpId := '';
        if Grid.ColCount > 2 then
          HubId := Trim(Grid.Cells[2, I]);
        if Grid.ColCount > 3 then
          DxpId := Trim(Grid.Cells[3, I]);

        Item := TJSONObject.Create;
        Item.Add('executable', Grid.Cells[0, I]);
        Item.Add('path', Grid.Cells[1, I]);
        Item.Add('hub_id', HubId);
        Item.Add('dxp_id', DxpId);
        Data.Add(Item);

        ParamsFileName := EngineParamsFileNameForDisplayName('',
          IncludeTrailingPathDelimiter(Grid.Cells[1, I]) + Grid.Cells[0, I]);
        SetLength(HubParams, 0);
        LoadParamsFromJson(ParamsFileName, 'hub', HubParams);
        if (Length(HubParams) > 0) or (HubId <> '') then
        begin
          AddOrUpdateParam(HubParams, HubIdParamName, 'string', HubId, False);
          SaveParamsToJson(ParamsFileName, 'hub', HubParams);
        end;
        SetLength(DxpParams, 0);
        LoadParamsFromJson(ParamsFileName, 'dxp', DxpParams);
        if (Length(DxpParams) > 0) or (DxpId <> '') then
        begin
          AddOrUpdateParam(DxpParams, DxpIdParamName, 'string', DxpId, False);
          SaveParamsToJson(ParamsFileName, 'dxp', DxpParams);
        end;
      end;
    Lines := TStringList.Create;
    try
      Lines.Text := Data.FormatJSON([], 2) + LineEnding;
      Lines.SaveToFile(RegisteredEnginesFileName);
    finally
      Lines.Free;
    end;
  finally
    Data.Free;
  end;
end;

procedure TMainWindow.RegisteredEnginesMenuItemClick(Sender: TObject);
var
  BottomPanel: TPanel;
  CloseButton: TButton;
  Data: TJSONData;
  Dialog: TForm;
  Grid: TStringGrid;
  I: Integer;
  Lines: TStringList;
  ParamsFileName: String;
  Params: TEngineParamArray;
  Row: Integer;
  SaveButton: TButton;

  function ParamValue(const AParams: TEngineParamArray;
    const AName: String): String;
  var
    P: Integer;
  begin
    Result := '';
    for P := 0 to High(AParams) do
      if SameText(AParams[P].Name, AName) then
        Exit(AParams[P].Value);
  end;

  function ParamExists(const AParams: TEngineParamArray;
    const AName: String): Boolean;
  var
    P: Integer;
  begin
    Result := False;
    for P := 0 to High(AParams) do
      if SameText(AParams[P].Name, AName) then
        Exit(True);
  end;

  procedure SortGridById;
  var
    Col: Integer;
    LeftRow: Integer;
    RightRow: Integer;
    Temp: String;
  begin
    for LeftRow := 1 to Grid.RowCount - 2 do
      for RightRow := LeftRow + 1 to Grid.RowCount - 1 do
        if CompareText(Grid.Cells[0, LeftRow],
          Grid.Cells[0, RightRow]) > 0 then
          for Col := 0 to Grid.ColCount - 1 do
          begin
            Temp := Grid.Cells[Col, LeftRow];
            Grid.Cells[Col, LeftRow] := Grid.Cells[Col, RightRow];
            Grid.Cells[Col, RightRow] := Temp;
          end;
  end;
begin
  Dialog := TForm.Create(Self);
  Dialog.Caption := 'Registered engines';
  Dialog.Width := 820;
  Dialog.Height := 360;
  Dialog.Position := poDesigned;
  Dialog.OnClose := @RegisteredEnginesDialogClose;

  Grid := TStringGrid.Create(Dialog);
  Grid.Name := 'RegisteredEnginesGrid';
  Grid.Parent := Dialog;
  Grid.Align := alClient;
  Grid.ColCount := 4;
  Grid.FixedCols := 0;
  Grid.FixedRows := 1;
  Grid.RowCount := 2;
  Grid.Options := Grid.Options + [goEditing, goColSizing] - [goRowSelect];
  Grid.Cells[0, 0] := 'Executable';
  Grid.Cells[1, 0] := 'Path';
  Grid.Cells[2, 0] := 'Hub ID';
  Grid.Cells[3, 0] := 'DXP ID';
  Grid.ColWidths[0] := 130;
  Grid.ColWidths[1] := 360;
  Grid.ColWidths[2] := 150;
  Grid.ColWidths[3] := 150;

  if FileExists(RegisteredEnginesFileName) then
  begin
    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(RegisteredEnginesFileName);
      Data := GetJSON(Lines.Text);
    finally
      Lines.Free;
    end;
    try
      if Data.JSONType = jtArray then
      begin
        Grid.RowCount := Max(2, TJSONArray(Data).Count + 1);
        Row := 1;
        for I := 0 to TJSONArray(Data).Count - 1 do
          if TJSONArray(Data).Items[I].JSONType = jtObject then
          begin
            Grid.Cells[0, Row] :=
              TJSONObject(TJSONArray(Data).Items[I]).Get('executable', '');
            Grid.Cells[1, Row] :=
              TJSONObject(TJSONArray(Data).Items[I]).Get('path', '');
            Grid.Cells[2, Row] :=
              TJSONObject(TJSONArray(Data).Items[I]).Get('hub_id', '');
            Grid.Cells[3, Row] :=
              TJSONObject(TJSONArray(Data).Items[I]).Get('dxp_id', '');
            if (Grid.Cells[2, Row] = '') and
              SameText(TJSONObject(TJSONArray(Data).Items[I]).Get('protocol', ''),
              'hub') then
              Grid.Cells[2, Row] :=
                TJSONObject(TJSONArray(Data).Items[I]).Get('reported_id',
                TJSONObject(TJSONArray(Data).Items[I]).Get('id', ''));
            if (Grid.Cells[3, Row] = '') and
              SameText(TJSONObject(TJSONArray(Data).Items[I]).Get('protocol', ''),
              'dxp') then
              Grid.Cells[3, Row] :=
                TJSONObject(TJSONArray(Data).Items[I]).Get('reported_id',
                TJSONObject(TJSONArray(Data).Items[I]).Get('id', ''));
            ParamsFileName := EngineParamsFileNameForDisplayName('',
              IncludeTrailingPathDelimiter(Grid.Cells[1, Row]) +
              Grid.Cells[0, Row]);
            SetLength(Params, 0);
            LoadParamsFromJson(ParamsFileName, 'hub', Params);
            if (Grid.Cells[2, Row] = '') and (Length(Params) > 0) then
            begin
              Grid.Cells[2, Row] := ParamValue(Params, HubIdParamName);
              if (Grid.Cells[2, Row] = '') and
                (not ParamExists(Params, HubIdParamName)) then
                Grid.Cells[2, Row] := 'Hub' + IntToStr(Row);
            end;
            SetLength(Params, 0);
            LoadParamsFromJson(ParamsFileName, 'dxp', Params);
            if (Grid.Cells[3, Row] = '') and (Length(Params) > 0) then
            begin
              Grid.Cells[3, Row] := ParamValue(Params, DxpIdParamName);
              if (Grid.Cells[3, Row] = '') and
                (not ParamExists(Params, DxpIdParamName)) then
                Grid.Cells[3, Row] := 'DXP' + IntToStr(Row);
            end;
            Inc(Row);
          end;
      end;
    finally
      Data.Free;
    end;
  end;

  SortGridById;
  if Grid.Cells[0, 1] = '' then
    Grid.Cells[0, 1] := '(none)';

  BottomPanel := TPanel.Create(Dialog);
  BottomPanel.Parent := Dialog;
  BottomPanel.Align := alBottom;
  BottomPanel.Height := 44;
  BottomPanel.BevelOuter := bvNone;

  SaveButton := TButton.Create(BottomPanel);
  SaveButton.Parent := BottomPanel;
  SaveButton.Caption := 'Save';
  SaveButton.SetBounds(10, 8, 88, 28);
  SaveButton.OnClick := @RegisteredEnginesDialogSaveButtonClick;

  CloseButton := TButton.Create(BottomPanel);
  CloseButton.Parent := BottomPanel;
  CloseButton.Caption := 'Close';
  CloseButton.SetBounds(106, 8, 88, 28);
  CloseButton.OnClick := @RegisteredEnginesDialogCloseButtonClick;

  CenterDialogOnMainWindow(Dialog);
  Dialog.Show;
end;

procedure TMainWindow.TournamentDialogMenuItemClick(Sender: TObject);
begin
  if FTournamentDialog = nil then
  begin
    FTournamentDialog := TTournamentDialog.Create(Self, RegisteredEnginesFileName);
    CenterDialogOnMainWindow(FTournamentDialog);
  end;
  FTournamentDialog.Show;
  FTournamentDialog.BringToFront;
end;

procedure TMainWindow.ShowAnalysisBoardMenuItemClick(Sender: TObject);
begin
  if FAnalysisBoardForm = nil then
  begin
    FAnalysisBoardForm := TForm.Create(Self);
    FAnalysisBoardForm.Caption := 'Analysis board';
    FAnalysisBoardForm.Width := 420;
    FAnalysisBoardForm.Height := 440;
    FAnalysisBoardForm.Position := poDesigned;
    FAnalysisBoardForm.OnClose := @AnalysisBoardFormClose;

    FAnalysisBoardPaintBox := TPaintBox.Create(FAnalysisBoardForm);
    FAnalysisBoardPaintBox.Parent := FAnalysisBoardForm;
    FAnalysisBoardPaintBox.Align := alClient;
    FAnalysisBoardPaintBox.BorderSpacing.Around := 8;
    FAnalysisBoardPaintBox.OnPaint := @AnalysisBoardPaintBoxPaint;

    CenterDialogOnMainWindow(FAnalysisBoardForm);
  end;

  FAnalysisBoardForm.Show;
  FAnalysisBoardForm.BringToFront;
  if FAnalysisBoardPaintBox <> nil then
    FAnalysisBoardPaintBox.Invalidate;
end;

procedure TMainWindow.EngineIniBrowseClick(Sender: TObject);
var
  Dialog: TCustomForm;
  Edit: TEdit;
  Memo: TMemo;
  OpenDialog: TOpenDialog;
  StartDir: String;
begin
  if not (Sender is TControl) then
    Exit;
  if not (TControl(Sender).Parent is TCustomForm) then
    Exit;

  Dialog := TCustomForm(TControl(Sender).Parent);
  if not (Dialog.FindComponent('EngineIniEdit') is TEdit) then
    Exit;
  if not (Dialog.FindComponent('EngineIniMemo') is TMemo) then
    Exit;

  Edit := TEdit(Dialog.FindComponent('EngineIniEdit'));
  Memo := TMemo(Dialog.FindComponent('EngineIniMemo'));
  OpenDialog := TOpenDialog.Create(Dialog);
  try
    OpenDialog.Title := 'Select engine configuration file';
    OpenDialog.Filter :=
      'Configuration files (*.ini;*.cfg;*.conf;*.txt)|*.ini;*.cfg;*.conf;*.txt|All files (*.*)|*.*';
    OpenDialog.Options := OpenDialog.Options + [ofFileMustExist];
    if (Trim(Edit.Text) <> '') and (Trim(Edit.Text) <> '(none found)') then
    begin
      OpenDialog.FileName := Edit.Text;
      StartDir := ExtractFilePath(Edit.Text);
    end
    else
      StartDir := TControl(Sender).Hint;
    if StartDir <> '' then
      OpenDialog.InitialDir := StartDir;

    if not OpenDialog.Execute then
      Exit;

    Edit.Text := OpenDialog.FileName;
    Memo.ReadOnly := False;
    try
      Memo.Lines.LoadFromFile(OpenDialog.FileName);
    except
      on E: Exception do
      begin
        Memo.Clear;
        Memo.Lines.Add('; Could not load configuration file: ' + E.Message);
      end;
    end;
  finally
    OpenDialog.Free;
  end;
end;

function TMainWindow.ShowEngineLauncherDialog(AEngineIndex: Integer;
  out AFileName, APreferredProtocol: String): Boolean;
var
  BrowseButton: TButton;
  CancelButton: TButton;
  Data: TJSONData;
  Dialog: TForm;
  EngineFileName: String;
  EngineList: TListBox;
  ExeText: String;
  HubId: String;
  DxpId: String;
  I: Integer;
  Lines: TStringList;
  OKButton: TButton;
  PathText: String;
  Protocols: TStringList;
  SelectedIndex: Integer;

  procedure AddRegisteredEngine(const ADisplayText, AFileName,
    AProtocol: String);
  begin
    if (ADisplayText = '') or (AFileName = '') then
      Exit;
    EngineList.Items.Add(ADisplayText);
    Protocols.Add(AProtocol);
    Lines.Add(AFileName);
  end;

begin
  Result := False;
  AFileName := '';
  APreferredProtocol := '';

  Protocols := TStringList.Create;
  Dialog := TForm.Create(Self);
  try
    Dialog.Caption := 'Open engine';
    Dialog.Width := 620;
    Dialog.Height := 360;
    Dialog.Position := poDesigned;
    Dialog.BorderStyle := bsDialog;

    EngineList := TListBox.Create(Dialog);
    EngineList.Parent := Dialog;
    EngineList.SetBounds(12, 12, 596, 260);

    Lines := TStringList.Create;
    try
      if FileExists(RegisteredEnginesFileName) then
      begin
        Lines.LoadFromFile(RegisteredEnginesFileName);
        Data := GetJSON(Lines.Text);
        try
          Lines.Clear;
          if Data.JSONType = jtArray then
            for I := 0 to TJSONArray(Data).Count - 1 do
              if TJSONArray(Data).Items[I].JSONType = jtObject then
              begin
                PathText := TJSONObject(TJSONArray(Data).Items[I]).Get('path', '');
                ExeText := TJSONObject(TJSONArray(Data).Items[I]).Get('executable', '');
                if (PathText = '') or (ExeText = '') then
                  Continue;
                EngineFileName := IncludeTrailingPathDelimiter(PathText) + ExeText;
                HubId := Trim(TJSONObject(TJSONArray(Data).Items[I]).Get('hub_id', ''));
                DxpId := Trim(TJSONObject(TJSONArray(Data).Items[I]).Get('dxp_id', ''));

                if HubId <> '' then
                  AddRegisteredEngine(HubId + ' (Engine ' + IntToStr(I + 1) +
                    ' Hub mode)', EngineFileName, 'hub');
                if DxpId <> '' then
                  AddRegisteredEngine(DxpId + ' (Engine ' + IntToStr(I + 1) +
                    ' DXP mode)', EngineFileName, 'dxp');
              end;
        finally
          Data.Free;
        end;
      end
      else
        Lines.Clear;

      if EngineList.Items.Count = 0 then
        EngineList.Items.Add('(no registered engines)');
      if EngineList.Items.Count > 0 then
        EngineList.ItemIndex := 0;

      OKButton := TButton.Create(Dialog);
      OKButton.Parent := Dialog;
      OKButton.Caption := 'Open';
      OKButton.Default := True;
      OKButton.ModalResult := mrOK;
      OKButton.SetBounds(320, 304, 88, 28);

      BrowseButton := TButton.Create(Dialog);
      BrowseButton.Parent := Dialog;
      BrowseButton.Caption := 'Browse...';
      BrowseButton.ModalResult := mrYes;
      BrowseButton.SetBounds(416, 304, 88, 28);

      CancelButton := TButton.Create(Dialog);
      CancelButton.Parent := Dialog;
      CancelButton.Caption := 'Cancel';
      CancelButton.Cancel := True;
      CancelButton.ModalResult := mrCancel;
      CancelButton.SetBounds(516, 304, 88, 28);

      repeat
        CenterDialogOnMainWindow(Dialog);
        case Dialog.ShowModal of
          mrOK:
            begin
              SelectedIndex := EngineList.ItemIndex;
              if (SelectedIndex < 0) or (SelectedIndex >= Lines.Count) then
              begin
                MessageDlg('Open engine',
                  'Please select a registered engine, or use Browse...',
                  mtInformation, [mbOK], 0);
                Continue;
              end;
              AFileName := Lines[SelectedIndex];
              APreferredProtocol := Protocols[SelectedIndex];
              Result := True;
              Exit;
            end;
          mrYes:
            begin
              if FEngineOpenDialog.Execute then
              begin
                AFileName := FEngineOpenDialog.FileName;
                APreferredProtocol := '';
                Result := True;
                Exit;
              end;
            end;
        else
          Exit;
        end;
      until False;
    finally
      Lines.Free;
    end;
  finally
    Dialog.Free;
    Protocols.Free;
  end;
end;

function TMainWindow.ShowEngineLaunchOptionsDialog(AEngineIndex: Integer;
  const APreferredProtocol: String): Boolean;
var
  BlackLabel: TLabel;
  BrowseIniButton: TButton;
  CancelButton: TButton;
  Dialog: TForm;
  DxpGroup: TGroupBox;
  DxpIdEdit: TEdit;
  DxpIdLabel: TLabel;
  HubArgumentEdit: TEdit;
  HubGroup: TGroupBox;
  HubIdEdit: TEdit;
  HubIdLabel: TLabel;
  IniEdit: TEdit;
  IniFileName: String;
  IniLabel: TLabel;
  IniMemo: TMemo;
  IpEdit: TEdit;
  IpLabel: TLabel;
  LaunchEdit: TEdit;
  LaunchLabel: TLabel;
  OKButton: TButton;
  OtherEngineIndex: Integer;
  ProtocolGroup: TRadioGroup;
  RoleCombo: TComboBox;
  RoleLabel: TLabel;
  SocketEdit: TSpinEdit;
  SocketLabel: TLabel;

  function DxpPortUsedByOtherEngine(APort: Integer; const AIpAddress: String;
    out AOtherEngineIndex: Integer): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    AOtherEngineIndex := 0;

    for I := Low(FEngines) to High(FEngines) do
      if (I <> AEngineIndex) and (FEngines[I] <> nil) and
        (FEngines[I].Protocol = epDxp) and
        (FEngines[I].DxpRole = edrClient) and
        ((FEngines[I].DxpThread <> nil) or (FEngines[I].DxpSocket <> nil)) and
        SameText(FEngines[I].DxpIpAddress, AIpAddress) and
        (StrToIntDef(FEngines[I].DxpSocketNumber, 0) = APort) then
      begin
        AOtherEngineIndex := I;
        Exit(True);
      end;
  end;

  function ParamValue(const AParams: TEngineParamArray;
    const AName, ADefault: String): String;
  var
    I: Integer;
  begin
    Result := ADefault;
    for I := 0 to High(AParams) do
      if SameText(AParams[I].Name, AName) then
        Exit(AParams[I].Value);
  end;

  function ParamExists(const AParams: TEngineParamArray;
    const AName: String): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    for I := 0 to High(AParams) do
      if SameText(AParams[I].Name, AName) then
        Exit(True);
  end;

  function NextDefaultProtocolId(const APrefix, ASection,
    AParamName: String): String;
  var
    Data: TJSONData;
    EngineFileName: String;
    ExeText: String;
    I: Integer;
    Item: TJSONObject;
    Lines: TStringList;
    MaxId: Integer;
    Params: TEngineParamArray;
    ParamsFileName: String;
    PathText: String;
    P: Integer;
    Suffix: String;
    SupportedCount: Integer;
    Value: String;

  begin
    MaxId := 0;
    SupportedCount := 0;
    if FileExists(RegisteredEnginesFileName) then
    begin
      Lines := TStringList.Create;
      try
        Lines.LoadFromFile(RegisteredEnginesFileName);
        Data := GetJSON(Lines.Text);
      finally
        Lines.Free;
      end;
      try
        if Data.JSONType = jtArray then
          for I := 0 to TJSONArray(Data).Count - 1 do
            if TJSONArray(Data).Items[I].JSONType = jtObject then
            begin
              Item := TJSONObject(TJSONArray(Data).Items[I]);
              if SameText(ASection, 'dxp') then
                Value := Trim(Item.Get('dxp_id', ''))
              else
                Value := Trim(Item.Get('hub_id', ''));
              if Value = '' then
              begin
                PathText := Item.Get('path', '');
                ExeText := Item.Get('executable', '');
                if (PathText <> '') and (ExeText <> '') then
                begin
                  EngineFileName := IncludeTrailingPathDelimiter(PathText) + ExeText;
                  ParamsFileName := EngineParamsFileNameForDisplayName('',
                    EngineFileName);
                  SetLength(Params, 0);
                  LoadParamsFromJson(ParamsFileName, ASection, Params);
                  Value := Trim(ParamValue(Params, AParamName, ''));
                  if (Value = '') and ParamExists(Params, AParamName) then
                    Continue;
                end;
              end;
              if Value = '' then
                Continue;
              Inc(SupportedCount);
              if not AnsiStartsText(APrefix, Value) then
                Continue;
              Suffix := Copy(Value, Length(APrefix) + 1,
                Length(Value) - Length(APrefix));
              P := StrToIntDef(Suffix, 0);
              if P > MaxId then
                MaxId := P;
            end;
      finally
        Data.Free;
      end;
    end;
    Result := APrefix + IntToStr(Max(MaxId, SupportedCount) + 1);
  end;

  function RegisteredProtocolIdForCurrentEngine(const AProtocol: String): String;
  var
    Data: TJSONData;
    EngineFileName: String;
    ExeText: String;
    I: Integer;
    Item: TJSONObject;
    Lines: TStringList;
    PathText: String;
    SelectedFileName: String;
  begin
    Result := '';
    if not FileExists(RegisteredEnginesFileName) then
      Exit;

    SelectedFileName := ExpandFileName(FEngines[AEngineIndex].FileName);
    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(RegisteredEnginesFileName);
      Data := GetJSON(Lines.Text);
    finally
      Lines.Free;
    end;
    try
      if Data.JSONType <> jtArray then
        Exit;
      for I := 0 to TJSONArray(Data).Count - 1 do
        if TJSONArray(Data).Items[I].JSONType = jtObject then
        begin
          Item := TJSONObject(TJSONArray(Data).Items[I]);
          PathText := Item.Get('path', '');
          ExeText := Item.Get('executable', '');
          if (PathText = '') or (ExeText = '') then
            Continue;
          EngineFileName := ExpandFileName(IncludeTrailingPathDelimiter(PathText) +
            ExeText);
          if not SameText(EngineFileName, SelectedFileName) then
            Continue;
          if SameText(AProtocol, 'dxp') then
            Result := Trim(Item.Get('dxp_id', ''))
          else
            Result := Trim(Item.Get('hub_id', ''));
          Exit;
        end;
    finally
      Data.Free;
    end;
  end;

  function RegisteredDxpPortUsed(APort: Integer; const AIpAddress: String): Boolean;
  var
    Data: TJSONData;
    EngineFileName: String;
    ExeText: String;
    I: Integer;
    IdText: String;
    Item: TJSONObject;
    Lines: TStringList;
    Params: TEngineParamArray;
    ParamsFileName: String;
    PathText: String;
    RegisteredFileName: String;
    ReportedIdText: String;
    SelectedFileName: String;

    function FindParamsFile: String;
    begin
      Result := '';
      if IdText <> '' then
      begin
        Result := EngineParamsFileNameForDisplayName(IdText, EngineFileName);
        if FileExists(Result) then
          Exit;
      end;
      if ReportedIdText <> '' then
      begin
        Result := EngineParamsFileNameForDisplayName(ReportedIdText,
          EngineFileName);
        if FileExists(Result) then
          Exit;
      end;
      Result := EngineParamsFileNameForDisplayName(
        ChangeFileExt(ExeText, ''), EngineFileName);
      if not FileExists(Result) then
        Result := '';
    end;

  begin
    Result := False;
    RegisteredFileName := RegisteredEnginesFileName;
    if not FileExists(RegisteredFileName) then
      Exit;

    SelectedFileName := ExpandFileName(FEngines[AEngineIndex].FileName);
    Lines := TStringList.Create;
    try
      Lines.LoadFromFile(RegisteredFileName);
      Data := GetJSON(Lines.Text);
    finally
      Lines.Free;
    end;
    try
      if Data.JSONType <> jtArray then
        Exit;

      for I := 0 to TJSONArray(Data).Count - 1 do
        if TJSONArray(Data).Items[I].JSONType = jtObject then
        begin
          Item := TJSONObject(TJSONArray(Data).Items[I]);
          PathText := Item.Get('path', '');
          ExeText := Item.Get('executable', '');
          if (PathText = '') or (ExeText = '') then
            Continue;
          EngineFileName := ExpandFileName(IncludeTrailingPathDelimiter(PathText) +
            ExeText);
          if SameText(EngineFileName, SelectedFileName) then
            Continue;

          IdText := Item.Get('id', '');
          ReportedIdText := Item.Get('reported_id', '');
          ParamsFileName := FindParamsFile;
          if ParamsFileName = '' then
            Continue;

          SetLength(Params, 0);
          LoadParamsFromJson(ParamsFileName, Params);
          if SameText(ParamValue(Params, EngineTypeParamName, ''), 'dxp') and
            (SameText(ParamValue(Params, DxpRoleParamName, ''), 'connect') or
            SameText(ParamValue(Params, DxpRoleParamName, ''), 'client')) and
            SameText(ParamValue(Params, DxpIpParamName, DxpDefaultIp),
              AIpAddress) and
            (StrToIntDef(ParamValue(Params, DxpSocketParamName, ''), 0) =
              APort) then
            Exit(True);
        end;
    finally
      Data.Free;
    end;
  end;

  function NextAvailableDxpPort(AStartPort: Integer; const AIpAddress: String): Integer;
  begin
    Result := AStartPort;
    if Result < 1 then
      Result := StrToIntDef(DxpDefaultSocket, 27531);
    if Result < 1 then
      Result := 27531;

    while (Result <= 65535) and
      (DxpPortUsedByOtherEngine(Result, AIpAddress, OtherEngineIndex) or
      RegisteredDxpPortUsed(Result, AIpAddress)) do
      Inc(Result);
    if Result > 65535 then
      Result := AStartPort;
  end;

  function DxpPortConflictsWithOtherEngine(out AOtherEngineIndex: Integer): Boolean;
  begin
    Result := False;
    AOtherEngineIndex := 0;
    if ProtocolGroup.ItemIndex <> 1 then
      Exit;
    if RoleCombo.ItemIndex <> 1 then
      Exit;

    Result := DxpPortUsedByOtherEngine(SocketEdit.Value, Trim(IpEdit.Text),
      AOtherEngineIndex);
  end;

  function DxpLaunchModeLooksInconsistent: Boolean;
  var
    LaunchText: String;
  begin
    Result := False;
    if ProtocolGroup.ItemIndex <> 1 then
      Exit;
    if RoleCombo.ItemIndex <> 0 then
      Exit;

    LaunchText := LowerCase(LaunchEdit.Text);
    Result := (Pos('dxp_client', LaunchText) > 0) or
      (Pos('dxp-client', LaunchText) > 0);
  end;

  function FindIniFileForEngine(const AEngineFileName: String): String;
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

  procedure PreferDefaultProtocolForDialog;
  var
    DxpParams: TEngineParamArray;
    HubParams: TEngineParamArray;

    function SectionSupportsProtocol(const AParams: TEngineParamArray;
      const AIdParamName: String): Boolean;
    begin
      Result := Length(AParams) > 0;
      if not Result then
        Exit;
      if ParamExists(AParams, AIdParamName) then
        Result := Trim(ParamValue(AParams, AIdParamName, '')) <> '';
    end;

  begin
    if FEngines[AEngineIndex].ParamsFileName = '' then
      Exit;
    if not FileExists(FEngines[AEngineIndex].ParamsFileName) then
      Exit;

    SetLength(HubParams, 0);
    SetLength(DxpParams, 0);
    LoadParamsFromJson(FEngines[AEngineIndex].ParamsFileName, 'hub', HubParams);
    LoadParamsFromJson(FEngines[AEngineIndex].ParamsFileName, 'dxp', DxpParams);

    if SectionSupportsProtocol(HubParams, HubIdParamName) then
      FEngines[AEngineIndex].Params := HubParams
    else if SectionSupportsProtocol(DxpParams, DxpIdParamName) then
      FEngines[AEngineIndex].Params := DxpParams
    else
      Exit;

    LoadHubLaunchArgumentFromParams(AEngineIndex);
  end;
begin
  Result := False;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  PreferDefaultProtocolForDialog;
  if SameText(APreferredProtocol, 'dxp') then
    FEngines[AEngineIndex].Protocol := epDxp
  else if SameText(APreferredProtocol, 'hub') then
    FEngines[AEngineIndex].Protocol := epHub;

  Dialog := TForm.Create(Self);
  try
    Dialog.Caption := 'Open engine';
    Dialog.Width := 600;
    Dialog.Height := 642;
    Dialog.Position := poDesigned;
    Dialog.BorderStyle := bsDialog;

    ProtocolGroup := TRadioGroup.Create(Dialog);
    ProtocolGroup.Parent := Dialog;
    ProtocolGroup.Caption := 'Engine type';
    ProtocolGroup.Items.Add('Hub engine');
    ProtocolGroup.Items.Add('DXP engine');
    if FEngines[AEngineIndex].Protocol = epDxp then
      ProtocolGroup.ItemIndex := 1
    else
      ProtocolGroup.ItemIndex := 0;
    ProtocolGroup.SetBounds(12, 10, 560, 64);

    HubGroup := TGroupBox.Create(Dialog);
    HubGroup.Parent := Dialog;
    HubGroup.Caption := 'Hub';
    HubGroup.SetBounds(12, 84, 560, 96);

    HubIdLabel := TLabel.Create(HubGroup);
    HubIdLabel.Parent := HubGroup;
    HubIdLabel.Caption := 'HUB ID';
    HubIdLabel.SetBounds(12, 26, 136, 22);

    HubIdEdit := TEdit.Create(HubGroup);
    HubIdEdit.Parent := HubGroup;
    HubIdEdit.Text := RegisteredProtocolIdForCurrentEngine('hub');
    if Trim(HubIdEdit.Text) = '' then
      HubIdEdit.Text := NextDefaultProtocolId('Hub', 'hub', HubIdParamName);
    if Trim(HubIdEdit.Text) = '' then
      HubIdEdit.Text := NextDefaultProtocolId('Hub', 'hub', HubIdParamName);
    HubIdEdit.SetBounds(156, 22, 384, 26);

    BlackLabel := TLabel.Create(HubGroup);
    BlackLabel.Parent := HubGroup;
    BlackLabel.Caption := 'Hub launch args';
    BlackLabel.SetBounds(12, 60, 136, 22);

    HubArgumentEdit := TEdit.Create(HubGroup);
    HubArgumentEdit.Parent := HubGroup;
    HubArgumentEdit.Text := FEngines[AEngineIndex].HubLaunchArgument;
    HubArgumentEdit.SetBounds(156, 56, 384, 26);

    DxpGroup := TGroupBox.Create(Dialog);
    DxpGroup.Parent := Dialog;
    DxpGroup.Caption := 'DXP';
    DxpGroup.SetBounds(12, 190, 560, 172);

    DxpIdLabel := TLabel.Create(DxpGroup);
    DxpIdLabel.Parent := DxpGroup;
    DxpIdLabel.Caption := 'DXP ID';
    DxpIdLabel.SetBounds(12, 26, 80, 22);

    DxpIdEdit := TEdit.Create(DxpGroup);
    DxpIdEdit.Parent := DxpGroup;
    DxpIdEdit.Text := RegisteredProtocolIdForCurrentEngine('dxp');
    if Trim(DxpIdEdit.Text) = '' then
      DxpIdEdit.Text := NextDefaultProtocolId('DXP', 'dxp', DxpIdParamName);
    if Trim(DxpIdEdit.Text) = '' then
      DxpIdEdit.Text := NextDefaultProtocolId('DXP', 'dxp', DxpIdParamName);
    DxpIdEdit.SetBounds(100, 22, 440, 26);

    IpLabel := TLabel.Create(DxpGroup);
    IpLabel.Parent := DxpGroup;
    IpLabel.Caption := 'IPv4';
    IpLabel.SetBounds(12, 60, 80, 22);

    IpEdit := TEdit.Create(DxpGroup);
    IpEdit.Parent := DxpGroup;
    IpEdit.Text := FEngines[AEngineIndex].DxpIpAddress;
    IpEdit.SetBounds(100, 56, 150, 26);

    SocketLabel := TLabel.Create(DxpGroup);
    SocketLabel.Parent := DxpGroup;
    SocketLabel.Caption := 'Socket';
    SocketLabel.SetBounds(270, 60, 60, 22);

    SocketEdit := TSpinEdit.Create(DxpGroup);
    SocketEdit.Parent := DxpGroup;
    SocketEdit.MinValue := 1;
    SocketEdit.MaxValue := 65535;
    SocketEdit.Value := StrToIntDef(FEngines[AEngineIndex].DxpSocketNumber,
      StrToIntDef(DxpDefaultSocket, 27531));
    SocketEdit.Value := NextAvailableDxpPort(SocketEdit.Value,
      Trim(IpEdit.Text));
    SocketEdit.SetBounds(340, 56, 90, 26);

    RoleLabel := TLabel.Create(DxpGroup);
    RoleLabel.Parent := DxpGroup;
    RoleLabel.Caption := 'Socket mode';
    RoleLabel.SetBounds(12, 94, 100, 22);

    RoleCombo := TComboBox.Create(DxpGroup);
    RoleCombo.Parent := DxpGroup;
    RoleCombo.Style := csDropDownList;
    RoleCombo.Items.Add('GUI connects to engine listener');
    RoleCombo.Items.Add('GUI listens for engine connection');
    if FEngines[AEngineIndex].DxpRole = edrClient then
      RoleCombo.ItemIndex := 1
    else
      RoleCombo.ItemIndex := 0;
    RoleCombo.SetBounds(120, 90, 300, 26);

    LaunchLabel := TLabel.Create(DxpGroup);
    LaunchLabel.Parent := DxpGroup;
    LaunchLabel.Caption := 'DXP launch args';
    LaunchLabel.SetBounds(12, 134, 136, 22);

    LaunchEdit := TEdit.Create(DxpGroup);
    LaunchEdit.Parent := DxpGroup;
    LaunchEdit.Text := FEngines[AEngineIndex].DxpLaunchArguments;
    LaunchEdit.ShowHint := True;
    LaunchEdit.Hint := 'Placeholders: {ip}, {port}';
    LaunchEdit.SetBounds(156, 130, 384, 26);

    IniLabel := TLabel.Create(Dialog);
    IniLabel.Parent := Dialog;
    IniLabel.Caption := 'INI file';
    IniLabel.SetBounds(24, 376, 136, 22);

    IniEdit := TEdit.Create(Dialog);
    IniEdit.Name := 'EngineIniEdit';
    IniEdit.Parent := Dialog;
    IniEdit.ReadOnly := True;
    IniFileName := FEngines[AEngineIndex].IniFileName;
    if IniFileName = '' then
      IniFileName := FindIniFileForEngine(FEngines[AEngineIndex].FileName);
    IniEdit.Text := IniFileName;
    if IniFileName = '' then
      IniEdit.Text := '(none found)';
    IniEdit.Hint := ExtractFilePath(FEngines[AEngineIndex].FileName);
    IniEdit.ShowHint := True;
    IniEdit.OnClick := @EngineIniBrowseClick;
    IniEdit.SetBounds(168, 372, 344, 26);

    BrowseIniButton := TButton.Create(Dialog);
    BrowseIniButton.Parent := Dialog;
    BrowseIniButton.Caption := '...';
    BrowseIniButton.Hint := ExtractFilePath(FEngines[AEngineIndex].FileName);
    BrowseIniButton.ShowHint := True;
    BrowseIniButton.OnClick := @EngineIniBrowseClick;
    BrowseIniButton.SetBounds(520, 372, 32, 26);

    IniMemo := TMemo.Create(Dialog);
    IniMemo.Name := 'EngineIniMemo';
    IniMemo.Parent := Dialog;
    IniMemo.ScrollBars := ssBoth;
    IniMemo.WordWrap := False;
    IniMemo.SetBounds(168, 404, 384, 140);
    if (IniFileName <> '') and FileExists(IniFileName) then
    begin
      try
        IniMemo.Lines.LoadFromFile(IniFileName);
      except
        on E: Exception do
        begin
          IniMemo.Clear;
          IniMemo.Lines.Add('; Could not load INI file: ' + E.Message);
        end;
      end;
    end
    else
    begin
      IniMemo.ReadOnly := True;
      IniMemo.Lines.Text := '';
    end;

    OKButton := TButton.Create(Dialog);
    OKButton.Parent := Dialog;
    OKButton.Caption := 'OK';
    OKButton.ModalResult := mrOK;
    OKButton.Default := True;
    OKButton.SetBounds(384, 568, 88, 28);

    CancelButton := TButton.Create(Dialog);
    CancelButton.Parent := Dialog;
    CancelButton.Caption := 'Cancel';
    CancelButton.ModalResult := mrCancel;
    CancelButton.Cancel := True;
    CancelButton.SetBounds(484, 568, 88, 28);

    repeat
      CenterDialogOnMainWindow(Dialog);
      if Dialog.ShowModal <> mrOK then
        Exit;

      if DxpLaunchModeLooksInconsistent then
      begin
        MessageDlg('Open engine',
          'These DXP launch args look like they start an engine that connects ' +
          'to the GUI. Please set Socket mode to "GUI listens for engine ' +
          'connection".',
          mtError, [mbOK], 0);
        Continue;
      end;

      if DxpPortConflictsWithOtherEngine(OtherEngineIndex) then
      begin
        MessageDlg('Open engine',
          EngineLogName(OtherEngineIndex) +
          ' has already been configured for DXP port ' +
          IntToStr(SocketEdit.Value) + '. Please select another port.',
          mtError, [mbOK], 0);
        Continue;
      end;

      Break;
    until False;

    if ProtocolGroup.ItemIndex = 1 then
      FEngines[AEngineIndex].Protocol := epDxp
    else
      FEngines[AEngineIndex].Protocol := epHub;
    FEngines[AEngineIndex].HubId := Trim(HubIdEdit.Text);
    if FEngines[AEngineIndex].HubId = '' then
      FEngines[AEngineIndex].HubId :=
        NextDefaultProtocolId('Hub', 'hub', HubIdParamName);
    FEngines[AEngineIndex].HubLaunchArgument := HubArgumentEdit.Text;
    FEngines[AEngineIndex].DxpId := Trim(DxpIdEdit.Text);
    if FEngines[AEngineIndex].DxpId = '' then
      FEngines[AEngineIndex].DxpId :=
        NextDefaultProtocolId('DXP', 'dxp', DxpIdParamName);
    FEngines[AEngineIndex].DxpIpAddress := Trim(IpEdit.Text);
    if FEngines[AEngineIndex].DxpIpAddress = '' then
      FEngines[AEngineIndex].DxpIpAddress := DxpDefaultIp;
    FEngines[AEngineIndex].DxpSocketNumber := IntToStr(SocketEdit.Value);
    FEngines[AEngineIndex].DxpLaunchArguments := LaunchEdit.Text;
    if RoleCombo.ItemIndex = 1 then
      FEngines[AEngineIndex].DxpRole := edrClient
    else
      FEngines[AEngineIndex].DxpRole := edrListener;
    IniFileName := Trim(IniEdit.Text);
    if IniFileName = '(none found)' then
      IniFileName := '';
    FEngines[AEngineIndex].IniFileName := IniFileName;
    if IniFileName <> '' then
    begin
      try
        IniMemo.Lines.SaveToFile(IniFileName);
      except
        on E: Exception do
          MessageDlg('Could not save INI file:' + LineEnding + IniFileName +
            LineEnding + E.Message, mtError, [mbOK], 0);
      end;
    end;
    SyncHubLaunchArgumentParam(AEngineIndex);
    if FEngines[AEngineIndex].ParamsFileName <> '' then
      SaveParamsToJson(FEngines[AEngineIndex].ParamsFileName,
        FEngines[AEngineIndex].Params);
    Result := True;
  finally
    Dialog.Free;
  end;
end;

procedure TMainWindow.OpenEngineMenuItemClick(Sender: TObject);
var
  FileName: String;
  PreferredProtocol: String;
begin
  if ShowEngineLauncherDialog(1, FileName, PreferredProtocol) then
  begin
    try
      StartEngine(FileName, False, True, PreferredProtocol);
    except
      on E: Exception do
        MessageDlg('Open engine', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainWindow.OpenSecondEngineMenuItemClick(Sender: TObject);
var
  FileName: String;
  PreferredProtocol: String;
begin
  if not EngineIsRunning then
  begin
    AppendEngine2Log('[please load engine 1 first]' + LineEnding);
    Exit;
  end;

  if ShowEngineLauncherDialog(2, FileName, PreferredProtocol) then
  begin
    try
      StartSecondEngine(FileName, False, True, PreferredProtocol);
    except
      on E: Exception do
        MessageDlg('Open engine', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainWindow.EnginePopupMenuPopup(Sender: TObject);
begin
  UpdateEnginePopupMenuItems;
end;

procedure TMainWindow.EditEngineParamsMenuItemClick(Sender: TObject);
var
  Dialog: TEngineParamDialog;
begin
  Dialog := TEngineParamDialog.Create(Self);
  SyncHubLaunchArgumentParam(1);
  SyncSendStartingPositionParam(1);
  SyncSingleCapturesIncludeCapturedSquareParam(1);
  RemoveAnalyzeSendsInfoParam(1);
  SyncEngineSupportsMctsParam(1);
  SyncScorePerspectiveParam(1);
  SyncEvaluationDepthMinParam(1);
  SyncEvaluationBarMaxParam(1);
  Dialog.SetParams(FEngines[1].Params);
  Dialog.LoadIniFromEngineFile(FEngines[1].FileName);
  Dialog.OnHide := @EngineParamsDialogHide;
  CenterDialogOnMainWindow(Dialog);
  Dialog.Show;
end;

procedure TMainWindow.EditSecondEngineParamsMenuItemClick(Sender: TObject);
var
  Dialog: TEngineParamDialog;
begin
  Dialog := TEngineParamDialog.Create(Self);
  SyncHubLaunchArgumentParam(2);
  SyncSendStartingPositionParam(2);
  SyncSingleCapturesIncludeCapturedSquareParam(2);
  RemoveAnalyzeSendsInfoParam(2);
  SyncEngineSupportsMctsParam(2);
  SyncScorePerspectiveParam(2);
  SyncEvaluationDepthMinParam(2);
  SyncEvaluationBarMaxParam(2);
  Dialog.SetParams(FEngines[2].Params);
  Dialog.LoadIniFromEngineFile(FEngines[2].FileName);
  Dialog.OnHide := @Engine2ParamsDialogHide;
  CenterDialogOnMainWindow(Dialog);
  Dialog.Show;
end;

procedure TMainWindow.EngineParamsDialogHide(Sender: TObject);
var
  Dialog: TEngineParamDialog;
  RestartAfterSave: Boolean;
  RestartFileName: String;
begin
  if not (Sender is TEngineParamDialog) then
    Exit;

  Dialog := TEngineParamDialog(Sender);
  if Dialog.ModalResult = mrOK then
  begin
    RestartAfterSave := EngineIsRunning and (FEngines[1].FileName <> '');
    RestartFileName := FEngines[1].FileName;
    FEngines[1].Params := Dialog.Params;
    LoadHubLaunchArgumentFromParams(1);
    SyncHubLaunchArgumentParam(1);
    SyncSendStartingPositionParam(1);
    SyncSingleCapturesIncludeCapturedSquareParam(1);
    RemoveAnalyzeSendsInfoParam(1);
    SyncEngineSupportsMctsParam(1);
    SyncScorePerspectiveParam(1);
    SyncEvaluationDepthMinParam(1);
    SyncEvaluationBarMaxParam(1);
    if FEngines[1].ParamsFileName = '' then
      FEngines[1].ParamsFileName :=
        EngineParamsFileNameForDisplayName(FEngines[1].DisplayName,
          FEngines[1].FileName);
    SaveParamsToJson(FEngines[1].ParamsFileName, FEngines[1].Params);
    AppendEngineLog('[saved engine parameters to ' + FEngines[1].ParamsFileName + ']' +
      LineEnding);
    if RestartAfterSave then
    begin
      AppendEngineLog('[restarting engine after parameter change]' + LineEnding);
      StartEngine(RestartFileName, True);
    end;
  end;
  Dialog.Release;
end;

procedure TMainWindow.Engine2ParamsDialogHide(Sender: TObject);
var
  Dialog: TEngineParamDialog;
  RestartAfterSave: Boolean;
  RestartFileName: String;
begin
  if not (Sender is TEngineParamDialog) then
    Exit;

  Dialog := TEngineParamDialog(Sender);
  if Dialog.ModalResult = mrOK then
  begin
    RestartAfterSave := SecondEngineIsRunning and (FEngines[2].FileName <> '');
    RestartFileName := FEngines[2].FileName;
    FEngines[2].Params := Dialog.Params;
    LoadHubLaunchArgumentFromParams(2);
    SyncHubLaunchArgumentParam(2);
    SyncSendStartingPositionParam(2);
    SyncSingleCapturesIncludeCapturedSquareParam(2);
    RemoveAnalyzeSendsInfoParam(2);
    SyncEngineSupportsMctsParam(2);
    SyncScorePerspectiveParam(2);
    SyncEvaluationDepthMinParam(2);
    SyncEvaluationBarMaxParam(2);
    if FEngines[2].ParamsFileName = '' then
      FEngines[2].ParamsFileName :=
        EngineParamsFileNameForDisplayName(FEngines[2].DisplayName, FEngines[2].FileName);
    SaveParamsToJson(FEngines[2].ParamsFileName, FEngines[2].Params);
    AppendEngine2Log('[saved engine parameters to ' + FEngines[2].ParamsFileName + ']' +
      LineEnding);
    if RestartAfterSave then
    begin
      AppendEngine2Log('[restarting engine after parameter change]' + LineEnding);
      StartSecondEngine(RestartFileName, True);
    end;
  end;
  Dialog.Release;
end;

procedure TMainWindow.HandleEngineIdLine(const ALine: String);
var
  NewDisplayName: String;
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

  if (NewDisplayName = FEngines[1].DisplayName) and
    (NewDisplayName = FEngines[1].HubId) then
    Exit;

  FEngines[1].DisplayName := NewDisplayName;
  if FEngines[1].Protocol = epHub then
  begin
    FEngines[1].HubId := NewDisplayName;
    AddOrUpdateParam(FEngines[1].Params, HubIdParamName, 'string',
      FEngines[1].HubId, False);
    if FEngines[1].ParamsFileName <> '' then
      SaveParamsToJson(FEngines[1].ParamsFileName, 'hub', FEngines[1].Params);
    UpdateRegisteredEngineId(FEngines[1].FileName, FEngines[1].HubId, 'hub');
  end;
  AppendEngineLog('[' + EngineLogName(1) + ' name: ' +
    FEngines[1].DisplayName + ']' + LineEnding);
end;

procedure TMainWindow.HandleEngine2IdLine(const ALine: String);
var
  NewDisplayName: String;
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

  if (NewDisplayName = FEngines[2].DisplayName) and
    (NewDisplayName = FEngines[2].HubId) then
    Exit;

  FEngines[2].DisplayName := NewDisplayName;
  if FEngines[2].Protocol = epHub then
  begin
    FEngines[2].HubId := NewDisplayName;
    AddOrUpdateParam(FEngines[2].Params, HubIdParamName, 'string',
      FEngines[2].HubId, False);
    if FEngines[2].ParamsFileName <> '' then
      SaveParamsToJson(FEngines[2].ParamsFileName, 'hub', FEngines[2].Params);
    UpdateRegisteredEngineId(FEngines[2].FileName, FEngines[2].HubId, 'hub');
  end;
  AppendEngine2Log('[' + EngineLogName(2) + ' name: ' +
    FEngines[2].DisplayName + ']' + LineEnding);
end;

procedure TMainWindow.StartEngine(const AFileName: String; AUseCurrentParams: Boolean;
  AShowLaunchOptions: Boolean; const APreferredProtocol: String);
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
var
  I: Integer;
  LaunchArgs: TStringList;
  OtherEngineIndex: Integer;
begin
  CloseEngine;
  FEngines[1].LogMemo.Clear;
  FEngines[1].LogMemo.Lines.Add('Engine: ' + AFileName);
  FEngines[1].FileName := AFileName;
  if not AUseCurrentParams then
  begin
    FEngines[1].DisplayName := ChangeFileExt(ExtractFileName(AFileName), '');
    FEngines[1].ParamsFileName := EngineParamsFileNameForDisplayName(
      FEngines[1].DisplayName, FEngines[1].FileName);
    LoadParamsFromJson(FEngines[1].ParamsFileName, FEngines[1].Params);
  end;
  LoadHubLaunchArgumentFromParams(1);
  SyncSendStartingPositionParam(1);
  SyncSingleCapturesIncludeCapturedSquareParam(1);
  RemoveAnalyzeSendsInfoParam(1);
  SyncEngineSupportsMctsParam(1);
  SyncScorePerspectiveParam(1);
  SyncEvaluationDepthMinParam(1);
  SyncEvaluationBarMaxParam(1);
  if AShowLaunchOptions and
    (not ShowEngineLaunchOptionsDialog(1, APreferredProtocol)) then
    Exit;
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
  FPendingAnalyzeStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  LeavePlayGameMode;
  FEngineSearching := False;
  ResetEngineSlotRuntime(1);
  FEngineStartAfterReady := True;
  FEngineStopRequested := False;
  FIgnoreNextDoneMove := False;
  if (FEngines[1].Protocol = epDxp) and (FEngines[1].DxpRole = edrClient) then
  begin
    if DxpListenerPortInUse(1, OtherEngineIndex) then
      raise Exception.Create(EngineLogName(OtherEngineIndex) +
        ' has already been configured for DXP port ' +
        FEngines[1].DxpSocketNumber + '. Please select another port.');
    if not StartDxpConnection(1) then
    begin
      AppendEngineLog('[engine launch aborted: DXP listener is not ready]' +
        LineEnding);
      Exit;
    end;
  end;

  LaunchArgs := TStringList.Create;
  try
    EngineLaunchArguments(FEngines[1], LaunchArgs);
    AppendEngineLog('[launch params file: ' + FEngines[1].ParamsFileName + ']' +
      LineEnding);
    if FEngines[1].Protocol = epDxp then
      AppendEngineLog('[launch protocol: DXP]' + LineEnding +
        '[launch DXP id: ' + FEngines[1].DxpId + ']' + LineEnding +
        '[launch DXP args: ' + LaunchArgs.DelimitedText + ']' + LineEnding)
    else
      AppendEngineLog('[launch protocol: HUB]' + LineEnding +
        '[launch HUB args: ' + LaunchArgs.DelimitedText + ']' + LineEnding);
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
  for I := 0 to LaunchArgs.Count - 1 do
    CommandLine += ' ' + CommandLineQuote(LaunchArgs[I]);
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
  for I := 0 to LaunchArgs.Count - 1 do
    FEngines[1].Process.Parameters.Add(LaunchArgs[I]);
  FEngines[1].Process.CurrentDirectory := ExtractFilePath(AFileName);
  FEngines[1].Process.Options := [poUsePipes, poStderrToOutput];
  FEngines[1].Process.ShowWindow := swoHIDE;
  AppendEngineLog('[' + EngineLogName(1) + ' execute begin]' +
    LineEnding);
  AppendEngineLog('[' + EngineLogName(1) + ' cwd ' + FEngines[1].Process.CurrentDirectory + ']' +
    LineEnding);
  FEngines[1].Process.Execute;
  {$ENDIF}
  UpdateEnginePollTimer;
  AppendEngineLog('[' + EngineLogName(1) + ' execute returned' +
    ' running=' + BoolToStr(EngineIsRunning, True) + ']' + LineEnding);
  RegisterEngineExecutable(AFileName);
  if (FEngines[1].Protocol = epDxp) and (Trim(FEngines[1].DxpId) <> '') then
    UpdateRegisteredEngineId(AFileName, Trim(FEngines[1].DxpId), 'dxp')
  else if (FEngines[1].Protocol = epHub) and (Trim(FEngines[1].HubId) <> '') then
    UpdateRegisteredEngineId(AFileName, Trim(FEngines[1].HubId), 'hub');

  if FEngines[1].Protocol = epDxp then
  begin
    if Trim(FEngines[1].DxpId) <> '' then
      FEngines[1].DisplayName := Trim(FEngines[1].DxpId);
    if FAutoPlayButton <> nil then
      FAutoPlayButton.Enabled := False;
    if FGoButton <> nil then
      FGoButton.Enabled := True;
    if FMctsButton <> nil then
      FMctsButton.Enabled := True;
    if FStopButton <> nil then
      FStopButton.Enabled := True;
    if FEngines[1].DxpId <> '' then
      AppendEngineLog('[DXP id=' + FEngines[1].DxpId + ']' + LineEnding);
    if FEngines[1].DxpRole = edrClient then
      AppendEngineLog('[DXP socket mode=listen ip=' + FEngines[1].DxpIpAddress +
        ' socket=' + FEngines[1].DxpSocketNumber + ']' + LineEnding)
    else
      AppendEngineLog('[DXP socket mode=connect ip=' + FEngines[1].DxpIpAddress +
        ' socket=' + FEngines[1].DxpSocketNumber + ']' + LineEnding);
    if FEngines[1].DxpLaunchArguments <> '' then
      AppendEngineLog('[DXP launch arguments: ' + FEngines[1].DxpLaunchArguments +
        ']' + LineEnding);
    if FEngines[1].DxpRole = edrListener then
      StartDxpConnection(1);
  end
  else
  begin
    if FEngines[1].HubLaunchArgument <> '' then
      AppendEngineLog('[hub launch argument: ' + FEngines[1].HubLaunchArgument +
      ']' + LineEnding);
    AppendEngineLog('> hub' + LineEnding);
    SendEngineCommand('hub');
  end;
  {$IFDEF MSWINDOWS}
  if Parent2ChildRead <> 0 then
    CloseHandle(Parent2ChildRead);
  if Child2ParentWrite <> 0 then
    CloseHandle(Child2ParentWrite);
  {$ENDIF}
  finally
    LaunchArgs.Free;
  end;
  UpdateEnginePopupMenuItems;
end;

procedure TMainWindow.StartSecondEngine(const AFileName: String;
  AUseCurrentParams: Boolean; AShowLaunchOptions: Boolean;
  const APreferredProtocol: String);
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
var
  I: Integer;
  LaunchArgs: TStringList;
  OtherEngineIndex: Integer;
begin
  CloseSecondEngine;
  FEngines[2].LogMemo.Clear;
  FEngines[2].LogMemo.Lines.Add('Engine 2: ' + AFileName);
  FEngines[2].FileName := AFileName;
  if not AUseCurrentParams then
  begin
    FEngines[2].DisplayName := ChangeFileExt(ExtractFileName(AFileName), '');
    FEngines[2].ParamsFileName := EngineParamsFileNameForDisplayName(FEngines[2].DisplayName,
      FEngines[2].FileName);
    LoadParamsFromJson(FEngines[2].ParamsFileName, FEngines[2].Params);
  end;
  LoadHubLaunchArgumentFromParams(2);
  SyncSendStartingPositionParam(2);
  SyncSingleCapturesIncludeCapturedSquareParam(2);
  RemoveAnalyzeSendsInfoParam(2);
  SyncEngineSupportsMctsParam(2);
  SyncScorePerspectiveParam(2);
  SyncEvaluationDepthMinParam(2);
  SyncEvaluationBarMaxParam(2);
  if AShowLaunchOptions and
    (not ShowEngineLaunchOptionsDialog(2, APreferredProtocol)) then
    Exit;
  if Length(FEngines[2].Params) > 0 then
    FEngines[2].LogMemo.Lines.Add('Loaded parameters: ' + FEngines[2].ParamsFileName);
  ResetEngineSlotRuntime(2);
  if (FEngines[2].Protocol = epDxp) and (FEngines[2].DxpRole = edrClient) then
  begin
    if DxpListenerPortInUse(2, OtherEngineIndex) then
      raise Exception.Create(EngineLogName(OtherEngineIndex) +
        ' has already been configured for DXP port ' +
        FEngines[2].DxpSocketNumber + '. Please select another port.');
    if not StartDxpConnection(2) then
    begin
      AppendEngine2Log('[engine launch aborted: DXP listener is not ready]' +
        LineEnding);
      Exit;
    end;
  end;

  LaunchArgs := TStringList.Create;
  try
    EngineLaunchArguments(FEngines[2], LaunchArgs);
    AppendEngine2Log('[launch params file: ' + FEngines[2].ParamsFileName + ']' +
      LineEnding);
    if FEngines[2].Protocol = epDxp then
      AppendEngine2Log('[launch protocol: DXP]' + LineEnding +
        '[launch DXP id: ' + FEngines[2].DxpId + ']' + LineEnding +
        '[launch DXP args: ' + LaunchArgs.DelimitedText + ']' + LineEnding)
    else
      AppendEngine2Log('[launch protocol: HUB]' + LineEnding +
        '[launch HUB args: ' + LaunchArgs.DelimitedText + ']' + LineEnding);
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
  for I := 0 to LaunchArgs.Count - 1 do
    CommandLine += ' ' + CommandLineQuote(LaunchArgs[I]);
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
  for I := 0 to LaunchArgs.Count - 1 do
    FEngines[2].Process.Parameters.Add(LaunchArgs[I]);
  FEngines[2].Process.CurrentDirectory := ExtractFilePath(AFileName);
  FEngines[2].Process.Options := [poUsePipes, poStderrToOutput];
  FEngines[2].Process.ShowWindow := swoHIDE;
  AppendEngine2Log('[' + EngineLogName(2) + ' execute begin]' +
    LineEnding);
  AppendEngine2Log('[' + EngineLogName(2) + ' cwd ' + FEngines[2].Process.CurrentDirectory + ']' +
    LineEnding);
  FEngines[2].Process.Execute;
  {$ENDIF}
  UpdateEnginePollTimer;
  AppendEngine2Log('[' + EngineLogName(2) + ' execute returned' +
    ' running=' + BoolToStr(SecondEngineIsRunning, True) + ']' + LineEnding);
  RegisterEngineExecutable(AFileName);
  if (FEngines[2].Protocol = epDxp) and (Trim(FEngines[2].DxpId) <> '') then
    UpdateRegisteredEngineId(AFileName, Trim(FEngines[2].DxpId), 'dxp')
  else if (FEngines[2].Protocol = epHub) and (Trim(FEngines[2].HubId) <> '') then
    UpdateRegisteredEngineId(AFileName, Trim(FEngines[2].HubId), 'hub');

  if FEngines[2].Protocol = epDxp then
  begin
    if Trim(FEngines[2].DxpId) <> '' then
      FEngines[2].DisplayName := Trim(FEngines[2].DxpId);
    if FEngines[2].DxpId <> '' then
      AppendEngine2Log('[DXP id=' + FEngines[2].DxpId + ']' + LineEnding);
    if FEngines[2].DxpRole = edrClient then
      AppendEngine2Log('[DXP socket mode=listen ip=' + FEngines[2].DxpIpAddress +
        ' socket=' + FEngines[2].DxpSocketNumber + ']' + LineEnding)
    else
      AppendEngine2Log('[DXP socket mode=connect ip=' + FEngines[2].DxpIpAddress +
        ' socket=' + FEngines[2].DxpSocketNumber + ']' + LineEnding);
    if FEngines[2].DxpLaunchArguments <> '' then
      AppendEngine2Log('[DXP launch arguments: ' + FEngines[2].DxpLaunchArguments +
        ']' + LineEnding);
  end
  else
  begin
    if FEngines[2].HubLaunchArgument <> '' then
      AppendEngine2Log('[hub launch argument: ' + FEngines[2].HubLaunchArgument +
      ']' + LineEnding);
    AppendEngine2Log('> hub' + LineEnding);
    SendSecondEngineCommand('hub');
  end;
  {$IFDEF MSWINDOWS}
  if Parent2ChildRead <> 0 then
    CloseHandle(Parent2ChildRead);
  if Child2ParentWrite <> 0 then
    CloseHandle(Child2ParentWrite);
  {$ENDIF}
  finally
    LaunchArgs.Free;
  end;
  UpdateEnginePopupMenuItems;
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
    esAnalyzing: Result := 'analyzing';
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
    esAnalyzing: Result := 'Analyzing';
    esMcts: Result := 'MCTS';
    esThinking: Result := 'Thinking';
    esWaitingForOtherEngine: Result := 'Waiting';
  else
    Result := 'Unknown';
  end;
end;

function TMainWindow.GuiStateText(AState: TGuiState): String;
begin
  case AState of
    gsIdle: Result := 'Idle';
    gsAnalyzing: Result := 'Analyzing';
    gsMcts: Result := 'MCTS';
    gsAutoPlaying: Result := 'Auto-playing';
    gsPlayGameHumanTurn: Result := 'Play-game human turn';
    gsPlayGameEngineTurn: Result := 'Play-game engine turn';
    gsTournamentRunning: Result := 'Tournament running';
    gsStopping: Result := 'Stopping';
    gsGameOver: Result := 'Game over';
  else
    Result := 'Unknown';
  end;
end;

function EngineStateNeedsStop(AState: TEngineState): Boolean;
begin
  Result := AState in [esAnalyzing, esMcts, esThinking];
end;

function CommandLineQuote(const AText: String): String;
var
  I: Integer;
  NeedsQuotes: Boolean;
begin
  NeedsQuotes := AText = '';
  for I := 1 to Length(AText) do
    if AText[I] in [' ', #9, '"'] then
      NeedsQuotes := True;

  if not NeedsQuotes then
    Exit(AText);

  Result := '"';
  for I := 1 to Length(AText) do
  begin
    if AText[I] = '"' then
      Result += '\"'
    else
      Result += AText[I];
  end;
  Result += '"';
end;

procedure SplitLaunchArguments(const AText: String; AArgs: TStrings);
var
  Current: String;
  I: Integer;
  InQuotes: Boolean;
  QuoteChar: Char;
begin
  if AArgs = nil then
    Exit;

  AArgs.Clear;
  Current := '';
  InQuotes := False;
  QuoteChar := #0;
  I := 1;
  while I <= Length(AText) do
  begin
    if InQuotes then
    begin
      if AText[I] = QuoteChar then
      begin
        InQuotes := False;
        QuoteChar := #0;
      end
      else if (AText[I] = '\') and (I < Length(AText)) then
      begin
        Inc(I);
        Current += AText[I];
      end
      else
        Current += AText[I];
    end
    else if AText[I] in ['"', ''''] then
    begin
      InQuotes := True;
      QuoteChar := AText[I];
    end
    else if AText[I] in [' ', #9, #10, #13] then
    begin
      if Current <> '' then
      begin
        AArgs.Add(Current);
        Current := '';
      end;
    end
    else
      Current += AText[I];
    Inc(I);
  end;

  if Current <> '' then
    AArgs.Add(Current);
end;

function ExpandLaunchArgumentPlaceholders(AEngine: TEngineSlot;
  const AText: String): String;
begin
  Result := AText;
  if AEngine = nil then
    Exit;

  Result := StringReplace(Result, '{ip}', AEngine.DxpIpAddress,
    [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{port}', AEngine.DxpSocketNumber,
    [rfReplaceAll, rfIgnoreCase]);
end;

procedure EngineLaunchArguments(AEngine: TEngineSlot; AArgs: TStrings);
begin
  if AEngine = nil then
    Exit;
  if AEngine.Protocol = epDxp then
    SplitLaunchArguments(ExpandLaunchArgumentPlaceholders(AEngine,
      AEngine.DxpLaunchArguments), AArgs)
  else
    SplitLaunchArguments(AEngine.HubLaunchArgument, AArgs);
end;

procedure RemoveEngineParam(var AParams: TEngineParamArray; const AName: String);
var
  I: Integer;
  J: Integer;
begin
  for I := 0 to High(AParams) do
    if SameText(AParams[I].Name, AName) then
    begin
      for J := I to High(AParams) - 1 do
        AParams[J] := AParams[J + 1];
      SetLength(AParams, Length(AParams) - 1);
      Exit;
  end;
end;

procedure TMainWindow.SyncHubLaunchArgumentParam(AEngineIndex: Integer);
var
  ProtocolText: String;
  RoleText: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if FEngines[AEngineIndex].Protocol = epDxp then
    ProtocolText := 'dxp'
  else
    ProtocolText := 'hub';
  if FEngines[AEngineIndex].DxpRole = edrClient then
    RoleText := 'connect'
  else
    RoleText := 'listen';
  AddOrUpdateParam(FEngines[AEngineIndex].Params, EngineTypeParamName,
    'string', ProtocolText, False);
  if Trim(FEngines[AEngineIndex].HubId) = '' then
    FEngines[AEngineIndex].HubId := 'Hub' + IntToStr(AEngineIndex);
  AddOrUpdateParam(FEngines[AEngineIndex].Params, HubIdParamName,
    'string', FEngines[AEngineIndex].HubId, False);
  AddOrUpdateParam(FEngines[AEngineIndex].Params, EngineIniFileParamName,
    'string', FEngines[AEngineIndex].IniFileName, False);
  AddOrUpdateParam(FEngines[AEngineIndex].Params, HubLaunchArgumentParamName,
    'string', FEngines[AEngineIndex].HubLaunchArgument, False);
  if Trim(FEngines[AEngineIndex].DxpId) = '' then
    FEngines[AEngineIndex].DxpId := 'DXP' + IntToStr(AEngineIndex);
  AddOrUpdateParam(FEngines[AEngineIndex].Params, DxpIdParamName,
    'string', FEngines[AEngineIndex].DxpId, False);
  AddOrUpdateParam(FEngines[AEngineIndex].Params, DxpIpParamName,
    'string', FEngines[AEngineIndex].DxpIpAddress, False);
  AddOrUpdateParam(FEngines[AEngineIndex].Params, DxpSocketParamName,
    'int', FEngines[AEngineIndex].DxpSocketNumber, False);
  AddOrUpdateParam(FEngines[AEngineIndex].Params, DxpLaunchArgumentsParamName,
    'string', FEngines[AEngineIndex].DxpLaunchArguments, False);
  AddOrUpdateParam(FEngines[AEngineIndex].Params, DxpRoleParamName,
    'string', RoleText, False);
  RemoveEngineParam(FEngines[AEngineIndex].Params, OldHubLaunchArgumentParamName);
  RemoveEngineParam(FEngines[AEngineIndex].Params, OldLaunchWithHubArgumentParamName);
end;

procedure TMainWindow.SyncSendStartingPositionParam(AEngineIndex: Integer);
var
  I: Integer;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      OldSendStartingPositionParamName) then
    begin
      AddOrUpdateParam(FEngines[AEngineIndex].Params,
        SendStartingPositionParamName, 'bool',
        FEngines[AEngineIndex].Params[I].Value, False);
      RemoveEngineParam(FEngines[AEngineIndex].Params,
        OldSendStartingPositionParamName);
      Exit;
    end;
  AddOrUpdateParam(FEngines[AEngineIndex].Params, SendStartingPositionParamName,
    'bool', 'true', True);
end;

procedure TMainWindow.SyncSingleCapturesIncludeCapturedSquareParam(
  AEngineIndex: Integer);
var
  I: Integer;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      OldSingleCapturesIncludeCapturedSquareParamName) then
    begin
      AddOrUpdateParam(FEngines[AEngineIndex].Params,
        SingleCapturesIncludeCapturedSquareParamName, 'bool',
        FEngines[AEngineIndex].Params[I].Value, False);
      RemoveEngineParam(FEngines[AEngineIndex].Params,
        OldSingleCapturesIncludeCapturedSquareParamName);
      Exit;
    end;
  AddOrUpdateParam(FEngines[AEngineIndex].Params,
    SingleCapturesIncludeCapturedSquareParamName, 'bool', 'true', True);
end;

procedure TMainWindow.RemoveAnalyzeSendsInfoParam(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  RemoveEngineParam(FEngines[AEngineIndex].Params, AnalyzeSendsInfoParamName);
  RemoveEngineParam(FEngines[AEngineIndex].Params, OldAnalyzeSendsInfoParamName);
end;

procedure TMainWindow.SyncEngineSupportsMctsParam(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  AddOrUpdateParam(FEngines[AEngineIndex].Params, EngineSupportsMctsParamName,
    'bool', 'false', True);
end;

procedure TMainWindow.SyncScorePerspectiveParam(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  AddOrUpdateParam(FEngines[AEngineIndex].Params, ScorePerspectiveParamName,
    'string', 'side-to-move', True);
end;

procedure TMainWindow.SyncEvaluationDepthMinParam(AEngineIndex: Integer);
var
  I: Integer;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      OldEvaluationDepthMinParamName) then
    begin
      AddOrUpdateParam(FEngines[AEngineIndex].Params,
        EvaluationDepthMinParamName, 'int',
        FEngines[AEngineIndex].Params[I].Value, False);
      RemoveEngineParam(FEngines[AEngineIndex].Params,
        OldEvaluationDepthMinParamName);
      Exit;
    end;
  AddOrUpdateParam(FEngines[AEngineIndex].Params, EvaluationDepthMinParamName,
    'int', '4', True);
end;

procedure TMainWindow.SyncEvaluationBarMaxParam(AEngineIndex: Integer);
var
  I: Integer;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      OldEvaluationBarMaxParamName) then
    begin
      AddOrUpdateParam(FEngines[AEngineIndex].Params,
        EvaluationBarMaxParamName, 'int',
        FEngines[AEngineIndex].Params[I].Value, False);
      RemoveEngineParam(FEngines[AEngineIndex].Params,
        OldEvaluationBarMaxParamName);
      Exit;
    end;
  AddOrUpdateParam(FEngines[AEngineIndex].Params, EvaluationBarMaxParamName,
    'int', '1000', True);
end;

procedure TMainWindow.LoadHubLaunchArgumentFromParams(AEngineIndex: Integer);
var
  I: Integer;
  OldBoolValue: String;
  Value: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  FEngines[AEngineIndex].Protocol := epHub;
  FEngines[AEngineIndex].HubId := 'Hub' + IntToStr(AEngineIndex);
  FEngines[AEngineIndex].IniFileName := '';
  FEngines[AEngineIndex].HubLaunchArgument := '';
  FEngines[AEngineIndex].DxpId := 'DXP' + IntToStr(AEngineIndex);
  FEngines[AEngineIndex].DxpIpAddress := DxpDefaultIp;
  FEngines[AEngineIndex].DxpSocketNumber := DxpDefaultSocket;
  FEngines[AEngineIndex].DxpLaunchArguments := '';
  FEngines[AEngineIndex].DxpRole := edrListener;

  for I := 0 to High(FEngines[AEngineIndex].Params) do
  begin
    Value := FEngines[AEngineIndex].Params[I].Value;
    if SameText(FEngines[AEngineIndex].Params[I].Name, EngineTypeParamName) then
    begin
      if SameText(Value, 'dxp') then
        FEngines[AEngineIndex].Protocol := epDxp
      else
        FEngines[AEngineIndex].Protocol := epHub;
    end
    else if SameText(FEngines[AEngineIndex].Params[I].Name,
      HubIdParamName) then
      FEngines[AEngineIndex].HubId := Trim(Value)
    else if SameText(FEngines[AEngineIndex].Params[I].Name,
      EngineIniFileParamName) then
      FEngines[AEngineIndex].IniFileName := Trim(Value)
    else if SameText(FEngines[AEngineIndex].Params[I].Name,
      DxpIdParamName) then
      FEngines[AEngineIndex].DxpId := Trim(Value)
    else if SameText(FEngines[AEngineIndex].Params[I].Name,
      DxpIpParamName) and (Trim(Value) <> '') then
      FEngines[AEngineIndex].DxpIpAddress := Trim(Value)
    else if SameText(FEngines[AEngineIndex].Params[I].Name,
      DxpSocketParamName) and (Trim(Value) <> '') then
      FEngines[AEngineIndex].DxpSocketNumber := Trim(Value)
    else if SameText(FEngines[AEngineIndex].Params[I].Name,
      DxpLaunchArgumentsParamName) then
      FEngines[AEngineIndex].DxpLaunchArguments := Value
    else if SameText(FEngines[AEngineIndex].Params[I].Name,
      DxpRoleParamName) then
    begin
      if SameText(Value, 'client') or SameText(Value, 'connect') then
        FEngines[AEngineIndex].DxpRole := edrClient
      else
        FEngines[AEngineIndex].DxpRole := edrListener;
    end;
  end;

  if Trim(FEngines[AEngineIndex].HubId) = '' then
    FEngines[AEngineIndex].HubId := 'Hub' + IntToStr(AEngineIndex);
  if Trim(FEngines[AEngineIndex].DxpId) = '' then
    FEngines[AEngineIndex].DxpId := 'DXP' + IntToStr(AEngineIndex);

  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      HubLaunchArgumentParamName) then
    begin
      FEngines[AEngineIndex].HubLaunchArgument := FEngines[AEngineIndex].Params[I].Value;
      SyncHubLaunchArgumentParam(AEngineIndex);
      Exit;
    end;

  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      OldHubLaunchArgumentParamName) then
    begin
      FEngines[AEngineIndex].HubLaunchArgument := FEngines[AEngineIndex].Params[I].Value;
      SyncHubLaunchArgumentParam(AEngineIndex);
      Exit;
    end;

  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      OldLaunchWithHubArgumentParamName) then
    begin
      OldBoolValue := FEngines[AEngineIndex].Params[I].Value;
      if SameText(OldBoolValue, 'true') then
        FEngines[AEngineIndex].HubLaunchArgument := 'hub'
      else
        FEngines[AEngineIndex].HubLaunchArgument := '';
      SyncHubLaunchArgumentParam(AEngineIndex);
      Exit;
    end;

  SyncHubLaunchArgumentParam(AEngineIndex);
end;

function TMainWindow.EngineSendStartingPosition(AEngineIndex: Integer): Boolean;
var
  I: Integer;
begin
  Result := True;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      SendStartingPositionParamName) then
    begin
      Result := not SameText(FEngines[AEngineIndex].Params[I].Value, 'false');
      Exit;
    end;
end;

function TMainWindow.EngineSingleCapturesIncludeCapturedSquare(
  AEngineIndex: Integer): Boolean;
var
  I: Integer;
begin
  Result := True;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      SingleCapturesIncludeCapturedSquareParamName) then
    begin
      Result := not SameText(FEngines[AEngineIndex].Params[I].Value, 'false');
      Exit;
    end;
end;

function TMainWindow.EngineSupportsMcts(AEngineIndex: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      EngineSupportsMctsParamName) then
    begin
      Result := SameText(FEngines[AEngineIndex].Params[I].Value, 'true');
      Exit;
    end;
end;

function TMainWindow.EngineScorePerspective(AEngineIndex: Integer): String;
var
  I: Integer;
begin
  Result := 'side-to-move';
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      ScorePerspectiveParamName) then
    begin
      Result := LowerCase(Trim(FEngines[AEngineIndex].Params[I].Value));
      if Result = '' then
        Result := 'side-to-move';
      Exit;
    end;
end;

function TMainWindow.EngineEvaluationDepthMin(AEngineIndex: Integer): Double;
var
  FormatSettings: TFormatSettings;
  I: Integer;
  Value: Double;
begin
  Result := 4.0;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      EvaluationDepthMinParamName) then
    begin
      if TryStrToFloat(FEngines[AEngineIndex].Params[I].Value, Value,
        FormatSettings) and (Value >= 0.0) then
        Result := Value;
      Exit;
    end;
end;

function TMainWindow.EngineEvaluationBarMax(AEngineIndex: Integer): Double;
var
  FormatSettings: TFormatSettings;
  I: Integer;
  Value: Double;
begin
  Result := EvalBarDefaultMaxScore;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  for I := 0 to High(FEngines[AEngineIndex].Params) do
    if SameText(FEngines[AEngineIndex].Params[I].Name,
      EvaluationBarMaxParamName) then
    begin
      if TryStrToFloat(FEngines[AEngineIndex].Params[I].Value, Value,
        FormatSettings) and (Value > 0.0) then
        Result := Value;
      Exit;
    end;
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
  SetEngineSlotState(1, AState);
end;

procedure TMainWindow.SetSecondEngineState(AState: TEngineState);
begin
  SetEngineSlotState(2, AState);
end;

procedure TMainWindow.SetGuiState(AState: TGuiState; const AReason: String);
var
  Line: String;
  OldState: TGuiState;
begin
  OldState := FGuiState;
  FGuiState := AState;

  Line := '[GUI state: ' + GuiStateText(OldState);
  if OldState <> AState then
    Line += ' -> ' + GuiStateText(AState);
  Line += '; ' + EngineLogName(1) + ': ' +
    EngineStateLogText(FEngines[1].State);
  Line += '; ' + EngineLogName(2) + ': ' +
    EngineStateLogText(FEngines[2].State);
  if AReason <> '' then
    Line += '; reason=' + AReason;
  Line += ']' + LineEnding;

  AppendEngineLog(Line);
  if SecondEngineIsRunning then
    AppendEngine2Log(Line);
end;

procedure TMainWindow.SetEngineSlotState(AEngineIndex: Integer;
  AState: TEngineState);
var
  OldState: TEngineState;
  Slot: TEngineSlot;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  Slot := FEngines[AEngineIndex];
  if Slot.State = AState then
    Exit;

  OldState := Slot.State;
  Slot.State := AState;
  UpdateEngineStateLabels;
  if AEngineIndex = 2 then
    AppendEngine2Log('[' + EngineLogName(AEngineIndex) + ' state: ' +
      EngineStateLogText(OldState) + ' -> ' + EngineStateLogText(Slot.State) +
      '; GUI: ' + GuiStateText(FGuiState) + ']' + LineEnding)
  else
    AppendEngineLog('[' + EngineLogName(AEngineIndex) + ' state: ' +
      EngineStateLogText(OldState) + ' -> ' + EngineStateLogText(Slot.State) +
      '; GUI: ' + GuiStateText(FGuiState) + ']' + LineEnding);
end;

procedure TMainWindow.BeginEngineSlotSearch(AEngineIndex: Integer;
  AMode: TEngineSearchMode; AState: TEngineState);
var
  OldState: TEngineState;
  Slot: TEngineSlot;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  Slot := FEngines[AEngineIndex];
  OldState := Slot.State;
  Slot.BeginSearch(AMode, AState);
  if OldState <> AState then
  begin
    UpdateEngineStateLabels;
    if AEngineIndex = 2 then
      AppendEngine2Log('[' + EngineLogName(AEngineIndex) + ' state: ' +
        EngineStateLogText(OldState) + ' -> ' + EngineStateLogText(Slot.State) +
        '; GUI: ' + GuiStateText(FGuiState) + ']' + LineEnding)
    else
      AppendEngineLog('[' + EngineLogName(AEngineIndex) + ' state: ' +
        EngineStateLogText(OldState) + ' -> ' + EngineStateLogText(Slot.State) +
        '; GUI: ' + GuiStateText(FGuiState) + ']' + LineEnding);
  end;
end;

procedure TMainWindow.FinishEngineSlotSearch(AEngineIndex: Integer);
var
  OldState: TEngineState;
  Slot: TEngineSlot;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  Slot := FEngines[AEngineIndex];
  OldState := Slot.State;
  Slot.FinishSearch;
  UpdateEngineStateLabels;
  if OldState <> esIdle then
    if AEngineIndex = 2 then
      AppendEngine2Log('[' + EngineLogName(AEngineIndex) + ' state: ' +
        EngineStateLogText(OldState) + ' -> idle; GUI: ' +
        GuiStateText(FGuiState) + ']' + LineEnding)
    else
      AppendEngineLog('[' + EngineLogName(AEngineIndex) + ' state: ' +
        EngineStateLogText(OldState) + ' -> idle; GUI: ' +
        GuiStateText(FGuiState) + ']' + LineEnding);
end;

procedure TMainWindow.ResetEngineSlotRuntime(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  FEngines[AEngineIndex].ResetRuntimeState;
  UpdateEngineStateLabels;
end;

function TMainWindow.DxpGameStateText(AState: TDxpGameState): String;
begin
  case AState of
    dgsIdle: Result := 'idle';
    dgsGameRequested: Result := 'game requested';
    dgsWaitingForMoveOrGameEnd: Result := 'waiting for DXP_MOVE or DXP_GAMEEND';
    dgsGameEnding: Result := 'game ending';
    dgsWaitingForNextGame: Result := 'waiting for DXP_GAMEREQ';
  else
    Result := 'unknown';
  end;
end;

procedure TMainWindow.SetDxpGameState(AEngineIndex: Integer;
  AState: TDxpGameState);
var
  Slot: TEngineSlot;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  Slot := FEngines[AEngineIndex];
  if Slot.DxpGameState = AState then
    Exit;

  Slot.DxpGameState := AState;
  if AEngineIndex = 2 then
    AppendEngine2Log('[DXP state: ' + DxpGameStateText(AState) + ']' +
      LineEnding)
  else
    AppendEngineLog('[DXP state: ' + DxpGameStateText(AState) + ']' +
      LineEnding);
end;

procedure TMainWindow.MarkDxpWaitingForReply(AEngineIndex: Integer;
  AMode: TEngineSearchMode);
begin
  if AMode = esmPlayGameThink then
    ActivateGameClocks;
  SetDxpGameState(AEngineIndex, dgsWaitingForMoveOrGameEnd);
  BeginEngineSlotSearch(AEngineIndex, AMode, esThinking);
end;

function TMainWindow.DxpShouldAcceptMove(AEngineIndex: Integer;
  ASearchMode: TEngineSearchMode): Boolean;
begin
  Result := False;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if FEngines[AEngineIndex].DxpGameState <> dgsWaitingForMoveOrGameEnd then
    Exit;

  if ASearchMode = esmAutoPlay then
    Result := FAutoPlayActive
  else
    Result := FPlayGameActive;
end;

function TMainWindow.DxpListenerPortInUse(AEngineIndex: Integer;
  out AOtherEngineIndex: Integer): Boolean;
var
  I: Integer;
begin
  Result := False;
  AOtherEngineIndex := 0;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if (FEngines[AEngineIndex].Protocol <> epDxp) or
    (FEngines[AEngineIndex].DxpRole <> edrClient) then
    Exit;

  for I := Low(FEngines) to High(FEngines) do
    if (I <> AEngineIndex) and (FEngines[I] <> nil) and
      (FEngines[I].Protocol = epDxp) and
      (FEngines[I].DxpRole = edrClient) and
      ((FEngines[I].DxpThread <> nil) or (FEngines[I].DxpSocket <> nil)) and
      SameText(FEngines[I].DxpIpAddress, FEngines[AEngineIndex].DxpIpAddress) and
      (StrToIntDef(FEngines[I].DxpSocketNumber, 0) =
       StrToIntDef(FEngines[AEngineIndex].DxpSocketNumber, 0)) then
    begin
      AOtherEngineIndex := I;
      Exit(True);
    end;
end;

function TMainWindow.StartDxpConnection(AEngineIndex: Integer): Boolean;
var
  I: Integer;
  LogText: String;
  OtherEngineIndex: Integer;
  Port: Integer;
begin
  Result := False;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if FEngines[AEngineIndex].Protocol <> epDxp then
    Exit;

  StopDxpConnection(AEngineIndex);

  Port := StrToIntDef(FEngines[AEngineIndex].DxpSocketNumber,
    StrToIntDef(DxpDefaultSocket, 27531));
  if (Port < 1) or (Port > 65535) then
  begin
    LogText := '[invalid DXP socket: ' + FEngines[AEngineIndex].DxpSocketNumber +
      ']' + LineEnding;
    if AEngineIndex = 2 then
      AppendEngine2Log(LogText)
    else
      AppendEngineLog(LogText);
    Exit;
  end;

  if DxpListenerPortInUse(AEngineIndex, OtherEngineIndex) then
  begin
    LogText := '[' + EngineLogName(OtherEngineIndex) +
      ' has already been configured for DXP port ' + IntToStr(Port) +
      '. Please select another port]' + LineEnding;
    if AEngineIndex = 2 then
      AppendEngine2Log(LogText)
    else
      AppendEngineLog(LogText);
    Exit;
  end;

  FEngines[AEngineIndex].Ready := False;
  FEngines[AEngineIndex].DxpThread := TEngineDxpConnectionThread.Create(Self,
    AEngineIndex, FEngines[AEngineIndex].DxpIpAddress, Word(Port),
    FEngines[AEngineIndex].DxpRole);

  if FEngines[AEngineIndex].DxpRole = edrClient then
  begin
    for I := 1 to 200 do
    begin
      if (FEngines[AEngineIndex].DxpThread = nil) or
        FEngines[AEngineIndex].DxpThread.Listening then
        Break;
      CheckSynchronize(0);
      Sleep(25);
    end;

    if (FEngines[AEngineIndex].DxpThread <> nil) and
      FEngines[AEngineIndex].DxpThread.Listening then
    begin
      LogText := '[listening for DXP socket connection on 0.0.0.0:' +
        IntToStr(Port) + ' target-ip=' + FEngines[AEngineIndex].DxpIpAddress +
        ']' + LineEnding;
      Result := True;
    end
    else
    begin
      LogText := '[DXP listener did not confirm listening on 0.0.0.0:' +
        IntToStr(Port) + ']' + LineEnding;
      if AEngineIndex = 2 then
        AppendEngine2Log(LogText)
      else
        AppendEngineLog(LogText);
      StopDxpConnection(AEngineIndex);
      Exit;
    end;
  end
  else
  begin
    LogText := '[connecting to DXP socket listener on ' +
      FEngines[AEngineIndex].DxpIpAddress + ':' + IntToStr(Port) + ']' +
      LineEnding;
    Result := True;
  end;

  if AEngineIndex = 2 then
    AppendEngine2Log(LogText)
  else
    AppendEngineLog(LogText);
end;

procedure TMainWindow.StopDxpConnection(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  if (FEngines[AEngineIndex].DxpThread <> nil) or
    (FEngines[AEngineIndex].DxpSocket <> nil) then
    if AEngineIndex = 2 then
      AppendEngine2Log('[stopping DXP connection]' + LineEnding)
    else
      AppendEngineLog('[stopping DXP connection]' + LineEnding);

  if FEngines[AEngineIndex].DxpThread <> nil then
  begin
    FEngines[AEngineIndex].DxpThread.StopConnection;
    FEngines[AEngineIndex].DxpThread.WaitFor;
    FreeAndNil(FEngines[AEngineIndex].DxpThread);
  end;

  if FEngines[AEngineIndex].DxpSocket <> nil then
    FreeAndNil(FEngines[AEngineIndex].DxpSocket);
  SetDxpGameState(AEngineIndex, dgsIdle);
end;

procedure TMainWindow.SendDxpGameReqToEngine(AEngineIndex: Integer;
  AEngineSide: TSide; AGameMinutes: Double);
var
  BoardText: String;
  EngineColourText: Char;
  GameMoves: Integer;
  GameTime: Integer;
  I: Integer;
  MessageText: String;
  NameText: String;
  PieceText: Char;
  SideText: Char;

  function ParamInt(const AName: String; ADefault: Integer): Integer;
  var
    P: Integer;
  begin
    Result := ADefault;
    for P := 0 to High(FEngines[AEngineIndex].Params) do
      if SameText(FEngines[AEngineIndex].Params[P].Name, AName) then
      begin
        Result := StrToIntDef(FEngines[AEngineIndex].Params[P].Value, ADefault);
        Exit;
      end;
  end;

  function Dxp3(AValue: Integer): String;
  begin
    if AValue < 0 then
      AValue := 0;
    if AValue > 999 then
      AValue := 999;
    Result := Format('%.3d', [AValue]);
  end;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if not EngineIsDxp(AEngineIndex) then
    Exit;
  FEngines[AEngineIndex].DxpGameEndSent := False;
  SetDxpGameState(AEngineIndex, dgsGameRequested);

  if FEngines[AEngineIndex].DxpSocket = nil then
  begin
    SetDxpGameState(AEngineIndex, dgsIdle);
    if AEngineIndex = 2 then
      AppendEngine2Log('[DXP_GAMEREQ not sent: no DXP socket]' + LineEnding)
    else
      AppendEngineLog('[DXP_GAMEREQ not sent: no DXP socket]' + LineEnding);
    Exit;
  end;

  NameText := 'International Draughts GUI';
  if Length(NameText) > 32 then
    SetLength(NameText, 32);
  while Length(NameText) < 32 do
    NameText += ' ';

  if AEngineSide = sideWhite then
    EngineColourText := 'W'
  else
    EngineColourText := 'Z';

  GameTime := Round(AGameMinutes);
  if GameTime <= 0 then
    GameTime := 1;
  GameMoves := ParamInt('dxp_game_moves', 75);

  if FSideToMove = sideWhite then
    SideText := 'W'
  else
    SideText := 'Z';

  BoardText := '';
  for I := Low(FBoard) to High(FBoard) do
  begin
    case FBoard[I] of
      pcWhiteMan: PieceText := 'w';
      pcWhiteKing: PieceText := 'W';
      pcBlackMan: PieceText := 'z';
      pcBlackKing: PieceText := 'Z';
    else
      PieceText := 'e';
    end;
    BoardText += PieceText;
  end;

  MessageText := 'R' + '01' + NameText + EngineColourText + Dxp3(GameTime) +
    Dxp3(GameMoves) + 'B' + SideText + BoardText + #0;

  if AEngineIndex = 2 then
    AppendEngine2Log('[Engine is a DXP follower]' + LineEnding)
  else
    AppendEngineLog('[Engine is a DXP follower]' + LineEnding);

  FEngines[AEngineIndex].DxpSocket.WriteBuffer(MessageText[1],
    Length(MessageText));
  SetDxpGameState(AEngineIndex, dgsWaitingForMoveOrGameEnd);

  if AEngineIndex = 2 then
    AppendEngine2Log('> DXP_GAMEREQ ' + Copy(MessageText, 1,
      Length(MessageText) - 1) + LineEnding +
      '[Waiting for DXP_MOVE or DXP_GAMEEND]' + LineEnding)
  else
    AppendEngineLog('> DXP_GAMEREQ ' + Copy(MessageText, 1,
      Length(MessageText) - 1) + LineEnding +
      '[Waiting for DXP_MOVE or DXP_GAMEEND]' + LineEnding);
end;

function TMainWindow.DxpGameEndCodeForEngine(AEngineIndex: Integer): Char;
var
  EngineSide: TSide;
begin
  Result := '0';

  if (FGameResult = '1-1') or (FGameResult = '1/2-1/2') then
    Exit('2');
  if FGameResult = '*' then
    Exit('0');

  if FPlayGameWhiteIsEngine and (FPlayGameWhiteEngineIndex = AEngineIndex) then
    EngineSide := sideWhite
  else if FPlayGameBlackIsEngine and (FPlayGameBlackEngineIndex = AEngineIndex) then
    EngineSide := sideBlack
  else
    Exit('0');

  if ((EngineSide = sideWhite) and (FGameResult = '2-0')) or
    ((EngineSide = sideBlack) and (FGameResult = '0-2')) then
    Result := '1'
  else if ((EngineSide = sideWhite) and (FGameResult = '0-2')) or
    ((EngineSide = sideBlack) and (FGameResult = '2-0')) then
    Result := '3';
end;

function TMainWindow.DxpResultFromGameEnd(AEngineIndex: Integer;
  ACode: Char): String;
var
  EngineSide: TSide;
begin
  Result := '*';

  if ACode = '2' then
    Exit('1-1');
  if ACode = '0' then
    Exit('*');

  if FPlayGameWhiteIsEngine and (FPlayGameWhiteEngineIndex = AEngineIndex) then
    EngineSide := sideWhite
  else if FPlayGameBlackIsEngine and (FPlayGameBlackEngineIndex = AEngineIndex) then
    EngineSide := sideBlack
  else
    Exit('*');

  case ACode of
    '1':
      if EngineSide = sideWhite then
        Result := '0-2'
      else
        Result := '2-0';
    '3':
      if EngineSide = sideWhite then
        Result := '2-0'
      else
        Result := '0-2';
  end;
end;

procedure TMainWindow.SendDxpGameEndToEngine(AEngineIndex: Integer; ACode: Char);
var
  MessageText: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if not EngineIsDxp(AEngineIndex) then
    Exit;
  if FEngines[AEngineIndex].DxpGameEndSent then
  begin
    if AEngineIndex = 2 then
      AppendEngine2Log('[DXP_GAMEEND not sent: already sent]' + LineEnding)
    else
      AppendEngineLog('[DXP_GAMEEND not sent: already sent]' + LineEnding);
    Exit;
  end;
  if FEngines[AEngineIndex].DxpSocket = nil then
  begin
    if AEngineIndex = 2 then
      AppendEngine2Log('[DXP_GAMEEND not sent: no DXP socket]' + LineEnding)
    else
      AppendEngineLog('[DXP_GAMEEND not sent: no DXP socket]' + LineEnding);
    Exit;
  end;

  if not (ACode in ['0'..'3']) then
    ACode := '0';
  MessageText := 'E' + ACode + '0' + #0;
  FEngines[AEngineIndex].DxpSocket.WriteBuffer(MessageText[1],
    Length(MessageText));
  FEngines[AEngineIndex].DxpGameEndSent := True;
  SetDxpGameState(AEngineIndex, dgsGameEnding);

  if AEngineIndex = 2 then
    AppendEngine2Log('> DXP_GAMEEND ' + Copy(MessageText, 1,
      Length(MessageText) - 1) + LineEnding)
  else
    AppendEngineLog('> DXP_GAMEEND ' + Copy(MessageText, 1,
      Length(MessageText) - 1) + LineEnding);
end;

procedure TMainWindow.SendDxpGameEndToPlayingDxpEngines(
  AExcludeEngineIndex: Integer);
begin
  if not FPlayGameActive then
  begin
    if EngineIsRunning and EngineIsDxp(1) then
      AppendEngineLog('[DXP_GAMEEND not sent: no active play game]' +
        LineEnding);
    if SecondEngineIsRunning and EngineIsDxp(2) then
      AppendEngine2Log('[DXP_GAMEEND not sent: no active play game]' +
        LineEnding);
    Exit;
  end;

  if FPlayGameWhiteIsEngine and EngineIsDxp(FPlayGameWhiteEngineIndex) and
    (FPlayGameWhiteEngineIndex <> AExcludeEngineIndex) then
    SendDxpGameEndToEngine(FPlayGameWhiteEngineIndex,
      DxpGameEndCodeForEngine(FPlayGameWhiteEngineIndex));
  if FPlayGameBlackIsEngine and EngineIsDxp(FPlayGameBlackEngineIndex) and
    (FPlayGameBlackEngineIndex <> FPlayGameWhiteEngineIndex) and
    (FPlayGameBlackEngineIndex <> AExcludeEngineIndex) then
    SendDxpGameEndToEngine(FPlayGameBlackEngineIndex,
      DxpGameEndCodeForEngine(FPlayGameBlackEngineIndex));
end;

procedure TMainWindow.SendDxpMoveToEngine(AEngineIndex: Integer;
  const AMove: TMove; ATimeUsedSeconds: Integer);
var
  I: Integer;
  MessageText: String;

  function Dxp2(AValue: Integer): String;
  begin
    if AValue < 0 then
      AValue := 0;
    if AValue > 99 then
      AValue := 99;
    Result := Format('%.2d', [AValue]);
  end;

  function Dxp4(AValue: Integer): String;
  begin
    if AValue < 0 then
      AValue := 0;
    if AValue > 9999 then
      AValue := 9999;
    Result := Format('%.4d', [AValue]);
  end;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if not EngineIsDxp(AEngineIndex) then
    Exit;
  if Length(AMove.Squares) < 2 then
    Exit;

  if FEngines[AEngineIndex].DxpSocket = nil then
  begin
    if AEngineIndex = 2 then
      AppendEngine2Log('[DXP_MOVE not sent: no DXP socket]' + LineEnding)
    else
      AppendEngineLog('[DXP_MOVE not sent: no DXP socket]' + LineEnding);
    Exit;
  end;

  MessageText := 'M' + Dxp4(ATimeUsedSeconds) + Dxp2(AMove.Squares[0]) +
    Dxp2(AMove.Squares[High(AMove.Squares)]) + Dxp2(Length(AMove.Captures));
  for I := 0 to High(AMove.Captures) do
    MessageText += Dxp2(AMove.Captures[I]);
  MessageText += #0;

  FEngines[AEngineIndex].DxpSocket.WriteBuffer(MessageText[1],
    Length(MessageText));
  SetDxpGameState(AEngineIndex, dgsWaitingForMoveOrGameEnd);

  if AEngineIndex = 2 then
    AppendEngine2Log('> DXP_MOVE ' + Copy(MessageText, 1,
      Length(MessageText) - 1) + LineEnding)
  else
    AppendEngineLog('> DXP_MOVE ' + Copy(MessageText, 1,
      Length(MessageText) - 1) + LineEnding);
end;

function DxpMoveMessageToText(const AMessage: String; out AMoveText: String): Boolean;
var
  CaptureCount: Integer;
  FromSquare: Integer;
  I: Integer;
  Offset: Integer;
  ToSquare: Integer;
begin
  Result := False;
  AMoveText := '';
  if (Length(AMessage) < 11) or (AMessage[1] <> 'M') then
    Exit;

  FromSquare := StrToIntDef(Copy(AMessage, 6, 2), 0);
  ToSquare := StrToIntDef(Copy(AMessage, 8, 2), 0);
  CaptureCount := StrToIntDef(Copy(AMessage, 10, 2), -1);
  if (FromSquare < 1) or (FromSquare > 50) or
    (ToSquare < 1) or (ToSquare > 50) or (CaptureCount < 0) then
    Exit;
  if Length(AMessage) < 11 + 2 * CaptureCount then
    Exit;

  if CaptureCount = 0 then
    AMoveText := IntToStr(FromSquare) + '-' + IntToStr(ToSquare)
  else
  begin
    AMoveText := IntToStr(FromSquare) + 'x' + IntToStr(ToSquare);
    Offset := 12;
    for I := 1 to CaptureCount do
    begin
      AMoveText += 'x' + IntToStr(StrToIntDef(Copy(AMessage, Offset, 2), 0));
      Inc(Offset, 2);
    end;
  end;

  Result := True;
end;

procedure TMainWindow.ProcessDxpMessage(AEngineIndex: Integer;
  const AMessage: String);
var
  MoveText: String;
  SearchMode: TEngineSearchMode;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if AMessage = '' then
    Exit;

  if AEngineIndex = 2 then
    AppendEngine2Log('[' + EngineLogName(2) + '] < ' + AMessage + LineEnding)
  else
    AppendEngineLog('[' + EngineLogName(1) + '] < ' + AMessage + LineEnding);

  case AMessage[1] of
    'A':
      begin
        if AEngineIndex = 2 then
          AppendEngine2Log('[DXP_GAMEACC accepted]' + LineEnding)
        else
          AppendEngineLog('[DXP_GAMEACC accepted]' + LineEnding);
      end;
    'M':
      begin
        if not DxpMoveMessageToText(AMessage, MoveText) then
        begin
          if AEngineIndex = 2 then
            AppendEngine2Log('[could not parse DXP_MOVE]' + LineEnding)
          else
            AppendEngineLog('[could not parse DXP_MOVE]' + LineEnding);
          Exit;
        end;

        SearchMode := FEngines[AEngineIndex].SearchMode;
        FinishEngineSlotSearch(AEngineIndex);
        if not DxpShouldAcceptMove(AEngineIndex, SearchMode) then
        begin
          if AEngineIndex = 2 then
            AppendEngine2Log('[ignored late DXP_MOVE ' + MoveText + ']' +
              LineEnding)
          else
            AppendEngineLog('[ignored late DXP_MOVE ' + MoveText + ']' +
              LineEnding);
          Exit;
        end;

        if PlayEngineMove(MoveText, AEngineIndex) then
        begin
          if SearchMode = esmAutoPlay then
          begin
            if not FAutoPlayActive then
              Exit;
            Inc(FAutoPlayPlyCount);
            if Length(FMoves) = 0 then
            begin
              FAutoPlayActive := False;
              SetTerminalResult;
              AppendEngineLog('[auto-play stopped: terminal position]' +
                LineEnding);
            end
            else if FAutoPlayPlyCount >= 255 then
            begin
              FAutoPlayActive := False;
              AppendEngineLog('[auto-play stopped: 255 moves reached]' +
                LineEnding);
            end
            else
              SendGoThinkToEngine(esmAutoPlay);
          end
          else if FPlayGameActive then
          begin
            if Length(FMoves) = 0 then
            begin
              SetTerminalResult;
              LeavePlayGameMode;
              if AEngineIndex = 2 then
                AppendEngine2Log('[play game stopped: terminal position]' +
                  LineEnding)
              else
                AppendEngineLog('[play game stopped: terminal position]' +
                  LineEnding);
            end
            else
            begin
              if (AEngineIndex = 1) and IsPlayGameSecondEngineTurn then
                SetEngineState(esWaitingForOtherEngine)
              else if (AEngineIndex = 2) and IsPlayGameEngineTurn and
                (not IsPlayGameSecondEngineTurn) then
                SetSecondEngineState(esWaitingForOtherEngine);
              ContinuePlayGameSearch;
            end;
          end;
        end
        else
        begin
          if FPlayGameActive then
            LeavePlayGameMode;
          if AEngineIndex = 2 then
            AppendEngine2Log('[play game stopped: ' + EngineLogName(2) +
              ' DXP move could not be played]' + LineEnding)
          else
            AppendEngineLog('[play game stopped: ' + EngineLogName(1) +
              ' DXP move could not be played]' + LineEnding);
        end;
      end;
    'E':
      begin
        FinishEngineSlotSearch(AEngineIndex);
        SetDxpGameState(AEngineIndex, dgsWaitingForNextGame);
        if AEngineIndex = 2 then
          AppendEngine2Log('[DXP_GAMEEND received]' + LineEnding)
        else
          AppendEngineLog('[DXP_GAMEEND received]' + LineEnding);
        if (Length(AMessage) >= 2) and
          (not FEngines[AEngineIndex].DxpGameEndSent) then
          SendDxpGameEndToEngine(AEngineIndex, AMessage[2]);
        if FPlayGameActive then
        begin
          if Length(AMessage) >= 2 then
            FGameResult := DxpResultFromGameEnd(AEngineIndex, AMessage[2])
          else
            FGameResult := '*';
          MarkGameDirty;
          UpdateHistoryList;
          SendDxpGameEndToPlayingDxpEngines(AEngineIndex);
          LeavePlayGameMode;
          if AEngineIndex = 2 then
            SendStopToEngine
          else if SecondEngineIsRunning then
            SendStopToSecondEngine;
        end;
      end;
  end;
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
    if AnsiStartsText('gui-', FEngines[1].Params[I].Name) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, HubLaunchArgumentParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, OldHubLaunchArgumentParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, OldLaunchWithHubArgumentParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, SendStartingPositionParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, OldSendStartingPositionParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name,
      SingleCapturesIncludeCapturedSquareParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name,
      OldSingleCapturesIncludeCapturedSquareParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, AnalyzeSendsInfoParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, OldAnalyzeSendsInfoParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, EngineSupportsMctsParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, ScorePerspectiveParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, EvaluationDepthMinParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, OldEvaluationDepthMinParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, EvaluationBarMaxParamName) then
      Continue;
    if SameText(FEngines[1].Params[I].Name, OldEvaluationBarMaxParamName) then
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
    if AnsiStartsText('gui-', FEngines[2].Params[I].Name) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, HubLaunchArgumentParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, OldHubLaunchArgumentParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, OldLaunchWithHubArgumentParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, SendStartingPositionParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, OldSendStartingPositionParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name,
      SingleCapturesIncludeCapturedSquareParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name,
      OldSingleCapturesIncludeCapturedSquareParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, AnalyzeSendsInfoParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, OldAnalyzeSendsInfoParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, EngineSupportsMctsParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, ScorePerspectiveParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, EvaluationDepthMinParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, OldEvaluationDepthMinParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, EvaluationBarMaxParamName) then
      Continue;
    if SameText(FEngines[2].Params[I].Name, OldEvaluationBarMaxParamName) then
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
    HandleEngineProcessTerminated(1);
  end;
  if (FEngines[2].ProcessInfo.hProcess <> 0) and (not SecondEngineIsRunning) then
  begin
    HandleEngineProcessTerminated(2);
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
    HandleEngineProcessTerminated(1);
  end
  else if FEngines[1].Process <> nil then
    EngineProcessReadData(Sender);

  if (FEngines[2].Process <> nil) and (not FEngines[2].Process.Running) then
  begin
    HandleEngineProcessTerminated(2);
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
  HandleEngineProcessTerminated(1);
end;

procedure TMainWindow.HandleEngineProcessTerminated(AEngineIndex: Integer);
begin
  if (AEngineIndex < 1) or (AEngineIndex > 2) then
    Exit;

  {$IFDEF MSWINDOWS}
  if FEngines[AEngineIndex].ProcessInfo.hProcess = 0 then
    Exit;
  {$ELSE}
  if FEngines[AEngineIndex].Process = nil then
    Exit;
  {$ENDIF}

  if AEngineIndex = 1 then
  begin
    EngineProcessReadData(nil);
    FEngines[1].Ready := False;
    FAutoPlayActive := False;
    FPendingAutoPlayStart := False;
    FPendingMctsStart := False;
    FPendingAnalyzeStart := False;
    FPendingPlayGameStart := False;
    FPendingThinkStart := False;
    LeavePlayGameMode;
    FinishEngineSlotSearch(1);
    if FAutoPlayButton <> nil then
      FAutoPlayButton.Enabled := False;
    if FGoButton <> nil then
      FGoButton.Enabled := False;
    if FMctsButton <> nil then
      FMctsButton.Enabled := False;
    if FStopButton <> nil then
      FStopButton.Enabled := False;
    AppendEngineLog(LineEnding + '[' + EngineLogName(1) +
      ' process terminated]' + LineEnding);
  end
  else
  begin
    EngineProcessReadSecondEngineData;
    FEngines[2].Ready := False;
    FinishEngineSlotSearch(2);
    AppendEngine2Log(LineEnding + '[' + EngineLogName(2) +
      ' process terminated]' + LineEnding);
  end;

  {$IFDEF MSWINDOWS}
  FEngines[AEngineIndex].Running := False;
  if FEngines[AEngineIndex].ReaderThread <> nil then
  begin
    FEngines[AEngineIndex].ReaderThread.Terminate;
  end;
  if FEngines[AEngineIndex].InputWriteHandle <> 0 then
  begin
    CloseHandle(FEngines[AEngineIndex].InputWriteHandle);
    FEngines[AEngineIndex].InputWriteHandle := 0;
  end;
  if FEngines[AEngineIndex].ProcessInfo.hThread <> 0 then
  begin
    CloseHandle(FEngines[AEngineIndex].ProcessInfo.hThread);
    FEngines[AEngineIndex].ProcessInfo.hThread := 0;
  end;
  if FEngines[AEngineIndex].ProcessInfo.hProcess <> 0 then
  begin
    CloseHandle(FEngines[AEngineIndex].ProcessInfo.hProcess);
    FEngines[AEngineIndex].ProcessInfo.hProcess := 0;
  end;
  {$ELSE}
  FreeAndNil(FEngines[AEngineIndex].Process);
  {$ENDIF}

  UpdateEnginePollTimer;
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

procedure ParsePvMoveText(const APvText: String; out AMoves: TTextArray);
var
  Ch: Char;
  I: Integer;
  MoveText: String;

  procedure AppendMove;
  begin
    MoveText := Trim(MoveText);
    if MoveText = '' then
      Exit;
    SetLength(AMoves, Length(AMoves) + 1);
    AMoves[High(AMoves)] := MoveText;
    MoveText := '';
  end;

begin
  SetLength(AMoves, 0);
  MoveText := '';
  for I := 1 to Length(APvText) do
  begin
    Ch := APvText[I];
    if Ch in [' ', #9, #10, #13] then
      AppendMove
    else
      MoveText += Ch;
  end;
  AppendMove;
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
  PathMatches: Boolean;
begin
  if (not ParseMoveNumbers(AEngineMove, Numbers, IsCapture)) or
    (Length(ALegalMove.Squares) < 2) then
    Exit(False);

  if Numbers[0] <> ALegalMove.Squares[0] then
    Exit(False);

  if IsCapture <> (Length(ALegalMove.Captures) > 0) then
    Exit(False);

  if not IsCapture then
  begin
    Result := Numbers[1] = ALegalMove.Squares[High(ALegalMove.Squares)];
    Exit;
  end;

  PathMatches := Length(Numbers) = Length(ALegalMove.Squares);
  if PathMatches then
    for I := 0 to High(Numbers) do
      if Numbers[I] <> ALegalMove.Squares[I] then
      begin
        PathMatches := False;
        Break;
      end;
  if PathMatches then
    Exit(True);

  if Numbers[1] <> ALegalMove.Squares[High(ALegalMove.Squares)] then
    Exit(False);

  if Length(Numbers) = 2 then
  begin
    Result := Length(ALegalMove.Captures) = 1;
    Exit;
  end;

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
    FLastEngineInfoLine := '';
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
var
  SearchMode: TEngineSearchMode;
begin
  FEngineSearching := False;
  FEngineStopRequested := False;
  SearchMode := FEngines[1].SearchMode;
  FinishEngineSlotSearch(1);
  case SearchMode of
  esmAutoPlay:
  begin
    if PlayEngineMove(AMoveText) then
    begin
      if not FAutoPlayActive then
        Exit;
      Inc(FAutoPlayPlyCount);
      if Length(FMoves) = 0 then
      begin
        FAutoPlayActive := False;
        SetTerminalResult;
        AppendEngineLog('[auto-play stopped: terminal position]' + LineEnding);
      end
      else if FAutoPlayPlyCount >= 255 then
      begin
        FAutoPlayActive := False;
        SetGuiState(gsIdle, 'auto-play 255 moves reached');
        AppendEngineLog('[auto-play stopped: 255 moves reached]' + LineEnding);
      end
      else
        SendGoThinkToEngine(esmAutoPlay);
    end
    else
    begin
      FAutoPlayActive := False;
      SetGuiState(gsIdle, 'auto-play move could not be played');
      AppendEngineLog('[auto-play stopped: ' + EngineLogName(1) + ' move could not be played]' +
        LineEnding);
    end;
  end;
  esmPlayGameThink:
  begin
    if PlayEngineMove(AMoveText) then
    begin
      if not FPlayGameActive then
        Exit;
      if Length(FMoves) = 0 then
      begin
        SetTerminalResult;
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
  esmAnalyze, esmPlayGameAnalyze:
  begin
    if AMoveText <> '' then
    begin
      UpdateAnalyzeBestMoveFromMoveText(AMoveText);
      AppendEngineLog('[analysis move ignored: ' + AMoveText + ']' + LineEnding)
    end
    else
      AppendEngineLog('[analysis done]' + LineEnding);
  end;
  esmMcts:
  begin
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
      BeginEngineSlotSearch(1, esmAutoPlay, esThinking);
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
  ResultText: String;
begin
  if EngineIsDxp(1) then
  begin
    FEngines[1].TextBuffer := '';
    Exit;
  end;

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
        FAutoPlayButton.Enabled := not EngineIsDxp(1);
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
          SendGoAnalyzeToEngine;
      end;
    end
    else if StartsText('param ', Line) then
      AddOrUpdateParam(FEngines[1].Params, ExtractHubArgument(Line, 'name'),
        ExtractHubArgument(Line, 'type'), ExtractHubArgument(Line, 'value'), True)
    else if StartsText('id ', Line) then
      HandleEngineIdLine(Line)
    else if StartsText('info ', Line) then
    begin
      FLastEngineInfoLine := Line;
      FLastEngineInfoAnnotation := EngineInfoAnnotation(Line);
      UpdateEngineEvalFromInfo(Line);
      UpdateAnalyzeBestMoveFromInfo(Line);
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
      ResultText := ExtractHubArgument(Line, 'result');
      if FLastEngineInfoLine <> '' then
        UpdateEngineEvalFromInfo(FLastEngineInfoLine, True);
      if FPlayGameActive and HubDoneResultIsDraw(ResultText) then
      begin
        FGameResult := '1-1';
        SetGuiState(gsGameOver, 'agreed draw');
        MarkGameDirty;
        SendDxpGameEndToPlayingDxpEngines;
        LeavePlayGameMode;
        UpdateHistoryList;
        AppendEngineLog('[play game stopped: agreed draw]' + LineEnding);
        Continue;
      end;
      if FPendingAutoPlayStart then
      begin
        FIgnoreNextDoneMove := False;
        FEngineSearching := False;
        FEngineStopRequested := False;
        FinishEngineSlotSearch(1);
        if MoveText <> '' then
          AppendEngineLog('[ignored previous-search move ' + MoveText + ']' +
            LineEnding)
        else
          AppendEngineLog('[previous search stopped]' + LineEnding);
        BeginAutoPlay;
      end
      else if FPendingAnalyzeStart then
      begin
        FIgnoreNextDoneMove := False;
        FEngineSearching := False;
        FEngineStopRequested := False;
        FinishEngineSlotSearch(1);
        if MoveText <> '' then
          AppendEngineLog('[ignored previous-search move ' + MoveText + ']' +
            LineEnding)
        else
          AppendEngineLog('[previous search stopped]' + LineEnding);
        FPendingAnalyzeStart := False;
        SendGoAnalyzeToEngine(FPendingAnalyzeMode);
      end
      else if FPendingMctsStart then
      begin
        FIgnoreNextDoneMove := False;
        FEngineSearching := False;
        FEngineStopRequested := False;
        FinishEngineSlotSearch(1);
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
        FinishEngineSlotSearch(1);
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
        FinishEngineSlotSearch(1);
        if MoveText <> '' then
          AppendEngineLog('[ignored previous-search move ' + MoveText + ']' +
            LineEnding)
        else
          AppendEngineLog('[previous search stopped]' + LineEnding);
        BeginPlayGame(FPendingPlayGameWhiteIsEngine,
          FPendingPlayGameBlackIsEngine, FPendingPlayGameWhiteName,
          FPendingPlayGameBlackName, FPendingPlayGameMinutes,
          FPendingPlayGameFromCurrent, True, FPendingPlayGameWhiteEngineIndex,
          FPendingPlayGameBlackEngineIndex);
      end
      else if FIgnoreNextDoneMove then
      begin
        FIgnoreNextDoneMove := False;
        FEngineStopRequested := False;
        if FEngines[1].SearchMode = esmIdle then
        begin
          FEngineSearching := False;
          SetEngineState(esIdle);
        end;
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
  ResultText: String;
  SearchMode: TEngineSearchMode;
begin
  if EngineIsDxp(2) then
  begin
    FEngines[2].TextBuffer := '';
    Exit;
  end;

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
        FinishEngineSlotSearch(2);
        AppendEngine2Log('[previous search stopped]' + LineEnding);
        SendGoThinkToSecondEngine;
        Continue;
      end;
      if FEngineAnalyzeEnabled and (FEngines[1].State = esAnalyzing) and
        (FEngines[1].SearchMode in [esmAnalyze, esmPlayGameAnalyze]) then
      begin
        AppendEngine2Log('[' + EngineLogName(2) + ' catching up to current analysis]' + LineEnding);
        SendGoAnalyzeToSecondEngine(FEngines[1].SearchMode);
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
      ResultText := ExtractHubArgument(Line, 'result');
      if FPlayGameActive and HubDoneResultIsDraw(ResultText) then
      begin
        FGameResult := '1-1';
        SetGuiState(gsGameOver, 'agreed draw');
        MarkGameDirty;
        SendDxpGameEndToPlayingDxpEngines;
        LeavePlayGameMode;
        UpdateHistoryList;
        AppendEngine2Log('[play game stopped: agreed draw]' + LineEnding);
        Continue;
      end;
      if FEngines[2].PendingThinkStart then
      begin
        FEngines[2].IgnoreNextDoneMove := False;
        FEngines[2].PendingThinkStart := False;
        FinishEngineSlotSearch(2);
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
        if FEngines[2].SearchMode = esmIdle then
          SetSecondEngineState(esIdle);
        if MoveText <> '' then
          AppendEngine2Log('[ignored stopped-search move ' +
            MoveText + ']' + LineEnding)
        else
          AppendEngine2Log('[ignored stopped-search done]' + LineEnding);
        Continue;
      end;
      SearchMode := FEngines[2].SearchMode;
      FinishEngineSlotSearch(2);
      if FPlayGameActive and IsPlayGameSecondEngineTurn and
        (SearchMode = esmPlayGameThink) and (MoveText <> '') then
      begin
        if PlayEngineMove(MoveText, 2) then
        begin
          if not FPlayGameActive then
            Exit;
          if Length(FMoves) = 0 then
          begin
            SetTerminalResult;
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
          AppendEngine2Log('[analysis move ignored: ' +
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
  FPendingAnalyzeStart := False;
  AppendEngineLog('[manual Analyze: starting analysis]' + LineEnding);
  SetGuiState(gsAnalyzing, 'manual analyze');
  SendStopToAllEngines;
  SendGoAnalyzeToEngine(esmAnalyze);
end;

procedure TMainWindow.MctsButtonClick(Sender: TObject);
begin
  FAutoPlayActive := False;
  FPendingAutoPlayStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  LeavePlayGameMode;
  FPendingAnalyzeStart := False;
  FPendingMctsStart := False;
  AppendEngineLog('[manual MCTS: starting mcts]' + LineEnding);
  SetGuiState(gsMcts, 'manual mcts');
  SendStopToAllEngines;
  SendGoMctsToEngine;
end;

procedure TMainWindow.AutoPlayButtonClick(Sender: TObject);
begin
  if not EngineIsRunning or (not FEngines[1].Ready) then
    Exit;
  if EngineIsDxp(1) then
  begin
    AppendEngineLog('[auto-play not supported for DXP engines]' + LineEnding);
    Exit;
  end;

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
    FPendingAnalyzeStart := False;
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
  FPendingAnalyzeStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FIgnoreNextDoneMove := False;
  LeavePlayGameMode;
  FAutoPlayActive := True;
  FAutoPlayPlyCount := 0;
  SetGuiState(gsAutoPlaying, 'auto-play started');
  AppendEngineLog('[auto-play started]' + LineEnding);
  if EngineIsDxp(1) then
  begin
    FAutoPlayActive := False;
    SetGuiState(gsIdle, 'auto-play not supported for DXP');
    AppendEngineLog('[auto-play not supported for DXP engines]' + LineEnding);
    Exit;
  end;
  SendGoThinkToEngine(esmAutoPlay);
end;

procedure TMainWindow.StartPlayGameFromOptions(AWhiteIsEngine,
  ABlackIsEngine: Boolean; const AWhiteName, ABlackName: String;
  AGameMinutes: Double; AStartFromCurrent: Boolean; AWhiteEngineIndex: Integer;
  ABlackEngineIndex: Integer);
begin
  if AGameMinutes <= 0 then
    AGameMinutes := 5;
  if (not EngineStateNeedsStop(FEngines[1].State)) and
    EngineStateNeedsStop(FEngines[2].State) then
  begin
    BeginPlayGame(AWhiteIsEngine, ABlackIsEngine, AWhiteName, ABlackName,
      AGameMinutes, AStartFromCurrent, False, AWhiteEngineIndex,
      ABlackEngineIndex);
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
      AStartFromCurrent, False, AWhiteEngineIndex, ABlackEngineIndex);
    FPendingAutoPlayStart := False;
    FPendingMctsStart := False;
    FPendingPlayGameStart := False;
    FPendingPlayGameWhiteIsEngine := AWhiteIsEngine;
    FPendingPlayGameBlackIsEngine := ABlackIsEngine;
    FPendingPlayGameWhiteName := AWhiteName;
    FPendingPlayGameBlackName := ABlackName;
    FPendingPlayGameWhiteEngineIndex := AWhiteEngineIndex;
    FPendingPlayGameBlackEngineIndex := ABlackEngineIndex;
    if not IsPlayGameEngineTurn then
    begin
      if AWhiteIsEngine and ABlackIsEngine then
      begin
        FPendingAnalyzeStart := False;
        FPendingThinkStart := False;
      end
      else if (AWhiteIsEngine or ABlackIsEngine) and FEngineAnalyzeEnabled then
      begin
        FPendingAnalyzeMode := esmPlayGameAnalyze;
        FPendingAnalyzeStart := True;
        FPendingThinkStart := False;
      end
      else if FEngineAnalyzeEnabled then
      begin
        FPendingAnalyzeMode := esmAnalyze;
        FPendingAnalyzeStart := True;
        FPendingThinkStart := False;
      end
      else
      begin
        FPendingAnalyzeStart := False;
        FPendingThinkStart := False;
      end;
    end
    else
    begin
      FPendingAnalyzeStart := False;
      FPendingThinkMode := esmPlayGameThink;
      FPendingThinkStart := True;
    end;
    FAutoPlayActive := False;
    AppendEngineLog('[stopping previous search before starting game]' + LineEnding);
    if EngineStateNeedsStop(FEngines[2].State) then
      SendStopToSecondEngine;
    SendStopToEngine;
    if FPlayGameActive and IsPlayGameEngineTurn and
      (not IsPlayGameSecondEngineTurn) then
      FPendingThinkStart := True;
    Exit;
  end;

  BeginPlayGame(AWhiteIsEngine, ABlackIsEngine, AWhiteName, ABlackName,
    AGameMinutes, AStartFromCurrent, True, AWhiteEngineIndex,
    ABlackEngineIndex);
end;

procedure TMainWindow.BeginPlayGame(AWhiteIsEngine, ABlackIsEngine: Boolean;
  const AWhiteName, ABlackName: String; AGameMinutes: Double;
  AStartFromCurrent: Boolean; AStartSearch: Boolean; AWhiteEngineIndex: Integer;
  ABlackEngineIndex: Integer);
begin
  FPendingAutoPlayStart := False;
  FPendingAnalyzeStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  FIgnoreNextDoneMove := False;
  ResetClocks;
  FPlayGameWhiteIsEngine := AWhiteIsEngine;
  FPlayGameBlackIsEngine := ABlackIsEngine;
  FPlayGameWhiteName := AWhiteName;
  FPlayGameBlackName := ABlackName;
  FPlayGameWhiteEngineIndex := AWhiteEngineIndex;
  FPlayGameBlackEngineIndex := ABlackEngineIndex;
  if FPlayGameWhiteIsEngine and (FPlayGameWhiteEngineIndex = 0) then
  begin
    if SameText(AWhiteName, FEngines[2].DisplayName) and
      (not SameText(AWhiteName, FEngines[1].DisplayName)) then
      FPlayGameWhiteEngineIndex := 2
    else
      FPlayGameWhiteEngineIndex := 1;
  end;
  if FPlayGameBlackIsEngine and (FPlayGameBlackEngineIndex = 0) then
  begin
    if SameText(ABlackName, FEngines[2].DisplayName) and
      (not SameText(ABlackName, FEngines[1].DisplayName)) then
      FPlayGameBlackEngineIndex := 2
    else
      FPlayGameBlackEngineIndex := 1;
  end;
  FAutoPlayActive := False;
  FPlayGameActive := True;
  if FPlayGameWhiteIsEngine and FPlayGameBlackIsEngine then
  begin
    FEngineAnalyzeAutoDisabled := FEngineAnalyzeEnabled;
    FEngineAnalyzeEnabled := False;
    FPendingAnalyzeStart := False;
    AppendEngineLog('[analysis disabled for engine-vs-engine game]' + LineEnding);
  end
  else if FEngineAnalyzeAutoDisabled then
  begin
    FEngineAnalyzeAutoDisabled := False;
    FEngineAnalyzeEnabled := True;
  end;
  UpdateAnalyzeMenuItems;
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
  if IsPlayGameEngineTurn then
    SetGuiState(gsPlayGameEngineTurn, 'play game started')
  else
    SetGuiState(gsPlayGameHumanTurn, 'play game started');
  MarkGameDirty;
  StartGameClocks(AGameMinutes);
  UpdateMoveList;
  UpdateHistoryList;
  InvalidateBoard;
  AppendEngineLog('[play game started: white=' + FGameWhiteName + ', black=' +
    FGameBlackName + ', minutes=' + FormatFloat('0.###', AGameMinutes) + ']' +
    LineEnding);

  if FPlayGameWhiteIsEngine and EngineIsDxp(FPlayGameWhiteEngineIndex) then
    SendDxpGameReqToEngine(FPlayGameWhiteEngineIndex, sideWhite, AGameMinutes);
  if FPlayGameBlackIsEngine and EngineIsDxp(FPlayGameBlackEngineIndex) then
    SendDxpGameReqToEngine(FPlayGameBlackEngineIndex, sideBlack, AGameMinutes);

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

  function BoolText(AValue: Boolean): String;
  begin
    Result := BoolToStr(AValue, True);
  end;

  function ProtocolText(AEngineIndex: Integer): String;
  begin
    if EngineIsDxp(AEngineIndex) then
      Result := 'DXP'
    else
      Result := 'HUB';
  end;

  procedure LogSlotAvailability(AEngineIndex: Integer);
  var
    LogText: String;
  begin
    LogText := '[play-game slot ' + IntToStr(AEngineIndex) +
      ': name=' + EngineLogName(AEngineIndex) +
      ' protocol=' + ProtocolText(AEngineIndex) +
      ' ready=' + BoolText(FEngines[AEngineIndex].Ready) +
      ' dxp-socket=' + BoolText(FEngines[AEngineIndex].DxpSocket <> nil) +
      ' available=' + BoolText(EngineSlotAvailableForPlay(AEngineIndex)) +
      ']' + LineEnding;
    if AEngineIndex = 2 then
      AppendEngine2Log(LogText)
    else
      AppendEngineLog(LogText);
  end;
begin
  if FPlayGameDialog <> nil then
  begin
    FPlayGameDialog.BringToFront;
    Exit;
  end;

  LogSlotAvailability(1);
  LogSlotAvailability(2);

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
  if EngineSlotAvailableForPlay(1) then
    FPlayGameWhitePlayerCombo.Items.Add(FEngines[1].DisplayName);
  if EngineSlotAvailableForPlay(2) then
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
  if EngineSlotAvailableForPlay(1) then
    FPlayGameBlackPlayerCombo.Items.Add(FEngines[1].DisplayName);
  if EngineSlotAvailableForPlay(2) then
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
  SetGuiState(gsStopping, 'manual stop');
  FAutoPlayActive := False;
  FPendingAutoPlayStart := False;
  FPendingAnalyzeStart := False;
  FPendingMctsStart := False;
  FPendingPlayGameStart := False;
  FPendingThinkStart := False;
  if EngineIsRunning then
    AppendEngineLog('[manual STOP]' + LineEnding);
  if SecondEngineIsRunning then
    AppendEngine2Log('[manual STOP]' + LineEnding);
  SendDxpGameEndToPlayingDxpEngines;
  LeavePlayGameMode;
  SendStopToAllEngines;
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

function TMainWindow.HubPositionCommand(AEngineIndex: Integer): String;
var
  Board: TBoard;
  I: Integer;
  IncludeSingleCaptureSquare: Boolean;
  MoveText: String;
  MoveStart: Integer;
  Reversible: Boolean;
  RootBoard: TBoard;
  RootSide: TSide;
  Side: TSide;
begin
  Board := FHistoryBaseBoard;
  Side := FHistoryBaseSide;
  RootBoard := Board;
  RootSide := Side;
  MoveStart := 0;

  if not EngineSendStartingPosition(AEngineIndex) then
    for I := 0 to Min(FCurrentPly, Length(FHistoryMoves)) - 1 do
    begin
      Reversible := MoveIsReversibleOnBoard(Board, FHistoryMoves[I]);
      ApplyMoveToBoard(Board, Side, FHistoryMoves[I]);
      if not Reversible then
      begin
        MoveStart := I + 1;
        RootBoard := Board;
        RootSide := Side;
      end;
    end
  else
  begin
    RootBoard := FHistoryBaseBoard;
    RootSide := FHistoryBaseSide;
  end;

  Result := 'pos pos=' + HubPositionStringFor(RootBoard, RootSide);
  IncludeSingleCaptureSquare := EngineSingleCapturesIncludeCapturedSquare(AEngineIndex);
  MoveText := '';
  for I := MoveStart to Min(FCurrentPly, Length(FHistoryMoves)) - 1 do
  begin
    if MoveText <> '' then
      MoveText += ' ';
    MoveText += MoveToHubString(FHistoryMoves[I], IncludeSingleCaptureSquare);
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

procedure TMainWindow.SendDxpStartOrMoveToEngine(AEngineIndex: Integer;
  AMode: TEngineSearchMode);
var
  IncludeSingleCaptureSquare: Boolean;
  LastMoveText: String;
  LogText: String;
begin
  if not EngineIsDxp(AEngineIndex) then
    Exit;

  IncludeSingleCaptureSquare :=
    EngineSingleCapturesIncludeCapturedSquare(AEngineIndex);
  if FCurrentPly <= 0 then
    LogText := '[DXP start position: ' + HubPositionString + ']'
  else
  begin
    LastMoveText := MoveToHubString(FHistoryMoves[FCurrentPly - 1],
      IncludeSingleCaptureSquare);
    LogText := '[DXP send move: ' + LastMoveText + ']';
  end;

  if AEngineIndex = 2 then
  begin
    AppendEngine2Log(LogText + LineEnding);
    AppendEngine2Log('[waiting for DXP answer]' + LineEnding);
  end
  else
  begin
    AppendEngineLog(LogText + LineEnding);
    AppendEngineLog('[waiting for DXP answer]' + LineEnding);
  end;
  MarkDxpWaitingForReply(AEngineIndex, AMode);
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
    FPlayGameWhiteIsEngine and (FPlayGameWhiteEngineIndex = 2)) or
    ((FSideToMove = sideBlack) and FPlayGameBlackIsEngine and
    (FPlayGameBlackEngineIndex = 2)));
end;

function TMainWindow.EngineIsDxp(AEngineIndex: Integer): Boolean;
begin
  Result := (AEngineIndex >= Low(FEngines)) and
    (AEngineIndex <= High(FEngines)) and
    (FEngines[AEngineIndex].Protocol = epDxp);
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
    SetGuiState(gsPlayGameEngineTurn, 'continue play-game search');
    if IsPlayGameSecondEngineTurn then
    begin
      AppendEngine2Log('[' + EngineLogName(2) + ' to move; starting think]' + LineEnding);
      if EngineIsDxp(2) then
      begin
        SendDxpStartOrMoveToEngine(2, esmPlayGameThink);
        if EngineStateNeedsStop(FEngines[1].State) then
          SendStopToEngine;
        Exit;
      end;
      if EngineStateNeedsStop(FEngines[2].State) then
      begin
        AppendEngine2Log('[synchronizing previous search before engine think]' +
          LineEnding);
        SendStopToSecondEngine;
        FEngines[2].PendingThinkStart := True;
        if EngineStateNeedsStop(FEngines[1].State) then
          SendStopToEngine;
      end
      else
        SendGoThinkToSecondEngine;
      Exit;
    end;
    AppendEngineLog('[' + EngineLogName(1) + ' to move; starting think]' + LineEnding);
    if EngineIsDxp(1) then
    begin
      SendDxpStartOrMoveToEngine(1, esmPlayGameThink);
      Exit;
    end;
    if EngineStateNeedsStop(FEngines[1].State) then
    begin
      FPendingAutoPlayStart := False;
      FPendingAnalyzeStart := False;
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
  begin
    SetGuiState(gsPlayGameHumanTurn, 'continue play-game search');
    SendPlayGameHumanTurnAnalyze
  end
  else if HasPlayGameHumanPlayer and EngineIsRunning and FEngines[1].Ready then
  begin
    SetGuiState(gsPlayGameHumanTurn, 'continue play-game search');
    if EngineStateNeedsStop(FEngines[1].State) then
    begin
      FPendingAutoPlayStart := False;
      FPendingMctsStart := False;
      FPendingAnalyzeMode := esmAnalyze;
      FPendingAnalyzeStart := True;
      FPendingPlayGameStart := False;
      FPendingThinkStart := False;
      AppendEngineLog('[stopping previous search before human-vs-human analysis]' +
        LineEnding);
      SendStopToEngine;
    end
    else
      SendGoAnalyzeToEngine(esmAnalyze);
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

function TMainWindow.HistoryAnnotationScoreWhite(APly: Integer;
  out AScore: Double): Boolean;
var
  Annotation: String;
  FormatSettings: TFormatSettings;
  Perspective: String;
  ScoreText: String;
  SideBeforeMove: TSide;
begin
  Result := False;
  AScore := 0.0;
  if (APly <= 0) or (APly > Length(FHistoryMoveAnnotations)) then
    Exit;

  Annotation := FHistoryMoveAnnotations[APly - 1];
  ScoreText := ExtractHubArgument(Annotation, 'score');
  if ScoreText = '' then
    Exit;

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  if not TryStrToFloat(ScoreText, AScore, FormatSettings) then
    Exit;

  Perspective := EngineScorePerspective(1);
  if (Perspective = 'black') or (Perspective = 'b') then
    AScore := -AScore
  else if (Perspective = 'side-to-move') or (Perspective = 'stm') or
    (Perspective = 'side') then
  begin
    SideBeforeMove := FHistoryBaseSide;
    if Odd(APly - 1) then
      if SideBeforeMove = sideWhite then
        SideBeforeMove := sideBlack
      else
        SideBeforeMove := sideWhite;
    if SideBeforeMove = sideBlack then
      AScore := -AScore;
  end;

  Result := True;
end;

procedure TMainWindow.UpdateEngineEvalFromInfo(const ALine: String; AForce: Boolean);
var
  DepthText: String;
  DepthValue: Double;
  FormatSettings: TFormatSettings;
  Perspective: String;
  ScoreText: String;
  OldScoreValue: Double;
  ScoreValue: Double;
begin
  ScoreText := ExtractHubArgument(ALine, 'score');
  if ScoreText = '' then
    Exit;

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';

  if not AForce then
  begin
    DepthText := ExtractHubArgument(ALine, 'depth');
    if (DepthText = '') or (not TryStrToFloat(DepthText, DepthValue,
      FormatSettings)) or (DepthValue < EngineEvaluationDepthMin(1)) then
      Exit;
  end;

  if not TryStrToFloat(ScoreText, ScoreValue, FormatSettings) then
    Exit;

  Perspective := EngineScorePerspective(1);
  if (Perspective = 'black') or (Perspective = 'b') then
    ScoreValue := -ScoreValue
  else if (Perspective = 'side-to-move') or (Perspective = 'stm') or
    (Perspective = 'side') then
  begin
    if FSideToMove = sideBlack then
      ScoreValue := -ScoreValue;
  end;

  OldScoreValue := FEngineEvalScoreWhite;
  FEngineEvalScoreWhite := ScoreValue;
  RepaintEngineEvalBarDelta(OldScoreValue, ScoreValue);
end;

procedure TMainWindow.UpdateAnalyzeBestMoveFromInfo(const ALine: String);
var
  PvText: String;
begin
  if FEngines[1].SearchMode = esmIdle then
    Exit;
  if FAnalyzePvLocked then
    Exit;

  PvText := ExtractHubArgument(ALine, 'pv');
  UpdateAnalyzePvFromMoveText(PvText);
  UpdateAnalyzeBestMoveFromMoveText(PvText);
end;

procedure TMainWindow.UpdateAnalyzePvFromMoveText(const APvText: String);
var
  BoardAfterFirstMove: TBoard;
  FirstMoveIndex: Integer;
  I: Integer;
  PvBaseMoves: TMoveArray;
  NewHintSourceSquare: Integer;
  OldHintSourceSquare: Integer;
  ReplyMoves: TMoveArray;
  SideAfterFirstMove: TSide;
begin
  ParsePvMoveText(APvText, FAnalyzePvMoves);
  FAnalyzePvHasBase := Length(FAnalyzePvMoves) > 0;
  if FAnalyzePvHasBase then
  begin
    FAnalyzePvBaseBoard := FBoard;
    FAnalyzePvBaseSide := FSideToMove;
    FAnalyzePvBasePly := FCurrentPly;
    FAnalyzePvBrowseBoard := FAnalyzePvBaseBoard;
    FAnalyzePvBrowseSide := FAnalyzePvBaseSide;
    FAnalyzePvBrowsePly := Length(FAnalyzePvMoves);
  end;

  if Length(FAnalyzePvMoves) >= 2 then
    FAnalyzeHintMove := FAnalyzePvMoves[1]
  else
    FAnalyzeHintMove := '';

  NewHintSourceSquare := 0;
  if FAnalyzeHintMove <> '' then
  begin
    FirstMoveIndex := -1;
    if Length(FAnalyzePvMoves) > 0 then
    begin
      GenerateLegalMoves(FAnalyzePvBaseBoard, FAnalyzePvBaseSide, PvBaseMoves);
      for I := 0 to High(PvBaseMoves) do
        if EngineMoveMatchesLegalMove(FAnalyzePvMoves[0], PvBaseMoves[I]) then
        begin
          FirstMoveIndex := I;
          Break;
        end;
    end;

    if FirstMoveIndex >= 0 then
    begin
      BoardAfterFirstMove := FAnalyzePvBaseBoard;
      SideAfterFirstMove := FAnalyzePvBaseSide;
      ApplyMoveToBoard(BoardAfterFirstMove, SideAfterFirstMove,
        PvBaseMoves[FirstMoveIndex]);
      GenerateLegalMoves(BoardAfterFirstMove, SideAfterFirstMove, ReplyMoves);
      for I := 0 to High(ReplyMoves) do
        if EngineMoveMatchesLegalMove(FAnalyzeHintMove, ReplyMoves[I]) and
          (Length(ReplyMoves[I].Squares) > 0) then
        begin
          NewHintSourceSquare := ReplyMoves[I].Squares[0];
          Break;
        end;
    end;
  end;

  if FAnalyzeHintSourceSquare <> NewHintSourceSquare then
  begin
    OldHintSourceSquare := FAnalyzeHintSourceSquare;
    FAnalyzeHintSourceSquare := NewHintSourceSquare;
    InvalidateBoardSquare(OldHintSourceSquare);
    InvalidateBoardSquare(NewHintSourceSquare);
  end;

  RebuildAnalyzePvPositionToPly(FAnalyzePvBrowsePly);
  UpdateAnalyzePvList;
end;

procedure TMainWindow.UpdateAnalyzeBestMoveFromMoveText(const AMoveText: String);
var
  MoveIndex: Integer;
  MoveText: String;
  NewSourceSquare: Integer;
  OldSourceSquare: Integer;
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

  if FAnalyzeBestSourceSquare = NewSourceSquare then
    Exit;

  OldSourceSquare := FAnalyzeBestSourceSquare;
  FAnalyzeBestSourceSquare := NewSourceSquare;
  InvalidateBoardSquare(OldSourceSquare);
  InvalidateBoardSquare(NewSourceSquare);
end;

procedure TMainWindow.UpdateAnalyzePvList;
var
  PvText: String;
begin
  if FPvMemo = nil then
    Exit;

  PvText := BuildAnalyzePvText(True);
  if PvText = '' then
    PvText := 'No PV';

  FPvMemo.Lines.BeginUpdate;
  try
    FPvMemo.Clear;
    FPvMemo.Text := PvText;
  finally
    FPvMemo.Lines.EndUpdate;
  end;
  FPvMemo.Invalidate;
  FPvMemo.Update;
  SelectAnalyzePvPly(FAnalyzePvBrowsePly);
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

function TMainWindow.BuildAnalyzePvText(AStoreRanges: Boolean): String;
var
  AbsolutePly: Integer;
  BasePly: Integer;
  BaseSide: TSide;
  I: Integer;
  MoveNumber: Integer;
  MoveSide: TSide;
  Prefix: String;

  function MoveNumberForAbsolutePly(APly: Integer): Integer;
  begin
    if FHistoryBaseSide = sideWhite then
      Result := ((APly - 1) div 2) + 1
    else
      Result := (APly div 2) + 1;
  end;

begin
  Result := '';
  if AStoreRanges then
  begin
    SetLength(FAnalyzePvMoveStarts, Length(FAnalyzePvMoves) + 1);
    SetLength(FAnalyzePvMoveLengths, Length(FAnalyzePvMoves) + 1);
  end;

  if FAnalyzePvHasBase then
  begin
    BasePly := FAnalyzePvBasePly;
    BaseSide := FAnalyzePvBaseSide;
  end
  else
  begin
    BasePly := FCurrentPly;
    BaseSide := FSideToMove;
  end;

  for I := 0 to High(FAnalyzePvMoves) do
  begin
    AbsolutePly := BasePly + I + 1;
    MoveSide := BaseSide;
    if Odd(I) then
      if MoveSide = sideWhite then
        MoveSide := sideBlack
      else
        MoveSide := sideWhite;
    MoveNumber := MoveNumberForAbsolutePly(AbsolutePly);

    Prefix := '';
    if MoveSide = sideWhite then
      Prefix := Format('%d. ', [MoveNumber])
    else if I = 0 then
      Prefix := Format('%d... ', [MoveNumber]);

    if Result <> '' then
      Result += ' ';
    Result += Prefix + FAnalyzePvMoves[I];
    if AStoreRanges then
    begin
      FAnalyzePvMoveStarts[I + 1] := Length(Result) - Length(FAnalyzePvMoves[I]);
      FAnalyzePvMoveLengths[I + 1] := Length(FAnalyzePvMoves[I]);
    end;
  end;
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
    RestartEngineAnalyze;
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
  if EngineIsDxp(1) then
  begin
    AppendEngineLog('[send position not supported for DXP engines]' + LineEnding);
    Exit;
  end;
  if Length(FMoves) = 0 then
  begin
    AppendEngineLog('[not sending terminal position]' + LineEnding);
    Exit;
  end;

  Command := HubPositionCommand(1);
  AppendEngineLog('> ' + Command + LineEnding);
  SendEngineCommand(Command);
end;

procedure TMainWindow.SendPlayGameHumanTurnAnalyze;
begin
  if not FPlayGameActive then
    Exit;
  if not (HasPlayGameEnginePlayer and HasPlayGameHumanPlayer) then
    Exit;
  if Length(FMoves) = 0 then
  begin
    SetTerminalResult;
    LeavePlayGameMode;
    AppendEngineLog('[play game stopped: terminal position]' + LineEnding);
    Exit;
  end;

  ActivateGameClocks;
  if EngineStateNeedsStop(FEngines[1].State) then
  begin
    FPendingAutoPlayStart := False;
    FPendingMctsStart := False;
    FPendingAnalyzeMode := esmPlayGameAnalyze;
    FPendingAnalyzeStart := True;
    FPendingPlayGameStart := False;
    FPendingThinkStart := False;
    AppendEngineLog('[stopping previous search before play-game analysis]' +
    LineEnding);
    if (FAnalyzeBestSourceSquare <> 0) or (FAnalyzeHintSourceSquare <> 0) then
    begin
      FAnalyzeBestSourceSquare := 0;
      FAnalyzeHintSourceSquare := 0;
      InvalidateBoard;
    end;
    SendStopToEngine;
  end
  else
    SendGoAnalyzeToEngine(esmPlayGameAnalyze);
end;

procedure TMainWindow.SendGoAnalyzeToEngine(AMode: TEngineSearchMode);
var
  CanUseFirstEngine: Boolean;
  CanUseSecondEngine: Boolean;
  FormatSettings: TFormatSettings;
  LevelCommand: String;
  PositionCommand: String;
begin
  CanUseFirstEngine := EngineIsRunning and FEngines[1].Ready;
  CanUseSecondEngine := SecondEngineIsRunning and FEngines[2].Ready;
  if (FAnalyzeBestSourceSquare <> 0) or (FAnalyzeHintSourceSquare <> 0) then
  begin
    FAnalyzeBestSourceSquare := 0;
    FAnalyzeHintSourceSquare := 0;
    InvalidateBoard;
  end;
  if not CanUseFirstEngine and not CanUseSecondEngine then
    Exit;
  if FPlayGameActive and IsPlayGameEngineTurn then
  begin
    if CanUseFirstEngine then
      AppendEngineLog('[not starting analysis: engine to move]' + LineEnding);
    if CanUseSecondEngine then
      AppendEngine2Log('[not starting analysis: engine to move]' + LineEnding);
    Exit;
  end;
  if not FEngineAnalyzeEnabled then
  begin
    if CanUseFirstEngine then
      AppendEngineLog('[analysis disabled: not starting analysis]' + LineEnding);
    if CanUseSecondEngine then
      AppendEngine2Log('[analysis disabled: not starting analysis]' + LineEnding);
    Exit;
  end;

  if Length(FMoves) = 0 then
  begin
    if CanUseFirstEngine then
    begin
      AppendEngineLog('[' + EngineLogName(1) + ' not starting search: terminal position]' + LineEnding);
      FEngineSearching := False;
      FinishEngineSlotSearch(1);
    end;
    if CanUseSecondEngine then
    begin
      AppendEngine2Log('[' + EngineLogName(2) + ' not starting search: terminal position]' + LineEnding);
  FinishEngineSlotSearch(2);
  UpdateEnginePopupMenuItems;
end;
    Exit;
  end;

  PositionCommand := HubPositionCommand(1);
  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  LevelCommand := Format('level move-time=%.3f', [FEngineMoveTimeSpin.Value],
    FormatSettings);

  FLastEngineInfoAnnotation := '';
  FLastEngineInfoLine := '';
  SetLength(FAnalyzePvMoves, 0);
  FAnalyzePvHasBase := False;
  FAnalyzePvLocked := False;
  FAnalyzePvBrowsePly := 0;
  FAnalyzeHintMove := '';
  FAnalyzeHintSourceSquare := 0;
  UpdateAnalyzePvList;
  if FHistoryPvMiniBoardPaintBox <> nil then
    FHistoryPvMiniBoardPaintBox.Invalidate;
  if FAnalysisBoardPaintBox <> nil then
    FAnalysisBoardPaintBox.Invalidate;
  FAnalyzeBestSourceSquare := 0;
  InvalidateBoard;

  if CanUseFirstEngine then
  begin
    if EngineIsDxp(1) then
    begin
      AppendEngineLog('[go analyze not supported for DXP engines]' + LineEnding);
    end
    else
    begin
    AppendEngineLog('> ' + PositionCommand + LineEnding);
    SendEngineCommand(PositionCommand);
    AppendEngineLog('> ' + LevelCommand + LineEnding);
    SendEngineCommand(LevelCommand);
    AppendEngineLog('> go analyze' + LineEnding);
    SendEngineCommand('go analyze');
    FEngineSearching := True;
    BeginEngineSlotSearch(1, AMode, esAnalyzing);
    end;
  end;

  if CanUseSecondEngine then
  begin
    if EngineIsDxp(2) then
    begin
      AppendEngine2Log('[go analyze not supported for DXP engines]' + LineEnding);
    end
    else
    begin
    PositionCommand := HubPositionCommand(2);
    AppendEngine2Log('> ' + PositionCommand + LineEnding);
    SendSecondEngineCommand(PositionCommand);
    AppendEngine2Log('> ' + LevelCommand + LineEnding);
    SendSecondEngineCommand(LevelCommand);
    AppendEngine2Log('> go analyze' + LineEnding);
    SendSecondEngineCommand('go analyze');
    BeginEngineSlotSearch(2, AMode, esAnalyzing);
    end;
  end;
end;

procedure TMainWindow.SendGoAnalyzeToSecondEngine(AMode: TEngineSearchMode);
var
  FormatSettings: TFormatSettings;
  LevelCommand: String;
  PositionCommand: String;
begin
  if not SecondEngineIsRunning then
    Exit;
  if not FEngines[2].Ready then
    Exit;
  if FPlayGameActive and IsPlayGameEngineTurn then
  begin
    AppendEngine2Log('[not starting analysis: engine to move]' + LineEnding);
    Exit;
  end;
  if not FEngineAnalyzeEnabled then
  begin
    AppendEngine2Log('[analysis disabled: not starting analysis]' + LineEnding);
    Exit;
  end;
  if EngineIsDxp(2) then
  begin
    AppendEngine2Log('[go analyze not supported for DXP engines]' + LineEnding);
    Exit;
  end;
  if Length(FMoves) = 0 then
  begin
    AppendEngine2Log('[' + EngineLogName(2) + ' not starting search: terminal position]' + LineEnding);
    FinishEngineSlotSearch(2);
    Exit;
  end;

  PositionCommand := HubPositionCommand(2);
  AppendEngine2Log('> ' + PositionCommand + LineEnding);
  SendSecondEngineCommand(PositionCommand);

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  LevelCommand := Format('level move-time=%.3f', [FEngineMoveTimeSpin.Value],
    FormatSettings);
  AppendEngine2Log('> ' + LevelCommand + LineEnding);
  SendSecondEngineCommand(LevelCommand);
  AppendEngine2Log('> go analyze' + LineEnding);
  SendSecondEngineCommand('go analyze');
  BeginEngineSlotSearch(2, AMode, esAnalyzing);
end;

procedure TMainWindow.SendGoMctsToEngine;
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

  if Length(FMoves) = 0 then
  begin
    if CanUseFirstEngine then
    begin
      AppendEngineLog('[' + EngineLogName(1) + ' not starting search: terminal position]' + LineEnding);
      FEngineSearching := False;
      FinishEngineSlotSearch(1);
    end;
    if CanUseSecondEngine then
    begin
      AppendEngine2Log('[' + EngineLogName(2) + ' not starting search: terminal position]' + LineEnding);
      FinishEngineSlotSearch(2);
    end;
    Exit;
  end;

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  LevelCommand := Format('level move-time=%.3f', [FEngineMoveTimeSpin.Value],
    FormatSettings);

  FLastEngineInfoAnnotation := '';
  FLastEngineInfoLine := '';
  SetLength(FAnalyzePvMoves, 0);
  FAnalyzePvHasBase := False;
  FAnalyzePvLocked := False;
  FAnalyzePvBrowsePly := 0;
  FAnalyzeHintMove := '';
  FAnalyzeHintSourceSquare := 0;
  UpdateAnalyzePvList;
  if FHistoryPvMiniBoardPaintBox <> nil then
    FHistoryPvMiniBoardPaintBox.Invalidate;
  if FAnalysisBoardPaintBox <> nil then
    FAnalysisBoardPaintBox.Invalidate;
  FAnalyzeBestSourceSquare := 0;
  InvalidateBoard;

  if CanUseFirstEngine then
  begin
    if EngineIsDxp(1) then
      AppendEngineLog('[go mcts not supported for DXP engines]' + LineEnding)
    else if EngineSupportsMcts(1) then
    begin
      PositionCommand := HubPositionCommand(1);
      AppendEngineLog('> ' + PositionCommand + LineEnding);
      SendEngineCommand(PositionCommand);
      AppendEngineLog('> ' + LevelCommand + LineEnding);
      SendEngineCommand(LevelCommand);
      AppendEngineLog('> go mcts' + LineEnding);
      SendEngineCommand('go mcts');
      FEngineSearching := True;
      BeginEngineSlotSearch(1, esmMcts, esMcts);
    end
    else
      AppendEngineLog('[' + EngineLogName(1) +
        ' does not support go mcts]' + LineEnding);
  end;

  if CanUseSecondEngine then
  begin
    if EngineIsDxp(2) then
      AppendEngine2Log('[go mcts not supported for DXP engines]' + LineEnding)
    else if EngineSupportsMcts(2) then
    begin
      PositionCommand := HubPositionCommand(2);
      AppendEngine2Log('> ' + PositionCommand + LineEnding);
      SendSecondEngineCommand(PositionCommand);
      AppendEngine2Log('> ' + LevelCommand + LineEnding);
      SendSecondEngineCommand(LevelCommand);
      AppendEngine2Log('> go mcts' + LineEnding);
      SendSecondEngineCommand('go mcts');
      BeginEngineSlotSearch(2, esmMcts, esMcts);
    end
    else
      AppendEngine2Log('[' + EngineLogName(2) +
        ' does not support go mcts]' + LineEnding);
  end;
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
  if EngineIsDxp(1) then
  begin
    if AMode = esmAutoPlay then
    begin
      AppendEngineLog('[DXP auto-play from current position]' + LineEnding);
      SendDxpStartOrMoveToEngine(1, AMode);
    end
    else if AMode = esmPlayGameThink then
      SendDxpStartOrMoveToEngine(1, AMode)
    else
      AppendEngineLog('[go think not supported for DXP engines outside game/auto-play]' +
        LineEnding);
    Exit;
  end;
  if Length(FMoves) = 0 then
  begin
    if FPlayGameActive then
      LeavePlayGameMode;
    FAutoPlayActive := False;
    FEngineSearching := False;
    FinishEngineSlotSearch(1);
    AppendEngineLog('[' + EngineLogName(1) + ' not starting search: terminal position]' + LineEnding);
    Exit;
  end;

  PositionCommand := HubPositionCommand(1);
  AppendEngineLog('> ' + PositionCommand + LineEnding);
  SendEngineCommand(PositionCommand);

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  if AMode = esmPlayGameThink then
  begin
    ActivateGameClocks;
    LevelCommand := Format('level time=%.3f', [CurrentEngineRemainingTimeSeconds],
      FormatSettings)
  end
  else
    LevelCommand := Format('level move-time=%.3f', [FEngineMoveTimeSpin.Value],
      FormatSettings);
  AppendEngineLog('> ' + LevelCommand + LineEnding);
  SendEngineCommand(LevelCommand);
  AppendEngineLog('> go think' + LineEnding);
  FLastEngineInfoAnnotation := '';
  FLastEngineInfoLine := '';
  SetLength(FAnalyzePvMoves, 0);
  FAnalyzePvHasBase := False;
  FAnalyzePvLocked := False;
  FAnalyzePvBrowsePly := 0;
  FAnalyzeHintMove := '';
  FAnalyzeHintSourceSquare := 0;
  UpdateAnalyzePvList;
  if FHistoryPvMiniBoardPaintBox <> nil then
    FHistoryPvMiniBoardPaintBox.Invalidate;
  if FAnalysisBoardPaintBox <> nil then
    FAnalysisBoardPaintBox.Invalidate;
  FIgnoreNextDoneMove := False;
  if (FAnalyzeBestSourceSquare <> 0) or (FAnalyzeHintSourceSquare <> 0) then
  begin
    FAnalyzeBestSourceSquare := 0;
    FAnalyzeHintSourceSquare := 0;
    InvalidateBoard;
  end
  else
    InvalidateBoard;
  SendEngineCommand('go think');
  FEngineSearching := True;
  BeginEngineSlotSearch(1, AMode, esThinking);
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
  if EngineIsDxp(2) then
  begin
    SendDxpStartOrMoveToEngine(2, esmPlayGameThink);
    Exit;
  end;
  if Length(FMoves) = 0 then
  begin
    if FPlayGameActive then
      LeavePlayGameMode;
    FinishEngineSlotSearch(2);
    AppendEngine2Log('[' + EngineLogName(2) + ' not starting search: terminal position]' + LineEnding);
    Exit;
  end;

  PositionCommand := HubPositionCommand(2);
  AppendEngine2Log('> ' + PositionCommand + LineEnding);
  SendSecondEngineCommand(PositionCommand);

  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  ActivateGameClocks;
  LevelCommand := Format('level time=%.3f', [CurrentEngineRemainingTimeSeconds],
    FormatSettings);
  AppendEngine2Log('> ' + LevelCommand + LineEnding);
  SendSecondEngineCommand(LevelCommand);
  AppendEngine2Log('> go think' + LineEnding);
  FEngines[2].IgnoreNextDoneMove := False;
  SendSecondEngineCommand('go think');
  BeginEngineSlotSearch(2, esmPlayGameThink, esThinking);
end;

procedure TMainWindow.RestartEngineAnalyze;
begin
  if not FEngineAnalyzeEnabled then
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
    FPendingAnalyzeMode := esmAnalyze;
    FPendingAnalyzeStart := True;
    FPendingPlayGameStart := False;
    FPendingThinkStart := False;
    AppendEngineLog('[stopping previous search before analysis]' + LineEnding);
    SendStopToEngine;
  end
  else
  begin
    if EngineStateNeedsStop(FEngines[2].State) then
      SendStopToSecondEngine;
    SendGoAnalyzeToEngine;
  end;
end;

procedure TMainWindow.SendStopToEngine;
var
  PreviousState: TEngineState;
begin
  if not EngineIsRunning then
    Exit;

  PreviousState := FEngines[1].State;
  if EngineIsDxp(1) then
  begin
    if FPlayGameActive then
      SendDxpGameEndToEngine(1, DxpGameEndCodeForEngine(1));
    FIgnoreNextDoneMove := False;
    FEngineStopRequested := False;
    FEngineSearching := False;
    FEngines[1].FinishSearch;
    if PreviousState <> esIdle then
      AppendEngineLog('[' + EngineLogName(1) + ' state: ' +
        EngineStateLogText(PreviousState) + ' -> idle]' + LineEnding);
    UpdateEngineStateLabels;
    Exit;
  end;
  AppendEngineLog('> stop' + LineEnding);
  AppendEngineLog('[' + EngineLogName(1) + ' stop requested while state: ' +
    EngineStateLogText(PreviousState) + ']' + LineEnding);
  FIgnoreNextDoneMove := EngineStateNeedsStop(FEngines[1].State);
  FEngineStopRequested := False;
  FEngineSearching := False;
  FEngines[1].FinishSearch;
  if PreviousState <> esIdle then
  begin
    UpdateEngineStateLabels;
    AppendEngineLog('[' + EngineLogName(1) + ' state: ' + EngineStateLogText(PreviousState) +
      ' -> idle]' + LineEnding);
  end
  else
    SetEngineState(esIdle);
  SendEngineCommand('stop');
end;

procedure TMainWindow.SendStopToAllEngines;
begin
  SendStopToSecondEngine;
  SendStopToEngine;
end;

procedure TMainWindow.SendStopToSecondEngine;
var
  PreviousState: TEngineState;
begin
  if not SecondEngineIsRunning then
    Exit;

  PreviousState := FEngines[2].State;
  if EngineIsDxp(2) then
  begin
    if FPlayGameActive then
      SendDxpGameEndToEngine(2, DxpGameEndCodeForEngine(2));
    FEngines[2].FinishSearch;
    FEngines[2].IgnoreNextDoneMove := False;
    if PreviousState <> esIdle then
      AppendEngine2Log('[' + EngineLogName(2) + ' state: ' +
        EngineStateLogText(PreviousState) + ' -> idle]' + LineEnding);
    UpdateEngineStateLabels;
    Exit;
  end;
  AppendEngine2Log('> stop' + LineEnding);
  AppendEngine2Log('[' + EngineLogName(2) + ' stop requested while state: ' +
    EngineStateLogText(PreviousState) + ']' + LineEnding);
  FEngines[2].FinishSearch;
  FEngines[2].IgnoreNextDoneMove := EngineStateNeedsStop(PreviousState);
  if PreviousState <> esIdle then
  begin
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

procedure TMainWindow.UpdateAnalyzeMenuItems;
var
  DisableAnalyzeToggle: Boolean;
begin
  DisableAnalyzeToggle := FPlayGameActive and FPlayGameWhiteIsEngine and
    FPlayGameBlackIsEngine;
  if FEngines[1].AnalyzeMenuItem <> nil then
  begin
    FEngines[1].AnalyzeMenuItem.Checked := FEngineAnalyzeEnabled;
    FEngines[1].AnalyzeMenuItem.Enabled := not DisableAnalyzeToggle;
  end;
  if FEngines[2].AnalyzeMenuItem <> nil then
  begin
    FEngines[2].AnalyzeMenuItem.Checked := FEngineAnalyzeEnabled;
    FEngines[2].AnalyzeMenuItem.Enabled := not DisableAnalyzeToggle;
  end;
  UpdateEnginePopupMenuItems;
end;

procedure TMainWindow.UpdateEnginePopupMenuItems;
var
  Engine1Loaded: Boolean;
  Engine2Loaded: Boolean;
begin
  Engine1Loaded := EngineIsRunning;
  Engine2Loaded := SecondEngineIsRunning;

  if FEngines[1].OpenMenuItem <> nil then
    FEngines[1].OpenMenuItem.Enabled := not Engine1Loaded;
  if FEngines[1].CloseMenuItem <> nil then
    FEngines[1].CloseMenuItem.Enabled := Engine1Loaded;
  if FEngines[1].ParamsMenuItem <> nil then
    FEngines[1].ParamsMenuItem.Enabled := Engine1Loaded;

  if FEngines[2].OpenMenuItem <> nil then
    FEngines[2].OpenMenuItem.Enabled := not Engine2Loaded;
  if FEngines[2].CloseMenuItem <> nil then
    FEngines[2].CloseMenuItem.Enabled := Engine2Loaded;
  if FEngines[2].ParamsMenuItem <> nil then
    FEngines[2].ParamsMenuItem.Enabled := Engine2Loaded;
end;

procedure TMainWindow.AnalyzeMenuItemClick(Sender: TObject);
begin
  if FPlayGameActive and FPlayGameWhiteIsEngine and FPlayGameBlackIsEngine then
    Exit;
  FEngineAnalyzeAutoDisabled := False;
  FEngineAnalyzeEnabled := not FEngineAnalyzeEnabled;
  UpdateAnalyzeMenuItems;
  if FEngineAnalyzeEnabled then
  begin
    AppendEngineLog('[analysis enabled]' + LineEnding);
    if FAutoPlayActive then
      Exit;
    if FPlayGameActive then
    begin
      if not IsPlayGameEngineTurn then
        ContinuePlayGameSearch;
    end
    else
      RestartEngineAnalyze;
  end
  else
  begin
    AppendEngineLog('[analysis disabled]' + LineEnding);
    FPendingAnalyzeStart := False;
    if (FEngines[1].State = esAnalyzing) or (FEngines[2].State = esAnalyzing) then
      SendStopToAllEngines;
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
  AResult: String; const AEvent: String; const ARound: String; AAppend: Boolean);
var
  ExistingLines: TStringList;
  EventText: String;
  Lines: TStringList;
  RoundText: String;
begin
  EventText := AEvent;
  if EventText = '' then
    EventText := '?';
  RoundText := ARound;
  if RoundText = '' then
    RoundText := '?';

  Lines := TStringList.Create;
  try
    Lines.Add('[Event "' + PdnEscape(EventText) + '"]');
    Lines.Add('[Site "?"]');
    Lines.Add('[Date "????.??.??"]');
    Lines.Add('[Round "' + PdnEscape(RoundText) + '"]');
    Lines.Add('[White "' + PdnEscape(AWhiteName) + '"]');
    Lines.Add('[Black "' + PdnEscape(ABlackName) + '"]');
    Lines.Add('[Result "' + AResult + '"]');
    Lines.Add('[FEN "' + BoardToFen(FHistoryBaseBoard, FHistoryBaseSide) + '"]');
    Lines.Add('');
    Lines.Add(BuildPdnMoveText(AResult, False));
    if AAppend and FileExists(AFileName) then
    begin
      ExistingLines := TStringList.Create;
      try
        ExistingLines.LoadFromFile(AFileName);
        while (ExistingLines.Count > 0) and
          (Trim(ExistingLines[ExistingLines.Count - 1]) = '') do
          ExistingLines.Delete(ExistingLines.Count - 1);
        ExistingLines.Add('');
        ExistingLines.Add('');
        ExistingLines.AddStrings(Lines);
        ExistingLines.SaveToFile(AFileName);
      finally
        ExistingLines.Free;
      end;
    end
    else
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
  RestartEngineAnalyze;
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
    RestartEngineAnalyze;
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

procedure ExtractPdnMoveTokens(const ALines: TStrings; out ATokens,
  AAnnotations: TTextArray);
var
  Ch: Char;
  Comment: String;
  I: Integer;
  InComment: Boolean;
  InVariation: Integer;
  J: Integer;
  LastTokenIndex: Integer;
  Line: String;
  Token: String;

  procedure AppendToken;
  begin
    Token := Trim(Token);
    if Token = '' then
      Exit;
    SetLength(ATokens, Length(ATokens) + 1);
    SetLength(AAnnotations, Length(ATokens));
    ATokens[High(ATokens)] := Token;
    AAnnotations[High(AAnnotations)] := '';
    LastTokenIndex := High(ATokens);
    Token := '';
  end;

  procedure AppendComment;
  begin
    Comment := Trim(Comment);
    if (Comment = '') or (LastTokenIndex < 0) then
      Exit;
    if AAnnotations[LastTokenIndex] <> '' then
      AAnnotations[LastTokenIndex] += ' ';
    AAnnotations[LastTokenIndex] += Comment;
    Comment := '';
  end;

begin
  SetLength(ATokens, 0);
  SetLength(AAnnotations, 0);
  InComment := False;
  InVariation := 0;
  LastTokenIndex := -1;
  Token := '';
  Comment := '';

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
        begin
          InComment := False;
          AppendComment;
        end
        else
          Comment += Ch;
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
        '{':
        begin
          AppendToken;
          InComment := True;
          Comment := '';
        end;
        '(':
        begin
          AppendToken;
          InVariation := 1;
        end;
        ';':
        begin
          AppendToken;
          Break;
        end;
        ' ', #9, #10, #13:
          AppendToken;
      else
        Token += Ch;
      end;
    end;
    AppendToken;
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
  StartFen: String;
  Token: String;
  TokenAnnotations: TTextArray;
  Tokens: TTextArray;
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
    ExtractPdnMoveTokens(Lines, Tokens, TokenAnnotations);

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
            if I <= High(TokenAnnotations) then
              RecordPlayedMove(MatchedMove, TokenAnnotations[I])
            else
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
    RestartEngineAnalyze;
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
  if FHistoryEvalPaintBox <> nil then
    FHistoryEvalPaintBox.Invalidate;

  SelectHistoryPly(FCurrentPly);
  FHistoryMemo.Invalidate;
  FHistoryMemo.Update;
end;

procedure TMainWindow.UpdateMoveList;
var
  I: Integer;
begin
  ClearBoardSelection;
  GenerateLegalMoves(FBoard, FSideToMove, FMoves);
  SetLength(FAnalyzePvMoves, 0);
  FAnalyzePvHasBase := False;
  FAnalyzePvLocked := False;
  FAnalyzePvBrowsePly := 0;
  FAnalyzeHintMove := '';
  FAnalyzeHintSourceSquare := 0;
  UpdateAnalyzePvList;
  if FHistoryPvMiniBoardPaintBox <> nil then
    FHistoryPvMiniBoardPaintBox.Invalidate;
  if FAnalysisBoardPaintBox <> nil then
    FAnalysisBoardPaintBox.Invalidate;
  FOnlyMoveSourceSquare := 0;
  if (Length(FMoves) = 1) and (Length(FMoves[0].Squares) > 0) then
    FOnlyMoveSourceSquare := FMoves[0].Squares[0];

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
  FMovesMemo.Invalidate;
  FMovesMemo.Update;
end;

end.
