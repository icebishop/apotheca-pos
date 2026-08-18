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

unit UFrameReturns;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, EditBtn, Grids,
  Buttons, ComCtrls, Dialogs, LCLType,
  UItem, UOperationType, UPerson, UFFindCustomer, UFFindSupplier, UFFindProduct,
  UReturnService, UBalanceBuilder, UDataModule, UResourceString, UGridUtils,
  UDataOperationType;

type

  { TFrameReturns }

  TFrameReturns = class(TFrame)
    BtnAddItem: TBitBtn;
    BtnDeleteItem: TBitBtn;
    BtnRebuild: TBitBtn;
    BtnSave: TBitBtn;
    BtnSelectPerson: TBitBtn;
    BtnSelectProduct: TButton;
    ComboOpType: TComboBox;
    DateEdit: TDateEdit;
    EditPerson: TEdit;
    GridItems: TStringGrid;
    LabelDate: TLabel;
    LabelOpType: TLabel;
    LabelPerson: TLabel;
    LabelTitle: TLabel;
    StatusBarReturns: TStatusBar;
    procedure BtnAddItemClick(Sender: TObject);
    procedure BtnDeleteItemClick(Sender: TObject);
    procedure BtnRebuildClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnSelectPersonClick(Sender: TObject);
    procedure BtnSelectProductClick(Sender: TObject);
    procedure ComboOpTypeChange(Sender: TObject);
    procedure DateEditChange(Sender: TObject);
    procedure GridItemsEditingDone(Sender: TObject);
    procedure GridItemsSelectCell(Sender: TObject; aCol, aRow: Integer;
      var CanSelect: Boolean);
  private
    FReturnService: TReturnService;
    FOperationType: TOperationType;
    FPerson: TPerson;
    FItems: TList;
    FOperationDirection: String;
    procedure LoadDataGrid;
    procedure ClearForm;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.lfm}

{ TFrameReturns }

constructor TFrameReturns.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FReturnService := TReturnService.Create;
  FItems := TList.Create;
  FPerson := nil;
  FOperationType := nil;

  { Setup inline product select button inside grid }
  GridItems.DefaultRowHeight := BtnSelectProduct.Height;
  BtnSelectProduct.Parent := GridItems;
  BtnSelectProduct.Visible := False;

  { Assign labels from resourcestrings for i18n }
  LabelTitle.Caption := RS_RETURNS_TITLE;
  LabelOpType.Caption := RS_RETURNS_OP_TYPE;
  LabelPerson.Caption := RS_RETURNS_PERSON;
  LabelDate.Caption := RS_RETURNS_DATE;
  GridItems.Cells[0, 0] := RS_RETURNS_GRID_PRODUCT;
  GridItems.Cells[1, 0] := RS_RETURNS_GRID_QTY;
  GridItems.Cells[2, 0] := RS_RETURNS_GRID_COST;

  { Populate operation type combo from resourcestrings }
  ComboOpType.Items.Clear;
  ComboOpType.Items.Add(RS_RETURNS_COMBO_DEVOLUTION);
  ComboOpType.Items.Add(RS_RETURNS_COMBO_LOSS);
  ComboOpType.Items.Add(RS_RETURNS_COMBO_PROVIDER);
  ComboOpType.ItemIndex := 0;
  FOperationDirection := 'in';

  { Initialize date to today }
  DateEdit.Date := Now;

  { Add initial empty item row }
  FItems.Add(TItem.Create);
  LoadDataGrid;
end;

destructor TFrameReturns.Destroy;
var
  i: Integer;
begin
  FReturnService.Free;
  for i := 0 to FItems.Count - 1 do
    TItem(FItems[i]).Free;
  FItems.Free;
  inherited Destroy;
end;

procedure TFrameReturns.ClearForm;
var
  i: Integer;
begin
  { Free existing items }
  for i := 0 to FItems.Count - 1 do
    TItem(FItems[i]).Free;
  FItems.Clear;

  { Reset person }
  FPerson := nil;
  EditPerson.Text := '';

  { Reset combo to first option }
  ComboOpType.ItemIndex := 0;
  FOperationDirection := 'in';

  { Reset date }
  DateEdit.Date := Now;

  { Add initial empty item row }
  FItems.Add(TItem.Create);
  LoadDataGrid;

  StatusBarReturns.SimpleText := '';
end;

procedure TFrameReturns.ComboOpTypeChange(Sender: TObject);
begin
  case ComboOpType.ItemIndex of
    0: FOperationDirection := 'in';   { Customer Devolution }
    1: FOperationDirection := 'out';  { Inventory Loss }
    2: FOperationDirection := 'out';  { Return to Provider }
  end;

  { Clear person when type changes }
  FPerson := nil;
  EditPerson.Text := '';

  { Enable/disable person selection based on type }
  case ComboOpType.ItemIndex of
    0: BtnSelectPerson.Enabled := True;   { Customer Devolution - need customer }
    1: BtnSelectPerson.Enabled := False;  { Inventory Loss - no person }
    2: BtnSelectPerson.Enabled := True;   { Return to Provider - need supplier }
  end;
end;

procedure TFrameReturns.BtnSelectPersonClick(Sender: TObject);
var
  formFindCustomer: TFormFindCustomer;
  formFindSupplier: TFormFindSupplier;
begin
  case ComboOpType.ItemIndex of
    0: { Customer Devolution - open Find Customer }
    begin
      formFindCustomer := TFormFindCustomer.Create(Self);
      try
        formFindCustomer.ShowModal;
        if formFindCustomer.getCustomer() <> nil then
        begin
          FPerson := formFindCustomer.getCustomer();
          EditPerson.Text := FPerson.getName();
        end;
      finally
        formFindCustomer.Free;
      end;
    end;
    2: { Return to Provider - open Find Supplier }
    begin
      formFindSupplier := TFormFindSupplier.Create(Self);
      try
        formFindSupplier.ShowModal;
        if formFindSupplier.getSupplier() <> nil then
        begin
          FPerson := formFindSupplier.getSupplier();
          EditPerson.Text := FPerson.getName();
        end;
      finally
        formFindSupplier.Free;
      end;
    end;
  end;
end;

procedure TFrameReturns.DateEditChange(Sender: TObject);
begin
  { Prevent future dates }
  if DateEdit.Date > Now then
    DateEdit.Date := Now;
end;

procedure TFrameReturns.BtnAddItemClick(Sender: TObject);
begin
  FItems.Add(TItem.Create);
  LoadDataGrid;
end;

procedure TFrameReturns.BtnDeleteItemClick(Sender: TObject);
begin
  if (FItems.Count > 0) and (GridItems.Row > 0) and
     (GridItems.Row <= FItems.Count) then
  begin
    TItem(FItems[GridItems.Row - 1]).Free;
    FItems.Delete(GridItems.Row - 1);
    LoadDataGrid;
  end;
end;

procedure TFrameReturns.BtnSelectProductClick(Sender: TObject);
var
  formProduct: TFormFindProduct;
  item: TItem;
begin
  if (GridItems.Row < 1) or (GridItems.Row > FItems.Count) then
    Exit;

  formProduct := TFormFindProduct.Create(Self);
  try
    formProduct.setFlagAllProducts(True);
    formProduct.ShowModal;
    if formProduct.getProduct() <> nil then
    begin
      item := TItem(FItems[GridItems.Row - 1]);
      item.setProduct(formProduct.getProduct());
      item.setCost(item.getProduct().getBalance().getCost());
      item.setStock(1);
      LoadDataGrid;
    end;
  finally
    formProduct.Free;
  end;
end;

procedure TFrameReturns.GridItemsEditingDone(Sender: TObject);
var
  item: TItem;
  row: Integer;
  qty: Integer;
begin
  row := GridItems.Row;
  if (row < 1) or (row > FItems.Count) then
    Exit;

  item := TItem(FItems[row - 1]);

  { Column 1 = Quantity }
  qty := StrToIntDef(GridItems.Cells[1, row], 1);
  if qty < 1 then qty := 1;
  item.setStock(qty);

  LoadDataGrid;
end;

procedure TFrameReturns.GridItemsSelectCell(Sender: TObject; aCol,
  aRow: Integer; var CanSelect: Boolean);
var
  rect: TRect;
begin
  if (aCol = 0) and (aRow > 0) then
  begin
    rect := GridItems.CellRect(aCol, aRow);
    rect.Left := rect.Left + (rect.Right - rect.Left) - BtnSelectProduct.Width;
    rect.Right := rect.Left + BtnSelectProduct.Width;
    rect.Bottom := rect.Top + BtnSelectProduct.Height;
    BtnSelectProduct.BoundsRect := rect;
    BtnSelectProduct.Visible := True;
  end
  else
    BtnSelectProduct.Visible := False;
end;

procedure TFrameReturns.BtnSaveClick(Sender: TObject);
var
  dataOpType: TDataOperationType;
  opType: TOperationType;
  opDescription: String;
begin
  StatusBarReturns.SimpleText := '';

  { Map combo index to DB description (English) }
  case ComboOpType.ItemIndex of
    0: opDescription := 'Customer Devolution';
    1: opDescription := 'Inventory Loss';
    2: opDescription := 'Return to Provider';
  else
    opDescription := '';
  end;

  { Query the actual TOperationType record from DB }
  dataOpType := TDataOperationType.Create(DataModule1.SQLite3Connection1);
  try
    opType := dataOpType.getByDescription(opDescription);
  finally
    dataOpType.Free;
  end;

  if opType = nil then
  begin
    StatusBarReturns.SimpleText := RS_RETURNS_SAVE_ERROR;
    Exit;
  end;

  { Call FReturnService.SaveReturn }
  if FReturnService.SaveReturn(opType, FPerson, DateEdit.Date, FItems) then
  begin
    StatusBarReturns.SimpleText := RS_RETURNS_SAVE_SUCCESS;
    ClearForm;
  end
  else
  begin
    StatusBarReturns.SimpleText := FReturnService.GetLastError;
  end;
end;

procedure TFrameReturns.BtnRebuildClick(Sender: TObject);
var
  balanceBuilder: TBalanceBuilder;
begin
  StatusBarReturns.SimpleText := '';

  balanceBuilder := TBalanceBuilder.Create;
  try
    if balanceBuilder.build() then
    begin
      StatusBarReturns.SimpleText := RS_RETURNS_REBUILD_SUCCESS;
    end
    else
    begin
      MessageDlg(balanceBuilder.getBalanceMessage(), mtWarning, [mbOK], 0);
    end;
  finally
    balanceBuilder.Free;
  end;
end;

procedure TFrameReturns.LoadDataGrid;
var
  i: Integer;
  item: TItem;
begin
  GridItems.Clean([gzNormal]);
  GridItems.RowCount := FItems.Count + 1;

  DistributeColumns(GridItems, [50, 25, 25]);

  for i := 0 to FItems.Count - 1 do
  begin
    item := TItem(FItems[i]);
    if item.getProduct() <> nil then
      GridItems.Cells[0, i + 1] := item.getProduct().getName()
    else
      GridItems.Cells[0, i + 1] := '';
    GridItems.Cells[1, i + 1] := IntToStr(item.getStock());
    GridItems.Cells[2, i + 1] := FormatFloat('0.00', item.getCost());
  end;
end;

end.
