unit uGameMoveHistory;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uDraughtsBoard;

type
  TGameMove = class
  public
    MoveText: string;
    Side: TDraughtsSide;
    SecondsUsed: Double;
    Annotation: string;
    PrincipalVariation: string;
  end;

  TGameMoveHistory = class
  private
    FItems: TList;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TGameMove;
  public
    constructor Create;
    destructor Destroy; override;
    function AddMove(const AMoveText: string; ASide: TDraughtsSide;
      ASecondsUsed: Double; const AAnnotation: string = '';
      const APrincipalVariation: string = ''): TGameMove;
    procedure AssignFromTexts(const AMovesText, AAnnotationsText: string);
    procedure Clear;
    procedure FillPureMoves(AMoves: TStrings);
    function AnnotationsText: string;
    function MovesText: string;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TGameMove read GetItem; default;
  end;

implementation

constructor TGameMoveHistory.Create;
begin
  inherited Create;
  FItems := TList.Create;
end;

destructor TGameMoveHistory.Destroy;
begin
  Clear;
  FItems.Free;
  inherited Destroy;
end;

function TGameMoveHistory.GetCount: Integer;
begin
  Result := FItems.Count;
end;

function TGameMoveHistory.GetItem(AIndex: Integer): TGameMove;
begin
  if (AIndex < 0) or (AIndex >= FItems.Count) then
    raise ERangeError.CreateFmt('Move history index out of range: %d', [AIndex]);
  Result := TGameMove(FItems[AIndex]);
end;

function TGameMoveHistory.AddMove(const AMoveText: string; ASide: TDraughtsSide;
  ASecondsUsed: Double; const AAnnotation: string;
  const APrincipalVariation: string): TGameMove;
begin
  Result := TGameMove.Create;
  Result.MoveText := NormalizeMoveNotation(AMoveText);
  Result.Side := ASide;
  Result.SecondsUsed := ASecondsUsed;
  Result.Annotation := Trim(AAnnotation);
  Result.PrincipalVariation := Trim(APrincipalVariation);
  FItems.Add(Result);
end;

procedure TGameMoveHistory.AssignFromTexts(const AMovesText,
  AAnnotationsText: string);
var
  I: Integer;
  LAnnotations: TStringList;
  LMoves: TStringList;
  LSide: TDraughtsSide;
begin
  Clear;
  LAnnotations := TStringList.Create;
  LMoves := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)), LMoves);
    LAnnotations.Text := AAnnotationsText;
    LSide := dsWhite;
    for I := 0 to LMoves.Count - 1 do
    begin
      if I < LAnnotations.Count then
        AddMove(LMoves[I], LSide, 0, LAnnotations[I])
      else
        AddMove(LMoves[I], LSide, 0, '');
      LSide := OppositeSide(LSide);
    end;
  finally
    LMoves.Free;
    LAnnotations.Free;
  end;
end;

procedure TGameMoveHistory.Clear;
var
  I: Integer;
begin
  for I := 0 to FItems.Count - 1 do
    TObject(FItems[I]).Free;
  FItems.Clear;
end;

procedure TGameMoveHistory.FillPureMoves(AMoves: TStrings);
var
  I: Integer;
begin
  if AMoves = nil then
    Exit;
  AMoves.Clear;
  for I := 0 to FItems.Count - 1 do
    AMoves.Add(TGameMove(FItems[I]).MoveText);
end;

function TGameMoveHistory.AnnotationsText: string;
var
  I: Integer;
  LAnnotations: TStringList;
begin
  LAnnotations := TStringList.Create;
  try
    for I := 0 to FItems.Count - 1 do
      LAnnotations.Add(TGameMove(FItems[I]).Annotation);
    Result := LAnnotations.Text;
  finally
    LAnnotations.Free;
  end;
end;

function TGameMoveHistory.MovesText: string;
var
  I: Integer;
  LMoves: TStringList;
begin
  LMoves := TStringList.Create;
  try
    for I := 0 to FItems.Count - 1 do
      LMoves.Add(TGameMove(FItems[I]).MoveText);
    Result := Trim(StringReplace(LMoves.Text, LineEnding, ' ', [rfReplaceAll]));
  finally
    LMoves.Free;
  end;
end;

end.
