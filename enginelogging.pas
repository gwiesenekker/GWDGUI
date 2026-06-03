unit EngineLogging;

{$mode objfpc}{$H+}

interface

function EngineLogTimestamp: String;
function EngineLogPrefix(const AName: String; AShowTimestamps: Boolean):
  String;
function PrefixLogLines(const AText, APrefix: String): String;
function EngineOutputLogText(const AText, AEngineName: String;
  AShowTimestamps: Boolean): String;

implementation

uses
  SysUtils;

function EngineLogTimestamp: String;
begin
  Result := FormatDateTime('hh:nn:ss.zzz', Now);
end;

function EngineLogPrefix(const AName: String; AShowTimestamps: Boolean):
  String;
begin
  if AShowTimestamps then
    Result := '[' + AName + ' ' + EngineLogTimestamp + '] '
  else
    Result := '[' + AName + '] ';
end;

function PrefixLogLines(const AText, APrefix: String): String;
var
  LineBody: String;
  LineEnd: String;
  LineStart: Integer;
  P: Integer;

  procedure AppendLine(const ALine: String);
  begin
    if Trim(ALine) <> '' then
      Result += APrefix + ALine
    else
      Result += ALine;
  end;

begin
  Result := '';
  LineStart := 1;
  P := 1;
  while P <= Length(AText) do
  begin
    if AText[P] in [#10, #13] then
    begin
      LineBody := Copy(AText, LineStart, P - LineStart);
      LineEnd := AText[P];
      if (AText[P] = #13) and (P < Length(AText)) and
        (AText[P + 1] = #10) then
      begin
        LineEnd += AText[P + 1];
        Inc(P);
      end;
      AppendLine(LineBody + LineEnd);
      LineStart := P + 1;
    end;
    Inc(P);
  end;

  if LineStart <= Length(AText) then
    AppendLine(Copy(AText, LineStart, MaxInt));
end;

function EngineOutputLogText(const AText, AEngineName: String;
  AShowTimestamps: Boolean): String;
var
  LineBody: String;
  LineEnd: String;
  LineStart: Integer;
  P: Integer;
  Prefix: String;

  procedure AppendLine(const ALine: String);
  begin
    if Trim(ALine) <> '' then
      Result += Prefix + '< ' + ALine
    else
      Result += ALine;
  end;

begin
  Result := '';
  Prefix := EngineLogPrefix(AEngineName, AShowTimestamps);
  LineStart := 1;
  P := 1;
  while P <= Length(AText) do
  begin
    if AText[P] in [#10, #13] then
    begin
      LineBody := Copy(AText, LineStart, P - LineStart);
      LineEnd := AText[P];
      if (AText[P] = #13) and (P < Length(AText)) and
        (AText[P + 1] = #10) then
      begin
        LineEnd += AText[P + 1];
        Inc(P);
      end;
      AppendLine(LineBody + LineEnd);
      LineStart := P + 1;
    end;
    Inc(P);
  end;

  if LineStart <= Length(AText) then
    AppendLine(Copy(AText, LineStart, MaxInt));
end;

end.
