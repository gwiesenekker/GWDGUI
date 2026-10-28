unit uGameTreeActor;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils,
  uGameTree, uGameTreeBuilder, uGameTreeSearchRef, uThreadMessageQueue, uGameMoveHistory, uGameTreeNodeData, uDraughtsPdn;

type
  TGameTreeMoveSource = (
    gmsUnknown,
    gmsHuman,
    gmsEngineMatch
  );

  TGameTreeActorCommandKind = (
    gtcAddMainlineMove,
    gtcAppendMainlineMove,
    gtcAppendMainlineSnapshotMove,
    gtcImportBranch,
    gtcImportNode,
    gtcStartSearch,
    gtcCancelSearch,
    gtcSearchDone,
    gtcReleaseSearch,
    gtcRecordEnginePV,
    gtcRecordAnnotatorPV,
    gtcRecordAutoPlayPV,
    gtcStoreMoveVariation,
    gtcClearBranches,
    gtcRebuildFromInputs,
    gtcSetHeader,
    gtcRestoreNodeData,
    gtcImportPdnTree
  );

  TGameTreeSearchState = (
    gssActive,
    gssCancelled,
    gssDone,
    gssFailed
  );

  TGameTreeImportMove = record
    MoveText: string;
    AnnotationText: string;
  end;
  TGameTreeImportMoves = array of TGameTreeImportMove;

  TGameTreeCommand = class;

  TGameTreeSearchRecord = class
  public
    SearchId: Int64;
    GameTreeId: Int64;
    NodeId: Int64;
    State: TGameTreeSearchState;
    ResultMove: string;
    function SearchRef: TGameTreeSearchRef;
  end;

  TGameTreeCommandCallback = procedure(ACommand: TGameTreeCommand) of object;

  TGameTreeCommand = class(TThreadMessage)
  public
    CommandId: Int64;
    CommandKind: TGameTreeActorCommandKind;
    GameTreeId: Int64;
    NodeId: Int64;
    SearchId: Int64;
    MoveText: string;
    AnnotationText: string;
    ImportMoves: TGameTreeImportMoves;
    ImportRoot: TPdnMoveNode;
    ImportWarnings: TStringList;
    ValidatedMoveCount, ImportedMoveCount: Integer;
    MoveSource: TGameTreeMoveSource;
    NodeData: TGameTreeNodeData;
    HeaderInput: TGameTreeHeaderInput;
    MainlineInput: TGameTreeMainlineInput;
    EnginePvInput: TGameTreePvInput;
    AnnotatorPvInput: TGameTreePvInput;
    PlyNumber: Integer;
    Accepted: Boolean;
    TreeChanged: Boolean;
    ErrorText: string;
    CreatedNodeId: Int64;
    ScoreText: string;
    PvText: string;
    PvDepthText: string;
    PvTimeText: string;
    constructor Create(AKind: TGameTreeActorCommandKind); reintroduce;
    destructor Destroy; override;
    function SearchRef: TGameTreeSearchRef;
    procedure SetSearchRef(const ASearch: TGameTreeSearchRef);
  end;

  TGameTreeActor = class
  private
    FCommandQueue: TThreadMessageQueue;
    FGameTree: TGameTree;
    FLastRebuildSignature: string;
    FNextCommandId: Int64;
    FNextSearchId: Int64;
    FOwnsGameTree: Boolean;
    FRevision: Int64;
    FSearches: TObjectList;
    procedure CopyMainlineInputToCommand(ACommand: TGameTreeCommand;
      const AMainline: TGameTreeMainlineInput; AIncludeMoves: Boolean);
    function CommandRebuildSignature(ACommand: TGameTreeCommand): string;
    function MoveSourceOriginText(ASource: TGameTreeMoveSource): string;
    procedure ClearRebuildSignature;
    function ValidateMoveCommand(ACommand: TGameTreeCommand): Boolean;
    procedure ExecuteImportPdnTree(ACommand: TGameTreeCommand;
      var AInvalidateRebuildSignature: Boolean);
    function CreateCommand(AKind: TGameTreeActorCommandKind): TGameTreeCommand;
    function CreateRecordPVCommand(AKind: TGameTreeActorCommandKind;
      ANodeId: Int64; const AScore, APV, ADepth,
      ATimeText: string): TGameTreeCommand;
    function FindSearch(ASearchId: Int64): TGameTreeSearchRecord; overload;
    function FindSearch(const ASearch: TGameTreeSearchRef
      ): TGameTreeSearchRecord; overload;
    function NextCommandId: Int64;
    function NextSearchId: Int64;
    function MarkMissingTargetSearchesFailed: Boolean;
    function RemoveSearch(ASearchId: Int64): Boolean;
    function ResolveSearchCommand(ACommand: TGameTreeCommand;
      out ASearch: TGameTreeSearchRecord): Boolean;
    function SearchCommandMatches(ACommand: TGameTreeCommand;
      ASearch: TGameTreeSearchRecord): Boolean;
    procedure AcceptActorStateChange(ACommand: TGameTreeCommand);
    procedure AcceptTreeMutation(ACommand: TGameTreeCommand;
      var AInvalidateRebuildSignature: Boolean;
      AInvalidateSignature: Boolean = True);
    function ApplyHeaderInput(const AHeader: TGameTreeHeaderInput): Boolean;
    procedure ExecuteRecordPVCommand(ACommand: TGameTreeCommand;
      var AInvalidateRebuildSignature: Boolean;
      ARecordEnginePV: Boolean);
    procedure ExecuteStoreMoveVariationCommand(ACommand: TGameTreeCommand;
      ANode: TGameTreePlyNode; const AMoveText: string;
      var AInvalidateRebuildSignature: Boolean);
    procedure Reject(ACommand: TGameTreeCommand; const AErrorText: string);
    function StoreMoveVariationFromNode(ACommand: TGameTreeCommand;
      ANode: TGameTreePlyNode; const AMoveText: string;
      out AChanged: Boolean): Boolean;
  public
    constructor Create(AGameTree: TGameTree = nil;
      AOwnsGameTree: Boolean = True);
    destructor Destroy; override;

    function CreateAddMainlineMoveCommand(APlyNumber: Integer;
      const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
    function CreateAppendMainlineMoveCommand(const AMoveText: string;
      ASource: TGameTreeMoveSource): TGameTreeCommand;
    function CreateAppendMainlineSnapshotMoveCommand(
      const AHeader: TGameTreeHeaderInput; const AMoveText,
      AAnnotationText: string; const AMainline: TGameTreeMainlineInput;
      const AEnginePV: TGameTreePvInput;
      ASource: TGameTreeMoveSource): TGameTreeCommand;
    function CreateCancelSearchCommand(ASearchId: Int64): TGameTreeCommand; overload;
    function CreateCancelSearchCommand(
      const ASearch: TGameTreeSearchRef): TGameTreeCommand; overload;
    function CreateReleaseSearchCommand(ASearchId: Int64): TGameTreeCommand; overload;
    function CreateReleaseSearchCommand(
      const ASearch: TGameTreeSearchRef): TGameTreeCommand; overload;
    function CreateSearchDoneCommand(ASearchId: Int64;
      const AMoveText: string): TGameTreeCommand; overload;
    function CreateSearchDoneCommand(const ASearch: TGameTreeSearchRef;
      const AMoveText: string): TGameTreeCommand; overload;
    function CreateRecordEnginePVCommand(ANodeId: Int64; const AScore,
      APV: string; const ADepth: string = '';
      const ATimeText: string = ''): TGameTreeCommand;
    function CreateRecordAnnotatorPVCommand(ANodeId: Int64; const AScore,
      APV: string; const ADepth: string = '';
      const ATimeText: string = ''): TGameTreeCommand;
    function CreateRecordAutoPlayPVCommand(ANodeId: Int64;
      const APV: string): TGameTreeCommand;
    function CreateStoreMoveVariationCommand(ANodeId: Int64;
      const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
    function CreateClearBranchesCommand: TGameTreeCommand;
    function CreateRebuildFromInputsCommand(
      const AHeader: TGameTreeHeaderInput;
      const AMainline: TGameTreeMainlineInput;
      const AEnginePV, AAnnotatorPV: TGameTreePvInput;
      AAnalysisNodeId: Int64 = 0;
      const AVariationPvScore: string = '';
      const AVariationPvText: string = ''; const AVariationPvDepth: string = '';
      const AVariationPvTimeText: string = ''): TGameTreeCommand;
    function CreateSetHeaderCommand(const AHeader: TGameTreeHeaderInput
      ): TGameTreeCommand; overload;
    function CreateSetHeaderCommand(const AHeader: TGameTreeHeaderInput;
      const AMainline: TGameTreeMainlineInput): TGameTreeCommand; overload;
    function CreateStartSearchCommand(ANodeId: Int64;
      out ASearchId: Int64): TGameTreeCommand; overload;
    function CreateStartSearchCommand(ANodeId: Int64;
      out ASearch: TGameTreeSearchRef): TGameTreeCommand; overload;
    function CreateRestoreNodeDataCommand(ANodeId: Int64; const Data: TGameTreeNodeData): TGameTreeCommand;
    function CreateImportPdnTreeCommand(ARoot: TPdnMoveNode): TGameTreeCommand;
    function CreateImportNodeCommand(AParentNodeId: Int64;
      const AMoveText, AAnnotationText: string): TGameTreeCommand;
    function CreateImportBranchCommand(AParentNodeId: Int64;
      const AMoves: TGameTreeImportMoves;
      ASource: TGameTreeMoveSource = gmsUnknown): TGameTreeCommand;

    procedure ExecuteCommand(ACommand: TGameTreeCommand);
    function PostCommand(ACommand: TGameTreeCommand): Boolean;
    function ProcessCommands: Integer; overload;
    function ProcessCommands(AAfterExecute: TGameTreeCommandCallback): Integer; overload;
    function SearchResult(ASearchId: Int64; out ANodeId: Int64;
      out AMoveText: string): Boolean; overload;
    function SearchResult(const ASearch: TGameTreeSearchRef;
      out ANodeId: Int64; out AMoveText: string): Boolean; overload;
    function SearchState(ASearchId: Int64;
      out AState: TGameTreeSearchState): Boolean; overload;
    function SearchState(const ASearch: TGameTreeSearchRef;
      out AState: TGameTreeSearchState): Boolean; overload;

    property GameTree: TGameTree read FGameTree;
    property Revision: Int64 read FRevision;
  end;

implementation

uses
  uGamePosition, Math;

function TGameTreeSearchRecord.SearchRef: TGameTreeSearchRef;
begin
  Result := GameTreeSearchRef(GameTreeId, SearchId, NodeId);
end;

constructor TGameTreeCommand.Create(AKind: TGameTreeActorCommandKind);
const
  CommandNames: array[TGameTreeActorCommandKind] of string = (
    'game-tree-add-mainline-move',
    'game-tree-append-mainline-move',
    'game-tree-append-mainline-snapshot-move',
    'game-tree-import-branch',
    'game-tree-import-node',
    'game-tree-start-search',
    'game-tree-cancel-search',
    'game-tree-search-done',
    'game-tree-release-search',
    'game-tree-record-engine-pv',
    'game-tree-record-annotator-pv',
    'game-tree-record-auto-play-pv',
    'game-tree-store-move-variation',
    'game-tree-clear-branches',
    'game-tree-rebuild-from-inputs',
    'game-tree-set-header',
    'game-tree-restore-node-data',
    'game-tree-import-pdn-tree'
  );
begin
  inherited Create(CommandNames[AKind]);
  CommandKind := AKind;
  MoveSource := gmsUnknown;
  MainlineInput.Moves := TStringList.Create;
  MainlineInput.Annotations := TStringList.Create;
  PlyNumber := -1;
end;

destructor TGameTreeCommand.Destroy;
begin
  ImportRoot.Free;
  ImportWarnings.Free;
  MainlineInput.Annotations.Free;
  MainlineInput.Moves.Free;
  inherited Destroy;
end;

function TGameTreeCommand.SearchRef: TGameTreeSearchRef;
begin
  Result := GameTreeSearchRef(GameTreeId, SearchId, NodeId);
end;

procedure TGameTreeCommand.SetSearchRef(const ASearch: TGameTreeSearchRef);
begin
  GameTreeId := ASearch.GameTreeId;
  SearchId := ASearch.SearchId;
  NodeId := ASearch.NodeId;
end;

constructor TGameTreeActor.Create(AGameTree: TGameTree;
  AOwnsGameTree: Boolean);
begin
  inherited Create;
  if AGameTree = nil then
  begin
    FGameTree := TGameTree.Create;
    FOwnsGameTree := True;
  end
  else
  begin
    FGameTree := AGameTree;
    FOwnsGameTree := AOwnsGameTree;
  end;
  FCommandQueue := TThreadMessageQueue.Create(True);
  FSearches := TObjectList.Create(True);
end;

destructor TGameTreeActor.Destroy;
begin
  FSearches.Free;
  FCommandQueue.Free;
  if FOwnsGameTree then
    FGameTree.Free;
  inherited Destroy;
end;

function TGameTreeActor.NextCommandId: Int64;
begin
  Inc(FNextCommandId);
  Result := FNextCommandId;
end;

function TGameTreeActor.NextSearchId: Int64;
begin
  Inc(FNextSearchId);
  Result := FNextSearchId;
end;

function TGameTreeActor.MarkMissingTargetSearchesFailed: Boolean;
var
  I: Integer;
  Search: TGameTreeSearchRecord;
begin
  Result := False;
  for I := 0 to FSearches.Count - 1 do
  begin
    Search := TGameTreeSearchRecord(FSearches[I]);
    if (Search = nil) or (Search.State <> gssActive) then
      Continue;
    if FGameTree.FindNodeById(Search.NodeId) <> nil then
      Continue;
    Search.State := gssFailed;
    Result := True;
  end;
end;

function TGameTreeActor.RemoveSearch(ASearchId: Int64): Boolean;
var
  I: Integer;
  Search: TGameTreeSearchRecord;
begin
  Result := False;
  for I := FSearches.Count - 1 downto 0 do
  begin
    Search := TGameTreeSearchRecord(FSearches[I]);
    if (Search <> nil) and (Search.SearchId = ASearchId) then
    begin
      FSearches.Delete(I);
      Exit(True);
    end;
  end;
end;

function TGameTreeActor.SearchCommandMatches(ACommand: TGameTreeCommand;
  ASearch: TGameTreeSearchRecord): Boolean;
begin
  Result := (ACommand <> nil) and (ASearch <> nil);
  if Result and (ACommand.NodeId > 0) then
    Result := SameGameTreeSearchRef(ACommand.SearchRef, ASearch.SearchRef);
end;

procedure TGameTreeActor.AcceptActorStateChange(ACommand: TGameTreeCommand);
begin
  if ACommand = nil then
    Exit;
  ACommand.Accepted := True;
  Inc(FRevision);
end;

procedure TGameTreeActor.AcceptTreeMutation(ACommand: TGameTreeCommand;
  var AInvalidateRebuildSignature: Boolean; AInvalidateSignature: Boolean);
begin
  if ACommand = nil then
    Exit;
  ACommand.Accepted := True;
  ACommand.TreeChanged := True;
  if AInvalidateSignature then
    AInvalidateRebuildSignature := True;
  MarkMissingTargetSearchesFailed;
  Inc(FRevision);
end;

function TGameTreeActor.ApplyHeaderInput(
  const AHeader: TGameTreeHeaderInput): Boolean;
var
  Changed: Boolean;
  FieldChanged: Boolean;
begin
  FGameTree.SetHeader(AHeader.EventName, AHeader.WhiteName, AHeader.BlackName,
    AHeader.ResultText, AHeader.StartingFEN, Changed);
  FGameTree.SetStatusText(AHeader.StatusText, FieldChanged);
  Changed := Changed or FieldChanged;
  FGameTree.SetGameState(AHeader.GameState, FieldChanged);
  Result := Changed or FieldChanged;
end;

procedure TGameTreeActor.ExecuteRecordPVCommand(ACommand: TGameTreeCommand;
  var AInvalidateRebuildSignature: Boolean; ARecordEnginePV: Boolean);
var
  Changed: Boolean;
  FailedText: string;
  MissingTargetText: string;
  Recorded: Boolean;
begin
  if ARecordEnginePV then
  begin
    MissingTargetText := 'engine PV target node does not exist';
    FailedText := 'engine PV was not recorded';
  end
  else
  begin
    MissingTargetText := 'annotator PV target node does not exist';
    FailedText := 'annotator PV was not recorded';
  end;

  if FGameTree.FindNodeById(ACommand.NodeId) = nil then
  begin
    Reject(ACommand, MissingTargetText);
    Exit;
  end;

  if ARecordEnginePV then
    Recorded := FGameTree.RecordEnginePVForNodeId(ACommand.NodeId,
      ACommand.ScoreText, ACommand.PvText, ACommand.PvDepthText,
      ACommand.PvTimeText, Changed)
  else
    Recorded := FGameTree.RecordAnnotatorPVForNodeId(ACommand.NodeId,
      ACommand.ScoreText, ACommand.PvText, ACommand.PvDepthText,
      ACommand.PvTimeText, Changed);
  if not Recorded then
  begin
    Reject(ACommand, FailedText);
    Exit;
  end;

  ACommand.Accepted := True;
  if Changed then
    AcceptTreeMutation(ACommand, AInvalidateRebuildSignature);
end;

procedure TGameTreeActor.ExecuteStoreMoveVariationCommand(
  ACommand: TGameTreeCommand; ANode: TGameTreePlyNode; const AMoveText: string;
  var AInvalidateRebuildSignature: Boolean);
var
  Changed: Boolean;
begin
  if not StoreMoveVariationFromNode(ACommand, ANode, AMoveText, Changed) then
    Exit;
  if Changed then
    AcceptTreeMutation(ACommand, AInvalidateRebuildSignature);
end;

function TGameTreeActor.ResolveSearchCommand(ACommand: TGameTreeCommand;
  out ASearch: TGameTreeSearchRecord): Boolean;
begin
  Result := False;
  ASearch := nil;
  if ACommand = nil then
    Exit;

  ASearch := FindSearch(ACommand.SearchId);
  if ASearch = nil then
  begin
    Reject(ACommand, 'search id not found');
    Exit;
  end;

  if not SearchCommandMatches(ACommand, ASearch) then
  begin
    Reject(ACommand, 'search reference mismatch');
    ASearch := nil;
    Exit;
  end;

  Result := True;
end;

function TGameTreeActor.CreateAddMainlineMoveCommand(APlyNumber: Integer;
  const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := CreateCommand(gtcAddMainlineMove);
  Result.PlyNumber := APlyNumber;
  Result.MoveText := Trim(AMoveText);
  Result.MoveSource := ASource;
end;

function TGameTreeActor.CreateAppendMainlineMoveCommand(
  const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := CreateCommand(gtcAppendMainlineMove);
  Result.MoveText := Trim(AMoveText);
  Result.MoveSource := ASource;
end;

function TGameTreeActor.CreateAppendMainlineSnapshotMoveCommand(
  const AHeader: TGameTreeHeaderInput; const AMoveText,
  AAnnotationText: string; const AMainline: TGameTreeMainlineInput;
  const AEnginePV: TGameTreePvInput; ASource: TGameTreeMoveSource
  ): TGameTreeCommand;
begin
  Result := CreateCommand(gtcAppendMainlineSnapshotMove);
  Result.HeaderInput := AHeader;
  Result.MoveText := Trim(AMoveText);
  Result.AnnotationText := AAnnotationText;
  CopyMainlineInputToCommand(Result, AMainline, False);
  Result.EnginePvInput := AEnginePV;
  Result.MoveSource := ASource;
end;

function TGameTreeActor.CreateCancelSearchCommand(
  ASearchId: Int64): TGameTreeCommand;
begin
  Result := CreateCommand(gtcCancelSearch);
  Result.SearchId := ASearchId;
end;

function TGameTreeActor.CreateCancelSearchCommand(
  const ASearch: TGameTreeSearchRef): TGameTreeCommand;
begin
  Result := CreateCancelSearchCommand(ASearch.SearchId);
  Result.SetSearchRef(ASearch);
end;

function TGameTreeActor.CreateReleaseSearchCommand(
  ASearchId: Int64): TGameTreeCommand;
begin
  Result := CreateCommand(gtcReleaseSearch);
  Result.SearchId := ASearchId;
end;

function TGameTreeActor.CreateReleaseSearchCommand(
  const ASearch: TGameTreeSearchRef): TGameTreeCommand;
begin
  Result := CreateReleaseSearchCommand(ASearch.SearchId);
  Result.SetSearchRef(ASearch);
end;

function TGameTreeActor.CreateSearchDoneCommand(ASearchId: Int64;
  const AMoveText: string): TGameTreeCommand;
var
  Search: TGameTreeSearchRecord;
begin
  Result := CreateCommand(gtcSearchDone);
  Result.SearchId := ASearchId;
  Result.MoveText := Trim(AMoveText);
  Search := FindSearch(ASearchId);
  if Search <> nil then
    Result.SetSearchRef(Search.SearchRef);
end;

function TGameTreeActor.CreateSearchDoneCommand(
  const ASearch: TGameTreeSearchRef; const AMoveText: string): TGameTreeCommand;
begin
  Result := CreateSearchDoneCommand(ASearch.SearchId, AMoveText);
  Result.SetSearchRef(ASearch);
end;

function TGameTreeActor.CreateRecordAnnotatorPVCommand(ANodeId: Int64;
  const AScore, APV: string; const ADepth: string; const ATimeText: string
  ): TGameTreeCommand;
begin
  Result := CreateRecordPVCommand(gtcRecordAnnotatorPV, ANodeId, AScore, APV,
    ADepth, ATimeText);
end;

function TGameTreeActor.CreateRecordAutoPlayPVCommand(ANodeId: Int64;
  const APV: string): TGameTreeCommand;
begin
  Result := CreateCommand(gtcRecordAutoPlayPV);
  Result.NodeId := ANodeId;
  Result.PvText := Trim(APV);
end;

function TGameTreeActor.CreateRestoreNodeDataCommand(ANodeId: Int64;
  const Data: TGameTreeNodeData): TGameTreeCommand;
begin
  Result := CreateCommand(gtcRestoreNodeData);
  Result.NodeId := ANodeId;
  Result.NodeData := Data;
end;

function TGameTreeActor.CreateRecordEnginePVCommand(ANodeId: Int64;
  const AScore, APV: string; const ADepth: string; const ATimeText: string
  ): TGameTreeCommand;
begin
  Result := CreateRecordPVCommand(gtcRecordEnginePV, ANodeId, AScore, APV,
    ADepth, ATimeText);
end;

function TGameTreeActor.CreateStoreMoveVariationCommand(ANodeId: Int64;
  const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := CreateCommand(gtcStoreMoveVariation);
  Result.NodeId := ANodeId;
  Result.MoveText := Trim(AMoveText);
  Result.MoveSource := ASource;
end;

function TGameTreeActor.CreateClearBranchesCommand: TGameTreeCommand;
begin
  Result := CreateCommand(gtcClearBranches);
end;

procedure TGameTreeActor.CopyMainlineInputToCommand(ACommand: TGameTreeCommand;
  const AMainline: TGameTreeMainlineInput; AIncludeMoves: Boolean);
begin
  if ACommand = nil then
    Exit;

  ACommand.MainlineInput.MoveData := Copy(AMainline.MoveData);
  ACommand.MainlineInput.RecordClock := AMainline.RecordClock;
  ACommand.MainlineInput.WhiteRemainingSeconds :=
    AMainline.WhiteRemainingSeconds;
  ACommand.MainlineInput.BlackRemainingSeconds :=
    AMainline.BlackRemainingSeconds;
  ACommand.MainlineInput.WhiteUsedSeconds := AMainline.WhiteUsedSeconds;
  ACommand.MainlineInput.BlackUsedSeconds := AMainline.BlackUsedSeconds;

  if not AIncludeMoves then
    Exit;
  if AMainline.Moves <> nil then
    ACommand.MainlineInput.Moves.Assign(AMainline.Moves);
  if AMainline.Annotations <> nil then
    ACommand.MainlineInput.Annotations.Assign(AMainline.Annotations);
end;

function TGameTreeActor.MoveSourceOriginText(
  ASource: TGameTreeMoveSource): string;
begin
  case ASource of
    gmsHuman:
      Result := 'Human';
    gmsEngineMatch:
      Result := 'Engine';
  else
    Result := '';
  end;
end;

function TGameTreeActor.CommandRebuildSignature(
  ACommand: TGameTreeCommand): string;

  procedure AddLine(const AText: string);
  begin
    Result += AText + #10;
  end;

  procedure AddStrings(AStrings: TStrings);
  var
    J: Integer;
  begin
    if AStrings = nil then
    begin
      AddLine('<nil>');
      Exit;
    end;
    AddLine(IntToStr(AStrings.Count));
    for J := 0 to AStrings.Count - 1 do
      AddLine(AStrings[J]);
  end;

  function BoolText(AValue: Boolean): string;
  begin
    if AValue then
      Result := '1'
    else
      Result := '0';
  end;

  function SecondsText(AValue: Double): string;
  begin
    Result := FormatFloat('0.000', AValue);
  end;
begin
  Result := '';
  if ACommand = nil then
    Exit;

  AddLine(ACommand.HeaderInput.Signature);
  AddLine(ACommand.HeaderInput.EventName);
  AddLine(ACommand.HeaderInput.WhiteName);
  AddLine(ACommand.HeaderInput.BlackName);
  AddLine(ACommand.HeaderInput.ResultText);
  AddLine(ACommand.HeaderInput.StartingFEN);
  AddLine(ACommand.HeaderInput.StatusText);
  AddLine(ACommand.HeaderInput.InitialCommentText);
  AddLine(IntToStr(Ord(ACommand.HeaderInput.GameState)));
  AddLine(BoolText(ACommand.HeaderInput.RecordTimeControl));
  AddLine(IntToStr(ACommand.HeaderInput.TimeControl.MovesPerPeriod));
  AddLine(SecondsText(ACommand.HeaderInput.TimeControl.MinutesPerPeriod));
  AddLine(SecondsText(ACommand.HeaderInput.TimeControl.IncrementSeconds));
  AddLine(IntToStr(Ord(ACommand.HeaderInput.TimeControl.IncrementMode)));

  AddStrings(ACommand.MainlineInput.Moves);
  AddStrings(ACommand.MainlineInput.Annotations);
  AddLine(GameMoveDataSignature(ACommand.MainlineInput.MoveData));
  AddLine(BoolText(ACommand.MainlineInput.RecordClock));
  AddLine(SecondsText(ACommand.MainlineInput.WhiteRemainingSeconds));
  AddLine(SecondsText(ACommand.MainlineInput.BlackRemainingSeconds));
  AddLine(SecondsText(ACommand.MainlineInput.WhiteUsedSeconds));
  AddLine(SecondsText(ACommand.MainlineInput.BlackUsedSeconds));

  AddLine(BoolText(ACommand.EnginePvInput.RecordPV));
  AddLine(IntToStr(ACommand.EnginePvInput.BasePly));
  AddLine(ACommand.EnginePvInput.Score);
  AddLine(ACommand.EnginePvInput.PV);
  AddLine(ACommand.EnginePvInput.Depth);
  AddLine(ACommand.EnginePvInput.TimeText);
  AddLine(BoolText(ACommand.AnnotatorPvInput.RecordPV));
  AddLine(IntToStr(ACommand.AnnotatorPvInput.BasePly));
  AddLine(ACommand.AnnotatorPvInput.Score);
  AddLine(ACommand.AnnotatorPvInput.PV);
  AddLine(ACommand.AnnotatorPvInput.Depth);
  AddLine(ACommand.AnnotatorPvInput.TimeText);

  AddLine(IntToStr(ACommand.NodeId));
  AddLine(IntToStr(ACommand.PlyNumber));
  AddLine(ACommand.ScoreText);
  AddLine(ACommand.PvText);
  AddLine(ACommand.PvDepthText);
  AddLine(ACommand.PvTimeText);

end;

procedure TGameTreeActor.ClearRebuildSignature;
begin
  FLastRebuildSignature := '';
end;

function TGameTreeActor.CreateCommand(
  AKind: TGameTreeActorCommandKind): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(AKind);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
end;

function TGameTreeActor.CreateRecordPVCommand(AKind: TGameTreeActorCommandKind;
  ANodeId: Int64; const AScore, APV, ADepth,
  ATimeText: string): TGameTreeCommand;
begin
  Result := CreateCommand(AKind);
  Result.NodeId := ANodeId;
  Result.ScoreText := Trim(AScore);
  Result.PvText := Trim(APV);
  Result.PvDepthText := Trim(ADepth);
  Result.PvTimeText := Trim(ATimeText);
end;

function TGameTreeActor.CreateRebuildFromInputsCommand(
  const AHeader: TGameTreeHeaderInput;
  const AMainline: TGameTreeMainlineInput;
  const AEnginePV, AAnnotatorPV: TGameTreePvInput;
  AAnalysisNodeId: Int64;
  const AVariationPvScore: string; const AVariationPvText: string;
  const AVariationPvDepth: string; const AVariationPvTimeText: string
  ): TGameTreeCommand;
begin
  Result := CreateCommand(gtcRebuildFromInputs);
  Result.HeaderInput := AHeader;
  CopyMainlineInputToCommand(Result, AMainline, True);
  Result.NodeId := AAnalysisNodeId;
  Result.EnginePvInput := AEnginePV;
  Result.AnnotatorPvInput := AAnnotatorPV;
  Result.ScoreText := Trim(AVariationPvScore);
  Result.PvText := Trim(AVariationPvText);
  Result.PvDepthText := Trim(AVariationPvDepth);
  Result.PvTimeText := Trim(AVariationPvTimeText);
end;

function TGameTreeActor.CreateSetHeaderCommand(
  const AHeader: TGameTreeHeaderInput): TGameTreeCommand;
begin
  Result := CreateSetHeaderCommand(AHeader,
    GameTreeMainlineInput(nil, nil, False, 0, 0, 0, 0));
end;

function TGameTreeActor.CreateSetHeaderCommand(
  const AHeader: TGameTreeHeaderInput;
  const AMainline: TGameTreeMainlineInput): TGameTreeCommand;
begin
  Result := CreateCommand(gtcSetHeader);
  Result.HeaderInput := AHeader;
  CopyMainlineInputToCommand(Result, AMainline, False);
end;

function TGameTreeActor.CreateStartSearchCommand(ANodeId: Int64;
  out ASearchId: Int64): TGameTreeCommand;
begin
  ASearchId := NextSearchId;
  Result := CreateCommand(gtcStartSearch);
  Result.NodeId := ANodeId;
  Result.SearchId := ASearchId;
end;

function TGameTreeActor.CreateStartSearchCommand(ANodeId: Int64;
  out ASearch: TGameTreeSearchRef): TGameTreeCommand;
var
  SearchId: Int64;
begin
  Result := CreateStartSearchCommand(ANodeId, SearchId);
  ASearch := Result.SearchRef;
end;

function TGameTreeActor.CreateImportPdnTreeCommand(ARoot: TPdnMoveNode): TGameTreeCommand;
begin
  Result := CreateCommand(gtcImportPdnTree);
  Result.ImportWarnings := TStringList.Create;
  if ARoot <> nil then Result.ImportRoot := ARoot.Clone;
end;

function TGameTreeActor.CreateImportNodeCommand(AParentNodeId: Int64;
  const AMoveText, AAnnotationText: string): TGameTreeCommand;
var Moves: TGameTreeImportMoves;
begin
  SetLength(Moves, 1);
  Moves[0].MoveText := AMoveText;
  Moves[0].AnnotationText := AAnnotationText;
  Result := CreateImportBranchCommand(AParentNodeId, Moves);
  Result.CommandKind := gtcImportNode;
end;

function TGameTreeActor.CreateImportBranchCommand(AParentNodeId: Int64;
  const AMoves: TGameTreeImportMoves; ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := CreateCommand(gtcImportBranch);
  Result.NodeId := AParentNodeId;
  Result.ImportMoves := Copy(AMoves);
  Result.MoveSource := ASource;
end;

function TGameTreeActor.FindSearch(ASearchId: Int64): TGameTreeSearchRecord;
var
  I: Integer;
  Search: TGameTreeSearchRecord;
begin
  Result := nil;
  for I := 0 to FSearches.Count - 1 do
  begin
    Search := TGameTreeSearchRecord(FSearches[I]);
    if (Search <> nil) and (Search.SearchId = ASearchId) then
      Exit(Search);
  end;
end;

function TGameTreeActor.FindSearch(
  const ASearch: TGameTreeSearchRef): TGameTreeSearchRecord;
begin
  Result := FindSearch(ASearch.SearchId);
  if (Result <> nil) and
    (not SameGameTreeSearchRef(Result.SearchRef, ASearch)) then
    Result := nil;
end;

procedure TGameTreeActor.Reject(ACommand: TGameTreeCommand;
  const AErrorText: string);
begin
  if ACommand = nil then
    Exit;
  ACommand.Accepted := False;
  ACommand.ErrorText := AErrorText;
end;

function TGameTreeActor.StoreMoveVariationFromNode(ACommand: TGameTreeCommand;
  ANode: TGameTreePlyNode; const AMoveText: string; out AChanged: Boolean): Boolean;
var Child: TGameTreePlyNode;
begin
  AChanged := False;
  Result := False;
  if (ACommand = nil) or (ANode = nil) then Exit;
  Child := FGameTree.FindChildByMove(ANode, AMoveText);
  if Child = nil then
  begin
    Child := FGameTree.RecordBranchMove(ANode, AMoveText);
    FGameTree.SetNodeOrigin(Child, MoveSourceOriginText(ACommand.MoveSource));
    AChanged := True;
  end;
  ACommand.Accepted := Child <> nil;
  if Child = nil then Exit;
  ACommand.CreatedNodeId := Child.NodeId;
  ACommand.PlyNumber := Child.PlyNumber;
  ACommand.MoveText := Child.MoveText;
  Result := True;
end;

function TGameTreeActor.ValidateMoveCommand(ACommand: TGameTreeCommand): Boolean;
var
  Board: TGamePosition;
  Mainline: TStringList;
  Parent: TGameTreePlyNode;
  Ply, ImportIndex: Integer;
  Fen: string;

  procedure Replay(AList: TStrings; ACount: Integer);
  var
    J: Integer;
  begin
    for J := 0 to ACount - 1 do
      AList[J] := Board.PlayMoveText(AList[J]);
  end;

  procedure LoadStart(const AValue: string);
  begin
    if Trim(AValue) = '' then
      Board.LoadFromFEN(FGameTree.Variant.DefaultStartingFEN)
    else
      Board.LoadFromFEN(AValue);
  end;

  procedure ValidateChildren(Node: TGameTreePlyNode; Position: TGamePosition);
  var
    J: Integer;
    Next: TGamePosition;
  begin
    for J := 0 to Node.ChildCount - 1 do
    begin
      Next := Position.Clone;
      try
        Next.PlayMoveText(Node.Children[J].MoveText);
        ValidateChildren(Node.Children[J], Next);
      finally
        Next.Free;
      end;
    end;
  end;

begin
  Result := True;
  if not (ACommand.CommandKind in [gtcAddMainlineMove, gtcAppendMainlineMove,
    gtcAppendMainlineSnapshotMove, gtcImportBranch, gtcImportNode, gtcStoreMoveVariation,
    gtcRebuildFromInputs, gtcSetHeader]) then
    Exit;
  Board := FGameTree.Variant.CreatePosition;
  Mainline := TStringList.Create;
  try
    try
      case ACommand.CommandKind of
        gtcAddMainlineMove, gtcAppendMainlineMove,
        gtcAppendMainlineSnapshotMove:
          begin
            Ply := FGameTree.MainlineCount + 1;
            if ACommand.CommandKind = gtcAddMainlineMove then
              Ply := ACommand.PlyNumber;
            if (Ply < 1) or (Ply > FGameTree.MainlineCount + 1) then
              raise EConvertError.Create('Mainline move would leave a hole');
            if ACommand.CommandKind = gtcAppendMainlineSnapshotMove then
            begin
              // Validate the prospective header and complete sequence before
              // applying either; a rejected snapshot must not alter headers.
              LoadStart(ACommand.HeaderInput.StartingFEN);
              FGameTree.CopyMainlineMovesTo(Mainline);
              Replay(Mainline, Mainline.Count);
            end
            else
            begin
              if Ply = 1 then
                Parent := FGameTree.Root
              else
                Parent := FGameTree.MainlineNode[Ply - 1];
              if not FGameTree.TryBuildPositionAtNode(Parent, Board) then
                raise EConvertError.Create('Cannot replay move parent');
            end;
            ACommand.MoveText := Board.PlayMoveText(ACommand.MoveText);
          end;
        gtcStoreMoveVariation:
          begin
            Parent := FGameTree.FindNodeById(ACommand.NodeId);
            if (Parent = nil) or not FGameTree.TryBuildPositionAtNode(Parent, Board) then
              raise EConvertError.Create('Cannot replay variation parent');
            ACommand.MoveText := Board.PlayMoveText(ACommand.MoveText);
          end;
        gtcImportBranch, gtcImportNode:
          begin
            Parent := FGameTree.FindNodeById(ACommand.NodeId);
            if (Parent = nil) or not FGameTree.TryBuildPositionAtNode(Parent, Board) then
              raise EConvertError.Create('Cannot replay import parent');
            if Length(ACommand.ImportMoves) = 0 then
              raise EConvertError.Create('Branch has no moves');
            if (ACommand.CommandKind = gtcImportNode) and (Length(ACommand.ImportMoves) <> 1) then
              raise EConvertError.Create('Node import requires exactly one move');
            for ImportIndex := 0 to High(ACommand.ImportMoves) do
              ACommand.ImportMoves[ImportIndex].MoveText :=
                Board.PlayMoveText(ACommand.ImportMoves[ImportIndex].MoveText);
          end;
        gtcRebuildFromInputs, gtcSetHeader:
          begin
            Fen := ACommand.HeaderInput.StartingFEN;
            LoadStart(Fen);
            if ACommand.CommandKind = gtcRebuildFromInputs then
              Mainline.Assign(ACommand.MainlineInput.Moves)
            else
              FGameTree.CopyMainlineMovesTo(Mainline);
            Replay(Mainline, Mainline.Count);
            if (ACommand.CommandKind = gtcRebuildFromInputs) and (ACommand.MainlineInput.Moves <> nil) then
              ACommand.MainlineInput.Moves.Assign(Mainline);
            if ACommand.CommandKind = gtcSetHeader then
            begin
              LoadStart(Fen);
              ValidateChildren(FGameTree.Root, Board);
            end;
          end;
      end;
    except
      on E: Exception do
      begin
        Reject(ACommand, E.Message);
        Result := False;
      end;
    end;
  finally
    Mainline.Free;
    Board.Free;
  end;
end;

function FiniteNodeData(const Data: TGameTreeNodeData): Boolean;
begin
  Result := not (IsNan(Data.SecondsUsed) or IsInfinite(Data.SecondsUsed) or
          IsNan(Data.WhiteRemainingSeconds) or IsInfinite(Data.WhiteRemainingSeconds) or
          IsNan(Data.BlackRemainingSeconds) or IsInfinite(Data.BlackRemainingSeconds) or
          IsNan(Data.WhiteUsedSeconds) or IsInfinite(Data.WhiteUsedSeconds) or
          IsNan(Data.BlackUsedSeconds) or IsInfinite(Data.BlackUsedSeconds));
end;

procedure TGameTreeActor.ExecuteImportPdnTree(ACommand: TGameTreeCommand;
  var AInvalidateRebuildSignature: Boolean);
var Board: TGamePosition; Changed: Boolean;
  procedure Walk(Source: TPdnMoveNode; Target: TGameTreePlyNode;
    Position: TGamePosition);
  var I: Integer; ParentCopy, Next: TGamePosition;
    Child: TGameTreePlyNode; Move: string;
  begin
    if Source.HasNodeData then
      if not FiniteNodeData(Source.NodeData) then
        ACommand.ImportWarnings.Add('Cannot restore node data: node metadata contains non-finite clock data')
      else
      begin
        FGameTree.RestoreNodeData(Target.NodeId, Source.NodeData);
        Changed := True;
      end;
    ParentCopy := nil;
    if Source.ChildCount > 1 then
      ParentCopy := Position.Clone;
    try
      for I := 0 to Source.ChildCount - 1 do
      begin
        Next := Position;
        if I > 0 then
          Next := ParentCopy.Clone;
        try
          Inc(ACommand.ValidatedMoveCount);
          try
            Move := Next.PlayMoveText(Source.Children[I].MoveText);
          except
            on E: Exception do
            begin
              ACommand.ImportWarnings.Add('Cannot load move ' + Source.Children[I].MoveText + ': ' + E.Message);
              Continue; // Reject only this subtree, preserving later valid siblings.
            end;
          end;
          Child := FGameTree.FindChildByMove(Target, Move);
          if Child = nil then
          begin
            Child := FGameTree.RecordBranchMove(Target, Move);
            FGameTree.SetNodeOrigin(Child, MoveSourceOriginText(ACommand.MoveSource));
            Changed := True;
          end;
          Changed := FGameTree.RecordNodeAnnotation(Child, Source.Children[I].AnnotationText) or Changed;
          Inc(ACommand.ImportedMoveCount);
          Walk(Source.Children[I], Child, Next);
        finally if I > 0 then Next.Free; end;
      end;
    finally ParentCopy.Free; end;
  end;
begin
  if ACommand.ImportRoot = nil then
  begin Reject(ACommand, 'PDN import has no root'); Exit; end;
  Board := FGameTree.Variant.CreatePosition;
  try
    try Board.LoadFromFEN(FGameTree.StartingFEN);
    except on E: Exception do begin Reject(ACommand, E.Message); Exit; end; end;
    ACommand.ImportWarnings.Clear;
    ACommand.ValidatedMoveCount := 0; ACommand.ImportedMoveCount := 0;
    Changed := False;
    Walk(ACommand.ImportRoot, FGameTree.Root, Board);
    ACommand.Accepted := True;
    if Changed then AcceptTreeMutation(ACommand, AInvalidateRebuildSignature);
  finally Board.Free; end;
end;

procedure TGameTreeActor.ExecuteCommand(ACommand: TGameTreeCommand);
var
  ImportIndex: Integer;
  ImportChild: TGameTreePlyNode;
  Changed: Boolean;
  InvalidateRebuildSignature: Boolean;
  Node: TGameTreePlyNode;
  RebuildSignature: string;
  Search: TGameTreeSearchRecord;
  ClockChanged: Boolean;
  TimeControlChanged: Boolean;

  function HeaderIncrementModeText: string;
  begin
    case Ord(ACommand.HeaderInput.TimeControl.IncrementMode) of
      0:
        Result := 'from start';
      1:
        Result := 'after move limit';
    else
      Result := '';
    end;
  end;
begin
  if ACommand = nil then
    Exit;

  ACommand.Accepted := False;
  ACommand.TreeChanged := False;
  ACommand.ErrorText := '';
  if ACommand.GameTreeId <> FGameTree.GameTreeId then
  begin
    Reject(ACommand, 'wrong game tree id');
    Exit;
  end;
  if not ValidateMoveCommand(ACommand) then
    Exit;
  InvalidateRebuildSignature := False;

  case ACommand.CommandKind of
    gtcImportPdnTree: ExecuteImportPdnTree(ACommand, InvalidateRebuildSignature);
    gtcRestoreNodeData:
      begin
        if not FiniteNodeData(ACommand.NodeData) then
        begin Reject(ACommand, 'node metadata contains non-finite clock data'); Exit; end;
        if not FGameTree.RestoreNodeData(ACommand.NodeId, ACommand.NodeData) then
        begin Reject(ACommand, 'node metadata target does not exist'); Exit; end;
        AcceptTreeMutation(ACommand, InvalidateRebuildSignature);
      end;
    gtcAddMainlineMove:
      begin
        Node := FGameTree.RecordMainlineMove(ACommand.PlyNumber,
          ACommand.MoveText);
        if Node = nil then
        begin
          Reject(ACommand, 'mainline move was not recorded');
          Exit;
        end;
        ACommand.CreatedNodeId := Node.NodeId;
        ACommand.NodeId := Node.NodeId;
        ACommand.PlyNumber := Node.PlyNumber;
        ACommand.MoveText := Node.MoveText;
        AcceptTreeMutation(ACommand, InvalidateRebuildSignature);
      end;
    gtcAppendMainlineMove:
      begin
        Node := FGameTree.RecordMainlineMove(FGameTree.MainlineCount + 1,
          ACommand.MoveText);
        if Node = nil then
        begin
          Reject(ACommand, 'mainline move was not appended');
          Exit;
        end;
        ACommand.CreatedNodeId := Node.NodeId;
        ACommand.NodeId := Node.NodeId;
        ACommand.PlyNumber := Node.PlyNumber;
        ACommand.MoveText := Node.MoveText;
        AcceptTreeMutation(ACommand, InvalidateRebuildSignature);
      end;
    gtcAppendMainlineSnapshotMove:
      begin
        Changed := ApplyHeaderInput(ACommand.HeaderInput);
        if ACommand.HeaderInput.RecordTimeControl then
          FGameTree.RecordTimeControl(ACommand.HeaderInput.TimeControl);
        Node := FGameTree.RecordMainlineMove(FGameTree.MainlineCount + 1,
          ACommand.MoveText);
        if Node = nil then
        begin
          Reject(ACommand, 'snapshot mainline move was not appended');
          Exit;
        end;
        ACommand.CreatedNodeId := Node.NodeId;
        ACommand.NodeId := Node.NodeId;
        ACommand.PlyNumber := Node.PlyNumber;
        ACommand.MoveText := Node.MoveText;
        if Trim(ACommand.AnnotationText) <> '' then
          FGameTree.RecordMainlineAnnotation(Node.PlyNumber,
            ACommand.AnnotationText);
        if ACommand.MainlineInput.RecordClock then
          FGameTree.RecordClockState(Node.PlyNumber,
            ACommand.MainlineInput.WhiteRemainingSeconds,
            ACommand.MainlineInput.BlackRemainingSeconds,
            ACommand.MainlineInput.WhiteUsedSeconds,
            ACommand.MainlineInput.BlackUsedSeconds);
        RecordGameTreeCompletedMoves(FGameTree, ACommand.MainlineInput.MoveData);
        RecordGameTreeAnalysis(FGameTree, ACommand.EnginePvInput,
          GameTreePvInput(False, 0, '', ''));
        AcceptTreeMutation(ACommand, InvalidateRebuildSignature);
      end;
    gtcImportBranch, gtcImportNode:
      begin
        Node := FGameTree.FindNodeById(ACommand.NodeId);
        Changed := False;
        for ImportIndex := 0 to High(ACommand.ImportMoves) do
        begin
          ImportChild := FGameTree.FindChildByMove(Node, ACommand.ImportMoves[ImportIndex].MoveText);
          if ImportChild = nil then
          begin
            ImportChild := FGameTree.RecordBranchMove(Node, ACommand.ImportMoves[ImportIndex].MoveText);
            Changed := True;
            FGameTree.SetNodeOrigin(ImportChild, MoveSourceOriginText(ACommand.MoveSource));
          end;
          Changed := FGameTree.RecordNodeAnnotation(ImportChild,
            ACommand.ImportMoves[ImportIndex].AnnotationText) or Changed;
          Node := ImportChild;
        end;
        ACommand.CreatedNodeId := Node.NodeId;
        ACommand.Accepted := True;
        if Changed then AcceptTreeMutation(ACommand, InvalidateRebuildSignature);
      end;
    gtcStartSearch:
      begin
        if FGameTree.FindNodeById(ACommand.NodeId) = nil then
        begin
          Reject(ACommand, 'search target node does not exist');
          Exit;
        end;
        if ACommand.SearchId <= 0 then
        begin
          Reject(ACommand, 'invalid search id');
          Exit;
        end;
        if FindSearch(ACommand.SearchId) <> nil then
        begin
          Reject(ACommand, 'duplicate search id');
          Exit;
        end;
        Search := TGameTreeSearchRecord.Create;
        Search.SearchId := ACommand.SearchId;
        Search.GameTreeId := FGameTree.GameTreeId;
        Search.NodeId := ACommand.NodeId;
        Search.State := gssActive;
        FSearches.Add(Search);
        AcceptActorStateChange(ACommand);
      end;
    gtcCancelSearch:
      begin
        if not ResolveSearchCommand(ACommand, Search) then
          Exit;
        if Search.State <> gssActive then
        begin
          Reject(ACommand, 'search is not active');
          Exit;
        end;
        Search.State := gssCancelled;
        ACommand.SetSearchRef(Search.SearchRef);
        AcceptActorStateChange(ACommand);
      end;
    gtcSearchDone:
      begin
        if not ResolveSearchCommand(ACommand, Search) then
          Exit;
        if Search.State <> gssActive then
        begin
          Reject(ACommand, 'search is not active');
          Exit;
        end;
        if FGameTree.FindNodeById(Search.NodeId) = nil then
        begin
          Search.State := gssFailed;
          Reject(ACommand, 'search target node no longer exists');
          Inc(FRevision);
          Exit;
        end;
        Search.State := gssDone;
        Search.ResultMove := Trim(ACommand.MoveText);
        ACommand.SetSearchRef(Search.SearchRef);
        AcceptActorStateChange(ACommand);
      end;
    gtcReleaseSearch:
      begin
        if not ResolveSearchCommand(ACommand, Search) then
          Exit;
        if Search.State = gssActive then
        begin
          Reject(ACommand, 'active search cannot be released');
          Exit;
        end;
        ACommand.SetSearchRef(Search.SearchRef);
        if not RemoveSearch(ACommand.SearchId) then
        begin
          Reject(ACommand, 'search was not released');
          Exit;
        end;
        AcceptActorStateChange(ACommand);
      end;
    gtcRecordEnginePV:
      begin
        ExecuteRecordPVCommand(ACommand, InvalidateRebuildSignature, True);
      end;
    gtcRecordAnnotatorPV:
      begin
        ExecuteRecordPVCommand(ACommand, InvalidateRebuildSignature, False);
      end;
    gtcRecordAutoPlayPV:
      begin
        if not FGameTree.RecordAutoPlayPVForNodeId(ACommand.NodeId,
          ACommand.PvText, Changed) then
        begin
          Reject(ACommand, 'Auto Play PV target node does not exist');
          Exit;
        end;
        ACommand.Accepted := True;
        if Changed then
          AcceptTreeMutation(ACommand, InvalidateRebuildSignature);
      end;
    gtcStoreMoveVariation:
      begin
        Node := FGameTree.FindNodeById(ACommand.NodeId);
        if Node = nil then
        begin
          Reject(ACommand, 'variation target node does not exist');
          Exit;
        end;
        ExecuteStoreMoveVariationCommand(ACommand, Node, ACommand.MoveText,
          InvalidateRebuildSignature);
      end;
    gtcClearBranches:
      begin
        if FGameTree.BranchCount = 0 then
        begin
          ACommand.Accepted := True;
          Exit;
        end;
        FGameTree.ClearBranches;
        AcceptTreeMutation(ACommand, InvalidateRebuildSignature);
      end;
    gtcRebuildFromInputs:
      begin
        RebuildSignature := CommandRebuildSignature(ACommand);
        if (RebuildSignature <> '') and
          (RebuildSignature = FLastRebuildSignature) then
        begin
          ACommand.Accepted := True;
          Exit;
        end;
        BeginGameTreeRebuild(FGameTree, ACommand.HeaderInput);
        RecordGameTreeMainline(FGameTree, ACommand.MainlineInput);
        RecordGameTreeAnalysis(FGameTree, ACommand.EnginePvInput,
          ACommand.AnnotatorPvInput);
        if (ACommand.NodeId > 0) and (Trim(ACommand.PvText) <> '') then
          FGameTree.RecordAnnotatorPVForNodeId(ACommand.NodeId,
            ACommand.ScoreText, ACommand.PvText, ACommand.PvDepthText,
            ACommand.PvTimeText);
        AcceptTreeMutation(ACommand, InvalidateRebuildSignature, False);
        FLastRebuildSignature := RebuildSignature;
      end;
    gtcSetHeader:
      begin
        Changed := ApplyHeaderInput(ACommand.HeaderInput);
        if ACommand.HeaderInput.RecordTimeControl then
        begin
          TimeControlChanged := (not FGameTree.HasTimeControl) or
            (FGameTree.MovesPerPeriod <>
              ACommand.HeaderInput.TimeControl.MovesPerPeriod) or
            (FGameTree.MinutesPerPeriod <>
              ACommand.HeaderInput.TimeControl.MinutesPerPeriod) or
            (FGameTree.IncrementSeconds <>
              ACommand.HeaderInput.TimeControl.IncrementSeconds) or
            (FGameTree.IncrementModeText <> HeaderIncrementModeText);
          if TimeControlChanged then
          begin
            FGameTree.RecordTimeControl(ACommand.HeaderInput.TimeControl);
            Changed := True;
          end;
        end;
        if ACommand.MainlineInput.RecordClock then
        begin
          ClockChanged := (not FGameTree.HasClockInfo) or
            (FGameTree.WhiteRemainingSeconds <>
              ACommand.MainlineInput.WhiteRemainingSeconds) or
            (FGameTree.BlackRemainingSeconds <>
              ACommand.MainlineInput.BlackRemainingSeconds) or
            (FGameTree.WhiteUsedSeconds <>
              ACommand.MainlineInput.WhiteUsedSeconds) or
            (FGameTree.BlackUsedSeconds <>
              ACommand.MainlineInput.BlackUsedSeconds);
          if ClockChanged then
          begin
            FGameTree.RecordClockState(FGameTree.MainlineCount,
              ACommand.MainlineInput.WhiteRemainingSeconds,
              ACommand.MainlineInput.BlackRemainingSeconds,
              ACommand.MainlineInput.WhiteUsedSeconds,
              ACommand.MainlineInput.BlackUsedSeconds);
            Changed := True;
          end;
        end;
        Changed := RecordGameTreeCompletedMoves(FGameTree,
          ACommand.MainlineInput.MoveData) or Changed;
        ACommand.Accepted := True;
        if Changed then
          AcceptTreeMutation(ACommand, InvalidateRebuildSignature);
      end;
  end;
  if InvalidateRebuildSignature then
    ClearRebuildSignature;
end;

function TGameTreeActor.PostCommand(ACommand: TGameTreeCommand): Boolean;
begin
  Result := False;
  if ACommand = nil then
    Exit;
  Result := FCommandQueue.TryPost(ACommand);
end;

function TGameTreeActor.ProcessCommands: Integer;
begin
  Result := ProcessCommands(nil);
end;

function TGameTreeActor.ProcessCommands(AAfterExecute: TGameTreeCommandCallback
  ): Integer;
var
  CommandObject: TObject;
begin
  Result := 0;
  while FCommandQueue.TryPop(CommandObject) do
  begin
    try
      if CommandObject is TGameTreeCommand then
      begin
        ExecuteCommand(TGameTreeCommand(CommandObject));
        if Assigned(AAfterExecute) then
          AAfterExecute(TGameTreeCommand(CommandObject));
      end;
      Inc(Result);
    finally
      CommandObject.Free;
    end;
  end;
end;

function TGameTreeActor.SearchState(ASearchId: Int64;
  out AState: TGameTreeSearchState): Boolean;
var
  Search: TGameTreeSearchRecord;
begin
  Search := FindSearch(ASearchId);
  Result := Search <> nil;
  if Result then
    AState := Search.State;
end;

function TGameTreeActor.SearchState(const ASearch: TGameTreeSearchRef;
  out AState: TGameTreeSearchState): Boolean;
var
  Search: TGameTreeSearchRecord;
begin
  Search := FindSearch(ASearch);
  Result := Search <> nil;
  if Result then
    AState := Search.State;
end;

function TGameTreeActor.SearchResult(ASearchId: Int64; out ANodeId: Int64;
  out AMoveText: string): Boolean;
var
  Search: TGameTreeSearchRecord;
begin
  ANodeId := 0;
  AMoveText := '';
  Search := FindSearch(ASearchId);
  Result := (Search <> nil) and (Search.State = gssDone);
  if Result then
  begin
    ANodeId := Search.NodeId;
    AMoveText := Search.ResultMove;
  end;
end;

function TGameTreeActor.SearchResult(const ASearch: TGameTreeSearchRef;
  out ANodeId: Int64; out AMoveText: string): Boolean;
var
  Search: TGameTreeSearchRecord;
begin
  ANodeId := 0;
  AMoveText := '';
  Search := FindSearch(ASearch);
  Result := (Search <> nil) and (Search.State = gssDone);
  if Result then
  begin
    ANodeId := Search.NodeId;
    AMoveText := Search.ResultMove;
  end;
end;

end.
