unit uPdn;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, uDraughtsBoard;

type
  TPdnGame = class
  public
    EventName: string;
    WhiteName: string;
    BlackName: string;
    ResultText: string;
    StartingFEN: string;
    MoveAnnotationsText: string;
    MovesText: string;
    constructor Create;
    procedure AssignFrom(ASource: TPdnGame);
  end;

  TPdnGameReadEvent = procedure(AGame: TPdnGame; ABytesRead,
    ATotalBytes: Int64; var AStop: Boolean) of object;

procedure LoadPdnGamesFromFile(const AFileName: string; AGames: TList);
procedure ReadPdnGamesFromFile(const AFileName: string;
  AOnGame: TPdnGameReadEvent);
procedure AppendPdnGameToFile(const AFileName: string; AGame: TPdnGame);
function PdnGameToText(AGame: TPdnGame): string;
function AnnotationWithScore(const AAnnotation, AName, AScore: string): string;
function ExtractAnnotationValue(const AAnnotation, AName: string): string;

implementation

const
  DefaultPdnFen = 'W:W31-50:B1-20';

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
  EventName := ASource.EventName;
  WhiteName := ASource.WhiteName;
  BlackName := ASource.BlackName;
  ResultText := ASource.ResultText;
  StartingFEN := ASource.StartingFEN;
  MoveAnnotationsText := ASource.MoveAnnotationsText;
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
    SameText(Result, '0-2') or SameText(Result, '*')) then
    Result := '*';
end;

function IsPdnResultToken(const AText: string): Boolean;
begin
  Result := SameText(AText, '2-0') or SameText(AText, '1-1') or
    SameText(AText, '0-2') or SameText(AText, '1-0') or
    SameText(AText, '0-1') or SameText(AText, '1/2-1/2') or
    SameText(AText, '1/2:1/2') or SameText(AText, '*');
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

function TrimPdnLine(const ALine: string): string;
begin
  Result := Trim(ALine);
  if Copy(Result, 1, 3) = #$EF#$BB#$BF then
    Delete(Result, 1, 3);
  Result := Trim(Result);
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
begin
  Result := Trim(AToken);
  while (Result <> '') and (Result[Length(Result)] in
    ['!', '?', '+', '=', ',', ';', ':']) do
    Delete(Result, Length(Result), 1);
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
end;

function ExtractAnnotationValue(const AAnnotation, AName: string): string;
var
  I: Integer;
  LowerText: string;
  StartPos: Integer;
begin
  Result := '';
  LowerText := LowerCase(AAnnotation);
  StartPos := Pos(LowerCase(AName) + ':', LowerText);
  if StartPos <= 0 then
    StartPos := Pos(LowerCase(AName) + '=', LowerText);
  if StartPos <= 0 then
    Exit;

  Inc(StartPos, Length(AName) + 1);
  while (StartPos <= Length(AAnnotation)) and
    (AAnnotation[StartPos] in [' ', #9]) do
    Inc(StartPos);
  I := StartPos;
  while (I <= Length(AAnnotation)) and (AAnnotation[I] <> ';') do
    Inc(I);
  Result := Trim(Copy(AAnnotation, StartPos, I - StartPos));
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
    ExtractStrings([';'], [], PChar(AAnnotation), Items);
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

procedure ExtractMovesAndAnnotationsFromPdnText(const AText: string;
  AMoves, AAnnotations: TStrings);
var
  I: Integer;
  LBraceDepth: Integer;
  LComment: string;
  LInLineComment: Boolean;
  LLastMoveIndex: Integer;
  LParenDepth: Integer;
  LToken: string;

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
      Exit;
    if LooksLikePdnMove(LCleanToken) then
    begin
      AMoves.Add(NormalizeMoveNotation(LCleanToken));
      AAnnotations.Add('');
      LLastMoveIndex := AMoves.Count - 1;
    end;
  end;

  procedure ProcessComment;
  var
    LCommentText: string;
    LLowerComment: string;
  begin
    LCommentText := Trim(LComment);
    LComment := '';
    if (LLastMoveIndex < 0) or (LLastMoveIndex >= AAnnotations.Count) then
      Exit;
    LLowerComment := LowerCase(LCommentText);
    if (Pos('score=', LLowerComment) > 0) or
      (Pos('engine:', LLowerComment) > 0) or
      (Pos('engine=', LLowerComment) > 0) or
      (Pos('annotator:', LLowerComment) > 0) or
      (Pos('annotator=', LLowerComment) > 0) then
      AAnnotations[LLastMoveIndex] := LCommentText;
  end;
begin
  if AMoves <> nil then
    AMoves.Clear;
  if AAnnotations <> nil then
    AAnnotations.Clear;
  if (AMoves = nil) or (AAnnotations = nil) then
    Exit;

  LBraceDepth := 0;
  LComment := '';
  LInLineComment := False;
  LLastMoveIndex := -1;
  LParenDepth := 0;
  LToken := '';
  for I := 1 to Length(AText) do
  begin
    if LInLineComment then
    begin
      if AText[I] in [#10, #13] then
      begin
        LInLineComment := False;
        ProcessToken;
      end;
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
        begin
          ProcessToken;
          Inc(LBraceDepth);
          LComment := '';
        end;
      '(':
        begin
          ProcessToken;
          Inc(LParenDepth);
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
  end;
  ProcessToken;
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

  LSpace := Pos(' ', ALine);
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

  if SameText(LName, 'Event') then
    AGame.EventName := LValue
  else if SameText(LName, 'White') then
    AGame.WhiteName := LValue
  else if SameText(LName, 'Black') then
    AGame.BlackName := LValue
  else if SameText(LName, 'Result') then
    AGame.ResultText := NormalizePdnResult(LValue)
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
  LMoves: TStringList;
begin
  if ACurrent = nil then
    Exit;
  LAnnotations := TStringList.Create;
  LMoves := TStringList.Create;
  try
    ExtractMovesAndAnnotationsFromPdnText(AMoveLines.Text, LMoves, LAnnotations);
    ACurrent.MovesText := Trim(StringReplace(LMoves.Text, LineEnding, ' ',
      [rfReplaceAll]));
    ACurrent.MoveAnnotationsText := LAnnotations.Text;
    if Trim(ACurrent.StartingFEN) = '' then
      ACurrent.StartingFEN := DefaultPdnFen;
    if Trim(ACurrent.ResultText) = '' then
      ACurrent.ResultText := '*';
    if AGames <> nil then
    begin
      AGames.Add(ACurrent);
      ACurrent := nil;
    end;
    AMoveLines.Clear;
  finally
    LMoves.Free;
    LAnnotations.Free;
  end;
end;

procedure LoadPdnGamesFromFile(const AFileName: string; AGames: TList);
var
  Current: TPdnGame;
  I: Integer;
  Lines: TStringList;
  MoveLines: TStringList;
  S: string;
begin
  if AGames = nil then
    Exit;
  ClearGameList(AGames);
  Lines := TStringList.Create;
  MoveLines := TStringList.Create;
  Current := nil;
  try
    Lines.LoadFromFile(AFileName);
    for I := 0 to Lines.Count - 1 do
    begin
      S := TrimPdnLine(Lines[I]);
      if S = '' then
        Continue;
      if S[1] = '[' then
      begin
        if (Current <> nil) and (Trim(MoveLines.Text) <> '') then
          AddCurrentGame(Current, MoveLines, AGames);
        if Current = nil then
          Current := TPdnGame.Create;
        ParsePdnTag(S, Current);
      end
      else
      begin
        if Current = nil then
          Current := TPdnGame.Create;
        MoveLines.Add(S);
      end;
    end;
    AddCurrentGame(Current, MoveLines, AGames);
  finally
    Current.Free;
    MoveLines.Free;
    Lines.Free;
  end;
end;

procedure ReadPdnGamesFromFile(const AFileName: string;
  AOnGame: TPdnGameReadEvent);
var
  Buffer: array[0..65535] of Byte;
  BytesRead: Integer;
  Current: TPdnGame;
  I: Integer;
  Line: string;
  MoveLines: TStringList;
  Stop: Boolean;
  Stream: TFileStream;
  TotalBytes: Int64;

  procedure ProcessLine(const ALine: string);
  var
    S: string;
  begin
    S := TrimPdnLine(ALine);
    if S = '' then
      Exit;
    if S[1] = '[' then
    begin
      if (Current <> nil) and (Trim(MoveLines.Text) <> '') then
      begin
        AddCurrentGame(Current, MoveLines, nil);
        if Assigned(AOnGame) then
          AOnGame(Current, Stream.Position, TotalBytes, Stop)
        else
          Stop := True;
        Current.Free;
        Current := nil;
        if Stop then
          Exit;
      end;
      if Current = nil then
        Current := TPdnGame.Create;
      ParsePdnTag(S, Current);
    end
    else
    begin
      if Current = nil then
        Current := TPdnGame.Create;
      MoveLines.Add(S);
    end;
  end;

begin
  if not Assigned(AOnGame) then
    Exit;

  Current := nil;
  Line := '';
  Stop := False;
  MoveLines := TStringList.Create;
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyNone);
  try
    TotalBytes := Stream.Size;
    FillChar(Buffer, SizeOf(Buffer), 0);
    repeat
      BytesRead := Stream.Read(Buffer, SizeOf(Buffer));
      for I := 0 to BytesRead - 1 do
      begin
        if Buffer[I] = Ord(#10) then
        begin
          ProcessLine(Line);
          Line := '';
          if Stop then
            Break;
        end
        else if Buffer[I] <> Ord(#13) then
          Line += Chr(Buffer[I]);
      end;
    until (BytesRead = 0) or Stop;

    if (not Stop) and (Trim(Line) <> '') then
      ProcessLine(Line);
    if (not Stop) and (Current <> nil) then
    begin
      AddCurrentGame(Current, MoveLines, nil);
      AOnGame(Current, Stream.Position, TotalBytes, Stop);
      Current.Free;
      Current := nil;
    end;
  finally
    Current.Free;
    MoveLines.Free;
    Stream.Free;
  end;
end;

function FormatMovesForPdn(const AMovesText, AAnnotationsText, AResultText: string;
  const AStartingFEN: string): string;
var
  I: Integer;
  LAnnotations: TStringList;
  LMoves: TStringList;
  LMoveNumber: Integer;
  LOut: TStringList;
  LSide: TDraughtsSide;
  LText: string;
begin
  LMoves := TStringList.Create;
  LAnnotations := TStringList.Create;
  LOut := TStringList.Create;
  try
    ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)), LMoves);
    LAnnotations.Text := AAnnotationsText;
    LSide := dsWhite;
    if (Trim(AStartingFEN) <> '') and (UpCase(Trim(AStartingFEN)[1]) = 'B') then
      LSide := dsBlack;
    LText := '';
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
    LAnnotations.Free;
    LMoves.Free;
  end;
end;

procedure AppendPdnGameToFile(const AFileName: string; AGame: TPdnGame);
var
  Lines: TStringList;
begin
  if AGame = nil then
    Exit;
  Lines := TStringList.Create;
  try
    if FileExists(AFileName) then
      Lines.LoadFromFile(AFileName);
    if (Lines.Count > 0) and (Trim(Lines[Lines.Count - 1]) <> '') then
      Lines.Add('');
    Lines.Text := Lines.Text + PdnGameToText(AGame);
    Lines.SaveToFile(AFileName);
  finally
    Lines.Free;
  end;
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
    Lines.Add('[White "' + PdnQuote(AGame.WhiteName) + '"]');
    Lines.Add('[Black "' + PdnQuote(AGame.BlackName) + '"]');
    Lines.Add('[Result "' + PdnQuote(PdnExportResult(AGame.ResultText)) + '"]');
    if Trim(AGame.StartingFEN) <> DefaultPdnFen then
      Lines.Add('[SetUp "1"]');
    Lines.Add('[FEN "' + PdnQuote(AGame.StartingFEN) + '"]');
    Lines.Add('');
    Lines.Text := Lines.Text + FormatMovesForPdn(AGame.MovesText,
      AGame.MoveAnnotationsText, AGame.ResultText, AGame.StartingFEN);
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

end.
