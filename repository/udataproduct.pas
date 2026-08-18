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
                              '	maxstock,'+
                              '	image_ref,'+
                              '	originalprice,'+
                              '	isservice,'+
                              '	category,'+
                              '	description,'+
                              '	brand,'+
                              '	condition,'+
                              '	google_product_category)'+
                              ' values (:name,'+
                              ' :minstock,'+
                              '	:maxstock,'+
                              ' :image_ref,'+
                              ' :originalprice,'+
                              ' :isservice,'+
                              ' :category,'+
                              ' :description,'+
                              ' :brand,'+
                              ' :condition,'+
                              ' :google_product_category);';

            Self.getQuery().Params.ParamByName('name').AsString := product.getName();
            Self.getQuery().Params.ParamByName('minstock').AsInteger := product.getMinStock();
            Self.getQuery().Params.ParamByName('maxstock').AsInteger := product.getMaxStock();
            Self.getQuery().Params.ParamByName('image_ref').AsInteger := product.getImageRef();
            Self.getQuery().Params.ParamByName('originalprice').AsFloat := product.getOriginalPrice();
            Self.getQuery().Params.ParamByName('isservice').AsInteger := Ord(product.getIsService());
            Self.getQuery().Params.ParamByName('category').AsString := product.getCategory();
            Self.getQuery().Params.ParamByName('description').AsString := product.getDescription();
            Self.getQuery().Params.ParamByName('brand').AsString := product.getBrand();
            Self.getQuery().Params.ParamByName('condition').AsString := product.getProductCondition();
            Self.getQuery().Params.ParamByName('google_product_category').AsString := product.getGoogleProductCategory();
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
                              '       maxStock = :maxStock,'+
                              '       image_ref = :image_ref,'+
                              '       originalprice = :originalprice,'+
                              '       isservice = :isservice,'+
                              '       category = :category,'+
                              '       description = :description,'+
                              '       brand = :brand,'+
                              '       condition = :condition,'+
                              '       google_product_category = :google_product_category'+
                              '  where id = :id';
            Self.getQuery().Params.ParamByName('name').AsString := product.getName();
            Self.getQuery().Params.ParamByName('minstock').AsInteger := product.getMinStock();
            Self.getQuery().Params.ParamByName('maxstock').AsInteger := product.getMaxStock();
            Self.getQuery().Params.ParamByName('image_ref').AsInteger := product.getImageRef();
            Self.getQuery().Params.ParamByName('originalprice').AsFloat := product.getOriginalPrice();
            Self.getQuery().Params.ParamByName('isservice').AsInteger := Ord(product.getIsService());
            Self.getQuery().Params.ParamByName('category').AsString := product.getCategory();
            Self.getQuery().Params.ParamByName('description').AsString := product.getDescription();
            Self.getQuery().Params.ParamByName('brand').AsString := product.getBrand();
            Self.getQuery().Params.ParamByName('condition').AsString := product.getProductCondition();
            Self.getQuery().Params.ParamByName('google_product_category').AsString := product.getGoogleProductCategory();
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
              if not query.FieldByName('image_ref').IsNull then
                 product.setImageRef(query.FieldByName('image_ref').AsInteger)
              else
                 product.setImageRef(0);
              if not query.FieldByName('originalprice').IsNull then
                 product.setOriginalPrice(query.FieldByName('originalprice').AsFloat)
              else
                 product.setOriginalPrice(0.0);
              if (not query.FieldByName('isservice').IsNull) and
                 (query.FieldByName('isservice').AsInteger = 1) then
                 product.setIsService(True)
              else
                 product.setIsService(False);
              if not query.FieldByName('category').IsNull then
                 product.setCategory(query.FieldByName('category').AsString);
              if not query.FieldByName('description').IsNull then
                 product.setDescription(query.FieldByName('description').AsString);
              if not query.FieldByName('brand').IsNull then
                 product.setBrand(query.FieldByName('brand').AsString);
              if not query.FieldByName('condition').IsNull then
                 product.setProductCondition(query.FieldByName('condition').AsString);
              if not query.FieldByName('google_product_category').IsNull then
                 product.setGoogleProductCategory(query.FieldByName('google_product_category').AsString);
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

