unit uManualHighlighter;

{$mode objfpc}{$H+}

{ SynEdit highlighter for the rendered manual: the style of every byte comes
  from TManualDocument, so the highlighter only cuts each line into runs of
  equal style. }

interface

uses
  Classes, SysUtils, Graphics, SynEditHighlighter, uManualDocument;

type
  TManualHighlighter = class(TSynCustomHighlighter)
  private
    FDocument: TManualDocument;
    FAttributes: array[TManualStyle] of TSynHighlighterAttributes;
    FLine: string;
    FOffset, FPos, FNext: Integer;
  protected
    function GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes; override;
  public
    constructor Create(AOwner: TComponent); override;
    procedure SetLine(const NewValue: string; LineNumber: Integer); override;
    procedure Next; override;
    function GetEol: Boolean; override;
    function GetToken: string; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: Integer); override;
    function GetTokenAttribute: TSynHighlighterAttributes; override;
    function GetTokenKind: Integer; override;
    function GetTokenPos: Integer; override;
    property Document: TManualDocument read FDocument write FDocument;
  end;

implementation

const
  StyleNames: array[TManualStyle] of string = ('Text', 'Title', 'Heading',
    'Subheading', 'Strong', 'Code', 'CodeBlock', 'TableHeader', 'Muted');

constructor TManualHighlighter.Create(AOwner: TComponent);
var
  S: TManualStyle;
  LCodeBackground: TColor;
begin
  inherited Create(AOwner);
  for S := Low(S) to High(S) do
  begin
    FAttributes[S] := TSynHighlighterAttributes.Create('Manual ' + StyleNames[S],
      'manual' + StyleNames[S]);
    AddAttribute(FAttributes[S]);
  end;
  LCodeBackground := RGBToColor(242, 242, 238);
  FAttributes[msText].Foreground := RGBToColor(32, 32, 32);
  FAttributes[msTitle].Foreground := RGBToColor(20, 55, 120);
  FAttributes[msTitle].Style := [fsBold];
  FAttributes[msHeading].Foreground := RGBToColor(25, 85, 160);
  FAttributes[msHeading].Style := [fsBold];
  FAttributes[msSubheading].Foreground := RGBToColor(20, 110, 115);
  FAttributes[msSubheading].Style := [fsBold];
  FAttributes[msStrong].Foreground := RGBToColor(0, 0, 0);
  FAttributes[msStrong].Style := [fsBold];
  FAttributes[msCode].Foreground := RGBToColor(150, 40, 40);
  FAttributes[msCode].Background := LCodeBackground;
  FAttributes[msCodeBlock].Foreground := RGBToColor(60, 60, 60);
  FAttributes[msCodeBlock].Background := LCodeBackground;
  FAttributes[msTableHeader].Foreground := RGBToColor(0, 0, 0);
  FAttributes[msTableHeader].Style := [fsBold];
  FAttributes[msMuted].Foreground := RGBToColor(150, 150, 150);
end;

function TManualHighlighter.GetDefaultAttribute(Index: Integer): TSynHighlighterAttributes;
begin
  Result := FAttributes[msText];
end;

procedure TManualHighlighter.SetLine(const NewValue: string; LineNumber: Integer);
begin
  inherited;
  FLine := NewValue;
  FOffset := 0;
  if Assigned(FDocument) and (LineNumber >= 0) and (LineNumber < FDocument.LineCount) then
    FOffset := FDocument.LineStart(LineNumber);
  FNext := 0;
  Next;
end;

procedure TManualHighlighter.Next;
var
  S: TManualStyle;
begin
  FPos := FNext;
  if GetEol then
    Exit;
  // SynEdit expects a terminal empty token before GetEol becomes true.
  if FPos = Length(FLine) then
  begin
    Inc(FNext);
    Exit;
  end;
  if not Assigned(FDocument) then
  begin
    FNext := Length(FLine);
    Exit;
  end;
  S := FDocument.StyleAt(FOffset + FPos);
  Inc(FNext);
  while (FNext < Length(FLine)) and (FDocument.StyleAt(FOffset + FNext) = S) do
    Inc(FNext);
end;

function TManualHighlighter.GetEol: Boolean;
begin
  Result := FPos > Length(FLine);
end;

function TManualHighlighter.GetToken: string;
begin
  Result := Copy(FLine, FPos + 1, FNext - FPos);
end;

procedure TManualHighlighter.GetTokenEx(out TokenStart: PChar; out TokenLength: Integer);
begin
  TokenStart := PChar(FLine) + FPos;
  TokenLength := FNext - FPos;
end;

function TManualHighlighter.GetTokenAttribute: TSynHighlighterAttributes;
begin
  Result := FAttributes[TManualStyle(GetTokenKind)];
end;

function TManualHighlighter.GetTokenKind: Integer;
begin
  if Assigned(FDocument) then
    Result := Ord(FDocument.StyleAt(FOffset + FPos))
  else
    Result := Ord(msText);
end;

function TManualHighlighter.GetTokenPos: Integer;
begin
  Result := FPos;
end;

end.
