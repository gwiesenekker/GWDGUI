program performance_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads, cwstring,{$ENDIF} Classes, SysUtils, md5,
  uDraughtsBoard, uPdn, uGameTree, uGameTreeActor, uGameTreeBuilder,
  uGameTreePdn, uGameOrchestrator;
var
  Games: TList; Game: TPdnGame; Root: TPdnMoveNode; Moves: TStringList;
  TreeActor, Actor: TGameTreeActor; Board: TDraughtsBoard;
  Rendered: TGameTreePdnRenderResult;
  RenderCount, ImportCount, ReplayCount, Samples, Sample, I, J, Nodes, Warnings, ActualNodes, ActualWarnings: Integer;
  Tick: QWord; Elapsed: QWord;
  RenderDigest, ImportDigest, ReplayDigest, Text, Digest: string;
procedure Check(Value: Boolean; const MessageText: string);
begin if not Value then raise Exception.Create(MessageText); end;
function CountArgument(Index, DefaultValue: Integer): Integer;
begin
  if ParamCount < Index then Exit(DefaultValue);
  Result := StrToInt(ParamStr(Index));
  Check(Result > 0, 'Iteration and sample counts must be positive');
end;
procedure Execute(AActor: TGameTreeActor; Command: TGameTreeCommand);
begin
  try AActor.ExecuteCommand(Command); Check(Command.Accepted, Command.ErrorText);
  finally Command.Free; end;
end;
function ImportGame(out ImportedNodes, ImportWarnings: Integer): TGameTreeActor;
var Command: TGameTreeCommand;
begin
  Result := TGameTreeActor.Create;
  try
    Execute(Result, Result.CreateRebuildFromInputsCommand(
      GameTreeHeaderInput('benchmark', Game.EventName, Game.WhiteName,
        Game.BlackName, Game.ResultText, Game.StartingFEN, False, DefaultTimeControl),
      GameTreeMainlineInput(Moves, nil, False, 0, 0, 0, 0),
      GameTreePvInput(False, 0, '', ''), GameTreePvInput(False, 0, '', '')));
    Command := Result.CreateImportPdnTreeCommand(Root);
    try
      Result.ExecuteCommand(Command); Check(Command.Accepted, Command.ErrorText);
      ImportedNodes := Command.ImportedMoveCount;
      ImportWarnings := Command.ImportWarnings.Count;
    finally Command.Free; end;
  except Result.Free; raise; end;
end;
procedure Report(const Operation: string; Count: Integer; Milliseconds: QWord;
  const OutputText: string; var ExpectedDigest: string);
var Hash: string;
begin
  Hash := MD5Print(MD5String(OutputText));
  if ExpectedDigest = '' then ExpectedDigest := Hash;
  Check(Hash = ExpectedDigest, Operation + ' output changed across samples');
  WriteLn(Operation, ',', Sample, ',', Count, ',', Milliseconds, ',',
    FormatFloat('0.000', Milliseconds / Count), ',', Length(OutputText), ',', Hash);
end;
begin
  DefaultFormatSettings.DecimalSeparator := '.';
  Check((ParamCount >= 1) and (ParamCount <= 5), 'Usage: performance_check fixture.pdn [renders imports replays samples]');
  RenderCount := CountArgument(2, 100); ImportCount := CountArgument(3, 10);
  ReplayCount := CountArgument(4, 30); Samples := CountArgument(5, 3);
  Games := TList.Create; Moves := TStringList.Create; Board := TDraughtsBoard.Create;
  Root := nil; TreeActor := nil;
  try
    LoadPdnGamesFromFile(ParamStr(1), Games);
    Check(Games.Count = 1, 'Benchmark fixture must contain exactly one game');
    Game := TPdnGame(Games[0]); Root := Game.BuildMoveTree;
    TextToMoveList(Game.MovesText, Moves);
    TreeActor := ImportGame(Nodes, Warnings);
    ImportDigest := MD5Print(MD5String(GameTreeToPdnText(TreeActor.GameTree)));
    RenderGameTreeMovesToPdn(TreeActor.GameTree, DefaultGameTreePdnRenderOptions, Rendered);
    RenderDigest := MD5Print(MD5String(Rendered.Text));
    Board.LoadFromFEN(Game.StartingFEN);
    for I := 0 to Moves.Count - 1 do Board.PlayMove(Moves[I], True, True);
    ReplayDigest := MD5Print(MD5String(Board.CurrentFEN));
    WriteLn('# plies=', Moves.Count, ' imported_nodes=', Nodes, ' import_warnings=', Warnings);
    WriteLn('# parser_warnings=', StringReplace(Game.ImportWarningsText, LineEnding, ' | ', [rfReplaceAll]));
    WriteLn('operation,sample,iterations,total_ms,ms_per_iteration,output_bytes,output_md5');
    for Sample := 1 to Samples do
    begin
      Tick := GetTickCount64;
      for J := 1 to ReplayCount do
      begin
        Board.LoadFromFEN(Game.StartingFEN);
        for I := 0 to Moves.Count - 1 do Board.PlayMove(Moves[I], True, True);
      end;
      Report('board_replay', ReplayCount, GetTickCount64 - Tick, Board.CurrentFEN, ReplayDigest);

      Tick := GetTickCount64;
      for J := 1 to RenderCount do
        RenderGameTreeMovesToPdn(TreeActor.GameTree, DefaultGameTreePdnRenderOptions, Rendered);
      Report('notation_render', RenderCount, GetTickCount64 - Tick, Rendered.Text, RenderDigest);

      Elapsed := 0;
      for J := 1 to ImportCount do
      begin
        Tick := GetTickCount64;
        Actor := ImportGame(ActualNodes, ActualWarnings);
        // Include actor destruction, but exclude export/fingerprinting from import timing.
        try
          Elapsed += GetTickCount64 - Tick;
          Check((ActualNodes = Nodes) and (ActualWarnings = Warnings),
            'Imported node or warning count changed');
          Text := GameTreeToPdnText(Actor.GameTree);
          Digest := MD5Print(MD5String(Text));
          Check(Digest = ImportDigest, 'Imported complete game changed');
        finally
          Tick := GetTickCount64; Actor.Free;
          Elapsed += GetTickCount64 - Tick;
        end;
      end;
      Report('actor_import', ImportCount, Elapsed, Text, ImportDigest);
    end;
  finally
    TreeActor.Free; Root.Free; Board.Free; Moves.Free;
    for I := 0 to Games.Count - 1 do TObject(Games[I]).Free;
    Games.Free;
  end;
end.
