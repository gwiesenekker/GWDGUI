program notation_analysis_order_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uDraughtsBoard, uGameTree, uGameTreePdn,
  uNotationPresentation, uTreeTestUtils;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then raise Exception.Create(Text); end;
function PvFrom(Board: TDraughtsBoard; Choice: Integer): string;
var CopyBoard: TDraughtsBoard;
begin
  CopyBoard := TDraughtsBoard.CreateCopy(Board);
  try
    Result := CopyBoard.LegalMoves[Choice mod CopyBoard.LegalMoveCount];
    CopyBoard.PlayMove(Result);
    if CopyBoard.LegalMoveCount > 0 then Result += ' ' + CopyBoard.LegalMoves[0];
  finally CopyBoard.Free; end;
end;
procedure CheckFixture(BlackStart: Boolean; Count: Integer);
var Tree: TGameTree; Presenter: TNotationPresentation; Options: TGameTreePdnRenderOptions;
  Board: TDraughtsBoard; Selection: TNotationSelection; Target: TNotationBrowseTarget;
  Hit: TMoveVariationHit; Range, NextRange: TNotationRange; Before: string;
  I, Base, Flags, Slot, Expected: Integer; PrefixCounts: array of Integer;
  Changed: Boolean;
begin
  Tree := TGameTree.Create; Presenter := TNotationPresentation.Create; Board := TDraughtsBoard.Create;
  try
    if BlackStart then Tree.BeginRebuild('black', '?', 'White', 'Black', '*', 'B:W31-50:B1-20');
    Board.LoadFromFEN(Tree.StartingFEN);
    for I := 1 to Count do
      if BlackStart then
        case I of
          1: Tree.RecordMainlineMove(I, '20-25');
          2: Tree.RecordMainlineMove(I, '32-28');
          3: Tree.RecordMainlineMove(I, '19-23');
        end
      else
        case I of
          1: Tree.RecordMainlineMove(I, '32-28');
          2: Tree.RecordMainlineMove(I, '18-23');
          3: Tree.RecordMainlineMove(I, '37-32');
        end;
    for Base := 0 to Count do
    begin
      Tree.RecordEnginePV(Base, '0.1', PvFrom(Board, 0));
      Tree.RecordAnnotatorPV(Base, '0.2', PvFrom(Board, 1));
      if Base = 0 then
        Tree.RecordAutoPlayPVForNodeId(Tree.Root.NodeId, PvFrom(Board, 2), Changed)
      else Tree.RecordAutoPlayPVForNodeId(Tree.MainlineNode[Base].NodeId, PvFrom(Board, 2), Changed);
      if Base < Count then Board.PlayMove(Tree.MainlineNode[Base + 1].MoveText);
    end;
    Before := GameTreeToPdnText(Tree);
    for Flags := 0 to 15 do
    begin
      Options := DefaultGameTreePdnRenderOptions;
      Options.ShowEnginePVMove := (Flags and 1) <> 0;
      Options.ShowEngineFullPV := (Flags and 2) <> 0;
      Options.ShowAnnotatorPVMove := (Flags and 4) <> 0;
      Options.ShowAnnotatorFullPV := (Flags and 8) <> 0;
      Presenter.Render(Tree, Options);
      SetLength(PrefixCounts, Count + 1);
      for Base := 0 to Count do PrefixCounts[Base] := 0;
      Selection := Default(TNotationSelection); Selection.BasePly := -1;
      for I := 0 to Presenter.VariationCount - 1 do
      begin
        Hit := Presenter.VariationHits[I]; Base := Hit.BasePly;
        Check((Base >= 0) and (Base <= Count), 'analysis retains original base ply');
        if Hit.VariationPly = 0 then Inc(PrefixCounts[Base]);
        if Count > 0 then
        begin
          Slot := Base; if Slot >= Count then Slot := Count - 1;
          Range := Presenter.MoveRanges[Slot];
          Check(Hit.Start > Range.Start + Range.Length, 'analysis follows the actual move played from its base');
          if Slot + 1 < Count then
          begin
            NextRange := Presenter.MoveRanges[Slot + 1];
            Check(Hit.Start + Hit.Length <= NextRange.Start, 'analysis precedes the next actual move');
          end;
        end;
        Target := Presenter.HitTest(Hit.Start + 1, 0, Selection);
        Check((Target.Kind = nbPreview) and (Target.Variation.BasePly = Base) and
          (Target.Variation.MovesText = Hit.MovesText) and
          (Target.Variation.VariationPly = Hit.VariationPly), 'relocated prefix/move retains its exact preview target');
      end;
      Expected := 1 + Ord(Options.ShowEnginePVMove or Options.ShowEngineFullPV) +
        Ord(Options.ShowAnnotatorPVMove or Options.ShowAnnotatorFullPV);
      for Base := 0 to Count do
        Check(PrefixCounts[Base] = Expected, 'each enabled line appears exactly once, including root and tip');
      Check(GameTreeToPdnText(Tree) = Before, 'display reordering cannot change exported node data');
    end;
  finally Board.Free; Presenter.Free; Tree.Free; end;
end;
var Count: Integer;
begin
  for Count := 0 to 3 do
  begin CheckFixture(False, Count); CheckFixture(True, Count); end;
  Writeln('Analysis notation order checks passed');
end.
