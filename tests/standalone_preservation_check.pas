program standalone_preservation_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, StdCtrls, ExtCtrls, LCLType,
  uBoardControl, uDraughtsBoard, uMainForm, uPdn,
  uGameTree, uGameTreeBuilder, uGameTreePdn, uGameSetupForm, uGameOrchestrator;

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
      CheckNestedGuiNavigation(Form);
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
