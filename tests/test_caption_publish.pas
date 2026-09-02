{ Feature: instagram-auto-publish
  Property 2: Price formatting
  Property 3: Discount percentage
  Property 4: Caption length bound

  Property-based tests for TCaptionBuilder (pure logic, no I/O), following the
  FPCUnit + random-harness pattern used by test_csv_export.pas.

  **Validates: Requirements 5.2, 5.3, 5.4, 5.5**
}

unit test_caption_publish;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, LazUTF8, fpcunit, testregistry,
  URegistryItem, UCaptionBuilder;

type
  TTestCaptionPublish = class(TTestCase)
  private
    function MakeItem(const AName, ACategory, ABrand, ADesc: String;
      APrice: Integer; AHasOrig: Boolean; AOrig: Integer): TRegistryItem;
    function RandomText(AMaxLen: Integer): String;
    function ExpectedGrouping(Amount: Integer): String;
  published
    procedure Test_FormatPriceCop_Grouping_Property;
    procedure Test_DiscountPercent_HalfUp_Property;
    procedure Test_Caption_LengthBound_Property;
    procedure Test_Caption_HashtagsDroppedBeforeDescription;
  end;

implementation

const
  ITERATIONS = 200;
  ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ';
  CATS: array[0..5] of String =
    ('Kits', 'Casquillos', 'Tizas', 'Guantes', 'Accesorios', 'Otra');

function TTestCaptionPublish.MakeItem(const AName, ACategory, ABrand,
  ADesc: String; APrice: Integer; AHasOrig: Boolean; AOrig: Integer): TRegistryItem;
begin
  Result := TRegistryItem.Create;
  Result.Name := AName;
  Result.Category := ACategory;
  Result.Brand := ABrand;
  Result.Description := ADesc;
  Result.Price := APrice;
  Result.HasOriginalPrice := AHasOrig;
  Result.OriginalPrice := AOrig;
  Result.IsVisible := True;
end;

function TTestCaptionPublish.RandomText(AMaxLen: Integer): String;
var
  Len, i: Integer;
begin
  Len := Random(AMaxLen + 1);
  Result := '';
  for i := 1 to Len do
    Result := Result + ALPHABET[1 + Random(Length(ALPHABET))];
end;

{ Independent reference implementation of the thousands grouping. }
function TTestCaptionPublish.ExpectedGrouping(Amount: Integer): String;
var
  Digits: String;
  i, Count: Integer;
begin
  Digits := IntToStr(Abs(Amount));
  Result := '';
  Count := 0;
  for i := Length(Digits) downto 1 do
  begin
    Result := Digits[i] + Result;
    Inc(Count);
    if (Count mod 3 = 0) and (i > 1) then
      Result := '.' + Result;
  end;
end;

{ Property 2: FormatPriceCop = "$" + grouped digits + " COP" }
procedure TTestCaptionPublish.Test_FormatPriceCop_Grouping_Property;
var
  Iteration, Amount: Integer;
  Expected, Got: String;
begin
  { Fixed edge cases first }
  AssertEquals('250 -> $250 COP', '$250 COP', TCaptionBuilder.FormatPriceCop(250));
  AssertEquals('1000 -> $1.000 COP', '$1.000 COP', TCaptionBuilder.FormatPriceCop(1000));
  AssertEquals('25000 -> $25.000 COP', '$25.000 COP', TCaptionBuilder.FormatPriceCop(25000));
  AssertEquals('0 -> $0 COP', '$0 COP', TCaptionBuilder.FormatPriceCop(0));
  AssertEquals('1000000 -> $1.000.000 COP', '$1.000.000 COP',
    TCaptionBuilder.FormatPriceCop(1000000));

  for Iteration := 1 to ITERATIONS do
  begin
    Amount := Random(100000000);
    Expected := '$' + ExpectedGrouping(Amount) + ' COP';
    Got := TCaptionBuilder.FormatPriceCop(Amount);
    AssertEquals(Format('Iteration %d: amount=%d', [Iteration, Amount]),
      Expected, Got);
  end;
end;

{ Property 3: DiscountPercent = round-half-up((orig-price)/orig*100) }
procedure TTestCaptionPublish.Test_DiscountPercent_HalfUp_Property;
var
  Iteration, Price, Orig, Expected, Got: Integer;
begin
  { Fixed cases }
  AssertEquals('80000->25000 = 69%', 69,
    TCaptionBuilder.DiscountPercent(25000, 80000));
  AssertEquals('half rounds up: price=1,orig=8 -> 87.5 -> 88', 88,
    TCaptionBuilder.DiscountPercent(1, 8));

  for Iteration := 1 to ITERATIONS do
  begin
    Orig := 2 + Random(1000000);
    Price := Random(Orig);  { 0..Orig-1, strictly less }
    Expected := Floor((Orig - Price) / Orig * 100 + 0.5);
    Got := TCaptionBuilder.DiscountPercent(Price, Orig);
    AssertEquals(Format('Iteration %d: price=%d orig=%d', [Iteration, Price, Orig]),
      Expected, Got);
  end;
end;

{ Property 4: caption UTF-8 length <= 2200 for any item }
procedure TTestCaptionPublish.Test_Caption_LengthBound_Property;
var
  Iteration, Price: Integer;
  Item: TRegistryItem;
  Caption: String;
begin
  for Iteration := 1 to ITERATIONS do
  begin
    Price := Random(500000);
    Item := MakeItem(
      RandomText(80),                        { name }
      CATS[Random(Length(CATS))],            { category }
      RandomText(20),                        { brand }
      RandomText(4000),                      { long description to force truncation }
      Price,
      Random(2) = 0,                         { hasOriginalPrice }
      Price + 1 + Random(500000));           { originalPrice > price }
    try
      Caption := TCaptionBuilder.Build(Item);
      AssertTrue(
        Format('Iteration %d: caption UTF-8 length %d exceeds 2200',
          [Iteration, UTF8Length(Caption)]),
        UTF8Length(Caption) <= 2200);
    finally
      Item.Free;
    end;
  end;
end;

{ Property 4 detail: when the body itself fits, a long-description item that
  overflows only because of hashtags must still contain the store link (i.e.
  hashtags are dropped before the description is cut). }
procedure TTestCaptionPublish.Test_Caption_HashtagsDroppedBeforeDescription;
var
  Item: TRegistryItem;
  Caption: String;
begin
  { A description sized so body+hashtags > 2200 but body alone <= 2200, so the
    length control must drop hashtags (not truncate the description). The
    non-hashtag overhead is well under 150 chars; a 2000-char description keeps
    the body under 2200 while the full hashtag line pushes it over. }
  Item := MakeItem('Producto', 'Casquillos', 'Kamui',
    StringOfChar('x', 2000), 25000, True, 80000);
  try
    Caption := TCaptionBuilder.Build(Item);
    AssertTrue('caption within limit', UTF8Length(Caption) <= 2200);
    AssertTrue('store link preserved (description not truncated first)',
      Pos('donpulido.com', Caption) > 0);
    AssertTrue('full description preserved (hashtags dropped instead)',
      Pos(StringOfChar('x', 2000), Caption) > 0);
    { With the full description kept, most hashtags must have been dropped:
      the general hashtags should not all survive. }
    AssertTrue('hashtags were trimmed', Pos('#CueLife', Caption) = 0);
  finally
    Item.Free;
  end;
end;

initialization
  Randomize;
  RegisterTest(TTestCaptionPublish);

end.
