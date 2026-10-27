unit uDisplayedPosition;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, uGamePosition, uGameTree, uGameTreeCursor;
type
  TDisplayReplayCacheEntry = record
    TreeId, NodeId, Revision: Int64;
    Position: TGamePosition; // owned copy
  end;
  // Owns one persistent cursor and temporary PV/replay state, never the tree.
  // Callers supply the actor revision and bracket one UI refresh with Begin/End.
  TDisplayedPosition = class
  private
    FCursor: TGameTreeCursor;
    FPreviewPly: Integer;
    FPreviewMoves: string;
    FRefreshDepth, FReplayBuildCount: Integer;
    FReplayCache: array of TDisplayReplayCacheEntry;
    procedure ClearReplayCache;
  public
    constructor Create;
    destructor Destroy; override;
    procedure ClearPreview;
    function SelectPreview(ABasePly, AVariationPly: Integer;
      const AMovesText: string; AGameTree: TGameTree): Boolean;
    function PreviewMoveCount: Integer;
    function ResolveNode(AGameTree: TGameTree; AActive: Boolean): TGameTreePlyNode;
    function BrowseBasePly(ATree: TGameTree): Integer;
    function BrowsingBranch(ATree: TGameTree): Boolean;
    function MovesText(AGameTree: TGameTree; AActive: Boolean): string;
    procedure BeginRefresh(ATree: TGameTree);
    procedure EndRefresh;
    // APosition must belong to AGameTree's variant; it is unchanged on failure.
    function TryBuildNodePosition(AGameTree: TGameTree; ANode: TGameTreePlyNode;
      Revision: Int64; APosition: TGamePosition): Boolean;
    function TryBuildPosition(AGameTree: TGameTree; AActive: Boolean;
      ARevision: Int64; APosition: TGamePosition): Boolean; overload;
    // Also returns the move that led to the displayed position: the last
    // preview move, else the displayed node's move ('' at the tree start).
    function TryBuildPosition(AGameTree: TGameTree; AActive: Boolean;
      ARevision: Int64; APosition: TGamePosition; out ALastMove: string): Boolean; overload;
    property Cursor: TGameTreeCursor read FCursor;
    property PreviewPly: Integer read FPreviewPly;
    property PreviewMoves: string read FPreviewMoves;
    property ReplayBuildCount: Integer read FReplayBuildCount;
  end;
implementation
uses uGameTreeBuilder;
constructor TDisplayedPosition.Create;
begin
  inherited Create;
  FCursor := TGameTreeCursor.Create;
end;
destructor TDisplayedPosition.Destroy;
begin
  ClearReplayCache;
  FCursor.Free;
  inherited Destroy;
end;
procedure TDisplayedPosition.ClearReplayCache;
var I: Integer;
begin
  for I := 0 to High(FReplayCache) do FReplayCache[I].Position.Free;
  FReplayCache := nil;
end;
procedure TDisplayedPosition.BeginRefresh(ATree: TGameTree);
begin
  if FRefreshDepth = 0 then FReplayBuildCount := 0;
  Inc(FRefreshDepth);
  // Resolve a missing selection by identity before deriving indexes or rendering.
  FCursor.Resolve(ATree);
end;
procedure TDisplayedPosition.EndRefresh;
begin
  Dec(FRefreshDepth);
  if FRefreshDepth = 0 then ClearReplayCache;
end;
procedure TDisplayedPosition.ClearPreview;
begin
  FPreviewPly := 0;
  FPreviewMoves := '';
end;
function TDisplayedPosition.SelectPreview(ABasePly,
  AVariationPly: Integer; const AMovesText: string; AGameTree: TGameTree): Boolean;
var
  LMoveCount: Integer;
  LMoves: TStringList;
begin
  Result := False;
  if (AGameTree = nil) or (ABasePly < 0) or (Trim(AMovesText) = '') then
    Exit;

  LMoves := TStringList.Create;
  try
    TextToMoveList(AMovesText, LMoves);
    LMoveCount := LMoves.Count;
  finally
    LMoves.Free;
  end;
  if AVariationPly < 0 then
    AVariationPly := 0
  else if AVariationPly > LMoveCount then
    AVariationPly := LMoveCount;

  if ABasePly = 0 then
    FCursor.Select(AGameTree, AGameTree.Root)
  else
    FCursor.Select(AGameTree, AGameTree.MainlineNode[ABasePly]);
  FPreviewPly := AVariationPly;
  FPreviewMoves := Trim(AMovesText);
  Result := True;
end;
function TDisplayedPosition.ResolveNode(
  AGameTree: TGameTree; AActive: Boolean): TGameTreePlyNode;
begin
  if not AActive then
  begin
    if AGameTree = nil then Exit(nil);
    if AGameTree.MainlineCount = 0 then Exit(AGameTree.Root);
    Exit(AGameTree.MainlineNode[AGameTree.MainlineCount]);
  end;
  Result := FCursor.Resolve(AGameTree);
end;
function TDisplayedPosition.BrowseBasePly(ATree: TGameTree): Integer;
var Node: TGameTreePlyNode;
begin
  Node := FCursor.Resolve(ATree);
  if FCursor.Following or (Node = nil) then Exit(-1);
  Result := Node.PlyNumber;
end;
function TDisplayedPosition.BrowsingBranch(ATree: TGameTree): Boolean;
var Tree: TGameTree; Node: TGameTreePlyNode;
begin
  Tree := ATree;
  Node := FCursor.Resolve(Tree);
  Result := (Tree <> nil) and (Node <> nil) and not FCursor.Following and
    not Tree.IsMainlineNode(Node);
end;
function TDisplayedPosition.PreviewMoveCount: Integer;
var Moves: TStringList;
begin
  Moves := TStringList.Create;
  try
    TextToMoveList(FPreviewMoves, Moves);
    Result := Moves.Count;
  finally Moves.Free; end;
end;
function TDisplayedPosition.MovesText(AGameTree: TGameTree; AActive: Boolean): string;
var
  I: Integer;
  Moves, Preview: TStringList;
begin
  Result := '';
  if AGameTree = nil then
    Exit;
  Moves := TStringList.Create;
  Preview := TStringList.Create;
  try
    if not AGameTree.CopyNodeMovesTo(ResolveNode(AGameTree, AActive),
      Moves) then
      Exit;
    if (Trim(FPreviewMoves) <> '') and (FPreviewPly > 0) then
    begin
      TextToMoveList(FPreviewMoves, Preview);
      if FPreviewPly > Preview.Count then
        Exit;
      for I := 0 to FPreviewPly - 1 do
        Moves.Add(Preview[I]);
    end;
    for I := 0 to Moves.Count - 1 do
    begin
      if Result <> '' then
        Result += ' ';
      Result += Moves[I];
    end;
  finally
    Preview.Free;
    Moves.Free;
  end;
end;
function TDisplayedPosition.TryBuildNodePosition(AGameTree: TGameTree;
  ANode: TGameTreePlyNode; Revision: Int64; APosition: TGamePosition): Boolean;
var I: Integer;
begin
  Result := False;
  if (AGameTree = nil) or (ANode = nil) or (APosition = nil) then Exit;
  if FRefreshDepth > 0 then
    for I := 0 to High(FReplayCache) do
      if (FReplayCache[I].TreeId = AGameTree.GameTreeId) and
        (FReplayCache[I].NodeId = ANode.NodeId) and
        (FReplayCache[I].Revision = Revision) then
      begin APosition.AssignFrom(FReplayCache[I].Position); Exit(True); end;
  if FRefreshDepth > 0 then Inc(FReplayBuildCount);
  Result := AGameTree.TryBuildPositionAtNode(ANode, APosition);
  if Result and (FRefreshDepth > 0) then
  begin
    I := Length(FReplayCache);
    SetLength(FReplayCache, I + 1);
    FReplayCache[I].TreeId := AGameTree.GameTreeId;
    FReplayCache[I].NodeId := ANode.NodeId;
    FReplayCache[I].Revision := Revision;
    FReplayCache[I].Position := APosition.Clone;
  end;
end;
function TDisplayedPosition.TryBuildPosition(AGameTree: TGameTree; AActive: Boolean;
  ARevision: Int64; APosition: TGamePosition): Boolean;
var
  LLastMove: string;
begin
  Result := TryBuildPosition(AGameTree, AActive, ARevision, APosition, LLastMove);
end;
function TDisplayedPosition.TryBuildPosition(AGameTree: TGameTree; AActive: Boolean;
  ARevision: Int64; APosition: TGamePosition; out ALastMove: string): Boolean;
var
  I: Integer;
  LNode: TGameTreePlyNode;
  LMoves: TStringList;
  Candidate: TGamePosition;
begin
  Result := False;
  ALastMove := '';
  if (AGameTree = nil) or (APosition = nil) then
    Exit;
  LNode := ResolveNode(AGameTree, AActive);
  LMoves := TStringList.Create;
  Candidate := AGameTree.Variant.CreatePosition;
  try
    if not TryBuildNodePosition(AGameTree, LNode, ARevision, Candidate) then
      Exit;
    ALastMove := LNode.MoveText;
    try
      if (Trim(FPreviewMoves) <> '') and (FPreviewPly > 0) then
      begin
        TextToMoveList(FPreviewMoves, LMoves);
        if FPreviewPly > LMoves.Count then
          Exit;
        // Preview moves come from engines and PV text: validate each one.
        for I := 0 to FPreviewPly - 1 do
          ALastMove := Candidate.PlayMoveText(LMoves[I]);
      end;
      APosition.AssignFrom(Candidate);
      Result := True;
    except
      Result := False;
    end;
  finally
    if not Result then
      ALastMove := '';
    Candidate.Free;
    LMoves.Free;
  end;
end;
end.
