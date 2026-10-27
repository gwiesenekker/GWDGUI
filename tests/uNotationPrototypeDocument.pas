unit uNotationPrototypeDocument;
{$mode objfpc}{$H+}
interface
uses SysUtils, Types, uGameTree, uGameTreePdn, uNotationPresentation;
type
  TNotationStyle = (nsComment, nsPlayed, nsVariation, nsAnalysis);
  TNotationSpan = record Start, Len: Integer; Style: TNotationStyle; end;
  TNotationSpans = array of TNotationSpan;
  TIntMap = array of Integer;
  // Test/prototype projection only. The production presenter remains authoritative.
  TNotationPrototypeDocument = class
  private
    FText: string;
    FStyles: array of TNotationStyle;
    FChars, FUtf16, FLines: TIntMap;
    FSpans: TNotationSpans;
    FPresenter: TNotationPresentation;
    procedure Mark(Start, Len: Integer; Style: TNotationStyle);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Render(Tree: TGameTree; const Options: TGameTreePdnRenderOptions);
    function NativeOffset(ByteOffset: Integer; Utf16, CRLF: Boolean): Integer;
    function NativeToByte(Native: Integer; Utf16, CRLF: Boolean): Integer;
    function LinePoint(ByteOffset: Integer): TPoint;
    function PointOffset(const Point: TPoint): Integer;
    function StyleAt(ByteOffset: Integer): TNotationStyle;
    property Text: string read FText;
    property Spans: TNotationSpans read FSpans;
    property Presenter: TNotationPresentation read FPresenter;
  end;
implementation
constructor TNotationPrototypeDocument.Create;
begin inherited; FPresenter := TNotationPresentation.Create; end;
destructor TNotationPrototypeDocument.Destroy;
begin FPresenter.Free; inherited; end;
procedure TNotationPrototypeDocument.Mark(Start, Len: Integer; Style: TNotationStyle);
var I: Integer;
begin
  for I := Start to Start + Len - 1 do
    if (I >= 0) and (I < Length(FStyles)) then FStyles[I] := Style;
end;
procedure TNotationPrototypeDocument.Render(Tree: TGameTree;
  const Options: TGameTreePdnRenderOptions);
var I, J, Chars, Units, Line, N: Integer; R: TNotationRange; H: TMoveVariationHit;
begin
  FPresenter.Render(Tree, Options);
  FText := FPresenter.Text;
  SetLength(FStyles, Length(FText));
  for I := 0 to High(FStyles) do FStyles[I] := nsComment;
  for I := 0 to FPresenter.MoveCount - 1 do
  begin R := FPresenter.MoveRanges[I]; Mark(R.Start, R.Length, nsPlayed); end;
  for I := 0 to FPresenter.VariationCount - 1 do
  begin
    H := FPresenter.VariationHits[I];
    if H.NodeId > 0 then Mark(H.Start, H.Length, nsVariation)
    else Mark(H.Start, H.Length, nsAnalysis);
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
function TNotationPrototypeDocument.LinePoint(ByteOffset: Integer): TPoint;
var L, H, M: Integer;
begin
  if (ByteOffset < 0) or (ByteOffset > Length(FText)) then raise ERangeError.Create('Byte offset');
  L := 0; H := High(FLines);
  while L < H do
  begin M := (L+H+1) div 2; if FLines[M] <= ByteOffset then L := M else H := M-1; end;
  Result := Point(ByteOffset-FLines[L]+1, L+1);
end;
function TNotationPrototypeDocument.PointOffset(const Point: TPoint): Integer;
begin
  if (Point.Y < 1) or (Point.Y > Length(FLines)) then raise ERangeError.Create('Line');
  Result := FLines[Point.Y-1]+Point.X-1;
  if (Result < FLines[Point.Y-1]) or (Result > Length(FText)) then raise ERangeError.Create('Column');
end;
function TNotationPrototypeDocument.NativeOffset(ByteOffset: Integer; Utf16, CRLF: Boolean): Integer;
begin
  if (ByteOffset < 0) or (ByteOffset > Length(FText)) then raise ERangeError.Create('Byte offset');
  if Utf16 then Result := FUtf16[ByteOffset] else Result := FChars[ByteOffset];
  if CRLF then Inc(Result, LinePoint(ByteOffset).Y-1);
end;
function TNotationPrototypeDocument.NativeToByte(Native: Integer; Utf16, CRLF: Boolean): Integer;
var L, H, M: Integer;
begin
  L := 0; H := Length(FText);
  while L < H do
  begin M := (L+H) div 2; if NativeOffset(M, Utf16, CRLF) < Native then L := M+1 else H := M; end;
  // UTF-8 continuation bytes share the previous character's end offset.
  while (L < Length(FText)) and ((Byte(FText[L+1]) and $C0) = $80) do Inc(L);
  Result := L;
end;
function TNotationPrototypeDocument.StyleAt(ByteOffset: Integer): TNotationStyle;
begin
  if (ByteOffset < 0) or (ByteOffset >= Length(FStyles)) then Exit(nsComment);
  Result := FStyles[ByteOffset];
end;
end.
