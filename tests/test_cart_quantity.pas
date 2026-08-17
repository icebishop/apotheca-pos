program test_cart_quantity;

{$mode objfpc}{$H+}

{ Feature: modern-sales-ui, Property 2: Cart quantity accumulation }
{ Validates: Requirements 2.3, 2.5 }
{
  Property 2: Cart quantity accumulation
  For any product P added to the cart K times (K >= 1), the cart shall contain
  exactly one line item for product P with quantity equal to K.

  This test uses a lightweight random-generator harness with 100+ iterations
  to verify the property across randomized inputs.
}

uses
  Classes, SysUtils, UProduct, UBalance, UItem, UCartService;

var
  PassedCount: Integer = 0;
  FailedCount: Integer = 0;
  Iteration: Integer;
  K: Integer;
  ProductId: Integer;
  ProductName: String;
  Price: Real;
  Cost: Real;
  Product: TProduct;
  Balance: TBalance;
  Cart: TCartService;
  Item: TItem;
  i: Integer;

const
  NUM_ITERATIONS = 150;
  MAX_K = 50;

  function RandomString(Len: Integer): String;
  var
    j: Integer;
  begin
    Result := '';
    for j := 1 to Len do
      Result := Result + Chr(Ord('A') + Random(26));
  end;

begin
  Randomize;
  WriteLn('=== Property 2: Cart quantity accumulation ===');
  WriteLn('Iterations: ', NUM_ITERATIONS);
  WriteLn('');

  for Iteration := 1 to NUM_ITERATIONS do
  begin
    { Generate random product parameters }
    ProductId := Random(100000) + 1;
    ProductName := RandomString(5 + Random(16)); { 5..20 chars }
    Price := (Random(99999) + 1) / 100.0;       { 0.01..999.99 }
    Cost := (Random(99999) + 1) / 100.0;        { 0.01..999.99 }
    K := Random(MAX_K) + 1;                      { 1..50 }

    { Create product with balance }
    Product := TProduct.Create;
    Product.setId(ProductId);
    Product.setName(ProductName);
    Product.setMinstock(0);
    Product.setMaxstock(100);

    Balance := Product.getBalance();
    Balance.setPrice(Price);
    Balance.setCost(Cost);
    Balance.setStock(1000); { Plenty of stock available }

    { Create cart and add product K times }
    Cart := TCartService.Create;
    try
      for i := 1 to K do
        Cart.AddProduct(Product);

      { Assert: cart has exactly 1 line item }
      if Cart.GetItemCount <> 1 then
      begin
        Inc(FailedCount);
        WriteLn('[FAIL] Iteration ', Iteration,
                ': Expected 1 item in cart, got ', Cart.GetItemCount,
                ' (ProductId=', ProductId, ', K=', K, ')');
        Continue;
      end;

      { Assert: the single line item has quantity = K }
      Item := Cart.GetItem(0);
      if Item = nil then
      begin
        Inc(FailedCount);
        WriteLn('[FAIL] Iteration ', Iteration,
                ': GetItem(0) returned nil',
                ' (ProductId=', ProductId, ', K=', K, ')');
        Continue;
      end;

      if Item.getStock() <> K then
      begin
        Inc(FailedCount);
        WriteLn('[FAIL] Iteration ', Iteration,
                ': Expected qty=', K, ' got qty=', Item.getStock(),
                ' (ProductId=', ProductId, ', K=', K, ')');
        Continue;
      end;

      { Assert: the item references the correct product }
      if (Item.getProduct() = nil) or (Item.getProduct().getId() <> ProductId) then
      begin
        Inc(FailedCount);
        WriteLn('[FAIL] Iteration ', Iteration,
                ': Product ID mismatch',
                ' (expected=', ProductId, ')');
        Continue;
      end;

      Inc(PassedCount);
    finally
      Cart.Free;
      Product.Free;
    end;
  end;

  WriteLn('');
  WriteLn('--- Results ---');
  WriteLn('Passed: ', PassedCount, '/', NUM_ITERATIONS);
  WriteLn('Failed: ', FailedCount, '/', NUM_ITERATIONS);
  WriteLn('');

  if FailedCount = 0 then
  begin
    WriteLn('[OK] Property 2 holds: Cart quantity accumulation verified.');
    Halt(0);
  end
  else
  begin
    WriteLn('[FAILED] Property 2 violated in ', FailedCount, ' iteration(s).');
    Halt(1);
  end;
end.
