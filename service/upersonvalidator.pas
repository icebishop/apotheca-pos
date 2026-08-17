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

unit UPersonValidator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UPerson, UValidator, UResourceString;

  type
    TPersonValidator = class(TValidator)
private // self access only

person:TPerson;



public // access by anything

function hasName():boolean;
function hasTelephone():boolean;
function hasAddress():boolean;
function validate():boolean;override;
procedure setPerson(newPerson:TPerson);


end;

implementation

function TPersonValidator.hasName():boolean;
begin
     if person.getName() <> '' then
        hasName:=true
     else
     begin
        setMessage(Format(RS_MSGVALPERNAME, [getMessage(),person.getPersonType(), char(13)]));
        hasName := false;
     end;
end;

function TPersonValidator.hasTelephone():boolean;
begin
     if person.getTelephone() <> '' then
        hasTelephone:=true
     else
     begin
        setMessage(Format(RS_MSGVALPERTEL, [getMessage(), person.getPersonType() ,char(13)]));
        hasTelephone := false;
     end;
end;

function TPersonValidator.hasAddress():boolean;
begin
     if person.getAddress()  <> '' then
        hasAddress:=true
     else
     begin
        setMessage(Format(RS_MSGVALPERADDRESS, [getMessage(),person.getPersonType(), char(13)]));
        hasAddress := false;
     end;
end;

function TPersonValidator.validate():boolean;
var
   ret:boolean;
begin
   ret := true;
   if not((ret=true)and(hasName()=true)) then
     ret := false;
   if not((ret=true)and(hasTelephone()=true)) then
     ret := false;
   if not((ret=true)and(hasAddress()=true)) then
     ret := false;
   validate := ret;
end;

procedure TPersonValidator.setPerson(newPerson:TPerson);
begin
     person := newPerson;
end;

end.

