unit uGameTreeActor;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils,
  uGameTree, uGameTreeBuilder, uGameTreeSearchRef, uThreadMessageQueue;

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
    gtcStoreVariationLine,
    gtcStartSearch,
    gtcCancelSearch,
    gtcSearchDone,
    gtcReleaseSearch,
    gtcRecordEnginePV,
    gtcRecordAnnotatorPV,
    gtcRecordAutoPlayPV,
    gtcStoreMoveVariation,
    gtcClearStoredVariations,
    gtcRebuildFromInputs,
    gtcSetHeader
  );

  TGameTreeSearchState = (
    gssActive,
    gssCancelled,
    gssDone,
    gssFailed
  );

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
    MoveSource: TGameTreeMoveSource;
    HeaderInput: TGameTreeHeaderInput;
    MainlineInput: TGameTreeMainlineInput;
    EnginePvInput: TGameTreePvInput;
    AnnotatorPvInput: TGameTreePvInput;
    PlyNumber: Integer;
    DisplayAfterPly: Integer;
    BasePly: Integer;
    Accepted: Boolean;
    TreeChanged: Boolean;
    ErrorText: string;
    CreatedNodeId: Int64;
    ScoreText: string;
    PvText: string;
    PvDepthText: string;
    PvTimeText: string;
    VariationIndex: Integer;
    RebuildVariationLines: TObjectList;
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
    procedure CopyStoredVariationsToCommand(ACommand: TGameTreeCommand);
    function CommandRebuildSignature(ACommand: TGameTreeCommand): string;
    function MoveSourceOriginText(ASource: TGameTreeMoveSource): string;
    procedure ClearRebuildSignature;
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
    procedure RebuildStoredVariations(ACommand: TGameTreeCommand);
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
    function CreateClearStoredVariationsCommand: TGameTreeCommand;
    function CreateRebuildFromInputsCommand(
      const AHeader: TGameTreeHeaderInput;
      const AMainline: TGameTreeMainlineInput;
      const AEnginePV, AAnnotatorPV: TGameTreePvInput;
      AVariationPvIndex: Integer = -1; AVariationPvPly: Integer = 0;
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
    function CreateStoreVariationLineCommand(ADisplayAfterPly, ABasePly: Integer;
      const AMovesText, AAnnotationText: string;
      ASource: TGameTreeMoveSource): TGameTreeCommand;

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
  uDraughtsBoard;

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
    'game-tree-store-variation-line',
    'game-tree-start-search',
    'game-tree-cancel-search',
    'game-tree-search-done',
    'game-tree-release-search',
    'game-tree-record-engine-pv',
    'game-tree-record-annotator-pv',
    'game-tree-record-auto-play-pv',
    'game-tree-store-move-variation',
    'game-tree-clear-stored-variations',
    'game-tree-rebuild-from-inputs',
    'game-tree-set-header'
  );
begin
  inherited Create(CommandNames[AKind]);
  CommandKind := AKind;
  MoveSource := gmsUnknown;
  MainlineInput.Moves := TStringList.Create;
  MainlineInput.Annotations := TStringList.Create;
  RebuildVariationLines := TObjectList.Create(True);
  PlyNumber := -1;
  DisplayAfterPly := -1;
  BasePly := -1;
  VariationIndex := -1;
end;

destructor TGameTreeCommand.Destroy;
begin
  RebuildVariationLines.Free;
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

function TGameTreeActor.CreateClearStoredVariationsCommand: TGameTreeCommand;
begin
  Result := CreateCommand(gtcClearStoredVariations);
end;

procedure TGameTreeActor.CopyMainlineInputToCommand(ACommand: TGameTreeCommand;
  const AMainline: TGameTreeMainlineInput; AIncludeMoves: Boolean);
begin
  if ACommand = nil then
    Exit;

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

procedure TGameTreeActor.CopyStoredVariationsToCommand(
  ACommand: TGameTreeCommand);
var
  I: Integer;
  SourceLine: TGameTreeVariationLine;
  TargetLine: TGameTreeVariationLine;
begin
  if (ACommand = nil) or (FGameTree = nil) then
    Exit;

  ACommand.RebuildVariationLines.Clear;
  for I := 0 to FGameTree.VariationLineCount - 1 do
  begin
    SourceLine := FGameTree.VariationLine[I];
    if SourceLine = nil then
      Continue;

    TargetLine := TGameTreeVariationLine.Create(SourceLine.DisplayAfterPly,
      SourceLine.BasePly, SourceLine.MovesText, SourceLine.AnnotationText,
      SourceLine.OriginText);
    ACommand.RebuildVariationLines.Add(TargetLine);
  end;
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
var
  I: Integer;
  Line: TGameTreeVariationLine;

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
  AddLine(IntToStr(Ord(ACommand.HeaderInput.GameState)));
  AddLine(BoolText(ACommand.HeaderInput.RecordTimeControl));
  AddLine(IntToStr(ACommand.HeaderInput.TimeControl.MovesPerPeriod));
  AddLine(SecondsText(ACommand.HeaderInput.TimeControl.MinutesPerPeriod));
  AddLine(SecondsText(ACommand.HeaderInput.TimeControl.IncrementSeconds));
  AddLine(IntToStr(Ord(ACommand.HeaderInput.TimeControl.IncrementMode)));

  AddStrings(ACommand.MainlineInput.Moves);
  AddStrings(ACommand.MainlineInput.Annotations);
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

  AddLine(IntToStr(ACommand.VariationIndex));
  AddLine(IntToStr(ACommand.PlyNumber));
  AddLine(ACommand.ScoreText);
  AddLine(ACommand.PvText);
  AddLine(ACommand.PvDepthText);
  AddLine(ACommand.PvTimeText);
  if ACommand.RebuildVariationLines = nil then
    AddLine('0')
  else
  begin
    AddLine(IntToStr(ACommand.RebuildVariationLines.Count));
    for I := 0 to ACommand.RebuildVariationLines.Count - 1 do
    begin
      Line := TGameTreeVariationLine(ACommand.RebuildVariationLines[I]);
      if Line = nil then
      begin
        AddLine('<nil>');
        Continue;
      end;
      AddLine(IntToStr(Line.DisplayAfterPly));
      AddLine(IntToStr(Line.BasePly));
      AddLine(Line.MovesText);
      AddLine(Line.AnnotationText);
      AddLine(Line.OriginText);
    end;
  end;
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
  AVariationPvIndex: Integer; AVariationPvPly: Integer;
  const AVariationPvScore: string; const AVariationPvText: string;
  const AVariationPvDepth: string; const AVariationPvTimeText: string
  ): TGameTreeCommand;
begin
  Result := CreateCommand(gtcRebuildFromInputs);
  CopyStoredVariationsToCommand(Result);
  Result.HeaderInput := AHeader;
  CopyMainlineInputToCommand(Result, AMainline, True);
  Result.EnginePvInput := AEnginePV;
  Result.AnnotatorPvInput := AAnnotatorPV;
  Result.VariationIndex := AVariationPvIndex;
  Result.PlyNumber := AVariationPvPly;
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

function TGameTreeActor.CreateStoreVariationLineCommand(ADisplayAfterPly,
  ABasePly: Integer; const AMovesText, AAnnotationText: string;
  ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := CreateCommand(gtcStoreVariationLine);
  Result.DisplayAfterPly := ADisplayAfterPly;
  Result.BasePly := ABasePly;
  Result.MoveText := Trim(AMovesText);
  Result.AnnotationText := Trim(AAnnotationText);
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

procedure TGameTreeActor.RebuildStoredVariations(ACommand: TGameTreeCommand);
var
  I: Integer;
  OriginChanged: Boolean;
  StoredLine: TGameTreeVariationLine;
  StoredVariationIndex: Integer;
  VariationLine: TGameTreeVariationLine;
  VariationMoves: TStringList;
begin
  if ACommand = nil then
    Exit;

  VariationMoves := TStringList.Create;
  try
    for I := 0 to ACommand.RebuildVariationLines.Count - 1 do
    begin
      StoredLine := TGameTreeVariationLine(ACommand.RebuildVariationLines[I]);
      if StoredLine = nil then
        Continue;

      VariationMoves.Clear;
      TextToMoveList(StoredLine.MovesText, VariationMoves);
      if VariationMoves.Count = 0 then
        Continue;

      StoredVariationIndex := FGameTree.StoreVariationLine(
        StoredLine.DisplayAfterPly, StoredLine.BasePly,
        StoredLine.MovesText, StoredLine.AnnotationText);
      if StoredVariationIndex < 0 then
        Continue;
      VariationLine := FGameTree.VariationLine[StoredVariationIndex];
      if VariationLine = nil then
        Continue;
      FGameTree.SetVariationLineOrigin(StoredVariationIndex,
        StoredLine.OriginText, OriginChanged);

      RecordGameTreeVariationLine(FGameTree,
        GameTreeVariationLineInput(VariationLine, StoredVariationIndex,
          VariationMoves, nil));
    end;
  finally
    VariationMoves.Free;
  end;
end;

function TGameTreeActor.StoreMoveVariationFromNode(
  ACommand: TGameTreeCommand; ANode: TGameTreePlyNode;
  const AMoveText: string; out AChanged: Boolean): Boolean;
var
  I: Integer;
  LBasePly: Integer;
  LDisplayAfterPly: Integer;
  LMoveText: string;
  LMovesText: string;
  LNodeWasMaterialized: Boolean;
  LAnnotationText: string;
  LOriginChanged: Boolean;
  LOriginText: string;
  LVariationIndex: Integer;
  LVariationNode: TGameTreePlyNode;
  LVariationPly: Integer;
  LStoredLine: TGameTreeVariationLine;
  LStoredMoves: TStringList;
  VariationLine: TGameTreeVariationLine;
begin
  Result := False;
  AChanged := False;
  if (ACommand = nil) or (ANode = nil) then
    Exit;

  LMoveText := NormalizeMoveNotation(AMoveText);
  if LMoveText = '' then
  begin
    Reject(ACommand, 'move is empty');
    Exit;
  end;

  LBasePly := ANode.PlyNumber;
  LDisplayAfterPly := LBasePly;
  LVariationIndex := -1;
  LVariationPly := 0;
  LAnnotationText := '';
  LOriginText := MoveSourceOriginText(ACommand.MoveSource);
  if Trim(ANode.VariationKey) <> '' then
  begin
    if not FGameTree.ParseVariationKey(ANode.VariationKey, LBasePly,
      LDisplayAfterPly, LVariationIndex, LVariationPly) then
    begin
      Reject(ACommand, 'invalid variation key');
      Exit;
    end;
    if (LVariationIndex < 0) or
      (LVariationIndex >= FGameTree.VariationLineCount) then
    begin
      Reject(ACommand, 'variation index out of range');
      Exit;
    end;
    VariationLine := FGameTree.VariationLine[LVariationIndex];
    if VariationLine = nil then
    begin
      Reject(ACommand, 'variation line not found');
      Exit;
    end;
    LMovesText := '';
    for I := 1 to LVariationPly do
    begin
      LVariationNode := FGameTree.FindVariationNode(LVariationIndex, I);
      if LVariationNode = nil then
        Break;
      if LMovesText <> '' then
        LMovesText += ' ';
      LMovesText += LVariationNode.MoveText;
    end;
    if LMovesText <> '' then
      LMovesText += ' ';
    LMovesText += LMoveText;
  end
  else
  begin
    LMovesText := LMoveText;
  end;

  if LVariationIndex >= 0 then
    ACommand.VariationIndex := FGameTree.StoreVariationLineAtIndex(
      LVariationIndex, LDisplayAfterPly, LBasePly, LMovesText,
      LAnnotationText, AChanged)
  else
    ACommand.VariationIndex := FGameTree.StoreVariationLine(
      LDisplayAfterPly, LBasePly, LMovesText, LAnnotationText, AChanged);
  if ACommand.VariationIndex < 0 then
  begin
    Reject(ACommand, 'variation line was not stored');
    Exit;
  end;
  if (FGameTree.VariationLine[ACommand.VariationIndex] <> nil) and
    (LOriginText <> '') then
  begin
    FGameTree.SetVariationLineOrigin(ACommand.VariationIndex, LOriginText,
      LOriginChanged);
    AChanged := AChanged or LOriginChanged;
  end;
  ACommand.NodeId := ANode.NodeId;
  ACommand.BasePly := LBasePly;
  ACommand.DisplayAfterPly := LDisplayAfterPly;
  ACommand.PlyNumber := LVariationPly + 1;
  ACommand.MoveText := LMovesText;
  ACommand.Accepted := True;
  LNodeWasMaterialized := FGameTree.FindVariationNode(ACommand.VariationIndex,
    ACommand.PlyNumber) <> nil;
  LStoredLine := FGameTree.VariationLine[ACommand.VariationIndex];
  if LStoredLine <> nil then
  begin
    LStoredMoves := TStringList.Create;
    try
      TextToMoveList(LStoredLine.MovesText, LStoredMoves);
      RecordGameTreeVariationLine(FGameTree,
        GameTreeVariationLineInput(LStoredLine, ACommand.VariationIndex,
          LStoredMoves, nil));
    finally
      LStoredMoves.Free;
    end;
  end;
  if FGameTree.FindVariationNode(ACommand.VariationIndex,
    ACommand.PlyNumber) = nil then
  begin
    Reject(ACommand, 'variation node was not materialized');
    Exit;
  end;
  if (not LNodeWasMaterialized) and
    (FGameTree.FindVariationNode(ACommand.VariationIndex,
      ACommand.PlyNumber) <> nil) then
    AChanged := True;
  Result := True;
end;

procedure TGameTreeActor.ExecuteCommand(ACommand: TGameTreeCommand);
var
  Changed: Boolean;
  InvalidateRebuildSignature: Boolean;
  Node: TGameTreePlyNode;
  OriginChanged: Boolean;
  OriginText: string;
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
  InvalidateRebuildSignature := False;

  case ACommand.CommandKind of
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
        RecordGameTreeAnalysis(FGameTree, ACommand.EnginePvInput,
          GameTreePvInput(False, 0, '', ''));
        AcceptTreeMutation(ACommand, InvalidateRebuildSignature);
      end;
    gtcStoreVariationLine:
      begin
        ACommand.VariationIndex := FGameTree.StoreVariationLine(
          ACommand.DisplayAfterPly, ACommand.BasePly, ACommand.MoveText,
          ACommand.AnnotationText, Changed);
        if ACommand.VariationIndex < 0 then
        begin
          Reject(ACommand, 'variation line was not stored');
          Exit;
        end;
        OriginText := MoveSourceOriginText(ACommand.MoveSource);
        if (FGameTree.VariationLine[ACommand.VariationIndex] <> nil) and
          (OriginText <> '') and
          (Trim(FGameTree.VariationLine[ACommand.VariationIndex].OriginText) <>
            OriginText) then
        begin
          FGameTree.SetVariationLineOrigin(ACommand.VariationIndex,
            OriginText, OriginChanged);
          Changed := Changed or OriginChanged;
        end;
        ACommand.Accepted := True;
        if Changed then
          AcceptTreeMutation(ACommand, InvalidateRebuildSignature);
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
    gtcClearStoredVariations:
      begin
        if FGameTree.VariationLineCount = 0 then
        begin
          ACommand.Accepted := True;
          Exit;
        end;
        FGameTree.ClearStoredVariations;
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
        RebuildStoredVariations(ACommand);
        if (ACommand.VariationIndex >= 0) and
          (ACommand.PlyNumber > 0) and (Trim(ACommand.PvText) <> '') and
          (ACommand.VariationIndex < FGameTree.VariationLineCount) then
          RecordGameTreeVariationAnnotatorPV(FGameTree,
            GameTreeVariationPvInput(
              FGameTree.VariationLine[ACommand.VariationIndex],
              ACommand.VariationIndex, ACommand.PlyNumber,
              ACommand.ScoreText, ACommand.PvText, ACommand.PvDepthText,
              ACommand.PvTimeText));
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
