unit EngineLogPopup;

{$mode objfpc}{$H+}

interface

uses
  Classes,
  EngineSlot,
  Menus;

procedure SetupEngineLogPopupMenu(AOwner: TComponent; ASlot: TEngineSlot;
  AOnPopup, AOpenClick, AParamsClick, ACloseClick, AAnalyzeClick,
  ATimestampsClick, ASaveClick: TNotifyEvent; AAnalyzeEnabled,
  AShowTimestamps: Boolean);
procedure UpdateEngineLogPopupMenuItems(ASlot: TEngineSlot; AEngineLoaded: Boolean);
procedure UpdateEngineLogAnalyzeMenuItem(ASlot: TEngineSlot; AAnalyzeEnabled,
  AMenuEnabled: Boolean);
procedure UpdateEngineLogTimestampMenuItem(ASlot: TEngineSlot;
  AShowTimestamps: Boolean);

implementation

function AddMenuItem(AMenu: TPopupMenu; ACaption: String; ASlotIndex: Integer;
  AOnClick: TNotifyEvent): TMenuItem;
begin
  Result := TMenuItem.Create(AMenu);
  Result.Caption := ACaption;
  Result.Tag := ASlotIndex;
  Result.OnClick := AOnClick;
  AMenu.Items.Add(Result);
end;

procedure SetupEngineLogPopupMenu(AOwner: TComponent; ASlot: TEngineSlot;
  AOnPopup, AOpenClick, AParamsClick, ACloseClick, AAnalyzeClick,
  ATimestampsClick, ASaveClick: TNotifyEvent; AAnalyzeEnabled,
  AShowTimestamps: Boolean);
begin
  if ASlot = nil then
    Exit;

  ASlot.LogPopupMenu := TPopupMenu.Create(AOwner);
  ASlot.LogPopupMenu.OnPopup := AOnPopup;

  ASlot.OpenMenuItem := AddMenuItem(ASlot.LogPopupMenu, 'Open Engine...',
    ASlot.Index, AOpenClick);
  ASlot.ParamsMenuItem := AddMenuItem(ASlot.LogPopupMenu,
    'Engine Parameters...', ASlot.Index, AParamsClick);
  ASlot.CloseMenuItem := AddMenuItem(ASlot.LogPopupMenu, 'Close Engine',
    ASlot.Index, ACloseClick);

  ASlot.LogPopupMenu.Items.AddSeparator;

  ASlot.AnalyzeMenuItem := AddMenuItem(ASlot.LogPopupMenu, 'Analyze',
    ASlot.Index, AAnalyzeClick);
  ASlot.AnalyzeMenuItem.AutoCheck := False;
  ASlot.AnalyzeMenuItem.Checked := AAnalyzeEnabled;

  ASlot.ShowTimestampsMenuItem := AddMenuItem(ASlot.LogPopupMenu,
    'Show timestamps', ASlot.Index, ATimestampsClick);
  ASlot.ShowTimestampsMenuItem.AutoCheck := False;
  ASlot.ShowTimestampsMenuItem.Checked := AShowTimestamps;

  ASlot.SaveLogMenuItem := AddMenuItem(ASlot.LogPopupMenu, 'Save as...',
    ASlot.Index, ASaveClick);

  if ASlot.LogMemo <> nil then
    ASlot.LogMemo.PopupMenu := ASlot.LogPopupMenu;
end;

procedure UpdateEngineLogPopupMenuItems(ASlot: TEngineSlot; AEngineLoaded: Boolean);
begin
  if ASlot = nil then
    Exit;

  if ASlot.OpenMenuItem <> nil then
    ASlot.OpenMenuItem.Enabled := not AEngineLoaded;
  if ASlot.CloseMenuItem <> nil then
    ASlot.CloseMenuItem.Enabled := AEngineLoaded;
  if ASlot.ParamsMenuItem <> nil then
    ASlot.ParamsMenuItem.Enabled := True;
end;

procedure UpdateEngineLogAnalyzeMenuItem(ASlot: TEngineSlot; AAnalyzeEnabled,
  AMenuEnabled: Boolean);
begin
  if (ASlot = nil) or (ASlot.AnalyzeMenuItem = nil) then
    Exit;

  ASlot.AnalyzeMenuItem.Checked := AAnalyzeEnabled;
  ASlot.AnalyzeMenuItem.Enabled := AMenuEnabled;
end;

procedure UpdateEngineLogTimestampMenuItem(ASlot: TEngineSlot;
  AShowTimestamps: Boolean);
begin
  if (ASlot = nil) or (ASlot.ShowTimestampsMenuItem = nil) then
    Exit;

  ASlot.ShowTimestampsMenuItem.Checked := AShowTimestamps;
end;

end.
