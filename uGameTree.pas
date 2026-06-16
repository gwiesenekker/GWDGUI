unit uGameTree;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils, uDraughtsBoard, uGameOrchestrator;

type
  TGameTreePlyNode = class
  private
    FChildren: TObjectList;
    function GetChild(AIndex: Integer): TGameTreePlyNode;
    function GetChildCount: Integer;
  public
    Parent: TGameTreePlyNode;
    NodeId: Int64;
    PlyNumber: Integer;
    MoveNumber: Integer;
    SideToMove: TDraughtsSide;
    MoveText: string;
    EngineScore: string;
    EnginePV: string;
    EnginePVDepth: string;
    EnginePVTimeText: string;
    AnnotatorScore: string;
    AnnotatorPV: string;
    AnnotatorPVDepth: string;
    AnnotatorPVTimeText: string;
    CommentText: string;
    VariationKey: string;
    HasClockInfo: Boolean;
    WhiteRemainingSeconds: Double;
    BlackRemainingSeconds: Double;
    WhiteUsedSeconds: Double;
    BlackUsedSeconds: Double;
    constructor Create;
    destructor Destroy; override;
    function AddChild: TGameTreePlyNode;
    property ChildCount: Integer read GetChildCount;
    property Children[AIndex: Integer]: TGameTreePlyNode read GetChild;
  end;

  TGameTreeVariationLine = class
  public
    BasePly: Integer;
    DisplayAfterPly: Integer;
    MovesText: string;
    AnnotationText: string;
    OriginText: string;
  end;

  TGameTreeClockState = class
  public
    WhiteRemainingSeconds: Double;
    BlackRemainingSeconds: Double;
    WhiteUsedSeconds: Double;
    BlackUsedSeconds: Double;
  end;

  TGameTree = class
  private
    FAnnotatorPvsByPly: TStringList;
    FAnnotatorPvDepthsByPly: TStringList;
    FAnnotatorPvTimesByPly: TStringList;
    FAnnotatorScoresByPly: TStringList;
    FClockStatesByPly: TObjectList;
    FEnginePvDepthsByPly: TStringList;
    FEnginePvsByPly: TStringList;
    FEnginePvTimesByPly: TStringList;
    FEngineScoresByPly: TStringList;
    FGameTreeId: Int64;
    FVariationAnnotatorPvsByKey: TStringList;
    FVariationAnnotatorPvDepthsByKey: TStringList;
    FVariationAnnotatorPvTimesByKey: TStringList;
    FVariationAnnotatorScoresByKey: TStringList;
    FVariationEnginePvsByKey: TStringList;
    FVariationEngineScoresByKey: TStringList;
    FVariationEnginePvDepthsByKey: TStringList;
    FVariationEnginePvTimesByKey: TStringList;
    FVariationLines: TObjectList;
    FMainline: TFPList;
    FNextNodeId: Int64;
    FRoot: TGameTreePlyNode;
    FSignature: string;
    procedure ApplyAnnotationText(ANode: TGameTreePlyNode;
      const AAnnotationText: string);
    procedure ApplyStoredAnalysis(ANode: TGameTreePlyNode; APlyNumber: Integer);
    procedure ClearObservedAnalysis;
    procedure ClearStructure;
    procedure ClearTreeMetadata;
    function IncrementModeCaption(AMode: TClockIncrementMode): string;
    function SideForPly(APlyNumber: Integer): TDraughtsSide;
    function AddMove(AParent: TGameTreePlyNode; APlyNumber: Integer;
      const AMoveText: string): TGameTreePlyNode;
    function AddMainlineMove(APlyNumber: Integer;
      const AMoveText: string): TGameTreePlyNode;
    procedure AddEnginePV(APlyNumber: Integer; const AScore, APV: string;
      const ADepth: string = ''; const ATimeText: string = '');
    procedure AddAnnotatorPV(APlyNumber: Integer; const AScore, APV: string;
      const ADepth: string = ''; const ATimeText: string = '');
    function BuildVariationKey(ABasePlyNumber, ADisplayAfterPly,
      AVariationIndex, AVariationPlyNumber: Integer): string;
    function GetMainlineNode(APlyNumber: Integer): TGameTreePlyNode;
    function GetMainlineCount: Integer;
    function GetVariationLine(AIndex: Integer): TGameTreeVariationLine;
    function GetVariationLineCount: Integer;
    function GetStoredKeyValue(AList: TStringList; const AKey: string): string;
    function GetStoredValue(AList: TStringList; APlyNumber: Integer): string;
    procedure ApplyStoredClockState(ANode: TGameTreePlyNode;
      APlyNumber: Integer);
    procedure ApplyStoredVariationAnalysis(ANode: TGameTreePlyNode;
      const AVariationKey: string);
    procedure AssignNodeId(ANode: TGameTreePlyNode);
    procedure ResetNodeState(ANode: TGameTreePlyNode);
    procedure RemoveMainlineFrom(APlyNumber: Integer);
    procedure RemoveNodeFromParent(ANode: TGameTreePlyNode);
    procedure RemoveVariationNodes(ANode: TGameTreePlyNode);
    function GetStoredClockState(APlyNumber: Integer): TGameTreeClockState;
    function FindStoredVariation(ADisplayAfterPly, ABasePly: Integer;
      const AMovesText: string): Integer;
    procedure StoreKeyValue(AList: TStringList; const AKey, AValue: string);
    procedure StoreClockState(APlyNumber: Integer; AWhiteRemainingSeconds,
      ABlackRemainingSeconds, AWhiteUsedSeconds, ABlackUsedSeconds: Double);
    procedure StoreValue(AList: TStringList; APlyNumber: Integer;
      const AValue: string);
    function FindVariationNodeByKey(const AVariationKey: string): TGameTreePlyNode;
  public
    EventName: string;
    WhiteName: string;
    BlackName: string;
    ResultText: string;
    StartingFEN: string;
    StatusText: string;
    GameState: TGameOrchestratorState;
    HasTimeControl: Boolean;
    MovesPerPeriod: Integer;
    MinutesPerPeriod: Double;
    IncrementSeconds: Double;
    IncrementModeText: string;
    HasClockInfo: Boolean;
    WhiteRemainingSeconds: Double;
    BlackRemainingSeconds: Double;
    WhiteUsedSeconds: Double;
    BlackUsedSeconds: Double;
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure BeginRebuild(const ASignature, AEventName, AWhiteName,
      ABlackName, AResultText, AStartingFEN: string);
    procedure SetHeader(const AEventName, AWhiteName, ABlackName, AResultText,
      AStartingFEN: string); overload;
    procedure SetHeader(const AEventName, AWhiteName, ABlackName, AResultText,
      AStartingFEN: string; out AChanged: Boolean); overload;
    procedure SetGameState(AState: TGameOrchestratorState;
      out AChanged: Boolean);
    procedure SetTimeControl(AMovesPerPeriod: Integer; AMinutesPerPeriod,
      AIncrementSeconds: Double; const AIncrementModeText: string);
    procedure SetClockState(AWhiteRemainingSeconds, ABlackRemainingSeconds,
      AWhiteUsedSeconds, ABlackUsedSeconds: Double);
    procedure SetNodeClockState(ANode: TGameTreePlyNode;
      AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
      ABlackUsedSeconds: Double);
    procedure RecordTimeControl(AMovesPerPeriod: Integer; AMinutesPerPeriod,
      AIncrementSeconds: Double; const AIncrementModeText: string); overload;
    procedure RecordTimeControl(const ATimeControl: TTimeControl); overload;
    procedure RecordClockState(APlyNumber: Integer; AWhiteRemainingSeconds,
      ABlackRemainingSeconds, AWhiteUsedSeconds, ABlackUsedSeconds: Double);
    function RecordMainlineMove(APlyNumber: Integer;
      const AMoveText: string): TGameTreePlyNode;
    procedure RecordMainlineAnnotation(APlyNumber: Integer;
      const AAnnotationText: string);
    procedure RecordEnginePV(APlyNumber: Integer; const AScore, APV: string;
      const ADepth: string = ''; const ATimeText: string = '');
    procedure RecordAnnotatorPV(APlyNumber: Integer; const AScore, APV: string;
      const ADepth: string = ''; const ATimeText: string = '');
    function RecordVariationMove(AParent: TGameTreePlyNode; ABasePlyNumber,
      ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
      const AMoveText: string): TGameTreePlyNode;
    procedure RecordVariationEnginePV(ABasePlyNumber, ADisplayAfterPly,
      AVariationIndex, AVariationPlyNumber: Integer; const AScore,
      APV: string; const ADepth: string = ''; const ATimeText: string = '');
    procedure RecordVariationAnnotatorPV(ABasePlyNumber, ADisplayAfterPly,
      AVariationIndex, AVariationPlyNumber: Integer; const AScore,
      APV: string; const ADepth: string = ''; const ATimeText: string = '');
    function RecordAnnotatorPVForNodeId(ANodeId: Int64; const AScore,
      APV: string; const ADepth: string = '';
      const ATimeText: string = ''): Boolean; overload;
    function RecordAnnotatorPVForNodeId(ANodeId: Int64; const AScore,
      APV: string; out AChanged: Boolean): Boolean; overload;
    function RecordAnnotatorPVForNodeId(ANodeId: Int64; const AScore,
      APV, ADepth, ATimeText: string; out AChanged: Boolean): Boolean; overload;
    function RecordEnginePVForNodeId(ANodeId: Int64; const AScore,
      APV: string; const ADepth: string = '';
      const ATimeText: string = ''): Boolean; overload;
    function RecordEnginePVForNodeId(ANodeId: Int64; const AScore,
      APV: string; out AChanged: Boolean): Boolean; overload;
    function RecordEnginePVForNodeId(ANodeId: Int64; const AScore,
      APV, ADepth, ATimeText: string; out AChanged: Boolean): Boolean; overload;
    function ParseVariationKey(const AVariationKey: string;
      out ABasePlyNumber, ADisplayAfterPly, AVariationIndex,
      AVariationPlyNumber: Integer): Boolean;
    procedure RecordVariationAnnotation(ABasePlyNumber, ADisplayAfterPly,
      AVariationIndex, AVariationPlyNumber: Integer;
      const AAnnotationText: string);
    procedure ClearStoredVariations;
    procedure CopyMainlineMovesTo(AMoves: TStrings);
    procedure TrimMainlineToCount(ACount: Integer);
    procedure TrimVariationLine(ABasePlyNumber, ADisplayAfterPly,
      AVariationIndex, AVariationMoveCount: Integer);
    function FindNodeById(ANodeId: Int64): TGameTreePlyNode;
    function FindVariationNode(AVariationIndex,
      AVariationPlyNumber: Integer): TGameTreePlyNode;
    function FindStoredVariationByDisplayAfterPly(
      ADisplayAfterPly: Integer): Integer;
    function StoreVariationLine(ADisplayAfterPly, ABasePly: Integer;
      const AMovesText, AAnnotationText: string): Integer; overload;
    function StoreVariationLine(ADisplayAfterPly, ABasePly: Integer;
      const AMovesText, AAnnotationText: string;
      out AChanged: Boolean): Integer; overload;
    function StoreVariationLine(ADisplayAfterPly, ABasePly: Integer;
      const AMovesText, AAnnotationText: string; AForceNew: Boolean;
      out AChanged: Boolean): Integer; overload;
    property Root: TGameTreePlyNode read FRoot;
    property GameTreeId: Int64 read FGameTreeId;
    property MainlineNode[APlyNumber: Integer]: TGameTreePlyNode
      read GetMainlineNode;
    property MainlineCount: Integer read GetMainlineCount;
    property VariationLineCount: Integer read GetVariationLineCount;
    property VariationLine[AIndex: Integer]: TGameTreeVariationLine
      read GetVariationLine;
  end;

function SideToMoveText(ASide: TDraughtsSide): string;

implementation

uses
  uPdn;

var
  NextGameTreeId: Int64 = 0;

function AllocateGameTreeId: Int64;
begin
  Inc(NextGameTreeId);
  Result := NextGameTreeId;
end;

function SideToMoveText(ASide: TDraughtsSide): string;
begin
  case ASide of
    dsWhite:
      Result := 'White';
    dsBlack:
      Result := 'Black';
  else
    Result := '?';
  end;
end;

function FenStartingSide(const AFEN: string): TDraughtsSide;
var
  LText: string;
begin
  LText := UpperCase(Trim(AFEN));
  if (LText <> '') and (LText[1] = 'B') then
    Result := dsBlack
  else
    Result := dsWhite;
end;

constructor TGameTreePlyNode.Create;
begin
  inherited Create;
  FChildren := TObjectList.Create(True);
  PlyNumber := 0;
  MoveNumber := 0;
  SideToMove := dsWhite;
  VariationKey := '';
  HasClockInfo := False;
  WhiteRemainingSeconds := 0;
  BlackRemainingSeconds := 0;
  WhiteUsedSeconds := 0;
  BlackUsedSeconds := 0;
end;

destructor TGameTreePlyNode.Destroy;
begin
  FChildren.Free;
  inherited Destroy;
end;

function TGameTreePlyNode.GetChild(AIndex: Integer): TGameTreePlyNode;
begin
  Result := TGameTreePlyNode(FChildren[AIndex]);
end;

function TGameTreePlyNode.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TGameTreePlyNode.AddChild: TGameTreePlyNode;
begin
  Result := TGameTreePlyNode.Create;
  Result.Parent := Self;
  FChildren.Add(Result);
end;

constructor TGameTree.Create;
begin
  inherited Create;
  FGameTreeId := AllocateGameTreeId;
  FNextNodeId := 0;
  FMainline := TFPList.Create;
  FEngineScoresByPly := TStringList.Create;
  FEnginePvsByPly := TStringList.Create;
  FEnginePvDepthsByPly := TStringList.Create;
  FEnginePvTimesByPly := TStringList.Create;
  FAnnotatorScoresByPly := TStringList.Create;
  FAnnotatorPvsByPly := TStringList.Create;
  FAnnotatorPvDepthsByPly := TStringList.Create;
  FAnnotatorPvTimesByPly := TStringList.Create;
  FClockStatesByPly := TObjectList.Create(True);
  FVariationEngineScoresByKey := TStringList.Create;
  FVariationEnginePvsByKey := TStringList.Create;
  FVariationEnginePvDepthsByKey := TStringList.Create;
  FVariationEnginePvTimesByKey := TStringList.Create;
  FVariationAnnotatorScoresByKey := TStringList.Create;
  FVariationAnnotatorPvsByKey := TStringList.Create;
  FVariationAnnotatorPvDepthsByKey := TStringList.Create;
  FVariationAnnotatorPvTimesByKey := TStringList.Create;
  FVariationLines := TObjectList.Create(True);
  FRoot := TGameTreePlyNode.Create;
  Clear;
end;

destructor TGameTree.Destroy;
begin
  FRoot.Free;
  FVariationLines.Free;
  FVariationAnnotatorPvTimesByKey.Free;
  FVariationAnnotatorPvDepthsByKey.Free;
  FVariationAnnotatorPvsByKey.Free;
  FVariationAnnotatorScoresByKey.Free;
  FVariationEnginePvTimesByKey.Free;
  FVariationEnginePvDepthsByKey.Free;
  FVariationEnginePvsByKey.Free;
  FVariationEngineScoresByKey.Free;
  FClockStatesByPly.Free;
  FAnnotatorPvTimesByPly.Free;
  FAnnotatorPvDepthsByPly.Free;
  FAnnotatorPvsByPly.Free;
  FAnnotatorScoresByPly.Free;
  FEnginePvTimesByPly.Free;
  FEnginePvDepthsByPly.Free;
  FEnginePvsByPly.Free;
  FEngineScoresByPly.Free;
  FMainline.Free;
  inherited Destroy;
end;

procedure TGameTree.Clear;
begin
  ClearObservedAnalysis;
  FSignature := '';
  ClearStructure;
end;

procedure TGameTree.ClearObservedAnalysis;
begin
  FEngineScoresByPly.Clear;
  FEnginePvsByPly.Clear;
  FEnginePvDepthsByPly.Clear;
  FEnginePvTimesByPly.Clear;
  FAnnotatorScoresByPly.Clear;
  FAnnotatorPvsByPly.Clear;
  FAnnotatorPvDepthsByPly.Clear;
  FAnnotatorPvTimesByPly.Clear;
  FClockStatesByPly.Clear;
  FVariationEngineScoresByKey.Clear;
  FVariationEnginePvsByKey.Clear;
  FVariationEnginePvDepthsByKey.Clear;
  FVariationEnginePvTimesByKey.Clear;
  FVariationAnnotatorScoresByKey.Clear;
  FVariationAnnotatorPvsByKey.Clear;
  FVariationAnnotatorPvDepthsByKey.Clear;
  FVariationAnnotatorPvTimesByKey.Clear;
  ClearStoredVariations;
end;

procedure TGameTree.ClearStructure;
begin
  FRoot.Free;
  FRoot := TGameTreePlyNode.Create;
  AssignNodeId(FRoot);
  FMainline.Clear;
  ClearTreeMetadata;
end;

procedure TGameTree.ClearTreeMetadata;
begin
  EventName := '?';
  WhiteName := 'White';
  BlackName := 'Black';
  ResultText := '*';
  StartingFEN := '';
  StatusText := '';
  GameState := gosWaiting;
  HasTimeControl := False;
  MovesPerPeriod := 0;
  MinutesPerPeriod := 0;
  IncrementSeconds := 0;
  IncrementModeText := '';
  HasClockInfo := False;
  WhiteRemainingSeconds := 0;
  BlackRemainingSeconds := 0;
  WhiteUsedSeconds := 0;
  BlackUsedSeconds := 0;
end;

procedure TGameTree.AssignNodeId(ANode: TGameTreePlyNode);
begin
  if ANode = nil then
    Exit;
  Inc(FNextNodeId);
  ANode.NodeId := FNextNodeId;
end;

procedure TGameTree.ResetNodeState(ANode: TGameTreePlyNode);
begin
  if ANode = nil then
    Exit;
  ANode.EngineScore := '';
  ANode.EnginePV := '';
  ANode.EnginePVDepth := '';
  ANode.EnginePVTimeText := '';
  ANode.AnnotatorScore := '';
  ANode.AnnotatorPV := '';
  ANode.AnnotatorPVDepth := '';
  ANode.AnnotatorPVTimeText := '';
  ANode.CommentText := '';
  ANode.HasClockInfo := False;
  ANode.WhiteRemainingSeconds := 0;
  ANode.BlackRemainingSeconds := 0;
  ANode.WhiteUsedSeconds := 0;
  ANode.BlackUsedSeconds := 0;
end;

procedure TGameTree.RemoveNodeFromParent(ANode: TGameTreePlyNode);
begin
  if (ANode = nil) or (ANode.Parent = nil) then
    Exit;
  ANode.Parent.FChildren.Remove(ANode);
end;

procedure TGameTree.RemoveVariationNodes(ANode: TGameTreePlyNode);
var
  Child: TGameTreePlyNode;
  I: Integer;
begin
  if ANode = nil then
    Exit;

  I := ANode.ChildCount - 1;
  while I >= 0 do
  begin
    Child := ANode.Children[I];
    if Trim(Child.VariationKey) <> '' then
      ANode.FChildren.Remove(Child)
    else
      RemoveVariationNodes(Child);
    Dec(I);
  end;
end;

procedure TGameTree.RemoveMainlineFrom(APlyNumber: Integer);
var
  I: Integer;
  Node: TGameTreePlyNode;
begin
  if APlyNumber <= 0 then
    APlyNumber := 1;
  if APlyNumber > FMainline.Count then
    Exit;

  for I := FMainline.Count downto APlyNumber do
  begin
    Node := TGameTreePlyNode(FMainline[I - 1]);
    if Node <> nil then
      RemoveNodeFromParent(Node);
    FMainline.Delete(I - 1);
  end;
end;

procedure TGameTree.BeginRebuild(const ASignature, AEventName, AWhiteName,
  ABlackName, AResultText, AStartingFEN: string);
begin
  if FSignature <> ASignature then
  begin
    ClearObservedAnalysis;
    FSignature := ASignature;
    ClearStructure;
  end;
  ClearTreeMetadata;
  SetHeader(AEventName, AWhiteName, ABlackName, AResultText, AStartingFEN);
  ResetNodeState(FRoot);
  ApplyStoredAnalysis(FRoot, 0);
end;

procedure TGameTree.SetHeader(const AEventName, AWhiteName, ABlackName,
  AResultText, AStartingFEN: string);
var
  Changed: Boolean;
begin
  SetHeader(AEventName, AWhiteName, ABlackName, AResultText, AStartingFEN,
    Changed);
end;

procedure TGameTree.SetHeader(const AEventName, AWhiteName, ABlackName,
  AResultText, AStartingFEN: string; out AChanged: Boolean);
begin
  AChanged := (EventName <> AEventName) or (WhiteName <> AWhiteName) or
    (BlackName <> ABlackName) or (ResultText <> AResultText) or
    (StartingFEN <> AStartingFEN);
  EventName := AEventName;
  WhiteName := AWhiteName;
  BlackName := ABlackName;
  ResultText := AResultText;
  StartingFEN := AStartingFEN;
end;

procedure TGameTree.SetGameState(AState: TGameOrchestratorState;
  out AChanged: Boolean);
begin
  AChanged := GameState <> AState;
  GameState := AState;
end;

procedure TGameTree.SetTimeControl(AMovesPerPeriod: Integer;
  AMinutesPerPeriod, AIncrementSeconds: Double; const AIncrementModeText: string);
begin
  HasTimeControl := True;
  MovesPerPeriod := AMovesPerPeriod;
  MinutesPerPeriod := AMinutesPerPeriod;
  IncrementSeconds := AIncrementSeconds;
  IncrementModeText := Trim(AIncrementModeText);
end;

procedure TGameTree.SetClockState(AWhiteRemainingSeconds,
  ABlackRemainingSeconds, AWhiteUsedSeconds, ABlackUsedSeconds: Double);
begin
  HasClockInfo := True;
  WhiteRemainingSeconds := AWhiteRemainingSeconds;
  BlackRemainingSeconds := ABlackRemainingSeconds;
  WhiteUsedSeconds := AWhiteUsedSeconds;
  BlackUsedSeconds := ABlackUsedSeconds;
end;

procedure TGameTree.SetNodeClockState(ANode: TGameTreePlyNode;
  AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
  ABlackUsedSeconds: Double);
begin
  if ANode = nil then
    Exit;
  ANode.HasClockInfo := True;
  ANode.WhiteRemainingSeconds := AWhiteRemainingSeconds;
  ANode.BlackRemainingSeconds := ABlackRemainingSeconds;
  ANode.WhiteUsedSeconds := AWhiteUsedSeconds;
  ANode.BlackUsedSeconds := ABlackUsedSeconds;
end;

function TGameTree.IncrementModeCaption(AMode: TClockIncrementMode): string;
begin
  case AMode of
    cimFromStart:
      Result := 'from start';
    cimAfterMoveLimit:
      Result := 'after move limit';
  else
    Result := '';
  end;
end;

procedure TGameTree.RecordTimeControl(AMovesPerPeriod: Integer;
  AMinutesPerPeriod, AIncrementSeconds: Double; const AIncrementModeText: string);
begin
  SetTimeControl(AMovesPerPeriod, AMinutesPerPeriod, AIncrementSeconds,
    AIncrementModeText);
end;

procedure TGameTree.RecordTimeControl(const ATimeControl: TTimeControl);
begin
  RecordTimeControl(ATimeControl.MovesPerPeriod,
    ATimeControl.MinutesPerPeriod, ATimeControl.IncrementSeconds,
    IncrementModeCaption(ATimeControl.IncrementMode));
end;

procedure TGameTree.RecordClockState(APlyNumber: Integer;
  AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
  ABlackUsedSeconds: Double);
begin
  SetClockState(AWhiteRemainingSeconds, ABlackRemainingSeconds,
    AWhiteUsedSeconds, ABlackUsedSeconds);
  if APlyNumber > 0 then
    StoreClockState(APlyNumber, AWhiteRemainingSeconds, ABlackRemainingSeconds,
      AWhiteUsedSeconds, ABlackUsedSeconds);
  if APlyNumber > 0 then
    SetNodeClockState(GetMainlineNode(APlyNumber), AWhiteRemainingSeconds,
      ABlackRemainingSeconds, AWhiteUsedSeconds, ABlackUsedSeconds);
end;

procedure TGameTree.ApplyAnnotationText(ANode: TGameTreePlyNode;
  const AAnnotationText: string);
var
  LAnnotatorScore: string;
  LEngineScore: string;
begin
  if ANode = nil then
    Exit;

  LEngineScore := ExtractAnnotationValue(AAnnotationText, 'engine');
  LAnnotatorScore := ExtractAnnotationValue(AAnnotationText, 'annotator');
  if LEngineScore <> '' then
    ANode.EngineScore := LEngineScore;
  if LAnnotatorScore <> '' then
    ANode.AnnotatorScore := LAnnotatorScore;
  if (LEngineScore = '') and (LAnnotatorScore = '') and
    (Trim(AAnnotationText) <> '') then
    ANode.CommentText := Trim(AAnnotationText);
end;

function TGameTree.RecordMainlineMove(APlyNumber: Integer;
  const AMoveText: string): TGameTreePlyNode;
begin
  Result := GetMainlineNode(APlyNumber);
  if (Result <> nil) and
    (not SameText(NormalizeMoveNotation(Result.MoveText),
      NormalizeMoveNotation(AMoveText))) then
  begin
    RemoveMainlineFrom(APlyNumber);
    Result := nil;
  end;

  if Result = nil then
  begin
    Result := AddMainlineMove(APlyNumber, AMoveText);
    Exit;
  end;

  Result.PlyNumber := APlyNumber;
  Result.MoveNumber := ((APlyNumber - 1) div 2) + 1;
  Result.SideToMove := SideForPly(APlyNumber);
  Result.MoveText := Trim(AMoveText);
  Result.VariationKey := '';
  ResetNodeState(Result);
  ApplyStoredAnalysis(Result, APlyNumber);
  ApplyStoredClockState(Result, APlyNumber);
end;

procedure TGameTree.RecordMainlineAnnotation(APlyNumber: Integer;
  const AAnnotationText: string);
var
  LAnnotatorScore: string;
  LEngineScore: string;
begin
  LEngineScore := ExtractAnnotationValue(AAnnotationText, 'engine');
  LAnnotatorScore := ExtractAnnotationValue(AAnnotationText, 'annotator');
  if LEngineScore <> '' then
    StoreValue(FEngineScoresByPly, APlyNumber, LEngineScore);
  if LAnnotatorScore <> '' then
    StoreValue(FAnnotatorScoresByPly, APlyNumber, LAnnotatorScore);
  ApplyAnnotationText(GetMainlineNode(APlyNumber), AAnnotationText);
end;

procedure TGameTree.RecordEnginePV(APlyNumber: Integer; const AScore,
  APV: string; const ADepth: string; const ATimeText: string);
begin
  AddEnginePV(APlyNumber, AScore, APV, ADepth, ATimeText);
end;

procedure TGameTree.RecordAnnotatorPV(APlyNumber: Integer; const AScore,
  APV: string; const ADepth: string; const ATimeText: string);
begin
  AddAnnotatorPV(APlyNumber, AScore, APV, ADepth, ATimeText);
end;

function TGameTree.RecordVariationMove(AParent: TGameTreePlyNode;
  ABasePlyNumber, ADisplayAfterPly, AVariationIndex,
  AVariationPlyNumber: Integer; const AMoveText: string): TGameTreePlyNode;
var
  LVariationKey: string;
begin
  LVariationKey := BuildVariationKey(ABasePlyNumber, ADisplayAfterPly,
    AVariationIndex, AVariationPlyNumber);
  Result := FindVariationNodeByKey(LVariationKey);
  if (Result <> nil) and ((Result.Parent <> AParent) or
    (not SameText(NormalizeMoveNotation(Result.MoveText),
      NormalizeMoveNotation(AMoveText)))) then
  begin
    RemoveNodeFromParent(Result);
    Result := nil;
  end;

  if Result = nil then
  begin
    Result := AddMove(AParent, ABasePlyNumber + AVariationPlyNumber,
      AMoveText);
    if Result = nil then
      Exit;
  end;

  Result.PlyNumber := ABasePlyNumber + AVariationPlyNumber;
  Result.MoveNumber := ((Result.PlyNumber - 1) div 2) + 1;
  Result.SideToMove := SideForPly(Result.PlyNumber);
  Result.MoveText := Trim(AMoveText);
  Result.VariationKey := LVariationKey;
  ResetNodeState(Result);
  ApplyStoredVariationAnalysis(Result, Result.VariationKey);
end;

procedure TGameTree.RecordVariationEnginePV(ABasePlyNumber,
  ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
  const AScore, APV: string; const ADepth: string; const ATimeText: string);
var
  LNode: TGameTreePlyNode;
  LVariationKey: string;
begin
  LVariationKey := BuildVariationKey(ABasePlyNumber, ADisplayAfterPly,
    AVariationIndex, AVariationPlyNumber);
  if Trim(AScore) <> '' then
    StoreKeyValue(FVariationEngineScoresByKey, LVariationKey, AScore);
  StoreKeyValue(FVariationEnginePvsByKey, LVariationKey, APV);
  if Trim(ADepth) <> '' then
    StoreKeyValue(FVariationEnginePvDepthsByKey, LVariationKey, ADepth);
  if Trim(ATimeText) <> '' then
    StoreKeyValue(FVariationEnginePvTimesByKey, LVariationKey, ATimeText);
  LNode := FindVariationNodeByKey(LVariationKey);
  if LNode <> nil then
    ApplyStoredVariationAnalysis(LNode, LVariationKey);
end;

function TGameTree.RecordEnginePVForNodeId(ANodeId: Int64;
  const AScore, APV: string; const ADepth: string; const ATimeText: string
  ): Boolean;
var
  Changed: Boolean;
begin
  Result := RecordEnginePVForNodeId(ANodeId, AScore, APV, ADepth, ATimeText,
    Changed);
end;

function TGameTree.RecordEnginePVForNodeId(ANodeId: Int64;
  const AScore, APV: string; out AChanged: Boolean): Boolean;
begin
  Result := RecordEnginePVForNodeId(ANodeId, AScore, APV, '', '', AChanged);
end;

function TGameTree.RecordEnginePVForNodeId(ANodeId: Int64;
  const AScore, APV, ADepth, ATimeText: string; out AChanged: Boolean
  ): Boolean;
var
  LBasePlyNumber: Integer;
  LDisplayAfterPly: Integer;
  LDepth: string;
  LNode: TGameTreePlyNode;
  LScore: string;
  LPV: string;
  LTimeText: string;
  LVariationIndex: Integer;
  LVariationPlyNumber: Integer;
begin
  Result := False;
  AChanged := False;
  LScore := Trim(AScore);
  LPV := Trim(APV);
  LDepth := Trim(ADepth);
  LTimeText := Trim(ATimeText);
  if LPV = '' then
    Exit;
  LNode := FindNodeById(ANodeId);
  if LNode = nil then
    Exit;

  AChanged := ((LScore <> '') and (Trim(LNode.EngineScore) <> LScore)) or
    (Trim(LNode.EnginePV) <> LPV) or
    ((LDepth <> '') and (Trim(LNode.EnginePVDepth) <> LDepth)) or
    ((LTimeText <> '') and (Trim(LNode.EnginePVTimeText) <> LTimeText));
  if Trim(LNode.VariationKey) = '' then
    RecordEnginePV(LNode.PlyNumber, LScore, LPV, LDepth, LTimeText)
  else
  begin
    if not ParseVariationKey(LNode.VariationKey, LBasePlyNumber,
      LDisplayAfterPly, LVariationIndex, LVariationPlyNumber) then
      Exit;
    RecordVariationEnginePV(LBasePlyNumber, LDisplayAfterPly,
      LVariationIndex, LVariationPlyNumber, LScore, LPV, LDepth, LTimeText);
  end;
  Result := True;
end;

procedure TGameTree.RecordVariationAnnotatorPV(ABasePlyNumber,
  ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
  const AScore, APV: string; const ADepth: string; const ATimeText: string);
var
  LNode: TGameTreePlyNode;
  LVariationKey: string;
begin
  LVariationKey := BuildVariationKey(ABasePlyNumber, ADisplayAfterPly,
    AVariationIndex, AVariationPlyNumber);
  StoreKeyValue(FVariationAnnotatorScoresByKey, LVariationKey, AScore);
  StoreKeyValue(FVariationAnnotatorPvsByKey, LVariationKey, APV);
  if Trim(ADepth) <> '' then
    StoreKeyValue(FVariationAnnotatorPvDepthsByKey, LVariationKey, ADepth);
  if Trim(ATimeText) <> '' then
    StoreKeyValue(FVariationAnnotatorPvTimesByKey, LVariationKey, ATimeText);
  LNode := FindVariationNodeByKey(LVariationKey);
  if LNode <> nil then
    ApplyStoredVariationAnalysis(LNode, LVariationKey);
end;

function TGameTree.RecordAnnotatorPVForNodeId(ANodeId: Int64;
  const AScore, APV: string; const ADepth: string; const ATimeText: string
  ): Boolean;
var
  Changed: Boolean;
begin
  Result := RecordAnnotatorPVForNodeId(ANodeId, AScore, APV, ADepth,
    ATimeText, Changed);
end;

function TGameTree.RecordAnnotatorPVForNodeId(ANodeId: Int64;
  const AScore, APV: string; out AChanged: Boolean): Boolean;
begin
  Result := RecordAnnotatorPVForNodeId(ANodeId, AScore, APV, '', '',
    AChanged);
end;

function TGameTree.RecordAnnotatorPVForNodeId(ANodeId: Int64;
  const AScore, APV, ADepth, ATimeText: string; out AChanged: Boolean
  ): Boolean;
var
  LBasePlyNumber: Integer;
  LDisplayAfterPly: Integer;
  LDepth: string;
  LNode: TGameTreePlyNode;
  LScore: string;
  LPV: string;
  LTimeText: string;
  LVariationIndex: Integer;
  LVariationPlyNumber: Integer;
begin
  Result := False;
  AChanged := False;
  LScore := Trim(AScore);
  LPV := Trim(APV);
  LDepth := Trim(ADepth);
  LTimeText := Trim(ATimeText);
  if LPV = '' then
    Exit;
  LNode := FindNodeById(ANodeId);
  if LNode = nil then
    Exit;

  AChanged := (Trim(LNode.AnnotatorScore) <> LScore) or
    (Trim(LNode.AnnotatorPV) <> LPV) or
    ((LDepth <> '') and (Trim(LNode.AnnotatorPVDepth) <> LDepth)) or
    ((LTimeText <> '') and (Trim(LNode.AnnotatorPVTimeText) <> LTimeText));
  if Trim(LNode.VariationKey) = '' then
    RecordAnnotatorPV(LNode.PlyNumber, LScore, LPV, LDepth, LTimeText)
  else
  begin
    if not ParseVariationKey(LNode.VariationKey, LBasePlyNumber,
      LDisplayAfterPly, LVariationIndex, LVariationPlyNumber) then
      Exit;
    RecordVariationAnnotatorPV(LBasePlyNumber, LDisplayAfterPly,
      LVariationIndex, LVariationPlyNumber, LScore, LPV, LDepth, LTimeText);
  end;
  Result := True;
end;

procedure TGameTree.RecordVariationAnnotation(ABasePlyNumber,
  ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
  const AAnnotationText: string);
var
  LAnnotatorScore: string;
  LEngineScore: string;
  LNode: TGameTreePlyNode;
  LVariationKey: string;
begin
  LVariationKey := BuildVariationKey(ABasePlyNumber, ADisplayAfterPly,
    AVariationIndex, AVariationPlyNumber);
  LEngineScore := ExtractAnnotationValue(AAnnotationText, 'engine');
  LAnnotatorScore := ExtractAnnotationValue(AAnnotationText, 'annotator');
  if LEngineScore <> '' then
    StoreKeyValue(FVariationEngineScoresByKey, LVariationKey, LEngineScore);
  if LAnnotatorScore <> '' then
    StoreKeyValue(FVariationAnnotatorScoresByKey, LVariationKey,
      LAnnotatorScore);
  LNode := FindVariationNodeByKey(LVariationKey);
  ApplyAnnotationText(LNode, AAnnotationText);
  ApplyStoredVariationAnalysis(LNode, LVariationKey);
end;

procedure TGameTree.ClearStoredVariations;
begin
  RemoveVariationNodes(FRoot);
  FVariationLines.Clear;
end;

procedure TGameTree.TrimMainlineToCount(ACount: Integer);
begin
  if ACount < 0 then
    ACount := 0;
  if ACount < FMainline.Count then
    RemoveMainlineFrom(ACount + 1);
end;

procedure TGameTree.TrimVariationLine(ABasePlyNumber, ADisplayAfterPly,
  AVariationIndex, AVariationMoveCount: Integer);
var
  Node: TGameTreePlyNode;
begin
  if AVariationMoveCount < 0 then
    AVariationMoveCount := 0;
  Node := FindVariationNodeByKey(BuildVariationKey(ABasePlyNumber,
    ADisplayAfterPly, AVariationIndex, AVariationMoveCount + 1));
  if Node <> nil then
    RemoveNodeFromParent(Node);
end;

function TGameTree.FindStoredVariationByDisplayAfterPly(
  ADisplayAfterPly: Integer): Integer;
var
  I: Integer;
  VariationEntry: TGameTreeVariationLine;
begin
  Result := -1;
  for I := 0 to FVariationLines.Count - 1 do
  begin
    VariationEntry := TGameTreeVariationLine(FVariationLines[I]);
    if (VariationEntry <> nil) and
      (VariationEntry.DisplayAfterPly = ADisplayAfterPly) then
      Exit(I);
  end;
end;

function FirstMoveInText(const AMovesText: string): string;
var
  Moves: TStringList;
begin
  Result := '';
  Moves := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)), Moves);
    if Moves.Count > 0 then
      Result := NormalizeMoveNotation(Moves[0]);
  finally
    Moves.Free;
  end;
end;

function TGameTree.FindStoredVariation(ADisplayAfterPly, ABasePly: Integer;
  const AMovesText: string): Integer;
var
  I: Integer;
  NewFirstMove: string;
  StoredFirstMove: string;
  VariationEntry: TGameTreeVariationLine;
begin
  Result := -1;
  NewFirstMove := FirstMoveInText(AMovesText);
  for I := 0 to FVariationLines.Count - 1 do
  begin
    VariationEntry := TGameTreeVariationLine(FVariationLines[I]);
    if (VariationEntry = nil) or
      (VariationEntry.DisplayAfterPly <> ADisplayAfterPly) or
      (VariationEntry.BasePly <> ABasePly) then
      Continue;

    StoredFirstMove := FirstMoveInText(VariationEntry.MovesText);
    if (StoredFirstMove = NewFirstMove) or
      ((StoredFirstMove = '') and (NewFirstMove <> '')) then
      Exit(I);
  end;
end;

function TGameTree.StoreVariationLine(ADisplayAfterPly, ABasePly: Integer;
  const AMovesText, AAnnotationText: string): Integer;
var
  Changed: Boolean;
begin
  Result := StoreVariationLine(ADisplayAfterPly, ABasePly, AMovesText,
    AAnnotationText, Changed);
end;

function TGameTree.StoreVariationLine(ADisplayAfterPly, ABasePly: Integer;
  const AMovesText, AAnnotationText: string;
  out AChanged: Boolean): Integer;
begin
  Result := StoreVariationLine(ADisplayAfterPly, ABasePly, AMovesText,
    AAnnotationText, False, AChanged);
end;

function TGameTree.StoreVariationLine(ADisplayAfterPly, ABasePly: Integer;
  const AMovesText, AAnnotationText: string; AForceNew: Boolean;
  out AChanged: Boolean): Integer;
var
  NewAnnotationText: string;
  NewMovesText: string;
  VariationEntry: TGameTreeVariationLine;
begin
  Result := -1;
  AChanged := False;
  if (ADisplayAfterPly < 0) or (ABasePly < 0) then
    Exit;

  NewMovesText := Trim(AMovesText);
  if AForceNew then
    Result := -1
  else
    Result := FindStoredVariation(ADisplayAfterPly, ABasePly, AMovesText);
  if Result < 0 then
  begin
    VariationEntry := TGameTreeVariationLine.Create;
    Result := FVariationLines.Add(VariationEntry);
    AChanged := True;
  end
  else
    VariationEntry := TGameTreeVariationLine(FVariationLines[Result]);

  NewAnnotationText := Trim(VariationEntry.AnnotationText);
  if (Trim(AAnnotationText) <> '') or (NewAnnotationText = '') then
    NewAnnotationText := Trim(AAnnotationText);

  if (VariationEntry.DisplayAfterPly <> ADisplayAfterPly) or
    (VariationEntry.BasePly <> ABasePly) or
    (Trim(VariationEntry.MovesText) <> NewMovesText) or
    (Trim(VariationEntry.AnnotationText) <> NewAnnotationText) then
    AChanged := True;

  VariationEntry.DisplayAfterPly := ADisplayAfterPly;
  VariationEntry.BasePly := ABasePly;
  VariationEntry.MovesText := NewMovesText;
  VariationEntry.AnnotationText := NewAnnotationText;
end;

function TGameTree.GetStoredValue(AList: TStringList; APlyNumber: Integer): string;
var
  LIndex: Integer;
begin
  Result := '';
  LIndex := AList.IndexOfName(IntToStr(APlyNumber));
  if LIndex >= 0 then
    Result := AList.ValueFromIndex[LIndex];
end;

function TGameTree.GetStoredKeyValue(AList: TStringList;
  const AKey: string): string;
var
  LIndex: Integer;
  LName: string;
begin
  Result := '';
  LName := Trim(AKey);
  if LName = '' then
    Exit;
  LIndex := AList.IndexOfName(LName);
  if LIndex >= 0 then
    Result := AList.ValueFromIndex[LIndex];
end;

function TGameTree.GetStoredClockState(APlyNumber: Integer): TGameTreeClockState;
begin
  Result := nil;
  if (APlyNumber <= 0) or (APlyNumber > FClockStatesByPly.Count) then
    Exit;
  Result := TGameTreeClockState(FClockStatesByPly[APlyNumber - 1]);
end;

procedure TGameTree.StoreClockState(APlyNumber: Integer;
  AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
  ABlackUsedSeconds: Double);
var
  ClockState: TGameTreeClockState;
begin
  if APlyNumber <= 0 then
    Exit;

  while FClockStatesByPly.Count < APlyNumber do
    FClockStatesByPly.Add(nil);
  ClockState := TGameTreeClockState(FClockStatesByPly[APlyNumber - 1]);
  if ClockState = nil then
  begin
    ClockState := TGameTreeClockState.Create;
    FClockStatesByPly[APlyNumber - 1] := ClockState;
  end;

  ClockState.WhiteRemainingSeconds := AWhiteRemainingSeconds;
  ClockState.BlackRemainingSeconds := ABlackRemainingSeconds;
  ClockState.WhiteUsedSeconds := AWhiteUsedSeconds;
  ClockState.BlackUsedSeconds := ABlackUsedSeconds;
end;

procedure TGameTree.StoreValue(AList: TStringList; APlyNumber: Integer;
  const AValue: string);
var
  LIndex: Integer;
  LName: string;
begin
  LName := IntToStr(APlyNumber);
  LIndex := AList.IndexOfName(LName);
  if Trim(AValue) = '' then
  begin
    if LIndex >= 0 then
      AList.Delete(LIndex);
    Exit;
  end;

  if LIndex >= 0 then
    AList.ValueFromIndex[LIndex] := Trim(AValue)
  else
    AList.Add(LName + '=' + Trim(AValue));
end;

procedure TGameTree.StoreKeyValue(AList: TStringList; const AKey,
  AValue: string);
var
  LIndex: Integer;
  LName: string;
begin
  LName := Trim(AKey);
  if LName = '' then
    Exit;

  LIndex := AList.IndexOfName(LName);
  if Trim(AValue) = '' then
  begin
    if LIndex >= 0 then
      AList.Delete(LIndex);
    Exit;
  end;

  if LIndex >= 0 then
    AList.ValueFromIndex[LIndex] := Trim(AValue)
  else
    AList.Add(LName + '=' + Trim(AValue));
end;

procedure TGameTree.ApplyStoredAnalysis(ANode: TGameTreePlyNode;
  APlyNumber: Integer);
begin
  if ANode = nil then
    Exit;
  ANode.EngineScore := GetStoredValue(FEngineScoresByPly, APlyNumber);
  ANode.EnginePV := GetStoredValue(FEnginePvsByPly, APlyNumber);
  ANode.EnginePVDepth := GetStoredValue(FEnginePvDepthsByPly, APlyNumber);
  ANode.EnginePVTimeText := GetStoredValue(FEnginePvTimesByPly, APlyNumber);
  ANode.AnnotatorScore := GetStoredValue(FAnnotatorScoresByPly, APlyNumber);
  ANode.AnnotatorPV := GetStoredValue(FAnnotatorPvsByPly, APlyNumber);
  ANode.AnnotatorPVDepth := GetStoredValue(FAnnotatorPvDepthsByPly,
    APlyNumber);
  ANode.AnnotatorPVTimeText := GetStoredValue(FAnnotatorPvTimesByPly,
    APlyNumber);
end;

procedure TGameTree.ApplyStoredClockState(ANode: TGameTreePlyNode;
  APlyNumber: Integer);
var
  ClockState: TGameTreeClockState;
begin
  if ANode = nil then
    Exit;
  ClockState := GetStoredClockState(APlyNumber);
  if ClockState = nil then
    Exit;
  SetNodeClockState(ANode, ClockState.WhiteRemainingSeconds,
    ClockState.BlackRemainingSeconds, ClockState.WhiteUsedSeconds,
    ClockState.BlackUsedSeconds);
end;

procedure TGameTree.ApplyStoredVariationAnalysis(ANode: TGameTreePlyNode;
  const AVariationKey: string);
begin
  if ANode = nil then
    Exit;
  ANode.EngineScore := GetStoredKeyValue(FVariationEngineScoresByKey,
    AVariationKey);
  ANode.EnginePV := GetStoredKeyValue(FVariationEnginePvsByKey,
    AVariationKey);
  ANode.EnginePVDepth := GetStoredKeyValue(FVariationEnginePvDepthsByKey,
    AVariationKey);
  ANode.EnginePVTimeText := GetStoredKeyValue(FVariationEnginePvTimesByKey,
    AVariationKey);
  ANode.AnnotatorScore := GetStoredKeyValue(FVariationAnnotatorScoresByKey,
    AVariationKey);
  ANode.AnnotatorPV := GetStoredKeyValue(FVariationAnnotatorPvsByKey,
    AVariationKey);
  ANode.AnnotatorPVDepth := GetStoredKeyValue(FVariationAnnotatorPvDepthsByKey,
    AVariationKey);
  ANode.AnnotatorPVTimeText := GetStoredKeyValue(FVariationAnnotatorPvTimesByKey,
    AVariationKey);
end;

function TGameTree.GetMainlineNode(APlyNumber: Integer): TGameTreePlyNode;
begin
  Result := nil;
  if (APlyNumber <= 0) or (APlyNumber > FMainline.Count) then
    Exit;
  Result := TGameTreePlyNode(FMainline[APlyNumber - 1]);
end;

function TGameTree.GetMainlineCount: Integer;
begin
  Result := FMainline.Count;
  while (Result > 0) and (FMainline[Result - 1] = nil) do
    Dec(Result);
end;

procedure TGameTree.CopyMainlineMovesTo(AMoves: TStrings);
var
  I: Integer;
  Node: TGameTreePlyNode;
begin
  if AMoves = nil then
    Exit;

  AMoves.Clear;
  for I := 1 to MainlineCount do
  begin
    Node := MainlineNode[I];
    if Node <> nil then
      AMoves.Add(Node.MoveText);
  end;
end;

function TGameTree.FindVariationNodeByKey(
  const AVariationKey: string): TGameTreePlyNode;
  function SearchNode(ANode: TGameTreePlyNode): TGameTreePlyNode;
  var
    I: Integer;
  begin
    Result := nil;
    if ANode = nil then
      Exit;
    if SameText(Trim(ANode.VariationKey), Trim(AVariationKey)) then
      Exit(ANode);
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Result := SearchNode(ANode.Children[I]);
      if Result <> nil then
        Exit;
    end;
  end;
begin
  Result := nil;
  if Trim(AVariationKey) = '' then
    Exit;
  Result := SearchNode(FRoot);
end;

function TGameTree.FindNodeById(ANodeId: Int64): TGameTreePlyNode;
  function SearchNode(ANode: TGameTreePlyNode): TGameTreePlyNode;
  var
    I: Integer;
  begin
    Result := nil;
    if ANode = nil then
      Exit;
    if ANode.NodeId = ANodeId then
      Exit(ANode);
    for I := 0 to ANode.ChildCount - 1 do
    begin
      Result := SearchNode(ANode.Children[I]);
      if Result <> nil then
        Exit;
    end;
  end;
begin
  Result := nil;
  if ANodeId <= 0 then
    Exit;
  Result := SearchNode(FRoot);
end;

function TGameTree.FindVariationNode(AVariationIndex,
  AVariationPlyNumber: Integer): TGameTreePlyNode;
var
  LVariationLine: TGameTreeVariationLine;
begin
  Result := nil;
  LVariationLine := GetVariationLine(AVariationIndex);
  if (LVariationLine = nil) or (AVariationPlyNumber <= 0) then
    Exit;

  Result := FindVariationNodeByKey(BuildVariationKey(LVariationLine.BasePly,
    LVariationLine.DisplayAfterPly, AVariationIndex, AVariationPlyNumber));
end;

function TGameTree.GetVariationLine(AIndex: Integer): TGameTreeVariationLine;
begin
  Result := nil;
  if (AIndex < 0) or (AIndex >= FVariationLines.Count) then
    Exit;
  Result := TGameTreeVariationLine(FVariationLines[AIndex]);
end;

function TGameTree.GetVariationLineCount: Integer;
begin
  Result := FVariationLines.Count;
end;

function TGameTree.SideForPly(APlyNumber: Integer): TDraughtsSide;
var
  LStartingSide: TDraughtsSide;
begin
  LStartingSide := FenStartingSide(StartingFEN);
  if ((LStartingSide = dsWhite) and Odd(APlyNumber)) or
    ((LStartingSide = dsBlack) and (not Odd(APlyNumber))) then
    Result := dsWhite
  else
    Result := dsBlack;
end;

function TGameTree.BuildVariationKey(ABasePlyNumber, ADisplayAfterPly,
  AVariationIndex, AVariationPlyNumber: Integer): string;
begin
  Result := IntToStr(ABasePlyNumber) + ':' + IntToStr(ADisplayAfterPly) +
    ':' + IntToStr(AVariationIndex) + ':' + IntToStr(AVariationPlyNumber);
end;

function TGameTree.ParseVariationKey(const AVariationKey: string;
  out ABasePlyNumber, ADisplayAfterPly, AVariationIndex,
  AVariationPlyNumber: Integer): Boolean;
var
  Parts: TStringList;
begin
  Result := False;
  ABasePlyNumber := -1;
  ADisplayAfterPly := -1;
  AVariationIndex := -1;
  AVariationPlyNumber := -1;
  Parts := TStringList.Create;
  try
    ExtractStrings([':'], [], PChar(Trim(AVariationKey)), Parts);
    if Parts.Count <> 4 then
      Exit;
    Result := TryStrToInt(Parts[0], ABasePlyNumber) and
      TryStrToInt(Parts[1], ADisplayAfterPly) and
      TryStrToInt(Parts[2], AVariationIndex) and
      TryStrToInt(Parts[3], AVariationPlyNumber);
  finally
    Parts.Free;
  end;
end;

function TGameTree.AddMove(AParent: TGameTreePlyNode; APlyNumber: Integer;
  const AMoveText: string): TGameTreePlyNode;
begin
  if AParent = nil then
    AParent := FRoot;
  Result := AParent.AddChild;
  AssignNodeId(Result);
  Result.PlyNumber := APlyNumber;
  Result.MoveNumber := ((APlyNumber - 1) div 2) + 1;
  Result.SideToMove := SideForPly(APlyNumber);
  Result.MoveText := Trim(AMoveText);
end;

function TGameTree.AddMainlineMove(APlyNumber: Integer;
  const AMoveText: string): TGameTreePlyNode;
begin
  if APlyNumber <= 0 then
    Exit(nil);

  Result := AddMove(FRoot, APlyNumber, AMoveText);
  while FMainline.Count < APlyNumber do
    FMainline.Add(nil);
  FMainline[APlyNumber - 1] := Result;
  ApplyStoredAnalysis(Result, APlyNumber);
  ApplyStoredClockState(Result, APlyNumber);
end;

procedure TGameTree.AddEnginePV(APlyNumber: Integer; const AScore,
  APV: string; const ADepth: string; const ATimeText: string);
var
  Node: TGameTreePlyNode;
begin
  if APlyNumber = 0 then
    Node := FRoot
  else
    Node := GetMainlineNode(APlyNumber);
  if Node = nil then
    Exit;
  if Trim(AScore) <> '' then
    StoreValue(FEngineScoresByPly, APlyNumber, AScore);
  StoreValue(FEnginePvsByPly, APlyNumber, APV);
  if Trim(ADepth) <> '' then
    StoreValue(FEnginePvDepthsByPly, APlyNumber, ADepth);
  if Trim(ATimeText) <> '' then
    StoreValue(FEnginePvTimesByPly, APlyNumber, ATimeText);
  ApplyStoredAnalysis(Node, APlyNumber);
end;

procedure TGameTree.AddAnnotatorPV(APlyNumber: Integer; const AScore,
  APV: string; const ADepth: string; const ATimeText: string);
var
  Node: TGameTreePlyNode;
begin
  if APlyNumber = 0 then
    Node := FRoot
  else
    Node := GetMainlineNode(APlyNumber);
  if Node = nil then
    Exit;
  StoreValue(FAnnotatorScoresByPly, APlyNumber, AScore);
  StoreValue(FAnnotatorPvsByPly, APlyNumber, APV);
  if Trim(ADepth) <> '' then
    StoreValue(FAnnotatorPvDepthsByPly, APlyNumber, ADepth);
  if Trim(ATimeText) <> '' then
    StoreValue(FAnnotatorPvTimesByPly, APlyNumber, ATimeText);
  ApplyStoredAnalysis(Node, APlyNumber);
end;

end.
