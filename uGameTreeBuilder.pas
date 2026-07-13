unit uGameTreeBuilder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uGameOrchestrator, uGameTree;

type
  TGameTreeVariationPlyCallback = procedure(AGameTree: TGameTree;
    AVariation: TGameTreeVariationLine; AVariationIndex,
    AVariationPly: Integer) of object;
  TGameTreePvInput = record
    RecordPV: Boolean;
    BasePly: Integer;
    Score: string;
    PV: string;
    Depth: string;
    TimeText: string;
  end;
  TGameTreeHeaderInput = record
    Signature: string;
    EventName: string;
    WhiteName: string;
    BlackName: string;
    ResultText: string;
    StartingFEN: string;
    StatusText: string;
    GameState: TGameOrchestratorState;
    RecordTimeControl: Boolean;
    TimeControl: TTimeControl;
  end;
  TGameTreeMainlineInput = record
    Moves: TStrings;
    Annotations: TStrings;
    RecordClock: Boolean;
    WhiteRemainingSeconds: Double;
    BlackRemainingSeconds: Double;
    WhiteUsedSeconds: Double;
    BlackUsedSeconds: Double;
  end;
  TGameTreeVariationLineInput = record
    Variation: TGameTreeVariationLine;
    VariationIndex: Integer;
    Moves: TStrings;
    BeforeMove: TGameTreeVariationPlyCallback;
  end;
  TGameTreeVariationPvInput = record
    Variation: TGameTreeVariationLine;
    VariationIndex: Integer;
    VariationPly: Integer;
    Score: string;
    PV: string;
    Depth: string;
    TimeText: string;
  end;

procedure TextToMoveList(const AMovesText: string; AMoves: TStrings);
function GameTreePvInput(ARecordPV: Boolean; ABasePly: Integer;
  const AScore, APV: string; const ADepth: string = '';
  const ATimeText: string = ''): TGameTreePvInput;
function GameTreeHeaderInput(const ASignature, AEventName, AWhiteName,
  ABlackName, AResultText, AStartingFEN: string; ARecordTimeControl: Boolean;
  const ATimeControl: TTimeControl;
  AGameState: TGameOrchestratorState = gosWaiting;
  const AStatusText: string = ''): TGameTreeHeaderInput;
function GameTreeMainlineInput(AMoves, AAnnotations: TStrings;
  ARecordClock: Boolean; AWhiteRemainingSeconds, ABlackRemainingSeconds,
  AWhiteUsedSeconds, ABlackUsedSeconds: Double): TGameTreeMainlineInput;
function GameTreeVariationLineInput(AVariation: TGameTreeVariationLine;
  AVariationIndex: Integer; AMoves: TStrings;
  ABeforeMove: TGameTreeVariationPlyCallback): TGameTreeVariationLineInput;
function GameTreeVariationPvInput(AVariation: TGameTreeVariationLine;
  AVariationIndex, AVariationPly: Integer; const AScore,
  APV: string; const ADepth: string = '';
  const ATimeText: string = ''): TGameTreeVariationPvInput;
procedure BeginGameTreeRebuild(AGameTree: TGameTree;
  const AHeader: TGameTreeHeaderInput);
procedure RecordGameTreeMainline(AGameTree: TGameTree;
  const AMainline: TGameTreeMainlineInput);
procedure RecordGameTreeAnalysis(AGameTree: TGameTree;
  const AEnginePV, AAnnotatorPV: TGameTreePvInput);
procedure RecordGameTreeVariationLine(AGameTree: TGameTree;
  const AVariationLine: TGameTreeVariationLineInput);
procedure RecordGameTreeVariationAnnotatorPV(AGameTree: TGameTree;
  const AVariationPV: TGameTreeVariationPvInput);

implementation

procedure TextToMoveList(const AMovesText: string; AMoves: TStrings);
begin
  if AMoves = nil then
    Exit;
  AMoves.Clear;
  ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)), AMoves);
end;

function GameTreePvInput(ARecordPV: Boolean; ABasePly: Integer;
  const AScore, APV: string; const ADepth: string; const ATimeText: string
  ): TGameTreePvInput;
begin
  Result.RecordPV := ARecordPV;
  Result.BasePly := ABasePly;
  Result.Score := AScore;
  Result.PV := APV;
  Result.Depth := ADepth;
  Result.TimeText := ATimeText;
end;

function GameTreeHeaderInput(const ASignature, AEventName, AWhiteName,
  ABlackName, AResultText, AStartingFEN: string; ARecordTimeControl: Boolean;
  const ATimeControl: TTimeControl;
  AGameState: TGameOrchestratorState;
  const AStatusText: string): TGameTreeHeaderInput;
begin
  Result.Signature := ASignature;
  Result.EventName := AEventName;
  Result.WhiteName := AWhiteName;
  Result.BlackName := ABlackName;
  Result.ResultText := AResultText;
  Result.StartingFEN := AStartingFEN;
  Result.StatusText := AStatusText;
  Result.GameState := AGameState;
  Result.RecordTimeControl := ARecordTimeControl;
  Result.TimeControl := ATimeControl;
end;

function GameTreeMainlineInput(AMoves, AAnnotations: TStrings;
  ARecordClock: Boolean; AWhiteRemainingSeconds, ABlackRemainingSeconds,
  AWhiteUsedSeconds, ABlackUsedSeconds: Double): TGameTreeMainlineInput;
begin
  Result.Moves := AMoves;
  Result.Annotations := AAnnotations;
  Result.RecordClock := ARecordClock;
  Result.WhiteRemainingSeconds := AWhiteRemainingSeconds;
  Result.BlackRemainingSeconds := ABlackRemainingSeconds;
  Result.WhiteUsedSeconds := AWhiteUsedSeconds;
  Result.BlackUsedSeconds := ABlackUsedSeconds;
end;

function GameTreeVariationLineInput(AVariation: TGameTreeVariationLine;
  AVariationIndex: Integer; AMoves: TStrings;
  ABeforeMove: TGameTreeVariationPlyCallback): TGameTreeVariationLineInput;
begin
  Result.Variation := AVariation;
  Result.VariationIndex := AVariationIndex;
  Result.Moves := AMoves;
  Result.BeforeMove := ABeforeMove;
end;

function GameTreeVariationPvInput(AVariation: TGameTreeVariationLine;
  AVariationIndex, AVariationPly: Integer; const AScore,
  APV: string; const ADepth: string; const ATimeText: string
  ): TGameTreeVariationPvInput;
begin
  Result.Variation := AVariation;
  Result.VariationIndex := AVariationIndex;
  Result.VariationPly := AVariationPly;
  Result.Score := AScore;
  Result.PV := APV;
  Result.Depth := ADepth;
  Result.TimeText := ATimeText;
end;

procedure BeginGameTreeRebuild(AGameTree: TGameTree;
  const AHeader: TGameTreeHeaderInput);
var
  Changed: Boolean;
begin
  if AGameTree = nil then
    Exit;

  AGameTree.BeginRebuild(AHeader.Signature, AHeader.EventName,
    AHeader.WhiteName, AHeader.BlackName, AHeader.ResultText,
    AHeader.StartingFEN);
  AGameTree.SetStatusText(AHeader.StatusText, Changed);
  AGameTree.SetGameState(AHeader.GameState, Changed);
  if AHeader.RecordTimeControl then
    AGameTree.RecordTimeControl(AHeader.TimeControl);
end;

procedure RecordGameTreeMainline(AGameTree: TGameTree;
  const AMainline: TGameTreeMainlineInput);
var
  I: Integer;
  LNode: TGameTreePlyNode;
  LMoveCount: Integer;
begin
  if AGameTree = nil then
    Exit;

  if AMainline.Moves <> nil then
  begin
    for I := 0 to AMainline.Moves.Count - 1 do
    begin
      LNode := AGameTree.RecordMainlineMove(I + 1, AMainline.Moves[I]);
      if LNode = nil then
        Continue;
      if (AMainline.Annotations <> nil) and
        (I < AMainline.Annotations.Count) then
        AGameTree.RecordMainlineAnnotation(I + 1, AMainline.Annotations[I]);
    end;
    AGameTree.TrimMainlineToCount(AMainline.Moves.Count);
  end;

  if AMainline.Moves <> nil then
    LMoveCount := AMainline.Moves.Count
  else
    LMoveCount := AGameTree.MainlineCount;
  if AMainline.RecordClock then
    AGameTree.RecordClockState(LMoveCount,
      AMainline.WhiteRemainingSeconds, AMainline.BlackRemainingSeconds,
      AMainline.WhiteUsedSeconds, AMainline.BlackUsedSeconds);
end;

procedure RecordGameTreeAnalysis(AGameTree: TGameTree;
  const AEnginePV, AAnnotatorPV: TGameTreePvInput);
begin
  if AGameTree = nil then
    Exit;

  if AEnginePV.RecordPV and (Trim(AEnginePV.PV) <> '') then
    AGameTree.RecordEnginePV(AEnginePV.BasePly, AEnginePV.Score,
      AEnginePV.PV, AEnginePV.Depth, AEnginePV.TimeText);
  if AAnnotatorPV.RecordPV and (Trim(AAnnotatorPV.PV) <> '') then
    AGameTree.RecordAnnotatorPV(AAnnotatorPV.BasePly, AAnnotatorPV.Score,
      AAnnotatorPV.PV, AAnnotatorPV.Depth, AAnnotatorPV.TimeText);
end;

procedure RecordGameTreeVariationLine(AGameTree: TGameTree;
  const AVariationLine: TGameTreeVariationLineInput);
var
  I: Integer;
  LParentNode: TGameTreePlyNode;
  LVariationNode: TGameTreePlyNode;
begin
  if (AGameTree = nil) or (AVariationLine.Variation = nil) or
    (AVariationLine.Moves = nil) then
    Exit;
  if AVariationLine.Moves.Count = 0 then
    Exit;

  if AVariationLine.Variation.DisplayAfterPly <= 0 then
    LParentNode := AGameTree.Root
  else
    LParentNode := AGameTree.MainlineNode[
      AVariationLine.Variation.DisplayAfterPly];
  if LParentNode = nil then
    Exit;

  LVariationNode := nil;
  for I := 0 to AVariationLine.Moves.Count - 1 do
  begin
    if Assigned(AVariationLine.BeforeMove) then
      AVariationLine.BeforeMove(AGameTree, AVariationLine.Variation,
        AVariationLine.VariationIndex, I + 1);
    LVariationNode := AGameTree.RecordVariationMove(LParentNode,
      AVariationLine.Variation.BasePly,
      AVariationLine.Variation.DisplayAfterPly,
      AVariationLine.VariationIndex, I + 1, AVariationLine.Moves[I]);
    LParentNode := LVariationNode;
  end;
  AGameTree.TrimVariationLine(AVariationLine.Variation.BasePly,
    AVariationLine.Variation.DisplayAfterPly,
    AVariationLine.VariationIndex, AVariationLine.Moves.Count);

  if LVariationNode <> nil then
    AGameTree.RecordVariationAnnotation(AVariationLine.Variation.BasePly,
      AVariationLine.Variation.DisplayAfterPly,
      AVariationLine.VariationIndex, AVariationLine.Moves.Count,
      AVariationLine.Variation.AnnotationText);
end;

procedure RecordGameTreeVariationAnnotatorPV(AGameTree: TGameTree;
  const AVariationPV: TGameTreeVariationPvInput);
begin
  if (AGameTree = nil) or (AVariationPV.Variation = nil) or
    (Trim(AVariationPV.PV) = '') then
    Exit;

  AGameTree.RecordVariationAnnotatorPV(AVariationPV.Variation.BasePly,
    AVariationPV.Variation.DisplayAfterPly, AVariationPV.VariationIndex,
    AVariationPV.VariationPly, AVariationPV.Score, AVariationPV.PV,
    AVariationPV.Depth, AVariationPV.TimeText);
end;

end.
