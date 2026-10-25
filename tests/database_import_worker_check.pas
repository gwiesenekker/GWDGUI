program database_import_worker_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, uGameDatabase, uDatabaseImportWorker;
procedure Check(Condition: Boolean; const Text: string);
begin if not Condition then raise Exception.Create(Text); end;
var Database: TGameDatabase; Worker: TDatabaseImportWorker;
  State: TDatabaseImportState; Lines: TStringList; Name, DbName: string;
  Started: QWord; Games: TList; I: Integer;
begin
  Name := GetTempFileName(GetTempDir, 'gwdworker'); DbName := Name + '.db';
  Database := TGameDatabase.Create; Lines := TStringList.Create; Games := TList.Create;
  try
    Database.CreateDatabase(DbName); Database.Close;
    for I := 1 to 200 do Lines.Add('[Event "Game' + IntToStr(I) + '"] 1.32-28 18-23 *');
    Lines.SaveToFile(Name);
    Worker := TDatabaseImportWorker.Create(DbName, Name);
    try
      Worker.RequestCancel; Worker.Start;
      Started := GetTickCount64;
      repeat
        State := Worker.Snapshot;
        Check(GetTickCount64 - Started < 10000, 'worker must complete without main-thread synchronization');
        if not State.Done then Sleep(5);
      until State.Done;
      Worker.WaitFor;
      Check(State.WorkerThreadId <> GetCurrentThreadID, 'database work runs on a different thread');
      Check((State.Failure = '') and (State.Imported = 1), 'cancel retains first completed game');
    finally Worker.Free; end;
    Database.OpenDatabase(DbName); Database.LoadGames(Games);
    Check(Games.Count = 1, 'cancelled worker committed its completed games');
    for I := 0 to Games.Count - 1 do TObject(Games[I]).Free;
    Games.Clear; Database.Close;
    Worker := TDatabaseImportWorker.Create(DbName, Name + '.missing');
    try
      Worker.Start; Worker.WaitFor; State := Worker.Snapshot;
      Check(State.Done and (State.Failure <> ''), 'worker errors are delivered as data');
    finally Worker.Free; end;
  finally
    Games.Free; Lines.Free; Database.Free;
    DeleteFile(Name); DeleteFile(DbName); DeleteFile(ChangeFileExt(Name, '.import.log'));
    DeleteFile(ChangeFileExt(Name + '.missing', '.import.log'));
  end;
  Writeln('OK');
end.
