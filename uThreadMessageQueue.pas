unit uThreadMessageQueue;

{$mode objfpc}{$H+}

interface

uses
  Classes, SyncObjs, SysUtils;

const
  ThreadMessageQueueInfinite = High(Cardinal);

type
  TThreadMessage = class
  private
    FCreatedTick: QWord;
    FKind: string;
  public
    constructor Create(const AKind: string); virtual;
    property CreatedTick: QWord read FCreatedTick;
    property Kind: string read FKind;
  end;

  TThreadMessageQueue = class
  private
    FClosed: Boolean;
    FEvent: TSimpleEvent;
    FItems: TList;
    FLock: TCriticalSection;
    FOwnsMessages: Boolean;
    function PopLocked(out AMessage: TObject): Boolean;
    procedure ResetEventIfEmptyLocked;
  public
    constructor Create(AOwnsMessages: Boolean = True);
    destructor Destroy; override;

    procedure Clear;
    procedure Close;
    function Count: Integer;
    function IsClosed: Boolean;
    procedure Post(AMessage: TObject);
    function TryPost(AMessage: TObject): Boolean;
    function TryPop(out AMessage: TObject): Boolean;
    function WaitPop(out AMessage: TObject;
      ATimeoutMs: Cardinal = ThreadMessageQueueInfinite): Boolean;

    property OwnsMessages: Boolean read FOwnsMessages;
  end;

implementation

constructor TThreadMessage.Create(const AKind: string);
begin
  inherited Create;
  FKind := Trim(AKind);
  FCreatedTick := GetTickCount64;
end;

constructor TThreadMessageQueue.Create(AOwnsMessages: Boolean);
begin
  inherited Create;
  FOwnsMessages := AOwnsMessages;
  FItems := TList.Create;
  FLock := TCriticalSection.Create;
  FEvent := TSimpleEvent.Create;
end;

destructor TThreadMessageQueue.Destroy;
begin
  Close;
  Clear;
  FEvent.Free;
  FLock.Free;
  FItems.Free;
  inherited Destroy;
end;

procedure TThreadMessageQueue.ResetEventIfEmptyLocked;
begin
  if FItems.Count = 0 then
    FEvent.ResetEvent;
end;

function TThreadMessageQueue.PopLocked(out AMessage: TObject): Boolean;
begin
  Result := FItems.Count > 0;
  if not Result then
  begin
    AMessage := nil;
    ResetEventIfEmptyLocked;
    Exit;
  end;

  AMessage := TObject(FItems[0]);
  FItems.Delete(0);
  ResetEventIfEmptyLocked;
end;

procedure TThreadMessageQueue.Clear;
var
  I: Integer;
begin
  FLock.Acquire;
  try
    if FOwnsMessages then
      for I := 0 to FItems.Count - 1 do
        TObject(FItems[I]).Free;
    FItems.Clear;
    FEvent.ResetEvent;
  finally
    FLock.Release;
  end;
end;

procedure TThreadMessageQueue.Close;
begin
  FLock.Acquire;
  try
    FClosed := True;
    FEvent.SetEvent;
  finally
    FLock.Release;
  end;
end;

function TThreadMessageQueue.Count: Integer;
begin
  FLock.Acquire;
  try
    Result := FItems.Count;
  finally
    FLock.Release;
  end;
end;

function TThreadMessageQueue.IsClosed: Boolean;
begin
  FLock.Acquire;
  try
    Result := FClosed;
  finally
    FLock.Release;
  end;
end;

procedure TThreadMessageQueue.Post(AMessage: TObject);
begin
  if AMessage = nil then
    raise EArgumentException.Create('Cannot post a nil thread message');

  if not TryPost(AMessage) then
    raise EInvalidOperation.Create('Cannot post to a closed thread message queue');
end;

function TThreadMessageQueue.TryPost(AMessage: TObject): Boolean;
begin
  Result := False;
  if AMessage = nil then
    Exit;

  FLock.Acquire;
  try
    if FClosed then
    begin
      if FOwnsMessages then
        AMessage.Free;
      Exit;
    end;

    FItems.Add(AMessage);
    FEvent.SetEvent;
    Result := True;
  finally
    FLock.Release;
  end;
end;

function TThreadMessageQueue.TryPop(out AMessage: TObject): Boolean;
begin
  FLock.Acquire;
  try
    Result := PopLocked(AMessage);
  finally
    FLock.Release;
  end;
end;

function TThreadMessageQueue.WaitPop(out AMessage: TObject;
  ATimeoutMs: Cardinal): Boolean;
var
  RemainingMs: Cardinal;
  StartTick: QWord;
  WaitResult: TWaitResult;
begin
  Result := False;
  AMessage := nil;
  StartTick := GetTickCount64;
  RemainingMs := ATimeoutMs;

  while True do
  begin
    FLock.Acquire;
    try
      if PopLocked(AMessage) then
        Exit(True);
      if FClosed then
        Exit(False);
    finally
      FLock.Release;
    end;

    if ATimeoutMs = 0 then
      Exit(False);

    WaitResult := FEvent.WaitFor(RemainingMs);
    if WaitResult = wrTimeout then
      Exit(False);
    if WaitResult = wrError then
      raise ESyncObjectException.Create('Thread message queue wait failed');

    if ATimeoutMs <> ThreadMessageQueueInfinite then
    begin
      if GetTickCount64 - StartTick >= QWord(ATimeoutMs) then
        Exit(False);
      RemainingMs := ATimeoutMs - Cardinal(GetTickCount64 - StartTick);
    end;
  end;
end;

end.
