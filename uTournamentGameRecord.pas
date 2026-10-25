unit uTournamentGameRecord;
{$mode objfpc}{$H+}
interface
uses FPJSON;
type
  TTournamentGameRecord = class
  private
    FAttempt: Integer;
    FPdn: string;
    FPlayedResult: string;
    FManualResult: string;
    FHistory: TJSONArray;
    function CurrentJson: TJSONObject;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadFromJson(AGame: TJSONObject);
    function ToJson: TJSONObject;
    procedure RecordPlayedGame(const APdn, AResult: string);
    procedure OverrideResult(const AResult: string);
    procedure Reschedule;
    function HasRecord: Boolean;
    function EffectiveResult: string;
    function RenderPdn(const ATournamentId, AEvent, ARound, AGameNo,
      AWhite, ABlack, AFen: string): string;
    property Attempt: Integer read FAttempt;
    property ManualResult: string read FManualResult;
    property PlayedResult: string read FPlayedResult;
  end;
implementation
uses Classes, SysUtils, StrUtils, uPdn, uTournamentStorage;

constructor TTournamentGameRecord.Create;
begin
  inherited Create;
  FAttempt := 1;
  FHistory := TJSONArray.Create;
end;

destructor TTournamentGameRecord.Destroy;
begin
  FHistory.Free;
  inherited Destroy;
end;

function TTournamentGameRecord.CurrentJson: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.Add('attempt', FAttempt);
  Result.Add('pdn', FPdn);
  Result.Add('played_result', FPlayedResult);
  Result.Add('manual_result', FManualResult);
end;

function TTournamentGameRecord.ToJson: TJSONObject;
begin
  Result := CurrentJson;
  Result.Add('history', FHistory.Clone);
end;

procedure TTournamentGameRecord.LoadFromJson(AGame: TJSONObject);
var
  Data: TJSONObject;
  History: TJSONData;
begin
  Data := TJSONObject(AGame.Find('record'));
  if Data = nil then
  begin
    FPlayedResult := AGame.Get('result', '*');
    if FPlayedResult = '*' then
      FPlayedResult := '';
    if SameText(AGame.Get('reason', ''), 'Manual result') then
    begin
      FManualResult := AGame.Get('result', '*');
      FPlayedResult := '';
    end;
    Exit;
  end;
  FAttempt := Data.Get('attempt', 1);
  FPdn := Data.Get('pdn', '');
  FPlayedResult := Data.Get('played_result', '');
  FManualResult := Data.Get('manual_result', '');
  History := Data.Find('history');
  if History <> nil then
  begin
    FHistory.Free;
    FHistory := TJSONArray(History.Clone);
  end;
end;

procedure TTournamentGameRecord.RecordPlayedGame(const APdn, AResult: string);
begin
  FPdn := APdn;
  FPlayedResult := AResult;
  FManualResult := '';
end;

procedure TTournamentGameRecord.OverrideResult(const AResult: string);
begin
  if Trim(AResult) = '*' then FManualResult := ''
  else FManualResult := AResult;
end;

procedure TTournamentGameRecord.Reschedule;
begin
  if HasRecord then
    FHistory.Add(CurrentJson);
  Inc(FAttempt);
  FPdn := '';
  FPlayedResult := '';
  FManualResult := '';
end;

function TTournamentGameRecord.HasRecord: Boolean;
begin
  Result := (FPdn <> '') or (FPlayedResult <> '') or (FManualResult <> '');
end;

function TTournamentGameRecord.EffectiveResult: string;
begin
  Result := FManualResult;
  if Result = '' then
    Result := FPlayedResult;
  if Result = '' then
    Result := '*';
end;

function TTournamentGameRecord.RenderPdn(const ATournamentId, AEvent, ARound,
  AGameNo, AWhite, ABlack, AFen: string): string;
var
  Lines, Headers: TStringList;
  Output: TStringStream;
  I, FirstMoveLine: Integer;
  MovesText, OldResult, NewResult: string;

  procedure SetTag(const AName, AValue: string);
  var
    J: Integer;
  begin
    for J := Headers.Count - 1 downto 0 do
      if StartsText('[' + AName + ' ', Trim(Headers[J])) then
        Headers.Delete(J);
    Headers.Add(TournamentPdnTag(AName, AValue));
  end;
begin
  Result := '';
  if not HasRecord then
    Exit;
  Lines := TStringList.Create;
  Headers := TStringList.Create;
  Output := TStringStream.Create('');
  try
    Lines.Text := FPdn;
    FirstMoveLine := 0;
    while (FirstMoveLine < Lines.Count) and
      StartsText('[', Trim(Lines[FirstMoveLine])) do
    begin
      Headers.Add(Lines[FirstMoveLine]);
      Inc(FirstMoveLine);
    end;
    if FPdn = '' then
    begin
      SetTag('White', AWhite);
      SetTag('Black', ABlack);
      SetTag('FEN', AFen);
      SetTag('RecordSource', 'standings');
    end;
    SetTag('Event', AEvent);
    SetTag('TournamentId', ATournamentId);
    SetTag('Round', ARound);
    SetTag('GameNo', AGameNo);
    SetTag('Attempt', IntToStr(FAttempt));
    NewResult := PdnExportResult(EffectiveResult);
    SetTag('Result', NewResult);
    if FManualResult <> '' then
    begin
      SetTag('ResultSource', 'manual');
      if FPlayedResult <> '' then
        SetTag('PlayedResult', FPlayedResult);
    end
    else if FPdn = '' then
      SetTag('ResultSource', 'standings')
    else
      SetTag('ResultSource', 'played');
    for I := FirstMoveLine to Lines.Count - 1 do
      Output.WriteString(Lines[I] + LineEnding);
    MovesText := Trim(Output.DataString);
    OldResult := PdnExportResult(FPlayedResult);
    // The generated tree export ends with its result token when it is known.
    if (FPlayedResult <> '') and EndsText(OldResult, MovesText) and
      ((Length(MovesText) = Length(OldResult)) or
       (MovesText[Length(MovesText) - Length(OldResult)] in [' ', #9, #10, #13])) then
      MovesText := TrimRight(Copy(MovesText, 1, Length(MovesText) - Length(OldResult)));
    if MovesText <> '' then
      MovesText += ' ';
    MovesText += NewResult;
    Result := Headers.Text + LineEnding + MovesText + LineEnding;
  finally
    Output.Free;
    Headers.Free;
    Lines.Free;
  end;
end;
end.
