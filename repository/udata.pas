unit UData;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, sqlite3conn, SqlDb;

type
TData = class(TObject)
private // self access only
Query: TSQLQuery;
Transaction: TSQLTransaction;
SQLite3Connection: TSQLite3Connection;
public
Constructor Create(Connection: TSQLite3Connection);

procedure setQuery(sqlQuery: TSQLQuery);
procedure free();
procedure setTransaction(sqlTransaction:TSQLTransaction);

function getConnection():TSQLite3Connection;
function getQuery():TSQLQuery;
function getTransaction():TSQLTransaction;


end;

implementation

Constructor TData.Create(Connection: TSQLite3Connection);
begin
Self.setQuery(TSQLQuery.Create(nil));
self.SQLite3Connection := Connection;
Self.Transaction := Self.SQLite3Connection.Transaction;
Self.getQuery().DataBase := Connection;
end;

procedure TData.setQuery(sqlQuery: TSQLQuery);
begin
Self.Query := sqlQuery;
end;

procedure TData.setTransaction(sqlTransaction:TSQLTransaction);
begin
Self.Transaction := sqlTransaction;
end;

function TData.getConnection():TSQLite3Connection;
begin
getConnection := Self.SQLite3Connection;
end;

function TData.getQuery():TSQLQuery;
begin
getQuery := Self.Query;
end;

function TData.getTransaction():TSQLTransaction;
begin
getTransaction := Self.Transaction;
end;

procedure TData.free();
begin
Self.getTransaction().Free;
Self.getQuery().Free;
end;



end.
