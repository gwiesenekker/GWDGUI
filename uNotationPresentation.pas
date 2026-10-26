unit uNotationPresentation;

{$mode objfpc}{$H+}

interface

uses SysUtils, uGameTree, uGameTreePdn;

type
  TNotationRange = record
    Start, Length: Integer;
  end;
  TMoveVariationHit = record
    NodeId: Int64;
    BeforeMove: Boolean;
    Start: Integer;
    Length: Integer;
    VariationPly: Integer;
    BasePly: Integer;
    MovesText: string;
  end;

  TNotationSelection = record
    NodeId: Int64;
    BasePly, PreviewPly: Integer;
    PreviewMoves: string;
  end;
  TNotationBrowseKind = (nbNone, nbConsumed, nbHandled, nbMainline, nbNode, nbBeforeNode,
    nbPreview);
  TNotationBrowseTarget = record
    Kind: TNotationBrowseKind;
    Ply: Integer;
    Variation: TMoveVariationHit;
  end;

  // A disposable projection of the tree. No tree, cursor or UI is owned here.
  TNotationPresentation = class
  private
    FRendered: TGameTreePdnRenderResult;
    FSignature: string;
    function GetText: string;
    function GetMoveCount: Integer;
    function GetVariationCount: Integer;
    function GetMoveRange(AIndex: Integer): TNotationRange;
    function GetVariationHit(AIndex: Integer): TMoveVariationHit;
  public
    procedure Render(ATree: TGameTree; const AOptions: TGameTreePdnRenderOptions);
    procedure InvalidateSignature;
    procedure ClearVariationHits;
    function HitTest(AStart, ALength: Integer;
      const ASelection: TNotationSelection): TNotationBrowseTarget;
    function AutomaticHighlight(const ASelection: TNotationSelection;
      AHighlightPly: Integer; out AVariation: Boolean): TNotationRange;
    function SelectionHighlight(const ASelection: TNotationSelection;
      out ARange: TNotationRange): Boolean;
    property Text: string read GetText;
    property Signature: string read FSignature;
    property MoveCount: Integer read GetMoveCount;
    property MoveRanges[AIndex: Integer]: TNotationRange read GetMoveRange;
    property VariationCount: Integer read GetVariationCount;
    property VariationHits[AIndex: Integer]: TMoveVariationHit read GetVariationHit;
  end;

function GameTreeMoveLabelsSignature(AGameTree: TGameTree;
  const AOptions: TGameTreePdnRenderOptions): string;

implementation

function GameTreeMoveLabelsSignature(AGameTree: TGameTree;
  const AOptions: TGameTreePdnRenderOptions): string;

  procedure AppendFlag(var AText: string; AValue: Boolean);
  begin
    if AValue then
      AText += '1|'
    else
      AText += '0|';
  end;

  procedure AppendNode(var AText: string; ANode: TGameTreePlyNode);
  var
    ChildIndex: Integer;
  begin
    if ANode = nil then
      Exit;
    AText += IntToStr(ANode.PlyNumber) + '|' +
      IntToStr(Ord(ANode.SideToMove)) + '|' + ANode.MoveText + '|' +
      IntToStr(ANode.NodeId) + '|';
    if not AOptions.HideAnnotations then
    begin
      if AOptions.ShowEngineScore then
        AText += 'es=' + ANode.EngineScore + '|';
      if AOptions.ShowAnnotatorScore then
        AText += 'as=' + ANode.AnnotatorScore + '|';
      AText += 'ct=' + ANode.CommentText + '|';
      if AOptions.ShowClocks and ANode.HasClockInfo then
        AText += 'clk=' + FormatFloat('0.000', ANode.WhiteRemainingSeconds) +
          ',' + FormatFloat('0.000', ANode.BlackRemainingSeconds) + ',' +
          FormatFloat('0.000', ANode.WhiteUsedSeconds) + ',' +
          FormatFloat('0.000', ANode.BlackUsedSeconds) + '|';
    end;
    if AOptions.ShowEnginePVMove or AOptions.ShowEngineFullPV then
      AText += 'epv=' + ANode.EnginePV + '|';
    if AOptions.ShowAnnotatorPVMove or AOptions.ShowAnnotatorFullPV then
      AText += 'apv=' + ANode.AnnotatorPV + '|';
    AText += 'autopv=' + ANode.AutoPlayPV + '|';
    AText += 'children=' + IntToStr(ANode.ChildCount) + '|';
    for ChildIndex := 0 to ANode.ChildCount - 1 do
      AppendNode(AText, ANode.Children[ChildIndex]);
  end;

begin
  Result := '';
  if AGameTree = nil then
    Exit;
  AppendFlag(Result, AOptions.HideAnnotations);
  AppendFlag(Result, AOptions.ShowEngineScore);
  AppendFlag(Result, AOptions.ShowClocks);
  AppendFlag(Result, AOptions.ShowEnginePVMove);
  AppendFlag(Result, AOptions.ShowEngineFullPV);
  AppendFlag(Result, AOptions.ShowAnnotatorPVMove);
  AppendFlag(Result, AOptions.ShowAnnotatorFullPV);
  AppendFlag(Result, AOptions.ShowAnnotatorScore);
  Result += 'main=' + IntToStr(AGameTree.MainlineCount) + '|';
  AppendNode(Result, AGameTree.Root);
end;

procedure TNotationPresentation.Render(ATree: TGameTree;
  const AOptions: TGameTreePdnRenderOptions);
begin
  if ATree = nil then Exit;
  FSignature := GameTreeMoveLabelsSignature(ATree, AOptions);
  RenderGameTreeMovesToPdn(ATree, AOptions, FRendered);
end;

procedure TNotationPresentation.InvalidateSignature;
begin
  FSignature := '';
end;

procedure TNotationPresentation.ClearVariationHits;
begin
  FRendered.VariationStarts := nil;
  FRendered.VariationLengths := nil;
  FRendered.VariationNodeIds := nil;
  FRendered.VariationBeforeMoves := nil;
  FRendered.VariationPlies := nil;
  FRendered.VariationBasePlies := nil;
  FRendered.VariationMovesTexts := nil;
end;

function TNotationPresentation.GetText: string;
begin
  Result := FRendered.Text;
end;

function TNotationPresentation.GetMoveCount: Integer;
begin
  Result := Length(FRendered.MoveStarts);
end;

function TNotationPresentation.GetVariationCount: Integer;
begin
  Result := Length(FRendered.VariationStarts);
end;

function TNotationPresentation.GetMoveRange(AIndex: Integer): TNotationRange;
begin
  Result.Start := FRendered.MoveStarts[AIndex];
  Result.Length := FRendered.MoveLengths[AIndex];
end;

function TNotationPresentation.GetVariationHit(AIndex: Integer): TMoveVariationHit;
begin
  Result.NodeId := FRendered.VariationNodeIds[AIndex];
  Result.BeforeMove := FRendered.VariationBeforeMoves[AIndex];
  Result.Start := FRendered.VariationStarts[AIndex];
  Result.Length := FRendered.VariationLengths[AIndex];
  Result.VariationPly := FRendered.VariationPlies[AIndex];
  Result.BasePly := FRendered.VariationBasePlies[AIndex];
  Result.MovesText := FRendered.VariationMovesTexts[AIndex];
end;
function TNotationPresentation.HitTest(AStart, ALength: Integer;
  const ASelection: TNotationSelection): TNotationBrowseTarget;
var
  I, SelectionEnd: Integer;
  Hit: TMoveVariationHit;

  function SelectionHitsRange(AHitStart, AHitLength: Integer): Boolean;
  var RangeEnd: Integer;
  begin
    Result := False;
    if AHitLength <= 0 then Exit;
    RangeEnd := AHitStart + AHitLength;
    // Preserve the memo's inclusive right endpoint for a caret, but use
    // exclusive range overlap when text is selected.
    if SelectionEnd > AStart then
      Result := (AStart < RangeEnd) and (SelectionEnd > AHitStart)
    else
      Result := (AStart >= AHitStart) and (AStart <= RangeEnd);
  end;

begin
  Result := Default(TNotationBrowseTarget);
  SelectionEnd := AStart + ALength;
  for I := 0 to VariationCount - 1 do
  begin
    Hit := VariationHits[I];
    if (Trim(ASelection.PreviewMoves) <> '') and
      ((Hit.BasePly <> ASelection.BasePly) or
       (Hit.MovesText <> ASelection.PreviewMoves)) then Continue;
    if SelectionHitsRange(Hit.Start, Hit.Length) then
    begin
      Result.Variation := Hit;
      if Hit.NodeId > 0 then
      begin
        if Hit.BeforeMove then Result.Kind := nbBeforeNode
        else Result.Kind := nbNode;
      end
      else if Trim(Hit.MovesText) <> '' then Result.Kind := nbPreview
      else Result.Kind := nbHandled;
      Exit;
    end;
  end;
  // While previewing, clicks outside its own ranges are consumed without
  // jumping to an unrelated mainline or variation.
  if Trim(ASelection.PreviewMoves) <> '' then
  begin
    Result.Kind := nbConsumed;
    Exit;
  end;
  for I := 0 to MoveCount - 1 do
    if SelectionHitsRange(MoveRanges[I].Start, MoveRanges[I].Length) then
    begin
      Result.Kind := nbMainline;
      Result.Ply := I + 1;
      Exit;
    end;
  if (MoveCount > 0) and (AStart < MoveRanges[0].Start) then
  begin
    Result.Kind := nbMainline;
    Result.Ply := 0;
  end;
end;

function TNotationPresentation.AutomaticHighlight(
  const ASelection: TNotationSelection; AHighlightPly: Integer;
  out AVariation: Boolean): TNotationRange;
var I: Integer; Hit: TMoveVariationHit;
begin
  AVariation := False;
  for I := 0 to VariationCount - 1 do
  begin
    Hit := VariationHits[I];
    if ((ASelection.PreviewMoves = '') and not Hit.BeforeMove and
      (Hit.NodeId > 0) and (Hit.NodeId = ASelection.NodeId)) or
      ((ASelection.PreviewMoves <> '') and (Hit.MovesText = ASelection.PreviewMoves) and
      (Hit.BasePly = ASelection.BasePly) and (Hit.VariationPly = ASelection.PreviewPly)) then
    begin
      Result.Start := Hit.Start;
      Result.Length := Hit.Length;
      AVariation := True;
      Exit;
    end;
  end;
  if (AHighlightPly > 0) and (AHighlightPly <= MoveCount) then
    Exit(MoveRanges[AHighlightPly - 1]);
  Result.Start := 0;
  Result.Length := 0;
end;

function TNotationPresentation.SelectionHighlight(
  const ASelection: TNotationSelection; out ARange: TNotationRange): Boolean;
var I: Integer; Hit: TMoveVariationHit;
begin
  Result := True;
  if Trim(ASelection.PreviewMoves) <> '' then
    for I := 0 to VariationCount - 1 do
    begin
      Hit := VariationHits[I];
      if (Hit.BasePly = ASelection.BasePly) and
        (Hit.MovesText = ASelection.PreviewMoves) and
        (Hit.VariationPly = ASelection.PreviewPly) then
      begin
        ARange.Start := Hit.Start;
        ARange.Length := Hit.Length;
        Exit;
      end;
    end;
  for I := 0 to VariationCount - 1 do
  begin
    Hit := VariationHits[I];
    if (Hit.NodeId = ASelection.NodeId) and (Hit.NodeId > 0) and not Hit.BeforeMove then
    begin
      ARange.Start := Hit.Start;
      ARange.Length := Hit.Length;
      Exit;
    end;
  end;
  if (ASelection.BasePly > 0) and (ASelection.BasePly <= MoveCount) then
    ARange := MoveRanges[ASelection.BasePly - 1]
  else
    Result := False; // Explicit focus/navigation leaves the existing selection.
end;

end.
