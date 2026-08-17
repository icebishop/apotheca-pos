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

unit UDataBalance;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, sqlite3conn, SqlDb, UData, UBalance, UProduct;

type
TDataBalance = class(TData)

public // access by anything

function new(product:TProduct):Integer;
function edit(product:TProduct):Boolean;
function delete(balance:TBalance):Boolean;
function get(productId:Integer):TBalance;
end;

implementation

function TDataBalance.new(product:TProduct):Integer;
begin
try


Self.getQuery().SQL.Text := 'insert into balance('+
'	product,'+
'	units,'+
'	balance,'+
' cost, price)'+
' values (:product,'+
' :units,'+
'	:balance,'+
' :cost,:price);';

Self.getQuery().Params.ParamByName('product').AsInteger := product.getId();
Self.getQuery().Params.ParamByName('units').AsInteger := product.getBalance.getStock();
Self.getQuery().Params.ParamByName('balance').AsFloat := product.getBalance.getBalance();
Self.getQuery().Params.ParamByName('cost').AsFloat := product.getBalance.getCost();
Self.getQuery().Params.ParamByName('price').AsFloat := product.getBalance.getPrice();


Self.getQuery().ExecSQL;
Self.getQuery().SQL.Text:= 'SELECT last_insert_rowid() id';
Self.getQuery().Open;
while not Self.getQuery().EOF do
begin
product.getBalance.setId(Self.getQuery().FieldByName('id').AsInteger);
Self.getQuery().Next;
end;

new := product.getBalance.getId();


except
new := 0;
end;
end;

function TDataBalance.edit(product:TProduct):Boolean;
var
test:String;
begin
try
Self.getConnection().Transaction := Self.getTransaction();
Self.getQuery().DataBase := Self.getConnection();
Self.getQuery().SQL.Text := 'update balance '+
'   set product = :product,'+
'       units = :units,'+
'       cost = :cost,'+
'       price = :price,'+
'       balance = :balance'+
'  where id = :id';
Self.getQuery().Params.ParamByName('product').AsInteger := product.getId();
Self.getQuery().Params.ParamByName('units').AsInteger := product.getBalance.getStock();
Self.getQuery().Params.ParamByName('cost').AsFloat := product.getBalance.getCost();
Self.getQuery().Params.ParamByName('price').AsFloat := product.getBalance.getPrice();
Self.getQuery().Params.ParamByName('balance').AsFloat := product.getBalance.getBalance();
Self.getQuery().Params.ParamByName('id').AsInteger := product.getBalance.getId();
test := Self.getQuery().SQL.Text;
Self.getQuery().ExecSQL;

edit := true;
except
edit := false;
end;
end;

function TDataBalance.delete(balance:TBalance):Boolean;
begin
try

Self.getQuery().SQL.Text := 'delete from balance where id =:id';
Self.getQuery().Params.ParamByName('id').AsInteger := balance.getId();

Self.getQuery().ExecSQL;

delete := true;


except
delete := false;
end;
end;

function TDataBalance.get(productId:Integer):TBalance;
var
balance:TBalance;
begin
try
Self.getQuery().SQL.Text := 'select * from balance where product = :productId';
Self.getQuery().Params.ParamByName('productId').AsInteger := productId;
Self.getQuery().Open;

Self.getQuery().First;
while not Self.getQuery().EOF do
begin
balance := TBalance.Create;
balance.setId(Self.getQuery().FieldByName('id').AsInteger);
balance.setStock(Self.getQuery().FieldByName('units').AsInteger);
balance.setBalance(Self.getQuery().FieldByName('balance').AsFloat);
balance.setPrice(Self.getQuery().FieldByName('price').AsFloat);
balance.setCost(Self.getQuery().FieldByName('cost').AsFloat);
Self.getQuery().Next;
end;
get := balance;
except
get := nil;
end;
end;

end.
