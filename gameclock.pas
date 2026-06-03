unit GameClock;

{$mode objfpc}{$H+}

interface

uses
  DraughtsRules,
  Math,
  PlatformTime;

type
  TClockSnapshot = record
    HasClock: Boolean;
    WhiteSeconds: Double;
    BlackSeconds: Double;
  end;
  TClockSnapshotArray = array of TClockSnapshot;

  TGameClock = class
  private
    FActive: Boolean;
    FBlackSeconds: Double;
    FInitialBlackSeconds: Double;
    FInitialWhiteSeconds: Double;
    FLastTick: Double;
    FWhiteSeconds: Double;
    function NowSeconds: Double;
  public
    constructor Create;
    procedure Reset;
    procedure Start(AGameMinutes: Double);
    procedure Activate;
    procedure Pause;
    procedure Stop;
    function Update(ASideToMove: TSide): Boolean;
    function UpdateAt(ASideToMove: TSide; ANowSeconds: Double): Boolean;
    procedure PauseAt(ASideToMove: TSide; ANowSeconds: Double);
    procedure RestoreInitial;
    procedure RestoreSnapshot(const ASnapshot: TClockSnapshot);
    function Snapshot(AHasClock: Boolean): TClockSnapshot;
    function SecondsSinceLastTick: Double;
    function SecondsForSide(ASide: TSide): Double;
    function SecondsForSideAt(ASide, ASideToMove: TSide;
      ANowSeconds: Double): Double;
    function SecondsUsedForSide(ASide: TSide): Double;
    property Active: Boolean read FActive;
    property WhiteSeconds: Double read FWhiteSeconds;
    property BlackSeconds: Double read FBlackSeconds;
    property InitialWhiteSeconds: Double read FInitialWhiteSeconds;
    property InitialBlackSeconds: Double read FInitialBlackSeconds;
  end;

implementation

constructor TGameClock.Create;
begin
  inherited Create;
  Reset;
end;

function TGameClock.NowSeconds: Double;
begin
  Result := PlatformTimestampSeconds;
end;

procedure TGameClock.Reset;
begin
  FWhiteSeconds := 0;
  FBlackSeconds := 0;
  FInitialWhiteSeconds := 0;
  FInitialBlackSeconds := 0;
  FLastTick := NowSeconds;
  FActive := False;
end;

procedure TGameClock.Start(AGameMinutes: Double);
begin
  FWhiteSeconds := Max(0, AGameMinutes * 60);
  FBlackSeconds := Max(0, AGameMinutes * 60);
  FInitialWhiteSeconds := FWhiteSeconds;
  FInitialBlackSeconds := FBlackSeconds;
  FLastTick := NowSeconds;
  FActive := False;
end;

procedure TGameClock.Activate;
begin
  FLastTick := NowSeconds;
  FActive := (FWhiteSeconds > 0) and (FBlackSeconds > 0);
end;

procedure TGameClock.Pause;
begin
  FActive := False;
  FLastTick := NowSeconds;
end;

procedure TGameClock.PauseAt(ASideToMove: TSide; ANowSeconds: Double);
begin
  UpdateAt(ASideToMove, ANowSeconds);
  FActive := False;
  FLastTick := ANowSeconds;
end;

procedure TGameClock.Stop;
begin
  FActive := False;
end;

function TGameClock.Update(ASideToMove: TSide): Boolean;
begin
  Result := UpdateAt(ASideToMove, NowSeconds);
end;

function TGameClock.UpdateAt(ASideToMove: TSide; ANowSeconds: Double): Boolean;
var
  ElapsedSeconds: Double;
begin
  Result := False;
  if not FActive then
    Exit;

  ElapsedSeconds := ANowSeconds - FLastTick;
  FLastTick := ANowSeconds;
  if ElapsedSeconds <= 0 then
    Exit;
  if ElapsedSeconds > 10 then
    ElapsedSeconds := 0;

  if ASideToMove = sideWhite then
  begin
    FWhiteSeconds := Max(0, FWhiteSeconds - ElapsedSeconds);
    Result := FWhiteSeconds = 0;
  end
  else
  begin
    FBlackSeconds := Max(0, FBlackSeconds - ElapsedSeconds);
    Result := FBlackSeconds = 0;
  end;
end;

procedure TGameClock.RestoreInitial;
begin
  FWhiteSeconds := FInitialWhiteSeconds;
  FBlackSeconds := FInitialBlackSeconds;
  FLastTick := NowSeconds;
end;

procedure TGameClock.RestoreSnapshot(const ASnapshot: TClockSnapshot);
begin
  FWhiteSeconds := ASnapshot.WhiteSeconds;
  FBlackSeconds := ASnapshot.BlackSeconds;
  FLastTick := NowSeconds;
end;

function TGameClock.Snapshot(AHasClock: Boolean): TClockSnapshot;
begin
  Result.HasClock := AHasClock;
  Result.WhiteSeconds := FWhiteSeconds;
  Result.BlackSeconds := FBlackSeconds;
end;

function TGameClock.SecondsSinceLastTick: Double;
begin
  Result := NowSeconds - FLastTick;
end;

function TGameClock.SecondsForSide(ASide: TSide): Double;
begin
  if ASide = sideWhite then
    Result := FWhiteSeconds
  else
    Result := FBlackSeconds;
end;

function TGameClock.SecondsForSideAt(ASide, ASideToMove: TSide;
  ANowSeconds: Double): Double;
var
  ElapsedSeconds: Double;
begin
  Result := SecondsForSide(ASide);
  if (not FActive) or (ASide <> ASideToMove) then
    Exit;

  ElapsedSeconds := ANowSeconds - FLastTick;
  if ElapsedSeconds <= 0 then
    Exit;
  if ElapsedSeconds > 10 then
    ElapsedSeconds := 0;
  Result := Max(0, Result - ElapsedSeconds);
end;

function TGameClock.SecondsUsedForSide(ASide: TSide): Double;
begin
  if ASide = sideWhite then
    Result := FInitialWhiteSeconds - FWhiteSeconds
  else
    Result := FInitialBlackSeconds - FBlackSeconds;
  if Result < 0 then
    Result := 0;
end;

end.
