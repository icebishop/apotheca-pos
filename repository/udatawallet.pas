unit UDataWallet;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, SqlDb, UData, UWallet, UDataIn, UDataPay,
  UDataCustomer;

  type
    TDataWallet  = class(TData)

    public // access by anything


        function get(wallet:TWallet):TWallet;
        function find(name:String):TList;

    end;

implementation

   function TDataWallet.get(wallet:TWallet):TWallet;
   var
      dataIn : TDataIn;
      dataPay : TDataPay;
   begin
      dataIn := TDataIn.Create(Self.getConnection());
      wallet.setListSale(dataIn.get(wallet.getCustomer()));

      dataPay := TDataPay.Create(Self.getConnection());
      wallet.setListPay(dataPay.get(wallet.getCustomer()));

      get := wallet;
   end;

   function  TDataWallet.find(name:String):TList;
   var
       listWallet:TList;
       wallet : TWallet;
       dataCustomer : TDataCustomer;
   begin
      try
         Self.getQuery().SQL.Text := 'select person.id from person, customer where customer.person = person.id ';
         if name <> '' then
         begin
            Self.getQuery().SQL.Text := Self.getQuery().SQL.Text + ' and name like :name';
            Self.getQuery().Params.ParamByName('name').AsString := name;
         end;
         Self.getQuery().Open;

         listWallet := TList.Create;
         dataCustomer := TDataCustomer.Create(Self.getConnection());
         Self.getQuery().First;
         while not Self.getQuery().EOF do
         begin
              wallet := TWallet.Create;
              wallet.setCustomer(dataCustomer.get(Self.getQuery().FieldByName('id').AsInteger));
              wallet := Self.get(wallet);
              wallet.calculate();
              listWallet.Add(wallet);
              Self.getQuery().Next;
         end;
         Self.getQuery().Close;
         find := listWallet;
      except
        find := nil;
      end;
   end;

end.

