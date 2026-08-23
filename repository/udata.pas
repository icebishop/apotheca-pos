unit UData;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, sqlite3conn, SqlDb, LazLogger;

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
var
  Trans: TSQLTransaction;
begin
  Self.setQuery(TSQLQuery.Create(nil));
  Self.SQLite3Connection := Connection;

  try
    { Ensure connection always has a usable transaction }
    if Connection.Transaction = nil then
    begin
      Trans := TSQLTransaction.Create(nil);
      Trans.DataBase := Connection;
      Connection.Transaction := Trans;
    end;
    { Ensure transaction is active }
    if not Connection.Transaction.Active then
      Connection.Transaction.StartTransaction;
  except
    on E: Exception do
      DebugLn('[TData.Create] ERROR setting up transaction: ' + E.Message);
  end;

  Self.Transaction := Connection.Transaction;
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
