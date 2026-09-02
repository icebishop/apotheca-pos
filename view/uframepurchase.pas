unit UFramePurchase;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, EditBtn, Grids,
  Buttons, ComCtrls, Dialogs, LCLType,
  UPurchase, UItem, UFFindSupplier, UFFindProduct,
  UPurchaseService, UDataModule, UResourceString, UGridUtils, LazLogger;

type

  { TFramePurchase }

  TFramePurchase = class(TFrame)
    BtnAddItem: TBitBtn;
    BtnDeleteItem: TBitBtn;
    BtnSavePurchase: TBitBtn;
    BtnSelectProduct: TButton;
    BtnSelectSupplier: TBitBtn;
    DateEdit: TDateEdit;
    EditSupplier: TEdit;
    GridItems: TStringGrid;
    LabelDate: TLabel;
    LabelSupplier: TLabel;
    LabelTitle: TLabel;
    LabelTotalCost: TLabel;
    StatusBarPurchase: TStatusBar;
    procedure BtnAddItemClick(Sender: TObject);
    procedure BtnDeleteItemClick(Sender: TObject);
    procedure BtnSavePurchaseClick(Sender: TObject);
    procedure BtnSelectProductClick(Sender: TObject);
    procedure BtnSelectSupplierClick(Sender: TObject);
    procedure DateEditChange(Sender: TObject);
    procedure GridItemsEditingDone(Sender: TObject);
    procedure GridItemsSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
  private
    FPurchase: TPurchase;
    FPurchaseService: TPurchaseService;
    FItemFlag: Boolean;
    FUtilityPercentages: array of Real;  { % utility per row }
    FTotalCosts: array of Real;          { total cost per row }
    FManualPrice: array of Boolean;      { true if user manually edited price }
    procedure LoadDataGrid;
    procedure CalculateTotal;
    procedure CalculateRowPrices(ARow: Integer);
    procedure InitPurchase;
    procedure ApplyTranslations;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ClearForm;
  end;

implementation

{$R *.lfm}

{ TFramePurchase }

constructor TFramePurchase.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FPurchaseService := TPurchaseService.Create;

  { Setup inline product select button inside grid }
  GridItems.DefaultRowHeight := BtnSelectProduct.Height;
  BtnSelectProduct.Parent := GridItems;
  BtnSelectProduct.Visible := False;

  ApplyTranslations;
  InitPurchase;
end;

procedure TFramePurchase.ApplyTranslations;
begin
  LabelTitle.Caption := RS_PURCHASE_TITLE;
  LabelSupplier.Caption := RS_PURCHASE_SUPPLIER;
  LabelDate.Caption := RS_PURCHASE_DATE;
  BtnAddItem.Caption := RS_PURCHASE_ADD;
  BtnDeleteItem.Caption := RS_PURCHASE_DELETE_ITEM;
  BtnSavePurchase.Caption := RS_PURCHASE_SAVE;

  { Grid headers (fixed row; survives GridItems.Clean([gzNormal])) }
  GridItems.Cells[0, 0] := RS_PURCHASE_GRID_PRODUCT;
  GridItems.Cells[1, 0] := RS_PURCHASE_GRID_QTY;
  GridItems.Cells[2, 0] := RS_PURCHASE_GRID_TOTALCOST;
  GridItems.Cells[3, 0] := RS_PURCHASE_GRID_UTILITY;
  GridItems.Cells[4, 0] := RS_PURCHASE_GRID_UNITCOST;
  GridItems.Cells[5, 0] := RS_PURCHASE_GRID_PRICE;
end;

destructor TFramePurchase.Destroy;
begin
  FPurchaseService.Free;
  if FPurchase <> nil then
    FPurchase.Free;
  inherited Destroy;
end;

procedure TFramePurchase.InitPurchase;
begin
  if FPurchase <> nil then
  begin
    FPurchase.Free;
    FPurchase := nil;
  end;

  FPurchase := TPurchase.Create;
  FPurchase.setItemList(TList.Create);
  FPurchase.getItemList().Add(TItem.Create);
  DateEdit.Date := Now;
  FPurchase.setDate(DateEdit.Date);
  EditSupplier.Text := '';
  FItemFlag := False;
  SetLength(FTotalCosts, 1);
  FTotalCosts[0] := 0;
  SetLength(FUtilityPercentages, 1);
  FUtilityPercentages[0] := 0;
  SetLength(FManualPrice, 1);
  FManualPrice[0] := False;
  LoadDataGrid;
  CalculateTotal;
end;

procedure TFramePurchase.ClearForm;
begin
  InitPurchase;
  StatusBarPurchase.SimpleText := '';
end;

procedure TFramePurchase.BtnSelectSupplierClick(Sender: TObject);
var
  formFindSupplier: TFormFindSupplier;
begin
  try
  formFindSupplier := TFormFindSupplier.Create(Self);
  try
    formFindSupplier.ShowModal;
    if formFindSupplier.getSupplier() <> nil then
    begin
      FPurchase.setSupplier(formFindSupplier.getSupplier());
      EditSupplier.Text := FPurchase.getSupplier().getName();
    end;
  finally
    formFindSupplier.Free;
  end;
  except
    on E: Exception do DebugLn('[TFramePurchase.BtnSelectSupplierClick] ERROR: ' + E.Message);
  end;
end;

procedure TFramePurchase.DateEditChange(Sender: TObject);
begin
  FPurchase.setDate(DateEdit.Date);
end;

procedure TFramePurchase.BtnAddItemClick(Sender: TObject);
begin
  try
  FPurchase.getItemList().Add(TItem.Create);
  SetLength(FTotalCosts, Length(FTotalCosts) + 1);
  FTotalCosts[High(FTotalCosts)] := 0;
  SetLength(FUtilityPercentages, Length(FUtilityPercentages) + 1);
  FUtilityPercentages[High(FUtilityPercentages)] := 0;
  SetLength(FManualPrice, Length(FManualPrice) + 1);
  FManualPrice[High(FManualPrice)] := False;
  FItemFlag := False;
  LoadDataGrid;
  CalculateTotal;
  except
    on E: Exception do DebugLn('[TFramePurchase.BtnAddItemClick] ERROR: ' + E.Message);
  end;
end;

procedure TFramePurchase.BtnDeleteItemClick(Sender: TObject);
begin
  try
  if (FPurchase.getItemList().Count > 0) and (GridItems.Row > 0) then
  begin
    FPurchase.getItemList().Delete(GridItems.Row - 1);
    if FPurchase.getItemList().Count = 0 then
      FItemFlag := True;
    LoadDataGrid;
    CalculateTotal;
  end;
  except
    on E: Exception do DebugLn('[TFramePurchase.BtnDeleteItemClick] ERROR: ' + E.Message);
  end;
end;

procedure TFramePurchase.BtnSavePurchaseClick(Sender: TObject);
var
  i: Integer;
  item: TItem;
  hasCompleteRow: Boolean;
begin
  try
  { Validate supplier selected }
  if FPurchase.getSupplier() = nil then
  begin
    StatusBarPurchase.SimpleText := RS_PURCHASE_NO_SUPPLIER;
    Exit;
  end;

  { Validate at least one complete item row }
  hasCompleteRow := False;
  for i := 0 to FPurchase.getItemList().Count - 1 do
  begin
    item := TItem(FPurchase.getItemList()[i]);
    if (item.getProduct() <> nil) and (item.getStock() > 0) and
       (item.getCost() > 0) then
    begin
      hasCompleteRow := True;
      Break;
    end;
  end;

  if not hasCompleteRow then
  begin
    StatusBarPurchase.SimpleText := RS_PURCHASE_NO_ITEMS;
    Exit;
  end;

  { Call PurchaseService to save }
  if FPurchaseService.SavePurchase(FPurchase) then
  begin
    Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE), MB_OK);
    ClearForm;
  end
  else
  begin
    Application.MessageBox(PChar(FPurchaseService.GetLastError()),
      PChar(RS_Error), MB_ICONHAND);
  end;
  except
    on E: Exception do DebugLn('[TFramePurchase.BtnSavePurchaseClick] ERROR: ' + E.Message);
  end;
end;

procedure TFramePurchase.BtnSelectProductClick(Sender: TObject);
var
  formProduct: TFormFindProduct;
  item: TItem;
begin
  try
  formProduct := TFormFindProduct.Create(Self);
  try
    formProduct.setFlagAllProducts(True);
    formProduct.ShowModal;
    if formProduct.getProduct() <> nil then
    begin
      item := TItem(FPurchase.getItemList()[GridItems.Row - 1]);
      item.setProduct(formProduct.getProduct());
      item.setCost(item.getProduct().getBalance().getCost());
      item.setPrice(item.getProduct().getBalance().getPrice());
      LoadDataGrid;
      CalculateTotal;
    end;
  finally
    formProduct.Free;
  end;
  except
    on E: Exception do DebugLn('[TFramePurchase.BtnSelectProductClick] ERROR: ' + E.Message);
  end;
end;

procedure TFramePurchase.GridItemsEditingDone(Sender: TObject);
var
  item: TItem;
  row, col: Integer;
  totalCost, pct, unitCost, salePrice: Real;
  qty: Integer;
begin
  try
  row := GridItems.Row;
  col := GridItems.Col;
  if (row < 1) or (row > FPurchase.getItemList().Count) then
    Exit;

  item := TItem(FPurchase.getItemList()[row - 1]);

  { Parse edited cells }
  { Column 1 = Quantity }
  qty := StrToIntDef(GridItems.Cells[1, row], 0);
  item.setStock(qty);

  { Column 2 = Total Cost for this row }
  totalCost := StrToFloatDef(GridItems.Cells[2, row], 0);
  if (row - 1) <= High(FTotalCosts) then
    FTotalCosts[row - 1] := totalCost;

  { Column 3 = % Utility }
  pct := StrToFloatDef(GridItems.Cells[3, row], 0);
  if (row - 1) <= High(FUtilityPercentages) then
    FUtilityPercentages[row - 1] := pct;

  { Calculate unit cost }
  if qty > 0 then
    unitCost := totalCost / qty
  else
    unitCost := 0;

  item.setCost(unitCost);
  GridItems.Cells[4, row] := FormatFloat('0.00', unitCost);

  { Column 5 = Sale Price - if user edited it directly, use their value }
  if col = 5 then
  begin
    salePrice := StrToFloatDef(GridItems.Cells[5, row], 0);
    item.setPrice(salePrice);
    if (row - 1) <= High(FManualPrice) then
      FManualPrice[row - 1] := True;
  end
  else
  begin
    { Only auto-calculate if price was NOT manually set }
    if ((row - 1) <= High(FManualPrice)) and FManualPrice[row - 1] then
    begin
      { Keep existing manual price, don't overwrite }
    end
    else
    begin
      salePrice := unitCost * (1 + pct / 100);
      item.setPrice(salePrice);
      GridItems.Cells[5, row] := FormatFloat('0.00', salePrice);
    end;
  end;

  FItemFlag := True;
  CalculateTotal;
  except
    on E: Exception do DebugLn('[TFramePurchase.GridItemsEditingDone] ERROR: ' + E.Message);
  end;
end;

procedure TFramePurchase.GridItemsSelectCell(Sender: TObject; aCol,
  aRow: Integer; var CanSelect: Boolean);
var
  rect: TRect;
begin
  try
  if (aCol = 0) and (aRow > 0) then
  begin
    rect := GridItems.CellRect(aCol, aRow);
    rect.Left := rect.Left + (rect.Right - rect.Left) - BtnSelectProduct.Width;
    rect.Right := rect.Left + BtnSelectProduct.Width;
    rect.Bottom := rect.Top + BtnSelectProduct.Height;
    BtnSelectProduct.BoundsRect := rect;
    BtnSelectProduct.Visible := True;
  end
  else
    BtnSelectProduct.Visible := False;
  except
    on E: Exception do DebugLn('[TFramePurchase.GridItemsSelectCell] ERROR: ' + E.Message);
  end;
end;

procedure TFramePurchase.LoadDataGrid;
var
  i: Integer;
  item: TItem;
  totalCost, pct: Real;
begin
  GridItems.Clean([gzNormal]);
  GridItems.RowCount := FPurchase.getItemList().Count + 1;

  { Ensure arrays match item count }
  SetLength(FTotalCosts, FPurchase.getItemList().Count);
  SetLength(FUtilityPercentages, FPurchase.getItemList().Count);
  if Length(FManualPrice) < FPurchase.getItemList().Count then
    SetLength(FManualPrice, FPurchase.getItemList().Count);

  DistributeColumns(GridItems, [28, 10, 16, 12, 16, 18]);

  for i := 0 to FPurchase.getItemList().Count - 1 do
  begin
    item := TItem(FPurchase.getItemList()[i]);
    if item.getProduct() <> nil then
      GridItems.Cells[0, i + 1] := item.getProduct().getName();
    GridItems.Cells[1, i + 1] := IntToStr(item.getStock());

    { Total cost for row }
    totalCost := FTotalCosts[i];
    if totalCost = 0 then
      totalCost := item.getCost() * item.getStock();
    GridItems.Cells[2, i + 1] := FormatFloat('0.00', totalCost);

    { % Utility }
    pct := FUtilityPercentages[i];
    GridItems.Cells[3, i + 1] := FormatFloat('0.##', pct);

    { Unit cost (calculated) }
    GridItems.Cells[4, i + 1] := FormatFloat('0.00', item.getCost());

    { Sale price (calculated) }
    GridItems.Cells[5, i + 1] := FormatFloat('0.00', item.getPrice());
  end;
end;

procedure TFramePurchase.CalculateTotal;
var
  total: Real;
  i: Integer;
begin
  total := 0;
  for i := 0 to High(FTotalCosts) do
    total := total + FTotalCosts[i];
  LabelTotalCost.Caption := Format(RS_PURCHASE_TOTAL, [FormatFloat('0.00', total)]);
end;

procedure TFramePurchase.CalculateRowPrices(ARow: Integer);
var
  item: TItem;
  totalCost, pct, unitCost, salePrice: Real;
  qty: Integer;
begin
  if (ARow < 1) or (ARow > FPurchase.getItemList().Count) then Exit;
  item := TItem(FPurchase.getItemList()[ARow - 1]);
  qty := item.getStock();
  totalCost := FTotalCosts[ARow - 1];
  pct := FUtilityPercentages[ARow - 1];

  if qty > 0 then
    unitCost := totalCost / qty
  else
    unitCost := 0;
  salePrice := unitCost * (1 + pct / 100);

  item.setCost(unitCost);
  item.setPrice(salePrice);

  GridItems.Cells[4, ARow] := FormatFloat('0.00', unitCost);
  GridItems.Cells[5, ARow] := FormatFloat('0.00', salePrice);
end;

end.
