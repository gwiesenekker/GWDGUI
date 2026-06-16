unit uPreferences;

{$mode objfpc}{$H+}

interface

uses
  Graphics;

type
  TScoreScale = (ssLinear, ssLogarithmic);

  TGuiPreferences = record
    MainBoardLightColor: TColor;
    MainBoardDarkColor: TColor;
    AnalysisBoardLightColor: TColor;
    AnalysisBoardDarkColor: TColor;
    TargetSquareColor: TColor;
    LastMoveColor: TColor;
    PvMoveColor: TColor;
    HintMoveColor: TColor;
    EvaluationMaxScore: Double;
    EvaluationScale: TScoreScale;
  end;

function PreferencesJsonFileName: string;
function DefaultGuiPreferences: TGuiPreferences;
procedure LoadGuiPreferences(var APrefs: TGuiPreferences);
procedure SaveGuiPreferences(const APrefs: TGuiPreferences);

implementation

uses
  Classes, FPJSON, JSONParser, SysUtils;

function PreferencesJsonFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) +
    'prefs.json';
end;

function DefaultGuiPreferences: TGuiPreferences;
begin
  Result.MainBoardLightColor := RGBToColor(228, 207, 176);
  Result.MainBoardDarkColor := RGBToColor(98, 73, 53);
  Result.AnalysisBoardLightColor := RGBToColor(206, 228, 246);
  Result.AnalysisBoardDarkColor := RGBToColor(54, 95, 139);
  Result.TargetSquareColor := clLime;
  Result.LastMoveColor := clYellow;
  Result.PvMoveColor := RGBToColor(255, 165, 0);
  Result.HintMoveColor := clRed;
  Result.EvaluationMaxScore := 10.0;
  Result.EvaluationScale := ssLogarithmic;
end;

function ColorToJsonText(AColor: TColor): string;
var
  C: TColor;
begin
  C := ColorToRGB(AColor);
  Result := Format('#%.2x%.2x%.2x', [
    C and $FF,
    (C shr 8) and $FF,
    (C shr 16) and $FF
  ]);
end;

function TryJsonTextToColor(const AText: string; out AColor: TColor): Boolean;
var
  Code: Integer;
  HexText: string;
  Value: Integer;
begin
  Result := False;
  HexText := Trim(AText);
  if (Length(HexText) = 7) and (HexText[1] = '#') then
    Delete(HexText, 1, 1);
  if Length(HexText) <> 6 then
    Exit;

  Val('$' + HexText, Value, Code);
  if Code <> 0 then
    Exit;

  AColor := RGBToColor((Value shr 16) and $FF, (Value shr 8) and $FF,
    Value and $FF);
  Result := True;
end;

procedure LoadColor(AObject: TJSONObject; const AName: string;
  var AColor: TColor);
var
  NewColor: TColor;
begin
  if (AObject <> nil) and TryJsonTextToColor(AObject.Get(AName, ''), NewColor) then
    AColor := NewColor;
end;

procedure LoadGuiPreferences(var APrefs: TGuiPreferences);
var
  Data: TJSONData;
  FileName: string;
  Lines: TStringList;
begin
  APrefs := DefaultGuiPreferences;
  FileName := PreferencesJsonFileName;
  if not FileExists(FileName) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(FileName);
    Data := GetJSON(Lines.Text);
  finally
    Lines.Free;
  end;

  try
    if Data.JSONType = jtObject then
    begin
      LoadColor(TJSONObject(Data), 'main_board_light', APrefs.MainBoardLightColor);
      LoadColor(TJSONObject(Data), 'main_board_dark', APrefs.MainBoardDarkColor);
      LoadColor(TJSONObject(Data), 'analysis_board_light',
        APrefs.AnalysisBoardLightColor);
      LoadColor(TJSONObject(Data), 'analysis_board_dark',
        APrefs.AnalysisBoardDarkColor);
      LoadColor(TJSONObject(Data), 'target_square', APrefs.TargetSquareColor);
      LoadColor(TJSONObject(Data), 'last_move', APrefs.LastMoveColor);
      LoadColor(TJSONObject(Data), 'pv_move', APrefs.PvMoveColor);
      LoadColor(TJSONObject(Data), 'hint_move', APrefs.HintMoveColor);
      APrefs.EvaluationMaxScore := TJSONObject(Data).Get(
        'evaluation_max_score', APrefs.EvaluationMaxScore);
      if SameText(TJSONObject(Data).Get('evaluation_scale', 'logarithmic'),
        'linear') then
        APrefs.EvaluationScale := ssLinear
      else
        APrefs.EvaluationScale := ssLogarithmic;
    end;
  finally
    Data.Free;
  end;
end;

procedure SaveGuiPreferences(const APrefs: TGuiPreferences);
var
  Data: TJSONObject;
  Lines: TStringList;
begin
  Data := TJSONObject.Create;
  Lines := TStringList.Create;
  try
    Data.Add('main_board_light', ColorToJsonText(APrefs.MainBoardLightColor));
    Data.Add('main_board_dark', ColorToJsonText(APrefs.MainBoardDarkColor));
    Data.Add('analysis_board_light',
      ColorToJsonText(APrefs.AnalysisBoardLightColor));
    Data.Add('analysis_board_dark',
      ColorToJsonText(APrefs.AnalysisBoardDarkColor));
    Data.Add('target_square', ColorToJsonText(APrefs.TargetSquareColor));
    Data.Add('last_move', ColorToJsonText(APrefs.LastMoveColor));
    Data.Add('pv_move', ColorToJsonText(APrefs.PvMoveColor));
    Data.Add('hint_move', ColorToJsonText(APrefs.HintMoveColor));
    Data.Add('evaluation_max_score', APrefs.EvaluationMaxScore);
    if APrefs.EvaluationScale = ssLinear then
      Data.Add('evaluation_scale', 'linear')
    else
      Data.Add('evaluation_scale', 'logarithmic');
    Lines.Text := Data.FormatJSON([], 2);
    Lines.SaveToFile(PreferencesJsonFileName);
  finally
    Lines.Free;
    Data.Free;
  end;
end;

end.
