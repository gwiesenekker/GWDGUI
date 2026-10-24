program standalone_preservation_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, StdCtrls, ExtCtrls, uMainForm, uPdn,
  uGameTree, uGameTreePdn, uGameSetupForm, uGameOrchestrator;

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

var
  Form: TMainForm;
  Game: TPdnGame;
begin
  RequireDerivedFormResource := False;
  Application.Initialize;
  Form := TMainForm.Create(nil);
  Game := TPdnGame.Create;
  try
    Check(not GameTreeHasContent(Form.ActiveGameTree),
      'untouched initial board should not prompt to save');
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
  end;
  WriteLn('OK');
end.
