program main_form_boundaries_check;
{$mode objfpc}{$H+}
{$IFNDEF GWDGUI_NONINTERACTIVE_TEST}
  {$FATAL Build this test with its .lpi project}
{$ENDIF}
uses {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Classes, SysUtils, Controls, StdCtrls, Menus, ExtCtrls, Grids,
  LCLType, Types, Graphics, uMainForm, uRunningGame, uBoardControl, uDraughtsBoard, uPdn,
  uGameTree, uGameTreePdn, uGameTreeBuilder, uGameSetupTypes, uGameOrchestrator, uGuiDialogs,
  uPositionSetupForm, uEngineRegistry, uEngineParamsJson, uAnalyzerRunnerThread,
  uGameGuiMessages, uGameTreeSearchRef, uEngineEditForm, uGameTreeActor, uDisplayedPosition;

type
  TBoardPaintAccess = class(TDraughtsBoardControl)
    procedure Render(Image: TBitmap);
  end;
  TCaptureChoice = class
    Dialog: TForm;
    Index: Integer;
    Expected: TStringList;
    MainForm: TMainForm;
    ChangePosition: Boolean;
    procedure Shown(Sender: TObject);
    procedure Choose(Data: PtrInt);
  end;
  TExceptionReporter = class
    procedure Report(Sender: TObject; Error: Exception);
  end;
procedure TBoardPaintAccess.Render(Image: TBitmap);
begin PaintWindow(Image.Canvas.Handle); end;
procedure TExceptionReporter.Report(Sender: TObject; Error: Exception);
begin
  WriteLn('FAIL: ', Error.ClassName, ': ', Error.Message);
  DumpExceptionBackTrace(Output); Flush(Output); Halt(1);
end;

procedure Check(Value: Boolean; const Text: string);
begin if not Value then raise Exception.Create(Text); end;

procedure Pump(Form: TMainForm);
var I: Integer;
begin
  Application.ProcessMessages;
  for I := 0 to Form.ComponentCount - 1 do
    if (Form.Components[I] is TTimer) and Assigned(TTimer(Form.Components[I]).OnTimer) then
      TTimer(Form.Components[I]).OnTimer(nil);
end;

function Menu(Form: TMainForm; const Caption: string): TMenuItem;
var I: Integer;
begin
  Result := nil;
  for I := 0 to Form.ComponentCount - 1 do
    if (Form.Components[I] is TMenuItem) and
      (TMenuItem(Form.Components[I]).Caption = Caption) then Exit(TMenuItem(Form.Components[I]));
  raise Exception.Create('Missing menu: ' + Caption);
end;

function PointForSquare(Board: TDraughtsBoardControl; Square: Integer): TPoint;
var X, Y, Step: Integer;
begin
  Step := Board.BoardSquareSize div 2; if Step < 1 then Step := 1;
  Y := 0;
  while Y < Board.ClientHeight do
  begin
    X := 0;
    while X < Board.ClientWidth do
    begin
      if Board.SquareAtPoint(X, Y) = Square then Exit(Point(X, Y));
      Inc(X, Step);
    end;
    Inc(Y, Step);
  end;
  raise Exception.Create('Cannot locate square ' + IntToStr(Square));
end;

procedure ClickSquare(Board: TDraughtsBoardControl; Square: Integer);
var P: TPoint;
begin P := PointForSquare(Board, Square); Board.OnMouseDown(Board, mbLeft, [], P.X, P.Y); end;

procedure CheckCaptureAndFlip;
const Fen = 'W:WK32:B27,28';
var Form: TMainForm; Board: TDraughtsBoardControl; Expected: TDraughtsBoard;
  Legal: string; Destination, I: Integer; Key: Word; BeforeText: string;
  Points: array[1..50] of TPoint; Flipped: Boolean; NodeId: Int64;
begin
  Form := TMainForm.Create(nil); Expected := TDraughtsBoard.Create;
  try
    Form.LoadStandaloneFen(Fen);
    Board := TDraughtsBoardControl(Form.FindComponent('MainBoard'));
    Board.SetBounds(0, 0, 500, 500);
    Expected.LoadFromFEN(Fen);
    Check(Expected.LegalMoveCount > 1, 'fixture offers several captures from one square');
    Legal := Expected.LegalMoves[Expected.LegalMoveCount - 1];
    Expected.PlayMove(Legal);
    Destination := 0;
    for I := 1 to 50 do if Expected[I] = pkWhiteKing then Destination := I;
    Check(Destination > 0, 'capture has a resulting king square');
    BeforeText := GameTreeToPdnText(Form.ActiveGameTree);
    ClickSquare(Board, 32);
    Check(GameTreeToPdnText(Form.ActiveGameTree) = BeforeText, 'source selection alone cannot play a capture');
    ClickSquare(Board, Destination);
    Check((Form.ActiveGameTree.MainlineCount = 1) and
      (Form.ActiveGameTree.MainlineNode[1].MoveText = Legal), 'target click chooses the canonical capture');
    Check(Board.Board.CurrentFEN = Expected.CurrentFEN, 'capture click displays its resulting position');
    BeforeText := GameTreeToPdnText(Form.ActiveGameTree); NodeId := Form.ActiveGameTree.MainlineNode[1].NodeId;
    Flipped := Board.BoardFlipped;
    for I := 1 to 50 do Points[I] := PointForSquare(Board, I);
    Key := Ord('F'); Form.OnKeyDown(Form, Key, []);
    Check(Board.BoardFlipped <> Flipped, 'keyboard flips the actual board');
    for I := 1 to 50 do
      Check(Board.SquareAtPoint(Points[I].X, Points[I].Y) = 51 - I, 'flip reverses square mapping');
    Key := Ord('F'); Form.OnKeyDown(Form, Key, []);
    Check(Board.BoardFlipped = Flipped, 'second flip restores orientation');
    Check((GameTreeToPdnText(Form.ActiveGameTree) = BeforeText) and
      (Form.ActiveGameTree.MainlineNode[1].NodeId = NodeId) and
      (Board.Board.CurrentFEN = Expected.CurrentFEN), 'flip preserves model, identity and displayed position');
  finally Expected.Free; Form.Free; end;
end;

procedure TCaptureChoice.Shown(Sender: TObject);
var Choices: TListBox;
begin
  Dialog := TForm(Sender);
  Choices := TListBox(Dialog.FindComponent('Choices'));
  Check(Choices.Items.Text = Expected.Text, 'chooser shows distinct standard PDN paths in legal order');
  Application.QueueAsyncCall(@Choose, 0);
end;
procedure TCaptureChoice.Choose(Data: PtrInt);
begin
  if ChangePosition then MainForm.LoadStandaloneFen(DefaultStartingFEN);
  if Index < 0 then TButton(Dialog.FindComponent('CancelButton')).Click
  else
  begin
    TListBox(Dialog.FindComponent('Choices')).ItemIndex := Index;
    TButton(Dialog.FindComponent('ChooseButton')).Click;
  end;
end;
procedure CheckAmbiguousCapture;
const Fen = 'W:WK21:B31,39,14,17,19';
var Form: TMainForm; Board: TDraughtsBoardControl; Expected: TDraughtsBoard;
  Choice: TCaptureChoice; Moves: TStringList; I, Scenario: Integer; Before: string;
begin
  Choice := TCaptureChoice.Create; Expected := TDraughtsBoard.Create;
  Moves := TStringList.Create; Choice.Expected := TStringList.Create;
  try
    Expected.LoadFromFEN(Fen);
    Check(Expected.LegalMoveCount = 2, 'same-target fixture has two distinct captures');
    for I := 0 to Expected.LegalMoveCount - 1 do
    begin Moves.Add(Expected.LegalMoves[I]); Choice.Expected.Add(Expected.PdnMoveNotation(Moves[I])); end;
    Check(Choice.Expected[0] <> Choice.Expected[1], 'capture path labels distinguish the choices');
    GuiTestChoiceOnShow := @Choice.Shown;
    for Scenario := -1 to 2 do
    begin
      Form := TMainForm.Create(nil);
      try
        Form.LoadStandaloneFen(Fen); Choice.MainForm := Form;
        Choice.ChangePosition := Scenario = 2;
        if Scenario = 2 then Choice.Index := 0 else Choice.Index := Scenario;
        Board := TDraughtsBoardControl(Form.FindComponent('MainBoard'));
        Board.SetBounds(0, 0, 500, 500);
        Expected.LoadFromFEN(Fen);
        Before := GameTreeToPdnText(Form.ActiveGameTree);
        ClickSquare(Board, 21); ClickSquare(Board, 26);
        if Scenario = -1 then
          Check((GameTreeToPdnText(Form.ActiveGameTree) = Before) and
            (Board.Board.CurrentFEN = Expected.CurrentFEN), 'cancel leaves tree and board untouched')
        else if Scenario = 2 then
        begin
          Expected.SetBeginPosition;
          Check((Form.ActiveGameTree.MainlineCount = 0) and
            (Board.Board.CurrentFEN = Expected.CurrentFEN), 'position change while choosing rejects stale choice');
        end
        else
        begin
          Expected.LoadFromFEN(Fen); Expected.PlayMove(Moves[Scenario]);
          Check((Form.ActiveGameTree.MainlineCount = 1) and
            (Form.ActiveGameTree.MainlineNode[1].MoveText = Moves[Scenario]), 'explicit capture choice reaches actor');
          Check(Board.Board.CurrentFEN = Expected.CurrentFEN, 'each selected capture displays the correct surviving pieces');
        end;
      finally Form.Free; end;
    end;
  finally
    GuiTestChoiceOnShow := nil; Choice.Expected.Free; Choice.Free; Moves.Free; Expected.Free;
  end;
end;

procedure CheckReplacementPrompt;
var Form: TMainForm; Position: TPositionSetupForm; I: Integer;
  BeforeText: string; Id: Int64; Setup: TGameSetup; Running: TRunningGame;
begin
  Form := TMainForm.Create(nil);
  try
    Form.LoadStandaloneFen('W:WK32:B27,28');
    BeforeText := GameTreeToPdnText(Form.ActiveGameTree); Id := Form.ActiveGameTree.GameTreeId;
    Menu(Form, 'Setup position...').Click;
    Position := nil;
    for I := 0 to Form.ComponentCount - 1 do
      if Form.Components[I] is TPositionSetupForm then Position := TPositionSetupForm(Form.Components[I]);
    Check(Position <> nil, 'actual setup action creates the position editor');
    Position.Hide;
    GuiTestConfirmationResult := mrCancel;
    Position.OnAccepted(Position, DefaultStartingFEN);
    Check((Form.ActiveGameTree.GameTreeId = Id) and
      (GameTreeToPdnText(Form.ActiveGameTree) = BeforeText), 'cancel preserves unsaved standalone game');
    GuiTestConfirmationResult := mrNo;
    Position.OnAccepted(Position, DefaultStartingFEN);
    Check(Form.ActiveGameTree.StartingFEN = DefaultStartingFEN, 'declining save permits replacement');
    Form.LoadStandaloneFen('W:WK32:B27,28');
    Id := Form.ActiveGameTree.GameTreeId; BeforeText := GameTreeToPdnText(Form.ActiveGameTree);
    GuiTestConfirmationResult := 0; // Any unwanted prompt now fails the test.
    Setup := Default(TGameSetup); Setup.StartingFEN := DefaultStartingFEN;
    Setup.TimeControl := DefaultTimeControl; Setup.WhitePlayer := pkHuman; Setup.BlackPlayer := pkHuman;
    Running := Form.StartGameFromSetup(Setup);
    Check(Form.ActiveGameTree = Running.GameTree, 'new running game is displayed without a replacement prompt');
    with TListBox(Form.FindComponent('GameHistoryList')) do begin ItemIndex := 0; OnClick(Form.FindComponent('GameHistoryList')); end;
    Check((Form.ActiveGameTree.GameTreeId = Id) and
      (GameTreeToPdnText(Form.ActiveGameTree) = BeforeText), 'switching games preserves the standalone tree');
  finally GuiTestConfirmationResult := 0; Form.Free; end;
end;

procedure FakeHub;
var Line, Hub, Moves, PV, Fen, Whites, Blacks: string; I: Integer;
  Board: TDraughtsBoard; Words: TStringList; Searching: Boolean;
begin
  Board := TDraughtsBoard.Create; Words := TStringList.Create; Searching := False;
  try
    while not EOF(Input) do
    begin
      ReadLn(Line);
      if Line = 'hub' then begin WriteLn('id name=BoundaryHub'); WriteLn('wait'); end
      else if Line = 'init' then WriteLn('ready')
      else if Pos('pos ', Line) = 1 then
      begin
        Hub := ExtractHubArgument(Line, 'pos'); Whites := ''; Blacks := '';
        if Length(Hub) = 51 then
        begin
          for I := 1 to 50 do
          begin
            if Hub[I + 1] in ['w','W'] then
            begin if Whites <> '' then Whites += ','; if Hub[I + 1] = 'W' then Whites += 'K'; Whites += IntToStr(I); end;
            if Hub[I + 1] in ['b','B'] then
            begin if Blacks <> '' then Blacks += ','; if Hub[I + 1] = 'B' then Blacks += 'K'; Blacks += IntToStr(I); end;
          end;
          Fen := Hub[1] + ':W' + Whites + ':B' + Blacks; Board.LoadFromFEN(Fen);
          Moves := ExtractHubArgument(Line, 'moves'); TextToMoveList(Moves, Words);
          for I := 0 to Words.Count - 1 do Board.PlayMove(Words[I]);
        end;
        PV := ''; if Board.LegalMoveCount > 0 then PV := Board.LegalMoves[0];
      end
      else if (Line = 'go analyze') or (Line = 'go mcts') then
      begin Searching := True; WriteLn('info depth=9 score=0.25 pv="' + PV + '"'); end
      else if Line = 'go think' then
      begin
        Sleep(200); // Leave time to stop a one-shot search before its late reply.
        WriteLn('info depth=9 score=0.25 pv="' + PV + '"'); WriteLn('done move=' + PV);
      end
      else if (Line = 'stop') and Searching then
      begin Searching := False; WriteLn('done move=' + PV); end
      else if Line = 'quit' then Break;
      Flush(Output);
    end;
  finally Words.Free; Board.Free; end;
end;

function HasLog(Form: TMainForm; const Text: string): Boolean;
var I: Integer;
begin
  for I := 0 to Form.ComponentCount - 1 do
    if (Form.Components[I] is TMemo) and (Pos(Text, TMemo(Form.Components[I]).Text) > 0) then Exit(True);
  Result := False;
end;

function ButtonWithCaption(Form: TCustomForm; const Caption: string): TButton;
var I: Integer;
begin
  for I := 0 to Form.ComponentCount - 1 do
    if (Form.Components[I] is TButton) and (TButton(Form.Components[I]).Caption = Caption) then Exit(TButton(Form.Components[I]));
  raise Exception.Create('Missing button: ' + Caption);
end;

procedure CheckAnalysisControls;
var Form: TMainForm; Engines: TExternalEngineList; Definition: TExternalEngineDefinition;
  Params: TEngineParamArray; Item: TMenuItem; Popup: TPopupMenu;
  Tick: QWord; Keys: TStringList; Game: TRunningGame; Setup: TGameSetup; Memo: TMemo;
  NodeId: Int64; AutoText, Config, ParamFile: string; HadConfig, HadParams: Boolean;
  SavedConfig, SavedParams: TStringList; Key: Word; Button: TButton;
  OldRunner, CurrentRunner: TAnalyzerRunnerThread; Search: TGameTreeSearchRef;
begin
  Config := EnginesJsonFileName; ParamFile := EngineParamsFileName(ExpandFileName(ParamStr(0)));
  HadConfig := FileExists(Config); HadParams := FileExists(ParamFile);
  SavedConfig := TStringList.Create; SavedParams := TStringList.Create;
  Engines := TExternalEngineList.Create; Keys := TStringList.Create; Form := nil; OldRunner := nil;
  try
    if HadConfig then SavedConfig.LoadFromFile(Config);
    if HadParams then SavedParams.LoadFromFile(ParamFile);
    Definition := TExternalEngineDefinition.Create; Definition.Kind := eekHub;
    Definition.ExePath := ExpandFileName(ParamStr(0)); Definition.HubId := 'BoundaryHub'; Definition.Arguments := '--boundary-hub';
    Engines.Add(Definition); SaveExternalEngines(Config, Engines);
    // Keep a completed old runner alive so its identity cannot be reused.
    OldRunner := TAnalyzerRunnerThread.Create(Definition, nil, nil, nil);
    OldRunner.Terminate; OldRunner.Start; OldRunner.WaitFor;
    Params := nil; AddOrUpdateParam(Params, 'gui-engine-supports-mcts', 'bool', 'true', False);
    SaveEngineParamsToJson(ParamFile, 'hub', Params);
    Form := TMainForm.Create(nil);
    Setup := Default(TGameSetup); Setup.StartingFEN := DefaultStartingFEN;
    Setup.WhitePlayer := pkHuman; Setup.BlackPlayer := pkHuman; Setup.TimeControl := DefaultTimeControl;
    Game := Form.StartGameFromSetup(Setup);
    Tick := GetTickCount64;
    repeat Pump(Form); Sleep(5); until (Game.Lifecycle = rglRunning) or (GetTickCount64 - Tick > 5000);
    Check(Game.Lifecycle = rglRunning, 'human game starts for stopped-game analysis');
    Game.Runner.PostHumanMove('32-28'); Game.Runner.PostHumanMove('18-23');
    Tick := GetTickCount64;
    repeat Pump(Form); Sleep(5); until (Game.MainlineCount = 2) or (GetTickCount64 - Tick > 5000);
    Check(Game.MainlineCount = 2, 'human runner records the analysis fixture');
    Form.MarkGameStopped(Game, 'characterization');
    Tick := GetTickCount64;
    repeat Pump(Form); Sleep(5); until (Game.Lifecycle = rglFinished) or (GetTickCount64 - Tick > 5000);
    Check(Game.Lifecycle = rglFinished, 'analysis fixture is a fully stopped game');
    Memo := TMemo(Form.FindComponent('GameMoveMemo'));
    Key := VK_LEFT; Memo.OnKeyDown(Memo, Key, []); // following -> tip
    Key := VK_LEFT; Memo.OnKeyDown(Memo, Key, []); // tip -> ply 1
    Check(TDraughtsBoardControl(Form.FindComponent('MainBoard')).Board.SideToMove = dsBlack,
      'historical analysis starts after the first move');
    NodeId := Form.ActiveGameTree.MainlineNode[1].NodeId;
    Item := Menu(Form, 'Open Annotator'); Popup := TPopupMenu(Item.GetParentMenu); Popup.OnPopup(Popup);
    Check(Item.Count = 1, 'one fake annotator is available'); Item.Items[0].Click;
    Tick := GetTickCount64;
    repeat Pump(Form); Keys.Clear; Form.CollectBusyEngineKeys(Keys); Sleep(5);
    until (Keys.Count = 1) or (GetTickCount64 - Tick > 5000);
    CurrentRunner := Form.TestAnalyzerRunner; Search := Form.TestAnalysis.Search;
    Check(IsValidGameTreeSearchRef(Search), 'annotator has an active search before foreign completion');
    Form.TestGuiEventQueue.Post(TAnalyzerFinishedGuiMessage.Create(OldRunner));
    Form.TestDrainGuiEvents(True);
    Keys.Clear; Form.CollectBusyEngineKeys(Keys);
    Check((Form.TestAnalyzerRunner = CurrentRunner) and (Keys.Count = 1) and
      SameGameTreeSearchRef(Form.TestAnalysis.Search, Search),
      'old analyzer completion preserves the current runner, search and reservation');
    Button := ButtonWithCaption(Form, 'Auto Play');
    Check(Button.Enabled, 'opening annotator enables Auto Play'); Button.Click;
    Tick := GetTickCount64;
    repeat Pump(Form); Sleep(5);
    until (Form.ActiveGameTree.FindNodeById(NodeId).AutoPlayPV <> '') or (GetTickCount64 - Tick > 5000);
    Check(Form.ActiveGameTree.FindNodeById(NodeId).AutoPlayPV <> '', 'Auto Play attaches to the selected historical node');
    Check(Form.ActiveGameTree.Root.AutoPlayPV = '', 'Auto Play does not attach to root');
    Check((Form.ActiveGameTree.MainlineCount = 2) and
      (Form.ActiveGameTree.MainlineNode[2].MoveText = '18-23'), 'Auto Play preserves the official continuation');
    Key := VK_ESCAPE; Form.OnKeyDown(Form, Key, []);
    AutoText := Form.ActiveGameTree.FindNodeById(NodeId).AutoPlayPV;
    Tick := GetTickCount64;
    repeat Pump(Form); Sleep(5); until GetTickCount64 - Tick > 600;
    Check(Form.ActiveGameTree.FindNodeById(NodeId).AutoPlayPV = AutoText, 'late reply after Stop cannot extend Auto Play');
    Check(Button.Caption = 'Auto Play', 'Escape stops Auto Play');
    Item := Menu(Form, 'Close Annotator');
    TPopupMenu(Item.GetParentMenu).OnPopup(Item.GetParentMenu); Item.Click;
    Tick := GetTickCount64;
    Item := Menu(Form, 'Open Annotator'); Popup := TPopupMenu(Item.GetParentMenu);
    repeat Pump(Form); Popup.OnPopup(Popup); Keys.Clear; Form.CollectBusyEngineKeys(Keys); Sleep(5);
    until ((Keys.Count = 0) and Item.Enabled) or (GetTickCount64 - Tick > 5000);
    Check((Keys.Count = 0) and Item.Enabled, 'annotator shutdown releases runner and engine reservation');
    Item := Menu(Form, 'Open MCTS annotator'); Popup := TPopupMenu(Item.GetParentMenu); Popup.OnPopup(Popup);
    Check(Item.Count = 1, 'one fake MCTS annotator is available'); Item.Items[0].Click;
    Keys.Clear; Form.CollectBusyEngineKeys(Keys); Check(Keys.Count = 1, 'MCTS reserves its engine');
    Tick := GetTickCount64;
    repeat Pump(Form); Sleep(5); until HasLog(Form, 'go mcts') or (GetTickCount64 - Tick > 5000);
    Check(HasLog(Form, 'go mcts'), 'MCTS form action reaches the engine protocol');
    CurrentRunner := Form.TestMctsRunner;
    Form.TestGuiEventQueue.Post(TMctsFinishedGuiMessage.Create(OldRunner));
    Form.TestDrainGuiEvents(True); Keys.Clear; Form.CollectBusyEngineKeys(Keys);
    Check((Form.TestMctsRunner = CurrentRunner) and (Keys.Count = 1),
      'old MCTS completion preserves current runner and reservation');
    Popup.OnPopup(Popup); Menu(Form, 'Close MCTS annotator').Click;
    Tick := GetTickCount64;
    Item := Menu(Form, 'Open MCTS annotator');
    repeat Pump(Form); Popup.OnPopup(Popup); Keys.Clear; Form.CollectBusyEngineKeys(Keys); Sleep(5);
    until ((Keys.Count = 0) and Item.Enabled) or (GetTickCount64 - Tick > 5000);
    Check((Keys.Count = 0) and Item.Enabled, 'MCTS shutdown releases runner and reservation');
    Item := Menu(Form, 'Open MCTS annotator'); Popup.OnPopup(Popup); Item.Items[0].Click;
    Form.Free; Form := nil; // Destruction must drain pending MCTS updates safely.
  finally
    Form.Free; OldRunner.Free; Keys.Free; Engines.Free;
    if HadConfig then SavedConfig.SaveToFile(Config) else DeleteFile(Config);
    if HadParams then SavedParams.SaveToFile(ParamFile) else DeleteFile(ParamFile);
    SavedConfig.Free; SavedParams.Free;
  end;
end;

procedure CheckHintModes;
var Form: TMainForm; Board: TDraughtsBoardControl; Actor: TGameTreeActor;
  Display: TDisplayedPosition; Command: TGameTreeCommand;
  Main, Annotator, None: TMenuItem; Before, Fen: string; Key: Word; I: Integer; Image: TBitmap;
  function SquareHasColor(Square: Integer; Color: TColor): Boolean;
  var X, Y: Integer;
  begin
    for Y := 0 to Board.ClientHeight - 1 do
      for X := 0 to Board.ClientWidth - 1 do
        if (Board.SquareAtPoint(X, Y) = Square) and
          (ColorToRGB(Image.Canvas.Pixels[X, Y]) = ColorToRGB(Color)) then Exit(True);
    Result := False;
  end;
  procedure CheckPaintedPairs(FirstSource, FirstTarget, ReplySource, ReplyTarget: Integer);
  begin
    Image.SetSize(Board.ClientWidth, Board.ClientHeight);
    // Invoke the normal custom-control painting path with an offscreen DC;
    // GTK PaintTo can copy the parent window instead of rendering this control.
    TBoardPaintAccess(Board).Render(Image);
    Check(SquareHasColor(FirstSource, Board.PvSourceSquareColor) and
      SquareHasColor(FirstTarget, Board.PvSourceSquareColor), 'first PV move outlines both squares in the PV color');
    Check(SquareHasColor(ReplySource, Board.HintSourceSquareColor) and
      SquareHasColor(ReplyTarget, Board.HintSourceSquareColor), 'PV reply outlines both squares in the hint color');
  end;
begin
  Form := TMainForm.Create(nil); Display := TDisplayedPosition.Create; Image := TBitmap.Create;
  Form.LoadStandaloneFen(DefaultStartingFEN);
  Actor := TGameTreeActor.Create(Form.ActiveGameTree, False);
  try
    Board := TDraughtsBoardControl(Form.FindComponent('MainBoard'));
    Board.Align := alNone; Board.SetBounds(0, 0, 500, 500);
    Board.PvSourceSquareColor := clFuchsia; Board.HintSourceSquareColor := clAqua;
    Main := Menu(Form, 'Show hints from main PV');
    Annotator := Menu(Form, 'Show hints from annotator PV');
    None := Menu(Form, 'Do not show hints');
    Check(Main.Checked and not Annotator.Checked and not None.Checked, 'main PV remains the default');
    Command := Actor.CreateRecordEnginePVCommand(Form.ActiveGameTree.Root.NodeId, '0', '32-28 18-23');
    try Actor.ExecuteCommand(Command); Check(Command.Accepted, Command.ErrorText); finally Command.Free; end;
    Command := Actor.CreateRecordAnnotatorPVCommand(Form.ActiveGameTree.Root.NodeId, '0', '34-30 20-25');
    try Actor.ExecuteCommand(Command); Check(Command.Accepted, Command.ErrorText); finally Command.Free; end;
    Form.TestAnalysis.Pv.SetAnalyzerBaseFromTree(Form.ActiveGameTree, Form.ActiveGameTree.Root.NodeId,
      0, Board.Board, Display, Actor.Revision);
    Before := GameTreeToPdnText(Form.ActiveGameTree); Fen := Board.Board.CurrentFEN;
    Main.Click;
    Check((Board.PvSourceSquare = 32) and (Board.HintSourceSquare = 18) and
      (Board.PvTargetSquare = 28) and (Board.HintTargetSquare = 23), 'main PV supplies its source/target hints');
    CheckPaintedPairs(32, 28, 18, 23);
    Annotator.Click;
    Check(Annotator.Checked and not Main.Checked and not None.Checked, 'annotator choice is exclusive');
    Check((Board.PvSourceSquare = 34) and (Board.HintSourceSquare = 20) and
      (Board.PvTargetSquare = 30) and (Board.HintTargetSquare = 25), 'annotator PV supplies its source/target hints');
    CheckPaintedPairs(34, 30, 20, 25);
    Key := Ord('F'); Form.OnKeyDown(Form, Key, []);
    CheckPaintedPairs(34, 30, 20, 25); // Both endpoints follow flipped square mapping.
    Key := Ord('F'); Form.OnKeyDown(Form, Key, []);
    for I := 1 to 2 do
    begin
      None.Click;
      Check(None.Checked and not Main.Checked and not Annotator.Checked, 'none remains selected when clicked again');
      Check((Board.PvSourceSquare = 0) and (Board.HintSourceSquare = 0) and
        (Board.PvTargetSquare = 0) and (Board.HintTargetSquare = 0), 'none clears all PV hint squares immediately');
    end;
    Image.SetSize(Board.ClientWidth, Board.ClientHeight); TBoardPaintAccess(Board).Render(Image);
    Check(not SquareHasColor(34, Board.PvSourceSquareColor) and
      not SquareHasColor(30, Board.PvSourceSquareColor) and
      not SquareHasColor(20, Board.HintSourceSquareColor) and
      not SquareHasColor(25, Board.HintSourceSquareColor), 'none removes painted source and target outlines');
    Key := Ord('F'); Form.OnKeyDown(Form, Key, []);
    Check(None.Checked and (Board.PvSourceSquare = 0) and (Board.HintSourceSquare = 0), 'refresh cannot re-enable disabled hints');
    Key := Ord('F'); Form.OnKeyDown(Form, Key, []);
    Main.Click;
    Check(Main.Checked and not Annotator.Checked and not None.Checked and
      (Board.PvSourceSquare = 32), 'main hints can be re-enabled');
    Check((GameTreeToPdnText(Form.ActiveGameTree) = Before) and (Board.Board.CurrentFEN = Fen),
      'hint choices do not modify game data or displayed position');
    ClickSquare(Board, 32); ClickSquare(Board, 28);
    Check((Board.PvSourceSquare = 0) and (Board.PvTargetSquare = 0) and
      (Board.HintSourceSquare = 0) and (Board.HintTargetSquare = 0),
      'moving away from the PV base clears all source and target hints');
    None.Click;
    Check((Board.LastMoveTargetSquare = 28) and (Board.PvSourceSquare = 0) and
      (Board.HintSourceSquare = 0), 'none preserves the last-move marker');
    Check((Board.PvTargetSquare = 0) and (Board.HintTargetSquare = 0), 'refresh clears both target hints too');
  finally Image.Free; Actor.Free; Display.Free; Form.Free; end;
end;

procedure CheckInvalidEngineParameters;
var Form: TEngineEditForm; Definition: TExternalEngineDefinition;
  Lines: TStringList; Params: TEngineParamArray; ExeName, ParamName, Before: string;
  I, Row: Integer; Grid: TStringGrid;
begin
  ExeName := GetTempFileName(GetTempDir, 'gwdedit'); ParamName := EngineParamsFileName(ExeName);
  Definition := TExternalEngineDefinition.Create; Lines := TStringList.Create;
  Definition.Kind := eekHub; Definition.ExePath := ExeName;
  AddOrUpdateParam(Params, 'path', 'string', 'valid', False);
  SaveEngineParamsToJson(ParamName, 'hub', Params);
  Lines.LoadFromFile(ParamName); Before := Lines.Text;
  Form := TEngineEditForm.Create(nil);
  try
    Form.LoadEngine(Definition); Grid := nil;
    for I := 0 to Form.ComponentCount - 1 do
      if Form.Components[I] is TStringGrid then Grid := TStringGrid(Form.Components[I]);
    Check(Grid <> nil, 'engine parameter grid exists'); Row := -1;
    for I := 1 to Grid.RowCount - 1 do if Grid.Cells[0, I] = 'path' then Row := I;
    Check(Row > 0, 'saved parameter loaded into editor');
    Grid.Cells[2, Row] := 'bad"quote';
    GuiTestConfirmationResult := mrOk;
    try ButtonWithCaption(Form, 'Launched correctly').Click;
    finally GuiTestConfirmationResult := 0; end;
    Check(Pos('path', GuiTestLastConfirmationText) > 0, 'editor identifies the invalid parameter');
    Lines.LoadFromFile(ParamName);
    Check(Lines.Text = Before, 'invalid editor parameter cannot overwrite saved settings');
  finally Form.Free; Definition.Free; Lines.Free; DeleteFile(ExeName); DeleteFile(ParamName); end;
end;

var Reporter: TExceptionReporter;
begin
  if ParamStr(1) = '--boundary-hub' then begin FakeHub; Halt(0); end;
  RequireDerivedFormResource := False; Application.Initialize;
  Reporter := TExceptionReporter.Create; Application.OnException := @Reporter.Report;
  try
    CheckCaptureAndFlip;
    CheckAmbiguousCapture;
    CheckReplacementPrompt;
    CheckAnalysisControls;
    CheckInvalidEngineParameters;
    CheckHintModes;
    Application.OnException := nil; Reporter.Free;
    WriteLn('OK');
  except on E: Exception do begin WriteLn('FAIL: ', E.ClassName, ': ', E.Message); DumpExceptionBackTrace(Output); Halt(1); end; end;
end.
