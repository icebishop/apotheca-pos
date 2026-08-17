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

unit UValidator;

{$mode objfpc}{$H+}

interface

uses
Classes, SysUtils, FileUtil, LResources, Forms, Controls, Graphics, Dialogs,
ExtCtrls, Buttons, LCLType,
UResourceString;

type
TValidator = class(TObject)
private // self access only

message:String;

public // access by anything

function validate():boolean;virtual;abstract;
procedure setMessage(newMessage:String);
function getMessage():String;
function isNumber(number:String):boolean;
function isPositive(number:String):boolean;
function confirmBox():boolean;
end;

implementation

procedure TValidator.setMessage(newMessage:String);
begin
     message := newMessage;
end;

function TValidator.getMessage():String;
begin
     getMessage := message;
end;

function TValidator.isNumber(number:String):boolean;
begin
     try
        StrToFloat(number);
        isNumber := true;
     except
        setMessage(Format(RS_MSGVALNUMERIC, [getMessage(), char(13)]));
        isNumber := false;
     end;

end;

function TValidator.isPositive(number:String):boolean;
begin

     if StrToFloat(number) > 0 then
        isPositive := true
     else
     begin
          setMessage(Format(RS_MSGMORETHAN0, [getMessage(), char(13)]));
         isPositive := false;
     end;

end;

function TValidator.confirmBox():boolean;
begin
     if Application.MessageBox(PChar(RS_MSGVALCBOX), PChar(RS_MSGWARNING), MB_ICONWARNING+MB_OKCANCEL
       ) = IDOK then
       confirmBox := true
     else
       confirmBox := false;

end;

end.

