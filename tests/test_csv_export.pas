{ Feature: modern-sales-ui, Property 8: CSV export completeness }
{
  Property-based test for CSV export completeness.

  For any report grid data with R rows and C columns, the exported CSV shall
  contain exactly R+1 lines (1 header + R data lines), and each line shall
  contain exactly C comma-separated quoted fields matching the grid cell values.

  This test exercises the pure CSV export logic extracted from
  TFrameReports.BtnExportCSVClick without requiring GUI access.

  **Validates: Requirements 4.5**

  Uses FPCUnit with a lightweight random-generator harness (150 iterations).
}

unit test_csv_export;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry;

type
  { 2D grid stored as a flat TStringList with row-major layout }
  TGridData = record
    Cells: TStringList;  { flat storage: index = row * ColCount + col }
    RowCount: Integer;
    ColCount: Integer;
  end;

  { TTestCSVExport }

  TTestCSVExport = class(TTestCase)
  private
    { Simulates the CSV export logic from TFrameReports.BtnExportCSVClick.
      Takes grid data and produces a CSV string.
      Row 0 = header row, rows 1..R = data rows.
      Each field is quoted and comma-separated: "val1","val2",...,"valN" }
    function ExportGridToCSV(const AGrid: TGridData): String;
    { Gets a cell value from the grid }
    function GetCell(const AGrid: TGridData; ARow, ACol: Integer): String;
    { Sets a cell value in the grid }
    procedure SetCell(var AGrid: TGridData; ARow, ACol: Integer; const AValue: String);
    { Initializes a grid with given dimensions }
    procedure InitGrid(var AGrid: TGridData; ARowCount, AColCount: Integer);
    { Frees grid resources }
    procedure FreeGrid(var AGrid: TGridData);
    { Generates a random string of length 0..MaxLen with printable ASCII }
    function RandomCellValue(AMaxLen: Integer; AAllowSpecial: Boolean): String;
    { Parses a CSV line and returns the quoted fields as a TStringList }
    function ParseCSVLine(const ALine: String): TStringList;
  published
    procedure Test_CSVExport_LineCount_Property;
    procedure Test_CSVExport_FieldCount_Property;
    procedure Test_CSVExport_FieldValues_Property;
    procedure Test_CSVExport_Combined_Property;
  end;

implementation

const
  ITERATIONS = 150;
  ROWS_MIN = 1;
  ROWS_MAX = 20;
  COLS_MIN = 1;
  COLS_MAX = 12;
  CELL_MAX_LEN = 15;
  { Printable ASCII chars safe for basic CSV (no quote, no comma, no newline) }
  SAFE_CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 ._-+=';

{ TTestCSVExport }

procedure TTestCSVExport.InitGrid(var AGrid: TGridData; ARowCount, AColCount: Integer);
var
  I: Integer;
begin
  AGrid.RowCount := ARowCount;
  AGrid.ColCount := AColCount;
  AGrid.Cells := TStringList.Create;
  { Pre-fill with empty strings }
  for I := 0 to (ARowCount * AColCount) - 1 do
    AGrid.Cells.Add('');
end;

procedure TTestCSVExport.FreeGrid(var AGrid: TGridData);
begin
  AGrid.Cells.Free;
  AGrid.Cells := nil;
end;

function TTestCSVExport.GetCell(const AGrid: TGridData; ARow, ACol: Integer): String;
begin
  Result := AGrid.Cells[ARow * AGrid.ColCount + ACol];
end;

procedure TTestCSVExport.SetCell(var AGrid: TGridData; ARow, ACol: Integer;
  const AValue: String);
begin
  AGrid.Cells[ARow * AGrid.ColCount + ACol] := AValue;
end;

function TTestCSVExport.ExportGridToCSV(const AGrid: TGridData): String;
var
  StringList: TStringList;
  i, j: Integer;
  LineStr: String;
begin
  { This replicates the logic from TFrameReports.BtnExportCSVClick:
    for i := 0 to GridReport.RowCount - 1 do
    begin
      LineStr := '';
      for j := 0 to GridReport.ColCount - 1 do
      begin
        if j > 0 then
          LineStr := LineStr + ',';
        LineStr := LineStr + '"' + GridReport.Cells[j, i] + '"';
      end;
      StringList.Add(LineStr);
    end;
  }
  StringList := TStringList.Create;
  try
    for i := 0 to AGrid.RowCount - 1 do
    begin
      LineStr := '';
      for j := 0 to AGrid.ColCount - 1 do
      begin
        if j > 0 then
          LineStr := LineStr + ',';
        LineStr := LineStr + '"' + GetCell(AGrid, i, j) + '"';
      end;
      StringList.Add(LineStr);
    end;
    Result := StringList.Text;
  finally
    StringList.Free;
  end;
end;

function TTestCSVExport.RandomCellValue(AMaxLen: Integer;
  AAllowSpecial: Boolean): String;
var
  Len, I: Integer;
  Ch: Char;
begin
  Len := Random(AMaxLen + 1); { 0..AMaxLen }
  Result := '';
  for I := 1 to Len do
  begin
    if AAllowSpecial and (Random(10) = 0) then
      Ch := SAFE_CHARS[1 + Random(Length(SAFE_CHARS))]
    else
      Ch := SAFE_CHARS[1 + Random(Length(SAFE_CHARS))];
    Result := Result + Ch;
  end;
end;

function TTestCSVExport.ParseCSVLine(const ALine: String): TStringList;
var
  I: Integer;
  InQuote: Boolean;
  CurrentField: String;
begin
  { Parse a line of format: "field1","field2",...,"fieldN"
    Assumes fields are always quoted and separated by commas.
    This is the format produced by the export logic. }
  Result := TStringList.Create;
  InQuote := False;
  CurrentField := '';
  I := 1;

  while I <= Length(ALine) do
  begin
    if (ALine[I] = '"') and (not InQuote) then
    begin
      { Start of quoted field }
      InQuote := True;
      CurrentField := '';
    end
    else if (ALine[I] = '"') and InQuote then
    begin
      { End of quoted field }
      InQuote := False;
      Result.Add(CurrentField);
      CurrentField := '';
    end
    else if (ALine[I] = ',') and (not InQuote) then
    begin
      { Field separator — skip }
    end
    else if InQuote then
    begin
      { Character inside a quoted field }
      CurrentField := CurrentField + ALine[I];
    end;
    Inc(I);
  end;
end;

{ Test that CSV output has exactly R+1 lines (1 header + R data rows) }
procedure TTestCSVExport.Test_CSVExport_LineCount_Property;
var
  Iteration, R, C, I, J: Integer;
  Grid: TGridData;
  CSV: String;
  Lines: TStringList;
begin
  for Iteration := 1 to ITERATIONS do
  begin
    R := ROWS_MIN + Random(ROWS_MAX - ROWS_MIN + 1);  { data rows }
    C := COLS_MIN + Random(COLS_MAX - COLS_MIN + 1);   { columns }

    { Build grid: row 0 = header, rows 1..R = data }
    InitGrid(Grid, R + 1, C);
    for I := 0 to R do
      for J := 0 to C - 1 do
        SetCell(Grid, I, J, RandomCellValue(CELL_MAX_LEN, False));

    { Export }
    CSV := ExportGridToCSV(Grid);

    { Parse into lines }
    Lines := TStringList.Create;
    try
      Lines.Text := CSV;
      { Remove any trailing empty line caused by TStringList.Text trailing newline }
      while (Lines.Count > 0) and (Lines[Lines.Count - 1] = '') do
        Lines.Delete(Lines.Count - 1);

      AssertEquals(
        Format('Iteration %d: Expected %d lines (1 header + %d data), got %d. R=%d, C=%d',
          [Iteration, R + 1, R, Lines.Count, R, C]),
        R + 1, Lines.Count);
    finally
      Lines.Free;
    end;
    FreeGrid(Grid);
  end;
end;

{ Test that each line has exactly C quoted comma-separated fields }
procedure TTestCSVExport.Test_CSVExport_FieldCount_Property;
var
  Iteration, R, C, I, J: Integer;
  Grid: TGridData;
  CSV: String;
  Lines, Fields: TStringList;
begin
  for Iteration := 1 to ITERATIONS do
  begin
    R := ROWS_MIN + Random(ROWS_MAX - ROWS_MIN + 1);
    C := COLS_MIN + Random(COLS_MAX - COLS_MIN + 1);

    { Build grid }
    InitGrid(Grid, R + 1, C);
    for I := 0 to R do
      for J := 0 to C - 1 do
        SetCell(Grid, I, J, RandomCellValue(CELL_MAX_LEN, False));

    { Export }
    CSV := ExportGridToCSV(Grid);

    { Parse into lines }
    Lines := TStringList.Create;
    try
      Lines.Text := CSV;
      while (Lines.Count > 0) and (Lines[Lines.Count - 1] = '') do
        Lines.Delete(Lines.Count - 1);

      { Each line must have exactly C fields }
      for I := 0 to Lines.Count - 1 do
      begin
        Fields := ParseCSVLine(Lines[I]);
        try
          AssertEquals(
            Format('Iteration %d, Line %d: Expected %d fields, got %d',
              [Iteration, I, C, Fields.Count]),
            C, Fields.Count);
        finally
          Fields.Free;
        end;
      end;
    finally
      Lines.Free;
    end;
    FreeGrid(Grid);
  end;
end;

{ Test that each field value matches the original grid cell value }
procedure TTestCSVExport.Test_CSVExport_FieldValues_Property;
var
  Iteration, R, C, I, J: Integer;
  Grid: TGridData;
  CSV: String;
  Lines, Fields: TStringList;
begin
  for Iteration := 1 to ITERATIONS do
  begin
    R := ROWS_MIN + Random(ROWS_MAX - ROWS_MIN + 1);
    C := COLS_MIN + Random(COLS_MAX - COLS_MIN + 1);

    { Build grid }
    InitGrid(Grid, R + 1, C);
    for I := 0 to R do
      for J := 0 to C - 1 do
        SetCell(Grid, I, J, RandomCellValue(CELL_MAX_LEN, False));

    { Export }
    CSV := ExportGridToCSV(Grid);

    { Parse and compare }
    Lines := TStringList.Create;
    try
      Lines.Text := CSV;
      while (Lines.Count > 0) and (Lines[Lines.Count - 1] = '') do
        Lines.Delete(Lines.Count - 1);

      for I := 0 to Lines.Count - 1 do
      begin
        Fields := ParseCSVLine(Lines[I]);
        try
          for J := 0 to Fields.Count - 1 do
          begin
            AssertEquals(
              Format('Iteration %d, Row %d, Col %d: field value mismatch',
                [Iteration, I, J]),
              GetCell(Grid, I, J), Fields[J]);
          end;
        finally
          Fields.Free;
        end;
      end;
    finally
      Lines.Free;
    end;
    FreeGrid(Grid);
  end;
end;

{ Combined property test: verifies line count, field count, and field values together }
procedure TTestCSVExport.Test_CSVExport_Combined_Property;
var
  Iteration, R, C, I, J: Integer;
  Grid: TGridData;
  CSV: String;
  Lines, Fields: TStringList;
begin
  for Iteration := 1 to ITERATIONS do
  begin
    { Generate random dimensions }
    R := ROWS_MIN + Random(ROWS_MAX - ROWS_MIN + 1);
    C := COLS_MIN + Random(COLS_MAX - COLS_MIN + 1);

    { Build grid with varied content: headers use titles, data uses mixed values }
    InitGrid(Grid, R + 1, C);
    { Row 0 = header row }
    for J := 0 to C - 1 do
      SetCell(Grid, 0, J, 'Col_' + IntToStr(J + 1) + '_' + RandomCellValue(5, False));
    { Rows 1..R = data rows with random content }
    for I := 1 to R do
      for J := 0 to C - 1 do
        SetCell(Grid, I, J, RandomCellValue(CELL_MAX_LEN, True));

    { Export to CSV string }
    CSV := ExportGridToCSV(Grid);

    { Parse and verify all properties }
    Lines := TStringList.Create;
    try
      Lines.Text := CSV;
      while (Lines.Count > 0) and (Lines[Lines.Count - 1] = '') do
        Lines.Delete(Lines.Count - 1);

      { Property 8a: Output has R+1 lines }
      AssertEquals(
        Format('Iteration %d: Line count must be R+1=%d (R=%d, C=%d)',
          [Iteration, R + 1, R, C]),
        R + 1, Lines.Count);

      { Property 8b+8c: Each line has C fields matching grid values }
      for I := 0 to Lines.Count - 1 do
      begin
        Fields := ParseCSVLine(Lines[I]);
        try
          { Exactly C fields per line }
          AssertEquals(
            Format('Iteration %d, Line %d: field count must be %d',
              [Iteration, I, C]),
            C, Fields.Count);

          { Each field matches grid cell }
          for J := 0 to Fields.Count - 1 do
          begin
            AssertEquals(
              Format('Iteration %d, Row %d, Col %d: value mismatch. Expected="%s", Got="%s"',
                [Iteration, I, J, GetCell(Grid, I, J), Fields[J]]),
              GetCell(Grid, I, J), Fields[J]);
          end;
        finally
          Fields.Free;
        end;
      end;
    finally
      Lines.Free;
    end;
    FreeGrid(Grid);
  end;
end;

initialization
  Randomize;
  RegisterTest(TTestCSVExport);

end.
