program test_i18n;

{$mode objfpc}{$H+}

uses
  SysUtils, Translations, UResourceString;

var
  POFile: String;
  Fails: Integer = 0;

  procedure Check(const Got, Expected, Label_: String);
  begin
    if Got = Expected then
      WriteLn('OK   ', Label_, ' = "', Got, '"')
    else
    begin
      WriteLn('FAIL ', Label_, ' got "', Got, '" expected "', Expected, '"');
      Inc(Fails);
    end;
  end;

begin
  POFile := ExtractFilePath(ParamStr(0)) + 'languages/es/apotheca.es.po';
  if not FileExists(POFile) then
    POFile := 'languages/es/apotheca.es.po';
  WriteLn('Loading: ', POFile, '  exists=', FileExists(POFile));

  TranslateUnitResourceStrings('UResourceString', POFile);

  Check(RS_LCUSTOMER, 'Cliente', 'RS_LCUSTOMER');
  Check(RS_NAV_SETTINGS, 'Configuración', 'RS_NAV_SETTINGS');
  Check(RS_NAV_SALES, 'Ventas', 'RS_NAV_SALES');
  Check(RS_EXPORT_UPDATE_CATALOG, 'Actualizar Catálogo Web', 'RS_EXPORT_UPDATE_CATALOG');
  Check(RS_SETTINGS_BTN_SAVE, 'Guardar', 'RS_SETTINGS_BTN_SAVE');
  Check(RS_PUBPREVIEW_TITLE, 'Confirmar Publicación en Instagram', 'RS_PUBPREVIEW_TITLE');

  WriteLn;
  if Fails = 0 then
    WriteLn('ALL TRANSLATIONS OK')
  else
    WriteLn(Fails, ' TRANSLATION(S) FAILED');
  Halt(Fails);
end.
