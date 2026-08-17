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

unit UCreditService;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, sqlite3conn, UDataModule, UDebtorInfo,
  UCreditSaleInfo, UPay, UPerson, ULogger;

type

  { TCreditService }

  TCreditService = class(TObject)
  private
    FLastError: String;
  public
    function GetDebtors: TList;
    function GetAllCreditCustomers: TList;
    function GetAllCreditCustomersFiltered(const nameFilter: String): TList;
    function GetDebtorsFiltered(const nameFilter: String): TList;
    function GetDebtBalance(personId: Integer): Real;
    function GetCreditSales(personId: Integer): TList;
    function GetCreditSaleTotal(operationId: Integer): Real;
    function GetPayments(operationId: Integer): TList;
    function GetTotalPayments(operationId: Integer): Real;
    function RegisterPayment(personId: Integer; operationId: Integer; amount: Real; payDate: TDateTime): Boolean;
    function GetTotalOutstandingDebt: Real;
    function GetLastError: String;
  end;

implementation

function TCreditService.GetDebtors: TList;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  debtor: TDebtorInfo;
begin
  Result := TList.Create;
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'SELECT ' +
      '  c.person AS person_id, ' +
      '  pe.name AS customer_name, ' +
      '  COALESCE(credit_totals.total, 0) AS total_credit_sales, ' +
      '  COALESCE(payment_totals.total, 0) AS total_payments, ' +
      '  COALESCE(credit_totals.total, 0) - COALESCE(payment_totals.total, 0) AS debt_balance ' +
      'FROM customer c ' +
      'JOIN person pe ON c.person = pe.id ' +
      'LEFT JOIN ( ' +
      '  SELECT o.person, SUM(i.stock * i.price) AS total ' +
      '  FROM operation o ' +
      '  JOIN item i ON i.operation = o.id ' +
      '  WHERE o.type = 2 AND o.credit = 1 ' +
      '  GROUP BY o.person ' +
      ') credit_totals ON credit_totals.person = c.person ' +
      'LEFT JOIN ( ' +
      '  SELECT o2.person, SUM(p.val) AS total ' +
      '  FROM pay p ' +
      '  JOIN operation o2 ON p.operation = o2.id ' +
      '  WHERE o2.type = 2 AND o2.credit = 1 ' +
      '  GROUP BY o2.person ' +
      ') payment_totals ON payment_totals.person = c.person ' +
      'WHERE COALESCE(credit_totals.total, 0) - COALESCE(payment_totals.total, 0) > 0 ' +
      'ORDER BY pe.name';

    Query.Open;
    while not Query.EOF do
    begin
      debtor := TDebtorInfo.Create;
      debtor.PersonId := Query.FieldByName('person_id').AsInteger;
      debtor.CustomerName := Query.FieldByName('customer_name').AsString;
      debtor.TotalCreditSales := Query.FieldByName('total_credit_sales').AsFloat;
      debtor.TotalPayments := Query.FieldByName('total_payments').AsFloat;
      debtor.DebtBalance := Query.FieldByName('debt_balance').AsFloat;
      Result.Add(debtor);
      Query.Next;
    end;
    Query.Close;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      FLastError := E.Message;
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.GetAllCreditCustomers: TList;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  debtor: TDebtorInfo;
begin
  Result := TList.Create;
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'SELECT ' +
      '  c.person AS person_id, ' +
      '  pe.name AS customer_name, ' +
      '  COALESCE(credit_totals.total, 0) AS total_credit_sales, ' +
      '  COALESCE(payment_totals.total, 0) AS total_payments, ' +
      '  COALESCE(credit_totals.total, 0) - COALESCE(payment_totals.total, 0) AS debt_balance ' +
      'FROM customer c ' +
      'JOIN person pe ON c.person = pe.id ' +
      'INNER JOIN ( ' +
      '  SELECT o.person, SUM(i.stock * i.price) AS total ' +
      '  FROM operation o ' +
      '  JOIN item i ON i.operation = o.id ' +
      '  WHERE o.type = 2 AND o.credit = 1 ' +
      '  GROUP BY o.person ' +
      ') credit_totals ON credit_totals.person = c.person ' +
      'LEFT JOIN ( ' +
      '  SELECT o2.person, SUM(p.val) AS total ' +
      '  FROM pay p ' +
      '  JOIN operation o2 ON p.operation = o2.id ' +
      '  WHERE o2.type = 2 AND o2.credit = 1 ' +
      '  GROUP BY o2.person ' +
      ') payment_totals ON payment_totals.person = c.person ' +
      'ORDER BY pe.name';

    Query.Open;
    while not Query.EOF do
    begin
      debtor := TDebtorInfo.Create;
      debtor.PersonId := Query.FieldByName('person_id').AsInteger;
      debtor.CustomerName := Query.FieldByName('customer_name').AsString;
      debtor.TotalCreditSales := Query.FieldByName('total_credit_sales').AsFloat;
      debtor.TotalPayments := Query.FieldByName('total_payments').AsFloat;
      debtor.DebtBalance := Query.FieldByName('debt_balance').AsFloat;
      Result.Add(debtor);
      Query.Next;
    end;
    Query.Close;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      FLastError := E.Message;
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.GetAllCreditCustomersFiltered(const nameFilter: String): TList;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  debtor: TDebtorInfo;
begin
  Result := TList.Create;
  if nameFilter = '' then
  begin
    Result.Free;
    Result := GetAllCreditCustomers;
    Exit;
  end;

  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'SELECT ' +
      '  c.person AS person_id, ' +
      '  pe.name AS customer_name, ' +
      '  COALESCE(credit_totals.total, 0) AS total_credit_sales, ' +
      '  COALESCE(payment_totals.total, 0) AS total_payments, ' +
      '  COALESCE(credit_totals.total, 0) - COALESCE(payment_totals.total, 0) AS debt_balance ' +
      'FROM customer c ' +
      'JOIN person pe ON c.person = pe.id ' +
      'INNER JOIN ( ' +
      '  SELECT o.person, SUM(i.stock * i.price) AS total ' +
      '  FROM operation o ' +
      '  JOIN item i ON i.operation = o.id ' +
      '  WHERE o.type = 2 AND o.credit = 1 ' +
      '  GROUP BY o.person ' +
      ') credit_totals ON credit_totals.person = c.person ' +
      'LEFT JOIN ( ' +
      '  SELECT o2.person, SUM(p.val) AS total ' +
      '  FROM pay p ' +
      '  JOIN operation o2 ON p.operation = o2.id ' +
      '  WHERE o2.type = 2 AND o2.credit = 1 ' +
      '  GROUP BY o2.person ' +
      ') payment_totals ON payment_totals.person = c.person ' +
      'WHERE LOWER(pe.name) LIKE LOWER(:nameFilter) ' +
      'ORDER BY pe.name';

    Query.Params.ParamByName('nameFilter').AsString := '%' + nameFilter + '%';
    Query.Open;
    while not Query.EOF do
    begin
      debtor := TDebtorInfo.Create;
      debtor.PersonId := Query.FieldByName('person_id').AsInteger;
      debtor.CustomerName := Query.FieldByName('customer_name').AsString;
      debtor.TotalCreditSales := Query.FieldByName('total_credit_sales').AsFloat;
      debtor.TotalPayments := Query.FieldByName('total_payments').AsFloat;
      debtor.DebtBalance := Query.FieldByName('debt_balance').AsFloat;
      Result.Add(debtor);
      Query.Next;
    end;
    Query.Close;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      FLastError := E.Message;
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.GetDebtorsFiltered(const nameFilter: String): TList;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  debtor: TDebtorInfo;
begin
  Result := TList.Create;
  if nameFilter = '' then
  begin
    Result.Free;
    Result := GetDebtors;
    Exit;
  end;

  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'SELECT ' +
      '  c.person AS person_id, ' +
      '  pe.name AS customer_name, ' +
      '  COALESCE(credit_totals.total, 0) AS total_credit_sales, ' +
      '  COALESCE(payment_totals.total, 0) AS total_payments, ' +
      '  COALESCE(credit_totals.total, 0) - COALESCE(payment_totals.total, 0) AS debt_balance ' +
      'FROM customer c ' +
      'JOIN person pe ON c.person = pe.id ' +
      'LEFT JOIN ( ' +
      '  SELECT o.person, SUM(i.stock * i.price) AS total ' +
      '  FROM operation o ' +
      '  JOIN item i ON i.operation = o.id ' +
      '  WHERE o.type = 2 AND o.credit = 1 ' +
      '  GROUP BY o.person ' +
      ') credit_totals ON credit_totals.person = c.person ' +
      'LEFT JOIN ( ' +
      '  SELECT o2.person, SUM(p.val) AS total ' +
      '  FROM pay p ' +
      '  JOIN operation o2 ON p.operation = o2.id ' +
      '  WHERE o2.type = 2 AND o2.credit = 1 ' +
      '  GROUP BY o2.person ' +
      ') payment_totals ON payment_totals.person = c.person ' +
      'WHERE COALESCE(credit_totals.total, 0) - COALESCE(payment_totals.total, 0) > 0 ' +
      '  AND LOWER(pe.name) LIKE LOWER(:nameFilter) ' +
      'ORDER BY pe.name';

    Query.Params.ParamByName('nameFilter').AsString := '%' + nameFilter + '%';
    Query.Open;
    while not Query.EOF do
    begin
      debtor := TDebtorInfo.Create;
      debtor.PersonId := Query.FieldByName('person_id').AsInteger;
      debtor.CustomerName := Query.FieldByName('customer_name').AsString;
      debtor.TotalCreditSales := Query.FieldByName('total_credit_sales').AsFloat;
      debtor.TotalPayments := Query.FieldByName('total_payments').AsFloat;
      debtor.DebtBalance := Query.FieldByName('debt_balance').AsFloat;
      Result.Add(debtor);
      Query.Next;
    end;
    Query.Close;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      FLastError := E.Message;
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.GetDebtBalance(personId: Integer): Real;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  balance: Real;
begin
  Result := 0;
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'SELECT COALESCE( ' +
      '  (SELECT SUM(i.stock * i.price) ' +
      '   FROM item i ' +
      '   JOIN operation o ON i.operation = o.id ' +
      '   WHERE o.person = :personId AND o.type = 2 AND o.credit = 1), 0) ' +
      '- COALESCE( ' +
      '  (SELECT SUM(p.val) FROM pay p ' +
      '   JOIN operation o2 ON p.operation = o2.id ' +
      '   WHERE o2.person = :personId AND o2.type = 2 AND o2.credit = 1), 0) ' +
      'AS debt_balance';

    Query.Params.ParamByName('personId').AsInteger := personId;
    Query.Open;

    if not Query.EOF then
    begin
      balance := Query.FieldByName('debt_balance').AsFloat;
      if balance > 0 then
        Result := balance
      else
        Result := 0;
    end;
    Query.Close;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      FLastError := E.Message;
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.GetCreditSales(personId: Integer): TList;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  saleInfo: TCreditSaleInfo;
begin
  Result := TList.Create;
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'SELECT o.id, o.date, SUM(i.stock * i.price) AS sale_total, ' +
      'COALESCE((SELECT SUM(p.val) FROM pay p WHERE p.operation = o.id), 0) AS total_paid ' +
      'FROM operation o ' +
      'JOIN item i ON i.operation = o.id ' +
      'WHERE o.person = :personId AND o.type = 2 AND o.credit = 1 ' +
      'GROUP BY o.id, o.date ' +
      'ORDER BY o.date DESC';

    Query.Params.ParamByName('personId').AsInteger := personId;
    Query.Open;
    while not Query.EOF do
    begin
      saleInfo := TCreditSaleInfo.Create;
      saleInfo.OperationId := Query.FieldByName('id').AsInteger;
      saleInfo.Date := Query.FieldByName('date').AsFloat;
      saleInfo.SaleTotal := Query.FieldByName('sale_total').AsFloat;
      saleInfo.Debt := Query.FieldByName('sale_total').AsFloat - Query.FieldByName('total_paid').AsFloat;
      if saleInfo.Debt < 0 then saleInfo.Debt := 0;
      Result.Add(saleInfo);
      Query.Next;
    end;
    Query.Close;

    Trans.Commit;
  except
    on E: Exception do
    begin
      LogError('CreditService', 'GET_CREDIT_SALES_FAILED', 'personId=' + IntToStr(personId) + ' error=' + E.Message);
      if Trans.Active then Trans.Rollback;
      FLastError := E.Message;
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.GetCreditSaleTotal(operationId: Integer): Real;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
begin
  Result := 0;
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'SELECT COALESCE(SUM(i.stock * i.price), 0) AS sale_total ' +
      'FROM item i ' +
      'WHERE i.operation = :operationId';

    Query.Params.ParamByName('operationId').AsInteger := operationId;
    Query.Open;

    if not Query.EOF then
      Result := Query.FieldByName('sale_total').AsFloat;
    Query.Close;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      FLastError := E.Message;
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.GetPayments(operationId: Integer): TList;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  pay: TPay;
  person: TPerson;
begin
  Result := TList.Create;
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'SELECT id, person, val, date FROM pay ' +
      'WHERE operation = :operationId ' +
      'ORDER BY date DESC';

    Query.Params.ParamByName('operationId').AsInteger := operationId;
    Query.Open;
    while not Query.EOF do
    begin
      pay := TPay.Create;
      pay.setId(Query.FieldByName('id').AsInteger);
      pay.setValue(Query.FieldByName('val').AsFloat);
      pay.setDate(Query.FieldByName('date').AsFloat);
      person := TPerson.Create;
      person.setId(Query.FieldByName('person').AsInteger);
      pay.setPerson(person);
      Result.Add(pay);
      Query.Next;
    end;
    Query.Close;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      FLastError := E.Message;
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.GetTotalPayments(operationId: Integer): Real;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
begin
  Result := 0;
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'SELECT COALESCE(SUM(val), 0) AS total_payments ' +
      'FROM pay ' +
      'WHERE operation = :operationId';

    Query.Params.ParamByName('operationId').AsInteger := operationId;
    Query.Open;

    if not Query.EOF then
      Result := Query.FieldByName('total_payments').AsFloat;
    Query.Close;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      FLastError := E.Message;
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.RegisterPayment(personId: Integer; operationId: Integer; amount: Real; payDate: TDateTime): Boolean;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
begin
  Result := False;
  FLastError := '';

  { Validate amount > 0 }
  if amount <= 0 then
  begin
    FLastError := 'El monto debe ser mayor a cero';
    LogWarn('CreditService', 'PAYMENT_VALIDATION_FAIL',
      'personId=' + IntToStr(personId) + ' operationId=' + IntToStr(operationId) + ' reason=amount_invalid');
    Exit;
  end;

  LogInfo('CreditService', 'PAYMENT_ATTEMPT',
    'personId=' + IntToStr(personId) + ' operationId=' + IntToStr(operationId));

  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'INSERT INTO pay (person, val, date, operation) VALUES (:person, :val, :paydate, :operation)';
    Query.Params.ParamByName('person').AsInteger := personId;
    Query.Params.ParamByName('val').AsFloat := amount;
    Query.Params.ParamByName('paydate').AsFloat := Double(payDate);
    Query.Params.ParamByName('operation').AsInteger := operationId;
    Query.ExecSQL;

    Trans.Commit;
    Result := True;
    LogSecurity('CreditService', 'PAYMENT_REGISTERED',
      'personId=' + IntToStr(personId) + ' operationId=' + IntToStr(operationId) + ' date=' + DateToStr(payDate));
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      FLastError := 'Error al guardar el pago: ' + E.Message;
      LogError('CreditService', 'PAYMENT_FAILED',
        'personId=' + IntToStr(personId) + ' operationId=' + IntToStr(operationId) + ' error=' + E.Message);
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.GetTotalOutstandingDebt: Real;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
begin
  Result := 0;
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := DataModule1.SQLite3Connection1;
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text :=
      'SELECT COALESCE(SUM(debt_balance), 0) AS total_debt FROM ( ' +
      '  SELECT ' +
      '    COALESCE(credit_totals.total, 0) - COALESCE(payment_totals.total, 0) AS debt_balance ' +
      '  FROM customer c ' +
      '  LEFT JOIN ( ' +
      '    SELECT o.person, SUM(i.stock * i.price) AS total ' +
      '    FROM operation o ' +
      '    JOIN item i ON i.operation = o.id ' +
      '    WHERE o.type = 2 AND o.credit = 1 ' +
      '    GROUP BY o.person ' +
      '  ) credit_totals ON credit_totals.person = c.person ' +
      '  LEFT JOIN ( ' +
      '    SELECT o2.person, SUM(p.val) AS total ' +
      '    FROM pay p ' +
      '    JOIN operation o2 ON p.operation = o2.id ' +
      '    WHERE o2.type = 2 AND o2.credit = 1 ' +
      '    GROUP BY o2.person ' +
      '  ) payment_totals ON payment_totals.person = c.person ' +
      '  WHERE COALESCE(credit_totals.total, 0) - COALESCE(payment_totals.total, 0) > 0 ' +
      ')';

    Query.Open;
    if not Query.EOF then
      Result := Query.FieldByName('total_debt').AsFloat;
    Query.Close;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      FLastError := E.Message;
    end;
  end;
  Query.Free;
  Trans.Free;
end;

function TCreditService.GetLastError: String;
begin
  Result := FLastError;
end;

end.
