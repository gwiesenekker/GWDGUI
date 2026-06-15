unit uScoreHistoryForm;

{$mode objfpc}{$H+}

interface

uses
  Classes, Controls, Forms, uDraughtsBoard, uPreferences,
  uScoreHistoryControl;

type
  TScoreHistoryForm = class(TForm)
  private
    FScoreHistoryControl: TScoreHistoryControl;
  public
    constructor Create(AOwner: TComponent); override;
    procedure UpdateScores(const AAnnotationsText: string; APlyCount,
      ACurrentPly: Integer; AMaxScore: Double; AScale: TScoreScale;
      AStartingSide: TDraughtsSide);
  end;

implementation

constructor TScoreHistoryForm.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  Caption := 'Score history';
  Position := poDesigned;
  BorderStyle := bsSizeable;
  Width := 760;
  Height := 260;
  Constraints.MinWidth := 360;
  Constraints.MinHeight := 180;

  FScoreHistoryControl := TScoreHistoryControl.Create(Self);
  FScoreHistoryControl.Parent := Self;
  FScoreHistoryControl.Align := alClient;
  FScoreHistoryControl.DisplayMode := shdmBars;
  FScoreHistoryControl.ShowEvaluationBar := True;
end;

procedure TScoreHistoryForm.UpdateScores(const AAnnotationsText: string;
  APlyCount, ACurrentPly: Integer; AMaxScore: Double; AScale: TScoreScale;
  AStartingSide: TDraughtsSide);
begin
  FScoreHistoryControl.MaxScore := AMaxScore;
  FScoreHistoryControl.Scale := AScale;
  FScoreHistoryControl.StartingSide := AStartingSide;
  FScoreHistoryControl.PlyCount := APlyCount;
  FScoreHistoryControl.AnnotationsText := AAnnotationsText;
  FScoreHistoryControl.CurrentPly := ACurrentPly;
end;

end.
