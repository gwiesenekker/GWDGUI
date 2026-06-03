unit DxpProtocol;

{$mode objfpc}{$H+}

interface

uses
  DraughtsRules;

function DxpBuildGameReqPacket(const ABoard: TBoard; ASideToMove,
  AEngineSide: TSide; AGameMinutes: Double; AGameMoves: Integer;
  const ANameText: String): String;
function DxpBuildGameEndPacket(ACode: Char): String;
function DxpBuildMovePacket(const AMove: TMove;
  ATotalTimeUsedSeconds: Integer): String;
function DxpMoveMessageToText(const AMessage: String;
  out AMoveText: String): Boolean;
function DxpGameEndCodeForResult(const AGameResult: String;
  AEngineSide: TSide): Char;
function DxpResultFromGameEndCode(ACode: Char; AEngineSide: TSide): String;

implementation

uses
  SysUtils;

function Dxp2(AValue: Integer): String;
begin
  if AValue < 0 then
    AValue := 0;
  if AValue > 99 then
    AValue := 99;
  Result := Format('%.2d', [AValue]);
end;

function Dxp3(AValue: Integer): String;
begin
  if AValue < 0 then
    AValue := 0;
  if AValue > 999 then
    AValue := 999;
  Result := Format('%.3d', [AValue]);
end;

function Dxp4(AValue: Integer): String;
begin
  if AValue < 0 then
    AValue := 0;
  if AValue > 9999 then
    AValue := 9999;
  Result := Format('%.4d', [AValue]);
end;

function DxpBuildGameReqPacket(const ABoard: TBoard; ASideToMove,
  AEngineSide: TSide; AGameMinutes: Double; AGameMoves: Integer;
  const ANameText: String): String;
var
  BoardText: String;
  EngineColourText: Char;
  GameTime: Integer;
  I: Integer;
  NameText: String;
  PieceText: Char;
  SideText: Char;
begin
  NameText := ANameText;
  if Length(NameText) > 32 then
    SetLength(NameText, 32);
  while Length(NameText) < 32 do
    NameText += ' ';

  if AEngineSide = sideWhite then
    EngineColourText := 'W'
  else
    EngineColourText := 'Z';

  GameTime := Round(AGameMinutes);
  if GameTime <= 0 then
    GameTime := 1;

  if ASideToMove = sideWhite then
    SideText := 'W'
  else
    SideText := 'Z';

  BoardText := '';
  for I := Low(ABoard) to High(ABoard) do
  begin
    case ABoard[I] of
      pcWhiteMan: PieceText := 'w';
      pcWhiteKing: PieceText := 'W';
      pcBlackMan: PieceText := 'z';
      pcBlackKing: PieceText := 'Z';
    else
      PieceText := 'e';
    end;
    BoardText += PieceText;
  end;

  Result := 'R' + '01' + NameText + EngineColourText + Dxp3(GameTime) +
    Dxp3(AGameMoves) + 'B' + SideText + BoardText + #0;
end;

function DxpBuildGameEndPacket(ACode: Char): String;
begin
  if not (ACode in ['0'..'3']) then
    ACode := '0';
  Result := 'E' + ACode + '0' + #0;
end;

function DxpBuildMovePacket(const AMove: TMove;
  ATotalTimeUsedSeconds: Integer): String;
var
  I: Integer;
begin
  Result := '';
  if Length(AMove.Squares) < 2 then
    Exit;

  Result := 'M' + Dxp4(ATotalTimeUsedSeconds) + Dxp2(AMove.Squares[0]) +
    Dxp2(AMove.Squares[High(AMove.Squares)]) + Dxp2(Length(AMove.Captures));
  for I := 0 to High(AMove.Captures) do
    Result += Dxp2(AMove.Captures[I]);
  Result += #0;
end;

function DxpMoveMessageToText(const AMessage: String;
  out AMoveText: String): Boolean;
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

  Result := True;
end;

function DxpGameEndCodeForResult(const AGameResult: String;
  AEngineSide: TSide): Char;
begin
  Result := '0';

  if (AGameResult = '1-1') or (AGameResult = '1/2-1/2') then
    Exit('2');
  if AGameResult = '*' then
    Exit('0');

  if ((AEngineSide = sideWhite) and (AGameResult = '2-0')) or
    ((AEngineSide = sideBlack) and (AGameResult = '0-2')) then
    Result := '1'
  else if ((AEngineSide = sideWhite) and (AGameResult = '0-2')) or
    ((AEngineSide = sideBlack) and (AGameResult = '2-0')) then
    Result := '3';
end;

function DxpResultFromGameEndCode(ACode: Char; AEngineSide: TSide): String;
begin
  Result := '*';

  if ACode = '2' then
    Exit('1-1');
  if ACode = '0' then
    Exit('*');

  case ACode of
    '1':
      if AEngineSide = sideWhite then
        Result := '0-2'
      else
        Result := '2-0';
    '3':
      if AEngineSide = sideWhite then
        Result := '2-0'
      else
        Result := '0-2';
  end;
end;

end.
