program help_menu_check;
{$mode objfpc}{$H+}{$codepage utf8}
{$IFNDEF GWDGUI_NONINTERACTIVE_TEST}{$FATAL Build with its LPI project}{$ENDIF}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Interfaces, Forms, Classes, SysUtils,
  Controls, Menus, LCLType, StdCtrls, LazUTF8, uMainForm, uGuiDialogs, uPdn,
  uManualForm, uAppInfo;
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
var Main: TMainForm; Manual: TManualForm; Search: TEdit; Memo: TMemo;
  Status: TLabel; Matches: TManualMatches; Before: string; Key: Word;
  CurrentCommit: string;
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
    Memo := TMemo(Manual.FindComponent('ManualText'));
    Status := TLabel(Manual.FindComponent('ManualMatchStatus'));
    Check(Memo.ReadOnly and (Pos('GWDGUI User Manual', Memo.Text) > 0) and
      (Pos('Choose capture', Memo.Text) + Pos('captures share', Memo.Text) > 0), 'embedded current manual available without external file');
    Search.Text := 'tournament';
    Matches := FindManualMatches(Memo.Text, Search.Text);
    Check((Length(Matches) > 2) and (Memo.SelStart = Matches[0].Start) and
      (UTF8LowerCase(Memo.SelText) = 'tournament'), 'search selects first case-insensitive match');
    TButton(Manual.FindComponent('ManualNext')).Click;
    Check(Memo.SelStart = Matches[1].Start, 'next selects next match');
    TButton(Manual.FindComponent('ManualPrevious')).Click;
    TButton(Manual.FindComponent('ManualPrevious')).Click;
    Check(Memo.SelStart = Matches[High(Matches)].Start, 'previous wraps to final match');
    Key := VK_F3; Manual.OnKeyDown(Manual, Key, []);
    Check((Key = 0) and (Memo.SelStart = Matches[0].Start), 'F3 wraps forward');
    Key := VK_F3; Manual.OnKeyDown(Manual, Key, [ssShift]);
    Check(Memo.SelStart = Matches[High(Matches)].Start, 'Shift F3 navigates backwards');
    Memo.SetFocus; Key := Ord('F'); Manual.OnKeyDown(Manual, Key, [ssCtrl]);
    Check((Key = 0) and (Manual.ActiveControl = Search) and (Search.SelText = Search.Text), 'Ctrl F focuses and selects query');
    Search.Text := 'no-such-manual-phrase-12345';
    Check((Status.Caption = 'No matches') and (Memo.SelLength = 0), 'no-match feedback clears old highlight');
    Search.Clear; Check(Memo.SelLength = 0, 'empty query clears highlight');
    Key := VK_ESCAPE; Manual.OnKeyDown(Manual, Key, []);
    Check(not Manual.Visible, 'Escape closes help');
    FindMenu(Main, 'Manual...').Click;
    Check((Main.FindComponent('ManualWindow') = Manual) and Manual.Visible, 'reopen reuses help window');
    Check(Main.CurrentGameTreePdnText('before help') = Before, 'help leaves game untouched');
  finally GuiTestConfirmationResult := 0; Main.Free; end;
end;
procedure CheckUtf8Search;
var Matches: TManualMatches;
begin
  Matches := FindManualMatches('αβ' + LineEnding + 'Draughts — DRAUGHTS', 'draughts');
  Check((Length(Matches) = 2) and (Matches[0].Start = 2 + Length(LineEnding)) and
    (Matches[1].Start = Matches[0].Start + 11) and (Matches[0].Count = 8),
    'Unicode and multiline offsets use characters rather than UTF8 byte counts');
  Check(Length(FindManualMatches('anything', '')) = 0, 'empty search has no matches');
end;

begin
  RequireDerivedFormResource := False; Application.Initialize;
  CheckMenus; CheckManual; CheckUtf8Search;
  Writeln('Help and menu checks passed');
end.
