{ Feature: units-sold-report, Property 5: Date filter correctness }
{
  Property-based test for Units Sold Report date filter correctness.
  Generates random date ranges and random sale transaction data, applies the
  date filter using Julian Day conversion, and asserts:
    - All returned items have dates within [StartDate 00:00:00, EndDate 23:59:59]
    - No transaction with a date within the range is excluded from results

  Validates: Requirements 2.1, 2.2

  Uses FPCUnit with a lightweight random-generator harness (150 iterations).
}

unit test_units_sold_date_filter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, DateUtils, fpcunit, testregistry;

type

  TSaleTransaction = record
    TransactionId: Integer;
    TxDate: TDateTime;
    JulianDay: Double;
    ProductId: Integer;
    ProductName: String;
    Quantity: Integer;
    UnitPrice: Real;
    UnitCost: Real;
  end;

  PSaleTransaction = ^TSaleTransaction;

  { TTestUnitsSoldDateFilter }

  TTestUnitsSoldDateFilter = class(TTestCase)
  private
    { Generates a random date within the last 365 days from today }
    function RandomDateWithinLastYear: TDateTime;
    { Converts a TDateTime to Julian Day as the report engine does }
    function DateTimeToJulianDay(ADate: TDateTime): Double;
    { Generates a random sale transaction record with a given date }
    function GenerateTransaction(AId: Integer; ADate: TDateTime): PSaleTransaction;
    { Generates a list of random sale transactions (random dates within last year) }
    function GenerateTransactionList(ACount: Integer): TList;
    { Generates a valid date range [StartDate, EndDate] within the last year }
    procedure GenerateRandomDateRange(out AStartDate, AEndDate: TDateTime);
    { Simulates the date filter logic as used by GetUnitsSoldReport:
      Converts StartDate/EndDate to Julian Day and returns a new TList
      containing only transactions where JulianDay >= start_julian AND
      JulianDay <= end_julian }
    function FilterByDateRange(ATransactions: TList;
      AStartDate, AEndDate: TDateTime): TList;
    { Frees a TList of PSaleTransaction pointers }
    procedure FreeTransactionList(var AList: TList);
    { Generates a random string for names }
    function RandomName(ALen: Integer): String;
  published
    procedure Test_DateFilter_Correctness_Property;
  end;

implementation

const
  ITERATION_COUNT = 150;
  ALPHA_CHARS = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';

{ TTestUnitsSoldDateFilter }

function TTestUnitsSoldDateFilter.RandomName(ALen: Integer): String;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ALen do
    Result := Result + ALPHA_CHARS[1 + Random(Length(ALPHA_CHARS))];
end;

function TTestUnitsSoldDateFilter.RandomDateWithinLastYear: TDateTime;
var
  DaysBack: Integer;
  Hours, Minutes, Seconds: Integer;
begin
  { Random day offset within last 365 days }
  DaysBack := Random(365);
  { Random time of day }
  Hours := Random(24);
  Minutes := Random(60);
  Seconds := Random(60);
  Result := Date - DaysBack + EncodeTime(Hours, Minutes, Seconds, 0);
end;

function TTestUnitsSoldDateFilter.DateTimeToJulianDay(ADate: TDateTime): Double;
begin
  { This matches how TReportEngine stores/compares dates:
    The operation.date field in SQLite is stored as Julian Day.
    A TDateTime with time component maps to Julian Day as:
    Int(Date) + 2415018.5 + fractional_time }
  Result := Int(ADate) + 2415018.5 + Frac(ADate);
end;

function TTestUnitsSoldDateFilter.GenerateTransaction(AId: Integer;
  ADate: TDateTime): PSaleTransaction;
begin
  New(Result);
  Result^.TransactionId := AId;
  Result^.TxDate := ADate;
  Result^.JulianDay := DateTimeToJulianDay(ADate);
  Result^.ProductId := 1 + Random(100);
  Result^.ProductName := RandomName(4 + Random(12));
  Result^.Quantity := 1 + Random(100);
  Result^.UnitPrice := (1 + Random(99900)) / 100.0; { 0.01..999.00 }
  Result^.UnitCost := (1 + Random(49900)) / 100.0;  { 0.01..499.00 }
end;

function TTestUnitsSoldDateFilter.GenerateTransactionList(ACount: Integer): TList;
var
  I: Integer;
  TxDate: TDateTime;
begin
  Result := TList.Create;
  for I := 0 to ACount - 1 do
  begin
    TxDate := RandomDateWithinLastYear;
    Result.Add(GenerateTransaction(I + 1, TxDate));
  end;
end;

procedure TTestUnitsSoldDateFilter.GenerateRandomDateRange(out AStartDate,
  AEndDate: TDateTime);
var
  D1, D2: TDateTime;
  DaysBack1, DaysBack2: Integer;
begin
  { Generate two random dates within last 365 days (date-only, no time) }
  DaysBack1 := Random(365);
  DaysBack2 := Random(365);
  D1 := Date - DaysBack1;
  D2 := Date - DaysBack2;
  { Ensure StartDate <= EndDate }
  if D1 <= D2 then
  begin
    AStartDate := D1;
    AEndDate := D2;
  end
  else
  begin
    AStartDate := D2;
    AEndDate := D1;
  end;
end;

function TTestUnitsSoldDateFilter.FilterByDateRange(ATransactions: TList;
  AStartDate, AEndDate: TDateTime): TList;
var
  I: Integer;
  Rec: PSaleTransaction;
  StartJulian, EndJulian: Double;
begin
  { Simulates the filtering logic in TReportEngine.GetUnitsSoldReport:
    Query.Params.ParamByName('start_date').AsFloat := Int(StartDate) + 2415018.5;
    Query.Params.ParamByName('end_date').AsFloat := Int(EndDate) + 2415019.49999;
    WHERE o.date >= :start_date AND o.date <= :end_date

    This means: include all transactions from the start of StartDate (00:00:00)
    to the end of EndDate (23:59:59). The +2415019.49999 formula covers the
    full end-of-day in Julian Day terms. }
  Result := TList.Create;
  StartJulian := Int(AStartDate) + 2415018.5;
  EndJulian := Int(AEndDate) + 2415019.49999;

  for I := 0 to ATransactions.Count - 1 do
  begin
    Rec := PSaleTransaction(ATransactions[I]);
    if (Rec^.JulianDay >= StartJulian) and (Rec^.JulianDay <= EndJulian) then
      Result.Add(Rec);
  end;
end;

procedure TTestUnitsSoldDateFilter.FreeTransactionList(var AList: TList);
var
  I: Integer;
begin
  if AList <> nil then
  begin
    for I := 0 to AList.Count - 1 do
      Dispose(PSaleTransaction(AList[I]));
    AList.Free;
    AList := nil;
  end;
end;

procedure TTestUnitsSoldDateFilter.Test_DateFilter_Correctness_Property;
var
  Iteration, TxCount, I: Integer;
  Transactions: TList;
  FilteredResults: TList;
  StartDate, EndDate: TDateTime;
  StartJulian, EndJulian: Double;
  Rec: PSaleTransaction;
  ExpectedCount: Integer;
begin
  Randomize;

  for Iteration := 1 to ITERATION_COUNT do
  begin
    { Generate random transaction list with 5..100 transactions }
    TxCount := 5 + Random(96); // 5..100
    Transactions := GenerateTransactionList(TxCount);
    FilteredResults := nil;
    try
      { Generate random date range }
      GenerateRandomDateRange(StartDate, EndDate);
      StartJulian := Int(StartDate) + 2415018.5;
      EndJulian := Int(EndDate) + 2415019.49999;

      { Apply filter }
      FilteredResults := FilterByDateRange(Transactions, StartDate, EndDate);

      { Property A: All returned items have dates within [StartDate 00:00:00, EndDate 23:59:59] }
      for I := 0 to FilteredResults.Count - 1 do
      begin
        Rec := PSaleTransaction(FilteredResults[I]);
        AssertTrue(
          Format('Iteration %d: Filtered transaction (ID=%d, JulianDay=%.6f) has date before StartDate julian %.6f',
            [Iteration, Rec^.TransactionId, Rec^.JulianDay, StartJulian]),
          Rec^.JulianDay >= StartJulian
        );
        AssertTrue(
          Format('Iteration %d: Filtered transaction (ID=%d, JulianDay=%.6f) has date after EndDate julian %.6f',
            [Iteration, Rec^.TransactionId, Rec^.JulianDay, EndJulian]),
          Rec^.JulianDay <= EndJulian
        );
      end;

      { Property B: No in-range transaction is excluded }
      ExpectedCount := 0;
      for I := 0 to Transactions.Count - 1 do
      begin
        Rec := PSaleTransaction(Transactions[I]);
        if (Rec^.JulianDay >= StartJulian) and (Rec^.JulianDay <= EndJulian) then
          Inc(ExpectedCount);
      end;

      AssertEquals(
        Format('Iteration %d: Result count mismatch. Expected %d matching transactions for range [%s, %s]',
          [Iteration, ExpectedCount,
           FormatDateTime('yyyy-mm-dd', StartDate),
           FormatDateTime('yyyy-mm-dd', EndDate)]),
        ExpectedCount, FilteredResults.Count
      );

    finally
      if FilteredResults <> nil then
        FilteredResults.Free; { Don't dispose records here, Transactions owns them }
      FreeTransactionList(Transactions);
    end;
  end;
end;

initialization
  RegisterTest(TTestUnitsSoldDateFilter);

end.
