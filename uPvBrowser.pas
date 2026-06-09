unit uPvBrowser;

{$mode objfpc}{$H+}

interface

uses
  Classes, LCLType, StdCtrls, SysUtils, uBoardControl, uDraughtsBoard,
  uPvSnapshot;

type
  TIntArray = array of Integer;

  TPvBrowser = class
  private
    FBaseBoard: TDraughtsBoard;
    FBasePly: Integer;
    FBoard: TDraughtsBoard;
    FBoardControl: TDraughtsBoardControl;
    FBrowsePly: Integer;
    FDepth: string;
    FInfoLabel: TLabel;
    FMoveLengths: TIntArray;
    FMoveStarts: TIntArray;
    FOnBoardChanged: TNotifyEvent;
    FPendingBaseBoard: TDraughtsBoard;
    FPendingBasePly: Integer;
    FPendingDepth: string;
    FPendingScore: string;
    FPendingStartingFEN: string;
    FPendingTimeText: string;
    FPendingVariation: string;
    FHasPendingData: Boolean;
    FPvMemo: TMemo;
    FScore: string;
    FStartingFEN: string;
    FTimeText: string;
    FVariation: string;
    procedure ApplyBrowsePly(APly: Integer);
    procedure ApplyPendingData;
    function FormatInfo: string;
    function MoveCount: Integer;
    procedure BuildMoveText(out AText: string; var AStarts,
      ALengths: TIntArray);
    procedure HighlightSelection(AFocusMemo: Boolean);
    procedure MemoClick(Sender: TObject);
    procedure MemoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure RenderBoard;
    procedure RenderMemo(const AText: string);
    procedure SetDataInternal(ABaseBoard: TDraughtsBoard; ABasePly: Integer;
      const AStartingFEN, APv, AScore, ADepth, ATimeText: string);
    procedure StorePendingData(ABaseBoard: TDraughtsBoard; ABasePly: Integer;
      const AStartingFEN, APv, AScore, ADepth, ATimeText: string);
    procedure UnlockUpdates;
  public
    constructor Create(ABoard: TDraughtsBoard; ABoardControl: TDraughtsBoardControl;
      AInfoLabel: TLabel; APvMemo: TMemo);
    destructor Destroy; override;

    procedure Clear;
    procedure SetSnapshot(ASnapshot: TPvSnapshot; const AStartingFEN: string);
    procedure SetData(ABaseBoard: TDraughtsBoard; ABasePly: Integer;
      const AStartingFEN, APv, AScore, ADepth, ATimeText: string);

    property PrincipalVariation: string read FVariation;
    property Score: string read FScore;
    property Depth: string read FDepth;
    property OnBoardChanged: TNotifyEvent read FOnBoardChanged write FOnBoardChanged;
    property TimeText: string read FTimeText;
  end;

implementation

function FenSideToMove(const AFEN: string): TDraughtsSide;
begin
  if (Trim(AFEN) <> '') and (UpCase(Trim(AFEN)[1]) = 'B') then
    Result := dsBlack
  else
    Result := dsWhite;
end;

function MoveSegmentText(APly, ADisplayedIndex: Integer; const AMove: string;
  AStartingSide: TDraughtsSide): string;
var
  LMoveNumber: Integer;
  LSide: TDraughtsSide;
  LPlyFromWhiteStart: Integer;
begin
  LPlyFromWhiteStart := APly;
  if AStartingSide = dsBlack then
    Inc(LPlyFromWhiteStart);
  LMoveNumber := ((LPlyFromWhiteStart - 1) div 2) + 1;
  if ((AStartingSide = dsWhite) and Odd(APly)) or
    ((AStartingSide = dsBlack) and (not Odd(APly))) then
    LSide := dsWhite
  else
    LSide := dsBlack;

  if LSide = dsWhite then
    Result := IntToStr(LMoveNumber) + '.' + AMove
  else if ADisplayedIndex = 0 then
    Result := IntToStr(LMoveNumber) + '...' + AMove
  else
    Result := AMove;
end;

procedure TextToMoveList(const AMovesText: string; AMoves: TStrings);
begin
  if AMoves = nil then
    Exit;
  AMoves.Clear;
  ExtractStrings([' ', #9, #10, #13], [], PChar(Trim(AMovesText)), AMoves);
end;

constructor TPvBrowser.Create(ABoard: TDraughtsBoard;
  ABoardControl: TDraughtsBoardControl; AInfoLabel: TLabel; APvMemo: TMemo);
begin
  inherited Create;
  FBaseBoard := TDraughtsBoard.Create;
  FPendingBaseBoard := TDraughtsBoard.Create;
  FBrowsePly := -1;
  FBoard := ABoard;
  FBoardControl := ABoardControl;
  FInfoLabel := AInfoLabel;
  FPvMemo := APvMemo;
  if FPvMemo <> nil then
  begin
    FPvMemo.OnClick := @MemoClick;
    FPvMemo.OnKeyDown := @MemoKeyDown;
  end;
  Clear;
end;

destructor TPvBrowser.Destroy;
begin
  FPendingBaseBoard.Free;
  FBaseBoard.Free;
  inherited Destroy;
end;

procedure TPvBrowser.Clear;
begin
  FBasePly := 0;
  FStartingFEN := '';
  FVariation := '';
  FScore := '';
  FDepth := '';
  FTimeText := '';
  FHasPendingData := False;
  FBrowsePly := -1;
  SetLength(FMoveStarts, 0);
  SetLength(FMoveLengths, 0);
  RenderMemo('No PV');
  RenderBoard;
  if FInfoLabel <> nil then
    FInfoLabel.Caption := FormatInfo;
  if (FBoardControl <> nil) then
    FBoardControl.Invalidate;
end;

function TPvBrowser.FormatInfo: string;
begin
  Result := 'PV:';
  if Trim(FScore) <> '' then
    Result += ' score ' + Trim(FScore);
  if Trim(FDepth) <> '' then
    Result += ' depth ' + Trim(FDepth);
  if Trim(FTimeText) <> '' then
    Result += ' time ' + Trim(FTimeText);
  if Result = 'PV:' then
    Result += ' no info';
end;

procedure TPvBrowser.BuildMoveText(out AText: string; var AStarts,
  ALengths: TIntArray);
var
  I: Integer;
  LMoves: TStringList;
  LSegment: string;
  LStartingSide: TDraughtsSide;
begin
  AText := '';
  SetLength(AStarts, 0);
  SetLength(ALengths, 0);

  LMoves := TStringList.Create;
  try
    TextToMoveList(FVariation, LMoves);
    if LMoves.Count = 0 then
    begin
      AText := 'No PV';
      Exit;
    end;

    SetLength(AStarts, LMoves.Count);
    SetLength(ALengths, LMoves.Count);
    LStartingSide := FenSideToMove(FStartingFEN);
    for I := 0 to LMoves.Count - 1 do
    begin
      if AText <> '' then
        AText += ' ';
      LSegment := MoveSegmentText(FBasePly + I + 1, I, LMoves[I],
        LStartingSide);
      AStarts[I] := Length(AText);
      ALengths[I] := Length(LSegment);
      AText += LSegment;
    end;
  finally
    LMoves.Free;
  end;
end;

procedure TPvBrowser.RenderBoard;
var
  I: Integer;
  LMoves: TStringList;
  LPly: Integer;
begin
  if FBoard = nil then
    Exit;

  FBoard.AssignFrom(FBaseBoard);
  LMoves := TStringList.Create;
  try
    TextToMoveList(FVariation, LMoves);
    LPly := FBrowsePly;
    if (LPly < 0) or (LPly > LMoves.Count) then
      LPly := LMoves.Count;
    for I := 0 to LPly - 1 do
      try
        FBoard.PlayMove(LMoves[I], True, False);
      except
        on E: Exception do
          Break;
      end;
  finally
    LMoves.Free;
  end;

  if FBoardControl <> nil then
    FBoardControl.Invalidate;
  if Assigned(FOnBoardChanged) then
    FOnBoardChanged(Self);
end;

procedure TPvBrowser.RenderMemo(const AText: string);
begin
  if FPvMemo = nil then
    Exit;
  FPvMemo.Lines.BeginUpdate;
  try
    FPvMemo.Text := AText;
  finally
    FPvMemo.Lines.EndUpdate;
  end;
  FPvMemo.SelLength := 0;
end;

function TPvBrowser.MoveCount: Integer;
var
  LMoves: TStringList;
begin
  LMoves := TStringList.Create;
  try
    TextToMoveList(FVariation, LMoves);
    Result := LMoves.Count;
  finally
    LMoves.Free;
  end;
end;

procedure TPvBrowser.HighlightSelection(AFocusMemo: Boolean);
begin
  if FPvMemo = nil then
    Exit;
  if (FBrowsePly > 0) and (FBrowsePly <= Length(FMoveStarts)) then
  begin
    FPvMemo.SelStart := FMoveStarts[FBrowsePly - 1];
    FPvMemo.SelLength := FMoveLengths[FBrowsePly - 1];
  end
  else
  begin
    FPvMemo.SelStart := 0;
    FPvMemo.SelLength := 0;
  end;
  if AFocusMemo and FPvMemo.CanFocus then
    FPvMemo.SetFocus;
end;

procedure TPvBrowser.ApplyBrowsePly(APly: Integer);
var
  LMoveCount: Integer;
begin
  LMoveCount := MoveCount;
  if APly < 0 then
    APly := 0
  else if APly > LMoveCount then
    APly := LMoveCount;
  FBrowsePly := APly;
  RenderBoard;
  HighlightSelection(True);
end;

procedure TPvBrowser.MemoClick(Sender: TObject);
var
  I: Integer;
  LPos: Integer;
begin
  if FPvMemo = nil then
    Exit;
  LPos := FPvMemo.SelStart;
  for I := 0 to High(FMoveStarts) do
    if (LPos >= FMoveStarts[I]) and
      (LPos <= FMoveStarts[I] + FMoveLengths[I]) then
    begin
      ApplyBrowsePly(I + 1);
      Exit;
    end;
end;

procedure TPvBrowser.MemoKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  LMoveCount: Integer;
  LPly: Integer;
begin
  if Key = VK_ESCAPE then
  begin
    UnlockUpdates;
    Key := 0;
  end
  else if Key = VK_LEFT then
  begin
    LMoveCount := MoveCount;
    if LMoveCount = 0 then
      Exit;
    if FBrowsePly < 0 then
      LPly := LMoveCount
    else
      LPly := FBrowsePly - 1;
    ApplyBrowsePly(LPly);
    Key := 0;
  end
  else if Key = VK_RIGHT then
  begin
    if MoveCount = 0 then
      Exit;
    if FBrowsePly < 0 then
      LPly := 1
    else
      LPly := FBrowsePly + 1;
    ApplyBrowsePly(LPly);
    Key := 0;
  end;
end;

procedure TPvBrowser.StorePendingData(ABaseBoard: TDraughtsBoard;
  ABasePly: Integer; const AStartingFEN, APv, AScore, ADepth,
  ATimeText: string);
begin
  if ABaseBoard <> nil then
    FPendingBaseBoard.AssignFrom(ABaseBoard);
  FPendingBasePly := ABasePly;
  FPendingStartingFEN := AStartingFEN;
  FPendingVariation := Trim(APv);
  FPendingScore := Trim(AScore);
  FPendingDepth := Trim(ADepth);
  FPendingTimeText := Trim(ATimeText);
  FHasPendingData := True;
end;

procedure TPvBrowser.ApplyPendingData;
begin
  if not FHasPendingData then
    Exit;
  FHasPendingData := False;
  SetDataInternal(FPendingBaseBoard, FPendingBasePly, FPendingStartingFEN,
    FPendingVariation, FPendingScore, FPendingDepth, FPendingTimeText);
end;

procedure TPvBrowser.UnlockUpdates;
begin
  FBrowsePly := -1;
  if FHasPendingData then
    ApplyPendingData
  else
  begin
    RenderBoard;
    HighlightSelection(True);
  end;
end;

procedure TPvBrowser.SetDataInternal(ABaseBoard: TDraughtsBoard;
  ABasePly: Integer; const AStartingFEN, APv, AScore, ADepth,
  ATimeText: string);
var
  LText: string;
begin
  if ABaseBoard <> nil then
    FBaseBoard.AssignFrom(ABaseBoard);
  FBasePly := ABasePly;
  FStartingFEN := AStartingFEN;
  FVariation := Trim(APv);
  FScore := Trim(AScore);
  FDepth := Trim(ADepth);
  FTimeText := Trim(ATimeText);

  if FInfoLabel <> nil then
    FInfoLabel.Caption := FormatInfo;
  BuildMoveText(LText, FMoveStarts, FMoveLengths);
  RenderMemo(LText);
  RenderBoard;
  HighlightSelection(False);
end;

procedure TPvBrowser.SetData(ABaseBoard: TDraughtsBoard; ABasePly: Integer;
  const AStartingFEN, APv, AScore, ADepth, ATimeText: string);
begin
  if FBrowsePly >= 0 then
    StorePendingData(ABaseBoard, ABasePly, AStartingFEN, APv, AScore, ADepth,
      ATimeText)
  else
    SetDataInternal(ABaseBoard, ABasePly, AStartingFEN, APv, AScore, ADepth,
      ATimeText);
end;

procedure TPvBrowser.SetSnapshot(ASnapshot: TPvSnapshot;
  const AStartingFEN: string);
begin
  if ASnapshot = nil then
    Clear
  else
    SetData(ASnapshot.BaseBoard, ASnapshot.BasePly, AStartingFEN,
      ASnapshot.PrincipalVariation, ASnapshot.Score, ASnapshot.Depth,
      ASnapshot.TimeText);
end;

end.
