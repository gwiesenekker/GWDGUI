unit uGameMoveHistory;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uGamePosition;

type
  TGameMoveData = record
    MoveText: string;
    Side: TGameSide;
    SecondsUsed: Double;
    Annotation: string;
    PrincipalVariation: string;
    PvScore, PvDepth, PvTimeText: string;
    HasClockInfo: Boolean;
    WhiteRemainingSeconds, BlackRemainingSeconds: Double;
    WhiteUsedSeconds, BlackUsedSeconds: Double;
  end;
  TGameMoveDataArray = array of TGameMoveData;

  TGameMove = class
  public
    MoveText: string;
    Side: TGameSide;
    SecondsUsed: Double;
    Annotation: string;
    PrincipalVariation: string;
    PvScore, PvDepth, PvTimeText: string;
    HasClockInfo: Boolean;
    WhiteRemainingSeconds, BlackRemainingSeconds: Double;
    WhiteUsedSeconds, BlackUsedSeconds: Double;
  end;

  TGameMoveHistory = class
  private
    FItems: TList;
    function GetCount: Integer;
    function GetItem(AIndex: Integer): TGameMove;
  public
    constructor Create;
    destructor Destroy; override;
    function AddMove(const AMoveText: string; ASide: TGameSide;
      ASecondsUsed: Double; const AAnnotation: string = '';
      const APrincipalVariation: string = ''): TGameMove;
    function ExportData: TGameMoveDataArray;
    procedure Clear;
    procedure FillPureMoves(AMoves: TStrings);
    function AnnotationsText: string;
    function MovesText: string;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: TGameMove read GetItem; default;
  end;

function GameMoveDataSignature(const AData: TGameMoveDataArray): string;

implementation

function GameMoveDataSignature(const AData: TGameMoveDataArray): string;
var
  I: Integer;

  procedure Add(const Value: string);
  begin
    Result += IntToStr(Length(Value)) + ':' + Value;
  end;

begin
  Result := '';
  for I := 0 to Length(AData) - 1 do
  begin
    Add(AData[I].MoveText);
    Add(IntToStr(Ord(AData[I].Side)));
    Add(FloatToStr(AData[I].SecondsUsed));
    Add(AData[I].Annotation);
    Add(AData[I].PrincipalVariation);
    Add(AData[I].PvScore);
    Add(AData[I].PvDepth);
    Add(AData[I].PvTimeText);
    Add(BoolToStr(AData[I].HasClockInfo, True));
    Add(FloatToStr(AData[I].WhiteRemainingSeconds));
    Add(FloatToStr(AData[I].BlackRemainingSeconds));
    Add(FloatToStr(AData[I].WhiteUsedSeconds));
    Add(FloatToStr(AData[I].BlackUsedSeconds));
  end;
end;

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

function TGameMoveHistory.AddMove(const AMoveText: string; ASide: TGameSide;
  ASecondsUsed: Double; const AAnnotation: string;
  const APrincipalVariation: string): TGameMove;
begin
  Result := TGameMove.Create;
  // Callers pass canonical moves (the orchestrator validates them first).
  Result.MoveText := Trim(AMoveText);
  Result.Side := ASide;
  Result.SecondsUsed := ASecondsUsed;
  Result.Annotation := Trim(AAnnotation);
  Result.PrincipalVariation := Trim(APrincipalVariation);
  FItems.Add(Result);
end;

function TGameMoveHistory.ExportData: TGameMoveDataArray;
var
  I: Integer;
begin
  Result := nil;
  SetLength(Result, Count);
  for I := 0 to Count - 1 do
  begin
    Result[I].MoveText := Items[I].MoveText;
    Result[I].Side := Items[I].Side;
    Result[I].SecondsUsed := Items[I].SecondsUsed;
    Result[I].Annotation := Items[I].Annotation;
    Result[I].PrincipalVariation := Items[I].PrincipalVariation;
    Result[I].PvScore := Items[I].PvScore;
    Result[I].PvDepth := Items[I].PvDepth;
    Result[I].PvTimeText := Items[I].PvTimeText;
    Result[I].HasClockInfo := Items[I].HasClockInfo;
    Result[I].WhiteRemainingSeconds := Items[I].WhiteRemainingSeconds;
    Result[I].BlackRemainingSeconds := Items[I].BlackRemainingSeconds;
    Result[I].WhiteUsedSeconds := Items[I].WhiteUsedSeconds;
    Result[I].BlackUsedSeconds := Items[I].BlackUsedSeconds;
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
