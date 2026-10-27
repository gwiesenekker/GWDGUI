unit uNotationDocument;
{$mode objfpc}{$H+}
interface
uses SysUtils, Types, uNotationStyles, uGameTree, uGameTreePdn, uNotationPresentation;
type
  TNotationSpan = record Start, Len: Integer; Style: TNotationStyle; end;
  TNotationSpans = array of TNotationSpan;
  TIntMap = array of Integer;
  // Disposable styling and coordinate index over the authoritative presenter.
  TNotationDocument = class
  private
    FText: string;
    FStyles: array of TNotationStyle;
    FChars, FUtf16, FLines: TIntMap;
    FSpans: TNotationSpans;
    FPresenter: TNotationPresentation;
    FOwnsPresenter: Boolean;
    procedure Build;
    procedure Mark(Start, Len: Integer; Style: TNotationStyle);
  public
    constructor Create;
    destructor Destroy; override;
    procedure UsePresentation(Presenter: TNotationPresentation);
    procedure Render(Tree: TGameTree; const Options: TGameTreePdnRenderOptions);
    function NativeOffset(ByteOffset: Integer; Utf16, CRLF: Boolean): Integer;
    function NativeToByte(Native: Integer; Utf16, CRLF: Boolean): Integer;
    function LinePoint(ByteOffset: Integer): TPoint;
    function PointOffset(const Point: TPoint): Integer;
    // For positions coming from the control (caret, selection, clicks): clamps
    // the line to the document and the column to that line's text, so a click
    // right of a line's end or below the text maps to the nearest text offset.
    function ClampedPointOffset(const Point: TPoint): Integer;
    function StyleAt(ByteOffset: Integer): TNotationStyle;
    property Text: string read FText;
    property Spans: TNotationSpans read FSpans;
    property Presenter: TNotationPresentation read FPresenter;
  end;
implementation
constructor TNotationDocument.Create;
begin inherited; FPresenter := TNotationPresentation.Create; FOwnsPresenter := True; Build; end;
destructor TNotationDocument.Destroy;
begin if FOwnsPresenter then FPresenter.Free; inherited; end;
procedure TNotationDocument.Mark(Start, Len: Integer; Style: TNotationStyle);
var I: Integer;
begin
  for I := Start to Start + Len - 1 do
    if (I >= 0) and (I < Length(FStyles)) then FStyles[I] := Style;
end;
procedure TNotationDocument.Render(Tree: TGameTree;
  const Options: TGameTreePdnRenderOptions);
begin FPresenter.Render(Tree, Options); Build; end;
procedure TNotationDocument.UsePresentation(Presenter: TNotationPresentation);
begin
  if Presenter = FPresenter then begin Build; Exit; end;
  if FOwnsPresenter then FPresenter.Free;
  FOwnsPresenter := False; FPresenter := Presenter; Build;
end;
procedure TNotationDocument.Build;
var I, J, Chars, Units, Line, N: Integer; R: TNotationRange; H: TMoveVariationHit;
begin
  FText := FPresenter.Text;
  SetLength(FStyles, Length(FText));
  for I := 0 to High(FStyles) do FStyles[I] := nsComment;
  for I := 0 to FPresenter.MoveCount - 1 do
  begin R := FPresenter.MoveRanges[I]; Mark(R.Start, R.Length, nsPlayed); end;
  for I := 0 to FPresenter.VariationCount - 1 do
  begin
    H := FPresenter.VariationHits[I];
    if H.NodeId > 0 then Mark(H.Start, H.Length, nsVariation)
    else case H.AnalysisSource of
      nasEngine: Mark(H.Start, H.Length, nsEnginePV);
      nasAnnotator: Mark(H.Start, H.Length, nsAnnotatorPV);
      else Mark(H.Start, H.Length, nsAnalysis);
    end;
  end;
  SetLength(FSpans, 0);
  I := 0;
  while I < Length(FText) do
  begin
    J := I + 1;
    while (J < Length(FText)) and (FStyles[J] = FStyles[I]) do Inc(J);
    N := Length(FSpans); SetLength(FSpans, N + 1);
    FSpans[N].Start := I; FSpans[N].Len := J-I; FSpans[N].Style := FStyles[I];
    I := J;
  end;
  SetLength(FChars, Length(FText)+1); SetLength(FUtf16, Length(FText)+1);
  SetLength(FLines, 1); FLines[0] := 0;
  Chars := 0; Units := 0; Line := 0;
  for I := 0 to Length(FText) do
  begin
    FChars[I] := Chars; FUtf16[I] := Units;
    if I = Length(FText) then Break;
    if (Byte(FText[I+1]) and $C0) <> $80 then
    begin
      Inc(Chars); Inc(Units);
      if Byte(FText[I+1]) >= $F0 then Inc(Units);
    end;
    if FText[I+1] = #10 then
    begin Inc(Line); SetLength(FLines, Line+1); FLines[Line] := I+1; end;
  end;
end;
function TNotationDocument.LinePoint(ByteOffset: Integer): TPoint;
var L, H, M: Integer;
begin
  if (ByteOffset < 0) or (ByteOffset > Length(FText)) then raise ERangeError.Create('Byte offset');
  L := 0; H := High(FLines);
  while L < H do
  begin M := (L+H+1) div 2; if FLines[M] <= ByteOffset then L := M else H := M-1; end;
  Result := Point(ByteOffset-FLines[L]+1, L+1);
end;
function TNotationDocument.PointOffset(const Point: TPoint): Integer;
begin
  if (Point.Y < 1) or (Point.Y > Length(FLines)) then raise ERangeError.Create('Line');
  Result := FLines[Point.Y-1]+Point.X-1;
  if (Result < FLines[Point.Y-1]) or (Result > Length(FText)) then raise ERangeError.Create('Column');
end;
function TNotationDocument.ClampedPointOffset(const Point: TPoint): Integer;
var
  LLine, LStart, LEnd: Integer;
begin
  LLine := Point.Y;
  if LLine < 1 then LLine := 1;
  if LLine > Length(FLines) then LLine := Length(FLines);
  LStart := FLines[LLine - 1];
  // The line's text ends before its line break (#10, or #13#10).
  if LLine < Length(FLines) then
  begin
    LEnd := FLines[LLine] - 1;
    if (LEnd > LStart) and (FText[LEnd] = #13) then Dec(LEnd);
  end
  else
    LEnd := Length(FText);
  Result := LStart + Point.X - 1;
  if Result < LStart then Result := LStart;
  if Result > LEnd then Result := LEnd;
end;

function TNotationDocument.NativeOffset(ByteOffset: Integer; Utf16, CRLF: Boolean): Integer;
begin
  if (ByteOffset < 0) or (ByteOffset > Length(FText)) then raise ERangeError.Create('Byte offset');
  if Utf16 then Result := FUtf16[ByteOffset] else Result := FChars[ByteOffset];
  if CRLF then Inc(Result, LinePoint(ByteOffset).Y-1);
end;
function TNotationDocument.NativeToByte(Native: Integer; Utf16, CRLF: Boolean): Integer;
var L, H, M: Integer;
begin
  L := 0; H := Length(FText);
  while L < H do
  begin M := (L+H) div 2; if NativeOffset(M, Utf16, CRLF) < Native then L := M+1 else H := M; end;
  // UTF-8 continuation bytes share the previous character's end offset.
  while (L < Length(FText)) and ((Byte(FText[L+1]) and $C0) = $80) do Inc(L);
  Result := L;
end;
function TNotationDocument.StyleAt(ByteOffset: Integer): TNotationStyle;
begin
  if (ByteOffset < 0) or (ByteOffset >= Length(FStyles)) then Exit(nsComment);
  Result := FStyles[ByteOffset];
end;
end.
