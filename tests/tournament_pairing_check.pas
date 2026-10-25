program tournament_pairing_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uTournamentPairing;
procedure Check(Condition: Boolean; const Text: string);
begin if not Condition then raise Exception.Create(Text); end;
procedure CheckRoundRobin(N: Integer; DoubleRound: Boolean);
var Engines: TStringList; Pairs: TTournamentPairingArray; I, J, A, B, Expected: Integer;
  Counts, InRound: array of array of Integer;
  RoundCount: Integer; Balance: array of Integer;
begin
  Engines := TStringList.Create;
  try
    for I := 0 to N - 1 do Engines.Add('Engine ' + IntToStr(I));
    RoundCount := N - 1 + Ord(Odd(N));
    if DoubleRound then RoundCount *= 2;
    SetLength(InRound, RoundCount + 1, N);
    SetLength(Counts, N, N); SetLength(Balance, N);
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
    end;
    for I := 0 to N - 1 do
    begin
      Check(Abs(Balance[I]) <= Ord(not DoubleRound), 'round robin colors must be balanced');
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

var N: Integer;
begin
  CheckSwissAvoidsGreedyRepeat;
  for N := 2 to 12 do begin CheckRoundRobin(N, False); CheckRoundRobin(N, True); end;
  Writeln('OK');
end.
