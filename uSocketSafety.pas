unit uSocketSafety;

{$mode objfpc}{$H+}

interface

uses
  ssockets;

function DxpListenAddress(const Host: string): string;
function DxpPeerAllowed(const ListenHost, AllowedPeer, ActualPeer: string): Boolean;
procedure SuppressSocketSigPipe(ASocket: TSocketStream);

implementation

uses
  sockets, SysUtils;

function DxpListenAddress(const Host: string): string;
var Address: in_addr;
begin
  Result := Trim(Host);
  if (Result = '') or SameText(Result, 'localhost') then Exit('127.0.0.1');
  if not TryStrToHostAddr(Result, Address) then
    raise EConvertError.Create('DXP listen address must be an IPv4 address or localhost: ' + Result);
  Result := HostAddrToStr(Address);
end;

function DxpPeerAllowed(const ListenHost, AllowedPeer, ActualPeer: string): Boolean;
begin
  if Trim(AllowedPeer) <> '' then Exit(DxpListenAddress(AllowedPeer) = ActualPeer);
  // A loopback listener accepts only local peers. Explicit network bindings
  // may accept remote engines; an optional peer address can restrict them.
  Result := (Copy(ListenHost, 1, 4) <> '127.') or (Copy(ActualPeer, 1, 4) = '127.');
end;

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
