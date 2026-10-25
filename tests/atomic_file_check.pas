program atomic_file_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uAtomicFile;
procedure Check(Condition: Boolean; const Text: string);
begin
  if not Condition then
    raise Exception.Create(Text);
end;
var
  FileName, DirectoryName, NewFile: string;
  Lines: TStringList;
  Search: TSearchRec;
  Raised: Boolean;
begin
  Check(IsTransientPublicationError(5) and IsTransientPublicationError(32) and
    IsTransientPublicationError(33), 'transient Windows sharing and access errors are retried');
  Check(not IsTransientPublicationError(80) and not IsTransientPublicationError(3),
    'existing-file and missing-path errors must not be treated as sharing errors');
  FileName := GetTempFileName(GetTempDir, 'gwd');
  DirectoryName := FileName + '.directory';
  NewFile := FileName + '.Gérard-棋.new';
  Lines := TStringList.Create;
  try
    WriteTextFileAtomically(FileName, 'Original' + #13#10);
    Lines.LoadFromFile(FileName);
    Check(Trim(Lines.Text) = 'Original', 'initial save');
    WriteTextFileAtomically(FileName, 'Replacement' + LineEnding);
    Lines.LoadFromFile(FileName);
    Check(Trim(Lines.Text) = 'Replacement', 'atomic overwrite');
    WriteTextFileAtomically(NewFile, 'First publication', False);
    Raised := False;
    try
      WriteTextFileAtomically(NewFile, 'Must not overwrite', False);
    except
      on E: Exception do Raised := True;
    end;
    Lines.LoadFromFile(NewFile);
    Check(Raised and (Lines.Text = 'First publication' + LineEnding),
      'exclusive publication must preserve a destination that already exists');
    Check(FindFirst(NewFile + '.tmp.*', faAnyFile, Search) <> 0,
      'failed exclusive publication must clean up its temporary file');
    CreateDir(DirectoryName);
    Raised := False;
    try
      WriteTextFileAtomically(DirectoryName, 'Must not replace a directory');
    except
      on E: EInOutError do
        Raised := True;
    end;
    Check(Raised and DirectoryExists(DirectoryName), 'failed replacement must preserve destination');
    Check(FindFirst(DirectoryName + '.tmp.*', faAnyFile, Search) <> 0,
      'failed replacement must clean up its temporary file');
    Lines.LoadFromFile(FileName);
    Check(Trim(Lines.Text) = 'Replacement', 'failure must leave prior successful save intact');
  finally
    DeleteFile(NewFile);
    RemoveDir(DirectoryName);
    DeleteFile(FileName);
    Lines.Free;
  end;
  WriteLn('OK');
end.
