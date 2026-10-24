unit uAtomicFile;
{$mode objfpc}{$H+}
interface
procedure WriteTextFileAtomically(const AFileName, AText: string;
  AReplaceExisting: Boolean = True);
implementation
uses
  Classes, SysUtils
  {$IFDEF UNIX}, BaseUnix, Unix{$ENDIF}
  {$IFDEF MSWINDOWS}, Windows{$ENDIF};

procedure WriteTextFileAtomically(const AFileName, AText: string;
  AReplaceExisting: Boolean);
var
  Id: TGUID;
  TempName: string;
  Stream: TFileStream;
  {$IFDEF MSWINDOWS}MoveFlags: DWORD;{$ENDIF}
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
    MoveFlags := MOVEFILE_WRITE_THROUGH;
    if AReplaceExisting then MoveFlags := MoveFlags or MOVEFILE_REPLACE_EXISTING;
    if not MoveFileEx(PChar(TempName), PChar(ExpandFileName(AFileName)), MoveFlags) then
      RaiseLastOSError;
    {$ELSE}
    if AReplaceExisting then
    begin
      if not RenameFile(TempName, ExpandFileName(AFileName)) then
        raise EInOutError.Create('Could not replace file: ' + AFileName);
    end
    else
    begin
      {$IFDEF UNIX}
      // Publishing a same-directory temporary file with link is atomic and
      // refuses an existing destination, including one created after selection.
      if fpLink(PChar(TempName), PChar(ExpandFileName(AFileName))) <> 0 then
        RaiseLastOSError;
      {$ELSE}
      raise EInOutError.Create('Exclusive atomic creation is unsupported');
      {$ENDIF}
    end;
    {$ENDIF}
  finally
    if FileExists(TempName) then
      DeleteFile(TempName);
  end;
end;
end.
