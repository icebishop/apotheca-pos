unit UDataOut;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, UDataTransaction;

type
TDataOut  = class(TDataTransaction)

public // access by anything

       { function new(itemList:TList):Boolean;
        function edit(product:TProduct):Boolean;
        function delete(balance:TBalance):Boolean;
        function get(productId:Integer):TBalance;}

end;

implementation



end.
