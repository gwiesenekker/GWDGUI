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
var
  I: Integer;

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
end.
