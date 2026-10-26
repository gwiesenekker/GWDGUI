program database_import_performance_check;
{$mode objfpc}{$H+}
uses {$IFDEF UNIX}cthreads,{$ENDIF} Classes, SysUtils, uGameDatabase;
procedure Check(Value: Boolean; const Text: string);
begin if not Value then raise Exception.Create(Text); end;
var Db: TGameDatabase; Fixture, Input, Loaded: TStringList; Games: TList;
  Base, DbName, InputName, LogName: string; Count, I, Mode, Pass, Imported,
  Duplicates, Errors: Integer; Tick: QWord;
begin
  Check(ParamCount >= 1, 'usage: database_import_performance_check fixture [games]');
  Count := 100; if ParamCount > 1 then Count := StrToInt(ParamStr(2));
  Check(Count > 0, 'game count must be positive');
  Base := GetTempFileName(GetTempDir, 'gwddbperf');
  DbName := Base + '.db'; InputName := Base + '.pdn'; LogName := Base + '.log';
  Fixture := TStringList.Create; Input := TStringList.Create;
  Loaded := TStringList.Create; Games := TList.Create; Db := TGameDatabase.Create;
  try
    Fixture.LoadFromFile(ParamStr(1));
    for I := 1 to Count do
      Input.Add(StringReplace(Fixture.Text, '[White "', '[White "case' + IntToStr(I) + ' ', []));
    Input.SaveToFile(InputName);
    Writeln('operation,logging,games,ms');
    for Mode := 0 to 1 do
    begin
      Db.CreateDatabase(DbName);
      for Pass := 0 to 1 do
      begin
        Tick := GetTickCount64;
        if Mode = 0 then Db.ImportPdnFile(InputName, Imported, Duplicates, Errors)
        else Db.ImportPdnFile(InputName, Imported, Duplicates, Errors, nil, LogName);
        if Pass = 0 then Write('fresh,') else Write('duplicate,');
        if Mode = 0 then Write('off,') else Write('on,');
        Writeln(Count, ',', GetTickCount64 - Tick);
        Check(Errors = 0, 'benchmark games must be valid');
        if Pass = 0 then Check((Imported = Count) and (Duplicates = 0), 'all fresh games inserted')
        else Check((Imported = 0) and (Duplicates = Count), 'all reimported games detected');
      end;
      Db.LoadGames(Games); Check(Games.Count = Count, 'reimport must preserve game count');
      for I := 0 to Games.Count - 1 do TObject(Games[I]).Free; Games.Clear;
      if Mode = 1 then
      begin
        Loaded.LoadFromFile(LogName);
        Check(Pos('----- DUPLICATE PDN -----', Loaded.Text) > 0, 'logged duplicates include public PDN');
      end;
      Db.Close; DeleteFile(DbName);
    end;
  finally
    Db.Free; Games.Free; Fixture.Free; Input.Free; Loaded.Free;
    DeleteFile(Base); DeleteFile(DbName); DeleteFile(InputName); DeleteFile(LogName);
  end;
end.
