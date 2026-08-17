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

unit UFSupplier;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
StdCtrls, Buttons,USupplier, UDataSupplier, UDataModule, LCLType, sqldb,
UResourceString, UPersonValidator;

type

  { TFormSupplier }

TFormSupplier = class(TForm)
BitBtnOk: TBitBtn;
BitBtnCancel: TBitBtn;
EditName: TEdit;
EditTelephone: TEdit;
EditAddress: TEdit;
LabelName: TLabel;
LabelTelephone: TLabel;
LabelAddress: TLabel;
procedure BitBtnOkClick(Sender: TObject);
procedure BitBtnCancelClick(Sender: TObject);
procedure EditNameExit(Sender: TObject);
procedure EditTelephoneExit(Sender: TObject);
procedure EditAddressExit(Sender: TObject);
procedure FormCreate(Sender: TObject);
procedure FormShow(Sender: TObject);
private
    { private declarations }
supplier:TSupplier;
supplierValidator : TPersonValidator;
flagOperacion:Integer;
flagAction:Integer;
public
    { public declarations }
function getSupplier():TSupplier;
procedure setSupplier(newSupplier:TSupplier);
function getFlagAction():Integer;
procedure setFlagOperation(flag:Integer);
end; 

var
FormSupplier: TFormSupplier;

implementation

procedure TFormSupplier.BitBtnOkClick(Sender: TObject);
var
dataSupplier : TDataSupplier;
begin

     supplier.setName(EditName.Text);
     supplier.setTelephone(EditTelephone.Text);
     supplier.setAddress(EditAddress.Text);

     supplierValidator.setMessage('');

     if supplierValidator.validate() then
     begin
     DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
     datasupplier := TDataSupplier.Create(DataModule1.SQLite3Connection1);
     datasupplier.getTransaction().StartTransaction;

     if flagOperacion  = 1 then
     begin
          if datasupplier.new(supplier) > 0 then
          begin
               dataSupplier.getTransaction().Commit;
               Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE),MB_OK )
          end
          else
              begin Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND)
          end;
     end
     else
     begin
          if datasupplier.edit(supplier) then
          begin
               dataSupplier.getTransaction().Commit;
               Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE),MB_OK )
          end
          else
               begin Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND)
          end;
     end;
     dataSupplier.free;
     Close;

     end
     else
         Application.MessageBox(PChar(supplierValidator.getMessage()), PChar(RS_Error), MB_ICONWARNING);
end;

procedure TFormSupplier.BitBtnCancelClick(Sender: TObject);
begin
     Close;
end;

procedure TFormSupplier.EditNameExit(Sender: TObject);
begin
     supplier.setName(EditName.Text);
     supplierValidator.setMessage('');
     if not supplierValidator.hasName() then
        Application.MessageBox( PChar(supplierValidator.getMessage()),PChar(RS_MSGWARNING),
                                MB_ICONWARNING);
end;

procedure TFormSupplier.EditTelephoneExit(Sender: TObject);
begin
     supplier.setTelephone(EditTelephone.Text);
     supplierValidator.setMessage('');
     if not supplierValidator.hasTelephone() then
        Application.MessageBox( PChar(supplierValidator.getMessage()),PChar(RS_MSGWARNING),
                                MB_ICONWARNING);
end;

procedure TFormSupplier.EditAddressExit(Sender: TObject);
begin
     supplier.setAddress(EditAddress.Text);
     supplierValidator.setMessage('');
     if not supplierValidator.hasAddress() then
        Application.MessageBox( PChar(supplierValidator.getMessage()),PChar(RS_MSGWARNING),
                                MB_ICONWARNING);
end;

procedure TFormSupplier.FormCreate(Sender: TObject);
begin
     if supplier = nil then
     begin
          supplier := TSupplier.Create;
          supplierValidator := TPersonValidator.Create;
          supplierValidator.setPerson(supplier);
     end;
end;

procedure TFormSupplier.FormShow(Sender: TObject);
begin
     if supplier <> nil then
     begin
          EditName.Text:= supplier.getName();
          EditTelephone.Text:= supplier.getTelephone();
          EditAddress.Text:= supplier.getAddress();
     end;
end;

function TFormSupplier.getSupplier():TSupplier;
begin
     getSupplier := Self.supplier;
end;

procedure TFormSupplier.setSupplier(newSupplier:TSupplier);
begin
     Self.supplier := newSupplier;
end;


procedure TFormSupplier.setFlagOperation(flag:Integer);
begin
     Self.flagOperacion:= flag;
end;

function TFormSupplier.getFlagAction():Integer;
begin
     getFlagAction := flagAction;
end;

initialization
  {$I ufsupplier.lrs}

end.
