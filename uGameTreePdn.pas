unit uGameTreePdn;

{$mode objfpc}{$H+}

interface

uses
  Classes, StrUtils, SysUtils, uDraughtsBoard, uGameTree;

type
  TGameTreePdnIntArray = array of Integer;
  TGameTreePdnNodeIdArray = array of Int64;
  TGameTreePdnBoolArray = array of Boolean;
  TGameTreePdnStringArray = array of string;

  TGameTreePdnRenderOptions = record
    HideAnnotations: Boolean;
    ShowEngineScore: Boolean;
    ShowClocks: Boolean;
    ShowEnginePVMove: Boolean;
    ShowEngineFullPV: Boolean;
    ShowAnnotatorPVMove: Boolean;
    ShowAnnotatorFullPV: Boolean;
    ShowAnnotatorScore: Boolean;
  end;

  TGameTreePdnRenderResult = record
    Text: string;
    MoveStarts: TGameTreePdnIntArray;
    MoveLengths: TGameTreePdnIntArray;
    VariationStarts: TGameTreePdnIntArray;
    VariationNodeIds: TGameTreePdnNodeIdArray;
    VariationBeforeMoves: TGameTreePdnBoolArray;
    VariationLengths: TGameTreePdnIntArray;
    VariationPlies: TGameTreePdnIntArray;
    VariationBasePlies: TGameTreePdnIntArray;
    VariationMovesTexts: TGameTreePdnStringArray;
  end;

function DefaultGameTreePdnRenderOptions: TGameTreePdnRenderOptions;
function GameTreeToPdnText(AGameTree: TGameTree): string;
function GameTreeToPdnTextEx(AGameTree: TGameTree;
  const AOptions: TGameTreePdnRenderOptions;
  const AEventName: string = ''): string;
procedure RenderGameTreeMovesToPdn(AGameTree: TGameTree;
  const AOptions: TGameTreePdnRenderOptions;
  out ARenderResult: TGameTreePdnRenderResult);
function GameTreeScoreAnnotationsText(AGameTree: TGameTree): string;
function GameTreeHasContent(AGameTree: TGameTree): Boolean;

implementation

uses uPdn;

function GameTreeHasContent(AGameTree: TGameTree): Boolean;
begin
  Result := False;
  if AGameTree = nil then
    Exit;
  Result := (AGameTree.MainlineCount > 0) or (AGameTree.BranchCount > 0) or
    (AGameTree.StartingFEN <> DefaultStartingFEN) or
    (AGameTree.ResultText <> '*') or (AGameTree.EventName <> '?') or
    (AGameTree.WhiteName <> 'White') or (AGameTree.BlackName <> 'Black') or
    (AGameTree.Root.CommentText <> '') or (AGameTree.Root.EnginePV <> '') or
    (AGameTree.Root.AnnotatorPV <> '') or (AGameTree.Root.AutoPlayPV <> '') or
    (AGameTree.Root.EngineScore <> '') or (AGameTree.Root.AnnotatorScore <> '');
end;

function DefaultGameTreePdnRenderOptions: TGameTreePdnRenderOptions;
begin
  Result.HideAnnotations := False;
  Result.ShowEngineScore := True;
  Result.ShowClocks := True;
  Result.ShowEnginePVMove := True;
  Result.ShowEngineFullPV := True;
  Result.ShowAnnotatorPVMove := True;
  Result.ShowAnnotatorFullPV := True;
  Result.ShowAnnotatorScore := True;
end;

function PdnQuote(const AText: string): string;
begin
  Result := StringReplace(AText, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
end;

function PdnExportResult(const AText: string): string;
begin
  Result := Trim(AText);
  if SameText(Result, '2-0') then
    Result := '1-0'
  else if SameText(Result, '1-1') then
    Result := '1/2-1/2'
  else if SameText(Result, '0-2') then
    Result := '0-1'
  else if not SameText(Result, '*') and not SameText(Result, '0-0') then
    Result := '*';
end;

function NodeMoveCaption(AGameTree: TGameTree; ANode: TGameTreePlyNode; AForceMoveNumber: Boolean;
  ACompact: Boolean): string;
var Board: TDraughtsBoard; MoveText: string;
begin
  Result := '';
  if ANode = nil then
    Exit;

  if (ANode.SideToMove = dsWhite) or AForceMoveNumber then
  begin
    Result := IntToStr(ANode.MoveNumber);
    if ANode.SideToMove = dsWhite then
      Result += '.'
    else
      Result += '...';
    if not ACompact then
      Result += ' ';
  end;
  MoveText := ANode.MoveText;
  if not ACompact and (Pos('x', MoveText) > 0) then
  begin
    Board := TDraughtsBoard.Create;
    try
      if AGameTree.TryBuildBoardAtNode(ANode.Parent, Board) then
        MoveText := Board.PdnMoveNotation(MoveText);
    finally Board.Free; end;
  end;
  Result += MoveText;
end;

function ClockSecondsCaption(ASeconds: Double): string;
begin
  Result := FormatFloat('0.000', ASeconds);
end;

function NodeClockAnnotation(ANode: TGameTreePlyNode): string;
begin
  Result := '';
  if (ANode = nil) or (not ANode.HasClockInfo) then
    Exit;
  Result := 'clk: W=' + ClockSecondsCaption(ANode.WhiteRemainingSeconds) +
    ', B=' + ClockSecondsCaption(ANode.BlackRemainingSeconds) +
    '; used: W=' + ClockSecondsCaption(ANode.WhiteUsedSeconds) +
    ', B=' + ClockSecondsCaption(ANode.BlackUsedSeconds);
  if ANode.HasMoveTime then
    Result += '; emt: ' + ClockSecondsCaption(ANode.SecondsUsed);
end;

function FirstPvMove(const APv: string): string;
var
  Moves: TStringList;
begin
  Result := '';
  Moves := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(APv)), Moves);
    if Moves.Count > 0 then
      Result := NormalizeMoveNotation(Moves[0]);
  finally
    Moves.Free;
  end;
end;

function NodeAnnotation(ANode: TGameTreePlyNode;
  const AOptions: TGameTreePdnRenderOptions): string;
var
  LClockText: string;
begin
  Result := '';
  if ANode = nil then
    Exit;
  if AOptions.HideAnnotations then
    Exit;
  if Trim(ANode.CommentText) <> '' then
    Result := Trim(ANode.CommentText);
  if AOptions.ShowEngineScore and (Trim(ANode.EngineScore) <> '') then
  begin
    if Result <> '' then
      Result += '; ';
    Result += 'E: ' + Trim(ANode.EngineScore);
  end;
  if AOptions.ShowAnnotatorScore and (Trim(ANode.AnnotatorScore) <> '') then
  begin
    if Result <> '' then
      Result += '; ';
    Result += 'A: ' + Trim(ANode.AnnotatorScore);
  end;
  if AOptions.ShowClocks then
  begin
    LClockText := NodeClockAnnotation(ANode);
    if LClockText <> '' then
    begin
      if Result <> '' then
        Result += '; ';
      Result += LClockText;
    end;
  end;
  if Result <> '' then
    Result := ' {' + EscapePdnComment(Result) + '}';
end;

function NodeIsAnnotatorAlternative(APrevious, ANode: TGameTreePlyNode): Boolean;
var
  LPvMove: string;
begin
  Result := False;
  if (APrevious = nil) or (ANode = nil) then
    Exit;
  if Trim(APrevious.AnnotatorPV) = '' then
    Exit;
  LPvMove := FirstPvMove(APrevious.AnnotatorPV);
  Result := (LPvMove <> '') and
    (not SameText(LPvMove, NormalizeMoveNotation(ANode.MoveText)));
end;

function SideForNextPly(ASide: TDraughtsSide): TDraughtsSide;
begin
  if ASide = dsWhite then
    Result := dsBlack
  else
    Result := dsWhite;
end;

function PreviousPositionAnnotation(APrevious, APlayedMove: TGameTreePlyNode;
  const AOptions: TGameTreePdnRenderOptions): string;
begin
  Result := '';
  if (APrevious = nil) or (APlayedMove = nil) then
    Exit;
  if AOptions.HideAnnotations or (not AOptions.ShowAnnotatorScore) then
    Exit;
  if Trim(APrevious.AnnotatorScore) = '' then
    Exit;
  if Trim(APlayedMove.AnnotatorScore) <> '' then
    Exit;
  if Trim(APrevious.AnnotatorPV) <> '' then
    Exit;
  Result := ' {A: ' + Trim(APrevious.AnnotatorScore) + '}';
end;

function PlyMoveCaption(APlyNumber: Integer; ASideToMove: TDraughtsSide;
  const AMoveText: string; AForceMoveNumber, ACompact: Boolean): string;
var
  LMoveNumber: Integer;
begin
  Result := '';
  LMoveNumber := ((APlyNumber - 1) div 2) + 1;
  if (ASideToMove = dsWhite) or AForceMoveNumber then
  begin
    Result := IntToStr(LMoveNumber);
    if ASideToMove = dsWhite then
      Result += '.'
    else
      Result += '...';
    if not ACompact then
      Result += ' ';
  end;
  Result += AMoveText;
end;

procedure AddNodeHit(var AResult: TGameTreePdnRenderResult; ANodeId: Int64;
  ABeforeMove: Boolean); forward;
procedure AddInt(var AValues: TGameTreePdnIntArray; AValue: Integer); forward;
procedure AddString(var AValues: TGameTreePdnStringArray;
  const AValue: string); forward;

function RenderAnalysisVariation(ABaseNode: TGameTreePlyNode;
  const APv, AScore, AScorePrefix: string; AShowFullPv, AShowScore: Boolean;
  const AOptions: TGameTreePdnRenderOptions; ACompact: Boolean;
  var ARenderResult: TGameTreePdnRenderResult; ABaseOffset: Integer): string;
var
  I: Integer;
  LLimit: Integer;
  LMoveStart: Integer;
  LMoves: TStringList;
  LPlyNumber: Integer;
  LSegment: string;
  LSegmentOffset: Integer;
  LSide: TDraughtsSide;
begin
  Result := '';
  if (ABaseNode = nil) or (Trim(APv) = '') then
    Exit;

  LMoves := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(APv)),
      LMoves);
    if LMoves.Count = 0 then
      Exit;
    LLimit := 1;
    if AShowFullPv then
      LLimit := LMoves.Count;
    LSide := SideForNextPly(ABaseNode.SideToMove);
    if ABaseNode.PlyNumber = 0 then
      LSide := ABaseNode.SideToMove;
    for I := 0 to LLimit - 1 do
    begin
      LPlyNumber := ABaseNode.PlyNumber + I + 1;
      LSegment := PlyMoveCaption(LPlyNumber, LSide, LMoves[I], I = 0,
        ACompact);
      if (I = 0) and (ABaseNode.PlyNumber = 0) and
        AShowScore and
        (not AOptions.HideAnnotations) and
        (Trim(AScore) <> '') then
        LSegment += ' {' + AScorePrefix + ': ' + Trim(AScore) + '}';
      if Result <> '' then
        Result += ' ';
      LSegmentOffset := Length(Result);
      Result += LSegment;
      LMoveStart := Pos(LMoves[I], LSegment);
      if LMoveStart > 0 then
      begin
        AddNodeHit(ARenderResult, 0, False);
        AddInt(ARenderResult.VariationStarts,
          ABaseOffset + 1 + LSegmentOffset + LMoveStart - 1);
        AddInt(ARenderResult.VariationLengths, Length(LMoves[I]));

        AddInt(ARenderResult.VariationPlies, I + 1);
        AddInt(ARenderResult.VariationBasePlies, ABaseNode.PlyNumber);
        AddString(ARenderResult.VariationMovesTexts, Trim(APv));
      end;
      LSide := SideForNextPly(LSide);
    end;
    if Result <> '' then
    begin
      Result := '(' + Result + ')';
      AddNodeHit(ARenderResult, 0, False);
      AddInt(ARenderResult.VariationStarts, ABaseOffset);
      AddInt(ARenderResult.VariationLengths,
        Pos(LMoves[0], Result) - 1);

      AddInt(ARenderResult.VariationPlies, 0);
      AddInt(ARenderResult.VariationBasePlies, ABaseNode.PlyNumber);
      AddString(ARenderResult.VariationMovesTexts, Trim(APv));
    end;
  finally
    LMoves.Free;
  end;
end;

function FindContinuationChild(ANode: TGameTreePlyNode): TGameTreePlyNode;
begin
  Result := nil;
  if (ANode <> nil) and (ANode.ChildCount > 0) then Result := ANode.Children[0];
end;

procedure AddInt(var AValues: TGameTreePdnIntArray; AValue: Integer);
var
  LIndex: Integer;
begin
  LIndex := Length(AValues);
  SetLength(AValues, LIndex + 1);
  AValues[LIndex] := AValue;
end;

procedure AddString(var AValues: TGameTreePdnStringArray;
  const AValue: string);
var
  LIndex: Integer;
begin
  LIndex := Length(AValues);
  SetLength(AValues, LIndex + 1);
  AValues[LIndex] := AValue;
end;

procedure AddNodeHit(var AResult: TGameTreePdnRenderResult; ANodeId: Int64;
  ABeforeMove: Boolean);
var
  N: Integer;
begin
  N := Length(AResult.VariationNodeIds);
  SetLength(AResult.VariationNodeIds, N + 1);
  SetLength(AResult.VariationBeforeMoves, N + 1);
  AResult.VariationNodeIds[N] := ANodeId;
  AResult.VariationBeforeMoves[N] := ABeforeMove;
end;

procedure ClearRenderResult(out ARenderResult: TGameTreePdnRenderResult);
begin
  ARenderResult.Text := '';
  SetLength(ARenderResult.MoveStarts, 0);
  SetLength(ARenderResult.MoveLengths, 0);
  SetLength(ARenderResult.VariationStarts, 0);
  SetLength(ARenderResult.VariationNodeIds, 0);
  SetLength(ARenderResult.VariationBeforeMoves, 0);
  SetLength(ARenderResult.VariationLengths, 0);
  SetLength(ARenderResult.VariationPlies, 0);
  SetLength(ARenderResult.VariationBasePlies, 0);
  SetLength(ARenderResult.VariationMovesTexts, 0);
end;

function RenderVariationLine(AGameTree: TGameTree; ANode, APreviousPosition: TGameTreePlyNode;
  const AOptions: TGameTreePdnRenderOptions; ACompact: Boolean;
  var ARenderResult: TGameTreePdnRenderResult; ABaseOffset: Integer;
  AIncludeSiblings: Boolean = False): string; forward;

function RenderChildVariations(AGameTree: TGameTree; ANode, AContinuation: TGameTreePlyNode;
  const AOptions: TGameTreePdnRenderOptions; ACompact: Boolean;
  var ARenderResult: TGameTreePdnRenderResult; ABaseOffset: Integer;
  ABasePlyFilter: Integer = -1): string;
var
  I: Integer;
  LBasePlyNumber: Integer;
  LChild: TGameTreePlyNode;
  LLineOffset: Integer;
  LText: string;
  LVariationPlyNumber: Integer;
begin
  Result := '';
  if ANode = nil then
    Exit;

  for I := 0 to ANode.ChildCount - 1 do
  begin
    LChild := ANode.Children[I];
    if (LChild = nil) or (LChild = AContinuation) then
      Continue;
    if (ABasePlyFilter >= 0) and (ANode.PlyNumber <> ABasePlyFilter) then
      Continue;
    if NodeIsAnnotatorAlternative(ANode, LChild) and
      (not AOptions.ShowAnnotatorPVMove) and
      (not AOptions.ShowAnnotatorFullPV) then
      Continue;
    LLineOffset := ABaseOffset + Length(Result);
    if Result <> '' then
      Inc(LLineOffset);
    Inc(LLineOffset);
    LText := RenderVariationLine(AGameTree, LChild, ANode, AOptions, ACompact,
      ARenderResult, LLineOffset);
    if LText = '' then
      Continue;
    LBasePlyNumber := ANode.PlyNumber;
    LVariationPlyNumber := 1;
    begin
      AddNodeHit(ARenderResult, LChild.NodeId, True);
      AddInt(ARenderResult.VariationStarts, LLineOffset - 1);
      AddInt(ARenderResult.VariationLengths, Pos(LChild.MoveText, LText));

      AddInt(ARenderResult.VariationPlies, LVariationPlyNumber - 1);
      AddInt(ARenderResult.VariationBasePlies, LBasePlyNumber);
      AddString(ARenderResult.VariationMovesTexts, '');
    end;
    if Result <> '' then
      Result += ' ';
    Result += '(' + LText + ')';
  end;
end;

function RenderVariationLine(AGameTree: TGameTree; ANode, APreviousPosition: TGameTreePlyNode;
  const AOptions: TGameTreePdnRenderOptions; ACompact: Boolean;
  var ARenderResult: TGameTreePdnRenderResult; ABaseOffset: Integer;
  AIncludeSiblings: Boolean): string;
var
  LBasePlyNumber: Integer;
  LContinuation: TGameTreePlyNode;
  LMoveStart: Integer;
  LNested: string;
  LVariationPlyNumber: Integer;
begin
  Result := '';
  if ANode = nil then
    Exit;

  LContinuation := FindContinuationChild(ANode);
  if APreviousPosition <> nil then
    if NodeIsAnnotatorAlternative(APreviousPosition, ANode) and
      (not AOptions.ShowAnnotatorFullPV) then
      LContinuation := nil;

  Result := NodeMoveCaption(AGameTree, ANode, True, ACompact) +
    NodeAnnotation(ANode, AOptions);
  if APreviousPosition <> nil then
    if NodeIsAnnotatorAlternative(APreviousPosition, ANode) and
      AOptions.ShowAnnotatorScore and (not AOptions.HideAnnotations) and
      (Trim(APreviousPosition.AnnotatorScore) <> '') and
      (Trim(ANode.AnnotatorScore) = '') then
      Result += ' {A: ' + Trim(APreviousPosition.AnnotatorScore) + '}';

  LBasePlyNumber := APreviousPosition.PlyNumber;
  LVariationPlyNumber := 1;
  begin
    LMoveStart := Pos(ANode.MoveText, Result);
    if LMoveStart > 0 then
    begin
      AddNodeHit(ARenderResult, ANode.NodeId, False);
      AddInt(ARenderResult.VariationStarts, ABaseOffset + LMoveStart - 1);
      AddInt(ARenderResult.VariationLengths, Length(ANode.MoveText));

      AddInt(ARenderResult.VariationPlies, LVariationPlyNumber);
      AddInt(ARenderResult.VariationBasePlies, LBasePlyNumber);
      AddString(ARenderResult.VariationMovesTexts, '');
    end;
  end;

  // PDN alternatives follow the move they replace, at its parent position.
  if AIncludeSiblings then
  begin
    LNested := RenderChildVariations(AGameTree, APreviousPosition, ANode, AOptions,
      ACompact, ARenderResult, ABaseOffset + Length(Result) + 1);
    if LNested <> '' then
      Result += ' ' + LNested;
  end;
  if LContinuation <> nil then
  begin
    if Result <> '' then
      Result += ' ';
    Result += RenderVariationLine(AGameTree, LContinuation, ANode, AOptions,
      ACompact, ARenderResult, ABaseOffset + Length(Result), True);
  end;
end;

function RenderMainline(AGameTree: TGameTree; const AResultText: string;
  const AOptions: TGameTreePdnRenderOptions; ACompact: Boolean;
  var ARenderResult: TGameTreePdnRenderResult): string;
var
  I: Integer;
  LChild: TGameTreePlyNode;
  LMoveStart: Integer;
  LNested: string;
  LPreviousPosition: TGameTreePlyNode;
  LResultText: string;
  LSegment: string;
  LRootVariationRendered: Boolean;

  procedure AppendAnalysisVariation(ABaseNode: TGameTreePlyNode;
    const APv, AScore, AScorePrefix: string; AShowMove, AShowFull,
    AShowScore: Boolean);
  var
    LBaseOffset: Integer;
    LVariationText: string;
  begin
    if (not AShowMove) and (not AShowFull) then
      Exit;
    if Result = '' then
      LBaseOffset := 0
    else
      LBaseOffset := Length(Result) + 1;
    LVariationText := RenderAnalysisVariation(ABaseNode, APv, AScore,
      AScorePrefix, AShowFull, AShowScore, AOptions, ACompact,
      ARenderResult, LBaseOffset);
    if LVariationText = '' then
      Exit;
    if Result <> '' then
      Result += ' ';
    Result += LVariationText;
  end;
begin
  Result := '';
  LRootVariationRendered := False;
  if (AGameTree = nil) or (AGameTree.Root = nil) then
    Exit;

  Result := Trim(NodeAnnotation(AGameTree.Root, AOptions));
  for I := 1 to AGameTree.MainlineCount do
  begin
    LChild := AGameTree.MainlineNode[I];
    if LChild = nil then
      Continue;

    if Result <> '' then
      Result += ' ';
    LPreviousPosition := AGameTree.Root;
    if LChild.PlyNumber > 1 then
      LPreviousPosition := AGameTree.MainlineNode[LChild.PlyNumber - 1];
    LSegment := NodeMoveCaption(AGameTree, LChild, Result = '', ACompact) +
      NodeAnnotation(LChild, AOptions) +
      PreviousPositionAnnotation(LPreviousPosition, LChild, AOptions);
    LMoveStart := Pos(LChild.MoveText, LSegment);
    if LMoveStart > 0 then
    begin
      AddInt(ARenderResult.MoveStarts, Length(Result) + LMoveStart - 1);
      AddInt(ARenderResult.MoveLengths, Length(LChild.MoveText));
    end;
    Result += LSegment;
    LNested := RenderChildVariations(AGameTree, LPreviousPosition, LChild, AOptions, ACompact,
      ARenderResult, Length(Result) + 1);
    if LNested <> '' then
      Result += ' ' + LNested;
    if (not LRootVariationRendered) and (LPreviousPosition = AGameTree.Root) then
    begin
      AppendAnalysisVariation(AGameTree.Root, AGameTree.Root.EnginePV,
        AGameTree.Root.EngineScore, 'E', AOptions.ShowEnginePVMove,
        AOptions.ShowEngineFullPV, AOptions.ShowEngineScore);
      AppendAnalysisVariation(AGameTree.Root, AGameTree.Root.AnnotatorPV,
        AGameTree.Root.AnnotatorScore, 'A', AOptions.ShowAnnotatorPVMove,
        AOptions.ShowAnnotatorFullPV, AOptions.ShowAnnotatorScore);
      AppendAnalysisVariation(AGameTree.Root, AGameTree.Root.AutoPlayPV,
        '', '', True, True, False);
      LRootVariationRendered := True;
    end;
    AppendAnalysisVariation(LChild, LChild.EnginePV, LChild.EngineScore, 'E',
      AOptions.ShowEnginePVMove, AOptions.ShowEngineFullPV,
      AOptions.ShowEngineScore);
    AppendAnalysisVariation(LChild, LChild.AnnotatorPV, LChild.AnnotatorScore,
      'A', AOptions.ShowAnnotatorPVMove, AOptions.ShowAnnotatorFullPV,
      AOptions.ShowAnnotatorScore);
    AppendAnalysisVariation(LChild, LChild.AutoPlayPV, '', '', True, True,
      False);
  end;

  if AGameTree.MainlineCount = 0 then
    LChild := AGameTree.Root
  else
    LChild := AGameTree.MainlineNode[AGameTree.MainlineCount];
  LNested := RenderChildVariations(AGameTree, LChild, nil, AOptions, ACompact,
    ARenderResult, Length(Result) + 1, AGameTree.MainlineCount);
  if LNested <> '' then
  begin
    if Result <> '' then
      Result += ' ';
    Result += LNested;
  end;

  if not LRootVariationRendered then
  begin
    AppendAnalysisVariation(AGameTree.Root, AGameTree.Root.EnginePV,
      AGameTree.Root.EngineScore, 'E', AOptions.ShowEnginePVMove,
      AOptions.ShowEngineFullPV, AOptions.ShowEngineScore);
    AppendAnalysisVariation(AGameTree.Root, AGameTree.Root.AnnotatorPV,
      AGameTree.Root.AnnotatorScore, 'A', AOptions.ShowAnnotatorPVMove,
      AOptions.ShowAnnotatorFullPV, AOptions.ShowAnnotatorScore);
    AppendAnalysisVariation(AGameTree.Root, AGameTree.Root.AutoPlayPV,
      '', '', True, True, False);
  end;

  LResultText := PdnExportResult(AResultText);
  if LResultText <> '*' then
  begin
    if Result <> '' then
      Result += ' ';
    Result += LResultText;
  end;
end;

function GameTreeToPdnTextEx(AGameTree: TGameTree;
  const AOptions: TGameTreePdnRenderOptions; const AEventName: string): string;
var
  Lines: TStringList;
  RenderResult: TGameTreePdnRenderResult;
begin
  Result := '';
  if AGameTree = nil then
    Exit;

  Lines := TStringList.Create;
  try
    if Trim(AEventName) <> '' then
      Lines.Add('[Event "' + PdnQuote(AEventName) + '"]')
    else
      Lines.Add('[Event "' + PdnQuote(AGameTree.EventName) + '"]');
    Lines.Add('[White "' + PdnQuote(AGameTree.WhiteName) + '"]');
    Lines.Add('[Black "' + PdnQuote(AGameTree.BlackName) + '"]');
    Lines.Add('[Result "' + PdnQuote(PdnExportResult(AGameTree.ResultText)) + '"]');
    if AGameTree.StartingFEN <> DefaultStartingFEN then Lines.Add('[SetUp "1"]');
    Lines.Add('[FEN "' + PdnQuote(AGameTree.StartingFEN) + '"]');
    Lines.Add('');
    ClearRenderResult(RenderResult);
    Lines.Text := Lines.Text + RenderMainline(AGameTree, AGameTree.ResultText,
      AOptions, False, RenderResult);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

function GameTreeToPdnText(AGameTree: TGameTree): string;
begin
  Result := GameTreeToPdnTextEx(AGameTree, DefaultGameTreePdnRenderOptions);
end;

procedure RenderGameTreeMovesToPdn(AGameTree: TGameTree;
  const AOptions: TGameTreePdnRenderOptions;
  out ARenderResult: TGameTreePdnRenderResult);
begin
  ClearRenderResult(ARenderResult);
  if AGameTree = nil then
  begin
    ARenderResult.Text := '(none)';
    Exit;
  end;
  ARenderResult.Text := RenderMainline(AGameTree, AGameTree.ResultText,
    AOptions, True, ARenderResult);
  if Trim(ARenderResult.Text) = '' then
    ARenderResult.Text := '(none)';
end;

function ScoreAnnotationLine(const AEngineScore, AAnnotatorScore: string): string;
begin
  Result := '';
  if Trim(AEngineScore) <> '' then
    Result := 'E: ' + Trim(AEngineScore);
  if Trim(AAnnotatorScore) <> '' then
  begin
    if Result <> '' then
      Result += '; ';
    Result += 'A: ' + Trim(AAnnotatorScore);
  end;
end;

function GameTreeScoreAnnotationsText(AGameTree: TGameTree): string;
var
  I: Integer;
  LAnnotatorScore: string;
  LLine: string;
  LNode: TGameTreePlyNode;
  Lines: TStringList;
begin
  Result := '';
  if AGameTree = nil then
    Exit;

  Lines := TStringList.Create;
  try
    I := 1;
    while AGameTree.MainlineNode[I] <> nil do
    begin
      LNode := AGameTree.MainlineNode[I];
      LAnnotatorScore := LNode.AnnotatorScore;
      LLine := ScoreAnnotationLine(LNode.EngineScore, LAnnotatorScore);
      Lines.Add(LLine);
      Inc(I);
    end;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
