program endgame_draw_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Classes, SysUtils, uDraughtsBoard, uDraughtsDrawRules, uGameOrchestrator;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then raise Exception.Create(Text); end;
procedure CheckLimits;
var Counter: TEndgameDrawCounter; Board: TDraughtsBoard; I: Integer;
begin
  Board := TDraughtsBoard.Create;
  try
    Board.LoadFromFEN('W:WK46,K47,K48:BK1'); Counter.Start(Board);
    for I := 1 to 31 do
    begin Counter.AfterMove(Board); Check(Counter.DrawMoveLimit = 0, '16 full moves required'); end;
    Counter.AfterMove(Board); Check(Counter.DrawMoveLimit = 16, '16-move limit reached');
    Board.LoadFromFEN('B:WK46:BK1,K2,3'); Counter.Start(Board);
    for I := 1 to 30 do Counter.AfterMove(Board);
    Board.LoadFromFEN('B:WK46:BK1,3'); // capture: five-move clock starts, 16 clock continues
    Counter.AfterMove(Board); Check(Counter.DrawMoveLimit = 0, 'capture does not end the limit early');
    Counter.AfterMove(Board); Check(Counter.DrawMoveLimit = 16, 'capture must not reset 16-move clock');
    Board.LoadFromFEN('W:WK46,47:BK1'); Counter.Start(Board);
    for I := 1 to 9 do Counter.AfterMove(Board);
    Check(Counter.DrawMoveLimit = 0, 'five full moves required');
    Counter.AfterMove(Board); Check(Counter.DrawMoveLimit = 5, 'king plus man versus king limit');
    Board.LoadFromFEN('B:WK46:BK1'); Counter.Start(Board);
    for I := 1 to 10 do Counter.AfterMove(Board);
    Check(Counter.DrawMoveLimit = 5, 'king versus king limit with Black starting');
    Board.LoadFromFEN('W:W46,47,48:BK1'); Counter.Start(Board);
    for I := 1 to 32 do Counter.AfterMove(Board);
    Check(Counter.DrawMoveLimit = 0, 'three men without a king do not start the limit');
    Board.SetBeginPosition; Counter.Start(Board);
    for I := 1 to 40 do Counter.AfterMove(Board);
    Check(Counter.DrawMoveLimit = 0, 'new game resets all limits');
    Board.LoadFromFEN('W:WK46,K47,K48:BK1'); Counter.AfterMove(Board);
    for I := 1 to 31 do Counter.AfterMove(Board);
    Check(Counter.DrawMoveLimit = 0, 'first qualifying position is the start, not a counted move');
    Counter.AfterMove(Board); Check(Counter.DrawMoveLimit = 16, 'entered material limit counted correctly');
  finally Board.Free; end;
end;
procedure CheckPlayedFiveMoveDraw;
var Game: TGameOrchestrator; Candidate: TDraughtsBoard; Seen: TStringList;
  Ply, I: Integer; Move: string; Found: Boolean;
begin
  Game := TGameOrchestrator.Create; Candidate := TDraughtsBoard.Create; Seen := TStringList.Create;
  try
    Game.NewGame('W:WK46:BK1'); Seen.Add(Game.Board.PositionKey);
    for Ply := 1 to 10 do
    begin
      Found := False;
      for I := 0 to Game.Board.LegalMoveCount - 1 do
      begin
        Move := Game.Board.LegalMoves[I]; Candidate.AssignFrom(Game.Board);
        Candidate.PlayMove(Move);
        if (Candidate.LegalMoveCount > 0) and (Seen.IndexOf(Candidate.PositionKey) < 0) and
          (Pos('x', Move) = 0) then begin Found := True; Break; end;
      end;
      Check(Found, 'draw fixture has a fresh nonterminal continuation');
      Game.PlayMove(Move, Game.CurrentSide, 0, 'test'); Seen.Add(Game.Board.PositionKey);
      if Ply < 10 then Check(Game.State = gosRunning, 'no premature five-move draw');
    end;
    Check((Game.GameResult = '1-1') and (Pos('5-move', Game.Log.Text) > 0), 'orchestrator applies five-move rule');
    Game.NewGame('W:WK32:B27');
    Game.PlayMove(Game.Board.LegalMoves[0], dsWhite, 0, 'test');
    Check(Game.GameResult = '2-0', 'terminal capture is a win rather than a draw');
  finally Seen.Free; Candidate.Free; Game.Free; end;
end;
begin CheckLimits; CheckPlayedFiveMoveDraw; WriteLn('OK'); end.
