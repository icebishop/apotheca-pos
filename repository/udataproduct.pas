unit UDataProduct;

{$mode objfpc}{$H+}

interface



uses
  Classes, SysUtils, sqlite3conn, SqlDb, UProduct, UData, UDataBalance;

  type
    TDataProducto = class(TData)

    public // access by anything

        function find(name:String):TList;
        function findInStock(name:String):TList;
        function new(product:TProduct):Integer;
        function edit(product:TProduct):Boolean;
        function delete(product:TProduct):Boolean;
        function get(id:Integer):TProduct;
        function getBalance(name:String):TList;


    end;

implementation

    function TDataProducto.find(name:String):TList;
    var
       listProduct:TList;
       product:TProduct;
    begin

         Self.getQuery().SQL.Text := 'select id from product ';
         if name <> '' then
         begin
            Self.getQuery().SQL.Text := Self.getQuery().SQL.Text + 'where name like :name';
            Self.getQuery().Params.ParamByName('name').AsString := name;
         end;
         Self.getQuery().Open;

         listProduct := TList.Create;
         Self.getQuery().First;
         while not Self.getQuery().EOF do
         begin
              product := Self.get(Self.getQuery().FieldByName('id').AsInteger);
              listProduct.Add(product);
              Self.getQuery().Next;
         end;
         find := listProduct;

    end;


    function TDataProducto.findInStock(name:String):TList;
    var
       listProduct:TList;
       product:TProduct;
    begin

         Self.getQuery().SQL.Text := 'select product.id from product,balance where product.id = balance.product and balance.units > 0 ';
         if name <> '' then
         begin
            Self.getQuery().SQL.Text := Self.getQuery().SQL.Text + 'and name like :name';
            Self.getQuery().Params.ParamByName('name').AsString := name;
         end;
         Self.getQuery().Open;

         listProduct := TList.Create;
         Self.getQuery().First;
         while not Self.getQuery().EOF do
         begin
              product := Self.get(Self.getQuery().FieldByName('id').AsInteger);
              listProduct.Add(product);
              Self.getQuery().Next;
         end;
         findInStock := listProduct;

    end;


    function TDataProducto.new(product:TProduct):Integer;
    var
       dataBalance : TDataBalance;
    begin
         try


            Self.getQuery().SQL.Text := 'insert into product('+
                              '	name,'+
                              '	minstock,'+
                              '	maxstock)'+
                              ' values (:name,'+
                              ' :minstock,'+
                              '	:maxstock);';

            Self.getQuery().Params.ParamByName('name').AsString := product.getName();
            Self.getQuery().Params.ParamByName('minstock').AsInteger := product.getMinStock();
            Self.getQuery().Params.ParamByName('maxstock').AsInteger := product.getMaxStock();
            Self.getQuery().ExecSQL;
            Self.getQuery().SQL.Text:= 'SELECT last_insert_rowid() id';
            Self.getQuery().Open;
            while not Self.getQuery().EOF do
            begin
                 product.setId(Self.getQuery().FieldByName('id').AsInteger);
                 Self.getQuery().Next;
            end;
            dataBalance := TDataBalance.Create(Self.getConnection());
            product.getBalance().setId(dataBalance.new(product));
            new := product.getId();


         except
               new := 0;
         end;
    end;

    function TDataProducto.edit(product:TProduct):Boolean;
    begin
         try


            Self.getQuery().SQL.Text := 'update product '+
                              '   set name = :name,'+
                              '       minStock = :minStock,'+
                              '       maxStock = :maxStock'+
                              '  where id = :id';
            Self.getQuery().Params.ParamByName('name').AsString := product.getName();
            Self.getQuery().Params.ParamByName('minstock').AsInteger := product.getMinStock();
            Self.getQuery().Params.ParamByName('maxstock').AsInteger := product.getMaxStock();
            Self.getQuery().Params.ParamByName('id').AsInteger := product.getId();
            Self.getQuery().ExecSQL;

            edit := true;

         except
               edit := false;
         end;
    end;

    function TDataProducto.delete(product:TProduct):Boolean;
    begin
         try
            Self.getQuery().SQL.Text := 'delete from product where id =:id';
            Self.getQuery().Params.ParamByName('id').AsInteger := product.getId();
            Self.getQuery().ExecSQL;
            delete := true;
         except
               delete := false;
         end;
    end;

    function TDataProducto.get(id:Integer):TProduct;
    var
       product:TProduct;
       dataBalance : TDataBalance;
       query: TSQLQuery;
    begin
      try

         query := TSQLQuery.Create(nil);
         query.DataBase := self.getConnection();
         query.SQL.Text := 'select * from product where id = :id';
         query.Params.ParamByName('id').AsInteger := id;
         query.Open;

         dataBalance := TDataBalance.Create(Self.getConnection());
         query.First;

         while not query.EOF do
         begin
              product := TProduct.Create;
              product.setId(query.FieldByName('id').AsInteger);
              product.setName(query.FieldByName('name').AsString);
              product.setMaxstock(query.FieldByName('maxStock').AsInteger);
              product.setMinstock(query.FieldByName('minStock').AsInteger);
              product.setBalance(dataBalance.get(product.getId()));
              query.Next;
         end;
         query.close;
         get := product;
      except
         get := nil;
      end;
    end;

    function TDataProducto.getBalance(name:String):TList;
    var
       listProduct:TList;
       product:TProduct;
    begin

         Self.getQuery().SQL.Text := 'select product.id from product, balance where product.id = balance.product and units <> 0  ';
         if name <> '' then
         begin
            Self.getQuery().SQL.Text := Self.getQuery().SQL.Text + ' and name like :name';
            Self.getQuery().Params.ParamByName('name').AsString := name;
         end;
         Self.getQuery().Open;

         listProduct := TList.Create;
         Self.getQuery().First;
         while not Self.getQuery().EOF do
         begin
              product := Self.get(Self.getQuery().FieldByName('id').AsInteger);
              listProduct.Add(product);
              Self.getQuery().Next;
         end;
         getBalance := listProduct;
    end;

end.

