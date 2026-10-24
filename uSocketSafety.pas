unit uSocketSafety;

{$mode objfpc}{$H+}

interface

uses
  ssockets;

procedure SuppressSocketSigPipe(ASocket: TSocketStream);

implementation

uses
  sockets, SysUtils;

procedure SuppressSocketSigPipe(ASocket: TSocketStream);
{$IFDEF DARWIN}
var
  Enabled: Longint;
{$ENDIF}
begin
  if ASocket = nil then
    Exit;
  {$IFDEF UNIX}
  {$IFDEF DARWIN}
  Enabled := 1;
  if fpSetSockOpt(ASocket.Handle, SOL_SOCKET, SO_NOSIGPIPE,
    @Enabled, SizeOf(Enabled)) <> 0 then
    raise EInOutError.Create('Could not suppress SIGPIPE on engine socket');
  {$ELSE}
  ASocket.WriteFlags := ASocket.WriteFlags or MSG_NOSIGNAL;
  {$ENDIF}
  {$ENDIF}
end;

end.
