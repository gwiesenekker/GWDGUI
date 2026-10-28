program help_menu_check;
{$mode objfpc}{$H+}{$codepage utf8}
{$IFNDEF GWDGUI_NONINTERACTIVE_TEST}{$FATAL Build with its LPI project}{$ENDIF}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Interfaces, Forms, Classes, SysUtils,
  Controls, Menus, LCLType, StdCtrls, ComCtrls, LazUTF8, SynEdit, uMainForm, uGuiDialogs,
  uDraughtsPdn, uManualForm, uManualDocument, uAppInfo, uDraughtsPosition;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then begin WriteLn('FAIL: ', Text); Halt(1); end; end;
function FindMenu(Form: TMainForm; const Caption: string): TMenuItem;
var I: Integer;
begin
  for I := 0 to Form.ComponentCount - 1 do
    if (Form.Components[I] is TMenuItem) and
      (StringReplace(TMenuItem(Form.Components[I]).Caption, '&', '', [rfReplaceAll]) = Caption) then
      Exit(TMenuItem(Form.Components[I]));
  raise Exception.Create('Missing menu: ' + Caption);
end;
procedure CheckMenus;
var Form: TMainForm; Game: TPdnGame;
begin
  Form := TMainForm.Create(nil);
  try
    Check(FindMenu(Form, 'Open PDN...').ShortCut = ShortCut(Ord('O'), [ssCtrl]), 'open shortcut');
    Check(FindMenu(Form, 'Save PDN...').ShortCut = ShortCut(Ord('S'), [ssCtrl]), 'save shortcut');
    Check(FindMenu(Form, 'Preferences...').ShortCut = ShortCut(Ord(','), [ssCtrl]), 'preferences shortcut');
    Check(FindMenu(Form, 'Open database...').ShortCut = ShortCut(Ord('O'), [ssCtrl, ssShift]), 'database open shortcut');
    Check(FindMenu(Form, 'Create database...').ShortCut = ShortCut(Ord('N'), [ssCtrl, ssShift]), 'database create shortcut');
    Check(FindMenu(Form, 'Quit').ShortCut = ShortCut(Ord('Q'), [ssCtrl]), 'quit shortcut');
    Check(FindMenu(Form, 'Quit').Parent = FindMenu(Form, 'File'), 'quit belongs to file menu');
    Game := TPdnGame.Create;
    try Game.MovesText := '32-28'; Form.LoadPdnGameToDisplay(Game); finally Game.Free; end;
    Form.Show;
    GuiTestConfirmationResult := mrCancel;
    FindMenu(Form, 'Quit').Click;
    Check(Form.Visible and (Form.ActiveGameTree.MainlineCount = 1), 'quit cancel preserves unsaved game and window');
    GuiTestConfirmationResult := mrNo;
    FindMenu(Form, 'Quit').Click;
    Check(not Form.Visible, 'quit follows normal close after declining save');
  finally GuiTestConfirmationResult := 0; Form.Free; end;
end;
procedure CheckManual;
var Main: TMainForm; Manual: TManualForm; Search: TEdit; Text: TSynEdit;
  Contents: TTreeView; Status: TLabel; Matches: TManualMatches; Before: string;
  Key: Word; CurrentCommit: string; Node: TTreeNode; I, Heading: Integer;

  function Selected: string;
  begin
    Result := StringReplace(Text.SelText, LineEnding, #10, [rfReplaceAll]);
  end;

  function MatchText(const AMatch: TManualMatch): string;
  begin
    Result := Copy(Manual.Document.Text, AMatch.Start + 1, AMatch.Count);
  end;

begin
  Main := TMainForm.Create(nil);
  try
    Check(FindMenu(Main, 'Manual...').Parent = FindMenu(Main, 'Help'), 'manual belongs to help');
    Check(FindMenu(Main, 'Manual...').ShortCut = ShortCut(VK_F1, []), 'manual F1 shortcut');
    Check(FindMenu(Main, 'About GWDGUI...').ShortCut = ShortCut(VK_F1, [ssShift]), 'about shortcut');
    CurrentCommit := AppBuildCommit;
    Check(((Length(CurrentCommit) = 40) and (Pos('unavailable', CurrentCommit) = 0)) or
      (CurrentCommit = 'unavailable (source archive)'), 'build identifies its commit or explicitly identifies an archive');
    GuiTestConfirmationResult := mrYes;
    FindMenu(Main, 'About GWDGUI...').Click;
    Check((Pos('GWDGUI', GuiTestLastConfirmationText) > 0) and
      (Pos('Commit: ' + CurrentCommit, GuiTestLastConfirmationText) > 0), 'About action displays embedded commit');
    GuiTestConfirmationResult := 0;
    Before := Main.CurrentGameTreePdnText('before help');
    FindMenu(Main, 'Manual...').Click;
    Manual := TManualForm(Main.FindComponent('ManualWindow'));
    Check((Manual <> nil) and Manual.Visible, 'manual menu opens an owned help window');
    Search := TEdit(Manual.FindComponent('ManualSearch'));
    Text := TSynEdit(Manual.FindComponent('ManualText'));
    Contents := TTreeView(Manual.FindComponent('ManualContents'));
    Status := TLabel(Manual.FindComponent('ManualMatchStatus'));
    Check(Text.ReadOnly and (Pos('GWDGUI User Manual', Text.Lines.Text) > 0) and
      (Pos('Choose capture', Text.Lines.Text) + Pos('captures share', Text.Lines.Text) > 0),
      'embedded current manual available without external file');
    Check((Pos('**', Text.Lines.Text) = 0) and (Pos('## ', Text.Lines.Text) = 0),
      'the manual is shown without Markdown markers');

    // Contents: one top-level entry per section; selecting one shows it.
    Check(Contents.Items.TopLvlCount >= 10, 'contents list the sections');
    Node := Contents.Items.TopLvlItems[3];
    Contents.Selected := Node;
    Heading := PtrInt(Node.Data);
    Check(Text.TopLine = Manual.Document.Headings[Heading].Line + 1,
      Format('selecting a section shows it at the top (top %d, heading line %d, lines %d, window %d)',
        [Text.TopLine, Manual.Document.Headings[Heading].Line + 1, Text.Lines.Count, Text.LinesInWindow]));
    Check(Node.HasChildren and (Node.GetFirstChild.Text <> ''), 'subsections are nested');
    Heading := PtrInt(Contents.Items.TopLvlItems[6].Data);
    Text.TopLine := Manual.Document.Headings[Heading].Line + 2;
    Application.ProcessMessages;
    Check((Contents.Selected <> nil) and (Contents.Selected.Text =
      Manual.Document.Headings[Heading].Title),
      'scrolling the text follows in the contents');

    // Search over the rendered text, also across wrapped lines.
    Search.Text := 'tournament';
    Matches := Manual.Matches;
    Check((Length(Matches) > 2) and (Manual.MatchIndex = 0) and
      (UTF8LowerCase(Selected) = 'tournament'), 'search selects first case-insensitive match');
    TButton(Manual.FindComponent('ManualNext')).Click;
    Check((Manual.MatchIndex = 1) and (UTF8LowerCase(Selected) = 'tournament'), 'next selects next match');
    TButton(Manual.FindComponent('ManualPrevious')).Click;
    TButton(Manual.FindComponent('ManualPrevious')).Click;
    Check(Manual.MatchIndex = High(Matches), 'previous wraps to final match');
    Key := VK_F3; Manual.OnKeyDown(Manual, Key, []);
    Check((Key = 0) and (Manual.MatchIndex = 0), 'F3 wraps forward');
    Key := VK_F3; Manual.OnKeyDown(Manual, Key, [ssShift]);
    Check(Manual.MatchIndex = High(Matches), 'Shift F3 navigates backwards');
    Text.SetFocus; Key := Ord('F'); Manual.OnKeyDown(Manual, Key, [ssCtrl]);
    Check((Key = 0) and (Manual.ActiveControl = Search) and (Search.SelText = Search.Text), 'Ctrl F focuses and selects query');

    // A phrase that the layout wraps is still found, at every width.
    Manual.RenderForColumns(40);
    Search.Text := 'launched for this test';
    Check((Length(Manual.Matches) = 1) and (Text.SelAvail) and
      (Pos('launched', MatchText(Manual.Matches[0])) = 1), 'phrase found at 40 columns');
    Manual.RenderForColumns(160);
    Check(Length(Manual.Matches) = 1, 'search results follow a re-render');
    for I := 0 to Text.Lines.Count - 1 do
      if UTF8Length(Text.Lines[I]) > 160 then
        Check(Copy(Text.Lines[I], 1, 4) = '    ', 'only code lines may exceed the width');

    Search.Text := 'no-such-manual-phrase-12345';
    Check((Status.Caption = 'No matches') and (not Text.SelAvail), 'no-match feedback clears old highlight');
    Search.Clear; Check(not Text.SelAvail, 'empty query clears highlight');
    Key := VK_ESCAPE; Manual.OnKeyDown(Manual, Key, []);
    Check(not Manual.Visible, 'Escape closes help');
    FindMenu(Main, 'Manual...').Click;
    Check((Main.FindComponent('ManualWindow') = Manual) and Manual.Visible, 'reopen reuses help window');
    Check(Main.CurrentGameTreePdnText('before help') = Before, 'help leaves game untouched');
  finally GuiTestConfirmationResult := 0; Main.Free; end;
end;
procedure CheckUtf8Search;
var Matches: TManualMatches; Text: string;
begin
  Text := 'αβ' + #10 + 'Draughts — DRAUGHTS';
  Matches := FindManualMatches(Text, 'draughts');
  Check((Length(Matches) = 2) and (Matches[0].Start = Pos('Draughts', Text) - 1) and
    (Copy(Text, Matches[1].Start + 1, Matches[1].Count) = 'DRAUGHTS') and (Matches[0].Count = 8),
    'matches are byte offsets in the rendered UTF-8 text');
  Check(Length(FindManualMatches('anything', '')) = 0, 'empty search has no matches');
  Matches := FindManualMatches('first' + #10 + '    second', 'first second');
  Check((Length(Matches) = 1) and (Matches[0].Count = Length('first' + #10 + '    second')),
    'whitespace and line breaks match a single space in the query');
end;

begin
  RequireDerivedFormResource := False; Application.Initialize;
  CheckMenus; CheckManual; CheckUtf8Search;
  Writeln('Help and menu checks passed');
end.
