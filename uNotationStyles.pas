unit uNotationStyles;
{$mode objfpc}{$H+}
interface
type
  TNotationStyle = (nsComment, nsPlayed, nsVariation, nsAnalysis, nsEnginePV, nsAnnotatorPV);
  TNotationStyleSetting = record
    Color: LongInt;
    Bold, Italic: Boolean;
  end;
  TNotationStyles = array[TNotationStyle] of TNotationStyleSetting;
const
  DefaultNotationFontSize = 11;
  NotationStyleNames: array[TNotationStyle] of string =
    ('Comments / other text', 'Played moves', 'Variations', 'Auto Play PVs', 'Engine PVs', 'Annotator PVs');
function DefaultNotationFontName: string;
function DefaultNotationStyles: TNotationStyles;
implementation
function DefaultNotationFontName: string;
begin
  {$IFDEF MSWINDOWS}Result := 'Consolas';{$ELSE}Result := 'DejaVu Sans Mono';{$ENDIF}
end;
function DefaultNotationStyles: TNotationStyles;
var S: TNotationStyle;
begin
  for S := Low(S) to High(S) do
  begin Result[S].Color := 0; Result[S].Bold := False; Result[S].Italic := False; end;
  Result[nsPlayed].Bold := True;
  Result[nsVariation].Color := $008000; Result[nsVariation].Italic := True;
  Result[nsAnalysis].Color := $FF0000;
  Result[nsEnginePV].Color := $FF0000;
  Result[nsAnnotatorPV].Color := $800080;
  Result[nsComment].Color := $808080; Result[nsComment].Italic := True;
end;
end.
