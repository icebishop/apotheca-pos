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
  UDataGoogleCategory, UPngValidator, LCLType,
  UDataModule, SqlDb, UProductValidator, UResourceString, LazLogger;

type

  { TFormProduct }

  TFormProduct = class(TForm)
    BitBtnOk: TBitBtn;
    BitBtnCancel: TBitBtn;
    BtnAddImage: TBitBtn;
    BtnRemoveImage: TBitBtn;
    GroupBoxImages: TGroupBox;
    ListImages: TListBox;
    ChkIsService: TCheckBox;
    EditName: TEdit;
    EditMinStock: TEdit;
    EditMaxStock: TEdit;
    EditOriginalPrice: TEdit;
    EditCategory: TEdit;
    EditBrand: TEdit;
    EditCondition: TEdit;
    EditGoogleCat: TComboBox;
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
    procedure BtnAddImageClick(Sender: TObject);
    procedure BtnRemoveImageClick(Sender: TObject);
    procedure ListImagesClick(Sender: TObject);
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
    { Working set of images for the product being edited. FImageData[i] holds
      the PNG bytes for list entry i (loaded from DB for existing images, or
      read from disk for newly added ones). Order follows ListImages. }
    FImageData: array of TBytes;
    procedure LoadGoogleCategories;
    procedure ClearImageWorkingSet;
    procedure AddImageEntry(const PngData: TBytes; const EntryLabel: String);
    procedure RemoveImageEntryAt(index: Integer);
    procedure ShowImagePreview(index: Integer);
    procedure UpdateImageStatus;
    procedure SaveProductImages(dataProduct: TDataProducto);
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
  { Persist a newly typed category so it appears in the list next time. }
  if Trim(EditGoogleCat.Text) <> '' then
    with TDataGoogleCategory.Create(DataModule1.SQLite3Connection1) do
      try
        EnsureExists(EditGoogleCat.Text);
      finally
        Destroy;
      end;
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
        { Persist all images (array) now that the product has an id. }
        SaveProductImages(dataProduct);
        dataProduct.edit(product);
        Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE), MB_OK);
      end
      else
        Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND);
    end
    else
    begin
      { Rewrite the full image set so additions/removals/reorders persist. }
      SaveProductImages(dataProduct);

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

procedure TFormProduct.ClearImageWorkingSet;
begin
  SetLength(FImageData, 0);
  ListImages.Items.Clear;
  ImagePreview.Picture.Clear;
end;

procedure TFormProduct.AddImageEntry(const PngData: TBytes; const EntryLabel: String);
var
  len: Integer;
begin
  len := Length(FImageData);
  SetLength(FImageData, len + 1);
  FImageData[len] := Copy(PngData, 0, Length(PngData));
  ListImages.Items.Add(EntryLabel);
end;

procedure TFormProduct.RemoveImageEntryAt(index: Integer);
var
  i: Integer;
begin
  if (index < 0) or (index >= Length(FImageData)) then
    Exit;
  for i := index to High(FImageData) - 1 do
    FImageData[i] := FImageData[i + 1];
  SetLength(FImageData, Length(FImageData) - 1);
  ListImages.Items.Delete(index);
end;

procedure TFormProduct.ShowImagePreview(index: Integer);
var
  Stream: TBytesStream;
  Png: TPortableNetworkGraphic;
begin
  if (index < 0) or (index >= Length(FImageData)) or
     (Length(FImageData[index]) = 0) then
  begin
    ImagePreview.Picture.Clear;
    Exit;
  end;
  try
    Stream := TBytesStream.Create(FImageData[index]);
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
      LblImageStatus.Caption := Format(RS_PRODUCT_IMG_PREVIEW_ERROR, [E.Message]);
      ImagePreview.Picture.Clear;
    end;
  end;
end;

procedure TFormProduct.UpdateImageStatus;
begin
  LblImageStatus.Caption := Format(RS_PRODUCT_IMG_COUNT, [Length(FImageData)]);
end;

procedure TFormProduct.SaveProductImages(dataProduct: TDataProducto);
var
  dataImage: TDataImage;
  i, newId: Integer;
begin
  if product.getId() <= 0 then
    Exit;
  dataImage := TDataImage.Create(DataModule1.SQLite3Connection1);
  try
    { Simplest correct strategy: clear the product's images and re-store the
      current working set in list order. Store() assigns incremental positions,
      preserving the displayed order. }
    dataImage.Delete(product.getId());
    product.clearImageRefs();
    for i := 0 to High(FImageData) do
    begin
      if Length(FImageData[i]) = 0 then
        Continue;
      newId := dataImage.Store(product.getId(), FImageData[i]);
      if newId > 0 then
        product.addImageRef(newId);
    end;
  finally
    dataImage.getQuery().Free;
  end;
end;

procedure TFormProduct.BtnAddImageClick(Sender: TObject);
var
  Dlg: TOpenDialog;
  FS: TFileStream;
  ValidationError: String;
  PngData: TBytes;
begin
  try
  Dlg := TOpenDialog.Create(Self);
  try
    Dlg.Title := RS_PRODUCT_DLG_PNG_TITLE;
    Dlg.Filter := RS_PRODUCT_DLG_PNG_FILTER;
    if not Dlg.Execute then
      Exit;

    try
      FS := TFileStream.Create(Dlg.FileName, fmOpenRead or fmShareDenyNone);
      try
        SetLength(PngData, FS.Size);
        if FS.Size > 0 then
          FS.Read(PngData[0], FS.Size);
      finally
        FS.Free;
      end;
    except
      on E: Exception do
      begin
        LblImageStatus.Caption := Format(RS_PRODUCT_IMG_ERROR, [E.Message]);
        Exit;
      end;
    end;

    ValidationError := TPngValidator.GetValidationError(PngData);
    if ValidationError <> '' then
    begin
      LblImageStatus.Caption := ValidationError;
      Exit;
    end;

    AddImageEntry(PngData, Format(RS_PRODUCT_IMG_NEW, [ExtractFileName(Dlg.FileName)]));
    ListImages.ItemIndex := ListImages.Items.Count - 1;
    ShowImagePreview(ListImages.ItemIndex);
    UpdateImageStatus;
  finally
    Dlg.Free;
  end;
  except
    on E: Exception do DebugLn('[TFormProduct.BtnAddImageClick] ERROR: ' + E.Message);
  end;
end;

procedure TFormProduct.BtnRemoveImageClick(Sender: TObject);
var
  idx: Integer;
begin
  try
    idx := ListImages.ItemIndex;
    if idx < 0 then
      Exit;
    RemoveImageEntryAt(idx);
    if ListImages.Items.Count > 0 then
    begin
      if idx >= ListImages.Items.Count then
        idx := ListImages.Items.Count - 1;
      ListImages.ItemIndex := idx;
      ShowImagePreview(idx);
    end
    else
      ImagePreview.Picture.Clear;
    UpdateImageStatus;
  except
    on E: Exception do DebugLn('[TFormProduct.BtnRemoveImageClick] ERROR: ' + E.Message);
  end;
end;

procedure TFormProduct.ListImagesClick(Sender: TObject);
begin
  ShowImagePreview(ListImages.ItemIndex);
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

procedure TFormProduct.LoadGoogleCategories;
var
  DataCat: TDataGoogleCategory;
  Cats: TStringList;
begin
  try
    DataModule1.EnsureTransaction;
    DataCat := TDataGoogleCategory.Create(DataModule1.SQLite3Connection1);
    try
      Cats := DataCat.FindAll();
      try
        EditGoogleCat.Items.Assign(Cats);
      finally
        Cats.Free;
      end;
    finally
      DataCat.Destroy;  { avoid TData's shadowing free() on the shared txn }
    end;
  except
    on E: Exception do
      DebugLn('[TFormProduct.LoadGoogleCategories] ERROR: ' + E.Message);
  end;
end;

procedure TFormProduct.FormCreate(Sender: TObject);
begin
  BitBtnOk.Caption := RS_OK;
  BitBtnCancel.Caption := RS_CANCEL;
  LabelName.Caption := RS_LNAME;
  LabelMinStock.Caption := RS_LMINSTOCK;
  LabelMaxStock.Caption := RS_LMAXSTOCK;
  LabelOriginalPrice.Caption := RS_PRODUCT_LBL_ORIGINAL_PRICE;
  LabelCategory.Caption := RS_PRODUCT_LBL_CATEGORY;
  LabelBrand.Caption := RS_PRODUCT_LBL_BRAND;
  LabelCondition.Caption := RS_PRODUCT_LBL_CONDITION;
  LabelGoogleCat.Caption := RS_PRODUCT_LBL_GOOGLE_CAT;
  LabelDescription.Caption := RS_LDESCRIPTION;
  ChkIsService.Caption := RS_PRODUCT_CHK_IS_SERVICE;
  GroupBoxImages.Caption := RS_PRODUCT_GROUP_IMAGES;
  BtnAddImage.Caption := RS_PRODUCT_BTN_ADD_IMAGE;
  BtnRemoveImage.Caption := RS_PRODUCT_BTN_REMOVE_IMAGE;
  GroupBoxPreview.Caption := RS_PRODUCT_GROUP_PREVIEW;
  Self.Caption := RS_LPRODUCTS;

  { Populate the Google category combobox from the database. }
  LoadGoogleCategories;

  flagAction := 0;
  ClearImageWorkingSet;
  if product = nil then
    product := TProduct.Create;
  productValidator := TProductValidator.Create;
end;

procedure TFormProduct.FormShow(Sender: TObject);
var
  DataImage: TDataImage;
  ImageData: TBytes;
  i, imageId: Integer;
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

    { Load every image of the product into the working list, in order. }
    ClearImageWorkingSet;
    if product.getImageRefCount() > 0 then
    begin
      DataImage := TDataImage.Create(DataModule1.SQLite3Connection1);
      try
        for i := 0 to product.getImageRefCount() - 1 do
        begin
          imageId := product.getImageRefAt(i);
          if imageId <= 0 then
            Continue;
          ImageData := DataImage.Get(imageId);
          if Length(ImageData) > 0 then
            AddImageEntry(ImageData, Format(RS_PRODUCT_IMG_STORED, [imageId]));
        end;
      finally
        DataImage.getQuery().Free;
      end;
    end;

    if ListImages.Items.Count > 0 then
    begin
      ListImages.ItemIndex := 0;
      ShowImagePreview(0);
    end;
    UpdateImageStatus;
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
