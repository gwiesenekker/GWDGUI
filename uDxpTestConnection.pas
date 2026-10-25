unit uDxpTestConnection;

{$mode objfpc}{$H+}

interface

uses
  Classes, SyncObjs, ssockets, uEngineRegistry;

type
  TDxpTestLogEvent = procedure(Sender: TObject; const AText: string) of object;

  TDxpTestConnectionThread = class(TThread)
  private
    FLock: TCriticalSection;
    FDxpHost: string;
    FDxpPort: Word;
    FLogText: string;
    FOnLog: TDxpTestLogEvent;
    FRole: TDxpEngineRole;
    FServer: TInetServer;
    FSocket: TSocketStream;
    procedure AcceptConnection(Sender: TObject; Data: TSocketStream);
    procedure DeliverLog;
    procedure Log(const AText: string);
    procedure WakeListener;
  protected
    procedure Execute; override;
  public
    constructor Create(const AHost: string; APort: Word; ARole: TDxpEngineRole;
      AOnLog: TDxpTestLogEvent);
    destructor Destroy; override;
    procedure StopConnection;
  end;

implementation

uses
  SysUtils;

constructor TDxpTestConnectionThread.Create(const AHost: string; APort: Word;
  ARole: TDxpEngineRole; AOnLog: TDxpTestLogEvent);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FLock := TCriticalSection.Create;
  FDxpHost := AHost;
  if Trim(FDxpHost) = '' then FDxpHost := '127.0.0.1';
  FDxpPort := APort;
  FRole := ARole;
  FOnLog := AOnLog;
  FServer := nil;
  FSocket := nil;
  Start;
end;

destructor TDxpTestConnectionThread.Destroy;
begin
  StopConnection;
  WaitFor;
  FSocket.Free;
  FLock.Free;
  inherited Destroy;
end;

procedure TDxpTestConnectionThread.AcceptConnection(Sender: TObject;
  Data: TSocketStream);
begin
  FSocket := Data;
  if FServer <> nil then
    FServer.StopAccepting(False);
end;

procedure TDxpTestConnectionThread.DeliverLog;
begin
  if Assigned(FOnLog) then
    FOnLog(Self, FLogText);
end;

procedure TDxpTestConnectionThread.Log(const AText: string);
begin
  FLogText := AText;
  Synchronize(@DeliverLog);
end;

procedure TDxpTestConnectionThread.WakeListener;
var
  Socket: TInetSocket;
begin
  if FRole <> derListen then
    Exit;
  Socket := nil;
  try
    if FDxpHost = '0.0.0.0' then Socket := TInetSocket.Create('127.0.0.1', FDxpPort, 100)
    else Socket := TInetSocket.Create(FDxpHost, FDxpPort, 100);
  except
    on E: Exception do
      ;
  end;
  Socket.Free;
end;

procedure TDxpTestConnectionThread.Execute;
var
  Attempt: Integer;
  InetSocket: TInetSocket;
begin
  try
    if FRole = derListen then
    begin
      Log('[DXP listening on ' + FDxpHost + ':' + IntToStr(FDxpPort) + ']');
      FLock.Acquire;
      try FServer := TInetServer.Create(FDxpHost, FDxpPort);
      finally FLock.Release; end;
      try
        FServer.ReuseAddress := True;
        FServer.MaxConnections := 1;
        FServer.OnConnect := @AcceptConnection;
        FServer.Listen;
        if not Terminated then FServer.StartAccepting;
      finally
        FLock.Acquire;
        try FreeAndNil(FServer);
        finally FLock.Release; end;
      end;
      if Terminated then
        Exit;
      if FSocket <> nil then
        Log('[DXP socket connected]')
      else
        Log('[DXP listener stopped without connection]');
    end
    else
    begin
      Log('[DXP connecting to ' + FDxpHost + ':' + IntToStr(FDxpPort) + ']');
      for Attempt := 1 to 120 do
      begin
        if Terminated then
          Exit;
        try
          InetSocket := TInetSocket.Create(FDxpHost, FDxpPort, 1000);
          try
            FSocket := InetSocket;
            InetSocket := nil;
            Log('[DXP socket connected after attempt ' + IntToStr(Attempt) + ']');
            Break;
          finally
            InetSocket.Free;
          end;
        except
          on E: Exception do
          begin
            if (Attempt = 1) or (Attempt mod 10 = 0) then
              Log('[DXP connect attempt ' + IntToStr(Attempt) + ' failed: ' +
                E.Message + ']');
            Sleep(250);
          end;
        end;
      end;
      if (not Terminated) and (FSocket = nil) then
        Log('[DXP connect failed]');
    end;

    while (not Terminated) and (FSocket <> nil) do
      Sleep(100);
  except
    on E: Exception do
      if not Terminated then
        Log('[DXP socket error: ' + E.Message + ']');
  end;
end;

procedure TDxpTestConnectionThread.StopConnection;
begin
  Terminate;
  FLock.Acquire;
  try
    if FServer <> nil then FServer.StopAccepting(False);
  finally FLock.Release; end;
  WakeListener;
end;

end.
