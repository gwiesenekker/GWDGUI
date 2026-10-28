unit uManualForm;
{$mode objfpc}{$H+}

{ Help window: the manual rendered for reading (uManualDocument) in a styled,
  read-only SynEdit, with a contents tree and text search. The layout follows
  the window width: paragraphs, lists and tables are wrapped again when the
  view is resized. }

interface

uses
  Classes, SysUtils, Types, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls,
  Graphics, LCLType, SynEdit, SynEditTypes, uManualDocument, uManualHighlighter;

type
  TManualForm = class(TForm)
  private
    FText: TSynEdit;
    FContents: TTreeView;
    FSearch: TEdit;
    FStatus: TLabel;
    FDocument: TManualDocument;
    FHighlighter: TManualHighlighter;
    FMatches: TManualMatches;
    FMatchIndex: Integer;
    FHeadingNodes: array of TTreeNode;
    FRenderedWidth: Integer;
    FSyncingContents: Boolean;
    procedure SearchChanged(Sender: TObject);
    procedure NextClick(Sender: TObject);
    procedure PreviousClick(Sender: TObject);
    procedure Keys(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ContentsChanged(Sender: TObject);
    procedure TextResized(Sender: TObject);
    procedure TextStatusChanged(Sender: TObject; Changes: TSynStatusChanges);
    procedure SelectMatch(Index: Integer);
    procedure BuildContents;
    procedure SyncContents;
    function HeadingAtLine(ALine: Integer): Integer;
    function ColumnsForWidth: Integer;
    function OffsetPoint(AOffset: Integer): TPoint;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    // Renders the manual for AColumns characters per line (also used by tests).
    procedure RenderForColumns(AColumns: Integer);
    // Shows the section of heading AIndex (TManualDocument.Headings) at the top.
    procedure ShowHeading(AIndex: Integer);
    property Document: TManualDocument read FDocument;
    property MatchIndex: Integer read FMatchIndex;
    property Matches: TManualMatches read FMatches;
  end;

implementation

uses
  uAppInfo, uGuiDialogs, uNotationStyles;

constructor TManualForm.Create(AOwner: TComponent);
var
  Bar: TPanel;
  LabelControl: TLabel;
  Button: TButton;
  Splitter: TSplitter;
begin
  inherited CreateNew(AOwner);
  Name := 'ManualWindow';
  Caption := 'GWDGUI Manual';
  Width := 1080;
  Height := 760;
  Constraints.MinWidth := 760;
  Constraints.MinHeight := 360;
  KeyPreview := True;
  OnKeyDown := @Keys;

  Bar := TPanel.Create(Self);
  Bar.Parent := Self;
  Bar.Align := alTop;
  Bar.Height := 54;
  Bar.BevelOuter := bvNone;
  LabelControl := TLabel.Create(Self);
  LabelControl.Parent := Bar;
  LabelControl.Caption := 'Find:';
  LabelControl.SetBounds(12, 18, 36, 22);
  FSearch := TEdit.Create(Self);
  FSearch.Parent := Bar;
  FSearch.Name := 'ManualSearch';
  FSearch.Text := ''; // naming a control also sets its text
  FSearch.SetBounds(54, 12, 270, 30);
  FSearch.OnChange := @SearchChanged;
  FSearch.Hint := 'Find text (Ctrl+F); next (F3), previous (Shift+F3)';
  FSearch.ShowHint := True;
  Button := TButton.Create(Self);
  Button.Parent := Bar;
  Button.Name := 'ManualPrevious';
  Button.Caption := 'Previous';
  Button.SetBounds(334, 12, 90, 30);
  Button.OnClick := @PreviousClick;
  Button := TButton.Create(Self);
  Button.Parent := Bar;
  Button.Name := 'ManualNext';
  Button.Caption := 'Next';
  Button.SetBounds(432, 12, 80, 30);
  Button.OnClick := @NextClick;
  FStatus := TLabel.Create(Self);
  FStatus.Parent := Bar;
  FStatus.Name := 'ManualMatchStatus';
  FStatus.SetBounds(524, 18, 220, 22);
  FStatus.AutoSize := True;

  FContents := TTreeView.Create(Self);
  FContents.Parent := Self;
  FContents.Name := 'ManualContents';
  FContents.Align := alLeft;
  FContents.Width := 330;
  FContents.ReadOnly := True;
  FContents.HideSelection := False;
  FContents.RowSelect := True;
  FContents.ShowRoot := True;
  // OnSelectionChanged fires at once; OnChange is delayed by a timer.
  FContents.OnSelectionChanged := @ContentsChanged;
  Splitter := TSplitter.Create(Self);
  Splitter.Parent := Self;
  Splitter.Align := alLeft;
  Splitter.Left := FContents.Width + 1;

  FDocument := TManualDocument.Create;
  FDocument.Load(AppManualText);
  FHighlighter := TManualHighlighter.Create(Self);
  FHighlighter.Document := FDocument;
  FText := TSynEdit.Create(Self);
  FText.Parent := Self;
  FText.Name := 'ManualText';
  FText.Align := alClient;
  FText.ReadOnly := True;
  FText.Gutter.Visible := False;
  FText.RightGutter.Visible := False;
  FText.RightEdge := 0;
  FText.Color := clWhite;
  FText.HideSelection := False;
  FText.WantTabs := False;
  FText.ScrollBars := ssAutoBoth;
  FText.Options := FText.Options - [eoScrollPastEol];
  FText.ParentFont := False;
  FText.Font.Name := DefaultNotationFontName;
  FText.Font.Size := DefaultNotationFontSize;
  FText.OnResize := @TextResized;
  FText.OnStatusChange := @TextStatusChanged;
  RenderForColumns(100);

  FMatchIndex := -1;
  ActiveControl := FSearch;
  FStatus.Caption := 'Ctrl+F to search';
  if AOwner is TCustomForm then
    CenterFormOnOwner(Self, TCustomForm(AOwner))
  else
    CenterFormOnPrimaryMonitor(Self);
end;

destructor TManualForm.Destroy;
begin
  if FText <> nil then
    FText.Highlighter := nil;
  inherited Destroy;
  FDocument.Free;
end;

function TManualForm.ColumnsForWidth: Integer;
var
  LCharWidth: Integer;
begin
  LCharWidth := FText.CharWidth;
  if LCharWidth <= 0 then
    Exit(100);
  // Leave room for the vertical scroll bar and a small right margin.
  Result := (FText.ClientWidth - 24) div LCharWidth - 1;
end;

procedure TManualForm.RenderForColumns(AColumns: Integer);
var
  LHeading, LOffsetInSection, LTopLine: Integer;
begin
  if AColumns < 30 then
    AColumns := 30;
  if (AColumns = FRenderedWidth) and (FText.Lines.Count > 0) then
    Exit;
  // Keep the section at the top of the view in place.
  LHeading := -1;
  LOffsetInSection := 0;
  if FText.Lines.Count > 0 then
  begin
    LTopLine := FText.TopLine - 1;
    LHeading := HeadingAtLine(LTopLine);
    if LHeading >= 0 then
      LOffsetInSection := LTopLine - FDocument.Headings[LHeading].Line;
  end;
  FRenderedWidth := AColumns;
  FHeadingNodes := nil; // stale until BuildContents
  FDocument.Render(AColumns);
  FText.BeginUpdate;
  try
    FText.Highlighter := nil;
    FText.Lines.Text := FDocument.Text;
    FText.Highlighter := FHighlighter;
  finally
    FText.EndUpdate;
  end;
  BuildContents;
  if FSearch.Text <> '' then
  begin
    FMatches := FindManualMatches(FDocument.Text, FSearch.Text);
    if FMatchIndex >= Length(FMatches) then
      FMatchIndex := 0;
  end;
  if LHeading >= 0 then
    FText.TopLine := FDocument.Headings[LHeading].Line + LOffsetInSection + 1
  else
    FText.TopLine := 1;
  SyncContents;
end;

procedure TManualForm.BuildContents;
var
  I: Integer;
  LParent: TTreeNode;
begin
  FSyncingContents := True;
  FContents.Items.BeginUpdate;
  try
    FContents.Items.Clear;
    SetLength(FHeadingNodes, Length(FDocument.Headings));
    LParent := nil;
    for I := 0 to High(FDocument.Headings) do
    begin
      FHeadingNodes[I] := nil;
      case FDocument.Headings[I].Level of
        1: ; // the title is the window itself
        2:
          begin
            LParent := FContents.Items.Add(nil, FDocument.Headings[I].Title);
            FHeadingNodes[I] := LParent;
          end;
      else
        FHeadingNodes[I] := FContents.Items.AddChild(LParent, FDocument.Headings[I].Title);
      end;
      if FHeadingNodes[I] <> nil then
        FHeadingNodes[I].Data := Pointer(PtrInt(I));
    end;
  finally
    FContents.Items.EndUpdate;
    FSyncingContents := False;
  end;
end;

function TManualForm.HeadingAtLine(ALine: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to High(FDocument.Headings) do
    if FDocument.Headings[I].Line <= ALine then
      Result := I
    else
      Break;
end;

procedure TManualForm.ShowHeading(AIndex: Integer);
var
  LLine: Integer;
begin
  if (AIndex < 0) or (AIndex > High(FDocument.Headings)) then
    Exit;
  LLine := FDocument.Headings[AIndex].Line + 1;
  FText.LogicalCaretXY := Point(1, LLine);
  FText.TopLine := LLine;
end;

procedure TManualForm.ContentsChanged(Sender: TObject);
begin
  if FSyncingContents or (FContents.Selected = nil) then
    Exit;
  FSyncingContents := True;
  try
    ShowHeading(PtrInt(FContents.Selected.Data));
  finally
    FSyncingContents := False;
  end;
end;

procedure TManualForm.SyncContents;
var
  I: Integer;
begin
  if FSyncingContents or (FText.Lines.Count = 0) or
    (Length(FHeadingNodes) <> Length(FDocument.Headings)) then
    Exit;
  I := HeadingAtLine(FText.TopLine - 1);
  while (I >= 0) and (FHeadingNodes[I] = nil) do
    Dec(I);
  if (I < 0) or (FContents.Selected = FHeadingNodes[I]) then
    Exit;
  FSyncingContents := True;
  try
    FContents.Selected := FHeadingNodes[I];
  finally
    FSyncingContents := False;
  end;
end;

procedure TManualForm.TextResized(Sender: TObject);
begin
  RenderForColumns(ColumnsForWidth);
end;

procedure TManualForm.TextStatusChanged(Sender: TObject; Changes: TSynStatusChanges);
begin
  if scTopLine in Changes then
    SyncContents;
end;

function TManualForm.OffsetPoint(AOffset: Integer): TPoint;
var
  LLine: Integer;
begin
  LLine := FDocument.LineOfOffset(AOffset);
  Result := Point(AOffset - FDocument.LineStart(LLine) + 1, LLine + 1);
end;

procedure TManualForm.SelectMatch(Index: Integer);
var
  LStart, LEnd: TPoint;
begin
  if Length(FMatches) = 0 then
  begin
    FMatchIndex := -1;
    FText.BlockBegin := FText.LogicalCaretXY;
    FText.BlockEnd := FText.LogicalCaretXY;
    if FSearch.Text = '' then
      FStatus.Caption := 'Ctrl+F to search'
    else
      FStatus.Caption := 'No matches';
    Exit;
  end;
  FMatchIndex := (Index + Length(FMatches)) mod Length(FMatches);
  LStart := OffsetPoint(FMatches[FMatchIndex].Start);
  LEnd := OffsetPoint(FMatches[FMatchIndex].Start + FMatches[FMatchIndex].Count);
  FText.LogicalCaretXY := LEnd;
  FText.BlockBegin := LStart;
  FText.BlockEnd := LEnd;
  // Show the match a little below the top rather than at the window edge.
  if (LStart.Y < FText.TopLine) or (LEnd.Y >= FText.TopLine + FText.LinesInWindow) then
    FText.TopLine := LStart.Y - FText.LinesInWindow div 3;
  FStatus.Caption := Format('%d of %d matches', [FMatchIndex + 1, Length(FMatches)]);
end;

procedure TManualForm.SearchChanged(Sender: TObject);
begin
  FMatches := FindManualMatches(FDocument.Text, FSearch.Text);
  SelectMatch(0);
end;

procedure TManualForm.NextClick(Sender: TObject);
begin
  SelectMatch(FMatchIndex + 1);
end;

procedure TManualForm.PreviousClick(Sender: TObject);
begin
  SelectMatch(FMatchIndex - 1);
end;

procedure TManualForm.Keys(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if (Key = Ord('F')) and (Shift = [ssCtrl]) then
  begin
    FSearch.SetFocus;
    FSearch.SelectAll;
  end
  else if ((Key = VK_F3) or (Key = VK_RETURN)) and (Shift = []) then
    NextClick(nil)
  else if (Key = VK_F3) and (Shift = [ssShift]) then
    PreviousClick(nil)
  else if (Key = VK_ESCAPE) and (Shift = []) then
    Close
  else
    Exit;
  Key := 0;
end;

end.
