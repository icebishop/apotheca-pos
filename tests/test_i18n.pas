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
  Check(RS_PEOPLE_GRID_PHONE, 'Teléfono', 'RS_PEOPLE_GRID_PHONE');
  Check(RS_PRODUCTS_GRID_STOCK, 'Stock', 'RS_PRODUCTS_GRID_STOCK');
  Check(RS_PURCHASE_GRID_UTILITY, '% Utilidad', 'RS_PURCHASE_GRID_UTILITY');
  Check(RS_REPORTS_VAL_COL_INV_VALUE, 'Valor Inventario', 'RS_REPORTS_VAL_COL_INV_VALUE');
  Check(RS_REPORTS_INCOME_TOTALS, 'TOTALES:', 'RS_REPORTS_INCOME_TOTALS');
  Check(RS_RETURNS_REBUILD, 'Reconstruir Saldos', 'RS_RETURNS_REBUILD');
  Check(Format(RS_PRODUCTS_DELETE_CONFIRM, ['X']), '¿Eliminar Producto: X?', 'RS_PRODUCTS_DELETE_CONFIRM');

  WriteLn;
  if Fails = 0 then
    WriteLn('ALL TRANSLATIONS OK')
  else
    WriteLn(Fails, ' TRANSLATION(S) FAILED');
  Halt(Fails);
end.
