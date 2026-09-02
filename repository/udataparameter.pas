{ Apothêca - Application parameters

  Repository for the parameters table (key/value application settings). Stores
  raw values as given (the service layer handles encryption for credential
  parameters). Follows the TData repository pattern (see udataimage.pas).

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UDataParameter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqlite3conn, SqlDb, fgl, UData;

type
  TParameterRecord = record
    Key: String;
    Value: String;         { raw stored value (may be encrypted ciphertext) }
    IsCredential: Boolean;
    Description: String;
  end;

  { Element object for parameter lists (records lack the '=' operator that
    TFPGList requires, so list elements are objects). }
  TParameterItem = class(TObject)
  public
    Key: String;
    Value: String;
    IsCredential: Boolean;
    Description: String;
  end;

  TParameterList = specialize TFPGObjectList<TParameterItem>;

  { TDataParameter }

  TDataParameter = class(TData)
  public
    constructor Create(Connection: TSQLite3Connection);
    destructor Destroy; override;

    function Exists(const Key: String): Boolean;
    function Get(const Key: String; out Rec: TParameterRecord): Boolean;
    { Upsert on key. Stores Value verbatim. Returns True on success. }
    function Upsert(const Rec: TParameterRecord): Boolean;
    { All parameters ordered by key. Caller frees the list. }
    function GetAll(): TParameterList;
  end;

implementation

constructor TDataParameter.Create(Connection: TSQLite3Connection);
begin
  inherited Create(Connection);
end;

destructor TDataParameter.Destroy;
begin
  if Self.getQuery() <> nil then
    Self.getQuery().Free;
  inherited Destroy;
end;

function TDataParameter.Exists(const Key: String): Boolean;
var
  q: TSQLQuery;
begin
  Result := False;
  q := TSQLQuery.Create(nil);
  try
    q.DataBase := Self.getConnection();
    q.SQL.Text := 'SELECT 1 FROM parameters WHERE key = :k';
    q.Params.ParamByName('k').AsString := Key;
    q.Open;
    Result := not q.EOF;
    q.Close;
  finally
    q.Free;
  end;
end;

function TDataParameter.Get(const Key: String; out Rec: TParameterRecord): Boolean;
var
  q: TSQLQuery;
begin
  Result := False;
  Rec.Key := Key;
  Rec.Value := '';
  Rec.IsCredential := False;
  Rec.Description := '';
  q := TSQLQuery.Create(nil);
  try
    q.DataBase := Self.getConnection();
    q.SQL.Text := 'SELECT key, value, is_credential, description ' +
                  'FROM parameters WHERE key = :k';
    q.Params.ParamByName('k').AsString := Key;
    q.Open;
    if not q.EOF then
    begin
      Rec.Key := q.FieldByName('key').AsString;
      Rec.Value := q.FieldByName('value').AsString;
      Rec.IsCredential := q.FieldByName('is_credential').AsInteger <> 0;
      Rec.Description := q.FieldByName('description').AsString;
      Result := True;
    end;
    q.Close;
  finally
    q.Free;
  end;
end;

function TDataParameter.Upsert(const Rec: TParameterRecord): Boolean;
begin
  Result := False;
  try
    Self.getQuery().SQL.Text :=
      'INSERT INTO parameters (key, value, is_credential, description) ' +
      'VALUES (:k, :v, :c, :d) ' +
      'ON CONFLICT(key) DO UPDATE SET ' +
      '  value = excluded.value, ' +
      '  is_credential = excluded.is_credential, ' +
      '  description = excluded.description';
    Self.getQuery().Params.ParamByName('k').AsString := Rec.Key;
    Self.getQuery().Params.ParamByName('v').AsString := Rec.Value;
    Self.getQuery().Params.ParamByName('c').AsInteger := Ord(Rec.IsCredential);
    Self.getQuery().Params.ParamByName('d').AsString := Rec.Description;
    Self.getQuery().ExecSQL;
    if Self.getTransaction() <> nil then
      Self.getTransaction().Commit;
    Result := True;
  except
    Result := False;
  end;
end;

function TDataParameter.GetAll(): TParameterList;
var
  q: TSQLQuery;
  Item: TParameterItem;
begin
  Result := TParameterList.Create(True);  { owns items }
  q := TSQLQuery.Create(nil);
  try
    q.DataBase := Self.getConnection();
    q.SQL.Text := 'SELECT key, value, is_credential, description ' +
                  'FROM parameters ORDER BY key';
    q.Open;
    while not q.EOF do
    begin
      Item := TParameterItem.Create;
      Item.Key := q.FieldByName('key').AsString;
      Item.Value := q.FieldByName('value').AsString;
      Item.IsCredential := q.FieldByName('is_credential').AsInteger <> 0;
      Item.Description := q.FieldByName('description').AsString;
      Result.Add(Item);
      q.Next;
    end;
    q.Close;
  finally
    q.Free;
  end;
end;

end.
