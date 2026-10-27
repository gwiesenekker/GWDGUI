unit uDraughtsPosition;

{$mode objfpc}{$H+}

{ International draughts implementation of the uGamePosition boundary.

  A thin adapter over TDraughtsBoard: rules, move generation and notation stay
  in uDraughtsBoard. Draughts-specific code (board control, Hub/DXP engines,
  PDN) may reach the wrapped board through the Board property; generic units
  must not. }

interface

uses
  Classes, SysUtils, uGamePosition, uDraughtsBoard, uGameTree;

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
  end;

  TDraughtsVariant = class(TGameVariant)
  public
    function Name: string; override;
    function DefaultStartingFEN: string; override;
    function SideFromFEN(const AFEN: string): TGameSide; override;
    function CreatePosition: TGamePosition; override;
    function CreatePositionFromFEN(const AFEN: string): TGamePosition; override;
    function SameMove(const A, B: string): Boolean; override;
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
