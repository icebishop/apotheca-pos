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

unit UFramePeople;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ComCtrls, Grids, StdCtrls, Buttons,
  Dialogs, LCLType, SqlDb,
  UCustomer, USupplier, UDataCustomer, UDataSupplier, UDataModule,
  UFCustomer, UFSupplier, UResourceString, UGridUtils, LazLogger;

type

  { TFramePeople }

  TFramePeople = class(TFrame)
    TabControl: TTabControl;
    GridCustomers: TStringGrid;
    GridSuppliers: TStringGrid;
    EditSearch: TEdit;
    BtnAdd: TBitBtn;
    BtnEdit: TBitBtn;
    BtnDelete: TBitBtn;
    procedure TabControlChange(Sender: TObject);
    procedure EditSearchChange(Sender: TObject);
    procedure BtnAddClick(Sender: TObject);
    procedure BtnEditClick(Sender: TObject);
    procedure BtnDeleteClick(Sender: TObject);
  private
    FCustomerList: TList;
    FSupplierList: TList;
    procedure LoadCustomers(const AFilter: String);
    procedure LoadSuppliers(const AFilter: String);
    procedure RefreshActiveGrid;
    procedure FreeCustomerList;
    procedure FreeSupplierList;
    procedure InitGrids;
    function IsCustomersTab: Boolean;
    function GetSelectedCustomer: TCustomer;
    function GetSelectedSupplier: TSupplier;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

implementation

{$R *.lfm}

{ TFramePeople }

constructor TFramePeople.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCustomerList := nil;
  FSupplierList := nil;
  InitGrids;
end;

destructor TFramePeople.Destroy;
begin
  FreeCustomerList;
  FreeSupplierList;
  inherited Destroy;
end;

procedure TFramePeople.InitGrids;
begin
  GridCustomers.RowCount := 1;
  GridCustomers.FixedRows := 1;
  GridCustomers.Cells[0, 0] := 'Nombre';
  GridCustomers.Cells[1, 0] := 'Teléfono';
  GridCustomers.Cells[2, 0] := 'Dirección';
  DistributeColumns(GridCustomers, [40, 25, 35]);

  GridSuppliers.RowCount := 1;
  GridSuppliers.FixedRows := 1;
  GridSuppliers.Cells[0, 0] := 'Nombre';
  GridSuppliers.Cells[1, 0] := 'Teléfono';
  GridSuppliers.Cells[2, 0] := 'Dirección';
  DistributeColumns(GridSuppliers, [40, 25, 35]);
end;

procedure TFramePeople.FreeCustomerList;
var
  I: Integer;
begin
  if FCustomerList <> nil then
  begin
    for I := 0 to FCustomerList.Count - 1 do
      TCustomer(FCustomerList[I]).Free;
    FCustomerList.Free;
    FCustomerList := nil;
  end;
end;

procedure TFramePeople.FreeSupplierList;
var
  I: Integer;
begin
  if FSupplierList <> nil then
  begin
    for I := 0 to FSupplierList.Count - 1 do
      TSupplier(FSupplierList[I]).Free;
    FSupplierList.Free;
    FSupplierList := nil;
  end;
end;

function TFramePeople.IsCustomersTab: Boolean;
begin
  Result := TabControl.TabIndex = 0;
end;

procedure TFramePeople.LoadCustomers(const AFilter: String);
var
  DataCustomer: TDataCustomer;
  Customer: TCustomer;
  I: Integer;
  SearchParam: String;
  Trans: TSQLTransaction;
begin
  FreeCustomerList;

  DataModule1.EnsureTransaction;
  { Transaction handled by TData.Create }
  DataCustomer := TDataCustomer.Create(DataModule1.SQLite3Connection1);
  try
    if AFilter <> '' then
      SearchParam := '%' + AFilter + '%'
    else
      SearchParam := '';

    FCustomerList := DataCustomer.find(SearchParam);

    GridCustomers.RowCount := 1; // header only
    if (FCustomerList <> nil) and (FCustomerList.Count > 0) then
    begin
      GridCustomers.RowCount := FCustomerList.Count + 1;
      for I := 0 to FCustomerList.Count - 1 do
      begin
        Customer := TCustomer(FCustomerList[I]);
        GridCustomers.Cells[0, I + 1] := Customer.getName();
        GridCustomers.Cells[1, I + 1] := Customer.getTelephone();
        GridCustomers.Cells[2, I + 1] := Customer.getAddress();
      end;
    end;
  finally
    DataCustomer.Free;
  end;
end;

procedure TFramePeople.LoadSuppliers(const AFilter: String);
var
  DataSupplier: TDataSupplier;
  Supplier: TSupplier;
  I: Integer;
  SearchParam: String;
  Trans: TSQLTransaction;
begin
  FreeSupplierList;

  DataModule1.EnsureTransaction;
  { Transaction handled by TData.Create }
  DataSupplier := TDataSupplier.Create(DataModule1.SQLite3Connection1);
  try
    if AFilter <> '' then
      SearchParam := '%' + AFilter + '%'
    else
      SearchParam := '';

    FSupplierList := DataSupplier.find(SearchParam);

    GridSuppliers.RowCount := 1; // header only
    if (FSupplierList <> nil) and (FSupplierList.Count > 0) then
    begin
      GridSuppliers.RowCount := FSupplierList.Count + 1;
      for I := 0 to FSupplierList.Count - 1 do
      begin
        Supplier := TSupplier(FSupplierList[I]);
        GridSuppliers.Cells[0, I + 1] := Supplier.getName();
        GridSuppliers.Cells[1, I + 1] := Supplier.getTelephone();
        GridSuppliers.Cells[2, I + 1] := Supplier.getAddress();
      end;
    end;
  finally
    DataSupplier.Free;
  end;
end;

procedure TFramePeople.RefreshActiveGrid;
var
  Filter: String;
begin
  Filter := Trim(EditSearch.Text);
  if IsCustomersTab then
  begin
    GridCustomers.Visible := True;
    GridSuppliers.Visible := False;
    LoadCustomers(Filter);
  end
  else
  begin
    GridCustomers.Visible := False;
    GridSuppliers.Visible := True;
    LoadSuppliers(Filter);
  end;
end;

procedure TFramePeople.TabControlChange(Sender: TObject);
begin
  try
  EditSearch.Text := '';
  RefreshActiveGrid;
  except
    on E: Exception do DebugLn('[TFramePeople.TabControlChange] ERROR: ' + E.Message);
  end;
end;

procedure TFramePeople.EditSearchChange(Sender: TObject);
begin
  try
  RefreshActiveGrid;
  except
    on E: Exception do DebugLn('[TFramePeople.EditSearchChange] ERROR: ' + E.Message);
  end;
end;

procedure TFramePeople.BtnAddClick(Sender: TObject);
var
  FrmCustomer: TFormCustomer;
  FrmSupplier: TFormSupplier;
begin
  try
  if IsCustomersTab then
  begin
    FrmCustomer := TFormCustomer.Create(Application);
    try
      FrmCustomer.setFlagOperation(1); // new
      FrmCustomer.ShowModal;
    finally
      FrmCustomer.Free;
    end;
  end
  else
  begin
    FrmSupplier := TFormSupplier.Create(Application);
    try
      FrmSupplier.setFlagOperation(1); // new
      FrmSupplier.ShowModal;
    finally
      FrmSupplier.Free;
    end;
  end;
  RefreshActiveGrid;
  except
    on E: Exception do DebugLn('[TFramePeople.BtnAddClick] ERROR: ' + E.Message);
  end;
end;

function TFramePeople.GetSelectedCustomer: TCustomer;
var
  Row: Integer;
begin
  Result := nil;
  Row := GridCustomers.Row;
  if (Row >= 1) and (FCustomerList <> nil) and (Row <= FCustomerList.Count) then
    Result := TCustomer(FCustomerList[Row - 1]);
end;

function TFramePeople.GetSelectedSupplier: TSupplier;
var
  Row: Integer;
begin
  Result := nil;
  Row := GridSuppliers.Row;
  if (Row >= 1) and (FSupplierList <> nil) and (Row <= FSupplierList.Count) then
    Result := TSupplier(FSupplierList[Row - 1]);
end;

procedure TFramePeople.BtnEditClick(Sender: TObject);
var
  Customer: TCustomer;
  Supplier: TSupplier;
  FrmCustomer: TFormCustomer;
  FrmSupplier: TFormSupplier;
begin
  try
  if IsCustomersTab then
  begin
    Customer := GetSelectedCustomer;
    if Customer = nil then Exit;
    FrmCustomer := TFormCustomer.Create(Application);
    try
      FrmCustomer.setCustomer(Customer);
      FrmCustomer.setFlagOperation(0); // edit
      FrmCustomer.ShowModal;
    finally
      FrmCustomer.Free;
    end;
  end
  else
  begin
    Supplier := GetSelectedSupplier;
    if Supplier = nil then Exit;
    FrmSupplier := TFormSupplier.Create(Application);
    try
      FrmSupplier.setSupplier(Supplier);
      FrmSupplier.setFlagOperation(0); // edit
      FrmSupplier.ShowModal;
    finally
      FrmSupplier.Free;
    end;
  end;
  RefreshActiveGrid;
  except
    on E: Exception do DebugLn('[TFramePeople.BtnEditClick] ERROR: ' + E.Message);
  end;
end;

procedure TFramePeople.BtnDeleteClick(Sender: TObject);
var
  Customer: TCustomer;
  Supplier: TSupplier;
  DataCustomer: TDataCustomer;
  DataSupplier: TDataSupplier;
  ConfirmMsg: String;
  Trans: TSQLTransaction;
  Query: TSQLQuery;
  PersonId: Integer;
  OpCount: Integer;

  function HasOperations(APersonId: Integer): Integer;
  begin
    Result := 0;
    DataModule1.EnsureTransaction;
    Trans.DataBase := DataModule1.SQLite3Connection1;
    { Transaction handled by TData.Create }
    Query := TSQLQuery.Create(nil);
    Query.DataBase := DataModule1.SQLite3Connection1;
    Query.Transaction := Trans;
    try
      Query.SQL.Text := 'SELECT COUNT(*) AS cnt FROM operation WHERE person = :pid';
      Query.Params.ParamByName('pid').AsInteger := APersonId;
      Trans.StartTransaction;
      Query.Open;
      Result := Query.FieldByName('cnt').AsInteger;
      Query.Close;
      Trans.Commit;
    except
      if Trans.Active then Trans.Rollback;
    end;
    Query.Free;
  end;

begin
  try
  if IsCustomersTab then
  begin
    Customer := GetSelectedCustomer;
    if Customer = nil then Exit;

    { Check if customer has operations }
    OpCount := HasOperations(Customer.getId());
    if OpCount > 0 then
    begin
      Application.MessageBox(
        PChar('No se puede eliminar. Este cliente tiene ' + IntToStr(OpCount) + ' operación(es) registrada(s).'),
        PChar(RS_Error), MB_ICONWARNING);
      Exit;
    end;

    ConfirmMsg := RS_FMAINDELETECUSTOMER + ': ' + Customer.getName() + '?';
    if Application.MessageBox(PChar(ConfirmMsg), PChar(RS_MESSAGE),
       MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
      DataModule1.EnsureTransaction;
      Trans.DataBase := DataModule1.SQLite3Connection1;
      { Transaction handled by TData.Create }
      DataCustomer := TDataCustomer.Create(DataModule1.SQLite3Connection1);
      try
if not         DataCustomer.getTransaction().Active then         DataCustomer.getTransaction().StartTransaction;
        if DataCustomer.delete(Customer) then
        begin
          DataCustomer.getTransaction().Commit;
          Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE), MB_OK);
        end
        else
        begin
          DataCustomer.getTransaction().Rollback;
          Application.MessageBox(PChar(DataCustomer.getLastError()),
            PChar(RS_Error), MB_ICONHAND);
        end;
      finally
        DataCustomer.Free;
      end;
      RefreshActiveGrid;
    end;
  end
  else
  begin
    Supplier := GetSelectedSupplier;
    if Supplier = nil then Exit;

    { Check if supplier has operations }
    OpCount := HasOperations(Supplier.getId());
    if OpCount > 0 then
    begin
      Application.MessageBox(
        PChar('No se puede eliminar. Este proveedor tiene ' + IntToStr(OpCount) + ' operación(es) registrada(s).'),
        PChar(RS_Error), MB_ICONWARNING);
      Exit;
    end;

    ConfirmMsg := RS_FMAINDELETESUPPLIER + ': ' + Supplier.getName() + '?';
    if Application.MessageBox(PChar(ConfirmMsg), PChar(RS_MESSAGE),
       MB_YESNO or MB_ICONQUESTION) = IDYES then
    begin
      DataModule1.EnsureTransaction;
      Trans.DataBase := DataModule1.SQLite3Connection1;
      { Transaction handled by TData.Create }
      DataSupplier := TDataSupplier.Create(DataModule1.SQLite3Connection1);
      try
if not         DataSupplier.getTransaction().Active then         DataSupplier.getTransaction().StartTransaction;
        if DataSupplier.delete(Supplier) then
        begin
          DataSupplier.getTransaction().Commit;
          Application.MessageBox(PChar(RS_OBJECTSAVE), PChar(RS_MESSAGE), MB_OK);
        end
        else
        begin
          DataSupplier.getTransaction().Rollback;
          Application.MessageBox(PChar(DataSupplier.getLastError()),
            PChar(RS_Error), MB_ICONHAND);
        end;
      finally
        DataSupplier.Free;
      end;
      RefreshActiveGrid;
    end;
  end;
  except
    on E: Exception do DebugLn('[TFramePeople.BtnDeleteClick] ERROR: ' + E.Message);
  end;
end;

end.
