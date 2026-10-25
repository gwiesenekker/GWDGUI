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
  Stream: THandleStream;
  {$IFDEF MSWINDOWS}
  MoveFlags, MoveError: DWORD;
  Attempt: Integer;
  WideTemp, WideTarget: UnicodeString;
  TempHandle: THandle;
  {$ENDIF}
  {$IFDEF UNIX}Reservation: cint; LinkError: cint;{$ENDIF}
begin
  if CreateGUID(Id) <> 0 then
    raise EInOutError.Create('Could not create a temporary file name');
  TempName := ExpandFileName(AFileName) + '.tmp.' + GUIDToString(Id);
  try
    {$IFDEF MSWINDOWS}
    WideTemp := UTF8Decode(TempName);
    TempHandle := CreateFileW(PWideChar(WideTemp), GENERIC_WRITE, FILE_SHARE_READ,
      nil, CREATE_NEW, FILE_ATTRIBUTE_NORMAL, 0);
    if TempHandle = INVALID_HANDLE_VALUE then RaiseLastOSError;
    Stream := THandleStream.Create(TempHandle);
    {$ELSE}
    Stream := TFileStream.Create(TempName, fmCreate);
    {$ENDIF}
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
      {$IFDEF MSWINDOWS}CloseHandle(TempHandle);{$ENDIF}
    end;
    {$IFDEF MSWINDOWS}
    MoveFlags := MOVEFILE_WRITE_THROUGH;
    if AReplaceExisting then MoveFlags := MoveFlags or MOVEFILE_REPLACE_EXISTING;
    WideTemp := UTF8Decode(TempName);
    WideTarget := UTF8Decode(ExpandFileName(AFileName));
    for Attempt := 0 to 5 do
    begin
      if MoveFileExW(PWideChar(WideTemp), PWideChar(WideTarget), MoveFlags) then Break;
      MoveError := GetLastError;
      if (Attempt = 5) or not (MoveError in [ERROR_SHARING_VIOLATION, ERROR_LOCK_VIOLATION]) then
        RaiseLastOSError(MoveError);
      Sleep(20 shl Attempt);
    end;
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
      {$IFDEF GWDGUI_TEST_NO_HARDLINK}
      LinkError := ESysEOPNOTSUPP;
      {$ELSE}
      if fpLink(PChar(TempName), PChar(ExpandFileName(AFileName))) = 0 then Exit;
      LinkError := fpGetErrno;
      {$ENDIF}
      if not (LinkError in [ESysEOPNOTSUPP, ESysEPERM, ESysENOSYS]) then
        raise EOSError.CreateFmt('Could not publish file: %s (error %d)', [AFileName, LinkError]);
      // Filesystems without hard links can still reserve a new name exclusively.
      // A crash before rename leaves an empty, recoverable projection, never a
      // partial replacement of a pre-existing file.
      Reservation := fpOpen(PChar(ExpandFileName(AFileName)), O_WRONLY or O_CREAT or O_EXCL, &600);
      if Reservation < 0 then RaiseLastOSError;
      fpClose(Reservation);
      if not RenameFile(TempName, ExpandFileName(AFileName)) then
      begin
        DeleteFile(AFileName);
        raise EInOutError.Create('Could not publish reserved file: ' + AFileName);
      end;
      {$ELSE}
      raise EInOutError.Create('Exclusive atomic creation is unsupported');
      {$ENDIF}
    end;
    {$ENDIF}
  finally
    {$IFDEF MSWINDOWS}
    DeleteFileW(PWideChar(UTF8Decode(TempName)));
    {$ELSE}
    if FileExists(TempName) then DeleteFile(TempName);
    {$ENDIF}
  end;
end;
end.
