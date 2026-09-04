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
  UTransaction, sqldb, UDataProduct, UDataBalance, LazLogger;

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
   Result := nil;
   try
   dataTransaction := TDataTransaction.Create(DataModule1.SQLite3Connection1);

   transactionList := dataTransaction.get(product);
   balance := TBalance.Create;
   balance.setId(product.getBalance().getId());

   DebugLn('[BalanceBuilder] Product: ' + product.getName() +
     ' (id=' + IntToStr(product.getId()) + ') - ' +
     IntToStr(transactionList.Count) + ' transactions');

   for i := 0 to transactionList.Count-1 do
   begin
        transaction := TTransaction(transactionList[i]);

        for j := 0 to transaction.getItemList().Count-1 do
        begin
             item := TItem(transaction.getItemList()[j]);

             DebugLn('[BalanceBuilder]   Op id=' + IntToStr(transaction.getId()) +
               ' type=' + transaction.getOperationType().getTyp() +
               ' (' + transaction.getOperationType().getName() + ')' +
               ' qty=' + IntToStr(item.getStock()) +
               ' cost=' + FormatFloat('0.00', item.getCost()) +
               ' price=' + FormatFloat('0.00', item.getPrice()));

             if transaction.getOperationType().getTyp() = 'in'then
                balance := Self.calculateBalanceIN(item,balance)
             else
                balance := Self.calculateBalanceOUT(item,balance)
        end;
   end;

   DebugLn('[BalanceBuilder]   Result: stock=' + IntToStr(balance.getStock()) +
     ' cost=' + FormatFloat('0.00', balance.getCost()) +
     ' price=' + FormatFloat('0.00', balance.getPrice()) +
     ' balance=' + FormatFloat('0.00', balance.getBalance()));

   Result := balance;
   except
     on E: Exception do DebugLn('[TBalanceBuilder.build(product)] ERROR: ' + E.Message);
   end;
end;

function TBalanceBuilder.build():boolean;
var
   i : Integer;
   dataProduct: TDataProducto;
   productList:TList;
   dataBalance : TDataBalance;
   product : TProduct;
   balance:TBalance;
begin
   Result := False;
   try
   dataProduct := TDataProducto.Create(DataModule1.SQLite3Connection1);
   dataBalance := TDataBalance.Create(DataModule1.SQLite3Connection1);
   productList := dataProduct.find('');
   DebugLn('[TBalanceBuilder.build] Found ' + IntToStr(productList.Count) + ' products');

   { Ensure transaction is active for writes }
   if not DataModule1.SQLite3Connection1.Transaction.Active then
     DataModule1.SQLite3Connection1.Transaction.StartTransaction;

   for i := 0 to productList.Count -1 do
   begin
       product := TProduct(productList[i]);
       balance := Self.build(product);
       if balance <> nil then
       begin
         product.setBalance(balance);
         { A product may have NO balance row yet (e.g. created without one, or
           a product whose only movements are purchases). balance.getId()=0 in
           that case, so an UPDATE would touch zero rows and silently drop the
           recomputed stock. INSERT a fresh row instead; otherwise UPDATE. }
         if balance.getId() > 0 then
         begin
           if not dataBalance.edit(product) then
             DebugLn('[TBalanceBuilder.build] FAILED edit for id=' + IntToStr(product.getId()));
         end
         else
         begin
           if dataBalance.new(product) <= 0 then
             DebugLn('[TBalanceBuilder.build] FAILED insert for id=' + IntToStr(product.getId()))
           else
             DebugLn('[TBalanceBuilder.build] INSERTED missing balance for id=' +
               IntToStr(product.getId()));
         end;
       end
       else
         DebugLn('[TBalanceBuilder.build] NIL balance for id=' + IntToStr(product.getId()));
   end;

   { Commit }
   if DataModule1.SQLite3Connection1.Transaction.Active then
     DataModule1.SQLite3Connection1.Transaction.Commit;

   DebugLn('[TBalanceBuilder.build] Rebuild committed OK');
   Result := true;
   except
     on E: Exception do
     begin
       DebugLn('[TBalanceBuilder.build] ERROR: ' + E.Message);
       try
         if DataModule1.SQLite3Connection1.Transaction.Active then
           DataModule1.SQLite3Connection1.Transaction.Rollback;
       except
       end;
     end;
   end;
end;

function TBalanceBuilder.getBalanceMessage():String;
begin
     getBalanceMessage := balanceMessage;
end;

end.

