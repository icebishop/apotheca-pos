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

unit UResourceString;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils;

resourcestring

RS_FMAINDELETECUSTOMER = 'Delete Customer';
RS_FMAINDELETEPAY = 'Delete Payment';
RS_FMAINDELETEPURCHASE = 'Delete Purchase';
RS_FMAINDELETESALE = 'Delete Sale';
RS_FMAINDELETESUPPLIER = 'Delete Supplier';
RS_FMAINEDITCUSTOMER = 'Edit Customer';
RS_FMAINEDITPAY = 'Edit Payment';
RS_FMAINEDITPURCHASE = 'Edit Purchase';
RS_FMAINEDITSALE = 'Edit Sale';
RS_FMAINEDITSUPPLIER = 'Edit Supplier';
RS_FMAINMENUPAY = 'P&ayment';
RS_FMAINMENUSALE = '&Sale';
RS_FMAINNEWCUSTOMER = 'New Customer';
RS_FMAINNEWPA = 'New Sale';
RS_FMAINNEWPAY = 'New Payment';
RS_FMAINNEWPURCHASE = 'New Purchase';
RS_FMAINNEWSALE = 'New Sale';
RS_FMAINNEWSUPPLIER = 'New Supplier';
RS_LADDRESS = 'Address';
RS_LCUSTOMER = 'Customer';
RS_LCUSTOMERS = 'Customers';
RS_LDATE = 'Date';
RS_LDESCRIPTION = 'Description';
RS_LFINDCUSTOMERS = 'Find Customers';
RS_LFINDPAY = 'Find Payments';
RS_LFINDPRODUCTS = 'Find Products';
RS_LMAXSTOCK = 'Max Stock';
RS_LMINSTOCK = 'Min Stock';
RS_LNAME = 'Name';
RS_LPRODUCTS = 'Products';
RS_LTELEPHONE = 'Telephone';
RS_LVALUE = 'Value';
RS_LSALES = 'Sales';
RS_LTOTAL = 'Total';

RS_MSGCUSTOMER = 'Customer';
RS_MSGMORETHAN0 = '%sValue must be greater than 0%s';
RS_MSGSUPPLIER = 'Supplier';
RS_MSGVALCBOX = 'Are you sure you want to perform this operation?';
RS_MSGVALDATE = '%sYou must select a date';
RS_MSGVALITEMS = '%sYou must include Products%s';
RS_MSGVALLISTITEMS = 'The product list has the following errors: %s';
RS_MSGVALNUMERIC = '%sValue must be numeric%s';
RS_MSGVALNUMITEM = '%sItem No%s';
RS_MSGVALPAYCUST = '%sPayment must have a customer%s';
RS_MSGVALPAYDATE = '%sPayment must have a date%s';
RS_MSGVALPAYVALUE = '%sPayment must be greater than 0%s';
RS_MSGVALPERADDRESS = '%s%s must have an address%s';
RS_MSGVALPERNAME = '%s%s must have a name%s';
RS_MSGVALPERSON = '%sYou must select a Supplier/Customer';
RS_FMAIN = 'Apothêca';
RS_FMAINMENUOPEN = '&Open';
RS_FMAINMENUNEW = '&New';
RS_FMAINMENUFILE = '&File';
RS_FMAINMENUCLOSE = '&Close';
RS_FMAINMENUEDIT = '&Edit';
RS_FMAINMENUMODIFY = '&Modify';
RS_FMAINMENUDELETE = '&Delete';
RS_FMAINMENUCUSTOMER = '&Customer';
RS_FMAINMENUSUPPLIER = '&Supplier';
RS_FMAINMENUPRODUCTO = 'Pr&oduct';
RS_FMAINMENUPURCHASE = '&Purchase';
RS_FMAINTABCUSTOMER = '&Customers';
RS_FMAINTABPRODUCT = '&Products';
RS_FMAINSTRINGGRID100 = 'ID';
RS_FMAINSTRINGGRID110 = 'Name';
RS_FMAINSTRINGGRID120 = 'Last Purchase';
RS_FMAINSTRINGGRID130 = 'Last Payment';
RS_FMAINSTRINGGRID140 = 'Paid';
RS_FMAINSTRINGGRID150 = 'Balance';
RS_FMAINSTRINGGRID200 = 'ID';
RS_FMAINSTRINGGRID210 = 'Name';
RS_FMAINSTRINGGRID220 = 'Unit Price';
RS_FMAINSTRINGGRID230 = 'Quantity';
RS_FMAINSTRINGGRID240 = 'Cost';
RS_FMAINSTRINGGRID250 = 'Price';
RS_FMAINSTRINGGRID260 = 'Sale Price';
RS_FMAINMENUHELP      = '&Help';
RS_FMAINMENUABOUT     = '&About';
RS_FMAINMENUHELPINDEX = '&Help Index';

RS_FIND = '&Find';
RS_MSGVALPERTEL = '%s%s must have a telephone number%s';
RS_MSGVALPRODMAXSTOCK =
'%sMax stock must be greater than min stock';
RS_MSGVALPRODMINSTOCK = '%sProduct must have a minimum stock';
RS_MSGVALPRODNAME = '%sProduct must have a Name';
RS_MSGVALPRODSTOCK = '%sOnly %s units of product %s are available';
RS_MSGWARNING = 'Warning';

//Buttons
RS_OK = '&OK';
RS_CANCEL = '&Cancel';
RS_NEW = '&New';
RS_ADD = '&Add';
RS_DELETE = '&Delete';

//Message Box
RS_OBJECTNOTSAVE = 'Object was not saved';
RS_OBJECTSAVE = 'Object was saved';
RS_MESSAGE = 'Message';
RS_Error = 'Error';

//Tabs
RS_TABCUSTOMER = 'Customers';
RS_TABPRODUCT = 'Products';
RS_FMAINSTRINGGRID340 = 'Product';
RS_FFINDSUPPLIER = 'Find Supplier';
RS_LSUPPLIERS = 'Suppliers';
RS_LNUMBER = 'Number';
RS_LDETAIL = 'Detail';
RS_FFINDTRANSACTION = 'Find Transaction';


//Dialogs
RS_DIALOGPURCHASE = 'Purchases';
RS_ITEMVALIDATORPRODUCT = '%sProduct: %s';
RS_ITEMVALIDATORPRODUCTSELECT = '%s You must select a product';
RS_ITEMVALIDATORPRODUCTCOST = '%s You must specify the product cost';
RS_ITEMVALIDATORPRODUCTPRICE = '%s You must specify the product price';
RS_ITEMVALIDATORPRODUCTSTOCK = '%s You must specify the product quantity';

// Sidebar navigation
RS_NAV_SALES = 'Sales';
RS_NAV_CREDITS = 'Credits';
RS_NAV_PURCHASES = 'Purchases';
RS_NAV_PRODUCTS = 'Products';
RS_NAV_PEOPLE = 'People';
RS_NAV_REPORTS = 'Reports';

// POS frame
RS_POS_SEARCH_HINT = 'Search product...';
RS_POS_CUSTOMER_HINT = 'Customer...';
RS_POS_SELECT_CUSTOMER = 'Sel. Customer';
RS_POS_COMPLETE_SALE = 'Complete Sale';
RS_POS_TOTAL = 'Total: $%s';
RS_POS_GRID_PRODUCT = 'Product';
RS_POS_GRID_PRICE = 'Unit Price';
RS_POS_GRID_QTY = 'Quantity';
RS_POS_GRID_LINETOTAL = 'Line Total';
RS_POS_CART_EMPTY = 'You must add at least one product to the cart';
RS_POS_NO_CUSTOMER = 'You must select a customer';
RS_POS_CREDIT_NO_CUSTOMER = 'You must select a customer for credit sales';

// Purchase frame
RS_PURCHASE_TITLE = 'Purchases';
RS_PURCHASE_SUPPLIER = 'Supplier';
RS_PURCHASE_DATE = 'Date';
RS_PURCHASE_ADD = '&Add';
RS_PURCHASE_DELETE_ITEM = '&Delete';
RS_PURCHASE_SAVE = '&Save Purchase';
RS_PURCHASE_TOTAL = 'Purchase Total: $%s';
RS_PURCHASE_NO_SUPPLIER = 'You must select a supplier';
RS_PURCHASE_NO_ITEMS = 'You must add at least one complete item';
RS_PURCHASE_GRID_PRODUCT = 'Product';
RS_PURCHASE_GRID_QTY = 'Qty';
RS_PURCHASE_GRID_TOTALCOST = 'Total Cost';
RS_PURCHASE_GRID_UTILITY = '%% Utility';
RS_PURCHASE_GRID_UNITCOST = 'Unit Cost';
RS_PURCHASE_GRID_PRICE = 'Sale Price';

// Products frame
RS_PRODUCTS_SEARCH_HINT = 'Search by name...';
RS_PRODUCTS_BTN_NEW = '&New';
RS_PRODUCTS_BTN_EDIT = '&Edit';
RS_PRODUCTS_BTN_DELETE = 'De&lete';
RS_PRODUCTS_GRID_NAME = 'Name';
RS_PRODUCTS_GRID_STOCK = 'Stock';
RS_PRODUCTS_GRID_COST = 'Cost';
RS_PRODUCTS_GRID_PRICE = 'Price';
RS_PRODUCTS_DELETE_CONFIRM = 'Delete Product: %s?';

// People frame
RS_PEOPLE_TAB_CUSTOMERS = 'Customers';
RS_PEOPLE_TAB_SUPPLIERS = 'Suppliers';
RS_PEOPLE_SEARCH_HINT = 'Search by name...';
RS_PEOPLE_BTN_NEW = '&New';
RS_PEOPLE_BTN_EDIT = '&Edit';
RS_PEOPLE_BTN_DELETE = 'De&lete';
RS_PEOPLE_GRID_NAME = 'Name';
RS_PEOPLE_GRID_PHONE = 'Phone';
RS_PEOPLE_GRID_ADDRESS = 'Address';

// Reports frame
RS_REPORTS_TITLE = 'Reports';
RS_REPORTS_DATE_FROM = 'From:';
RS_REPORTS_DATE_TO = 'To:';
RS_REPORTS_REFRESH = 'Refresh';
RS_REPORTS_EXPORT = 'Export CSV';
RS_REPORTS_TAB_INCOME = 'Income & Profit';
RS_REPORTS_TAB_VALUATION = 'Inventory Valuation';
RS_REPORTS_TAB_PURCHASES = 'Purchases';
RS_REPORTS_EXPORTED = 'Report exported successfully to: %s';

// Units Sold Report
RS_REPORTS_TAB_UNITS_SOLD = 'Units Sold';
RS_REPORTS_UNITS_COL_PRODUCT = 'Product';
RS_REPORTS_UNITS_COL_UNITS = 'Units Sold';
RS_REPORTS_UNITS_COL_REVENUE = 'Revenue';
RS_REPORTS_UNITS_COL_COST = 'Cost';
RS_REPORTS_UNITS_COL_UTILITY = 'Utility';
RS_REPORTS_UNITS_TOTAL = 'TOTAL';
RS_REPORTS_EXPORT_ERROR = 'Error exporting CSV: %s';

// Credits frame
RS_CREDITS_TITLE = 'Debtors';
RS_CREDITS_SEARCH_HINT = 'Search by name...';
RS_CREDITS_SUMMARY_TOTAL = 'Total Debt: $%s';
RS_CREDITS_GRID_NAME = 'Name';
RS_CREDITS_GRID_SALES = 'Credit Sales';
RS_CREDITS_GRID_PAYMENTS = 'Payments';
RS_CREDITS_GRID_BALANCE = 'Balance';
RS_CREDITS_TAB_SALES = 'Credit Sales';
RS_CREDITS_TAB_PAYMENTS = 'Payments';
RS_CREDITS_SALE_DATE = 'Date';
RS_CREDITS_SALE_TOTAL = 'Total';
RS_CREDITS_SALE_ID = 'Operation ID';
RS_CREDITS_PAY_DATE = 'Date';
RS_CREDITS_PAY_AMOUNT = 'Amount';
RS_CREDITS_PAY_TOTAL = 'Total Payments: $%s';
RS_CREDITS_PAY_LABEL_AMOUNT = 'Amount:';
RS_CREDITS_PAY_LABEL_DATE = 'Date:';
RS_CREDITS_BTN_REGISTER = 'Register Payment';
RS_CREDITS_NO_DEBTOR = 'You must select a debtor';
RS_CREDITS_NO_SALE = 'You must select a credit sale';
RS_CREDITS_INVALID_AMOUNT = 'Enter a valid amount';
RS_CREDITS_AMOUNT_ZERO = 'Amount must be greater than zero';
RS_CREDITS_PAY_SUCCESS = 'Payment registered successfully';
RS_CREDITS_CHECKBOX = 'Credit';

// Returns frame
RS_NAV_RETURNS = 'Devoluciones';
RS_RETURNS_TITLE = 'Devoluciones / Pérdidas';
RS_RETURNS_OP_TYPE = 'Tipo de Operación';
RS_RETURNS_PERSON = 'Persona';
RS_RETURNS_DATE = 'Fecha';
RS_RETURNS_ADD = '&Agregar';
RS_RETURNS_DELETE = '&Eliminar';
RS_RETURNS_SAVE = '&Guardar';
RS_RETURNS_REBUILD = 'Reconstruir Saldos';
RS_RETURNS_GRID_PRODUCT = 'Producto';
RS_RETURNS_GRID_QTY = 'Cantidad';
RS_RETURNS_GRID_COST = 'Costo Unitario';
RS_RETURNS_COMBO_DEVOLUTION = 'Devolución de Cliente';
RS_RETURNS_COMBO_LOSS = 'Pérdida de Inventario';
RS_RETURNS_COMBO_PROVIDER = 'Devolución a Proveedor';
RS_RETURNS_NO_ITEMS = 'Debe agregar al menos un ítem con un producto';
RS_RETURNS_NO_CUSTOMER = 'Debe seleccionar un cliente';
RS_RETURNS_NO_SUPPLIER = 'Debe seleccionar un proveedor';
RS_RETURNS_INSUFFICIENT_STOCK = 'Stock insuficiente para: %s (disponible: %d)';
RS_RETURNS_SAVE_ERROR = 'La operación no fue guardada';
RS_RETURNS_SAVE_SUCCESS = 'Operación guardada exitosamente';
RS_RETURNS_REBUILD_SUCCESS = 'Saldos reconstruidos exitosamente';
RS_RETURNS_REBUILD_WARNING = 'Algunos productos tienen stock negativo después de reconstruir';

// Sidebar navigation (added)
RS_NAV_EXPORT = 'Export';
RS_NAV_SETTINGS = 'Settings';

// Export / Update Web Catalog frame
RS_EXPORT_PRODUCTS = 'Export Products';
RS_EXPORT_SERVICES = 'Export Services';
RS_EXPORT_BROWSE = 'Browse...';
RS_EXPORT_UPDATE_CATALOG = 'Update Web Catalog';
RS_EXPORT_PUBLISH_INSTAGRAM = 'Instagram Publication';
RS_EXPORT_DLG_JSON_TITLE = 'Select JSON export file';
RS_EXPORT_DLG_JSON_FILTER = 'JSON files (*.json)|*.json';
RS_EXPORT_DLG_DIR_TITLE = 'Select image output directory';
RS_EXPORT_ERR_SELECT_OPTION = 'Error: Select at least one export option (Products or Services).';
RS_EXPORT_COMPLETE = 'Export complete: %d products, %d services exported.';
RS_EXPORT_WARN_NO_IMAGE = '  WARNING: %d product(s) and %d service(s) have no image.';
RS_EXPORT_DLG_MISSING_TITLE = 'Missing images';
RS_EXPORT_DLG_MISSING_MSG = 'Export finished, but %d product(s) and %d service(s) were exported without an image.' + sLineBreak + sLineBreak + 'Assign images to these items (Products screen) for a complete catalog.';
RS_EXPORT_ERR_PREFIX = 'Error: %s';

// Instagram Publication (frame + flow)
RS_PUB_ERR_SELECT_OPTION = 'Error: Select at least one option (Products or Services).';
RS_PUB_NOTHING = 'Nothing to publish: no new products or services.';
RS_PUB_CANCELLED = 'Publication cancelled (%d item(s) pending).';
RS_PUB_NONE_SELECTED = 'No items selected; nothing published.';
RS_PUB_PUBLISHING = 'Publishing %d selected item(s) to Instagram...';
RS_PUB_RESULT_OK = 'Instagram Publication: %d published, %d skipped, %d failed.';
RS_PUB_RESULT_STOPPED = 'Instagram Publication stopped (see log): %d published, %d skipped, %d failed.';

// Instagram Publication preview dialog
RS_PUBPREVIEW_TITLE = 'Confirm Instagram Publication';
RS_PUBPREVIEW_HEADER = 'The following items will be published:';
RS_PUBPREVIEW_COL_PUBLISH = 'Publish';
RS_PUBPREVIEW_COL_ID = 'Id';
RS_PUBPREVIEW_COL_NAME = 'Name';
RS_PUBPREVIEW_COL_IMAGE = 'Image';
RS_PUBPREVIEW_IMG_OK = 'OK';
RS_PUBPREVIEW_IMG_MISSING = 'MISSING';
RS_PUBPREVIEW_BTN_PUBLISH = 'Publish';
RS_PUBPREVIEW_BTN_CANCEL = 'Cancel';
RS_PUBPREVIEW_BTN_SELECT_ALL = 'Select all';
RS_PUBPREVIEW_BTN_SELECT_NONE = 'Select none';
RS_PUBPREVIEW_SELECTED = '%d of %d item(s) selected to publish to Instagram.%s';
RS_PUBPREVIEW_WARN_NO_IMAGE = '  -  WARNING: %d item(s) have no image and cannot be published.';

// Settings frame
RS_SETTINGS_COL_PARAM = 'Parameter';
RS_SETTINGS_COL_VALUE = 'Value';
RS_SETTINGS_COL_CREDENTIAL = 'Credential';
RS_SETTINGS_COL_DESC = 'Description';
RS_SETTINGS_SELECT_HINT = '(select a parameter)';
RS_SETTINGS_YES = 'Yes';
RS_SETTINGS_NO = 'No';
RS_SETTINGS_LBL_PARAM = 'Parameter:';
RS_SETTINGS_LBL_VALUE = 'Value:';
RS_SETTINGS_LBL_VALUE_CRED = 'New value (credential, hidden):';
RS_SETTINGS_BTN_SAVE = 'Save';
RS_SETTINGS_BTN_REFRESH = 'Refresh';
RS_SETTINGS_MSG_SELECT_FIRST = 'Select a parameter first.';
RS_SETTINGS_MSG_CRED_BLANK = 'Enter a new value to change this credential (blank leaves it unchanged).';
RS_SETTINGS_MSG_SAVE_ERROR = 'Error saving: %s';
RS_SETTINGS_MSG_SAVED = 'Saved: %s';
RS_SETTINGS_MSG_RELOADED = 'Reloaded.';
RS_SETTINGS_MSG_ERROR = 'Error: %s';
RS_SETTINGS_DB_CHANGED = 'Database changed and reconnected: %s';
RS_SETTINGS_DB_NOT_SWITCHED_STATUS = 'Saved, but could not switch database: %s';
RS_SETTINGS_DB_NOT_SWITCHED_TITLE = 'Database not switched';
RS_SETTINGS_DB_NOT_SWITCHED_MSG = 'The db.file value was saved, but the application could not connect to:' + sLineBreak + '%s' + sLineBreak + sLineBreak + '%s' + sLineBreak + 'Still using: %s';

// Product form
RS_PRODUCT_LBL_ORIGINAL_PRICE = 'Original Price';
RS_PRODUCT_LBL_CATEGORY = 'Category';
RS_PRODUCT_LBL_BRAND = 'Brand';
RS_PRODUCT_LBL_CONDITION = 'Condition';
RS_PRODUCT_LBL_GOOGLE_CAT = 'Google Category';
RS_PRODUCT_CHK_IS_SERVICE = 'Is Service';
RS_PRODUCT_BTN_SELECT_IMAGE = 'Select Image...';
RS_PRODUCT_GROUP_PREVIEW = 'Preview';
RS_PRODUCT_DLG_PNG_TITLE = 'Select PNG image';
RS_PRODUCT_DLG_PNG_FILTER = 'PNG images (*.png)|*.png';
RS_PRODUCT_IMG_ERROR = 'Error: %s';
RS_PRODUCT_IMG_SELECTED = 'Image selected: %s';
RS_PRODUCT_IMG_PREVIEW_ERROR = 'Preview error: %s';
RS_PRODUCT_IMG_ID = 'Image ID: %d';


implementation

end.
