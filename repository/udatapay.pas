unit UDataPay;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, SqlDb, UData, UPay, UPerson;

  type
    TDataPay = class(TData)

    public // access by anything


        function new(pay:TPay):Integer;
        function edit(pay:TPay):Boolean;
        function delete(pay:TPay):Boolean;
        function get(id:Integer):TPay;overload;
        function get(person:TPerson):TList;
    end;

implementation

    function TDataPay.new(pay:TPay):Integer;
    begin
         try
            Self.getQuery().SQL.Text := 'insert into pay('+
                              '	person,'+
                              '	date,'+
                              '	val)'+
                              ' values (:person,'+
                              ' :date,'+
                              '	:val);';

            Self.getQuery().Params.ParamByName('person').AsInteger := pay.getPerson().getId();
            Self.getQuery().Params.ParamByName('date').AsDate := pay.getDate();
            Self.getQuery().Params.ParamByName('val').AsFloat := pay.getValue();
            Self.getQuery().ExecSQL;
            Self.getQuery().SQL.Text:= 'SELECT last_insert_rowid() id';
            Self.getQuery().Open;
            while not Self.getQuery().EOF do
            begin
                 pay.setId(Self.getQuery().FieldByName('id').AsInteger);
                 Self.getQuery().Next;
            end;
            new := pay.getId();
         except
               new := 0;
         end;
    end;

    function TDataPay.edit(pay:TPay):Boolean;
    begin
         try
            Self.getQuery().SQL.Text := 'update pay '+
                              '   set person = :person,'+
                              '       date = :date,'+
                              '       val = :val'+
                              '  where id = :id';
            Self.getQuery().Params.ParamByName('person').AsInteger := pay.getPerson().getId();
            Self.getQuery().Params.ParamByName('val').AsFloat := pay.getValue();
            Self.getQuery().Params.ParamByName('date').AsDate:= pay.getDate();
            Self.getQuery().Params.ParamByName('id').AsInteger:= pay.getId();
            Self.getQuery().ExecSQL;
            edit := true;
         except
               edit := false;
         end;
    end;

    function TDataPay.delete(pay:TPay):Boolean;
    begin
         try
            Self.getQuery().SQL.Text := 'delete from pay where id =:id';
            Self.getQuery().Params.ParamByName('id').AsInteger := pay.getId();
            Self.getQuery().ExecSQL;
            delete := true;
         except
               delete := false;
         end;
    end;

    function TDataPay.get(id:Integer):TPay;
    var
       pay:TPay;
    begin
      try

         Self.getQuery().SQL.Text := 'select * from pay where id = :id';
         Self.getQuery().Params.ParamByName('id').AsInteger := id;
         Self.getQuery().Open;
         Self.getQuery().First;

         while not Self.getQuery().EOF do
         begin
              pay := TPay.Create;
              pay.setId(Self.getQuery().FieldByName('id').AsInteger);
              pay.setValue(Self.getQuery().FieldByName('val').Asfloat);
              pay.setDate(Self.getQuery().FieldByName('date').AsDateTime);
              Self.getQuery().Next;
         end;
         Self.getQuery().close;
         get := pay;
      except
         get := nil;
      end;
    end;

    function TDataPay.get(person:TPerson):TList;
    var
       query: TSQLQuery;
       payList : TList;
       pay : TPay;
    begin
      try
       query := TSQLQuery.Create(nil);
       query.DataBase := self.getConnection();
       query.SQL.Text := 'select * from pay where person = :person';
       query.Params.ParamByName('person').AsInteger := person.getId();
       query.Open;

       query.First;

       payList := TList.Create;
       while not query.EOF do
       begin
           pay :=  Self.get(query.FieldByName('id').AsInteger);
           pay.setPerson(person);
           payList.Add(pay);
           query.Next;
       end;

       query.Close;

       get :=  payList;

      except
            get := nil;
      end;
    end;

end.

