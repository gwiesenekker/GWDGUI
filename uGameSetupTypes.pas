unit uGameSetupTypes;

{$mode objfpc}{$H+}

interface

uses uEngineRegistry, uGameOrchestrator;

type
  TPlayerKind = (pkHuman, pkRegistered);

  TGameSetup = record
    StartingFEN: string;
    WhitePlayer: TPlayerKind;
    BlackPlayer: TPlayerKind;
    WhiteEngine: TExternalEngineDefinition;
    BlackEngine: TExternalEngineDefinition;
    TimeControl: TTimeControl;
  end;

  TGameSetupAcceptedEvent = procedure(Sender: TObject; const ASetup: TGameSetup) of object;

implementation

end.
