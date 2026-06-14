unit uGameTreeActor;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils,
  uGameTree, uThreadMessageQueue;

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
    gtcStoreVariationLine,
    gtcStartSearch,
    gtcCancelSearch,
    gtcSearchDone,
    gtcRecordAnnotatorPV,
    gtcStoreSearchMoveVariation,
    gtcStoreMoveVariation,
    gtcClearStoredVariations
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
    PlyNumber: Integer;
    DisplayAfterPly: Integer;
    BasePly: Integer;
    Accepted: Boolean;
    ErrorText: string;
    CreatedNodeId: Int64;
    ScoreText: string;
    PvText: string;
    VariationIndex: Integer;
    constructor Create(AKind: TGameTreeActorCommandKind); reintroduce;
  end;

  TGameTreeActor = class
  private
    FCommandQueue: TThreadMessageQueue;
    FGameTree: TGameTree;
    FNextCommandId: Int64;
    FNextSearchId: Int64;
    FOwnsGameTree: Boolean;
    FRevision: Int64;
    FSearches: TObjectList;
    function FindSearch(ASearchId: Int64): TGameTreeSearchRecord;
    function NextCommandId: Int64;
    function NextSearchId: Int64;
    procedure Reject(ACommand: TGameTreeCommand; const AErrorText: string);
    function StoreMoveVariationFromNode(ACommand: TGameTreeCommand;
      ANode: TGameTreePlyNode; const AMoveText: string): Boolean;
  public
    constructor Create(AGameTree: TGameTree = nil;
      AOwnsGameTree: Boolean = True);
    destructor Destroy; override;

    function CreateAddMainlineMoveCommand(APlyNumber: Integer;
      const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
    function CreateAppendMainlineMoveCommand(const AMoveText: string;
      ASource: TGameTreeMoveSource): TGameTreeCommand;
    function CreateCancelSearchCommand(ASearchId: Int64): TGameTreeCommand;
    function CreateSearchDoneCommand(ASearchId: Int64;
      const AMoveText: string): TGameTreeCommand;
    function CreateRecordAnnotatorPVCommand(ANodeId: Int64; const AScore,
      APV: string): TGameTreeCommand;
    function CreateStoreSearchMoveVariationCommand(ASearchId: Int64;
      ASource: TGameTreeMoveSource): TGameTreeCommand;
    function CreateStoreMoveVariationCommand(ANodeId: Int64;
      const AMoveText: string; ASource: TGameTreeMoveSource): TGameTreeCommand;
    function CreateClearStoredVariationsCommand: TGameTreeCommand;
    function CreateStartSearchCommand(ANodeId: Int64;
      out ASearchId: Int64): TGameTreeCommand;
    function CreateStoreVariationLineCommand(ADisplayAfterPly, ABasePly: Integer;
      const AMovesText, AAnnotationText: string;
      ASource: TGameTreeMoveSource): TGameTreeCommand;

    procedure ExecuteCommand(ACommand: TGameTreeCommand);
    function PostCommand(ACommand: TGameTreeCommand): Boolean;
    function ProcessCommands: Integer;
    function SearchResult(ASearchId: Int64; out ANodeId: Int64;
      out AMoveText: string): Boolean;
    function SearchState(ASearchId: Int64;
      out AState: TGameTreeSearchState): Boolean;

    property GameTree: TGameTree read FGameTree;
    property Revision: Int64 read FRevision;
  end;

implementation

uses
  uDraughtsBoard;

constructor TGameTreeCommand.Create(AKind: TGameTreeActorCommandKind);
const
  CommandNames: array[TGameTreeActorCommandKind] of string = (
    'game-tree-add-mainline-move',
    'game-tree-append-mainline-move',
    'game-tree-store-variation-line',
    'game-tree-start-search',
    'game-tree-cancel-search',
    'game-tree-search-done',
    'game-tree-record-annotator-pv',
    'game-tree-store-search-move-variation',
    'game-tree-store-move-variation',
    'game-tree-clear-stored-variations'
  );
begin
  inherited Create(CommandNames[AKind]);
  CommandKind := AKind;
  MoveSource := gmsUnknown;
  PlyNumber := -1;
  DisplayAfterPly := -1;
  BasePly := -1;
  VariationIndex := -1;
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

function TGameTreeActor.CreateCancelSearchCommand(
  ASearchId: Int64): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcCancelSearch);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  Result.SearchId := ASearchId;
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
  begin
    Result.GameTreeId := Search.GameTreeId;
    Result.NodeId := Search.NodeId;
  end
  else
    Result.GameTreeId := FGameTree.GameTreeId;
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

function TGameTreeActor.CreateStoreSearchMoveVariationCommand(
  ASearchId: Int64; ASource: TGameTreeMoveSource): TGameTreeCommand;
begin
  Result := TGameTreeCommand.Create(gtcStoreSearchMoveVariation);
  Result.CommandId := NextCommandId;
  Result.GameTreeId := FGameTree.GameTreeId;
  Result.SearchId := ASearchId;
  Result.MoveSource := ASource;
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

procedure TGameTreeActor.Reject(ACommand: TGameTreeCommand;
  const AErrorText: string);
begin
  if ACommand = nil then
    Exit;
  ACommand.Accepted := False;
  ACommand.ErrorText := AErrorText;
end;

function TGameTreeActor.StoreMoveVariationFromNode(
  ACommand: TGameTreeCommand; ANode: TGameTreePlyNode;
  const AMoveText: string): Boolean;
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
    LDisplayAfterPly, LBasePly, LMovesText, '');
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
  Node: TGameTreePlyNode;
  Search: TGameTreeSearchRecord;
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
        Inc(FRevision);
      end;
    gtcStoreVariationLine:
      begin
        ACommand.VariationIndex := FGameTree.StoreVariationLine(
          ACommand.DisplayAfterPly, ACommand.BasePly, ACommand.MoveText,
          ACommand.AnnotationText);
        if ACommand.VariationIndex < 0 then
        begin
          Reject(ACommand, 'variation line was not stored');
          Exit;
        end;
        ACommand.Accepted := True;
        Inc(FRevision);
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
        if Search.State <> gssActive then
        begin
          Reject(ACommand, 'search is not active');
          Exit;
        end;
        Search.State := gssCancelled;
        ACommand.NodeId := Search.NodeId;
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
        ACommand.GameTreeId := Search.GameTreeId;
        ACommand.NodeId := Search.NodeId;
        ACommand.Accepted := True;
        Inc(FRevision);
      end;
    gtcRecordAnnotatorPV:
      begin
        if FGameTree.FindNodeById(ACommand.NodeId) = nil then
        begin
          Reject(ACommand, 'annotator PV target node does not exist');
          Exit;
        end;
        if not FGameTree.RecordAnnotatorPVForNodeId(ACommand.NodeId,
          ACommand.ScoreText, ACommand.PvText) then
        begin
          Reject(ACommand, 'annotator PV was not recorded');
          Exit;
        end;
        ACommand.Accepted := True;
        Inc(FRevision);
      end;
    gtcStoreSearchMoveVariation:
      begin
        Search := FindSearch(ACommand.SearchId);
        if Search = nil then
        begin
          Reject(ACommand, 'search id not found');
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
          Search.ResultMove) then
          Exit;
        Inc(FRevision);
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
          ACommand.MoveText) then
          Exit;
        Inc(FRevision);
      end;
    gtcClearStoredVariations:
      begin
        FGameTree.ClearStoredVariations;
        ACommand.Accepted := True;
        Inc(FRevision);
      end;
  end;
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

end.
