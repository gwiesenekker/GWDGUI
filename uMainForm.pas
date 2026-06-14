unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, Clipbrd, ComCtrls, Controls, Dialogs, ExtCtrls, Forms, Graphics,
  LCLType, Grids, Menus, StdCtrls, SysUtils, Types, uBoardControl,
  uDraughtsBoard, uEnginesDialog,
  uGameOrchestrator, uGameRunnerThread, uGameSetupForm,
  uEngineParamsJson, uEngineRegistry, uPdn, uPdnOpenDialog, uThreadMessageQueue,
  uTournamentDialog, uPvBrowser, uPvSnapshot, uAnalyzerRunnerThread,
  uGuiDialogs, uDatabaseForm, uGameTree, uGameTreeActor, uGameTreeBuilder,
  uGameTreePdn, uGameTreeSearchRef, uGameTreeView, uPositionSetupForm,
  uPreferences, uPreferencesForm, uScoreHistoryControl, uScoreHistoryForm;

type
  TIntArray = array of Integer;
  TPvHintSource = (phsMain, phsAnalyzer);
  TMoveVariationHit = record
    Start: Integer;
    Length: Integer;
    VariationIndex: Integer;
    VariationPly: Integer;
  end;
  TMoveVariationHitArray = array of TMoveVariationHit;

  TRunnerSnapshotGuiMessage = class(TThreadMessage)
  private
    FGameId: Integer;
    FSnapshot: TGameRunnerSnapshot;
  public
    constructor Create(AGameId: Integer; ASnapshot: TGameRunnerSnapshot);
      reintroduce;
    destructor Destroy; override;
    property GameId: Integer read FGameId;
    property Snapshot: TGameRunnerSnapshot read FSnapshot;
  end;

  TRunnerFinishedGuiMessage = class(TThreadMessage)
  private
    FGameId: Integer;
  public
    constructor Create(AGameId: Integer); reintroduce;
    property GameId: Integer read FGameId;
  end;

  TAnalyzerLogGuiMessage = class(TThreadMessage)
  private
    FMessage: string;
  public
    constructor Create(const AMessage: string); reintroduce;
    property Message: string read FMessage;
  end;

  TAnalyzerSnapshotGuiMessage = class(TThreadMessage)
  private
    FSnapshot: TPvSnapshot;
  public
    constructor Create(ASnapshot: TPvSnapshot); reintroduce;
    destructor Destroy; override;
    property Snapshot: TPvSnapshot read FSnapshot;
  end;

  TAnalyzerMoveGuiMessage = class(TThreadMessage)
  private
    FMoveText: string;
    FSearch: TGameTreeSearchRef;
  public
    constructor Create(const ASearch: TGameTreeSearchRef;
      const AMoveText: string); reintroduce;
    property MoveText: string read FMoveText;
    property Search: TGameTreeSearchRef read FSearch;
  end;

  TAnalyzerFinishedGuiMessage = class(TThreadMessage)
  private
    FRunner: TAnalyzerRunnerThread;
  public
    constructor Create(ARunner: TAnalyzerRunnerThread); reintroduce;
    property Runner: TAnalyzerRunnerThread read FRunner;
  end;

  TMctsLogGuiMessage = class(TThreadMessage)
  private
    FMessage: string;
  public
    constructor Create(const AMessage: string); reintroduce;
    property Message: string read FMessage;
  end;

  TMctsFinishedGuiMessage = class(TThreadMessage)
  private
    FRunner: TAnalyzerRunnerThread;
  public
    constructor Create(ARunner: TAnalyzerRunnerThread); reintroduce;
    property Runner: TAnalyzerRunnerThread read FRunner;
  end;

  TRunningGameLifecycle = (
    rglStarting,
    rglRunning,
    rglStopRequested,
    rglRemoveRequested,
    rglFinished
  );

  TRunningGame = class
  private
    FId: Integer;
    FBlackEngineKey: string;
    FBlackPlayerKind: TPlayerKind;
    FGameTreeActor: TGameTreeActor;
    FGameTree: TGameTree;
    FPaused: Boolean;
    FReservationKeys: TStringList;
    FReleasingRunner: Boolean;
    FRunner: TGameRunnerThread;
    FLifecycle: TRunningGameLifecycle;
    FShowStdout: Boolean;
    FSnapshot: TGameRunnerSnapshot;
    FLastSnapshotTreePvSignature: string;
    FLastSnapshotTreeSyncSignature: string;
    FListCaption: string;
    FStopReason: string;
    FSetup: TGameSetup;
    FTitle: string;
    FWhiteEngineKey: string;
    FWhiteDisplayName: string;
    FWhitePlayerKind: TPlayerKind;
    FBlackDisplayName: string;
    procedure ClearSetup;
    procedure CopySetupFrom(const ASetup: TGameSetup);
    procedure ReleaseRunner;
    procedure WaitForRunnerFinished;
  public
    constructor Create(AId: Integer; const ATitle: string; ARunner: TGameRunnerThread;
      AWhitePlayerKind, ABlackPlayerKind: TPlayerKind; const AWhiteEngineKey,
      ABlackEngineKey, AWhiteDisplayName, ABlackDisplayName: string;
      AReservationKeys: TStrings; const ASetup: TGameSetup);
    destructor Destroy; override;

    function IsEngineReservationActive: Boolean;
    function IsHumanToMove: Boolean;
    function ReservationSummary: string;
    procedure AssignSetupTo(out ASetup: TGameSetup);
    property Id: Integer read FId;
    property GameTreeActor: TGameTreeActor read FGameTreeActor;
    property GameTree: TGameTree read FGameTree;
    property Lifecycle: TRunningGameLifecycle read FLifecycle;
    property Paused: Boolean read FPaused write FPaused;
    property Runner: TGameRunnerThread read FRunner;
    property ShowStdout: Boolean read FShowStdout write FShowStdout;
    property Snapshot: TGameRunnerSnapshot read FSnapshot;
    property StopReason: string read FStopReason;
    property Title: string read FTitle;
    property WhiteDisplayName: string read FWhiteDisplayName;
    property BlackDisplayName: string read FBlackDisplayName;
  end;

  TMainForm = class(TForm)
  private
    FAnalyzerCloseMenuItem: TMenuItem;
    FAnalyzerEngineKey: string;
    FAnalyzerLastPositionSignature: string;
    FAnalyzerMiniBoard: TDraughtsBoard;
    FAnalyzerMiniBoardControl: TDraughtsBoardControl;
    FAnalyzerMiniBoardForm: TForm;
    FAnalyzerMemo: TMemo;
    FAnalyzerOpenMenuItem: TMenuItem;
    FAnalyzerPopoutBoard: TDraughtsBoard;
    FAnalyzerPopoutBoardControl: TDraughtsBoardControl;
    FAnalyzerPopup: TPopupMenu;
    FAnalyzerPvBaseBoard: TDraughtsBoard;
    FAnalyzerPvBasePly: Integer;
    FAnalyzerPvBrowser: TPvBrowser;
    FAnalyzerPvMemo: TMemo;
    FAnalyzerRunner: TAnalyzerRunnerThread;
    FAnalyzerSearch: TGameTreeSearchRef;
    FAutorandomButton: TButton;
    FAutoplayButton: TButton;
    FAutoplaySecondsEdit: TEdit;
    FAutoplayThinkSeconds: Double;
    FBoard: TDraughtsBoard;
    FBoardControl: TDraughtsBoardControl;
    FBoardFlipped: Boolean;
    FBlackClockLabel: TLabel;
    FBlackRemainingSeconds: Double;
    FBlackUsedSeconds: Double;
    FClosing: Boolean;
    FDatabaseForm: TDatabaseForm;
    FEnginesDialog: TEnginesDialog;
    FGameActive: Boolean;
    FGameLog: TStringList;
    FGameLogSourceGameId: Integer;
    FGameLogSourceLineCount: Integer;
    FGameLogSourceShowStdout: Boolean;
    FGameLogMemoGameId: Integer;
    FGameLogMemoLineCount: Integer;
    FGameLogMemoShowStdout: Boolean;
    FGameLogMemo: TMemo;
    FGameBrowsePly: Integer;
    FGameResult: string;
    FGames: TList;
    FGamesListBox: TListBox;
    FGameState: TGameOrchestratorState;
    FGuiEventQueue: TThreadMessageQueue;
    FGuiEventTimer: TTimer;
    FBlackPlayerEdit: TEdit;
    FFenEdit: TEdit;
    FGameMoveLengths: TIntArray;
    FGameMoveMemo: TMemo;
    FGameMoveStarts: TIntArray;
    FGameTree: TGameTree;
    FGameTreeActor: TGameTreeActor;
    FGameTreeBrowseMode: Boolean;
    FGameTreeForm: TForm;
    FGameTreeView: TTreeView;
    FDisplayedAnnotationsSignature: string;
    FDisplayedMovesSignature: string;
    FDisplayedSnapshotSignature: string;
    FDisplayedGameTreeId: Int64;
    FDisplayedGameTreeRevision: Int64;
    FHighlightedGameMovePly: Integer;
    FHideMoveAnnotations: Boolean;
    FHideMoveAnnotationsMenuItem: TMenuItem;
    FMoveShowEnginePVMove: Boolean;
    FMoveShowEnginePVMoveMenuItem: TMenuItem;
    FMoveShowEngineFullPV: Boolean;
    FMoveShowEngineFullPVMenuItem: TMenuItem;
    FMoveShowAnnotatorPVMove: Boolean;
    FMoveShowAnnotatorPVMoveMenuItem: TMenuItem;
    FMoveShowAnnotatorFullPV: Boolean;
    FMoveShowAnnotatorFullPVMenuItem: TMenuItem;
    FMoveShowAnnotatorScore: Boolean;
    FMoveShowClocks: Boolean;
    FMoveShowEngineScore: Boolean;
    FHumanMoveChoices: TStringList;
    FHumanMoveSourceSquare: Integer;
    FLegalMovesMemo: TMemo;
    FLastDatabaseSearchFEN: string;
    FMiniBoard: TDraughtsBoard;
    FMiniBoardControl: TDraughtsBoardControl;
    FMiniBoardForm: TForm;
    FMctsCloseMenuItem: TMenuItem;
    FMctsEngineKey: string;
    FMctsLastPositionSignature: string;
    FMctsMemo: TMemo;
    FMctsOpenMenuItem: TMenuItem;
    FMctsPopup: TPopupMenu;
    FMctsRunner: TAnalyzerRunnerThread;
    FMctsStatsGrid: TStringGrid;
    FNextGameId: Integer;
    FHintFromAnalyzerMenuItem: TMenuItem;
    FHintFromMainMenuItem: TMenuItem;
    FPvHintSource: TPvHintSource;
    FPauseGameMenuItem: TMenuItem;
    FPopoutBoard: TDraughtsBoard;
    FPopoutBoardControl: TDraughtsBoardControl;
    FPositionSetupForm: TPositionSetupForm;
    FPreferences: TGuiPreferences;
    FPreferencesForm: TPreferencesForm;
    FPrincipalVariation: string;
    FPrincipalVariationDepth: string;
    FPrincipalVariationScore: string;
    FPrincipalVariationTimeText: string;
    FPvBaseBoard: TDraughtsBoard;
    FPvBasePly: Integer;
    FPvInfoLabel: TLabel;
    FPvBrowser: TPvBrowser;
    FPvMemo: TMemo;
    FPdnOpenDialog: TPdnOpenDialog;
    FReplayGameMenuItem: TMenuItem;
    FRemoveGameMenuItem: TMenuItem;
    FResultEdit: TEdit;
    FScoreHistoryControl: TScoreHistoryControl;
    FScoreHistoryForm: TScoreHistoryForm;
    FScoreHistoryCachedAnnotationsText: string;
    FScoreHistoryCachedGameTreeId: Int64;
    FScoreHistoryCachedPlyCount: Integer;
    FSearchPositionInDatabase: Boolean;
    FSearchPositionInDatabaseMenuItem: TMenuItem;
    FShowGameTreeMenuItem: TMenuItem;
    FSetupForm: TGameSetupForm;
    FShowStdoutMenuItem: TMenuItem;
    FStartingFEN: string;
    FStopGameMenuItem: TMenuItem;
    FStandaloneBlackPlayerName: string;
    FStandaloneEventName: string;
    FStandaloneWhitePlayerName: string;
    FTournamentDialog: TTournamentDialog;
    FViewedGameId: Integer;
    FVariationHits: TMoveVariationHitArray;
    FVariationIndex: Integer;
    FVariationBrowsePly: Integer;
    FWhiteClockLabel: TLabel;
    FWhitePlayerEdit: TEdit;
    FWhiteRemainingSeconds: Double;
    FWhiteUsedSeconds: Double;
    function ActiveBoard: TDraughtsBoard;
    function ActiveGameTree: TGameTree;
    procedure ApplyBoardFlipped;
    procedure ApplyBoardTheme(AControl: TDraughtsBoardControl;
      AUseAnalysisTheme: Boolean);
    procedure ApplyPreferences;
    procedure ApplyGameToDisplay(AGame: TRunningGame);
    procedure ApplyGameBrowsePly(APly: Integer);
    procedure AnalyzerLog(Sender: TObject; const AMessage: string);
    procedure AnalyzerFinished(Sender: TObject);
    procedure AnalyzerMiniBoardDblClick(Sender: TObject);
    procedure AnalyzerMiniBoardFormClose(Sender: TObject;
      var CloseAction: TCloseAction);
    procedure AnalyzerMiniBoardPopoutClick(Sender: TObject);
    procedure AnalyzerPopoutBoardCopyFenClick(Sender: TObject);
    procedure AnalyzerMove(Sender: TObject;
      const ASearch: TGameTreeSearchRef; const AMoveText: string);
    procedure AnalyzerPvBoardChanged(Sender: TObject);
    procedure AnalyzerPopupPopup(Sender: TObject);
    procedure AnalyzerSnapshot(Sender: TObject; ASnapshot: TPvSnapshot);
    procedure AutoplayClick(Sender: TObject);
    procedure AutorandomClick(Sender: TObject);
    function ReadAutoplaySecondsFromToolbar: Boolean;
    procedure UpdateAutoplayControls;
    function RecordAnalyzerSnapshotInGameTree(ASnapshot: TPvSnapshot): TGameTree;
    procedure ApplyVariationBrowsePly(AVariationIndex, AVariationPly: Integer;
      AGameTree: TGameTree);
    procedure BoardMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure BoardPopupPopup(Sender: TObject);
    procedure AddVariationMove(const AMove: string;
      ASource: TGameTreeMoveSource = gmsHuman);
    function ExecuteGameTreeAppendMainlineMove(AGameTree: TGameTree;
      const AMove: string; ASource: TGameTreeMoveSource): TGameTreePlyNode;
    function AppendGameTreeMainlineMove(AActor: TGameTreeActor;
      AGameTree: TGameTree; const AMove: string; ASource: TGameTreeMoveSource;
      out ACreatedNodeId: Int64; out AErrorText: string): Boolean;
    function RebuildGameTreeFromInputs(AActor: TGameTreeActor;
      const AHeader: TGameTreeHeaderInput;
      const AMainline: TGameTreeMainlineInput;
      const AEnginePV, AAnnotatorPV: TGameTreePvInput;
      AVariationPvIndex, AVariationPvPly: Integer;
      const AVariationPvScore, AVariationPvText: string;
      out AErrorText: string): Boolean;
    function SetGameTreeHeader(AActor: TGameTreeActor;
      const AHeader: TGameTreeHeaderInput; out AErrorText: string): Boolean;
    function ExecuteGameTreeCommand(AActor: TGameTreeActor;
      ACommand: TGameTreeCommand; out AErrorText: string): Boolean;
    function ExecuteAndApplyGameTreeCommand(AActor: TGameTreeActor;
      AGameTree: TGameTree; ACommand: TGameTreeCommand;
      AFollowVariationBrowse: Boolean; out AErrorText: string): Boolean;
    function TryStartGameTreeSearchForDisplayedNode(AGameTree: TGameTree;
      out ASearch: TGameTreeSearchRef; out AErrorText: string): Boolean;
    function AnalyzerSearchMatches(const ASearch: TGameTreeSearchRef): Boolean;
    function AcceptSearchMove(AActor: TGameTreeActor;
      const ASearch: TGameTreeSearchRef; const AMoveText: string;
      out AErrorText: string): Boolean;
    function CancelGameTreeSearch(AActor: TGameTreeActor;
      const ASearch: TGameTreeSearchRef): Boolean;
    function ReleaseGameTreeSearch(AActor: TGameTreeActor;
      const ASearch: TGameTreeSearchRef): Boolean;
    function ReleaseRejectedSearchIfFinished(AActor: TGameTreeActor;
      const ASearch: TGameTreeSearchRef): Boolean;
    function StoreSearchMoveVariation(AActor: TGameTreeActor;
      const ASearch: TGameTreeSearchRef; ASource: TGameTreeMoveSource;
      out AErrorText: string): Boolean;
    function StoreMoveVariation(AActor: TGameTreeActor; AGameTree: TGameTree;
      ANodeId: Int64; const AMove: string; ASource: TGameTreeMoveSource;
      out AErrorText: string): Boolean;
    function RecordEnginePvInGameTree(AActor: TGameTreeActor;
      AGameTree: TGameTree; ANodeId: Int64; const AScore,
      APrincipalVariation: string; out AErrorText: string): Boolean;
    function RecordAnnotatorPvInGameTree(AActor: TGameTreeActor;
      AGameTree: TGameTree; ANodeId: Int64; const AScore,
      APrincipalVariation: string; out AErrorText: string): Boolean;
    function ClearGameTreeStoredVariations(AActor: TGameTreeActor): Boolean;
    function StoreGameTreeVariationLine(AActor: TGameTreeActor;
      ADisplayAfterPly, ABasePly: Integer; const AMovesText,
      AAnnotationText: string; ASource: TGameTreeMoveSource;
      out AErrorText: string): Boolean;
    function TryResolveActiveSearchSnapshot(ASnapshot: TPvSnapshot;
      out AActor: TGameTreeActor; out AGameTree: TGameTree;
      out ANode: TGameTreePlyNode): Boolean;
    procedure TrackAnalyzerSearch(const ASearch: TGameTreeSearchRef);
    procedure ClearAnalyzerSearchTracking;
    procedure SetAnalyzerPvBase(ABoard: TDraughtsBoard; APly: Integer);
    procedure InvalidateAnalyzerPositionSignature;
    procedure InvalidateMctsPositionSignature;
    procedure ApplyGameTreeCommandResult(AGameTree: TGameTree;
      ACommand: TGameTreeCommand; AFollowVariationBrowse: Boolean);
    function ExecuteGameTreeRebuildFromInput(AGame: TRunningGame;
      AGameTree: TGameTree; AMoves, AAnnotations: TStrings): Boolean;
    function CurrentGameTreeHeaderInput(AGame: TRunningGame;
      AGameTree: TGameTree): TGameTreeHeaderInput;
    function RunningGameTreeHeaderInput(AGame: TRunningGame;
      const AEventName: string): TGameTreeHeaderInput;
    procedure UpdateRunningGameTreeFromSnapshot(AGame: TRunningGame;
      const AEventName: string = '');
    function RunningGameTreePdnText(AGame: TRunningGame;
      const AEventName: string): string;
    function CanExploreVariation: Boolean;
    function CanAcceptHumanBoardMove: Boolean;
    function HasLegalDisplayedMove: Boolean;
    function CanStartAutoplayForGame(AGame: TRunningGame): Boolean;
    function CanStartAutoplay: Boolean;
    function CanRecordCurrentAnnotatorPV: Boolean;
    function CanRecordCurrentVariationAnnotatorPV(AVariationIndex,
      AVariationPly: Integer): Boolean;
    function CurrentGameTreeEnginePvInput(
      AGameTree: TGameTree): TGameTreePvInput;
    function CurrentGameTreeAnnotatorPvInput(
      AGameTree: TGameTree): TGameTreePvInput;
    procedure ClearHumanMoveSelection;
    procedure ClearStoredTreeVariations(AGameTree: TGameTree);
    procedure ClearVariationExploration;
    function ApplyGameMoveMemoCaretBrowse: Boolean;
    procedure CopyGameTreePdnClick(Sender: TObject);
    procedure CloseQueryHandler(Sender: TObject; var CanClose: Boolean);
    procedure CloseAnalyzerClick(Sender: TObject);
    procedure CancelAnalyzerSearch;
    procedure CopyBoardFenClick(Sender: TObject);
    procedure CreateDatabaseClick(Sender: TObject);
    procedure StopSelectedGame(Sender: TObject);
    function CurrentMoveCount: Integer;
    function CurrentVariationMoveCount(AGameTree: TGameTree): Integer;
    function GameTreeMainlineMovesText(AGameTree: TGameTree): string;
    function DisplayedMovesText(AGameTree: TGameTree): string;
    function DisplayedMoveContext(AGameTree: TGameTree;
      out AMovesText: string; out AMoveCount: Integer): Boolean;
    function DisplayedPositionSignature(const AStartingFEN,
      AMovesText: string; AGameState: TGameOrchestratorState): string;
    function DisplayedPositionIsTerminal(ADisplayedMoveCount,
      ATotalMoveCount: Integer; AGameState: TGameOrchestratorState): Boolean;
    function HasDisplayedGameToSave: Boolean;
    function EngineSupportsMcts(AEngine: TExternalEngineDefinition): Boolean;
    function GameForTree(AGameTree: TGameTree): TRunningGame;
    function ActorForGameTree(AGameTree: TGameTree): TGameTreeActor;
    function ActorForGameTreeId(AGameTreeId: Int64): TGameTreeActor;
    function ActorForSearchRef(
      const ASearch: TGameTreeSearchRef): TGameTreeActor;
    function GameForTreeRefresh(AGameTree: TGameTree): TRunningGame;
    function BlackNameForTree(AGameTree: TGameTree): string;
    function EventNameForTree(AGameTree: TGameTree): string;
    function ResultForTree(AGameTree: TGameTree): string;
    function RunningGameTreeExtendsSnapshot(AGame: TRunningGame): Boolean;
    function StartingFenForTree(AGameTree: TGameTree): string;
    function StateForTree(AGameTree: TGameTree): TGameOrchestratorState;
    function WhiteNameForTree(AGameTree: TGameTree): string;
    function ClockValuesForTree(AGameTree: TGameTree;
      out AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
      ABlackUsedSeconds: Double): Boolean;
    function VisibleMainPvForTree(AGameTree: TGameTree;
      out ABaseBoard: TDraughtsBoard; out ABasePly: Integer; out APV,
      AScore, ADepth, ATimeText: string): Boolean;
    function FormatClock(ASeconds: Double): string;
    function CurrentFilteredGameTreePdnOptions: TGameTreePdnRenderOptions;
    function GameLogLineVisible(const ALine: string; AGame: TRunningGame): Boolean;
    function GameTitleEngineName(AEngine: TExternalEngineDefinition): string;
    procedure PrepareGameTreeForPdn(AGame: TRunningGame;
      AGameTree: TGameTree; const AEventName: string);
    function CurrentGameTreePdnText(const AEventName: string): string;
    function PlayerSetupDisplayName(AKind: TPlayerKind;
      AEngine: TExternalEngineDefinition): string;
    function FindHumanMoveToTarget(ATargetSquare: Integer; out AMove: string): Boolean;
    procedure GameMoveBrowseClick(Sender: TObject);
    procedure GameMoveBrowseKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure GameMovePopupPopup(Sender: TObject);
    procedure GameTreeFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure GameTreeViewClick(Sender: TObject);
    procedure GameTreeViewKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure HideMoveAnnotationsClick(Sender: TObject);
    procedure HighlightGameMoveTextSelection(AFocusMemo: Boolean;
      AGameTree: TGameTree);
    procedure GameSetupAccepted(Sender: TObject; const ASetup: TGameSetup);
    procedure GamesPopupPopup(Sender: TObject);
    procedure GamesListBoxClick(Sender: TObject);
    procedure GuiEventTimerTick(Sender: TObject);
    procedure HandleAnalyzerLog(const AMessage: string);
    procedure HandleAnalyzerMove(const ASearch: TGameTreeSearchRef;
      const AMoveText: string);
    procedure HandleMctsLog(const AMessage: string);
    procedure HintSourceClick(Sender: TObject);
    procedure GameFinished(Sender: TObject);
    procedure GameSnapshot(Sender: TObject; ASnapshot: TGameRunnerSnapshot);
    procedure LegalMovesMemoClick(Sender: TObject);
    function CurrentDisplayedGameTreeNode(
      AGameTree: TGameTree): TGameTreePlyNode;
    function LiveGameCount: Integer;
    procedure MainFormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure MiniBoardDblClick(Sender: TObject);
    procedure MiniBoardFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure MiniBoardPopoutClick(Sender: TObject);
    procedure MoveDisplayFilterClick(Sender: TObject);
    procedure UpdateGameMovePopupState;
    procedure MctsFinished(Sender: TObject);
    procedure MctsLog(Sender: TObject; const AMessage: string);
    procedure MctsPopupPopup(Sender: TObject);
    procedure PopoutBoardCopyFenClick(Sender: TObject);
    procedure PvBoardChanged(Sender: TObject);
    procedure NewGameClick(Sender: TObject);
    procedure OpenAnalyzerClick(Sender: TObject);
    procedure OpenMctsClick(Sender: TObject);
    procedure OpenDatabaseClick(Sender: TObject);
    procedure EnginesClick(Sender: TObject);
    procedure ExitGameBrowseMode;
    procedure OpenPdnClick(Sender: TObject);
    procedure PauseGameClick(Sender: TObject);
    procedure PasteFenClick(Sender: TObject);
    procedure PdnGameSelected(Sender: TObject; AGame: TPdnGame);
    function PlayerNameOrFallback(const AName, AFallback: string): string;
    function PostGuiEvent(AEvent: TObject): Boolean;
    procedure PreferencesAccepted(Sender: TObject;
      const APreferences: TGuiPreferences);
    procedure PreferencesClick(Sender: TObject);
    function MoveSquareAt(const AMove: string; ASquareIndex: Integer): Integer;
    procedure PlayHumanMove(const AMove: string;
      ASource: TGameTreeMoveSource = gmsHuman);
    procedure RemoveGame(AGame: TRunningGame);
    procedure RemoveSelectedGame(Sender: TObject);
    procedure RestartAnalyzer(AGameTree: TGameTree);
    procedure RestartMctsAnnotator(AGameTree: TGameTree);
    procedure ReplaySelectedGame(Sender: TObject);
    procedure SelectHumanMoveSource(ASourceSquare: Integer);
    procedure RebuildGameMoveLabels(AGameTree: TGameTree);
    procedure UpdateGameMoveHighlight;
    function SelectedGame: TRunningGame;
    function SelectedDisplayedGame: TRunningGame;
    procedure SavePdnClick(Sender: TObject);
    function SaveCurrentGameWithDialog: Boolean;
    procedure ScrollMemoToLastTextLine(AMemo: TMemo);
    procedure ScoreHistoryPopoutClick(Sender: TObject);
    procedure ScoreHistoryFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure SearchPositionInDatabaseClick(Sender: TObject);
    procedure SetupPositionAccepted(Sender: TObject; const AFEN: string);
    procedure SetupPositionClick(Sender: TObject);
    procedure ShowGameTreeClick(Sender: TObject);
    procedure ShowStdoutClick(Sender: TObject);
    procedure StopAllGames;
    procedure CloseMctsClick(Sender: TObject);
    procedure ClearMctsStatsGrid;
    procedure ToggleBoardFlipped;
    procedure TournamentStartGame(Sender: TObject; const ASetup: TGameSetup;
      const ATitlePrefix: string; out AGame: TObject);
    function TreeVariationLineByIndex(AIndex: Integer;
      AGameTree: TGameTree): TGameTreeVariationLine;
    procedure LoadStandaloneFen(const AFEN: string);
    procedure LoadPdnGameToDisplay(AGame: TPdnGame);
    procedure LoadTreeVariationsFromLegacyText(AGameTree: TGameTree;
      const AVariationsText, AVariationAnnotationsText: string);
    function FindTreeVariationByDisplayAfterPly(ADisplayAfterPly: Integer;
      AGameTree: TGameTree): Integer;
    function StoreTreeVariation(ADisplayAfterPly, ABasePly: Integer;
      const AMovesText, AAnnotationText: string;
      AGameTree: TGameTree): Boolean;
    procedure UpdateBrowseInfo;
    procedure UpdateBoardInfo;
    procedure UpdateDatabaseSearchPosition;
    procedure UpdateBoardFromBrowseState(AGameTree: TGameTree);
    procedure UpdateBoardHighlights(AGameTree: TGameTree);
    procedure UpdateClockLabels(const AWhiteName, ABlackName: string);
    procedure UpdateScoreHistory(AGameTree: TGameTree);
    procedure UpdateGameListItem(AGame: TRunningGame);
    procedure UpdateLegalMoves;
    procedure UpdateGameLogMemo;
    procedure UpdateGameTreeFromMoveText(AGame: TRunningGame;
      AGameTree: TGameTree; const AMovesText, AAnnotationsText: string);
    procedure RefreshVisibleGameTreeView(AGameTree: TGameTree);
    procedure RefreshDisplayedGameTreeViews(AGameTree: TGameTree;
      AForce: Boolean);
    procedure UpdateGameTreeView(AGameTree: TGameTree);
    procedure UpdateMiniBoardFromBoard(ABoard: TDraughtsBoard);
    procedure UpdateMctsStatsFromLog(const AMessage: string);
    procedure TournamentClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure AppendRunningGameToPdn(AGame: TRunningGame;
      const AFileName, AEventName: string);
    procedure CollectBusyEngineKeys(AKeys: TStrings);
    function FindGameById(AGameId: Integer): TRunningGame;
    procedure MarkGameStopped(AGame: TRunningGame; const AReason: string);
    function StartGameFromSetup(const ASetup: TGameSetup;
      const ATitlePrefix: string = 'Game'): TRunningGame;
  end;

var
  MainForm: TMainForm;

implementation

function RunningGameLifecycleToString(ALifecycle: TRunningGameLifecycle): string;
begin
  case ALifecycle of
    rglStarting:
      Result := 'starting';
    rglRunning:
      Result := 'running';
    rglStopRequested:
      Result := 'stop requested';
    rglRemoveRequested:
      Result := 'remove requested';
    rglFinished:
      Result := 'finished';
  else
    Result := 'unknown';
  end;
end;

constructor TRunnerSnapshotGuiMessage.Create(AGameId: Integer;
  ASnapshot: TGameRunnerSnapshot);
begin
  inherited Create('runner-snapshot');
  FGameId := AGameId;
  FSnapshot := ASnapshot;
end;

destructor TRunnerSnapshotGuiMessage.Destroy;
begin
  FSnapshot.Free;
  inherited Destroy;
end;

constructor TRunnerFinishedGuiMessage.Create(AGameId: Integer);
begin
  inherited Create('runner-finished');
  FGameId := AGameId;
end;

constructor TAnalyzerLogGuiMessage.Create(const AMessage: string);
begin
  inherited Create('analyzer-log');
  FMessage := AMessage;
end;

constructor TAnalyzerSnapshotGuiMessage.Create(ASnapshot: TPvSnapshot);
begin
  inherited Create('analyzer-snapshot');
  FSnapshot := ASnapshot;
end;

destructor TAnalyzerSnapshotGuiMessage.Destroy;
begin
  FSnapshot.Free;
  inherited Destroy;
end;

constructor TAnalyzerMoveGuiMessage.Create(const ASearch: TGameTreeSearchRef;
  const AMoveText: string);
begin
  inherited Create('analyzer-move');
  FSearch := ASearch;
  FMoveText := Trim(AMoveText);
end;

constructor TAnalyzerFinishedGuiMessage.Create(ARunner: TAnalyzerRunnerThread);
begin
  inherited Create('analyzer-finished');
  FRunner := ARunner;
end;

constructor TMctsLogGuiMessage.Create(const AMessage: string);
begin
  inherited Create('mcts-log');
  FMessage := AMessage;
end;

constructor TMctsFinishedGuiMessage.Create(ARunner: TAnalyzerRunnerThread);
begin
  inherited Create('mcts-finished');
  FRunner := ARunner;
end;

constructor TRunningGame.Create(AId: Integer; const ATitle: string;
  ARunner: TGameRunnerThread; AWhitePlayerKind, ABlackPlayerKind: TPlayerKind;
  const AWhiteEngineKey, ABlackEngineKey, AWhiteDisplayName,
  ABlackDisplayName: string; AReservationKeys: TStrings; const ASetup: TGameSetup);
begin
  inherited Create;
  FId := AId;
  FTitle := ATitle;
  FRunner := ARunner;
  FWhitePlayerKind := AWhitePlayerKind;
  FBlackPlayerKind := ABlackPlayerKind;
  FWhiteEngineKey := AWhiteEngineKey;
  FBlackEngineKey := ABlackEngineKey;
  FWhiteDisplayName := AWhiteDisplayName;
  FBlackDisplayName := ABlackDisplayName;
  FReservationKeys := TStringList.Create;
  FReservationKeys.Sorted := True;
  FReservationKeys.Duplicates := dupIgnore;
  if AReservationKeys <> nil then
    FReservationKeys.AddStrings(AReservationKeys);
  FGameTree := TGameTree.Create;
  FGameTreeActor := TGameTreeActor.Create(FGameTree, False);
  FSnapshot := TGameRunnerSnapshot.Create;
  CopySetupFrom(ASetup);
  FLifecycle := rglStarting;
end;

destructor TRunningGame.Destroy;
begin
  ReleaseRunner;
  ClearSetup;
  FGameTreeActor.Free;
  FGameTree.Free;
  FSnapshot.Free;
  FReservationKeys.Free;
  inherited Destroy;
end;

procedure TRunningGame.ClearSetup;
begin
  FreeAndNil(FSetup.WhiteEngine);
  FreeAndNil(FSetup.BlackEngine);
end;

procedure TRunningGame.CopySetupFrom(const ASetup: TGameSetup);
begin
  ClearSetup;
  FSetup := ASetup;
  FSetup.WhiteEngine := nil;
  FSetup.BlackEngine := nil;
  if ASetup.WhiteEngine <> nil then
  begin
    FSetup.WhiteEngine := TExternalEngineDefinition.Create;
    FSetup.WhiteEngine.Assign(ASetup.WhiteEngine);
  end;
  if ASetup.BlackEngine <> nil then
  begin
    FSetup.BlackEngine := TExternalEngineDefinition.Create;
    FSetup.BlackEngine.Assign(ASetup.BlackEngine);
  end;
end;

procedure TRunningGame.AssignSetupTo(out ASetup: TGameSetup);
begin
  ASetup := FSetup;
  ASetup.WhiteEngine := nil;
  ASetup.BlackEngine := nil;
  if FSetup.WhiteEngine <> nil then
  begin
    ASetup.WhiteEngine := TExternalEngineDefinition.Create;
    ASetup.WhiteEngine.Assign(FSetup.WhiteEngine);
  end;
  if FSetup.BlackEngine <> nil then
  begin
    ASetup.BlackEngine := TExternalEngineDefinition.Create;
    ASetup.BlackEngine.Assign(FSetup.BlackEngine);
  end;
end;

procedure TRunningGame.ReleaseRunner;
begin
  if FRunner = nil then
    Exit;
  if FReleasingRunner then
    Exit;

  FReleasingRunner := True;
  try

    if FLifecycle <> rglFinished then
      FRunner.PostStop;
    WaitForRunnerFinished;
    FRunner.WaitFor;
    FreeAndNil(FRunner);
  finally
    FReleasingRunner := False;
  end;
end;

procedure TRunningGame.WaitForRunnerFinished;
const
  RunnerReleaseWarningMs = 10000;
var
  LastWarningTick: QWord;
  WarningText: string;
begin
  if FRunner = nil then
    Exit;

  LastWarningTick := GetTickCount64;
  while not FRunner.Finished do
  begin
    CheckSynchronize(50);
    if GetTickCount64 - LastWarningTick >= RunnerReleaseWarningMs then
    begin
      WarningText := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
        ' [gui] waiting for runner shutdown; game_id=' + IntToStr(FId) +
        '; title=' + FTitle +
        '; lifecycle=' + RunningGameLifecycleToString(FLifecycle) +
        '; state=' + OrchestratorStateToString(FSnapshot.State) +
        '; plies=' + IntToStr(FSnapshot.PlyCount) +
        '; reservations=' + ReservationSummary;
      FSnapshot.LogLines.Add(WarningText);
      WriteLn(WarningText);
      LastWarningTick := GetTickCount64;
    end;
    Sleep(10);
  end;
end;

function TRunningGame.IsEngineReservationActive: Boolean;
begin
  Result := FLifecycle <> rglFinished;
end;

function TRunningGame.IsHumanToMove: Boolean;
begin
  if FSnapshot.CurrentSide = dsBlack then
    Result := FBlackPlayerKind = pkHuman
  else
    Result := FWhitePlayerKind = pkHuman;
end;

function TRunningGame.ReservationSummary: string;
begin
  Result := Trim(FReservationKeys.CommaText);
  if Result = '' then
    Result := 'none';
end;

constructor TMainForm.Create(AOwner: TComponent);
var
  LGamesPanel: TPanel;
  LMainPanel: TPanel;
  LLegalPanel: TPanel;
  LLegalMovesPanel: TPanel;
  LSidePanel: TPanel;
  LToolbar: TPanel;
  LWorkPanel: TPanel;
  LBoardPopup: TPopupMenu;
  LDatabaseMenu: TMenuItem;
  LFenPopup: TPopupMenu;
  LFileMenu: TMenuItem;
  LGameMovePopup: TPopupMenu;
  LLeftSplitter: TSplitter;
  LMainMenu: TMainMenu;
  LRightSplitter: TSplitter;
  LAnalyzerSplitter: TSplitter;
  LBottomPanel: TPanel;
  LGamesLabel: TLabel;
  LGamesPopup: TPopupMenu;
  LLegalMovesLabel: TLabel;
  LMenuItem: TMenuItem;
  LLogSplitter: TSplitter;
  LEnginesButton: TButton;
  LAutoplayLabel: TLabel;
  LGameHeaderPanel: TPanel;
  LPvBoardPanel: TPanel;
  LPvLabel: TLabel;
  LPvPanel: TPanel;
  LPvPopup: TPopupMenu;
  LPvScorePanel: TPanel;
  LPvSplitter: TSplitter;
  LPvTextPanel: TPanel;
  LPvTopPanel: TPanel;
  LAnalyzerBoardPanel: TPanel;
  LAnalyzerBoardPopup: TPopupMenu;
  LAnalyzerMiniBoardPanel: TPanel;
  LAnalyzerPanel: TPanel;
  LAnalyzerStatsPanel: TPanel;
  LAnalyzerTextPanel: TPanel;
  LPvInfoTextWidth: Integer;
  LPvSidePanelWidth: Integer;
  LResetButton: TButton;
  LScoreHistoryPopup: TPopupMenu;
  LTournamentButton: TButton;

  procedure AddHeaderField(const ACaption: string; ATop: Integer;
    out AEdit: TEdit);
  var
    LLabel: TLabel;
  begin
    LLabel := TLabel.Create(Self);
    LLabel.Parent := LGameHeaderPanel;
    LLabel.SetBounds(0, ATop + 3, 48, 22);
    LLabel.Caption := ACaption;

    AEdit := TEdit.Create(Self);
    AEdit.Parent := LGameHeaderPanel;
    AEdit.SetBounds(52, ATop, LGameHeaderPanel.ClientWidth - 52, 24);
    AEdit.Anchors := [akTop, akLeft, akRight];
    AEdit.ReadOnly := True;
  end;
begin
  inherited Create(AOwner);

  Caption := 'GWDGUI - International Polish Draughts';
  Application.HintColor := RGBToColor(255, 255, 225);
  Screen.HintFont.Color := clBlack;
  Position := poDesigned;
  KeyPreview := True;
  OnKeyDown := @MainFormKeyDown;
  OnCloseQuery := @CloseQueryHandler;
  Width := 1040;
  Height := 760;
  Constraints.MinWidth := 720;
  Constraints.MinHeight := 520;
  CenterFormOnLaptopPanel(Self, 0);

  FBoard := TDraughtsBoard.Create;
  FMiniBoard := TDraughtsBoard.Create;
  FPopoutBoard := TDraughtsBoard.Create;
  FAnalyzerMiniBoard := TDraughtsBoard.Create;
  FAnalyzerPopoutBoard := TDraughtsBoard.Create;
  FAnalyzerPvBaseBoard := TDraughtsBoard.Create;
  FPvBaseBoard := TDraughtsBoard.Create;
  FStartingFEN := FBoard.StartingFEN;
  FGameState := gosWaiting;
  FGameResult := '*';
  FGameBrowsePly := -1;
  FGameTreeBrowseMode := False;
  FVariationIndex := -1;
  FVariationBrowsePly := 0;
  FGameLogSourceGameId := -1;
  FGameLogSourceLineCount := -1;
  FGameLogSourceShowStdout := False;
  FGameLogMemoGameId := -1;
  FGameLogMemoLineCount := -1;
  FDisplayedAnnotationsSignature := '';
  FDisplayedGameTreeId := 0;
  FDisplayedGameTreeRevision := -1;
  FHighlightedGameMovePly := -1;
  FHideMoveAnnotations := False;
  FMoveShowEnginePVMove := False;
  FMoveShowEngineFullPV := False;
  FMoveShowAnnotatorPVMove := False;
  FMoveShowAnnotatorFullPV := False;
  FMoveShowAnnotatorScore := True;
  FMoveShowClocks := False;
  FMoveShowEngineScore := True;
  FAutoplayThinkSeconds := 1.0;
  FSearchPositionInDatabase := True;
  FPvHintSource := phsMain;
  FViewedGameId := -1;
  FGameLog := TStringList.Create;
  FHumanMoveChoices := TStringList.Create;
  FGameTree := TGameTree.Create;
  FGameTreeActor := TGameTreeActor.Create(FGameTree, False);
  FGames := TList.Create;
  FGuiEventQueue := TThreadMessageQueue.Create(True);
  FGuiEventTimer := TTimer.Create(Self);
  FGuiEventTimer.Interval := 50;
  FGuiEventTimer.OnTimer := @GuiEventTimerTick;
  FGuiEventTimer.Enabled := True;
  FStandaloneWhitePlayerName := 'White';
  FStandaloneBlackPlayerName := 'Black';
  FStandaloneEventName := '?';
  LoadGuiPreferences(FPreferences);
  Randomize;

  LMainMenu := TMainMenu.Create(Self);
  LFileMenu := TMenuItem.Create(Self);
  LFileMenu.Caption := 'File';
  LMainMenu.Items.Add(LFileMenu);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Open PDN...';
  LMenuItem.OnClick := @OpenPdnClick;
  LFileMenu.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Save PDN...';
  LMenuItem.OnClick := @SavePdnClick;
  LFileMenu.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Preferences...';
  LMenuItem.OnClick := @PreferencesClick;
  LFileMenu.Add(LMenuItem);

  LDatabaseMenu := TMenuItem.Create(Self);
  LDatabaseMenu.Caption := 'Database';
  LMainMenu.Items.Add(LDatabaseMenu);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Create database...';
  LMenuItem.OnClick := @CreateDatabaseClick;
  LDatabaseMenu.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Open database...';
  LMenuItem.OnClick := @OpenDatabaseClick;
  LDatabaseMenu.Add(LMenuItem);
  Menu := LMainMenu;

  LToolbar := TPanel.Create(Self);
  LToolbar.Parent := Self;
  LToolbar.Align := alTop;
  LToolbar.Height := 42;
  LToolbar.BevelOuter := bvNone;
  LToolbar.ParentColor := True;
  LToolbar.BorderSpacing.Around := 6;

  { With alLeft on this widgetset, later-created buttons are placed further
    left, so create these in reverse visual order. }
  FAutoplayButton := TButton.Create(Self);
  FAutoplayButton.Parent := LToolbar;
  FAutoplayButton.Align := alLeft;
  FAutoplayButton.Width := 86;
  FAutoplayButton.BorderSpacing.Left := 6;
  FAutoplayButton.Caption := 'Autoplay';
  FAutoplayButton.OnClick := @AutoplayClick;

  FAutorandomButton := TButton.Create(Self);
  FAutorandomButton.Parent := LToolbar;
  FAutorandomButton.Align := alLeft;
  FAutorandomButton.Width := 96;
  FAutorandomButton.BorderSpacing.Left := 6;
  FAutorandomButton.Caption := 'Autorandom';
  FAutorandomButton.OnClick := @AutorandomClick;

  FAutoplaySecondsEdit := TEdit.Create(Self);
  FAutoplaySecondsEdit.Parent := LToolbar;
  FAutoplaySecondsEdit.Align := alLeft;
  FAutoplaySecondsEdit.Width := 54;
  FAutoplaySecondsEdit.BorderSpacing.Left := 4;
  FAutoplaySecondsEdit.Text := FloatToStr(FAutoplayThinkSeconds);
  FAutoplaySecondsEdit.Hint := 'Seconds per autoplay move';
  FAutoplaySecondsEdit.ShowHint := True;

  LAutoplayLabel := TLabel.Create(Self);
  LAutoplayLabel.Parent := LToolbar;
  LAutoplayLabel.Align := alLeft;
  LAutoplayLabel.Width := 58;
  LAutoplayLabel.BorderSpacing.Left := 14;
  LAutoplayLabel.Caption := 'Seconds';
  LAutoplayLabel.Layout := tlCenter;
  LAutoplayLabel.ParentColor := True;
  LAutoplayLabel.Transparent := True;

  LTournamentButton := TButton.Create(Self);
  LTournamentButton.Parent := LToolbar;
  LTournamentButton.Align := alLeft;
  LTournamentButton.Width := 120;
  LTournamentButton.BorderSpacing.Left := 8;
  LTournamentButton.Caption := 'Tournament...';
  LTournamentButton.OnClick := @TournamentClick;

  LResetButton := TButton.Create(Self);
  LResetButton.Parent := LToolbar;
  LResetButton.Align := alLeft;
  LResetButton.Width := 120;
  LResetButton.BorderSpacing.Left := 8;
  LResetButton.Caption := 'New game...';
  LResetButton.OnClick := @NewGameClick;

  LEnginesButton := TButton.Create(Self);
  LEnginesButton.Parent := LToolbar;
  LEnginesButton.Align := alLeft;
  LEnginesButton.Width := 120;
  LEnginesButton.Caption := 'Engines...';
  LEnginesButton.OnClick := @EnginesClick;
  UpdateAutoplayControls;

  LBottomPanel := TPanel.Create(Self);
  LBottomPanel.Parent := Self;
  LBottomPanel.Align := alBottom;
  LBottomPanel.Height := 366;
  LBottomPanel.Constraints.MinHeight := 260;
  LBottomPanel.BevelOuter := bvNone;
  LBottomPanel.Color := clWindow;
  LBottomPanel.BorderSpacing.Left := 8;
  LBottomPanel.BorderSpacing.Right := 8;
  LBottomPanel.BorderSpacing.Bottom := 8;

  LAnalyzerPanel := TPanel.Create(Self);
  LAnalyzerPanel.Parent := LBottomPanel;
  LAnalyzerPanel.Align := alBottom;
  LAnalyzerPanel.Height := 112;
  LAnalyzerPanel.Constraints.MinHeight := 112;
  LAnalyzerPanel.BevelOuter := bvNone;

  FAnalyzerPopup := TPopupMenu.Create(Self);
  FAnalyzerPopup.OnPopup := @AnalyzerPopupPopup;
  FAnalyzerOpenMenuItem := TMenuItem.Create(Self);
  FAnalyzerOpenMenuItem.Caption := 'Open Annotator';
  FAnalyzerPopup.Items.Add(FAnalyzerOpenMenuItem);
  FAnalyzerCloseMenuItem := TMenuItem.Create(Self);
  FAnalyzerCloseMenuItem.Caption := 'Close Annotator';
  FAnalyzerCloseMenuItem.OnClick := @CloseAnalyzerClick;
  FAnalyzerPopup.Items.Add(FAnalyzerCloseMenuItem);

  FMctsPopup := TPopupMenu.Create(Self);
  FMctsPopup.OnPopup := @MctsPopupPopup;
  FMctsOpenMenuItem := TMenuItem.Create(Self);
  FMctsOpenMenuItem.Caption := 'Open MCTS annotator';
  FMctsPopup.Items.Add(FMctsOpenMenuItem);
  FMctsCloseMenuItem := TMenuItem.Create(Self);
  FMctsCloseMenuItem.Caption := 'Close MCTS annotator';
  FMctsCloseMenuItem.OnClick := @CloseMctsClick;
  FMctsPopup.Items.Add(FMctsCloseMenuItem);

  LAnalyzerBoardPanel := TPanel.Create(Self);
  LAnalyzerBoardPanel.Parent := LAnalyzerPanel;
  LAnalyzerBoardPanel.Align := alRight;
  LAnalyzerBoardPanel.Width := 300;
  LAnalyzerBoardPanel.BevelOuter := bvNone;
  LAnalyzerBoardPanel.BorderSpacing.Left := 8;
  LAnalyzerBoardPanel.BorderSpacing.Right := 8;

  LAnalyzerBoardPopup := TPopupMenu.Create(Self);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Pop out annotator mini-board';
  LMenuItem.OnClick := @AnalyzerMiniBoardPopoutClick;
  LAnalyzerBoardPopup.Items.Add(LMenuItem);

  LAnalyzerMiniBoardPanel := TPanel.Create(Self);
  LAnalyzerMiniBoardPanel.Parent := LAnalyzerBoardPanel;
  LAnalyzerMiniBoardPanel.Align := alLeft;
  LAnalyzerMiniBoardPanel.Width := 112;
  LAnalyzerMiniBoardPanel.BevelOuter := bvNone;
  LAnalyzerMiniBoardPanel.BorderSpacing.Right := 6;

  FAnalyzerMiniBoardControl := TDraughtsBoardControl.Create(Self);
  FAnalyzerMiniBoardControl.Parent := LAnalyzerMiniBoardPanel;
  FAnalyzerMiniBoardControl.Align := alClient;
  FAnalyzerMiniBoardControl.Board := FAnalyzerMiniBoard;
  FAnalyzerMiniBoardControl.ShowCoordinates := False;
  FAnalyzerMiniBoardControl.PopupMenu := LAnalyzerBoardPopup;
  FAnalyzerMiniBoardControl.OnDblClick := @AnalyzerMiniBoardDblClick;
  FAnalyzerMiniBoardControl.BoardFlipped := FBoardFlipped;

  LAnalyzerStatsPanel := TPanel.Create(Self);
  LAnalyzerStatsPanel.Parent := LAnalyzerBoardPanel;
  LAnalyzerStatsPanel.Align := alClient;
  LAnalyzerStatsPanel.BevelOuter := bvNone;

  FMctsStatsGrid := TStringGrid.Create(Self);
  FMctsStatsGrid.Parent := LAnalyzerStatsPanel;
  FMctsStatsGrid.Align := alTop;
  FMctsStatsGrid.BorderStyle := bsSingle;
  FMctsStatsGrid.ColCount := 2;
  FMctsStatsGrid.RowCount := 8;
  FMctsStatsGrid.FixedCols := 0;
  FMctsStatsGrid.FixedRows := 0;
  FMctsStatsGrid.Options := FMctsStatsGrid.Options - [goEditing, goRangeSelect] +
    [goRowSelect];
  FMctsStatsGrid.ScrollBars := ssAutoVertical;
  FMctsStatsGrid.Font.Size := 7;
  FMctsStatsGrid.DefaultRowHeight := 13;
  FMctsStatsGrid.Height := FMctsStatsGrid.RowCount *
    FMctsStatsGrid.DefaultRowHeight + 4;
  FMctsStatsGrid.ColWidths[0] := 82;
  FMctsStatsGrid.ColWidths[1] := 92;
  ClearMctsStatsGrid;

  LAnalyzerTextPanel := TPanel.Create(Self);
  LAnalyzerTextPanel.Parent := LAnalyzerPanel;
  LAnalyzerTextPanel.Align := alClient;
  LAnalyzerTextPanel.BevelOuter := bvNone;

  FAnalyzerPvMemo := TMemo.Create(Self);
  FAnalyzerPvMemo.Parent := LAnalyzerTextPanel;
  FAnalyzerPvMemo.Align := alTop;
  FAnalyzerPvMemo.Height := 44;
  FAnalyzerPvMemo.ParentFont := True;
  FAnalyzerPvMemo.ReadOnly := True;
  FAnalyzerPvMemo.ScrollBars := ssVertical;
  FAnalyzerPvMemo.WordWrap := True;
  FAnalyzerPvMemo.HideSelection := False;
  FAnalyzerPvMemo.Lines.Add('No PV');
  FAnalyzerPvMemo.PopupMenu := FAnalyzerPopup;

  FAnalyzerPvBrowser := TPvBrowser.Create(FAnalyzerMiniBoard,
    FAnalyzerMiniBoardControl, nil, FAnalyzerPvMemo);
  FAnalyzerPvBrowser.OnBoardChanged := @AnalyzerPvBoardChanged;

  FMctsMemo := TMemo.Create(Self);
  FMctsMemo.Parent := LAnalyzerTextPanel;
  FMctsMemo.Align := alBottom;
  FMctsMemo.Height := 34;
  FMctsMemo.ParentFont := True;
  FMctsMemo.ReadOnly := True;
  FMctsMemo.ScrollBars := ssAutoBoth;
  FMctsMemo.WordWrap := False;
  FMctsMemo.BorderSpacing.Top := 4;
  FMctsMemo.Lines.Add('MCTS annotator closed');
  FMctsMemo.PopupMenu := FMctsPopup;

  FAnalyzerMemo := TMemo.Create(Self);
  FAnalyzerMemo.Parent := LAnalyzerTextPanel;
  FAnalyzerMemo.Align := alClient;
  FAnalyzerMemo.ParentFont := True;
  FAnalyzerMemo.ReadOnly := True;
  FAnalyzerMemo.ScrollBars := ssAutoBoth;
  FAnalyzerMemo.WordWrap := False;
  FAnalyzerMemo.Lines.Add('Annotator closed');
  FAnalyzerMemo.PopupMenu := FAnalyzerPopup;

  LAnalyzerSplitter := TSplitter.Create(Self);
  LAnalyzerSplitter.Parent := LBottomPanel;
  LAnalyzerSplitter.Align := alBottom;
  LAnalyzerSplitter.Height := 8;
  LAnalyzerSplitter.ResizeAnchor := akBottom;

  FGameLogMemo := TMemo.Create(Self);
  FGameLogMemo.Parent := LBottomPanel;
  FGameLogMemo.Align := alClient;
  FGameLogMemo.ReadOnly := True;
  FGameLogMemo.ScrollBars := ssAutoBoth;
  FGameLogMemo.WordWrap := False;

  LLogSplitter := TSplitter.Create(Self);
  LLogSplitter.Parent := Self;
  LLogSplitter.Align := alBottom;
  LLogSplitter.Height := 8;
  LLogSplitter.ResizeAnchor := akBottom;

  LWorkPanel := TPanel.Create(Self);
  LWorkPanel.Parent := Self;
  LWorkPanel.Align := alClient;
  LWorkPanel.BevelOuter := bvNone;
  LWorkPanel.Color := clBtnFace;

  LLeftSplitter := TSplitter.Create(Self);
  LLeftSplitter.Parent := LWorkPanel;
  LLeftSplitter.Align := alLeft;
  LLeftSplitter.Width := 8;
  LLeftSplitter.ResizeAnchor := akLeft;
  LLeftSplitter.MinSize := 150;

  LLegalMovesPanel := TPanel.Create(Self);
  LLegalMovesPanel.Parent := LWorkPanel;
  LLegalMovesPanel.Align := alLeft;
  LLegalMovesPanel.Width := 220;
  LLegalMovesPanel.Constraints.MinWidth := 150;
  LLegalMovesPanel.Constraints.MaxWidth := 420;
  LLegalMovesPanel.BevelOuter := bvNone;
  LLegalMovesPanel.BorderSpacing.Left := 8;

  LGamesPanel := TPanel.Create(Self);
  LGamesPanel.Parent := LLegalMovesPanel;
  LGamesPanel.Align := alTop;
  LGamesPanel.Height := 180;
  LGamesPanel.BevelOuter := bvNone;

  LGamesLabel := TLabel.Create(Self);
  LGamesLabel.Parent := LGamesPanel;
  LGamesLabel.SetBounds(0, 0, LGamesPanel.ClientWidth, 22);
  LGamesLabel.Anchors := [akTop, akLeft, akRight];
  LGamesLabel.Caption := 'Game History';
  LGamesLabel.Layout := tlCenter;

  FGamesListBox := TListBox.Create(Self);
  FGamesListBox.Parent := LGamesPanel;
  FGamesListBox.SetBounds(0, 24, LGamesPanel.ClientWidth, LGamesPanel.ClientHeight - 24);
  FGamesListBox.Anchors := [akTop, akLeft, akRight, akBottom];
  FGamesListBox.OnClick := @GamesListBoxClick;

  LGamesPopup := TPopupMenu.Create(Self);
  LGamesPopup.OnPopup := @GamesPopupPopup;
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'New game...';
  LMenuItem.OnClick := @NewGameClick;
  LGamesPopup.Items.Add(LMenuItem);
  FReplayGameMenuItem := TMenuItem.Create(Self);
  FReplayGameMenuItem.Caption := 'Replay game';
  FReplayGameMenuItem.OnClick := @ReplaySelectedGame;
  LGamesPopup.Items.Add(FReplayGameMenuItem);
  FShowStdoutMenuItem := TMenuItem.Create(Self);
  FShowStdoutMenuItem.Caption := 'Show stdout';
  FShowStdoutMenuItem.AutoCheck := False;
  FShowStdoutMenuItem.OnClick := @ShowStdoutClick;
  LGamesPopup.Items.Add(FShowStdoutMenuItem);
  FPauseGameMenuItem := TMenuItem.Create(Self);
  FPauseGameMenuItem.Caption := 'Pause game';
  FPauseGameMenuItem.OnClick := @PauseGameClick;
  LGamesPopup.Items.Add(FPauseGameMenuItem);
  FStopGameMenuItem := TMenuItem.Create(Self);
  FStopGameMenuItem.Caption := 'Stop game';
  FStopGameMenuItem.OnClick := @StopSelectedGame;
  LGamesPopup.Items.Add(FStopGameMenuItem);
  FRemoveGameMenuItem := TMenuItem.Create(Self);
  FRemoveGameMenuItem.Caption := 'Remove game';
  FRemoveGameMenuItem.OnClick := @RemoveSelectedGame;
  LGamesPopup.Items.Add(FRemoveGameMenuItem);
  FGamesListBox.PopupMenu := LGamesPopup;

  LLegalPanel := TPanel.Create(Self);
  LLegalPanel.Parent := LLegalMovesPanel;
  LLegalPanel.Align := alClient;
  LLegalPanel.BevelOuter := bvNone;

  LLegalMovesLabel := TLabel.Create(Self);
  LLegalMovesLabel.Parent := LLegalPanel;
  LLegalMovesLabel.SetBounds(0, 0, LLegalPanel.ClientWidth, 22);
  LLegalMovesLabel.Anchors := [akTop, akLeft, akRight];
  LLegalMovesLabel.Caption := 'Legal moves';
  LLegalMovesLabel.Layout := tlCenter;

  FLegalMovesMemo := TMemo.Create(Self);
  FLegalMovesMemo.Parent := LLegalPanel;
  FLegalMovesMemo.SetBounds(0, 24, LLegalPanel.ClientWidth, LLegalPanel.ClientHeight - 24);
  FLegalMovesMemo.Anchors := [akTop, akLeft, akRight, akBottom];
  FLegalMovesMemo.ReadOnly := True;
  FLegalMovesMemo.ScrollBars := ssAutoVertical;
  FLegalMovesMemo.WordWrap := False;
  FLegalMovesMemo.OnClick := @LegalMovesMemoClick;

  LSidePanel := TPanel.Create(Self);
  LSidePanel.Parent := LWorkPanel;
  LSidePanel.Align := alRight;
  LSidePanel.Width := 330;
  LSidePanel.Constraints.MinWidth := 220;
  LSidePanel.BevelOuter := bvNone;
  LSidePanel.BorderSpacing.Around := 8;

  LRightSplitter := TSplitter.Create(Self);
  LRightSplitter.Parent := LWorkPanel;
  LRightSplitter.Align := alRight;
  LRightSplitter.Width := 8;
  LRightSplitter.ResizeAnchor := akRight;

  LGameHeaderPanel := TPanel.Create(Self);
  LGameHeaderPanel.Parent := LSidePanel;
  LGameHeaderPanel.Align := alTop;
  LGameHeaderPanel.Height := 106;
  LGameHeaderPanel.BevelOuter := bvNone;
  LGameHeaderPanel.BorderSpacing.Bottom := 6;

  AddHeaderField('White', 0, FWhitePlayerEdit);
  AddHeaderField('Black', 26, FBlackPlayerEdit);
  AddHeaderField('Result', 52, FResultEdit);
  AddHeaderField('FEN', 78, FFenEdit);
  LFenPopup := TPopupMenu.Create(Self);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Paste FEN position from clipboard';
  LMenuItem.OnClick := @PasteFenClick;
  LFenPopup.Items.Add(LMenuItem);
  FFenEdit.PopupMenu := LFenPopup;

  LPvSplitter := TSplitter.Create(Self);
  LPvSplitter.Parent := LSidePanel;
  LPvSplitter.Align := alBottom;
  LPvSplitter.Height := 8;
  LPvSplitter.ResizeAnchor := akBottom;

  LPvPanel := TPanel.Create(Self);
  LPvPanel.Parent := LSidePanel;
  LPvPanel.Align := alBottom;
  LPvPanel.Height := 130;
  LPvPanel.Constraints.MinHeight := 70;
  LPvPanel.BevelOuter := bvNone;

  FGameMoveMemo := TMemo.Create(Self);
  FGameMoveMemo.Parent := LSidePanel;
  FGameMoveMemo.Align := alClient;
  FGameMoveMemo.ParentFont := True;
  FGameMoveMemo.ReadOnly := True;
  FGameMoveMemo.ScrollBars := ssVertical;
  FGameMoveMemo.WordWrap := True;
  FGameMoveMemo.HideSelection := False;
  FGameMoveMemo.OnClick := @GameMoveBrowseClick;
  FGameMoveMemo.OnKeyDown := @GameMoveBrowseKeyDown;

  LGameMovePopup := TPopupMenu.Create(Self);
  LGameMovePopup.OnPopup := @GameMovePopupPopup;
  FHideMoveAnnotationsMenuItem := TMenuItem.Create(Self);
  FHideMoveAnnotationsMenuItem.Caption := 'Hide annotation';
  FHideMoveAnnotationsMenuItem.AutoCheck := False;
  FHideMoveAnnotationsMenuItem.OnClick := @HideMoveAnnotationsClick;
  LGameMovePopup.Items.Add(FHideMoveAnnotationsMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := '-';
  LGameMovePopup.Items.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Show engine score';
  LMenuItem.AutoCheck := False;
  LMenuItem.Checked := FMoveShowEngineScore;
  LMenuItem.Tag := 1;
  LMenuItem.OnClick := @MoveDisplayFilterClick;
  LGameMovePopup.Items.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Show annotator score';
  LMenuItem.AutoCheck := False;
  LMenuItem.Checked := FMoveShowAnnotatorScore;
  LMenuItem.Tag := 5;
  LMenuItem.OnClick := @MoveDisplayFilterClick;
  LGameMovePopup.Items.Add(LMenuItem);
  FMoveShowEnginePVMoveMenuItem := TMenuItem.Create(Self);
  FMoveShowEnginePVMoveMenuItem.Caption := 'Show engine PV move';
  FMoveShowEnginePVMoveMenuItem.AutoCheck := False;
  FMoveShowEnginePVMoveMenuItem.Checked := FMoveShowEnginePVMove;
  FMoveShowEnginePVMoveMenuItem.Tag := 2;
  FMoveShowEnginePVMoveMenuItem.OnClick := @MoveDisplayFilterClick;
  LGameMovePopup.Items.Add(FMoveShowEnginePVMoveMenuItem);
  FMoveShowEngineFullPVMenuItem := TMenuItem.Create(Self);
  FMoveShowEngineFullPVMenuItem.Caption := 'Show engine full PV';
  FMoveShowEngineFullPVMenuItem.AutoCheck := False;
  FMoveShowEngineFullPVMenuItem.Checked := FMoveShowEngineFullPV;
  FMoveShowEngineFullPVMenuItem.Tag := 6;
  FMoveShowEngineFullPVMenuItem.OnClick := @MoveDisplayFilterClick;
  LGameMovePopup.Items.Add(FMoveShowEngineFullPVMenuItem);
  FMoveShowAnnotatorPVMoveMenuItem := TMenuItem.Create(Self);
  FMoveShowAnnotatorPVMoveMenuItem.Caption := 'Show annotator PV move';
  FMoveShowAnnotatorPVMoveMenuItem.AutoCheck := False;
  FMoveShowAnnotatorPVMoveMenuItem.Checked := FMoveShowAnnotatorPVMove;
  FMoveShowAnnotatorPVMoveMenuItem.Tag := 4;
  FMoveShowAnnotatorPVMoveMenuItem.OnClick := @MoveDisplayFilterClick;
  LGameMovePopup.Items.Add(FMoveShowAnnotatorPVMoveMenuItem);
  FMoveShowAnnotatorFullPVMenuItem := TMenuItem.Create(Self);
  FMoveShowAnnotatorFullPVMenuItem.Caption := 'Show annotator full PV';
  FMoveShowAnnotatorFullPVMenuItem.AutoCheck := False;
  FMoveShowAnnotatorFullPVMenuItem.Checked := FMoveShowAnnotatorFullPV;
  FMoveShowAnnotatorFullPVMenuItem.Tag := 7;
  FMoveShowAnnotatorFullPVMenuItem.OnClick := @MoveDisplayFilterClick;
  LGameMovePopup.Items.Add(FMoveShowAnnotatorFullPVMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Show clocks';
  LMenuItem.AutoCheck := False;
  LMenuItem.Checked := FMoveShowClocks;
  LMenuItem.Tag := 3;
  LMenuItem.OnClick := @MoveDisplayFilterClick;
  LGameMovePopup.Items.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := '-';
  LGameMovePopup.Items.Add(LMenuItem);
  FShowGameTreeMenuItem := TMenuItem.Create(Self);
  FShowGameTreeMenuItem.Caption := 'Show tree';
  FShowGameTreeMenuItem.OnClick := @ShowGameTreeClick;
  LGameMovePopup.Items.Add(FShowGameTreeMenuItem);
  FGameMoveMemo.PopupMenu := LGameMovePopup;
  UpdateGameMovePopupState;

  LPvBoardPanel := TPanel.Create(Self);
  LPvBoardPanel.Parent := LPvPanel;
  LPvBoardPanel.Align := alRight;
  LPvBoardPanel.Width := 112;
  LPvBoardPanel.BevelOuter := bvNone;
  LPvBoardPanel.BorderSpacing.Left := 8;

  LPvPopup := TPopupMenu.Create(Self);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Pop out mini-board';
  LMenuItem.OnClick := @MiniBoardPopoutClick;
  LPvPopup.Items.Add(LMenuItem);

  FMiniBoardControl := TDraughtsBoardControl.Create(Self);
  FMiniBoardControl.Parent := LPvBoardPanel;
  FMiniBoardControl.Align := alClient;
  FMiniBoardControl.Board := FMiniBoard;
  FMiniBoardControl.ShowCoordinates := False;
  FMiniBoardControl.PopupMenu := LPvPopup;
  FMiniBoardControl.OnDblClick := @MiniBoardDblClick;
  FMiniBoardControl.BoardFlipped := FBoardFlipped;

  LPvTextPanel := TPanel.Create(Self);
  LPvTextPanel.Parent := LPvPanel;
  LPvTextPanel.Align := alClient;
  LPvTextPanel.BevelOuter := bvNone;

  LPvTopPanel := TPanel.Create(Self);
  LPvTopPanel.Parent := LPvTextPanel;
  LPvTopPanel.Align := alTop;
  LPvTopPanel.Height := 94;
  LPvTopPanel.BevelOuter := bvNone;

  LPvScorePanel := TPanel.Create(Self);
  LPvScorePanel.Parent := LPvTopPanel;
  LPvScorePanel.Align := alTop;
  LPvScorePanel.Height := 66;
  LPvScorePanel.BevelOuter := bvNone;

  FScoreHistoryControl := TScoreHistoryControl.Create(Self);
  FScoreHistoryControl.Parent := LPvScorePanel;
  FScoreHistoryControl.Align := alClient;
  FScoreHistoryControl.ParentFont := True;
  FScoreHistoryControl.ShowEvaluationBar := True;
  LScoreHistoryPopup := TPopupMenu.Create(Self);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Pop out score history...';
  LMenuItem.OnClick := @ScoreHistoryPopoutClick;
  LScoreHistoryPopup.Items.Add(LMenuItem);
  FScoreHistoryControl.PopupMenu := LScoreHistoryPopup;

  LPvLabel := TLabel.Create(Self);
  LPvLabel.Parent := LPvTopPanel;
  LPvLabel.Align := alClient;
  LPvLabel.Caption := 'PV';
  LPvLabel.Layout := tlCenter;

  FPvInfoLabel := LPvLabel;
  Canvas.Font.Assign(LPvLabel.Font);
  LPvInfoTextWidth := Canvas.TextWidth(
    'PV: score -123.456 depth 123 time 1234.56') + 16;
  LPvSidePanelWidth := LPvInfoTextWidth + LPvBoardPanel.Width + 40;
  if LSidePanel.Width < LPvSidePanelWidth then
    LSidePanel.Width := LPvSidePanelWidth;
  if LSidePanel.Constraints.MinWidth < LPvSidePanelWidth then
    LSidePanel.Constraints.MinWidth := LPvSidePanelWidth;

  FPvMemo := TMemo.Create(Self);
  FPvMemo.Parent := LPvTextPanel;
  FPvMemo.Align := alClient;
  FPvMemo.ParentFont := True;
  FPvMemo.ReadOnly := True;
  FPvMemo.ScrollBars := ssVertical;
  FPvMemo.WordWrap := True;
  FPvMemo.HideSelection := False;

  FPvBrowser := TPvBrowser.Create(FMiniBoard, FMiniBoardControl, FPvInfoLabel,
    FPvMemo);
  FPvBrowser.OnBoardChanged := @PvBoardChanged;

  LMainPanel := TPanel.Create(Self);
  LMainPanel.Parent := LWorkPanel;
  LMainPanel.Align := alClient;
  LMainPanel.BevelOuter := bvNone;
  LMainPanel.BorderSpacing.Top := 8;
  LMainPanel.BorderSpacing.Bottom := 8;

  FBlackClockLabel := TLabel.Create(Self);
  FBlackClockLabel.Parent := LMainPanel;
  FBlackClockLabel.Align := alTop;
  FBlackClockLabel.Height := 28;
  FBlackClockLabel.Alignment := taCenter;
  FBlackClockLabel.Layout := tlCenter;

  FWhiteClockLabel := TLabel.Create(Self);
  FWhiteClockLabel.Parent := LMainPanel;
  FWhiteClockLabel.Align := alBottom;
  FWhiteClockLabel.Height := 28;
  FWhiteClockLabel.Alignment := taCenter;
  FWhiteClockLabel.Layout := tlCenter;

  FBoardControl := TDraughtsBoardControl.Create(Self);
  FBoardControl.Parent := LMainPanel;
  FBoardControl.Align := alClient;
  FBoardControl.Board := FBoard;
  FBoardControl.ShowSideToMoveMarker := True;
  FBoardControl.OnMouseDown := @BoardMouseDown;
  FBoardControl.BoardFlipped := FBoardFlipped;
  LBoardPopup := TPopupMenu.Create(Self);
  LBoardPopup.OnPopup := @BoardPopupPopup;
  FHintFromMainMenuItem := TMenuItem.Create(Self);
  FHintFromMainMenuItem.Caption := 'Show hints from main PV';
  FHintFromMainMenuItem.Checked := True;
  FHintFromMainMenuItem.RadioItem := True;
  FHintFromMainMenuItem.GroupIndex := 1;
  FHintFromMainMenuItem.OnClick := @HintSourceClick;
  LBoardPopup.Items.Add(FHintFromMainMenuItem);
  FHintFromAnalyzerMenuItem := TMenuItem.Create(Self);
  FHintFromAnalyzerMenuItem.Caption := 'Show hints from annotator PV';
  FHintFromAnalyzerMenuItem.RadioItem := True;
  FHintFromAnalyzerMenuItem.GroupIndex := 1;
  FHintFromAnalyzerMenuItem.OnClick := @HintSourceClick;
  LBoardPopup.Items.Add(FHintFromAnalyzerMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := '-';
  LBoardPopup.Items.Add(LMenuItem);
  FSearchPositionInDatabaseMenuItem := TMenuItem.Create(Self);
  FSearchPositionInDatabaseMenuItem.Caption := 'Search position in database';
  FSearchPositionInDatabaseMenuItem.AutoCheck := False;
  FSearchPositionInDatabaseMenuItem.Checked := FSearchPositionInDatabase;
  FSearchPositionInDatabaseMenuItem.OnClick := @SearchPositionInDatabaseClick;
  LBoardPopup.Items.Add(FSearchPositionInDatabaseMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := '-';
  LBoardPopup.Items.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Setup position...';
  LMenuItem.OnClick := @SetupPositionClick;
  LBoardPopup.Items.Add(LMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Copy FEN position to clipboard';
  LMenuItem.OnClick := @CopyBoardFenClick;
  LBoardPopup.Items.Add(LMenuItem);
  FBoardControl.PopupMenu := LBoardPopup;

  ApplyPreferences;
  UpdateBoardInfo;
end;

destructor TMainForm.Destroy;
begin
  FClosing := True;
  Application.RemoveAsyncCalls(Self);
  if FGuiEventTimer <> nil then
    FGuiEventTimer.Enabled := False;
  if FTournamentDialog <> nil then
    FTournamentDialog.BeginShutdown;
  StopAllGames;
  FreeAndNil(FMctsRunner);
  FreeAndNil(FAnalyzerRunner);
  if FGuiEventQueue <> nil then
    FGuiEventQueue.Close;
  FreeAndNil(FGuiEventQueue);
  FreeAndNil(FEnginesDialog);
  FreeAndNil(FDatabaseForm);
  FreeAndNil(FSetupForm);
  FreeAndNil(FPositionSetupForm);
  FreeAndNil(FPreferencesForm);
  FreeAndNil(FScoreHistoryForm);
  FreeAndNil(FTournamentDialog);
  FreeAndNil(FPdnOpenDialog);
  FreeAndNil(FMiniBoardForm);
  FreeAndNil(FAnalyzerMiniBoardForm);
  FreeAndNil(FGameTreeForm);
  FreeAndNil(FAnalyzerPvBrowser);
  FreeAndNil(FPvBrowser);
  FHumanMoveChoices.Free;
  FGameTreeActor.Free;
  FGameTree.Free;
  FGameLog.Free;
  FGames.Free;
  FAnalyzerPopoutBoard.Free;
  FAnalyzerPvBaseBoard.Free;
  FAnalyzerMiniBoard.Free;
  FPopoutBoard.Free;
  FMiniBoard.Free;
  FPvBaseBoard.Free;
  FBoard.Free;
  inherited Destroy;
end;

function TMainForm.ActiveBoard: TDraughtsBoard;
begin
  Result := FBoard;
end;

function TMainForm.ActiveGameTree: TGameTree;
var
  LGame: TRunningGame;
begin
  Result := FGameTree;
  LGame := SelectedDisplayedGame;
  if (LGame <> nil) and (LGame.GameTree <> nil) then
    Result := LGame.GameTree;
end;

procedure TMainForm.ApplyBoardTheme(AControl: TDraughtsBoardControl;
  AUseAnalysisTheme: Boolean);
begin
  if AControl = nil then
    Exit;

  if AUseAnalysisTheme then
  begin
    AControl.BoardLightColor := FPreferences.AnalysisBoardLightColor;
    AControl.BoardDarkColor := FPreferences.AnalysisBoardDarkColor;
    AControl.GridColor := FPreferences.AnalysisBoardDarkColor;
  end
  else
  begin
    AControl.BoardLightColor := FPreferences.MainBoardLightColor;
    AControl.BoardDarkColor := FPreferences.MainBoardDarkColor;
    AControl.GridColor := FPreferences.MainBoardDarkColor;
  end;

  AControl.TargetSquareColor := FPreferences.TargetSquareColor;
  AControl.LastMoveTargetSquareColor := FPreferences.LastMoveColor;
  AControl.PvSourceSquareColor := FPreferences.PvMoveColor;
  AControl.HintSourceSquareColor := FPreferences.HintMoveColor;
end;

procedure TMainForm.ApplyPreferences;
begin
  ApplyBoardTheme(FBoardControl, False);
  ApplyBoardTheme(FMiniBoardControl, False);
  ApplyBoardTheme(FPopoutBoardControl, False);
  ApplyBoardTheme(FAnalyzerMiniBoardControl, True);
  ApplyBoardTheme(FAnalyzerPopoutBoardControl, True);

  if FPositionSetupForm <> nil then
    FPositionSetupForm.ApplyPreferences(FPreferences);
  if FSetupForm <> nil then
    FSetupForm.ApplyPreferences(FPreferences);
  if FDatabaseForm <> nil then
    FDatabaseForm.ApplyPreferences(FPreferences);
  UpdateScoreHistory(ActiveGameTree);
end;

procedure TMainForm.ApplyBoardFlipped;
begin
  if FBoardControl <> nil then
    FBoardControl.BoardFlipped := FBoardFlipped;
  if FMiniBoardControl <> nil then
    FMiniBoardControl.BoardFlipped := FBoardFlipped;
  if FPopoutBoardControl <> nil then
    FPopoutBoardControl.BoardFlipped := FBoardFlipped;
  if FAnalyzerMiniBoardControl <> nil then
    FAnalyzerMiniBoardControl.BoardFlipped := FBoardFlipped;
  if FAnalyzerPopoutBoardControl <> nil then
    FAnalyzerPopoutBoardControl.BoardFlipped := FBoardFlipped;
end;

function TMainForm.CanAcceptHumanBoardMove: Boolean;
var
  LGame: TRunningGame;
begin
  if FGameBrowsePly >= 0 then
    Exit(False);

  LGame := SelectedDisplayedGame;
  Result := (LGame <> nil) and (LGame.Runner <> nil) and
    (LGame.Snapshot.State = gosRunning) and LGame.IsHumanToMove;
end;

function TMainForm.HasLegalDisplayedMove: Boolean;
begin
  Result := (ActiveBoard <> nil) and (ActiveBoard.LegalMoves.Count > 0);
end;

function TMainForm.CanStartAutoplayForGame(AGame: TRunningGame): Boolean;
begin
  Result := (AGame = nil) or
    (not (AGame.Snapshot.State in [gosWaiting, gosRunning]));
end;

function TMainForm.CanStartAutoplay: Boolean;
var
  LGame: TRunningGame;
begin
  Result := False;
  if not HasLegalDisplayedMove then
    Exit;

  LGame := SelectedDisplayedGame;
  Result := CanStartAutoplayForGame(LGame);
end;

function TMainForm.CanExploreVariation: Boolean;
var
  LGame: TRunningGame;
begin
  Result := False;
  if FGameBrowsePly < 0 then
    Exit;

  LGame := SelectedDisplayedGame;
  if LGame <> nil then
    Result := (LGame.Lifecycle = rglFinished) or
      (LGame.Snapshot.State in [gosStopped, gosGameOver])
  else
    Result := Trim(StartingFenForTree(ActiveGameTree)) <> '';
end;

procedure TMainForm.ClearHumanMoveSelection;
begin
  FHumanMoveSourceSquare := 0;
  if FHumanMoveChoices <> nil then
    FHumanMoveChoices.Clear;
  if FBoardControl <> nil then
    FBoardControl.ClearTargetSquares;
end;

procedure TMainForm.ClearVariationExploration;
begin
  FVariationIndex := -1;
  FVariationBrowsePly := 0;
end;

procedure TMainForm.ToggleBoardFlipped;
begin
  FBoardFlipped := not FBoardFlipped;
  ClearHumanMoveSelection;
  ApplyBoardFlipped;
  if FGameActive then
    UpdateClockLabels(FWhitePlayerEdit.Text, FBlackPlayerEdit.Text);
end;

function TMainForm.TreeVariationLineByIndex(AIndex: Integer;
  AGameTree: TGameTree): TGameTreeVariationLine;
begin
  Result := nil;
  if (AGameTree = nil) or (AIndex < 0) or
    (AIndex >= AGameTree.VariationLineCount) then
    Exit;
  Result := AGameTree.VariationLine[AIndex];
end;

function TMainForm.AppendGameTreeMainlineMove(AActor: TGameTreeActor;
  AGameTree: TGameTree; const AMove: string; ASource: TGameTreeMoveSource;
  out ACreatedNodeId: Int64; out AErrorText: string): Boolean;
var
  Command: TGameTreeCommand;
begin
  Result := False;
  ACreatedNodeId := 0;
  AErrorText := '';
  if (AActor = nil) or (AGameTree = nil) or (Trim(AMove) = '') then
  begin
    AErrorText := 'invalid mainline move target';
    Exit;
  end;

  Command := AActor.CreateAppendMainlineMoveCommand(AMove, ASource);
  try
    Result := ExecuteAndApplyGameTreeCommand(AActor, AGameTree, Command,
      False, AErrorText);
    if not Result then
      Exit;
    ACreatedNodeId := Command.CreatedNodeId;
  finally
    Command.Free;
  end;
end;

function TMainForm.ExecuteGameTreeAppendMainlineMove(AGameTree: TGameTree;
  const AMove: string; ASource: TGameTreeMoveSource): TGameTreePlyNode;
var
  Actor: TGameTreeActor;
  CreatedNodeId: Int64;
  LErrorText: string;
begin
  Result := nil;
  Actor := ActorForGameTree(AGameTree);
  if Actor = nil then
    Exit;

  if not AppendGameTreeMainlineMove(Actor, AGameTree, AMove, ASource,
    CreatedNodeId, LErrorText) then
    Exit;

  Result := AGameTree.FindNodeById(CreatedNodeId);
end;

function TMainForm.RebuildGameTreeFromInputs(AActor: TGameTreeActor;
  const AHeader: TGameTreeHeaderInput; const AMainline: TGameTreeMainlineInput;
  const AEnginePV, AAnnotatorPV: TGameTreePvInput; AVariationPvIndex,
  AVariationPvPly: Integer; const AVariationPvScore,
  AVariationPvText: string; out AErrorText: string): Boolean;
var
  Command: TGameTreeCommand;
begin
  Result := False;
  AErrorText := '';
  if AActor = nil then
  begin
    AErrorText := 'invalid game-tree rebuild target';
    Exit;
  end;

  Command := AActor.CreateRebuildFromInputsCommand(AHeader, AMainline,
    AEnginePV, AAnnotatorPV, AVariationPvIndex, AVariationPvPly,
    AVariationPvScore, AVariationPvText);
  try
    Result := ExecuteGameTreeCommand(AActor, Command, AErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.SetGameTreeHeader(AActor: TGameTreeActor;
  const AHeader: TGameTreeHeaderInput; out AErrorText: string): Boolean;
var
  Command: TGameTreeCommand;
begin
  Result := False;
  AErrorText := '';
  if AActor = nil then
  begin
    AErrorText := 'invalid game-tree header target';
    Exit;
  end;

  Command := AActor.CreateSetHeaderCommand(AHeader);
  try
    Result := ExecuteGameTreeCommand(AActor, Command, AErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.ExecuteGameTreeCommand(AActor: TGameTreeActor;
  ACommand: TGameTreeCommand; out AErrorText: string): Boolean;
begin
  AErrorText := '';
  Result := False;
  if (AActor = nil) or (ACommand = nil) then
  begin
    AErrorText := 'game tree command is unavailable';
    Exit;
  end;

  AActor.ExecuteCommand(ACommand);
  Result := ACommand.Accepted;
  if not Result then
    AErrorText := ACommand.ErrorText;
end;

function TMainForm.ExecuteAndApplyGameTreeCommand(AActor: TGameTreeActor;
  AGameTree: TGameTree; ACommand: TGameTreeCommand;
  AFollowVariationBrowse: Boolean; out AErrorText: string): Boolean;
var
  LRevisionBefore: Int64;
begin
  if AActor <> nil then
    LRevisionBefore := AActor.Revision
  else
    LRevisionBefore := -1;
  Result := ExecuteGameTreeCommand(AActor, ACommand, AErrorText);
  if not Result then
    Exit;
  if AFollowVariationBrowse or (AActor.Revision <> LRevisionBefore) then
    ApplyGameTreeCommandResult(AGameTree, ACommand, AFollowVariationBrowse);
end;

function TMainForm.TryStartGameTreeSearchForDisplayedNode(
  AGameTree: TGameTree; out ASearch: TGameTreeSearchRef;
  out AErrorText: string): Boolean;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Node: TGameTreePlyNode;
begin
  ASearch := EmptyGameTreeSearchRef;
  AErrorText := '';
  Result := False;

  Actor := ActorForGameTree(AGameTree);
  Node := CurrentDisplayedGameTreeNode(AGameTree);
  if (Actor = nil) or (Node = nil) then
  begin
    AErrorText := 'no game-tree node';
    Exit;
  end;

  Command := Actor.CreateStartSearchCommand(Node.NodeId, ASearch);
  try
    Result := ExecuteGameTreeCommand(Actor, Command, AErrorText);
    if not Result then
      ASearch := EmptyGameTreeSearchRef;
  finally
    Command.Free;
  end;
end;

function TMainForm.AnalyzerSearchMatches(
  const ASearch: TGameTreeSearchRef): Boolean;
begin
  Result := IsValidGameTreeSearchRef(ASearch) and
    SameGameTreeSearchRef(FAnalyzerSearch, ASearch);
end;

function TMainForm.AcceptSearchMove(AActor: TGameTreeActor;
  const ASearch: TGameTreeSearchRef; const AMoveText: string;
  out AErrorText: string): Boolean;
var
  Command: TGameTreeCommand;
begin
  Result := False;
  AErrorText := '';
  if (AActor = nil) or (not IsValidGameTreeSearchRef(ASearch)) then
  begin
    AErrorText := 'invalid search';
    Exit;
  end;

  Command := AActor.CreateSearchDoneCommand(ASearch, AMoveText);
  try
    Result := ExecuteGameTreeCommand(AActor, Command, AErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.CancelGameTreeSearch(AActor: TGameTreeActor;
  const ASearch: TGameTreeSearchRef): Boolean;
var
  Command: TGameTreeCommand;
  LErrorText: string;
begin
  Result := False;
  if (AActor = nil) or (not IsValidGameTreeSearchRef(ASearch)) then
    Exit;

  Command := AActor.CreateCancelSearchCommand(ASearch);
  try
    Result := ExecuteGameTreeCommand(AActor, Command, LErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.ReleaseGameTreeSearch(AActor: TGameTreeActor;
  const ASearch: TGameTreeSearchRef): Boolean;
var
  Command: TGameTreeCommand;
  LErrorText: string;
begin
  Result := False;
  if (AActor = nil) or (not IsValidGameTreeSearchRef(ASearch)) then
    Exit;

  Command := AActor.CreateReleaseSearchCommand(ASearch);
  try
    Result := ExecuteGameTreeCommand(AActor, Command, LErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.ReleaseRejectedSearchIfFinished(AActor: TGameTreeActor;
  const ASearch: TGameTreeSearchRef): Boolean;
var
  LSearchState: TGameTreeSearchState;
begin
  Result := False;
  if (AActor = nil) or (not IsValidGameTreeSearchRef(ASearch)) then
    Exit;
  if AActor.SearchState(ASearch, LSearchState) and
    (LSearchState in [gssCancelled, gssFailed]) then
    Result := ReleaseGameTreeSearch(AActor, ASearch);
end;

function TMainForm.StoreSearchMoveVariation(AActor: TGameTreeActor;
  const ASearch: TGameTreeSearchRef; ASource: TGameTreeMoveSource;
  out AErrorText: string): Boolean;
var
  Command: TGameTreeCommand;
  LGameTree: TGameTree;
begin
  Result := False;
  AErrorText := '';
  if (AActor = nil) or (not IsValidGameTreeSearchRef(ASearch)) then
  begin
    AErrorText := 'invalid search';
    Exit;
  end;

  LGameTree := AActor.GameTree;
  Command := AActor.CreateStoreSearchMoveVariationCommand(ASearch, ASource);
  try
    Result := ExecuteAndApplyGameTreeCommand(AActor, LGameTree, Command,
      True, AErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.StoreMoveVariation(AActor: TGameTreeActor;
  AGameTree: TGameTree; ANodeId: Int64; const AMove: string;
  ASource: TGameTreeMoveSource; out AErrorText: string): Boolean;
var
  Command: TGameTreeCommand;
begin
  Result := False;
  AErrorText := '';
  if (AActor = nil) or (AGameTree = nil) or (ANodeId <= 0) or
    (Trim(AMove) = '') then
  begin
    AErrorText := 'invalid move variation target';
    Exit;
  end;

  Command := AActor.CreateStoreMoveVariationCommand(ANodeId, AMove, ASource);
  try
    Result := ExecuteAndApplyGameTreeCommand(AActor, AGameTree, Command,
      True, AErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.RecordAnnotatorPvInGameTree(AActor: TGameTreeActor;
  AGameTree: TGameTree; ANodeId: Int64; const AScore,
  APrincipalVariation: string; out AErrorText: string): Boolean;
var
  Command: TGameTreeCommand;
begin
  Result := False;
  AErrorText := '';
  if (AActor = nil) or (AGameTree = nil) or (ANodeId <= 0) then
  begin
    AErrorText := 'invalid annotator PV target';
    Exit;
  end;

  Command := AActor.CreateRecordAnnotatorPVCommand(ANodeId, AScore,
    APrincipalVariation);
  try
    Result := ExecuteAndApplyGameTreeCommand(AActor, AGameTree, Command,
      False, AErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.RecordEnginePvInGameTree(AActor: TGameTreeActor;
  AGameTree: TGameTree; ANodeId: Int64; const AScore,
  APrincipalVariation: string; out AErrorText: string): Boolean;
var
  Command: TGameTreeCommand;
begin
  Result := False;
  AErrorText := '';
  if (AActor = nil) or (AGameTree = nil) or (ANodeId <= 0) then
  begin
    AErrorText := 'invalid engine PV target';
    Exit;
  end;

  Command := AActor.CreateRecordEnginePVCommand(ANodeId, AScore,
    APrincipalVariation);
  try
    Result := ExecuteGameTreeCommand(AActor, Command, AErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.ClearGameTreeStoredVariations(
  AActor: TGameTreeActor): Boolean;
var
  Command: TGameTreeCommand;
  LErrorText: string;
begin
  Result := False;
  if AActor = nil then
    Exit;

  Command := AActor.CreateClearStoredVariationsCommand;
  try
    Result := ExecuteGameTreeCommand(AActor, Command, LErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.StoreGameTreeVariationLine(AActor: TGameTreeActor;
  ADisplayAfterPly, ABasePly: Integer; const AMovesText,
  AAnnotationText: string; ASource: TGameTreeMoveSource;
  out AErrorText: string): Boolean;
var
  Command: TGameTreeCommand;
begin
  Result := False;
  AErrorText := '';
  if (AActor = nil) or (ADisplayAfterPly < 0) or (ABasePly < 0) then
  begin
    AErrorText := 'invalid variation line target';
    Exit;
  end;

  Command := AActor.CreateStoreVariationLineCommand(ADisplayAfterPly,
    ABasePly, AMovesText, AAnnotationText, ASource);
  try
    Result := ExecuteGameTreeCommand(AActor, Command, AErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.TryResolveActiveSearchSnapshot(ASnapshot: TPvSnapshot;
  out AActor: TGameTreeActor; out AGameTree: TGameTree;
  out ANode: TGameTreePlyNode): Boolean;
var
  LSearch: TGameTreeSearchRef;
  LSearchState: TGameTreeSearchState;
begin
  Result := False;
  AActor := nil;
  AGameTree := nil;
  ANode := nil;
  if ASnapshot = nil then
    LSearch := EmptyGameTreeSearchRef
  else
    LSearch := ASnapshot.SearchRef;
  if not IsValidGameTreeSearchRef(LSearch) then
    Exit;

  AActor := ActorForSearchRef(LSearch);
  if AActor = nil then
    Exit;
  if (not AActor.SearchState(LSearch, LSearchState)) or
    (LSearchState <> gssActive) then
  begin
    AActor := nil;
    Exit;
  end;
  ANode := AActor.GameTree.FindNodeById(LSearch.NodeId);
  if ANode = nil then
  begin
    AActor := nil;
    AGameTree := nil;
    Exit;
  end;

  AGameTree := AActor.GameTree;
  Result := AGameTree <> nil;
end;

procedure TMainForm.TrackAnalyzerSearch(const ASearch: TGameTreeSearchRef);
begin
  if not IsValidGameTreeSearchRef(ASearch) then
  begin
    ClearAnalyzerSearchTracking;
    Exit;
  end;

  FAnalyzerSearch := ASearch;
end;

procedure TMainForm.ClearAnalyzerSearchTracking;
begin
  FAnalyzerSearch := EmptyGameTreeSearchRef;
end;

procedure TMainForm.SetAnalyzerPvBase(ABoard: TDraughtsBoard; APly: Integer);
begin
  if ABoard <> nil then
    FAnalyzerPvBaseBoard.AssignFrom(ABoard);
  FAnalyzerPvBasePly := APly;
end;

procedure TMainForm.InvalidateAnalyzerPositionSignature;
begin
  FAnalyzerLastPositionSignature := '';
end;

procedure TMainForm.InvalidateMctsPositionSignature;
begin
  FMctsLastPositionSignature := '';
end;

procedure TMainForm.ApplyGameTreeCommandResult(AGameTree: TGameTree;
  ACommand: TGameTreeCommand; AFollowVariationBrowse: Boolean);
begin
  if (AGameTree = nil) or (ACommand = nil) or (not ACommand.Accepted) then
    Exit;

  if AFollowVariationBrowse and (AGameTree = ActiveGameTree) and
    (ACommand.CommandKind in [gtcStoreSearchMoveVariation,
      gtcStoreMoveVariation]) and (ACommand.VariationIndex >= 0) then
  begin
    FGameBrowsePly := ACommand.BasePly;
    FVariationIndex := ACommand.VariationIndex;
    FVariationBrowsePly := ACommand.PlyNumber;
    UpdateBoardFromBrowseState(AGameTree);
    UpdateBrowseInfo;
  end;

  RefreshDisplayedGameTreeViews(AGameTree, True);
end;

function TMainForm.ExecuteGameTreeRebuildFromInput(AGame: TRunningGame;
  AGameTree: TGameTree; AMoves, AAnnotations: TStrings): Boolean;
var
  Actor: TGameTreeActor;
  LErrorText: string;
  LVariationPvIndex: Integer;
  LVariationPvPly: Integer;
  LVariationPvScore: string;
  LVariationPvText: string;
begin
  Result := False;
  Actor := ActorForGameTree(AGameTree);
  if Actor = nil then
    Exit;

  LVariationPvIndex := -1;
  LVariationPvPly := 0;
  LVariationPvScore := '';
  LVariationPvText := '';
  if (AGameTree = ActiveGameTree) and
    CanRecordCurrentVariationAnnotatorPV(FVariationIndex,
      FVariationBrowsePly) then
  begin
    LVariationPvIndex := FVariationIndex;
    LVariationPvPly := FVariationBrowsePly;
    LVariationPvScore := FAnalyzerPvBrowser.Score;
    LVariationPvText := FAnalyzerPvBrowser.PrincipalVariation;
  end;

  Result := RebuildGameTreeFromInputs(Actor,
    CurrentGameTreeHeaderInput(AGame, AGameTree),
    GameTreeMainlineInput(AMoves, AAnnotations,
      (AGame <> nil) and (AGame = SelectedDisplayedGame),
      FWhiteRemainingSeconds, FBlackRemainingSeconds, FWhiteUsedSeconds,
      FBlackUsedSeconds),
    CurrentGameTreeEnginePvInput(AGameTree),
    CurrentGameTreeAnnotatorPvInput(AGameTree),
    LVariationPvIndex, LVariationPvPly, LVariationPvScore,
    LVariationPvText, LErrorText);
end;

function TMainForm.FindHumanMoveToTarget(ATargetSquare: Integer;
  out AMove: string): Boolean;
var
  I: Integer;
begin
  AMove := '';
  Result := False;
  if FHumanMoveChoices = nil then
    Exit;
  for I := 0 to FHumanMoveChoices.Count - 1 do
    if MoveSquareAt(FHumanMoveChoices[I], 2) = ATargetSquare then
    begin
      AMove := FHumanMoveChoices[I];
      Exit(True);
    end;
end;

procedure TMainForm.PlayHumanMove(const AMove: string;
  ASource: TGameTreeMoveSource);
var
  LBoard: TDraughtsBoard;
  LGame: TRunningGame;
  LGameTree: TGameTree;
  LMove: string;
begin
  LBoard := ActiveBoard;
  LMove := NormalizeMoveNotation(AMove);
  if (LBoard = nil) or (not LBoard.IsLegalMove(LMove)) then
    Exit;

  ClearHumanMoveSelection;
  if CanExploreVariation then
  begin
    AddVariationMove(LMove, ASource);
    Exit;
  end;

  LGame := SelectedDisplayedGame;
  if (LGame <> nil) and
    (LGame.Snapshot.State in [gosStopped, gosGameOver]) and
    (FGameBrowsePly < 0) then
  begin
    LGameTree := ActiveGameTree;
    if LGameTree = nil then
      Exit;
    if ExecuteGameTreeAppendMainlineMove(LGameTree, LMove, ASource) = nil then
      Exit;
    ClearVariationExploration;
    FGameBrowsePly := -1;
    FGameResult := '*';
    UpdateBoardFromBrowseState(LGameTree);
    UpdateBrowseInfo;
    UpdateBoardInfo;
    UpdateLegalMoves;
    Exit;
  end;

  if (LGame <> nil) and (LGame.Runner <> nil) and
    (LGame.Snapshot.State = gosRunning) and LGame.IsHumanToMove then
    LGame.Runner.PostHumanMove(LMove);
end;

procedure TMainForm.AddVariationMove(const AMove: string;
  ASource: TGameTreeMoveSource);
var
  Actor: TGameTreeActor;
  LErrorText: string;
  LGameTree: TGameTree;
  LMove: string;
  LNode: TGameTreePlyNode;
begin
  LGameTree := ActiveGameTree;
  if LGameTree = nil then
    Exit;

  LMove := NormalizeMoveNotation(AMove);
  if (FGameBrowsePly < 0) or (LMove = '') then
    Exit;

  LNode := CurrentDisplayedGameTreeNode(LGameTree);
  Actor := ActorForGameTree(LGameTree);
  if (LNode = nil) or (Actor = nil) then
    Exit;

  StoreMoveVariation(Actor, LGameTree, LNode.NodeId, LMove, ASource,
    LErrorText);
end;

procedure TMainForm.SelectHumanMoveSource(ASourceSquare: Integer);
var
  I, J: Integer;
  LBoard: TDraughtsBoard;
  LMove: string;
  LTarget: Integer;
  LTargets: TIntArray;
  LTargetKnown: Boolean;
begin
  LTargets := nil;
  ClearHumanMoveSelection;
  if (not CanAcceptHumanBoardMove) and (not CanExploreVariation) then
    Exit;

  LBoard := ActiveBoard;
  if LBoard = nil then
    Exit;

  for I := 0 to LBoard.LegalMoves.Count - 1 do
  begin
    LMove := Trim(LBoard.LegalMoves[I]);
    if MoveSquareAt(LMove, 1) = ASourceSquare then
      FHumanMoveChoices.Add(LMove);
  end;

  if FHumanMoveChoices.Count = 0 then
    Exit;
  if FHumanMoveChoices.Count = 1 then
  begin
    PlayHumanMove(FHumanMoveChoices[0]);
    Exit;
  end;

  FHumanMoveSourceSquare := ASourceSquare;
  SetLength(LTargets, 0);
  for I := 0 to FHumanMoveChoices.Count - 1 do
  begin
    LTarget := MoveSquareAt(FHumanMoveChoices[I], 2);
    LTargetKnown := False;
    for J := 0 to High(LTargets) do
      if LTargets[J] = LTarget then
      begin
        LTargetKnown := True;
        Break;
      end;
    if (LTarget > 0) and (not LTargetKnown) then
    begin
      SetLength(LTargets, Length(LTargets) + 1);
      LTargets[High(LTargets)] := LTarget;
    end;
  end;
  if FBoardControl <> nil then
    FBoardControl.SetTargetSquares(LTargets);
end;

procedure TMainForm.BoardMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
var
  LMove: string;
  LSquare: Integer;
begin
  if Button <> mbLeft then
    Exit;
  if FBoardControl = nil then
    Exit;

  LSquare := FBoardControl.SquareAtPoint(X, Y);
  if LSquare <= 0 then
  begin
    ClearHumanMoveSelection;
    Exit;
  end;

  if (FHumanMoveSourceSquare > 0) and FindHumanMoveToTarget(LSquare, LMove) then
  begin
    PlayHumanMove(LMove);
    Exit;
  end;

  SelectHumanMoveSource(LSquare);
end;

procedure TMainForm.AnalyzerLog(Sender: TObject; const AMessage: string);
begin
  PostGuiEvent(TAnalyzerLogGuiMessage.Create(AMessage));
end;

procedure TMainForm.AnalyzerFinished(Sender: TObject);
begin
  PostGuiEvent(TAnalyzerFinishedGuiMessage.Create(TAnalyzerRunnerThread(Sender)));
end;

procedure TMainForm.AnalyzerSnapshot(Sender: TObject; ASnapshot: TPvSnapshot);
begin
  if ASnapshot = nil then
    Exit;
  PostGuiEvent(TAnalyzerSnapshotGuiMessage.Create(ASnapshot));
end;

procedure TMainForm.AnalyzerMove(Sender: TObject;
  const ASearch: TGameTreeSearchRef; const AMoveText: string);
begin
  PostGuiEvent(TAnalyzerMoveGuiMessage.Create(ASearch, AMoveText));
end;

procedure TMainForm.MctsLog(Sender: TObject; const AMessage: string);
begin
  PostGuiEvent(TMctsLogGuiMessage.Create(AMessage));
end;

procedure TMainForm.MctsFinished(Sender: TObject);
begin
  PostGuiEvent(TMctsFinishedGuiMessage.Create(TAnalyzerRunnerThread(Sender)));
end;

procedure TMainForm.HandleAnalyzerLog(const AMessage: string);
begin
  if FAnalyzerMemo = nil then
    Exit;
  FAnalyzerMemo.Lines.Add(AMessage);
  ScrollMemoToLastTextLine(FAnalyzerMemo);
end;

procedure TMainForm.HandleAnalyzerMove(const ASearch: TGameTreeSearchRef;
  const AMoveText: string);
var
  Actor: TGameTreeActor;
  LAccepted: Boolean;
  LErrorText: string;
  LRejectedReason: string;
begin
  Actor := ActorForSearchRef(ASearch);
  if Actor = nil then
  begin
    if FAnalyzerMemo <> nil then
      FAnalyzerMemo.Lines.Add('Annotator move rejected; game tree not found');
    Exit;
  end;

  LAccepted := AcceptSearchMove(Actor, ASearch, AMoveText, LErrorText);

  if LAccepted then
  begin
    if FAnalyzerMemo <> nil then
      FAnalyzerMemo.Lines.Add('Annotator move accepted; move=' +
        Trim(AMoveText));
    if (not StoreSearchMoveVariation(Actor, ASearch, gmsAutoplay,
      LErrorText)) and (FAnalyzerMemo <> nil) then
      FAnalyzerMemo.Lines.Add('Autoplay move was not recorded; reason=' +
        LErrorText);
    ReleaseGameTreeSearch(Actor, ASearch);
    if AnalyzerSearchMatches(ASearch) then
      ClearAnalyzerSearchTracking;
  end
  else
  begin
    LRejectedReason := LErrorText;
    ReleaseRejectedSearchIfFinished(Actor, ASearch);
    if FAnalyzerMemo <> nil then
      FAnalyzerMemo.Lines.Add('Annotator move rejected; reason=' +
        LRejectedReason);
  end;
end;

procedure TMainForm.HandleMctsLog(const AMessage: string);
begin
  if FMctsMemo = nil then
    Exit;
  UpdateMctsStatsFromLog(AMessage);
  FMctsMemo.Lines.Add(AMessage);
  ScrollMemoToLastTextLine(FMctsMemo);
end;

procedure TMainForm.ScrollMemoToLastTextLine(AMemo: TMemo);
var
  LastLineIndex: Integer;
  LastTextPoint: TPoint;
begin
  if (AMemo = nil) or (AMemo.Lines.Count = 0) then
    Exit;

  LastLineIndex := AMemo.Lines.Count - 1;
  LastTextPoint.X := 0;
  LastTextPoint.Y := LastLineIndex;
  AMemo.CaretPos := LastTextPoint;
end;

procedure TMainForm.ClearMctsStatsGrid;
const
  Labels: array[0..7] of string = (
    'nshootouts',
    'nwon',
    'ndraw',
    'nlost',
    '(W-L)/N',
    'won lcb',
    'lost ucb',
    'lcb-ucb'
  );
var
  I: Integer;
begin
  if FMctsStatsGrid = nil then
    Exit;

  FMctsStatsGrid.RowCount := Length(Labels);
  for I := 0 to High(Labels) do
  begin
    FMctsStatsGrid.Cells[0, I] := Labels[I];
    FMctsStatsGrid.Cells[1, I] := '';
  end;
end;

procedure TMainForm.UpdateMctsStatsFromLog(const AMessage: string);
const
  Z95 = 1.95996398454005;

  function MctsFloatText(AValue: Double): string;
  var
    FormatSettings: TFormatSettings;
  begin
    FormatSettings := DefaultFormatSettings;
    FormatSettings.DecimalSeparator := '.';
    Result := FormatFloat('0.000000', AValue, FormatSettings);
  end;

  procedure WilsonBounds(ASuccesses, ATotal: Int64; out ALower, AUpper: Double);
  var
    Center: Double;
    Denominator: Double;
    Margin: Double;
    P: Double;
    N: Double;
  begin
    ALower := 0.0;
    AUpper := 0.0;
    if ATotal <= 0 then
      Exit;

    N := ATotal;
    P := ASuccesses / N;
    Denominator := 1.0 + Sqr(Z95) / N;
    Center := P + Sqr(Z95) / (2.0 * N);
    Margin := Z95 * Sqrt((P * (1.0 - P) + Sqr(Z95) / (4.0 * N)) / N);
    ALower := (Center - Margin) / Denominator;
    AUpper := (Center + Margin) / Denominator;
  end;

  procedure SetValue(ARow: Integer; const AValue: string);
  begin
    if (FMctsStatsGrid <> nil) and (ARow >= 0) and
      (ARow < FMctsStatsGrid.RowCount) then
      FMctsStatsGrid.Cells[1, ARow] := AValue;
  end;

var
  DrawCount: Int64;
  LostCount: Int64;
  LossLower: Double;
  LossUpper: Double;
  Payload: string;
  PayloadPos: SizeInt;
  ShootOuts: Int64;
  Total: Int64;
  WinLower: Double;
  WinUpper: Double;
  WonCount: Int64;
begin
  if FMctsStatsGrid = nil then
    Exit;

  PayloadPos := Pos('stdout; text=', LowerCase(AMessage));
  if PayloadPos = 0 then
    Exit;
  Payload := Trim(Copy(AMessage, PayloadPos + Length('stdout; text='), MaxInt));
  PayloadPos := Pos('\n', Payload);
  if PayloadPos > 0 then
    Delete(Payload, PayloadPos, MaxInt);
  Payload := Trim(Payload);

  if Pos('info ', LowerCase(Payload)) <> 1 then
    Exit;

  if not TryStrToInt64(ExtractHubArgument(Payload, 'nwon'), WonCount) then
    WonCount := 0;
  if not TryStrToInt64(ExtractHubArgument(Payload, 'ndraw'), DrawCount) then
    DrawCount := 0;
  if not TryStrToInt64(ExtractHubArgument(Payload, 'nlost'), LostCount) then
    LostCount := 0;

  Total := WonCount + DrawCount + LostCount;
  ShootOuts := Total;
  SetValue(0, IntToStr(ShootOuts));
  SetValue(1, IntToStr(WonCount));
  SetValue(2, IntToStr(DrawCount));
  SetValue(3, IntToStr(LostCount));
  if Total > 0 then
  begin
    SetValue(4, MctsFloatText((WonCount - LostCount) / Total));
    WilsonBounds(WonCount, Total, WinLower, WinUpper);
    WilsonBounds(LostCount, Total, LossLower, LossUpper);
    SetValue(5, MctsFloatText(WinLower));
    SetValue(6, MctsFloatText(LossUpper));
    SetValue(7, MctsFloatText(WinLower - LossUpper));
  end;
end;

procedure TMainForm.HintSourceClick(Sender: TObject);
begin
  if Sender = FHintFromAnalyzerMenuItem then
    FPvHintSource := phsAnalyzer
  else
    FPvHintSource := phsMain;

  if FHintFromMainMenuItem <> nil then
    FHintFromMainMenuItem.Checked := FPvHintSource = phsMain;
  if FHintFromAnalyzerMenuItem <> nil then
    FHintFromAnalyzerMenuItem.Checked := FPvHintSource = phsAnalyzer;

  UpdateBoardHighlights(ActiveGameTree);
  if FBoardControl <> nil then
    FBoardControl.Invalidate;
  UpdateDatabaseSearchPosition;
end;

procedure TMainForm.AnalyzerPopupPopup(Sender: TObject);
var
  BusyKeys: TStringList;
  EngineKey: string;
  Engines: TExternalEngineList;
  I: Integer;
  Item: TMenuItem;
begin
  FAnalyzerOpenMenuItem.Clear;
  FAnalyzerOpenMenuItem.Enabled := FAnalyzerRunner = nil;
  FAnalyzerCloseMenuItem.Enabled := FAnalyzerRunner <> nil;
  UpdateAutoplayControls;

  if FAnalyzerRunner <> nil then
    Exit;

  BusyKeys := TStringList.Create;
  Engines := TExternalEngineList.Create;
  try
    BusyKeys.Sorted := True;
    BusyKeys.Duplicates := dupIgnore;
    CollectBusyEngineKeys(BusyKeys);
    LoadExternalEngines(EnginesJsonFileName, Engines);
    for I := 0 to Engines.Count - 1 do
    begin
      if Engines[I].Kind <> eekHub then
        Continue;
      EngineKey := EngineIdentityKey(Engines[I]);
      if BusyKeys.IndexOf(EngineKey) >= 0 then
        Continue;
      Item := TMenuItem.Create(Self);
      Item.Caption := EnginePickerDisplayName(Engines[I], I + 1);
      Item.Hint := EngineKey;
      Item.OnClick := @OpenAnalyzerClick;
      FAnalyzerOpenMenuItem.Add(Item);
    end;
  finally
    Engines.Free;
    BusyKeys.Free;
  end;

  if FAnalyzerOpenMenuItem.Count = 0 then
  begin
    Item := TMenuItem.Create(Self);
    Item.Caption := '(no available Hub engines)';
    Item.Enabled := False;
    FAnalyzerOpenMenuItem.Add(Item);
  end;
end;

function TMainForm.ReadAutoplaySecondsFromToolbar: Boolean;
var
  LText: string;
  LValue: Double;
begin
  Result := True;
  if FAutoplaySecondsEdit = nil then
    Exit;
  LText := Trim(FAutoplaySecondsEdit.Text);
  if (not TryStrToFloat(LText, LValue)) or (LValue <= 0) then
  begin
    Result := False;
    ShowGuiOkDialog(Self, 'Autoplay',
      'Enter a positive number of seconds for autoplay.');
    Exit;
  end;
  FAutoplayThinkSeconds := LValue;
end;

procedure TMainForm.UpdateAutoplayControls;
begin
  if FAutoplayButton <> nil then
  begin
    FAutoplayButton.Caption := 'Autoplay';
    FAutoplayButton.Enabled := CanStartAutoplay;
  end;
  if FAutoplaySecondsEdit <> nil then
  begin
    FAutoplaySecondsEdit.Enabled := True;
    if not FAutoplaySecondsEdit.Focused then
      FAutoplaySecondsEdit.Text := FloatToStr(FAutoplayThinkSeconds);
  end;
  if FAutorandomButton <> nil then
    FAutorandomButton.Enabled := HasLegalDisplayedMove;
end;

procedure TMainForm.AutoplayClick(Sender: TObject);
var
  LDisplayedMoveCount: Integer;
  LDisplayedMovesText: string;
  LErrorText: string;
  LGameTree: TGameTree;
  LSearch: TGameTreeSearchRef;
  LStartingFEN: string;
begin
  if not ReadAutoplaySecondsFromToolbar then
  begin
    UpdateAutoplayControls;
    Exit;
  end;

  ApplyGameMoveMemoCaretBrowse;

  if not CanStartAutoplay then
  begin
    if FAnalyzerMemo <> nil then
      FAnalyzerMemo.Lines.Add('Autoplay rejected; unavailable position');
    UpdateAutoplayControls;
    Exit;
  end;

  if FAnalyzerRunner = nil then
  begin
    ShowGuiOkDialog(Self, 'Autoplay',
      'Open an annotator before using autoplay.');
    UpdateAutoplayControls;
    Exit;
  end;

  if not HasLegalDisplayedMove then
  begin
    ShowGuiOkDialog(Self, 'Autoplay',
      'The displayed position has no legal moves.');
    UpdateAutoplayControls;
    Exit;
  end;

  LGameTree := ActiveGameTree;
  if LGameTree = nil then
  begin
    UpdateAutoplayControls;
    Exit;
  end;

  LStartingFEN := StartingFenForTree(LGameTree);
  if not DisplayedMoveContext(LGameTree, LDisplayedMovesText,
    LDisplayedMoveCount) then
  begin
    UpdateAutoplayControls;
    Exit;
  end;

  CancelAnalyzerSearch;
  if not TryStartGameTreeSearchForDisplayedNode(LGameTree, LSearch,
    LErrorText) then
  begin
    if FAnalyzerMemo <> nil then
      FAnalyzerMemo.Lines.Add('Autoplay rejected; reason=' + LErrorText);
    UpdateAutoplayControls;
    Exit;
  end;

  TrackAnalyzerSearch(LSearch);
  InvalidateAnalyzerPositionSignature;
  SetAnalyzerPvBase(ActiveBoard, LDisplayedMoveCount);

  if FAnalyzerMemo <> nil then
    FAnalyzerMemo.Lines.Add(Format('Autoplay thinking; time=%.3g seconds',
      [FAutoplayThinkSeconds]));
  FAnalyzerRunner.PostThinkOnce(LStartingFEN, LDisplayedMovesText,
    FAnalyzerPvBaseBoard, FAnalyzerPvBasePly, FAutoplayThinkSeconds,
    LSearch);
  UpdateAutoplayControls;
end;

procedure TMainForm.AutorandomClick(Sender: TObject);
var
  LBoard: TDraughtsBoard;
  LMove: string;
begin
  LBoard := ActiveBoard;
  if (LBoard = nil) or (LBoard.LegalMoves.Count = 0) then
  begin
    ShowGuiOkDialog(Self, 'Autorandom',
      'The displayed position has no legal moves.');
    Exit;
  end;

  LMove := LBoard.LegalMoves[Random(LBoard.LegalMoves.Count)];
  PlayHumanMove(LMove, gmsAutorandom);
end;

procedure TMainForm.OpenAnalyzerClick(Sender: TObject);
var
  Engine: TExternalEngineDefinition;
  EngineKey: string;
  Engines: TExternalEngineList;
  I: Integer;
begin
  if FAnalyzerRunner <> nil then
    Exit;
  if not (Sender is TMenuItem) then
    Exit;

  EngineKey := TMenuItem(Sender).Hint;
  Engines := TExternalEngineList.Create;
  try
    LoadExternalEngines(EnginesJsonFileName, Engines);
    Engine := nil;
    for I := 0 to Engines.Count - 1 do
      if (Engines[I].Kind = eekHub) and
        (EngineIdentityKey(Engines[I]) = EngineKey) then
      begin
        Engine := Engines[I];
        Break;
      end;
    if Engine = nil then
      Exit;

    FAnalyzerMemo.Clear;
    if FAnalyzerPvBrowser <> nil then
      FAnalyzerPvBrowser.Clear;
    FAnalyzerEngineKey := EngineKey;
    InvalidateAnalyzerPositionSignature;
    FAnalyzerRunner := TAnalyzerRunnerThread.Create(Engine, @AnalyzerLog,
      @AnalyzerSnapshot, @AnalyzerFinished, armAnalyze, @AnalyzerMove);
    FAnalyzerRunner.Start;
    UpdateAutoplayControls;
    RestartAnalyzer(ActiveGameTree);
  finally
    Engines.Free;
  end;
end;

procedure TMainForm.CloseAnalyzerClick(Sender: TObject);
begin
  UpdateAutoplayControls;
  CancelAnalyzerSearch;
  if FAnalyzerRunner <> nil then
  begin
    if FAnalyzerMemo <> nil then
      FAnalyzerMemo.Lines.Add('Closing Annotator');
    FAnalyzerRunner.PostShutdown;
  end;
  FAnalyzerEngineKey := '';
  InvalidateAnalyzerPositionSignature;
  if FAnalyzerPvBrowser <> nil then
    FAnalyzerPvBrowser.Clear;
end;

procedure TMainForm.CancelAnalyzerSearch;
var
  Actor: TGameTreeActor;
begin
  if not IsValidGameTreeSearchRef(FAnalyzerSearch) then
    Exit;

  Actor := ActorForSearchRef(FAnalyzerSearch);
  if CancelGameTreeSearch(Actor, FAnalyzerSearch) then
    ReleaseGameTreeSearch(Actor, FAnalyzerSearch);

  ClearAnalyzerSearchTracking;
end;

procedure TMainForm.MctsPopupPopup(Sender: TObject);
var
  BusyKeys: TStringList;
  EngineKey: string;
  Engines: TExternalEngineList;
  I: Integer;
  Item: TMenuItem;
begin
  FMctsOpenMenuItem.Clear;
  FMctsOpenMenuItem.Enabled := FMctsRunner = nil;
  FMctsCloseMenuItem.Enabled := FMctsRunner <> nil;

  if FMctsRunner <> nil then
    Exit;

  BusyKeys := TStringList.Create;
  Engines := TExternalEngineList.Create;
  try
    BusyKeys.Sorted := True;
    BusyKeys.Duplicates := dupIgnore;
    CollectBusyEngineKeys(BusyKeys);
    LoadExternalEngines(EnginesJsonFileName, Engines);
    for I := 0 to Engines.Count - 1 do
    begin
      if not EngineSupportsMcts(Engines[I]) then
        Continue;
      EngineKey := EngineIdentityKey(Engines[I]);
      if BusyKeys.IndexOf(EngineKey) >= 0 then
        Continue;
      Item := TMenuItem.Create(Self);
      Item.Caption := EnginePickerDisplayName(Engines[I], I + 1);
      Item.Hint := EngineKey;
      Item.OnClick := @OpenMctsClick;
      FMctsOpenMenuItem.Add(Item);
    end;
  finally
    Engines.Free;
    BusyKeys.Free;
  end;

  if FMctsOpenMenuItem.Count = 0 then
  begin
    Item := TMenuItem.Create(Self);
    Item.Caption := '(no available MCTS Hub engines)';
    Item.Enabled := False;
    FMctsOpenMenuItem.Add(Item);
  end;
end;

procedure TMainForm.OpenMctsClick(Sender: TObject);
var
  Engine: TExternalEngineDefinition;
  EngineKey: string;
  Engines: TExternalEngineList;
  I: Integer;
begin
  if FMctsRunner <> nil then
    Exit;
  if not (Sender is TMenuItem) then
    Exit;

  EngineKey := TMenuItem(Sender).Hint;
  Engines := TExternalEngineList.Create;
  try
    LoadExternalEngines(EnginesJsonFileName, Engines);
    Engine := nil;
    for I := 0 to Engines.Count - 1 do
      if (EngineIdentityKey(Engines[I]) = EngineKey) and
        EngineSupportsMcts(Engines[I]) then
      begin
        Engine := Engines[I];
        Break;
      end;
    if Engine = nil then
      Exit;

    FMctsMemo.Clear;
    ClearMctsStatsGrid;
    FMctsEngineKey := EngineKey;
    InvalidateMctsPositionSignature;
    FMctsRunner := TAnalyzerRunnerThread.Create(Engine, @MctsLog, nil,
      @MctsFinished, armMcts);
    FMctsRunner.Start;
    RestartMctsAnnotator(ActiveGameTree);
  finally
    Engines.Free;
  end;
end;

procedure TMainForm.CloseMctsClick(Sender: TObject);
begin
  if FMctsRunner <> nil then
  begin
    if FMctsMemo <> nil then
      FMctsMemo.Lines.Add('Closing MCTS annotator');
    FMctsRunner.PostShutdown;
  end;
  FMctsEngineKey := '';
  InvalidateMctsPositionSignature;
  ClearMctsStatsGrid;
end;

procedure TMainForm.RestartAnalyzer(AGameTree: TGameTree);
var
  LGameTree: TGameTree;
  LSearch: TGameTreeSearchRef;
  LDisplayedMoveCount: Integer;
  LDisplayedMovesText: string;
  LErrorText: string;
  LGameState: TGameOrchestratorState;
  LStartingFEN: string;
  LTotalMoveCount: Integer;
  LTerminal: Boolean;
  Signature: string;
begin
  if FAnalyzerRunner = nil then
    Exit;

  LGameTree := AGameTree;
  if LGameTree = nil then
    Exit;
  LSearch := EmptyGameTreeSearchRef;

  LStartingFEN := StartingFenForTree(LGameTree);
  if not DisplayedMoveContext(LGameTree, LDisplayedMovesText,
    LDisplayedMoveCount) then
    Exit;
  LTotalMoveCount := LGameTree.MainlineCount;
  LGameState := StateForTree(LGameTree);

  Signature := DisplayedPositionSignature(LStartingFEN, LDisplayedMovesText,
    LGameState);
  if Signature = FAnalyzerLastPositionSignature then
    Exit;
  FAnalyzerLastPositionSignature := Signature;
  CancelAnalyzerSearch;

  SetAnalyzerPvBase(ActiveBoard, LDisplayedMoveCount);
  LTerminal := DisplayedPositionIsTerminal(LDisplayedMoveCount,
    LTotalMoveCount, LGameState);
  if LTerminal and (FAnalyzerPvBrowser <> nil) then
    FAnalyzerPvBrowser.Clear;
  if not LTerminal then
  begin
    if TryStartGameTreeSearchForDisplayedNode(LGameTree, LSearch,
      LErrorText) then
      TrackAnalyzerSearch(LSearch);
  end;
  FAnalyzerRunner.PostAnalyze(LStartingFEN, LDisplayedMovesText,
    FAnalyzerPvBaseBoard, FAnalyzerPvBasePly, LTerminal,
    LSearch);
end;

procedure TMainForm.RestartMctsAnnotator(AGameTree: TGameTree);
var
  LGameTree: TGameTree;
  LDisplayedMoveCount: Integer;
  LDisplayedMovesText: string;
  LGameState: TGameOrchestratorState;
  LStartingFEN: string;
  LTotalMoveCount: Integer;
  LTerminal: Boolean;
  Signature: string;
begin
  if FMctsRunner = nil then
    Exit;

  LGameTree := AGameTree;
  if LGameTree = nil then
    Exit;
  LStartingFEN := StartingFenForTree(LGameTree);
  if not DisplayedMoveContext(LGameTree, LDisplayedMovesText,
    LDisplayedMoveCount) then
    Exit;
  LTotalMoveCount := LGameTree.MainlineCount;
  LGameState := StateForTree(LGameTree);

  Signature := DisplayedPositionSignature(LStartingFEN, LDisplayedMovesText,
    LGameState);
  if Signature = FMctsLastPositionSignature then
    Exit;
  FMctsLastPositionSignature := Signature;
  ClearMctsStatsGrid;

  LTerminal := DisplayedPositionIsTerminal(LDisplayedMoveCount,
    LTotalMoveCount, LGameState);
  FMctsRunner.PostAnalyze(LStartingFEN, LDisplayedMovesText, ActiveBoard,
    LDisplayedMoveCount, LTerminal, EmptyGameTreeSearchRef);
end;

function TMainForm.LiveGameCount: Integer;
var
  I: Integer;
  LGame: TRunningGame;
begin
  Result := 0;
  for I := 0 to FGames.Count - 1 do
  begin
    LGame := TRunningGame(FGames[I]);
    if LGame.Lifecycle <> rglFinished then
      Inc(Result);
  end;
end;

procedure TMainForm.CloseQueryHandler(Sender: TObject; var CanClose: Boolean);
var
  LLiveGames: Integer;
  LMessage: string;
  LResponse: Integer;
begin
  CanClose := False;
  if FClosing then
  begin
    CanClose := True;
    Exit;
  end;

  if (FTournamentDialog <> nil) and FTournamentDialog.HasTournamentData then
  begin
    LResponse := ShowGuiConfirmationDialog(Self, 'Close GWDGUI',
      'Save the tournament JSON before closing?', 'Yes', 'No', mrNo);
    if LResponse = mrCancel then
      Exit;
    if (LResponse = mrYes) and (not FTournamentDialog.SaveTournamentWithDialog) then
      Exit;
  end;

  if HasDisplayedGameToSave then
  begin
    LResponse := ShowGuiConfirmationDialog(Self, 'Close GWDGUI',
      'Save the currently displayed game as PDN before closing?', 'Yes',
      'No', mrNo);
    if LResponse = mrCancel then
      Exit;
    if (LResponse = mrYes) and (not SaveCurrentGameWithDialog) then
      Exit;
  end;

  LLiveGames := LiveGameCount;
  if (LLiveGames > 0) or
    ((FTournamentDialog <> nil) and FTournamentDialog.IsRunning) then
  begin
    LMessage := 'Closing will stop ';
    if LLiveGames = 1 then
      LMessage += '1 running game'
    else
      LMessage += IntToStr(LLiveGames) + ' running games';
    if (FTournamentDialog <> nil) and FTournamentDialog.IsRunning then
      LMessage += ' and the running tournament scheduler';
    LMessage += '. Close anyway?';

    if ShowGuiConfirmationDialog(Self, 'Close GWDGUI', LMessage, 'Yes',
      'No', mrNo) <> mrYes then
      Exit;
  end;

  CanClose := True;
end;

procedure TMainForm.CopyBoardFenClick(Sender: TObject);
var
  LFen: string;
begin
  LFen := FBoard.CurrentFEN;
  Clipboard.AsText := LFen;
end;

procedure TMainForm.SetupPositionAccepted(Sender: TObject; const AFEN: string);
begin
  try
    LoadStandaloneFen(AFEN);
  except
    on E: Exception do
      ShowGuiOkDialog(Self, 'Setup position', 'Invalid FEN: ' + E.Message);
  end;
end;

procedure TMainForm.SetupPositionClick(Sender: TObject);
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

procedure TMainForm.LoadStandaloneFen(const AFEN: string);
var
  LBoard: TDraughtsBoard;
begin
  ClearHumanMoveSelection;
  LBoard := TDraughtsBoard.Create;
  try
    LBoard.LoadFromFEN(AFEN);
    FBoard.AssignFrom(LBoard);
  finally
    LBoard.Free;
  end;

  FGameActive := False;
  FGameState := gosWaiting;
  FGameResult := '*';
  FStartingFEN := FBoard.StartingFEN;
  FDisplayedAnnotationsSignature := '';
  FDisplayedMovesSignature := '';
  FDisplayedSnapshotSignature := '';
  FDisplayedGameTreeId := 0;
  FDisplayedGameTreeRevision := -1;
  ClearStoredTreeVariations(FGameTree);
  FStandaloneWhitePlayerName := 'White';
  FStandaloneBlackPlayerName := 'Black';
  FStandaloneEventName := '?';
  FPrincipalVariation := '';
  FPrincipalVariationScore := '';
  FPrincipalVariationDepth := '';
  FPrincipalVariationTimeText := '';
  FGameBrowsePly := -1;
  FPvBaseBoard.AssignFrom(FBoard);
  FPvBasePly := 0;
  FWhiteRemainingSeconds := 0;
  FBlackRemainingSeconds := 0;
  FWhiteUsedSeconds := 0;
  FBlackUsedSeconds := 0;
  FViewedGameId := -1;
  if FGamesListBox <> nil then
    FGamesListBox.ItemIndex := -1;
  FGameLog.Clear;
  FGameLogSourceGameId := -1;
  FGameLogSourceLineCount := -1;
  FGameLogSourceShowStdout := False;
  UpdateMiniBoardFromBoard(FBoard);
  UpdateBoardInfo;
end;

procedure TMainForm.PasteFenClick(Sender: TObject);
var
  LFen: string;
begin
  LFen := Trim(Clipboard.AsText);
  if LFen = '' then
  begin
    ShowGuiOkDialog(Self, 'Paste FEN',
      'Clipboard does not contain a FEN position');
    Exit;
  end;

  try
    LoadStandaloneFen(LFen);
  except
    on E: Exception do
      ShowGuiOkDialog(Self, 'Paste FEN', 'Invalid FEN: ' + E.Message);
  end;
end;

procedure TMainForm.PreferencesAccepted(Sender: TObject;
  const APreferences: TGuiPreferences);
begin
  FPreferences := APreferences;
  SaveGuiPreferences(FPreferences);
  ApplyPreferences;
end;

procedure TMainForm.PreferencesClick(Sender: TObject);
begin
  if FPreferencesForm = nil then
  begin
    FPreferencesForm := TPreferencesForm.Create(Self);
    FPreferencesForm.OnAccepted := @PreferencesAccepted;
  end;
  FPreferencesForm.StartEdit(FPreferences);
  ShowFormCenteredOnOwner(FPreferencesForm, Self);
end;

function TMainForm.RecordAnalyzerSnapshotInGameTree(
  ASnapshot: TPvSnapshot): TGameTree;
var
  Actor: TGameTreeActor;
  LErrorText: string;
  LGame: TRunningGame;
  LGameTree: TGameTree;
  LHasSearch: Boolean;
  LNode: TGameTreePlyNode;
  LNodeId: Int64;
  LSearch: TGameTreeSearchRef;
begin
  Result := nil;
  if ASnapshot = nil then
    Exit;
  if Trim(ASnapshot.Score) = '' then
    Exit;
  if Trim(ASnapshot.PrincipalVariation) = '' then
    Exit;

  Actor := nil;
  LNode := nil;
  LSearch := ASnapshot.SearchRef;
  LHasSearch := IsValidGameTreeSearchRef(LSearch);
  if LHasSearch then
  begin
    if not TryResolveActiveSearchSnapshot(ASnapshot, Actor, LGameTree,
      LNode) then
      Exit;
  end
  else
  begin
    LGame := SelectedDisplayedGame;
    if LGame <> nil then
      LGameTree := LGame.GameTree
    else
      LGameTree := FGameTree;
  end;

  if LGameTree = nil then
    Exit;
  LGame := GameForTree(LGameTree);
  if LGame <> nil then
    UpdateRunningGameTreeFromSnapshot(LGame);
  if LHasSearch and
    (not TryResolveActiveSearchSnapshot(ASnapshot, Actor, LGameTree,
      LNode)) then
    Exit;

  if Actor = nil then
    Actor := ActorForGameTree(LGameTree);
  if Actor = nil then
    Exit;

  if LNode <> nil then
    LNodeId := LNode.NodeId
  else
  begin
    LNodeId := LSearch.NodeId;
    if LNodeId <= 0 then
    begin
      if ASnapshot.BasePly <= 0 then
        LNode := LGameTree.Root
      else
        LNode := LGameTree.MainlineNode[ASnapshot.BasePly];
    end;
    if LNode <> nil then
      LNodeId := LNode.NodeId;
  end;
  if LNodeId <= 0 then
    Exit;

  if not RecordAnnotatorPvInGameTree(Actor, LGameTree, LNodeId,
    ASnapshot.Score, ASnapshot.PrincipalVariation, LErrorText) then
  begin
    if FAnalyzerMemo <> nil then
      FAnalyzerMemo.Lines.Add('Annotator PV rejected; reason=' +
        LErrorText);
    Exit;
  end;
  Result := LGameTree;
end;

procedure TMainForm.LoadPdnGameToDisplay(AGame: TPdnGame);
var
  I: Integer;
  LBoard: TDraughtsBoard;
  LMoves: TStringList;
begin
  if AGame = nil then
    Exit;

  ClearHumanMoveSelection;
  LBoard := TDraughtsBoard.Create;
  LMoves := TStringList.Create;
  try
    LBoard.LoadFromFEN(AGame.StartingFEN);
    TextToMoveList(AGame.MovesText, LMoves);
    for I := 0 to LMoves.Count - 1 do
      try
        LBoard.PlayMove(LMoves[I], True, True);
      except
        on E: Exception do
        begin
          ShowGuiOkDialog(Self, 'Open PDN', 'PDN move ' + IntToStr(I + 1) +
            ' is invalid: ' + LMoves[I] + '; ' + E.Message);
          Exit;
        end;
      end;

    FBoard.AssignFrom(LBoard);
    FGameActive := False;
    FGameState := gosWaiting;
    FGameResult := AGame.ResultText;
    if Trim(FGameResult) = '' then
    FGameResult := '*';
    FStartingFEN := AGame.StartingFEN;
    FDisplayedAnnotationsSignature := AGame.MoveAnnotationsText;
    FDisplayedMovesSignature := AGame.MovesText;
    FDisplayedSnapshotSignature := '';
    FDisplayedGameTreeId := 0;
    FDisplayedGameTreeRevision := -1;
    LoadTreeVariationsFromLegacyText(FGameTree, AGame.MoveVariationsText,
      AGame.MoveVariationAnnotationsText);
    FStandaloneWhitePlayerName := PlayerNameOrFallback(AGame.WhiteName, 'White');
    FStandaloneBlackPlayerName := PlayerNameOrFallback(AGame.BlackName, 'Black');
    FStandaloneEventName := PlayerNameOrFallback(AGame.EventName, '?');
    FPrincipalVariation := '';
    FPrincipalVariationScore := '';
    FPrincipalVariationDepth := '';
    FPrincipalVariationTimeText := '';
    FGameBrowsePly := 0;
    UpdateGameTreeFromMoveText(nil, FGameTree, AGame.MovesText,
      AGame.MoveAnnotationsText);
    FPvBaseBoard.AssignFrom(FBoard);
    FPvBasePly := CurrentMoveCount;
    FWhiteRemainingSeconds := 0;
    FBlackRemainingSeconds := 0;
    FWhiteUsedSeconds := 0;
    FBlackUsedSeconds := 0;
    FViewedGameId := -1;
    if FGamesListBox <> nil then
      FGamesListBox.ItemIndex := -1;
    FGameLog.Clear;
    FGameLogSourceGameId := -1;
    FGameLogSourceLineCount := -1;
    FGameLogSourceShowStdout := False;
    UpdateBoardFromBrowseState(FGameTree);
    UpdateMiniBoardFromBoard(FBoard);
    UpdateBoardInfo;
  finally
    LMoves.Free;
    LBoard.Free;
  end;
end;

function FenSideToMove(const AFEN: string): TDraughtsSide;
begin
  if (Trim(AFEN) <> '') and (UpCase(Trim(AFEN)[1]) = 'B') then
    Result := dsBlack
  else
    Result := dsWhite;
end;

procedure TMainForm.ApplyVariationBrowsePly(AVariationIndex,
  AVariationPly: Integer; AGameTree: TGameTree);
var
  LGameTree: TGameTree;
  LMoveCount: Integer;
  LMoves: TStringList;
  VariationLine: TGameTreeVariationLine;
begin
  ClearHumanMoveSelection;
  LGameTree := AGameTree;
  if LGameTree = nil then
    Exit;
  VariationLine := TreeVariationLineByIndex(AVariationIndex, LGameTree);
  if VariationLine = nil then
    Exit;
  if AVariationPly <= 0 then
  begin
    ApplyGameBrowsePly(VariationLine.BasePly);
    Exit;
  end;

  LMoves := TStringList.Create;
  try
    TextToMoveList(VariationLine.MovesText, LMoves);
    LMoveCount := LMoves.Count;
    if LMoveCount = 0 then
      Exit;
    if AVariationPly > LMoveCount then
      AVariationPly := LMoveCount;

    FGameBrowsePly := VariationLine.BasePly;
    FVariationIndex := AVariationIndex;
    FVariationBrowsePly := AVariationPly;
    { Keep the local move list parsed above to validate the requested ply. }
  finally
    LMoves.Free;
  end;

  UpdateBoardFromBrowseState(LGameTree);
  UpdateBrowseInfo;
end;

function TMainForm.CurrentMoveCount: Integer;
var
  LGameTree: TGameTree;
begin
  Result := 0;
  LGameTree := ActiveGameTree;
  if LGameTree <> nil then
    Result := LGameTree.MainlineCount;
end;

function TMainForm.CurrentDisplayedGameTreeNode(
  AGameTree: TGameTree): TGameTreePlyNode;
var
  LPly: Integer;
begin
  Result := nil;
  if AGameTree = nil then
    Exit;

  if (FVariationIndex >= 0) and (FVariationBrowsePly > 0) then
  begin
    Result := AGameTree.FindVariationNode(FVariationIndex,
      FVariationBrowsePly);
    Exit;
  end;

  if FGameBrowsePly < 0 then
    LPly := AGameTree.MainlineCount
  else
    LPly := FGameBrowsePly;

  if LPly <= 0 then
    Result := AGameTree.Root
  else
    Result := AGameTree.MainlineNode[LPly];
end;

function TMainForm.CurrentVariationMoveCount(AGameTree: TGameTree): Integer;
var
  LMoves: TStringList;
  VariationLine: TGameTreeVariationLine;
begin
  Result := 0;
  VariationLine := TreeVariationLineByIndex(FVariationIndex, AGameTree);
  if VariationLine = nil then
    Exit;

  LMoves := TStringList.Create;
  try
    TextToMoveList(VariationLine.MovesText, LMoves);
    Result := LMoves.Count;
  finally
    LMoves.Free;
  end;
end;

function TMainForm.GameTreeMainlineMovesText(AGameTree: TGameTree): string;
var
  I: Integer;
  LMoves: TStringList;
begin
  Result := '';
  if AGameTree = nil then
    Exit;

  LMoves := TStringList.Create;
  try
    AGameTree.CopyMainlineMovesTo(LMoves);
    for I := 0 to LMoves.Count - 1 do
    begin
      if Result <> '' then
        Result += ' ';
      Result += LMoves[I];
    end;
  finally
    LMoves.Free;
  end;
end;

function TMainForm.DisplayedMovesText(AGameTree: TGameTree): string;
var
  I: Integer;
  LLimit: Integer;
  LMoves: TStringList;
  LPly: Integer;
  VariationLine: TGameTreeVariationLine;
  LVariationMoves: TStringList;
begin
  Result := '';
  if AGameTree = nil then
    Exit;

  LMoves := TStringList.Create;
  LVariationMoves := TStringList.Create;
  try
    AGameTree.CopyMainlineMovesTo(LMoves);
    LPly := FGameBrowsePly;
    if (LPly < 0) or (LPly > LMoves.Count) then
      LPly := LMoves.Count;
    for I := 0 to LPly - 1 do
    begin
      if Result <> '' then
        Result += ' ';
      Result += LMoves[I];
    end;
    VariationLine := TreeVariationLineByIndex(FVariationIndex, AGameTree);
    if (VariationLine <> nil) and (VariationLine.BasePly = LPly) and
      (FVariationBrowsePly > 0) then
    begin
      TextToMoveList(VariationLine.MovesText, LVariationMoves);
      LLimit := FVariationBrowsePly;
      if LLimit > LVariationMoves.Count then
        LLimit := LVariationMoves.Count;
      for I := 0 to LLimit - 1 do
      begin
        if Result <> '' then
          Result += ' ';
        Result += LVariationMoves[I];
      end;
    end;
  finally
    LVariationMoves.Free;
    LMoves.Free;
  end;
end;

function TMainForm.DisplayedMoveContext(AGameTree: TGameTree;
  out AMovesText: string; out AMoveCount: Integer): Boolean;
var
  LMoves: TStringList;
begin
  AMovesText := '';
  AMoveCount := 0;
  Result := AGameTree <> nil;
  if not Result then
    Exit;

  AMovesText := DisplayedMovesText(AGameTree);
  LMoves := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)),
      LMoves);
    AMoveCount := LMoves.Count;
  finally
    LMoves.Free;
  end;
end;

function TMainForm.DisplayedPositionSignature(const AStartingFEN,
  AMovesText: string; AGameState: TGameOrchestratorState): string;
begin
  Result := AStartingFEN + #10 + AMovesText + #10 +
    IntToStr(Ord(AGameState));
end;

function TMainForm.DisplayedPositionIsTerminal(ADisplayedMoveCount,
  ATotalMoveCount: Integer; AGameState: TGameOrchestratorState): Boolean;
begin
  Result := (not HasLegalDisplayedMove) or
    ((AGameState = gosGameOver) and
      ((FGameBrowsePly < 0) or (ADisplayedMoveCount >= ATotalMoveCount)));
end;

function TMainForm.HasDisplayedGameToSave: Boolean;
var
  LGameTree: TGameTree;
begin
  LGameTree := ActiveGameTree;
  Result := (LGameTree <> nil) and (LGameTree.MainlineCount > 0);
end;

procedure TMainForm.ClearStoredTreeVariations(AGameTree: TGameTree);
var
  Actor: TGameTreeActor;
begin
  SetLength(FVariationHits, 0);
  Actor := ActorForGameTree(AGameTree);
  ClearGameTreeStoredVariations(Actor);
  ClearVariationExploration;
end;

procedure TMainForm.LoadTreeVariationsFromLegacyText(AGameTree: TGameTree;
  const AVariationsText, AVariationAnnotationsText: string);
var
  I: Integer;
  AnnotationText: string;
  BasePly: Integer;
  DisplayAfterPly: Integer;
  Lines: TStringList;
  MovesText: string;
  RawAnnotationText: string;
  AnnotationLines: TStringList;
begin
  if AGameTree = nil then
    Exit;

  ClearStoredTreeVariations(AGameTree);
  Lines := TStringList.Create;
  AnnotationLines := TStringList.Create;
  try
    Lines.Text := AVariationsText;
    AnnotationLines.Text := AVariationAnnotationsText;
    for I := 0 to Lines.Count - 1 do
      if Trim(Lines[I]) <> '' then
      begin
        RawAnnotationText := '';
        if I < AnnotationLines.Count then
          RawAnnotationText := Trim(AnnotationLines[I]);
        if DecodePdnVariationLine(Lines[I], RawAnnotationText, I,
          DisplayAfterPly, BasePly, MovesText, AnnotationText) then
          StoreTreeVariation(DisplayAfterPly, BasePly, MovesText,
            AnnotationText, AGameTree);
      end;
  finally
    AnnotationLines.Free;
    Lines.Free;
  end;
end;

function TMainForm.FindTreeVariationByDisplayAfterPly(
  ADisplayAfterPly: Integer; AGameTree: TGameTree): Integer;
begin
  Result := -1;
  if AGameTree <> nil then
    Result := AGameTree.FindStoredVariationByDisplayAfterPly(
      ADisplayAfterPly);
end;

function TMainForm.StoreTreeVariation(ADisplayAfterPly, ABasePly: Integer;
  const AMovesText, AAnnotationText: string; AGameTree: TGameTree): Boolean;
var
  Actor: TGameTreeActor;
  LErrorText: string;
  LExisting: TGameTreeVariationLine;
begin
  Result := False;
  if (ADisplayAfterPly < 0) or (ABasePly < 0) or (AGameTree = nil) then
    Exit;

  LExisting := TreeVariationLineByIndex(
    AGameTree.FindStoredVariationByDisplayAfterPly(ADisplayAfterPly),
    AGameTree);
  if (LExisting <> nil) and
    (LExisting.DisplayAfterPly = ADisplayAfterPly) and
    (LExisting.BasePly = ABasePly) and
    (Trim(LExisting.MovesText) = Trim(AMovesText)) and
    (Trim(LExisting.AnnotationText) = Trim(AAnnotationText)) then
    Exit;

  Actor := ActorForGameTree(AGameTree);
  if Actor = nil then
    Exit;

  Result := StoreGameTreeVariationLine(Actor, ADisplayAfterPly, ABasePly,
    AMovesText, AAnnotationText, gmsUnknown, LErrorText);
end;

function TMainForm.EngineSupportsMcts(AEngine: TExternalEngineDefinition): Boolean;
var
  Params: TEngineParamArray;
  Value: string;
begin
  Result := False;
  SetLength(Params, 0);
  if (AEngine = nil) or (AEngine.Kind <> eekHub) then
    Exit;

  LoadEngineParamsFromJson(EngineParamsFileName(AEngine.ExePath), 'hub',
    Params);
  Value := LowerCase(Trim(EngineParamValue(Params,
    'gui-engine-supports-mcts', 'false')));
  Result := (Value = 'true') or (Value = '1') or (Value = 'yes') or
    (Value = 'on');
end;

function TMainForm.GameForTree(AGameTree: TGameTree): TRunningGame;
var
  I: Integer;
  LGame: TRunningGame;
begin
  Result := nil;
  if (AGameTree = nil) or (FGames = nil) then
    Exit;

  for I := 0 to FGames.Count - 1 do
  begin
    LGame := TRunningGame(FGames[I]);
    if (LGame <> nil) and (LGame.GameTree = AGameTree) then
      Exit(LGame);
  end;
end;

function TMainForm.ActorForGameTree(AGameTree: TGameTree): TGameTreeActor;
var
  LGame: TRunningGame;
begin
  Result := nil;
  if AGameTree = nil then
    Exit;

  if AGameTree = FGameTree then
    Exit(FGameTreeActor);

  LGame := GameForTree(AGameTree);
  if LGame <> nil then
    Result := LGame.GameTreeActor;
end;

function TMainForm.ActorForGameTreeId(AGameTreeId: Int64): TGameTreeActor;
var
  I: Integer;
  LGame: TRunningGame;
begin
  Result := nil;
  if AGameTreeId <= 0 then
    Exit;

  if (FGameTree <> nil) and (FGameTree.GameTreeId = AGameTreeId) then
    Exit(FGameTreeActor);

  if FGames = nil then
    Exit;
  for I := 0 to FGames.Count - 1 do
  begin
    LGame := TRunningGame(FGames[I]);
    if (LGame <> nil) and (LGame.GameTree <> nil) and
      (LGame.GameTree.GameTreeId = AGameTreeId) then
      Exit(LGame.GameTreeActor);
  end;
end;

function TMainForm.ActorForSearchRef(
  const ASearch: TGameTreeSearchRef): TGameTreeActor;
begin
  Result := nil;
  if not IsValidGameTreeSearchRef(ASearch) then
    Exit;
  Result := ActorForGameTreeId(ASearch.GameTreeId);
end;

function TMainForm.GameForTreeRefresh(AGameTree: TGameTree): TRunningGame;
begin
  Result := GameForTree(AGameTree);
end;

function TMainForm.StartingFenForTree(AGameTree: TGameTree): string;
begin
  Result := '';
  if AGameTree <> nil then
    Result := Trim(AGameTree.StartingFEN);
  if Result = '' then
    Result := FStartingFEN;
end;

function TMainForm.StateForTree(AGameTree: TGameTree): TGameOrchestratorState;
var
  LGame: TRunningGame;
begin
  LGame := GameForTreeRefresh(AGameTree);
  if LGame <> nil then
    Result := LGame.Snapshot.State
  else
    Result := FGameState;
end;

function TMainForm.ResultForTree(AGameTree: TGameTree): string;
begin
  Result := '';
  if AGameTree <> nil then
    Result := Trim(AGameTree.ResultText);
  if Result = '' then
    Result := PlayerNameOrFallback(FGameResult, '*');
end;

function TMainForm.RunningGameTreeExtendsSnapshot(
  AGame: TRunningGame): Boolean;
var
  LMoves: TStringList;
begin
  Result := False;
  if (AGame = nil) or (AGame.GameTree = nil) then
    Exit;
  if not (AGame.Snapshot.State in [gosStopped, gosGameOver]) then
    Exit;
  if AGame.GameTree.VariationLineCount > 0 then
    Exit(True);

  LMoves := TStringList.Create;
  try
    TextToMoveList(AGame.Snapshot.MovesPlayedText, LMoves);
    Result := AGame.GameTree.MainlineCount > LMoves.Count;
  finally
    LMoves.Free;
  end;
end;

function TMainForm.WhiteNameForTree(AGameTree: TGameTree): string;
begin
  Result := '';
  if AGameTree <> nil then
    Result := Trim(AGameTree.WhiteName);
  if Result = '' then
    Result := PlayerNameOrFallback(FStandaloneWhitePlayerName, 'White');
end;

function TMainForm.BlackNameForTree(AGameTree: TGameTree): string;
begin
  Result := '';
  if AGameTree <> nil then
    Result := Trim(AGameTree.BlackName);
  if Result = '' then
    Result := PlayerNameOrFallback(FStandaloneBlackPlayerName, 'Black');
end;

function TMainForm.EventNameForTree(AGameTree: TGameTree): string;
begin
  Result := '';
  if AGameTree <> nil then
    Result := Trim(AGameTree.EventName);
  if Result = '' then
    Result := PlayerNameOrFallback(FStandaloneEventName, '?');
end;

function TMainForm.ClockValuesForTree(AGameTree: TGameTree;
  out AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
  ABlackUsedSeconds: Double): Boolean;
begin
  Result := (AGameTree <> nil) and AGameTree.HasClockInfo;
  if Result then
  begin
    AWhiteRemainingSeconds := AGameTree.WhiteRemainingSeconds;
    ABlackRemainingSeconds := AGameTree.BlackRemainingSeconds;
    AWhiteUsedSeconds := AGameTree.WhiteUsedSeconds;
    ABlackUsedSeconds := AGameTree.BlackUsedSeconds;
  end
  else
  begin
    AWhiteRemainingSeconds := FWhiteRemainingSeconds;
    ABlackRemainingSeconds := FBlackRemainingSeconds;
    AWhiteUsedSeconds := FWhiteUsedSeconds;
    ABlackUsedSeconds := FBlackUsedSeconds;
  end;
end;

function TMainForm.VisibleMainPvForTree(AGameTree: TGameTree;
  out ABaseBoard: TDraughtsBoard; out ABasePly: Integer; out APV, AScore,
  ADepth, ATimeText: string): Boolean;
var
  LGame: TRunningGame;
begin
  LGame := GameForTreeRefresh(AGameTree);
  APV := '';
  AScore := '';
  ADepth := '';
  ATimeText := '';
  ABaseBoard := ActiveBoard;
  ABasePly := CurrentMoveCount;

  if LGame <> nil then
  begin
    APV := LGame.Snapshot.PrincipalVariation;
    AScore := LGame.Snapshot.PvScore;
    ADepth := LGame.Snapshot.PvSnapshot.Depth;
    ATimeText := LGame.Snapshot.PvSnapshot.TimeText;
    if Trim(APV) <> '' then
    begin
      ABaseBoard := LGame.Snapshot.PvBaseBoard;
      ABasePly := LGame.Snapshot.PvBasePly;
    end;
  end
  else if AGameTree = FGameTree then
  begin
    APV := FPrincipalVariation;
    AScore := FPrincipalVariationScore;
    ADepth := FPrincipalVariationDepth;
    ATimeText := FPrincipalVariationTimeText;
    if Trim(APV) <> '' then
    begin
      ABaseBoard := FPvBaseBoard;
      ABasePly := FPvBasePly;
    end;
  end;

  Result := Trim(APV) <> '';
end;

function TMainForm.PlayerNameOrFallback(const AName, AFallback: string): string;
begin
  Result := Trim(AName);
  if Result = '' then
    Result := AFallback;
end;

function TMainForm.PostGuiEvent(AEvent: TObject): Boolean;
begin
  Result := False;
  if AEvent = nil then
    Exit;
  if FGuiEventQueue = nil then
  begin
    AEvent.Free;
    Exit;
  end;
  Result := FGuiEventQueue.TryPost(AEvent);
end;

procedure TMainForm.RebuildGameMoveLabels(AGameTree: TGameTree);
var
  LGameTree: TGameTree;
  I: Integer;
  LOptions: TGameTreePdnRenderOptions;
  LRenderResult: TGameTreePdnRenderResult;
  LText: string;
begin
  if FGameMoveMemo = nil then
    Exit;

  LOptions := CurrentFilteredGameTreePdnOptions;
  LGameTree := AGameTree;
  if LGameTree = nil then
    Exit;
  RenderGameTreeMovesToPdn(LGameTree, LOptions, LRenderResult);
  LText := LRenderResult.Text;
  SetLength(FGameMoveStarts, Length(LRenderResult.MoveStarts));
  SetLength(FGameMoveLengths, Length(LRenderResult.MoveLengths));
  for I := 0 to High(LRenderResult.MoveStarts) do
  begin
    FGameMoveStarts[I] := LRenderResult.MoveStarts[I];
    FGameMoveLengths[I] := LRenderResult.MoveLengths[I];
  end;
  SetLength(FVariationHits, Length(LRenderResult.VariationStarts));
  for I := 0 to High(LRenderResult.VariationStarts) do
  begin
    FVariationHits[I].Start := LRenderResult.VariationStarts[I];
    FVariationHits[I].Length := LRenderResult.VariationLengths[I];
    FVariationHits[I].VariationIndex := LRenderResult.VariationIndexes[I];
    FVariationHits[I].VariationPly := LRenderResult.VariationPlies[I];
  end;

  if FGameMoveMemo.Text <> LText then
  begin
    FGameMoveMemo.Lines.BeginUpdate;
    try
      FGameMoveMemo.Text := LText;
      FHighlightedGameMovePly := -2;
    finally
      FGameMoveMemo.Lines.EndUpdate;
    end;
  end;
  UpdateGameMoveHighlight;
end;

function TMainForm.CurrentGameTreeHeaderInput(AGame: TRunningGame;
  AGameTree: TGameTree): TGameTreeHeaderInput;
var
  LBlackName: string;
  LMovesText: string;
  LRecordTimeControl: Boolean;
  LStartingFEN: string;
  LTimeControl: TTimeControl;
  LTreeSignature: string;
  LWhiteName: string;
begin
  if AGame <> nil then
  begin
    LWhiteName := PlayerNameOrFallback(AGame.Snapshot.WhitePlayerName,
      PlayerNameOrFallback(AGame.WhiteDisplayName, 'White'));
    LBlackName := PlayerNameOrFallback(AGame.Snapshot.BlackPlayerName,
      PlayerNameOrFallback(AGame.BlackDisplayName, 'Black'));
  end
  else
  begin
    LWhiteName := WhiteNameForTree(AGameTree);
    LBlackName := BlackNameForTree(AGameTree);
  end;

  if AGame <> nil then
    LTreeSignature := 'running:' + IntToStr(AGame.Id)
  else
  begin
    LStartingFEN := StartingFenForTree(AGameTree);
    LMovesText := GameTreeMainlineMovesText(AGameTree);
    LTreeSignature := 'standalone:' + LStartingFEN + '|' +
      EventNameForTree(AGameTree) + '|' + LWhiteName +
      '|' + LBlackName + '|moves=' + LMovesText;
  end;

  LRecordTimeControl := AGame <> nil;
  if LRecordTimeControl then
    LTimeControl := AGame.FSetup.TimeControl
  else
    FillChar(LTimeControl, SizeOf(LTimeControl), 0);

  if AGame <> nil then
    Result := GameTreeHeaderInput(LTreeSignature,
      EventNameForTree(AGameTree), LWhiteName, LBlackName,
      PlayerNameOrFallback(AGame.Snapshot.GameResult, '*'),
      PlayerNameOrFallback(AGame.Snapshot.StartingFEN, AGame.FSetup.StartingFEN),
      LRecordTimeControl, LTimeControl)
  else
  begin
    LStartingFEN := StartingFenForTree(AGameTree);
    Result := GameTreeHeaderInput(LTreeSignature,
      EventNameForTree(AGameTree), LWhiteName, LBlackName,
      ResultForTree(AGameTree), LStartingFEN,
      LRecordTimeControl, LTimeControl);
  end;
end;

function TMainForm.RunningGameTreeHeaderInput(AGame: TRunningGame;
  const AEventName: string): TGameTreeHeaderInput;
var
  LBlackName: string;
  LEventName: string;
  LResultText: string;
  LStartingFEN: string;
  LTimeControl: TTimeControl;
  LWhiteName: string;
begin
  LTimeControl := DefaultTimeControl;
  if AGame = nil then
  begin
    Result := GameTreeHeaderInput('', '?', 'White', 'Black', '*', '',
      False, LTimeControl);
    Exit;
  end;

  LEventName := PlayerNameOrFallback(AEventName,
    EventNameForTree(AGame.GameTree));
  LWhiteName := PlayerNameOrFallback(AGame.Snapshot.WhitePlayerName,
    PlayerNameOrFallback(AGame.WhiteDisplayName, 'White'));
  LBlackName := PlayerNameOrFallback(AGame.Snapshot.BlackPlayerName,
    PlayerNameOrFallback(AGame.BlackDisplayName, 'Black'));
  LResultText := PlayerNameOrFallback(AGame.Snapshot.GameResult, '*');
  LStartingFEN := PlayerNameOrFallback(AGame.Snapshot.StartingFEN,
    AGame.FSetup.StartingFEN);

  Result := GameTreeHeaderInput('running:' + IntToStr(AGame.Id),
    LEventName, LWhiteName, LBlackName, LResultText, LStartingFEN, True,
    AGame.FSetup.TimeControl);
end;

procedure TMainForm.UpdateRunningGameTreeFromSnapshot(AGame: TRunningGame;
  const AEventName: string);
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  LErrorText: string;
  LAnnotations: TStringList;
  LExistingAnnotations: TStringList;
  LGameTree: TGameTree;
  LMoves: TStringList;
  LSyncSignature: string;

  function LineOrEmpty(AStrings: TStrings; AIndex: Integer): string;
  begin
    Result := '';
    if (AStrings <> nil) and (AIndex >= 0) and (AIndex < AStrings.Count) then
      Result := AStrings[AIndex];
  end;

  function SnapshotExtendsCurrentTree: Boolean;
  var
    I: Integer;
  begin
    Result := False;
    if LGameTree.MainlineCount >= LMoves.Count then
      Exit;
    for I := 1 to LGameTree.MainlineCount do
      if not SameText(NormalizeMoveNotation(LGameTree.MainlineNode[I].MoveText),
        NormalizeMoveNotation(LMoves[I - 1])) then
        Exit;

    LExistingAnnotations := TStringList.Create;
    try
      LExistingAnnotations.Text := GameTreeScoreAnnotationsText(LGameTree);
      for I := 0 to LGameTree.MainlineCount - 1 do
        if Trim(LineOrEmpty(LExistingAnnotations, I)) <>
          Trim(LineOrEmpty(LAnnotations, I)) then
          Exit;
    finally
      LExistingAnnotations.Free;
    end;
    Result := True;
  end;

  function SnapshotMovesMatchCurrentTree: Boolean;
  var
    I: Integer;
  begin
    Result := False;
    if LGameTree.MainlineCount <> LMoves.Count then
      Exit;
    for I := 1 to LGameTree.MainlineCount do
      if not SameText(NormalizeMoveNotation(LGameTree.MainlineNode[I].MoveText),
        NormalizeMoveNotation(LMoves[I - 1])) then
        Exit;
    Result := True;
  end;

  procedure PreserveExistingSnapshotAnnotations;
  var
    I: Integer;
    LLimit: Integer;
  begin
    LExistingAnnotations := TStringList.Create;
    try
      LExistingAnnotations.Text := GameTreeScoreAnnotationsText(LGameTree);
      LLimit := LGameTree.MainlineCount;
      if LMoves.Count < LLimit then
        LLimit := LMoves.Count;
      for I := 0 to LLimit - 1 do
        if (Trim(LineOrEmpty(LAnnotations, I)) = '') and
          (Trim(LineOrEmpty(LExistingAnnotations, I)) <> '') and
          SameText(NormalizeMoveNotation(LGameTree.MainlineNode[I + 1].MoveText),
            NormalizeMoveNotation(LMoves[I])) then
        begin
          while LAnnotations.Count <= I do
            LAnnotations.Add('');
          LAnnotations[I] := LExistingAnnotations[I];
        end;
    finally
      LExistingAnnotations.Free;
    end;
  end;

  function TryAppendSnapshotMoves: Boolean;
  var
    I: Integer;
    IsLastMove: Boolean;
  begin
    Result := False;
    if not SnapshotExtendsCurrentTree then
      Exit;
    Actor := ActorForGameTree(LGameTree);
    if Actor = nil then
      Exit;

    for I := LGameTree.MainlineCount to LMoves.Count - 1 do
    begin
      IsLastMove := I = LMoves.Count - 1;
      Command := Actor.CreateAppendMainlineSnapshotMoveCommand(
        RunningGameTreeHeaderInput(AGame, AEventName),
        LMoves[I], LineOrEmpty(LAnnotations, I),
        GameTreeMainlineInput(nil, nil, IsLastMove,
          AGame.Snapshot.WhiteRemainingSeconds,
          AGame.Snapshot.BlackRemainingSeconds,
          AGame.Snapshot.WhiteUsedSeconds,
          AGame.Snapshot.BlackUsedSeconds),
        GameTreePvInput(IsLastMove and
          (Trim(AGame.Snapshot.PrincipalVariation) <> ''),
          AGame.Snapshot.PvBasePly, '',
          AGame.Snapshot.PrincipalVariation),
        gmsEngineMatch);
      try
        if not ExecuteGameTreeCommand(Actor, Command, LErrorText) then
          Exit;
      finally
        Command.Free;
      end;
    end;
    Result := True;
  end;

  procedure TryRecordSnapshotPV;
  var
    LNode: TGameTreePlyNode;
    LPvSignature: string;
  begin
    if Trim(AGame.Snapshot.PrincipalVariation) = '' then
      Exit;
    if AGame.Snapshot.PvBasePly <= 0 then
      LNode := LGameTree.Root
    else
      LNode := LGameTree.MainlineNode[AGame.Snapshot.PvBasePly];
    if LNode = nil then
      Exit;
    Actor := ActorForGameTree(LGameTree);
    if Actor = nil then
      Exit;
    LPvSignature := IntToStr(LGameTree.GameTreeId) + #10 +
      IntToStr(LNode.NodeId) + #10 + AGame.Snapshot.PrincipalVariation;
    if AGame.FLastSnapshotTreePvSignature = LPvSignature then
      Exit;
    if RecordEnginePvInGameTree(Actor, LGameTree, LNode.NodeId, '',
      AGame.Snapshot.PrincipalVariation, LErrorText) then
      AGame.FLastSnapshotTreePvSignature := LPvSignature;
  end;
begin
  if (AGame = nil) or (AGame.GameTree = nil) then
    Exit;
  if RunningGameTreeExtendsSnapshot(AGame) then
    Exit;

  LGameTree := AGame.GameTree;
  TryRecordSnapshotPV;
  LSyncSignature :=
    AEventName + #10 +
    AGame.Snapshot.WhitePlayerName + #10 +
    AGame.Snapshot.BlackPlayerName + #10 +
    AGame.Snapshot.GameResult + #10 +
    AGame.Snapshot.StartingFEN + #10 +
    IntToStr(Ord(AGame.Snapshot.State)) + #10 +
    AGame.Snapshot.MovesPlayedText + #10 +
    AGame.Snapshot.MoveAnnotationsText;
  if AGame.FLastSnapshotTreeSyncSignature = LSyncSignature then
    Exit;

  LMoves := TStringList.Create;
  LAnnotations := TStringList.Create;
  try
    TextToMoveList(AGame.Snapshot.MovesPlayedText, LMoves);
    LAnnotations.Text := AGame.Snapshot.MoveAnnotationsText;
    PreserveExistingSnapshotAnnotations;

    if TryAppendSnapshotMoves then
    begin
      AGame.FLastSnapshotTreeSyncSignature := LSyncSignature;
      Exit;
    end;

    if SnapshotMovesMatchCurrentTree and
      (Trim(GameTreeScoreAnnotationsText(LGameTree)) =
        Trim(LAnnotations.Text)) then
    begin
      Actor := ActorForGameTree(LGameTree);
      if Actor <> nil then
        SetGameTreeHeader(Actor, RunningGameTreeHeaderInput(AGame,
          AEventName), LErrorText);
      AGame.FLastSnapshotTreeSyncSignature := LSyncSignature;
      Exit;
    end;

    Actor := ActorForGameTree(LGameTree);
    if Actor = nil then
      Exit;
    if RebuildGameTreeFromInputs(Actor,
      RunningGameTreeHeaderInput(AGame, AEventName),
      GameTreeMainlineInput(LMoves, LAnnotations, True,
        AGame.Snapshot.WhiteRemainingSeconds,
        AGame.Snapshot.BlackRemainingSeconds,
        AGame.Snapshot.WhiteUsedSeconds,
        AGame.Snapshot.BlackUsedSeconds),
      GameTreePvInput(Trim(AGame.Snapshot.PrincipalVariation) <> '',
        AGame.Snapshot.PvBasePly, '',
        AGame.Snapshot.PrincipalVariation),
      GameTreePvInput(False, 0, '', ''), -1, 0, '', '', LErrorText) then
      AGame.FLastSnapshotTreeSyncSignature := LSyncSignature;
  finally
    LAnnotations.Free;
    LMoves.Free;
  end;
end;

function TMainForm.RunningGameTreePdnText(AGame: TRunningGame;
  const AEventName: string): string;
var
  LOptions: TGameTreePdnRenderOptions;
begin
  Result := '';
  if (AGame = nil) or (AGame.GameTree = nil) then
    Exit;

  UpdateRunningGameTreeFromSnapshot(AGame, AEventName);
  LOptions := DefaultGameTreePdnRenderOptions;
  Result := GameTreeToPdnTextEx(AGame.GameTree, LOptions);
end;

function TMainForm.CanRecordCurrentAnnotatorPV: Boolean;
var
  LDisplayedPly: Integer;
begin
  Result := False;
  if FAnalyzerPvBrowser = nil then
    Exit;
  if Trim(FAnalyzerPvBrowser.PrincipalVariation) = '' then
    Exit;
  if (FVariationIndex >= 0) and (FVariationBrowsePly > 0) then
    Exit;

  if FGameBrowsePly >= 0 then
    LDisplayedPly := FGameBrowsePly
  else
    LDisplayedPly := CurrentMoveCount;
  if FAnalyzerPvBasePly <> LDisplayedPly then
    Exit;
  if FAnalyzerPvBaseBoard.PositionKey <> ActiveBoard.PositionKey then
    Exit;

  Result := True;
end;

function TMainForm.CanRecordCurrentVariationAnnotatorPV(AVariationIndex,
  AVariationPly: Integer): Boolean;
begin
  Result := False;
  if FAnalyzerPvBrowser = nil then
    Exit;
  if Trim(FAnalyzerPvBrowser.PrincipalVariation) = '' then
    Exit;
  if (FVariationIndex <> AVariationIndex) or
    (FVariationBrowsePly <> AVariationPly) then
    Exit;

  Result := True;
end;

function TMainForm.CurrentGameTreeEnginePvInput(
  AGameTree: TGameTree): TGameTreePvInput;
var
  LGame: TRunningGame;
begin
  LGame := GameForTreeRefresh(AGameTree);
  if LGame <> nil then
  begin
    Result := GameTreePvInput(Trim(LGame.Snapshot.PrincipalVariation) <> '',
      LGame.Snapshot.PvBasePly, LGame.Snapshot.PvScore,
      LGame.Snapshot.PrincipalVariation);
    Exit;
  end;

  Result := GameTreePvInput((AGameTree = FGameTree) and
    (Trim(FPrincipalVariation) <> ''), FPvBasePly,
    FPrincipalVariationScore, FPrincipalVariation);
end;

function TMainForm.CurrentGameTreeAnnotatorPvInput(
  AGameTree: TGameTree): TGameTreePvInput;
var
  LRecordAnnotatorPV: Boolean;
  LAnnotatorPV: string;
  LAnnotatorScore: string;
begin
  LRecordAnnotatorPV := (AGameTree = ActiveGameTree) and
    CanRecordCurrentAnnotatorPV;
  LAnnotatorPV := '';
  LAnnotatorScore := '';
  if LRecordAnnotatorPV then
  begin
    LAnnotatorPV := FAnalyzerPvBrowser.PrincipalVariation;
    LAnnotatorScore := FAnalyzerPvBrowser.Score;
  end;

  Result := GameTreePvInput(LRecordAnnotatorPV, FAnalyzerPvBasePly,
    LAnnotatorScore, LAnnotatorPV);
end;

procedure TMainForm.UpdateGameMoveHighlight;
var
  I: Integer;
  LHighlightPly: Integer;
begin
  if FGameMoveMemo = nil then
    Exit;
  if Length(FGameMoveStarts) <> Length(FGameMoveLengths) then
  begin
    RebuildGameMoveLabels(ActiveGameTree);
    Exit;
  end;

  LHighlightPly := FGameBrowsePly;
  if (LHighlightPly < 0) and (SelectedDisplayedGame <> nil) then
    LHighlightPly := CurrentMoveCount;

  if (FHighlightedGameMovePly = LHighlightPly) and
    (not ((FVariationIndex >= 0) and (FVariationBrowsePly > 0))) then
    Exit;
  if (FVariationIndex >= 0) and (FVariationBrowsePly > 0) then
  begin
    for I := 0 to High(FVariationHits) do
      if (FVariationHits[I].VariationIndex = FVariationIndex) and
        (FVariationHits[I].VariationPly = FVariationBrowsePly) then
      begin
        FGameMoveMemo.SelStart := FVariationHits[I].Start;
        FGameMoveMemo.SelLength := FVariationHits[I].Length;
        FHighlightedGameMovePly := -2;
        Exit;
      end;
  end;
  if (LHighlightPly > 0) and (LHighlightPly <= Length(FGameMoveStarts)) then
  begin
    FGameMoveMemo.SelStart := FGameMoveStarts[LHighlightPly - 1];
    FGameMoveMemo.SelLength := FGameMoveLengths[LHighlightPly - 1];
  end
  else
  begin
    FGameMoveMemo.SelStart := 0;
    FGameMoveMemo.SelLength := 0;
  end;
  FHighlightedGameMovePly := LHighlightPly;
end;

function TMainForm.MoveSquareAt(const AMove: string; ASquareIndex: Integer): Integer;
var
  I: Integer;
  LCount: Integer;
  LNumberText: string;
begin
  Result := 0;
  LCount := 0;
  LNumberText := '';
  for I := 1 to Length(AMove) do
  begin
    if AMove[I] in ['0'..'9'] then
      LNumberText += AMove[I]
    else if LNumberText <> '' then
    begin
      Inc(LCount);
      if LCount = ASquareIndex then
        Exit(StrToIntDef(LNumberText, 0));
      LNumberText := '';
    end;
  end;
  if LNumberText <> '' then
  begin
    Inc(LCount);
    if LCount = ASquareIndex then
      Result := StrToIntDef(LNumberText, 0);
  end;
end;

procedure TMainForm.UpdateBoardHighlights(AGameTree: TGameTree);
var
  LDisplayedGamePly: Integer;
  LGameMoves: TStringList;
  LPvBaseBoard: TDraughtsBoard;
  LPvBasePly: Integer;
  LPvDepth: string;
  LPvHighlightsActive: Boolean;
  LPvMoves: TStringList;
  LPvScore: string;
  LPvTimeText: string;
  LPvText: string;
begin
  if FBoardControl = nil then
    Exit;
  if AGameTree = nil then
    Exit;

  LGameMoves := TStringList.Create;
  LPvMoves := TStringList.Create;
  try
    AGameTree.CopyMainlineMovesTo(LGameMoves);
    if FPvHintSource = phsAnalyzer then
    begin
      LPvBaseBoard := FAnalyzerPvBaseBoard;
      if FAnalyzerPvBrowser <> nil then
        LPvText := FAnalyzerPvBrowser.PrincipalVariation
      else
        LPvText := '';
    end
    else
      VisibleMainPvForTree(AGameTree, LPvBaseBoard, LPvBasePly, LPvText,
        LPvScore, LPvDepth, LPvTimeText);
    TextToMoveList(LPvText, LPvMoves);
    if FGameBrowsePly < 0 then
      LDisplayedGamePly := LGameMoves.Count
    else
      LDisplayedGamePly := FGameBrowsePly;
    if (LDisplayedGamePly > 0) and
      (LDisplayedGamePly <= LGameMoves.Count) then
      FBoardControl.LastMoveTargetSquare := MoveSquareAt(
        LGameMoves[LDisplayedGamePly - 1], 2)
    else
      FBoardControl.LastMoveTargetSquare := 0;

    LPvHighlightsActive := (LPvBaseBoard <> nil) and
      (FBoard.PositionKey = LPvBaseBoard.PositionKey);

    if LPvHighlightsActive and (LPvMoves.Count > 0) then
      FBoardControl.PvSourceSquare := MoveSquareAt(LPvMoves[0], 1)
    else
      FBoardControl.PvSourceSquare := 0;

    if LPvHighlightsActive and (LPvMoves.Count > 1) then
      FBoardControl.HintSourceSquare := MoveSquareAt(LPvMoves[1], 1)
    else
      FBoardControl.HintSourceSquare := 0;
  finally
    LPvMoves.Free;
    LGameMoves.Free;
  end;
end;

procedure TMainForm.UpdateBoardFromBrowseState(AGameTree: TGameTree);
var
  I: Integer;
  LGameMoves: TStringList;
  LLimit: Integer;
  LPly: Integer;
  VariationLine: TGameTreeVariationLine;
  LVariationMoves: TStringList;
begin
  if AGameTree = nil then
    Exit;

  LGameMoves := TStringList.Create;
  LVariationMoves := TStringList.Create;
  try
    AGameTree.CopyMainlineMovesTo(LGameMoves);
    FBoard.LoadFromFEN(StartingFenForTree(AGameTree));

    LPly := FGameBrowsePly;
    if (LPly < 0) or (LPly > LGameMoves.Count) then
      LPly := LGameMoves.Count;
    for I := 0 to LPly - 1 do
      FBoard.PlayMove(LGameMoves[I], True, False);
    VariationLine := TreeVariationLineByIndex(FVariationIndex, AGameTree);
    if (VariationLine <> nil) and (VariationLine.BasePly = LPly) and
      (FVariationBrowsePly > 0) then
    begin
      TextToMoveList(VariationLine.MovesText, LVariationMoves);
      LLimit := FVariationBrowsePly;
      if LLimit > LVariationMoves.Count then
        LLimit := LVariationMoves.Count;
      for I := 0 to LLimit - 1 do
        FBoard.PlayMove(LVariationMoves[I], True, False);
    end;
  finally
    LVariationMoves.Free;
    LGameMoves.Free;
  end;

  if FBoardControl <> nil then
    FBoardControl.Invalidate;
  UpdateDatabaseSearchPosition;
end;

procedure TMainForm.ApplyGameBrowsePly(APly: Integer);
var
  LMoveCount: Integer;
begin
  ClearHumanMoveSelection;
  ClearVariationExploration;
  LMoveCount := CurrentMoveCount;
  if APly < 0 then
    FGameBrowsePly := LMoveCount
  else if APly > LMoveCount then
    FGameBrowsePly := 0
  else
    FGameBrowsePly := APly;
  UpdateBoardFromBrowseState(ActiveGameTree);
  UpdateBrowseInfo;
end;

procedure TMainForm.ExitGameBrowseMode;
begin
  if FGameBrowsePly < 0 then
  begin
    if FGameMoveMemo <> nil then
      FGameMoveMemo.SelLength := 0;
    Exit;
  end;
  ClearVariationExploration;
  FGameBrowsePly := -1;
  UpdateBoardFromBrowseState(ActiveGameTree);
  UpdateBrowseInfo;
end;

procedure TMainForm.ApplyGameToDisplay(AGame: TRunningGame);
var
  LLogSourceChanged: Boolean;
  LEffectiveAnnotationsText: string;
  LMoveCount: Integer;
  LPositionChanged: Boolean;
  LPvChanged: Boolean;
  LSnapshotSignature: string;
  LSnapshotAnnotationsEmpty: Boolean;
  LSnapshotAnnotationsText: string;
  LTreeAnnotationsMatchSnapshot: Boolean;
  LTreeAnnotationsText: string;
  LTreeExtendsSnapshot: Boolean;
  LTreeMatchesSnapshot: Boolean;
  LTreeMovesMatchSnapshot: Boolean;
  LTreeMovesText: string;

  function SecondsSignature(AValue: Double): string;
  begin
    Result := FormatFloat('0.000', AValue);
  end;

  procedure UpdateDisplayedGameLog;
  var
    J: Integer;
  begin
    LLogSourceChanged := (FGameLogSourceGameId <> AGame.Id) or
      (FGameLogSourceLineCount <> AGame.Snapshot.LogLines.Count) or
      (FGameLogSourceShowStdout <> AGame.ShowStdout);
    if LLogSourceChanged then
    begin
      FGameLog.Clear;
      for J := 0 to AGame.Snapshot.LogLines.Count - 1 do
        if GameLogLineVisible(AGame.Snapshot.LogLines[J], AGame) then
          FGameLog.Add(AGame.Snapshot.LogLines[J]);
      FGameLogSourceGameId := AGame.Id;
      FGameLogSourceLineCount := AGame.Snapshot.LogLines.Count;
      FGameLogSourceShowStdout := AGame.ShowStdout;
    end;
  end;
begin
  if AGame = nil then
  begin
    ClearHumanMoveSelection;
    FGameActive := False;
    FGameResult := '*';
    FPrincipalVariation := '';
    FPrincipalVariationScore := '';
    FPrincipalVariationDepth := '';
    FPrincipalVariationTimeText := '';
    FDisplayedAnnotationsSignature := '';
    FDisplayedMovesSignature := '';
    FDisplayedSnapshotSignature := '';
    FDisplayedGameTreeId := 0;
    FDisplayedGameTreeRevision := -1;
    FScoreHistoryCachedAnnotationsText := '';
    FScoreHistoryCachedGameTreeId := 0;
    FScoreHistoryCachedPlyCount := 0;
    ClearStoredTreeVariations(FGameTree);
    FStandaloneWhitePlayerName := 'White';
    FStandaloneBlackPlayerName := 'Black';
    FStandaloneEventName := '?';
    FGameBrowsePly := -1;
    FViewedGameId := -1;
    FGameLog.Clear;
    FGameLogSourceGameId := -1;
    FGameLogSourceLineCount := -1;
    FGameLogSourceShowStdout := False;
    FBoard.SetBeginPosition;
    FStartingFEN := FBoard.StartingFEN;
    FPvBaseBoard.AssignFrom(FBoard);
    FPvBasePly := 0;
    UpdateMiniBoardFromBoard(FBoard);
    UpdateBoardInfo;
    Exit;
  end;

  if FViewedGameId <> AGame.Id then
  begin
    ClearHumanMoveSelection;
    FViewedGameId := AGame.Id;
    FGameBrowsePly := -1;
    FDisplayedAnnotationsSignature := '';
    FDisplayedSnapshotSignature := '';
    FDisplayedGameTreeId := 0;
    FDisplayedGameTreeRevision := -1;
    ClearStoredTreeVariations(AGame.GameTree);
  end;

  LSnapshotSignature :=
    IntToStr(AGame.Id) + #10 +
    AGame.Snapshot.WhitePlayerName + #10 +
    AGame.Snapshot.BlackPlayerName + #10 +
    AGame.Snapshot.StartingFEN + #10 +
    AGame.Snapshot.MovesPlayedText + #10 +
    AGame.Snapshot.MoveAnnotationsText + #10 +
    IntToStr(Ord(AGame.Snapshot.State)) + #10 +
    AGame.Snapshot.GameResult + #10 +
    IntToStr(Ord(AGame.Snapshot.CurrentSide)) + #10 +
    AGame.Snapshot.PrincipalVariation + #10 +
    AGame.Snapshot.PvScore + #10 +
    AGame.Snapshot.PvSnapshot.Depth + #10 +
    AGame.Snapshot.PvSnapshot.TimeText + #10 +
    IntToStr(AGame.Snapshot.PvBasePly) + #10 +
    SecondsSignature(AGame.Snapshot.WhiteRemainingSeconds) + #10 +
    SecondsSignature(AGame.Snapshot.BlackRemainingSeconds) + #10 +
    SecondsSignature(AGame.Snapshot.WhiteUsedSeconds) + #10 +
    SecondsSignature(AGame.Snapshot.BlackUsedSeconds);
  UpdateDisplayedGameLog;
  if FDisplayedSnapshotSignature = LSnapshotSignature then
  begin
    UpdateGameLogMemo;
    UpdateAutoplayControls;
    Exit;
  end;
  FDisplayedSnapshotSignature := LSnapshotSignature;

  LTreeMovesText := GameTreeMainlineMovesText(AGame.GameTree);
  LTreeAnnotationsText := GameTreeScoreAnnotationsText(AGame.GameTree);
  LSnapshotAnnotationsText := AGame.Snapshot.MoveAnnotationsText;
  LSnapshotAnnotationsEmpty := Trim(LSnapshotAnnotationsText) = '';
  LTreeMovesMatchSnapshot :=
    Trim(LTreeMovesText) = Trim(AGame.Snapshot.MovesPlayedText);
  if LSnapshotAnnotationsEmpty and LTreeMovesMatchSnapshot and
    (Trim(LTreeAnnotationsText) <> '') then
    LEffectiveAnnotationsText := LTreeAnnotationsText
  else
    LEffectiveAnnotationsText := LSnapshotAnnotationsText;

  LPositionChanged := (FStartingFEN <> AGame.Snapshot.StartingFEN) or
    (FDisplayedAnnotationsSignature <> LEffectiveAnnotationsText) or
    (FDisplayedMovesSignature <> AGame.Snapshot.MovesPlayedText) or
    (FGameState <> AGame.Snapshot.State) or
    (FGameResult <> AGame.Snapshot.GameResult);
  LPvChanged := (FPrincipalVariation <> AGame.Snapshot.PrincipalVariation) or
    (FPrincipalVariationScore <> AGame.Snapshot.PvScore) or
    (FPrincipalVariationDepth <> AGame.Snapshot.PvSnapshot.Depth) or
    (FPrincipalVariationTimeText <> AGame.Snapshot.PvSnapshot.TimeText) or
    (FPvBasePly <> AGame.Snapshot.PvBasePly) or
    (FPvBaseBoard.PositionKey <> AGame.Snapshot.PvBaseBoard.PositionKey);
  if FDisplayedMovesSignature <> AGame.Snapshot.MovesPlayedText then
  begin
    ClearHumanMoveSelection;
    ClearVariationExploration;
  end;
  FStartingFEN := AGame.Snapshot.StartingFEN;
  FGameState := AGame.Snapshot.State;
  FGameResult := AGame.Snapshot.GameResult;
  FPrincipalVariation := AGame.Snapshot.PrincipalVariation;
  FPrincipalVariationScore := AGame.Snapshot.PvScore;
  FPrincipalVariationDepth := AGame.Snapshot.PvSnapshot.Depth;
  FPrincipalVariationTimeText := AGame.Snapshot.PvSnapshot.TimeText;
  FPvBaseBoard.AssignFrom(AGame.Snapshot.PvBaseBoard);
  FPvBasePly := AGame.Snapshot.PvBasePly;
  FWhiteRemainingSeconds := AGame.Snapshot.WhiteRemainingSeconds;
  FBlackRemainingSeconds := AGame.Snapshot.BlackRemainingSeconds;
  FWhiteUsedSeconds := AGame.Snapshot.WhiteUsedSeconds;
  FBlackUsedSeconds := AGame.Snapshot.BlackUsedSeconds;
  FGameActive := True;
  if not LPositionChanged then
  begin
    UpdateClockLabels(WhiteNameForTree(AGame.GameTree),
      BlackNameForTree(AGame.GameTree));
    UpdateGameLogMemo;
    if LPvChanged then
    begin
      UpdateBoardHighlights(AGame.GameTree);
      if FPvBrowser <> nil then
        FPvBrowser.SetData(FPvBaseBoard, FPvBasePly,
          StartingFenForTree(AGame.GameTree), FPrincipalVariation,
          FPrincipalVariationScore, FPrincipalVariationDepth,
          FPrincipalVariationTimeText);
      if FBoardControl <> nil then
        FBoardControl.Invalidate;
    end;
    UpdateAutoplayControls;
    Exit;
  end;

  UpdateMiniBoardFromBoard(AGame.Snapshot.Board);
  LTreeExtendsSnapshot := RunningGameTreeExtendsSnapshot(AGame);
  LTreeAnnotationsMatchSnapshot := LSnapshotAnnotationsEmpty or
    (Trim(LTreeAnnotationsText) = Trim(LSnapshotAnnotationsText));
  LTreeMatchesSnapshot := LTreeMovesMatchSnapshot and
    LTreeAnnotationsMatchSnapshot;
  if LTreeExtendsSnapshot then
  begin
    FDisplayedAnnotationsSignature := LTreeAnnotationsText;
    FDisplayedMovesSignature := LTreeMovesText
  end
  else
  begin
    FDisplayedAnnotationsSignature := LEffectiveAnnotationsText;
    FDisplayedMovesSignature := AGame.Snapshot.MovesPlayedText;
    if not LTreeMatchesSnapshot then
      ClearStoredTreeVariations(AGame.GameTree);
  end;
  if (not LTreeExtendsSnapshot) and (not LTreeMatchesSnapshot) then
    UpdateGameTreeFromMoveText(AGame, AGame.GameTree,
      AGame.Snapshot.MovesPlayedText, AGame.Snapshot.MoveAnnotationsText);
  LMoveCount := CurrentMoveCount;
  if FGameBrowsePly > LMoveCount then
    FGameBrowsePly := -1;
  UpdateBoardFromBrowseState(AGame.GameTree);
  RefreshDisplayedGameTreeViews(AGame.GameTree, False);
  if LSnapshotAnnotationsEmpty and LTreeMovesMatchSnapshot and
    (Trim(LTreeAnnotationsText) <> '') then
    UpdateScoreHistory(AGame.GameTree);
  UpdateBoardInfo;
end;

procedure TMainForm.MiniBoardDblClick(Sender: TObject);
begin
  MiniBoardPopoutClick(Sender);
end;

procedure TMainForm.MiniBoardFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

procedure TMainForm.MiniBoardPopoutClick(Sender: TObject);
var
  LMenuItem: TMenuItem;
  LPopup: TPopupMenu;
begin
  if FMiniBoardForm = nil then
  begin
    FMiniBoardForm := TForm.Create(Self);
    FMiniBoardForm.Caption := 'Mini-board';
    FMiniBoardForm.Position := poDesigned;
    FMiniBoardForm.Width := 520;
    FMiniBoardForm.Height := 540;
    FMiniBoardForm.Constraints.MinWidth := 300;
    FMiniBoardForm.Constraints.MinHeight := 320;
    FMiniBoardForm.OnClose := @MiniBoardFormClose;

    FPopoutBoardControl := TDraughtsBoardControl.Create(FMiniBoardForm);
    FPopoutBoardControl.Parent := FMiniBoardForm;
    FPopoutBoardControl.Align := alClient;
    FPopoutBoardControl.Board := FPopoutBoard;
    FPopoutBoardControl.BoardFlipped := FBoardFlipped;
    ApplyBoardTheme(FPopoutBoardControl, False);

    LPopup := TPopupMenu.Create(FMiniBoardForm);
    LMenuItem := TMenuItem.Create(FMiniBoardForm);
    LMenuItem.Caption := 'Copy FEN to clipboard';
    LMenuItem.OnClick := @PopoutBoardCopyFenClick;
    LPopup.Items.Add(LMenuItem);
    FPopoutBoardControl.PopupMenu := LPopup;
  end;

  FPopoutBoard.AssignFrom(FMiniBoard);
  if FPopoutBoardControl <> nil then
    FPopoutBoardControl.Invalidate;
  ShowFormCenteredOnOwner(FMiniBoardForm, Self);
end;

procedure TMainForm.PopoutBoardCopyFenClick(Sender: TObject);
begin
  if FPopoutBoard <> nil then
    Clipboard.AsText := FPopoutBoard.CurrentFEN;
end;

procedure TMainForm.PvBoardChanged(Sender: TObject);
begin
  if (FMiniBoardForm <> nil) and FMiniBoardForm.Visible and
    (FPopoutBoard <> nil) then
  begin
    FPopoutBoard.AssignFrom(FMiniBoard);
    if FPopoutBoardControl <> nil then
      FPopoutBoardControl.Invalidate;
  end;
  if FPvHintSource = phsMain then
  begin
    UpdateBoardHighlights(ActiveGameTree);
    if FBoardControl <> nil then
      FBoardControl.Invalidate;
  end;
end;

procedure TMainForm.AnalyzerMiniBoardDblClick(Sender: TObject);
begin
  AnalyzerMiniBoardPopoutClick(Sender);
end;

procedure TMainForm.AnalyzerMiniBoardFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

procedure TMainForm.AnalyzerMiniBoardPopoutClick(Sender: TObject);
var
  LMenuItem: TMenuItem;
  LPopup: TPopupMenu;
begin
  if FAnalyzerMiniBoardForm = nil then
  begin
    FAnalyzerMiniBoardForm := TForm.Create(Self);
    FAnalyzerMiniBoardForm.Caption := 'Annotator mini-board';
    FAnalyzerMiniBoardForm.Position := poDesigned;
    FAnalyzerMiniBoardForm.Width := 520;
    FAnalyzerMiniBoardForm.Height := 540;
    FAnalyzerMiniBoardForm.Constraints.MinWidth := 300;
    FAnalyzerMiniBoardForm.Constraints.MinHeight := 320;
    FAnalyzerMiniBoardForm.OnClose := @AnalyzerMiniBoardFormClose;

    FAnalyzerPopoutBoardControl := TDraughtsBoardControl.Create(
      FAnalyzerMiniBoardForm);
    FAnalyzerPopoutBoardControl.Parent := FAnalyzerMiniBoardForm;
    FAnalyzerPopoutBoardControl.Align := alClient;
    FAnalyzerPopoutBoardControl.Board := FAnalyzerPopoutBoard;
    FAnalyzerPopoutBoardControl.BoardFlipped := FBoardFlipped;
    ApplyBoardTheme(FAnalyzerPopoutBoardControl, True);

    LPopup := TPopupMenu.Create(FAnalyzerMiniBoardForm);
    LMenuItem := TMenuItem.Create(FAnalyzerMiniBoardForm);
    LMenuItem.Caption := 'Copy FEN to clipboard';
    LMenuItem.OnClick := @AnalyzerPopoutBoardCopyFenClick;
    LPopup.Items.Add(LMenuItem);
    FAnalyzerPopoutBoardControl.PopupMenu := LPopup;
  end;

  FAnalyzerPopoutBoard.AssignFrom(FAnalyzerMiniBoard);
  if FAnalyzerPopoutBoardControl <> nil then
    FAnalyzerPopoutBoardControl.Invalidate;
  ShowFormCenteredOnOwner(FAnalyzerMiniBoardForm, Self);
end;

procedure TMainForm.AnalyzerPopoutBoardCopyFenClick(Sender: TObject);
begin
  if FAnalyzerPopoutBoard <> nil then
    Clipboard.AsText := FAnalyzerPopoutBoard.CurrentFEN;
end;

procedure TMainForm.AnalyzerPvBoardChanged(Sender: TObject);
begin
  if (FAnalyzerMiniBoardForm <> nil) and FAnalyzerMiniBoardForm.Visible and
    (FAnalyzerPopoutBoard <> nil) then
  begin
    FAnalyzerPopoutBoard.AssignFrom(FAnalyzerMiniBoard);
    if FAnalyzerPopoutBoardControl <> nil then
      FAnalyzerPopoutBoardControl.Invalidate;
  end;
  if FPvHintSource = phsAnalyzer then
  begin
    UpdateBoardHighlights(ActiveGameTree);
    if FBoardControl <> nil then
      FBoardControl.Invalidate;
  end;
end;

function TMainForm.FindGameById(AGameId: Integer): TRunningGame;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to FGames.Count - 1 do
    if TRunningGame(FGames[I]).Id = AGameId then
      Exit(TRunningGame(FGames[I]));
end;

function TMainForm.FormatClock(ASeconds: Double): string;
var
  LMinutes, LSeconds: Integer;
begin
  if ASeconds < 0 then
    ASeconds := 0;
  LMinutes := Trunc(ASeconds) div 60;
  LSeconds := Trunc(ASeconds) mod 60;
  Result := Format('%d:%.2d', [LMinutes, LSeconds]);
end;

function TMainForm.CurrentFilteredGameTreePdnOptions: TGameTreePdnRenderOptions;
begin
  Result := DefaultGameTreePdnRenderOptions;
  Result.HideAnnotations := FHideMoveAnnotations;
  Result.ShowEngineScore := FMoveShowEngineScore;
  Result.ShowEnginePVMove := FMoveShowEnginePVMove;
  Result.ShowEngineFullPV := FMoveShowEngineFullPV;
  Result.ShowAnnotatorPVMove := FMoveShowAnnotatorPVMove;
  Result.ShowAnnotatorFullPV := FMoveShowAnnotatorFullPV;
  Result.ShowClocks := FMoveShowClocks;
  Result.ShowAnnotatorScore := FMoveShowAnnotatorScore;
end;

function TMainForm.GameLogLineVisible(const ALine: string;
  AGame: TRunningGame): Boolean;
begin
  Result := True;
  if AGame = nil then
    Exit;
  if AGame.ShowStdout then
    Exit;

  Result := Pos('stdout;', LowerCase(ALine)) = 0;
end;

function TMainForm.GameTitleEngineName(AEngine: TExternalEngineDefinition): string;
begin
  Result := '';
  if AEngine <> nil then
  begin
    Result := Trim(AEngine.IdText);
    if Result = '' then
      Result := ChangeFileExt(AEngine.ExecutableName, '');
    if Result = '' then
      Result := ChangeFileExt(ExtractFileName(AEngine.ExePath), '');
  end;
  if Result = '' then
    Result := 'Engine';
end;

procedure TMainForm.PrepareGameTreeForPdn(AGame: TRunningGame;
  AGameTree: TGameTree; const AEventName: string);
var
  LBlackName: string;
  LEventName: string;
  LResultText: string;
  LStartingFEN: string;
  LWhiteName: string;

  procedure ApplyHeader(const AResolvedEventName, AResolvedWhiteName,
    AResolvedBlackName, AResolvedResultText, AResolvedStartingFEN: string);
  var
    Actor: TGameTreeActor;
    LErrorText: string;
  begin
    Actor := ActorForGameTree(AGameTree);
    if Actor = nil then
      Exit;

    SetGameTreeHeader(Actor,
      GameTreeHeaderInput('', AResolvedEventName, AResolvedWhiteName,
        AResolvedBlackName, AResolvedResultText, AResolvedStartingFEN,
        False, DefaultTimeControl), LErrorText);
  end;
begin
  if AGameTree = nil then
    Exit;

  if AGame <> nil then
  begin
    LEventName := PlayerNameOrFallback(AEventName,
      EventNameForTree(AGameTree));
    LWhiteName := PlayerNameOrFallback(AGame.Snapshot.WhitePlayerName,
      PlayerNameOrFallback(AGame.WhiteDisplayName, 'White'));
    LBlackName := PlayerNameOrFallback(AGame.Snapshot.BlackPlayerName,
      PlayerNameOrFallback(AGame.BlackDisplayName, 'Black'));
    LResultText := PlayerNameOrFallback(AGame.Snapshot.GameResult, '*');
    LStartingFEN := PlayerNameOrFallback(AGame.Snapshot.StartingFEN,
      AGame.FSetup.StartingFEN);
    ApplyHeader(LEventName, LWhiteName, LBlackName, LResultText,
      LStartingFEN);
    Exit;
  end;

  LEventName := PlayerNameOrFallback(AEventName, EventNameForTree(AGameTree));
  LWhiteName := PlayerNameOrFallback(FWhitePlayerEdit.Text,
    WhiteNameForTree(AGameTree));
  LBlackName := PlayerNameOrFallback(FBlackPlayerEdit.Text,
    BlackNameForTree(AGameTree));
  LResultText := ResultForTree(AGameTree);

  ApplyHeader(LEventName, LWhiteName, LBlackName, LResultText,
    StartingFenForTree(AGameTree));
end;

function TMainForm.CurrentGameTreePdnText(const AEventName: string): string;
var
  LGame: TRunningGame;
  LGameTree: TGameTree;
  LOptions: TGameTreePdnRenderOptions;
begin
  Result := '';
  LGameTree := ActiveGameTree;
  if LGameTree = nil then
    Exit;

  LGame := GameForTreeRefresh(LGameTree);
  PrepareGameTreeForPdn(LGame, LGameTree, AEventName);
  LOptions := DefaultGameTreePdnRenderOptions;
  Result := GameTreeToPdnTextEx(LGameTree, LOptions);
end;

function TMainForm.PlayerSetupDisplayName(AKind: TPlayerKind;
  AEngine: TExternalEngineDefinition): string;
begin
  case AKind of
    pkHuman:
      Result := 'Human';
    pkRegistered:
      Result := GameTitleEngineName(AEngine);
  else
    Result := 'Player';
  end;
end;

procedure TMainForm.GameMoveBrowseClick(Sender: TObject);
begin
  ApplyGameMoveMemoCaretBrowse;
end;

function TMainForm.ApplyGameMoveMemoCaretBrowse: Boolean;
var
  I: Integer;
  LGameTree: TGameTree;
  LFirstMoveStart: Integer;
  LPos: Integer;
begin
  Result := False;
  if FGameMoveMemo = nil then
    Exit;
  LGameTree := ActiveGameTree;
  LPos := FGameMoveMemo.SelStart;
  for I := 0 to High(FVariationHits) do
    if (LPos >= FVariationHits[I].Start) and
      (LPos <= FVariationHits[I].Start + FVariationHits[I].Length) then
    begin
      ApplyVariationBrowsePly(FVariationHits[I].VariationIndex,
        FVariationHits[I].VariationPly, LGameTree);
      HighlightGameMoveTextSelection(True, LGameTree);
      Result := True;
      Exit;
    end;

  for I := 0 to High(FGameMoveStarts) do
    if (LPos >= FGameMoveStarts[I]) and
      (LPos <= FGameMoveStarts[I] + FGameMoveLengths[I]) then
    begin
      ApplyGameBrowsePly(I + 1);
      HighlightGameMoveTextSelection(True, LGameTree);
      Result := True;
      Exit;
    end;

  if Length(FGameMoveStarts) > 0 then
  begin
    LFirstMoveStart := FGameMoveStarts[0];
    if LPos < LFirstMoveStart then
    begin
      ApplyGameBrowsePly(0);
      HighlightGameMoveTextSelection(True, LGameTree);
      Result := True;
    end;
  end;
end;

procedure TMainForm.HideMoveAnnotationsClick(Sender: TObject);
begin
  FHideMoveAnnotations := not FHideMoveAnnotations;
  if FHideMoveAnnotationsMenuItem <> nil then
    FHideMoveAnnotationsMenuItem.Checked := FHideMoveAnnotations;
  RebuildGameMoveLabels(ActiveGameTree);
end;

procedure TMainForm.GameMovePopupPopup(Sender: TObject);
begin
  UpdateGameMovePopupState;
end;

procedure TMainForm.UpdateGameMovePopupState;
begin
  if FMoveShowEnginePVMoveMenuItem <> nil then
    FMoveShowEnginePVMoveMenuItem.Checked := FMoveShowEnginePVMove;
  if FMoveShowEngineFullPVMenuItem <> nil then
    FMoveShowEngineFullPVMenuItem.Checked := FMoveShowEngineFullPV;
  if FMoveShowAnnotatorPVMoveMenuItem <> nil then
    FMoveShowAnnotatorPVMoveMenuItem.Checked := FMoveShowAnnotatorPVMove;
  if FMoveShowAnnotatorFullPVMenuItem <> nil then
    FMoveShowAnnotatorFullPVMenuItem.Checked := FMoveShowAnnotatorFullPV;
end;

procedure TMainForm.MoveDisplayFilterClick(Sender: TObject);
var
  LItem: TMenuItem;
  LGameTree: TGameTree;
begin
  if not (Sender is TMenuItem) then
    Exit;

  LGameTree := ActiveGameTree;
  LItem := TMenuItem(Sender);
  LItem.Checked := not LItem.Checked;
  case LItem.Tag of
    1:
      FMoveShowEngineScore := LItem.Checked;
    2:
      FMoveShowEnginePVMove := LItem.Checked;
    3:
      FMoveShowClocks := LItem.Checked;
    4:
      FMoveShowAnnotatorPVMove := LItem.Checked;
    5:
      FMoveShowAnnotatorScore := LItem.Checked;
    6:
      FMoveShowEngineFullPV := LItem.Checked;
    7:
      FMoveShowAnnotatorFullPV := LItem.Checked;
  end;
  UpdateGameMovePopupState;
  RebuildGameMoveLabels(LGameTree);
end;

procedure TMainForm.GameTreeFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  FGameTreeBrowseMode := False;
  CloseAction := caHide;
end;

procedure TMainForm.GameTreeViewClick(Sender: TObject);
begin
  FGameTreeBrowseMode := True;
  if (FGameTreeView <> nil) and FGameTreeView.CanFocus then
    FGameTreeView.SetFocus;
end;

procedure TMainForm.GameTreeViewKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  LGameTree: TGameTree;
begin
  if Key <> VK_ESCAPE then
    Exit;

  FGameTreeBrowseMode := False;
  LGameTree := ActiveGameTree;
  UpdateGameTreeView(LGameTree);
  Key := 0;
end;

procedure TMainForm.CopyGameTreePdnClick(Sender: TObject);
var
  LGame: TRunningGame;
  LGameTree: TGameTree;
  LOptions: TGameTreePdnRenderOptions;
begin
  LGameTree := ActiveGameTree;
  if LGameTree = nil then
    Exit;
  LGame := GameForTreeRefresh(LGameTree);
  PrepareGameTreeForPdn(LGame, LGameTree, '');
  LOptions := CurrentFilteredGameTreePdnOptions;
  Clipboard.AsText := GameTreeToPdnTextEx(LGameTree, LOptions);
end;

procedure TMainForm.ShowGameTreeClick(Sender: TObject);
var
  LGameTree: TGameTree;
  LMenuItem: TMenuItem;
  LPopup: TPopupMenu;
begin
  if FGameTreeForm = nil then
  begin
    FGameTreeForm := TForm.Create(Self);
    FGameTreeForm.Caption := 'Game tree';
    FGameTreeForm.Position := poDesigned;
    FGameTreeForm.Width := 520;
    FGameTreeForm.Height := 640;
    FGameTreeForm.Constraints.MinWidth := 320;
    FGameTreeForm.Constraints.MinHeight := 360;
    FGameTreeForm.OnClose := @GameTreeFormClose;
    CenterFormOnLaptopPanel(FGameTreeForm, 0);

    FGameTreeView := TTreeView.Create(FGameTreeForm);
    FGameTreeView.Parent := FGameTreeForm;
    FGameTreeView.Align := alClient;
    FGameTreeView.ReadOnly := True;
    FGameTreeView.HideSelection := False;
    FGameTreeView.Options := FGameTreeView.Options - [tvoToolTips];
    FGameTreeView.ShowHint := True;
    FGameTreeView.Hint := 'Click to browse/freeze updates. Press Escape to resume live updates.';
    FGameTreeView.OnClick := @GameTreeViewClick;
    FGameTreeView.OnKeyDown := @GameTreeViewKeyDown;

    LPopup := TPopupMenu.Create(FGameTreeForm);
    LMenuItem := TMenuItem.Create(FGameTreeForm);
    LMenuItem.Caption := 'Copy tree PDN to clipboard';
    LMenuItem.OnClick := @CopyGameTreePdnClick;
    LPopup.Items.Add(LMenuItem);
    FGameTreeView.PopupMenu := LPopup;
  end;

  FGameTreeBrowseMode := False;
  LGameTree := ActiveGameTree;
  UpdateGameTreeView(LGameTree);
  FGameTreeForm.Show;
  FGameTreeForm.BringToFront;
end;

procedure TMainForm.HighlightGameMoveTextSelection(AFocusMemo: Boolean;
  AGameTree: TGameTree);
var
  I: Integer;
  VariationLine: TGameTreeVariationLine;
begin
  if FGameMoveMemo = nil then
    Exit;
  VariationLine := TreeVariationLineByIndex(FVariationIndex, AGameTree);
  if (VariationLine <> nil) and (VariationLine.BasePly = FGameBrowsePly) and
    (FVariationBrowsePly > 0) then
  begin
    for I := 0 to High(FVariationHits) do
      if (FVariationHits[I].VariationIndex = FVariationIndex) and
        (FVariationHits[I].VariationPly = FVariationBrowsePly) then
      begin
        FGameMoveMemo.SelStart := FVariationHits[I].Start;
        FGameMoveMemo.SelLength := FVariationHits[I].Length;
        if AFocusMemo and FGameMoveMemo.CanFocus then
          FGameMoveMemo.SetFocus;
        Exit;
      end;
  end;
  if (FGameBrowsePly > 0) and (FGameBrowsePly <= Length(FGameMoveStarts)) then
  begin
    FGameMoveMemo.SelStart := FGameMoveStarts[FGameBrowsePly - 1];
    FGameMoveMemo.SelLength := FGameMoveLengths[FGameBrowsePly - 1];
  end;
  if AFocusMemo and FGameMoveMemo.CanFocus then
    FGameMoveMemo.SetFocus;
end;

procedure TMainForm.GameMoveBrowseKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  LGameTree: TGameTree;
  LPly: Integer;
  LVariationMoveCount: Integer;
  VariationLine: TGameTreeVariationLine;
begin
  LGameTree := ActiveGameTree;
  if Key = VK_LEFT then
  begin
    VariationLine := TreeVariationLineByIndex(FVariationIndex, LGameTree);
    if (VariationLine <> nil) and (VariationLine.BasePly = FGameBrowsePly) and
      (FVariationBrowsePly > 0) then
    begin
      if FVariationBrowsePly > 1 then
        ApplyVariationBrowsePly(FVariationIndex, FVariationBrowsePly - 1,
          LGameTree)
      else
        ApplyGameBrowsePly(VariationLine.BasePly);
      HighlightGameMoveTextSelection(True, LGameTree);
      Key := 0;
      Exit;
    end;

    if FGameBrowsePly < 0 then
      LPly := CurrentMoveCount
    else
      LPly := FGameBrowsePly - 1;
    ApplyGameBrowsePly(LPly);
    HighlightGameMoveTextSelection(True, LGameTree);
    Key := 0;
  end
  else if Key = VK_RIGHT then
  begin
    VariationLine := TreeVariationLineByIndex(FVariationIndex, LGameTree);
    if (VariationLine <> nil) and (VariationLine.BasePly = FGameBrowsePly) and
      (FVariationBrowsePly > 0) then
    begin
      LVariationMoveCount := CurrentVariationMoveCount(LGameTree);
      if FVariationBrowsePly < LVariationMoveCount then
        ApplyVariationBrowsePly(FVariationIndex, FVariationBrowsePly + 1,
          LGameTree);
      HighlightGameMoveTextSelection(True, LGameTree);
      Key := 0;
      Exit;
    end;

    if FGameBrowsePly < 0 then
      LPly := 0
    else
      LPly := FGameBrowsePly + 1;
    ApplyGameBrowsePly(LPly);
    HighlightGameMoveTextSelection(True, LGameTree);
    Key := 0;
  end
  else if Key = VK_ESCAPE then
  begin
    ExitGameBrowseMode;
    Key := 0;
  end;
end;

procedure TMainForm.MainFormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    ExitGameBrowseMode;
    Key := 0;
  end
  else if ((Key = Ord('F')) or (Key = Ord('f'))) and (Shift = []) then
  begin
    ToggleBoardFlipped;
    Key := 0;
  end;
end;

procedure TMainForm.BoardPopupPopup(Sender: TObject);
begin
  if FSearchPositionInDatabaseMenuItem <> nil then
  begin
    FSearchPositionInDatabaseMenuItem.Enabled :=
      (FDatabaseForm <> nil) and FDatabaseForm.Visible;
    FSearchPositionInDatabaseMenuItem.Checked := FSearchPositionInDatabase;
  end;
end;

procedure TMainForm.GamesPopupPopup(Sender: TObject);
var
  LGame: TRunningGame;
begin
  LGame := SelectedGame;
  if FShowStdoutMenuItem = nil then
    Exit;

  FShowStdoutMenuItem.Enabled := LGame <> nil;
  FShowStdoutMenuItem.Checked := (LGame <> nil) and LGame.ShowStdout;
  if FReplayGameMenuItem <> nil then
    FReplayGameMenuItem.Enabled := LGame <> nil;
  if FPauseGameMenuItem <> nil then
  begin
    FPauseGameMenuItem.Enabled := (LGame <> nil) and
      (LGame.Snapshot.State in [gosWaiting, gosRunning]);
    if (LGame <> nil) and LGame.Paused then
      FPauseGameMenuItem.Caption := 'Resume game'
    else
      FPauseGameMenuItem.Caption := 'Pause game';
  end;
  if FStopGameMenuItem <> nil then
    FStopGameMenuItem.Enabled := (LGame <> nil) and
      (LGame.Lifecycle <> rglFinished);
  if FRemoveGameMenuItem <> nil then
    FRemoveGameMenuItem.Enabled := LGame <> nil;
end;

procedure TMainForm.NewGameClick(Sender: TObject);
var
  LBusyEngineKeys: TStringList;
begin
  if FSetupForm = nil then
  begin
    FSetupForm := TGameSetupForm.Create(Self);
    FSetupForm.OnAccepted := @GameSetupAccepted;
  end;
  FSetupForm.ApplyPreferences(FPreferences);
  LBusyEngineKeys := TStringList.Create;
  try
    CollectBusyEngineKeys(LBusyEngineKeys);
    FSetupForm.SetBusyEngineKeys(LBusyEngineKeys);
  finally
    LBusyEngineKeys.Free;
  end;
  ShowFormCenteredOnOwner(FSetupForm, Self);
end;

procedure TMainForm.EnginesClick(Sender: TObject);
begin
  if FEnginesDialog = nil then
    FEnginesDialog := TEnginesDialog.Create(Self);
  ShowFormCenteredOnOwner(FEnginesDialog, Self);
end;

procedure TMainForm.CreateDatabaseClick(Sender: TObject);
var
  Dialog: TSaveDialog;
begin
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Title := 'Create database';
    Dialog.DefaultExt := 'sqlite';
    Dialog.Filter := 'SQLite database (*.sqlite)|*.sqlite|All files (*)|*';
    Dialog.Options := Dialog.Options + [ofOverwritePrompt, ofEnableSizing];
    if not Dialog.Execute then
      Exit;

    if FDatabaseForm = nil then
      FDatabaseForm := TDatabaseForm.Create(Self);
    try
      FDatabaseForm.OnGameSelected := @PdnGameSelected;
      FDatabaseForm.ApplyPreferences(FPreferences);
      FDatabaseForm.CreateDatabase(Dialog.FileName);
      FDatabaseForm.SetSearchFEN(ActiveBoard.CurrentFEN);
      FLastDatabaseSearchFEN := '';
      ShowFormCenteredOnOwner(FDatabaseForm, Self);
      UpdateDatabaseSearchPosition;
    except
      on E: Exception do
        ShowGuiOkDialog(Self, 'Create database',
          'Could not create database: ' + E.Message);
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TMainForm.OpenDatabaseClick(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := 'Open database';
    Dialog.Filter := 'SQLite database (*.sqlite;*.db)|*.sqlite;*.db|All files (*)|*';
    Dialog.Options := Dialog.Options + [ofFileMustExist, ofEnableSizing];
    if not Dialog.Execute then
      Exit;

    if FDatabaseForm = nil then
      FDatabaseForm := TDatabaseForm.Create(Self);
    try
      FDatabaseForm.OnGameSelected := @PdnGameSelected;
      FDatabaseForm.ApplyPreferences(FPreferences);
      FDatabaseForm.OpenDatabase(Dialog.FileName);
      FDatabaseForm.SetSearchFEN(ActiveBoard.CurrentFEN);
      FLastDatabaseSearchFEN := '';
      ShowFormCenteredOnOwner(FDatabaseForm, Self);
      UpdateDatabaseSearchPosition;
    except
      on E: Exception do
        ShowGuiOkDialog(Self, 'Open database',
          'Could not open database: ' + E.Message);
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TMainForm.OpenPdnClick(Sender: TObject);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(Self);
  try
    Dialog.Title := 'Open PDN';
    Dialog.Filter := 'PDN files (*.pdn)|*.pdn|All files (*)|*';
    Dialog.Options := Dialog.Options + [ofFileMustExist, ofEnableSizing];
    if not Dialog.Execute then
      Exit;

    if FPdnOpenDialog = nil then
    begin
      FPdnOpenDialog := TPdnOpenDialog.Create(Self);
      FPdnOpenDialog.OnGameSelected := @PdnGameSelected;
    end;
    try
      FPdnOpenDialog.OpenPdnFile(Dialog.FileName);
    except
      on E: Exception do
        ShowGuiOkDialog(Self, 'Open PDN',
          'Could not open PDN: ' + E.Message);
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TMainForm.PauseGameClick(Sender: TObject);
var
  LGame: TRunningGame;
begin
  LGame := SelectedGame;
  if LGame = nil then
    Exit;
  if not (LGame.Snapshot.State in [gosWaiting, gosRunning]) then
    Exit;

  LGame.Paused := not LGame.Paused;
  if LGame.Runner <> nil then
    LGame.Runner.PostPause(LGame.Paused);
  if LGame.Paused then
    LGame.Snapshot.LogLines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
      ' [gui] pause requested')
  else
    LGame.Snapshot.LogLines.Add(FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
      ' [gui] resume requested');
  UpdateGameListItem(LGame);
  ApplyGameToDisplay(LGame);
end;

procedure TMainForm.PdnGameSelected(Sender: TObject; AGame: TPdnGame);
begin
  LoadPdnGameToDisplay(AGame);
end;

procedure TMainForm.AppendRunningGameToPdn(AGame: TRunningGame;
  const AFileName, AEventName: string);
var
  Game: TPdnGame;
  LPdnText: string;
begin
  if (AGame = nil) or (Trim(AFileName) = '') then
    Exit;

  LPdnText := RunningGameTreePdnText(AGame, AEventName);
  if Trim(LPdnText) <> '' then
  begin
    AppendPdnTextToFile(AFileName, LPdnText);
    Exit;
  end;

  Game := TPdnGame.Create;
  try
    Game.WhiteName := PlayerNameOrFallback(AGame.Snapshot.WhitePlayerName,
      'White');
    Game.BlackName := PlayerNameOrFallback(AGame.Snapshot.BlackPlayerName,
      'Black');
    Game.EventName := PlayerNameOrFallback(AEventName, '?');
    Game.ResultText := AGame.Snapshot.GameResult;
    Game.StartingFEN := AGame.Snapshot.StartingFEN;
    Game.MovesText := AGame.Snapshot.MovesPlayedText;
    Game.MoveAnnotationsText := AGame.Snapshot.MoveAnnotationsText;
    AppendPdnGameToFile(AFileName, Game);
  finally
    Game.Free;
  end;
end;

function TMainForm.SaveCurrentGameWithDialog: Boolean;
var
  Dialog: TSaveDialog;
  LPdnText: string;
  RunningGame: TRunningGame;
begin
  Result := False;
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Title := 'Save PDN';
    Dialog.Filter := 'PDN files (*.pdn)|*.pdn|All files (*)|*';
    Dialog.DefaultExt := 'pdn';
    Dialog.Options := Dialog.Options + [ofPathMustExist, ofEnableSizing];
    if not Dialog.Execute then
      Exit;

    RunningGame := SelectedDisplayedGame;
    if RunningGame <> nil then
    begin
      AppendRunningGameToPdn(RunningGame, Dialog.FileName,
        EventNameForTree(RunningGame.GameTree));
      Result := True;
      Exit;
    end;

    LPdnText := CurrentGameTreePdnText(EventNameForTree(FGameTree));
    AppendPdnTextToFile(Dialog.FileName, LPdnText);
    Result := True;
  finally
    Dialog.Free;
  end;
end;

procedure TMainForm.SavePdnClick(Sender: TObject);
begin
  SaveCurrentGameWithDialog;
end;

procedure TMainForm.ScoreHistoryPopoutClick(Sender: TObject);
begin
  if FScoreHistoryControl = nil then
    Exit;
  if FScoreHistoryForm = nil then
  begin
    FScoreHistoryForm := TScoreHistoryForm.Create(Self);
    FScoreHistoryForm.OnClose := @ScoreHistoryFormClose;
  end;
  FScoreHistoryForm.UpdateScores(FScoreHistoryControl.AnnotationsText,
    FScoreHistoryControl.PlyCount, FScoreHistoryControl.CurrentPly,
    FScoreHistoryControl.MaxScore, FScoreHistoryControl.Scale,
    FScoreHistoryControl.StartingSide);
  ShowFormCenteredOnOwner(FScoreHistoryForm, Self);
end;

procedure TMainForm.ScoreHistoryFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
end;

procedure TMainForm.SearchPositionInDatabaseClick(Sender: TObject);
begin
  if (FDatabaseForm = nil) or (not FDatabaseForm.Visible) then
    Exit;
  FSearchPositionInDatabase := not FSearchPositionInDatabase;
  if FSearchPositionInDatabaseMenuItem <> nil then
    FSearchPositionInDatabaseMenuItem.Checked := FSearchPositionInDatabase;
  if FSearchPositionInDatabase then
  begin
    FLastDatabaseSearchFEN := '';
    UpdateDatabaseSearchPosition;
  end;
end;

procedure TMainForm.GameSetupAccepted(Sender: TObject; const ASetup: TGameSetup);
begin
  StartGameFromSetup(ASetup);
end;

function TMainForm.StartGameFromSetup(const ASetup: TGameSetup;
  const ATitlePrefix: string): TRunningGame;
var
  LBlackEngineKey: string;
  LBlackName: string;
  LGameId: Integer;
  LReservationKeys: TStringList;
  LRunner: TGameRunnerThread;
  LTitle: string;
  LWhiteEngineKey: string;
  LWhiteName: string;
begin
  LWhiteName := PlayerSetupDisplayName(ASetup.WhitePlayer, ASetup.WhiteEngine);
  LBlackName := PlayerSetupDisplayName(ASetup.BlackPlayer, ASetup.BlackEngine);
  LTitle := Trim(ATitlePrefix);
  if LTitle = '' then
    LTitle := 'Game';
  if SameText(LTitle, 'Tournament game') then
    LTitle := 'Tournament ' + LWhiteName + ' vs ' + LBlackName
  else
    LTitle := LTitle + ' ' + IntToStr(FGames.Count + 1) + ' ' +
      LWhiteName + ' vs ' + LBlackName;
  LWhiteEngineKey := EngineIdentityKey(ASetup.WhiteEngine);
  LBlackEngineKey := EngineIdentityKey(ASetup.BlackEngine);
  LReservationKeys := TStringList.Create;
  try
    LReservationKeys.Sorted := True;
    LReservationKeys.Duplicates := dupIgnore;
    AddEngineReservationKeys(ASetup.WhiteEngine, LReservationKeys);
    AddEngineReservationKeys(ASetup.BlackEngine, LReservationKeys);
    if LWhiteEngineKey <> '' then
      LReservationKeys.Add(LWhiteEngineKey);
    if LBlackEngineKey <> '' then
      LReservationKeys.Add(LBlackEngineKey);

  Inc(FNextGameId);
  LGameId := FNextGameId;
  LRunner := TGameRunnerThread.Create(ASetup, LGameId, @GameSnapshot,
    @GameFinished);
  Result := TRunningGame.Create(LGameId, LTitle, LRunner,
      ASetup.WhitePlayer, ASetup.BlackPlayer, LWhiteEngineKey,
      LBlackEngineKey, LWhiteName, LBlackName, LReservationKeys, ASetup);
  finally
    LReservationKeys.Free;
  end;
  FGames.Add(Result);
  FGamesListBox.Items.AddObject(LTitle + ' - starting', Result);
  FGamesListBox.ItemIndex := FGamesListBox.Items.Count - 1;

  ClearHumanMoveSelection;
  FBoard.LoadFromFEN(ASetup.StartingFEN);
  FStartingFEN := ASetup.StartingFEN;
  FDisplayedAnnotationsSignature := '';
  FDisplayedMovesSignature := '';
  FDisplayedGameTreeId := 0;
  FDisplayedGameTreeRevision := -1;
  ClearStoredTreeVariations(Result.GameTree);
  FGameBrowsePly := -1;
  FWhiteRemainingSeconds := ASetup.TimeControl.MinutesPerPeriod * 60;
  FBlackRemainingSeconds := FWhiteRemainingSeconds;
  FWhiteUsedSeconds := 0;
  FBlackUsedSeconds := 0;
  FGameState := gosRunning;
  FGameResult := '*';
  FPrincipalVariation := '';
  FPrincipalVariationScore := '';
  FPrincipalVariationDepth := '';
  FPrincipalVariationTimeText := '';
  FPvBaseBoard.AssignFrom(FBoard);
  FPvBasePly := 0;
  FGameActive := True;
  FDisplayedAnnotationsSignature := '';
  FDisplayedSnapshotSignature := '';
  FDisplayedGameTreeId := 0;
  FDisplayedGameTreeRevision := -1;
  FBoardControl.Board := FBoard;
  UpdateMiniBoardFromBoard(FBoard);
  FGameLogMemo.Clear;
  FGameLogMemoGameId := -1;
  FGameLogMemoLineCount := -1;
  UpdateGameTreeFromMoveText(Result, Result.GameTree, '', '');
  UpdateBoardInfo;

  LRunner.Start;
end;

procedure TMainForm.CollectBusyEngineKeys(AKeys: TStrings);
var
  I: Integer;
  LGame: TRunningGame;
begin
  if AKeys = nil then
    Exit;

  AKeys.Clear;
  if FAnalyzerEngineKey <> '' then
    AKeys.Add(FAnalyzerEngineKey);
  if FMctsEngineKey <> '' then
    AKeys.Add(FMctsEngineKey);
  for I := 0 to FGames.Count - 1 do
  begin
    LGame := TRunningGame(FGames[I]);
    if not LGame.IsEngineReservationActive then
      Continue;
    AKeys.AddStrings(LGame.FReservationKeys);
  end;
end;

procedure TMainForm.MarkGameStopped(AGame: TRunningGame; const AReason: string);
begin
  if AGame = nil then
    Exit;

  if AGame.Runner <> nil then
    AGame.Runner.PostStop;
  AGame.Paused := False;
  if not (AGame.FLifecycle in [rglFinished, rglRemoveRequested]) then
    AGame.FLifecycle := rglStopRequested;
  AGame.FStopReason := AReason;
  AGame.Snapshot.MarkStopped(AGame.StopReason);
  if not FClosing then
  begin
    UpdateGameListItem(AGame);
    if SelectedGame = AGame then
      ApplyGameToDisplay(AGame);
  end;
end;

procedure TMainForm.GuiEventTimerTick(Sender: TObject);
const
  MaxGuiEventsPerTimerTick = 100;
type
  TPendingAnalyzerSnapshot = record
    Key: string;
    Message: TAnalyzerSnapshotGuiMessage;
  end;
  TPendingRunnerSnapshot = record
    GameId: Integer;
    Message: TRunnerSnapshotGuiMessage;
  end;
var
  PendingAnalyzerSnapshots: array of TPendingAnalyzerSnapshot;
  DrainAllEvents: Boolean;
  EventObject: TObject;
  LGame: TRunningGame;
  LGameTree: TGameTree;
  PendingSnapshots: array of TPendingRunnerSnapshot;
  ProcessedEvents: Integer;
  RemoveAfterFinish: Boolean;
  SnapshotMessage: TRunnerSnapshotGuiMessage;

  function AnalyzerSnapshotKey(AMessage: TAnalyzerSnapshotGuiMessage): string;
  var
    Search: TGameTreeSearchRef;
  begin
    Result := '';
    if (AMessage = nil) or (AMessage.Snapshot = nil) then
      Exit;
    Search := AMessage.Snapshot.SearchRef;
    if IsValidGameTreeSearchRef(Search) then
      Result := 'search:' + IntToStr(Search.GameTreeId) + ':' +
        IntToStr(Search.SearchId) + ':' + IntToStr(Search.NodeId)
    else
      Result := 'display';
  end;

  procedure ApplyAnalyzerSnapshot(AMessage: TAnalyzerSnapshotGuiMessage);
  begin
    if (AMessage = nil) or (AMessage.Snapshot = nil) then
      Exit;

    SetAnalyzerPvBase(AMessage.Snapshot.BaseBoard, AMessage.Snapshot.BasePly);
    LGameTree := RecordAnalyzerSnapshotInGameTree(AMessage.Snapshot);
    if LGameTree = nil then
      Exit;
    if (not AMessage.Snapshot.GameTreeOnly) and
      (FAnalyzerPvBrowser <> nil) then
      FAnalyzerPvBrowser.SetSnapshot(AMessage.Snapshot,
        StartingFenForTree(LGameTree));
    RefreshVisibleGameTreeView(LGameTree);
    if (not AMessage.Snapshot.GameTreeOnly) and
      (FPvHintSource = phsAnalyzer) then
    begin
      UpdateBoardHighlights(LGameTree);
      if FBoardControl <> nil then
        FBoardControl.Invalidate;
    end;
  end;

  procedure FlushPendingAnalyzerSnapshots;
  var
    I: Integer;
  begin
    for I := 0 to High(PendingAnalyzerSnapshots) do
    begin
      try
        ApplyAnalyzerSnapshot(PendingAnalyzerSnapshots[I].Message);
      finally
        PendingAnalyzerSnapshots[I].Message.Free;
        PendingAnalyzerSnapshots[I].Message := nil;
      end;
    end;
    SetLength(PendingAnalyzerSnapshots, 0);
  end;

  procedure QueueAnalyzerSnapshot(AMessage: TAnalyzerSnapshotGuiMessage);
  var
    I: Integer;
    Key: string;
  begin
    if AMessage = nil then
      Exit;
    Key := AnalyzerSnapshotKey(AMessage);
    for I := 0 to High(PendingAnalyzerSnapshots) do
      if PendingAnalyzerSnapshots[I].Key = Key then
      begin
        PendingAnalyzerSnapshots[I].Message.Free;
        PendingAnalyzerSnapshots[I].Message := AMessage;
        Exit;
      end;
    I := Length(PendingAnalyzerSnapshots);
    SetLength(PendingAnalyzerSnapshots, I + 1);
    PendingAnalyzerSnapshots[I].Key := Key;
    PendingAnalyzerSnapshots[I].Message := AMessage;
  end;

  procedure ApplyRunnerSnapshot(AMessage: TRunnerSnapshotGuiMessage);
  begin
    if AMessage = nil then
      Exit;

    LGame := FindGameById(AMessage.GameId);
    if LGame = nil then
      Exit;

    LGame.Snapshot.AssignFrom(AMessage.Snapshot);
    UpdateRunningGameTreeFromSnapshot(LGame);
    if LGame.FLifecycle = rglStarting then
      LGame.FLifecycle := rglRunning;
    if (LGame.FLifecycle in [rglStopRequested, rglRemoveRequested]) and
      (LGame.Snapshot.State in [gosWaiting, gosRunning, gosError]) then
      LGame.Snapshot.MarkStopped(LGame.StopReason);
    if not FClosing then
    begin
      UpdateGameListItem(LGame);
      if SelectedGame = LGame then
        ApplyGameToDisplay(LGame);
    end;
  end;

  procedure FlushPendingRunnerSnapshots;
  var
    I: Integer;
  begin
    for I := 0 to High(PendingSnapshots) do
    begin
      try
        ApplyRunnerSnapshot(PendingSnapshots[I].Message);
      finally
        PendingSnapshots[I].Message.Free;
        PendingSnapshots[I].Message := nil;
      end;
    end;
    SetLength(PendingSnapshots, 0);
  end;

  procedure QueueRunnerSnapshot(AMessage: TRunnerSnapshotGuiMessage);
  var
    I: Integer;
  begin
    if AMessage = nil then
      Exit;
    for I := 0 to High(PendingSnapshots) do
      if PendingSnapshots[I].GameId = AMessage.GameId then
      begin
        PendingSnapshots[I].Message.Free;
        PendingSnapshots[I].Message := AMessage;
        Exit;
      end;
    I := Length(PendingSnapshots);
    SetLength(PendingSnapshots, I + 1);
    PendingSnapshots[I].GameId := AMessage.GameId;
    PendingSnapshots[I].Message := AMessage;
  end;
begin
  if FGuiEventQueue = nil then
    Exit;

  DrainAllEvents := Sender = nil;
  ProcessedEvents := 0;
  try
    while FGuiEventQueue.TryPop(EventObject) do
    begin
      Inc(ProcessedEvents);
      try
        if EventObject is TAnalyzerSnapshotGuiMessage then
        begin
          QueueAnalyzerSnapshot(TAnalyzerSnapshotGuiMessage(EventObject));
          EventObject := nil;
          Continue;
        end;

        if EventObject is TRunnerSnapshotGuiMessage then
        begin
          SnapshotMessage := TRunnerSnapshotGuiMessage(EventObject);
          QueueRunnerSnapshot(SnapshotMessage);
          EventObject := nil;
          Continue;
        end;

        FlushPendingAnalyzerSnapshots;
        FlushPendingRunnerSnapshots;

        if EventObject is TAnalyzerLogGuiMessage then
          HandleAnalyzerLog(TAnalyzerLogGuiMessage(EventObject).Message)
        else if EventObject is TAnalyzerMoveGuiMessage then
          HandleAnalyzerMove(TAnalyzerMoveGuiMessage(EventObject).Search,
            TAnalyzerMoveGuiMessage(EventObject).MoveText)
        else if EventObject is TMctsLogGuiMessage then
          HandleMctsLog(TMctsLogGuiMessage(EventObject).Message)
        else if EventObject is TAnalyzerFinishedGuiMessage then
        begin
          CancelAnalyzerSearch;
          if FAnalyzerRunner = TAnalyzerFinishedGuiMessage(EventObject).Runner then
            FreeAndNil(FAnalyzerRunner);
          FAnalyzerEngineKey := '';
          InvalidateAnalyzerPositionSignature;
          UpdateAutoplayControls;
        end
        else if EventObject is TMctsFinishedGuiMessage then
        begin
          if FMctsRunner = TMctsFinishedGuiMessage(EventObject).Runner then
            FreeAndNil(FMctsRunner);
          FMctsEngineKey := '';
          InvalidateMctsPositionSignature;
        end
        else if EventObject is TRunnerFinishedGuiMessage then
        begin
          LGame := FindGameById(TRunnerFinishedGuiMessage(EventObject).GameId);
          if LGame <> nil then
          begin
            RemoveAfterFinish := LGame.Lifecycle = rglRemoveRequested;
            LGame.FLifecycle := rglFinished;
            if RemoveAfterFinish then
              RemoveGame(LGame)
            else if not FClosing then
            begin
              UpdateGameListItem(LGame);
              if SelectedGame = LGame then
                UpdateAutoplayControls;
            end;
          end;
        end;
      finally
        EventObject.Free;
      end;
      if (not DrainAllEvents) and
        (ProcessedEvents >= MaxGuiEventsPerTimerTick) then
        Break;
    end;
    FlushPendingAnalyzerSnapshots;
    FlushPendingRunnerSnapshots;
  finally
    FlushPendingAnalyzerSnapshots;
    FlushPendingRunnerSnapshots;
  end;
end;

procedure TMainForm.GameFinished(Sender: TObject);
begin
  PostGuiEvent(TRunnerFinishedGuiMessage.Create(TGameRunnerThread(Sender).GameId));
end;

procedure TMainForm.GameSnapshot(Sender: TObject; ASnapshot: TGameRunnerSnapshot);
begin
  if ASnapshot = nil then
    Exit;
  PostGuiEvent(TRunnerSnapshotGuiMessage.Create(
    TGameRunnerThread(Sender).GameId, ASnapshot));
end;

procedure TMainForm.TournamentClick(Sender: TObject);
begin
  if FTournamentDialog = nil then
  begin
    FTournamentDialog := TTournamentDialog.Create(Self);
    FTournamentDialog.OnStartGame := @TournamentStartGame;
  end;
  ShowFormCenteredOnOwner(FTournamentDialog, Self);
end;

procedure TMainForm.TournamentStartGame(Sender: TObject; const ASetup: TGameSetup;
  const ATitlePrefix: string; out AGame: TObject);
begin
  AGame := StartGameFromSetup(ASetup, ATitlePrefix);
end;

procedure TMainForm.GamesListBoxClick(Sender: TObject);
begin
  ApplyGameToDisplay(SelectedGame);
end;

procedure TMainForm.ReplaySelectedGame(Sender: TObject);
var
  BusyKeys: TStringList;
  I: Integer;
  LGame: TRunningGame;
  LReplayKeys: TStringList;
  LSetup: TGameSetup;
begin
  LGame := SelectedGame;
  if LGame = nil then
    Exit;

  LSetup.WhiteEngine := nil;
  LSetup.BlackEngine := nil;
  BusyKeys := TStringList.Create;
  LReplayKeys := TStringList.Create;
  try
    LReplayKeys.Sorted := True;
    LReplayKeys.Duplicates := dupIgnore;
    LGame.AssignSetupTo(LSetup);
    AddEngineReservationKeys(LSetup.WhiteEngine, LReplayKeys);
    AddEngineReservationKeys(LSetup.BlackEngine, LReplayKeys);
    if EngineIdentityKey(LSetup.WhiteEngine) <> '' then
      LReplayKeys.Add(EngineIdentityKey(LSetup.WhiteEngine));
    if EngineIdentityKey(LSetup.BlackEngine) <> '' then
      LReplayKeys.Add(EngineIdentityKey(LSetup.BlackEngine));

    CollectBusyEngineKeys(BusyKeys);
    for I := 0 to LReplayKeys.Count - 1 do
      if BusyKeys.IndexOf(LReplayKeys[I]) >= 0 then
      begin
        ShowGuiOkDialog(Self, 'Replay game',
          'One or more engines from this game are still busy.');
        Exit;
      end;

    StartGameFromSetup(LSetup, 'Replay');
  finally
    LSetup.WhiteEngine.Free;
    LSetup.BlackEngine.Free;
    LReplayKeys.Free;
    BusyKeys.Free;
  end;
end;

procedure TMainForm.ShowStdoutClick(Sender: TObject);
var
  LGame: TRunningGame;
begin
  LGame := SelectedGame;
  if LGame = nil then
    Exit;

  LGame.ShowStdout := not LGame.ShowStdout;
  if LGame.Runner <> nil then
    LGame.Runner.PostShowStdout(LGame.ShowStdout);
  if FShowStdoutMenuItem <> nil then
    FShowStdoutMenuItem.Checked := LGame.ShowStdout;
  ApplyGameToDisplay(LGame);
end;

function TMainForm.SelectedGame: TRunningGame;
begin
  Result := nil;
  if (FGamesListBox.ItemIndex >= 0) and (FGamesListBox.ItemIndex < FGamesListBox.Items.Count) then
    Result := TRunningGame(FGamesListBox.Items.Objects[FGamesListBox.ItemIndex]);
end;

function TMainForm.SelectedDisplayedGame: TRunningGame;
begin
  Result := nil;
  if not FGameActive then
    Exit;
  Result := SelectedGame;
end;

procedure TMainForm.RemoveGame(AGame: TRunningGame);
var
  LIndex: Integer;
begin
  if AGame = nil then
    Exit;

  if AGame.Lifecycle <> rglFinished then
  begin
    MarkGameStopped(AGame, 'Stopped');
    AGame.FLifecycle := rglRemoveRequested;
    if not FClosing then
      UpdateGameListItem(AGame);
    Exit;
  end;

  LIndex := FGamesListBox.Items.IndexOfObject(AGame);
  if (FTournamentDialog <> nil) and
    ((AGame.FTitle <> '') and (Pos('Tournament ', AGame.FTitle) = 1)) then
    FTournamentDialog.GameStopped(AGame);
  FGames.Remove(AGame);
  if LIndex >= 0 then
    FGamesListBox.Items.Delete(LIndex);
  AGame.Free;

  if FClosing then
    Exit;

  if FGamesListBox.Items.Count > 0 then
  begin
    if LIndex < 0 then
      LIndex := FGamesListBox.ItemIndex;
    if LIndex >= FGamesListBox.Items.Count then
      LIndex := FGamesListBox.Items.Count - 1;
    if LIndex < 0 then
      LIndex := 0;
    FGamesListBox.ItemIndex := LIndex;
    ApplyGameToDisplay(SelectedGame);
  end
  else
    ApplyGameToDisplay(nil);
end;

procedure TMainForm.RemoveSelectedGame(Sender: TObject);
var
  LGame: TRunningGame;
begin
  LGame := SelectedGame;
  if LGame = nil then
    Exit;
  RemoveGame(LGame);
end;

procedure TMainForm.StopSelectedGame(Sender: TObject);
var
  LGame: TRunningGame;
begin
  LGame := SelectedGame;
  if LGame = nil then
    Exit;

  if LGame.Lifecycle = rglFinished then
    Exit;

  if FTournamentDialog <> nil then
    FTournamentDialog.GameStopped(LGame);

  MarkGameStopped(LGame, 'Stopped');
  UpdateGameListItem(LGame);
end;

procedure TMainForm.StopAllGames;
const
  GameDrainWarningMs = 10000;
var
  I: Integer;
  LastWarningTick: QWord;
  LGame: TRunningGame;
  PendingText: string;
  WarningText: string;
begin
  for I := FGames.Count - 1 downto 0 do
  begin
    LGame := TRunningGame(FGames[I]);
    if LGame.Lifecycle = rglFinished then
    begin
      RemoveGame(LGame);
      Continue;
    end;
    MarkGameStopped(LGame, 'Application shutdown');
    LGame.FLifecycle := rglRemoveRequested;
  end;

  LastWarningTick := GetTickCount64;
  while FGames.Count > 0 do
  begin
    GuiEventTimerTick(nil);
    if FGames.Count = 0 then
      Break;
    CheckSynchronize(50);
    if GetTickCount64 - LastWarningTick >= GameDrainWarningMs then
    begin
      PendingText := '';
      for I := 0 to FGames.Count - 1 do
      begin
        LGame := TRunningGame(FGames[I]);
        if PendingText <> '' then
          PendingText += '; ';
        PendingText += '#' + IntToStr(LGame.Id) + ' ' + LGame.Title +
          ' [lifecycle=' + RunningGameLifecycleToString(LGame.Lifecycle) +
          ', state=' + OrchestratorStateToString(LGame.Snapshot.State) +
          ', plies=' + IntToStr(LGame.Snapshot.PlyCount) +
          ', reservations=' + LGame.ReservationSummary + ']';
      end;
      WarningText := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) +
        ' [gui] waiting for games to stop; remaining_games=' +
        IntToStr(FGames.Count) + '; pending=' + PendingText;
      WriteLn(WarningText);
      LastWarningTick := GetTickCount64;
    end;
    Sleep(10);
  end;

  if FGamesListBox <> nil then
    FGamesListBox.Clear;
end;

procedure TMainForm.LegalMovesMemoClick(Sender: TObject);
var
  LLineIndex: Integer;
  LMove: string;
  LBoard: TDraughtsBoard;
begin
  LBoard := ActiveBoard;
  LLineIndex := FLegalMovesMemo.CaretPos.Y;
  if (LLineIndex < 0) or (LLineIndex >= FLegalMovesMemo.Lines.Count) then
    Exit;

  LMove := Trim(FLegalMovesMemo.Lines[LLineIndex]);
  if not LBoard.IsLegalMove(LMove) then
    Exit;

  PlayHumanMove(LMove);
end;

procedure TMainForm.UpdateBrowseInfo;
var
  LGameTree: TGameTree;
  LPvBaseBoard: TDraughtsBoard;
  LPvBasePly: Integer;
  LPvDepth: string;
  LPvScore: string;
  LPvText: string;
  LPvTimeText: string;
begin
  LGameTree := ActiveGameTree;
  UpdateBoardHighlights(LGameTree);

  UpdateGameMoveHighlight;
  HighlightGameMoveTextSelection(False, LGameTree);
  UpdateLegalMoves;
  RestartAnalyzer(LGameTree);
  RestartMctsAnnotator(LGameTree);
  UpdateScoreHistory(LGameTree);
  VisibleMainPvForTree(LGameTree, LPvBaseBoard, LPvBasePly, LPvText,
    LPvScore, LPvDepth, LPvTimeText);
  if FPvBrowser <> nil then
    FPvBrowser.SetData(LPvBaseBoard, LPvBasePly,
      StartingFenForTree(LGameTree), LPvText, LPvScore, LPvDepth,
      LPvTimeText);
  if FBoardControl <> nil then
    FBoardControl.Invalidate;
end;

procedure TMainForm.UpdateClockLabels(const AWhiteName, ABlackName: string);
var
  LBlackRemainingSeconds: Double;
  LBlackCaption: string;
  LBlackUsedSeconds: Double;
  LWhiteRemainingSeconds: Double;
  LWhiteCaption: string;
  LWhiteUsedSeconds: Double;
begin
  if not FGameActive then
  begin
    if FBlackClockLabel <> nil then
      FBlackClockLabel.Caption := '';
    if FWhiteClockLabel <> nil then
      FWhiteClockLabel.Caption := '';
    Exit;
  end;

  ClockValuesForTree(ActiveGameTree, LWhiteRemainingSeconds,
    LBlackRemainingSeconds, LWhiteUsedSeconds, LBlackUsedSeconds);

  LBlackCaption := ABlackName + '  ' + FormatClock(LBlackRemainingSeconds) +
    '   used ' + FormatFloat('0.000', LBlackUsedSeconds) + ' s';
  LWhiteCaption := AWhiteName + '  ' + FormatClock(LWhiteRemainingSeconds) +
    '   used ' + FormatFloat('0.000', LWhiteUsedSeconds) + ' s';

  if FBoardFlipped then
  begin
    if (FBlackClockLabel <> nil) and
      (FBlackClockLabel.Caption <> LWhiteCaption) then
      FBlackClockLabel.Caption := LWhiteCaption;
    if (FWhiteClockLabel <> nil) and
      (FWhiteClockLabel.Caption <> LBlackCaption) then
      FWhiteClockLabel.Caption := LBlackCaption;
  end
  else
  begin
    if (FBlackClockLabel <> nil) and
      (FBlackClockLabel.Caption <> LBlackCaption) then
      FBlackClockLabel.Caption := LBlackCaption;
    if (FWhiteClockLabel <> nil) and
      (FWhiteClockLabel.Caption <> LWhiteCaption) then
      FWhiteClockLabel.Caption := LWhiteCaption;
  end;
end;

procedure TMainForm.UpdateBoardInfo;
var
  LGame: TRunningGame;
  LBlackName: string;
  LFenText: string;
  LGameTree: TGameTree;
  LPvBaseBoard: TDraughtsBoard;
  LPvBasePly: Integer;
  LPvDepth: string;
  LPvScore: string;
  LPvText: string;
  LPvTimeText: string;
  LResultText: string;
  LWhiteName: string;
begin
  LGameTree := ActiveGameTree;
  LGame := SelectedGame;

  if LGameTree <> nil then
  begin
    LWhiteName := PlayerNameOrFallback(LGameTree.WhiteName, 'White');
    LBlackName := PlayerNameOrFallback(LGameTree.BlackName, 'Black');
    LResultText := PlayerNameOrFallback(LGameTree.ResultText, '*');
    LFenText := LGameTree.StartingFEN;
  end
  else if LGame <> nil then
  begin
    LWhiteName := PlayerNameOrFallback(LGame.Snapshot.WhitePlayerName,
      PlayerNameOrFallback(LGame.WhiteDisplayName, 'White'));
    LBlackName := PlayerNameOrFallback(LGame.Snapshot.BlackPlayerName,
      PlayerNameOrFallback(LGame.BlackDisplayName, 'Black'));
    LResultText := PlayerNameOrFallback(LGame.Snapshot.GameResult, '*');
    LFenText := PlayerNameOrFallback(LGame.Snapshot.StartingFEN,
      LGame.FSetup.StartingFEN);
  end
  else
  begin
    LWhiteName := WhiteNameForTree(FGameTree);
    LBlackName := BlackNameForTree(FGameTree);
    LResultText := ResultForTree(FGameTree);
    LFenText := StartingFenForTree(FGameTree);
  end;

  UpdateClockLabels(LWhiteName, LBlackName);

  if FWhitePlayerEdit <> nil then
    FWhitePlayerEdit.Text := LWhiteName;
  if FBlackPlayerEdit <> nil then
    FBlackPlayerEdit.Text := LBlackName;
  if FResultEdit <> nil then
    FResultEdit.Text := LResultText;
  if FFenEdit <> nil then
    FFenEdit.Text := LFenText;

  UpdateBoardHighlights(LGameTree);
  RefreshDisplayedGameTreeViews(LGameTree, False);

  UpdateLegalMoves;
  RestartAnalyzer(LGameTree);
  RestartMctsAnnotator(LGameTree);

  UpdateGameLogMemo;

  VisibleMainPvForTree(LGameTree, LPvBaseBoard, LPvBasePly, LPvText,
    LPvScore, LPvDepth, LPvTimeText);

  if FPvBrowser <> nil then
    FPvBrowser.SetData(LPvBaseBoard, LPvBasePly, LFenText,
      LPvText, LPvScore, LPvDepth, LPvTimeText);
  HighlightGameMoveTextSelection(False, LGameTree);
  if FBoardControl <> nil then
    FBoardControl.Invalidate;
  UpdateAutoplayControls;
  UpdateDatabaseSearchPosition;
end;

procedure TMainForm.UpdateDatabaseSearchPosition;
var
  LFen: string;
begin
  if (not FSearchPositionInDatabase) or (FDatabaseForm = nil) or
    (not FDatabaseForm.Visible) then
    Exit;

  LFen := ActiveBoard.CurrentFEN;
  if LFen = FLastDatabaseSearchFEN then
    Exit;
  FLastDatabaseSearchFEN := LFen;
  FDatabaseForm.SetSearchFEN(LFen);
  FDatabaseForm.SearchCurrentPosition;
end;

procedure TMainForm.UpdateScoreHistory(AGameTree: TGameTree);
var
  LAnnotationsText: string;
  LGame: TRunningGame;
  LGameTree: TGameTree;
  LMoveCount: Integer;
  LPly: Integer;
  LStartingFEN: string;
begin
  if FScoreHistoryControl = nil then
    Exit;

  LGameTree := AGameTree;
  if LGameTree = nil then
    Exit;
  LAnnotationsText := GameTreeScoreAnnotationsText(LGameTree);
  LStartingFEN := StartingFenForTree(LGameTree);
  LMoveCount := LGameTree.MainlineCount;
  LGame := GameForTreeRefresh(LGameTree);
  if (Trim(LAnnotationsText) = '') and (LGame <> nil) and
    ((LGame.Lifecycle = rglFinished) or
      (LGame.Snapshot.State in [gosStopped, gosGameOver])) and
    (FScoreHistoryCachedGameTreeId = LGameTree.GameTreeId) and
    (Trim(FScoreHistoryCachedAnnotationsText) <> '') and
    (FScoreHistoryCachedPlyCount <= LMoveCount) then
    LAnnotationsText := FScoreHistoryCachedAnnotationsText
  else if Trim(LAnnotationsText) <> '' then
  begin
    FScoreHistoryCachedGameTreeId := LGameTree.GameTreeId;
    FScoreHistoryCachedAnnotationsText := LAnnotationsText;
    FScoreHistoryCachedPlyCount := LMoveCount;
  end;

  LPly := FGameBrowsePly;
  if LPly < 0 then
    LPly := LMoveCount;
  FScoreHistoryControl.MaxScore := FPreferences.EvaluationMaxScore;
  FScoreHistoryControl.Scale := FPreferences.EvaluationScale;
  FScoreHistoryControl.StartingSide := FenSideToMove(LStartingFEN);
  FScoreHistoryControl.PlyCount := LMoveCount;
  FScoreHistoryControl.AnnotationsText := LAnnotationsText;
  FScoreHistoryControl.CurrentPly := LPly;
  if FScoreHistoryForm <> nil then
    FScoreHistoryForm.UpdateScores(LAnnotationsText, LMoveCount, LPly,
      FPreferences.EvaluationMaxScore, FPreferences.EvaluationScale,
      FenSideToMove(LStartingFEN));
end;

procedure TMainForm.UpdateGameTreeFromMoveText(AGame: TRunningGame;
  AGameTree: TGameTree; const AMovesText, AAnnotationsText: string);
var
  LAnnotations: TStringList;
  LMoves: TStringList;
begin
  if AGameTree = nil then
    Exit;

  LMoves := TStringList.Create;
  LAnnotations := TStringList.Create;
  try
    TextToMoveList(AMovesText, LMoves);
    LAnnotations.Text := AAnnotationsText;

    ExecuteGameTreeRebuildFromInput(AGame, AGameTree, LMoves,
      LAnnotations);
  finally
    LAnnotations.Free;
    LMoves.Free;
  end;
end;

procedure TMainForm.RefreshVisibleGameTreeView(AGameTree: TGameTree);
var
  LGameTree: TGameTree;
begin
  if (FGameTreeForm = nil) or (not FGameTreeForm.Visible) or
    FGameTreeBrowseMode then
    Exit;

  LGameTree := AGameTree;
  if LGameTree = nil then
    Exit;
  UpdateGameTreeView(LGameTree);
end;

procedure TMainForm.RefreshDisplayedGameTreeViews(AGameTree: TGameTree;
  AForce: Boolean);
var
  Actor: TGameTreeActor;
  LGameTreeId: Int64;
  LRevision: Int64;
begin
  if AGameTree = nil then
    Exit;
  if AGameTree <> ActiveGameTree then
    Exit;

  LGameTreeId := AGameTree.GameTreeId;
  LRevision := -1;
  Actor := ActorForGameTree(AGameTree);
  if Actor <> nil then
    LRevision := Actor.Revision;

  if (not AForce) and (FDisplayedGameTreeId = LGameTreeId) and
    (FDisplayedGameTreeRevision = LRevision) then
    Exit;

  RebuildGameMoveLabels(AGameTree);
  UpdateScoreHistory(AGameTree);
  RefreshVisibleGameTreeView(AGameTree);
  FDisplayedGameTreeId := LGameTreeId;
  FDisplayedGameTreeRevision := LRevision;
end;

procedure TMainForm.UpdateGameTreeView(AGameTree: TGameTree);
begin
  if (FGameTreeView = nil) or (AGameTree = nil) then
    Exit;

  PopulateGameTreeView(FGameTreeView, AGameTree);
end;

procedure TMainForm.UpdateGameListItem(AGame: TRunningGame);
var
  I: Integer;
  LBaseTitle: string;
  LBlackName: string;
  LCaption: string;
  LWhiteName: string;
begin
  if (AGame = nil) or (FGamesListBox = nil) then
    Exit;

  LWhiteName := PlayerNameOrFallback(AGame.Snapshot.WhitePlayerName,
    PlayerNameOrFallback(AGame.WhiteDisplayName, 'White'));
  LBlackName := PlayerNameOrFallback(AGame.Snapshot.BlackPlayerName,
    PlayerNameOrFallback(AGame.BlackDisplayName, 'Black'));
  LBaseTitle := AGame.Title;
  if Pos(' vs ', LBaseTitle) = 0 then
    LBaseTitle := LBaseTitle + ' ' + LWhiteName + ' vs ' + LBlackName;

  if AGame.Snapshot.State = gosGameOver then
    LCaption := LBaseTitle + ' - ' + AGame.Snapshot.GameResult
  else
    LCaption := LBaseTitle + ' - ' +
      OrchestratorStateToString(AGame.Snapshot.State);
  case AGame.Lifecycle of
    rglStarting:
      LCaption := LBaseTitle + ' - ' +
        RunningGameLifecycleToString(AGame.Lifecycle);
    rglStopRequested:
      LCaption := LCaption + ' (' +
        RunningGameLifecycleToString(AGame.Lifecycle) + ')';
    rglRemoveRequested:
      LCaption := LCaption + ' (' +
        RunningGameLifecycleToString(AGame.Lifecycle) + ')';
    rglFinished:
      LCaption := LCaption + ' (' +
        RunningGameLifecycleToString(AGame.Lifecycle) + ')';
  end;
  if AGame.Paused and (AGame.Snapshot.State in [gosWaiting, gosRunning]) then
    LCaption := LCaption + ' (paused)';
  LCaption := LCaption + ' - ' + IntToStr(AGame.Snapshot.PlyCount) + ' plies';
  if AGame.FListCaption = LCaption then
    Exit;
  for I := 0 to FGamesListBox.Items.Count - 1 do
    if FGamesListBox.Items.Objects[I] = AGame then
    begin
      FGamesListBox.Items[I] := LCaption;
      FGamesListBox.Items.Objects[I] := AGame;
      AGame.FListCaption := LCaption;
      Exit;
    end;
end;

procedure TMainForm.UpdateLegalMoves;
var
  LBoard: TDraughtsBoard;
begin
  LBoard := ActiveBoard;
  FLegalMovesMemo.Lines.BeginUpdate;
  try
    FLegalMovesMemo.Clear;
    if LBoard.LegalMoves.Count = 0 then
      FLegalMovesMemo.Lines.Add('(none)')
    else
      FLegalMovesMemo.Lines.AddStrings(LBoard.LegalMoves);
  finally
    FLegalMovesMemo.Lines.EndUpdate;
  end;
end;

procedure TMainForm.UpdateGameLogMemo;
var
  I: Integer;
  LCanAppend: Boolean;
  LChanged: Boolean;
  LGame: TRunningGame;
  LGameId: Integer;
  LShowStdout: Boolean;
begin
  if FGameLogMemo = nil then
    Exit;

  LGame := SelectedGame;
  if LGame <> nil then
  begin
    LGameId := LGame.Id;
    LShowStdout := LGame.ShowStdout;
  end
  else
  begin
    LGameId := -1;
    LShowStdout := False;
  end;

  LCanAppend := (FGameLogMemoGameId = LGameId) and
    (FGameLogMemoShowStdout = LShowStdout) and
    (FGameLogMemoLineCount >= 0) and
    (FGameLogMemoLineCount <= FGameLog.Count) and
    (FGameLogMemo.Lines.Count = FGameLogMemoLineCount);
  LChanged := (not LCanAppend) or (FGameLogMemoLineCount < FGameLog.Count);

  if not LChanged then
    Exit;

  FGameLogMemo.Lines.BeginUpdate;
  try
    if LCanAppend then
    begin
      for I := FGameLogMemoLineCount to FGameLog.Count - 1 do
        FGameLogMemo.Lines.Add(FGameLog[I]);
    end
    else
      FGameLogMemo.Lines.Assign(FGameLog);
  finally
    FGameLogMemo.Lines.EndUpdate;
  end;

  FGameLogMemoGameId := LGameId;
  FGameLogMemoShowStdout := LShowStdout;
  FGameLogMemoLineCount := FGameLog.Count;

  if FGameLogMemo.Lines.Count > 0 then
    FGameLogMemo.SelStart := Length(FGameLogMemo.Text);
end;

procedure TMainForm.UpdateMiniBoardFromBoard(ABoard: TDraughtsBoard);
begin
  if (FMiniBoard = nil) or (ABoard = nil) then
    Exit;

  FMiniBoard.AssignFrom(ABoard);
  if FMiniBoardControl <> nil then
    FMiniBoardControl.Invalidate;

  if (FMiniBoardForm <> nil) and FMiniBoardForm.Visible and
    (FPopoutBoard <> nil) then
  begin
    FPopoutBoard.AssignFrom(FMiniBoard);
    if FPopoutBoardControl <> nil then
      FPopoutBoardControl.Invalidate;
  end;
end;

end.
