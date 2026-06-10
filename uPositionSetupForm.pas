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
    FPieceCombo: TComboBox;
    FSideCombo: TComboBox;
    procedure ApplyClick(Sender: TObject);
    procedure BoardMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure CancelClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    function CurrentPiece: TDraughtsPieceKind;
    procedure SetFenClick(Sender: TObject);
    procedure SetStartClick(Sender: TObject);
    procedure SideChange(Sender: TObject);
    procedure UpdateFenEdit;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ApplyPreferences(const APreferences: TGuiPreferences);
    procedure StartSetup(const AFEN: string);
    property OnAccepted: TPositionSetupAcceptedEvent read FOnAccepted
      write FOnAccepted;
  end;

implementation

constructor TPositionSetupForm.Create(AOwner: TComponent);
var
  LApplyButton: TButton;
  LBottomPanel: TPanel;
  LButton: TButton;
  LControlsPanel: TPanel;
  LLabel: TLabel;
begin
  inherited Create(AOwner);

  Caption := 'Setup position';
  Position := poDesigned;
  Width := 620;
  Height := 620;
  Constraints.MinWidth := 420;
  Constraints.MinHeight := 420;

  FBoard := TDraughtsBoard.Create;

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
  LControlsPanel.Height := 92;
  LControlsPanel.BevelOuter := bvNone;
  LControlsPanel.BorderSpacing.Around := 8;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LControlsPanel;
  LLabel.SetBounds(0, 4, 84, 24);
  LLabel.Caption := 'Side';
  LLabel.Layout := tlCenter;

  FSideCombo := TComboBox.Create(Self);
  FSideCombo.Parent := LControlsPanel;
  FSideCombo.SetBounds(88, 4, 110, 24);
  FSideCombo.Style := csDropDownList;
  FSideCombo.Items.Add('White');
  FSideCombo.Items.Add('Black');
  FSideCombo.ItemIndex := 0;
  FSideCombo.OnChange := @SideChange;

  LLabel := TLabel.Create(Self);
  LLabel.Parent := LControlsPanel;
  LLabel.SetBounds(216, 4, 84, 24);
  LLabel.Caption := 'Piece';
  LLabel.Layout := tlCenter;

  FPieceCombo := TComboBox.Create(Self);
  FPieceCombo.Parent := LControlsPanel;
  FPieceCombo.SetBounds(300, 4, 130, 24);
  FPieceCombo.Style := csDropDownList;
  FPieceCombo.Items.Add('Empty');
  FPieceCombo.Items.Add('White man');
  FPieceCombo.Items.Add('White king');
  FPieceCombo.Items.Add('Black man');
  FPieceCombo.Items.Add('Black king');
  FPieceCombo.ItemIndex := 1;

  LButton := TButton.Create(Self);
  LButton.Parent := LControlsPanel;
  LButton.SetBounds(448, 4, 76, 24);
  LButton.Caption := 'Start';
  LButton.OnClick := @SetStartClick;

  LButton := TButton.Create(Self);
  LButton.Parent := LControlsPanel;
  LButton.SetBounds(532, 4, 76, 24);
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

  FBoardControl := TDraughtsBoardControl.Create(Self);
  FBoardControl.Parent := Self;
  FBoardControl.Align := alClient;
  FBoardControl.Board := FBoard;
  FBoardControl.ShowSideToMoveMarker := True;
  FBoardControl.OnMouseDown := @BoardMouseDown;
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
end;

procedure TPositionSetupForm.StartSetup(const AFEN: string);
begin
  try
    FBoard.LoadFromFEN(AFEN);
  except
    FBoard.SetBeginPosition;
  end;
  if FBoard.SideToMove = dsBlack then
    FSideCombo.ItemIndex := 1
  else
    FSideCombo.ItemIndex := 0;
  UpdateFenEdit;
  FBoardControl.Invalidate;
end;

function TPositionSetupForm.CurrentPiece: TDraughtsPieceKind;
begin
  case FPieceCombo.ItemIndex of
    1:
      Result := pkWhiteMan;
    2:
      Result := pkWhiteKing;
    3:
      Result := pkBlackMan;
    4:
      Result := pkBlackKing;
  else
    Result := pkEmpty;
  end;
end;

procedure TPositionSetupForm.UpdateFenEdit;
begin
  FFenEdit.Text := FBoard.CurrentFEN;
end;

procedure TPositionSetupForm.SideChange(Sender: TObject);
begin
  if FSideCombo.ItemIndex = 1 then
    FBoard.SideToMove := dsBlack
  else
    FBoard.SideToMove := dsWhite;
  UpdateFenEdit;
  FBoardControl.Invalidate;
end;

procedure TPositionSetupForm.BoardMouseDown(Sender: TObject;
  Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  LSquare: Integer;
begin
  if Button <> mbLeft then
    Exit;
  LSquare := FBoardControl.SquareAtPoint(X, Y);
  if LSquare <= 0 then
    Exit;
  FBoard[LSquare] := CurrentPiece;
  UpdateFenEdit;
  FBoardControl.Invalidate;
end;

procedure TPositionSetupForm.SetFenClick(Sender: TObject);
begin
  try
    FBoard.LoadFromFEN(Trim(FFenEdit.Text));
    if FBoard.SideToMove = dsBlack then
      FSideCombo.ItemIndex := 1
    else
      FSideCombo.ItemIndex := 0;
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
  FSideCombo.ItemIndex := 0;
  UpdateFenEdit;
  FBoardControl.Invalidate;
end;

procedure TPositionSetupForm.ClearClick(Sender: TObject);
begin
  FBoard.Clear;
  FSideCombo.ItemIndex := 0;
  UpdateFenEdit;
  FBoardControl.Invalidate;
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
