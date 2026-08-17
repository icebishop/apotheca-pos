unit test_cart_removal;

{ Feature: modern-sales-ui, Property 4: Cart removal preserves totals }
{ Validates: Requirements 2.8 }
{
  Property 4: Cart removal preserves totals
  For any cart with N >= 2 items, removing the item at index i shall result
  in a cart with N-1 items and a grand total equal to the previous grand
  total minus the removed item's line total.
}

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry, UCartService, UProduct, UBalance;

type
  TTestCartRemoval = class(TTestCase)
  private
    function CreateProductWithPrice(id: Integer; price, cost: Real): TProduct;
    procedure PopulateCartWithRandomItems(cart: TCartService;
      itemCount: Integer; out products: TList);
    procedure FreeProducts(products: TList);
  published
    procedure TestCartRemovalPreservesTotals;
  end;

implementation

const
  ITERATIONS = 150;
  MAX_ITEMS = 10;
  MIN_ITEMS = 2;
  MAX_PRICE = 999.99;
  MIN_PRICE = 0.01;
  MAX_COST = 500.00;
  MIN_COST = 0.01;
  MAX_QTY = 50;

function TTestCartRemoval.CreateProductWithPrice(id: Integer; price, cost: Real): TProduct;
var
  balance: TBalance;
begin
  Result := TProduct.Create;
  Result.setId(id);
  Result.setName('Product_' + IntToStr(id));
  Result.setMinstock(0);
  Result.setMaxstock(100);
  balance := Result.getBalance();
  balance.setPrice(price);
  balance.setCost(cost);
  balance.setStock(1000);
end;

procedure TTestCartRemoval.PopulateCartWithRandomItems(cart: TCartService;
  itemCount: Integer; out products: TList);
var
  i, qty: Integer;
  product: TProduct;
  price, cost: Real;
begin
  products := TList.Create;
  for i := 1 to itemCount do
  begin
    price := MIN_PRICE + Random * (MAX_PRICE - MIN_PRICE);
    cost := MIN_COST + Random * (MAX_COST - MIN_COST);
    product := CreateProductWithPrice(i * 1000 + Random(9999), price, cost);
    products.Add(product);

    { Add product to cart (creates item with qty=1) }
    cart.AddProduct(product);

    { Optionally increase quantity by adding multiple times }
    qty := 1 + Random(MAX_QTY - 1);  { qty in range [1..MAX_QTY] }
    if qty > 1 then
      cart.SetQuantity(i - 1, qty);
  end;
end;

procedure TTestCartRemoval.FreeProducts(products: TList);
var
  i: Integer;
begin
  if products = nil then Exit;
  for i := 0 to products.Count - 1 do
    TProduct(products[i]).Free;
  products.Free;
end;

procedure TTestCartRemoval.TestCartRemovalPreservesTotals;
{ Property 4: Cart removal preserves totals
  Generate random cart with N >= 2 items, pick random index,
  record old grand total and line total at index.
  Remove item at index, assert new grand total = old grand total - removed
  line total, item count = N-1. }
var
  iteration, itemCount, removeIndex: Integer;
  cart: TCartService;
  products: TList;
  oldGrandTotal, removedLineTotal, newGrandTotal, expectedTotal: Real;
  oldItemCount: Integer;
begin
  Randomize;

  for iteration := 1 to ITERATIONS do
  begin
    cart := TCartService.Create;
    products := nil;
    try
      { Generate random cart with N >= 2 items }
      itemCount := MIN_ITEMS + Random(MAX_ITEMS - MIN_ITEMS + 1);

      PopulateCartWithRandomItems(cart, itemCount, products);

      { Verify cart was populated correctly }
      AssertEquals(
        Format('Iteration %d: cart should have %d items', [iteration, itemCount]),
        itemCount, cart.GetItemCount);

      { Pick random index to remove }
      removeIndex := Random(itemCount);

      { Record old grand total and line total at index }
      oldGrandTotal := cart.GetGrandTotal;
      removedLineTotal := cart.GetLineTotal(removeIndex);
      oldItemCount := cart.GetItemCount;

      { Remove item at index }
      cart.RemoveItem(removeIndex);

      { Assert new item count = N - 1 }
      AssertEquals(
        Format('Iteration %d: after removal, item count should be N-1', [iteration]),
        oldItemCount - 1, cart.GetItemCount);

      { Assert new grand total = old grand total - removed line total }
      newGrandTotal := cart.GetGrandTotal;
      expectedTotal := oldGrandTotal - removedLineTotal;

      { Use a small epsilon for floating-point comparison }
      AssertTrue(
        Format('Iteration %d: grand total mismatch. Expected=%.4f Got=%.4f ' +
               '(old=%.4f removed=%.4f removeIdx=%d N=%d)',
               [iteration, expectedTotal, newGrandTotal,
                oldGrandTotal, removedLineTotal, removeIndex, itemCount]),
        Abs(newGrandTotal - expectedTotal) < 0.001);

    finally
      cart.Free;
      FreeProducts(products);
    end;
  end;
end;

initialization
  RegisterTest(TTestCartRemoval);

end.
