unit UDataCustomer;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, SqlDb, UCustomer, UDataPerson, UPerson;

type
  TDataCustomer = class(TDataPerson)
  private
    FLastError: String;
  public
    function find(name:String):TList;
    function new(customer:TCustomer):Integer;
    function edit(customer:TCustomer):Boolean;
    function delete(customer:TCustomer):Boolean;
    function get(customerId:Integer):TCustomer;
    function getLastError(): String;
  end;

implementation

function TDataCustomer.getLastError(): String;
begin
  getLastError := FLastError;
end;

function TDataCustomer.find(name:String):TList;
var
  listCustomer:TList;
  customer:TCustomer;
begin
  try
    Self.getQuery().SQL.Text := 'select * from customer,person where person.id = customer.person ';
    if name <> '' then
    begin
      Self.getQuery().SQL.Text := Self.getQuery().SQL.Text + 'and name like :name';
      Self.getQuery().Params.ParamByName('name').AsString := name;
    end;
    Self.getQuery().Open;

    listCustomer := TList.Create;
    Self.getQuery().First;
    while not Self.getQuery().EOF do
    begin
      customer := TCustomer.Create;
      customer.setId(Self.getQuery().FieldByName('person').AsInteger);
      customer.setName(Self.getQuery().FieldByName('name').AsString);
      customer.setTelephone(Self.getQuery().FieldByName('telephone').AsString);
      customer.setAddress(Self.getQuery().FieldByName('address').AsString);
      listCustomer.Add(customer);
      Self.getQuery().Next;
    end;
    Self.getQuery().Close;
    find := listCustomer;
  except
    find := nil;
  end;
end;

function TDataCustomer.new(customer:TCustomer):Integer;
begin
  try
    customer.setId(Inherited new(customer));
    Self.getQuery().SQL.Text := 'insert into customer (person) values (:person)';
    Self.getQuery().Params.ParamByName('person').AsInteger := customer.getId();
    Self.getQuery().ExecSQL;
    new := customer.getId();
    Self.getQuery().Close;
  except
    new := 0;
  end;
end;

function TDataCustomer.edit(customer:TCustomer):Boolean;
begin
  edit := Inherited edit(customer);
end;

function TDataCustomer.delete(customer:TCustomer):Boolean;
var
  OpCount, PayCount: Integer;
begin
  FLastError := '';
  if (customer = nil) or (customer.getId() <= 0) then
  begin
    FLastError := 'Invalid customer record.';
    Result := False;
    Exit;
  end;

  try
    { Check 1: blocking operation records }
    Self.getQuery().SQL.Text := 'SELECT COUNT(*) AS cnt FROM operation WHERE person = :person';
    Self.getQuery().Params.ParamByName('person').AsInteger := customer.getId();
    Self.getQuery().Open;
    OpCount := Self.getQuery().FieldByName('cnt').AsInteger;
    Self.getQuery().Close;

    if OpCount > 0 then
    begin
      FLastError := Format('Cannot delete: customer has %d transaction record(s).', [OpCount]);
      Result := False;
      Exit;
    end;

    { Check 2: blocking pay records }
    Self.getQuery().SQL.Text := 'SELECT COUNT(*) AS cnt FROM pay WHERE person = :person';
    Self.getQuery().Params.ParamByName('person').AsInteger := customer.getId();
    Self.getQuery().Open;
    PayCount := Self.getQuery().FieldByName('cnt').AsInteger;
    Self.getQuery().Close;

    if PayCount > 0 then
    begin
      FLastError := Format('Cannot delete: customer has %d payment record(s).', [PayCount]);
      Result := False;
      Exit;
    end;

    { Atomic deletion: child table first, then person }
    Self.getQuery().SQL.Text := 'DELETE FROM customer WHERE person = :person';
    Self.getQuery().Params.ParamByName('person').AsInteger := customer.getId();
    Self.getQuery().ExecSQL;

    Self.getQuery().SQL.Text := 'DELETE FROM person WHERE id = :id';
    Self.getQuery().Params.ParamByName('id').AsInteger := customer.getId();
    Self.getQuery().ExecSQL;

    Result := True;
  except
    on E: Exception do
    begin
      FLastError := 'DB error during customer deletion: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TDataCustomer.get(customerId:Integer):TCustomer;
var
  person: TPerson;
  customer: TCustomer;
begin
  person := inherited get(customerId);
  if person <> nil then
  begin
    customer := TCustomer.Create;
    customer.setId(person.getId());
    customer.setAddress(person.getAddress());
    customer.setName(person.getName());
    customer.setTelephone(person.getTelephone());
    get := customer;
  end;
end;

end.
