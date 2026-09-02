{ Apothêca - Instagram Auto-Publish

  Instagram Graph API client. Creates media containers (single image or
  carousel), waits for them to be ready, and publishes them, with auth and
  rate-limit error handling. Uses fphttpclient over TLS (opensslsockets).

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UInstagramApiClient;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, opensslsockets, fpjson, jsonparser,
  UPublishConfig, ULogger;

type
  EAuthError = class(Exception);
  EPublishError = class(Exception);

  TPublishResult = record
    MediaId: String;
    ProductId: String;   { catalog id, for the caller's tracking }
    Timestamp: String;   { YYYY-MM-DDTHH:MM:SSZ (UTC) }
  end;

  { TInstagramApiClient }

  TInstagramApiClient = class(TObject)
  private
    FConfig: TPublishConfig;
    function DoRequest(const Method, Url: String; Params: TStrings): TJSONObject;
    function MakeRequest(const Method, Url: String; Params: TStrings): TJSONObject;
    procedure WaitForContainerReady(const ContainerId: String);
    function CreateMediaContainer(const ImageUrl, Caption: String): String;
    function CreateCarouselItemContainer(const ImageUrl: String): String;
    function CreateCarouselContainer(Children: TStrings; const Caption: String): String;
    function PublishContainer(const ContainerId: String): String;
    function NowUtcTimestamp(): String;
  public
    constructor Create(AConfig: TPublishConfig);
    function PublishSingleImage(const ImageUrl, Caption, ProductId: String): TPublishResult;
    function PublishCarousel(const ImageUrls: array of String;
      const Caption, ProductId: String): TPublishResult;
  end;

const
  API_BASE_URL = 'https://graph.instagram.com/v21.0';
  REQUEST_TIMEOUT_MS = 30000;
  MAX_RETRIES = 3;
  CONTAINER_POLL_INTERVAL_S = 5;
  CONTAINER_MAX_WAIT_S = 60;

implementation

uses
  DateUtils;

constructor TInstagramApiClient.Create(AConfig: TPublishConfig);
begin
  inherited Create;
  FConfig := AConfig;
end;

function TInstagramApiClient.NowUtcTimestamp(): String;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', LocalTimeToUniversal(Now));
end;

{ Performs a single HTTP request and parses the JSON body. Raises on transport
  failure. The caller (MakeRequest) interprets status codes / error bodies. }
function TInstagramApiClient.DoRequest(const Method, Url: String;
  Params: TStrings): TJSONObject;
var
  Http: TFPHTTPClient;
  ResponseText, FullUrl, QueryStr: String;
  i: Integer;
  Data: TJSONData;
begin
  Result := nil;
  Http := TFPHTTPClient.Create(nil);
  try
    Http.ConnectTimeout := REQUEST_TIMEOUT_MS;
    Http.IOTimeout := REQUEST_TIMEOUT_MS;
    Http.AddHeader('User-Agent', 'ApothecaPOS/1.0 (+https://donpulido.com)');
    Http.AddHeader('Accept', 'application/json');

    { Build a query string from params (values URL-encoded). }
    QueryStr := '';
    for i := 0 to Params.Count - 1 do
    begin
      if QueryStr <> '' then
        QueryStr := QueryStr + '&';
      QueryStr := QueryStr +
        Params.Names[i] + '=' +
        EncodeURLElement(Params.ValueFromIndex[i]);
    end;

    FullUrl := Url;
    if QueryStr <> '' then
      FullUrl := FullUrl + '?' + QueryStr;

    if UpperCase(Method) = 'POST' then
      ResponseText := Http.Post(FullUrl)
    else
      ResponseText := Http.Get(FullUrl);

    { Attach status via a synthetic field is not needed; caller reads
      Http.ResponseStatusCode through the exception path. Here we only parse. }
    if Trim(ResponseText) = '' then
      raise EPublishError.Create('Empty response from Graph API');

    Data := GetJSON(ResponseText);
    if not (Data is TJSONObject) then
    begin
      Data.Free;
      raise EPublishError.Create('Unexpected non-object JSON response');
    end;
    Result := TJSONObject(Data);
  finally
    Http.Free;
  end;
end;

{ Wraps DoRequest with token injection, error mapping, and bounded retry. }
function TInstagramApiClient.MakeRequest(const Method, Url: String;
  Params: TStrings): TJSONObject;
var
  Attempt, WaitSec, ErrCode: Integer;
  Obj, ErrObj: TJSONObject;
  ErrData: TJSONData;
  ErrMsg, Lower: String;
begin
  Result := nil;
  Params.Values['access_token'] := FConfig.AccessToken;

  for Attempt := 0 to MAX_RETRIES do
  begin
    Obj := nil;
    try
      Obj := DoRequest(Method, Url, Params);
    except
      on E: EAuthError do
        raise;
      on E: Exception do
      begin
        Lower := LowerCase(E.Message);
        { Map an HTTP 401 surfaced as an exception to an auth error. }
        if (Pos('401', Lower) > 0) then
        begin
          LogError('InstagramApiClient', 'AUTH_ERROR',
            'Invalid or expired access token');
          raise EAuthError.Create('Invalid or expired access token');
        end;
        { Retry on transient transport errors. }
        if Attempt < MAX_RETRIES then
        begin
          WaitSec := 1 shl (Attempt + 1);
          LogWarn('InstagramApiClient', 'REQUEST_RETRY',
            'error=' + E.Message + ' attempt=' + IntToStr(Attempt + 1));
          Sleep(WaitSec * 1000);
          Continue;
        end;
        raise EPublishError.Create('Request failed: ' + E.Message);
      end;
    end;

    { Inspect API-level error body. }
    ErrData := Obj.Find('error');
    if (ErrData <> nil) and (ErrData is TJSONObject) then
    begin
      ErrObj := TJSONObject(ErrData);
      ErrCode := ErrObj.Get('code', 0);
      ErrMsg := ErrObj.Get('message', 'Unknown error');

      if ErrCode = 190 then
      begin
        Obj.Free;
        LogError('InstagramApiClient', 'AUTH_ERROR',
          'Invalid or expired access token (code 190)');
        raise EAuthError.Create('Invalid or expired access token');
      end;

      if ErrCode = 4 then { rate limit }
      begin
        Obj.Free;
        if Attempt < MAX_RETRIES then
        begin
          WaitSec := 1 shl (Attempt + 1);
          LogWarn('InstagramApiClient', 'RATE_LIMITED',
            'retrying in ' + IntToStr(WaitSec) + 's attempt=' + IntToStr(Attempt + 1));
          Sleep(WaitSec * 1000);
          Continue;
        end;
        raise EPublishError.Create('Rate limit exceeded after retries');
      end;

      Obj.Free;
      raise EPublishError.Create('API error (code ' + IntToStr(ErrCode) +
        '): ' + ErrMsg);
    end;

    Result := Obj;
    Exit;
  end;

  raise EPublishError.Create('Request failed after all retries');
end;

function TInstagramApiClient.CreateMediaContainer(const ImageUrl,
  Caption: String): String;
var
  Params: TStringList;
  Obj: TJSONObject;
begin
  Params := TStringList.Create;
  try
    Params.Values['image_url'] := ImageUrl;
    Params.Values['caption'] := Caption;
    LogInfo('InstagramApiClient', 'CREATE_CONTAINER', 'single image');
    Obj := MakeRequest('POST',
      API_BASE_URL + '/' + FConfig.BusinessAccountId + '/media', Params);
    try
      Result := Obj.Get('id', '');
    finally
      Obj.Free;
    end;
  finally
    Params.Free;
  end;
end;

function TInstagramApiClient.CreateCarouselItemContainer(
  const ImageUrl: String): String;
var
  Params: TStringList;
  Obj: TJSONObject;
begin
  Params := TStringList.Create;
  try
    Params.Values['image_url'] := ImageUrl;
    Params.Values['is_carousel_item'] := 'true';
    Obj := MakeRequest('POST',
      API_BASE_URL + '/' + FConfig.BusinessAccountId + '/media', Params);
    try
      Result := Obj.Get('id', '');
    finally
      Obj.Free;
    end;
  finally
    Params.Free;
  end;
end;

function TInstagramApiClient.CreateCarouselContainer(Children: TStrings;
  const Caption: String): String;
var
  Params: TStringList;
  Obj: TJSONObject;
  ChildrenCsv: String;
  i: Integer;
begin
  ChildrenCsv := '';
  for i := 0 to Children.Count - 1 do
  begin
    if ChildrenCsv <> '' then
      ChildrenCsv := ChildrenCsv + ',';
    ChildrenCsv := ChildrenCsv + Children[i];
  end;

  Params := TStringList.Create;
  try
    Params.Values['media_type'] := 'CAROUSEL';
    Params.Values['children'] := ChildrenCsv;
    Params.Values['caption'] := Caption;
    LogInfo('InstagramApiClient', 'CREATE_CAROUSEL',
      'children=' + IntToStr(Children.Count));
    Obj := MakeRequest('POST',
      API_BASE_URL + '/' + FConfig.BusinessAccountId + '/media', Params);
    try
      Result := Obj.Get('id', '');
    finally
      Obj.Free;
    end;
  finally
    Params.Free;
  end;
end;

procedure TInstagramApiClient.WaitForContainerReady(const ContainerId: String);
var
  Params: TStringList;
  Obj: TJSONObject;
  Status: String;
  Elapsed: Integer;
begin
  Elapsed := 0;
  while Elapsed < CONTAINER_MAX_WAIT_S do
  begin
    Params := TStringList.Create;
    try
      Params.Values['fields'] := 'status_code';
      Obj := MakeRequest('GET', API_BASE_URL + '/' + ContainerId, Params);
      try
        Status := Obj.Get('status_code', 'UNKNOWN');
      finally
        Obj.Free;
      end;
    finally
      Params.Free;
    end;

    if (Status = 'FINISHED') or (Status = 'PUBLISHED') then
      Exit;
    if Status = 'ERROR' then
      raise EPublishError.Create('Container ' + ContainerId + ' failed (ERROR)');
    if Status = 'EXPIRED' then
      raise EPublishError.Create('Container ' + ContainerId + ' expired');

    LogInfo('InstagramApiClient', 'CONTAINER_WAIT',
      'id=' + ContainerId + ' status=' + Status);
    Sleep(CONTAINER_POLL_INTERVAL_S * 1000);
    Inc(Elapsed, CONTAINER_POLL_INTERVAL_S);
  end;

  raise EPublishError.Create('Container ' + ContainerId +
    ' not ready after ' + IntToStr(CONTAINER_MAX_WAIT_S) + 's');
end;

function TInstagramApiClient.PublishContainer(const ContainerId: String): String;
var
  Params: TStringList;
  Obj: TJSONObject;
begin
  WaitForContainerReady(ContainerId);
  Params := TStringList.Create;
  try
    Params.Values['creation_id'] := ContainerId;
    Obj := MakeRequest('POST',
      API_BASE_URL + '/' + FConfig.BusinessAccountId + '/media_publish', Params);
    try
      Result := Obj.Get('id', '');
    finally
      Obj.Free;
    end;
  finally
    Params.Free;
  end;
end;

function TInstagramApiClient.PublishSingleImage(const ImageUrl, Caption,
  ProductId: String): TPublishResult;
var
  ContainerId, MediaId: String;
begin
  ContainerId := CreateMediaContainer(ImageUrl, Caption);
  MediaId := PublishContainer(ContainerId);
  Result.MediaId := MediaId;
  Result.ProductId := ProductId;
  Result.Timestamp := NowUtcTimestamp();
  LogInfo('InstagramApiClient', 'PUBLISHED',
    'product=' + ProductId + ' media=' + MediaId);
end;

function TInstagramApiClient.PublishCarousel(const ImageUrls: array of String;
  const Caption, ProductId: String): TPublishResult;
var
  Children: TStringList;
  i: Integer;
  CarouselId, MediaId: String;
begin
  Children := TStringList.Create;
  try
    for i := 0 to High(ImageUrls) do
      Children.Add(CreateCarouselItemContainer(ImageUrls[i]));
    CarouselId := CreateCarouselContainer(Children, Caption);
    MediaId := PublishContainer(CarouselId);
  finally
    Children.Free;
  end;
  Result.MediaId := MediaId;
  Result.ProductId := ProductId;
  Result.Timestamp := NowUtcTimestamp();
  LogInfo('InstagramApiClient', 'PUBLISHED',
    'product=' + ProductId + ' media=' + MediaId + ' (carousel)');
end;

end.
