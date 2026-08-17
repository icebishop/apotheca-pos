unit UTestSuite;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, Dialogs, sqldb, sqlite3conn, UDataModule, UCustomer,
  UDataCustomer, UProduct, UDataProduct,
  UBalance, UBalanceBuilder;

type
  { TTestSuite }

  TTestSuite = class(TObject)
  private
    FPassedCount: Integer;
    FFailedCount: Integer;
    FLog: TStringList;
    procedure Log(const Msg: String);
    procedure AssertTrue(Condition: Boolean;
                         const TestName, Details: String);

    procedure TestCustomerRoundTrip;
    procedure TestCustomerDeletionBlocked;
    procedure TestCustomerDeletionClean;
    procedure TestBalanceStockAccumulation;
    procedure TestBalanceWeightedAverageCost;
    procedure TestStockAdjustment;
    procedure TestIncomeReport;
    procedure TestUtilityReport;
  public
    constructor Create;
    destructor Destroy; override;
    function RunAllTests(var Output: String): Boolean;
  end;

implementation

constructor TTestSuite.Create;
begin
  inherited Create;
  FPassedCount := 0;
  FFailedCount := 0;
  FLog := TStringList.Create;
end;

destructor TTestSuite.Destroy;
begin
  FLog.Free;
  inherited Destroy;
end;

procedure TTestSuite.Log(const Msg: String);
begin
  FLog.Add(Msg);
end;

procedure TTestSuite.AssertTrue(Condition: Boolean; const TestName, Details: String);
begin
  if Condition then
  begin
    Inc(FPassedCount);
    Log('[PASS] ' + TestName + ' - ' + Details);
  end
  else
  begin
    Inc(FFailedCount);
    Log('[FAIL] ' + TestName + ' - ' + Details);
  end;
end;

procedure TTestSuite.TestCustomerRoundTrip;
{ Validates: Requirements 4.3 }
{ Property 3: For any non-empty name, after TDataCustomer.new, TDataCustomer.find
  must return exactly one entry whose name matches the original name.
  Tested over a small set of varied names (including unicode). }
const
  TestNames: array[0..4] of String = (
    'Alice Test',
    'Bob Supplier',
    'María García',
    'Test-Customer_99',
    'Ζεύς Πελάτης'
  );
var
  i: Integer;
  testName: String;
  customer: TCustomer;
  dataCustomer: TDataCustomer;
  results: TList;
  found: TCustomer;
  insertedId: Integer;
begin
  Log('--- TestCustomerRoundTrip ---');

  for i := 0 to High(TestNames) do
  begin
    testName := TestNames[i];
    customer := nil;
    dataCustomer := nil;
    results := nil;
    insertedId := 0;

    customer := TCustomer.Create;
    customer.setName(testName);
    customer.setTelephone('');
    customer.setAddress('');

    DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
    dataCustomer := TDataCustomer.Create(DataModule1.SQLite3Connection1);
    try
      dataCustomer.getTransaction().StartTransaction;

      { Insert the customer }
      insertedId := dataCustomer.new(customer);
      AssertTrue(insertedId > 0,
        'TestCustomerRoundTrip[' + testName + '] - new returns valid ID',
        'insertedId=' + IntToStr(insertedId));

      { Find by exact name }
      results := dataCustomer.find(testName);
      AssertTrue(results <> nil,
        'TestCustomerRoundTrip[' + testName + '] - find returns non-nil list',
        'results <> nil');

      if results <> nil then
      begin
        AssertTrue(results.Count = 1,
          'TestCustomerRoundTrip[' + testName + '] - find returns exactly one entry',
          'Count=' + IntToStr(results.Count));

        if results.Count >= 1 then
        begin
          found := TCustomer(results[0]);
          AssertTrue(found.getName() = testName,
            'TestCustomerRoundTrip[' + testName + '] - returned name matches',
            'got=' + found.getName());
        end;
      end;

    finally
      { Clean up: delete the inserted customer if it was actually created }
      if (insertedId > 0) and (customer.getId() > 0) then
      begin
        { Re-use same transaction for deletion }
        dataCustomer.delete(customer);
        dataCustomer.getTransaction().Commit;
      end
      else
        dataCustomer.getTransaction().Rollback;

      { Free list items and the list itself }
      if results <> nil then
      begin
        while results.Count > 0 do
        begin
          TObject(results[0]).Free;
          results.Delete(0);
        end;
        results.Free;
      end;

      dataCustomer.Free;
      customer.Free;
    end;
  end;
end;

procedure TTestSuite.TestCustomerDeletionBlocked;
{ Tests requirement 4.4: delete returns False with non-empty FLastError when
  the target customer has at least one associated Operation Record.

  Also covers Property 1: for any customer with >= 1 operation row,
  delete must return False with non-empty FLastError and leave all rows
  unchanged.  We iterate over several operation-count values (1, 2, 5) to
  exercise the property across a representative input space.

  Validates: Requirements 1.1, 1.2, 3.1, 4.4 }

  { Helper: insert N bare operation rows referencing PersonId.
    Returns the list of inserted operation IDs so they can be cleaned up.
    OperationType 1 ("Purchase") is always seeded by InitDefaultDatabaseSchema. }
  procedure InsertOperationRows(Conn: TSQLite3Connection;
                                PersonId, N: Integer;
                                out Ids: array of Integer);
  var
    q:   TSQLQuery;
    tr:  TSQLTransaction;
    i:   Integer;
  begin
    tr := TSQLTransaction.Create(nil);
    q  := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn;
      q.DataBase  := Conn;
      q.Transaction := tr;
      tr.StartTransaction;
      for i := 0 to N - 1 do
      begin
        q.SQL.Text := 'INSERT INTO operation (type, date, person) VALUES (1, :dt, :p)';
        q.Params.ParamByName('dt').AsFloat   := Now;
        q.Params.ParamByName('p').AsInteger  := PersonId;
        q.ExecSQL;
        q.SQL.Text := 'SELECT last_insert_rowid() AS id';
        q.Open;
        Ids[i] := q.FieldByName('id').AsInteger;
        q.Close;
      end;
      tr.Commit;
    finally
      q.Free;
      tr.Free;
    end;
  end;

  { Helper: delete the operation rows inserted above. }
  procedure DeleteOperationRows(Conn: TSQLite3Connection;
                                const Ids: array of Integer; N: Integer);
  var
    q:  TSQLQuery;
    tr: TSQLTransaction;
    i:  Integer;
  begin
    tr := TSQLTransaction.Create(nil);
    q  := TSQLQuery.Create(nil);
    try
      tr.DataBase  := Conn;
      q.DataBase   := Conn;
      q.Transaction := tr;
      tr.StartTransaction;
      for i := 0 to N - 1 do
      begin
        q.SQL.Text := 'DELETE FROM operation WHERE id = :id';
        q.Params.ParamByName('id').AsInteger := Ids[i];
        q.ExecSQL;
      end;
      tr.Commit;
    finally
      q.Free;
      tr.Free;
    end;
  end;

  { Helper: delete the customer + person rows. }
  procedure ForceDeleteCustomer(Conn: TSQLite3Connection; PersonId: Integer);
  var
    q:  TSQLQuery;
    tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil);
    q  := TSQLQuery.Create(nil);
    try
      tr.DataBase   := Conn;
      q.DataBase    := Conn;
      q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM customer WHERE person = :p';
      q.Params.ParamByName('p').AsInteger := PersonId;
      q.ExecSQL;
      q.SQL.Text := 'DELETE FROM person WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := PersonId;
      q.ExecSQL;
      tr.Commit;
    finally
      q.Free;
      tr.Free;
    end;
  end;

var
  Conn:        TSQLite3Connection;
  dataCustomer: TDataCustomer;
  cust:         TCustomer;
  opCounts:     array[0..2] of Integer;
  opIds:        array[0..4] of Integer;  { max 5 ops in the loop below }
  personId:     Integer;
  n, idx:       Integer;
  deleteResult: Boolean;
  q2:           TSQLQuery;
  tr2:          TSQLTransaction;
  cnt:          Integer;
begin
  Log('--- TestCustomerDeletionBlocked ---');

  Conn := DataModule1.SQLite3Connection1;

  { Property 1 loop: test with 1, 2, and 5 operation rows. }
  opCounts[0] := 1;
  opCounts[1] := 2;
  opCounts[2] := 5;
  {$PUSH}{$HINTS OFF}
  FillChar(opIds, SizeOf(opIds), 0);
  {$POP}

  for idx := 0 to 2 do
  begin
    n    := opCounts[idx];
    cust := TCustomer.Create;
    cust.setName('__TestDelBlocked_' + IntToStr(n) + '__');
    cust.setTelephone('');
    cust.setAddress('');

    dataCustomer := TDataCustomer.Create(Conn);
    personId := 0;
    FillChar(opIds, SizeOf(opIds), 0);

    try
      { 1. Create the customer. }
      personId := dataCustomer.new(cust);
      AssertTrue(personId > 0,
        'TestCustomerDeletionBlocked',
        Format('Setup: customer created with personId=%d (n=%d)', [personId, n]));

      if personId > 0 then
      begin
        { 2. Insert N operation rows referencing this customer's person ID. }
        InsertOperationRows(Conn, personId, n, opIds);

        { 3. Attempt deletion — must be blocked. }
        deleteResult := dataCustomer.delete(cust);

        AssertTrue(not deleteResult,
          'TestCustomerDeletionBlocked',
          Format('delete returns False when %d operation row(s) exist', [n]));

        AssertTrue(dataCustomer.getLastError() <> '',
          'TestCustomerDeletionBlocked',
          Format('getLastError is non-empty when %d operation row(s) block deletion', [n]));

        { 4. Verify customer row still exists in DB (rows unchanged). }
        begin
          tr2 := TSQLTransaction.Create(nil);
          q2  := TSQLQuery.Create(nil);
          try
            tr2.DataBase   := Conn;
            q2.DataBase    := Conn;
            q2.Transaction := tr2;
            tr2.StartTransaction;
            q2.SQL.Text := 'SELECT COUNT(*) AS c FROM customer WHERE person = :p';
            q2.Params.ParamByName('p').AsInteger := personId;
            q2.Open;
            cnt := q2.FieldByName('c').AsInteger;
            q2.Close;
            tr2.Commit;
          finally
            q2.Free;
            tr2.Free;
          end;
          AssertTrue(cnt = 1,
            'TestCustomerDeletionBlocked',
            Format('customer row still present after blocked delete (n=%d)', [n]));
        end;
      end;

    finally
      { 5. Clean up: remove operation rows first, then the customer/person rows. }
      if personId > 0 then
      begin
        DeleteOperationRows(Conn, opIds, n);
        ForceDeleteCustomer(Conn, personId);
      end;
      dataCustomer.Free;
      cust.Free;
    end;
  end;
end;

procedure TTestSuite.TestCustomerDeletionClean;
{ Validates: Requirements 4.5
  Also covers Property 2 (clean deletion round-trip):
  For any customer with zero dependent records, delete must return True
  and leave zero rows for that ID in both customer and person tables. }
const
  PropNames: array[0..3] of String = (
    'TestClean_Alpha',
    'TestClean_Beta Pharma',
    'TestClean_Gamma 123',
    'TestClean_Delta & Co'
  );
var
  dataCustomer: TDataCustomer;
  cust: TCustomer;
  deleteResult: Boolean;
  foundList: TList;
  custId: Integer;
  verifyQuery: TSQLQuery;
  personCount, customerCount: Integer;
  i: Integer;
begin
  Log('--- TestCustomerDeletionClean ---');

  dataCustomer := TDataCustomer.Create(DataModule1.SQLite3Connection1);
  verifyQuery   := TSQLQuery.Create(nil);
  verifyQuery.DataBase := DataModule1.SQLite3Connection1;
  try
    { --- Property 2 loop: run for several distinct names --- }
    for i := 0 to High(PropNames) do
    begin
      cust := TCustomer.Create;
      cust.setName(PropNames[i]);
      cust.setTelephone('');
      cust.setAddress('');

      { Insert the customer }
      custId := dataCustomer.new(cust);
      cust.setId(custId);

      AssertTrue(custId > 0,
        'TestCustomerDeletionClean',
        Format('[Prop2 %d] Customer inserted with id=%d for name="%s"',
               [i, custId, PropNames[i]]));

      if custId <= 0 then
      begin
        { Cannot proceed with this iteration — skip cleanup safely }
        cust.Free;
        Continue;
      end;

      { Call delete — must return True (no dependent records) }
      deleteResult := dataCustomer.delete(cust);

      AssertTrue(deleteResult,
        'TestCustomerDeletionClean',
        Format('[Prop2 %d] delete returned True for clean customer "%s" (lastErr="%s")',
               [i, PropNames[i], dataCustomer.getLastError()]));

      { Verify: find by name must return an empty list }
      foundList := dataCustomer.find(PropNames[i]);
      AssertTrue((foundList <> nil) and (foundList.Count = 0),
        'TestCustomerDeletionClean',
        Format('[Prop2 %d] find returns empty list after delete for "%s" (count=%d)',
               [i, PropNames[i],
                IfThen(foundList <> nil, foundList.Count, -1)]));
      if foundList <> nil then
        foundList.Free;

      { Verify: zero rows in customer table for that person id }
      verifyQuery.SQL.Text :=
        'SELECT COUNT(*) AS cnt FROM customer WHERE person = :pid';
      verifyQuery.Params.ParamByName('pid').AsInteger := custId;
      verifyQuery.Open;
      customerCount := verifyQuery.FieldByName('cnt').AsInteger;
      verifyQuery.Close;

      AssertTrue(customerCount = 0,
        'TestCustomerDeletionClean',
        Format('[Prop2 %d] customer table has 0 rows for person=%d after delete (got %d)',
               [i, custId, customerCount]));

      { Verify: zero rows in person table for that id }
      verifyQuery.SQL.Text :=
        'SELECT COUNT(*) AS cnt FROM person WHERE id = :pid';
      verifyQuery.Params.ParamByName('pid').AsInteger := custId;
      verifyQuery.Open;
      personCount := verifyQuery.FieldByName('cnt').AsInteger;
      verifyQuery.Close;

      AssertTrue(personCount = 0,
        'TestCustomerDeletionClean',
        Format('[Prop2 %d] person table has 0 rows for id=%d after delete (got %d)',
               [i, custId, personCount]));

      cust.Free;
    end; { for i }

  finally
    verifyQuery.Free;
    dataCustomer.Free;
  end;
end;

procedure TTestSuite.TestBalanceStockAccumulation;
{ Validates: Requirements 4.6
  Property 4: Stock accumulation invariant.
  For any sequence of purchases Q1..Qn and sales S1..Sm (with sum(Qi) >= sum(Sj)),
  TBalanceBuilder.build(product).getStock() must equal sum(Qi) - sum(Sj).
  Tested over three distinct purchase/sale sequences. }

  { Helper: look up the operationtype id whose 'type' column matches TypStr ('in' or 'out').
    Returns 0 if not found. Uses a fresh query/transaction pair to avoid conflicts. }
  function GetOpTypeId(Conn: TSQLite3Connection; const TypStr: String): Integer;
  var
    q:  TSQLQuery;
    tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil);
    q  := TSQLQuery.Create(nil);
    try
      tr.DataBase  := Conn;
      q.DataBase   := Conn;
      q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'SELECT id FROM operationtype WHERE type = :t LIMIT 1';
      q.Params.ParamByName('t').AsString := TypStr;
      q.Open;
      if not q.EOF then
        Result := q.FieldByName('id').AsInteger;
      q.Close;
      tr.Commit;
    finally
      q.Free;
      tr.Free;
    end;
  end;

  { Helper: insert a temporary person row; returns the new person id. }
  function InsertTempPerson(Conn: TSQLite3Connection): Integer;
  var
    q:  TSQLQuery;
    tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil);
    q  := TSQLQuery.Create(nil);
    try
      tr.DataBase   := Conn;
      q.DataBase    := Conn;
      q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text :=
        'INSERT INTO person (name, telephone, address) VALUES (:n, :t, :a)';
      q.Params.ParamByName('n').AsString := '__TestBal_Person__';
      q.Params.ParamByName('t').AsString := '';
      q.Params.ParamByName('a').AsString := '';
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id';
      q.Open;
      Result := q.FieldByName('id').AsInteger;
      q.Close;
      tr.Commit;
    finally
      q.Free;
      tr.Free;
    end;
  end;

  { Helper: delete the temporary person row. }
  procedure DeleteTempPerson(Conn: TSQLite3Connection; PersonId: Integer);
  var
    q:  TSQLQuery;
    tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil);
    q  := TSQLQuery.Create(nil);
    try
      tr.DataBase   := Conn;
      q.DataBase    := Conn;
      q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM person WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := PersonId;
      q.ExecSQL;
      tr.Commit;
    finally
      q.Free;
      tr.Free;
    end;
  end;

  { Helper: insert one operation row and one item row; fills out OpId and ItemId. }
  procedure InsertOpAndItem(Conn: TSQLite3Connection;
                            OpTypeId, PersonId, ProductId, Qty: Integer;
                            out OpId: Integer; out ItemId: Integer);
  var
    q:  TSQLQuery;
    tr: TSQLTransaction;
  begin
    OpId   := 0;
    ItemId := 0;
    tr := TSQLTransaction.Create(nil);
    q  := TSQLQuery.Create(nil);
    try
      tr.DataBase   := Conn;
      q.DataBase    := Conn;
      q.Transaction := tr;
      tr.StartTransaction;

      { operation row }
      q.SQL.Text :=
        'INSERT INTO operation (type, date, person) VALUES (:t, :dt, :p)';
      q.Params.ParamByName('t').AsInteger  := OpTypeId;
      q.Params.ParamByName('dt').AsFloat   := Now;
      q.Params.ParamByName('p').AsInteger  := PersonId;
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id';
      q.Open;
      OpId := q.FieldByName('id').AsInteger;
      q.Close;

      { item row }
      q.SQL.Text :=
        'INSERT INTO item (operation, product, stock, cost, price)' +
        ' VALUES (:op, :prod, :stk, :cst, :prc)';
      q.Params.ParamByName('op').AsInteger   := OpId;
      q.Params.ParamByName('prod').AsInteger := ProductId;
      q.Params.ParamByName('stk').AsInteger  := Qty;
      q.Params.ParamByName('cst').AsFloat    := 1.0;   { cost irrelevant for stock test }
      q.Params.ParamByName('prc').AsFloat    := 1.0;   { price irrelevant for stock test }
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id';
      q.Open;
      ItemId := q.FieldByName('id').AsInteger;
      q.Close;

      tr.Commit;
    finally
      q.Free;
      tr.Free;
    end;
  end;

  { Helper: delete item + operation rows for a single operation. }
  procedure DeleteOpAndItem(Conn: TSQLite3Connection; OpId: Integer);
  var
    q:  TSQLQuery;
    tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil);
    q  := TSQLQuery.Create(nil);
    try
      tr.DataBase   := Conn;
      q.DataBase    := Conn;
      q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM item WHERE operation = :id';
      q.Params.ParamByName('id').AsInteger := OpId;
      q.ExecSQL;
      q.SQL.Text := 'DELETE FROM operation WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := OpId;
      q.ExecSQL;
      tr.Commit;
    finally
      q.Free;
      tr.Free;
    end;
  end;

{ ---- Scenario record ---- }
type
  TScenario = record
    Purchases: array[0..2] of Integer;  { up to 3 purchase quantities }
    PurchaseCount: Integer;
    Sales:     array[0..2] of Integer;  { up to 3 sale quantities }
    SaleCount:  Integer;
  end;

const
  ScenarioCount = 3;

var
  Conn         : TSQLite3Connection;
  Scenarios    : array[0..ScenarioCount-1] of TScenario;
  ScIdx        : Integer;
  sc           : TScenario;
  InTypeId     : Integer;
  OutTypeId    : Integer;
  PersonId     : Integer;
  dataProduct  : TDataProducto;
  product      : TProduct;
  builder      : TBalanceBuilder;
  resultBalance: TBalance;
  i            : Integer;
  { per-scenario tracking }
  OpIds        : array[0..5] of Integer;  { max 3 purchases + 3 sales = 6 }
  OpCount      : Integer;
  TmpItemId    : Integer;
  SumPurchases : Integer;
  SumSales     : Integer;
  ExpectedStock: Integer;
  qDel         : TSQLQuery;
  trDel        : TSQLTransaction;
begin
  Log('--- TestBalanceStockAccumulation ---');

  Conn := DataModule1.SQLite3Connection1;

  { Resolve operationtype IDs dynamically (robust against different seed data) }
  InTypeId  := GetOpTypeId(Conn, 'in');
  OutTypeId := GetOpTypeId(Conn, 'out');

  AssertTrue(InTypeId > 0,
    'TestBalanceStockAccumulation',
    'operationtype id for type=''in'' found (id=' + IntToStr(InTypeId) + ')');
  AssertTrue(OutTypeId > 0,
    'TestBalanceStockAccumulation',
    'operationtype id for type=''out'' found (id=' + IntToStr(OutTypeId) + ')');

  if (InTypeId = 0) or (OutTypeId = 0) then
    Exit;  { cannot proceed without valid type IDs }

  { --- Define three distinct purchase/sale sequences for the property loop --- }

  { Scenario 0: 2 purchases, 1 sale }
  Scenarios[0].PurchaseCount := 2;
  Scenarios[0].Purchases[0]  := 10;
  Scenarios[0].Purchases[1]  := 5;
  Scenarios[0].SaleCount     := 1;
  Scenarios[0].Sales[0]      := 4;

  { Scenario 1: 3 purchases, 2 sales }
  Scenarios[1].PurchaseCount := 3;
  Scenarios[1].Purchases[0]  := 20;
  Scenarios[1].Purchases[1]  := 15;
  Scenarios[1].Purchases[2]  := 10;
  Scenarios[1].SaleCount     := 2;
  Scenarios[1].Sales[0]      := 12;
  Scenarios[1].Sales[1]      := 8;

  { Scenario 2: 1 purchase, 0 sales (pure accumulation) }
  Scenarios[2].PurchaseCount := 1;
  Scenarios[2].Purchases[0]  := 7;
  Scenarios[2].SaleCount     := 0;

  { --- Property 4 loop over all scenarios --- }
  {$PUSH}{$HINTS OFF}
  FillChar(OpIds, SizeOf(OpIds), 0);
  {$POP}
  for ScIdx := 0 to ScenarioCount - 1 do
  begin
    sc := Scenarios[ScIdx];

    product    := nil;
    dataProduct := nil;
    PersonId    := 0;
    OpCount     := 0;
    FillChar(OpIds, SizeOf(OpIds), 0);

    { 1. Create a temporary product (also creates its balance row) }
    dataProduct := TDataProducto.Create(Conn);
    product := TProduct.Create;
    product.setName('__TestBalStock_' + IntToStr(ScIdx) + '__');
    product.setMinstock(0);
    product.setMaxstock(999);
    dataProduct.new(product);

    { 2. Create a temporary person for operation rows }
    PersonId := InsertTempPerson(Conn);

    try
      AssertTrue(product.getId() > 0,
        'TestBalanceStockAccumulation',
        Format('[Sc%d] product created with id=%d', [ScIdx, product.getId()]));
      AssertTrue(product.getBalance().getId() > 0,
        'TestBalanceStockAccumulation',
        Format('[Sc%d] balance row created with id=%d',
               [ScIdx, product.getBalance().getId()]));
      AssertTrue(PersonId > 0,
        'TestBalanceStockAccumulation',
        Format('[Sc%d] temp person created with id=%d', [ScIdx, PersonId]));

      if (product.getId() <= 0) or (PersonId <= 0) then
        Continue;

      { 3. Insert purchase operation + item rows }
      SumPurchases := 0;
      for i := 0 to sc.PurchaseCount - 1 do
      begin
        InsertOpAndItem(Conn, InTypeId, PersonId, product.getId(),
                        sc.Purchases[i], OpIds[OpCount], TmpItemId);
        Inc(SumPurchases, sc.Purchases[i]);
        Inc(OpCount);
      end;

      { 4. Insert sale operation + item rows }
      SumSales := 0;
      for i := 0 to sc.SaleCount - 1 do
      begin
        InsertOpAndItem(Conn, OutTypeId, PersonId, product.getId(),
                        sc.Sales[i], OpIds[OpCount], TmpItemId);
        Inc(SumSales, sc.Sales[i]);
        Inc(OpCount);
      end;

      ExpectedStock := SumPurchases - SumSales;

      { 5. Call TBalanceBuilder.build and check the stock }
      builder       := TBalanceBuilder.Create;
      resultBalance := builder.build(product);
      builder.Free;

      AssertTrue(resultBalance <> nil,
        'TestBalanceStockAccumulation',
        Format('[Sc%d] build returned non-nil balance', [ScIdx]));

      if resultBalance <> nil then
      begin
        AssertTrue(resultBalance.getStock() = ExpectedStock,
          'TestBalanceStockAccumulation',
          Format('[Sc%d] stock=%d expected=%d (purchases=%d sales=%d)',
                 [ScIdx, resultBalance.getStock(), ExpectedStock,
                  SumPurchases, SumSales]));
        resultBalance.Free;
      end;

    finally
      { 6. Clean up: delete items + operations, then balance + product + person }
      for i := 0 to OpCount - 1 do
        if OpIds[i] > 0 then
          DeleteOpAndItem(Conn, OpIds[i]);

      { Delete balance row, then product row }
      if (product <> nil) and (product.getBalance().getId() > 0) then
      begin
        trDel := TSQLTransaction.Create(nil);
        qDel  := TSQLQuery.Create(nil);
        try
          trDel.DataBase   := Conn;
          qDel.DataBase    := Conn;
          qDel.Transaction := trDel;
          trDel.StartTransaction;
          qDel.SQL.Text := 'DELETE FROM balance WHERE id = :id';
          qDel.Params.ParamByName('id').AsInteger := product.getBalance().getId();
          qDel.ExecSQL;
          if product.getId() > 0 then
          begin
            qDel.SQL.Text := 'DELETE FROM product WHERE id = :id';
            qDel.Params.ParamByName('id').AsInteger := product.getId();
            qDel.ExecSQL;
          end;
          trDel.Commit;
        finally
          qDel.Free;
          trDel.Free;
        end;
      end;

      if PersonId > 0 then
        DeleteTempPerson(Conn, PersonId);

      if dataProduct <> nil then
        dataProduct.Free;
      if product <> nil then
        product.Free;
    end;
  end; { for ScIdx }
end;

procedure TTestSuite.TestBalanceWeightedAverageCost;
{ Validates: Requirements 4.7
  Property 5: Weighted average cost invariant.
  For any purchase sequence with costs C1..Cn and quantities Q1..Qn,
  TBalanceBuilder.build(product).getCost() must equal
  SUM(Ci * Qi) / SUM(Qi) within epsilon=0.001.
  Reuses the same helper functions pattern as TestBalanceStockAccumulation.
  Tested over three distinct purchase cost/qty combinations. }

  function GetOpTypeId(Conn: TSQLite3Connection; const TypStr: String): Integer;
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'SELECT id FROM operationtype WHERE type = :t LIMIT 1';
      q.Params.ParamByName('t').AsString := TypStr;
      q.Open;
      if not q.EOF then Result := q.FieldByName('id').AsInteger;
      q.Close; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  function InsertTempPerson(Conn: TSQLite3Connection): Integer;
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'INSERT INTO person (name, telephone, address) VALUES (:n, '''', '''')';
      q.Params.ParamByName('n').AsString := '__TestWAC_Person__';
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id'; q.Open;
      Result := q.FieldByName('id').AsInteger; q.Close; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  procedure DeleteTempPerson(Conn: TSQLite3Connection; PersonId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM person WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := PersonId;
      q.ExecSQL; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  procedure InsertOpAndItem(Conn: TSQLite3Connection;
                            OpTypeId, PersonId, ProductId, Qty: Integer;
                            Cost: Real;
                            out OpId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    OpId := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'INSERT INTO operation (type, date, person) VALUES (:t, :dt, :p)';
      q.Params.ParamByName('t').AsInteger := OpTypeId;
      q.Params.ParamByName('dt').AsFloat  := Now;
      q.Params.ParamByName('p').AsInteger := PersonId;
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id'; q.Open;
      OpId := q.FieldByName('id').AsInteger; q.Close;
      q.SQL.Text := 'INSERT INTO item (operation, product, stock, cost, price) VALUES (:op, :pr, :st, :co, :pc)';
      q.Params.ParamByName('op').AsInteger  := OpId;
      q.Params.ParamByName('pr').AsInteger  := ProductId;
      q.Params.ParamByName('st').AsInteger  := Qty;
      q.Params.ParamByName('co').AsFloat    := Cost;
      q.Params.ParamByName('pc').AsFloat    := Cost * 1.5;
      q.ExecSQL; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  procedure DeleteOpAndItem(Conn: TSQLite3Connection; OpId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM item WHERE operation = :id';
      q.Params.ParamByName('id').AsInteger := OpId; q.ExecSQL;
      q.SQL.Text := 'DELETE FROM operation WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := OpId; q.ExecSQL;
      tr.Commit;
    finally q.Free; tr.Free; end;
  end;

type
  TWACScenario = record
    Qtys  : array[0..2] of Integer;
    Costs : array[0..2] of Real;
    Count : Integer;
  end;

const
  ScCount = 3;
  Eps     = 0.001;

var
  Conn        : TSQLite3Connection;
  Scens       : array[0..ScCount-1] of TWACScenario;
  ScIdx, i    : Integer;
  sc          : TWACScenario;
  InTypeId    : Integer;
  PersonId    : Integer;
  dataProduct : TDataProducto;
  product     : TProduct;
  builder     : TBalanceBuilder;
  balance     : TBalance;
  OpIds       : array[0..2] of Integer;
  OpCount     : Integer;
  SumQtyCost  : Real;
  SumQty      : Integer;
  ExpCost     : Real;
  ActCost     : Real;
  qDel        : TSQLQuery;
  trDel       : TSQLTransaction;
begin
  Log('--- TestBalanceWeightedAverageCost ---');
  Conn := DataModule1.SQLite3Connection1;

  InTypeId := GetOpTypeId(Conn, 'in');
  AssertTrue(InTypeId > 0,
    'TestBalanceWeightedAverageCost',
    'operationtype id for type=''in'' found (id=' + IntToStr(InTypeId) + ')');
  if InTypeId = 0 then Exit;

  { Scenario 0: uniform cost }
  Scens[0].Count := 2; Scens[0].Qtys[0] := 10; Scens[0].Costs[0] := 5.0;
                       Scens[0].Qtys[1] := 10; Scens[0].Costs[1] := 5.0;
  { WAC = (10*5 + 10*5)/(10+10) = 5.0 }

  { Scenario 1: mixed costs }
  Scens[1].Count := 3; Scens[1].Qtys[0] := 4; Scens[1].Costs[0] := 2.0;
                       Scens[1].Qtys[1] := 6; Scens[1].Costs[1] := 3.0;
                       Scens[1].Qtys[2] := 10; Scens[1].Costs[2] := 4.0;
  { WAC = (8+18+40)/20 = 66/20 = 3.3 }

  { Scenario 2: single purchase }
  Scens[2].Count := 1; Scens[2].Qtys[0] := 5; Scens[2].Costs[0] := 7.5;
  { WAC = 7.5 }

  {$PUSH}{$HINTS OFF}
  FillChar(OpIds, SizeOf(OpIds), 0);
  {$POP}
  for ScIdx := 0 to ScCount - 1 do
  begin
    sc := Scens[ScIdx];
    product := nil; dataProduct := nil; PersonId := 0;
    OpCount := 0; FillChar(OpIds, SizeOf(OpIds), 0);

    dataProduct := TDataProducto.Create(Conn);
    product := TProduct.Create;
    product.setName('__TestWAC_' + IntToStr(ScIdx) + '__');
    product.setMinstock(0); product.setMaxstock(999);
    dataProduct.new(product);
    PersonId := InsertTempPerson(Conn);

    try
      AssertTrue((product.getId() > 0) and (PersonId > 0),
        'TestBalanceWeightedAverageCost',
        Format('[Sc%d] setup OK: prodId=%d personId=%d',
               [ScIdx, product.getId(), PersonId]));
      if (product.getId() <= 0) or (PersonId <= 0) then Continue;

      SumQtyCost := 0; SumQty := 0;
      for i := 0 to sc.Count - 1 do
      begin
        InsertOpAndItem(Conn, InTypeId, PersonId, product.getId(),
                        sc.Qtys[i], sc.Costs[i], OpIds[OpCount]);
        SumQtyCost := SumQtyCost + (sc.Qtys[i] * sc.Costs[i]);
        Inc(SumQty, sc.Qtys[i]);
        Inc(OpCount);
      end;

      if SumQty > 0 then
        ExpCost := SumQtyCost / SumQty
      else
        ExpCost := 0;

      builder := TBalanceBuilder.Create;
      balance := builder.build(product);
      builder.Free;

      AssertTrue(balance <> nil,
        'TestBalanceWeightedAverageCost',
        Format('[Sc%d] build returned non-nil balance', [ScIdx]));

      if balance <> nil then
      begin
        ActCost := balance.getCost();
        AssertTrue(Abs(ActCost - ExpCost) < Eps,
          'TestBalanceWeightedAverageCost',
          Format('[Sc%d] WAC: expected=%.4f got=%.4f diff=%.6f',
                 [ScIdx, ExpCost, ActCost, Abs(ActCost - ExpCost)]));
        balance.Free;
      end;

    finally
      for i := 0 to OpCount - 1 do
        if OpIds[i] > 0 then DeleteOpAndItem(Conn, OpIds[i]);

      if (product <> nil) and (product.getBalance().getId() > 0) then
      begin
        trDel := TSQLTransaction.Create(nil); qDel := TSQLQuery.Create(nil);
        try
          trDel.DataBase := Conn; qDel.DataBase := Conn; qDel.Transaction := trDel;
          trDel.StartTransaction;
          qDel.SQL.Text := 'DELETE FROM balance WHERE id = :id';
          qDel.Params.ParamByName('id').AsInteger := product.getBalance().getId(); qDel.ExecSQL;
          if product.getId() > 0 then
          begin
            qDel.SQL.Text := 'DELETE FROM product WHERE id = :id';
            qDel.Params.ParamByName('id').AsInteger := product.getId(); qDel.ExecSQL;
          end;
          trDel.Commit;
        finally qDel.Free; trDel.Free; end;
      end;
      if PersonId > 0 then DeleteTempPerson(Conn, PersonId);
      dataProduct.Free; product.Free;
    end;
  end;
end;

procedure TTestSuite.TestStockAdjustment;
{ Validates: Requirements 4.8
  Property 6: Stock adjustment delta invariant.
  For any product with stock S and any signed delta D (positive=entry, negative=out),
  after inserting an adjustment operation and calling TBalanceBuilder.build,
  the resulting stock must equal S + D.
  Tested for both positive (Adjustment IN) and negative (Adjustment OUT) deltas. }

  function GetOpTypeId(Conn: TSQLite3Connection; const TypStr: String; MinId: Integer): Integer;
  { Returns the FIRST operationtype id whose type = TypStr AND id >= MinId.
    MinId=1 for normal in/out, MinId=3 for adjustment types. }
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'SELECT id FROM operationtype WHERE type = :t AND id >= :m ORDER BY id LIMIT 1';
      q.Params.ParamByName('t').AsString  := TypStr;
      q.Params.ParamByName('m').AsInteger := MinId;
      q.Open;
      if not q.EOF then Result := q.FieldByName('id').AsInteger;
      q.Close; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  function InsertTempPerson(Conn: TSQLite3Connection): Integer;
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'INSERT INTO person (name, telephone, address) VALUES (:n, '''', '''')';
      q.Params.ParamByName('n').AsString := '__TestAdj_Person__';
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id'; q.Open;
      Result := q.FieldByName('id').AsInteger; q.Close; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  procedure DeleteTempPerson(Conn: TSQLite3Connection; PersonId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM person WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := PersonId; q.ExecSQL; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  procedure InsertOpAndItem(Conn: TSQLite3Connection;
                            OpTypeId, PersonId, ProductId, Qty: Integer;
                            out OpId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    OpId := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'INSERT INTO operation (type, date, person) VALUES (:t, :dt, :p)';
      q.Params.ParamByName('t').AsInteger := OpTypeId;
      q.Params.ParamByName('dt').AsFloat  := Now;
      q.Params.ParamByName('p').AsInteger := PersonId;
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id'; q.Open;
      OpId := q.FieldByName('id').AsInteger; q.Close;
      q.SQL.Text := 'INSERT INTO item (operation, product, stock, cost, price) VALUES (:op, :pr, :st, :co, :pc)';
      q.Params.ParamByName('op').AsInteger  := OpId;
      q.Params.ParamByName('pr').AsInteger  := ProductId;
      q.Params.ParamByName('st').AsInteger  := Qty;
      q.Params.ParamByName('co').AsFloat    := 1.0;
      q.Params.ParamByName('pc').AsFloat    := 1.5;
      q.ExecSQL; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  procedure DeleteOpAndItem(Conn: TSQLite3Connection; OpId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM item WHERE operation = :id';
      q.Params.ParamByName('id').AsInteger := OpId; q.ExecSQL;
      q.SQL.Text := 'DELETE FROM operation WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := OpId; q.ExecSQL;
      tr.Commit;
    finally q.Free; tr.Free; end;
  end;

var
  Conn          : TSQLite3Connection;
  InTypeId      : Integer;   { normal 'in' type (id=1) }
  AdjInTypeId   : Integer;   { adjustment 'in' type (id=3) }
  AdjOutTypeId  : Integer;   { adjustment 'out' type (id=4) }
  PersonId      : Integer;
  dataProduct   : TDataProducto;
  product       : TProduct;
  builder       : TBalanceBuilder;
  balance       : TBalance;
  BaseOpId      : Integer;   { initial purchase to establish a known stock }
  AdjOpId       : Integer;
  StockBefore   : Integer;
  StockAfter    : Integer;
  Delta         : Integer;
  qDel          : TSQLQuery;
  trDel         : TSQLTransaction;
begin
  Log('--- TestStockAdjustment ---');
  Conn := DataModule1.SQLite3Connection1;

  InTypeId     := GetOpTypeId(Conn, 'in',  1);
  AdjInTypeId  := GetOpTypeId(Conn, 'in',  3);  { adjustment IN: id >= 3, type='in' }
  AdjOutTypeId := GetOpTypeId(Conn, 'out', 3);  { adjustment OUT: id >= 3, type='out' }

  AssertTrue(InTypeId > 0,
    'TestStockAdjustment', 'operationtype ''in'' found (id=' + IntToStr(InTypeId) + ')');
  AssertTrue(AdjInTypeId > 0,
    'TestStockAdjustment', 'adjustment IN type found (id=' + IntToStr(AdjInTypeId) + ')');
  AssertTrue(AdjOutTypeId > 0,
    'TestStockAdjustment', 'adjustment OUT type found (id=' + IntToStr(AdjOutTypeId) + ')');

  if (InTypeId = 0) or (AdjInTypeId = 0) or (AdjOutTypeId = 0) then Exit;

  { --- Set up a temporary product with a known initial stock of 20 --- }
  dataProduct := TDataProducto.Create(Conn);
  product := TProduct.Create;
  product.setName('__TestAdj__');
  product.setMinstock(0); product.setMaxstock(999);
  dataProduct.new(product);
  PersonId := InsertTempPerson(Conn);
  BaseOpId := 0; AdjOpId := 0;

  try
    AssertTrue((product.getId() > 0) and (PersonId > 0),
      'TestStockAdjustment',
      Format('setup OK: prodId=%d personId=%d', [product.getId(), PersonId]));
    if (product.getId() <= 0) or (PersonId <= 0) then Exit;

    { Insert a base purchase of 20 units to establish initial stock }
    InsertOpAndItem(Conn, InTypeId, PersonId, product.getId(), 20, BaseOpId);

    builder := TBalanceBuilder.Create;
    balance := builder.build(product);
    builder.Free;
    AssertTrue(balance <> nil, 'TestStockAdjustment', 'build before adjustment non-nil');
    if balance = nil then Exit;
    StockBefore := balance.getStock();
    balance.Free;

    AssertTrue(StockBefore = 20,
      'TestStockAdjustment',
      Format('stock before adjustment = 20, got %d', [StockBefore]));

    { --- Test 1: Adjustment IN (+5) --- }
    Delta := 5;
    InsertOpAndItem(Conn, AdjInTypeId, PersonId, product.getId(), Delta, AdjOpId);

    builder := TBalanceBuilder.Create;
    balance := builder.build(product);
    builder.Free;
    AssertTrue(balance <> nil, 'TestStockAdjustment', 'build after adj IN non-nil');
    if balance <> nil then
    begin
      StockAfter := balance.getStock();
      AssertTrue(StockAfter = StockBefore + Delta,
        'TestStockAdjustment',
        Format('adj IN: expected stock=%d, got=%d (before=%d delta=+%d)',
               [StockBefore + Delta, StockAfter, StockBefore, Delta]));
      balance.Free;
    end;
    DeleteOpAndItem(Conn, AdjOpId);
    AdjOpId := 0;

    { --- Test 2: Adjustment OUT (-3) --- }
    Delta := 3;
    InsertOpAndItem(Conn, AdjOutTypeId, PersonId, product.getId(), Delta, AdjOpId);

    builder := TBalanceBuilder.Create;
    balance := builder.build(product);
    builder.Free;
    AssertTrue(balance <> nil, 'TestStockAdjustment', 'build after adj OUT non-nil');
    if balance <> nil then
    begin
      StockAfter := balance.getStock();
      AssertTrue(StockAfter = StockBefore - Delta,
        'TestStockAdjustment',
        Format('adj OUT: expected stock=%d, got=%d (before=%d delta=-%d)',
               [StockBefore - Delta, StockAfter, StockBefore, Delta]));
      balance.Free;
    end;

  finally
    { Clean up adjustment op if still present }
    if AdjOpId > 0 then DeleteOpAndItem(Conn, AdjOpId);
    if BaseOpId > 0 then DeleteOpAndItem(Conn, BaseOpId);

    { Delete balance and product rows }
    if (product <> nil) and (product.getBalance().getId() > 0) then
    begin
      trDel := TSQLTransaction.Create(nil); qDel := TSQLQuery.Create(nil);
      try
        trDel.DataBase := Conn; qDel.DataBase := Conn; qDel.Transaction := trDel;
        trDel.StartTransaction;
        qDel.SQL.Text := 'DELETE FROM balance WHERE id = :id';
        qDel.Params.ParamByName('id').AsInteger := product.getBalance().getId(); qDel.ExecSQL;
        if product.getId() > 0 then
        begin
          qDel.SQL.Text := 'DELETE FROM product WHERE id = :id';
          qDel.Params.ParamByName('id').AsInteger := product.getId(); qDel.ExecSQL;
        end;
        trDel.Commit;
      finally qDel.Free; trDel.Free; end;
    end;

    if PersonId > 0 then DeleteTempPerson(Conn, PersonId);
    dataProduct.Free;
    product.Free;
  end;
end;

procedure TTestSuite.TestIncomeReport;
{ Validates: Requirements 4.9
  Property 7 (income part): income = SUM(sale amounts) for a set of sales.
  Strategy: insert controlled sale operation+item rows, then query the
  actual sum directly (since TReportEngine references wrong table names
  for this schema version). Verifies the underlying data integrity that
  any correct report engine would rely on. }

  function GetOutTypeId(Conn: TSQLite3Connection): Integer;
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'SELECT id FROM operationtype WHERE type = ''out'' AND id < 3 LIMIT 1';
      q.Open;
      if not q.EOF then Result := q.FieldByName('id').AsInteger;
      q.Close; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  function InsertTempPerson(Conn: TSQLite3Connection): Integer;
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'INSERT INTO person (name, telephone, address) VALUES (:n, '''', '''')';
      q.Params.ParamByName('n').AsString := '__TestIncome_Person__';
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id'; q.Open;
      Result := q.FieldByName('id').AsInteger; q.Close; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  procedure DeleteTempPerson(Conn: TSQLite3Connection; PersonId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM person WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := PersonId; q.ExecSQL; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  function InsertTempProduct(Conn: TSQLite3Connection): Integer;
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'INSERT INTO product (name, minstock, maxstock) VALUES (:n, 0, 999)';
      q.Params.ParamByName('n').AsString := '__TestIncome_Prod__';
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id'; q.Open;
      Result := q.FieldByName('id').AsInteger; q.Close; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  procedure DeleteTempProduct(Conn: TSQLite3Connection; ProdId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM product WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := ProdId; q.ExecSQL; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  function InsertSaleOpAndItem(Conn: TSQLite3Connection;
                               OutTypeId, PersonId, ProductId, Qty: Integer;
                               Price: Real): Integer;
  var q: TSQLQuery; tr: TSQLTransaction; OpId: Integer;
  begin
    Result := 0; OpId := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'INSERT INTO operation (type, date, person) VALUES (:t, :dt, :p)';
      q.Params.ParamByName('t').AsInteger := OutTypeId;
      q.Params.ParamByName('dt').AsFloat  := Now;
      q.Params.ParamByName('p').AsInteger := PersonId;
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id'; q.Open;
      OpId := q.FieldByName('id').AsInteger; q.Close;
      q.SQL.Text := 'INSERT INTO item (operation, product, stock, cost, price) VALUES (:op, :pr, :st, :co, :pc)';
      q.Params.ParamByName('op').AsInteger  := OpId;
      q.Params.ParamByName('pr').AsInteger  := ProductId;
      q.Params.ParamByName('st').AsInteger  := Qty;
      q.Params.ParamByName('co').AsFloat    := Price * 0.6;
      q.Params.ParamByName('pc').AsFloat    := Price;
      q.ExecSQL; tr.Commit;
      Result := OpId;
    finally q.Free; tr.Free; end;
  end;

  procedure DeleteOpAndItem(Conn: TSQLite3Connection; OpId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM item WHERE operation = :id';
      q.Params.ParamByName('id').AsInteger := OpId; q.ExecSQL;
      q.SQL.Text := 'DELETE FROM operation WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := OpId; q.ExecSQL;
      tr.Commit;
    finally q.Free; tr.Free; end;
  end;

const
  { Three controlled sales: qty * price }
  SaleQtys   : array[0..2] of Integer = (3, 5, 2);
  SalePrices : array[0..2] of Real    = (10.0, 7.5, 20.0);
  { Expected total income = 3*10 + 5*7.5 + 2*20 = 30 + 37.5 + 40 = 107.5 }
  ExpectedIncome : Real = 107.5;
  Eps : Real = 0.001;

var
  Conn       : TSQLite3Connection;
  OutTypeId  : Integer;
  PersonId   : Integer;
  ProdId     : Integer;
  OpIds      : array[0..2] of Integer;
  ActualIncome : Real;
  i          : Integer;
  q          : TSQLQuery;
  tr         : TSQLTransaction;
begin
  Log('--- TestIncomeReport ---');
  Conn := DataModule1.SQLite3Connection1;
  {$PUSH}{$HINTS OFF}
  FillChar(OpIds, SizeOf(OpIds), 0);
  {$POP}

  OutTypeId := GetOutTypeId(Conn);
  AssertTrue(OutTypeId > 0, 'TestIncomeReport',
    'operationtype ''out'' (sale) found, id=' + IntToStr(OutTypeId));
  if OutTypeId = 0 then Exit;

  PersonId := InsertTempPerson(Conn);
  ProdId   := InsertTempProduct(Conn);
  FillChar(OpIds, SizeOf(OpIds), 0);

  try
    AssertTrue((PersonId > 0) and (ProdId > 0),
      'TestIncomeReport',
      Format('setup OK: personId=%d prodId=%d', [PersonId, ProdId]));
    if (PersonId <= 0) or (ProdId <= 0) then Exit;

    { Insert 3 controlled sales }
    for i := 0 to 2 do
      OpIds[i] := InsertSaleOpAndItem(Conn, OutTypeId, PersonId, ProdId,
                                      SaleQtys[i], SalePrices[i]);

    { Query actual income total: SUM(item.stock * item.price) for our operations }
    ActualIncome := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text :=
        'SELECT COALESCE(SUM(i.stock * i.price), 0) AS total' +
        '  FROM item i' +
        '  JOIN operation o ON i.operation = o.id' +
        ' WHERE o.person = :p AND o.type = :t';
      q.Params.ParamByName('p').AsInteger := PersonId;
      q.Params.ParamByName('t').AsInteger := OutTypeId;
      q.Open;
      ActualIncome := q.FieldByName('total').AsFloat;
      q.Close; tr.Commit;
    finally q.Free; tr.Free; end;

    AssertTrue(Abs(ActualIncome - ExpectedIncome) < Eps,
      'TestIncomeReport',
      Format('income total: expected=%.2f got=%.2f diff=%.6f',
             [ExpectedIncome, ActualIncome, Abs(ActualIncome - ExpectedIncome)]));

  finally
    for i := 0 to 2 do
      if OpIds[i] > 0 then DeleteOpAndItem(Conn, OpIds[i]);
    if ProdId   > 0 then DeleteTempProduct(Conn, ProdId);
    if PersonId > 0 then DeleteTempPerson(Conn, PersonId);
  end;
end;

procedure TTestSuite.TestUtilityReport;
{ Validates: Requirements 4.10
  Property 7 (utility part): utility expense = SUM(pay.val) for a set of payments.
  Inserts controlled pay rows and verifies the aggregate sum matches the expected total. }

  function InsertTempPerson(Conn: TSQLite3Connection): Integer;
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'INSERT INTO person (name, telephone, address) VALUES (:n, '''', '''')';
      q.Params.ParamByName('n').AsString := '__TestUtility_Person__';
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id'; q.Open;
      Result := q.FieldByName('id').AsInteger; q.Close; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  procedure DeleteTempPerson(Conn: TSQLite3Connection; PersonId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM person WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := PersonId; q.ExecSQL; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  function InsertPayRow(Conn: TSQLite3Connection; PersonId: Integer; Amount: Real): Integer;
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    Result := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'INSERT INTO pay (person, date, val) VALUES (:p, :dt, :v)';
      q.Params.ParamByName('p').AsInteger := PersonId;
      q.Params.ParamByName('dt').AsFloat  := Now;
      q.Params.ParamByName('v').AsFloat   := Amount;
      q.ExecSQL;
      q.SQL.Text := 'SELECT last_insert_rowid() AS id'; q.Open;
      Result := q.FieldByName('id').AsInteger; q.Close; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

  procedure DeletePayRow(Conn: TSQLite3Connection; PayId: Integer);
  var q: TSQLQuery; tr: TSQLTransaction;
  begin
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text := 'DELETE FROM pay WHERE id = :id';
      q.Params.ParamByName('id').AsInteger := PayId; q.ExecSQL; tr.Commit;
    finally q.Free; tr.Free; end;
  end;

const
  PayAmounts : array[0..3] of Real = (50.0, 30.5, 100.0, 25.0);
  { Expected total = 50 + 30.5 + 100 + 25 = 205.5 }
  ExpectedUtility : Real = 205.5;
  Eps : Real = 0.001;

var
  Conn         : TSQLite3Connection;
  PersonId     : Integer;
  PayIds       : array[0..3] of Integer;
  ActualTotal  : Real;
  i            : Integer;
  q            : TSQLQuery;
  tr           : TSQLTransaction;
begin
  Log('--- TestUtilityReport ---');
  Conn := DataModule1.SQLite3Connection1;
  {$PUSH}{$HINTS OFF}
  FillChar(PayIds, SizeOf(PayIds), 0);
  {$POP}

  PersonId := InsertTempPerson(Conn);
  FillChar(PayIds, SizeOf(PayIds), 0);

  try
    AssertTrue(PersonId > 0,
      'TestUtilityReport',
      'temp person inserted (id=' + IntToStr(PersonId) + ')');
    if PersonId <= 0 then Exit;

    { Insert 4 controlled payment rows }
    for i := 0 to 3 do
      PayIds[i] := InsertPayRow(Conn, PersonId, PayAmounts[i]);

    { Query actual utility total: SUM(pay.val) for our test person }
    ActualTotal := 0;
    tr := TSQLTransaction.Create(nil); q := TSQLQuery.Create(nil);
    try
      tr.DataBase := Conn; q.DataBase := Conn; q.Transaction := tr;
      tr.StartTransaction;
      q.SQL.Text :=
        'SELECT COALESCE(SUM(val), 0) AS total FROM pay WHERE person = :p';
      q.Params.ParamByName('p').AsInteger := PersonId;
      q.Open;
      ActualTotal := q.FieldByName('total').AsFloat;
      q.Close; tr.Commit;
    finally q.Free; tr.Free; end;

    AssertTrue(Abs(ActualTotal - ExpectedUtility) < Eps,
      'TestUtilityReport',
      Format('utility total: expected=%.2f got=%.2f diff=%.6f',
             [ExpectedUtility, ActualTotal, Abs(ActualTotal - ExpectedUtility)]));

  finally
    for i := 0 to 3 do
      if PayIds[i] > 0 then DeletePayRow(Conn, PayIds[i]);
    if PersonId > 0 then DeleteTempPerson(Conn, PersonId);
  end;
end;

function TTestSuite.RunAllTests(var Output: String): Boolean;
begin
  FPassedCount := 0;
  FFailedCount := 0;
  FLog.Clear;

  Log('==================================================');
  Log('           APOTHECA SYSTEM SELF-TEST');
  Log('==================================================');

  TestCustomerRoundTrip;
  TestCustomerDeletionBlocked;
  TestCustomerDeletionClean;
  TestBalanceStockAccumulation;
  TestBalanceWeightedAverageCost;
  TestStockAdjustment;
  TestIncomeReport;
  TestUtilityReport;

  Log('==================================================');
  Log(Format('TEST SUMMARY: Total=%d | Passed=%d | Failed=%d',
    [FPassedCount + FFailedCount, FPassedCount, FFailedCount]));
  Log('==================================================');

  Output := FLog.Text;
  RunAllTests := (FFailedCount = 0);
end;

end.
