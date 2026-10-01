{ Apothêca - Instagram Auto-Publish

  Registry item model: a product or service loaded from the catalog JSON files
  produced by the JSON Export feature (products.json / services.json).

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit URegistryItem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TRegistryKind = (rkProduct, rkService);

  { TRegistryItem }

  TRegistryItem = class(TObject)
  private
    FId: String;
    FName: String;
    FCategory: String;
    FPrice: Integer;
    FHasOriginalPrice: Boolean;
    FOriginalPrice: Integer;
    FDescription: String;
    FImages: TStringList;
    FIsVisible: Boolean;
    FBrand: String;
    FKind: TRegistryKind;
    FImageRef: Integer;
    FImageRefs: array of Integer;
    function GetImageRefCount: Integer;
    function GetImageRefItem(Index: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    { Replace the full set of DB image ids (ordered). Also sets ImageRef to the
      first id for backward compatibility. }
    procedure SetImageRefs(const Refs: array of Integer);
    { Number of DB image ids carried by this item. }
    property ImageRefCount: Integer read GetImageRefCount;
    { DB image id at the given 0-based position. }
    property ImageRefItem[Index: Integer]: Integer read GetImageRefItem;

    property Id: String read FId write FId;
    property Name: String read FName write FName;
    property Category: String read FCategory write FCategory;
    property Price: Integer read FPrice write FPrice;
    property HasOriginalPrice: Boolean read FHasOriginalPrice write FHasOriginalPrice;
    property OriginalPrice: Integer read FOriginalPrice write FOriginalPrice;
    property Description: String read FDescription write FDescription;
    property Images: TStringList read FImages;
    property IsVisible: Boolean read FIsVisible write FIsVisible;
    property Brand: String read FBrand write FBrand;
    property Kind: TRegistryKind read FKind write FKind;
    { DB images.id reference (0 = none); set for database-sourced items. }
    property ImageRef: Integer read FImageRef write FImageRef;
  end;

implementation

constructor TRegistryItem.Create;
begin
  inherited Create;
  FId := '';
  FName := '';
  FCategory := '';
  FPrice := 0;
  FHasOriginalPrice := False;
  FOriginalPrice := 0;
  FDescription := '';
  FImages := TStringList.Create;
  FIsVisible := False;
  FBrand := '';
  FKind := rkProduct;
  FImageRef := 0;
  SetLength(FImageRefs, 0);
end;

function TRegistryItem.GetImageRefCount: Integer;
begin
  Result := Length(FImageRefs);
end;

function TRegistryItem.GetImageRefItem(Index: Integer): Integer;
begin
  if (Index >= 0) and (Index < Length(FImageRefs)) then
    Result := FImageRefs[Index]
  else
    Result := 0;
end;

procedure TRegistryItem.SetImageRefs(const Refs: array of Integer);
var
  i: Integer;
begin
  SetLength(FImageRefs, Length(Refs));
  for i := 0 to High(Refs) do
    FImageRefs[i] := Refs[i];
  if Length(FImageRefs) > 0 then
    FImageRef := FImageRefs[0];
end;

destructor TRegistryItem.Destroy;
begin
  FImages.Free;
  inherited Destroy;
end;

end.
