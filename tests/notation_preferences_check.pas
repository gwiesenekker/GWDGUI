program notation_preferences_check;
{$mode objfpc}{$H+}{$codepage utf8}
uses {$IFDEF UNIX}cthreads, cwstring,{$ENDIF} Interfaces, Forms, Classes, SysUtils,
  StdCtrls, Controls, ComCtrls, Graphics, Types, LCLType, LMessages, uTreeTestUtils, uPreferences, uPreferencesForm,
  uNotationStyles, uNotationPresentation, uGameTree, uGameTreePdn, uGameNotationView,
  uNotationHighlighter, uDraughtsPosition;
type
  TFontChoicePreferences = class(TPreferencesForm)
  public
    AcceptFont: Boolean;
    ChosenName: string; ChosenSize: Integer;
  protected
    function SelectNotationFont(AFont: TFont): Boolean; override;
  end;
  TReceiver = class
    Called: Boolean;
    Preferences: TGuiPreferences;
    View: TGameNotationView; Presenter: TNotationPresentation;
    ClickTarget: TNotationBrowseTarget; ClickCount: Integer;
    procedure Clicked(Sender: TObject);
    procedure Accepted(Sender: TObject; const P: TGuiPreferences);
  end;
function TFontChoicePreferences.SelectNotationFont(AFont: TFont): Boolean;
begin
  AFont.Name := ChosenName; AFont.Size := ChosenSize;
  Result := AcceptFont;
end;
procedure TReceiver.Accepted(Sender: TObject; const P: TGuiPreferences);
begin Called := True; Preferences := P; end;
procedure TReceiver.Clicked(Sender: TObject);
begin
  Inc(ClickCount); ClickTarget := Presenter.HitTest(View.SelStart, View.SelLength, Default(TNotationSelection));
end;
procedure Check(B: Boolean; const S: string);
begin if not B then raise Exception.Create(S); end;
var Prefs, Loaded: TGuiPreferences; S: TNotationStyle; Existing: TMemoryStream;
    HadFile: Boolean; Lines: TStringList; Dialog: TFontChoicePreferences; Receiver: TReceiver;
    Host: TForm; View: TGameNotationView; Tree: TGameTree; Presenter: TNotationPresentation;
    Before, Expected: string; R: TNotationRange; Highlighter: TNotationRangeHighlighter;
    I, J, Offset: Integer; Hit: TMoveVariationHit; P, Pixel: TPoint; B: TCheckBox;
begin
  try
    RequireDerivedFormResource := False;
    Application.Initialize; Application.CaptureExceptions := False;
    Existing := TMemoryStream.Create; HadFile := FileExists(PreferencesJsonFileName);
    if HadFile then Existing.LoadFromFile(PreferencesJsonFileName);
    Dialog := nil; Receiver := nil; Host := nil; Tree := nil; Presenter := nil;
    try
      Prefs := DefaultGuiPreferences;
      Prefs.NotationFontName := 'Courier New'; Prefs.NotationFontSize := 15;
      for S := Low(S) to High(S) do
      begin
        Prefs.NotationStyles[S].Color := RGBToColor(30+Ord(S)*20, 60, 90);
        Prefs.NotationStyles[S].Bold := Odd(Ord(S));
        Prefs.NotationStyles[S].Italic := not Odd(Ord(S));
      end;
      SaveGuiPreferences(Prefs); LoadGuiPreferences(Loaded);
      for S := Low(S) to High(S) do
        Check((Loaded.NotationStyles[S].Color = Prefs.NotationStyles[S].Color) and
          (Loaded.NotationStyles[S].Bold = Prefs.NotationStyles[S].Bold) and
          (Loaded.NotationStyles[S].Italic = Prefs.NotationStyles[S].Italic), 'style persistence');
      Check((Loaded.NotationFontName = Prefs.NotationFontName) and
        (Loaded.NotationFontSize = Prefs.NotationFontSize), 'notation font persistence');
      Check(Loaded.MainBoardLightColor = Prefs.MainBoardLightColor, 'existing board preferences preserved');
      Lines := TStringList.Create;
      try
        Lines.Text := '{"main_board_light":"#123456","notation_1_color":"invalid","notation_1_bold":"invalid","notation_font_name":"  ","notation_font_size":-5}';
        Lines.SaveToFile(PreferencesJsonFileName); LoadGuiPreferences(Loaded);
        Check((Loaded.NotationFontName = DefaultNotationFontName) and
          (Loaded.NotationFontSize = DefaultNotationFontSize), 'invalid font settings retain defaults');
        Check(Loaded.NotationStyles[nsPlayed].Bold, 'old/malformed style values retain defaults');
        Check(Loaded.NotationStyles[nsVariation].Italic, 'missing styles retain defaults');
        Check(Loaded.MainBoardLightColor = RGBToColor($12,$34,$56), 'legacy preferences still load');
        Check(Loaded.NotationStyles[nsEnginePV].Color <> Loaded.NotationStyles[nsAnnotatorPV].Color,
          'distinct default PV colours for legacy default settings');
        Lines.Text := '{"notation_3_color":"#204060","notation_3_bold":true,"notation_5_color":"#aa00bb","notation_5_bold":false}';
        Lines.SaveToFile(PreferencesJsonFileName); LoadGuiPreferences(Loaded);
        Check((Loaded.NotationStyles[nsEnginePV].Color = RGBToColor($20,$40,$60)) and
          Loaded.NotationStyles[nsEnginePV].Bold, 'custom shared PV settings migrate to engine');
        Check((Loaded.NotationStyles[nsAnnotatorPV].Color = RGBToColor($aa,0,$bb)) and
          not Loaded.NotationStyles[nsAnnotatorPV].Bold, 'explicit annotator settings override legacy shared settings');
      finally Lines.Free; end;
      Receiver := TReceiver.Create; Dialog := TFontChoicePreferences.Create(nil);
      Dialog.OnAccepted := @Receiver.Accepted; Dialog.StartEdit(Prefs);
      Check((Dialog.FindComponent('NotationTab') is TTabSheet) and
        (TTabSheet(Dialog.FindComponent('NotationTab')).Caption = 'Notation'), 'separate Notation tab');
      for S := Low(S) to High(S) do
      begin
        B := TCheckBox(Dialog.FindComponent('NotationBold'+IntToStr(Ord(S))));
        Check(B.Checked = Prefs.NotationStyles[S].Bold, 'edit opens with saved bold'); B.Checked := not B.Checked;
        B := TCheckBox(Dialog.FindComponent('NotationItalic'+IntToStr(Ord(S)))); B.Checked := not B.Checked;
      end;
      Dialog.ChosenName := DefaultNotationFontName; Dialog.ChosenSize := 17;
      Dialog.AcceptFont := False;
      TButton(Dialog.FindComponent('NotationFontChoose')).Click;
      Check(Pos('Courier New, 15 pt', TLabel(Dialog.FindComponent('NotationFontSummary')).Caption) > 0,
        'cancelled font chooser preserves font');
      Check(not Receiver.Called, 'editing styles/font does not apply early');
      TButton(Dialog.FindComponent('PreferencesApply')).Click;
      Check(Receiver.Called, 'Apply callback');
      Check((Receiver.Preferences.NotationFontName = 'Courier New') and
        (Receiver.Preferences.NotationFontSize = 15), 'cancelled font choice cannot be saved');
      Dialog.AcceptFont := True;
      TButton(Dialog.FindComponent('NotationFontChoose')).Click;
      TButton(Dialog.FindComponent('PreferencesApply')).Click;
      Check((Receiver.Preferences.NotationFontName = DefaultNotationFontName) and
        (Receiver.Preferences.NotationFontSize = 17), 'accepted font chooser saves family and size');
      for S := Low(S) to High(S) do
        Check((Receiver.Preferences.NotationStyles[S].Bold <> Prefs.NotationStyles[S].Bold) and
          (Receiver.Preferences.NotationStyles[S].Italic <> Prefs.NotationStyles[S].Italic), 'Apply collects independent style choices');
      TButton(Dialog.FindComponent('PreferencesDefaults')).Click;
      TButton(Dialog.FindComponent('PreferencesApply')).Click;
      Check(Receiver.Preferences.NotationStyles[nsPlayed].Bold and
        Receiver.Preferences.NotationStyles[nsVariation].Italic and
        (Receiver.Preferences.NotationStyles[nsVariation].Color = $008000), 'Defaults restores styles');
      Check((Receiver.Preferences.NotationFontName = DefaultNotationFontName) and
        (Receiver.Preferences.NotationFontSize = DefaultNotationFontSize), 'Defaults restores notation font');
      TTabSheet(Dialog.FindComponent('NotationTab')).PageControl.ActivePage := TTabSheet(Dialog.FindComponent('NotationTab'));
      Dialog.Hide;
      Host := TForm.CreateNew(nil); Host.SetBounds(30,30,600,400);
      View := TGameNotationView.Create(Host); View.Parent := Host; View.Align := alClient;
      Tree := TGameTree.Create; Presenter := TNotationPresentation.Create;
      Tree.RecordNodeAnnotation(Tree.Root, 'Gérard 棋 😀 é');
      Tree.RecordMainlineMove(1,'32-28'); Tree.RecordMainlineMove(2,'18-23');
      AddFixtureBranch(Tree, 0, '33-29 19-23', 'Variation comment');
      Tree.RecordEnginePV(0, '0.1', '31-26 19-23');
      Tree.RecordAnnotatorPV(0, '0.1', '31-26 19-23');
      Before := GameTreeToPdnText(Tree);
      Presenter.Render(Tree, DefaultGameTreePdnRenderOptions); View.SetPresentation(Presenter);
      Host.Show; Application.ProcessMessages;
      R := Presenter.MoveRanges[1]; View.SelStart := R.Start; View.SelLength := R.Length;
      Expected := Copy(Presenter.Text,R.Start+1,R.Length);
      Check((View.SelStart = R.Start) and (View.SelText = Expected), 'UTF-8 byte ranges after non-BMP comments');
      Receiver.View := View; Receiver.Presenter := Presenter; View.OnClick := @Receiver.Clicked;
      Pixel := View.RowColumnToPixels(View.LogicalToPhysicalPos(View.Document.LinePoint(R.Start)));
      Inc(Pixel.X, 2); Inc(Pixel.Y, 2);
      View.Perform(LM_LBUTTONDOWN, 0, LPARAM((Pixel.Y shl 16) or (Pixel.X and $FFFF)));
      View.Perform(LM_LBUTTONUP, 0, LPARAM((Pixel.Y shl 16) or (Pixel.X and $FFFF)));
      Check((Receiver.ClickCount > 0) and (Receiver.ClickTarget.Kind = nbMainline) and
        (Receiver.ClickTarget.Ply = 2), 'native mouse click resolves the played move');
      View.SelStart := R.Start; View.SelLength := R.Length;
      View.ApplyAppearance(Prefs.NotationFontName, Prefs.NotationFontSize, Prefs.NotationStyles);
      Application.ProcessMessages;
      Check((View.Font.Name = Prefs.NotationFontName) and (View.Font.Size = Prefs.NotationFontSize),
        'chosen font applies to notation');
      Check((View.SelStart = R.Start) and (View.SelText = Expected), 'font/style application preserves selection');
      Receiver.ClickCount := 0;
      Pixel := View.RowColumnToPixels(View.LogicalToPhysicalPos(View.Document.LinePoint(R.Start)));
      Inc(Pixel.X, 2); Inc(Pixel.Y, 2);
      View.Perform(LM_LBUTTONDOWN, 0, LPARAM((Pixel.Y shl 16) or (Pixel.X and $FFFF)));
      View.Perform(LM_LBUTTONUP, 0, LPARAM((Pixel.Y shl 16) or (Pixel.X and $FFFF)));
      Check((Receiver.ClickCount > 0) and (Receiver.ClickTarget.Kind = nbMainline) and
        (Receiver.ClickTarget.Ply = 2), 'native move click remains correct after changing font');
      View.SelStart := R.Start; View.SelLength := R.Length;
      Highlighter := TNotationRangeHighlighter(View.Highlighter);
      Check((Highlighter.IdentifierAttribute <> nil) and (Highlighter.CommentAttribute <> nil) and
        (Highlighter.KeywordAttribute <> nil) and (Highlighter.StringAttribute <> nil) and
        (Highlighter.SymbolAttribute <> nil) and (Highlighter.WhitespaceAttribute <> nil),
        'SynEdit standard attribute queries must not call an abstract method');
      P := View.Document.LinePoint(R.Start); I := View.Document.PointOffset(Point(1,P.Y));
      Highlighter.SetLine(View.Lines[P.Y-1], P.Y-1);
      while (not Highlighter.GetEol) and (I+Highlighter.GetTokenPos < R.Start) do Highlighter.Next;
      Check((Highlighter.GetTokenAttribute.Foreground = Prefs.NotationStyles[nsPlayed].Color) and
        ((fsBold in Highlighter.GetTokenAttribute.Style) = Prefs.NotationStyles[nsPlayed].Bold) and
        ((fsItalic in Highlighter.GetTokenAttribute.Style) = Prefs.NotationStyles[nsPlayed].Italic), 'applied highlighter preferences');
      for J := 0 to Presenter.VariationCount-1 do
      begin
        Hit := Presenter.VariationHits[J];
        if Hit.AnalysisSource = nasEngine then S := nsEnginePV
        else if Hit.AnalysisSource = nasAnnotator then S := nsAnnotatorPV else Continue;
        P := View.Document.LinePoint(Hit.Start); Offset := View.Document.PointOffset(Point(1,P.Y));
        Highlighter.SetLine(View.Lines[P.Y-1], P.Y-1);
        while (not Highlighter.GetEol) and (Offset+Highlighter.GetTokenPos+Length(Highlighter.GetToken) <= Hit.Start) do Highlighter.Next;
        Check(Highlighter.GetTokenAttribute.Foreground = Prefs.NotationStyles[S].Color,
          'identical engine/annotator PVs receive independent colours');
        Check(((fsBold in Highlighter.GetTokenAttribute.Style) = Prefs.NotationStyles[S].Bold) and
          ((fsItalic in Highlighter.GetTokenAttribute.Style) = Prefs.NotationStyles[S].Italic),
          'source-specific bold/italic attributes');
      end;
      View.SetPresentation(Presenter);
      Check((View.Text = Presenter.Text) and (GameTreeToPdnText(Tree) = Before), 'styles cannot change notation/tree/export');
      Check((View.SelStart = R.Start) and (View.SelText = Expected), 'unchanged presentation preserves selection');
      View.ApplyStyles(DefaultNotationStyles);
      WriteLn('Notation preferences and SynEdit byte-range checks passed');
    finally
      Host.Free; Presenter.Free; Tree.Free; Dialog.Free; Receiver.Free;
      if HadFile then Existing.SaveToFile(PreferencesJsonFileName) else DeleteFile(PreferencesJsonFileName);
      Existing.Free;
    end;
  except on E: Exception do begin WriteLn(StdErr,E.ClassName,': ',E.Message); DumpExceptionBackTrace(StdErr); Halt(1); end; end;
end.
