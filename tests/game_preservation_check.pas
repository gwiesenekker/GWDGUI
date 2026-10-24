program game_preservation_check;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uGameTree, uGameTreeActor, uGameTreeBuilder,
  uGameTreePdn, uGameOrchestrator;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    WriteLn('FAIL: ', AMessage);
    Halt(1);
  end;
end;

procedure Execute(AActor: TGameTreeActor; ACommand: TGameTreeCommand);
begin
  try
    AActor.ExecuteCommand(ACommand);
    Check(ACommand.Accepted, 'command rejected: ' + ACommand.ErrorText);
  finally
    ACommand.Free;
  end;
end;

procedure Rebuild(AActor: TGameTreeActor; const ASignature, AFen,
  AMoves: string);
var
  Moves, Annotations: TStringList;
begin
  Moves := TStringList.Create;
  Annotations := TStringList.Create;
  try
    TextToMoveList(AMoves, Moves);
    Execute(AActor, AActor.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput(ASignature, 'test', 'White', 'Black', '*', AFen,
        False, DefaultTimeControl),
      GameTreeMainlineInput(Moves, Annotations, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
  finally
    Annotations.Free;
    Moves.Free;
  end;
end;

procedure CheckStoredVariationsAreExported;
var
  Actor: TGameTreeActor;
  Command: TGameTreeCommand;
  Revision: Int64;
  Text: string;
begin
  Actor := TGameTreeActor.Create;
  try
    Rebuild(Actor, 'import', '', '32-28 18-23 37-32');
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '19-23 37-32 14-19', 'A: 0.10', gmsUnknown));
    Check(Actor.GameTree.FindVariationNode(0, 1) <> nil,
      'storing an imported variation must create its first node immediately');
    Check(Actor.GameTree.FindVariationNode(0, 3) <> nil,
      'all imported variation moves must be materialized');
    Text := GameTreeToPdnText(Actor.GameTree);
    Check(Pos('(1... 19-23', Text) > 0, 'export must retain the variation');
    Check(Pos('14-19 {A: 0.10}', Text) > 0,
      'export must retain its tail and annotation');
    Revision := Actor.Revision;
    Command := Actor.CreateStoreVariationLineCommand(2, 1,
      '19-23 37-32 14-19', 'A: 0.10', gmsUnknown);
    Execute(Actor, Command);
    Check(Actor.Revision = Revision, 'storing an unchanged line must be a no-op');
  finally
    Actor.Free;
  end;
end;

procedure CheckVariationsBelongToTheirGame;
var
  Actor: TGameTreeActor;
begin
  Actor := TGameTreeActor.Create;
  try
    Rebuild(Actor, 'game A', '', '32-28 18-23');
    Execute(Actor, Actor.CreateStoreVariationLineCommand(2, 1,
      '19-23 37-32', 'A: 0.20', gmsUnknown));
    Rebuild(Actor, 'game A', '', '32-28 18-23');
    Check(Actor.GameTree.VariationLineCount = 1,
      'refreshing the same game must preserve its variation');
    Check(Actor.GameTree.FindVariationNode(0, 2).AnnotatorScore = '0.20',
      'refreshing the same game must preserve variation annotations');
    Rebuild(Actor, 'game B', '', '32-28 18-23');
    Check(Actor.GameTree.VariationLineCount = 0,
      'a different game must not inherit variations even with the same moves');
    Execute(Actor, Actor.CreateStoreMoveVariationCommand(
      Actor.GameTree.Root.NodeId, '33-28', gmsHuman));
    Rebuild(Actor, 'game C', 'W:W31,32:B19,20', '');
    Check((Actor.GameTree.VariationLineCount = 0) and
      (Actor.GameTree.Root.ChildCount = 0),
      'loading a new FEN must not inherit a previous root variation');
  finally
    Actor.Free;
  end;
end;

begin
  CheckStoredVariationsAreExported;
  CheckVariationsBelongToTheirGame;
  WriteLn('OK');
end.
