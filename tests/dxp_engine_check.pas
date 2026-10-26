program dxp_engine_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, sockets, ssockets, uSocketSafety,
  uDraughtsBoard, uDxpEngine, uDxpTestConnection, uEngineRegistry, uGameOrchestrator;

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
    if Reason = 'C' then
      Exit; // Crash/disconnect immediately after accepting the game.
    if Reason = 'O' then
    begin
      Text := 'M00001333022919' + #0;
      Stream.WriteBuffer(Text[1], Length(Text));
      Text := ReadPacket(Stream);
      Check((Text <> '') and (Text[1] = 'M'), 'reordered captures must allow the next opponent move');
      Text := 'M0000051000' + #0; Stream.WriteBuffer(Text[1], Length(Text));
      Text := ReadPacket(Stream);
      Check((Text <> '') and (Text[1] = 'E'), 'ordered-history fixture must shut down normally');
      Text := 'E00' + #0; Stream.WriteBuffer(Text[1], Length(Text));
      Exit;
    end;
    if Reason = 'S' then
    begin
      Text := ReadPacket(Stream); // Silent until the GUI ends the timed-out game.
      Check((Text <> '') and (Text[1] = 'E'), 'timeout must send GAMEEND');
      Text := 'E00' + #0;
      Stream.WriteBuffer(Text[1], Length(Text));
      Exit;
    end;
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

procedure CheckLoopbackBinding;
var Listener: TDxpAcceptThread; Port: Word; Wrong, Right: TInetSocket; Tick: QWord;
begin
  Port := AvailablePort;
  Listener := TDxpAcceptThread.Create(Port);
  Wrong := nil;
  Right := nil;
  try
    Tick := GetTickCount64;
    while not Listener.Listening and (GetTickCount64 - Tick < 2000) do Sleep(5);
    Check(Listener.Listening, 'binding fixture must listen');
    try Wrong := TInetSocket.Create('127.0.0.2', Port, 100); except on E: Exception do ; end;
    Check(Wrong = nil, 'default DXP listener must not accept connections on other interfaces');
    Right := TInetSocket.Create('127.0.0.1', Port, 1000);
  finally
    Right.Free;
    Wrong.Free;
    Listener.StopAccepting;
    Listener.WaitFor;
    Listener.Free;
  end;
end;

procedure CheckNamedListenerAndPeerRestriction;
var Listener: TDxpAcceptThread; Port: Word; Client: TInetSocket; Tick: QWord;
begin
  Check(DxpListenAddress('localhost') = '127.0.0.1', 'localhost resolves before binding');
  Check(not DxpPeerAllowed('127.0.0.1', '', '192.0.2.1'), 'loopback listener rejects nonlocal peer');
  Port := AvailablePort; Listener := TDxpAcceptThread.Create(Port, 'localhost', '127.0.0.2');
  Client := nil;
  try
    Tick := GetTickCount64;
    while not Listener.Listening and (GetTickCount64 - Tick < 2000) do Sleep(5);
    Check(Listener.Listening, 'localhost listener starts');
    try
      Client := TInetSocket.Create('127.0.0.2', Port, 100);
      Check(False, 'localhost must not become a wildcard binding');
    except on E: ESocketError do ; end;
    Client := TInetSocket.Create('127.0.0.1', Port, 1000);
    Sleep(100);
    Check(not Listener.SocketAvailable, 'configured unexpected peer must not be accepted');
    Check(Listener.Listening, 'rejected peer must not stop accepting');
  finally Client.Free; Listener.Free; end;
  Listener := TDxpAcceptThread.Create(AvailablePort, 'invalid address!');
  try
    Listener.WaitFor;
    Check((not Listener.Listening) and (Pos('IPv4', Listener.ErrorMessage) > 0),
      'invalid listener address must fail rather than bind all interfaces');
  finally Listener.Free; end;
end;

type TConnectionLog = class
  Connected, Rejected: Boolean;
  Error: string;
  procedure Log(Sender: TObject; const Text: string);
end;
procedure TConnectionLog.Log(Sender: TObject; const Text: string);
begin
  if Pos('socket connected', Text) > 0 then Connected := True;
  if Pos('rejected peer', Text) > 0 then Rejected := True;
  if Pos('socket error', Text) > 0 then Error := Text;
end;
procedure CheckRegistrationPeerRestriction;
var Observer: TConnectionLog; Test: TDxpTestConnectionThread; Client: TInetSocket;
  Port: Word; Tick: QWord; Mode: Integer; Peer: string;
begin
  for Mode := 0 to 1 do
  begin
    Observer := TConnectionLog.Create; Client := nil; Port := AvailablePort;
    if Mode = 0 then Peer := '127.0.0.2' else Peer := '127.0.0.1';
    Test := TDxpTestConnectionThread.Create('localhost', Port, derListen, @Observer.Log, Peer);
    try
      Tick := GetTickCount64;
      repeat
        CheckSynchronize(1);
        try Client := TInetSocket.Create('127.0.0.1', Port, 100);
        except on E: ESocketError do ; end;
        Check(Observer.Error = '', Observer.Error);
      until (Client <> nil) or (GetTickCount64 - Tick > 3000);
      Check(Client <> nil, 'registration test binds localhost and accepts a TCP attempt');
      Tick := GetTickCount64;
      repeat CheckSynchronize(5);
      until Observer.Connected or Observer.Rejected or (GetTickCount64 - Tick > 3000);
      Check((Observer.Connected = (Mode = 1)) and (Observer.Rejected = (Mode = 0)),
        'registration test honors the configured peer restriction');
    finally Client.Free; Test.Free; Observer.Free; end;
  end;
end;

procedure CheckListenerShutdownRaces;
var I: Integer; Listener: TDxpAcceptThread; Test: TDxpTestConnectionThread;
begin
  for I := 1 to 20 do
  begin
    Listener := TDxpAcceptThread.Create(AvailablePort);
    Listener.Free;
    Test := TDxpTestConnectionThread.Create('127.0.0.1', AvailablePort, derListen, nil);
    Test.Free;
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

procedure CheckDisconnectedPeerFailsPromptly;
var
  Definition: TExternalEngineDefinition;
  Game: TGameOrchestrator;
  Engine: TDxpEngine;
  Port: Word;
  Tick: QWord;
  Raised: Boolean;
begin
  Port := AvailablePort;
  Definition := TExternalEngineDefinition.Create;
  Game := TGameOrchestrator.Create;
  try
    Definition.Kind := eekDxp;
    Definition.DxpId := 'Disconnected DXP';
    Definition.DxpRole := derListen;
    Definition.DxpHost := '127.0.0.1';
    Definition.DxpPort := Port;
    Definition.ExePath := ExpandFileName(ParamStr(0));
    Definition.Arguments := '--peer ' + IntToStr(Port) + ' C';
    Engine := TDxpEngine.Create(Definition);
    Game.Engine[dsWhite] := Engine;
    Check(Engine.LaunchAndInit, 'disconnecting peer should initialize');
    Game.NewGame(DefaultStartingFEN);
    Tick := GetTickCount64;
    Raised := False;
    try
      Game.PlayNextMove;
    except
      on E: EInvalidOperation do
        Raised := Pos('disconnected', E.Message) > 0;
    end;
    Check(Raised, 'EOF must report a disconnected engine instead of no data');
    Check(GetTickCount64 - Tick < 2000, 'EOF detection must not wait a move timeout');
    Check((Game.State = gosError) and (Game.MoveHistory.Count = 0),
      'disconnect must report an error without accepting a move');
  finally
    Game.Free; // Shutdown must also tolerate the dead peer.
    Definition.Free;
  end;
end;

procedure CheckUnorderedCaptureHistory;
var Definition: TExternalEngineDefinition; Game: TGameOrchestrator;
  Engine: TDxpEngine; Port: Word;
begin
  Port := AvailablePort; Definition := TExternalEngineDefinition.Create;
  Game := TGameOrchestrator.Create;
  try
    Definition.Kind := eekDxp; Definition.DxpId := 'Capture-order DXP';
    Definition.DxpRole := derListen; Definition.DxpHost := '127.0.0.1'; Definition.DxpPort := Port;
    Definition.ExePath := ExpandFileName(ParamStr(0));
    Definition.Arguments := '--peer ' + IntToStr(Port) + ' O';
    Engine := TDxpEngine.Create(Definition); Game.Engine[dsBlack] := Engine;
    Check(Engine.LaunchAndInit, 'capture-order peer initializes');
    Game.NewGame('B:W19,29,45,46:B13,5');
    Check(Game.PlayNextMove <> '', 'reordered capture is accepted');
    Check(Game.MovesPlayedText = '13x33x19x29', 'orchestrator stores the canonical capture');
    Game.PlayMove('46-41', dsWhite, 0, 'human');
    Check(Game.PlayNextMove = '5-10', 'next DXP turn survives a reordered capture set');
    Check(Game.State = gosRunning, 'reordered capture history must not end the game');
  finally Game.Free; Definition.Free; end;
end;

procedure CheckSilentPeerLosesOnTime;
var
  Definition: TExternalEngineDefinition;
  Game: TGameOrchestrator;
  Engine: TDxpEngine;
  Clock: TTimeControl;
  Port: Word;
  Tick: QWord;
begin
  Port := AvailablePort;
  Definition := TExternalEngineDefinition.Create;
  Game := TGameOrchestrator.Create;
  try
    Definition.Kind := eekDxp;
    Definition.DxpId := 'Silent DXP';
    Definition.DxpRole := derListen;
    Definition.DxpHost := '127.0.0.1';
    Definition.DxpPort := Port;
    Definition.ExePath := ExpandFileName(ParamStr(0));
    Definition.Arguments := '--peer ' + IntToStr(Port) + ' S';
    Engine := TDxpEngine.Create(Definition);
    Game.Engine[dsWhite] := Engine;
    Check(Engine.LaunchAndInit, 'silent peer should initialize');
    Clock := DefaultTimeControl;
    Clock.MinutesPerPeriod := 0.002;
    Game.TimeControl := Clock;
    Game.NewGame(DefaultStartingFEN);
    Tick := GetTickCount64;
    Check(Game.PlayNextMove = '', 'timed-out DXP search must not return a move');
    Check(GetTickCount64 - Tick < 2000, 'DXP deadline must follow the short clock');
    Check(Engine.MoveTimedOut, 'DXP adapter must report its expired deadline');
    Check((Game.State = gosGameOver) and (Game.GameResult = '0-2') and
      (Game.MoveHistory.Count = 0), 'DXP timeout must be scored as a loss on time');
    Check(Pos('send; packet=DXP_GAMEEND', Engine.StateLog.Text) > 0,
      'DXP timeout must stop the peer session');
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
  CheckLoopbackBinding;
  CheckNamedListenerAndPeerRestriction;
  CheckListenerShutdownRaces;
  CheckRegistrationPeerRestriction;
  CheckGameEndClaim('1', dsWhite, '0-2');
  CheckGameEndClaim('1', dsBlack, '2-0');
  CheckDisconnectedPeerFailsPromptly;
  CheckUnorderedCaptureHistory;
  CheckSilentPeerLosesOnTime;
  WriteLn('OK');
end.
