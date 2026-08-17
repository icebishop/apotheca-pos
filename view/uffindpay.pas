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

unit UFFindpay;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs,
  Grids, Buttons, UPay, ExtCtrls, UResourceString;

type

  { TFormFindPay }

  TFormFindPay = class(TForm)
    BitBtnOk: TBitBtn;
    BitBtnCancel: TBitBtn;
    StringGridPay: TStringGrid;
    procedure BitBtnOkClick(Sender: TObject);
    procedure BitBtnCancelClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure StringGridPayDblClick(Sender: TObject);
  private
    { private declarations }
    payList : TList;
    pay:TPay;
    flagAction:Integer;
  public
    { public declarations }
    procedure setPayList(newPayList:TList);
    function getPay():TPay;
    procedure loadDataGrid();
    function getFlagAction():Integer;

  end; 

var
  FormFindPay: TFormFindPay;

implementation

function TFormFindPay.getFlagAction():Integer;
begin
     getFlagAction := flagAction;
end;

function TFormFindPay.getPay():TPay;
begin
     getPay := pay;
end;

procedure TFormFindPay.BitBtnOkClick(Sender: TObject);
begin
   pay := TPay(payList[StringGridPay.Row-1]);
   flagAction:=1;
   Close;
end;

procedure TFormFindPay.BitBtnCancelClick(Sender: TObject);
begin
  flagAction:=0;
  Close;
end;

procedure TFormFindPay.FormClose(Sender: TObject; var CloseAction: TCloseAction
  );
begin
  if flagAction <> 1 then
    flagAction:=0;
end;

procedure TFormFindPay.FormCreate(Sender: TObject);
begin
     BitBtnCancel.Caption := RS_CANCEL;
     BitBtnOk.Caption     := RS_OK;
     Self.Caption         := RS_LFINDPAY;
end;

procedure TFormFindPay.FormShow(Sender: TObject);
begin
  if payList.Count > 0 then
     BitBtnOk.Enabled := true
  else
     BitBtnOk.Enabled := false;
  loadDataGrid();
end;

procedure TFormFindPay.StringGridPayDblClick(Sender: TObject);
begin
   BitBtnOkClick(Sender);
end;

procedure TFormFindPay.setPayList(newPayList: TList);
begin
    Self.payList := newPayList;
end;

procedure TFormFindPay.loadDataGrid();
var
   i:Integer;
 begin
     StringGridPay.RowCount:= payList.Count + 1;
     StringGridPay.Cells[0, 0]:= RS_LDATE;
     StringGridPay.Cells[1, 0]:= RS_LVALUE;
     for i:=0 to payList.Count-1 do
     begin
         pay := TPay(payList[i]);
         StringGridPay.Cells[0,i+1] := DateToStr(pay.getDate());
         StringGridPay.Cells[1,i+1] := FloatToStr(pay.getValue());
     end;
end;




initialization
  {$I uffindpay.lrs}

end.

