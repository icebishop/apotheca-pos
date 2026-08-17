{ Apothêca

  Copyright (C) 2010 Ice icebishop@gmail.com

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
}

unit UFProduct;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, Buttons, Uproduct, UDataProduct, LCLType,
  UDataModule, SqlDb, UProductValidator, UResourceString;

type

  { TFormProduct }

  TFormProduct = class(TForm)
    BitBtnOk: TBitBtn;
    BitBtnCancel: TBitBtn;
    EditName: TEdit;
    EditMinStock: TEdit;
    EditMaxStock: TEdit;
    LabelName: TLabel;
    LabelMinStock: TLabel;
    LabelMaxStock: TLabel;
    procedure BitBtnOkClick(Sender: TObject);
    procedure BitBtnCancelClick(Sender: TObject);
    procedure EditMaxStockExit(Sender: TObject);
    procedure EditNameExit(Sender: TObject);
    procedure EditMinStockExit(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    { private declarations }
    product:TProduct;
    flagOperacion:Integer;
    flagAction:Integer;
    productValidator : TProductValidator;
  public
    { public declarations }
    function getProduct():TProduct;
    procedure setProduct(newProduct:TProduct);
    function getFlagAction():Integer;
    procedure setFlagOperation(flag:Integer);
  end; 

var
  FormProduct: TFormProduct;

implementation

procedure TFormProduct.BitBtnOkClick(Sender: TObject);
var
   dataProduct : TDataProducto;
begin
     product.setName(EditName.Text);
     product.setMinstock(StrToInt(EditMinStock.Text));
     product.setMaxstock(StrToInt(EditMaxStock.Text));

     if productValidator.validate() then
     begin

     DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
     dataProduct := TDataProducto.Create(DataModule1.SQLite3Connection1);
     dataProduct.getTransaction().StartTransaction;

     if flagOperacion  = 1 then
     begin
        if dataProduct.new(product) > 0 then
           Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE),MB_OK )
        else
           Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND);
     end
     else
        if dataProduct.edit(product) then
           Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE),MB_OK )
        else
           Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND);
     begin
     end;

     dataProduct.getTransaction().Commit;
     Close;

     end
     else
         Application.MessageBox(PChar(productValidator.getMessage()), PChar(RS_Error), MB_ICONWARNING);
end;

procedure TFormProduct.BitBtnCancelClick(Sender: TObject);
begin
  { TODO 1 -odiego -cerror : Verificar la validacion del producto la salir del formulario }
  Close;
end;

procedure TFormProduct.EditMaxStockExit(Sender: TObject);
begin
  productValidator.setMessage('');
  if not productValidator.isNumber(EditMaxStock.Text) then
  begin
       Application.MessageBox( PChar(productValidator.getMessage()),PChar(RS_MSGWARNING),
                               MB_ICONWARNING);
       EditMaxStock.Text:='0';
  end;
end;

procedure TFormProduct.EditNameExit(Sender: TObject);
begin
  productValidator.setMessage('');
  product.setName(EditName.Text);
  if not productValidator.hasName() then
     Application.MessageBox( PChar(productValidator.getMessage()),PChar(RS_MSGWARNING),
       MB_ICONWARNING);
end;

procedure TFormProduct.EditMinStockExit(Sender: TObject);
begin
  productValidator.setMessage('');
  if not productValidator.isNumber(EditMinStock.Text) then
  begin
       Application.MessageBox( PChar(productValidator.getMessage()),PChar(RS_MSGWARNING),
                               MB_ICONWARNING);
       EditMinStock.Text:='0'
  end;
end;

procedure TFormProduct.FormCreate(Sender: TObject);
begin
    BitBtnOk.Caption := RS_OK;
    BitBtnCancel.Caption:= RS_CANCEL;

    LabelName.Caption:= RS_LDESCRIPTION;
    LabelMaxStock.Caption:= RS_LMAXSTOCK;
    LabelMinStock.Caption := RS_LMINSTOCK;

    Self.Caption:=RS_LPRODUCTS;


    flagAction:= 0;
    if product = nil then
     begin
        product := TProduct.Create;
     end;
     productValidator := TProductValidator.Create;

end;

procedure TFormProduct.FormShow(Sender: TObject);
begin
  if product <> nil then
  begin
       EditName.Text:= product.getName();
       EditMinStock.Text:= IntToStr(product.getMinStock());
       EditMaxStock.Text:= IntToStr(product.getMaxStock());
  end;
   productValidator.setProduct(product);
end;

function TFormProduct.getProduct():TProduct;
begin
   getProduct := Self.product;
end;

procedure TFormProduct.setProduct(newProduct:TProduct);
begin
  Self.product := newProduct;
end;


procedure TFormProduct.setFlagOperation(flag:Integer);
begin
  Self.flagOperacion:= flag;
end;

function TFormProduct.getFlagAction():Integer;
begin
 getFlagAction := flagAction;
end;

initialization
  {$I ufproduct.lrs}

end.

