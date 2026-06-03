unit Notation;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  DraughtsRules,
  HubProtocol;

function BoardToFen(const ABoard: TBoard; ASide: TSide): String;
procedure ParseFenToBoard(const AFen: String; out ABoard: TBoard;
  out ASide: TSide);
function FormatClockSeconds(ASeconds: Double): String;
function FormatClockAnnotationSeconds(ASeconds: Double): String;
function PdnEscape(const AText: String): String;
function ExtractPdnTagValue(const ALines: TStrings; const ATagName: String): String;
function StripPdnMoveText(const ALines: TStrings): String;
procedure ExtractPdnMoveTokens(const ALines: TStrings; out ATokens,
  AAnnotations: TTextArray);
function PdnTokenMoveText(const AToken: String): String;
function IsPdnResultToken(const AToken: String): Boolean;

implementation

uses
  Math,
  StrUtils,
  SysUtils;

function BoardToFen(const ABoard: TBoard; ASide: TSide): String;
var
  BlackText: String;
  Square: Integer;
  WhiteText: String;

  procedure AddPiece(var AText: String; ASquare: Integer; IsKing: Boolean);
  begin
    if AText <> '' then
      AText += ',';
    if IsKing then
      AText += 'K';
    AText += IntToStr(ASquare);
  end;

begin
  WhiteText := '';
  BlackText := '';

  for Square := Low(ABoard) to High(ABoard) do
    case ABoard[Square] of
      pcWhiteMan: AddPiece(WhiteText, Square, False);
      pcWhiteKing: AddPiece(WhiteText, Square, True);
      pcBlackMan: AddPiece(BlackText, Square, False);
      pcBlackKing: AddPiece(BlackText, Square, True);
    end;

  if ASide = sideWhite then
    Result := 'W'
  else
    Result := 'B';
  Result += ':W' + WhiteText + ':B' + BlackText;
end;

procedure ParseFenToBoard(const AFen: String; out ABoard: TBoard;
  out ASide: TSide);
var
  CurrentSide: Char;
  Fen: String;
  FirstPieceSection: Integer;
  I: Integer;
  IsKing: Boolean;
  J: Integer;
  P: Integer;
  ParsedBoard: TBoard;
  Piece: TPiece;
  PositionText: String;
  RangeEnd: Integer;
  RangeStart: Integer;
  Section: String;
  Sections: TStringArray;
  Square: Integer;
  Token: String;
  Tokens: TStringArray;
begin
  Fen := Trim(StringReplace(AFen, LineEnding, '', [rfReplaceAll]));
  if Fen = '' then
    raise Exception.Create('The selected FEN file is empty.');

  for Square := Low(ParsedBoard) to High(ParsedBoard) do
    ParsedBoard[Square] := pcNone;
  ASide := sideWhite;
  Sections := Fen.Split(':');
  FirstPieceSection := 0;

  if (Length(Sections) > 0) and (Length(Trim(Sections[0])) = 1) and
    (UpCase(Trim(Sections[0])[1]) in ['W', 'B']) then
  begin
    if UpCase(Trim(Sections[0])[1]) = 'W' then
      ASide := sideWhite
    else
      ASide := sideBlack;
    FirstPieceSection := 1;
  end;

  for I := FirstPieceSection to High(Sections) do
  begin
    Section := Trim(Sections[I]);
    if Section = '' then
      Continue;

    CurrentSide := UpCase(Section[1]);
    if not (CurrentSide in ['W', 'B']) then
      Continue;

    Delete(Section, 1, 1);
    Section := StringReplace(Section, ';', ',', [rfReplaceAll]);
    Tokens := Section.Split(',');

    for J := 0 to High(Tokens) do
    begin
      Token := Trim(Tokens[J]);
      if Token = '' then
        Continue;

      IsKing := UpCase(Token[1]) = 'K';
      if IsKing then
        Delete(Token, 1, 1);

      PositionText := Token;
      if Pos('-', PositionText) > 0 then
      begin
        RangeStart := StrToIntDef(Copy(PositionText, 1,
          Pos('-', PositionText) - 1), 0);
        RangeEnd := StrToIntDef(Copy(PositionText,
          Pos('-', PositionText) + 1, MaxInt), 0);
      end
      else
      begin
        RangeStart := StrToIntDef(PositionText, 0);
        RangeEnd := RangeStart;
      end;

      if (RangeStart < 1) or (RangeEnd > 50) or
        (RangeEnd < RangeStart) then
        raise Exception.CreateFmt('Invalid FEN position: %s', [Token]);

      for P := RangeStart to RangeEnd do
      begin
        if CurrentSide = 'W' then
          if IsKing then
            Piece := pcWhiteKing
          else
            Piece := pcWhiteMan
        else if IsKing then
          Piece := pcBlackKing
        else
          Piece := pcBlackMan;

        ParsedBoard[P] := Piece;
      end;
    end;
  end;

  ABoard := ParsedBoard;
end;

function FormatClockSeconds(ASeconds: Double): String;
var
  WholeSeconds: Integer;
begin
  WholeSeconds := Ceil(Max(0, ASeconds));
  Result := Format('%2.2d:%2.2d', [WholeSeconds div 60, WholeSeconds mod 60]);
end;

function FormatClockAnnotationSeconds(ASeconds: Double): String;
var
  WholeSeconds: Integer;
begin
  WholeSeconds := Ceil(Max(0, ASeconds));
  Result := Format('%2.2d:%2.2d:%2.2d',
    [WholeSeconds div 3600, (WholeSeconds div 60) mod 60, WholeSeconds mod 60]);
end;

function PdnEscape(const AText: String): String;
begin
  Result := StringReplace(AText, '\', '\\', [rfReplaceAll]);
  Result := StringReplace(Result, '"', '\"', [rfReplaceAll]);
end;

function ExtractPdnTagValue(const ALines: TStrings; const ATagName: String): String;
var
  I: Integer;
  Line: String;
  Prefix: String;
begin
  Result := '';
  Prefix := '[' + ATagName + ' "';
  for I := 0 to ALines.Count - 1 do
  begin
    Line := Trim(ALines[I]);
    if StartsText(Prefix, Line) then
    begin
      Result := Copy(Line, Length(Prefix) + 1, MaxInt);
      if EndsText('"]', Result) then
        SetLength(Result, Length(Result) - 2);
      Result := StringReplace(Result, '\"', '"', [rfReplaceAll]);
      Result := StringReplace(Result, '\\', '\', [rfReplaceAll]);
      Exit;
    end;
  end;
end;

function StripPdnMoveText(const ALines: TStrings): String;
var
  Ch: Char;
  I: Integer;
  InComment: Boolean;
  InVariation: Integer;
  J: Integer;
  Line: String;
begin
  Result := '';
  InComment := False;
  InVariation := 0;

  for I := 0 to ALines.Count - 1 do
  begin
    Line := Trim(ALines[I]);
    if (Line = '') or StartsText('[', Line) then
      Continue;

    for J := 1 to Length(Line) do
    begin
      Ch := Line[J];
      if InComment then
      begin
        if Ch = '}' then
          InComment := False;
        Continue;
      end;
      if InVariation > 0 then
      begin
        if Ch = '(' then
          Inc(InVariation)
        else if Ch = ')' then
          Dec(InVariation);
        Continue;
      end;

      case Ch of
        '{': InComment := True;
        '(': InVariation := 1;
        ';': Break;
      else
        Result += Ch;
      end;
    end;
    Result += ' ';
  end;
end;

procedure ExtractPdnMoveTokens(const ALines: TStrings; out ATokens,
  AAnnotations: TTextArray);
var
  Ch: Char;
  Comment: String;
  I: Integer;
  InComment: Boolean;
  InVariation: Integer;
  J: Integer;
  LastTokenIndex: Integer;
  Line: String;
  Token: String;

  procedure AppendToken;
  begin
    Token := Trim(Token);
    if Token = '' then
      Exit;
    SetLength(ATokens, Length(ATokens) + 1);
    SetLength(AAnnotations, Length(ATokens));
    ATokens[High(ATokens)] := Token;
    AAnnotations[High(AAnnotations)] := '';
    LastTokenIndex := High(ATokens);
    Token := '';
  end;

  procedure AppendComment;
  begin
    Comment := Trim(Comment);
    if (Comment = '') or (LastTokenIndex < 0) then
      Exit;
    if AAnnotations[LastTokenIndex] <> '' then
      AAnnotations[LastTokenIndex] += ' ';
    AAnnotations[LastTokenIndex] += Comment;
    Comment := '';
  end;

begin
  SetLength(ATokens, 0);
  SetLength(AAnnotations, 0);
  InComment := False;
  InVariation := 0;
  LastTokenIndex := -1;
  Token := '';
  Comment := '';

  for I := 0 to ALines.Count - 1 do
  begin
    Line := Trim(ALines[I]);
    if (Line = '') or StartsText('[', Line) then
      Continue;

    for J := 1 to Length(Line) do
    begin
      Ch := Line[J];
      if InComment then
      begin
        if Ch = '}' then
        begin
          InComment := False;
          AppendComment;
        end
        else
          Comment += Ch;
        Continue;
      end;
      if InVariation > 0 then
      begin
        if Ch = '(' then
          Inc(InVariation)
        else if Ch = ')' then
          Dec(InVariation);
        Continue;
      end;

      case Ch of
        '{':
        begin
          AppendToken;
          InComment := True;
          Comment := '';
        end;
        '(':
        begin
          AppendToken;
          InVariation := 1;
        end;
        ';':
        begin
          AppendToken;
          Break;
        end;
        ' ', #9, #10, #13:
          AppendToken;
      else
        Token += Ch;
      end;
    end;
    AppendToken;
  end;
end;

function PdnTokenMoveText(const AToken: String): String;
var
  DotPos: Integer;
  I: Integer;
begin
  Result := Trim(AToken);
  while (Result <> '') and (Result[1] in ['!', '?']) do
    Delete(Result, 1, 1);
  while (Result <> '') and (Result[Length(Result)] in ['!', '?', ',', ';']) do
    SetLength(Result, Length(Result) - 1);

  DotPos := 0;
  for I := Length(Result) downto 1 do
    if Result[I] = '.' then
    begin
      DotPos := I;
      Break;
    end;
  if DotPos > 0 then
    Delete(Result, 1, DotPos);
end;

function IsPdnResultToken(const AToken: String): Boolean;
begin
  Result := (AToken = '2-0') or (AToken = '1-1') or (AToken = '0-2') or
    (AToken = '*') or (AToken = '1-0') or (AToken = '0-1') or
    (AToken = '1/2-1/2');
end;

end.
