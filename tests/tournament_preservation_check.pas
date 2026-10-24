program tournament_preservation_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, StdCtrls, Grids, ExtCtrls, FPJSON, JSONParser,
  uTournamentDialog, uTournamentGridModel, uMainForm, uGameSetupForm,
  uGameOrchestrator, uGameTreeActor, uGameTreeBuilder, uPdn;

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

procedure CheckFailedLoadIsTransactional(const Fixture: string);
var
  Dialog: TTournamentDialog;
  Before, After, Bad: TStringList;
  I: Integer;
  Raised: Boolean;
  Fen: TEdit;
  Panel: TPanel;
const
  InvalidDocuments: array[0..6] of string = (
    '{invalid JSON',
    '[]',
    '{"tournament_name":"Partial overwrite","games":[{"white":17}]}',
    '{"tournament_name":"Partial overwrite","games":{}}',
    '{"storage_version":3}',
    '{"games":[{"record":{"manual_result":17}}]}',
    '{"games":[{"game":1,"round":1},{"game":1,"round":1}]}');
begin
  Dialog := TTournamentDialog.Create(nil);
  Before := TStringList.Create;
  After := TStringList.Create;
  Bad := TStringList.Create;
  try
    Dialog.LoadTournamentFromFile(Fixture);
    Dialog.SetSelectedResult('1-1');
    Dialog.SaveTournamentToFile(Fixture + '.before');
    Before.LoadFromFile(Fixture + '.before');
    for I := Low(InvalidDocuments) to High(InvalidDocuments) do
    begin
      Bad.Text := InvalidDocuments[I];
      Bad.SaveToFile(Fixture + '.bad');
      Raised := False;
      try
        Dialog.LoadTournamentFromFile(Fixture + '.bad');
      except
        on E: Exception do
          Raised := True;
      end;
      Check(Raised, 'malformed tournament must be rejected');
      Dialog.SaveTournamentToFile(Fixture + '.after');
      After.LoadFromFile(Fixture + '.after');
      Check(After.Text = Before.Text,
        'failed load must preserve all current settings and results');
    end;
    Fen := TEdit(Dialog.FindComponent('TournamentStartingFEN'));
    Panel := TPanel(Dialog.FindComponent('TournamentSettingsChanged'));
    Fen.Text := 'B:W31-50:B1-20';
    Check(Panel.Visible, 'failed load must not leave change tracking disabled');
  finally
    DeleteFile(Fixture + '.before');
    DeleteFile(Fixture + '.after');
    DeleteFile(Fixture + '.bad');
    Bad.Free;
    After.Free;
    Before.Free;
    Dialog.Free;
  end;
end;

procedure CheckAutosaveAndFailureRecovery(const Fixture: string);
var
  Dialog, Reloaded: TTournamentDialog;
  Game: TRunningGame;
  Name: TEdit;
  OriginalPdn: string;
  Data: TJSONData;
  Lines: TStringList;
begin
  Dialog := TTournamentDialog.Create(nil);
  Reloaded := nil;
  Game := NewGame(103);
  Lines := TStringList.Create;
  try
    WriteFixture(Fixture, 'Recovery test');
    Dialog.LoadTournamentFromFile(Fixture);
    OriginalPdn := Dialog.PdnFileName;
    Name := TEdit(Dialog.FindComponent('TournamentName'));
    Name.Text := 'Renamed tournament';
    Dialog.SetSelectedResult('1-1');
    Check(Dialog.PdnFileName = OriginalPdn, 'renaming must not redirect game records');
    Lines.LoadFromFile(Fixture);
    Data := GetJSON(Lines.Text);
    try
      Check(TJSONObject(Data).Get('tournament_id', '') <> '', 'autosave must retain identity');
      Check(TJSONObject(Data).Get('pdn_file_name', '') = OriginalPdn,
        'autosave must retain the absolute PDN path');
    finally
      Data.Free;
    end;
    Reloaded := TTournamentDialog.Create(nil);
    Reloaded.LoadTournamentFromFile(Fixture);
    Check(TStringGrid(Reloaded.FindComponent('TournamentPairings')).Cells[
      TournamentColResult, 1] = '1-1', 'fresh form must recover autosaved result');
    Reloaded.Free;
    Reloaded := nil;
    Dialog.RescheduleSelectedGame(nil);
    // Make the save destination a directory: replacement must fail safely.
    Check(RenameFile(Fixture, Fixture + '.previous'), 'prepare failed-save fixture');
    Check(CreateDir(Fixture), 'prepare blocked destination');
    Dialog.RegisterRunningGame(1, Game);
    CompleteGame(Game, '2-0');
    Dialog.GameStopped(Game);
    Check(not Dialog.IsRunning, 'save failure must not leave a finished game active');
    Check(Dialog.StorageError <> '', 'save failure must be visible and pause scheduling');
    Check(FileExists(Fixture + '.previous'), 'previous successful save must survive');
    RemoveDir(Fixture);
    Check(RenameFile(Fixture + '.previous', Fixture), 'restore save destination');
    Dialog.SetSelectedResult('1-1');
    Check(Dialog.StorageError = '', 'a successful save must recover after failure');
  finally
    if DirectoryExists(Fixture) then
      RemoveDir(Fixture);
    if FileExists(Fixture + '.previous') then
      RenameFile(Fixture + '.previous', Fixture);
    DeleteFile(OriginalPdn);
    Lines.Free;
    Reloaded.Free;
    Game.Free;
    Dialog.Free;
  end;
end;

procedure CheckUnsavedTournamentGetsRecoveryFile;
var
  Dialog: TTournamentDialog;
  Grid: TStringGrid;
  RecoveryFile: string;
begin
  Dialog := TTournamentDialog.Create(nil);
  RecoveryFile := '';
  try
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, 'White', 'Black', 1);
    Dialog.SetSelectedResult('1-1');
    RecoveryFile := Dialog.SaveFileName;
    Check((Dialog.StorageError = '') and FileExists(RecoveryFile),
      'a tournament without a chosen filename must autosave a recovery file');
    Check(Pos(IncludeTrailingPathDelimiter(GetAppConfigDir(False)), RecoveryFile) = 1,
      'recovery files must use the application config directory');
  finally
    Dialog.Free;
    DeleteFile(RecoveryFile);
    DeleteFile(ChangeFileExt(RecoveryFile, '.pdn'));
  end;
end;

procedure CheckPdnResult(const FileName, ExpectedResult, Attempt: string);
var
  Games: TList;
  Lines: TStringList;
  I: Integer;
begin
  Games := TList.Create;
  Lines := TStringList.Create;
  try
    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 1, 'current pairing must have exactly one PDN game');
    Check(TPdnGame(Games[0]).ResultText = ExpectedResult,
      'PDN result must match the tournament result');
    Lines.LoadFromFile(FileName);
    Check(Pos('[Attempt "' + Attempt + '"]', Lines.Text) > 0, 'attempt identity');
    Check((Pos('[TournamentId "', Lines.Text) > 0) and
      (Pos('[GameNo "1"]', Lines.Text) > 0) and
      (Pos('[Round "1"]', Lines.Text) > 0), 'persistent pairing identity tags');
  finally
    for I := 0 to Games.Count - 1 do
      TObject(Games[I]).Free;
    Lines.Free;
    Games.Free;
  end;
end;

procedure CheckRecordsAndPdnStayConsistent(const Fixture: string);
var
  Dialog, Reloaded: TTournamentDialog;
  First, Second, Third: TRunningGame;
  Lines: TStringList;
  Data: TJSONObject;
  GameData, RecordData: TJSONObject;
  PdnPath: string;
begin
  WriteFixture(Fixture, 'Record preservation');
  Dialog := TTournamentDialog.Create(nil);
  Reloaded := nil;
  First := NewGame(201);
  Second := NewGame(202);
  Third := NewGame(203);
  Lines := TStringList.Create;
  try
    Dialog.LoadTournamentFromFile(Fixture);
    Dialog.RegisterRunningGame(1, First);
    CompleteGame(First, '2-0');
    Dialog.GameStopped(First);
    PdnPath := Dialog.PdnFileName;
    CheckPdnResult(PdnPath, '2-0', '1'); // Result before any moves must be saved.
    Dialog.SetSelectedResult('1-1');
    Dialog.GameStopped(First);
    CheckPdnResult(PdnPath, '1-1', '1');
    Lines.LoadFromFile(PdnPath);
    Check((Pos('[ResultSource "manual"]', Lines.Text) > 0) and
      (Pos('[PlayedResult "2-0"]', Lines.Text) > 0),
      'override must be explicit while retaining the played result');
    Reloaded := TTournamentDialog.Create(nil);
    Reloaded.LoadTournamentFromFile(Fixture);
    CheckPdnResult(Reloaded.PdnFileName, '1-1', '1');
    Reloaded.Free;
    Reloaded := nil;
    Dialog.RescheduleSelectedGame(nil);
    Dialog.RegisterRunningGame(1, Second);
    Reloaded := TTournamentDialog.Create(nil);
    Reloaded.LoadTournamentFromFile(Fixture);
    Check(TStringGrid(Reloaded.FindComponent('TournamentPairings')).Cells[
      TournamentColResult, 1] = '*', 'resume must retain the pending attempt');
    Reloaded.Free;
    Reloaded := nil;
    Dialog.GameStopped(First);
    Check(Dialog.IsRunning, 'old completion must not finish the new attempt');
    CompleteGame(Second, '0-2');
    Dialog.GameStopped(Second);
    CheckPdnResult(PdnPath, '0-2', '2');
    Lines.LoadFromFile(Fixture);
    Data := TJSONObject(GetJSON(Lines.Text));
    try
      GameData := TJSONObject(TJSONArray(Data.Find('games'))[0]);
      RecordData := TJSONObject(GameData.Find('record'));
      Check(TJSONArray(RecordData.Find('history')).Count = 1,
        'rescheduled attempt must remain in JSON history');
      Check(TJSONObject(TJSONArray(RecordData.Find('history'))[0]).Get(
        'manual_result', '') = '1-1', 'attempt history must retain its override');
    finally
      Data.Free;
    end;
    // JSON is authoritative: loading must repair a stale or damaged PDN projection.
    Lines.Text := 'stale export';
    Lines.SaveToFile(PdnPath);
    Reloaded := TTournamentDialog.Create(nil);
    Reloaded.LoadTournamentFromFile(Fixture);
    CheckPdnResult(PdnPath, '0-2', '2');
    Reloaded.Free;
    Reloaded := nil;
    Dialog.RescheduleSelectedGame(nil);
    Dialog.RegisterRunningGame(1, Third);
    DeleteFile(PdnPath);
    Check(CreateDir(PdnPath), 'prepare blocked PDN projection');
    CompleteGame(Third, '2-0');
    Dialog.GameStopped(Third);
    Check((not Dialog.IsRunning) and (Dialog.StorageError <> ''),
      'failed PDN write must pause without keeping a finished row active');
    RemoveDir(PdnPath);
    Reloaded := TTournamentDialog.Create(nil);
    Reloaded.LoadTournamentFromFile(Fixture);
    CheckPdnResult(PdnPath, '2-0', '3');
    Check(Reloaded.StorageError = '', 'saved JSON must recover a failed PDN write');
  finally
    if DirectoryExists(PdnPath) then
      RemoveDir(PdnPath);
    Lines.Free;
    Third.Free;
    Second.Free;
    First.Free;
    Dialog.Free;
    Reloaded.Free;
  end;
end;

procedure CheckByeSurvivesReload(const Fixture: string);
var
  Dialog, Reloaded: TTournamentDialog;
  Grid: TStringGrid;
begin
  WriteFixture(Fixture, 'Swiss bye');
  Dialog := TTournamentDialog.Create(nil);
  Reloaded := TTournamentDialog.Create(nil);
  try
    Dialog.LoadTournamentFromFile(Fixture);
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    Grid.Cells[TournamentColBlack, 1] := 'BYE';
    Grid.Cells[TournamentColResult, 1] := '2-0';
    Grid.Cells[TournamentColReason, 1] := 'Bye';
    Dialog.SaveTournamentToFile(Fixture);
    Reloaded.LoadTournamentFromFile(Fixture);
    Grid := TStringGrid(Reloaded.FindComponent('TournamentPairings'));
    Check(Grid.Cells[TournamentColResult, 1] = '2-0',
      'a bye must retain its awarded points after reload');
    Check(Grid.Cells[TournamentColReason, 1] = 'Bye',
      'a bye must retain its reason after reload');
    Check(not FileExists(Reloaded.PdnFileName),
      'a bye must not produce a fictitious played game');
  finally
    Reloaded.Free;
    Dialog.Free;
  end;
end;

procedure CheckLegacyPdnIsPreserved(const Fixture: string);
var
  Dialog: TTournamentDialog;
  Lines: TStringList;
  LegacyPath: string;
begin
  WriteFixture(Fixture, 'Legacy preservation');
  LegacyPath := ChangeFileExt(Fixture, '.pdn');
  Lines := TStringList.Create;
  Dialog := TTournamentDialog.Create(nil);
  try
    Lines.Text := 'Original unlinked archive: keep exactly';
    Lines.SaveToFile(LegacyPath);
    Dialog.LoadTournamentFromFile(Fixture);
    Check(Dialog.PdnFileName <> LegacyPath,
      'legacy archives without persistent records must not be overwritten');
    Dialog.SetSelectedResult('1-1');
    CheckPdnResult(Dialog.PdnFileName, '1-1', '1');
    Lines.LoadFromFile(LegacyPath);
    Check(Trim(Lines.Text) = 'Original unlinked archive: keep exactly',
      'migration must preserve the older PDN file');
  finally
    Dialog.Free;
    Lines.Free;
  end;
end;

var
  Fixture, OtherFile, TestDirectory: string;
  Id: TGUID;
  Search: TSearchRec;
begin
  RequireDerivedFormResource := False;
  Application.Initialize;
  Check(CreateGUID(Id) = 0, 'test directory identity');
  TestDirectory := IncludeTrailingPathDelimiter(GetTempDir) + 'gwdtour-' + GUIDToString(Id);
  Check(CreateDir(TestDirectory), 'create isolated test directory');
  Fixture := IncludeTrailingPathDelimiter(TestDirectory) + 'tournament.json';
  OtherFile := IncludeTrailingPathDelimiter(TestDirectory) + 'other.json';
  try
    try
      WriteFixture(Fixture, 'Original');
      WriteFixture(OtherFile, 'Other');
      CheckCompletionIsAppliedOnce(Fixture);
      CheckFailedLoadIsTransactional(Fixture);
      CheckPairingChangesWaitForShutdown(Fixture, OtherFile);
      CheckAutosaveAndFailureRecovery(Fixture);
      CheckUnsavedTournamentGetsRecoveryFile;
      CheckRecordsAndPdnStayConsistent(IncludeTrailingPathDelimiter(TestDirectory) + 'records.json');
      CheckLegacyPdnIsPreserved(IncludeTrailingPathDelimiter(TestDirectory) + 'legacy.json');
      CheckByeSurvivesReload(IncludeTrailingPathDelimiter(TestDirectory) + 'bye.json');
      WriteLn('OK');
    finally
      if FindFirst(IncludeTrailingPathDelimiter(TestDirectory) + '*', faAnyFile, Search) = 0 then
      begin
        repeat
          if (Search.Name <> '.') and (Search.Name <> '..') then
            DeleteFile(IncludeTrailingPathDelimiter(TestDirectory) + Search.Name);
        until FindNext(Search) <> 0;
        FindClose(Search);
      end;
      RemoveDir(TestDirectory);
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
