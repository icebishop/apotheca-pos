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

unit UWebPConverter;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, FileUtil;

type
  TWebPConverter = class(TObject)
  private
    FCwebpPath: String;
    FLastError: String;
    function FindCwebp(): String;
  public
    constructor Create;
    function Convert(const PngData: TBytes; const OutputDir: String;
                     const NormalizedName: String; Quality: Integer = 80): Boolean;
    function GetLastError(): String;
    class function NormalizeProductName(const Name: String): String;
  end;

implementation

constructor TWebPConverter.Create;
begin
  inherited Create;
  FLastError := '';
  FCwebpPath := FindCwebp();
end;

function TWebPConverter.FindCwebp(): String;
begin
  Result := FindDefaultExecutablePath('cwebp');
end;

class function TWebPConverter.NormalizeProductName(const Name: String): String;
var
  i: Integer;
  LowerName: String;
  Ch: Char;
begin
  LowerName := LowerCase(Name);
  Result := '';
  for i := 1 to Length(LowerName) do
  begin
    Ch := LowerName[i];
    if ((Ch >= 'a') and (Ch <= 'z')) or ((Ch >= '0') and (Ch <= '9')) then
      Result := Result + Ch
    else
      Result := Result + '-';
  end;
end;

function TWebPConverter.Convert(const PngData: TBytes; const OutputDir: String;
                                const NormalizedName: String; Quality: Integer): Boolean;
var
  TempFile: String;
  OutputFile: String;
  AProcess: TProcess;
  FS: TFileStream;
begin
  Result := False;
  FLastError := '';

  if FCwebpPath = '' then
  begin
    FLastError := 'cwebp executable not found in PATH';
    Exit;
  end;

  if Length(PngData) = 0 then
  begin
    FLastError := 'PNG data is empty';
    Exit;
  end;

  TempFile := IncludeTrailingPathDelimiter(OutputDir) + NormalizedName + '_tmp.png';
  OutputFile := IncludeTrailingPathDelimiter(OutputDir) + NormalizedName + '.webp';

  // Write PngData to temp file
  try
    FS := TFileStream.Create(TempFile, fmCreate);
    try
      FS.Write(PngData[0], Length(PngData));
    finally
      FS.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to write temp PNG file: ' + E.Message;
      Exit;
    end;
  end;

  // Invoke cwebp
  try
    AProcess := TProcess.Create(nil);
    try
      AProcess.Executable := FCwebpPath;
      AProcess.Parameters.Add('-q');
      AProcess.Parameters.Add(IntToStr(Quality));
      AProcess.Parameters.Add(TempFile);
      AProcess.Parameters.Add('-o');
      AProcess.Parameters.Add(OutputFile);
      AProcess.Options := [poWaitOnExit, poUsePipes];
      AProcess.Execute;

      if AProcess.ExitStatus = 0 then
        Result := True
      else
        FLastError := 'cwebp exited with code ' + IntToStr(AProcess.ExitStatus);
    finally
      AProcess.Free;
    end;
  except
    on E: Exception do
    begin
      FLastError := 'Failed to execute cwebp: ' + E.Message;
    end;
  end;

  // Delete temp file
  if FileExists(TempFile) then
    DeleteFile(TempFile);
end;

function TWebPConverter.GetLastError(): String;
begin
  Result := FLastError;
end;

end.
