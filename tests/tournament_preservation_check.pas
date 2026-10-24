program tournament_preservation_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, StdCtrls, Grids,
  uTournamentDialog, uTournamentGridModel, uMainForm, uGameSetupForm,
  uGameOrchestrator, uGameTreeActor, uGameTreeBuilder;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

procedure WriteFixture(const FileName, Name: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := '{"tournament_name":"' + Name + '","games":[' +
      '{"game":1,"round":1,"white":"White","black":"Black",' +
      '"result":"*","reason":""}]}';
    Lines.SaveToFile(FileName);
  finally
    Lines.Free;
  end;
end;

function NewGame(Id: Integer): TRunningGame;
var
  Setup: TGameSetup;
begin
  Setup := Default(TGameSetup);
  Setup.StartingFEN := 'W:W31-50:B1-20';
  Setup.TimeControl := DefaultTimeControl;
  Result := TRunningGame.Create(Id, 'Tournament regression', nil,
    pkHuman, pkHuman, '', '', 'White', 'Black', nil, Setup);
end;

procedure CompleteGame(Game: TRunningGame; const ResultText: string);
var
  Command: TGameTreeCommand;
begin
  Command := Game.GameTreeActor.CreateSetHeaderCommand(
    GameTreeHeaderInput('test', 'Tournament regression', 'White', 'Black',
      ResultText, 'W:W31-50:B1-20', False, DefaultTimeControl, gosGameOver));
  try
    Game.GameTreeActor.ExecuteCommand(Command);
    Check(Command.Accepted, 'fixture result must be accepted');
  finally
    Command.Free;
  end;
  Game.MarkFinished;
end;

procedure CheckCompletionIsAppliedOnce(const Fixture: string);
var
  Dialog: TTournamentDialog;
  Game: TRunningGame;
  Grid: TStringGrid;
begin
  Dialog := TTournamentDialog.Create(nil);
  Game := NewGame(101);
  try
    Dialog.LoadTournamentFromFile(Fixture);
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    Dialog.RegisterRunningGame(1, Game);
    CompleteGame(Game, '2-0');
    Dialog.GameStopped(Game);
    Check(Grid.Cells[TournamentColResult, 1] = '2-0', 'first completion result');
    Dialog.SetSelectedResult('1-1');
    Check(Grid.Cells[TournamentColReason, 1] = 'Manual result',
      'manual override must always have an explicit reason');
    Dialog.GameStopped(Game);
    Check(Grid.Cells[TournamentColResult, 1] = '1-1',
      'duplicate completion must not overwrite a manual override');
    Dialog.RescheduleSelectedGame(nil);
    Dialog.GameStopped(Game);
    Check((Grid.Cells[TournamentColResult, 1] = '*') and
      (Grid.Cells[TournamentColReason, 1] = ''),
      'old completion must not restore the result of a rescheduled row');
  finally
    Game.Free;
    Dialog.Free;
  end;
end;

procedure CheckPairingChangesWaitForShutdown(const Fixture, OtherFile: string);
var
  Dialog: TTournamentDialog;
  Game: TRunningGame;
  Grid: TStringGrid;
  Name: TEdit;
  I: Integer;
  Button: TButton;
const
  Names: array[0..3] of string = ('CreatePairing', 'ClearPairing',
    'LoadTournament', 'ApplyTournamentChanges');
begin
  Dialog := TTournamentDialog.Create(nil);
  Game := NewGame(102);
  try
    Dialog.LoadTournamentFromFile(Fixture);
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    Name := TEdit(Dialog.FindComponent('TournamentName'));
    Dialog.RegisterRunningGame(1, Game);
    Game.RequestStop('regression');
    Check(Dialog.IsRunning, 'pending shutdown must count as running');
    for I := Low(Names) to High(Names) do
    begin
      Button := TButton(Dialog.FindComponent(Names[I]));
      Check((Button <> nil) and Assigned(Button.OnClick), 'missing test action');
      Button.OnClick(Button);
      Check(Dialog.IsRunning, 'pairing action must retain pending game reference');
      Check(Grid.Cells[TournamentColWhite, 1] = 'White',
        'pairing action must not clear running rows');
    end;
    Dialog.LoadTournamentFromFile(OtherFile);
    Check(Name.Text = 'Original', 'direct load must also reject replacement while stopping; got=' + Name.Text);
    CompleteGame(Game, '0-2');
    Dialog.GameStopped(Game);
    Check(not Dialog.IsRunning, 'completed game must release running reference');
    Check(Grid.Cells[TournamentColResult, 1] = '0-2',
      'completion must still update the preserved row');
  finally
    Game.Free;
    Dialog.Free;
  end;
end;

var
  Fixture, OtherFile: string;
begin
  RequireDerivedFormResource := False;
  Application.Initialize;
  Fixture := GetTempFileName(GetTempDir, 'gwd');
  OtherFile := Fixture + '.other';
  try
    try
      WriteFixture(Fixture, 'Original');
      WriteFixture(OtherFile, 'Other');
      CheckCompletionIsAppliedOnce(Fixture);
      CheckPairingChangesWaitForShutdown(Fixture, OtherFile);
      WriteLn('OK');
    finally
      DeleteFile(OtherFile);
      DeleteFile(Fixture);
    end;
  except
    on E: Exception do
    begin
      WriteLn('FAIL: ', E.ClassName, ': ', E.Message);
      DumpExceptionBackTrace(Output);
      Halt(1);
    end;
  end;
end.
