program move_interaction_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, uDraughtsBoard, uMoveInteraction, uGameTree, uGameTreeActor, uGamePosition, uDraughtsPosition;
procedure Check(Value: Boolean; const Text: string);
begin
  if not Value then raise Exception.Create(Text);
end;
procedure CheckSelection(const Fen: string);
var
  Board: TDraughtsBoard;
  Position: TGamePosition;
  Interaction: TMoveInteraction;
  Choices, Targets, Matches: TStringList;
  Source, I, J, Target, Multi: Integer;
  Move, Found: string;
begin
  Board := TDraughtsBoard.Create;
  Interaction := TMoveInteraction.Create;
  Choices := TStringList.Create;
  Targets := TStringList.Create; Matches := TStringList.Create;
  Multi := 0;
  Position := nil;
  try
    Board.LoadFromFEN(Fen);
    Position := DraughtsVariant.CreatePositionFromFEN(Fen);
    for Source := 1 to 50 do
    begin
      Choices.Clear;
      Targets.Clear;
      for I := 0 to Board.LegalMoveCount - 1 do
        if MoveSquareAt(Board.LegalMoves[I], 1) = Source then
        begin
          Choices.Add(Board.LegalMoves[I]);
          Target := MoveSquareAt(Board.LegalMoves[I], 2);
          if Targets.IndexOf(IntToStr(Target)) < 0 then Targets.Add(IntToStr(Target));
        end;
      Move := Interaction.SelectSource(Position, Source);
      if Choices.Count = 1 then
        Check((Move = Choices[0]) and (Interaction.SourceSquare = 0),
          'a forced move plays immediately without retaining a selected source')
      else if Choices.Count = 0 then
        Check((Move = '') and (Interaction.SourceSquare = 0) and
          (Length(Interaction.Targets) = 0), 'empty source clears stale targets')
      else
      begin
        Inc(Multi);
        Check((Move = '') and (Interaction.SourceSquare = Source), 'ambiguous source waits');
        Check(Length(Interaction.Targets) = Targets.Count, 'deduplicate target squares');
        for I := 0 to Targets.Count - 1 do
          Check(Interaction.Targets[I] = StrToInt(Targets[I]), 'preserve target order');
        for I := 0 to Choices.Count - 1 do
        begin
          Target := MoveSquareAt(Choices[I], 2);
          Interaction.TargetChoices(Target, Matches);
          J := 0;
          while MoveSquareAt(Choices[J], 2) <> Target do Inc(J);
          if Matches.Count = 1 then
            Check(Interaction.FindTarget(Target, Found) and (Found = Choices[J]), 'unique target plays directly')
          else Check(not Interaction.FindTarget(Target, Found) and (Found = ''),
            'ambiguous target requires an explicit choice');
          for J := 0 to Matches.Count - 1 do
            Check(Choices.IndexOf(Matches[J]) >= 0, 'chooser returns canonical legal moves');
        end;
      end;
    end;
    Check(Multi > 0, 'fixture exercises multiple choices');
    Interaction.Clear;
    Check(not Interaction.FindTarget(1, Move) and (Move = ''), 'clear discards candidates');
    Interaction.SelectSource(nil, 32);
    Check(Interaction.SourceSquare = 0, 'missing board clears selection');
  finally
    Matches.Free; Targets.Free; Choices.Free; Interaction.Free; Board.Free; Position.Free;
  end;
end;
procedure CheckHighlights;
var Moves: TStringList; H: TMoveHighlights;
begin
  Moves := TStringList.Create;
  try
    Moves.Add('32-28'); Moves.Add('18-23');
    H := CalculateMoveHighlights(DraughtsVariant, '18-23', '37-32 12-18', True);
    Check((H.LastMoveTargetSquare = 23) and (H.PvSourceSquare = 37) and
      (H.HintSourceSquare = 12) and (H.PvTargetSquare = 32) and
      (H.HintTargetSquare = 18), 'following tip uses mainline target and matching PV sources');
    H := CalculateMoveHighlights(DraughtsVariant, '32-28', '20-24 38-32', False);
    Check((H.LastMoveTargetSquare = 28) and (H.PvSourceSquare = 0) and
      (H.HintSourceSquare = 0) and (H.PvTargetSquare = 0) and
      (H.HintTargetSquare = 0), 'historical position suppresses unrelated PV hints');
    H := CalculateMoveHighlights(DraughtsVariant, '', '32-28', True);
    Check((H.LastMoveTargetSquare = 0) and (H.PvSourceSquare = 32) and
      (H.HintSourceSquare = 0) and (H.PvTargetSquare = 28) and
      (H.HintTargetSquare = 0), 'root has no last move, one-move PV has no second hint');
    H := CalculateMoveHighlights(DraughtsVariant, '', '', True);
    Check((H.LastMoveTargetSquare = 0) and (H.PvSourceSquare = 0) and
      (H.HintSourceSquare = 0) and (H.PvTargetSquare = 0) and
      (H.HintTargetSquare = 0), 'empty PV and out-of-range ply clear highlights');
    H := CalculateMoveHighlights(DraughtsVariant, '19-24', '', False);
    Check(H.LastMoveTargetSquare = 24, 'variation uses its own target, not replaced mainline move');
    H := CalculateMoveHighlights(DraughtsVariant, '38x27x32', '', False);
    Check(H.LastMoveTargetSquare = 27, 'capture marker uses destination, not captured square');
    H := CalculateMoveHighlights(DraughtsVariant, '', '38x27x32 17x28x22', True);
    Check((H.PvSourceSquare = 38) and (H.PvTargetSquare = 27) and
      (H.HintSourceSquare = 17) and (H.HintTargetSquare = 28),
      'PV capture pairs use destinations rather than captured squares');
    Moves.Clear;
    H := CalculateMoveHighlights(DraughtsVariant, '', '', False);
    Check(H.LastMoveTargetSquare = 0, 'empty game has no last target');
  finally Moves.Free; end;
end;

var
  Actor: TGameTreeActor;
  Board: TGamePosition;
  Move: string;
  Command: TGameTreeCommand;
begin
  CheckHighlights;
  CheckSelection('W:W31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50:B1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20');
  CheckSelection('W:WK32:B27,28');
  CheckSelection('W:WK21:B31,39,14,17,19');
  Actor := TGameTreeActor.Create;
  Board := Actor.GameTree.Variant.CreatePosition;
  try
    Check(Actor.GameTree.TryBuildPositionAtNode(Actor.GameTree.Root, Board), 'initial replay');
    Check(RouteMove(Board, Actor.GameTree, Actor.GameTree.Root, '32-28',
      True, False, True, False, Move) = mrMainline, 'unfinished tip appends');
    Check(RouteMove(Board, Actor.GameTree, Actor.GameTree.Root, '32-28',
      True, False, False, True, Move) = mrVariation, 'finished tip explores despite runner flag');
    Check(RouteMove(Board, Actor.GameTree, Actor.GameTree.Root, '32-28',
      True, True, True, False, Move) = mrVariation, 'branch never appends official moves');
    Check(RouteMove(Board, Actor.GameTree, Actor.GameTree.Root, '32-28',
      False, False, True, True, Move) = mrRunner, 'live human turn posts to runner');
    Check(RouteMove(Board, Actor.GameTree, Actor.GameTree.Root, '32-28',
      False, False, True, False, Move) = mrNone, 'nonhuman turn does nothing');
    Check(RouteMove(Board, Actor.GameTree, Actor.GameTree.Root, '32-23',
      True, False, True, True, Move) = mrInvalid, 'illegal moves cannot reach any destination');
    Command := Actor.CreateAppendMainlineMoveCommand('32-28', gmsHuman);
    try Actor.ExecuteCommand(Command); Check(Command.Accepted, Command.ErrorText);
    finally Command.Free; end;
    Check(RouteMove(Board, Actor.GameTree, Actor.GameTree.Root, '31-26',
      True, False, True, False, Move) = mrVariation, 'historical mainline node explores');
    Check(Actor.GameTree.MainlineCount = 1, 'routing does not mutate the tree');
  finally Board.Free; Actor.Free; end;
  Writeln('Move interaction checks passed');
end.
