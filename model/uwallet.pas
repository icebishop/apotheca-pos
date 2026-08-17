unit UWallet;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UCustomer, UOut, UPay;

  type
  TWallet = class(TObject)
  private
    // Data/method defs local to this Unit
    customer : TCustomer;
    listSale: TList;
    listPay : TList;
    totalPay : real;
    totalSale : real;
  protected
    // Data/method defs local to this class + descendants
  public
    procedure setCustomer(newCustomer:TCustomer);
    procedure setListSale(newListSale:TList);
    procedure setListPay(newListPay:TList);

    function getCustomer():TCustomer;
    function getListSale():TList;
    function getListPay():TList;
    function getTotalPay():real;
    function getTotalSale():real;

    procedure calculate();
  published
    // Externally interrogatable public definitions
end;

implementation

    procedure TWallet.setCustomer(newCustomer:TCustomer);
    begin
        Self.customer := newCustomer;
    end;

    procedure TWallet.setListSale(newListSale:TList);
    begin
        Self.listSale := newListSale;
    end;

    procedure TWallet.setListPay(newListPay:TList);
    begin
         Self.listPay := newListPay;
    end;

    function TWallet.getCustomer():TCustomer;
    begin
         getCustomer := customer;
    end;

    function TWallet.getListSale():TList;
    begin
         getListSale := listSale;
    end;

    function TWallet.getListPay():TList;
    begin
         getListPay := listPay;
    end;

    function TWallet.getTotalPay():real;
    begin
         getTotalPay := totalPay;
    end;

    function TWallet.getTotalSale():real;
    begin
         getTotalSale := totalSale;
    end;

    procedure TWallet.calculate();
    var
       i:Integer;
       _out : TOut;
       pay : TPay;
    begin
       if  listSale.Count > 0 then
       for i := 0 to listSale.Count-1 do
       begin
          _out := TOut(listSale[i]);
          totalSale:= totalSale + _out.getSum() ;
       end;

       for i := 0 to listPay.Count-1 do
       begin
          pay := TPay(listPay[i]);
          totalPay:= totalPay + pay.getValue() ;
       end;

    end;

end.

