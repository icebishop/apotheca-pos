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

unit UItemValidator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UValidator, UItem, UResourceString, UOperationType;

type
TItemValidator = class(TValidator)
private // self access only
 item: TItem;
 operationType:TOperationType;

 function hasCost():boolean;
 function hasPrice():boolean;
 function hasStock():boolean;



public // access by anything
 function validate():boolean;override;
 procedure setItem(newItem:TItem);
 procedure setOperationType(newOperationType:TOperationType);
 function hasProduct():boolean;
end;

implementation

 function TItemValidator.hasProduct():boolean;
 begin
     if (item.getProduct()<>nil) and (item.getProduct().getId()>0) then
     begin
        hasProduct := true;
        setMessage(Format(RS_ITEMVALIDATORPRODUCT, [getMessage(),
          item.getProduct().getName()]));
     end
     else
     begin
         hasProduct := false;
         setMessage(Format(RS_ITEMVALIDATORPRODUCTSELECT, [getMessage()]));
     end;
 end;

 function TItemValidator.hasCost():boolean;
 begin
     if item.getCost() > 0 then
        hasCost := true
     else
     begin
         hasCost := false;
         setMessage(Format(RS_ITEMVALIDATORPRODUCTCOST, [getMessage()]));
     end;
 end;

 function TItemValidator.hasPrice():boolean;
 begin
      if item.getPrice() > 0 then
        hasPrice := true
     else
     begin
         hasPrice := false;
         setMessage(Format(RS_ITEMVALIDATORPRODUCTPRICE, [getMessage()]));
     end;
 end;

 function TItemValidator.hasStock():boolean;
 begin
      if item.getStock() > 0 then
        hasStock := true
     else
     begin
         hasStock := false;
         setMessage(Format(RS_ITEMVALIDATORPRODUCTSTOCK, [getMessage()]));
     end;
 end;

 function TItemValidator.validate():boolean;
 var
    ret : boolean;
 begin
    setMessage('');
    ret:= hasProduct();
    if ret then
       ret:=hasStock();
    if ret then
       if operationType.getTyp() = 'in' then
          ret := hasCost()
       else  if operationType.getTyp() = 'out' then
          ret := hasPrice();
    setMessage(getMessage()+Char(13));
    validate := ret;
 end;

 procedure TItemValidator.setItem(newItem:TItem);
 begin
     item := newItem;
 end;

 procedure TItemValidator.setOperationType(newOperationType:TOperationType);
 begin
     operationType:=newOperationType;
 end;
end.

