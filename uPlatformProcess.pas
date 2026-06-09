unit uPlatformProcess;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process
  {$IFDEF MSWINDOWS}
  , Windows
  {$ENDIF}
  {$IFDEF UNIX}
  , BaseUnix
  {$ENDIF}
  ;

type
  TPlatformProcessDataEvent = procedure(Sender: TObject; const AText: string) of object;

  TPlatformProcess = class;

  {$IFDEF MSWINDOWS}
  TPlatformProcessReaderThread = class(TThread)
  private
    FChunk: string;
    FOwner: TPlatformProcess;
    FReadHandle: THandle;
    procedure DeliverChunk;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TPlatformProcess; AReadHandle: THandle);
  end;
  {$ENDIF}

  TPlatformProcess = class
  private
    FOnData: TPlatformProcessDataEvent;
    FSynchronizeData: Boolean;
    {$IFDEF MSWINDOWS}
    FInputWriteHandle: THandle;
    FOutputReadHandle: THandle;
    FProcessInfo: TProcessInformation;
    FReaderThread: TPlatformProcessReaderThread;
    FRunning: Boolean;
    procedure ClosePipeHandles(ACloseOutputHandle: Boolean);
    procedure CloseProcessInfoHandles;
    procedure StopReaderThread(AWaitForThread: Boolean);
    {$ELSE}
    FProcess: TProcess;
    {$ENDIF}
    procedure DeliverData(const AText: string);
  public
    constructor Create;
    destructor Destroy; override;
    function HasProcess: Boolean;
    function IsRunning: Boolean;
    function NeedsPolling: Boolean;
    procedure Start(const AFileName: string; ALaunchArgs: TStrings;
      const ACurrentDirectory: string);
    procedure WriteLine(const AText: string);
    procedure ReadAvailable;
    procedure RequestQuit(const AQuitCommand: string; AWaitMs: Integer);
    procedure Terminate(AWaitMs: Integer);
    procedure Close;
    property OnData: TPlatformProcessDataEvent read FOnData write FOnData;
    property SynchronizeData: Boolean read FSynchronizeData write FSynchronizeData;
  end;

implementation

function CommandLineQuote(const AText: string): string;
var
  I: Integer;
begin
  Result := '"';
  for I := 1 to Length(AText) do
    if AText[I] = '"' then
      Result += '\"'
    else
      Result += AText[I];
  Result += '"';
end;

{$IFDEF MSWINDOWS}
constructor TPlatformProcessReaderThread.Create(AOwner: TPlatformProcess;
  AReadHandle: THandle);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  FReadHandle := AReadHandle;
  Start;
end;

procedure TPlatformProcessReaderThread.DeliverChunk;
begin
  if (FOwner <> nil) and (FChunk <> '') then
    FOwner.DeliverData(FChunk);
end;

procedure TPlatformProcessReaderThread.Execute;
var
  Buffer: array[0..4095] of Byte;
  BytesRead: DWORD;
begin
  while (not Terminated) and (FReadHandle <> 0) do
  begin
    BytesRead := 0;
    if (not ReadFile(FReadHandle, Buffer[0], SizeOf(Buffer), BytesRead, nil)) or
      (BytesRead = 0) then
      Break;
    SetString(FChunk, PChar(@Buffer[0]), BytesRead);
    if (FOwner <> nil) and FOwner.SynchronizeData then
      Synchronize(@DeliverChunk)
    else
      DeliverChunk;
  end;
end;
{$ENDIF}

constructor TPlatformProcess.Create;
begin
  inherited Create;
  FSynchronizeData := True;
  {$IFDEF MSWINDOWS}
  FInputWriteHandle := 0;
  FOutputReadHandle := 0;
  FillChar(FProcessInfo, SizeOf(FProcessInfo), 0);
  FReaderThread := nil;
  FRunning := False;
  {$ELSE}
  FProcess := nil;
  {$ENDIF}
end;

destructor TPlatformProcess.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TPlatformProcess.HasProcess: Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result := FProcessInfo.hProcess <> 0;
  {$ELSE}
  Result := FProcess <> nil;
  {$ENDIF}
end;

function TPlatformProcess.IsRunning: Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result := FRunning and (FProcessInfo.hProcess <> 0) and
    (WaitForSingleObject(FProcessInfo.hProcess, 0) = WAIT_TIMEOUT);
  if not Result then
    FRunning := False;
  {$ELSE}
  Result := (FProcess <> nil) and FProcess.Running;
  {$ENDIF}
end;

function TPlatformProcess.NeedsPolling: Boolean;
begin
  Result := True;
end;

procedure TPlatformProcess.Start(const AFileName: string; ALaunchArgs: TStrings;
  const ACurrentDirectory: string);
{$IFDEF MSWINDOWS}
var
  Child2ParentRead: THandle;
  Child2ParentWrite: THandle;
  CommandLine: string;
  I: Integer;
  Parent2ChildRead: THandle;
  Parent2ChildWrite: THandle;
  Security: TSecurityAttributes;
  StartupInfo: TStartupInfo;
{$ELSE}
var
  I: Integer;
{$ENDIF}
begin
  Close;
  {$IFDEF MSWINDOWS}
  Parent2ChildRead := 0;
  Parent2ChildWrite := 0;
  Child2ParentRead := 0;
  Child2ParentWrite := 0;

  FillChar(Security, SizeOf(Security), 0);
  Security.nLength := SizeOf(Security);
  Security.bInheritHandle := True;
  if not CreatePipe(Parent2ChildRead, Parent2ChildWrite, @Security, 0) then
    RaiseLastOSError;
  if not SetHandleInformation(Parent2ChildWrite, HANDLE_FLAG_INHERIT, 0) then
    RaiseLastOSError;
  if not CreatePipe(Child2ParentRead, Child2ParentWrite, @Security, 0) then
    RaiseLastOSError;
  if not SetHandleInformation(Child2ParentRead, HANDLE_FLAG_INHERIT, 0) then
    RaiseLastOSError;

  FillChar(FProcessInfo, SizeOf(FProcessInfo), 0);
  FillChar(StartupInfo, SizeOf(StartupInfo), 0);
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.hStdError := Child2ParentWrite;
  StartupInfo.hStdInput := Parent2ChildRead;
  StartupInfo.hStdOutput := Child2ParentWrite;
  StartupInfo.dwFlags := STARTF_USESTDHANDLES;

  CommandLine := '"' + AFileName + '"';
  for I := 0 to ALaunchArgs.Count - 1 do
    CommandLine += ' ' + CommandLineQuote(ALaunchArgs[I]);

  try
    if not CreateProcess(nil, PChar(CommandLine), nil, nil, True,
      CREATE_NO_WINDOW, nil, PChar(ACurrentDirectory), StartupInfo,
      FProcessInfo) then
      RaiseLastOSError;
    CloseHandle(Parent2ChildRead);
    Parent2ChildRead := 0;
    CloseHandle(Child2ParentWrite);
    Child2ParentWrite := 0;
    FInputWriteHandle := Parent2ChildWrite;
    FOutputReadHandle := Child2ParentRead;
    FRunning := True;
  finally
    if Parent2ChildRead <> 0 then
      CloseHandle(Parent2ChildRead);
    if Child2ParentWrite <> 0 then
      CloseHandle(Child2ParentWrite);
  end;
  {$ELSE}
  FProcess := TProcess.Create(nil);
  FProcess.Executable := AFileName;
  for I := 0 to ALaunchArgs.Count - 1 do
    FProcess.Parameters.Add(ALaunchArgs[I]);
  FProcess.CurrentDirectory := ACurrentDirectory;
  FProcess.Options := [poUsePipes, poStderrToOutPut];
  FProcess.ShowWindow := swoHIDE;
  FProcess.Execute;
  {$ENDIF}
end;

procedure TPlatformProcess.WriteLine(const AText: string);
var
  CommandText: string;
  {$IFDEF MSWINDOWS}
  BytesWritten: DWORD;
  {$ENDIF}
begin
  if not IsRunning then
    Exit;
  CommandText := AText + LineEnding;
  if CommandText = '' then
    Exit;
  {$IFDEF MSWINDOWS}
  if (FInputWriteHandle <> 0) and
    (not WriteFile(FInputWriteHandle, CommandText[1], Length(CommandText),
      BytesWritten, nil)) then
    RaiseLastOSError;
  {$ELSE}
  FProcess.Input.WriteBuffer(CommandText[1], Length(CommandText));
  {$ENDIF}
end;

procedure TPlatformProcess.ReadAvailable;
var
  Buffer: array[0..4095] of Byte;
  Chunk: string;
  {$IFDEF MSWINDOWS}
  Available: DWORD;
  BytesReadWin: DWORD;
  {$ELSE}
  BytesRead: LongInt;
  {$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  if FOutputReadHandle = 0 then
    Exit;
  while True do
  begin
    Available := 0;
    if not PeekNamedPipe(FOutputReadHandle, nil, 0, nil, @Available, nil) then
      Break;
    if Available = 0 then
      Break;
    BytesReadWin := 0;
    if not ReadFile(FOutputReadHandle, Buffer[0], SizeOf(Buffer),
      BytesReadWin, nil) then
      Break;
    if BytesReadWin = 0 then
      Break;
    SetString(Chunk, PChar(@Buffer[0]), BytesReadWin);
    DeliverData(Chunk);
  end;
  {$ELSE}
  if FProcess = nil then
    Exit;
  while (FProcess.Output <> nil) and
    (FProcess.Output.NumBytesAvailable > 0) do
  begin
    BytesRead := FProcess.Output.Read(Buffer, SizeOf(Buffer));
    if BytesRead <= 0 then
      Break;
    SetString(Chunk, PChar(@Buffer[0]), BytesRead);
    DeliverData(Chunk);
  end;
  {$ENDIF}
end;

procedure TPlatformProcess.RequestQuit(const AQuitCommand: string; AWaitMs: Integer);
begin
  if not IsRunning then
    Exit;
  if AQuitCommand <> '' then
    WriteLine(AQuitCommand);
  {$IFDEF MSWINDOWS}
  if FProcessInfo.hProcess <> 0 then
    WaitForSingleObject(FProcessInfo.hProcess, AWaitMs);
  {$ELSE}
  if FProcess <> nil then
    FProcess.WaitOnExit(AWaitMs);
  {$ENDIF}
end;

procedure TPlatformProcess.Terminate(AWaitMs: Integer);
begin
  if not IsRunning then
    Exit;
  {$IFDEF MSWINDOWS}
  if FProcessInfo.hProcess <> 0 then
  begin
    TerminateProcess(FProcessInfo.hProcess, 0);
    WaitForSingleObject(FProcessInfo.hProcess, AWaitMs);
  end;
  {$ELSE}
  if FProcess <> nil then
  begin
    FProcess.Terminate(0);
    FProcess.WaitOnExit(AWaitMs);
    if FProcess.Running then
    begin
      fpKill(FProcess.ProcessID, SIGKILL);
      FProcess.WaitOnExit(AWaitMs);
    end;
  end;
  {$ENDIF}
end;

procedure TPlatformProcess.Close;
begin
  {$IFDEF MSWINDOWS}
  ClosePipeHandles(True);
  StopReaderThread(True);
  CloseProcessInfoHandles;
  FRunning := False;
  {$ELSE}
  FreeAndNil(FProcess);
  {$ENDIF}
end;

procedure TPlatformProcess.DeliverData(const AText: string);
begin
  if Assigned(FOnData) then
    FOnData(Self, AText);
end;

{$IFDEF MSWINDOWS}
procedure TPlatformProcess.ClosePipeHandles(ACloseOutputHandle: Boolean);
begin
  if FInputWriteHandle <> 0 then
  begin
    CloseHandle(FInputWriteHandle);
    FInputWriteHandle := 0;
  end;
  if ACloseOutputHandle and (FOutputReadHandle <> 0) then
  begin
    CloseHandle(FOutputReadHandle);
    FOutputReadHandle := 0;
  end;
end;

procedure TPlatformProcess.StopReaderThread(AWaitForThread: Boolean);
begin
  if FReaderThread <> nil then
  begin
    FReaderThread.Terminate;
    if AWaitForThread then
    begin
      FReaderThread.WaitFor;
      FreeAndNil(FReaderThread);
    end;
  end;
end;

procedure TPlatformProcess.CloseProcessInfoHandles;
begin
  if FProcessInfo.hThread <> 0 then
  begin
    CloseHandle(FProcessInfo.hThread);
    FProcessInfo.hThread := 0;
  end;
  if FProcessInfo.hProcess <> 0 then
  begin
    CloseHandle(FProcessInfo.hProcess);
    FProcessInfo.hProcess := 0;
  end;
end;
{$ENDIF}

end.
