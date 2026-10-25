program platform_process_check;
{$mode objfpc}{$H+}
uses
  {$IFDEF UNIX}cthreads, BaseUnix,{$ENDIF}
  Classes, SysUtils, uPlatformProcess;
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
  Tick: QWord;
  {$IFDEF LINUX}I: Integer; Target, InputPipe, OutputPipe: string;{$ENDIF}
begin
  {$IFDEF LINUX}
  if ParamStr(1) = '--fd-probe' then
  begin
    InputPipe := fpReadLink('/proc/self/fd/0');
    OutputPipe := fpReadLink('/proc/self/fd/1');
    for I := 3 to 255 do
    begin
      Target := fpReadLink('/proc/self/fd/' + IntToStr(I));
      if (Pos('pipe:', Target) = 1) and (Target <> InputPipe) and (Target <> OutputPipe) then
      begin WriteLn('LEAKED ', I, ' ', Target); Halt(1); end;
    end;
    WriteLn('CLEAN'); Halt(0);
  end;
  {$ENDIF}
  Check(CommandLineQuote('C:\path\') = '"C:\path\\"', 'Windows trailing slash quoting');
  Check(CommandLineQuote('a"b') = '"a\"b"', 'Windows embedded quote quoting');
  {$IFDEF LINUX}
  First := TPlatformProcess.Create; Second := TPlatformProcess.Create;
  Args := TStringList.Create; Probe := TOutputProbe.Create;
  try
    First.SynchronizeData := False; Second.SynchronizeData := False;
    First.Start('/bin/cat', Args, GetTempDir);
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
    Second.Free; First.Free; Probe.Free; Args.Free;
  end;
  {$ENDIF}
  WriteLn('OK');
end.
