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

program apotheca;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, clocale, SysUtils, ApothecaMain, LResources, UFPurchase,
  UFFindProduct, UDataModule, SQLDBLaz, UFProduct,
  UFFindCustomer,
  UFFindSupplier, UFSupplier, UFCustomer,
  UFSale,
  UFPay, UFFindpay,
  UFFindTransacion, UFTransaction,
  ULanguage, UFormSplash, ULogger;

{$IFDEF WINDOWS}{$R apotheca.rc}{$ENDIF}

var
  Splash: TFormSplash;

begin
  {$I apotheca.lrs}
  InitializeLanguage;
  InitLogger(ExtractFilePath(ParamStr(0)) + 'logs');
  LogSecurity('App', 'APP_START', 'Application starting');
  Application.Initialize;

  { Set application icon }
  if FileExists(ExtractFilePath(ParamStr(0)) + 'apotheca.ico') then
    Application.Icon.LoadFromFile(ExtractFilePath(ParamStr(0)) + 'apotheca.ico');

  { Show splash screen for 5 seconds (modal, timer auto-closes) }
  Splash := TFormSplash.Create(Application);
  try
    Splash.LoadSplashImage;
    Splash.ShowModal;
  finally
    Splash.Free;
  end;

  Application.CreateForm(TDataModule1, DataModule1);
  Application.CreateForm(TFormPrincipal, FormPrincipal);
  Application.Run;
end.

