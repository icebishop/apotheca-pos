{ Feature: modern-sales-ui, Property 6: Purchase creates correct operation type and updates balance }
{
  Property-based test for purchase balance update logic.

  For any valid purchase with N items (random quantities and costs),
  saving shall:
    - Create an operation with type = 1 ('in')
    - For each item, increment the product's balance stock by the item's quantity
    - Recalculate the weighted average cost as new_balance / new_stock

  This test exercises the pure mathematical logic of TIn.calculateNewBalance
  without requiring database access.

  **Validates: Requirements 3.7, 8.2, 8.3**
}
unit test_purchase_balance;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, Math,
  UPurchase, UItem, UProduct, UBalance, USupplier, UPerson;

type

  { TTestPurchaseBalance }

  TTestPurchaseBalance = class(TTestCase)
  private
    function RandomRange(AMin, AMax: Integer): Integer;
    function RandomFloat(AMin, AMax: Real): Real;
    function CreateProductWithBalance(InitialStock: Integer;
      InitialBalance, InitialCost, InitialPrice: Real): TProduct;
    function CreateItem(AProduct: TProduct; AQty: Integer;
      ACost, APrice: Real): TItem;
  published
    procedure Test_PurchaseOperationType;
    procedure Test_PurchaseBalanceStockIncrement;
    procedure Test_PurchaseWeightedAverageCost;
    procedure Test_PurchaseBalanceUpdateCombined;
  end;

implementation

const
  ITERATIONS = 100;
  EPSILON = 0.0001;

{ Helper: generate random integer in [AMin..AMax] }
function TTestPurchaseBalance.RandomRange(AMin, AMax: Integer): Integer;
begin
  Result := AMin + Random(AMax - AMin + 1);
end;

{ Helper: generate random float in [AMin..AMax] }
function TTestPurchaseBalance.RandomFloat(AMin, AMax: Real): Real;
begin
  Result := AMin + Random * (AMax - AMin);
end;

{ Helper: create a TProduct with a pre-configured TBalance }
function TTestPurchaseBalance.CreateProductWithBalance(InitialStock: Integer;
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
function TTestPurchaseBalance.CreateItem(AProduct: TProduct; AQty: Integer;
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

{ Test that TPurchase always has operation type = 1 ('in') }
procedure TTestPurchaseBalance.Test_PurchaseOperationType;
var
  iter: Integer;
  purchase: TPurchase;
begin
  for iter := 1 to ITERATIONS do
  begin
    purchase := TPurchase.Create;
    try
      AssertEquals(
        Format('Iter %d: Purchase operation type id must be 1', [iter]),
        1, purchase.getOperationType().getId());
    finally
      purchase.getOperationType().Free;
      purchase.Free;
    end;
  end;
end;

{ Test that after calculateNewBalance, each product's balance stock is
  incremented by the item's quantity }
procedure TTestPurchaseBalance.Test_PurchaseBalanceStockIncrement;
var
  iter, i, itemCount: Integer;
  purchase: TPurchase;
  product: TProduct;
  item: TItem;
  itemList: TList;
  initialStocks: array of Integer;
  quantities: array of Integer;
  initialStock, qty: Integer;
  cost, price: Real;
begin
  for iter := 1 to ITERATIONS do
  begin
    purchase := TPurchase.Create;
    itemList := TList.Create;
    purchase.setItemList(itemList);

    itemCount := RandomRange(1, 8);
    SetLength(initialStocks, itemCount);
    SetLength(quantities, itemCount);

    { Generate random items with distinct products }
    for i := 0 to itemCount - 1 do
    begin
      initialStock := RandomRange(0, 100);
      qty := RandomRange(1, 50);
      cost := RandomFloat(0.01, 500.0);
      price := RandomFloat(cost, cost * 2.0);

      product := CreateProductWithBalance(initialStock,
        initialStock * RandomFloat(0.5, 10.0),
        RandomFloat(0.01, 500.0),
        RandomFloat(0.01, 1000.0));
      item := CreateItem(product, qty, cost, price);
      itemList.Add(item);

      initialStocks[i] := initialStock;
      quantities[i] := qty;
    end;

    { Execute the balance calculation }
    purchase.calculateNewBalance();

    { Assert: each product's stock is incremented by item qty }
    for i := 0 to itemCount - 1 do
    begin
      item := TItem(itemList[i]);
      AssertEquals(
        Format('Iter %d, Item %d: balance stock must equal initial + qty', [iter, i]),
        initialStocks[i] + quantities[i],
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
    purchase.getOperationType().Free;
    purchase.Free;
  end;
end;

{ Test that after calculateNewBalance, weighted average cost =
  new_balance / new_stock for each product }
procedure TTestPurchaseBalance.Test_PurchaseWeightedAverageCost;
var
  iter, i, itemCount: Integer;
  purchase: TPurchase;
  product: TProduct;
  item: TItem;
  itemList: TList;
  initialStock, qty: Integer;
  initialBalance, cost, price: Real;
  expectedBalance, expectedCost: Real;
  newStock: Integer;
begin
  for iter := 1 to ITERATIONS do
  begin
    purchase := TPurchase.Create;
    itemList := TList.Create;
    purchase.setItemList(itemList);

    itemCount := RandomRange(1, 8);

    { Generate random items with distinct products }
    for i := 0 to itemCount - 1 do
    begin
      initialStock := RandomRange(0, 100);
      qty := RandomRange(1, 50);
      cost := RandomFloat(0.01, 500.0);
      price := RandomFloat(cost, cost * 2.0);
      { Set initial balance = initialStock * some cost so it's realistic }
      initialBalance := initialStock * RandomFloat(0.5, 10.0);

      product := CreateProductWithBalance(initialStock, initialBalance,
        RandomFloat(0.01, 500.0), RandomFloat(0.01, 1000.0));
      item := CreateItem(product, qty, cost, price);
      itemList.Add(item);
    end;

    { Execute the balance calculation }
    purchase.calculateNewBalance();

    { Assert: weighted average cost = new_balance / new_stock }
    for i := 0 to itemCount - 1 do
    begin
      item := TItem(itemList[i]);
      product := item.getProduct();
      newStock := product.getBalance().getStock();

      if newStock > 0 then
      begin
        expectedCost := product.getBalance().getBalance() / newStock;
        AssertTrue(
          Format('Iter %d, Item %d: cost (%f) must equal balance/stock (%f)',
            [iter, i, product.getBalance().getCost(), expectedCost]),
          Abs(product.getBalance().getCost() - expectedCost) < EPSILON);
      end;
    end;

    { Cleanup }
    for i := 0 to itemList.Count - 1 do
    begin
      item := TItem(itemList[i]);
      item.getProduct().Free;
      item.Free;
    end;
    itemList.Free;
    purchase.getOperationType().Free;
    purchase.Free;
  end;
end;

{ Combined property test: full purchase balance update
  Tests all three properties together:
  - Operation type = 1
  - Stock incremented by qty
  - Weighted avg cost = balance / stock }
procedure TTestPurchaseBalance.Test_PurchaseBalanceUpdateCombined;
var
  iter, i, itemCount: Integer;
  purchase: TPurchase;
  product: TProduct;
  item: TItem;
  itemList: TList;
  initialStock, qty: Integer;
  initialBalance, cost, price: Real;
  expectedBalance, expectedCost: Real;
  newStock: Integer;
  initialStocks: array of Integer;
  initialBalances: array of Real;
  quantities: array of Integer;
  costs: array of Real;
begin
  for iter := 1 to ITERATIONS do
  begin
    purchase := TPurchase.Create;
    itemList := TList.Create;
    purchase.setItemList(itemList);

    { Verify operation type = 1 }
    AssertEquals(
      Format('Iter %d: operation type must be 1', [iter]),
      1, purchase.getOperationType().getId());

    itemCount := RandomRange(1, 10);
    SetLength(initialStocks, itemCount);
    SetLength(initialBalances, itemCount);
    SetLength(quantities, itemCount);
    SetLength(costs, itemCount);

    { Generate random items }
    for i := 0 to itemCount - 1 do
    begin
      initialStock := RandomRange(0, 200);
      qty := RandomRange(1, 50);
      cost := RandomFloat(0.01, 999.99);
      price := RandomFloat(cost, cost * 3.0);
      initialBalance := initialStock * RandomFloat(0.5, 20.0);

      product := CreateProductWithBalance(initialStock, initialBalance,
        RandomFloat(0.01, 999.99), RandomFloat(0.01, 999.99));
      item := CreateItem(product, qty, cost, price);
      itemList.Add(item);

      initialStocks[i] := initialStock;
      initialBalances[i] := initialBalance;
      quantities[i] := qty;
      costs[i] := cost;
    end;

    { Execute the balance calculation }
    purchase.calculateNewBalance();

    { Assert all properties for each item }
    for i := 0 to itemCount - 1 do
    begin
      item := TItem(itemList[i]);
      product := item.getProduct();

      { Property: stock incremented by qty }
      AssertEquals(
        Format('Iter %d, Item %d: stock = initial + qty', [iter, i]),
        initialStocks[i] + quantities[i],
        product.getBalance().getStock());

      { Property: new balance = old balance + (cost * qty) }
      expectedBalance := initialBalances[i] + (costs[i] * quantities[i]);
      AssertTrue(
        Format('Iter %d, Item %d: balance (%f) must equal expected (%f)',
          [iter, i, product.getBalance().getBalance(), expectedBalance]),
        Abs(product.getBalance().getBalance() - expectedBalance) < EPSILON);

      { Property: weighted avg cost = new_balance / new_stock }
      newStock := product.getBalance().getStock();
      if newStock > 0 then
      begin
        expectedCost := expectedBalance / newStock;
        AssertTrue(
          Format('Iter %d, Item %d: cost (%f) must equal balance/stock (%f)',
            [iter, i, product.getBalance().getCost(), expectedCost]),
          Abs(product.getBalance().getCost() - expectedCost) < EPSILON);
      end;

      { Property: price is updated to item price }
      AssertTrue(
        Format('Iter %d, Item %d: price must be updated to item price', [iter, i]),
        Abs(product.getBalance().getPrice() - item.getPrice()) < EPSILON);
    end;

    { Cleanup }
    for i := 0 to itemList.Count - 1 do
    begin
      item := TItem(itemList[i]);
      item.getProduct().Free;
      item.Free;
    end;
    itemList.Free;
    purchase.getOperationType().Free;
    purchase.Free;
  end;
end;

initialization
  Randomize;
  RegisterTest(TTestPurchaseBalance);

end.
