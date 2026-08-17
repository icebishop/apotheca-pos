unit UFReports;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  ComCtrls, Grids, StdCtrls, Buttons, ExtCtrls, UReportEngine, UDataModule;

type

  { TFormReports }

  TFormReports = class(TForm)
    ButtonClose: TBitBtn;
    ButtonExportCSV: TBitBtn;
    ButtonRefresh: TBitBtn;
    EditStartDate: TEdit;
    EditEndDate: TEdit;
    LabelEndDate: TLabel;
    LabelStartDate: TLabel;
    PanelBottom: TPanel;
    PanelFilter: TPanel;
    PanelSummaryValuation: TPanel;
    PanelSummaryUtility: TPanel;
    StringGridIncomeUtility: TStringGrid;
    StringGridValuation: TStringGrid;
    TabControlReports: TTabControl;
    procedure ButtonCloseClick(Sender: TObject);
    procedure ButtonExportCSVClick(Sender: TObject);
    procedure ButtonRefreshClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure TabControlReportsChange(Sender: TObject);
  private
    FReportEngine: TReportEngine;
    FIncomeList: TList;
    FValuationList: TList;
    procedure ClearList(AList: TList);
    procedure LoadIncomeUtilityReport;
    procedure LoadInventoryValuationReport;
  public
    { public declarations }
  end;

var
  FormReports: TFormReports;

type
  PIncomeUtilityReportRow = ^TIncomeUtilityReportRow;
  PInventoryValuationRow = ^TInventoryValuationRow;

implementation

{$R *.lfm}

{ TFormReports }

procedure TFormReports.FormCreate(Sender: TObject);
begin
  Caption := 'Reports - Income, Utility & Inventory Valuation';
  TabControlReports.Tabs.Clear;
  TabControlReports.Tabs.Add('Income & Utility Report');
  TabControlReports.Tabs.Add('Inventory Valuation Report');
  TabControlReports.TabIndex := 0;

  EditStartDate.Text := DateToStr(Date - 30);
  EditEndDate.Text := DateToStr(Date);

  // Setup Income Utility Grid Headers
  StringGridIncomeUtility.ColCount := 10;
  StringGridIncomeUtility.Cells[0, 0] := 'Tx ID';
  StringGridIncomeUtility.Cells[1, 0] := 'Date';
  StringGridIncomeUtility.Cells[2, 0] := 'Customer';
  StringGridIncomeUtility.Cells[3, 0] := 'Product';
  StringGridIncomeUtility.Cells[4, 0] := 'Qty';
  StringGridIncomeUtility.Cells[5, 0] := 'Unit Price';
  StringGridIncomeUtility.Cells[6, 0] := 'Unit Cost';
  StringGridIncomeUtility.Cells[7, 0] := 'Total Sale';
  StringGridIncomeUtility.Cells[8, 0] := 'Total Cost';
  StringGridIncomeUtility.Cells[9, 0] := 'Utility ($)';

  // Setup Valuation Grid Headers
  StringGridValuation.ColCount := 8;
  StringGridValuation.Cells[0, 0] := 'Prod ID';
  StringGridValuation.Cells[1, 0] := 'Product Name';
  StringGridValuation.Cells[2, 0] := 'Min Stock';
  StringGridValuation.Cells[3, 0] := 'Max Stock';
  StringGridValuation.Cells[4, 0] := 'Current Stock';
  StringGridValuation.Cells[5, 0] := 'Avg Cost';
  StringGridValuation.Cells[6, 0] := 'Sale Price';
  StringGridValuation.Cells[7, 0] := 'Inventory Value';

  FReportEngine := TReportEngine.Create(DataModule1.SQLite3Connection1);
  FIncomeList := nil;
  FValuationList := nil;

  LoadIncomeUtilityReport;
end;

procedure TFormReports.FormDestroy(Sender: TObject);
begin
  ClearList(FIncomeList);
  ClearList(FValuationList);
  if Assigned(FReportEngine) then FReportEngine.Free;
end;

procedure TFormReports.ClearList(AList: TList);
var
  i: Integer;
begin
  if AList <> nil then
  begin
    for i := 0 to AList.Count - 1 do
      FreeMem(AList[i]);
    AList.Free;
  end;
end;

procedure TFormReports.LoadIncomeUtilityReport;
var
  i: Integer;
  TotSales, TotCosts, TotUtility, MarginPct: Real;
  RowPtr: PIncomeUtilityReportRow;
  StartDateVal, EndDateVal: TDateTime;
begin
  StartDateVal := StrToDateDef(EditStartDate.Text, Date - 30);
  EndDateVal := StrToDateDef(EditEndDate.Text, Date);

  TotSales := 0;
  TotCosts := 0;
  TotUtility := 0;

  ClearList(FIncomeList);
  FIncomeList := FReportEngine.GetIncomeUtilityReport(StartDateVal, EndDateVal, TotSales, TotCosts, TotUtility);

  StringGridIncomeUtility.RowCount := FIncomeList.Count + 1;

  for i := 0 to FIncomeList.Count - 1 do
  begin
    RowPtr := PIncomeUtilityReportRow(FIncomeList[i]);
    StringGridIncomeUtility.Cells[0, i + 1] := IntToStr(RowPtr^.TransactionId);
    StringGridIncomeUtility.Cells[1, i + 1] := DateToStr(RowPtr^.TxDate);
    StringGridIncomeUtility.Cells[2, i + 1] := RowPtr^.CustomerName;
    StringGridIncomeUtility.Cells[3, i + 1] := RowPtr^.ProductName;
    StringGridIncomeUtility.Cells[4, i + 1] := IntToStr(RowPtr^.Quantity);
    StringGridIncomeUtility.Cells[5, i + 1] := Format('%.2f', [RowPtr^.UnitPrice]);
    StringGridIncomeUtility.Cells[6, i + 1] := Format('%.2f', [RowPtr^.UnitCost]);
    StringGridIncomeUtility.Cells[7, i + 1] := Format('%.2f', [RowPtr^.TotalSale]);
    StringGridIncomeUtility.Cells[8, i + 1] := Format('%.2f', [RowPtr^.TotalCost]);
    StringGridIncomeUtility.Cells[9, i + 1] := Format('%.2f', [RowPtr^.Utility]);
  end;

  if TotSales > 0 then
    MarginPct := (TotUtility / TotSales) * 100
  else
    MarginPct := 0;

  PanelSummaryUtility.Caption := Format('Total Revenue: $%.2f   |   Total Product Cost: $%.2f   |   Gross Utility: $%.2f (%.1f%%)',
    [TotSales, TotCosts, TotUtility, MarginPct]);
end;

procedure TFormReports.LoadInventoryValuationReport;
var
  i, TotCount: Integer;
  GrandVal: Real;
  RowPtr: PInventoryValuationRow;
begin
  GrandVal := 0;
  TotCount := 0;

  ClearList(FValuationList);
  FValuationList := FReportEngine.GetInventoryValuationReport(GrandVal, TotCount);

  StringGridValuation.RowCount := FValuationList.Count + 1;

  for i := 0 to FValuationList.Count - 1 do
  begin
    RowPtr := PInventoryValuationRow(FValuationList[i]);
    StringGridValuation.Cells[0, i + 1] := IntToStr(RowPtr^.ProductId);
    StringGridValuation.Cells[1, i + 1] := RowPtr^.ProductName;
    StringGridValuation.Cells[2, i + 1] := IntToStr(RowPtr^.MinStock);
    StringGridValuation.Cells[3, i + 1] := IntToStr(RowPtr^.MaxStock);
    StringGridValuation.Cells[4, i + 1] := IntToStr(RowPtr^.Stock);
    StringGridValuation.Cells[5, i + 1] := Format('%.2f', [RowPtr^.UnitCost]);
    StringGridValuation.Cells[6, i + 1] := Format('%.2f', [RowPtr^.UnitPrice]);
    StringGridValuation.Cells[7, i + 1] := Format('%.2f', [RowPtr^.TotalValue]);
  end;

  PanelSummaryValuation.Caption := Format('Total Product Types: %d   |   Total Inventory Items in Stock: %d   |   Grand Total Valuation: $%.2f',
    [FValuationList.Count, TotCount, GrandVal]);
end;

procedure TFormReports.ButtonRefreshClick(Sender: TObject);
begin
  if TabControlReports.TabIndex = 0 then
    LoadIncomeUtilityReport
  else
    LoadInventoryValuationReport;
end;

procedure TFormReports.TabControlReportsChange(Sender: TObject);
begin
  if TabControlReports.TabIndex = 0 then
  begin
    StringGridIncomeUtility.Visible := True;
    StringGridValuation.Visible := False;
    PanelSummaryUtility.Visible := True;
    PanelSummaryValuation.Visible := False;
    PanelFilter.Visible := True;
    LoadIncomeUtilityReport;
  end
  else
  begin
    StringGridIncomeUtility.Visible := False;
    StringGridValuation.Visible := True;
    PanelSummaryUtility.Visible := False;
    PanelSummaryValuation.Visible := True;
    PanelFilter.Visible := False;
    LoadInventoryValuationReport;
  end;
end;

procedure TFormReports.ButtonExportCSVClick(Sender: TObject);
var
  SaveDialog: TSaveDialog;
  StringList: TStringList;
  i, j: Integer;
  LineStr: String;
  TargetGrid: TStringGrid;
begin
  if TabControlReports.TabIndex = 0 then
    TargetGrid := StringGridIncomeUtility
  else
    TargetGrid := StringGridValuation;

  SaveDialog := TSaveDialog.Create(Self);
  StringList := TStringList.Create;
  try
    SaveDialog.Filter := 'CSV Files (*.csv)|*.csv|Text Files (*.txt)|*.txt';
    SaveDialog.DefaultExt := 'csv';

    if SaveDialog.Execute then
    begin
      for i := 0 to TargetGrid.RowCount - 1 do
      begin
        LineStr := '';
        for j := 0 to TargetGrid.ColCount - 1 do
        begin
          if j > 0 then LineStr := LineStr + ',';
          LineStr := LineStr + '"' + TargetGrid.Cells[j, i] + '"';
        end;
        StringList.Add(LineStr);
      end;
      StringList.SaveToFile(SaveDialog.FileName);
      ShowMessage('Report exported successfully to: ' + SaveDialog.FileName);
    end;
  finally
    StringList.Free;
    SaveDialog.Free;
  end;
end;

procedure TFormReports.ButtonCloseClick(Sender: TObject);
begin
  Close;
end;

end.
