program standalone_preservation_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, StdCtrls, ExtCtrls, LCLType,
  uBoardControl, uDraughtsBoard, uMainForm, uPdn,
  uGameTree, uGameTreeActor, uGameTreeBuilder, uGameTreePdn, uGameSetupForm, uGameOrchestrator;

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
      CheckFrozenPvSurvivesRefresh(Form);
      CheckNestedGuiNavigation(Form);
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
