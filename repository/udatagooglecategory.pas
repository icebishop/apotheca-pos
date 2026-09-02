{ Apothêca - Google product categories

  Repository for the google_category table (the list of Google product
  categories offered in the Product form's category combobox).

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UDataGoogleCategory;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, sqlite3conn, SqlDb, UData;

type
  { TDataGoogleCategory }

  TDataGoogleCategory = class(TData)
  public
    constructor Create(Connection: TSQLite3Connection);
    destructor Destroy; override;
    { All categories ordered alphabetically. Caller frees the list. }
    function FindAll(): TStringList;
    { Adds a category if it does not already exist. Returns True on success. }
    function EnsureExists(const Category: String): Boolean;
  end;

implementation

constructor TDataGoogleCategory.Create(Connection: TSQLite3Connection);
begin
  inherited Create(Connection);
end;

destructor TDataGoogleCategory.Destroy;
begin
  if Self.getQuery() <> nil then
    Self.getQuery().Free;
  inherited Destroy;
end;

function TDataGoogleCategory.FindAll(): TStringList;
var
  q: TSQLQuery;
begin
  Result := TStringList.Create;
  q := TSQLQuery.Create(nil);
  try
    q.DataBase := Self.getConnection();
    q.SQL.Text := 'SELECT category FROM google_category ORDER BY category';
    q.Open;
    while not q.EOF do
    begin
      Result.Add(q.FieldByName('category').AsString);
      q.Next;
    end;
    q.Close;
  finally
    q.Free;
  end;
end;

function TDataGoogleCategory.EnsureExists(const Category: String): Boolean;
begin
  Result := False;
  if Trim(Category) = '' then
    Exit;
  try
    Self.getQuery().SQL.Text :=
      'INSERT OR IGNORE INTO google_category (category) VALUES (:c)';
    Self.getQuery().Params.ParamByName('c').AsString := Category;
    Self.getQuery().ExecSQL;
    if Self.getTransaction() <> nil then
      Self.getTransaction().Commit;
    Result := True;
  except
    Result := False;
  end;
end;

end.
