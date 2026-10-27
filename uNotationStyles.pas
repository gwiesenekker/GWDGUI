unit uNotationStyles;
{$mode objfpc}{$H+}
interface
type
  TNotationStyle = (nsComment, nsPlayed, nsVariation, nsAnalysis);
  TNotationStyleSetting = record
    Color: LongInt;
    Bold, Italic: Boolean;
  end;
  TNotationStyles = array[TNotationStyle] of TNotationStyleSetting;
const
  NotationStyleNames: array[TNotationStyle] of string =
    ('Comments / other text', 'Played moves', 'Variations', 'Analysis / PVs');
function DefaultNotationStyles: TNotationStyles;
implementation
function DefaultNotationStyles: TNotationStyles;
var S: TNotationStyle;
begin
  for S := Low(S) to High(S) do
  begin Result[S].Color := 0; Result[S].Bold := False; Result[S].Italic := False; end;
  Result[nsPlayed].Bold := True;
  Result[nsVariation].Color := $008000; Result[nsVariation].Italic := True;
  Result[nsAnalysis].Color := $FF0000;
  Result[nsComment].Color := $808080; Result[nsComment].Italic := True;
end;
end.
