unit USale;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, UOut, UCustomer, UOperationType;

type
TSale = class(TOut)
private // self access only


public // access by anything
constructor create();
procedure setCustomer(newCustomer:TCustomer);
function getCustomer():TCustomer;
end;

implementation

constructor TSale.create();
begin
Self.setOperationType(TOperationType.Create(2,'Sale'));
end;

procedure TSale.setCustomer(newCustomer:TCustomer);
begin
inherited setPerson(newCustomer);
end;

function TSale.getCustomer():TCustomer;
begin
getCustomer := TCustomer(inherited getPerson());
end;
end.
