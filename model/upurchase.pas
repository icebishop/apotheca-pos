unit UPurchase;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, UIn, USupplier, UOperationType;

type
TPurchase = class(TIn)
private // self access only


public // access by anything
constructor create();
procedure setSupplier(newSupplier:TSupplier);
function getSupplier():TSupplier;
end;

implementation

constructor TPurchase.create();
begin
Self.setOperationType(TOperationType.Create(1,'Purchase'));
end;

procedure TPurchase.setSupplier(newSupplier:TSupplier);
begin
inherited setPerson(newSupplier);
end;

function TPurchase.getSupplier():TSupplier;
begin
getSupplier := TSupplier(inherited getPerson());
end;
end.
