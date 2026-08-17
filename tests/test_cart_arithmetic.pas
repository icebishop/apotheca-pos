program test_cart_arithmetic;

{$mode objfpc}{$H+}

{ Feature: modern-sales-ui, Property 3: Cart arithmetic invariant }
{ Validates: Requirements 2.4, 2.6, 2.7 }
{
  Property 3: Cart arithmetic invariant
  For any cart containing N items with arbitrary prices and quantities,
  each line total shall equal quantity × unit_price for that item,
  and the grand total shall equal the sum of all line totals.

  This test uses a lightweight random-generator harness with 150 iterations
  to verify the property across randomized inputs.
}

uses
  Classes, SysUtils, Math, UProduct, UBalance, UItem, UCartService;

var
  PassedCount: Integer = 0;
  FailedCount: Integer = 0;
  Iteration: Integer;
  N: Integer;           { number of items in cart (1..10) }
  i: Integer;
  Qty: Integer;
  Price: Real;
  Balance: TBalance;
  Cart: TCartService;
  Item: TItem;
  Products: array of TProduct;
  Prices: array of Real;
  Quantities: array of Integer;
  ExpectedLineTotal: Real;
  ActualLineTotal: Real;
  ExpectedGrandTotal: Real;
  ActualGrandTotal: Real;
  LineFailed: Boolean;

const
  NUM_ITERATIONS = 150;
  PRICE_MIN = 0.01;
  PRICE_MAX = 999.99;
  QTY_MIN = 1;
  QTY_MAX = 50;
  ITEMS_MIN = 1;
  ITEMS_MAX = 10;
  EPSILON = 0.001;  { tolerance for floating point comparisons }

  function RandomPrice: Real;
  begin
    { Generate random price between PRICE_MIN and PRICE_MAX, rounded to 2 decimals }
    Result := PRICE_MIN + Random * (PRICE_MAX - PRICE_MIN);
    Result := RoundTo(Result, -2);
    if Result < PRICE_MIN then
      Result := PRICE_MIN;
  end;

  function RandomQuantity: Integer;
  begin
    Result := QTY_MIN + Random(QTY_MAX - QTY_MIN + 1);
  end;

  function RandomItemCount: Integer;
  begin
    Result := ITEMS_MIN + Random(ITEMS_MAX - ITEMS_MIN + 1);
  end;

begin
  Randomize;
  WriteLn('=== Property 3: Cart arithmetic invariant ===');
  WriteLn('Iterations: ', NUM_ITERATIONS);
  WriteLn('');

  for Iteration := 1 to NUM_ITERATIONS do
  begin
    { Generate random number of items for this cart }
    N := RandomItemCount;

    { Pre-generate prices and quantities for all items }
    SetLength(Products, N);
    SetLength(Prices, N);
    SetLength(Quantities, N);

    for i := 0 to N - 1 do
    begin
      Prices[i] := RandomPrice;
      Quantities[i] := RandomQuantity;

      { Create product with a unique ID and the random price }
      Products[i] := TProduct.Create;
      Products[i].setId((Iteration * 100) + i + 1);
      Products[i].setName('Prod_' + IntToStr(Iteration) + '_' + IntToStr(i));
      Products[i].setMinstock(0);
      Products[i].setMaxstock(100);

      Balance := Products[i].getBalance();
      Balance.setPrice(Prices[i]);
      Balance.setCost(Prices[i] * 0.6);  { cost irrelevant for this property }
      Balance.setStock(999);              { enough stock }
    end;

    { Create cart and populate it }
    Cart := TCartService.Create;
    try
      { Add each product to the cart }
      for i := 0 to N - 1 do
        Cart.AddProduct(Products[i]);

      { Set the desired quantities }
      for i := 0 to N - 1 do
        Cart.SetQuantity(i, Quantities[i]);

      { Verify item count }
      if Cart.GetItemCount <> N then
      begin
        Inc(FailedCount);
        WriteLn('[FAIL] Iteration ', Iteration,
                ': Expected ', N, ' items in cart, got ', Cart.GetItemCount);
        Continue;
      end;

      { Property 3a: Verify each GetLineTotal(i) = qty × price }
      LineFailed := False;
      ExpectedGrandTotal := 0;

      for i := 0 to N - 1 do
      begin
        Item := Cart.GetItem(i);
        if Item = nil then
        begin
          Inc(FailedCount);
          WriteLn('[FAIL] Iteration ', Iteration,
                  ': GetItem(', i, ') returned nil');
          LineFailed := True;
          Break;
        end;

        Qty := Item.getStock();
        Price := Item.getPrice();
        ExpectedLineTotal := Qty * Price;
        ActualLineTotal := Cart.GetLineTotal(i);

        if Abs(ActualLineTotal - ExpectedLineTotal) >= EPSILON then
        begin
          Inc(FailedCount);
          WriteLn('[FAIL] Iteration ', Iteration, ', item ', i,
                  ': GetLineTotal mismatch.',
                  ' Expected=', ExpectedLineTotal:0:4,
                  ' Actual=', ActualLineTotal:0:4,
                  ' (qty=', Qty, ', price=', Price:0:4, ')');
          LineFailed := True;
          Break;
        end;

        ExpectedGrandTotal := ExpectedGrandTotal + ActualLineTotal;
      end;

      if LineFailed then
        Continue;

      { Property 3b: Verify GetGrandTotal = sum of all line totals }
      ActualGrandTotal := Cart.GetGrandTotal;

      if Abs(ActualGrandTotal - ExpectedGrandTotal) >= EPSILON then
      begin
        Inc(FailedCount);
        WriteLn('[FAIL] Iteration ', Iteration,
                ': GetGrandTotal mismatch.',
                ' Expected=', ExpectedGrandTotal:0:4,
                ' Actual=', ActualGrandTotal:0:4,
                ' (N=', N, ')');
        Continue;
      end;

      Inc(PassedCount);
    finally
      Cart.Free;
      for i := 0 to N - 1 do
        Products[i].Free;
    end;
  end;

  WriteLn('');
  WriteLn('--- Results ---');
  WriteLn('Passed: ', PassedCount, '/', NUM_ITERATIONS);
  WriteLn('Failed: ', FailedCount, '/', NUM_ITERATIONS);
  WriteLn('');

  if FailedCount = 0 then
  begin
    WriteLn('[OK] Property 3 holds: Cart arithmetic invariant verified.');
    Halt(0);
  end
  else
  begin
    WriteLn('[FAILED] Property 3 violated in ', FailedCount, ' iteration(s).');
    Halt(1);
  end;
end.
