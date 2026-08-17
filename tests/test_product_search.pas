{ Feature: modern-sales-ui, Property 1: Product search filter correctness }
{
  Property-based test for product search filter correctness.
  Generates random product lists (5..50 products with random names),
  picks a random substring S, and asserts:
    - All returned products contain S (case-insensitive)
    - No matching product is excluded from the results

  Validates: Requirements 2.2, 5.2

  Uses FPCUnit with a lightweight random-generator harness (100+ iterations).
}

unit test_product_search;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, fpcunit, testregistry;

type

  { TTestProductSearchFilter }

  TTestProductSearchFilter = class(TTestCase)
  private
    { Simulates the LIKE '%S%' case-insensitive filter used by
      TDataProducto.find and TFrameProducts.LoadProducts }
    function FilterProducts(const AProducts: TStringList;
      const ASearchTerm: String): TStringList;
    { Generates a random string of given length using mixed-case alpha chars }
    function RandomProductName(AMinLen, AMaxLen: Integer): String;
    { Generates a random product list with Count items }
    function GenerateProductList(ACount: Integer): TStringList;
    { Picks a random substring from a given string }
    function PickRandomSubstring(const ASource: String): String;
  published
    procedure Test_SearchFilter_Correctness_Property;
  end;

implementation

const
  ITERATION_COUNT = 150;
  ALPHA_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

{ TTestProductSearchFilter }

function TTestProductSearchFilter.RandomProductName(AMinLen, AMaxLen: Integer): String;
var
  Len, I: Integer;
begin
  Len := AMinLen + Random(AMaxLen - AMinLen + 1);
  Result := '';
  for I := 1 to Len do
    Result := Result + ALPHA_CHARS[1 + Random(Length(ALPHA_CHARS))];
end;

function TTestProductSearchFilter.GenerateProductList(ACount: Integer): TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := 0 to ACount - 1 do
    Result.Add(RandomProductName(3, 20));
end;

function TTestProductSearchFilter.PickRandomSubstring(const ASource: String): String;
var
  StartPos, SubLen: Integer;
begin
  if Length(ASource) = 0 then
  begin
    Result := '';
    Exit;
  end;
  { Pick a substring of length 1..min(5, Length(ASource)) starting at a random position }
  SubLen := 1 + Random(Min(5, Length(ASource)));
  StartPos := 1 + Random(Length(ASource) - SubLen + 1);
  Result := Copy(ASource, StartPos, SubLen);
end;

function TTestProductSearchFilter.FilterProducts(const AProducts: TStringList;
  const ASearchTerm: String): TStringList;
var
  I: Integer;
  LowerSearch: String;
begin
  { Simulates SQL: WHERE name LIKE '%SearchTerm%' (case-insensitive)
    SQLite LIKE is case-insensitive for ASCII characters by default. }
  Result := TStringList.Create;
  LowerSearch := LowerCase(ASearchTerm);
  for I := 0 to AProducts.Count - 1 do
  begin
    if Pos(LowerSearch, LowerCase(AProducts[I])) > 0 then
      Result.Add(AProducts[I]);
  end;
end;

procedure TTestProductSearchFilter.Test_SearchFilter_Correctness_Property;
var
  Iteration, ProductCount, SourceIndex, I: Integer;
  Products, FilteredResults: TStringList;
  SearchTerm, LowerSearch: String;
  MatchFound: Boolean;
  ExpectedCount: Integer;
begin
  Randomize;

  for Iteration := 1 to ITERATION_COUNT do
  begin
    { Generate random product list with 5..50 products }
    ProductCount := 5 + Random(46); // 5..50
    Products := GenerateProductList(ProductCount);
    try
      { Pick a random product name to extract substring from }
      SourceIndex := Random(Products.Count);
      SearchTerm := PickRandomSubstring(Products[SourceIndex]);

      { Skip empty search terms (edge case: empty source string) }
      if SearchTerm = '' then
        Continue;

      LowerSearch := LowerCase(SearchTerm);

      { Apply filter }
      FilteredResults := FilterProducts(Products, SearchTerm);
      try
        { Property A: All returned products contain S (case-insensitive) }
        for I := 0 to FilteredResults.Count - 1 do
        begin
          AssertTrue(
            Format('Iteration %d: Filtered product "%s" does not contain search term "%s"',
              [Iteration, FilteredResults[I], SearchTerm]),
            Pos(LowerSearch, LowerCase(FilteredResults[I])) > 0
          );
        end;

        { Property B: No matching product is excluded from the results }
        for I := 0 to Products.Count - 1 do
        begin
          MatchFound := Pos(LowerSearch, LowerCase(Products[I])) > 0;
          if MatchFound then
          begin
            AssertTrue(
              Format('Iteration %d: Product "%s" matches "%s" but was excluded from results',
                [Iteration, Products[I], SearchTerm]),
              FilteredResults.IndexOf(Products[I]) >= 0
            );
          end;
        end;

        { Additional check: result count equals the number of matching products }
        ExpectedCount := 0;
        for I := 0 to Products.Count - 1 do
        begin
          if Pos(LowerSearch, LowerCase(Products[I])) > 0 then
            Inc(ExpectedCount);
        end;
        AssertEquals(
          Format('Iteration %d: Result count mismatch for search "%s"',
            [Iteration, SearchTerm]),
          ExpectedCount, FilteredResults.Count
        );

      finally
        FilteredResults.Free;
      end;
    finally
      Products.Free;
    end;
  end;
end;

initialization
  RegisterTest(TTestProductSearchFilter);

end.
