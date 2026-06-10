unit uCancellationToken;

{$mode objfpc}{$H+}

interface

uses
  SyncObjs;

type
  TCancellationToken = class
  private
    FCancelled: Boolean;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Cancel;
    function IsCancelled: Boolean;
    procedure Reset;
  end;

implementation

constructor TCancellationToken.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
end;

destructor TCancellationToken.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

procedure TCancellationToken.Cancel;
begin
  FLock.Acquire;
  try
    FCancelled := True;
  finally
    FLock.Release;
  end;
end;

function TCancellationToken.IsCancelled: Boolean;
begin
  FLock.Acquire;
  try
    Result := FCancelled;
  finally
    FLock.Release;
  end;
end;

procedure TCancellationToken.Reset;
begin
  FLock.Acquire;
  try
    FCancelled := False;
  finally
    FLock.Release;
  end;
end;

end.
