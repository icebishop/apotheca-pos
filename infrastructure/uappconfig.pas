{ Apothêca - Application bootstrap configuration

  Stores settings that must be known BEFORE the database is opened - primarily
  the database file path (db.file). These cannot live in the SQLite parameters
  table (chicken-and-egg: the path is needed to open the very database that
  would hold it), so they are kept in a small KEY=VALUE file next to the
  executable (apotheca.conf).

  All OTHER application parameters continue to live in the parameters table via
  TSettingsService.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UAppConfig;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

const
  { Config file name, resolved relative to the executable. }
  APP_CONFIG_FILE = 'apotheca.conf';
  { Key for the database file path inside the config file. }
  CFG_DB_FILE = 'db.file';

type
  { TAppConfig - reads/writes the exe-relative apotheca.conf KEY=VALUE file. }
  TAppConfig = class(TObject)
  private
    class function ConfigPath: String; static;
    class function ReadAll: TStringList; static;
  public
    { Returns the value for Key, or ADefault when missing/empty. }
    class function GetValue(const Key, ADefault: String): String; static;
    { Writes Key=Value to the config file, preserving other keys. Returns True
      on success. }
    class function SetValue(const Key, Value: String): Boolean; static;

    { Convenience accessors for the database file path. }
    class function GetDbFile(const ADefault: String): String; static;
    class function SetDbFile(const Path: String): Boolean; static;
  end;

implementation

class function TAppConfig.ConfigPath: String;
begin
  Result := ExtractFilePath(ParamStr(0)) + APP_CONFIG_FILE;
end;

{ Load the config file into a name=value TStringList. Blank lines and lines
  starting with '#' are ignored. Caller owns the returned list. }
class function TAppConfig.ReadAll: TStringList;
var
  Raw: TStringList;
  i, EqPos: Integer;
  Line, Key, Value, Path: String;
begin
  Result := TStringList.Create;
  Path := ConfigPath;
  if not FileExists(Path) then
    Exit;

  Raw := TStringList.Create;
  try
    Raw.LoadFromFile(Path);
    for i := 0 to Raw.Count - 1 do
    begin
      Line := Trim(Raw[i]);
      if (Line = '') or (Line[1] = '#') then
        Continue;
      EqPos := Pos('=', Line);
      if EqPos <= 1 then
        Continue;
      Key := Trim(Copy(Line, 1, EqPos - 1));
      Value := Trim(Copy(Line, EqPos + 1, Length(Line) - EqPos));
      if Key = '' then
        Continue;
      Result.Values[Key] := Value;
    end;
  finally
    Raw.Free;
  end;
end;

class function TAppConfig.GetValue(const Key, ADefault: String): String;
var
  Cfg: TStringList;
begin
  Cfg := ReadAll;
  try
    Result := Trim(Cfg.Values[Key]);
    if Result = '' then
      Result := ADefault;
  finally
    Cfg.Free;
  end;
end;

class function TAppConfig.SetValue(const Key, Value: String): Boolean;
var
  Cfg: TStringList;
begin
  Result := False;
  Cfg := ReadAll;
  try
    Cfg.Values[Key] := Value;
    try
      Cfg.SaveToFile(ConfigPath);
      Result := True;
    except
      on E: Exception do
        Result := False;
    end;
  finally
    Cfg.Free;
  end;
end;

class function TAppConfig.GetDbFile(const ADefault: String): String;
begin
  Result := GetValue(CFG_DB_FILE, ADefault);
end;

class function TAppConfig.SetDbFile(const Path: String): Boolean;
begin
  Result := SetValue(CFG_DB_FILE, Path);
end;

end.
