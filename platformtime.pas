unit PlatformTime;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  SysUtils;

type
  TPlatformTickEvent = procedure(Sender: TObject) of object;

  TPlatformTicker = class;

  TPlatformTickerThread = class(TThread)
  private
    FOwner: TPlatformTicker;
    procedure DeliverTick;
  protected
    procedure Execute; override;
  public
    constructor Create(AOwner: TPlatformTicker);
  end;

  TPlatformTicker = class
  private
    FEnabled: Boolean;
    FInterval: Integer;
    FOnTick: TPlatformTickEvent;
    FThread: TPlatformTickerThread;
    procedure DoTick;
    procedure SetEnabled(AValue: Boolean);
  public
    constructor Create(AInterval: Integer);
    destructor Destroy; override;
    property Enabled: Boolean read FEnabled write SetEnabled;
    property Interval: Integer read FInterval;
    property OnTick: TPlatformTickEvent read FOnTick write FOnTick;
  end;

function PlatformTimestampMilliseconds: QWord;
function PlatformTimestampSeconds: Double;

implementation

function PlatformTimestampMilliseconds: QWord;
begin
  Result := GetTickCount64;
end;

function PlatformTimestampSeconds: Double;
begin
  Result := PlatformTimestampMilliseconds / 1000.0;
end;

constructor TPlatformTickerThread.Create(AOwner: TPlatformTicker);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FOwner := AOwner;
  Start;
end;

procedure TPlatformTickerThread.DeliverTick;
begin
  if FOwner <> nil then
    FOwner.DoTick;
end;

procedure TPlatformTickerThread.Execute;
begin
  while not Terminated do
  begin
    if FOwner <> nil then
      Sleep(FOwner.Interval)
    else
      Sleep(250);
    if not Terminated then
      Synchronize(@DeliverTick);
  end;
end;

constructor TPlatformTicker.Create(AInterval: Integer);
begin
  inherited Create;
  FEnabled := False;
  FInterval := AInterval;
  if FInterval <= 0 then
    FInterval := 250;
  FThread := TPlatformTickerThread.Create(Self);
end;

destructor TPlatformTicker.Destroy;
begin
  if FThread <> nil then
  begin
    FThread.Terminate;
    FThread.WaitFor;
    FreeAndNil(FThread);
  end;
  inherited Destroy;
end;

procedure TPlatformTicker.DoTick;
begin
  if FEnabled and Assigned(FOnTick) then
    FOnTick(Self);
end;

procedure TPlatformTicker.SetEnabled(AValue: Boolean);
begin
  FEnabled := AValue;
end;

end.
