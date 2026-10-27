unit uNotationHighlighter;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Graphics, SynEditHighlighter, uNotationDocument, uNotationStyles;
type
  TNotationRangeHighlighter = class(TSynCustomHighlighter)
  private
    FDoc: TNotationDocument;
    FPos, FNext, FOffset: Integer;
    // Own copy of the current line: TSynCustomHighlighter.CurrentLineText
    // only exists from Lazarus 4.x on.
    FLine: string;
    FAttributes: array[TNotationStyle] of TSynHighlighterAttributes;
  protected
    function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure ApplyStyles(const Styles: TNotationStyles);
    procedure SetLine(const NewValue: string; LineNumber: Integer); override;
    procedure Next; override;
    function GetEol: Boolean; override;
    function GetToken: string; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: Integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: Integer; override;
    function GetTokenPos: Integer; override;
    property Document: TNotationDocument read FDoc write FDoc;
  end;
implementation
constructor TNotationRangeHighlighter.Create(AOwner: TComponent);
var S: TNotationStyle;
begin
  inherited;
  for S := Low(S) to High(S) do
  begin
    FAttributes[S] := TSynHighlighterAttributes.Create('Notation '+IntToStr(Ord(S)), 'notation'+IntToStr(Ord(S)));
    AddAttribute(FAttributes[S]);
  end;
  ApplyStyles(DefaultNotationStyles);
end;
function TNotationRangeHighlighter.GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes;
begin
  // Default attributes are queried independently of token rendering by SynEdit.
  Result := FAttributes[nsComment];
end;
procedure TNotationRangeHighlighter.ApplyStyles(const Styles: TNotationStyles);
var S: TNotationStyle; FontStyle: TFontStyles;
begin
  BeginUpdate;
  try
    for S := Low(S) to High(S) do
    begin
      FontStyle := [];
      if Styles[S].Bold then Include(FontStyle, fsBold);
      if Styles[S].Italic then Include(FontStyle, fsItalic);
      FAttributes[S].Foreground := Styles[S].Color;
      FAttributes[S].Style := FontStyle;
    end;
  finally EndUpdate; end;
  DefHighlightChange(Self);
end;
procedure TNotationRangeHighlighter.SetLine(const NewValue: string; LineNumber: Integer);
begin
  inherited;
  FLine := NewValue;
  FOffset := 0;
  if Assigned(FDoc) then FOffset := FDoc.PointOffset(Point(1, LineNumber+1));
  FNext := 0; Next;
end;
procedure TNotationRangeHighlighter.Next;
var S: TNotationStyle;
begin
  FPos := FNext;
  if GetEol then Exit;
  // SynEdit wrapping expects a terminal NUL token before GetEol becomes true.
  if FPos = Length(FLine) then begin Inc(FNext); Exit; end;
  S := FDoc.StyleAt(FOffset+FPos); Inc(FNext);
  while (FNext < Length(FLine)) and
    (FDoc.StyleAt(FOffset+FNext) = S) do Inc(FNext);
end;
function TNotationRangeHighlighter.GetEol: Boolean;
begin Result := FPos > Length(FLine); end;
function TNotationRangeHighlighter.GetToken: string;
begin Result := Copy(FLine, FPos+1, FNext-FPos); end;
procedure TNotationRangeHighlighter.GetTokenEx(out TokenStart: PChar; out TokenLength: Integer);
begin TokenStart := PChar(FLine)+FPos; TokenLength := FNext-FPos; end;
function TNotationRangeHighlighter.GetTokenKind: Integer;
begin Result := Ord(FDoc.StyleAt(FOffset+FPos)); end;
function TNotationRangeHighlighter.GetTokenAttribute: TSynHighlighterAttributes;
begin Result := FAttributes[TNotationStyle(GetTokenKind)]; end;
function TNotationRangeHighlighter.GetTokenPos: Integer;
begin Result := FPos; end;
end.
