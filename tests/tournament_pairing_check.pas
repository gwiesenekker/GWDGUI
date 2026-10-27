program tournament_pairing_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uTournamentPairing, uDraughtsPosition;
procedure Check(Condition: Boolean; const Text: string);
begin if not Condition then raise Exception.Create(Text); end;
procedure CheckRoundRobin(N: Integer; DoubleRound: Boolean);
var Engines: TStringList; Pairs: TTournamentPairingArray; I, J, A, B, Expected: Integer;
  Counts, InRound: array of array of Integer;
  RoundCount, Run, K: Integer; Balance: array of Integer; Colours: array of string;
begin
  Engines := TStringList.Create;
  try
    for I := 0 to N - 1 do Engines.Add('Engine ' + IntToStr(I));
    RoundCount := N - 1 + Ord(Odd(N));
    if DoubleRound then RoundCount *= 2;
    SetLength(InRound, RoundCount + 1, N);
    SetLength(Counts, N, N); SetLength(Balance, N); SetLength(Colours, N);
    GenerateRoundRobinPairings(Engines, DoubleRound, Pairs);
    Expected := N * (N - 1) div 2;
    if DoubleRound then Expected *= 2;
    Check(Length(Pairs) = Expected, 'round robin game count');
    for I := 0 to High(Pairs) do
    begin
      A := Engines.IndexOf(Pairs[I].White); B := Engines.IndexOf(Pairs[I].Black);
      Check((A >= 0) and (B >= 0) and (A <> B), 'round robin participants');
      Check((Pairs[I].RoundNumber >= 1) and (Pairs[I].RoundNumber <= RoundCount), 'real round number');
      Inc(InRound[Pairs[I].RoundNumber, A]); Inc(InRound[Pairs[I].RoundNumber, B]);
      Check((InRound[Pairs[I].RoundNumber, A] = 1) and (InRound[Pairs[I].RoundNumber, B] = 1),
        'a participant must not play twice in one round');
      Inc(Counts[A, B]); Inc(Balance[A]); Dec(Balance[B]);
      Colours[A] += 'W'; Colours[B] += 'B';
    end;
    for I := 0 to N - 1 do
    begin
      Check(Abs(Balance[I]) <= Ord(not DoubleRound), 'round robin colors must be balanced');
      Run := 1;
      for K := 2 to Length(Colours[I]) do
      begin
        if Colours[I][K] = Colours[I][K - 1] then Inc(Run) else Run := 1;
        Check(Run <= 2, 'round robin colours must not have long same-colour streaks');
      end;
      for J := I + 1 to N - 1 do
        Check(Counts[I, J] + Counts[J, I] = 1 + Ord(DoubleRound), 'every pair must meet once per leg');
    end;
  finally Engines.Free; end;
end;
procedure CheckSwissAvoidsGreedyRepeat;
var Engines, White, Black, Results, Rounds: TStringList;
  Pairs: TTournamentPairingArray; HasRepeat: Boolean; I: Integer; Seen: TStringList;
begin
  Engines := TStringList.Create; White := TStringList.Create;
  Black := TStringList.Create; Results := TStringList.Create;
  Rounds := TStringList.Create; Seen := TStringList.Create;
  try
    Engines.CommaText := 'A,B,C,D';
    White.CommaText := 'A,B,C'; Black.CommaText := 'D,C,D';
    Results.CommaText := '2-0,2-0,1-1'; Rounds.CommaText := '1,1,2';
    GenerateSwissPairings(Engines, White, Black, Results, Rounds, Pairs, HasRepeat);
    Check(not HasRepeat and (Length(Pairs) = 2), 'Swiss must backtrack before proposing an avoidable repeat');
    for I := 0 to High(Pairs) do
    begin
      Check((Seen.IndexOf(Pairs[I].White) < 0) and (Seen.IndexOf(Pairs[I].Black) < 0),
        'Swiss participants must appear once');
      Seen.Add(Pairs[I].White); Seen.Add(Pairs[I].Black);
      Check(((Pairs[I].White = 'A') and (Pairs[I].Black = 'C')) or
        ((Pairs[I].White = 'C') and (Pairs[I].Black = 'A')) or
        ((Pairs[I].White = 'B') and (Pairs[I].Black = 'D')) or
        ((Pairs[I].White = 'D') and (Pairs[I].Black = 'B')), 'use the available nonrepeat matching');
    end;
    White.CommaText := 'A,A,A,B,B,C'; Black.CommaText := 'B,C,D,C,D,D';
    Results.CommaText := '1-1,1-1,1-1,1-1,1-1,1-1';
    GenerateSwissPairings(Engines, White, Black, Results, Rounds, Pairs, HasRepeat);
    Check(HasRepeat and (Length(Pairs) = 2), 'an exhausted opponent graph must still produce a labelled proposal');
  finally Seen.Free; Rounds.Free; Results.Free; Black.Free; White.Free; Engines.Free; end;
end;

procedure CheckGeneralMatchingAgainstOracle;
var Engines, White, Black, Results, Rounds: TStringList;
  Allowed: array[0..5, 0..5] of Boolean;
  Pairs: TTournamentPairingArray; Repeated: Boolean;
  Graph, A, B, Bit, I, Fresh: Integer;
  function MaximumPairs(Mask: Integer): Integer;
  var First, Other, Value: Integer;
  begin
    if Mask = 0 then Exit(0);
    First := 0; while (Mask and (1 shl First)) = 0 do Inc(First);
    Mask := Mask and not (1 shl First);
    Result := MaximumPairs(Mask);
    for Other := First + 1 to 5 do
      if ((Mask and (1 shl Other)) <> 0) and Allowed[First, Other] then
      begin
        Value := 1 + MaximumPairs(Mask and not (1 shl Other));
        if Value > Result then Result := Value;
      end;
  end;
begin
  Engines := TStringList.Create; White := TStringList.Create; Black := TStringList.Create;
  Results := TStringList.Create; Rounds := TStringList.Create;
  try
    Engines.CommaText := 'A,B,C,D,E,F';
    for Graph := 0 to (1 shl 15) - 1 do
    begin
      White.Clear; Black.Clear; Results.Clear; Rounds.Clear; Bit := 0;
      for A := 0 to 5 do for B := A + 1 to 5 do
      begin
        Allowed[A, B] := (Graph and (1 shl Bit)) <> 0;
        Allowed[B, A] := Allowed[A, B]; Inc(Bit);
        if not Allowed[A, B] then
        begin White.Add(Engines[A]); Black.Add(Engines[B]); Results.Add('1-1'); Rounds.Add('1'); end;
      end;
      GenerateSwissPairings(Engines, White, Black, Results, Rounds, Pairs, Repeated);
      Check(Length(Pairs) = 3, 'every six-vertex graph yields a full proposal');
      Fresh := 0;
      for I := 0 to High(Pairs) do
        if Allowed[Engines.IndexOf(Pairs[I].White), Engines.IndexOf(Pairs[I].Black)] then Inc(Fresh);
      Check(Fresh = MaximumPairs(63), 'general matching must maximize fresh opponents, including odd cycles');
      Check(Repeated = (Fresh < 3), 'repeat flag must agree with the maximum matching');
    end;
  finally Rounds.Free; Results.Free; Black.Free; White.Free; Engines.Free; end;
end;

procedure CheckLargeSwissResponsiveness;
var Engines, White, Black, Results, Rounds: TStringList;
  Pairs: TTournamentPairingArray; Repeated: Boolean; I, Round: Integer; Tick: QWord;
begin
  Engines := TStringList.Create; White := TStringList.Create; Black := TStringList.Create;
  Results := TStringList.Create; Rounds := TStringList.Create;
  try
    for I := 1 to 40 do Engines.Add(Format('Engine %.2d', [I]));
    Tick := GetTickCount64;
    for Round := 1 to 25 do
    begin
      GenerateSwissPairings(Engines, White, Black, Results, Rounds, Pairs, Repeated);
      Check((Length(Pairs) = 20) and not Repeated, 'large Swiss fixture retains a fresh matching');
      for I := 0 to High(Pairs) do
      begin White.Add(Pairs[I].White); Black.Add(Pairs[I].Black); Results.Add('1-1'); Rounds.Add(IntToStr(Round)); end;
    end;
    Check(GetTickCount64 - Tick < 1000, '40-engine Swiss rounds must not freeze the GUI for seconds');
  finally Rounds.Free; Results.Free; Black.Free; White.Free; Engines.Free; end;
end;

var N: Integer;
begin
  CheckGeneralMatchingAgainstOracle;
  CheckLargeSwissResponsiveness;
  CheckSwissAvoidsGreedyRepeat;
  for N := 2 to 12 do begin CheckRoundRobin(N, False); CheckRoundRobin(N, True); end;
  Writeln('OK');
end.
