unit uPdn;

{$mode objfpc}{$H+}

interface

uses
  Classes, Contnrs, SysUtils, uDraughtsBoard;

type
  TPdnMoveNode = class
  private
    FParent: TPdnMoveNode;
    FChildren: TObjectList;
    function GetChild(I: Integer): TPdnMoveNode;
    function GetChildCount: Integer;
  public
    MoveText, AnnotationText: string;
    constructor Create;
    destructor Destroy; override;
    function AddMove(const Text: string; AsContinuation: Boolean): TPdnMoveNode;
    procedure MergeChildren(Source: TPdnMoveNode);
    function Clone: TPdnMoveNode;
    property Parent: TPdnMoveNode read FParent;
    property ChildCount: Integer read GetChildCount;
    property Children[I: Integer]: TPdnMoveNode read GetChild;
  end;

  TPdnGame = class
  private
    FParsedRoot: TPdnMoveNode;
    FParsedSignature: string;
    FHasResultTag: Boolean;
    function TreeDataSignature: string;
  public
    EventName: string;
    TournamentId: string;
    WhiteName: string;
    BlackName: string;
    ResultText: string;
    StartingFEN: string;
    InitialCommentText: string;
    ImportWarningsText: string;
    MoveAnnotationsText: string;
    MoveVariationAnnotationsText: string;
    MoveVariationsText: string;
    MovesText: string;
    constructor Create;
    destructor Destroy; override;
    function BuildMoveTree: TPdnMoveNode;
    procedure AssignFrom(ASource: TPdnGame);
  end;

  TPdnGameReadEvent = procedure(AGame: TPdnGame; ABytesRead,
    ATotalBytes: Int64; var AStop: Boolean) of object;

procedure LoadPdnGamesFromFile(const AFileName: string; AGames: TList);
procedure ReadPdnGamesFromFile(const AFileName: string;
  AOnGame: TPdnGameReadEvent);
procedure AppendPdnGameToFile(const AFileName: string; AGame: TPdnGame);
procedure AppendPdnTextToFile(const AFileName, APdnText: string);
function PdnGameToText(AGame: TPdnGame): string;
function PdnExportResult(const AText: string): string;
function AnnotationWithScore(const AAnnotation, AName, AScore: string): string;
function ExtractAnnotationValue(const AAnnotation, AName: string): string;
function AnnotationWithoutName(const AAnnotation, AName: string): string;
procedure DecodeVariationAnnotations(const AText: string; ACount: Integer;
  AAnnotations: TStrings);
function EncodeVariationAnnotations(AAnnotations: TStrings): string;
function EncodePdnVariationLine(ADisplayAfterPly, ABasePly: Integer;
  const AMovesText: string): string;
function DecodePdnVariationLine(const ALine, AAnnotation: string;
  ADefaultDisplayAfterPly: Integer; out ADisplayAfterPly, ABasePly: Integer;
  out AMovesText, AVisibleAnnotation: string): Boolean;

implementation

uses FPJSON, JSONParser;

const
  DefaultPdnFen = 'W:W31-50:B1-20';
  VariationAnnotationsPrefix = '@pdn-annotations:';

constructor TPdnMoveNode.Create;
begin
  inherited Create;
  FChildren := TObjectList.Create(True);
end;

destructor TPdnMoveNode.Destroy;
begin
  FChildren.Free;
  inherited Destroy;
end;

function TPdnMoveNode.GetChild(I: Integer): TPdnMoveNode;
begin
  Result := TPdnMoveNode(FChildren[I]);
end;

function TPdnMoveNode.GetChildCount: Integer;
begin
  Result := FChildren.Count;
end;

function TPdnMoveNode.AddMove(const Text: string; AsContinuation: Boolean): TPdnMoveNode;
var I: Integer;
begin
  Result := nil;
  for I := 0 to ChildCount - 1 do
    if Children[I].MoveText = NormalizeMoveNotation(Text) then
    begin Result := Children[I]; Break; end;
  if Result = nil then
  begin
    Result := TPdnMoveNode.Create;
    Result.FParent := Self;
    Result.MoveText := NormalizeMoveNotation(Text);
    FChildren.Add(Result);
  end;
  if AsContinuation then FChildren.Move(FChildren.IndexOf(Result), 0);
end;

procedure TPdnMoveNode.MergeChildren(Source: TPdnMoveNode);
var I: Integer; Child: TPdnMoveNode;
begin
  if Source = nil then Exit;
  for I := 0 to Source.ChildCount - 1 do
  begin
    Child := AddMove(Source.Children[I].MoveText, False);
    if Child.AnnotationText = '' then Child.AnnotationText := Source.Children[I].AnnotationText
    else if (Source.Children[I].AnnotationText <> '') and
      (Child.AnnotationText <> Source.Children[I].AnnotationText) then
      Child.AnnotationText += '; ' + Source.Children[I].AnnotationText;
    Child.MergeChildren(Source.Children[I]);
  end;
end;

function TPdnMoveNode.Clone: TPdnMoveNode;
begin
  Result := TPdnMoveNode.Create;
  try
    Result.MoveText := MoveText;
    Result.AnnotationText := AnnotationText;
    Result.MergeChildren(Self);
  except Result.Free; raise; end;
end;

function TPdnGame.TreeDataSignature: string;
begin
  Result := StartingFEN + #0 + MovesText + #0 + MoveAnnotationsText + #0 +
    InitialCommentText + #0 + MoveVariationsText + #0 + MoveVariationAnnotationsText;
end;

destructor TPdnGame.Destroy;
begin
  FParsedRoot.Free;
  inherited Destroy;
end;

constructor TPdnGame.Create;
begin
  inherited Create;
  EventName := '?';
  WhiteName := 'White';
  BlackName := 'Black';
  ResultText := '*';
  StartingFEN := DefaultPdnFen;
end;

procedure TPdnGame.AssignFrom(ASource: TPdnGame);
begin
  if ASource = nil then
    Exit;
  if ASource = Self then Exit;
  FreeAndNil(FParsedRoot);
  if ASource.FParsedRoot <> nil then FParsedRoot := ASource.FParsedRoot.Clone;
  FParsedSignature := ASource.FParsedSignature;
  EventName := ASource.EventName;
  TournamentId := ASource.TournamentId;
  WhiteName := ASource.WhiteName;
  BlackName := ASource.BlackName;
  ResultText := ASource.ResultText;
  FHasResultTag := ASource.FHasResultTag;
  StartingFEN := ASource.StartingFEN;
  InitialCommentText := ASource.InitialCommentText;
  ImportWarningsText := ASource.ImportWarningsText;
  MoveAnnotationsText := ASource.MoveAnnotationsText;
  MoveVariationAnnotationsText := ASource.MoveVariationAnnotationsText;
  MoveVariationsText := ASource.MoveVariationsText;
  MovesText := ASource.MovesText;
end;

function PdnUnquote(const AText: string): string;
var
  I: Integer;
  LEscaped: Boolean;
begin
  Result := '';
  LEscaped := False;
  for I := 1 to Length(AText) do
  begin
    if LEscaped then
    begin
      Result += AText[I];
      LEscaped := False;
    end
    else if AText[I] = '\' then
      LEscaped := True
    else
      Result += AText[I];
  end;
end;

function PdnQuote(const AText: string): string;
begin
  Result := StringReplace(AText, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
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

function IsPdnResultToken(const AText: string): Boolean;
begin
  Result := SameText(AText, '2-0') or SameText(AText, '1-1') or
    SameText(AText, '0-2') or SameText(AText, '1-0') or
    SameText(AText, '0-1') or SameText(AText, '1/2-1/2') or
    SameText(AText, '1/2:1/2') or SameText(AText, '0-0') or SameText(AText, '*');
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

function StripPdnMoveText(const AText: string): string;
var
  I: Integer;
  LBraceDepth: Integer;
  LInLineComment: Boolean;
  LParenDepth: Integer;
begin
  Result := '';
  LBraceDepth := 0;
  LInLineComment := False;
  LParenDepth := 0;
  for I := 1 to Length(AText) do
  begin
    if LInLineComment then
    begin
      if AText[I] in [#10, #13] then
      begin
        LInLineComment := False;
        Result += ' ';
      end;
      Continue;
    end;

    if LBraceDepth > 0 then
    begin
      if AText[I] = '{' then
        Inc(LBraceDepth)
      else if AText[I] = '}' then
        Dec(LBraceDepth);
      Continue;
    end;

    if LParenDepth > 0 then
    begin
      if AText[I] = '(' then
        Inc(LParenDepth)
      else if AText[I] = ')' then
        Dec(LParenDepth);
      Continue;
    end;

    case AText[I] of
      '{':
        Inc(LBraceDepth);
      '(':
        Inc(LParenDepth);
      ';':
        LInLineComment := True;
      #10, #13, #9:
        Result += ' ';
    else
      Result += AText[I];
    end;
  end;
end;

function CleanMoveToken(AToken: string): string;
var
  DotPos: Integer;
  Prefix: string;
  Rest: string;
begin
  Result := Trim(AToken);
  while (Result <> '') and (Result[Length(Result)] in
    ['!', '?', '+', '=', ',', ';', ':']) do
    Delete(Result, Length(Result), 1);
  DotPos := Pos('.', Result);
  if DotPos <= 0 then
    Exit;

  Prefix := Copy(Result, 1, DotPos - 1);
  Rest := Copy(Result, DotPos + 1, MaxInt);
  while (Rest <> '') and (Rest[1] = '.') do
    Delete(Rest, 1, 1);
  if (Prefix <> '') and (StrToIntDef(Prefix, -1) >= 0) and
    (Rest <> '') and (Rest[1] in ['0'..'9']) and
    ((Pos('-', Rest) > 0) or (Pos('x', LowerCase(Rest)) > 0)) then
    Result := Rest;
end;

function LooksLikePdnMove(const AToken: string): Boolean;
begin
  Result := (AToken <> '') and (AToken[1] in ['0'..'9']) and
    ((Pos('-', AToken) > 0) or (Pos('x', LowerCase(AToken)) > 0));
end;

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

function AnnotationContainsName(const AAnnotation, AName: string): Boolean;
var
  I: Integer;
  ItemText: string;
  Items: TStringList;
begin
  Result := False;
  Items := TStringList.Create;
  try
    SplitAnnotationItems(AAnnotation, Items);
    for I := 0 to Items.Count - 1 do
    begin
      ItemText := Trim(Items[I]);
      if (ItemText <> '') and AnnotationNameMatches(ItemText, 1, AName) then
        Exit(True);
    end;
  finally
    Items.Free;
  end;
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

function MoveListText(AMoves: TStrings): string;
begin
  if AMoves = nil then
    Exit('');
  Result := Trim(StringReplace(AMoves.Text, LineEnding, ' ', [rfReplaceAll]));
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

procedure DecodeVariationAnnotations(const AText: string; ACount: Integer;
  AAnnotations: TStrings);
var
  Data: TJSONData;
  I: Integer;
begin
  AAnnotations.Clear;
  for I := 1 to ACount do
    AAnnotations.Add('');
  if Copy(AText, 1, Length(VariationAnnotationsPrefix)) =
    VariationAnnotationsPrefix then
  begin
    Data := GetJSON(Copy(AText, Length(VariationAnnotationsPrefix) + 1, MaxInt));
    try
      if (Data.JSONType <> jtArray) or (Data.Count <> ACount) then
        raise EConvertError.Create('Invalid variation annotations');
      for I := 0 to ACount - 1 do
        AAnnotations[I] := Data.Items[I].AsString;
    finally
      Data.Free;
    end;
  end
  else if ACount > 0 then
    AAnnotations[ACount - 1] := AText;
end;

function EncodePdnVariationLine(ADisplayAfterPly, ABasePly: Integer;
  const AMovesText: string): string;
begin
  Result := IntToStr(ADisplayAfterPly) + #9 + IntToStr(ABasePly) + #9 +
    Trim(AMovesText);
end;

function DecodePdnVariationLine(const ALine, AAnnotation: string;
  ADefaultDisplayAfterPly: Integer; out ADisplayAfterPly, ABasePly: Integer;
  out AMovesText, AVisibleAnnotation: string): Boolean;
var
  BaseText: string;
  FirstTab: Integer;
  SecondTab: Integer;
begin
  Result := False;
  ADisplayAfterPly := ADefaultDisplayAfterPly;
  ABasePly := ADefaultDisplayAfterPly;
  AMovesText := '';
  AVisibleAnnotation := Trim(AAnnotation);

  FirstTab := Pos(#9, ALine);
  SecondTab := 0;
  if FirstTab > 0 then
    SecondTab := FirstTab + Pos(#9, Copy(ALine, FirstTab + 1, MaxInt));
  if (FirstTab > 0) and (SecondTab > FirstTab) and
    (StrToIntDef(Trim(Copy(ALine, 1, FirstTab - 1)), -1) >= 0) and
    (StrToIntDef(Trim(Copy(ALine, FirstTab + 1,
    SecondTab - FirstTab - 1)), -1) >= 0) then
  begin
    ADisplayAfterPly := StrToIntDef(Trim(Copy(ALine, 1, FirstTab - 1)),
      ADefaultDisplayAfterPly);
    ABasePly := StrToIntDef(Trim(Copy(ALine, FirstTab + 1,
      SecondTab - FirstTab - 1)), ADisplayAfterPly);
    AMovesText := Trim(Copy(ALine, SecondTab + 1, MaxInt));
  end
  else
  begin
    AMovesText := Trim(ALine);
    BaseText := ExtractAnnotationValue(AVisibleAnnotation, 'base_ply');
    if BaseText <> '' then
      ABasePly := StrToIntDef(BaseText, ADisplayAfterPly)
    else if ExtractAnnotationValue(AVisibleAnnotation, 'annotator') <> '' then
    begin
      ABasePly := ADisplayAfterPly - 1;
      if ABasePly < 0 then
        ABasePly := 0;
    end;
  end;

  if Copy(AVisibleAnnotation, 1, Length(VariationAnnotationsPrefix)) <>
    VariationAnnotationsPrefix then
    AVisibleAnnotation := AnnotationWithoutName(AVisibleAnnotation, 'base_ply');
  Result := AMovesText <> '';
end;

function StartingSideFromFen(const AStartingFEN: string): TDraughtsSide;
begin
  Result := dsWhite;
  if (Trim(AStartingFEN) <> '') and (UpCase(Trim(AStartingFEN)[1]) = 'B') then
    Result := dsBlack;
end;

function PlyForMoveNumberAndSide(AMoveNumber: Integer;
  ASide, AStartingSide: TDraughtsSide): Integer;
begin
  if AMoveNumber <= 0 then
    Exit(-1);
  if AStartingSide = dsWhite then
  begin
    if ASide = dsWhite then
      Result := (AMoveNumber - 1) * 2 + 1
    else
      Result := (AMoveNumber - 1) * 2 + 2;
  end
  else
  begin
    if ASide = dsBlack then
      Result := (AMoveNumber - 1) * 2 + 1
    else
      Result := (AMoveNumber - 1) * 2;
  end;
end;

function InferVariationBasePly(const AVariationText, AStartingFEN: string;
  ADefaultBasePly: Integer): Integer;
var
  DotCount: Integer;
  DotPos: Integer;
  I: Integer;
  MoveNumber: Integer;
  Prefix: string;
  Side: TDraughtsSide;
  Text: string;
  Token: string;
  VariationPly: Integer;
begin
  Result := ADefaultBasePly;
  Text := Trim(AVariationText);
  Token := '';
  for I := 1 to Length(Text) do
  begin
    if Text[I] in [' ', #9, #10, #13, '{', '('] then
    begin
      if Token <> '' then
        Break;
    end
    else
      Token += Text[I];
  end;

  DotPos := Pos('.', Token);
  if DotPos <= 1 then
    Exit;
  Prefix := Copy(Token, 1, DotPos - 1);
  MoveNumber := StrToIntDef(Prefix, -1);
  if MoveNumber <= 0 then
    Exit;

  DotCount := 0;
  for I := DotPos to Length(Token) do
    if Token[I] = '.' then
      Inc(DotCount)
    else
      Break;
  if DotCount >= 3 then
    Side := dsBlack
  else
    Side := dsWhite;

  VariationPly := PlyForMoveNumberAndSide(MoveNumber, Side,
    StartingSideFromFen(AStartingFEN));
  if VariationPly >= 0 then
    Result := VariationPly - 1;
end;

procedure ExtractPdnMoveData(const AText: string; AMoves, AAnnotations,
  AVariations, AVariationAnnotations: TStrings; const AStartingFEN: string = '';
  AInitialComments: TStrings = nil; APlyOffset: Integer = 0;
  AWarnings: TStrings = nil; ATreeRoot: TPdnMoveNode = nil;
  AMovetextResult: PString = nil);
var
  I: Integer;
  LBraceDepth: Integer;
  LComment: string;
  LInLineComment: Boolean;
  LLastMoveIndex: Integer;
  LToken: string;
  LVariationText: string;
  LVariationClosed: Boolean;
  Positions: array of TPdnMoveNode;

  procedure Warn(const AMessage: string);
  begin
    if AWarnings <> nil then AWarnings.Add(AMessage);
  end;

  procedure ProcessToken;
  var
    LCleanToken: string;
  begin
    LCleanToken := CleanMoveToken(LToken);
    LToken := '';
    if LCleanToken = '' then
      Exit;
    if LCleanToken[1] = '$' then
      Exit;
    if (Pos('.', LCleanToken) > 0) and (Pos('-', LCleanToken) = 0) and
      (Pos('x', LowerCase(LCleanToken)) = 0) then
      Exit;
    if IsPdnResultToken(LCleanToken) then
    begin
      if AMovetextResult <> nil then
        AMovetextResult^ := NormalizePdnResult(LCleanToken);
      Exit;
    end;
    if LooksLikePdnMove(LCleanToken) then
    begin
      AMoves.Add(NormalizeMoveNotation(LCleanToken));
      AAnnotations.Add('');
      LLastMoveIndex := AMoves.Count - 1;
      if ATreeRoot <> nil then
      begin
        SetLength(Positions, AMoves.Count + 1);
        Positions[AMoves.Count] := Positions[AMoves.Count - 1].AddMove(LCleanToken, True);
      end;
    end;
  end;

  procedure ProcessComment;
  var
    LCommentText: string;
  begin
    LCommentText := Trim(StringReplace(StringReplace(LComment, #13, ' ',
      [rfReplaceAll]), #10, ' ', [rfReplaceAll]));
    LComment := '';
    if LCommentText = '' then
      Exit;
    if (LLastMoveIndex < 0) or (LLastMoveIndex >= AAnnotations.Count) then
    begin
      if AInitialComments <> nil then
        AInitialComments.Add(LCommentText);
      Exit;
    end;
    if AAnnotations[LLastMoveIndex] <> '' then
      LCommentText := AAnnotations[LLastMoveIndex] + '; ' + LCommentText;
    AAnnotations[LLastMoveIndex] := LCommentText;
    if ATreeRoot <> nil then Positions[LLastMoveIndex + 1].AnnotationText := LCommentText;
  end;

  function ReadParenthesizedText(out AClosed: Boolean): string;
  var
    Depth: Integer;
    InBrace: Integer;
    InLineComment: Boolean;
  begin
    Result := '';
    AClosed := False;
    Depth := 1;
    InBrace := 0;
    InLineComment := False;
    Inc(I);
    while I <= Length(AText) do
    begin
      if InLineComment then
      begin
        Result += AText[I];
        if AText[I] in [#10, #13] then InLineComment := False;
      end
      else if InBrace > 0 then
      begin
        if AText[I] = '{' then
          Inc(InBrace)
        else if AText[I] = '}' then
          Dec(InBrace);
        Result += AText[I];
      end
      else if AText[I] = '{' then
      begin
        Inc(InBrace);
        Result += AText[I];
      end
      else if AText[I] = ';' then
      begin
        InLineComment := True;
        Result += AText[I];
      end
      else if AText[I] = '(' then
      begin
        Inc(Depth);
        Result += AText[I];
      end
      else if AText[I] = ')' then
      begin
        Dec(Depth);
        if Depth = 0 then
        begin
          AClosed := True;
          Exit;
        end;
        Result += AText[I];
      end
      else
        Result += AText[I];
      Inc(I);
    end;
  end;

  procedure ProcessVariation(const AVariationText: string);
  var
    LBasePly: Integer;
    LSlot: Integer;
    LVariationAnnotation: string;
    LVariationAnnotations: TStringList;
    LVariationMoves: TStringList;
    LInitialComments: TStringList;
    NestedLines, NestedAnnotations, NestedMoves, NestedMoveAnnotations: TStringList;
    CombinedMoves, CombinedAnnotations: TStringList;
    J, K, NestedDisplay, NestedBase, PrefixCount: Integer;
    NestedText, NestedComment: string;
    BranchRoot: TPdnMoveNode;
  begin
    if (AVariations = nil) or (AVariationAnnotations = nil) then
      Exit;

    LSlot := APlyOffset + AMoves.Count;
    LBasePly := LSlot - 1;
    if LBasePly < APlyOffset then
      LBasePly := APlyOffset;
    LBasePly := InferVariationBasePly(AVariationText, AStartingFEN, LBasePly);
    if (LBasePly < APlyOffset) or (LBasePly > LSlot) then
    begin
      Warn('Skipped variation after ply ' + IntToStr(LSlot) +
        ': its numbered start lies outside its parent line.');
      Exit;
    end;
    BranchRoot := nil;
    if ATreeRoot <> nil then BranchRoot := TPdnMoveNode.Create;
    LVariationAnnotations := TStringList.Create;
    LVariationMoves := TStringList.Create;
    LInitialComments := TStringList.Create;
    NestedLines := TStringList.Create;
    NestedAnnotations := TStringList.Create;
    NestedMoves := TStringList.Create;
    NestedMoveAnnotations := TStringList.Create;
    CombinedMoves := TStringList.Create;
    CombinedAnnotations := TStringList.Create;
    try
      ExtractPdnMoveData(AVariationText, LVariationMoves,
        LVariationAnnotations, NestedLines, NestedAnnotations, AStartingFEN,
        LInitialComments, LBasePly, AWarnings, BranchRoot);
      if LVariationMoves.Count = 0 then
        Exit;
      if LInitialComments.Count > 0 then
      begin
        LVariationAnnotation := Trim(StringReplace(LInitialComments.Text,
          LineEnding, ' ', [rfReplaceAll]));
        if LVariationAnnotations[0] <> '' then
          LVariationAnnotation += '; ' + LVariationAnnotations[0];
        LVariationAnnotations[0] := LVariationAnnotation;
      end;
      if LVariationAnnotations.Count > 0 then
      begin
        LVariationAnnotation := Trim(
          LVariationAnnotations[LVariationAnnotations.Count - 1]);
        LBasePly := StrToIntDef(ExtractAnnotationValue(LVariationAnnotation,
          'base_ply'), LBasePly);
      end
      else
        LVariationAnnotation := '';
      if (LBasePly < APlyOffset) or (LBasePly > LSlot) then
      begin
        Warn('Skipped variation after ply ' + IntToStr(LSlot) +
          ': its annotated start lies outside its parent line.');
        Exit;
      end;
      if (ATreeRoot <> nil) and (BranchRoot.ChildCount > 0) then
      begin
        BranchRoot.Children[0].AnnotationText := LVariationAnnotations[0];
        Positions[LBasePly - APlyOffset].MergeChildren(BranchRoot);
      end;
      AVariations.Add(EncodePdnVariationLine(LSlot, LBasePly,
        MoveListText(LVariationMoves)));
      if LVariationAnnotations.Count > 0 then
        AVariationAnnotations.Add(EncodeVariationAnnotations(LVariationAnnotations))
      else
        AVariationAnnotations.Add('');
      for J := 0 to NestedLines.Count - 1 do
      begin
        if not DecodePdnVariationLine(NestedLines[J], NestedAnnotations[J], 0,
          NestedDisplay, NestedBase, NestedText, NestedComment) then
          Continue;
        PrefixCount := NestedBase - LBasePly;
        if (PrefixCount < 0) or (PrefixCount > LVariationMoves.Count) then
        begin
          Warn('Skipped nested variation: its start lies outside its parent line.');
          Continue;
        end;
        ExtractStrings([' ', #9, #10, #13], [], PChar(NestedText), NestedMoves);
        DecodeVariationAnnotations(NestedComment, NestedMoves.Count,
          NestedMoveAnnotations);
        CombinedMoves.Clear;
        CombinedAnnotations.Clear;
        for K := 0 to PrefixCount - 1 do
        begin
          CombinedMoves.Add(LVariationMoves[K]);
          CombinedAnnotations.Add(LVariationAnnotations[K]);
        end;
        CombinedMoves.AddStrings(NestedMoves);
        CombinedAnnotations.AddStrings(NestedMoveAnnotations);
        AVariations.Add(EncodePdnVariationLine(LSlot, LBasePly,
          MoveListText(CombinedMoves)));
        AVariationAnnotations.Add(EncodeVariationAnnotations(CombinedAnnotations));
        NestedMoves.Clear;
      end;
    finally
      BranchRoot.Free;
      CombinedAnnotations.Free;
      CombinedMoves.Free;
      NestedMoveAnnotations.Free;
      NestedMoves.Free;
      NestedAnnotations.Free;
      NestedLines.Free;
      LInitialComments.Free;
      LVariationMoves.Free;
      LVariationAnnotations.Free;
    end;
  end;
begin
  if AMoves <> nil then
    AMoves.Clear;
  if AAnnotations <> nil then
    AAnnotations.Clear;
  if AVariations <> nil then
    AVariations.Clear;
  if AVariationAnnotations <> nil then
    AVariationAnnotations.Clear;
  if (AMoves = nil) or (AAnnotations = nil) then
    Exit;

  if AMovetextResult <> nil then AMovetextResult^ := '';
  SetLength(Positions, 1);
  Positions[0] := ATreeRoot;
  LBraceDepth := 0;
  LComment := '';
  LInLineComment := False;
  LLastMoveIndex := -1;
  LToken := '';
  I := 1;
  while I <= Length(AText) do
  begin
    if LInLineComment then
    begin
      if AText[I] in [#10, #13] then
      begin
        LInLineComment := False;
        ProcessToken;
      end;
      Inc(I);
      Continue;
    end;

    if LBraceDepth > 0 then
    begin
      if AText[I] = '{' then
      begin
        Inc(LBraceDepth);
        LComment += AText[I];
      end
      else if AText[I] = '}' then
      begin
        Dec(LBraceDepth);
        if LBraceDepth = 0 then
          ProcessComment
        else
          LComment += AText[I];
      end
      else
        LComment += AText[I];
      Inc(I);
      Continue;
    end;

    case AText[I] of
      '{':
        begin
          ProcessToken;
          Inc(LBraceDepth);
          LComment := '';
        end;
      '(':
        begin
          ProcessToken;
          LVariationText := ReadParenthesizedText(LVariationClosed);
          if LVariationClosed then ProcessVariation(LVariationText)
          else Warn('Skipped unterminated variation after ply ' +
            IntToStr(APlyOffset + AMoves.Count) + '.');
        end;
      ')':
        begin
          ProcessToken;
          Warn('Ignored unmatched closing variation bracket after ply ' +
            IntToStr(APlyOffset + AMoves.Count) + '.');
        end;
      ';':
        begin
          ProcessToken;
          LInLineComment := True;
        end;
      ' ', #9, #10, #13:
        ProcessToken;
    else
      LToken += AText[I];
    end;
    Inc(I);
  end;
  ProcessToken;
end;

procedure ExtractMovesAndAnnotationsFromPdnText(const AText: string;
  AMoves, AAnnotations: TStrings);
begin
  ExtractPdnMoveData(AText, AMoves, AAnnotations, nil, nil);
end;

function ExtractMovesFromPdnText(const AText: string): string;
var
  LAnnotations: TStringList;
  LMoves: TStringList;
begin
  LAnnotations := TStringList.Create;
  LMoves := TStringList.Create;
  try
    ExtractMovesAndAnnotationsFromPdnText(AText, LMoves, LAnnotations);
    Result := Trim(StringReplace(LMoves.Text, LineEnding, ' ', [rfReplaceAll]));
  finally
    LMoves.Free;
    LAnnotations.Free;
  end;
end;

procedure ParsePdnTag(const ALine: string; AGame: TPdnGame);
var
  LFirstQuote: Integer;
  LLastQuote: Integer;
  LName: string;
  LSpace: Integer;
  LValue: string;
begin
  if (AGame = nil) or (Length(ALine) < 3) or (ALine[1] <> '[') then
    Exit;

  LSpace := 2;
  while (LSpace <= Length(ALine)) and
    not (ALine[LSpace] in [' ', #9, #10, #13]) do Inc(LSpace);
  if LSpace <= 2 then
    Exit;
  LName := Copy(ALine, 2, LSpace - 2);
  LFirstQuote := Pos('"', ALine);
  LLastQuote := Length(ALine);
  while (LLastQuote > LFirstQuote) and (ALine[LLastQuote] <> '"') do
    Dec(LLastQuote);
  if (LFirstQuote = 0) or (LLastQuote <= LFirstQuote) then
    Exit;
  LValue := PdnUnquote(Copy(ALine, LFirstQuote + 1,
    LLastQuote - LFirstQuote - 1));

  if SameText(LName, 'TournamentId') then
    AGame.TournamentId := LValue
  else if SameText(LName, 'Event') then
    AGame.EventName := LValue
  else if SameText(LName, 'White') then
    AGame.WhiteName := LValue
  else if SameText(LName, 'Black') then
    AGame.BlackName := LValue
  else if SameText(LName, 'Result') then
  begin
    AGame.ResultText := NormalizePdnResult(LValue);
    AGame.FHasResultTag := True;
  end
  else if SameText(LName, 'FEN') then
    AGame.StartingFEN := Trim(LValue);
end;

procedure ClearGameList(AGames: TList);
var
  I: Integer;
begin
  if AGames = nil then
    Exit;
  for I := 0 to AGames.Count - 1 do
    TObject(AGames[I]).Free;
  AGames.Clear;
end;

procedure AddCurrentGame(var ACurrent: TPdnGame; AMoveLines: TStrings;
  AGames: TList);
var
  LAnnotations: TStringList;
  LInitialComments: TStringList;
  LMoves: TStringList;
  LVariationAnnotations: TStringList;
  LVariations: TStringList;
  LWarnings: TStringList;
  LMovetextResult: string;
begin
  if ACurrent = nil then
    Exit;
  LAnnotations := TStringList.Create;
  LInitialComments := TStringList.Create;
  LMoves := TStringList.Create;
  LVariationAnnotations := TStringList.Create;
  LVariations := TStringList.Create;
  LWarnings := TStringList.Create;
  try
    FreeAndNil(ACurrent.FParsedRoot);
    ACurrent.FParsedRoot := TPdnMoveNode.Create;
    ExtractPdnMoveData(AMoveLines.Text, LMoves, LAnnotations, LVariations,
      LVariationAnnotations, ACurrent.StartingFEN, LInitialComments, 0, LWarnings, ACurrent.FParsedRoot, @LMovetextResult);
    if LMovetextResult <> '' then
    begin
      if not ACurrent.FHasResultTag then
        ACurrent.ResultText := LMovetextResult
      else if ACurrent.ResultText <> LMovetextResult then
        LWarnings.Add('Result tag "' + ACurrent.ResultText +
          '" conflicts with movetext result "' + LMovetextResult +
          '"; kept the Result tag.');
    end;
    ACurrent.InitialCommentText := Trim(StringReplace(LInitialComments.Text,
      LineEnding, ' ', [rfReplaceAll]));
    ACurrent.ImportWarningsText := LWarnings.Text;
    ACurrent.MovesText := MoveListText(LMoves);
    ACurrent.MoveAnnotationsText := LAnnotations.Text;
    ACurrent.MoveVariationsText := LVariations.Text;
    ACurrent.MoveVariationAnnotationsText := LVariationAnnotations.Text;
    ACurrent.FParsedRoot.AnnotationText := ACurrent.InitialCommentText;
    if Trim(ACurrent.StartingFEN) = '' then
      ACurrent.StartingFEN := DefaultPdnFen;
    if Trim(ACurrent.ResultText) = '' then
      ACurrent.ResultText := '*';
    ACurrent.FParsedSignature := ACurrent.TreeDataSignature;
    if AGames <> nil then
    begin
      AGames.Add(ACurrent);
      ACurrent := nil;
    end;
    AMoveLines.Clear;
  finally
    LWarnings.Free;
    LInitialComments.Free;
    LVariations.Free;
    LVariationAnnotations.Free;
    LMoves.Free;
    LAnnotations.Free;
  end;
end;

type
  TPdnGameListCollector = class
    Games: TList;
    procedure Collect(AGame: TPdnGame; ABytesRead, ATotalBytes: Int64;
      var AStop: Boolean);
  end;

procedure TPdnGameListCollector.Collect(AGame: TPdnGame; ABytesRead,
  ATotalBytes: Int64; var AStop: Boolean);
var
  Copy: TPdnGame;
begin
  Copy := TPdnGame.Create;
  try
    Copy.AssignFrom(AGame);
    Games.Add(Copy);
  except
    Copy.Free;
    raise;
  end;
end;

procedure LoadPdnGamesFromFile(const AFileName: string; AGames: TList);
var
  Collector: TPdnGameListCollector;
begin
  if AGames = nil then Exit;
  ClearGameList(AGames);
  Collector := TPdnGameListCollector.Create;
  try
    Collector.Games := AGames;
    ReadPdnGamesFromFile(AFileName, @Collector.Collect);
  finally
    Collector.Free;
  end;
end;

procedure ReadPdnGamesFromFile(const AFileName: string;
  AOnGame: TPdnGameReadEvent);
var
  Buffer: array[0..65535] of Byte;
  BytesRead, I, BraceDepth, VariationDepth: Integer;
  Current: TPdnGame;
  MoveLines, HeaderNames: TStringList;
  MoveLine, TagText, Token: string;
  Stop, InTag, InQuote, Escaped, InLineComment: Boolean;
  HasMovetext, LineHasContent, PreviousCR, ResultSeen: Boolean;
  Stream: TFileStream;
  TotalBytes: Int64;

  procedure EnsureGame;
  begin
    if Current = nil then Current := TPdnGame.Create;
  end;

  procedure FinishGame;
  begin
    if Current = nil then Exit;
    MoveLines.Add(MoveLine);
    MoveLine := '';
    AddCurrentGame(Current, MoveLines, nil);
    try
      AOnGame(Current, Stream.Position, TotalBytes, Stop);
    finally
      FreeAndNil(Current);
    end;
    HeaderNames.Clear;
    ResultSeen := False;
    HasMovetext := False;
    BraceDepth := 0;
    VariationDepth := 0;
  end;

  procedure FinishToken;
  var
    Value: string;
  begin
    if Token = '' then Exit;
    Value := Token;
    Token := '';
    // Delay delivery after a result so trailing comments/NAGs stay with their
    // game. Only a new top-level token or header starts the next game.
    if ResultSeen and (VariationDepth = 0) and IsPdnResultToken(CleanMoveToken(Value)) then Exit;
    if ResultSeen and (VariationDepth = 0) and (Value[1] <> '$') then FinishGame;
    if Stop then Exit;
    EnsureGame;
    MoveLine += Value;
    HasMovetext := True;
    if (VariationDepth = 0) and IsPdnResultToken(CleanMoveToken(Value)) then
      ResultSeen := True;
  end;

  procedure FinishTag;
  var
    NameEnd: Integer;
    Name: string;
  begin
    NameEnd := 2;
    while (NameEnd <= Length(TagText)) and
      not (TagText[NameEnd] in [' ', #9, #10, #13, ']']) do Inc(NameEnd);
    Name := Copy(TagText, 2, NameEnd - 2);
    // Whitespace cannot establish a game boundary: headers may contain blank
    // lines even after Result. A repeated tag identifies a new header block.
    if HeaderNames.IndexOf(Name) >= 0 then FinishGame;
    if Stop then Exit;
    EnsureGame;
    ParsePdnTag(TagText, Current);
    HeaderNames.Add(Name);
    TagText := '';
    InTag := False;
  end;

  procedure ReadChar(C: Char);
  begin
    if InTag then
    begin
      TagText += C;
      if Escaped then Escaped := False
      else if InQuote and (C = '\') then Escaped := True
      else if C = '"' then InQuote := not InQuote
      else if (C = ']') and not InQuote then FinishTag;
      Exit;
    end;
    if InLineComment then
    begin
      MoveLine += C;
      if C = #10 then
      begin
        InLineComment := False;
        MoveLines.Add(MoveLine);
        MoveLine := '';
        LineHasContent := False;
      end;
      Exit;
    end;
    if BraceDepth > 0 then
    begin
      MoveLine += C;
      if C = '{' then Inc(BraceDepth)
      else if C = '}' then Dec(BraceDepth);
      if C = #10 then
      begin
        MoveLines.Add(MoveLine);
        MoveLine := '';
        LineHasContent := False;
      end
      else if not (C in [' ', #9]) then LineHasContent := True;
      Exit;
    end;
    if C in [' ', #9, #10, '[', '{', ';', '(', ')'] then FinishToken;
    if Stop then Exit;
    // Recover at a header on a new line even if a preceding RAV was unclosed.
    // Brackets inside brace/line comments and quoted values never reach here.
    if (C = '[') and ((VariationDepth = 0) or not LineHasContent) then
    begin
      if HasMovetext then FinishGame;
      if Stop then Exit;
      InTag := True;
      InQuote := False;
      Escaped := False;
      TagText := '[';
      LineHasContent := True;
      Exit;
    end;
    if C = #10 then
    begin
      MoveLines.Add(MoveLine);
      MoveLine := '';
      LineHasContent := False;
      Exit;
    end;
    if C in [' ', #9] then
    begin
      MoveLine += C;
      Exit;
    end;
    EnsureGame;
    LineHasContent := True;
    case C of
      '{':
        begin
          MoveLine += C;
          BraceDepth := 1;
        end;
      ';':
        begin
          MoveLine += C;
          InLineComment := True;
        end;
      '(':
        begin
          MoveLine += C;
          Inc(VariationDepth);
          HasMovetext := True;
        end;
      ')':
        begin
          MoveLine += C;
          if VariationDepth > 0 then Dec(VariationDepth);
          HasMovetext := True;
        end;
    else
      Token += C;
    end;
  end;

begin
  if not Assigned(AOnGame) then Exit;
  Current := nil;
  MoveLine := '';
  TagText := '';
  Token := '';
  ResultSeen := False;
  Stop := False;
  InTag := False;
  InQuote := False;
  Escaped := False;
  InLineComment := False;
  HasMovetext := False;
  LineHasContent := False;
  PreviousCR := False;
  BraceDepth := 0;
  VariationDepth := 0;
  MoveLines := TStringList.Create;
  HeaderNames := TStringList.Create;
  Stream := nil;
  try
    Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
    TotalBytes := Stream.Size;
    // Accept the optional UTF-8 BOM without passing it to the token reader.
    BytesRead := Stream.Read(Buffer, 3);
    if (BytesRead <> 3) or (Buffer[0] <> $EF) or
      (Buffer[1] <> $BB) or (Buffer[2] <> $BF) then Stream.Position := 0;
    repeat
      BytesRead := Stream.Read(Buffer, SizeOf(Buffer));
      for I := 0 to BytesRead - 1 do
      begin
        if Buffer[I] = 13 then ReadChar(#10)
        else if not ((Buffer[I] = 10) and PreviousCR) then ReadChar(Chr(Buffer[I]));
        PreviousCR := Buffer[I] = 13;
        if Stop then Break;
      end;
    until (BytesRead = 0) or Stop;
    if not Stop then FinishToken;
    if not Stop then FinishGame;
  finally
    Current.Free;
    HeaderNames.Free;
    MoveLines.Free;
    Stream.Free;
  end;
end;

function FormatVariationForPdn(const AMovesText, AStartingFEN: string;
  APlyOffset: Integer; const AAnnotationsText: string): string;
var
  I: Integer;
  LMoves: TStringList;
  LAnnotations: TStringList;
  LMoveNumber: Integer;
  LPly: Integer;
  LPlyFromWhiteStart: Integer;
  LSide: TDraughtsSide;
  LStartingSide: TDraughtsSide;
begin
  Result := '';
  LMoves := TStringList.Create;
  LAnnotations := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)), LMoves);
    DecodeVariationAnnotations(AAnnotationsText, LMoves.Count, LAnnotations);
    if LMoves.Count = 0 then
      Exit;

    LStartingSide := dsWhite;
    if (Trim(AStartingFEN) <> '') and (UpCase(Trim(AStartingFEN)[1]) = 'B') then
      LStartingSide := dsBlack;

    for I := 0 to LMoves.Count - 1 do
    begin
      LPly := APlyOffset + I + 1;
      if Result <> '' then
        Result += ' ';
      if ((LStartingSide = dsWhite) and Odd(LPly)) or
        ((LStartingSide = dsBlack) and (not Odd(LPly))) then
        LSide := dsWhite
      else
        LSide := dsBlack;
      LPlyFromWhiteStart := LPly;
      if LStartingSide = dsBlack then
        Inc(LPlyFromWhiteStart);
      LMoveNumber := ((LPlyFromWhiteStart - 1) div 2) + 1;
      if LSide = dsWhite then
        Result += IntToStr(LMoveNumber) + '. ' + LMoves[I]
      else if I = 0 then
        Result += IntToStr(LMoveNumber) + '... ' + LMoves[I]
      else
        Result += LMoves[I];
      if LAnnotations[I] <> '' then
        Result += ' {' + LAnnotations[I] + '}';
    end;
  finally
    LAnnotations.Free;
    LMoves.Free;
  end;
end;

function FormatMovesForPdn(const AMovesText, AAnnotationsText,
  AVariationsText, AVariationAnnotationsText, AResultText: string;
  const AStartingFEN: string): string;
var
  I: Integer;
  LAnnotations: TStringList;
  LDisplayAfterPly: Integer;
  LMoves: TStringList;
  LMoveNumber: Integer;
  LOut: TStringList;
  LSide: TDraughtsSide;
  LText: string;
  LVariations: TStringList;
  LVariationAnnotations: TStringList;
  LVariationBasePly: Integer;
  LVariationComment: string;
  LVariationMovesText: string;
  LVariationRawComment: string;
  LVariationText: string;

  procedure AppendVariationsAfterPly(ADisplayAfterPly: Integer);
  var
    J: Integer;
  begin
    for J := 0 to LVariations.Count - 1 do
    begin
      LVariationRawComment := '';
      if J < LVariationAnnotations.Count then
        LVariationRawComment := Trim(LVariationAnnotations[J]);
      if not DecodePdnVariationLine(LVariations[J], LVariationRawComment,
        ADisplayAfterPly, LDisplayAfterPly, LVariationBasePly,
        LVariationMovesText, LVariationComment) then
        Continue;
      if LDisplayAfterPly <> ADisplayAfterPly then
        Continue;
      LVariationText := FormatVariationForPdn(LVariationMovesText,
        AStartingFEN, LVariationBasePly, LVariationComment);
      if LVariationText <> '' then
      begin
        if LText <> '' then
          LText += ' ';
        LText += '(' + LVariationText + ')';
      end;
    end;
  end;
begin
  LMoves := TStringList.Create;
  LAnnotations := TStringList.Create;
  LVariations := TStringList.Create;
  LVariationAnnotations := TStringList.Create;
  LOut := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)), LMoves);
    LAnnotations.Text := AAnnotationsText;
    LVariations.Text := AVariationsText;
    LVariationAnnotations.Text := AVariationAnnotationsText;
    LSide := dsWhite;
    if (Trim(AStartingFEN) <> '') and (UpCase(Trim(AStartingFEN)[1]) = 'B') then
      LSide := dsBlack;
    LText := '';
    AppendVariationsAfterPly(0);
    for I := 0 to LMoves.Count - 1 do
    begin
      if LText <> '' then
        LText += ' ';
      if LSide = dsWhite then
      begin
        LMoveNumber := (I div 2) + 1;
        LText += IntToStr(LMoveNumber) + '. ' + LMoves[I];
        LSide := dsBlack;
      end
      else
      begin
        if I = 0 then
          LText += '1... ';
        LText += LMoves[I];
        LSide := dsWhite;
      end;
      if (I < LAnnotations.Count) and (Trim(LAnnotations[I]) <> '') then
        LText += ' {' + Trim(LAnnotations[I]) + '}';
      AppendVariationsAfterPly(I + 1);
      if Length(LText) > 78 then
      begin
        LOut.Add(Trim(LText));
        LText := '';
      end;
    end;
    if NormalizePdnResult(AResultText) <> '*' then
    begin
      if LText <> '' then
        LText += ' ';
      LText += PdnExportResult(AResultText);
    end;
    if LText <> '' then
      LOut.Add(Trim(LText));
    Result := LOut.Text;
  finally
    LOut.Free;
    LVariationAnnotations.Free;
    LVariations.Free;
    LAnnotations.Free;
    LMoves.Free;
  end;
end;

procedure AppendPdnGameToFile(const AFileName: string; AGame: TPdnGame);
begin
  if AGame = nil then
    Exit;
  AppendPdnTextToFile(AFileName, PdnGameToText(AGame));
end;

procedure AppendPdnTextToFile(const AFileName, APdnText: string);
var
  Lines: TStringList;
  Text: string;
begin
  Text := TrimRight(APdnText);
  if Trim(Text) = '' then
    Exit;
  Lines := TStringList.Create;
  try
    if FileExists(AFileName) then
      Lines.LoadFromFile(AFileName);
    if (Lines.Count > 0) and (Trim(Lines[Lines.Count - 1]) <> '') then
      Lines.Add('');
    Lines.Text := Lines.Text + Text + LineEnding;
    Lines.SaveToFile(AFileName);
  finally
    Lines.Free;
  end;
end;

function TPdnGame.BuildMoveTree: TPdnMoveNode;
var Moves, Annotations, Variations, VariationAnnotations: TStringList;
    Text: string;
begin
  if (FParsedRoot = nil) or (FParsedSignature <> TreeDataSignature) then
  begin
    FreeAndNil(FParsedRoot);
    FParsedRoot := TPdnMoveNode.Create;
    Moves := TStringList.Create;
    Annotations := TStringList.Create;
    Variations := TStringList.Create;
    VariationAnnotations := TStringList.Create;
    try
      try
        // Backward compatibility for games constructed from old database fields.
        Text := FormatMovesForPdn(MovesText, MoveAnnotationsText, MoveVariationsText,
          MoveVariationAnnotationsText, '*', StartingFEN);
        ExtractPdnMoveData(Text, Moves, Annotations, Variations, VariationAnnotations,
          StartingFEN, nil, 0, nil, FParsedRoot);
        FParsedRoot.AnnotationText := InitialCommentText;
        FParsedSignature := TreeDataSignature;
      except
        FreeAndNil(FParsedRoot);
        raise;
      end;
    finally
      VariationAnnotations.Free;
      Variations.Free;
      Annotations.Free;
      Moves.Free;
    end;
  end;
  Result := FParsedRoot.Clone;
end;

function PdnGameToText(AGame: TPdnGame): string;
var
  Lines: TStringList;
begin
  Result := '';
  if AGame = nil then
    Exit;
  Lines := TStringList.Create;
  try
    Lines.Add('[Event "' + PdnQuote(AGame.EventName) + '"]');
    if AGame.TournamentId <> '' then
      Lines.Add('[TournamentId "' + PdnQuote(AGame.TournamentId) + '"]');
    Lines.Add('[White "' + PdnQuote(AGame.WhiteName) + '"]');
    Lines.Add('[Black "' + PdnQuote(AGame.BlackName) + '"]');
    Lines.Add('[Result "' + PdnQuote(PdnExportResult(AGame.ResultText)) + '"]');
    if Trim(AGame.StartingFEN) <> DefaultPdnFen then
      Lines.Add('[SetUp "1"]');
    Lines.Add('[FEN "' + PdnQuote(AGame.StartingFEN) + '"]');
    Lines.Add('');
    if AGame.InitialCommentText <> '' then
      Lines.Add('{' + AGame.InitialCommentText + '}');
    Lines.Text := Lines.Text + FormatMovesForPdn(AGame.MovesText,
      AGame.MoveAnnotationsText, AGame.MoveVariationsText,
      AGame.MoveVariationAnnotationsText, AGame.ResultText, AGame.StartingFEN);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
