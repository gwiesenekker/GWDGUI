unit uGameGuiMessages;

{$mode objfpc}{$H+}

interface

uses
  uThreadMessageQueue, uGameRunnerThread, uPvSnapshot,
  uGameTreeSearchRef, uAnalyzerRunnerThread;

type
  TRunnerSnapshotGuiMessage = class(TThreadMessage)
  private
    FGameId: Integer;
    FSnapshot: TGameRunnerSnapshot;
  public
    constructor Create(AGameId: Integer; ASnapshot: TGameRunnerSnapshot);
      reintroduce;
    destructor Destroy; override;
    property GameId: Integer read FGameId;
    property Snapshot: TGameRunnerSnapshot read FSnapshot;
  end;

  TRunnerFinishedGuiMessage = class(TThreadMessage)
  private
    FGameId: Integer;
  public
    constructor Create(AGameId: Integer); reintroduce;
    property GameId: Integer read FGameId;
  end;

  TAnalyzerLogGuiMessage = class(TThreadMessage)
  private
    FMessage: string;
  public
    constructor Create(const AMessage: string); reintroduce;
    property Message: string read FMessage;
  end;

  TAnalyzerSnapshotGuiMessage = class(TThreadMessage)
  private
    FSnapshot: TPvSnapshot;
  public
    constructor Create(ASnapshot: TPvSnapshot); reintroduce;
    destructor Destroy; override;
    property Snapshot: TPvSnapshot read FSnapshot;
  end;

  TAnalyzerMoveGuiMessage = class(TThreadMessage)
  private
    FMoveText: string;
    FSearch: TGameTreeSearchRef;
  public
    constructor Create(const ASearch: TGameTreeSearchRef;
      const AMoveText: string); reintroduce;
    property MoveText: string read FMoveText;
    property Search: TGameTreeSearchRef read FSearch;
  end;

  TAnalyzerFinishedGuiMessage = class(TThreadMessage)
  private
    FRunner: TAnalyzerRunnerThread;
  public
    constructor Create(ARunner: TAnalyzerRunnerThread); reintroduce;
    property Runner: TAnalyzerRunnerThread read FRunner;
  end;

  TMctsLogGuiMessage = class(TThreadMessage)
  private
    FMessage: string;
  public
    constructor Create(const AMessage: string); reintroduce;
    property Message: string read FMessage;
  end;

  TMctsFinishedGuiMessage = class(TThreadMessage)
  private
    FRunner: TAnalyzerRunnerThread;
  public
    constructor Create(ARunner: TAnalyzerRunnerThread); reintroduce;
    property Runner: TAnalyzerRunnerThread read FRunner;
  end;

implementation

uses SysUtils;

constructor TRunnerSnapshotGuiMessage.Create(AGameId: Integer;
  ASnapshot: TGameRunnerSnapshot);
begin
  inherited Create('runner-snapshot');
  FGameId := AGameId;
  FSnapshot := ASnapshot;
end;

destructor TRunnerSnapshotGuiMessage.Destroy;
begin
  FSnapshot.Free;
  inherited Destroy;
end;

constructor TRunnerFinishedGuiMessage.Create(AGameId: Integer);
begin
  inherited Create('runner-finished');
  FGameId := AGameId;
end;

constructor TAnalyzerLogGuiMessage.Create(const AMessage: string);
begin
  inherited Create('analyzer-log');
  FMessage := AMessage;
end;

constructor TAnalyzerSnapshotGuiMessage.Create(ASnapshot: TPvSnapshot);
begin
  inherited Create('analyzer-snapshot');
  FSnapshot := ASnapshot;
end;

destructor TAnalyzerSnapshotGuiMessage.Destroy;
begin
  FSnapshot.Free;
  inherited Destroy;
end;

constructor TAnalyzerMoveGuiMessage.Create(const ASearch: TGameTreeSearchRef;
  const AMoveText: string);
begin
  inherited Create('analyzer-move');
  FSearch := ASearch;
  FMoveText := Trim(AMoveText);
end;

constructor TAnalyzerFinishedGuiMessage.Create(ARunner: TAnalyzerRunnerThread);
begin
  inherited Create('analyzer-finished');
  FRunner := ARunner;
end;

constructor TMctsLogGuiMessage.Create(const AMessage: string);
begin
  inherited Create('mcts-log');
  FMessage := AMessage;
end;

constructor TMctsFinishedGuiMessage.Create(ARunner: TAnalyzerRunnerThread);
begin
  inherited Create('mcts-finished');
  FRunner := ARunner;
end;

end.
