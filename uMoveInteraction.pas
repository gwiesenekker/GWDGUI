unit uMoveInteraction;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, uDraughtsBoard, uGameTree;
type
  TMoveHighlights = record
    LastMoveTargetSquare, PvSourceSquare, HintSourceSquare: Integer;
  end;
  TMoveTargetSquares = array of Integer;
  TMoveRoute = (mrInvalid, mrNone, mrMainline, mrVariation, mrRunner);
  // Temporary click state only. Persistent selection remains the tree cursor.
  TMoveInteraction = class
  private
    FChoices: TStringList;
    FSourceSquare: Integer;
    FTargets: TMoveTargetSquares;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function SelectSource(ABoard: TDraughtsBoard; ASourceSquare: Integer): string;
    procedure TargetChoices(ATargetSquare: Integer; AMoves: TStrings);
    function FindTarget(ATargetSquare: Integer; out AMove: string): Boolean;
    property SourceSquare: Integer read FSourceSquare;
    property Targets: TMoveTargetSquares read FTargets;
  end;
function CalculateMoveHighlights(const ADisplayedMove, APvText: string; APvMatchesPosition: Boolean): TMoveHighlights;
function MoveSquareAt(const AMove: string; ASquareIndex: Integer): Integer;
function RouteMove(ABoard: TDraughtsBoard; ATree: TGameTree;
  ANode: TGameTreePlyNode; const AMove: string; ACanExplore, ABrowsingBranch,
  AUnfinished, ARunnerHumanTurn: Boolean; out ANormalizedMove: string): TMoveRoute;
implementation
uses uGameTreeBuilder;
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

function CalculateMoveHighlights(const ADisplayedMove, APvText: string; APvMatchesPosition: Boolean): TMoveHighlights;
var PvMoves: TStringList;
begin
  Result.LastMoveTargetSquare := 0;
  Result.PvSourceSquare := 0;
  Result.HintSourceSquare := 0;
  Result.LastMoveTargetSquare := MoveSquareAt(ADisplayedMove, 2);
  if not APvMatchesPosition then Exit;
  PvMoves := TStringList.Create;
  try
    TextToMoveList(APvText, PvMoves);
    if PvMoves.Count > 0 then Result.PvSourceSquare := MoveSquareAt(PvMoves[0], 1);
    if PvMoves.Count > 1 then Result.HintSourceSquare := MoveSquareAt(PvMoves[1], 1);
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
  FTargets := nil;
end;
function TMoveInteraction.SelectSource(ABoard: TDraughtsBoard;
  ASourceSquare: Integer): string;
var I, J, Target: Integer; Move: string; Known: Boolean;
begin
  Clear;
  Result := '';
  if ABoard = nil then Exit;
  for I := 0 to ABoard.LegalMoveCount - 1 do
  begin
    Move := Trim(ABoard.LegalMoves[I]);
    if MoveSquareAt(Move, 1) = ASourceSquare then FChoices.Add(Move);
  end;
  if FChoices.Count = 0 then Exit;
  if FChoices.Count = 1 then Exit(FChoices[0]);
  FSourceSquare := ASourceSquare;
  for I := 0 to FChoices.Count - 1 do
  begin
    Target := MoveSquareAt(FChoices[I], 2);
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
    if MoveSquareAt(FChoices[I], 2) = ATargetSquare then AMoves.Add(FChoices[I]);
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
function RouteMove(ABoard: TDraughtsBoard; ATree: TGameTree;
  ANode: TGameTreePlyNode; const AMove: string; ACanExplore, ABrowsingBranch,
  AUnfinished, ARunnerHumanTurn: Boolean; out ANormalizedMove: string): TMoveRoute;
var Tip: TGameTreePlyNode;
begin
  ANormalizedMove := NormalizeMoveNotation(AMove);
  Result := mrInvalid;
  if (ATree = nil) or (ABoard = nil) then Exit;
  if not ABoard.IsLegalMove(ANormalizedMove) then Exit;
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
