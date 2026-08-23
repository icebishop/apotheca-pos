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
  Dialogs, LazLogger, ULogger;

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
    procedure CreateImagesTable;
    procedure SeedReturnOperationTypes;
  public
    ImagesTableReady: Boolean;
    procedure EnsureTransaction;
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
      DebugLn('[DataModule] EnsureTransaction: Created new transaction');
    end
    else
      DebugLn('[DataModule] EnsureTransaction: Transaction already exists (Active=' +
        BoolToStr(SQLite3Connection1.Transaction.Active, 'True', 'False') + ')');
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
                      '  maxstock INTEGER);';
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

procedure TDataModule1.DataModuleCreate(Sender: TObject);
var
  DbPath: String;
  DbDir: String;
begin
  { Resolve database path: try relative to executable first, then CWD }
  DbPath := ExtractFilePath(ParamStr(0)) + 'db' + PathDelim + 'invcar';
  DebugLn('[DataModule] ParamStr(0) = ', ParamStr(0));
  DebugLn('[DataModule] ExtractFilePath = ', ExtractFilePath(ParamStr(0)));
  DebugLn('[DataModule] Initial DbPath = ', DbPath);
  DebugLn('[DataModule] FileExists(DbPath) = ', BoolToStr(FileExists(DbPath), 'True', 'False'));

  if not FileExists(DbPath) then
  begin
    DebugLn('[DataModule] DbPath not found, trying CWD fallback...');
    if FileExists('db' + PathDelim + 'invcar') then
    begin
      DbPath := ExpandFileName('db' + PathDelim + 'invcar');
      DebugLn('[DataModule] CWD fallback found: ', DbPath);
    end
    else
      DebugLn('[DataModule] CWD fallback also not found');
  end;

  DbDir := ExtractFilePath(DbPath);
  if not DirectoryExists(DbDir) then
  begin
    DebugLn('[DataModule] Creating directory: ', DbDir);
    ForceDirectories(DbDir);
  end;

  SQLite3Connection1.Connected := False;
  SQLite3Connection1.DatabaseName := DbPath;
  DebugLn('[DataModule] DatabaseName set to: ', SQLite3Connection1.DatabaseName);

  try
    SQLite3Connection1.Connected := True;
    DebugLn('[DataModule] Connected successfully!');
    LogInfo('DataModule', 'DB_CONNECTED', 'path=' + SQLite3Connection1.DatabaseName);
    InitDefaultDatabaseSchema;
    DebugLn('[DataModule] Schema initialized');
    MigrateCreditColumn;
    DebugLn('[DataModule] Credit column migration complete');
    MigratePayOperationColumn;
    DebugLn('[DataModule] Pay operation column migration complete');
    SeedReturnOperationTypes;
    DebugLn('[DataModule] Return operation types seeding complete');
    MigrateProductExportColumns;
    DebugLn('[DataModule] Product export columns migration complete');
    CreateImagesTable;
    DebugLn('[DataModule] Images table creation complete');
    LogInfo('DataModule', 'DB_MIGRATIONS_COMPLETE', 'All migrations applied');
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
