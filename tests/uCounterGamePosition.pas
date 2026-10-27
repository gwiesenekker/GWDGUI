unit uCounterGamePosition;

{$mode objfpc}{$H+}

{ A deliberately tiny second game for tests of the game-neutral units.

  It shares no code or notation with draughts, so a generic unit that still
  assumes draughts (square numbers in move text, draughts FENs, the default
  variant) fails with it.

  - Position: a counter 0..CounterLimit and a side to move. FEN: 'W:3', 'B:0'.
  - Moves: '+1' and '+2' (canonical); the counter may not exceed CounterLimit,
    so the game ends there. Aliases: 'p1', 'p2', and the notation 'one', 'two'.
  - Squares: from = counter + 1, to = counter + step + 1. }

interface

uses
  Classes, SysUtils, uGamePosition;

const
  CounterLimit = 5;

type
  TCounterPosition = class(TGamePosition)
  private
    FCount: Integer;
    FSide: TGameSide;
    function Step(const ACanonical: string): Integer;
  public
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
    function MoveNotation(const ACanonical: string): string; override;
    procedure MoveSquares(const ACanonical: string; out AFrom, ATo: Integer);
      override;
    property Count: Integer read FCount;
  end;

  TCounterVariant = class(TGameVariant)
  public
    function Name: string; override;
    function DefaultStartingFEN: string; override;
    function SideFromFEN(const AFEN: string): TGameSide; override;
    function CreatePosition: TGamePosition; override;
    function SameMove(const A, B: string): Boolean; override;
    // Counter squares depend on the position, not on the move text.
    procedure MoveSquares(const AMove: string; out AFrom, ATo: Integer); override;
  end;

  // Same game, but Black moves first by default (review G9).
  TBlackStartCounterVariant = class(TCounterVariant)
  public
    function DefaultStartingFEN: string; override;
  end;

// Canonical form of any accepted spelling, or '' when the text is not a move.
function CounterCanonicalMove(const AText: string): string;

implementation

function CounterCanonicalMove(const AText: string): string;
var
  LText: string;
begin
  LText := LowerCase(Trim(AText));
  if (LText = '+1') or (LText = 'p1') or (LText = 'one') then
    Result := '+1'
  else if (LText = '+2') or (LText = 'p2') or (LText = 'two') then
    Result := '+2'
  else
    Result := '';
end;

{ TCounterPosition }

function TCounterPosition.Step(const ACanonical: string): Integer;
begin
  if ACanonical = '+1' then
    Result := 1
  else if ACanonical = '+2' then
    Result := 2
  else
    Result := 0;
end;

procedure TCounterPosition.LoadFromFEN(const AText: string);
var
  LText: string;
  LSide: TGameSide;
  LCount: Integer;
begin
  LText := UpperCase(Trim(AText));
  if (Length(LText) < 3) or (LText[2] <> ':') then
    raise EConvertError.Create('Invalid counter FEN: ' + AText);
  case LText[1] of
    'W': LSide := gsWhite;
    'B': LSide := gsBlack;
  else
    raise EConvertError.Create('Invalid counter FEN side: ' + AText);
  end;
  LCount := StrToIntDef(Copy(LText, 3, MaxInt), -1);
  if (LCount < 0) or (LCount > CounterLimit) then
    raise EConvertError.Create('Invalid counter FEN count: ' + AText);
  FSide := LSide;
  FCount := LCount;
end;

function TCounterPosition.ToFEN: string;
begin
  if FSide = gsWhite then
    Result := 'W:'
  else
    Result := 'B:';
  Result += IntToStr(FCount);
end;

procedure TCounterPosition.AssignFrom(ASource: TGamePosition);
begin
  if not (ASource is TCounterPosition) then
    raise EGamePositionError.Create('Cannot assign ' + ASource.ClassName +
      ' to a counter position');
  FCount := TCounterPosition(ASource).FCount;
  FSide := TCounterPosition(ASource).FSide;
end;

function TCounterPosition.Clone: TGamePosition;
begin
  Result := TCounterPosition.Create;
  Result.AssignFrom(Self);
end;

function TCounterPosition.SideToMove: TGameSide;
begin
  Result := FSide;
end;

function TCounterPosition.PositionKey: string;
begin
  Result := 'counter|' + ToFEN;
end;

function TCounterPosition.LegalMoveCount: Integer;
begin
  Result := CounterLimit - FCount;
  if Result > 2 then
    Result := 2;
end;

function TCounterPosition.LegalMove(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= LegalMoveCount) then
    raise ERangeError.Create('Legal move index');
  Result := '+' + IntToStr(AIndex + 1);
end;

function TCounterPosition.IsLegal(const ACanonical: string): Boolean;
var
  LStep: Integer;
begin
  LStep := Step(ACanonical);
  Result := (LStep > 0) and (FCount + LStep <= CounterLimit);
end;

function TCounterPosition.TryParseMove(const AText: string;
  out ACanonical: string): Boolean;
begin
  ACanonical := CounterCanonicalMove(AText);
  Result := (ACanonical <> '') and IsLegal(ACanonical);
  if not Result then
    ACanonical := '';
end;

function TCounterPosition.SameMove(const A, B: string): Boolean;
var
  LA, LB: string;
begin
  LA := CounterCanonicalMove(A);
  LB := CounterCanonicalMove(B);
  Result := (LA <> '') and (LA = LB);
end;

procedure TCounterPosition.PlayMove(const ACanonical: string);
var
  LMove: string;
begin
  if not TryParseMove(ACanonical, LMove) then
    raise EGamePositionError.Create('Illegal counter move: ' + ACanonical);
  PlayTrustedMove(LMove);
end;

procedure TCounterPosition.PlayTrustedMove(const ACanonical: string);
begin
  Inc(FCount, Step(ACanonical));
  FSide := OppositeGameSide(FSide);
end;

function TCounterPosition.MoveNotation(const ACanonical: string): string;
begin
  if ACanonical = '+1' then
    Result := 'one'
  else if ACanonical = '+2' then
    Result := 'two'
  else
    Result := ACanonical;
end;

procedure TCounterPosition.MoveSquares(const ACanonical: string;
  out AFrom, ATo: Integer);
begin
  AFrom := FCount + 1;
  ATo := FCount + Step(ACanonical) + 1;
end;

{ TCounterVariant }

function TCounterVariant.Name: string;
begin
  Result := 'Counter test game';
end;

function TCounterVariant.DefaultStartingFEN: string;
begin
  Result := 'W:0';
end;

function TCounterVariant.SideFromFEN(const AFEN: string): TGameSide;
var
  LText: string;
begin
  LText := UpperCase(Trim(AFEN));
  if (LText <> '') and (LText[1] = 'B') then
    Result := gsBlack
  else
    Result := gsWhite;
end;

function TCounterVariant.CreatePosition: TGamePosition;
begin
  Result := TCounterPosition.Create;
  Result.LoadFromFEN(DefaultStartingFEN);
end;

function TCounterVariant.SameMove(const A, B: string): Boolean;
var
  LA, LB: string;
begin
  LA := CounterCanonicalMove(A);
  LB := CounterCanonicalMove(B);
  Result := (LA <> '') and (LA = LB);
end;

procedure TCounterVariant.MoveSquares(const AMove: string; out AFrom, ATo: Integer);
begin
  AFrom := 0;
  ATo := 0;
end;

{ TBlackStartCounterVariant }

function TBlackStartCounterVariant.DefaultStartingFEN: string;
begin
  Result := 'B:0';
end;

end.
