unit UProduct;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, UBalance;

type
TImageRefArray = array of Integer;

TProduct = class(TObject)
private // self access only
id : Integer;
name : String;
minstock :Integer;
maxstock :Integer;
balance : TBalance;
imageRef : Integer;
imageRefs : TImageRefArray;
originalPrice : Real;
isService : Boolean;
category : String;
description : String;
brand : String;
productCondition : String;
googleProductCategory : String;


public // access by anything
constructor Create;
procedure setId(newId:Integer);
procedure setName(newName:String);
procedure setMinstock(newMinstock:Integer);
procedure setMaxstock(newMaxstock:Integer);
procedure setBalance(newBalance:TBalance);


function getId():Integer;
function getName():String;
function getMinStock():Integer;
function getMaxStock():Integer;
function getBalance():TBalance;
procedure setImageRef(newImageRef:Integer);
function getImageRef():Integer;
{ Image array support. The product can hold multiple image ids. imageRef is
  kept as the "primary" image (the first one) for backward compatibility. }
procedure addImageRef(imageId:Integer);
procedure clearImageRefs();
function getImageRefCount():Integer;
function getImageRefAt(index:Integer):Integer;
function getImageRefs():TImageRefArray;
procedure setImageRefs(const newImageRefs:TImageRefArray);
procedure setOriginalPrice(newOriginalPrice:Real);
function getOriginalPrice():Real;
procedure setIsService(newIsService:Boolean);
function getIsService():Boolean;
procedure setCategory(newCategory:String);
function getCategory():String;
procedure setDescription(newDescription:String);
function getDescription():String;
procedure setBrand(newBrand:String);
function getBrand():String;
procedure setProductCondition(newCondition:String);
function getProductCondition():String;
procedure setGoogleProductCategory(newCat:String);
function getGoogleProductCategory():String;




end;

implementation

constructor TProduct.Create;
begin
inherited;
balance := TBalance.Create;
imageRef := 0;
SetLength(imageRefs, 0);
originalPrice := 0.0;
isService := False;
category := '';
description := '';
brand := '';
productCondition := 'new';
googleProductCategory := '';
end;

procedure TProduct.setId(newId:Integer);
begin
Self.id:= newId;
end;

procedure TProduct.setName(newName:String);
begin
Self.name:= newName;
end;

procedure TProduct.setMinstock(newMinstock:Integer);
begin
Self.minstock:= newMinstock;
end;

procedure TProduct.setMaxstock(newMaxstock:Integer);
begin
Self.maxstock:= newMaxstock;
end;

function TProduct.getId():Integer;
begin
getId := Self.id;
end;

function TProduct.getName():String;
begin
getName := Self.name;
end;

function TProduct.getMinStock():Integer;
begin
getMinStock := Self.minstock;
end;

function TProduct.getMaxStock():Integer;
begin
getMaxStock := Self.maxstock;
end;

procedure TProduct.setBalance(newBalance:TBalance);
begin
Self.balance := newBalance;
end;

function TProduct.getBalance():TBalance;
begin
     getBalance := balance;
end;

procedure TProduct.setImageRef(newImageRef:Integer);
begin
Self.imageRef := newImageRef;
end;

function TProduct.getImageRef():Integer;
begin
{ Prefer the first element of the array when present so callers that still
  rely on a single reference get the primary image. }
if Length(Self.imageRefs) > 0 then
   getImageRef := Self.imageRefs[0]
else
   getImageRef := Self.imageRef;
end;

procedure TProduct.addImageRef(imageId:Integer);
var
   len : Integer;
begin
if imageId <= 0 then Exit;
len := Length(Self.imageRefs);
SetLength(Self.imageRefs, len + 1);
Self.imageRefs[len] := imageId;
{ Keep the scalar imageRef pointing at the primary (first) image. }
if len = 0 then
   Self.imageRef := imageId;
end;

procedure TProduct.clearImageRefs();
begin
SetLength(Self.imageRefs, 0);
Self.imageRef := 0;
end;

function TProduct.getImageRefCount():Integer;
begin
getImageRefCount := Length(Self.imageRefs);
end;

function TProduct.getImageRefAt(index:Integer):Integer;
begin
if (index >= 0) and (index < Length(Self.imageRefs)) then
   getImageRefAt := Self.imageRefs[index]
else
   getImageRefAt := 0;
end;

function TProduct.getImageRefs():TImageRefArray;
begin
getImageRefs := Self.imageRefs;
end;

procedure TProduct.setImageRefs(const newImageRefs:TImageRefArray);
var
   i : Integer;
begin
SetLength(Self.imageRefs, Length(newImageRefs));
for i := 0 to High(newImageRefs) do
   Self.imageRefs[i] := newImageRefs[i];
if Length(Self.imageRefs) > 0 then
   Self.imageRef := Self.imageRefs[0]
else
   Self.imageRef := 0;
end;

procedure TProduct.setOriginalPrice(newOriginalPrice:Real);
begin
if newOriginalPrice >= 0.0 then
   Self.originalPrice := newOriginalPrice;
end;

function TProduct.getOriginalPrice():Real;
begin
getOriginalPrice := Self.originalPrice;
end;

procedure TProduct.setIsService(newIsService:Boolean);
begin
Self.isService := newIsService;
end;

function TProduct.getIsService():Boolean;
begin
getIsService := Self.isService;
end;

procedure TProduct.setCategory(newCategory:String);
begin
Self.category := newCategory;
end;

function TProduct.getCategory():String;
begin
getCategory := Self.category;
end;

procedure TProduct.setDescription(newDescription:String);
begin
Self.description := newDescription;
end;

function TProduct.getDescription():String;
begin
getDescription := Self.description;
end;

procedure TProduct.setBrand(newBrand:String);
begin
Self.brand := newBrand;
end;

function TProduct.getBrand():String;
begin
getBrand := Self.brand;
end;

procedure TProduct.setProductCondition(newCondition:String);
begin
Self.productCondition := newCondition;
end;

function TProduct.getProductCondition():String;
begin
getProductCondition := Self.productCondition;
end;

procedure TProduct.setGoogleProductCategory(newCat:String);
begin
Self.googleProductCategory := newCat;
end;

function TProduct.getGoogleProductCategory():String;
begin
getGoogleProductCategory := Self.googleProductCategory;
end;

end.
