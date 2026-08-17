unit UOut;
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UTransaction, UItem;

  type
    TOut = class(TTransaction)
    private // self access only
        function calculateNewBalance(item:TItem):TItem;

    public // access by anything
        procedure calculateNewBalance();
        function getSum():Real;Override;
    end;

implementation

    function TOut.calculateNewBalance(item:TItem):TItem;
    begin
        item.getProduct().getBalance().setBalance(item.getProduct().getBalance().getBalance()-(item.getProduct().getBalance().getCost()*item.getStock()));
        item.getProduct().getBalance().setStock(item.getProduct().getBalance().getStock()-item.getStock());
        calculateNewBalance := item;
    end;

    procedure TOut.calculateNewBalance();
    var
       i:Integer;
    begin
         for i := 0 to Self.getItemList().Count-1 do
         begin
            Self.getItemList()[i] := Self.calculateNewBalance(TItem(getItemList()[i]));
         end;
    end;

    function TOut.getSum():Real;
    var
       i:Integer;
       sum:Real;
       item : TItem;
    begin
       sum := 0;
       for i := 0 to Self.getItemList.Count-1 do
       begin
         item := TItem(Self.getItemList[i]);
         sum := sum + (item.getStock()*item.getPrice());
       end;
       getSum := sum;
    end;

end.

