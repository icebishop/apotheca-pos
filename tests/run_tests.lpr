program run_tests;

{$mode objfpc}{$H+}

uses
  Classes, SysUtils, fpcunit, testregistry, consoletestrunner,
  { Test units }
  test_cart_removal,
  test_purchase_balance;

var
  Application: TTestRunner;

begin
  Application := TTestRunner.Create(nil);
  Application.Initialize;
  Application.Title := 'Apotheca Property Tests';
  Application.Run;
  Application.Free;
end.
