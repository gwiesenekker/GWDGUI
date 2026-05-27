unit SetupDialog;

{$mode objfpc}{$H+}

interface

uses
  Buttons,
  Classes,
  Controls,
  Dialogs,
  DraughtsRules,
  EasyLazFreeType,
  ExtCtrls,
  FPImage,
  Forms,
  GraphType,
  Graphics,
  IntfGraphics,
  LazFreeTypeFontCollection,
  LazFreeTypeIntfDrawer,
  StdCtrls;

type
  TSetupPositionDialog = class(TForm)
  private
    FBoard: TBoard;
    FBoardPaintBox: TPaintBox;
    FButtonPanel: TPanel;
    FCancelButton: TBitBtn;
    FClearButton: TButton;
    FOKButton: TBitBtn;
    FPalettePaintBox: TPaintBox;
    FPieceDrawer: TIntfFreeTypeDrawer;
    FPieceFont: TFreeTypeFont;
    FPieceImage: TLazIntfImage;
    FSelectedPiece: TPiece;
    FSideToMove: TSide;
    FSideToMoveCombo: TComboBox;
    procedure BoardPaintBoxClick(Sender: TObject);
    procedure BoardPaintBoxPaint(Sender: TObject);
    procedure ButtonClick(Sender: TObject);
    procedure ClearButtonClick(Sender: TObject);
    procedure DrawBoard(ACanvas: TCanvas; const ARect: TRect);
    procedure DrawPiece(ACanvas: TCanvas; const ARect: TRect; APiece: TPiece;
      ABackgroundColor: TColor);
    procedure PalettePaintBoxClick(Sender: TObject);
    procedure PalettePaintBoxPaint(Sender: TObject);
    procedure SetupPieceFont;
    procedure SideToMoveComboChange(Sender: TObject);
    function BoardSquareAt(X, Y: Integer): Integer;
    function CanPlacePiece(ASquare: Integer; APiece: TPiece): Boolean;
    function PalettePieceAt(X, Y: Integer): TPiece;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure SetPosition(const ABoard: TBoard; ASideToMove: TSide);
    property Board: TBoard read FBoard;
    property SideToMove: TSide read FSideToMove;
  end;

implementation

uses
  Math,
  SysUtils;

const
  BoardSize = 10;
  PaletteCount = 4;
  WoodSquareColor = TColor($00305E8B);
  SelectedColor = TColor($0000A5FF);

constructor TSetupPositionDialog.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);

  Caption := 'Setup Position';
  Width := 760;
  Height := 620;
  Position := poOwnerFormCenter;

  FSelectedPiece := pcWhiteMan;
  FSideToMove := sideWhite;

  FBoardPaintBox := TPaintBox.Create(Self);
  FBoardPaintBox.Parent := Self;
  FBoardPaintBox.Align := alClient;
  FBoardPaintBox.OnPaint := @BoardPaintBoxPaint;
  FBoardPaintBox.OnClick := @BoardPaintBoxClick;

  FButtonPanel := TPanel.Create(Self);
  FButtonPanel.Parent := Self;
  FButtonPanel.Align := alRight;
  FButtonPanel.Width := 190;
  FButtonPanel.BevelOuter := bvNone;
  FButtonPanel.BorderSpacing.Around := 8;

  FPalettePaintBox := TPaintBox.Create(FButtonPanel);
  FPalettePaintBox.Parent := FButtonPanel;
  FPalettePaintBox.Align := alTop;
  FPalettePaintBox.Height := 310;
  FPalettePaintBox.OnPaint := @PalettePaintBoxPaint;
  FPalettePaintBox.OnClick := @PalettePaintBoxClick;

  FSideToMoveCombo := TComboBox.Create(FButtonPanel);
  FSideToMoveCombo.Parent := FButtonPanel;
  FSideToMoveCombo.Align := alTop;
  FSideToMoveCombo.Style := csDropDownList;
  FSideToMoveCombo.Items.Add('White to move');
  FSideToMoveCombo.Items.Add('Black to move');
  FSideToMoveCombo.ItemIndex := 0;
  FSideToMoveCombo.BorderSpacing.Top := 8;
  FSideToMoveCombo.OnChange := @SideToMoveComboChange;

  FClearButton := TButton.Create(FButtonPanel);
  FClearButton.Parent := FButtonPanel;
  FClearButton.Align := alTop;
  FClearButton.Caption := 'Clear board';
  FClearButton.BorderSpacing.Top := 8;
  FClearButton.OnClick := @ClearButtonClick;

  FCancelButton := TBitBtn.Create(FButtonPanel);
  FCancelButton.Parent := FButtonPanel;
  FCancelButton.Align := alBottom;
  FCancelButton.Kind := bkCancel;
  FCancelButton.OnClick := @ButtonClick;

  FOKButton := TBitBtn.Create(FButtonPanel);
  FOKButton.Parent := FButtonPanel;
  FOKButton.Align := alBottom;
  FOKButton.Kind := bkOK;
  FOKButton.BorderSpacing.Bottom := 8;
  FOKButton.OnClick := @ButtonClick;

  SetupPieceFont;
end;

procedure TSetupPositionDialog.ButtonClick(Sender: TObject);
begin
  if Sender is TBitBtn then
    ModalResult := TBitBtn(Sender).ModalResult
  else
    ModalResult := mrCancel;
  Hide;
end;

destructor TSetupPositionDialog.Destroy;
begin
  FPieceFont.Free;
  FPieceDrawer.Free;
  FPieceImage.Free;
  inherited Destroy;
end;

procedure TSetupPositionDialog.SetPosition(const ABoard: TBoard; ASideToMove: TSide);
begin
  FBoard := ABoard;
  FSideToMove := ASideToMove;
  if FSideToMove = sideWhite then
    FSideToMoveCombo.ItemIndex := 0
  else
    FSideToMoveCombo.ItemIndex := 1;
  FBoardPaintBox.Invalidate;
end;

procedure TSetupPositionDialog.SetupPieceFont;
var
  FontFileName: String;
  FontFamilyName: String;
begin
  FontFileName := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'draughts.ttf';
  if not FileExists(FontFileName) then
    FontFileName := 'draughts.ttf';

  FPieceImage := TLazIntfImage.Create(0, 0, [riqfRGB]);
  FPieceDrawer := TIntfFreeTypeDrawer.Create(FPieceImage);

  if FileExists(FontFileName) then
  begin
    FontFamilyName := FontCollection.AddFile(FontFileName).Family.FamilyName;
    FPieceFont := TFreeTypeFont.Create;
    FPieceFont.Name := FontFamilyName;
    FPieceFont.Hinted := True;
    FPieceFont.ClearType := True;
    FPieceFont.Quality := grqHighQuality;
    FPieceFont.SmallLinePadding := False;
  end;
end;

procedure TSetupPositionDialog.BoardPaintBoxPaint(Sender: TObject);
begin
  DrawBoard(FBoardPaintBox.Canvas, FBoardPaintBox.ClientRect);
end;

procedure TSetupPositionDialog.DrawBoard(ACanvas: TCanvas; const ARect: TRect);
var
  BoardPixels: Integer;
  CellSize: Integer;
  Col: Integer;
  LeftPos: Integer;
  PiecePosition: Integer;
  Row: Integer;
  SquareColor: TColor;
  SquareRect: TRect;
  TopPos: Integer;
begin
  ACanvas.Brush.Color := clBtnFace;
  ACanvas.FillRect(ARect);

  BoardPixels := Min(ARect.Right - ARect.Left - 24, ARect.Bottom - ARect.Top - 24);
  CellSize := BoardPixels div BoardSize;
  BoardPixels := CellSize * BoardSize;
  LeftPos := ARect.Left + ((ARect.Right - ARect.Left - BoardPixels) div 2);
  TopPos := ARect.Top + ((ARect.Bottom - ARect.Top - BoardPixels) div 2);

  for Row := 0 to BoardSize - 1 do
    for Col := 0 to BoardSize - 1 do
    begin
      if Odd(Row + Col) then
        SquareColor := WoodSquareColor
      else
        SquareColor := clWhite;

      SquareRect := Rect(LeftPos + (Col * CellSize), TopPos + (Row * CellSize),
        LeftPos + ((Col + 1) * CellSize), TopPos + ((Row + 1) * CellSize));
      ACanvas.Brush.Color := SquareColor;
      ACanvas.FillRect(SquareRect);

      if Odd(Row + Col) then
      begin
        PiecePosition := (Row * 5) + (Col div 2) + 1;
        DrawPiece(ACanvas, SquareRect, FBoard[PiecePosition], SquareColor);
      end;
    end;

  ACanvas.Pen.Color := clBlack;
  ACanvas.Pen.Width := 2;
  ACanvas.Brush.Style := bsClear;
  ACanvas.Rectangle(Rect(LeftPos, TopPos, LeftPos + BoardPixels, TopPos + BoardPixels));
  ACanvas.Brush.Style := bsSolid;
end;

procedure TSetupPositionDialog.DrawPiece(ACanvas: TCanvas; const ARect: TRect;
  APiece: TPiece; ABackgroundColor: TColor);
var
  Bitmap: TBitmap;
  Glyph: String;
  MainColor: TFPColor;
  Offset: Integer;
  OutlineColor: TFPColor;
  Size: Integer;
  TextX: Single;
  TextY: Single;
begin
  if (APiece = pcNone) or (FPieceFont = nil) then
    Exit;

  if APiece in [pcWhiteKing, pcBlackKing] then
    Glyph := 'b'
  else
    Glyph := 'g';

  Size := Min(ARect.Right - ARect.Left, ARect.Bottom - ARect.Top);
  if (FPieceImage.Width <> Size) or (FPieceImage.Height <> Size) then
    FPieceImage.SetSize(Size, Size);

  FPieceDrawer.FillPixels(TColorToFPColor(ABackgroundColor));
  FPieceFont.SizeInPixels := Size * 0.78;
  TextX := Size / 2;
  TextY := Size / 2;
  Offset := Max(1, Size div 30);

  if APiece in [pcWhiteMan, pcWhiteKing] then
  begin
    MainColor := TColorToFPColor(clWhite);
    OutlineColor := TColorToFPColor(clBlack);
  end
  else
  begin
    MainColor := TColorToFPColor(clBlack);
    OutlineColor := TColorToFPColor(clWhite);
  end;

  FPieceDrawer.DrawText(Glyph, FPieceFont, TextX - Offset, TextY, OutlineColor,
    [ftaCenter, ftaVerticalCenter]);
  FPieceDrawer.DrawText(Glyph, FPieceFont, TextX + Offset, TextY, OutlineColor,
    [ftaCenter, ftaVerticalCenter]);
  FPieceDrawer.DrawText(Glyph, FPieceFont, TextX, TextY - Offset, OutlineColor,
    [ftaCenter, ftaVerticalCenter]);
  FPieceDrawer.DrawText(Glyph, FPieceFont, TextX, TextY + Offset, OutlineColor,
    [ftaCenter, ftaVerticalCenter]);
  FPieceDrawer.DrawText(Glyph, FPieceFont, TextX, TextY, MainColor,
    [ftaCenter, ftaVerticalCenter]);

  Bitmap := TBitmap.Create;
  try
    Bitmap.LoadFromIntfImage(FPieceImage);
    ACanvas.StretchDraw(ARect, Bitmap);
  finally
    Bitmap.Free;
  end;
end;

function TSetupPositionDialog.BoardSquareAt(X, Y: Integer): Integer;
var
  BoardPixels: Integer;
  CellSize: Integer;
  Col: Integer;
  LeftPos: Integer;
  Row: Integer;
  TopPos: Integer;
begin
  BoardPixels := Min(FBoardPaintBox.ClientWidth - 24, FBoardPaintBox.ClientHeight - 24);
  CellSize := BoardPixels div BoardSize;
  BoardPixels := CellSize * BoardSize;
  LeftPos := (FBoardPaintBox.ClientWidth - BoardPixels) div 2;
  TopPos := (FBoardPaintBox.ClientHeight - BoardPixels) div 2;

  Col := (X - LeftPos) div CellSize;
  Row := (Y - TopPos) div CellSize;
  if (X < LeftPos) or (Y < TopPos) or (Col < 0) or (Col >= BoardSize) or
    (Row < 0) or (Row >= BoardSize) or (not Odd(Row + Col)) then
    Exit(0);

  Result := (Row * 5) + (Col div 2) + 1;
end;

function TSetupPositionDialog.CanPlacePiece(ASquare: Integer; APiece: TPiece): Boolean;
var
  Row: Integer;
begin
  Row := (ASquare - 1) div 5;
  case APiece of
    pcWhiteMan: Result := Row <> 0;
    pcBlackMan: Result := Row <> 9;
  else
    Result := True;
  end;
end;

procedure TSetupPositionDialog.BoardPaintBoxClick(Sender: TObject);
var
  Square: Integer;
begin
  Square := BoardSquareAt(FBoardPaintBox.ScreenToClient(Mouse.CursorPos).X,
    FBoardPaintBox.ScreenToClient(Mouse.CursorPos).Y);
  if Square = 0 then
    Exit;

  if FBoard[Square] = FSelectedPiece then
    FBoard[Square] := pcNone
  else if CanPlacePiece(Square, FSelectedPiece) then
    FBoard[Square] := FSelectedPiece;
  FBoardPaintBox.Invalidate;
end;

function TSetupPositionDialog.PalettePieceAt(X, Y: Integer): TPiece;
var
  Index: Integer;
  SlotHeight: Integer;
begin
  SlotHeight := FPalettePaintBox.Height div PaletteCount;
  if SlotHeight <= 0 then
    Exit(pcNone);

  Index := Y div SlotHeight;
  case Index of
    0: Result := pcWhiteMan;
    1: Result := pcWhiteKing;
    2: Result := pcBlackMan;
    3: Result := pcBlackKing;
  else
    Result := pcNone;
  end;
end;

procedure TSetupPositionDialog.PalettePaintBoxClick(Sender: TObject);
var
  Piece: TPiece;
begin
  Piece := PalettePieceAt(FPalettePaintBox.ScreenToClient(Mouse.CursorPos).X,
    FPalettePaintBox.ScreenToClient(Mouse.CursorPos).Y);
  if Piece <> pcNone then
  begin
    FSelectedPiece := Piece;
    FPalettePaintBox.Invalidate;
  end;
end;

procedure TSetupPositionDialog.PalettePaintBoxPaint(Sender: TObject);
const
  Pieces: array[0..PaletteCount - 1] of TPiece =
    (pcWhiteMan, pcWhiteKing, pcBlackMan, pcBlackKing);
var
  I: Integer;
  PieceRect: TRect;
  SlotHeight: Integer;
begin
  FPalettePaintBox.Canvas.Brush.Color := clBtnFace;
  FPalettePaintBox.Canvas.FillRect(FPalettePaintBox.ClientRect);

  SlotHeight := FPalettePaintBox.Height div PaletteCount;
  for I := 0 to PaletteCount - 1 do
  begin
    PieceRect := Rect(24, (I * SlotHeight) + 8, 104, ((I + 1) * SlotHeight) - 8);

    if Pieces[I] = FSelectedPiece then
    begin
      FPalettePaintBox.Canvas.Brush.Color := SelectedColor;
      FPalettePaintBox.Canvas.Pen.Color := clBlack;
      FPalettePaintBox.Canvas.Rectangle(Rect(12, I * SlotHeight + 4,
        FPalettePaintBox.Width - 12, (I + 1) * SlotHeight - 4));
    end;

    DrawPiece(FPalettePaintBox.Canvas, PieceRect, Pieces[I], clWhite);
  end;
end;

procedure TSetupPositionDialog.ClearButtonClick(Sender: TObject);
var
  Square: Integer;
begin
  for Square := Low(FBoard) to High(FBoard) do
    FBoard[Square] := pcNone;
  FBoardPaintBox.Invalidate;
end;

procedure TSetupPositionDialog.SideToMoveComboChange(Sender: TObject);
begin
  if FSideToMoveCombo.ItemIndex = 0 then
    FSideToMove := sideWhite
  else
    FSideToMove := sideBlack;
end;

end.
