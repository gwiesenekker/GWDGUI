unit EngineSearchController;

{$mode objfpc}{$H+}

interface

uses
  EngineConfig,
  EngineCommands,
  EngineState;

type
  TEngineSearchIntent = (esiAnalyze, esiMcts, esiThink);

  TEngineSearchPreparation = record
    ClearAnalyzeHighlights: Boolean;
    ClearAnalysisDisplay: Boolean;
    TerminalAutoPlay: Boolean;
    SendTerminalToEngine: Boolean;
  end;

  TEngineAnalyzeRoute = (earUnsupported, earHubAnalyze);

  TEngineAnalyzeDecision = record
    Route: TEngineAnalyzeRoute;
    HubLevelCommand: THubLevelCommand;
    LogText: String;
  end;

  TEngineMctsRoute = (emrUnsupported, emrHubMcts);

  TEngineMctsDecision = record
    Route: TEngineMctsRoute;
    HubLevelCommand: THubLevelCommand;
    LogText: String;
  end;

  TEngineThinkRoute = (etrUnsupported, etrHubThink, etrDxpThink);

  TEngineThinkDecision = record
    Route: TEngineThinkRoute;
    HubLevelCommand: THubLevelCommand;
    LogText: String;
  end;

function EngineSearchPreparation(AIntent: TEngineSearchIntent;
  AMode: TEngineSearchMode): TEngineSearchPreparation;
function DecideEngineAnalyze(AProtocol: TEngineProtocol): TEngineAnalyzeDecision;
function DecideEngineMcts(AProtocol: TEngineProtocol; ASupportsMcts: Boolean;
  const AEngineName: String): TEngineMctsDecision;
function DecideEngineThink(AProtocol: TEngineProtocol;
  AMode: TEngineSearchMode): TEngineThinkDecision;

implementation

function EngineSearchPreparation(AIntent: TEngineSearchIntent;
  AMode: TEngineSearchMode): TEngineSearchPreparation;
begin
  Result.ClearAnalyzeHighlights := AIntent = esiAnalyze;
  Result.ClearAnalysisDisplay := True;
  Result.TerminalAutoPlay := False;
  Result.SendTerminalToEngine := False;

  if AIntent = esiThink then
  begin
    Result.TerminalAutoPlay := AMode = esmAutoPlay;
    Result.SendTerminalToEngine := True;
  end;
end;

function DecideEngineAnalyze(AProtocol: TEngineProtocol): TEngineAnalyzeDecision;
begin
  Result.Route := earUnsupported;
  Result.HubLevelCommand := hlcMoveTime;
  Result.LogText := '';

  if AProtocol = epDxp then
  begin
    Result.LogText := '[go analyze not supported for DXP engines]' +
      LineEnding;
    Exit;
  end;

  Result.Route := earHubAnalyze;
end;

function DecideEngineMcts(AProtocol: TEngineProtocol; ASupportsMcts: Boolean;
  const AEngineName: String): TEngineMctsDecision;
begin
  Result.Route := emrUnsupported;
  Result.HubLevelCommand := hlcMoveTime;
  Result.LogText := '';

  if AProtocol = epDxp then
  begin
    Result.LogText := '[go mcts not supported for DXP engines]' + LineEnding;
    Exit;
  end;

  if not ASupportsMcts then
  begin
    Result.LogText := '[' + AEngineName + ' does not support go mcts]' +
      LineEnding;
    Exit;
  end;

  Result.Route := emrHubMcts;
end;

function DecideEngineThink(AProtocol: TEngineProtocol;
  AMode: TEngineSearchMode): TEngineThinkDecision;
begin
  Result.Route := etrUnsupported;
  Result.HubLevelCommand := hlcMoveTime;
  Result.LogText := '';

  if AProtocol = epDxp then
  begin
    if AMode = esmAutoPlay then
      Result.LogText := '[DXP auto-play from current position]' + LineEnding;
    if AMode in [esmAutoPlay, esmPlayGameThink] then
      Result.Route := etrDxpThink
    else
      Result.LogText :=
        '[go think not supported for DXP engines outside game/auto-play]' +
        LineEnding;
    Exit;
  end;

  Result.Route := etrHubThink;
  if AMode = esmPlayGameThink then
    Result.HubLevelCommand := hlcGameTime
  else
    Result.HubLevelCommand := hlcMoveTime;
end;

end.
