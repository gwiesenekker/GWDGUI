unit TournamentFiles;

{$mode objfpc}{$H+}

interface

uses
  Classes;

function SelectTournamentOpenFile(AOwner: TComponent; out AFileName: String): Boolean;
function SelectTournamentSaveFile(AOwner: TComponent; const ACurrentFileName,
  ATournamentName: String; out AFileName: String): Boolean;

implementation

uses
  Dialogs,
  SysUtils;

const
  TournamentFileFilter = 'Tournament files (*.json)|*.json|All files (*.*)|*.*';

function DefaultTournamentSaveFileName(const ACurrentFileName,
  ATournamentName: String): String;
begin
  if ACurrentFileName <> '' then
    Exit(ACurrentFileName);
  if Trim(ATournamentName) <> '' then
    Exit(Trim(ATournamentName) + '.json');
  Result := 'Tournament.json';
end;

function SelectTournamentOpenFile(AOwner: TComponent; out AFileName: String): Boolean;
var
  OpenDialog: TOpenDialog;
begin
  Result := False;
  AFileName := '';
  OpenDialog := TOpenDialog.Create(AOwner);
  try
    OpenDialog.Title := 'Load tournament';
    OpenDialog.Filter := TournamentFileFilter;
    OpenDialog.Options := OpenDialog.Options + [ofFileMustExist];
    if not OpenDialog.Execute then
      Exit;
    AFileName := OpenDialog.FileName;
    Result := True;
  finally
    OpenDialog.Free;
  end;
end;

function SelectTournamentSaveFile(AOwner: TComponent; const ACurrentFileName,
  ATournamentName: String; out AFileName: String): Boolean;
var
  SaveDialog: TSaveDialog;
begin
  Result := False;
  AFileName := '';
  SaveDialog := TSaveDialog.Create(AOwner);
  try
    SaveDialog.Title := 'Save tournament';
    SaveDialog.Filter := TournamentFileFilter;
    SaveDialog.DefaultExt := 'json';
    SaveDialog.FileName := DefaultTournamentSaveFileName(ACurrentFileName,
      ATournamentName);
    SaveDialog.Options := SaveDialog.Options + [ofOverwritePrompt];
    if not SaveDialog.Execute then
      Exit;
    AFileName := SaveDialog.FileName;
    Result := True;
  finally
    SaveDialog.Free;
  end;
end;

end.
