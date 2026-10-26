unit uAnalysisCoordinator;
{$mode objfpc}{$H+}
interface
uses SysUtils, uDraughtsBoard, uGameTree, uGameTreeActor, uGameTreeSearchRef,
  uGameOrchestrator, uPvSnapshot;
type
  TAutoPlayCoordinator = class
  private
    FActive: Boolean;
    FBasePly, FMoveCount: Integer;
    FTreeId, FNodeId: Int64;
    FMovesText: string;
    FSearch: TGameTreeSearchRef;
  public
    procedure BeginLine(ATree: TGameTree; ANode: TGameTreePlyNode);
    procedure Stop;
    procedure TrackSearch(const ASearch: TGameTreeSearchRef);
    procedure ClearSearch;
    function SearchMatches(const ASearch: TGameTreeSearchRef): Boolean;
    function CanContinue(ATree: TGameTree; AState: TGameOrchestratorState): Boolean;
    function CreateMoveCommand(AActor: TGameTreeActor; ATree: TGameTree;
      ABoard: TDraughtsBoard; const AMove: string;
      out AErrorText: string): TGameTreeCommand;
    procedure MoveStored(ACommand: TGameTreeCommand);
    property Active: Boolean read FActive;
    property Search: TGameTreeSearchRef read FSearch;
    property TreeId: Int64 read FTreeId;
    property NodeId: Int64 read FNodeId;
    property BasePly: Integer read FBasePly;
    property MoveCount: Integer read FMoveCount;
    property MovesText: string read FMovesText;
  end;

  // Main-thread coordination only. Actors, trees, snapshots and runners are borrowed.
  TAnalysisCoordinator = class
  private
    FSearch: TGameTreeSearchRef;
    FAnalyzerSignature, FMctsSignature: string;
  public
    procedure TrackSearch(const ASearch: TGameTreeSearchRef);
    procedure ClearSearch;
    function SearchMatches(const ASearch: TGameTreeSearchRef): Boolean;
    procedure InvalidateAnalyzer;
    procedure InvalidateMcts;
    function RestartAnalyzerFor(const ASignature: string): Boolean;
    function RestartMctsFor(const ASignature: string): Boolean;
    property Search: TGameTreeSearchRef read FSearch;
  end;
function StartAnalysisSearch(AActor: TGameTreeActor; ANode: TGameTreePlyNode;
  out ASearch: TGameTreeSearchRef; out AErrorText: string): Boolean;
function AcceptSearchMove(AActor: TGameTreeActor; const ASearch: TGameTreeSearchRef;
  const AMoveText: string; out AErrorText: string): Boolean;
function CancelGameTreeSearch(AActor: TGameTreeActor; const ASearch: TGameTreeSearchRef): Boolean;
function ReleaseGameTreeSearch(AActor: TGameTreeActor; const ASearch: TGameTreeSearchRef): Boolean;
function ReleaseRejectedSearchIfFinished(AActor: TGameTreeActor;
  const ASearch: TGameTreeSearchRef): Boolean;
function ResolveActiveAnalysisSnapshot(AActor: TGameTreeActor; ASnapshot: TPvSnapshot;
  out AGameTree: TGameTree; out ANode: TGameTreePlyNode): Boolean;
function TryResolveAnalyzerSnapshotNode(AGameTree: TGameTree; ASnapshot: TPvSnapshot;
  out ANode: TGameTreePlyNode): Boolean;
function AnalyzerSnapshotIsTransient(ASnapshot: TPvSnapshot): Boolean;
function AnalysisSnapshotKey(ASnapshot: TPvSnapshot): string;
function DisplayedPositionSignature(AGameTree: TGameTree; ANodeId: Int64;
  const AStartingFEN, AMovesText: string; AGameState: TGameOrchestratorState): string;
function AnalysisPositionIsTerminal(AHasLegalMove, APreview: Boolean;
  ABrowseBasePly, ADisplayedMoveCount, ATotalMoveCount: Integer;
  AGameState: TGameOrchestratorState): Boolean;
implementation
function ExecuteAnalysisCommand(AActor: TGameTreeActor; ACommand: TGameTreeCommand;
  out AErrorText: string): Boolean;
begin
  AErrorText := '';
  Result := False;
  if (AActor = nil) or (ACommand = nil) then
  begin AErrorText := 'game tree command is unavailable'; Exit; end;
  AActor.ExecuteCommand(ACommand);
  Result := ACommand.Accepted;
  if not Result then AErrorText := ACommand.ErrorText;
end;
function StartAnalysisSearch(AActor: TGameTreeActor; ANode: TGameTreePlyNode;
  out ASearch: TGameTreeSearchRef; out AErrorText: string): Boolean;
var Command: TGameTreeCommand;
begin
  ASearch := EmptyGameTreeSearchRef;
  AErrorText := '';
  Result := False;
  if (AActor = nil) or (ANode = nil) then
  begin AErrorText := 'no game-tree node'; Exit; end;
  Command := AActor.CreateStartSearchCommand(ANode.NodeId, ASearch);
  try
    Result := ExecuteAnalysisCommand(AActor, Command, AErrorText);
    if not Result then ASearch := EmptyGameTreeSearchRef;
  finally Command.Free; end;
end;
procedure TAnalysisCoordinator.TrackSearch(const ASearch: TGameTreeSearchRef);
begin
  if not IsValidGameTreeSearchRef(ASearch) then ClearSearch
  else FSearch := ASearch;
end;
procedure TAnalysisCoordinator.ClearSearch;
begin FSearch := EmptyGameTreeSearchRef; end;
function TAnalysisCoordinator.SearchMatches(const ASearch: TGameTreeSearchRef): Boolean;
begin
  Result := IsValidGameTreeSearchRef(ASearch) and SameGameTreeSearchRef(FSearch, ASearch);
end;
procedure TAnalysisCoordinator.InvalidateAnalyzer;
begin FAnalyzerSignature := ''; end;
procedure TAnalysisCoordinator.InvalidateMcts;
begin FMctsSignature := ''; end;
function TAnalysisCoordinator.RestartAnalyzerFor(const ASignature: string): Boolean;
begin
  Result := ASignature <> FAnalyzerSignature;
  if Result then FAnalyzerSignature := ASignature;
end;
function TAnalysisCoordinator.RestartMctsFor(const ASignature: string): Boolean;
begin
  Result := ASignature <> FMctsSignature;
  if Result then FMctsSignature := ASignature;
end;
function AnalyzerSnapshotIsTransient(ASnapshot: TPvSnapshot): Boolean;
begin Result := (ASnapshot <> nil) and ASnapshot.Transient; end;
function AnalysisSnapshotKey(ASnapshot: TPvSnapshot): string;
var Search: TGameTreeSearchRef;
begin
  Result := '';
  if ASnapshot = nil then Exit;
  Search := ASnapshot.SearchRef;
  if IsValidGameTreeSearchRef(Search) then
    Result := 'search:' + IntToStr(Search.GameTreeId) + ':' +
      IntToStr(Search.SearchId) + ':' + IntToStr(Search.NodeId)
  else Result := 'display';
end;
function AnalysisPositionIsTerminal(AHasLegalMove, APreview: Boolean;
  ABrowseBasePly, ADisplayedMoveCount, ATotalMoveCount: Integer;
  AGameState: TGameOrchestratorState): Boolean;
begin
  Result := (not AHasLegalMove) or
    ((not APreview) and (AGameState = gosGameOver) and
      ((ABrowseBasePly < 0) or (ADisplayedMoveCount >= ATotalMoveCount)));
end;
function AcceptSearchMove(AActor: TGameTreeActor;
  const ASearch: TGameTreeSearchRef; const AMoveText: string;
  out AErrorText: string): Boolean;
var
  Command: TGameTreeCommand;
begin
  Result := False;
  AErrorText := '';
  if (AActor = nil) or (not IsValidGameTreeSearchRef(ASearch)) then
  begin
    AErrorText := 'invalid search';
    Exit;
  end;

  Command := AActor.CreateSearchDoneCommand(ASearch, AMoveText);
  try
    Result := ExecuteAnalysisCommand(AActor, Command, AErrorText);
  finally
    Command.Free;
  end;
end;

function CancelGameTreeSearch(AActor: TGameTreeActor;
  const ASearch: TGameTreeSearchRef): Boolean;
var
  Command: TGameTreeCommand;
  LErrorText: string;
begin
  Result := False;
  if (AActor = nil) or (not IsValidGameTreeSearchRef(ASearch)) then
    Exit;

  Command := AActor.CreateCancelSearchCommand(ASearch);
  try
    Result := ExecuteAnalysisCommand(AActor, Command, LErrorText);
  finally
    Command.Free;
  end;
end;

function ReleaseGameTreeSearch(AActor: TGameTreeActor;
  const ASearch: TGameTreeSearchRef): Boolean;
var
  Command: TGameTreeCommand;
begin
  Result := False;
  if (AActor = nil) or (not IsValidGameTreeSearchRef(ASearch)) then
    Exit;

  Command := AActor.CreateReleaseSearchCommand(ASearch);
  try
    Result := AActor.PostCommand(Command);
    Command := nil;
  finally
    Command.Free;
  end;
end;

function ReleaseRejectedSearchIfFinished(AActor: TGameTreeActor;
  const ASearch: TGameTreeSearchRef): Boolean;
var
  LSearchState: TGameTreeSearchState;
begin
  Result := False;
  if (AActor = nil) or (not IsValidGameTreeSearchRef(ASearch)) then
    Exit;
  if AActor.SearchState(ASearch, LSearchState) and
    (LSearchState in [gssCancelled, gssFailed]) then
    Result := ReleaseGameTreeSearch(AActor, ASearch);
end;
function ResolveActiveAnalysisSnapshot(AActor: TGameTreeActor; ASnapshot: TPvSnapshot; out AGameTree: TGameTree;
  out ANode: TGameTreePlyNode): Boolean;
var
  LSearch: TGameTreeSearchRef;
  LSearchState: TGameTreeSearchState;
begin
  Result := False;
  AGameTree := nil;
  ANode := nil;
  if ASnapshot = nil then
    LSearch := EmptyGameTreeSearchRef
  else
    LSearch := ASnapshot.SearchRef;
  if not IsValidGameTreeSearchRef(LSearch) then
    Exit;

  if (AActor = nil) or (AActor.GameTree.GameTreeId <> LSearch.GameTreeId) then
    Exit;
  if (not AActor.SearchState(LSearch, LSearchState)) or
    (LSearchState <> gssActive) then
  begin
      Exit;
  end;
  ANode := AActor.GameTree.FindNodeById(LSearch.NodeId);
  if ANode = nil then
  begin
      AGameTree := nil;
    Exit;
  end;

  AGameTree := AActor.GameTree;
  Result := AGameTree <> nil;
end;
function TryResolveAnalyzerSnapshotNode(AGameTree: TGameTree;
  ASnapshot: TPvSnapshot; out ANode: TGameTreePlyNode): Boolean;
var
  LSearch: TGameTreeSearchRef;
begin
  Result := False;
  ANode := nil;
  if (AGameTree = nil) or (ASnapshot = nil) then
    Exit;

  LSearch := ASnapshot.SearchRef;
  if IsValidGameTreeSearchRef(LSearch) and
    (LSearch.GameTreeId = AGameTree.GameTreeId) and (LSearch.NodeId > 0) then
    ANode := AGameTree.FindNodeById(LSearch.NodeId);

  if ANode = nil then
  begin
    if ASnapshot.BasePly <= 0 then
      ANode := AGameTree.Root
    else
      ANode := AGameTree.MainlineNode[ASnapshot.BasePly];
  end;

  Result := ANode <> nil;
end;
function DisplayedPositionSignature(AGameTree: TGameTree;
  ANodeId: Int64; const AStartingFEN, AMovesText: string;
  AGameState: TGameOrchestratorState): string;
var
  LGameTreeId: Int64;
begin
  LGameTreeId := 0;
  if AGameTree <> nil then
    LGameTreeId := AGameTree.GameTreeId;
  Result := IntToStr(LGameTreeId) + #10 + IntToStr(ANodeId) + #10 +
    AStartingFEN + #10 + AMovesText + #10 +
    IntToStr(Ord(AGameState));
end;
procedure TAutoPlayCoordinator.BeginLine(ATree: TGameTree; ANode: TGameTreePlyNode);
begin
  FBasePly := ANode.PlyNumber;
  FNodeId := ANode.NodeId;
  FMoveCount := 0;
  FMovesText := '';
  FActive := True;
  FTreeId := ATree.GameTreeId;
  FSearch := EmptyGameTreeSearchRef;
end;
procedure TAutoPlayCoordinator.Stop;
begin
  FActive := False;
  FSearch := EmptyGameTreeSearchRef;
  FTreeId := 0;
  FNodeId := 0;
end;
procedure TAutoPlayCoordinator.TrackSearch(const ASearch: TGameTreeSearchRef);
begin FSearch := ASearch; end;
procedure TAutoPlayCoordinator.ClearSearch;
begin FSearch := EmptyGameTreeSearchRef; end;
function TAutoPlayCoordinator.SearchMatches(const ASearch: TGameTreeSearchRef): Boolean;
begin
  Result := FActive and IsValidGameTreeSearchRef(ASearch) and
    SameGameTreeSearchRef(FSearch, ASearch);
end;
function TAutoPlayCoordinator.CanContinue(ATree: TGameTree;
  AState: TGameOrchestratorState): Boolean;
begin
  Result := (ATree <> nil) and (ATree.GameTreeId = FTreeId) and (AState = gosStopped);
end;
function TAutoPlayCoordinator.CreateMoveCommand(AActor: TGameTreeActor;
  ATree: TGameTree; ABoard: TDraughtsBoard; const AMove: string;
  out AErrorText: string): TGameTreeCommand;
var Move, Moves: string;
begin
  Result := nil;
  AErrorText := '';
  if (ATree = nil) or (AActor = nil) or (ATree.GameTreeId <> FTreeId) then
  begin AErrorText := 'game tree is no longer active'; Exit; end;
  if (ABoard = nil) or not ABoard.TryGetLegalMove(AMove, Move) then
  begin AErrorText := 'engine returned an illegal move: ' + Trim(AMove); Exit; end;
  Moves := Trim(FMovesText);
  if Moves <> '' then Moves += ' ';
  Moves += Move;
  Result := AActor.CreateRecordAutoPlayPVCommand(FNodeId, Moves);
end;
procedure TAutoPlayCoordinator.MoveStored(ACommand: TGameTreeCommand);
begin
  // The form applies actor results before advancing the preview, as before.
  if (ACommand = nil) or not ACommand.Accepted then Exit;
  FMovesText := ACommand.PvText;
  Inc(FMoveCount);
end;

end.
