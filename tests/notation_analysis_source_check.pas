program notation_analysis_source_check;
{$mode objfpc}{$H+}{$codepage utf8}
uses SysUtils, uGameTree, uGameTreePdn, uNotationPresentation, uTreeTestUtils, uNotationDocument, uNotationStyles, uDraughtsPosition;
procedure Check(B: Boolean; const Text: string);
begin if not B then raise Exception.Create(Text); end;
procedure Fixture(BlackStart: Boolean; MoveCount: Integer);
var Tree: TGameTree; Presenter: TNotationPresentation; Options: TGameTreePdnRenderOptions;
    Flags, I, Expected: Integer; Hit: TMoveVariationHit; Source: TNotationAnalysisSource;
    Counts: array[TNotationAnalysisSource] of Integer; Doc: TNotationDocument; ExpectedStyle: TNotationStyle; Changed: Boolean;
    PV, Before: string; Selection: TNotationSelection; Target: TNotationBrowseTarget;
begin
  Tree := TGameTree.Create; Presenter := TNotationPresentation.Create; Doc := TNotationDocument.Create;
  try
    if BlackStart then Tree.BeginRebuild('black', '?', 'W', 'B', '*', 'B:W31-50:B1-20');
    Tree.RecordNodeAnnotation(Tree.Root, 'Unicode 棋 😀');
    if MoveCount > 0 then
      if BlackStart then Tree.RecordMainlineMove(1, '20-25') else Tree.RecordMainlineMove(1, '32-28');
    if BlackStart then
    begin PV := '18-23 34-29'; AddFixtureBranch(Tree, 0, '19-23 33-29', 'branch'); end
    else begin PV := '31-26 19-23'; AddFixtureBranch(Tree, 0, '33-29 19-23', 'branch'); end;
    // Identical PVs and scores cannot be classified by parsing visible text.
    Tree.RecordEnginePV(0, '0.1', PV); Tree.RecordAnnotatorPV(0, '0.1', PV);
    Tree.RecordAutoPlayPVForNodeId(Tree.Root.NodeId, PV, Changed);
    Before := GameTreeToPdnText(Tree);
    Selection := Default(TNotationSelection); Selection.BasePly := -1;
    for Flags := 0 to 63 do
    begin
      Options := DefaultGameTreePdnRenderOptions;
      Options.ShowEnginePVMove := (Flags and 1) <> 0;
      Options.ShowEngineFullPV := (Flags and 2) <> 0;
      Options.ShowAnnotatorPVMove := (Flags and 4) <> 0;
      Options.ShowAnnotatorFullPV := (Flags and 8) <> 0;
      Options.ShowEngineScore := (Flags and 16) <> 0;
      Options.ShowAnnotatorScore := (Flags and 16) <> 0;
      Options.HideAnnotations := (Flags and 32) <> 0;
      Presenter.Render(Tree, Options); Doc.UsePresentation(Presenter); FillChar(Counts, SizeOf(Counts), 0);
      for I := 0 to Presenter.VariationCount-1 do
      begin
        Hit := Presenter.VariationHits[I]; Inc(Counts[Hit.AnalysisSource]);
        if Hit.NodeId > 0 then Check(Hit.AnalysisSource = nasNone, 'real branch has no analysis source')
        else begin
          Check(Hit.AnalysisSource <> nasNone, 'each PV prefix/move has a source');
          case Hit.AnalysisSource of
            nasEngine: ExpectedStyle := nsEnginePV;
            nasAnnotator: ExpectedStyle := nsAnnotatorPV;
            else ExpectedStyle := nsAnalysis;
          end;
          Check((Doc.StyleAt(Hit.Start) = ExpectedStyle) and
            (Doc.StyleAt(Hit.Start+Hit.Length-1) = ExpectedStyle), 'source-specific prefix/move style');
          Check((Hit.BasePly = 0) and (Hit.MovesText = PV), 'source preserves preview base/content');
          Target := Presenter.HitTest(Hit.Start+1, 0, Selection);
          Check((Target.Kind = nbPreview) and (Target.Variation.AnalysisSource = Hit.AnalysisSource), 'preview target retains source');
        end;
      end;
      for Source := nasEngine to nasAutoPlay do
      begin
        case Source of
          nasEngine: if Options.ShowEngineFullPV then Expected := 3 else if Options.ShowEnginePVMove then Expected := 2 else Expected := 0;
          nasAnnotator: if Options.ShowAnnotatorFullPV then Expected := 3 else if Options.ShowAnnotatorPVMove then Expected := 2 else Expected := 0;
          else Expected := 3;
        end;
        Check(Counts[Source] = Expected, 'source count/filter/prefix mismatch');
      end;
      Check(GameTreeToPdnText(Tree) = Before, 'metadata cannot change PDN export');
    end;
    Presenter.ClearVariationHits; Check(Presenter.VariationCount = 0, 'clears source-bearing hits');
  finally Doc.Free; Presenter.Free; Tree.Free; end;
end;
begin
  Fixture(False,0); Fixture(False,1); Fixture(True,0); Fixture(True,1);
  WriteLn('Notation analysis-source checks passed');
end.
