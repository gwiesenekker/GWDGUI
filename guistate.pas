unit GuiState;

{$mode objfpc}{$H+}

interface

type
  TGuiState = (gsIdle, gsAnalyzing, gsMcts, gsAutoPlaying,
    gsPlayGameHumanTurn, gsPlayGameEngineTurn, gsTournamentRunning,
    gsStopping, gsGameOver);

function GuiStateText(AState: TGuiState): String;

implementation

function GuiStateText(AState: TGuiState): String;
begin
  case AState of
    gsIdle: Result := 'Idle';
    gsAnalyzing: Result := 'Analyzing';
    gsMcts: Result := 'MCTS';
    gsAutoPlaying: Result := 'Auto-playing';
    gsPlayGameHumanTurn: Result := 'Play-game human turn';
    gsPlayGameEngineTurn: Result := 'Play-game engine turn';
    gsTournamentRunning: Result := 'Tournament running';
    gsStopping: Result := 'Stopping';
    gsGameOver: Result := 'Game over';
  else
    Result := 'Unknown';
  end;
end;

end.
