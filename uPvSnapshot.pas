unit uPvSnapshot;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uDraughtsBoard, uGameTreeSearchRef;

type
  TPvSnapshot = class
  private
    FBaseBoard: TDraughtsBoard;
    FBasePly: Integer;
    FDepth: string;
    FGameTreeOnly: Boolean;
    FGameTreeId: Int64;
    FNodeId: Int64;
    FPrincipalVariation: string;
    FSearchId: Int64;
    FScore: string;
    FTimeText: string;
    FTransient: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AssignFrom(ASource: TPvSnapshot);
    function SearchRef: TGameTreeSearchRef;
    procedure SetData(ABaseBoard: TDraughtsBoard; ABasePly: Integer;
      const APv, AScore, ADepth: string; const ATimeText: string = '';
      AGameTreeId: Int64 = 0; ASearchId: Int64 = 0; ANodeId: Int64 = 0;
      AGameTreeOnly: Boolean = False);
    procedure SetDataWithSearch(ABaseBoard: TDraughtsBoard;
      ABasePly: Integer; const APv, AScore, ADepth: string;
      const ATimeText: string; const ASearch: TGameTreeSearchRef;
      AGameTreeOnly: Boolean; ATransient: Boolean = False);

    property BaseBoard: TDraughtsBoard read FBaseBoard;
    property BasePly: Integer read FBasePly;
    property Depth: string read FDepth;
    property GameTreeOnly: Boolean read FGameTreeOnly;
    property GameTreeId: Int64 read FGameTreeId;
    property NodeId: Int64 read FNodeId;
    property PrincipalVariation: string read FPrincipalVariation;
    property SearchId: Int64 read FSearchId;
    property Score: string read FScore;
    property TimeText: string read FTimeText;
    property Transient: Boolean read FTransient;
  end;

implementation

constructor TPvSnapshot.Create;
begin
  inherited Create;
  FBaseBoard := TDraughtsBoard.Create;
  FBasePly := 0;
end;

destructor TPvSnapshot.Destroy;
begin
  FBaseBoard.Free;
  inherited Destroy;
end;

procedure TPvSnapshot.AssignFrom(ASource: TPvSnapshot);
begin
  if ASource = nil then
    Exit;
  SetDataWithSearch(ASource.BaseBoard, ASource.BasePly,
    ASource.PrincipalVariation, ASource.Score, ASource.Depth,
    ASource.TimeText, ASource.SearchRef, ASource.GameTreeOnly,
    ASource.Transient);
end;

function TPvSnapshot.SearchRef: TGameTreeSearchRef;
begin
  Result := GameTreeSearchRef(FGameTreeId, FSearchId, FNodeId);
end;

procedure TPvSnapshot.SetData(ABaseBoard: TDraughtsBoard; ABasePly: Integer;
  const APv, AScore, ADepth: string; const ATimeText: string;
  AGameTreeId: Int64; ASearchId: Int64; ANodeId: Int64;
  AGameTreeOnly: Boolean);
begin
  SetDataWithSearch(ABaseBoard, ABasePly, APv, AScore, ADepth, ATimeText,
    GameTreeSearchRef(AGameTreeId, ASearchId, ANodeId), AGameTreeOnly);
end;

procedure TPvSnapshot.SetDataWithSearch(ABaseBoard: TDraughtsBoard;
  ABasePly: Integer; const APv, AScore, ADepth: string;
  const ATimeText: string; const ASearch: TGameTreeSearchRef;
  AGameTreeOnly: Boolean; ATransient: Boolean);
begin
  if ABaseBoard <> nil then
    FBaseBoard.AssignFrom(ABaseBoard);
  FBasePly := ABasePly;
  FGameTreeId := ASearch.GameTreeId;
  FSearchId := ASearch.SearchId;
  FNodeId := ASearch.NodeId;
  FGameTreeOnly := AGameTreeOnly;
  FTransient := ATransient;
  FPrincipalVariation := Trim(APv);
  FScore := Trim(AScore);
  FDepth := Trim(ADepth);
  FTimeText := Trim(ATimeText);
end;

end.
