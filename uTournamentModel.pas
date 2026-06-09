unit uTournamentModel;

{$mode objfpc}{$H+}

interface

uses
  Classes;

type
  TTournamentTextArray = array of string;
  TTournamentIntArray = array of Integer;
  TTournamentFloatArray = array of Double;
  TTournamentTextMatrix = array of array of string;

  TTournamentCrossTable = record
    EngineNames: TTournamentTextArray;
    Matrix: TTournamentTextMatrix;
    Order: TTournamentIntArray;
    Points: TTournamentIntArray;
    SB: TTournamentFloatArray;
    Wins: TTournamentIntArray;
  end;

function CompactTournamentEngineHeader(const AName: string): string;
function FormatTournamentSB(AValue: Double): string;
procedure BuildTournamentCrossTable(ASelectedEngines, AWhiteEngines,
  ABlackEngines, AResults: TStrings; out ATable: TTournamentCrossTable);

implementation

uses
  StrUtils, SysUtils, uTournamentResults;

function IsDisplayOnlyName(const AName: string): Boolean;
begin
  Result := (AName = '') or AnsiStartsText('(', AName) or SameText(AName, 'BYE');
end;

procedure EnsureEngine(var ATable: TTournamentCrossTable; const AName: string);
var
  Count: Integer;
  I: Integer;
begin
  if IsDisplayOnlyName(AName) then
    Exit;
  for I := 0 to High(ATable.EngineNames) do
    if ATable.EngineNames[I] = AName then
      Exit;
  Count := Length(ATable.EngineNames) + 1;
  SetLength(ATable.EngineNames, Count);
  SetLength(ATable.Points, Count);
  SetLength(ATable.Wins, Count);
  SetLength(ATable.SB, Count);
  ATable.EngineNames[Count - 1] := AName;
end;

function EngineIndex(const ATable: TTournamentCrossTable;
  const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(ATable.EngineNames) do
    if ATable.EngineNames[I] = AName then
      Exit(I);
  Result := -1;
end;

procedure AddMarker(var ATable: TTournamentCrossTable; ARow,
  AOpponent: Integer; const AText: string);
begin
  if (ARow < 0) or (AOpponent < 0) or (AText = '') then
    Exit;
  if ATable.Matrix[ARow, AOpponent] <> '' then
    ATable.Matrix[ARow, AOpponent] := ATable.Matrix[ARow, AOpponent] + '/' +
      AText
  else
    ATable.Matrix[ARow, AOpponent] := AText;
end;

procedure AddPoints(var ATable: TTournamentCrossTable; const AName: string;
  APoints: Integer);
var
  Index: Integer;
begin
  Index := EngineIndex(ATable, AName);
  if Index >= 0 then
    Inc(ATable.Points[Index], APoints);
end;

procedure AddWin(var ATable: TTournamentCrossTable; const AName: string);
var
  Index: Integer;
begin
  Index := EngineIndex(ATable, AName);
  if Index >= 0 then
    Inc(ATable.Wins[Index]);
end;

function ComesBefore(const ATable: TTournamentCrossTable; AIndex,
  BIndex: Integer): Boolean;
begin
  if ATable.Points[AIndex] <> ATable.Points[BIndex] then
    Exit(ATable.Points[AIndex] > ATable.Points[BIndex]);
  if ATable.Wins[AIndex] <> ATable.Wins[BIndex] then
    Exit(ATable.Wins[AIndex] > ATable.Wins[BIndex]);
  if Abs(ATable.SB[AIndex] - ATable.SB[BIndex]) > 0.0001 then
    Exit(ATable.SB[AIndex] > ATable.SB[BIndex]);
  Result := AnsiCompareText(ATable.EngineNames[AIndex],
    ATable.EngineNames[BIndex]) < 0;
end;

function CompactTournamentEngineHeader(const AName: string): string;
const
  Marker = ' (Engine ';
var
  IChar: Integer;
  NumberText: string;
  P: Integer;
begin
  Result := Trim(AName);
  P := Pos(Marker, Result);
  if P <= 0 then
    Exit;
  NumberText := '';
  IChar := P + Length(Marker);
  while (IChar <= Length(Result)) and (Result[IChar] in ['0'..'9']) do
  begin
    NumberText += Result[IChar];
    Inc(IChar);
  end;
  Result := Trim(Copy(Result, 1, P - 1));
  if NumberText <> '' then
    Result := Result + '#' + NumberText;
end;

function FormatTournamentSB(AValue: Double): string;
begin
  if Abs(AValue - Round(AValue)) < 0.0001 then
    Result := IntToStr(Round(AValue))
  else
    Result := FormatFloat('0.0', AValue);
end;

procedure BuildTournamentCrossTable(ASelectedEngines, AWhiteEngines,
  ABlackEngines, AResults: TStrings; out ATable: TTournamentCrossTable);
var
  BlackIndex: Integer;
  I: Integer;
  J: Integer;
  GameResult: TTournamentResult;
  Temp: Integer;
  WhiteIndex: Integer;
begin
  SetLength(ATable.EngineNames, 0);
  SetLength(ATable.Matrix, 0, 0);
  SetLength(ATable.Order, 0);
  SetLength(ATable.Points, 0);
  SetLength(ATable.SB, 0);
  SetLength(ATable.Wins, 0);

  for I := 0 to ASelectedEngines.Count - 1 do
    EnsureEngine(ATable, ASelectedEngines[I]);
  for I := 0 to AWhiteEngines.Count - 1 do
  begin
    EnsureEngine(ATable, AWhiteEngines[I]);
    EnsureEngine(ATable, ABlackEngines[I]);
  end;

  SetLength(ATable.Matrix, Length(ATable.EngineNames), Length(ATable.EngineNames));
  SetLength(ATable.Order, Length(ATable.EngineNames));
  for I := 0 to High(ATable.Order) do
    ATable.Order[I] := I;

  for I := 0 to AResults.Count - 1 do
  begin
    GameResult := ParseTournamentResult(AResults[I]);
    if not TournamentResultIsKnown(GameResult) then
      Continue;
    AddPoints(ATable, AWhiteEngines[I], TournamentResultPointsForWhite(GameResult));
    AddPoints(ATable, ABlackEngines[I], TournamentResultPointsForBlack(GameResult));
    if GameResult = trWhiteWin then
      AddWin(ATable, AWhiteEngines[I]);
    if GameResult = trBlackWin then
      AddWin(ATable, ABlackEngines[I]);
  end;

  for I := 0 to AResults.Count - 1 do
  begin
    GameResult := ParseTournamentResult(AResults[I]);
    if not TournamentResultIsKnown(GameResult) then
      Continue;
    WhiteIndex := EngineIndex(ATable, AWhiteEngines[I]);
    BlackIndex := EngineIndex(ATable, ABlackEngines[I]);
    if (WhiteIndex < 0) or (BlackIndex < 0) then
      Continue;
    if GameResult = trWhiteWin then
    begin
      ATable.SB[WhiteIndex] += ATable.Points[BlackIndex];
      AddMarker(ATable, WhiteIndex, BlackIndex, '2W');
      AddMarker(ATable, BlackIndex, WhiteIndex, '0B');
    end
    else if GameResult = trDraw then
    begin
      ATable.SB[WhiteIndex] += ATable.Points[BlackIndex] / 2;
      ATable.SB[BlackIndex] += ATable.Points[WhiteIndex] / 2;
      AddMarker(ATable, WhiteIndex, BlackIndex, '1W');
      AddMarker(ATable, BlackIndex, WhiteIndex, '1B');
    end
    else if GameResult = trBlackWin then
    begin
      ATable.SB[BlackIndex] += ATable.Points[WhiteIndex];
      AddMarker(ATable, WhiteIndex, BlackIndex, '0W');
      AddMarker(ATable, BlackIndex, WhiteIndex, '2B');
    end;
  end;

  for I := 0 to High(ATable.Order) - 1 do
    for J := I + 1 to High(ATable.Order) do
      if not ComesBefore(ATable, ATable.Order[I], ATable.Order[J]) then
      begin
        Temp := ATable.Order[I];
        ATable.Order[I] := ATable.Order[J];
        ATable.Order[J] := Temp;
      end;
end;

end.
