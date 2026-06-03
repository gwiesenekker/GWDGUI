unit PdnAnnotations;

{$mode objfpc}{$H+}

interface

uses
  DraughtsRules;

function BuildEngineInfoAnnotation(const ALine: String): String;
function TryAnnotationScoreWhite(const AAnnotation, AScorePerspective: String;
  ABaseSide: TSide; APly: Integer; out AScore: Double): Boolean;

implementation

uses
  EngineParams,
  SysUtils;

function TryParseDotFloat(const AText: String; out AValue: Double): Boolean;
var
  FormatSettings: TFormatSettings;
begin
  FormatSettings := DefaultFormatSettings;
  FormatSettings.DecimalSeparator := '.';
  Result := TryStrToFloat(AText, AValue, FormatSettings);
end;

function SideBeforePly(ABaseSide: TSide; APly: Integer): TSide;
begin
  Result := ABaseSide;
  if Odd(APly - 1) then
    if Result = sideWhite then
      Result := sideBlack
    else
      Result := sideWhite;
end;

function BuildEngineInfoAnnotation(const ALine: String): String;
var
  DepthText: String;
  ScoreText: String;
  TimeText: String;
begin
  DepthText := ExtractHubArgument(ALine, 'depth');
  ScoreText := ExtractHubArgument(ALine, 'score');
  TimeText := ExtractHubArgument(ALine, 'time');

  Result := '';
  if DepthText <> '' then
    Result := 'depth=' + DepthText;
  if ScoreText <> '' then
  begin
    if Result <> '' then
      Result += ' ';
    Result += 'score=' + ScoreText;
  end;
  if TimeText <> '' then
  begin
    if Result <> '' then
      Result += ' ';
    Result += 'time=' + TimeText;
  end;
end;

function TryAnnotationScoreWhite(const AAnnotation, AScorePerspective: String;
  ABaseSide: TSide; APly: Integer; out AScore: Double): Boolean;
var
  Perspective: String;
  ScoreText: String;
begin
  Result := False;
  AScore := 0.0;

  ScoreText := ExtractHubArgument(AAnnotation, 'score');
  if ScoreText = '' then
    Exit;
  if not TryParseDotFloat(ScoreText, AScore) then
    Exit;

  Perspective := LowerCase(Trim(AScorePerspective));
  if (Perspective = 'black') or (Perspective = 'b') then
    AScore := -AScore
  else if (Perspective = 'side-to-move') or (Perspective = 'stm') or
    (Perspective = 'side') then
    if SideBeforePly(ABaseSide, APly) = sideBlack then
      AScore := -AScore;

  Result := True;
end;

end.
