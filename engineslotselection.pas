unit EngineSlotSelection;

{$mode objfpc}{$H+}

interface

uses
  HubProtocol;

const
  EngineFirstSlot = 1;
  EngineLastSlot = 2;
  EnginePrimarySlot = 1;
  EngineSecondarySlot = 2;

procedure AddEngineSlot(var ASlots: TIntegerArray; ASlot: Integer);
function EnginePrimarySlots: TIntegerArray;
function EngineReverseSlots: TIntegerArray;

implementation

procedure AddEngineSlot(var ASlots: TIntegerArray; ASlot: Integer);
var
  Count: Integer;
begin
  Count := Length(ASlots);
  SetLength(ASlots, Count + 1);
  ASlots[Count] := ASlot;
end;

function EnginePrimarySlots: TIntegerArray;
begin
  Result := nil;
  SetLength(Result, 1);
  Result[0] := EnginePrimarySlot;
end;

function EngineReverseSlots: TIntegerArray;
begin
  Result := nil;
  SetLength(Result, 2);
  Result[0] := EngineSecondarySlot;
  Result[1] := EnginePrimarySlot;
end;

end.
