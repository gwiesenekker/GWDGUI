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

procedure CheckGameTreeIds;
var
  FirstRootId: Int64;
  GameTreeA: TGameTree;
  GameTreeB: TGameTree;
  Node: TGameTreePlyNode;
  VariationIndex: Integer;
  VariationNode: TGameTreePlyNode;
begin
  GameTreeA := TGameTree.Create;
  GameTreeB := TGameTree.Create;
  try
    Check(GameTreeA.GameTreeId > 0, 'game tree id should be positive');
    Check(GameTreeB.GameTreeId > 0, 'second game tree id should be positive');
    Check(GameTreeA.GameTreeId <> GameTreeB.GameTreeId,
      'game tree ids should be unique');
    Check(GameTreeA.Root.NodeId > 0, 'root node id should be positive');
    Check(GameTreeA.FindNodeById(GameTreeA.Root.NodeId) = GameTreeA.Root,
      'root node id should resolve to root');

    Node := GameTreeA.RecordMainlineMove(1, '32-28');
    Check(Node <> nil, 'mainline node should be created');
    Check(Node.NodeId <> GameTreeA.Root.NodeId,
      'mainline node id should differ from root id');
    Check(GameTreeA.FindNodeById(Node.NodeId) = Node,
      'mainline node id should resolve to node');

    VariationIndex := GameTreeA.StoreVariationLine(2, 1,
      '16-21 37-32', '');
    Check(VariationIndex >= 0, 'variation line should be stored');
    VariationNode := GameTreeA.RecordVariationMove(Node, 1, 2,
      VariationIndex, 1, '16-21');
    Check(VariationNode <> nil, 'variation node should be created');
    Check(GameTreeA.FindVariationNode(VariationIndex, 1) = VariationNode,
      'variation node should resolve by variation index and ply');
    Check(GameTreeA.FindNodeById(VariationNode.NodeId) = VariationNode,
      'variation node id should resolve to node');

    FirstRootId := GameTreeA.Root.NodeId;
    GameTreeA.BeginRebuild('new', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    Check(GameTreeA.Root.NodeId <> FirstRootId,
      'node ids should not be reused after different-tree rebuild');
    Check(GameTreeA.FindNodeById(FirstRootId) = nil,
      'old node id should not resolve after different-tree rebuild');
  finally
    GameTreeB.Free;
    GameTreeA.Free;
  end;
end;

procedure CheckStableRebuildNodeIds;
var
  FirstId: Int64;
  GameTree: TGameTree;
  RootId: Int64;
  SecondId: Int64;
  VariationId: Int64;
  VariationIndex: Integer;
  VariationMoves: TStringList;
begin
  GameTree := TGameTree.Create;
  VariationMoves := TStringList.Create;
  try
    GameTree.BeginRebuild('stable', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    RootId := GameTree.Root.NodeId;
    FirstId := GameTree.RecordMainlineMove(1, '32-28').NodeId;
    SecondId := GameTree.RecordMainlineMove(2, '16-21').NodeId;

    GameTree.BeginRebuild('stable', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    GameTree.RecordMainlineMove(1, '32-28');
    GameTree.RecordMainlineMove(2, '16-21');
    GameTree.TrimMainlineToCount(2);

    Check(GameTree.Root.NodeId = RootId,
      'same-signature rebuild should preserve root node id');
    Check(GameTree.MainlineNode[1].NodeId = FirstId,
      'same move at ply 1 should preserve node id');
    Check(GameTree.MainlineNode[2].NodeId = SecondId,
      'same move at ply 2 should preserve node id');

    GameTree.BeginRebuild('stable', 'Event', 'White', 'Black', '*',
      'W:W31-50:B1-20');
    GameTree.RecordMainlineMove(1, '32-28');
    GameTree.RecordMainlineMove(2, '18-23');
    GameTree.TrimMainlineToCount(2);

    Check(GameTree.MainlineNode[1].NodeId = FirstId,
      'unchanged prefix should preserve node id after changed suffix');
    Check(GameTree.MainlineNode[2].NodeId <> SecondId,
      'changed move should receive a new node id');
    Check(GameTree.FindNodeById(SecondId) = nil,
      'old changed node id should no longer resolve');

    VariationIndex := GameTree.StoreVariationLine(1, 1, '20-24 34-29', '');
    TextToMoveList('20-24 34-29', VariationMoves);
    RecordGameTreeVariationLine(GameTree,
      GameTreeVariationLineInput(GameTree.VariationLine[VariationIndex],
      VariationIndex, VariationMoves, nil));
    VariationId := GameTree.FindVariationNode(VariationIndex, 1).NodeId;

    RecordGameTreeVariationLine(GameTree,
      GameTreeVariationLineInput(GameTree.VariationLine[VariationIndex],
      VariationIndex, VariationMoves, nil));
    Check(GameTree.FindVariationNode(VariationIndex, 1).NodeId = VariationId,
      'same variation move should preserve node id');
  finally
    VariationMoves.Free;
    GameTree.Free;
  end;
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
    CheckContains(Text, 'E PV: 16-21 37-32', 'engine full PV should be shown');
    CheckContains(Text, 'A: 0.11', 'annotator score should be shown');
    CheckContains(Text, 'clk:', 'clocks should be shown');
    CheckContains(Text, '(1.34-30 {A: 0.50} 20-25)',
      'annotator full PV should be shown');

    Options.ShowEngineScore := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, 'E: 0.12', 'engine score toggle should hide score');
    CheckContains(Text, 'E PV: 16-21 37-32',
      'engine score toggle should not hide engine full PV');
    Options.ShowEngineScore := True;

    Options.ShowEngineFullPV := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckContains(Text, 'E PV: 16-21',
      'engine full PV toggle should fall back to engine PV move');
    CheckNotContains(Text, 'E PV: 16-21 37-32',
      'engine full PV toggle should hide engine PV tail');
    Options.ShowEngineFullPV := True;

    Options.ShowEnginePVMove := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckContains(Text, 'E: 0.12', 'engine PV move toggle should not hide score');
    CheckContains(Text, 'E PV: 16-21 37-32',
      'engine PV move toggle should not hide engine full PV');
    CheckContains(Text, 'A PV:', 'engine PV move toggle should not hide annotator PV move');
    Options.ShowEnginePVMove := True;

    Options.ShowEngineFullPV := False;
    Options.ShowEnginePVMove := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, 'E PV:',
      'engine PV toggles should hide engine PV completely');
    Options.ShowEnginePVMove := True;
    Options.ShowEngineFullPV := True;

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

    Options.ShowAnnotatorFullPV := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckContains(Text, '(1.34-30 {A: 0.50})',
      'annotator full PV toggle should fall back to annotator PV move');
    CheckNotContains(Text, '20-25)',
      'annotator full PV toggle should hide annotator PV tail');
    Options.ShowAnnotatorFullPV := True;

    Options.ShowAnnotatorPVMove := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckContains(Text, '(1.34-30 {A: 0.50} 20-25)',
      'annotator PV move toggle should not hide annotator full PV variation');
    CheckContains(Text, 'A PV: 16-21 37-32',
      'annotator PV move toggle should not hide annotator full PV annotation');
    Options.ShowAnnotatorPVMove := True;

    Options.ShowAnnotatorFullPV := False;
    Options.ShowAnnotatorPVMove := False;
    Text := RenderWithOptions(GameTree, Options);
    CheckNotContains(Text, '(1.34-30',
      'annotator PV toggles should hide annotator PV variation');
    CheckNotContains(Text, 'A PV:',
      'annotator PV toggles should hide annotator PV annotation');
    Options.ShowAnnotatorPVMove := True;
    Options.ShowAnnotatorFullPV := True;

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
  CheckGameTreeIds;
  CheckStableRebuildNodeIds;
  CheckPdnDisplayFilters;
  CheckSamePlyVariationsDoNotOverwrite;
  Writeln('OK');
end.
