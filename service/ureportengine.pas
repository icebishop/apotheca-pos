{ Apothêca

  Copyright (C) 2010 Ice icebishop@gmail.com
  Updated 2026 - Analytical Reports Module

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.
}

unit UReportEngine;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, sqlite3conn, UDataModule, db;

type
  TIncomeUtilityReportRow = record
    TransactionId : Integer;
    TxDate        : TDateTime;
    CustomerName  : String;
    TotalSale     : Real;
    TotalCost     : Real;
    Utility       : Real;
  end;

  TInventoryValuationRow = record
    ProductId   : Integer;
    ProductName : String;
    MinStock    : Integer;
    MaxStock    : Integer;
    Stock       : Integer;
    UnitCost    : Real;
    UnitPrice   : Real;
    TotalValue  : Real;
  end;

  TPurchaseReportRow = record
    TransactionId : Integer;
    TxDate        : TDateTime;
    SupplierName  : String;
    ProductName   : String;
    Quantity      : Integer;
    UnitCost      : Real;
    UnitPrice     : Real;
    TotalCost     : Real;
  end;

  { TReportEngine }

  TReportEngine = class(TObject)
  private
    FConnection: TSQLite3Connection;
  public
    constructor Create(AConnection: TSQLite3Connection);
    
    // Financial & Utility Summary
    function GetIncomeUtilityReport(StartDate, EndDate: TDateTime; var TotalSales, TotalCosts, TotalUtility: Real): TList;
    
    // Inventory Valuation Summary
    function GetInventoryValuationReport(var GrandTotalValue: Real; var TotalItemsCount: Integer): TList;

    // Purchase Report by date range
    function GetPurchaseReport(StartDate, EndDate: TDateTime; var TotalPurchases: Real): TList;
  end;

implementation

constructor TReportEngine.Create(AConnection: TSQLite3Connection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TReportEngine.GetIncomeUtilityReport(StartDate, EndDate: TDateTime; var TotalSales, TotalCosts, TotalUtility: Real): TList;
var
  Query: TSQLQuery;
  Trans: TSQLTransaction;
  ResultList: TList;
  RowPtr: ^TIncomeUtilityReportRow;
begin
  ResultList := TList.Create;
  TotalSales := 0;
  TotalCosts := 0;
  TotalUtility := 0;

  if FConnection = nil then
  begin
    GetIncomeUtilityReport := ResultList;
    Exit;
  end;

  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := FConnection;
    Query.DataBase := FConnection;
    Query.Transaction := Trans;

    // Query for sales aggregated per operation (sale ID, date, customer, totals)
    Query.SQL.Text := 
      'SELECT o.id AS op_id, o.date AS op_date, p.name AS person_name, ' +
      'SUM(i.stock * i.price) AS total_sale, SUM(i.stock * i.cost) AS total_cost ' +
      'FROM operation o ' +
      'JOIN operationtype ot ON o.type = ot.id ' +
      'JOIN person p ON o.person = p.id ' +
      'JOIN item i ON i.operation = o.id ' +
      'WHERE ot.type = ''out'' AND o.date >= :start_date AND o.date <= :end_date ' +
      'GROUP BY o.id, o.date, p.name ' +
      'ORDER BY o.date DESC';

    { Convert TDateTime to Julian Day for SQLite comparison }
    Query.Params.ParamByName('start_date').AsFloat := Int(StartDate) + 2415018.5;
    Query.Params.ParamByName('end_date').AsFloat := Int(EndDate) + 2415019.49999;
    
    Trans.StartTransaction;
    Query.Open;

    while not Query.EOF do
    begin
      New(RowPtr);
      RowPtr^.TransactionId := Query.FieldByName('op_id').AsInteger;
      RowPtr^.TxDate        := Query.FieldByName('op_date').AsFloat - 2415018.5;
      RowPtr^.CustomerName  := Query.FieldByName('person_name').AsString;
      RowPtr^.TotalSale     := Query.FieldByName('total_sale').AsFloat;
      RowPtr^.TotalCost     := Query.FieldByName('total_cost').AsFloat;
      RowPtr^.Utility       := RowPtr^.TotalSale - RowPtr^.TotalCost;

      TotalSales   := TotalSales + RowPtr^.TotalSale;
      TotalCosts   := TotalCosts + RowPtr^.TotalCost;
      TotalUtility := TotalUtility + RowPtr^.Utility;

      ResultList.Add(RowPtr);
      Query.Next;
    end;

    Query.Close;
    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
    end;
  end;

  Query.Free;
  Trans.Free;

  GetIncomeUtilityReport := ResultList;
end;

function TReportEngine.GetInventoryValuationReport(var GrandTotalValue: Real; var TotalItemsCount: Integer): TList;
var
  Query: TSQLQuery;
  Trans: TSQLTransaction;
  ResultList: TList;
  RowPtr: ^TInventoryValuationRow;
begin
  ResultList := TList.Create;
  GrandTotalValue := 0;
  TotalItemsCount := 0;

  if FConnection = nil then
  begin
    GetInventoryValuationReport := ResultList;
    Exit;
  end;

  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := FConnection;
    Query.DataBase := FConnection;
    Query.Transaction := Trans;

    Query.SQL.Text := 
      'SELECT p.id, p.name, p.minstock, p.maxstock, ' +
      'b.units, b.cost, b.price ' +
      'FROM product p ' +
      'LEFT JOIN balance b ON p.id = b.product ' +
      'ORDER BY p.name ASC';

    Trans.StartTransaction;
    Query.Open;

    while not Query.EOF do
    begin
      New(RowPtr);
      RowPtr^.ProductId   := Query.FieldByName('id').AsInteger;
      RowPtr^.ProductName := Query.FieldByName('name').AsString;
      RowPtr^.MinStock    := Query.FieldByName('minstock').AsInteger;
      RowPtr^.MaxStock    := Query.FieldByName('maxstock').AsInteger;
      RowPtr^.Stock       := Query.FieldByName('units').AsInteger;
      RowPtr^.UnitCost    := Query.FieldByName('cost').AsFloat;
      RowPtr^.UnitPrice   := Query.FieldByName('price').AsFloat;
      RowPtr^.TotalValue  := RowPtr^.Stock * RowPtr^.UnitCost;

      GrandTotalValue := GrandTotalValue + RowPtr^.TotalValue;
      TotalItemsCount := TotalItemsCount + RowPtr^.Stock;

      ResultList.Add(RowPtr);
      Query.Next;
    end;

    Query.Close;
    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
    end;
  end;

  Query.Free;
  Trans.Free;

  GetInventoryValuationReport := ResultList;
end;

function TReportEngine.GetPurchaseReport(StartDate, EndDate: TDateTime; var TotalPurchases: Real): TList;
var
  Query: TSQLQuery;
  Trans: TSQLTransaction;
  ResultList: TList;
  RowPtr: ^TPurchaseReportRow;
begin
  ResultList := TList.Create;
  TotalPurchases := 0;

  if FConnection = nil then
  begin
    GetPurchaseReport := ResultList;
    Exit;
  end;

  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := FConnection;
    Query.DataBase := FConnection;
    Query.Transaction := Trans;

    Query.SQL.Text :=
      'SELECT o.id AS op_id, o.date AS op_date, p.name AS supplier_name, ' +
      'pr.name AS product_name, i.stock AS qty, i.cost AS unit_cost, i.price AS unit_price ' +
      'FROM operation o ' +
      'JOIN operationtype ot ON o.type = ot.id ' +
      'JOIN person p ON o.person = p.id ' +
      'JOIN item i ON i.operation = o.id ' +
      'JOIN product pr ON i.product = pr.id ' +
      'WHERE ot.type = ''in'' AND o.date >= :start_date AND o.date <= :end_date ' +
      'ORDER BY o.date DESC, o.id DESC';

    { Convert TDateTime to Julian Day for SQLite comparison }
    Query.Params.ParamByName('start_date').AsFloat := Int(StartDate) + 2415018.5;
    Query.Params.ParamByName('end_date').AsFloat := Int(EndDate) + 2415019.49999;

    Trans.StartTransaction;
    Query.Open;

    while not Query.EOF do
    begin
      New(RowPtr);
      RowPtr^.TransactionId := Query.FieldByName('op_id').AsInteger;
      RowPtr^.TxDate        := Query.FieldByName('op_date').AsFloat - 2415018.5;
      RowPtr^.SupplierName  := Query.FieldByName('supplier_name').AsString;
      RowPtr^.ProductName   := Query.FieldByName('product_name').AsString;
      RowPtr^.Quantity      := Query.FieldByName('qty').AsInteger;
      RowPtr^.UnitCost      := Query.FieldByName('unit_cost').AsFloat;
      RowPtr^.UnitPrice     := Query.FieldByName('unit_price').AsFloat;
      RowPtr^.TotalCost     := RowPtr^.Quantity * RowPtr^.UnitCost;

      TotalPurchases := TotalPurchases + RowPtr^.TotalCost;

      ResultList.Add(RowPtr);
      Query.Next;
    end;

    Query.Close;
    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
    end;
  end;

  Query.Free;
  Trans.Free;

  GetPurchaseReport := ResultList;
end;

end.
