unit uManualDocument;

{$mode objfpc}{$H+}

{ The manual as a readable, styled text for the manual window.

  Load parses the Markdown subset used by MANUAL.md: headings, paragraphs,
  bullet and numbered lists (nested by indentation), pipe tables, fenced code
  blocks, and inline **strong**, `code` and [links](target). Render lays it
  out for a monospace view of a given width: paragraphs and list items are
  wrapped with hanging indents, tables get aligned columns (the last column
  wraps), and Markdown markers are removed. The result is plain text with a
  style per byte, a line index and the list of headings for the contents.

  No LCL: the view (uManualForm) and the tests use the same rendering. }

interface

uses
  Classes, SysUtils;

type
  TManualStyle = (msText, msTitle, msHeading, msSubheading, msStrong, msCode,
    msCodeBlock, msTableHeader, msMuted);
  TManualStyles = array of TManualStyle;

  TManualHeading = record
    Level: Integer;  // 1 = title, 2 = section, 3 and more = subsection
    Title: string;   // without Markdown markers
    Line: Integer;   // zero-based line of the rendered text
  end;
  TManualHeadings = array of TManualHeading;

  TManualBlockKind = (mbHeading, mbParagraph, mbListItem, mbTable, mbCode);

  TManualTableRow = array of string;

  TManualBlock = record
    Kind: TManualBlockKind;
    Level: Integer;      // heading level, or list nesting (0 = top level)
    Marker: string;      // list marker as written ('-', '*', '1.')
    Text: string;        // inline Markdown of a heading, paragraph or list item
    Rows: array of TManualTableRow; // table cells; row 0 is the header
    CodeLines: array of string;
  end;

  TManualStyledLine = record
    Text: string;
    Styles: TManualStyles; // one per byte of Text
    // One per byte of Text: the byte's position in the logical (unwrapped)
    // text of the manual, or -1 for layout (indents, bullets, table padding
    // and rules). Search runs on the logical text (review U11).
    Sources: array of Integer;
  end;
  TManualStyledLines = array of TManualStyledLine;

  // A search hit in the rendered text: zero-based byte offset and byte count.
  TManualMatch = record
    Start, Count: Integer;
  end;
  TManualMatches = array of TManualMatch;

  TManualDocument = class
  private
    FBlocks: array of TManualBlock;
    FLines: TManualStyledLines;
    FText: string;
    FStyles: TManualStyles;
    FLineStarts: array of Integer;
    FHeadings: TManualHeadings;
    FWidth: Integer;
    FSources: array of Integer;      // per byte of FText, see TManualStyledLine
    FNextSource: Integer;
    function NewSegment(ALength: Integer): Integer;
    procedure AddBlock(const ABlock: TManualBlock);
    procedure AddLine(const ALine: TManualStyledLine);
    procedure AddBlank;
    procedure RenderHeading(const ABlock: TManualBlock);
    procedure RenderWrapped(const AText: string; ABase: TManualStyle;
      const AFirstPrefix, ARestPrefix: string; APrefixStyle: TManualStyle);
    procedure RenderTable(const ABlock: TManualBlock);
    procedure RenderCode(const ABlock: TManualBlock);
    procedure BuildText;
  public
    procedure Load(const AMarkdown: string);
    // Lays the manual out for AWidth characters per line (at least 30).
    procedure Render(AWidth: Integer);
    function LineCount: Integer;
    // Byte offset of the first character of ALine (zero-based).
    function LineStart(ALine: Integer): Integer;
    // Zero-based line containing byte offset AOffset.
    function LineOfOffset(AOffset: Integer): Integer;
    function StyleAt(AOffset: Integer): TManualStyle;
    // FindManualMatches on the logical text: words split by wrapping and table
    // cells wrapped over several lines are found whole, while real spaces
    // between words still separate them. Each match is the smallest rendered
    // range that contains all its bytes; across table cells it can include
    // other text of the row.
    function FindMatches(const AQuery: string): TManualMatches;
    property Text: string read FText;
    property Headings: TManualHeadings read FHeadings;
    property Width: Integer read FWidth;
  end;

// Removes the inline markers; AStyles receives one style per byte of the result.
procedure ParseManualInline(const ARaw: string; ABase: TManualStyle;
  out APlain: string; out AStyles: TManualStyles);
// Number of characters (UTF-8 code points) in AText.
function ManualCharCount(const AText: string): Integer;
// Greedy word wrap of a styled text into lines of at most AWidth characters.
// Words longer than AWidth are split. Sources are ASourceBase + the byte's
// zero-based offset in APlain.
function WrapManualText(const APlain: string; const AStyles: TManualStyles;
  AWidth: Integer; ASourceBase: Integer = 0): TManualStyledLines;
// Case-insensitive (ASCII letters) search in rendered text. Any run of spaces
// and line breaks matches any run in the query, so a phrase is found where
// the layout wrapped it. Matches do not overlap.
function FindManualMatches(const AText, AQuery: string): TManualMatches;

implementation

uses
  StrUtils;

const
  MinRenderWidth = 30;
  MinTableColumn = 10;
  TableIndent = '  ';
  TableSeparator = ' │ ';

function ManualCharCount(const AText: string): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 1 to Length(AText) do
    if (Byte(AText[I]) and $C0) <> $80 then
      Inc(Result);
end;

function CharByteLength(const AText: string; AIndex: Integer): Integer;
var
  B: Byte;
begin
  B := Byte(AText[AIndex]);
  if B < $C0 then
    Result := 1
  else if B < $E0 then
    Result := 2
  else if B < $F0 then
    Result := 3
  else
    Result := 4;
  if AIndex + Result - 1 > Length(AText) then
    Result := Length(AText) - AIndex + 1;
end;

function StyledLine(const AText: string; AStyle: TManualStyle): TManualStyledLine;
var
  I: Integer;
begin
  Result.Text := AText;
  SetLength(Result.Styles, Length(AText));
  SetLength(Result.Sources, Length(AText));
  for I := 0 to High(Result.Styles) do
  begin
    Result.Styles[I] := AStyle;
    Result.Sources[I] := -1;
  end;
end;

// AText as logical content starting at source ASource.
function SourcedLine(const AText: string; AStyle: TManualStyle;
  ASource: Integer): TManualStyledLine;
var
  I: Integer;
begin
  Result := StyledLine(AText, AStyle);
  for I := 0 to High(Result.Sources) do
    Result.Sources[I] := ASource + I;
end;

procedure AppendStyled(var ALine: TManualStyledLine; const AText: string;
  AStyle: TManualStyle);
var
  I, LStart: Integer;
begin
  LStart := Length(ALine.Text);
  ALine.Text := ALine.Text + AText;
  SetLength(ALine.Styles, Length(ALine.Text));
  SetLength(ALine.Sources, Length(ALine.Text));
  for I := LStart to High(ALine.Styles) do
  begin
    ALine.Styles[I] := AStyle;
    ALine.Sources[I] := -1;
  end;
end;

procedure AppendLine(var ALine: TManualStyledLine; const AOther: TManualStyledLine);
var
  I, LStart: Integer;
begin
  LStart := Length(ALine.Text);
  ALine.Text := ALine.Text + AOther.Text;
  SetLength(ALine.Styles, Length(ALine.Text));
  SetLength(ALine.Sources, Length(ALine.Text));
  for I := 0 to High(AOther.Styles) do
  begin
    ALine.Styles[LStart + I] := AOther.Styles[I];
    if I <= High(AOther.Sources) then
      ALine.Sources[LStart + I] := AOther.Sources[I]
    else
      ALine.Sources[LStart + I] := -1;
  end;
end;

function RepeatText(const AText: string; ACount: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ACount do
    Result := Result + AText;
end;

procedure ParseManualInline(const ARaw: string; ABase: TManualStyle;
  out APlain: string; out AStyles: TManualStyles);
var
  I, J, K: Integer;
  LInner: string;
  LInnerStyles: TManualStyles;
  LStrong: TManualStyle;

  procedure Emit(const AText: string; AStyle: TManualStyle);
  var
    N, P: Integer;
  begin
    N := Length(APlain);
    APlain := APlain + AText;
    SetLength(AStyles, Length(APlain));
    for P := N to High(AStyles) do
      AStyles[P] := AStyle;
  end;

  procedure EmitStyled(const AText: string; const AStyles2: TManualStyles);
  var
    N, P: Integer;
  begin
    N := Length(APlain);
    APlain := APlain + AText;
    SetLength(AStyles, Length(APlain));
    for P := 0 to High(AStyles2) do
      AStyles[N + P] := AStyles2[P];
  end;

begin
  APlain := '';
  AStyles := nil;
  if ABase in [msTitle, msHeading, msSubheading, msTableHeader] then
    LStrong := ABase
  else
    LStrong := msStrong;
  I := 1;
  while I <= Length(ARaw) do
  begin
    if ARaw[I] = '`' then
    begin
      J := Pos('`', Copy(ARaw, I + 1, MaxInt));
      if J > 0 then
      begin
        Emit(Copy(ARaw, I + 1, J - 1), msCode);
        Inc(I, J + 1);
        Continue;
      end;
    end
    else if (ARaw[I] = '*') and (I < Length(ARaw)) and (ARaw[I + 1] = '*') then
    begin
      J := Pos('**', Copy(ARaw, I + 2, MaxInt));
      if J > 0 then
      begin
        ParseManualInline(Copy(ARaw, I + 2, J - 1), LStrong, LInner, LInnerStyles);
        EmitStyled(LInner, LInnerStyles);
        Inc(I, J + 3);
        Continue;
      end;
    end
    else if ARaw[I] = '[' then
    begin
      J := Pos('](', Copy(ARaw, I + 1, MaxInt));
      if J > 0 then
      begin
        K := Pos(')', Copy(ARaw, I + J + 2, MaxInt));
        if K > 0 then
        begin
          ParseManualInline(Copy(ARaw, I + 1, J - 1), ABase, LInner, LInnerStyles);
          EmitStyled(LInner, LInnerStyles);
          I := I + J + 2 + K;
          Continue;
        end;
      end;
    end;
    Emit(ARaw[I], ABase);
    Inc(I);
  end;
end;

function WrapManualText(const APlain: string; const AStyles: TManualStyles;
  AWidth: Integer; ASourceBase: Integer): TManualStyledLines;
var
  I, LWordStart, LWordEnd, LLineChars, LWordChars, LCharBytes: Integer;
  LCurrent: TManualStyledLine;
  LHasWords: Boolean;

  procedure Flush;
  begin
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LCurrent;
    LCurrent.Text := '';
    LCurrent.Styles := nil;
    LCurrent.Sources := nil;
    LLineChars := 0;
    LHasWords := False;
  end;

  procedure AddBytes(AFrom, ACount: Integer);
  var
    P, N: Integer;
  begin
    N := Length(LCurrent.Text);
    LCurrent.Text := LCurrent.Text + Copy(APlain, AFrom, ACount);
    SetLength(LCurrent.Styles, Length(LCurrent.Text));
    SetLength(LCurrent.Sources, Length(LCurrent.Text));
    for P := 0 to ACount - 1 do
    begin
      LCurrent.Styles[N + P] := AStyles[AFrom - 1 + P];
      LCurrent.Sources[N + P] := ASourceBase + AFrom - 1 + P;
    end;
  end;

begin
  Result := nil;
  if AWidth < 1 then
    AWidth := 1;
  LCurrent.Text := '';
  LCurrent.Styles := nil;
  LCurrent.Sources := nil;
  LLineChars := 0;
  LHasWords := False;
  I := 1;
  while I <= Length(APlain) do
  begin
    // Skip the spaces between words; the separator is re-added when joining.
    while (I <= Length(APlain)) and (APlain[I] = ' ') do
      Inc(I);
    if I > Length(APlain) then
      Break;
    LWordStart := I;
    while (I <= Length(APlain)) and (APlain[I] <> ' ') do
      Inc(I);
    LWordEnd := I - 1;
    LWordChars := ManualCharCount(Copy(APlain, LWordStart, LWordEnd - LWordStart + 1));
    if LHasWords and (LLineChars + 1 + LWordChars > AWidth) then
      Flush;
    if LHasWords then
    begin
      // Keep the style of the space in the source (a space inside a code span
      // keeps the code style).
      AddBytes(LWordStart - 1, 1);
      Inc(LLineChars);
    end;
    // A word longer than the line is split at character boundaries.
    while LWordStart <= LWordEnd do
    begin
      if LLineChars >= AWidth then
        Flush;
      LCharBytes := CharByteLength(APlain, LWordStart);
      AddBytes(LWordStart, LCharBytes);
      Inc(LWordStart, LCharBytes);
      Inc(LLineChars);
      LHasWords := True;
    end;
  end;
  if LHasWords or (Length(Result) = 0) then
    Flush;
end;

type
  TManualOffsets = array of Integer;

// The search of FindManualMatches on AText, whose byte I (one-based) lies at
// rendered offset AOffsets[I - 1].
function FindMappedMatches(const AText: string; const AOffsets: TManualOffsets;
  const AQuery: string): TManualMatches;
var
  LText, LQuery: string;
  LMap: array of Integer; // rendered offset of each byte of LText
  I, P, N, LFirst, LLast: Integer;
  LSpace: Boolean;
begin
  Result := nil;
  // Collapse whitespace in the query.
  LQuery := '';
  LSpace := False;
  for I := 1 to Length(AQuery) do
    if AQuery[I] in [' ', #9, #10, #13] then
      LSpace := LQuery <> ''
    else
    begin
      if LSpace then
        LQuery := LQuery + ' ';
      LSpace := False;
      LQuery := LQuery + LowerCase(AQuery[I]);
    end;
  if LQuery = '' then
    Exit;
  // Collapse whitespace in the text, remembering where each byte came from.
  SetLength(LText, Length(AText));
  SetLength(LMap, Length(AText));
  N := 0;
  LSpace := False;
  for I := 1 to Length(AText) do
    if AText[I] in [' ', #9, #10, #13] then
    begin
      if not LSpace then
      begin
        Inc(N);
        LText[N] := ' ';
        LMap[N - 1] := AOffsets[I - 1];
        LSpace := True;
      end;
    end
    else
    begin
      Inc(N);
      LText[N] := LowerCase(AText[I]);
      LMap[N - 1] := AOffsets[I - 1];
      LSpace := False;
    end;
  SetLength(LText, N);
  P := Pos(LQuery, LText);
  while P > 0 do
  begin
    // The range encloses every byte of the match. In a table the logical order
    // is not the screen order (a left cell can continue below the start of its
    // right neighbour), so the first and last bytes are not the ends of the
    // range (review U12). The range may include other text of the row.
    LFirst := LMap[P - 1];
    LLast := LMap[P - 1];
    for I := P to P + Length(LQuery) - 2 do
    begin
      if LMap[I] < LFirst then
        LFirst := LMap[I];
      if LMap[I] > LLast then
        LLast := LMap[I];
    end;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)].Start := LFirst;
    Result[High(Result)].Count := LLast + 1 - LFirst;
    P := PosEx(LQuery, LText, P + Length(LQuery));
  end;
end;

function FindManualMatches(const AText, AQuery: string): TManualMatches;
var
  LOffsets: TManualOffsets;
  I: Integer;
begin
  SetLength(LOffsets, Length(AText));
  for I := 0 to High(LOffsets) do
    LOffsets[I] := I;
  Result := FindMappedMatches(AText, LOffsets, AQuery);
end;

{ Parsing }

function IsFence(const ALine: string): Boolean;
begin
  Result := Copy(TrimLeft(ALine), 1, 3) = '```';
end;

function IsHeading(const ALine: string; out ALevel: Integer; out AText: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  ALevel := 0;
  AText := '';
  I := 1;
  while (I <= Length(ALine)) and (ALine[I] = '#') do
    Inc(I);
  ALevel := I - 1;
  if (ALevel < 1) or (ALevel > 6) or (I > Length(ALine)) or (ALine[I] <> ' ') then
    Exit;
  AText := Trim(Copy(ALine, I + 1, MaxInt));
  while (AText <> '') and (AText[Length(AText)] = '#') do
    Delete(AText, Length(AText), 1);
  AText := Trim(AText);
  Result := True;
end;

function IsTableLine(const ALine: string): Boolean;
begin
  Result := Copy(TrimLeft(ALine), 1, 1) = '|';
end;

function IsListItem(const ALine: string; out AIndent: Integer; out AMarker,
  AText: string): Boolean;
var
  I, J: Integer;
begin
  Result := False;
  AIndent := 0;
  AMarker := '';
  AText := '';
  I := 1;
  while (I <= Length(ALine)) and (ALine[I] = ' ') do
    Inc(I);
  AIndent := I - 1;
  if I > Length(ALine) then
    Exit;
  if (ALine[I] in ['-', '*']) and (I < Length(ALine)) and (ALine[I + 1] = ' ') then
  begin
    AMarker := ALine[I];
    AText := Trim(Copy(ALine, I + 2, MaxInt));
    Exit(True);
  end;
  J := I;
  while (J <= Length(ALine)) and (ALine[J] in ['0'..'9']) do
    Inc(J);
  if (J > I) and (J < Length(ALine)) and (ALine[J] = '.') and (ALine[J + 1] = ' ') then
  begin
    AMarker := Copy(ALine, I, J - I + 1);
    AText := Trim(Copy(ALine, J + 2, MaxInt));
    Result := True;
  end;
end;

function IsSeparatorRow(const ARow: TManualTableRow): Boolean;
var
  I, J: Integer;
  LCell: string;
begin
  Result := Length(ARow) > 0;
  for I := 0 to High(ARow) do
  begin
    LCell := Trim(ARow[I]);
    if LCell = '' then
      Exit(False);
    for J := 1 to Length(LCell) do
      if not (LCell[J] in ['-', ':']) then
        Exit(False);
  end;
end;

function SplitTableRow(const ALine: string): TManualTableRow;
var
  LText: string;
  P: Integer;
begin
  Result := nil;
  LText := Trim(ALine);
  if (LText <> '') and (LText[1] = '|') then
    Delete(LText, 1, 1);
  if (LText <> '') and (LText[Length(LText)] = '|') then
    Delete(LText, Length(LText), 1);
  repeat
    P := Pos('|', LText);
    SetLength(Result, Length(Result) + 1);
    if P = 0 then
      Result[High(Result)] := Trim(LText)
    else
    begin
      Result[High(Result)] := Trim(Copy(LText, 1, P - 1));
      Delete(LText, 1, P);
    end;
  until P = 0;
end;

procedure TManualDocument.AddBlock(const ABlock: TManualBlock);
begin
  SetLength(FBlocks, Length(FBlocks) + 1);
  FBlocks[High(FBlocks)] := ABlock;
end;

procedure TManualDocument.Load(const AMarkdown: string);
var
  LSource: TStringList;
  I, LLevel, LIndent, LDummyIndent: Integer;
  LLine, LText, LMarker, LDummyMarker, LDummyText: string;
  LBlock: TManualBlock;
  LRow: TManualTableRow;

  function StartsBlock(const ALine: string): Boolean;
  var
    L: Integer;
    T: string;
  begin
    Result := (Trim(ALine) = '') or IsFence(ALine) or IsHeading(ALine, L, T) or
      IsTableLine(ALine) or IsListItem(ALine, LDummyIndent, LDummyMarker, LDummyText);
  end;

begin
  FBlocks := nil;
  LSource := TStringList.Create;
  try
    LSource.Text := StringReplace(AMarkdown, #13, '', [rfReplaceAll]);
    I := 0;
    while I < LSource.Count do
    begin
      LLine := LSource[I];
      LBlock := Default(TManualBlock);
      if Trim(LLine) = '' then
      begin
        Inc(I);
        Continue;
      end;
      if IsFence(LLine) then
      begin
        LBlock.Kind := mbCode;
        Inc(I);
        while (I < LSource.Count) and not IsFence(LSource[I]) do
        begin
          SetLength(LBlock.CodeLines, Length(LBlock.CodeLines) + 1);
          LBlock.CodeLines[High(LBlock.CodeLines)] := LSource[I];
          Inc(I);
        end;
        Inc(I); // closing fence
        AddBlock(LBlock);
        Continue;
      end;
      if IsHeading(LLine, LLevel, LText) then
      begin
        LBlock.Kind := mbHeading;
        LBlock.Level := LLevel;
        LBlock.Text := LText;
        AddBlock(LBlock);
        Inc(I);
        Continue;
      end;
      if IsTableLine(LLine) then
      begin
        LBlock.Kind := mbTable;
        while (I < LSource.Count) and IsTableLine(LSource[I]) do
        begin
          LRow := SplitTableRow(LSource[I]);
          if not IsSeparatorRow(LRow) then
          begin
            SetLength(LBlock.Rows, Length(LBlock.Rows) + 1);
            LBlock.Rows[High(LBlock.Rows)] := LRow;
          end;
          Inc(I);
        end;
        AddBlock(LBlock);
        Continue;
      end;
      if IsListItem(LLine, LIndent, LMarker, LText) then
      begin
        LBlock.Kind := mbListItem;
        LBlock.Level := LIndent div 2;
        LBlock.Marker := LMarker;
        Inc(I);
        // Continuation lines (indented or lazy) belong to the item.
        while (I < LSource.Count) and not StartsBlock(LSource[I]) do
        begin
          LText := LText + ' ' + Trim(LSource[I]);
          Inc(I);
        end;
        LBlock.Text := LText;
        AddBlock(LBlock);
        Continue;
      end;
      LBlock.Kind := mbParagraph;
      LText := Trim(LLine);
      Inc(I);
      while (I < LSource.Count) and not StartsBlock(LSource[I]) do
      begin
        LText := LText + ' ' + Trim(LSource[I]);
        Inc(I);
      end;
      LBlock.Text := LText;
      AddBlock(LBlock);
    end;
  finally
    LSource.Free;
  end;
  FWidth := 0;
end;

{ Rendering }

function TManualDocument.NewSegment(ALength: Integer): Integer;
begin
  // A gap of two keeps segments apart in the logical text (FindMatches puts a
  // space there).
  Result := FNextSource;
  Inc(FNextSource, ALength + 2);
end;

procedure TManualDocument.AddLine(const ALine: TManualStyledLine);
begin
  SetLength(FLines, Length(FLines) + 1);
  FLines[High(FLines)] := ALine;
end;

procedure TManualDocument.AddBlank;
begin
  if (Length(FLines) > 0) and (FLines[High(FLines)].Text <> '') then
    AddLine(StyledLine('', msText));
end;

procedure TManualDocument.RenderWrapped(const AText: string; ABase: TManualStyle;
  const AFirstPrefix, ARestPrefix: string; APrefixStyle: TManualStyle);
var
  LPlain: string;
  LStyles: TManualStyles;
  LWrapped: TManualStyledLines;
  LLine: TManualStyledLine;
  I: Integer;
begin
  ParseManualInline(AText, ABase, LPlain, LStyles);
  LWrapped := WrapManualText(LPlain, LStyles,
    FWidth - ManualCharCount(ARestPrefix), NewSegment(Length(LPlain)));
  for I := 0 to High(LWrapped) do
  begin
    if I = 0 then
      LLine := StyledLine(AFirstPrefix, APrefixStyle)
    else
      LLine := StyledLine(ARestPrefix, msText);
    AppendLine(LLine, LWrapped[I]);
    AddLine(LLine);
  end;
end;

procedure TManualDocument.RenderHeading(const ABlock: TManualBlock);
var
  LStyle: TManualStyle;
  LPlain, LRule: string;
  LStyles: TManualStyles;
  LChars: Integer;
begin
  case ABlock.Level of
    1: LStyle := msTitle;
    2: LStyle := msHeading;
  else
    LStyle := msSubheading;
  end;
  ParseManualInline(ABlock.Text, LStyle, LPlain, LStyles);
  AddBlank;
  SetLength(FHeadings, Length(FHeadings) + 1);
  FHeadings[High(FHeadings)].Level := ABlock.Level;
  FHeadings[High(FHeadings)].Title := LPlain;
  FHeadings[High(FHeadings)].Line := Length(FLines);
  RenderWrapped(ABlock.Text, LStyle, '', '', msText);
  if ABlock.Level <= 2 then
  begin
    LChars := ManualCharCount(LPlain);
    if LChars > FWidth then
      LChars := FWidth;
    if ABlock.Level = 1 then
      LRule := RepeatText('═', LChars)
    else
      LRule := RepeatText('─', LChars);
    AddLine(StyledLine(LRule, msMuted));
  end;
  AddBlank;
end;

procedure TManualDocument.RenderTable(const ABlock: TManualBlock);
type
  TCellLines = array of TManualStyledLines;
var
  LColumns, LRowIndex, LCol, I, LFixed, LLast, LHeight, LTotal, LWidest: Integer;
  LWidths: array of Integer;
  LCells: array of TCellLines;
  LPlain: string;
  LStyles: TManualStyles;
  LStyle: TManualStyle;
  LLine: TManualStyledLine;
  LText: string;
begin
  LColumns := 0;
  for LRowIndex := 0 to High(ABlock.Rows) do
    if Length(ABlock.Rows[LRowIndex]) > LColumns then
      LColumns := Length(ABlock.Rows[LRowIndex]);
  if LColumns = 0 then
    Exit;
  SetLength(LWidths, LColumns);
  for LCol := 0 to LColumns - 1 do
    LWidths[LCol] := 1;
  // Natural widths from the unwrapped cells.
  for LRowIndex := 0 to High(ABlock.Rows) do
    for LCol := 0 to High(ABlock.Rows[LRowIndex]) do
    begin
      ParseManualInline(ABlock.Rows[LRowIndex][LCol], msText, LPlain, LStyles);
      if ManualCharCount(LPlain) > LWidths[LCol] then
        LWidths[LCol] := ManualCharCount(LPlain);
    end;
  // Too wide: narrow the widest column one character at a time (cells then
  // wrap within their column), down to MinTableColumn characters.
  LLast := LColumns - 1;
  LFixed := Length(TableIndent) + (LColumns - 1) * ManualCharCount(TableSeparator);
  repeat
    LTotal := LFixed;
    LWidest := 0;
    for LCol := 0 to LLast do
    begin
      Inc(LTotal, LWidths[LCol]);
      if LWidths[LCol] > LWidths[LWidest] then
        LWidest := LCol;
    end;
    if (LTotal <= FWidth) or (LWidths[LWidest] <= MinTableColumn) then
      Break;
    Dec(LWidths[LWidest]);
  until False;
  SetLength(LCells, Length(ABlock.Rows));
  for LRowIndex := 0 to High(ABlock.Rows) do
  begin
    SetLength(LCells[LRowIndex], LColumns);
    if LRowIndex = 0 then
      LStyle := msTableHeader
    else
      LStyle := msText;
    for LCol := 0 to LColumns - 1 do
    begin
      if LCol <= High(ABlock.Rows[LRowIndex]) then
        LText := ABlock.Rows[LRowIndex][LCol]
      else
        LText := '';
      ParseManualInline(LText, LStyle, LPlain, LStyles);
      LCells[LRowIndex][LCol] := WrapManualText(LPlain, LStyles, LWidths[LCol],
        NewSegment(Length(LPlain)));
    end;
  end;
  for LRowIndex := 0 to High(ABlock.Rows) do
  begin
    LHeight := 1;
    for LCol := 0 to LColumns - 1 do
      if Length(LCells[LRowIndex][LCol]) > LHeight then
        LHeight := Length(LCells[LRowIndex][LCol]);
    for I := 0 to LHeight - 1 do
    begin
      LLine := StyledLine(TableIndent, msText);
      for LCol := 0 to LColumns - 1 do
      begin
        if LCol > 0 then
          AppendStyled(LLine, TableSeparator, msMuted);
        if I <= High(LCells[LRowIndex][LCol]) then
        begin
          AppendLine(LLine, LCells[LRowIndex][LCol][I]);
          if LCol < LLast then
            AppendStyled(LLine, StringOfChar(' ', LWidths[LCol] -
              ManualCharCount(LCells[LRowIndex][LCol][I].Text)), msText);
        end
        else if LCol < LLast then
          AppendStyled(LLine, StringOfChar(' ', LWidths[LCol]), msText);
      end;
      LLine.Text := TrimRight(LLine.Text);
      SetLength(LLine.Styles, Length(LLine.Text));
      SetLength(LLine.Sources, Length(LLine.Text));
      AddLine(LLine);
    end;
    if LRowIndex = 0 then
    begin
      LLine := StyledLine(TableIndent, msText);
      for LCol := 0 to LColumns - 1 do
      begin
        if LCol > 0 then
          AppendStyled(LLine, '─┼─', msMuted);
        AppendStyled(LLine, RepeatText('─', LWidths[LCol]), msMuted);
      end;
      AddLine(LLine);
    end;
  end;
end;

procedure TManualDocument.RenderCode(const ABlock: TManualBlock);
var
  I: Integer;
  LLine: TManualStyledLine;
begin
  for I := 0 to High(ABlock.CodeLines) do
  begin
    LLine := StyledLine('    ', msText);
    AppendLine(LLine, SourcedLine(ABlock.CodeLines[I], msCodeBlock,
      NewSegment(Length(ABlock.CodeLines[I]))));
    AddLine(LLine);
  end;
end;

procedure TManualDocument.BuildText;
var
  I, J, LOffset, LTotal: Integer;
begin
  while (Length(FLines) > 0) and (FLines[High(FLines)].Text = '') do
    SetLength(FLines, Length(FLines) - 1);
  LTotal := 0;
  for I := 0 to High(FLines) do
    Inc(LTotal, Length(FLines[I].Text) + 1);
  SetLength(FText, LTotal);
  SetLength(FStyles, LTotal);
  SetLength(FSources, LTotal);
  SetLength(FLineStarts, Length(FLines));
  LOffset := 0;
  for I := 0 to High(FLines) do
  begin
    FLineStarts[I] := LOffset;
    for J := 1 to Length(FLines[I].Text) do
    begin
      FText[LOffset + J] := FLines[I].Text[J];
      FStyles[LOffset + J - 1] := FLines[I].Styles[J - 1];
      if J <= Length(FLines[I].Sources) then
        FSources[LOffset + J - 1] := FLines[I].Sources[J - 1]
      else
        FSources[LOffset + J - 1] := -1;
    end;
    Inc(LOffset, Length(FLines[I].Text));
    FText[LOffset + 1] := #10;
    FStyles[LOffset] := msText;
    FSources[LOffset] := -1;
    Inc(LOffset);
  end;
  // No line break after the last line.
  if LTotal > 0 then
  begin
    SetLength(FText, LTotal - 1);
    SetLength(FStyles, LTotal - 1);
    SetLength(FSources, LTotal - 1);
  end;
  FLines := nil;
end;

procedure TManualDocument.Render(AWidth: Integer);
var
  I, LIndent: Integer;
  LMarker, LFirst, LRest: string;
  LBlock: TManualBlock;
begin
  if AWidth < MinRenderWidth then
    AWidth := MinRenderWidth;
  FWidth := AWidth;
  FLines := nil;
  FHeadings := nil;
  FNextSource := 0;
  for I := 0 to High(FBlocks) do
  begin
    LBlock := FBlocks[I];
    case LBlock.Kind of
      mbHeading:
        RenderHeading(LBlock);
      mbParagraph:
        begin
          RenderWrapped(LBlock.Text, msText, '', '', msText);
          AddBlank;
        end;
      mbListItem:
        begin
          LIndent := 2 + 3 * LBlock.Level;
          if LBlock.Marker[1] in ['-', '*'] then
          begin
            if LBlock.Level = 0 then
              LMarker := '•'
            else
              LMarker := '◦';
          end
          else
            LMarker := LBlock.Marker;
          // A bullet list right after a numbered one (or the reverse) is a
          // separate list.
          if (I > 0) and (FBlocks[I - 1].Kind = mbListItem) and (LBlock.Level = 0) and
            (FBlocks[I - 1].Level = 0) and
            ((FBlocks[I - 1].Marker[1] in ['-', '*']) <> (LBlock.Marker[1] in ['-', '*'])) then
            AddBlank;
          LFirst := StringOfChar(' ', LIndent) + LMarker + ' ';
          LRest := StringOfChar(' ', LIndent + ManualCharCount(LMarker) + 1);
          RenderWrapped(LBlock.Text, msText, LFirst, LRest, msMuted);
          if (I = High(FBlocks)) or (FBlocks[I + 1].Kind <> mbListItem) then
            AddBlank;
        end;
      mbTable:
        begin
          RenderTable(LBlock);
          AddBlank;
        end;
      mbCode:
        begin
          RenderCode(LBlock);
          AddBlank;
        end;
    end;
  end;
  BuildText;
end;

function TManualDocument.LineCount: Integer;
begin
  Result := Length(FLineStarts);
end;

function TManualDocument.LineStart(ALine: Integer): Integer;
begin
  if (ALine < 0) or (ALine >= Length(FLineStarts)) then
    raise ERangeError.CreateFmt('Manual line %d', [ALine]);
  Result := FLineStarts[ALine];
end;

function TManualDocument.LineOfOffset(AOffset: Integer): Integer;
var
  L, H, M: Integer;
begin
  Result := 0;
  if Length(FLineStarts) = 0 then
    Exit;
  L := 0;
  H := High(FLineStarts);
  while L < H do
  begin
    M := (L + H + 1) div 2;
    if FLineStarts[M] <= AOffset then
      L := M
    else
      H := M - 1;
  end;
  Result := L;
end;

function TManualDocument.FindMatches(const AQuery: string): TManualMatches;
var
  LRendered: TManualOffsets; // rendered offset of each logical position
  LText: string;
  LOffsets: TManualOffsets;
  I, LSource, N, LLast: Integer;
begin
  SetLength(LRendered, FNextSource);
  for I := 0 to High(LRendered) do
    LRendered[I] := -1;
  for I := 0 to High(FSources) do
  begin
    LSource := FSources[I];
    if (LSource >= 0) and (LSource < FNextSource) then
      LRendered[LSource] := I;
  end;
  // The logical text in source order (table cells are laid out side by side,
  // but read one after the other); a gap becomes one space.
  SetLength(LText, FNextSource);
  SetLength(LOffsets, FNextSource);
  N := 0;
  LLast := -2;
  for LSource := 0 to High(LRendered) do
  begin
    if LRendered[LSource] < 0 then
      Continue;
    if (LLast >= 0) and (LSource > LLast + 1) then
    begin
      Inc(N);
      LText[N] := ' ';
      LOffsets[N - 1] := LRendered[LSource];
    end;
    Inc(N);
    LText[N] := FText[LRendered[LSource] + 1];
    LOffsets[N - 1] := LRendered[LSource];
    LLast := LSource;
  end;
  SetLength(LText, N);
  SetLength(LOffsets, N);
  Result := FindMappedMatches(LText, LOffsets, AQuery);
end;

function TManualDocument.StyleAt(AOffset: Integer): TManualStyle;
begin
  if (AOffset < 0) or (AOffset >= Length(FStyles)) then
    Result := msText
  else
    Result := FStyles[AOffset];
end;

end.
