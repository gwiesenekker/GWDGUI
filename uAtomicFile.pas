unit uAtomicFile;
{$mode objfpc}{$H+}
interface
procedure WriteTextFileAtomically(const AFileName, AText: string);
implementation
uses
  Classes, SysUtils
  {$IFDEF UNIX}, BaseUnix, Unix{$ENDIF}
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

procedure WriteTextFileAtomically(const AFileName, AText: string);
var
  Id: TGUID;
  TempName: string;
  Stream: TFileStream;
begin
  if CreateGUID(Id) <> 0 then
    raise EInOutError.Create('Could not create a temporary file name');
  TempName := ExpandFileName(AFileName) + '.tmp.' + GUIDToString(Id);
  try
    Stream := TFileStream.Create(TempName, fmCreate);
    try
      if Length(AText) > 0 then
        Stream.WriteBuffer(AText[1], Length(AText));
      {$IFDEF UNIX}
      if fpFsync(Stream.Handle) <> 0 then
        RaiseLastOSError;
      {$ENDIF}
      {$IFDEF MSWINDOWS}
      if not FlushFileBuffers(Stream.Handle) then
        RaiseLastOSError;
      {$ENDIF}
    finally
      Stream.Free;
    end;
    {$IFDEF MSWINDOWS}
    if not MoveFileEx(PChar(TempName), PChar(ExpandFileName(AFileName)),
      MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then
      RaiseLastOSError;
    {$ELSE}
    if not RenameFile(TempName, ExpandFileName(AFileName)) then
      raise EInOutError.Create('Could not replace file: ' + AFileName);
    {$ENDIF}
  finally
    if FileExists(TempName) then
      DeleteFile(TempName);
  end;
end;
end.
