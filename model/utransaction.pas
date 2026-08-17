{ Apothêca

  Copyright (C) 2010 Ice icebishop@gmail.com

  This source is free software; you can redistribute it and/or modify it under
  the terms of the GNU General Public License as published by the Free
  Software Foundation; either version 2 of the License, or (at your option)
  any later version.

  This code is distributed in the hope that it will be useful, but WITHOUT ANY
  WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
  FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
  details.

  A copy of the GNU General Public License is available on the World Wide Web
  at <http://www.gnu.org/copyleft/gpl.html>. You can also obtain it by writing
  to the Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston,
  MA 02111-1307, USA.
}

unit UTransaction;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UPerson, UItem, UOperationType;

  type
    TTransaction = class(TObject)
    private // self access only
        id : Integer;
        date : TDateTime;
        itemList :TList;
        person:TPerson;
        operationType:TOperationType;
        credit : Integer;
    public // access by anything

        procedure setId(newId:Integer);
        procedure setDate(newDate:TDateTime);
        procedure setPerson(newPerson:TPerson);
        procedure setOperationType(newOperationType:TOperationType);
        procedure setItemList(newItemList:TList);
        procedure setCredit(newCredit:Integer);

        procedure init();

        function getId():Integer;
        function getDate():TDateTime;
        function getPerson():TPerson;
        function getOperationType():TOperationType;
        function getItemList():TList;
        function getCredit():Integer;

        function getSum():Real;Virtual;



    end;

implementation

    procedure TTransaction.init();
    begin
       date := Now;
       credit := 0;
       if itemList <> nil then
       begin
          itemList.Clear;
          itemlist.Free;
       end;
       if person <> nil then
          person.free;
       if operationType <> nil then
          operationType.free;
    end;

    procedure TTransaction.setId(newId:Integer);
    begin
        Self.id:= newId;
    end;

    procedure TTransaction.setDate(newDate:TDateTime);
    begin
         Self.date:=  newDate;
    end;

    procedure TTransaction.setPerson(newPerson:TPerson);
    begin
         Self.person:=  newPerson;
    end;

    procedure TTransaction.setOperationType(newOperationType:TOperationType);
    begin
         Self.operationType:= newOperationType;
    end;

    procedure TTransaction.setItemList(newItemList:TList);
    begin
         Self.itemList:= newItemList;
    end;

    function TTransaction.getId():Integer;
    begin
         getId := Self.id;
    end;

    function TTransaction.getDate():TDateTime;
    begin
         getDate := Self.date;
    end;

    function TTransaction.getPerson():TPerson;
    begin
         getPerson := Self.person;
    end;

    function TTransaction.getOperationType():TOperationType;
    begin
         getOperationType := Self.operationType;
    end;

    function TTransaction.getItemList():TList;
    begin
         getItemList := Self.itemList;
    end;

    procedure TTransaction.setCredit(newCredit:Integer);
    begin
         Self.credit:= newCredit;
    end;

    function TTransaction.getCredit():Integer;
    begin
         getCredit := Self.credit;
    end;

    function TTransaction.getSum():Real;
    var
       i:Integer;
       sum:Real;
       item : TItem;
    begin
       sum := 0;
       for i := 0 to itemList.Count-1 do
       begin
         item := TItem(itemList[i]);
         sum := sum + (item.getStock()*item.getCost());
       end;

       getSum := sum;
    end;

end.

