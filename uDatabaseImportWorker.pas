unit uDatabaseImportWorker;
{$mode objfpc}{$H+}
interface
uses Classes, SyncObjs, SysUtils, uGameDatabase;
type
  TDatabaseImportState = record
    BytesRead, TotalBytes: Int64;
    Imported, Duplicates, Errors: Integer;
    Done: Boolean;
    Failure: string;
    WorkerThreadId: TThreadID;
  end;
  TDatabaseImportWorker = class(TThread)
  private
    FLock: TCriticalSection;
    FCancel: Boolean;
    FState: TDatabaseImportState;
    FDatabaseName, FPdnName: string;
    procedure Progress(BytesRead, TotalBytes: Int64; Imported, Duplicates,
      Errors: Integer; var Cancel: Boolean);
  protected
    procedure Execute; override;
  public
    constructor Create(const DatabaseName, PdnName: string);
    destructor Destroy; override;
    procedure RequestCancel;
    function Snapshot: TDatabaseImportState;
  end;
implementation
constructor TDatabaseImportWorker.Create(const DatabaseName, PdnName: string);
begin
  inherited Create(True);
  FLock := TCriticalSection.Create;
  FDatabaseName := DatabaseName; FPdnName := PdnName;
end;
destructor TDatabaseImportWorker.Destroy;
begin
  RequestCancel;
  inherited Destroy; // joins before releasing the state lock
  FLock.Free;
end;
procedure TDatabaseImportWorker.RequestCancel;
begin FLock.Acquire; try FCancel := True; finally FLock.Release; end; end;
function TDatabaseImportWorker.Snapshot: TDatabaseImportState;
begin FLock.Acquire; try Result := FState; finally FLock.Release; end; end;
procedure TDatabaseImportWorker.Progress(BytesRead, TotalBytes: Int64;
  Imported, Duplicates, Errors: Integer; var Cancel: Boolean);
begin
  FLock.Acquire;
  try
    FState.BytesRead := BytesRead; FState.TotalBytes := TotalBytes;
    FState.Imported := Imported; FState.Duplicates := Duplicates; FState.Errors := Errors;
    Cancel := FCancel;
  finally FLock.Release; end;
end;
procedure TDatabaseImportWorker.Execute;
var Database: TGameDatabase; Imported, Duplicates, Errors: Integer;
  Failure: string;
begin
  Database := nil; Imported := 0; Duplicates := 0; Errors := 0; Failure := '';
  try
    try
      // No GUI objects or main-thread SQLite connection cross this boundary.
      Database := TGameDatabase.Create;
      Database.OpenDatabase(FDatabaseName);
      Database.ImportPdnFile(FPdnName, Imported, Duplicates, Errors,
        @Progress, ChangeFileExt(FPdnName, '.import.log'));
    except on E: Exception do Failure := E.Message; end;
  finally
    try Database.Free;
    except on E: Exception do if Failure = '' then Failure := E.Message; end;
    FLock.Acquire;
    try
      FState.Imported := Imported; FState.Duplicates := Duplicates; FState.Errors := Errors;
      FState.Failure := Failure; FState.WorkerThreadId := GetCurrentThreadID;
      FState.Done := True;
    finally FLock.Release; end;
  end;
end;
end.
