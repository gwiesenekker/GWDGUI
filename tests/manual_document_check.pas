program manual_document_check;

{$mode objfpc}{$H+}

{ Rendering of the manual for the manual window (uManualDocument): Markdown
  markers removed, styles, wrapping with hanging indents, tables, code blocks,
  the contents, and the real MANUAL.md at several widths. }

uses
  Classes, SysUtils, uManualDocument;

var
  Failures: Integer = 0;

procedure Check(ACondition: Boolean; const AMessage: string);
begin
  if not ACondition then
  begin
    Inc(Failures);
    WriteLn('FAIL: ', AMessage);
  end;
end;

function LineText(ADoc: TManualDocument; ALine: Integer): string;
var
  LEnd: Integer;
begin
  if ALine + 1 < ADoc.LineCount then
    LEnd := ADoc.LineStart(ALine + 1) - 1
  else
    LEnd := Length(ADoc.Text);
  Result := Copy(ADoc.Text, ADoc.LineStart(ALine) + 1, LEnd - ADoc.LineStart(ALine));
end;

function FindLine(ADoc: TManualDocument; const AText: string): Integer;
var
  I: Integer;
begin
  for I := 0 to ADoc.LineCount - 1 do
    if Pos(AText, LineText(ADoc, I)) > 0 then
      Exit(I);
  Result := -1;
end;

function StyleOf(ADoc: TManualDocument; const AText: string): TManualStyle;
var
  P: Integer;
begin
  P := Pos(AText, ADoc.Text);
  if P = 0 then
    Exit(msMuted);
  Result := ADoc.StyleAt(P - 1);
end;

const
  Sample =
    '# Sample Manual' + LineEnding +
    '' + LineEnding +
    'Intro text with **bold words** and `code text` and a [link `x`](y.md).' + LineEnding +
    'Second source line of the same paragraph.' + LineEnding +
    '' + LineEnding +
    '## 1. Section' + LineEnding +
    '' + LineEnding +
    '- first item that is long enough to wrap onto a second line of the' + LineEnding +
    '  rendered text at this width;' + LineEnding +
    '- second item' + LineEnding +
    '' + LineEnding +
    '1. Numbered step.' + LineEnding +
    '   - nested bullet' + LineEnding +
    '' + LineEnding +
    '### 1.1 Sub' + LineEnding +
    '' + LineEnding +
    '| Name | Meaning |' + LineEnding +
    '| --- | --- |' + LineEnding +
    '| `a` | short |' + LineEnding +
    '| `longer-name` | a meaning that is much too long for the remaining width of the table |' + LineEnding +
    '' + LineEnding +
    '```text' + LineEnding +
    'W:W31-50:B1-20  **not bold**' + LineEnding +
    '```' + LineEnding;

procedure CheckSample;
var
  LDoc: TManualDocument;
  I, LLine: Integer;
  LText: string;
begin
  LDoc := TManualDocument.Create;
  try
    LDoc.Load(Sample);
    LDoc.Render(50);
    LText := LDoc.Text;
    Check(Pos('**bold', LText) = 0, 'strong markers removed');
    Check(Pos('`code', LText) = 0, 'code markers removed');
    Check(Pos('](', LText) = 0, 'link target removed');
    Check(Pos('# Sample', LText) = 0, 'heading markers removed');
    Check(Pos('| ---', LText) = 0, 'table separator row removed');
    Check(StyleOf(LDoc, 'Sample Manual') = msTitle, 'title style');
    Check(StyleOf(LDoc, '1. Section') = msHeading, 'section style');
    Check(StyleOf(LDoc, '1.1 Sub') = msSubheading, 'subsection style');
    Check(StyleOf(LDoc, 'bold words') = msStrong, 'strong style');
    Check(StyleOf(LDoc, 'code text') = msCode, 'code style');
    Check(StyleOf(LDoc, 'link') = msText, 'link text keeps the surrounding style');
    Check(StyleOf(LDoc, 'Intro') = msText, 'text style');
    Check(Pos('W:W31-50:B1-20  **not bold**', LText) > 0, 'code blocks are kept verbatim');
    Check(StyleOf(LDoc, 'W:W31-50') = msCodeBlock, 'code block style');
    Check(Pos('paragraph. ', LText) = 0, 'no trailing space');
    Check(Pos('with **', LText) = 0, 'inline markers gone');
    Check(Pos('of the same paragraph.', LText) > 0,
      'paragraph source lines are joined before wrapping');

    // Contents
    Check(Length(LDoc.Headings) = 3, 'three headings');
    Check((LDoc.Headings[0].Level = 1) and (LDoc.Headings[0].Title = 'Sample Manual'),
      'title heading');
    Check((LDoc.Headings[1].Level = 2) and (LDoc.Headings[1].Title = '1. Section'),
      'section heading');
    Check(LineText(LDoc, LDoc.Headings[2].Line) = '1.1 Sub', 'heading line index');

    // Wrapping: every line except code fits the width.
    for I := 0 to LDoc.LineCount - 1 do
      if LDoc.StyleAt(LDoc.LineStart(I) + 4) <> msCodeBlock then
        Check(Length(UTF8Decode(LineText(LDoc, I))) <= 50,
          'line fits the width: "' + LineText(LDoc, I) + '"');

    // Lists: bullets and hanging indent.
    LLine := FindLine(LDoc, 'first item');
    Check((LLine >= 0) and (Pos('  • first', LineText(LDoc, LLine)) = 1),
      'top-level bullet: "' + LineText(LDoc, LLine) + '"');
    Check((LLine >= 0) and (Copy(LineText(LDoc, LLine + 1), 1, 4) = '    ') and
      (Copy(LineText(LDoc, LLine + 1), 5, 1) <> ' '),
      'continuation hangs under the item text: "' + LineText(LDoc, LLine + 1) + '"');
    Check(FindLine(LDoc, '  1. Numbered step.') >= 0, 'numbered item keeps its number');
    Check(FindLine(LDoc, '     ◦ nested bullet') >= 0, 'nested bullet');

    // Table: aligned columns, last column wrapped under itself.
    LLine := FindLine(LDoc, 'Name');
    Check((LLine >= 0) and (Pos('│ Meaning', LineText(LDoc, LLine)) > 0), 'table header');
    Check(StyleOf(LDoc, 'Meaning') = msTableHeader, 'table header style');
    Check((LLine >= 0) and (Pos('┼', LineText(LDoc, LLine + 1)) > 0), 'header rule');
    Check(Pos('a           │ short', LText) > 0, 'first column padded to its width');
    LLine := FindLine(LDoc, 'longer-name');
    Check((LLine >= 0) and (Pos('│ a meaning', LineText(LDoc, LLine)) > 0),
      'long cell starts in its column');
    Check((LLine >= 0) and (Pos('│ ', LineText(LDoc, LLine + 1)) =
      Pos('│ ', LineText(LDoc, LLine))), 'wrapped cell continues in its column');

    // Rendering again at another width keeps the content and moves headings.
    LDoc.Render(120);
    Check(Pos('first item that is long enough to wrap onto a second line of the rendered text at this width;',
      LDoc.Text) > 0, 'wider rendering keeps an item on one line');
    Check(LineText(LDoc, LDoc.Headings[2].Line) = '1.1 Sub', 'heading index after re-render');
  finally
    LDoc.Free;
  end;
end;

procedure CheckWrap;
var
  LPlain: string;
  LStyles: TManualStyles;
  LLines: TManualStyledLines;
begin
  ParseManualInline('aaaa bbbb `cc dd` eeeeeeeeeeeeeeee', msText, LPlain, LStyles);
  LLines := WrapManualText(LPlain, LStyles, 9);
  Check((Length(LLines) = 4) and (LLines[0].Text = 'aaaa bbbb') and
    (LLines[1].Text = 'cc dd') and (LLines[2].Text = 'eeeeeeeee') and
    (LLines[3].Text = 'eeeeeee'), 'greedy wrap with long-word split');
  Check((Length(LLines) > 1) and (LLines[1].Styles[2] = msCode),
    'a space inside a code span keeps the code style');
  ParseManualInline('αβγ δεζ', msText, LPlain, LStyles);
  LLines := WrapManualText(LPlain, LStyles, 7);
  Check((Length(LLines) = 1) and (LLines[0].Text = 'αβγ δεζ'),
    'width counts characters, not bytes');
end;

procedure CheckRealManual;
var
  LDoc: TManualDocument;
  LSource: TStringList;
  I, J, LWidth, LHeadingCount: Integer;
  LInFence: Boolean;
  LLine, LRoot: string;
const
  Widths: array[0..2] of Integer = (40, 80, 140);
begin
  LSource := TStringList.Create;
  LDoc := TManualDocument.Create;
  try
    LRoot := GetEnvironmentVariable('GWDGUI_ROOT');
    if LRoot = '' then
      LRoot := ExtractFilePath(ParamStr(0)) + '..';
    LSource.LoadFromFile(IncludeTrailingPathDelimiter(LRoot) + 'MANUAL.md');
    LHeadingCount := 0;
    LInFence := False;
    for I := 0 to LSource.Count - 1 do
    begin
      if Copy(LSource[I], 1, 3) = '```' then
        LInFence := not LInFence
      else if not LInFence and (Copy(LSource[I], 1, 1) = '#') then
        Inc(LHeadingCount);
    end;
    LDoc.Load(LSource.Text);
    for J := Low(Widths) to High(Widths) do
    begin
      LWidth := Widths[J];
      LDoc.Render(LWidth);
      Check(Length(LDoc.Headings) = LHeadingCount,
        Format('all %d headings in the contents at width %d, got %d',
          [LHeadingCount, LWidth, Length(LDoc.Headings)]));
      Check(Pos('**', LDoc.Text) = 0, 'no strong markers in the real manual');
      Check(Pos('GWDGUI User Manual', LDoc.Text) > 0, 'manual title');
      for I := 0 to LDoc.LineCount - 1 do
      begin
        LLine := LineText(LDoc, I);
        if (LDoc.StyleAt(LDoc.LineStart(I) + 4) <> msCodeBlock) and
          (Length(UTF8Decode(LLine)) > LWidth) then
          Check(False, Format('real manual line %d exceeds width %d: %s',
            [I, LWidth, LLine]));
      end;
      for I := 0 to High(LDoc.Headings) do
        Check(LineText(LDoc, LDoc.Headings[I].Line) <> '',
          'heading line is not blank: ' + LDoc.Headings[I].Title);
    end;
  finally
    LDoc.Free;
    LSource.Free;
  end;
end;

{ U11: search on the logical text finds words that wrapping split and table
  cells that wrap, at every width; real spaces still separate words. }
procedure CheckLogicalSearch;
var
  LDoc: TManualDocument;
  LSource: TStringList;
  LMatches: TManualMatches;
  LRoot, LHit: string;
  J, LCount, LTournament: Integer;
const
  Widths: array[0..3] of Integer = (30, 40, 80, 140);
  Synthetic =
    'Before averyveryveryverylongidentifierthatcannotfitononeline after.' + LineEnding +
    '' + LineEnding +
    '| Name | Meaning |' + LineEnding +
    '| --- | --- |' + LineEnding +
    '| `gui-another-long-parameter-name` | text of the cell that wraps |' + LineEnding;
begin
  LDoc := TManualDocument.Create;
  LSource := TStringList.Create;
  try
    LDoc.Load(Synthetic);
    for J := Low(Widths) to High(Widths) do
    begin
      LDoc.Render(Widths[J]);
      LMatches := LDoc.FindMatches('averyveryveryverylongidentifierthatcannotfitononeline');
      Check(Length(LMatches) = 1, Format('split word found at width %d', [Widths[J]]));
      LMatches := LDoc.FindMatches('gui-another-long-parameter-name');
      Check(Length(LMatches) = 1, Format('split table cell found at width %d', [Widths[J]]));
      if Length(LMatches) = 1 then
      begin
        LHit := Copy(LDoc.Text, LMatches[0].Start + 1, LMatches[0].Count);
        Check(Copy(LHit, 1, 4) = 'gui-', 'match starts at the cell: ' + LHit);
      end;
      Check(Length(LDoc.FindMatches('cell that wraps')) = 1,
        Format('phrase in a wrapped cell at width %d', [Widths[J]]));
      Check(Length(LDoc.FindMatches('beforeavery')) = 0, 'a real space still separates words');
      Check(Length(LDoc.FindMatches('meaning gui-another')) = 1,
        'table cells read one after another, separated by a space');
    end;

    LRoot := GetEnvironmentVariable('GWDGUI_ROOT');
    if LRoot = '' then
      LRoot := ExtractFilePath(ParamStr(0)) + '..';
    LSource.LoadFromFile(IncludeTrailingPathDelimiter(LRoot) + 'MANUAL.md');
    LDoc.Load(LSource.Text);
    LCount := -1;
    LTournament := -1;
    for J := Low(Widths) to High(Widths) do
    begin
      LDoc.Render(Widths[J]);
      LMatches := LDoc.FindMatches('gui-send-starting-position');
      Check(Length(LMatches) >= 1, Format('real parameter found at width %d', [Widths[J]]));
      if J = 0 then
      begin
        LCount := Length(LMatches);
        LTournament := Length(LDoc.FindMatches('tournament'));
      end;
      Check(Length(LMatches) = LCount, 'same number of parameter matches at every width');
      Check(Length(LDoc.FindMatches('tournament')) = LTournament,
        'same number of tournament matches at every width');
    end;
  finally
    LSource.Free;
    LDoc.Free;
  end;
end;

begin
  CheckSample;
  CheckWrap;
  CheckRealManual;
  CheckLogicalSearch;
  if Failures > 0 then
  begin
    WriteLn(Failures, ' manual document checks failed');
    Halt(1);
  end;
  WriteLn('Manual document checks passed');
end.
