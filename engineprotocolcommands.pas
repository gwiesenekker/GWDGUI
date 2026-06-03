unit EngineProtocolCommands;

{$mode objfpc}{$H+}

interface

type
  TEngineProtocolCommand = (epcStop, epcAnalyze, epcMcts, epcThink);
  TEngineSlotCommandAction = (escaStop, escaAnalyze, escaMcts, escaThink);
  TEngineAllCommandTarget = (eactReverseSlots, eactAnalyzeReadySlots,
    eactMctsReadySlots, eactPrimaryThinkSlot);

function EngineSlotCommandAction(ACommand: TEngineProtocolCommand):
  TEngineSlotCommandAction;
function EngineAllCommandTarget(ACommand: TEngineProtocolCommand):
  TEngineAllCommandTarget;

implementation

function EngineSlotCommandAction(ACommand: TEngineProtocolCommand):
  TEngineSlotCommandAction;
begin
  case ACommand of
    epcStop:
      Result := escaStop;
    epcAnalyze:
      Result := escaAnalyze;
    epcMcts:
      Result := escaMcts;
    epcThink:
      Result := escaThink;
  end;
end;

function EngineAllCommandTarget(ACommand: TEngineProtocolCommand):
  TEngineAllCommandTarget;
begin
  case ACommand of
    epcStop:
      Result := eactReverseSlots;
    epcAnalyze:
      Result := eactAnalyzeReadySlots;
    epcMcts:
      Result := eactMctsReadySlots;
    epcThink:
      Result := eactPrimaryThinkSlot;
  end;
end;

end.
