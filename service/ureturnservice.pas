unit UReturnService;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, UOperationType, UPerson, UItem, UProduct,
  UIn, UOut, UTransaction, UDataTransaction, UDataModule, UResourceString;

type

  { TProductQtyPair - helper record for aggregation }
  TProductQtyPair = class(TObject)
  private
    FProduct: TProduct;
    FQuantity: Integer;
  public
    constructor Create(aProduct: TProduct; aQuantity: Integer);
    property Product: TProduct read FProduct write FProduct;
    property Quantity: Integer read FQuantity write FQuantity;
  end;

  { TReturnService }

  TReturnService = class(TObject)
  private
    FLastError: String;
    function ValidateItems(items: TList): Boolean;
    function ValidatePerson(opType: TOperationType; person: TPerson): Boolean;
    function ValidateStock(items: TList): Boolean;
    function AggregateQuantitiesByProduct(items: TList): TList;
  public
    function SaveReturn(opType: TOperationType; person: TPerson;
      date: TDateTime; items: TList): Boolean;
    function GetLastError: String;
  end;

implementation

{ TProductQtyPair }

constructor TProductQtyPair.Create(aProduct: TProduct; aQuantity: Integer);
begin
  inherited Create;
  FProduct := aProduct;
  FQuantity := aQuantity;
end;

{ TReturnService }

function TReturnService.ValidateItems(items: TList): Boolean;
var
  i: Integer;
  item: TItem;
begin
  Result := False;
  if (items = nil) or (items.Count = 0) then
  begin
    FLastError := RS_RETURNS_NO_ITEMS;
    Exit;
  end;

  for i := 0 to items.Count - 1 do
  begin
    item := TItem(items[i]);
    if (item.getProduct() <> nil) and (item.getStock() >= 1) then
    begin
      Result := True;
      Exit;
    end;
  end;

  FLastError := RS_RETURNS_NO_ITEMS;
end;

function TReturnService.ValidatePerson(opType: TOperationType; person: TPerson): Boolean;
begin
  Result := True;

  if opType.getName() = 'Customer Devolution' then
  begin
    if person = nil then
    begin
      FLastError := RS_RETURNS_NO_CUSTOMER;
      Result := False;
    end;
  end
  else if opType.getName() = 'Return to Provider' then
  begin
    if person = nil then
    begin
      FLastError := RS_RETURNS_NO_SUPPLIER;
      Result := False;
    end;
  end;
  { Inventory Loss does not require a person }
end;

function TReturnService.AggregateQuantitiesByProduct(items: TList): TList;
var
  i, j: Integer;
  item: TItem;
  pair: TProductQtyPair;
  found: Boolean;
begin
  Result := TList.Create;

  for i := 0 to items.Count - 1 do
  begin
    item := TItem(items[i]);
    if (item.getProduct() = nil) or (item.getStock() < 1) then
      Continue;

    found := False;
    for j := 0 to Result.Count - 1 do
    begin
      pair := TProductQtyPair(Result[j]);
      if pair.Product.getId() = item.getProduct().getId() then
      begin
        pair.Quantity := pair.Quantity + item.getStock();
        found := True;
        Break;
      end;
    end;

    if not found then
    begin
      pair := TProductQtyPair.Create(item.getProduct(), item.getStock());
      Result.Add(pair);
    end;
  end;
end;

function TReturnService.ValidateStock(items: TList): Boolean;
var
  aggregated: TList;
  i: Integer;
  pair: TProductQtyPair;
  errors: String;
begin
  Result := True;
  errors := '';

  aggregated := AggregateQuantitiesByProduct(items);
  try
    for i := 0 to aggregated.Count - 1 do
    begin
      pair := TProductQtyPair(aggregated[i]);
      if pair.Quantity > pair.Product.getBalance().getStock() then
      begin
        if errors <> '' then
          errors := errors + '; ';
        errors := errors + Format(RS_RETURNS_INSUFFICIENT_STOCK,
          [pair.Product.getName(), pair.Product.getBalance().getStock()]);
        Result := False;
      end;
    end;

    if not Result then
      FLastError := errors;
  finally
    for i := 0 to aggregated.Count - 1 do
      TProductQtyPair(aggregated[i]).Free;
    aggregated.Free;
  end;
end;

function TReturnService.SaveReturn(opType: TOperationType; person: TPerson;
  date: TDateTime; items: TList): Boolean;
var
  transaction: TTransaction;
  dataTransaction: TDataTransaction;
  dummyPerson: TPerson;
begin
  Result := False;
  FLastError := '';

  { Step 1: Validate items }
  if not ValidateItems(items) then
    Exit;

  { Step 2: Validate person }
  if not ValidatePerson(opType, person) then
    Exit;

  { Step 3: Validate stock for "out" operations }
  if opType.getTyp() = 'out' then
  begin
    if not ValidateStock(items) then
      Exit;
  end;

  { Step 4: Construct TIn or TOut based on operation type direction }
  if opType.getTyp() = 'in' then
    transaction := TIn.Create
  else
    transaction := TOut.Create;

  transaction.setOperationType(opType);
  transaction.setDate(date);
  transaction.setItemList(items);

  { Handle person: if nil (Inventory Loss), create a dummy person with id 0 }
  if person <> nil then
    transaction.setPerson(person)
  else
  begin
    dummyPerson := TPerson.Create;
    dummyPerson.setId(0);
    dummyPerson.setName('');
    transaction.setPerson(dummyPerson);
  end;

  transaction.setCredit(0);

  { Step 5: Calculate new balance }
  if opType.getTyp() = 'in' then
    TIn(transaction).calculateNewBalance()
  else
    TOut(transaction).calculateNewBalance();

  { Step 6: Persist via DB transaction }
  DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
  DataModule1.SQLite3Connection1.Transaction.DataBase := DataModule1.SQLite3Connection1;
  dataTransaction := TDataTransaction.Create(DataModule1.SQLite3Connection1);
  dataTransaction.getTransaction().StartTransaction;
  try
    if dataTransaction.new(transaction) > 0 then
    begin
      dataTransaction.getTransaction().Commit;
      Result := True;
    end
    else
    begin
      dataTransaction.getTransaction().Rollback;
      FLastError := RS_RETURNS_SAVE_ERROR;
    end;
  except
    on E: Exception do
    begin
      dataTransaction.getTransaction().Rollback;
      FLastError := RS_RETURNS_SAVE_ERROR;
    end;
  end;
  DataModule1.SQLite3Connection1.Transaction.Free;
  DataModule1.SQLite3Connection1.Transaction := nil;
  dataTransaction.Free;
end;

function TReturnService.GetLastError: String;
begin
  Result := FLastError;
end;

end.
