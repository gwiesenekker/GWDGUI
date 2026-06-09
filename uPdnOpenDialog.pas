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
  Width := 720;
  Height := 420;
  Constraints.MinWidth := 520;
  Constraints.MinHeight := 260;

  FGames := TList.Create;

  FStatusLabel := TLabel.Create(Self);
  FStatusLabel.Parent := Self;
  FStatusLabel.Align := alBottom;
  FStatusLabel.Height := 26;
  FStatusLabel.Layout := tlCenter;
  FStatusLabel.BorderSpacing.Left := 8;

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.ColCount := 4;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.Options := FGrid.Options + [goRowSelect] -
    [goEditing, goRangeSelect];
  FGrid.Cells[0, 0] := 'White';
  FGrid.Cells[1, 0] := 'Black';
  FGrid.Cells[2, 0] := 'Event';
  FGrid.Cells[3, 0] := 'Result';
  FGrid.ColWidths[0] := 170;
  FGrid.ColWidths[1] := 170;
  FGrid.ColWidths[2] := 250;
  FGrid.ColWidths[3] := 70;
  FGrid.RowCount := 2;
  FGrid.OnDblClick := @GridDblClick;
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

procedure TPdnOpenDialog.PopulateGrid;
var
  Game: TPdnGame;
  Row: Integer;
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
  end;

  for Row := 1 to FGames.Count do
  begin
    Game := TPdnGame(FGames[Row - 1]);
    FGrid.Cells[0, Row] := Game.WhiteName;
    FGrid.Cells[1, Row] := Game.BlackName;
    FGrid.Cells[2, Row] := Game.EventName;
    FGrid.Cells[3, Row] := Game.ResultText;
  end;

  FStatusLabel.Caption := IntToStr(FGames.Count) + ' game(s) found in ' +
    ExtractFileName(FFileName);
end;

procedure TPdnOpenDialog.OpenPdnFile(const AFileName: string);
begin
  FFileName := AFileName;
  LoadPdnGamesFromFile(FFileName, FGames);
  PopulateGrid;
  if Owner is TCustomForm then
    ShowFormCenteredOnOwner(Self, TCustomForm(Owner))
  else
  begin
    Show;
    BringToFront;
  end;
end;

end.
