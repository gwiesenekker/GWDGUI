unit MainForm;

{$mode objfpc}{$H+}

interface

uses
  AnalysisBoardUi,
  BoardGeometry,
  BoardHighlightUi,
  BoardUi,
  CheckLst,
  Classes,
  ClockUi,
  Clipbrd,
  Controls,
  Dialogs,
  DraughtsRules,
  DxpConnection,
  DxpDispatcher,
  DxpProtocol,
  EngineCommands,
  EasyLazFreeType,
  EngineConfig,
  EngineGates,
  EngineLogAdapter,
  EngineLogMemo,
  EngineLogMessages,
  EngineLogPopup,
  EngineParams,
  EngineProtocolCommands,
  EngineRegistry,
  EngineSearchController,
  EngineSlot,
  EngineSlotSelection,
  EngineState,
  EvalBarUi,
  ExtCtrls,
  FPJSON,
  FPImage,
  Forms,
  GameClock,
  GameFlow,
  GameHistory,
  GameState,
  GraphType,
  Graphics,
  Grids,
  GuiDialogs,
  GuiState,
  HubProtocol,
  IntfGraphics,
  LazFreeTypeIntfDrawer,
  LazFreeTypeFontCollection,
  Menus,
  Notation,
  PdnAnnotations,
  PDNSaveDialog,
  PlayClockController,
  PlatformDialogs,
  PlatformProcess,
  SetupDialog,
  ScoreHistoryUi,
  ssockets,
  Spin,
  StdCtrls,
  JSONParser,
  LCLType,
  TournamentFiles,
  TournamentGridModel,
  TournamentModel,
  TournamentPairing,
  TournamentStorage,
  TournamentTypes,
  TournamentUi,
  Types;

type
  TMainWindow = class;

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
    FPlayRoundButton: TButton;
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
    procedure AddPairing(const AWhite, ABlack: String; ARound: Integer = 1);
    procedure AdjustSectionHeights;
    procedure ApplyTournamentData(const AData: TTournamentFileData);
    procedure ClearPairingGrid;
    procedure CollectPairingRows(AWhiteEngines, ABlackEngines,
      AResults: TStrings);
    procedure CollectRoundRows(ARounds: TStrings);
    procedure CollectSelectedEngineNames(AEngines: TStrings);
    procedure CollectSelectedEngineNames(var AEngines: TTournamentTextArray);
    procedure CrossTableDrawCell(Sender: TObject; ACol, ARow: Integer;
      ARect: TRect; AState: TGridDrawState);
    procedure PairingGridDrawCell(Sender: TObject; ACol, ARow: Integer;
      ARect: TRect; AState: TGridDrawState);
    procedure PlayRoundButtonClick(Sender: TObject);
    procedure DialogClose(Sender: TObject; var CloseAction: TCloseAction);
    function EngineFileNameForName(const AName: String): String;
    function EngineProtocolForName(const AName: String): String;
    function FindNextUnplayedTournamentRow: Integer;
    procedure GridClick(Sender: TObject);
    function GridIsEmpty: Boolean;
    procedure HighlightTournamentRow(ARow: Integer);
    function LoadedSlotIndexForTournamentEngine(AMain: TMainWindow;
      const AName, AFileName: String): Integer;
    procedure LoadTournamentEngineIntoSlot(AMain: TMainWindow;
      AEngineIndex: Integer; const AName, AFileName, AProtocol: String);
    procedure LoadButtonClick(Sender: TObject);
    procedure LoadEngineNames(AEngines: TStrings);
    procedure MarkDirty;
    procedure MinutesEditChange(Sender: TObject);
    function OtherTournamentSlot(AEngineIndex: Integer): Integer;
    procedure PopulateEngineCheckList;
    procedure ResultComboChange(Sender: TObject);
    procedure ResultComboExit(Sender: TObject);
    function ResolveTournamentPairing(AMain: TMainWindow; ARow: Integer;
      out AWhiteName, ABlackName, AWhiteFileName, ABlackFileName,
      AWhiteProtocol, ABlackProtocol: String; out AWhiteLoadedIndex,
      ABlackLoadedIndex: Integer): Boolean;
    procedure ResolveTournamentSlots(AMain: TMainWindow; const AWhiteName,
      ABlackName, AWhiteFileName, ABlackFileName, AWhiteProtocol,
      ABlackProtocol: String; AWhiteLoadedIndex, ABlackLoadedIndex: Integer);
    procedure RoundRobinGroupClick(Sender: TObject);
    procedure SaveButtonClick(Sender: TObject);
    function SaveTournament: Boolean;
    procedure SaveTournamentGamePdn(AGameNumber: Integer);
    function TournamentSlotMatches(AMain: TMainWindow; AIndex: Integer;
      const AName, AFileName: String): Boolean;
    function StartNextTournamentGame: Boolean;
    procedure StartButtonClick(Sender: TObject);
    procedure StopButtonClick(Sender: TObject);
    procedure TournamentTimerTick(Sender: TObject);
    procedure TournamentResize(Sender: TObject);
    procedure UpdateTournamentButtons;
    procedure UpdateCrossTable;
  public
    function ConfirmClose: Boolean;
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
    FEngineEvalScoreWhite: Double;
    FEvalBarRect: TRect;
    FLastEvalBarWhitePixels: Integer;
    FEngineAnalyzeAutoDisabled: Boolean;
    FEngineAnalyzeEnabled: Boolean;
    FEngineLogShowTimestamps: Boolean;
    FEngineStartAfterReady: Boolean;
    FEditMenu: TMenuItem;
    FShuttingDown: Boolean;
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
    FGameResultReason: String;
    FGameWhiteName: String;
    FPlayClock: TPlayClockController;
    FBoardFlipped: Boolean;
    FButtonPanel: TPanel;
    FBoardPaintBox: TPaintBox;
    FBoardPanel: TPanel;
    FBoardMoveSplitter: TSplitter;
    FBoardTopClockLabel: TLabel;
    FBoardBottomClockLabel: TLabel;
    FHistory: TGameHistory;
    FHistoryBlackEdit: TEdit;
    FHistoryBlackLabel: TLabel;
    FHistoryFenLabel: TLabel;
    FHistoryFenMemo: TMemo;
    FHistoryEvalPaintBox: TPaintBox;
    FHistoryMemo: TMemo;
    FHistoryPvLabel: TLabel;
    FHistoryPvMiniBoardPanel: TPanel;
    FHistoryPvMiniBoardPaintBox: TPaintBox;
    FPvEngineCombo: TComboBox;
    FHistoryResultEdit: TEdit;
    FHistoryResultLabel: TLabel;
    FHistoryWhiteEdit: TEdit;
    FHistoryWhiteLabel: TLabel;
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
    FSelectedPvEngineIndex: Integer;
    FAnalysisBoardForm: TForm;
    FAnalysisBoardPaintBox: TPaintBox;
    FAnalysisBoardPopupMenu: TPopupMenu;
    FShowAnalysisBoardMenuItem: TMenuItem;
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
    FPendingPlayGameFromCurrent: Boolean;
    FPendingPlayGameMinutes: Double;
    FPendingPlayGameBlackIsEngine: Boolean;
    FPendingPlayGameBlackEngineIndex: Integer;
    FPendingPlayGameBlackName: String;
    FPendingPlayGameWhiteIsEngine: Boolean;
    FPendingPlayGameWhiteEngineIndex: Integer;
    FPendingPlayGameWhiteName: String;
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
    procedure AppendEngineSlotLog(AEngineIndex: Integer; const AText: String);
    procedure AppendEngineSlotRawLog(AEngineIndex: Integer; const AText: String);
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
    procedure ApplicationIdle(Sender: TObject; var Done: Boolean);
    procedure ClockTimerTimer(Sender: TObject);
    procedure ClearBoardSelection;
    procedure ClearBoard;
    procedure CopyFenMenuItemClick(Sender: TObject);
    procedure CloseEngine;
    procedure CloseEngineSlot(AEngineIndex: Integer);
    procedure CloseEngineSlotProcess(AEngineIndex: Integer);
    procedure RequestEngineSlotProcessExit(AEngineIndex: Integer);
    procedure TerminateEngineSlotProcessIfRunning(AEngineIndex: Integer);
    procedure CloseEngineSlotProcessHandles(AEngineIndex: Integer);
    procedure ResetEngineSlotAfterClose(AEngineIndex: Integer);
    procedure ResetEngineRuntimeForLaunch(AEngineIndex: Integer);
    procedure ResetEngineRuntimeForClose(AEngineIndex: Integer);
    procedure ResetEngineRuntimeAfterProcessExit(AEngineIndex: Integer);
    procedure ResetPrimaryEngineAfterClose;
    procedure ResetSecondaryEngineAfterClose;
    procedure RefreshEngineUiAfterSlotChange;
    function EngineSlotIndexFromSender(Sender: TObject): Integer;
    procedure CloseEngineMenuItemClick(Sender: TObject);
    procedure CloseSecondEngine;
    procedure CenterMainWindowOnScreen;
    procedure CenterDialogOnMainWindow(ADialog: TCustomForm);
    procedure DrawBoard(ACanvas: TCanvas);
    procedure DrawEngineEvalBar(ACanvas: TCanvas; const ABoardRect: TRect);
    procedure DrawBoardSideToMoveMarker(ACanvas: TCanvas; const ABoardRect: TRect;
      ACellSize: Integer);
    procedure DrawPiece(ACanvas: TCanvas; const ASquare: TRect;
      APiece: TPiece; ACellSize: Integer; ASquareColor: TColor);
    procedure EngineProcessReadData(Sender: TObject);
    procedure EngineProcessReadSecondEngineData;
    procedure PlatformProcessData(Sender: TObject; const AText: String);
    procedure ReadEngineSlotData(AEngineIndex: Integer);
    procedure EnginePollTimerTimer(Sender: TObject);
    function AnyEngineSlotProcessHandlePresent: Boolean;
    function EngineSlotShouldReadInPoll(AEngineIndex: Integer): Boolean;
    procedure PollEngineSlot(AEngineIndex: Integer);
    procedure EngineProcessTerminate(Sender: TObject);
    procedure HandleEngineProcessTerminated(AEngineIndex: Integer);
    function EngineSlotProcessHandlePresent(AEngineIndex: Integer): Boolean;
    procedure DrainEngineSlotOutputAfterExit(AEngineIndex: Integer);
    procedure LogEngineSlotProcessTerminated(AEngineIndex: Integer);
    procedure CloseTerminatedEngineSlotProcess(AEngineIndex: Integer);
    procedure UpdateEnginePollTimer;
    procedure FormShow(Sender: TObject);
    procedure RefreshInitialLayout(Data: PtrInt);
    function EngineMoveIndex(const AEngineMove: String): Integer;
    function EngineMoveMatchesLegalMove(const AEngineMove: String;
      const ALegalMove: TMove): Boolean;
    function EngineIsRunning: Boolean;
    function EngineSlotIsRunning(AEngineIndex: Integer): Boolean;
    function EngineSlotIndexValid(AEngineIndex: Integer): Boolean;
    function EngineSlotConfigured(AEngineIndex: Integer): Boolean;
    function EngineSlotDxpSocketOpen(AEngineIndex: Integer): Boolean;
    function EngineSlotDxpConnectionActive(AEngineIndex: Integer): Boolean;
    procedure CloseDxpSocket(AEngineIndex: Integer; const AReason: String);
    function EngineSlotCanReceiveCommand(AEngineIndex: Integer;
      ARequireReady: Boolean): TEngineCommandGate;
    function EngineSlotCanStartHubSearch(AEngineIndex: Integer;
      const AGoCommand: String; ARequireMctsSupport: Boolean):
      TEngineCommandGate;
    function EngineSlotCanSendDxpPacket(AEngineIndex: Integer;
      const APacketName: String; ACheckGameEndSent: Boolean = False):
      TEngineCommandGate;
    function EngineSlotCanSendDxpGameEnd(AEngineIndex: Integer):
      TEngineCommandGate;
    function LogEngineGateFailure(AEngineIndex: Integer;
      const AGate: TEngineCommandGate): Boolean;
    function EngineSlotAvailableForPlay(AEngineIndex: Integer): Boolean;
    function EngineOutputLogText(const AText: String; AEngineIndex: Integer): String;
    function EngineCanonicalParamsFileName(const AEngineFileName: String): String;
    procedure LoadEngineParamsForProtocol(AEngineIndex: Integer;
      const AEngineFileName, AProtocol: String);
    function EngineParamsFileNameForDisplayName(const ADisplayName: String;
      const AEngineFileName: String = ''): String;
    function SecondEngineIsRunning: Boolean;
    function StartDxpConnection(AEngineIndex: Integer): Boolean;
    procedure StopDxpConnection(AEngineIndex: Integer);
    function DxpListenerPortInUse(AEngineIndex: Integer;
      out AOtherEngineIndex: Integer): Boolean;
    function DxpGameEndCodeForEngine(AEngineIndex: Integer): Char;
    function DxpResultFromGameEnd(AEngineIndex: Integer; ACode: Char): String;
    procedure StartDxpGameForSlot(AEngineIndex: Integer; AEngineSide: TSide;
      AGameMinutes: Double);
    procedure StartDxpPlayGameSessions(AGameMinutes: Double);
    procedure SendDxpGameReqToEngine(AEngineIndex: Integer; AEngineSide: TSide;
      AGameMinutes: Double);
    procedure SendDxpGameEndToEngine(AEngineIndex: Integer; ACode: Char);
    procedure NotifyDxpPlayGameEnd(AExcludeEngineIndex: Integer = 0);
    procedure HandleDxpGameEndReceived(AEngineIndex: Integer; ACode: Char);
    procedure StopNonOriginSearchAfterGameEnd(AOriginEngineIndex: Integer);
    procedure SendDxpMoveToEngine(AEngineIndex: Integer; const AMove: TMove;
      ATotalTimeUsedSeconds: Integer = 0);
    function SendDxpPacketAfterGate(AEngineIndex: Integer;
      const APacketName, APacketText: String;
      const AGate: TEngineCommandGate): Boolean;
    function SendDxpPacketToEngine(AEngineIndex: Integer;
      const APacketName, APacketText: String): Boolean;
    procedure SetDxpGameState(AEngineIndex: Integer; AState: TDxpGameState;
      const AReason: String = '');
    procedure BeginDxpGameRequest(AEngineIndex: Integer);
    procedure CancelDxpGameRequest(AEngineIndex: Integer);
    procedure MarkDxpWaitingForProtocolReply(AEngineIndex: Integer;
      const AReason: String; const ALogText: String = '');
    procedure MarkDxpGameRequestSent(AEngineIndex: Integer);
    procedure MarkDxpMoveSent(AEngineIndex: Integer);
    procedure MarkDxpGameEndSent(AEngineIndex: Integer);
    procedure MarkDxpGameEndArrived(AEngineIndex: Integer);
    procedure MarkDxpWaitingForReply(AEngineIndex: Integer;
      AMode: TEngineSearchMode; const AReason: String = 'waiting for engine reply');
    function DxpShouldAcceptMove(AEngineIndex: Integer;
      ASearchMode: TEngineSearchMode): Boolean;
    function DxpShouldAcceptGameEnd(AEngineIndex: Integer): Boolean;
    procedure ClearEngineTiming(AEngineIndex: Integer);
    procedure LogEngineTimingDiagnostic(AEngineIndex: Integer;
      const AProtocolName, AReceivedMessage: String; AReceivedAtSeconds: Double);
    procedure LogDxpTimingDiagnostic(AEngineIndex: Integer;
      const AReceivedMessage: String; AReceivedAtSeconds: Double);
    procedure StoreEngineTimingStart(AEngineIndex: Integer;
      const ALabel: String);
    procedure StoreDxpTimingStart(AEngineIndex: Integer;
      const ALabel: String);
    procedure DxpConnectionMessage(AEngineIndex: Integer; const AMessage: String;
      AReceivedAtSeconds: Double);
    procedure DxpConnectionConnected(AEngineIndex: Integer;
      ASocket: TSocketStream; ARole: TEngineDxpRole; const AIpAddress: String;
      APort: Word; AConnectAttemptCount, AConnectElapsedMs: QWord);
    procedure DxpConnectionError(AEngineIndex: Integer; const AMessage: String);
    procedure DxpConnectionAttemptFailed(AEngineIndex: Integer;
      const AIpAddress: String; APort: Word; const AMessage: String);
    procedure ProcessDxpMessage(AEngineIndex: Integer; const AMessage: String;
      AReceivedAtSeconds: Double);
    procedure HandleDxpGameAccPacket(AEngineIndex: Integer);
    procedure HandleDxpMovePacket(AEngineIndex: Integer; const AMoveText: String;
      AReceivedAtSeconds: Double);
    procedure SyncHubLaunchArgumentParam(AEngineIndex: Integer);
    procedure SyncSendStartingPositionParam(AEngineIndex: Integer);
    procedure SyncSingleCapturesIncludeCapturedSquareParam(AEngineIndex: Integer);
    procedure SyncEngineSupportsMctsParam(AEngineIndex: Integer);
    procedure SyncScorePerspectiveParam(AEngineIndex: Integer);
    procedure SyncEvaluationDepthMinParam(AEngineIndex: Integer);
    procedure SyncEvaluationBarMaxParam(AEngineIndex: Integer);
    procedure LoadHubLaunchArgumentFromParams(AEngineIndex: Integer);
    procedure ApplyEngineSlotProtocolConfig(AEngineIndex: Integer;
      const AConfig: TEngineProtocolConfig);
    procedure ResetEngineSlotProtocolConfig(AEngineIndex: Integer);
    function EngineSlotParamValue(AEngineIndex: Integer; const AName,
      ADefault: String): String;
    function EngineSlotParamBool(AEngineIndex: Integer; const AName: String;
      ADefault: Boolean): Boolean;
    function EngineSlotParamInt(AEngineIndex: Integer; const AName: String;
      ADefault: Integer): Integer;
    function EngineSlotParamFloat(AEngineIndex: Integer; const AName: String;
      ADefault: Double): Double;
    function EngineSendStartingPosition(AEngineIndex: Integer): Boolean;
    function EngineSingleCapturesIncludeCapturedSquare(AEngineIndex: Integer): Boolean;
    procedure RemoveAnalyzeSendsInfoParam(AEngineIndex: Integer);
    function EngineSupportsMcts(AEngineIndex: Integer): Boolean;
    function EngineScorePerspective(AEngineIndex: Integer): String;
    function EngineEvaluationDepthMin(AEngineIndex: Integer): Double;
    function EngineEvaluationBarMax(AEngineIndex: Integer): Double;
    procedure AutoPlayButtonClick(Sender: TObject);
    procedure GoButtonClick(Sender: TObject);
    function PlayEngineMove(const AEngineMove: String;
      AEngineIndex: Integer = 1; ADxpReceivedAtSeconds: Double = 0): Boolean;
    function CurrentPositionRepetitionCount: Integer;
    function HubPositionString: String;
    function HubPositionCommand(AEngineIndex: Integer): String;
    function CurrentEngineRemainingTimeSeconds: Double;
    function HasPlayGameEnginePlayer: Boolean;
    function HasPlayGameHumanPlayer: Boolean;
    function IsPlayGameHumanTurn: Boolean;
    function IsPlayGameEngineTurn: Boolean;
    function IsPlayGameSecondEngineTurn: Boolean;
    function EngineIsDxp(AEngineIndex: Integer): Boolean;
    function EngineLogName(AEngineIndex: Integer): String;
    function PlayerNameToMove: String;
    procedure InvalidateBoard;
    procedure InvalidateBoardSquare(ASquare: Integer);
    procedure InvalidateEngineEvalBar;
    procedure RepaintEngineEvalBarDelta(AOldScore, ANewScore: Double);
    function BuildPdnMoveText(const AResult: String; AStoreRanges: Boolean): String;
    function BuildAnalyzePvText(AStoreRanges: Boolean): String;
    function EngineInfoAnnotation(const ALine: String): String;
    function HistoryAnnotationScoreWhite(APly: Integer; out AScore: Double): Boolean;
    function GuessResultFromFinalPosition: String;
    procedure HistoryMemoClick(Sender: TObject);
    procedure HistoryMemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure AnalyzePvMemoClick(Sender: TObject);
    procedure AnalyzePvEngineComboChange(Sender: TObject);
    procedure AnalyzePvMemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure AnalyzePvMemoKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure AnalysisBoardFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure AnalysisBoardPaintBoxPaint(Sender: TObject);
    procedure HandleEngineDoneMove(const AMoveText: String);
    procedure FormResize(Sender: TObject);
    procedure LoadFenFile(const AFileName: String);
    procedure LoadPdnFile(const AFileName: String);
    procedure LeavePlayGameMode;
    procedure FinishPlayGameMode(AUpdateHistory: Boolean = False;
      ARestartAnalyze: Boolean = False);
    procedure MoveListMoveClick(Sender: TObject);
    procedure MctsButtonClick(Sender: TObject);
    procedure MovesMemoDblClick(Sender: TObject);
    procedure OpenEngineMenuItemClick(Sender: TObject);
    procedure EngineLauncherListDblClick(Sender: TObject);
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
    procedure SaveRegisteredEnginesDialog(ADialog: TCustomForm);
    function CheckDrawByRepetition: Boolean;
    function CheckDrawByTwentyFiveMoveRule: Boolean;
    procedure AppendEngineSlotLogOrMain(AEngineIndex: Integer;
      const AText: String);
    procedure LogGameEventToRelevantEngines(const AText: String;
      AOriginEngineIndex: Integer = 0);
    procedure EndCurrentGame(AReason: TGameEndReason; const AResult: String = '';
      AOriginEngineIndex: Integer = 0; ARestartAnalyze: Boolean = False);
    procedure StopModeBecause(AEngineIndex: Integer; AMode: TStoppedMode;
      const AReason: String);
    procedure StopAutoPlayBecause(AEngineIndex: Integer; const AReason: String);
    procedure StopPlayGameBecause(AEngineIndex: Integer; const AReason: String);
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
    procedure ClearAnalyzeBoardHighlights;
    procedure ClearAnalyzePvForEngine(AEngineIndex: Integer);
    procedure ClearAnalyzePvForAllEngines;
    procedure ClearSearchAnalysisDisplay;
    procedure HandleTerminalSearchPosition(AEngineIndex: Integer;
      AStopAutoPlay, ALeavePlayGame: Boolean);
    procedure ShowAnalyzePvFromEngine(AEngineIndex: Integer);
    procedure SelectBoardSquare(ASquare: Integer);
    function ShowEngineLauncherDialog(AEngineIndex: Integer;
      out AFileName, APreferredProtocol: String): Boolean;
    function ShowEngineLaunchOptionsDialog(AEngineIndex: Integer;
      const APreferredProtocol: String = ''): Boolean;
    function SquareAtPoint(X, Y: Integer): Integer;
    procedure ProcessEngineSlotOutput(AEngineIndex: Integer;
      const AText: String);
    procedure DispatchEngineSlotReceivedLine(AEngineIndex: Integer;
      const ALine: String);
    procedure EditEngineParamsMenuItemClick(Sender: TObject);
    procedure EngineParamsDialogHide(Sender: TObject);
    procedure ShowEngineSlotParamsDialog(AEngineIndex: Integer);
    procedure HandleEngineSlotParamsDialogHide(AEngineIndex: Integer;
      ADialog: TObject);
    procedure SyncEngineSlotGuiParams(AEngineIndex: Integer);
    procedure HandleEngineSlotIdLine(AEngineIndex: Integer;
      const ALine: String);
    procedure HandleEngineSlotParamLine(AEngineIndex: Integer;
      const ALine: String);
    procedure HandleEngineSlotInfoLine(AEngineIndex: Integer;
      const ALine: String);
    procedure HandleEngineSlotErrorLine(AEngineIndex: Integer;
      const ALine: String);
    procedure HandleEngineSlotWaitLine(AEngineIndex: Integer);
    procedure HandleEngineSlotReadyLine(AEngineIndex: Integer);
    procedure HandleEngineSlotDoneLine(AEngineIndex: Integer;
      const ALine: String);
    function HandleHubDoneDrawResult(AEngineIndex: Integer;
      const AResultText: String): Boolean;
    function HandleStoppedSearchDone(AEngineIndex: Integer;
      const AMoveText: String): Boolean;
    procedure HandleEngine1DoneMove(const AMoveText: String);
    procedure HandleEngine2DoneMove(const AMoveText: String;
      ASearchMode: TEngineSearchMode);
    procedure EngineIniBrowseClick(Sender: TObject);
    procedure SendEngineSlotParams(AEngineIndex: Integer);
    procedure SetupMenu;
    procedure SetupBoardArea;
    procedure SetupEngineLog;
    function CreateEngineLogPanel(AParent: TWinControl; AAlign: TAlign;
      AHeight: Integer = 0): TPanel;
    procedure SetupEngineSlotLogControls(AEngineIndex: Integer;
      AParentPanel: TWinControl; const AInitialText: String);
    procedure SetupEngineSlotLogPopupMenu(AEngineIndex: Integer);
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
    procedure PrepareManualEngineCommand(AClearPendingActions,
      ALeavePlayGameMode: Boolean);
    procedure StorePendingPlayGameOptions(AWhiteIsEngine,
      ABlackIsEngine: Boolean; const AWhiteName, ABlackName: String;
      AGameMinutes: Double; AStartFromCurrent: Boolean;
      AWhiteEngineIndex, ABlackEngineIndex: Integer);
    procedure PendingActionForPlayGameStart(out AAction: TPendingEngineAction;
      out AMode: TEngineSearchMode);
    procedure RequestPlayGameStartAfterEngine1Stop;
    procedure HandleEngine2StopBeforePlayGameStart;
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
    procedure StartEngineSlot(AEngineIndex: Integer; const AFileName: String;
      AUseCurrentParams, AShowLaunchOptions: Boolean;
      const APreferredProtocol: String);
    procedure PrepareUiForEngineSlotStart(AEngineIndex: Integer);
    procedure ResetPrimaryStateBeforeEngineStart;
    procedure ResetSecondaryStateBeforeEngineStart;
    function PrepareEngineSlotForLaunch(AEngineIndex: Integer;
      const AFileName: String; AUseCurrentParams, AShowLaunchOptions: Boolean;
      const APreferredProtocol: String): Boolean;
    procedure PrepareEngineSlotLaunchLog(AEngineIndex: Integer;
      const AFileName: String);
    procedure LoadEngineSlotLaunchParams(AEngineIndex: Integer;
      const AFileName: String; AUseCurrentParams: Boolean);
    function ConfirmEngineSlotLaunchOptions(AEngineIndex: Integer;
      AShowLaunchOptions: Boolean; const APreferredProtocol: String): Boolean;
    procedure FinalizeEngineSlotLaunchPreparation(AEngineIndex: Integer);
    function EnsureDxpListenerReadyForLaunch(AEngineIndex: Integer): Boolean;
    procedure LogEngineSlotLaunch(AEngineIndex: Integer; ALaunchArgs: TStringList);
    procedure LaunchEngineSlotProcess(AEngineIndex: Integer;
      const AFileName: String; ALaunchArgs: TStringList);
    procedure FinalizeEngineSlotLaunch(AEngineIndex: Integer;
      const AFileName: String);
    procedure RegisterLaunchedEngineSlot(AEngineIndex: Integer;
      const AFileName: String);
    procedure FinalizeDxpEngineSlotLaunch(AEngineIndex: Integer);
    procedure FinalizeHubEngineSlotLaunch(AEngineIndex: Integer);
    procedure SendEngineSlotCommand(AEngineIndex: Integer;
      const ACommand: String);
    procedure LogEngineSlotCommandSent(AEngineIndex: Integer;
      const ACommand: String);
    procedure SetEngineSlotState(AEngineIndex: Integer; AState: TEngineState);
    procedure SetGuiState(AState: TGuiState; const AReason: String);
    function EngineSlotPendingAction(AEngineIndex: Integer): TPendingEngineAction;
    procedure ClearEngineSlotPendingAction(AEngineIndex: Integer);
    procedure SetEngineSlotPendingAction(AEngineIndex: Integer;
      AAction: TPendingEngineAction; AMode: TEngineSearchMode = esmIdle);
    procedure RequestEngineSlotActionAfterStop(AEngineIndex: Integer;
      AAction: TPendingEngineAction; AMode: TEngineSearchMode;
      const AReason: String);
    function RunPendingEngineSlotAction(AEngineIndex: Integer;
      const AStoppedMoveText: String): Boolean;
    procedure BeginEngineSlotSearch(AEngineIndex: Integer;
      AMode: TEngineSearchMode; AState: TEngineState);
    procedure FinishEngineSlotSearch(AEngineIndex: Integer);
    procedure ResetEngineSlotRuntime(AEngineIndex: Integer);
    function EngineSlotSupportsAutoPlay(AEngineIndex: Integer): Boolean;
    function EngineSlotCommandUiAvailable(AEngineIndex: Integer): Boolean;
    procedure UpdateEngineCommandButtons;
    procedure UpdateEngineSlotReadyUi(AEngineIndex: Integer);
    procedure UpdateEngineStateLabels;
    procedure UpdateRegisteredEngineId(const AFileName, AEngineId: String;
      const AProtocol: String = '');
    procedure UpdateRegisteredEngineProtocol(const AFileName,
      AProtocol: String);
    procedure SendPlayGameHumanTurnAnalyze;
    function CurrentPlayGameEngineIndex: Integer;
    procedure ContinuePlayGameSearch;
    procedure ContinuePlayGameEngineTurn(AEngineIndex: Integer);
    procedure ContinuePlayGameHumanTurn;
    procedure StartDxpPlayGameThink(AEngineIndex: Integer);
    procedure StartHubPlayGameThink(AEngineIndex: Integer);
    procedure ContinueAutoPlayAfterPositionChange;
    procedure MarkPlayGameWaitingEngine(AActorEngineIndex: Integer);
    procedure ContinuePlayGameAfterPositionChange(AActorEngineIndex: Integer);
    function HandleTerminalPositionAfterFlowChange(
      AReason: TGameFlowReason): Boolean;
    procedure ContinueGameFlowAfterPositionChange(AReason: TGameFlowReason;
      AActorEngineIndex: Integer = 0);
    procedure HandleEngineMoveForSearchMode(AEngineIndex: Integer;
      const AMoveText: String; ASearchMode: TEngineSearchMode;
      ADxpReceivedAtSeconds: Double = 0);
    function ApplyEngineMoveForSearchMode(AEngineIndex: Integer;
      const AMoveText: String; ASearchMode: TEngineSearchMode;
      ADxpReceivedAtSeconds: Double = 0): Boolean;
    procedure HandleFailedEngineMove(AEngineIndex: Integer;
      ASearchMode: TEngineSearchMode);
    procedure ContinueAfterEngineMove(AEngineIndex: Integer;
      ASearchMode: TEngineSearchMode);
    procedure SendDxpStartOrMoveToEngine(AEngineIndex: Integer;
      AMode: TEngineSearchMode);
    function CanStartHubSearch(AEngineIndex: Integer; AGoCommand: THubGoCommand;
      ARequireMctsSupport: Boolean): Boolean;
    function EngineSlotReadyForSearch(AEngineIndex: Integer): Boolean;
    function ReadyEngineSlotsForSearch: TIntegerArray;
    procedure AppendEngineSlotLogs(const ASlots: TIntegerArray;
      const AText: String);
    procedure HandleTerminalSearchPositions(const ASlots: TIntegerArray;
      const APreparation: TEngineSearchPreparation);
    function HandleEngineSlotTerminalSearchPosition(AEngineIndex: Integer;
      AAutoPlay, ASendTerminalToEngine: Boolean): Boolean;
    procedure StartHubEngineSlotSearch(AEngineIndex: Integer;
      ALevelCommand: THubLevelCommand; AGoCommand: THubGoCommand;
      AMode: TEngineSearchMode; AState: TEngineState;
      ARequireMctsSupport: Boolean);
    procedure SendHubSearchToEngine(AEngineIndex: Integer;
      ALevelCommand: THubLevelCommand; AGoCommand: THubGoCommand;
      AMode: TEngineSearchMode; AState: TEngineState);
    procedure SendGoAnalyzeToEngine(AMode: TEngineSearchMode = esmAnalyze);
    procedure SendGoAnalyzeToEngineSlot(AEngineIndex: Integer;
      AMode: TEngineSearchMode);
    procedure RequestOrSendAnalyzeToEngineSlot(AEngineIndex: Integer;
      AMode: TEngineSearchMode; const AStopReason: String);
    procedure SendGoMctsToEngine;
    procedure SendGoMctsToEngineSlot(AEngineIndex: Integer);
    procedure SendGoThinkToEngineSlot(AEngineIndex: Integer;
      AMode: TEngineSearchMode);
    procedure RequestOrSendThinkToEngineSlot(AEngineIndex: Integer;
      AMode: TEngineSearchMode; const AStopReason: String);
    procedure SendProtocolCommandToEngineSlot(AEngineIndex: Integer;
      ACommand: TEngineProtocolCommand; AMode: TEngineSearchMode = esmIdle);
    procedure SendProtocolCommandToAllEngines(ACommand: TEngineProtocolCommand;
      AMode: TEngineSearchMode = esmIdle);
    procedure RestartEngineAnalyze;
    procedure SendStopToEngineSlot(AEngineIndex: Integer);
    procedure SendStopToAllEngines;
    procedure SendProtocolCommandToEngineSlots(const ASlots: TIntegerArray;
      ACommand: TEngineProtocolCommand; AMode: TEngineSearchMode = esmIdle);
    procedure ClearEngineSlotStopState(AEngineIndex: Integer;
      APreviousState: TEngineState; AStoppedByHubCommand: Boolean);
    procedure LogEngineSlotStopTransition(AEngineIndex: Integer;
      APreviousState: TEngineState);
    procedure StopDxpEngineSlot(AEngineIndex: Integer;
      APreviousState: TEngineState);
    procedure StopHubEngineSlot(AEngineIndex: Integer;
      APreviousState: TEngineState);
    procedure SendPositionMenuItemClick(Sender: TObject);
    procedure SendPositionToEngine;
    procedure SavePdnMenuItemClick(Sender: TObject);
    procedure SavePdnOptionsDialogHide(Sender: TObject);
    procedure SaveEngineLogMenuItemClick(Sender: TObject);
    procedure AnalyzeMenuItemClick(Sender: TObject);
    procedure ShowTimestampsMenuItemClick(Sender: TObject);
    procedure SavePdnFile(const AFileName, AWhiteName, ABlackName,
      AResult: String; const AEvent: String = '?'; const ARound: String = '?';
      AAppend: Boolean = False);
    procedure EndGameIfTerminalPosition;
    procedure StopButtonClick(Sender: TObject);
    procedure StopGameClocks;
    procedure PauseGameClocks;
    procedure PauseGameClocksAt(AReceivedAtSeconds: Double);
    procedure ExecuteMoveFromList(AMoveIndex: Integer; AContinueEngine: Boolean);
    procedure ExecuteLegalMoveIndex(AMoveIndex: Integer; AContinueEngine: Boolean);
    procedure UpdateBoardLayout;
    procedure UpdateClockLabels;
    procedure HandleClockExpired;
    procedure UpdateGameClock;
    procedure UpdateHistoryList;
    procedure UpdateMovePanelWidth;
    procedure UpdateMoveList;
    procedure UpdateAnalyzePvList;
    procedure UnlockAnalyzePv;
    procedure UpdateEnginePopupMenuItems;
    procedure UpdateAnalyzeMenuItems;
    procedure UpdateAnalyzeBestMoveFromMoveText(const AMoveText: String);
    procedure UpdateAnalyzeBestMoveFromInfo(AEngineIndex: Integer;
      const ALine: String);
    procedure UpdateAnalyzePvFromMoveText(AEngineIndex: Integer;
      const APvText: String);
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
  PlatformTime,
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
  BoardSideMarkerGap = 6;
  BoardSideMarkerWidth = 72;
  BoardMargin = 24;
  WoodSquareColor = TColor($00305E8B);
  AnalyzeBestSourceColor = TColor($0000A5FF);
  AnalyzeHintSourceColor = clRed;

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
  FRoundRobinGroup.Items.Add('Swiss');
  FRoundRobinGroup.ItemIndex := TournamentPairingIndexSingleRoundRobin;
  FRoundRobinGroup.OnClick := @RoundRobinGroupClick;
  FRoundRobinGroup.SetBounds(72, 42, 250, 76);
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
  FStartButton.Caption := 'Create pairing for next round';
  FStartButton.SetBounds(206, 7, 190, 28);
  FStartButton.OnClick := @StartButtonClick;

  FPlayRoundButton := TButton.Create(ButtonPanel);
  FPlayRoundButton.Parent := ButtonPanel;
  FPlayRoundButton.Caption := 'Complete next round';
  FPlayRoundButton.SetBounds(404, 7, 150, 28);
  FPlayRoundButton.OnClick := @PlayRoundButtonClick;

  FStopButton := TButton.Create(ButtonPanel);
  FStopButton.Parent := ButtonPanel;
  FStopButton.Caption := 'Stop';
  FStopButton.SetBounds(562, 7, 86, 28);
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
  FGrid.ColCount := 6;
  FGrid.DefaultDrawing := False;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.RowCount := 2;
  FGrid.Options := FGrid.Options - [goEditing] + [goColSizing, goRowSelect];
  FGrid.Cells[TournamentColGame, 0] := 'Game';
  FGrid.Cells[TournamentColRound, 0] := 'Round';
  FGrid.Cells[TournamentColWhite, 0] := 'White';
  FGrid.Cells[TournamentColBlack, 0] := 'Black';
  FGrid.Cells[TournamentColResult, 0] := 'Result';
  FGrid.Cells[TournamentColReason, 0] := 'Reason';
  FGrid.Cells[TournamentColResult, 1] := '*';
  FGrid.Cells[TournamentColReason, 1] := '';
  FGrid.ColWidths[TournamentColGame] := 54;
  FGrid.ColWidths[TournamentColRound] := 54;
  FGrid.ColWidths[TournamentColWhite] := 260;
  FGrid.ColWidths[TournamentColBlack] := 260;
  FGrid.ColWidths[TournamentColResult] := 90;
  FGrid.ColWidths[TournamentColReason] := 180;
  FGrid.OnClick := @GridClick;
  FGrid.OnDrawCell := @PairingGridDrawCell;

  FResultCombo := TComboBox.Create(FGrid);
  FResultCombo.Parent := FGrid;
  FResultCombo.Style := csDropDownList;
  FResultCombo.Items.Add('*');
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
begin
  if not ConfirmClose then
  begin
    CloseAction := caNone;
    Exit;
  end;

  if FTournamentRunning then
    StopButtonClick(Self);
  if Owner is TMainWindow then
    TMainWindow(Owner).FTournamentDialog := nil;
  CloseAction := caFree;
end;

function TTournamentDialog.ConfirmClose: Boolean;
var
  Answer: Integer;
begin
  Result := False;
  if FDirty then
  begin
    Answer := ShowGuiConfirmationDialog(Self, 'Unsaved tournament',
      'Tournament results have changed.' + LineEnding +
      'Save before closing?', 'Save', 'Don''t Save', mrNo);
    case Answer of
      mrYes:
        if not SaveTournament then
        begin
          Exit;
        end;
      mrCancel:
      begin
        Exit;
      end;
    end;
  end;

  Result := True;
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

procedure TTournamentDialog.ClearPairingGrid;
begin
  ClearTournamentPairingGrid(FGrid);
end;

procedure TTournamentDialog.MinutesEditChange(Sender: TObject);
begin
  if FSuppressMinutesChange then
    Exit;
  if FMinutesEdit.Value = FPreviousMinutesValue then
    Exit;

  if (not GridIsEmpty) and
    (ShowGuiConfirmationDialog(Self, 'Tournament',
    'Warning: you will lose all results if you change the time setting.' +
    LineEnding + 'Are you sure?', 'Yes', 'No', mrNo) <> mrYes) then
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
    ClearPairingGrid;
    UpdateCrossTable;
    MarkDirty;
  end;
end;

procedure TTournamentDialog.CrossTableDrawCell(Sender: TObject; ACol,
  ARow: Integer; ARect: TRect; AState: TGridDrawState);
begin
  DrawCrossTableCell(TStringGrid(Sender), ACol, ARow, ARect);
end;

procedure TTournamentDialog.PairingGridDrawCell(Sender: TObject; ACol,
  ARow: Integer; ARect: TRect; AState: TGridDrawState);
begin
  DrawPairingGridCell(TStringGrid(Sender), ACol, ARow, ARect,
    FCurrentTournamentRow, FTournamentRunning);
end;

procedure TTournamentDialog.AddPairing(const AWhite, ABlack: String;
  ARound: Integer);
begin
  AddTournamentPairingRow(FGrid, AWhite, ABlack, ARound);
  UpdateCrossTable;
  MarkDirty;
end;

procedure TTournamentDialog.CollectPairingRows(AWhiteEngines, ABlackEngines,
  AResults: TStrings);
begin
  CollectTournamentPairingRows(FGrid, AWhiteEngines, ABlackEngines,
    AResults);
end;

procedure TTournamentDialog.CollectRoundRows(ARounds: TStrings);
begin
  CollectTournamentRoundRows(FGrid, ARounds);
end;

procedure TTournamentDialog.CollectSelectedEngineNames(AEngines: TStrings);
begin
  CollectSelectedTournamentEngineNames(FEngineCheckList, AEngines);
end;

procedure TTournamentDialog.CollectSelectedEngineNames(
  var AEngines: TTournamentTextArray);
begin
  CollectSelectedTournamentEngineNames(FEngineCheckList, AEngines);
end;

procedure TTournamentDialog.ApplyTournamentData(const AData: TTournamentFileData);
begin
  FNameEdit.Text := AData.Name;
  FSuppressMinutesChange := True;
  try
    FMinutesEdit.Value := AData.Minutes;
    FPreviousMinutesValue := FMinutesEdit.Value;
  finally
    FSuppressMinutesChange := False;
  end;

  FSuppressRoundRobinChange := True;
  try
    FRoundRobinGroup.ItemIndex :=
      RoundRobinIndexForTournamentType(AData.TournamentType);
    FPreviousRoundRobinIndex := FRoundRobinGroup.ItemIndex;
  finally
    FSuppressRoundRobinChange := False;
  end;

  ApplySelectedTournamentEngineNames(FEngineCheckList, AData.EngineNames);
  ApplyTournamentGamesToGrid(FGrid, AData);
  UpdateCrossTable;
end;

procedure TTournamentDialog.LoadEngineNames(AEngines: TStrings);
begin
  LoadRegisteredTournamentEngines(FEnginesFileName, AEngines,
    FEngineFileNames, FEngineProtocols);
end;

function TTournamentDialog.EngineProtocolForName(const AName: String): String;
begin
  Result := '';
  if (AName <> '') and (FEngineProtocols <> nil) then
    Result := LowerCase(Trim(FEngineProtocols.Values[AName]));
end;

function TTournamentDialog.EngineFileNameForName(const AName: String): String;
begin
  Result := '';
  if AName = '' then
    Exit;
  if (FEngineFileNames <> nil) and (FEngineFileNames.Values[AName] <> '') then
    Exit(FEngineFileNames.Values[AName]);
  Result := RegisteredEngineFileNameForDisplayName(FEnginesFileName, AName);
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

procedure TTournamentDialog.UpdateCrossTable;
var
  BlackEngines: TStringList;
  I: Integer;
  J: Integer;
  Results: TStringList;
  SelectedEngines: TStringList;
  Table: TTournamentCrossTable;
  WhiteEngines: TStringList;

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

  SelectedEngines := TStringList.Create;
  WhiteEngines := TStringList.Create;
  BlackEngines := TStringList.Create;
  Results := TStringList.Create;
  try
    CollectSelectedEngineNames(SelectedEngines);
    CollectPairingRows(WhiteEngines, BlackEngines, Results);

    BuildTournamentCrossTable(SelectedEngines, WhiteEngines, BlackEngines,
      Results, Table);

    FCrossTableGrid.ColCount := Max(4, Length(Table.EngineNames) + 4);
    FCrossTableGrid.RowCount := Max(2, Length(Table.EngineNames) + 1);
    for I := 0 to FCrossTableGrid.ColCount - 1 do
      for J := 0 to FCrossTableGrid.RowCount - 1 do
        FCrossTableGrid.Cells[I, J] := '';

    FCrossTableGrid.Cells[0, 0] := 'Engine';
    for I := 0 to High(Table.EngineNames) do
    begin
      FCrossTableGrid.Cells[I + 1, 0] :=
        CompactTournamentEngineHeader(Table.EngineNames[Table.Order[I]]);
      FCrossTableGrid.Cells[0, I + 1] := Table.EngineNames[Table.Order[I]];
    end;
    FCrossTableGrid.Cells[Length(Table.EngineNames) + 1, 0] := 'Points';
    FCrossTableGrid.Cells[Length(Table.EngineNames) + 2, 0] := '#Wins';
    FCrossTableGrid.Cells[Length(Table.EngineNames) + 3, 0] := 'SB';

    if Length(Table.EngineNames) = 0 then
    begin
      FCrossTableGrid.Cells[0, 1] := '';
      FCrossTableGrid.Cells[1, 1] := '0';
    end;

    for I := 0 to High(Table.EngineNames) do
    begin
      for J := 0 to High(Table.EngineNames) do
        FCrossTableGrid.Cells[J + 1, I + 1] :=
          Table.Matrix[Table.Order[I], Table.Order[J]];
      FCrossTableGrid.Cells[Length(Table.EngineNames) + 1, I + 1] :=
        IntToStr(Table.Points[Table.Order[I]]);
      FCrossTableGrid.Cells[Length(Table.EngineNames) + 2, I + 1] :=
        IntToStr(Table.Wins[Table.Order[I]]);
      FCrossTableGrid.Cells[Length(Table.EngineNames) + 3, I + 1] :=
        FormatTournamentSB(Table.SB[Table.Order[I]]);
    end;

    AutoSizeCrossTableColumns;
    AdjustSectionHeights;
    UpdateTournamentButtons;
  finally
    Results.Free;
    BlackEngines.Free;
    WhiteEngines.Free;
    SelectedEngines.Free;
  end;
end;

procedure TTournamentDialog.UpdateTournamentButtons;
var
  BlackEngines: TStringList;
  Results: TStringList;
  State: TTournamentButtonState;
  WhiteEngines: TStringList;
begin
  if (FStartButton = nil) or (FPlayRoundButton = nil) then
    Exit;

  WhiteEngines := TStringList.Create;
  BlackEngines := TStringList.Create;
  Results := TStringList.Create;
  try
    CollectPairingRows(WhiteEngines, BlackEngines, Results);

    State := BuildTournamentButtonState(
      TournamentRoundRobinIndexIsSwiss(FRoundRobinGroup.ItemIndex),
      FTournamentRunning, GridIsEmpty, WhiteEngines, BlackEngines, Results);
    FStartButton.Enabled := State.CanCreatePairing;
    FPlayRoundButton.Enabled := State.CanPlayRound;
    FStopButton.Enabled := State.CanStop;
  finally
    Results.Free;
    BlackEngines.Free;
    WhiteEngines.Free;
  end;
end;

procedure TTournamentDialog.StartButtonClick(Sender: TObject);
var
  BlackEngines: TStringList;
  Engines: TStringList;
  PairingRound: TTournamentPairingRound;
  Results: TStringList;
  Rounds: TStringList;
  SwissPairing: Boolean;
  WhiteEngines: TStringList;
begin
  if FTournamentRunning then
    Exit;

  Engines := TStringList.Create;
  WhiteEngines := TStringList.Create;
  BlackEngines := TStringList.Create;
  Results := TStringList.Create;
  Rounds := TStringList.Create;
  try
    CollectSelectedEngineNames(Engines);
    if Engines.Count < 2 then
    begin
      ShowGuiOkDialog(Self, 'Tournament',
        'Select at least two engines for the tournament.');
      Exit;
    end;

    SwissPairing := TournamentRoundRobinIndexIsSwiss(FRoundRobinGroup.ItemIndex);
    CollectPairingRows(WhiteEngines, BlackEngines, Results);
    CollectRoundRows(Rounds);

    if not SwissPairing then
    begin
      if not GridIsEmpty then
        Exit;
      ClearPairingGrid;
    end;
    if SwissPairing and
      (not TournamentAllResultsKnown(WhiteEngines, BlackEngines, Results)) then
    begin
      ShowGuiOkDialog(Self, 'Tournament',
        'Enter all results before creating the next Swiss round.');
      Exit;
    end;

    PairingRound := BuildTournamentPairingRound(SwissPairing,
      TournamentRoundRobinIndexIsDouble(FRoundRobinGroup.ItemIndex), Engines,
      WhiteEngines, BlackEngines, Results, Rounds);
    if PairingRound.HasRepeat and
      (ShowGuiConfirmationDialog(Self, 'Tournament',
      'A Swiss pairing without repeated opponents is no longer possible.' +
      LineEnding + 'Continue with repeated pairing?', 'Continue', '',
      mrCancel) <> mrYes) then
      Exit;
    ApplyTournamentPairingRoundToGrid(FGrid, PairingRound);
  finally
    Rounds.Free;
    Results.Free;
    BlackEngines.Free;
    WhiteEngines.Free;
    Engines.Free;
  end;

  UpdateCrossTable;
  MarkDirty;
end;

procedure TTournamentDialog.PlayRoundButtonClick(Sender: TObject);
begin
  if FTournamentRunning then
    Exit;
  FTournamentRunning := StartNextTournamentGame;
  FTournamentTimer.Enabled := FTournamentRunning;
  if (Owner is TMainWindow) and FTournamentRunning then
    TMainWindow(Owner).SetGuiState(gsTournamentRunning, 'tournament started');
  UpdateTournamentButtons;
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
  if FGrid <> nil then
    FGrid.Invalidate;
  FCurrentWhiteEngineIndex := 1;
  FCurrentBlackEngineIndex := 2;
  if FTournamentTimer <> nil then
    FTournamentTimer.Enabled := False;
  if Owner is TMainWindow then
  begin
    Main := TMainWindow(Owner);
    Main.StopButtonClick(Sender);
  end;
  UpdateTournamentButtons;
end;

function TTournamentDialog.FindNextUnplayedTournamentRow: Integer;
var
  BlackEngines: TStringList;
  Results: TStringList;
  Rounds: TStringList;
  WhiteEngines: TStringList;
begin
  WhiteEngines := TStringList.Create;
  BlackEngines := TStringList.Create;
  Results := TStringList.Create;
  Rounds := TStringList.Create;
  try
    CollectPairingRows(WhiteEngines, BlackEngines, Results);
    CollectRoundRows(Rounds);
    Result := TournamentPairing.FindNextUnplayedTournamentRow(
      TournamentRoundRobinIndexIsSwiss(FRoundRobinGroup.ItemIndex), Results,
      Rounds);
  finally
    Rounds.Free;
    Results.Free;
    BlackEngines.Free;
    WhiteEngines.Free;
  end;
end;

function TTournamentDialog.TournamentSlotMatches(AMain: TMainWindow;
  AIndex: Integer; const AName, AFileName: String): Boolean;
begin
  Result := False;
  if (AMain = nil) or (AIndex < Low(AMain.FEngines)) or
    (AIndex > High(AMain.FEngines)) then
    Exit;
  if (AIndex = 1) and (not AMain.EngineIsRunning) then
    Exit;
  if (AIndex = 2) and (not AMain.SecondEngineIsRunning) then
    Exit;
  Result := ((AFileName <> '') and
    SameFileName(AMain.FEngines[AIndex].FileName, AFileName)) or
    SameText(AMain.FEngines[AIndex].DisplayName, AName) or
    SameText(ChangeFileExt(ExtractFileName(AMain.FEngines[AIndex].FileName),
    ''), AName) or SameText(AName, 'Engine' + IntToStr(AIndex)) or
    SameText(AName, 'Engine ' + IntToStr(AIndex));
end;

function TTournamentDialog.LoadedSlotIndexForTournamentEngine(
  AMain: TMainWindow; const AName, AFileName: String): Integer;
begin
  if TournamentSlotMatches(AMain, 1, AName, AFileName) then
    Exit(1);
  if TournamentSlotMatches(AMain, 2, AName, AFileName) then
    Exit(2);
  Result := 0;
end;

function TTournamentDialog.OtherTournamentSlot(AEngineIndex: Integer): Integer;
begin
  if AEngineIndex = 1 then
    Result := 2
  else
    Result := 1;
end;

procedure TTournamentDialog.HighlightTournamentRow(ARow: Integer);
begin
  FCurrentTournamentRow := ARow;
  FCurrentGameStarted := False;
  if FGrid = nil then
    Exit;

  FGrid.Row := ARow;
  FGrid.Col := 0;
  if ARow >= FGrid.FixedRows then
    FGrid.TopRow := ARow;
  FGrid.Invalidate;
end;

procedure TTournamentDialog.LoadTournamentEngineIntoSlot(AMain: TMainWindow;
  AEngineIndex: Integer; const AName, AFileName, AProtocol: String);
begin
  AMain.FEngines[AEngineIndex].DisplayName := AName;
  AMain.LoadEngineParamsForProtocol(AEngineIndex, AFileName, AProtocol);
  if AEngineIndex = 2 then
    AMain.StartSecondEngine(AFileName, True)
  else
    AMain.StartEngine(AFileName, True);
end;

function TTournamentDialog.ResolveTournamentPairing(AMain: TMainWindow;
  ARow: Integer; out AWhiteName, ABlackName, AWhiteFileName, ABlackFileName,
  AWhiteProtocol, ABlackProtocol: String; out AWhiteLoadedIndex,
  ABlackLoadedIndex: Integer): Boolean;
begin
  Result := False;
  AWhiteName := FGrid.Cells[TournamentColWhite, ARow];
  ABlackName := FGrid.Cells[TournamentColBlack, ARow];
  AWhiteFileName := EngineFileNameForName(AWhiteName);
  ABlackFileName := EngineFileNameForName(ABlackName);
  AWhiteProtocol := EngineProtocolForName(AWhiteName);
  ABlackProtocol := EngineProtocolForName(ABlackName);
  AWhiteLoadedIndex := LoadedSlotIndexForTournamentEngine(AMain, AWhiteName,
    AWhiteFileName);
  ABlackLoadedIndex := LoadedSlotIndexForTournamentEngine(AMain, ABlackName,
    ABlackFileName);

  if (AWhiteFileName = '') and (AWhiteLoadedIndex <> 0) then
    AWhiteFileName := AMain.FEngines[AWhiteLoadedIndex].FileName;
  if (ABlackFileName = '') and (ABlackLoadedIndex <> 0) then
    ABlackFileName := AMain.FEngines[ABlackLoadedIndex].FileName;

  if (AWhiteFileName = '') or (ABlackFileName = '') then
  begin
    ShowGuiOkDialog(Self, 'Tournament',
      'Could not find engine executable for this pairing:' + LineEnding +
      'White: ' + AWhiteName + LineEnding + 'Black: ' + ABlackName);
    Exit;
  end;
  Result := True;
end;

procedure TTournamentDialog.ResolveTournamentSlots(AMain: TMainWindow;
  const AWhiteName, ABlackName, AWhiteFileName, ABlackFileName,
  AWhiteProtocol, ABlackProtocol: String; AWhiteLoadedIndex,
  ABlackLoadedIndex: Integer);
begin
  AWhiteLoadedIndex := LoadedSlotIndexForTournamentEngine(AMain, AWhiteName,
    AWhiteFileName);
  ABlackLoadedIndex := LoadedSlotIndexForTournamentEngine(AMain, ABlackName,
    ABlackFileName);

  if (AWhiteLoadedIndex <> 0) and (ABlackLoadedIndex <> 0) and
    (AWhiteLoadedIndex <> ABlackLoadedIndex) then
  begin
    FCurrentWhiteEngineIndex := AWhiteLoadedIndex;
    FCurrentBlackEngineIndex := ABlackLoadedIndex;
    Exit;
  end;

  if AWhiteLoadedIndex <> 0 then
  begin
    FCurrentWhiteEngineIndex := AWhiteLoadedIndex;
    FCurrentBlackEngineIndex := OtherTournamentSlot(AWhiteLoadedIndex);
    LoadTournamentEngineIntoSlot(AMain, FCurrentBlackEngineIndex, ABlackName,
      ABlackFileName, ABlackProtocol);
  end
  else if ABlackLoadedIndex <> 0 then
  begin
    FCurrentBlackEngineIndex := ABlackLoadedIndex;
    FCurrentWhiteEngineIndex := OtherTournamentSlot(ABlackLoadedIndex);
    LoadTournamentEngineIntoSlot(AMain, FCurrentWhiteEngineIndex, AWhiteName,
      AWhiteFileName, AWhiteProtocol);
  end
  else
  begin
    FCurrentWhiteEngineIndex := 1;
    FCurrentBlackEngineIndex := 2;
    LoadTournamentEngineIntoSlot(AMain, 1, AWhiteName, AWhiteFileName,
      AWhiteProtocol);
    LoadTournamentEngineIntoSlot(AMain, 2, ABlackName, ABlackFileName,
      ABlackProtocol);
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
begin
  Result := False;
  if not (Owner is TMainWindow) then
    Exit;

  Main := TMainWindow(Owner);

  Row := FindNextUnplayedTournamentRow;
  if Row = 0 then
    Exit;

  if not ResolveTournamentPairing(Main, Row, WhiteName, BlackName,
    WhiteFileName, BlackFileName, WhiteProtocol, BlackProtocol,
    WhiteLoadedIndex, BlackLoadedIndex) then
    Exit;

  HighlightTournamentRow(Row);
  Main.FGameResult := '*';
  Main.FGameResultReason := '';
  ResolveTournamentSlots(Main, WhiteName, BlackName, WhiteFileName,
    BlackFileName, WhiteProtocol, BlackProtocol, WhiteLoadedIndex,
    BlackLoadedIndex);

  Result := True;
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
    if Main.EngineSlotAvailableForPlay(FCurrentWhiteEngineIndex) and
      Main.EngineSlotAvailableForPlay(FCurrentBlackEngineIndex) then
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
      FGrid.Cells[TournamentColResult, FCurrentTournamentRow] :=
        Main.FGameResult;
      FGrid.Cells[TournamentColReason, FCurrentTournamentRow] :=
        Main.FGameResultReason;
      UpdateCrossTable;
      MarkDirty;
      SaveTournamentGamePdn(StrToIntDef(FGrid.Cells[TournamentColGame,
        FCurrentTournamentRow], FCurrentTournamentRow));
    end;

    FCurrentGameStarted := False;
    FCurrentTournamentRow := 0;
    FGrid.Invalidate;

    FTournamentRunning := StartNextTournamentGame;
    FTournamentTimer.Enabled := FTournamentRunning;
  end;
end;

procedure TTournamentDialog.GridClick(Sender: TObject);
var
  CellRect: TRect;
begin
  if (FGrid.Row <= 0) or (FGrid.Col <> TournamentColResult) then
  begin
    FResultCombo.Visible := False;
    Exit;
  end;

  CellRect := FGrid.CellRect(TournamentColResult, FGrid.Row);
  FResultCombo.SetBounds(CellRect.Left, CellRect.Top,
    CellRect.Right - CellRect.Left, CellRect.Bottom - CellRect.Top);
  FResultCombo.ItemIndex := FResultCombo.Items.IndexOf(
    FGrid.Cells[TournamentColResult, FGrid.Row]);
  FResultCombo.Visible := True;
  FResultCombo.BringToFront;
  FResultCombo.SetFocus;
  FResultCombo.DroppedDown := True;
end;

procedure TTournamentDialog.ResultComboChange(Sender: TObject);
begin
  if (FGrid.Row > 0) and (FGrid.Col = TournamentColResult) and
    (FResultCombo.ItemIndex >= 0) and
    (FGrid.Cells[TournamentColResult, FGrid.Row] <> FResultCombo.Text) then
  begin
    FGrid.Cells[TournamentColResult, FGrid.Row] := FResultCombo.Text;
    if FResultCombo.Text = '*' then
      FGrid.Cells[TournamentColReason, FGrid.Row] := ''
    else
      FGrid.Cells[TournamentColReason, FGrid.Row] := 'Manual result';
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
    (ShowGuiConfirmationDialog(Self, 'Tournament',
    'Warning: you will lose all results if you change tournament type.' +
    LineEnding + 'Are you sure?', 'Yes', 'No', mrNo) <> mrYes) then
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
    ClearPairingGrid;
    UpdateCrossTable;
    MarkDirty;
  end;
end;

function TTournamentDialog.GridIsEmpty: Boolean;
begin
  Result := TournamentPairingGridIsEmpty(FGrid);
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
  Data: TTournamentFileData;
  FileName: String;
  TournamentType: String;
begin
  Result := False;
  if not SelectTournamentSaveFile(Self, FFileName, FNameEdit.Text, FileName) then
    Exit;

  TournamentType := TournamentTypeForRoundRobinIndex(FRoundRobinGroup.ItemIndex);
  BuildTournamentFileDataFromGrid(FGrid, FEngineCheckList, FNameEdit.Text,
    TournamentType, FMinutesEdit.Value, Data);

  SaveTournamentFile(FileName, Data);
  FFileName := FileName;
  FDirty := False;
  Result := True;
end;

procedure TTournamentDialog.LoadButtonClick(Sender: TObject);
var
  Data: TTournamentFileData;
  FileName: String;
begin
  if not SelectTournamentOpenFile(Self, FileName) then
    Exit;

  LoadTournamentFile(FileName, Data);
  ApplyTournamentData(Data);
  FFileName := FileName;
  FDirty := False;
end;

constructor TMainWindow.Create(AOwner: TComponent);
var
  I: Integer;
begin
  inherited Create(AOwner);

  for I := Low(FEngines) to High(FEngines) do
  begin
    FEngines[I] := TEngineSlot.Create(I);
    FEngines[I].PlatformProcess.OnData := @PlatformProcessData;
  end;

  Caption := 'International Draughts';
  Color := clBtnFace;
  Constraints.MinWidth := 700;
  Constraints.MinHeight := 440;
  Width := 1280;
  Height := 900;
  CenterMainWindowOnScreen;
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
  FSelectedPvEngineIndex := 1;
  FEngineLogShowTimestamps := False;
  FGameWhiteName := 'Human';
  FGameBlackName := 'Human';
  FGameResult := '*';
  FGameResultReason := '';
  FGameDirty := False;
  FShutdownAfterPdnSave := False;
  FShutdownConfirmed := False;
  FSuppressBoardUpdates := False;
  ClearBoardSelection;

  FHistory := TGameHistory.Create;
  ParseFen('W:W31-50:B1-20');
  ResetHistoryFromCurrentPosition;
  FPlayClock := TPlayClockController.Create(250);
  FPlayClock.OnTick := @ClockTimerTimer;
  Application.OnIdle := @ApplicationIdle;
  FEnginePollTimer := TTimer.Create(Self);
  FEnginePollTimer.Enabled := False;
  FEnginePollTimer.Interval := 50;
  FEnginePollTimer.OnTimer := @EnginePollTimerTimer;
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
  Application.OnIdle := nil;
  FreeAndNil(FPlayClock);
  FreeAndNil(FHistory);
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
  PvTextPanel: TPanel;
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

  PvTextPanel := TPanel.Create(PvPanel);
  PvTextPanel.Parent := PvPanel;
  PvTextPanel.Align := alClient;
  PvTextPanel.BevelOuter := bvNone;
  PvTextPanel.BorderSpacing.Right := 6;

  FPvEngineCombo := TComboBox.Create(PvTextPanel);
  FPvEngineCombo.Parent := PvTextPanel;
  FPvEngineCombo.Align := alTop;
  FPvEngineCombo.Height := 26;
  FPvEngineCombo.Style := csDropDownList;
  FPvEngineCombo.Items.Add('Show PV from Engine 1');
  FPvEngineCombo.Items.Add('Show PV from Engine 2');
  FPvEngineCombo.ItemIndex := 0;
  FPvEngineCombo.OnChange := @AnalyzePvEngineComboChange;

  FPvMemo := TMemo.Create(PvTextPanel);
  FPvMemo.Parent := PvTextPanel;
  FPvMemo.Align := alClient;
  FPvMemo.BorderSpacing.Left := 0;
  FPvMemo.BorderSpacing.Top := 3;
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
  BoardPixels := SnapBoardPixels(BoardPixels);
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
    HideBoardClockLabels(FBoardTopClockLabel, FBoardBottomClockLabel);
    Exit;
  end;

  BoardPixels := SnapBoardPixels(BoardPixels);
  UnitLeft := BoardArea.Left + LayoutMargin;
  LegalLeft := UnitLeft;
  LeftPos := UnitLeft + LegalWidth + LegalGap + EvalWidth + EvalGap;
  TopPos := BoardArea.Top + ((BoardArea.Bottom - BoardArea.Top - BoardPixels) div 2);
  FBoardRect := Types.Rect(LeftPos, TopPos, LeftPos + BoardPixels,
    TopPos + BoardPixels);
  FEvalBarRect := EvalBarRectForBoard(FBoardRect, EvalBarGap, EvalBarWidth);

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

  PositionBoardClockLabels(FBoardTopClockLabel, FBoardBottomClockLabel,
    FBoardRect, OffsetX, OffsetY);
end;

function TMainWindow.CreateEngineLogPanel(AParent: TWinControl; AAlign: TAlign;
  AHeight: Integer): TPanel;
begin
  Result := TPanel.Create(AParent);
  Result.Parent := AParent;
  Result.Align := AAlign;
  if AHeight > 0 then
    Result.Height := AHeight;
  Result.BevelOuter := bvNone;
end;

procedure TMainWindow.SetupEngineSlotLogControls(AEngineIndex: Integer;
  AParentPanel: TWinControl; const AInitialText: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  FEngines[AEngineIndex].StateLabel := TLabel.Create(AParentPanel);
  FEngines[AEngineIndex].StateLabel.Parent := AParentPanel;
  FEngines[AEngineIndex].StateLabel.Align := alRight;
  FEngines[AEngineIndex].StateLabel.AutoSize := False;
  FEngines[AEngineIndex].StateLabel.Width := EngineStateLabelWidth;
  FEngines[AEngineIndex].StateLabel.BorderSpacing.Right := LayoutMargin;
  FEngines[AEngineIndex].StateLabel.BorderSpacing.Bottom := 6;
  FEngines[AEngineIndex].StateLabel.Alignment := taCenter;
  FEngines[AEngineIndex].StateLabel.Layout := tlCenter;
  FEngines[AEngineIndex].StateLabel.Font.Style := [fsBold];
  FEngines[AEngineIndex].StateLabel.Transparent := False;
  FEngines[AEngineIndex].StateLabel.Color := clBtnFace;

  FEngines[AEngineIndex].LogMemo := TMemo.Create(AParentPanel);
  FEngines[AEngineIndex].LogMemo.Parent := AParentPanel;
  FEngines[AEngineIndex].LogMemo.Align := alClient;
  FEngines[AEngineIndex].LogMemo.BorderSpacing.Left := LayoutMargin;
  FEngines[AEngineIndex].LogMemo.BorderSpacing.Right := 6;
  FEngines[AEngineIndex].LogMemo.BorderSpacing.Bottom := 6;
  FEngines[AEngineIndex].LogMemo.ReadOnly := True;
  FEngines[AEngineIndex].LogMemo.ScrollBars := ssBoth;
  FEngines[AEngineIndex].LogMemo.WordWrap := False;
  FEngines[AEngineIndex].LogMemo.TabStop := False;

  SetupEngineSlotLogPopupMenu(AEngineIndex);
  FEngines[AEngineIndex].LogMemo.Lines.Add(AInitialText);
end;

procedure TMainWindow.SetupEngineSlotLogPopupMenu(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  SetupEngineLogPopupMenu(Self, FEngines[AEngineIndex], @EnginePopupMenuPopup,
    @OpenEngineMenuItemClick, @EditEngineParamsMenuItemClick,
    @CloseEngineMenuItemClick, @AnalyzeMenuItemClick,
    @ShowTimestampsMenuItemClick, @SaveEngineLogMenuItemClick,
    FEngineAnalyzeEnabled, FEngineLogShowTimestamps);
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

  Engine1Panel := CreateEngineLogPanel(FEnginePanel, alClient);

  SetupEngineSlotLogControls(1, Engine1Panel, 'Engine output');

  EngineLogSplitter := TSplitter.Create(FEnginePanel);
  EngineLogSplitter.Parent := FEnginePanel;
  EngineLogSplitter.Align := alBottom;
  EngineLogSplitter.ResizeAnchor := akBottom;
  EngineLogSplitter.Height := 4;

  Engine2Panel := CreateEngineLogPanel(FEnginePanel, alBottom,
    (FEnginePanel.Height - EngineLogSplitter.Height) div 2);

  SetupEngineSlotLogControls(2, Engine2Panel, 'Engine 2 output');
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
  FEngineOpenDialog.Filter := EngineExecutableFilter;
  FEngineOpenDialog.DefaultExt := EngineExecutableDefaultExt;
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
  DisplayCol: Integer;
  DisplayRow: Integer;
  InvalidateArea: TRect;
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

  if not BoardCellForSquare(ASquare, FBoardFlipped, DisplayRow, DisplayCol) then
    Exit;

  InvalidateArea := BoardCellRect(FBoardRect, DisplayRow, DisplayCol);
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
  NewPixels: Integer;
  PaintCanvas: TCanvas;
begin
  if (FBoardPaintBox = nil) or (FEvalBarRect.Right <= FEvalBarRect.Left) or
    (FEvalBarRect.Bottom <= FEvalBarRect.Top) then
  begin
    InvalidateEngineEvalBar;
    Exit;
  end;

  PaintCanvas := FBoardPaintBox.Canvas;
  EvalBarUi.RepaintEvalBarDelta(PaintCanvas, FEvalBarRect, AOldScore,
    ANewScore, EngineEvaluationBarMax(1), FBoardFlipped, NewPixels);
  if NewPixels >= 0 then
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
begin
  if FHistoryEvalPaintBox = nil then
    Exit;

  DrawScoreHistoryGraph(FHistoryEvalPaintBox.Canvas,
    FHistoryEvalPaintBox.ClientRect, Length(FHistory.Moves),
    FHistory.CurrentPly, EngineEvaluationBarMax(1),
    @HistoryAnnotationScoreWhite);
end;

procedure TMainWindow.HistoryPvMiniBoardPaintBoxPaint(Sender: TObject);
begin
  if FHistoryPvMiniBoardPaintBox <> nil then
    DrawAnalysisMiniBoard(FHistoryPvMiniBoardPaintBox.Canvas,
      FHistoryPvMiniBoardPaintBox.ClientRect, FAnalyzePvBrowseBoard,
      FAnalyzePvHasBase, FBoardFlipped, Color, WoodSquareColor);
end;

procedure TMainWindow.AnalysisBoardPaintBoxPaint(Sender: TObject);
begin
  if FAnalysisBoardPaintBox <> nil then
    DrawAnalysisMiniBoard(FAnalysisBoardPaintBox.Canvas,
      FAnalysisBoardPaintBox.ClientRect, FAnalyzePvBrowseBoard,
      FAnalyzePvHasBase, FBoardFlipped, Color, WoodSquareColor);
end;

procedure TMainWindow.AnalysisBoardFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  FAnalysisBoardPaintBox := nil;
  FAnalysisBoardForm := nil;
  CloseAction := caFree;
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

  CellSize := BoardCellSize(FBoardRect);
  DrawBoardSideToMoveMarker(ACanvas, FBoardRect, CellSize);
  DrawEngineEvalBar(ACanvas, FBoardRect);

  for Row := 0 to BoardSize - 1 do
    for Col := 0 to BoardSize - 1 do
    begin
      if Odd(Row + Col) then
        SquareColor := WoodSquareColor
      else
        SquareColor := clWhite;

      SquareRect := BoardCellRect(FBoardRect, Row, Col);
      ACanvas.Brush.Color := SquareColor;
      ACanvas.FillRect(SquareRect);

      if Odd(Row + Col) then
      begin
        PiecePosition := BoardGeometry.BoardSquareAtCell(Row, Col, FBoardFlipped);
        if PiecePosition = FSelectedSquare then
          DrawSquareOutline(ACanvas, SquareRect, clYellow,
            Max(2, CellSize div 16), 0)
        else if FTargetSquares[PiecePosition] then
        begin
          if FAmbiguousTargetSquares[PiecePosition] then
            DrawTargetCircle(ACanvas, SquareRect, clRed,
              Max(2, CellSize div 18), CellSize div 4)
          else
            DrawTargetCircle(ACanvas, SquareRect, clLime,
              Max(2, CellSize div 18), CellSize div 4);
        end;
      end;

      if Odd(Row + Col) then
      begin
        PiecePosition := BoardGeometry.BoardSquareAtCell(Row, Col, FBoardFlipped);
        DrawPiece(ACanvas, SquareRect, FBoard[PiecePosition], CellSize, SquareColor);
        if PiecePosition = FOnlyMoveSourceSquare then
          DrawSquareOutline(ACanvas, SquareRect, clBlue,
            Max(3, CellSize div 12), 2);
        if PiecePosition = FAnalyzeBestSourceSquare then
          DrawSquareOutline(ACanvas, SquareRect, AnalyzeBestSourceColor,
            Max(3, CellSize div 12), CellSize div 10);
        if PiecePosition = FAnalyzeHintSourceSquare then
          DrawSquareOutline(ACanvas, SquareRect, AnalyzeHintSourceColor,
            Max(3, CellSize div 12), CellSize div 7);
        if PiecePosition = FLastMoveTargetSquare then
          DrawSquareOutline(ACanvas, SquareRect, clYellow,
            Max(3, CellSize div 12), 2);
      end;
    end;

  ACanvas.Pen.Color := clBlack;
  ACanvas.Pen.Width := 2;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Rectangle(FBoardRect);
  ACanvas.Brush.Style := bsSolid;
end;

procedure TMainWindow.DrawEngineEvalBar(ACanvas: TCanvas; const ABoardRect: TRect);
begin
  if (ABoardRect.Right <= ABoardRect.Left) or
    (ABoardRect.Bottom <= ABoardRect.Top) then
    Exit;

  FEvalBarRect := EvalBarRectForBoard(ABoardRect, EvalBarGap, EvalBarWidth);
  DrawEvalBar(ACanvas, FEvalBarRect, FEngineEvalScoreWhite,
    EngineEvaluationBarMax(1), FBoardFlipped, FLastEvalBarWhitePixels);
end;

procedure TMainWindow.DrawBoardSideToMoveMarker(ACanvas: TCanvas;
  const ABoardRect: TRect; ACellSize: Integer);
var
  MarkerPiece: TPiece;
  MarkerRect: TRect;
begin
  MarkerRect := BoardSideToMoveMarkerRect(ABoardRect, ACellSize,
    BoardSideMarkerGap, BoardSideMarkerWidth, FSideToMove, FBoardFlipped,
    MarkerPiece);
  DrawPiece(ACanvas, MarkerRect, MarkerPiece, ACellSize, Color);
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

procedure TMainWindow.ResetHistoryFromCurrentPosition;
begin
  FLastMoveTargetSquare := 0;
  FHistory.ResetFromPosition(FBoard, FSideToMove);
end;

procedure TMainWindow.MarkGameDirty;
begin
  FGameDirty := True;
end;

procedure TMainWindow.RecordPlayedMove(const AMove: TMove; const AAnnotation: String);
var
  Snapshot: TClockSnapshot;
begin
  if FPlayClock <> nil then
    Snapshot := FPlayClock.Snapshot(FPlayGameActive)
  else
    Snapshot.HasClock := False;
  FHistory.AddMove(AMove, AAnnotation, Snapshot);
  MarkGameDirty;
  if not FSuppressBoardUpdates then
    UpdateHistoryList;
end;

procedure TMainWindow.LogPlayedMoveToEngineWindows(const AMove: TMove;
  AActorEngineIndex: Integer);
var
  ActorName: String;
  MoverSide: TSide;
  MoveText: String;
  TimeUsedSeconds: Integer;
begin
  MoveText := MoveToString(AMove);
  TimeUsedSeconds := 0;
  if FPlayGameActive and (FPlayClock <> nil) then
  begin
    if FSideToMove = sideWhite then
      MoverSide := sideBlack
    else
      MoverSide := sideWhite;
    TimeUsedSeconds := Trunc(FPlayClock.SecondsUsedForSide(MoverSide));
  end;
  case AActorEngineIndex of
    1: ActorName := FEngines[1].DisplayName;
    2: ActorName := FEngines[2].DisplayName;
  else
    ActorName := 'Human';
  end;

  if (AActorEngineIndex <> 1) and EngineIsRunning then
  begin
    AppendEngineSlotLog(1, '[' + ActorName + ' played ' + MoveText + ']' +
      LineEnding);
    if FPlayGameActive and EngineIsDxp(1) and
      (((FPlayGameWhiteIsEngine and (FPlayGameWhiteEngineIndex = 1)) or
      (FPlayGameBlackIsEngine and (FPlayGameBlackEngineIndex = 1)))) then
      SendDxpMoveToEngine(1, AMove, TimeUsedSeconds);
  end;
  if (AActorEngineIndex <> 2) and SecondEngineIsRunning then
  begin
    AppendEngineSlotLog(2, '[' + ActorName + ' played ' + MoveText + ']' +
      LineEnding);
    if FPlayGameActive and EngineIsDxp(2) and
      (((FPlayGameWhiteIsEngine and (FPlayGameWhiteEngineIndex = 2)) or
      (FPlayGameBlackIsEngine and (FPlayGameBlackEngineIndex = 2)))) then
      SendDxpMoveToEngine(2, AMove, TimeUsedSeconds);
  end;
end;

function TMainWindow.CurrentPositionRepetitionCount: Integer;
begin
  Result := FHistory.RepetitionCountForPosition(FBoard, FSideToMove);
end;

function TMainWindow.CheckDrawByRepetition: Boolean;
begin
  Result := False;
  if (not FPlayGameActive) and (not FAutoPlayActive) then
    Exit;
  if CurrentPositionRepetitionCount < 3 then
    Exit;

  Result := True;
  EndCurrentGame(gerRepetition, '1-1');
  SendStopToAllEngines;
end;

function TMainWindow.CheckDrawByTwentyFiveMoveRule: Boolean;
const
  TwentyFiveMovesInPlies = 50;
begin
  Result := False;
  if (not FPlayGameActive) and (not FAutoPlayActive) then
    Exit;
  if FHistory.ConsecutiveReversiblePlyCount < TwentyFiveMovesInPlies then
    Exit;

  Result := True;
  EndCurrentGame(gerTwentyFiveMoveRule, '1-1');
  SendStopToAllEngines;
end;

procedure TMainWindow.AppendEngineSlotLogOrMain(AEngineIndex: Integer;
  const AText: String);
begin
  if EngineSlotIndexValid(AEngineIndex) then
    AppendEngineSlotLog(AEngineIndex, AText)
  else
    AppendEngineSlotLog(1, AText);
end;

procedure TMainWindow.LogGameEventToRelevantEngines(const AText: String;
  AOriginEngineIndex: Integer);
begin
  if AText = '' then
    Exit;

  if AOriginEngineIndex = 2 then
    AppendEngineSlotLog(2, AText + LineEnding)
  else if AOriginEngineIndex = 1 then
    AppendEngineSlotLog(1, AText + LineEnding)
  else
  begin
    AppendEngineSlotLog(1, AText + LineEnding);
    if SecondEngineIsRunning then
      AppendEngineSlotLog(2, AText + LineEnding);
  end;
end;

procedure TMainWindow.EndCurrentGame(AReason: TGameEndReason;
  const AResult: String; AOriginEngineIndex: Integer;
  ARestartAnalyze: Boolean);
var
  GuiReason: String;
  LogText: String;
  ResultText: String;
begin
  ResultText := GameEndResultForReason(AReason, AResult, FSideToMove);
  if ResultText <> '' then
    FGameResult := ResultText;
  FGameResultReason := GameEndTournamentReasonText(AReason, FSideToMove,
    ResultText);
  GameEndReasonDetails(AReason, FSideToMove, GuiReason, LogText);
  SetGuiState(gsGameOver, GuiReason);

  FAutoPlayActive := False;
  StopGameClocks;
  MarkGameDirty;
  NotifyDxpPlayGameEnd(AOriginEngineIndex);
  FinishPlayGameMode(True, ARestartAnalyze);
  LogGameEventToRelevantEngines(LogText, AOriginEngineIndex);
end;

procedure TMainWindow.StopModeBecause(AEngineIndex: Integer;
  AMode: TStoppedMode; const AReason: String);
var
  LogText: String;
begin
  case AMode of
    smAutoPlay:
      begin
        FAutoPlayActive := False;
        SetGuiState(gsIdle, 'auto-play ' + AReason);
      end;
    smPlayGame:
      LeavePlayGameMode;
  end;

  LogText := '[' + StoppedModeText(AMode) + ' stopped: ' + AReason + ']' +
    LineEnding;
  AppendEngineSlotLogOrMain(AEngineIndex, LogText);
end;

procedure TMainWindow.StopAutoPlayBecause(AEngineIndex: Integer;
  const AReason: String);
begin
  StopModeBecause(AEngineIndex, smAutoPlay, AReason);
end;

procedure TMainWindow.StopPlayGameBecause(AEngineIndex: Integer;
  const AReason: String);
begin
  StopModeBecause(AEngineIndex, smPlayGame, AReason);
end;

procedure TMainWindow.EndGameIfTerminalPosition;
begin
  if Length(FMoves) <> 0 then
    Exit;

  EndCurrentGame(gerTerminalPosition);
end;

procedure TMainWindow.RebuildPositionToPly(APly: Integer);
begin
  if APly > Length(FHistory.Moves) then
    APly := Length(FHistory.Moves);
  if APly < 0 then
    APly := 0;

  FHistory.PositionAtPly(APly, FBoard, FSideToMove, FLastMoveTargetSquare);
  FHistory.CurrentPly := APly;
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
  Ply: Integer;
begin
  if FHistoryMemo = nil then
    Exit;

  Caret := FHistoryMemo.SelStart;
  Ply := FHistory.PlyAtTextOffset(Caret);

  if (Ply > 0) and (Ply <= Length(FHistory.Moves)) then
    NavigateHistoryToPly(Ply)
  else
    SelectHistoryPly(FHistory.CurrentPly);
end;

procedure TMainWindow.HistoryMemoKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  case Key of
    VK_RIGHT:
    begin
      NavigateHistoryToPly(Min(FHistory.CurrentPly + 1, Length(FHistory.Moves)));
      Key := 0;
    end;
    VK_LEFT:
    begin
      NavigateHistoryToPly(Max(FHistory.CurrentPly - 1, 0));
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

procedure TMainWindow.AnalyzePvEngineComboChange(Sender: TObject);
var
  Mode: TEngineSearchMode;
begin
  if FPvEngineCombo = nil then
    Exit;

  if FPvEngineCombo.ItemIndex = 1 then
    FSelectedPvEngineIndex := 2
  else
    FSelectedPvEngineIndex := 1;

  SetAnalyzePvLocked(False);
  ShowAnalyzePvFromEngine(FSelectedPvEngineIndex);

  if (not FEngineAnalyzeEnabled) or FAutoPlayActive then
    Exit;
  if FPlayGameActive and IsPlayGameEngineTurn then
    Exit;

  if FPlayGameActive and HasPlayGameEnginePlayer and HasPlayGameHumanPlayer then
    Mode := esmPlayGameAnalyze
  else
    Mode := esmAnalyze;

  RequestOrSendAnalyzeToEngineSlot(FSelectedPvEngineIndex, Mode,
    'stopping previous search before selected PV analysis');
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

  if (APly <= High(FHistory.MoveStarts)) and (FHistory.MoveLengths[APly] > 0) then
  begin
    FHistoryMemo.SelStart := FHistory.MoveStarts[APly];
    FHistoryMemo.SelLength := FHistory.MoveLengths[APly];
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
    AppendEngineSlotLog(1, '[PV locked]' + LineEnding)
  else
    AppendEngineSlotLog(1, '[PV unlocked]' + LineEnding);
end;

procedure TMainWindow.UnlockAnalyzePv;
begin
  if not FAnalyzePvLocked then
    Exit;

  SetAnalyzePvLocked(False);
  ShowAnalyzePvFromEngine(FSelectedPvEngineIndex);
end;

procedure TMainWindow.ClearAnalyzeBoardHighlights;
begin
  if (FAnalyzeBestSourceSquare <> 0) or (FAnalyzeHintSourceSquare <> 0) then
  begin
    FAnalyzeBestSourceSquare := 0;
    FAnalyzeHintSourceSquare := 0;
    InvalidateBoard;
  end;
end;

procedure TMainWindow.ClearAnalyzePvForEngine(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  FEngines[AEngineIndex].AnalyzePvText := '';
  FEngines[AEngineIndex].AnalyzePvBasePly := 0;
  FEngines[AEngineIndex].AnalyzePvHasBase := False;
end;

procedure TMainWindow.ClearAnalyzePvForAllEngines;
var
  I: Integer;
begin
  for I := Low(FEngines) to High(FEngines) do
    ClearAnalyzePvForEngine(I);
end;

procedure TMainWindow.ClearSearchAnalysisDisplay;
begin
  FLastEngineInfoAnnotation := '';
  FLastEngineInfoLine := '';
  ClearAnalyzePvForAllEngines;
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
end;

procedure TMainWindow.HandleTerminalSearchPosition(AEngineIndex: Integer;
  AStopAutoPlay, ALeavePlayGame: Boolean);
var
  LogText: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  if ALeavePlayGame and FPlayGameActive then
    LeavePlayGameMode;
  if AStopAutoPlay then
    FAutoPlayActive := False;

  FinishEngineSlotSearch(AEngineIndex);
  LogText := '[' + EngineLogName(AEngineIndex) +
    ' not starting search: terminal position]' + LineEnding;
  AppendEngineSlotLog(AEngineIndex, LogText);
end;

function TMainWindow.SquareAtPoint(X, Y: Integer): Integer;
begin
  Result := BoardGeometry.BoardSquareAtPoint(FBoardRect, X, Y, FBoardFlipped);
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

  CopyMove(FMoves[AMoveIndex], PlayedMove);
  ClearBoardSelection;

  if FPlayGameActive and (not IsPlayGameHumanTurn) then
  begin
    AppendEngineSlotLog(1, '[not your turn]' + LineEnding);
    Exit;
  end;

  if FPlayGameActive then
    PauseGameClocks;

  ApplyMove(PlayedMove);
  RecordPlayedMove(PlayedMove);
  LogPlayedMoveToEngineWindows(PlayedMove, 0);

  if FPlayGameActive then
  begin
    AppendEngineSlotLog(1, '[human move ' + MoveToString(PlayedMove) + ']' +
      LineEnding);
    ContinueGameFlowAfterPositionChange(gfrHumanMove, 0);
  end
  else if AContinueEngine and EngineIsRunning and
    FEngines[1].Ready then
  begin
    AppendEngineSlotLog(1, '[played move ' + MoveToString(PlayedMove) +
      '; restarting analysis]' + LineEnding);
    RestartEngineAnalyze;
  end;
end;

procedure TMainWindow.AppendEngineSlotLog(AEngineIndex: Integer;
  const AText: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    AEngineIndex := 1;
  AppendEngineGuiLog(FEngines[AEngineIndex].LogMemo, AText,
    FEngineLogShowTimestamps);
end;

procedure TMainWindow.AppendEngineSlotRawLog(AEngineIndex: Integer;
  const AText: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    AEngineIndex := 1;
  AppendEngineRawLog(FEngines[AEngineIndex].LogMemo, AText);
end;

function TMainWindow.EngineIsRunning: Boolean;
begin
  Result := EngineSlotIndexValid(1) and
    (FEngines[1].PlatformProcess <> nil) and
    FEngines[1].PlatformProcess.IsRunning;
end;

function TMainWindow.EngineOutputLogText(const AText: String;
  AEngineIndex: Integer): String;
begin
  Result := FormatEngineOutputLog(AText, EngineLogName(AEngineIndex),
    FEngineLogShowTimestamps);
end;

function TMainWindow.SecondEngineIsRunning: Boolean;
begin
  Result := EngineSlotIndexValid(2) and
    (FEngines[2].PlatformProcess <> nil) and
    FEngines[2].PlatformProcess.IsRunning;
end;

function TMainWindow.EngineSlotIsRunning(AEngineIndex: Integer): Boolean;
begin
  case AEngineIndex of
    1: Result := EngineIsRunning;
    2: Result := SecondEngineIsRunning;
  else
    Result := False;
  end;
end;

function TMainWindow.EngineSlotIndexValid(AEngineIndex: Integer): Boolean;
begin
  Result := (AEngineIndex >= Low(FEngines)) and
    (AEngineIndex <= High(FEngines));
end;

function TMainWindow.EngineSlotConfigured(AEngineIndex: Integer): Boolean;
begin
  Result := False;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  Result := (FEngines[AEngineIndex].FileName <> '') or
    (FEngines[AEngineIndex].ParamsFileName <> '') or
    FEngines[AEngineIndex].Ready or EngineSlotProcessHandlePresent(AEngineIndex) or
    (FEngines[AEngineIndex].DxpSocket <> nil);
end;

function TMainWindow.EngineSlotDxpSocketOpen(AEngineIndex: Integer): Boolean;
begin
  Result := False;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  Result := FEngines[AEngineIndex].DxpSocket <> nil;
  if not Result then
    Exit;

  if EngineSlotProcessHandlePresent(AEngineIndex) and
    (not EngineSlotIsRunning(AEngineIndex)) then
  begin
    CloseDxpSocket(AEngineIndex, 'engine process is not running');
    Result := False;
  end;
end;

function TMainWindow.EngineSlotDxpConnectionActive(
  AEngineIndex: Integer): Boolean;
begin
  Result := EngineSlotIndexValid(AEngineIndex) and
    ((FEngines[AEngineIndex].DxpThread <> nil) or
     EngineSlotDxpSocketOpen(AEngineIndex));
end;

procedure TMainWindow.CloseDxpSocket(AEngineIndex: Integer;
  const AReason: String);
var
  LogText: String;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  if FEngines[AEngineIndex].DxpSocket = nil then
    Exit;

  if AReason <> '' then
  begin
    LogText := '[DXP socket closed: ' + AReason + ']' + LineEnding;
    AppendEngineSlotLog(AEngineIndex, LogText);
  end;

  FreeAndNil(FEngines[AEngineIndex].DxpSocket);
  SetDxpGameState(AEngineIndex, dgsIdle, 'DXP socket closed');
end;

function TMainWindow.EngineSlotCanReceiveCommand(AEngineIndex: Integer;
  ARequireReady: Boolean): TEngineCommandGate;
var
  EngineReady: Boolean;
  SlotValid: Boolean;
begin
  SlotValid := EngineSlotIndexValid(AEngineIndex);
  EngineReady := SlotValid and FEngines[AEngineIndex].Ready;
  Result := EngineReceiveCommandGate(EngineLogName(AEngineIndex), SlotValid,
    EngineSlotIsRunning(AEngineIndex), ARequireReady, EngineReady);
end;

function TMainWindow.EngineSlotCanStartHubSearch(AEngineIndex: Integer;
  const AGoCommand: String; ARequireMctsSupport: Boolean): TEngineCommandGate;
begin
  Result := HubSearchGate(EngineSlotCanReceiveCommand(AEngineIndex, True),
    AGoCommand, EngineLogName(AEngineIndex), EngineIsDxp(AEngineIndex),
    ARequireMctsSupport, EngineSupportsMcts(AEngineIndex));
end;

function TMainWindow.EngineSlotCanSendDxpPacket(AEngineIndex: Integer;
  const APacketName: String; ACheckGameEndSent: Boolean): TEngineCommandGate;
var
  GameEndAlreadySent: Boolean;
  SlotValid: Boolean;
begin
  SlotValid := EngineSlotIndexValid(AEngineIndex);
  GameEndAlreadySent := SlotValid and FEngines[AEngineIndex].DxpGameEndSent;
  Result := DxpPacketGate(APacketName, SlotValid, EngineIsDxp(AEngineIndex),
    ACheckGameEndSent, GameEndAlreadySent,
    EngineSlotDxpSocketOpen(AEngineIndex));
end;

function TMainWindow.EngineSlotCanSendDxpGameEnd(
  AEngineIndex: Integer): TEngineCommandGate;
begin
  Result := EngineSlotCanSendDxpPacket(AEngineIndex, 'DXP_GAMEEND', True);
end;

function TMainWindow.LogEngineGateFailure(AEngineIndex: Integer;
  const AGate: TEngineCommandGate): Boolean;
begin
  Result := not AGate.Allowed;
  if Result and (AGate.Reason <> '') and EngineSlotIndexValid(AEngineIndex) then
    AppendEngineSlotLog(AEngineIndex, AGate.Reason);
end;

function TMainWindow.EngineSlotAvailableForPlay(AEngineIndex: Integer): Boolean;
begin
  Result := False;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if EngineIsDxp(AEngineIndex) then
  begin
    Result := EngineSlotDxpSocketOpen(AEngineIndex);
    Exit;
  end;

  Result := EngineSlotIsRunning(AEngineIndex);
  if not Result then
    Exit;
  Result := FEngines[AEngineIndex].Ready;
end;

procedure TMainWindow.UpdateEnginePollTimer;
var
  HasEngineProcess: Boolean;
  I: Integer;
begin
  if FEnginePollTimer = nil then
    Exit;

  HasEngineProcess := False;
  for I := Low(FEngines) to High(FEngines) do
    if (FEngines[I] <> nil) and
      (FEngines[I].PlatformProcess <> nil) and
      FEngines[I].PlatformProcess.HasProcess and
      FEngines[I].PlatformProcess.NeedsPolling then
    begin
      HasEngineProcess := True;
      Break;
    end;

  FEnginePollTimer.Enabled := HasEngineProcess;
end;

function TMainWindow.EngineParamsFileNameForDisplayName(
  const ADisplayName: String; const AEngineFileName: String): String;
var
  DefaultDirectory: String;
begin
  if FEngines[1].FileName <> '' then
    DefaultDirectory := ExtractFilePath(FEngines[1].FileName)
  else
    DefaultDirectory := ExtractFilePath(ParamStr(0));
  Result := EngineConfigParamsFileName(ADisplayName, AEngineFileName,
    DefaultDirectory);
end;

function TMainWindow.EngineCanonicalParamsFileName(
  const AEngineFileName: String): String;
begin
  Result := EngineParamsFileNameForDisplayName('', AEngineFileName);
end;

procedure TMainWindow.LoadEngineParamsForProtocol(AEngineIndex: Integer;
  const AEngineFileName, AProtocol: String);
var
  SectionName: String;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  FEngines[AEngineIndex].ParamsFileName :=
    EngineCanonicalParamsFileName(AEngineFileName);

  SectionName := LowerCase(Trim(AProtocol));
  if (SectionName = 'hub') or (SectionName = 'dxp') then
    LoadParamsFromJson(FEngines[AEngineIndex].ParamsFileName, SectionName,
      FEngines[AEngineIndex].Params)
  else
    LoadParamsFromJson(FEngines[AEngineIndex].ParamsFileName,
      FEngines[AEngineIndex].Params);

  if (SectionName = 'hub') or (SectionName = 'dxp') then
    AddOrUpdateParam(FEngines[AEngineIndex].Params, EngineTypeParamName,
      'string', SectionName, False);
end;

procedure TMainWindow.ClockTimerTimer(Sender: TObject);
begin
  UpdateGameClock;
end;

procedure TMainWindow.ApplicationIdle(Sender: TObject; var Done: Boolean);
begin
  if (FPlayClock <> nil) and FPlayClock.Active then
  begin
    if FPlayClock.NeedsIdleUpdate then
      UpdateGameClock;
    Done := False;
  end;
end;

procedure TMainWindow.HandleClockExpired;
begin
  EndCurrentGame(gerClockExpired, '', 0, True);
end;

procedure TMainWindow.UpdateGameClock;
begin
  if (FPlayClock = nil) or (not FPlayClock.Active) then
    Exit;

  if FPlayClock.Update(FSideToMove) then
    HandleClockExpired;

  UpdateClockLabels;
end;

procedure TMainWindow.ResetClocks;
begin
  if FPlayClock <> nil then
    FPlayClock.Reset;
  StopGameClocks;
end;

procedure TMainWindow.StartGameClocks(AGameMinutes: Double);
begin
  if FPlayClock <> nil then
    FPlayClock.Start(AGameMinutes);
  UpdateClockLabels;
end;

procedure TMainWindow.ActivateGameClocks;
begin
  if not FPlayGameActive then
    Exit;

  if FPlayClock <> nil then
    FPlayClock.Activate;
  UpdateClockLabels;
end;

procedure TMainWindow.PauseGameClocks;
begin
  if FPlayClock <> nil then
    FPlayClock.Pause(FSideToMove);
  UpdateClockLabels;
end;

procedure TMainWindow.PauseGameClocksAt(AReceivedAtSeconds: Double);
begin
  if (AReceivedAtSeconds <= 0) or (FPlayClock = nil) then
  begin
    PauseGameClocks;
    Exit;
  end;

  if FPlayClock.Active then
    FPlayClock.PauseAt(FSideToMove, AReceivedAtSeconds)
  else
    FPlayClock.Pause(FSideToMove);
  UpdateClockLabels;
end;

procedure TMainWindow.StopGameClocks;
begin
  if FPlayClock <> nil then
    FPlayClock.Stop;
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

procedure TMainWindow.FinishPlayGameMode(AUpdateHistory: Boolean;
  ARestartAnalyze: Boolean);
begin
  LeavePlayGameMode;
  if AUpdateHistory then
    UpdateHistoryList;
  if ARestartAnalyze then
    RestartEngineAnalyze;
end;

procedure TMainWindow.RestoreClockSnapshot(APly: Integer);
begin
  if APly <= 0 then
    FPlayClock.RestoreInitial
  else if (APly <= Length(FHistory.ClockSnapshots)) and
    FHistory.ClockSnapshots[APly - 1].HasClock then
    FPlayClock.RestoreSnapshot(FHistory.ClockSnapshots[APly - 1])
  else
    Exit;

  if FPlayGameActive then
    FPlayClock.Activate
  else
    FPlayClock.Stop;
  UpdateClockLabels;
  AppendEngineSlotLog(1, ClockRestoreLogText(FPlayClock.WhiteSeconds,
    FPlayClock.BlackSeconds));
end;

procedure TMainWindow.UpdateClockLabels;
  function ClockPlayerName(const AName, AFallback: String): String;
  begin
    Result := Trim(AName);
    if Result = '' then
      Result := AFallback;
  end;

var
  BlackClockName: String;
  WhiteClockName: String;
begin
  if FPlayClock = nil then
    Exit;

  WhiteClockName := ClockPlayerName(FGameWhiteName, 'White');
  BlackClockName := ClockPlayerName(FGameBlackName, 'Black');

  if FBoardFlipped then
  begin
    ApplyClockLabel(FBoardTopClockLabel, WhiteClockName, FPlayClock.WhiteSeconds,
      FPlayClock.Active);
    ApplyClockLabel(FBoardBottomClockLabel, BlackClockName, FPlayClock.BlackSeconds,
      FPlayClock.Active);
  end
  else
  begin
    ApplyClockLabel(FBoardTopClockLabel, BlackClockName, FPlayClock.BlackSeconds,
      FPlayClock.Active);
    ApplyClockLabel(FBoardBottomClockLabel, WhiteClockName, FPlayClock.WhiteSeconds,
      FPlayClock.Active);
  end;
end;

procedure TMainWindow.CloseEngine;
begin
  CloseEngineSlot(1);
end;

procedure TMainWindow.CloseEngineSlot(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  CloseEngineSlotProcess(AEngineIndex);
  ResetEngineSlotAfterClose(AEngineIndex);
  RefreshEngineUiAfterSlotChange;
end;

procedure TMainWindow.ResetEngineSlotAfterClose(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  ResetEngineRuntimeForClose(AEngineIndex);
end;

procedure TMainWindow.ResetEngineRuntimeForLaunch(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  ResetEngineSlotRuntime(AEngineIndex);
end;

procedure TMainWindow.ResetEngineRuntimeForClose(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if AEngineIndex = 1 then
    ResetPrimaryEngineAfterClose
  else
    ResetSecondaryEngineAfterClose;
end;

procedure TMainWindow.ResetEngineRuntimeAfterProcessExit(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  FEngines[AEngineIndex].Ready := False;
  if AEngineIndex = 1 then
  begin
    FAutoPlayActive := False;
    ClearEngineSlotPendingAction(1);
    LeavePlayGameMode;
  end
  else
    ClearEngineSlotPendingAction(AEngineIndex);

  FinishEngineSlotSearch(AEngineIndex);
end;

procedure TMainWindow.ResetPrimaryEngineAfterClose;
begin
  FAutoPlayActive := False;
  FAutoPlayPlyCount := 0;
  FEngineEvalScoreWhite := 0.0;
  FPendingPlayGameWhiteIsEngine := False;
  FPendingPlayGameBlackIsEngine := False;
  LeavePlayGameMode;
  ResetEngineSlotRuntime(1);
  ClearEngineSlotPendingAction(2);
end;

procedure TMainWindow.ResetSecondaryEngineAfterClose;
begin
  ResetEngineSlotRuntime(2);
end;

procedure TMainWindow.RefreshEngineUiAfterSlotChange;
begin
  UpdateEnginePollTimer;
  UpdateEngineCommandButtons;
  UpdateEnginePopupMenuItems;
  UpdateEngineStateLabels;
end;

procedure TMainWindow.CloseEngineSlotProcess(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if FEnginePollTimer <> nil then
    FEnginePollTimer.Enabled := False;
  StopDxpConnection(AEngineIndex);
  RequestEngineSlotProcessExit(AEngineIndex);
  TerminateEngineSlotProcessIfRunning(AEngineIndex);
  CloseEngineSlotProcessHandles(AEngineIndex);
end;

procedure TMainWindow.RequestEngineSlotProcessExit(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if (FEngines[AEngineIndex].PlatformProcess <> nil) and
    FEngines[AEngineIndex].PlatformProcess.IsRunning and
    (not EngineIsDxp(AEngineIndex)) then
  begin
    LogEngineSlotCommandSent(AEngineIndex, 'quit');
    FEngines[AEngineIndex].PlatformProcess.RequestQuit('quit', 1000);
  end;
end;

procedure TMainWindow.TerminateEngineSlotProcessIfRunning(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if FEngines[AEngineIndex].PlatformProcess <> nil then
    FEngines[AEngineIndex].PlatformProcess.Terminate(1000);
end;

procedure TMainWindow.CloseEngineSlotProcessHandles(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if FEngines[AEngineIndex].PlatformProcess <> nil then
    FEngines[AEngineIndex].PlatformProcess.Close;
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

  CloseEngineSlot(2);

  if FirstEngineWasRunning and (FirstEngineFileName <> '') and
    (not EngineIsRunning) then
  begin
    AppendEngineSlotLog(1, '[engine 1 stopped while closing engine 2; restarting]' +
      LineEnding);
    StartEngine(FirstEngineFileName, True);
  end;
end;

function TMainWindow.EngineSlotIndexFromSender(Sender: TObject): Integer;
begin
  Result := 1;
  if Sender = FEngines[2].OpenMenuItem then
    Exit(2);
  if Sender = FEngines[2].ParamsMenuItem then
    Exit(2);
  if Sender = FEngines[2].CloseMenuItem then
    Exit(2);
  if Sender = FEngines[2].SaveLogMenuItem then
    Exit(2);
  if Sender = FEngines[1].OpenMenuItem then
    Exit(1);
  if Sender = FEngines[1].ParamsMenuItem then
    Exit(1);
  if Sender = FEngines[1].CloseMenuItem then
    Exit(1);
  if Sender = FEngines[1].SaveLogMenuItem then
    Exit(1);
  if Sender is TComponent then
    Result := TComponent(Sender).Tag;
  if not EngineSlotIndexValid(Result) then
    Result := 1;
end;

procedure TMainWindow.CloseEngineMenuItemClick(Sender: TObject);
var
  EngineIndex: Integer;
begin
  EngineIndex := EngineSlotIndexFromSender(Sender);
  if EngineIndex = 1 then
  begin
    if SecondEngineIsRunning then
    begin
      AppendEngineSlotLog(1, '[please close engine 2 first]' + LineEnding);
      Exit;
    end;

    CloseEngine;
    AppendEngineSlotLog(1, '[' + EngineLogName(1) + ' closed]' + LineEnding);
    Exit;
  end;

  CloseSecondEngine;
  AppendEngineSlotLog(2, '[' + EngineLogName(2) + ' closed]' + LineEnding);
end;

procedure TMainWindow.CenterMainWindowOnScreen;
var
  WorkArea: TRect;
begin
  Position := poDesigned;
  WorkArea := Monitor.WorkareaRect;
  Left := WorkArea.Left + ((WorkArea.Right - WorkArea.Left - Width) div 2);
  Top := WorkArea.Top + ((WorkArea.Bottom - WorkArea.Top - Height) div 2);

  if Left < WorkArea.Left then
    Left := WorkArea.Left;
  if Top < WorkArea.Top then
    Top := WorkArea.Top;
  if Left + Width > WorkArea.Right then
    Left := Max(WorkArea.Left, WorkArea.Right - Width);
  if Top + Height > WorkArea.Bottom then
    Top := Max(WorkArea.Top, WorkArea.Bottom - Height);
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
  Result := RegisteredEnginesFileNameForApplication(ParamStr(0));
end;

procedure TMainWindow.RegisterEngineExecutable(const AFileName: String);
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

  try
    AddRegisteredEngineExecutable(RegisteredEnginesFileName, AFileName,
      CurrentHubId, CurrentDxpId);
  except
    on E: Exception do
      AppendEngineSlotLog(1, '[could not update engines.json: ' + E.Message + ']' +
        LineEnding);
  end;
end;

procedure TMainWindow.UpdateRegisteredEngineId(const AFileName,
  AEngineId: String; const AProtocol: String);
begin
  if (AFileName = '') or (AEngineId = '') then
    Exit;

  try
    UpdateRegisteredEngineProtocolId(RegisteredEnginesFileName, AFileName,
      AEngineId, AProtocol);
  except
    on E: Exception do
      AppendEngineSlotLog(1, '[could not update engine id in engines.json: ' +
        E.Message + ']' + LineEnding);
  end;
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
  Engines: TRegisteredEngineArray;
  I: Integer;
  Row: Integer;

begin
  if AGrid = nil then
    Exit;

  Engines := nil;
  SetLength(Engines, AGrid.RowCount - 1);
  for I := 0 to High(Engines) do
  begin
    Row := I + 1;
    Engines[I].Executable := Trim(AGrid.Cells[0, Row]);
    Engines[I].Path := Trim(AGrid.Cells[1, Row]);
    if AGrid.ColCount > 2 then
      Engines[I].HubId := Trim(AGrid.Cells[2, Row])
    else
      Engines[I].HubId := '';
    if AGrid.ColCount > 3 then
      Engines[I].DxpId := Trim(AGrid.Cells[3, Row])
    else
      Engines[I].DxpId := '';
  end;

  NormalizeRegisteredEngineEntries(Engines);

  for I := 0 to High(Engines) do
  begin
    Row := I + 1;
    if (Engines[I].Path <> '') and (Engines[I].Path <> '(none)') then
      AGrid.Cells[0, Row] := Engines[I].Executable;
  end;
end;

procedure TMainWindow.SaveRegisteredEnginesDialog(ADialog: TCustomForm);
var
  Data: TJSONArray;
  DxpId: String;
  DxpParams: TEngineParamArray;
  Entry: TRegisteredEngine;
  Grid: TStringGrid;
  HubId: String;
  HubParams: TEngineParamArray;
  I: Integer;
  ParamsFileName: String;
begin
  if (ADialog = nil) or
    (not (ADialog.FindComponent('RegisteredEnginesGrid') is TStringGrid)) then
    Exit;

  HubParams := nil;
  DxpParams := nil;
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

        Entry.Executable := Grid.Cells[0, I];
        Entry.Path := Grid.Cells[1, I];
        Entry.HubId := HubId;
        Entry.DxpId := DxpId;
        Data.Add(RegisteredEngineToJson(Entry));

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
    SaveRegisteredEngines(RegisteredEnginesFileName, Data);
  finally
    Data.Free;
  end;
end;

procedure TMainWindow.RegisteredEnginesMenuItemClick(Sender: TObject);
var
  BottomPanel: TPanel;
  CloseButton: TButton;
  Data: TJSONArray;
  Dialog: TForm;
  Entry: TRegisteredEngine;
  Grid: TStringGrid;
  I: Integer;
  ParamsFileName: String;
  Params: TEngineParamArray;
  Row: Integer;
  SaveButton: TButton;

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
  Params := nil;
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
    Data := LoadRegisteredEngines(RegisteredEnginesFileName);
    try
      Grid.RowCount := Max(2, Data.Count + 1);
      Row := 1;
      for I := 0 to Data.Count - 1 do
        if Data.Items[I].JSONType = jtObject then
        begin
          Entry := RegisteredEngineFromJson(TJSONObject(Data.Items[I]));
          Grid.Cells[0, Row] := Entry.Executable;
          Grid.Cells[1, Row] := Entry.Path;
          Grid.Cells[2, Row] := Entry.HubId;
          Grid.Cells[3, Row] := Entry.DxpId;
          ParamsFileName := EngineParamsFileNameForDisplayName('',
            IncludeTrailingPathDelimiter(Grid.Cells[1, Row]) +
            Grid.Cells[0, Row]);
          SetLength(Params, 0);
          LoadParamsFromJson(ParamsFileName, 'hub', Params);
          if (Grid.Cells[2, Row] = '') and (Length(Params) > 0) then
          begin
            Grid.Cells[2, Row] := EngineConfigParamValue(Params,
              HubIdParamName, '');
            if (Grid.Cells[2, Row] = '') and
              (not EngineConfigParamExists(Params, HubIdParamName)) then
              Grid.Cells[2, Row] := 'Hub' + IntToStr(Row);
          end;
          SetLength(Params, 0);
          LoadParamsFromJson(ParamsFileName, 'dxp', Params);
          if (Grid.Cells[3, Row] = '') and (Length(Params) > 0) then
          begin
            Grid.Cells[3, Row] := EngineConfigParamValue(Params,
              DxpIdParamName, '');
            if (Grid.Cells[3, Row] = '') and
              (not EngineConfigParamExists(Params, DxpIdParamName)) then
              Grid.Cells[3, Row] := 'DXP' + IntToStr(Row);
          end;
          Inc(Row);
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
  EngineObject: TJSONObject;
  Dialog: TForm;
  EngineFileName: String;
  EngineList: TListBox;
  I: Integer;
  Lines: TStringList;
  OKButton: TButton;
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
    EngineList.OnDblClick := @EngineLauncherListDblClick;

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
                EngineObject := TJSONObject(TJSONArray(Data).Items[I]);
                EngineFileName := RegisteredEngineFileName(EngineObject);
                if EngineFileName = '' then
                  Continue;

                if RegisteredEngineSupportsProtocol(EngineObject, 'hub') then
                  AddRegisteredEngine(RegisteredEngineProtocolDisplayName(
                    EngineObject, I + 1, 'hub'), EngineFileName, 'hub');
                if RegisteredEngineSupportsProtocol(EngineObject, 'dxp') then
                  AddRegisteredEngine(RegisteredEngineProtocolDisplayName(
                    EngineObject, I + 1, 'dxp'), EngineFileName, 'dxp');
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
                ShowGuiOkDialog(Self, 'Open engine',
                  'Please select a registered engine, or use Browse...');
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
  IniText: String;
  IpEdit: TEdit;
  IpLabel: TLabel;
  LaunchEdit: TEdit;
  LaunchLabel: TLabel;
  OKButton: TButton;
  OtherEngineIndex: Integer;
  ProtocolGroup: TRadioGroup;
  RoleCombo: TComboBox;
  RoleLabel: TLabel;
  SaveSection: String;
  SocketEdit: TSpinEdit;
  SocketLabel: TLabel;
  DxpModeMessage: String;

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
        SameText(FEngines[I].DxpIpAddress, AIpAddress) and
        (StrToIntDef(FEngines[I].DxpSocketNumber, 0) = APort) then
      begin
        AOtherEngineIndex := I;
        Exit(True);
      end;
  end;

  function NextDefaultProtocolId(const APrefix, ASection,
    AParamName: String): String;
  var
    Data: TJSONArray;
    Entry: TRegisteredEngine;
    EngineFileName: String;
    I: Integer;
    MaxId: Integer;
    Params: TEngineParamArray;
    ParamsFileName: String;
    P: Integer;
    Suffix: String;
    SupportedCount: Integer;
    Value: String;

  begin
    MaxId := 0;
    SupportedCount := 0;
    Params := nil;
    if FileExists(RegisteredEnginesFileName) then
    begin
      Data := LoadRegisteredEngines(RegisteredEnginesFileName);
      try
        for I := 0 to Data.Count - 1 do
          if Data.Items[I].JSONType = jtObject then
          begin
            Value := RegisteredEngineProtocolId(TJSONObject(Data.Items[I]),
              ASection);
            if Value = '' then
            begin
              Entry := RegisteredEngineFromJson(TJSONObject(Data.Items[I]));
              if (Entry.Path <> '') and (Entry.Executable <> '') then
              begin
                EngineFileName := IncludeTrailingPathDelimiter(Entry.Path) +
                  Entry.Executable;
                ParamsFileName := EngineParamsFileNameForDisplayName('',
                  EngineFileName);
                SetLength(Params, 0);
                LoadParamsFromJson(ParamsFileName, ASection, Params);
                Value := Trim(EngineConfigParamValue(Params, AParamName, ''));
                if (Value = '') and EngineConfigParamExists(Params, AParamName) then
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
  begin
    Result := RegisteredEngineProtocolIdForFileName(RegisteredEnginesFileName,
      FEngines[AEngineIndex].FileName, AProtocol);
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
      RegisteredDxpPortUsed(RegisteredEnginesFileName,
      FEngines[AEngineIndex].FileName, AIpAddress, Result)) do
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

  function DxpLaunchModeInconsistencyMessage: String;
  var
    LaunchText: String;

    function LaunchHasToken(const AToken1, AToken2: String): Boolean;
    var
      I: Integer;
      Token: String;
      Tokens: TStringList;
    begin
      Result := False;
      Tokens := TStringList.Create;
      try
        ExtractStrings([' ', #9, #10, #13, ',', ';'], ['"'],
          PChar(LaunchText), Tokens);
        for I := 0 to Tokens.Count - 1 do
        begin
          Token := LowerCase(Trim(Tokens[I]));
          if (Token = AToken1) or (Token = AToken2) then
            Exit(True);
        end;
      finally
        Tokens.Free;
      end;
    end;

  begin
    Result := '';
    if ProtocolGroup.ItemIndex <> 1 then
      Exit;

    LaunchText := LowerCase(LaunchEdit.Text);
    if (RoleCombo.ItemIndex = 0) and
      LaunchHasToken('dxp_client', 'dxp-client') then
      Result :=
        'These DXP launch args look like they start an engine that connects ' +
        'to the GUI. Please set Socket mode to "GUI listens for engine ' +
        'connection".'
    else if (RoleCombo.ItemIndex = 1) and
      LaunchHasToken('dxp_server', 'dxp-server') then
      Result :=
        'These DXP launch args look like they start an engine socket listener. ' +
        'Please set Socket mode to "GUI connects to engine listener".';
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
      if EngineConfigParamExists(AParams, AIdParamName) then
        Result := Trim(EngineConfigParamValue(AParams, AIdParamName, '')) <> '';
    end;

    procedure UseDialogParams(const AParams: TEngineParamArray);
    var
      I: Integer;
    begin
      SetLength(FEngines[AEngineIndex].Params, Length(AParams));
      for I := 0 to High(AParams) do
        FEngines[AEngineIndex].Params[I] := AParams[I];
      LoadHubLaunchArgumentFromParams(AEngineIndex);
    end;

  begin
    if FEngines[AEngineIndex].ParamsFileName = '' then
      Exit;
    if not FileExists(FEngines[AEngineIndex].ParamsFileName) then
      Exit;

    HubParams := nil;
    DxpParams := nil;
    SetLength(HubParams, 0);
    SetLength(DxpParams, 0);
    LoadParamsFromJson(FEngines[AEngineIndex].ParamsFileName, 'hub', HubParams);
    LoadParamsFromJson(FEngines[AEngineIndex].ParamsFileName, 'dxp', DxpParams);

    if SameText(APreferredProtocol, 'dxp') and
      SectionSupportsProtocol(DxpParams, DxpIdParamName) then
    begin
      UseDialogParams(DxpParams);
      Exit;
    end;
    if SameText(APreferredProtocol, 'hub') and
      SectionSupportsProtocol(HubParams, HubIdParamName) then
    begin
      UseDialogParams(HubParams);
      Exit;
    end;
    if (FEngines[AEngineIndex].Protocol = epDxp) and
      SectionSupportsProtocol(DxpParams, DxpIdParamName) then
    begin
      UseDialogParams(DxpParams);
      Exit;
    end;
    if (FEngines[AEngineIndex].Protocol = epHub) and
      SectionSupportsProtocol(HubParams, HubIdParamName) then
    begin
      UseDialogParams(HubParams);
      Exit;
    end;

    if SectionSupportsProtocol(HubParams, HubIdParamName) then
      UseDialogParams(HubParams)
    else if SectionSupportsProtocol(DxpParams, DxpIdParamName) then
      UseDialogParams(DxpParams);
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
    IniText := EngineSlotParamValue(AEngineIndex, EngineIniContentParamName,
      '');
    if IniText <> '' then
      IniMemo.Lines.Text := IniText
    else if (IniFileName <> '') and FileExists(IniFileName) then
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

      DxpModeMessage := DxpLaunchModeInconsistencyMessage;
      if DxpModeMessage <> '' then
      begin
        ShowGuiOkDialog(Self, 'Open engine', DxpModeMessage);
        Continue;
      end;

      if DxpPortConflictsWithOtherEngine(OtherEngineIndex) then
      begin
        ShowGuiOkDialog(Self, 'Open engine',
          EngineLogName(OtherEngineIndex) +
          ' has already been configured for DXP port ' +
          IntToStr(SocketEdit.Value) + '. Please select another port.');
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
    IniText := IniMemo.Lines.Text;
    if IniFileName <> '' then
    begin
      try
        with TStringList.Create do
        try
          Text := StringReplace(IniText, '{ip}',
            FEngines[AEngineIndex].DxpIpAddress, [rfReplaceAll, rfIgnoreCase]);
          Text := StringReplace(Text, '{port}',
            FEngines[AEngineIndex].DxpSocketNumber,
            [rfReplaceAll, rfIgnoreCase]);
          SaveToFile(IniFileName);
        finally
          Free;
        end;
      except
        on E: Exception do
          ShowGuiOkDialog(Self, 'Could not save INI file',
            IniFileName + LineEnding + E.Message);
      end;
    end;
    SyncHubLaunchArgumentParam(AEngineIndex);
    if IniFileName <> '' then
      AddOrUpdateParam(FEngines[AEngineIndex].Params,
        EngineIniContentParamName, 'string', IniText, False);
    if FEngines[AEngineIndex].ParamsFileName <> '' then
    begin
      if FEngines[AEngineIndex].Protocol = epDxp then
        SaveSection := 'dxp'
      else
        SaveSection := 'hub';
      SaveParamsToJson(FEngines[AEngineIndex].ParamsFileName, SaveSection,
        FEngines[AEngineIndex].Params);
      AppendEngineSlotLog(AEngineIndex, '[saved ' + SaveSection +
        ' launch options to ' + FEngines[AEngineIndex].ParamsFileName + ']' +
        LineEnding);
    end;
    Result := True;
  finally
    Dialog.Free;
  end;
end;

procedure TMainWindow.OpenEngineMenuItemClick(Sender: TObject);
var
  EngineIndex: Integer;
  FileName: String;
  PreferredProtocol: String;
begin
  EngineIndex := EngineSlotIndexFromSender(Sender);
  if (EngineIndex = 2) and (not EngineSlotConfigured(1)) then
  begin
    AppendEngineSlotLog(2, '[please load engine 1 first; engine1 file="' +
      FEngines[1].FileName + '" params="' + FEngines[1].ParamsFileName +
      '" ready=' + BoolToStr(FEngines[1].Ready, True) + ' running=' +
      BoolToStr(EngineSlotProcessHandlePresent(1), True) + ' dxp-socket=' +
      BoolToStr(FEngines[1].DxpSocket <> nil, True) + ']' + LineEnding);
    Exit;
  end;

  if ShowEngineLauncherDialog(EngineIndex, FileName, PreferredProtocol) then
  begin
    try
      if EngineIndex = 1 then
        StartEngine(FileName, False, True, PreferredProtocol)
      else
        StartSecondEngine(FileName, False, True, PreferredProtocol);
    except
      on E: Exception do
        ShowGuiOkDialog(Self, 'Open engine', E.Message);
    end;
  end;
end;

procedure TMainWindow.EngineLauncherListDblClick(Sender: TObject);
begin
  if (Sender is TListBox) and (TListBox(Sender).Parent is TCustomForm) then
    TCustomForm(TListBox(Sender).Parent).ModalResult := mrOK;
end;

procedure TMainWindow.EnginePopupMenuPopup(Sender: TObject);
begin
  UpdateEnginePopupMenuItems;
end;

procedure TMainWindow.EditEngineParamsMenuItemClick(Sender: TObject);
begin
  ShowEngineSlotParamsDialog(EngineSlotIndexFromSender(Sender));
end;

procedure TMainWindow.EngineParamsDialogHide(Sender: TObject);
var
  Dialog: TEngineParamDialog;
  EngineIndex: Integer;
begin
  if not (Sender is TEngineParamDialog) then
    Exit;

  Dialog := TEngineParamDialog(Sender);
  EngineIndex := Dialog.Tag;
  if not EngineSlotIndexValid(EngineIndex) then
    EngineIndex := 1;
  HandleEngineSlotParamsDialogHide(EngineIndex, Dialog);
  Dialog.Release;
end;

procedure TMainWindow.ShowEngineSlotParamsDialog(AEngineIndex: Integer);
var
  Dialog: TEngineParamDialog;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  Dialog := TEngineParamDialog.Create(Self);
  SyncEngineSlotGuiParams(AEngineIndex);
  Dialog.SetParams(FEngines[AEngineIndex].Params);
  Dialog.LoadIniFromEngineFile(FEngines[AEngineIndex].FileName);
  Dialog.Tag := AEngineIndex;
  Dialog.OnHide := @EngineParamsDialogHide;
  CenterDialogOnMainWindow(Dialog);
  Dialog.Show;
end;

procedure TMainWindow.HandleEngineSlotParamsDialogHide(AEngineIndex: Integer;
  ADialog: TObject);
var
  Dialog: TEngineParamDialog;
  RestartAfterSave: Boolean;
  RestartFileName: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) or
    (ADialog = nil) then
    Exit;
  if not (ADialog is TEngineParamDialog) then
    Exit;

  Dialog := TEngineParamDialog(ADialog);
  if Dialog.ModalResult <> mrOK then
    Exit;

  RestartFileName := FEngines[AEngineIndex].FileName;
  RestartAfterSave := RestartFileName <> '';
  FEngines[AEngineIndex].Params := Dialog.Params;
  SyncEngineSlotGuiParams(AEngineIndex);
  if FEngines[AEngineIndex].ParamsFileName = '' then
    FEngines[AEngineIndex].ParamsFileName :=
      EngineCanonicalParamsFileName(FEngines[AEngineIndex].FileName);
  SaveParamsToJson(FEngines[AEngineIndex].ParamsFileName,
    FEngines[AEngineIndex].Params);
  AppendEngineSlotLog(AEngineIndex, '[saved engine parameters to ' +
    FEngines[AEngineIndex].ParamsFileName + ']' + LineEnding);
  if RestartAfterSave then
  begin
    AppendEngineSlotLog(AEngineIndex,
      '[launching engine after parameter change]' + LineEnding);
    if AEngineIndex = 2 then
      StartSecondEngine(RestartFileName, True)
    else
      StartEngine(RestartFileName, True);
  end;
end;

procedure TMainWindow.SyncEngineSlotGuiParams(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  LoadHubLaunchArgumentFromParams(AEngineIndex);
  SyncHubLaunchArgumentParam(AEngineIndex);
  SyncSendStartingPositionParam(AEngineIndex);
  SyncSingleCapturesIncludeCapturedSquareParam(AEngineIndex);
  RemoveAnalyzeSendsInfoParam(AEngineIndex);
  SyncEngineSupportsMctsParam(AEngineIndex);
  SyncScorePerspectiveParam(AEngineIndex);
  SyncEvaluationDepthMinParam(AEngineIndex);
  SyncEvaluationBarMaxParam(AEngineIndex);
end;

procedure TMainWindow.HandleEngineSlotIdLine(AEngineIndex: Integer;
  const ALine: String);
var
  NewDisplayName: String;
  NameText: String;
  VersionText: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  NameText := ExtractHubArgument(ALine, 'name');
  VersionText := ExtractHubArgument(ALine, 'version');

  if NameText = '' then
    Exit;

  NewDisplayName := NameText;
  if VersionText <> '' then
    NewDisplayName += '_' + VersionText;

  if (NewDisplayName = FEngines[AEngineIndex].DisplayName) and
    (NewDisplayName = FEngines[AEngineIndex].HubId) then
    Exit;

  FEngines[AEngineIndex].DisplayName := NewDisplayName;
  if FEngines[AEngineIndex].Protocol = epHub then
  begin
    FEngines[AEngineIndex].HubId := NewDisplayName;
    AddOrUpdateParam(FEngines[AEngineIndex].Params, HubIdParamName, 'string',
      FEngines[AEngineIndex].HubId, False);
    if FEngines[AEngineIndex].ParamsFileName <> '' then
      SaveParamsToJson(FEngines[AEngineIndex].ParamsFileName, 'hub',
        FEngines[AEngineIndex].Params);
    UpdateRegisteredEngineId(FEngines[AEngineIndex].FileName,
      FEngines[AEngineIndex].HubId, 'hub');
  end;
  AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
    ' name: ' + FEngines[AEngineIndex].DisplayName + ']' + LineEnding);
end;

procedure TMainWindow.HandleEngineSlotParamLine(AEngineIndex: Integer;
  const ALine: String);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  AddOrUpdateParam(FEngines[AEngineIndex].Params,
    ExtractHubArgument(ALine, 'name'), ExtractHubArgument(ALine, 'type'),
    ExtractHubArgument(ALine, 'value'), True);
end;

procedure TMainWindow.HandleEngineSlotInfoLine(AEngineIndex: Integer;
  const ALine: String);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  if AEngineIndex = 1 then
  begin
    FLastEngineInfoLine := ALine;
    FLastEngineInfoAnnotation := EngineInfoAnnotation(ALine);
    UpdateEngineEvalFromInfo(ALine);
  end;
  UpdateAnalyzeBestMoveFromInfo(AEngineIndex, ALine);
end;

procedure TMainWindow.HandleEngineSlotErrorLine(AEngineIndex: Integer;
  const ALine: String);
var
  ErrorText: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  ErrorText := ExtractHubArgument(ALine, 'message');
  if ErrorText = '' then
    ErrorText := ALine;
  AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
    ' error: ' + ErrorText + ']' + LineEnding);
end;

procedure TMainWindow.HandleEngineSlotWaitLine(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if FEngines[AEngineIndex].WaitingForInit then
    Exit;

  FEngines[AEngineIndex].WaitingForInit := True;
  SendEngineSlotParams(AEngineIndex);
  LogEngineSlotCommandSent(AEngineIndex, 'init');
  SendEngineSlotCommand(AEngineIndex, 'init');
end;

procedure TMainWindow.HandleEngineSlotReadyLine(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  FEngines[AEngineIndex].Ready := True;
  FEngines[AEngineIndex].WaitingForInit := False;
  UpdateEngineSlotReadyUi(AEngineIndex);
  AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
    ' ready]' + LineEnding);
  if FEngines[AEngineIndex].ParamsFileName <> '' then
    SaveParamsToJson(FEngines[AEngineIndex].ParamsFileName,
      FEngines[AEngineIndex].Params);

  if AEngineIndex = 1 then
  begin
    if FEngineStartAfterReady then
    begin
      FEngineStartAfterReady := False;
      if FPlayGameActive then
        ContinuePlayGameSearch
      else
        SendGoAnalyzeToEngine;
    end;
    Exit;
  end;

  if RunPendingEngineSlotAction(2, '') then
    Exit;
  if FEngineAnalyzeEnabled and (FEngines[1].State = esAnalyzing) and
    (FEngines[1].SearchMode in [esmAnalyze, esmPlayGameAnalyze]) then
  begin
    AppendEngineSlotLog(2, '[' + EngineLogName(2) +
      ' catching up to current analysis]' + LineEnding);
    SendGoAnalyzeToEngineSlot(2, FEngines[1].SearchMode);
  end;
end;

procedure TMainWindow.HandleEngineSlotDoneLine(AEngineIndex: Integer;
  const ALine: String);
var
  MoveText: String;
  ResultText: String;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  MoveText := ExtractHubArgument(ALine, 'move');
  ResultText := ExtractHubArgument(ALine, 'result');
  LogEngineTimingDiagnostic(AEngineIndex, 'Hub', ALine,
    PlatformTimestampSeconds);

  if HandleHubDoneDrawResult(AEngineIndex, ResultText) then
  begin
    ClearEngineTiming(AEngineIndex);
    Exit;
  end;

  if AEngineIndex = 1 then
  begin
    FLastEngineDoneLine := ALine;
    if FLastEngineInfoLine <> '' then
      UpdateEngineEvalFromInfo(FLastEngineInfoLine, True);
  end;

  if RunPendingEngineSlotAction(AEngineIndex, MoveText) then
    Exit;

  if HandleStoppedSearchDone(AEngineIndex, MoveText) then
    Exit;

  if AEngineIndex = 1 then
    HandleEngine1DoneMove(MoveText)
  else
    HandleEngine2DoneMove(MoveText, FEngines[2].SearchMode);
end;

function TMainWindow.HandleHubDoneDrawResult(AEngineIndex: Integer;
  const AResultText: String): Boolean;
begin
  Result := FPlayGameActive and HubDoneResultIsDraw(AResultText);
  if Result then
    EndCurrentGame(gerAgreedDraw, '1-1', AEngineIndex);
end;

function TMainWindow.HandleStoppedSearchDone(AEngineIndex: Integer;
  const AMoveText: String): Boolean;
begin
  Result := False;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if AEngineIndex = 1 then
  begin
    if not FEngines[1].IgnoreNextDoneMove then
      Exit;
    FEngines[1].IgnoreNextDoneMove := False;
    if FEngines[1].SearchMode = esmIdle then
      SetEngineSlotState(1, esIdle);
  end
  else
  begin
    if not FEngines[AEngineIndex].IgnoreNextDoneMove then
      Exit;
    FEngines[AEngineIndex].IgnoreNextDoneMove := False;
    if FEngines[AEngineIndex].SearchMode = esmIdle then
      SetEngineSlotState(AEngineIndex, esIdle);
  end;

  if AMoveText <> '' then
    AppendEngineSlotLog(AEngineIndex, '[ignored stopped-search move ' +
      AMoveText + ']' + LineEnding)
  else
    AppendEngineSlotLog(AEngineIndex, '[ignored stopped-search done]' +
      LineEnding);
  ClearEngineTiming(AEngineIndex);
  Result := True;
end;

procedure TMainWindow.HandleEngine1DoneMove(const AMoveText: String);
begin
  HandleEngineDoneMove(AMoveText);
end;

procedure TMainWindow.HandleEngine2DoneMove(const AMoveText: String;
  ASearchMode: TEngineSearchMode);
begin
  FinishEngineSlotSearch(2);
  if FPlayGameActive and IsPlayGameSecondEngineTurn and
    (ASearchMode = esmPlayGameThink) and (AMoveText <> '') then
    HandleEngineMoveForSearchMode(2, AMoveText, ASearchMode)
  else if AMoveText <> '' then
    AppendEngineSlotLog(2, '[analysis move ignored: ' + AMoveText + ']' + LineEnding)
  else
    AppendEngineSlotLog(2, '[' + EngineLogName(2) + ' done]' + LineEnding);
end;

function TMainWindow.PrepareEngineSlotForLaunch(AEngineIndex: Integer;
  const AFileName: String; AUseCurrentParams, AShowLaunchOptions: Boolean;
  const APreferredProtocol: String): Boolean;
begin
  Result := False;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  LoadEngineSlotLaunchParams(AEngineIndex, AFileName, AUseCurrentParams);
  if not ConfirmEngineSlotLaunchOptions(AEngineIndex, AShowLaunchOptions,
    APreferredProtocol) then
    Exit;
  PrepareEngineSlotLaunchLog(AEngineIndex, AFileName);
  FinalizeEngineSlotLaunchPreparation(AEngineIndex);
  Result := True;
end;

procedure TMainWindow.PrepareEngineSlotLaunchLog(AEngineIndex: Integer;
  const AFileName: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if FEngines[AEngineIndex].LogMemo <> nil then
  begin
    FEngines[AEngineIndex].LogMemo.Clear;
    AppendEngineSlotLog(AEngineIndex, '[engine executable: ' + AFileName +
      ']' + LineEnding);
  end;
end;

procedure TMainWindow.LoadEngineSlotLaunchParams(AEngineIndex: Integer;
  const AFileName: String; AUseCurrentParams: Boolean);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  FEngines[AEngineIndex].FileName := AFileName;
  if not AUseCurrentParams then
  begin
    FEngines[AEngineIndex].DisplayName :=
      ChangeFileExt(ExtractFileName(AFileName), '');
    FEngines[AEngineIndex].ParamsFileName :=
      EngineCanonicalParamsFileName(FEngines[AEngineIndex].FileName);
    LoadParamsFromJson(FEngines[AEngineIndex].ParamsFileName,
      FEngines[AEngineIndex].Params);
  end;

  SyncEngineSlotGuiParams(AEngineIndex);
end;

function TMainWindow.ConfirmEngineSlotLaunchOptions(AEngineIndex: Integer;
  AShowLaunchOptions: Boolean; const APreferredProtocol: String): Boolean;
begin
  Result := False;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  if (not AShowLaunchOptions) or
    ShowEngineLaunchOptionsDialog(AEngineIndex, APreferredProtocol) then
    Result := True;
end;

procedure TMainWindow.FinalizeEngineSlotLaunchPreparation(
  AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if (Length(FEngines[AEngineIndex].Params) > 0) and
    (FEngines[AEngineIndex].LogMemo <> nil) then
    FEngines[AEngineIndex].LogMemo.Lines.Add(
      EngineLoadedParametersLogText(FEngines[AEngineIndex].ParamsFileName));

  ResetEngineRuntimeForLaunch(AEngineIndex);
end;

function TMainWindow.EnsureDxpListenerReadyForLaunch(
  AEngineIndex: Integer): Boolean;
var
  OtherEngineIndex: Integer;
begin
  Result := True;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit(False);

  if (FEngines[AEngineIndex].Protocol <> epDxp) or
    (FEngines[AEngineIndex].DxpRole <> edrClient) then
    Exit;

  if DxpListenerPortInUse(AEngineIndex, OtherEngineIndex) then
    raise Exception.Create(EngineLogName(OtherEngineIndex) +
      ' has already been configured for DXP port ' +
      FEngines[AEngineIndex].DxpSocketNumber + '. Please select another port.');

  if not StartDxpConnection(AEngineIndex) then
  begin
    AppendEngineSlotLog(AEngineIndex, EngineLaunchAbortedLogText(
      'DXP listener is not ready'));
    Result := False;
  end;
end;

procedure TMainWindow.LogEngineSlotLaunch(AEngineIndex: Integer;
  ALaunchArgs: TStringList);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  AppendEngineSlotLog(AEngineIndex,
    EngineLaunchLogText(FEngines[AEngineIndex].ParamsFileName,
      FEngines[AEngineIndex].Protocol, FEngines[AEngineIndex].DxpId,
      ALaunchArgs.DelimitedText));
end;

procedure TMainWindow.LaunchEngineSlotProcess(AEngineIndex: Integer;
  const AFileName: String; ALaunchArgs: TStringList);
var
  CurrentDir: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  CurrentDir := ExtractFilePath(AFileName);
  AppendEngineSlotLog(AEngineIndex,
    EngineExecuteBeginLogText(EngineLogName(AEngineIndex)));
  AppendEngineSlotLog(AEngineIndex,
    EngineExecuteCwdLogText(EngineLogName(AEngineIndex), CurrentDir));
  FEngines[AEngineIndex].PlatformProcess.Start(AFileName, ALaunchArgs, CurrentDir);
end;

procedure TMainWindow.FinalizeEngineSlotLaunch(AEngineIndex: Integer;
  const AFileName: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  UpdateEnginePollTimer;
  AppendEngineSlotLog(AEngineIndex,
    EngineExecuteReturnedLogText(EngineLogName(AEngineIndex),
      EngineSlotIsRunning(AEngineIndex)));

  RegisterLaunchedEngineSlot(AEngineIndex, AFileName);
  if FEngines[AEngineIndex].Protocol = epDxp then
    FinalizeDxpEngineSlotLaunch(AEngineIndex)
  else
    FinalizeHubEngineSlotLaunch(AEngineIndex);
  UpdateEnginePopupMenuItems;
end;

procedure TMainWindow.RegisterLaunchedEngineSlot(AEngineIndex: Integer;
  const AFileName: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  RegisterEngineExecutable(AFileName);
  if (FEngines[AEngineIndex].Protocol = epDxp) and
    (Trim(FEngines[AEngineIndex].DxpId) <> '') then
    UpdateRegisteredEngineId(AFileName, Trim(FEngines[AEngineIndex].DxpId), 'dxp')
  else if (FEngines[AEngineIndex].Protocol = epHub) and
    (Trim(FEngines[AEngineIndex].HubId) <> '') then
    UpdateRegisteredEngineId(AFileName, Trim(FEngines[AEngineIndex].HubId), 'hub');
end;

procedure TMainWindow.FinalizeDxpEngineSlotLaunch(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if Trim(FEngines[AEngineIndex].DxpId) <> '' then
    FEngines[AEngineIndex].DisplayName := Trim(FEngines[AEngineIndex].DxpId);
  UpdateEngineCommandButtons;
  AppendEngineSlotLog(AEngineIndex, EngineDxpLaunchDetailsLogText(
    FEngines[AEngineIndex].DxpId, FEngines[AEngineIndex].DxpRole,
    FEngines[AEngineIndex].DxpIpAddress,
    FEngines[AEngineIndex].DxpSocketNumber,
    FEngines[AEngineIndex].DxpLaunchArguments));
  if FEngines[AEngineIndex].DxpRole = edrListener then
    StartDxpConnection(AEngineIndex);
end;

procedure TMainWindow.FinalizeHubEngineSlotLaunch(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  AppendEngineSlotLog(AEngineIndex, EngineHubLaunchDetailsLogText(
    FEngines[AEngineIndex].HubLaunchArgument));
  LogEngineSlotCommandSent(AEngineIndex, 'hub');
  SendEngineSlotCommand(AEngineIndex, 'hub');
end;

procedure TMainWindow.StartEngine(const AFileName: String; AUseCurrentParams: Boolean;
  AShowLaunchOptions: Boolean; const APreferredProtocol: String);
begin
  CloseEngine;
  StartEngineSlot(1, AFileName, AUseCurrentParams, AShowLaunchOptions,
    APreferredProtocol);
end;

procedure TMainWindow.StartSecondEngine(const AFileName: String;
  AUseCurrentParams: Boolean; AShowLaunchOptions: Boolean;
  const APreferredProtocol: String);
begin
  CloseSecondEngine;
  StartEngineSlot(2, AFileName, AUseCurrentParams, AShowLaunchOptions,
    APreferredProtocol);
end;

procedure TMainWindow.StartEngineSlot(AEngineIndex: Integer;
  const AFileName: String; AUseCurrentParams, AShowLaunchOptions: Boolean;
  const APreferredProtocol: String);
var
  LaunchArgs: TStringList;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if not PrepareEngineSlotForLaunch(AEngineIndex, AFileName, AUseCurrentParams,
    AShowLaunchOptions, APreferredProtocol) then
    Exit;

  PrepareUiForEngineSlotStart(AEngineIndex);
  if not EnsureDxpListenerReadyForLaunch(AEngineIndex) then
    Exit;

  LaunchArgs := TStringList.Create;
  try
    EngineLaunchArguments(FEngines[AEngineIndex], LaunchArgs);
    LogEngineSlotLaunch(AEngineIndex, LaunchArgs);
    LaunchEngineSlotProcess(AEngineIndex, AFileName, LaunchArgs);
    FinalizeEngineSlotLaunch(AEngineIndex, AFileName);
  finally
    LaunchArgs.Free;
  end;
end;

procedure TMainWindow.PrepareUiForEngineSlotStart(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  if AEngineIndex = 1 then
    ResetPrimaryStateBeforeEngineStart
  else
    ResetSecondaryStateBeforeEngineStart;
  RefreshEngineUiAfterSlotChange;
end;

procedure TMainWindow.ResetPrimaryStateBeforeEngineStart;
begin
  FAutoPlayActive := False;
  FAutoPlayPlyCount := 0;
  FEngineStartAfterReady := True;
  FEngines[1].IgnoreNextDoneMove := False;
  ClearEngineSlotPendingAction(1);
  ClearEngineSlotPendingAction(2);
  LeavePlayGameMode;
end;

procedure TMainWindow.ResetSecondaryStateBeforeEngineStart;
begin
  ClearEngineSlotPendingAction(2);
end;

procedure TMainWindow.SendEngineSlotCommand(AEngineIndex: Integer;
  const ACommand: String);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if not EngineSlotIsRunning(AEngineIndex) then
    Exit;

  if FEngines[AEngineIndex].PlatformProcess <> nil then
    FEngines[AEngineIndex].PlatformProcess.WriteLine(ACommand);
end;

procedure TMainWindow.LogEngineSlotCommandSent(AEngineIndex: Integer;
  const ACommand: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  AppendEngineSlotLog(AEngineIndex, EngineCommandSentLogText(ACommand));
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

procedure TMainWindow.SyncHubLaunchArgumentParam(AEngineIndex: Integer);
var
  Config: TEngineProtocolConfig;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  if Trim(FEngines[AEngineIndex].HubId) = '' then
    FEngines[AEngineIndex].HubId := 'Hub' + IntToStr(AEngineIndex);
  if Trim(FEngines[AEngineIndex].DxpId) = '' then
    FEngines[AEngineIndex].DxpId := 'DXP' + IntToStr(AEngineIndex);

  Config.Protocol := FEngines[AEngineIndex].Protocol;
  Config.HubId := FEngines[AEngineIndex].HubId;
  Config.IniFileName := FEngines[AEngineIndex].IniFileName;
  Config.HubLaunchArgument := FEngines[AEngineIndex].HubLaunchArgument;
  Config.DxpId := FEngines[AEngineIndex].DxpId;
  Config.DxpIpAddress := FEngines[AEngineIndex].DxpIpAddress;
  Config.DxpSocketNumber := FEngines[AEngineIndex].DxpSocketNumber;
  Config.DxpLaunchArguments := FEngines[AEngineIndex].DxpLaunchArguments;
  Config.DxpRole := FEngines[AEngineIndex].DxpRole;
  SaveEngineProtocolConfig(FEngines[AEngineIndex].Params, Config);
end;

procedure TMainWindow.SyncSendStartingPositionParam(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  SyncEngineParamWithLegacy(FEngines[AEngineIndex].Params,
    SendStartingPositionParamName, OldSendStartingPositionParamName, 'bool',
    'true');
end;

procedure TMainWindow.SyncSingleCapturesIncludeCapturedSquareParam(
  AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  SyncEngineParamWithLegacy(FEngines[AEngineIndex].Params,
    SingleCapturesIncludeCapturedSquareParamName,
    OldSingleCapturesIncludeCapturedSquareParamName, 'bool', 'true');
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
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  SyncEngineParamWithLegacy(FEngines[AEngineIndex].Params,
    EvaluationDepthMinParamName, OldEvaluationDepthMinParamName, 'int', '4');
end;

procedure TMainWindow.SyncEvaluationBarMaxParam(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  SyncEngineParamWithLegacy(FEngines[AEngineIndex].Params,
    EvaluationBarMaxParamName, OldEvaluationBarMaxParamName, 'int', '1000');
end;

procedure TMainWindow.LoadHubLaunchArgumentFromParams(AEngineIndex: Integer);
var
  Config: TEngineProtocolConfig;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  Config := LoadEngineProtocolConfig(FEngines[AEngineIndex].Params,
    AEngineIndex);
  ApplyEngineSlotProtocolConfig(AEngineIndex, Config);
  SyncHubLaunchArgumentParam(AEngineIndex);
end;

procedure TMainWindow.ApplyEngineSlotProtocolConfig(AEngineIndex: Integer;
  const AConfig: TEngineProtocolConfig);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  FEngines[AEngineIndex].Protocol := AConfig.Protocol;
  FEngines[AEngineIndex].HubId := AConfig.HubId;
  FEngines[AEngineIndex].IniFileName := AConfig.IniFileName;
  FEngines[AEngineIndex].HubLaunchArgument := AConfig.HubLaunchArgument;
  FEngines[AEngineIndex].DxpId := AConfig.DxpId;
  FEngines[AEngineIndex].DxpIpAddress := AConfig.DxpIpAddress;
  FEngines[AEngineIndex].DxpSocketNumber := AConfig.DxpSocketNumber;
  FEngines[AEngineIndex].DxpLaunchArguments := AConfig.DxpLaunchArguments;
  FEngines[AEngineIndex].DxpRole := AConfig.DxpRole;
end;

procedure TMainWindow.ResetEngineSlotProtocolConfig(AEngineIndex: Integer);
begin
  ApplyEngineSlotProtocolConfig(AEngineIndex,
    DefaultEngineProtocolConfig(AEngineIndex));
end;

function TMainWindow.EngineSlotParamValue(AEngineIndex: Integer; const AName,
  ADefault: String): String;
begin
  Result := ADefault;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  Result := EngineConfigParamValue(FEngines[AEngineIndex].Params, AName,
    ADefault);
end;

function TMainWindow.EngineSlotParamBool(AEngineIndex: Integer;
  const AName: String; ADefault: Boolean): Boolean;
begin
  Result := ADefault;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  Result := EngineConfigParamBool(FEngines[AEngineIndex].Params, AName,
    ADefault);
end;

function TMainWindow.EngineSlotParamInt(AEngineIndex: Integer;
  const AName: String; ADefault: Integer): Integer;
begin
  Result := ADefault;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  Result := EngineConfigParamInt(FEngines[AEngineIndex].Params, AName,
    ADefault);
end;

function TMainWindow.EngineSlotParamFloat(AEngineIndex: Integer;
  const AName: String; ADefault: Double): Double;
begin
  Result := ADefault;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  Result := EngineConfigParamFloat(FEngines[AEngineIndex].Params, AName,
    ADefault);
end;

function TMainWindow.EngineSendStartingPosition(AEngineIndex: Integer): Boolean;
begin
  Result := EngineSlotParamBool(AEngineIndex, SendStartingPositionParamName,
    True);
end;

function TMainWindow.EngineSingleCapturesIncludeCapturedSquare(
  AEngineIndex: Integer): Boolean;
begin
  Result := EngineSlotParamBool(AEngineIndex,
    SingleCapturesIncludeCapturedSquareParamName, True);
end;

function TMainWindow.EngineSupportsMcts(AEngineIndex: Integer): Boolean;
begin
  Result := EngineSlotParamBool(AEngineIndex, EngineSupportsMctsParamName,
    False);
end;

function TMainWindow.EngineScorePerspective(AEngineIndex: Integer): String;
begin
  Result := LowerCase(Trim(EngineSlotParamValue(AEngineIndex,
    ScorePerspectiveParamName, 'side-to-move')));
  if Result = '' then
    Result := 'side-to-move';
end;

function TMainWindow.EngineEvaluationDepthMin(AEngineIndex: Integer): Double;
begin
  Result := EngineSlotParamFloat(AEngineIndex, EvaluationDepthMinParamName, 4.0);
  if Result < 0.0 then
    Result := 4.0;
end;

function TMainWindow.EngineEvaluationBarMax(AEngineIndex: Integer): Double;
begin
  Result := EngineSlotParamFloat(AEngineIndex, EvaluationBarMaxParamName,
    EvalBarDefaultMaxScore);
  if Result <= 0.0 then
    Result := EvalBarDefaultMaxScore;
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
    EngineStateLogText(FEngines[1].State, PlayerNameToMove);
  Line += '; ' + EngineLogName(2) + ': ' +
    EngineStateLogText(FEngines[2].State, PlayerNameToMove);
  if AReason <> '' then
    Line += '; reason=' + AReason;
  Line += ']' + LineEnding;

  AppendEngineSlotLog(1, Line);
  if SecondEngineIsRunning then
    AppendEngineSlotLog(2, Line);
end;

function TMainWindow.EngineSlotPendingAction(
  AEngineIndex: Integer): TPendingEngineAction;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit(peaNone);

  Result := FEngines[AEngineIndex].PendingAction;
end;

procedure TMainWindow.ClearEngineSlotPendingAction(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  FEngines[AEngineIndex].PendingAction := peaNone;
  FEngines[AEngineIndex].PendingMode := esmIdle;
end;

procedure TMainWindow.SetEngineSlotPendingAction(AEngineIndex: Integer;
  AAction: TPendingEngineAction; AMode: TEngineSearchMode);
var
  OldAction: TPendingEngineAction;
  LogLine: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  OldAction := EngineSlotPendingAction(AEngineIndex);
  FEngines[AEngineIndex].PendingAction := AAction;
  FEngines[AEngineIndex].PendingMode := AMode;
  if OldAction <> AAction then
  begin
    LogLine := '[' + EngineLogName(AEngineIndex) + ' pending action: ' +
      PendingEngineActionText(OldAction) + ' -> ' +
      PendingEngineActionText(AAction) + '; GUI: ' + GuiStateText(FGuiState) +
      ']' + LineEnding;
    AppendEngineSlotLog(AEngineIndex, LogLine);
  end;
end;

procedure TMainWindow.RequestEngineSlotActionAfterStop(AEngineIndex: Integer;
  AAction: TPendingEngineAction; AMode: TEngineSearchMode;
  const AReason: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  SetEngineSlotPendingAction(AEngineIndex, AAction, AMode);
  if AReason <> '' then
    AppendEngineSlotLog(AEngineIndex, '[' + AReason + ']' + LineEnding);
  SendStopToEngineSlot(AEngineIndex);
end;

function TMainWindow.RunPendingEngineSlotAction(AEngineIndex: Integer;
  const AStoppedMoveText: String): Boolean;
var
  PendingAction: TPendingEngineAction;
  PendingMode: TEngineSearchMode;
begin
  Result := False;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  PendingAction := EngineSlotPendingAction(AEngineIndex);
  if PendingAction = peaNone then
    Exit;

  PendingMode := FEngines[AEngineIndex].PendingMode;
  if AEngineIndex = 1 then
  begin
    FEngines[1].IgnoreNextDoneMove := False;
  end
  else
    FEngines[AEngineIndex].IgnoreNextDoneMove := False;

  FinishEngineSlotSearch(AEngineIndex);
  if AStoppedMoveText <> '' then
    AppendEngineSlotLog(AEngineIndex, '[ignored previous-search move ' +
      AStoppedMoveText + ']' + LineEnding)
  else
    AppendEngineSlotLog(AEngineIndex, '[previous search stopped]' +
      LineEnding);

  ClearEngineSlotPendingAction(AEngineIndex);
  case PendingAction of
    peaAutoPlay:
      if AEngineIndex = 1 then
        BeginAutoPlay;
    peaAnalyze:
      if AEngineIndex = 1 then
        SendGoAnalyzeToEngine(PendingMode)
      else
        SendGoAnalyzeToEngineSlot(2, PendingMode);
    peaMcts:
      SendGoMctsToEngine;
    peaThink:
      SendGoThinkToEngineSlot(AEngineIndex, PendingMode);
    peaPlayGame:
      if AEngineIndex = 1 then
        BeginPlayGame(FPendingPlayGameWhiteIsEngine,
          FPendingPlayGameBlackIsEngine, FPendingPlayGameWhiteName,
          FPendingPlayGameBlackName, FPendingPlayGameMinutes,
          FPendingPlayGameFromCurrent, True, FPendingPlayGameWhiteEngineIndex,
          FPendingPlayGameBlackEngineIndex);
  end;
  Result := True;
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
  AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
    ' state: ' + EngineStateLogText(OldState, PlayerNameToMove) + ' -> ' +
    EngineStateLogText(Slot.State, PlayerNameToMove) + '; GUI: ' + GuiStateText(FGuiState) +
    ']' + LineEnding);
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
    AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
      ' state: ' + EngineStateLogText(OldState, PlayerNameToMove) + ' -> ' +
      EngineStateLogText(Slot.State, PlayerNameToMove) + '; GUI: ' + GuiStateText(FGuiState) +
      ']' + LineEnding);
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
    AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
      ' state: ' + EngineStateLogText(OldState, PlayerNameToMove) + ' -> idle; GUI: ' +
      GuiStateText(FGuiState) + ']' + LineEnding);
end;

procedure TMainWindow.ResetEngineSlotRuntime(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  FEngines[AEngineIndex].ResetRuntimeState;
  UpdateEngineStateLabels;
end;

procedure TMainWindow.SetDxpGameState(AEngineIndex: Integer;
  AState: TDxpGameState; const AReason: String);
var
  LogText: String;
  OldState: TDxpGameState;
  Slot: TEngineSlot;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  Slot := FEngines[AEngineIndex];
  if Slot.DxpGameState = AState then
  begin
    if AReason <> '' then
      AppendEngineSlotLog(AEngineIndex, '[DXP state: ' +
        DxpGameStateText(AState) + '; reason=' + AReason + ']' +
        LineEnding);
    Exit;
  end;

  OldState := Slot.DxpGameState;
  Slot.DxpGameState := AState;
  LogText := '[DXP state: ' + DxpGameStateText(OldState) + ' -> ' +
    DxpGameStateText(AState) + '; GUI: ' + GuiStateText(FGuiState);
  if AReason <> '' then
    LogText += '; reason=' + AReason;
  LogText += ']' + LineEnding;
  AppendEngineSlotLog(AEngineIndex, LogText);
end;

procedure TMainWindow.BeginDxpGameRequest(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  FEngines[AEngineIndex].DxpGameEndSent := False;
  SetDxpGameState(AEngineIndex, dgsGameRequested, 'GAMEREQ build started');
end;

procedure TMainWindow.CancelDxpGameRequest(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  SetDxpGameState(AEngineIndex, dgsIdle, 'GAMEREQ cancelled');
end;

procedure TMainWindow.MarkDxpWaitingForProtocolReply(AEngineIndex: Integer;
  const AReason: String; const ALogText: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  SetDxpGameState(AEngineIndex, dgsWaitingForMoveOrGameEnd, AReason);
  if ALogText <> '' then
    AppendEngineSlotLog(AEngineIndex, ALogText + LineEnding);
end;

procedure TMainWindow.MarkDxpGameRequestSent(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  SetDxpGameState(AEngineIndex, dgsGameRequested,
    'GAMEREQ sent; waiting for DXP_GAMEACC');
  AppendEngineSlotLog(AEngineIndex, '[Waiting for DXP_GAMEACC]' + LineEnding);
end;

procedure TMainWindow.MarkDxpMoveSent(AEngineIndex: Integer);
begin
  MarkDxpWaitingForProtocolReply(AEngineIndex, 'MOVE sent');
end;

procedure TMainWindow.MarkDxpGameEndSent(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  FEngines[AEngineIndex].DxpGameEndSent := True;
  SetDxpGameState(AEngineIndex, dgsGameEnding, 'GAMEEND sent');
end;

procedure TMainWindow.MarkDxpGameEndArrived(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  FinishEngineSlotSearch(AEngineIndex);
  SetDxpGameState(AEngineIndex, dgsWaitingForNextGame, 'GAMEEND received');
  AppendEngineSlotLog(AEngineIndex, '[DXP_GAMEEND received]' + LineEnding);
end;

procedure TMainWindow.MarkDxpWaitingForReply(AEngineIndex: Integer;
  AMode: TEngineSearchMode; const AReason: String);
begin
  if AMode = esmPlayGameThink then
    ActivateGameClocks;
  MarkDxpWaitingForProtocolReply(AEngineIndex, AReason);
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

function TMainWindow.DxpShouldAcceptGameEnd(AEngineIndex: Integer): Boolean;
begin
  Result := False;
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  if FEngines[AEngineIndex].DxpGameState = dgsGameEnding then
    Exit(True);

  Result := (FEngines[AEngineIndex].DxpGameState =
    dgsWaitingForMoveOrGameEnd) and
    (FEngines[AEngineIndex].SearchMode <> esmIdle);
end;

procedure TMainWindow.ClearEngineTiming(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  FEngines[AEngineIndex].DxpTimingActive := False;
  FEngines[AEngineIndex].DxpTimingLabel := '';
  FEngines[AEngineIndex].DxpTimingSendClockSeconds := 0;
  FEngines[AEngineIndex].DxpTimingSendWallSeconds := 0;
end;

procedure TMainWindow.StoreEngineTimingStart(AEngineIndex: Integer;
  const ALabel: String);
var
  Slot: TEngineSlot;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  Slot := FEngines[AEngineIndex];
  Slot.DxpTimingActive := True;
  Slot.DxpTimingLabel := ALabel;
  Slot.DxpTimingSendSide := FSideToMove;
  Slot.DxpTimingSendWallSeconds := PlatformTimestampSeconds;
  if FPlayClock <> nil then
    Slot.DxpTimingSendClockSeconds := FPlayClock.SecondsForSide(FSideToMove)
  else
    Slot.DxpTimingSendClockSeconds := 0;
end;

procedure TMainWindow.StoreDxpTimingStart(AEngineIndex: Integer;
  const ALabel: String);
begin
  StoreEngineTimingStart(AEngineIndex, ALabel);
end;

procedure TMainWindow.LogEngineTimingDiagnostic(AEngineIndex: Integer;
  const AProtocolName, AReceivedMessage: String; AReceivedAtSeconds: Double);
var
  ClockDelta: Double;
  ClockText: String;
  ReceiveClock: Double;
  ReceiveSeconds: Double;
  SideText: String;
  Slot: TEngineSlot;
  WallDelta: Double;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  Slot := FEngines[AEngineIndex];
  if not Slot.DxpTimingActive then
    Exit;

  ReceiveSeconds := AReceivedAtSeconds;
  if ReceiveSeconds <= 0 then
    ReceiveSeconds := PlatformTimestampSeconds;
  WallDelta := ReceiveSeconds - Slot.DxpTimingSendWallSeconds;
  if WallDelta < 0 then
    WallDelta := 0;

  if FPlayClock <> nil then
    ReceiveClock := FPlayClock.SecondsForSideAt(Slot.DxpTimingSendSide,
      FSideToMove, ReceiveSeconds)
  else
    ReceiveClock := 0;
  ClockDelta := Slot.DxpTimingSendClockSeconds - ReceiveClock;
  if ClockDelta < 0 then
    ClockDelta := 0;

  if Slot.DxpTimingSendSide = sideWhite then
    SideText := 'white'
  else
    SideText := 'black';

  if FPlayGameActive and (FPlayClock <> nil) then
    ClockText := '; ' + SideText + ' clock send=' +
      FormatFloat('0.000', Slot.DxpTimingSendClockSeconds) +
      ' recv=' + FormatFloat('0.000', ReceiveClock) +
      ' delta=' + FormatFloat('0.000', ClockDelta)
  else
    ClockText := '; ' + SideText +
      ' clock delta unavailable: game clock no longer active';

  AppendEngineSlotLog(AEngineIndex, '[' + AProtocolName + ' timing: sent ' +
    Slot.DxpTimingLabel + '; received ' + AReceivedMessage +
    '; wall send=' + FormatFloat('0.000', Slot.DxpTimingSendWallSeconds) +
    ' recv=' + FormatFloat('0.000', ReceiveSeconds) +
    ' delta=' + FormatFloat('0.000', WallDelta) + ClockText + ']' +
    LineEnding);
end;

procedure TMainWindow.LogDxpTimingDiagnostic(AEngineIndex: Integer;
  const AReceivedMessage: String; AReceivedAtSeconds: Double);
begin
  LogEngineTimingDiagnostic(AEngineIndex, 'DXP', AReceivedMessage,
    AReceivedAtSeconds);
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
      EngineSlotDxpConnectionActive(I) and
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
    AppendEngineSlotLog(AEngineIndex, LogText);
    Exit;
  end;

  if DxpListenerPortInUse(AEngineIndex, OtherEngineIndex) then
  begin
    LogText := '[' + EngineLogName(OtherEngineIndex) +
      ' has already been configured for DXP port ' + IntToStr(Port) +
      '. Please select another port]' + LineEnding;
    AppendEngineSlotLog(AEngineIndex, LogText);
    Exit;
  end;

  FEngines[AEngineIndex].Ready := False;
  FEngines[AEngineIndex].DxpThread := TEngineDxpConnectionThread.Create(
    AEngineIndex, FEngines[AEngineIndex].DxpIpAddress, Word(Port),
    FEngines[AEngineIndex].DxpRole, @DxpConnectionMessage,
    @DxpConnectionConnected, @DxpConnectionError,
    @DxpConnectionAttemptFailed);

  if FEngines[AEngineIndex].DxpRole = edrClient then
  begin
    for I := 1 to 200 do
    begin
      if (FEngines[AEngineIndex].DxpThread = nil) or
        TEngineDxpConnectionThread(FEngines[AEngineIndex].DxpThread).Listening then
        Break;
      CheckSynchronize(0);
      Sleep(25);
    end;

    if (FEngines[AEngineIndex].DxpThread <> nil) and
      TEngineDxpConnectionThread(FEngines[AEngineIndex].DxpThread).Listening then
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
      AppendEngineSlotLog(AEngineIndex, LogText);
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

  AppendEngineSlotLog(AEngineIndex, LogText);
end;

procedure TMainWindow.StopDxpConnection(AEngineIndex: Integer);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  if EngineSlotDxpConnectionActive(AEngineIndex) then
    AppendEngineSlotLog(AEngineIndex, '[stopping DXP connection]' +
      LineEnding);

  if FEngines[AEngineIndex].DxpThread <> nil then
  begin
    TEngineDxpConnectionThread(FEngines[AEngineIndex].DxpThread).StopConnection;
    FEngines[AEngineIndex].DxpThread.WaitFor;
    FreeAndNil(FEngines[AEngineIndex].DxpThread);
  end;

  CloseDxpSocket(AEngineIndex, '');
  SetDxpGameState(AEngineIndex, dgsIdle, 'DXP connection stopped');
end;

procedure TMainWindow.StartDxpGameForSlot(AEngineIndex: Integer;
  AEngineSide: TSide; AGameMinutes: Double);
begin
  if not EngineIsDxp(AEngineIndex) then
    Exit;
  SendDxpGameReqToEngine(AEngineIndex, AEngineSide, AGameMinutes);
end;

procedure TMainWindow.StartDxpPlayGameSessions(AGameMinutes: Double);
begin
  if FPlayGameWhiteIsEngine then
    StartDxpGameForSlot(FPlayGameWhiteEngineIndex, sideWhite, AGameMinutes);
  if FPlayGameBlackIsEngine and
    (FPlayGameBlackEngineIndex <> FPlayGameWhiteEngineIndex) then
    StartDxpGameForSlot(FPlayGameBlackEngineIndex, sideBlack, AGameMinutes);
end;

procedure TMainWindow.SendDxpGameReqToEngine(AEngineIndex: Integer;
  AEngineSide: TSide; AGameMinutes: Double);
var
  Gate: TEngineCommandGate;
  MessageText: String;
begin
  Gate := EngineSlotCanSendDxpPacket(AEngineIndex, 'DXP_GAMEREQ');
  BeginDxpGameRequest(AEngineIndex);

  if not EngineSlotIndexValid(AEngineIndex) then
  begin
    CancelDxpGameRequest(AEngineIndex);
    Exit;
  end;

  MessageText := BuildDxpGameReqCommand(FBoard, FSideToMove, AEngineSide,
    AGameMinutes, FEngines[AEngineIndex].Params);
  if MessageText = '' then
  begin
    CancelDxpGameRequest(AEngineIndex);
    Exit;
  end;

  AppendEngineSlotLog(AEngineIndex, '[Engine is a DXP follower]' + LineEnding);
  if not SendDxpPacketAfterGate(AEngineIndex, 'DXP_GAMEREQ', MessageText,
    Gate) then
  begin
    CancelDxpGameRequest(AEngineIndex);
    Exit;
  end;
  MarkDxpGameRequestSent(AEngineIndex);
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

  Result := DxpGameEndCodeForResult(FGameResult, EngineSide);
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

  Result := DxpResultFromGameEndCode(ACode, EngineSide);
end;

procedure TMainWindow.SendDxpGameEndToEngine(AEngineIndex: Integer; ACode: Char);
var
  Gate: TEngineCommandGate;
  MessageText: String;
begin
  Gate := EngineSlotCanSendDxpGameEnd(AEngineIndex);
  MessageText := BuildDxpGameEndCommand(ACode);
  if SendDxpPacketAfterGate(AEngineIndex, 'DXP_GAMEEND', MessageText,
    Gate) then
    MarkDxpGameEndSent(AEngineIndex);
end;

procedure TMainWindow.NotifyDxpPlayGameEnd(
  AExcludeEngineIndex: Integer);
begin
  if not FPlayGameActive then
  begin
    if EngineIsRunning and EngineIsDxp(1) then
      AppendEngineSlotLog(1, '[DXP_GAMEEND not sent: no active play game]' +
        LineEnding);
    if SecondEngineIsRunning and EngineIsDxp(2) then
      AppendEngineSlotLog(2, '[DXP_GAMEEND not sent: no active play game]' +
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

procedure TMainWindow.StopNonOriginSearchAfterGameEnd(
  AOriginEngineIndex: Integer);
begin
  if AOriginEngineIndex = 2 then
    SendStopToEngineSlot(1)
  else if SecondEngineIsRunning then
    SendStopToEngineSlot(2);
end;

procedure TMainWindow.HandleDxpGameEndReceived(AEngineIndex: Integer;
  ACode: Char);
var
  ResultText: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  if not DxpShouldAcceptGameEnd(AEngineIndex) then
  begin
    AppendEngineSlotLog(AEngineIndex, '[ignored late DXP_GAMEEND while state: ' +
      DxpGameStateText(FEngines[AEngineIndex].DxpGameState) + ']' +
      LineEnding);
    Exit;
  end;

  MarkDxpGameEndArrived(AEngineIndex);

  if (ACode <> #0) and (not FEngines[AEngineIndex].DxpGameEndSent) then
  begin
    SendDxpGameEndToEngine(AEngineIndex, ACode);
    SetDxpGameState(AEngineIndex, dgsWaitingForNextGame,
      'GAMEEND reply sent');
  end;

  if FPlayGameActive then
  begin
    if ACode <> #0 then
      ResultText := DxpResultFromGameEnd(AEngineIndex, ACode)
    else
      ResultText := '*';
    EndCurrentGame(gerDxpGameEnd, ResultText, AEngineIndex);
    StopNonOriginSearchAfterGameEnd(AEngineIndex);
  end;
  ClearEngineTiming(AEngineIndex);
end;

procedure TMainWindow.SendDxpMoveToEngine(AEngineIndex: Integer;
  const AMove: TMove; ATotalTimeUsedSeconds: Integer);
var
  Gate: TEngineCommandGate;
  MessageText: String;
begin
  Gate := EngineSlotCanSendDxpPacket(AEngineIndex, 'DXP_MOVE');

  MessageText := BuildDxpMoveCommand(AMove, ATotalTimeUsedSeconds);
  if SendDxpPacketAfterGate(AEngineIndex, 'DXP_MOVE', MessageText, Gate) then
  begin
    if FPlayGameActive and (CurrentPlayGameEngineIndex = AEngineIndex) then
      MarkDxpWaitingForReply(AEngineIndex, esmPlayGameThink,
        'MOVE sent; waiting for engine reply')
    else
      MarkDxpMoveSent(AEngineIndex);
  end;
end;

function TMainWindow.SendDxpPacketAfterGate(AEngineIndex: Integer;
  const APacketName, APacketText: String;
  const AGate: TEngineCommandGate): Boolean;
begin
  Result := False;
  if LogEngineGateFailure(AEngineIndex, AGate) then
    Exit;
  if APacketText = '' then
    Exit;
  Result := SendDxpPacketToEngine(AEngineIndex, APacketName, APacketText);
end;

function TMainWindow.SendDxpPacketToEngine(AEngineIndex: Integer;
  const APacketName, APacketText: String): Boolean;
begin
  Result := False;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  if (APacketText = '') or (not EngineSlotDxpSocketOpen(AEngineIndex)) then
    Exit;

  try
    FEngines[AEngineIndex].DxpSocket.WriteBuffer(APacketText[1],
      Length(APacketText));
    AppendEngineSlotLog(AEngineIndex, '> ' + APacketName + ' ' +
      Copy(APacketText, 1, Length(APacketText) - 1) + LineEnding);
    if SameText(APacketName, 'DXP_MOVE') or
      (SameText(APacketName, 'DXP_GAMEREQ') and FPlayGameActive and
      (CurrentPlayGameEngineIndex = AEngineIndex)) then
      StoreDxpTimingStart(AEngineIndex, APacketName + ' ' +
        Copy(APacketText, 1, Length(APacketText) - 1));
    Result := True;
  except
    on E: Exception do
    begin
      AppendEngineSlotLog(AEngineIndex, '[' + APacketName +
        ' not sent: DXP socket write failed: ' + E.Message + ']' +
        LineEnding);
      CloseDxpSocket(AEngineIndex, 'write failed');
    end;
  end;
end;

procedure TMainWindow.DxpConnectionMessage(AEngineIndex: Integer;
  const AMessage: String; AReceivedAtSeconds: Double);
begin
  ProcessDxpMessage(AEngineIndex, AMessage, AReceivedAtSeconds);
end;

procedure TMainWindow.DxpConnectionConnected(AEngineIndex: Integer;
  ASocket: TSocketStream; ARole: TEngineDxpRole; const AIpAddress: String;
  APort: Word; AConnectAttemptCount, AConnectElapsedMs: QWord);
var
  DetailText: String;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  FEngines[AEngineIndex].DxpSocket := ASocket;
  FEngines[AEngineIndex].Ready := True;

  DetailText := '';
  if (ARole = edrListener) and (AConnectAttemptCount > 0) then
    DetailText := ' after ' + IntToStr(AConnectAttemptCount) +
      ' attempt';
  if DetailText <> '' then
  begin
    if AConnectAttemptCount <> 1 then
      DetailText += 's';
    DetailText += ' in ' + FormatFloat('0.000', AConnectElapsedMs / 1000) +
      ' seconds';
  end;

  if ARole = edrClient then
    AppendEngineSlotLog(AEngineIndex,
      '[Connected to DXP socket peer]' + LineEnding)
  else
    AppendEngineSlotLog(AEngineIndex,
      '[Connected to DXP socket listener on IP ' + AIpAddress +
      ' and port ' + IntToStr(APort) + DetailText + ']' + LineEnding);
end;

procedure TMainWindow.DxpConnectionError(AEngineIndex: Integer;
  const AMessage: String);
begin
  AppendEngineSlotLog(AEngineIndex,
    '[DXP connection error: ' + AMessage + ']' + LineEnding);
end;

procedure TMainWindow.DxpConnectionAttemptFailed(AEngineIndex: Integer;
  const AIpAddress: String; APort: Word; const AMessage: String);
begin
  AppendEngineSlotLog(AEngineIndex,
    '[connect to DXP socket listener on IP ' + AIpAddress + ' and port ' +
    IntToStr(APort) + ' failed. ' + AMessage + ']' + LineEnding);
end;

procedure TMainWindow.ProcessDxpMessage(AEngineIndex: Integer;
  const AMessage: String; AReceivedAtSeconds: Double);
var
  Packet: TDxpReceivedPacket;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if AMessage = '' then
    Exit;

  AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
    '] < ' + AMessage + LineEnding);
  LogDxpTimingDiagnostic(AEngineIndex, AMessage, AReceivedAtSeconds);

  Packet := DispatchDxpMessage(AMessage);
  case Packet.Kind of
    drpGameAcc:
      HandleDxpGameAccPacket(AEngineIndex);
    drpMove:
      if Packet.MoveParseOk then
        HandleDxpMovePacket(AEngineIndex, Packet.MoveText, AReceivedAtSeconds)
      else
        AppendEngineSlotLog(AEngineIndex, '[could not parse DXP_MOVE]' +
          LineEnding);
    drpGameEnd:
      HandleDxpGameEndReceived(AEngineIndex, Packet.GameEndCode);
  end;
end;

procedure TMainWindow.HandleDxpGameAccPacket(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  if FEngines[AEngineIndex].DxpGameState <> dgsGameRequested then
  begin
    AppendEngineSlotLog(AEngineIndex, '[ignored unexpected DXP_GAMEACC while state: ' +
      DxpGameStateText(FEngines[AEngineIndex].DxpGameState) + ']' +
      LineEnding);
    Exit;
  end;

  AppendEngineSlotLog(AEngineIndex, '[DXP_GAMEACC accepted]' + LineEnding);
  MarkDxpWaitingForProtocolReply(AEngineIndex, 'GAMEACC accepted',
    '[Waiting for DXP_MOVE or DXP_GAMEEND]');
end;

procedure TMainWindow.HandleDxpMovePacket(AEngineIndex: Integer;
  const AMoveText: String; AReceivedAtSeconds: Double);
var
  SearchMode: TEngineSearchMode;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  SearchMode := FEngines[AEngineIndex].SearchMode;
  if not DxpShouldAcceptMove(AEngineIndex, SearchMode) then
  begin
    AppendEngineSlotLog(AEngineIndex, '[ignored late DXP_MOVE ' +
      AMoveText + ']' + LineEnding);
    Exit;
  end;

  FinishEngineSlotSearch(AEngineIndex);
  HandleEngineMoveForSearchMode(AEngineIndex, AMoveText, SearchMode,
    AReceivedAtSeconds);
end;

function TMainWindow.EngineSlotSupportsAutoPlay(AEngineIndex: Integer): Boolean;
begin
  Result := (AEngineIndex = 1) and EngineSlotIsRunning(AEngineIndex) and
    FEngines[AEngineIndex].Ready and (not EngineIsDxp(AEngineIndex));
end;

function TMainWindow.EngineSlotCommandUiAvailable(AEngineIndex: Integer): Boolean;
begin
  Result := EngineSlotIsRunning(AEngineIndex) and
    (FEngines[AEngineIndex].Ready or EngineIsDxp(AEngineIndex));
end;

procedure TMainWindow.UpdateEngineCommandButtons;
var
  AnyAvailable: Boolean;
begin
  AnyAvailable := EngineSlotCommandUiAvailable(1) or
    EngineSlotCommandUiAvailable(2);

  if FAutoPlayButton <> nil then
    FAutoPlayButton.Enabled := EngineSlotSupportsAutoPlay(1);
  if FGoButton <> nil then
    FGoButton.Enabled := AnyAvailable;
  if FMctsButton <> nil then
    FMctsButton.Enabled := AnyAvailable;
  if FStopButton <> nil then
    FStopButton.Enabled := EngineSlotIsRunning(1) or EngineSlotIsRunning(2);
end;

procedure TMainWindow.UpdateEngineSlotReadyUi(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  UpdateEngineCommandButtons;
  UpdateEngineStateLabels;
  UpdateEnginePopupMenuItems;
end;

procedure TMainWindow.UpdateEngineStateLabels;
begin
  if FEngines[1].StateLabel <> nil then
    FEngines[1].StateLabel.Caption := EngineStateCaption(FEngines[1].State);
  if FEngines[2].StateLabel <> nil then
    FEngines[2].StateLabel.Caption := EngineStateCaption(FEngines[2].State);
end;

procedure TMainWindow.SendEngineSlotParams(AEngineIndex: Integer);
var
  Command: String;
  I: Integer;
  ParamName: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  for I := 0 to High(FEngines[AEngineIndex].Params) do
  begin
    ParamName := FEngines[AEngineIndex].Params[I].Name;
    if not EngineParamShouldSendToHub(ParamName) then
      Continue;
    Command := 'set-param name=' + HubQuote(ParamName) +
      ' value=' + HubQuote(FEngines[AEngineIndex].Params[I].Value);
    LogEngineSlotCommandSent(AEngineIndex, Command);
    SendEngineSlotCommand(AEngineIndex, Command);
  end;
end;

procedure TMainWindow.EngineProcessReadData(Sender: TObject);
begin
  if Sender <> nil then ;
  ReadEngineSlotData(1);
end;

procedure TMainWindow.EngineProcessReadSecondEngineData;
begin
  ReadEngineSlotData(2);
end;

procedure TMainWindow.PlatformProcessData(Sender: TObject; const AText: String);
var
  EngineIndex: Integer;
begin
  if not (Sender is TPlatformProcess) then
    Exit;

  EngineIndex := TPlatformProcess(Sender).SlotIndex;
  if not EngineSlotIndexValid(EngineIndex) then
    Exit;

  if not FEngines[EngineIndex].FirstReadSeen then
  begin
    FEngines[EngineIndex].FirstReadSeen := True;
    AppendEngineSlotLog(EngineIndex, EngineFirstReadLogText(
      EngineLogName(EngineIndex), Length(AText)));
  end;

  AppendEngineSlotRawLog(EngineIndex,
    EngineOutputLogText(AText, EngineIndex));
  ProcessEngineSlotOutput(EngineIndex, AText);
end;

procedure TMainWindow.ReadEngineSlotData(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if FEngines[AEngineIndex].PlatformProcess <> nil then
    FEngines[AEngineIndex].PlatformProcess.ReadAvailable;
end;

procedure TMainWindow.EnginePollTimerTimer(Sender: TObject);
var
  I: Integer;
begin
  if Sender <> nil then ;

  if not AnyEngineSlotProcessHandlePresent then
  begin
    if FEnginePollTimer <> nil then
      FEnginePollTimer.Enabled := False;
    Exit;
  end;

  for I := 1 to 2 do
    PollEngineSlot(I);
end;

function TMainWindow.AnyEngineSlotProcessHandlePresent: Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to 2 do
    if EngineSlotProcessHandlePresent(I) then
      Exit(True);
end;

function TMainWindow.EngineSlotShouldReadInPoll(AEngineIndex: Integer): Boolean;
begin
  Result := False;
  if not EngineSlotProcessHandlePresent(AEngineIndex) then
    Exit;

  Result := (FEngines[AEngineIndex].PlatformProcess <> nil) and
    FEngines[AEngineIndex].PlatformProcess.NeedsPolling;
end;

procedure TMainWindow.PollEngineSlot(AEngineIndex: Integer);
begin
  if not EngineSlotProcessHandlePresent(AEngineIndex) then
    Exit;

  if not EngineSlotIsRunning(AEngineIndex) then
  begin
    HandleEngineProcessTerminated(AEngineIndex);
    Exit;
  end;

  if EngineSlotShouldReadInPoll(AEngineIndex) then
    ReadEngineSlotData(AEngineIndex);
end;

procedure TMainWindow.EngineProcessTerminate(Sender: TObject);
begin
  HandleEngineProcessTerminated(1);
end;

procedure TMainWindow.HandleEngineProcessTerminated(AEngineIndex: Integer);
begin
  if (AEngineIndex < 1) or (AEngineIndex > 2) then
    Exit;

  if not EngineSlotProcessHandlePresent(AEngineIndex) then
    Exit;

  DrainEngineSlotOutputAfterExit(AEngineIndex);
  ResetEngineRuntimeAfterProcessExit(AEngineIndex);
  LogEngineSlotProcessTerminated(AEngineIndex);
  CloseTerminatedEngineSlotProcess(AEngineIndex);
  RefreshEngineUiAfterSlotChange;
end;

function TMainWindow.EngineSlotProcessHandlePresent(
  AEngineIndex: Integer): Boolean;
begin
  Result := False;
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  Result := (FEngines[AEngineIndex].PlatformProcess <> nil) and
    FEngines[AEngineIndex].PlatformProcess.HasProcess;
end;

procedure TMainWindow.DrainEngineSlotOutputAfterExit(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if AEngineIndex = 1 then
    EngineProcessReadData(nil)
  else
    EngineProcessReadSecondEngineData;
end;

procedure TMainWindow.LogEngineSlotProcessTerminated(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  AppendEngineSlotLog(AEngineIndex,
    EngineProcessTerminatedLogText(EngineLogName(AEngineIndex)));
end;

procedure TMainWindow.CloseTerminatedEngineSlotProcess(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if FEngines[AEngineIndex].PlatformProcess <> nil then
    FEngines[AEngineIndex].PlatformProcess.Close;
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
  if (not ParseHubMoveNumbers(AEngineMove, Numbers, IsCapture)) or
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
  AEngineIndex: Integer; ADxpReceivedAtSeconds: Double): Boolean;
var
  Annotation: String;
  MoveIndex: Integer;
  MoveToPlay: TMove;
begin
  Result := False;
  MoveIndex := EngineMoveIndex(AEngineMove);
  if MoveIndex >= 0 then
  begin
    AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
      ' executing move ' + AEngineMove + ']' + LineEnding);
    if FPlayGameActive then
    begin
      if EngineIsDxp(AEngineIndex) then
        PauseGameClocksAt(ADxpReceivedAtSeconds)
      else
        PauseGameClocks
    end
    else
      UpdateGameClock;
    Annotation := FLastEngineInfoAnnotation;
    FLastEngineInfoAnnotation := '';
    FLastEngineInfoLine := '';
    CopyMove(FMoves[MoveIndex], MoveToPlay);
    ApplyMove(MoveToPlay);
    RecordPlayedMove(MoveToPlay, Annotation);
    LogPlayedMoveToEngineWindows(MoveToPlay, AEngineIndex);
    SysUtils.Beep;
    Exit(True);
  end;

  AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
    ' move is not legal here: ' + AEngineMove + ']' + LineEnding);
end;

procedure TMainWindow.HandleEngineDoneMove(const AMoveText: String);
var
  SearchMode: TEngineSearchMode;
begin
  SearchMode := FEngines[1].SearchMode;
  FinishEngineSlotSearch(1);
  case SearchMode of
  esmAutoPlay:
    HandleEngineMoveForSearchMode(1, AMoveText, SearchMode);
  esmPlayGameThink:
    HandleEngineMoveForSearchMode(1, AMoveText, SearchMode);
  esmAnalyze, esmPlayGameAnalyze:
  begin
    if AMoveText <> '' then
    begin
      UpdateAnalyzeBestMoveFromMoveText(AMoveText);
      AppendEngineSlotLog(1, '[analysis move ignored: ' + AMoveText + ']' + LineEnding)
    end
    else
      AppendEngineSlotLog(1, '[analysis done]' + LineEnding);
  end;
  esmMcts:
  begin
    if ExtractHubArgument(FLastEngineDoneLine, 'result') <> '' then
      AppendEngineSlotLog(1, '[mcts done: result=' +
        ExtractHubArgument(FLastEngineDoneLine, 'result') + ']' + LineEnding)
    else
      AppendEngineSlotLog(1, '[mcts done: nshootouts=' +
        ExtractHubArgument(FLastEngineDoneLine, 'nshootouts') + ' nwon=' +
        ExtractHubArgument(FLastEngineDoneLine, 'nwon') + ' ndraw=' +
        ExtractHubArgument(FLastEngineDoneLine, 'ndraw') + ' nlost=' +
        ExtractHubArgument(FLastEngineDoneLine, 'nlost') + ']' + LineEnding);
  end;
  else
    if (AMoveText <> '') and FAutoPlayActive and
      (EngineMoveIndex(AMoveText) >= 0) then
    begin
      AppendEngineSlotLog(1, '[recovering auto-play move in idle state]' + LineEnding);
      BeginEngineSlotSearch(1, esmAutoPlay, esThinking);
      HandleEngineDoneMove(AMoveText);
    end
    else if AMoveText <> '' then
      AppendEngineSlotLog(1, '[' + EngineLogName(1) + ' move ignored: ' + AMoveText + ']' + LineEnding)
    else
      AppendEngineSlotLog(1, '[' + EngineLogName(1) + ' done]' + LineEnding);
  end;
end;

procedure TMainWindow.ProcessEngineSlotOutput(AEngineIndex: Integer;
  const AText: String);
var
  Line: String;
  DelimiterLength: Integer;
  LineEnd: Integer;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if EngineIsDxp(AEngineIndex) then
  begin
    FEngines[AEngineIndex].TextBuffer := '';
    Exit;
  end;

  FEngines[AEngineIndex].TextBuffer += AText;

  while True do
  begin
    DelimiterLength := Length(LineEnding);
    LineEnd := Pos(LineEnding, FEngines[AEngineIndex].TextBuffer);
    if LineEnd = 0 then
    begin
      LineEnd := Pos(#10, FEngines[AEngineIndex].TextBuffer);
      DelimiterLength := 1;
    end;
    if LineEnd = 0 then
      Break;

    Line := Trim(Copy(FEngines[AEngineIndex].TextBuffer, 1, LineEnd - 1));
    Delete(FEngines[AEngineIndex].TextBuffer, 1,
      LineEnd + DelimiterLength - 1);

    DispatchEngineSlotReceivedLine(AEngineIndex, Line);
  end;
end;

procedure TMainWindow.DispatchEngineSlotReceivedLine(AEngineIndex: Integer;
  const ALine: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if ALine = 'wait' then
    HandleEngineSlotWaitLine(AEngineIndex)
  else if ALine = 'ready' then
    HandleEngineSlotReadyLine(AEngineIndex)
  else if StartsText('param ', ALine) then
    HandleEngineSlotParamLine(AEngineIndex, ALine)
  else if StartsText('id ', ALine) then
    HandleEngineSlotIdLine(AEngineIndex, ALine)
  else if StartsText('info ', ALine) then
    HandleEngineSlotInfoLine(AEngineIndex, ALine)
  else if StartsText('error ', ALine) then
    HandleEngineSlotErrorLine(AEngineIndex, ALine)
  else if StartsText('done ', ALine) or (ALine = 'done') then
    HandleEngineSlotDoneLine(AEngineIndex, ALine);
end;

procedure TMainWindow.GoButtonClick(Sender: TObject);
begin
  PrepareManualEngineCommand(True, True);
  AppendEngineSlotLog(1, '[manual Analyze: starting analysis]' + LineEnding);
  SetGuiState(gsAnalyzing, 'manual analyze');
  SendProtocolCommandToAllEngines(epcStop);
  SendProtocolCommandToAllEngines(epcAnalyze, esmAnalyze);
end;

procedure TMainWindow.MctsButtonClick(Sender: TObject);
begin
  PrepareManualEngineCommand(True, True);
  AppendEngineSlotLog(1, '[manual MCTS: starting mcts]' + LineEnding);
  SetGuiState(gsMcts, 'manual mcts');
  SendProtocolCommandToAllEngines(epcStop);
  SendProtocolCommandToAllEngines(epcMcts);
end;

procedure TMainWindow.AutoPlayButtonClick(Sender: TObject);
begin
  if not EngineIsRunning or (not FEngines[1].Ready) then
    Exit;
  if EngineIsDxp(1) then
  begin
    AppendEngineSlotLog(1, '[auto-play not supported for DXP engines]' + LineEnding);
    Exit;
  end;

  if FHistory.CurrentPly < Length(FHistory.Moves) then
  begin
    FHistory.TruncateToCurrentPly;
    UpdateHistoryList;
  end;
  UpdateHistoryList;
  if EngineStateNeedsStop(FEngines[1].State) then
  begin
    PrepareManualEngineCommand(False, True);
    FAutoPlayPlyCount := 0;
    RequestEngineSlotActionAfterStop(1, peaAutoPlay, esmIdle,
      'stopping previous search before auto-play');
    Exit;
  end;

  BeginAutoPlay;
end;

procedure TMainWindow.BeginAutoPlay;
begin
  ClearEngineSlotPendingAction(1);
  ClearEngineSlotPendingAction(2);
  FEngines[1].IgnoreNextDoneMove := False;
  LeavePlayGameMode;
  FAutoPlayActive := True;
  FAutoPlayPlyCount := 0;
  SetGuiState(gsAutoPlaying, 'auto-play started');
  AppendEngineSlotLog(1, '[auto-play started]' + LineEnding);
  if EngineIsDxp(1) then
  begin
    FAutoPlayActive := False;
    SetGuiState(gsIdle, 'auto-play not supported for DXP');
    AppendEngineSlotLog(1, '[auto-play not supported for DXP engines]' + LineEnding);
    Exit;
  end;
  SendProtocolCommandToEngineSlot(1, epcThink, esmAutoPlay);
end;

procedure TMainWindow.PrepareManualEngineCommand(AClearPendingActions,
  ALeavePlayGameMode: Boolean);
begin
  FAutoPlayActive := False;
  if AClearPendingActions then
  begin
    ClearEngineSlotPendingAction(1);
    ClearEngineSlotPendingAction(2);
  end;
  if ALeavePlayGameMode then
    LeavePlayGameMode;
end;

procedure TMainWindow.StorePendingPlayGameOptions(AWhiteIsEngine,
  ABlackIsEngine: Boolean; const AWhiteName, ABlackName: String;
  AGameMinutes: Double; AStartFromCurrent: Boolean; AWhiteEngineIndex,
  ABlackEngineIndex: Integer);
begin
  FPendingPlayGameWhiteIsEngine := AWhiteIsEngine;
  FPendingPlayGameBlackIsEngine := ABlackIsEngine;
  FPendingPlayGameWhiteName := AWhiteName;
  FPendingPlayGameBlackName := ABlackName;
  FPendingPlayGameMinutes := AGameMinutes;
  FPendingPlayGameFromCurrent := AStartFromCurrent;
  FPendingPlayGameWhiteEngineIndex := AWhiteEngineIndex;
  FPendingPlayGameBlackEngineIndex := ABlackEngineIndex;
end;

procedure TMainWindow.PendingActionForPlayGameStart(
  out AAction: TPendingEngineAction; out AMode: TEngineSearchMode);
begin
  AAction := peaNone;
  AMode := esmIdle;

  if IsPlayGameEngineTurn then
  begin
    AAction := peaThink;
    AMode := esmPlayGameThink;
    Exit;
  end;

  if FPlayGameWhiteIsEngine and FPlayGameBlackIsEngine then
    Exit;

  if (FPlayGameWhiteIsEngine or FPlayGameBlackIsEngine) and
    FEngineAnalyzeEnabled then
  begin
    AAction := peaAnalyze;
    AMode := esmPlayGameAnalyze;
    Exit;
  end;

  if FEngineAnalyzeEnabled then
  begin
    AAction := peaAnalyze;
    AMode := esmAnalyze;
  end;
end;

procedure TMainWindow.RequestPlayGameStartAfterEngine1Stop;
var
  PendingAction: TPendingEngineAction;
  PendingMode: TEngineSearchMode;
begin
  ClearEngineSlotPendingAction(1);
  PendingActionForPlayGameStart(PendingAction, PendingMode);
  FAutoPlayActive := False;

  if EngineStateNeedsStop(FEngines[2].State) then
    SendStopToEngineSlot(2);

  if PendingAction = peaNone then
  begin
    AppendEngineSlotLog(1, '[stopping previous search before starting game]' +
      LineEnding);
    SendStopToEngineSlot(1);
    Exit;
  end;

  RequestEngineSlotActionAfterStop(1, PendingAction, PendingMode,
    'stopping previous search before starting game');
end;

procedure TMainWindow.HandleEngine2StopBeforePlayGameStart;
begin
  FAutoPlayActive := False;
  if FPlayGameActive and IsPlayGameSecondEngineTurn then
    RequestEngineSlotActionAfterStop(2, peaThink, esmPlayGameThink,
      'stopping previous search before starting game')
  else
  begin
    AppendEngineSlotLog(2, '[stopping previous search before starting game]' +
      LineEnding);
    SendStopToEngineSlot(2);
    ContinuePlayGameSearch;
  end;
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
    HandleEngine2StopBeforePlayGameStart;
    Exit;
  end;
  if EngineStateNeedsStop(FEngines[1].State) then
  begin
    StorePendingPlayGameOptions(AWhiteIsEngine, ABlackIsEngine, AWhiteName,
      ABlackName, AGameMinutes, AStartFromCurrent, AWhiteEngineIndex,
      ABlackEngineIndex);
    BeginPlayGame(AWhiteIsEngine, ABlackIsEngine, AWhiteName, ABlackName,
      AGameMinutes,
      AStartFromCurrent, False, AWhiteEngineIndex, ABlackEngineIndex);
    RequestPlayGameStartAfterEngine1Stop;
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
  ClearEngineSlotPendingAction(1);
  FEngines[1].IgnoreNextDoneMove := False;
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
    ClearEngineSlotPendingAction(1);
    AppendEngineSlotLog(1, '[analysis disabled for engine-vs-engine game]' + LineEnding);
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
  FGameResultReason := '';
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
  AppendEngineSlotLog(1, '[play game started: white=' + FGameWhiteName + ', black=' +
    FGameBlackName + ', minutes=' + FormatFloat('0.###', AGameMinutes) + ']' +
    LineEnding);

  StartDxpPlayGameSessions(AGameMinutes);

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
  BlackEngineIndex: Integer;
  BlackName: String;
  StartFromCurrent: Boolean;
  WhiteIsEngine: Boolean;
  WhiteEngineIndex: Integer;
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
    begin
      WhiteName := FPlayGameWhitePlayerCombo.Text;
      WhiteEngineIndex := PtrInt(FPlayGameWhitePlayerCombo.Items.Objects[
        FPlayGameWhitePlayerCombo.ItemIndex]);
    end
    else
    begin
      WhiteName := 'Human';
      WhiteEngineIndex := 0;
    end;
    if BlackIsEngine then
    begin
      BlackName := FPlayGameBlackPlayerCombo.Text;
      BlackEngineIndex := PtrInt(FPlayGameBlackPlayerCombo.Items.Objects[
        FPlayGameBlackPlayerCombo.ItemIndex]);
    end
    else
    begin
      BlackName := 'Human';
      BlackEngineIndex := 0;
    end;
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
    WhiteEngineIndex := 0;
    BlackEngineIndex := 0;
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
      BlackName, GameMinutes, StartFromCurrent, WhiteEngineIndex,
      BlackEngineIndex);
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

  function PlayGameEngineLabel(AEngineIndex: Integer): String;
  begin
    Result := FEngines[AEngineIndex].DisplayName + ' (Engine ' +
      IntToStr(AEngineIndex) + ' ';
    if EngineIsDxp(AEngineIndex) then
      Result += 'DXP Mode)'
    else
      Result += 'Hub mode)';
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
    AppendEngineSlotLog(AEngineIndex, LogText);
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
  Dialog.ClientWidth := 420;
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
  FPlayGameWhitePlayerCombo.SetBounds(96, 14, 304, 28);
  FPlayGameWhitePlayerCombo.Style := csDropDownList;
  FPlayGameWhitePlayerCombo.Items.Add('Human');
  if EngineSlotAvailableForPlay(1) then
    FPlayGameWhitePlayerCombo.Items.AddObject(PlayGameEngineLabel(1),
      TObject(PtrInt(1)));
  if EngineSlotAvailableForPlay(2) then
    FPlayGameWhitePlayerCombo.Items.AddObject(PlayGameEngineLabel(2),
      TObject(PtrInt(2)));
  FPlayGameWhitePlayerCombo.ItemIndex := 0;

  BlackLabel := TLabel.Create(Dialog);
  BlackLabel.Parent := Dialog;
  BlackLabel.SetBounds(16, 52, 72, 24);
  BlackLabel.Layout := tlCenter;
  BlackLabel.Caption := 'Black:';

  FPlayGameBlackPlayerCombo := TComboBox.Create(Dialog);
  FPlayGameBlackPlayerCombo.Parent := Dialog;
  FPlayGameBlackPlayerCombo.SetBounds(96, 50, 304, 28);
  FPlayGameBlackPlayerCombo.Style := csDropDownList;
  FPlayGameBlackPlayerCombo.Items.Add('Human');
  if EngineSlotAvailableForPlay(1) then
    FPlayGameBlackPlayerCombo.Items.AddObject(PlayGameEngineLabel(1),
      TObject(PtrInt(1)));
  if EngineSlotAvailableForPlay(2) then
    FPlayGameBlackPlayerCombo.Items.AddObject(PlayGameEngineLabel(2),
      TObject(PtrInt(2)));
  FPlayGameBlackPlayerCombo.ItemIndex := 0;

  PositionLabel := TLabel.Create(Dialog);
  PositionLabel.Parent := Dialog;
  PositionLabel.SetBounds(16, 104, 120, 20);
  PositionLabel.Caption := 'Start from:';

  PositionGroup := TPanel.Create(Dialog);
  PositionGroup.Parent := Dialog;
  PositionGroup.SetBounds(16, 126, 388, 60);
  PositionGroup.BevelOuter := bvLowered;

  StandardPositionRadio := TRadioButton.Create(PositionGroup);
  StandardPositionRadio.Parent := PositionGroup;
  StandardPositionRadio.SetBounds(12, 6, 360, 24);
  StandardPositionRadio.Caption := 'Beginning';
  StandardPositionRadio.Checked := True;

  FPlayGameCurrentPositionRadio := TRadioButton.Create(PositionGroup);
  FPlayGameCurrentPositionRadio.Parent := PositionGroup;
  FPlayGameCurrentPositionRadio.SetBounds(12, 32, 360, 24);
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
  OKButton.SetBounds(242, 8, 80, 26);
  Dialog.DefaultControl := OKButton;

  CancelButton := TButton.Create(ButtonPanel);
  CancelButton.Parent := ButtonPanel;
  CancelButton.Caption := 'Cancel';
  CancelButton.ModalResult := mrCancel;
  CancelButton.OnClick := @PlayGameDialogButtonClick;
  CancelButton.SetBounds(328, 8, 80, 26);
  Dialog.CancelControl := CancelButton;

  FPlayGameDialog := Dialog;
  CenterDialogOnMainWindow(Dialog);
  Dialog.Show;
end;

procedure TMainWindow.StopButtonClick(Sender: TObject);
begin
  SetGuiState(gsStopping, 'manual stop');
  PrepareManualEngineCommand(True, False);
  if EngineIsRunning then
    AppendEngineSlotLog(1, '[manual STOP]' + LineEnding);
  if SecondEngineIsRunning then
    AppendEngineSlotLog(2, '[manual STOP]' + LineEnding);
  NotifyDxpPlayGameEnd;
  FinishPlayGameMode;
  SendProtocolCommandToAllEngines(epcStop);
end;

function TMainWindow.HubPositionString: String;
begin
  Result := HubPositionStringFor(FBoard, FSideToMove);
end;

function TMainWindow.HubPositionCommand(AEngineIndex: Integer): String;
begin
  Result := BuildHubPositionCommand(FHistory,
    EngineSendStartingPosition(AEngineIndex),
    EngineSingleCapturesIncludeCapturedSquare(AEngineIndex));
end;

function TMainWindow.CurrentEngineRemainingTimeSeconds: Double;
begin
  UpdateGameClock;

  if FPlayClock <> nil then
    Result := FPlayClock.SecondsForSide(FSideToMove)
  else
    Result := 0;

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
  if FHistory.CurrentPly <= 0 then
    LogText := '[DXP start position: ' + HubPositionString + ']'
  else
  begin
    LastMoveText := MoveToHubString(FHistory.Moves[FHistory.CurrentPly - 1],
      IncludeSingleCaptureSquare);
    LogText := '[DXP send move: ' + LastMoveText + ']';
  end;

  AppendEngineSlotLog(AEngineIndex, LogText + LineEnding +
    '[waiting for DXP answer]' + LineEnding);

  if (FHistory.CurrentPly <= 0) and
    (FEngines[AEngineIndex].DxpGameState = dgsGameRequested) then
  begin
    if AMode = esmPlayGameThink then
      ActivateGameClocks;
    BeginEngineSlotSearch(AEngineIndex, AMode, esThinking);
    Exit;
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

procedure TMainWindow.ContinueAutoPlayAfterPositionChange;
begin
  if not FAutoPlayActive then
    Exit;

  Inc(FAutoPlayPlyCount);

  if FAutoPlayPlyCount >= 255 then
  begin
    StopAutoPlayBecause(0, '255 moves reached');
    Exit;
  end;

  RequestOrSendThinkToEngineSlot(1, esmAutoPlay,
    'stopping previous search before auto-play');
end;

procedure TMainWindow.MarkPlayGameWaitingEngine(AActorEngineIndex: Integer);
begin
  if (AActorEngineIndex = 1) and IsPlayGameSecondEngineTurn then
    SetEngineSlotState(1, esWaitingForOtherEngine)
  else if (AActorEngineIndex = 2) and IsPlayGameEngineTurn and
    (not IsPlayGameSecondEngineTurn) then
    SetEngineSlotState(2, esWaitingForOtherEngine);
end;

procedure TMainWindow.ContinuePlayGameAfterPositionChange(
  AActorEngineIndex: Integer);
begin
  if not FPlayGameActive then
    Exit;

  MarkPlayGameWaitingEngine(AActorEngineIndex);
  ContinuePlayGameSearch;
end;

function TMainWindow.HandleTerminalPositionAfterFlowChange(
  AReason: TGameFlowReason): Boolean;
begin
  Result := Length(FMoves) = 0;
  if not Result then
    Exit;

  AppendEngineSlotLog(1, '[terminal position after ' + GameFlowReasonText(AReason) +
    ']' + LineEnding);
  EndCurrentGame(gerTerminalPosition);
end;

procedure TMainWindow.ContinueGameFlowAfterPositionChange(
  AReason: TGameFlowReason; AActorEngineIndex: Integer);
begin
  if CheckDrawByRepetition then
    Exit;
  if CheckDrawByTwentyFiveMoveRule then
    Exit;
  if HandleTerminalPositionAfterFlowChange(AReason) then
    Exit;

  case AReason of
    gfrAutoPlayMove:
      ContinueAutoPlayAfterPositionChange;
    gfrHumanMove, gfrEngineMove:
      ContinuePlayGameAfterPositionChange(AActorEngineIndex);
  end;
end;

procedure TMainWindow.HandleEngineMoveForSearchMode(AEngineIndex: Integer;
  const AMoveText: String; ASearchMode: TEngineSearchMode;
  ADxpReceivedAtSeconds: Double);
begin
  if not ApplyEngineMoveForSearchMode(AEngineIndex, AMoveText, ASearchMode,
    ADxpReceivedAtSeconds) then
  begin
    HandleFailedEngineMove(AEngineIndex, ASearchMode);
    ClearEngineTiming(AEngineIndex);
    Exit;
  end;

  ClearEngineTiming(AEngineIndex);
  ContinueAfterEngineMove(AEngineIndex, ASearchMode);
end;

function TMainWindow.ApplyEngineMoveForSearchMode(AEngineIndex: Integer;
  const AMoveText: String; ASearchMode: TEngineSearchMode;
  ADxpReceivedAtSeconds: Double): Boolean;
begin
  case ASearchMode of
    esmAutoPlay, esmPlayGameThink:
      Result := PlayEngineMove(AMoveText, AEngineIndex,
        ADxpReceivedAtSeconds);
  else
    Result := False;
  end;
end;

procedure TMainWindow.HandleFailedEngineMove(AEngineIndex: Integer;
  ASearchMode: TEngineSearchMode);
begin
  case ASearchMode of
    esmAutoPlay:
      StopAutoPlayBecause(AEngineIndex, EngineLogName(AEngineIndex) +
        ' move could not be played');
    esmPlayGameThink:
      StopPlayGameBecause(AEngineIndex, EngineLogName(AEngineIndex) +
        ' move could not be played');
  end;
end;

procedure TMainWindow.ContinueAfterEngineMove(AEngineIndex: Integer;
  ASearchMode: TEngineSearchMode);
begin
  case ASearchMode of
    esmAutoPlay:
      ContinueGameFlowAfterPositionChange(gfrAutoPlayMove, AEngineIndex);
    esmPlayGameThink:
      ContinueGameFlowAfterPositionChange(gfrEngineMove, AEngineIndex);
  end;
end;

function TMainWindow.CurrentPlayGameEngineIndex: Integer;
begin
  Result := 0;
  if not IsPlayGameEngineTurn then
    Exit;

  if (FSideToMove = sideWhite) and FPlayGameWhiteIsEngine then
    Result := FPlayGameWhiteEngineIndex
  else if (FSideToMove = sideBlack) and FPlayGameBlackIsEngine then
    Result := FPlayGameBlackEngineIndex;
end;

procedure TMainWindow.ContinuePlayGameSearch;
var
  EngineIndex: Integer;
begin
  if not FPlayGameActive then
    Exit;

  EngineIndex := CurrentPlayGameEngineIndex;
  if EngineIndex > 0 then
    ContinuePlayGameEngineTurn(EngineIndex)
  else
    ContinuePlayGameHumanTurn;
end;

procedure TMainWindow.ContinuePlayGameEngineTurn(AEngineIndex: Integer);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  SetGuiState(gsPlayGameEngineTurn, 'continue play-game search');

  if EngineIsDxp(AEngineIndex) and
    (FEngines[AEngineIndex].SearchMode = esmPlayGameThink) and
    (FEngines[AEngineIndex].DxpGameState = dgsWaitingForMoveOrGameEnd) then
  begin
    AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
      ' to move; already waiting for DXP answer]' + LineEnding);
    ActivateGameClocks;
    Exit;
  end;

  AppendEngineSlotLog(AEngineIndex, '[' + EngineLogName(AEngineIndex) +
    ' to move; starting think]' + LineEnding);

  if EngineIsDxp(AEngineIndex) then
    StartDxpPlayGameThink(AEngineIndex)
  else
    StartHubPlayGameThink(AEngineIndex);
end;

procedure TMainWindow.ContinuePlayGameHumanTurn;
begin
  SetGuiState(gsPlayGameHumanTurn, 'continue play-game search');
  ActivateGameClocks;

  if HasPlayGameEnginePlayer and HasPlayGameHumanPlayer then
  begin
    SendPlayGameHumanTurnAnalyze
  end
  else if HasPlayGameHumanPlayer and EngineIsRunning and FEngines[1].Ready then
  begin
    if EngineStateNeedsStop(FEngines[1].State) then
    begin
      RequestEngineSlotActionAfterStop(1, peaAnalyze, esmAnalyze,
        'stopping previous search before human-vs-human analysis');
    end
    else
      SendGoAnalyzeToEngine(esmAnalyze);
  end;
end;

procedure TMainWindow.StartDxpPlayGameThink(AEngineIndex: Integer);
begin
  SendDxpStartOrMoveToEngine(AEngineIndex, esmPlayGameThink);
  if (AEngineIndex = 2) and EngineStateNeedsStop(FEngines[1].State) then
    SendStopToEngineSlot(1);
end;

procedure TMainWindow.StartHubPlayGameThink(AEngineIndex: Integer);
begin
  if AEngineIndex = 2 then
    RequestOrSendThinkToEngineSlot(AEngineIndex, esmPlayGameThink,
      'synchronizing previous search before engine think')
  else
    RequestOrSendThinkToEngineSlot(AEngineIndex, esmPlayGameThink,
      'stopping previous search before engine think');

  if (AEngineIndex = 2) and EngineStateNeedsStop(FEngines[1].State) then
    SendStopToEngineSlot(1);
end;

function TMainWindow.EngineInfoAnnotation(const ALine: String): String;
begin
  Result := BuildEngineInfoAnnotation(ALine);
end;

function TMainWindow.HistoryAnnotationScoreWhite(APly: Integer;
  out AScore: Double): Boolean;
begin
  if (APly <= 0) or (APly > Length(FHistory.MoveAnnotations)) then
  begin
    AScore := 0.0;
    Exit(False);
  end;

  Result := TryAnnotationScoreWhite(FHistory.MoveAnnotations[APly - 1],
    EngineScorePerspective(1), FHistory.BaseSide, APly, AScore);
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

procedure TMainWindow.UpdateAnalyzeBestMoveFromInfo(AEngineIndex: Integer;
  const ALine: String);
var
  PvText: String;
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;
  if FEngines[AEngineIndex].SearchMode = esmIdle then
    Exit;

  PvText := ExtractHubArgument(ALine, 'pv');
  UpdateAnalyzePvFromMoveText(AEngineIndex, PvText);
end;

procedure TMainWindow.ShowAnalyzePvFromEngine(AEngineIndex: Integer);
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
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  ParseHubPvMoveText(FEngines[AEngineIndex].AnalyzePvText, FAnalyzePvMoves);
  FAnalyzePvHasBase := FEngines[AEngineIndex].AnalyzePvHasBase and
    (Length(FAnalyzePvMoves) > 0);
  if FAnalyzePvHasBase then
  begin
    FAnalyzePvBaseBoard := FEngines[AEngineIndex].AnalyzePvBaseBoard;
    FAnalyzePvBaseSide := FEngines[AEngineIndex].AnalyzePvBaseSide;
    FAnalyzePvBasePly := FEngines[AEngineIndex].AnalyzePvBasePly;
    FAnalyzePvBrowseBoard := FAnalyzePvBaseBoard;
    FAnalyzePvBrowseSide := FAnalyzePvBaseSide;
    FAnalyzePvBrowsePly := Length(FAnalyzePvMoves);
  end
  else
  begin
    FAnalyzePvBrowseBoard := FBoard;
    FAnalyzePvBrowseSide := FSideToMove;
    FAnalyzePvBrowsePly := 0;
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

  if FAnalyzePvHasBase then
    RebuildAnalyzePvPositionToPly(FAnalyzePvBrowsePly)
  else
  begin
    if FHistoryPvMiniBoardPaintBox <> nil then
      FHistoryPvMiniBoardPaintBox.Invalidate;
    if FAnalysisBoardPaintBox <> nil then
      FAnalysisBoardPaintBox.Invalidate;
  end;
  UpdateAnalyzePvList;
  UpdateAnalyzeBestMoveFromMoveText(FEngines[AEngineIndex].AnalyzePvText);
end;

procedure TMainWindow.UpdateAnalyzePvFromMoveText(AEngineIndex: Integer;
  const APvText: String);
begin
  if (AEngineIndex < Low(FEngines)) or (AEngineIndex > High(FEngines)) then
    Exit;

  FEngines[AEngineIndex].AnalyzePvText := APvText;
  FEngines[AEngineIndex].AnalyzePvBaseBoard := FBoard;
  FEngines[AEngineIndex].AnalyzePvBaseSide := FSideToMove;
  FEngines[AEngineIndex].AnalyzePvBasePly := FHistory.CurrentPly;
  FEngines[AEngineIndex].AnalyzePvHasBase := Trim(APvText) <> '';

  if (AEngineIndex = FSelectedPvEngineIndex) and (not FAnalyzePvLocked) then
    ShowAnalyzePvFromEngine(AEngineIndex);
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
  begin
    if FAnalyzeBestSourceSquare <> 0 then
    begin
      OldSourceSquare := FAnalyzeBestSourceSquare;
      FAnalyzeBestSourceSquare := 0;
      InvalidateBoardSquare(OldSourceSquare);
    end;
    Exit;
  end;
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
    if FHistory.BaseSide = sideWhite then
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
    BasePly := FHistory.CurrentPly;
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
begin
  Result := FHistory.BuildPdnMoveText(AResult, AStoreRanges);
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
  SavedPly := FHistory.CurrentPly;
  SavedMoves := FMoves;
  try
    RebuildPositionToPly(Length(FHistory.Moves));
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
    FHistory.CurrentPly := SavedPly;
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
  AppendEngineSlotLog(1, '[copied FEN ' + Fen + ']' + LineEnding);
end;

procedure TMainWindow.PasteFenMenuItemClick(Sender: TObject);
var
  Fen: String;
begin
  Fen := Trim(Clipboard.AsText);
  if Fen = '' then
  begin
    ShowGuiOkDialog(Self, 'Paste Position',
      'The clipboard does not contain a FEN string.');
    Exit;
  end;

  try
    ParseFen(Fen);
    FGameWhiteName := 'Human';
    FGameBlackName := 'Human';
    FGameResult := '*';
    FGameResultReason := '';
    LeavePlayGameMode;
    ResetHistoryFromCurrentPosition;
    FGameDirty := True;
    UpdateMoveList;
    UpdateHistoryList;
    Caption := 'International Draughts';
    InvalidateBoard;
    AppendEngineSlotLog(1, '[pasted FEN ' + Fen + ']' + LineEnding);
    RestartEngineAnalyze;
  except
    on E: Exception do
      ShowGuiOkDialog(Self, 'Paste Position', E.Message);
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
        ShowGuiOkDialog(Self, 'Open FEN', E.Message);
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
        ShowGuiOkDialog(Self, 'Open PDN', E.Message);
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

  if (FTournamentDialog <> nil) and (not FTournamentDialog.ConfirmClose) then
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
  SendStopToAllEngines;
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
    AppendEngineSlotLog(1, '[send position not supported for DXP engines]' + LineEnding);
    Exit;
  end;
  if Length(FMoves) = 0 then
  begin
    AppendEngineSlotLog(1, '[not sending terminal position]' + LineEnding);
    Exit;
  end;

  Command := HubPositionCommand(1);
  LogEngineSlotCommandSent(1, Command);
  SendEngineSlotCommand(1, Command);
end;

procedure TMainWindow.SendPlayGameHumanTurnAnalyze;
var
  I: Integer;
  Slots: TIntegerArray;
begin
  if not FPlayGameActive then
    Exit;
  if not (HasPlayGameEnginePlayer and HasPlayGameHumanPlayer) then
    Exit;
  if Length(FMoves) = 0 then
  begin
    EndGameIfTerminalPosition;
    Exit;
  end;

  ActivateGameClocks;
  ClearAnalyzeBoardHighlights;
  Slots := ReadyEngineSlotsForSearch;
  for I := 0 to High(Slots) do
    RequestOrSendAnalyzeToEngineSlot(Slots[I], esmPlayGameAnalyze,
      'stopping previous search before play-game analysis');
end;

function TMainWindow.CanStartHubSearch(AEngineIndex: Integer;
  AGoCommand: THubGoCommand; ARequireMctsSupport: Boolean): Boolean;
var
  Gate: TEngineCommandGate;
begin
  Gate := EngineSlotCanStartHubSearch(AEngineIndex, HubGoCommandText(AGoCommand),
    ARequireMctsSupport);
  Result := Gate.Allowed;
  if not Result then
    LogEngineGateFailure(AEngineIndex, Gate);
end;

function TMainWindow.EngineSlotReadyForSearch(AEngineIndex: Integer): Boolean;
begin
  Result := EngineSlotIndexValid(AEngineIndex) and
    EngineSlotCanReceiveCommand(AEngineIndex, True).Allowed;
end;

function TMainWindow.ReadyEngineSlotsForSearch: TIntegerArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, 0);
  for I := EngineFirstSlot to EngineLastSlot do
    if EngineSlotIndexValid(I) and EngineSlotIsRunning(I) and
      FEngines[I].Ready then
      AddEngineSlot(Result, I);
end;

procedure TMainWindow.AppendEngineSlotLogs(const ASlots: TIntegerArray;
  const AText: String);
var
  I: Integer;
begin
  for I := 0 to High(ASlots) do
    AppendEngineSlotLog(ASlots[I], AText);
end;

procedure TMainWindow.HandleTerminalSearchPositions(
  const ASlots: TIntegerArray; const APreparation: TEngineSearchPreparation);
var
  I: Integer;
begin
  for I := 0 to High(ASlots) do
    HandleTerminalSearchPosition(ASlots[I], APreparation.TerminalAutoPlay,
      APreparation.SendTerminalToEngine);
end;

function TMainWindow.HandleEngineSlotTerminalSearchPosition(
  AEngineIndex: Integer; AAutoPlay, ASendTerminalToEngine: Boolean): Boolean;
begin
  Result := Length(FMoves) = 0;
  if Result then
    HandleTerminalSearchPosition(AEngineIndex, AAutoPlay, ASendTerminalToEngine);
end;

procedure TMainWindow.StartHubEngineSlotSearch(AEngineIndex: Integer;
  ALevelCommand: THubLevelCommand; AGoCommand: THubGoCommand;
  AMode: TEngineSearchMode; AState: TEngineState;
  ARequireMctsSupport: Boolean);
begin
  if not CanStartHubSearch(AEngineIndex, AGoCommand, ARequireMctsSupport) then
    Exit;
  SendHubSearchToEngine(AEngineIndex, ALevelCommand, AGoCommand, AMode,
    AState);
end;

procedure TMainWindow.SendHubSearchToEngine(AEngineIndex: Integer;
  ALevelCommand: THubLevelCommand; AGoCommand: THubGoCommand;
  AMode: TEngineSearchMode; AState: TEngineState);
var
  SearchCommand: THubSearchCommand;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  SearchCommand := BuildHubSearchCommand(FHistory,
    EngineSendStartingPosition(AEngineIndex),
    EngineSingleCapturesIncludeCapturedSquare(AEngineIndex), ALevelCommand,
    FEngineMoveTimeSpin.Value, CurrentEngineRemainingTimeSeconds, AGoCommand);
  LogEngineSlotCommandSent(AEngineIndex, SearchCommand.PositionCommand);
  SendEngineSlotCommand(AEngineIndex, SearchCommand.PositionCommand);
  LogEngineSlotCommandSent(AEngineIndex, SearchCommand.LevelCommand);
  SendEngineSlotCommand(AEngineIndex, SearchCommand.LevelCommand);
  LogEngineSlotCommandSent(AEngineIndex, SearchCommand.GoCommand);
  SendEngineSlotCommand(AEngineIndex, SearchCommand.GoCommand);
  if (AGoCommand = hgcThink) and (AMode = esmPlayGameThink) then
    StoreEngineTimingStart(AEngineIndex, SearchCommand.GoCommand);
  BeginEngineSlotSearch(AEngineIndex, AMode, AState);
  if AMode = esmPlayGameThink then
    ActivateGameClocks;
end;

procedure TMainWindow.SendGoAnalyzeToEngine(AMode: TEngineSearchMode);
var
  Preparation: TEngineSearchPreparation;
  Slots: TIntegerArray;
begin
  Slots := ReadyEngineSlotsForSearch;
  Preparation := EngineSearchPreparation(esiAnalyze, AMode);
  if Preparation.ClearAnalyzeHighlights then
    ClearAnalyzeBoardHighlights;
  if Length(Slots) = 0 then
    Exit;
  if FPlayGameActive and IsPlayGameEngineTurn then
  begin
    AppendEngineSlotLogs(Slots,
      '[not starting analysis: engine to move]' + LineEnding);
    Exit;
  end;
  if not FEngineAnalyzeEnabled then
  begin
    AppendEngineSlotLogs(Slots,
      '[analysis disabled: not starting analysis]' + LineEnding);
    Exit;
  end;

  if Length(FMoves) = 0 then
  begin
    HandleTerminalSearchPositions(Slots, Preparation);
    Exit;
  end;

  if Preparation.ClearAnalysisDisplay then
    ClearSearchAnalysisDisplay;

  SendProtocolCommandToEngineSlots(Slots, epcAnalyze, AMode);
end;

procedure TMainWindow.SendGoAnalyzeToEngineSlot(AEngineIndex: Integer;
  AMode: TEngineSearchMode);
var
  Decision: TEngineAnalyzeDecision;
  Preparation: TEngineSearchPreparation;
begin
  if not EngineSlotReadyForSearch(AEngineIndex) then
    Exit;
  if FPlayGameActive and IsPlayGameEngineTurn then
  begin
    AppendEngineSlotLog(AEngineIndex,
      '[not starting analysis: engine to move]' + LineEnding);
    Exit;
  end;
  if not FEngineAnalyzeEnabled then
  begin
    AppendEngineSlotLog(AEngineIndex,
      '[analysis disabled: not starting analysis]' + LineEnding);
    Exit;
  end;
  Preparation := EngineSearchPreparation(esiAnalyze, AMode);
  if HandleEngineSlotTerminalSearchPosition(AEngineIndex,
    Preparation.TerminalAutoPlay, Preparation.SendTerminalToEngine) then
    Exit;

  Decision := DecideEngineAnalyze(FEngines[AEngineIndex].Protocol);
  if Decision.LogText <> '' then
    AppendEngineSlotLog(AEngineIndex, Decision.LogText);
  case Decision.Route of
    earHubAnalyze:
      StartHubEngineSlotSearch(AEngineIndex, Decision.HubLevelCommand,
        hgcAnalyze, AMode, esAnalyzing, False);
    earUnsupported:
      Exit;
  end;
end;

procedure TMainWindow.RequestOrSendAnalyzeToEngineSlot(AEngineIndex: Integer;
  AMode: TEngineSearchMode; const AStopReason: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if EngineStateNeedsStop(FEngines[AEngineIndex].State) then
    RequestEngineSlotActionAfterStop(AEngineIndex, peaAnalyze, AMode,
      AStopReason)
  else
    SendGoAnalyzeToEngineSlot(AEngineIndex, AMode);
end;

procedure TMainWindow.SendGoMctsToEngine;
var
  Preparation: TEngineSearchPreparation;
  Slots: TIntegerArray;
begin
  Slots := ReadyEngineSlotsForSearch;
  Preparation := EngineSearchPreparation(esiMcts, esmMcts);
  if Length(Slots) = 0 then
    Exit;

  if Length(FMoves) = 0 then
  begin
    HandleTerminalSearchPositions(Slots, Preparation);
    Exit;
  end;

  if Preparation.ClearAnalysisDisplay then
    ClearSearchAnalysisDisplay;

  SendProtocolCommandToEngineSlots(Slots, epcMcts);
end;

procedure TMainWindow.SendGoMctsToEngineSlot(AEngineIndex: Integer);
var
  Decision: TEngineMctsDecision;
  Preparation: TEngineSearchPreparation;
begin
  if not EngineSlotReadyForSearch(AEngineIndex) then
    Exit;
  Preparation := EngineSearchPreparation(esiMcts, esmMcts);
  if HandleEngineSlotTerminalSearchPosition(AEngineIndex,
    Preparation.TerminalAutoPlay, Preparation.SendTerminalToEngine) then
    Exit;

  Decision := DecideEngineMcts(FEngines[AEngineIndex].Protocol,
    EngineSupportsMcts(AEngineIndex), EngineLogName(AEngineIndex));
  if Decision.LogText <> '' then
    AppendEngineSlotLog(AEngineIndex, Decision.LogText);
  case Decision.Route of
    emrHubMcts:
      StartHubEngineSlotSearch(AEngineIndex, Decision.HubLevelCommand,
        hgcMcts, esmMcts, esMcts, True);
    emrUnsupported:
      Exit;
  end;
end;

procedure TMainWindow.SendGoThinkToEngineSlot(AEngineIndex: Integer;
  AMode: TEngineSearchMode);
var
  Decision: TEngineThinkDecision;
  Preparation: TEngineSearchPreparation;
begin
  if not EngineSlotReadyForSearch(AEngineIndex) then
    Exit;

  Decision := DecideEngineThink(FEngines[AEngineIndex].Protocol, AMode);
  if Decision.LogText <> '' then
    AppendEngineSlotLog(AEngineIndex, Decision.LogText);
  case Decision.Route of
    etrDxpThink:
    begin
      SendDxpStartOrMoveToEngine(AEngineIndex, AMode);
      Exit;
    end;
    etrUnsupported:
      Exit;
  end;

  Preparation := EngineSearchPreparation(esiThink, AMode);
  if HandleEngineSlotTerminalSearchPosition(AEngineIndex,
    Preparation.TerminalAutoPlay, Preparation.SendTerminalToEngine) then
    Exit;

  if Preparation.ClearAnalysisDisplay then
    ClearSearchAnalysisDisplay;
  FEngines[AEngineIndex].IgnoreNextDoneMove := False;
  StartHubEngineSlotSearch(AEngineIndex, Decision.HubLevelCommand, hgcThink,
    AMode, esThinking, False);
end;

procedure TMainWindow.RequestOrSendThinkToEngineSlot(AEngineIndex: Integer;
  AMode: TEngineSearchMode; const AStopReason: String);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if EngineStateNeedsStop(FEngines[AEngineIndex].State) then
    RequestEngineSlotActionAfterStop(AEngineIndex, peaThink, AMode,
      AStopReason)
  else
    SendGoThinkToEngineSlot(AEngineIndex, AMode);
end;

procedure TMainWindow.SendProtocolCommandToEngineSlot(AEngineIndex: Integer;
  ACommand: TEngineProtocolCommand; AMode: TEngineSearchMode);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  case EngineSlotCommandAction(ACommand) of
    escaStop:
      SendStopToEngineSlot(AEngineIndex);
    escaAnalyze:
      SendGoAnalyzeToEngineSlot(AEngineIndex, AMode);
    escaMcts:
      SendGoMctsToEngineSlot(AEngineIndex);
    escaThink:
      SendGoThinkToEngineSlot(AEngineIndex, AMode);
  end;
end;

procedure TMainWindow.SendProtocolCommandToEngineSlots(
  const ASlots: TIntegerArray; ACommand: TEngineProtocolCommand;
  AMode: TEngineSearchMode);
var
  I: Integer;
begin
  for I := 0 to High(ASlots) do
    SendProtocolCommandToEngineSlot(ASlots[I], ACommand, AMode);
end;

procedure TMainWindow.SendProtocolCommandToAllEngines(
  ACommand: TEngineProtocolCommand; AMode: TEngineSearchMode);
begin
  case EngineAllCommandTarget(ACommand) of
    eactReverseSlots:
      SendProtocolCommandToEngineSlots(EngineReverseSlots, ACommand, AMode);
    eactAnalyzeReadySlots:
      SendGoAnalyzeToEngine(AMode);
    eactMctsReadySlots:
      SendGoMctsToEngine;
    eactPrimaryThinkSlot:
      SendProtocolCommandToEngineSlots(EnginePrimarySlots, ACommand, AMode);
  end;
end;

procedure TMainWindow.RestartEngineAnalyze;
var
  I: Integer;
  Slots: TIntegerArray;
begin
  if not FEngineAnalyzeEnabled then
    Exit;
  if (not (EngineIsRunning and FEngines[1].Ready)) and
    (not (SecondEngineIsRunning and FEngines[2].Ready)) then
    Exit;
  if FAutoPlayActive or FPlayGameActive then
    Exit;

  Slots := ReadyEngineSlotsForSearch;
  ClearAnalyzeBoardHighlights;
  for I := 0 to High(Slots) do
    RequestOrSendAnalyzeToEngineSlot(Slots[I], esmAnalyze,
      'stopping previous search before analysis');
end;

procedure TMainWindow.SendStopToAllEngines;
begin
  SendStopToEngineSlot(2);
  SendStopToEngineSlot(1);
end;

procedure TMainWindow.SendStopToEngineSlot(AEngineIndex: Integer);
var
  PreviousState: TEngineState;
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  if not EngineSlotCanReceiveCommand(AEngineIndex, False).Allowed then
    Exit;

  PreviousState := FEngines[AEngineIndex].State;
  if EngineIsDxp(AEngineIndex) then
    StopDxpEngineSlot(AEngineIndex, PreviousState)
  else
    StopHubEngineSlot(AEngineIndex, PreviousState);
end;

procedure TMainWindow.ClearEngineSlotStopState(AEngineIndex: Integer;
  APreviousState: TEngineState; AStoppedByHubCommand: Boolean);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;
  FEngines[AEngineIndex].FinishSearch;
  FEngines[AEngineIndex].IgnoreNextDoneMove :=
    AStoppedByHubCommand and EngineStateNeedsStop(APreviousState);
end;

procedure TMainWindow.LogEngineSlotStopTransition(AEngineIndex: Integer;
  APreviousState: TEngineState);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if APreviousState <> esIdle then
  begin
    UpdateEngineStateLabels;
    AppendEngineSlotLog(AEngineIndex,
      EngineStopTransitionLogText(EngineLogName(AEngineIndex),
        EngineStateLogText(APreviousState, PlayerNameToMove)));
  end
  else if AEngineIndex = 1 then
    SetEngineSlotState(1, esIdle)
  else
    SetEngineSlotState(2, esIdle);
end;

procedure TMainWindow.StopDxpEngineSlot(AEngineIndex: Integer;
  APreviousState: TEngineState);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  if FPlayGameActive then
    SendDxpGameEndToEngine(AEngineIndex,
      DxpGameEndCodeForEngine(AEngineIndex));
  ClearEngineSlotStopState(AEngineIndex, APreviousState, False);
  LogEngineSlotStopTransition(AEngineIndex, APreviousState);
  UpdateEngineStateLabels;
end;

procedure TMainWindow.StopHubEngineSlot(AEngineIndex: Integer;
  APreviousState: TEngineState);
begin
  if not EngineSlotIndexValid(AEngineIndex) then
    Exit;

  LogEngineSlotCommandSent(AEngineIndex, 'stop');
  AppendEngineSlotLog(AEngineIndex,
    EngineStopRequestedLogText(EngineLogName(AEngineIndex),
      EngineStateLogText(APreviousState, PlayerNameToMove)));
  ClearEngineSlotStopState(AEngineIndex, APreviousState, True);
  LogEngineSlotStopTransition(AEngineIndex, APreviousState);
  SendEngineSlotCommand(AEngineIndex, 'stop');
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
  FGameResultReason := '';
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
var
  EngineIndex: Integer;
begin
  EngineIndex := EngineSlotIndexFromSender(Sender);
  if (FSaveEngineLogDialog = nil) or
    (FEngines[EngineIndex].LogMemo = nil) then
    Exit;

  if FSaveEngineLogDialog.Execute then
  begin
    SaveEngineLogMemoToFile(FEngines[EngineIndex].LogMemo,
      FSaveEngineLogDialog.FileName);
    AppendEngineSlotLog(EngineIndex, '[saved engine log ' +
      FSaveEngineLogDialog.FileName + ']' + LineEnding);
  end;
end;

procedure TMainWindow.UpdateAnalyzeMenuItems;
var
  DisableAnalyzeToggle: Boolean;
begin
  DisableAnalyzeToggle := FPlayGameActive and FPlayGameWhiteIsEngine and
    FPlayGameBlackIsEngine;
  UpdateEngineLogAnalyzeMenuItem(FEngines[1], FEngineAnalyzeEnabled,
    not DisableAnalyzeToggle);
  UpdateEngineLogAnalyzeMenuItem(FEngines[2], FEngineAnalyzeEnabled,
    not DisableAnalyzeToggle);
  UpdateEnginePopupMenuItems;
end;

procedure TMainWindow.UpdateEnginePopupMenuItems;
var
  Engine1Loaded: Boolean;
  Engine2Loaded: Boolean;
begin
  Engine1Loaded := EngineIsRunning;
  Engine2Loaded := SecondEngineIsRunning;

  UpdateEngineLogPopupMenuItems(FEngines[1], Engine1Loaded);
  UpdateEngineLogPopupMenuItems(FEngines[2], Engine2Loaded);
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
    AppendEngineSlotLog(1, '[analysis enabled]' + LineEnding);
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
    AppendEngineSlotLog(1, '[analysis disabled]' + LineEnding);
    ClearEngineSlotPendingAction(1);
    ClearEngineSlotPendingAction(2);
    if (FEngines[1].State = esAnalyzing) or (FEngines[2].State = esAnalyzing) then
      SendStopToAllEngines;
  end;
end;

procedure TMainWindow.ShowTimestampsMenuItemClick(Sender: TObject);
begin
  FEngineLogShowTimestamps := not FEngineLogShowTimestamps;
  UpdateEngineLogTimestampMenuItem(FEngines[1], FEngineLogShowTimestamps);
  UpdateEngineLogTimestampMenuItem(FEngines[2], FEngineLogShowTimestamps);
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
    Lines.Add('[FEN "' + BoardToFen(FHistory.BaseBoard, FHistory.BaseSide) + '"]');
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
    AppendEngineSlotLog(1, '[saved PDN ' + AFileName + ']' + LineEnding);
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
  FGameResultReason := '';
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
    FGameResultReason := '';
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
    FGameResultReason := '';

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
  Board: TBoard;
  Side: TSide;
begin
  ParseFenToBoard(AFen, Board, Side);
  FBoard := Board;
  FSideToMove := Side;
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
  FHistoryFenMemo.Text := BoardToFen(FHistory.BaseBoard, FHistory.BaseSide);
  FHistoryMemo.Text := BuildPdnMoveText(FGameResult, True);
  if FHistoryEvalPaintBox <> nil then
    FHistoryEvalPaintBox.Invalidate;

  SelectHistoryPly(FHistory.CurrentPly);
  FHistoryMemo.Invalidate;
  FHistoryMemo.Update;
end;

procedure TMainWindow.UpdateMoveList;
var
  I: Integer;
begin
  ClearBoardSelection;
  GenerateLegalMoves(FBoard, FSideToMove, FMoves);
  ClearAnalyzePvForAllEngines;
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
