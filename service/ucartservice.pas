unit UCartService;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UItem, UProduct, UCustomer, USale, LazLogger;

type
  TCartService = class(TObject)
  private
    FItems: TList;
    FCustomer: TCustomer;
    function FindProductIndex(productId: Integer): Integer;
  public
    constructor Create;
    destructor Destroy; override;
    procedure AddProduct(product: TProduct);
    procedure RemoveItem(index: Integer);
    procedure SetQuantity(index: Integer; qty: Integer);
    function GetLineTotal(index: Integer): Real;
    function GetGrandTotal: Real;
    function GetItemCount: Integer;
    function GetItem(index: Integer): TItem;
    procedure Clear;
    procedure SetCustomer(customer: TCustomer);
    function GetCustomer: TCustomer;
    function IsValid: Boolean;
    function ToSale: TSale;
  end;

implementation

constructor TCartService.Create;
begin
  inherited Create;
  FItems := TList.Create;
  FCustomer := nil;
end;

destructor TCartService.Destroy;
begin
  Clear;
  FItems.Free;
  inherited Destroy;
end;

function TCartService.FindProductIndex(productId: Integer): Integer;
var
  i: Integer;
  item: TItem;
begin
  Result := -1;
  for i := 0 to FItems.Count - 1 do
  begin
    item := TItem(FItems[i]);
    if (item.getProduct() <> nil) and (item.getProduct().getId() = productId) then
    begin
      Result := i;
      Exit;
    end;
  end;
end;

procedure TCartService.AddProduct(product: TProduct);
var
  idx: Integer;
  item: TItem;
  availableStock: Integer;
  currentQty: Integer;
begin
  try
  if product = nil then Exit;

  // Get available stock from balance
  availableStock := 0;
  if product.getBalance() <> nil then
    availableStock := product.getBalance().getStock();

  idx := FindProductIndex(product.getId());
  if idx >= 0 then
  begin
    // Product already in cart, check if we can increment
    item := TItem(FItems[idx]);
    currentQty := item.getStock();
    if currentQty >= availableStock then
      Exit; // No more stock available
    item.setStock(currentQty + 1);
  end
  else
  begin
    // New product, check stock > 0
    if availableStock <= 0 then
      Exit; // No stock available
    item := TItem.Create;
    item.setProduct(product);
    item.setStock(1);
    if product.getBalance() <> nil then
    begin
      item.setPrice(product.getBalance().getPrice());
      item.setCost(product.getBalance().getCost());
    end;
    FItems.Add(item);
  end;
  except
    on E: Exception do DebugLn('[TCartService.AddProduct] ERROR: ' + E.Message);
  end;
end;

procedure TCartService.RemoveItem(index: Integer);
var
  item: TItem;
begin
  if (index >= 0) and (index < FItems.Count) then
  begin
    item := TItem(FItems[index]);
    FItems.Delete(index);
    item.Free;
  end;
end;

procedure TCartService.SetQuantity(index: Integer; qty: Integer);
var
  item: TItem;
  availableStock: Integer;
begin
  if (index >= 0) and (index < FItems.Count) then
  begin
    item := TItem(FItems[index]);
    availableStock := 0;
    if (item.getProduct() <> nil) and (item.getProduct().getBalance() <> nil) then
      availableStock := item.getProduct().getBalance().getStock();
    if qty > availableStock then
      qty := availableStock;
    if qty < 1 then
      qty := 1;
    item.setStock(qty);
  end;
end;

function TCartService.GetLineTotal(index: Integer): Real;
var
  item: TItem;
begin
  Result := 0;
  if (index >= 0) and (index < FItems.Count) then
  begin
    item := TItem(FItems[index]);
    Result := item.getPrice() * item.getStock();
  end;
end;

function TCartService.GetGrandTotal: Real;
var
  i: Integer;
begin
  Result := 0;
  for i := 0 to FItems.Count - 1 do
    Result := Result + GetLineTotal(i);
end;

function TCartService.GetItemCount: Integer;
begin
  Result := FItems.Count;
end;

function TCartService.GetItem(index: Integer): TItem;
begin
  Result := nil;
  if (index >= 0) and (index < FItems.Count) then
    Result := TItem(FItems[index]);
end;

procedure TCartService.Clear;
var
  i: Integer;
  item: TItem;
begin
  for i := FItems.Count - 1 downto 0 do
  begin
    item := TItem(FItems[i]);
    item.Free;
  end;
  FItems.Clear;
  FCustomer := nil;
end;

procedure TCartService.SetCustomer(customer: TCustomer);
begin
  FCustomer := customer;
end;

function TCartService.GetCustomer: TCustomer;
begin
  Result := FCustomer;
end;

function TCartService.IsValid: Boolean;
begin
  Result := (FItems.Count > 0) and (FCustomer <> nil);
end;

function TCartService.ToSale: TSale;
var
  sale: TSale;
  saleItems: TList;
  i: Integer;
  cartItem, saleItem: TItem;
begin
  Result := nil;
  try
  sale := TSale.Create;
  sale.setCustomer(FCustomer);
  sale.setDate(Now);

  saleItems := TList.Create;
  for i := 0 to FItems.Count - 1 do
  begin
    cartItem := TItem(FItems[i]);
    saleItem := TItem.Create;
    saleItem.setProduct(cartItem.getProduct());
    saleItem.setStock(cartItem.getStock());
    saleItem.setPrice(cartItem.getPrice());
    saleItem.setCost(cartItem.getCost());
    saleItems.Add(saleItem);
  end;
  sale.setItemList(saleItems);

  Result := sale;
  except
    on E: Exception do DebugLn('[TCartService.ToSale] ERROR: ' + E.Message);
  end;
end;

end.
