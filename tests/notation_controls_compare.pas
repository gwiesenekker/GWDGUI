program notation_controls_compare;
{$mode objfpc}{$H+}{$codepage utf8}
uses {$IFDEF UNIX}cthreads, cwstring,{$ENDIF} Interfaces, Forms, Controls,
  StdCtrls, ExtCtrls, Classes, SysUtils, Math, Types, Graphics, LCLType, LCLIntf,
  LazUTF8, LCLVersion, SynEdit, uDraughtsBoard, uGameTreeBuilder, RichMemo, uPdn, uGameTree, uGameTreeActor,
  uGameTreePdn, uGameTreeCursor, uGameTreeNodeData, uGameOrchestrator, uNotationPresentation,
  uNotationPrototypeDocument, uNotationControlPrototype, uTreeTestUtils;
type
  TComparisonForm = class(TForm)
  public
    Choice: TComboBox;
    Status: TLabel;
    Host: TPanel;
    View: TNotationControlPrototype;
    Doc: TNotationPrototypeDocument;
    Tree: TGameTree;
    Selection: TNotationSelection;
    GameCursor: TGameTreeCursor;
    procedure HighlightCursor;
    procedure Changed(Sender: TObject);
    procedure Clicked(Sender: TObject);
    procedure Keyed(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ShowTarget(const Target: TNotationBrowseTarget);
    procedure Attach(Kind: TPrototypeControlKind);
  end;
procedure Check(B: Boolean; const S: string);
begin if not B then raise Exception.Create(S); end;
procedure TComparisonForm.Attach(Kind: TPrototypeControlKind);
begin
  FreeAndNil(View);
  View := TNotationControlPrototype.Create(Self, Host, Kind);
  case Kind of
    pcMemo: begin TMemo(View.Control).OnClick := @Clicked; TMemo(View.Control).OnKeyDown := @Keyed; end;
    pcSynEdit: begin TSynEdit(View.Control).OnClick := @Clicked; TSynEdit(View.Control).OnKeyDown := @Keyed; end;
    pcRichMemo: begin TRichMemo(View.Control).OnClick := @Clicked; TRichMemo(View.Control).OnKeyDown := @Keyed; end;
  end;
  View.Load(Doc); View.Control.SetFocus;
end;
procedure TComparisonForm.Changed(Sender: TObject);
begin Attach(TPrototypeControlKind(Choice.ItemIndex)); end;
procedure TComparisonForm.HighlightCursor;
var R: TNotationRange; Node: TGameTreePlyNode; IsVariation: Boolean;
begin
  Node := GameCursor.Resolve(Tree);
  Selection.NodeId := Node.NodeId;
  R := Doc.Presenter.AutomaticHighlight(Selection, Node.PlyNumber, IsVariation);
  if Doc.Presenter.SelectionHighlight(Selection, R) then begin end;
  View.SelectRange(R.Start, R.Length);
end;
procedure TComparisonForm.ShowTarget(const Target: TNotationBrowseTarget);
begin
  Status.Caption := Format('kind=%d  node=%d  base=%d  preview ply=%d  (Ctrl+C copies selection)',
    [Ord(Target.Kind), Target.Variation.NodeId, Target.Variation.BasePly, Target.Variation.VariationPly]);
  case Target.Kind of
    nbMainline: begin
      GameCursor.Select(Tree, Tree.MainlineNode[Target.Ply]);
      Selection.PreviewMoves := ''; Selection.NodeId := GameCursor.NodeId;
    end;
    nbNode: begin
      GameCursor.Select(Tree, Tree.FindNodeById(Target.Variation.NodeId));
      Selection.PreviewMoves := ''; Selection.NodeId := GameCursor.NodeId;
    end;
    nbBeforeNode: begin
      GameCursor.SelectBefore(Tree, Tree.FindNodeById(Target.Variation.NodeId));
      Selection.PreviewMoves := ''; Selection.NodeId := GameCursor.NodeId;
    end;
    nbPreview: begin
      Selection.BasePly := Target.Variation.BasePly;
      Selection.PreviewPly := Target.Variation.VariationPly;
      Selection.PreviewMoves := Target.Variation.MovesText;
    end;
  end;
end;
procedure TComparisonForm.Clicked(Sender: TObject);
begin ShowTarget(Doc.Presenter.HitTest(View.SelectionStart, 0, Selection)); end;
procedure TComparisonForm.Keyed(Sender: TObject; var Key: Word; Shift: TShiftState);
var I, Count: Integer; Moves: TStringList; H: TMoveVariationHit;
begin
  if Shift <> [] then Exit;
  if Key = VK_ESCAPE then
  begin
    Selection := Default(TNotationSelection); Selection.BasePly := -1;
    GameCursor.Follow; HighlightCursor; Status.Caption := 'Following current position'; Key := 0; Exit;
  end;
  if not (Key in [VK_LEFT, VK_RIGHT]) then Exit;
  if Selection.PreviewMoves <> '' then
  begin
    Moves := TStringList.Create;
    try TextToMoveList(Selection.PreviewMoves, Moves); Count := Moves.Count; finally Moves.Free; end;
    if Key = VK_LEFT then Dec(Selection.PreviewPly) else Inc(Selection.PreviewPly);
    if Selection.PreviewPly < 0 then Selection.PreviewPly := Count;
    if Selection.PreviewPly > Count then Selection.PreviewPly := 0;
    for I := 0 to Doc.Presenter.VariationCount-1 do
    begin
      H := Doc.Presenter.VariationHits[I];
      if (H.MovesText = Selection.PreviewMoves) and (H.BasePly = Selection.BasePly) and
        (H.VariationPly = Selection.PreviewPly) then
      begin View.SelectRange(H.Start, H.Length); Break; end;
    end;
  end
  else
  begin
    if Key = VK_LEFT then GameCursor.StepLeft(Tree) else GameCursor.StepRight(Tree);
    HighlightCursor;
  end;
  Key := 0;
end;
procedure Pump(Form: TComparisonForm);
begin Application.ProcessMessages; Form.View.Control.Repaint; Application.ProcessMessages; end;
function LoadActor(const FileName: string): TGameTreeActor;
var Games: TList; Game: TPdnGame; Root: TPdnMoveNode; Moves: TStringList; Cmd: TGameTreeCommand; I: Integer;
  procedure Execute(C: TGameTreeCommand);
  begin
    try Result.ExecuteCommand(C); Check(C.Accepted, C.ErrorText); finally C.Free; end;
  end;
begin
  Games := TList.Create; Moves := TStringList.Create; Root := nil; Result := nil;
  try
    LoadPdnGamesFromFile(FileName, Games); Check(Games.Count = 1, 'Expected one fixture game');
    Game := TPdnGame(Games[0]); Root := Game.BuildMoveTree; TextToMoveList(Game.MovesText, Moves);
    Result := TGameTreeActor.Create;
    Execute(Result.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('prototype', Game.EventName, Game.WhiteName, Game.BlackName,
        Game.ResultText, Game.StartingFEN, False, DefaultTimeControl),
      GameTreeMainlineInput(Moves, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
    Cmd := Result.CreateImportPdnTreeCommand(Root);
    try
      Result.ExecuteCommand(Cmd); Check(Cmd.Accepted, Cmd.ErrorText);
      WriteLn('# import_warnings=', Cmd.ImportWarnings.Count);
    finally Cmd.Free; end;
  finally
    Root.Free; Moves.Free;
    for I := 0 to Games.Count-1 do TObject(Games[I]).Free;
    Games.Free;
  end;
end;
procedure Verify(Form: TComparisonForm);
var I, Pos, Len: Integer; Range: TNotationRange; Hit: TMoveVariationHit;
    Expected, Actual: TNotationBrowseTarget; Before: string;
  procedure SelectAndCheck;
  begin
    Form.View.SelectRange(Pos, Len); Pump(Form);
    Check(Form.View.SelectionStart = Pos, 'selection offset '+IntToStr(Pos));
    Check(Form.View.SelectedText = Copy(Form.Doc.Text, Pos+1, Len),
      Format('%s selection/copy text at %d+%d: expected [%s], got [%s]',
        [PrototypeNames[Form.View.Kind], Pos, Len, Copy(Form.Doc.Text, Pos+1, Min(Len, 80)), Copy(Form.View.SelectedText, 1, 80)]));
    Expected := Form.Doc.Presenter.HitTest(Pos, 0, Form.Selection);
    Actual := Form.Doc.Presenter.HitTest(Form.View.SelectionStart, 0, Form.Selection);
    Check((Actual.Kind = Expected.Kind) and (Actual.Ply = Expected.Ply) and
      (Actual.Variation.NodeId = Expected.Variation.NodeId) and
      (Actual.Variation.BasePly = Expected.Variation.BasePly) and
      (Actual.Variation.VariationPly = Expected.Variation.VariationPly) and
      (Actual.Variation.MovesText = Expected.Variation.MovesText), 'navigation target');
  end;
begin
  Before := GameTreeToPdnText(Form.Tree);
  Check(Form.View.ReadText = Form.Doc.Text, 'control text differs from presenter');
  Form.View.CheckStyles;
  for I := 0 to Form.Doc.Presenter.MoveCount-1 do
  begin
    if (I mod Max(1, Form.Doc.Presenter.MoveCount div 12) <> 0) and
      (I <> Form.Doc.Presenter.MoveCount-1) then Continue;
    Range := Form.Doc.Presenter.MoveRanges[I]; Pos := Range.Start; Len := Range.Length; SelectAndCheck;
  end;
  for I := 0 to Form.Doc.Presenter.VariationCount-1 do
  begin
    if (I mod Max(1, Form.Doc.Presenter.VariationCount div 12) <> 0) and
      (I <> Form.Doc.Presenter.VariationCount-1) then Continue;
    Hit := Form.Doc.Presenter.VariationHits[I]; Pos := Hit.Start; Len := Hit.Length; SelectAndCheck;
  end;
  // Arbitrary text selections include newlines, combining and non-BMP characters.
  Pos := 0; Len := Length(Form.Doc.Text); SelectAndCheck;
  Check(GameTreeToPdnText(Form.Tree) = Before, 'view changed tree or PDN');
end;
procedure VerifyKeys(Form: TComparisonForm);
var Key: Word; I: Integer; H: TMoveVariationHit; R: TNotationRange;
    Node: TGameTreePlyNode; OriginalId: Int64; Target: TNotationBrowseTarget;
begin
  if Form.Doc.Presenter.MoveCount < 2 then Exit;
  Form.Selection := Default(TNotationSelection); Form.Selection.BasePly := -1;
  R := Form.Doc.Presenter.MoveRanges[0]; Form.View.SelectRange(R.Start, 0);
  Form.Clicked(Form.View.Control);
  Check(Form.GameCursor.Resolve(Form.Tree) = Form.Tree.MainlineNode[1], 'mainline click cursor');
  Key := VK_RIGHT; Form.Keyed(Form.View.Control, Key, []);
  Check((Key = 0) and (Form.GameCursor.Resolve(Form.Tree) = Form.Tree.MainlineNode[2]), 'Right handler');
  Key := VK_LEFT; Form.Keyed(Form.View.Control, Key, []);
  Check(Form.GameCursor.Resolve(Form.Tree) = Form.Tree.MainlineNode[1], 'Left handler');
  for I := 0 to Form.Doc.Presenter.VariationCount-1 do
  begin
    H := Form.Doc.Presenter.VariationHits[I];
    if (H.NodeId = 0) and (I mod Max(1, Form.Doc.Presenter.VariationCount div 12) <> 0) then Continue;
    Form.Selection := Default(TNotationSelection); Form.Selection.BasePly := -1;
    Form.View.SelectRange(H.Start+1, 0);
    Target := Form.Doc.Presenter.HitTest(H.Start+1, 0, Form.Selection);
    Form.Clicked(Form.View.Control);
    H := Target.Variation;
    if Target.Kind in [nbNode, nbBeforeNode] then
    begin
      Node := Form.Tree.FindNodeById(H.NodeId);
      if Target.Kind = nbBeforeNode then Check(Form.GameCursor.Resolve(Form.Tree) = Node.Parent, 'before-branch cursor')
      else begin
        OriginalId := Form.GameCursor.NodeId;
        Key := VK_LEFT; Form.Keyed(Form.View.Control, Key, []);
        Key := VK_RIGHT; Form.Keyed(Form.View.Control, Key, []);
        Check(Form.GameCursor.NodeId = OriginalId, 'branch Left/Right retains node');
      end;
    end
    else if Target.Kind = nbPreview then begin
      Check(Form.Selection.PreviewMoves = H.MovesText, 'PV click preview');
      Key := VK_RIGHT; Form.Keyed(Form.View.Control, Key, []);
      Key := VK_LEFT; Form.Keyed(Form.View.Control, Key, []);
      Check(Form.Selection.PreviewPly = H.VariationPly, 'PV Left/Right wraps consistently');
    end;
  end;
  Key := VK_ESCAPE; Form.Keyed(Form.View.Control, Key, []);
  Check((Key = 0) and Form.GameCursor.Following and (Form.Selection.PreviewMoves = ''), 'Escape handler');
  Form.Selection := Default(TNotationSelection); Form.Selection.BasePly := -1;
end;
procedure EdgeCases(Form: TComparisonForm);
var Tree: TGameTree; Doc: TNotationPrototypeDocument; OldTree: TGameTree;
    OldDoc: TNotationPrototypeDocument; Options: TGameTreePdnRenderOptions; I: Integer;
begin
  Tree := TGameTree.Create; Doc := TNotationPrototypeDocument.Create;
  OldTree := Form.Tree; OldDoc := Form.Doc;
  try
    Form.Tree := Tree; Form.Doc := Doc;
    Tree.RecordNodeAnnotation(Tree.Root, 'Gérard 棋 😀 é'+#10+'second line');
    Doc.Render(Tree, DefaultGameTreePdnRenderOptions); Form.View.Load(Doc); Pump(Form); Verify(Form);
    Tree.BeginRebuild('black', '?', 'W', 'B', '*', 'B:W31-50:B1-20');
    Tree.RecordNodeAnnotation(Tree.Root, 'Gérard 棋 😀 é');
    Tree.RecordMainlineMove(1, '20-25'); Tree.RecordMainlineMove(2, '32-28');
    AddFixtureBranch(Tree, 0, '19-23 33-29', 'branch 棋');
    Tree.RecordNodeAnnotation(Tree.RecordBranchMove(Tree.Root.Children[1], '34-30'), 'nested αβ');
    Tree.RecordEnginePV(0, '0.1', '18-23 34-29');
    Tree.RecordAnnotatorPV(0, '0.2', '17-22 35-30');
    for I := 0 to 1 do
    begin
      Options := DefaultGameTreePdnRenderOptions; Options.HideAnnotations := I<>0;
      Doc.Render(Tree, Options); Form.View.Load(Doc); Pump(Form); Verify(Form);
    end;
    Tree.RecordNodeAnnotation(Tree.Root, StringOfChar('a', 70000)+UTF8String(' tail 棋 😀'));
    Doc.Render(Tree, DefaultGameTreePdnRenderOptions);
    Check(Length(Doc.Text) > 65536, 'large-text fixture must exceed 64K');
    Form.View.Load(Doc); Pump(Form); Verify(Form);
  finally
    Form.Doc := OldDoc; Form.Tree := OldTree; Form.View.Load(OldDoc);
    Doc.Free; Tree.Free;
  end;
end;
procedure Benchmark(Form: TComparisonForm; Samples: Integer);
var Sample, I, Op, Count, Position: Integer; Tick: QWord;
    Range: TNotationRange; Before: string; Kind: TPrototypeControlKind;
    SavedData: TGameTreeNodeData; UpdateNode: TGameTreePlyNode;
const Ops: array[0..4] of string = ('reload_styled', 'browse', 'resize_wrap', 'live_update', 'cached_refresh');
begin
  WriteLn('# LCL=', lcl_version, ' platform=', {$IFDEF MSWINDOWS}'win32'{$ELSE}'gtk2'{$ENDIF},
    ' font=DejaVu Sans Mono 11; fixed client=760x600; synchronous repaint/event drain');
  WriteLn('# bytes=', Length(Form.Doc.Text), ' plies=', Form.Doc.Presenter.MoveCount,
    ' hits=', Form.Doc.Presenter.VariationCount, ' style_spans=', Length(Form.Doc.Spans));
  WriteLn('control,operation,sample,iterations,total_ms,ms_per_op');
  for Kind := Low(Kind) to High(Kind) do
  begin
    if (GetEnvironmentVariable('GWDGUI_COMPARE_CONTROL') <> '') and
      (GetEnvironmentVariable('GWDGUI_COMPARE_CONTROL') <> PrototypeNames[Kind]) then Continue;
    WriteLn(StdErr, 'Checking ', PrototypeNames[Kind], ' text/styles/selection...');
    Form.Attach(Kind); Pump(Form); Verify(Form);
    WriteLn(StdErr, 'Checking ', PrototypeNames[Kind], ' click/key handlers...');
    VerifyKeys(Form);
    WriteLn(StdErr, 'Checking ', PrototypeNames[Kind], ' Unicode/empty/Black-start/>64K...');
    EdgeCases(Form);
    WriteLn(StdErr, 'Timing ', PrototypeNames[Kind], '...'); Flush(StdErr);
    Before := GameTreeToPdnText(Form.Tree);
    UpdateNode := Form.Tree.MainlineNode[Form.Tree.MainlineCount div 2];
    SavedData := UpdateNode.NodeData;
    for Sample := 1 to Samples do
      for Op := 0 to High(Ops) do
      begin
        if Op = 1 then Count := 30 else if Op in [0, 3] then Count := 5 else Count := 10;
        Form.Host.Width := 760;
        Form.Doc.Render(Form.Tree, DefaultGameTreePdnRenderOptions);
        Form.View.Load(Form.Doc); Pump(Form);
        Tick := GetTickCount64;
        for I := 0 to Count-1 do
        begin
          case Op of
            0: Form.View.Load(Form.Doc);
            1: begin
              Position := (I*37) mod Form.Doc.Presenter.MoveCount;
              Range := Form.Doc.Presenter.MoveRanges[Position];
              Form.View.SelectRange(Range.Start, Range.Length);
            end;
            2: Form.Host.Width := 600 + (I mod 2)*160;
            3: begin
              Form.Tree.RecordEnginePV(UpdateNode.PlyNumber, '0.'+IntToStr(I mod 2), SavedData.EnginePV);
              Form.Doc.Render(Form.Tree, DefaultGameTreePdnRenderOptions);
              Form.View.Load(Form.Doc);
              Range := Form.Doc.Presenter.MoveRanges[Form.Doc.Presenter.MoveCount div 2];
              Form.View.SelectRange(Range.Start, Range.Length);
            end;
            4: begin
              // Application-level no-op: avoid reassigning unchanged text or styles.
              Form.View.Refresh(Form.Doc);
            end;
          end;
          Pump(Form);
        end;
        Tick := GetTickCount64-Tick;
        WriteLn(PrototypeNames[Kind], ',', Ops[Op], ',', Sample, ',', Count, ',', Tick, ',',
          FormatFloat('0.000', Tick/Count)); Flush(Output);
        Form.Tree.RestoreNodeData(UpdateNode.NodeId, SavedData);
      end;
    Form.Doc.Render(Form.Tree, DefaultGameTreePdnRenderOptions); Form.View.Load(Form.Doc); Pump(Form);
    Check(GameTreeToPdnText(Form.Tree) = Before, 'benchmark did not restore fixture');
    WriteLn('# ', PrototypeNames[Kind], ': text/ranges/styles/Unicode/empty/Black-start/filters passed');
  end;
end;
var Form: TComparisonForm; Actor: TGameTreeActor; Doc: TNotationPrototypeDocument;
    Kind: TPrototypeControlKind; Samples: Integer;
begin
  try
  DefaultFormatSettings.DecimalSeparator := '.';
  Application.Initialize; Application.CaptureExceptions := False;
  Form := TComparisonForm.CreateNew(nil); Actor := nil; Doc := TNotationPrototypeDocument.Create;
  try
    Check(ParamCount >= 1, 'Usage: notation_controls_compare fixture.pdn [samples] [--interactive]');
    Samples := 3; if ParamCount >= 2 then Samples := StrToInt(ParamStr(2));
    Actor := LoadActor(ParamStr(1)); Form.Tree := Actor.GameTree; Form.Doc := Doc;
    Doc.Render(Form.Tree, DefaultGameTreePdnRenderOptions);
    Form.Caption := 'Notation comparison: gray comments, bold moves, green branches, blue PVs';
    Form.ClientWidth := 800; Form.ClientHeight := 680;
    Form.Choice := TComboBox.Create(Form); Form.Choice.Parent := Form;
    Form.Choice.SetBounds(12, 8, 200, 28); Form.Choice.Style := csDropDownList;
    for Kind := Low(Kind) to High(Kind) do Form.Choice.Items.Add(PrototypeNames[Kind]);
    Form.Choice.ItemIndex := 0; Form.Choice.OnChange := @Form.Changed;
    Form.Status := TLabel.Create(Form); Form.Status.Parent := Form; Form.Status.SetBounds(12, 42, 780, 25);
    Form.Status.Caption := 'Select moves/PVs; Left/Right browse; Escape clears preview; Ctrl+C copies';
    Form.Host := TPanel.Create(Form); Form.Host.Parent := Form; Form.Host.SetBounds(12, 70, 760, 600);
    Form.Host.BevelOuter := bvNone;
    Form.Selection := Default(TNotationSelection); Form.Selection.BasePly := -1;
    Form.GameCursor := TGameTreeCursor.Create;
    Form.Show; Application.ProcessMessages; Form.Attach(pcMemo);
    if (ParamCount >= 3) and (ParamStr(3) = '--interactive') then Application.Run
    else Benchmark(Form, Samples);
  finally
    Form.View.Free; Form.View := nil; Form.GameCursor.Free; Form.Free; Doc.Free; Actor.Free;
  end;
  except on E: Exception do begin WriteLn(StdErr, E.ClassName, ': ', E.Message); Halt(1); end; end;
end.
