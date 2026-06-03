unit TournamentUi;

{$mode objfpc}{$H+}

interface

uses
  Grids,
  Types;

procedure DrawCrossTableCell(AGrid: TStringGrid; ACol, ARow: Integer;
  const ARect: TRect);
procedure DrawPairingGridCell(AGrid: TStringGrid; ACol, ARow: Integer;
  const ARect: TRect; ACurrentTournamentRow: Integer;
  ATournamentRunning: Boolean);

implementation

uses
  Graphics,
  Math;

const
  CurrentGameColor = TColor($00CCFFFF);

procedure DrawGridText(AGrid: TStringGrid; ACol, ARow: Integer;
  const ARect: TRect; AHorizontalPadding, AVerticalPadding: Integer);
var
  TextRect: TRect;
begin
  AGrid.Canvas.FillRect(ARect);
  TextRect := ARect;
  InflateRect(TextRect, -AHorizontalPadding, -AVerticalPadding);
  AGrid.Canvas.TextRect(TextRect, TextRect.Left,
    TextRect.Top + Max(0, (TextRect.Height -
    AGrid.Canvas.TextHeight(AGrid.Cells[ACol, ARow])) div 2),
    AGrid.Cells[ACol, ARow]);
end;

procedure DrawCrossTableCell(AGrid: TStringGrid; ACol, ARow: Integer;
  const ARect: TRect);
begin
  if (ARow > 0) and (ACol > 0) and (ACol = ARow) and
    (ACol < AGrid.ColCount - 1) then
  begin
    AGrid.Canvas.Brush.Color := clGray;
    AGrid.Canvas.Font.Color := clWhite;
  end
  else if ARow = 0 then
  begin
    AGrid.Canvas.Brush.Color := clBtnFace;
    AGrid.Canvas.Font.Color := clWindowText;
  end
  else
  begin
    AGrid.Canvas.Brush.Color := clWindow;
    AGrid.Canvas.Font.Color := clWindowText;
  end;

  DrawGridText(AGrid, ACol, ARow, ARect, 4, 2);
end;

procedure DrawPairingGridCell(AGrid: TStringGrid; ACol, ARow: Integer;
  const ARect: TRect; ACurrentTournamentRow: Integer;
  ATournamentRunning: Boolean);
begin
  if ARow = 0 then
  begin
    AGrid.Canvas.Brush.Color := clBtnFace;
    AGrid.Canvas.Font.Color := clWindowText;
  end
  else if ATournamentRunning and (ARow = ACurrentTournamentRow) then
  begin
    AGrid.Canvas.Brush.Color := CurrentGameColor;
    AGrid.Canvas.Font.Color := clBlack;
  end
  else
  begin
    AGrid.Canvas.Brush.Color := clWindow;
    AGrid.Canvas.Font.Color := clWindowText;
  end;

  DrawGridText(AGrid, ACol, ARow, ARect, 4, 0);
end;

end.
