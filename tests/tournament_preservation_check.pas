program tournament_preservation_check;
{$mode objfpc}{$H+}
{$IFNDEF GWDGUI_NONINTERACTIVE_TEST}
  {$FATAL Build this test with its .lpi project to enable noninteractive dialogs}
{$ENDIF}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, StdCtrls, Grids, ExtCtrls, CheckLst, Controls, FPJSON, JSONParser, uGuiDialogs,
  uEngineRegistry, uTournamentStorage, uTournamentDialog, uTournamentGridModel, uMainForm, uRunningGame, uGameSetupTypes,
  uGameOrchestrator, uGameTreeActor, uGameTreeBuilder, uPdn, uDraughtsPosition;

type
  TFailingCaptureTournament = class(TTournamentDialog)
  public
    FailCapture: Boolean;
    function CaptureGamePdn(AGame: TObject): string; override;
  end;
function TFailingCaptureTournament.CaptureGamePdn(AGame: TObject): string;
begin
  if FailCapture then raise EInOutError.Create('injected capture failure');
  Result := inherited CaptureGamePdn(AGame);
end;

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
    Dialog.SetSelectedResult('*');
    Check(Grid.Cells[TournamentColResult, 1] = '2-0', 'clearing an override restores its played result');
    Dialog.SetSelectedResult('1-1');
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

procedure CheckCaptureFailureStopsCleanly(const Fixture: string);
var Dialog: TFailingCaptureTournament; Game: TRunningGame;
begin
  Dialog := TFailingCaptureTournament.Create(nil);
  Game := NewGame(104);
  try
    WriteFixture(Fixture, 'Capture failure');
    Dialog.LoadTournamentFromFile(Fixture);
    Dialog.RegisterRunningGame(1, Game);
    CompleteGame(Game, '2-0');
    Dialog.FailCapture := True;
    Dialog.GameStopped(Game);
    Check(not Dialog.IsRunning and (Dialog.StorageError = '') and
      (Pos('Capture failed', TStringGrid(Dialog.FindComponent('TournamentPairings')).Cells[TournamentColReason, 1]) > 0),
      'capture failure must pause without leaving a finished row active');
    Dialog.SetSelectedResult('1-1'); // manual edit while the failed capture is pending
    Dialog.FailCapture := False;
    Dialog.GameStopped(Game);
    Check(TStringGrid(Dialog.FindComponent('TournamentPairings')).Cells[TournamentColResult, 1] = '1-1',
      'a successful capture retry must preserve a pending manual override');
    Check(Dialog.StorageError = '', 'a pending capture must be retryable after its failure is corrected');
    Dialog.SetSelectedResult('1-1');
    Dialog.GameStopped(Game);
    Check(TStringGrid(Dialog.FindComponent('TournamentPairings')).Cells[TournamentColResult, 1] = '1-1',
      'successful capture retries must not enable stale completion overwrites');
  finally Game.Free; Dialog.Free; end;
end;

procedure CheckCaptureFailureDoesNotBlockSaving(const Fixture: string);
var Dialog: TFailingCaptureTournament; Reloaded: TTournamentDialog;
  Game: TRunningGame; Grid: TStringGrid; Data: TJSONObject;
begin
  WriteFixture(Fixture, 'Capture isolation');
  Dialog := TFailingCaptureTournament.Create(nil); Reloaded := TTournamentDialog.Create(nil);
  Game := NewGame(105);
  try
    Dialog.LoadTournamentFromFile(Fixture); Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, 'Other White', 'Other Black', 1);
    Dialog.RegisterRunningGame(1, Game); CompleteGame(Game, '2-0');
    Dialog.FailCapture := True; Dialog.GameStopped(Game);
    Check(Dialog.StorageError = '', 'capture failure is row data, not a global storage failure');
    Grid.Row := 2; Dialog.SetSelectedResult('1-1');
    Dialog.SaveTournamentToFile(Fixture + '.saved');
    Reloaded.LoadTournamentFromFile(Fixture + '.saved');
    Check(TStringGrid(Reloaded.FindComponent('TournamentPairings')).Cells[TournamentColResult, 2] = '1-1',
      'other results remain editable and durable while a capture is pending');
    Data := ReadTournamentDocument(Fixture + '.saved');
    try Check(Pos('capture_error', Data.AsJSON) > 0, 'capture diagnostic is persisted explicitly');
    finally Data.Free; end;
    Dialog.GameRemoved(Game); FreeAndNil(Game);
    Dialog.SaveTournamentToFile(Fixture + '.after-removal');
    Grid.Row := 1; Dialog.RescheduleSelectedGame(nil);
    Check((Grid.Cells[TournamentColResult, 1] = '*') and (Grid.Cells[TournamentColReason, 1] = ''),
      'failed capture row can be rescheduled after its live game is removed');
    Dialog.SaveTournamentToFile(Fixture + '.rescheduled');
  finally Game.Free; Reloaded.Free; Dialog.Free; end;
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
  InvalidDocuments: array[0..7] of string = (
    '{invalid JSON',
    '[]',
    '{"tournament_name":"Partial overwrite","games":[{"white":17}]}',
    '{"tournament_name":"Partial overwrite","games":{}}',
    '{"storage_version":3}',
    '{"pdn_owned":"yes"}',
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
      Check(TJSONObject(Data).Get('pdn_file_name', '') = ExtractFileName(OriginalPdn),
        'autosave must retain a relative PDN path');
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

function FileContents(const FileName: string): string; forward;

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
    // A damaged/unrelated projection is preserved; rebuild at a fresh path.
    Lines.Text := 'stale export';
    Lines.SaveToFile(PdnPath);
    Reloaded := TTournamentDialog.Create(nil);
    Reloaded.LoadTournamentFromFile(Fixture);
    Check(FileContents(PdnPath) = 'stale export' + LineEnding, 'preserve unverified PDN content');
    PdnPath := Reloaded.PdnFileName;
    CheckPdnResult(PdnPath, '0-2', '2');
    Reloaded.Free;
    Reloaded := nil;
    Dialog.RescheduleSelectedGame(nil);
    Dialog.RegisterRunningGame(1, Third);
    PdnPath := Dialog.PdnFileName;
    DeleteFile(PdnPath);
    Check(CreateDir(PdnPath), 'prepare blocked PDN projection');
    CompleteGame(Third, '2-0');
    Dialog.GameStopped(Third);
    Check((not Dialog.IsRunning) and (Dialog.StorageError = '') and DirectoryExists(PdnPath),
      'an occupied directory must remain intact while the projection chooses a new path');
    RemoveDir(PdnPath);
    Reloaded := TTournamentDialog.Create(nil);
    Reloaded.LoadTournamentFromFile(Fixture);
    PdnPath := Reloaded.PdnFileName;
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

function FileContents(const FileName: string): string;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, Stream.Size);
    if Result <> '' then Stream.ReadBuffer(Result[1], Length(Result));
  finally
    Stream.Free;
  end;
end;

function TournamentId(const FileName: string): string;
var
  Data: TJSONObject;
begin
  Data := TJSONObject(GetJSON(FileContents(FileName)));
  try
    Result := Data.Get('tournament_id', '');
  finally
    Data.Free;
  end;
end;

procedure CheckEmptyResetKeepsStorage(const Fixture: string);
var Dialog: TTournamentDialog; Clear: TButton; OldPath, OldId: string;
begin
  Dialog := TTournamentDialog.Create(nil);
  try
    Dialog.SaveTournamentToFile(Fixture);
    OldPath := Dialog.SaveFileName;
    OldId := TournamentId(OldPath);
    Clear := TButton(Dialog.FindComponent('ClearPairing'));
    Clear.OnClick(Clear);
    Clear.OnClick(Clear);
    Check((Dialog.SaveFileName = OldPath) and (TournamentId(OldPath) = OldId),
      'resetting an empty tournament must not create storage generations');
    AddTournamentPairingRow(TStringGrid(Dialog.FindComponent('TournamentPairings')), 'White', 'Black', 1);
    Dialog.SetSelectedResult('1-1');
    Dialog.RescheduleSelectedGame(nil);
    Clear.OnClick(Clear);
    Check(Dialog.SaveFileName <> OldPath, 'historical attempts must still get a protected generation');
  finally Dialog.Free; end;
end;

procedure CheckResetPreservesSavedFiles(const Fixture: string; Action: Integer);
var
  Dialog, Reloaded: TTournamentDialog;
  Game: TRunningGame;
  Command: TGameTreeCommand;
  Grid: TStringGrid;
  Engines: TCheckListBox;
  Button: TButton;
  JsonBefore, PdnBefore, OldPdn, OldId, NewId, NewJson: string;
begin
  WriteFixture(Fixture, 'Reset preservation');
  Dialog := TTournamentDialog.Create(nil);
  Reloaded := TTournamentDialog.Create(nil);
  Game := NewGame(300 + Action);
  try
    Dialog.LoadTournamentFromFile(Fixture);
    Dialog.RegisterRunningGame(1, Game);
    Command := Game.GameTreeActor.CreateAppendMainlineMoveCommand('32-28', gmsHuman);
    try
      Game.GameTreeActor.ExecuteCommand(Command);
      Check(Command.Accepted, 'reset preservation move fixture');
    finally
      Command.Free;
    end;
    CompleteGame(Game, '2-0');
    Dialog.GameStopped(Game);
    Dialog.SetSelectedResult('1-1');
    OldPdn := Dialog.PdnFileName;
    OldId := TournamentId(Fixture);
    JsonBefore := FileContents(Fixture);
    PdnBefore := FileContents(OldPdn);
    case Action of
      0: begin
        TEdit(Dialog.FindComponent('TournamentStartingFEN')).Text := 'B:W31-50:B1-20';
        Button := TButton(Dialog.FindComponent('ApplyTournamentChanges'));
      end;
      1: begin
        Engines := TCheckListBox(Dialog.FindComponent('TournamentEngines'));
        Engines.Items.Clear;
        Engines.Items.Add('Engine A');
        Engines.Items.Add('Engine B');
        Engines.Checked[0] := True;
        Engines.Checked[1] := True;
        Button := TButton(Dialog.FindComponent('CreatePairing'));
      end;
      else Button := TButton(Dialog.FindComponent('ClearPairing'));
    end;
    {$IFDEF GWDGUI_NONINTERACTIVE_TEST}
    if Action = 2 then
    begin
      GuiTestConfirmationResult := mrNo;
      try
        Button.OnClick(Button);
      finally
        GuiTestConfirmationResult := 0;
      end;
      Check(Dialog.SaveFileName = ExpandFileName(Fixture), 'cancel must retain tournament identity');
      Check((FileContents(Fixture) = JsonBefore) and
        (FileContents(OldPdn) = PdnBefore), 'cancel must leave both saved files untouched');
    end;
    GuiTestConfirmationResult := mrYes;
    {$ENDIF}
    try
      Button.OnClick(Button);
    finally
      {$IFDEF GWDGUI_NONINTERACTIVE_TEST}
      GuiTestConfirmationResult := 0;
      {$ENDIF}
    end;
    Check((FileContents(Fixture) = JsonBefore) and
      (FileContents(OldPdn) = PdnBefore), 'reset must preserve the original JSON and PDN byte for byte');
    NewJson := Dialog.SaveFileName;
    Check((NewJson <> ExpandFileName(Fixture)) and FileExists(NewJson),
      'reset must autosave to a separate file');
    NewId := TournamentId(NewJson);
    Check((NewId <> '') and (NewId <> OldId), 'reset must allocate a new tournament ID');
    Check(Dialog.PdnFileName <> OldPdn, 'reset must not reuse the original PDN target');
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    if Action = 1 then
    begin
      Check(TournamentGridHasPairingAtRow(Grid, 1), 'round robin must create fresh pairings');
      Dialog.SetSelectedResult('0-2');
    end
    else
      Check(TournamentPairingGridIsEmpty(Grid), 'apply and clear must reset the current pairings');
    Reloaded.LoadTournamentFromFile(Fixture);
    Check(TStringGrid(Reloaded.FindComponent('TournamentPairings')).Cells[
      TournamentColResult, 1] = '1-1', 'the original tournament must still reopen with its result');
    CheckPdnResult(OldPdn, '1-1', '1');
    Check(Pos('32-28', FileContents(OldPdn)) > 0, 'the original played game must survive reset');
    Check((FileContents(Fixture) = JsonBefore) and
      (FileContents(OldPdn) = PdnBefore), 'later saves and reopening must preserve the original files');
  finally
    Game.Free;
    Reloaded.Free;
    Dialog.Free;
  end;
end;

procedure CheckResetWaitsForSuccessfulSave(const Fixture: string);
var
  Dialog: TTournamentDialog;
  Grid: TStringGrid;
  Button: TButton;
  Engines: TCheckListBox;
  I: Integer;
  Saved: string;
const
  Names: array[0..2] of string = ('CreatePairing', 'ClearPairing', 'ApplyTournamentChanges');
begin
  WriteFixture(Fixture, 'Failed reset save');
  Dialog := TTournamentDialog.Create(nil);
  try
    Dialog.LoadTournamentFromFile(Fixture);
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    Engines := TCheckListBox(Dialog.FindComponent('TournamentEngines'));
    Engines.Items.Clear;
    Engines.Items.Add('Engine A');
    Engines.Items.Add('Engine B');
    Engines.Checked[0] := True;
    Engines.Checked[1] := True;
    Check(RenameFile(Fixture, Fixture + '.saved'), 'prepare reset save failure');
    Check(CreateDir(Fixture), 'block reset save destination');
    Dialog.SetSelectedResult('1-1');
    Check(Dialog.StorageError <> '', 'unsaved result must report save error');
    for I := Low(Names) to High(Names) do
    begin
      if I = 2 then
        TEdit(Dialog.FindComponent('TournamentStartingFEN')).Text := 'B:W31-50:B1-20';
      Button := TButton(Dialog.FindComponent(Names[I]));
      Check(not Button.Enabled, 'reset actions must be disabled while results remain unsaved');
      Button.OnClick(Button);
      Check((Dialog.SaveFileName = ExpandFileName(Fixture)) and
        (Grid.Cells[TournamentColResult, 1] = '1-1'),
        'direct reset actions must also retain the only in-memory result after a save failure');
    end;
    RemoveDir(Fixture);
    Check(RenameFile(Fixture + '.saved', Fixture), 'restore reset save destination');
    // Revert the pending edit before recovering the original tournament save.
    TEdit(Dialog.FindComponent('TournamentStartingFEN')).Text := 'W:W31-50:B1-20';
    Dialog.SaveTournamentToFile(Fixture);
    Check((Dialog.StorageError = '') and
      TButton(Dialog.FindComponent('CreatePairing')).Enabled,
      'successful explicit save must unblock reset actions');
    Saved := FileContents(Fixture);
    TEdit(Dialog.FindComponent('TournamentStartingFEN')).Text := 'B:W31-50:B1-20';
    Button := TButton(Dialog.FindComponent('ApplyTournamentChanges'));
    Button.OnClick(Button);
    Check((Dialog.SaveFileName <> ExpandFileName(Fixture)) and
      (FileContents(Fixture) = Saved), 'reset after recovery must retain the saved result');
  finally
    if DirectoryExists(Fixture) then RemoveDir(Fixture);
    if FileExists(Fixture + '.saved') then RenameFile(Fixture + '.saved', Fixture);
    Dialog.Free;
  end;
end;

procedure CheckResetPreservesRecoveryFiles;
var
  Dialog: TTournamentDialog;
  Grid: TStringGrid;
  OldJson, OldPdn, NewJson, NewPdn, Saved: string;
begin
  Dialog := TTournamentDialog.Create(nil);
  OldJson := ''; OldPdn := ''; NewJson := ''; NewPdn := '';
  try
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, 'White', 'Black', 1);
    Dialog.SetSelectedResult('1-1');
    OldJson := Dialog.SaveFileName;
    OldPdn := Dialog.PdnFileName;
    Saved := FileContents(OldJson);
    TEdit(Dialog.FindComponent('TournamentStartingFEN')).Text := 'B:W31-50:B1-20';
    with TButton(Dialog.FindComponent('ApplyTournamentChanges')) do OnClick(nil);
    NewJson := Dialog.SaveFileName;
    NewPdn := Dialog.PdnFileName;
    Check((NewJson <> OldJson) and FileExists(NewJson),
      'resetting an unnamed tournament must create a separate recovery file');
    Check(FileContents(OldJson) = Saved, 'the prior recovery JSON must survive reset');
    CheckPdnResult(OldPdn, '1-1', '1');
  finally
    Dialog.Free;
    DeleteFile(OldJson); DeleteFile(OldPdn);
    DeleteFile(NewJson); DeleteFile(NewPdn);
  end;
end;

procedure WriteContents(const FileName, Text: string);
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(FileName, fmCreate);
  try
    if Text <> '' then Stream.WriteBuffer(Text[1], Length(Text));
  finally
    Stream.Free;
  end;
end;

procedure CheckFirstSaveRelocatesRecovery(const Target: string);
var
  Dialog, Reloaded: TTournamentDialog;
  Grid: TStringGrid;
  OldJson, OldPdn, NewPdn, Saved: string;
  Failed: Boolean;
begin
  Dialog := TTournamentDialog.Create(nil);
  Reloaded := TTournamentDialog.Create(nil);
  OldJson := '';
  OldPdn := '';
  NewPdn := '';
  try
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, 'White', 'Black', 1);
    Dialog.SetSelectedResult('1-1');
    OldJson := Dialog.SaveFileName;
    OldPdn := Dialog.PdnFileName;
    Saved := FileContents(OldJson);
    Failed := False;
    try
      Dialog.SaveTournamentToFile(Target + '/missing/file.json');
    except
      on E: Exception do Failed := True;
    end;
    Check(Failed, 'saving to a missing directory must fail');
    Check((Dialog.SaveFileName = OldJson) and (Dialog.PdnFileName = OldPdn) and
      (FileContents(OldJson) = Saved) and FileExists(OldPdn),
      'failed first Save As must preserve recovery paths and files');
    WriteContents(ChangeFileExt(Target, '.pdn'), 'Unrelated archive');
    Dialog.SaveTournamentToFile(Target);
    NewPdn := Dialog.PdnFileName;
    Check((ExtractFilePath(NewPdn) = ExtractFilePath(Target)) and
      (NewPdn <> ChangeFileExt(Target, '.pdn')), 'first Save As must relocate beside JSON safely');
    Check(FileContents(ChangeFileExt(Target, '.pdn')) = 'Unrelated archive',
      'relocation must preserve unrelated PDN');
    Check(not FileExists(OldJson) and not FileExists(OldPdn),
      'successful first Save As must remove obsolete recovery files');
    Reloaded.LoadTournamentFromFile(Target);
    Check((Reloaded.StorageError = '') and (Reloaded.PdnFileName = NewPdn) and
      (TStringGrid(Reloaded.FindComponent('TournamentPairings')).Cells[TournamentColResult, 1] = '1-1'),
      'named save must recover result and relocated projection');
    Dialog.SaveTournamentToFile(Target + '.copy.json');
    Check(Dialog.PdnFileName = NewPdn, 'later Save As must retain an established non-recovery PDN');
  finally
    Dialog.Free;
    Reloaded.Free;
    DeleteFile(OldJson);
    DeleteFile(OldPdn);
    DeleteFile(NewPdn);
  end;
end;

procedure CheckPortableTournamentPaths(const Target: string);
var
  Dialog, Reloaded: TTournamentDialog;
  Grid: TStringGrid;
  Data: TJSONObject;
  MovedDir, MovedJson, MovedPdn, Pdn, FallbackPdn: string;
begin
  Dialog := TTournamentDialog.Create(nil);
  Reloaded := TTournamentDialog.Create(nil);
  MovedDir := Target + '.moved';
  MovedJson := IncludeTrailingPathDelimiter(MovedDir) + ExtractFileName(Target);
  MovedPdn := '';
  FallbackPdn := '';
  try
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, 'White', 'Black', 1);
    Dialog.SaveTournamentToFile(Target);
    Dialog.SetSelectedResult('1-1');
    Pdn := Dialog.PdnFileName;
    Data := TJSONObject(GetJSON(FileContents(Target)));
    try
      Check(Data.Get('pdn_file_name', '') = ExtractFileName(Pdn),
        'same-directory PDN must be serialized relative to JSON');
    finally
      Data.Free;
    end;
    Check(CreateDir(MovedDir), 'create moved tournament directory');
    MovedPdn := IncludeTrailingPathDelimiter(MovedDir) + ExtractFileName(Pdn);
    Check(RenameFile(Target, MovedJson) and RenameFile(Pdn, MovedPdn),
      'move tournament JSON and PDN together');
    Reloaded.LoadTournamentFromFile(MovedJson);
    Check((Reloaded.StorageError = '') and (Reloaded.PdnFileName = MovedPdn),
      'moved tournament must resume beside its JSON');
    Reloaded.SetSelectedResult('0-2');
    CheckPdnResult(MovedPdn, '0-2', '1');
    // Simulate an older absolute path from a machine/directory that no longer exists.
    Data := TJSONObject(GetJSON(FileContents(MovedJson)));
    try
      Data.Strings['pdn_file_name'] := Target + '.absent/old.pdn';
      WriteContents(MovedJson, Data.AsJSON);
    finally
      Data.Free;
    end;
    Reloaded.LoadTournamentFromFile(MovedJson);
    FallbackPdn := Reloaded.PdnFileName;
    Check((Reloaded.StorageError = '') and (FallbackPdn <> MovedPdn) and
      (ExtractFilePath(FallbackPdn) = IncludeTrailingPathDelimiter(MovedDir)),
      'missing old folder must choose an unused PDN beside the loaded JSON');
    CheckPdnResult(MovedPdn, '0-2', '1');
    CheckPdnResult(FallbackPdn, '0-2', '1');
  finally
    Reloaded.Free;
    Dialog.Free;
    DeleteFile(MovedJson);
    DeleteFile(MovedPdn);
    DeleteFile(FallbackPdn);
    RemoveDir(MovedDir);
  end;
end;

procedure CheckLargeTournamentSave(const Target: string);
var
  Data, Game, RecordData: TJSONObject;
  Games: TJSONArray;
  Dialog: TTournamentDialog;
  Payload, Pdn, SavedPdn: string;
  I: Integer;
  Tick, Elapsed: QWord;
begin
  Data := TJSONObject.Create;
  Dialog := TTournamentDialog.Create(nil);
  SavedPdn := '';
  try
    Data.Add('tournament_name', 'Large tournament');
    Games := TJSONArray.Create;
    Data.Add('games', Games);
    Payload := StringOfChar('x', 10000);
    Pdn := '[Result "1-0"]' + LineEnding + LineEnding +
      '1. 32-28 {' + Payload + '} 1-0';
    for I := 1 to 1000 do
    begin
      Game := TJSONObject.Create;
      Games.Add(Game);
      Game.Add('game', I);
      Game.Add('round', I);
      Game.Add('white', 'White');
      Game.Add('black', 'Black');
      Game.Add('result', '2-0');
      RecordData := TJSONObject.Create;
      Game.Add('record', RecordData);
      RecordData.Add('pdn', Pdn);
      RecordData.Add('played_result', '2-0');
    end;
    WriteContents(Target, Data.AsJSON);
    Dialog.LoadTournamentFromFile(Target);
    Check(Dialog.StorageError = '', 'large fixture must load successfully');
    SavedPdn := Dialog.PdnFileName;
    Tick := GetTickCount64;
    Dialog.SetSelectedResult('1-1');
    Elapsed := GetTickCount64 - Tick;
    Check(Dialog.StorageError = '', 'large autosave must succeed');
    WriteLn('1000 games, 10 KB each: autosave ', Elapsed, ' ms');
    Check(Elapsed < 2000, 'large autosave must stay below the two-second regression limit');
    Data.Free;
    Data := TJSONObject(GetJSON(FileContents(Target)));
    Games := TJSONArray(Data.Find('games'));
    Check((Games.Count = 1000) and
      (TJSONObject(TJSONObject(Games[999]).Find('record')).Get('pdn', '') = Pdn),
      'large save must retain the full last game in authoritative JSON');
    Check(Pos(Payload, FileContents(SavedPdn)) > 0, 'large projection must retain full comments');
  finally
    Data.Free;
    Dialog.Free;
    DeleteFile(Target);
    DeleteFile(SavedPdn);
  end;
end;

procedure CheckStableEngineRows(const Fixture: string);
var Dialog, Reloaded, Missing: TTournamentDialog; Engines: TExternalEngineList;
  Engine: TExternalEngineDefinition; Grid: TStringGrid; Setup: TGameSetup;
  Config, SavedConfig: string; HadConfig: Boolean;

  procedure WriteEngines(Reversed, OmitA: Boolean);
  var I: Integer; Name: string;
  begin
    Engines.Clear;
    for I := 0 to 1 do
    begin
      if Reversed xor (I = 0) then Name := 'A' else Name := 'B';
      if OmitA and (Name = 'A') then Continue;
      Engine := TExternalEngineDefinition.Create;
      Engine.Kind := eekHub; Engine.HubId := Name;
      Engine.ExePath := '/tmp/gwd-test-engine-' + Name;
      Engines.Add(Engine);
    end;
    SaveExternalEngines(Config, Engines);
  end;

begin
  Config := EnginesJsonFileName;
  HadConfig := FileExists(Config);
  if HadConfig then SavedConfig := FileContents(Config);
  Engines := TExternalEngineList.Create;
  Dialog := nil; Reloaded := nil; Missing := nil;
  try
    WriteEngines(False, False);
    Dialog := TTournamentDialog.Create(nil);
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, EnginePickerDisplayName(Engines[0], 1),
      EnginePickerDisplayName(Engines[1], 2), 1);
    Dialog.SaveTournamentToFile(Fixture);
    WriteEngines(True, False);
    Reloaded := TTournamentDialog.Create(nil);
    Reloaded.LoadTournamentFromFile(Fixture);
    Check(Reloaded.GameSetupForRow(1, Setup), 'reordered engines must still resolve');
    Check((Setup.WhiteEngine.HubId = 'A') and (Setup.BlackEngine.HubId = 'B'),
      'saved tournament rows must retain engine identities across picker reorder');
    WriteEngines(True, True);
    Missing := TTournamentDialog.Create(nil);
    Missing.LoadTournamentFromFile(Fixture);
    Check(not Missing.GameSetupForRow(1, Setup), 'missing engine must not bind by a matching slot');
    Grid := TStringGrid(Missing.FindComponent('TournamentPairings'));
    Check(Pos('Missing engine', Grid.Cells[TournamentColReason, 1]) > 0,
      'missing engine must have an actionable row diagnostic');
  finally
    Missing.Free; Reloaded.Free; Dialog.Free; Engines.Free;
    if HadConfig then WriteContents(Config, SavedConfig) else DeleteFile(Config);
  end;
end;

procedure CheckMovedOwnedProjection(const Fixture: string);
var
  Source, Moved: TTournamentDialog;
  Grid: TStringGrid;
  Data: TJSONObject;
  Collision: string;
begin
  WriteFixture(Fixture, 'Owned projection');
  Source := TTournamentDialog.Create(nil);
  Moved := TTournamentDialog.Create(nil);
  try
    Source.LoadTournamentFromFile(Fixture);
    Grid := TStringGrid(Source.FindComponent('TournamentPairings'));
    Grid.Row := 1;
    Source.SetSelectedResult('2-0');
    Collision := Fixture + '.unrelated.pdn';
    WriteContents(Collision, '[Event "Unrelated"]' + #13#10 + '1. 33-28 *' + #13#10);
    Data := TJSONObject(GetJSON(FileContents(Fixture)));
    try
      Data.Strings['pdn_file_name'] := ExtractFileName(Collision);
      WriteContents(Fixture, Data.AsJSON);
    finally Data.Free; end;
    Moved.LoadTournamentFromFile(Fixture);
    Moved.SetSelectedResult('1-1');
    Check(Moved.StorageError = '', 'owned projection collision must recover');
    Check(FileContents(Collision) = '[Event "Unrelated"]' + #13#10 + '1. 33-28 *' + #13#10,
      'copied JSON must never overwrite an unrelated claimed-owned PDN');
    Check(Moved.PdnFileName <> Collision, 'ownership mismatch must choose a fresh path');
    CheckPdnResult(Moved.PdnFileName, '1-1', '1');
  finally
    Moved.Free;
    Source.Free;
  end;
end;

procedure CheckNewProjectionPreservesExistingPdn(const Fixture: string);
var
  Dialog, Reloaded, Resumed: TTournamentDialog;
  Grid: TStringGrid;
  OriginalPdn, UnclaimedPdn, CurrentPdn: string;
  Data: TJSONObject;
const
  OriginalText = 'Earlier archive: keep exactly' + #13#10;
  ArrivalText = 'File created after the JSON save: keep exactly' + #13#10;
begin
  OriginalPdn := ChangeFileExt(Fixture, '.pdn');
  WriteContents(OriginalPdn, OriginalText);
  Dialog := TTournamentDialog.Create(nil);
  Reloaded := TTournamentDialog.Create(nil);
  Resumed := TTournamentDialog.Create(nil);
  try
    Dialog.SaveTournamentToFile(Fixture);
    Check(FileContents(OriginalPdn) = OriginalText,
      'saving an empty new tournament must not blank an existing same-name PDN');
    UnclaimedPdn := Dialog.PdnFileName;
    Check(UnclaimedPdn <> OriginalPdn, 'a new tournament must choose an unused projection target');
    Data := TJSONObject(GetJSON(FileContents(Fixture)));
    try
      Check(not Data.Get('pdn_owned', True), 'an uncreated projection must not be claimed as owned');
      Check(Data.Get('pdn_file_name', '') = ExtractFileName(UnclaimedPdn), 'JSON must record the unused target');
    finally
      Data.Free;
    end;
    Reloaded.LoadTournamentFromFile(Fixture);
    Check(Reloaded.PdnFileName = UnclaimedPdn,
      'an unused target must remain stable across reload');
    // A different file may appear after path selection, even across application restarts.
    WriteContents(UnclaimedPdn, ArrivalText);
    Grid := TStringGrid(Reloaded.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, 'White', 'Black', 1);
    Reloaded.SetSelectedResult('1-1');
    CurrentPdn := Reloaded.PdnFileName;
    Check((Reloaded.StorageError = '') and (CurrentPdn <> UnclaimedPdn) and
      (CurrentPdn <> OriginalPdn), 'later arrival must select another unused target');
    Check((FileContents(OriginalPdn) = OriginalText) and
      (FileContents(UnclaimedPdn) = ArrivalText),
      'first and subsequent autosaves must preserve both unrelated files byte for byte');
    CheckPdnResult(CurrentPdn, '1-1', '1');
    Data := TJSONObject(GetJSON(FileContents(Fixture)));
    try
      Check(Data.Get('pdn_owned', False), 'ownership must persist only after successful first publication');
      Check(Data.Get('pdn_file_name', '') = ExtractFileName(CurrentPdn), 'JSON and published PDN path must agree');
    finally
      Data.Free;
    end;
    Resumed.LoadTournamentFromFile(Fixture);
    Check(Resumed.PdnFileName = CurrentPdn, 'an owned projection must remain stable on resume');
    Resumed.SetSelectedResult('0-2');
    CheckPdnResult(CurrentPdn, '0-2', '1');
    Check((FileContents(OriginalPdn) = OriginalText) and
      (FileContents(UnclaimedPdn) = ArrivalText),
      'resumed result corrections must leave unrelated archives untouched');
  finally
    Resumed.Free;
    Reloaded.Free;
    Dialog.Free;
  end;
end;

procedure CheckProjectionAvoidsExistingDirectory(const Fixture: string);
var
  Dialog: TTournamentDialog;
  Grid: TStringGrid;
  DirectoryName: string;
begin
  DirectoryName := ChangeFileExt(Fixture, '.pdn');
  Check(CreateDir(DirectoryName), 'prepare projection-name directory');
  WriteContents(IncludeTrailingPathDelimiter(DirectoryName) + 'keep', 'directory content');
  Dialog := TTournamentDialog.Create(nil);
  try
    Dialog.SaveTournamentToFile(Fixture);
    Check(Dialog.PdnFileName <> DirectoryName, 'a directory must not be adopted as a PDN target');
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, 'White', 'Black', 1);
    Dialog.SetSelectedResult('1-1');
    Check(Dialog.StorageError = '', 'an occupied base name must not prevent saving new game records');
    CheckPdnResult(Dialog.PdnFileName, '1-1', '1');
    Check(FileContents(IncludeTrailingPathDelimiter(DirectoryName) + 'keep') = 'directory content',
      'directory contents must survive projection creation');
  finally
    Dialog.Free;
    DeleteFile(IncludeTrailingPathDelimiter(DirectoryName) + 'keep');
    RemoveDir(DirectoryName);
  end;
end;

procedure CheckUnmarkedV2PdnIsPreserved(const Fixture: string);
var
  Dialog: TTournamentDialog;
  Grid: TStringGrid;
  ExistingPdn: string;
begin
  WriteContents(Fixture,
    '{"storage_version":2,"tournament_id":"unmarked-v2","games":[]}');
  ExistingPdn := ChangeFileExt(Fixture, '.pdn');
  WriteContents(ExistingPdn, 'Unmarked existing archive');
  Dialog := TTournamentDialog.Create(nil);
  try
    Dialog.LoadTournamentFromFile(Fixture);
    Check((FileContents(ExistingPdn) = 'Unmarked existing archive') and
      (Dialog.PdnFileName <> ExistingPdn),
      'an older v2 snapshot without an ownership marker must not adopt or blank a PDN');
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, 'White', 'Black', 1);
    Dialog.SetSelectedResult('1-1');
    CheckPdnResult(Dialog.PdnFileName, '1-1', '1');
    Check(FileContents(ExistingPdn) = 'Unmarked existing archive',
      'later autosaves of an older snapshot must preserve its original archive');
  finally
    Dialog.Free;
  end;
end;

procedure CheckEngineArgumentIdentity(const Fixture: string);
var Engines: TExternalEngineList; Fast, Slow: TExternalEngineDefinition;
  Dialog, Reloaded: TTournamentDialog; Grid: TStringGrid; Setup: TGameSetup;
  Config, SavedConfig, LegacyKey: string; HadConfig: Boolean;
begin
  Config := EnginesJsonFileName; HadConfig := FileExists(Config);
  if HadConfig then SavedConfig := FileContents(Config);
  Engines := TExternalEngineList.Create; Dialog := nil; Reloaded := nil;
  try
    Fast := TExternalEngineDefinition.Create; Fast.Kind := eekHub;
    Fast.HubId := 'Same engine'; Fast.ExePath := '/tmp/gwd-test-same-engine'; Fast.Arguments := '--level fast';
    Slow := TExternalEngineDefinition.Create; Slow.Assign(Fast); Slow.Arguments := '--level slow';
    Engines.Add(Fast); Engines.Add(Slow);
    Check(EngineIdentityKey(Fast) <> EngineIdentityKey(Slow), 'arguments distinguish tournament engine identities');
    LegacyKey := LowerCase(Fast.KindText) + '|' + LowerCase(ExpandFileName(Fast.ExePath)) + '|' + LowerCase(Fast.IdText);
    Check(FindEngineByIdentityKey(Engines, LegacyKey) = nil, 'ambiguous legacy key must not silently choose the first engine');
    SaveExternalEngines(Config, Engines);
    Dialog := TTournamentDialog.Create(nil);
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, EnginePickerDisplayName(Fast, 1), EnginePickerDisplayName(Slow, 2), 1);
    Check(Dialog.GameSetupForRow(1, Setup), 'argument variants resolve in game setup');
    Check((Setup.WhiteEngine.Arguments = '--level fast') and (Setup.BlackEngine.Arguments = '--level slow'),
      'same executable must launch distinct argument variants');
    Dialog.SaveTournamentToFile(Fixture);
    Reloaded := TTournamentDialog.Create(nil); Reloaded.LoadTournamentFromFile(Fixture);
    Check(Reloaded.GameSetupForRow(1, Setup), 'argument variants survive tournament reload');
    Check((Setup.WhiteEngine.Arguments = '--level fast') and (Setup.BlackEngine.Arguments = '--level slow'),
      'reloaded game must not collapse two variants');
    Slow.Arguments := Fast.Arguments; Slow.InitText := 'set-param name=Threads value=2';
    Check(EngineIdentityKey(Fast) <> EngineIdentityKey(Slow), 'initialization parameters distinguish definitions');
  finally
    Reloaded.Free; Dialog.Free; Engines.Free;
    if HadConfig then WriteContents(Config, SavedConfig) else DeleteFile(Config);
  end;
end;

procedure CheckUnfingerprintedProjection(const Fixture: string);
var Dialog, Resumed: TTournamentDialog; Grid: TStringGrid;
  Document: TJSONObject; PdnPath: string;
begin
  Dialog := TTournamentDialog.Create(nil); Resumed := TTournamentDialog.Create(nil);
  try
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, 'White', 'Black', 1);
    Dialog.SaveTournamentToFile(Fixture);
    Dialog.SetSelectedResult('1-1');
    PdnPath := Dialog.PdnFileName;
    Document := TJSONObject(GetJSON(FileContents(Fixture)));
    try
      Document.Delete('pdn_published_hash');
      WriteContents(Fixture, Document.AsJSON);
    finally Document.Free; end;
    Resumed.LoadTournamentFromFile(Fixture);
    Resumed.SaveTournamentToFile(Fixture);
    Check(Resumed.PdnFileName = PdnPath, 'identical old projection is adopted without a fork');
    Check(Pos('Preserved', Resumed.Caption) = 0, 'identical old projection has no preservation warning');
    // A same-size edit must still be detected; mtime granularity cannot bypass ownership.
    WriteContents(PdnPath, StringReplace(FileContents(PdnPath), 'White', 'Other', []));
    Resumed.SetSelectedResult('1-1');
    Check(Resumed.PdnFileName <> PdnPath, 'same-size external edits are preserved');
  finally Resumed.Free; Dialog.Free; end;
end;

procedure CheckExternalPdnEdits(const Fixture: string);
var Dialog, Resumed: TTournamentDialog; Grid: TStringGrid;
  PdnPath, Edited: string;
begin
  Dialog := TTournamentDialog.Create(nil); Resumed := TTournamentDialog.Create(nil);
  try
    Grid := TStringGrid(Dialog.FindComponent('TournamentPairings'));
    AddTournamentPairingRow(Grid, 'White', 'Black', 1);
    Dialog.SaveTournamentToFile(Fixture);
    Dialog.SetSelectedResult('1-1');
    PdnPath := Dialog.PdnFileName;
    Edited := FileContents(PdnPath) + '{external user annotation}' + LineEnding;
    WriteContents(PdnPath, Edited);
    Resumed.LoadTournamentFromFile(Fixture);
    Resumed.SetSelectedResult('2-0');
    Check((Resumed.StorageError = '') and (Resumed.PdnFileName <> PdnPath),
      'edited same-identity PDN must get a fresh projection path');
    Check(FileContents(PdnPath) = Edited, 'external PDN edits survive byte for byte');
    Check(Pos('Preserved changed PDN', Resumed.Caption) > 0, 'external edit preservation is visible');
    CheckPdnResult(Resumed.PdnFileName, '2-0', '1');
  finally Resumed.Free; Dialog.Free; end;
end;

procedure CheckIndependentLegacyIdentities(const Fixture: string);
var Dialog: TTournamentDialog; FirstId: string;
begin
  WriteFixture(Fixture, 'First legacy');
  WriteFixture(Fixture + '.second', 'Second legacy');
  Dialog := TTournamentDialog.Create(nil);
  try
    Dialog.LoadTournamentFromFile(Fixture);
    Dialog.SaveTournamentToFile(Fixture + '.first-saved');
    FirstId := TournamentId(Fixture + '.first-saved');
    Dialog.LoadTournamentFromFile(Fixture + '.second');
    Dialog.SaveTournamentToFile(Fixture + '.second-saved');
    Check(TournamentId(Fixture + '.second-saved') <> FirstId,
      'separate legacy files loaded in one dialog need distinct identities');
  finally Dialog.Free; end;
end;

procedure CheckLegacyMigrationCollision(const Fixture: string);
var
  Dialog: TTournamentDialog;
  Archive, Collision: string;
begin
  WriteContents(Fixture, '{"tournament_id":"legacy-collision","games":[' +
    '{"white":"White","black":"Black","result":"1-1"}]}');
  Archive := ChangeFileExt(Fixture, '.pdn');
  Collision := ChangeFileExt(Archive, '') + '.legacy-collision.pdn';
  WriteContents(Archive, 'original legacy archive');
  WriteContents(Collision, 'earlier migration output');
  Dialog := TTournamentDialog.Create(nil);
  try
    Dialog.LoadTournamentFromFile(Fixture);
    Check((Dialog.PdnFileName <> Archive) and (Dialog.PdnFileName <> Collision),
      'legacy migration must not adopt an existing suffixed archive');
    Check((FileContents(Archive) = 'original legacy archive') and
      (FileContents(Collision) = 'earlier migration output'),
      'both legacy archives must survive migration');
    CheckPdnResult(Dialog.PdnFileName, '1-1', '1');
  finally
    Dialog.Free;
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
      if ParamStr(1) = '--performance' then
      begin
        CheckLargeTournamentSave(IncludeTrailingPathDelimiter(TestDirectory) + 'large.json');
      end;
      WriteFixture(Fixture, 'Original');
      WriteFixture(OtherFile, 'Other');
      CheckCaptureFailureDoesNotBlockSaving(IncludeTrailingPathDelimiter(TestDirectory) + 'capture-isolation.json');
      CheckCaptureFailureStopsCleanly(IncludeTrailingPathDelimiter(TestDirectory) + 'capture-failure.json');
      CheckCompletionIsAppliedOnce(Fixture);
      CheckFailedLoadIsTransactional(Fixture);
      CheckPairingChangesWaitForShutdown(Fixture, OtherFile);
      CheckAutosaveAndFailureRecovery(Fixture);
      CheckUnsavedTournamentGetsRecoveryFile;
      CheckFirstSaveRelocatesRecovery(IncludeTrailingPathDelimiter(TestDirectory) + 'named.json');
      CheckRecordsAndPdnStayConsistent(IncludeTrailingPathDelimiter(TestDirectory) + 'records.json');
      CheckLegacyPdnIsPreserved(IncludeTrailingPathDelimiter(TestDirectory) + 'legacy.json');
      CheckByeSurvivesReload(IncludeTrailingPathDelimiter(TestDirectory) + 'bye.json');
      CheckEmptyResetKeepsStorage(IncludeTrailingPathDelimiter(TestDirectory) + 'empty-reset.json');
      CheckResetPreservesSavedFiles(IncludeTrailingPathDelimiter(TestDirectory) + 'apply.json', 0);
      CheckResetPreservesSavedFiles(IncludeTrailingPathDelimiter(TestDirectory) + 'create.json', 1);
      CheckResetPreservesSavedFiles(IncludeTrailingPathDelimiter(TestDirectory) + 'clear.json', 2);
      CheckResetWaitsForSuccessfulSave(IncludeTrailingPathDelimiter(TestDirectory) + 'failed-reset.json');
      CheckResetPreservesRecoveryFiles;
      CheckPortableTournamentPaths(IncludeTrailingPathDelimiter(TestDirectory) + 'portable.json');
      CheckStableEngineRows(IncludeTrailingPathDelimiter(TestDirectory) + 'stable-engines.json');
      CheckMovedOwnedProjection(IncludeTrailingPathDelimiter(TestDirectory) + 'owned-collision.json');
      CheckNewProjectionPreservesExistingPdn(IncludeTrailingPathDelimiter(TestDirectory) + 'collision.json');
      CheckProjectionAvoidsExistingDirectory(IncludeTrailingPathDelimiter(TestDirectory) + 'directory.json');
      CheckEngineArgumentIdentity(IncludeTrailingPathDelimiter(TestDirectory) + 'argument-identities.json');
      CheckUnfingerprintedProjection(IncludeTrailingPathDelimiter(TestDirectory) + 'old-fingerprint.json');
      CheckExternalPdnEdits(IncludeTrailingPathDelimiter(TestDirectory) + 'external-edits.json');
      CheckIndependentLegacyIdentities(IncludeTrailingPathDelimiter(TestDirectory) + 'legacy-identities.json');
      CheckLegacyMigrationCollision(IncludeTrailingPathDelimiter(TestDirectory) + 'legacy-collision.json');
      CheckUnmarkedV2PdnIsPreserved(IncludeTrailingPathDelimiter(TestDirectory) + 'unmarked-v2.json');
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
