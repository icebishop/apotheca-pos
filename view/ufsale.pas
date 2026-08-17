unit UFSale;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
StdCtrls, Grids, Buttons, EditBtn, Menus, USale, UItem, UDataOut, sqldb,
UDataModule,LCLType, ComCtrls, UFFindCustomer, UFFindProduct, UBalanceBuilder,
UResourceString, UTransactionValidator, UProductValidator, UItemValidator;

type

  { TFormSale }

TFormSale = class(TForm)
      BitBtnOk: TBitBtn;
      BitBtnCancel: TBitBtn;
      BitBtnAdd: TBitBtn;
      BitBtnDelete: TBitBtn;
      BitBtnCustomer: TBitBtn;
      ButtonProduct: TButton;
      DateEdit: TDateEdit;
      EditCustomer: TEdit;
      LabelCustomer: TLabel;
      LabelDate: TLabel;
      LabelTotal: TLabel;
      MenuItemAdd: TMenuItem;
      MenuItemDelete: TMenuItem;
      PopupMenuOperation: TPopupMenu;
      StaticTextTotal: TStaticText;
      StatusBarSale: TStatusBar;
      StringGridProduct: TStringGrid;
      procedure BitBtnCancelClick(Sender: TObject);
      procedure BitBtnOkClick(Sender: TObject);
      procedure BitBtnAddClick(Sender: TObject);
      procedure BitBtnDeleteClick(Sender: TObject);
      procedure BitBtnCustomerClick(Sender: TObject);
      procedure ButtonProductClick(Sender: TObject);
      procedure DateEditChange(Sender: TObject);
      procedure EditUnitsChange(Sender: TObject);
      procedure EditUnitsEditingDone(Sender: TObject);
      procedure FormCreate(Sender: TObject);
      procedure FormShow(Sender: TObject);
      procedure MenuItemAddClick(Sender: TObject);
      procedure MenuItemDeleteClick(Sender: TObject);
      procedure StringGridProductEditingDone(Sender: TObject);
      procedure StringGridProductSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
    private
    { private declarations }
      sale:TSale;
      saleValidator : TTransactionValidator;
      productValidator : TProductValidator;
      flagOperation:Integer;
      procedure loadDataGrid();
      procedure calculateTotal();
    public
    { public declarations }
      procedure setFlagOperation(flag:Integer);
      procedure setSale(newSale:TSale);
      function getSale():Tsale;

end; 

var
FormSale: TFormSale;

implementation

{ TFormSale }

procedure TFormSale.loadDataGrid();
var
   i:Integer;
   item:TItem;
begin
     StringGridProduct.RowCount:= sale.getItemList.Count + 1;
     for i:=0 to sale.getItemList.Count-1 do
     begin
          item := TItem(sale.getItemList[i]);
          if item.getProduct() <> nil then
          begin
               StringGridProduct.Cells[0,i+1] := item.getProduct().getName()
          end;
                StringGridProduct.Cells[1,i+1] := FloatToStr(item.getPrice());
                StringGridProduct.Cells[2,i+1] := IntToStr(item.getStock());
                StringGridProduct.Cells[3,i+1] := FloatToStr(item.getPrice()*item.getStock());
     end;
end;

procedure TFormSale.calculateTotal();
begin
     StaticTextTotal.Caption:= FloatToStr(sale.getSum());
end;

procedure TFormSale.MenuItemDeleteClick(Sender: TObject);
begin
     if sale.getItemList().Count > 0 then
     begin
          sale.getItemList().Delete(StringGridProduct.Row-1);
          loadDataGrid();
     end;
end;

procedure TFormSale.FormCreate(Sender: TObject);
begin
     Self.Caption:= RS_LSALES ;
     LabelCustomer.Caption:= RS_LCUSTOMER;
     LabelDate.Caption:= RS_LDATE;
     LabelTotal.Caption:= RS_LTOTAL;
     BitBtnAdd.Caption:= RS_ADD;
     BitBtnDelete.Caption:= RS_DELETE;
     BitBtnCancel.Caption := RS_CANCEL;
     BitBtnOk.Caption:= RS_OK;
     MenuItemAdd.Caption:= RS_ADD;
     MenuItemDelete.Caption:= RS_DELETE;
     StringGridProduct.Cells[0, 0] := RS_FMAINSTRINGGRID340;
     StringGridProduct.Cells[1, 0] := RS_FMAINSTRINGGRID250;
     StringGridProduct.Cells[2, 0] := RS_FMAINSTRINGGRID230;
     StringGridProduct.Cells[3,0] := RS_LTOTAL;


     saleValidator := TTransactionValidator.Create;
     productValidator := TProductValidator.Create;
     StringGridProduct.DefaultRowHeight:=ButtonProduct.Height;
     ButtonProduct.Parent := StringGridProduct;
     ButtonProduct.Visible:=true;
     sale := TSale.Create;
     sale.setItemList(TList.Create);
     sale.getItemList().Add(TItem.Create);
     DateEdit.Date:= Now;;
     loadDataGrid();
     calculateTotal();



end;

procedure TFormSale.FormShow(Sender: TObject);
begin
  if sale.getCustomer() <> nil then
    EditCustomer.Text:= sale.getCustomer().getName();
  loadDataGrid();
  calculateTotal();
end;

procedure TFormSale.BitBtnAddClick(Sender: TObject);
begin
     sale.getItemList().Add(TItem.Create);
     loadDataGrid();
     calculateTotal();
end;

procedure TFormSale.BitBtnDeleteClick(Sender: TObject);
begin
     MenuItemDeleteClick(Sender);
end;

procedure TFormSale.BitBtnCustomerClick(Sender: TObject);
var
   formFindCustomer : TFormFindCustomer;
begin
     formFindCustomer := TFormFindCustomer.Create(Self);
     try
        formFindCustomer.ShowModal;
        sale.setCustomer(formFindCustomer.getCustomer());
        EditCustomer.Text:= sale.getCustomer.getName();
     finally
            formFindCustomer.Free;
     end;
end;

procedure TFormSale.ButtonProductClick(Sender: TObject);
var
   formProduct : TFormFindProduct;
   item :TItem;
begin
     formProduct := TFormFindProduct.Create(Self);
     try
        formProduct.setFlagAllProducts(false);
        formProduct.ShowModal;
        if formProduct.getFlagAction() = 1 then
        begin
             item := TItem(sale.getItemList[StringGridProduct.Row-1]);
             item.setProduct(formProduct.getProduct());
             item.setPrice(formProduct.getProduct().getBalance().getPrice());
             item.setCost(formProduct.getProduct().getBalance().getCost());
             loadDataGrid();
             calculateTotal();
        end;
     finally
            formProduct.Free;
     end;
end;

procedure TFormSale.DateEditChange(Sender: TObject);
begin
     sale.setDate(DateEdit.Date);
end;

procedure TFormSale.EditUnitsChange(Sender: TObject);
begin

end;

procedure TFormSale.EditUnitsEditingDone(Sender: TObject);

begin

end;


procedure TFormSale.BitBtnOkClick(Sender: TObject);
var
   dataOut : TDataOut;
   balanceBuilder : TBalanceBuilder;
begin
{ TODO 1 -odiego -cerror : Limpiar los datos de la transaccion al guardar }
{ TODO 1 -odiego -cerror : Validar que el stock sea positivo al guardar }

     if saleValidator.confirmBox() then
     begin
     saleValidator.setTransaction(sale);
     if saleValidator.validate() then
     begin
          balanceBuilder := TBalanceBuilder.Create;
          DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
          dataOut := TDataOut.Create(DataModule1.SQLite3Connection1);
          dataOut.getTransaction().StartTransaction;
          if flagOperation = 1 then
          begin
               sale.calculateNewBalance();
               if dataOut.new(sale) > 0 then
               begin
                    Application.MessageBox('El objeto ha sido Guardado', 'Mensaje',MB_OK );
                    dataOut.getTransaction().Commit;
               end
               else
               begin
                    Application.MessageBox('El objeto no ha sido Guardado', 'Error', MB_ICONHAND);
                    dataOut.getTransaction().Rollback;
               end;
          end
          else
          begin
               if dataOut.edit(sale)  then
               begin
                    if balanceBuilder.build()then
                    begin
                         dataOut.getTransaction().Commit;
                         Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE), MB_OK);
                    end
                    else
                    begin
                         Application.MessageBox(PChar(RS_OBJECTNOTSAVE+Char(13)+balanceBuilder.getBalanceMessage()), PChar(RS_Error),
                                  MB_ICONHAND);
                         dataOut.getTransaction().Rollback;
                    end;
               end
               else
               begin
               Application.MessageBox(PChar(RS_OBJECTNOTSAVE),  PChar(RS_Error), MB_ICONHAND);
               dataOut.getTransaction().Rollback;
               end;
          end;
          dataOut.free();
          balanceBuilder.Free;
     end
     else
         Application.MessageBox(PChar(saleValidator.getMessage()), PChar(RS_Error), MB_ICONWARNING);
     end;

end;

procedure TFormSale.BitBtnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TFormSale.MenuItemAddClick(Sender: TObject);
begin
    sale.getItemList().Add(TItem.Create);
     loadDataGrid();
     calculateTotal();
end;

procedure TFormSale.StringGridProductEditingDone(Sender: TObject);
var
   item:TItem;
   itemValidator : TItemValidator;
begin
     item := TItem (sale.getItemList()[StringGridProduct.Row-1]);
     item.setPrice(StrToFloat(StringGridProduct.Cells[1,StringGridProduct.Row]));
     item.setStock(StrToInt(StringGridProduct.Cells[2,StringGridProduct.Row]));
     itemValidator := TItemValidator.Create;
     itemValidator.setItem(item);
     itemValidator.setOperationType(sale.getOperationType());
     productValidator.setProduct(item.getProduct());
     StatusBarSale.SimpleText :='';
     if StringGridProduct.Col > 1 then
     begin
          if itemValidator.validate()  then
          begin
               if not productValidator.hasStock(item.getStock()) then
               begin
                    StatusBarSale.SimpleText := productValidator.getMessage();
                    productValidator.setMessage('');
                    StringGridProduct.Col := 2;
               end;
          end
          else
          begin
               StatusBarSale.SimpleText := itemValidator.getMessage();
               itemValidator.setMessage('');
               StringGridProduct.Col := 1;
          end;
     end;
     itemValidator.Free;
     loadDataGrid();
     calculateTotal();
end;

procedure TFormSale.StringGridProductSelectCell(Sender: TObject; aCol, aRow: Integer;
var CanSelect: Boolean);
var
   rect : TRect;
begin
     if  (aCol = 0) then
     begin
          rect := StringGridProduct.CellRect(aCol, aRow);
          rect.Left := rect.Left + 200;
          ButtonProduct.BoundsRect := rect;
          ButtonProduct.Visible:=true;
     end ;

     if  (aCol <> 0) then
     begin
          ButtonProduct.Visible:=false
     end;

end;

procedure TFormSale.setFlagOperation(flag:Integer);
begin
  Self.flagOperation:= flag;
end;

procedure TFormSale.setSale(newSale:TSale);
begin
   sale := newSale;
end;

function TFormSale.getSale():Tsale;
begin
     getSale := sale;
end;

initialization
  {$I ufsale.lrs}

end.
