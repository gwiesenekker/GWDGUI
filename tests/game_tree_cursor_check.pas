program game_tree_cursor_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uGameTree, uGameTreeActor, uGameTreeBuilder,
  uGameTreeCursor;
procedure Check(Value: Boolean; const MessageText: string);
begin
  if not Value then raise Exception.Create(MessageText);
end;
procedure Execute(Actor: TGameTreeActor; Command: TGameTreeCommand);
begin
  try
    Actor.ExecuteCommand(Command);
    Check(Command.Accepted, Command.ErrorText);
  finally
    Command.Free;
  end;
end;
var
  Actor, Other: TGameTreeActor;
  Cursor: TGameTreeCursor;
  Tree: TGameTree;
  Moves: TStringList;
  Selected, Parent: Int64;
  Changed: Boolean;
begin
  Actor := TGameTreeActor.Create;
  Other := TGameTreeActor.Create;
  Cursor := TGameTreeCursor.Create;
  Moves := TStringList.Create;
  try
    Tree := Actor.GameTree;
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('32-28', gmsHuman));
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('18-23', gmsHuman));
    Cursor.Follow;
    Check(Cursor.Resolve(Tree) = Tree.MainlineNode[2], 'following resolves the live tip');
    Cursor.StepLeft(Tree);
    Execute(Actor, Actor.CreateAppendMainlineMoveCommand('37-32', gmsHuman));
    Check(Cursor.Resolve(Tree) = Tree.MainlineNode[2], 'selected node stays frozen as the game grows');
    Cursor.Follow;
    Check(Cursor.Resolve(Tree) = Tree.MainlineNode[3], 'follow resumes at the new tip');
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '20-24 38-32 14-20', '', gmsHuman));
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '20-24 38-32 18-22', '', gmsHuman));
    Selected := Tree.FindVariationNode(1, 3).NodeId;
    Parent := Tree.FindVariationNode(1, 2).NodeId;
    Cursor.Select(Tree, Tree.FindNodeById(Selected));
    Cursor.StepLeft(Tree);
    Check(Cursor.NodeId = Parent, 'Left follows actual nested parent');
    Cursor.StepRight(Tree);
    Check(Cursor.NodeId = Selected, 'Right restores the chosen sibling after Left');
    Cursor.SelectBefore(Tree, Tree.FindNodeById(Selected));
    Check(Cursor.NodeId = Parent, 'branch opening selects its actual parent');
    Cursor.StepRight(Tree);
    Check(Cursor.NodeId = Selected, 'branch opening retains the requested child');
    // Shortening the first compatibility path changes the shared node's address.
    Cursor.Select(Tree, Tree.FindNodeById(Parent));
    Tree.StoreVariationLineAtIndex(0, 2, 1, '20-24', '', Changed);
    TextToMoveList('20-24', Moves);
    RecordGameTreeVariationLine(Tree,
      GameTreeVariationLineInput(Tree.VariationLine[0], 0, Moves, nil));
    Check((Cursor.Resolve(Tree).NodeId = Parent) and
      (Tree.FindVariationNode(1, 2).NodeId = Parent),
      'compatibility-path changes must not retarget the cursor');
    Execute(Actor, Actor.CreateClearStoredVariationsCommand);
    Check(Cursor.Resolve(Tree) = Tree.MainlineNode[1],
      'removed branches fall back to their nearest surviving ancestor');
    Cursor.Select(Tree, Tree.MainlineNode[3]);
    Execute(Actor, Actor.CreateAddMainlineMoveCommand(2, '20-24', gmsHuman));
    Check(Cursor.Resolve(Tree) = Tree.MainlineNode[1],
      'a replacement at the same ply must not inherit the selection');
    Check(Cursor.Resolve(Other.GameTree) = Other.GameTree.Root,
      'switching trees must not reuse a coincident node ID');
    Check(Cursor.Following, 'switching trees resumes following');
  finally
    Moves.Free;
    Cursor.Free;
    Other.Free;
    Actor.Free;
  end;
  WriteLn('OK');
end.
