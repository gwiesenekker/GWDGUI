unit uGamePosition;

{$mode objfpc}{$H+}

{ Game-neutral position boundary.

  Generic units (game tree, actor, displayed position, notation walker,
  analysis coordination, running games) talk to a game only through these
  classes. A concrete game supplies one TGameVariant and one TGamePosition
  descendant. See claude/position-interface-proposal.md.

  Move contract:
  - A move is a canonical string produced by the implementation (LegalMove,
    TryParseMove). Canonical moves contain no whitespace.
  - Only the implementation parses or compares move text. Generic code uses
    TryParseMove for external spellings and SameMove for equality.
  - MoveNotation is evaluated in the position BEFORE the move. }

interface

uses
  Classes, SysUtils;

type
  TGameSide = (gsWhite, gsBlack);

  EGamePositionError = class(Exception);

  TGamePosition = class
  public
    { Setup and copying }
    // Raises EConvertError for invalid text; the position is unchanged then.
    procedure LoadFromFEN(const AText: string); virtual; abstract;
    function ToFEN: string; virtual; abstract;
    // ASource must be of the same concrete class.
    procedure AssignFrom(ASource: TGamePosition); virtual; abstract;
    function Clone: TGamePosition; virtual; abstract;
    function SideToMove: TGameSide; virtual; abstract;
    // Repetition identity, also used for position lookup (PV caches, databases):
    // placement, side to move and every state that changes the legal moves
    // (chess: castling rights; en passant only when an en passant capture is
    // legal). Move counters are not part of it; ToFEN carries the complete
    // state. Equal keys therefore do not imply equal FEN text (review R10).
    function PositionKey: string; virtual; abstract;

    { Moves (canonical text only) }
    function LegalMoveCount: Integer; virtual; abstract;
    // Stable order for a given position.
    function LegalMove(AIndex: Integer): string; virtual; abstract;
    function IsLegal(const ACanonical: string): Boolean; virtual; abstract;
    // Accepts every spelling users, files and engines use. Returns False when
    // the text is not a legal move here or is ambiguous.
    function TryParseMove(const AText: string; out ACanonical: string): Boolean;
      virtual; abstract;
    function SameMove(const A, B: string): Boolean; virtual; abstract;
    // Validated. Raises EGamePositionError for an illegal move; the position is
    // unchanged then.
    procedure PlayMove(const ACanonical: string); virtual; abstract;
    // For replaying moves that were validated before (tree moves). May skip
    // validation and defer legal-move generation.
    procedure PlayTrustedMove(const ACanonical: string); virtual; abstract;
    // Validated play of any accepted spelling (TryParseMove). Returns the
    // canonical move; raises EGamePositionError with the game's message when
    // the text is not a legal move here, leaving the position unchanged.
    function PlayMoveText(const AText: string): string; virtual;

    { Presentation }
    // Short record notation of a legal move in this position (PDN short form,
    // SAN). Unique among the legal moves of this position.
    function MoveNotation(const ACanonical: string): string; virtual; abstract;

    { Board interaction; squares are implementation-defined integers > 0 }
    procedure MoveSquares(const ACanonical: string; out AFrom, ATo: Integer);
      virtual; abstract;
    // All legal moves with this from/to pair (same-target captures, promotion).
    procedure MovesBetween(AFrom, ATo: Integer; AMoves: TStrings); virtual;
    // All legal moves starting on AFrom.
    procedure MovesFrom(AFrom: Integer; AMoves: TStrings); virtual;

    { Conveniences built on the abstract members }
    procedure CopyLegalMovesTo(AMoves: TStrings);
    function TryPlayMoveText(const AText: string): Boolean;
  end;

  TGamePositionClass = class of TGamePosition;

  TGameOutcome = (goOngoing, goWhiteWins, goBlackWins, goDraw);

  { End-of-game rules that depend on the game history (repetition, progress
    counters, endgame limits) as well as the position. One instance follows one
    game: Reset at its start, MovePlayed after every move.

    Draw policy (review R9): Outcome reports a draw as soon as either side may
    claim one (chess: threefold repetition, 50-move rule) as well as for
    automatic draws (fivefold repetition, 75-move rule), with checkmate taking
    precedence. Every available claim is treated as made at once, as is usual
    in engine games; the GUI has no claim command.

    The orchestrator keeps the clocks; when a side's time runs out it asks
    TimeoutOutcome for the result (review M9). }
  TGameRules = class
  public
    procedure Reset(AStart: TGamePosition); virtual; abstract;
    // ABefore: the position before AMove (canonical); AAfter: after it.
    procedure MovePlayed(ABefore: TGamePosition; const AMove: string;
      AAfter: TGamePosition); virtual; abstract;
    // The outcome in APosition, the current position of the followed game.
    // AReason is a short log text when the game is over.
    function Outcome(APosition: TGamePosition; out AReason: string): TGameOutcome;
      virtual; abstract;
    // The result when AExpired's time has run out in APosition (AExpired is to
    // move; a move made after the time ran out is not played). AReason
    // describes the clock event and is extended by the game when needed. The
    // default is a win for the opponent; chess draws when the opponent cannot
    // mate by any legal sequence (FIDE Article 6.9).
    function TimeoutOutcome(APosition: TGamePosition; AExpired: TGameSide;
      var AReason: string): TGameOutcome; virtual;
  end;

  TGameVariant = class
  public
    function Name: string; virtual; abstract;
    function DefaultStartingFEN: string; virtual; abstract;
    // Side to move from FEN text without full validation (tree headers).
    function SideFromFEN(const AFEN: string): TGameSide; virtual; abstract;
    // The number of the first move after AFEN (chess: the FEN fullmove
    // number), without full validation. Default 1 (draughts FEN has none).
    function StartingMoveNumberFromFEN(const AFEN: string): Integer; virtual;
    function CreatePosition: TGamePosition; virtual; abstract;
    // A position loaded from AFEN, or from DefaultStartingFEN when AFEN is
    // empty. Raises EConvertError for invalid text.
    function CreatePositionFromFEN(const AFEN: string): TGamePosition; virtual;
    // Equality of move texts, independent of a position (canonical moves and
    // the game's equivalent spellings). Generic code never compares move text
    // itself.
    function SameMove(const A, B: string): Boolean; virtual; abstract;
    // Squares of a move from its text alone, for highlighting moves that lie
    // several plies away from any built position (PV hints). Returns 0, 0 when
    // the text does not determine the squares; for a legal move the result
    // agrees with TGamePosition.MoveSquares in that move's position.
    procedure MoveSquares(const AMove: string; out AFrom, ATo: Integer); virtual; abstract;
    // The game's standard spelling of move text without a position (draughts:
    // no leading zeros, one separator). Canonical moves are returned unchanged;
    // text that is not move-like is returned trimmed. Used for analysis text
    // (engine PVs) that is stored or compared without replaying it.
    function NormalizeMove(const AMove: string): string; virtual; abstract;
    // A new rules object for one game; the caller owns it.
    function CreateRules: TGameRules; virtual; abstract;
    // The game's result text for an outcome ('*' for goOngoing), as written in
    // records and logs (draughts: 2-0, 0-2, 1-1).
    function ResultText(AOutcome: TGameOutcome): string; virtual; abstract;
  end;

function OppositeGameSide(ASide: TGameSide): TGameSide;
// 'white' or 'black' (log texts).
function GameSideName(ASide: TGameSide): string;
// The outcome in which ASide wins.
function WinFor(ASide: TGameSide): TGameOutcome;
// The move number of ply APly (1 = the first move after the start position),
// for a start with AStartSide to move and AStartNumber as its move number.
// The one place that numbers moves (review G10).
function GameMoveNumberForPly(AStartSide: TGameSide; AStartNumber,
  APly: Integer): Integer;
// The side that makes ply APly (1 = the first move).
function GameSideForPly(AStartSide: TGameSide; APly: Integer): TGameSide;

{ Copies ASource into ATarget. ATarget is created (Clone) when it is nil or of
  another class, so holders of a position need not know the game in advance.
  ASource = nil leaves ATarget unchanged. }
procedure AssignGamePosition(var ATarget: TGamePosition; ASource: TGamePosition);

{ The variant used when a generic object is created without one. A game unit
  registers itself in its initialization section, so a program selects its
  game by linking that unit (for draughts, the draughts position unit). }
procedure RegisterDefaultGameVariant(AVariant: TGameVariant);
function DefaultGameVariant: TGameVariant;

implementation

var
  GDefaultVariant: TGameVariant = nil;

procedure RegisterDefaultGameVariant(AVariant: TGameVariant);
begin
  GDefaultVariant := AVariant;
end;

function DefaultGameVariant: TGameVariant;
begin
  if GDefaultVariant = nil then
    raise EGamePositionError.Create('No game variant is registered; link a game ' +
      'position unit into the program');
  Result := GDefaultVariant;
end;

function OppositeGameSide(ASide: TGameSide): TGameSide;
begin
  if ASide = gsWhite then
    Result := gsBlack
  else
    Result := gsWhite;
end;

function GameSideName(ASide: TGameSide): string;
begin
  if ASide = gsWhite then
    Result := 'white'
  else
    Result := 'black';
end;

function WinFor(ASide: TGameSide): TGameOutcome;
begin
  if ASide = gsWhite then
    Result := goWhiteWins
  else
    Result := goBlackWins;
end;

function GameMoveNumberForPly(AStartSide: TGameSide; AStartNumber,
  APly: Integer): Integer;
begin
  if AStartNumber < 1 then
    AStartNumber := 1;
  if APly < 1 then
    Exit(AStartNumber);
  Result := AStartNumber + (APly - 1 + Ord(AStartSide = gsBlack)) div 2;
end;

function GameSideForPly(AStartSide: TGameSide; APly: Integer): TGameSide;
begin
  if Odd(APly) then
    Result := AStartSide
  else
    Result := OppositeGameSide(AStartSide);
end;

procedure AssignGamePosition(var ATarget: TGamePosition; ASource: TGamePosition);
begin
  if ASource = nil then
    Exit;
  if (ATarget <> nil) and (ATarget.ClassType = ASource.ClassType) then
    ATarget.AssignFrom(ASource)
  else
  begin
    FreeAndNil(ATarget);
    ATarget := ASource.Clone;
  end;
end;

procedure TGamePosition.MovesBetween(AFrom, ATo: Integer; AMoves: TStrings);
var
  I, LFrom, LTo: Integer;
  LMove: string;
begin
  AMoves.Clear;
  for I := 0 to LegalMoveCount - 1 do
  begin
    LMove := LegalMove(I);
    MoveSquares(LMove, LFrom, LTo);
    if (LFrom = AFrom) and (LTo = ATo) then
      AMoves.Add(LMove);
  end;
end;

procedure TGamePosition.MovesFrom(AFrom: Integer; AMoves: TStrings);
var
  I, LFrom, LTo: Integer;
  LMove: string;
begin
  AMoves.Clear;
  for I := 0 to LegalMoveCount - 1 do
  begin
    LMove := LegalMove(I);
    MoveSquares(LMove, LFrom, LTo);
    if LFrom = AFrom then
      AMoves.Add(LMove);
  end;
end;

procedure TGamePosition.CopyLegalMovesTo(AMoves: TStrings);
var
  I: Integer;
begin
  AMoves.Clear;
  for I := 0 to LegalMoveCount - 1 do
    AMoves.Add(LegalMove(I));
end;

function TGamePosition.PlayMoveText(const AText: string): string;
begin
  if not TryParseMove(AText, Result) then
    raise EGamePositionError.Create('Illegal move: ' + Trim(AText));
  PlayMove(Result);
end;

function TGamePosition.TryPlayMoveText(const AText: string): Boolean;
var
  LMove: string;
begin
  Result := TryParseMove(AText, LMove);
  if Result then
    PlayMove(LMove);
end;

function TGameRules.TimeoutOutcome(APosition: TGamePosition; AExpired: TGameSide;
  var AReason: string): TGameOutcome;
begin
  Result := WinFor(OppositeGameSide(AExpired));
end;

function TGameVariant.StartingMoveNumberFromFEN(const AFEN: string): Integer;
begin
  Result := 1;
end;

function TGameVariant.CreatePositionFromFEN(const AFEN: string): TGamePosition;
begin
  Result := CreatePosition;
  try
    if Trim(AFEN) = '' then
      Result.LoadFromFEN(DefaultStartingFEN)
    else
      Result.LoadFromFEN(AFEN);
  except
    Result.Free;
    raise;
  end;
end;

end.
