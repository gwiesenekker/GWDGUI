unit uMainForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, Clipbrd, Controls, Dialogs, ExtCtrls, Forms, Graphics, LCLType,
  Menus, StdCtrls, SysUtils, uBoardControl, uDraughtsBoard, uEnginesDialog,
  uGameOrchestrator, uGameRunnerThread, uGameSetupForm,
  uEngineRegistry, uPdn, uPdnOpenDialog, uThreadMessageQueue,
  uTournamentDialog, uPvBrowser, uPvSnapshot, uAnalyzerRunnerThread,
  uGuiDialogs, uDatabaseForm, uPositionSetupForm, uPreferences,
  uPreferencesForm, uScoreHistoryControl, uScoreHistoryForm;

type
  TIntArray = array of Integer;
  TPvHintSource = (phsMain, phsAnalyzer);

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

  TAnalyzerFinishedGuiMessage = class(TThreadMessage)
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
    FAnnotatorAnnotationsText: string;
    FBlackEngineKey: string;
    FBlackPlayerKind: TPlayerKind;
    FPaused: Boolean;
    FReservationKeys: TStringList;
    FReleasingRunner: Boolean;
    FRunner: TGameRunnerThread;
    FLifecycle: TRunningGameLifecycle;
    FShowStdout: Boolean;
    FSnapshot: TGameRunnerSnapshot;
    FStopReason: string;
    FTitle: string;
    FWhiteEngineKey: string;
    FWhiteDisplayName: string;
    FWhitePlayerKind: TPlayerKind;
    FBlackDisplayName: string;
    procedure ReleaseRunner;
    procedure WaitForRunnerFinished;
  public
    constructor Create(AId: Integer; const ATitle: string; ARunner: TGameRunnerThread;
      AWhitePlayerKind, ABlackPlayerKind: TPlayerKind; const AWhiteEngineKey,
      ABlackEngineKey, AWhiteDisplayName, ABlackDisplayName: string;
      AReservationKeys: TStrings);
    destructor Destroy; override;

    function IsEngineReservationActive: Boolean;
    function IsHumanToMove: Boolean;
    function ReservationSummary: string;
    property Id: Integer read FId;
    property AnnotatorAnnotationsText: string read FAnnotatorAnnotationsText
      write FAnnotatorAnnotationsText;
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
    FGameCommentLengths: TIntArray;
    FGameCommentStarts: TIntArray;
    FGameMoveLengths: TIntArray;
    FGameMoveMemo: TMemo;
    FGameMoveStarts: TIntArray;
    FHighlightedGameMovePly: Integer;
    FHideMoveAnnotations: Boolean;
    FHideMoveAnnotationsMenuItem: TMenuItem;
    FHumanMoveChoices: TStringList;
    FHumanMoveSourceSquare: Integer;
    FLegalMovesMemo: TMemo;
    FMiniBoard: TDraughtsBoard;
    FMiniBoardControl: TDraughtsBoardControl;
    FMiniBoardForm: TForm;
    FMoveAnnotationsText: string;
    FMovesPlayedText: string;
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
    FResultEdit: TEdit;
    FScoreHistoryControl: TScoreHistoryControl;
    FScoreHistoryForm: TScoreHistoryForm;
    FSetupForm: TGameSetupForm;
    FShowStdoutMenuItem: TMenuItem;
    FStartingFEN: string;
    FStandaloneBlackPlayerName: string;
    FStandaloneEventName: string;
    FStandaloneWhitePlayerName: string;
    FTournamentDialog: TTournamentDialog;
    FViewedGameId: Integer;
    FWhiteClockLabel: TLabel;
    FWhitePlayerEdit: TEdit;
    FWhiteRemainingSeconds: Double;
    FWhiteUsedSeconds: Double;
    function ActiveBoard: TDraughtsBoard;
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
    procedure AnalyzerPvBoardChanged(Sender: TObject);
    procedure AnalyzerPopupPopup(Sender: TObject);
    procedure AnalyzerSnapshot(Sender: TObject; ASnapshot: TPvSnapshot);
    procedure ApplyAnalyzerScoreAnnotation(ASnapshot: TPvSnapshot);
    procedure BuildAnnotatedMoveText(const AMovesText, AAnnotationsText,
      AStartingFEN: string; out AText: string; var AMoveStarts,
      AMoveLengths, ACommentStarts, ACommentLengths: TIntArray;
      APlyOffset: Integer = 0; AHideAnnotations: Boolean = False);
    procedure BuildMoveText(const AMovesText, AStartingFEN: string;
      out AText: string; var AStarts, ALengths: TIntArray;
      APlyOffset: Integer = 0);
    procedure BoardMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    function CanAcceptHumanBoardMove: Boolean;
    procedure ClearHumanMoveSelection;
    procedure CloseQueryHandler(Sender: TObject; var CanClose: Boolean);
    procedure CloseAnalyzerClick(Sender: TObject);
    procedure CopyBoardFenClick(Sender: TObject);
    procedure CreateDatabaseClick(Sender: TObject);
    procedure StopSelectedGame(Sender: TObject);
    function CurrentMoveCount: Integer;
    function DisplayedMovesText: string;
    function FormatClock(ASeconds: Double): string;
    function GameLogLineVisible(const ALine: string; AGame: TRunningGame): Boolean;
    function GameTitleEngineName(AEngine: TExternalEngineDefinition): string;
    function PlayerSetupDisplayName(AKind: TPlayerKind;
      AEngine: TExternalEngineDefinition): string;
    function FindHumanMoveToTarget(ATargetSquare: Integer; out AMove: string): Boolean;
    procedure GameMoveBrowseClick(Sender: TObject);
    procedure GameMoveBrowseKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure HideMoveAnnotationsClick(Sender: TObject);
    procedure HighlightGameMoveTextSelection(AFocusMemo: Boolean);
    procedure GameSetupAccepted(Sender: TObject; const ASetup: TGameSetup);
    procedure GamesPopupPopup(Sender: TObject);
    procedure GamesListBoxClick(Sender: TObject);
    procedure GuiEventTimerTick(Sender: TObject);
    procedure HandleAnalyzerLog(const AMessage: string);
    procedure HintSourceClick(Sender: TObject);
    procedure GameFinished(Sender: TObject);
    procedure GameSnapshot(Sender: TObject; ASnapshot: TGameRunnerSnapshot);
    procedure LegalMovesMemoClick(Sender: TObject);
    function LiveGameCount: Integer;
    procedure MainFormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure MiniBoardDblClick(Sender: TObject);
    procedure MiniBoardFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure MiniBoardPopoutClick(Sender: TObject);
    procedure PopoutBoardCopyFenClick(Sender: TObject);
    procedure PvBoardChanged(Sender: TObject);
    procedure NewGameClick(Sender: TObject);
    procedure OpenAnalyzerClick(Sender: TObject);
    procedure OpenDatabaseClick(Sender: TObject);
    procedure EnginesClick(Sender: TObject);
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
    procedure PlayHumanMove(const AMove: string);
    procedure RemoveGame(AGame: TRunningGame);
    procedure RestartAnalyzer;
    procedure SelectHumanMoveSource(ASourceSquare: Integer);
    procedure RebuildGameMoveLabels;
    procedure UpdateGameMoveHighlight;
    function SelectedGame: TRunningGame;
    procedure SavePdnClick(Sender: TObject);
    function SaveCurrentGameWithDialog: Boolean;
    procedure ScoreHistoryPopoutClick(Sender: TObject);
    procedure ScoreHistoryFormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure SetupPositionAccepted(Sender: TObject; const AFEN: string);
    procedure SetupPositionClick(Sender: TObject);
    procedure ShowStdoutClick(Sender: TObject);
    procedure StopAllGames;
    procedure ToggleBoardFlipped;
    procedure TournamentStartGame(Sender: TObject; const ASetup: TGameSetup;
      const ATitlePrefix: string; out AGame: TObject);
    procedure LoadStandaloneFen(const AFEN: string);
    procedure LoadPdnGameToDisplay(AGame: TPdnGame);
    function MergeAnnotatorAnnotations(const ABaseAnnotations,
      AAnnotatorAnnotations: string): string;
    function SetAnnotationScoreInText(const AAnnotationsText: string;
      APly: Integer; const AName, AScore: string): string;
    procedure UpdateBrowseInfo;
    procedure UpdateBoardInfo;
    procedure UpdateBoardFromBrowseState;
    procedure UpdateBoardHighlights;
    procedure UpdateClockLabels(const AWhiteName, ABlackName: string);
    procedure UpdateScoreHistory;
    procedure UpdateGameListItem(AGame: TRunningGame);
    procedure UpdateLegalMoves;
    procedure UpdateGameLogMemo;
    procedure UpdateMiniBoardFromBoard(ABoard: TDraughtsBoard);
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

constructor TAnalyzerFinishedGuiMessage.Create(ARunner: TAnalyzerRunnerThread);
begin
  inherited Create('analyzer-finished');
  FRunner := ARunner;
end;

constructor TRunningGame.Create(AId: Integer; const ATitle: string;
  ARunner: TGameRunnerThread; AWhitePlayerKind, ABlackPlayerKind: TPlayerKind;
  const AWhiteEngineKey, ABlackEngineKey, AWhiteDisplayName,
  ABlackDisplayName: string; AReservationKeys: TStrings);
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
  FSnapshot := TGameRunnerSnapshot.Create;
  FLifecycle := rglStarting;
end;

destructor TRunningGame.Destroy;
begin
  ReleaseRunner;
  FSnapshot.Free;
  FReservationKeys.Free;
  inherited Destroy;
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
  LGameHeaderPanel: TPanel;
  LPvBoardPanel: TPanel;
  LPvLabel: TLabel;
  LPvPanel: TPanel;
  LPvPopup: TPopupMenu;
  LPvSplitter: TSplitter;
  LPvTextPanel: TPanel;
  LPvTopPanel: TPanel;
  LAnalyzerBoardPanel: TPanel;
  LAnalyzerBoardPopup: TPopupMenu;
  LAnalyzerPanel: TPanel;
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
  FGameLogMemoGameId := -1;
  FGameLogMemoLineCount := -1;
  FHighlightedGameMovePly := -1;
  FHideMoveAnnotations := False;
  FPvHintSource := phsMain;
  FViewedGameId := -1;
  FGameLog := TStringList.Create;
  FHumanMoveChoices := TStringList.Create;
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
  LToolbar.BorderSpacing.Around := 6;

  { With alLeft on this widgetset, later-created buttons are placed further
    left, so create these in reverse visual order. }
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
  LBottomPanel.Height := 318;
  LBottomPanel.Constraints.MinHeight := 210;
  LBottomPanel.BevelOuter := bvNone;
  LBottomPanel.Color := clWindow;
  LBottomPanel.BorderSpacing.Left := 8;
  LBottomPanel.BorderSpacing.Right := 8;
  LBottomPanel.BorderSpacing.Bottom := 8;

  LAnalyzerPanel := TPanel.Create(Self);
  LAnalyzerPanel.Parent := LBottomPanel;
  LAnalyzerPanel.Align := alBottom;
  LAnalyzerPanel.Height := 130;
  LAnalyzerPanel.Constraints.MinHeight := 70;
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

  LAnalyzerBoardPanel := TPanel.Create(Self);
  LAnalyzerBoardPanel.Parent := LAnalyzerPanel;
  LAnalyzerBoardPanel.Align := alRight;
  LAnalyzerBoardPanel.Width := 112;
  LAnalyzerBoardPanel.BevelOuter := bvNone;
  LAnalyzerBoardPanel.BorderSpacing.Left := 8;
  LAnalyzerBoardPanel.BorderSpacing.Right := 8;

  LAnalyzerBoardPopup := TPopupMenu.Create(Self);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Pop out annotator mini-board';
  LMenuItem.OnClick := @AnalyzerMiniBoardPopoutClick;
  LAnalyzerBoardPopup.Items.Add(LMenuItem);

  FAnalyzerMiniBoardControl := TDraughtsBoardControl.Create(Self);
  FAnalyzerMiniBoardControl.Parent := LAnalyzerBoardPanel;
  FAnalyzerMiniBoardControl.Align := alClient;
  FAnalyzerMiniBoardControl.Board := FAnalyzerMiniBoard;
  FAnalyzerMiniBoardControl.ShowCoordinates := False;
  FAnalyzerMiniBoardControl.PopupMenu := LAnalyzerBoardPopup;
  FAnalyzerMiniBoardControl.OnDblClick := @AnalyzerMiniBoardDblClick;
  FAnalyzerMiniBoardControl.BoardFlipped := FBoardFlipped;

  LAnalyzerTextPanel := TPanel.Create(Self);
  LAnalyzerTextPanel.Parent := LAnalyzerPanel;
  LAnalyzerTextPanel.Align := alClient;
  LAnalyzerTextPanel.BevelOuter := bvNone;

  FAnalyzerPvMemo := TMemo.Create(Self);
  FAnalyzerPvMemo.Parent := LAnalyzerTextPanel;
  FAnalyzerPvMemo.Align := alTop;
  FAnalyzerPvMemo.Height := 52;
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
  FShowStdoutMenuItem := TMenuItem.Create(Self);
  FShowStdoutMenuItem.Caption := 'Show stdout';
  FShowStdoutMenuItem.AutoCheck := False;
  FShowStdoutMenuItem.OnClick := @ShowStdoutClick;
  LGamesPopup.Items.Add(FShowStdoutMenuItem);
  FPauseGameMenuItem := TMenuItem.Create(Self);
  FPauseGameMenuItem.Caption := 'Pause game';
  FPauseGameMenuItem.OnClick := @PauseGameClick;
  LGamesPopup.Items.Add(FPauseGameMenuItem);
  LMenuItem := TMenuItem.Create(Self);
  LMenuItem.Caption := 'Stop selected';
  LMenuItem.OnClick := @StopSelectedGame;
  LGamesPopup.Items.Add(LMenuItem);
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
  FHideMoveAnnotationsMenuItem := TMenuItem.Create(Self);
  FHideMoveAnnotationsMenuItem.Caption := 'Hide annotation';
  FHideMoveAnnotationsMenuItem.AutoCheck := False;
  FHideMoveAnnotationsMenuItem.OnClick := @HideMoveAnnotationsClick;
  LGameMovePopup.Items.Add(FHideMoveAnnotationsMenuItem);
  FGameMoveMemo.PopupMenu := LGameMovePopup;

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
  LPvTopPanel.Height := 88;
  LPvTopPanel.BevelOuter := bvNone;

  FScoreHistoryControl := TScoreHistoryControl.Create(Self);
  FScoreHistoryControl.Parent := LPvTopPanel;
  FScoreHistoryControl.Align := alTop;
  FScoreHistoryControl.Height := 62;
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
  FreeAndNil(FAnalyzerPvBrowser);
  FreeAndNil(FPvBrowser);
  FHumanMoveChoices.Free;
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
  if FDatabaseForm <> nil then
    FDatabaseForm.ApplyPreferences(FPreferences);
  UpdateScoreHistory;
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

  if not FGameActive then
    Exit(False);

  LGame := SelectedGame;
  Result := (LGame <> nil) and (LGame.Runner <> nil) and
    (LGame.Snapshot.State = gosRunning) and LGame.IsHumanToMove;
end;

procedure TMainForm.ClearHumanMoveSelection;
begin
  FHumanMoveSourceSquare := 0;
  if FHumanMoveChoices <> nil then
    FHumanMoveChoices.Clear;
  if FBoardControl <> nil then
    FBoardControl.ClearTargetSquares;
end;

procedure TMainForm.ToggleBoardFlipped;
begin
  FBoardFlipped := not FBoardFlipped;
  ClearHumanMoveSelection;
  ApplyBoardFlipped;
  if FGameActive then
    UpdateClockLabels(FWhitePlayerEdit.Text, FBlackPlayerEdit.Text);
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

procedure TMainForm.PlayHumanMove(const AMove: string);
var
  LBoard: TDraughtsBoard;
  LGame: TRunningGame;
  LMove: string;
begin
  LBoard := ActiveBoard;
  LMove := Trim(AMove);
  if (LBoard = nil) or (not LBoard.IsLegalMove(LMove)) then
    Exit;

  ClearHumanMoveSelection;
  if not FGameActive then
    Exit;

  LGame := SelectedGame;
  if (LGame <> nil) and (LGame.Runner <> nil) and
    (LGame.Snapshot.State = gosRunning) and LGame.IsHumanToMove then
    LGame.Runner.PostHumanMove(LMove);
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
  if not CanAcceptHumanBoardMove then
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

procedure TMainForm.HandleAnalyzerLog(const AMessage: string);
begin
  if FAnalyzerMemo = nil then
    Exit;
  FAnalyzerMemo.Lines.Add(AMessage);
  FAnalyzerMemo.SelStart := Length(FAnalyzerMemo.Text);
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

  UpdateBoardHighlights;
  if FBoardControl <> nil then
    FBoardControl.Invalidate;
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
    FAnalyzerLastPositionSignature := '';
    FAnalyzerRunner := TAnalyzerRunnerThread.Create(Engine, @AnalyzerLog,
      @AnalyzerSnapshot, @AnalyzerFinished);
    FAnalyzerRunner.Start;
    RestartAnalyzer;
  finally
    Engines.Free;
  end;
end;

procedure TMainForm.CloseAnalyzerClick(Sender: TObject);
begin
  if FAnalyzerRunner <> nil then
  begin
    if FAnalyzerMemo <> nil then
      FAnalyzerMemo.Lines.Add('Closing Annotator');
    FAnalyzerRunner.PostShutdown;
  end;
  FAnalyzerEngineKey := '';
  FAnalyzerLastPositionSignature := '';
  if FAnalyzerPvBrowser <> nil then
    FAnalyzerPvBrowser.Clear;
end;

procedure TMainForm.RestartAnalyzer;
var
  LDisplayedMoveCount: Integer;
  LDisplayedMoves: TStringList;
  LDisplayedMovesText: string;
  LTotalMoveCount: Integer;
  LTerminal: Boolean;
  Signature: string;
begin
  if FAnalyzerRunner = nil then
    Exit;

  LDisplayedMovesText := DisplayedMovesText;
  LDisplayedMoves := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(LDisplayedMovesText)),
      LDisplayedMoves);
    LDisplayedMoveCount := LDisplayedMoves.Count;
  finally
    LDisplayedMoves.Free;
  end;
  LTotalMoveCount := CurrentMoveCount;

  Signature := FStartingFEN + #10 + LDisplayedMovesText + #10 +
    IntToStr(Ord(FGameState));
  if Signature = FAnalyzerLastPositionSignature then
    Exit;
  FAnalyzerLastPositionSignature := Signature;

  FAnalyzerPvBaseBoard.AssignFrom(ActiveBoard);
  FAnalyzerPvBasePly := LDisplayedMoveCount;
  LTerminal := (ActiveBoard.LegalMoves.Count = 0) or
    ((FGameState = gosGameOver) and
      ((FGameBrowsePly < 0) or (LDisplayedMoveCount >= LTotalMoveCount)));
  if LTerminal and (FAnalyzerPvBrowser <> nil) then
    FAnalyzerPvBrowser.Clear;
  FAnalyzerRunner.PostAnalyze(FStartingFEN, LDisplayedMovesText,
    FAnalyzerPvBaseBoard, FAnalyzerPvBasePly, LTerminal);
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

  if Trim(FMovesPlayedText) <> '' then
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
  FMovesPlayedText := '';
  FMoveAnnotationsText := '';
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

procedure TextToMoveList(const AMovesText: string; AMoves: TStrings);
begin
  if AMoves = nil then
    Exit;
  AMoves.Clear;
  ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)), AMoves);
end;

function TMainForm.SetAnnotationScoreInText(const AAnnotationsText: string;
  APly: Integer; const AName, AScore: string): string;
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := AAnnotationsText;
    while Lines.Count < APly do
      Lines.Add('');
    if APly > 0 then
      Lines[APly - 1] := AnnotationWithScore(Lines[APly - 1], AName,
        AScore);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function TMainForm.MergeAnnotatorAnnotations(const ABaseAnnotations,
  AAnnotatorAnnotations: string): string;
var
  BaseLines: TStringList;
  I: Integer;
  AnnotatorLines: TStringList;
  AnnotatorScore: string;
begin
  BaseLines := TStringList.Create;
  AnnotatorLines := TStringList.Create;
  try
    BaseLines.Text := ABaseAnnotations;
    AnnotatorLines.Text := AAnnotatorAnnotations;
    while BaseLines.Count < AnnotatorLines.Count do
      BaseLines.Add('');
    for I := 0 to AnnotatorLines.Count - 1 do
    begin
      AnnotatorScore := ExtractAnnotationValue(AnnotatorLines[I],
        'annotator');
      if AnnotatorScore <> '' then
        BaseLines[I] := AnnotationWithScore(BaseLines[I], 'annotator',
          AnnotatorScore);
    end;
    Result := BaseLines.Text;
  finally
    AnnotatorLines.Free;
    BaseLines.Free;
  end;
end;

procedure TMainForm.ApplyAnalyzerScoreAnnotation(ASnapshot: TPvSnapshot);
var
  LGame: TRunningGame;
  LAnnotationsText: string;
begin
  if ASnapshot = nil then
    Exit;
  if Trim(ASnapshot.Score) = '' then
    Exit;
  if ASnapshot.BasePly <= 0 then
    Exit;
  if ASnapshot.BasePly > CurrentMoveCount then
    Exit;
  if ASnapshot.BaseBoard.PositionKey <> FBoard.PositionKey then
    Exit;

  LGame := SelectedGame;
  if (LGame <> nil) and FGameActive then
  begin
    LGame.AnnotatorAnnotationsText := SetAnnotationScoreInText(
      LGame.AnnotatorAnnotationsText, ASnapshot.BasePly, 'annotator',
      ASnapshot.Score);
    LAnnotationsText := MergeAnnotatorAnnotations(
      LGame.Snapshot.MoveAnnotationsText, LGame.AnnotatorAnnotationsText);
  end
  else
    LAnnotationsText := SetAnnotationScoreInText(FMoveAnnotationsText,
      ASnapshot.BasePly, 'annotator', ASnapshot.Score);

  if LAnnotationsText = FMoveAnnotationsText then
    Exit;
  FMoveAnnotationsText := LAnnotationsText;
  RebuildGameMoveLabels;
  UpdateScoreHistory;
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
    FMovesPlayedText := AGame.MovesText;
    FMoveAnnotationsText := AGame.MoveAnnotationsText;
    FStandaloneWhitePlayerName := PlayerNameOrFallback(AGame.WhiteName, 'White');
    FStandaloneBlackPlayerName := PlayerNameOrFallback(AGame.BlackName, 'Black');
    FStandaloneEventName := PlayerNameOrFallback(AGame.EventName, '?');
    FPrincipalVariation := '';
    FPrincipalVariationScore := '';
    FPrincipalVariationDepth := '';
    FPrincipalVariationTimeText := '';
    FGameBrowsePly := -1;
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

function MoveSegmentText(APly, ADisplayedIndex: Integer; const AMove: string;
  AStartingSide: TDraughtsSide): string;
var
  LMoveNumber: Integer;
  LSide: TDraughtsSide;
  LPlyFromWhiteStart: Integer;
begin
  LPlyFromWhiteStart := APly;
  if AStartingSide = dsBlack then
    Inc(LPlyFromWhiteStart);
  LMoveNumber := ((LPlyFromWhiteStart - 1) div 2) + 1;
  if ((AStartingSide = dsWhite) and Odd(APly)) or
    ((AStartingSide = dsBlack) and (not Odd(APly))) then
    LSide := dsWhite
  else
    LSide := dsBlack;

  if LSide = dsWhite then
    Result := IntToStr(LMoveNumber) + '.' + AMove
  else if ADisplayedIndex = 0 then
    Result := IntToStr(LMoveNumber) + '...' + AMove
  else
    Result := AMove;
end;

procedure TMainForm.BuildAnnotatedMoveText(const AMovesText,
  AAnnotationsText, AStartingFEN: string; out AText: string;
  var AMoveStarts, AMoveLengths, ACommentStarts, ACommentLengths: TIntArray;
  APlyOffset: Integer; AHideAnnotations: Boolean);
var
  I: Integer;
  LAnnotations: TStringList;
  LMoves: TStringList;
  LComment: string;
  LSegment: string;
  LStartingSide: TDraughtsSide;
begin
  AText := '';
  SetLength(AMoveStarts, 0);
  SetLength(AMoveLengths, 0);
  SetLength(ACommentStarts, 0);
  SetLength(ACommentLengths, 0);

  LMoves := TStringList.Create;
  LAnnotations := TStringList.Create;
  try
    TextToMoveList(AMovesText, LMoves);
    LAnnotations.Text := AAnnotationsText;
    if LMoves.Count = 0 then
    begin
      AText := '(none)';
      Exit;
    end;

    SetLength(AMoveStarts, LMoves.Count);
    SetLength(AMoveLengths, LMoves.Count);
    SetLength(ACommentStarts, LMoves.Count);
    SetLength(ACommentLengths, LMoves.Count);
    LStartingSide := FenSideToMove(AStartingFEN);
    for I := 0 to LMoves.Count - 1 do
    begin
      if AText <> '' then
        AText += ' ';
      LSegment := MoveSegmentText(APlyOffset + I + 1, I, LMoves[I],
        LStartingSide);
      AMoveStarts[I] := Length(AText);
      AMoveLengths[I] := Length(LSegment);
      AText += LSegment;

      LComment := '';
      if (not AHideAnnotations) and (I < LAnnotations.Count) then
        LComment := Trim(LAnnotations[I]);
      if LComment <> '' then
      begin
        LSegment := ' {' + LComment + '}';
        AText += LSegment;
        ACommentStarts[I] := Length(AText) - Length(LSegment);
        ACommentLengths[I] := Length(LSegment);
      end;
    end;
  finally
    LAnnotations.Free;
    LMoves.Free;
  end;
end;

procedure TMainForm.BuildMoveText(const AMovesText, AStartingFEN: string;
  out AText: string; var AStarts, ALengths: TIntArray; APlyOffset: Integer);
var
  I: Integer;
  LMoves: TStringList;
  LSegment: string;
  LStartingSide: TDraughtsSide;
begin
  AText := '';
  SetLength(AStarts, 0);
  SetLength(ALengths, 0);
  LMoves := TStringList.Create;
  try
    TextToMoveList(AMovesText, LMoves);
    if LMoves.Count = 0 then
    begin
      AText := '(none)';
      Exit;
    end;

    SetLength(AStarts, LMoves.Count);
    SetLength(ALengths, LMoves.Count);
    LStartingSide := FenSideToMove(AStartingFEN);
    for I := 0 to LMoves.Count - 1 do
    begin
      if AText <> '' then
        AText += ' ';
      LSegment := MoveSegmentText(APlyOffset + I + 1, I, LMoves[I],
        LStartingSide);
      AStarts[I] := Length(AText);
      ALengths[I] := Length(LSegment);
      AText += LSegment;
    end;
  finally
    LMoves.Free;
  end;
end;

function TMainForm.CurrentMoveCount: Integer;
var
  LMoves: TStringList;
begin
  LMoves := TStringList.Create;
  try
    TextToMoveList(FMovesPlayedText, LMoves);
    Result := LMoves.Count;
  finally
    LMoves.Free;
  end;
end;

function TMainForm.DisplayedMovesText: string;
var
  I: Integer;
  LMoves: TStringList;
  LPly: Integer;
begin
  Result := '';
  LMoves := TStringList.Create;
  try
    TextToMoveList(FMovesPlayedText, LMoves);
    LPly := FGameBrowsePly;
    if (LPly < 0) or (LPly > LMoves.Count) then
      LPly := LMoves.Count;
    for I := 0 to LPly - 1 do
    begin
      if Result <> '' then
        Result += ' ';
      Result += LMoves[I];
    end;
  finally
    LMoves.Free;
  end;
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

procedure TMainForm.RebuildGameMoveLabels;
var
  LText: string;
begin
  if FGameMoveMemo = nil then
    Exit;

  FGameMoveMemo.Lines.BeginUpdate;
  try
    BuildAnnotatedMoveText(FMovesPlayedText, FMoveAnnotationsText,
      FStartingFEN, LText, FGameMoveStarts, FGameMoveLengths,
      FGameCommentStarts, FGameCommentLengths, 0, FHideMoveAnnotations);
    FGameMoveMemo.Text := LText;
    FHighlightedGameMovePly := -2;
  finally
    FGameMoveMemo.Lines.EndUpdate;
  end;
  UpdateGameMoveHighlight;
end;

procedure TMainForm.UpdateGameMoveHighlight;
begin
  if FGameMoveMemo = nil then
    Exit;
  if Length(FGameMoveStarts) <> Length(FGameMoveLengths) then
  begin
    RebuildGameMoveLabels;
    Exit;
  end;
  if FHighlightedGameMovePly = FGameBrowsePly then
    Exit;
  if (FGameBrowsePly > 0) and (FGameBrowsePly <= Length(FGameMoveStarts)) then
  begin
    FGameMoveMemo.SelStart := FGameMoveStarts[FGameBrowsePly - 1];
    FGameMoveMemo.SelLength := FGameMoveLengths[FGameBrowsePly - 1];
  end
  else
  begin
    FGameMoveMemo.SelStart := 0;
    FGameMoveMemo.SelLength := 0;
  end;
  FHighlightedGameMovePly := FGameBrowsePly;
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

procedure TMainForm.UpdateBoardHighlights;
var
  LDisplayedGamePly: Integer;
  LGameMoves: TStringList;
  LPvBaseBoard: TDraughtsBoard;
  LPvHighlightsActive: Boolean;
  LPvMoves: TStringList;
  LPvText: string;
begin
  if FBoardControl = nil then
    Exit;

  LGameMoves := TStringList.Create;
  LPvMoves := TStringList.Create;
  try
    TextToMoveList(FMovesPlayedText, LGameMoves);
    if FPvHintSource = phsAnalyzer then
    begin
      LPvBaseBoard := FAnalyzerPvBaseBoard;
      if FAnalyzerPvBrowser <> nil then
        LPvText := FAnalyzerPvBrowser.PrincipalVariation
      else
        LPvText := '';
    end
    else
    begin
      LPvBaseBoard := FPvBaseBoard;
      LPvText := FPrincipalVariation;
    end;
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

procedure TMainForm.UpdateBoardFromBrowseState;
var
  I: Integer;
  LGameMoves: TStringList;
  LPly: Integer;
begin
  LGameMoves := TStringList.Create;
  try
    TextToMoveList(FMovesPlayedText, LGameMoves);
    FBoard.LoadFromFEN(FStartingFEN);

    LPly := FGameBrowsePly;
    if (LPly < 0) or (LPly > LGameMoves.Count) then
      LPly := LGameMoves.Count;
    for I := 0 to LPly - 1 do
      FBoard.PlayMove(LGameMoves[I], True, False);
  finally
    LGameMoves.Free;
  end;

  if FBoardControl <> nil then
    FBoardControl.Invalidate;
end;

procedure TMainForm.ApplyGameBrowsePly(APly: Integer);
var
  LMoveCount: Integer;
begin
  ClearHumanMoveSelection;
  LMoveCount := CurrentMoveCount;
  if APly < 0 then
    FGameBrowsePly := LMoveCount
  else if APly > LMoveCount then
    FGameBrowsePly := 0
  else
    FGameBrowsePly := APly;
  UpdateBoardFromBrowseState;
  UpdateBrowseInfo;
end;

procedure TMainForm.ApplyGameToDisplay(AGame: TRunningGame);
var
  I: Integer;
  LMoveCount: Integer;
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
    FMovesPlayedText := '';
    FMoveAnnotationsText := '';
    FStandaloneWhitePlayerName := 'White';
    FStandaloneBlackPlayerName := 'Black';
    FStandaloneEventName := '?';
    FGameBrowsePly := -1;
    FViewedGameId := -1;
    FGameLog.Clear;
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
  end;

  if FMovesPlayedText <> AGame.Snapshot.MovesPlayedText then
    ClearHumanMoveSelection;
  UpdateMiniBoardFromBoard(AGame.Snapshot.Board);
  FStartingFEN := AGame.Snapshot.StartingFEN;
  FMovesPlayedText := AGame.Snapshot.MovesPlayedText;
  FMoveAnnotationsText := MergeAnnotatorAnnotations(
    AGame.Snapshot.MoveAnnotationsText, AGame.AnnotatorAnnotationsText);
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
  FGameLog.Clear;
  for I := 0 to AGame.Snapshot.LogLines.Count - 1 do
    if GameLogLineVisible(AGame.Snapshot.LogLines[I], AGame) then
      FGameLog.Add(AGame.Snapshot.LogLines[I]);
  FGameActive := True;
  LMoveCount := CurrentMoveCount;
  if FGameBrowsePly > LMoveCount then
    FGameBrowsePly := -1;
  UpdateBoardFromBrowseState;
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
    UpdateBoardHighlights;
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
    UpdateBoardHighlights;
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
var
  I: Integer;
  LPos: Integer;
begin
  if FGameMoveMemo = nil then
    Exit;
  LPos := FGameMoveMemo.SelStart;
  for I := 0 to High(FGameMoveStarts) do
    if (LPos >= FGameMoveStarts[I]) and
      (LPos <= FGameMoveStarts[I] + FGameMoveLengths[I]) then
    begin
      ApplyGameBrowsePly(I + 1);
      HighlightGameMoveTextSelection(True);
      Exit;
    end;
end;

procedure TMainForm.HideMoveAnnotationsClick(Sender: TObject);
begin
  FHideMoveAnnotations := not FHideMoveAnnotations;
  if FHideMoveAnnotationsMenuItem <> nil then
    FHideMoveAnnotationsMenuItem.Checked := FHideMoveAnnotations;
  RebuildGameMoveLabels;
end;

procedure TMainForm.HighlightGameMoveTextSelection(AFocusMemo: Boolean);
begin
  if FGameMoveMemo = nil then
    Exit;
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
  LPly: Integer;
begin
  if Key = VK_LEFT then
  begin
    if FGameBrowsePly < 0 then
      LPly := CurrentMoveCount
    else
      LPly := FGameBrowsePly - 1;
    ApplyGameBrowsePly(LPly);
    HighlightGameMoveTextSelection(True);
    Key := 0;
  end
  else if Key = VK_RIGHT then
  begin
    if FGameBrowsePly < 0 then
      LPly := 0
    else
      LPly := FGameBrowsePly + 1;
    ApplyGameBrowsePly(LPly);
    HighlightGameMoveTextSelection(True);
    Key := 0;
  end;
end;

procedure TMainForm.MainFormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if ((Key = Ord('F')) or (Key = Ord('f'))) and (Shift = []) then
  begin
    ToggleBoardFlipped;
    Key := 0;
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
  if FPauseGameMenuItem <> nil then
  begin
    FPauseGameMenuItem.Enabled := (LGame <> nil) and
      (LGame.Snapshot.State in [gosWaiting, gosRunning]);
    if (LGame <> nil) and LGame.Paused then
      FPauseGameMenuItem.Caption := 'Resume game'
    else
      FPauseGameMenuItem.Caption := 'Pause game';
  end;
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
      FDatabaseForm.ApplyPreferences(FPreferences);
      FDatabaseForm.CreateDatabase(Dialog.FileName);
      FDatabaseForm.SetSearchFEN(ActiveBoard.CurrentFEN);
      ShowFormCenteredOnOwner(FDatabaseForm, Self);
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
      FDatabaseForm.ApplyPreferences(FPreferences);
      FDatabaseForm.OpenDatabase(Dialog.FileName);
      FDatabaseForm.SetSearchFEN(ActiveBoard.CurrentFEN);
      ShowFormCenteredOnOwner(FDatabaseForm, Self);
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
begin
  if (AGame = nil) or (Trim(AFileName) = '') then
    Exit;

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
    Game.MoveAnnotationsText := MergeAnnotatorAnnotations(
      AGame.Snapshot.MoveAnnotationsText, AGame.AnnotatorAnnotationsText);
    AppendPdnGameToFile(AFileName, Game);
  finally
    Game.Free;
  end;
end;

function TMainForm.SaveCurrentGameWithDialog: Boolean;
var
  Dialog: TSaveDialog;
  Game: TPdnGame;
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

    Game := TPdnGame.Create;
    try
      RunningGame := SelectedGame;
      if (RunningGame <> nil) and FGameActive then
      begin
        AppendRunningGameToPdn(RunningGame, Dialog.FileName,
          PlayerNameOrFallback(FStandaloneEventName, '?'));
        Result := True;
        Exit;
      end
      else
      begin
        Game.WhiteName := PlayerNameOrFallback(FStandaloneWhitePlayerName,
          PlayerNameOrFallback(FWhitePlayerEdit.Text, 'White'));
        Game.BlackName := PlayerNameOrFallback(FStandaloneBlackPlayerName,
          PlayerNameOrFallback(FBlackPlayerEdit.Text, 'Black'));
      end;
      Game.EventName := PlayerNameOrFallback(FStandaloneEventName, '?');
      Game.ResultText := FGameResult;
      Game.StartingFEN := FStartingFEN;
      Game.MovesText := FMovesPlayedText;
      Game.MoveAnnotationsText := FMoveAnnotationsText;
      AppendPdnGameToFile(Dialog.FileName, Game);
      Result := True;
    finally
      Game.Free;
    end;
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
  if FScoreHistoryForm = nil then
  begin
    FScoreHistoryForm := TScoreHistoryForm.Create(Self);
    FScoreHistoryForm.OnClose := @ScoreHistoryFormClose;
  end;
  UpdateScoreHistory;
  ShowFormCenteredOnOwner(FScoreHistoryForm, Self);
end;

procedure TMainForm.ScoreHistoryFormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  CloseAction := caHide;
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
      LBlackEngineKey, LWhiteName, LBlackName, LReservationKeys);
  finally
    LReservationKeys.Free;
  end;
  FGames.Add(Result);
  FGamesListBox.Items.AddObject(LTitle + ' - starting', Result);
  FGamesListBox.ItemIndex := FGamesListBox.Items.Count - 1;

  ClearHumanMoveSelection;
  FBoard.LoadFromFEN(ASetup.StartingFEN);
  FStartingFEN := ASetup.StartingFEN;
  FMovesPlayedText := '';
  FMoveAnnotationsText := '';
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
  FBoardControl.Board := FBoard;
  UpdateMiniBoardFromBoard(FBoard);
  FGameLogMemo.Clear;
  FGameLogMemoGameId := -1;
  FGameLogMemoLineCount := -1;
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
var
  EventObject: TObject;
  LGame: TRunningGame;
  RemoveAfterFinish: Boolean;
  SnapshotMessage: TRunnerSnapshotGuiMessage;
begin
  if FGuiEventQueue = nil then
    Exit;

  while FGuiEventQueue.TryPop(EventObject) do
  begin
    try
      if not (EventObject is TRunnerSnapshotGuiMessage) then
      begin
        if EventObject is TAnalyzerLogGuiMessage then
          HandleAnalyzerLog(TAnalyzerLogGuiMessage(EventObject).Message)
        else if EventObject is TAnalyzerSnapshotGuiMessage then
        begin
          FAnalyzerPvBaseBoard.AssignFrom(
            TAnalyzerSnapshotGuiMessage(EventObject).Snapshot.BaseBoard);
          FAnalyzerPvBasePly :=
            TAnalyzerSnapshotGuiMessage(EventObject).Snapshot.BasePly;
          if FAnalyzerPvBrowser <> nil then
            FAnalyzerPvBrowser.SetSnapshot(
              TAnalyzerSnapshotGuiMessage(EventObject).Snapshot, FStartingFEN);
          ApplyAnalyzerScoreAnnotation(
            TAnalyzerSnapshotGuiMessage(EventObject).Snapshot);
          if FPvHintSource = phsAnalyzer then
          begin
            UpdateBoardHighlights;
            if FBoardControl <> nil then
              FBoardControl.Invalidate;
          end;
        end
        else if EventObject is TAnalyzerFinishedGuiMessage then
        begin
          if FAnalyzerRunner = TAnalyzerFinishedGuiMessage(EventObject).Runner then
            FreeAndNil(FAnalyzerRunner);
          FAnalyzerEngineKey := '';
          FAnalyzerLastPositionSignature := '';
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
              UpdateGameListItem(LGame);
          end;
        end;
        Continue;
      end;

      SnapshotMessage := TRunnerSnapshotGuiMessage(EventObject);
      LGame := FindGameById(SnapshotMessage.GameId);
      if LGame = nil then
        Continue;

      LGame.Snapshot.AssignFrom(SnapshotMessage.Snapshot);
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
    finally
      EventObject.Free;
    end;
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

procedure TMainForm.StopSelectedGame(Sender: TObject);
var
  LGame: TRunningGame;
begin
  LGame := SelectedGame;
  if LGame = nil then
    Exit;

  if LGame.Lifecycle = rglFinished then
  begin
    RemoveGame(LGame);
    Exit;
  end;

  if FTournamentDialog <> nil then
    FTournamentDialog.GameStopped(LGame);

  MarkGameStopped(LGame, 'Stopped');
  if LGame.Lifecycle <> rglFinished then
    LGame.FLifecycle := rglRemoveRequested;
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
  LBoard: TDraughtsBoard;
  LPvBaseBoard: TDraughtsBoard;
  LPvBasePly: Integer;
begin
  LBoard := ActiveBoard;
  UpdateBoardHighlights;

  UpdateGameMoveHighlight;
  HighlightGameMoveTextSelection(False);
  UpdateLegalMoves;
  RestartAnalyzer;
  UpdateScoreHistory;
  if Trim(FPrincipalVariation) = '' then
  begin
    LPvBaseBoard := LBoard;
    LPvBasePly := CurrentMoveCount;
  end
  else
  begin
    LPvBaseBoard := FPvBaseBoard;
    LPvBasePly := FPvBasePly;
  end;
  if FPvBrowser <> nil then
    FPvBrowser.SetData(LPvBaseBoard, LPvBasePly, FStartingFEN,
      FPrincipalVariation, FPrincipalVariationScore, FPrincipalVariationDepth,
      FPrincipalVariationTimeText);
  if FBoardControl <> nil then
    FBoardControl.Invalidate;
end;

procedure TMainForm.UpdateClockLabels(const AWhiteName, ABlackName: string);
var
  LBlackCaption: string;
  LWhiteCaption: string;
begin
  if not FGameActive then
  begin
    if FBlackClockLabel <> nil then
      FBlackClockLabel.Caption := '';
    if FWhiteClockLabel <> nil then
      FWhiteClockLabel.Caption := '';
    Exit;
  end;

  LBlackCaption := ABlackName + '  ' + FormatClock(FBlackRemainingSeconds) +
    '   used ' + FormatFloat('0.000', FBlackUsedSeconds) + ' s';
  LWhiteCaption := AWhiteName + '  ' + FormatClock(FWhiteRemainingSeconds) +
    '   used ' + FormatFloat('0.000', FWhiteUsedSeconds) + ' s';

  if FBoardFlipped then
  begin
    if FBlackClockLabel <> nil then
      FBlackClockLabel.Caption := LWhiteCaption;
    if FWhiteClockLabel <> nil then
      FWhiteClockLabel.Caption := LBlackCaption;
  end
  else
  begin
    if FBlackClockLabel <> nil then
      FBlackClockLabel.Caption := LBlackCaption;
    if FWhiteClockLabel <> nil then
      FWhiteClockLabel.Caption := LWhiteCaption;
  end;
end;

procedure TMainForm.UpdateBoardInfo;
var
  LGame: TRunningGame;
  LBlackName: string;
  LPvBaseBoard: TDraughtsBoard;
  LPvBasePly: Integer;
  LResultText: string;
  LWhiteName: string;
begin
  LGame := SelectedGame;
  UpdateBoardHighlights;
  if (LGame <> nil) and FGameActive then
  begin
    LWhiteName := PlayerNameOrFallback(LGame.Snapshot.WhitePlayerName,
      PlayerNameOrFallback(LGame.WhiteDisplayName, 'White'));
    LBlackName := PlayerNameOrFallback(LGame.Snapshot.BlackPlayerName,
      PlayerNameOrFallback(LGame.BlackDisplayName, 'Black'));
  end
  else
  begin
    LWhiteName := PlayerNameOrFallback(FStandaloneWhitePlayerName, 'White');
    LBlackName := PlayerNameOrFallback(FStandaloneBlackPlayerName, 'Black');
  end;

  UpdateClockLabels(LWhiteName, LBlackName);

  LResultText := FGameResult;
  if Trim(LResultText) = '' then
    LResultText := '*';
  if FWhitePlayerEdit <> nil then
    FWhitePlayerEdit.Text := LWhiteName;
  if FBlackPlayerEdit <> nil then
    FBlackPlayerEdit.Text := LBlackName;
  if FResultEdit <> nil then
    FResultEdit.Text := LResultText;
  if FFenEdit <> nil then
    FFenEdit.Text := FStartingFEN;

  RebuildGameMoveLabels;
  UpdateScoreHistory;

  UpdateLegalMoves;
  RestartAnalyzer;

  UpdateGameLogMemo;

  if Trim(FPrincipalVariation) = '' then
  begin
    LPvBaseBoard := FBoard;
    LPvBasePly := CurrentMoveCount;
  end
  else
  begin
    LPvBaseBoard := FPvBaseBoard;
    LPvBasePly := FPvBasePly;
  end;

  if FPvBrowser <> nil then
    FPvBrowser.SetData(LPvBaseBoard, LPvBasePly, FStartingFEN,
      FPrincipalVariation, FPrincipalVariationScore, FPrincipalVariationDepth,
      FPrincipalVariationTimeText);
  HighlightGameMoveTextSelection(False);
  if FBoardControl <> nil then
    FBoardControl.Invalidate;
end;

procedure TMainForm.UpdateScoreHistory;
var
  LPly: Integer;
begin
  if FScoreHistoryControl = nil then
    Exit;

  LPly := FGameBrowsePly;
  if LPly < 0 then
    LPly := CurrentMoveCount;
  FScoreHistoryControl.MaxScore := FPreferences.EvaluationMaxScore;
  FScoreHistoryControl.Scale := FPreferences.EvaluationScale;
  FScoreHistoryControl.StartingSide := FenSideToMove(FStartingFEN);
  FScoreHistoryControl.PlyCount := CurrentMoveCount;
  FScoreHistoryControl.AnnotationsText := FMoveAnnotationsText;
  FScoreHistoryControl.CurrentPly := LPly;
  if FScoreHistoryForm <> nil then
    FScoreHistoryForm.UpdateScores(FMoveAnnotationsText, CurrentMoveCount, LPly,
      FPreferences.EvaluationMaxScore, FPreferences.EvaluationScale,
      FenSideToMove(FStartingFEN));
end;

procedure TMainForm.UpdateGameListItem(AGame: TRunningGame);
var
  I: Integer;
  LBaseTitle: string;
  LBlackName: string;
  LCaption: string;
  LWhiteName: string;
begin
  if AGame = nil then
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
  for I := 0 to FGamesListBox.Items.Count - 1 do
    if FGamesListBox.Items.Objects[I] = AGame then
    begin
      FGamesListBox.Items[I] := LCaption;
      FGamesListBox.Items.Objects[I] := AGame;
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
