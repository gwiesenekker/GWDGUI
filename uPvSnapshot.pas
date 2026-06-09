unit uPvSnapshot;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, uDraughtsBoard;

type
  TPvSnapshot = class
  private
    FBaseBoard: TDraughtsBoard;
    FBasePly: Integer;
    FDepth: string;
    FPrincipalVariation: string;
    FScore: string;
    FTimeText: string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AssignFrom(ASource: TPvSnapshot);
    procedure SetData(ABaseBoard: TDraughtsBoard; ABasePly: Integer;
      const APv, AScore, ADepth: string; const ATimeText: string = '');

    property BaseBoard: TDraughtsBoard read FBaseBoard;
    property BasePly: Integer read FBasePly;
    property Depth: string read FDepth;
    property PrincipalVariation: string read FPrincipalVariation;
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
    ASource.Score, ASource.Depth, ASource.TimeText);
end;

procedure TPvSnapshot.SetData(ABaseBoard: TDraughtsBoard; ABasePly: Integer;
  const APv, AScore, ADepth: string; const ATimeText: string);
begin
  if ABaseBoard <> nil then
    FBaseBoard.AssignFrom(ABaseBoard);
  FBasePly := ABasePly;
  FPrincipalVariation := Trim(APv);
  FScore := Trim(AScore);
  FDepth := Trim(ADepth);
  FTimeText := Trim(ATimeText);
end;

end.
