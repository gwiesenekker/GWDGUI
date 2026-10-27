unit uMoveInteraction;
{$mode objfpc}{$H+}
{ Board-click interaction and highlight calculation, game-neutral: moves are
  canonical strings and squares come from the game (uGamePosition). }
interface
uses Classes, SysUtils, uGamePosition, uGameTree;
type
  TMoveHighlights = record
    LastMoveTargetSquare, PvSourceSquare, PvTargetSquare,
      HintSourceSquare, HintTargetSquare: Integer;
  end;
  TMoveTargetSquares = array of Integer;
  TMoveRoute = (mrInvalid, mrNone, mrMainline, mrVariation, mrRunner);
  // Temporary click state only. Persistent selection remains the tree cursor.
  TMoveInteraction = class
  private
    FChoices: TStringList;
    FChoiceTargets: array of Integer; // target square of FChoices[I]
    FSourceSquare: Integer;
    FTargets: TMoveTargetSquares;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    // Collects the legal moves from ASourceSquare. Returns the move when there
    // is exactly one; otherwise remembers the source and its distinct targets.
    function SelectSource(APosition: TGamePosition; ASourceSquare: Integer): string;
    procedure TargetChoices(ATargetSquare: Integer; AMoves: TStrings);
    function FindTarget(ATargetSquare: Integer; out AMove: string): Boolean;
    property SourceSquare: Integer read FSourceSquare;
    property Targets: TMoveTargetSquares read FTargets;
  end;
// ADisplayedMove: the move that led to the displayed position ('' at the start).
// APvText: whitespace-separated moves from the displayed position.
function CalculateMoveHighlights(AVariant: TGameVariant; const ADisplayedMove,
  APvText: string; APvMatchesPosition: Boolean): TMoveHighlights;
// Routes a move text played on the displayed position. ACanonicalMove is the
// canonical form when the move is legal there, '' otherwise.
function RouteMove(APosition: TGamePosition; ATree: TGameTree;
  ANode: TGameTreePlyNode; const AMove: string; ACanExplore, ABrowsingBranch,
  AUnfinished, ARunnerHumanTurn: Boolean; out ACanonicalMove: string): TMoveRoute;
implementation
uses uGameTreeBuilder;

function CalculateMoveHighlights(AVariant: TGameVariant; const ADisplayedMove,
  APvText: string; APvMatchesPosition: Boolean): TMoveHighlights;
var PvMoves: TStringList; Source: Integer;
begin
  Result := Default(TMoveHighlights);
  if AVariant = nil then Exit;
  if Trim(ADisplayedMove) <> '' then
    AVariant.MoveSquares(Trim(ADisplayedMove), Source, Result.LastMoveTargetSquare);
  if not APvMatchesPosition then Exit;
  PvMoves := TStringList.Create;
  try
    TextToMoveList(APvText, PvMoves);
    if PvMoves.Count > 0 then
      AVariant.MoveSquares(PvMoves[0], Result.PvSourceSquare, Result.PvTargetSquare);
    if PvMoves.Count > 1 then
      AVariant.MoveSquares(PvMoves[1], Result.HintSourceSquare, Result.HintTargetSquare);
  finally PvMoves.Free; end;
end;

constructor TMoveInteraction.Create;
begin
  inherited Create;
  FChoices := TStringList.Create;
end;
destructor TMoveInteraction.Destroy;
begin
  FChoices.Free;
  inherited Destroy;
end;
procedure TMoveInteraction.Clear;
begin
  FSourceSquare := 0;
  FChoices.Clear;
  FChoiceTargets := nil;
  FTargets := nil;
end;
function TMoveInteraction.SelectSource(APosition: TGamePosition;
  ASourceSquare: Integer): string;
var I, J, From, Target: Integer; Known: Boolean;
begin
  Clear;
  Result := '';
  if APosition = nil then Exit;
  APosition.MovesFrom(ASourceSquare, FChoices);
  SetLength(FChoiceTargets, FChoices.Count);
  for I := 0 to FChoices.Count - 1 do
    APosition.MoveSquares(FChoices[I], From, FChoiceTargets[I]);
  if FChoices.Count = 0 then Exit;
  if FChoices.Count = 1 then Exit(FChoices[0]);
  FSourceSquare := ASourceSquare;
  for I := 0 to FChoices.Count - 1 do
  begin
    Target := FChoiceTargets[I];
    Known := False;
    for J := 0 to High(FTargets) do
      if FTargets[J] = Target then begin Known := True; Break; end;
    if (Target > 0) and not Known then
    begin
      SetLength(FTargets, Length(FTargets) + 1);
      FTargets[High(FTargets)] := Target;
    end;
  end;
end;
procedure TMoveInteraction.TargetChoices(ATargetSquare: Integer; AMoves: TStrings);
var I: Integer;
begin
  AMoves.Clear;
  for I := 0 to FChoices.Count - 1 do
    if FChoiceTargets[I] = ATargetSquare then AMoves.Add(FChoices[I]);
end;
function TMoveInteraction.FindTarget(ATargetSquare: Integer;
  out AMove: string): Boolean;
var Choices: TStringList;
begin
  AMove := '';
  Choices := TStringList.Create;
  try
    TargetChoices(ATargetSquare, Choices);
    Result := Choices.Count = 1;
    if Result then AMove := Choices[0];
  finally Choices.Free; end;
end;
function RouteMove(APosition: TGamePosition; ATree: TGameTree;
  ANode: TGameTreePlyNode; const AMove: string; ACanExplore, ABrowsingBranch,
  AUnfinished, ARunnerHumanTurn: Boolean; out ACanonicalMove: string): TMoveRoute;
var Tip: TGameTreePlyNode;
begin
  ACanonicalMove := '';
  Result := mrInvalid;
  if (ATree = nil) or (APosition = nil) then Exit;
  if not APosition.TryParseMove(AMove, ACanonicalMove) then
  begin
    ACanonicalMove := '';
    Exit;
  end;
  if ACanExplore then
  begin
    Tip := ATree.Root;
    if ATree.MainlineCount > 0 then Tip := ATree.MainlineNode[ATree.MainlineCount];
    if not ABrowsingBranch and (ANode = Tip) and AUnfinished then
      Exit(mrMainline);
    Exit(mrVariation);
  end;
  if ARunnerHumanTurn then Exit(mrRunner);
  Result := mrNone;
end;
end.
