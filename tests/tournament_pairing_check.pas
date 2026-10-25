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
var N: Integer;
begin
  for N := 2 to 12 do begin CheckRoundRobin(N, False); CheckRoundRobin(N, True); end;
  Writeln('OK');
end.
