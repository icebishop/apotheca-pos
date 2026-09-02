{ Apothêca - Catalog Publication

  Repository for the publication table. Records which catalog products have been
  published, keyed by product.id, with the media id, publish date/time, and an
  instagram flag. Follows the TData repository pattern (see udataimage.pas).

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UDataPublication;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqlite3conn, SqlDb, UData;

type
  TPublicationRecord = record
    ProductId: Integer;   { FK to product.id }
    ItemName: String;
    MediaId: String;
    PublishedAt: String;  { ISO 8601 UTC }
    Instagram: Boolean;   { flag: published to Instagram }
  end;

  { TDataPublication }

  TDataPublication = class(TData)
  public
    constructor Create(Connection: TSQLite3Connection);
    destructor Destroy; override;
    function IsPublished(ProductId: Integer): Boolean;
    { Product ids (decimal strings) already published. Caller frees. }
    function LoadPublishedIds(): TStringList;
    { Upsert on product_id. Returns True on success. }
    function Record_(const Rec: TPublicationRecord): Boolean;
    function Get(ProductId: Integer): TPublicationRecord;

    { Maps a catalog id ("p42"/"s3") to product.id. Returns False when the id
      has no p/s prefix or a non-integer remainder. }
    class function TryParseCatalogId(const CatalogId: String;
      out ProductId: Integer): Boolean;
  end;

implementation

constructor TDataPublication.Create(Connection: TSQLite3Connection);
begin
  inherited Create(Connection);
end;

destructor TDataPublication.Destroy;
begin
  { Free the internal query created by TData.Create so it is not left as a
    dangling dataset on the shared connection. The transaction is owned by the
    caller (the shared connection), so it is not freed here. }
  if Self.getQuery() <> nil then
    Self.getQuery().Free;
  inherited Destroy;
end;

class function TDataPublication.TryParseCatalogId(const CatalogId: String;
  out ProductId: Integer): Boolean;
var
  Prefix: Char;
  Remainder: String;
begin
  ProductId := 0;
  Result := False;
  if CatalogId = '' then
    Exit;

  { Preferred: the catalog id is the raw product.id integer (e.g. "42"). }
  if TryStrToInt(CatalogId, ProductId) then
  begin
    Result := True;
    Exit;
  end;

  { Backward compatibility: accept a legacy 'p'/'s' prefix (e.g. "p42"/"s3"). }
  if Length(CatalogId) < 2 then
    Exit;
  Prefix := LowerCase(CatalogId)[1];
  if (Prefix <> 'p') and (Prefix <> 's') then
    Exit;
  Remainder := Copy(CatalogId, 2, Length(CatalogId) - 1);
  Result := TryStrToInt(Remainder, ProductId);
  if not Result then
    ProductId := 0;
end;

function TDataPublication.IsPublished(ProductId: Integer): Boolean;
var
  query: TSQLQuery;
begin
  Result := False;
  try
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.SQL.Text :=
        'SELECT 1 FROM publication WHERE product_id = :pid';
      query.Params.ParamByName('pid').AsInteger := ProductId;
      query.Open;
      Result := not query.EOF;
      query.Close;
    finally
      query.Free;
    end;
  except
    Result := False;
  end;
end;

function TDataPublication.LoadPublishedIds(): TStringList;
var
  query: TSQLQuery;
begin
  Result := TStringList.Create;
  query := TSQLQuery.Create(nil);
  try
    query.DataBase := Self.getConnection();
    query.SQL.Text := 'SELECT product_id FROM publication';
    query.Open;
    while not query.EOF do
    begin
      Result.Add(IntToStr(query.FieldByName('product_id').AsInteger));
      query.Next;
    end;
    query.Close;
  finally
    query.Free;
  end;
end;

function TDataPublication.Record_(const Rec: TPublicationRecord): Boolean;
begin
  try
    Self.getQuery().SQL.Text :=
      'INSERT INTO publication ' +
      '  (product_id, item_name, media_id, published_at, instagram) ' +
      'VALUES (:pid, :name, :media, :at, :ig) ' +
      'ON CONFLICT(product_id) DO UPDATE SET ' +
      '  item_name = excluded.item_name, ' +
      '  media_id = excluded.media_id, ' +
      '  published_at = excluded.published_at, ' +
      '  instagram = excluded.instagram';
    Self.getQuery().Params.ParamByName('pid').AsInteger := Rec.ProductId;
    Self.getQuery().Params.ParamByName('name').AsString := Rec.ItemName;
    Self.getQuery().Params.ParamByName('media').AsString := Rec.MediaId;
    Self.getQuery().Params.ParamByName('at').AsString := Rec.PublishedAt;
    Self.getQuery().Params.ParamByName('ig').AsInteger := Ord(Rec.Instagram);
    Self.getQuery().ExecSQL;
    if Self.getTransaction() <> nil then
      Self.getTransaction().Commit;
    Result := True;
  except
    Result := False;
  end;
end;

function TDataPublication.Get(ProductId: Integer): TPublicationRecord;
var
  query: TSQLQuery;
begin
  Result.ProductId := 0;
  Result.ItemName := '';
  Result.MediaId := '';
  Result.PublishedAt := '';
  Result.Instagram := False;
  try
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.SQL.Text :=
        'SELECT product_id, item_name, media_id, published_at, instagram ' +
        'FROM publication WHERE product_id = :pid';
      query.Params.ParamByName('pid').AsInteger := ProductId;
      query.Open;
      if not query.EOF then
      begin
        Result.ProductId := query.FieldByName('product_id').AsInteger;
        Result.ItemName := query.FieldByName('item_name').AsString;
        Result.MediaId := query.FieldByName('media_id').AsString;
        Result.PublishedAt := query.FieldByName('published_at').AsString;
        Result.Instagram := query.FieldByName('instagram').AsInteger <> 0;
      end;
      query.Close;
    finally
      query.Free;
    end;
  except
    ; { leave empty record }
  end;
end;

end.
