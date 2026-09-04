unit UPurchaseService;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, UPurchase, UItem, UDataIn, UDataModule, ULogger;

type

  { TPurchaseService }

  TPurchaseService = class(TObject)
  private
    FLastError: String;
  public
    function SavePurchase(purchase: TPurchase): Boolean;
    function GetLastError: String;
  end;

implementation

function TPurchaseService.SavePurchase(purchase: TPurchase): Boolean;
var
  dataIn: TDataIn;
  newId: Integer;
  i: Integer;
  item: TItem;

  { Snapshot of the connection/transaction state for diagnostics. }
  function ConnState: String;
  begin
    Result := 'connected=' + BoolToStr(DataModule1.SQLite3Connection1.Connected, True) +
              ' db=' + DataModule1.SQLite3Connection1.DatabaseName;
    if DataModule1.SQLite3Connection1.Transaction = nil then
      Result := Result + ' trans=nil'
    else
      Result := Result + ' transActive=' +
        BoolToStr(DataModule1.SQLite3Connection1.Transaction.Active, True);
  end;

begin
  Result := False;
  FLastError := '';

  LogInfo('PurchaseService', 'SAVE_BEGIN', ConnState);

  { Step 1: Validate purchase }
  if purchase = nil then
  begin
    FLastError := 'Compra nula (error interno)';
    LogError('PurchaseService', 'SAVE_VALIDATION', 'purchase=nil');
    Exit;
  end;

  if purchase.getPerson() = nil then
  begin
    FLastError := 'Debe seleccionar un proveedor';
    LogWarn('PurchaseService', 'SAVE_VALIDATION', 'reason=no_supplier');
    Exit;
  end;

  if (purchase.getItemList() = nil) or (purchase.getItemList().Count = 0) then
  begin
    FLastError := 'Debe agregar al menos un ítem completo';
    LogWarn('PurchaseService', 'SAVE_VALIDATION', 'reason=no_items');
    Exit;
  end;

  { Diagnostic: log the header + each item so we can see exactly what is being
    persisted (product ids, quantities, costs, balance ids). }
  try
    if purchase.getOperationType() = nil then
      LogWarn('PurchaseService', 'SAVE_HEADER', 'operationType=nil (will fail on insert)')
    else
      LogInfo('PurchaseService', 'SAVE_HEADER',
        'supplierId=' + IntToStr(purchase.getPerson().getId()) +
        ' opType=' + IntToStr(purchase.getOperationType().getId()) +
        ' credit=' + IntToStr(purchase.getCredit()) +
        ' items=' + IntToStr(purchase.getItemList().Count));

    for i := 0 to purchase.getItemList().Count - 1 do
    begin
      item := TItem(purchase.getItemList()[i]);
      if item.getProduct() = nil then
        LogWarn('PurchaseService', 'SAVE_ITEM', 'row=' + IntToStr(i) + ' product=nil')
      else
        LogInfo('PurchaseService', 'SAVE_ITEM',
          'row=' + IntToStr(i) +
          ' productId=' + IntToStr(item.getProduct().getId()) +
          ' balanceId=' + IntToStr(item.getProduct().getBalance().getId()) +
          ' qty=' + IntToStr(item.getStock()) +
          ' cost=' + FloatToStr(item.getCost()));
    end;
  except
    on E: Exception do
      LogError('PurchaseService', 'SAVE_DIAG_FAILED', 'error=' + E.Message);
  end;

  { Step 2: Calculate new balance (adjusts in-memory balance for each item) }
  try
    purchase.calculateNewBalance();
    LogDebug('PurchaseService', 'BALANCE_CALCULATED', '');
  except
    on E: Exception do
    begin
      FLastError := 'Error calculando saldos: ' + E.Message;
      LogError('PurchaseService', 'BALANCE_CALC_FAILED', 'error=' + E.Message);
      Exit;
    end;
  end;

  { Step 3: Persist via TDataIn.new() }
  try
    DataModule1.EnsureTransaction;
    if not DataModule1.SQLite3Connection1.Transaction.Active then
      DataModule1.SQLite3Connection1.Transaction.StartTransaction;
    LogDebug('PurchaseService', 'TRANSACTION_READY', ConnState);
  except
    on E: Exception do
    begin
      FLastError := 'No se pudo iniciar la transacción: ' + E.Message;
      LogError('PurchaseService', 'TRANSACTION_START_FAILED',
        'error=' + E.Message + ' ' + ConnState);
      Exit;
    end;
  end;

  dataIn := TDataIn.Create(DataModule1.SQLite3Connection1);
  try
    try
      newId := dataIn.new(purchase);
      LogInfo('PurchaseService', 'DATAIN_NEW_RESULT', 'newId=' + IntToStr(newId));

      if newId > 0 then
      begin
        DataModule1.SQLite3Connection1.Transaction.Commit;
        Result := True;
        LogInfo('PurchaseService', 'SAVE_COMMITTED', 'operationId=' + IntToStr(newId));
      end
      else
      begin
        if DataModule1.SQLite3Connection1.Transaction.Active then
          DataModule1.SQLite3Connection1.Transaction.Rollback;
        FLastError := 'La compra no fue guardada (el insert devolvió 0). ' +
          'Revise el log para el detalle.';
        LogError('PurchaseService', 'SAVE_FAILED',
          'reason=dataIn_new_returned_zero ' + ConnState);
      end;
    except
      on E: Exception do
      begin
        if DataModule1.SQLite3Connection1.Transaction.Active then
          DataModule1.SQLite3Connection1.Transaction.Rollback;
        FLastError := 'La compra no fue guardada: ' + E.Message;
        LogError('PurchaseService', 'SAVE_EXCEPTION',
          'error=' + E.ClassName + ': ' + E.Message + ' ' + ConnState);
      end;
    end;
  finally
    { Use Destroy, not Free: TData shadows a lowercase free() that used to
      release the shared connection transaction. Destroy releases the instance
      cleanly without touching the shared transaction. }
    dataIn.Destroy;
  end;
end;

function TPurchaseService.GetLastError: String;
begin
  Result := FLastError;
end;

end.
