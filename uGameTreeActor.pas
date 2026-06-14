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
    gmsAutorandom,
    gmsAutoplay,
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
    gtcStoreSearchMoveVariation,
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

  TGameTreeSearchRecord = class
  public
    SearchId: Int64;
    GameTreeId: Int64;
    NodeId: Int64;
    State: TGameTreeSearchState;
    ResultMove: string;
    function SearchRef: TGameTreeSearchRef;
  end;

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
    ErrorText: string;
    CreatedNodeId: Int64;
    ScoreText: string;
    PvText: string;
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
    procedure CopyStoredVariationsToCommand(ACommand: TGameTreeCommand);
    function CommandRebuildSignature(ACommand: TGameTreeCommand): string;
    procedure ClearRebuildSignature;
    function FindSearch(ASearchId: Int64): TGameTreeSearchRecord; overload;
    function FindSearch(const ASearch: TGameTreeSearchRef
      ): TGameTreeSearchRecord; overload;
    function NextCommandId: Int64;
    function NextSearchId: Int64;
    function RemoveSearch(ASearchId: Int64): Boolean;
    function SearchCommandMatches(ACommand: TGameTreeCommand;
      ASearch: TGameTreeSearchRecord): Boolean;
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
      APV: string): TGameTreeCommand;
    function CreateRecordAnnotatorPVCommand(ANodeId: Int64; const AScore,
      APV: string): TGameTreeCommand;
    function CreateStoreSearchMoveVariationCommand(ASearchId: Int64;
      ASource: TGameTreeMoveSource): TGameTreeCommand; overload;
    function CreateStoreSearchMoveVariationCommand(
      const ASearch: TGameTreeSearchRef;
      ASource: TGameTreeMoveSource): TGameTreeCommand; overload;
    function CreateStoreMoveVariationCommand(ANodeId: Int64;
      const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
    function CreateClearStoredVariationsCommand: TGameTreeCommand;
    function CreateRebuildFromInputsCommand(
      const AHeader: TGameTreeHeaderInput;
      const AMainline: TGameTreeMainlineInput;
      const AEnginePV, AAnnotatorPV: TGameTreePvInput;
      AVariationPvIndex: Integer = -1; AVariationPvPly: Integer = 0;
      const AVariationPvScore: string = '';
      const AVariationPvText: string = ''): TGameTreeCommand;
    function CreateSetHeaderCommand(const AHeader: TGameTreeHeaderInput
      ): TGameTreeCommand;
    function CreateStartSearchCommand(ANodeId: Int64;
      out ASearchId: Int64): TGameTreeCommand; overload;
    function CreateStartSearchCommand(ANodeId: Int64;
      out ASearch: TGameTreeSearchRef): TGameTreeCommand; overload;
    function CreateStoreVariationLineCommand(ADisplayAfterPly, ABasePly: Integer;
      const AMovesText, AAnnotationText: string;
      ASource: TGameTreeMoveSource): TGameTreeCommand;

    procedure ExecuteCommand(ACommand: TGameTreeCommand);
    function PostCommand(ACommand: TGameTreeCommand): Boolean;
    function ProcessCommands: Integer;
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
    'game-tree-store-search-move-variation',
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

function TGameTreeActor.CreateAddMainlineMoveCommand(APlyNumber: Integer;
  const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcAddMainlineMove);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  Result.PlyNumber := APlyNumber;
  Result.MoveText := Trim(AMoveText);
  Result.MoveSource := ASource;
end;

function TGameTreeActor.CreateAppendMainlineMoveCommand(
  const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcAppendMainlineMove);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  Result.MoveText := Trim(AMoveText);
  Result.MoveSource := ASource;
end;

function TGameTreeActor.CreateAppendMainlineSnapshotMoveCommand(
  const AHeader: TGameTreeHeaderInput; const AMoveText,
  AAnnotationText: string; const AMainline: TGameTreeMainlineInput;
  const AEnginePV: TGameTreePvInput; ASource: TGameTreeMoveSource
  ): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcAppendMainlineSnapshotMove);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  Result.HeaderInput := AHeader;
  Result.MoveText := Trim(AMoveText);
  Result.AnnotationText := AAnnotationText;
  Result.MainlineInput.RecordClock := AMainline.RecordClock;
  Result.MainlineInput.WhiteRemainingSeconds :=
    AMainline.WhiteRemainingSeconds;
  Result.MainlineInput.BlackRemainingSeconds :=
    AMainline.BlackRemainingSeconds;
  Result.MainlineInput.WhiteUsedSeconds := AMainline.WhiteUsedSeconds;
  Result.MainlineInput.BlackUsedSeconds := AMainline.BlackUsedSeconds;
  Result.EnginePvInput := AEnginePV;
  Result.MoveSource := ASource;
end;

function TGameTreeActor.CreateCancelSearchCommand(
  ASearchId: Int64): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcCancelSearch);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
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
  Result := TGameTreeCommand.Create(gtcReleaseSearch);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
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
  Result := TGameTreeCommand.Create(gtcSearchDone);
  Result.CommandId := NextCommandId;
  Result.SearchId := ASearchId;
  Result.MoveText := Trim(AMoveText);
  Search := FindSearch(ASearchId);
  if Search <> nil then
    Result.SetSearchRef(Search.SearchRef)
  else
    Result.GameTreeId := FGameTree.GameTreeId;
end;

function TGameTreeActor.CreateSearchDoneCommand(
  const ASearch: TGameTreeSearchRef; const AMoveText: string): TGameTreeCommand;
begin
  Result := CreateSearchDoneCommand(ASearch.SearchId, AMoveText);
  Result.SetSearchRef(ASearch);
end;

function TGameTreeActor.CreateRecordAnnotatorPVCommand(ANodeId: Int64;
  const AScore, APV: string): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcRecordAnnotatorPV);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  Result.NodeId := ANodeId;
  Result.ScoreText := Trim(AScore);
  Result.PvText := Trim(APV);
end;

function TGameTreeActor.CreateRecordEnginePVCommand(ANodeId: Int64;
  const AScore, APV: string): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcRecordEnginePV);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  Result.NodeId := ANodeId;
  Result.ScoreText := Trim(AScore);
  Result.PvText := Trim(APV);
end;

function TGameTreeActor.CreateStoreSearchMoveVariationCommand(
  ASearchId: Int64; ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcStoreSearchMoveVariation);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  Result.SearchId := ASearchId;
  Result.MoveSource := ASource;
end;

function TGameTreeActor.CreateStoreSearchMoveVariationCommand(
  const ASearch: TGameTreeSearchRef;
  ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := CreateStoreSearchMoveVariationCommand(ASearch.SearchId, ASource);
  Result.SetSearchRef(ASearch);
end;

function TGameTreeActor.CreateStoreMoveVariationCommand(ANodeId: Int64;
  const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcStoreMoveVariation);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  Result.NodeId := ANodeId;
  Result.MoveText := Trim(AMoveText);
  Result.MoveSource := ASource;
end;

function TGameTreeActor.CreateClearStoredVariationsCommand: TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcClearStoredVariations);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
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

    TargetLine := TGameTreeVariationLine.Create;
    TargetLine.BasePly := SourceLine.BasePly;
    TargetLine.DisplayAfterPly := SourceLine.DisplayAfterPly;
    TargetLine.MovesText := SourceLine.MovesText;
    TargetLine.AnnotationText := SourceLine.AnnotationText;
    ACommand.RebuildVariationLines.Add(TargetLine);
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
  AddLine(BoolText(ACommand.AnnotatorPvInput.RecordPV));
  AddLine(IntToStr(ACommand.AnnotatorPvInput.BasePly));
  AddLine(ACommand.AnnotatorPvInput.Score);
  AddLine(ACommand.AnnotatorPvInput.PV);

  AddLine(IntToStr(ACommand.VariationIndex));
  AddLine(IntToStr(ACommand.PlyNumber));
  AddLine(ACommand.ScoreText);
  AddLine(ACommand.PvText);
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
    end;
  end;
end;

procedure TGameTreeActor.ClearRebuildSignature;
begin
  FLastRebuildSignature := '';
end;

function TGameTreeActor.CreateRebuildFromInputsCommand(
  const AHeader: TGameTreeHeaderInput;
  const AMainline: TGameTreeMainlineInput;
  const AEnginePV, AAnnotatorPV: TGameTreePvInput;
  AVariationPvIndex: Integer; AVariationPvPly: Integer;
  const AVariationPvScore: string; const AVariationPvText: string
  ): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcRebuildFromInputs);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  CopyStoredVariationsToCommand(Result);
  Result.HeaderInput := AHeader;
  Result.MainlineInput.RecordClock := AMainline.RecordClock;
  Result.MainlineInput.WhiteRemainingSeconds :=
    AMainline.WhiteRemainingSeconds;
  Result.MainlineInput.BlackRemainingSeconds :=
    AMainline.BlackRemainingSeconds;
  Result.MainlineInput.WhiteUsedSeconds := AMainline.WhiteUsedSeconds;
  Result.MainlineInput.BlackUsedSeconds := AMainline.BlackUsedSeconds;
  if AMainline.Moves <> nil then
    Result.MainlineInput.Moves.Assign(AMainline.Moves);
  if AMainline.Annotations <> nil then
    Result.MainlineInput.Annotations.Assign(AMainline.Annotations);
  Result.EnginePvInput := AEnginePV;
  Result.AnnotatorPvInput := AAnnotatorPV;
  Result.VariationIndex := AVariationPvIndex;
  Result.PlyNumber := AVariationPvPly;
  Result.ScoreText := Trim(AVariationPvScore);
  Result.PvText := Trim(AVariationPvText);
end;

function TGameTreeActor.CreateSetHeaderCommand(
  const AHeader: TGameTreeHeaderInput): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcSetHeader);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  Result.HeaderInput := AHeader;
end;

function TGameTreeActor.CreateStartSearchCommand(ANodeId: Int64;
  out ASearchId: Int64): TGameTreeCommand;
begin
  ASearchId := NextSearchId;
  Result := TGameTreeCommand.Create(gtcStartSearch);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
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
  Result := TGameTreeCommand.Create(gtcStoreVariationLine);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
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
  LVariationIndex: Integer;
  LVariationMoves: TStringList;
  LVariationPly: Integer;
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
  if Trim(ANode.VariationKey) <> '' then
  begin
    if not FGameTree.ParseVariationKey(ANode.VariationKey, LBasePly,
      LDisplayAfterPly, LVariationIndex, LVariationPly) then
    begin
      Reject(ACommand, 'invalid variation key');
      Exit;
    end;
    VariationLine := FGameTree.VariationLine[LVariationIndex];
    if VariationLine = nil then
    begin
      Reject(ACommand, 'variation line not found');
      Exit;
    end;

    LVariationMoves := TStringList.Create;
    try
      ExtractStrings([' ', #9, #10, #13], [],
        PChar(Trim(VariationLine.MovesText)), LVariationMoves);
      if LVariationPly > LVariationMoves.Count then
        LVariationPly := LVariationMoves.Count;
      LMovesText := '';
      for I := 0 to LVariationPly - 1 do
      begin
        if LMovesText <> '' then
          LMovesText += ' ';
        LMovesText += LVariationMoves[I];
      end;
      if LMovesText <> '' then
        LMovesText += ' ';
      LMovesText += LMoveText;
    finally
      LVariationMoves.Free;
    end;
  end
  else
  begin
    if ANode.PlyNumber < FGameTree.MainlineCount then
      LDisplayAfterPly := ANode.PlyNumber + 1;
    LMovesText := LMoveText;
  end;

  ACommand.VariationIndex := FGameTree.StoreVariationLine(
    LDisplayAfterPly, LBasePly, LMovesText, '', AChanged);
  if ACommand.VariationIndex < 0 then
  begin
    Reject(ACommand, 'variation line was not stored');
    Exit;
  end;
  ACommand.NodeId := ANode.NodeId;
  ACommand.BasePly := LBasePly;
  ACommand.DisplayAfterPly := LDisplayAfterPly;
  ACommand.PlyNumber := LVariationPly + 1;
  ACommand.MoveText := LMovesText;
  ACommand.Accepted := True;
  Result := True;
end;

procedure TGameTreeActor.ExecuteCommand(ACommand: TGameTreeCommand);
var
  Changed: Boolean;
  InvalidateRebuildSignature: Boolean;
  Node: TGameTreePlyNode;
  RebuildSignature: string;
  Search: TGameTreeSearchRecord;
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
        ACommand.Accepted := True;
        InvalidateRebuildSignature := True;
        Inc(FRevision);
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
        ACommand.Accepted := True;
        InvalidateRebuildSignature := True;
        Inc(FRevision);
      end;
    gtcAppendMainlineSnapshotMove:
      begin
        FGameTree.SetHeader(ACommand.HeaderInput.EventName,
          ACommand.HeaderInput.WhiteName, ACommand.HeaderInput.BlackName,
          ACommand.HeaderInput.ResultText, ACommand.HeaderInput.StartingFEN,
          Changed);
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
        ACommand.Accepted := True;
        InvalidateRebuildSignature := True;
        Inc(FRevision);
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
        ACommand.Accepted := True;
        if Changed then
        begin
          InvalidateRebuildSignature := True;
          Inc(FRevision);
        end;
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
        ACommand.Accepted := True;
        Inc(FRevision);
      end;
    gtcCancelSearch:
      begin
        Search := FindSearch(ACommand.SearchId);
        if Search = nil then
        begin
          Reject(ACommand, 'search id not found');
          Exit;
        end;
        if not SearchCommandMatches(ACommand, Search) then
        begin
          Reject(ACommand, 'search reference mismatch');
          Exit;
        end;
        if Search.State <> gssActive then
        begin
          Reject(ACommand, 'search is not active');
          Exit;
        end;
        Search.State := gssCancelled;
        ACommand.SetSearchRef(Search.SearchRef);
        ACommand.Accepted := True;
        Inc(FRevision);
      end;
    gtcSearchDone:
      begin
        Search := FindSearch(ACommand.SearchId);
        if Search = nil then
        begin
          Reject(ACommand, 'search id not found');
          Exit;
        end;
        if not SearchCommandMatches(ACommand, Search) then
        begin
          Reject(ACommand, 'search reference mismatch');
          Exit;
        end;
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
        ACommand.Accepted := True;
        Inc(FRevision);
      end;
    gtcReleaseSearch:
      begin
        Search := FindSearch(ACommand.SearchId);
        if Search = nil then
        begin
          Reject(ACommand, 'search id not found');
          Exit;
        end;
        if not SearchCommandMatches(ACommand, Search) then
        begin
          Reject(ACommand, 'search reference mismatch');
          Exit;
        end;
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
        ACommand.Accepted := True;
        Inc(FRevision);
      end;
    gtcRecordEnginePV:
      begin
        if FGameTree.FindNodeById(ACommand.NodeId) = nil then
        begin
          Reject(ACommand, 'engine PV target node does not exist');
          Exit;
        end;
        if not FGameTree.RecordEnginePVForNodeId(ACommand.NodeId,
          ACommand.ScoreText, ACommand.PvText, Changed) then
        begin
          Reject(ACommand, 'engine PV was not recorded');
          Exit;
        end;
        ACommand.Accepted := True;
        if Changed then
        begin
          InvalidateRebuildSignature := True;
          Inc(FRevision);
        end;
      end;
    gtcRecordAnnotatorPV:
      begin
        if FGameTree.FindNodeById(ACommand.NodeId) = nil then
        begin
          Reject(ACommand, 'annotator PV target node does not exist');
          Exit;
        end;
        if not FGameTree.RecordAnnotatorPVForNodeId(ACommand.NodeId,
          ACommand.ScoreText, ACommand.PvText, Changed) then
        begin
          Reject(ACommand, 'annotator PV was not recorded');
          Exit;
        end;
        ACommand.Accepted := True;
        if Changed then
        begin
          InvalidateRebuildSignature := True;
          Inc(FRevision);
        end;
      end;
    gtcStoreSearchMoveVariation:
      begin
        Search := FindSearch(ACommand.SearchId);
        if Search = nil then
        begin
          Reject(ACommand, 'search id not found');
          Exit;
        end;
        if not SearchCommandMatches(ACommand, Search) then
        begin
          Reject(ACommand, 'search reference mismatch');
          Exit;
        end;
        if Search.State <> gssDone then
        begin
          Reject(ACommand, 'search is not done');
          Exit;
        end;
        Node := FGameTree.FindNodeById(Search.NodeId);
        if Node = nil then
        begin
          Reject(ACommand, 'search target node no longer exists');
          Exit;
        end;

        if not StoreMoveVariationFromNode(ACommand, Node,
          Search.ResultMove, Changed) then
          Exit;
        if Changed then
        begin
          InvalidateRebuildSignature := True;
          Inc(FRevision);
        end;
      end;
    gtcStoreMoveVariation:
      begin
        Node := FGameTree.FindNodeById(ACommand.NodeId);
        if Node = nil then
        begin
          Reject(ACommand, 'variation target node does not exist');
          Exit;
        end;
        if not StoreMoveVariationFromNode(ACommand, Node,
          ACommand.MoveText, Changed) then
          Exit;
        if Changed then
        begin
          InvalidateRebuildSignature := True;
          Inc(FRevision);
        end;
      end;
    gtcClearStoredVariations:
      begin
        if FGameTree.VariationLineCount = 0 then
        begin
          ACommand.Accepted := True;
          Exit;
        end;
        FGameTree.ClearStoredVariations;
        ACommand.Accepted := True;
        InvalidateRebuildSignature := True;
        Inc(FRevision);
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
              ACommand.ScoreText, ACommand.PvText));
        ACommand.Accepted := True;
        FLastRebuildSignature := RebuildSignature;
        Inc(FRevision);
      end;
    gtcSetHeader:
      begin
        FGameTree.SetHeader(ACommand.HeaderInput.EventName,
          ACommand.HeaderInput.WhiteName, ACommand.HeaderInput.BlackName,
          ACommand.HeaderInput.ResultText, ACommand.HeaderInput.StartingFEN,
          Changed);
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
        ACommand.Accepted := True;
        if Changed then
        begin
          InvalidateRebuildSignature := True;
          Inc(FRevision);
        end;
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
var
  CommandObject: TObject;
begin
  Result := 0;
  while FCommandQueue.TryPop(CommandObject) do
  begin
    try
      if CommandObject is TGameTreeCommand then
        ExecuteCommand(TGameTreeCommand(CommandObject));
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
