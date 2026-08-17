{ Apothêca

  Copyright (C) 2010 Ice icebishop@gmail.com

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
}

unit UFrameReports;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ComCtrls, Grids, StdCtrls, Buttons, ExtCtrls, EditBtn,
  UReportEngine, UDataModule, UGridUtils;

type

  PIncomeUtilityReportRow = ^TIncomeUtilityReportRow;
  PInventoryValuationRow = ^TInventoryValuationRow;
  PPurchaseReportRow = ^TPurchaseReportRow;

  { TFrameReports }

  TFrameReports = class(TFrame)
    BtnExportCSV: TBitBtn;
    BtnRefresh: TBitBtn;
    DateFrom: TDateEdit;
    DateTo: TDateEdit;
    GridDetail: TStringGrid;
    GridReport: TStringGrid;
    LabelDateFrom: TLabel;
    LabelDateTo: TLabel;
    LabelTitle: TLabel;
    PanelTop: TPanel;
    SplitterDetail: TSplitter;
    TabControl: TTabControl;
    procedure BtnExportCSVClick(Sender: TObject);
    procedure BtnRefreshClick(Sender: TObject);
    procedure GridReportSelection(Sender: TObject; aCol, aRow: Integer);
    procedure TabControlChange(Sender: TObject);
  private
    FReportEngine: TReportEngine;
    FIncomeList: TList;
    FValuationList: TList;
    FPurchaseList: TList;
    FPurchaseMasterIds: TList; { TList of PInteger - operation IDs for master rows }
    FInitialized: Boolean;
    procedure ClearList(var AList: TList);
    procedure ClearMasterIds;
    procedure LoadIncomeUtilityReport;
    procedure LoadInventoryValuationReport;
    procedure LoadPurchaseReport;
    procedure LoadPurchaseDetail(AOperationId: Integer);
    procedure SetupIncomeGridHeaders;
    procedure SetupValuationGridHeaders;
    procedure SetupPurchaseMasterHeaders;
    procedure SetupPurchaseDetailHeaders;
    procedure ShowDetailGrid(AVisible: Boolean);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure InitReports;
  end;

implementation

{$R *.lfm}

{ TFrameReports }

constructor TFrameReports.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FIncomeList := nil;
  FValuationList := nil;
  FPurchaseList := nil;
  FPurchaseMasterIds := nil;
  FReportEngine := nil;
  FInitialized := False;
end;

destructor TFrameReports.Destroy;
begin
  ClearList(FIncomeList);
  ClearList(FValuationList);
  ClearList(FPurchaseList);
  ClearMasterIds;
  if Assigned(FReportEngine) then
    FReportEngine.Free;
  inherited Destroy;
end;

procedure TFrameReports.InitReports;
begin
  if FInitialized then Exit;
  FInitialized := True;

  DateFrom.Date := Date - 30;
  DateTo.Date := Date;

  TabControl.Tabs.Clear;
  TabControl.Tabs.Add('Ingresos y Utilidad');
  TabControl.Tabs.Add('Valoración Inventario');
  TabControl.Tabs.Add('Compras');
  TabControl.TabIndex := 0;

  FReportEngine := TReportEngine.Create(DataModule1.SQLite3Connection1);

  SetupIncomeGridHeaders;
  LoadIncomeUtilityReport;
end;

procedure TFrameReports.SetupIncomeGridHeaders;
begin
  GridReport.Clear;
  GridReport.ColCount := 6;
  GridReport.RowCount := 2;
  GridReport.FixedRows := 1;
  GridReport.Cells[0, 0] := 'ID Venta';
  GridReport.Cells[1, 0] := 'Fecha';
  GridReport.Cells[2, 0] := 'Cliente';
  GridReport.Cells[3, 0] := 'Total Venta';
  GridReport.Cells[4, 0] := 'Total Costo';
  GridReport.Cells[5, 0] := 'Utilidad';
  DistributeColumns(GridReport, [10, 15, 25, 18, 18, 14]);
end;

procedure TFrameReports.SetupValuationGridHeaders;
begin
  GridReport.Clear;
  GridReport.ColCount := 8;
  GridReport.RowCount := 2;
  GridReport.FixedRows := 1;
  GridReport.Cells[0, 0] := 'ID Prod';
  GridReport.Cells[1, 0] := 'Producto';
  GridReport.Cells[2, 0] := 'Stock Mín';
  GridReport.Cells[3, 0] := 'Stock Máx';
  GridReport.Cells[4, 0] := 'Stock Actual';
  GridReport.Cells[5, 0] := 'Costo Prom.';
  GridReport.Cells[6, 0] := 'Precio Venta';
  GridReport.Cells[7, 0] := 'Valor Inventario';
  DistributeColumns(GridReport, [8, 22, 10, 10, 12, 13, 13, 12]);
end;

procedure TFrameReports.ClearList(var AList: TList);
var
  i: Integer;
begin
  if AList <> nil then
  begin
    for i := 0 to AList.Count - 1 do
      FreeMem(AList[i]);
    AList.Free;
    AList := nil;
  end;
end;

procedure TFrameReports.LoadIncomeUtilityReport;
var
  i: Integer;
  TotSales, TotCosts, TotUtility: Real;
  RowPtr: PIncomeUtilityReportRow;
  StartDateVal, EndDateVal: TDateTime;
begin
  if not Assigned(FReportEngine) then Exit;

  StartDateVal := DateFrom.Date;
  EndDateVal := DateTo.Date;

  TotSales := 0;
  TotCosts := 0;
  TotUtility := 0;

  ClearList(FIncomeList);
  FIncomeList := FReportEngine.GetIncomeUtilityReport(StartDateVal, EndDateVal,
    TotSales, TotCosts, TotUtility);

  SetupIncomeGridHeaders;

  if FIncomeList.Count > 0 then
    GridReport.RowCount := FIncomeList.Count + 2  { +1 header, +1 totals row }
  else
    GridReport.RowCount := 2;

  for i := 0 to FIncomeList.Count - 1 do
  begin
    RowPtr := PIncomeUtilityReportRow(FIncomeList[i]);
    GridReport.Cells[0, i + 1] := IntToStr(RowPtr^.TransactionId);
    GridReport.Cells[1, i + 1] := DateToStr(RowPtr^.TxDate);
    GridReport.Cells[2, i + 1] := RowPtr^.CustomerName;
    GridReport.Cells[3, i + 1] := Format('%.2f', [RowPtr^.TotalSale]);
    GridReport.Cells[4, i + 1] := Format('%.2f', [RowPtr^.TotalCost]);
    GridReport.Cells[5, i + 1] := Format('%.2f', [RowPtr^.Utility]);
  end;

  { Add totals summary row at the bottom }
  if FIncomeList.Count > 0 then
  begin
    GridReport.Cells[0, FIncomeList.Count + 1] := '';
    GridReport.Cells[1, FIncomeList.Count + 1] := '';
    GridReport.Cells[2, FIncomeList.Count + 1] := 'TOTALES:';
    GridReport.Cells[3, FIncomeList.Count + 1] := Format('%.2f', [TotSales]);
    GridReport.Cells[4, FIncomeList.Count + 1] := Format('%.2f', [TotCosts]);
    GridReport.Cells[5, FIncomeList.Count + 1] := Format('%.2f', [TotUtility]);
  end;
end;

procedure TFrameReports.LoadInventoryValuationReport;
var
  i, TotCount: Integer;
  GrandVal: Real;
  RowPtr: PInventoryValuationRow;
begin
  if not Assigned(FReportEngine) then Exit;

  GrandVal := 0;
  TotCount := 0;

  ClearList(FValuationList);
  FValuationList := FReportEngine.GetInventoryValuationReport(GrandVal, TotCount);

  SetupValuationGridHeaders;

  if FValuationList.Count > 0 then
    GridReport.RowCount := FValuationList.Count + 1
  else
    GridReport.RowCount := 2;

  for i := 0 to FValuationList.Count - 1 do
  begin
    RowPtr := PInventoryValuationRow(FValuationList[i]);
    GridReport.Cells[0, i + 1] := IntToStr(RowPtr^.ProductId);
    GridReport.Cells[1, i + 1] := RowPtr^.ProductName;
    GridReport.Cells[2, i + 1] := IntToStr(RowPtr^.MinStock);
    GridReport.Cells[3, i + 1] := IntToStr(RowPtr^.MaxStock);
    GridReport.Cells[4, i + 1] := IntToStr(RowPtr^.Stock);
    GridReport.Cells[5, i + 1] := Format('%.2f', [RowPtr^.UnitCost]);
    GridReport.Cells[6, i + 1] := Format('%.2f', [RowPtr^.UnitPrice]);
    GridReport.Cells[7, i + 1] := Format('%.2f', [RowPtr^.TotalValue]);
  end;

  { Add totals row at the bottom }
  if FValuationList.Count > 0 then
  begin
    GridReport.RowCount := FValuationList.Count + 2;
    GridReport.Cells[0, FValuationList.Count + 1] := '';
    GridReport.Cells[1, FValuationList.Count + 1] := 'TOTAL INVENTARIO:';
    GridReport.Cells[2, FValuationList.Count + 1] := '';
    GridReport.Cells[3, FValuationList.Count + 1] := '';
    GridReport.Cells[4, FValuationList.Count + 1] := IntToStr(TotCount);
    GridReport.Cells[5, FValuationList.Count + 1] := '';
    GridReport.Cells[6, FValuationList.Count + 1] := '';
    GridReport.Cells[7, FValuationList.Count + 1] := Format('%.2f', [GrandVal]);
  end;
end;

procedure TFrameReports.BtnRefreshClick(Sender: TObject);
begin
  case TabControl.TabIndex of
    0: LoadIncomeUtilityReport;
    1: LoadInventoryValuationReport;
    2: LoadPurchaseReport;
  end;
end;

procedure TFrameReports.TabControlChange(Sender: TObject);
begin
  case TabControl.TabIndex of
    0: begin ShowDetailGrid(False); LoadIncomeUtilityReport; end;
    1: begin ShowDetailGrid(False); LoadInventoryValuationReport; end;
    2: begin ShowDetailGrid(True); LoadPurchaseReport; end;
  end;
end;

procedure TFrameReports.GridReportSelection(Sender: TObject; aCol, aRow: Integer);
var
  OpId: Integer;
  PId: PInteger;
begin
  { Only handle master-detail in Compras tab }
  if TabControl.TabIndex <> 2 then Exit;
  if (aRow < 1) or (FPurchaseMasterIds = nil) then Exit;
  if (aRow - 1) >= FPurchaseMasterIds.Count then Exit;

  PId := PInteger(FPurchaseMasterIds[aRow - 1]);
  OpId := PId^;
  LoadPurchaseDetail(OpId);
end;

procedure TFrameReports.ShowDetailGrid(AVisible: Boolean);
begin
  if AVisible then
  begin
    GridReport.Align := alTop;
    GridReport.Height := 200;
    SplitterDetail.Visible := True;
    GridDetail.Visible := True;
  end
  else
  begin
    SplitterDetail.Visible := False;
    GridDetail.Visible := False;
    GridReport.Align := alClient;
  end;
end;

procedure TFrameReports.ClearMasterIds;
var
  i: Integer;
begin
  if FPurchaseMasterIds <> nil then
  begin
    for i := 0 to FPurchaseMasterIds.Count - 1 do
      Dispose(PInteger(FPurchaseMasterIds[i]));
    FPurchaseMasterIds.Free;
    FPurchaseMasterIds := nil;
  end;
end;

procedure TFrameReports.SetupPurchaseMasterHeaders;
begin
  GridReport.Clear;
  GridReport.ColCount := 4;
  GridReport.RowCount := 2;
  GridReport.FixedRows := 1;
  GridReport.Cells[0, 0] := 'ID';
  GridReport.Cells[1, 0] := 'Fecha';
  GridReport.Cells[2, 0] := 'Proveedor';
  GridReport.Cells[3, 0] := 'Total';
  DistributeColumns(GridReport, [10, 20, 45, 25]);
end;

procedure TFrameReports.SetupPurchaseDetailHeaders;
begin
  GridDetail.Clear;
  GridDetail.ColCount := 5;
  GridDetail.RowCount := 2;
  GridDetail.FixedRows := 1;
  GridDetail.Cells[0, 0] := 'Producto';
  GridDetail.Cells[1, 0] := 'Cantidad';
  GridDetail.Cells[2, 0] := 'Costo Unit.';
  GridDetail.Cells[3, 0] := 'Precio Venta';
  GridDetail.Cells[4, 0] := 'Total';
  DistributeColumns(GridDetail, [35, 15, 18, 18, 14]);
end;

procedure TFrameReports.LoadPurchaseReport;
var
  i: Integer;
  TotPurchases: Real;
  RowPtr: PPurchaseReportRow;
  StartDateVal, EndDateVal: TDateTime;
  LastId, MasterRow: Integer;
  MasterTotal: Real;
  PId: PInteger;
begin
  if not Assigned(FReportEngine) then Exit;

  StartDateVal := DateFrom.Date;
  EndDateVal := DateTo.Date;
  TotPurchases := 0;

  ClearList(FPurchaseList);
  ClearMasterIds;
  FPurchaseList := FReportEngine.GetPurchaseReport(StartDateVal, EndDateVal, TotPurchases);
  FPurchaseMasterIds := TList.Create;

  SetupPurchaseMasterHeaders;
  SetupPurchaseDetailHeaders;

  { Build master rows: one per unique operation ID }
  GridReport.RowCount := 2;
  LastId := -1;
  MasterRow := 0;
  MasterTotal := 0;

  for i := 0 to FPurchaseList.Count - 1 do
  begin
    RowPtr := PPurchaseReportRow(FPurchaseList[i]);
    if RowPtr^.TransactionId <> LastId then
    begin
      { Write total for previous master row }
      if (MasterRow > 0) then
        GridReport.Cells[3, MasterRow] := Format('%.2f', [MasterTotal]);

      Inc(MasterRow);
      GridReport.RowCount := MasterRow + 1;
      GridReport.Cells[0, MasterRow] := IntToStr(RowPtr^.TransactionId);
      GridReport.Cells[1, MasterRow] := DateToStr(RowPtr^.TxDate);
      GridReport.Cells[2, MasterRow] := RowPtr^.SupplierName;
      MasterTotal := 0;
      LastId := RowPtr^.TransactionId;

      New(PId);
      PId^ := RowPtr^.TransactionId;
      FPurchaseMasterIds.Add(PId);
    end;
    MasterTotal := MasterTotal + RowPtr^.TotalCost;
  end;
  { Write total for last master row }
  if MasterRow > 0 then
    GridReport.Cells[3, MasterRow] := Format('%.2f', [MasterTotal]);

  { Clear detail grid }
  GridDetail.RowCount := 2;
  GridDetail.Cells[0, 1] := '';
  GridDetail.Cells[1, 1] := '';
  GridDetail.Cells[2, 1] := '';
  GridDetail.Cells[3, 1] := '';
  GridDetail.Cells[4, 1] := '';

  { Auto-select first row if available }
  if (FPurchaseMasterIds.Count > 0) then
    LoadPurchaseDetail(PInteger(FPurchaseMasterIds[0])^);
end;

procedure TFrameReports.LoadPurchaseDetail(AOperationId: Integer);
var
  i, DetailRow: Integer;
  RowPtr: PPurchaseReportRow;
begin
  SetupPurchaseDetailHeaders;
  DetailRow := 0;

  for i := 0 to FPurchaseList.Count - 1 do
  begin
    RowPtr := PPurchaseReportRow(FPurchaseList[i]);
    if RowPtr^.TransactionId = AOperationId then
    begin
      Inc(DetailRow);
      GridDetail.RowCount := DetailRow + 1;
      GridDetail.Cells[0, DetailRow] := RowPtr^.ProductName;
      GridDetail.Cells[1, DetailRow] := IntToStr(RowPtr^.Quantity);
      GridDetail.Cells[2, DetailRow] := Format('%.2f', [RowPtr^.UnitCost]);
      GridDetail.Cells[3, DetailRow] := Format('%.2f', [RowPtr^.UnitPrice]);
      GridDetail.Cells[4, DetailRow] := Format('%.2f', [RowPtr^.TotalCost]);
    end;
  end;

  if DetailRow = 0 then
    GridDetail.RowCount := 2;
end;

procedure TFrameReports.BtnExportCSVClick(Sender: TObject);
var
  SaveDialog: TSaveDialog;
  StringList: TStringList;
  i, j: Integer;
  LineStr: String;
begin
  SaveDialog := TSaveDialog.Create(Self);
  StringList := TStringList.Create;
  try
    SaveDialog.Filter := 'CSV Files (*.csv)|*.csv|Text Files (*.txt)|*.txt';
    SaveDialog.DefaultExt := 'csv';
    SaveDialog.Title := 'Exportar Reporte a CSV';

    if SaveDialog.Execute then
    begin
      for i := 0 to GridReport.RowCount - 1 do
      begin
        LineStr := '';
        for j := 0 to GridReport.ColCount - 1 do
        begin
          if j > 0 then
            LineStr := LineStr + ',';
          LineStr := LineStr + '"' + GridReport.Cells[j, i] + '"';
        end;
        StringList.Add(LineStr);
      end;
      StringList.SaveToFile(SaveDialog.FileName);
      ShowMessage('Reporte exportado exitosamente a: ' + SaveDialog.FileName);
    end;
  finally
    StringList.Free;
    SaveDialog.Free;
  end;
end;

end.
