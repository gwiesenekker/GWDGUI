program standalone_preservation_check;

{$mode objfpc}{$H+}
{$IFNDEF GWDGUI_NONINTERACTIVE_TEST}
  {$FATAL Build this test with its .lpi project to enable noninteractive dialogs}
{$ENDIF}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, StdCtrls, ExtCtrls, Grids, LCLType, Controls, ComCtrls, Menus,
  uEngineRegistry, uBoardControl, uDraughtsBoard, uMainForm, uPdn, uPdnOpenDialog, uPvBrowser, uGuiDialogs,
  uGameTree, uGameTreeActor, uGameTreeBuilder, uGameTreePdn, uGameSetupForm, uGameOrchestrator, uTreeTestUtils;

type
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
  Memo: TMemo;
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
    Memo := TMemo(AForm.FindComponent('GameMoveMemo'));
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
  Memo: TMemo;
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
    Memo := TMemo(AForm.FindComponent('GameMoveMemo'));
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
      (Grid.Cells[4, 2] = ''), 'PDN list must include both games and mark only the warned one');
    Check(Pos('1 import warning', Status.Caption) > 0, 'PDN status must report parse warnings');
    CanSelect := True;
    Grid.OnSelectCell(Grid, 0, 1, CanSelect);
    Check(Warning.Visible and (Pos('outside its parent line', Warning.Caption) > 0),
      'selecting the affected game must explain the skipped variation');
    Grid.OnSelectCell(Grid, 0, 2, CanSelect);
    Check(not Warning.Visible, 'selecting a clean game must clear the previous warning');
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
  Memo: TMemo;
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
    Memo := TMemo(AForm.FindComponent('GameMoveMemo'));
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
  Memo: TMemo;
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
    Memo := TMemo(AForm.FindComponent('GameMoveMemo'));
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
  Memo: TMemo;
  Board: TDraughtsBoardControl;
  Expected: TDraughtsBoard;
  Target: Int64;
  I: Integer;
  Key: Word;
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;

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
    Memo := TMemo(AForm.FindComponent('GameMoveMemo'));
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
  Memo: TMemo;
  Info: TLabel;
  Key: Word;
begin
  Base := TDraughtsBoard.Create;
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
    Browser.SetData(Base, 0, DefaultStartingFEN, '32-28 28-23 19-24', '', '', '');
    Check(Displayed.CurrentFEN = Expected.CurrentFEN,
      'a wrong-side PV move must stop at the last legal position');
    Check(Pos('Invalid PV move 2: 28-23', Memo.Text) > 0,
      'invalid PV move must be identified in the memo');
    Memo.SelStart := Pos('19-24', Memo.Text) - 1;
    Memo.OnClick(Memo);
    Check((Displayed.CurrentFEN = Expected.CurrentFEN) and
      (Memo.SelText = '1.32-28'),
      'clicking past an invalid PV move must select the last legal position');
    Key := VK_ESCAPE;
    Memo.OnKeyDown(Memo, Key, []);
    Browser.SetData(Base, 0, DefaultStartingFEN,
      '32-28 19-23 46-41 23x32', '', '', '');
    Expected.PlayMove('19-23');
    Check(Displayed.CurrentFEN = Expected.CurrentFEN,
      'an impossible PV move must not change any board square');
    Check(Pos('Invalid PV move 3: 46-41', Memo.Text) > 0,
      'impossible PV continuation must be marked');
    Browser.SetData(Base, 0, DefaultStartingFEN, 'nonsense 32-28', '', '', '');
    Check((Displayed.CurrentFEN = Base.CurrentFEN) and
      (Pos('Invalid PV move 1: nonsense', Memo.Text) > 0),
      'a malformed first PV move must show the base position with an explanation');
    Base.LoadFromFEN('W:W37,45:B32,22,5');
    Expected.AssignFrom(Base);
    Expected.PlayMove('37x17');
    Expected.PlayMove('5-10');
    Expected.PlayMove('45-40');
    Browser.SetData(Base, 0, Base.CurrentFEN, '37x17 5-10 45-40', '', '', '');
    Check(Displayed.CurrentFEN = Expected.CurrentFEN,
      'short-form multiple capture must replay the complete legal PV');
    Check(Pos('Invalid PV', Memo.Text) = 0, 'new legal PV must clear old warnings');
    Memo.SelStart := Pos('37x17', Memo.Text) - 1;
    Memo.OnClick(Memo);
    Expected.AssignFrom(Base);
    Expected.PlayMove('37x17');
    Base.SetBeginPosition;
    Browser.SetData(Base, 0, DefaultStartingFEN, '19-24', '', '', '');
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
    Base.Free;
  end;
end;

procedure CheckFrozenPvSurvivesRefresh(AForm: TMainForm);
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Memo, MovesMemo: TMemo;
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
    MovesMemo := TMemo(AForm.FindComponent('GameMoveMemo'));
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
      CheckParsedLiteralComments(Form);
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
