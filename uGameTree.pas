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
    PlyNumber: Integer;
    MoveNumber: Integer;
    SideToMove: TDraughtsSide;
    MoveText: string;
    EngineScore: string;
    EnginePV: string;
    AnnotatorScore: string;
    AnnotatorPV: string;
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
    FAnnotatorScoresByPly: TStringList;
    FClockStatesByPly: TObjectList;
    FEnginePvsByPly: TStringList;
    FEngineScoresByPly: TStringList;
    FVariationAnnotatorPvsByKey: TStringList;
    FVariationAnnotatorScoresByKey: TStringList;
    FVariationEnginePvsByKey: TStringList;
    FVariationEngineScoresByKey: TStringList;
    FVariationLines: TObjectList;
    FMainline: TFPList;
    FRoot: TGameTreePlyNode;
    FSignature: string;
    procedure ApplyAnnotationText(ANode: TGameTreePlyNode;
      const AAnnotationText: string);
    procedure ApplyStoredAnalysis(ANode: TGameTreePlyNode; APlyNumber: Integer);
    procedure ClearObservedAnalysis;
    procedure ClearStructure;
    function IncrementModeCaption(AMode: TClockIncrementMode): string;
    function SideForPly(APlyNumber: Integer): TDraughtsSide;
    function AddMove(AParent: TGameTreePlyNode; APlyNumber: Integer;
      const AMoveText: string): TGameTreePlyNode;
    function AddMainlineMove(APlyNumber: Integer;
      const AMoveText: string): TGameTreePlyNode;
    procedure AddEnginePV(APlyNumber: Integer; const AScore, APV: string);
    procedure AddAnnotatorPV(APlyNumber: Integer; const AScore, APV: string);
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
    function GetStoredClockState(APlyNumber: Integer): TGameTreeClockState;
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
      AStartingFEN: string);
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
    procedure RecordEnginePV(APlyNumber: Integer; const AScore, APV: string);
    procedure RecordAnnotatorPV(APlyNumber: Integer; const AScore, APV: string);
    function RecordVariationMove(AParent: TGameTreePlyNode; ABasePlyNumber,
      ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
      const AMoveText: string): TGameTreePlyNode;
    procedure RecordVariationEnginePV(ABasePlyNumber, ADisplayAfterPly,
      AVariationIndex, AVariationPlyNumber: Integer; const AScore,
      APV: string);
    procedure RecordVariationAnnotatorPV(ABasePlyNumber, ADisplayAfterPly,
      AVariationIndex, AVariationPlyNumber: Integer; const AScore,
      APV: string);
    procedure RecordVariationAnnotation(ABasePlyNumber, ADisplayAfterPly,
      AVariationIndex, AVariationPlyNumber: Integer;
      const AAnnotationText: string);
    procedure ClearStoredVariations;
    procedure CopyMainlineMovesTo(AMoves: TStrings);
    function FindStoredVariationByDisplayAfterPly(
      ADisplayAfterPly: Integer): Integer;
    function StoreVariationLine(ADisplayAfterPly, ABasePly: Integer;
      const AMovesText, AAnnotationText: string): Integer;
    property Root: TGameTreePlyNode read FRoot;
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
  FMainline := TFPList.Create;
  FEngineScoresByPly := TStringList.Create;
  FEnginePvsByPly := TStringList.Create;
  FAnnotatorScoresByPly := TStringList.Create;
  FAnnotatorPvsByPly := TStringList.Create;
  FClockStatesByPly := TObjectList.Create(True);
  FVariationEngineScoresByKey := TStringList.Create;
  FVariationEnginePvsByKey := TStringList.Create;
  FVariationAnnotatorScoresByKey := TStringList.Create;
  FVariationAnnotatorPvsByKey := TStringList.Create;
  FVariationLines := TObjectList.Create(True);
  FRoot := TGameTreePlyNode.Create;
  Clear;
end;

destructor TGameTree.Destroy;
begin
  FRoot.Free;
  FVariationLines.Free;
  FVariationAnnotatorPvsByKey.Free;
  FVariationAnnotatorScoresByKey.Free;
  FVariationEnginePvsByKey.Free;
  FVariationEngineScoresByKey.Free;
  FClockStatesByPly.Free;
  FAnnotatorPvsByPly.Free;
  FAnnotatorScoresByPly.Free;
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
  FAnnotatorScoresByPly.Clear;
  FAnnotatorPvsByPly.Clear;
  FClockStatesByPly.Clear;
  FVariationEngineScoresByKey.Clear;
  FVariationEnginePvsByKey.Clear;
  FVariationAnnotatorScoresByKey.Clear;
  FVariationAnnotatorPvsByKey.Clear;
  ClearStoredVariations;
end;

procedure TGameTree.ClearStructure;
begin
  FRoot.Free;
  FRoot := TGameTreePlyNode.Create;
  FMainline.Clear;
  EventName := '?';
  WhiteName := 'White';
  BlackName := 'Black';
  ResultText := '*';
  StartingFEN := '';
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

procedure TGameTree.BeginRebuild(const ASignature, AEventName, AWhiteName,
  ABlackName, AResultText, AStartingFEN: string);
begin
  if FSignature <> ASignature then
  begin
    ClearObservedAnalysis;
    FSignature := ASignature;
  end;
  ClearStructure;
  SetHeader(AEventName, AWhiteName, ABlackName, AResultText, AStartingFEN);
  ApplyStoredAnalysis(FRoot, 0);
end;

procedure TGameTree.SetHeader(const AEventName, AWhiteName, ABlackName,
  AResultText, AStartingFEN: string);
begin
  EventName := AEventName;
  WhiteName := AWhiteName;
  BlackName := ABlackName;
  ResultText := AResultText;
  StartingFEN := AStartingFEN;
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
end;

function TGameTree.RecordMainlineMove(APlyNumber: Integer;
  const AMoveText: string): TGameTreePlyNode;
begin
  Result := GetMainlineNode(APlyNumber);
  if Result = nil then
  begin
    Result := AddMainlineMove(APlyNumber, AMoveText);
    Exit;
  end;

  Result.PlyNumber := APlyNumber;
  Result.MoveNumber := ((APlyNumber - 1) div 2) + 1;
  Result.SideToMove := SideForPly(APlyNumber);
  Result.MoveText := Trim(AMoveText);
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
  APV: string);
begin
  AddEnginePV(APlyNumber, AScore, APV);
end;

procedure TGameTree.RecordAnnotatorPV(APlyNumber: Integer; const AScore,
  APV: string);
begin
  AddAnnotatorPV(APlyNumber, AScore, APV);
end;

function TGameTree.RecordVariationMove(AParent: TGameTreePlyNode;
  ABasePlyNumber, ADisplayAfterPly, AVariationIndex,
  AVariationPlyNumber: Integer; const AMoveText: string): TGameTreePlyNode;
begin
  Result := AddMove(AParent, ABasePlyNumber + AVariationPlyNumber,
    AMoveText);
  if Result = nil then
    Exit;
  Result.VariationKey := BuildVariationKey(ABasePlyNumber, ADisplayAfterPly,
    AVariationIndex, AVariationPlyNumber);
  ApplyStoredVariationAnalysis(Result, Result.VariationKey);
end;

procedure TGameTree.RecordVariationEnginePV(ABasePlyNumber,
  ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
  const AScore, APV: string);
var
  LVariationKey: string;
begin
  LVariationKey := BuildVariationKey(ABasePlyNumber, ADisplayAfterPly,
    AVariationIndex, AVariationPlyNumber);
  StoreKeyValue(FVariationEngineScoresByKey, LVariationKey, AScore);
  StoreKeyValue(FVariationEnginePvsByKey, LVariationKey, APV);
end;

procedure TGameTree.RecordVariationAnnotatorPV(ABasePlyNumber,
  ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
  const AScore, APV: string);
var
  LVariationKey: string;
begin
  LVariationKey := BuildVariationKey(ABasePlyNumber, ADisplayAfterPly,
    AVariationIndex, AVariationPlyNumber);
  StoreKeyValue(FVariationAnnotatorScoresByKey, LVariationKey, AScore);
  StoreKeyValue(FVariationAnnotatorPvsByKey, LVariationKey, APV);
end;

procedure TGameTree.RecordVariationAnnotation(ABasePlyNumber,
  ADisplayAfterPly, AVariationIndex, AVariationPlyNumber: Integer;
  const AAnnotationText: string);
begin
  ApplyAnnotationText(FindVariationNodeByKey(BuildVariationKey(ABasePlyNumber,
    ADisplayAfterPly, AVariationIndex, AVariationPlyNumber)),
    AAnnotationText);
end;

procedure TGameTree.ClearStoredVariations;
begin
  FVariationLines.Clear;
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

function TGameTree.StoreVariationLine(ADisplayAfterPly, ABasePly: Integer;
  const AMovesText, AAnnotationText: string): Integer;
var
  VariationEntry: TGameTreeVariationLine;
begin
  Result := -1;
  if (ADisplayAfterPly < 0) or (ABasePly < 0) then
    Exit;

  Result := FindStoredVariationByDisplayAfterPly(ADisplayAfterPly);
  if Result < 0 then
  begin
    VariationEntry := TGameTreeVariationLine.Create;
    Result := FVariationLines.Add(VariationEntry);
  end
  else
    VariationEntry := TGameTreeVariationLine(FVariationLines[Result]);

  VariationEntry.DisplayAfterPly := ADisplayAfterPly;
  VariationEntry.BasePly := ABasePly;
  VariationEntry.MovesText := Trim(AMovesText);
  VariationEntry.AnnotationText := Trim(AAnnotationText);
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
  ANode.AnnotatorScore := GetStoredValue(FAnnotatorScoresByPly, APlyNumber);
  ANode.AnnotatorPV := GetStoredValue(FAnnotatorPvsByPly, APlyNumber);
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
  ANode.AnnotatorScore := GetStoredKeyValue(FVariationAnnotatorScoresByKey,
    AVariationKey);
  ANode.AnnotatorPV := GetStoredKeyValue(FVariationAnnotatorPvsByKey,
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

function TGameTree.AddMove(AParent: TGameTreePlyNode; APlyNumber: Integer;
  const AMoveText: string): TGameTreePlyNode;
begin
  if AParent = nil then
    AParent := FRoot;
  Result := AParent.AddChild;
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

procedure TGameTree.AddEnginePV(APlyNumber: Integer; const AScore, APV: string);
var
  Node: TGameTreePlyNode;
begin
  if APlyNumber = 0 then
    Node := FRoot
  else
    Node := GetMainlineNode(APlyNumber);
  if Node = nil then
    Exit;
  StoreValue(FEngineScoresByPly, APlyNumber, AScore);
  StoreValue(FEnginePvsByPly, APlyNumber, APV);
  ApplyStoredAnalysis(Node, APlyNumber);
end;

procedure TGameTree.AddAnnotatorPV(APlyNumber: Integer; const AScore,
  APV: string);
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
  ApplyStoredAnalysis(Node, APlyNumber);
end;

end.
