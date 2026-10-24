unit uGameTreeCursor;
{$mode objfpc}{$H+}
interface
uses uGameTree;
type
  TGameTreeCursor = class
  private
    FTreeId, FNodeId: Int64;
    FAncestors, FForward: array of Int64;
    procedure Remember(ATree: TGameTree; ANode: TGameTreePlyNode);
    function GetFollowing: Boolean;
  public
    procedure Follow;
    procedure Select(ATree: TGameTree; ANode: TGameTreePlyNode);
    procedure SelectBefore(ATree: TGameTree; AChild: TGameTreePlyNode);
    function Resolve(ATree: TGameTree): TGameTreePlyNode;
    procedure StepLeft(ATree: TGameTree);
    procedure StepRight(ATree: TGameTree);
    property Following: Boolean read GetFollowing;
    property NodeId: Int64 read FNodeId;
  end;
implementation

function TGameTreeCursor.GetFollowing: Boolean;
begin
  Result := FNodeId = 0;
end;

procedure TGameTreeCursor.Follow;
begin
  FTreeId := 0;
  FNodeId := 0;
  SetLength(FAncestors, 0);
  SetLength(FForward, 0);
end;

procedure TGameTreeCursor.Remember(ATree: TGameTree; ANode: TGameTreePlyNode);
var
  Parent: TGameTreePlyNode;
  N: Integer;
begin
  FTreeId := ATree.GameTreeId;
  FNodeId := ANode.NodeId;
  SetLength(FAncestors, 0);
  Parent := ANode.Parent;
  while Parent <> nil do
  begin
    N := Length(FAncestors);
    SetLength(FAncestors, N + 1);
    FAncestors[N] := Parent.NodeId;
    Parent := Parent.Parent;
  end;
end;

procedure TGameTreeCursor.Select(ATree: TGameTree; ANode: TGameTreePlyNode);
begin
  if (ATree = nil) or (ANode = nil) then Exit;
  if ATree.FindNodeById(ANode.NodeId) <> ANode then Exit;
  Remember(ATree, ANode);
  SetLength(FForward, 0);
end;

procedure TGameTreeCursor.SelectBefore(ATree: TGameTree; AChild: TGameTreePlyNode);
begin
  if (ATree = nil) or (AChild = nil) or (AChild.Parent = nil) then Exit;
  if ATree.FindNodeById(AChild.NodeId) <> AChild then Exit;
  Select(ATree, AChild.Parent);
  SetLength(FForward, 1);
  FForward[0] := AChild.NodeId;
end;

function TGameTreeCursor.Resolve(ATree: TGameTree): TGameTreePlyNode;
var
  I: Integer;
begin
  Result := nil;
  if ATree = nil then Exit;
  if not Following and (FTreeId <> ATree.GameTreeId) then Follow;
  if not Following then
  begin
    Result := ATree.FindNodeById(FNodeId);
    if Result <> nil then Exit;
    // A removed branch falls back to its nearest surviving ancestor, never to
    // a different move occupying the old ply or compatibility-line index.
    for I := 0 to High(FAncestors) do
    begin
      Result := ATree.FindNodeById(FAncestors[I]);
      if Result <> nil then
      begin
        Remember(ATree, Result);
        SetLength(FForward, 0);
        Exit;
      end;
    end;
    Follow;
  end;
  if ATree.MainlineCount = 0 then Result := ATree.Root
  else Result := ATree.MainlineNode[ATree.MainlineCount];
end;

procedure TGameTreeCursor.StepLeft(ATree: TGameTree);
var
  Node: TGameTreePlyNode;
  N: Integer;
begin
  if ATree = nil then Exit;
  Node := Resolve(ATree);
  if Following then
  begin
    Select(ATree, Node);
    Exit;
  end;
  if Node = nil then Exit;
  if Node.Parent = nil then
  begin
    if ATree.MainlineCount > 0 then
      Select(ATree, ATree.MainlineNode[ATree.MainlineCount]);
    Exit;
  end;
  N := Length(FForward);
  SetLength(FForward, N + 1);
  FForward[N] := Node.NodeId;
  Remember(ATree, Node.Parent);
end;

procedure TGameTreeCursor.StepRight(ATree: TGameTree);
var
  Node, Next: TGameTreePlyNode;
  N: Integer;
begin
  if ATree = nil then Exit;
  Node := Resolve(ATree);
  if Following then
  begin
    Select(ATree, ATree.Root);
    Exit;
  end;
  if Node = nil then Exit;
  Next := nil;
  N := Length(FForward);
  if N > 0 then
  begin
    Next := ATree.FindNodeById(FForward[N - 1]);
    SetLength(FForward, N - 1);
    if (Next = nil) or (Next.Parent <> Node) then
    begin
      Next := nil;
      SetLength(FForward, 0);
    end;
  end;
  if Next = nil then
  begin
    if (Node = ATree.Root) or (ATree.MainlineNode[Node.PlyNumber] = Node) then
      Next := ATree.MainlineNode[Node.PlyNumber + 1];
    if (Next = nil) and (Node.ChildCount > 0) then Next := Node.Children[0];
  end;
  if Next <> nil then Remember(ATree, Next)
  else if (Node = ATree.MainlineNode[ATree.MainlineCount]) then
    Select(ATree, ATree.Root);
end;
end.
