unit uGameTreeView;

{$mode objfpc}{$H+}

interface

uses
  ComCtrls, uGameTree;

procedure PopulateGameTreeView(ATreeView: TTreeView; AGameTree: TGameTree);

implementation

uses
  SysUtils, uDraughtsBoard;

function FormatClock(ASeconds: Double): string;
var
  LMinutes: Integer;
  LSeconds: Integer;
begin
  if ASeconds < 0 then
    ASeconds := 0;
  LMinutes := Trunc(ASeconds) div 60;
  LSeconds := Trunc(ASeconds) mod 60;
  Result := Format('%d:%.2d', [LMinutes, LSeconds]);
end;

function SecondsCaption(ASeconds: Double): string;
begin
  Result := FormatFloat('0.000', ASeconds) + ' s';
end;

function NodeCaption(ANode: TGameTreePlyNode): string;
begin
  if ANode = nil then
    Exit('');
  Result := IntToStr(ANode.MoveNumber);
  if ANode.SideToMove = dsWhite then
    Result += '.'
  else
    Result += '... ';
  Result += ANode.MoveText;
end;

procedure AddClockChildren(ATreeView: TTreeView; ATreeParent: TTreeNode;
  AModelNode: TGameTreePlyNode);
begin
  if (ATreeView = nil) or (ATreeParent = nil) or (AModelNode = nil) or
    (not AModelNode.HasClockInfo) then
    Exit;
  ATreeView.Items.AddChild(ATreeParent, 'White time left: ' +
    FormatClock(AModelNode.WhiteRemainingSeconds));
  ATreeView.Items.AddChild(ATreeParent, 'Black time left: ' +
    FormatClock(AModelNode.BlackRemainingSeconds));
  ATreeView.Items.AddChild(ATreeParent, 'White time used: ' +
    SecondsCaption(AModelNode.WhiteUsedSeconds));
  ATreeView.Items.AddChild(ATreeParent, 'Black time used: ' +
    SecondsCaption(AModelNode.BlackUsedSeconds));
end;

procedure AddAnalysisChildren(ATreeView: TTreeView; ATreeParent: TTreeNode;
  AModelNode: TGameTreePlyNode);
begin
  if (ATreeView = nil) or (ATreeParent = nil) or (AModelNode = nil) then
    Exit;

  if AModelNode.EngineScore <> '' then
    ATreeView.Items.AddChild(ATreeParent, 'Engine score: ' +
      AModelNode.EngineScore);
  if AModelNode.EnginePV <> '' then
    ATreeView.Items.AddChild(ATreeParent, 'Engine PV: ' +
      AModelNode.EnginePV);

  if AModelNode.AnnotatorScore <> '' then
    ATreeView.Items.AddChild(ATreeParent, 'Annotator score: ' +
      AModelNode.AnnotatorScore);
  if AModelNode.AnnotatorPV <> '' then
    ATreeView.Items.AddChild(ATreeParent, 'Annotator PV: ' +
      AModelNode.AnnotatorPV);
  if AModelNode.AutoPlayPV <> '' then
    ATreeView.Items.AddChild(ATreeParent, 'Auto Play PV: ' +
      AModelNode.AutoPlayPV);
end;

procedure AddChildren(ATreeView: TTreeView; ATreeParent: TTreeNode;
  AModelParent: TGameTreePlyNode);
var
  I: Integer;
  LChildTreeNode: TTreeNode;
begin
  if (ATreeView = nil) or (ATreeParent = nil) or (AModelParent = nil) then
    Exit;
  for I := 0 to AModelParent.ChildCount - 1 do
  begin
    LChildTreeNode := ATreeView.Items.AddChild(ATreeParent,
      NodeCaption(AModelParent.Children[I]));
    AddAnalysisChildren(ATreeView, LChildTreeNode, AModelParent.Children[I]);
    AddClockChildren(ATreeView, LChildTreeNode, AModelParent.Children[I]);
    AddChildren(ATreeView, LChildTreeNode, AModelParent.Children[I]);
  end;
end;

procedure PopulateGameTreeView(ATreeView: TTreeView; AGameTree: TGameTree);
var
  LRootCaption: string;
  LRootTreeNode: TTreeNode;
begin
  if (ATreeView = nil) or (AGameTree = nil) then
    Exit;

  ATreeView.Items.BeginUpdate;
  try
    ATreeView.Items.Clear;
    LRootCaption := AGameTree.WhiteName + ' - ' + AGameTree.BlackName +
      '  ' + AGameTree.ResultText;
    LRootTreeNode := ATreeView.Items.Add(nil, LRootCaption);
    ATreeView.Items.AddChild(LRootTreeNode, 'Event: ' +
      AGameTree.EventName);
    ATreeView.Items.AddChild(LRootTreeNode, 'FEN: ' +
      AGameTree.StartingFEN);
    if Trim(AGameTree.StatusText) <> '' then
      ATreeView.Items.AddChild(LRootTreeNode, 'Status: ' +
        AGameTree.StatusText);
    if AGameTree.HasTimeControl then
    begin
      ATreeView.Items.AddChild(LRootTreeNode, 'Moves per period: ' +
        IntToStr(AGameTree.MovesPerPeriod));
      ATreeView.Items.AddChild(LRootTreeNode, 'Minutes per period: ' +
        FormatFloat('0.###', AGameTree.MinutesPerPeriod));
      ATreeView.Items.AddChild(LRootTreeNode, 'Increment: ' +
        SecondsCaption(AGameTree.IncrementSeconds));
      if AGameTree.IncrementModeText <> '' then
        ATreeView.Items.AddChild(LRootTreeNode, 'Increment mode: ' +
          AGameTree.IncrementModeText);
    end;
    if AGameTree.HasClockInfo then
    begin
      ATreeView.Items.AddChild(LRootTreeNode, 'White time left: ' +
        FormatClock(AGameTree.WhiteRemainingSeconds));
      ATreeView.Items.AddChild(LRootTreeNode, 'Black time left: ' +
        FormatClock(AGameTree.BlackRemainingSeconds));
      ATreeView.Items.AddChild(LRootTreeNode, 'White time used: ' +
        SecondsCaption(AGameTree.WhiteUsedSeconds));
      ATreeView.Items.AddChild(LRootTreeNode, 'Black time used: ' +
        SecondsCaption(AGameTree.BlackUsedSeconds));
    end;
    AddAnalysisChildren(ATreeView, LRootTreeNode, AGameTree.Root);
    AddClockChildren(ATreeView, LRootTreeNode, AGameTree.Root);
    AddChildren(ATreeView, LRootTreeNode, AGameTree.Root);
    LRootTreeNode.Expand(False);
  finally
    ATreeView.Items.EndUpdate;
  end;
end;

end.
