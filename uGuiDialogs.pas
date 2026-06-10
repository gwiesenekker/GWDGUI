unit uGuiDialogs;

{$mode objfpc}{$H+}

interface

uses
  Forms, Types;

function ShowGuiConfirmationDialog(AOwner: TCustomForm; const ACaption,
  AText, AAcceptCaption, ARejectCaption: string; ARejectResult: Integer): Integer;
function ShowGuiOkDialog(AOwner: TCustomForm; const ACaption,
  AText: string): Integer;
function ShowGuiTextDialog(AOwner: TCustomForm; const ACaption,
  AText: string): Integer;
procedure CenterFormInWorkArea(AForm: TCustomForm; const AWorkArea: TRect);
procedure CenterFormOnPrimaryMonitor(AForm: TCustomForm);
procedure CenterFormOnMonitorIndex(AForm: TCustomForm; AMonitorIndex: Integer);
procedure CenterFormOnLaptopPanel(AForm: TCustomForm;
  AFallbackMonitorIndex: Integer = 0);
procedure CenterFormOnMouseMonitor(AForm: TCustomForm);
procedure CenterFormOnOwner(AForm, AOwner: TCustomForm);
procedure ShowFormCenteredOnOwner(AForm, AOwner: TCustomForm);

implementation

uses
  Classes, Controls, ExtCtrls, Graphics, Math, Process, StdCtrls, SysUtils;

const
  DialogWidth = 400;
  DialogMargin = 20;
  DialogButtonTopMargin = 18;
  DialogButtonHeight = 28;
  DialogBottomMargin = 18;
  DialogMinTextHeight = 44;
  DialogMaxTextHeight = 220;

procedure ClampFormToWorkArea(AForm: TCustomForm; const AWorkArea: TRect);
begin
  if AForm = nil then
    Exit;

  if AForm.Left < AWorkArea.Left then
    AForm.Left := AWorkArea.Left;
  if AForm.Top < AWorkArea.Top then
    AForm.Top := AWorkArea.Top;
  if AForm.Left + AForm.Width > AWorkArea.Right then
    AForm.Left := AWorkArea.Right - AForm.Width;
  if AForm.Top + AForm.Height > AWorkArea.Bottom then
    AForm.Top := AWorkArea.Bottom - AForm.Height;
  if AForm.Left < AWorkArea.Left then
    AForm.Left := AWorkArea.Left;
  if AForm.Top < AWorkArea.Top then
    AForm.Top := AWorkArea.Top;
end;

procedure CenterFormInWorkArea(AForm: TCustomForm; const AWorkArea: TRect);
begin
  if AForm = nil then
    Exit;

  AForm.Position := poDesigned;
  AForm.Left := AWorkArea.Left + ((AWorkArea.Width - AForm.Width) div 2);
  AForm.Top := AWorkArea.Top + ((AWorkArea.Height - AForm.Height) div 2);
  ClampFormToWorkArea(AForm, AWorkArea);
end;

procedure CenterFormOnPrimaryMonitor(AForm: TCustomForm);
begin
  CenterFormInWorkArea(AForm, Screen.PrimaryMonitor.WorkareaRect);
end;

procedure CenterFormOnMonitorIndex(AForm: TCustomForm; AMonitorIndex: Integer);
begin
  if (AMonitorIndex >= 0) and (AMonitorIndex < Screen.MonitorCount) then
    CenterFormInWorkArea(AForm, Screen.Monitors[AMonitorIndex].WorkareaRect)
  else
    CenterFormOnPrimaryMonitor(AForm);
end;

function XRandrLineIsLaptopPanel(const ALine: string): Boolean;
var
  LLine: string;
begin
  LLine := LowerCase(Trim(ALine));
  Result := (Pos(' connected', LLine) > 0) and
    ((Pos('edp', LLine) = 1) or (Pos('lvds', LLine) = 1) or
    (Pos('dsi', LLine) = 1));
end;

function TryParseXRandrGeometryToken(const AToken: string; out ARect: TRect): Boolean;
var
  H: Integer;
  I: Integer;
  Sign2: Integer;
  W: Integer;
  X: Integer;
  XSep: Integer;
  Y: Integer;

  function ParseSignedInt(const S: string; out AValue: Integer): Boolean;
  var
    Code: Integer;
  begin
    Val(S, AValue, Code);
    Result := Code = 0;
  end;

begin
  Result := False;
  XSep := Pos('x', AToken);
  if XSep <= 1 then
    Exit;

  Sign2 := 0;
  for I := XSep + 1 to Length(AToken) do
    if (AToken[I] = '+') or (AToken[I] = '-') then
    begin
      Sign2 := I;
      Break;
    end;
  if Sign2 <= XSep + 1 then
    Exit;

  I := Sign2 + 1;
  while (I <= Length(AToken)) and not ((AToken[I] = '+') or
    (AToken[I] = '-')) do
    Inc(I);
  if I > Length(AToken) then
    Exit;

  if not ParseSignedInt(Copy(AToken, 1, XSep - 1), W) then
    Exit;
  if not ParseSignedInt(Copy(AToken, XSep + 1, Sign2 - XSep - 1), H) then
    Exit;
  if not ParseSignedInt(Copy(AToken, Sign2, I - Sign2), X) then
    Exit;
  if not ParseSignedInt(Copy(AToken, I, Length(AToken) - I + 1), Y) then
    Exit;
  if (W <= 0) or (H <= 0) then
    Exit;

  ARect := Rect(X, Y, X + W, Y + H);
  Result := True;
end;

function TryParseXRandrGeometryLine(const ALine: string; out ARect: TRect): Boolean;
var
  I: Integer;
  Parts: TStringList;
begin
  Result := False;
  Parts := TStringList.Create;
  try
    ExtractStrings([' ', #9], [], PChar(ALine), Parts);
    for I := 0 to Parts.Count - 1 do
      if TryParseXRandrGeometryToken(Parts[I], ARect) then
        Exit(True);
  finally
    Parts.Free;
  end;
end;

function TryGetLaptopPanelRectFromXRandr(out ARect: TRect): Boolean;
var
  I: Integer;
  Lines: TStringList;
  Proc: TProcess;
begin
  Result := False;
  Lines := TStringList.Create;
  Proc := TProcess.Create(nil);
  try
    Proc.Executable := 'xrandr';
    Proc.Parameters.Add('--query');
    Proc.Options := [poUsePipes, poWaitOnExit];
    try
      Proc.Execute;
      if Proc.ExitStatus <> 0 then
        Exit;
      Lines.LoadFromStream(Proc.Output);
    except
      Exit;
    end;

    for I := 0 to Lines.Count - 1 do
      if XRandrLineIsLaptopPanel(Lines[I]) and
        TryParseXRandrGeometryLine(Lines[I], ARect) then
        Exit(True);
  finally
    Proc.Free;
    Lines.Free;
  end;
end;

procedure CenterFormOnLaptopPanel(AForm: TCustomForm;
  AFallbackMonitorIndex: Integer);
var
  LRect: TRect;
begin
  if TryGetLaptopPanelRectFromXRandr(LRect) then
    CenterFormInWorkArea(AForm, LRect)
  else
    CenterFormOnMonitorIndex(AForm, AFallbackMonitorIndex);
end;

procedure CenterFormOnMouseMonitor(AForm: TCustomForm);
begin
  CenterFormInWorkArea(AForm,
    Screen.MonitorFromPoint(Mouse.CursorPos).WorkareaRect);
end;

procedure CenterFormOnOwner(AForm, AOwner: TCustomForm);
begin
  if AForm = nil then
    Exit;

  if AOwner = nil then
  begin
    CenterFormOnPrimaryMonitor(AForm);
    Exit;
  end;

  AForm.Position := poDesigned;
  AForm.Left := AOwner.Left + ((AOwner.Width - AForm.Width) div 2);
  AForm.Top := AOwner.Top + ((AOwner.Height - AForm.Height) div 2);
end;

procedure ShowFormCenteredOnOwner(AForm, AOwner: TCustomForm);
begin
  if AForm = nil then
    Exit;
  CenterFormOnOwner(AForm, AOwner);
  AForm.Show;
  AForm.BringToFront;
end;

function WrappedTextHeight(ADialog: TForm; const AText: string;
  AWidth: Integer): Integer;
var
  ApproxCharsPerLine: Integer;
  I: Integer;
  LineCount: Integer;
  LinePart: string;
  Lines: TStringList;
begin
  Result := DialogMinTextHeight;
  if AWidth <= 0 then
    Exit;

  ApproxCharsPerLine := Max(1, AWidth div Max(1,
    ADialog.Canvas.TextWidth('n')));
  Lines := TStringList.Create;
  try
    Lines.Text := StringReplace(AText, LineEnding, #10, [rfReplaceAll]);
    LineCount := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      LinePart := Lines[I];
      if LinePart = '' then
        Inc(LineCount)
      else
        Inc(LineCount, Max(1, Ceil(Length(LinePart) / ApproxCharsPerLine)));
    end;
    Result := LineCount * (ADialog.Canvas.TextHeight('Wg') + 3);
    Result := Max(DialogMinTextHeight, Min(DialogMaxTextHeight, Result));
  finally
    Lines.Free;
  end;
end;

function ShowGuiConfirmationDialog(AOwner: TCustomForm; const ACaption,
  AText, AAcceptCaption, ARejectCaption: string; ARejectResult: Integer): Integer;
var
  AcceptLeft: Integer;
  Button: TButton;
  ButtonTop: Integer;
  CancelLeft: Integer;
  Dialog: TForm;
  RejectLeft: Integer;
  TextHeight: Integer;
  TextWidth: Integer;
  PromptLabel: TLabel;
begin
  Dialog := TForm.Create(AOwner);
  try
    Dialog.BorderStyle := bsDialog;
    Dialog.Caption := ACaption;
    Dialog.ClientWidth := DialogWidth;
    Dialog.Color := clBtnFace;
    Dialog.ModalResult := mrCancel;
    TextWidth := Dialog.ClientWidth - (2 * DialogMargin);
    TextHeight := WrappedTextHeight(Dialog, AText, TextWidth);
    ButtonTop := DialogMargin + TextHeight + DialogButtonTopMargin;
    Dialog.ClientHeight := ButtonTop + DialogButtonHeight + DialogBottomMargin;

    PromptLabel := TLabel.Create(Dialog);
    PromptLabel.Parent := Dialog;
    PromptLabel.AutoSize := False;
    PromptLabel.SetBounds(DialogMargin, DialogMargin, TextWidth, TextHeight);
    PromptLabel.WordWrap := True;
    PromptLabel.Caption := AText;

    CancelLeft := Dialog.ClientWidth - DialogMargin - 80;
    RejectLeft := CancelLeft - 94;
    AcceptLeft := RejectLeft - 86;
    if ARejectCaption = '' then
      AcceptLeft := RejectLeft;

    Button := TButton.Create(Dialog);
    Button.Parent := Dialog;
    Button.Caption := AAcceptCaption;
    Button.ModalResult := mrYes;
    Button.SetBounds(AcceptLeft, ButtonTop, 80, DialogButtonHeight);
    Dialog.DefaultControl := Button;

    if ARejectCaption <> '' then
    begin
      Button := TButton.Create(Dialog);
      Button.Parent := Dialog;
      Button.Caption := ARejectCaption;
      Button.ModalResult := ARejectResult;
      Button.SetBounds(RejectLeft, ButtonTop, 88, DialogButtonHeight);
    end;

    Button := TButton.Create(Dialog);
    Button.Parent := Dialog;
    Button.Caption := 'Cancel';
    Button.ModalResult := mrCancel;
    Button.SetBounds(CancelLeft, ButtonTop, 80, DialogButtonHeight);
    Dialog.CancelControl := Button;

    CenterFormOnOwner(Dialog, AOwner);
    Result := Dialog.ShowModal;
  finally
    Dialog.Free;
  end;
end;

function ShowGuiOkDialog(AOwner: TCustomForm; const ACaption,
  AText: string): Integer;
begin
  Result := ShowGuiConfirmationDialog(AOwner, ACaption, AText, 'OK', '',
    mrCancel);
end;

function ShowGuiTextDialog(AOwner: TCustomForm; const ACaption,
  AText: string): Integer;
var
  Button: TButton;
  ButtonPanel: TPanel;
  Dialog: TForm;
  Memo: TMemo;
begin
  Dialog := TForm.Create(AOwner);
  try
    Dialog.Caption := ACaption;
    Dialog.Position := poDesigned;
    Dialog.Color := clBtnFace;
    Dialog.BorderStyle := bsSizeable;
    Dialog.Width := 760;
    Dialog.Height := 520;
    Dialog.Constraints.MinWidth := 420;
    Dialog.Constraints.MinHeight := 260;

    ButtonPanel := TPanel.Create(Dialog);
    ButtonPanel.Parent := Dialog;
    ButtonPanel.Align := alBottom;
    ButtonPanel.Height := 52;
    ButtonPanel.BevelOuter := bvNone;

    Button := TButton.Create(Dialog);
    Button.Parent := ButtonPanel;
    Button.Caption := 'OK';
    Button.ModalResult := mrOk;
    Button.SetBounds(ButtonPanel.ClientWidth - DialogMargin - 80, 12, 80,
      DialogButtonHeight);
    Button.Anchors := [akTop, akRight];
    Dialog.DefaultControl := Button;
    Dialog.CancelControl := Button;

    Memo := TMemo.Create(Dialog);
    Memo.Parent := Dialog;
    Memo.Align := alClient;
    Memo.BorderSpacing.Around := DialogMargin;
    Memo.ReadOnly := True;
    Memo.ScrollBars := ssBoth;
    Memo.WordWrap := False;
    Memo.Lines.Text := AText;
    Memo.SelStart := 0;

    CenterFormOnOwner(Dialog, AOwner);
    Result := Dialog.ShowModal;
  finally
    Dialog.Free;
  end;
end;

end.
