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

unit UPerson;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, UResourceString;

type
TPerson = class(TObject)
private // self access only
id : Integer;
name : String;
telephone:String;
address:String;

public // access by anything

procedure setId(newId:Integer);
procedure setName(newName:String);
procedure setTelephone(newTelephone:String);
procedure setAddress(newAddress:String);

function getId():Integer;
function getName():String;
function getTelephone():String;
function getAddress():String;
function getPersonType():String;
end;

implementation

procedure TPerson.setId(newId:Integer);
begin
Self.id:=newId;
end;

procedure TPerson.setName(newName:String);
begin
Self.name:=newName;
end;

procedure TPerson.setTelephone(newTelephone:String);
begin
Self.telephone:=newTelephone;
end;

procedure TPerson.setAddress(newAddress:String);
begin
Self.address:=newAddress;
end;

function TPerson.getId():Integer;
begin
getId:=Self.id;
end;

function TPerson.getName():String;
begin
getName:=Self.name;
end;

function TPerson.getTelephone():String;
begin
getTelephone:=Self.telephone;
end;

function TPerson.getAddress():String;
begin
getAddress:=Self.address;
end;

function TPerson.getPersonType():String;
var
   typePerson : String;
begin
     if self.ClassName = 'TCustomer' then
        typePerson := RS_MSGCUSTOMER
     else if self.ClassName = 'TSupplier' then
         typePerson := RS_MSGSUPPLIER;

     getPersonType := typePerson;
end;

end.
