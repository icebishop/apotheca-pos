{ Apothêca - Instagram Auto-Publish

  Product/Service registry loader. Parses the catalog JSON files produced by the
  JSON Export feature into TRegistryItem lists using fpjson.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UProductRegistry;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpjson, jsonparser, contnrs, URegistryItem;

type
  ERegistryError = class(Exception);

  { TProductRegistry }

  TProductRegistry = class(TObject)
  private
    class function LoadArray(const Path: String): TJSONArray;
    class function AsInt(Obj: TJSONObject; const Key: String; Default: Integer): Integer;
    class function AsStr(Obj: TJSONObject; const Key: String; const Default: String): String;
    class function AsBool(Obj: TJSONObject; const Key: String; Default: Boolean): Boolean;
    class procedure RequireFields(Obj: TJSONObject; const EntryDesc: String);
  public
    { Returns an owned TFPObjectList of TRegistryItem (caller frees).
      Raises ERegistryError on missing file, malformed JSON, non-array root,
      or an entry missing a required field. }
    class function LoadProducts(const Path: String): TFPObjectList;
    class function LoadServices(const Path: String): TFPObjectList;
  end;

implementation

class function TProductRegistry.LoadArray(const Path: String): TJSONArray;
var
  Stream: TFileStream;
  Data: TJSONData;
begin
  if not FileExists(Path) then
    raise ERegistryError.Create('Registry file not found: ' + Path);

  Stream := TFileStream.Create(Path, fmOpenRead or fmShareDenyWrite);
  try
    try
      Data := GetJSON(Stream);
    except
      on E: Exception do
        raise ERegistryError.Create(
          'Registry file contains malformed JSON: ' + Path + ' - ' + E.Message);
    end;
  finally
    Stream.Free;
  end;

  if not (Data is TJSONArray) then
  begin
    Data.Free;
    raise ERegistryError.Create(
      'Registry file has invalid format (expected a JSON array): ' + Path);
  end;

  Result := TJSONArray(Data);
end;

class function TProductRegistry.AsInt(Obj: TJSONObject; const Key: String;
  Default: Integer): Integer;
var
  D: TJSONData;
begin
  D := Obj.Find(Key);
  if (D = nil) or (D.JSONType = jtNull) then
    Result := Default
  else
    Result := D.AsInteger;
end;

class function TProductRegistry.AsStr(Obj: TJSONObject; const Key: String;
  const Default: String): String;
var
  D: TJSONData;
begin
  D := Obj.Find(Key);
  if (D = nil) or (D.JSONType = jtNull) then
    Result := Default
  else
    Result := D.AsString;
end;

class function TProductRegistry.AsBool(Obj: TJSONObject; const Key: String;
  Default: Boolean): Boolean;
var
  D: TJSONData;
begin
  D := Obj.Find(Key);
  if (D = nil) or (D.JSONType = jtNull) then
    Result := Default
  else
    Result := D.AsBoolean;
end;

class procedure TProductRegistry.RequireFields(Obj: TJSONObject;
  const EntryDesc: String);
  procedure Need(const Key: String);
  var
    D: TJSONData;
  begin
    D := Obj.Find(Key);
    if (D = nil) or (D.JSONType = jtNull) then
      raise ERegistryError.Create(
        'Invalid registry entry (missing field "' + Key + '"): ' + EntryDesc);
  end;
begin
  Need('id');
  Need('name');
  Need('price');
  Need('description');
end;

class function TProductRegistry.LoadProducts(const Path: String): TFPObjectList;
var
  Arr: TJSONArray;
  i, j: Integer;
  Obj: TJSONObject;
  Item: TRegistryItem;
  ImagesData: TJSONData;
  ImagesArr: TJSONArray;
  OrigData: TJSONData;
  EntryId: String;
begin
  Result := TFPObjectList.Create(True); { owns items }
  Arr := LoadArray(Path);
  try
    for i := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[i] is TJSONObject) then
        raise ERegistryError.Create(
          'Invalid registry entry (expected object) at index ' + IntToStr(i) +
          ' in ' + Path);
      Obj := TJSONObject(Arr.Items[i]);
      EntryId := AsStr(Obj, 'id', 'index ' + IntToStr(i));
      RequireFields(Obj, EntryId);

      Item := TRegistryItem.Create;
      Item.Kind := rkProduct;
      Item.Id := AsStr(Obj, 'id', '');
      Item.Name := AsStr(Obj, 'name', '');
      Item.Category := AsStr(Obj, 'category', '');
      Item.Price := AsInt(Obj, 'price', 0);
      Item.Description := AsStr(Obj, 'description', '');
      Item.Brand := AsStr(Obj, 'brand', '');
      Item.IsVisible := AsBool(Obj, 'isVisible', False);

      OrigData := Obj.Find('originalPrice');
      if (OrigData <> nil) and (OrigData.JSONType <> jtNull) then
      begin
        Item.HasOriginalPrice := True;
        Item.OriginalPrice := OrigData.AsInteger;
      end;

      ImagesData := Obj.Find('images');
      if (ImagesData <> nil) and (ImagesData is TJSONArray) then
      begin
        ImagesArr := TJSONArray(ImagesData);
        for j := 0 to ImagesArr.Count - 1 do
          if ImagesArr.Items[j].JSONType = jtString then
            Item.Images.Add(ImagesArr.Items[j].AsString);
      end;

      Result.Add(Item);
    end;
  finally
    Arr.Free;
  end;
end;

class function TProductRegistry.LoadServices(const Path: String): TFPObjectList;
var
  Arr: TJSONArray;
  i: Integer;
  Obj: TJSONObject;
  Item: TRegistryItem;
  OrigData: TJSONData;
  ImageStr, EntryId: String;
begin
  Result := TFPObjectList.Create(True);
  Arr := LoadArray(Path);
  try
    for i := 0 to Arr.Count - 1 do
    begin
      if not (Arr.Items[i] is TJSONObject) then
        raise ERegistryError.Create(
          'Invalid registry entry (expected object) at index ' + IntToStr(i) +
          ' in ' + Path);
      Obj := TJSONObject(Arr.Items[i]);
      EntryId := AsStr(Obj, 'id', 'index ' + IntToStr(i));
      RequireFields(Obj, EntryId);

      Item := TRegistryItem.Create;
      Item.Kind := rkService;
      Item.Id := AsStr(Obj, 'id', '');
      Item.Name := AsStr(Obj, 'name', '');
      Item.Category := '';
      Item.Price := AsInt(Obj, 'price', 0);
      Item.Description := AsStr(Obj, 'description', '');
      Item.Brand := '';
      Item.IsVisible := True;

      OrigData := Obj.Find('originalPrice');
      if (OrigData <> nil) and (OrigData.JSONType <> jtNull) then
      begin
        Item.HasOriginalPrice := True;
        Item.OriginalPrice := OrigData.AsInteger;
      end;

      ImageStr := AsStr(Obj, 'image', '');
      if ImageStr <> '' then
        Item.Images.Add(ImageStr);

      Result.Add(Item);
    end;
  finally
    Arr.Free;
  end;
end;

end.
