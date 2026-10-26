unit uManualForm;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, LCLType;
type
  TManualMatch = record Start, Count: Integer; end;
  TManualMatches = array of TManualMatch;
  TManualForm = class(TForm)
  private
    FText: TMemo;
    FSearch: TEdit;
    FStatus: TLabel;
    FMatches: TManualMatches;
    FMatchIndex: Integer;
    procedure SearchChanged(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure PreviousClick(Sender: TObject);
    procedure Keys(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SelectMatch(Index: Integer);
  public
    constructor Create(AOwner: TComponent); override;
  end;
function FindManualMatches(const Text, Query: string): TManualMatches;
implementation
uses StrUtils, LazUTF8, uAppInfo, uGuiDialogs;
function FindManualMatches(const Text, Query: string): TManualMatches;
var Haystack, Needle: string; AtByte, N: Integer;
begin
  Result := nil;
  if Query = '' then Exit;
  Haystack := UTF8LowerCase(Text); Needle := UTF8LowerCase(Query);
  AtByte := PosEx(Needle, Haystack, 1);
  while AtByte > 0 do
  begin
    N := Length(Result); SetLength(Result, N + 1);
    Result[N].Start := UTF8Length(PChar(Haystack), AtByte - 1);
    Result[N].Count := UTF8Length(Query);
    AtByte := PosEx(Needle, Haystack, AtByte + Length(Needle));
  end;
end;
constructor TManualForm.Create(AOwner: TComponent);
var Bar: TPanel; LabelControl: TLabel; Button: TButton;
begin
  inherited CreateNew(AOwner);
  Name := 'ManualWindow'; Caption := 'GWDGUI Manual';
  Width := 960; Height := 720; Constraints.MinWidth := 760; Constraints.MinHeight := 360;
  KeyPreview := True; OnKeyDown := @Keys;
  Bar := TPanel.Create(Self); Bar.Parent := Self; Bar.Align := alTop;
  Bar.Height := 54; Bar.BevelOuter := bvNone;
  LabelControl := TLabel.Create(Self); LabelControl.Parent := Bar;
  LabelControl.Caption := 'Find:'; LabelControl.SetBounds(12, 18, 36, 22);
  FSearch := TEdit.Create(Self); FSearch.Parent := Bar; FSearch.Name := 'ManualSearch';
  FSearch.SetBounds(54, 12, 270, 30); FSearch.OnChange := @SearchChanged;
  FSearch.Hint := 'Find text (Ctrl+F); next (F3), previous (Shift+F3)'; FSearch.ShowHint := True;
  Button := TButton.Create(Self); Button.Parent := Bar; Button.Name := 'ManualPrevious';
  Button.Caption := 'Previous'; Button.SetBounds(334, 12, 90, 30); Button.OnClick := @PreviousClick;
  Button := TButton.Create(Self); Button.Parent := Bar; Button.Name := 'ManualNext';
  Button.Caption := 'Next'; Button.SetBounds(432, 12, 80, 30); Button.OnClick := @NextClick;
  FStatus := TLabel.Create(Self); FStatus.Parent := Bar; FStatus.Name := 'ManualMatchStatus';
  FStatus.SetBounds(524, 18, 220, 22); FStatus.AutoSize := True;
  FText := TMemo.Create(Self); FText.Parent := Self; FText.Name := 'ManualText';
  FText.Align := alClient; FText.ReadOnly := True; FText.ScrollBars := ssAutoBoth;
  FText.WordWrap := False; FText.HideSelection := False;
  FText.Font.Name := 'Monospace'; FText.Font.Size := 11;
  FText.Text := AppManualText;
  FMatchIndex := -1; ActiveControl := FSearch;
  FStatus.Caption := 'Ctrl+F to search';
  if AOwner is TCustomForm then CenterFormOnOwner(Self, TCustomForm(AOwner))
  else CenterFormOnPrimaryMonitor(Self);
end;
procedure TManualForm.SelectMatch(Index: Integer);
begin
  if Length(FMatches) = 0 then
  begin
    FMatchIndex := -1; FText.SelLength := 0;
    if FSearch.Text = '' then FStatus.Caption := 'Ctrl+F to search'
    else FStatus.Caption := 'No matches';
    Exit;
  end;
  FMatchIndex := (Index + Length(FMatches)) mod Length(FMatches);
  FText.SelStart := FMatches[FMatchIndex].Start;
  FText.SelLength := FMatches[FMatchIndex].Count;
  FStatus.Caption := Format('%d of %d matches', [FMatchIndex + 1, Length(FMatches)]);
end;
procedure TManualForm.SearchChanged(Sender: TObject);
begin FMatches := FindManualMatches(FText.Text, FSearch.Text); SelectMatch(0); end;
procedure TManualForm.NextClick(Sender: TObject);
begin SelectMatch(FMatchIndex + 1); end;
procedure TManualForm.PreviousClick(Sender: TObject);
begin SelectMatch(FMatchIndex - 1); end;
procedure TManualForm.Keys(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('F')) and (Shift = [ssCtrl]) then
  begin FSearch.SetFocus; FSearch.SelectAll; end
  else if ((Key = VK_F3) or (Key = VK_RETURN)) and (Shift = []) then NextClick(nil)
  else if (Key = VK_F3) and (Shift = [ssShift]) then PreviousClick(nil)
  else if (Key = VK_ESCAPE) and (Shift = []) then Close
  else Exit;
  Key := 0;
end;
end.
