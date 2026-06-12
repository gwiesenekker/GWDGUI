program game_tree_pdn_filter_check;

{$mode objfpc}{$H+}

uses
  SysUtils, uGameTree, uGameTreePdn;

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
      'annotator move and PV should be shown');

    Options.ShowEngineScore := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, 'E: 0.12', 'engine score toggle should hide score');
    CheckContains(Text, 'E PV: 16-21 37-32',
      'engine score toggle should not hide PV');
    Options.ShowEngineScore := True;

    Options.ShowEnginePV := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckContains(Text, 'E: 0.12', 'engine PV toggle should not hide score');
    CheckNotContains(Text, 'E PV:', 'engine PV toggle should hide PV');
    Options.ShowEnginePV := True;

    Options.ShowClocks := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, 'clk:', 'clock toggle should hide clocks');
    Options.ShowClocks := True;

    Options.ShowAnnotatorScore := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, 'A:', 'annotator score toggle should hide scores');
    CheckContains(Text, '(1.34-30 20-25)',
      'annotator score toggle should keep annotator PV moves');
    Options.ShowAnnotatorScore := True;

    Options.ShowAnnotatorPV := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckContains(Text, '(1.34-30 {A: 0.50})',
      'annotator PV toggle should keep only the first annotator move');
    CheckNotContains(Text, '20-25)', 'annotator PV toggle should hide PV tail');
    Options.ShowAnnotatorPV := True;

    Options.ShowAnnotatorMove := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, '(1.34-30',
      'annotator move toggle should hide annotator alternative');
    Options.ShowAnnotatorMove := True;

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

begin
  CheckPdnDisplayFilters;
  Writeln('OK');
end.
