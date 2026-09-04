unit UDataTransaction;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, SqlDb, LazLogger, ULogger, UData, UProduct, UBalance, UDataBalance,UDataItem,
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
          existing : TBalance;
          balanceId : Integer;
        begin
          { Resolve the real balance id. The product's in-memory balance id may
            be 0 (product created without a balance row, or a freshly built
            TProduct), so look it up in the DB. Use a dedicated instance for the
            lookup so its (open) query does not clash with the update/insert. }
          balanceId := product.getBalance().getId();
          if balanceId <= 0 then
          begin
            dataBalance := TDataBalance.Create(Self.getConnection());
            try
              existing := dataBalance.get(product.getId());
              try
                balanceId := existing.getId();
              finally
                existing.Free;
              end;
            finally
              dataBalance.Destroy;
            end;
            product.getBalance().setId(balanceId);
          end;

          { Fresh instance for the write, so we never reuse a query left open by
            the lookup above. }
          dataBalance := TDataBalance.Create(Self.getConnection());
          try
            if balanceId > 0 then
              updateBalance := dataBalance.edit(product)
            else
            begin
              { No balance row for this product yet: INSERT one so the purchased
                units are actually recorded (previously UPDATE hit zero rows and
                the stock was silently lost). }
              product.getBalance().setId(dataBalance.new(product));
              updateBalance := product.getBalance().getId() > 0;
              if not updateBalance then
                LogError('DataTransaction', 'BALANCE_INSERT_FAILED',
                  'productId=' + IntToStr(product.getId()));
            end;
          finally
            dataBalance.Destroy;
          end;
        end;

    function TDataTransaction.new(transaction:TTransaction):Integer;
    var
      i : Integer;
      dataItem : TDataItem;
      item:TItem;
      ok : Boolean;
    begin
         new := 0;

         { Guard against nil header fields that would throw on the insert. }
         if transaction.getOperationType() = nil then
         begin
              LogError('DataTransaction', 'NEW_HEADER_NIL', 'operationType=nil');
              Exit;
         end;
         if transaction.getPerson() = nil then
         begin
              LogError('DataTransaction', 'NEW_HEADER_NIL', 'person=nil');
              Exit;
         end;

         { Insert the operation header. This was previously OUTSIDE any handler,
           so a failure here (schema/constraint/nil) threw uncaught. }
         try
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
            Self.getQuery().Close;
            LogInfo('DataTransaction', 'OPERATION_INSERTED',
              'operationId=' + IntToStr(transaction.getId()) +
              ' type=' + IntToStr(transaction.getOperationType().getId()) +
              ' person=' + IntToStr(transaction.getPerson().getId()));
         except
            on E: Exception do
            begin
                 LogError('DataTransaction', 'OPERATION_INSERT_FAILED',
                   'error=' + E.ClassName + ': ' + E.Message);
                 new := 0;
                 Exit;
            end;
         end;

         new := transaction.getId();
         dataItem := TDataItem.Create(Self.getConnection());
         ok := true;

         try
            try
               for i:=0 to transaction.getItemList.Count-1 do
               begin
                    if not ok then
                       Break;
                    item := TItem(transaction.getItemList[i]);
                    { Persist the item; failure aborts the whole operation. }
                    if dataItem.new(item, transaction.getId()) = 0 then
                    begin
                       LogError('DataTransaction', 'ITEM_INSERT_ZERO',
                         'row=' + IntToStr(i) + ' operationId=' + IntToStr(transaction.getId()));
                       ok := false;
                    end;
                    { Update the running stock/balance for the product; keep the
                      failure flag from either step (previously this line
                      overwrote a failed item insert, hiding the error). }
                    if ok then
                    begin
                       ok := Self.updateBalance(item.getProduct());
                       if not ok then
                          LogError('DataTransaction', 'UPDATE_BALANCE_FAILED',
                            'row=' + IntToStr(i) +
                            ' productId=' + IntToStr(item.getProduct().getId()) +
                            ' balanceId=' + IntToStr(item.getProduct().getBalance().getId()));
                    end;
               end;

               { If any item/balance step failed, report failure so the caller
                 rolls back instead of committing a half-written operation. }
               if not ok then
                  new := 0
               else
                  LogInfo('DataTransaction', 'NEW_OK',
                    'operationId=' + IntToStr(transaction.getId()) +
                    ' items=' + IntToStr(transaction.getItemList.Count));
            except
               on E: Exception do
               begin
                  LogError('DataTransaction', 'NEW_ITEMS_EXCEPTION',
                    'error=' + E.ClassName + ': ' + E.Message);
                  new := 0;
               end;
            end;
         finally
            dataItem.Destroy;
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

