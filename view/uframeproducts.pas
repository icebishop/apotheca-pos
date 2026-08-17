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

unit UFrameProducts;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Grids, StdCtrls, Buttons,
  Dialogs, LCLType, SqlDb,
  UProduct, UDataProduct, UDataModule, UFProduct, UResourceString, UGridUtils;

type

  { TFrameProducts }

  TFrameProducts = class(TFrame)
    EditSearch: TEdit;
    GridProducts: TStringGrid;
    BtnAdd: TBitBtn;
    BtnEdit: TBitBtn;
    BtnDelete: TBitBtn;
    procedure EditSearchChange(Sender: TObject);
    procedure BtnAddClick(Sender: TObject);
    procedure BtnEditClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);
  private
    FProductList: TList;
    procedure LoadProducts(const AFilter: String);
    procedure RefreshGrid;
    procedure FreeProductList;
    procedure InitGrid;
    function GetSelectedProduct: TProduct;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.lfm}

{ TFrameProducts }

constructor TFrameProducts.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FProductList := nil;
  InitGrid;
  LoadProducts('');
end;

destructor TFrameProducts.Destroy;
begin
  FreeProductList;
  inherited Destroy;
end;

procedure TFrameProducts.InitGrid;
begin
  GridProducts.RowCount := 1;
  GridProducts.FixedRows := 1;
  GridProducts.Cells[0, 0] := 'Nombre';
  GridProducts.Cells[1, 0] := 'Existencia';
  GridProducts.Cells[2, 0] := 'Costo';
  GridProducts.Cells[3, 0] := 'Precio';
  DistributeColumns(GridProducts, [40, 15, 20, 25]);
end;

procedure TFrameProducts.FreeProductList;
var
  I: Integer;
begin
  if FProductList <> nil then
  begin
    for I := 0 to FProductList.Count - 1 do
      TProduct(FProductList[I]).Free;
    FProductList.Free;
    FProductList := nil;
  end;
end;

procedure TFrameProducts.LoadProducts(const AFilter: String);
var
  DataProduct: TDataProducto;
  Product: TProduct;
  I: Integer;
  SearchParam: String;
  Trans: TSQLTransaction;
begin
  FreeProductList;

  Trans := TSQLTransaction.Create(nil);
  Trans.DataBase := DataModule1.SQLite3Connection1;
  DataModule1.SQLite3Connection1.Transaction := Trans;
  DataProduct := TDataProducto.Create(DataModule1.SQLite3Connection1);
  try
    if AFilter <> '' then
      SearchParam := '%' + AFilter + '%'
    else
      SearchParam := '%%';

    FProductList := DataProduct.getBalance(SearchParam);

    GridProducts.RowCount := 1; // header only
    if (FProductList <> nil) and (FProductList.Count > 0) then
    begin
      GridProducts.RowCount := FProductList.Count + 1;
      for I := 0 to FProductList.Count - 1 do
      begin
        Product := TProduct(FProductList[I]);
        GridProducts.Cells[0, I + 1] := Product.getName();
        if Product.getBalance() <> nil then
        begin
          GridProducts.Cells[1, I + 1] := IntToStr(Product.getBalance().getStock());
          GridProducts.Cells[2, I + 1] := FormatFloat('0.00', Product.getBalance().getCost());
          GridProducts.Cells[3, I + 1] := FormatFloat('0.00', Product.getBalance().getPrice());
        end
        else
        begin
          GridProducts.Cells[1, I + 1] := '0';
          GridProducts.Cells[2, I + 1] := '0.00';
          GridProducts.Cells[3, I + 1] := '0.00';
        end;
      end;
    end;
  finally
    DataProduct.Free;
  end;
end;

procedure TFrameProducts.RefreshGrid;
var
  Filter: String;
begin
  Filter := Trim(EditSearch.Text);
  LoadProducts(Filter);
end;

procedure TFrameProducts.EditSearchChange(Sender: TObject);
begin
  RefreshGrid;
end;

procedure TFrameProducts.BtnAddClick(Sender: TObject);
var
  FrmProduct: TFormProduct;
begin
  FrmProduct := TFormProduct.Create(Application);
  try
    FrmProduct.setFlagOperation(1); // new
    FrmProduct.ShowModal;
  finally
    FrmProduct.Free;
  end;
  RefreshGrid;
end;

function TFrameProducts.GetSelectedProduct: TProduct;
var
  Row: Integer;
begin
  Result := nil;
  Row := GridProducts.Row;
  if (Row >= 1) and (FProductList <> nil) and (Row <= FProductList.Count) then
    Result := TProduct(FProductList[Row - 1]);
end;

procedure TFrameProducts.BtnEditClick(Sender: TObject);
var
  Product: TProduct;
  FrmProduct: TFormProduct;
begin
  Product := GetSelectedProduct;
  if Product = nil then Exit;

  FrmProduct := TFormProduct.Create(Application);
  try
    FrmProduct.setProduct(Product);
    FrmProduct.setFlagOperation(0); // edit
    FrmProduct.ShowModal;
  finally
    FrmProduct.Free;
  end;
  RefreshGrid;
end;

procedure TFrameProducts.BtnDeleteClick(Sender: TObject);
var
  Product: TProduct;
  DataProduct: TDataProducto;
  ConfirmMsg: String;
  Trans: TSQLTransaction;
begin
  Product := GetSelectedProduct;
  if Product = nil then Exit;

  ConfirmMsg := 'Eliminar Producto: ' + Product.getName() + '?';
  if Application.MessageBox(PChar(ConfirmMsg), PChar(RS_MESSAGE),
     MB_YESNO or MB_ICONQUESTION) = IDYES then
  begin
    Trans := TSQLTransaction.Create(nil);
    Trans.DataBase := DataModule1.SQLite3Connection1;
    DataModule1.SQLite3Connection1.Transaction := Trans;
    DataProduct := TDataProducto.Create(DataModule1.SQLite3Connection1);
    try
      DataProduct.getTransaction().StartTransaction;
      if DataProduct.delete(Product) then
      begin
        DataProduct.getTransaction().Commit;
        Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE), MB_OK);
      end
      else
      begin
        DataProduct.getTransaction().Rollback;
        Application.MessageBox(PChar(RS_OBJECTNOTSAVE),
          PChar(RS_Error), MB_ICONHAND);
      end;
    finally
      DataProduct.Free;
    end;
    RefreshGrid;
  end;
end;

end.
