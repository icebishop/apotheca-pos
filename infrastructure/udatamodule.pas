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

unit UDataModule;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, FileUtil, LResources, Forms, Controls,
  Dialogs, LazLogger, ULogger, USettingsService;

type

  { TDataModule1 }

  TDataModule1 = class(TDataModule)
    SQLite3Connection1: TSQLite3Connection;
    procedure DataModuleCreate(Sender: TObject);
    procedure SQLite3Connection1AfterConnect(Sender: TObject);
  private
    procedure InitDefaultDatabaseSchema;
    procedure MigrateCreditColumn;
    procedure MigratePayOperationColumn;
    procedure MigrateProductExportColumns;
    procedure MigrateProductIdColumn;
    procedure CreateImagesTable;
    procedure CreatePublicationTable;
    procedure CreateParametersTable;
    procedure CreateGoogleCategoryTable;
    procedure SeedParameters(const DbPath: String);
    procedure SeedReturnOperationTypes;
    function ResolveDefaultDbPath: String;
    { Connects to DbPath and runs all schema init / migrations / seeding.
      Returns True on success. }
    function OpenDatabase(const DbPath: String): Boolean;
  public
    ImagesTableReady: Boolean;
    procedure EnsureTransaction;
    { Reconnects the data module to a different database file (e.g. after the
      db.file parameter changes in Settings), running migrations on the new file.
      Returns True on success; on failure the connection is left closed and the
      previous path is reported in ErrorMsg. }
    function ReopenDatabase(const NewDbPath: String; out ErrorMsg: String): Boolean;
    { The database file the module is currently connected to. }
    function CurrentDbPath: String;
  end; 

var
  DataModule1: TDataModule1; 

implementation

{ TDataModule1 }

procedure TDataModule1.EnsureTransaction;
var
  Trans: TSQLTransaction;
begin
  try
    if SQLite3Connection1.Transaction = nil then
    begin
      Trans := TSQLTransaction.Create(nil);
      Trans.DataBase := SQLite3Connection1;
      SQLite3Connection1.Transaction := Trans;
    end;
    { Always ensure the transaction is active for reads/writes }
    if not SQLite3Connection1.Transaction.Active then
      SQLite3Connection1.Transaction.StartTransaction;
  except
    on E: Exception do
      DebugLn('[DataModule] EnsureTransaction ERROR: ' + E.Message);
  end;
end;

procedure TDataModule1.SQLite3Connection1AfterConnect(Sender: TObject);
begin

end;

procedure TDataModule1.InitDefaultDatabaseSchema;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
begin
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := SQLite3Connection1;
    Query.DataBase := SQLite3Connection1;
    Query.Transaction := Trans;

    Trans.StartTransaction;

    // Create person table
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS person (' +
                      '  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
                      '  name TEXT NOT NULL,' +
                      '  telephone TEXT,' +
                      '  address TEXT);';
    Query.ExecSQL;

    // Create customer table
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS customer (' +
                      '  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
                      '  person INTEGER,' +
                      '  FOREIGN KEY(person) REFERENCES person(id));';
    Query.ExecSQL;

    // Create supplier table
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS supplier (' +
                      '  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
                      '  person INTEGER,' +
                      '  FOREIGN KEY(person) REFERENCES person(id));';
    Query.ExecSQL;

    // Create product table
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS product (' +
                      '  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
                      '  name TEXT NOT NULL,' +
                      '  minstock INTEGER,' +
                      '  maxstock INTEGER,' +
                      '  image_ref INTEGER DEFAULT 0,' +
                      '  originalprice REAL DEFAULT 0.0,' +
                      '  isservice INTEGER DEFAULT 0,' +
                      '  category TEXT DEFAULT '''',' +
                      '  description TEXT DEFAULT '''',' +
                      '  brand TEXT DEFAULT '''',' +
                      '  condition TEXT DEFAULT '''',' +
                      '  google_product_category TEXT DEFAULT '''');';
    Query.ExecSQL;

    // Create balance table
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS balance (' +
                      '  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
                      '  product INTEGER NOT NULL,' +
                      '  units INTEGER NOT NULL,' +
                      '  balance REAL NOT NULL,' +
                      '  cost REAL NOT NULL,' +
                      '  price REAL NOT NULL,' +
                      '  FOREIGN KEY(product) REFERENCES product(id));';
    Query.ExecSQL;

    // Create operationtype table
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS operationtype (' +
                      '  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
                      '  description TEXT,' +
                      '  type TEXT);';
    Query.ExecSQL;

    // Create operation table
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS operation (' +
                      '  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
                      '  type INTEGER NOT NULL,' +
                      '  date REAL,' +
                      '  person INTEGER,' +
                      '  FOREIGN KEY(person) REFERENCES person(id),' +
                      '  FOREIGN KEY(type) REFERENCES operationtype(id));';
    Query.ExecSQL;

    // Create item table
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS item (' +
                      '  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
                      '  product INTEGER NOT NULL,' +
                      '  operation INTEGER NOT NULL,' +
                      '  cost REAL NOT NULL,' +
                      '  stock INTEGER NOT NULL,' +
                      '  price REAL NOT NULL,' +
                      '  FOREIGN KEY(product) REFERENCES product(id),' +
                      '  FOREIGN KEY(operation) REFERENCES operation(id));';
    Query.ExecSQL;

    // Create pay table
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS pay (' +
                      '  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,' +
                      '  person INTEGER NOT NULL,' +
                      '  val REAL NOT NULL,' +
                      '  date DATE,' +
                      '  FOREIGN KEY(person) REFERENCES person(id));';
    Query.ExecSQL;

    // Create indices
    Query.SQL.Text := 'CREATE INDEX IF NOT EXISTS idxperson ON customer (person ASC);';
    Query.ExecSQL;
    Query.SQL.Text := 'CREATE INDEX IF NOT EXISTS idxoperation ON operation (id ASC);';
    Query.ExecSQL;
    Query.SQL.Text := 'CREATE INDEX IF NOT EXISTS idxitem ON item (product ASC);';
    Query.ExecSQL;

    // Seed default operation types if missing
    Query.SQL.Text := 'SELECT COUNT(*) AS cnt FROM operationtype';
    Query.Open;
    if Query.FieldByName('cnt').AsInteger = 0 then
    begin
      Query.Close;
      Query.SQL.Text := 'INSERT INTO operationtype (id, description, type) VALUES (1, "Purchase", "in");';
      Query.ExecSQL;
      Query.SQL.Text := 'INSERT INTO operationtype (id, description, type) VALUES (2, "Sale", "out");';
      Query.ExecSQL;
      Query.SQL.Text := 'INSERT INTO operationtype (id, description, type) VALUES (3, "Adjustment IN", "in");';
      Query.ExecSQL;
      Query.SQL.Text := 'INSERT INTO operationtype (id, description, type) VALUES (4, "Adjustment OUT", "out");';
      Query.ExecSQL;
    end
    else
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
end;

procedure TDataModule1.MigrateCreditColumn;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  HasColumn: Boolean;
begin
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := SQLite3Connection1;
    Query.DataBase := SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    HasColumn := False;
    Query.SQL.Text := 'PRAGMA table_info(operation)';
    Query.Open;
    while not Query.EOF do
    begin
      if Query.FieldByName('name').AsString = 'credit' then
      begin
        HasColumn := True;
        Break;
      end;
      Query.Next;
    end;
    Query.Close;

    if not HasColumn then
    begin
      Query.SQL.Text := 'ALTER TABLE operation ADD COLUMN credit INTEGER DEFAULT 0';
      Query.ExecSQL;
    end;

    Trans.Commit;
  except
    if Trans.Active then Trans.Rollback;
  end;
  Query.Free;
  Trans.Free;
end;

procedure TDataModule1.MigratePayOperationColumn;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  HasColumn: Boolean;
begin
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := SQLite3Connection1;
    Query.DataBase := SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    HasColumn := False;
    Query.SQL.Text := 'PRAGMA table_info(pay)';
    Query.Open;
    while not Query.EOF do
    begin
      if Query.FieldByName('name').AsString = 'operation' then
      begin
        HasColumn := True;
        Break;
      end;
      Query.Next;
    end;
    Query.Close;

    if not HasColumn then
    begin
      Query.SQL.Text := 'ALTER TABLE pay ADD COLUMN operation INTEGER DEFAULT 0';
      Query.ExecSQL;
    end;

    Trans.Commit;
  except
    if Trans.Active then Trans.Rollback;
  end;
  Query.Free;
  Trans.Free;
end;

procedure TDataModule1.SeedReturnOperationTypes;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
begin
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := SQLite3Connection1;
    Query.DataBase := SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    // Insert "Customer Devolution" if not already present
    Query.SQL.Text := 'INSERT OR IGNORE INTO operationtype (description, type) ' +
                      'SELECT ''Customer Devolution'', ''in'' ' +
                      'WHERE NOT EXISTS (SELECT 1 FROM operationtype WHERE description = ''Customer Devolution'')';
    Query.ExecSQL;

    // Insert "Inventory Loss" if not already present
    Query.SQL.Text := 'INSERT OR IGNORE INTO operationtype (description, type) ' +
                      'SELECT ''Inventory Loss'', ''out'' ' +
                      'WHERE NOT EXISTS (SELECT 1 FROM operationtype WHERE description = ''Inventory Loss'')';
    Query.ExecSQL;

    // Insert "Return to Provider" if not already present
    Query.SQL.Text := 'INSERT OR IGNORE INTO operationtype (description, type) ' +
                      'SELECT ''Return to Provider'', ''out'' ' +
                      'WHERE NOT EXISTS (SELECT 1 FROM operationtype WHERE description = ''Return to Provider'')';
    Query.ExecSQL;

    Trans.Commit;
    DebugLn('[DataModule] Return operation types seeded');
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      DebugLn('[DataModule] ERROR seeding return operation types: ', E.Message);
    end;
  end;
  Query.Free;
  Trans.Free;
end;

procedure TDataModule1.MigrateProductExportColumns;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  HasImageRef, HasOriginalPrice, HasIsService: Boolean;
begin
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := SQLite3Connection1;
    Query.DataBase := SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    { Check which columns already exist }
    HasImageRef := False;
    HasOriginalPrice := False;
    HasIsService := False;
    Query.SQL.Text := 'PRAGMA table_info(product)';
    Query.Open;
    while not Query.EOF do
    begin
      if Query.FieldByName('name').AsString = 'image_ref' then
        HasImageRef := True
      else if Query.FieldByName('name').AsString = 'originalprice' then
        HasOriginalPrice := True
      else if Query.FieldByName('name').AsString = 'isservice' then
        HasIsService := True;
      Query.Next;
    end;
    Query.Close;

    { Add missing columns individually }
    if not HasImageRef then
    begin
      try
        Query.SQL.Text := 'ALTER TABLE product ADD COLUMN image_ref INTEGER DEFAULT 0';
        Query.ExecSQL;
      except
        on E: Exception do
          LogError('DataModule', 'MIGRATE_IMAGE_REF_FAILED', 'error=' + E.Message);
      end;
    end;

    if not HasOriginalPrice then
    begin
      try
        Query.SQL.Text := 'ALTER TABLE product ADD COLUMN originalprice REAL DEFAULT 0.0';
        Query.ExecSQL;
      except
        on E: Exception do
          LogError('DataModule', 'MIGRATE_ORIGINALPRICE_FAILED', 'error=' + E.Message);
      end;
    end;

    if not HasIsService then
    begin
      try
        Query.SQL.Text := 'ALTER TABLE product ADD COLUMN isservice INTEGER DEFAULT 0';
        Query.ExecSQL;
      except
        on E: Exception do
          LogError('DataModule', 'MIGRATE_ISSERVICE_FAILED', 'error=' + E.Message);
      end;
    end;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      LogError('DataModule', 'MIGRATE_EXPORT_COLUMNS_FAILED', 'error=' + E.Message);
    end;
  end;
  Query.Free;
  Trans.Free;
end;

procedure TDataModule1.MigrateProductIdColumn;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  IdIsRowidAlias: Boolean;
begin
  { The product.id must be an INTEGER PRIMARY KEY (a rowid alias) so inserts
    auto-assign the id. Some databases ended up with 'id INT' (no autoincrement),
    which makes new products get a NULL id and corrupts subsequent operations.
    Detect that and rebuild the table preserving all data and ids. }
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := SQLite3Connection1;
    Query.DataBase := SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    { PRAGMA table_info reports pk=1 AND type='INTEGER' for a rowid alias. }
    IdIsRowidAlias := False;
    Query.SQL.Text := 'PRAGMA table_info(product)';
    Query.Open;
    while not Query.EOF do
    begin
      if Query.FieldByName('name').AsString = 'id' then
      begin
        IdIsRowidAlias :=
          (Query.FieldByName('pk').AsInteger = 1) and
          (UpperCase(Trim(Query.FieldByName('type').AsString)) = 'INTEGER');
        Break;
      end;
      Query.Next;
    end;
    Query.Close;

    if IdIsRowidAlias then
    begin
      Trans.Commit;
      Exit; { already correct }
    end;

    LogWarn('DataModule', 'MIGRATE_PRODUCT_ID_START',
      'product.id is not a rowid alias; rebuilding table to fix autoincrement');

    { Rebuild: create a corrected table, copy data, swap. Column set matches
      InitDefaultDatabaseSchema (plus the export columns). }
    Query.SQL.Text := 'CREATE TABLE product_new (' +
      'id INTEGER PRIMARY KEY, ' +
      'name TEXT NOT NULL, ' +
      'minstock INTEGER, ' +
      'maxstock INTEGER, ' +
      'image_ref INTEGER DEFAULT 0, ' +
      'originalprice REAL DEFAULT 0.0, ' +
      'isservice INTEGER DEFAULT 0, ' +
      'category TEXT DEFAULT '''', ' +
      'description TEXT DEFAULT '''', ' +
      'brand TEXT DEFAULT '''', ' +
      'condition TEXT DEFAULT '''', ' +
      'google_product_category TEXT DEFAULT '''')';
    Query.ExecSQL;

    Query.SQL.Text := 'INSERT INTO product_new ' +
      '(id, name, minstock, maxstock, image_ref, originalprice, isservice, ' +
      ' category, description, brand, condition, google_product_category) ' +
      'SELECT ' +
      ' COALESCE(id, rowid), name, minstock, maxstock, ' +
      ' COALESCE(image_ref,0), COALESCE(originalprice,0.0), COALESCE(isservice,0), ' +
      ' COALESCE(category,''''), COALESCE(description,''''), COALESCE(brand,''''), ' +
      ' COALESCE(condition,''''), COALESCE(google_product_category,'''') ' +
      'FROM product';
    Query.ExecSQL;

    Query.SQL.Text := 'DROP TABLE product';
    Query.ExecSQL;
    Query.SQL.Text := 'ALTER TABLE product_new RENAME TO product';
    Query.ExecSQL;

    Trans.Commit;
    LogSecurity('DataModule', 'MIGRATE_PRODUCT_ID_DONE',
      'product table rebuilt with INTEGER PRIMARY KEY');
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      LogError('DataModule', 'MIGRATE_PRODUCT_ID_FAILED', 'error=' + E.Message);
    end;
  end;
  Query.Free;
  Trans.Free;
end;

procedure TDataModule1.CreateImagesTable;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
begin
  ImagesTableReady := False;
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := SQLite3Connection1;
    Query.DataBase := SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS images (' +
                      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
                      'product_id INTEGER NOT NULL, ' +
                      'data BLOB NOT NULL)';
    Query.ExecSQL;

    Query.SQL.Text := 'CREATE INDEX IF NOT EXISTS idx_images_product ON images(product_id)';
    Query.ExecSQL;

    Trans.Commit;
    ImagesTableReady := True;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      LogError('DataModule', 'CREATE_IMAGES_TABLE_FAILED', 'error=' + E.Message);
    end;
  end;
  Query.Free;
  Trans.Free;
end;

procedure TDataModule1.CreatePublicationTable;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  HasLegacy, HasPublication, HasInstagramCol: Boolean;
begin
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := SQLite3Connection1;
    Query.DataBase := SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    { Detect existing tables. }
    HasLegacy := False;
    HasPublication := False;
    Query.SQL.Text := 'SELECT name FROM sqlite_master WHERE type=''table'' ' +
                      'AND name IN (''instagram_publication'', ''publication'')';
    Query.Open;
    while not Query.EOF do
    begin
      if Query.FieldByName('name').AsString = 'instagram_publication' then
        HasLegacy := True
      else if Query.FieldByName('name').AsString = 'publication' then
        HasPublication := True;
      Query.Next;
    end;
    Query.Close;

    { Rename the legacy instagram_publication table to publication. }
    if HasLegacy and (not HasPublication) then
    begin
      Query.SQL.Text := 'ALTER TABLE instagram_publication RENAME TO publication';
      Query.ExecSQL;
      HasPublication := True;
    end;

    { Publication: one row per published catalog product.
      product_id is a FK to product.id; published_at is ISO 8601 UTC text;
      instagram is a flag (1 = published to Instagram). }
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS publication (' +
                      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
                      'product_id INTEGER NOT NULL UNIQUE, ' +
                      'item_name TEXT NOT NULL, ' +
                      'media_id TEXT NOT NULL, ' +
                      'published_at TEXT NOT NULL, ' +
                      'instagram INTEGER NOT NULL DEFAULT 1, ' +
                      'FOREIGN KEY(product_id) REFERENCES product(id))';
    Query.ExecSQL;

    { Add the instagram flag column if migrating an older publication table. }
    HasInstagramCol := False;
    Query.SQL.Text := 'PRAGMA table_info(publication)';
    Query.Open;
    while not Query.EOF do
    begin
      if Query.FieldByName('name').AsString = 'instagram' then
        HasInstagramCol := True;
      Query.Next;
    end;
    Query.Close;
    if not HasInstagramCol then
    begin
      Query.SQL.Text := 'ALTER TABLE publication ADD COLUMN instagram INTEGER NOT NULL DEFAULT 1';
      Query.ExecSQL;
    end;

    { Refresh the index name for the renamed table. }
    Query.SQL.Text := 'DROP INDEX IF EXISTS idx_pub_product';
    Query.ExecSQL;
    Query.SQL.Text := 'CREATE INDEX IF NOT EXISTS idx_publication_product ' +
                      'ON publication(product_id)';
    Query.ExecSQL;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      LogError('DataModule', 'CREATE_PUBLICATION_TABLE_FAILED', 'error=' + E.Message);
    end;
  end;
  Query.Free;
  Trans.Free;
end;

procedure TDataModule1.CreateParametersTable;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;
begin
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := SQLite3Connection1;
    Query.DataBase := SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    { Application parameters: key/value settings. is_credential flags rows whose
      value is stored encrypted and must be masked in the UI. }
    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS parameters (' +
                      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
                      'key TEXT NOT NULL UNIQUE, ' +
                      'value TEXT DEFAULT '''', ' +
                      'is_credential INTEGER NOT NULL DEFAULT 0, ' +
                      'description TEXT DEFAULT '''')';
    Query.ExecSQL;

    Query.SQL.Text := 'CREATE INDEX IF NOT EXISTS idx_parameters_key ' +
                      'ON parameters(key)';
    Query.ExecSQL;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      LogError('DataModule', 'CREATE_PARAMETERS_TABLE_FAILED', 'error=' + E.Message);
    end;
  end;
  Query.Free;
  Trans.Free;
end;

procedure TDataModule1.CreateGoogleCategoryTable;
var
  Trans: TSQLTransaction;
  Query: TSQLQuery;

  procedure SeedCat(const Cat: String);
  begin
    Query.SQL.Text := 'INSERT OR IGNORE INTO google_category (category) VALUES (:c)';
    Query.Params.ParamByName('c').AsString := Cat;
    Query.ExecSQL;
  end;

begin
  Trans := TSQLTransaction.Create(nil);
  Query := TSQLQuery.Create(nil);
  try
    Trans.DataBase := SQLite3Connection1;
    Query.DataBase := SQLite3Connection1;
    Query.Transaction := Trans;
    Trans.StartTransaction;

    Query.SQL.Text := 'CREATE TABLE IF NOT EXISTS google_category (' +
                      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
                      'category TEXT NOT NULL UNIQUE)';
    Query.ExecSQL;

    { Seed the billiard-relevant Google product categories (only if absent). }
    SeedCat('Sporting Goods > Billiards');
    SeedCat('Sporting Goods > Billiards > Billiard Chalk');
    SeedCat('Sporting Goods > Billiards > Billiard Cue Accessories');
    SeedCat('Sporting Goods > Billiards > Billiard Cue Accessories > Billiard Cue Tips');
    SeedCat('Sporting Goods > Billiards > Billiard Cue Cases');
    SeedCat('Sporting Goods > Billiards > Billiard Cues');
    SeedCat('Sporting Goods > Billiards > Billiard Gloves');
    SeedCat('Sporting Goods > Billiards > Billiard Tables');

    { Also import any categories already present on products so the list stays
      complete even if a product used a value not in the seed set. }
    Query.SQL.Text := 'INSERT OR IGNORE INTO google_category (category) ' +
      'SELECT DISTINCT google_product_category FROM product ' +
      'WHERE COALESCE(google_product_category,'''') <> ''''';
    Query.ExecSQL;

    Trans.Commit;
  except
    on E: Exception do
    begin
      if Trans.Active then Trans.Rollback;
      LogError('DataModule', 'CREATE_GOOGLE_CATEGORY_TABLE_FAILED', 'error=' + E.Message);
    end;
  end;
  Query.Free;
  Trans.Free;
end;

procedure TDataModule1.SeedParameters(const DbPath: String);
var
  Svc: TSettingsService;
  AppDir, ResBase: String;
begin
  try
    EnsureTransaction;
    AppDir := ExtractFilePath(ParamStr(0));
    ResBase := AppDir + '..' + PathDelim + 'don-pilido-app' + PathDelim +
               'src' + PathDelim + 'res' + PathDelim;
    Svc := TSettingsService.Create(SQLite3Connection1);
    try
      Svc.SeedDefaults(
        DbPath,
        ResBase + 'products.json',
        ResBase + 'services.json',
        AppDir + '..' + PathDelim + 'don-pilido-app' + PathDelim + 'public');
    finally
      Svc.Free;
    end;
  except
    on E: Exception do
      LogError('DataModule', 'SEED_PARAMETERS_FAILED', 'error=' + E.Message);
  end;
end;

function TDataModule1.ResolveDefaultDbPath: String;
begin
  { Try relative to executable first, then CWD. }
  Result := ExtractFilePath(ParamStr(0)) + 'db' + PathDelim + 'invcar';
  if not FileExists(Result) then
  begin
    if FileExists('db' + PathDelim + 'invcar') then
      Result := ExpandFileName('db' + PathDelim + 'invcar');
  end;
end;

function TDataModule1.OpenDatabase(const DbPath: String): Boolean;
var
  DbDir: String;
begin
  Result := False;

  DbDir := ExtractFilePath(DbPath);
  if (DbDir <> '') and (not DirectoryExists(DbDir)) then
  begin
    DebugLn('[DataModule] Creating directory: ', DbDir);
    ForceDirectories(DbDir);
  end;

  SQLite3Connection1.Connected := False;
  SQLite3Connection1.DatabaseName := DbPath;
  DebugLn('[DataModule] DatabaseName set to: ', SQLite3Connection1.DatabaseName);

  SQLite3Connection1.Connected := True;
  DebugLn('[DataModule] Connected successfully!');
  LogInfo('DataModule', 'DB_CONNECTED', 'path=' + SQLite3Connection1.DatabaseName);

  InitDefaultDatabaseSchema;
  MigrateCreditColumn;
  MigratePayOperationColumn;
  SeedReturnOperationTypes;
  MigrateProductExportColumns;
  MigrateProductIdColumn;
  CreateImagesTable;
  CreatePublicationTable;
  CreateParametersTable;
  CreateGoogleCategoryTable;
  SeedParameters(DbPath);
  LogInfo('DataModule', 'DB_MIGRATIONS_COMPLETE', 'All migrations applied path=' + DbPath);
  Result := True;
end;

function TDataModule1.CurrentDbPath: String;
begin
  Result := SQLite3Connection1.DatabaseName;
end;

function TDataModule1.ReopenDatabase(const NewDbPath: String;
  out ErrorMsg: String): Boolean;
var
  PrevPath: String;
begin
  Result := False;
  ErrorMsg := '';
  PrevPath := SQLite3Connection1.DatabaseName;

  if Trim(NewDbPath) = '' then
  begin
    ErrorMsg := 'Empty database path';
    Exit;
  end;
  if SameFileName(ExpandFileName(NewDbPath), ExpandFileName(PrevPath)) then
  begin
    { Same file: nothing to do. }
    Result := True;
    Exit;
  end;
  if not FileExists(NewDbPath) then
  begin
    { Only reopen onto an existing database file; do not silently create a new,
      empty one from a mistyped path. }
    ErrorMsg := 'Database file does not exist: ' + NewDbPath;
    Exit;
  end;

  try
    { Detach any active transaction before switching files. }
    if (SQLite3Connection1.Transaction <> nil) and
       SQLite3Connection1.Transaction.Active then
      SQLite3Connection1.Transaction.Commit;
  except
    on E: Exception do
      DebugLn('[DataModule] ReopenDatabase commit warning: ' + E.Message);
  end;

  try
    if OpenDatabase(NewDbPath) then
    begin
      LogSecurity('DataModule', 'DB_REOPENED',
        'from=' + PrevPath + ' to=' + NewDbPath);
      Result := True;
    end;
  except
    on E: Exception do
    begin
      ErrorMsg := E.Message;
      LogError('DataModule', 'DB_REOPEN_FAILED',
        'to=' + NewDbPath + ' error=' + E.Message);
      { Attempt to fall back to the previous database so the app stays usable. }
      try
        if PrevPath <> '' then
          OpenDatabase(PrevPath);
      except
        on E2: Exception do
          DebugLn('[DataModule] Fallback reopen failed: ' + E2.Message);
      end;
    end;
  end;
end;

procedure TDataModule1.DataModuleCreate(Sender: TObject);
var
  DbPath, ConfiguredPath: String;
  Svc: TSettingsService;
begin
  DbPath := ResolveDefaultDbPath;
  DebugLn('[DataModule] Initial DbPath = ', DbPath);

  try
    if not OpenDatabase(DbPath) then
      Exit;

    { The db.file parameter can redirect to another database file. It lives in
      the parameters table of the just-opened DB; if it points to a different,
      existing file, switch to it (and run migrations there). }
    ConfiguredPath := '';
    try
      EnsureTransaction;
      Svc := TSettingsService.Create(SQLite3Connection1);
      try
        ConfiguredPath := Svc.GetValue(PARAM_DB_FILE, '');
      finally
        Svc.Free;
      end;
    except
      on E: Exception do
      begin
        ConfiguredPath := '';
        DebugLn('[DataModule] read db.file param failed: ' + E.Message);
      end;
    end;

    if (ConfiguredPath <> '') and FileExists(ConfiguredPath) and
       (not SameFileName(ExpandFileName(ConfiguredPath), ExpandFileName(DbPath))) then
    begin
      DebugLn('[DataModule] db.file parameter redirects to: ', ConfiguredPath);
      OpenDatabase(ConfiguredPath);
    end;
  except
    on E: Exception do
    begin
      DebugLn('[DataModule] ERROR connecting: ', E.Message);
      LogError('DataModule', 'DB_CONNECTION_FAILED', 'path=' + DbPath + ' error=' + E.Message);
      ShowMessage('Database connection failed: ' + DbPath + #13#10 + E.Message);
    end;
  end;
end;

initialization
  {$I udatamodule.lrs}

end.
