unit uPdnOpenDialog;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Forms, Graphics, Grids, StdCtrls, SysUtils, uGuiDialogs,
  uPdn;

type
  TPdnGameSelectedEvent = procedure(Sender: TObject; AGame: TPdnGame) of object;

  TPdnOpenDialog = class(TForm)
  private
    FFileName: string;
    FGames: TList;
    FGrid: TStringGrid;
    FOnGameSelected: TPdnGameSelectedEvent;
    FStatusLabel: TLabel;
    FWarningLabel: TLabel;
    procedure GridSelectCell(Sender: TObject; ACol, ARow: Integer; var CanSelect: Boolean);
    procedure ShowGameWarnings(ARow: Integer);
    function GameAtRow(ARow: Integer): TPdnGame;
    procedure GridDblClick(Sender: TObject);
    procedure PopulateGrid;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure OpenPdnFile(const AFileName: string);
    property OnGameSelected: TPdnGameSelectedEvent read FOnGameSelected
      write FOnGameSelected;
  end;

implementation

constructor TPdnOpenDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Caption := 'Open PDN';
  Position := poDesigned;
  Width := 860;
  Height := 420;
  Constraints.MinWidth := 520;
  Constraints.MinHeight := 260;

  FGames := TList.Create;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Name := 'PdnImportStatus';
  FStatusLabel.Parent := Self;
  FStatusLabel.Align := alBottom;
  FStatusLabel.Height := 26;
  FStatusLabel.Layout := tlCenter;
  FStatusLabel.BorderSpacing.Left := 8;

  FWarningLabel := TLabel.Create(Self);
  FWarningLabel.Name := 'PdnImportWarnings';
  FWarningLabel.Parent := Self;
  FWarningLabel.Align := alBottom;
  FWarningLabel.AutoSize := False;
  FWarningLabel.Height := 50;
  FWarningLabel.WordWrap := True;
  FWarningLabel.ShowHint := True;
  FWarningLabel.BorderSpacing.Left := 8;
  FWarningLabel.BorderSpacing.Right := 8;
  FWarningLabel.Visible := False;

  FGrid := TStringGrid.Create(Self);
  FGrid.Name := 'PdnGames';
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.ColCount := 5;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.Options := FGrid.Options + [goRowSelect] -
    [goEditing, goRangeSelect];
  FGrid.Cells[0, 0] := 'White';
  FGrid.Cells[1, 0] := 'Black';
  FGrid.Cells[2, 0] := 'Event';
  FGrid.Cells[3, 0] := 'Result';
  FGrid.Cells[4, 0] := 'Warnings';
  FGrid.ColWidths[0] := 170;
  FGrid.ColWidths[1] := 170;
  FGrid.ColWidths[2] := 250;
  FGrid.ColWidths[3] := 70;
  FGrid.ColWidths[4] := 90;
  FGrid.RowCount := 2;
  FGrid.OnDblClick := @GridDblClick;
  FGrid.OnSelectCell := @GridSelectCell;
end;

destructor TPdnOpenDialog.Destroy;
var
  I: Integer;
begin
  for I := 0 to FGames.Count - 1 do
    TObject(FGames[I]).Free;
  FGames.Free;
  inherited Destroy;
end;

function TPdnOpenDialog.GameAtRow(ARow: Integer): TPdnGame;
begin
  Result := nil;
  if (ARow <= 0) or (ARow > FGames.Count) then
    Exit;
  Result := TPdnGame(FGames[ARow - 1]);
end;

procedure TPdnOpenDialog.GridDblClick(Sender: TObject);
var
  LGame: TPdnGame;
begin
  LGame := GameAtRow(FGrid.Row);
  if (LGame <> nil) and Assigned(FOnGameSelected) then
    FOnGameSelected(Self, LGame);
end;

procedure TPdnOpenDialog.ShowGameWarnings(ARow: Integer);
var
  Game: TPdnGame;
  Warnings: TStringList;
begin
  Game := GameAtRow(ARow);
  FWarningLabel.Caption := '';
  if Game <> nil then
  begin
    Game.ValidateMoveTree;
    FWarningLabel.Caption := Trim(StringReplace(Game.ImportWarningsText,
      LineEnding, ' ', [rfReplaceAll]));
    Warnings := TStringList.Create;
    try
      Warnings.Text := Game.ImportWarningsText;
      if Warnings.Count > 0 then FGrid.Cells[4, ARow] := IntToStr(Warnings.Count);
    finally Warnings.Free; end;
  end;
  FWarningLabel.Hint := FWarningLabel.Caption;
  FWarningLabel.Visible := FWarningLabel.Caption <> '';
end;

procedure TPdnOpenDialog.GridSelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
begin
  ShowGameWarnings(ARow);
end;

procedure TPdnOpenDialog.PopulateGrid;
var
  Game: TPdnGame;
  Row, WarningCount: Integer;
  Warnings: TStringList;
begin
  if FGames.Count = 0 then
    FGrid.RowCount := 2
  else
    FGrid.RowCount := FGames.Count + 1;
  for Row := 1 to FGrid.RowCount - 1 do
  begin
    FGrid.Cells[0, Row] := '';
    FGrid.Cells[1, Row] := '';
    FGrid.Cells[2, Row] := '';
    FGrid.Cells[3, Row] := '';
    FGrid.Cells[4, Row] := '';
  end;

  WarningCount := 0;
  Warnings := TStringList.Create;
  try
    for Row := 1 to FGames.Count do
    begin
      Game := TPdnGame(FGames[Row - 1]);
      FGrid.Cells[0, Row] := Game.WhiteName;
      FGrid.Cells[1, Row] := Game.BlackName;
      FGrid.Cells[2, Row] := Game.EventName;
      FGrid.Cells[3, Row] := Game.ResultText;
      Warnings.Text := Game.ImportWarningsText;
      Inc(WarningCount, Warnings.Count);
      if Warnings.Count > 0 then FGrid.Cells[4, Row] := IntToStr(Warnings.Count);
    end;
  finally
    Warnings.Free;
  end;

  FStatusLabel.Caption := IntToStr(FGames.Count) + ' game(s) found in ' +
    ExtractFileName(FFileName);
  if WarningCount > 0 then
    FStatusLabel.Caption := FStatusLabel.Caption + ' — ' + IntToStr(WarningCount) + ' import warning(s)';
  ShowGameWarnings(FGrid.Row);
end;

procedure TPdnOpenDialog.OpenPdnFile(const AFileName: string);
begin
  FFileName := AFileName;
  LoadPdnGamesFromFile(FFileName, FGames);
  PopulateGrid;
  {$IFNDEF GWDGUI_NONINTERACTIVE_TEST}
  if Owner is TCustomForm then
    ShowFormCenteredOnOwner(Self, TCustomForm(Owner))
  else
  begin
    Show;
    BringToFront;
  end;
  {$ENDIF}
end;

end.
