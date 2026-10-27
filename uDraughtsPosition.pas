unit uDraughtsPosition;

{$mode objfpc}{$H+}

{ International draughts implementation of the uGamePosition boundary.

  A thin adapter over TDraughtsBoard: rules, move generation and notation stay
  in uDraughtsBoard. Draughts-specific code (board control, Hub/DXP engines,
  PDN) may reach the wrapped board through the Board property; generic units
  must not. }

interface

uses
  Classes, SysUtils, uGamePosition, uDraughtsBoard, uDraughtsDrawRules, uGameTree,
  uDisplayedPosition;

type
  TDraughtsPosition = class(TGamePosition)
  private
    FBoard: TDraughtsBoard;
    FLegalMovesStale: Boolean;
    procedure EnsureLegalMoves;
    function GetBoard: TDraughtsBoard;
  public
    constructor Create;
    destructor Destroy; override;

    procedure LoadFromFEN(const AText: string); override;
    function ToFEN: string; override;
    procedure AssignFrom(ASource: TGamePosition); override;
    function Clone: TGamePosition; override;
    function SideToMove: TGameSide; override;
    function PositionKey: string; override;

    function LegalMoveCount: Integer; override;
    function LegalMove(AIndex: Integer): string; override;
    function IsLegal(const ACanonical: string): Boolean; override;
    function TryParseMove(const AText: string; out ACanonical: string): Boolean;
      override;
    function SameMove(const A, B: string): Boolean; override;
    procedure PlayMove(const ACanonical: string); override;
    procedure PlayTrustedMove(const ACanonical: string); override;
    function PlayMoveText(const AText: string): string; override;

    function MoveNotation(const ACanonical: string): string; override;
    procedure MoveSquares(const ACanonical: string; out AFrom, ATo: Integer);
      override;

    // Draughts-specific access for draughts-only units. Legal moves are
    // brought up to date before the board is returned.
    property Board: TDraughtsBoard read GetBoard;
    // Copies a draughts board (with its played-move history and legal moves)
    // for draughts-only units that still hold boards.
    procedure AssignBoard(ABoard: TDraughtsBoard);
  end;

  TDraughtsVariant = class(TGameVariant)
  public
    function Name: string; override;
    function DefaultStartingFEN: string; override;
    function SideFromFEN(const AFEN: string): TGameSide; override;
    function CreatePosition: TGamePosition; override;
    function CreatePositionFromFEN(const AFEN: string): TGamePosition; override;
    function SameMove(const A, B: string): Boolean; override;
    procedure MoveSquares(const AMove: string; out AFrom, ATo: Integer); override;
    function NormalizeMove(const AMove: string): string; override;
    function CreateRules: TGameRules; override;
    function ResultText(AOutcome: TGameOutcome): string; override;
  end;

  { FMJD end-of-game rules: no legal move loses; draws by the 16/5-move endgame
    limits, threefold repetition and 25 moves of kings only (reversible moves).
    Positions must be TDraughtsPosition. }
  TDraughtsRules = class(TGameRules)
  private
    FPositionHistory: TStringList;
    FConsecutiveReversiblePlyCount: Integer;
    FEndgameDrawCounter: TEndgameDrawCounter;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Reset(AStart: TGamePosition); override;
    procedure MovePlayed(ABefore: TGamePosition; const AMove: string;
      AAfter: TGamePosition); override;
    function Outcome(APosition: TGamePosition; out AReason: string): TGameOutcome;
      override;
  end;

// Shared variant instance; owned by this unit.
function DraughtsVariant: TDraughtsVariant;

function DraughtsSideToGameSide(ASide: TDraughtsSide): TGameSide;
function GameSideToDraughtsSide(ASide: TGameSide): TDraughtsSide;

{ Migration helper for units that still work on TDraughtsBoard: replays the
  tree's validated moves (TGameTree.TryBuildPositionAtNode) into ABoard,
  including the played-move history. ABoard is unchanged on failure. }
function TryBuildDraughtsBoardAtNode(ATree: TGameTree; ANode: TGameTreePlyNode;
  ABoard: TDraughtsBoard): Boolean;

{ Migration helpers for units that still hold TDraughtsBoard values (main form,
  analysis coordination): the TDisplayedPosition replays, copied into ABoard
  with its played-move history. ABoard is unchanged on failure. }
// AScratch: an optional caller-owned position reused across calls, so frequent
// callers do not set up a new start position each time; nil uses a temporary.
function TryBuildDraughtsNodeBoard(ADisplay: TDisplayedPosition; ATree: TGameTree;
  ANode: TGameTreePlyNode; ARevision: Int64; ABoard: TDraughtsBoard;
  AScratch: TDraughtsPosition = nil): Boolean;
function TryBuildDraughtsDisplayedBoard(ADisplay: TDisplayedPosition;
  ATree: TGameTree; AActive: Boolean; ARevision: Int64; ABoard: TDraughtsBoard;
  AScratch: TDraughtsPosition = nil): Boolean;

// The ASquareIndex-th square number in draughts move text (1 = from, 2 = to).
function MoveSquareAt(const AMove: string; ASquareIndex: Integer): Integer;

implementation

var
  GDraughtsVariant: TDraughtsVariant = nil;

function DraughtsVariant: TDraughtsVariant;
begin
  if GDraughtsVariant = nil then
    GDraughtsVariant := TDraughtsVariant.Create;
  Result := GDraughtsVariant;
end;

function DraughtsSideToGameSide(ASide: TDraughtsSide): TGameSide;
begin
  if ASide = dsWhite then
    Result := gsWhite
  else
    Result := gsBlack;
end;

function GameSideToDraughtsSide(ASide: TGameSide): TDraughtsSide;
begin
  if ASide = gsWhite then
    Result := dsWhite
  else
    Result := dsBlack;
end;

function TryBuildDraughtsBoardAtNode(ATree: TGameTree; ANode: TGameTreePlyNode;
  ABoard: TDraughtsBoard): Boolean;
var
  LPosition: TDraughtsPosition;
begin
  Result := False;
  if (ATree = nil) or (ABoard = nil) then
    Exit;
  LPosition := TDraughtsPosition.Create;
  try
    Result := ATree.TryBuildPositionAtNode(ANode, LPosition);
    if Result then
      ABoard.AssignFrom(LPosition.Board);
  finally
    LPosition.Free;
  end;
end;

function TryBuildDraughtsNodeBoard(ADisplay: TDisplayedPosition; ATree: TGameTree;
  ANode: TGameTreePlyNode; ARevision: Int64; ABoard: TDraughtsBoard;
  AScratch: TDraughtsPosition): Boolean;
var
  LPosition: TDraughtsPosition;
begin
  Result := False;
  if (ADisplay = nil) or (ABoard = nil) then
    Exit;
  LPosition := AScratch;
  if LPosition = nil then
    LPosition := TDraughtsPosition.Create;
  try
    Result := ADisplay.TryBuildNodePosition(ATree, ANode, ARevision, LPosition);
    if Result then
      ABoard.AssignFrom(LPosition.Board);
  finally
    if LPosition <> AScratch then
      LPosition.Free;
  end;
end;

function TryBuildDraughtsDisplayedBoard(ADisplay: TDisplayedPosition;
  ATree: TGameTree; AActive: Boolean; ARevision: Int64; ABoard: TDraughtsBoard;
  AScratch: TDraughtsPosition): Boolean;
var
  LPosition: TDraughtsPosition;
begin
  Result := False;
  if (ADisplay = nil) or (ABoard = nil) then
    Exit;
  LPosition := AScratch;
  if LPosition = nil then
    LPosition := TDraughtsPosition.Create;
  try
    Result := ADisplay.TryBuildPosition(ATree, AActive, ARevision, LPosition);
    if Result then
      ABoard.AssignFrom(LPosition.Board);
  finally
    if LPosition <> AScratch then
      LPosition.Free;
  end;
end;

function MoveSquareAt(const AMove: string; ASquareIndex: Integer): Integer;
var
  I: Integer;
  LCount: Integer;
  LNumberText: string;
begin
  Result := 0;
  LCount := 0;
  LNumberText := '';
  for I := 1 to Length(AMove) do
  begin
    if AMove[I] in ['0'..'9'] then
      LNumberText += AMove[I]
    else if LNumberText <> '' then
    begin
      Inc(LCount);
      if LCount = ASquareIndex then
        Exit(StrToIntDef(LNumberText, 0));
      LNumberText := '';
    end;
  end;
  if LNumberText <> '' then
  begin
    Inc(LCount);
    if LCount = ASquareIndex then
      Result := StrToIntDef(LNumberText, 0);
  end;
end;

{ Square numbers of a canonical draughts move: from, to, then captured squares. }
procedure CanonicalSquares(const AMove: string; out AFrom, ATo: Integer);
var
  I, LIndex: Integer;
  LNumber: string;

  procedure Flush;
  begin
    if LNumber = '' then
      Exit;
    Inc(LIndex);
    if LIndex = 1 then
      AFrom := StrToIntDef(LNumber, 0)
    else if LIndex = 2 then
      ATo := StrToIntDef(LNumber, 0);
    LNumber := '';
  end;

begin
  AFrom := 0;
  ATo := 0;
  LIndex := 0;
  LNumber := '';
  for I := 1 to Length(AMove) do
    if AMove[I] in ['0'..'9'] then
      LNumber += AMove[I]
    else
      Flush;
  Flush;
end;

{ TDraughtsPosition }

constructor TDraughtsPosition.Create;
begin
  inherited Create;
  FBoard := TDraughtsBoard.Create;
end;

destructor TDraughtsPosition.Destroy;
begin
  FBoard.Free;
  inherited Destroy;
end;

procedure TDraughtsPosition.EnsureLegalMoves;
begin
  if not FLegalMovesStale then
    Exit;
  FBoard.GenerateLegalMoves;
  FLegalMovesStale := False;
end;

function TDraughtsPosition.GetBoard: TDraughtsBoard;
begin
  EnsureLegalMoves;
  Result := FBoard;
end;

procedure TDraughtsPosition.LoadFromFEN(const AText: string);
begin
  // TDraughtsBoard.LoadFromFEN parses into a local board and raises
  // EConvertError before changing anything.
  FBoard.LoadFromFEN(AText);
  FLegalMovesStale := False;
end;

function TDraughtsPosition.ToFEN: string;
begin
  Result := FBoard.CurrentFEN;
end;

procedure TDraughtsPosition.AssignFrom(ASource: TGamePosition);
begin
  if not (ASource is TDraughtsPosition) then
    raise EGamePositionError.Create('Cannot assign ' + ASource.ClassName +
      ' to a draughts position');
  FBoard.AssignFrom(TDraughtsPosition(ASource).FBoard);
  FLegalMovesStale := TDraughtsPosition(ASource).FLegalMovesStale;
end;

procedure TDraughtsPosition.AssignBoard(ABoard: TDraughtsBoard);
begin
  if ABoard = nil then
    Exit;
  FBoard.AssignFrom(ABoard);
  FLegalMovesStale := False;
end;

function TDraughtsPosition.Clone: TGamePosition;
begin
  Result := TDraughtsPosition.Create;
  Result.AssignFrom(Self);
end;

function TDraughtsPosition.SideToMove: TGameSide;
begin
  Result := DraughtsSideToGameSide(FBoard.SideToMove);
end;

function TDraughtsPosition.PositionKey: string;
begin
  Result := FBoard.PositionKey;
end;

function TDraughtsPosition.LegalMoveCount: Integer;
begin
  EnsureLegalMoves;
  Result := FBoard.LegalMoveCount;
end;

function TDraughtsPosition.LegalMove(AIndex: Integer): string;
begin
  EnsureLegalMoves;
  Result := FBoard.LegalMoves[AIndex];
end;

function TDraughtsPosition.IsLegal(const ACanonical: string): Boolean;
var
  LMove: string;
begin
  EnsureLegalMoves;
  Result := FBoard.TryGetLegalMove(ACanonical, LMove) and SameMove(LMove, ACanonical);
end;

function TDraughtsPosition.TryParseMove(const AText: string;
  out ACanonical: string): Boolean;
begin
  ACanonical := '';
  if Trim(AText) = '' then
    Exit(False);
  EnsureLegalMoves;
  Result := FBoard.TryGetLegalMove(AText, ACanonical);
end;

function SameDraughtsMove(const A, B: string): Boolean;
var
  LA, LB: string;
begin
  LA := NormalizeMoveNotation(A);
  LB := NormalizeMoveNotation(B);
  Result := SameText(LA, LB) or SameMoveIgnoringCaptureOrder(LA, LB);
end;

function TDraughtsPosition.SameMove(const A, B: string): Boolean;
begin
  Result := SameDraughtsMove(A, B);
end;

procedure TDraughtsPosition.PlayMove(const ACanonical: string);
begin
  PlayMoveText(ACanonical);
end;

function TDraughtsPosition.PlayMoveText(const AText: string): string;
begin
  EnsureLegalMoves;
  // Same validation and messages as TDraughtsBoard.PlayMove; existing import
  // warnings and logs keep their text.
  if not FBoard.TryGetLegalMove(AText, Result) then
    raise EGamePositionError.Create('Illegal move: ' + NormalizeMoveNotation(AText));
  FBoard.PlayMove(Result, True, False, True);
end;

procedure TDraughtsPosition.PlayTrustedMove(const ACanonical: string);
begin
  // The tree stores canonical moves validated on entry (actor boundary), so
  // replay skips validation and defers move generation to the next query.
  FBoard.PlayMove(ACanonical, True, False, False);
  FLegalMovesStale := True;
end;

function TDraughtsPosition.MoveNotation(const ACanonical: string): string;
begin
  // Quiet moves are written as stored; only captures need the legal-move list
  // to choose between the short form and a landing path.
  if Pos('x', ACanonical) = 0 then
    Exit(ACanonical);
  EnsureLegalMoves;
  Result := FBoard.PdnMoveNotation(ACanonical);
end;

procedure TDraughtsPosition.MoveSquares(const ACanonical: string;
  out AFrom, ATo: Integer);
begin
  CanonicalSquares(ACanonical, AFrom, ATo);
end;

{ TDraughtsVariant }

function TDraughtsVariant.Name: string;
begin
  Result := 'International draughts';
end;

function TDraughtsVariant.DefaultStartingFEN: string;
begin
  Result := uDraughtsBoard.DefaultStartingFEN;
end;

function TDraughtsVariant.SideFromFEN(const AFEN: string): TGameSide;
var
  LText: string;
begin
  LText := UpperCase(Trim(AFEN));
  if (LText <> '') and (LText[1] = 'B') then
    Result := gsBlack
  else
    Result := gsWhite;
end;

function TDraughtsVariant.SameMove(const A, B: string): Boolean;
begin
  Result := SameDraughtsMove(A, B);
end;

procedure TDraughtsVariant.MoveSquares(const AMove: string; out AFrom, ATo: Integer);
begin
  CanonicalSquares(AMove, AFrom, ATo);
end;

function TDraughtsVariant.NormalizeMove(const AMove: string): string;
begin
  Result := NormalizeMoveNotation(AMove);
end;

function TDraughtsVariant.CreateRules: TGameRules;
begin
  Result := TDraughtsRules.Create;
end;

function TDraughtsVariant.ResultText(AOutcome: TGameOutcome): string;
begin
  case AOutcome of
    goWhiteWins: Result := '2-0';
    goBlackWins: Result := '0-2';
    goDraw: Result := '1-1';
  else
    Result := '*';
  end;
end;

{ TDraughtsRules }

function RulesBoard(APosition: TGamePosition): TDraughtsBoard;
begin
  if not (APosition is TDraughtsPosition) then
    raise EGamePositionError.Create('Draughts rules need a draughts position');
  Result := TDraughtsPosition(APosition).Board;
end;

constructor TDraughtsRules.Create;
begin
  inherited Create;
  FPositionHistory := TStringList.Create;
end;

destructor TDraughtsRules.Destroy;
begin
  FPositionHistory.Free;
  inherited Destroy;
end;

procedure TDraughtsRules.Reset(AStart: TGamePosition);
begin
  FPositionHistory.Clear;
  FPositionHistory.Add(AStart.PositionKey);
  FConsecutiveReversiblePlyCount := 0;
  FEndgameDrawCounter.Start(RulesBoard(AStart));
end;

procedure TDraughtsRules.MovePlayed(ABefore: TGamePosition; const AMove: string;
  AAfter: TGamePosition);
begin
  if RulesBoard(ABefore).MoveIsReversible(AMove) then
    Inc(FConsecutiveReversiblePlyCount)
  else
    FConsecutiveReversiblePlyCount := 0;
  FEndgameDrawCounter.AfterMove(RulesBoard(AAfter));
  FPositionHistory.Add(AAfter.PositionKey);
end;

function TDraughtsRules.Outcome(APosition: TGamePosition;
  out AReason: string): TGameOutcome;
const
  RepetitionDrawCount = 3;
  TwentyFiveMovesInPlies = 50;
var
  I, LRepetitionCount, LMoveLimit: Integer;
  LKey: string;
begin
  AReason := '';
  // A terminal win takes precedence on the last move allowed by a draw limit.
  if APosition.LegalMoveCount = 0 then
  begin
    if APosition.SideToMove = gsWhite then
    begin
      AReason := 'White has no legal move';
      Exit(goBlackWins);
    end;
    AReason := 'Black has no legal move';
    Exit(goWhiteWins);
  end;
  LMoveLimit := FEndgameDrawCounter.DrawMoveLimit;
  if LMoveLimit <> 0 then
  begin
    AReason := 'draw by ' + IntToStr(LMoveLimit) + '-move endgame rule';
    Exit(goDraw);
  end;
  LRepetitionCount := 0;
  LKey := APosition.PositionKey;
  for I := 0 to FPositionHistory.Count - 1 do
    if FPositionHistory[I] = LKey then
      Inc(LRepetitionCount);
  if LRepetitionCount >= RepetitionDrawCount then
  begin
    AReason := 'draw by repetition; repetitions=' + IntToStr(LRepetitionCount);
    Exit(goDraw);
  end;
  if FConsecutiveReversiblePlyCount >= TwentyFiveMovesInPlies then
  begin
    AReason := 'draw by 25-move rule; reversible_plies=' +
      IntToStr(FConsecutiveReversiblePlyCount);
    Exit(goDraw);
  end;
  Result := goOngoing;
end;

function TDraughtsVariant.CreatePosition: TGamePosition;
begin
  // The board constructor already sets up the standard starting position;
  // load only when a descendant variant defines another default.
  Result := TDraughtsPosition.Create;
  if DefaultStartingFEN <> uDraughtsBoard.DefaultStartingFEN then
    try
      Result.LoadFromFEN(DefaultStartingFEN);
    except
      Result.Free;
      raise;
    end;
end;

function TDraughtsVariant.CreatePositionFromFEN(const AFEN: string): TGamePosition;
var
  LFEN: string;
begin
  // One FEN load per replay, as before the position boundary.
  LFEN := Trim(AFEN);
  if LFEN = '' then
    LFEN := DefaultStartingFEN;
  Result := TDraughtsPosition.Create;
  try
    if LFEN <> uDraughtsBoard.DefaultStartingFEN then
      Result.LoadFromFEN(LFEN);
  except
    Result.Free;
    raise;
  end;
end;

initialization
  RegisterDefaultGameVariant(DraughtsVariant);

finalization
  RegisterDefaultGameVariant(nil);
  FreeAndNil(GDraughtsVariant);

end.
