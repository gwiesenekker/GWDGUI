unit uGameTreeSearchRef;

{$mode objfpc}{$H+}

interface

type
  TGameTreeSearchRef = record
    GameTreeId: Int64;
    NodeId: Int64;
    SearchId: Int64;
  end;

function EmptyGameTreeSearchRef: TGameTreeSearchRef;
function GameTreeSearchRef(AGameTreeId, ASearchId,
  ANodeId: Int64): TGameTreeSearchRef;
function IsValidGameTreeSearchRef(const ASearch: TGameTreeSearchRef): Boolean;
function SameGameTreeSearchRef(const ALeft,
  ARight: TGameTreeSearchRef): Boolean;

implementation

function EmptyGameTreeSearchRef: TGameTreeSearchRef;
begin
  Result.GameTreeId := 0;
  Result.NodeId := 0;
  Result.SearchId := 0;
end;

function GameTreeSearchRef(AGameTreeId, ASearchId,
  ANodeId: Int64): TGameTreeSearchRef;
begin
  Result.GameTreeId := AGameTreeId;
  Result.NodeId := ANodeId;
  Result.SearchId := ASearchId;
end;

function IsValidGameTreeSearchRef(const ASearch: TGameTreeSearchRef): Boolean;
begin
  Result := (ASearch.GameTreeId > 0) and (ASearch.NodeId > 0) and
    (ASearch.SearchId > 0);
end;

function SameGameTreeSearchRef(const ALeft,
  ARight: TGameTreeSearchRef): Boolean;
begin
  Result := (ALeft.GameTreeId = ARight.GameTreeId) and
    (ALeft.SearchId = ARight.SearchId) and
    (ALeft.NodeId = ARight.NodeId);
end;

end.
