unit UFTransaction;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  StdCtrls, Grids, Buttons, EditBtn, Menus, UTransaction, UIn, UOut, UItem;

type

  { TFormTransaction }

  TFormTransaction = class(TForm)
    ButtonOk: TBitBtn;
    DateEdit: TDateEdit;
    EditPerson: TEdit;
    LabelDate: TLabel;
    LabelPerson: TLabel;
    LabelType: TLabel;
    LabelTypeValue: TLabel;
    LabelTotal: TLabel;
    StaticTotal: TStaticText;
    StringGridProduct: TStringGrid;
    procedure ButtonOkClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    transactionIn:TIn;
    transactionOut:TOut;
    transaction:TTransaction;
  public
    procedure setTransaction(newTransaction:TTransaction);
    procedure loadDataGrid();
    procedure calculateTotal();
  end; 

var
  FormTransaction: TFormTransaction;

implementation

   procedure TFormTransaction.FormShow(Sender: TObject);
   begin

     if transaction.getOperationType().getTyp()='in' then
        transactionIn := TIn(transaction)
     else if transaction.getOperationType().getTyp()='out' then
        transactionOut := TOut(transaction);
     EditPerson.Text := transaction.getPerson().getName();
     DateEdit.Date:= transaction.getDate();
     LabelTypeValue.Caption:= transaction.getOperationType().getName();
     loadDataGrid();
     calculateTotal();
   end;

   procedure TFormTransaction.ButtonOkClick(Sender: TObject);
   begin
     Close;
   end;

   procedure TFormTransaction.setTransaction(newTransaction:TTransaction);
   begin
       Self.transaction := newTransaction;
   end;

   procedure TFormTransaction.loadDataGrid();
   var
      i:Integer;
      item:TItem;
   begin
        StringGridProduct.RowCount:= transaction.getItemList.Count + 1;
        for i:=0 to transaction.getItemList.Count-1 do
        begin
             item := TItem(transaction.getItemList[i]);
             if item.getProduct() <> nil then
             begin
                  StringGridProduct.Cells[0,i+1] := item.getProduct().getName()
             end;
        StringGridProduct.Cells[1,i+1] := FloatToStr(item.getCost());
        StringGridProduct.Cells[2,i+1] := IntToStr(item.getStock());
        StringGridProduct.Cells[3,i+1] := FloatToStr(item.getPrice());
        if transactionIn <> nil then
                StringGridProduct.Cells[4,i+1] := FloatToStr(item.getCost()*item.getStock())
        else if transactionOut <> nil then
                StringGridProduct.Cells[4,i+1] := FloatToStr(item.getPrice()*item.getStock())
        end;
   end;

   procedure TFormTransaction.calculateTotal();
   begin
        if transactionIn <> nil then
             StaticTotal.Caption:= FloatToStr(transactionIn.getSum())
        else if transactionOut <> nil then
             StaticTotal.Caption:= FloatToStr(transactionOut.getSum());;
   end;

initialization
  {$I uftransaction.lrs}

end.

