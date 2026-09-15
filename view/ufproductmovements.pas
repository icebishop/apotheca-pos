{ Apothêca - Product movements history dialog

  Read-only modal listing every movement (any operation type: purchase, sale,
  return, adjustment …) that involved a given product.
  Columns: operation ID, type description, date, person/provider, quantity,
  and value (unit cost × qty for in-ops; unit price × qty for out-ops).

  All movements are loaded once from the DB; the date filter is applied
  client-side so the user can switch ranges without extra queries.

  Built programmatically (no .lfm) since it is a simple read-only view.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UFProductMovements;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DateUtils, Forms, Controls, Grids, StdCtrls, Buttons,
  ExtCtrls, EditBtn, UProduct, UResourceString;

{ Shows the modal movement-history dialog for AProduct. }
procedure ShowProductMovements(AOwner: TComponent; AProduct: TProduct);

implementation

uses
  UDataModule, UDataTransaction, UTransaction, UItem, UOperationType, UPerson,
  LazLogger, ULogger;

const
  COL_ID     = 0;
  COL_TYPE   = 1;
  COL_DATE   = 2;
  COL_PERSON = 3;
  COL_QTY    = 4;
  COL_VALUE  = 5;

type
  { In-memory record for one product movement, loaded once from the DB. }
  TMovementRec = record
    TransId    : Integer;
    TypeName   : String;
    TxDate     : TDateTime;
    PersonName : String;
    Qty        : Integer;
    Value      : Real;
    IsIn       : Boolean;
  end;

  { TProductMovementsForm - builds its own UI programmatically }
  TProductMovementsForm = class(TForm)
  private
    FGrid      : TStringGrid;
    FDateFrom  : TDateEdit;
    FDateTo    : TDateEdit;
    FLblTotal  : TLabel;
    FProduct   : TProduct;
    FRows      : array of TMovementRec;

    procedure BuildUI;
    procedure LoadAllMovements;
    procedure RefreshGrid;
    procedure BtnFilterClick(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; AProduct: TProduct); reintroduce;
  end;

{ ------------------------------------------------------------------ }
{ TProductMovementsForm                                               }
{ ------------------------------------------------------------------ }

constructor TProductMovementsForm.Create(AOwner: TComponent; AProduct: TProduct);
begin
  inherited CreateNew(AOwner);
  FProduct := AProduct;

  Caption     := Format(RS_PRODMOV_TITLE, [AProduct.getName()]);
  Position    := poOwnerFormCenter;
  Width       := 720;
  Height      := 470;
  BorderStyle := bsSizeable;

  BuildUI;
  LoadAllMovements;
  RefreshGrid;
end;

procedure TProductMovementsForm.BuildUI;
var
  PanelTop : TPanel;
  LblFrom  : TLabel;
  LblTo    : TLabel;
  BtnFilter: TBitBtn;
  BtnClose : TBitBtn;
begin
  { ── Top filter bar ───────────────────────────────────────────── }
  PanelTop := TPanel.Create(Self);
  PanelTop.Parent     := Self;
  PanelTop.Align      := alTop;
  PanelTop.Height     := 48;
  PanelTop.BevelOuter := bvNone;

  LblFrom := TLabel.Create(Self);
  LblFrom.Parent  := PanelTop;
  LblFrom.Caption := RS_PRODMOV_FROM;
  LblFrom.Left    := 8;
  LblFrom.Top     := 16;

  FDateFrom := TDateEdit.Create(Self);
  FDateFrom.Parent := PanelTop;
  FDateFrom.Left   := LblFrom.Left + LblFrom.Width + 6;
  FDateFrom.Top    := 12;
  FDateFrom.Width  := 110;
  FDateFrom.Date   := IncMonth(Date, -6); { default: last 6 months }

  LblTo := TLabel.Create(Self);
  LblTo.Parent  := PanelTop;
  LblTo.Caption := RS_PRODMOV_TO;
  LblTo.Left    := FDateFrom.Left + FDateFrom.Width + 14;
  LblTo.Top     := 16;

  FDateTo := TDateEdit.Create(Self);
  FDateTo.Parent := PanelTop;
  FDateTo.Left   := LblTo.Left + LblTo.Width + 6;
  FDateTo.Top    := 12;
  FDateTo.Width  := 110;
  FDateTo.Date   := Date;  { today }

  BtnFilter := TBitBtn.Create(Self);
  BtnFilter.Parent   := PanelTop;
  BtnFilter.Caption  := RS_PRODMOV_BTN_FILTER;
  BtnFilter.Left     := FDateTo.Left + FDateTo.Width + 16;
  BtnFilter.Top      := 10;
  BtnFilter.Width    := 90;
  BtnFilter.Kind     := bkCustom;
  BtnFilter.OnClick  := @BtnFilterClick;

  { ── Summary label (bottom) ────────────────────────────────────── }
  FLblTotal := TLabel.Create(Self);
  FLblTotal.Parent            := Self;
  FLblTotal.Align             := alBottom;
  FLblTotal.BorderSpacing.Top := 4;
  FLblTotal.BorderSpacing.Bottom := 4;
  FLblTotal.BorderSpacing.Left   := 8;
  FLblTotal.Caption           := '';

  { ── Close button (bottom) ────────────────────────────────────── }
  BtnClose := TBitBtn.Create(Self);
  BtnClose.Parent            := Self;
  BtnClose.Align             := alBottom;
  BtnClose.BorderSpacing.Around := 6;
  BtnClose.Caption           := RS_PRODMOV_BTN_CLOSE;
  BtnClose.Kind              := bkClose;
  BtnClose.Default           := True;

  { ── Grid (fills remaining space) ─────────────────────────────── }
  FGrid := TStringGrid.Create(Self);
  FGrid.Parent := Self;
  FGrid.Align  := alClient;
  FGrid.BorderSpacing.Around := 8;
  FGrid.FixedRows := 1;
  FGrid.FixedCols := 0;
  FGrid.RowCount  := 1;
  FGrid.ColCount  := 6;
  FGrid.Options := FGrid.Options + [goRowSelect, goVertLine, goHorzLine,
    goFixedHorzLine, goFixedVertLine];

  FGrid.Cells[COL_ID,     0] := RS_PRODMOV_COL_ID;
  FGrid.Cells[COL_TYPE,   0] := RS_PRODMOV_COL_TYPE;
  FGrid.Cells[COL_DATE,   0] := RS_PRODMOV_COL_DATE;
  FGrid.Cells[COL_PERSON, 0] := RS_PRODMOV_COL_PERSON;
  FGrid.Cells[COL_QTY,    0] := RS_PRODMOV_COL_QTY;
  FGrid.Cells[COL_VALUE,  0] := RS_PRODMOV_COL_VALUE;

  FGrid.ColWidths[COL_ID]     := 55;
  FGrid.ColWidths[COL_TYPE]   := 140;
  FGrid.ColWidths[COL_DATE]   := 105;
  FGrid.ColWidths[COL_PERSON] := 160;
  FGrid.ColWidths[COL_QTY]    := 65;
  FGrid.ColWidths[COL_VALUE]  := 120;
end;

procedure TProductMovementsForm.LoadAllMovements;
var
  DataTrans  : TDataTransaction;
  List       : TList;
  Trans      : TTransaction;
  Item       : TItem;
  OpType     : TOperationType;
  Person     : TPerson;
  i, j, Idx : Integer;
  Qty        : Integer;
  Value      : Real;
  IsIn       : Boolean;
  PersonName : String;
  TypeName   : String;
begin
  SetLength(FRows, 0);
  try
    DataModule1.EnsureTransaction;
    DataTrans := TDataTransaction.Create(DataModule1.SQLite3Connection1);
    try
      { get(product) returns ALL operation types for this product. }
      List := DataTrans.get(FProduct);
      if List = nil then Exit;

      SetLength(FRows, List.Count);
      Idx := 0;

      for i := 0 to List.Count - 1 do
      begin
        Trans := TTransaction(List[i]);
        if Trans = nil then Continue;

        { Determine direction from the operation type. }
        OpType := Trans.getOperationType();
        if OpType <> nil then
        begin
          TypeName := OpType.getName();
          IsIn     := OpType.getTyp() = 'in';
        end
        else
        begin
          TypeName := '?';
          IsIn     := True;
        end;

        { Person name (supplier for in-ops, customer for out-ops). }
        Person := Trans.getPerson();
        if (Person <> nil) and (Person.getName() <> '') then
          PersonName := Person.getName()
        else
          PersonName := '-';

        { Accumulate qty / value for items of this product in this op. }
        Qty   := 0;
        Value := 0;
        if Trans.getItemList() <> nil then
          for j := 0 to Trans.getItemList().Count - 1 do
          begin
            Item := TItem(Trans.getItemList()[j]);
            if (Item.getProduct() <> nil) and
               (Item.getProduct().getId() = FProduct.getId()) then
            begin
              Qty := Qty + Item.getStock();
              if IsIn then
                Value := Value + (Item.getCost()  * Item.getStock())
              else
                Value := Value + (Item.getPrice() * Item.getStock());
            end;
          end;

        FRows[Idx].TransId    := Trans.getId();
        FRows[Idx].TypeName   := TypeName;
        FRows[Idx].TxDate     := Trans.getDate();
        FRows[Idx].PersonName := PersonName;
        FRows[Idx].Qty        := Qty;
        FRows[Idx].Value      := Value;
        FRows[Idx].IsIn       := IsIn;
        Inc(Idx);
      end;

      SetLength(FRows, Idx);
    finally
      DataTrans.Destroy;
    end;
  except
    on E: Exception do
      LogError('ProductMovements', 'LOAD_FAILED',
        'productId=' + IntToStr(FProduct.getId()) + ' error=' + E.Message);
  end;
end;

procedure TProductMovementsForm.RefreshGrid;
var
  i, Row, TotalIn, TotalOut : Integer;
  DateFrom, DateTo          : TDateTime;
begin
  DateFrom := Trunc(FDateFrom.Date);
  DateTo   := Trunc(FDateTo.Date);     { inclusive: both bounds are whole days }

  TotalIn  := 0;
  TotalOut := 0;
  Row      := 1;
  FGrid.RowCount := 1;                 { reset to header-only }

  for i := 0 to High(FRows) do
  begin
    if (Trunc(FRows[i].TxDate) < DateFrom) or
       (Trunc(FRows[i].TxDate) > DateTo) then
      Continue;

    FGrid.RowCount := Row + 1;
    FGrid.Cells[COL_ID,     Row] := IntToStr(FRows[i].TransId);
    FGrid.Cells[COL_TYPE,   Row] := FRows[i].TypeName;
    FGrid.Cells[COL_DATE,   Row] := FormatDateTime('yyyy-mm-dd', FRows[i].TxDate);
    FGrid.Cells[COL_PERSON, Row] := FRows[i].PersonName;
    FGrid.Cells[COL_QTY,    Row] := IntToStr(FRows[i].Qty);
    FGrid.Cells[COL_VALUE,  Row] := FormatFloat('0.00', FRows[i].Value);
    Inc(Row);

    if FRows[i].IsIn then
      TotalIn  := TotalIn  + FRows[i].Qty
    else
      TotalOut := TotalOut + FRows[i].Qty;
  end;

  if Row <= 1 then
    FLblTotal.Caption := RS_PRODMOV_NONE
  else
    FLblTotal.Caption := Format(RS_PRODMOV_TOTAL, [TotalIn, TotalOut]);
end;

procedure TProductMovementsForm.BtnFilterClick(Sender: TObject);
begin
  RefreshGrid;
end;

{ ------------------------------------------------------------------ }
{ Public entry point                                                  }
{ ------------------------------------------------------------------ }

procedure ShowProductMovements(AOwner: TComponent; AProduct: TProduct);
var
  Frm: TProductMovementsForm;
begin
  if AProduct = nil then Exit;
  Frm := TProductMovementsForm.Create(AOwner, AProduct);
  try
    Frm.ShowModal;
  finally
    Frm.Free;
  end;
end;

end.
