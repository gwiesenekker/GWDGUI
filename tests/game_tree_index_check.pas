program game_tree_index_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uGameTree, uDraughtsPosition;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then raise Exception.Create(Text); end;
var Tree: TGameTree; Seen, Live: TStringList;
  Branch, Child: TGameTreePlyNode; I: Integer;
procedure CheckIndex;
  procedure Walk(Node: TGameTreePlyNode);
  var J: Integer; Id: string;
  begin
    Id := IntToStr(Node.NodeId);
    Check(Live.IndexOf(Id) < 0, 'node identity unique in current tree'); Live.Add(Id);
    if Seen.IndexOf(Id) < 0 then Seen.Add(Id);
    Check(Tree.FindNodeById(Node.NodeId) = Node, 'index resolves exact live object');
    for J := 0 to Node.ChildCount - 1 do Walk(Node.Children[J]);
  end;
var J: Integer;
begin
  Live.Clear; Walk(Tree.Root);
  for J := 0 to Seen.Count - 1 do
    if Live.IndexOf(Seen[J]) < 0 then
      Check(Tree.FindNodeById(StrToInt64(Seen[J])) = nil, 'removed/rebuilt nodes leave no dangling index entry');
  Check(Tree.FindNodeById(0) = nil, 'zero ID absent');
  Check(Tree.FindNodeById(-1) = nil, 'negative ID absent');
  Check(Tree.FindNodeById(High(Int64)) = nil, 'unknown ID absent');
end;
procedure CheckLargeRemovalBatches;
const BranchCount = 40; Depth = 500;
var LocalTree: TGameTree; Node, Added: TGameTreePlyNode;
  Removed: array of Int64; Trimmed: array[6..200] of Int64;
  I, J, K: Integer; RootId, TipId: Int64; Before: QWord;
begin
  LocalTree := TGameTree.Create;
  try
    RootId := LocalTree.Root.NodeId;
    LocalTree.RecordMainlineMove(1, '32-28'); LocalTree.RecordMainlineMove(2, '18-23');
    TipId := LocalTree.MainlineNode[2].NodeId;
    SetLength(Removed, BranchCount * Depth); K := 0;
    // Synthetic internal nodes exercise map lifecycle independently of rules.
    for I := 1 to BranchCount do
    begin
      Node := LocalTree.RecordBranchMove(LocalTree.Root, '1-' + IntToStr(I));
      Removed[K] := Node.NodeId; Inc(K);
      for J := 2 to Depth do
      begin Node := LocalTree.RecordBranchMove(Node, '6-11'); Removed[K] := Node.NodeId; Inc(K); end;
    end;
    Before := LocalTree.NodeIndexRebuildCount;
    LocalTree.ClearBranches;
    Check(LocalTree.NodeIndexRebuildCount = Before, 'bulk clearing does not rebuild for every removed node');
    Added := LocalTree.RecordBranchMove(LocalTree.Root, '2-7');
    Check(LocalTree.FindNodeById(Added.NodeId) = Added, 'nodes added during invalidation enter rebuilt index');
    Check(LocalTree.FindNodeById(TipId) = LocalTree.MainlineNode[2], 'clearing retains official moves');
    for I := 0 to High(Removed) do
      Check(LocalTree.FindNodeById(Removed[I]) = nil, 'large removed subtree leaves no stale IDs');
    Check(LocalTree.NodeIndexRebuildCount = Before + 1, 'one lazy rebuild covers all bulk-clear lookups');
    LocalTree.RemoveBranch(Added);
    Check(LocalTree.FindNodeById(RootId) = LocalTree.Root, 'single branch removal rebuilds surviving index');
    for I := 3 to 200 do
    begin
      LocalTree.RecordMainlineMove(I, '1-6');
      if I >= 6 then Trimmed[I] := LocalTree.MainlineNode[I].NodeId;
    end;
    Before := LocalTree.NodeIndexRebuildCount;
    LocalTree.TrimMainlineToCount(5);
    Check(LocalTree.NodeIndexRebuildCount = Before, 'trimming many mainline nodes defers one rebuild');
    for I := 6 to 200 do Check(LocalTree.FindNodeById(Trimmed[I]) = nil, 'trimmed IDs absent');
    Check(LocalTree.NodeIndexRebuildCount = Before + 1, 'one rebuild covers the entire takeback');
    Check(LocalTree.FindNodeById(TipId) = LocalTree.MainlineNode[2], 'takeback keeps surviving node identity');
    LocalTree.Clear;
    Check((LocalTree.Root.NodeId <> RootId) and (LocalTree.FindNodeById(RootId) = nil), 'clear never reuses old node IDs');
  finally LocalTree.Free; end;
end;

begin
  CheckLargeRemovalBatches;
  Tree := TGameTree.Create; Seen := TStringList.Create; Live := TStringList.Create;
  try
    CheckIndex;
    for I := 1 to 25 do
    begin
      Tree.RecordMainlineMove(1, '32-28'); Tree.RecordMainlineMove(2, '18-23');
      Tree.RecordMainlineMove(3, '37-32'); CheckIndex;
      Branch := Tree.RecordBranchMove(Tree.MainlineNode[1], '20-24');
      Child := Tree.RecordBranchMove(Branch, '38-32');
      Tree.RecordBranchMove(Child, '14-20');
      Child := Tree.RecordBranchMove(Child, '18-22'); CheckIndex;
      Tree.RemoveBranch(Child); CheckIndex;
      Tree.TrimMainlineToCount(1); CheckIndex;
      Tree.ClearBranches; CheckIndex;
      Tree.RecordMainlineMove(1, '31-26'); CheckIndex;
      Tree.BeginRebuild(IntToStr(I), '?', 'White', 'Black', '*', 'W:W31-50:B1-20');
      CheckIndex;
    end;
    Tree.Clear; CheckIndex;
  finally Live.Free; Seen.Free; Tree.Free; end;
  Writeln('Game tree index checks passed');
end.
