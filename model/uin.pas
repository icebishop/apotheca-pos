unit UIn;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UTransaction, UItem;

  type
    TIn = class(TTransaction)
    private // self access only
        function calculateNewBalance(item:TItem):TItem;
    public // access by anything
        procedure calculateNewBalance();
    end;

implementation

    function TIn.calculateNewBalance(item:TItem):TItem;
    begin
        item.getProduct().getBalance().setBalance(item.getProduct().getBalance().getBalance()+(item.getCost()*item.getStock()));
        item.getProduct().getBalance().setPrice(item.getPrice());
        item.getProduct().getBalance().setStock(item.getProduct().getBalance().getStock()+item.getStock());
        item.getProduct().getBalance().setCost(item.getProduct().getBalance().getBalance()/item.getProduct().getBalance().getStock());
        calculateNewBalance := item;
    end;

    procedure TIn.calculateNewBalance();
    var
       i:Integer;
    begin
         for i := 0 to Self.getItemList().Count-1 do
         begin
            Self.getItemList()[i] := Self.calculateNewBalance(TItem(getItemList()[i]));
         end;
    end;

end.

