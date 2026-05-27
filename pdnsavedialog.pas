unit PDNSaveDialog;

{$mode objfpc}{$H+}

interface

uses
  Buttons,
  Classes,
  Controls,
  Forms,
  Graphics,
  StdCtrls;

type
  TPDNSaveDialog = class(TForm)
  private
    FBlackEdit: TEdit;
    FBlackLabel: TLabel;
    FCancelButton: TBitBtn;
    FOKButton: TBitBtn;
    FResultCombo: TComboBox;
    FResultLabel: TLabel;
    FWhiteEdit: TEdit;
    FWhiteLabel: TLabel;
  public
    constructor Create(AOwner: TComponent); override;
    function GetBlackName: String;
    function GetResultText: String;
    function GetWhiteName: String;
    procedure SetDefaults(const AWhiteName, ABlackName, AResult: String);
    property WhiteName: String read GetWhiteName;
    property BlackName: String read GetBlackName;
    property ResultText: String read GetResultText;
  end;

implementation

uses
  ExtCtrls;

constructor TPDNSaveDialog.Create(AOwner: TComponent);
var
  ButtonPanel: TPanel;
  ContentPanel: TPanel;
begin
  inherited Create(AOwner);

  Caption := 'Save PDN';
  Width := 380;
  Height := 170;
  Position := poOwnerFormCenter;

  ContentPanel := TPanel.Create(Self);
  ContentPanel.Parent := Self;
  ContentPanel.Align := alClient;
  ContentPanel.BevelOuter := bvNone;
  ContentPanel.BorderSpacing.Around := 12;

  FWhiteLabel := TLabel.Create(ContentPanel);
  FWhiteLabel.Parent := ContentPanel;
  FWhiteLabel.SetBounds(0, 4, 72, 24);
  FWhiteLabel.Layout := tlCenter;
  FWhiteLabel.Caption := 'White';

  FWhiteEdit := TEdit.Create(ContentPanel);
  FWhiteEdit.Parent := ContentPanel;
  FWhiteEdit.SetBounds(82, 0, 260, 28);
  FWhiteEdit.Anchors := [akLeft, akTop, akRight];
  FWhiteEdit.Text := 'White';

  FBlackLabel := TLabel.Create(ContentPanel);
  FBlackLabel.Parent := ContentPanel;
  FBlackLabel.SetBounds(0, 40, 72, 24);
  FBlackLabel.Layout := tlCenter;
  FBlackLabel.Caption := 'Black';

  FBlackEdit := TEdit.Create(ContentPanel);
  FBlackEdit.Parent := ContentPanel;
  FBlackEdit.SetBounds(82, 36, 260, 28);
  FBlackEdit.Anchors := [akLeft, akTop, akRight];
  FBlackEdit.Text := 'Black';

  FResultLabel := TLabel.Create(ContentPanel);
  FResultLabel.Parent := ContentPanel;
  FResultLabel.SetBounds(0, 76, 72, 24);
  FResultLabel.Layout := tlCenter;
  FResultLabel.Caption := 'Result';

  FResultCombo := TComboBox.Create(ContentPanel);
  FResultCombo.Parent := ContentPanel;
  FResultCombo.SetBounds(82, 72, 120, 28);
  FResultCombo.Style := csDropDownList;
  FResultCombo.Items.Add('2-0');
  FResultCombo.Items.Add('1-1');
  FResultCombo.Items.Add('0-2');
  FResultCombo.Items.Add('*');
  FResultCombo.ItemIndex := FResultCombo.Items.IndexOf('*');

  ButtonPanel := TPanel.Create(Self);
  ButtonPanel.Parent := Self;
  ButtonPanel.Align := alBottom;
  ButtonPanel.Height := 44;
  ButtonPanel.BevelOuter := bvNone;

  FOKButton := TBitBtn.Create(ButtonPanel);
  FOKButton.Parent := ButtonPanel;
  FOKButton.Align := alRight;
  FOKButton.Kind := bkOK;
  FOKButton.BorderSpacing.Around := 8;

  FCancelButton := TBitBtn.Create(ButtonPanel);
  FCancelButton.Parent := ButtonPanel;
  FCancelButton.Align := alRight;
  FCancelButton.Kind := bkCancel;
  FCancelButton.BorderSpacing.Around := 8;
end;

procedure TPDNSaveDialog.SetDefaults(const AWhiteName, ABlackName, AResult: String);
begin
  FWhiteEdit.Text := AWhiteName;
  FBlackEdit.Text := ABlackName;
  FResultCombo.ItemIndex := FResultCombo.Items.IndexOf(AResult);
  if FResultCombo.ItemIndex < 0 then
    FResultCombo.ItemIndex := FResultCombo.Items.IndexOf('*');
end;

function TPDNSaveDialog.GetWhiteName: String;
begin
  Result := FWhiteEdit.Text;
end;

function TPDNSaveDialog.GetBlackName: String;
begin
  Result := FBlackEdit.Text;
end;

function TPDNSaveDialog.GetResultText: String;
begin
  Result := FResultCombo.Text;
end;

end.
