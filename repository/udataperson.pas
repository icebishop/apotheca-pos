unit UDataPerson;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, sqlite3conn, SqlDb, UPerson, UData;

type
TDataPerson = class(TData)


public // access by anything
function find(name:String):TList;
function new(person:TPerson):Integer;
function edit(person:TPerson):Boolean;
function get(personId:Integer):TPerson;{
        function delete(person:Tperson):Boolean;
        procedure setConnection(Connection: TSQLite3Connection);
         }

end;

implementation

function TDataPerson.find(name:String):TList;
var
listPerson:TList;
begin
try
Self.getQuery().SQL.Text := 'select * from person ';
if name <> '' then
begin
Self.getQuery().SQL.Text := Self.getQuery().SQL.Text + 'where name like :name';
Self.getQuery().Params.ParamByName('name').AsString := name;
end;
Self.getQuery().Open;

listPerson := TList.Create;
Self.getQuery().First;
while not Self.getQuery().EOF do
begin
listPerson.Add(Self.get(Self.getQuery().FieldByName('id').AsInteger));
Self.getQuery().Next;
end;
Self.getQuery().Close;
find := listPerson;
except
find := nil;
end;
end;

function TDataPerson.new(person:TPerson):Integer;
begin
try
Self.getQuery().SQL.Text := 'insert into person('+
'	name,'+
'	telephone,'+
'	address)'+
' values (:name,'+
' :telephone,'+
'	:address)';

Self.getQuery().Params.ParamByName('name').AsString := person.getName();
Self.getQuery().Params.ParamByName('telephone').AsString := person.getTelephone();
Self.getQuery().Params.ParamByName('address').AsString := person.getAddress();

Self.getQuery().ExecSQL;
Self.getQuery().SQL.Text:= 'SELECT last_insert_rowid() id';
Self.getQuery().Open;
while not Self.getQuery().EOF do
begin
person.setId(Self.getQuery().FieldByName('id').AsInteger);
Self.getQuery().Next;
end;

new := person.getId();
Self.getQuery().Close;

except
new := 0;
end;
end;

function TDataPerson.edit(person:TPerson):Boolean;
begin
try
Self.getConnection().Transaction := Self.getTransaction();
Self.getQuery().DataBase := Self.getConnection();
Self.getQuery().SQL.Text := 'update person '+
'   set name = :name,'+
'       telephone = :telephone,'+
'       address = :address'+
'  where id = :id';
Self.getQuery().Params.ParamByName('name').AsString := person.getName();
Self.getQuery().Params.ParamByName('telephone').AsString := person.getTelephone();
Self.getQuery().Params.ParamByName('address').AsString := person.getAddress();
Self.getQuery().Params.ParamByName('id').AsInteger := person.getId();

Self.getQuery().ExecSQL;
Self.getQuery().Close;
edit := true;
except
edit := false;
end;
end;

function TDataPerson.get(personId:Integer):TPerson;
var
person : TPerson;
query: TSQLQuery;
begin
try
query := TSQLQuery.Create(nil);
query.DataBase := self.getConnection();
query.SQL.Text := 'select * from person where id = :id';
query.Params.ParamByName('id').AsInteger := personId;
query.Open;

person := TPerson.Create;
query.First;
while not query.EOF do
begin
person := TPerson.Create;
person.setId(query.FieldByName('id').AsInteger);
person.setName(query.FieldByName('name').AsString);
person.setTelephone(query.FieldByName('telephone').AsString);
person.setAddress(query.FieldByName('address').AsString);
query.Next;
end;
query.Close;
get := Person;
except
get := nil;
end;

end;

end.
