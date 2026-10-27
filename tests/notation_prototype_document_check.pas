program notation_prototype_document_check;
{$mode objfpc}{$H+}{$codepage utf8}
uses SysUtils, uGameTree, uGameTreePdn, uNotationPresentation, uNotationDocument, uNotationStyles,
  uTreeTestUtils;
procedure Check(B: Boolean; const S: string);
begin if not B then raise Exception.Create(S); end;
var Tree: TGameTree; Doc: TNotationDocument; Opt: TGameTreePdnRenderOptions;
    Before: string; I, Flags, U, C: Integer; R: TNotationRange;
    H: TMoveVariationHit; Sel: TNotationSelection; Target: TNotationBrowseTarget;
begin
  Tree := TGameTree.Create; Doc := TNotationDocument.Create;
  try
    Tree.RecordNodeAnnotation(Tree.Root, 'Gérard 棋 😀 before moves');
    Tree.RecordMainlineMove(1, '32-28'); Tree.RecordMainlineMove(2, '18-23');
    Tree.RecordMainlineMove(3, '37-32');
    AddFixtureBranch(Tree, 0, '33-29 19-23', 'Unicode αβ');
    Tree.RecordEnginePV(0, '0.1', '31-26 19-23');
    Tree.RecordAnnotatorPV(0, '0.2', '34-29 20-25');
    Before := GameTreeToPdnText(Tree);
    Sel := Default(TNotationSelection); Sel.BasePly := -1;
    for Flags := 0 to 15 do
    begin
      Opt := DefaultGameTreePdnRenderOptions;
      Opt.ShowEngineFullPV := (Flags and 1) <> 0;
      Opt.ShowAnnotatorFullPV := (Flags and 2) <> 0;
      Opt.HideAnnotations := (Flags and 4) <> 0;
      Opt.ShowClocks := (Flags and 8) <> 0;
      Doc.Render(Tree, Opt);
      for I := 0 to Length(Doc.Text) do
        if (I = Length(Doc.Text)) or ((Byte(Doc.Text[I+1]) and $C0) <> $80) then
        begin
          Check(Doc.PointOffset(Doc.LinePoint(I)) = I, 'line/byte round trip');
          for U := 0 to 1 do for C := 0 to 1 do
            Check(Doc.NativeToByte(Doc.NativeOffset(I, U<>0, C<>0), U<>0, C<>0) = I,
              'Unicode/native offset round trip');
        end;
      for I := 0 to Doc.Presenter.MoveCount-1 do
      begin
        R := Doc.Presenter.MoveRanges[I];
        Check(Doc.StyleAt(R.Start) = nsPlayed, 'played move style');
        Target := Doc.Presenter.HitTest(R.Start, 0, Sel);
        Check(Target.Kind = nbMainline, 'played hit preserved');
      end;
      for I := 0 to Doc.Presenter.VariationCount-1 do
      begin
        H := Doc.Presenter.VariationHits[I];
        if H.NodeId > 0 then Check(Doc.StyleAt(H.Start) = nsVariation, 'branch style')
        else case H.AnalysisSource of
          nasEngine: Check(Doc.StyleAt(H.Start) = nsEnginePV, 'engine style');
          nasAnnotator: Check(Doc.StyleAt(H.Start) = nsAnnotatorPV, 'annotator style');
          else Check(Doc.StyleAt(H.Start) = nsAnalysis, 'Auto Play style');
        end;
      end;
      Check(GameTreeToPdnText(Tree) = Before, 'prototype must preserve model/export');
    end;
    WriteLn('Notation prototype document checks passed');
  finally Doc.Free; Tree.Free; end;
end.
