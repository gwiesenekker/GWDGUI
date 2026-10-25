unit uGameTree;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils, uDraughtsBoard, uGameOrchestrator, uGameMoveHistory;

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
    FNodeId: Int64;
    FParent: TGameTreePlyNode;
    FPlyNumber: Integer;
    FSideToMove: TDraughtsSide;
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
    property HasMoveTime: Boolean read FHasMoveTime;
    property SecondsUsed: Double read FSecondsUsed;
    property MoveNumber: Integer read FMoveNumber;
    property MoveText: string read FMoveText;
    property NodeId: Int64 read FNodeId;
    property Parent: TGameTreePlyNode read FParent;
    property PlyNumber: Integer read FPlyNumber;
    property SideToMove: TDraughtsSide read FSideToMove;
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
    FNodeIds: array of Int64;
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
    procedure ClearStructure;
    procedure UpdateNodePV(ANode: TGameTreePlyNode; AEngine: Boolean;
      const AScore, APV, ADepth, ATimeText: string);
    procedure ClearTreeMetadata;
    function IncrementModeCaption(AMode: TClockIncrementMode): string;
    function SideForPly(APlyNumber: Integer): TDraughtsSide;
    function MoveNumberForPly(APlyNumber: Integer): Integer;
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
    function GetVariationLine(AIndex: Integer): TGameTreeVariationLine;
    function GetVariationLineCount: Integer;
    procedure AssignNodeId(ANode: TGameTreePlyNode);
    procedure RemoveMainlineFrom(APlyNumber: Integer);
    procedure RemoveNodeFromParent(ANode: TGameTreePlyNode);
    procedure RemoveVariationNodes(ANode: TGameTreePlyNode);
    procedure PruneUnreferencedVariations(ANode: TGameTreePlyNode);
    function FindStoredVariation(ADisplayAfterPly, ABasePly: Integer;
      const AMovesText: string): Integer;
    procedure SetNodeClockState(ANode: TGameTreePlyNode;
      AWhiteRemainingSeconds, ABlackRemainingSeconds, AWhiteUsedSeconds,
      ABlackUsedSeconds: Double);
    function UpdateVariationLine(AVariationLine: TGameTreeVariationLine;
      ADisplayAfterPly, ABasePly: Integer; const AMovesText,
      AAnnotationText: string): Boolean;
  public
    function TryLocateVariationNode(ANode: TGameTreePlyNode;
      out ABase, ADisplay, AIndex, APly: Integer): Boolean;
    function FindChildByMove(AParent: TGameTreePlyNode; const AMove: string): TGameTreePlyNode;
    function RecordCompletedMoveData(APly: Integer; const AData: TGameMoveData): Boolean;
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
    procedure RecordVariationAnnotation(ABasePlyNumber, ADisplayAfterPly,
      AVariationIndex, AVariationPlyNumber: Integer;
      const AAnnotationText: string);
    procedure ClearStoredVariations;
    procedure RemoveStoredVariationLineAtIndex(AIndex: Integer);
    procedure CopyMainlineMovesTo(AMoves: TStrings);
    function CopyNodeMovesTo(ANode: TGameTreePlyNode; AMoves: TStrings): Boolean;
    function TryBuildBoardAtNode(ANode: TGameTreePlyNode;
      ABoard: TDraughtsBoard): Boolean;
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
    property Signature: string read FSignature;
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
  FVariationLines := TObjectList.Create(True);
  FRoot := TGameTreePlyNode.Create;
  Clear;
end;

destructor TGameTree.Destroy;
begin
  FRoot.Free;
  FVariationLines.Free;
  FMainline.Free;
  inherited Destroy;
end;

procedure TGameTree.Clear;
begin
  FVariationLines.Clear;
  FSignature := '';
  ClearStructure;
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
    if GetMainlineNode(Child.PlyNumber) <> Child then
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
    FVariationLines.Clear;
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

function TGameTree.RecordCompletedMoveData(APly: Integer;
  const AData: TGameMoveData): Boolean;
var
  Node, ParentNode: TGameTreePlyNode;
begin
  Result := False;
  Node := GetMainlineNode(APly);
  if (Node = nil) or
    (NormalizeMoveNotation(Node.MoveText) <> NormalizeMoveNotation(AData.MoveText)) then Exit;
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

function TGameTree.RecordVariationMove(AParent: TGameTreePlyNode;
  ABasePlyNumber, ADisplayAfterPly, AVariationIndex,
  AVariationPlyNumber: Integer; const AMoveText: string): TGameTreePlyNode;
var
  Line: TGameTreeVariationLine;
begin
  Result := nil;
  Line := GetVariationLine(AVariationIndex);
  if (AParent = nil) or (Line = nil) or (AVariationPlyNumber <= 0) then
    Exit;
  // A position owns each continuation once. Legacy lines only index paths.
  Result := FindChildByMove(AParent, AMoveText);
  if Result = nil then
    Result := AddMove(AParent, AParent.PlyNumber + 1, AMoveText);
  if Length(Line.FNodeIds) < AVariationPlyNumber then
    SetLength(Line.FNodeIds, AVariationPlyNumber);
  Line.FNodeIds[AVariationPlyNumber - 1] := Result.NodeId;
end;

procedure TGameTree.RecordVariationEnginePV(ABasePlyNumber,
  ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
  const AScore, APV: string; const ADepth: string; const ATimeText: string);
begin
  UpdateNodePV(FindVariationNode(AVariationIndex, AVariationPlyNumber),
    True, AScore, APV, ADepth, ATimeText);
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

procedure TGameTree.RecordVariationAnnotatorPV(ABasePlyNumber,
  ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
  const AScore, APV: string; const ADepth: string; const ATimeText: string);
begin
  UpdateNodePV(FindVariationNode(AVariationIndex, AVariationPlyNumber),
    False, AScore, APV, ADepth, ATimeText);
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

procedure TGameTree.RecordVariationAnnotation(ABasePlyNumber,
  ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
  const AAnnotationText: string);
var
  LNode: TGameTreePlyNode;
  Base, Display, Index, Ply: Integer;
  Canonical: Boolean;
begin
  LNode := FindVariationNode(AVariationIndex, AVariationPlyNumber);
  Canonical := TryLocateVariationNode(LNode, Base, Display, Index, Ply) and
    (Index = AVariationIndex) and (Ply = AVariationPlyNumber);
  if (LNode <> nil) and not Canonical and
    (LNode.CommentText <> '') and (AAnnotationText = '') then Exit;
  if (LNode <> nil) and not Canonical and
    (LNode.CommentText <> '') and (Pos(LNode.CommentText, AAnnotationText) = 0) then
    ApplyAnnotationText(LNode, LNode.CommentText + '; ' + AAnnotationText)
  else
    ApplyAnnotationText(LNode, AAnnotationText);
end;

procedure TGameTree.RemoveStoredVariationLineAtIndex(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FVariationLines.Count) then Exit;
  FVariationLines.Delete(AIndex);
  PruneUnreferencedVariations(FRoot);
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

procedure TGameTree.PruneUnreferencedVariations(ANode: TGameTreePlyNode);
var
  I, J, K: Integer;
  Child: TGameTreePlyNode;
  Line: TGameTreeVariationLine;
  Referenced: Boolean;
begin
  if ANode = nil then
    Exit;
  for I := ANode.ChildCount - 1 downto 0 do
  begin
    Child := ANode.Children[I];
    PruneUnreferencedVariations(Child);
    if GetMainlineNode(Child.PlyNumber) = Child then
      Continue;
    Referenced := False;
    for J := 0 to VariationLineCount - 1 do
    begin
      Line := VariationLine[J];
      for K := 0 to High(Line.FNodeIds) do
        if Line.FNodeIds[K] = Child.NodeId then
        begin
          Referenced := True;
          Break;
        end;
      if Referenced then
        Break;
    end;
    if (not Referenced) and (Child.ChildCount = 0) then
      RemoveNodeFromParent(Child);
  end;
end;

procedure TGameTree.TrimVariationLine(ABasePlyNumber, ADisplayAfterPly,
  AVariationIndex, AVariationMoveCount: Integer);
var
  Line: TGameTreeVariationLine;
begin
  Line := GetVariationLine(AVariationIndex);
  if Line = nil then
    Exit;
  if AVariationMoveCount < 0 then
    AVariationMoveCount := 0;
  if Length(Line.FNodeIds) > AVariationMoveCount then
    SetLength(Line.FNodeIds, AVariationMoveCount);
  PruneUnreferencedVariations(FRoot);
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

function CanonicalMoveLine(const AMovesText: string): string;
var
  Moves: TStringList;
  I: Integer;
begin
  Result := '';
  Moves := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)), Moves);
    for I := 0 to Moves.Count - 1 do
    begin
      if Result <> '' then
        Result += ' ';
      Result += NormalizeMoveNotation(Moves[I]);
    end;
  finally
    Moves.Free;
  end;
end;

function TGameTree.FindStoredVariation(ADisplayAfterPly, ABasePly: Integer;
  const AMovesText: string): Integer;
var
  I: Integer;
  NewMoves: string;
  VariationEntry: TGameTreeVariationLine;
begin
  Result := -1;
  NewMoves := CanonicalMoveLine(AMovesText);
  for I := 0 to FVariationLines.Count - 1 do
  begin
    VariationEntry := TGameTreeVariationLine(FVariationLines[I]);
    if (VariationEntry = nil) or
      (VariationEntry.FDisplayAfterPly <> ADisplayAfterPly) or
      (VariationEntry.FBasePly <> ABasePly) then
      Continue;

    if CanonicalMoveLine(VariationEntry.FMovesText) = NewMoves then
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

function TGameTree.TryBuildBoardAtNode(ANode: TGameTreePlyNode;
  ABoard: TDraughtsBoard): Boolean;
var
  Moves: TStringList;
  Candidate: TDraughtsBoard;
  I: Integer;
begin
  Result := False;
  if ABoard = nil then
    Exit;
  Moves := TStringList.Create;
  Candidate := TDraughtsBoard.Create;
  try
    if not CopyNodeMovesTo(ANode, Moves) then
      Exit;
    try
      if Trim(FStartingFEN) = '' then
        Candidate.LoadFromFEN(DefaultStartingFEN)
      else
        Candidate.LoadFromFEN(FStartingFEN);
      for I := 0 to Moves.Count - 1 do
        Candidate.PlayMove(Moves[I], True, True);
      ABoard.AssignFrom(Candidate);
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

  if AVariationPlyNumber <= Length(LVariationLine.FNodeIds) then
    Result := FindNodeById(LVariationLine.FNodeIds[AVariationPlyNumber - 1]);
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

function TGameTree.MoveNumberForPly(APlyNumber: Integer): Integer;
begin
  if FenStartingSide(FStartingFEN) = dsBlack then
    Result := (APlyNumber div 2) + 1
  else
    Result := ((APlyNumber - 1) div 2) + 1;
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

function TGameTree.TryLocateVariationNode(ANode: TGameTreePlyNode;
  out ABase, ADisplay, AIndex, APly: Integer): Boolean;
var
  I, J: Integer;
  Line: TGameTreeVariationLine;
begin
  Result := False;
  ABase := -1; ADisplay := -1; AIndex := -1; APly := -1;
  if (ANode = nil) or (ANode = FRoot) or
    (GetMainlineNode(ANode.PlyNumber) = ANode) then Exit;
  // Compatibility locations are derived from node identity, never parsed from
  // an alias that can change when another path is removed or reindexed.
  for I := 0 to FVariationLines.Count - 1 do
  begin
    Line := GetVariationLine(I);
    for J := 0 to High(Line.FNodeIds) do
      if Line.FNodeIds[J] = ANode.NodeId then
      begin
        ABase := Line.BasePly; ADisplay := Line.DisplayAfterPly;
        AIndex := I; APly := J + 1;
        Exit(True);
      end;
  end;
end;

function TGameTree.FindChildByMove(AParent: TGameTreePlyNode;
  const AMove: string): TGameTreePlyNode;
var
  I: Integer;
begin
  Result := nil;
  if AParent = nil then Exit;
  for I := 0 to AParent.ChildCount - 1 do
    if NormalizeMoveNotation(AParent.Children[I].MoveText) = NormalizeMoveNotation(AMove) then
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
