{ Feature: modern-sales-ui, Property 9: Balance invariant after sequence of operations }
{
  Property-based test for balance invariant after combined purchase/sale sequences.

  For any product with an initial balance of zero and any sequence of N purchases
  (IN) followed by M sales (OUT) where total sold <= total purchased, the final
  balance stock shall equal sum(purchase_quantities) - sum(sale_quantities) and
  the final balance value shall be non-negative.

  This test exercises the pure mathematical logic of TIn.calculateNewBalance and
  TOut.calculateNewBalance without requiring database access.

  **Validates: Requirements 2.13, 3.7, 8.3**
}
unit test_balance_invariant;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, Math,
  UPurchase, USale, UItem, UProduct, UBalance, USupplier, UCustomer, UPerson;

type

  { TTestBalanceInvariant }

  TTestBalanceInvariant = class(TTestCase)
  private
    function RandomRange(AMin, AMax: Integer): Integer;
    function RandomFloat(AMin, AMax: Real): Real;
    function CreateProduct: TProduct;
    function CreatePurchaseItem(AProduct: TProduct; AQty: Integer;
      ACost, APrice: Real): TItem;
    function CreateSaleItem(AProduct: TProduct; AQty: Integer): TItem;
  published
    procedure Test_BalanceInvariantAfterOperationSequences;
  end;

implementation

const
  ITERATIONS = 100;
  EPSILON = 0.0001;

{ Helper: generate random integer in [AMin..AMax] }
function TTestBalanceInvariant.RandomRange(AMin, AMax: Integer): Integer;
begin
  Result := AMin + Random(AMax - AMin + 1);
end;

{ Helper: generate random float in [AMin..AMax] }
function TTestBalanceInvariant.RandomFloat(AMin, AMax: Real): Real;
begin
  Result := AMin + Random * (AMax - AMin);
end;

{ Helper: create a TProduct with zero initial balance }
function TTestBalanceInvariant.CreateProduct: TProduct;
var
  product: TProduct;
begin
  product := TProduct.Create;
  product.setId(RandomRange(1, 9999));
  product.setName('TestProduct_' + IntToStr(Random(10000)));
  product.setMinstock(0);
  product.setMaxstock(999);
  { Start with zero balance }
  product.getBalance().setStock(0);
  product.getBalance().setBalance(0.0);
  product.getBalance().setCost(0.0);
  product.getBalance().setPrice(0.0);
  Result := product;
end;

{ Helper: create a purchase item referencing the shared product }
function TTestBalanceInvariant.CreatePurchaseItem(AProduct: TProduct;
  AQty: Integer; ACost, APrice: Real): TItem;
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

{ Helper: create a sale item referencing the shared product }
function TTestBalanceInvariant.CreateSaleItem(AProduct: TProduct;
  AQty: Integer): TItem;
var
  item: TItem;
begin
  item := TItem.Create;
  item.setProduct(AProduct);
  item.setStock(AQty);
  { Price/cost not needed for sale balance calc, but set them anyway }
  item.setPrice(AProduct.getBalance().getPrice());
  item.setCost(AProduct.getBalance().getCost());
  Result := item;
end;

{ Property 9: Balance invariant after sequence of operations
  - Start with a product at zero balance
  - Apply N purchases (each calls TIn.calculateNewBalance logic)
  - Apply M sales (each calls TOut.calculateNewBalance logic)
  - Assert: final stock = sum(purchase_qty) - sum(sale_qty)
  - Assert: final balance value >= 0 }
procedure TTestBalanceInvariant.Test_BalanceInvariantAfterOperationSequences;
var
  iter, i: Integer;
  numPurchases, numSales: Integer;
  product: TProduct;
  purchase: TPurchase;
  sale: TSale;
  purchaseItemList, saleItemList: TList;
  item: TItem;
  qty: Integer;
  cost, price: Real;
  totalPurchased, totalSold: Integer;
  expectedStock: Integer;
  remainingSellable: Integer;
begin
  for iter := 1 to ITERATIONS do
  begin
    { Create a product starting at zero balance }
    product := CreateProduct;
    totalPurchased := 0;
    totalSold := 0;

    { Generate N purchases (1..5 purchase operations) }
    numPurchases := RandomRange(1, 5);
    for i := 1 to numPurchases do
    begin
      purchase := TPurchase.Create;
      purchaseItemList := TList.Create;
      purchase.setItemList(purchaseItemList);

      { Each purchase has 1 item for our shared product }
      qty := RandomRange(1, 50);
      cost := RandomFloat(0.01, 500.0);
      price := RandomFloat(cost, cost * 2.0);

      item := CreatePurchaseItem(product, qty, cost, price);
      purchaseItemList.Add(item);

      { Execute purchase balance calculation (TIn.calculateNewBalance) }
      purchase.calculateNewBalance();

      totalPurchased := totalPurchased + qty;

      { Cleanup purchase (but not items or product - items reference shared product) }
      item.Free;
      purchaseItemList.Free;
      purchase.getOperationType().Free;
      purchase.Free;
    end;

    { Generate M sales (1..3 sale operations), ensuring total sold <= total purchased }
    numSales := RandomRange(1, 3);
    remainingSellable := totalPurchased;

    for i := 1 to numSales do
    begin
      if remainingSellable <= 0 then
        Break;

      sale := TSale.Create;
      saleItemList := TList.Create;
      sale.setItemList(saleItemList);

      { Each sale has 1 item for our shared product, qty <= remaining sellable }
      if remainingSellable = 1 then
        qty := 1
      else
        qty := RandomRange(1, remainingSellable);

      item := CreateSaleItem(product, qty);
      saleItemList.Add(item);

      { Execute sale balance calculation (TOut.calculateNewBalance) }
      sale.calculateNewBalance();

      totalSold := totalSold + qty;
      remainingSellable := remainingSellable - qty;

      { Cleanup sale }
      item.Free;
      saleItemList.Free;
      sale.getOperationType().Free;
      sale.Free;
    end;

    { Assert: final stock = sum(purchase_qty) - sum(sale_qty) }
    expectedStock := totalPurchased - totalSold;
    AssertEquals(
      Format('Iter %d: final stock must equal total purchased (%d) - total sold (%d)',
        [iter, totalPurchased, totalSold]),
      expectedStock,
      product.getBalance().getStock());

    { Assert: final balance value >= 0 }
    AssertTrue(
      Format('Iter %d: final balance value (%f) must be >= 0',
        [iter, product.getBalance().getBalance()]),
      product.getBalance().getBalance() >= -EPSILON);

    { Cleanup product }
    product.Free;
  end;
end;

initialization
  Randomize;
  RegisterTest(TTestBalanceInvariant);

end.
