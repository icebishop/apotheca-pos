{ Apothêca - Database / transaction persistence tests

  Consolidated DB test suite (formerly the ad-hoc diag_purchase diagnostic).
  Exercises the repository transaction layer end-to-end against a fresh,
  self-contained SQLite database created in a temp file - it does NOT touch the
  live db/invcar. Each test builds the real schema, seeds minimal data, and
  drives TDataIn/TDataTransaction (the purchase-save path) plus commit/rollback
  behaviour and the TData.free() shared-transaction safety.

  Run with: tests/run_db_test  (see run_db_test.lpr)
}
unit test_db;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, sqlite3conn, sqldb,
  UProduct, UBalance, USupplier, UPerson, UItem, UPurchase, UOperationType,
  UDataProduct, UDataIn, UDataBalance, UData;

type

  { TDBTest }

  TDBTest = class(TTestCase)
  private
    FConn: TSQLite3Connection;
    FTrans: TSQLTransaction;
    FDbPath: String;
    procedure ExecSQL(const ASql: String);
    function ScalarInt(const ASql: String): Integer;
    procedure CreateSchema;
    procedure SeedData;
    { Builds a purchase (supplier id=1) with one item for product id=1. }
    function BuildPurchase(AQty: Integer; ACost, APrice: Real): TPurchase;
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    { The exact path we debugged: insert operation + item + update balance. }
    procedure TestSavePurchaseCommits;
    { A committed purchase must increase the product balance stock. }
    procedure TestPurchaseIncrementsStock;
    { Multiple items in one transaction all persist atomically. }
    procedure TestMultiItemPurchase;
    { Rolling back a started transaction must leave no operation rows. }
    procedure TestRollbackLeavesNoRows;
    { TData.free() must NOT destroy the shared connection transaction; after
      freeing a TData instance the connection must still be usable. }
    procedure TestDataFreeKeepsSharedTransaction;
    { A nil operation type must fail cleanly (return 0), not throw uncaught. }
    procedure TestNilOperationTypeFailsCleanly;
    { Regression: a product with NO balance row (e.g. created without one) must
      get a balance created on purchase, not silently lose the stock. This is
      the "Portatiza O'min: stock 0 after 3 purchases" bug. }
    procedure TestPurchaseCreatesMissingBalance;
    { The balance repair path: TDataBalance.new must insert a correct row for a
      product that has purchase history but no balance row (what the balance
      builder relies on to fix O'min-style products). }
    procedure TestDataBalanceInsertForMissingProduct;
  end;

implementation

{ ---- helpers ---------------------------------------------------------------}

procedure TDBTest.ExecSQL(const ASql: String);
var
  q: TSQLQuery;
begin
  q := TSQLQuery.Create(nil);
  try
    q.DataBase := FConn;
    q.Transaction := FTrans;
    q.SQL.Text := ASql;
    q.ExecSQL;
  finally
    q.Free;
  end;
end;

function TDBTest.ScalarInt(const ASql: String): Integer;
var
  q: TSQLQuery;
begin
  Result := -1;
  q := TSQLQuery.Create(nil);
  try
    q.DataBase := FConn;
    q.Transaction := FTrans;
    q.SQL.Text := ASql;
    q.Open;
    if not q.EOF then
      Result := q.Fields[0].AsInteger;
    q.Close;
  finally
    q.Free;
  end;
end;

procedure TDBTest.CreateSchema;
begin
  { Mirrors InitDefaultDatabaseSchema + MigrateCreditColumn (operation.credit). }
  ExecSQL('CREATE TABLE person (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
          ' name TEXT NOT NULL, telephone TEXT, address TEXT);');
  ExecSQL('CREATE TABLE product (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
          ' name TEXT NOT NULL, minstock INTEGER, maxstock INTEGER,' +
          ' image_ref INTEGER DEFAULT 0, originalprice REAL DEFAULT 0.0,' +
          ' isservice INTEGER DEFAULT 0, category TEXT DEFAULT '''',' +
          ' description TEXT DEFAULT '''', brand TEXT DEFAULT '''',' +
          ' condition TEXT DEFAULT '''', google_product_category TEXT DEFAULT '''');');
  ExecSQL('CREATE TABLE balance (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
          ' product INTEGER NOT NULL, units INTEGER NOT NULL, balance REAL NOT NULL,' +
          ' cost REAL NOT NULL, price REAL NOT NULL);');
  ExecSQL('CREATE TABLE operationtype (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
          ' description TEXT, type TEXT);');
  ExecSQL('CREATE TABLE operation (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
          ' type INTEGER NOT NULL, date REAL, person INTEGER, credit INTEGER DEFAULT 0);');
  ExecSQL('CREATE TABLE item (id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
          ' product INTEGER NOT NULL, operation INTEGER NOT NULL, cost REAL NOT NULL,' +
          ' stock INTEGER NOT NULL, price REAL NOT NULL);');
end;

procedure TDBTest.SeedData;
begin
  { Operation type 1 = purchase ('in'), matching TPurchase's default. }
  ExecSQL('INSERT INTO operationtype (id, description, type) VALUES (1, ''Compra'', ''in'');');
  ExecSQL('INSERT INTO operationtype (id, description, type) VALUES (2, ''Venta'', ''out'');');
  { Supplier / person id 1. }
  ExecSQL('INSERT INTO person (id, name) VALUES (1, ''Proveedor Test'');');
  { Product id 1 with an existing balance row (stock 5). }
  ExecSQL('INSERT INTO product (id, name, minstock, maxstock) VALUES (1, ''Producto Test'', 0, 100);');
  ExecSQL('INSERT INTO product (id, name, minstock, maxstock) VALUES (2, ''Producto Test 2'', 0, 100);');
  { Product 3 intentionally has NO balance row (reproduces the O'min bug). }
  ExecSQL('INSERT INTO product (id, name, minstock, maxstock) VALUES (3, ''Sin Balance'', 0, 100);');
  ExecSQL('INSERT INTO balance (id, product, units, balance, cost, price)' +
          ' VALUES (1, 1, 5, 5000.0, 1000.0, 1500.0);');
  ExecSQL('INSERT INTO balance (id, product, units, balance, cost, price)' +
          ' VALUES (2, 2, 3, 3000.0, 1000.0, 1500.0);');
  FTrans.Commit;
  FTrans.StartTransaction;
end;

function TDBTest.BuildPurchase(AQty: Integer; ACost, APrice: Real): TPurchase;
var
  dp: TDataProducto;
  prod: TProduct;
  sup: TSupplier;
  item: TItem;
  items: TList;
  purchase: TPurchase;
begin
  dp := TDataProducto.Create(FConn);
  try
    prod := dp.get(1);
  finally
    dp.Destroy;
  end;
  AssertNotNull('product 1 loaded', prod);
  AssertNotNull('product 1 has balance', prod.getBalance());

  sup := TSupplier.Create;
  sup.setId(1);

  purchase := TPurchase.Create;   { sets operation type 1 }
  purchase.setSupplier(sup);
  purchase.setDate(Now);

  item := TItem.Create;
  item.setProduct(prod);
  item.setStock(AQty);
  item.setCost(ACost);
  item.setPrice(APrice);

  items := TList.Create;
  items.Add(item);
  purchase.setItemList(items);

  Result := purchase;
end;

{ ---- fixture ---------------------------------------------------------------}

procedure TDBTest.SetUp;
begin
  FDbPath := GetTempDir(False) + 'apotheca_test_' + IntToStr(Random(1000000)) + '.sqlite';
  if FileExists(FDbPath) then
    DeleteFile(FDbPath);
  FConn := TSQLite3Connection.Create(nil);
  FTrans := TSQLTransaction.Create(nil);
  FConn.DatabaseName := FDbPath;
  FConn.Transaction := FTrans;
  FTrans.DataBase := FConn;
  FConn.Open;
  if not FTrans.Active then
    FTrans.StartTransaction;
  CreateSchema;
  FTrans.Commit;
  FTrans.StartTransaction;
  SeedData;
end;

procedure TDBTest.TearDown;
begin
  try
    if FConn.Connected then
    begin
      if (FConn.Transaction <> nil) and FConn.Transaction.Active then
        FConn.Transaction.Rollback;
      FConn.Close;
    end;
  except
    { ignore teardown errors }
  end;
  FTrans.Free;
  FConn.Free;
  if FileExists(FDbPath) then
    DeleteFile(FDbPath);
end;

{ ---- tests -----------------------------------------------------------------}

procedure TDBTest.TestSavePurchaseCommits;
var
  purchase: TPurchase;
  dataIn: TDataIn;
  newId: Integer;
begin
  purchase := BuildPurchase(2, 1000, 1500);
  purchase.calculateNewBalance();

  dataIn := TDataIn.Create(FConn);
  try
    newId := dataIn.new(purchase);
  finally
    dataIn.Destroy;
  end;

  AssertTrue('dataIn.new returned a positive operation id (got ' + IntToStr(newId) + ')',
    newId > 0);
  FTrans.Commit;
  FTrans.StartTransaction;

  AssertEquals('one operation row persisted', 1,
    ScalarInt('SELECT COUNT(*) FROM operation'));
  AssertEquals('one item row persisted', 1,
    ScalarInt('SELECT COUNT(*) FROM item WHERE operation = ' + IntToStr(newId)));
end;

procedure TDBTest.TestPurchaseIncrementsStock;
var
  purchase: TPurchase;
  dataIn: TDataIn;
  before, after: Integer;
begin
  before := ScalarInt('SELECT units FROM balance WHERE product = 1');
  AssertEquals('seeded stock is 5', 5, before);

  purchase := BuildPurchase(3, 1000, 1500);   { buy 3 units }
  purchase.calculateNewBalance();

  dataIn := TDataIn.Create(FConn);
  try
    AssertTrue('save ok', dataIn.new(purchase) > 0);
  finally
    dataIn.Destroy;
  end;
  FTrans.Commit;
  FTrans.StartTransaction;

  after := ScalarInt('SELECT units FROM balance WHERE product = 1');
  AssertEquals('stock increased by purchased qty', before + 3, after);
end;

procedure TDBTest.TestMultiItemPurchase;
var
  dp: TDataProducto;
  sup: TSupplier;
  purchase: TPurchase;
  it1, it2: TItem;
  items: TList;
  dataIn: TDataIn;
  newId: Integer;
begin
  dp := TDataProducto.Create(FConn);
  sup := TSupplier.Create;
  sup.setId(1);
  purchase := TPurchase.Create;
  purchase.setSupplier(sup);
  purchase.setDate(Now);

  it1 := TItem.Create;
  it1.setProduct(dp.get(1));
  it1.setStock(2); it1.setCost(1000); it1.setPrice(1500);

  it2 := TItem.Create;
  it2.setProduct(dp.get(2));
  it2.setStock(4); it2.setCost(800); it2.setPrice(1200);
  dp.Destroy;

  items := TList.Create;
  items.Add(it1);
  items.Add(it2);
  purchase.setItemList(items);
  purchase.calculateNewBalance();

  dataIn := TDataIn.Create(FConn);
  try
    newId := dataIn.new(purchase);
  finally
    dataIn.Destroy;
  end;
  AssertTrue('multi-item save ok', newId > 0);
  FTrans.Commit;
  FTrans.StartTransaction;

  AssertEquals('two item rows persisted', 2,
    ScalarInt('SELECT COUNT(*) FROM item WHERE operation = ' + IntToStr(newId)));
end;

procedure TDBTest.TestRollbackLeavesNoRows;
var
  purchase: TPurchase;
  dataIn: TDataIn;
begin
  purchase := BuildPurchase(2, 1000, 1500);
  purchase.calculateNewBalance();

  dataIn := TDataIn.Create(FConn);
  try
    AssertTrue('save ok', dataIn.new(purchase) > 0);
  finally
    dataIn.Destroy;
  end;

  { Roll back instead of commit: nothing must remain. }
  FTrans.Rollback;
  FTrans.StartTransaction;

  AssertEquals('no operation rows after rollback', 0,
    ScalarInt('SELECT COUNT(*) FROM operation'));
  AssertEquals('no item rows after rollback', 0,
    ScalarInt('SELECT COUNT(*) FROM item'));
end;

procedure TDBTest.TestDataFreeKeepsSharedTransaction;
var
  d: TData;
begin
  { TData.free() historically freed the shared connection transaction, breaking
    every subsequent DB call. After calling the shadowed free(), the connection
    transaction must still exist and be usable. }
  d := TData.Create(FConn);
  d.free();   { shadowed lowercase free - must NOT kill FConn.Transaction }

  AssertTrue('connection still connected', FConn.Connected);
  AssertNotNull('connection still has a transaction', FConn.Transaction);
  { A query must still work through the shared transaction. }
  AssertEquals('can still query after TData.free()', 3,
    ScalarInt('SELECT COUNT(*) FROM product'));
end;

procedure TDBTest.TestNilOperationTypeFailsCleanly;
var
  dp: TDataProducto;
  sup: TSupplier;
  purchase: TPurchase;
  item: TItem;
  items: TList;
  dataIn: TDataIn;
  newId: Integer;
begin
  dp := TDataProducto.Create(FConn);
  sup := TSupplier.Create;
  sup.setId(1);

  purchase := TPurchase.Create;
  purchase.setOperationType(nil);   { force the invalid-header path }
  purchase.setSupplier(sup);
  purchase.setDate(Now);

  item := TItem.Create;
  item.setProduct(dp.get(1));
  dp.Destroy;
  item.setStock(1); item.setCost(1000); item.setPrice(1500);
  items := TList.Create;
  items.Add(item);
  purchase.setItemList(items);

  dataIn := TDataIn.Create(FConn);
  try
    newId := dataIn.new(purchase);
  finally
    dataIn.Destroy;
  end;

  AssertEquals('nil operation type returns 0 (no crash)', 0, newId);
  if FTrans.Active then FTrans.Rollback;
  FTrans.StartTransaction;
  AssertEquals('no operation row written for invalid header', 0,
    ScalarInt('SELECT COUNT(*) FROM operation'));
end;

procedure TDBTest.TestPurchaseCreatesMissingBalance;
var
  dp: TDataProducto;
  prod: TProduct;
  sup: TSupplier;
  item: TItem;
  items: TList;
  purchase: TPurchase;
  dataIn: TDataIn;
  newId, balCount, units: Integer;
begin
  { Product 3 has no balance row at all. }
  AssertEquals('product 3 starts with no balance row', 0,
    ScalarInt('SELECT COUNT(*) FROM balance WHERE product = 3'));

  dp := TDataProducto.Create(FConn);
  prod := dp.get(3);
  dp.Destroy;
  AssertNotNull('product 3 loaded', prod);
  AssertEquals('product 3 in-memory balance id is 0', 0, prod.getBalance().getId());

  sup := TSupplier.Create;
  sup.setId(1);
  purchase := TPurchase.Create;
  purchase.setSupplier(sup);
  purchase.setDate(Now);

  item := TItem.Create;
  item.setProduct(prod);
  item.setStock(4);
  item.setCost(6000);
  item.setPrice(13000);
  items := TList.Create;
  items.Add(item);
  purchase.setItemList(items);
  purchase.calculateNewBalance();

  dataIn := TDataIn.Create(FConn);
  try
    newId := dataIn.new(purchase);
  finally
    dataIn.Destroy;
  end;
  AssertTrue('purchase saved for product with no balance', newId > 0);
  FTrans.Commit;
  FTrans.StartTransaction;

  balCount := ScalarInt('SELECT COUNT(*) FROM balance WHERE product = 3');
  AssertEquals('a balance row was created for product 3', 1, balCount);

  units := ScalarInt('SELECT units FROM balance WHERE product = 3');
  AssertEquals('created balance holds the purchased units', 4, units);
end;

procedure TDBTest.TestDataBalanceInsertForMissingProduct;
var
  db: TDataBalance;
  prod: TProduct;
  bal: TBalance;
  newBalId: Integer;
begin
  { Product 3 has no balance row. Build the balance in memory (as the balance
    builder does from history) and INSERT via TDataBalance.new. }
  AssertEquals('product 3 has no balance row initially', 0,
    ScalarInt('SELECT COUNT(*) FROM balance WHERE product = 3'));

  prod := TProduct.Create;
  prod.setId(3);
  bal := prod.getBalance();
  bal.setId(0);            { no existing row }
  bal.setStock(4);
  bal.setBalance(24724.0);
  bal.setCost(6181.0);
  bal.setPrice(13000.0);

  db := TDataBalance.Create(FConn);
  try
    newBalId := db.new(prod);
  finally
    db.Destroy;
  end;

  AssertTrue('TDataBalance.new returned a positive id', newBalId > 0);
  FTrans.Commit;
  FTrans.StartTransaction;

  AssertEquals('exactly one balance row now exists for product 3', 1,
    ScalarInt('SELECT COUNT(*) FROM balance WHERE product = 3'));
  AssertEquals('inserted balance units correct', 4,
    ScalarInt('SELECT units FROM balance WHERE product = 3'));
end;

initialization
  Randomize;
  RegisterTest(TDBTest);

end.
