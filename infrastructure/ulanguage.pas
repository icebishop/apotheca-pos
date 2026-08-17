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

unit ULanguage;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, GetText, Translations, LazFileUtils, LazLogger;

{ Call this before Application.Initialize to load translations based on OS language }
procedure InitializeLanguage;

{ Returns the detected 2-letter language code (e.g. 'es', 'en') }
function GetCurrentLanguage: String;

implementation

var
  FCurrentLanguage: String = 'en';

function GetCurrentLanguage: String;
begin
  Result := FCurrentLanguage;
end;

function DetectOSLanguage: String;
var
  Lang, FallbackLang: String;
begin
  { GetLanguageIDs returns the OS locale (e.g. 'es_CO', 'en_US') }
  GetLanguageIDs(Lang, FallbackLang);
  { Extract 2-letter code }
  if Length(FallbackLang) >= 2 then
    Result := LowerCase(Copy(FallbackLang, 1, 2))
  else if Length(Lang) >= 2 then
    Result := LowerCase(Copy(Lang, 1, 2))
  else
    Result := 'en';
end;

procedure InitializeLanguage;
var
  LangCode: String;
  POFile: String;
  BasePath: String;
begin
  LangCode := DetectOSLanguage;
  FCurrentLanguage := LangCode;

  DebugLn('[Language] Detected OS language: ', LangCode);

  { English is the default (built into resourcestrings), no translation needed }
  if LangCode = 'en' then
  begin
    DebugLn('[Language] Using English (default)');
    Exit;
  end;

  { Look for translation file in languages/<lang>/apotheca.<lang>.po }
  BasePath := ExtractFilePath(ParamStr(0)) + 'languages' + PathDelim;
  POFile := BasePath + LangCode + PathDelim + 'apotheca.' + LangCode + '.po';

  { Fallback: try relative path from CWD }
  if not FileExists(POFile) then
    POFile := 'languages' + PathDelim + LangCode + PathDelim + 'apotheca.' + LangCode + '.po';

  if FileExists(POFile) then
  begin
    DebugLn('[Language] Loading translation: ', POFile);
    TranslateUnitResourceStrings('UResourceString', POFile);
  end
  else
    DebugLn('[Language] Translation file not found: ', POFile, ' - using English defaults');
end;

end.
