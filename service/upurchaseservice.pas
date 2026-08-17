unit UPurchaseService;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqldb, UPurchase, UDataIn, UDataModule;

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
begin
  Result := False;
  FLastError := '';

  { Step 1: Validate purchase }
  if purchase.getPerson() = nil then
  begin
    FLastError := 'Debe seleccionar un proveedor';
    Exit;
  end;

  if (purchase.getItemList() = nil) or (purchase.getItemList().Count = 0) then
  begin
    FLastError := 'Debe agregar al menos un ítem completo';
    Exit;
  end;

  { Step 2: Calculate new balance (adjusts in-memory balance for each item) }
  purchase.calculateNewBalance();

  { Step 3: Create transaction and persist via TDataIn.new() }
  DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
  DataModule1.SQLite3Connection1.Transaction.DataBase := DataModule1.SQLite3Connection1;
  dataIn := TDataIn.Create(DataModule1.SQLite3Connection1);
  dataIn.getTransaction().StartTransaction;
  try
    if dataIn.new(purchase) > 0 then
    begin
      { Step 4a: Success - commit }
      dataIn.getTransaction().Commit;
      Result := True;
    end
    else
    begin
      { Step 4b: Failure - rollback }
      dataIn.getTransaction().Rollback;
      FLastError := 'El objeto no ha sido Guardado';
    end;
  except
    on E: Exception do
    begin
      dataIn.getTransaction().Rollback;
      FLastError := 'El objeto no ha sido Guardado';
    end;
  end;
  dataIn.Free;
end;

function TPurchaseService.GetLastError: String;
begin
  Result := FLastError;
end;

end.
