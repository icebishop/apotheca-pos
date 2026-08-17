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

unit UTransactionValidator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UValidator, UTransaction, UItemValidator, UItem, UResourceString;

  type
TTransactionValidator = class(TValidator)
private // self access only
 transaction: TTransaction;


 function validateItems():boolean;
 function hasPerson():boolean;
 function hasDate():boolean;
 function hasItems():boolean;


public // access by anything
 function validate():boolean;override;
 procedure setTransaction(newTransaction:TTransaction);
end;

implementation

 procedure TTransactionValidator.setTransaction(newTransaction:TTransaction);
 begin
      transaction := newTransaction;
 end;

 function TTransactionValidator.validate():boolean;
 var
    ret:boolean;
 begin
      ret := true;
      if ret then
         ret := hasPerson();
      if ret then
         ret := hasDate();
      if ret then
         ret := hasItems();
      if ret then
         ret := validateItems();
      validate := ret;
 end;

 function TTransactionValidator.validateItems():boolean;
 var
    control,i : Integer;
    itemValidator : TItemValidator;
 begin
      itemValidator := TItemValidator.Create;
      control := 0;
     for  i := 0 to transaction.getItemList().Count-1 do
     begin
          itemValidator.setItem(TItem(transaction.getItemList()[i]));
          itemValidator.setOperationType(transaction.getOperationType());
          if not itemValidator.validate() then
          begin
             if control = 0 then
                setMessage(Format(RS_MSGVALLISTITEMS, [Char(13)]));
             setMessage(Format(RS_MSGVALNUMITEM, [getMessage(), IntToStr(i+1)+
               Char(13)]));
             setMessage(getMessage()+itemValidator.getMessage());
             Inc(control);
          end;
     end;

     if control > 0 then
        validateItems:= false
     else
         validateItems := true;

     itemValidator.Free;
 end;

 function TTransactionValidator.hasPerson():boolean;
 begin
      if transaction.getPerson()=nil then
      begin
           setMessage(Format(RS_MSGVALPERSON, [getMessage()]));
           hasPerson:= false;
      end
      else
          hasPerson:= true;

 end;

 function TTransactionValidator.hasDate():boolean;
 begin
      if transaction.getDate() = 0 then
      begin
         setMessage(Format(RS_MSGVALDATE, [getMessage()+char(13)]));
         hasDate := false;
      end
      else
          hasDate := true;
 end;

 function TTransactionValidator.hasItems():boolean;
 begin
      if (transaction.getItemList() <> nil) and (transaction.getItemList().Count > 0) then
           hasItems := true
      else
      begin
           setMessage(Format(RS_MSGVALITEMS, [getMessage(), char(13)]));
           hasItems := true;
      end;
 end;

end.

