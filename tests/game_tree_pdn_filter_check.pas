program game_tree_pdn_filter_check;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, uGameTree, uGameTreeBuilder, uGameTreePdn;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    Writeln('FAIL: ', AMessage);
    Halt(1);
  end;
end;

function RenderWithOptions(AGameTree: TGameTree;
  const AOptions: TGameTreePdnRenderOptions): string;
var
  RenderResult: TGameTreePdnRenderResult;
begin
  RenderGameTreeMovesToPdn(AGameTree, AOptions, RenderResult);
  Result := RenderResult.Text;
end;

procedure CheckContains(const AText, ANeedle, AMessage: string);
begin
  Check(Pos(ANeedle, AText) > 0, AMessage + '; text="' + AText + '"');
end;

procedure CheckNotContains(const AText, ANeedle, AMessage: string);
begin
  Check(Pos(ANeedle, AText) = 0, AMessage + '; text="' + AText + '"');
end;

procedure CheckPdnDisplayFilters;
var
  GameTree: TGameTree;
  Options: TGameTreePdnRenderOptions;
  Text: string;
begin
  GameTree := TGameTree.Create;
  try
    GameTree.BeginRebuild('test', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    GameTree.RecordMainlineMove(1, '32-28');
    GameTree.RecordMainlineMove(2, '16-21');
    GameTree.RecordEnginePV(1, '0.12', '16-21 37-32');
    GameTree.RecordAnnotatorPV(0, '0.50', '34-30 20-25');
    GameTree.RecordAnnotatorPV(1, '0.11', '16-21 37-32');
    GameTree.RecordClockState(1, 299.0, 300.0, 1.0, 0.0);

    Options := DefaultGameTreePdnRenderOptions;
    Text := RenderWithOptions(GameTree, Options);
    CheckContains(Text, 'E: 0.12', 'engine score should be shown');
    CheckContains(Text, 'E PV: 16-21 37-32', 'engine PV should be shown');
    CheckContains(Text, 'A: 0.11', 'annotator score should be shown');
    CheckContains(Text, 'clk:', 'clocks should be shown');
    CheckContains(Text, '(1.34-30 {A: 0.50} 20-25)',
      'PV move and full PV should be shown');

    Options.ShowEngineScore := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, 'E: 0.12', 'engine score toggle should hide score');
    CheckContains(Text, 'E PV: 16-21 37-32',
      'engine score toggle should not hide PV');
    Options.ShowEngineScore := True;

    Options.ShowFullPV := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckContains(Text, 'E: 0.12', 'full PV toggle should not hide score');
    CheckNotContains(Text, 'E PV:', 'full PV toggle should hide engine PV');
    CheckNotContains(Text, 'A PV:', 'full PV toggle should hide annotator PV');
    Options.ShowFullPV := True;

    Options.ShowClocks := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, 'clk:', 'clock toggle should hide clocks');
    Options.ShowClocks := True;

    Options.ShowAnnotatorScore := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, 'A:', 'annotator score toggle should hide scores');
    CheckContains(Text, '(1.34-30 20-25)',
      'annotator score toggle should keep PV moves');
    Options.ShowAnnotatorScore := True;

    Options.ShowFullPV := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckContains(Text, '(1.34-30 {A: 0.50})',
      'full PV toggle should keep only the first PV move');
    CheckNotContains(Text, '20-25)', 'full PV toggle should hide PV tail');
    Options.ShowFullPV := True;

    Options.ShowPVMove := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, '(1.34-30',
      'PV move toggle should hide PV move alternative');
    Options.ShowPVMove := True;

    Options.HideAnnotations := True;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, 'E:', 'hide annotations should hide engine score');
    CheckNotContains(Text, 'E PV:', 'hide annotations should hide engine PV');
    CheckNotContains(Text, 'A:', 'hide annotations should hide annotator scores');
    CheckNotContains(Text, 'clk:', 'hide annotations should hide clocks');
    CheckContains(Text, '(1.34-30 20-25)',
      'hide annotations should not hide annotator variation moves');
  finally
    GameTree.Free;
  end;
end;

procedure CheckSamePlyVariationsDoNotOverwrite;
var
  GameTree: TGameTree;
  Moves: TStringList;
  Options: TGameTreePdnRenderOptions;
  Text: string;
  VariationIndex: Integer;
begin
  GameTree := TGameTree.Create;
  Moves := TStringList.Create;
  try
    GameTree.BeginRebuild('variations', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    GameTree.RecordMainlineMove(1, '32-28');
    GameTree.RecordMainlineMove(2, '16-21');

    VariationIndex := GameTree.StoreVariationLine(1, 1, '18-23',
      'annotator=0.10');
    TextToMoveList('18-23', Moves);
    RecordGameTreeVariationLine(GameTree,
      GameTreeVariationLineInput(GameTree.VariationLine[VariationIndex],
      VariationIndex, Moves, nil));

    VariationIndex := GameTree.StoreVariationLine(1, 1, '20-24',
      'annotator=0.20');
    TextToMoveList('20-24', Moves);
    RecordGameTreeVariationLine(GameTree,
      GameTreeVariationLineInput(GameTree.VariationLine[VariationIndex],
      VariationIndex, Moves, nil));

    Check(GameTree.VariationLineCount = 2,
      'same-ply variations should be stored as separate lines');

    Options := DefaultGameTreePdnRenderOptions;
    Text := RenderWithOptions(GameTree, Options);
    CheckContains(Text, '(1...18-23 {A: 0.10})',
      'first same-ply variation should be rendered');
    CheckContains(Text, '(1...20-24 {A: 0.20})',
      'second same-ply variation should be rendered');
  finally
    Moves.Free;
    GameTree.Free;
  end;
end;

begin
  CheckPdnDisplayFilters;
  CheckSamePlyVariationsDoNotOverwrite;
  Writeln('OK');
end.
