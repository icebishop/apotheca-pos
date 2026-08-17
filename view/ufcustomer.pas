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

unit UFCustomer;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
StdCtrls, Buttons, UCustomer, UDataCustomer, UDataModule, LCLType,
UResourceString, DefaultTranslator, SqlDb, UPersonValidator;

type

  { TFormCustomer }

TFormCustomer = class(TForm)
BitBtnOk: TBitBtn;
BitBtnCancel: TBitBtn;
EditName: TEdit;
EditTelephone: TEdit;
EditAddress: TEdit;
LabelName: TLabel;
LabelTelephone: TLabel;
LabelAddress: TLabel;
procedure BitBtnCancelExit(Sender: TObject);
procedure BitBtnOkClick(Sender: TObject);
procedure BitBtnCancelClick(Sender: TObject);
procedure EditAddressExit(Sender: TObject);
procedure EditNameExit(Sender: TObject);
procedure EditTelephoneExit(Sender: TObject);
procedure FormCreate(Sender: TObject);
procedure FormShow(Sender: TObject);
private
    { private declarations }
customer:TCustomer;
customerValidator:TPersonValidator;
flagOperacion:Integer;
flagAction:Integer;
public
    { public declarations }
function getCustomer():TCustomer;
procedure setCustomer(newCustomer:TCustomer);
function getFlagAction():Integer;
procedure setFlagOperation(flag:Integer);
end; 

var
FormCustomer: TFormCustomer;

implementation

{ TFormCustomer }

procedure TFormCustomer.FormShow(Sender: TObject);
begin
     if customer <> nil then
     begin
          EditName.Text:= customer.getName();
          EditTelephone.Text:= customer.getTelephone();
          EditAddress.Text:= customer.getAddress();
     end;
end;

procedure TFormCustomer.BitBtnCancelExit(Sender: TObject);
begin

end;

procedure TFormCustomer.BitBtnOkClick(Sender: TObject);
var
dataCustomer : TDataCustomer;
begin
     customer.setName(EditName.Text);
     customer.setTelephone(EditTelephone.Text);
     customer.setAddress(EditAddress.Text);
     if customerValidator.confirmBox() then
     begin
     if customerValidator.validate() then
     begin
          DataModule1.SQLite3Connection1.Transaction := TSQLTransaction.Create(nil);
          datacustomer := TDataCustomer.Create(DataModule1.SQLite3Connection1);
          datacustomer.getTransaction().StartTransaction;
          if flagOperacion  = 1 then
          begin
               if datacustomer.new(customer) > 0 then
               begin
                    Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE),MB_OK );
                    dataCustomer.getTransaction().Commit;
               end
               else
               begin Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND) end;
          end
          else
              if datacustomer.edit(customer) then
              begin
                   Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE),MB_OK );
                   dataCustomer.getTransaction().Commit;
              end
              else
                  begin Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND) end;
          dataCustomer.free();

          Close;

     end
     else
         Application.MessageBox(PChar(customerValidator.getMessage()), PChar(RS_Error), MB_ICONWARNING);
     end;
end;



procedure TFormCustomer.BitBtnCancelClick(Sender: TObject);
begin
Close
end;

procedure TFormCustomer.EditAddressExit(Sender: TObject);
begin
     customer.setAddress(EditAddress.Text);
     customerValidator.setMessage('');
     if not customerValidator.hasAddress() then
        Application.MessageBox( PChar(customerValidator.getMessage()),PChar(RS_MSGWARNING),
                                MB_ICONWARNING);
end;

procedure TFormCustomer.EditNameExit(Sender: TObject);
begin
     customer.setName(EditName.Text);
     customerValidator.setMessage('');
     if not customerValidator.hasName() then
        Application.MessageBox( PChar(customerValidator.getMessage()),PChar(RS_MSGWARNING), MB_ICONWARNING);
end;

procedure TFormCustomer.EditTelephoneExit(Sender: TObject);
begin
     customer.setTelephone(EditTelephone.Text);
     customerValidator.setMessage('');
     if not customerValidator.hasTelephone() then
        Application.MessageBox( PChar(customerValidator.getMessage()),PChar(RS_MSGWARNING),MB_ICONWARNING);
end;

procedure TFormCustomer.FormCreate(Sender: TObject);
begin
     Self.Caption:= RS_LCUSTOMERS ;
     LabelName.Caption := RS_LNAME;
     LabelTelephone.Caption := RS_LTELEPHONE;
     LabelAddress.Caption := RS_LADDRESS ;
     BitBtnOk.Caption:=RS_OK;
     BitBtnCancel.Caption:=RS_CANCEL;

     if customer = nil then
     begin
          customer := TCustomer.Create;
          customerValidator := TPersonValidator.Create;
          customerValidator.setPerson(customer);
     end;
end;

function TFormCustomer.getCustomer():TCustomer;
begin
     getCustomer := Self.customer;
end;

procedure TFormCustomer.setCustomer(newCustomer:TCustomer);
begin
     Self.customer := newCustomer;
end;


procedure TFormCustomer.setFlagOperation(flag:Integer);
begin
     Self.flagOperacion:= flag;
end;

function TFormCustomer.getFlagAction():Integer;
begin
     getFlagAction := flagAction;
end;

initialization
  {$I ufcustomer.lrs}

end.
