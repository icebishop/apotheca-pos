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

unit UFFindProduct;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
Grids, StdCtrls, Buttons, UDataModule, UDataProduct ,UProduct, UFProduct,sqldb,
UResourceString;

type

  { TFormFindProduct }

TFormFindProduct = class(TForm)
BitBtnNew: TBitBtn;
BitBtnCancel: TBitBtn;
BitBtnOk: TBitBtn;
EditFind: TEdit;
StringGridProduct: TStringGrid;
procedure BitBtnNewClick(Sender: TObject);
procedure BitBtnCancelClick(Sender: TObject);
procedure BitBtnOkClick(Sender: TObject);
procedure EditFindKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
procedure FormCreate(Sender: TObject);
procedure FormShow(Sender: TObject);
procedure StringGridProductClick(Sender: TObject);
private
    { private declarations }
listproduct:TList;
product : TProduct;
flagAction:Integer;
flagAllProducts:boolean;
procedure loadDataGrid();
procedure loadData();

public
    { public declarations }
function getProduct():TProduct;
function getFlagAction():Integer;
procedure setFlagAllProducts(newFlagAllProducts:boolean);
end; 

var
FormFindProduct: TFormFindProduct;

implementation

{ TFormFindProduct }

procedure TFormFindProduct.setFlagAllProducts(newFlagAllProducts:boolean);
begin
     flagAllProducts:= newFlagAllProducts;
end;

procedure TFormFindProduct.FormCreate(Sender: TObject);
begin
     BitBtnCancel.Caption := RS_CANCEL;
     BitBtnOk.Caption     := RS_OK;
     Self.Caption         := RS_LFINDPRODUCTS;
     BitBtnNew.Caption    := RS_NEW;
end;

procedure TFormFindProduct.FormShow(Sender: TObject);
begin
  loadData();
  loadDataGrid();
  flagAction:= 0;
end;

procedure TFormFindProduct.loadData();
var
dataProduct : TDataProducto;
begin
DataModule1.EnsureTransaction;
dataProduct := TDataProducto.Create(DataModule1.SQLite3Connection1);
if flagAllProducts then
   listproduct := dataProduct.find('%'+EditFind.Text+'%')
else
   listproduct := dataProduct.findInStock('%'+EditFind.Text+'%');
dataProduct.free();
end;

procedure TFormFindProduct.BitBtnNewClick(Sender: TObject);
var
formProduct : TFormProduct;
begin
formProduct := TFormProduct.Create(Self);
try
formProduct.setFlagOperation(1);
formProduct.ShowModal;
loadData();
loadDataGrid();
StringGridProduct.Row:= StringGridProduct.RowCount-1;
finally
formProduct.Free;
end;

end;

procedure TFormFindProduct.BitBtnCancelClick(Sender: TObject);
begin
flagAction := 0;
product.Free;
product := nil;
Close;
end;

procedure TFormFindProduct.BitBtnOkClick(Sender: TObject);
begin
StringGridProductClick(Sender);
flagAction:= 1;
Close;
end;

procedure TFormFindProduct.EditFindKeyUp(Sender: TObject; var Key: Word;
Shift: TShiftState);
begin
loadData();
loadDataGrid();
end;

procedure TFormFindProduct.StringGridProductClick(Sender: TObject);
begin
product := TProduct(listproduct[StringGridProduct.Row-1]);
flagAction:=1;
Close;
end;

procedure TFormFindProduct.loadDataGrid();
var
c:Integer;
begin
StringGridProduct.Clean;
StringGridProduct.RowCount:= listproduct.Count+1;
StringGridProduct.Cells[0,0]:= RS_LPRODUCTS;
For c := 0 to listproduct.Count -1 do
begin
product := TProduct (listproduct[c]);
StringGridProduct.Cells[0,c+1]:= product.getName();
end;
end;

function TFormFindProduct.getProduct():TProduct;
begin
getProduct := Self.product;
end;


function TFormFindProduct.getFlagAction():Integer;
begin
getFlagAction := flagAction;
end;
initialization
  {$I uffindproduct.lrs}

end.
