program atomic_file_check;
{$mode objfpc}{$H+}
uses Classes, SysUtils, uAtomicFile;
procedure Check(Condition: Boolean; const Text: string);
begin
  if not Condition then
    raise Exception.Create(Text);
end;
var
  FileName, DirectoryName: string;
  Lines: TStringList;
  Search: TSearchRec;
  Raised: Boolean;
begin
  FileName := GetTempFileName(GetTempDir, 'gwd');
  DirectoryName := FileName + '.directory';
  Lines := TStringList.Create;
  try
    WriteTextFileAtomically(FileName, 'Original' + #13#10);
    Lines.LoadFromFile(FileName);
    Check(Trim(Lines.Text) = 'Original', 'initial save');
    WriteTextFileAtomically(FileName, 'Replacement' + LineEnding);
    Lines.LoadFromFile(FileName);
    Check(Trim(Lines.Text) = 'Replacement', 'atomic overwrite');
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
    RemoveDir(DirectoryName);
    DeleteFile(FileName);
    Lines.Free;
  end;
  WriteLn('OK');
end.
