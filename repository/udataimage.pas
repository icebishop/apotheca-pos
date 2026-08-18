unit UDataImage;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqlite3conn, SqlDb, UData;

type
  TDataImage = class(TData)
  public
    constructor Create(Connection: TSQLite3Connection);
    function Store(productId: Integer; const PngData: TBytes): Integer;
    function Update(imageId: Integer; const PngData: TBytes): Boolean;
    function Get(imageId: Integer): TBytes;
    function GetByProduct(productId: Integer): TBytes;
    function Delete(productId: Integer): Boolean;
  end;

implementation

constructor TDataImage.Create(Connection: TSQLite3Connection);
begin
  inherited Create(Connection);
end;

function TDataImage.Store(productId: Integer; const PngData: TBytes): Integer;
var
  stream: TBytesStream;
begin
  try
    stream := TBytesStream.Create(PngData);
    try
      Self.getQuery().SQL.Text :=
        'INSERT INTO images (product_id, data) VALUES (:product_id, :data)';
      Self.getQuery().Params.ParamByName('product_id').AsInteger := productId;
      Self.getQuery().Params.ParamByName('data').LoadFromStream(stream, ftBlob);
      Self.getQuery().ExecSQL;

      Self.getQuery().SQL.Text := 'SELECT last_insert_rowid() id';
      Self.getQuery().Open;
      Result := Self.getQuery().FieldByName('id').AsInteger;
      Self.getQuery().Close;
    finally
      stream.Free;
    end;
  except
    Result := 0;
  end;
end;

function TDataImage.Update(imageId: Integer; const PngData: TBytes): Boolean;
var
  stream: TBytesStream;
begin
  try
    stream := TBytesStream.Create(PngData);
    try
      Self.getQuery().SQL.Text :=
        'UPDATE images SET data = :data WHERE id = :id';
      Self.getQuery().Params.ParamByName('data').LoadFromStream(stream, ftBlob);
      Self.getQuery().Params.ParamByName('id').AsInteger := imageId;
      Self.getQuery().ExecSQL;
      Result := True;
    finally
      stream.Free;
    end;
  except
    Result := False;
  end;
end;

function TDataImage.Get(imageId: Integer): TBytes;
var
  stream: TMemoryStream;
  query: TSQLQuery;
begin
  Result := nil;
  try
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.SQL.Text := 'SELECT data FROM images WHERE id = :id';
      query.Params.ParamByName('id').AsInteger := imageId;
      query.Open;

      if not query.EOF then
      begin
        stream := TMemoryStream.Create;
        try
          TBlobField(query.FieldByName('data')).SaveToStream(stream);
          SetLength(Result, stream.Size);
          if stream.Size > 0 then
          begin
            stream.Position := 0;
            stream.Read(Result[0], stream.Size);
          end;
        finally
          stream.Free;
        end;
      end;

      query.Close;
    finally
      query.Free;
    end;
  except
    Result := nil;
  end;
end;

function TDataImage.GetByProduct(productId: Integer): TBytes;
var
  stream: TMemoryStream;
  query: TSQLQuery;
begin
  Result := nil;
  try
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.SQL.Text := 'SELECT data FROM images WHERE product_id = :product_id';
      query.Params.ParamByName('product_id').AsInteger := productId;
      query.Open;

      if not query.EOF then
      begin
        stream := TMemoryStream.Create;
        try
          TBlobField(query.FieldByName('data')).SaveToStream(stream);
          SetLength(Result, stream.Size);
          if stream.Size > 0 then
          begin
            stream.Position := 0;
            stream.Read(Result[0], stream.Size);
          end;
        finally
          stream.Free;
        end;
      end;

      query.Close;
    finally
      query.Free;
    end;
  except
    Result := nil;
  end;
end;

function TDataImage.Delete(productId: Integer): Boolean;
begin
  try
    Self.getQuery().SQL.Text :=
      'DELETE FROM images WHERE product_id = :product_id';
    Self.getQuery().Params.ParamByName('product_id').AsInteger := productId;
    Self.getQuery().ExecSQL;
    Result := True;
  except
    Result := False;
  end;
end;

end.
