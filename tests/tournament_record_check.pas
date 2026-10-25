program tournament_record_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, FPJSON, JSONParser, uTournamentStorage, uTournamentGameRecord, uPdn;
procedure Check(Condition: Boolean; const MessageText: string);
begin
  if not Condition then
    raise Exception.Create(MessageText);
end;
procedure CheckProjectionIdentity;
var FileName: string; Text: TStringList;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd-id');
  Text := TStringList.Create;
  try
    Text.Text := '[Event "One"] [TournamentId "ours"] 1. 32-28 {' +
      StringOfChar('c', 70000) + '} *' + LineEnding +
      '[Event "Two"] [TournamentId "ours"] 1. 33-28 *';
    Text.SaveToFile(FileName);
    Check(TournamentPdnMatchesId(FileName, 'ours'), 'headers-only ownership across buffers');
    Text.Text := Text.Text + LineEnding + '[Event "Other"] [TournamentId "theirs"] *';
    Text.SaveToFile(FileName);
    Check(not TournamentPdnMatchesId(FileName, 'ours'), 'mixed identities must not establish ownership');
    Text.Text := '{[TournamentId "ours"]} 1. 32-28 *';
    Text.SaveToFile(FileName);
    Check(not TournamentPdnMatchesId(FileName, 'ours'), 'comment must not establish ownership');
    Text.Text := '[TournamentId "ours"';
    Text.SaveToFile(FileName);
    Check(not TournamentPdnMatchesId(FileName, 'ours'), 'malformed tag must not establish ownership');
  finally Text.Free; DeleteFile(FileName); end;
end;

procedure CheckStreamedDocument;
var
  Data, ReadBack: TJSONData;
  Text: string;
begin
  SetMultiByteConversionCodePage(CP_UTF8);
  Data := GetJSON('{"name":"Gérard \"test\"", "path":"C:\\Games",' +
    '"nested":[null,true,false,-1.5,{"line\\key":"comment\nnext\tcolumn"}]}');
  ReadBack := nil;
  try
    Text := TournamentDocumentText(Data);
    ReadBack := GetJSON(UTF8String(Text));
    Check(Data.AsJSON = ReadBack.AsJSON, 'streamed JSON must preserve types, escaping and Unicode');
  finally
    ReadBack.Free;
    Data.Free;
  end;
end;

var
  RecordData, Reloaded: TTournamentGameRecord;
  Wrapper: TJSONObject;
  Lines: TStringList;
  Games: TList;
  PdnText, FileName: string;
  I: Integer;
begin
  CheckProjectionIdentity;
  CheckStreamedDocument;
  RecordData := TTournamentGameRecord.Create;
  Reloaded := TTournamentGameRecord.Create;
  Lines := TStringList.Create;
  Games := TList.Create;
  FileName := GetTempFileName(GetTempDir, 'gwd-record');
  Wrapper := TJSONObject.Create;
  try
    RecordData.RecordPlayedGame('[Event "Original"]' + LineEnding +
      '[White "White"]' + LineEnding + '[Black "Black"]' + LineEnding +
      '[Result "1-0"]' + LineEnding + '[FEN "W:W31-50:B1-20"]' +
      LineEnding + LineEnding +
      '1. 32-28 {Main comment} 18-23 (1... 20-24 {Outer} ' +
      '2. 37-32 (2. 38-32 {Nested}) 14-20) 2. 37-32 1-0', '2-0');
    RecordData.OverrideResult('1-1');
    Wrapper.Add('record', RecordData.ToJson);
    Reloaded.LoadFromJson(Wrapper);
    Check(Reloaded.EffectiveResult = '1-1', 'override must persist');
    Check(Reloaded.PlayedResult = '2-0', 'played result must persist separately');
    PdnText := Reloaded.RenderPdn('stable-id', 'Renamed event', '3', '12',
      'White', 'Black', 'W:W31-50:B1-20');
    Check(Pos('37-32 (2. 38-32 {Nested}) 14-20)', PdnText) > 0,
      'result correction must preserve nested movetext and comments');
    Check(Pos('[Event "Renamed event"]', PdnText) > 0, 'event projection');
    Check(Pos('[PlayedResult "2-0"]', PdnText) > 0, 'explicit original result');
    Lines.Text := PdnText;
    Lines.SaveToFile(FileName);
    LoadPdnGamesFromFile(FileName, Games);
    Check(Games.Count = 1, 'corrected projection must contain one complete game');
    Check(TPdnGame(Games[0]).ResultText = '1-1', 'corrected result must reload');
    Check(TPdnGame(Games[0]).MovesText = '32-28 18-23 37-32', 'mainline preservation');
    Check(Pos('Nested', TPdnGame(Games[0]).MoveVariationAnnotationsText) > 0,
      'nested commentary preservation');
    Reloaded.Reschedule;
    Check((Reloaded.Attempt = 2) and not Reloaded.HasRecord,
      'rescheduling must begin an empty new attempt');
    Wrapper.Free;
    Wrapper := Reloaded.ToJson;
    Check(TJSONArray(Wrapper.Find('history')).Count = 1, 'prior attempt retained');
    Check(TJSONObject(TJSONArray(Wrapper.Find('history'))[0]).Get(
      'manual_result', '') = '1-1', 'prior manual result retained');
    Check(Reloaded.RenderPdn('id', 'event', '3', '12', '', '', '') = '',
      'an unplayed replacement must not duplicate its old attempt in PDN');
  finally
    for I := 0 to Games.Count - 1 do
      TObject(Games[I]).Free;
    DeleteFile(FileName);
    Wrapper.Free;
    Games.Free;
    Lines.Free;
    Reloaded.Free;
    RecordData.Free;
  end;
  WriteLn('OK');
end.
