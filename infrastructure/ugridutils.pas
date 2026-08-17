{ Apothêca - Grid utility functions }
unit UGridUtils;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Grids;

{ Distributes column widths proportionally based on percentage weights.
  Percentages array must have Grid.ColCount elements summing to 100. }
procedure DistributeColumns(Grid: TStringGrid; const Percentages: array of Integer);

implementation

procedure DistributeColumns(Grid: TStringGrid; const Percentages: array of Integer);
var
  i, AvailWidth, ColW: Integer;
  TotalPct: Integer;
begin
  if Grid = nil then Exit;
  if Length(Percentages) <> Grid.ColCount then Exit;

  { Available width minus grid lines }
  AvailWidth := Grid.ClientWidth - (Grid.ColCount + 1) * Grid.GridLineWidth;
  if AvailWidth < 50 then Exit;

  TotalPct := 0;
  for i := 0 to High(Percentages) do
    TotalPct := TotalPct + Percentages[i];
  if TotalPct = 0 then Exit;

  for i := 0 to Grid.ColCount - 1 do
  begin
    ColW := (AvailWidth * Percentages[i]) div TotalPct;
    if ColW < 20 then ColW := 20;
    Grid.ColWidths[i] := ColW;
  end;
end;

end.
