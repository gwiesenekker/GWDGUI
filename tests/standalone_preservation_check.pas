program standalone_preservation_check;

{$mode objfpc}{$H+}
{$IFNDEF GWDGUI_NONINTERACTIVE_TEST}
  {$FATAL Build this test with its .lpi project to enable noninteractive dialogs}
{$ENDIF}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, uGameNotationView, Classes, SysUtils, StdCtrls, ExtCtrls, Grids, LCLType, Controls, ComCtrls, Menus,
  uDatabaseForm, uGameDatabase, uEngineRegistry, uDraughtsBoardControl, uDraughtsBoard, uMainForm, uMoveInteraction, uRunningGame, uDraughtsPdn, uPdnOpenDialog, uPvBrowser, uScoreHistoryControl, uGuiDialogs,
  uGameTreeNodeData, uGameTreeView, uGameTree, uGameTreeActor, uGameTreeBuilder, uGameTreePdn, uGameSetupForm, uGameSetupTypes, uGameOrchestrator, uTreeTestUtils, uDraughtsPosition, uDraughtsHubEngine, uDraughtsDxpEngine;

type
  TDatabaseModalProbe = class
    DatabaseForm: TDatabaseForm;
    ForbiddenPath: string;
    Called: Boolean;
    procedure Run(Data: PtrInt);
  end;
  TTestExceptionReporter = class
    procedure Report(Sender: TObject; E: Exception);
  end;

procedure TTestExceptionReporter.Report(Sender: TObject; E: Exception);
begin
  WriteLn('FAIL: ', E.ClassName, ': ', E.Message);
  DumpExceptionBackTrace(Output);
  Flush(Output);
  Halt(1);
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AMessage);
    Halt(1);
  end;
end;

procedure TDatabaseModalProbe.Run(Data: PtrInt);
begin
  Called := True;
  Check(Application.ModalLevel > 0, 'database import must be modal before work starts');
  DatabaseForm.SearchCurrentPosition;
  DatabaseForm.OpenDatabase(ForbiddenPath);
  DatabaseForm.Close;
  Check(DatabaseForm.Visible, 'closing during import must request cancellation, not close its owner');
end;

procedure CheckInvalidDisplayIsVisible(AForm: TMainForm);
var Memo: TGameNotationView; Key: Word; Board: TDraughtsBoardControl;
begin
  AForm.LoadStandaloneFen(DefaultStartingFEN);
  // Deliberately bypass the actor to simulate corrupt persisted/legacy state.
  AForm.ActiveGameTree.RecordMainlineMove(1, '1-50');
  Memo := TGameNotationView(AForm.FindComponent('GameMoveMemo'));
  Key := VK_RIGHT; Memo.OnKeyDown(Memo, Key, []); // following -> root
  Key := VK_RIGHT; Memo.OnKeyDown(Memo, Key, []); // root -> corrupt node
  Check(Pos('Cannot display the selected position', AForm.Caption) > 0,
    'invalid board selection must have a visible diagnostic');
  Board := TDraughtsBoardControl(AForm.FindComponent('MainBoard'));
  Check((Board <> nil) and (Board.Board = nil), 'stale board must not look like the selected position');
  Key := VK_LEFT; Memo.OnKeyDown(Memo, Key, []);
  Check((Pos('Cannot display', AForm.Caption) = 0) and (Board.Board <> nil),
    'returning to a valid node restores the board and clears its diagnostic');
end;

procedure CheckNotationTreeLayouts;
var Tree, Other: TGameTree; Host: TForm; View: TTreeView; Seen: TStringList;
  Target, Header: Int64; I: Integer;
  function Row(Id: Int64): TTreeNode;
  var J: Integer;
  begin
    for J := 0 to View.Items.Count - 1 do
      if Int64(PtrUInt(View.Items[J].Data)) = Id then Exit(View.Items[J]);
    raise Exception.Create('Missing model row ' + IntToStr(Id));
  end;
  function CountNodes(Node: TGameTreePlyNode): Integer;
  var J: Integer;
  begin
    Result := 1;
    for J := 0 to Node.ChildCount - 1 do Inc(Result, CountNodes(Node.Children[J]));
  end;
  procedure CheckUnique;
  var J: Integer; Id: string;
  begin
    Seen.Clear;
    for J := 0 to View.Items.Count - 1 do
      if View.Items[J].Data <> nil then
      begin
        Id := IntToStr(Int64(PtrUInt(View.Items[J].Data)));
        Check(Seen.IndexOf(Id) < 0, 'layout must not duplicate a model node');
        Seen.Add(Id);
      end;
    Check(Seen.Count = CountNodes(Tree.Root), 'layout includes every model node exactly once');
  end;
begin
  Tree := TGameTree.Create; Other := TGameTree.Create;
  Host := TForm.Create(nil);
  View := TTreeView.Create(nil); View.Parent := Host; Seen := TStringList.Create;
  try
    Tree.RecordMainlineMove(1, '32-28'); Tree.RecordMainlineMove(2, '18-23');
    Tree.RecordMainlineMove(3, '37-32');
    AddFixtureBranch(Tree, 1, '20-24 38-32 14-20', '');
    AddFixtureBranch(Tree, 1, '20-24 38-32 18-22', '');
    Target := Tree.FindBranchNode(1, 3).NodeId;
    Header := Tree.FindBranchNode(0, 1).NodeId;
    PopulateGameTreeView(View, Tree); CheckUnique;
    Check(Row(Tree.MainlineNode[1].NodeId).Parent = Row(Tree.MainlineNode[3].NodeId).Parent,
      'notation mainline moves are sibling rows');
    Check(Pos('Variation: ', Row(Header).Text) = 1, 'variation header is visibly marked');
    Check(Row(Header).Parent = Row(Tree.MainlineNode[2].NodeId), 'alternative hangs under replaced move');
    Row(Header).Expanded := True;
    View.Selected := Row(Target); View.Selected.MakeVisible;
    PopulateGameTreeView(View, Tree, gtvNotation, True); CheckUnique;
    Check((SelectedGameTreeNodeId(View) = Target) and Row(Header).Expanded,
      'refresh preserves selected identity and expanded variation');
    PopulateGameTreeView(View, Tree, gtvNested, True); CheckUnique;
    Check((SelectedGameTreeNodeId(View) = Target) and
      (Row(Tree.MainlineNode[3].NodeId).Parent = Row(Tree.MainlineNode[2].NodeId)),
      'nested layout keeps selection and original parent structure');
    PopulateGameTreeView(View, Tree, gtvNotation, True); CheckUnique;
    Check(SelectedGameTreeNodeId(View) = Target, 'layout round trip preserves selected node');
    PopulateGameTreeView(View, Other, gtvNotation, False);
    Check(SelectedGameTreeNodeId(View) <> Target, 'different tree cannot inherit selection by local node ID');
    Tree.BeginRebuild('capture', '?', 'White', 'Black', '*', 'W:W32:B17,27');
    Tree.RecordMainlineMove(1, '32x12x27x17');
    for I := 0 to 1 do
    begin
      PopulateGameTreeView(View, Tree, TGameTreeViewLayout(I));
      Check(Row(Tree.MainlineNode[1].NodeId).Text = '1.32x12', 'both layouts show standard capture caption');
    end;
  finally Seen.Free; View.Free; Host.Free; Other.Free; Tree.Free; end;
end;

procedure CheckEvaluationDisplay;
var Control: TScoreHistoryControl; Score: Double;
begin
  Control := TScoreHistoryControl.Create(nil);
  try
    Control.AnnotationsText := 'engine=0.1' + LineEnding + 'annotator=0.8' +
      LineEnding + '+2 for white';
    Control.CurrentPly := 2;
    Check(Control.TryCurrentEvaluation(Score) and (Abs(Score - 0.8) < 0.001),
      'current annotator score takes precedence over an old engine score');
    Control.CurrentPly := 3;
    Check(not Control.TryCurrentEvaluation(Score), 'free text is not an evaluation');
    Control.CurrentPly := 1;
    Check(Control.TryCurrentEvaluation(Score) and (Abs(Score - 0.1) < 0.001),
      'selected historical position uses its own engine score');
    Control.CurrentPly := 0;
    Check(not Control.TryCurrentEvaluation(Score), 'root must not borrow a later score');
  finally Control.Free; end;
end;

procedure CheckNodeDataImport(AForm: TMainForm);
var Data: TGameTreeNodeData; Game: TPdnGame; Games: TList;
  Lines: TStringList; FileName, Text: string; I, Cycle: Integer;
begin
  Data := Default(TGameTreeNodeData);
  Data.CommentText := 'user note'; Data.EnginePV := '32-28 16-21';
  Data.EngineScore := '0.15'; Data.EnginePVDepth := '20';
  Data.AnnotatorPV := '34-30'; Data.AnnotatorPVDepth := '22';
  Data.HasMoveTime := True; Data.SecondsUsed := 1.75;
  Text := '[Event "node data"]' + LineEnding +
    '{user note} {' + EncodeNodeData(Data, 'user note') + '} 1.32-28 ' +
    '(1.34-30 20-25 (1...18-23 {user note} {' + EncodeNodeData(Data, 'user note') + '})) *';
  Games := TList.Create; Lines := TStringList.Create;
  FileName := GetTempFileName(GetTempDir, 'gwd');
  try
    for Cycle := 1 to 3 do
    begin
      Lines.Text := Text; Lines.SaveToFile(FileName);
      LoadPdnGamesFromFile(FileName, Games);
      Check(Games.Count = 1, 'GUI round trip remains one game');
      Game := TPdnGame(Games[0]);
      AForm.LoadPdnGameToDisplay(Game);
      Check((AForm.LastDisplayReplayCount > 0) and (AForm.LastDisplayReplayCount <= 3),
        'a refresh must reuse validated boards for repeated consumers');
      Check(EncodeNodeData(AForm.ActiveGameTree.Root.NodeData, '') =
        EncodeNodeData(Data, ''), 'GUI imports complete root analysis');
      Check(AForm.ActiveGameTree.Root.ChildCount = 2, 'GUI preserves real root variations');
      Check(AForm.ActiveGameTree.Root.Children[1].ChildCount = 2, 'GUI preserves nested alternatives');
      Check(EncodeNodeData(AForm.ActiveGameTree.Root.Children[1].Children[1].NodeData, '') =
        EncodeNodeData(Data, ''), 'GUI imports nested node analysis');
      Text := GameTreeToPdnText(AForm.ActiveGameTree);
      for I := 0 to Games.Count - 1 do TObject(Games[I]).Free;
      Games.Clear;
    end;
  finally
    for I := 0 to Games.Count - 1 do TObject(Games[I]).Free;
    DeleteFile(FileName); Lines.Free; Games.Free;
  end;
end;

procedure CheckLandingCaptureImport(AForm: TMainForm);
var Game: TPdnGame; Text: string; Memo: TGameNotationView; Board: TDraughtsBoardControl;
begin
  Game := TPdnGame.Create;
  try
    Game.StartingFEN := 'W:W32:B17,27';
    Game.MovesText := '32x21x12';
    AForm.LoadPdnGameToDisplay(Game);
    Check((AForm.ActiveGameTree.MainlineCount = 1) and
      (AForm.ActiveGameTree.MainlineNode[1].MoveText = '32x12x27x17'),
      'landing path must import as a validated canonical tree move');
    Memo := TGameNotationView(AForm.FindComponent('GameMoveMemo'));
    Check((Pos('32x12', Memo.Text) > 0) and (Pos('x27x17', Memo.Text) = 0),
      'move list uses standard capture notation');
    Memo.SelStart := Pos('32x12', Memo.Text) - 1; Memo.OnClick(Memo);
    Board := TDraughtsBoardControl(AForm.FindComponent('MainBoard'));
    Check((Board.Board[12] = pkWhiteMan) and (Board.Board[17] = pkEmpty) and
      (Board.Board[27] = pkEmpty) and (Memo.SelText = '32x12'),
      'standard capture caption retains the correct clickable move range');
    Text := GameTreeToPdnText(AForm.ActiveGameTree);
    Check((Pos('32x12x27x17', Text) = 0) and (Pos('32x12', Text) > 0) and
      (Pos('[SetUp "1"]', Text) > 0), 'PDN export must use standard capture and setup notation');
  finally Game.Free; end;
end;

procedure CheckNotationSelectionAndFilters(AForm: TMainForm);
var
  Game: TPdnGame;
  Memo: TGameNotationView;
  Board: TDraughtsBoardControl;
  Expected: TDraughtsBoard;
  HideAnnotations: TMenuItem;
  I, Start: Integer;
  ExportBefore: string;
  WasHidden: Boolean;

  procedure SelectText(AStart, ALength: Integer);
  begin
    Memo.SelStart := AStart;
    Memo.SelLength := ALength;
    Memo.OnClick(Memo);
  end;

  procedure CheckPosition(const Path: string);
  var Moves: TStringList; J: Integer;
  begin
    Expected.SetBeginPosition;
    Moves := TStringList.Create;
    try
      TextToMoveList(Path, Moves);
      for J := 0 to Moves.Count - 1 do Expected.PlayMove(Moves[J]);
      Check(Board.Board.CurrentFEN = Expected.CurrentFEN,
        'notation selection displays the selected path: ' + Path);
      Check(GameTreeToPdnText(AForm.ActiveGameTree) = ExportBefore,
        'notation selections and display filters preserve the game');
    finally Moves.Free; end;
  end;

begin
  Game := TPdnGame.Create;
  Expected := TDraughtsBoard.Create;
  HideAnnotations := nil;
  WasHidden := False;
  try
    Game.MovesText := '32-28 18-23 37-32';
    Game.InitialCommentText := 'Opening note';
    Game.MoveAnnotationsText := 'First move note' + LineEnding;
    AForm.LoadPdnGameToDisplay(Game);
    Memo := TGameNotationView(AForm.FindComponent('GameMoveMemo'));
    Board := TDraughtsBoardControl(AForm.FindComponent('MainBoard'));
    Check((Memo <> nil) and (Board <> nil) and (Memo.PopupMenu <> nil),
      'notation selection controls exist');
    for I := 0 to Memo.PopupMenu.Items.Count - 1 do
      if Memo.PopupMenu.Items[I].Caption = 'Hide annotation' then
        HideAnnotations := Memo.PopupMenu.Items[I];
    Check(HideAnnotations <> nil, 'annotation filter is accessible through the real popup');
    WasHidden := HideAnnotations.Checked;
    if WasHidden then HideAnnotations.OnClick(HideAnnotations);
    ExportBefore := GameTreeToPdnText(AForm.ActiveGameTree);
    Start := Pos('32-28', Memo.Text) - 1;
    Check(Start > 0, 'initial comment precedes first move');
    SelectText(Start + Length('32-28'), 0);
    CheckPosition('32-28');
    Check(Memo.SelText = '32-28', 'caret at right edge highlights the whole first move');
    SelectText(Start - 1, 1);
    CheckPosition('');
    SelectText(Pos('18-23', Memo.Text), 2);
    CheckPosition('32-28 18-23');
    Check(Memo.SelText = '18-23', 'selected text inside a move highlights its complete range');
    HideAnnotations.OnClick(HideAnnotations);
    Check((Pos('Opening note', Memo.Text) = 0) and
      (Pos('First move note', Memo.Text) = 0), 'filter rebuild removes comments');
    CheckPosition('32-28 18-23');
    Check(Memo.SelText = '18-23', 'filter rebuild relocates the selected move range');
    SelectText(Pos('37-32', Memo.Text) - 1 + Length('37-32'), 0);
    CheckPosition('32-28 18-23 37-32');
    Check(Memo.SelText = '37-32', 'filtered ranges remain clickable at their endpoints');
    HideAnnotations.OnClick(HideAnnotations);
    Check(Pos('Opening note', Memo.Text) > 0, 'filter restores introductory comment');
    CheckPosition('32-28 18-23 37-32');
    Check(Memo.SelText = '37-32', 'restored comments relocate selected range again');
  finally
    if (HideAnnotations <> nil) and (HideAnnotations.Checked <> WasHidden) then
      HideAnnotations.OnClick(HideAnnotations);
    Expected.Free;
    Game.Free;
  end;
end;

procedure CheckModalDatabaseImport(AForm: TMainForm);
var Form: TDatabaseForm; Probe: TDatabaseModalProbe; Database: TGameDatabase;
  FileName, DbName: string; Text: TStringList; Games: TList; I: Integer;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd-modal');
  DbName := FileName + '.db';
  Text := TStringList.Create;
  Games := TList.Create;
  Form := TDatabaseForm.Create(AForm);
  Probe := TDatabaseModalProbe.Create;
  Database := TGameDatabase.Create;
  try
    for I := 1 to 5000 do
      Text.Add('[Event "Game ' + IntToStr(I) + '"] 1.32-28 18-23 *');
    Text.SaveToFile(FileName);
    Form.CreateDatabase(DbName);
    Form.Show;
    Probe.DatabaseForm := Form;
    Probe.ForbiddenPath := DbName + '.must-not-open';
    Application.QueueAsyncCall(@Probe.Run, 0);
    Form.ImportPdnFile(FileName);
    Check(Probe.Called and not FileExists(Probe.ForbiddenPath),
      'reentrant actions must not replace the database during import');
    Database.OpenDatabase(DbName);
    Database.LoadGames(Games);
    Check((Games.Count >= 1) and (Games.Count < 5000),
      'close cancellation must stop the worker and retain completed games');
  finally
    Application.RemoveAsyncCalls(Probe);
    for I := 0 to Games.Count - 1 do TObject(Games[I]).Free;
    Database.Free;
    Form.Free;
    Probe.Free;
    Games.Free;
    Text.Free;
    DeleteFile(FileName);
    DeleteFile(ChangeFileExt(FileName, '.import.log'));
    DeleteFile(DbName);
  end;
end;

procedure DrainGuiEvents(AForm: TMainForm);
var
  I: Integer;
begin
  Application.ProcessMessages;
  for I := 0 to AForm.ComponentCount - 1 do
    if (AForm.Components[I] is TTimer) and
      Assigned(TTimer(AForm.Components[I]).OnTimer) then
      TTimer(AForm.Components[I]).OnTimer(nil);
end;

procedure FakeHistoryHub(const MoveText: string);
var
  Line: string;
begin
  while not EOF(Input) do
  begin
    ReadLn(Line);
    if Line = 'hub' then WriteLn('wait')
    else if Line = 'init' then WriteLn('ready')
    else if Line = 'go think' then
    begin
      WriteLn('info depth=17 time=0.12 score=0.42 pv="' + MoveText + '"');
      WriteLn('done move=' + MoveText);
    end
    else if Line = 'stop' then WriteLn('done')
    else if Line = 'quit' then Exit;
    Flush(Output);
  end;
end;

procedure CheckParsedLiteralComments(AForm: TMainForm);
var
  FileName: string;
  Lines: TStringList;
  Games: TList;
  I: Integer;
  Node: TGameTreePlyNode;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd-literal');
  Lines := TStringList.Create;
  Games := TList.Create;
  try
    Lines.Text := '[Event "Literal comments"]' + LineEnding +
      '1.32-28 {@pdn-annotations:not json} 18-23 ' +
      '(1...20-24 {@pdn-annotations:["literal"]} 2.38-32) 2.37-32 *';
    Lines.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 1, 'literal comment fixture');
    AForm.LoadPdnGameToDisplay(TPdnGame(Games[0]));
    Check(AForm.ActiveGameTree.MainlineNode[1].CommentText = '@pdn-annotations:not json',
      'mainline literal marker must stay a comment');
    Node := AForm.ActiveGameTree.FindChildByMove(AForm.ActiveGameTree.MainlineNode[1], '20-24');
    Check(Node <> nil, 'literal comment syntax must not suppress a valid branch');
    Check(Node.CommentText = '@pdn-annotations:["literal"]',
      'recursive import must not reinterpret literal comments as annotation arrays');
  finally
    for I := 0 to Games.Count - 1 do TObject(Games[I]).Free;
    Games.Free; Lines.Free; DeleteFile(FileName);
  end;
end;

procedure CheckCoalescedRunnerHistory(AForm: TMainForm);
var
  WhiteEngine, BlackEngine: TExternalEngineDefinition;
  Setup: TGameSetup;
  Game: TRunningGame;
  Tick: QWord;
  Text: string;
begin
  WhiteEngine := TExternalEngineDefinition.Create;
  BlackEngine := TExternalEngineDefinition.Create;
  Game := nil;
  try
    WhiteEngine.Kind := eekHub;
    WhiteEngine.ExePath := ExpandFileName(ParamStr(0));
    WhiteEngine.Arguments := '--history-white';
    BlackEngine.Assign(WhiteEngine);
    BlackEngine.Arguments := '--history-black';
    Setup := Default(TGameSetup);
    Setup.WhitePlayer := pkRegistered;
    Setup.BlackPlayer := pkRegistered;
    Setup.WhiteEngine := WhiteEngine;
    Setup.BlackEngine := BlackEngine;
    Setup.StartingFEN := 'W:W32:B23';
    Setup.TimeControl := DefaultTimeControl;
    Game := AForm.StartGameFromSetup(Setup);
    // Let both moves finish before draining any GUI snapshots.
    Tick := GetTickCount64;
    while not Game.Runner.Finished and (GetTickCount64 - Tick < 5000) do Sleep(10);
    Check(Game.Runner.Finished, 'short fake-engine game must finish without GUI updates');
    DrainGuiEvents(AForm);
    Check((Game.GameTree.MainlineCount = 2) and (Game.ResultText = '0-2'),
      'coalesced snapshots must recover both moves and the final result');
    Check((Game.GameTree.Root.EnginePV = '32-28') and
      (Game.GameTree.MainlineNode[1].EnginePV = '23x32'),
      'coalescing must preserve both completed engine searches');
    Check(Game.GameTree.MainlineNode[1].HasClockInfo and
      Game.GameTree.MainlineNode[2].HasClockInfo and
      Game.GameTree.MainlineNode[1].HasMoveTime and
      Game.GameTree.MainlineNode[2].HasMoveTime,
      'coalescing must preserve times and both clocks at every move');
    Text := GameTreeToPdnText(Game.GameTree);
    Check((Pos('emt:', Text) > 0) and (Pos('clk:', Text) > 0),
      'completed runner history must remain exportable');
  finally
    if Game <> nil then AForm.RemoveGame(Game);
    BlackEngine.Free;
    WhiteEngine.Free;
  end;
end;

procedure CheckStandaloneSurvivesRunningGame(AForm: TMainForm;
  const AExpectedFen: string; AExpectedMoves: Integer);
var
  Setup: TGameSetup;
  Game: TRunningGame;
  Standalone: TGameTree;
  Text: string;
  Tick: QWord;
  History: TListBox;
begin
  Standalone := AForm.ActiveGameTree;
  Text := GameTreeToPdnText(Standalone);
  Setup := Default(TGameSetup);
  Setup.StartingFEN := 'W:W31-50:B1-20';
  Setup.TimeControl := DefaultTimeControl;
  Setup.WhitePlayer := pkHuman;
  Setup.BlackPlayer := pkHuman;
  Game := AForm.StartGameFromSetup(Setup);
  Check(AForm.ActiveGameTree <> Standalone,
    'starting a game should select its own tree');
  Tick := GetTickCount64;
  while (Game.Lifecycle = rglStarting) and (GetTickCount64 - Tick < 5000) do
  begin
    DrainGuiEvents(AForm);
    Sleep(10);
  end;
  Check(Game.Lifecycle = rglRunning, 'runner should publish its initial position');
  AForm.MarkGameStopped(Game, 'regression check');
  Tick := GetTickCount64;
  while (Game.Lifecycle <> rglFinished) and (GetTickCount64 - Tick < 5000) do
  begin
    DrainGuiEvents(AForm);
    Sleep(10);
  end;
  Check(Game.Lifecycle = rglFinished, 'stopped runner should finish; runner=' +
    BoolToStr(Game.Runner.Finished, True) + '; components=' +
    IntToStr(AForm.ComponentCount));
  AForm.RemoveGame(Game);
  Check(AForm.ActiveGameTree = Standalone,
    'removing the last game must return to the original standalone tree');
  Check((Standalone.MainlineCount = AExpectedMoves) and
    (Standalone.StartingFEN = AExpectedFen),
    'removing a running game must not reset standalone content');
  Check(GameTreeToPdnText(Standalone) = Text,
    'standalone annotations and variations must also survive');
  History := TListBox(AForm.FindComponent('GameHistoryList'));
  Check((History <> nil) and (History.Items.Count = 1),
    'the standalone board must remain reachable in game history');
  Game := AForm.StartGameFromSetup(Setup);
  Tick := GetTickCount64;
  while (Game.Lifecycle = rglStarting) and (GetTickCount64 - Tick < 5000) do
  begin
    DrainGuiEvents(AForm);
    Sleep(10);
  end;
  Check(Game.Lifecycle = rglRunning, 'second runner should initialize');
  History.ItemIndex := 0;
  History.OnClick(History);
  Check((AForm.ActiveGameTree = Standalone) and
    (GameTreeToPdnText(Standalone) = Text),
    'selecting Board while another game runs must restore the preserved game');
  AForm.MarkGameStopped(Game, 'regression check');
  Tick := GetTickCount64;
  while (Game.Lifecycle <> rglFinished) and (GetTickCount64 - Tick < 5000) do
  begin
    DrainGuiEvents(AForm);
    Sleep(10);
  end;
  Check(Game.Lifecycle = rglFinished, 'second runner should finish');
  AForm.RemoveGame(Game);
end;

procedure CheckNestedGuiNavigation(AForm: TMainForm);
var
  Games: TList;
  Source, Moves: TStringList;
  FileName: string;
  Memo: TGameNotationView;
  BoardControl: TDraughtsBoardControl;
  Expected: TDraughtsBoard;
  I: Integer;
  Key: Word;
  BeforeText: string;
  Changed: Boolean;
  SelectedId: Int64;

  procedure CheckBoard(const Path: string);
  var
    J: Integer;
  begin
    Expected.SetBeginPosition;
    TextToMoveList(Path, Moves);
    for J := 0 to Moves.Count - 1 do
      Expected.PlayMove(Moves[J]);
    Check(BoardControl.Board.CurrentFEN = Expected.CurrentFEN,
      'memo navigation must follow nested ancestry: ' + Path);
    Check(GameTreeToPdnText(AForm.ActiveGameTree) = BeforeText,
      'navigation must not change the game tree');
  end;

  procedure ClickText(const Needle: string);
  var
    Offset: Integer;
  begin
    Offset := Pos(Needle, Memo.Text);
    Check(Offset > 0, 'missing nested memo target: ' + Needle);
    Memo.SelStart := Offset - 1;
    Memo.SelLength := 0;
    Memo.OnClick(Memo);
  end;
begin
  Games := TList.Create;
  Source := TStringList.Create;
  Moves := TStringList.Create;
  Expected := TDraughtsBoard.Create;
  FileName := GetTempFileName(GetTempDir, 'gwd');
  try
    Source.Text := '[Event "Nested GUI test"]' + LineEnding + LineEnding +
      '1. 32-28 18-23 (1... 20-24 {Outer} 2. 37-32 ' +
      '(2. 38-32 {Nested} 14-20 (2... 18-22 {Deeper})) 14-20) 2. 37-32 *';
    Source.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 1, 'GUI nested fixture should parse');
    AForm.LoadPdnGameToDisplay(TPdnGame(Games[0]));
    Memo := TGameNotationView(AForm.FindComponent('GameMoveMemo'));
    BoardControl := TDraughtsBoardControl(AForm.FindComponent('MainBoard'));
    Check((Memo <> nil) and (BoardControl <> nil), 'named navigation controls');
    BeforeText := GameTreeToPdnText(AForm.ActiveGameTree);
    ClickText('38-32');
    CheckBoard('32-28 20-24 38-32');
    ClickText('18-22');
    CheckBoard('32-28 20-24 38-32 18-22');
    Key := VK_LEFT;
    Memo.OnKeyDown(Memo, Key, []);
    CheckBoard('32-28 20-24 38-32');
    Key := VK_RIGHT;
    Memo.OnKeyDown(Memo, Key, []);
    CheckBoard('32-28 20-24 38-32 18-22');
    ClickText('(2.38-32');
    CheckBoard('32-28 20-24');
    Key := VK_RIGHT;
    Memo.OnKeyDown(Memo, Key, []);
    CheckBoard('32-28 20-24 38-32');
    ClickText('(2...18-22');
    CheckBoard('32-28 20-24 38-32');
    Key := VK_RIGHT;
    Memo.OnKeyDown(Memo, Key, []);
    CheckBoard('32-28 20-24 38-32 18-22');
    ClickText('38-32');
    SelectedId := AForm.ActiveGameTree.FindBranchNode(1, 2).NodeId;
    // Remove one leaf while the selected shared parent survives in another path.
    AForm.ActiveGameTree.RemoveBranch(AForm.ActiveGameTree.FindBranchNode(1, 3));
    BeforeText := GameTreeToPdnText(AForm.ActiveGameTree);
    Check(AForm.ActiveGameTree.FindBranchNode(1, 2).NodeId = SelectedId,
      'fixture must retain the selected shared node through its surviving child');
    Key := VK_LEFT;
    Memo.OnKeyDown(Memo, Key, []);
    CheckBoard('32-28 20-24');
    Key := VK_RIGHT;
    Memo.OnKeyDown(Memo, Key, []);
    CheckBoard('32-28 20-24 38-32');
    Check(Pos('38-32', Memo.SelText) > 0,
      'memo highlight must follow the surviving node after its path changes');
  finally
    for I := 0 to Games.Count - 1 do
      TObject(Games[I]).Free;
    DeleteFile(FileName);
    Expected.Free;
    Moves.Free;
    Source.Free;
    Games.Free;
  end;
end;

procedure CheckBlackStartVariationNavigation(AForm: TMainForm);
var
  Games: TList;
  Source, Moves: TStringList;
  FileName, BeforeText: string;
  Memo: TGameNotationView;
  Board: TDraughtsBoardControl;
  Expected: TDraughtsBoard;
  I: Integer;

  procedure SelectVariation(const MoveText, Path: string);
  var
    J, Offset: Integer;
  begin
    Offset := Pos(MoveText, Memo.Text);
    Check(Offset > 0, 'Black-start alternative must be visible: ' + MoveText);
    Memo.SelStart := Offset - 1;
    Memo.SelLength := 0;
    Memo.OnClick(Memo);
    Expected.LoadFromFEN('B:W31-50:B1-20');
    TextToMoveList(Path, Moves);
    for J := 0 to Moves.Count - 1 do Expected.PlayMove(Moves[J]);
    Check(Board.Board.CurrentFEN = Expected.CurrentFEN,
      'Black-start alternative must browse from its actual parent: ' + MoveText);
    Check(Board.LastMoveTargetSquare = MoveSquareAt(Expected.MovesPlayed[Expected.MovesPlayedCount - 1], 2),
      'branch marker follows the displayed move: ' + MoveText);
    Check(GameTreeToPdnText(AForm.ActiveGameTree) = BeforeText,
      'browsing Black-start alternatives must not mutate the game');
  end;
begin
  Games := TList.Create;
  Source := TStringList.Create;
  Moves := TStringList.Create;
  Expected := TDraughtsBoard.Create;
  FileName := GetTempFileName(GetTempDir, 'gwd');
  try
    Source.Text := '[FEN "B:W31-50:B1-20"]' + LineEnding + LineEnding +
      '1... 18-23 2. 32-28 (2. 33-28 (2. 31-27 12-18) 17-22) ' +
      '23x32 3. 37x28 (3. 38x27 12-18) 12-18 *';
    Source.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 1, 'Black-start GUI fixture must parse');
    AForm.LoadPdnGameToDisplay(TPdnGame(Games[0]));
    Memo := TGameNotationView(AForm.FindComponent('GameMoveMemo'));
    Board := TDraughtsBoardControl(AForm.FindComponent('MainBoard'));
    BeforeText := GameTreeToPdnText(AForm.ActiveGameTree);
    SelectVariation('33-28', '18-23 33-28');
    SelectVariation('31-27', '18-23 31-27');
    SelectVariation('38x27', '18-23 32-28 23x32 38x27');
  finally
    for I := 0 to Games.Count - 1 do TObject(Games[I]).Free;
    DeleteFile(FileName);
    Expected.Free;
    Moves.Free;
    Source.Free;
    Games.Free;
  end;
end;

procedure CheckMalformedVariationWarningsInGui(AForm: TMainForm);
var
  Dialog: TPdnOpenDialog;
  Source: TStringList;
  Games: TList;
  Grid: TStringGrid;
  Status, Warning: TLabel;
  FileName: string;
  CanSelect: Boolean;
  I: Integer;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd');
  Source := TStringList.Create;
  Games := TList.Create;
  Dialog := TPdnOpenDialog.Create(AForm);
  try
    Source.Text := '[Event "Warned game"]' + LineEnding +
      '1. 32-28 18-23 (1... 20-24 {Outer} (1. 33-28 {Bad nested}) ' +
      '2. 37-32 (2. 38-32 {Good sibling} 14-20) 14-20) 2. 37-32 *' + LineEnding +
      '[Event "Clean game"]' + LineEnding + '1. 33-28 18-22 *';
    Source.SaveToFile(FileName);
    Dialog.OpenPdnFile(FileName);
    Grid := TStringGrid(Dialog.FindComponent('PdnGames'));
    Status := TLabel(Dialog.FindComponent('PdnImportStatus'));
    Warning := TLabel(Dialog.FindComponent('PdnImportWarnings'));
    Check((Grid.RowCount = 3) and (Grid.Cells[4, 1] = '1') and
      (Grid.Cells[4, 2] = 'On selection'), 'PDN list checks selected game and defers the other game');
    Check(Pos('1 import warning', Status.Caption) > 0, 'PDN status must report parse warnings');
    CanSelect := True;
    Grid.OnSelectCell(Grid, 0, 1, CanSelect);
    Check(Warning.Visible and (Pos('outside its parent line', Warning.Caption) > 0),
      'selecting the affected game must explain the skipped variation');
    Grid.OnSelectCell(Grid, 0, 2, CanSelect);
    Check(not Warning.Visible and (Grid.Cells[4, 2] = ''),
      'selecting a clean game must clear its pending warning marker and the previous warning');
    LoadPdnGamesFromFile(FileName, Games);
    AForm.LoadPdnGameToDisplay(TPdnGame(Games[0]));
    Check((AForm.ActiveGameTree.MainlineCount = 3) and
      (AForm.ActiveGameTree.BranchCount = 2),
      'a warned game must still load its mainline and valid branches into the actual form');
    Check(Pos('Good sibling', GameTreeToPdnText(AForm.ActiveGameTree)) > 0,
      'opening a warned game must retain its valid annotations');
    Source.Text := '[Event "Illegal branch"]' + LineEnding +
      '1. 32-28 18-23 (1... 18-24) *';
    Source.SaveToFile(FileName);
    Dialog.OpenPdnFile(FileName);
    Grid.OnSelectCell(Grid, 0, 1, CanSelect);
    Check(Warning.Visible and (Pos('18-24', Warning.Caption) > 0),
      'PDN list must explain an illegal branch before opening it');
    LoadPdnGamesFromFile(FileName, Games);
    AForm.LoadPdnGameToDisplay(TPdnGame(Games[0]));
    Check((AForm.ActiveGameTree.MainlineCount = 2) and
      (Pos('18-24', AForm.ActiveGameTree.StatusText) > 0),
      'actor rejection must remain visible in the board status');
  finally
    Dialog.Free;
    for I := 0 to Games.Count - 1 do TObject(Games[I]).Free;
    Games.Free;
    Source.Free;
    DeleteFile(FileName);
  end;
end;

procedure ClickBoardSquare(AForm: TMainForm; ASquare: Integer);
var
  Board: TDraughtsBoardControl;
  X, Y: Integer;
begin
  Board := TDraughtsBoardControl(AForm.FindComponent('MainBoard'));
  // Locate a point through the control's own coordinate mapping, including margins.
  for Y := 0 to Board.Height div 4 do
    for X := 0 to Board.Width div 4 do
      if Board.SquareAtPoint(X * 4, Y * 4) = ASquare then
      begin
        Board.OnMouseDown(Board, mbLeft, [], X * 4, Y * 4);
        Exit;
      end;
  Check(False, 'cannot locate board square ' + IntToStr(ASquare));
end;

procedure ClickBoardMove(AForm: TMainForm; AFrom, ATo: Integer);
begin
  ClickBoardSquare(AForm, AFrom);
  ClickBoardSquare(AForm, ATo);
end;

procedure CheckStandaloneMainlineCanBeExtended(AForm: TMainForm);
var
  Tree: TGameTree;
  Game: TPdnGame;
  Memo: TGameNotationView;
  Key: Word;
begin
  AForm.LoadStandaloneFen(DefaultStartingFEN);
  Tree := AForm.ActiveGameTree;
  ClickBoardMove(AForm, 32, 28);
  Check((Tree.MainlineCount = 1) and (Tree.MainlineNode[1].MoveText = '32-28'),
    'a move from a pasted position must start the standalone mainline');
  ClickBoardMove(AForm, 18, 23);
  Check((Tree.MainlineCount = 2) and (Tree.BranchCount = 0),
    'successive standalone moves must extend the same mainline');
  Game := TPdnGame.Create;
  try
    Game.MovesText := '32-28 18-23';
    Game.ResultText := '*';
    AForm.LoadPdnGameToDisplay(Game);
    Memo := TGameNotationView(AForm.FindComponent('GameMoveMemo'));
    Key := VK_LEFT;
    Memo.OnKeyDown(Memo, Key, []);
    ClickBoardMove(AForm, 37, 32);
    Check((Tree.MainlineCount = 3) and (Tree.BranchCount = 0),
      'a move at the explicitly selected last ply must extend an unfinished PDN');
    ClickBoardMove(AForm, 12, 18);
    Check(Tree.MainlineCount = 4, 'editing must continue at the new mainline tip');
    // Earlier positions still create alternatives, retaining the full played line.
    Key := VK_LEFT;
    Memo.OnKeyDown(Memo, Key, []);
    Key := VK_LEFT;
    Memo.OnKeyDown(Memo, Key, []);
    ClickBoardMove(AForm, 13, 18);
    Check(Tree.MainlineCount = 4, 'editing an earlier position must retain the mainline');
    Check(Pos('13-18', GameTreeToPdnText(Tree)) > 0,
      'an earlier alternative must remain exportable');
  finally
    Game.Free;
  end;
end;

procedure CheckCompletedGameKeepsOfficialMainline(AForm: TMainForm);
var
  Setup: TGameSetup;
  Game: TRunningGame;
  Command: TGameTreeCommand;
  History: TListBox;
  Memo: TGameNotationView;
  Tick: QWord;
  Key: Word;
  Text: string;
begin
  Setup := Default(TGameSetup);
  Setup.StartingFEN := DefaultStartingFEN;
  Setup.TimeControl := DefaultTimeControl;
  Setup.WhitePlayer := pkHuman;
  Setup.BlackPlayer := pkHuman;
  Game := AForm.StartGameFromSetup(Setup);
  Tick := GetTickCount64;
  while (Game.Lifecycle = rglStarting) and (GetTickCount64 - Tick < 5000) do
  begin
    DrainGuiEvents(AForm);
    Sleep(10);
  end;
  AForm.MarkGameStopped(Game, 'finished-game fixture');
  Tick := GetTickCount64;
  while (Game.Lifecycle <> rglFinished) and (GetTickCount64 - Tick < 5000) do
  begin
    DrainGuiEvents(AForm);
    Sleep(10);
  end;
  Check(Game.Lifecycle = rglFinished, 'completed editing fixture must finish');
  try
    ClickBoardMove(AForm, 32, 28);
    ClickBoardMove(AForm, 18, 23);
    Check((Game.MainlineCount = 2) and (Game.ResultText = '*'),
      'a stopped unfinished game must remain extendable');
    Command := Game.GameTreeActor.CreateSetHeaderCommand(
      GameTreeHeaderInput('finished-fixture', 'Game ended on time', 'White',
        'Black', '0-2', DefaultStartingFEN, False, DefaultTimeControl, gosGameOver));
    try
      Game.GameTreeActor.ExecuteCommand(Command);
      Check(Command.Accepted, 'completed game header fixture');
    finally
      Command.Free;
    end;
    History := TListBox(AForm.FindComponent('GameHistoryList'));
    History.OnClick(History);
    // The game ended with legal moves available, as after a loss on time.
    ClickBoardMove(AForm, 37, 32);
    Check((Game.MainlineCount = 2) and (Game.ResultText = '0-2') and
      (Game.State = gosGameOver),
      'post-result exploration must preserve the official mainline and result');
    Check(Game.GameTree.MainlineNode[2].ChildCount = 1,
      'a move after a completed game must be retained as a continuation variation');
    ClickBoardMove(AForm, 12, 18);
    Check(Game.MainlineCount = 2, 'continued exploration must stay outside the official line');
    Text := GameTreeToPdnText(Game.GameTree);
    Check((Pos('37-32', Text) > 0) and (Pos('12-18', Text) > 0),
      'post-result exploration must be visible in saved PDN');
    Memo := TGameNotationView(AForm.FindComponent('GameMoveMemo'));
    Key := VK_ESCAPE;
    Memo.OnKeyDown(Memo, Key, []);
    ClickBoardMove(AForm, 38, 32);
    Check((Game.MainlineCount = 2) and (Game.GameTree.MainlineNode[2].ChildCount = 2),
      'a different post-result move must preserve the first continuation');
  finally
    AForm.RemoveGame(Game);
  end;
end;

procedure CheckUnexpectedDialogsAbort;
{$IFDEF GWDGUI_NONINTERACTIVE_TEST}
var
  I: Integer;
  Rejected: Boolean;
{$ENDIF}
begin
  {$IFDEF GWDGUI_NONINTERACTIVE_TEST}
  for I := 1 to 2 do
  begin
    Rejected := False;
    try
      if I = 1 then ShowGuiOkDialog(nil, 'regression', 'unexpected dialog')
      else ShowGuiTextDialog(nil, 'regression', 'unexpected dialog');
    except
      on E: EInvalidOperation do
        Rejected := Pos('Unexpected dialog (regression)', E.Message) > 0;
    end;
    Check(Rejected, 'unexpected test dialogs must fail before opening a window');
  end;
  {$ENDIF}
end;

procedure CheckTreeWindowUsesSameCursor(AForm: TMainForm);
var
  Game: TPdnGame;
  Window: TForm;
  View: TTreeView;
  Memo: TGameNotationView;
  Board: TDraughtsBoardControl;
  Expected: TDraughtsBoard;
  Target: Int64;
  I: Integer;
  Key: Word;
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  LayoutItem: TMenuItem;

  procedure CheckPosition(const MessageText: string);
  begin
    Check(Board.Board.CurrentFEN = Expected.CurrentFEN, MessageText);
  end;
begin
  Game := TPdnGame.Create;
  Expected := TDraughtsBoard.Create;
  try
    Game.MovesText := '32-28 18-23';
    Game.MoveVariationsText := EncodePdnVariationLine(2, 1, '20-24 38-32 18-22');
    AForm.LoadPdnGameToDisplay(Game);
    Check(AForm.ActiveGameTree.FindBranchNode(0, 3) <> nil,
      'tree-window fixture must materialize its variation: ' +
      GameTreeToPdnText(AForm.ActiveGameTree));
    Target := AForm.ActiveGameTree.FindBranchNode(0, 3).NodeId;
    TMenuItem(AForm.FindComponent('ShowGameTree')).OnClick(nil);
    Window := TForm(AForm.FindComponent('GameTreeWindow'));
    Check(Window <> nil, 'tree window must open');
    Window.Hide;
    View := TTreeView(Window.FindComponent('GameTreeNodes'));
    Memo := TGameNotationView(AForm.FindComponent('GameMoveMemo'));
    Board := TDraughtsBoardControl(AForm.FindComponent('MainBoard'));
    for I := 0 to View.Items.Count - 1 do
      if Int64(PtrUInt(View.Items[I].Data)) = Target then
      begin
        View.Selected := View.Items[I];
        Break;
      end;
    Check(Int64(PtrUInt(View.Selected.Data)) = Target, 'select nested tree position');
    View.OnClick(View);
    Expected.SetBeginPosition;
    Expected.PlayMove('32-28');
    Expected.PlayMove('20-24');
    Expected.PlayMove('38-32');
    Expected.PlayMove('18-22');
    CheckPosition('tree click must display that node on the main board');
    Check(Pos('18-22', Memo.SelText) > 0, 'tree click must select the matching memo move');
    LayoutItem := TMenuItem(Window.FindComponent('GameTreeNestedLayout'));
    Check((LayoutItem <> nil) and not LayoutItem.Checked, 'notation layout is the default');
    LayoutItem.OnClick(LayoutItem);
    Check(LayoutItem.Checked and (SelectedGameTreeNodeId(View) = Target), 'popup switches to nested without moving cursor');
    CheckPosition('switching layout preserves displayed board');
    LayoutItem.OnClick(LayoutItem);
    Check(not LayoutItem.Checked and (SelectedGameTreeNodeId(View) = Target), 'popup returns to notation with same selection');
    Key := VK_LEFT;
    View.OnKeyDown(View, Key, []);
    Expected.SetBeginPosition;
    Expected.PlayMove('32-28');
    Expected.PlayMove('20-24');
    Expected.PlayMove('38-32');
    CheckPosition('tree keyboard Left must use the shared cursor parent');
    Key := VK_RIGHT;
    View.OnKeyDown(View, Key, []);
    Expected.PlayMove('18-22');
    CheckPosition('tree keyboard Right must restore the selected continuation');
    Memo.SelStart := Pos('18-23', Memo.Text) - 1;
    Memo.SelLength := 0;
    Memo.OnClick(Memo);
    Check(Int64(PtrUInt(View.Selected.Data)) = AForm.ActiveGameTree.MainlineNode[2].NodeId,
      'memo clicks must also update the tree selection');
    // A frozen tree view may still contain rows for a branch removed by a command.
    Actor := TGameTreeActor.Create(AForm.ActiveGameTree, False);
    try
      Command := Actor.CreateClearBranchesCommand;
      try
        Actor.ExecuteCommand(Command);
        Check(Command.Accepted, 'remove tree-window branch fixture');
      finally
        Command.Free;
      end;
    finally
      Actor.Free;
    end;
    for I := 0 to View.Items.Count - 1 do
      if Int64(PtrUInt(View.Items[I].Data)) = Target then
      begin
        View.Selected := View.Items[I];
        Break;
      end;
    View.OnClick(View);
    Expected.SetBeginPosition;
    Expected.PlayMove('32-28');
    Expected.PlayMove('18-23');
    CheckPosition('clicking a stale removed-node row must not retarget the board');
    Key := VK_ESCAPE;
    View.OnKeyDown(View, Key, []);
    Expected.SetBeginPosition;
    Expected.PlayMove('32-28');
    Expected.PlayMove('18-23');
    CheckPosition('tree Escape must return the shared cursor to the mainline tip');
    View.Selected := View.Items[1]; // Event metadata belongs to the root position.
    View.OnClick(View);
    Expected.SetBeginPosition;
    CheckPosition('metadata rows must select their enclosing position');
    Key := VK_ESCAPE;
    View.OnKeyDown(View, Key, []);
  finally
    Expected.Free;
    Game.Free;
  end;
end;

procedure CheckPvReplayIsValidated(AForm: TMainForm);
var
  Browser: TPvBrowser;
  Base, Displayed, Expected: TDraughtsBoard;
  BasePosition: TDraughtsPosition;

  Memo: TMemo;
  Info: TLabel;
  Key: Word;

  function B: TDraughtsPosition;
  begin
    BasePosition.AssignBoard(Base);
    Result := BasePosition;
  end;
begin
  Base := TDraughtsBoard.Create;
  BasePosition := TDraughtsPosition.Create;
  Displayed := TDraughtsBoard.Create;
  Expected := TDraughtsBoard.Create;
  Memo := TMemo.Create(nil);
  Info := TLabel.Create(nil);
  Memo.Parent := AForm;
  Memo.Enabled := False;
  Browser := TPvBrowser.Create(Displayed, nil, Info, Memo);
  try
    Base.SetBeginPosition;
    Expected.AssignFrom(Base);
    Expected.PlayMove('32-28');
    Browser.SetData(B, 0, DefaultStartingFEN, '32-28 28-23 19-24', '', '', '');
    Check(Displayed.CurrentFEN = Expected.CurrentFEN,
      'a wrong-side PV move must stop at the last legal position');
    Check(Pos('Invalid PV move 2: 28-23', Memo.Text) > 0,
      'invalid PV move must be identified in the memo');
    Memo.SelStart := Pos('19-24', Memo.Text) - 1;
    Memo.OnClick(Memo);
    Check((Displayed.CurrentFEN = Expected.CurrentFEN) and
      (Memo.SelText = '1.32-28'),
      'clicking past an invalid PV move must select the last legal position');
    Check(Pos('browsing; Esc to resume', Info.Caption) > 0, 'PV label indicates browsing');
    Browser.SetData(B, 0, DefaultStartingFEN, '33-28', '0.2', '20', '1');
    Check(Pos('newer PV pending', Info.Caption) > 0, 'PV label indicates pending update');
    Key := VK_ESCAPE;
    Memo.OnKeyDown(Memo, Key, []);
    Check((Pos('browsing', Info.Caption) = 0) and (Pos('score 0.2', Info.Caption) > 0),
      'Escape resumes newest PV and clears browsing label');
    Browser.SetData(B, 0, DefaultStartingFEN,
      '32-28 19-23 46-41 23x32', '', '', '');
    Expected.PlayMove('19-23');
    Check(Displayed.CurrentFEN = Expected.CurrentFEN,
      'an impossible PV move must not change any board square');
    Check(Pos('Invalid PV move 3: 46-41', Memo.Text) > 0,
      'impossible PV continuation must be marked');
    Browser.SetData(B, 0, DefaultStartingFEN, 'nonsense 32-28', '', '', '');
    Check((Displayed.CurrentFEN = Base.CurrentFEN) and
      (Pos('Invalid PV move 1: nonsense', Memo.Text) > 0),
      'a malformed first PV move must show the base position with an explanation');
    Base.LoadFromFEN('W:W37,45:B32,22,5');
    Expected.AssignFrom(Base);
    Expected.PlayMove('37x17');
    Expected.PlayMove('5-10');
    Expected.PlayMove('45-40');
    Browser.SetData(B, 0, Base.CurrentFEN, '37x17 5-10 45-40', '', '', '');
    Check(Displayed.CurrentFEN = Expected.CurrentFEN,
      'short-form multiple capture must replay the complete legal PV');
    Check(Pos('Invalid PV', Memo.Text) = 0, 'new legal PV must clear old warnings');
    Memo.SelStart := Pos('37x17', Memo.Text) - 1;
    Memo.OnClick(Memo);
    Expected.AssignFrom(Base);
    Expected.PlayMove('37x17');
    Base.SetBeginPosition;
    Browser.SetData(B, 0, DefaultStartingFEN, '19-24', '', '', '');
    Check(Displayed.CurrentFEN = Expected.CurrentFEN,
      'pending invalid PV must not replace a frozen legal position');
    Key := VK_ESCAPE;
    Memo.OnKeyDown(Memo, Key, []);
    Check((Displayed.CurrentFEN = Base.CurrentFEN) and
      (Pos('Invalid PV move 1: 19-24', Memo.Text) > 0),
      'unfreezing must validate pending PV data and show its warning');
  finally
    Browser.Free;
    Info.Free;
    Memo.Free;
    Expected.Free;
    Displayed.Free;
    BasePosition.Free;
    Base.Free;
  end;
end;

procedure CheckFrozenPvSurvivesRefresh(AForm: TMainForm);
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Memo: TMemo; MovesMemo: TGameNotationView;
  MiniBoard: TDraughtsBoardControl;
  Expected: TDraughtsBoard;
  Key: Word;
  FrozenText: string;
begin
  AForm.LoadStandaloneFen(DefaultStartingFEN);
  Actor := TGameTreeActor.Create(AForm.ActiveGameTree, False);
  Expected := TDraughtsBoard.Create;
  try
    Command := Actor.CreateRecordEnginePVCommand(AForm.ActiveGameTree.Root.NodeId,
      '0.25', '32-28 18-23 37-32');
    try
      Actor.ExecuteCommand(Command);
      Check(Command.Accepted, 'PV refresh fixture must be accepted');
    finally
      Command.Free;
    end;
    MovesMemo := TGameNotationView(AForm.FindComponent('GameMoveMemo'));
    Key := VK_LEFT;
    MovesMemo.OnKeyDown(MovesMemo, Key, []);
    Memo := TMemo(AForm.FindComponent('EnginePvMemo'));
    MiniBoard := TDraughtsBoardControl(AForm.FindComponent('EnginePvBoard'));
    Check((Memo <> nil) and (MiniBoard <> nil), 'named PV controls');
    Memo.Enabled := False; // Invoke events directly without focusing the hidden form.
    Memo.SelStart := Pos('18-23', Memo.Text) - 1;
    Check(Memo.SelStart >= 0, 'PV fixture must be visible');
    Memo.OnClick(Memo);
    Expected.SetBeginPosition;
    Expected.PlayMove('32-28');
    Expected.PlayMove('18-23');
    Check(MiniBoard.Board.CurrentFEN = Expected.CurrentFEN,
      'PV click must show the selected PV position');
    FrozenText := Memo.Text;
    // Selecting the standalone game runs the same full refresh as a game update.
    with TListBox(AForm.FindComponent('GameHistoryList')) do
      OnClick(nil);
    Check(MiniBoard.Board.CurrentFEN = Expected.CurrentFEN,
      'main display refresh must not overwrite the frozen PV board');
    Check(Memo.Text = FrozenText, 'frozen PV text must remain paired with its board');
    Key := VK_ESCAPE;
    Memo.OnKeyDown(Memo, Key, []);
    Expected.PlayMove('37-32');
    Check(MiniBoard.Board.CurrentFEN = Expected.CurrentFEN,
      'Escape must return the PV board to the latest complete line');
    Memo.Enabled := True;
  finally
    Expected.Free;
    Actor.Free;
  end;
end;

procedure CheckExportDoesNotMutate(AForm: TMainForm);
var
  Game: TRunningGame;
  Setup: TGameSetup;
  Moves, Saved: TStringList;
  BeforeText, Exported, FileName: string;
  Revision: Int64;
  I: Integer;

  procedure Execute(ACommand: TGameTreeCommand);
  begin
    try
      Game.GameTreeActor.ExecuteCommand(ACommand);
      Check(ACommand.Accepted, 'export fixture command: ' + ACommand.ErrorText);
    finally
      ACommand.Free;
    end;
  end;
begin
  BeforeText := GameTreeToPdnText(AForm.ActiveGameTree);
  for I := 1 to 5 do
  begin
    Exported := AForm.CurrentGameTreePdnText('Export-only event');
    Check(Pos('[Event "Export-only event"]', Exported) > 0,
      'event override must appear in exported text');
    Check(GameTreeToPdnText(AForm.ActiveGameTree) = BeforeText,
      'standalone export must not change model headers or content');
  end;
  Setup := Default(TGameSetup);
  Setup.StartingFEN := DefaultStartingFEN;
  Setup.TimeControl := DefaultTimeControl;
  Game := TRunningGame.Create(999, 'Export test', nil, pkHuman, pkHuman,
    '', '', 'Old White', 'Old Black', nil, Setup);
  Moves := TStringList.Create;
  Saved := TStringList.Create;
  FileName := GetTempFileName(GetTempDir, 'gwd');
  try
    TextToMoveList('32-28 18-23', Moves);
    Execute(Game.GameTreeActor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('export', 'Corrected event', 'Corrected White',
        'Corrected Black', '2-0', DefaultStartingFEN, False, DefaultTimeControl,
        gosGameOver),
      GameTreeMainlineInput(Moves, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
    Execute(Game.GameTreeActor.CreateRecordAnnotatorPVCommand(
      Game.GameTree.MainlineNode[1].NodeId, '0.75', '18-23'));
    BeforeText := GameTreeToPdnText(Game.GameTree);
    Revision := Game.GameTreeActor.Revision;
    AForm.AppendRunningGameToPdn(Game, FileName, 'Tournament export');
    Saved.LoadFromFile(FileName);
    Check(Pos('[Event "Tournament export"]', Saved.Text) > 0,
      'running export must use requested event without changing the model');
    Check(Pos('[White "Corrected White"]', Saved.Text) > 0,
      'running export must read names from the authoritative tree');
    Check(Pos('32-28', Saved.Text) > 0, 'running export must retain played moves');
    Check((Game.GameTreeActor.Revision = Revision) and
      (GameTreeToPdnText(Game.GameTree) = BeforeText),
      'export must not reapply a retained runner snapshot or mutate revision');
    Check((Game.GameTree.ResultText = '2-0') and
      (Game.GameTree.GameState = gosGameOver),
      'export must preserve the recorded terminal result');
  finally
    DeleteFile(FileName);
    Saved.Free;
    Moves.Free;
    Game.Free;
  end;
end;

var
  Form: TMainForm;
  Game: TPdnGame;
  Reporter: TTestExceptionReporter;
begin
  if ParamStr(1) = '--history-white' then
  begin
    FakeHistoryHub('32-28'); Halt(0);
  end;
  if ParamStr(1) = '--history-black' then
  begin
    FakeHistoryHub('23x32'); Halt(0);
  end;
  RequireDerivedFormResource := False;
  Application.Initialize;
  Reporter := TTestExceptionReporter.Create;
  Application.OnException := @Reporter.Report;
  try
    Form := TMainForm.Create(nil);
    Game := TPdnGame.Create;
    try
      Check(not GameTreeHasContent(Form.ActiveGameTree),
        'untouched initial board should not prompt to save');
      CheckInvalidDisplayIsVisible(Form);
      CheckEvaluationDisplay;
      CheckNotationTreeLayouts;
      CheckNodeDataImport(Form);
      CheckLandingCaptureImport(Form);
      CheckModalDatabaseImport(Form);
      CheckParsedLiteralComments(Form);
      CheckNotationSelectionAndFilters(Form);
      CheckCoalescedRunnerHistory(Form);
      CheckStandaloneMainlineCanBeExtended(Form);
      CheckCompletedGameKeepsOfficialMainline(Form);
      CheckUnexpectedDialogsAbort;
      CheckTreeWindowUsesSameCursor(Form);
      CheckPvReplayIsValidated(Form);
      CheckFrozenPvSurvivesRefresh(Form);
      CheckNestedGuiNavigation(Form);
      CheckBlackStartVariationNavigation(Form);
      CheckMalformedVariationWarningsInGui(Form);
      CheckExportDoesNotMutate(Form);
      Game.EventName := 'Standalone test';
      Game.MovesText := '32-28 18-23';
      Game.InitialCommentText := 'Introduction';
      Game.MoveAnnotationsText := 'Good move' + LineEnding;
      Game.MoveVariationsText := EncodePdnVariationLine(2, 1, '19-23');
      Game.MoveVariationAnnotationsText := 'Alternative reply';
      Form.LoadPdnGameToDisplay(Game);
      Check(GameTreeHasContent(Form.ActiveGameTree),
        'annotated standalone PDN should be saveable');
      CheckStandaloneSurvivesRunningGame(Form, 'W:W31-50:B1-20', 2);
      Form.Free;
      Form := nil;
      Form := TMainForm.Create(nil);
      Form.LoadStandaloneFen('B:WK32,K33:BK1,K2');
      Check(GameTreeHasContent(Form.ActiveGameTree),
        'FEN-only board should be saveable even without moves');
      CheckStandaloneSurvivesRunningGame(Form, 'B:WK32,K33:BK1,K2', 0);
    finally
      Game.Free;
      Form.Free;
      Application.OnException := nil;
      Reporter.Free;
    end;
    WriteLn('OK');
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.ClassName, ': ', E.Message);
      DumpExceptionBackTrace(Output);
      Halt(1);
    end;
  end;
end.
