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

{ Application Logger following OWASP Logging Cheat Sheet guidelines.
  - Structured log entries with: timestamp, level, source, event, details
  - Log levels: DEBUG, INFO, WARN, ERROR, SECURITY
  - File-based output with size-based rotation
  - No sensitive data (passwords, full card numbers, PII beyond user ID)
  - Security events for: app start/stop, credit operations, payment registration,
    validation failures, database errors
}

unit ULogger;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TLogLevel = (llDEBUG, llINFO, llWARN, llERROR, llSECURITY);

{ Initialize the logger. Call once at app startup. }
procedure InitLogger(const LogDir: String);

{ Shutdown the logger. Call at app exit. }
procedure ShutdownLogger;

{ Log an event }
procedure LogEvent(Level: TLogLevel; const Source, Event: String; const Details: String = '');

{ Convenience methods }
procedure LogInfo(const Source, Event: String; const Details: String = '');
procedure LogWarn(const Source, Event: String; const Details: String = '');
procedure LogError(const Source, Event: String; const Details: String = '');
procedure LogSecurity(const Source, Event: String; const Details: String = '');
procedure LogDebug(const Source, Event: String; const Details: String = '');

implementation

const
  LOG_FILE_NAME = 'apotheca.log';
  MAX_LOG_SIZE = 5 * 1024 * 1024; { 5 MB before rotation }
  MAX_LOG_FILES = 5;              { Keep up to 5 rotated files }
  LOG_LEVEL_NAMES: array[TLogLevel] of String = (
    'DEBUG', 'INFO', 'WARN', 'ERROR', 'SECURITY'
  );

var
  FLogFile: TextFile;
  FLogFilePath: String;
  FLogDir: String;
  FInitialized: Boolean;
  FMinLevel: TLogLevel;

procedure RotateLogFiles;
var
  i: Integer;
  OldPath, NewPath: String;
begin
  { Delete oldest }
  OldPath := FLogDir + LOG_FILE_NAME + '.' + IntToStr(MAX_LOG_FILES);
  if FileExists(OldPath) then
    DeleteFile(OldPath);

  { Rotate existing files }
  for i := MAX_LOG_FILES - 1 downto 1 do
  begin
    OldPath := FLogDir + LOG_FILE_NAME + '.' + IntToStr(i);
    NewPath := FLogDir + LOG_FILE_NAME + '.' + IntToStr(i + 1);
    if FileExists(OldPath) then
      RenameFile(OldPath, NewPath);
  end;

  { Rotate current log }
  if FileExists(FLogFilePath) then
  begin
    NewPath := FLogDir + LOG_FILE_NAME + '.1';
    RenameFile(FLogFilePath, NewPath);
  end;
end;

function GetLogFileSize: Int64;
var
  SR: TSearchRec;
begin
  Result := 0;
  if FindFirst(FLogFilePath, faAnyFile, SR) = 0 then
  begin
    Result := SR.Size;
    FindClose(SR);
  end;
end;

procedure CheckRotation;
begin
  if GetLogFileSize >= MAX_LOG_SIZE then
  begin
    CloseFile(FLogFile);
    RotateLogFiles;
    Assign(FLogFile, FLogFilePath);
    Rewrite(FLogFile);
  end;
end;

function FormatTimestamp: String;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.zzz', Now);
end;

procedure InitLogger(const LogDir: String);
begin
  if FInitialized then Exit;

  FLogDir := IncludeTrailingPathDelimiter(LogDir);
  FLogFilePath := FLogDir + LOG_FILE_NAME;
  FMinLevel := llINFO;

  { Ensure log directory exists }
  if not DirectoryExists(FLogDir) then
    ForceDirectories(FLogDir);

  { Open or create log file }
  Assign(FLogFile, FLogFilePath);
  if FileExists(FLogFilePath) then
    Append(FLogFile)
  else
    Rewrite(FLogFile);

  FInitialized := True;

  LogInfo('Logger', 'LOG_INIT', 'Logger initialized, path=' + FLogFilePath);
end;

procedure ShutdownLogger;
begin
  if not FInitialized then Exit;
  LogInfo('Logger', 'LOG_SHUTDOWN', 'Logger shutting down');
  CloseFile(FLogFile);
  FInitialized := False;
end;

procedure LogEvent(Level: TLogLevel; const Source, Event: String; const Details: String);
var
  Line: String;
begin
  if not FInitialized then Exit;
  if Level < FMinLevel then Exit;

  { Check if rotation needed }
  CheckRotation;

  { Format: TIMESTAMP | LEVEL | SOURCE | EVENT | DETAILS }
  Line := FormatTimestamp + ' | ' +
          LOG_LEVEL_NAMES[Level] + ' | ' +
          Source + ' | ' +
          Event + ' | ' +
          Details;

  WriteLn(FLogFile, Line);
  Flush(FLogFile);
end;

procedure LogInfo(const Source, Event: String; const Details: String);
begin
  LogEvent(llINFO, Source, Event, Details);
end;

procedure LogWarn(const Source, Event: String; const Details: String);
begin
  LogEvent(llWARN, Source, Event, Details);
end;

procedure LogError(const Source, Event: String; const Details: String);
begin
  LogEvent(llERROR, Source, Event, Details);
end;

procedure LogSecurity(const Source, Event: String; const Details: String);
begin
  LogEvent(llSECURITY, Source, Event, Details);
end;

procedure LogDebug(const Source, Event: String; const Details: String);
begin
  LogEvent(llDEBUG, Source, Event, Details);
end;

initialization
  FInitialized := False;

finalization
  ShutdownLogger;

end.
