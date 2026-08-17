unit UFInventoryAdjustment;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  StdCtrls, Buttons, ExtCtrls, UProduct, UDataProduct, UDataModule,
  UItem, UTransaction, UDataTransaction, UBalanceBuilder, sqldb, UOperationType;

type

  { TFormInventoryAdjustment }

  TFormInventoryAdjustment = class(TForm)
    ButtonCancel: TBitBtn;
    ButtonSave: TBitBtn;
    ComboBoxAdjustmentType: TComboBox;
    ComboBoxProduct: TComboBox;
    EditCost: TEdit;
    EditNotes: TEdit;
    EditPrice: TEdit;
    EditQuantity: TEdit;
    LabelAdjustmentType: TLabel;
    LabelCost: TLabel;
    LabelNotes: TLabel;
    LabelPrice: TLabel;
    LabelProduct: TLabel;
    LabelQuantity: TLabel;
    procedure ButtonCancelClick(Sender: TObject);
    procedure ButtonSaveClick(Sender: TObject);
    procedure ComboBoxProductChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FProductList: TList;
    FDataProduct: TDataProducto;
    procedure LoadProducts;
  public
    { public declarations }
  end;

var
  FormInventoryAdjustment: TFormInventoryAdjustment;

implementation

{$R *.lfm}

{ TFormInventoryAdjustment }

procedure TFormInventoryAdjustment.FormCreate(Sender: TObject);
begin
  Caption := 'Inventory Stock Adjustment (Entries / Outs)';
  ComboBoxAdjustmentType.Items.Clear;
  ComboBoxAdjustmentType.Items.Add('Entry (+) Stock Adjustment');
  ComboBoxAdjustmentType.Items.Add('Out (-) Waste / Damage / Shrinkage');
  ComboBoxAdjustmentType.ItemIndex := 0;

  FDataProduct := TDataProducto.Create(DataModule1.SQLite3Connection1);
  LoadProducts;
end;

procedure TFormInventoryAdjustment.FormDestroy(Sender: TObject);
var
  i: Integer;
begin
  if FProductList <> nil then
  begin
    for i := 0 to FProductList.Count - 1 do
      TProduct(FProductList[i]).Free;
    FProductList.Free;
  end;
  if Assigned(FDataProduct) then FDataProduct.Free;
end;

procedure TFormInventoryAdjustment.LoadProducts;
var
  i: Integer;
  Prod: TProduct;
begin
  FProductList := FDataProduct.find('');
  ComboBoxProduct.Items.Clear;
  for i := 0 to FProductList.Count - 1 do
  begin
    Prod := TProduct(FProductList[i]);
    ComboBoxProduct.Items.Add(Prod.getName() + ' (ID: ' + IntToStr(Prod.getId()) + ')');
  end;

  if ComboBoxProduct.Items.Count > 0 then
  begin
    ComboBoxProduct.ItemIndex := 0;
    ComboBoxProductChange(Self);
  end;
end;

procedure TFormInventoryAdjustment.ComboBoxProductChange(Sender: TObject);
var
  Prod: TProduct;
begin
  if (ComboBoxProduct.ItemIndex >= 0) and (ComboBoxProduct.ItemIndex < FProductList.Count) then
  begin
    Prod := TProduct(FProductList[ComboBoxProduct.ItemIndex]);
    EditPrice.Text := FloatToStr(Prod.getBalance().getPrice());
    EditCost.Text := FloatToStr(Prod.getBalance().getCost());
  end;
end;

procedure TFormInventoryAdjustment.ButtonSaveClick(Sender: TObject);
var
  Prod: TProduct;
  Qty: Integer;
  CostVal, PriceVal: Real;
  Tx: TTransaction;
  Item: TItem;
  DataTx: TDataTransaction;
  OpType: TOperationType;
  BalanceBld: TBalanceBuilder;
  Success: Boolean;
begin
  if ComboBoxProduct.ItemIndex < 0 then
  begin
    ShowMessage('Please select a valid product.');
    Exit;
  end;

  Qty := StrToIntDef(EditQuantity.Text, 0);
  if Qty <= 0 then
  begin
    ShowMessage('Please enter a positive stock quantity.');
    Exit;
  end;

  CostVal := StrToFloatDef(EditCost.Text, 0);
  PriceVal := StrToFloatDef(EditPrice.Text, 0);

  Prod := TProduct(FProductList[ComboBoxProduct.ItemIndex]);

  Tx := TTransaction.Create;
  Tx.setDate(Now);

  if ComboBoxAdjustmentType.ItemIndex = 0 then
    OpType := TOperationType.Create(3, 'Adjustment IN')
  else
    OpType := TOperationType.Create(4, 'Adjustment OUT');

  Tx.setOperationType(OpType);

  Item := TItem.Create;
  Item.setProduct(Prod);
  Item.setStock(Qty);
  Item.setCost(CostVal);
  Item.setPrice(PriceVal);

  Tx.getItemList.Add(Item);

  DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
  DataTx := TDataTransaction.Create(DataModule1.SQLite3Connection1);
  DataTx.getTransaction().StartTransaction;

  Success := False;
  try
    if DataTx.new(Tx) > 0 then
    begin
      BalanceBld := TBalanceBuilder.Create;
      try
        if BalanceBld.build() then
        begin
          DataTx.getTransaction().Commit;
          Success := True;
          ShowMessage('Stock adjustment registered successfully!');
        end
        else
        begin
          DataTx.getTransaction().Rollback;
          ShowMessage('Stock adjustment failed: ' + BalanceBld.getBalanceMessage());
        end;
      finally
        BalanceBld.Free;
      end;
    end
    else
    begin
      DataTx.getTransaction().Rollback;
      ShowMessage('Error saving transaction to database.');
    end;
  finally
    DataTx.Free;
    Tx.Free;
  end;

  if Success then ModalResult := mrOk;
end;

procedure TFormInventoryAdjustment.ButtonCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
