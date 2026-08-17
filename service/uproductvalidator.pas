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

unit UProductValidator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,UValidator,UProduct, UResourceString;

type
    TProductValidator = class(TValidator)
private // self access only

product:TProduct;

public // access by anything

function hasStock(number:Integer):boolean;
function hasName():boolean;
function hasMinStock():boolean;
function hasMaxStock():boolean;
function validate():boolean;override;
procedure setProduct(newProduct:TProduct);


end;

implementation

function TProductValidator.hasStock(number:Integer):boolean;
begin
     if product.getBalance().getStock()-number >= 0 then
        hasStock := true
     else
     begin
        setMessage(Format(RS_MSGVALPRODSTOCK, [getMessage(), IntToStr(
          product.getBalance().getStock()), product.getName()+char(13)]));
          hasStock := false;
     end;
end;

function TProductValidator.validate():boolean;
var
 ret:boolean;

begin
     ret:= true;
     if not((ret = true) and (hasName() = true)) then
       ret := false;
     if not((ret = true) and (hasMinStock() = true)) then
       ret := false;
     if not((ret = true) and (hasMaxStock() = true)) then
       ret := false;

     validate := ret;
end;

procedure TProductValidator.setProduct(newProduct:TProduct);
begin
     product := newProduct;
end;

function TProductValidator.hasName():boolean;
begin
     if (product.getName()<>'') then
        hasName := true
     else
     begin
          setMessage(Format(RS_MSGVALPRODNAME, [getMessage()+char(13)]));
          hasName := false;
     end;
end;

function TProductValidator.hasMinStock():boolean;
begin
     if product.getMinStock() > 0 then
        hasMinStock := true
     else
     begin
          setMessage(Format(RS_MSGVALPRODMINSTOCK, [getMessage()+char(13)]));
          hasMinStock := false;
     end;
end;

function TProductValidator.hasMaxStock():boolean;
begin
     if product.getMaxStock() > product.getMinStock() then
        hasMaxStock := true
     else
     begin
          setMessage(Format(RS_MSGVALPRODMAXSTOCK, [getMessage()+char(13)]));
          hasMaxStock := false;
     end;
end;

end.

