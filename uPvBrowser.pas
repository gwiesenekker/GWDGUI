unit uPvBrowser;

{$mode objfpc}{$H+}

interface

uses
  Classes, StdCtrls, SysUtils, uBoardControl, uDraughtsBoard,
  uPvSnapshot;

type
  TPvBrowser = class
  private
    FBaseBoard: TDraughtsBoard;
    FBasePly: Integer;
    FBoard: TDraughtsBoard;
    FBoardControl: TDraughtsBoardControl;
    FDepth: string;
    FInfoLabel: TLabel;
    FOnBoardChanged: TNotifyEvent;
    FPvMemo: TMemo;
    FScore: string;
    FStartingFEN: string;
    FTimeText: string;
    FVariation: string;
    function FormatInfo: string;
    procedure BuildMoveText(out AText: string);
    procedure RenderBoard;
    procedure RenderMemo(const AText: string);
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
  FBoard := ABoard;
  FBoardControl := ABoardControl;
  FInfoLabel := AInfoLabel;
  FPvMemo := APvMemo;
  Clear;
end;

destructor TPvBrowser.Destroy;
begin
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

procedure TPvBrowser.BuildMoveText(out AText: string);
var
  I: Integer;
  LMoves: TStringList;
  LSegment: string;
  LStartingSide: TDraughtsSide;
begin
  AText := '';

  LMoves := TStringList.Create;
  try
    TextToMoveList(FVariation, LMoves);
    if LMoves.Count = 0 then
    begin
      AText := 'No PV';
      Exit;
    end;

    LStartingSide := FenSideToMove(FStartingFEN);
    for I := 0 to LMoves.Count - 1 do
    begin
      if AText <> '' then
        AText += ' ';
      LSegment := MoveSegmentText(FBasePly + I + 1, I, LMoves[I],
        LStartingSide);
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
begin
  if FBoard = nil then
    Exit;

  FBoard.AssignFrom(FBaseBoard);
  LMoves := TStringList.Create;
  try
    TextToMoveList(FVariation, LMoves);
    for I := 0 to LMoves.Count - 1 do
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

procedure TPvBrowser.SetData(ABaseBoard: TDraughtsBoard; ABasePly: Integer;
  const AStartingFEN, APv, AScore, ADepth, ATimeText: string);
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
  BuildMoveText(LText);
  RenderMemo(LText);
  RenderBoard;
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
