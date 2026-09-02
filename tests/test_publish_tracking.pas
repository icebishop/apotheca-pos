{ Feature: instagram-auto-publish
  Property 8: Publication record round-trip (upsert on product_id)

  Runs against a temporary in-file SQLite database created with the
  instagram_publication schema, then exercises TDataPublication
  insert / upsert / read.

  **Validates: Requirements 3.2, 3.4, 3.6**
}

unit test_publish_tracking;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, sqldb, fpcunit, testregistry,
  UDataPublication;

type
  TTestPublishTracking = class(TTestCase)
  private
    FDbPath: String;
    FConn: TSQLite3Connection;
    FTrans: TSQLTransaction;
    procedure SetUp; override;
    procedure TearDown; override;
    procedure CreateSchema;
  published
    procedure Test_Record_And_Get_RoundTrip;
    procedure Test_Upsert_NoDuplicate;
    procedure Test_LoadPublishedIds_And_IsPublished;
  end;

implementation

const
  ITERATIONS = 150;

procedure TTestPublishTracking.CreateSchema;
var
  Q: TSQLQuery;
begin
  Q := TSQLQuery.Create(nil);
  try
    Q.DataBase := FConn;
    Q.SQL.Text := 'CREATE TABLE IF NOT EXISTS publication (' +
      'id INTEGER PRIMARY KEY AUTOINCREMENT, ' +
      'product_id INTEGER NOT NULL UNIQUE, ' +
      'item_name TEXT NOT NULL, ' +
      'media_id TEXT NOT NULL, ' +
      'published_at TEXT NOT NULL, ' +
      'instagram INTEGER NOT NULL DEFAULT 1)';
    Q.ExecSQL;
    FConn.Transaction.Commit;
  finally
    Q.Free;
  end;
end;

procedure TTestPublishTracking.SetUp;
begin
  FDbPath := IncludeTrailingPathDelimiter(GetTempDir) +
    'iap_track_' + IntToStr(Random(1000000)) + '.sqlite';
  FConn := TSQLite3Connection.Create(nil);
  FTrans := TSQLTransaction.Create(nil);
  FConn.DatabaseName := FDbPath;
  FConn.Transaction := FTrans;
  FTrans.DataBase := FConn;
  FConn.Connected := True;
  if not FTrans.Active then
    FTrans.StartTransaction;
  CreateSchema;
end;

procedure TTestPublishTracking.TearDown;
begin
  if FConn.Connected then
    FConn.Connected := False;
  FConn.Free;   { free connection before transaction (it references it) }
  FTrans.Free;
  if FileExists(FDbPath) then
    DeleteFile(FDbPath);
end;

{ Property 8: write then read yields equal fields. }
procedure TTestPublishTracking.Test_Record_And_Get_RoundTrip;
var
  Data: TDataPublication;
  Rec, Got: TPublicationRecord;
  Iteration, N: Integer;
begin
  Data := TDataPublication.Create(FConn);
  try
    for Iteration := 1 to ITERATIONS do
    begin
      N := Iteration;  { unique product_id per iteration }
      Rec.ProductId := N;
      Rec.ItemName := 'Item ' + IntToStr(N);
      Rec.MediaId := '1789' + IntToStr(N);
      Rec.PublishedAt := Format('2026-09-01T12:%.2d:00Z', [N mod 60]);
      Rec.Instagram := (N mod 2) = 0;

      AssertTrue(Format('Iteration %d: Record_ ok', [Iteration]),
        Data.Record_(Rec));

      Got := Data.Get(N);
      AssertEquals('product_id', Rec.ProductId, Got.ProductId);
      AssertEquals('item_name', Rec.ItemName, Got.ItemName);
      AssertEquals('media_id', Rec.MediaId, Got.MediaId);
      AssertEquals('published_at', Rec.PublishedAt, Got.PublishedAt);
      AssertEquals('instagram flag', Rec.Instagram, Got.Instagram);
    end;
  finally
    Data.Destroy;  { avoid TData's shadowing free() that frees the shared txn }
  end;
end;

{ Property 8: upsert keeps a single row per product_id; re-record updates it. }
procedure TTestPublishTracking.Test_Upsert_NoDuplicate;
var
  Data: TDataPublication;
  Rec, Got: TPublicationRecord;
  Ids: TStringList;
begin
  Data := TDataPublication.Create(FConn);
  try
    Rec.ProductId := 42;
    Rec.ItemName := 'First';
    Rec.MediaId := 'media_A';
    Rec.PublishedAt := '2026-09-01T10:00:00Z';
    Rec.Instagram := True;
    AssertTrue('first insert', Data.Record_(Rec));

    { Re-record same product_id with new values. }
    Rec.ItemName := 'Second';
    Rec.MediaId := 'media_B';
    Rec.PublishedAt := '2026-09-02T10:00:00Z';
    AssertTrue('upsert', Data.Record_(Rec));

    Got := Data.Get(42);
    AssertEquals('name updated', 'Second', Got.ItemName);
    AssertEquals('media updated', 'media_B', Got.MediaId);
    AssertEquals('date updated', '2026-09-02T10:00:00Z', Got.PublishedAt);

    Ids := Data.LoadPublishedIds();
    try
      AssertEquals('exactly one row after upsert', 1, Ids.Count);
      AssertEquals('the one id is 42', '42', Ids[0]);
    finally
      Ids.Free;
    end;
  finally
    Data.Destroy;
  end;
end;

{ IsPublished + LoadPublishedIds reflect recorded rows. }
procedure TTestPublishTracking.Test_LoadPublishedIds_And_IsPublished;
var
  Data: TDataPublication;
  Rec: TPublicationRecord;
  Ids: TStringList;
  i: Integer;
begin
  Data := TDataPublication.Create(FConn);
  try
    for i := 1 to 5 do
    begin
      Rec.ProductId := i * 10;
      Rec.ItemName := 'N' + IntToStr(i);
      Rec.MediaId := 'm' + IntToStr(i);
      Rec.PublishedAt := '2026-09-01T00:00:00Z';
      Rec.Instagram := True;
      Data.Record_(Rec);
    end;

    AssertTrue('10 published', Data.IsPublished(10));
    AssertTrue('50 published', Data.IsPublished(50));
    AssertFalse('99 not published', Data.IsPublished(99));

    Ids := Data.LoadPublishedIds();
    try
      AssertEquals('5 ids', 5, Ids.Count);
      AssertTrue('contains 30', Ids.IndexOf('30') >= 0);
    finally
      Ids.Free;
    end;
  finally
    Data.Destroy;
  end;
end;

initialization
  Randomize;
  RegisterTest(TTestPublishTracking);

end.
