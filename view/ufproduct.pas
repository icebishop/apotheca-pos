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
  ExtCtrls, StdCtrls, Buttons, Uproduct, UDataProduct, UDataImage,
  UPngValidator, LCLType,
  UDataModule, SqlDb, UProductValidator, UResourceString, LazLogger;

type

  { TFormProduct }

  TFormProduct = class(TForm)
    BitBtnOk: TBitBtn;
    BitBtnCancel: TBitBtn;
    BtnSelectImage: TBitBtn;
    ChkIsService: TCheckBox;
    EditName: TEdit;
    EditMinStock: TEdit;
    EditMaxStock: TEdit;
    EditOriginalPrice: TEdit;
    EditCategory: TEdit;
    EditBrand: TEdit;
    EditCondition: TEdit;
    EditGoogleCat: TEdit;
    MemoDescription: TMemo;
    LabelName: TLabel;
    LabelMinStock: TLabel;
    LabelMaxStock: TLabel;
    LabelOriginalPrice: TLabel;
    LabelCategory: TLabel;
    LabelBrand: TLabel;
    LabelCondition: TLabel;
    LabelGoogleCat: TLabel;
    LabelDescription: TLabel;
    LblImageStatus: TLabel;
    GroupBoxPreview: TGroupBox;
    ImagePreview: TImage;
    procedure BitBtnOkClick(Sender: TObject);
    procedure BitBtnCancelClick(Sender: TObject);
    procedure BtnSelectImageClick(Sender: TObject);
    procedure EditMaxStockExit(Sender: TObject);
    procedure EditNameExit(Sender: TObject);
    procedure EditMinStockExit(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private
    product: TProduct;
    flagOperacion: Integer;
    flagAction: Integer;
    productValidator: TProductValidator;
    FPendingImageData: TBytes;
    FHasPendingImage: Boolean;
  public
    function getProduct(): TProduct;
    procedure setProduct(newProduct: TProduct);
    function getFlagAction(): Integer;
    procedure setFlagOperation(flag: Integer);
  end;

var
  FormProduct: TFormProduct;

implementation

procedure TFormProduct.BitBtnOkClick(Sender: TObject);
var
  dataProduct: TDataProducto;
  dataImage: TDataImage;
  imageId: Integer;
begin
  try
  product.setName(EditName.Text);
  product.setMinstock(StrToInt(EditMinStock.Text));
  product.setMaxstock(StrToInt(EditMaxStock.Text));
  product.setOriginalPrice(StrToFloatDef(EditOriginalPrice.Text, 0.0));
  product.setCategory(EditCategory.Text);
  product.setBrand(EditBrand.Text);
  product.setProductCondition(EditCondition.Text);
  product.setGoogleProductCategory(EditGoogleCat.Text);
  product.setDescription(MemoDescription.Lines.Text);
  product.setIsService(ChkIsService.Checked);

  if productValidator.validate() then
  begin
    DataModule1.EnsureTransaction;
    dataProduct := TDataProducto.Create(DataModule1.SQLite3Connection1);
if not     dataProduct.getTransaction().Active then     dataProduct.getTransaction().StartTransaction;

    if flagOperacion = 1 then
    begin
      if dataProduct.new(product) > 0 then
      begin
        // Store pending image if any
        if FHasPendingImage and (Length(FPendingImageData) > 0) then
        begin
          dataImage := TDataImage.Create(DataModule1.SQLite3Connection1);
          try
            imageId := dataImage.Store(product.getId(), FPendingImageData);
            if imageId > 0 then
              product.setImageRef(imageId);
            dataProduct.edit(product);
          finally
            dataImage.getQuery().Free;
          end;
        end;
        Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE), MB_OK);
      end
      else
        Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND);
    end
    else
    begin
      // Store pending image if any
      if FHasPendingImage and (Length(FPendingImageData) > 0) then
      begin
        dataImage := TDataImage.Create(DataModule1.SQLite3Connection1);
        try
          if product.getImageRef() > 0 then
            dataImage.Update(product.getImageRef(), FPendingImageData)
          else
          begin
            imageId := dataImage.Store(product.getId(), FPendingImageData);
            if imageId > 0 then
              product.setImageRef(imageId);
          end;
        finally
          dataImage.getQuery().Free;
        end;
      end;

      if dataProduct.edit(product) then
        Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE), MB_OK)
      else
        Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND);
    end;

    dataProduct.getTransaction().Commit;
    Close;
  end
  else
    Application.MessageBox(PChar(productValidator.getMessage()), PChar(RS_Error), MB_ICONWARNING);
  except
    on E: Exception do DebugLn('[TFormProduct.BitBtnOkClick] ERROR: ' + E.Message);
  end;
end;

procedure TFormProduct.BtnSelectImageClick(Sender: TObject);
var
  Dlg: TOpenDialog;
  FS: TFileStream;
  ValidationError: String;
  Stream: TBytesStream;
  Png: TPortableNetworkGraphic;
begin
  try
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := 'Select PNG image';
    Dlg.Filter := 'PNG images (*.png)|*.png';
    if not Dlg.Execute then
      Exit;

    try
      FS := TFileStream.Create(Dlg.FileName, fmOpenRead or fmShareDenyNone);
      try
        SetLength(FPendingImageData, FS.Size);
        if FS.Size > 0 then
          FS.Read(FPendingImageData[0], FS.Size);
      finally
        FS.Free;
      end;
    except
      on E: Exception do
      begin
        LblImageStatus.Caption := 'Error: ' + E.Message;
        ImagePreview.Picture.Clear;
        Exit;
      end;
    end;

    ValidationError := TPngValidator.GetValidationError(FPendingImageData);
    if ValidationError <> '' then
    begin
      LblImageStatus.Caption := ValidationError;
      SetLength(FPendingImageData, 0);
      FHasPendingImage := False;
      ImagePreview.Picture.Clear;
      Exit;
    end;

    FHasPendingImage := True;
    LblImageStatus.Caption := 'Image selected: ' + ExtractFileName(Dlg.FileName);

    try
      Stream := TBytesStream.Create(FPendingImageData);
      try
        Png := TPortableNetworkGraphic.Create;
        try
          Png.LoadFromStream(Stream);
          ImagePreview.Picture.Graphic := Png;
        finally
          Png.Free;
        end;
      finally
        Stream.Free;
      end;
    except
      on E: Exception do
      begin
        LblImageStatus.Caption := 'Preview error: ' + E.Message;
        ImagePreview.Picture.Clear;
      end;
    end;
  finally
    Dlg.Free;
  end;
  except
    on E: Exception do DebugLn('[TFormProduct.BtnSelectImageClick] ERROR: ' + E.Message);
  end;
end;

procedure TFormProduct.BitBtnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TFormProduct.EditMaxStockExit(Sender: TObject);
begin
  try
  productValidator.setMessage('');
  if not productValidator.isNumber(EditMaxStock.Text) then
  begin
    Application.MessageBox(PChar(productValidator.getMessage()), PChar(RS_MSGWARNING), MB_ICONWARNING);
    EditMaxStock.Text := '0';
  end;
  except
    on E: Exception do DebugLn('[TFormProduct.EditMaxStockExit] ERROR: ' + E.Message);
  end;
end;

procedure TFormProduct.EditNameExit(Sender: TObject);
begin
  try
  productValidator.setMessage('');
  product.setName(EditName.Text);
  if not productValidator.hasName() then
    Application.MessageBox(PChar(productValidator.getMessage()), PChar(RS_MSGWARNING), MB_ICONWARNING);
  except
    on E: Exception do DebugLn('[TFormProduct.EditNameExit] ERROR: ' + E.Message);
  end;
end;

procedure TFormProduct.EditMinStockExit(Sender: TObject);
begin
  try
  productValidator.setMessage('');
  if not productValidator.isNumber(EditMinStock.Text) then
  begin
    Application.MessageBox(PChar(productValidator.getMessage()), PChar(RS_MSGWARNING), MB_ICONWARNING);
    EditMinStock.Text := '0';
  end;
  except
    on E: Exception do DebugLn('[TFormProduct.EditMinStockExit] ERROR: ' + E.Message);
  end;
end;

procedure TFormProduct.FormCreate(Sender: TObject);
begin
  BitBtnOk.Caption := RS_OK;
  BitBtnCancel.Caption := RS_CANCEL;
  LabelName.Caption := RS_LDESCRIPTION;
  LabelMaxStock.Caption := RS_LMAXSTOCK;
  LabelMinStock.Caption := RS_LMINSTOCK;
  Self.Caption := RS_LPRODUCTS;

  flagAction := 0;
  FHasPendingImage := False;
  SetLength(FPendingImageData, 0);
  ImagePreview.Picture.Clear;
  if product = nil then
    product := TProduct.Create;
  productValidator := TProductValidator.Create;
end;

procedure TFormProduct.FormShow(Sender: TObject);
var
  DataImage: TDataImage;
  ImageData: TBytes;
  Stream: TBytesStream;
  Png: TPortableNetworkGraphic;
begin
  try
  if product <> nil then
  begin
    EditName.Text := product.getName();
    EditMinStock.Text := IntToStr(product.getMinStock());
    EditMaxStock.Text := IntToStr(product.getMaxStock());
    EditOriginalPrice.Text := FormatFloat('0', product.getOriginalPrice());
    EditCategory.Text := product.getCategory();
    EditBrand.Text := product.getBrand();
    EditCondition.Text := product.getProductCondition();
    EditGoogleCat.Text := product.getGoogleProductCategory();
    MemoDescription.Lines.Text := product.getDescription();
    ChkIsService.Checked := product.getIsService();
    if product.getImageRef() > 0 then
    begin
      LblImageStatus.Caption := 'Image ID: ' + IntToStr(product.getImageRef());
      DataImage := TDataImage.Create(DataModule1.SQLite3Connection1);
      try
        ImageData := DataImage.Get(product.getImageRef());
        if Length(ImageData) > 0 then
        begin
          Stream := TBytesStream.Create(ImageData);
          try
            Png := TPortableNetworkGraphic.Create;
            try
              Png.LoadFromStream(Stream);
              ImagePreview.Picture.Graphic := Png;
            finally
              Png.Free;
            end;
          finally
            Stream.Free;
          end;
        end
        else
          ImagePreview.Picture.Clear;
      finally
        DataImage.getQuery().Free;
      end;
    end
    else
    begin
      LblImageStatus.Caption := '';
      ImagePreview.Picture.Clear;
    end;
  end;
  productValidator.setProduct(product);
  except
    on E: Exception do DebugLn('[TFormProduct.FormShow] ERROR: ' + E.Message);
  end;
end;

function TFormProduct.getProduct(): TProduct;
begin
  getProduct := Self.product;
end;

procedure TFormProduct.setProduct(newProduct: TProduct);
begin
  Self.product := newProduct;
end;

procedure TFormProduct.setFlagOperation(flag: Integer);
begin
  Self.flagOperacion := flag;
end;

function TFormProduct.getFlagAction(): Integer;
begin
  getFlagAction := flagAction;
end;

initialization
  {$I ufproduct.lrs}

end.
