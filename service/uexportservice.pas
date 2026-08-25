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

unit UExportService;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, UProduct, UJsonSerializer, UWebPConverter,
  UPngValidator, UDataProduct, UDataImage, ULogger;

type
  TExportResult = record
    Success: Boolean;
    ProductCount: Integer;
    ServiceCount: Integer;
    ProductFile: String;
    ServiceFile: String;
    ErrorMessage: String;
  end;

  TExportOptions = record
    ExportProducts: Boolean;
    ExportServices: Boolean;
    OutputFilePath: String;
    ImageOutputDir: String;
  end;

  TStringArray = array of String;

  TExportService = class(TObject)
  private
    FConnection: TSQLite3Connection;
    FSerializer: TJsonSerializer;
    FConverter: TWebPConverter;
    function DeriveFilePaths(const BasePath: String; Both: Boolean): TStringArray;
    function QueryProducts(IsService: Boolean): TList;
    function ProcessImage(Product: TProduct; const ImageDir: String): String;
    function SerializeProductList(Products: TList; const ImagePaths: array of String): String;
    function SerializeServiceList(Services: TList; const ImagePaths: array of String): String;
    function WriteJsonToFile(const FilePath: String; const JsonContent: String): Boolean;
  public
    constructor Create(AConnection: TSQLite3Connection);
    destructor Destroy; override;
    function Execute(const Options: TExportOptions): TExportResult;
  end;

implementation

constructor TExportService.Create(AConnection: TSQLite3Connection);
begin
  inherited Create;
  FConnection := AConnection;
  FSerializer := TJsonSerializer.Create;
  FConverter := TWebPConverter.Create;
end;

destructor TExportService.Destroy;
begin
  FSerializer.Free;
  FConverter.Free;
  inherited Destroy;
end;

function TExportService.DeriveFilePaths(const BasePath: String; Both: Boolean): TStringArray;
var
  JsonPos: Integer;
  BeforeJson, AfterJson: String;
begin
  Result := nil;
  SetLength(Result, 2);
  if not Both then
  begin
    Result[0] := BasePath;
    Result[1] := BasePath;
    Exit;
  end;

  JsonPos := Pos('.json', BasePath);
  if JsonPos > 0 then
  begin
    BeforeJson := Copy(BasePath, 1, JsonPos - 1);
    AfterJson := Copy(BasePath, JsonPos, Length(BasePath) - JsonPos + 1);
    Result[0] := BeforeJson + '_products' + AfterJson;
    Result[1] := BeforeJson + '_services' + AfterJson;
  end
  else
  begin
    Result[0] := BasePath + '_products.json';
    Result[1] := BasePath + '_services.json';
  end;
end;

function TExportService.QueryProducts(IsService: Boolean): TList;
var
  DataProducto: TDataProducto;
  AllProducts: TList;
  FilteredList: TList;
  i: Integer;
  Product: TProduct;
begin
  FilteredList := TList.Create;
  DataProducto := TDataProducto.Create(FConnection);
  try
    AllProducts := DataProducto.find('');
    if AllProducts <> nil then
    begin
      for i := 0 to AllProducts.Count - 1 do
      begin
        Product := TProduct(AllProducts[i]);
        if Product.getIsService() = IsService then
          FilteredList.Add(Product);
      end;
      AllProducts.Free;
    end;
  finally
    DataProducto.getQuery().Free;
  end;
  Result := FilteredList;
end;

function TExportService.ProcessImage(Product: TProduct; const ImageDir: String): String;
var
  DataImage: TDataImage;
  ImageData: TBytes;
  NormalizedName: String;
begin
  Result := '';

  if Product.getImageRef() <= 0 then
    Exit;

  DataImage := TDataImage.Create(FConnection);
  try
    ImageData := DataImage.Get(Product.getImageRef());

    if (ImageData = nil) or (Length(ImageData) = 0) then
    begin
      LogError('TExportService', 'PROCESS_IMAGE_FAIL',
        'Image not found for product ID=' + IntToStr(Product.getId()) +
        ' ImageRef=' + IntToStr(Product.getImageRef()));
      Exit;
    end;

    NormalizedName := TWebPConverter.NormalizeProductName(Product.getName());

    if FConverter.Convert(ImageData, ImageDir, NormalizedName) then
      Result := '/' + NormalizedName + '.webp'
    else
      LogError('TExportService', 'IMAGE_CONVERT_FAIL',
        'Failed to convert image to WebP for product ID=' + IntToStr(Product.getId()) +
        ' Error=' + FConverter.GetLastError());
  finally
    DataImage.getQuery().Free;
  end;
end;

function TExportService.SerializeProductList(Products: TList;
  const ImagePaths: array of String): String;
var
  i: Integer;
  Product: TProduct;
begin
  if Products.Count = 0 then
  begin
    Result := '[]';
    Exit;
  end;

  Result := '[' + LineEnding;
  for i := 0 to Products.Count - 1 do
  begin
    Product := TProduct(Products[i]);
    Result := Result + '  ' + FSerializer.SerializeProduct(Product, ImagePaths[i]);
    if i < Products.Count - 1 then
      Result := Result + ',';
    Result := Result + LineEnding;
  end;
  Result := Result + ']';
end;

function TExportService.SerializeServiceList(Services: TList;
  const ImagePaths: array of String): String;
var
  i: Integer;
  Product: TProduct;
begin
  if Services.Count = 0 then
  begin
    Result := '[]';
    Exit;
  end;

  Result := '[' + LineEnding;
  for i := 0 to Services.Count - 1 do
  begin
    Product := TProduct(Services[i]);
    Result := Result + '  ' + FSerializer.SerializeService(Product, ImagePaths[i]);
    if i < Services.Count - 1 then
      Result := Result + ',';
    Result := Result + LineEnding;
  end;
  Result := Result + ']';
end;

function TExportService.WriteJsonToFile(const FilePath: String;
  const JsonContent: String): Boolean;
var
  FS: TFileStream;
begin
  Result := False;
  try
    FS := TFileStream.Create(FilePath, fmCreate);
    try
      if Length(JsonContent) > 0 then
        FS.Write(JsonContent[1], Length(JsonContent));
      Result := True;
    finally
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      LogError('TExportService', 'FILE_WRITE_FAIL',
        'Failed to write file: ' + FilePath + ' Error=' + E.Message);
      // Delete partial file
      if FileExists(FilePath) then
        DeleteFile(FilePath);
    end;
  end;
end;

function TExportService.Execute(const Options: TExportOptions): TExportResult;
var
  FilePaths: TStringArray;
  ProductList, ServiceList: TList;
  ProductJson, ServiceJson: String;
  i: Integer;
  Product: TProduct;
  ImagePath: String;
  ProductImagePaths, ServiceImagePaths: array of String;
  OutputDir: String;
  Both: Boolean;
  ProductWriteOk, ServiceWriteOk: Boolean;
  TempFS: TFileStream;
  TempPath: String;
begin
  Result.Success := False;
  Result.ProductCount := 0;
  Result.ServiceCount := 0;
  Result.ProductFile := '';
  Result.ServiceFile := '';
  Result.ErrorMessage := '';
  ProductWriteOk := False;
  ServiceWriteOk := False;

  // Validate output file path directory exists
  OutputDir := ExtractFileDir(Options.OutputFilePath);
  if (OutputDir = '') or (not DirectoryExists(OutputDir)) then
  begin
    Result.ErrorMessage := 'Target directory is invalid';
    Exit;
  end;

  // Validate image output directory exists and is writable
  if (Options.ImageOutputDir = '') or
     (not DirectoryExists(Options.ImageOutputDir)) then
  begin
    Result.ErrorMessage := 'Image output directory is invalid or not writable';
    Exit;
  end;

  // Check writable by attempting to create a temp file
  TempPath := IncludeTrailingPathDelimiter(Options.ImageOutputDir) + '.export_write_test';
  try
    TempFS := TFileStream.Create(TempPath, fmCreate);
    TempFS.Free;
    DeleteFile(TempPath);
  except
    Result.ErrorMessage := 'Image output directory is invalid or not writable';
    Exit;
  end;

  Both := Options.ExportProducts and Options.ExportServices;
  FilePaths := DeriveFilePaths(Options.OutputFilePath, Both);

  // Process and export products
  if Options.ExportProducts then
  begin
    ProductList := QueryProducts(False);
    try
      SetLength(ProductImagePaths, ProductList.Count);
      for i := 0 to ProductList.Count - 1 do
      begin
        Product := TProduct(ProductList[i]);
        ImagePath := ProcessImage(Product, Options.ImageOutputDir);
        ProductImagePaths[i] := ImagePath;
      end;

      ProductJson := SerializeProductList(ProductList, ProductImagePaths);
      Result.ProductCount := ProductList.Count;
    finally
      ProductList.Free;
    end;

    ProductWriteOk := WriteJsonToFile(FilePaths[0], ProductJson);
    if ProductWriteOk then
      Result.ProductFile := FilePaths[0]
    else
      Result.ErrorMessage := 'File could not be saved: ' + FilePaths[0];
  end;

  // Process and export services
  if Options.ExportServices then
  begin
    ServiceList := QueryProducts(True);
    try
      SetLength(ServiceImagePaths, ServiceList.Count);
      for i := 0 to ServiceList.Count - 1 do
      begin
        Product := TProduct(ServiceList[i]);
        ImagePath := ProcessImage(Product, Options.ImageOutputDir);
        ServiceImagePaths[i] := ImagePath;
      end;

      ServiceJson := SerializeServiceList(ServiceList, ServiceImagePaths);
      Result.ServiceCount := ServiceList.Count;
    finally
      ServiceList.Free;
    end;

    ServiceWriteOk := WriteJsonToFile(FilePaths[1], ServiceJson);
    if ServiceWriteOk then
      Result.ServiceFile := FilePaths[1]
    else
    begin
      if Result.ErrorMessage <> '' then
        Result.ErrorMessage := Result.ErrorMessage + '; ';
      Result.ErrorMessage := Result.ErrorMessage +
        'File could not be saved: ' + FilePaths[1];
    end;
  end;

  // Determine overall success
  if Result.ErrorMessage = '' then
    Result.Success := True;
end;

end.
