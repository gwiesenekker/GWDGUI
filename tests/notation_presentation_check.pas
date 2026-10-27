program notation_presentation_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uGameTree, uGameTreePdn, uNotationPresentation,
  uTreeTestUtils;
procedure Check(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;
var RenderDigest: QWord = QWord($CBF29CE484222325);
    ExportDigest: QWord = QWord($CBF29CE484222325);
procedure DigestText(const Text: string);
var I: Integer;
begin
  for I := 1 to Length(Text) do
    RenderDigest := (RenderDigest xor Ord(Text[I])) * QWord(1099511628211);
  RenderDigest := (RenderDigest xor 0) * QWord(1099511628211);
end;
procedure DigestExport(const Text: string);
var I: Integer;
begin
  for I := 1 to Length(Text) do
    ExportDigest := (ExportDigest xor Ord(Text[I])) * QWord(1099511628211);
  ExportDigest := (ExportDigest xor 0) * QWord(1099511628211);
end;
function CountMoveNodes(Node: TGameTreePlyNode): Integer;
var I: Integer;
begin
  Result := 0;
  for I := 0 to Node.ChildCount - 1 do
    Inc(Result, 1 + CountMoveNodes(Node.Children[I]));
end;
procedure CheckRender(Presenter: TNotationPresentation; Tree: TGameTree;
  const Options: TGameTreePdnRenderOptions);
var Rendered: TGameTreePdnRenderResult; Hit: TMoveVariationHit;
  Exported: string; Range: TNotationRange; I, Work: Integer; Captions: TGameTreeMoveCaptionMap;
begin
  Captions := TGameTreeMoveCaptionMap.Create;
  try
    BuildGameTreeMoveCaptions(Tree, Captions, Work);
    Check((Captions.Count = CountMoveNodes(Tree.Root)) and (Work = Captions.Count),
      'tree captions include every node with one board move per node');
  finally Captions.Free; end;
  RenderGameTreeMovesToPdn(Tree, Options, Rendered);
  DigestText(Rendered.Text);
  Exported := GameTreeToPdnTextEx(Tree, Options);
  DigestText(Exported); DigestExport(Exported);
  for I := 0 to High(Rendered.MoveStarts) do
    DigestText(IntToStr(Rendered.MoveStarts[I]) + ':' + IntToStr(Rendered.MoveLengths[I]));
  for I := 0 to High(Rendered.VariationStarts) do
    DigestText(IntToStr(Rendered.VariationStarts[I]) + ':' + IntToStr(Rendered.VariationLengths[I]) +
      ':' + IntToStr(Rendered.VariationNodeIds[I]) + ':' + BoolToStr(Rendered.VariationBeforeMoves[I]) +
      ':' + IntToStr(Rendered.VariationPlies[I]) + ':' + IntToStr(Rendered.VariationBasePlies[I]) +
      ':' + Rendered.VariationMovesTexts[I]);
  Check((Rendered.BoardMovesApplied >= Tree.MainlineCount) and
    (Rendered.BoardMovesApplied <= CountMoveNodes(Tree.Root)),
    'incremental rendering applies at most one move per visible model node');
  Presenter.Render(Tree, Options);
  Check(Presenter.Text = Rendered.Text, 'presenter preserves renderer text exactly');
  Check(Presenter.MoveCount = Length(Rendered.MoveStarts), 'mainline count');
  Check(Presenter.VariationCount = Length(Rendered.VariationStarts), 'variation count');
  for I := 0 to Presenter.MoveCount - 1 do
  begin
    Range := Presenter.MoveRanges[I];
    Check((Range.Start = Rendered.MoveStarts[I]) and
      (Range.Length = Rendered.MoveLengths[I]), 'mainline range unchanged');
    Check(Copy(Presenter.Text, Range.Start + 1, Range.Length) <> '', 'range locates visible move');
  end;
  for I := 0 to Presenter.VariationCount - 1 do
  begin
    Hit := Presenter.VariationHits[I];
    Check((Hit.NodeId = Rendered.VariationNodeIds[I]) and
      (Hit.BeforeMove = Rendered.VariationBeforeMoves[I]) and
      (Hit.AnalysisSource = Rendered.VariationAnalysisSources[I]) and
      (Hit.Start = Rendered.VariationStarts[I]) and
      (Hit.Length = Rendered.VariationLengths[I]) and
      (Hit.VariationPly = Rendered.VariationPlies[I]) and
      (Hit.BasePly = Rendered.VariationBasePlies[I]) and
      (Hit.MovesText = Rendered.VariationMovesTexts[I]), 'all variation hit metadata unchanged');
  end;
end;
procedure CheckSelection(Presenter: TNotationPresentation; Tree: TGameTree);
var
  Selection: TNotationSelection;
  Target: TNotationBrowseTarget;
  Range, Expected: TNotationRange;
  Hit, PvHit: TMoveVariationHit;
  I, NodeHits, OpeningHits, PvHits: Integer;
  IsVariation: Boolean;
begin
  Presenter.Render(Tree, DefaultGameTreePdnRenderOptions);
  Selection := Default(TNotationSelection);
  Selection.BasePly := -1;
  NodeHits := 0; OpeningHits := 0; PvHits := 0;
  PvHit := Default(TMoveVariationHit);
  for I := 0 to Presenter.VariationCount - 1 do
  begin
    Hit := Presenter.VariationHits[I];
    Target := Presenter.HitTest(Hit.Start + 1, 0, Selection);
    if Hit.NodeId > 0 then
    begin
      Check(Target.Variation.NodeId = Hit.NodeId, 'branch click keeps real nested node identity');
      if Hit.BeforeMove then
      begin
        Inc(OpeningHits);
        Check(Target.Kind = nbBeforeNode, 'opening bracket selects position before child');
      end
      else
      begin
        Inc(NodeHits);
        Check(Target.Kind = nbNode, 'branch move selects its node');
        Selection.NodeId := Hit.NodeId;
        Selection.BasePly := Hit.BasePly + Hit.VariationPly;
        Range := Presenter.AutomaticHighlight(Selection, Selection.BasePly, IsVariation);
        Check(IsVariation and (Range.Start = Hit.Start) and (Range.Length = Hit.Length),
          'automatic branch highlight uses node identity instead of same-ply mainline');
        Check(Presenter.SelectionHighlight(Selection, Range) and
          (Range.Start = Hit.Start) and (Range.Length = Hit.Length),
          'focused branch highlight uses its move, not opening bracket');
      end;
    end
    else
    begin
      Inc(PvHits);
      Check(Target.Kind = nbPreview, 'analysis range requests a temporary preview');
      if Hit.VariationPly > 0 then PvHit := Hit;
    end;
  end;
  Check((NodeHits > 2) and (OpeningHits > 1) and (PvHits > 1),
    'fixture exercises nested nodes, opening brackets and analysis previews');
  Selection := Default(TNotationSelection);
  Selection.BasePly := -1;
  Expected := Presenter.MoveRanges[0];
  Target := Presenter.HitTest(Expected.Start + 1, 0, Selection);
  Check((Target.Kind = nbMainline) and (Target.Ply = 1), 'mainline caret selects first move');
  Target := Presenter.HitTest(Expected.Start + Expected.Length, 0, Selection);
  Check((Target.Kind = nbMainline) and (Target.Ply = 1), 'caret includes move right endpoint');
  Target := Presenter.HitTest(Expected.Start + Expected.Length, 1, Selection);
  Check((Target.Kind <> nbMainline) or (Target.Ply <> 1), 'selection starting at right edge does not overlap move');
  Target := Presenter.HitTest(Expected.Start - 1, 1, Selection);
  Check((Target.Kind = nbMainline) and (Target.Ply = 0), 'selection ending at first move starts before game');
  Target := Presenter.HitTest(0, 0, Selection);
  Check((Target.Kind = nbMainline) and (Target.Ply = 0), 'introductory comment selects root');
  Hit := Presenter.VariationHits[0];
  Target := Presenter.HitTest(0, Length(Presenter.Text), Selection);
  Check(Target.Variation.Start = Hit.Start, 'variation priority survives selection spanning mainline and branches');
  Range := Presenter.AutomaticHighlight(Selection, Tree.MainlineCount, IsVariation);
  Expected := Presenter.MoveRanges[Tree.MainlineCount - 1];
  Check(not IsVariation and (Range.Start = Expected.Start), 'following running game highlights mainline tip');
  Range := Presenter.AutomaticHighlight(Selection, -1, IsVariation);
  Check((Range.Start = 0) and (Range.Length = 0), 'automatic empty/root highlight clears selection');
  Check(not Presenter.SelectionHighlight(Selection, Range), 'explicit root highlight retains existing memo selection');
  Selection.PreviewMoves := PvHit.MovesText;
  Selection.BasePly := PvHit.BasePly;
  Selection.PreviewPly := PvHit.VariationPly;
  Range := Presenter.AutomaticHighlight(Selection, Selection.BasePly, IsVariation);
  Check(IsVariation and (Range.Start = PvHit.Start) and (Range.Length = PvHit.Length),
    'preview highlight uses full PV, base and preview ply');
  Check(Presenter.SelectionHighlight(Selection, Range) and (Range.Start = PvHit.Start),
    'explicit preview highlight locates same range');
  Target := Presenter.HitTest(PvHit.Start + 1, 0, Selection);
  Check((Target.Kind = nbPreview) and (Target.Variation.MovesText = PvHit.MovesText),
    'active preview permits its own ranges');
  Target := Presenter.HitTest(Presenter.MoveRanges[0].Start + 1, 0, Selection);
  Check(Target.Kind = nbConsumed, 'active preview consumes unrelated mainline click');
  Inc(Selection.BasePly, 99);
  Target := Presenter.HitTest(PvHit.Start + 1, 0, Selection);
  Check(Target.Kind = nbConsumed, 'same PV at a different base is unrelated');
end;

procedure CheckSignature(Tree: TGameTree);
var Options: TGameTreePdnRenderOptions; Before: string;
begin
  Options := DefaultGameTreePdnRenderOptions;
  Before := GameTreeMoveLabelsSignature(Tree, Options);
  Tree.RecordNodeAnnotation(Tree.Root, 'changed introduction');
  Check(Before <> GameTreeMoveLabelsSignature(Tree, Options), 'root comment invalidates labels');
  Options.HideAnnotations := True;
  Before := GameTreeMoveLabelsSignature(Tree, Options);
  Tree.RecordNodeAnnotation(Tree.Root, 'another introduction');
  Check(Before = GameTreeMoveLabelsSignature(Tree, Options), 'hidden comments do not invalidate labels');
  Options.HideAnnotations := False;
  Options.ShowEngineScore := False;
  Before := GameTreeMoveLabelsSignature(Tree, Options);
  Tree.RecordEnginePV(1, '0.9', '20-24 38-32');
  Check(Before = GameTreeMoveLabelsSignature(Tree, Options), 'hidden score does not invalidate labels');
  Options.ShowEngineScore := True;
  Before := GameTreeMoveLabelsSignature(Tree, Options);
  Tree.RecordEnginePV(1, '0.7', '20-24 38-32');
  Check(Before <> GameTreeMoveLabelsSignature(Tree, Options), 'visible score invalidates labels');
  Before := GameTreeMoveLabelsSignature(Tree, Options);
  Tree.RecordClockState(1, 220, 225, 5, 0);
  Check(Before <> GameTreeMoveLabelsSignature(Tree, Options), 'clock invalidates labels');
  Before := GameTreeMoveLabelsSignature(Tree, Options);
  AddFixtureBranch(Tree, 1, '19-24', 'new sibling');
  Check(Before <> GameTreeMoveLabelsSignature(Tree, Options), 'topology invalidates labels');
  Before := GameTreeMoveLabelsSignature(Tree, Options);
  Options.ShowClocks := False;
  Check(Before <> GameTreeMoveLabelsSignature(Tree, Options), 'filter invalidates labels');
end;
var Tree, CaptureTree: TGameTree; Presenter: TNotationPresentation;
  Options: TGameTreePdnRenderOptions; I: Integer; Before: string; Range: TNotationRange;
begin
  Tree := TGameTree.Create;
  CaptureTree := TGameTree.Create;
  Presenter := TNotationPresentation.Create;
  try
    Check((Presenter.Text = '') and (Presenter.MoveCount = 0) and
      (Presenter.VariationCount = 0) and (Presenter.Signature = ''), 'empty presenter');
    Check(GameTreeMoveLabelsSignature(nil, DefaultGameTreePdnRenderOptions) = '', 'nil signature');
    CheckRender(Presenter, Tree, DefaultGameTreePdnRenderOptions);
    Tree.RecordMainlineMove(1, '32-28');
    Tree.RecordMainlineMove(2, '18-23');
    Tree.RecordMainlineMove(3, '37-32');
    Tree.RecordNodeAnnotation(Tree.Root, 'Introduction');
    Tree.RecordMainlineAnnotation(1, 'a comment');
    AddFixtureBranch(Tree, 1, '20-24 38-32 14-20', 'outer note');
    AddFixtureBranch(Tree, 1, '20-24 38-32 18-22', 'nested note');
    Tree.RecordEnginePV(1, '0.1', '20-24 38-32');
    Tree.RecordAnnotatorPV(1, '0.2', '19-23 28x19');
    Tree.RecordClockState(1, 230, 240, 10, 0);
    Before := GameTreeToPdnText(Tree);
    for I := 0 to 255 do
    begin
      Options.HideAnnotations := (I and 1) <> 0;
      Options.ShowEngineScore := (I and 2) <> 0;
      Options.ShowClocks := (I and 4) <> 0;
      Options.ShowEnginePVMove := (I and 8) <> 0;
      Options.ShowEngineFullPV := (I and 16) <> 0;
      Options.ShowAnnotatorPVMove := (I and 32) <> 0;
      Options.ShowAnnotatorFullPV := (I and 64) <> 0;
      Options.ShowAnnotatorScore := (I and 128) <> 0;
      CheckRender(Presenter, Tree, Options);
    end;
    Check(GameTreeToPdnText(Tree) = Before, 'presentation never mutates tree');
    CheckSelection(Presenter, Tree);
    CheckSignature(Tree);
    CaptureTree.BeginRebuild('capture', '?', 'White', 'Black', '*', 'W:W32:B17,27');
    CaptureTree.RecordMainlineMove(1, '32x12x27x17');
    CheckRender(Presenter, CaptureTree, DefaultGameTreePdnRenderOptions);
    Range := Presenter.MoveRanges[0];
    Check(Copy(Presenter.Text, Range.Start + 1, Range.Length) = '32x12',
      'capture range uses PDN caption, not internal capture path');
    Presenter.ClearVariationHits;
    Check((Presenter.VariationCount = 0) and (Presenter.MoveCount = 1), 'clear branch hits preserves mainline ranges');
    Before := Presenter.Text;
    Presenter.InvalidateSignature;
    Check((Presenter.Signature = '') and (Presenter.Text = Before), 'invalidation preserves visible projection');
    Tree.Free;
    Tree := nil;
    Check(Presenter.Text = Before, 'presenter owns projection without retaining tree');
  finally Presenter.Free; CaptureTree.Free; Tree.Free; end;
  // File export remains unchanged; compact text/navigation intentionally moves
  // analysis after the played move (covered independently by analysis-order checks).
  Check(ExportDigest = QWord($874083F2AE786E19), 'file export matches pre-layout-change fingerprint: ' + IntToHex(ExportDigest, 16));
  Check(RenderDigest = QWord($436FE42BE715E249), 'text and navigation ranges match expected analysis-after-move layout: ' + IntToHex(RenderDigest, 16));
  Writeln('Notation presentation checks passed');
end.
