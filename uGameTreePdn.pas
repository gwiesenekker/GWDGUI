unit uGameTreePdn;

{$mode objfpc}{$H+}

interface

uses
  Classes, StrUtils, SysUtils, uDraughtsBoard, uGameTree;

type
  TGameTreePdnIntArray = array of Integer;
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
    VariationLengths: TGameTreePdnIntArray;
    VariationIndexes: TGameTreePdnIntArray;
    VariationPlies: TGameTreePdnIntArray;
    VariationBasePlies: TGameTreePdnIntArray;
    VariationMovesTexts: TGameTreePdnStringArray;
  end;

function DefaultGameTreePdnRenderOptions: TGameTreePdnRenderOptions;
function GameTreeToPdnText(AGameTree: TGameTree): string;
function GameTreeToPdnTextEx(AGameTree: TGameTree;
  const AOptions: TGameTreePdnRenderOptions): string;
procedure RenderGameTreeMovesToPdn(AGameTree: TGameTree;
  const AOptions: TGameTreePdnRenderOptions;
  out ARenderResult: TGameTreePdnRenderResult);
function GameTreeScoreAnnotationsText(AGameTree: TGameTree): string;

implementation

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
  else if not SameText(Result, '*') then
    Result := '*';
end;

function VariationPrefix(const AVariationKey: string): string;
var
  LPos: Integer;
begin
  Result := Trim(AVariationKey);
  LPos := RPos(':', Result);
  if LPos > 0 then
    Result := Copy(Result, 1, LPos - 1);
end;

function NodeMoveCaption(ANode: TGameTreePlyNode; AForceMoveNumber: Boolean;
  ACompact: Boolean): string;
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
  Result += ANode.MoveText;
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
    Result := ' {' + Result + '}';
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
        AddInt(ARenderResult.VariationStarts,
          ABaseOffset + 1 + LSegmentOffset + LMoveStart - 1);
        AddInt(ARenderResult.VariationLengths, Length(LMoves[I]));
        AddInt(ARenderResult.VariationIndexes, -1);
        AddInt(ARenderResult.VariationPlies, I + 1);
        AddInt(ARenderResult.VariationBasePlies, ABaseNode.PlyNumber);
        AddString(ARenderResult.VariationMovesTexts, Trim(APv));
      end;
      LSide := SideForNextPly(LSide);
    end;
    if Result <> '' then
    begin
      Result := '(' + Result + ')';
      AddInt(ARenderResult.VariationStarts, ABaseOffset);
      AddInt(ARenderResult.VariationLengths,
        Pos(LMoves[0], Result) - 1);
      AddInt(ARenderResult.VariationIndexes, -1);
      AddInt(ARenderResult.VariationPlies, 0);
      AddInt(ARenderResult.VariationBasePlies, ABaseNode.PlyNumber);
      AddString(ARenderResult.VariationMovesTexts, Trim(APv));
    end;
  finally
    LMoves.Free;
  end;
end;

function SameVariationLine(AParent, AChild: TGameTreePlyNode): Boolean;
begin
  Result := (AParent <> nil) and (AChild <> nil) and
    (Trim(AParent.VariationKey) <> '') and
    (VariationPrefix(AParent.VariationKey) = VariationPrefix(AChild.VariationKey));
end;

function FindContinuationChild(ANode: TGameTreePlyNode): TGameTreePlyNode;
var
  I: Integer;
begin
  Result := nil;
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
    if SameVariationLine(ANode, ANode.Children[I]) then
      Exit(ANode.Children[I]);
end;

procedure ParseVariationKey(const AVariationKey: string; out ABasePlyNumber,
  ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer);
var
  Parts: TStringList;
begin
  ABasePlyNumber := -1;
  ADisplayAfterPly := -1;
  AVariationIndex := -1;
  AVariationPlyNumber := -1;
  Parts := TStringList.Create;
  try
    ExtractStrings([':'], [], PChar(Trim(AVariationKey)), Parts);
    if Parts.Count >= 4 then
    begin
      ABasePlyNumber := StrToIntDef(Parts[0], -1);
      ADisplayAfterPly := StrToIntDef(Parts[1], -1);
      AVariationIndex := StrToIntDef(Parts[2], -1);
      AVariationPlyNumber := StrToIntDef(Parts[3], -1);
    end;
  finally
    Parts.Free;
  end;
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

procedure ClearRenderResult(out ARenderResult: TGameTreePdnRenderResult);
begin
  ARenderResult.Text := '';
  SetLength(ARenderResult.MoveStarts, 0);
  SetLength(ARenderResult.MoveLengths, 0);
  SetLength(ARenderResult.VariationStarts, 0);
  SetLength(ARenderResult.VariationLengths, 0);
  SetLength(ARenderResult.VariationIndexes, 0);
  SetLength(ARenderResult.VariationPlies, 0);
  SetLength(ARenderResult.VariationBasePlies, 0);
  SetLength(ARenderResult.VariationMovesTexts, 0);
end;

function RenderVariationLine(ANode, APreviousPosition: TGameTreePlyNode;
  const AOptions: TGameTreePdnRenderOptions; ACompact: Boolean;
  var ARenderResult: TGameTreePdnRenderResult; ABaseOffset: Integer): string; forward;

function RenderChildVariations(ANode, AContinuation: TGameTreePlyNode;
  const AOptions: TGameTreePdnRenderOptions; ACompact: Boolean;
  var ARenderResult: TGameTreePdnRenderResult; ABaseOffset: Integer): string;
var
  I: Integer;
  LBasePlyNumber: Integer;
  LChild: TGameTreePlyNode;
  LDisplayAfterPly: Integer;
  LLineOffset: Integer;
  LText: string;
  LVariationIndex: Integer;
  LVariationPlyNumber: Integer;
begin
  Result := '';
  if ANode = nil then
    Exit;

  for I := 0 to ANode.ChildCount - 1 do
  begin
    LChild := ANode.Children[I];
    if (LChild = nil) or (LChild = AContinuation) or
      (Trim(LChild.VariationKey) = '') then
      Continue;
    if NodeIsAnnotatorAlternative(ANode, LChild) and
      (not AOptions.ShowAnnotatorPVMove) and
      (not AOptions.ShowAnnotatorFullPV) then
      Continue;
    LLineOffset := ABaseOffset + Length(Result);
    if Result <> '' then
      Inc(LLineOffset);
    Inc(LLineOffset);
    LText := RenderVariationLine(LChild, ANode, AOptions, ACompact,
      ARenderResult, LLineOffset);
    if LText = '' then
      Continue;
    ParseVariationKey(LChild.VariationKey, LBasePlyNumber,
      LDisplayAfterPly, LVariationIndex, LVariationPlyNumber);
    if LVariationIndex >= 0 then
    begin
      AddInt(ARenderResult.VariationStarts, LLineOffset - 1);
      AddInt(ARenderResult.VariationLengths, Pos(LChild.MoveText, LText));
      AddInt(ARenderResult.VariationIndexes, LVariationIndex);
      AddInt(ARenderResult.VariationPlies, 0);
      AddInt(ARenderResult.VariationBasePlies, LBasePlyNumber);
      AddString(ARenderResult.VariationMovesTexts, '');
    end;
    if Result <> '' then
      Result += ' ';
    Result += '(' + LText + ')';
  end;
end;

function RenderVariationLine(ANode, APreviousPosition: TGameTreePlyNode;
  const AOptions: TGameTreePdnRenderOptions; ACompact: Boolean;
  var ARenderResult: TGameTreePdnRenderResult; ABaseOffset: Integer): string;
var
  LBasePlyNumber: Integer;
  LContinuation: TGameTreePlyNode;
  LDisplayAfterPly: Integer;
  LMoveStart: Integer;
  LNested: string;
  LVariationIndex: Integer;
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

  Result := NodeMoveCaption(ANode, True, ACompact) +
    NodeAnnotation(ANode, AOptions);
  if APreviousPosition <> nil then
    if NodeIsAnnotatorAlternative(APreviousPosition, ANode) and
      AOptions.ShowAnnotatorScore and (not AOptions.HideAnnotations) and
      (Trim(APreviousPosition.AnnotatorScore) <> '') and
      (Trim(ANode.AnnotatorScore) = '') then
      Result += ' {A: ' + Trim(APreviousPosition.AnnotatorScore) + '}';

  ParseVariationKey(ANode.VariationKey, LBasePlyNumber, LDisplayAfterPly,
    LVariationIndex, LVariationPlyNumber);
  if (LVariationIndex >= 0) and (LVariationPlyNumber > 0) then
  begin
    LMoveStart := Pos(ANode.MoveText, Result);
    if LMoveStart > 0 then
    begin
      AddInt(ARenderResult.VariationStarts, ABaseOffset + LMoveStart - 1);
      AddInt(ARenderResult.VariationLengths, Length(ANode.MoveText));
      AddInt(ARenderResult.VariationIndexes, LVariationIndex);
      AddInt(ARenderResult.VariationPlies, LVariationPlyNumber);
      AddInt(ARenderResult.VariationBasePlies, LBasePlyNumber);
      AddString(ARenderResult.VariationMovesTexts, '');
    end;
  end;

  LNested := RenderChildVariations(ANode, LContinuation, AOptions, ACompact,
    ARenderResult, ABaseOffset + Length(Result) + 1);
  if LNested <> '' then
    Result += ' ' + LNested;
  if LContinuation <> nil then
  begin
    if Result <> '' then
      Result += ' ';
    Result += RenderVariationLine(LContinuation, ANode, AOptions,
      ACompact, ARenderResult, ABaseOffset + Length(Result));
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

  Result := '';
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
    LSegment := NodeMoveCaption(LChild, Result = '', ACompact) +
      NodeAnnotation(LChild, AOptions) +
      PreviousPositionAnnotation(LPreviousPosition, LChild, AOptions);
    LMoveStart := Pos(LChild.MoveText, LSegment);
    if LMoveStart > 0 then
    begin
      AddInt(ARenderResult.MoveStarts, Length(Result) + LMoveStart - 1);
      AddInt(ARenderResult.MoveLengths, Length(LChild.MoveText));
    end;
    Result += LSegment;
    LNested := RenderChildVariations(LChild, nil, AOptions, ACompact,
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
  const AOptions: TGameTreePdnRenderOptions): string;
var
  Lines: TStringList;
  RenderResult: TGameTreePdnRenderResult;
begin
  Result := '';
  if AGameTree = nil then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.Add('[Event "' + PdnQuote(AGameTree.EventName) + '"]');
    Lines.Add('[White "' + PdnQuote(AGameTree.WhiteName) + '"]');
    Lines.Add('[Black "' + PdnQuote(AGameTree.BlackName) + '"]');
    Lines.Add('[Result "' + PdnQuote(PdnExportResult(AGameTree.ResultText)) + '"]');
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
  LPreviousNode: TGameTreePlyNode;
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
      if I = 1 then
        LPreviousNode := AGameTree.Root
      else
        LPreviousNode := AGameTree.MainlineNode[I - 1];

      LAnnotatorScore := LNode.AnnotatorScore;
      if (Trim(LAnnotatorScore) = '') and (LPreviousNode <> nil) then
        LAnnotatorScore := LPreviousNode.AnnotatorScore;

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
