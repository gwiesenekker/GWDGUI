unit GuiDialogs;

{$mode objfpc}{$H+}

interface

uses
  Forms;

function ShowGuiConfirmationDialog(AOwner: TCustomForm; const ACaption,
  AText, AAcceptCaption, ARejectCaption: String; ARejectResult: Integer): Integer;
function ShowGuiOkDialog(AOwner: TCustomForm; const ACaption,
  AText: String): Integer;

implementation

uses
  Classes,
  Controls,
  Graphics,
  Math,
  StdCtrls,
  SysUtils,
  Types;

const
  DialogWidth = 400;
  DialogMargin = 20;
  DialogButtonTopMargin = 18;
  DialogButtonHeight = 28;
  DialogBottomMargin = 18;
  DialogMinTextHeight = 44;
  DialogMaxTextHeight = 220;

procedure CenterDialogOnOwner(ADialog, AOwner: TCustomForm);
var
  WorkArea: TRect;
begin
  if ADialog = nil then
    Exit;

  if AOwner = nil then
  begin
    ADialog.Position := poScreenCenter;
    Exit;
  end;

  WorkArea := AOwner.Monitor.WorkareaRect;
  ADialog.Position := poDesigned;
  ADialog.Left := AOwner.Left + ((AOwner.Width - ADialog.Width) div 2);
  ADialog.Top := AOwner.Top + ((AOwner.Height - ADialog.Height) div 2);

  if ADialog.Left < WorkArea.Left then
    ADialog.Left := WorkArea.Left;
  if ADialog.Top < WorkArea.Top then
    ADialog.Top := WorkArea.Top;
  if ADialog.Left + ADialog.Width > WorkArea.Right then
    ADialog.Left := WorkArea.Right - ADialog.Width;
  if ADialog.Top + ADialog.Height > WorkArea.Bottom then
    ADialog.Top := WorkArea.Bottom - ADialog.Height;
end;

function WrappedTextHeight(ADialog: TForm; const AText: String;
  AWidth: Integer): Integer;
var
  ApproxCharsPerLine: Integer;
  I: Integer;
  LineCount: Integer;
  LinePart: String;
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
  AText, AAcceptCaption, ARejectCaption: String; ARejectResult: Integer): Integer;
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

    CenterDialogOnOwner(Dialog, AOwner);
    Result := Dialog.ShowModal;
  finally
    Dialog.Free;
  end;
end;

function ShowGuiOkDialog(AOwner: TCustomForm; const ACaption,
  AText: String): Integer;
begin
  Result := ShowGuiConfirmationDialog(AOwner, ACaption, AText, 'OK', '',
    mrCancel);
end;

end.
