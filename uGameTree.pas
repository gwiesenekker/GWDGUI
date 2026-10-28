unit uGameTree;

{$mode objfpc}{$H+}{$modeswitch advancedrecords}

interface

uses
  Classes, Contnrs, SysUtils, uGamePosition, uGameOrchestrator, uGameMoveHistory, uGameTreeNodeData;

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
    FHasMoveTime: Boolean;
    FSecondsUsed: Double;
    FMoveNumber: Integer;
    FMoveText: string;
    FOriginText: string;
    FNodeId: Int64;
    FParent: TGameTreePlyNode;
    FPlyNumber: Integer;
    FSideToMove: TGameSide;
    FWhiteRemainingSeconds: Double;
    FWhiteUsedSeconds: Double;
    {$WARN 3018 OFF}
    constructor Create;
    {$WARN 3018 ON}
    function AddChild: TGameTreePlyNode;
    function GetNodeData: TGameTreeNodeData;
    function GetChild(AIndex: Integer): TGameTreePlyNode;
    function GetChildCount: Integer;
  public
    destructor Destroy; override;
    property NodeData: TGameTreeNodeData read GetNodeData;
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
    property HasMoveTime: Boolean read FHasMoveTime;
    property SecondsUsed: Double read FSecondsUsed;
    property MoveNumber: Integer read FMoveNumber;
    property MoveText: string read FMoveText;
    property OriginText: string read FOriginText;
    property NodeId: Int64 read FNodeId;
    property Parent: TGameTreePlyNode read FParent;
    property PlyNumber: Integer read FPlyNumber;
    property SideToMove: TGameSide read FSideToMove;
    property WhiteRemainingSeconds: Double read FWhiteRemainingSeconds;
    property WhiteUsedSeconds: Double read FWhiteUsedSeconds;
  end;

  // A read-only inspection path, derived on demand from actual children.
  // It owns no game data and is never accepted as an import or rebuild input.
  TGameTreeBranchPath = record
    Nodes: array of TGameTreePlyNode;
    function GetBasePly: Integer;
    function GetMovesText: string;
    function GetAnnotationText: string;
    function GetOriginText: string;
    property BasePly: Integer read GetBasePly;
    property MovesText: string read GetMovesText;
    property AnnotationText: string read GetAnnotationText;
    property OriginText: string read GetOriginText;
  end;
  TGameTreeBranchPaths = array of TGameTreeBranchPath;

  TGameTree = class
  private
    FBlackName: string;
    FBlackRemainingSeconds: Double;
    FBlackUsedSeconds: Double;
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
    FMainline: TFPList;
    FNextNodeId: Int64;
    FNodeIndexDirty: Boolean;
    FNodeIndexRebuildCount: QWord;
    FNodeIndex: TFPHashList; // Non-owning; child nodes remain owned by the tree.
    FVariant: TGameVariant; // Borrowed; outlives the tree.
    FRoot: TGameTreePlyNode;
    FSignature: string;
    FWhiteName: string;
    FWhiteRemainingSeconds: Double;
    FWhiteUsedSeconds: Double;
    procedure ApplyAnnotationText(ANode: TGameTreePlyNode;
      const AAnnotationText: string);
    procedure ClearStructure;
    procedure UpdateNodePV(ANode: TGameTreePlyNode; AEngine: Boolean;
      const AScore, APV, ADepth, ATimeText: string);
    procedure ClearTreeMetadata;
    function IncrementModeCaption(AMode: TClockIncrementMode): string;
    function SideForPly(APlyNumber: Integer): TGameSide;
    function MoveNumberForPly(APlyNumber: Integer): Integer;
    procedure ApplyStartingFEN(ARenumber: Boolean);
    function AddMove(AParent: TGameTreePlyNode; APlyNumber: Integer;
      const AMoveText: string): TGameTreePlyNode;
    function AddMainlineMove(APlyNumber: Integer;
      const AMoveText: string): TGameTreePlyNode;
    procedure AddEnginePV(APlyNumber: Integer; const AScore, APV: string;
      const ADepth: string = ''; const ATimeText: string = '');
    procedure AddAnnotatorPV(APlyNumber: Integer; const AScore, APV: string;
      const ADepth: string = ''; const ATimeText: string = '');
    function GetMainlineNode(APlyNumber: Integer): TGameTreePlyNode;
    function GetMainlineCount: Integer;
    procedure AssignNodeId(ANode: TGameTreePlyNode);
    procedure InvalidateNodeIndex;
    procedure EnsureNodeIndex;
    procedure RemoveMainlineFrom(APlyNumber: Integer);
    procedure RemoveNodeFromParent(ANode: TGameTreePlyNode);
    procedure RemoveVariationNodes(ANode: TGameTreePlyNode);
    procedure SetNodeClockState(ANode: TGameTreePlyNode;
      AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
      ABlackUsedSeconds: Double);
  public
    property NodeIndexRebuildCount: QWord read FNodeIndexRebuildCount;
    function FindChildByMove(AParent: TGameTreePlyNode; const AMove: string): TGameTreePlyNode;
    function IsMainlineNode(ANode: TGameTreePlyNode): Boolean;
    function RecordBranchMove(AParent: TGameTreePlyNode; const AMove: string): TGameTreePlyNode;
    function RecordNodeAnnotation(ANode: TGameTreePlyNode; const AText: string): Boolean;
    procedure SetNodeOrigin(ANode: TGameTreePlyNode; const AOrigin: string);
    procedure ClearBranches;
    procedure RemoveBranch(ANode: TGameTreePlyNode);
    function BranchPaths: TGameTreeBranchPaths;
    function GetBranchPath(AIndex: Integer): TGameTreeBranchPath;
    function GetBranchCount: Integer;
    function FindBranchNode(AIndex, APly: Integer): TGameTreePlyNode;
    function RestoreNodeData(ANodeId: Int64; const Data: TGameTreeNodeData): Boolean;
    function RecordCompletedMoveData(APly: Integer; const AData: TGameMoveData): Boolean;
    // AVariant = nil uses DefaultGameVariant (registered by the linked game).
    constructor Create(AVariant: TGameVariant = nil);
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
    procedure CopyMainlineMovesTo(AMoves: TStrings);
    function CopyNodeMovesTo(ANode: TGameTreePlyNode; AMoves: TStrings): Boolean;
    // Replays the validated moves from the starting position into APosition
    // (a position of this tree's variant). False when the node is not in
    // this tree or a move does not replay; APosition is unchanged then.
    function TryBuildPositionAtNode(ANode: TGameTreePlyNode;
      APosition: TGamePosition): Boolean;
    procedure TrimMainlineToCount(ACount: Integer);
    function FindNodeById(ANodeId: Int64): TGameTreePlyNode;
    property Variant: TGameVariant read FVariant;
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
    property Signature: string read FSignature;
    property StartingFEN: string read FStartingFEN;
    property StatusText: string read FStatusText;
    property BranchCount: Integer read GetBranchCount;
    property BranchPath[AIndex: Integer]: TGameTreeBranchPath read GetBranchPath;
    property WhiteName: string read FWhiteName;
    property WhiteRemainingSeconds: Double read FWhiteRemainingSeconds;
    property WhiteUsedSeconds: Double read FWhiteUsedSeconds;
  end;

function SideToMoveText(ASide: TGameSide): string;

implementation

uses
  uPdnText;

var
  NextGameTreeId: Int64 = 0;

function AllocateGameTreeId: Int64;
begin
  Inc(NextGameTreeId);
  Result := NextGameTreeId;
end;

function SideToMoveText(ASide: TGameSide): string;
begin
  case ASide of
    gsWhite:
      Result := 'White';
    gsBlack:
      Result := 'Black';
  else
    Result := '?';
  end;
end;

function TGameTreePlyNode.GetNodeData: TGameTreeNodeData;
begin
  Result.CommentText := FCommentText;
  Result.OriginText := FOriginText;
  Result.EnginePV := FEnginePV;
  Result.EngineScore := FEngineScore;
  Result.EnginePVDepth := FEnginePVDepth;
  Result.EnginePVTimeText := FEnginePVTimeText;
  Result.AnnotatorPV := FAnnotatorPV;
  Result.AnnotatorScore := FAnnotatorScore;
  Result.AnnotatorPVDepth := FAnnotatorPVDepth;
  Result.AnnotatorPVTimeText := FAnnotatorPVTimeText;
  Result.AutoPlayPV := FAutoPlayPV;
  Result.HasClockInfo := FHasClockInfo;
  Result.HasMoveTime := FHasMoveTime;
  Result.SecondsUsed := FSecondsUsed;
  Result.WhiteRemainingSeconds := FWhiteRemainingSeconds;
  Result.BlackRemainingSeconds := FBlackRemainingSeconds;
  Result.WhiteUsedSeconds := FWhiteUsedSeconds;
  Result.BlackUsedSeconds := FBlackUsedSeconds;
end;

function TGameTree.RestoreNodeData(ANodeId: Int64; const Data: TGameTreeNodeData): Boolean;
var Node: TGameTreePlyNode;
begin
  Node := FindNodeById(ANodeId);
  Result := Node <> nil;
  if not Result then Exit;
  Node.FCommentText := Data.CommentText;
  Node.FOriginText := Data.OriginText;
  Node.FEnginePV := Data.EnginePV;
  Node.FEngineScore := Data.EngineScore;
  Node.FEnginePVDepth := Data.EnginePVDepth;
  Node.FEnginePVTimeText := Data.EnginePVTimeText;
  Node.FAnnotatorPV := Data.AnnotatorPV;
  Node.FAnnotatorScore := Data.AnnotatorScore;
  Node.FAnnotatorPVDepth := Data.AnnotatorPVDepth;
  Node.FAnnotatorPVTimeText := Data.AnnotatorPVTimeText;
  Node.FAutoPlayPV := Data.AutoPlayPV;
  Node.FHasClockInfo := Data.HasClockInfo;
  Node.FHasMoveTime := Data.HasMoveTime;
  Node.FSecondsUsed := Data.SecondsUsed;
  Node.FWhiteRemainingSeconds := Data.WhiteRemainingSeconds;
  Node.FBlackRemainingSeconds := Data.BlackRemainingSeconds;
  Node.FWhiteUsedSeconds := Data.WhiteUsedSeconds;
  Node.FBlackUsedSeconds := Data.BlackUsedSeconds;
end;

constructor TGameTreePlyNode.Create;
begin
  inherited Create;
  FChildren := TObjectList.Create(True);
  FPlyNumber := 0;
  FMoveNumber := 0;
  FSideToMove := gsWhite;
  FHasClockInfo := False;
  FWhiteRemainingSeconds := 0;
  FBlackRemainingSeconds := 0;
  FWhiteUsedSeconds := 0;
  FBlackUsedSeconds := 0;
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

constructor TGameTree.Create(AVariant: TGameVariant);
begin
  inherited Create;
  FVariant := AVariant;
  if FVariant = nil then
    FVariant := DefaultGameVariant;
  FGameTreeId := AllocateGameTreeId;
  FNextNodeId := 0;
  FMainline := TFPList.Create;
  FNodeIndex := TFPHashList.Create;
  FRoot := TGameTreePlyNode.Create;
  Clear;
end;

destructor TGameTree.Destroy;
begin
  FRoot.Free;
  FNodeIndex.Free;
  FMainline.Free;
  inherited Destroy;
end;

procedure TGameTree.Clear;
begin
  FSignature := '';
  ClearStructure;
end;

procedure TGameTree.ClearStructure;
begin
  FNodeIndex.Clear;
  FNodeIndexDirty := False;
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
  FStartingFEN := FVariant.DefaultStartingFEN;
  // The root's side and starting move number always follow the starting FEN
  // (reviews G9, G10); SetHeader does the same when a header supplies another FEN.
  ApplyStartingFEN(False);
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
  if not FNodeIndexDirty then FNodeIndex.Add(IntToStr(ANode.FNodeId), ANode);
end;

procedure TGameTree.InvalidateNodeIndex;
begin
  if FNodeIndexDirty then Exit;
  // Empty the non-owning map before freeing nodes; do not rehash per removed ID.
  FNodeIndex.Clear;
  FNodeIndexDirty := True;
end;

procedure TGameTree.EnsureNodeIndex;
  procedure Visit(Node: TGameTreePlyNode);
  var I: Integer;
  begin
    FNodeIndex.Add(IntToStr(Node.NodeId), Node);
    for I := 0 to Node.ChildCount - 1 do Visit(Node.Children[I]);
  end;
begin
  if not FNodeIndexDirty then Exit;
  FNodeIndex.Clear;
  Visit(FRoot);
  FNodeIndexDirty := False;
  Inc(FNodeIndexRebuildCount);
end;

procedure TGameTree.RemoveNodeFromParent(ANode: TGameTreePlyNode);
begin
  if (ANode = nil) or (ANode.FParent = nil) then
    Exit;
  InvalidateNodeIndex;
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
    if GetMainlineNode(Child.PlyNumber) <> Child then
    begin
      InvalidateNodeIndex;
      ANode.FChildren.Remove(Child);
    end
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
var
  EffectiveFen: string;
begin
  EffectiveFen := Trim(AStartingFEN);
  if EffectiveFen = '' then EffectiveFen := FVariant.DefaultStartingFEN;
  if (FSignature <> ASignature) or (FStartingFEN <> EffectiveFen) then
  begin
      FSignature := ASignature;
    ClearStructure;
  end;
  ClearTreeMetadata;
  SetHeader(AEventName, AWhiteName, ABlackName, AResultText, AStartingFEN);
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
  LFENChanged: Boolean;
begin
  EffectiveStartingFEN := Trim(AStartingFEN);
  if EffectiveStartingFEN = '' then
    EffectiveStartingFEN := FVariant.DefaultStartingFEN;
  LFENChanged := FStartingFEN <> EffectiveStartingFEN;
  AChanged := (FEventName <> AEventName) or (FWhiteName <> AWhiteName) or
    (FBlackName <> ABlackName) or (FResultText <> AResultText) or LFENChanged;
  FEventName := AEventName;
  FWhiteName := AWhiteName;
  FBlackName := ABlackName;
  FResultText := AResultText;
  FStartingFEN := EffectiveStartingFEN;
  ApplyStartingFEN(LFENChanged);
end;

procedure TGameTree.ApplyStartingFEN(ARenumber: Boolean);

  procedure Renumber(ANode: TGameTreePlyNode);
  var
    I: Integer;
  begin
    for I := 0 to ANode.ChildCount - 1 do
    begin
      ANode.Children[I].FMoveNumber := MoveNumberForPly(ANode.Children[I].FPlyNumber);
      ANode.Children[I].FSideToMove := SideForPly(ANode.Children[I].FPlyNumber);
      Renumber(ANode.Children[I]);
    end;
  end;

begin
  if FRoot = nil then
    Exit;
  FRoot.FSideToMove := FVariant.SideFromFEN(FStartingFEN);
  // The root has no move; its number is that of the first move (used for
  // analysis lines that start at the root).
  FRoot.FMoveNumber := FVariant.StartingMoveNumberFromFEN(FStartingFEN);
  if ARenumber then
    Renumber(FRoot);
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

function TGameTree.RecordCompletedMoveData(APly: Integer;
  const AData: TGameMoveData): Boolean;
var
  Node, ParentNode: TGameTreePlyNode;
begin
  Result := False;
  Node := GetMainlineNode(APly);
  if (Node = nil) or
    not FVariant.SameMove(Node.MoveText, AData.MoveText) then Exit;
  Result := not Node.FHasMoveTime or (Node.FSecondsUsed <> AData.SecondsUsed);
  Node.FHasMoveTime := True;
  Node.FSecondsUsed := AData.SecondsUsed;
  if AData.HasClockInfo then
  begin
    Result := Result or not Node.HasClockInfo or
      (Node.WhiteRemainingSeconds <> AData.WhiteRemainingSeconds) or
      (Node.BlackRemainingSeconds <> AData.BlackRemainingSeconds) or
      (Node.WhiteUsedSeconds <> AData.WhiteUsedSeconds) or
      (Node.BlackUsedSeconds <> AData.BlackUsedSeconds);
    SetNodeClockState(Node, AData.WhiteRemainingSeconds, AData.BlackRemainingSeconds,
      AData.WhiteUsedSeconds, AData.BlackUsedSeconds);
  end;
  ParentNode := Node.Parent;
  if (ParentNode <> nil) and (AData.PrincipalVariation <> '') then
  begin
    Result := Result or (ParentNode.EnginePV <> AData.PrincipalVariation) or
      (ParentNode.EngineScore <> AData.PvScore) or
      (ParentNode.EnginePVDepth <> AData.PvDepth) or
      (ParentNode.EnginePVTimeText <> AData.PvTimeText);
    UpdateNodePV(ParentNode, True, AData.PvScore, AData.PrincipalVariation,
      AData.PvDepth, AData.PvTimeText);
  end;
end;

procedure TGameTree.RecordClockState(APlyNumber: Integer;
  AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
  ABlackUsedSeconds: Double);
begin
  SetClockState(AWhiteRemainingSeconds, ABlackRemainingSeconds,
    AWhiteUsedSeconds, ABlackUsedSeconds);
  if APlyNumber = 0 then
    SetNodeClockState(FRoot, AWhiteRemainingSeconds, ABlackRemainingSeconds,
      AWhiteUsedSeconds, ABlackUsedSeconds)
  else if APlyNumber > 0 then
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
  ANode.FCommentText := AnnotationWithoutName(AnnotationWithoutName(
    AnnotationWithoutName(AAnnotationText, 'engine'), 'annotator'), 'score');
end;

function TGameTree.RecordMainlineMove(APlyNumber: Integer;
  const AMoveText: string): TGameTreePlyNode;
begin
  Result := GetMainlineNode(APlyNumber);
  if (Result <> nil) and
    not FVariant.SameMove(Result.FMoveText, AMoveText) then
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
  Result.FMoveNumber := MoveNumberForPly(APlyNumber);
  Result.FSideToMove := SideForPly(APlyNumber);
  Result.FMoveText := Trim(AMoveText);
end;

procedure TGameTree.RecordMainlineAnnotation(APlyNumber: Integer;
  const AAnnotationText: string);
begin
  if APlyNumber = 0 then
    ApplyAnnotationText(FRoot, AAnnotationText)
  else
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
  LDepth: string;
  LNode: TGameTreePlyNode;
  LScore: string;
  LPV: string;
  LTimeText: string;
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
  UpdateNodePV(LNode, True, LScore, LPV, LDepth, LTimeText);
  Result := True;
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
  LDepth: string;
  LNode: TGameTreePlyNode;
  LScore: string;
  LPV: string;
  LTimeText: string;
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
  UpdateNodePV(LNode, False, LScore, LPV, LDepth, LTimeText);
  Result := True;
end;

procedure TGameTree.TrimMainlineToCount(ACount: Integer);
begin
  if ACount < 0 then
    ACount := 0;
  if ACount < FMainline.Count then
    RemoveMainlineFrom(ACount + 1);
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

function TGameTree.CopyNodeMovesTo(ANode: TGameTreePlyNode;
  AMoves: TStrings): Boolean;
var
  Path: TStringList;
  I: Integer;
begin
  Result := False;
  if AMoves = nil then
    Exit;
  AMoves.Clear;
  if (ANode = nil) or (FindNodeById(ANode.NodeId) <> ANode) then
    Exit;
  Path := TStringList.Create;
  try
    while ANode <> FRoot do
    begin
      if ANode = nil then
        Exit;
      Path.Add(ANode.MoveText);
      ANode := ANode.Parent;
    end;
    for I := Path.Count - 1 downto 0 do
      AMoves.Add(Path[I]);
    Result := True;
  finally
    Path.Free;
  end;
end;

function TGameTree.TryBuildPositionAtNode(ANode: TGameTreePlyNode;
  APosition: TGamePosition): Boolean;
var
  Moves: TStringList;
  Candidate: TGamePosition;
  I: Integer;
begin
  Result := False;
  if APosition = nil then
    Exit;
  Moves := TStringList.Create;
  Candidate := nil;
  try
    if not CopyNodeMovesTo(ANode, Moves) then
      Exit;
    try
      Candidate := FVariant.CreatePositionFromFEN(FStartingFEN);
      // Validated replay: a tree restored from older files may hold a move
      // that does not replay, and callers report that (review U5).
      for I := 0 to Moves.Count - 1 do
        Candidate.PlayMoveText(Moves[I]);
      APosition.AssignFrom(Candidate);
      Result := True;
    except
      Result := False;
    end;
  finally
    Candidate.Free;
    Moves.Free;
  end;
end;

function TGameTree.FindNodeById(ANodeId: Int64): TGameTreePlyNode;
begin
  Result := nil;
  if ANodeId <= 0 then Exit;
  EnsureNodeIndex;
  Result := TGameTreePlyNode(FNodeIndex.Find(IntToStr(ANodeId)));
end;

function TGameTree.SideForPly(APlyNumber: Integer): TGameSide;
var
  LStartingSide: TGameSide;
begin
  LStartingSide := FVariant.SideFromFEN(FStartingFEN);
  if ((LStartingSide = gsWhite) and Odd(APlyNumber)) or
    ((LStartingSide = gsBlack) and (not Odd(APlyNumber))) then
    Result := gsWhite
  else
    Result := gsBlack;
end;

function TGameTree.MoveNumberForPly(APlyNumber: Integer): Integer;
begin
  Result := GameMoveNumberForPly(FVariant.SideFromFEN(FStartingFEN),
    FVariant.StartingMoveNumberFromFEN(FStartingFEN), APlyNumber);
end;

function TGameTree.AddMove(AParent: TGameTreePlyNode; APlyNumber: Integer;
  const AMoveText: string): TGameTreePlyNode;
begin
  if AParent = nil then
    AParent := FRoot;
  Result := AParent.AddChild;
  AssignNodeId(Result);
  Result.FPlyNumber := APlyNumber;
  Result.FMoveNumber := MoveNumberForPly(APlyNumber);
  Result.FSideToMove := SideForPly(APlyNumber);
  Result.FMoveText := Trim(AMoveText);
end;

function TGameTreeBranchPath.GetBasePly: Integer;
begin
  Result := 0;
  if (Length(Nodes) > 0) and (Nodes[0].Parent <> nil) then Result := Nodes[0].Parent.PlyNumber;
end;

function TGameTreeBranchPath.GetMovesText: string;
var I: Integer;
begin
  Result := '';
  for I := 0 to High(Nodes) do
  begin
    if Result <> '' then Result += ' ';
    Result += Nodes[I].MoveText;
  end;
end;

function TGameTreeBranchPath.GetAnnotationText: string;
var Lines: TStringList; I: Integer;
begin
  Lines := TStringList.Create;
  try
    for I := 0 to High(Nodes) do
      Lines.Add(AnnotationWithScore(AnnotationWithScore(Nodes[I].CommentText,
        'engine', Nodes[I].EngineScore), 'annotator', Nodes[I].AnnotatorScore));
    Result := EncodeVariationAnnotations(Lines);
  finally Lines.Free; end;
end;

function TGameTreeBranchPath.GetOriginText: string;
begin
  Result := '';
  if Length(Nodes) > 0 then Result := Nodes[0].OriginText;
end;

function TGameTree.IsMainlineNode(ANode: TGameTreePlyNode): Boolean;
begin
  Result := (ANode <> nil) and ((ANode = Root) or
    (GetMainlineNode(ANode.PlyNumber) = ANode));
end;

function TGameTree.RecordBranchMove(AParent: TGameTreePlyNode;
  const AMove: string): TGameTreePlyNode;
begin
  Result := FindChildByMove(AParent, AMove);
  if (Result = nil) and (AParent <> nil) then
    Result := AddMove(AParent, AParent.PlyNumber + 1, AMove);
end;

procedure TGameTree.SetNodeOrigin(ANode: TGameTreePlyNode; const AOrigin: string);
begin
  if (ANode <> nil) and (ANode.FOriginText = '') then ANode.FOriginText := AOrigin;
end;

function TGameTree.RecordNodeAnnotation(ANode: TGameTreePlyNode; const AText: string): Boolean;
var BeforeText, Text, Comment: string;
begin
  Result := False;
  if (ANode = nil) or (Trim(AText) = '') then Exit;
  BeforeText := ANode.CommentText + #10 + ANode.EngineScore + #10 + ANode.AnnotatorScore;
  Comment := AnnotationWithoutName(AnnotationWithoutName(
    AnnotationWithoutName(AText, 'engine'), 'annotator'), 'score');
  Text := AText;
  if (ANode.CommentText <> '') and (Pos(ANode.CommentText, Comment) = 0) then
  begin
    if Comment = '' then Comment := ANode.CommentText
    else Comment := ANode.CommentText + '; ' + Comment;
    Text := AnnotationWithScore(AnnotationWithScore(Comment,
      'engine', ExtractAnnotationValue(AText, 'engine')),
      'annotator', ExtractAnnotationValue(AText, 'annotator'));
  end;
  ApplyAnnotationText(ANode, Text);
  Result := BeforeText <> ANode.CommentText + #10 + ANode.EngineScore + #10 + ANode.AnnotatorScore;
end;

procedure TGameTree.ClearBranches;
begin
  RemoveVariationNodes(Root);
end;

procedure TGameTree.RemoveBranch(ANode: TGameTreePlyNode);
begin
  if not IsMainlineNode(ANode) then RemoveNodeFromParent(ANode);
end;

function TGameTree.BranchPaths: TGameTreeBranchPaths;
var I, J: Integer; Parent, Official: TGameTreePlyNode;
  procedure Visit(Node: TGameTreePlyNode; const Path: TGameTreeBranchPath);
  var Next: TGameTreeBranchPath; K, N: Integer;
  begin
    Next.Nodes := Copy(Path.Nodes);
    N := Length(Next.Nodes); SetLength(Next.Nodes, N + 1); Next.Nodes[N] := Node;
    if Node.ChildCount = 0 then
    begin
      N := Length(Result); SetLength(Result, N + 1); Result[N] := Next;
    end
    else for K := 0 to Node.ChildCount - 1 do Visit(Node.Children[K], Next);
  end;
var Empty: TGameTreeBranchPath;
begin
  Result := nil; Empty.Nodes := nil;
  for I := 0 to MainlineCount do
  begin
    if I = 0 then Parent := Root else Parent := MainlineNode[I];
    Official := MainlineNode[I + 1];
    for J := 0 to Parent.ChildCount - 1 do
      if Parent.Children[J] <> Official then Visit(Parent.Children[J], Empty);
  end;
end;

function TGameTree.GetBranchPath(AIndex: Integer): TGameTreeBranchPath;
var Paths: TGameTreeBranchPaths;
begin
  Result.Nodes := nil; Paths := BranchPaths;
  if (AIndex >= 0) and (AIndex < Length(Paths)) then Result := Paths[AIndex];
end;

function TGameTree.GetBranchCount: Integer;
begin
  Result := Length(BranchPaths);
end;

function TGameTree.FindBranchNode(AIndex, APly: Integer): TGameTreePlyNode;
var Path: TGameTreeBranchPath;
begin
  Result := nil; Path := GetBranchPath(AIndex);
  if (APly > 0) and (APly <= Length(Path.Nodes)) then Result := Path.Nodes[APly - 1];
end;

function TGameTree.FindChildByMove(AParent: TGameTreePlyNode;
  const AMove: string): TGameTreePlyNode;
var
  I: Integer;
begin
  Result := nil;
  if AParent = nil then Exit;
  for I := 0 to AParent.ChildCount - 1 do
    if FVariant.SameMove(AParent.Children[I].MoveText, AMove) then
      Exit(AParent.Children[I]);
end;

function TGameTree.AddMainlineMove(APlyNumber: Integer;
  const AMoveText: string): TGameTreePlyNode;
var
  ParentNode: TGameTreePlyNode;
begin
  Result := nil;
  if APlyNumber <= 0 then Exit;
  if APlyNumber = 1 then ParentNode := FRoot
  else ParentNode := GetMainlineNode(APlyNumber - 1);
  if ParentNode = nil then Exit;
  Result := FindChildByMove(ParentNode, AMoveText);
  if Result = nil then Result := AddMove(ParentNode, APlyNumber, AMoveText);
  // The first child is always the official continuation at a mainline position.
  // Reuse a previously explored node, retaining its identity and metadata.
  ParentNode.FChildren.Move(ParentNode.FChildren.IndexOf(Result), 0);
  while FMainline.Count < APlyNumber do FMainline.Add(nil);
  FMainline[APlyNumber - 1] := Result;
end;

procedure TGameTree.UpdateNodePV(ANode: TGameTreePlyNode; AEngine: Boolean;
  const AScore, APV, ADepth, ATimeText: string);
begin
  if ANode = nil then
    Exit;
  if AEngine then
  begin
    if Trim(AScore) <> '' then
      ANode.FEngineScore := Trim(AScore);
    ANode.FEnginePV := Trim(APV);
    if Trim(ADepth) <> '' then
      ANode.FEnginePVDepth := Trim(ADepth);
    if Trim(ATimeText) <> '' then
      ANode.FEnginePVTimeText := Trim(ATimeText);
  end
  else
  begin
    ANode.FAnnotatorScore := Trim(AScore);
    ANode.FAnnotatorPV := Trim(APV);
    if Trim(ADepth) <> '' then
      ANode.FAnnotatorPVDepth := Trim(ADepth);
    if Trim(ATimeText) <> '' then
      ANode.FAnnotatorPVTimeText := Trim(ATimeText);
  end;
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
  UpdateNodePV(Node, True, AScore, APV, ADepth, ATimeText);
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
  UpdateNodePV(Node, False, AScore, APV, ADepth, ATimeText);
end;

end.
