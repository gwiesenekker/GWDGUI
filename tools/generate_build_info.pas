program GenerateBuildInfo;
{$mode objfpc}{$H+}{$codepage utf8}
uses Classes, SysUtils, Process
  {$IFDEF MSWINDOWS}, Windows, ShellApi{$ENDIF};

function InputParam(Index: Integer): string;
{$IFDEF MSWINDOWS}
type TWideArgs = array[0..65535] of PWideChar;
     PWideArgs = ^TWideArgs;
var Args: PWideArgs; Count: LongInt;
{$ENDIF}
begin
  {$IFDEF MSWINDOWS}
  // RTL ParamStr uses the ANSI command line: use Unicode paths on Windows.
  Args := PWideArgs(CommandLineToArgvW(GetCommandLineW, @Count));
  if Args = nil then RaiseLastOSError;
  try
    if (Index < 0) or (Index >= Count) then
      raise Exception.Create('Missing build information argument');
    Result := UTF8Encode(UnicodeString(Args^[Index]));
  finally
    LocalFree(HLOCAL(Args));
  end;
  {$ELSE}
  Result := ParamStr(Index);
  {$ENDIF}
end;

function Git(const Root: string; const Args: array of string): string;
var P: TProcess; Output: TStringStream; I: Integer;
begin
  P := TProcess.Create(nil);
  Output := TStringStream.Create('');
  try
    P.Executable := 'git';
    P.Parameters.Add('-C');
    P.Parameters.Add(Root);
    for I := 0 to High(Args) do P.Parameters.Add(Args[I]);
    P.Options := [poUsePipes, poNoConsole];
    P.Execute;
    // Drain stdout before waiting, including large dirty working trees.
    Output.CopyFrom(P.Output, 0);
    P.WaitOnExit;
    if P.ExitStatus <> 0 then raise Exception.Create('Git identity unavailable');
    Result := Trim(Output.DataString);
  finally
    Output.Free;
    P.Free;
  end;
end;

function Quoted(const Text: string): string;
begin
  Result := '''' + StringReplace(Text, '''', '''''', [rfReplaceAll]) + '''';
end;

function ReadText(const Name: string): string;
var S: TFileStream;
begin
  S := TFileStream.Create(Name, fmOpenRead or fmShareDenyNone);
  try
    SetLength(Result, S.Size);
    if Length(Result) > 0 then S.ReadBuffer(Result[1], Length(Result));
  finally
    S.Free;
  end;
end;

var Root, Commit, Revision, Manual, Text, OutputName: string;
    Dirty: Boolean;
    Start, I: SizeInt;
    Stream: TFileStream;
begin
  {$IFDEF MSWINDOWS}
  SetMultiByteConversionCodePage(CP_UTF8);
  SetMultiByteFileSystemCodePage(CP_UTF8);
  {$ENDIF}
  try
    if ParamCount <> 2 then raise Exception.Create('Expected source root and output filename');
    Root := ExcludeTrailingPathDelimiter(ExpandFileName(InputParam(1)));
    OutputName := ExpandFileName(InputParam(2));
    try
      {$IFDEF MSWINDOWS}
      if CompareText(ExpandFileName(Git(Root, ['rev-parse', '--show-toplevel'])), Root) <> 0 then
    {$ELSE}
      if ExpandFileName(Git(Root, ['rev-parse', '--show-toplevel'])) <> Root then
    {$ENDIF}
        raise Exception.Create('Source folder is not the repository root');
      Commit := Git(Root, ['rev-parse', '--verify', 'HEAD']);
      Revision := Git(Root, ['describe', '--tags', '--always']);
      Dirty := Git(Root, ['status', '--porcelain', '--untracked-files=no']) <> '';
    except
      Commit := 'unavailable (source archive)';
      Revision := 'source build';
      Dirty := False;
    end;
    Manual := StringReplace(ReadText(Root + DirectorySeparator + 'MANUAL.md'), #13#10, #10, [rfReplaceAll]);
    Manual := StringReplace(Manual, #13, #10, [rfReplaceAll]);
    Text := 'const' + #10 + '  BuildCommit = ' + Quoted(Commit) + ';' + #10 +
      '  BuildRevision = ' + Quoted(Revision) + ';' + #10 +
      '  BuildHasChanges = ' + BoolToStr(Dirty, True) + ';' + #10 +
      '  EmbeddedManual: UTF8String =' + #10;
    Start := 1;
    for I := 1 to Length(Manual) do
      if Manual[I] = #10 then
      begin
        Text += '    ' + Quoted(Copy(Manual, Start, I - Start)) + ' + #10 +' + #10;
        Start := I + 1;
      end;
    Text += '    ' + Quoted(Copy(Manual, Start, MaxInt)) + ';' + #10;
    if not ForceDirectories(ExtractFileDir(OutputName)) then
      raise Exception.Create('Cannot create build information directory');
    Stream := TFileStream.Create(OutputName, fmCreate);
    try
      Stream.WriteBuffer(Text[1], Length(Text));
    finally
      Stream.Free;
    end;
  except
    on E: Exception do
    begin
      WriteLn(StdErr, E.Message);
      Halt(1);
    end;
  end;
end.
