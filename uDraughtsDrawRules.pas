unit uDraughtsDrawRules;
{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
interface
uses uDraughtsBoard;
type
  TEndgameDrawCounter = record
  private
    FSixteenPlies, FFivePlies: Integer;
    procedure ObserveMaterial(Board: TDraughtsBoard);
  public
    procedure Start(Board: TDraughtsBoard);
    procedure AfterMove(Board: TDraughtsBoard);
    function DrawMoveLimit: Integer;
  end;
implementation
procedure TEndgameDrawCounter.ObserveMaterial(Board: TDraughtsBoard);
var Men, Kings: array[TDraughtsSide] of Integer;
  I, WhiteCount, BlackCount: Integer;
begin
  Men[dsWhite] := 0; Men[dsBlack] := 0;
  Kings[dsWhite] := 0; Kings[dsBlack] := 0;
  for I := 1 to 50 do
    case Board[I] of
      pkWhiteMan: Inc(Men[dsWhite]); pkBlackMan: Inc(Men[dsBlack]);
      pkWhiteKing: Inc(Kings[dsWhite]); pkBlackKing: Inc(Kings[dsBlack]);
    end;
  WhiteCount := Men[dsWhite] + Kings[dsWhite];
  BlackCount := Men[dsBlack] + Kings[dsBlack];
  if (FSixteenPlies < 0) and
    (((WhiteCount = 3) and (Kings[dsWhite] > 0) and (BlackCount = 1) and (Kings[dsBlack] = 1)) or
     ((BlackCount = 3) and (Kings[dsBlack] > 0) and (WhiteCount = 1) and (Kings[dsWhite] = 1))) then
    FSixteenPlies := 0;
  if (FFivePlies < 0) and
    (((WhiteCount in [1, 2]) and (Kings[dsWhite] > 0) and (BlackCount = 1) and (Kings[dsBlack] = 1)) or
     ((BlackCount in [1, 2]) and (Kings[dsBlack] > 0) and (WhiteCount = 1) and (Kings[dsWhite] = 1))) then
    FFivePlies := 0;
end;
procedure TEndgameDrawCounter.Start(Board: TDraughtsBoard);
begin
  FSixteenPlies := -1; FFivePlies := -1;
  ObserveMaterial(Board);
end;
procedure TEndgameDrawCounter.AfterMove(Board: TDraughtsBoard);
begin
  // FMJD Annex 1, 6.3: a capture does not restart an existing 16-move limit.
  if FSixteenPlies >= 0 then Inc(FSixteenPlies);
  if FFivePlies >= 0 then Inc(FFivePlies);
  ObserveMaterial(Board);
end;
function TEndgameDrawCounter.DrawMoveLimit: Integer;
begin
  Result := 0;
  if FSixteenPlies >= 32 then Result := 16;
  if FFivePlies >= 10 then Result := 5;
end;
end.
