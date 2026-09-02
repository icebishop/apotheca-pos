{ Apothêca - Settings service

  Application settings backed by the parameters table. Handles transparent
  encryption/decryption of credential-flagged values (via UCrypto) so callers
  work with plaintext, while values are stored encrypted at rest.

  Also seeds the default set of application parameters (db file, export file
  paths, Instagram configuration) on first run.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit USettingsService;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl, sqlite3conn, UDataParameter, UCrypto;

type
  { A UI-facing view of a parameter: value already decrypted, plus a Masked
    display string that hides credential values. }
  TParameterView = class(TObject)
  public
    Key: String;
    Value: String;          { decrypted plaintext }
    IsCredential: Boolean;
    Description: String;
    Masked: String;         { what the UI should display }
  end;
  TParameterViewList = specialize TFPGObjectList<TParameterView>;

  { Well-known parameter keys. }
  { }

  { TSettingsService }

  TSettingsService = class(TObject)
  private
    FData: TDataParameter;
  public
    constructor Create(AConnection: TSQLite3Connection);
    destructor Destroy; override;

    { Returns the decrypted plaintext value for a key, or ADefault if absent. }
    function GetValue(const Key: String; const ADefault: String = ''): String;
    { Stores a value; encrypts it when IsCredential is true. Creates the row if
      it does not exist (preserving the existing credential flag when present). }
    function SetValue(const Key, Value: String): Boolean;
    { Defines/updates a parameter with an explicit credential flag + description. }
    function Define(const Key, Value: String; IsCredential: Boolean;
      const Description: String): Boolean;
    { All parameters as UI views (values decrypted, credential values masked).
      Caller frees the list. }
    function GetViews(): TParameterViewList;
    { Seeds the default parameter set if the keys are absent. }
    procedure SeedDefaults(const DbFilePath, ProductsPath, ServicesPath,
      PublicFolder: String);
  end;

const
  { Application parameter keys. }
  PARAM_DB_FILE                = 'db.file';
  PARAM_EXPORT_PRODUCTS_PATH   = 'export.products.path';
  PARAM_EXPORT_SERVICES_PATH   = 'export.services.path';
  PARAM_EXPORT_PUBLIC_FOLDER   = 'export.public.folder';
  PARAM_IG_ACCESS_TOKEN        = 'instagram.access_token';
  PARAM_IG_BUSINESS_ACCOUNT_ID = 'instagram.business_account_id';
  PARAM_IG_IMAGE_BASE_URL      = 'instagram.image_base_url';

  MASK_TEXT = '********';

implementation

constructor TSettingsService.Create(AConnection: TSQLite3Connection);
begin
  inherited Create;
  FData := TDataParameter.Create(AConnection);
end;

destructor TSettingsService.Destroy;
begin
  FData.Destroy;  { avoid TData's shadowing free() that frees the shared txn }
  inherited Destroy;
end;

function TSettingsService.GetValue(const Key, ADefault: String): String;
var
  Rec: TParameterRecord;
begin
  if not FData.Get(Key, Rec) then
  begin
    Result := ADefault;
    Exit;
  end;
  if Rec.IsCredential then
    Result := TCrypto.Decrypt(Rec.Value)
  else
    Result := Rec.Value;
  if Result = '' then
    Result := ADefault;
end;

function TSettingsService.SetValue(const Key, Value: String): Boolean;
var
  Existing: TParameterRecord;
  Rec: TParameterRecord;
begin
  Rec.Key := Key;
  Rec.IsCredential := False;
  Rec.Description := '';
  { Preserve credential flag/description if the key already exists. }
  if FData.Get(Key, Existing) then
  begin
    Rec.IsCredential := Existing.IsCredential;
    Rec.Description := Existing.Description;
  end;
  if Rec.IsCredential then
    Rec.Value := TCrypto.Encrypt(Value)
  else
    Rec.Value := Value;
  Result := FData.Upsert(Rec);
end;

function TSettingsService.Define(const Key, Value: String;
  IsCredential: Boolean; const Description: String): Boolean;
var
  Rec: TParameterRecord;
begin
  Rec.Key := Key;
  Rec.IsCredential := IsCredential;
  Rec.Description := Description;
  if IsCredential then
    Rec.Value := TCrypto.Encrypt(Value)
  else
    Rec.Value := Value;
  Result := FData.Upsert(Rec);
end;

function TSettingsService.GetViews(): TParameterViewList;
var
  Raw: TParameterList;
  i: Integer;
  V: TParameterView;
  R: TParameterItem;
begin
  Result := TParameterViewList.Create(True);  { owns items }
  Raw := FData.GetAll();
  try
    for i := 0 to Raw.Count - 1 do
    begin
      R := Raw[i];
      V := TParameterView.Create;
      V.Key := R.Key;
      V.IsCredential := R.IsCredential;
      V.Description := R.Description;
      if R.IsCredential then
      begin
        V.Value := TCrypto.Decrypt(R.Value);
        { Never expose decrypted credential values in the grid. }
        if V.Value <> '' then
          V.Masked := MASK_TEXT
        else
          V.Masked := '';
      end
      else
      begin
        V.Value := R.Value;
        V.Masked := R.Value;
      end;
      Result.Add(V);
    end;
  finally
    Raw.Free;
  end;
end;

procedure TSettingsService.SeedDefaults(const DbFilePath, ProductsPath,
  ServicesPath, PublicFolder: String);

  procedure SeedIfAbsent(const Key, Value: String; IsCred: Boolean;
    const Desc: String);
  begin
    if not FData.Exists(Key) then
      Define(Key, Value, IsCred, Desc);
  end;

begin
  SeedIfAbsent(PARAM_DB_FILE, DbFilePath, False,
    'SQLite database file path');
  SeedIfAbsent(PARAM_EXPORT_PRODUCTS_PATH, ProductsPath, False,
    'Products JSON export file (Update Web Catalog)');
  SeedIfAbsent(PARAM_EXPORT_SERVICES_PATH, ServicesPath, False,
    'Services JSON export file (Update Web Catalog)');
  SeedIfAbsent(PARAM_EXPORT_PUBLIC_FOLDER, PublicFolder, False,
    'Public image folder for Instagram Publication');
  SeedIfAbsent(PARAM_IG_ACCESS_TOKEN, '', True,
    'Instagram Graph API access token (credential)');
  SeedIfAbsent(PARAM_IG_BUSINESS_ACCOUNT_ID, '', False,
    'Instagram business account id');
  SeedIfAbsent(PARAM_IG_IMAGE_BASE_URL, 'https://donpulido.com', False,
    'Public base URL for served images');
end;

end.
