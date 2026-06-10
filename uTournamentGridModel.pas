unit uTournamentGridModel;

{$mode objfpc}{$H+}

interface

uses
  Classes, CheckLst, Grids, uTournamentModel, uTournamentPairing;

const
  TournamentColGame = 0;
  TournamentColRound = 1;
  TournamentColWhite = 2;
  TournamentColBlack = 3;
  TournamentColResult = 4;
  TournamentColReason = 5;

function AddTournamentPairingRow(AGrid: TStringGrid; const AWhite,
  ABlack: string; ARound: Integer): Integer;
procedure ClearTournamentPairingGrid(AGrid: TStringGrid);
procedure CollectTournamentPairingRows(AGrid: TStringGrid; AWhiteEngines,
  ABlackEngines, AResults: TStrings);
procedure CollectTournamentRoundRows(AGrid: TStringGrid; ARounds: TStrings);
procedure CollectSelectedTournamentEngineNames(ACheckList: TCheckListBox;
  AEngines: TStrings);
procedure ApplyTournamentPairingRoundToGrid(AGrid: TStringGrid;
  const APairingRound: TTournamentPairingRound);
function TournamentGridHasPairingAtRow(AGrid: TStringGrid; ARow: Integer): Boolean;
function TournamentPairingGridIsEmpty(AGrid: TStringGrid): Boolean;

implementation

uses
  StrUtils, SysUtils;

function AddTournamentPairingRow(AGrid: TStringGrid; const AWhite,
  ABlack: string; ARound: Integer): Integer;
begin
  if (AGrid.RowCount = 2) and (AGrid.Cells[TournamentColGame, 1] = '') and
    (AGrid.Cells[TournamentColWhite, 1] = '') and
    (AGrid.Cells[TournamentColBlack, 1] = '') then
    Result := 1
  else
  begin
    Result := AGrid.RowCount;
    AGrid.RowCount := AGrid.RowCount + 1;
  end;
  AGrid.Cells[TournamentColGame, Result] := IntToStr(Result);
  AGrid.Cells[TournamentColRound, Result] := IntToStr(ARound);
  AGrid.Cells[TournamentColWhite, Result] := AWhite;
  AGrid.Cells[TournamentColBlack, Result] := ABlack;
  AGrid.Cells[TournamentColResult, Result] := '*';
  AGrid.Cells[TournamentColReason, Result] := '';
end;

procedure ClearTournamentPairingGrid(AGrid: TStringGrid);
begin
  AGrid.RowCount := 2;
  AGrid.Cells[TournamentColGame, 1] := '';
  AGrid.Cells[TournamentColRound, 1] := '';
  AGrid.Cells[TournamentColWhite, 1] := '';
  AGrid.Cells[TournamentColBlack, 1] := '';
  AGrid.Cells[TournamentColResult, 1] := '';
  AGrid.Cells[TournamentColReason, 1] := '';
end;

procedure CollectTournamentPairingRows(AGrid: TStringGrid; AWhiteEngines,
  ABlackEngines, AResults: TStrings);
var
  Row: Integer;
begin
  AWhiteEngines.Clear;
  ABlackEngines.Clear;
  AResults.Clear;
  for Row := 1 to AGrid.RowCount - 1 do
  begin
    AWhiteEngines.Add(AGrid.Cells[TournamentColWhite, Row]);
    ABlackEngines.Add(AGrid.Cells[TournamentColBlack, Row]);
    AResults.Add(AGrid.Cells[TournamentColResult, Row]);
  end;
end;

procedure CollectTournamentRoundRows(AGrid: TStringGrid; ARounds: TStrings);
var
  Row: Integer;
begin
  ARounds.Clear;
  for Row := 1 to AGrid.RowCount - 1 do
    ARounds.Add(AGrid.Cells[TournamentColRound, Row]);
end;

procedure CollectSelectedTournamentEngineNames(ACheckList: TCheckListBox;
  AEngines: TStrings);
var
  I: Integer;
begin
  AEngines.Clear;
  for I := 0 to ACheckList.Items.Count - 1 do
    if ACheckList.Checked[I] and (not AnsiStartsText('(', ACheckList.Items[I])) then
      AEngines.Add(ACheckList.Items[I]);
end;

procedure ApplyTournamentPairingRoundToGrid(AGrid: TStringGrid;
  const APairingRound: TTournamentPairingRound);
var
  I: Integer;
  Row: Integer;
begin
  for I := 0 to High(APairingRound.Pairings) do
  begin
    Row := AddTournamentPairingRow(AGrid, APairingRound.Pairings[I].White,
      APairingRound.Pairings[I].Black, APairingRound.RoundNumber);
    if SameText(APairingRound.Pairings[I].Black, 'BYE') then
    begin
      AGrid.Cells[TournamentColResult, Row] := '2-0';
      AGrid.Cells[TournamentColReason, Row] := 'Bye';
    end;
  end;
end;

function TournamentGridHasPairingAtRow(AGrid: TStringGrid; ARow: Integer): Boolean;
begin
  Result := (ARow > 0) and (ARow < AGrid.RowCount) and
    ((AGrid.Cells[TournamentColWhite, ARow] <> '') or
    (AGrid.Cells[TournamentColBlack, ARow] <> ''));
end;

function TournamentPairingGridIsEmpty(AGrid: TStringGrid): Boolean;
var
  Row: Integer;
begin
  Result := True;
  for Row := 1 to AGrid.RowCount - 1 do
    if TournamentGridHasPairingAtRow(AGrid, Row) then
      Exit(False);
end;

end.
