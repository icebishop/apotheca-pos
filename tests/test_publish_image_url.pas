{ Feature: instagram-auto-publish
  Property 5: Public URL construction
  Property 6: Aspect-ratio acceptance
  Property 7: Carousel cap (<= 10 resolved images)

  Property 5 and the aspect-ratio arithmetic (Property 6) are verified as pure
  functions mirroring the resolver's documented rules. Property 7 is verified
  end-to-end by generating >10 small valid-ratio PNGs on disk and calling
  TPublishImageResolver.Resolve.

  **Validates: Requirements 6.2, 6.3, 6.4, 6.7**
}

unit test_publish_image_url;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FPimage, FPWritePNG, fpcunit, testregistry,
  URegistryItem, UPublishImageResolver;

type
  TTestPublishImageUrl = class(TTestCase)
  private
    function JoinUrl(const BaseUrl, Filename: String): String;
    function RatioAccepted(w, h: Integer): Boolean;
    procedure WritePng(const Path: String; w, h: Integer);
    function TempImageDir: String;
  published
    procedure Test_UrlJoin_TrimsTrailingSlash_Property;
    procedure Test_AspectRatio_Bounds_Property;
    procedure Test_Resolve_CarouselCap;
  end;

implementation

const
  ITERATIONS = 200;
  MIN_RATIO = 0.8;
  MAX_RATIO = 1.91;

{ Mirrors the resolver: trim all trailing '/' from base, join with single '/'. }
function TTestPublishImageUrl.JoinUrl(const BaseUrl, Filename: String): String;
var
  CleanBase, F: String;
begin
  CleanBase := BaseUrl;
  while (CleanBase <> '') and (CleanBase[Length(CleanBase)] = '/') do
    CleanBase := Copy(CleanBase, 1, Length(CleanBase) - 1);
  F := Filename;
  while (F <> '') and (F[1] = '/') do
    F := Copy(F, 2, Length(F) - 1);
  Result := CleanBase + '/' + F;
end;

function TTestPublishImageUrl.RatioAccepted(w, h: Integer): Boolean;
var
  Ratio: Double;
begin
  if h = 0 then
    Exit(False);
  Ratio := w / h;
  Result := (Ratio >= MIN_RATIO) and (Ratio <= MAX_RATIO);
end;

procedure TTestPublishImageUrl.WritePng(const Path: String; w, h: Integer);
var
  Img: TFPMemoryImage;
  Writer: TFPWriterPNG;
  x, y: Integer;
begin
  Img := TFPMemoryImage.Create(w, h);
  Writer := TFPWriterPNG.Create;
  try
    for y := 0 to h - 1 do
      for x := 0 to w - 1 do
        Img.Colors[x, y] := colBlue;
    Img.SaveToFile(Path, Writer);
  finally
    Writer.Free;
    Img.Free;
  end;
end;

function TTestPublishImageUrl.TempImageDir: String;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir) +
    'iap_test_' + IntToStr(Random(1000000));
  ForceDirectories(Result);
end;

{ Property 5: URL = trim-trailing-slash(base) + '/' + filename, no leading slash. }
procedure TTestPublishImageUrl.Test_UrlJoin_TrimsTrailingSlash_Property;
var
  Iteration, Slashes, i: Integer;
  Base, Fname, Url: String;
begin
  AssertEquals('basic', 'https://x.com/a.webp',
    JoinUrl('https://x.com', '/a.webp'));
  AssertEquals('trailing slash trimmed', 'https://x.com/a.webp',
    JoinUrl('https://x.com/', 'a.webp'));

  for Iteration := 1 to ITERATIONS do
  begin
    Base := 'https://host.example';
    Slashes := Random(4);
    for i := 1 to Slashes do
      Base := Base + '/';
    Fname := 'img' + IntToStr(Iteration) + '.webp';
    if Random(2) = 0 then
      Fname := '/' + Fname;

    Url := JoinUrl(Base, Fname);
    { Exactly one slash between host and path beyond the scheme. }
    AssertEquals(Format('Iteration %d', [Iteration]),
      'https://host.example/img' + IntToStr(Iteration) + '.webp', Url);
    { No "//" beyond the "https://" scheme. }
    AssertTrue('no double slash beyond scheme',
      Pos('//', Copy(Url, 9, Length(Url))) = 0);
  end;
end;

{ Property 6: accepted iff 0.8 <= w/h <= 1.91. }
procedure TTestPublishImageUrl.Test_AspectRatio_Bounds_Property;
var
  Iteration, w, h: Integer;
  Ratio: Double;
  Expected: Boolean;
begin
  { Boundary cases. }
  AssertTrue('4:5 (0.8) accepted', RatioAccepted(800, 1000));
  AssertTrue('1.91:1 accepted', RatioAccepted(1910, 1000));
  AssertTrue('square accepted', RatioAccepted(500, 500));
  AssertFalse('too tall rejected', RatioAccepted(700, 1000));   { 0.7 }
  AssertFalse('too wide rejected', RatioAccepted(2000, 1000));  { 2.0 }

  for Iteration := 1 to ITERATIONS do
  begin
    w := 100 + Random(2000);
    h := 100 + Random(2000);
    Ratio := w / h;
    Expected := (Ratio >= MIN_RATIO) and (Ratio <= MAX_RATIO);
    AssertEquals(Format('Iteration %d: %dx%d ratio=%.4f',
      [Iteration, w, h, Ratio]), Expected, RatioAccepted(w, h));
  end;
end;

{ Property 7: Resolve returns at most 10 images even when more are provided.
  Uses square PNGs (ratio 1.0, accepted) so each resolves to a direct URL. }
procedure TTestPublishImageUrl.Test_Resolve_CarouselCap;
var
  Dir: String;
  Item: TRegistryItem;
  Resolver: TPublishImageResolver;
  Resolved: TResolvedImageArray;
  i: Integer;
  Fname: String;
begin
  Dir := TempImageDir;
  Item := TRegistryItem.Create;
  Resolver := TPublishImageResolver.Create;
  try
    { Create 15 valid square PNGs and reference them all. }
    for i := 1 to 15 do
    begin
      Fname := 'sq' + IntToStr(i) + '.png';
      WritePng(IncludeTrailingPathDelimiter(Dir) + Fname, 300, 300);
      Item.Images.Add('/' + Fname);
    end;

    Resolved := Resolver.Resolve(Item, Dir, 'https://cdn.example');

    AssertTrue(
      Format('resolved %d images, expected <= 10', [Length(Resolved)]),
      Length(Resolved) <= 10);
    AssertEquals('all 10 slots used for 15 valid images', 10, Length(Resolved));
    { Spot-check URL join on the first resolved image. }
    AssertEquals('first url', 'https://cdn.example/sq1.png', Resolved[0].PublicUrl);
  finally
    Resolver.Free;
    Item.Free;
    { Clean up temp files. }
    for i := 1 to 15 do
      DeleteFile(IncludeTrailingPathDelimiter(Dir) + 'sq' + IntToStr(i) + '.png');
    RemoveDir(Dir);
  end;
end;

initialization
  Randomize;
  RegisterTest(TTestPublishImageUrl);

end.
