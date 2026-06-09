program pdn_regression_check;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, uDraughtsBoard, uGameMoveHistory, uPdn;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    Writeln('FAIL: ', AMessage);
    Halt(1);
  end;
end;

procedure CheckEqual(const AActual, AExpected, AMessage: string);
begin
  Check(AActual = AExpected, AMessage + '; expected="' + AExpected +
    '"; actual="' + AActual + '"');
end;

procedure ClearGames(AGames: TList);
var
  I: Integer;
begin
  for I := 0 to AGames.Count - 1 do
    TObject(AGames[I]).Free;
  AGames.Clear;
end;

procedure CheckPdnLoadAndAppend;
var
  FileName: string;
  Game: TPdnGame;
  Games: TList;
  Lines: TStringList;
begin
  FileName := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    'gwdgui_pdn_regression_check.pdn';
  Lines := TStringList.Create;
  Games := TList.Create;
  try
    Lines.Add('[Event "First"]');
    Lines.Add('[White "Alpha"]');
    Lines.Add('[Black "Beta"]');
    Lines.Add('[Result "1-1"]');
    Lines.Add('[FEN "W:W31-50:B1-20"]');
    Lines.Add('');
    Lines.Add('1. 34-30 {score=0.12} 20-25 {comment} 2. 32-28 1-1');
    Lines.Add('');
    Lines.Add('[Event "Second"]');
    Lines.Add('[White "Gamma"]');
    Lines.Add('[Black "Delta"]');
    Lines.Add('[Result "*"]');
    Lines.Add('');
    Lines.Add('1. 33-28 18-22 *');
    Lines.SaveToFile(FileName);

    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 2, 'two games should be parsed');
    Game := TPdnGame(Games[0]);
    CheckEqual(Game.EventName, 'First', 'first game event');
    CheckEqual(Game.WhiteName, 'Alpha', 'first game white');
    CheckEqual(Game.BlackName, 'Beta', 'first game black');
    CheckEqual(Game.ResultText, '1-1', 'first game result');
    CheckEqual(Game.MovesText, '34-30 20-25 32-28',
      'first game main line moves');
    CheckEqual(Game.MoveAnnotationsText, 'score=0.12' + LineEnding +
      LineEnding + LineEnding, 'first game score annotation');

    Game := TPdnGame.Create;
    try
      Game.EventName := 'Saved';
      Game.WhiteName := 'White';
      Game.BlackName := 'Black';
      Game.ResultText := '2-0';
      Game.StartingFEN := 'W:W31-50:B1-20';
      Game.MovesText := '34-30 20-25';
      Game.MoveAnnotationsText := 'score=0.25' + LineEnding +
        'score=-0.10' + LineEnding;
      AppendPdnGameToFile(FileName, Game);
    finally
      Game.Free;
    end;

    ClearGames(Games);
    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 3, 'saved game should be appended');
    CheckEqual(TPdnGame(Games[2]).EventName, 'Saved',
      'appended game event');
    CheckEqual(TPdnGame(Games[2]).MoveAnnotationsText,
      'score=0.25' + LineEnding + 'score=-0.10' + LineEnding,
      'appended game score annotations');
  finally
    ClearGames(Games);
    Games.Free;
    Lines.Free;
    if FileExists(FileName) then
      DeleteFile(FileName);
  end;
end;

procedure CheckMoveHistoryKeepsMoveAndAnnotationTogether;
var
  History: TGameMoveHistory;
  Moves: TStringList;
begin
  History := TGameMoveHistory.Create;
  Moves := TStringList.Create;
  try
    History.AddMove('034-030', dsWhite, 1.25, 'score=0.10', '30-25');
    History.AddMove('20-25', dsBlack, 0.75, 'score=-0.10', '');
    CheckEqual(History.MovesText, '34-30 20-25',
      'move history should expose pure canonical moves');
    CheckEqual(History.AnnotationsText, 'score=0.10' + LineEnding +
      'score=-0.10' + LineEnding,
      'move history should keep annotations aligned with moves');
    History.FillPureMoves(Moves);
    Check((Moves.Count = 2) and (Moves[0] = '34-30') and (Moves[1] = '20-25'),
      'move history should fill pure move lists for engine protocols');
  finally
    Moves.Free;
    History.Free;
  end;
end;

begin
  CheckPdnLoadAndAppend;
  CheckMoveHistoryKeepsMoveAndAnnotationTogether;
  Writeln('OK');
end.
