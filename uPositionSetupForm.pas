unit uPositionSetupForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, ExtCtrls, Forms, Graphics, StdCtrls, SysUtils,
  uBoardControl, uDraughtsBoard, uGuiDialogs, uPreferences;

type
  TPositionSetupAcceptedEvent = procedure(Sender: TObject;
    const AFEN: string) of object;

  TPositionSetupForm = class(TForm)
  private
    FBoard: TDraughtsBoard;
    FBoardControl: TDraughtsBoardControl;
    FFenEdit: TEdit;
    FOnAccepted: TPositionSetupAcceptedEvent;
    FPaletteLabel: TLabel;
    FPalettePanel: TPanel;
    FPiecePaintBoxes: array[0..3] of TPaintBox;
    FSelectedPiece: TDraughtsPieceKind;
    FSideGroup: TRadioGroup;
    procedure ApplyClick(Sender: TObject);
    procedure BoardMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure CancelClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    function CurrentPiece: TDraughtsPieceKind;
    procedure FormResizeHandler(Sender: TObject);
    function PalettePiece(AIndex: Integer): TDraughtsPieceKind;
    procedure PiecePaletteClick(Sender: TObject);
    procedure PiecePalettePaint(Sender: TObject);
    procedure SetFenClick(Sender: TObject);
    procedure SetStartClick(Sender: TObject);
    procedure SideChange(Sender: TObject);
    procedure UpdateFenEdit;
    procedure UpdatePiecePalette;
    procedure UpdatePiecePaletteLayout;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyPreferences(const APreferences: TGuiPreferences);
    procedure StartSetup(const AFEN: string);
    property OnAccepted: TPositionSetupAcceptedEvent read FOnAccepted
      write FOnAccepted;
  end;

implementation

uses
  Math;

procedure ShrinkRect(var ARect: TRect; DX, DY: Integer);
begin
  Inc(ARect.Left, DX);
  Inc(ARect.Top, DY);
  Dec(ARect.Right, DX);
  Dec(ARect.Bottom, DY);
end;

constructor TPositionSetupForm.Create(AOwner: TComponent);
var
  LApplyButton: TButton;
  LBottomPanel: TPanel;
  LButton: TButton;
  LControlsPanel: TPanel;
  I: Integer;
begin
  inherited Create(AOwner);

  Caption := 'Setup position';
  Position := poDesigned;
  OnResize := @FormResizeHandler;
  Width := 520;
  Height := 620;
  Constraints.MinWidth := 520;
  Constraints.MinHeight := 420;

  FBoard := TDraughtsBoard.Create;
  FSelectedPiece := pkWhiteMan;

  LBottomPanel := TPanel.Create(Self);
  LBottomPanel.Parent := Self;
  LBottomPanel.Align := alBottom;
  LBottomPanel.Height := 40;
  LBottomPanel.BevelOuter := bvNone;
  LBottomPanel.BorderSpacing.Around := 6;

  LApplyButton := TButton.Create(Self);
  LApplyButton.Parent := LBottomPanel;
  LApplyButton.Align := alRight;
  LApplyButton.Width := 100;
  LApplyButton.Caption := 'Apply';
  LApplyButton.OnClick := @ApplyClick;

  LButton := TButton.Create(Self);
  LButton.Parent := LBottomPanel;
  LButton.Align := alRight;
  LButton.Width := 100;
  LButton.BorderSpacing.Right := 8;
  LButton.Caption := 'Cancel';
  LButton.OnClick := @CancelClick;

  LControlsPanel := TPanel.Create(Self);
  LControlsPanel.Parent := Self;
  LControlsPanel.Align := alTop;
  LControlsPanel.Height := 76;
  LControlsPanel.BevelOuter := bvNone;
  LControlsPanel.BorderSpacing.Around := 8;

  LButton := TButton.Create(Self);
  LButton.Parent := LControlsPanel;
  LButton.SetBounds(0, 8, 76, 24);
  LButton.Caption := 'Start';
  LButton.OnClick := @SetStartClick;

  LButton := TButton.Create(Self);
  LButton.Parent := LControlsPanel;
  LButton.SetBounds(84, 8, 76, 24);
  LButton.Caption := 'Clear';
  LButton.OnClick := @ClearClick;

  FFenEdit := TEdit.Create(Self);
  FFenEdit.Parent := LControlsPanel;
  FFenEdit.SetBounds(0, 42, 500, 24);
  FFenEdit.Anchors := [akTop, akLeft, akRight];

  LButton := TButton.Create(Self);
  LButton.Parent := LControlsPanel;
  LButton.SetBounds(512, 42, 96, 24);
  LButton.Anchors := [akTop, akRight];
  LButton.Caption := 'Paste FEN';
  LButton.OnClick := @SetFenClick;

  FPalettePanel := TPanel.Create(Self);
  FPalettePanel.Parent := Self;
  FPalettePanel.Align := alLeft;
  FPalettePanel.Width := 104;
  FPalettePanel.BevelOuter := bvNone;
  FPalettePanel.Color := clBtnFace;
  FPalettePanel.ParentColor := False;
  FPalettePanel.BorderSpacing.Left := 4;
  FPalettePanel.BorderSpacing.Right := 4;
  FPalettePanel.BorderSpacing.Bottom := 8;

  for I := 0 to High(FPiecePaintBoxes) do
  begin
    FPiecePaintBoxes[I] := TPaintBox.Create(Self);
    FPiecePaintBoxes[I].Parent := FPalettePanel;
    FPiecePaintBoxes[I].Height := 64;
    FPiecePaintBoxes[I].BorderSpacing.Left := 8;
    FPiecePaintBoxes[I].BorderSpacing.Right := 8;
    FPiecePaintBoxes[I].BorderSpacing.Bottom := 8;
    FPiecePaintBoxes[I].Tag := I;
    FPiecePaintBoxes[I].OnClick := @PiecePaletteClick;
    FPiecePaintBoxes[I].OnPaint := @PiecePalettePaint;
  end;

  FPaletteLabel := TLabel.Create(Self);
  FPaletteLabel.Parent := FPalettePanel;
  FPaletteLabel.Height := 24;
  FPaletteLabel.Caption := 'Pieces';
  FPaletteLabel.Alignment := taCenter;
  FPaletteLabel.Layout := tlCenter;
  FPaletteLabel.Color := clBtnFace;
  FPaletteLabel.ParentColor := False;

  FSideGroup := TRadioGroup.Create(Self);
  FSideGroup.Parent := FPalettePanel;
  FSideGroup.Height := 72;
  FSideGroup.Caption := 'Side to move';
  FSideGroup.Columns := 1;
  FSideGroup.Items.Add('White');
  FSideGroup.Items.Add('Black');
  FSideGroup.ItemIndex := 0;
  FSideGroup.BorderSpacing.Bottom := 8;
  FSideGroup.OnClick := @SideChange;

  FBoardControl := TDraughtsBoardControl.Create(Self);
  FBoardControl.Parent := Self;
  FBoardControl.Align := alClient;
  FBoardControl.Board := FBoard;
  FBoardControl.ShowSideToMoveMarker := True;
  FBoardControl.OnMouseDown := @BoardMouseDown;
  UpdatePiecePaletteLayout;
end;

destructor TPositionSetupForm.Destroy;
begin
  FBoard.Free;
  inherited Destroy;
end;

procedure TPositionSetupForm.ApplyPreferences(
  const APreferences: TGuiPreferences);
begin
  if FBoardControl = nil then
    Exit;
  FBoardControl.BoardLightColor := APreferences.MainBoardLightColor;
  FBoardControl.BoardDarkColor := APreferences.MainBoardDarkColor;
  FBoardControl.GridColor := APreferences.MainBoardDarkColor;
  FBoardControl.PvSourceSquareColor := APreferences.PvMoveColor;
  FBoardControl.HintSourceSquareColor := APreferences.HintMoveColor;
  FBoardControl.LastMoveTargetSquareColor := APreferences.LastMoveColor;
  FBoardControl.TargetSquareColor := APreferences.TargetSquareColor;
  UpdatePiecePalette;
end;

procedure TPositionSetupForm.StartSetup(const AFEN: string);
begin
  try
    FBoard.LoadFromFEN(AFEN);
  except
    FBoard.SetBeginPosition;
  end;
  if FBoard.SideToMove = dsBlack then
    FSideGroup.ItemIndex := 1
  else
    FSideGroup.ItemIndex := 0;
  UpdateFenEdit;
  UpdatePiecePalette;
  FBoardControl.Invalidate;
end;

function TPositionSetupForm.CurrentPiece: TDraughtsPieceKind;
begin
  Result := FSelectedPiece;
end;

procedure TPositionSetupForm.FormResizeHandler(Sender: TObject);
begin
  UpdatePiecePaletteLayout;
end;

function TPositionSetupForm.PalettePiece(AIndex: Integer): TDraughtsPieceKind;
begin
  case AIndex of
    0: Result := pkWhiteMan;
    1: Result := pkWhiteKing;
    2: Result := pkBlackMan;
    3: Result := pkBlackKing;
  else
    Result := pkWhiteMan;
  end;
end;

procedure TPositionSetupForm.PiecePaletteClick(Sender: TObject);
begin
  if Sender is TPaintBox then
  begin
    FSelectedPiece := PalettePiece(TPaintBox(Sender).Tag);
    UpdatePiecePalette;
  end;
end;

procedure TPositionSetupForm.PiecePalettePaint(Sender: TObject);
var
  Box: TPaintBox;
  CellSize: Integer;
  Piece: TDraughtsPieceKind;
  PieceRect: TRect;
  TextValue: string;
begin
  if not (Sender is TPaintBox) then
    Exit;

  Box := TPaintBox(Sender);
  CellSize := Min(Box.Width, Box.Height);
  Piece := PalettePiece(Box.Tag);
  Box.Canvas.Brush.Color := FBoardControl.BoardDarkColor;
  Box.Canvas.FillRect(Box.ClientRect);

  Box.Canvas.Pen.Color := clGray;
  Box.Canvas.Brush.Style := bsClear;
  Box.Canvas.Rectangle(Box.ClientRect);
  Box.Canvas.Brush.Style := bsSolid;

  PieceRect := Rect((Box.Width - CellSize) div 2, (Box.Height - CellSize) div 2,
    (Box.Width + CellSize) div 2, (Box.Height + CellSize) div 2);
  ShrinkRect(PieceRect, Max(4, CellSize div 8), Max(4, CellSize div 8));
  if PieceColor(Piece) = pcWhite then
  begin
    Box.Canvas.Brush.Color := RGBToColor(245, 241, 229);
    Box.Canvas.Pen.Color := RGBToColor(70, 70, 70);
  end
  else
  begin
    Box.Canvas.Brush.Color := RGBToColor(36, 37, 40);
    Box.Canvas.Pen.Color := RGBToColor(10, 10, 10);
  end;
  Box.Canvas.Ellipse(PieceRect);
  ShrinkRect(PieceRect, Max(2, CellSize div 12), Max(2, CellSize div 12));
  Box.Canvas.Brush.Style := bsClear;
  Box.Canvas.Pen.Color := RGBToColor(150, 132, 104);
  Box.Canvas.Ellipse(PieceRect);
  Box.Canvas.Brush.Style := bsSolid;

  if Piece in [pkWhiteKing, pkBlackKing] then
  begin
    Box.Canvas.Font.Style := [fsBold];
    Box.Canvas.Font.Size := Max(10, CellSize div 3);
    if PieceColor(Piece) = pcWhite then
      Box.Canvas.Font.Color := RGBToColor(50, 50, 50)
    else
      Box.Canvas.Font.Color := RGBToColor(235, 230, 220);
    TextValue := 'K';
    Box.Canvas.Brush.Style := bsClear;
    Box.Canvas.TextOut((Box.Width - Box.Canvas.TextWidth(TextValue)) div 2,
      (Box.Height - Box.Canvas.TextHeight(TextValue)) div 2, TextValue);
    Box.Canvas.Font.Style := [];
    Box.Canvas.Brush.Style := bsSolid;
  end;

  if Piece = FSelectedPiece then
  begin
    Box.Canvas.Pen.Color := clHighlight;
    Box.Canvas.Pen.Width := 4;
    Box.Canvas.Brush.Style := bsClear;
    Box.Canvas.Rectangle(Box.ClientRect);
    Box.Canvas.Pen.Width := 1;
    Box.Canvas.Brush.Style := bsSolid;
  end;
end;

procedure TPositionSetupForm.UpdateFenEdit;
begin
  FFenEdit.Text := FBoard.CurrentFEN;
end;

procedure TPositionSetupForm.SideChange(Sender: TObject);
begin
  if FSideGroup.ItemIndex = 1 then
    FBoard.SideToMove := dsBlack
  else
    FBoard.SideToMove := dsWhite;
  UpdateFenEdit;
  FBoardControl.Invalidate;
end;

procedure TPositionSetupForm.BoardMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LPiece: TDraughtsPieceKind;
  LSquare: Integer;
begin
  if Button <> mbLeft then
    Exit;
  LSquare := FBoardControl.SquareAtPoint(X, Y);
  if LSquare <= 0 then
    Exit;
  LPiece := CurrentPiece;
  if FBoard[LSquare] = LPiece then
    FBoard[LSquare] := pkEmpty
  else
    FBoard[LSquare] := LPiece;
  UpdateFenEdit;
  FBoardControl.Invalidate;
end;

procedure TPositionSetupForm.SetFenClick(Sender: TObject);
begin
  try
    FBoard.LoadFromFEN(Trim(FFenEdit.Text));
    if FBoard.SideToMove = dsBlack then
      FSideGroup.ItemIndex := 1
    else
      FSideGroup.ItemIndex := 0;
    UpdateFenEdit;
    FBoardControl.Invalidate;
  except
    on E: Exception do
      ShowGuiOkDialog(Self, 'Setup position', 'Invalid FEN: ' + E.Message);
  end;
end;

procedure TPositionSetupForm.SetStartClick(Sender: TObject);
begin
  FBoard.SetBeginPosition;
  FSideGroup.ItemIndex := 0;
  UpdateFenEdit;
  FBoardControl.Invalidate;
end;

procedure TPositionSetupForm.ClearClick(Sender: TObject);
begin
  FBoard.Clear;
  FSideGroup.ItemIndex := 0;
  UpdateFenEdit;
  FBoardControl.Invalidate;
end;

procedure TPositionSetupForm.UpdatePiecePalette;
var
  I: Integer;
begin
  for I := 0 to High(FPiecePaintBoxes) do
    if FPiecePaintBoxes[I] <> nil then
      FPiecePaintBoxes[I].Invalidate;
end;

procedure TPositionSetupForm.UpdatePiecePaletteLayout;
var
  I: Integer;
  PaletteWidth: Integer;
  SquareSize: Integer;
  SideMargin: Integer;
  TopPos: Integer;
begin
  if (FBoardControl = nil) or (FPalettePanel = nil) then
    Exit;

  SquareSize := Max(32, FBoardControl.BoardSquareSize);
  PaletteWidth := Max(SquareSize + 8, 96);
  SideMargin := Max(0, (PaletteWidth - SquareSize) div 2);
  FPalettePanel.Width := PaletteWidth;

  TopPos := 0;
  if FSideGroup <> nil then
  begin
    FSideGroup.SetBounds(0, TopPos, PaletteWidth, 72);
    Inc(TopPos, FSideGroup.Height + 8);
  end;
  if FPaletteLabel <> nil then
  begin
    FPaletteLabel.SetBounds(0, TopPos, PaletteWidth, 24);
    Inc(TopPos, FPaletteLabel.Height + 4);
  end;
  for I := 0 to High(FPiecePaintBoxes) do
    if FPiecePaintBoxes[I] <> nil then
    begin
      FPiecePaintBoxes[I].SetBounds(SideMargin, TopPos, SquareSize,
        SquareSize);
      Inc(TopPos, SquareSize + 8);
    end;
  UpdatePiecePalette;
end;

procedure TPositionSetupForm.ApplyClick(Sender: TObject);
begin
  if Assigned(FOnAccepted) then
    FOnAccepted(Self, FBoard.CurrentFEN);
  Hide;
end;

procedure TPositionSetupForm.CancelClick(Sender: TObject);
begin
  Hide;
end;

end.
