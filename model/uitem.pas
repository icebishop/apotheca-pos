unit UItem;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, UProduct;

type
TItem = class(TObject)
private // self access only
id : Integer;
product : TProduct;
cost :Real;
stock :Integer;
price  : Real;

public // access by anything
Constructor Create();
procedure setId(newId:Integer);
procedure setProduct(newProduct:TProduct);
procedure setStock(newStock:Integer);
procedure setPrice(newPrice:Real);
procedure setCost(newCost:Real);
function getId():Integer;
function getProduct():TProduct;
function getStock():Integer;
function getPrice():Real;
function getCost():Real;
end;

implementation

Constructor TItem.Create();
begin
   id := 0;
   product:=nil;
   stock := 0;
   price:= 0;
   cost:= 0;
end;

procedure TItem.setId(newId:Integer);
begin
Self.id:= newId;
end;

procedure TItem.setProduct(newProduct:TProduct);
begin
Self.product:= newProduct;
end;

procedure TItem.setStock(newStock:Integer);
begin
Self.stock:= newStock;
end;

procedure TItem.setPrice(newPrice:Real);
begin
Self.price:= newPrice;
end;

procedure TItem.setCost(newCost:Real);
begin
Self.cost:= newCost;
end;

function TItem.getId():Integer;
begin
getId := Self.id;
end;

function TItem.getProduct():TProduct;
begin
getProduct := Self.product;
end;


function TItem.getStock():Integer;
begin
getStock := Self.stock;
end;

function TItem.getPrice():Real;
begin
getPrice := Self.price;
end;

function TItem.getCost():Real;
begin
getCost := Self.cost;
end;

end.
