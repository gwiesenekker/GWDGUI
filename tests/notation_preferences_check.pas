program notation_preferences_check;
{$mode objfpc}{$H+}{$codepage utf8}
uses {$IFDEF UNIX}cthreads, cwstring,{$ENDIF} Interfaces, Forms, Classes, SysUtils,
  StdCtrls, Controls, ComCtrls, Graphics, Types, LCLType, LMessages, uTreeTestUtils, uPreferences, uPreferencesForm,
  uNotationStyles, uNotationPresentation, uGameTree, uGameTreePdn, uGameNotationView,
  uNotationHighlighter;
type
  TReceiver = class
    Called: Boolean;
    Preferences: TGuiPreferences;
    View: TGameNotationView; Presenter: TNotationPresentation;
    ClickTarget: TNotationBrowseTarget; ClickCount: Integer;
    procedure Clicked(Sender: TObject);
    procedure Accepted(Sender: TObject; const P: TGuiPreferences);
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
    HadFile: Boolean; Lines: TStringList; Dialog: TPreferencesForm; Receiver: TReceiver;
    Host: TForm; View: TGameNotationView; Tree: TGameTree; Presenter: TNotationPresentation;
    Before, Expected: string; R: TNotationRange; Highlighter: TNotationRangeHighlighter;
    I: Integer; P, Pixel: TPoint; B: TCheckBox;
begin
  try
    RequireDerivedFormResource := False;
    Application.Initialize; Application.CaptureExceptions := False;
    Existing := TMemoryStream.Create; HadFile := FileExists(PreferencesJsonFileName);
    if HadFile then Existing.LoadFromFile(PreferencesJsonFileName);
    Dialog := nil; Receiver := nil; Host := nil; Tree := nil; Presenter := nil;
    try
      Prefs := DefaultGuiPreferences;
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
      Check(Loaded.MainBoardLightColor = Prefs.MainBoardLightColor, 'existing board preferences preserved');
      Lines := TStringList.Create;
      try
        Lines.Text := '{"main_board_light":"#123456","notation_1_color":"invalid","notation_1_bold":"invalid"}';
        Lines.SaveToFile(PreferencesJsonFileName); LoadGuiPreferences(Loaded);
        Check(Loaded.NotationStyles[nsPlayed].Bold, 'old/malformed style values retain defaults');
        Check(Loaded.NotationStyles[nsVariation].Italic, 'missing styles retain defaults');
        Check(Loaded.MainBoardLightColor = RGBToColor($12,$34,$56), 'legacy preferences still load');
      finally Lines.Free; end;
      Receiver := TReceiver.Create; Dialog := TPreferencesForm.Create(nil);
      Dialog.OnAccepted := @Receiver.Accepted; Dialog.StartEdit(Prefs);
      Check((Dialog.FindComponent('NotationTab') is TTabSheet) and
        (TTabSheet(Dialog.FindComponent('NotationTab')).Caption = 'Notation'), 'separate Notation tab');
      for S := Low(S) to High(S) do
      begin
        B := TCheckBox(Dialog.FindComponent('NotationBold'+IntToStr(Ord(S))));
        Check(B.Checked = Prefs.NotationStyles[S].Bold, 'edit opens with saved bold'); B.Checked := not B.Checked;
        B := TCheckBox(Dialog.FindComponent('NotationItalic'+IntToStr(Ord(S)))); B.Checked := not B.Checked;
      end;
      Check(not Receiver.Called, 'editing styles does not apply early');
      TButton(Dialog.FindComponent('PreferencesApply')).Click;
      Check(Receiver.Called, 'Apply callback');
      for S := Low(S) to High(S) do
        Check((Receiver.Preferences.NotationStyles[S].Bold <> Prefs.NotationStyles[S].Bold) and
          (Receiver.Preferences.NotationStyles[S].Italic <> Prefs.NotationStyles[S].Italic), 'Apply collects independent style choices');
      TButton(Dialog.FindComponent('PreferencesDefaults')).Click;
      TButton(Dialog.FindComponent('PreferencesApply')).Click;
      Check(Receiver.Preferences.NotationStyles[nsPlayed].Bold and
        Receiver.Preferences.NotationStyles[nsVariation].Italic and
        (Receiver.Preferences.NotationStyles[nsVariation].Color = $008000), 'Defaults restores styles');
      TTabSheet(Dialog.FindComponent('NotationTab')).PageControl.ActivePage := TTabSheet(Dialog.FindComponent('NotationTab'));
      Dialog.Hide;
      Host := TForm.CreateNew(nil); Host.SetBounds(30,30,600,400);
      View := TGameNotationView.Create(Host); View.Parent := Host; View.Align := alClient;
      Tree := TGameTree.Create; Presenter := TNotationPresentation.Create;
      Tree.RecordNodeAnnotation(Tree.Root, 'Gérard 棋 😀 é');
      Tree.RecordMainlineMove(1,'32-28'); Tree.RecordMainlineMove(2,'18-23');
      AddFixtureBranch(Tree, 0, '33-29 19-23', 'Variation comment');
      Tree.RecordEnginePV(0, '0.1', '31-26 19-23');
      Tree.RecordAnnotatorPV(0, '0.2', '34-29 20-25');
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
      View.ApplyStyles(Prefs.NotationStyles); Application.ProcessMessages;
      Check((View.SelStart = R.Start) and (View.SelText = Expected), 'style application preserves selection');
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
