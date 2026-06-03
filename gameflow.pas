unit GameFlow;

{$mode objfpc}{$H+}

interface

uses
  DraughtsRules;

type
  TGameFlowReason = (gfrHumanMove, gfrEngineMove, gfrAutoPlayMove);
  TGameEndReason = (gerTerminalPosition, gerRepetition, gerAgreedDraw,
    gerTwentyFiveMoveRule, gerDxpGameEnd, gerClockExpired);
  TStoppedMode = (smAutoPlay, smPlayGame);

function GameFlowReasonText(AReason: TGameFlowReason): String;
function GameEndResultForReason(AReason: TGameEndReason;
  const AExplicitResult: String; ASideToMove: TSide): String;
procedure GameEndReasonDetails(AReason: TGameEndReason; ASideToMove: TSide;
  out AGuiReason, ALogText: String);
function GameEndTournamentReasonText(AReason: TGameEndReason;
  ASideToMove: TSide; const AResult: String = ''): String;
function StoppedModeText(AMode: TStoppedMode): String;

implementation

function GameFlowReasonText(AReason: TGameFlowReason): String;
begin
  case AReason of
    gfrHumanMove: Result := 'human move';
    gfrEngineMove: Result := 'engine move';
    gfrAutoPlayMove: Result := 'auto-play move';
  else
    Result := 'unknown';
  end;
end;

function GameEndResultForReason(AReason: TGameEndReason;
  const AExplicitResult: String; ASideToMove: TSide): String;
begin
  Result := AExplicitResult;
  if ((AReason = gerTerminalPosition) or (AReason = gerClockExpired)) and
    (Result = '') then
  begin
    if ASideToMove = sideWhite then
      Result := '0-2'
    else
      Result := '2-0';
  end;
end;

procedure GameEndReasonDetails(AReason: TGameEndReason; ASideToMove: TSide;
  out AGuiReason, ALogText: String);
begin
  case AReason of
    gerTerminalPosition:
      begin
        AGuiReason := 'terminal position';
        ALogText := '[play game stopped: terminal position]';
      end;
    gerRepetition:
      begin
        AGuiReason := 'draw by repetition';
        ALogText := '[game drawn by repetition]';
      end;
    gerAgreedDraw:
      begin
        AGuiReason := 'agreed draw';
        ALogText := '[play game stopped: agreed draw]';
      end;
    gerTwentyFiveMoveRule:
      begin
        AGuiReason := '25-move draw';
        ALogText := '[game drawn by 25-move rule]';
      end;
    gerDxpGameEnd:
      begin
        AGuiReason := 'DXP game end';
        ALogText := '[play game stopped: DXP_GAMEEND]';
      end;
    gerClockExpired:
      begin
        AGuiReason := 'clock expired';
        if ASideToMove = sideWhite then
          ALogText := '[white clock expired]'
        else
          ALogText := '[black clock expired]';
      end;
  else
    begin
      AGuiReason := 'game ended';
      ALogText := '[game ended]';
    end;
  end;
end;

function GameEndTournamentReasonText(AReason: TGameEndReason;
  ASideToMove: TSide; const AResult: String): String;
begin
  case AReason of
    gerTerminalPosition:
      Result := 'Terminal position';
    gerRepetition:
      Result := 'Draw by repetition';
    gerAgreedDraw:
      Result := 'Agreed draw';
    gerTwentyFiveMoveRule:
      Result := 'Draw by 25-move rule';
    gerDxpGameEnd:
      if (AResult = '1-1') or (AResult = '1/2-1/2') then
        Result := 'DXP draw'
      else if AResult = '2-0' then
        Result := 'DXP white wins'
      else if AResult = '0-2' then
        Result := 'DXP black wins'
      else
        Result := 'DXP game end';
    gerClockExpired:
      if ASideToMove = sideWhite then
        Result := 'White lost on time'
      else
        Result := 'Black lost on time';
  else
    Result := '';
  end;
end;

function StoppedModeText(AMode: TStoppedMode): String;
begin
  case AMode of
    smAutoPlay: Result := 'auto-play';
    smPlayGame: Result := 'play game';
  else
    Result := 'mode';
  end;
end;

end.
