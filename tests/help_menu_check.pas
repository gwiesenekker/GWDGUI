program help_menu_check;
{$mode objfpc}{$H+}
{$IFNDEF GWDGUI_NONINTERACTIVE_TEST}{$FATAL Build with its LPI project}{$ENDIF}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Interfaces, Forms, Classes, SysUtils,
  Controls, Menus, LCLType, uMainForm, uGuiDialogs, uPdn;
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
begin
  RequireDerivedFormResource := False; Application.Initialize;
  CheckMenus;
  Writeln('Help and menu checks passed');
end.
