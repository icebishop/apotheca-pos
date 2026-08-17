unit UBalance;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

  type
    TBalance = class(TObject)
    private // self access only
        id : Integer;
        stock :Integer;
        price  : Real;
        cost  : Real;
        balance : Real;


    public // access by anything

        procedure setId(newId:Integer);
        procedure setStock(newStock:Integer);
        procedure setPrice(newPrice:Real);
        procedure setCost(newCost:Real);
        procedure setBalance(newBalance:Real);

        function getId():Integer;
        function getStock():Integer;
        function getPrice():Real;
        function getCost():Real;
        function getBalance():Real;
    end;

implementation


        procedure TBalance.setId(newId:Integer);
        begin
             Self.id := newId;
        end;

        procedure TBalance.setStock(newStock:Integer);
        begin
             Self.stock := newStock;
        end;

        procedure TBalance.setPrice(newPrice:Real);
        begin
             Self.price := newPrice;
        end;

        procedure TBalance.setCost(newCost:Real);
        begin
             Self.cost := newCost;
        end;

        procedure TBalance.setBalance(newBalance:Real);
        begin
            Self.balance := newBalance;
        end;

        function TBalance.getId():Integer;
        begin
             getId := Self.id;
        end;

        function TBalance.getStock():Integer;
        begin
             getStock := Self.stock;
        end;

        function TBalance.getPrice():Real;
        begin
             getPrice := Self.price;
        end;

        function TBalance.getCost():Real;
        begin
             getCost := Self.cost;
        end;

        function TBalance.getBalance():Real;
        begin
             getBalance := Self.balance;
        end;

end.

