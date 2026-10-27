unit uGameNotationView;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Math, Graphics, SynEdit, SynEditWrappedView,
  uNotationPresentation, uNotationDocument, uNotationStyles, uNotationHighlighter;
type
  // Public selection offsets match the presenter's zero-based UTF-8 byte ranges.
  TGameNotationView = class(TSynEdit)
  private
    FDocument: TNotationDocument;
    FNotationHighlighter: TNotationRangeHighlighter;
    function GetByteStart: Integer;
    function GetByteLength: Integer;
    procedure SetByteStart(Value: Integer);
    procedure SetByteLength(Value: Integer);
    function GetNotationText: string;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetPresentation(Presenter: TNotationPresentation);
    procedure ApplyStyles(const Styles: TNotationStyles);
    property SelStart: Integer read GetByteStart write SetByteStart;
    property SelLength: Integer read GetByteLength write SetByteLength;
    property Text: string read GetNotationText;
    property Document: TNotationDocument read FDocument;
  end;
implementation
constructor TGameNotationView.Create(AOwner: TComponent);
begin
  inherited;
  FDocument := TNotationDocument.Create;
  FNotationHighlighter := TNotationRangeHighlighter.Create(Self);
  ReadOnly := True; Gutter.Visible := False; RightGutter.Visible := False;
  RightEdge := 0; HideSelection := False; WantTabs := False; Color := clWhite;
  ParentFont := False;
  {$IFDEF MSWINDOWS}Font.Name := 'Consolas';{$ELSE}Font.Name := 'DejaVu Sans Mono';{$ENDIF}
  Font.Size := 11;
  TLazSynEditLineWrapPlugin.Create(Self);
end;
destructor TGameNotationView.Destroy;
begin
  Highlighter := nil;
  inherited Destroy;
  FDocument.Free;
end;
procedure TGameNotationView.SetPresentation(Presenter: TNotationPresentation);
var LNeedsTextAssignment: Boolean;
begin
  LNeedsTextAssignment := FDocument.Text <> Presenter.Text;
  BeginUpdate;
  try
    Highlighter := nil;
    FDocument.UsePresentation(Presenter);
    FNotationHighlighter.Document := FDocument;
    if LNeedsTextAssignment then Lines.Text := FDocument.Text;
    Highlighter := FNotationHighlighter;
  finally EndUpdate; end;
end;
procedure TGameNotationView.ApplyStyles(const Styles: TNotationStyles);
begin FNotationHighlighter.ApplyStyles(Styles); Invalidate; end;
function TGameNotationView.GetNotationText: string;
begin Result := FDocument.Text; end;
function TGameNotationView.GetByteStart: Integer;
begin
  if FDocument.Text = '' then Exit(0);
  if SelAvail then Result := FDocument.PointOffset(BlockBegin)
  else Result := FDocument.PointOffset(LogicalCaretXY);
end;
function TGameNotationView.GetByteLength: Integer;
begin
  if not SelAvail then Exit(0);
  Result := FDocument.PointOffset(BlockEnd)-FDocument.PointOffset(BlockBegin);
end;
procedure TGameNotationView.SetByteStart(Value: Integer);
var P: TPoint;
begin
  Value := EnsureRange(Value, 0, Length(FDocument.Text));
  P := FDocument.LinePoint(Value);
  LogicalCaretXY := P; BlockBegin := P; BlockEnd := P;
  EnsureCursorPosVisible;
end;
procedure TGameNotationView.SetByteLength(Value: Integer);
begin
  BlockEnd := FDocument.LinePoint(EnsureRange(GetByteStart+Value, 0, Length(FDocument.Text)));
end;
end.
