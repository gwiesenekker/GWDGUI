unit uGameTreeNodeData;
{$mode objfpc}{$H+}
interface
uses SysUtils;
type
  TGameTreeNodeData = record
    CommentText, OriginText, EnginePV, EngineScore, EnginePVDepth, EnginePVTimeText, AnnotatorPV, AnnotatorScore, AnnotatorPVDepth, AnnotatorPVTimeText, AutoPlayPV: string;
    HasClockInfo, HasMoveTime: Boolean;
    SecondsUsed, WhiteRemainingSeconds, BlackRemainingSeconds, WhiteUsedSeconds, BlackUsedSeconds: Double;
  end;
function EncodeNodeData(const Data: TGameTreeNodeData; const Projection: string): string;
function DecodeNodeData(const Text: string; out Data: TGameTreeNodeData;
  out Projection: string): Boolean;
implementation
uses FPJSON, JSONParser, Base64, Math;
function EncodeNodeData(const Data: TGameTreeNodeData; const Projection: string): string;
var Value: TJSONObject;
begin
  Value := TJSONObject.Create;
  try
    Value.Add('schema', 'GWDGUI-node-1');
    if Projection <> '' then Value.Add('projection', Projection);
    if Data.CommentText <> '' then Value.Add('CommentText', Data.CommentText);
    if Data.OriginText <> '' then Value.Add('OriginText', Data.OriginText);
    if Data.EnginePV <> '' then Value.Add('EnginePV', Data.EnginePV);
    if Data.EngineScore <> '' then Value.Add('EngineScore', Data.EngineScore);
    if Data.EnginePVDepth <> '' then Value.Add('EnginePVDepth', Data.EnginePVDepth);
    if Data.EnginePVTimeText <> '' then Value.Add('EnginePVTimeText', Data.EnginePVTimeText);
    if Data.AnnotatorPV <> '' then Value.Add('AnnotatorPV', Data.AnnotatorPV);
    if Data.AnnotatorScore <> '' then Value.Add('AnnotatorScore', Data.AnnotatorScore);
    if Data.AnnotatorPVDepth <> '' then Value.Add('AnnotatorPVDepth', Data.AnnotatorPVDepth);
    if Data.AnnotatorPVTimeText <> '' then Value.Add('AnnotatorPVTimeText', Data.AnnotatorPVTimeText);
    if Data.AutoPlayPV <> '' then Value.Add('AutoPlayPV', Data.AutoPlayPV);
    if Data.HasClockInfo then Value.Add('HasClockInfo', True);
    if Data.HasMoveTime then Value.Add('HasMoveTime', True);
    if Data.SecondsUsed <> 0 then Value.Add('SecondsUsed', Data.SecondsUsed);
    if Data.WhiteRemainingSeconds <> 0 then Value.Add('WhiteRemainingSeconds', Data.WhiteRemainingSeconds);
    if Data.BlackRemainingSeconds <> 0 then Value.Add('BlackRemainingSeconds', Data.BlackRemainingSeconds);
    if Data.WhiteUsedSeconds <> 0 then Value.Add('WhiteUsedSeconds', Data.WhiteUsedSeconds);
    if Data.BlackUsedSeconds <> 0 then Value.Add('BlackUsedSeconds', Data.BlackUsedSeconds);
    Result := '[%gwd-node ' + EncodeStringBase64(Value.FormatJSON(AsCompressedJSON)) + ']';
  finally Value.Free; end;
end;
function DecodeNodeData(const Text: string; out Data: TGameTreeNodeData;
  out Projection: string): Boolean;
var Value: TJSONData; Obj: TJSONObject; Payload: string;
begin
  Result := False;
  Data := Default(TGameTreeNodeData);
  Projection := '';
  if (Copy(Text, 1, 11) <> '[%gwd-node ') or (Text[Length(Text)] <> ']') then Exit;
  Payload := Copy(Text, 12, Length(Text) - 12);
  Value := nil;
  try
    try
      Value := GetJSON(DecodeStringBase64(Payload));
      if not (Value is TJSONObject) then Exit;
      Obj := TJSONObject(Value);
      if Obj.Get('schema', '') <> 'GWDGUI-node-1' then Exit;
      Projection := Obj.Get('projection', '');
      Data.CommentText := Obj.Get('CommentText', '');
      Data.OriginText := Obj.Get('OriginText', '');
      Data.EnginePV := Obj.Get('EnginePV', '');
      Data.EngineScore := Obj.Get('EngineScore', '');
      Data.EnginePVDepth := Obj.Get('EnginePVDepth', '');
      Data.EnginePVTimeText := Obj.Get('EnginePVTimeText', '');
      Data.AnnotatorPV := Obj.Get('AnnotatorPV', '');
      Data.AnnotatorScore := Obj.Get('AnnotatorScore', '');
      Data.AnnotatorPVDepth := Obj.Get('AnnotatorPVDepth', '');
      Data.AnnotatorPVTimeText := Obj.Get('AnnotatorPVTimeText', '');
      Data.AutoPlayPV := Obj.Get('AutoPlayPV', '');
      Data.HasClockInfo := Obj.Get('HasClockInfo', False);
      Data.HasMoveTime := Obj.Get('HasMoveTime', False);
      Data.SecondsUsed := Obj.Get('SecondsUsed', Double(0));
      if IsNan(Data.SecondsUsed) or IsInfinite(Data.SecondsUsed) then Exit;
      Data.WhiteRemainingSeconds := Obj.Get('WhiteRemainingSeconds', Double(0));
      if IsNan(Data.WhiteRemainingSeconds) or IsInfinite(Data.WhiteRemainingSeconds) then Exit;
      Data.BlackRemainingSeconds := Obj.Get('BlackRemainingSeconds', Double(0));
      if IsNan(Data.BlackRemainingSeconds) or IsInfinite(Data.BlackRemainingSeconds) then Exit;
      Data.WhiteUsedSeconds := Obj.Get('WhiteUsedSeconds', Double(0));
      if IsNan(Data.WhiteUsedSeconds) or IsInfinite(Data.WhiteUsedSeconds) then Exit;
      Data.BlackUsedSeconds := Obj.Get('BlackUsedSeconds', Double(0));
      if IsNan(Data.BlackUsedSeconds) or IsInfinite(Data.BlackUsedSeconds) then Exit;
      Result := True;
    except Result := False; end;
  finally Value.Free; end;
end;
end.
