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

unit UPngValidator;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TPngValidator = class(TObject)
  public
    class function IsValidPng(const Data: TBytes): Boolean;
    class function IsValidPngFile(const FilePath: String): Boolean;
    class function GetValidationError(const Data: TBytes): String;
  end;

implementation

const
  PNG_SIGNATURE: array[0..7] of Byte = ($89, $50, $4E, $47, $0D, $0A, $1A, $0A);

class function TPngValidator.IsValidPng(const Data: TBytes): Boolean;
var
  i: Integer;
begin
  Result := False;
  if Length(Data) < 8 then
    Exit;
  for i := 0 to 7 do
  begin
    if Data[i] <> PNG_SIGNATURE[i] then
      Exit;
  end;
  Result := True;
end;

class function TPngValidator.IsValidPngFile(const FilePath: String): Boolean;
var
  FS: TFileStream;
  Data: TBytes;
  BytesRead: Integer;
begin
  Result := False;
  if not FileExists(FilePath) then
    Exit;
  try
    FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyNone);
    try
      SetLength(Data, 8);
      BytesRead := FS.Read(Data[0], 8);
      if BytesRead < 8 then
      begin
        SetLength(Data, BytesRead);
        Result := False;
      end
      else
        Result := IsValidPng(Data);
    finally
      FS.Free;
    end;
  except
    Result := False;
  end;
end;

class function TPngValidator.GetValidationError(const Data: TBytes): String;
begin
  if Length(Data) = 0 then
  begin
    Result := 'The file is empty';
    Exit;
  end;
  if Length(Data) < 8 then
  begin
    Result := 'Invalid PNG signature: file too short';
    Exit;
  end;
  if not IsValidPng(Data) then
  begin
    Result := 'Only PNG format images are accepted';
    Exit;
  end;
  Result := '';
end;

end.
