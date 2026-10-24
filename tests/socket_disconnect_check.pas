program socket_disconnect_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, BaseUnix, sockets,{$ENDIF}
  Classes, SysUtils, ssockets, uSocketSafety;

procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;

{$IFDEF UNIX}
procedure WriteToDisconnectedPeer(ProtectedWrite: Boolean);
var
  Handles: array[0..1] of Longint;
  Stream: TSocketStream;
  ByteValue: Byte;
  Raised: Boolean;
  SignalSet: TSigSet;
begin
  // An unprotected write must kill only this isolated child process.
  fpSignal(SIGPIPE, SignalHandler(SIG_DFL));
  fpSigEmptySet(SignalSet);
  fpSigAddSet(SignalSet, SIGPIPE);
  fpSigProcMask(SIG_UNBLOCK, @SignalSet, nil);
  Check(fpSocketPair(AF_UNIX, SOCK_STREAM, 0, @Handles[0]) = 0,
    'could not create regression socket pair');
  Stream := TSocketStream.Create(Handles[0]);
  try
    if ProtectedWrite then
      SuppressSocketSigPipe(Stream);
    fpClose(Handles[1]);
    ByteValue := 1;
    if not ProtectedWrite then
    begin
      fpWrite(Stream.Handle, ByteValue, 1);
      Halt(99); // A live default SIGPIPE handler must prevent reaching this.
    end;
    {$IFNDEF DARWIN}
    Check((Stream.WriteFlags and MSG_NOSIGNAL) <> 0,
      'socket writes must explicitly suppress SIGPIPE');
    {$ENDIF}
    Raised := False;
    try
      Stream.WriteBuffer(ByteValue, 1);
    except
      on E: EWriteError do
        Raised := True;
    end;
    Check(Raised, 'broken socket must report a write error');
  finally
    Stream.Free;
  end;
end;

function ChildExit(const Mode: string): Integer;
var
  ChildPid, Status: Longint;
  Executable: string;
  Args: array[0..2] of PChar;
begin
  Executable := ExpandFileName(ParamStr(0));
  Args[0] := PChar(Executable);
  Args[1] := PChar(Mode);
  Args[2] := nil;
  ChildPid := fpFork;
  Check(ChildPid >= 0, 'could not fork regression child');
  if ChildPid = 0 then
  begin
    fpExecv(PChar(Executable), @Args[0]);
    fpExit(127);
  end;
  Check(fpWaitPid(ChildPid, @Status, 0) = ChildPid, 'could not wait for child');
  Result := Status;
end;
{$ENDIF}

begin
  {$IFDEF UNIX}
  if ParamStr(1) = '--protected' then
  begin
    WriteToDisconnectedPeer(True);
    Halt(0);
  end;
  if ParamStr(1) = '--unprotected' then
  begin
    WriteToDisconnectedPeer(False);
    Halt(0);
  end;
  Check(ChildExit('--unprotected') = SIGPIPE,
    'test setup must reproduce SIGPIPE with default socket flags');
  Check(ChildExit('--protected') = 0,
    'protected broken-socket write must raise normally instead of killing process');
  WriteLn('OK');
  {$ELSE}
  WriteLn('SKIP: SIGPIPE regression applies to Unix sockets');
  {$ENDIF}
end.
