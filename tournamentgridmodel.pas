unit TournamentGridModel;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  CheckLst,
  Grids,
  TournamentModel,
  TournamentPairing,
  TournamentStorage;

const
  TournamentColGame = 0;
  TournamentColRound = 1;
  TournamentColWhite = 2;
  TournamentColBlack = 3;
  TournamentColResult = 4;
  TournamentColReason = 5;

function AddTournamentPairingRow(AGrid: TStringGrid; const AWhite,
  ABlack: String; ARound: Integer): Integer;
procedure ClearTournamentPairingGrid(AGrid: TStringGrid);
procedure CollectTournamentPairingRows(AGrid: TStringGrid; AWhiteEngines,
  ABlackEngines, AResults: TStrings);
procedure CollectTournamentRoundRows(AGrid: TStringGrid; ARounds: TStrings);
procedure CollectSelectedTournamentEngineNames(ACheckList: TCheckListBox;
  AEngines: TStrings);
procedure CollectSelectedTournamentEngineNames(ACheckList: TCheckListBox;
  var AEngines: TTournamentTextArray);
procedure ApplySelectedTournamentEngineNames(ACheckList: TCheckListBox;
  const AEngineNames: TTournamentTextArray);
procedure BuildTournamentFileDataFromGrid(AGrid: TStringGrid;
  ACheckList: TCheckListBox; const AName, ATournamentType: String;
  AMinutes: Integer; out AData: TTournamentFileData);
procedure ApplyTournamentPairingRoundToGrid(AGrid: TStringGrid;
  const APairingRound: TTournamentPairingRound);
procedure ApplyTournamentGamesToGrid(AGrid: TStringGrid;
  const AData: TTournamentFileData);
function TournamentGridHasPairingAtRow(AGrid: TStringGrid; ARow: Integer): Boolean;
function TournamentPairingGridIsEmpty(AGrid: TStringGrid): Boolean;

implementation

uses
  StrUtils,
  SysUtils;

function AddTournamentPairingRow(AGrid: TStringGrid; const AWhite,
  ABlack: String; ARound: Integer): Integer;
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
    if ACheckList.Checked[I] and
      (not AnsiStartsText('(', ACheckList.Items[I])) then
      AEngines.Add(ACheckList.Items[I]);
end;

procedure CollectSelectedTournamentEngineNames(ACheckList: TCheckListBox;
  var AEngines: TTournamentTextArray);
var
  I: Integer;
begin
  SetLength(AEngines, 0);
  for I := 0 to ACheckList.Items.Count - 1 do
    if ACheckList.Checked[I] and
      (not AnsiStartsText('(', ACheckList.Items[I])) then
    begin
      SetLength(AEngines, Length(AEngines) + 1);
      AEngines[High(AEngines)] := ACheckList.Items[I];
    end;
end;

procedure ApplySelectedTournamentEngineNames(ACheckList: TCheckListBox;
  const AEngineNames: TTournamentTextArray);
var
  EngineName: String;
  I: Integer;
  J: Integer;
begin
  if Length(AEngineNames) = 0 then
    Exit;

  for I := 0 to ACheckList.Items.Count - 1 do
    if not AnsiStartsText('(', ACheckList.Items[I]) then
      ACheckList.Checked[I] := False;
  for I := 0 to High(AEngineNames) do
  begin
    EngineName := AEngineNames[I];
    for J := 0 to ACheckList.Items.Count - 1 do
      if SameText(ACheckList.Items[J], EngineName) then
      begin
        ACheckList.Checked[J] := True;
        Break;
      end;
  end;
end;

procedure BuildTournamentFileDataFromGrid(AGrid: TStringGrid;
  ACheckList: TCheckListBox; const AName, ATournamentType: String;
  AMinutes: Integer; out AData: TTournamentFileData);
var
  GameIndex: Integer;
  Row: Integer;
begin
  AData.Name := AName;
  AData.Minutes := AMinutes;
  AData.TournamentType := ATournamentType;
  CollectSelectedTournamentEngineNames(ACheckList, AData.EngineNames);

  SetLength(AData.Games, 0);
  SetLength(AData.GameNumbers, 0);
  SetLength(AData.ResultReasons, 0);
  SetLength(AData.Results, 0);
  SetLength(AData.RoundNumbers, 0);
  for Row := 1 to AGrid.RowCount - 1 do
    if TournamentGridHasPairingAtRow(AGrid, Row) then
    begin
      GameIndex := Length(AData.Games);
      SetLength(AData.Games, GameIndex + 1);
      SetLength(AData.GameNumbers, GameIndex + 1);
      SetLength(AData.ResultReasons, GameIndex + 1);
      SetLength(AData.Results, GameIndex + 1);
      SetLength(AData.RoundNumbers, GameIndex + 1);
      AData.GameNumbers[GameIndex] := StrToIntDef(
        AGrid.Cells[TournamentColGame, Row], Row);
      AData.RoundNumbers[GameIndex] := StrToIntDef(
        AGrid.Cells[TournamentColRound, Row], 1);
      AData.Games[GameIndex].White := AGrid.Cells[TournamentColWhite, Row];
      AData.Games[GameIndex].Black := AGrid.Cells[TournamentColBlack, Row];
      AData.Results[GameIndex] := AGrid.Cells[TournamentColResult, Row];
      AData.ResultReasons[GameIndex] := AGrid.Cells[TournamentColReason, Row];
    end;
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

procedure ApplyTournamentGamesToGrid(AGrid: TStringGrid;
  const AData: TTournamentFileData);
var
  I: Integer;
  Row: Integer;
begin
  ClearTournamentPairingGrid(AGrid);
  for I := 0 to High(AData.Games) do
  begin
    Row := AddTournamentPairingRow(AGrid, AData.Games[I].White,
      AData.Games[I].Black, AData.RoundNumbers[I]);
    AGrid.Cells[TournamentColGame, Row] := IntToStr(AData.GameNumbers[I]);
    AGrid.Cells[TournamentColResult, Row] := AData.Results[I];
    if I <= High(AData.ResultReasons) then
      AGrid.Cells[TournamentColReason, Row] := AData.ResultReasons[I];
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
  BlackEngines: TStringList;
  Results: TStringList;
  WhiteEngines: TStringList;
begin
  WhiteEngines := TStringList.Create;
  BlackEngines := TStringList.Create;
  Results := TStringList.Create;
  try
    CollectTournamentPairingRows(AGrid, WhiteEngines, BlackEngines, Results);
    Result := TournamentPairingRowsEmpty(WhiteEngines, BlackEngines);
  finally
    Results.Free;
    BlackEngines.Free;
    WhiteEngines.Free;
  end;
end;

end.
