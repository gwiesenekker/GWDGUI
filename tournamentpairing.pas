unit TournamentPairing;

{$mode objfpc}{$H+}

interface

uses
  Classes;

type
  TTournamentPairing = record
    White: String;
    Black: String;
  end;

  TTournamentPairingArray = array of TTournamentPairing;

  TTournamentButtonState = record
    CanCreatePairing: Boolean;
    CanPlayRound: Boolean;
    CanStop: Boolean;
  end;

  TTournamentPairingRound = record
    HasRepeat: Boolean;
    Pairings: TTournamentPairingArray;
    RoundNumber: Integer;
  end;

function BuildTournamentButtonState(AIsSwiss, ATournamentRunning,
  APairingGridEmpty: Boolean; AWhiteEngines, ABlackEngines,
  AResults: TStrings): TTournamentButtonState;
function BuildTournamentPairingRound(AIsSwiss, ADoubleRoundRobin: Boolean;
  AEngines, AWhiteEngines, ABlackEngines, AResults,
  ARounds: TStrings): TTournamentPairingRound;
function FindNextUnplayedTournamentRow(AIsSwiss: Boolean; AResults,
  ARounds: TStrings): Integer;
function TournamentAllResultsKnown(AWhiteEngines, ABlackEngines,
  AResults: TStrings): Boolean;
function TournamentNextRoundNumber(ARounds: TStrings): Integer;
procedure GenerateRoundRobinPairings(AEngines: TStrings;
  ADoubleRoundRobin: Boolean; out APairings: TTournamentPairingArray);
procedure GenerateSwissPairings(AEngines, AWhiteEngines, ABlackEngines,
  AResults, ARounds: TStrings; out APairings: TTournamentPairingArray;
  out AHasRepeat: Boolean);
function TournamentPairingRowsEmpty(AWhiteEngines, ABlackEngines: TStrings): Boolean;

implementation

uses
  SysUtils,
  TournamentResults;

function TournamentHasUnknownResults(AWhiteEngines, ABlackEngines,
  AResults: TStrings): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to AResults.Count - 1 do
    if ((AWhiteEngines[I] <> '') or (ABlackEngines[I] <> '')) and
      (not TournamentResultIsKnown(ParseTournamentResult(AResults[I]))) then
      Exit(True);
end;

function BuildTournamentButtonState(AIsSwiss, ATournamentRunning,
  APairingGridEmpty: Boolean; AWhiteEngines, ABlackEngines,
  AResults: TStrings): TTournamentButtonState;
begin
  if AIsSwiss then
    Result.CanCreatePairing := (not ATournamentRunning) and
      TournamentAllResultsKnown(AWhiteEngines, ABlackEngines, AResults)
  else
    Result.CanCreatePairing := (not ATournamentRunning) and
      APairingGridEmpty;

  Result.CanPlayRound := (not ATournamentRunning) and
    TournamentHasUnknownResults(AWhiteEngines, ABlackEngines, AResults);
  Result.CanStop := ATournamentRunning;
end;

function BuildTournamentPairingRound(AIsSwiss, ADoubleRoundRobin: Boolean;
  AEngines, AWhiteEngines, ABlackEngines, AResults,
  ARounds: TStrings): TTournamentPairingRound;
begin
  Result.HasRepeat := False;
  Result.RoundNumber := 1;
  SetLength(Result.Pairings, 0);

  if AIsSwiss then
  begin
    Result.RoundNumber := TournamentNextRoundNumber(ARounds);
    GenerateSwissPairings(AEngines, AWhiteEngines, ABlackEngines, AResults,
      ARounds, Result.Pairings, Result.HasRepeat);
  end
  else
    GenerateRoundRobinPairings(AEngines, ADoubleRoundRobin, Result.Pairings);
end;

function FindNextUnplayedTournamentRow(AIsSwiss: Boolean; AResults,
  ARounds: TStrings): Integer;
var
  I: Integer;
  LatestRound: Integer;
begin
  Result := 0;
  if not AIsSwiss then
  begin
    for I := 0 to AResults.Count - 1 do
      if not TournamentResultIsKnown(ParseTournamentResult(AResults[I])) then
        Exit(I + 1);
    Exit;
  end;

  LatestRound := 0;
  if ARounds <> nil then
    for I := 0 to ARounds.Count - 1 do
      if StrToIntDef(ARounds[I], 0) > LatestRound then
        LatestRound := StrToIntDef(ARounds[I], 0);

  for I := 0 to AResults.Count - 1 do
    if ((ARounds = nil) or (StrToIntDef(ARounds[I], 0) = LatestRound)) and
      (not TournamentResultIsKnown(ParseTournamentResult(AResults[I]))) then
      Exit(I + 1);
end;

procedure AppendPairing(var APairings: TTournamentPairingArray;
  const AWhite, ABlack: String);
var
  Index: Integer;
begin
  Index := Length(APairings);
  SetLength(APairings, Index + 1);
  APairings[Index].White := AWhite;
  APairings[Index].Black := ABlack;
end;

procedure GenerateRoundRobinPairings(AEngines: TStrings;
  ADoubleRoundRobin: Boolean; out APairings: TTournamentPairingArray);
var
  I: Integer;
  J: Integer;
begin
  SetLength(APairings, 0);
  for I := 0 to AEngines.Count - 2 do
    for J := I + 1 to AEngines.Count - 1 do
    begin
      AppendPairing(APairings, AEngines[I], AEngines[J]);
      if ADoubleRoundRobin then
        AppendPairing(APairings, AEngines[J], AEngines[I]);
    end;
end;

function TournamentAllResultsKnown(AWhiteEngines, ABlackEngines,
  AResults: TStrings): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to AResults.Count - 1 do
    if ((AWhiteEngines[I] <> '') or (ABlackEngines[I] <> '')) and
      (not TournamentResultIsKnown(ParseTournamentResult(AResults[I]))) then
      Exit(False);
end;

function TournamentNextRoundNumber(ARounds: TStrings): Integer;
var
  I: Integer;
begin
  Result := 1;
  for I := 0 to ARounds.Count - 1 do
    if StrToIntDef(ARounds[I], 0) >= Result then
      Result := StrToIntDef(ARounds[I], 0) + 1;
end;

function PairingAlreadyPlayed(AWhiteEngines, ABlackEngines: TStrings;
  const A, B: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to AWhiteEngines.Count - 1 do
    if (SameText(AWhiteEngines[I], A) and SameText(ABlackEngines[I], B)) or
      (SameText(AWhiteEngines[I], B) and SameText(ABlackEngines[I], A)) then
      Exit(True);
end;

function EngineHadBye(AWhiteEngines, ABlackEngines: TStrings;
  const AEngine: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to AWhiteEngines.Count - 1 do
    if SameText(AWhiteEngines[I], AEngine) and SameText(ABlackEngines[I],
      'BYE') then
      Exit(True);
end;

procedure GenerateSwissPairings(AEngines, AWhiteEngines, ABlackEngines,
  AResults, ARounds: TStrings; out APairings: TTournamentPairingArray;
  out AHasRepeat: Boolean);
var
  ByeIndex: Integer;
  ColorBalance: array of Integer;
  I: Integer;
  J: Integer;
  Order: array of Integer;
  Paired: array of Boolean;
  Scores: array of Integer;
  Temp: Integer;
  ByeName: String;

  function ComesBefore(AIndex, BIndex: Integer): Boolean;
  begin
    if Scores[AIndex] <> Scores[BIndex] then
      Exit(Scores[AIndex] > Scores[BIndex]);
    Result := AnsiCompareText(AEngines[AIndex], AEngines[BIndex]) < 0;
  end;

  procedure AddScore(const AName: String; APoints: Integer);
  var
    Index: Integer;
  begin
    Index := AEngines.IndexOf(AName);
    if Index >= 0 then
      Inc(Scores[Index], APoints);
  end;

  procedure AddColor(const AName: String; ADelta: Integer);
  var
    Index: Integer;
  begin
    Index := AEngines.IndexOf(AName);
    if Index >= 0 then
      Inc(ColorBalance[Index], ADelta);
  end;

  function PairPenalty(AIndex, BIndex: Integer): Integer;
  begin
    Result := Abs(Scores[AIndex] - Scores[BIndex]);
    if PairingAlreadyPlayed(AWhiteEngines, ABlackEngines, AEngines[AIndex],
      AEngines[BIndex]) then
      Inc(Result, 10000);
  end;

  function FindBestOpponent(AOrderIndex: Integer): Integer;
  var
    Candidate: Integer;
    CandidatePenalty: Integer;
    BestPenalty: Integer;
  begin
    Result := -1;
    BestPenalty := MaxInt;
    for Candidate := AOrderIndex + 1 to High(Order) do
    begin
      if Paired[Order[Candidate]] then
        Continue;
      CandidatePenalty := PairPenalty(Order[AOrderIndex], Order[Candidate]);
      if CandidatePenalty < BestPenalty then
      begin
        BestPenalty := CandidatePenalty;
        Result := Candidate;
      end;
    end;
  end;

  procedure AppendBalancedPairing(AIndex, BIndex: Integer);
  begin
    if ColorBalance[AIndex] > ColorBalance[BIndex] then
      AppendPairing(APairings, AEngines[BIndex], AEngines[AIndex])
    else if ColorBalance[BIndex] > ColorBalance[AIndex] then
      AppendPairing(APairings, AEngines[AIndex], AEngines[BIndex])
    else
      AppendPairing(APairings, AEngines[AIndex], AEngines[BIndex]);
  end;

begin
  SetLength(APairings, 0);
  AHasRepeat := False;
  ByeName := '';
  if AEngines.Count < 2 then
    Exit;

  if ARounds = nil then
    Exit;

  SetLength(ColorBalance, AEngines.Count);
  SetLength(Order, AEngines.Count);
  SetLength(Paired, AEngines.Count);
  SetLength(Scores, AEngines.Count);
  for I := 0 to AEngines.Count - 1 do
    Order[I] := I;

  for I := 0 to AResults.Count - 1 do
  begin
    AddScore(AWhiteEngines[I],
      TournamentResultPointsForWhite(ParseTournamentResult(AResults[I])));
    AddScore(ABlackEngines[I],
      TournamentResultPointsForBlack(ParseTournamentResult(AResults[I])));

    if not SameText(ABlackEngines[I], 'BYE') then
    begin
      AddColor(AWhiteEngines[I], 1);
      AddColor(ABlackEngines[I], -1);
    end;
  end;

  for I := 0 to High(Order) - 1 do
    for J := I + 1 to High(Order) do
      if not ComesBefore(Order[I], Order[J]) then
      begin
        Temp := Order[I];
        Order[I] := Order[J];
        Order[J] := Temp;
      end;

  if Odd(AEngines.Count) then
  begin
    ByeIndex := -1;
    for I := High(Order) downto 0 do
      if not EngineHadBye(AWhiteEngines, ABlackEngines, AEngines[Order[I]]) then
      begin
        ByeIndex := Order[I];
        Break;
      end;
    if ByeIndex < 0 then
      ByeIndex := Order[High(Order)];
    Paired[ByeIndex] := True;
    ByeName := AEngines[ByeIndex];
  end;

  for I := 0 to High(Order) do
  begin
    if Paired[Order[I]] then
      Continue;

    J := FindBestOpponent(I);
    if J < 0 then
      Break;

    if PairingAlreadyPlayed(AWhiteEngines, ABlackEngines, AEngines[Order[I]],
      AEngines[Order[J]]) then
      AHasRepeat := True;
    AppendBalancedPairing(Order[I], Order[J]);
    Paired[Order[I]] := True;
    Paired[Order[J]] := True;
  end;

  if ByeName <> '' then
    AppendPairing(APairings, ByeName, 'BYE');
end;

function TournamentPairingRowsEmpty(AWhiteEngines, ABlackEngines: TStrings): Boolean;
var
  I: Integer;
begin
  Result := True;
  for I := 0 to AWhiteEngines.Count - 1 do
    if (AWhiteEngines[I] <> '') or (ABlackEngines[I] <> '') then
      Exit(False);
end;

end.
