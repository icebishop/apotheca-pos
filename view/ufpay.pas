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

unit UFPay;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  StdCtrls, Buttons, EditBtn, UPay, UFFindCustomer, UDataPay, UDataModule, sqldb,
  LCLType, ComCtrls, UPayValidator, UResourceString, LazLogger;

type

  { TFormPay }

  TFormPay = class(TForm)
    BitBtnCancel: TBitBtn;
    BitBtnOk: TBitBtn;
    BitBtnCustomer: TBitBtn;
    DateEdit: TDateEdit;
    EditCustomer: TEdit;
    EditValue: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    StatusBarPay: TStatusBar;
    procedure BitBtnCancelClick(Sender: TObject);
    procedure BitBtnOkClick(Sender: TObject);
    procedure BitBtnCustomerClick(Sender: TObject);
    procedure DateEditExit(Sender: TObject);
    procedure EditCustomerExit(Sender: TObject);
    procedure EditValueExit(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure Label2Click(Sender: TObject);
  private
    pay : TPay;
    payValidator : TPayValidator;
    flagOperacion:Integer;
  public
    function getPay():TPay;
    procedure setPay(newPay:TPay);
    procedure setFlagOperation(flag:Integer);
  end; 

var
  FormPay: TFormPay;

implementation

{ TFormPay }

procedure TFormPay.Label2Click(Sender: TObject);
begin
end;

procedure TFormPay.setFlagOperation(flag:Integer);
begin
     Self.flagOperacion:= flag;
end;

procedure TFormPay.setPay(newPay:TPay);
begin
     Self.pay := newPay;
     payValidator.setPay(pay);
end;

function TFormPay.getPay():TPay;
begin
     getPay := pay;
end;

procedure TFormPay.BitBtnCustomerClick(Sender: TObject);
var
   formFindCustomer : TFormFindCustomer;
begin
   try
   formFindCustomer := TFormFindCustomer.Create(Self);
   try
      formFindCustomer.ShowModal;
      pay.setPerson(formFindCustomer.getCustomer());
      EditCustomer.Text:= pay.getPerson.getName();
   finally
      formFindCustomer.Free;
   end;
   except
     on E: Exception do DebugLn('[TFormPay.BitBtnCustomerClick] ERROR: ' + E.Message);
   end;
end;

procedure TFormPay.DateEditExit(Sender: TObject);
begin
  try
  pay.setDate(DateEdit.Date);
  payValidator.setMessage('');
  StatusBarPay.SimpleText := payValidator.getMessage();
  if not payValidator.hasDate() then
     StatusBarPay.SimpleText := payValidator.getMessage();
  except
    on E: Exception do DebugLn('[TFormPay.DateEditExit] ERROR: ' + E.Message);
  end;
end;

procedure TFormPay.EditCustomerExit(Sender: TObject);
begin
  try
  payValidator.setMessage('');
  StatusBarPay.SimpleText := payValidator.getMessage();
  if not payValidator.hasCustomer() then
     StatusBarPay.SimpleText := payValidator.getMessage();
  except
    on E: Exception do DebugLn('[TFormPay.EditCustomerExit] ERROR: ' + E.Message);
  end;
end;

procedure TFormPay.EditValueExit(Sender: TObject);
begin
  try
  payValidator.setMessage('');
  StatusBarPay.SimpleText := payValidator.getMessage();
  if not payValidator.isNumber(EditValue.Text) then
  begin
     StatusBarPay.SimpleText := payValidator.getMessage();
     EditValue.Text:='0';
  end;
  except
    on E: Exception do DebugLn('[TFormPay.EditValueExit] ERROR: ' + E.Message);
  end;
end;

procedure TFormPay.FormCreate(Sender: TObject);
begin
  payValidator := TPayValidator.Create;
  setPay(TPay.Create);
end;

procedure TFormPay.FormShow(Sender: TObject);
begin
 try
 if pay.getPerson() <> nil then
   EditCustomer.Text:= pay.getPerson().getName();
 EditValue.Text:= FloatToStr(pay.getValue());
 DateEdit.Date:= pay.getDate();
 except
   on E: Exception do DebugLn('[TFormPay.FormShow] ERROR: ' + E.Message);
 end;
end;

procedure TFormPay.BitBtnOkClick(Sender: TObject);
var
   dataPay : TDataPay;
begin
   try
   pay.setDate(DateEdit.Date);
   pay.setValue(StrToFloat(EditValue.Text));
   if payValidator.validate() then
   begin
   DataModule1.EnsureTransaction;
   dataPay:= TDataPay.Create(DataModule1.SQLite3Connection1);
   try
if not          dataPay.getTransaction().Active then          dataPay.getTransaction().StartTransaction;
         if flagOperacion = 1 then
            if dataPay.new(pay) > 0 then
            begin
                 dataPay.getTransaction().Commit;
                 Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE),MB_OK );
            end
            else
            begin
                 Application.MessageBox(PChar(RS_OBJECTNOTSAVE), PChar(RS_Error), MB_ICONHAND);
                 dataPay.getTransaction().Rollback;
            end
         else
            if dataPay.edit(pay) then
            begin
                 dataPay.getTransaction().Commit;
                 Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE),MB_OK );
            end
            else
            begin
                 Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_Error), MB_ICONHAND);
                 dataPay.getTransaction().Rollback;
            end
   finally
     dataPay.Free;
   end;

   Close;
   end
   else
   begin
        Application.MessageBox(PChar(payValidator.getMessage()), PChar(RS_Error), MB_ICONWARNING);
   end
   except
     on E: Exception do DebugLn('[TFormPay.BitBtnOkClick] ERROR: ' + E.Message);
   end;
end;

procedure TFormPay.BitBtnCancelClick(Sender: TObject);
begin
  Close;
end;

initialization
  {$I ufpay.lrs}

end.

