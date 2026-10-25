unit uTreeTestUtils;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, uGameTree, uGameTreeActor;
function ImportBranch(Actor: TGameTreeActor; BasePly: Integer;
  const Moves, Annotation: string; Source: TGameTreeMoveSource = gmsUnknown): TGameTreeCommand;
procedure AddFixtureBranch(Tree: TGameTree; BasePly: Integer;
  const MovesText, Annotation: string);
implementation
uses uGameTreeBuilder, uPdn;
function ImportBranch(Actor: TGameTreeActor; BasePly: Integer;
  const Moves, Annotation: string; Source: TGameTreeMoveSource): TGameTreeCommand;
var Parent: TGameTreePlyNode; Id: Int64;
begin
  Id := 0;
  if BasePly = 0 then Parent := Actor.GameTree.Root
  else Parent := Actor.GameTree.MainlineNode[BasePly];
  if Parent <> nil then Id := Parent.NodeId;
  Result := Actor.CreateImportBranchCommand(Id, Moves, Annotation, Source);
end;
procedure AddFixtureBranch(Tree: TGameTree; BasePly: Integer;
  const MovesText, Annotation: string);
var Moves, Annotations: TStringList; I: Integer; Node: TGameTreePlyNode;
begin
  Moves := TStringList.Create;
  Annotations := TStringList.Create;
  try
    TextToMoveList(MovesText, Moves);
    DecodeVariationAnnotations(Annotation, Moves.Count, Annotations);
    if BasePly = 0 then Node := Tree.Root else Node := Tree.MainlineNode[BasePly];
    for I := 0 to Moves.Count - 1 do
    begin
      Node := Tree.RecordBranchMove(Node, Moves[I]);
      Tree.RecordNodeAnnotation(Node, Annotations[I]);
    end;
  finally Annotations.Free; Moves.Free; end;
end;
end.
