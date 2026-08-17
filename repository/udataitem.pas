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

unit UDataItem;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, SqlDb, UData, UItem, UDataProduct;

  type
    TDataItem = class(TData)

    public // access by anything

        function new(item:TItem;transactionID:Integer):Integer;
  //      function edit(item:TItem):Boolean;
        function delete(item:TItem):Boolean;
        function get(itemId:Integer):TItem;
        function getTransactionItems(transactionId:Integer):TList;
        function getProductTransactionItems(transactionId:Integer;productId:Integer):TList;

    end;


implementation

    function TDataItem.new(item:TItem;transactionID:Integer):Integer;
    begin
         try
            Self.getQuery().SQL.Text := 'insert into item('+
                              '	operation,product,'+
                              '	cost,'+
                              ' stock,price)'+
                              ' values (:operation,:product,'+
                              '	:cost,'+
                              ' :stock,:price);';

            Self.getQuery().Params.ParamByName('product').AsInteger := item.getProduct().getId();
            Self.getQuery().Params.ParamByName('cost').AsFloat := item.getCost();
            Self.getQuery().Params.ParamByName('stock').AsFloat := item.getStock();
            Self.getQuery().Params.ParamByName('operation').AsInteger := transactionID;
            Self.getQuery().Params.ParamByName('price').AsFloat := item.getPrice();

            Self.getQuery().ExecSQL;
            Self.getQuery().SQL.Text:= 'SELECT last_insert_rowid() id';
            Self.getQuery().Open;
            while not Self.getQuery().EOF do
            begin
                 item.setId(Self.getQuery().FieldByName('id').AsInteger);
                 Self.getQuery().Next;
            end;

            new := item.getId();
            Self.getQuery().Close;

         except
               new := 0;
         end;
    end;

    {function TDataItem.edit(item:TItem):Boolean;
    begin

    end;}

    function TDataItem.delete(item:TItem):Boolean;
    begin
         try
            Self.getQuery().SQL.Text := 'delete from item where id =:id';
            Self.getQuery().Params.ParamByName('id').AsInteger := item.getId();
            Self.getQuery().ExecSQL;
            delete := true;
         except
               delete := false;
         end;
    end;

    function TDataItem.get(itemId:Integer):TItem;
    var
       item:TItem;
       dataProduct:TDataProducto;
    begin
      try
         Self.getQuery().SQL.Text := 'select * from item where id = :id';
         Self.getQuery().Params.ParamByName('id').AsInteger := itemId;
         Self.getQuery().Open;
         dataProduct := TDataProducto.Create(Self.getConnection());
         Self.getQuery().First;
         while not Self.getQuery().EOF do
         begin
              item := TItem.Create;
              item.setId(Self.getQuery().FieldByName('id').AsInteger);
              item.setPrice(Self.getQuery().FieldByName('price').AsFloat);
              item.setCost(Self.getQuery().FieldByName('cost').AsFloat);
              item.setStock(Self.getQuery().FieldByName('stock').AsInteger);
              item.setProduct(dataProduct.get(Self.getQuery().FieldByName('product').AsInteger));
              Self.getQuery().Next;
         end;
         get := item;
         Self.getQuery().Close;
      except
         get := nil;
      end;
    end;

    function TDataItem.getTransactionItems(transactionId:Integer):TList;
    var
       query: TSQLQuery;
       itemList:TList;
    begin
         try
            query := TSQLQuery.Create(nil);
            query.DataBase := self.getConnection();
            query.SQL.Text := 'select * from item where operation = :operation';
            query.Params.ParamByName('operation').AsInteger := transactionId;
            query.Open;
            query.First;
            itemList := TList.Create;
            while not query.EOF do
            begin
                 itemList.Add(Self.get(query.FieldByName('id').AsInteger));
                 query.Next;
            end;
            query.Close;
            getTransactionItems := itemList;
         except
            getTransactionItems := nil;
         end;

    end;

    function TDataItem.getProductTransactionItems(transactionId:Integer;productId:Integer):TList;
    var
       query: TSQLQuery;
       itemList:TList;
    begin
         try
            query := TSQLQuery.Create(nil);
            query.DataBase := self.getConnection();
            query.SQL.Text := 'select * from item where operation = :operation and product = :product order by operation';
            query.Params.ParamByName('operation').AsInteger := transactionId;
            query.Params.ParamByName('product').AsInteger := productId;
            query.Open;
            query.First;
            itemList := TList.Create;
            while not query.EOF do
            begin
                 itemList.Add(Self.get(query.FieldByName('id').AsInteger));
                 query.Next;
            end;
            query.Close;
            getProductTransactionItems := itemList;
         except
            getProductTransactionItems := nil;
         end;

    end;

end.

