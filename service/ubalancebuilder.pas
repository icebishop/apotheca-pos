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

unit UBalanceBuilder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UItem, UBalance, UDataTransaction, UDataModule, UProduct,
  UTransaction, sqldb, UDataProduct, UDataBalance;

  type
    TBalanceBuilder = class(TObject)
    private // self access only
      balanceMessage : String;
      function calculateBalanceIN(item:TItem; balance:TBalance):TBalance;
      function calculateBalanceOUT(item:TItem; balance:TBalance):TBalance;

    public // access by anything
      function build(product:TProduct):TBalance;Overload;
      function build():boolean;
      function getBalanceMessage():String;
    end;

implementation

function TBalanceBuilder.calculateBalanceIN(item:TItem; balance:TBalance):TBalance;
begin
   balance.setBalance(balance.getBalance()+(item.getCost()*item.getStock()));
   balance.setPrice(item.getPrice());
   balance.setStock(balance.getStock()+item.getStock());
   balance.setCost(balance.getBalance()/balance.getStock());
   calculateBalanceIN := balance;
end;

function TBalanceBuilder.calculateBalanceOUT(item:TItem; balance:TBalance):TBalance;
begin

   balance.setBalance(balance.getBalance()-(balance.getCost()*item.getStock()));
   balance.setStock(balance.getStock()-item.getStock());
   calculateBalanceOut := balance;
end;

function TBalanceBuilder.build(product:TProduct):TBalance;
var
   dataTransaction:TDataTransaction;
   transactionList :TList;
   transaction: TTransaction;
   item:TItem;
   balance:TBalance;
   i,j : Integer;
begin

   dataTransaction := TDataTransaction.Create(DataModule1.SQLite3Connection1);

   transactionList := dataTransaction.get(product);
   balance := TBalance.Create;
   balance.setId(product.getBalance().getId());


   for i := 0 to transactionList.Count-1 do
   begin
        transaction := TTransaction(transactionList[i]);

        for j := 0 to transaction.getItemList().Count-1 do
        begin
             item := TItem(transaction.getItemList()[j]);

             if transaction.getOperationType().getTyp() = 'in'then
                balance := Self.calculateBalanceIN(item,balance)
             else
                balance := Self.calculateBalanceOUT(item,balance)
        end;
   end;
   build := balance;
end;

function TBalanceBuilder.build():boolean;
var
   i : Integer;
   dataProduct: TDataProducto;
   productList:TList;
   dataBalance : TDataBalance;
   product : TProduct;
   ret:integer;
   balance:TBalance;
begin
   ret:=0;
   dataProduct := TDataProducto.Create(DataModule1.SQLite3Connection1);
   dataBalance := TDataBalance.Create(DataModule1.SQLite3Connection1);
   productList := dataProduct.find('');
   for i := 0 to productList.Count -1 do
   begin
       product := TProduct(productList[i]);
       balance := Self.build(product) ;
       if balance.getStock() >= 0 then
       begin
            product.setBalance(balance);
            dataBalance.edit(product);
       end
       else
       begin
           ret:=ret+1;
           balanceMessage:= balanceMessage + 'The product:'+ product.getName() +' has negative stock: '+ IntToStr(balance.getStock())+ Char(13) ;
       end;
   end;

   if ret > 0 then
      build := false
   else
      build := true;
end;

function TBalanceBuilder.getBalanceMessage():String;
begin
     getBalanceMessage := balanceMessage;
end;

end.

