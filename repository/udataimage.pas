unit UDataImage;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqlite3conn, SqlDb, UData, LazLogger;

type
  TDataImage = class(TData)
  public
    constructor Create(Connection: TSQLite3Connection);
    { Writes PngData to disk as <ImageDir>/<product_id>_<position>.png,
      inserts a row in images (filename only, no BLOB), returns the new id.
      ImageDir must end without a trailing separator. }
    function Store(productId: Integer; const PngData: TBytes;
                   const ImageDir: String): Integer;
    { Overwrites the file on disk and updates the filename in the DB row. }
    function Update(imageId: Integer; const PngData: TBytes;
                    const ImageDir: String): Boolean;
    { Loads image bytes from disk using the filename stored in the DB row.
      ImageDir is the base directory. Returns nil on any error. }
    function Get(imageId: Integer; const ImageDir: String): TBytes;
    { Returns bytes for the first (position=0) image of a product. }
    function GetByProduct(productId: Integer; const ImageDir: String): TBytes;
    { Returns the ids of every image belonging to a product, ordered by their
      stored position (then id). Caller owns the returned list. }
    function GetIdsByProduct(productId: Integer): TList;
    { Returns the filename stored in the DB for a given image id. }
    function GetFilename(imageId: Integer): String;
    { Returns all filenames for a product, ordered by position. }
    function GetFilenamesByProduct(productId: Integer): TStringList;
    { Deletes a single image row (does NOT remove the file from disk). }
    function DeleteImage(imageId: Integer): Boolean;
    { Deletes all image rows for a product (does NOT remove files from disk). }
    function Delete(productId: Integer): Boolean;
  private
    { Next free position for a product (max(position)+1, starting at 0). }
    function NextPosition(productId: Integer): Integer;
    { Derives the filename for a new image: <product_id>_<position>.png }
    function BuildFilename(productId, position: Integer): String;
  end;

implementation

constructor TDataImage.Create(Connection: TSQLite3Connection);
begin
  inherited Create(Connection);
end;

function TDataImage.NextPosition(productId: Integer): Integer;
var
  query: TSQLQuery;
begin
  Result := 0;
  try
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.Transaction := Self.getConnection().Transaction;
      query.SQL.Text :=
        'SELECT COALESCE(MAX(position), -1) + 1 AS nextpos ' +
        'FROM images WHERE product_id = :product_id';
      query.Params.ParamByName('product_id').AsInteger := productId;
      query.Open;
      if not query.EOF then
        Result := query.FieldByName('nextpos').AsInteger;
      query.Close;
    finally
      query.Free;
    end;
  except
    Result := 0;
  end;
end;

function TDataImage.BuildFilename(productId, position: Integer): String;
begin
  Result := IntToStr(productId) + '_' + IntToStr(position) + '.png';
end;

{ --- Store ------------------------------------------------------------------ }

function TDataImage.Store(productId: Integer; const PngData: TBytes;
                          const ImageDir: String): Integer;
var
  position: Integer;
  filename, filePath: String;
  fs: TFileStream;
begin
  Result := 0;
  try
    position := NextPosition(productId);
    filename  := BuildFilename(productId, position);
    filePath  := IncludeTrailingPathDelimiter(ImageDir) + filename;

    { Write image file to disk. }
    if not DirectoryExists(ImageDir) then
      ForceDirectories(ImageDir);

    fs := TFileStream.Create(filePath, fmCreate);
    try
      if Length(PngData) > 0 then
        fs.Write(PngData[0], Length(PngData));
    finally
      fs.Free;
    end;

    { Insert DB row with filename only (no BLOB). }
    Self.getQuery().SQL.Text :=
      'INSERT INTO images (product_id, position, filename) ' +
      'VALUES (:product_id, :position, :filename)';
    Self.getQuery().Params.ParamByName('product_id').AsInteger := productId;
    Self.getQuery().Params.ParamByName('position').AsInteger   := position;
    Self.getQuery().Params.ParamByName('filename').AsString    := filename;
    Self.getQuery().ExecSQL;

    Self.getQuery().SQL.Text := 'SELECT last_insert_rowid() id';
    Self.getQuery().Open;
    Result := Self.getQuery().FieldByName('id').AsInteger;
    Self.getQuery().Close;
  except
    on E: Exception do
      Result := 0;
  end;
end;

{ --- Update ----------------------------------------------------------------- }

function TDataImage.Update(imageId: Integer; const PngData: TBytes;
                           const ImageDir: String): Boolean;
var
  existingFilename, filePath: String;
  fs: TFileStream;
  query: TSQLQuery;
begin
  Result := False;
  try
    { Look up the existing filename to overwrite the same file on disk. }
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.Transaction := Self.getConnection().Transaction;
      query.SQL.Text := 'SELECT filename FROM images WHERE id = :id';
      query.Params.ParamByName('id').AsInteger := imageId;
      query.Open;
      if query.EOF then
        Exit;
      existingFilename := query.FieldByName('filename').AsString;
      query.Close;
    finally
      query.Free;
    end;

    if existingFilename = '' then
      Exit;

    filePath := IncludeTrailingPathDelimiter(ImageDir) + existingFilename;

    { Overwrite file on disk. }
    fs := TFileStream.Create(filePath, fmCreate);
    try
      if Length(PngData) > 0 then
        fs.Write(PngData[0], Length(PngData));
    finally
      fs.Free;
    end;

    { filename stays the same; no DB update needed. }
    Result := True;
  except
    Result := False;
  end;
end;

{ --- Get -------------------------------------------------------------------- }

function TDataImage.Get(imageId: Integer; const ImageDir: String): TBytes;
var
  filename, filePath: String;
  query: TSQLQuery;
  fs: TFileStream;
begin
  Result := nil;
  try
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.Transaction := Self.getConnection().Transaction;
      query.SQL.Text := 'SELECT filename FROM images WHERE id = :id';
      query.Params.ParamByName('id').AsInteger := imageId;
      query.Open;
      if query.EOF then
      begin
        DebugLn('[TDataImage.Get] no row for id=' + IntToStr(imageId));
        Exit;
      end;
      filename := query.FieldByName('filename').AsString;
      query.Close;
    finally
      query.Free;
    end;

    DebugLn('[TDataImage.Get] id=' + IntToStr(imageId)
      + ' filename=' + filename + ' imageDir=' + ImageDir);

    if filename = '' then
    begin
      DebugLn('[TDataImage.Get] empty filename for id=' + IntToStr(imageId));
      Exit;
    end;

    filePath := IncludeTrailingPathDelimiter(ImageDir) + filename;
    if not FileExists(filePath) then
    begin
      DebugLn('[TDataImage.Get] file not found: ' + filePath);
      Exit;
    end;

    fs := TFileStream.Create(filePath, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Result, fs.Size);
      if fs.Size > 0 then
        fs.Read(Result[0], fs.Size);
      DebugLn('[TDataImage.Get] loaded ' + IntToStr(fs.Size) + ' bytes from ' + filePath);
    finally
      fs.Free;
    end;
  except
    on E: Exception do
    begin
      DebugLn('[TDataImage.Get] EXCEPTION id=' + IntToStr(imageId) + ' ' + E.Message);
      Result := nil;
    end;
  end;
end;

{ --- GetByProduct ----------------------------------------------------------- }

function TDataImage.GetByProduct(productId: Integer;
                                 const ImageDir: String): TBytes;
var
  filename, filePath: String;
  query: TSQLQuery;
  fs: TFileStream;
begin
  Result := nil;
  try
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.Transaction := Self.getConnection().Transaction;
      query.SQL.Text :=
        'SELECT filename FROM images WHERE product_id = :product_id ' +
        'ORDER BY position, id LIMIT 1';
      query.Params.ParamByName('product_id').AsInteger := productId;
      query.Open;
      if query.EOF then
        Exit;
      filename := query.FieldByName('filename').AsString;
      query.Close;
    finally
      query.Free;
    end;

    if filename = '' then
      Exit;

    filePath := IncludeTrailingPathDelimiter(ImageDir) + filename;
    if not FileExists(filePath) then
      Exit;

    fs := TFileStream.Create(filePath, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Result, fs.Size);
      if fs.Size > 0 then
        fs.Read(Result[0], fs.Size);
    finally
      fs.Free;
    end;
  except
    Result := nil;
  end;
end;

{ --- GetIdsByProduct -------------------------------------------------------- }

function TDataImage.GetIdsByProduct(productId: Integer): TList;
var
  query: TSQLQuery;
  ids: TList;
begin
  ids := TList.Create;
  try
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.Transaction := Self.getConnection().Transaction;
      query.SQL.Text :=
        'SELECT id FROM images WHERE product_id = :product_id ' +
        'ORDER BY position, id';
      query.Params.ParamByName('product_id').AsInteger := productId;
      query.Open;
      while not query.EOF do
      begin
        ids.Add(Pointer(PtrInt(query.FieldByName('id').AsInteger)));
        query.Next;
      end;
      query.Close;
    finally
      query.Free;
    end;
  except
    { Return whatever was gathered (possibly empty) on error. }
  end;
  Result := ids;
end;

{ --- GetFilename ------------------------------------------------------------ }

function TDataImage.GetFilename(imageId: Integer): String;
var
  query: TSQLQuery;
begin
  Result := '';
  try
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.Transaction := Self.getConnection().Transaction;
      query.SQL.Text := 'SELECT filename FROM images WHERE id = :id';
      query.Params.ParamByName('id').AsInteger := imageId;
      query.Open;
      if not query.EOF then
        Result := query.FieldByName('filename').AsString;
      query.Close;
    finally
      query.Free;
    end;
  except
    Result := '';
  end;
end;

{ --- GetFilenamesByProduct -------------------------------------------------- }

function TDataImage.GetFilenamesByProduct(productId: Integer): TStringList;
var
  query: TSQLQuery;
begin
  Result := TStringList.Create;
  try
    query := TSQLQuery.Create(nil);
    try
      query.DataBase := Self.getConnection();
      query.Transaction := Self.getConnection().Transaction;
      query.SQL.Text :=
        'SELECT filename FROM images WHERE product_id = :product_id ' +
        'ORDER BY position, id';
      query.Params.ParamByName('product_id').AsInteger := productId;
      query.Open;
      while not query.EOF do
      begin
        Result.Add(query.FieldByName('filename').AsString);
        query.Next;
      end;
      query.Close;
    finally
      query.Free;
    end;
  except
    { Return whatever was gathered. }
  end;
end;

{ --- DeleteImage ------------------------------------------------------------ }

function TDataImage.DeleteImage(imageId: Integer): Boolean;
begin
  try
    Self.getQuery().SQL.Text := 'DELETE FROM images WHERE id = :id';
    Self.getQuery().Params.ParamByName('id').AsInteger := imageId;
    Self.getQuery().ExecSQL;
    Result := True;
  except
    Result := False;
  end;
end;

{ --- Delete ----------------------------------------------------------------- }

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
