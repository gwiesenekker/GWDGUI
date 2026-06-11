unit uDxpEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, sockets, ssockets,
  {$IFDEF MSWINDOWS}
  Windows,
  {$ENDIF}
  SyncObjs, SysUtils,
  {$IFDEF UNIX}
  BaseUnix,
  {$ENDIF}
  uDraughtsBoard, uDxpProtocol, uEngineBase, uEngineParamsJson,
  uEngineRegistry, uPlatformProcess, uThreadMessageQueue;

type
  TDxpAcceptThread = class(TThread)
  private
    FErrorMessage: string;
    FLock: TCriticalSection;
    FListening: Boolean;
    FPort: Word;
    FServer: TInetServer;
    FSocket: TSocketStream;
    procedure AcceptConnection(Sender: TObject; Data: TSocketStream);
    function GetErrorMessage: string;
    function GetListening: Boolean;
    function GetSocketAvailable: Boolean;
    procedure WakeListener;
  protected
    procedure Execute; override;
  public
    constructor Create(APort: Word);
    destructor Destroy; override;
    function DetachSocket: TSocketStream;
    procedure StopAccepting;
    property ErrorMessage: string read GetErrorMessage;
    property Listening: Boolean read GetListening;
    property SocketAvailable: Boolean read GetSocketAvailable;
  end;

  TDxpEngine = class(TDraughtsEngine)
  private
    FAcceptThread: TDxpAcceptThread;
    FBoard: TDraughtsBoard;
    FBuffer: string;
    FEngine: TExternalEngineDefinition;
    FEngineSide: TDraughtsSide;
    FGameMoves: Integer;
    FGameMinutes: Double;
    FGameStarted: Boolean;
    FLastMovesText: string;
    FProcess: TPlatformProcess;
    FReceivedLines: TStringList;
    FSentMoveCount: Integer;
    FSocket: TSocketStream;
    FSocketLock: TCriticalSection;
    FStopping: Boolean;
    FTotalUsedSeconds: Double;
    FWorker: TThread;
    FWorkerQueue: TThreadMessageQueue;
    FWorkerThreadId: TThreadID;
    procedure AcknowledgeGameEnd(AStopCode: Char);
    procedure CloseSocket;
    function ConnectSocket(ATimeoutMs: Integer): Boolean;
    function CurrentSide: TDraughtsSide;
    procedure DoBeginGame(const AStartingFEN: string; ASide: TDraughtsSide;
      AGameMinutes: Double; AGameMoves: Integer);
    function DoLaunchAndInit: Boolean;
    procedure DoRequestStop;
    procedure DoSetClockInfo(AMovesRemaining: Integer; ARemainingSeconds,
      ATotalUsedSeconds: Double);
    procedure DoSetGamePosition(const AStartingFEN: string; AMoves: TStrings);
    procedure DoStop;
    procedure ExecuteWorkerCommand(ACommand: TObject);
    function IsWorkerThread: Boolean;
    function LastMoveText: string;
    function LaunchProcess: Boolean;
    function LocalSocketOpen(out AStatus: string): Boolean;
    procedure ProcessData(Sender: TObject; const AText: string);
    procedure QueueProcessData(const AText: string);
    function QueueBoolCommand(ACommand: TObject): Boolean;
    procedure QueueProcedureCommand(ACommand: TObject);
    function QueueStringCommand(ACommand: TObject): string;
    function ReadDxpPacket(ATimeoutMs: Integer; out APacket: string;
      AIgnoreStopping: Boolean = False): Boolean;
    procedure SendPacket(const APacketName, APacketText: string);
    function TranslateGameEndResult(AReason: Char): string;
    function StartListening(ATimeoutMs: Integer): Boolean;
    procedure StopListening;
    function WaitForGameAccepted(ATimeoutMs: Integer): Boolean;
    function WaitForDxpMove(ATimeoutMs: Integer): string;
    function WaitForGameEndAcknowledgement(ATimeoutMs: Integer): Boolean;
    procedure WaitForWorkerCommand(ACommand: TThreadMessage;
      ACompleted: TSimpleEvent; const AErrorText: string);
  protected
    function DoStartThinking: string; override;
  public
    constructor Create(AEngine: TExternalEngineDefinition); reintroduce;
    destructor Destroy; override;
    procedure BeginGame(const AStartingFEN: string; ASide: TDraughtsSide;
      AGameMinutes: Double; AGameMoves: Integer); override;
    function LaunchAndInit: Boolean;
    procedure RequestStop; override;
    procedure SetClockInfo(AMovesRemaining: Integer; ARemainingSeconds,
      ATotalUsedSeconds: Double); override;
    procedure SetGamePosition(const AStartingFEN: string; AMoves: TStrings); override;
    function StartThinking: string; override;
    procedure Stop; override;
  end;

implementation

{$IFDEF UNIX}
const
  LocalFdCloseOnExec = 1;
{$ENDIF}

procedure SetHandleCloseOnExec(AHandle: Longint);
{$IFDEF UNIX}
var
  Flags: cint;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  if AHandle < 0 then
    Exit;
  SetHandleInformation(THandle(AHandle), HANDLE_FLAG_INHERIT, 0);
  {$ENDIF}
  {$IFDEF UNIX}
  if AHandle < 0 then
    Exit;
  Flags := fpfcntl(AHandle, F_GETFD);
  if Flags <> -1 then
    fpfcntl(AHandle, F_SETFD, Flags or LocalFdCloseOnExec);
  {$ENDIF}
end;

procedure SetSocketCloseOnExec(ASocket: TSocketStream);
begin
  if ASocket <> nil then
    SetHandleCloseOnExec(ASocket.Handle);
end;

type
  TDxpWorkerCommandKind = (
    dwcLaunchAndInit,
    dwcBeginGame,
    dwcSetGamePosition,
    dwcSetClockInfo,
    dwcStartThinking,
    dwcProcessData,
    dwcStop
  );

  TDxpWorkerCommand = class(TThreadMessage)
  private
    FBoolResult: Boolean;
    FCommandKind: TDxpWorkerCommandKind;
    FCompleted: TSimpleEvent;
    FErrorMessage: string;
    FGameMinutes: Double;
    FGameMoves: Integer;
    FMoves: TStringList;
    FMovesRemaining: Integer;
    FRemainingSeconds: Double;
    FSide: TDraughtsSide;
    FStartingFEN: string;
    FStringResult: string;
    FTextValue: string;
    FTotalUsedSeconds: Double;
  public
    constructor Create(AKind: TDxpWorkerCommandKind); reintroduce;
    destructor Destroy; override;
    procedure SignalCompleted;
    property BoolResult: Boolean read FBoolResult write FBoolResult;
    property CommandKind: TDxpWorkerCommandKind read FCommandKind;
    property Completed: TSimpleEvent read FCompleted;
    property ErrorMessage: string read FErrorMessage write FErrorMessage;
    property GameMinutes: Double read FGameMinutes write FGameMinutes;
    property GameMoves: Integer read FGameMoves write FGameMoves;
    property Moves: TStringList read FMoves;
    property MovesRemaining: Integer read FMovesRemaining write FMovesRemaining;
    property RemainingSeconds: Double read FRemainingSeconds write FRemainingSeconds;
    property Side: TDraughtsSide read FSide write FSide;
    property StartingFEN: string read FStartingFEN write FStartingFEN;
    property StringResult: string read FStringResult write FStringResult;
    property TextValue: string read FTextValue write FTextValue;
    property TotalUsedSeconds: Double read FTotalUsedSeconds write FTotalUsedSeconds;
  end;

  TDxpWorkerThread = class(TThread)
  private
    FOwner: TDxpEngine;
    FQueue: TThreadMessageQueue;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TDxpEngine; AQueue: TThreadMessageQueue);
  end;

const
  DxpLaunchListenTimeoutMs = 5000;
  DxpLaunchSocketTimeoutMs = 120000;
  DxpGameAcceptedTimeoutMs = 10000;
  DxpMoveTimeoutMs = 60000;
  DxpWorkerWaitPollMs = 1000;
  DxpWorkerWaitLogMs = 10000;

constructor TDxpWorkerCommand.Create(AKind: TDxpWorkerCommandKind);
const
  CommandNames: array[TDxpWorkerCommandKind] of string = (
    'dxp-launch-and-init',
    'dxp-begin-game',
    'dxp-set-game-position',
    'dxp-set-clock-info',
    'dxp-start-thinking',
    'dxp-process-data',
    'dxp-stop'
  );
begin
  inherited Create(CommandNames[AKind]);
  FCommandKind := AKind;
  FMoves := TStringList.Create;
  FCompleted := TSimpleEvent.Create;
end;

destructor TDxpWorkerCommand.Destroy;
begin
  FCompleted.Free;
  FMoves.Free;
  inherited Destroy;
end;

procedure TDxpWorkerCommand.SignalCompleted;
begin
  FCompleted.SetEvent;
end;

constructor TDxpWorkerThread.Create(AOwner: TDxpEngine; AQueue: TThreadMessageQueue);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FQueue := AQueue;
  Start;
end;

procedure TDxpWorkerThread.Execute;
var
  CommandObject: TObject;
  DxpCommand: TDxpWorkerCommand;
  AutoFreeCommand: Boolean;
begin
  FOwner.FWorkerThreadId := System.ThreadID;
  try
    while (not Terminated) and FQueue.WaitPop(CommandObject) do
    begin
      if not (CommandObject is TDxpWorkerCommand) then
        Continue;
      DxpCommand := TDxpWorkerCommand(CommandObject);
      AutoFreeCommand := DxpCommand.CommandKind = dwcProcessData;
      try
        FOwner.ExecuteWorkerCommand(DxpCommand);
      except
        on E: Exception do
          DxpCommand.ErrorMessage := E.Message;
      end;
      DxpCommand.SignalCompleted;
      if AutoFreeCommand then
        DxpCommand.Free;
    end;
  finally
    FOwner.FWorkerThreadId := 0;
  end;
end;

function TcpAddressPortHex(const AAddress: string): string;
var
  P: SizeInt;
begin
  Result := '';
  P := Pos(':', AAddress);
  if P > 0 then
    Result := UpperCase(Copy(AAddress, P + 1, MaxInt));
end;

function TcpTokenAt(const ALine: string; AIndex: Integer): string;
var
  I: Integer;
  InToken: Boolean;
  Token: string;
  TokenIndex: Integer;
begin
  Result := '';
  Token := '';
  TokenIndex := -1;
  InToken := False;
  for I := 1 to Length(ALine) do
  begin
    if ALine[I] in [#9, ' '] then
    begin
      if InToken then
      begin
        if TokenIndex = AIndex then
          Exit(Token);
        Token := '';
        InToken := False;
      end;
      Continue;
    end;

    if not InToken then
    begin
      InToken := True;
      Inc(TokenIndex);
    end;
    Token += ALine[I];
  end;

  if InToken and (TokenIndex = AIndex) then
    Result := Token;
end;

function TcpTimeWaitCountInFile(const AFileName: string; APort: Word): Integer;
var
  I: Integer;
  Lines: TStringList;
  LocalAddress: string;
  PortHex: string;
  RemoteAddress: string;
  StateText: string;
begin
  Result := 0;
  if not FileExists(AFileName) then
    Exit;

  PortHex := UpperCase(IntToHex(APort, 4));
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(AFileName);
    for I := 1 to Lines.Count - 1 do
    begin
      LocalAddress := TcpTokenAt(Trim(Lines[I]), 1);
      RemoteAddress := TcpTokenAt(Trim(Lines[I]), 2);
      StateText := TcpTokenAt(Trim(Lines[I]), 3);
      if StateText <> '06' then
        Continue;
      if (TcpAddressPortHex(LocalAddress) = PortHex) or
        (TcpAddressPortHex(RemoteAddress) = PortHex) then
        Inc(Result);
    end;
  finally
    Lines.Free;
  end;
end;

function TcpTimeWaitCountForPort(APort: Word): Integer;
begin
  Result := 0;
  {$IFDEF Linux}
  Result := TcpTimeWaitCountInFile('/proc/net/tcp', APort) +
    TcpTimeWaitCountInFile('/proc/net/tcp6', APort);
  {$ENDIF}
end;

constructor TDxpAcceptThread.Create(APort: Word);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FLock := TCriticalSection.Create;
  FPort := APort;
  Start;
end;

destructor TDxpAcceptThread.Destroy;
begin
  StopAccepting;
  FLock.Acquire;
  try
    FreeAndNil(FSocket);
  finally
    FLock.Release;
  end;
  FLock.Free;
  inherited Destroy;
end;

procedure TDxpAcceptThread.AcceptConnection(Sender: TObject; Data: TSocketStream);
begin
  SetSocketCloseOnExec(Data);
  FLock.Acquire;
  try
    FSocket := Data;
  finally
    FLock.Release;
  end;
  if FServer <> nil then
    FServer.StopAccepting(False);
end;

function TDxpAcceptThread.GetErrorMessage: string;
begin
  FLock.Acquire;
  try
    Result := FErrorMessage;
  finally
    FLock.Release;
  end;
end;

function TDxpAcceptThread.GetListening: Boolean;
begin
  FLock.Acquire;
  try
    Result := FListening;
  finally
    FLock.Release;
  end;
end;

function TDxpAcceptThread.GetSocketAvailable: Boolean;
begin
  FLock.Acquire;
  try
    Result := FSocket <> nil;
  finally
    FLock.Release;
  end;
end;

procedure TDxpAcceptThread.WakeListener;
var
  LocalSocket: TInetSocket;
begin
  if not Listening then
    Exit;

  LocalSocket := nil;
  try
    LocalSocket := TInetSocket.Create('127.0.0.1', FPort, 100);
  except
    on E: Exception do
      ;
  end;
  LocalSocket.Free;
end;

procedure TDxpAcceptThread.StopAccepting;
begin
  Terminate;
  if FServer <> nil then
    FServer.StopAccepting(False);
  WakeListener;
end;

function TDxpAcceptThread.DetachSocket: TSocketStream;
begin
  FLock.Acquire;
  try
    Result := FSocket;
    FSocket := nil;
  finally
    FLock.Release;
  end;
end;

procedure TDxpAcceptThread.Execute;
begin
  try
    FServer := TInetServer.Create('0.0.0.0', FPort);
    SetHandleCloseOnExec(FServer.Socket);
    try
      FServer.ReuseAddress := True;
      FServer.MaxConnections := 1;
      FServer.OnConnect := @AcceptConnection;
      FServer.Listen;
      FLock.Acquire;
      try
        FListening := True;
      finally
        FLock.Release;
      end;
      FServer.StartAccepting;
    finally
      FLock.Acquire;
      try
        FListening := False;
      finally
        FLock.Release;
      end;
      FreeAndNil(FServer);
    end;
  except
    on E: Exception do
    begin
      FLock.Acquire;
      try
        FErrorMessage := E.Message;
      finally
        FLock.Release;
      end;
    end;
  end;
end;

constructor TDxpEngine.Create(AEngine: TExternalEngineDefinition);
begin
  inherited Create(EnginePickerDisplayName(AEngine, 0));
  FEngine := TExternalEngineDefinition.Create;
  FEngine.Assign(AEngine);
  EngineName := FEngine.IdText;
  if EngineName = '' then
    EngineName := ChangeFileExt(FEngine.ExecutableName, '');
  FBoard := TDraughtsBoard.Create;
  FProcess := TPlatformProcess.Create;
  FProcess.SynchronizeData := False;
  FProcess.OnData := @ProcessData;
  FReceivedLines := TStringList.Create;
  FSocketLock := TCriticalSection.Create;
  FWorkerQueue := TThreadMessageQueue.Create(False);
  FWorker := TDxpWorkerThread.Create(Self, FWorkerQueue);
  FGameMinutes := 5;
  FGameMoves := 75;
  ChangeState(esWaiting, 'DXP adapter created');
end;

destructor TDxpEngine.Destroy;
begin
  Stop;
  if FWorkerQueue <> nil then
    FWorkerQueue.Close;
  if FWorker <> nil then
  begin
    FWorker.Terminate;
    FWorker.WaitFor;
  end;
  FWorker.Free;
  FWorkerQueue.Free;
  FReceivedLines.Free;
  FAcceptThread.Free;
  FSocketLock.Free;
  FProcess.Free;
  FBoard.Free;
  FEngine.Free;
  inherited Destroy;
end;

procedure TDxpEngine.ProcessData(Sender: TObject; const AText: string);
var
  DelimiterLength: Integer;
  Line: string;
  LineEnd: Integer;
begin
  if not IsWorkerThread then
  begin
    QueueProcessData(AText);
    Exit;
  end;

  Log('stdout; text=' + StringReplace(AText, LineEnding, '\n', [rfReplaceAll]));
  FBuffer += AText;
  while True do
  begin
    DelimiterLength := Length(LineEnding);
    LineEnd := Pos(LineEnding, FBuffer);
    if LineEnd = 0 then
    begin
      LineEnd := Pos(#10, FBuffer);
      DelimiterLength := 1;
    end;
    if LineEnd = 0 then
      Break;

    Line := Trim(Copy(FBuffer, 1, LineEnd - 1));
    Delete(FBuffer, 1, LineEnd + DelimiterLength - 1);
    if Line <> '' then
      FReceivedLines.Add(Line);
  end;
end;

procedure TDxpEngine.WaitForWorkerCommand(ACommand: TThreadMessage;
  ACompleted: TSimpleEvent; const AErrorText: string);
var
  ElapsedMs: QWord;
  LastLogTick: QWord;
  StartTick: QWord;
  WaitResult: TWaitResult;
begin
  StartTick := GetTickCount64;
  LastLogTick := StartTick;
  repeat
    WaitResult := ACompleted.WaitFor(DxpWorkerWaitPollMs);
    if WaitResult = wrSignaled then
      Exit;
    if WaitResult = wrError then
      raise ESyncObjectException.Create(AErrorText);

    if GetTickCount64 - LastLogTick >= DxpWorkerWaitLogMs then
    begin
      ElapsedMs := GetTickCount64 - StartTick;
      Log('worker command still waiting; command=' + ACommand.Kind +
        '; elapsed_ms=' + IntToStr(ElapsedMs) +
        '; queue_count=' + IntToStr(FWorkerQueue.Count));
      LastLogTick := GetTickCount64;
    end;
  until False;
end;

function TDxpEngine.QueueBoolCommand(ACommand: TObject): Boolean;
var
  DxpCommand: TDxpWorkerCommand;
begin
  Result := False;
  if not (ACommand is TDxpWorkerCommand) then
    Exit;
  DxpCommand := TDxpWorkerCommand(ACommand);
  try
    if IsWorkerThread then
    begin
      ExecuteWorkerCommand(DxpCommand);
      Result := DxpCommand.BoolResult;
      Exit;
    end;
    if (FWorkerQueue = nil) or (not FWorkerQueue.TryPost(DxpCommand)) then
      raise EInvalidOperation.Create('DXP worker queue is closed');
    WaitForWorkerCommand(DxpCommand, DxpCommand.Completed,
      'DXP worker command wait failed');
    if DxpCommand.ErrorMessage <> '' then
      raise EInvalidOperation.Create(DxpCommand.ErrorMessage);
    Result := DxpCommand.BoolResult;
  finally
    DxpCommand.Free;
  end;
end;

procedure TDxpEngine.QueueProcedureCommand(ACommand: TObject);
var
  DxpCommand: TDxpWorkerCommand;
begin
  if not (ACommand is TDxpWorkerCommand) then
    Exit;
  DxpCommand := TDxpWorkerCommand(ACommand);
  try
    if IsWorkerThread then
    begin
      ExecuteWorkerCommand(DxpCommand);
      Exit;
    end;
    if (FWorkerQueue = nil) or (not FWorkerQueue.TryPost(DxpCommand)) then
      raise EInvalidOperation.Create('DXP worker queue is closed');
    WaitForWorkerCommand(DxpCommand, DxpCommand.Completed,
      'DXP worker command wait failed');
    if DxpCommand.ErrorMessage <> '' then
      raise EInvalidOperation.Create(DxpCommand.ErrorMessage);
  finally
    DxpCommand.Free;
  end;
end;

procedure TDxpEngine.QueueProcessData(const AText: string);
var
  DxpCommand: TDxpWorkerCommand;
begin
  if AText = '' then
    Exit;
  DxpCommand := TDxpWorkerCommand.Create(dwcProcessData);
  DxpCommand.TextValue := AText;
  if (FWorkerQueue = nil) or (not FWorkerQueue.TryPost(DxpCommand)) then
    DxpCommand.Free;
end;

function TDxpEngine.QueueStringCommand(ACommand: TObject): string;
var
  DxpCommand: TDxpWorkerCommand;
begin
  Result := '';
  if not (ACommand is TDxpWorkerCommand) then
    Exit;
  DxpCommand := TDxpWorkerCommand(ACommand);
  try
    if IsWorkerThread then
    begin
      ExecuteWorkerCommand(DxpCommand);
      Result := DxpCommand.StringResult;
      Exit;
    end;
    if (FWorkerQueue = nil) or (not FWorkerQueue.TryPost(DxpCommand)) then
      raise EInvalidOperation.Create('DXP worker queue is closed');
    WaitForWorkerCommand(DxpCommand, DxpCommand.Completed,
      'DXP worker command wait failed');
    if DxpCommand.ErrorMessage <> '' then
      raise EInvalidOperation.Create(DxpCommand.ErrorMessage);
    Result := DxpCommand.StringResult;
  finally
    DxpCommand.Free;
  end;
end;

procedure TDxpEngine.ExecuteWorkerCommand(ACommand: TObject);
var
  DxpCommand: TDxpWorkerCommand;
begin
  if not (ACommand is TDxpWorkerCommand) then
    Exit;
  DxpCommand := TDxpWorkerCommand(ACommand);
  case DxpCommand.CommandKind of
    dwcLaunchAndInit:
      DxpCommand.BoolResult := DoLaunchAndInit;
    dwcBeginGame:
      DoBeginGame(DxpCommand.StartingFEN, DxpCommand.Side,
        DxpCommand.GameMinutes, DxpCommand.GameMoves);
    dwcSetGamePosition:
      DoSetGamePosition(DxpCommand.StartingFEN, DxpCommand.Moves);
    dwcSetClockInfo:
      DoSetClockInfo(DxpCommand.MovesRemaining, DxpCommand.RemainingSeconds,
        DxpCommand.TotalUsedSeconds);
    dwcStartThinking:
      DxpCommand.StringResult := inherited StartThinking;
    dwcProcessData:
      ProcessData(nil, DxpCommand.TextValue);
    dwcStop:
      DoStop;
  end;
end;

function TDxpEngine.IsWorkerThread: Boolean;
begin
  Result := (FWorkerThreadId <> 0) and (System.ThreadID = FWorkerThreadId);
end;

procedure TDxpEngine.AcknowledgeGameEnd(AStopCode: Char);
begin
  if not (AStopCode in ['0', '1']) then
    AStopCode := '0';
  try
    SendPacket('DXP_GAMEEND', DxpBuildGameEndPacketWithStopCode('0', AStopCode));
    Log('DXP_GAMEEND acknowledged; stop_code=' + AStopCode);
  except
    on E: Exception do
      Log('DXP_GAMEEND acknowledge failed; message=' + E.Message);
  end;
end;

procedure TDxpEngine.CloseSocket;
begin
  StopListening;
  FSocketLock.Acquire;
  try
    FreeAndNil(FSocket);
  finally
    FSocketLock.Release;
  end;
end;

function TDxpEngine.LaunchProcess: Boolean;
var
  Args: TStringList;
  Params: TEngineParamArray;
begin
  Result := False;
  Params := nil;
  Args := TStringList.Create;
  try
    SplitLaunchArguments(ExpandEnginePlaceholders(FEngine.Arguments, FEngine), Args);
    LoadEngineParamsFromJson(EngineParamsFileName(FEngine.ExePath), 'dxp',
      Params);
    FEngine.IniFileName := EngineParamValue(Params, 'gui-ini-file',
      FEngine.IniFileName);
    FEngine.IniContent := EngineParamValue(Params, 'gui-ini-content',
      FEngine.IniContent);
    WriteEngineIniFile(FEngine.IniFileName, FEngine.IniContent, FEngine);
    if Trim(FEngine.IniFileName) <> '' then
      Log('wrote expanded INI/config file; file=' + FEngine.IniFileName);
    Log('launch; executable=' + FEngine.ExePath);
    ChangeState(esLaunching, 'starting DXP process');
    FProcess.Start(FEngine.ExePath, Args, ExtractFilePath(FEngine.ExePath));
    Result := True;
  finally
    Args.Free;
  end;
end;

function TDxpEngine.LocalSocketOpen(out AStatus: string): Boolean;
var
  Err: Integer;
  ErrLen: TSockLen;
  HandleText: string;
begin
  Result := False;
  AStatus := 'socket=nil';

  FSocketLock.Acquire;
  try
    if FSocket = nil then
      Exit;

    HandleText := IntToStr(FSocket.Handle);
    Err := 0;
    ErrLen := SizeOf(Err);
    if fpGetSockOpt(FSocket.Handle, SOL_SOCKET, SO_ERROR, @Err, @ErrLen) <> 0 then
    begin
      AStatus := 'socket_handle=' + HandleText + '; getsockopt_failed=' +
        IntToStr(SocketError);
      Exit;
    end;

    AStatus := 'socket_handle=' + HandleText + '; so_error=' + IntToStr(Err);
    Result := Err = 0;
  finally
    FSocketLock.Release;
  end;
end;

procedure TDxpEngine.StopListening;
begin
  if FAcceptThread = nil then
    Exit;

  FAcceptThread.StopAccepting;
  FAcceptThread.WaitFor;
  FreeAndNil(FAcceptThread);
end;

function TDxpEngine.StartListening(ATimeoutMs: Integer): Boolean;
var
  StartTick: QWord;
begin
  Result := False;
  StopListening;
  Log('DXP listen; host=0.0.0.0; port=' + IntToStr(FEngine.DxpPort));
  FAcceptThread := TDxpAcceptThread.Create(FEngine.DxpPort);
  StartTick := GetTickCount64;
  repeat
    if FStopping or StopRequested then
      Exit(False);
    if FAcceptThread.Listening then
    begin
      Log('DXP listener ready');
      Exit(True);
    end;
    if FAcceptThread.ErrorMessage <> '' then
    begin
      Log('DXP listen failed; message=' + FAcceptThread.ErrorMessage);
      Exit(False);
    end;
    Sleep(10);
  until GetTickCount64 - StartTick >= QWord(ATimeoutMs);
  Log('DXP listen failed; message=listener startup timeout');
end;

function TDxpEngine.ConnectSocket(ATimeoutMs: Integer): Boolean;
var
  Attempt: Integer;
  InetSocket: TInetSocket;
  StartTick: QWord;
begin
  Result := False;
  StartTick := GetTickCount64;

  if FEngine.DxpRole = derListen then
  begin
    repeat
      if FStopping or StopRequested then
        Exit(False);
      if FProcess.NeedsPolling then
        FProcess.ReadAvailable;
      if FProcess.HasProcess and (not FProcess.IsRunning) then
      begin
        Log('DXP accept failed; message=process exited before socket connected');
        Exit(False);
      end;
      if (FAcceptThread <> nil) and FAcceptThread.SocketAvailable then
      begin
        FSocket := FAcceptThread.DetachSocket;
        StopListening;
        Log('DXP socket accepted');
        Exit(True);
      end;
      if (FAcceptThread <> nil) and (FAcceptThread.ErrorMessage <> '') then
      begin
        Log('DXP accept failed; message=' + FAcceptThread.ErrorMessage);
        Exit(False);
      end;
      Sleep(50);
    until GetTickCount64 - StartTick >= QWord(ATimeoutMs);
    Exit;
  end;

  Log('DXP connect; host=' + FEngine.DxpHost + '; port=' + IntToStr(FEngine.DxpPort));
  Attempt := 0;
  repeat
    Inc(Attempt);
    if FStopping or StopRequested then
      Exit(False);
    if FProcess.NeedsPolling then
      FProcess.ReadAvailable;
    if FProcess.HasProcess and (not FProcess.IsRunning) then
    begin
      Log('DXP connect failed; message=process exited before socket connected');
      Exit(False);
    end;
    try
      InetSocket := TInetSocket.Create(FEngine.DxpHost, FEngine.DxpPort, 1000);
      SetSocketCloseOnExec(InetSocket);
      FSocket := InetSocket;
      if FProcess.NeedsPolling then
        FProcess.ReadAvailable;
      Log('DXP socket connected; attempt=' + IntToStr(Attempt));
      Exit(True);
    except
      on E: Exception do
      begin
        if (Attempt = 1) or ((Attempt mod 10) = 0) then
          Log('DXP connect attempt failed; attempt=' + IntToStr(Attempt) +
            '; message=' + E.Message);
        if FProcess.NeedsPolling then
          FProcess.ReadAvailable;
        Sleep(250);
      end;
    end;
  until GetTickCount64 - StartTick >= QWord(ATimeoutMs);
end;

function TDxpEngine.DoLaunchAndInit: Boolean;
var
  TimeWaitCount: Integer;
begin
  Result := False;
  FStopping := False;
  CloseSocket;
  TimeWaitCount := TcpTimeWaitCountForPort(FEngine.DxpPort);
  if TimeWaitCount > 0 then
    Log('DXP port check; port=' + IntToStr(FEngine.DxpPort) +
      '; time_wait_count=' + IntToStr(TimeWaitCount) +
      '; launch may need SO_REUSEADDR or a retry delay')
  else
    Log('DXP port check; port=' + IntToStr(FEngine.DxpPort) +
      '; time_wait_count=0');
  if FEngine.DxpRole = derListen then
  begin
    if not StartListening(DxpLaunchListenTimeoutMs) then
    begin
      DoStop;
      Exit;
    end;
    if not LaunchProcess then
    begin
      DoStop;
      Exit;
    end;
    ChangeState(esInitializing, 'process launched; waiting for DXP socket');
    Result := ConnectSocket(DxpLaunchSocketTimeoutMs);
  end
  else
  begin
    if not LaunchProcess then
    begin
      DoStop;
      Exit;
    end;
    ChangeState(esInitializing, 'process launched; connecting DXP socket');
    Result := ConnectSocket(DxpLaunchSocketTimeoutMs);
  end;

  if Result then
  begin
    Log('DXP launch check passed; socket connected');
    ChangeState(esReady, 'DXP ready');
  end
  else
  begin
    Log('DXP launch check failed; socket not connected');
    ChangeState(esError, 'DXP socket timeout');
    DoStop;
  end;
end;

function TDxpEngine.CurrentSide: TDraughtsSide;
begin
  Result := FBoard.SideToMove;
end;

function TDxpEngine.LastMoveText: string;
begin
  Result := '';
  if MovesPlayed.Count > 0 then
    Result := MovesPlayed[MovesPlayed.Count - 1];
end;

function TDxpEngine.TranslateGameEndResult(AReason: Char): string;
begin
  case AReason of
    '1':
      begin
        if FEngineSide = dsWhite then
          Result := '0-2'
        else
          Result := '2-0';
      end;
    '2':
      Result := '1-1';
    '3':
      begin
        if FEngineSide = dsWhite then
          Result := '2-0'
        else
          Result := '0-2';
      end;
  else
    Result := '*';
  end;
end;

procedure TDxpEngine.DoSetClockInfo(AMovesRemaining: Integer; ARemainingSeconds,
  ATotalUsedSeconds: Double);
begin
  FGameMoves := AMovesRemaining;
  FGameMinutes := ARemainingSeconds / 60;
  FTotalUsedSeconds := ATotalUsedSeconds;
  Log('clock stored; moves_remaining=' + IntToStr(AMovesRemaining) +
    '; remaining_seconds=' + FloatToStr(ARemainingSeconds) +
    '; total_used_seconds=' + FloatToStr(ATotalUsedSeconds));
end;

procedure TDxpEngine.DoSetGamePosition(const AStartingFEN: string; AMoves: TStrings);
var
  I: Integer;
begin
  inherited SetGamePosition(AStartingFEN, AMoves);
  FLastMovesText := '';
  FBoard.LoadFromFEN(StartingFEN);
  for I := 0 to MovesPlayed.Count - 1 do
  begin
    FBoard.PlayMove(MovesPlayed[I], False);
    if FLastMovesText <> '' then
      FLastMovesText += ' ';
    FLastMovesText += MovesPlayed[I];
  end;
end;

procedure TDxpEngine.SendPacket(const APacketName, APacketText: string);
var
  LWireText: string;
begin
  FSocketLock.Acquire;
  try
    if (FSocket = nil) or (APacketText = '') then
      raise EInvalidOperation.Create('DXP socket is not connected');

    Log('send; packet=' + APacketName + '; bytes=' + IntToStr(Length(APacketText)) +
      '; message=' + APacketText);
    LWireText := APacketText + #0;
    FSocket.WriteBuffer(LWireText[1], Length(LWireText));
  finally
    FSocketLock.Release;
  end;
end;

function TDxpEngine.ReadDxpPacket(ATimeoutMs: Integer; out APacket: string;
  AIgnoreStopping: Boolean): Boolean;
var
  BytesRead: Longint;
  Ch: Char;
  StartTick: QWord;
begin
  Result := False;
  APacket := '';

  FSocketLock.Acquire;
  try
    if FSocket = nil then
      Exit;
    FSocket.IOTimeout := 250;
  finally
    FSocketLock.Release;
  end;

  StartTick := GetTickCount64;
  repeat
    if (FStopping or StopRequested) and (not AIgnoreStopping) then
      Exit(False);
    if FProcess.NeedsPolling then
      FProcess.ReadAvailable;
    Ch := #0;
    try
      FSocketLock.Acquire;
      try
        if FSocket = nil then
          Exit(False);
        BytesRead := FSocket.Read(Ch, 1);
      finally
        FSocketLock.Release;
      end;
    except
      on E: Exception do
      begin
        Sleep(10);
        Continue;
      end;
    end;

    if BytesRead > 0 then
    begin
      if Ch = #0 then
      begin
        Log('receive; packet=' + APacket);
        Exit(True);
      end;
      APacket += Ch;
    end
    else
      Sleep(10);
  until GetTickCount64 - StartTick >= QWord(ATimeoutMs);
end;

function TDxpEngine.WaitForDxpMove(ATimeoutMs: Integer): string;
var
  MoveText: string;
  Packet: string;
  Reason: Char;
  StopCode: Char;
begin
  Result := '';
  while ReadDxpPacket(ATimeoutMs, Packet) do
  begin
    if Packet = '' then
      Continue;
    case Packet[1] of
      'A':
        Log('DXP_GAMEACC received');
      'M':
        begin
          if DxpMoveMessageToText(Packet, MoveText) then
            Exit(MoveText);
          raise EConvertError.Create('Could not parse DXP_MOVE packet');
        end;
      'E':
        begin
          Reason := '0';
          StopCode := '0';
          if Length(Packet) >= 2 then
            Reason := Packet[2];
          if Length(Packet) >= 3 then
            StopCode := Packet[3];
          SetGameResult(TranslateGameEndResult(Reason));
          Log('DXP_GAMEEND received; reason=' + Reason + '; stop_code=' +
            StopCode + '; result=' + GameResult);
          try
            AcknowledgeGameEnd(StopCode);
          finally
            FGameStarted := False;
          end;
          Exit('');
        end;
    else
      Log('ignored DXP packet; packet=' + Packet);
    end;
  end;
  Log('DXP wait timeout; expected=DXP_MOVE or DXP_GAMEEND; timeout_ms=' +
    IntToStr(ATimeoutMs));
end;

function TDxpEngine.WaitForGameEndAcknowledgement(ATimeoutMs: Integer): Boolean;
var
  Packet: string;
begin
  Result := False;
  if ReadDxpPacket(ATimeoutMs, Packet, True) and (Packet <> '') then
  begin
    if Packet[1] = 'E' then
    begin
      Log('DXP_GAMEEND acknowledgement received; message=' + Packet);
      Exit(True);
    end;
    Log('ignored DXP packet while waiting for GAMEEND acknowledgement; packet=' +
      Packet);
  end;
  Log('DXP wait timeout; expected=DXP_GAMEEND acknowledgement; timeout_ms=' +
    IntToStr(ATimeoutMs));
end;

function TDxpEngine.WaitForGameAccepted(ATimeoutMs: Integer): Boolean;
var
  Packet: string;
  StopCode: Char;
begin
  Result := False;
  while ReadDxpPacket(ATimeoutMs, Packet) do
  begin
    if Packet = '' then
      Continue;
    case Packet[1] of
      'A':
        begin
          if (Length(Packet) >= 34) and (Packet[34] = '0') then
          begin
            Log('DXP_GAMEACC accepted');
            Exit(True);
          end;
          if Length(Packet) >= 34 then
            Log('DXP_GAMEACC rejected; code=' + Packet[34])
          else
            Log('DXP_GAMEACC rejected; malformed packet=' + Packet);
          Exit(False);
        end;
      'E':
        begin
          StopCode := '0';
          if Length(Packet) >= 3 then
            StopCode := Packet[3];
          Log('DXP_GAMEEND received while waiting for GAMEACC; stop_code=' +
            StopCode);
          try
            AcknowledgeGameEnd(StopCode);
          finally
            FGameStarted := False;
          end;
          Exit(False);
        end;
    else
      Log('ignored DXP packet while waiting for GAMEACC; packet=' + Packet);
    end;
  end;
  Log('DXP wait timeout; expected=DXP_GAMEACC; timeout_ms=' +
    IntToStr(ATimeoutMs));
end;

procedure TDxpEngine.DoBeginGame(const AStartingFEN: string; ASide: TDraughtsSide;
  AGameMinutes: Double; AGameMoves: Integer);
var
  GameReq: string;
begin
  inherited BeginGame(AStartingFEN, ASide, AGameMinutes, AGameMoves);
  FEngineSide := ASide;
  FBoard.LoadFromFEN(StartingFEN);
  FGameMinutes := AGameMinutes;
  FGameMoves := AGameMoves;
  FGameStarted := False;
  FSentMoveCount := 0;
  FTotalUsedSeconds := 0;

  if FSocket = nil then
    raise EInvalidOperation.Create('DXP socket is not connected');

  GameReq := DxpBuildGameReqPacket(FBoard, ASide, FGameMinutes,
    FGameMoves, 'International Draughts GUI');
  SendPacket('DXP_GAMEREQ', GameReq);
  FGameStarted := True;
  ChangeState(esWaitingForDone, 'waiting for DXP_GAMEACC');
  if not WaitForGameAccepted(DxpGameAcceptedTimeoutMs) then
  begin
    ChangeState(esError, 'timeout waiting for DXP_GAMEACC');
    raise EInvalidOperation.Create('DXP engine did not accept the game');
  end;
  ChangeState(esReady, 'DXP game accepted');
end;

procedure TDxpEngine.DoRequestStop;
begin
  { Keep teardown on the DXP worker thread.  RequestStop can be called from
    the runner/orchestrator while the worker is still polling FAcceptThread. }
  FStopping := True;
end;

procedure TDxpEngine.RequestStop;
begin
  DoRequestStop;
end;

function TDxpEngine.DoStartThinking: string;
var
  GameReq: string;
  MovePacket: string;
begin
  if FSocket = nil then
    raise EInvalidOperation.Create('DXP socket is not connected');

  if not FGameStarted then
  begin
    GameReq := DxpBuildGameReqPacket(FBoard, CurrentSide, FGameMinutes,
      FGameMoves, 'International Draughts GUI');
    SendPacket('DXP_GAMEREQ', GameReq);
    FGameStarted := True;
    FSentMoveCount := MovesPlayed.Count;
  end
  else if MovesPlayed.Count > FSentMoveCount then
  begin
    MovePacket := DxpBuildMovePacket(LastMoveText, 0);
    SendPacket('DXP_MOVE', MovePacket);
    FSentMoveCount := MovesPlayed.Count;
  end;

  ChangeState(esWaitingForDone, 'waiting for DXP_MOVE');
  Result := WaitForDxpMove(DxpMoveTimeoutMs);
end;

procedure TDxpEngine.DoStop;
var
  SocketStatus: string;
begin
  inherited Stop;
  LocalSocketOpen(SocketStatus);
  Log('DXP socket status before stop; ' + SocketStatus);
  if FGameStarted and LocalSocketOpen(SocketStatus) then
  begin
    try
      SendPacket('DXP_GAMEEND', DxpBuildGameEndPacket('0'));
      FStopping := True;
      WaitForGameEndAcknowledgement(1000);
    except
      on E: Exception do
        Log('DXP_GAMEEND failed; message=' + E.Message);
    end;
  end;
  FStopping := True;
  LocalSocketOpen(SocketStatus);
  Log('DXP socket status before close; ' + SocketStatus);
  CloseSocket;
  LocalSocketOpen(SocketStatus);
  Log('DXP socket status after close; ' + SocketStatus);
  FGameStarted := False;
  if FProcess.IsRunning then
    FProcess.Terminate(1000);
  FProcess.Close;
end;

procedure TDxpEngine.BeginGame(const AStartingFEN: string; ASide: TDraughtsSide;
  AGameMinutes: Double; AGameMoves: Integer);
var
  Command: TDxpWorkerCommand;
begin
  Command := TDxpWorkerCommand.Create(dwcBeginGame);
  Command.StartingFEN := AStartingFEN;
  Command.Side := ASide;
  Command.GameMinutes := AGameMinutes;
  Command.GameMoves := AGameMoves;
  QueueProcedureCommand(Command);
end;

function TDxpEngine.LaunchAndInit: Boolean;
begin
  Result := QueueBoolCommand(TDxpWorkerCommand.Create(dwcLaunchAndInit));
end;

procedure TDxpEngine.SetClockInfo(AMovesRemaining: Integer; ARemainingSeconds,
  ATotalUsedSeconds: Double);
var
  Command: TDxpWorkerCommand;
begin
  Command := TDxpWorkerCommand.Create(dwcSetClockInfo);
  Command.MovesRemaining := AMovesRemaining;
  Command.RemainingSeconds := ARemainingSeconds;
  Command.TotalUsedSeconds := ATotalUsedSeconds;
  QueueProcedureCommand(Command);
end;

procedure TDxpEngine.SetGamePosition(const AStartingFEN: string; AMoves: TStrings);
var
  Command: TDxpWorkerCommand;
begin
  Command := TDxpWorkerCommand.Create(dwcSetGamePosition);
  Command.StartingFEN := AStartingFEN;
  if AMoves <> nil then
    Command.Moves.Assign(AMoves);
  QueueProcedureCommand(Command);
end;

function TDxpEngine.StartThinking: string;
begin
  Result := QueueStringCommand(TDxpWorkerCommand.Create(dwcStartThinking));
end;

procedure TDxpEngine.Stop;
begin
  DoRequestStop;
  if (FWorkerQueue = nil) or (FWorkerQueue.IsClosed) then
    DoStop
  else
    QueueProcedureCommand(TDxpWorkerCommand.Create(dwcStop));
end;

end.
