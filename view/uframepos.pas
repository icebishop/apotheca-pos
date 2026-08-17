unit UFramePOS;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Grids, Buttons, ExtCtrls,
  ComCtrls, Dialogs, LCLType, LResources, UCartService, USaleService,
  UDataProduct, UDataModule, UProduct, UItem, UFFindCustomer,
  UResourceString, sqldb, UGridUtils;

type

  { TFramePOS }

  TFramePOS = class(TFrame)
    BtnCompleteSale: TBitBtn;
    BtnRemoveItem: TBitBtn;
    BtnSelectCustomer: TBitBtn;
    CheckCredit: TCheckBox;
    EditCustomer: TEdit;
    EditSearch: TEdit;
    GridCart: TStringGrid;
    LabelGrandTotal: TLabel;
    ListBoxResults: TListBox;
    TimerSearch: TTimer;
    procedure OnCompleteSaleClick(Sender: TObject);
    procedure OnGridEditingDone(Sender: TObject);
    procedure OnGridKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure OnProductSelected(Sender: TObject);
    procedure OnRemoveItemClick(Sender: TObject);
    procedure OnSearchChange(Sender: TObject);
    procedure OnSelectCustomerClick(Sender: TObject);
    procedure OnTimerFire(Sender: TObject);
  private
    FCartService: TCartService;
    FSaleService: TSaleService;
    FSearchResults: TList;
    procedure RefreshGrid;
    procedure RefreshTotals;
    procedure FreeSearchResults;
    procedure InitGrid;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ClearCart;
  end;

implementation

constructor TFramePOS.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCartService := TCartService.Create;
  FSaleService := TSaleService.Create;
  FSearchResults := nil;
  InitGrid;
end;

destructor TFramePOS.Destroy;
begin
  FreeSearchResults;
  FCartService.Free;
  FSaleService.Free;
  inherited Destroy;
end;

procedure TFramePOS.InitGrid;
begin
  if GridCart.RowCount < 2 then
    GridCart.RowCount := 2;
  GridCart.FixedRows := 1;
  GridCart.Cells[0, 0] := 'Producto';
  GridCart.Cells[1, 0] := 'Precio U';
  GridCart.Cells[2, 0] := 'Cantidad';
  GridCart.Cells[3, 0] := 'Total Línea';
  DistributeColumns(GridCart, [40, 20, 15, 25]);
end;

procedure TFramePOS.OnSearchChange(Sender: TObject);
begin
  { Restart timer on each keystroke for debounced search }
  TimerSearch.Enabled := False;
  TimerSearch.Enabled := True;
end;

procedure TFramePOS.OnTimerFire(Sender: TObject);
var
  dataProduct: TDataProducto;
  searchText: String;
  i: Integer;
  product: TProduct;
  Trans: TSQLTransaction;
begin
  TimerSearch.Enabled := False;
  searchText := Trim(EditSearch.Text);

  FreeSearchResults;
  ListBoxResults.Items.Clear;

  if searchText = '' then
  begin
    ListBoxResults.Visible := False;
    Exit;
  end;

  { Query products in stock matching search text }
  Trans := TSQLTransaction.Create(nil);
  Trans.DataBase := DataModule1.SQLite3Connection1;
  DataModule1.SQLite3Connection1.Transaction := Trans;
  dataProduct := TDataProducto.Create(DataModule1.SQLite3Connection1);
  try
    FSearchResults := dataProduct.findInStock('%' + searchText + '%');
  finally
    dataProduct.Free;
  end;

  if (FSearchResults <> nil) and (FSearchResults.Count > 0) then
  begin
    for i := 0 to FSearchResults.Count - 1 do
    begin
      product := TProduct(FSearchResults[i]);
      ListBoxResults.Items.Add(product.getName());
    end;
    ListBoxResults.Visible := True;
  end
  else
    ListBoxResults.Visible := False;
end;

procedure TFramePOS.OnProductSelected(Sender: TObject);
var
  idx: Integer;
  product: TProduct;
begin
  idx := ListBoxResults.ItemIndex;
  if (idx < 0) or (FSearchResults = nil) or (idx >= FSearchResults.Count) then
    Exit;

  product := TProduct(FSearchResults[idx]);
  FCartService.AddProduct(product);

  { Clear search and hide results }
  EditSearch.Text := '';
  ListBoxResults.Items.Clear;
  ListBoxResults.Visible := False;

  RefreshGrid;
  RefreshTotals;
end;

procedure TFramePOS.OnGridEditingDone(Sender: TObject);
var
  row, qty: Integer;
  newPrice: Real;
  item: TItem;
begin
  row := GridCart.Row;
  if row < 1 then Exit;
  if (row - 1) >= FCartService.GetItemCount then Exit;

  item := FCartService.GetItem(row - 1);
  if item = nil then Exit;

  { Column 1 = Price: allow editing but validate >= cost }
  if GridCart.Col = 1 then
  begin
    if TryStrToFloat(GridCart.Cells[1, row], newPrice) then
    begin
      if newPrice < item.getCost() then
      begin
        { Reject: price must be >= cost }
        GridCart.Cells[1, row] := FormatFloat('0.00', item.getPrice());
      end
      else
        item.setPrice(newPrice);
    end;
    RefreshGrid;
    RefreshTotals;
  end;

  { Column 2 = Quantity }
  if GridCart.Col = 2 then
  begin
    if TryStrToInt(GridCart.Cells[2, row], qty) then
    begin
      if qty <= 0 then
        FCartService.RemoveItem(row - 1)
      else
        FCartService.SetQuantity(row - 1, qty);
    end;
    RefreshGrid;
    RefreshTotals;
  end;
end;

procedure TFramePOS.OnRemoveItemClick(Sender: TObject);
var
  row: Integer;
begin
  row := GridCart.Row;
  if (row >= 1) and ((row - 1) < FCartService.GetItemCount) then
  begin
    FCartService.RemoveItem(row - 1);
    RefreshGrid;
    RefreshTotals;
  end;
end;

procedure TFramePOS.OnGridKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  row: Integer;
begin
  { Delete key removes selected item }
  if Key = VK_DELETE then
  begin
    row := GridCart.Row;
    if (row >= 1) and ((row - 1) < FCartService.GetItemCount) then
    begin
      FCartService.RemoveItem(row - 1);
      RefreshGrid;
      RefreshTotals;
    end;
    Key := 0;
  end;
end;

procedure TFramePOS.OnCompleteSaleClick(Sender: TObject);
var
  parentForm: TCustomForm;
  statusBar: TStatusBar;
begin
  { Validate cart }
  if FCartService.GetItemCount = 0 then
  begin
    Application.MessageBox(
      'Debe agregar al menos un producto al carrito',
      PChar(RS_Error), MB_ICONWARNING);
    Exit;
  end;

  { Credit-specific validation: customer is required for credit sales }
  if CheckCredit.Checked and (FCartService.GetCustomer = nil) then
  begin
    Application.MessageBox(
      PChar(RS_POS_CREDIT_NO_CUSTOMER),
      PChar(RS_Error), MB_ICONWARNING);
    Exit;
  end;

  if FCartService.GetCustomer = nil then
  begin
    Application.MessageBox(
      'Debe seleccionar un cliente',
      PChar(RS_Error), MB_ICONWARNING);
    Exit;
  end;

  { Save the sale via service }
  if FSaleService.SaveSale(FCartService, CheckCredit.Checked) then
  begin
    { Show confirmation in StatusBar }
    parentForm := GetParentForm(Self);
    if parentForm <> nil then
    begin
      statusBar := TStatusBar(parentForm.FindComponent('StatusBar'));
      if statusBar <> nil then
        statusBar.SimpleText := RS_OBJECTSAVE;
    end;
    ClearCart;
  end
  else
  begin
    Application.MessageBox(
      PChar(FSaleService.GetLastError), PChar(RS_Error), MB_ICONHAND);
  end;
end;

procedure TFramePOS.OnSelectCustomerClick(Sender: TObject);
var
  formFindCustomer: TFormFindCustomer;
begin
  formFindCustomer := TFormFindCustomer.Create(Self);
  try
    formFindCustomer.ShowModal;
    if formFindCustomer.getCustomer() <> nil then
    begin
      FCartService.SetCustomer(formFindCustomer.getCustomer());
      EditCustomer.Text := formFindCustomer.getCustomer().getName();
    end;
  finally
    formFindCustomer.Free;
  end;
end;

procedure TFramePOS.RefreshGrid;
var
  i: Integer;
  item: TItem;
begin
  if FCartService.GetItemCount > 0 then
    GridCart.RowCount := FCartService.GetItemCount + 1
  else
    GridCart.RowCount := 2;  { 1 fixed + 1 empty data row }
  GridCart.FixedRows := 1;
  GridCart.Cells[0, 0] := 'Producto';
  GridCart.Cells[1, 0] := 'Precio U';
  GridCart.Cells[2, 0] := 'Cantidad';
  GridCart.Cells[3, 0] := 'Total Línea';
  { Clear data rows }
  if FCartService.GetItemCount = 0 then
  begin
    GridCart.Cells[0, 1] := '';
    GridCart.Cells[1, 1] := '';
    GridCart.Cells[2, 1] := '';
    GridCart.Cells[3, 1] := '';
  end;
  for i := 0 to FCartService.GetItemCount - 1 do
  begin
    item := FCartService.GetItem(i);
    if item <> nil then
    begin
      if item.getProduct() <> nil then
        GridCart.Cells[0, i + 1] := item.getProduct().getName()
      else
        GridCart.Cells[0, i + 1] := '';
      GridCart.Cells[1, i + 1] := FormatFloat('0.00', item.getPrice());
      GridCart.Cells[2, i + 1] := IntToStr(item.getStock());
      GridCart.Cells[3, i + 1] := FormatFloat('0.00', FCartService.GetLineTotal(i));
    end;
  end;
end;

procedure TFramePOS.RefreshTotals;
begin
  LabelGrandTotal.Caption := 'Total: $' + FormatFloat('0.00', FCartService.GetGrandTotal);
end;

procedure TFramePOS.FreeSearchResults;
begin
  { Product objects may be referenced by cart items, so we only free the list
    container, not the individual product objects. }
  if FSearchResults <> nil then
  begin
    FSearchResults.Free;
    FSearchResults := nil;
  end;
end;

procedure TFramePOS.ClearCart;
begin
  FCartService.Clear;
  EditCustomer.Text := '';
  EditSearch.Text := '';
  CheckCredit.Checked := False;
  ListBoxResults.Items.Clear;
  ListBoxResults.Visible := False;
  RefreshGrid;
  RefreshTotals;
end;

initialization
  {$I uframepos.lrs}

end.
