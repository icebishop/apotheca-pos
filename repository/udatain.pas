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

unit UDataIn;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, SqlDb, UDataTransaction, UIn, UProduct,
  USupplier;

  type
    TDataIn  = class(TDataTransaction)

    public // access by anything

       function get(inId:Integer):TIn;overload;
       function get(product:TProduct):TList;overload;
       function get(supplier:TSupplier):TList;overload;
    end;

implementation

   function TDataIn.get(inId:Integer):TIn;
   begin
        get := TIn(inherited get(inId))
   end;

   function TDataIn.get(product:TProduct):TList;
    var
       query : TSQLQuery;
       transactionList : TList;
    begin
      try
         query := TSQLQuery.Create(nil);
         query.DataBase := self.getConnection();
         query.SQL.Text := 'select distinct operation.id '+
                           '  from operation, item, product'+
                           ' where operation.id = item.operation'+
                           '   and item.product = product.id'+
                           '   and product.id  = :product'+
                           '   and type = 1 order by operation.date,operation.id';
         query.Params.ParamByName('product').AsInteger := product.getId();
         query.Open;

         query.First;
         transactionList := TList.Create;
         while not query.EOF do
         begin
              transactionList.Add(Self.get(query.FieldByName('id').AsInteger));
              query.Next;
         end;
         query.close;
         get := transactionList;
      except
         get := nil;
      end;
    end;


    function TDataIn.get(supplier:TSupplier):TList;
    var
       query : TSQLQuery;
       transactionList : TList;
    begin
      try
         query := TSQLQuery.Create(nil);
         query.DataBase := self.getConnection();
         query.SQL.Text := 'select distinct operation.id '+
                           '  from operation, item, person'+
                           ' where operation.id = item.operation'+
                           '   and operation.person  = :person'+
                           '   and type = 1 order by operation.date,operation.id';
         query.Params.ParamByName('person').AsInteger := supplier.getId();
         query.Open;

         query.First;
         transactionList := TList.Create;
         while not query.EOF do
         begin
              transactionList.Add(Self.get(query.FieldByName('id').AsInteger));
              query.Next;
         end;
         query.close;
         get := transactionList;
      except
         get := nil;
      end;
    end;


end.

