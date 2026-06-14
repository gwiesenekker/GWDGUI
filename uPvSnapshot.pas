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
  public
    constructor Create;
    destructor Destroy; override;

    procedure AssignFrom(ASource: TPvSnapshot);
    function SearchRef: TGameTreeSearchRef;
    procedure SetData(ABaseBoard: TDraughtsBoard; ABasePly: Integer;
      const APv, AScore, ADepth: string; const ATimeText: string = '';
      AGameTreeId: Int64 = 0; ASearchId: Int64 = 0; ANodeId: Int64 = 0;
      AGameTreeOnly: Boolean = False);

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
  SetData(ASource.BaseBoard, ASource.BasePly, ASource.PrincipalVariation,
    ASource.Score, ASource.Depth, ASource.TimeText, ASource.GameTreeId,
    ASource.SearchId, ASource.NodeId, ASource.GameTreeOnly);
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
  if ABaseBoard <> nil then
    FBaseBoard.AssignFrom(ABaseBoard);
  FBasePly := ABasePly;
  FGameTreeId := AGameTreeId;
  FSearchId := ASearchId;
  FNodeId := ANodeId;
  FGameTreeOnly := AGameTreeOnly;
  FPrincipalVariation := Trim(APv);
  FScore := Trim(AScore);
  FDepth := Trim(ADepth);
  FTimeText := Trim(ATimeText);
end;

end.
