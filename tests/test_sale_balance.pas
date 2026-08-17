{ Feature: modern-sales-ui, Property 5: Sale creates correct operation type and updates balance }
{
  Property-based test for sale balance update logic.

  For any valid sale with N items (random quantities <= available stock),
  saving shall:
    - Create an operation with type = 2 ('out')
    - For each item, decrement the product's balance stock by the item's quantity
    - Decrement the product's balance value by (balance.cost × item.stock)

  This test exercises the pure mathematical logic of TOut.calculateNewBalance
  without requiring database access.

  **Validates: Requirements 2.13, 8.2, 8.3**
}
unit test_sale_balance;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, Math,
  USale, UItem, UProduct, UBalance, UCustomer, UPerson, UOperationType;

type

  { TTestSaleBalance }

  TTestSaleBalance = class(TTestCase)
  private
    function RandomRange(AMin, AMax: Integer): Integer;
    function RandomFloat(AMin, AMax: Real): Real;
    function CreateProductWithBalance(InitialStock: Integer;
      InitialBalance, InitialCost, InitialPrice: Real): TProduct;
    function CreateItem(AProduct: TProduct; AQty: Integer;
      ACost, APrice: Real): TItem;
  published
    procedure Test_SaleOperationType;
    procedure Test_SaleBalanceStockDecrement;
    procedure Test_SaleBalanceValueDecrement;
    procedure Test_SaleBalanceUpdateCombined;
  end;

implementation

const
  ITERATIONS = 100;
  EPSILON = 0.0001;

{ Helper: generate random integer in [AMin..AMax] }
function TTestSaleBalance.RandomRange(AMin, AMax: Integer): Integer;
begin
  Result := AMin + Random(AMax - AMin + 1);
end;

{ Helper: generate random float in [AMin..AMax] }
function TTestSaleBalance.RandomFloat(AMin, AMax: Real): Real;
begin
  Result := AMin + Random * (AMax - AMin);
end;

{ Helper: create a TProduct with a pre-configured TBalance }
function TTestSaleBalance.CreateProductWithBalance(InitialStock: Integer;
  InitialBalance, InitialCost, InitialPrice: Real): TProduct;
var
  product: TProduct;
begin
  product := TProduct.Create;
  product.setId(RandomRange(1, 9999));
  product.setName('TestProduct_' + IntToStr(Random(10000)));
  product.setMinstock(0);
  product.setMaxstock(999);
  product.getBalance().setStock(InitialStock);
  product.getBalance().setBalance(InitialBalance);
  product.getBalance().setCost(InitialCost);
  product.getBalance().setPrice(InitialPrice);
  Result := product;
end;

{ Helper: create a TItem with a product, quantity, cost, and price }
function TTestSaleBalance.CreateItem(AProduct: TProduct; AQty: Integer;
  ACost, APrice: Real): TItem;
var
  item: TItem;
begin
  item := TItem.Create;
  item.setProduct(AProduct);
  item.setStock(AQty);
  item.setCost(ACost);
  item.setPrice(APrice);
  Result := item;
end;

{ Test that TSale always has operation type = 2 ('out') }
procedure TTestSaleBalance.Test_SaleOperationType;
var
  iter: Integer;
  sale: TSale;
begin
  for iter := 1 to ITERATIONS do
  begin
    sale := TSale.Create;
    try
      AssertEquals(
        Format('Iter %d: Sale operation type id must be 2', [iter]),
        2, sale.getOperationType().getId());
    finally
      sale.getOperationType().Free;
      sale.Free;
    end;
  end;
end;

{ Test that after calculateNewBalance, each product's balance stock is
  decremented by the item's quantity (item.stock) }
procedure TTestSaleBalance.Test_SaleBalanceStockDecrement;
var
  iter, i, itemCount: Integer;
  sale: TSale;
  product: TProduct;
  item: TItem;
  itemList: TList;
  initialStocks: array of Integer;
  quantities: array of Integer;
  initialStock, qty: Integer;
  cost, price, initialBalance, initialCost: Real;
begin
  for iter := 1 to ITERATIONS do
  begin
    sale := TSale.Create;
    itemList := TList.Create;
    sale.setItemList(itemList);

    itemCount := RandomRange(1, 8);
    SetLength(initialStocks, itemCount);
    SetLength(quantities, itemCount);

    { Generate random items with distinct products, ensuring stock >= qty }
    for i := 0 to itemCount - 1 do
    begin
      qty := RandomRange(1, 50);
      initialStock := RandomRange(qty, qty + 100); { ensure stock >= qty }
      initialCost := RandomFloat(0.01, 500.0);
      initialBalance := initialStock * initialCost;
      price := RandomFloat(initialCost, initialCost * 2.0);
      cost := initialCost;

      product := CreateProductWithBalance(initialStock, initialBalance,
        initialCost, price);
      item := CreateItem(product, qty, cost, price);
      itemList.Add(item);

      initialStocks[i] := initialStock;
      quantities[i] := qty;
    end;

    { Execute the balance calculation }
    sale.calculateNewBalance();

    { Assert: each product's stock is decremented by item qty }
    for i := 0 to itemCount - 1 do
    begin
      item := TItem(itemList[i]);
      AssertEquals(
        Format('Iter %d, Item %d: balance stock must equal initial - qty', [iter, i]),
        initialStocks[i] - quantities[i],
        item.getProduct().getBalance().getStock());
    end;

    { Cleanup }
    for i := 0 to itemList.Count - 1 do
    begin
      item := TItem(itemList[i]);
      item.getProduct().Free;
      item.Free;
    end;
    itemList.Free;
    sale.getOperationType().Free;
    sale.Free;
  end;
end;

{ Test that after calculateNewBalance, each product's balance value is
  decremented by (balance.cost × item.stock) }
procedure TTestSaleBalance.Test_SaleBalanceValueDecrement;
var
  iter, i, itemCount: Integer;
  sale: TSale;
  product: TProduct;
  item: TItem;
  itemList: TList;
  initialStocks: array of Integer;
  initialBalances: array of Real;
  initialCosts: array of Real;
  quantities: array of Integer;
  qty, initialStock: Integer;
  initialBalance, initialCost, price: Real;
  expectedBalance: Real;
begin
  for iter := 1 to ITERATIONS do
  begin
    sale := TSale.Create;
    itemList := TList.Create;
    sale.setItemList(itemList);

    itemCount := RandomRange(1, 8);
    SetLength(initialStocks, itemCount);
    SetLength(initialBalances, itemCount);
    SetLength(initialCosts, itemCount);
    SetLength(quantities, itemCount);

    { Generate random items with distinct products, ensuring stock >= qty }
    for i := 0 to itemCount - 1 do
    begin
      qty := RandomRange(1, 50);
      initialStock := RandomRange(qty, qty + 100);
      initialCost := RandomFloat(0.01, 500.0);
      initialBalance := initialStock * initialCost;
      price := RandomFloat(initialCost, initialCost * 2.0);

      product := CreateProductWithBalance(initialStock, initialBalance,
        initialCost, price);
      item := CreateItem(product, qty, initialCost, price);
      itemList.Add(item);

      initialStocks[i] := initialStock;
      initialBalances[i] := initialBalance;
      initialCosts[i] := initialCost;
      quantities[i] := qty;
    end;

    { Execute the balance calculation }
    sale.calculateNewBalance();

    { Assert: each product's balance value is decremented by (cost × qty) }
    for i := 0 to itemCount - 1 do
    begin
      item := TItem(itemList[i]);
      expectedBalance := initialBalances[i] - (initialCosts[i] * quantities[i]);
      AssertTrue(
        Format('Iter %d, Item %d: balance (%f) must equal expected (%f)',
          [iter, i, item.getProduct().getBalance().getBalance(), expectedBalance]),
        Abs(item.getProduct().getBalance().getBalance() - expectedBalance) < EPSILON);
    end;

    { Cleanup }
    for i := 0 to itemList.Count - 1 do
    begin
      item := TItem(itemList[i]);
      item.getProduct().Free;
      item.Free;
    end;
    itemList.Free;
    sale.getOperationType().Free;
    sale.Free;
  end;
end;

{ Combined property test: full sale balance update
  Tests all properties together:
  - Operation type = 2 ('out')
  - Stock decremented by qty
  - Balance value decremented by (balance.cost × item.stock) }
procedure TTestSaleBalance.Test_SaleBalanceUpdateCombined;
var
  iter, i, itemCount: Integer;
  sale: TSale;
  product: TProduct;
  item: TItem;
  itemList: TList;
  initialStock, qty: Integer;
  initialBalance, initialCost, price: Real;
  expectedBalance: Real;
  initialStocks: array of Integer;
  initialBalances: array of Real;
  initialCosts: array of Real;
  quantities: array of Integer;
begin
  for iter := 1 to ITERATIONS do
  begin
    sale := TSale.Create;
    itemList := TList.Create;
    sale.setItemList(itemList);

    { Verify operation type = 2 }
    AssertEquals(
      Format('Iter %d: operation type must be 2', [iter]),
      2, sale.getOperationType().getId());

    itemCount := RandomRange(1, 10);
    SetLength(initialStocks, itemCount);
    SetLength(initialBalances, itemCount);
    SetLength(initialCosts, itemCount);
    SetLength(quantities, itemCount);

    { Generate random items with distinct products }
    for i := 0 to itemCount - 1 do
    begin
      qty := RandomRange(1, 50);
      initialStock := RandomRange(qty, qty + 200); { ensure stock >= qty }
      initialCost := RandomFloat(0.01, 999.99);
      initialBalance := initialStock * initialCost;
      price := RandomFloat(initialCost, initialCost * 3.0);

      product := CreateProductWithBalance(initialStock, initialBalance,
        initialCost, price);
      item := CreateItem(product, qty, initialCost, price);
      itemList.Add(item);

      initialStocks[i] := initialStock;
      initialBalances[i] := initialBalance;
      initialCosts[i] := initialCost;
      quantities[i] := qty;
    end;

    { Execute the balance calculation }
    sale.calculateNewBalance();

    { Assert all properties for each item }
    for i := 0 to itemCount - 1 do
    begin
      item := TItem(itemList[i]);
      product := item.getProduct();

      { Property: stock decremented by qty }
      AssertEquals(
        Format('Iter %d, Item %d: stock = initial - qty', [iter, i]),
        initialStocks[i] - quantities[i],
        product.getBalance().getStock());

      { Property: balance value = old balance - (cost * qty) }
      expectedBalance := initialBalances[i] - (initialCosts[i] * quantities[i]);
      AssertTrue(
        Format('Iter %d, Item %d: balance (%f) must equal expected (%f)',
          [iter, i, product.getBalance().getBalance(), expectedBalance]),
        Abs(product.getBalance().getBalance() - expectedBalance) < EPSILON);
    end;

    { Cleanup }
    for i := 0 to itemList.Count - 1 do
    begin
      item := TItem(itemList[i]);
      item.getProduct().Free;
      item.Free;
    end;
    itemList.Free;
    sale.getOperationType().Free;
    sale.Free;
  end;
end;

initialization
  Randomize;
  RegisterTest(TTestSaleBalance);

end.
