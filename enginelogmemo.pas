unit EngineLogMemo;

{$mode objfpc}{$H+}

interface

uses
  StdCtrls;

procedure AppendEngineLogMemoText(AMemo: TMemo; const AText: String);
procedure SaveEngineLogMemoToFile(AMemo: TMemo; const AFileName: String);

implementation

procedure AppendEngineLogMemoText(AMemo: TMemo; const AText: String);
begin
  if AText = '' then
    Exit;
  if AMemo = nil then
    Exit;

  AMemo.SelStart := Length(AMemo.Text);
  AMemo.SelText := AText;
  AMemo.SelStart := Length(AMemo.Text);
end;

procedure SaveEngineLogMemoToFile(AMemo: TMemo; const AFileName: String);
begin
  if AMemo = nil then
    Exit;
  if AFileName = '' then
    Exit;

  AMemo.Lines.SaveToFile(AFileName);
end;

end.
