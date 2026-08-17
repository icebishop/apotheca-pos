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

unit UPayValidator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,UValidator,UResourceString, UPay;

  type
    TPayValidator = class(TValidator)
private // self access only

pay:TPay;

public // access by anything

function hasCustomer():boolean;
function hasDate():boolean;
function hasValue():boolean;
function validate():boolean;override;
procedure setPay(newPay:TPay);

end;
implementation

function TPayValidator.hasCustomer():boolean;
begin
     if pay.getPerson()<>nil then
        hasCustomer := true
     else
     begin
          setMessage(Format(RS_MSGVALPAYCUST, [getMessage(), char(13)]));
          hasCustomer := false;
     end;
end;

function TPayValidator.hasValue():boolean;
begin
     if pay.getValue() > 0 then
        hasValue := true
     else
     begin
          setMessage(Format(RS_MSGVALPAYVALUE, [getMessage(), char(13)]));
          hasValue := false;
     end;
end;

function TPayValidator.hasDate():boolean;
begin
     if pay.getDate() > 0 then
        hasDate := true
     else
     begin
          setMessage(Format(RS_MSGVALPAYDATE, [getMessage(), char(13)]));
          hasDate := false;
     end;
end;

function TPayValidator.validate():boolean;
var
   ret : boolean;
begin
   ret := true;
   if not ((ret=true)and(hasCustomer()=true)) then
      ret := false;
   if not ((ret=true)and(hasValue()=true)) then
      ret := false;

   validate := ret;
end;



procedure TPayValidator.setPay(newPay:TPay);
begin
     pay := newPay;
end;

end.

