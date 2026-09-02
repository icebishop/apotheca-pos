{ Apothêca - Instagram Auto-Publish

  Publication tracker service. Wraps TDataPublication, translating catalog ids
  ("p42"/"s3") to product.id and DB failures into ETrackingError so the
  orchestrator can apply the "stop on tracking failure" rule.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UPublicationTracker;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, UDataPublication;

type
  ETrackingError = class(Exception);

  { TPublicationTracker }

  TPublicationTracker = class(TObject)
  private
    FData: TDataPublication;
  public
    constructor Create(AConnection: TSQLite3Connection);
    destructor Destroy; override;

    { Product ids (decimal strings) already published. Caller frees.
      Raises ETrackingError on DB error. }
    function LoadPublishedIds(): TStringList;

    { True when the catalog item is already published. An unmappable CatalogId
      is treated as not-published (detection skips it separately). }
    function IsPublished(const CatalogId: String): Boolean;

    { Records a publication right after a successful publish.
      Raises ETrackingError on unmappable id or DB write failure. }
    procedure RecordPublication(const CatalogId, ItemName, MediaId, PublishedAt: String);
  end;

implementation

constructor TPublicationTracker.Create(AConnection: TSQLite3Connection);
begin
  inherited Create;
  FData := TDataPublication.Create(AConnection);
end;

destructor TPublicationTracker.Destroy;
begin
  { Note: TData declares a shadowing lowercase free() that also frees the shared
    transaction. We must NOT call that here (the connection owns the
    transaction). Call the standard destructor directly so only TDataPublication's
    own Destroy runs (which frees just its internal query). }
  if FData <> nil then
    FData.Destroy;
  FData := nil;
  inherited Destroy;
end;

function TPublicationTracker.LoadPublishedIds(): TStringList;
begin
  try
    Result := FData.LoadPublishedIds();
  except
    on E: Exception do
      raise ETrackingError.Create(
        'Failed to read publication table: ' + E.Message);
  end;
end;

function TPublicationTracker.IsPublished(const CatalogId: String): Boolean;
var
  ProductId: Integer;
begin
  if not TDataPublication.TryParseCatalogId(CatalogId, ProductId) then
  begin
    Result := False;
    Exit;
  end;
  Result := FData.IsPublished(ProductId);
end;

procedure TPublicationTracker.RecordPublication(const CatalogId, ItemName,
  MediaId, PublishedAt: String);
var
  ProductId: Integer;
  Rec: TPublicationRecord;
begin
  if not TDataPublication.TryParseCatalogId(CatalogId, ProductId) then
    raise ETrackingError.Create(
      'Cannot map catalog id to product.id: ' + CatalogId);

  Rec.ProductId := ProductId;
  Rec.ItemName := ItemName;
  Rec.MediaId := MediaId;
  Rec.PublishedAt := PublishedAt;
  Rec.Instagram := True;  { this pipeline publishes to Instagram }

  if not FData.Record_(Rec) then
    raise ETrackingError.Create(
      'Failed to persist publication for catalog id ' + CatalogId);
end;

end.
