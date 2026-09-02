{ Apothêca - Instagram Auto-Publish

  Publish configuration: loads Instagram credentials and the public image base
  URL from environment variables, optionally seeded from a .env file.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UPublishConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  EPublishConfigError = class(Exception);

  { TPublishConfig }

  TPublishConfig = class(TObject)
  private
    FAccessToken: String;
    FBusinessAccountId: String;
    FImageBaseUrl: String;
    { Loads KEY=VALUE pairs from a .env file into EnvMap (blank/# lines ignored). }
    class procedure LoadEnvFile(const EnvFilePath: String; EnvMap: TStrings);
    { System env var wins; otherwise falls back to the .env map. }
    class function Resolve(const Key: String; EnvMap: TStrings): String;
  public
    { Loads config from environment (seeded by the optional .env file).
      Raises EPublishConfigError when any required value is missing/empty or
      when the base URL scheme is invalid. }
    class function Load(const EnvFilePath: String): TPublishConfig;

    { Builds config directly from explicit values (e.g. from the parameters
      table). Applies the same validation as Load. }
    class function FromValues(const Token, AccountId, BaseUrl: String): TPublishConfig;

    property AccessToken: String read FAccessToken;
    property BusinessAccountId: String read FBusinessAccountId;
    property ImageBaseUrl: String read FImageBaseUrl;
  end;

implementation

{ Parse a KEY=VALUE .env file into EnvMap. Lines that are blank or start with
  '#' are ignored. }
class procedure TPublishConfig.LoadEnvFile(const EnvFilePath: String;
  EnvMap: TStrings);
var
  Lines: TStringList;
  i, EqPos: Integer;
  Line, Key, Value: String;
begin
  if not FileExists(EnvFilePath) then
    Exit;

  Lines := TStringList.Create;
  try
    Lines.LoadFromFile(EnvFilePath);
    for i := 0 to Lines.Count - 1 do
    begin
      Line := Trim(Lines[i]);
      if (Line = '') or (Line[1] = '#') then
        Continue;
      EqPos := Pos('=', Line);
      if EqPos <= 1 then
        Continue;
      Key := Trim(Copy(Line, 1, EqPos - 1));
      Value := Trim(Copy(Line, EqPos + 1, Length(Line) - EqPos));
      if Key = '' then
        Continue;
      EnvMap.Values[Key] := Value;
    end;
  finally
    Lines.Free;
  end;
end;

{ System environment variable wins; otherwise fall back to the .env map. }
class function TPublishConfig.Resolve(const Key: String; EnvMap: TStrings): String;
begin
  Result := Trim(GetEnvironmentVariable(Key));
  if Result = '' then
    Result := Trim(EnvMap.Values[Key]);
end;

class function TPublishConfig.Load(const EnvFilePath: String): TPublishConfig;
var
  Cfg: TPublishConfig;
  Missing, EnvMap: TStringList;
  Token, AccountId, BaseUrl: String;
begin
  EnvMap := TStringList.Create;
  Missing := TStringList.Create;
  try
    LoadEnvFile(EnvFilePath, EnvMap);

    Token := Resolve('INSTAGRAM_ACCESS_TOKEN', EnvMap);
    AccountId := Resolve('INSTAGRAM_BUSINESS_ACCOUNT_ID', EnvMap);
    BaseUrl := Resolve('PUBLIC_IMAGE_BASE_URL', EnvMap);

    if Token = '' then Missing.Add('INSTAGRAM_ACCESS_TOKEN');
    if AccountId = '' then Missing.Add('INSTAGRAM_BUSINESS_ACCOUNT_ID');
    if BaseUrl = '' then Missing.Add('PUBLIC_IMAGE_BASE_URL');

    if Missing.Count > 0 then
      raise EPublishConfigError.Create(
        'Missing or empty required environment variables: ' +
        StringReplace(Missing.CommaText, ',', ', ', [rfReplaceAll]));

    if not (
      (Copy(LowerCase(BaseUrl), 1, 7) = 'http://') or
      (Copy(LowerCase(BaseUrl), 1, 8) = 'https://')) then
      raise EPublishConfigError.Create(
        'PUBLIC_IMAGE_BASE_URL must start with http:// or https://, got: ' + BaseUrl);

    Cfg := TPublishConfig.Create;
    Cfg.FAccessToken := Token;
    Cfg.FBusinessAccountId := AccountId;
    Cfg.FImageBaseUrl := BaseUrl;
    Result := Cfg;
  finally
    Missing.Free;
    EnvMap.Free;
  end;
end;

class function TPublishConfig.FromValues(const Token, AccountId,
  BaseUrl: String): TPublishConfig;
var
  Cfg: TPublishConfig;
  Missing: TStringList;
  T, A, B: String;
begin
  T := Trim(Token);
  A := Trim(AccountId);
  B := Trim(BaseUrl);
  Missing := TStringList.Create;
  try
    if T = '' then Missing.Add('INSTAGRAM_ACCESS_TOKEN');
    if A = '' then Missing.Add('INSTAGRAM_BUSINESS_ACCOUNT_ID');
    if B = '' then Missing.Add('PUBLIC_IMAGE_BASE_URL');
    if Missing.Count > 0 then
      raise EPublishConfigError.Create(
        'Missing or empty required parameters: ' +
        StringReplace(Missing.CommaText, ',', ', ', [rfReplaceAll]));

    if not (
      (Copy(LowerCase(B), 1, 7) = 'http://') or
      (Copy(LowerCase(B), 1, 8) = 'https://')) then
      raise EPublishConfigError.Create(
        'PUBLIC_IMAGE_BASE_URL must start with http:// or https://, got: ' + B);

    Cfg := TPublishConfig.Create;
    Cfg.FAccessToken := T;
    Cfg.FBusinessAccountId := A;
    Cfg.FImageBaseUrl := B;
    Result := Cfg;
  finally
    Missing.Free;
  end;
end;

end.
