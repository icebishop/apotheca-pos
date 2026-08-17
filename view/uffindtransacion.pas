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

unit UFFindTransacion;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  Grids, Buttons, UTransaction, UFSale, UFPurchase, UFTransaction,
  UResourceString;

type

  { TFormFindTransaction }

  TFormFindTransaction = class(TForm)
    BitBtnOk: TBitBtn;
    BitBtnCancel: TBitBtn;
    BitBtnDetail: TBitBtn;
    StringGridTransaction: TStringGrid;
    procedure BitBtnOkClick(Sender: TObject);
    procedure BitBtnCancelClick(Sender: TObject);
    procedure BitBtnDetailClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure StringGridTransactionDblClick(Sender: TObject);
  private
    { private declarations }
    transactionList : TList;
    transaction:TTransaction;
    flagAction:Integer;
  public
    { public declarations }
    procedure setTransactionList(newTransactionList:TList);
    function getTransaction():TTransaction;
    procedure loadDataGrid();
    function getFlagAction():Integer;

  end; 

var
  FormFindTransaction: TFormFindTransaction;

implementation

procedure TFormFindTransaction.FormShow(Sender: TObject);
begin
  loadDataGrid();
end;

procedure TFormFindTransaction.BitBtnOkClick(Sender: TObject);
begin
  transaction := TTransaction(transactionList[StringGridTransaction.Row-1]);
  flagAction:=1;
  Close;
end;

procedure TFormFindTransaction.BitBtnCancelClick(Sender: TObject);
begin
  Close;
end;

procedure TFormFindTransaction.BitBtnDetailClick(Sender: TObject);
var
  formTransaction : TFormTransaction;
begin
  transaction := TTransaction(transactionList[StringGridTransaction.Row-1]);
  formTransaction := TFormTransaction.Create(Self);
  try
     formTransaction.setTransaction(transaction);
     formTransaction.ShowModal;
  finally
     formTransaction.Free;
  end;
end;

procedure TFormFindTransaction.FormCreate(Sender: TObject);
begin
  Self.Caption:= RS_FFINDTRANSACTION;
  BitBtnOk.Caption:= RS_OK;
  BitBtnCancel.Caption:= RS_CANCEL;
  BitBtnDetail.Caption := RS_LDETAIL;
end;

procedure TFormFindTransaction.StringGridTransactionDblClick(Sender: TObject);
begin
  BitBtnOkClick(Sender);
end;

procedure TFormFindTransaction.setTransactionList(newTransactionList:TList);
begin
     transactionList := newTransactionList;
end;

function TFormFindTransaction.getTransaction():TTransaction;
begin
    getTransaction := transaction;
end;

procedure TFormFindTransaction.loadDataGrid();
var
   i:Integer;
 begin
     StringGridTransaction.RowCount:= transactionList.Count + 1;
     StringGridTransaction.Cells[0,0]:= RS_LDATE;
     StringGridTransaction.Cells[1, 0]:= RS_LNUMBER;
     for i:=0 to transactionList.Count-1 do
     begin
         transaction := TTransaction(transactionList[i]);
         StringGridTransaction.Cells[0,i+1] := DateToStr(transaction.getDate());
         StringGridTransaction.Cells[1,i+1] := IntToStr(transaction.getId());
     end;
end;

function TFormFindTransaction.getFlagAction():Integer;
begin
   getFlagAction := flagAction;
end;

initialization
  {$I uffindtransacion.lrs}

end.

