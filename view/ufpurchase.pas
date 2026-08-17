unit UFPurchase;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
StdCtrls, EditBtn, Grids, Buttons, ActnList, Menus, UFFindProduct, UFProduct,
UItem, UffindSupplier, UPurchase, UDataIn, UDataModule, sqldb, LCLType,
ComCtrls, UBalanceBuilder, UResourceString, UItemValidator, UTransactionValidator;

type

  { TFormPurchase }

TFormPurchase = class(TForm)
    ButtonOk: TBitBtn;
    ButtonCancel: TBitBtn;
    ButtonAddProduct: TBitBtn;
    ButtonDeleteProduct: TBitBtn;
    ButtonSelectSupplier: TBitBtn;
    ButtonSelectProduct: TButton;
    DateEdit: TDateEdit;
    EditSupplier: TEdit;
    LabelSupplier: TLabel;
    LabelDate: TLabel;
    LabelTotal: TLabel;
    MenuItemAdd: TMenuItem;
    MenuItemDelete: TMenuItem;
    PopupMenuProduct: TPopupMenu;
    StaticTotal: TStaticText;
    StatusBarPurchase: TStatusBar;
    StringGridProduct: TStringGrid;

    procedure ActionAgregarExecute(Sender: TObject);
    procedure ButtonCancelClick(Sender: TObject);
    procedure ButtonOkClick(Sender: TObject);
    procedure ButtonAddProductClick(Sender: TObject);
    procedure ButtonDeleteProductClick(Sender: TObject);
    procedure ButtonSelectSupplierClick(Sender: TObject);
    procedure ButtonSelectProductClick(Sender: TObject);
    procedure DateEditChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure MenuItemAddClick(Sender: TObject);
    procedure MenuItemDeleteClick(Sender: TObject);
    procedure StringGridProductEditingDone(Sender: TObject);
    procedure StringGridProductSelectCell(Sender: TObject; aCol, aRow: Integer;
    var CanSelect: Boolean);
private
    { private declarations }
    purchase:TPurchase;
    flagOperacion:Integer;
    itemFlag:Bool;
    procedure loadDataGrid();
    procedure calcularTotal();
    procedure init();

public
    { public declarations }
    procedure setPurchase(newPurchase:TPurchase);
    function getPurchase():TPurchase;
    procedure setFlagOperation(flag:Integer);
end; 

var
Formpurchase: TFormPurchase;

implementation

{ TFormPurchase }



procedure TFormPurchase.StringGridProductEditingDone(Sender: TObject);
var
   item:TItem;
   itemValidator : TItemValidator;
begin

item := TItem (purchase.getItemList()[StringGridProduct.Row-1]);

itemValidator := TItemValidator.Create;
itemValidator.setItem(item);
itemValidator.setOperationType(purchase.getOperationType());
item.setCost(StrToFloat(StringGridProduct.Cells[1,StringGridProduct.Row]));
item.setStock(StrToInt(StringGridProduct.Cells[2,StringGridProduct.Row]));
item.setPrice(StrToFloat(StringGridProduct.Cells[3,StringGridProduct.Row]));

    if StringGridProduct.Col > 0 then
    begin
        if not itemValidator.validate()then
        begin
             //Application.MessageBox(PChar(itemValidator.getMessage()), PChar(RS_Error), MB_ICONWARNING);
             StatusBarPurchase.SimpleText:= itemValidator.getMessage();
             itemValidator.setMessage('');
        end
        else
        begin
             StatusBarPurchase.SimpleText:= '';
             itemFlag:= true;
        end;
    end;

loadDataGrid();
calcularTotal();
end;

procedure TFormPurchase.StringGridProductSelectCell(Sender: TObject; aCol, aRow: Integer;
var CanSelect: Boolean);
var
rect : TRect;
begin


if  (aCol = 0) then
begin
rect := StringGridProduct.CellRect(aCol, aRow);
rect.Left := rect.Left + 200;
ButtonSelectProduct.BoundsRect := rect;
ButtonSelectProduct.Visible:=true;
end
else
begin ButtonSelectProduct.Visible:=false end;


end;

procedure TFormPurchase.FormCreate(Sender: TObject);
begin
StringGridProduct.DefaultRowHeight:=ButtonSelectProduct.Height;
ButtonSelectProduct.Parent := StringGridProduct;
ButtonSelectProduct.Visible:=false;

StringGridProduct.Cells[0, 0] := RS_FMAINSTRINGGRID340;
StringGridProduct.Cells[1, 0] := RS_FMAINSTRINGGRID250;
StringGridProduct.Cells[2, 0] := RS_FMAINSTRINGGRID230;
StringGridProduct.Cells[3, 0] := RS_FMAINSTRINGGRID260;
StringGridProduct.Cells[4,0]  := RS_LTOTAL;

Self.Caption:= RS_DIALOGPURCHASE;
LabelSupplier.Caption:= RS_MSGSUPPLIER;
LabelDate.Caption:= RS_LDATE;
ButtonAddProduct.Caption:= RS_ADD;
ButtonDeleteProduct.Caption:= RS_DELETE;
ButtonOk.Caption:= RS_OK;
ButtonCancel.Caption:= RS_CANCEL;
LabelTotal.Caption:= RS_LTOTAL;

init();
end;

procedure TFormPurchase.init();
begin
if purchase<> nil then
   purchase.init();
purchase := TPurchase.Create;
purchase.setItemList(TList.Create);
purchase.getItemList().Add(TItem.Create);
DateEdit.Date:= Now;
purchase.setDate(DateEdit.Date);
EditSupplier.Text:='';
itemFlag:= false;
loadDataGrid();
calcularTotal();
end;

procedure TFormPurchase.FormShow(Sender: TObject);
begin
    if purchase <> nil then
    begin
         if purchase.getSupplier()<> nil then
                  EditSupplier.Text:= purchase.getSupplier().getName();
         DateEdit.Date:= purchase.getDate();
         loadDataGrid();
         calcularTotal();
    end;
end;

procedure TFormPurchase.MenuItemAddClick(Sender: TObject);
begin
purchase.getItemList().Add(TItem.Create);
loadDataGrid();
calcularTotal();
end;

procedure TFormPurchase.MenuItemDeleteClick(Sender: TObject);
begin
if purchase.getItemList().Count > 0 then
begin
purchase.getItemList().Delete(StringGridProduct.Row-1);
 if purchase.getItemList().Count = 0 then
    itemFlag:=true;
loadDataGrid();
end;
end;

procedure TFormPurchase.ActionAgregarExecute(Sender: TObject);
begin

end;

procedure TFormPurchase.ButtonCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TFormPurchase.ButtonOkClick(Sender: TObject);
var
   dataIn : TDataIn;
   balanceBuilder : TBalanceBuilder;
   transactionValidator : TTransactionValidator;
begin
     transactionValidator := TTransactionValidator.Create;
     transactionValidator.setTransaction(purchase);
     if transactionValidator.confirmBox()then
        if transactionValidator.validate()then
        begin
             balanceBuilder := TBalanceBuilder.Create;
             DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
             dataIn := TDataIn.Create(DataModule1.SQLite3Connection1);
             dataIn.getTransaction().StartTransaction;
             if flagOperacion = 1 then
             begin
                  purchase.calculateNewBalance();
                  if dataIn.new(purchase) > 0 then
                  begin
                       Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE),MB_OK );
                       dataIn.getTransaction().Commit;
                       init();
                  end
                  else
                  begin
                       Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND);
                       dataIn.getTransaction().Rollback;
                  end;
             end
             else
             begin
                  if dataIn.edit(Purchase)  then
                  begin
                       if balanceBuilder.build() then
                       begin
                            dataIn.getTransaction().Commit;
                            Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE), MB_OK);
                       end
                       else
                       begin
                            Application.MessageBox(PChar(RS_OBJECTNOTSAVE+Char(13)+balanceBuilder.getBalanceMessage()), PChar(RS_Error),
                                  MB_ICONHAND);
                            dataIn.getTransaction().Rollback;
                       end;
                  end
                  else
                  begin
                       Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND);
                       dataIn.getTransaction().Rollback;
                  end;
             end;
             balanceBuilder.Free;
             dataIn.free();
        end
        else
        begin
               Application.MessageBox(PChar(transactionValidator.getMessage()), PChar(RS_Error), MB_ICONHAND);
        end;
end;

procedure TFormPurchase.ButtonAddProductClick(Sender: TObject);
begin
 if itemFlag then
 begin
   purchase.getItemList().Add(TItem.Create);
   loadDataGrid();
   calcularTotal();
 end;

end;

procedure TFormPurchase.ButtonDeleteProductClick(Sender: TObject);
begin
MenuItemDeleteClick(Sender);
end;

procedure TFormPurchase.ButtonSelectSupplierClick(Sender: TObject);
var
formFindSupplier : TFormFindSupplier;
begin
formFindSupplier := TFormFindSupplier.Create(Self);
try
formFindSupplier.ShowModal;
Purchase.setSupplier(formFindSupplier.getSupplier());
EditSupplier.Text:= Purchase.getSupplier.getName();
finally
formFindSupplier.Free;
end;

end;

procedure TFormPurchase.ButtonSelectProductClick(Sender: TObject);
var
formProduct : TFormFindProduct;
item :TItem;
begin
formProduct := TFormFindProduct.Create(Self);
try
formProduct.setFlagAllProducts(true);
formProduct.ShowModal;
item := TItem(purchase.getItemList[StringGridProduct.Row-1]);
item.setProduct(formProduct.getProduct());
item.setCost(item.getProduct().getBalance().getCost());
item.setPrice(item.getProduct().getBalance().getPrice());
loadDataGrid();
calcularTotal();
finally
formProduct.Free;
end;
end;

procedure TFormPurchase.DateEditChange(Sender: TObject);
begin
purchase.setDate(DateEdit.Date);
end;

procedure TFormPurchase.loadDataGrid();
var
i:Integer;
item:TItem;
begin
StringGridProduct.Clean([gzNormal,gzFixedRows]);
StringGridProduct.RowCount:= Purchase.getItemList.Count + 1;
for i:=0 to Purchase.getItemList.Count-1 do
begin
item := TItem(Purchase.getItemList[i]);
if item.getProduct() <> nil then
begin StringGridProduct.Cells[0,i+1] := item.getProduct().getName() end;
StringGridProduct.Cells[1,i+1] := FloatToStr(item.getCost());
StringGridProduct.Cells[2,i+1] := IntToStr(item.getStock());
StringGridProduct.Cells[3,i+1] := FloatToStr(item.getPrice());
StringGridProduct.Cells[4,i+1] := FloatToStr(item.getCost()*item.getStock());

end;
end;

procedure TFormPurchase.calcularTotal();
begin
StaticTotal.Caption:= FloatToStr(purchase.getSum());
end;

procedure TFormPurchase.setPurchase(newPurchase:TPurchase);
begin
     Self.purchase := newPurchase;
end;

procedure TFormPurchase.setFlagOperation(flag:Integer);
begin
  Self.flagOperacion:= flag;
end;

function TFormPurchase.getPurchase():TPurchase;
begin
     getPurchase :=  purchase;
end;

initialization
  {$I ufpurchase.lrs}

end.
