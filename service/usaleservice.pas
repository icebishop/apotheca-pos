unit USaleService;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, USale, UDataOut, UDataModule, UCartService, ULogger;

type

  { TSaleService }

  TSaleService = class(TObject)
  private
    FLastError: String;
  public
    function SaveSale(cart: TCartService; credit: Boolean): Boolean;
    function GetLastError: String;
  end;

implementation

function TSaleService.SaveSale(cart: TCartService; credit: Boolean): Boolean;
var
  sale: TSale;
  dataOut: TDataOut;
begin
  Result := False;
  FLastError := '';

  { Validate credit sale requires a customer }
  if credit and (cart.GetCustomer = nil) then
  begin
    FLastError := 'Debe seleccionar un cliente para ventas a crédito';
    LogWarn('SaleService', 'CREDIT_SALE_VALIDATION_FAIL', 'reason=no_customer');
    Exit;
  end;

  { Step 1: Validate the cart }
  if not cart.IsValid then
  begin
    if cart.GetItemCount = 0 then
      FLastError := 'Debe agregar al menos un producto al carrito'
    else
      FLastError := 'Debe seleccionar un cliente';
    Exit;
  end;

  { Step 2: Build TSale from cart }
  sale := cart.ToSale;

  { Step 3: Set credit flag }
  if credit then
    sale.setCredit(1)
  else
    sale.setCredit(0);

  { Step 4: Calculate new balance (adjusts in-memory balance for each item) }
  sale.calculateNewBalance();

  { Step 5: Create transaction and persist via TDataOut.new() }
  DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
  DataModule1.SQLite3Connection1.Transaction.DataBase := DataModule1.SQLite3Connection1;
  dataOut := TDataOut.Create(DataModule1.SQLite3Connection1);
  dataOut.getTransaction().StartTransaction;
  try
    if dataOut.new(sale) > 0 then
    begin
      dataOut.getTransaction().Commit;
      Result := True;
      if credit then
        LogSecurity('SaleService', 'CREDIT_SALE_CREATED',
          'personId=' + IntToStr(sale.getPerson().getId()) + ' items=' + IntToStr(sale.getItemList().Count))
      else
        LogInfo('SaleService', 'SALE_CREATED',
          'personId=' + IntToStr(sale.getPerson().getId()) + ' items=' + IntToStr(sale.getItemList().Count));
    end
    else
    begin
      dataOut.getTransaction().Rollback;
      FLastError := 'El objeto no ha sido Guardado';
      LogError('SaleService', 'SALE_SAVE_FAILED', 'reason=dataout_returned_zero');
    end;
  except
    on E: Exception do
    begin
      dataOut.getTransaction().Rollback;
      FLastError := 'El objeto no ha sido Guardado';
      LogError('SaleService', 'SALE_EXCEPTION', 'error=' + E.Message);
    end;
  end;
  DataModule1.SQLite3Connection1.Transaction.Free;
  DataModule1.SQLite3Connection1.Transaction := nil;
  dataOut.Free;
end;

function TSaleService.GetLastError: String;
begin
  Result := FLastError;
end;

end.
