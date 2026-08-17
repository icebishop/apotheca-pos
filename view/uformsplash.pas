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

unit UFormSplash;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, ExtCtrls, LazLogger;

type

  { TFormSplash }

  TFormSplash = class(TForm)
    ImageSplash: TImage;
    TimerClose: TTimer;
    procedure OnTimerClose(Sender: TObject);
  private
  public
    procedure LoadSplashImage;
  end;

implementation

{$R *.lfm}

procedure TFormSplash.LoadSplashImage;
var
  ImgPath: String;
  JPEG: TJPEGImage;
  Mon: TMonitor;
begin
  { Center splash on the primary monitor }
  Mon := Screen.PrimaryMonitor;
  Position := poDesigned;
  Left := Mon.Left + (Mon.Width - Width) div 2;
  Top := Mon.Top + (Mon.Height - Height) div 2;

  ImgPath := ExtractFilePath(ParamStr(0)) + 'res' + PathDelim + 'Splash.jpg';
  if not FileExists(ImgPath) then
    ImgPath := 'res' + PathDelim + 'Splash.jpg';

  if FileExists(ImgPath) then
  begin
    JPEG := TJPEGImage.Create;
    try
      JPEG.LoadFromFile(ImgPath);
      ImageSplash.Picture.Assign(JPEG);
    finally
      JPEG.Free;
    end;
  end
  else
    DebugLn('[Splash] Image not found: ', ImgPath);
end;

procedure TFormSplash.OnTimerClose(Sender: TObject);
begin
  TimerClose.Enabled := False;
  ModalResult := mrOk;
end;

end.
