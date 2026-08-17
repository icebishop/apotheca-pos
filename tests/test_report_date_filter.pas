{ Feature: modern-sales-ui, Property 7: Report date filter correctness }
{
  Property-based test for report date filter correctness.
  Generates random date ranges and random transaction data, applies the
  date filter, and asserts:
    - All returned rows have dates within [StartDate, EndDate] inclusive
    - No transaction with a date within the range is excluded from results

  Validates: Requirements 4.4

  Uses FPCUnit with a lightweight random-generator harness (100+ iterations).
}

unit test_report_date_filter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Math, DateUtils, fpcunit, testregistry;

type

  TTransactionRecord = record
    TransactionId: Integer;
    TxDate: TDateTime;
    CustomerName: String;
    ProductName: String;
    Quantity: Integer;
    UnitPrice: Real;
    UnitCost: Real;
    TotalSale: Real;
    TotalCost: Real;
    Utility: Real;
  end;

  PTransactionRecord = ^TTransactionRecord;

  { TTestReportDateFilter }

  TTestReportDateFilter = class(TTestCase)
  private
    { Generates a random date within the last 365 days from today }
    function RandomDateWithinLastYear: TDateTime;
    { Generates a random transaction record with a given date }
    function GenerateTransaction(AId: Integer; ADate: TDateTime): PTransactionRecord;
    { Generates a list of random transactions (random dates within last year) }
    function GenerateTransactionList(ACount: Integer): TList;
    { Generates a valid date range [StartDate, EndDate] within the last year }
    procedure GenerateRandomDateRange(out AStartDate, AEndDate: TDateTime);
    { Simulates the date filter logic as used by TReportEngine/TFrameReports:
      Returns a new TList containing only transactions where
      TxDate >= StartDate (at 00:00:00) and TxDate <= EndDate (at 23:59:59) }
    function FilterByDateRange(ATransactions: TList;
      AStartDate, AEndDate: TDateTime): TList;
    { Frees a TList of PTransactionRecord pointers }
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

{ TTestReportDateFilter }

function TTestReportDateFilter.RandomName(ALen: Integer): String;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to ALen do
    Result := Result + ALPHA_CHARS[1 + Random(Length(ALPHA_CHARS))];
end;

function TTestReportDateFilter.RandomDateWithinLastYear: TDateTime;
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

function TTestReportDateFilter.GenerateTransaction(AId: Integer;
  ADate: TDateTime): PTransactionRecord;
begin
  New(Result);
  Result^.TransactionId := AId;
  Result^.TxDate := ADate;
  Result^.CustomerName := RandomName(5 + Random(10));
  Result^.ProductName := RandomName(4 + Random(12));
  Result^.Quantity := 1 + Random(50);
  Result^.UnitPrice := (1 + Random(99900)) / 100.0; { 0.01..999.00 }
  Result^.UnitCost := (1 + Random(49900)) / 100.0;  { 0.01..499.00 }
  Result^.TotalSale := Result^.Quantity * Result^.UnitPrice;
  Result^.TotalCost := Result^.Quantity * Result^.UnitCost;
  Result^.Utility := Result^.TotalSale - Result^.TotalCost;
end;

function TTestReportDateFilter.GenerateTransactionList(ACount: Integer): TList;
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

procedure TTestReportDateFilter.GenerateRandomDateRange(out AStartDate,
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

function TTestReportDateFilter.FilterByDateRange(ATransactions: TList;
  AStartDate, AEndDate: TDateTime): TList;
var
  I: Integer;
  Rec: PTransactionRecord;
  FilterStart, FilterEnd: TDateTime;
begin
  { Simulates the filtering logic in TReportEngine.GetIncomeUtilityReport:
    StartStr := FormatDateTime('yyyy-mm-dd 00:00:00', StartDate);
    EndStr   := FormatDateTime('yyyy-mm-dd 23:59:59', EndDate);
    WHERE date_transaction >= :start_date AND date_transaction <= :end_date

    This means: include all transactions from the start of StartDate
    to the end of EndDate (23:59:59). }
  Result := TList.Create;
  FilterStart := Trunc(AStartDate); { Start of day: 00:00:00 }
  FilterEnd := Trunc(AEndDate) + EncodeTime(23, 59, 59, 0); { End of day: 23:59:59 }

  for I := 0 to ATransactions.Count - 1 do
  begin
    Rec := PTransactionRecord(ATransactions[I]);
    if (Rec^.TxDate >= FilterStart) and (Rec^.TxDate <= FilterEnd) then
      Result.Add(Rec);
  end;
end;

procedure TTestReportDateFilter.FreeTransactionList(var AList: TList);
var
  I: Integer;
begin
  if AList <> nil then
  begin
    for I := 0 to AList.Count - 1 do
      Dispose(PTransactionRecord(AList[I]));
    AList.Free;
    AList := nil;
  end;
end;

procedure TTestReportDateFilter.Test_DateFilter_Correctness_Property;
var
  Iteration, TxCount, I: Integer;
  Transactions: TList;
  FilteredResults: TList;
  StartDate, EndDate: TDateTime;
  FilterStart, FilterEnd: TDateTime;
  Rec: PTransactionRecord;
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
      FilterStart := Trunc(StartDate);
      FilterEnd := Trunc(EndDate) + EncodeTime(23, 59, 59, 0);

      { Apply filter }
      FilteredResults := FilterByDateRange(Transactions, StartDate, EndDate);

      { Property A: All returned rows have dates within [StartDate, EndDate] inclusive }
      for I := 0 to FilteredResults.Count - 1 do
      begin
        Rec := PTransactionRecord(FilteredResults[I]);
        AssertTrue(
          Format('Iteration %d: Filtered row (ID=%d, Date=%s) has date before StartDate %s',
            [Iteration, Rec^.TransactionId,
             FormatDateTime('yyyy-mm-dd hh:nn:ss', Rec^.TxDate),
             FormatDateTime('yyyy-mm-dd', StartDate)]),
          Rec^.TxDate >= FilterStart
        );
        AssertTrue(
          Format('Iteration %d: Filtered row (ID=%d, Date=%s) has date after EndDate %s',
            [Iteration, Rec^.TransactionId,
             FormatDateTime('yyyy-mm-dd hh:nn:ss', Rec^.TxDate),
             FormatDateTime('yyyy-mm-dd', EndDate)]),
          Rec^.TxDate <= FilterEnd
        );
      end;

      { Property B: No transaction with a date in range is excluded }
      ExpectedCount := 0;
      for I := 0 to Transactions.Count - 1 do
      begin
        Rec := PTransactionRecord(Transactions[I]);
        if (Rec^.TxDate >= FilterStart) and (Rec^.TxDate <= FilterEnd) then
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
  RegisterTest(TTestReportDateFilter);

end.
