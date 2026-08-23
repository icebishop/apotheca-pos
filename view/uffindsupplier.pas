unit UFFindSupplier;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
StdCtrls, Grids, Buttons, USupplier, UDataSupplier, UDataModule, UFSupplier,
sqldb, UResourceString;

type

  { TFormFindSupplier }

TFormFindSupplier = class(TForm)
BitBtnNew: TBitBtn;
BitBtnOk: TBitBtn;
BitBtnCancel: TBitBtn;
EditSupplier: TEdit;
StringGridSupplier: TStringGrid;
procedure BitBtnCancelClick(Sender: TObject);
procedure BitBtnNewClick(Sender: TObject);
procedure BitBtnOkClick(Sender: TObject);
procedure EditSupplierKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
procedure FormCreate(Sender: TObject);
procedure StringGridSupplierClick(Sender: TObject);
private
    { private declarations }
listSupplier:TList;
supplier : TSupplier;
flagAction:Integer;
procedure loadDataGrid();
procedure loadData();
public
    { public declarations }
function getSupplier():TSupplier;
function getFlagAction():Integer;
end; 

var
FormFindSupplier: TFormFindSupplier;

implementation

procedure TFormFindSupplier.FormCreate(Sender: TObject);
begin

Self.Caption:= RS_FFINDSUPPLIER;
BitBtnNew.Caption := RS_NEW;
BitBtnOk.Caption := RS_OK;
BitBtnCancel.Caption := RS_CANCEL;

loadData();
loadDataGrid();
flagAction:= 0;
end;

procedure TFormFindSupplier.BitBtnNewClick(Sender: TObject);
var
formSupplier : TFormSupplier;
begin
formSupplier := TFormSupplier.Create(Self);
try
formSupplier.setFlagOperation(1);
formSupplier.ShowModal;
loadData();
loadDataGrid();
StringGridSupplier.Row:= StringGridSupplier.RowCount-1;
finally
formSupplier.Free;
end;
end;

procedure TFormFindSupplier.BitBtnCancelClick(Sender: TObject);
begin
     flagAction := 0;
     Close;
end;

procedure TFormFindSupplier.BitBtnOkClick(Sender: TObject);
begin
     StringGridSupplierClick(Sender);
end;

procedure TFormFindSupplier.EditSupplierKeyUp(Sender: TObject; var Key: Word;
Shift: TShiftState);
begin
loadData();
loadDataGrid();
end;

procedure TFormFindSupplier.StringGridSupplierClick(Sender: TObject);
begin
supplier := TSupplier(listSupplier[StringGridSupplier.Row-1]);
flagAction:=1;
Close;
end;

procedure TFormFindSupplier.loadDataGrid();
var
c:Integer;
begin
StringGridSupplier.Clean;
StringGridSupplier.RowCount:= listSupplier.Count+1;
StringGridSupplier.Cells[0, 0]:= RS_LSUPPLIERS;
For c := 0 to listSupplier.Count -1 do
begin
supplier := TSupplier (listSupplier[c]);
StringGridSupplier.Cells[0,c+1]:= supplier.getName();
end;
end;

procedure TFormFindSupplier.loadData();
var
dataSupplier : TDataSupplier;
begin

DataModule1.EnsureTransaction;
datasupplier := TDataSupplier.Create(DataModule1.SQLite3Connection1);
listSupplier := dataSupplier.find('%'+EditSupplier.Text+'%');
dataSupplier.free();
end;

function TFormFindSupplier.getSupplier():TSupplier;
begin
getSupplier := Self.supplier;
end;


function TFormFindSupplier.getFlagAction():Integer;
begin
getFlagAction := flagAction;
end;

initialization
  {$I uffindsupplier.lrs}

end.
