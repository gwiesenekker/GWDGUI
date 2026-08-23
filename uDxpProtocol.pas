unit uDxpProtocol;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  uDraughtsBoard;

function DxpBuildGameReqPacket(ABoard: TDraughtsBoard; AEngineSide: TDraughtsSide;
  AGameMinutes: Double; AGameMoves: Integer; const ANameText: string): string;
function DxpBuildGameReqFischerPacket(ABoard: TDraughtsBoard;
  AEngineSide: TDraughtsSide; AInitialSeconds, AIncrementSeconds: Double;
  const ANameText: string): string;
function DxpBuildGameEndPacket(ACode: Char): string;
function DxpBuildGameEndPacketWithStopCode(AReason, AStopCode: Char): string;
function DxpBuildMovePacket(const AMove: string; ATotalTimeUsedSeconds: Integer): string;
function DxpMoveMessageToText(const AMessage: string; out AMoveText: string): Boolean;

implementation

function Dxp2(AValue: Integer): string;
begin
  if AValue < 0 then
    AValue := 0;
  if AValue > 99 then
    AValue := 99;
  Result := Format('%.2d', [AValue]);
end;

function Dxp3(AValue: Integer): string;
begin
  if AValue < 0 then
    AValue := 0;
  if AValue > 999 then
    AValue := 999;
  Result := Format('%.3d', [AValue]);
end;

function Dxp4(AValue: Integer): string;
begin
  if AValue < 0 then
    AValue := 0;
  if AValue > 9999 then
    AValue := 9999;
  Result := Format('%.4d', [AValue]);
end;

function Dxp6Seconds(AValue: Double): string;
var
  DotPos: Integer;
  FS: TFormatSettings;
begin
  if AValue < 0 then
    AValue := 0;

  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';
  Result := FormatFloat('0.###', AValue, FS);
  while Length(Result) > 6 do
  begin
    DotPos := Pos('.', Result);
    if (DotPos = 0) or (DotPos = Length(Result)) then
      Break;
    Delete(Result, Length(Result), 1);
    if (Length(Result) > 0) and (Result[Length(Result)] = '.') then
      Delete(Result, Length(Result), 1);
  end;
  if Length(Result) > 6 then
    Result := FormatFloat('0', AValue, FS);
  if Length(Result) > 6 then
    SetLength(Result, 6);
  while Length(Result) < 6 do
    Result := '0' + Result;
end;

function DxpSideText(ASide: TDraughtsSide): Char;
begin
  if ASide = dsWhite then
    Result := 'W'
  else
    Result := 'Z';
end;

function DxpPieceText(APiece: TDraughtsPieceKind): Char;
begin
  case APiece of
    pkWhiteMan:
      Result := 'w';
    pkWhiteKing:
      Result := 'W';
    pkBlackMan:
      Result := 'z';
    pkBlackKing:
      Result := 'Z';
  else
    Result := 'e';
  end;
end;

procedure ExtractMoveSquares(const AMove: string; ASquares: TStrings);
var
  I: Integer;
  Token: string;
begin
  ASquares.Clear;
  Token := '';
  for I := 1 to Length(AMove) do
  begin
    if AMove[I] in ['0'..'9'] then
      Token += AMove[I]
    else if AMove[I] in ['-', 'x', 'X'] then
    begin
      if Token <> '' then
        ASquares.Add(Token);
      Token := '';
    end;
  end;
  if Token <> '' then
    ASquares.Add(Token);
end;

function DxpPaddedName(const ANameText: string): string;
begin
  Result := ANameText;
  if Length(Result) > 32 then
    SetLength(Result, 32);
  while Length(Result) < 32 do
    Result += ' ';
end;

function DxpBoardText(ABoard: TDraughtsBoard): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to 50 do
    Result += DxpPieceText(ABoard[I]);
end;

function DxpBuildGameReqPacket(ABoard: TDraughtsBoard; AEngineSide: TDraughtsSide;
  AGameMinutes: Double; AGameMoves: Integer; const ANameText: string): string;
var
  GameTime: Integer;
begin
  Result := '';
  if ABoard = nil then
    Exit;

  GameTime := Round(AGameMinutes);
  if GameTime <= 0 then
    GameTime := 1;

  Result := 'R' + '01' + DxpPaddedName(ANameText) + DxpSideText(AEngineSide) +
    Dxp3(GameTime) + Dxp3(AGameMoves) + 'B' +
    DxpSideText(ABoard.SideToMove) + DxpBoardText(ABoard);
end;

function DxpBuildGameReqFischerPacket(ABoard: TDraughtsBoard;
  AEngineSide: TDraughtsSide; AInitialSeconds, AIncrementSeconds: Double;
  const ANameText: string): string;
begin
  Result := '';
  if ABoard = nil then
    Exit;

  Result := 'F' + '01' + DxpPaddedName(ANameText) + DxpSideText(AEngineSide) +
    Dxp6Seconds(AInitialSeconds) + Dxp6Seconds(AIncrementSeconds) + 'B' +
    DxpSideText(ABoard.SideToMove) + DxpBoardText(ABoard);
end;

function DxpBuildGameEndPacket(ACode: Char): string;
begin
  Result := DxpBuildGameEndPacketWithStopCode(ACode, '0');
end;

function DxpBuildGameEndPacketWithStopCode(AReason, AStopCode: Char): string;
begin
  if not (AReason in ['0'..'3']) then
    AReason := '0';
  if not (AStopCode in ['0', '1']) then
    AStopCode := '0';
  Result := 'E' + AReason + AStopCode;
end;

function DxpBuildMovePacket(const AMove: string; ATotalTimeUsedSeconds: Integer): string;
var
  CaptureCount: Integer;
  I: Integer;
  MoveText: string;
  Squares: TStringList;
begin
  Result := '';
  MoveText := NormalizeMoveNotation(AMove);
  Squares := TStringList.Create;
  try
    ExtractMoveSquares(MoveText, Squares);
    if Squares.Count < 2 then
      Exit;

    if Pos('x', LowerCase(MoveText)) > 0 then
      CaptureCount := Squares.Count - 2
    else
      CaptureCount := 0;

    Result := 'M' + Dxp4(ATotalTimeUsedSeconds) +
      Dxp2(StrToIntDef(Squares[0], 0)) +
      Dxp2(StrToIntDef(Squares[1], 0)) + Dxp2(CaptureCount);
    for I := 2 to Squares.Count - 1 do
      Result += Dxp2(StrToIntDef(Squares[I], 0));
  finally
    Squares.Free;
  end;
end;

function DxpMoveMessageToText(const AMessage: string; out AMoveText: string): Boolean;
var
  CaptureCount: Integer;
  FromSquare: Integer;
  I: Integer;
  Offset: Integer;
  ToSquare: Integer;
begin
  Result := False;
  AMoveText := '';
  if (Length(AMessage) < 11) or (AMessage[1] <> 'M') then
    Exit;

  FromSquare := StrToIntDef(Copy(AMessage, 6, 2), 0);
  ToSquare := StrToIntDef(Copy(AMessage, 8, 2), 0);
  CaptureCount := StrToIntDef(Copy(AMessage, 10, 2), -1);
  if (FromSquare < 1) or (FromSquare > 50) or
    (ToSquare < 1) or (ToSquare > 50) or (CaptureCount < 0) then
    Exit;
  if Length(AMessage) < 11 + 2 * CaptureCount then
    Exit;

  if CaptureCount = 0 then
    AMoveText := IntToStr(FromSquare) + '-' + IntToStr(ToSquare)
  else
  begin
    AMoveText := IntToStr(FromSquare) + 'x' + IntToStr(ToSquare);
    Offset := 12;
    for I := 1 to CaptureCount do
    begin
      AMoveText += 'x' + IntToStr(StrToIntDef(Copy(AMessage, Offset, 2), 0));
      Inc(Offset, 2);
    end;
  end;

  AMoveText := NormalizeMoveNotation(AMoveText);
  Result := True;
end;

end.
