unit uEngineBase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SyncObjs, SysUtils,
  uCancellationToken, uDraughtsBoard;

type
  TEngineState = (
    esWaiting,
    esWaitingForPositionOrMove,
    esLaunching,
    esInitializing,
    esWaitingForReady,
    esReady,
    esThinking,
    esWaitingForDone,
    esError
  );

  TEngineLogEvent = procedure(Sender: TObject; const AMessage: string) of object;

  TDraughtsEngine = class
  private
    FEngineName: string;
    FGameResult: string;
    FGameResultLock: TCriticalSection;
    FLastDepth: string;
    FLastError: string;
    FLastErrorLock: TCriticalSection;
    FLogLock: TCriticalSection;
    FLogTarget: TStrings;
    FMovesPlayed: TStringList;
    FOnLog: TEngineLogEvent;
    FPvLock: TCriticalSection;
    FLastScore: string;
    FLastTimeText: string;
    FPrincipalVariation: string;
    FStartingFEN: string;
    FState: TEngineState;
    FStateLock: TCriticalSection;
    FStateLog: TStringList;
    FStopToken: TCancellationToken;
    function ExtractMessageValue(const AMessage, AName: string; out AValue: string): Boolean;
    function GetGameResult: string;
    function GetLastDepth: string;
    function GetLastError: string;
    function GetLastScore: string;
    function GetLastTimeText: string;
    function GetPrincipalVariation: string;
    function GetCurrentState: TEngineState;
    procedure ParsePositionMessage(const AMessage: string; out AFEN,
      AMovesText: string);
    procedure SetLastError(const AValue: string);
    procedure SetLastDepth(const AValue: string);
    procedure SetLastScore(const AValue: string);
    procedure SetLastTimeText(const AValue: string);
    procedure SetPrincipalVariation(const AValue: string);
  protected
    procedure ChangeState(ANewState: TEngineState; const AReason: string);
    function DoStartThinking: string; virtual; abstract;
    procedure Log(const AMessage: string);
    procedure SetGameResult(const AResult: string);
    function StopRequested: Boolean;
    property State: TEngineState read GetCurrentState;
  public
    constructor Create(const AEngineName: string = 'Engine'); virtual;
    destructor Destroy; override;

    procedure BeginGame(const AStartingFEN: string; ASide: TDraughtsSide;
      AGameMinutes: Double; AGameMoves: Integer); virtual;
    procedure NewGame(const AStartingFEN: string); virtual;
    procedure DoMove(const AMove: string); virtual;
    procedure LogCurrentState(const AReason: string = ''); virtual;
    function ReceiveMessage(const AMessage: string): string; virtual;
    procedure RequestStop; virtual;
    procedure SetClockInfo(AMovesRemaining: Integer; ARemainingSeconds,
      ATotalUsedSeconds: Double); virtual;
    procedure SetGamePosition(const AStartingFEN: string; AMoves: TStrings); virtual;
    function StartThinking: string; virtual;
    procedure Stop; virtual;

    property EngineName: string read FEngineName write FEngineName;
    property CurrentState: TEngineState read GetCurrentState;
    property GameResult: string read GetGameResult;
    property LastDepth: string read GetLastDepth write SetLastDepth;
    property LastError: string read GetLastError;
    property LastScore: string read GetLastScore write SetLastScore;
    property LastTimeText: string read GetLastTimeText write SetLastTimeText;
    property LogTarget: TStrings read FLogTarget write FLogTarget;
    property MovesPlayed: TStringList read FMovesPlayed;
    property PrincipalVariation: string read GetPrincipalVariation write SetPrincipalVariation;
    property StartingFEN: string read FStartingFEN;
    property StateLog: TStringList read FStateLog;
    property StopToken: TCancellationToken read FStopToken write FStopToken;
    property OnLog: TEngineLogEvent read FOnLog write FOnLog;
  end;

function EngineStateToString(AState: TEngineState): string;

implementation

function MessageTokenValue(const AMessage, AKey: string): string;
var
  KeyPos: SizeInt;
  LowerMessage: string;
  StartPos: SizeInt;
begin
  Result := '';
  LowerMessage := LowerCase(AMessage);
  KeyPos := Pos(LowerCase(AKey) + '=', LowerMessage);
  if KeyPos = 0 then
    Exit;

  StartPos := KeyPos + Length(AKey) + 1;
  while (StartPos <= Length(AMessage)) and (AMessage[StartPos] in [#9, ' ']) do
    Inc(StartPos);
  while (StartPos <= Length(AMessage)) and not (AMessage[StartPos] in [#9, ' ']) do
  begin
    Result += AMessage[StartPos];
    Inc(StartPos);
  end;
end;

function EngineStateToString(AState: TEngineState): string;
begin
  case AState of
    esWaiting:
      Result := 'waiting';
    esWaitingForPositionOrMove:
      Result := 'waiting for position or move';
    esLaunching:
      Result := 'launching';
    esInitializing:
      Result := 'initializing';
    esWaitingForReady:
      Result := 'waiting for ready';
    esReady:
      Result := 'ready';
    esThinking:
      Result := 'thinking';
    esWaitingForDone:
      Result := 'waiting for done';
    esError:
      Result := 'error';
  else
    Result := 'unknown';
  end;
end;

constructor TDraughtsEngine.Create(const AEngineName: string);
begin
  inherited Create;
  FEngineName := AEngineName;
  FMovesPlayed := TStringList.Create;
  FStateLog := TStringList.Create;
  FLogLock := TCriticalSection.Create;
  FGameResultLock := TCriticalSection.Create;
  FLastErrorLock := TCriticalSection.Create;
  FPvLock := TCriticalSection.Create;
  FStateLock := TCriticalSection.Create;
  FState := esWaiting;
  SetGameResult('*');
  Log('created; state=' + EngineStateToString(GetCurrentState));
end;

destructor TDraughtsEngine.Destroy;
begin
  FLogLock.Free;
  FGameResultLock.Free;
  FLastErrorLock.Free;
  FPvLock.Free;
  FStateLock.Free;
  FStateLog.Free;
  FMovesPlayed.Free;
  inherited Destroy;
end;

function TDraughtsEngine.GetCurrentState: TEngineState;
begin
  FStateLock.Acquire;
  try
    Result := FState;
  finally
    FStateLock.Release;
  end;
end;

procedure TDraughtsEngine.Log(const AMessage: string);
var
  LMessage: string;
  LState: TEngineState;
begin
  LState := GetCurrentState;
  LMessage := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' [' +
    FEngineName + '] current_state=' + EngineStateToString(LState) + '; ' + AMessage;
  FLogLock.Acquire;
  try
    FStateLog.Add(LMessage);
    if Assigned(FLogTarget) then
      FLogTarget.Add(LMessage);
  finally
    FLogLock.Release;
  end;
  if Assigned(FOnLog) then
    FOnLog(Self, LMessage);
end;

procedure TDraughtsEngine.ChangeState(ANewState: TEngineState; const AReason: string);
var
  LOldState: TEngineState;
  LMessage: string;
begin
  FStateLock.Acquire;
  try
    if FState = ANewState then
      Exit;
    LOldState := FState;
    FState := ANewState;
  finally
    FStateLock.Release;
  end;

  LMessage := FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' [' +
    FEngineName + '] transition; old_state=' + EngineStateToString(LOldState) +
    '; new_state=' + EngineStateToString(ANewState);
  if AReason <> '' then
    LMessage := LMessage + '; ' + AReason;
  FLogLock.Acquire;
  try
    FStateLog.Add(LMessage);
    if Assigned(FLogTarget) then
      FLogTarget.Add(LMessage);
  finally
    FLogLock.Release;
  end;
  if Assigned(FOnLog) then
    FOnLog(Self, LMessage);
end;

function TDraughtsEngine.GetGameResult: string;
begin
  FGameResultLock.Acquire;
  try
    Result := FGameResult;
  finally
    FGameResultLock.Release;
  end;
end;

procedure TDraughtsEngine.SetGameResult(const AResult: string);
var
  LResult: string;
begin
  LResult := Trim(AResult);
  if LResult = '' then
    LResult := '*';

  FGameResultLock.Acquire;
  try
    FGameResult := LResult;
  finally
    FGameResultLock.Release;
  end;
end;

function TDraughtsEngine.GetLastError: string;
begin
  FLastErrorLock.Acquire;
  try
    Result := FLastError;
  finally
    FLastErrorLock.Release;
  end;
end;

procedure TDraughtsEngine.SetLastError(const AValue: string);
begin
  FLastErrorLock.Acquire;
  try
    FLastError := Trim(AValue);
  finally
    FLastErrorLock.Release;
  end;
end;

function TDraughtsEngine.GetLastScore: string;
begin
  FPvLock.Acquire;
  try
    Result := FLastScore;
  finally
    FPvLock.Release;
  end;
end;

procedure TDraughtsEngine.SetLastScore(const AValue: string);
begin
  FPvLock.Acquire;
  try
    FLastScore := Trim(AValue);
  finally
    FPvLock.Release;
  end;
end;

function TDraughtsEngine.GetLastDepth: string;
begin
  FPvLock.Acquire;
  try
    Result := FLastDepth;
  finally
    FPvLock.Release;
  end;
end;

procedure TDraughtsEngine.SetLastDepth(const AValue: string);
begin
  FPvLock.Acquire;
  try
    FLastDepth := Trim(AValue);
  finally
    FPvLock.Release;
  end;
end;

function TDraughtsEngine.GetLastTimeText: string;
begin
  FPvLock.Acquire;
  try
    Result := FLastTimeText;
  finally
    FPvLock.Release;
  end;
end;

procedure TDraughtsEngine.SetLastTimeText(const AValue: string);
begin
  FPvLock.Acquire;
  try
    FLastTimeText := Trim(AValue);
  finally
    FPvLock.Release;
  end;
end;

function TDraughtsEngine.StopRequested: Boolean;
begin
  Result := (FStopToken <> nil) and FStopToken.IsCancelled;
end;

function TDraughtsEngine.GetPrincipalVariation: string;
begin
  FPvLock.Acquire;
  try
    Result := FPrincipalVariation;
  finally
    FPvLock.Release;
  end;
end;

procedure TDraughtsEngine.SetPrincipalVariation(const AValue: string);
begin
  FPvLock.Acquire;
  try
    FPrincipalVariation := Trim(AValue);
  finally
    FPvLock.Release;
  end;
end;

procedure TDraughtsEngine.RequestStop;
begin
end;

procedure TDraughtsEngine.NewGame(const AStartingFEN: string);
begin
  FStartingFEN := Trim(AStartingFEN);
  FMovesPlayed.Clear;
  SetLastError('');
  PrincipalVariation := '';
  LastScore := '';
  LastDepth := '';
  LastTimeText := '';
  SetGameResult('*');
  Log('new game; fen=' + FStartingFEN);
  ChangeState(esReady, 'new game');
end;

procedure TDraughtsEngine.BeginGame(const AStartingFEN: string; ASide: TDraughtsSide;
  AGameMinutes: Double; AGameMoves: Integer);
begin
  NewGame(AStartingFEN);
  Log('game session started; side=' + IntToStr(Ord(ASide)) +
    '; game_minutes=' + FloatToStr(AGameMinutes) +
    '; game_moves=' + IntToStr(AGameMoves));
end;

procedure TDraughtsEngine.DoMove(const AMove: string);
var
  LMove: string;
begin
  LMove := NormalizeMoveNotation(AMove);
  if LMove = '' then
    Exit;

  FMovesPlayed.Add(LMove);
  Log('move played; move=' + LMove);
end;

procedure TDraughtsEngine.SetGamePosition(const AStartingFEN: string; AMoves: TStrings);
var
  I: Integer;
  LMove: string;
begin
  FStartingFEN := Trim(AStartingFEN);
  FMovesPlayed.Clear;
  if AMoves <> nil then
    for I := 0 to AMoves.Count - 1 do
    begin
      LMove := NormalizeMoveNotation(AMoves[I]);
      if LMove <> '' then
        FMovesPlayed.Add(LMove);
    end;
  SetLastError('');
  PrincipalVariation := '';
  LastScore := '';
  LastDepth := '';
  LastTimeText := '';
  SetGameResult('*');
  Log('position received; fen=' + FStartingFEN + '; move_count=' +
    IntToStr(FMovesPlayed.Count));
  ChangeState(esReady, 'position received');
end;

procedure TDraughtsEngine.SetClockInfo(AMovesRemaining: Integer;
  ARemainingSeconds, ATotalUsedSeconds: Double);
begin
  Log('clock received; moves_remaining=' + IntToStr(AMovesRemaining) +
    '; remaining_seconds=' + FloatToStr(ARemainingSeconds) +
    '; total_used_seconds=' + FloatToStr(ATotalUsedSeconds));
end;

procedure TDraughtsEngine.LogCurrentState(const AReason: string);
var
  LMessage: string;
begin
  LMessage := 'state snapshot; state=' + EngineStateToString(GetCurrentState);
  if AReason <> '' then
    LMessage := LMessage + '; ' + AReason;
  Log(LMessage);
end;

function TDraughtsEngine.ExtractMessageValue(const AMessage, AName: string;
  out AValue: string): Boolean;
var
  LMessage, LPrefix: string;
begin
  LMessage := Trim(AMessage);
  LPrefix := LowerCase(AName) + '=';
  Result := Pos(LPrefix, LowerCase(LMessage)) = 1;
  if Result then
    AValue := Trim(Copy(LMessage, Length(LPrefix) + 1, MaxInt))
  else
    AValue := '';
end;

procedure TDraughtsEngine.ParsePositionMessage(const AMessage: string; out AFEN,
  AMovesText: string);
var
  LLowerMessage, LMessage: string;
  LMovesPos: SizeInt;
begin
  LMessage := Trim(AMessage);
  LLowerMessage := LowerCase(LMessage);
  if Pos('pos=', LLowerMessage) <> 1 then
    raise EConvertError.CreateFmt('Invalid position message: %s', [AMessage]);

  LMovesPos := Pos(' moves=', LLowerMessage);
  if LMovesPos = 0 then
  begin
    AFEN := Trim(Copy(LMessage, 5, MaxInt));
    AMovesText := '';
  end
  else
  begin
    AFEN := Trim(Copy(LMessage, 5, LMovesPos - 5));
    AMovesText := Trim(Copy(LMessage, LMovesPos + Length(' moves='), MaxInt));
    if (Length(AMovesText) >= 2) and (AMovesText[1] = '"') and
      (AMovesText[Length(AMovesText)] = '"') then
      AMovesText := Copy(AMovesText, 2, Length(AMovesText) - 2);
  end;
end;

function TDraughtsEngine.ReceiveMessage(const AMessage: string): string;
var
  FormatSettings: TFormatSettings;
  LMessage: string;
  LMove, LMovesText, LValue: string;
  LMoves: TStringList;
  LMovesRemaining: Integer;
  LRemainingSeconds: Double;
  LTotalUsedSeconds: Double;
begin
  Result := '';
  LMessage := Trim(AMessage);
  if LMessage = '' then
    Exit;

  Log('received compatibility message; message=' + LMessage);

  if Pos('pos=', LowerCase(LMessage)) = 1 then
  begin
    ParsePositionMessage(LMessage, LValue, LMovesText);
    LMoves := TStringList.Create;
    try
      if LMovesText <> '' then
        ExtractStrings([' '], [], PChar(LMovesText), LMoves);
      SetGamePosition(LValue, LMoves);
    finally
      LMoves.Free;
    end;
    Exit;
  end;

  if ExtractMessageValue(LMessage, 'move', LValue) then
  begin
    DoMove(LValue);
    Exit;
  end;

  if Pos('level ', LowerCase(LMessage)) = 1 then
  begin
    FormatSettings := DefaultFormatSettings;
    FormatSettings.DecimalSeparator := '.';
    LMovesRemaining := StrToIntDef(MessageTokenValue(LMessage, 'moves'), 0);
    LRemainingSeconds := StrToFloatDef(MessageTokenValue(LMessage, 'time'), 0,
      FormatSettings);
    LTotalUsedSeconds := StrToFloatDef(MessageTokenValue(LMessage, 'used'), 0,
      FormatSettings);
    SetClockInfo(LMovesRemaining, LRemainingSeconds, LTotalUsedSeconds);
    Exit;
  end;

  if (CompareText(LMessage, 'go think') = 0) or
    (CompareText(LMessage, 'go thiink') = 0) then
  begin
    LMove := StartThinking;
    if LMove <> '' then
      Result := 'done move=' + LMove
    else
      Result := 'done';
    Log('sent compatibility message; message=' + Result);
    Exit;
  end;

  Log('ignored compatibility message; message=' + LMessage);
end;

function TDraughtsEngine.StartThinking: string;
begin
  Result := '';
  SetLastError('');
  ChangeState(esThinking, 'start thinking');
  try
    Result := Trim(DoStartThinking);
    if Result <> '' then
      DoMove(Result)
    else
      Log('thinking finished without move');
    ChangeState(esReady, 'thinking finished');
  except
    on E: Exception do
    begin
      SetLastError(E.Message);
      Log('error; message=' + E.Message);
      ChangeState(esError, 'exception while thinking');
      raise;
    end;
  end;
end;

procedure TDraughtsEngine.Stop;
begin
  Log('stop requested');
end;

end.
