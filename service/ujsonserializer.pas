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

unit UJsonSerializer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, UProduct, UBalance;

type
  TJsonSerializer = class(TObject)
  public
    function SerializeProducts(Products: TList; const ImageDir: String): String;
    function SerializeServices(Services: TList; const ImageDir: String): String;
    function SerializeProduct(Product: TProduct; const ImagePath: String): String;
    function SerializeService(Product: TProduct; const ImagePath: String): String;
    function EscapeJsonString(const S: String): String;
    function RoundHalfUp(Value: Real): Integer;
    function FormatJsonObject(const Pairs: array of String): String;
  end;

implementation

function TJsonSerializer.EscapeJsonString(const S: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    c := S[i];
    case c of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #0..#31:
        Result := Result + '\u' + LowerCase(IntToHex(Ord(c), 4));
    else
      Result := Result + c;
    end;
  end;
end;

function TJsonSerializer.RoundHalfUp(Value: Real): Integer;
begin
  Result := Floor(Value + 0.5);
end;

function TJsonSerializer.FormatJsonObject(const Pairs: array of String): String;
var
  i: Integer;
begin
  Result := '{' + LineEnding;
  i := 0;
  while i <= High(Pairs) - 1 do
  begin
    Result := Result + '  ' + Pairs[i] + ': ' + Pairs[i + 1];
    if i + 2 <= High(Pairs) - 1 then
      Result := Result + ',';
    Result := Result + LineEnding;
    i := i + 2;
  end;
  Result := Result + '}';
end;

function TJsonSerializer.SerializeProduct(Product: TProduct; const ImagePath: String): String;
var
  balance: TBalance;
  idStr, nameStr, priceStr, originalPriceStr: String;
  descriptionStr, imagesStr, isVisibleStr, availabilityStr: String;
  categoryStr, brandStr, conditionStr, googleCatStr: String;
begin
  balance := Product.getBalance();

  idStr := '"p' + IntToStr(Product.getId()) + '"';
  nameStr := '"' + EscapeJsonString(Product.getName()) + '"';
  categoryStr := '"' + EscapeJsonString(Product.getCategory()) + '"';
  priceStr := IntToStr(RoundHalfUp(balance.getPrice()));
  originalPriceStr := IntToStr(RoundHalfUp(Product.getOriginalPrice()));
  descriptionStr := '"' + EscapeJsonString(Product.getDescription()) + '"';
  brandStr := '"' + EscapeJsonString(Product.getBrand()) + '"';
  conditionStr := '"' + EscapeJsonString(Product.getProductCondition()) + '"';
  googleCatStr := '"' + EscapeJsonString(Product.getGoogleProductCategory()) + '"';

  if ImagePath <> '' then
    imagesStr := '[' + LineEnding + '      "' + EscapeJsonString(ImagePath) + '"' + LineEnding + '    ]'
  else
    imagesStr := '[]';

  if balance.getStock() > 0 then
  begin
    isVisibleStr := 'true';
    availabilityStr := '"in_stock"';
  end
  else
  begin
    isVisibleStr := 'false';
    availabilityStr := '"out_of_stock"';
  end;

  Result := '{' + LineEnding;
  Result := Result + '    "id": ' + idStr + ',' + LineEnding;
  Result := Result + '    "name": ' + nameStr + ',' + LineEnding;
  Result := Result + '    "category": ' + categoryStr + ',' + LineEnding;
  Result := Result + '    "price": ' + priceStr + ',' + LineEnding;
  Result := Result + '    "originalPrice": ' + originalPriceStr + ',' + LineEnding;
  Result := Result + '    "description": ' + descriptionStr + ',' + LineEnding;
  Result := Result + '    "isVisible": ' + isVisibleStr + ',' + LineEnding;
  Result := Result + '    "images": ' + imagesStr + ',' + LineEnding;
  Result := Result + '    "brand": ' + brandStr + ',' + LineEnding;
  Result := Result + '    "condition": ' + conditionStr + ',' + LineEnding;
  Result := Result + '    "availability": ' + availabilityStr + ',' + LineEnding;
  Result := Result + '    "google_product_category": ' + googleCatStr + LineEnding;
  Result := Result + '  }';
end;

function TJsonSerializer.SerializeService(Product: TProduct; const ImagePath: String): String;
var
  balance: TBalance;
  idStr, nameStr, priceStr, originalPriceStr: String;
  descriptionStr, imageStr, categoryStr, brandStr: String;
  conditionStr, googleCatStr, availabilityStr: String;
begin
  balance := Product.getBalance();

  idStr := '"s' + IntToStr(Product.getId()) + '"';
  nameStr := '"' + EscapeJsonString(Product.getName()) + '"';
  categoryStr := '"' + EscapeJsonString(Product.getCategory()) + '"';
  priceStr := IntToStr(RoundHalfUp(balance.getPrice()));
  originalPriceStr := IntToStr(RoundHalfUp(Product.getOriginalPrice()));
  descriptionStr := '"' + EscapeJsonString(Product.getDescription()) + '"';
  brandStr := '"' + EscapeJsonString(Product.getBrand()) + '"';
  conditionStr := '"' + EscapeJsonString(Product.getProductCondition()) + '"';
  googleCatStr := '"' + EscapeJsonString(Product.getGoogleProductCategory()) + '"';

  if ImagePath <> '' then
    imageStr := '"' + EscapeJsonString(ImagePath) + '"'
  else
    imageStr := '""';

  if balance.getStock() > 0 then
    availabilityStr := '"in_stock"'
  else
    availabilityStr := '"out_of_stock"';

  Result := '{' + LineEnding;
  Result := Result + '    "id": ' + idStr + ',' + LineEnding;
  Result := Result + '    "name": ' + nameStr + ',' + LineEnding;
  Result := Result + '    "category": ' + categoryStr + ',' + LineEnding;
  Result := Result + '    "price": ' + priceStr + ',' + LineEnding;
  Result := Result + '    "originalPrice": ' + originalPriceStr + ',' + LineEnding;
  Result := Result + '    "description": ' + descriptionStr + ',' + LineEnding;
  Result := Result + '    "image": ' + imageStr + ',' + LineEnding;
  Result := Result + '    "brand": ' + brandStr + ',' + LineEnding;
  Result := Result + '    "condition": ' + conditionStr + ',' + LineEnding;
  Result := Result + '    "availability": ' + availabilityStr + ',' + LineEnding;
  Result := Result + '    "google_product_category": ' + googleCatStr + LineEnding;
  Result := Result + '  }';
end;

function TJsonSerializer.SerializeProducts(Products: TList; const ImageDir: String): String;
var
  i: Integer;
  product: TProduct;
begin
  if Products.Count = 0 then
  begin
    Result := '[]';
    Exit;
  end;

  Result := '[' + LineEnding;
  for i := 0 to Products.Count - 1 do
  begin
    product := TProduct(Products[i]);
    Result := Result + '  ' + SerializeProduct(product, '');
    if i < Products.Count - 1 then
      Result := Result + ',';
    Result := Result + LineEnding;
  end;
  Result := Result + ']';
end;

function TJsonSerializer.SerializeServices(Services: TList; const ImageDir: String): String;
var
  i: Integer;
  product: TProduct;
begin
  if Services.Count = 0 then
  begin
    Result := '[]';
    Exit;
  end;

  Result := '[' + LineEnding;
  for i := 0 to Services.Count - 1 do
  begin
    product := TProduct(Services[i]);
    Result := Result + '  ' + SerializeService(product, '');
    if i < Services.Count - 1 then
      Result := Result + ',';
    Result := Result + LineEnding;
  end;
  Result := Result + ']';
end;

end.
