unit uGameTree;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils, uDraughtsBoard, uGameOrchestrator;

type
  TGameTreePlyNode = class
  private
    FChildren: TObjectList;
    FAutoPlayPV: string;
    FAnnotatorPV: string;
    FAnnotatorPVDepth: string;
    FAnnotatorPVTimeText: string;
    FAnnotatorScore: string;
    FBlackRemainingSeconds: Double;
    FBlackUsedSeconds: Double;
    FCommentText: string;
    FEnginePV: string;
    FEnginePVDepth: string;
    FEnginePVTimeText: string;
    FEngineScore: string;
    FHasClockInfo: Boolean;
    FMoveNumber: Integer;
    FMoveText: string;
    FNodeId: Int64;
    FParent: TGameTreePlyNode;
    FPlyNumber: Integer;
    FSideToMove: TDraughtsSide;
    FVariationKey: string;
    FWhiteRemainingSeconds: Double;
    FWhiteUsedSeconds: Double;
    {$WARN 3018 OFF}
    constructor Create;
    {$WARN 3018 ON}
    function AddChild: TGameTreePlyNode;
    function GetChild(AIndex: Integer): TGameTreePlyNode;
    function GetChildCount: Integer;
  public
    destructor Destroy; override;
    property AutoPlayPV: string read FAutoPlayPV;
    property AnnotatorPV: string read FAnnotatorPV;
    property AnnotatorPVDepth: string read FAnnotatorPVDepth;
    property AnnotatorPVTimeText: string read FAnnotatorPVTimeText;
    property AnnotatorScore: string read FAnnotatorScore;
    property BlackRemainingSeconds: Double read FBlackRemainingSeconds;
    property BlackUsedSeconds: Double read FBlackUsedSeconds;
    property ChildCount: Integer read GetChildCount;
    property Children[AIndex: Integer]: TGameTreePlyNode read GetChild;
    property CommentText: string read FCommentText;
    property EnginePV: string read FEnginePV;
    property EnginePVDepth: string read FEnginePVDepth;
    property EnginePVTimeText: string read FEnginePVTimeText;
    property EngineScore: string read FEngineScore;
    property HasClockInfo: Boolean read FHasClockInfo;
    property MoveNumber: Integer read FMoveNumber;
    property MoveText: string read FMoveText;
    property NodeId: Int64 read FNodeId;
    property Parent: TGameTreePlyNode read FParent;
    property PlyNumber: Integer read FPlyNumber;
    property SideToMove: TDraughtsSide read FSideToMove;
    property VariationKey: string read FVariationKey;
    property WhiteRemainingSeconds: Double read FWhiteRemainingSeconds;
    property WhiteUsedSeconds: Double read FWhiteUsedSeconds;
  end;

  TGameTreeVariationLine = class
  private
    FAnnotationText: string;
    FBasePly: Integer;
    FDisplayAfterPly: Integer;
    FMovesText: string;
    FOriginText: string;
  public
    constructor Create(ADisplayAfterPly: Integer = 0; ABasePly: Integer = 0;
      const AMovesText: string = ''; const AAnnotationText: string = '';
      const AOriginText: string = '');
    property AnnotationText: string read FAnnotationText;
    property BasePly: Integer read FBasePly;
    property DisplayAfterPly: Integer read FDisplayAfterPly;
    property MovesText: string read FMovesText;
    property OriginText: string read FOriginText;
  end;

  TGameTreeClockState = class
  private
    FBlackRemainingSeconds: Double;
    FBlackUsedSeconds: Double;
    FWhiteRemainingSeconds: Double;
    FWhiteUsedSeconds: Double;
  public
    property BlackRemainingSeconds: Double read FBlackRemainingSeconds;
    property BlackUsedSeconds: Double read FBlackUsedSeconds;
    property WhiteRemainingSeconds: Double read FWhiteRemainingSeconds;
    property WhiteUsedSeconds: Double read FWhiteUsedSeconds;
  end;

  TGameTree = class
  private
    FAnnotatorPvsByPly: TStringList;
    FAnnotatorPvDepthsByPly: TStringList;
    FAnnotatorPvTimesByPly: TStringList;
    FAutoPlayPvsByPly: TStringList;
    FAnnotatorScoresByPly: TStringList;
    FClockStatesByPly: TObjectList;
    FBlackName: string;
    FBlackRemainingSeconds: Double;
    FBlackUsedSeconds: Double;
    FEnginePvDepthsByPly: TStringList;
    FEnginePvsByPly: TStringList;
    FEnginePvTimesByPly: TStringList;
    FEngineScoresByPly: TStringList;
    FEventName: string;
    FGameTreeId: Int64;
    FGameState: TGameOrchestratorState;
    FHasClockInfo: Boolean;
    FHasTimeControl: Boolean;
    FIncrementModeText: string;
    FIncrementSeconds: Double;
    FMinutesPerPeriod: Double;
    FMovesPerPeriod: Integer;
    FResultText: string;
    FStartingFEN: string;
    FStatusText: string;
    FVariationAnnotatorPvsByKey: TStringList;
    FVariationAnnotatorPvDepthsByKey: TStringList;
    FVariationAnnotatorPvTimesByKey: TStringList;
    FVariationAnnotatorScoresByKey: TStringList;
    FVariationAutoPlayPvsByKey: TStringList;
    FVariationEnginePvsByKey: TStringList;
    FVariationEngineScoresByKey: TStringList;
    FVariationEnginePvDepthsByKey: TStringList;
    FVariationEnginePvTimesByKey: TStringList;
    FVariationLines: TObjectList;
    FMainline: TFPList;
    FNextNodeId: Int64;
    FRoot: TGameTreePlyNode;
    FSignature: string;
    FWhiteName: string;
    FWhiteRemainingSeconds: Double;
    FWhiteUsedSeconds: Double;
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
    procedure SetNodeClockState(ANode: TGameTreePlyNode;
      AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
      ABlackUsedSeconds: Double);
    procedure StoreValue(AList: TStringList; APlyNumber: Integer;
      const AValue: string);
    function UpdateVariationLine(AVariationLine: TGameTreeVariationLine;
      ADisplayAfterPly, ABasePly: Integer; const AMovesText,
      AAnnotationText: string): Boolean;
    function FindVariationNodeByKey(const AVariationKey: string): TGameTreePlyNode;
  public
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
    procedure SetStatusText(const AStatusText: string; out AChanged: Boolean);
    procedure SetTimeControl(AMovesPerPeriod: Integer; AMinutesPerPeriod,
      AIncrementSeconds: Double; const AIncrementModeText: string);
    procedure SetClockState(AWhiteRemainingSeconds, ABlackRemainingSeconds,
      AWhiteUsedSeconds, ABlackUsedSeconds: Double);
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
    function RecordAutoPlayPVForNodeId(ANodeId: Int64; const APV: string;
      out AChanged: Boolean): Boolean;
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
    function StoreVariationLineAtIndex(AVariationIndex, ADisplayAfterPly,
      ABasePly: Integer; const AMovesText, AAnnotationText: string;
      out AChanged: Boolean): Integer;
    procedure SetVariationLineOrigin(AVariationIndex: Integer;
      const AOriginText: string; out AChanged: Boolean);
    property BlackName: string read FBlackName;
    property BlackRemainingSeconds: Double read FBlackRemainingSeconds;
    property BlackUsedSeconds: Double read FBlackUsedSeconds;
    property EventName: string read FEventName;
    property GameState: TGameOrchestratorState read FGameState;
    property Root: TGameTreePlyNode read FRoot;
    property GameTreeId: Int64 read FGameTreeId;
    property HasClockInfo: Boolean read FHasClockInfo;
    property HasTimeControl: Boolean read FHasTimeControl;
    property IncrementModeText: string read FIncrementModeText;
    property IncrementSeconds: Double read FIncrementSeconds;
    property MainlineNode[APlyNumber: Integer]: TGameTreePlyNode
      read GetMainlineNode;
    property MainlineCount: Integer read GetMainlineCount;
    property MinutesPerPeriod: Double read FMinutesPerPeriod;
    property MovesPerPeriod: Integer read FMovesPerPeriod;
    property ResultText: string read FResultText;
    property StartingFEN: string read FStartingFEN;
    property StatusText: string read FStatusText;
    property VariationLineCount: Integer read GetVariationLineCount;
    property VariationLine[AIndex: Integer]: TGameTreeVariationLine
      read GetVariationLine;
    property WhiteName: string read FWhiteName;
    property WhiteRemainingSeconds: Double read FWhiteRemainingSeconds;
    property WhiteUsedSeconds: Double read FWhiteUsedSeconds;
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
  FPlyNumber := 0;
  FMoveNumber := 0;
  FSideToMove := dsWhite;
  FVariationKey := '';
  FHasClockInfo := False;
  FWhiteRemainingSeconds := 0;
  FBlackRemainingSeconds := 0;
  FWhiteUsedSeconds := 0;
  FBlackUsedSeconds := 0;
end;

constructor TGameTreeVariationLine.Create(ADisplayAfterPly: Integer;
  ABasePly: Integer; const AMovesText: string;
  const AAnnotationText: string; const AOriginText: string);
begin
  inherited Create;
  FDisplayAfterPly := ADisplayAfterPly;
  FBasePly := ABasePly;
  FMovesText := Trim(AMovesText);
  FAnnotationText := Trim(AAnnotationText);
  FOriginText := Trim(AOriginText);
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
  Result.FParent := Self;
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
  FAutoPlayPvsByPly := TStringList.Create;
  FClockStatesByPly := TObjectList.Create(True);
  FVariationEngineScoresByKey := TStringList.Create;
  FVariationEnginePvsByKey := TStringList.Create;
  FVariationEnginePvDepthsByKey := TStringList.Create;
  FVariationEnginePvTimesByKey := TStringList.Create;
  FVariationAnnotatorScoresByKey := TStringList.Create;
  FVariationAnnotatorPvsByKey := TStringList.Create;
  FVariationAnnotatorPvDepthsByKey := TStringList.Create;
  FVariationAnnotatorPvTimesByKey := TStringList.Create;
  FVariationAutoPlayPvsByKey := TStringList.Create;
  FVariationLines := TObjectList.Create(True);
  FRoot := TGameTreePlyNode.Create;
  Clear;
end;

destructor TGameTree.Destroy;
begin
  FRoot.Free;
  FVariationLines.Free;
  FVariationAutoPlayPvsByKey.Free;
  FVariationAnnotatorPvTimesByKey.Free;
  FVariationAnnotatorPvDepthsByKey.Free;
  FVariationAnnotatorPvsByKey.Free;
  FVariationAnnotatorScoresByKey.Free;
  FVariationEnginePvTimesByKey.Free;
  FVariationEnginePvDepthsByKey.Free;
  FVariationEnginePvsByKey.Free;
  FVariationEngineScoresByKey.Free;
  FClockStatesByPly.Free;
  FAutoPlayPvsByPly.Free;
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
  FAutoPlayPvsByPly.Clear;
  FClockStatesByPly.Clear;
  FVariationEngineScoresByKey.Clear;
  FVariationEnginePvsByKey.Clear;
  FVariationEnginePvDepthsByKey.Clear;
  FVariationEnginePvTimesByKey.Clear;
  FVariationAnnotatorScoresByKey.Clear;
  FVariationAnnotatorPvsByKey.Clear;
  FVariationAnnotatorPvDepthsByKey.Clear;
  FVariationAnnotatorPvTimesByKey.Clear;
  FVariationAutoPlayPvsByKey.Clear;
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
  FEventName := '?';
  FWhiteName := 'White';
  FBlackName := 'Black';
  FResultText := '*';
  FStartingFEN := DefaultStartingFEN;
  FStatusText := '';
  FGameState := gosWaiting;
  FHasTimeControl := False;
  FMovesPerPeriod := 0;
  FMinutesPerPeriod := 0;
  FIncrementSeconds := 0;
  FIncrementModeText := '';
  FHasClockInfo := False;
  FWhiteRemainingSeconds := 0;
  FBlackRemainingSeconds := 0;
  FWhiteUsedSeconds := 0;
  FBlackUsedSeconds := 0;
end;

procedure TGameTree.AssignNodeId(ANode: TGameTreePlyNode);
begin
  if ANode = nil then
    Exit;
  Inc(FNextNodeId);
  ANode.FNodeId := FNextNodeId;
end;

procedure TGameTree.ResetNodeState(ANode: TGameTreePlyNode);
begin
  if ANode = nil then
    Exit;
  ANode.FEngineScore := '';
  ANode.FAutoPlayPV := '';
  ANode.FEnginePV := '';
  ANode.FEnginePVDepth := '';
  ANode.FEnginePVTimeText := '';
  ANode.FAnnotatorScore := '';
  ANode.FAnnotatorPV := '';
  ANode.FAnnotatorPVDepth := '';
  ANode.FAnnotatorPVTimeText := '';
  ANode.FCommentText := '';
  ANode.FHasClockInfo := False;
  ANode.FWhiteRemainingSeconds := 0;
  ANode.FBlackRemainingSeconds := 0;
  ANode.FWhiteUsedSeconds := 0;
  ANode.FBlackUsedSeconds := 0;
end;

procedure TGameTree.RemoveNodeFromParent(ANode: TGameTreePlyNode);
begin
  if (ANode = nil) or (ANode.FParent = nil) then
    Exit;
  ANode.FParent.FChildren.Remove(ANode);
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
var
  EffectiveStartingFEN: string;
begin
  EffectiveStartingFEN := Trim(AStartingFEN);
  if EffectiveStartingFEN = '' then
    EffectiveStartingFEN := DefaultStartingFEN;
  AChanged := (FEventName <> AEventName) or (FWhiteName <> AWhiteName) or
    (FBlackName <> ABlackName) or (FResultText <> AResultText) or
    (FStartingFEN <> EffectiveStartingFEN);
  FEventName := AEventName;
  FWhiteName := AWhiteName;
  FBlackName := ABlackName;
  FResultText := AResultText;
  FStartingFEN := EffectiveStartingFEN;
  if FRoot <> nil then
    FRoot.FSideToMove := FenStartingSide(FStartingFEN);
end;

procedure TGameTree.SetGameState(AState: TGameOrchestratorState;
  out AChanged: Boolean);
begin
  AChanged := FGameState <> AState;
  FGameState := AState;
end;

procedure TGameTree.SetStatusText(const AStatusText: string;
  out AChanged: Boolean);
begin
  AChanged := FStatusText <> AStatusText;
  FStatusText := AStatusText;
end;

procedure TGameTree.SetTimeControl(AMovesPerPeriod: Integer;
  AMinutesPerPeriod, AIncrementSeconds: Double; const AIncrementModeText: string);
begin
  FHasTimeControl := True;
  FMovesPerPeriod := AMovesPerPeriod;
  FMinutesPerPeriod := AMinutesPerPeriod;
  FIncrementSeconds := AIncrementSeconds;
  FIncrementModeText := Trim(AIncrementModeText);
end;

procedure TGameTree.SetClockState(AWhiteRemainingSeconds,
  ABlackRemainingSeconds, AWhiteUsedSeconds, ABlackUsedSeconds: Double);
begin
  FHasClockInfo := True;
  FWhiteRemainingSeconds := AWhiteRemainingSeconds;
  FBlackRemainingSeconds := ABlackRemainingSeconds;
  FWhiteUsedSeconds := AWhiteUsedSeconds;
  FBlackUsedSeconds := ABlackUsedSeconds;
end;

procedure TGameTree.SetNodeClockState(ANode: TGameTreePlyNode;
  AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
  ABlackUsedSeconds: Double);
begin
  if ANode = nil then
    Exit;
  ANode.FHasClockInfo := True;
  ANode.FWhiteRemainingSeconds := AWhiteRemainingSeconds;
  ANode.FBlackRemainingSeconds := ABlackRemainingSeconds;
  ANode.FWhiteUsedSeconds := AWhiteUsedSeconds;
  ANode.FBlackUsedSeconds := ABlackUsedSeconds;
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
    ANode.FEngineScore := LEngineScore;
  if LAnnotatorScore <> '' then
    ANode.FAnnotatorScore := LAnnotatorScore;
  if (LEngineScore = '') and (LAnnotatorScore = '') and
    (Trim(AAnnotationText) <> '') then
    ANode.FCommentText := Trim(AAnnotationText);
end;

function TGameTree.RecordMainlineMove(APlyNumber: Integer;
  const AMoveText: string): TGameTreePlyNode;
begin
  Result := GetMainlineNode(APlyNumber);
  if (Result <> nil) and
    (not SameText(NormalizeMoveNotation(Result.FMoveText),
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

  Result.FPlyNumber := APlyNumber;
  Result.FMoveNumber := ((APlyNumber - 1) div 2) + 1;
  Result.FSideToMove := SideForPly(APlyNumber);
  Result.FMoveText := Trim(AMoveText);
  Result.FVariationKey := '';
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
  if (Result <> nil) and ((Result.FParent <> AParent) or
    (not SameText(NormalizeMoveNotation(Result.FMoveText),
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

  Result.FPlyNumber := ABasePlyNumber + AVariationPlyNumber;
  Result.FMoveNumber := ((Result.FPlyNumber - 1) div 2) + 1;
  Result.FSideToMove := SideForPly(Result.FPlyNumber);
  Result.FMoveText := Trim(AMoveText);
  Result.FVariationKey := LVariationKey;
  ResetNodeState(Result);
  ApplyStoredVariationAnalysis(Result, Result.FVariationKey);
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

  AChanged := ((LScore <> '') and (Trim(LNode.FEngineScore) <> LScore)) or
    (Trim(LNode.FEnginePV) <> LPV) or
    ((LDepth <> '') and (Trim(LNode.FEnginePVDepth) <> LDepth)) or
    ((LTimeText <> '') and (Trim(LNode.FEnginePVTimeText) <> LTimeText));
  if Trim(LNode.FVariationKey) = '' then
    RecordEnginePV(LNode.FPlyNumber, LScore, LPV, LDepth, LTimeText)
  else
  begin
    if not ParseVariationKey(LNode.FVariationKey, LBasePlyNumber,
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

  AChanged := (Trim(LNode.FAnnotatorScore) <> LScore) or
    (Trim(LNode.FAnnotatorPV) <> LPV) or
    ((LDepth <> '') and (Trim(LNode.FAnnotatorPVDepth) <> LDepth)) or
    ((LTimeText <> '') and (Trim(LNode.FAnnotatorPVTimeText) <> LTimeText));
  if Trim(LNode.FVariationKey) = '' then
    RecordAnnotatorPV(LNode.FPlyNumber, LScore, LPV, LDepth, LTimeText)
  else
  begin
    if not ParseVariationKey(LNode.FVariationKey, LBasePlyNumber,
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
      (VariationEntry.FDisplayAfterPly = ADisplayAfterPly) then
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
      (VariationEntry.FDisplayAfterPly <> ADisplayAfterPly) or
      (VariationEntry.FBasePly <> ABasePly) then
      Continue;

    StoredFirstMove := FirstMoveInText(VariationEntry.FMovesText);
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
    VariationEntry := TGameTreeVariationLine.Create(ADisplayAfterPly, ABasePly,
      NewMovesText, AAnnotationText);
    Result := FVariationLines.Add(VariationEntry);
    AChanged := True;
  end
  else
    VariationEntry := TGameTreeVariationLine(FVariationLines[Result]);

  if UpdateVariationLine(VariationEntry, ADisplayAfterPly, ABasePly,
    NewMovesText, AAnnotationText) then
    AChanged := True;
end;

function TGameTree.StoreVariationLineAtIndex(AVariationIndex,
  ADisplayAfterPly, ABasePly: Integer; const AMovesText,
  AAnnotationText: string; out AChanged: Boolean): Integer;
var
  VariationEntry: TGameTreeVariationLine;
begin
  Result := -1;
  AChanged := False;
  if (AVariationIndex < 0) or (AVariationIndex >= FVariationLines.Count) or
    (ADisplayAfterPly < 0) or (ABasePly < 0) then
    Exit;

  VariationEntry := TGameTreeVariationLine(FVariationLines[AVariationIndex]);
  if VariationEntry = nil then
    Exit;

  AChanged := UpdateVariationLine(VariationEntry, ADisplayAfterPly, ABasePly,
    AMovesText, AAnnotationText);
  Result := AVariationIndex;
end;

function TGameTree.UpdateVariationLine(AVariationLine: TGameTreeVariationLine;
  ADisplayAfterPly, ABasePly: Integer; const AMovesText,
  AAnnotationText: string): Boolean;
var
  NewAnnotationText: string;
  NewMovesText: string;
begin
  Result := False;
  if AVariationLine = nil then
    Exit;

  NewMovesText := Trim(AMovesText);
  NewAnnotationText := Trim(AVariationLine.FAnnotationText);
  if (Trim(AAnnotationText) <> '') or (NewAnnotationText = '') then
    NewAnnotationText := Trim(AAnnotationText);

  Result := (AVariationLine.FDisplayAfterPly <> ADisplayAfterPly) or
    (AVariationLine.FBasePly <> ABasePly) or
    (Trim(AVariationLine.FMovesText) <> NewMovesText) or
    (Trim(AVariationLine.FAnnotationText) <> NewAnnotationText);

  AVariationLine.FDisplayAfterPly := ADisplayAfterPly;
  AVariationLine.FBasePly := ABasePly;
  AVariationLine.FMovesText := NewMovesText;
  AVariationLine.FAnnotationText := NewAnnotationText;
end;

procedure TGameTree.SetVariationLineOrigin(AVariationIndex: Integer;
  const AOriginText: string; out AChanged: Boolean);
var
  VariationEntry: TGameTreeVariationLine;
begin
  AChanged := False;
  if (AVariationIndex < 0) or (AVariationIndex >= FVariationLines.Count) then
    Exit;

  VariationEntry := TGameTreeVariationLine(FVariationLines[AVariationIndex]);
  if VariationEntry = nil then
    Exit;

  AChanged := Trim(VariationEntry.FOriginText) <> Trim(AOriginText);
  VariationEntry.FOriginText := Trim(AOriginText);
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

  ClockState.FWhiteRemainingSeconds := AWhiteRemainingSeconds;
  ClockState.FBlackRemainingSeconds := ABlackRemainingSeconds;
  ClockState.FWhiteUsedSeconds := AWhiteUsedSeconds;
  ClockState.FBlackUsedSeconds := ABlackUsedSeconds;
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
  ANode.FEngineScore := GetStoredValue(FEngineScoresByPly, APlyNumber);
  ANode.FEnginePV := GetStoredValue(FEnginePvsByPly, APlyNumber);
  ANode.FEnginePVDepth := GetStoredValue(FEnginePvDepthsByPly, APlyNumber);
  ANode.FEnginePVTimeText := GetStoredValue(FEnginePvTimesByPly, APlyNumber);
  ANode.FAnnotatorScore := GetStoredValue(FAnnotatorScoresByPly, APlyNumber);
  ANode.FAnnotatorPV := GetStoredValue(FAnnotatorPvsByPly, APlyNumber);
  ANode.FAnnotatorPVDepth := GetStoredValue(FAnnotatorPvDepthsByPly,
    APlyNumber);
  ANode.FAnnotatorPVTimeText := GetStoredValue(FAnnotatorPvTimesByPly,
    APlyNumber);
  ANode.FAutoPlayPV := GetStoredValue(FAutoPlayPvsByPly, APlyNumber);
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
  SetNodeClockState(ANode, ClockState.FWhiteRemainingSeconds,
    ClockState.FBlackRemainingSeconds, ClockState.FWhiteUsedSeconds,
    ClockState.FBlackUsedSeconds);
end;

procedure TGameTree.ApplyStoredVariationAnalysis(ANode: TGameTreePlyNode;
  const AVariationKey: string);
begin
  if ANode = nil then
    Exit;
  ANode.FEngineScore := GetStoredKeyValue(FVariationEngineScoresByKey,
    AVariationKey);
  ANode.FEnginePV := GetStoredKeyValue(FVariationEnginePvsByKey,
    AVariationKey);
  ANode.FEnginePVDepth := GetStoredKeyValue(FVariationEnginePvDepthsByKey,
    AVariationKey);
  ANode.FEnginePVTimeText := GetStoredKeyValue(FVariationEnginePvTimesByKey,
    AVariationKey);
  ANode.FAnnotatorScore := GetStoredKeyValue(FVariationAnnotatorScoresByKey,
    AVariationKey);
  ANode.FAnnotatorPV := GetStoredKeyValue(FVariationAnnotatorPvsByKey,
    AVariationKey);
  ANode.FAnnotatorPVDepth := GetStoredKeyValue(FVariationAnnotatorPvDepthsByKey,
    AVariationKey);
  ANode.FAnnotatorPVTimeText := GetStoredKeyValue(FVariationAnnotatorPvTimesByKey,
    AVariationKey);
  ANode.FAutoPlayPV := GetStoredKeyValue(FVariationAutoPlayPvsByKey,
    AVariationKey);
end;

function TGameTree.RecordAutoPlayPVForNodeId(ANodeId: Int64;
  const APV: string; out AChanged: Boolean): Boolean;
var
  LNode: TGameTreePlyNode;
  LPV: string;
begin
  Result := False;
  AChanged := False;
  LNode := FindNodeById(ANodeId);
  if LNode = nil then
    Exit;

  LPV := Trim(APV);
  AChanged := Trim(LNode.FAutoPlayPV) <> LPV;
  if Trim(LNode.FVariationKey) = '' then
    StoreValue(FAutoPlayPvsByPly, LNode.FPlyNumber, LPV)
  else
    StoreKeyValue(FVariationAutoPlayPvsByKey, LNode.FVariationKey, LPV);
  LNode.FAutoPlayPV := LPV;
  Result := True;
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
      AMoves.Add(Node.FMoveText);
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
    if SameText(Trim(ANode.FVariationKey), Trim(AVariationKey)) then
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
    if ANode.FNodeId = ANodeId then
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

  Result := FindVariationNodeByKey(BuildVariationKey(LVariationLine.FBasePly,
    LVariationLine.FDisplayAfterPly, AVariationIndex, AVariationPlyNumber));
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
  LStartingSide := FenStartingSide(FStartingFEN);
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
  Result.FPlyNumber := APlyNumber;
  Result.FMoveNumber := ((APlyNumber - 1) div 2) + 1;
  Result.FSideToMove := SideForPly(APlyNumber);
  Result.FMoveText := Trim(AMoveText);
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
