unit uEnginesDialog;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Dialogs, Forms, Grids, Menus, SysUtils,
  uEngineEditForm, uEngineRegistry, uGuiDialogs;

type
  TEnginesDialog = class(TForm)
  private
    FAddForm: TEngineEditForm;
    FEditingIndex: Integer;
    FEngines: TExternalEngineList;
    FGrid: TStringGrid;
    FRegistryFileName: string;
    procedure AddEngineClick(Sender: TObject);
    procedure DeleteEngineClick(Sender: TObject);
    function DxpPortConflict(AEngine: TExternalEngineDefinition;
      out AOtherEngineName: string): Boolean;
    function ProtocolIdConflict(AEngine: TExternalEngineDefinition;
      out AOtherEngineName: string): Boolean;
    procedure EditEngineClick(Sender: TObject);
    procedure EngineAccepted(Sender: TObject; AEngine: TExternalEngineDefinition;
      var AAccepted: Boolean);
    procedure OpenEngineEditor(AIndex: Integer);
    procedure RefreshGrid;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Engines: TExternalEngineList read FEngines;
  end;

implementation

constructor TEnginesDialog.Create(AOwner: TComponent);
var
  LItem: TMenuItem;
  LPopup: TPopupMenu;
begin
  inherited Create(AOwner);

  Caption := 'Engines';
  Position := poDesigned;
  Width := 820;
  Height := 420;
  Constraints.MinWidth := 560;
  Constraints.MinHeight := 300;

  FEngines := TExternalEngineList.Create;
  FEditingIndex := -1;
  FRegistryFileName := EnginesJsonFileName;

  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align := alClient;
  FGrid.FixedCols := 0;
  FGrid.FixedRows := 1;
  FGrid.ColCount := 4;
  FGrid.RowCount := 1;
  FGrid.Options := FGrid.Options + [goRowSelect] - [goEditing];
  FGrid.OnDblClick := @EditEngineClick;
  FGrid.Cells[0, 0] := 'Exe path';
  FGrid.Cells[1, 0] := 'Executable';
  FGrid.Cells[2, 0] := 'Hub id';
  FGrid.Cells[3, 0] := 'DXP id';
  FGrid.ColWidths[0] := 360;
  FGrid.ColWidths[1] := 160;
  FGrid.ColWidths[2] := 130;
  FGrid.ColWidths[3] := 130;

  LPopup := TPopupMenu.Create(Self);
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'Add engine...';
  LItem.OnClick := @AddEngineClick;
  LPopup.Items.Add(LItem);
  LItem := TMenuItem.Create(Self);
  LItem.Caption := 'Delete engine';
  LItem.OnClick := @DeleteEngineClick;
  LPopup.Items.Add(LItem);
  FGrid.PopupMenu := LPopup;
  LoadExternalEngines(FRegistryFileName, FEngines);
  RefreshGrid;
end;

destructor TEnginesDialog.Destroy;
begin
  FreeAndNil(FAddForm);
  FEngines.Free;
  inherited Destroy;
end;

procedure TEnginesDialog.AddEngineClick(Sender: TObject);
begin
  FEditingIndex := -1;
  if FAddForm = nil then
  begin
    FAddForm := TEngineEditForm.Create(Self);
    FAddForm.OnAccepted := @EngineAccepted;
  end;
  FAddForm.LoadEngine(nil);
  ShowFormCenteredOnOwner(FAddForm, Self);
end;

procedure TEnginesDialog.DeleteEngineClick(Sender: TObject);
var
  Index: Integer;
begin
  Index := FGrid.Row - 1;
  if (Index < 0) or (Index >= FEngines.Count) then
    Exit;
  FEngines.Delete(Index);
  SaveExternalEngines(FRegistryFileName, FEngines);
  RefreshGrid;
end;

procedure TEnginesDialog.EditEngineClick(Sender: TObject);
begin
  OpenEngineEditor(FGrid.Row - 1);
end;

function TEnginesDialog.DxpPortConflict(AEngine: TExternalEngineDefinition;
  out AOtherEngineName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  AOtherEngineName := '';
  if (AEngine = nil) or (AEngine.Kind <> eekDxp) then
    Exit;

  for I := 0 to FEngines.Count - 1 do
  begin
    if I = FEditingIndex then
      Continue;
    if FEngines[I].Kind <> eekDxp then
      Continue;
    if FEngines[I].DxpPort <> AEngine.DxpPort then
      Continue;

    AOtherEngineName := Trim(FEngines[I].IdText);
    if AOtherEngineName = '' then
      AOtherEngineName := FEngines[I].ExecutableName;
    if AOtherEngineName = '' then
      AOtherEngineName := FEngines[I].ExePath;
    Exit(True);
  end;
end;

function TEnginesDialog.ProtocolIdConflict(AEngine: TExternalEngineDefinition;
  out AOtherEngineName: string): Boolean;
var
  I: Integer;
  IdText: string;
begin
  Result := False;
  AOtherEngineName := '';
  if AEngine = nil then
    Exit;

  IdText := Trim(AEngine.IdText);
  if IdText = '' then
    Exit;

  for I := 0 to FEngines.Count - 1 do
  begin
    if I = FEditingIndex then
      Continue;
    if FEngines[I].Kind <> AEngine.Kind then
      Continue;
    if not SameText(Trim(FEngines[I].IdText), IdText) then
      Continue;

    AOtherEngineName := FEngines[I].ExecutableName;
    if AOtherEngineName = '' then
      AOtherEngineName := FEngines[I].ExePath;
    Exit(True);
  end;
end;

procedure TEnginesDialog.EngineAccepted(Sender: TObject;
  AEngine: TExternalEngineDefinition; var AAccepted: Boolean);
var
  Copy: TExternalEngineDefinition;
  OtherEngineName: string;
begin
  AAccepted := False;
  if AEngine = nil then
    Exit;
  if ProtocolIdConflict(AEngine, OtherEngineName) then
  begin
    ShowGuiOkDialog(Self, 'Engines',
      UpperCase(AEngine.KindText) + ' ID "' + AEngine.IdText +
      '" is already used by ' + OtherEngineName + '.');
    Exit;
  end;
  if DxpPortConflict(AEngine, OtherEngineName) then
  begin
    ShowGuiOkDialog(Self, 'Engines',
      'DXP port ' + IntToStr(AEngine.DxpPort) +
      ' is already used by ' + OtherEngineName + '.');
    Exit;
  end;
  if (FEditingIndex >= 0) and (FEditingIndex < FEngines.Count) then
    FEngines[FEditingIndex].Assign(AEngine)
  else
  begin
    Copy := TExternalEngineDefinition.Create;
    Copy.Assign(AEngine);
    FEngines.Add(Copy);
  end;
  FEditingIndex := -1;
  SaveExternalEngines(FRegistryFileName, FEngines);
  RefreshGrid;
  AAccepted := True;
end;

procedure TEnginesDialog.OpenEngineEditor(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= FEngines.Count) then
    Exit;

  FEditingIndex := AIndex;
  if FAddForm = nil then
  begin
    FAddForm := TEngineEditForm.Create(Self);
    FAddForm.OnAccepted := @EngineAccepted;
  end;
  FAddForm.LoadEngine(FEngines[AIndex]);
  ShowFormCenteredOnOwner(FAddForm, Self);
end;

procedure TEnginesDialog.RefreshGrid;
var
  Engine: TExternalEngineDefinition;
  I: Integer;
begin
  FGrid.RowCount := FEngines.Count + 1;
  for I := 0 to FEngines.Count - 1 do
  begin
    Engine := FEngines[I];
    FGrid.Cells[0, I + 1] := Engine.ExePath;
    FGrid.Cells[1, I + 1] := Engine.ExecutableName;
    FGrid.Cells[2, I + 1] := Engine.HubId;
    FGrid.Cells[3, I + 1] := Engine.DxpId;
  end;
end;

end.
