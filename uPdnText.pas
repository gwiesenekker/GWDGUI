unit uPdnText;

{$mode objfpc}{$H+}

{ Game-neutral text helpers for PDN-style records: comment escaping, result
  spellings and "name: value" annotation items. No board or move knowledge;
  the game tree and the notation walker use these instead of the draughts PDN
  parser (uPdn). Moved unchanged from uPdn. }

interface

uses
  Classes, StrUtils, SysUtils;

const
  // Marks a JSON list of per-move annotations stored in one comment.
  VariationAnnotationsPrefix = '@pdn-annotations:';

function AnnotationNameMatches(const AText: string; AStart: Integer;
  const AName: string): Boolean;
function AnnotationWithScore(const AAnnotation, AName, AScore: string): string;
function AnnotationWithoutName(const AAnnotation, AName: string): string;
function EncodeVariationAnnotations(AAnnotations: TStrings): string;
function EscapePdnComment(const Text: string): string;
function EscapePdnLiteralComment(const Text: string): string;
function ExtractAnnotationValue(const AAnnotation, AName: string): string;
function NormalizePdnResult(const AText: string): string;
function PdnExportResult(const AText: string): string;
procedure SplitAnnotationItems(const AAnnotation: string; AItems: TStrings);

implementation

uses FPJSON;

function AnnotationNameMatches(const AText: string; AStart: Integer;
  const AName: string): Boolean;
var
  Prefix: string;
begin
  Prefix := LowerCase(Copy(AText, AStart, Length(AName) + 1));
  Result := (Prefix = LowerCase(AName) + ':') or
    (Prefix = LowerCase(AName) + '=');
  if (not Result) and SameText(AName, 'engine') then
    Result := AnnotationNameMatches(AText, AStart, 'E');
  if (not Result) and SameText(AName, 'annotator') then
    Result := AnnotationNameMatches(AText, AStart, 'A');
end;

function AnnotationWithScore(const AAnnotation, AName, AScore: string): string;
var
  I: Integer;
  Items: TStringList;
  ItemText: string;
  NewItem: string;
  Replaced: Boolean;
begin
  Result := '';
  if Trim(AScore) = '' then
    Exit(Trim(AAnnotation));

  Items := TStringList.Create;
  try
    SplitAnnotationItems(AAnnotation, Items);
    if SameText(AName, 'engine') then
      NewItem := 'E: ' + Trim(AScore)
    else if SameText(AName, 'annotator') then
      NewItem := 'A: ' + Trim(AScore)
    else
      NewItem := Trim(AName) + ': ' + Trim(AScore);
    Replaced := False;
    for I := 0 to Items.Count - 1 do
    begin
      ItemText := Trim(Items[I]);
      if ItemText = '' then
        Continue;
      if AnnotationNameMatches(ItemText, 1, AName) or
        ((SameText(AName, 'engine')) and AnnotationNameMatches(ItemText, 1,
        'score')) then
      begin
        ItemText := NewItem;
        Replaced := True;
      end;
      if Result <> '' then
        Result += '; ';
      Result += ItemText;
    end;
    if not Replaced then
    begin
      if Result <> '' then
        Result += '; ';
      Result += NewItem;
    end;
  finally
    Items.Free;
  end;
end;

function AnnotationWithoutName(const AAnnotation, AName: string): string;
var
  I: Integer;
  ItemText: string;
  Items: TStringList;
begin
  Result := '';
  Items := TStringList.Create;
  try
    SplitAnnotationItems(AAnnotation, Items);
    for I := 0 to Items.Count - 1 do
    begin
      ItemText := Trim(Items[I]);
      if (ItemText = '') or AnnotationNameMatches(ItemText, 1, AName) then
        Continue;
      if Result <> '' then
        Result += '; ';
      Result += ItemText;
    end;
  finally
    Items.Free;
  end;
end;

function EncodeVariationAnnotations(AAnnotations: TStrings): string;
var
  I: Integer;
  Items: TJSONArray;
  HasEarlierComment: Boolean;
begin
  Result := '';
  if AAnnotations.Count = 0 then
    Exit;
  HasEarlierComment := False;
  for I := 0 to AAnnotations.Count - 2 do
    HasEarlierComment := HasEarlierComment or (Trim(AAnnotations[I]) <> '');
  if (not HasEarlierComment) and
    (Copy(AAnnotations[AAnnotations.Count - 1], 1,
      Length(VariationAnnotationsPrefix)) <> VariationAnnotationsPrefix) then
    Exit(AAnnotations[AAnnotations.Count - 1]);
  Items := TJSONArray.Create;
  try
    for I := 0 to AAnnotations.Count - 1 do
      Items.Add(AAnnotations[I]);
    Result := VariationAnnotationsPrefix + Items.AsJSON;
  finally
    Items.Free;
  end;
end;

function EscapePdnComment(const Text: string): string;
begin
  Result := StringReplace(Text, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '{', '\{', [rfReplaceAll]);
  Result := StringReplace(Result, '}', '\}', [rfReplaceAll]);
end;

function EscapePdnLiteralComment(const Text: string): string;
var I: Integer;
begin
  Result := EscapePdnComment(Text);
  I := 1;
  while (I <= Length(Result)) and (Result[I] <= ' ') do Inc(I);
  if (Copy(Result, I, 6) = '[%gwd ') or (Copy(Result, I, 11) = '[%gwd-node ') then
    Insert('\', Result, I);
end;

function ExtractAnnotationValue(const AAnnotation, AName: string): string;
var
  DelimPos: Integer;
  I: Integer;
  ItemText: string;
  Items: TStringList;
begin
  Result := '';
  Items := TStringList.Create;
  try
    SplitAnnotationItems(AAnnotation, Items);
    for I := 0 to Items.Count - 1 do
    begin
      ItemText := Trim(Items[I]);
      if not AnnotationNameMatches(ItemText, 1, AName) then
        Continue;
      DelimPos := Pos(':', ItemText);
      if DelimPos <= 0 then
        DelimPos := Pos('=', ItemText);
      if DelimPos > 0 then
      begin
        Result := Trim(Copy(ItemText, DelimPos + 1, MaxInt));
        Exit;
      end;
    end;
  finally
    Items.Free;
  end;
end;

function NormalizePdnResult(const AText: string): string;
begin
  Result := Trim(AText);
  if SameText(Result, '1-0') then
    Result := '2-0'
  else if SameText(Result, '0-1') then
    Result := '0-2'
  else if SameText(Result, '1/2-1/2') or SameText(Result, '1/2:1/2') then
    Result := '1-1'
  else if not (SameText(Result, '2-0') or SameText(Result, '1-1') or
    SameText(Result, '0-2') or SameText(Result, '0-0') or SameText(Result, '*')) then
    Result := '*';
end;

function PdnExportResult(const AText: string): string;
begin
  Result := NormalizePdnResult(AText);
  if Result = '2-0' then
    Result := '1-0'
  else if Result = '1-1' then
    Result := '1/2-1/2'
  else if Result = '0-2' then
    Result := '0-1';
end;

procedure SplitAnnotationItems(const AAnnotation: string; AItems: TStrings);
var
  I: Integer;
  ItemText: string;
begin
  if AItems = nil then
    Exit;
  AItems.Clear;
  ItemText := '';
  for I := 1 to Length(AAnnotation) do
  begin
    if AAnnotation[I] = ';' then
    begin
      AItems.Add(Trim(ItemText));
      ItemText := '';
    end
    else
      ItemText += AAnnotation[I];
  end;
  if (ItemText <> '') or (AItems.Count = 0) then
    AItems.Add(Trim(ItemText));
end;


end.
