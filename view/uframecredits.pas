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

unit UFrameCredits;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Grids, Buttons, ExtCtrls,
  ComCtrls, Dialogs, EditBtn,
  UCreditService, UDebtorInfo, UCreditSaleInfo, UPay, UGridUtils,
  UResourceString, LazLogger;

type

  { TFrameCredits }

  TFrameCredits = class(TFrame)
    BtnRegisterPayment: TBitBtn;
    DateEditPay: TDateEdit;
    EditPayAmount: TEdit;
    EditSearch: TEdit;
    GridCreditSales: TStringGrid;
    GridDebtors: TStringGrid;
    GridPayments: TStringGrid;
    LabelPayAmount: TLabel;
    LabelPayDate: TLabel;
    LabelPaymentTotal: TLabel;
    LabelSummaryTotal: TLabel;
    LabelTitle: TLabel;
    PanelBottom: TPanel;
    PanelPayEntry: TPanel;
    PanelPayments: TPanel;
    PanelTop: TPanel;
    SplitterMain: TSplitter;
    TabControlDetail: TTabControl;
    procedure OnDebtorSelected(Sender: TObject; aCol, aRow: Integer);
    procedure OnDebtorClick(Sender: TObject);
    procedure OnCreditSaleSelected(Sender: TObject; aCol, aRow: Integer);
    procedure OnRegisterPayment(Sender: TObject);
    procedure OnSearchChange(Sender: TObject);
    procedure OnTabChange(Sender: TObject);
  private
    FCreditService: TCreditService;
    FSelectedPersonId: Integer;
    FSelectedOperationId: Integer;
    FDebtorsList: TList;
    FCreditSalesList: TList;
    FPaymentsList: TList;
    procedure InitGrids;
    procedure RefreshDebtors;
    procedure RefreshCreditSales;
    procedure RefreshPayments;
    procedure FreeDebtorsList;
    procedure FreeCreditSalesList;
    procedure FreePaymentsList;
    procedure ShowDetailTab;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.lfm}

constructor TFrameCredits.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCreditService := TCreditService.Create;
  FSelectedPersonId := -1;
  FSelectedOperationId := -1;
  FDebtorsList := nil;
  FCreditSalesList := nil;
  FPaymentsList := nil;

  { Apply resource string translations to UI elements }
  LabelTitle.Caption := RS_CREDITS_TITLE;
  EditSearch.TextHint := RS_CREDITS_SEARCH_HINT;
  TabControlDetail.Tabs[0] := RS_CREDITS_TAB_SALES;
  TabControlDetail.Tabs[1] := RS_CREDITS_TAB_PAYMENTS;
  LabelPayAmount.Caption := RS_CREDITS_PAY_LABEL_AMOUNT;
  LabelPayDate.Caption := RS_CREDITS_PAY_LABEL_DATE;
  BtnRegisterPayment.Caption := RS_CREDITS_BTN_REGISTER;

  InitGrids;
  BtnRegisterPayment.Enabled := False;
  DateEditPay.Date := Now;
  RefreshDebtors;
end;

destructor TFrameCredits.Destroy;
begin
  FreeDebtorsList;
  FreeCreditSalesList;
  FreePaymentsList;
  FCreditService.Free;
  inherited Destroy;
end;

procedure TFrameCredits.InitGrids;
begin
  { Debtors grid headers }
  GridDebtors.ColCount := 4;
  GridDebtors.FixedRows := 1;
  GridDebtors.RowCount := 2;
  GridDebtors.Cells[0, 0] := RS_CREDITS_GRID_NAME;
  GridDebtors.Cells[1, 0] := RS_CREDITS_GRID_SALES;
  GridDebtors.Cells[2, 0] := RS_CREDITS_GRID_PAYMENTS;
  GridDebtors.Cells[3, 0] := RS_CREDITS_GRID_BALANCE;
  DistributeColumns(GridDebtors, [35, 22, 22, 21]);

  { Credit sales grid headers }
  GridCreditSales.ColCount := 3;
  GridCreditSales.FixedRows := 1;
  GridCreditSales.RowCount := 2;
  GridCreditSales.Cells[0, 0] := RS_CREDITS_SALE_DATE;
  GridCreditSales.Cells[1, 0] := RS_CREDITS_SALE_TOTAL;
  GridCreditSales.Cells[2, 0] := RS_CREDITS_GRID_BALANCE;
  DistributeColumns(GridCreditSales, [35, 35, 30]);

  { Payments grid headers }
  GridPayments.ColCount := 3;
  GridPayments.FixedRows := 1;
  GridPayments.RowCount := 2;
  GridPayments.Cells[0, 0] := RS_CREDITS_PAY_DATE;
  GridPayments.Cells[1, 0] := RS_CREDITS_PAY_AMOUNT;
  GridPayments.Cells[2, 0] := RS_CREDITS_SALE_ID;
  DistributeColumns(GridPayments, [35, 35, 30]);
end;

procedure TFrameCredits.RefreshDebtors;
var
  i: Integer;
  debtor: TDebtorInfo;
  totalDebt: Real;
  searchText: String;
begin
  FreeDebtorsList;

  searchText := Trim(EditSearch.Text);
  if searchText = '' then
    FDebtorsList := FCreditService.GetAllCreditCustomers
  else
    FDebtorsList := FCreditService.GetAllCreditCustomersFiltered(searchText);

  if (FDebtorsList <> nil) and (FDebtorsList.Count > 0) then
  begin
    GridDebtors.RowCount := FDebtorsList.Count + 1;
    for i := 0 to FDebtorsList.Count - 1 do
    begin
      debtor := TDebtorInfo(FDebtorsList[i]);
      GridDebtors.Cells[0, i + 1] := debtor.CustomerName;
      GridDebtors.Cells[1, i + 1] := FormatFloat('0.00', debtor.TotalCreditSales);
      GridDebtors.Cells[2, i + 1] := FormatFloat('0.00', debtor.TotalPayments);
      GridDebtors.Cells[3, i + 1] := FormatFloat('0.00', debtor.DebtBalance);
    end;
  end
  else
  begin
    GridDebtors.RowCount := 2;
    GridDebtors.Cells[0, 1] := '';
    GridDebtors.Cells[1, 1] := '';
    GridDebtors.Cells[2, 1] := '';
    GridDebtors.Cells[3, 1] := '';
  end;

  { Update summary total }
  totalDebt := FCreditService.GetTotalOutstandingDebt;
  LabelSummaryTotal.Caption := Format(RS_CREDITS_SUMMARY_TOTAL, [FormatFloat('0.00', totalDebt)]);
end;

procedure TFrameCredits.RefreshCreditSales;
var
  i: Integer;
  saleInfo: TCreditSaleInfo;
begin
  FreeCreditSalesList;

  if FSelectedPersonId < 0 then
  begin
    GridCreditSales.RowCount := 2;
    GridCreditSales.Cells[0, 1] := '';
    GridCreditSales.Cells[1, 1] := '';
    GridCreditSales.Cells[2, 1] := '';
    Exit;
  end;

  FCreditSalesList := FCreditService.GetCreditSales(FSelectedPersonId);

  if (FCreditSalesList <> nil) and (FCreditSalesList.Count > 0) then
  begin
    GridCreditSales.RowCount := FCreditSalesList.Count + 1;
    for i := 0 to FCreditSalesList.Count - 1 do
    begin
      saleInfo := TCreditSaleInfo(FCreditSalesList[i]);
      GridCreditSales.Cells[0, i + 1] := DateToStr(saleInfo.Date);
      GridCreditSales.Cells[1, i + 1] := FormatFloat('0.00', saleInfo.SaleTotal);
      GridCreditSales.Cells[2, i + 1] := FormatFloat('0.00', saleInfo.Debt);
    end;
  end
  else
  begin
    GridCreditSales.RowCount := 2;
    GridCreditSales.Cells[0, 1] := '';
    GridCreditSales.Cells[1, 1] := '';
    GridCreditSales.Cells[2, 1] := '';
  end;
end;

procedure TFrameCredits.RefreshPayments;
var
  i: Integer;
  pay: TPay;
  totalPayments: Real;
begin
  FreePaymentsList;

  if FSelectedOperationId < 0 then
  begin
    GridPayments.RowCount := 2;
    GridPayments.Cells[0, 1] := '';
    GridPayments.Cells[1, 1] := '';
    GridPayments.Cells[2, 1] := '';
    LabelPaymentTotal.Caption := Format(RS_CREDITS_PAY_TOTAL, ['0.00']);
    Exit;
  end;

  FPaymentsList := FCreditService.GetPayments(FSelectedOperationId);

  if (FPaymentsList <> nil) and (FPaymentsList.Count > 0) then
  begin
    GridPayments.RowCount := FPaymentsList.Count + 1;
    for i := 0 to FPaymentsList.Count - 1 do
    begin
      pay := TPay(FPaymentsList[i]);
      GridPayments.Cells[0, i + 1] := DateToStr(pay.getDate());
      GridPayments.Cells[1, i + 1] := FormatFloat('0.00', pay.getValue());
      GridPayments.Cells[2, i + 1] := IntToStr(FSelectedOperationId);
    end;
  end
  else
  begin
    GridPayments.RowCount := 2;
    GridPayments.Cells[0, 1] := '';
    GridPayments.Cells[1, 1] := '';
    GridPayments.Cells[2, 1] := '';
  end;

  { Update payment total label }
  totalPayments := FCreditService.GetTotalPayments(FSelectedOperationId);
  LabelPaymentTotal.Caption := Format(RS_CREDITS_PAY_TOTAL, [FormatFloat('0.00', totalPayments)]);
end;

procedure TFrameCredits.OnDebtorSelected(Sender: TObject; aCol, aRow: Integer);
var
  idx: Integer;
  debtor: TDebtorInfo;
begin
  try
  idx := aRow - 1;
  if (FDebtorsList = nil) or (idx < 0) or (idx >= FDebtorsList.Count) then
  begin
    FSelectedPersonId := -1;
    FSelectedOperationId := -1;
    Exit;
  end;

  debtor := TDebtorInfo(FDebtorsList[idx]);
  FSelectedPersonId := debtor.PersonId;
  FSelectedOperationId := -1;
  BtnRegisterPayment.Enabled := False;
  RefreshCreditSales;
  RefreshPayments;
  except
    on E: Exception do DebugLn('[TFrameCredits.OnDebtorSelected] ERROR: ' + E.Message);
  end;
end;

procedure TFrameCredits.OnDebtorClick(Sender: TObject);
begin
  try
  OnDebtorSelected(Sender, GridDebtors.Col, GridDebtors.Row);
  except
    on E: Exception do DebugLn('[TFrameCredits.OnDebtorClick] ERROR: ' + E.Message);
  end;
end;

procedure TFrameCredits.OnSearchChange(Sender: TObject);
begin
  try
  RefreshDebtors;
  except
    on E: Exception do DebugLn('[TFrameCredits.OnSearchChange] ERROR: ' + E.Message);
  end;
end;

procedure TFrameCredits.OnTabChange(Sender: TObject);
begin
  try
  ShowDetailTab;
  except
    on E: Exception do DebugLn('[TFrameCredits.OnTabChange] ERROR: ' + E.Message);
  end;
end;

procedure TFrameCredits.ShowDetailTab;
begin
  case TabControlDetail.TabIndex of
    0: begin
      GridCreditSales.Visible := True;
      PanelPayments.Visible := False;
    end;
    1: begin
      GridCreditSales.Visible := False;
      PanelPayments.Visible := True;
    end;
  end;
end;

procedure TFrameCredits.OnRegisterPayment(Sender: TObject);
var
  amount: Real;
  payDate: TDateTime;
begin
  try
  { Validate debtor selected }
  if FSelectedPersonId < 0 then
  begin
    MessageDlg(RS_Error, RS_CREDITS_NO_DEBTOR, mtWarning, [mbOK], 0);
    Exit;
  end;

  { Validate credit sale selected }
  if FSelectedOperationId < 0 then
  begin
    MessageDlg(RS_Error, RS_CREDITS_NO_SALE, mtWarning, [mbOK], 0);
    Exit;
  end;

  { Validate amount is numeric }
  if not TryStrToFloat(Trim(EditPayAmount.Text), amount) then
  begin
    MessageDlg(RS_Error, RS_CREDITS_INVALID_AMOUNT, mtWarning, [mbOK], 0);
    Exit;
  end;

  { Validate amount > 0 }
  if amount <= 0 then
  begin
    MessageDlg(RS_Error, RS_CREDITS_AMOUNT_ZERO, mtWarning, [mbOK], 0);
    Exit;
  end;

  payDate := DateEditPay.Date;

  { Register payment via service }
  if FCreditService.RegisterPayment(FSelectedPersonId, FSelectedOperationId, amount, payDate) then
  begin
    MessageDlg(RS_MESSAGE, RS_CREDITS_PAY_SUCCESS, mtInformation, [mbOK], 0);
    EditPayAmount.Text := '';
    DateEditPay.Date := Now;
    RefreshDebtors;
    RefreshCreditSales;
    RefreshPayments;
  end
  else
  begin
    MessageDlg(RS_Error, FCreditService.GetLastError, mtError, [mbOK], 0);
  end;
  except
    on E: Exception do DebugLn('[TFrameCredits.OnRegisterPayment] ERROR: ' + E.Message);
  end;
end;

procedure TFrameCredits.OnCreditSaleSelected(Sender: TObject; aCol, aRow: Integer);
var
  idx: Integer;
  saleInfo: TCreditSaleInfo;
begin
  try
  idx := aRow - 1;
  if (FCreditSalesList = nil) or (idx < 0) or (idx >= FCreditSalesList.Count) then
  begin
    FSelectedOperationId := -1;
    BtnRegisterPayment.Enabled := False;
    RefreshPayments;
    Exit;
  end;

  saleInfo := TCreditSaleInfo(FCreditSalesList[idx]);
  FSelectedOperationId := saleInfo.OperationId;
  BtnRegisterPayment.Enabled := True;
  RefreshPayments;
  except
    on E: Exception do DebugLn('[TFrameCredits.OnCreditSaleSelected] ERROR: ' + E.Message);
  end;
end;

procedure TFrameCredits.FreeDebtorsList;
var
  i: Integer;
begin
  if FDebtorsList <> nil then
  begin
    for i := 0 to FDebtorsList.Count - 1 do
      TDebtorInfo(FDebtorsList[i]).Free;
    FDebtorsList.Free;
    FDebtorsList := nil;
  end;
end;

procedure TFrameCredits.FreeCreditSalesList;
var
  i: Integer;
begin
  if FCreditSalesList <> nil then
  begin
    for i := 0 to FCreditSalesList.Count - 1 do
      TCreditSaleInfo(FCreditSalesList[i]).Free;
    FCreditSalesList.Free;
    FCreditSalesList := nil;
  end;
end;

procedure TFrameCredits.FreePaymentsList;
var
  i: Integer;
begin
  if FPaymentsList <> nil then
  begin
    for i := 0 to FPaymentsList.Count - 1 do
      TPay(FPaymentsList[i]).Free;
    FPaymentsList.Free;
    FPaymentsList := nil;
  end;
end;

end.
