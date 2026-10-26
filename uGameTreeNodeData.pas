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
function NormalizeNodeComment(const Text: string): string;
function NodeDataAnalysisCaption(const Data: TGameTreeNodeData): string;
function IsNodeDataEnvelope(const Text: string): Boolean;
function DecodeNodeDataComment(const Text, VisibleComment: string;
  out Data: TGameTreeNodeData; out Edited: Boolean): Boolean;
implementation
uses Classes, FPJSON, JSONParser, Base64, Math, SHA1;
function NormalizeNodeComment(const Text: string): string;
var I, Count: Integer; PendingSpace: Boolean;
begin
  SetLength(Result, Length(Text)); Count := 0; PendingSpace := False;
  for I := 1 to Length(Text) do
    if Text[I] in [' ', #9, #10, #11, #12, #13] then
      PendingSpace := Count > 0
    else
    begin
      if PendingSpace then begin Inc(Count); Result[Count] := ' '; end;
      Inc(Count); Result[Count] := Text[I]; PendingSpace := False;
    end;
  SetLength(Result, Count);
end;

function NodeDataAnalysisCaption(const Data: TGameTreeNodeData): string;
var FS: TFormatSettings;
  procedure Add(const Text: string);
  begin if Result <> '' then Result += '; '; Result += Text; end;
  function Seconds(Value: Double): string;
  begin Result := FormatFloat('0.000', Value, FS); end;
begin
  FS := DefaultFormatSettings; FS.DecimalSeparator := '.';
  Result := '';
  if Trim(Data.EngineScore) <> '' then Add('E: ' + Trim(Data.EngineScore));
  if Trim(Data.AnnotatorScore) <> '' then Add('A: ' + Trim(Data.AnnotatorScore));
  if Data.HasClockInfo then
  begin
    Add('clk: W=' + Seconds(Data.WhiteRemainingSeconds) + ', B=' + Seconds(Data.BlackRemainingSeconds) +
      '; used: W=' + Seconds(Data.WhiteUsedSeconds) + ', B=' + Seconds(Data.BlackUsedSeconds));
    if Data.HasMoveTime then Add('emt: ' + Seconds(Data.SecondsUsed));
  end;
end;

function NodeCommentChecksum(const Text: string): string;
begin Result := Copy(SHA1Print(SHA1String(NormalizeNodeComment(Text))), 1, 12); end;

function EncodeNodeData(const Data: TGameTreeNodeData; const Projection: string): string;
var FS: TFormatSettings; Value: TJSONString; Note: string;
  procedure Add(const Key, Text: string);
  var Encoded: string;
  begin
    if Text = '' then Exit;
    Value := TJSONString.Create(Text);
    try Encoded := Value.AsJSON; finally Value.Free; end;
    // Keep braces/brackets out of the surrounding PDN comment grammar.
    Encoded := StringReplace(Encoded, '{', '\u007b', [rfReplaceAll]);
    Encoded := StringReplace(Encoded, '}', '\u007d', [rfReplaceAll]);
    Encoded := StringReplace(Encoded, '[', '\u005b', [rfReplaceAll]);
    Encoded := StringReplace(Encoded, ']', '\u005d', [rfReplaceAll]);
    Result += ' ' + Key + '=' + Encoded;
  end;
  function Number(Value: Double): string;
  begin Result := FloatToStr(Value, FS); end;
begin
  Result := '';
  Note := NormalizeNodeComment(Data.CommentText);
  // Ordinary comments and default human provenance need no extension at all.
  if (Data.EnginePV = '') and (Data.EngineScore = '') and (Data.EnginePVDepth = '') and
    (Data.EnginePVTimeText = '') and (Data.AnnotatorPV = '') and (Data.AnnotatorScore = '') and
    (Data.AnnotatorPVDepth = '') and (Data.AnnotatorPVTimeText = '') and (Data.AutoPlayPV = '') and
    not Data.HasClockInfo and not Data.HasMoveTime and (Data.SecondsUsed = 0) and
    (Data.WhiteRemainingSeconds = 0) and (Data.BlackRemainingSeconds = 0) and
    (Data.WhiteUsedSeconds = 0) and (Data.BlackUsedSeconds = 0) and
    ((Data.OriginText = '') or SameText(Data.OriginText, 'Human')) and
    (Data.CommentText = Note) then Exit;
  FS := DefaultFormatSettings; FS.DecimalSeparator := '.';
  Result := '[%gwd h=' + NodeCommentChecksum(Projection);
  if Note <> '' then Result += ' n=' + IntToStr(Length(Note));
  if (Data.CommentText <> Note) or (Copy(NormalizeNodeComment(Projection), 1, Length(Note)) <> Note) then
    Add('note', Data.CommentText); // Exceptional layout only; ordinary comments are never duplicated.
  Add('origin', Data.OriginText); Add('pv', Data.EnginePV); Add('eval', Data.EngineScore);
  Add('depth', Data.EnginePVDepth); Add('time', Data.EnginePVTimeText);
  Add('apv', Data.AnnotatorPV); Add('aeval', Data.AnnotatorScore);
  Add('adepth', Data.AnnotatorPVDepth); Add('atime', Data.AnnotatorPVTimeText);
  Add('autopv', Data.AutoPlayPV);
  if Data.HasClockInfo or (Data.WhiteRemainingSeconds <> 0) or (Data.BlackRemainingSeconds <> 0) or
    (Data.WhiteUsedSeconds <> 0) or (Data.BlackUsedSeconds <> 0) then
  begin
    Add('clk', Number(Data.WhiteRemainingSeconds) + ',' + Number(Data.BlackRemainingSeconds) + ',' +
      Number(Data.WhiteUsedSeconds) + ',' + Number(Data.BlackUsedSeconds));
    if not Data.HasClockInfo then Add('clock-info', '0');
  end;
  if Data.HasMoveTime then Add('emt', Number(Data.SecondsUsed))
  else if Data.SecondsUsed <> 0 then Add('seconds', Number(Data.SecondsUsed));
  Result += ']';
end;

function IsNodeDataEnvelope(const Text: string): Boolean;
var I: Integer; Data: TGameTreeNodeData; Projection: string;
begin
  Result := False;
  if Copy(Text, 1, 11) = '[%gwd-node ' then
    Exit(DecodeNodeData(Text, Data, Projection));
  // Current writers always start with a twelve-digit checksum. A bare prefix
  // in prose is ordinary text, not evidence of a damaged metadata extension.
  if (Length(Text) < 21) or (Copy(Text, 1, 8) <> '[%gwd h=') then Exit;
  for I := 9 to 20 do
    if not (Text[I] in ['0'..'9', 'a'..'f', 'A'..'F']) then Exit;
  Result := Text[21] in [']', ' ', #9, #10, #13];
end;

function DecodeNodeDataComment(const Text, VisibleComment: string;
  out Data: TGameTreeNodeData; out Edited: Boolean): Boolean;
var Obj: TJSONObject; Parsed: TJSONData; Parts: TStringList;
  I, Start, NoteLength, PrefixLength: Integer; Key, Token, Projection, Actual, Suffix: string;
  FS: TFormatSettings;
  function Number(const Value: string): Double;
  begin
    if not TryStrToFloat(Value, Result, FS) or IsNan(Result) or IsInfinite(Result) then
      raise EConvertError.Create('Invalid node clock');
  end;
begin
  Data := Default(TGameTreeNodeData); Edited := False; Result := False;
  if not IsNodeDataEnvelope(Text) then Exit;
  Actual := NormalizeNodeComment(VisibleComment);
  if Copy(Text, 1, 11) = '[%gwd-node ' then
  begin
    Result := DecodeNodeData(Text, Data, Projection);
    if not Result then Exit;
    Edited := Actual <> NormalizeNodeComment(Projection);
  end
  else
  begin
    if (Copy(Text, 1, 6) <> '[%gwd ') or (Text[Length(Text)] <> ']') then Exit;
    Obj := TJSONObject.Create; Parts := TStringList.Create; Parsed := nil;
    FS := DefaultFormatSettings; FS.DecimalSeparator := '.';
    try
      try
        I := 7;
        while I < Length(Text) do
        begin
          while (I < Length(Text)) and (Text[I] <= ' ') do Inc(I);
          if I = Length(Text) then Break;
          Start := I;
          while (I < Length(Text)) and not (Text[I] in ['=', ' ', #9]) do Inc(I);
          Key := Copy(Text, Start, I - Start);
          if (Key = '') or (Text[I] <> '=') or (Obj.Find(Key) <> nil) then Exit;
          Inc(I); Start := I;
          if Text[I] = '"' then
          begin
            Inc(I);
            while I < Length(Text) do
            begin
              if Text[I] = '\' then Inc(I)
              else if Text[I] = '"' then Break;
              Inc(I);
            end;
            if (I >= Length(Text)) or (Text[I] <> '"') then Exit;
            Inc(I); Token := Copy(Text, Start, I - Start);
            Parsed := GetJSON(Token);
            if Parsed.JSONType <> jtString then Exit;
            Obj.Add(Key, Parsed.AsString); FreeAndNil(Parsed);
          end
          else
          begin
            while (I < Length(Text)) and (Text[I] > ' ') do Inc(I);
            Obj.Add(Key, Copy(Text, Start, I - Start));
          end;
        end;
        if Obj.Get('h', '') = '' then Exit;
        NoteLength := StrToInt(Obj.Get('n', '0'));
        if NoteLength < 0 then Exit;
        Edited := Obj.Get('h', '') <> NodeCommentChecksum(Actual);
        Data.CommentText := Copy(Actual, 1, NoteLength);
        if Obj.Find('note') <> nil then Data.CommentText := Obj.Get('note', '');
        Data.OriginText := Obj.Get('origin', '');
        Data.EnginePV := Obj.Get('pv', ''); Data.EngineScore := Obj.Get('eval', '');
        Data.EnginePVDepth := Obj.Get('depth', ''); Data.EnginePVTimeText := Obj.Get('time', '');
        Data.AnnotatorPV := Obj.Get('apv', ''); Data.AnnotatorScore := Obj.Get('aeval', '');
        Data.AnnotatorPVDepth := Obj.Get('adepth', ''); Data.AnnotatorPVTimeText := Obj.Get('atime', '');
        Data.AutoPlayPV := Obj.Get('autopv', '');
        if Obj.Find('clk') <> nil then
        begin
          Parts.StrictDelimiter := True; Parts.Delimiter := ','; Parts.DelimitedText := Obj.Get('clk', '');
          if Parts.Count <> 4 then Exit;
          Data.WhiteRemainingSeconds := Number(Parts[0]); Data.BlackRemainingSeconds := Number(Parts[1]);
          Data.WhiteUsedSeconds := Number(Parts[2]); Data.BlackUsedSeconds := Number(Parts[3]);
          Data.HasClockInfo := Obj.Get('clock-info', '1') <> '0';
        end;
        if Obj.Find('emt') <> nil then
        begin Data.HasMoveTime := True; Data.SecondsUsed := Number(Obj.Get('emt', '')); end
        else if Obj.Find('seconds') <> nil then Data.SecondsUsed := Number(Obj.Get('seconds', ''));
        Result := True;
      except Result := False; end;
    finally Parsed.Free; Parts.Free; Obj.Free; end;
    if not Result then Exit;
  end;
  if Edited then
  begin
    Suffix := NodeDataAnalysisCaption(Data);
    PrefixLength := Length(Actual) - Length(Suffix);
    if (Suffix <> '') and (PrefixLength >= 0) and (Copy(Actual, PrefixLength + 1, MaxInt) = Suffix) and
      ((PrefixLength = 0) or (Copy(Actual, PrefixLength - 1, 2) = '; ')) then
    begin
      if PrefixLength > 0 then Dec(PrefixLength, 2);
      Data.CommentText := Copy(Actual, 1, PrefixLength);
    end
    else
    begin
      // The visible score/clock projection changed. Keep independent PV/depth/time
      // data, but never restore values that could contradict the user's edit.
      Data.CommentText := Actual;
      if Suffix <> '' then
      begin
        Data.EngineScore := ''; Data.AnnotatorScore := '';
        Data.HasClockInfo := False; Data.HasMoveTime := False; Data.SecondsUsed := 0;
        Data.WhiteRemainingSeconds := 0; Data.BlackRemainingSeconds := 0;
        Data.WhiteUsedSeconds := 0; Data.BlackUsedSeconds := 0;
      end;
    end;
  end;
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
