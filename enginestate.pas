unit EngineState;

{$mode objfpc}{$H+}

interface

type
  TPendingEngineAction = (peaNone, peaAutoPlay, peaAnalyze, peaMcts,
    peaThink, peaPlayGame);
  TEngineState = (esIdle, esAnalyzing, esMcts, esThinking,
    esWaitingForOtherEngine);
  TEngineSearchMode = (esmIdle, esmAnalyze, esmMcts, esmAutoPlay,
    esmPlayGameThink, esmPlayGameAnalyze);
  TDxpGameState = (dgsIdle, dgsGameRequested, dgsWaitingForMoveOrGameEnd,
    dgsGameEnding, dgsWaitingForNextGame);

function EngineStateCaption(AState: TEngineState): String;
function EngineStateLogText(AState: TEngineState;
  const AWaitingForName: String = 'other engine'): String;
function EngineStateNeedsStop(AState: TEngineState): Boolean;
function EngineStateText(AState: TEngineState): String;
function DxpGameStateText(AState: TDxpGameState): String;
function PendingEngineActionText(AAction: TPendingEngineAction): String;

implementation

function EngineStateCaption(AState: TEngineState): String;
begin
  case AState of
    esIdle: Result := 'Idle';
    esAnalyzing: Result := 'Analyzing';
    esMcts: Result := 'MCTS';
    esThinking: Result := 'Thinking';
    esWaitingForOtherEngine: Result := 'Waiting';
  else
    Result := 'Unknown';
  end;
end;

function EngineStateLogText(AState: TEngineState;
  const AWaitingForName: String): String;
begin
  if AState = esWaitingForOtherEngine then
    Result := 'wait for ' + AWaitingForName
  else
    Result := EngineStateText(AState);
end;

function EngineStateNeedsStop(AState: TEngineState): Boolean;
begin
  Result := AState in [esAnalyzing, esMcts, esThinking];
end;

function EngineStateText(AState: TEngineState): String;
begin
  case AState of
    esIdle: Result := 'idle';
    esAnalyzing: Result := 'analyzing';
    esMcts: Result := 'mcts';
    esThinking: Result := 'thinking';
    esWaitingForOtherEngine: Result := 'waiting for other engine';
  else
    Result := 'unknown';
  end;
end;

function DxpGameStateText(AState: TDxpGameState): String;
begin
  case AState of
    dgsIdle: Result := 'idle';
    dgsGameRequested: Result := 'waiting for DXP_GAMEACC';
    dgsWaitingForMoveOrGameEnd: Result := 'waiting for DXP_MOVE or DXP_GAMEEND';
    dgsGameEnding: Result := 'game ending';
    dgsWaitingForNextGame: Result := 'waiting for DXP_GAMEREQ';
  else
    Result := 'unknown';
  end;
end;

function PendingEngineActionText(AAction: TPendingEngineAction): String;
begin
  case AAction of
    peaNone: Result := 'none';
    peaAutoPlay: Result := 'auto-play';
    peaAnalyze: Result := 'analyze';
    peaMcts: Result := 'mcts';
    peaThink: Result := 'think';
    peaPlayGame: Result := 'play-game';
  else
    Result := 'unknown';
  end;
end;

end.
