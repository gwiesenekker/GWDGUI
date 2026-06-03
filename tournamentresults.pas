unit TournamentResults;

{$mode objfpc}{$H+}

interface

type
  TTournamentResult = (trUnknown, trWhiteWin, trDraw, trBlackWin);

function ParseTournamentResult(const AText: String): TTournamentResult;
function TournamentResultIsKnown(AResult: TTournamentResult): Boolean;
function TournamentResultPointsForBlack(AResult: TTournamentResult): Integer;
function TournamentResultPointsForWhite(AResult: TTournamentResult): Integer;

implementation

uses
  SysUtils;

function ParseTournamentResult(const AText: String): TTournamentResult;
begin
  if SameText(AText, '2-0') then
    Result := trWhiteWin
  else if SameText(AText, '1-1') then
    Result := trDraw
  else if SameText(AText, '0-2') then
    Result := trBlackWin
  else
    Result := trUnknown;
end;

function TournamentResultIsKnown(AResult: TTournamentResult): Boolean;
begin
  Result := AResult <> trUnknown;
end;

function TournamentResultPointsForBlack(AResult: TTournamentResult): Integer;
begin
  case AResult of
    trDraw:
      Result := 1;
    trBlackWin:
      Result := 2;
  else
    Result := 0;
  end;
end;

function TournamentResultPointsForWhite(AResult: TTournamentResult): Integer;
begin
  case AResult of
    trWhiteWin:
      Result := 2;
    trDraw:
      Result := 1;
  else
    Result := 0;
  end;
end;

end.
