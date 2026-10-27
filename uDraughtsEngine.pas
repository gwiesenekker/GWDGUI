unit uDraughtsEngine;

{$mode objfpc}{$H+}

{ Base class of the draughts engine protocols (Hub, DXP): draughts move-text
  normalization on top of the shared engine infrastructure in uEngineBase. }

interface

uses
  SysUtils, uEngineBase;

type
  TDraughtsEngine = class(TGameEngine)
  protected
    function NormalizeMoveText(const AMove: string): string; override;
  end;

implementation

uses
  uDraughtsBoard;

function TDraughtsEngine.NormalizeMoveText(const AMove: string): string;
begin
  Result := NormalizeMoveNotation(AMove);
end;

end.
