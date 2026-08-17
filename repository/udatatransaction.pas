unit UDataTransaction;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, SqlDb, UData, UProduct, UDataBalance,UDataItem,
  UItem, UTransaction, UDataPerson, UDataOperationType, UPerson, UIn, UOut;

  type
    TDataTransaction  = class(TData)

    public // access by anything

        function updateBalance(product:TProduct):Boolean;
        function new(transaction:TTransaction):Integer;
        function edit(transaction:TTransaction):Boolean;
        function delete(transaction:TTransaction):Boolean;

        function get(person:TPerson):TList;overload;
        function get(product:TProduct):TList;overload;
        function get(transactionId:Integer):TTransaction;overload;
        function get(transactionId:Integer;productId:Integer):TTransaction;
    end;

implementation

        function TDataTransaction.updateBalance(product:TProduct):Boolean;
        var
          dataBalance : TDataBalance;
        begin
          dataBalance := TDataBalance.Create(Self.getConnection());
          updateBalance := dataBalance.edit(product);
        end;

    function TDataTransaction.new(transaction:TTransaction):Integer;
    var
      i : Integer;
      dataItem : TDataItem;
      item:TItem;
      ok : Boolean;
    begin
         Self.getQuery().SQL.Text := 'insert into operation (type,'+
                                                               ' date,'+
                                                               ' person,'+
                                                               ' credit)'+
                                                               ' values(:type,'+
                                                               ' :date,'+
                                                               ' :person,'+
                                                               ' :credit)';
         Self.getQuery().Params.ParamByName('type').AsInteger := transaction.getOperationType().getId();
         Self.getQuery().Params.ParamByName('date').AsDate := transaction.getDate();
         Self.getQuery().Params.ParamByName('person').AsInteger := transaction.getPerson().getId();
         Self.getQuery().Params.ParamByName('credit').AsInteger := transaction.getCredit();
         Self.getQuery().ExecSQL;

         Self.getQuery().SQL.Text:= 'SELECT last_insert_rowid() id';
         Self.getQuery().Open;

         while not Self.getQuery().EOF do
         begin
              transaction.setId(Self.getQuery().FieldByName('id').AsInteger);
              Self.getQuery().Next;
         end;

         new := transaction.getId();
         dataItem := TDataItem.Create(Self.getConnection());
         ok := true;

         try
            for i:=0 to transaction.getItemList.Count-1 do
            begin
                 if ok then
                 begin
                          item := TItem(transaction.getItemList[i]);
                          if dataItem.new(item, transaction.getId()) = 0 then
                          ok := false;
                          ok := Self.updateBalance(item.getProduct());
                 end;
            end;
         except
               new := 0;
         end;
    end;

    function TDataTransaction.edit(transaction:TTransaction):Boolean;
    var
      i : Integer;
      dataItem : TDataItem;
      item:TItem;
      ok : Boolean;
    begin

       try
         Self.getQuery().SQL.Text := 'update operation set type = :type, '+
                                                         ' date = :date, '+
                                                         ' person = :person '+
                                                         ' where id = :Id';
         Self.getQuery().Params.ParamByName('type').AsInteger := transaction.getOperationType().getId();
         Self.getQuery().Params.ParamByName('date').AsDate := transaction.getDate();
         Self.getQuery().Params.ParamByName('person').AsInteger := transaction.getPerson().getId();
         Self.getQuery().Params.ParamByName('id').AsInteger := transaction.getId();
         Self.getQuery().ExecSQL;
         Self.getQuery().Close;
         Self.getQuery().SQL.Text := 'delete from item where operation =:id';
         Self.getQuery().Params.ParamByName('id').AsInteger := transaction.getId();
         Self.getQuery().ExecSQL;
         Self.getQuery().Close;

         dataItem := TDataItem.Create(Self.getConnection());



            for i:=0 to transaction.getItemList.Count-1 do
            begin
                 if ok then
                 begin
                          item := TItem(transaction.getItemList[i]);
                          if dataItem.new(item, transaction.getId()) = 0 then
                          ok := false;
                          ok := Self.updateBalance(item.getProduct());
                 end;
            end;
            edit := true;
         except
               edit := false;
         end;
    end;


    function TDataTransaction.delete(transaction:TTransaction):Boolean;
    begin
         try
            Self.getQuery().SQL.Text := 'delete from item where operation =:id';
            Self.getQuery().Params.ParamByName('id').AsInteger := transaction.getId();
            Self.getQuery().ExecSQL;
            Self.getQuery().Close;
            Self.getQuery().SQL.Text := 'delete from operation where id =:id';
            Self.getQuery().Params.ParamByName('id').AsInteger := transaction.getId();
            Self.getQuery().ExecSQL;
            Self.getQuery().Close;
            delete := true;
         except
               delete := false;
         end;
    end;

    function TDataTransaction.get(transactionId:Integer):TTransaction;overload;
    var
       transaction:TTransaction;
       dataItem : TDataItem;
       dataPerson:TDataPerson;
       dataOperationType: TDataOperationType;
    begin
      try
         Self.getQuery().SQL.Text := 'select  operation.id,operation.type,operation.date,operation.person, operationtype.type as inout  from operation  , operationtype where operation.type = operationtype.id and operation.id = :id';
         Self.getQuery().Params.ParamByName('id').AsInteger := transactionId;
         Self.getQuery().Open;

         dataItem := TDataItem.Create(Self.getConnection());
         dataPerson := TDataPerson.Create(Self.getConnection());
         dataOperationType := TDataOperationType.Create(Self.getConnection());
         Self.getQuery().First;

         while not Self.getQuery().EOF do
         begin
              if Self.getQuery().FieldByName('inout').AsString = 'in' then
                 transaction := TIn.Create
              else
                 transaction := TOut.Create;
              transaction.setId(Self.getQuery().FieldByName('id').AsInteger);
              transaction.setPerson(dataPerson.get(Self.getQuery().FieldByName('person').AsInteger));
              transaction.setDate(FloatToDateTime(Self.getQuery().FieldByName('date').AsFloat));
              transaction.setItemList(dataItem.getTransactionItems(Self.getQuery().FieldByName('id').AsInteger));
              transaction.setOperationType(dataOperationType.get(Self.getQuery().FieldByName('type').AsInteger));
              Self.getQuery().Next;
         end;
         Self.getQuery().close;
         get := transaction;
      except
         get := nil;
      end;
    end;

    function TDataTransaction.get(transactionId:Integer;productId:Integer):TTransaction;
    var
       transaction:TTransaction;
       dataItem : TDataItem;
       dataPerson:TDataPerson;
       dataOperationType: TDataOperationType;
    begin
      try
         Self.getQuery().SQL.Text := 'select  operation.id,operation.type,operation.date,operation.person, operationtype.type inout  from operation  , operationtype where operation.type = operationtype.id and operation.id = :id order by operation.date, operation.id';
         Self.getQuery().Params.ParamByName('id').AsInteger := transactionId;
         Self.getQuery().Open;

         dataItem := TDataItem.Create(Self.getConnection());
         dataPerson := TDataPerson.Create(Self.getConnection());
         dataOperationType := TDataOperationType.Create(Self.getConnection());
         Self.getQuery().First;

         while not Self.getQuery().EOF do
         begin
              if Self.getQuery().FieldByName('inout').AsString = 'in' then
                 transaction := TIn.Create
              else
                 transaction := TOut.Create;
              transaction.setId(Self.getQuery().FieldByName('id').AsInteger);
              transaction.setPerson(dataPerson.get(Self.getQuery().FieldByName('person').AsInteger));
              transaction.setDate(FloatToDateTime(Self.getQuery().FieldByName('date').AsFloat));
              transaction.setItemList(dataItem.getProductTransactionItems(Self.getQuery().FieldByName('id').AsInteger,productId));
              transaction.setOperationType(dataOperationType.get(Self.getQuery().FieldByName('type').AsInteger));
              Self.getQuery().Next;
         end;
         Self.getQuery().close;
         get := transaction;
      except
         get := nil;
      end;
    end;



    function TDataTransaction.get(person:TPerson):TList;overload;
    var
       query : TSQLQuery;
       transactionList : TList;
    begin
      try
         query := TSQLQuery.Create(nil);
         query.DataBase := self.getConnection();
         query.SQL.Text := 'select * from operation where person = :person';
         query.Params.ParamByName('person').AsInteger := person.getId();
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

    function TDataTransaction.get(product:TProduct):TList;overload;
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
                           ' order by operation.date,operation.id';
         query.Params.ParamByName('product').AsInteger := product.getId();
         query.Open;

         query.First;
         transactionList := TList.Create;
         while not query.EOF do
         begin
              transactionList.Add(Self.get(query.FieldByName('id').AsInteger,product.getId()));
              query.Next;
         end;
         query.close;
         get := transactionList;
      except
         get := nil;
      end;
    end;
end.

