unit uTournamentTypes;

{$mode objfpc}{$H+}

interface

const
  TournamentTypeSingleRoundRobin = 'single-round-robin';
  TournamentTypeDoubleRoundRobin = 'double-round-robin';
  TournamentTypeSwiss = 'swiss';

  TournamentPairingIndexSingleRoundRobin = 0;
  TournamentPairingIndexDoubleRoundRobin = 1;
  TournamentPairingIndexSwiss = 2;

function TournamentTypeForRoundRobinIndex(AIndex: Integer): string;
function TournamentRoundRobinIndexIsDouble(AIndex: Integer): Boolean;
function TournamentRoundRobinIndexIsSwiss(AIndex: Integer): Boolean;

implementation

function TournamentTypeForRoundRobinIndex(AIndex: Integer): string;
begin
  case AIndex of
    TournamentPairingIndexSwiss:
      Result := TournamentTypeSwiss;
    TournamentPairingIndexDoubleRoundRobin:
      Result := TournamentTypeDoubleRoundRobin;
  else
    Result := TournamentTypeSingleRoundRobin;
  end;
end;

function TournamentRoundRobinIndexIsDouble(AIndex: Integer): Boolean;
begin
  Result := AIndex = TournamentPairingIndexDoubleRoundRobin;
end;

function TournamentRoundRobinIndexIsSwiss(AIndex: Integer): Boolean;
begin
  Result := AIndex = TournamentPairingIndexSwiss;
end;

end.
