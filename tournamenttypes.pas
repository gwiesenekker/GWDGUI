unit TournamentTypes;

{$mode objfpc}{$H+}

interface

const
  TournamentTypeSingleRoundRobin = 'single-round-robin';
  TournamentTypeDoubleRoundRobin = 'double-round-robin';
  TournamentTypeSwiss = 'swiss';

  TournamentPairingIndexSingleRoundRobin = 0;
  TournamentPairingIndexDoubleRoundRobin = 1;
  TournamentPairingIndexSwiss = 2;

function RoundRobinIndexForTournamentType(const ATournamentType: String): Integer;
function TournamentTypeForRoundRobinIndex(AIndex: Integer): String;
function TournamentTypeIsSwiss(const ATournamentType: String): Boolean;
function TournamentRoundRobinIndexIsDouble(AIndex: Integer): Boolean;
function TournamentRoundRobinIndexIsSwiss(AIndex: Integer): Boolean;

implementation

uses
  SysUtils;

function RoundRobinIndexForTournamentType(const ATournamentType: String): Integer;
begin
  if SameText(ATournamentType, TournamentTypeSwiss) then
    Result := TournamentPairingIndexSwiss
  else if SameText(ATournamentType, TournamentTypeDoubleRoundRobin) then
    Result := TournamentPairingIndexDoubleRoundRobin
  else
    Result := TournamentPairingIndexSingleRoundRobin;
end;

function TournamentTypeForRoundRobinIndex(AIndex: Integer): String;
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

function TournamentTypeIsSwiss(const ATournamentType: String): Boolean;
begin
  Result := SameText(ATournamentType, TournamentTypeSwiss);
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
