unit UProduct;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, UBalance;

type
TProduct = class(TObject)
private // self access only
id : Integer;
name : String;
minstock :Integer;
maxstock :Integer;
balance : TBalance;


public // access by anything
constructor Create;
procedure setId(newId:Integer);
procedure setName(newName:String);
procedure setMinstock(newMinstock:Integer);
procedure setMaxstock(newMaxstock:Integer);
procedure setBalance(newBalance:TBalance);


function getId():Integer;
function getName():String;
function getMinStock():Integer;
function getMaxStock():Integer;
function getBalance():TBalance;




end;

implementation

constructor TProduct.Create;
begin
inherited;
balance := TBalance.Create;
end;

procedure TProduct.setId(newId:Integer);
begin
Self.id:= newId;
end;

procedure TProduct.setName(newName:String);
begin
Self.name:= newName;
end;

procedure TProduct.setMinstock(newMinstock:Integer);
begin
Self.minstock:= newMinstock;
end;

procedure TProduct.setMaxstock(newMaxstock:Integer);
begin
Self.maxstock:= newMaxstock;
end;

function TProduct.getId():Integer;
begin
getId := Self.id;
end;

function TProduct.getName():String;
begin
getName := Self.name;
end;

function TProduct.getMinStock():Integer;
begin
getMinStock := Self.minstock;
end;

function TProduct.getMaxStock():Integer;
begin
getMaxStock := Self.maxstock;
end;

procedure TProduct.setBalance(newBalance:TBalance);
begin
Self.balance := newBalance;
end;

function TProduct.getBalance():TBalance;
begin
     getBalance := balance;
end;

end.
