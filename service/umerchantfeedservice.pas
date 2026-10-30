{ Apothêca - Google Merchant Center product feed service

  Generates a tab-delimited (.txt/.tsv) product feed for Google Merchant Center
  from the product catalog, following the "Create a product file for Merchant
  Center" guidance (https://support.google.com/merchants/answer/12631822).

  The feed is a UTF-8, tab-separated file: a header row of attribute names
  followed by one row per product. Attributes emitted:

    id, title, description, link, image_link, availability, condition,
    price, brand, google_product_category

  Only products with available stock AND an image are included (same rule as
  the web-catalog export), since Merchant Center rejects items without a valid
  image_link and in-stock availability is required.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UMerchantFeedService;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn,
  UProduct, UWebPConverter, UDataProduct, ULogger;

type
  TMerchantFeedResult = record
    Success: Boolean;
    ProductCount: Integer;
    OutputFile: String;
    ErrorMessage: String;
  end;

  { Progress callback: Current/Total items processed, plus a status line.
    Total <= 0 means indeterminate. }
  TMerchantFeedProgress = procedure(Current, Total: Integer; const Msg: String) of object;

  TMerchantFeedOptions = record
    OutputFilePath: String;   { destination .txt/.tsv file }
    BaseUrl: String;          { public site base, e.g. https://donpulido.com }
    Currency: String;         { ISO code for the price column, e.g. COP }
    OnProgress: TMerchantFeedProgress;  { optional; may be nil }
  end;

  TMerchantFeedService = class(TObject)
  private
    FConnection: TSQLite3Connection;
    function QueryExportableProducts(): TList;
    { Build the public image URL for a product's primary image, matching the
      filenames produced by the web-catalog export (ProcessImages). }
    function PrimaryImageUrl(Product: TProduct; const BaseUrl: String): String;
    function BuildRow(Product: TProduct; const Opts: TMerchantFeedOptions): String;
  public
    constructor Create(AConnection: TSQLite3Connection);
    function Execute(const Options: TMerchantFeedOptions): TMerchantFeedResult;
  end;

{ Sanitizes a text value for a tab-delimited feed: strips tabs and line breaks
  (which would corrupt the row/column structure) and collapses them to spaces. }
function SanitizeTsvField(const S: String): String;

implementation

const
  TAB = #9;
  { Header row: attribute names in column order. }
  FEED_HEADER =
    'id' + TAB + 'title' + TAB + 'description' + TAB + 'link' + TAB +
    'image_link' + TAB + 'availability' + TAB + 'condition' + TAB +
    'price' + TAB + 'brand' + TAB + 'google_product_category';

function SanitizeTsvField(const S: String): String;
var
  i: Integer;
  c: Char;
begin
  Result := '';
  for i := 1 to Length(S) do
  begin
    c := S[i];
    { Replace tab, CR, LF with a single space to preserve the TSV grid. }
    if (c = #9) or (c = #10) or (c = #13) then
      Result := Result + ' '
    else
      Result := Result + c;
  end;
  Result := Trim(Result);
end;

{ Orders two products so the newest (highest id) sorts first (matches the
  web-catalog export ordering). }
function CompareProductsByIdDesc(Item1, Item2: Pointer): Integer;
begin
  Result := TProduct(Item2).getId() - TProduct(Item1).getId();
end;

constructor TMerchantFeedService.Create(AConnection: TSQLite3Connection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TMerchantFeedService.QueryExportableProducts(): TList;
var
  DataProducto: TDataProducto;
  AllProducts: TList;
  FilteredList: TList;
  i: Integer;
  Product: TProduct;
  HasStock, HasImage: Boolean;
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
        { Services are not shippable physical goods; exclude them from the
          Merchant Center product feed. }
        if Product.getIsService() then
        begin
          Product.Free;
          Continue;
        end;

        HasStock := (Product.getBalance() <> nil) and
                    (Product.getBalance().getStock() > 0);
        HasImage := Product.getImageRef() > 0;

        if HasStock and HasImage then
          FilteredList.Add(Product)
        else
        begin
          if not HasStock then
            LogWarn('TMerchantFeedService', 'SKIP_NO_STOCK',
              'Skipped (no stock) ID=' + IntToStr(Product.getId()) +
              ' Name=' + Product.getName());
          if not HasImage then
            LogWarn('TMerchantFeedService', 'SKIP_NO_IMAGE',
              'Skipped (no image) ID=' + IntToStr(Product.getId()) +
              ' Name=' + Product.getName());
          Product.Free;
        end;
      end;
      AllProducts.Free;
    end;
  finally
    DataProducto.getQuery().Free;
  end;

  FilteredList.Sort(@CompareProductsByIdDesc);
  Result := FilteredList;
end;

function TMerchantFeedService.PrimaryImageUrl(Product: TProduct;
  const BaseUrl: String): String;
var
  NormalizedName, VariantName: String;
begin
  NormalizedName := TWebPConverter.NormalizeProductName(Product.getName());
  { Primary image = variant index 0 (plain normalized name), matching the
    web-catalog export's ProcessImages output: /<name>.webp }
  VariantName := TWebPConverter.ImageVariantName(NormalizedName, 0);
  Result := BaseUrl + '/' + VariantName + '.webp';
end;

function TMerchantFeedService.BuildRow(Product: TProduct;
  const Opts: TMerchantFeedOptions): String;
var
  idStr, title, description, link, imageLink, availability, condition,
  priceStr, brand, gpc: String;
  price: Real;
begin
  idStr := IntToStr(Product.getId());
  title := SanitizeTsvField(Product.getName());
  description := SanitizeTsvField(Product.getDescription());
  { Product detail page on the public site: /p/<id> }
  link := Opts.BaseUrl + '/p/' + idStr;
  imageLink := PrimaryImageUrl(Product, Opts.BaseUrl);

  { Only in-stock products reach here (QueryExportableProducts filters), so
    availability is always in_stock. }
  availability := 'in_stock';

  condition := Trim(Product.getProductCondition());
  if condition = '' then
    condition := 'new';

  { Price: 'NNN.NN CUR' with a dot decimal separator regardless of locale. }
  price := 0;
  if Product.getBalance() <> nil then
    price := Product.getBalance().getPrice();
  priceStr := FormatFloat('0.00', price, DefaultFormatSettings);
  { Force dot decimal separator (Merchant Center expects '449.00'). }
  priceStr := StringReplace(priceStr, ',', '.', [rfReplaceAll]);
  priceStr := priceStr + ' ' + Opts.Currency;

  brand := SanitizeTsvField(Product.getBrand());
  if brand = '' then
    brand := 'Don Pulido';

  gpc := SanitizeTsvField(Product.getGoogleProductCategory());

  Result :=
    idStr + TAB + title + TAB + description + TAB + link + TAB +
    imageLink + TAB + availability + TAB + condition + TAB +
    priceStr + TAB + brand + TAB + gpc;
end;

function TMerchantFeedService.Execute(
  const Options: TMerchantFeedOptions): TMerchantFeedResult;
var
  Products: TList;
  Product: TProduct;
  i: Integer;
  OutputDir: String;
  Lines: TStringList;
  Opts: TMerchantFeedOptions;
begin
  Result.Success := False;
  Result.ProductCount := 0;
  Result.OutputFile := '';
  Result.ErrorMessage := '';

  Opts := Options;
  { Normalize config: trailing slash off the base URL, default currency. }
  while (Length(Opts.BaseUrl) > 0) and (Opts.BaseUrl[Length(Opts.BaseUrl)] = '/') do
    Opts.BaseUrl := Copy(Opts.BaseUrl, 1, Length(Opts.BaseUrl) - 1);
  if Trim(Opts.Currency) = '' then
    Opts.Currency := 'COP';

  if Trim(Opts.OutputFilePath) = '' then
  begin
    Result.ErrorMessage := 'Output file path is empty';
    Exit;
  end;

  OutputDir := ExtractFileDir(Opts.OutputFilePath);
  if (OutputDir = '') or (not DirectoryExists(OutputDir)) then
  begin
    Result.ErrorMessage := 'Target directory is invalid: ' + OutputDir;
    Exit;
  end;

  Products := QueryExportableProducts();
  Lines := TStringList.Create;
  try
    if Assigned(Opts.OnProgress) then
      Opts.OnProgress(0, Products.Count,
        Format('Generating Merchant feed for %d products...', [Products.Count]));

    Lines.Add(FEED_HEADER);
    for i := 0 to Products.Count - 1 do
    begin
      Product := TProduct(Products[i]);
      Lines.Add(BuildRow(Product, Opts));
      if Assigned(Opts.OnProgress) then
        Opts.OnProgress(i + 1, Products.Count,
          'Added: ' + Product.getName());
    end;

    try
      { UTF-8, LF line endings. SaveToFile writes the strings joined by the
        platform line ending; set to #10 for consistency. }
      Lines.LineBreak := #10;
      Lines.SaveToFile(Opts.OutputFilePath);
      Result.Success := True;
      Result.ProductCount := Products.Count;
      Result.OutputFile := Opts.OutputFilePath;
      LogInfo('TMerchantFeedService', 'FEED_WRITTEN',
        'file=' + Opts.OutputFilePath + ' products=' + IntToStr(Products.Count));
    except
      on E: Exception do
      begin
        Result.ErrorMessage := 'Could not write feed file: ' + E.Message;
        LogError('TMerchantFeedService', 'FEED_WRITE_FAIL',
          'file=' + Opts.OutputFilePath + ' error=' + E.Message);
        if FileExists(Opts.OutputFilePath) then
          DeleteFile(Opts.OutputFilePath);
      end;
    end;
  finally
    Lines.Free;
    { Free the product objects we took ownership of. }
    for i := 0 to Products.Count - 1 do
      TProduct(Products[i]).Free;
    Products.Free;
  end;
end;

end.
