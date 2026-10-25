unit uGameTreeBuilder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uGameMoveHistory, uGameOrchestrator, uGameTree;

type
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
    InitialCommentText: string;
    GameState: TGameOrchestratorState;
    RecordTimeControl: Boolean;
    TimeControl: TTimeControl;
  end;
  TGameTreeMainlineInput = record
    Moves: TStrings;
    Annotations: TStrings;
    RecordClock: Boolean;
    MoveData: TGameMoveDataArray;
    WhiteRemainingSeconds: Double;
    BlackRemainingSeconds: Double;
    WhiteUsedSeconds: Double;
    BlackUsedSeconds: Double;
  end;

procedure TextToMoveList(const AMovesText: string; AMoves: TStrings);
function GameTreePvInput(ARecordPV: Boolean; ABasePly: Integer;
  const AScore, APV: string; const ADepth: string = '';
  const ATimeText: string = ''): TGameTreePvInput;
function GameTreeHeaderInput(const ASignature, AEventName, AWhiteName,
  ABlackName, AResultText, AStartingFEN: string; ARecordTimeControl: Boolean;
  const ATimeControl: TTimeControl;
  AGameState: TGameOrchestratorState = gosWaiting;
  const AStatusText: string = '';
  const AInitialCommentText: string = ''): TGameTreeHeaderInput;
function GameTreeMainlineInput(AMoves, AAnnotations: TStrings;
  ARecordClock: Boolean; AWhiteRemainingSeconds, ABlackRemainingSeconds,
  AWhiteUsedSeconds, ABlackUsedSeconds: Double): TGameTreeMainlineInput;
procedure BeginGameTreeRebuild(AGameTree: TGameTree;
  const AHeader: TGameTreeHeaderInput);
procedure RecordGameTreeMainline(AGameTree: TGameTree;
  const AMainline: TGameTreeMainlineInput);
function RecordGameTreeCompletedMoves(AGameTree: TGameTree;
  const AMoves: TGameMoveDataArray): Boolean;
procedure RecordGameTreeAnalysis(AGameTree: TGameTree;
  const AEnginePV, AAnnotatorPV: TGameTreePvInput);
implementation

uses uPdn, uDraughtsBoard;

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
  const AStatusText: string; const AInitialCommentText: string): TGameTreeHeaderInput;
begin
  Result.Signature := ASignature;
  Result.EventName := AEventName;
  Result.WhiteName := AWhiteName;
  Result.BlackName := ABlackName;
  Result.ResultText := AResultText;
  Result.StartingFEN := AStartingFEN;
  Result.StatusText := AStatusText;
  Result.InitialCommentText := AInitialCommentText;
  Result.GameState := AGameState;
  Result.RecordTimeControl := ARecordTimeControl;
  Result.TimeControl := ATimeControl;
end;

function GameTreeMainlineInput(AMoves, AAnnotations: TStrings;
  ARecordClock: Boolean; AWhiteRemainingSeconds, ABlackRemainingSeconds,
  AWhiteUsedSeconds, ABlackUsedSeconds: Double): TGameTreeMainlineInput;
begin
  Result.MoveData := nil;
  Result.Moves := AMoves;
  Result.Annotations := AAnnotations;
  Result.RecordClock := ARecordClock;
  Result.WhiteRemainingSeconds := AWhiteRemainingSeconds;
  Result.BlackRemainingSeconds := ABlackRemainingSeconds;
  Result.WhiteUsedSeconds := AWhiteUsedSeconds;
  Result.BlackUsedSeconds := ABlackUsedSeconds;
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
  AGameTree.RecordMainlineAnnotation(0, AHeader.InitialCommentText);
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
  RecordGameTreeCompletedMoves(AGameTree, AMainline.MoveData);
end;

function RecordGameTreeCompletedMoves(AGameTree: TGameTree;
  const AMoves: TGameMoveDataArray): Boolean;
var
  I: Integer;
begin
  Result := False;
  if AGameTree = nil then Exit;
  for I := 0 to Length(AMoves) - 1 do
  begin
    if I >= AGameTree.MainlineCount then Break;
    if NormalizeMoveNotation(AGameTree.MainlineNode[I + 1].MoveText) <>
      NormalizeMoveNotation(AMoves[I].MoveText) then Break;
    if AGameTree.RecordCompletedMoveData(I + 1, AMoves[I]) then Result := True;
  end;
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

end.
