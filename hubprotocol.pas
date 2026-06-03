unit HubProtocol;

{$mode objfpc}{$H+}

interface

uses
  DraughtsRules;

type
  TIntegerArray = array of Integer;
  TTextArray = array of String;

function HubBuildMoveTimeLevelCommand(AMoveTimeSeconds: Double): String;
function HubBuildGameTimeLevelCommand(ARemainingTimeSeconds: Double): String;
function HubDoneResultIsDraw(const AResult: String): Boolean;
function HubPositionStringFor(const ABoard: TBoard; ASide: TSide): String;
function HubQuote(const AValue: String): String;
function ParseHubMoveNumbers(const AMoveText: String;
  out ANumbers: TIntegerArray; out AIsCapture: Boolean): Boolean;
procedure ParseHubPvMoveText(const APvText: String; out AMoves: TTextArray);

implementation

uses
  SysUtils;

function HubFormatFloatCommand(const AFormat: String; AValue: Double): String;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  Result := Format(AFormat, [AValue], FormatSettings);
end;

function HubBuildMoveTimeLevelCommand(AMoveTimeSeconds: Double): String;
begin
  Result := HubFormatFloatCommand('level move-time=%.3f', AMoveTimeSeconds);
end;

function HubBuildGameTimeLevelCommand(ARemainingTimeSeconds: Double): String;
begin
  Result := HubFormatFloatCommand('level time=%.3f', ARemainingTimeSeconds);
end;

function HubDoneResultIsDraw(const AResult: String): Boolean;
var
  ResultText: String;
begin
  ResultText := LowerCase(Trim(AResult));
  Result := (ResultText = 'draw') or (ResultText = '1-1') or
    (ResultText = '1/2-1/2') or (ResultText = '0.5-0.5');
end;

function HubPositionStringFor(const ABoard: TBoard; ASide: TSide): String;
var
  Square: Integer;
begin
  if ASide = sideWhite then
    Result := 'W'
  else
    Result := 'B';

  for Square := Low(ABoard) to High(ABoard) do
    case ABoard[Square] of
      pcWhiteMan: Result += 'w';
      pcBlackMan: Result += 'b';
      pcWhiteKing: Result += 'W';
      pcBlackKing: Result += 'B';
    else
      Result += 'e';
    end;
end;

function HubQuote(const AValue: String): String;
var
  I: Integer;
  NeedsQuotes: Boolean;
begin
  NeedsQuotes := AValue = '';
  for I := 1 to Length(AValue) do
    if AValue[I] in [' ', '=', '"'] then
      NeedsQuotes := True;

  if not NeedsQuotes then
    Exit(AValue);

  Result := '"';
  for I := 1 to Length(AValue) do
  begin
    if AValue[I] = '"' then
      Result += '\"'
    else
      Result += AValue[I];
  end;
  Result += '"';
end;

procedure AppendInteger(var AValues: TIntegerArray; AValue: Integer);
begin
  SetLength(AValues, Length(AValues) + 1);
  AValues[High(AValues)] := AValue;
end;

function ParseHubMoveNumbers(const AMoveText: String;
  out ANumbers: TIntegerArray; out AIsCapture: Boolean): Boolean;
var
  I: Integer;
  NumberStart: Integer;
begin
  SetLength(ANumbers, 0);
  AIsCapture := Pos('x', AMoveText) > 0;
  I := 1;

  while I <= Length(AMoveText) do
  begin
    if AMoveText[I] in ['0'..'9'] then
    begin
      NumberStart := I;
      while (I <= Length(AMoveText)) and (AMoveText[I] in ['0'..'9']) do
        Inc(I);
      AppendInteger(ANumbers, StrToIntDef(Copy(AMoveText, NumberStart,
        I - NumberStart), 0));
    end
    else
      Inc(I);
  end;

  Result := Length(ANumbers) >= 2;
end;

procedure ParseHubPvMoveText(const APvText: String; out AMoves: TTextArray);
var
  Ch: Char;
  I: Integer;
  MoveText: String;

  procedure AppendMove;
  begin
    MoveText := Trim(MoveText);
    if MoveText = '' then
      Exit;
    SetLength(AMoves, Length(AMoves) + 1);
    AMoves[High(AMoves)] := MoveText;
    MoveText := '';
  end;

begin
  SetLength(AMoves, 0);
  MoveText := '';
  for I := 1 to Length(APvText) do
  begin
    Ch := APvText[I];
    if Ch in [' ', #9, #10, #13] then
      AppendMove
    else
      MoveText += Ch;
  end;
  AppendMove;
end;

end.
