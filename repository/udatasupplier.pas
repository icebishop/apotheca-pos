unit UDataSupplier;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, SqlDb, USupplier, UDataPerson;

type
  TDataSupplier = class(TDataPerson)
  private
    FLastError: String;
  public
    function find(name:String):TList;
    function new(supplier:TSupplier):Integer;
    function edit(supplier:TSupplier):Boolean;
    function delete(supplier:TSupplier):Boolean;
    function getLastError(): String;
  end;

implementation

function TDataSupplier.getLastError(): String;
begin
  getLastError := FLastError;
end;

function TDataSupplier.find(name:String):TList;
var
  listSupplier:TList;
  supplier:TSupplier;
begin
  try
    Self.getQuery().SQL.Text := 'SELECT * from person, supplier where person.id = supplier.person ';
    if name <> '' then
    begin
      Self.getQuery().SQL.Text := Self.getQuery().SQL.Text + 'and name like :name';
      Self.getQuery().Params.ParamByName('name').AsString := name;
    end;
    Self.getQuery().Open;

    listSupplier := TList.Create;
    Self.getQuery().First;
    while not Self.getQuery().EOF do
    begin
      supplier := TSupplier.Create;
      supplier.setId(Self.getQuery().FieldByName('person').AsInteger);
      supplier.setName(Self.getQuery().FieldByName('name').AsString);
      supplier.setTelephone(Self.getQuery().FieldByName('telephone').AsString);
      supplier.setAddress(Self.getQuery().FieldByName('address').AsString);
      listSupplier.Add(supplier);
      Self.getQuery().Next;
    end;
    Self.getQuery().Close;
    find := listSupplier;
  except
    find := nil;
  end;
end;

function TDataSupplier.new(supplier:TSupplier):Integer;
begin
  try
    supplier.setId(Inherited new(supplier));
    Self.getQuery().SQL.Text := 'insert into supplier (person) values (:person)';
    Self.getQuery().Params.ParamByName('person').AsInteger := supplier.getId();
    Self.getQuery().ExecSQL;
    Self.getQuery().Close;
    new := supplier.getId();
  except
    new := 0;
  end;
end;

function TDataSupplier.edit(supplier:TSupplier):Boolean;
begin
  edit := Inherited edit(supplier);
end;

function TDataSupplier.delete(supplier:TSupplier):Boolean;
var
  OpCount: Integer;
begin
  FLastError := '';
  if (supplier = nil) or (supplier.getId() <= 0) then
  begin
    FLastError := 'Invalid supplier record.';
    Result := False;
    Exit;
  end;
  try
    Self.getQuery().SQL.Text := 'SELECT COUNT(*) AS cnt FROM operation WHERE person = :person';
    Self.getQuery().Params.ParamByName('person').AsInteger := supplier.getId();
    Self.getQuery().Open;
    OpCount := Self.getQuery().FieldByName('cnt').AsInteger;
    Self.getQuery().Close;
    if OpCount > 0 then
    begin
      FLastError := Format('Cannot delete: supplier has %d transaction record(s).', [OpCount]);
      Result := False;
      Exit;
    end;
    Self.getQuery().SQL.Text := 'DELETE FROM supplier WHERE person = :person';
    Self.getQuery().Params.ParamByName('person').AsInteger := supplier.getId();
    Self.getQuery().ExecSQL;
    Self.getQuery().SQL.Text := 'DELETE FROM person WHERE id = :id';
    Self.getQuery().Params.ParamByName('id').AsInteger := supplier.getId();
    Self.getQuery().ExecSQL;
    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'DB error during supplier deletion: ' + E.Message;
      Result := False;
    end;
  end;
end;

end.
