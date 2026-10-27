program displayed_position_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uDraughtsBoard, uGameTree, uGameTreeActor,
  uDisplayedPosition, uTreeTestUtils, uGamePosition, uDraughtsPosition;
procedure Check(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;
procedure Execute(Actor: TGameTreeActor; Command: TGameTreeCommand);
begin
  try
    Actor.ExecuteCommand(Command);
    Check(Command.Accepted, Command.ErrorText);
  finally Command.Free; end;
end;
var
  Actor, Other: TGameTreeActor;
  Display: TDisplayedPosition;
  Board: TGamePosition;
  Oracle: TDraughtsBoard;
  Tree: TGameTree;
  Node: TGameTreePlyNode;
  Selected: Int64;
  Key: string;
begin
  Actor := TGameTreeActor.Create;
  Other := TGameTreeActor.Create;
  Display := TDisplayedPosition.Create;
  Board := DraughtsVariant.CreatePosition;
  Oracle := TDraughtsBoard.Create;
  try
    Tree := Actor.GameTree;
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('32-28', gmsHuman));
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('18-23', gmsHuman));
    Execute(Actor, ImportBranch(Actor, 1, '20-24 38-32 14-20', '', gmsHuman));
    Execute(Actor, ImportBranch(Actor, 1, '20-24 38-32 18-22', '', gmsHuman));
    Check(Display.ResolveNode(Tree, True) = Tree.MainlineNode[2], 'follow uses tip');
    Check(Display.BrowseBasePly(Tree) = -1, 'follow has no historical ply');
    Node := Tree.FindBranchNode(1, 3);
    Selected := Node.NodeId;
    Display.Cursor.Select(Tree, Node);
    Check(Display.BrowsingBranch(Tree), 'nested branch is recognized');
    Check(Display.BrowseBasePly(Tree) = Node.PlyNumber, 'browse ply derives from identity');
    Check(Display.MovesText(Tree, True) = '32-28 20-24 38-32 18-22',
      'nested path includes chosen sibling, not mainline at same ply');
    Oracle.PlayMove('32-28', True, True);
    Oracle.PlayMove('20-24', True, True);
    Oracle.PlayMove('38-32', True, True);
    Oracle.PlayMove('18-22', True, True);
    Check(Display.TryBuildPosition(Tree, True, Actor.Revision, Board), 'nested replay');
    Check(Board.PositionKey = Oracle.PositionKey, 'nested replay matches legal path');
    Check(Display.ResolveNode(Other.GameTree, False) = Other.GameTree.Root,
      'nonselected game projects its tip');
    Check(Display.Cursor.NodeId = Selected, 'nonselected projection preserves selection');
    Check(Display.ResolveNode(nil, False) = nil, 'missing nonselected tree');
    Check(Display.SelectPreview(1, 99, ' 20-24 38-32 ', Tree), 'select preview');
    Check((Display.PreviewPly = 2) and (Display.PreviewMoveCount = 2), 'preview clamps to length');
    Check(Display.MovesText(Tree, True) = '32-28 20-24 38-32', 'preview extends selected base');
    Oracle.LoadFromFEN(Tree.StartingFEN);
    Oracle.PlayMove('32-28', True, True);
    Oracle.PlayMove('20-24', True, True);
    Oracle.PlayMove('38-32', True, True);
    Check(Display.TryBuildPosition(Tree, True, Actor.Revision, Board), 'legal preview replay');
    Check(Board.PositionKey = Oracle.PositionKey, 'preview replay matches path');
    Check(Tree.MainlineCount = 2, 'preview never modifies tree');
    Key := Board.PositionKey;
    Check(Display.SelectPreview(1, 2, '20-24 1-50', Tree), 'select invalid preview for validation');
    Check(not Display.TryBuildPosition(Tree, True, Actor.Revision, Board), 'invalid later preview move fails');
    Check(Board.PositionKey = Key, 'failed preview leaves caller board intact');
    Check(Display.SelectPreview(1, -3, '20-24', Tree) and (Display.PreviewPly = 0),
      'negative preview clamps to base');
    Check(not Display.SelectPreview(-1, 1, '20-24', Tree), 'invalid base request ignored');
    Display.ClearPreview;
    Check((Display.PreviewMoves = '') and (Display.PreviewPly = 0), 'clear temporary preview');
    Display.Cursor.Select(Tree, Node);
    Display.BeginRefresh(Tree);
    try
      Check(Display.TryBuildPosition(Tree, True, Actor.Revision, Board), 'first cached replay');
      Key := Board.PositionKey;
      Board.LoadFromFEN('W:W32:B1');
      Display.BeginRefresh(Tree);
      try
        Check(Display.TryBuildPosition(Tree, True, Actor.Revision, Board), 'nested refresh replay');
        Check((Board.PositionKey = Key) and (Display.ReplayBuildCount = 1),
          'nested refresh reuses an owned board copy');
      finally Display.EndRefresh; end;
      Check(Display.TryBuildPosition(Tree, True, Actor.Revision, Board) and
        (Display.ReplayBuildCount = 1), 'nested end retains outer cache');
      Execute(Actor, Actor.CreateAppendMainlineMoveCommand('37-32', gmsHuman));
      Check(Display.TryBuildPosition(Tree, True, Actor.Revision, Board) and
        (Display.ReplayBuildCount = 2), 'actor revision invalidates cache even for same node');
      Check(Display.Cursor.NodeId = Selected, 'new mainline move preserves historical selection');
    finally Display.EndRefresh; end;
    Display.BeginRefresh(Tree);
    try
      Check(Display.TryBuildPosition(Tree, True, Actor.Revision, Board) and
        (Display.ReplayBuildCount = 1), 'new refresh rebuilds after cache disposal');
    finally Display.EndRefresh; end;
    Execute(Actor, Actor.CreateClearBranchesCommand);
    Display.BeginRefresh(Tree);
    try
      Check(Display.ResolveNode(Tree, True) = Tree.MainlineNode[1],
        'removed branch resolves surviving ancestor before display');
      Check(not Display.BrowsingBranch(Tree), 'fallback is mainline');
      Check(Display.TryBuildPosition(Tree, True, Actor.Revision, Board), 'fallback replays');
      Key := Board.PositionKey;
      Check(not Display.TryBuildNodePosition(Tree, Other.GameTree.Root, Actor.Revision, Board),
        'foreign node rejected');
      Check(Board.PositionKey = Key, 'foreign node failure preserves board');
    finally Display.EndRefresh; end;
    Display.Cursor.Follow;
    Check(Display.ResolveNode(Tree, True) = Tree.MainlineNode[3], 'resume following current tip');
  finally
    Oracle.Free; Board.Free; Display.Free; Other.Free; Actor.Free;
  end;
  Writeln('Displayed position checks passed');
end.
