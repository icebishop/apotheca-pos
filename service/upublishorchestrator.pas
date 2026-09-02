{ Apothêca - Instagram Auto-Publish

  Orchestrator for the Instagram Publication pipeline: load config, load the
  catalog registry (products.json + services.json), load published product ids
  from the database, detect new items, and for each: resolve images, build a
  caption, publish via the Graph API, and record the publication.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UPublishOrchestrator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, sqlite3conn, FPimage, FPReadPNG, FPWriteJPEG,
  URegistryItem, UPublishConfig, UProductRegistry, UPublicationTracker,
  UCaptionBuilder, UPublishImageResolver, UInstagramApiClient, UDataPublication,
  UProduct, UBalance, UDataProduct, UDataImage, UWebPConverter, ULogger;

type
  { Progress callback: Current/Total items processed, plus a status/error line. }
  TPublishProgress = procedure(Current, Total: Integer; const Msg: String) of object;

  TPublishOptions = record
    EnvFilePath: String;
    ProductsPath: String;
    ServicesPath: String;
    PublicFolder: String;
    IncludeProducts: Boolean;
    IncludeServices: Boolean;
    { Optional explicit Instagram config (e.g. from the parameters table).
      When AccessToken is non-empty these are used directly; otherwise the
      orchestrator falls back to environment variables / EnvFilePath. }
    AccessToken: String;
    BusinessAccountId: String;
    ImageBaseUrl: String;
    { Optional whitelist of catalog ids to publish. When assigned and non-empty,
      only items whose catalog id is in this list are published; otherwise all
      detected new items are published. Not owned by the orchestrator. }
    OnlyIds: TStrings;
    { When True (default), the item source is the database: products with
      available stock (units > 0), read directly from the product/balance
      tables, rather than the products.json/services.json catalog files. }
    UseDatabase: Boolean;
    { Optional progress callback: Current/Total items, plus a status/error line. }
    OnProgress: TPublishProgress;
  end;

  TPublishSummary = record
    Published: Integer;
    Skipped: Integer;
    Failed: Integer;
    ExitCode: Integer;   { 0 success, 1 critical error }
  end;

  { TPublishOrchestrator }

  TPublishOrchestrator = class(TObject)
  private
    FConnection: TSQLite3Connection;
    function IsNew(Item: TRegistryItem; PublishedIds: TStrings): Boolean;
    { Whether the item has a usable image. In database mode this is authoritative
      from the DB (the item has an image reference); in JSON mode it checks that
      a referenced image file (or a .webp/.jpeg/.png sibling) exists in the
      public folder. }
    function ItemHasImage(Item: TRegistryItem; const Options: TPublishOptions): Boolean;
    { Loads registry items from the database: products with available stock
      (units > 0). Image path is derived from the normalized product name to
      match the file the web-catalog export writes to the public folder.
      Caller frees the returned owned list. }
    function LoadItemsFromDb(Options: TPublishOptions): TFPObjectList;
    { Extracts the item's image blob from the images table and writes it into
      the public folder as <normalized-name>.png so the resolver (and, via its
      public URL, the Instagram API) can use it. Returns True on success. }
    function MaterializeDbImage(Item: TRegistryItem; const PublicFolder: String): Boolean;
  public
    constructor Create(AConnection: TSQLite3Connection);
    function Run(const Options: TPublishOptions): TPublishSummary;
    { Loads the registry + published ids and returns the items that would be
      published (visible, mappable, not yet published), WITHOUT publishing.
      Each line is 'CatalogId'#9'Name'#9'HasImage' where HasImage is '1' when the
      item references at least one image whose file exists in PublicFolder, else
      '0'. Caller frees the list.
      On config/registry/tracking error, ErrorMsg is set and nil is returned. }
    function DetectNew(const Options: TPublishOptions;
      out ErrorMsg: String): TStringList;
  end;

implementation

constructor TPublishOrchestrator.Create(AConnection: TSQLite3Connection);
begin
  inherited Create;
  FConnection := AConnection;
end;

function TPublishOrchestrator.IsNew(Item: TRegistryItem;
  PublishedIds: TStrings): Boolean;
var
  ProductId: Integer;
begin
  Result := False;
  if not Item.IsVisible then
    Exit;
  { Must be mappable to a product.id and not already published. }
  if not TDataPublication.TryParseCatalogId(Item.Id, ProductId) then
    Exit;
  Result := PublishedIds.IndexOf(IntToStr(ProductId)) < 0;
end;

function TPublishOrchestrator.ItemHasImage(Item: TRegistryItem;
  const Options: TPublishOptions): Boolean;
var
  i: Integer;
  Folder, Filename, NameNoExt: String;
begin
  Result := False;
  if Item.Images.Count = 0 then
    Exit;

  { Database mode: the image reference in the DB is authoritative. LoadItemsFromDb
    only populates Images when the product has image_ref > 0, so the presence of
    any image entry means the DB has an image for this item. }
  if Options.UseDatabase then
  begin
    Result := True;
    Exit;
  end;

  { JSON mode: verify the referenced file exists in the public folder. }
  Folder := IncludeTrailingPathDelimiter(Options.PublicFolder);
  for i := 0 to Item.Images.Count - 1 do
  begin
    Filename := Item.Images[i];
    while (Filename <> '') and (Filename[1] = '/') do
      Filename := Copy(Filename, 2, Length(Filename) - 1);
    if Filename = '' then
      Continue;
    NameNoExt := ChangeFileExt(Filename, '');
    { The exact file, or a webp/jpeg/png sibling the resolver could use. }
    if FileExists(Folder + Filename) or
       FileExists(Folder + NameNoExt + '.webp') or
       FileExists(Folder + NameNoExt + '.jpeg') or
       FileExists(Folder + NameNoExt + '.jpg') or
       FileExists(Folder + NameNoExt + '.png') then
    begin
      Result := True;
      Exit;
    end;
  end;
end;

function TPublishOrchestrator.LoadItemsFromDb(
  Options: TPublishOptions): TFPObjectList;
var
  DataProduct: TDataProducto;
  DbList: TList;
  i: Integer;
  P: TProduct;
  Item: TRegistryItem;
  IsService: Boolean;
  NormName: String;
begin
  Result := TFPObjectList.Create(True);  { owns items }

  DataProduct := TDataProducto.Create(FConnection);
  try
    { Products/services with available stock (units > 0). }
    DbList := DataProduct.findInStock('');
    if DbList <> nil then
    begin
      for i := 0 to DbList.Count - 1 do
      begin
        P := TProduct(DbList[i]);
        IsService := P.getIsService();

        { Honor the include-products / include-services selection. }
        if IsService and (not Options.IncludeServices) then
          Continue;
        if (not IsService) and (not Options.IncludeProducts) then
          Continue;

        Item := TRegistryItem.Create;
        if IsService then
          Item.Kind := rkService
        else
          Item.Kind := rkProduct;
        { Catalog id is the raw product.id. }
        Item.Id := IntToStr(P.getId());
        Item.Name := P.getName();
        Item.Category := P.getCategory();
        Item.Description := P.getDescription();
        Item.Brand := P.getBrand();
        if P.getBalance() <> nil then
          Item.Price := Round(P.getBalance().getPrice())
        else
          Item.Price := 0;
        Item.HasOriginalPrice := P.getOriginalPrice() > 0;
        Item.OriginalPrice := Round(P.getOriginalPrice());
        { Available stock -> visible/publishable. }
        Item.IsVisible := (P.getBalance() <> nil) and (P.getBalance().getStock() > 0);
        { The web-catalog export writes the image as /<normalized-name>.webp in
          the public folder; reference that so the resolver can find it. }
        Item.ImageRef := P.getImageRef();
        if P.getImageRef() > 0 then
        begin
          { Instagram needs JPEG. The web-catalog export writes <normalized>.jpeg
            (and .webp) to the public folder; reference the .jpeg so the resolver
            uses it and the deployed URL matches. }
          NormName := TWebPConverter.NormalizeProductName(P.getName());
          Item.Images.Add('/' + NormName + '.jpeg');
        end;
        Result.Add(Item);
      end;
      { findInStock builds fresh TProduct objects; free them now. }
      for i := 0 to DbList.Count - 1 do
        TProduct(DbList[i]).Free;
      DbList.Free;
    end;
  finally
    DataProduct.getQuery().Free;
  end;
end;

function TPublishOrchestrator.MaterializeDbImage(Item: TRegistryItem;
  const PublicFolder: String): Boolean;
const
  IG_MIN_ASPECT = 0.8;
  IG_MAX_ASPECT = 1.91;
var
  DataImage: TDataImage;
  ImageData: TBytes;
  NormName, OutPath: String;
  Img, Cropped: TFPMemoryImage;
  Reader: TFPReaderPNG;
  Writer: TFPWriterJPEG;
  InStream: TBytesStream;
  Ratio: Double;
  NewW, NewH, Left, Top, X, Y: Integer;
begin
  Result := False;
  if Item.ImageRef <= 0 then
    Exit;

  DataImage := TDataImage.Create(FConnection);
  try
    ImageData := DataImage.Get(Item.ImageRef);
    if (ImageData = nil) or (Length(ImageData) = 0) then
    begin
      LogWarn('PublishOrchestrator', 'IMG_BLOB_EMPTY',
        'item=' + Item.Name + ' imageRef=' + IntToStr(Item.ImageRef));
      Exit;
    end;

    { Convert the PNG blob to JPEG (Instagram requires JPEG), cropping to the
      supported aspect-ratio range (4:5 .. 1.91:1) so it is accepted (avoids
      error 36003), and write it as <normalized>.jpeg. }
    NormName := TWebPConverter.NormalizeProductName(Item.Name);
    OutPath := IncludeTrailingPathDelimiter(PublicFolder) + NormName + '.jpeg';
    Img := TFPMemoryImage.Create(0, 0);
    InStream := TBytesStream.Create(ImageData);
    Reader := TFPReaderPNG.Create;
    Writer := TFPWriterJPEG.Create;
    try
      try
        InStream.Position := 0;
        Img.LoadFromStream(InStream, Reader);
        if (Img.Width = 0) or (Img.Height = 0) then
          Exit;
        Ratio := Img.Width / Img.Height;
        NewW := Img.Width; NewH := Img.Height; Left := 0; Top := 0;
        if Ratio < IG_MIN_ASPECT then
        begin
          NewH := Round(Img.Width / IG_MIN_ASPECT);
          Top := (Img.Height - NewH) div 2;
        end
        else if Ratio > IG_MAX_ASPECT then
        begin
          NewW := Round(Img.Height * IG_MAX_ASPECT);
          Left := (Img.Width - NewW) div 2;
        end;
        Writer.CompressionQuality := 85;
        if (NewW = Img.Width) and (NewH = Img.Height) then
          Img.SaveToFile(OutPath, Writer)
        else
        begin
          Cropped := TFPMemoryImage.Create(NewW, NewH);
          try
            for Y := 0 to NewH - 1 do
              for X := 0 to NewW - 1 do
                Cropped.Colors[X, Y] := Img.Colors[Left + X, Top + Y];
            Cropped.SaveToFile(OutPath, Writer);
          finally
            Cropped.Free;
          end;
        end;
        Result := True;
      except
        on E: Exception do
          LogError('PublishOrchestrator', 'IMG_WRITE_FAIL',
            'item=' + Item.Name + ' path=' + OutPath + ' error=' + E.Message);
      end;
    finally
      Writer.Free;
      Reader.Free;
      InStream.Free;
      Img.Free;
    end;
  finally
    DataImage.getQuery().Free;
  end;
end;

function TPublishOrchestrator.DetectNew(const Options: TPublishOptions;
  out ErrorMsg: String): TStringList;
var
  Tracker: TPublicationTracker;
  Items, Products, Services, DbItems: TFPObjectList;
  PublishedIds: TStringList;
  i: Integer;
  Item: TRegistryItem;
begin
  Result := nil;
  ErrorMsg := '';

  Items := TFPObjectList.Create(False);
  Products := nil;
  Services := nil;
  DbItems := nil;
  PublishedIds := nil;
  Tracker := nil;
  try
    { item source: database (products in stock) or JSON catalog files }
    if Options.UseDatabase then
    begin
      DbItems := LoadItemsFromDb(Options);
      for i := 0 to DbItems.Count - 1 do
        Items.Add(DbItems[i]);
    end
    else
    begin
      try
        if Options.IncludeProducts then
        begin
          if FileExists(Options.ProductsPath) then
            Products := TProductRegistry.LoadProducts(Options.ProductsPath)
          else
            Products := TFPObjectList.Create(True);
        end;
        if Options.IncludeServices then
        begin
          if FileExists(Options.ServicesPath) then
            Services := TProductRegistry.LoadServices(Options.ServicesPath)
          else
            Services := TFPObjectList.Create(True);
        end;
      except
        on E: ERegistryError do
        begin
          ErrorMsg := E.Message;
          Exit;
        end;
      end;
      if Products <> nil then
        for i := 0 to Products.Count - 1 do
          Items.Add(Products[i]);
      if Services <> nil then
        for i := 0 to Services.Count - 1 do
          Items.Add(Services[i]);
    end;

    { tracking }
    try
      Tracker := TPublicationTracker.Create(FConnection);
      PublishedIds := Tracker.LoadPublishedIds();
    except
      on E: ETrackingError do
      begin
        ErrorMsg := E.Message;
        Exit;
      end;
    end;

    { detect }
    Result := TStringList.Create;
    for i := 0 to Items.Count - 1 do
    begin
      Item := TRegistryItem(Items[i]);
      if IsNew(Item, PublishedIds) then
      begin
        if ItemHasImage(Item, Options) then
          Result.Add(Item.Id + #9 + Item.Name + #9 + '1')
        else
          Result.Add(Item.Id + #9 + Item.Name + #9 + '0');
      end;
    end;
  finally
    if PublishedIds <> nil then PublishedIds.Free;
    if Products <> nil then Products.Free;
    if Services <> nil then Services.Free;
    if DbItems <> nil then DbItems.Free;
    if Tracker <> nil then Tracker.Free;
    Items.Free;
  end;
end;

function TPublishOrchestrator.Run(const Options: TPublishOptions): TPublishSummary;
var
  Config: TPublishConfig;
  Tracker: TPublicationTracker;
  Resolver: TPublishImageResolver;
  ApiClient: TInstagramApiClient;
  Items: TFPObjectList;
  Products, Services, DbItems: TFPObjectList;
  PublishedIds: TStringList;
  NewItems: TList;
  i, VisibleCount: Integer;
  Item: TRegistryItem;
  Resolved: TResolvedImageArray;
  Urls: array of String;
  Caption: String;
  PubResult: TPublishResult;
  ProductId: Integer;
begin
  Result.Published := 0;
  Result.Skipped := 0;
  Result.Failed := 0;
  Result.ExitCode := 0;

  Config := nil;
  Tracker := nil;
  Resolver := nil;
  ApiClient := nil;
  Items := TFPObjectList.Create(False); { holds references; owned lists free items }
  Products := nil;
  Services := nil;
  DbItems := nil;
  PublishedIds := nil;
  NewItems := TList.Create;

  try
    { --- Step 1: config --- }
    try
      if Trim(Options.AccessToken) <> '' then
        Config := TPublishConfig.FromValues(Options.AccessToken,
          Options.BusinessAccountId, Options.ImageBaseUrl)
      else
        Config := TPublishConfig.Load(Options.EnvFilePath);
    except
      on E: EPublishConfigError do
      begin
        LogError('PublishOrchestrator', 'CONFIG_ERROR', E.Message);
        Result.ExitCode := 1;
        Exit;
      end;
    end;

    { --- Step 2: item source (database in-stock products, or JSON catalog) --- }
    if Options.UseDatabase then
    begin
      DbItems := LoadItemsFromDb(Options);
      for i := 0 to DbItems.Count - 1 do
        Items.Add(DbItems[i]);
    end
    else
    begin
      try
        if Options.IncludeProducts then
        begin
          if FileExists(Options.ProductsPath) then
            Products := TProductRegistry.LoadProducts(Options.ProductsPath)
          else
            Products := TFPObjectList.Create(True);
        end;
        if Options.IncludeServices then
        begin
          if FileExists(Options.ServicesPath) then
            Services := TProductRegistry.LoadServices(Options.ServicesPath)
          else
            Services := TFPObjectList.Create(True);
        end;
      except
        on E: ERegistryError do
        begin
          LogError('PublishOrchestrator', 'REGISTRY_ERROR', E.Message);
          Result.ExitCode := 1;
          Exit;
        end;
      end;
      if Products <> nil then
        for i := 0 to Products.Count - 1 do
          Items.Add(Products[i]);
      if Services <> nil then
        for i := 0 to Services.Count - 1 do
          Items.Add(Services[i]);
    end;

    { --- Step 3: tracking --- }
    try
      Tracker := TPublicationTracker.Create(FConnection);
      PublishedIds := Tracker.LoadPublishedIds();
    except
      on E: ETrackingError do
      begin
        LogError('PublishOrchestrator', 'TRACKING_ERROR', E.Message);
        Result.ExitCode := 1;
        Exit;
      end;
    end;

    { --- Step 4: detect new (optionally filtered to a whitelist of ids) --- }
    VisibleCount := 0;
    for i := 0 to Items.Count - 1 do
    begin
      Item := TRegistryItem(Items[i]);
      if Item.IsVisible then
        Inc(VisibleCount);
      if not IsNew(Item, PublishedIds) then
        Continue;
      { If a whitelist is provided, publish only the selected items. }
      if (Options.OnlyIds <> nil) and (Options.OnlyIds.Count > 0) and
         (Options.OnlyIds.IndexOf(Item.Id) < 0) then
        Continue;
      NewItems.Add(Item);
    end;

    LogInfo('PublishOrchestrator', 'DETECTION',
      'total=' + IntToStr(Items.Count) + ' visible=' + IntToStr(VisibleCount) +
      ' new=' + IntToStr(NewItems.Count));

    if NewItems.Count = 0 then
    begin
      LogInfo('PublishOrchestrator', 'NOTHING_TO_PUBLISH', 'no new items');
      Result.ExitCode := 0;
      Exit;
    end;

    { --- Step 5: publish each --- }
    Resolver := TPublishImageResolver.Create;
    ApiClient := TInstagramApiClient.Create(Config);

    for i := 0 to NewItems.Count - 1 do
    begin
      Item := TRegistryItem(NewItems[i]);

      if Assigned(Options.OnProgress) then
        Options.OnProgress(i + 1, NewItems.Count, 'Publishing: ' + Item.Name);

      { Database mode: extract the image blob from the DB into the public folder
        so the resolver (and the Instagram API, via the public URL) can use it. }
      if Options.UseDatabase and (Item.ImageRef > 0) then
        MaterializeDbImage(Item, Options.PublicFolder);

      Resolved := Resolver.Resolve(Item, Options.PublicFolder, Config.ImageBaseUrl);
      if Length(Resolved) = 0 then
      begin
        LogWarn('PublishOrchestrator', 'SKIP_NO_IMAGES', 'item=' + Item.Name);
        Inc(Result.Skipped);
        if Assigned(Options.OnProgress) then
          Options.OnProgress(i + 1, NewItems.Count,
            'SKIPPED (no usable image): ' + Item.Name);
        Continue;
      end;

      Caption := TCaptionBuilder.Build(Item);

      try
        if Length(Resolved) = 1 then
          PubResult := ApiClient.PublishSingleImage(
            Resolved[0].PublicUrl, Caption, Item.Id)
        else
        begin
          SetLength(Urls, Length(Resolved));
          for ProductId := 0 to High(Resolved) do
            Urls[ProductId] := Resolved[ProductId].PublicUrl;
          PubResult := ApiClient.PublishCarousel(Urls, Caption, Item.Id);
        end;
      except
        on E: EAuthError do
        begin
          LogError('PublishOrchestrator', 'AUTH_ABORT',
            'item=' + Item.Name + ' error=' + E.Message);
          if Assigned(Options.OnProgress) then
            Options.OnProgress(i + 1, NewItems.Count,
              'AUTH ERROR (stopped): ' + E.Message);
          LogInfo('PublishOrchestrator', 'SUMMARY',
            'published=' + IntToStr(Result.Published) +
            ' skipped=' + IntToStr(Result.Skipped) +
            ' failed=' + IntToStr(Result.Failed + 1));
          Result.ExitCode := 1;
          Exit;
        end;
        on E: EPublishError do
        begin
          LogError('PublishOrchestrator', 'PUBLISH_FAIL',
            'item=' + Item.Name + ' error=' + E.Message);
          Inc(Result.Failed);
          if Assigned(Options.OnProgress) then
            Options.OnProgress(i + 1, NewItems.Count,
              'FAILED: ' + Item.Name + ' -> ' + E.Message);
          Continue;
        end;
      end;

      { --- record publication (critical on failure) --- }
      try
        Tracker.RecordPublication(Item.Id, Item.Name,
          PubResult.MediaId, PubResult.Timestamp);
      except
        on E: ETrackingError do
        begin
          Inc(Result.Published);
          LogError('PublishOrchestrator', 'TRACKING_WRITE_FAIL',
            'item=' + Item.Name + ' error=' + E.Message);
          if Assigned(Options.OnProgress) then
            Options.OnProgress(i + 1, NewItems.Count,
              'PUBLISHED but tracking write FAILED (stopped): ' + Item.Name);
          LogInfo('PublishOrchestrator', 'SUMMARY',
            'published=' + IntToStr(Result.Published) +
            ' skipped=' + IntToStr(Result.Skipped) +
            ' failed=' + IntToStr(Result.Failed));
          Result.ExitCode := 1;
          Exit;
        end;
      end;

      Inc(Result.Published);
      LogInfo('PublishOrchestrator', 'PUBLISHED_OK',
        'item=' + Item.Name + ' media=' + PubResult.MediaId);
      if Assigned(Options.OnProgress) then
        Options.OnProgress(i + 1, NewItems.Count,
          'PUBLISHED: ' + Item.Name);
    end;

    LogInfo('PublishOrchestrator', 'SUMMARY',
      'published=' + IntToStr(Result.Published) +
      ' skipped=' + IntToStr(Result.Skipped) +
      ' failed=' + IntToStr(Result.Failed));

  finally
    NewItems.Free;
    Items.Free;
    if PublishedIds <> nil then PublishedIds.Free;
    if Products <> nil then Products.Free;
    if Services <> nil then Services.Free;
    if DbItems <> nil then DbItems.Free;
    if ApiClient <> nil then ApiClient.Free;
    if Resolver <> nil then Resolver.Free;
    if Tracker <> nil then Tracker.Free;
    if Config <> nil then Config.Free;
  end;
end;

end.
