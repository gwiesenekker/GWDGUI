unit uNotationControlPrototype;
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Controls, StdCtrls, Graphics, SynEdit,
  SynEditHighlighter, SynEditWrappedView, RichMemo, RichMemoFactory,
  uNotationDocument, uNotationStyles, uNotationPresentation, uNotationHighlighter;
type
  TPrototypeControlKind = (pcMemo, pcSynEdit, pcRichMemo);
  TNotationControlPrototype = class
  private
    FKind: TPrototypeControlKind;
    FControl: TWinControl;
    FDoc: TNotationDocument;
    FLoadedText, FLoadedSignature: string;
    FHighlighter: TNotationRangeHighlighter;
    function FontParams(Style: TNotationStyle): TFontParams;
    function NativePos(BytePos: Integer): Integer;
    function NativeToByte(Pos: Integer): Integer;
  public
    constructor Create(Owner: TComponent; Parent: TWinControl; Kind: TPrototypeControlKind);
    destructor Destroy; override;
    procedure Load(Doc: TNotationDocument);
    procedure Refresh(Doc: TNotationDocument);
    procedure SelectRange(Start, Len: Integer);
    function SelectionStart: Integer;
    function SelectedText: string;
    function ReadText: string;
    procedure CheckStyles;
    property Control: TWinControl read FControl;
    property Kind: TPrototypeControlKind read FKind;
  end;
const PrototypeNames: array[TPrototypeControlKind] of string = ('TMemo', 'TSynEdit', 'RichMemo');
implementation
{$IFDEF MSWINDOWS}uses Windows;{$ENDIF}
const StyleColors: array[TNotationStyle] of TColor = (clGray, clBlack, clGreen, clBlue);
      StyleFonts: array[TNotationStyle] of TFontStyles = ([fsItalic], [fsBold], [fsItalic], []);
constructor TNotationControlPrototype.Create(Owner: TComponent; Parent: TWinControl;
  Kind: TPrototypeControlKind);
var Syn: TSynEdit; Memo: TMemo; Rich: TRichMemo;
begin
  inherited Create;
  FKind := Kind;
  case Kind of
    pcMemo: begin
      Memo := TMemo.Create(Owner); FControl := Memo;
      Memo.ReadOnly := True; Memo.WordWrap := True;
      Memo.ScrollBars := ssVertical; Memo.HideSelection := False;
    end;
    pcSynEdit: begin
      Syn := TSynEdit.Create(Owner); FControl := Syn;
      Syn.ReadOnly := True; Syn.Gutter.Visible := False; Syn.RightGutter.Visible := False;
      Syn.ScrollBars := ssVertical;
      TLazSynEditLineWrapPlugin.Create(Syn);
      FHighlighter := TNotationRangeHighlighter.Create(Syn);
    end;
    pcRichMemo: begin
      Rich := TRichMemo.Create(Owner); FControl := Rich;
      Rich.ReadOnly := True; Rich.WordWrap := True;
      Rich.ScrollBars := ssVertical; Rich.HideSelection := False;
    end;
  end;
  FControl.Parent := Parent; FControl.Align := alClient;
  FControl.Color := clWhite;
  FControl.Font.Name := 'DejaVu Sans Mono'; FControl.Font.Size := 11;
end;
destructor TNotationControlPrototype.Destroy;
begin FControl.Free; inherited; end;
function TNotationControlPrototype.NativePos(BytePos: Integer): Integer;
begin
  Result := FDoc.NativeOffset(BytePos,
    {$IFDEF MSWINDOWS}True, FKind = pcMemo{$ELSE}False, False{$ENDIF});
end;
function TNotationControlPrototype.NativeToByte(Pos: Integer): Integer;
begin
  Result := FDoc.NativeToByte(Pos,
    {$IFDEF MSWINDOWS}True, FKind = pcMemo{$ELSE}False, False{$ENDIF});
end;
function TNotationControlPrototype.FontParams(Style: TNotationStyle): TFontParams;
begin
  Result := GetFontParams(FControl.Font.Name, 11, StyleColors[Style], StyleFonts[Style]);
end;
procedure TNotationControlPrototype.Load(Doc: TNotationDocument);
var S: TNotationSpan; Params: TFontParams; Syn: TSynEdit; Rich: TRichMemo;
begin
  FDoc := Doc;
  case FKind of
    pcMemo: TMemo(FControl).Text := Doc.Text;
    pcSynEdit: begin
      Syn := TSynEdit(FControl); Syn.BeginUpdate;
      try
        Syn.Highlighter := nil; FHighlighter.Document := Doc;
        Syn.Lines.Text := Doc.Text; Syn.Highlighter := FHighlighter;
      finally Syn.EndUpdate; end;
    end;
    pcRichMemo: begin
      Rich := TRichMemo(FControl); Rich.Lines.BeginUpdate;
      try
        Rich.Text := Doc.Text;
        for S in Doc.Spans do
        begin
          Params := FontParams(S.Style);
          Rich.SetTextAttributes(NativePos(S.Start), NativePos(S.Start+S.Len)-NativePos(S.Start), Params);
        end;
      finally Rich.Lines.EndUpdate; end;
    end;
  end;
  FLoadedText := Doc.Text; FLoadedSignature := Doc.Presenter.Signature;
end;
procedure TNotationControlPrototype.Refresh(Doc: TNotationDocument);
begin
  if (FLoadedText <> Doc.Text) or (FLoadedSignature <> Doc.Presenter.Signature) then Load(Doc)
  else begin FDoc := Doc; if FHighlighter <> nil then FHighlighter.Document := Doc; end;
end;
procedure TNotationControlPrototype.SelectRange(Start, Len: Integer);
var Syn: TSynEdit;
begin
  case FKind of
    pcSynEdit: begin
      Syn := TSynEdit(FControl);
      Syn.LogicalCaretXY := FDoc.LinePoint(Start);
      Syn.BlockBegin := FDoc.LinePoint(Start); Syn.BlockEnd := FDoc.LinePoint(Start+Len);
      Syn.EnsureCursorPosVisible;
    end;
    pcMemo: begin
      TMemo(FControl).SelStart := NativePos(Start);
      TMemo(FControl).SelLength := NativePos(Start+Len)-NativePos(Start);
    end;
    pcRichMemo: begin
      TRichMemo(FControl).SelStart := NativePos(Start);
      TRichMemo(FControl).SelLength := NativePos(Start+Len)-NativePos(Start);
      {$IFDEF MSWINDOWS}Windows.SendMessage(FControl.Handle, EM_SCROLLCARET, 0, 0);{$ENDIF}
    end;
  end;
end;
function TNotationControlPrototype.SelectionStart: Integer;
begin
  case FKind of
    pcSynEdit: Result := FDoc.PointOffset(TSynEdit(FControl).BlockBegin);
    pcMemo: Result := NativeToByte(TMemo(FControl).SelStart);
    pcRichMemo: Result := NativeToByte(TRichMemo(FControl).SelStart);
  end;
end;
function TNotationControlPrototype.SelectedText: string;
begin
  case FKind of
    pcSynEdit: Result := TSynEdit(FControl).SelText;
    pcMemo: Result := TMemo(FControl).SelText;
    pcRichMemo: Result := TRichMemo(FControl).SelText;
  end;
  Result := StringReplace(Result, #13#10, #10, [rfReplaceAll]);
end;
function TNotationControlPrototype.ReadText: string;
begin
  case FKind of
    pcSynEdit: Result := TSynEdit(FControl).Lines.Text;
    pcMemo: Result := TMemo(FControl).Text;
    pcRichMemo: Result := TRichMemo(FControl).Text;
  end;
  Result := StringReplace(Result, #13#10, #10, [rfReplaceAll]);
  // SynEdit's Lines.Text exposes an extra terminal line separator.
  if (FKind = pcSynEdit) and (Result = FDoc.Text+#10) then Delete(Result, Length(Result), 1);
end;
procedure TNotationControlPrototype.CheckStyles;
var S: TNotationSpan; Params: TFontParams; I, J, Offset: Integer;
begin
  if FKind = pcMemo then Exit;
  if FKind = pcSynEdit then
  begin
    for I := 0 to TSynEdit(FControl).Lines.Count-1 do
    begin
      FHighlighter.SetLine(TSynEdit(FControl).Lines[I], I);
      Offset := FDoc.PointOffset(Point(1, I+1));
      while not FHighlighter.GetEol do
      begin
        for J := 0 to Length(FHighlighter.GetToken)-1 do
          if FHighlighter.GetTokenKind <> Ord(FDoc.StyleAt(Offset+FHighlighter.GetTokenPos+J)) then
            raise Exception.Create('SynEdit token style mismatch');
        FHighlighter.Next;
      end;
    end;
    Exit;
  end;
  for S in FDoc.Spans do
    if FKind = pcRichMemo then
    begin
      if not TRichMemo(FControl).GetTextAttributes(NativePos(S.Start), Params) then
        raise Exception.Create('RichMemo cannot retrieve applied style');
      if (Params.Color <> StyleColors[S.Style]) or (Params.Style <> StyleFonts[S.Style]) then
        raise Exception.Create('RichMemo style mismatch at '+IntToStr(S.Start));
      if Params.Size <> FontParams(S.Style).Size then raise Exception.Create('RichMemo font size mismatch');
    end;
end;
end.
