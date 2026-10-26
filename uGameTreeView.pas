unit uGameTreeView;

{$mode objfpc}{$H+}

interface

uses
  ComCtrls, uGameTree;

type
  { gtvNotation: each line is a column of moves in game order; an alternative
    hangs under the move it replaces, so indentation follows variation depth.
    gtvNested: every move is a child of the previous move (the model's shape). }
  TGameTreeViewLayout = (gtvNotation, gtvNested);

procedure PopulateGameTreeView(ATreeView: TTreeView; AGameTree: TGameTree;
  ALayout: TGameTreeViewLayout = gtvNotation; APreserveState: Boolean = False);
function SelectedGameTreeNodeId(ATreeView: TTreeView): Int64;

implementation

uses
  SysUtils, fgl, uDraughtsBoard, uGameTreePdn;

type TExpansionMap = specialize TFPGMap<Int64, Boolean>;

function SelectedGameTreeNodeId(ATreeView: TTreeView): Int64;
var
  Node: TTreeNode;
begin
  Result := 0;
  if ATreeView = nil then Exit;
  Node := ATreeView.Selected;
  // Analysis and clock rows refer to their enclosing position.
  while (Node <> nil) and (Node.Data = nil) do Node := Node.Parent;
  if Node <> nil then Result := Int64(PtrUInt(Node.Data));
end;

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

function NodeCaption(ANode: TGameTreePlyNode; Captions: TGameTreeMoveCaptionMap): string;
begin
  if ANode = nil then
    Exit('');
  Result := IntToStr(ANode.MoveNumber);
  if ANode.SideToMove = dsWhite then
    Result += '.'
  else
    Result += '... ';
  Result += Captions.Data[Captions.IndexOf(ANode.NodeId)];
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
  AModelParent: TGameTreePlyNode; Captions: TGameTreeMoveCaptionMap);
var
  I: Integer;
  LChildTreeNode: TTreeNode;
begin
  if (ATreeView = nil) or (ATreeParent = nil) or (AModelParent = nil) then
    Exit;
  for I := 0 to AModelParent.ChildCount - 1 do
  begin
    LChildTreeNode := ATreeView.Items.AddChild(ATreeParent,
      NodeCaption(AModelParent.Children[I], Captions));
    LChildTreeNode.Data := Pointer(PtrUInt(AModelParent.Children[I].NodeId));
    AddAnalysisChildren(ATreeView, LChildTreeNode, AModelParent.Children[I]);
    AddClockChildren(ATreeView, LChildTreeNode, AModelParent.Children[I]);
    AddChildren(ATreeView, LChildTreeNode, AModelParent.Children[I], Captions);
  end;
end;

function AddMoveRow(ATreeView: TTreeView; AContainer: TTreeNode;
  AModelNode: TGameTreePlyNode; Captions: TGameTreeMoveCaptionMap): TTreeNode;
begin
  Result := ATreeView.Items.AddChild(AContainer, NodeCaption(AModelNode, Captions));
  Result.Data := Pointer(PtrUInt(AModelNode.NodeId));
  AddAnalysisChildren(ATreeView, Result, AModelNode);
  AddClockChildren(ATreeView, Result, AModelNode);
end;

procedure AddNotationAlternative(ATreeView: TTreeView; AReplacedRow: TTreeNode;
  AAlternative: TGameTreePlyNode; Captions: TGameTreeMoveCaptionMap); forward;

procedure AddNotationLine(ATreeView: TTreeView; AContainer: TTreeNode;
  AFirst: TGameTreePlyNode; Captions: TGameTreeMoveCaptionMap);
var
  I: Integer;
  LNode: TGameTreePlyNode;
  LParent: TGameTreePlyNode;
  LRow: TTreeNode;
begin
  // Rows for a line are siblings, one per ply. Each row is followed (as its
  // children) by the alternatives to that move, in the model's child order.
  LNode := AFirst;
  while LNode <> nil do
  begin
    LRow := AddMoveRow(ATreeView, AContainer, LNode, Captions);
    LParent := LNode.Parent;
    if (LParent <> nil) and (LParent.ChildCount > 1) and
      (LParent.Children[0] = LNode) then
      for I := 1 to LParent.ChildCount - 1 do
        AddNotationAlternative(ATreeView, LRow, LParent.Children[I], Captions);
    if LNode.ChildCount > 0 then
      LNode := LNode.Children[0]
    else
      LNode := nil;
  end;
end;

procedure AddNotationAlternative(ATreeView: TTreeView; AReplacedRow: TTreeNode;
  AAlternative: TGameTreePlyNode; Captions: TGameTreeMoveCaptionMap);
var
  LRow: TTreeNode;
begin
  // The alternative's first move is the variation's header row; the rest of
  // the variation continues as a column beneath it.
  LRow := AddMoveRow(ATreeView, AReplacedRow, AAlternative, Captions);
  LRow.Text := 'Variation: ' + LRow.Text;
  if AAlternative.ChildCount > 0 then
    AddNotationLine(ATreeView, LRow, AAlternative.Children[0], Captions);
end;

procedure PopulateGameTreeView(ATreeView: TTreeView; AGameTree: TGameTree;
  ALayout: TGameTreeViewLayout; APreserveState: Boolean);
var
  LRootCaption: string;
  LRootTreeNode, SelectedRow: TTreeNode;
  Captions: TGameTreeMoveCaptionMap;
  Expanded: TExpansionMap;
  I, Index, Work: Integer;
  SelectedId, Id: Int64;
begin
  if (ATreeView = nil) or (AGameTree = nil) then
    Exit;

  Captions := TGameTreeMoveCaptionMap.Create;
  Expanded := TExpansionMap.Create;
  Expanded.Sorted := True;
  SelectedId := 0;
  try
    BuildGameTreeMoveCaptions(AGameTree, Captions, Work);
    if APreserveState then
    begin
      SelectedId := SelectedGameTreeNodeId(ATreeView);
      for I := 0 to ATreeView.Items.Count - 1 do
        if ATreeView.Items[I].Data <> nil then
          Expanded.Add(Int64(PtrUInt(ATreeView.Items[I].Data)), ATreeView.Items[I].Expanded);
    end;
  ATreeView.Items.BeginUpdate;
  try
    ATreeView.Items.Clear;
    LRootCaption := AGameTree.WhiteName + ' - ' + AGameTree.BlackName +
      '  ' + AGameTree.ResultText;
    LRootTreeNode := ATreeView.Items.Add(nil, LRootCaption);
    LRootTreeNode.Data := Pointer(PtrUInt(AGameTree.Root.NodeId));
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
    if ALayout = gtvNested then
      AddChildren(ATreeView, LRootTreeNode, AGameTree.Root, Captions)
    else if AGameTree.Root.ChildCount > 0 then
      AddNotationLine(ATreeView, LRootTreeNode, AGameTree.Root.Children[0], Captions);
    LRootTreeNode.Expand(False);
    SelectedRow := nil;
    for I := 0 to ATreeView.Items.Count - 1 do
      if ATreeView.Items[I].Data <> nil then
      begin
        Id := Int64(PtrUInt(ATreeView.Items[I].Data));
        Index := Expanded.IndexOf(Id);
        if Index >= 0 then ATreeView.Items[I].Expanded := Expanded.Data[Index];
        if Id = SelectedId then SelectedRow := ATreeView.Items[I];
      end;
    if SelectedRow <> nil then
    begin
      ATreeView.Selected := SelectedRow;
      SelectedRow.MakeVisible;
    end;
  finally
    ATreeView.Items.EndUpdate;
  end;
  finally Expanded.Free; Captions.Free; end;
end;

end.
