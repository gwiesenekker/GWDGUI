unit BoardGeometry;

{$mode objfpc}{$H+}

interface

uses
  Types;

const
  BoardGeometrySize = 10;

function BoardCellSize(const ABoardRect: TRect): Integer;
function SnapBoardPixels(APixels: Integer): Integer;
function BoardCellRect(const ABoardRect: TRect; ARow, ACol: Integer): TRect;
function BoardSquareAtCell(ARow, ACol: Integer; ABoardFlipped: Boolean): Integer;
function BoardCellForSquare(ASquare: Integer; ABoardFlipped: Boolean;
  out ARow, ACol: Integer): Boolean;
function BoardSquareAtPoint(const ABoardRect: TRect; X, Y: Integer;
  ABoardFlipped: Boolean): Integer;

implementation

function BoardCellSize(const ABoardRect: TRect): Integer;
begin
  if (ABoardRect.Right <= ABoardRect.Left) or
    (ABoardRect.Bottom <= ABoardRect.Top) then
    Exit(0);
  Result := (ABoardRect.Right - ABoardRect.Left) div BoardGeometrySize;
end;

function SnapBoardPixels(APixels: Integer): Integer;
begin
  Result := (APixels div BoardGeometrySize) * BoardGeometrySize;
end;

function BoardCellRect(const ABoardRect: TRect; ARow, ACol: Integer): TRect;
var
  CellSize: Integer;
begin
  CellSize := BoardCellSize(ABoardRect);
  Result := Types.Rect(ABoardRect.Left + (ACol * CellSize),
    ABoardRect.Top + (ARow * CellSize),
    ABoardRect.Left + ((ACol + 1) * CellSize),
    ABoardRect.Top + ((ARow + 1) * CellSize));
end;

function BoardSquareAtCell(ARow, ACol: Integer; ABoardFlipped: Boolean): Integer;
var
  LogicalCol: Integer;
  LogicalRow: Integer;
begin
  Result := 0;
  if ABoardFlipped then
  begin
    LogicalRow := BoardGeometrySize - 1 - ARow;
    LogicalCol := BoardGeometrySize - 1 - ACol;
  end
  else
  begin
    LogicalRow := ARow;
    LogicalCol := ACol;
  end;

  if (LogicalRow < 0) or (LogicalRow >= BoardGeometrySize) or
    (LogicalCol < 0) or (LogicalCol >= BoardGeometrySize) or
    (not Odd(LogicalRow + LogicalCol)) then
    Exit;

  Result := (LogicalRow * 5) + (LogicalCol div 2) + 1;
end;

function BoardCellForSquare(ASquare: Integer; ABoardFlipped: Boolean;
  out ARow, ACol: Integer): Boolean;
var
  LogicalCol: Integer;
  LogicalRow: Integer;
begin
  Result := False;
  ARow := 0;
  ACol := 0;
  if (ASquare < 1) or (ASquare > 50) then
    Exit;

  LogicalRow := (ASquare - 1) div 5;
  LogicalCol := ((ASquare - 1) mod 5) * 2;
  if not Odd(LogicalRow) then
    Inc(LogicalCol);

  if ABoardFlipped then
  begin
    ARow := BoardGeometrySize - 1 - LogicalRow;
    ACol := BoardGeometrySize - 1 - LogicalCol;
  end
  else
  begin
    ARow := LogicalRow;
    ACol := LogicalCol;
  end;
  Result := True;
end;

function BoardSquareAtPoint(const ABoardRect: TRect; X, Y: Integer;
  ABoardFlipped: Boolean): Integer;
var
  CellSize: Integer;
  Col: Integer;
  Row: Integer;
begin
  Result := 0;
  if (ABoardRect.Right <= ABoardRect.Left) or
    (ABoardRect.Bottom <= ABoardRect.Top) then
    Exit;
  if (X < ABoardRect.Left) or (X >= ABoardRect.Right) or
    (Y < ABoardRect.Top) or (Y >= ABoardRect.Bottom) then
    Exit;

  CellSize := BoardCellSize(ABoardRect);
  if CellSize <= 0 then
    Exit;

  Col := (X - ABoardRect.Left) div CellSize;
  Row := (Y - ABoardRect.Top) div CellSize;
  if (Row < 0) or (Row >= BoardGeometrySize) or
    (Col < 0) or (Col >= BoardGeometrySize) then
    Exit;

  Result := BoardSquareAtCell(Row, Col, ABoardFlipped);
end;

end.
