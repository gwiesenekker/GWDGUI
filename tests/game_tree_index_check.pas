program game_tree_index_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uGameTree;
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
begin
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
