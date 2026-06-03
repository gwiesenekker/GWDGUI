unit ClockUi;

{$mode objfpc}{$H+}

interface

uses
  Graphics,
  StdCtrls;

procedure ApplyClockLabel(ALabel: TLabel; const AName: String;
  ASeconds: Double; AClockActive: Boolean);
function ClockRestoreLogText(AWhiteSeconds, ABlackSeconds: Double): String;

implementation

uses
  Notation,
  SysUtils;

procedure ApplyClockLabel(ALabel: TLabel; const AName: String;
  ASeconds: Double; AClockActive: Boolean);
begin
  if ALabel = nil then
    Exit;

  ALabel.Caption := AName + '  ' + FormatClockSeconds(ASeconds);
  if AClockActive and (ASeconds > 0) then
    ALabel.Font.Color := clGreen
  else
    ALabel.Font.Color := clRed;
end;

function ClockRestoreLogText(AWhiteSeconds, ABlackSeconds: Double): String;
begin
  Result := '[restored clocks ' + FormatClockSeconds(AWhiteSeconds) +
    ' / ' + FormatClockSeconds(ABlackSeconds) + ']' + LineEnding;
end;

end.
