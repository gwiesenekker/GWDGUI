unit DxpConnection;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  EngineConfig,
  ssockets;

type
  TDxpConnectionMessageEvent = procedure(AEngineIndex: Integer;
    const AMessage: String; AReceivedAtSeconds: Double) of object;
  TDxpConnectionConnectedEvent = procedure(AEngineIndex: Integer;
    ASocket: TSocketStream; ARole: TEngineDxpRole; const AIpAddress: String;
    APort: Word; AConnectAttemptCount, AConnectElapsedMs: QWord) of object;
  TDxpConnectionErrorEvent = procedure(AEngineIndex: Integer;
    const AMessage: String) of object;
  TDxpConnectionAttemptFailedEvent = procedure(AEngineIndex: Integer;
    const AIpAddress: String; APort: Word; const AMessage: String) of object;

  TEngineDxpConnectionThread = class(TThread)
  private
    FConnectAttemptCount: Integer;
    FConnectElapsedMs: QWord;
    FEngineIndex: Integer;
    FErrorMessage: String;
    FIncomingMessage: String;
    FIncomingMessageReceivedAtSeconds: Double;
    FIpAddress: String;
    FListening: Boolean;
    FOnConnectAttemptFailed: TDxpConnectionAttemptFailedEvent;
    FOnConnected: TDxpConnectionConnectedEvent;
    FOnError: TDxpConnectionErrorEvent;
    FOnMessage: TDxpConnectionMessageEvent;
    FPort: Word;
    FRole: TEngineDxpRole;
    FServer: TInetServer;
    FSocket: TSocketStream;
    procedure ServerConnect(Sender: TObject; Data: TSocketStream);
    procedure DeliverIncomingMessage;
    procedure NotifyListening;
    procedure NotifyConnected;
    procedure NotifyError;
    procedure NotifyConnectAttemptFailed;
    procedure ReadIncomingMessages;
  protected
    procedure Execute; override;
  public
    constructor Create(AEngineIndex: Integer; const AIpAddress: String;
      APort: Word; ARole: TEngineDxpRole;
      AOnMessage: TDxpConnectionMessageEvent;
      AOnConnected: TDxpConnectionConnectedEvent;
      AOnError: TDxpConnectionErrorEvent;
      AOnConnectAttemptFailed: TDxpConnectionAttemptFailedEvent);
    destructor Destroy; override;
    procedure StopConnection;
    property Listening: Boolean read FListening;
  end;

implementation

uses
  PlatformTime,
  SysUtils;

constructor TEngineDxpConnectionThread.Create(AEngineIndex: Integer;
  const AIpAddress: String; APort: Word; ARole: TEngineDxpRole;
  AOnMessage: TDxpConnectionMessageEvent;
  AOnConnected: TDxpConnectionConnectedEvent; AOnError: TDxpConnectionErrorEvent;
  AOnConnectAttemptFailed: TDxpConnectionAttemptFailedEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FEngineIndex := AEngineIndex;
  FIpAddress := AIpAddress;
  FPort := APort;
  FRole := ARole;
  FOnMessage := AOnMessage;
  FOnConnected := AOnConnected;
  FOnError := AOnError;
  FOnConnectAttemptFailed := AOnConnectAttemptFailed;
  FServer := nil;
  FSocket := nil;
  FListening := False;
  FIncomingMessage := '';
  FIncomingMessageReceivedAtSeconds := 0;
  FErrorMessage := '';
  Start;
end;

destructor TEngineDxpConnectionThread.Destroy;
begin
  StopConnection;
  inherited Destroy;
end;

procedure TEngineDxpConnectionThread.ServerConnect(Sender: TObject;
  Data: TSocketStream);
begin
  FSocket := Data;
  if FServer <> nil then
    FServer.StopAccepting(False);
end;

procedure TEngineDxpConnectionThread.DeliverIncomingMessage;
begin
  if Terminated then
    Exit;
  if Assigned(FOnMessage) then
    FOnMessage(FEngineIndex, FIncomingMessage,
      FIncomingMessageReceivedAtSeconds);
end;

procedure TEngineDxpConnectionThread.NotifyListening;
begin
  FListening := True;
end;

procedure TEngineDxpConnectionThread.NotifyConnected;
begin
  if Terminated then
    Exit;
  if Assigned(FOnConnected) then
    FOnConnected(FEngineIndex, FSocket, FRole, FIpAddress, FPort,
      FConnectAttemptCount, FConnectElapsedMs);
end;

procedure TEngineDxpConnectionThread.NotifyError;
begin
  if Terminated then
    Exit;
  if Assigned(FOnError) then
    FOnError(FEngineIndex, FErrorMessage);
end;

procedure TEngineDxpConnectionThread.NotifyConnectAttemptFailed;
begin
  if Terminated then
    Exit;
  if Assigned(FOnConnectAttemptFailed) then
    FOnConnectAttemptFailed(FEngineIndex, FIpAddress, FPort, FErrorMessage);
end;

procedure TEngineDxpConnectionThread.StopConnection;
begin
  Terminate;
  if FServer <> nil then
    FServer.StopAccepting(True);
end;

procedure TEngineDxpConnectionThread.ReadIncomingMessages;
var
  BytesRead: Longint;
  Ch: Char;
  MessageText: String;
begin
  if FSocket = nil then
    Exit;

  try
    FSocket.IOTimeout := 250;
  except
    on E: Exception do
      ;
  end;

  MessageText := '';
  while not Terminated do
  begin
    Ch := #0;
    try
      BytesRead := FSocket.Read(Ch, 1);
    except
      on E: Exception do
      begin
        if Terminated then
          Break;
        Sleep(10);
        Continue;
      end;
    end;
    if BytesRead = 0 then
      Break;
    if BytesRead < 0 then
    begin
      Sleep(10);
      Continue;
    end;

    if Ch = #0 then
    begin
      FIncomingMessage := MessageText;
      FIncomingMessageReceivedAtSeconds := PlatformTimestampSeconds;
      MessageText := '';
      Synchronize(@DeliverIncomingMessage);
    end
    else
      MessageText += Ch;
  end;
end;

procedure TEngineDxpConnectionThread.Execute;
var
  Attempt: Integer;
  Connected: Boolean;
  Socket: TInetSocket;
  StartTick: QWord;
begin
  try
    if FRole = edrClient then
    begin
      FServer := TInetServer.Create('0.0.0.0', FPort);
      try
        FServer.ReuseAddress := True;
        FServer.MaxConnections := 1;
        FServer.OnConnect := @ServerConnect;
        FServer.Listen;
        Synchronize(@NotifyListening);
        FServer.StartAccepting;
      finally
        FreeAndNil(FServer);
      end;
      if not Terminated then
      begin
        if FSocket <> nil then
          Synchronize(@NotifyConnected)
        else
        begin
          FErrorMessage := 'DXP listener stopped before accepting a connection';
          Synchronize(@NotifyError);
        end;
      end;
    end
    else
    begin
      Connected := False;
      FConnectAttemptCount := 0;
      FConnectElapsedMs := 0;
      StartTick := PlatformTimestampMilliseconds;
      for Attempt := 1 to DxpConnectAttempts do
      begin
        if Terminated then
          Exit;
        FConnectAttemptCount := Attempt;
        try
          Socket := TInetSocket.Create(FIpAddress, FPort,
            DxpConnectTimeoutMs);
          try
            FSocket := Socket;
            Socket := nil;
            Connected := True;
            FConnectElapsedMs := PlatformTimestampMilliseconds - StartTick;
            Break;
          finally
            Socket.Free;
          end;
        except
          on E: Exception do
          begin
            FErrorMessage := E.Message;
            if (Attempt = 1) or (Attempt mod 10 = 0) then
              Synchronize(@NotifyConnectAttemptFailed);
            Sleep(DxpConnectRetryDelayMs);
          end;
        end;
      end;
      if Terminated then
        Exit;
      if Connected then
        Synchronize(@NotifyConnected)
      else
      begin
        FErrorMessage := 'connect to DXP socket listener on IP ' +
          FIpAddress + ' and port ' + IntToStr(FPort) + ' failed after ' +
          IntToStr(DxpConnectAttempts) + ' attempts. Last error: ' +
          FErrorMessage;
        Synchronize(@NotifyError);
      end;
    end;
    if (not Terminated) and (FSocket <> nil) then
      ReadIncomingMessages;
  except
    on E: Exception do
    begin
      FErrorMessage := E.Message;
      if not Terminated then
        Synchronize(@NotifyError);
    end;
  end;
end;

end.
