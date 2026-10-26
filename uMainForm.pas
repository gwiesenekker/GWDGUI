unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, Clipbrd, ComCtrls, Controls, Dialogs, ExtCtrls, Forms, Graphics,
  LCLType, Grids, Menus, StdCtrls, SysUtils, Types, uBoardControl,
  uDraughtsBoard, uMoveInteraction, uEnginesDialog,
  uGameOrchestrator, uGameRunnerThread, uRunningGame, uGameSetupForm, uGameSetupTypes,
  uEngineParamsJson, uEngineRegistry, uPdn, uPdnOpenDialog, uThreadMessageQueue, uGameGuiMessages,
  uTournamentDialog, uPvBrowser, uPvSnapshot, uAnalyzerRunnerThread,
  uGuiDialogs, uDatabaseForm, uGameTree, uGameTreeActor, uGameTreeBuilder,
  uGameTreePdn, uNotationPresentation, uDisplayedPosition, uGameTreeSearchRef, uGameTreeView, uPositionSetupForm,
  uPreferences, uPreferencesForm, uScoreHistoryControl, uScoreHistoryForm, uGameMoveHistory;

type
  TPvHintSource = (phsMain, phsAnalyzer);

  TDisplayedBoardInfo = record
    WhiteName: string;
    BlackName: string;
    ResultText: string;
    StartingFEN: string;
  end;

  TMainForm = class(TForm)
  private
    FAnalyzerCloseMenuItem: TMenuItem;
    FAnalyzerEngineKey: string;
    FAnalyzerLastPositionSignature: string;
    FAnnotatorSecondsEdit: TEdit;
    FAnalyzerMiniBoard: TDraughtsBoard;
    FAnalyzerMiniBoardControl: TDraughtsBoardControl;
    FAnalyzerMiniBoardForm: TForm;
    FAnalyzerMemo: TMemo;
    FAnalyzerOpenMenuItem: TMenuItem;
    FAnalyzerPopoutBoard: TDraughtsBoard;
    FAnalyzerPopoutBoardControl: TDraughtsBoardControl;
    FAnalyzerPopup: TPopupMenu;
    FAnalyzerPvBaseBoard: TDraughtsBoard;
    FAnalyzerPvBaseNodeId: Int64;
    FAnalyzerPvBasePly: Integer;
    FAnalyzerPvBrowser: TPvBrowser;
    FAnalyzerPvMemo: TMemo;
    FAnalyzerRunner: TAnalyzerRunnerThread;
    FAnalyzerSearch: TGameTreeSearchRef;
    FAutoPlayActive: Boolean;
    FAutoPlayBasePly: Integer;
    FAutoPlayButton: TButton;
    FAutoPlayMoveCount: Integer;
    FAutoPlayMovesText: string;
    FAutoPlayNodeId: Int64;
    FAutoPlaySearch: TGameTreeSearchRef;
    FAutoPlayTreeId: Int64;
    FBoard: TDraughtsBoard;
    FBoardControl: TDraughtsBoardControl;
    FBoardFlipped: Boolean;
    FBlackClockLabel: TLabel;
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
    FDisplayedPosition: TDisplayedPosition;
    FGameResult: string;
    FGames: TList;
    FGamesListBox: TListBox;
    FGameState: TGameOrchestratorState;
    FGuiEventQueue: TThreadMessageQueue;
    FGuiEventTimer: TTimer;
    FBlackPlayerEdit: TEdit;
    FFenEdit: TEdit;
    FGameMoveMemo: TMemo;
    FGameTree: TGameTree;
    FGameTreeActor: TGameTreeActor;
    FGameTreeBrowseMode: Boolean;
    FGameTreeForm: TForm;
    FGameTreeView: TTreeView;
    FGameTreeViewTreeId: Int64;
    FDisplayedAnnotationsSignature: string;
    FDisplayedMovesSignature: string;
    FNotation: TNotationPresentation;
    FDisplayedScoreHistorySignature: string;
    FDisplayedRunningSignature: string;
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
    FMoveInteraction: TMoveInteraction;
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
    FPopoutBoard: TDraughtsBoard;
    FPopoutBoardControl: TDraughtsBoardControl;
    FPositionSetupForm: TPositionSetupForm;
    FPreferences: TGuiPreferences;
    FPreferencesForm: TPreferencesForm;
    FPrincipalVariation: string;
    FPrincipalVariationDepth: string;
    FPrincipalVariationScore: string;
    FPrincipalVariationTimeText: string;
    FPvBasePositionKey: string;
    FPvBasePly: Integer;
    FTreePvBaseBoard: TDraughtsBoard;
    FPvInfoLabel: TLabel;
    FPvBrowser: TPvBrowser;
    FPvMemo: TMemo;
    FPdnOpenDialog: TPdnOpenDialog;
    FReplayGameMenuItem: TMenuItem;
    FRemoveGameMenuItem: TMenuItem;
    FResultEdit: TEdit;
    FScoreHistoryControl: TScoreHistoryControl;
    FScoreHistoryForm: TScoreHistoryForm;
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

    FDisplayBoardFailed: Boolean;
    FWhiteClockLabel: TLabel;
    FWhitePlayerEdit: TEdit;
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
    procedure AutoPlayClick(Sender: TObject);
    function AutoPlaySearchMatches(const ASearch: TGameTreeSearchRef): Boolean;
    function AnnotatorSeconds: Double;
    procedure AnnotatorSecondsEditingDone(Sender: TObject);
    function RecordAnalyzerSnapshotInGameTree(ASnapshot: TPvSnapshot): TGameTree;
    function PublishAnalyzerSnapshotToGameTree(ASnapshot: TPvSnapshot
      ): TGameTree;
    function PublishRunnerSnapshotToGameTree(AGame: TRunningGame;
      ASnapshot: TGameRunnerSnapshot): TGameTree;
    procedure ApplyAnnotatorVariationBrowsePly(ABasePly, AVariationPly: Integer;
      const AMovesText: string; AGameTree: TGameTree);
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
      out AErrorText: string): Boolean;
    function SetGameTreeHeader(AActor: TGameTreeActor;
      const AHeader: TGameTreeHeaderInput; out AErrorText: string): Boolean;
    function ExecuteGameTreeCommand(AActor: TGameTreeActor;
      ACommand: TGameTreeCommand; out AErrorText: string): Boolean;
    function ExecuteAndApplyGameTreeCommand(AActor: TGameTreeActor;
      AGameTree: TGameTree; ACommand: TGameTreeCommand;
      AFollowVariationBrowse: Boolean; out AErrorText: string): Boolean;
    procedure HandleQueuedGameTreeCommandResult(ACommand: TGameTreeCommand);
    function ProcessQueuedGameTreeCommands: Integer;
    function TryStartGameTreeSearchForDisplayedNode(AGameTree: TGameTree;
      out ASearch: TGameTreeSearchRef; out AErrorText: string): Boolean;
    function AnalyzerSearchMatches(const ASearch: TGameTreeSearchRef): Boolean;
    function AnalyzerSnapshotIsTransient(ASnapshot: TPvSnapshot): Boolean;
    function AcceptSearchMove(AActor: TGameTreeActor;
      const ASearch: TGameTreeSearchRef; const AMoveText: string;
      out AErrorText: string): Boolean;
    function CancelGameTreeSearch(AActor: TGameTreeActor;
      const ASearch: TGameTreeSearchRef): Boolean;
    function ReleaseGameTreeSearch(AActor: TGameTreeActor;
      const ASearch: TGameTreeSearchRef): Boolean;
    function ReleaseRejectedSearchIfFinished(AActor: TGameTreeActor;
      const ASearch: TGameTreeSearchRef): Boolean;
    function StoreMoveVariation(AActor: TGameTreeActor; AGameTree: TGameTree;
      ANodeId: Int64; const AMove: string; ASource: TGameTreeMoveSource;
      out AErrorText: string): Boolean;
    function RecordEnginePvInGameTree(AActor: TGameTreeActor;
      AGameTree: TGameTree; ANodeId: Int64; const AScore,
      APrincipalVariation, ADepth, ATimeText: string;
      out AErrorText: string): Boolean;
    function RecordAnnotatorPvInGameTree(AActor: TGameTreeActor;
      AGameTree: TGameTree; ANodeId: Int64; const AScore,
      APrincipalVariation, ADepth, ATimeText: string;
      out AErrorText: string): Boolean;
    function ClearGameTreeBranches(AActor: TGameTreeActor): Boolean;
    function TryResolveActiveSearchSnapshot(ASnapshot: TPvSnapshot;
      out AActor: TGameTreeActor; out AGameTree: TGameTree;
      out ANode: TGameTreePlyNode): Boolean;
    function TryResolveAnalyzerSnapshotNode(AGameTree: TGameTree;
      ASnapshot: TPvSnapshot; out ANode: TGameTreePlyNode): Boolean;
    function TryResolveRunningSnapshotPvNode(AGameTree: TGameTree;
      const AInput: TRunningSnapshotTreeInput;
      out ANode: TGameTreePlyNode): Boolean;
    procedure TrackAnalyzerSearch(const ASearch: TGameTreeSearchRef);
    procedure ClearAnalyzerSearchTracking;
    procedure SetAnalyzerPvBase(ABoard: TDraughtsBoard; APly: Integer);
    procedure SetAnalyzerPvBaseFromTree(AGameTree: TGameTree; ANodeId: Int64;
      AFallbackBasePly: Integer; AFallbackBoard: TDraughtsBoard);
    procedure InvalidateAnalyzerPositionSignature;
    procedure InvalidateMctsPositionSignature;
    procedure ApplyGameTreeCommandResult(AGameTree: TGameTree;
      ACommand: TGameTreeCommand; AFollowVariationBrowse: Boolean);
    function RebuildStandaloneGameTreeFromImport(AGameTree: TGameTree;
      const AEventName, AWhiteName, ABlackName, AResultText, AStartingFEN,
      AMovesText, AAnnotationsText: string;
      const AInitialCommentText: string = ''): Boolean;
    function CurrentGameTreeHeaderInput(AGame: TRunningGame;
      AGameTree: TGameTree): TGameTreeHeaderInput;
    function RunningSnapshotTreeInput(AGame: TRunningGame;
      ASnapshot: TGameRunnerSnapshot;
      const AEventName: string): TRunningSnapshotTreeInput;
    function RunningSnapshotHeaderInput(
      const AInput: TRunningSnapshotTreeInput): TGameTreeHeaderInput;
    function RunningSnapshotMainlineInput(
      const AInput: TRunningSnapshotTreeInput; AMoves, AAnnotations: TStrings;
      ARecordClock: Boolean): TGameTreeMainlineInput;
    function RunningSnapshotPvInput(const AInput: TRunningSnapshotTreeInput;
      ARecordPV: Boolean): TGameTreePvInput;
    function RunningSnapshotSyncSignature(
      const AInput: TRunningSnapshotTreeInput): string;
    function RunningDisplaySignature(AGame: TRunningGame;
      ALogLineCount: Integer): string;
    procedure InitializeRunningGameTree(AGame: TRunningGame);
    procedure UpdateRunningGameTreeFromSnapshot(AGame: TRunningGame;
      ASnapshot: TGameRunnerSnapshot = nil;
      const AEventName: string = '');
    function RunningGameTreePdnText(AGame: TRunningGame;
      const AEventName: string): string;
    function CanExploreVariation: Boolean;
    function CanAcceptHumanBoardMove: Boolean;
    function HasLegalDisplayedMove: Boolean;
    function GetBrowseBasePly: Integer;
    function GetBrowsingBranch: Boolean;
    function GetBrowseVariationPly: Integer;
    property BrowseBasePly: Integer read GetBrowseBasePly;
    property BrowsingBranch: Boolean read GetBrowsingBranch;
    property BrowseVariationPly: Integer read GetBrowseVariationPly;
    procedure ClearHumanMoveSelection;
    procedure ClearTreeBranches(AGameTree: TGameTree);
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
    function DisplayedPositionSignature(AGameTree: TGameTree; ANodeId: Int64;
      const AStartingFEN, AMovesText: string;
      AGameState: TGameOrchestratorState): string;
    function DisplayedPositionIsTerminal(ADisplayedMoveCount,
      ATotalMoveCount: Integer; AGameState: TGameOrchestratorState): Boolean;
    function HasDisplayedGameToSave: Boolean;
    function ConfirmReplaceStandaloneGame: Boolean;
    procedure ShowStandaloneGame(Sender: TObject);
    function EngineSupportsMcts(AEngine: TExternalEngineDefinition): Boolean;
    function GameForTree(AGameTree: TGameTree): TRunningGame;
    function ActorForGameTree(AGameTree: TGameTree): TGameTreeActor;
    function ActorForGameTreeId(AGameTreeId: Int64): TGameTreeActor;
    function ActorForSearchRef(
      const ASearch: TGameTreeSearchRef): TGameTreeActor;
    function BlackNameForTree(AGameTree: TGameTree): string;
    function EventNameForTree(AGameTree: TGameTree): string;
    function ResultForTree(AGameTree: TGameTree): string;
    function RunningGameTreeExtendsSnapshot(AGame: TRunningGame;
      const AInput: TRunningSnapshotTreeInput): Boolean;
    function StartingFenForTree(AGameTree: TGameTree): string;
    function StateForTree(AGameTree: TGameTree): TGameOrchestratorState;
    function WhiteNameForTree(AGameTree: TGameTree): string;
    function ClockValuesForTree(AGameTree: TGameTree;
      out AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
      ABlackUsedSeconds: Double): Boolean;
    function EnginePvForTree(AGameTree: TGameTree; APly: Integer;
      out APV, AScore, ADepth, ATimeText: string): Boolean;
    function AnnotatorPvForTreeNode(AGameTree: TGameTree; ANodeId: Int64;
      out APV, AScore, ADepth, ATimeText: string): Boolean;
    function LatestEnginePvForTree(AGameTree: TGameTree; out ABasePly: Integer;
      out APV, AScore, ADepth, ATimeText: string): Boolean;
    function TryBuildTreeBoardAtPly(AGameTree: TGameTree; APly: Integer;
      ABoard: TDraughtsBoard): Boolean;
    function TryBuildTreeBoardAtNode(AGameTree: TGameTree;
      ANode: TGameTreePlyNode; ABoard: TDraughtsBoard): Boolean;
    function TryBuildDisplayedBoard(AGameTree: TGameTree;
      ABoard: TDraughtsBoard): Boolean;
    function VisibleMainPvForTree(AGameTree: TGameTree;
      out ABaseBoard: TDraughtsBoard; out ABasePly: Integer; out APV,
      AScore, ADepth, ATimeText: string): Boolean;
    procedure RefreshMainPvBrowserFromTree(AGameTree: TGameTree;
      const AStartingFEN: string = '');
    procedure RefreshAnalyzerPvBrowserFromTree(AGameTree: TGameTree;
      ANodeId: Int64; AFallbackBasePly: Integer);
    procedure SetDisplayedTreeTracking(const AAnnotationsSignature,
      AMovesSignature, ARunningSignature: string; AGameTreeId,
      AGameTreeRevision: Int64);
    function DisplayedPvCacheMatches(const APV, AScore, ADepth,
      ATimeText, ABasePositionKey: string; ABasePly: Integer): Boolean;
    procedure SetDisplayedPvCache(const APV, AScore, ADepth,
      ATimeText: string; ABaseBoard: TDraughtsBoard; ABasePly: Integer);
    function UpdateDisplayedPvCacheFromTree(AGameTree: TGameTree): Boolean;
    procedure ClearDisplayedPvCache(ABaseBoard: TDraughtsBoard;
      ABasePly: Integer);
    function FormatClock(ASeconds: Double): string;
    function CurrentFilteredGameTreePdnOptions: TGameTreePdnRenderOptions;
    function GameLogLineVisible(const ALine: string; AGame: TRunningGame): Boolean;
    function GameTitleEngineName(AEngine: TExternalEngineDefinition): string;
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
    procedure PasteFenClick(Sender: TObject);
    procedure PdnGameSelected(Sender: TObject; AGame: TPdnGame);
    function PlayerNameOrFallback(const AName, AFallback: string): string;
    function PostGuiEvent(AEvent: TObject): Boolean;
    procedure PreferencesAccepted(Sender: TObject;
      const APreferences: TGuiPreferences);
    procedure PreferencesClick(Sender: TObject);
    procedure PlayHumanMove(const AMove: string;
      ASource: TGameTreeMoveSource = gmsHuman);
    procedure RemoveSelectedGame(Sender: TObject);
    procedure RestartAnalyzer(AGameTree: TGameTree);
    procedure RestartMctsAnnotator(AGameTree: TGameTree);
    procedure ReplaySelectedGame(Sender: TObject);
    procedure SelectHumanMoveSource(ASourceSquare: Integer);
    procedure RebuildGameMoveLabels(AGameTree: TGameTree);
    procedure UpdateGameMoveHighlight;
    procedure UpdateAutoPlayButtonState;
    procedure StartAutoPlay;
    procedure StartNextAutoPlaySearch;
    procedure StopAutoPlay(const AReason: string = '');
    function StoreAutoPlayMove(const AMoveText: string;
      out AErrorText: string): Boolean;
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
    procedure TournamentSelectGame(Sender: TObject; AGame: TObject);
    procedure TournamentStartGame(Sender: TObject; const ASetup: TGameSetup;
      const ATitlePrefix: string; out AGame: TObject);
    procedure ImportPdnTree(AGameTree: TGameTree; AGame: TPdnGame);
    procedure UpdateBoardInfo;
    procedure RefreshDisplayFromGameTree(AGameTree: TGameTree;
      AForceViews: Boolean);
    procedure UpdateDatabaseSearchPositionFromTree(AGameTree: TGameTree);
    function TryGetDisplayedBoardFen(AGameTree: TGameTree;
      out AFen: string): Boolean;
    procedure UpdateBoardFromBrowseState(AGameTree: TGameTree);
    procedure UpdateBoardHighlights(AGameTree: TGameTree);
    function DisplayedBoardInfo(AGameTree: TGameTree;
      AGame: TRunningGame): TDisplayedBoardInfo;
    procedure UpdateClockLabels(AGameTree: TGameTree; const AWhiteName,
      ABlackName: string);
    procedure UpdateScoreHistory(AGameTree: TGameTree);
    procedure UpdateGameListItem(AGame: TRunningGame);
    procedure UpdateLegalMovesFromTree(AGameTree: TGameTree);
    procedure UpdateGameLogMemo;
    procedure RefreshVisibleGameTreeView(AGameTree: TGameTree);
    procedure RefreshDisplayedGameTreeViews(AGameTree: TGameTree;
      AForce: Boolean);
    procedure UpdateGameTreeView(AGameTree: TGameTree);
    procedure SyncGameTreeViewSelection;
    procedure UpdateMctsStatsFromLog(const AMessage: string);
    procedure TournamentClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    {$IFDEF GWDGUI_NONINTERACTIVE_TEST}
    function GetLastDisplayReplayCount: Integer;
    property LastDisplayReplayCount: Integer read GetLastDisplayReplayCount;
    {$ENDIF}
    function ActiveGameTree: TGameTree;
    function CurrentGameTreePdnText(const AEventName: string): string;
    procedure LoadStandaloneFen(const AFEN: string);
    procedure LoadPdnGameToDisplay(AGame: TPdnGame);
    procedure RemoveGame(AGame: TRunningGame);
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
  LAnnotatorSecondsPanel: TPanel;
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
  FTreePvBaseBoard := TDraughtsBoard.Create;
  FStartingFEN := FBoard.StartingFEN;
  FGameState := gosWaiting;
  FGameResult := '*';
  FDisplayedPosition := TDisplayedPosition.Create;
  FNotation := TNotationPresentation.Create;
  FGameTreeBrowseMode := False;
  FAutoPlaySearch := EmptyGameTreeSearchRef;
  FGameLogSourceGameId := -1;
  FGameLogSourceLineCount := -1;
  FGameLogSourceShowStdout := False;
  FGameLogMemoGameId := -1;
  FGameLogMemoLineCount := -1;
  SetDisplayedTreeTracking('', '', '', 0, -1);
  FHighlightedGameMovePly := -1;
  FHideMoveAnnotations := False;
  FMoveShowEnginePVMove := False;
  FMoveShowEngineFullPV := False;
  FMoveShowAnnotatorPVMove := False;
  FMoveShowAnnotatorFullPV := False;
  FMoveShowAnnotatorScore := True;
  FMoveShowClocks := False;
  FMoveShowEngineScore := True;
  FSearchPositionInDatabase := True;
  FPvHintSource := phsMain;
  FViewedGameId := -1;
  FGameLog := TStringList.Create;
  FMoveInteraction := TMoveInteraction.Create;
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

  FAutoPlayButton := TButton.Create(Self);
  FAutoPlayButton.Parent := LToolbar;
  FAutoPlayButton.Align := alLeft;
  FAutoPlayButton.Width := 96;
  FAutoPlayButton.BorderSpacing.Left := 8;
  FAutoPlayButton.Caption := 'Auto Play';
  FAutoPlayButton.Enabled := False;
  FAutoPlayButton.OnClick := @AutoPlayClick;

  LAnnotatorSecondsPanel := TPanel.Create(Self);
  LAnnotatorSecondsPanel.Parent := LToolbar;
  LAnnotatorSecondsPanel.Align := alLeft;
  LAnnotatorSecondsPanel.Width := 68;
  LAnnotatorSecondsPanel.BevelOuter := bvNone;

  FAnnotatorSecondsEdit := TEdit.Create(Self);
  FAnnotatorSecondsEdit.Parent := LAnnotatorSecondsPanel;
  FAnnotatorSecondsEdit.SetBounds(8, 7, 52, 27);
  FAnnotatorSecondsEdit.Text := '1';
  FAnnotatorSecondsEdit.Hint := 'Annotator seconds';
  FAnnotatorSecondsEdit.ShowHint := True;
  FAnnotatorSecondsEdit.OnEditingDone := @AnnotatorSecondsEditingDone;

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
  FGamesListBox.Name := 'GameHistoryList';
  FGamesListBox.Parent := LGamesPanel;
  FGamesListBox.SetBounds(0, 24, LGamesPanel.ClientWidth, LGamesPanel.ClientHeight - 24);
  FGamesListBox.Anchors := [akTop, akLeft, akRight, akBottom];
  FGamesListBox.OnClick := @GamesListBoxClick;
  FGamesListBox.Items.Add('Board (PDN / FEN)');
  FGamesListBox.ItemIndex := 0;

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
  FGameMoveMemo.Name := 'GameMoveMemo';
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
  FShowGameTreeMenuItem.Caption := 'Show game tree';
  FShowGameTreeMenuItem.Name := 'ShowGameTree';
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
  FMiniBoardControl.Name := 'EnginePvBoard';
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
  FScoreHistoryControl.DisplayMode := shdmGraph;
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
  FPvMemo.Name := 'EnginePvMemo';
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
  FBoardControl.Name := 'MainBoard';
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
  RefreshDisplayFromGameTree(FGameTree, True);
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
  FNotation.Free;
  FDisplayedPosition.Free;
  FMoveInteraction.Free;
  FGameTreeActor.Free;
  FGameTree.Free;
  FGameLog.Free;
  FGames.Free;
  FAnalyzerPopoutBoard.Free;
  FAnalyzerPvBaseBoard.Free;
  FAnalyzerMiniBoard.Free;
  FPopoutBoard.Free;
  FMiniBoard.Free;
  FTreePvBaseBoard.Free;
  FBoard.Free;
  inherited Destroy;
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
  LState: TGameOrchestratorState;
begin
  if BrowseBasePly >= 0 then
    Exit(False);

  LGame := SelectedDisplayedGame;
  if LGame = nil then
    Exit(False);

  LState := LGame.State;
  Result := (LGame.Runner <> nil) and
    (not LGame.IsStopOrRemoveRequested) and
    ((LState = gosRunning) or (LGame.Lifecycle = rglStarting)) and
    LGame.IsHumanToMove;
end;

function TMainForm.HasLegalDisplayedMove: Boolean;
var
  LBoard: TDraughtsBoard;
  LGameTree: TGameTree;
begin
  Result := False;
  LGameTree := ActiveGameTree;
  LBoard := TDraughtsBoard.Create;
  try
    Result := TryBuildDisplayedBoard(LGameTree, LBoard) and
      (LBoard.LegalMoveCount > 0);
  finally
    LBoard.Free;
  end;
end;

function TMainForm.CanExploreVariation: Boolean;
var
  LGame: TRunningGame;
begin
  Result := False;
  if Trim(FDisplayedPosition.PreviewMoves) <> '' then
    Exit;

  LGame := SelectedDisplayedGame;
  if LGame <> nil then
  begin
    Result := LGame.CanEditGameTree;
  end
  else
    Result := Trim(StartingFenForTree(ActiveGameTree)) <> '';
end;

procedure TMainForm.ClearHumanMoveSelection;
begin
  FMoveInteraction.Clear;
  if FBoardControl <> nil then
    FBoardControl.ClearTargetSquares;
end;

procedure TMainForm.ClearVariationExploration;
begin
  FDisplayedPosition.ClearPreview;
end;

procedure TMainForm.ToggleBoardFlipped;
begin
  FBoardFlipped := not FBoardFlipped;
  ClearHumanMoveSelection;
  ApplyBoardFlipped;
  if FGameActive then
    UpdateClockLabels(ActiveGameTree, FWhitePlayerEdit.Text,
      FBlackPlayerEdit.Text);
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
  const AEnginePV, AAnnotatorPV: TGameTreePvInput;
  out AErrorText: string): Boolean;
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
    AEnginePV, AAnnotatorPV);
  try
    Result := ExecuteAndApplyGameTreeCommand(AActor, AActor.GameTree,
      Command, False, AErrorText);
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
    Result := ExecuteAndApplyGameTreeCommand(AActor, AActor.GameTree,
      Command, False, AErrorText);
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
begin
  Result := ExecuteGameTreeCommand(AActor, ACommand, AErrorText);
  if not Result then
    Exit;
  if AFollowVariationBrowse or ACommand.TreeChanged then
    ApplyGameTreeCommandResult(AGameTree, ACommand, AFollowVariationBrowse);
end;

procedure TMainForm.HandleQueuedGameTreeCommandResult(ACommand: TGameTreeCommand);
var
  Actor: TGameTreeActor;
  FollowVariationBrowse: Boolean;
begin
  if (ACommand = nil) or (not ACommand.Accepted) then
    Exit;

  Actor := ActorForGameTreeId(ACommand.GameTreeId);
  if (Actor = nil) or (Actor.GameTree = nil) then
    Exit;

  FollowVariationBrowse := ACommand.CommandKind = gtcStoreMoveVariation;
  if FollowVariationBrowse or ACommand.TreeChanged then
    ApplyGameTreeCommandResult(Actor.GameTree, ACommand, FollowVariationBrowse);
end;

function TMainForm.ProcessQueuedGameTreeCommands: Integer;
var
  I: Integer;
  LGame: TRunningGame;
begin
  Result := 0;
  if FClosing then
    Exit;

  if FGameTreeActor <> nil then
    Inc(Result, FGameTreeActor.ProcessCommands(@HandleQueuedGameTreeCommandResult));

  for I := 0 to FGames.Count - 1 do
  begin
    LGame := TRunningGame(FGames[I]);
    if (LGame <> nil) and (LGame.GameTreeActor <> nil) then
      Inc(Result, LGame.GameTreeActor.ProcessCommands(
        @HandleQueuedGameTreeCommandResult));
  end;
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

function TMainForm.AnalyzerSnapshotIsTransient(
  ASnapshot: TPvSnapshot): Boolean;
begin
  Result := (ASnapshot <> nil) and ASnapshot.Transient;
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
begin
  Result := False;
  if (AActor = nil) or (not IsValidGameTreeSearchRef(ASearch)) then
    Exit;

  Command := AActor.CreateReleaseSearchCommand(ASearch);
  try
    Result := AActor.PostCommand(Command);
    Command := nil;
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
  APrincipalVariation, ADepth, ATimeText: string; out AErrorText: string
  ): Boolean;
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
    APrincipalVariation, ADepth, ATimeText);
  try
    Result := ExecuteAndApplyGameTreeCommand(AActor, AGameTree, Command,
      False, AErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.RecordEnginePvInGameTree(AActor: TGameTreeActor;
  AGameTree: TGameTree; ANodeId: Int64; const AScore,
  APrincipalVariation, ADepth, ATimeText: string; out AErrorText: string
  ): Boolean;
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
    APrincipalVariation, ADepth, ATimeText);
  try
    Result := ExecuteAndApplyGameTreeCommand(AActor, AGameTree, Command,
      False, AErrorText);
  finally
    Command.Free;
  end;
end;

function TMainForm.ClearGameTreeBranches(AActor: TGameTreeActor): Boolean;
var
  Command: TGameTreeCommand;
  LErrorText: string;
begin
  Result := False;
  if AActor = nil then
    Exit;

  Command := AActor.CreateClearBranchesCommand;
  try
    Result := ExecuteAndApplyGameTreeCommand(AActor, AActor.GameTree, Command,
      False, LErrorText);
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

function TMainForm.TryResolveAnalyzerSnapshotNode(AGameTree: TGameTree;
  ASnapshot: TPvSnapshot; out ANode: TGameTreePlyNode): Boolean;
var
  LSearch: TGameTreeSearchRef;
begin
  Result := False;
  ANode := nil;
  if (AGameTree = nil) or (ASnapshot = nil) then
    Exit;

  LSearch := ASnapshot.SearchRef;
  if IsValidGameTreeSearchRef(LSearch) and
    (LSearch.GameTreeId = AGameTree.GameTreeId) and (LSearch.NodeId > 0) then
    ANode := AGameTree.FindNodeById(LSearch.NodeId);

  if ANode = nil then
  begin
    if ASnapshot.BasePly <= 0 then
      ANode := AGameTree.Root
    else
      ANode := AGameTree.MainlineNode[ASnapshot.BasePly];
  end;

  Result := ANode <> nil;
end;

function TMainForm.TryResolveRunningSnapshotPvNode(AGameTree: TGameTree;
  const AInput: TRunningSnapshotTreeInput;
  out ANode: TGameTreePlyNode): Boolean;
begin
  Result := False;
  ANode := nil;
  if AGameTree = nil then
    Exit;

  if AInput.PvBasePly <= 0 then
    ANode := AGameTree.Root
  else
    ANode := AGameTree.MainlineNode[AInput.PvBasePly];

  Result := ANode <> nil;
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
  FAnalyzerPvBaseNodeId := 0;
  FAnalyzerPvBasePly := APly;
end;

procedure TMainForm.SetAnalyzerPvBaseFromTree(AGameTree: TGameTree;
  ANodeId: Int64; AFallbackBasePly: Integer; AFallbackBoard: TDraughtsBoard);
var
  LNode: TGameTreePlyNode;
begin
  LNode := nil;
  if (AGameTree <> nil) and (ANodeId > 0) then
    LNode := AGameTree.FindNodeById(ANodeId);

  if (LNode <> nil) and
    TryBuildTreeBoardAtNode(AGameTree, LNode, FAnalyzerPvBaseBoard) then
  begin
    FAnalyzerPvBaseNodeId := LNode.NodeId;
    FAnalyzerPvBasePly := LNode.PlyNumber;
    Exit;
  end;

  if (AGameTree <> nil) and (AFallbackBasePly >= 0) and
    TryBuildTreeBoardAtPly(AGameTree, AFallbackBasePly, FAnalyzerPvBaseBoard) then
  begin
    FAnalyzerPvBaseNodeId := 0;
    FAnalyzerPvBasePly := AFallbackBasePly;
    Exit;
  end;

  SetAnalyzerPvBase(AFallbackBoard, AFallbackBasePly);
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
var
  LActiveGameTree: TGameTree;
begin
  if (AGameTree = nil) or (ACommand = nil) or (not ACommand.Accepted) then
    Exit;

  LActiveGameTree := ActiveGameTree;
  if AFollowVariationBrowse and (AGameTree = LActiveGameTree) and
    (ACommand.CommandKind = gtcStoreMoveVariation) then
  begin
    ClearVariationExploration;
    FDisplayedPosition.Cursor.Select(AGameTree, AGameTree.FindNodeById(ACommand.CreatedNodeId));
  end;

  RefreshDisplayFromGameTree(AGameTree, True);
end;

function TMainForm.RebuildStandaloneGameTreeFromImport(AGameTree: TGameTree;
  const AEventName, AWhiteName, ABlackName, AResultText, AStartingFEN,
  AMovesText, AAnnotationsText: string;
  const AInitialCommentText: string): Boolean;
var
  Actor: TGameTreeActor;
  LAnnotations: TStringList;
  LErrorText: string;
  LHeader: TGameTreeHeaderInput;
  LMoves: TStringList;
begin
  Result := False;
  Actor := ActorForGameTree(AGameTree);
  if Actor = nil then
    Exit;

  LMoves := TStringList.Create;
  LAnnotations := TStringList.Create;
  try
    TextToMoveList(AMovesText, LMoves);
    LAnnotations.Text := AAnnotationsText;
    LHeader := GameTreeHeaderInput(
      'standalone:' + AStartingFEN + '|' + AEventName + '|' +
      AWhiteName + '|' + ABlackName + '|moves=' + AMovesText,
      PlayerNameOrFallback(AEventName, '?'),
      PlayerNameOrFallback(AWhiteName, 'White'),
      PlayerNameOrFallback(ABlackName, 'Black'),
      PlayerNameOrFallback(AResultText, '*'),
      AStartingFEN, False, DefaultTimeControl, gosWaiting, '', AInitialCommentText);
    Result := RebuildGameTreeFromInputs(Actor, LHeader,
      GameTreeMainlineInput(LMoves, LAnnotations, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', ''),
      LErrorText);
  finally
    LAnnotations.Free;
    LMoves.Free;
  end;
end;

function TMainForm.FindHumanMoveToTarget(ATargetSquare: Integer;
  out AMove: string): Boolean;
begin
  Result := FMoveInteraction.FindTarget(ATargetSquare, AMove);
end;

procedure TMainForm.PlayHumanMove(const AMove: string;
  ASource: TGameTreeMoveSource);
var
  Board: TDraughtsBoard;
  Game: TRunningGame;
  Tree: TGameTree;
  Move: string;
  Node: TGameTreePlyNode;
  State: TGameOrchestratorState;
  Route: TMoveRoute;
  RunnerHumanTurn: Boolean;
begin
  Tree := ActiveGameTree;
  if Tree = nil then Exit;
  Game := SelectedDisplayedGame;
  if (Game <> nil) and Game.IsStopOrRemoveRequested then Exit;
  if Game <> nil then State := Game.State else State := StateForTree(Tree);
  RunnerHumanTurn := (Game <> nil) and (Game.Runner <> nil) and
    ((State = gosRunning) or (Game.Lifecycle = rglStarting)) and Game.IsHumanToMove;
  Board := TDraughtsBoard.Create;
  try
    if not TryBuildDisplayedBoard(Tree, Board) then Exit;
    Route := RouteMove(Board, Tree, CurrentDisplayedGameTreeNode(Tree), AMove,
      CanExploreVariation, BrowsingBranch,
      (ResultForTree(Tree) = '*') and (State <> gosGameOver), RunnerHumanTurn, Move);
  finally
    Board.Free;
  end;
  if Route = mrInvalid then Exit;
  ClearHumanMoveSelection;
  case Route of
    mrMainline:
      begin
        Node := ExecuteGameTreeAppendMainlineMove(Tree, Move, ASource);
        if Node = nil then Exit;
        ClearVariationExploration;
        FDisplayedPosition.Cursor.Follow;
        RefreshDisplayFromGameTree(Tree, True);
      end;
    mrVariation: AddVariationMove(Move, ASource);
    mrRunner: Game.Runner.PostHumanMove(Move);
  end;
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
  if LMove = '' then
    Exit;

  LNode := CurrentDisplayedGameTreeNode(LGameTree);
  Actor := ActorForGameTree(LGameTree);
  if (LNode = nil) or (Actor = nil) then
    Exit;

  if not StoreMoveVariation(Actor, LGameTree, LNode.NodeId, LMove, ASource,
    LErrorText) then
    ShowGuiOkDialog(Self, 'Variation move', LErrorText);
end;

procedure TMainForm.SelectHumanMoveSource(ASourceSquare: Integer);
var
  Board: TDraughtsBoard;
  Move: string;
begin
  ClearHumanMoveSelection;
  if (not CanAcceptHumanBoardMove) and (not CanExploreVariation) then Exit;
  Board := TDraughtsBoard.Create;
  try
    if not TryBuildDisplayedBoard(ActiveGameTree, Board) then Exit;
    Move := FMoveInteraction.SelectSource(Board, ASourceSquare);
  finally
    Board.Free;
  end;
  if Move <> '' then PlayHumanMove(Move)
  else if FBoardControl <> nil then
    FBoardControl.SetTargetSquares(FMoveInteraction.Targets);
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

  if (FMoveInteraction.SourceSquare > 0) and FindHumanMoveToTarget(LSquare, LMove) then
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

function TMainForm.AnnotatorSeconds: Double;
var
  LText: string;
begin
  Result := 1;
  if FAnnotatorSecondsEdit = nil then
    Exit;

  LText := Trim(FAnnotatorSecondsEdit.Text);
  LText := StringReplace(LText, '.', DefaultFormatSettings.DecimalSeparator,
    [rfReplaceAll]);
  LText := StringReplace(LText, ',', DefaultFormatSettings.DecimalSeparator,
    [rfReplaceAll]);
  if (not TryStrToFloat(LText, Result)) or (Result <= 0) then
    Result := 1;
  FAnnotatorSecondsEdit.Text := FormatFloat('0.###', Result);
end;

procedure TMainForm.AnnotatorSecondsEditingDone(Sender: TObject);
begin
  AnnotatorSeconds;
  if FAnalyzerRunner = nil then
    Exit;
  InvalidateAnalyzerPositionSignature;
  RestartAnalyzer(ActiveGameTree);
end;

procedure TMainForm.AutoPlayClick(Sender: TObject);
begin
  if FAutoPlayActive then
    StopAutoPlay
  else
    StartAutoPlay;
end;

function TMainForm.AutoPlaySearchMatches(
  const ASearch: TGameTreeSearchRef): Boolean;
begin
  Result := FAutoPlayActive and IsValidGameTreeSearchRef(ASearch) and
    SameGameTreeSearchRef(FAutoPlaySearch, ASearch);
end;

procedure TMainForm.StartAutoPlay;
var
  LGameTree: TGameTree;
  LNode: TGameTreePlyNode;
begin
  LGameTree := ActiveGameTree;
  if (LGameTree = nil) or (StateForTree(LGameTree) <> gosStopped) then
    Exit;
  if FAnalyzerRunner = nil then
  begin
    ShowGuiOkDialog(Self, 'Auto Play', 'Open an annotator engine first.');
    Exit;
  end;
  if (Trim(FDisplayedPosition.PreviewMoves) <> '') or
    BrowsingBranch then
  begin
    ShowGuiOkDialog(Self, 'Auto Play',
      'Press Escape to leave variation browsing first.');
    Exit;
  end;

  LNode := CurrentDisplayedGameTreeNode(LGameTree);
  if LNode = nil then
    Exit;

  FAutoPlayBasePly := LNode.PlyNumber;
  FAutoPlayNodeId := LNode.NodeId;
  FAutoPlayMoveCount := 0;
  FAutoPlayMovesText := '';

  CancelAnalyzerSearch;
  FAutoPlayActive := True;
  FAutoPlayTreeId := LGameTree.GameTreeId;
  FAutoPlaySearch := EmptyGameTreeSearchRef;
  InvalidateAnalyzerPositionSignature;
  UpdateAutoPlayButtonState;
  StartNextAutoPlaySearch;
end;

procedure TMainForm.StopAutoPlay(const AReason: string);
var
  LActor: TGameTreeActor;
begin
  if not FAutoPlayActive then
    Exit;

  if IsValidGameTreeSearchRef(FAutoPlaySearch) then
  begin
    LActor := ActorForSearchRef(FAutoPlaySearch);
    if CancelGameTreeSearch(LActor, FAutoPlaySearch) then
      ReleaseGameTreeSearch(LActor, FAutoPlaySearch);
  end;
  if FAnalyzerRunner <> nil then
    FAnalyzerRunner.PostStopSearch;
  FAutoPlayActive := False;
  FAutoPlaySearch := EmptyGameTreeSearchRef;
  FAutoPlayTreeId := 0;
  FAutoPlayNodeId := 0;
  if (Trim(AReason) <> '') and (FAnalyzerMemo <> nil) then
    FAnalyzerMemo.Lines.Add('Auto Play stopped; reason=' + Trim(AReason));
  InvalidateAnalyzerPositionSignature;
  UpdateAutoPlayButtonState;
  RestartAnalyzer(ActiveGameTree);
end;

procedure TMainForm.StartNextAutoPlaySearch;
var
  LBoard: TDraughtsBoard;
  LErrorText: string;
  LGameTree: TGameTree;
  LMoveCount: Integer;
  LMovesText: string;
  LSearch: TGameTreeSearchRef;
begin
  if not FAutoPlayActive then
    Exit;
  LGameTree := ActiveGameTree;
  if (LGameTree = nil) or (LGameTree.GameTreeId <> FAutoPlayTreeId) or
    (StateForTree(LGameTree) <> gosStopped) then
  begin
    StopAutoPlay('game is no longer the active stopped game');
    Exit;
  end;

  LBoard := TDraughtsBoard.Create;
  try
    if not TryBuildDisplayedBoard(LGameTree, LBoard) then
    begin
      StopAutoPlay('position could not be built');
      Exit;
    end;
    if LBoard.LegalMoveCount = 0 then
    begin
      StopAutoPlay('no legal moves');
      Exit;
    end;
    if not DisplayedMoveContext(LGameTree, LMovesText, LMoveCount) then
    begin
      StopAutoPlay('move context could not be built');
      Exit;
    end;
    if not TryStartGameTreeSearchForDisplayedNode(LGameTree, LSearch,
      LErrorText) then
    begin
      StopAutoPlay(LErrorText);
      Exit;
    end;
    FAutoPlaySearch := LSearch;
    SetAnalyzerPvBase(LBoard, LMoveCount);
    FAnalyzerRunner.PostThinkOnce(StartingFenForTree(LGameTree), LMovesText,
      LBoard, LMoveCount, AnnotatorSeconds, LSearch, True);
  finally
    LBoard.Free;
  end;
end;

function TMainForm.StoreAutoPlayMove(const AMoveText: string;
  out AErrorText: string): Boolean;
var
  LActor: TGameTreeActor;
  LBoard: TDraughtsBoard;
  LCommand: TGameTreeCommand;
  LGameTree: TGameTree;
  LMove: string;
  LMovesText: string;
begin
  Result := False;
  AErrorText := '';
  LGameTree := ActiveGameTree;
  LActor := ActorForGameTree(LGameTree);
  if (LGameTree = nil) or (LActor = nil) or
    (LGameTree.GameTreeId <> FAutoPlayTreeId) then
  begin
    AErrorText := 'game tree is no longer active';
    Exit;
  end;

  LBoard := TDraughtsBoard.Create;
  try
    if not TryBuildDisplayedBoard(LGameTree, LBoard) or
      (not LBoard.TryGetLegalMove(AMoveText, LMove)) then
    begin
      AErrorText := 'engine returned an illegal move: ' + Trim(AMoveText);
      Exit;
    end;
  finally
    LBoard.Free;
  end;

  LMovesText := Trim(FAutoPlayMovesText);
  if LMovesText <> '' then
    LMovesText += ' ';
  LMovesText += LMove;
  LCommand := LActor.CreateRecordAutoPlayPVCommand(FAutoPlayNodeId,
    LMovesText);
  try
    Result := ExecuteAndApplyGameTreeCommand(LActor, LGameTree, LCommand,
      False, AErrorText);
    if not Result then
      Exit;
    FAutoPlayMovesText := LMovesText;
    Inc(FAutoPlayMoveCount);
    ApplyAnnotatorVariationBrowsePly(FAutoPlayBasePly,
      FAutoPlayMoveCount, LMovesText, LGameTree);
  finally
    LCommand.Free;
  end;
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
  if AutoPlaySearchMatches(ASearch) then
  begin
    Actor := ActorForSearchRef(ASearch);
    if Actor = nil then
    begin
      StopAutoPlay('game tree not found');
      Exit;
    end;
    LAccepted := AcceptSearchMove(Actor, ASearch, AMoveText, LErrorText);
    if LAccepted then
      ReleaseGameTreeSearch(Actor, ASearch)
    else
      ReleaseRejectedSearchIfFinished(Actor, ASearch);
    FAutoPlaySearch := EmptyGameTreeSearchRef;
    if not LAccepted then
    begin
      StopAutoPlay(LErrorText);
      Exit;
    end;
    if not StoreAutoPlayMove(AMoveText, LErrorText) then
    begin
      StopAutoPlay(LErrorText);
      Exit;
    end;
    StartNextAutoPlaySearch;
    Exit;
  end;

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
  UpdateDatabaseSearchPositionFromTree(ActiveGameTree);
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
    UpdateAutoPlayButtonState;
    RestartAnalyzer(ActiveGameTree);
  finally
    Engines.Free;
  end;
end;

procedure TMainForm.CloseAnalyzerClick(Sender: TObject);
begin
  if FAutoPlayActive then
    StopAutoPlay('annotator closed');
  CancelAnalyzerSearch;
  if FAnalyzerRunner <> nil then
  begin
    if FAnalyzerMemo <> nil then
      FAnalyzerMemo.Lines.Add('Closing Annotator');
    FAnalyzerRunner.PostShutdown;
  end;
  FAnalyzerEngineKey := '';
  UpdateAutoPlayButtonState;
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
  LBaseBoard: TDraughtsBoard;
  LGameTree: TGameTree;
  LNode: TGameTreePlyNode;
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
  if FAutoPlayActive or (FAnalyzerRunner = nil) then
    Exit;

  LGameTree := AGameTree;
  if LGameTree = nil then
    Exit;
  LSearch := EmptyGameTreeSearchRef;
  LNode := CurrentDisplayedGameTreeNode(LGameTree);
  if LNode = nil then
    Exit;
  LBaseBoard := TDraughtsBoard.Create;
  try
    if not TryBuildDisplayedBoard(LGameTree, LBaseBoard) then
      Exit;

    LStartingFEN := StartingFenForTree(LGameTree);
    if not DisplayedMoveContext(LGameTree, LDisplayedMovesText,
      LDisplayedMoveCount) then
      Exit;
    LTotalMoveCount := LGameTree.MainlineCount;
    LGameState := StateForTree(LGameTree);

    Signature := DisplayedPositionSignature(LGameTree, LNode.NodeId,
      LStartingFEN, LDisplayedMovesText, LGameState);
    if Signature = FAnalyzerLastPositionSignature then
      Exit;
    FAnalyzerLastPositionSignature := Signature;
    CancelAnalyzerSearch;

    if Trim(FDisplayedPosition.PreviewMoves) <> '' then
    begin
      SetAnalyzerPvBase(LBaseBoard, LDisplayedMoveCount);
    end
    else
    begin
      SetAnalyzerPvBaseFromTree(LGameTree, LNode.NodeId, LDisplayedMoveCount,
        LBaseBoard);
    end;
    LTerminal := DisplayedPositionIsTerminal(LDisplayedMoveCount,
      LTotalMoveCount, LGameState);
    if LTerminal and (FAnalyzerPvBrowser <> nil) then
      FAnalyzerPvBrowser.Clear;
    if (not LTerminal) and (Trim(FDisplayedPosition.PreviewMoves) = '') then
    begin
      if TryStartGameTreeSearchForDisplayedNode(LGameTree, LSearch,
        LErrorText) then
        TrackAnalyzerSearch(LSearch);
    end;
    FAnalyzerRunner.PostAnalyze(LStartingFEN, LDisplayedMovesText,
      FAnalyzerPvBaseBoard, FAnalyzerPvBasePly, LTerminal,
      LSearch, Trim(FDisplayedPosition.PreviewMoves) <> '', AnnotatorSeconds);
  finally
    LBaseBoard.Free;
  end;
end;

procedure TMainForm.RestartMctsAnnotator(AGameTree: TGameTree);
var
  LBaseBoard: TDraughtsBoard;
  LGameTree: TGameTree;
  LNode: TGameTreePlyNode;
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
  LNode := CurrentDisplayedGameTreeNode(LGameTree);
  if LNode = nil then
    Exit;
  LBaseBoard := TDraughtsBoard.Create;
  try
    if not TryBuildDisplayedBoard(LGameTree, LBaseBoard) then
      Exit;
    LStartingFEN := StartingFenForTree(LGameTree);
    if not DisplayedMoveContext(LGameTree, LDisplayedMovesText,
      LDisplayedMoveCount) then
      Exit;
    LTotalMoveCount := LGameTree.MainlineCount;
    LGameState := StateForTree(LGameTree);

    Signature := DisplayedPositionSignature(LGameTree, LNode.NodeId,
      LStartingFEN, LDisplayedMovesText, LGameState);
    if Signature = FMctsLastPositionSignature then
      Exit;
    FMctsLastPositionSignature := Signature;
    ClearMctsStatsGrid;

    LTerminal := DisplayedPositionIsTerminal(LDisplayedMoveCount,
      LTotalMoveCount, LGameState);
    if not TryBuildTreeBoardAtNode(LGameTree, LNode, FTreePvBaseBoard) then
      FTreePvBaseBoard.AssignFrom(LBaseBoard);
    FMctsRunner.PostAnalyze(LStartingFEN, LDisplayedMovesText, FTreePvBaseBoard,
      LDisplayedMoveCount, LTerminal, EmptyGameTreeSearchRef);
  finally
    LBaseBoard.Free;
  end;
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

  if FGameActive and GameTreeHasContent(FGameTree) then
  begin
    LResponse := ShowGuiConfirmationDialog(Self, 'Close GWDGUI',
      'Save the standalone board as PDN before closing?', 'Yes', 'No', mrNo);
    if LResponse = mrCancel then
      Exit;
    if LResponse = mrYes then
    begin
      ShowStandaloneGame(nil);
      if not SaveCurrentGameWithDialog then
        Exit;
    end;
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
  if TryGetDisplayedBoardFen(ActiveGameTree, LFen) then
    Clipboard.AsText := LFen;
end;

procedure TMainForm.SetupPositionAccepted(Sender: TObject; const AFEN: string);
begin
  if not ConfirmReplaceStandaloneGame then
    Exit;
  try
    LoadStandaloneFen(AFEN);
  except
    on E: Exception do
      ShowGuiOkDialog(Self, 'Setup position', 'Invalid FEN: ' + E.Message);
  end;
end;

procedure TMainForm.SetupPositionClick(Sender: TObject);
var
  LFen: string;
begin
  if FPositionSetupForm = nil then
  begin
    FPositionSetupForm := TPositionSetupForm.Create(Self);
    FPositionSetupForm.OnAccepted := @SetupPositionAccepted;
    FPositionSetupForm.ApplyPreferences(FPreferences);
  end;
  if not TryGetDisplayedBoardFen(ActiveGameTree, LFen) then
    LFen := StartingFenForTree(ActiveGameTree);
  FPositionSetupForm.StartSetup(LFen);
  ShowFormCenteredOnOwner(FPositionSetupForm, Self);
end;

procedure TMainForm.LoadStandaloneFen(const AFEN: string);
var
  LBoard: TDraughtsBoard;
  LStartingFEN: string;
begin
  ClearHumanMoveSelection;
  LBoard := TDraughtsBoard.Create;
  try
    LBoard.LoadFromFEN(AFEN);
    LStartingFEN := LBoard.StartingFEN;

    if not RebuildStandaloneGameTreeFromImport(FGameTree, '?', 'White',
      'Black', '*', LStartingFEN, '', '') then
      Exit;
    FGameActive := False;
    SetDisplayedTreeTracking('', '', '', 0, -1);
    FStandaloneWhitePlayerName := 'White';
    FStandaloneBlackPlayerName := 'Black';
    FStandaloneEventName := '?';
    ClearVariationExploration;
    FDisplayedPosition.Cursor.Follow;
    ClearDisplayedPvCache(LBoard, 0);
    FViewedGameId := -1;
    if FGamesListBox <> nil then
      FGamesListBox.ItemIndex := 0;
    FGameLog.Clear;
    FGameLogSourceGameId := -1;
    FGameLogSourceLineCount := -1;
    FGameLogSourceShowStdout := False;
    RefreshDisplayFromGameTree(FGameTree, True);
  finally
    LBoard.Free;
  end;
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

  if not ConfirmReplaceStandaloneGame then
    Exit;
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
  if AnalyzerSnapshotIsTransient(ASnapshot) then
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
  if LHasSearch and
    (not TryResolveActiveSearchSnapshot(ASnapshot, Actor, LGameTree,
      LNode)) then
    Exit;

  if Actor = nil then
    Actor := ActorForGameTree(LGameTree);
  if Actor = nil then
    Exit;

  if (LNode = nil) and
    (not TryResolveAnalyzerSnapshotNode(LGameTree, ASnapshot, LNode)) then
    Exit;
  LNodeId := LNode.NodeId;

  if not RecordAnnotatorPvInGameTree(Actor, LGameTree, LNodeId,
    ASnapshot.Score, ASnapshot.PrincipalVariation, ASnapshot.Depth,
    ASnapshot.TimeText, LErrorText) then
  begin
    if FAnalyzerMemo <> nil then
      FAnalyzerMemo.Lines.Add('Annotator PV rejected; reason=' +
        LErrorText);
    Exit;
  end;
  Result := LGameTree;
end;

function TMainForm.PublishAnalyzerSnapshotToGameTree(
  ASnapshot: TPvSnapshot): TGameTree;
begin
  Result := RecordAnalyzerSnapshotInGameTree(ASnapshot);
end;

function TMainForm.PublishRunnerSnapshotToGameTree(AGame: TRunningGame;
  ASnapshot: TGameRunnerSnapshot): TGameTree;
begin
  Result := nil;
  if (AGame = nil) or (ASnapshot = nil) then
    Exit;

  UpdateRunningGameTreeFromSnapshot(AGame, ASnapshot);
  AGame.AssignRunnerSnapshot(ASnapshot);
  Result := AGame.GameTree;
end;

procedure TMainForm.LoadPdnGameToDisplay(AGame: TPdnGame);
var
  I: Integer;
  LBoard: TDraughtsBoard;
  LEventName: string;
  LMoves: TStringList;
  LResultText: string;
  LStartingFEN: string;
  LWhiteName: string;
  LBlackName: string;
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

    LResultText := AGame.ResultText;
    if Trim(LResultText) = '' then
      LResultText := '*';
    LStartingFEN := AGame.StartingFEN;
    LWhiteName := PlayerNameOrFallback(AGame.WhiteName, 'White');
    LBlackName := PlayerNameOrFallback(AGame.BlackName, 'Black');
    LEventName := PlayerNameOrFallback(AGame.EventName, '?');
    if not RebuildStandaloneGameTreeFromImport(FGameTree, LEventName,
      LWhiteName, LBlackName, LResultText, LStartingFEN, AGame.MovesText,
      AGame.MoveAnnotationsText, AGame.InitialCommentText) then
    begin
      ShowGuiOkDialog(Self, 'Open PDN', 'Could not load the PDN game tree.');
      Exit;
    end;
    FGameActive := False;
    SetDisplayedTreeTracking('', '', '', 0, -1);
    FStandaloneWhitePlayerName := LWhiteName;
    FStandaloneBlackPlayerName := LBlackName;
    FStandaloneEventName := LEventName;
    ClearVariationExploration;
    FDisplayedPosition.Cursor.Select(FGameTree, FGameTree.Root);
    ImportPdnTree(FGameTree, AGame);
    ClearDisplayedPvCache(LBoard, CurrentMoveCount);
    FViewedGameId := -1;
    if FGamesListBox <> nil then
      FGamesListBox.ItemIndex := 0;
    FGameLog.Clear;
    FGameLogSourceGameId := -1;
    FGameLogSourceLineCount := -1;
    FGameLogSourceShowStdout := False;
    RefreshDisplayFromGameTree(FGameTree, True);
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

procedure TMainForm.ApplyAnnotatorVariationBrowsePly(ABasePly,
  AVariationPly: Integer; const AMovesText: string; AGameTree: TGameTree);
begin
  ClearHumanMoveSelection;
  if FDisplayedPosition.SelectPreview(ABasePly, AVariationPly, AMovesText, AGameTree) then
    RefreshDisplayFromGameTree(AGameTree, False);
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
begin
  Result := FDisplayedPosition.ResolveNode(AGameTree, AGameTree = ActiveGameTree);
end;

function TMainForm.GetBrowseBasePly: Integer;
begin
  Result := FDisplayedPosition.BrowseBasePly(ActiveGameTree);
end;

function TMainForm.GetBrowsingBranch: Boolean;
begin
  Result := FDisplayedPosition.BrowsingBranch(ActiveGameTree);
end;

function TMainForm.GetBrowseVariationPly: Integer;
begin
  Result := FDisplayedPosition.PreviewPly;
end;

function TMainForm.CurrentVariationMoveCount(AGameTree: TGameTree): Integer;
begin
  Result := FDisplayedPosition.PreviewMoveCount;
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
begin
  Result := FDisplayedPosition.MovesText(AGameTree, AGameTree = ActiveGameTree);
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

function TMainForm.DisplayedPositionSignature(AGameTree: TGameTree;
  ANodeId: Int64; const AStartingFEN, AMovesText: string;
  AGameState: TGameOrchestratorState): string;
var
  LGameTreeId: Int64;
begin
  LGameTreeId := 0;
  if AGameTree <> nil then
    LGameTreeId := AGameTree.GameTreeId;
  Result := IntToStr(LGameTreeId) + #10 + IntToStr(ANodeId) + #10 +
    AStartingFEN + #10 + AMovesText + #10 +
    IntToStr(Ord(AGameState));
end;

function TMainForm.DisplayedPositionIsTerminal(ADisplayedMoveCount,
  ATotalMoveCount: Integer; AGameState: TGameOrchestratorState): Boolean;
begin
  Result := (not HasLegalDisplayedMove) or
    ((Trim(FDisplayedPosition.PreviewMoves) = '') and (AGameState = gosGameOver) and
      ((BrowseBasePly < 0) or (ADisplayedMoveCount >= ATotalMoveCount)));
end;

function TMainForm.HasDisplayedGameToSave: Boolean;
begin
  Result := GameTreeHasContent(ActiveGameTree);
end;

function TMainForm.ConfirmReplaceStandaloneGame: Boolean;
var
  Response: Integer;
begin
  Result := True;
  if not GameTreeHasContent(FGameTree) then
    Exit;
  Response := ShowGuiConfirmationDialog(Self, 'Replace board',
    'Save the standalone board as PDN before replacing it?', 'Yes', 'No', mrNo);
  if Response = mrCancel then
    Exit(False);
  if Response = mrYes then
  begin
    ShowStandaloneGame(nil);
    Result := SaveCurrentGameWithDialog;
  end;
end;

procedure TMainForm.ShowStandaloneGame(Sender: TObject);
begin
  ClearHumanMoveSelection;
  ClearVariationExploration;
  FGameActive := False;
  FViewedGameId := -1;
  FDisplayedPosition.Cursor.Follow;
  FGamesListBox.ItemIndex := 0;
  SetDisplayedTreeTracking('', '', '', 0, -1);
  FGameLog.Clear;
  FGameLogSourceGameId := -1;
  FGameLogSourceLineCount := -1;
  FGameLogSourceShowStdout := False;
  RefreshDisplayFromGameTree(FGameTree, True);
end;

procedure TMainForm.ClearTreeBranches(AGameTree: TGameTree);
var
  Actor: TGameTreeActor;
begin
  FNotation.ClearVariationHits;
  Actor := ActorForGameTree(AGameTree);
  ClearGameTreeBranches(Actor);
  ClearVariationExploration;
end;

procedure TMainForm.ImportPdnTree(AGameTree: TGameTree; AGame: TPdnGame);
var
  Actor: TGameTreeActor;
  ParsedRoot: TPdnMoveNode;
  Header: TGameTreeHeaderInput;
  StatusCommand: TGameTreeCommand;
  StatusError: string;

  procedure ImportChildren(Source: TPdnMoveNode; ParentId: Int64);
  var I: Integer; Command: TGameTreeCommand; ErrorText: string;
  begin
    if Source.HasNodeData then
    begin
      Command := Actor.CreateRestoreNodeDataCommand(ParentId, Source.NodeData);
      try
        if not ExecuteGameTreeCommand(Actor, Command, ErrorText) then
          AGame.AddImportWarning('Cannot restore node data: ' + ErrorText);
      finally Command.Free; end;
    end;
    for I := 0 to Source.ChildCount - 1 do
    begin
      Command := Actor.CreateImportNodeCommand(ParentId,
        Source.Children[I].MoveText, Source.Children[I].AnnotationText);
      try
        if ExecuteGameTreeCommand(Actor, Command, ErrorText) then
          ImportChildren(Source.Children[I], Command.CreatedNodeId)
        else
          AGame.AddImportWarning('Cannot load move ' + Source.Children[I].MoveText + ': ' + ErrorText);
      finally Command.Free; end;
    end;
  end;

begin
  if (AGameTree = nil) or (AGame = nil) then Exit;
  Actor := ActorForGameTree(AGameTree);
  if Actor = nil then Exit;
  ParsedRoot := AGame.BuildMoveTree;
  try
    ClearTreeBranches(AGameTree);
    ImportChildren(ParsedRoot, AGameTree.Root.NodeId);
    if Trim(AGame.ImportWarningsText) <> '' then
    begin
      Header := CurrentGameTreeHeaderInput(nil, AGameTree);
      Header.StatusText := Trim(StringReplace(AGame.ImportWarningsText, LineEnding, ' ', [rfReplaceAll]));
      StatusCommand := Actor.CreateSetHeaderCommand(Header);
      try ExecuteGameTreeCommand(Actor, StatusCommand, StatusError);
      finally StatusCommand.Free; end;
    end;
    RefreshDisplayFromGameTree(AGameTree, True);
  finally ParsedRoot.Free; end;
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
    if (LGame <> nil) and (LGame.GameTreeId = AGameTreeId) then
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

function TMainForm.StartingFenForTree(AGameTree: TGameTree): string;
begin
  Result := '';
  if AGameTree <> nil then
    Result := Trim(AGameTree.StartingFEN);
end;

function TMainForm.StateForTree(AGameTree: TGameTree): TGameOrchestratorState;
begin
  if AGameTree <> nil then
    Result := AGameTree.GameState
  else
    Result := gosWaiting;
end;

function TMainForm.ResultForTree(AGameTree: TGameTree): string;
begin
  Result := '';
  if AGameTree <> nil then
    Result := Trim(AGameTree.ResultText);
  if Result = '' then
    Result := '*';
end;

function TMainForm.RunningGameTreeExtendsSnapshot(AGame: TRunningGame;
  const AInput: TRunningSnapshotTreeInput): Boolean;
var
  LMoves: TStringList;
begin
  Result := False;
  if AGame = nil then
    Exit;
  if not (AInput.State in [gosStopped, gosGameOver]) then
    Exit;
  if AGame.BranchCount > 0 then
    Exit(True);

  LMoves := TStringList.Create;
  try
    TextToMoveList(AInput.MovesText, LMoves);
    Result := AGame.MainlineCount > LMoves.Count;
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
    AWhiteRemainingSeconds := 0;
    ABlackRemainingSeconds := 0;
    AWhiteUsedSeconds := 0;
    ABlackUsedSeconds := 0;
  end;
end;

function TMainForm.EnginePvForTree(AGameTree: TGameTree; APly: Integer;
  out APV, AScore, ADepth, ATimeText: string): Boolean;
var
  LNode: TGameTreePlyNode;
begin
  APV := '';
  AScore := '';
  ADepth := '';
  ATimeText := '';
  Result := False;
  if AGameTree = nil then
    Exit;

  if APly <= 0 then
    LNode := AGameTree.Root
  else
    LNode := AGameTree.MainlineNode[APly];
  if LNode = nil then
    Exit;

  APV := Trim(LNode.EnginePV);
  AScore := Trim(LNode.EngineScore);
  ADepth := Trim(LNode.EnginePVDepth);
  ATimeText := Trim(LNode.EnginePVTimeText);
  Result := APV <> '';
end;

function TMainForm.AnnotatorPvForTreeNode(AGameTree: TGameTree;
  ANodeId: Int64; out APV, AScore, ADepth, ATimeText: string): Boolean;
var
  LNode: TGameTreePlyNode;
begin
  APV := '';
  AScore := '';
  ADepth := '';
  ATimeText := '';
  Result := False;
  if (AGameTree = nil) or (ANodeId <= 0) then
    Exit;

  LNode := AGameTree.FindNodeById(ANodeId);
  if LNode = nil then
    Exit;

  APV := Trim(LNode.AnnotatorPV);
  AScore := Trim(LNode.AnnotatorScore);
  ADepth := Trim(LNode.AnnotatorPVDepth);
  ATimeText := Trim(LNode.AnnotatorPVTimeText);
  Result := APV <> '';
end;

function TMainForm.LatestEnginePvForTree(AGameTree: TGameTree;
  out ABasePly: Integer; out APV, AScore, ADepth, ATimeText: string): Boolean;
var
  Ply: Integer;
begin
  ABasePly := 0;
  APV := '';
  AScore := '';
  ADepth := '';
  ATimeText := '';
  Result := False;
  if AGameTree = nil then
    Exit;

  for Ply := AGameTree.MainlineCount downto 0 do
    if EnginePvForTree(AGameTree, Ply, APV, AScore, ADepth, ATimeText) then
    begin
      ABasePly := Ply;
      Exit(True);
    end;
end;

function TMainForm.TryBuildTreeBoardAtPly(AGameTree: TGameTree;
  APly: Integer; ABoard: TDraughtsBoard): Boolean;
begin
  Result := False;
  if (AGameTree = nil) or (APly < 0) then
    Exit;
  if APly = 0 then
    Result := TryBuildTreeBoardAtNode(AGameTree, AGameTree.Root, ABoard)
  else
    Result := TryBuildTreeBoardAtNode(AGameTree, AGameTree.MainlineNode[APly], ABoard);
end;

function TMainForm.TryBuildTreeBoardAtNode(AGameTree: TGameTree;
  ANode: TGameTreePlyNode; ABoard: TDraughtsBoard): Boolean;
var Actor: TGameTreeActor; Revision: Int64;
begin
  Actor := ActorForGameTree(AGameTree);
  Revision := -1;
  if Actor <> nil then Revision := Actor.Revision;
  Result := FDisplayedPosition.TryBuildNodeBoard(AGameTree, ANode, Revision, ABoard);
end;

function TMainForm.TryBuildDisplayedBoard(AGameTree: TGameTree;
  ABoard: TDraughtsBoard): Boolean;
var Actor: TGameTreeActor; Revision: Int64;
begin
  Actor := ActorForGameTree(AGameTree);
  Revision := -1;
  if Actor <> nil then Revision := Actor.Revision;
  Result := FDisplayedPosition.TryBuildBoard(AGameTree, AGameTree = ActiveGameTree,
    Revision, ABoard);
end;

function TMainForm.VisibleMainPvForTree(AGameTree: TGameTree;
  out ABaseBoard: TDraughtsBoard; out ABasePly: Integer; out APV, AScore,
  ADepth, ATimeText: string): Boolean;
var
  LDisplayedNode: TGameTreePlyNode;
  LGame: TRunningGame;
  LTreeDepth: string;
  LTreePV: string;
  LTreeScore: string;
  LTreeTimeText: string;
begin
  LGame := GameForTree(AGameTree);
  APV := '';
  AScore := '';
  ADepth := '';
  ATimeText := '';
  ABaseBoard := FTreePvBaseBoard;
  ABasePly := 0;
  LDisplayedNode := CurrentDisplayedGameTreeNode(AGameTree);
  if LDisplayedNode <> nil then
  begin
    ABasePly := LDisplayedNode.PlyNumber;
    if not TryBuildTreeBoardAtNode(AGameTree, LDisplayedNode,
      FTreePvBaseBoard) then
    begin
      ABasePly := 0;
      FTreePvBaseBoard.LoadFromFEN(StartingFenForTree(AGameTree));
    end;
  end
  else
  begin
    ABasePly := 0;
    FTreePvBaseBoard.LoadFromFEN(StartingFenForTree(AGameTree));
  end;

  if LGame <> nil then
  begin
    if LatestEnginePvForTree(AGameTree, ABasePly, LTreePV,
      LTreeScore, LTreeDepth, LTreeTimeText) then
    begin
      APV := LTreePV;
      AScore := LTreeScore;
      ADepth := LTreeDepth;
      ATimeText := LTreeTimeText;
      if TryBuildTreeBoardAtPly(AGameTree, ABasePly, FTreePvBaseBoard) then
        ABaseBoard := FTreePvBaseBoard;
      Exit(True);
    end;
    Exit(False);
  end
  else if AGameTree = FGameTree then
  begin
    if LatestEnginePvForTree(AGameTree, ABasePly, LTreePV, LTreeScore,
      LTreeDepth, LTreeTimeText) then
    begin
      APV := LTreePV;
      AScore := LTreeScore;
      ADepth := LTreeDepth;
      ATimeText := LTreeTimeText;
      if TryBuildTreeBoardAtPly(AGameTree, ABasePly, FTreePvBaseBoard) then
        ABaseBoard := FTreePvBaseBoard;
      Exit(True);
    end;
  end;

  Result := Trim(APV) <> '';
end;

procedure TMainForm.RefreshMainPvBrowserFromTree(AGameTree: TGameTree;
  const AStartingFEN: string);
var
  LPvBaseBoard: TDraughtsBoard;
  LPvBasePly: Integer;
  LPvDepth: string;
  LPvScore: string;
  LPvText: string;
  LPvTimeText: string;
  LStartingFEN: string;
begin
  if FPvBrowser = nil then
    Exit;

  LStartingFEN := AStartingFEN;
  if LStartingFEN = '' then
    LStartingFEN := StartingFenForTree(AGameTree);

  VisibleMainPvForTree(AGameTree, LPvBaseBoard, LPvBasePly, LPvText,
    LPvScore, LPvDepth, LPvTimeText);
  FPvBrowser.SetData(LPvBaseBoard, LPvBasePly, LStartingFEN, LPvText,
    LPvScore, LPvDepth, LPvTimeText);
end;

procedure TMainForm.RefreshAnalyzerPvBrowserFromTree(AGameTree: TGameTree;
  ANodeId: Int64; AFallbackBasePly: Integer);
var
  LPvDepth: string;
  LPvScore: string;
  LPvText: string;
  LPvTimeText: string;
begin
  if FAnalyzerPvBrowser = nil then
    Exit;

  if not AnnotatorPvForTreeNode(AGameTree, ANodeId, LPvText, LPvScore,
    LPvDepth, LPvTimeText) then
  begin
    if (ANodeId <= 0) and (AGameTree <> nil) then
    begin
      if AFallbackBasePly <= 0 then
        ANodeId := AGameTree.Root.NodeId
      else if AGameTree.MainlineNode[AFallbackBasePly] <> nil then
        ANodeId := AGameTree.MainlineNode[AFallbackBasePly].NodeId;
    end;
    if not AnnotatorPvForTreeNode(AGameTree, ANodeId, LPvText, LPvScore,
      LPvDepth, LPvTimeText) then
    begin
      FAnalyzerPvBrowser.Clear;
      Exit;
    end;
  end;

  FAnalyzerPvBrowser.SetData(FAnalyzerPvBaseBoard, FAnalyzerPvBasePly,
    StartingFenForTree(AGameTree), LPvText, LPvScore, LPvDepth, LPvTimeText);
end;

procedure TMainForm.SetDisplayedTreeTracking(const AAnnotationsSignature,
  AMovesSignature, ARunningSignature: string; AGameTreeId,
  AGameTreeRevision: Int64);
begin
  FDisplayedAnnotationsSignature := AAnnotationsSignature;
  FDisplayedMovesSignature := AMovesSignature;
  FNotation.InvalidateSignature;
  FDisplayedScoreHistorySignature := '';
  FDisplayedRunningSignature := ARunningSignature;
  FDisplayedGameTreeId := AGameTreeId;
  FDisplayedGameTreeRevision := AGameTreeRevision;
end;

function TMainForm.DisplayedPvCacheMatches(const APV, AScore, ADepth,
  ATimeText, ABasePositionKey: string; ABasePly: Integer): Boolean;
begin
  Result := (FPrincipalVariation = APV) and
    (FPrincipalVariationScore = AScore) and
    (FPrincipalVariationDepth = ADepth) and
    (FPrincipalVariationTimeText = ATimeText) and
    (FPvBasePly = ABasePly) and
    (FPvBasePositionKey = ABasePositionKey);
end;

procedure TMainForm.SetDisplayedPvCache(const APV, AScore, ADepth,
  ATimeText: string; ABaseBoard: TDraughtsBoard; ABasePly: Integer);
begin
  FPrincipalVariation := APV;
  FPrincipalVariationScore := AScore;
  FPrincipalVariationDepth := ADepth;
  FPrincipalVariationTimeText := ATimeText;
  if ABaseBoard <> nil then
    FPvBasePositionKey := ABaseBoard.PositionKey
  else
    FPvBasePositionKey := '';
  FPvBasePly := ABasePly;
end;

function TMainForm.UpdateDisplayedPvCacheFromTree(
  AGameTree: TGameTree): Boolean;
var
  LPvBaseBoard: TDraughtsBoard;
  LPvBasePly: Integer;
  LPvBasePositionKey: string;
  LPvDepth: string;
  LPvScore: string;
  LPvText: string;
  LPvTimeText: string;
begin
  LPvBaseBoard := nil;
  LPvBasePly := 0;
  LPvText := '';
  LPvScore := '';
  LPvDepth := '';
  LPvTimeText := '';
  if VisibleMainPvForTree(AGameTree, LPvBaseBoard, LPvBasePly, LPvText,
    LPvScore, LPvDepth, LPvTimeText) and (LPvBaseBoard <> nil) then
    LPvBasePositionKey := LPvBaseBoard.PositionKey
  else
    LPvBasePositionKey := '';

  Result := not DisplayedPvCacheMatches(LPvText, LPvScore, LPvDepth,
    LPvTimeText, LPvBasePositionKey, LPvBasePly);
  if Result then
    SetDisplayedPvCache(LPvText, LPvScore, LPvDepth, LPvTimeText,
      LPvBaseBoard, LPvBasePly);
end;

procedure TMainForm.ClearDisplayedPvCache(ABaseBoard: TDraughtsBoard;
  ABasePly: Integer);
begin
  SetDisplayedPvCache('', '', '', '', ABaseBoard, ABasePly);
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
begin
  if (FGameMoveMemo = nil) or (AGameTree = nil) then Exit;
  FNotation.Render(AGameTree, CurrentFilteredGameTreePdnOptions);
  if FGameMoveMemo.Text <> FNotation.Text then
  begin
    FGameMoveMemo.Lines.BeginUpdate;
    try
      FGameMoveMemo.Text := FNotation.Text;
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
  LResultText: string;
  LState: TGameOrchestratorState;
  LStartingFEN: string;
  LStatusText: string;
  LTimeControl: TTimeControl;
  LTreeSignature: string;
  LWhiteName: string;
begin
  if AGame <> nil then
  begin
    LWhiteName := PlayerNameOrFallback(Trim(AGameTree.WhiteName),
      AGame.WhiteDisplayName);
    LBlackName := PlayerNameOrFallback(Trim(AGameTree.BlackName),
      AGame.BlackDisplayName);
    LResultText := ResultForTree(AGameTree);
    LStartingFEN := StartingFenForTree(AGameTree);
    LState := StateForTree(AGameTree);
  end
  else
  begin
    LWhiteName := WhiteNameForTree(AGameTree);
    LBlackName := BlackNameForTree(AGameTree);
    LResultText := ResultForTree(AGameTree);
    LStartingFEN := StartingFenForTree(AGameTree);
    LState := StateForTree(AGameTree);
  end;

  if AGame <> nil then
    LTreeSignature := 'running:' + IntToStr(AGame.Id)
  else
  begin
    LMovesText := GameTreeMainlineMovesText(AGameTree);
    LTreeSignature := 'standalone:' + LStartingFEN + '|' +
      EventNameForTree(AGameTree) + '|' + LWhiteName +
      '|' + LBlackName + '|moves=' + LMovesText;
  end;

  LRecordTimeControl := AGame <> nil;
  if LRecordTimeControl then
    LTimeControl := AGame.SetupTimeControl
  else
    FillChar(LTimeControl, SizeOf(LTimeControl), 0);
  if AGameTree <> nil then
    LStatusText := AGameTree.StatusText
  else
    LStatusText := '';

  if AGame <> nil then
    Result := GameTreeHeaderInput(LTreeSignature,
      EventNameForTree(AGameTree), LWhiteName, LBlackName,
      LResultText, LStartingFEN, LRecordTimeControl, LTimeControl, LState,
      LStatusText)
  else
    Result := GameTreeHeaderInput(LTreeSignature,
      EventNameForTree(AGameTree), LWhiteName, LBlackName,
      LResultText, LStartingFEN,
      LRecordTimeControl, LTimeControl, LState, LStatusText);
end;

function TMainForm.RunningSnapshotTreeInput(AGame: TRunningGame;
  ASnapshot: TGameRunnerSnapshot;
  const AEventName: string): TRunningSnapshotTreeInput;
var
  LEventName: string;
begin
  LEventName := PlayerNameOrFallback(AEventName,
    EventNameForTree(AGame.GameTree));
  AGame.SnapshotTreeInput(ASnapshot, LEventName, Result);
end;

function TMainForm.RunningSnapshotHeaderInput(
  const AInput: TRunningSnapshotTreeInput): TGameTreeHeaderInput;
begin
  Result := GameTreeHeaderInput('running:' + IntToStr(AInput.GameId),
    AInput.EventName, AInput.WhiteName, AInput.BlackName, AInput.ResultText,
    AInput.StartingFEN, True, AInput.TimeControl, AInput.State,
    AInput.StatusText);
end;

function TMainForm.RunningSnapshotMainlineInput(
  const AInput: TRunningSnapshotTreeInput; AMoves, AAnnotations: TStrings;
  ARecordClock: Boolean): TGameTreeMainlineInput;
begin
  if not ARecordClock then
    Result := GameTreeMainlineInput(AMoves, AAnnotations, False, 0, 0, 0, 0)
  else
    Result := GameTreeMainlineInput(AMoves, AAnnotations, True,
      AInput.WhiteRemainingSeconds, AInput.BlackRemainingSeconds,
      AInput.WhiteUsedSeconds, AInput.BlackUsedSeconds);
  Result.MoveData := Copy(AInput.MoveData);
end;

function TMainForm.RunningSnapshotPvInput(
  const AInput: TRunningSnapshotTreeInput; ARecordPV: Boolean): TGameTreePvInput;
begin
  if (not ARecordPV) or (Trim(AInput.PrincipalVariation) = '') then
  begin
    Result := GameTreePvInput(False, 0, '', '');
    Exit;
  end;

  Result := GameTreePvInput(True, AInput.PvBasePly, AInput.PvScore,
    AInput.PrincipalVariation, AInput.PvDepth, AInput.PvTimeText);
end;

function TMainForm.RunningSnapshotSyncSignature(
  const AInput: TRunningSnapshotTreeInput): string;

  function SecondsSignature(AValue: Double): string;
  begin
    Result := FormatFloat('0.000', AValue);
  end;

begin
  Result :=
    AInput.EventName + #10 +
    AInput.WhiteName + #10 +
    AInput.BlackName + #10 +
    AInput.ResultText + #10 +
    AInput.StartingFEN + #10 +
    IntToStr(Ord(AInput.State)) + #10 +
    AInput.MovesText + #10 +
    AInput.AnnotationsText + #10 +
    GameMoveDataSignature(AInput.MoveData) + #10 +
    SecondsSignature(AInput.WhiteRemainingSeconds) + #10 +
    SecondsSignature(AInput.BlackRemainingSeconds) + #10 +
    SecondsSignature(AInput.WhiteUsedSeconds) + #10 +
    SecondsSignature(AInput.BlackUsedSeconds);
end;

function TMainForm.RunningDisplaySignature(AGame: TRunningGame;
  ALogLineCount: Integer): string;
var
  Actor: TGameTreeActor;
  LRevision: Int64;
begin
  Result := IntToStr(AGame.Id);
  LRevision := -1;
  Actor := ActorForGameTree(AGame.GameTree);
  if Actor <> nil then
    LRevision := Actor.Revision;
  Result := Result + #10 +
    'tree=' + IntToStr(AGame.GameTreeId) + #10 +
    'revision=' + IntToStr(LRevision);
  Result := Result + #10 +
    IntToStr(Ord(AGame.State)) + #10 +
    IntToStr(ALogLineCount) + #10 +
    BoolToStr(AGame.ShowStdout, True);
end;

procedure TMainForm.InitializeRunningGameTree(AGame: TRunningGame);
var
  Actor: TGameTreeActor;
  LErrorText: string;
  LInput: TRunningSnapshotTreeInput;
begin
  if AGame = nil then
    Exit;

  Actor := ActorForGameTree(AGame.GameTree);
  if Actor = nil then
    Exit;

  LInput := RunningSnapshotTreeInput(AGame, nil, '');
  LInput.State := gosRunning;
  LInput.WhiteRemainingSeconds := AGame.InitialClockSeconds;
  LInput.BlackRemainingSeconds := LInput.WhiteRemainingSeconds;
  LInput.WhiteUsedSeconds := 0;
  LInput.BlackUsedSeconds := 0;
  RebuildGameTreeFromInputs(Actor,
    RunningSnapshotHeaderInput(LInput),
    RunningSnapshotMainlineInput(LInput, nil, nil, True),
    GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', ''),
    LErrorText);
end;

procedure TMainForm.UpdateRunningGameTreeFromSnapshot(AGame: TRunningGame;
  ASnapshot: TGameRunnerSnapshot;
  const AEventName: string);
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  LErrorText: string;
  LAnnotations: TStringList;
  LGameTree: TGameTree;
  LInput: TRunningSnapshotTreeInput;
  LMoves: TStringList;
  LSyncSignature: string;

  function LineOrEmpty(AStrings: TStrings; AIndex: Integer): string;
  begin
    Result := '';
    if (AStrings <> nil) and (AIndex >= 0) and (AIndex < AStrings.Count) then
      Result := AStrings[AIndex];
  end;

  function SnapshotMovesMatchTreePrefix(ATreeMoveCount: Integer): Boolean;
  var
    I: Integer;
  begin
    Result := False;
    if (ATreeMoveCount < 0) or (ATreeMoveCount > LGameTree.MainlineCount) or
      (ATreeMoveCount > LMoves.Count) then
      Exit;

    for I := 1 to ATreeMoveCount do
      if not SameText(NormalizeMoveNotation(LGameTree.MainlineNode[I].MoveText),
        NormalizeMoveNotation(LMoves[I - 1])) then
        Exit;

    Result := True;
  end;

  function SnapshotExtendsCurrentTree: Boolean;
  begin
    Result := (LGameTree.MainlineCount < LMoves.Count) and
      SnapshotMovesMatchTreePrefix(LGameTree.MainlineCount);
  end;

  function SnapshotMovesMatchCurrentTree: Boolean;
  begin
    Result := False;
    if LGameTree.MainlineCount <> LMoves.Count then
      Exit;
    Result := SnapshotMovesMatchTreePrefix(LGameTree.MainlineCount);
  end;

  function TryAppendSnapshotMoves: Boolean;
  var
    I: Integer;
    IsLastMove: Boolean;
    MutatedTree: Boolean;
  begin
    Result := False;
    MutatedTree := False;
    if not SnapshotExtendsCurrentTree then
      Exit;
    Actor := ActorForGameTree(LGameTree);
    if Actor = nil then
      Exit;

    for I := LGameTree.MainlineCount to LMoves.Count - 1 do
    begin
      IsLastMove := I = LMoves.Count - 1;
      Command := Actor.CreateAppendMainlineSnapshotMoveCommand(
        RunningSnapshotHeaderInput(LInput),
        LMoves[I], LineOrEmpty(LAnnotations, I),
        RunningSnapshotMainlineInput(LInput, nil, nil, IsLastMove),
        RunningSnapshotPvInput(LInput, IsLastMove),
        gmsEngineMatch);
      try
        if not ExecuteGameTreeCommand(Actor, Command, LErrorText) then
        begin
          if MutatedTree then
            RefreshDisplayFromGameTree(LGameTree, True);
          Exit;
        end;
        MutatedTree := MutatedTree or Command.TreeChanged;
      finally
        Command.Free;
      end;
    end;
    if MutatedTree then
      RefreshDisplayFromGameTree(LGameTree, True);
    Result := True;
  end;

  procedure TryRecordSnapshotPV;
  var
    LNode: TGameTreePlyNode;
    LPvSignature: string;
  begin
    if Trim(LInput.PrincipalVariation) = '' then
      Exit;
    if not TryResolveRunningSnapshotPvNode(LGameTree, LInput, LNode) then
      Exit;
    Actor := ActorForGameTree(LGameTree);
    if Actor = nil then
      Exit;
    LPvSignature := IntToStr(LGameTree.GameTreeId) + #10 +
      IntToStr(LNode.NodeId) + #10 + LInput.PvScore + #10 +
      LInput.PrincipalVariation + #10 + LInput.PvDepth + #10 +
      LInput.PvTimeText;
    if AGame.SnapshotPvSignatureMatches(LPvSignature) then
      Exit;
    if RecordEnginePvInGameTree(Actor, LGameTree, LNode.NodeId,
      LInput.PvScore, LInput.PrincipalVariation, LInput.PvDepth,
      LInput.PvTimeText, LErrorText) then
      AGame.RememberSnapshotPvSignature(LPvSignature);
  end;
begin
  if AGame = nil then
    Exit;
  LInput := RunningSnapshotTreeInput(AGame, ASnapshot, AEventName);

  LGameTree := AGame.GameTree;
  TryRecordSnapshotPV;
  if RunningGameTreeExtendsSnapshot(AGame, LInput) then
    Exit;

  LSyncSignature := RunningSnapshotSyncSignature(LInput);
  if AGame.SnapshotSyncSignatureMatches(LSyncSignature) then
    Exit;

  LMoves := TStringList.Create;
  LAnnotations := TStringList.Create;
  try
    TextToMoveList(LInput.MovesText, LMoves);
    LAnnotations.Text := LInput.AnnotationsText;

    if TryAppendSnapshotMoves then
    begin
      AGame.RememberSnapshotSyncSignature(LSyncSignature);
      Exit;
    end;

    if SnapshotMovesMatchCurrentTree then
    begin
      Actor := ActorForGameTree(LGameTree);
      if Actor <> nil then
      begin
        Command := Actor.CreateSetHeaderCommand(
          RunningSnapshotHeaderInput(LInput),
          RunningSnapshotMainlineInput(LInput, nil, nil, True));
        try
          ExecuteAndApplyGameTreeCommand(Actor, LGameTree, Command, False,
            LErrorText);
        finally
          Command.Free;
        end;
      end;
      AGame.RememberSnapshotSyncSignature(LSyncSignature);
      Exit;
    end;

    Actor := ActorForGameTree(LGameTree);
    if Actor = nil then
      Exit;
    if RebuildGameTreeFromInputs(Actor,
      RunningSnapshotHeaderInput(LInput),
      RunningSnapshotMainlineInput(LInput, LMoves, LAnnotations, True),
      RunningSnapshotPvInput(LInput, True),
      GameTreePvInput(False, 0, '', ''), LErrorText) then
      AGame.RememberSnapshotSyncSignature(LSyncSignature);
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
  if AGame = nil then
    Exit;

  LOptions := DefaultGameTreePdnRenderOptions;
  Result := GameTreeToPdnTextEx(AGame.GameTree, LOptions, AEventName);
end;

procedure TMainForm.UpdateGameMoveHighlight;
var
  I: Integer;
  LHighlightPly: Integer;
begin
  if FGameMoveMemo = nil then
    Exit;

  LHighlightPly := BrowseBasePly;
  if (LHighlightPly < 0) and (SelectedDisplayedGame <> nil) then
    LHighlightPly := CurrentMoveCount;

  if (FHighlightedGameMovePly = LHighlightPly) and
    (not BrowsingBranch) and (Trim(FDisplayedPosition.PreviewMoves) = '') then
    Exit;
  for I := 0 to FNotation.VariationCount - 1 do
    if ((FDisplayedPosition.PreviewMoves = '') and not FNotation.VariationHits[I].BeforeMove and
      (FNotation.VariationHits[I].NodeId > 0) and (FNotation.VariationHits[I].NodeId = FDisplayedPosition.Cursor.NodeId)) or
      ((FDisplayedPosition.PreviewMoves <> '') and (FNotation.VariationHits[I].MovesText = FDisplayedPosition.PreviewMoves) and
      (FNotation.VariationHits[I].BasePly = BrowseBasePly) and
      (FNotation.VariationHits[I].VariationPly = FDisplayedPosition.PreviewPly)) then
    begin
      FGameMoveMemo.SelStart := FNotation.VariationHits[I].Start;
      FGameMoveMemo.SelLength := FNotation.VariationHits[I].Length;
      FHighlightedGameMovePly := -2;
      Exit;
    end;
  if (LHighlightPly > 0) and (LHighlightPly <= FNotation.MoveCount) then
  begin
    FGameMoveMemo.SelStart := FNotation.MoveRanges[LHighlightPly - 1].Start;
    FGameMoveMemo.SelLength := FNotation.MoveRanges[LHighlightPly - 1].Length;
  end
  else
  begin
    FGameMoveMemo.SelStart := 0;
    FGameMoveMemo.SelLength := 0;
  end;
  FHighlightedGameMovePly := LHighlightPly;
end;


procedure TMainForm.UpdateBoardHighlights(AGameTree: TGameTree);
var
  LDisplayedBoard: TDraughtsBoard;
  LGameMoves: TStringList;
  LPvBaseBoard: TDraughtsBoard;
  LPvBasePly: Integer;
  LPvDepth: string;
  LPvHighlightsActive: Boolean;
  Highlights: TMoveHighlights;
  LPvScore: string;
  LPvTimeText: string;
  LPvText: string;
begin
  if FBoardControl = nil then
    Exit;
  if AGameTree = nil then
    Exit;

  LDisplayedBoard := TDraughtsBoard.Create;
  LGameMoves := TStringList.Create;
  try
    AGameTree.CopyMainlineMovesTo(LGameMoves);
    if FPvHintSource = phsAnalyzer then
    begin
      LPvBaseBoard := FAnalyzerPvBaseBoard;
      if not AnnotatorPvForTreeNode(AGameTree, FAnalyzerPvBaseNodeId,
        LPvText, LPvScore, LPvDepth, LPvTimeText) then
        LPvText := '';
    end
    else
      VisibleMainPvForTree(AGameTree, LPvBaseBoard, LPvBasePly, LPvText,
        LPvScore, LPvDepth, LPvTimeText);
    LPvHighlightsActive := (LPvBaseBoard <> nil) and
      TryBuildDisplayedBoard(AGameTree, LDisplayedBoard) and
      (LDisplayedBoard.PositionKey = LPvBaseBoard.PositionKey);

    Highlights := CalculateMoveHighlights(LGameMoves, BrowseBasePly, LPvText,
      LPvHighlightsActive);
    FBoardControl.LastMoveTargetSquare := Highlights.LastMoveTargetSquare;
    FBoardControl.PvSourceSquare := Highlights.PvSourceSquare;
    FBoardControl.HintSourceSquare := Highlights.HintSourceSquare;
  finally
    LGameMoves.Free;
    LDisplayedBoard.Free;
  end;
end;

procedure TMainForm.UpdateBoardFromBrowseState(AGameTree: TGameTree);
begin
  FDisplayBoardFailed := not TryBuildDisplayedBoard(AGameTree, FBoard);
  if FDisplayBoardFailed then
  begin
    Caption := 'GWDGUI - Cannot display the selected position';
    ClearHumanMoveSelection;
    CancelAnalyzerSearch;
    if FBoardControl <> nil then FBoardControl.Board := nil;
    if FAutoPlayButton <> nil then FAutoPlayButton.Enabled := False;
    Exit;
  end;
  Caption := 'GWDGUI - International Polish Draughts';
  if FBoardControl <> nil then
  begin
    FBoardControl.Board := FBoard;
    FBoardControl.Invalidate;
  end;
  UpdateDatabaseSearchPositionFromTree(AGameTree);
end;

procedure TMainForm.ApplyGameBrowsePly(APly: Integer);
var
  LMoveCount: Integer;
begin
  ClearHumanMoveSelection;
  ClearVariationExploration;
  LMoveCount := CurrentMoveCount;
  if APly < 0 then APly := LMoveCount
  else if APly > LMoveCount then APly := 0;
  if APly = 0 then FDisplayedPosition.Cursor.Select(ActiveGameTree, ActiveGameTree.Root)
  else FDisplayedPosition.Cursor.Select(ActiveGameTree, ActiveGameTree.MainlineNode[APly]);
  RefreshDisplayFromGameTree(ActiveGameTree, False);
end;

procedure TMainForm.ExitGameBrowseMode;
begin
  if Trim(FDisplayedPosition.PreviewMoves) <> '' then
  begin
    ClearVariationExploration;

    RefreshDisplayFromGameTree(ActiveGameTree, False);
    Exit;
  end;
  if BrowseBasePly < 0 then
  begin
    if FGameMoveMemo <> nil then
      FGameMoveMemo.SelLength := 0;
    Exit;
  end;
  ClearVariationExploration;
  FDisplayedPosition.Cursor.Follow;
  RefreshDisplayFromGameTree(ActiveGameTree, False);
end;

procedure TMainForm.ApplyGameToDisplay(AGame: TRunningGame);
var
  LLogSourceChanged: Boolean;
  LEffectiveAnnotationsText: string;
  LEffectiveResultText: string;
  LEffectiveStartingFEN: string;
  LEffectiveState: TGameOrchestratorState;
  LPositionChanged: Boolean;
  LPvChanged: Boolean;
  LRunningSignature: string;
  LEffectiveMovesText: string;
  LLogInput: TRunningSnapshotLogInput;

  procedure UpdateDisplayedGameLog;
  var
    J: Integer;
    LLogLines: TStringList;
  begin
    LLogSourceChanged := (FGameLogSourceGameId <> AGame.Id) or
      (FGameLogSourceLineCount <> LLogInput.LogLineCount) or
      (FGameLogSourceShowStdout <> AGame.ShowStdout);
    if LLogSourceChanged then
    begin
      FGameLog.Clear;
      LLogLines := TStringList.Create;
      try
        LLogLines.Text := LLogInput.LogLinesText;
        for J := 0 to LLogLines.Count - 1 do
          if GameLogLineVisible(LLogLines[J], AGame) then
            FGameLog.Add(LLogLines[J]);
      finally
        LLogLines.Free;
      end;
      FGameLogSourceGameId := AGame.Id;
      FGameLogSourceLineCount := LLogInput.LogLineCount;
      FGameLogSourceShowStdout := AGame.ShowStdout;
    end;
  end;

begin
  if AGame = nil then
  begin
    ShowStandaloneGame(nil);
    Exit;
  end;

  if FViewedGameId <> AGame.Id then
  begin
    ClearHumanMoveSelection;
    ClearVariationExploration;
    FViewedGameId := AGame.Id;
    FDisplayedPosition.Cursor.Follow;
    SetDisplayedTreeTracking('', '', '', 0, -1);
  end;

  AGame.SnapshotLogInput(LLogInput);
  LRunningSignature := RunningDisplaySignature(AGame, LLogInput.LogLineCount);
  UpdateDisplayedGameLog;
  if FDisplayedRunningSignature = LRunningSignature then
  begin
    UpdateClockLabels(AGame.GameTree, WhiteNameForTree(AGame.GameTree),
      BlackNameForTree(AGame.GameTree));
    UpdateGameLogMemo;
    RefreshDisplayedGameTreeViews(AGame.GameTree, False);
    if AGame.GameTree = ActiveGameTree then
    begin
      RefreshMainPvBrowserFromTree(AGame.GameTree);
      if FBoardControl <> nil then
        FBoardControl.Invalidate;
    end;
    Exit;
  end;
  FDisplayedRunningSignature := LRunningSignature;

  LEffectiveMovesText := GameTreeMainlineMovesText(AGame.GameTree);
  LEffectiveAnnotationsText := GameTreeScoreAnnotationsText(AGame.GameTree);
  LEffectiveStartingFEN := StartingFenForTree(AGame.GameTree);
  LEffectiveResultText := ResultForTree(AGame.GameTree);
  LEffectiveState := StateForTree(AGame.GameTree);

  LPositionChanged := (FStartingFEN <> LEffectiveStartingFEN) or
    (FDisplayedAnnotationsSignature <> LEffectiveAnnotationsText) or
    (FDisplayedMovesSignature <> LEffectiveMovesText) or
    (FGameState <> LEffectiveState) or
    (FGameResult <> LEffectiveResultText);
  LPvChanged := UpdateDisplayedPvCacheFromTree(AGame.GameTree);
  if FDisplayedMovesSignature <> LEffectiveMovesText then
  begin
    ClearHumanMoveSelection;
    ClearVariationExploration;
  end;
  FStartingFEN := LEffectiveStartingFEN;
  FGameState := LEffectiveState;
  FGameResult := LEffectiveResultText;
  FGameActive := True;
  if not LPositionChanged then
  begin
    UpdateClockLabels(AGame.GameTree, WhiteNameForTree(AGame.GameTree),
      BlackNameForTree(AGame.GameTree));
    UpdateGameLogMemo;
    if LPvChanged then
    begin
      UpdateBoardHighlights(AGame.GameTree);
      RefreshMainPvBrowserFromTree(AGame.GameTree);
      if FBoardControl <> nil then
        FBoardControl.Invalidate;
    end;
    Exit;
  end;

  RefreshDisplayFromGameTree(AGame.GameTree, False);
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
var
  LGameTree: TGameTree;
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
    LGameTree := ActiveGameTree;
    UpdateBoardHighlights(LGameTree);
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
var
  LGameTree: TGameTree;
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
    LGameTree := ActiveGameTree;
    UpdateBoardHighlights(LGameTree);
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

function TMainForm.CurrentGameTreePdnText(const AEventName: string): string;
var
  LGameTree: TGameTree;
  LOptions: TGameTreePdnRenderOptions;
begin
  Result := '';
  LGameTree := ActiveGameTree;
  if LGameTree = nil then
    Exit;

  LOptions := DefaultGameTreePdnRenderOptions;
  Result := GameTreeToPdnTextEx(LGameTree, LOptions, AEventName);
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
  LSelEnd: Integer;
  LSelStart: Integer;

  function SelectionHitsRange(AStart, ALength: Integer): Boolean;
  var
    LRangeEnd: Integer;
  begin
    Result := False;
    if ALength <= 0 then
      Exit;
    LRangeEnd := AStart + ALength;
    if LSelEnd > LSelStart then
      Result := (LSelStart < LRangeEnd) and (LSelEnd > AStart)
    else
      Result := (LSelStart >= AStart) and (LSelStart <= LRangeEnd);
  end;
begin
  Result := False;
  if FGameMoveMemo = nil then
    Exit;
  LGameTree := ActiveGameTree;
  LSelStart := FGameMoveMemo.SelStart;
  LSelEnd := LSelStart + FGameMoveMemo.SelLength;
  LPos := LSelStart;
  for I := 0 to FNotation.VariationCount - 1 do
  begin
    if (Trim(FDisplayedPosition.PreviewMoves) <> '') and
      ((FNotation.VariationHits[I].BasePly <> BrowseBasePly) or
       (FNotation.VariationHits[I].MovesText <> FDisplayedPosition.PreviewMoves)) then
      Continue;
    if SelectionHitsRange(FNotation.VariationHits[I].Start,
      FNotation.VariationHits[I].Length) then
    begin
      if FNotation.VariationHits[I].NodeId > 0 then
      begin
        ClearHumanMoveSelection;
        ClearVariationExploration;
        if FNotation.VariationHits[I].BeforeMove then
          FDisplayedPosition.Cursor.SelectBefore(LGameTree, LGameTree.FindNodeById(FNotation.VariationHits[I].NodeId))
        else
          FDisplayedPosition.Cursor.Select(LGameTree, LGameTree.FindNodeById(FNotation.VariationHits[I].NodeId));
        RefreshDisplayFromGameTree(LGameTree, False);
      end
      else if Trim(FNotation.VariationHits[I].MovesText) <> '' then
        ApplyAnnotatorVariationBrowsePly(FNotation.VariationHits[I].BasePly,
          FNotation.VariationHits[I].VariationPly, FNotation.VariationHits[I].MovesText,
          LGameTree)
;
      HighlightGameMoveTextSelection(True, LGameTree);
      Result := True;
      Exit;
    end;
  end;

  if Trim(FDisplayedPosition.PreviewMoves) <> '' then
  begin
    Result := True;
    Exit;
  end;

  for I := 0 to FNotation.MoveCount - 1 do
    if SelectionHitsRange(FNotation.MoveRanges[I].Start, FNotation.MoveRanges[I].Length) then
    begin
      ApplyGameBrowsePly(I + 1);
      HighlightGameMoveTextSelection(True, LGameTree);
      Result := True;
      Exit;
    end;

  if FNotation.MoveCount > 0 then
  begin
    LFirstMoveStart := FNotation.MoveRanges[0].Start;
    if LPos < LFirstMoveStart then
    begin
      ApplyGameBrowsePly(0);
      HighlightGameMoveTextSelection(True, LGameTree);
      Result := True;
    end;
  end;
end;

procedure TMainForm.HideMoveAnnotationsClick(Sender: TObject);
var
  LGameTree: TGameTree;
begin
  LGameTree := ActiveGameTree;
  FHideMoveAnnotations := not FHideMoveAnnotations;
  if FHideMoveAnnotationsMenuItem <> nil then
    FHideMoveAnnotationsMenuItem.Checked := FHideMoveAnnotations;
  RebuildGameMoveLabels(LGameTree);
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
var
  Tree: TGameTree;
  Node: TGameTreePlyNode;
begin
  Tree := ActiveGameTree;
  if (Tree = nil) or (Tree.GameTreeId <> FGameTreeViewTreeId) then Exit;
  Node := Tree.FindNodeById(SelectedGameTreeNodeId(FGameTreeView));
  if Node = nil then Exit;
  FGameTreeBrowseMode := True;
  ClearHumanMoveSelection;
  ClearVariationExploration;
  FDisplayedPosition.Cursor.Select(Tree, Node);
  RefreshDisplayFromGameTree(Tree, False);
  if Visible and CanFocus and (FGameTreeView <> nil) and
    FGameTreeView.CanFocus then FGameTreeView.SetFocus;
end;

procedure TMainForm.GameTreeViewKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Tree: TGameTree;
  WasEscape: Boolean;
begin
  if not (Key in [VK_ESCAPE, VK_LEFT, VK_RIGHT]) then Exit;
  WasEscape := Key = VK_ESCAPE;
  if WasEscape then FGameTreeBrowseMode := False;
  GameMoveBrowseKeyDown(Sender, Key, Shift);
  Tree := ActiveGameTree;
  if (Tree = nil) or (FGameTreeView = nil) then Exit;
  if WasEscape then UpdateGameTreeView(Tree);
  SyncGameTreeViewSelection;
end;

procedure TMainForm.CopyGameTreePdnClick(Sender: TObject);
var
  LGameTree: TGameTree;
  LOptions: TGameTreePdnRenderOptions;
begin
  LGameTree := ActiveGameTree;
  if LGameTree = nil then
    Exit;
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
    FGameTreeForm.Name := 'GameTreeWindow';
    FGameTreeForm.Caption := 'Game tree';
    FGameTreeForm.Position := poDesigned;
    FGameTreeForm.Width := 520;
    FGameTreeForm.Height := 640;
    FGameTreeForm.Constraints.MinWidth := 320;
    FGameTreeForm.Constraints.MinHeight := 360;
    FGameTreeForm.OnClose := @GameTreeFormClose;
    CenterFormOnLaptopPanel(FGameTreeForm, 0);

    FGameTreeView := TTreeView.Create(FGameTreeForm);
    FGameTreeView.Name := 'GameTreeNodes';
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
  {$IFNDEF GWDGUI_NONINTERACTIVE_TEST}
  FGameTreeForm.Show;
  FGameTreeForm.BringToFront;
  {$ENDIF}
end;

procedure TMainForm.HighlightGameMoveTextSelection(AFocusMemo: Boolean;
  AGameTree: TGameTree);
var
  I: Integer;
begin
  if FGameMoveMemo = nil then
    Exit;
  if Trim(FDisplayedPosition.PreviewMoves) <> '' then
  begin
    for I := 0 to FNotation.VariationCount - 1 do
      if (FNotation.VariationHits[I].BasePly = BrowseBasePly) and
        (FNotation.VariationHits[I].MovesText = FDisplayedPosition.PreviewMoves) and
        (FNotation.VariationHits[I].VariationPly = BrowseVariationPly) then
      begin
        FGameMoveMemo.SelStart := FNotation.VariationHits[I].Start;
        FGameMoveMemo.SelLength := FNotation.VariationHits[I].Length;
        if AFocusMemo and Visible and CanFocus and FGameMoveMemo.CanFocus then
          FGameMoveMemo.SetFocus;
        Exit;
      end;
  end;
  for I := 0 to FNotation.VariationCount - 1 do
    if (FNotation.VariationHits[I].NodeId = FDisplayedPosition.Cursor.NodeId) and
      (FNotation.VariationHits[I].NodeId > 0) and not FNotation.VariationHits[I].BeforeMove then
    begin
      FGameMoveMemo.SelStart := FNotation.VariationHits[I].Start;
      FGameMoveMemo.SelLength := FNotation.VariationHits[I].Length;
      if AFocusMemo and Visible and CanFocus and FGameMoveMemo.CanFocus then
        FGameMoveMemo.SetFocus;
      Exit;
    end;
  if (BrowseBasePly > 0) and (BrowseBasePly <= FNotation.MoveCount) then
  begin
    FGameMoveMemo.SelStart := FNotation.MoveRanges[BrowseBasePly - 1].Start;
    FGameMoveMemo.SelLength := FNotation.MoveRanges[BrowseBasePly - 1].Length;
  end;
  if AFocusMemo and Visible and CanFocus and FGameMoveMemo.CanFocus then
    FGameMoveMemo.SetFocus;
end;

procedure TMainForm.GameMoveBrowseKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  Tree: TGameTree;
  Ply, Count: Integer;
begin
  Tree := ActiveGameTree;
  if Key = VK_ESCAPE then
    ExitGameBrowseMode
  else if Key in [VK_LEFT, VK_RIGHT] then
  begin
    if FDisplayedPosition.PreviewMoves <> '' then
    begin
      Count := CurrentVariationMoveCount(Tree);
      Ply := FDisplayedPosition.PreviewPly;
      if Key = VK_LEFT then Dec(Ply) else Inc(Ply);
      if Ply < 0 then Ply := Count;
      if Ply > Count then Ply := 0;
      ApplyAnnotatorVariationBrowsePly(BrowseBasePly, Ply,
        FDisplayedPosition.PreviewMoves, Tree);
    end
    else
    begin
      ClearHumanMoveSelection;
      if Key = VK_LEFT then FDisplayedPosition.Cursor.StepLeft(Tree)
      else FDisplayedPosition.Cursor.StepRight(Tree);
      RefreshDisplayFromGameTree(Tree, False);
    end;
    HighlightGameMoveTextSelection(True, Tree);
  end
  else Exit;
  Key := 0;
end;

procedure TMainForm.MainFormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key = VK_ESCAPE) and (Shift = []) then
  begin
    if FAutoPlayActive then
    begin
      StopAutoPlay;
      if Trim(FDisplayedPosition.PreviewMoves) <> '' then
        HighlightGameMoveTextSelection(True, ActiveGameTree);
    end
    else
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
  LFen: string;
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
      if TryGetDisplayedBoardFen(ActiveGameTree, LFen) then
        FDatabaseForm.SetSearchFEN(LFen);
      FLastDatabaseSearchFEN := '';
      ShowFormCenteredOnOwner(FDatabaseForm, Self);
      UpdateDatabaseSearchPositionFromTree(ActiveGameTree);
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
  LFen: string;
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
      if TryGetDisplayedBoardFen(ActiveGameTree, LFen) then
        FDatabaseForm.SetSearchFEN(LFen);
      FLastDatabaseSearchFEN := '';
      ShowFormCenteredOnOwner(FDatabaseForm, Self);
      UpdateDatabaseSearchPositionFromTree(ActiveGameTree);
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

procedure TMainForm.PdnGameSelected(Sender: TObject; AGame: TPdnGame);
begin
  if ConfirmReplaceStandaloneGame then
    LoadPdnGameToDisplay(AGame);
end;

procedure TMainForm.AppendRunningGameToPdn(AGame: TRunningGame;
  const AFileName, AEventName: string);
var
  LPdnText: string;
begin
  if (AGame = nil) or (Trim(AFileName) = '') then
    Exit;

  LPdnText := RunningGameTreePdnText(AGame, AEventName);
  if Trim(LPdnText) <> '' then
    AppendPdnTextToFile(AFileName, LPdnText);
end;

function TMainForm.SaveCurrentGameWithDialog: Boolean;
var
  Dialog: TSaveDialog;
  LPdnText: string;
  RunningGame: TRunningGame;
begin
  Result := False;
  RunningGame := SelectedDisplayedGame;
  if RunningGame <> nil then
    LPdnText := RunningGameTreePdnText(RunningGame,
      EventNameForTree(RunningGame.GameTree))
  else
    LPdnText := CurrentGameTreePdnText(EventNameForTree(FGameTree));
  Dialog := TSaveDialog.Create(Self);
  try
    Dialog.Title := 'Save PDN';
    Dialog.Filter := 'PDN files (*.pdn)|*.pdn|All files (*)|*';
    Dialog.DefaultExt := 'pdn';
    Dialog.Options := Dialog.Options + [ofPathMustExist, ofEnableSizing];
    if not Dialog.Execute then
      Exit;

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
    UpdateDatabaseSearchPositionFromTree(ActiveGameTree);
  end;
end;

procedure TMainForm.GameSetupAccepted(Sender: TObject; const ASetup: TGameSetup);
begin
  StartGameFromSetup(ASetup);
end;

function TMainForm.StartGameFromSetup(const ASetup: TGameSetup;
  const ATitlePrefix: string): TRunningGame;
var
  LBoard: TDraughtsBoard;
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
  SetDisplayedTreeTracking('', '', '', 0, -1);
  FDisplayedPosition.Cursor.Follow;
  FGameLogMemo.Clear;
  FGameLogMemoGameId := -1;
  FGameLogMemoLineCount := -1;
  InitializeRunningGameTree(Result);
  LBoard := TDraughtsBoard.Create;
  try
    LBoard.LoadFromFEN(ASetup.StartingFEN);
    ClearDisplayedPvCache(LBoard, 0);
  finally
    LBoard.Free;
  end;
  FBoardControl.Board := FBoard;
  FGameActive := True;
  RefreshDisplayFromGameTree(Result.GameTree, True);

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
    LGame.AddReservationKeysTo(AKeys);
  end;
end;

procedure TMainForm.MarkGameStopped(AGame: TRunningGame; const AReason: string);
begin
  if AGame = nil then
    Exit;

  AGame.RequestStop(AReason);
  UpdateRunningGameTreeFromSnapshot(AGame);
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
  var
    LNode: TGameTreePlyNode;
    LNodeId: Int64;
  begin
    if (AMessage = nil) or (AMessage.Snapshot = nil) then
      Exit;

    if AnalyzerSnapshotIsTransient(AMessage.Snapshot) then
    begin
      if AMessage.Snapshot.BaseBoard.PositionKey <>
        FAnalyzerPvBaseBoard.PositionKey then
        Exit;
      SetAnalyzerPvBase(AMessage.Snapshot.BaseBoard,
        AMessage.Snapshot.BasePly);
      if (not AMessage.Snapshot.GameTreeOnly) and
        (FAnalyzerPvBrowser <> nil) then
        FAnalyzerPvBrowser.SetSnapshot(AMessage.Snapshot,
          StartingFenForTree(ActiveGameTree));
      Exit;
    end;

    LGameTree := PublishAnalyzerSnapshotToGameTree(AMessage.Snapshot);
    if LGameTree = nil then
      Exit;
    if not TryResolveAnalyzerSnapshotNode(LGameTree, AMessage.Snapshot,
      LNode) then
      Exit;
    LNodeId := LNode.NodeId;
    SetAnalyzerPvBaseFromTree(LGameTree, LNodeId,
      AMessage.Snapshot.BasePly, AMessage.Snapshot.BaseBoard);
    if (not AMessage.Snapshot.GameTreeOnly) and
      (FAnalyzerPvBrowser <> nil) then
      RefreshAnalyzerPvBrowserFromTree(LGameTree, LNodeId,
        AMessage.Snapshot.BasePly);
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

    LGameTree := PublishRunnerSnapshotToGameTree(LGame, AMessage.Snapshot);
    if LGameTree = nil then
      Exit;
    LGame.MarkRunningIfStarting;
    if LGame.IsStopOrRemoveRequested and
      (StateForTree(LGameTree) in [gosWaiting, gosRunning, gosError]) then
    begin
      LGame.MarkSnapshotStopped(LGame.StopReason);
      UpdateRunningGameTreeFromSnapshot(LGame);
      LGameTree := LGame.GameTree;
    end;
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

  ProcessQueuedGameTreeCommands;
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
          if FAutoPlayActive and
            (FAnalyzerRunner = TAnalyzerFinishedGuiMessage(EventObject).Runner) then
            StopAutoPlay('annotator closed');
          CancelAnalyzerSearch;
          if FAnalyzerRunner = TAnalyzerFinishedGuiMessage(EventObject).Runner then
            FreeAndNil(FAnalyzerRunner);
          FAnalyzerEngineKey := '';
          UpdateAutoPlayButtonState;
          InvalidateAnalyzerPositionSignature;
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
            LGame.MarkFinished;
            if RemoveAfterFinish then
              RemoveGame(LGame)
            else if not FClosing then
            begin
              UpdateGameListItem(LGame);
              if SelectedGame = LGame then
                RefreshDisplayFromGameTree(LGame.GameTree, False);
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
    ProcessQueuedGameTreeCommands;
  finally
    FlushPendingAnalyzerSnapshots;
    FlushPendingRunnerSnapshots;
    ProcessQueuedGameTreeCommands;
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
    FTournamentDialog.OnSelectGame := @TournamentSelectGame;
    FTournamentDialog.OnStartGame := @TournamentStartGame;
  end;
  ShowFormCenteredOnOwner(FTournamentDialog, Self);
end;

procedure TMainForm.TournamentSelectGame(Sender: TObject; AGame: TObject);
var
  LIndex: Integer;
  LRunningGame: TRunningGame;
begin
  if not (AGame is TRunningGame) then
    Exit;

  LRunningGame := TRunningGame(AGame);
  LIndex := FGamesListBox.Items.IndexOfObject(LRunningGame);
  if LIndex < 0 then
    Exit;

  FGamesListBox.ItemIndex := LIndex;
  ApplyGameToDisplay(LRunningGame);
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
    AGame.RequestRemoval;
    if not FClosing then
      UpdateGameListItem(AGame);
    Exit;
  end;

  LIndex := FGamesListBox.Items.IndexOfObject(AGame);
  if (FTournamentDialog <> nil) and AGame.IsTournamentGame then
  begin
    FTournamentDialog.GameStopped(AGame);
    FTournamentDialog.GameRemoved(AGame);
  end;
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
  LPlyCount: Integer;
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
    LGame.RequestRemoval;
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
        LPlyCount := LGame.MainlineCount;
        if PendingText <> '' then
          PendingText += '; ';
        PendingText += '#' + IntToStr(LGame.Id) + ' ' + LGame.Title +
          ' [lifecycle=' + RunningGameLifecycleToString(LGame.Lifecycle) +
          ', state=' + OrchestratorStateToString(LGame.State) +
          ', plies=' + IntToStr(LPlyCount) +
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
  LGameTree: TGameTree;
begin
  LLineIndex := FLegalMovesMemo.CaretPos.Y;
  if (LLineIndex < 0) or (LLineIndex >= FLegalMovesMemo.Lines.Count) then
    Exit;

  LMove := Trim(FLegalMovesMemo.Lines[LLineIndex]);
  LGameTree := ActiveGameTree;
  LBoard := TDraughtsBoard.Create;
  try
    if (not TryBuildDisplayedBoard(LGameTree, LBoard)) or
      (not LBoard.IsLegalMove(LMove)) then
      Exit;
  finally
    LBoard.Free;
  end;

  PlayHumanMove(LMove);
end;

procedure TMainForm.UpdateClockLabels(AGameTree: TGameTree; const AWhiteName,
  ABlackName: string);
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

  ClockValuesForTree(AGameTree, LWhiteRemainingSeconds,
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

function TMainForm.DisplayedBoardInfo(AGameTree: TGameTree;
  AGame: TRunningGame): TDisplayedBoardInfo;
begin
  if (AGameTree = nil) and (AGame <> nil) then
    AGameTree := AGame.GameTree;

  if AGameTree <> nil then
  begin
    Result.WhiteName := PlayerNameOrFallback(AGameTree.WhiteName, 'White');
    Result.BlackName := PlayerNameOrFallback(AGameTree.BlackName, 'Black');
    Result.ResultText := PlayerNameOrFallback(AGameTree.ResultText, '*');
    Result.StartingFEN := AGameTree.StartingFEN;
    Exit;
  end;

  Result.WhiteName := WhiteNameForTree(FGameTree);
  Result.BlackName := BlackNameForTree(FGameTree);
  Result.ResultText := ResultForTree(FGameTree);
  Result.StartingFEN := StartingFenForTree(FGameTree);
end;

procedure TMainForm.UpdateBoardInfo;
var
  LGame: TRunningGame;
  LInfo: TDisplayedBoardInfo;
  LGameTree: TGameTree;
begin
  LGameTree := ActiveGameTree;
  LGame := SelectedDisplayedGame;
  LInfo := DisplayedBoardInfo(LGameTree, LGame);
  if FDisplayBoardFailed then Exit;

  UpdateAutoPlayButtonState;

  UpdateClockLabels(LGameTree, LInfo.WhiteName, LInfo.BlackName);

  if FWhitePlayerEdit <> nil then
    FWhitePlayerEdit.Text := LInfo.WhiteName;
  if FBlackPlayerEdit <> nil then
    FBlackPlayerEdit.Text := LInfo.BlackName;
  if FResultEdit <> nil then
    FResultEdit.Text := LInfo.ResultText;
  if FFenEdit <> nil then
    FFenEdit.Text := LInfo.StartingFEN;

  UpdateBoardHighlights(LGameTree);

  UpdateLegalMovesFromTree(LGameTree);
  RestartAnalyzer(LGameTree);
  RestartMctsAnnotator(LGameTree);

  UpdateGameLogMemo;

  RefreshMainPvBrowserFromTree(LGameTree, LInfo.StartingFEN);
  HighlightGameMoveTextSelection(False, LGameTree);
  if FBoardControl <> nil then
    FBoardControl.Invalidate;
  UpdateDatabaseSearchPositionFromTree(LGameTree);
end;

procedure TMainForm.UpdateAutoPlayButtonState;
var
  LGameTree: TGameTree;
begin
  if FAutoPlayButton = nil then
    Exit;
  if FAutoPlayActive then
  begin
    FAutoPlayButton.Caption := 'Auto Playing';
    FAutoPlayButton.Enabled := False;
    Exit;
  end;
  FAutoPlayButton.Caption := 'Auto Play';
  LGameTree := ActiveGameTree;
  FAutoPlayButton.Enabled := (FAnalyzerRunner <> nil) and
    (Trim(FAnalyzerEngineKey) <> '') and (LGameTree <> nil) and
    (StateForTree(LGameTree) = gosStopped);
end;

procedure TMainForm.RefreshDisplayFromGameTree(AGameTree: TGameTree;
  AForceViews: Boolean);
var
  LAnnotationsText: string;
  LGame: TRunningGame;
  LMainlineCount: Integer;
  LMovesText: string;
begin
  if (AGameTree = nil) or (AGameTree <> ActiveGameTree) then
    Exit;

  FDisplayedPosition.BeginRefresh(AGameTree);
  try
  LGame := SelectedDisplayedGame;

  LMovesText := GameTreeMainlineMovesText(AGameTree);
  LAnnotationsText := GameTreeScoreAnnotationsText(AGameTree);
  FDisplayedMovesSignature := LMovesText;
  FDisplayedAnnotationsSignature := LAnnotationsText;
  FStartingFEN := StartingFenForTree(AGameTree);
  FGameResult := ResultForTree(AGameTree);
  FGameState := StateForTree(AGameTree);
  UpdateDisplayedPvCacheFromTree(AGameTree);

  UpdateBoardFromBrowseState(AGameTree);
  RefreshDisplayedGameTreeViews(AGameTree, AForceViews);
  UpdateBoardInfo;
  SyncGameTreeViewSelection;
  if LGame <> nil then
    UpdateGameListItem(LGame);
  finally
    FDisplayedPosition.EndRefresh;
  end;
end;

{$IFDEF GWDGUI_NONINTERACTIVE_TEST}
function TMainForm.GetLastDisplayReplayCount: Integer;
begin
  Result := FDisplayedPosition.ReplayBuildCount;
end;
{$ENDIF}

function TMainForm.TryGetDisplayedBoardFen(AGameTree: TGameTree;
  out AFen: string): Boolean;
var
  LBoard: TDraughtsBoard;
begin
  Result := False;
  AFen := '';
  LBoard := TDraughtsBoard.Create;
  try
    if not TryBuildDisplayedBoard(AGameTree, LBoard) then
      Exit;
    AFen := LBoard.CurrentFEN;
    Result := True;
  finally
    LBoard.Free;
  end;
end;

procedure TMainForm.UpdateDatabaseSearchPositionFromTree(AGameTree: TGameTree);
var
  LFen: string;
begin
  if not TryGetDisplayedBoardFen(AGameTree, LFen) then
    Exit;
  if (not FSearchPositionInDatabase) or (FDatabaseForm = nil) or
    (not FDatabaseForm.Visible) then
    Exit;
  if LFen = FLastDatabaseSearchFEN then
    Exit;
  FLastDatabaseSearchFEN := LFen;
  FDatabaseForm.SetSearchFEN(LFen);
  FDatabaseForm.SearchCurrentPosition;
end;

procedure TMainForm.UpdateScoreHistory(AGameTree: TGameTree);
var
  LAnnotationsText: string;
  LGameTree: TGameTree;
  LMoveCount: Integer;
  LPly: Integer;
  LSignature: string;
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

  LPly := BrowseBasePly;
  if LPly < 0 then
    LPly := LMoveCount;
  LSignature := IntToStr(LGameTree.GameTreeId) + #10 +
    IntToStr(LMoveCount) + #10 +
    IntToStr(LPly) + #10 +
    LStartingFEN + #10 +
    LAnnotationsText + #10 +
    FormatFloat('0.000000', FPreferences.EvaluationMaxScore) + #10 +
    IntToStr(Ord(FPreferences.EvaluationScale));
  if FDisplayedScoreHistorySignature = LSignature then
    Exit;
  FDisplayedScoreHistorySignature := LSignature;

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
  LLabelSignature: string;
  LOptions: TGameTreePdnRenderOptions;
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

  UpdateScoreHistory(AGameTree);
  LOptions := CurrentFilteredGameTreePdnOptions;
  LLabelSignature := GameTreeMoveLabelsSignature(AGameTree, LOptions);
  if FNotation.Signature <> LLabelSignature then
    RebuildGameMoveLabels(AGameTree);
  if (not AForce) and (FDisplayedGameTreeId = LGameTreeId) and
    (FDisplayedGameTreeRevision = LRevision) and
    (FNotation.Signature = LLabelSignature) then
    Exit;

  RefreshVisibleGameTreeView(AGameTree);
  FDisplayedGameTreeId := LGameTreeId;
  FDisplayedGameTreeRevision := LRevision;
end;

procedure TMainForm.SyncGameTreeViewSelection;
var
  Tree: TGameTree;
  Node: TGameTreePlyNode;
  I: Integer;
begin
  Tree := ActiveGameTree;
  if (Tree = nil) or (FGameTreeView = nil) or
    (Tree.GameTreeId <> FGameTreeViewTreeId) then Exit;
  Node := FDisplayedPosition.Cursor.Resolve(Tree);
  if Node = nil then Exit;
  for I := 0 to FGameTreeView.Items.Count - 1 do
    if Int64(PtrUInt(FGameTreeView.Items[I].Data)) = Node.NodeId then
    begin
      FGameTreeView.Selected := FGameTreeView.Items[I];
      Exit;
    end;
end;

procedure TMainForm.UpdateGameTreeView(AGameTree: TGameTree);
begin
  if (FGameTreeView = nil) or (AGameTree = nil) then
    Exit;

  PopulateGameTreeView(FGameTreeView, AGameTree);
  FGameTreeViewTreeId := AGameTree.GameTreeId;
  SyncGameTreeViewSelection;
end;

procedure TMainForm.UpdateGameListItem(AGame: TRunningGame);
var
  I: Integer;
  LBaseTitle: string;
  LBlackName: string;
  LCaption: string;
  LPlyCount: Integer;
  LResultText: string;
  LState: TGameOrchestratorState;
  LWhiteName: string;
begin
  if (AGame = nil) or (FGamesListBox = nil) then
    Exit;

  LWhiteName := AGame.WhiteNameText;
  LBlackName := AGame.BlackNameText;
  LResultText := AGame.ResultText;
  LState := AGame.State;
  LPlyCount := AGame.MainlineCount;
  LBaseTitle := AGame.Title;
  if Pos(' vs ', LBaseTitle) = 0 then
    LBaseTitle := LBaseTitle + ' ' + LWhiteName + ' vs ' + LBlackName;

  if LState = gosGameOver then
    LCaption := LBaseTitle + ' - ' + LResultText
  else
    LCaption := LBaseTitle + ' - ' +
      OrchestratorStateToString(LState);
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
  LCaption := LCaption + ' - ' + IntToStr(LPlyCount) + ' plies';
  if AGame.ListCaptionMatches(LCaption) then
    Exit;
  for I := 0 to FGamesListBox.Items.Count - 1 do
    if FGamesListBox.Items.Objects[I] = AGame then
    begin
      FGamesListBox.Items[I] := LCaption;
      FGamesListBox.Items.Objects[I] := AGame;
      AGame.UpdateListCaption(LCaption);
      Exit;
    end;
end;

procedure TMainForm.UpdateLegalMovesFromTree(AGameTree: TGameTree);
var
  LBoard: TDraughtsBoard;
  LHasBoard: Boolean;
begin
  LBoard := TDraughtsBoard.Create;
  FLegalMovesMemo.Lines.BeginUpdate;
  try
    LHasBoard := TryBuildDisplayedBoard(AGameTree, LBoard);
    FLegalMovesMemo.Clear;
    if (not LHasBoard) or (LBoard.LegalMoveCount = 0) then
      FLegalMovesMemo.Lines.Add('(none)')
    else
      LBoard.CopyLegalMovesTo(FLegalMovesMemo.Lines);
  finally
    FLegalMovesMemo.Lines.EndUpdate;
    LBoard.Free;
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


end.
