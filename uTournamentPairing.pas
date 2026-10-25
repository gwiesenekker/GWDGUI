unit uTournamentPairing;

{$mode objfpc}{$H+}

interface

uses
  Classes;

type
  TTournamentPairing = record
    White: string;
    Black: string;
    RoundNumber: Integer;
  end;

  TTournamentPairingArray = array of TTournamentPairing;

  TTournamentPairingRound = record
    HasRepeat: Boolean;
    Pairings: TTournamentPairingArray;
    RoundNumber: Integer;
  end;

function BuildTournamentPairingRound(AIsSwiss, ADoubleRoundRobin: Boolean;
  AEngines, AWhiteEngines, ABlackEngines, AResults,
  ARounds: TStrings): TTournamentPairingRound;
function TournamentAllResultsKnown(AWhiteEngines, ABlackEngines,
  AResults: TStrings): Boolean;
function TournamentNextRoundNumber(ARounds: TStrings): Integer;
procedure GenerateRoundRobinPairings(AEngines: TStrings;
  ADoubleRoundRobin: Boolean; out APairings: TTournamentPairingArray);
procedure GenerateSwissPairings(AEngines, AWhiteEngines, ABlackEngines,
  AResults, ARounds: TStrings; out APairings: TTournamentPairingArray;
  out AHasRepeat: Boolean);

implementation

uses
  SysUtils, uTournamentResults;

procedure AppendPairing(var APairings: TTournamentPairingArray;
  const AWhite, ABlack: string; ARoundNumber: Integer = 1);
var
  Index: Integer;
begin
  Index := Length(APairings);
  SetLength(APairings, Index + 1);
  APairings[Index].White := AWhite;
  APairings[Index].Black := ABlack;
  APairings[Index].RoundNumber := ARoundNumber;
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

procedure GenerateRoundRobinPairings(AEngines: TStrings;
  ADoubleRoundRobin: Boolean; out APairings: TTournamentPairingArray);
var Slots: array of Integer; N, Round, I, A, B, Last, FirstLegCount: Integer;
begin
  SetLength(APairings, 0);
  if AEngines.Count < 2 then Exit;
  N := AEngines.Count;
  if Odd(N) then Inc(N); // A virtual participant supplies the bye.
  SetLength(Slots, N);
  for I := 0 to N - 1 do Slots[I] := I;
  if Odd(AEngines.Count) then
  begin
    Slots[0] := AEngines.Count; // Fix the bye so actual players alternate colours.
    for I := 1 to N - 1 do Slots[I] := I - 1;
  end;
  for Round := 1 to N - 1 do
  begin
    for I := 0 to N div 2 - 1 do
    begin
      A := Slots[I]; B := Slots[N - 1 - I];
      if (A >= AEngines.Count) or (B >= AEngines.Count) then Continue;
      if ((I = 0) and not Odd(Round)) or ((I > 0) and Odd(I)) then
        AppendPairing(APairings, AEngines[B], AEngines[A], Round)
      else AppendPairing(APairings, AEngines[A], AEngines[B], Round);
    end;
    Last := Slots[N - 1];
    for I := N - 1 downto 2 do Slots[I] := Slots[I - 1];
    Slots[1] := Last;
  end;
  if ADoubleRoundRobin then
  begin
    FirstLegCount := Length(APairings);
    // Reverse the mirrored leg so the turn-around cannot concatenate colour runs.
    for I := FirstLegCount - 1 downto 0 do
      AppendPairing(APairings, APairings[I].Black, APairings[I].White,
        2 * (N - 1) + 1 - APairings[I].RoundNumber);
  end;
end;

function EngineHadBye(AWhiteEngines, ABlackEngines: TStrings;
  const AEngine: string): Boolean;
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
  ByeName: string;
  Choices: array of Integer;
  Played: array of array of Boolean;
  Parent, Base, Queue: array of Integer;
  Used, Blossom: array of Boolean;

  function ComesBefore(AIndex, BIndex: Integer): Boolean;
  begin
    if Scores[AIndex] <> Scores[BIndex] then
      Exit(Scores[AIndex] > Scores[BIndex]);
    Result := AnsiCompareText(AEngines[AIndex], AEngines[BIndex]) < 0;
  end;

  procedure AddScore(const AName: string; APoints: Integer);
  var
    Index: Integer;
  begin
    Index := AEngines.IndexOf(AName);
    if Index >= 0 then
      Inc(Scores[Index], APoints);
  end;

  procedure AddColor(const AName: string; ADelta: Integer);
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
    if Played[AIndex, BIndex] then
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

  function CommonBase(A, B: Integer): Integer;
  var Seen: array of Boolean;
  begin
    SetLength(Seen, AEngines.Count);
    while True do
    begin
      A := Base[A]; Seen[A] := True;
      if Choices[A] < 0 then Break;
      A := Parent[Choices[A]];
    end;
    while True do
    begin
      B := Base[B];
      if Seen[B] then Exit(B);
      B := Parent[Choices[B]];
    end;
  end;

  procedure MarkBlossomPath(V, RootBase, Child: Integer);
  begin
    while Base[V] <> RootBase do
    begin
      Blossom[Base[V]] := True; Blossom[Base[Choices[V]]] := True;
      Parent[V] := Child; Child := Choices[V]; V := Parent[Choices[V]];
    end;
  end;

  function AugmentFrom(Root: Integer): Boolean;
  var Head, Tail, V, U, K, L, RootBase, Previous, Next: Integer;
  begin
    for K := 0 to High(Order) do
    begin Parent[K] := -1; Base[K] := K; Used[K] := False; end;
    Head := 0; Tail := 1; Queue[0] := Root; Used[Root] := True;
    while Head < Tail do
    begin
      V := Queue[Head]; Inc(Head);
      for K := 0 to High(Order) do
      begin
        U := Order[K];
        if Paired[U] or (U = V) or Played[V, U] or
          (Base[V] = Base[U]) or (Choices[V] = U) then Continue;
        if (U = Root) or ((Choices[U] >= 0) and (Parent[Choices[U]] >= 0)) then
        begin
          RootBase := CommonBase(V, U);
          for L := 0 to High(Order) do Blossom[L] := False;
          MarkBlossomPath(V, RootBase, U); MarkBlossomPath(U, RootBase, V);
          for L := 0 to High(Order) do
            if Blossom[Base[L]] then
            begin
              Base[L] := RootBase;
              if not Used[L] then begin Used[L] := True; Queue[Tail] := L; Inc(Tail); end;
            end;
        end
        else if Parent[U] < 0 then
        begin
          Parent[U] := V;
          if Choices[U] < 0 then
          begin
            while U >= 0 do
            begin
              Previous := Parent[U]; Next := -1;
              if Previous >= 0 then Next := Choices[Previous];
              Choices[U] := Previous;
              if Previous >= 0 then Choices[Previous] := U;
              U := Next;
            end;
            Exit(True);
          end;
          U := Choices[U];
          if not Used[U] then begin Used[U] := True; Queue[Tail] := U; Inc(Tail); end;
        end;
      end;
    end;
    Result := False;
  end;

  procedure FindNonRepeatMatching;
  var K: Integer;
  begin
    // Edmonds augmenting paths with odd-cycle contraction: polynomial matching
    // replaces exponential backtracking while keeping score order as a preference.
    for K := 0 to High(Order) do
      if not Paired[Order[K]] and (Choices[Order[K]] < 0) then AugmentFrom(Order[K]);
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
  if (AEngines.Count < 2) or (ARounds = nil) then
    Exit;

  SetLength(ColorBalance, AEngines.Count);
  SetLength(Order, AEngines.Count);
  SetLength(Paired, AEngines.Count);
  SetLength(Scores, AEngines.Count);
  SetLength(Played, AEngines.Count, AEngines.Count);
  SetLength(Parent, AEngines.Count); SetLength(Base, AEngines.Count);
  SetLength(Queue, AEngines.Count); SetLength(Used, AEngines.Count); SetLength(Blossom, AEngines.Count);
  for I := 0 to AWhiteEngines.Count - 1 do
  begin
    J := AEngines.IndexOf(AWhiteEngines[I]); Temp := AEngines.IndexOf(ABlackEngines[I]);
    if (J >= 0) and (Temp >= 0) then begin Played[J, Temp] := True; Played[Temp, J] := True; end;
  end;
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

  SetLength(Choices, AEngines.Count);
  for I := 0 to High(Choices) do Choices[I] := -1;
  FindNonRepeatMatching;
  begin
    for I := 0 to High(Order) do
      if Choices[Order[I]] >= 0 then
      begin
        J := Choices[Order[I]];
        AppendBalancedPairing(Order[I], J);
        Paired[Order[I]] := True; Paired[J] := True;
        Choices[J] := -1; Choices[Order[I]] := -1;
      end;
  end;
  for I := 0 to High(Order) do
  begin
    if Paired[Order[I]] then
      Continue;
    J := FindBestOpponent(I);
    if J < 0 then
      Break;
    if Played[Order[I], Order[J]] then
      AHasRepeat := True;
    AppendBalancedPairing(Order[I], Order[J]);
    Paired[Order[I]] := True;
    Paired[Order[J]] := True;
  end;

  if ByeName <> '' then
    AppendPairing(APairings, ByeName, 'BYE');
end;

function BuildTournamentPairingRound(AIsSwiss, ADoubleRoundRobin: Boolean;
  AEngines, AWhiteEngines, ABlackEngines, AResults,
  ARounds: TStrings): TTournamentPairingRound;
var I: Integer;
begin
  Result.HasRepeat := False;
  Result.RoundNumber := 1;
  SetLength(Result.Pairings, 0);
  if AIsSwiss then
  begin
    Result.RoundNumber := TournamentNextRoundNumber(ARounds);
    GenerateSwissPairings(AEngines, AWhiteEngines, ABlackEngines, AResults,
      ARounds, Result.Pairings, Result.HasRepeat);
    for I := 0 to High(Result.Pairings) do Result.Pairings[I].RoundNumber := Result.RoundNumber;
  end
  else
    GenerateRoundRobinPairings(AEngines, ADoubleRoundRobin, Result.Pairings);
end;

end.
