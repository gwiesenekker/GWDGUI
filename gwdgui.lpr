program GWDGUI;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Interfaces,
  Forms,
  uMainForm,
  // The game and its engine protocols register themselves when linked.
  uDraughtsPosition, uDraughtsHubEngine, uDraughtsDxpEngine;

begin
  RequireDerivedFormResource := False;
  Application.Scaled := True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
