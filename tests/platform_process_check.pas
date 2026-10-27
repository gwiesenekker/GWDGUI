program platform_process_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, BaseUnix,{$ENDIF}
  Classes, SysUtils, Process, uPlatformProcess, uDraughtsPosition;
type
  TOutputProbe = class
    Text: string;
    procedure Data(Sender: TObject; const Chunk: string);
  end;
procedure TOutputProbe.Data(Sender: TObject; const Chunk: string);
begin Text += Chunk; end;
procedure Check(Value: Boolean; const MessageText: string);
begin if not Value then raise Exception.Create(MessageText); end;
var First, Second: TPlatformProcess; Args: TStringList; Probe: TOutputProbe;
  Tick: QWord; Auxiliary: TProcess; Lines: TStringList;
  {$IFDEF LINUX}I: Integer; Target, InputPipe, OutputPipe, ErrorPipe: string;{$ENDIF}
begin
  if ParamStr(1) = '--chunked-output' then
  begin
    Write('first chunk'); Flush(Output); Sleep(30);
    Write(StringOfChar('x', 70000)); Flush(Output); Sleep(30);
    WriteLn; WriteLn('eDP-1 connected primary 1920x1080+0+0'); Flush(Output); Halt(0);
  end;
  Auxiliary := TProcess.Create(nil); Lines := TStringList.Create;
  try
    Auxiliary.Executable := ExpandFileName(ParamStr(0));
    Auxiliary.Parameters.Add('--chunked-output'); Auxiliary.Options := [poUsePipes];
    ExecuteAuxiliaryProcess(Auxiliary);
    Lines.Text := ReadAuxiliaryProcessOutput(Auxiliary);
    Check(Lines.Text = 'first chunk' + StringOfChar('x', 70000) + LineEnding +
      'eDP-1 connected primary 1920x1080+0+0' + LineEnding,
      'auxiliary output includes delayed chunks, output larger than the pipe, and final panel line');
    Check(Auxiliary.ExitStatus = 0, 'output drain waits for actual process exit');
  finally Lines.Free; Auxiliary.Free; end;
  {$IFDEF LINUX}
  if ParamStr(1) = '--fd-probe' then
  begin
    InputPipe := fpReadLink('/proc/self/fd/0');
    OutputPipe := fpReadLink('/proc/self/fd/1');
    ErrorPipe := fpReadLink('/proc/self/fd/2');
    for I := 3 to 255 do
    begin
      Target := fpReadLink('/proc/self/fd/' + IntToStr(I));
      if (Pos('pipe:', Target) = 1) and (Target <> InputPipe) and (Target <> OutputPipe) and (Target <> ErrorPipe) then
      begin WriteLn('LEAKED ', I, ' ', Target); Halt(1); end;
    end;
    WriteLn('CLEAN'); Halt(0);
  end;
  {$ENDIF}
  Check(CommandLineQuote('C:\path\') = '"C:\path\\"', 'Windows trailing slash quoting');
  Check(CommandLineQuote('a"b') = '"a\"b"', 'Windows embedded quote quoting');
  {$IFDEF LINUX}
  First := TPlatformProcess.Create; Second := TPlatformProcess.Create;
  Args := TStringList.Create; Probe := TOutputProbe.Create; Auxiliary := nil;
  try
    First.SynchronizeData := False; Second.SynchronizeData := False;
    First.Start('/bin/cat', Args, GetTempDir);
    Auxiliary := TProcess.Create(nil); Lines := TStringList.Create;
    try
      Auxiliary.Executable := ExpandFileName(ParamStr(0));
      Auxiliary.Parameters.Add('--fd-probe'); Auxiliary.Options := [poUsePipes];
      ExecuteAuxiliaryProcess(Auxiliary);
      Lines.LoadFromStream(Auxiliary.Output); Auxiliary.WaitOnExit;
      Check(Pos('CLEAN', Lines.Text) > 0, 'auxiliary process must not inherit engine pipes');
    finally Lines.Free; FreeAndNil(Auxiliary); end;
    Auxiliary := TProcess.Create(nil);
    Auxiliary.Executable := '/bin/cat'; Auxiliary.Options := [poUsePipes];
    ExecuteAuxiliaryProcess(Auxiliary);
    Args.Add('--fd-probe'); Second.OnData := @Probe.Data;
    Second.Start(ExpandFileName(ParamStr(0)), Args, GetTempDir);
    Tick := GetTickCount64;
    repeat
      Second.ReadAvailable;
      if Pos('CLEAN', Probe.Text) > 0 then Break;
      Sleep(5);
    until GetTickCount64 - Tick > 3000;
    Check(Pos('CLEAN', Probe.Text) > 0,
      'second engine must not inherit first engine pipes: ' + Probe.Text);
  finally
    if Auxiliary <> nil then
    begin Auxiliary.Terminate(0); Auxiliary.WaitOnExit; Auxiliary.Free; end;
    Second.Free; First.Free; Probe.Free; Args.Free;
  end;
  {$ENDIF}
  WriteLn('OK');
end.
