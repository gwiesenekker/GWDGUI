unit PlayClockController;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  DraughtsRules,
  GameClock,
  PlatformTime;

type
  TPlayClockController = class
  private
    FClock: TGameClock;
    FTicker: TPlatformTicker;
    FOnTick: TNotifyEvent;
    procedure DoTickerTick(Sender: TObject);
    function GetActive: Boolean;
    function GetBlackSeconds: Double;
    function GetInitialBlackSeconds: Double;
    function GetInitialWhiteSeconds: Double;
    function GetWhiteSeconds: Double;
    procedure SetTickerEnabled(AEnabled: Boolean);
  public
    constructor Create(ATickIntervalMs: Integer);
    destructor Destroy; override;
    procedure Reset;
    procedure Start(AGameMinutes: Double);
    procedure Activate;
    procedure Pause(ASideToMove: TSide);
    procedure PauseAt(ASideToMove: TSide; AReceivedAtSeconds: Double);
    procedure Stop;
    function Update(ASideToMove: TSide): Boolean;
    function NeedsIdleUpdate: Boolean;
    procedure RestoreInitial;
    procedure RestoreSnapshot(const ASnapshot: TClockSnapshot);
    function Snapshot(AHasClock: Boolean): TClockSnapshot;
    function SecondsForSide(ASide: TSide): Double;
    function SecondsForSideAt(ASide, ASideToMove: TSide;
      ANowSeconds: Double): Double;
    function SecondsUsedForSide(ASide: TSide): Double;
    property Active: Boolean read GetActive;
    property BlackSeconds: Double read GetBlackSeconds;
    property Clock: TGameClock read FClock;
    property InitialBlackSeconds: Double read GetInitialBlackSeconds;
    property InitialWhiteSeconds: Double read GetInitialWhiteSeconds;
    property OnTick: TNotifyEvent read FOnTick write FOnTick;
    property WhiteSeconds: Double read GetWhiteSeconds;
  end;

implementation

constructor TPlayClockController.Create(ATickIntervalMs: Integer);
begin
  inherited Create;
  FClock := TGameClock.Create;
  FTicker := TPlatformTicker.Create(ATickIntervalMs);
  FTicker.OnTick := @DoTickerTick;
end;

destructor TPlayClockController.Destroy;
begin
  FTicker.Free;
  FClock.Free;
  inherited Destroy;
end;

procedure TPlayClockController.DoTickerTick(Sender: TObject);
begin
  if Assigned(FOnTick) then
    FOnTick(Sender);
end;

function TPlayClockController.GetActive: Boolean;
begin
  Result := FClock.Active;
end;

function TPlayClockController.GetBlackSeconds: Double;
begin
  Result := FClock.BlackSeconds;
end;

function TPlayClockController.GetInitialBlackSeconds: Double;
begin
  Result := FClock.InitialBlackSeconds;
end;

function TPlayClockController.GetInitialWhiteSeconds: Double;
begin
  Result := FClock.InitialWhiteSeconds;
end;

function TPlayClockController.GetWhiteSeconds: Double;
begin
  Result := FClock.WhiteSeconds;
end;

procedure TPlayClockController.SetTickerEnabled(AEnabled: Boolean);
begin
  if FTicker <> nil then
    FTicker.Enabled := AEnabled;
end;

procedure TPlayClockController.Reset;
begin
  FClock.Reset;
  SetTickerEnabled(False);
end;

procedure TPlayClockController.Start(AGameMinutes: Double);
begin
  FClock.Start(AGameMinutes);
  SetTickerEnabled(False);
end;

procedure TPlayClockController.Activate;
begin
  FClock.Activate;
  SetTickerEnabled(FClock.Active);
end;

procedure TPlayClockController.Pause(ASideToMove: TSide);
begin
  if FClock.Active then
    FClock.Update(ASideToMove);
  FClock.Pause;
  SetTickerEnabled(False);
end;

procedure TPlayClockController.PauseAt(ASideToMove: TSide;
  AReceivedAtSeconds: Double);
begin
  if AReceivedAtSeconds <= 0 then
  begin
    Pause(ASideToMove);
    Exit;
  end;

  if FClock.Active then
    FClock.PauseAt(ASideToMove, AReceivedAtSeconds)
  else
    FClock.Pause;
  SetTickerEnabled(False);
end;

procedure TPlayClockController.Stop;
begin
  FClock.Stop;
  SetTickerEnabled(False);
end;

function TPlayClockController.Update(ASideToMove: TSide): Boolean;
begin
  Result := FClock.Update(ASideToMove);
end;

function TPlayClockController.NeedsIdleUpdate: Boolean;
begin
  Result := FClock.Active and (FClock.SecondsSinceLastTick >= 0.20);
end;

procedure TPlayClockController.RestoreInitial;
begin
  FClock.RestoreInitial;
end;

procedure TPlayClockController.RestoreSnapshot(const ASnapshot: TClockSnapshot);
begin
  FClock.RestoreSnapshot(ASnapshot);
end;

function TPlayClockController.Snapshot(AHasClock: Boolean): TClockSnapshot;
begin
  Result := FClock.Snapshot(AHasClock);
end;

function TPlayClockController.SecondsForSide(ASide: TSide): Double;
begin
  Result := FClock.SecondsForSide(ASide);
end;

function TPlayClockController.SecondsForSideAt(ASide, ASideToMove: TSide;
  ANowSeconds: Double): Double;
begin
  Result := FClock.SecondsForSideAt(ASide, ASideToMove, ANowSeconds);
end;

function TPlayClockController.SecondsUsedForSide(ASide: TSide): Double;
begin
  Result := FClock.SecondsUsedForSide(ASide);
end;

end.
