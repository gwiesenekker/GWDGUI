unit EngineSlot;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  DraughtsRules,
  EngineConfig,
  EngineParams,
  EngineState,
  Menus,
  PlatformProcess,
  ssockets,
  StdCtrls;

type
  TEngineSlot = class
  public
    Index: Integer;
    LogMemo: TMemo;
    DisplayName: String;
    FileName: String;
    Params: TEngineParamArray;
    ParamsFileName: String;
    PlatformProcess: TPlatformProcess;
    Ready: Boolean;
    SearchMode: TEngineSearchMode;
    State: TEngineState;
    StateLabel: TLabel;
    IgnoreNextDoneMove: Boolean;
    PendingAction: TPendingEngineAction;
    PendingMode: TEngineSearchMode;
    TextBuffer: String;
    WaitingForInit: Boolean;
    FirstReadSeen: Boolean;
    Protocol: TEngineProtocol;
    HubId: String;
    IniFileName: String;
    HubLaunchArgument: String;
    DxpId: String;
    DxpIpAddress: String;
    DxpSocketNumber: String;
    DxpLaunchArguments: String;
    DxpRole: TEngineDxpRole;
    DxpThread: TThread;
    DxpSocket: TSocketStream;
    DxpGameState: TDxpGameState;
    DxpGameEndSent: Boolean;
    DxpTimingActive: Boolean;
    DxpTimingLabel: String;
    DxpTimingSendClockSeconds: Double;
    DxpTimingSendSide: TSide;
    DxpTimingSendWallSeconds: Double;
    AnalyzePvText: String;
    AnalyzePvBaseBoard: TBoard;
    AnalyzePvBaseSide: TSide;
    AnalyzePvBasePly: Integer;
    AnalyzePvHasBase: Boolean;
    LogPopupMenu: TPopupMenu;
    CloseMenuItem: TMenuItem;
    OpenMenuItem: TMenuItem;
    ParamsMenuItem: TMenuItem;
    AnalyzeMenuItem: TMenuItem;
    SaveLogMenuItem: TMenuItem;
    ShowTimestampsMenuItem: TMenuItem;
    constructor Create(AIndex: Integer);
    destructor Destroy; override;
    procedure BeginSearch(AMode: TEngineSearchMode; AState: TEngineState);
    procedure FinishSearch;
    procedure ResetRuntimeState;
  end;

  TEngineSlotArray = array[1..4] of TEngineSlot;

implementation

uses
  SysUtils;

constructor TEngineSlot.Create(AIndex: Integer);
begin
  inherited Create;
  Index := AIndex;
  if AIndex = 1 then
    DisplayName := 'Engine'
  else
    DisplayName := 'Engine ' + IntToStr(AIndex);
  PlatformProcess := TPlatformProcess.Create(AIndex);
  Protocol := epHub;
  HubId := 'Hub' + IntToStr(AIndex);
  IniFileName := '';
  HubLaunchArgument := '';
  DxpId := 'DXP' + IntToStr(AIndex);
  DxpIpAddress := DxpDefaultIp;
  DxpSocketNumber := DxpDefaultSocket;
  DxpLaunchArguments := '';
  DxpRole := edrListener;
  DxpGameState := dgsIdle;
  DxpGameEndSent := False;
  DxpTimingActive := False;
  DxpTimingLabel := '';
  DxpTimingSendClockSeconds := 0;
  DxpTimingSendSide := sideWhite;
  DxpTimingSendWallSeconds := 0;
  AnalyzePvText := '';
  AnalyzePvBaseSide := sideWhite;
  AnalyzePvBasePly := 0;
  AnalyzePvHasBase := False;
  SearchMode := esmIdle;
  State := esIdle;
  PendingAction := peaNone;
  PendingMode := esmIdle;
end;

destructor TEngineSlot.Destroy;
begin
  FreeAndNil(PlatformProcess);
  inherited Destroy;
end;

procedure TEngineSlot.BeginSearch(AMode: TEngineSearchMode;
  AState: TEngineState);
begin
  SearchMode := AMode;
  State := AState;
  IgnoreNextDoneMove := False;
end;

procedure TEngineSlot.FinishSearch;
begin
  SearchMode := esmIdle;
  State := esIdle;
  IgnoreNextDoneMove := False;
end;

procedure TEngineSlot.ResetRuntimeState;
begin
  Ready := False;
  SearchMode := esmIdle;
  State := esIdle;
  IgnoreNextDoneMove := False;
  PendingAction := peaNone;
  PendingMode := esmIdle;
  TextBuffer := '';
  WaitingForInit := False;
  FirstReadSeen := False;
  DxpGameState := dgsIdle;
  DxpGameEndSent := False;
  DxpTimingActive := False;
  DxpTimingLabel := '';
  DxpTimingSendClockSeconds := 0;
  DxpTimingSendSide := sideWhite;
  DxpTimingSendWallSeconds := 0;
  AnalyzePvText := '';
  AnalyzePvBasePly := 0;
  AnalyzePvHasBase := False;
end;

end.
