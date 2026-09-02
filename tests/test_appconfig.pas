program test_appconfig;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, UAppConfig;

var
  Fails: Integer = 0;
  ConfPath: String;

  procedure Check(const Cond: Boolean; const Label_: String);
  begin
    if Cond then WriteLn('OK   ', Label_)
    else begin WriteLn('FAIL ', Label_); Inc(Fails); end;
  end;

begin
  ConfPath := ExtractFilePath(ParamStr(0)) + APP_CONFIG_FILE;
  { start clean }
  if FileExists(ConfPath) then DeleteFile(ConfPath);

  { 1. missing config returns default }
  Check(TAppConfig.GetDbFile('/default/db') = '/default/db', 'missing config -> default');

  { 2. set + get db.file }
  Check(TAppConfig.SetDbFile('/tmp/mydb.sqlite'), 'SetDbFile writes ok');
  Check(FileExists(ConfPath), 'config file created');
  Check(TAppConfig.GetDbFile('/default/db') = '/tmp/mydb.sqlite', 'GetDbFile returns stored value');

  { 3. set an unrelated key, ensure db.file survives (preserve other keys) }
  Check(TAppConfig.SetValue('other.key', 'xyz'), 'SetValue other key');
  Check(TAppConfig.GetDbFile('/d') = '/tmp/mydb.sqlite', 'db.file preserved after other write');
  Check(TAppConfig.GetValue('other.key', '') = 'xyz', 'other.key readable');

  { 4. overwrite db.file }
  Check(TAppConfig.SetDbFile('/var/data/invcar'), 'overwrite db.file');
  Check(TAppConfig.GetDbFile('/d') = '/var/data/invcar', 'db.file overwritten');
  Check(TAppConfig.GetValue('other.key', '') = 'xyz', 'other.key still there after overwrite');

  { cleanup }
  DeleteFile(ConfPath);

  WriteLn;
  if Fails = 0 then WriteLn('ALL APPCONFIG TESTS OK')
  else WriteLn(Fails, ' TEST(S) FAILED');
  Halt(Fails);
end.
