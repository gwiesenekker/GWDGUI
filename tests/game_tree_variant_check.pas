program game_tree_variant_check;

{$mode objfpc}{$H+}

{ The game tree, actor and builder on an injected variant (review C11).

  The counter test game (uCounterGamePosition) shares nothing with draughts, so
  these checks fail if a generic unit consults the registered default variant
  or assumes draughts move text. Draughts is still linked and registered as the
  default, as in the application; the tests must not depend on it. }

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, uGamePosition, uDraughtsPosition, uCounterGamePosition,
  uGameTree, uGameTreeActor, uGameTreeBuilder, uGameMoveHistory, uGameTreePdn,
  uAnalysisCoordinator, uDisplayedPosition, uPvSnapshot, uGameTreeSearchRef,
  SyncObjs, uGameOrchestrator, uGameRunnerThread, uGameSetupTypes, uEngineBase;

var
  Failures: Integer = 0;

type
  // Collects runner snapshots (runner thread) for the counter-game runner check.
  TRunnerObserver = class
  public
    Lock: TCriticalSection;
    Finished: TEvent;
    PlyCount: Integer;
    State: TGameOrchestratorState;
    ResultText, MovesText, PositionFEN: string;
    PositionIsCounter: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure Snapshot(Sender: TObject; AData: TGameRunnerSnapshot);
  end;

constructor TRunnerObserver.Create;
begin
  inherited Create;
  Lock := TCriticalSection.Create;
  Finished := TEvent.Create(nil, True, False, '');
end;

destructor TRunnerObserver.Destroy;
begin
  Finished.Free;
  Lock.Free;
  inherited Destroy;
end;

procedure TRunnerObserver.Snapshot(Sender: TObject; AData: TGameRunnerSnapshot);
begin
  Lock.Acquire;
  try
    PlyCount := AData.PlyCount;
    State := AData.State;
    ResultText := AData.GameResult;
    MovesText := AData.MovesPlayedText;
    PositionIsCounter := AData.Position is TCounterPosition;
    if AData.Position <> nil then
      PositionFEN := AData.Position.ToFEN;
    if AData.State in [gosGameOver, gosError] then
      Finished.SetEvent;
  finally
    AData.Free;
    Lock.Release;
  end;
end;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', AMessage);
  end;
end;

function MainlineText(ATree: TGameTree): string;
var
  LMoves: TStringList;
begin
  LMoves := TStringList.Create;
  try
    ATree.CopyMainlineMovesTo(LMoves);
    LMoves.Delimiter := ' ';
    Result := LMoves.DelimitedText;
  finally
    LMoves.Free;
  end;
end;

function ReplaySide(ATree: TGameTree; ANode: TGameTreePlyNode; out ASide: TGameSide): Boolean;
var
  LPosition: TGamePosition;
begin
  LPosition := ATree.Variant.CreatePosition;
  try
    Result := ATree.TryBuildPositionAtNode(ANode, LPosition);
    ASide := LPosition.SideToMove;
  finally
    LPosition.Free;
  end;
end;

procedure CheckRootSide(ATree: TGameTree; AExpected: TGameSide; const AContext: string);
var
  LSide: TGameSide;
begin
  Check(ATree.Root.SideToMove = AExpected, AContext + ': root side');
  Check(ReplaySide(ATree, ATree.Root, LSide) and (LSide = AExpected),
    AContext + ': replayed root side agrees');
end;

function Execute(AActor: TGameTreeActor; ACommand: TGameTreeCommand; out AError: string;
  out ANodeId: Int64): Boolean;
begin
  try
    AActor.ExecuteCommand(ACommand);
    Result := ACommand.Accepted;
    AError := ACommand.ErrorText;
    ANodeId := ACommand.CreatedNodeId;
  finally
    ACommand.Free;
  end;
end;

{ G9: the root side follows the variant's default after construction, Clear and
  rebuild, and an explicit header FEN after SetHeader. }
procedure CheckRootSideFollowsVariant;
var
  LWhite: TCounterVariant;
  LBlack: TBlackStartCounterVariant;
  LTree: TGameTree;
begin
  LWhite := TCounterVariant.Create;
  LBlack := TBlackStartCounterVariant.Create;
  try
    LTree := TGameTree.Create(LBlack);
    try
      Check(LTree.Variant = LBlack, 'the tree keeps the injected variant');
      Check(LTree.StartingFEN = 'B:0', 'starting FEN from the injected variant');
      CheckRootSide(LTree, gsBlack, 'black-start variant after construction');
      LTree.Clear;
      CheckRootSide(LTree, gsBlack, 'black-start variant after Clear');
      LTree.BeginRebuild('another signature', 'Event', 'A', 'B', '*', '');
      CheckRootSide(LTree, gsBlack, 'black-start variant after rebuild with the default FEN');
      LTree.SetHeader('Event', 'A', 'B', '*', 'W:2');
      CheckRootSide(LTree, gsWhite, 'explicit White header FEN');
      LTree.Clear;
      CheckRootSide(LTree, gsBlack, 'Clear returns to the variant default');
    finally
      LTree.Free;
    end;
    LTree := TGameTree.Create(LWhite);
    try
      CheckRootSide(LTree, gsWhite, 'white-start variant after construction');
      LTree.SetHeader('Event', 'A', 'B', '*', 'B:1');
      CheckRootSide(LTree, gsBlack, 'explicit Black header FEN');
      LTree.Clear;
      CheckRootSide(LTree, gsWhite, 'white-start variant after Clear');
    finally
      LTree.Free;
    end;
  finally
    LBlack.Free;
    LWhite.Free;
  end;
end;

{ The actor validates and canonicalizes with the tree's own variant. }
procedure CheckActorOnInjectedVariant;
var
  LVariant: TCounterVariant;
  LTree: TGameTree;
  LActor: TGameTreeActor;
  LError: string;
  LNodeId, LBranchId, LSecondId, LAgainId: Int64;
  LBefore: string;
  LBranchCount: Integer;
  LNode: TGameTreePlyNode;
  LPosition: TGamePosition;
  LHeader: TGameTreeHeaderInput;
begin
  LVariant := TCounterVariant.Create;
  LTree := TGameTree.Create(LVariant);
  LActor := TGameTreeActor.Create(LTree, False);
  try
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('p1', gmsHuman), LError, LNodeId),
      'append an alias: ' + LError);
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('two', gmsHuman), LError, LSecondId),
      'append a notation spelling: ' + LError);
    Check(MainlineText(LTree) = '+1 +2', 'mainline stores canonical moves, got ' + MainlineText(LTree));

    // Rejected commands leave the tree unchanged.
    LBefore := MainlineText(LTree);
    LBranchCount := LTree.BranchCount;
    Check(not Execute(LActor, LActor.CreateAppendMainlineMoveCommand('32-28', gmsHuman), LError, LNodeId),
      'draughts move text is not a counter move');
    Check(Pos('Illegal move', LError) > 0, 'rejection names the illegal move: ' + LError);
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('+2', gmsHuman), LError, LNodeId),
      'reach the limit: ' + LError);
    LBefore := MainlineText(LTree);
    Check(not Execute(LActor, LActor.CreateAppendMainlineMoveCommand('+1', gmsHuman), LError, LNodeId),
      'a move past the limit is rejected');
    Check((MainlineText(LTree) = LBefore) and (LTree.BranchCount = LBranchCount),
      'a rejected command leaves mainline and branches unchanged');

    // A branch at ply 2, then the same move in another spelling finds that branch.
    LNode := LTree.MainlineNode[1];
    Check(Execute(LActor, LActor.CreateStoreMoveVariationCommand(LNode.NodeId, 'p1', gmsHuman),
      LError, LBranchId), 'store a variation: ' + LError);
    Check(LTree.BranchCount = LBranchCount + 1, 'the variation adds one branch');
    Check(Execute(LActor, LActor.CreateStoreMoveVariationCommand(LNode.NodeId, 'one', gmsHuman),
      LError, LAgainId), 'store the same variation in another spelling: ' + LError);
    Check(LTree.BranchCount = LBranchCount + 1, 'an equivalent spelling does not add a branch');
    Check(LTree.FindChildByMove(LNode, 'p1') = LTree.FindNodeById(LBranchId),
      'FindChildByMove resolves an alias to the existing child');

    // Nested branch replay through the injected variant.
    Check(Execute(LActor, LActor.CreateStoreMoveVariationCommand(LBranchId, '+2', gmsHuman),
      LError, LNodeId), 'nested branch move: ' + LError);
    LPosition := LVariant.CreatePosition;
    try
      Check(LTree.TryBuildPositionAtNode(LTree.FindNodeById(LNodeId), LPosition) and
        (LPosition.ToFEN = 'B:4'), 'nested branch replays to B:4, got ' + LPosition.ToFEN);
    finally
      LPosition.Free;
    end;

    // An equivalent mainline move at an existing ply keeps the node, its
    // continuation and its analysis.
    Check(Execute(LActor, LActor.CreateRecordEnginePVCommand(LSecondId, '0.5', '+1'), LError, LNodeId),
      'record analysis: ' + LError);
    Check(Execute(LActor, LActor.CreateAddMainlineMoveCommand(2, 'TWO', gmsHuman), LError, LNodeId),
      'equivalent mainline move: ' + LError);
    Check(LTree.MainlineNode[2].NodeId = LSecondId, 'equivalent mainline move keeps the node ID');
    Check(LTree.MainlineCount = 3, 'equivalent mainline move keeps the continuation');
    Check(LTree.MainlineNode[2].EngineScore = '0.5', 'equivalent mainline move keeps analysis');

    // Header reset through the actor uses the variant default.
    LHeader := Default(TGameTreeHeaderInput);
    LHeader.EventName := 'Counter';
    LHeader.WhiteName := 'W';
    LHeader.BlackName := 'B';
    LHeader.ResultText := '*';
    LHeader.StartingFEN := '';
    Check(Execute(LActor, LActor.CreateSetHeaderCommand(LHeader), LError, LNodeId),
      'header with the default FEN: ' + LError);
    Check(LTree.StartingFEN = 'W:0', 'header reset uses the variant default FEN');
  finally
    LActor.Free;
    LTree.Free;
    LVariant.Free;
  end;
end;

{ Completed-move data in another spelling attaches to the right node and does
  not stop at a false mismatch; a different move does stop it. }
procedure CheckCompletedMovesWithEquivalentSpellings;

  function MoveData(const AMove: string; ASeconds: Double): TGameMoveData;
  begin
    Result := Default(TGameMoveData);
    Result.MoveText := AMove;
    Result.SecondsUsed := ASeconds;
  end;

var
  LTree: TGameTree;
  LActor: TGameTreeActor;
  LError: string;
  LNodeId: Int64;
  LData: TGameMoveDataArray;
  LCounter: TCounterVariant;
begin
  // Draughts: the same capture with its captured squares in another order.
  LTree := TGameTree.Create(DraughtsVariant);
  LActor := TGameTreeActor.Create(LTree, False);
  try
    LTree.SetHeader('E', 'W', 'B', '*', 'W:W38,45:B33,24,K6');
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('38x20', gmsHuman), LError, LNodeId),
      'draughts capture: ' + LError);
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('6-11', gmsHuman), LError, LNodeId),
      'draughts reply: ' + LError);
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('45-40', gmsHuman), LError, LNodeId),
      'draughts quiet move: ' + LError);
    Check(LTree.MainlineNode[1].MoveText = '38x20x33x24', 'canonical capture, got ' +
      LTree.MainlineNode[1].MoveText);
    SetLength(LData, 3);
    LData[0] := MoveData('38x20x24x33', 1.5);
    LData[1] := MoveData('6-11', 2.5);
    LData[2] := MoveData('45-40', 3.5);
    Check(RecordGameTreeCompletedMoves(LTree, LData), 'completed moves recorded');
    Check(LTree.MainlineNode[1].HasMoveTime and (LTree.MainlineNode[1].SecondsUsed = 1.5),
      'timing on the capture written in another order');
    Check(LTree.MainlineNode[3].HasMoveTime and (LTree.MainlineNode[3].SecondsUsed = 3.5),
      'a later entry is not skipped after an equivalent spelling');
  finally
    LActor.Free;
    LTree.Free;
  end;

  LTree := TGameTree.Create(DraughtsVariant);
  LActor := TGameTreeActor.Create(LTree, False);
  try
    LTree.SetHeader('E', 'W', 'B', '*', 'W:W38,45:B33,24,K6');
    Execute(LActor, LActor.CreateAppendMainlineMoveCommand('38x20', gmsHuman), LError, LNodeId);
    Execute(LActor, LActor.CreateAppendMainlineMoveCommand('6-11', gmsHuman), LError, LNodeId);
    SetLength(LData, 2);
    LData[0] := MoveData('38x20x24x34', 1.5); // a different captured set
    LData[1] := MoveData('6-11', 2.5);
    RecordGameTreeCompletedMoves(LTree, LData);
    Check(not LTree.MainlineNode[1].HasMoveTime and not LTree.MainlineNode[2].HasMoveTime,
      'a different move stops attaching completed-move data');
  finally
    LActor.Free;
    LTree.Free;
  end;

  // Counter game aliases.
  LCounter := TCounterVariant.Create;
  LTree := TGameTree.Create(LCounter);
  LActor := TGameTreeActor.Create(LTree, False);
  try
    Execute(LActor, LActor.CreateAppendMainlineMoveCommand('+1', gmsHuman), LError, LNodeId);
    Execute(LActor, LActor.CreateAppendMainlineMoveCommand('+2', gmsHuman), LError, LNodeId);
    SetLength(LData, 2);
    LData[0] := MoveData('p1', 4);
    LData[1] := MoveData('two', 5);
    RecordGameTreeCompletedMoves(LTree, LData);
    Check((LTree.MainlineNode[1].SecondsUsed = 4) and (LTree.MainlineNode[2].SecondsUsed = 5),
      'counter aliases attach completed-move data');
  finally
    LActor.Free;
    LTree.Free;
    LCounter.Free;
  end;
end;

{ The notation walker renders through the tree's variant: record notation
  from the game, set-up detection against the game's own start position. }
procedure CheckNotationOnInjectedVariant;
var
  LVariant: TCounterVariant;
  LTree: TGameTree;
  LActor: TGameTreeActor;
  LError, LText: string;
  LNodeId, LFirstId: Int64;
  LHeader: TGameTreeHeaderInput;
begin
  LVariant := TCounterVariant.Create;
  LTree := TGameTree.Create(LVariant);
  LActor := TGameTreeActor.Create(LTree, False);
  try
    Check(not GameTreeHasContent(LTree), 'an empty counter tree has no content');
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('p1', gmsHuman), LError, LFirstId),
      'append: ' + LError);
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('+2', gmsHuman), LError, LNodeId),
      'append: ' + LError);
    Check(Execute(LActor, LActor.CreateStoreMoveVariationCommand(LFirstId, 'p1', gmsHuman),
      LError, LNodeId), 'variation: ' + LError);
    LText := GameTreeToPdnText(LTree);
    Check((Pos('one', LText) > 0) and (Pos('two', LText) > 0),
      'moves are rendered in the game''s record notation: ' + LText);
    Check((Pos('+1', LText) = 0) and (Pos('+2', LText) = 0),
      'no canonical move text in the record: ' + LText);
    Check(Pos('[SetUp', LText) = 0, 'the variant start position is not a set-up: ' + LText);
    Check(Pos('[FEN "W:0"]', LText) > 0, 'FEN tag from the tree: ' + LText);

    LHeader := Default(TGameTreeHeaderInput);
    LHeader.EventName := 'Counter';
    LHeader.WhiteName := 'W';
    LHeader.BlackName := 'B';
    LHeader.ResultText := '*';
    LHeader.StartingFEN := 'W:1';
    Check(Execute(LActor, LActor.CreateSetHeaderCommand(LHeader), LError, LNodeId),
      'set-up header: ' + LError);
    LText := GameTreeToPdnText(LTree);
    Check(Pos('[SetUp "1"]', LText) > 0, 'another start position is a set-up: ' + LText);
  finally
    LActor.Free;
    LTree.Free;
    LVariant.Free;
  end;
end;

{ Analysis state and auto play on a tree of another game: PV bases are
  positions of the tree's game, even when the state started with draughts. }
procedure CheckAnalysisOnInjectedVariant;
var
  LVariant: TCounterVariant;
  LTree: TGameTree;
  LActor: TGameTreeActor;
  LPv: TAnalysisPvState;
  LDisplay: TDisplayedPosition;
  LAutoPlay: TAutoPlayCoordinator;
  LSnapshot: TPvSnapshot;
  LBase, LPosition: TGamePosition;
  LCommand: TGameTreeCommand;
  LError, LText, LScore, LDepth, LTime: string;
  LNodeId: Int64;
  LPly: Integer;
begin
  LVariant := TCounterVariant.Create;
  LTree := TGameTree.Create(LVariant);
  LActor := TGameTreeActor.Create(LTree, False);
  LPv := TAnalysisPvState.Create; // starts with the default game (draughts)
  LDisplay := TDisplayedPosition.Create;
  LAutoPlay := TAutoPlayCoordinator.Create;
  LSnapshot := TPvSnapshot.Create;
  LPosition := nil;
  try
    Check(LSnapshot.BasePosition = nil, 'a new snapshot has no base position');
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('p1', gmsHuman), LError, LNodeId),
      'append: ' + LError);
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('two', gmsHuman), LError, LNodeId),
      'append: ' + LError);

    LPv.SetAnalyzerBaseFromTree(LTree, LNodeId, 2, nil, LDisplay, LActor.Revision);
    Check((LPv.AnalyzerBasePosition is TCounterPosition) and
      (LPv.AnalyzerBasePosition.ToFEN = 'W:3') and (LPv.AnalyzerBaseNodeId = LNodeId),
      'analyzer base replays the counter tree, got ' + LPv.AnalyzerBasePosition.ToFEN);

    Check(Execute(LActor, LActor.CreateRecordEnginePVCommand(LTree.MainlineNode[1].NodeId,
      '0.1', 'two', '3', '0.2'), LError, LNodeId), 'engine PV: ' + LError);
    Check(LPv.VisibleMainPv(LTree, LTree.MainlineNode[2], True, LDisplay, LActor.Revision,
      LBase, LPly, LText, LScore, LDepth, LTime), 'visible PV on the counter tree');
    Check((LPly = 1) and (LBase is TCounterPosition) and (LBase.ToFEN = 'B:1'),
      'visible PV base is the counter position after ply 1');

    LPosition := LVariant.CreatePositionFromFEN('B:1');
    LSnapshot.SetDataWithSearch(LPosition, 1, 'two', '0.1', '3', '', EmptyGameTreeSearchRef,
      False, True);
    Check(CanDisplayTransientAnalysis(LSnapshot, LBase), 'transient analysis on the same counter position');
    LSnapshot.SetDataWithSearch(nil, 1, 'two', '0.1', '3', '', EmptyGameTreeSearchRef, False, True);
    Check(LSnapshot.BasePosition.ToFEN = 'B:1', 'a nil base keeps the snapshot base');

    LAutoPlay.BeginLine(LTree, LTree.MainlineNode[1]);
    LCommand := LAutoPlay.CreateMoveCommand(LActor, LTree, LPosition, 'p2', LError);
    Check(LCommand <> nil, 'auto play accepts a counter alias: ' + LError);
    try
      LActor.ExecuteCommand(LCommand);
      Check(LCommand.Accepted, LCommand.ErrorText);
      LAutoPlay.MoveStored(LCommand);
    finally
      LCommand.Free;
    end;
    Check(LAutoPlay.MovesText = '+2', 'auto play stores the canonical move, got ' + LAutoPlay.MovesText);
    LCommand := LAutoPlay.CreateMoveCommand(LActor, LTree, LPosition, '32-28', LError);
    Check((LCommand = nil) and (Pos('illegal move', LError) > 0), 'draughts move rejected in auto play');
  finally
    LPosition.Free;
    LSnapshot.Free;
    LAutoPlay.Free;
    LDisplay.Free;
    LPv.Free;
    LActor.Free;
    LTree.Free;
    LVariant.Free;
  end;
end;

{ The orchestrator and the game runner on another game: legal moves, the
  end of the game and the result texts all come from the variant. }
procedure CheckOrchestratorOnInjectedVariant;
var
  LVariant: TCounterVariant;
  LGame: TGameOrchestrator;
  LError: string;
  LControl: TTimeControl;
begin
  LVariant := TCounterVariant.Create;
  LGame := TGameOrchestrator.Create(LVariant);
  try
    LGame.NewGame('W:0');
    Check(LGame.Position is TCounterPosition, 'orchestrator position is a counter position');
    LGame.PlayMove('p1', gsWhite, 1, 'human');
    LGame.PlayMove('+2', gsBlack, 1, 'human');
    Check((LGame.MovesPlayedText = '+1 +2') and (LGame.CurrentSide = gsWhite),
      'orchestrator stores canonical moves, got ' + LGame.MovesPlayedText);
    LError := '';
    try
      LGame.PlayMove('32-28', gsWhite, 1, 'human');
    except
      on E: Exception do LError := E.Message;
    end;
    Check(LError = 'Illegal move: 32-28', 'draughts move rejected: ' + LError);
    LGame.PlayMove('two', gsWhite, 1, 'human');
    Check((LGame.State = gosGameOver) and (LGame.GameResult = '1-0') and
      (Pos('counter limit reached', LGame.Log.Text) > 0),
      'the counter rules end the game with the counter result text, got ' + LGame.GameResult);

    LControl := LGame.TimeControl;
    LControl.MinutesPerPeriod := 0.001;
    LGame.TimeControl := LControl;
    LGame.NewGame('B:0');
    LGame.PlayMove('p1', gsBlack, 1, 'human');
    Check((LGame.State = gosGameOver) and (LGame.GameResult = '1-0') and
      (Pos('flag fell for black', LGame.Log.Text) > 0),
      'loss on time uses the variant result text, got ' + LGame.GameResult);
  finally
    LGame.Free;
    LVariant.Free;
  end;
end;

type
  // Counter-game engine whose search always misses its deadline (review M9).
  TTimeoutCounterEngine = class(TGameEngine)
  protected
    function DoStartThinking: string; override;
  end;

function TTimeoutCounterEngine.DoStartThinking: string;
begin
  MarkMoveTimedOut;
  Result := '';
end;

function RenderedMoves(ATree: TGameTree): string;
var
  LOptions: TGameTreePdnRenderOptions;
  LResult: TGameTreePdnRenderResult;
begin
  LOptions := DefaultGameTreePdnRenderOptions;
  LOptions.ShowEnginePVMove := True;
  LOptions.ShowEngineFullPV := True;
  RenderGameTreeMovesToPdn(ATree, LOptions, LResult);
  Result := LResult.Text;
end;

{ G10: move numbers start at the variant's starting move number (chess FEN
  fullmove number) in the tree, the PDN text and analysis lines, and follow a
  header change. }
procedure CheckMoveNumbering;
var
  LVariant: TCounterVariant;
  LTree: TGameTree;
  LActor: TGameTreeActor;
  LError, LText: string;
  LNodeId, LSecondId: Int64;
begin
  Check((GameMoveNumberForPly(gsWhite, 37, 1) = 37) and
    (GameMoveNumberForPly(gsWhite, 37, 2) = 37) and
    (GameMoveNumberForPly(gsWhite, 37, 3) = 38) and
    (GameMoveNumberForPly(gsBlack, 37, 1) = 37) and
    (GameMoveNumberForPly(gsBlack, 37, 2) = 38) and
    (GameMoveNumberForPly(gsBlack, 37, 3) = 38) and
    (GameMoveNumberForPly(gsWhite, 1, 0) = 1) and
    (GameMoveNumberForPly(gsWhite, 0, 1) = 1), 'GameMoveNumberForPly');
  Check((GameSideForPly(gsBlack, 1) = gsBlack) and (GameSideForPly(gsBlack, 2) = gsWhite),
    'GameSideForPly');

  LVariant := TCounterVariant.Create;
  LTree := TGameTree.Create(LVariant);
  LActor := TGameTreeActor.Create(LTree, False);
  try
    Check((LVariant.StartingMoveNumberFromFEN('W:0:37') = 37) and
      (LVariant.StartingMoveNumberFromFEN('W:0') = 1), 'counter starting move number');
    Check(LTree.Root.MoveNumber = 1, 'default root move number');
    LTree.SetHeader('E', 'W', 'B', '*', 'W:0:37');
    Check(LTree.Root.MoveNumber = 37, 'root carries the starting move number');
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('p1', gmsHuman), LError, LNodeId),
      'append: ' + LError);
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('p1', gmsHuman), LError, LSecondId),
      'append: ' + LError);
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('p1', gmsHuman), LError, LNodeId),
      'append: ' + LError);
    Check(Execute(LActor, LActor.CreateStoreMoveVariationCommand(LSecondId, 'p2', gmsHuman),
      LError, LNodeId), 'variation: ' + LError);
    Check((LTree.MainlineNode[1].MoveNumber = 37) and (LTree.MainlineNode[2].MoveNumber = 37) and
      (LTree.MainlineNode[3].MoveNumber = 38), 'White start at move 37: 37, 37, 38');
    LText := GameTreeToPdnText(LTree);
    Check((Pos('37. one', LText) > 0) and (Pos('38. one', LText) > 0) and
      (Pos('(38. two)', LText) > 0) and (Pos('1. ', LText) = 0),
      'PDN text numbers from 37: ' + LText);

    LTree.RecordEnginePV(0, '0.1', '+1 +1 +1');
    LTree.RecordEnginePV(2, '0.1', '+1 +1');
    LText := RenderedMoves(LTree);
    Check(Pos('(37.+1 {E: 0.1} +1 38.+1)', LText) > 0,
      'root analysis line numbers from 37: ' + LText);
    Check(Pos('(38.+1 +1)', LText) > 0,
      'analysis line after Black''s move continues with 38: ' + LText);

    LTree.SetHeader('E', 'W', 'B', '*', 'B:0:37');
    Check((LTree.MainlineNode[1].MoveNumber = 37) and
      (LTree.MainlineNode[1].SideToMove = gsBlack) and
      (LTree.MainlineNode[2].MoveNumber = 38) and (LTree.MainlineNode[3].MoveNumber = 38),
      'a header change renumbers the moves: Black start 37, 38, 38');
    LText := GameTreeToPdnText(LTree);
    Check((Pos('37... one 38. one', LText) > 0) and (Pos('} 37... one', LText) > 0), 'Black start PDN text: ' + LText);

    LTree.Clear;
    Check(LTree.Root.MoveNumber = 1, 'Clear restores move 1');
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('p1', gmsHuman), LError, LNodeId),
      'append after clear: ' + LError);
    Check(LTree.MainlineNode[1].MoveNumber = 1, 'first move after Clear is move 1');
  finally
    LActor.Free;
    LTree.Free;
    LVariant.Free;
  end;

  // Regression: an analysis line at the root of a Black-to-move game numbered
  // White's reply as move 1 instead of 2.
  LVariant := TBlackStartCounterVariant.Create;
  LTree := TGameTree.Create(LVariant);
  try
    LTree.RecordEnginePV(0, '0.1', '+1 +1 +1');
    LText := RenderedMoves(LTree);
    Check(Pos('(1...+1 {E: 0.1} 2.+1 +1)', LText) > 0,
      'Black-start root analysis line: ' + LText);
  finally
    LTree.Free;
    LVariant.Free;
  end;
end;

{ M9: both flag-fall paths ask the game's rules for the result. }
procedure CheckTimeoutOutcome;
var
  LVariant: TCounterVariant;
  LGame: TGameOrchestrator;
  LControl: TTimeControl;
  LSide: TGameSide;
  LStart: string;
begin
  LVariant := TCounterVariant.Create;
  LGame := TGameOrchestrator.Create(LVariant);
  try
    LControl := LGame.TimeControl;
    LControl.MinutesPerPeriod := 0.001;
    LGame.TimeControl := LControl;
    for LSide := Low(TGameSide) to High(TGameSide) do
    begin
      if LSide = gsWhite then LStart := 'W:' else LStart := 'B:';
      // Completed move after the time ran out; the opponent can still win.
      LGame.NewGame(LStart + '0');
      LGame.PlayMove('p1', LSide, 1, 'human');
      Check((LGame.State = gosGameOver) and
        (LGame.GameResult = LVariant.ResultText(WinFor(OppositeGameSide(LSide)))) and
        (LGame.MoveHistory.Count = 0),
        'flag fall: opponent wins and the late move is not played, got ' + LGame.GameResult);
      // The opponent cannot win: the rules make it a draw.
      LGame.NewGame(LStart + '4');
      LGame.PlayMove('p1', LSide, 1, 'human');
      Check((LGame.GameResult = '1/2-1/2') and
        (Pos('opponent cannot win', LGame.Log.Text) > 0),
        'flag fall without winning chances is a draw, got ' + LGame.GameResult);
      // Engine deadline path.
      LGame.Engine[LSide] := TTimeoutCounterEngine.Create('Timeout');
      LGame.NewGame(LStart + '4');
      LGame.PlayNextMove;
      Check((LGame.State = gosGameOver) and (LGame.GameResult = '1/2-1/2') and
        (Pos('engine move deadline expired; opponent cannot win', LGame.Log.Text) > 0),
        'engine deadline without winning chances is a draw, got ' + LGame.GameResult);
      LGame.NewGame(LStart + '1');
      LGame.PlayNextMove;
      Check(LGame.GameResult = LVariant.ResultText(WinFor(OppositeGameSide(LSide))),
        'engine deadline: opponent wins, got ' + LGame.GameResult);
      LGame.Engine[LSide] := nil;
    end;
  finally
    LGame.Free;
    LVariant.Free;
  end;
end;

procedure CheckRunnerOnInjectedVariant;
var
  LVariant: TCounterVariant;
  LSetup: TGameSetup;
  LRunner: TGameRunnerThread;
  LObserver: TRunnerObserver;
  LDone: Boolean;
begin
  LVariant := TCounterVariant.Create;
  LObserver := TRunnerObserver.Create;
  LSetup := Default(TGameSetup);
  LSetup.StartingFEN := 'W:0';
  LSetup.WhitePlayer := pkHuman;
  LSetup.BlackPlayer := pkHuman;
  LSetup.TimeControl := DefaultTimeControl;
  LRunner := TGameRunnerThread.Create(LSetup, 1, @LObserver.Snapshot, nil, LVariant);
  try
    LRunner.Start;
    LRunner.PostHumanMove('p1');
    LRunner.PostHumanMove('32-28'); // not a counter move: rejected
    LRunner.PostHumanMove('two');
    LRunner.PostHumanMove('+2');
    LDone := LObserver.Finished.WaitFor(5000) = wrSignaled;
    if not LDone then
      LRunner.PostStop;
    LRunner.WaitFor;
    LObserver.Lock.Acquire;
    try
      Check(LDone and (LObserver.State = gosGameOver), 'counter game finishes in the runner');
      Check((LObserver.MovesText = '+1 +2 +2') and (LObserver.ResultText = '1-0'),
        'runner plays canonical counter moves to the counter result, got ' +
        LObserver.MovesText + ' ' + LObserver.ResultText);
      Check(LObserver.PositionIsCounter and (LObserver.PositionFEN = 'B:5'),
        'runner snapshots carry the counter position, got ' + LObserver.PositionFEN);
    finally
      LObserver.Lock.Release;
    end;
  finally
    LRunner.Free;
    LObserver.Free;
    LVariant.Free;
  end;
end;

{ The displayed position reports the move that led to it (board highlights):
  the node's move, or the canonical last preview move. }
procedure CheckDisplayedMoveOnInjectedVariant;
var
  LVariant: TCounterVariant;
  LTree: TGameTree;
  LActor: TGameTreeActor;
  LDisplay: TDisplayedPosition;
  LPosition: TGamePosition;
  LError, LMove: string;
  LNodeId: Int64;
begin
  LVariant := TCounterVariant.Create;
  LTree := TGameTree.Create(LVariant);
  LActor := TGameTreeActor.Create(LTree, False);
  LDisplay := TDisplayedPosition.Create;
  LPosition := LVariant.CreatePosition;
  try
    Check(LDisplay.TryBuildPosition(LTree, True, LActor.Revision, LPosition, LMove) and
      (LMove = ''), 'no move leads to the start position, got "' + LMove + '"');
    Check(Execute(LActor, LActor.CreateAppendMainlineMoveCommand('p2', gmsHuman), LError, LNodeId),
      'append: ' + LError);
    Check(LDisplay.TryBuildPosition(LTree, True, LActor.Revision, LPosition, LMove) and
      (LMove = '+2'), 'the displayed node''s move, got "' + LMove + '"');
    Check(LDisplay.SelectPreview(1, 2, 'one two', LTree), 'select a preview');
    Check(LDisplay.TryBuildPosition(LTree, True, LActor.Revision, LPosition, LMove) and
      (LMove = '+2') and (LPosition.ToFEN = 'B:5'),
      'the canonical last preview move, got "' + LMove + '" at ' + LPosition.ToFEN);
    Check(LDisplay.SelectPreview(1, 1, 'one two', LTree), 'select a shorter preview');
    Check(LDisplay.TryBuildPosition(LTree, True, LActor.Revision, LPosition, LMove) and
      (LMove = '+1'), 'the first preview move in canonical form, got "' + LMove + '"');
    Check(LDisplay.SelectPreview(1, 1, '32-28', LTree), 'select an invalid preview');
    Check(not LDisplay.TryBuildPosition(LTree, True, LActor.Revision, LPosition, LMove) and
      (LMove = ''), 'no move for a position that cannot be built');
  finally
    LPosition.Free;
    LDisplay.Free;
    LActor.Free;
    LTree.Free;
    LVariant.Free;
  end;
end;

begin
  CheckRootSideFollowsVariant;
  CheckActorOnInjectedVariant;
  CheckCompletedMovesWithEquivalentSpellings;
  CheckNotationOnInjectedVariant;
  CheckAnalysisOnInjectedVariant;
  CheckOrchestratorOnInjectedVariant;
  CheckRunnerOnInjectedVariant;
  CheckDisplayedMoveOnInjectedVariant;
  CheckMoveNumbering;
  CheckTimeoutOutcome;
  if Failures > 0 then
  begin
    WriteLn(Failures, ' game tree variant checks failed');
    Halt(1);
  end;
  WriteLn('Game tree variant checks passed');
end.
