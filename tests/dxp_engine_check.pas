program dxp_engine_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, sockets, ssockets, uSocketSafety,
  uDraughtsBoard, uDxpEngine, uEngineRegistry, uGameOrchestrator;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

function ReadPacket(Stream: TSocketStream): string;
var
  Ch: Char;
begin
  Result := '';
  repeat
    Stream.ReadBuffer(Ch, 1);
    if Ch = #0 then
      Exit;
    Result += Ch;
  until Length(Result) > 512;
  raise Exception.Create('oversized fake peer packet');
end;

procedure FakePeer(Port: Word; Reason: Char);
var
  Stream: TInetSocket;
  Text: string;
begin
  Stream := TInetSocket.Create('127.0.0.1', Port, 3000);
  try
    SuppressSocketSigPipe(Stream);
    Stream.IOTimeout := 5000;
    Text := ReadPacket(Stream);
    Check((Text <> '') and (Text[1] = 'R'), 'peer should receive GAMEREQ');
    Text := 'A' + StringOfChar(' ', 32) + '0' + #0;
    Stream.WriteBuffer(Text[1], Length(Text));
    Text := 'E' + Reason + '0' + #0;
    Stream.WriteBuffer(Text[1], Length(Text));
    Text := ReadPacket(Stream);
    Check((Text <> '') and (Text[1] = 'E'), 'GUI should acknowledge GAMEEND');
  finally
    Stream.Free;
  end;
end;

function AvailablePort: Word;
var
  Server: TInetServer;
  Address: TInetSockAddr;
  AddressSize: TSockLen;
begin
  Server := TInetServer.Create('127.0.0.1', 0);
  try
    Server.Listen;
    AddressSize := SizeOf(Address);
    Check(fpGetSockName(Server.Socket, @Address, @AddressSize) = 0,
      'could not obtain temporary regression port');
    Result := ntohs(Address.sin_port);
  finally
    Server.Free;
  end;
end;

procedure CheckGameEndClaim(Reason: Char; Side: TDraughtsSide;
  const ExpectedResult: string);
var
  Definition: TExternalEngineDefinition;
  Engine: TDxpEngine;
  Game: TGameOrchestrator;
  Port: Word;
  Fen: string;
begin
  Port := AvailablePort;
  Definition := TExternalEngineDefinition.Create;
  Game := TGameOrchestrator.Create;
  try
    Definition.Kind := eekDxp;
    Definition.DxpId := 'Regression DXP';
    Definition.DxpRole := derListen;
    Definition.DxpHost := '127.0.0.1';
    Definition.DxpPort := Port;
    Definition.ExePath := ExpandFileName(ParamStr(0));
    Definition.Arguments := '--peer ' + IntToStr(Port) + ' ' + Reason;
    Engine := TDxpEngine.Create(Definition);
    Game.Engine[Side] := Engine;
    Check(Engine.LaunchAndInit, 'fake DXP peer should initialize');
    Fen := DefaultStartingFEN;
    if Side = dsBlack then
      Fen[1] := 'B';
    Game.NewGame(Fen);
    Check(Game.Board.LegalMoveCount > 0, 'claim fixture must be nonterminal');
    Check(Game.PlayNextMove = '', 'GAMEEND should not manufacture a move');
    Check(Game.GameResult = ExpectedResult,
      'unverified peer claim must not decide the result: reason=' + Reason);
    Check((Game.MoveHistory.Count = 0) and (Game.Board.LegalMoveCount > 0),
      'GAMEEND must leave the nonterminal board and move history unchanged');
    Check(Pos('reason=' + Reason, Engine.StateLog.Text) > 0,
      'peer claim must remain available in the engine log');
  finally
    Game.Free;
    Definition.Free;
  end;
end;

begin
  if ParamStr(1) = '--peer' then
  begin
    FakePeer(StrToInt(ParamStr(2)), ParamStr(3)[1]);
    Halt(0);
  end;
  CheckGameEndClaim('3', dsWhite, '*');
  CheckGameEndClaim('3', dsBlack, '*');
  CheckGameEndClaim('2', dsWhite, '*');
  CheckGameEndClaim('0', dsBlack, '*');
  CheckGameEndClaim('1', dsWhite, '0-2');
  CheckGameEndClaim('1', dsBlack, '2-0');
  WriteLn('OK');
end.
