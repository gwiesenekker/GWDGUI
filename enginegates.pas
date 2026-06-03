unit EngineGates;

{$mode objfpc}{$H+}

interface

type
  TEngineCommandGate = record
    Allowed: Boolean;
    Reason: String;
  end;

function EngineCommandAllowed: TEngineCommandGate;
function EngineCommandDenied(const AReason: String): TEngineCommandGate;
function EngineReceiveCommandGate(const AEngineName: String; AEngineSlotValid,
  AEngineRunning, ARequireReady, AEngineReady: Boolean): TEngineCommandGate;
function DxpPacketGate(const APacketName: String; AEngineSlotValid, AIsDxp,
  ACheckGameEndSent, AGameEndAlreadySent, ASocketOpen: Boolean):
  TEngineCommandGate;
function HubSearchGate(const AReceiveGate: TEngineCommandGate;
  const AGoCommand, AEngineName: String; AIsDxp, ARequireMctsSupport,
  ASupportsMcts: Boolean): TEngineCommandGate;

implementation

uses
  SysUtils;

function EngineCommandAllowed: TEngineCommandGate;
begin
  Result.Allowed := True;
  Result.Reason := '';
end;

function EngineCommandDenied(const AReason: String): TEngineCommandGate;
begin
  Result.Allowed := False;
  Result.Reason := AReason;
end;

function EngineReceiveCommandGate(const AEngineName: String; AEngineSlotValid,
  AEngineRunning, ARequireReady, AEngineReady: Boolean): TEngineCommandGate;
begin
  if not AEngineSlotValid then
    Exit(EngineCommandDenied('[engine command ignored: invalid engine slot]' +
      LineEnding));

  if not AEngineRunning then
    Exit(EngineCommandDenied('[' + AEngineName +
      ' command ignored: engine is not running]' + LineEnding));

  if ARequireReady and (not AEngineReady) then
    Exit(EngineCommandDenied('[' + AEngineName +
      ' command ignored: engine is not ready]' + LineEnding));

  Result := EngineCommandAllowed;
end;

function DxpPacketGate(const APacketName: String; AEngineSlotValid, AIsDxp,
  ACheckGameEndSent, AGameEndAlreadySent, ASocketOpen: Boolean):
  TEngineCommandGate;
begin
  if not AEngineSlotValid then
    Exit(EngineCommandDenied('[' + APacketName +
      ' not sent: invalid engine slot]' + LineEnding));

  if not AIsDxp then
    Exit(EngineCommandDenied('[' + APacketName +
      ' not sent: engine is not DXP]' + LineEnding));

  if ACheckGameEndSent and AGameEndAlreadySent then
    Exit(EngineCommandDenied('[' + APacketName +
      ' not sent: already sent]' + LineEnding));

  if not ASocketOpen then
    Exit(EngineCommandDenied('[' + APacketName +
      ' not sent: DXP socket is not open]' + LineEnding));

  Result := EngineCommandAllowed;
end;

function HubSearchGate(const AReceiveGate: TEngineCommandGate;
  const AGoCommand, AEngineName: String; AIsDxp, ARequireMctsSupport,
  ASupportsMcts: Boolean): TEngineCommandGate;
begin
  Result := AReceiveGate;
  if not Result.Allowed then
    Exit;

  if AIsDxp then
  begin
    Result := EngineCommandDenied('[' + AGoCommand +
      ' not supported for DXP engines]' + LineEnding);
    Exit;
  end;

  if ARequireMctsSupport and (not ASupportsMcts) then
  begin
    Result := EngineCommandDenied('[' + AEngineName +
      ' does not support go mcts]' + LineEnding);
    Exit;
  end;
end;

end.
