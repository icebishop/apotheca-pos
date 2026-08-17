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

unit UFFindCustomer;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
StdCtrls, Grids, Buttons, UCustomer, UDataCustomer, UDataModule , UFCustomer,
sqldb, UResourceString;

type

  { TFormFindCustomer }

TFormFindCustomer = class(TForm)
BitBtnNew: TBitBtn;
BitBtnCancel: TBitBtn;
BitBtnOk: TBitBtn;
EditFind: TEdit;
StringGridCustomer: TStringGrid;
procedure BitBtnNewClick(Sender: TObject);
procedure BitBtnCancelClick(Sender: TObject);
procedure BitBtnOkClick(Sender: TObject);
procedure EditFindKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
procedure FormCreate(Sender: TObject);
procedure StringGridCustomerClick(Sender: TObject);
private
    { private declarations }
listcustomer:TList;
customer : TCustomer;
flagAction:Integer;
procedure loadDataGrid();
procedure loadData();
public
    { public declarations }
function getCustomer():TCustomer;
function getFlagAction():Integer;
end; 

var
FormFindCustomer: TFormFindCustomer;

implementation

procedure TFormFindCustomer.FormCreate(Sender: TObject);
begin

StringGridCustomer.Cells[0, 0] := RS_LCUSTOMERS;
BitBtnCancel.Caption:= RS_CANCEL;
BitBtnOk.Caption := RS_OK;
BitBtnNew.Caption:= RS_NEW;
Self.Caption:= RS_LFINDCUSTOMERS;

loadData();
loadDataGrid();
flagAction:= 0;
end;

procedure TFormFindCustomer.StringGridCustomerClick(Sender: TObject);
begin
customer := TCustomer(listCustomer[StringGridCustomer.Row-1]);
Close;
end;

procedure TFormFindCustomer.BitBtnNewClick(Sender: TObject);
var
formCustomer : TFormCustomer;
begin
formCustomer := TFormCustomer.Create(Self);
try
formCustomer.setFlagOperation(1);
formCustomer.ShowModal;
loadData();
loadDataGrid();
StringGridCustomer.Row:= StringGridCustomer.RowCount-1;
finally
formCustomer.Free;
end;
end;

procedure TFormFindCustomer.BitBtnCancelClick(Sender: TObject);
begin
flagAction := 0;
Close;
end;

procedure TFormFindCustomer.BitBtnOkClick(Sender: TObject);
begin
StringGridCustomerClick(Sender);
flagAction:= 1;
Close;
end;

procedure TFormFindCustomer.EditFindKeyUp(Sender: TObject; var Key: Word;
Shift: TShiftState);
begin
loadData();
loadDataGrid();
end;

procedure TFormFindCustomer.loadDataGrid();
var
c:Integer;
begin
StringGridCustomer.Clean;
StringGridCustomer.RowCount:= listcustomer.Count+1;
StringGridCustomer.Cells[0,0]:= 'Clientes';
For c := 0 to listcustomer.Count -1 do
begin
customer := TCustomer (listcustomer[c]);
StringGridCustomer.Cells[0,c+1]:= customer.getName();
end;
end;

procedure TFormFindCustomer.loadData();
var
dataCustomer : TDataCustomer;
begin

DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
dataCustomer := TDataCustomer.Create(DataModule1.SQLite3Connection1);
listcustomer := dataCustomer.find('%'+EditFind.Text+'%');
dataCustomer.free;
end;

function TFormFindCustomer.getCustomer():TCustomer;
begin
getCustomer := Self.customer;
end;


function TFormFindCustomer.getFlagAction():Integer;
begin
getFlagAction := flagAction;
end;

initialization
  {$I uffindcustomer.lrs}

end.
