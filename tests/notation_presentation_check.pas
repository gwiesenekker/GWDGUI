program notation_presentation_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uGameTree, uGameTreePdn, uNotationPresentation,
  uTreeTestUtils;
procedure Check(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;
procedure CheckRender(Presenter: TNotationPresentation; Tree: TGameTree;
  const Options: TGameTreePdnRenderOptions);
var Rendered: TGameTreePdnRenderResult; Hit: TMoveVariationHit;
  Range: TNotationRange; I: Integer;
begin
  RenderGameTreeMovesToPdn(Tree, Options, Rendered);
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
      (Hit.Start = Rendered.VariationStarts[I]) and
      (Hit.Length = Rendered.VariationLengths[I]) and
      (Hit.VariationPly = Rendered.VariationPlies[I]) and
      (Hit.BasePly = Rendered.VariationBasePlies[I]) and
      (Hit.MovesText = Rendered.VariationMovesTexts[I]), 'all variation hit metadata unchanged');
  end;
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
  Writeln('Notation presentation checks passed');
end.
