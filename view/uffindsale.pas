unit UFFindSale;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
  Grids, Buttons, USale;

type

  { TFormFindSale }

  TFormFindSale = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    StringGrid1: TStringGrid;
  procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormShow(Sender: TObject);
    procedure StringGrid1DblClick(Sender: TObject);
  private
    { private declarations }
    saleList : TList;
    sale:TSale;
    flagAction:Integer;
  public
    { public declarations }
    procedure setSaleList(newSaleList:TList);
    function getSale():TSale;
    procedure loadDataGrid();
    function getFlagAction():Integer;

  end;

var
  FormFindSale: TFormFindSale;

implementation

function TFormFindSale.getFlagAction():Integer;
begin
     getFlagAction := flagAction;
end;

function TFormFindSale.getSale():TSale;
begin
     getSale := sale;
end;

procedure TFormFindSale.BitBtn1Click(Sender: TObject);
begin
   sale := TSale(saleList[StringGrid1.Row-1]);
   flagAction:=1;
   Close;
end;

procedure TFormFindSale.BitBtn2Click(Sender: TObject);
begin
  flagAction:=0;
  Close;
end;

procedure TFormFindSale.FormClose(Sender: TObject; var CloseAction: TCloseAction
  );
begin
  if flagAction <> 1 then
    flagAction:=0;
end;

procedure TFormFindSale.FormShow(Sender: TObject);
begin
  if saleList.Count > 0 then
     BitBtn1.Enabled := true
  else
     BitBtn1.Enabled := false;
  loadDataGrid();
end;

procedure TFormFindSale.StringGrid1DblClick(Sender: TObject);
begin
   BitBtn1Click(Sender);
end;

procedure TFormFindSale.setSaleList(newSaleList: TList);
begin
    Self.saleList := newSaleList;
end;

procedure TFormFindSale.loadDataGrid();
var
   i:Integer;
 begin
     StringGrid1.RowCount:= saleList.Count + 1;
     StringGrid1.Cells[0,0]:= 'Date';
     StringGrid1.Cells[1,0]:= 'Value';
     for i:=0 to saleList.Count-1 do
     begin
         sale := TSale(saleList[i]);
         StringGrid1.Cells[0,i+1] := DateToStr(sale.getDate());
         StringGrid1.Cells[1,i+1] := FloatToStr(sale.getSum());
     end;
end;

initialization
  {$I uffindpay.lrs}

end.

