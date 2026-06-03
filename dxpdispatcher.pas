unit DxpDispatcher;

{$mode objfpc}{$H+}

interface

type
  TDxpReceivedPacketKind = (drpUnknown, drpGameAcc, drpMove, drpGameEnd);

  TDxpReceivedPacket = record
    Kind: TDxpReceivedPacketKind;
    MoveText: String;
    MoveParseOk: Boolean;
    GameEndCode: Char;
  end;

function DispatchDxpMessage(const AMessage: String): TDxpReceivedPacket;

implementation

uses
  DxpProtocol;

function DispatchDxpMessage(const AMessage: String): TDxpReceivedPacket;
begin
  Result.Kind := drpUnknown;
  Result.MoveText := '';
  Result.MoveParseOk := False;
  Result.GameEndCode := #0;

  if AMessage = '' then
    Exit;

  case AMessage[1] of
    'A':
      Result.Kind := drpGameAcc;
    'M':
    begin
      Result.Kind := drpMove;
      Result.MoveParseOk := DxpMoveMessageToText(AMessage, Result.MoveText);
    end;
    'E':
    begin
      Result.Kind := drpGameEnd;
      if Length(AMessage) >= 2 then
        Result.GameEndCode := AMessage[2];
    end;
  end;
end;

end.
