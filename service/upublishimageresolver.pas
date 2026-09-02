{ Apothêca - Instagram Auto-Publish

  Image resolver. Resolves a registry item's image references to publicly
  reachable URLs, validating (and if needed converting/cropping) them to
  Instagram's supported aspect-ratio range using fcl-image, with WebP inputs
  decoded via the dwebp CLI.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UPublishImageResolver;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, FileUtil,
  FPimage, FPReadPNG, FPReadJPEG, FPWriteJPEG,
  URegistryItem, ULogger;

type
  TResolvedImage = record
    PublicUrl: String;
    LocalPath: String;
  end;
  TResolvedImageArray = array of TResolvedImage;

  { TPublishImageResolver }

  TPublishImageResolver = class(TObject)
  private
    FDwebpPath: String;
    function CheckAspectRatio(const Path: String): Boolean;
    function ConvertToJpeg(const SourcePath, OutputPath: String): Boolean;
    function DecodeWebpToPng(const WebpPath, PngOut: String): Boolean;
  public
    constructor Create;
    function Resolve(Item: TRegistryItem;
      const PublicFolder, BaseUrl: String): TResolvedImageArray;
  end;

const
  MAX_CAROUSEL_IMAGES = 10;
  MIN_ASPECT_RATIO = 0.8;    { 4:5 portrait }
  MAX_ASPECT_RATIO = 1.91;   { 1.91:1 landscape }

implementation

constructor TPublishImageResolver.Create;
begin
  inherited Create;
  FDwebpPath := FindDefaultExecutablePath('dwebp');
end;

function TPublishImageResolver.CheckAspectRatio(const Path: String): Boolean;
var
  Img: TFPMemoryImage;
  Ratio: Double;
begin
  Result := False;
  Img := TFPMemoryImage.Create(0, 0);
  try
    try
      Img.LoadFromFile(Path);
      if Img.Height = 0 then
        Exit;
      Ratio := Img.Width / Img.Height;
      Result := (Ratio >= MIN_ASPECT_RATIO) and (Ratio <= MAX_ASPECT_RATIO);
    except
      Result := False;
    end;
  finally
    Img.Free;
  end;
end;

function TPublishImageResolver.ConvertToJpeg(const SourcePath,
  OutputPath: String): Boolean;
var
  Img: TFPMemoryImage;
  Cropped: TFPMemoryImage;
  Writer: TFPWriterJPEG;
  Ratio: Double;
  NewW, NewH, Left, Top, X, Y: Integer;
begin
  Result := False;
  Img := TFPMemoryImage.Create(0, 0);
  try
    try
      Img.LoadFromFile(SourcePath);
      if (Img.Width = 0) or (Img.Height = 0) then
        Exit;

      Ratio := Img.Width / Img.Height;
      NewW := Img.Width;
      NewH := Img.Height;
      Left := 0;
      Top := 0;

      if Ratio < MIN_ASPECT_RATIO then
      begin
        { Too tall: crop height to width / MIN, centered }
        NewH := Round(Img.Width / MIN_ASPECT_RATIO);
        Top := (Img.Height - NewH) div 2;
      end
      else if Ratio > MAX_ASPECT_RATIO then
      begin
        { Too wide: crop width to height * MAX, centered }
        NewW := Round(Img.Height * MAX_ASPECT_RATIO);
        Left := (Img.Width - NewW) div 2;
      end;

      Writer := TFPWriterJPEG.Create;
      try
        Writer.CompressionQuality := 90;
        if (NewW = Img.Width) and (NewH = Img.Height) then
          Img.SaveToFile(OutputPath, Writer)
        else
        begin
          Cropped := TFPMemoryImage.Create(NewW, NewH);
          try
            for Y := 0 to NewH - 1 do
              for X := 0 to NewW - 1 do
                Cropped.Colors[X, Y] := Img.Colors[Left + X, Top + Y];
            Cropped.SaveToFile(OutputPath, Writer);
          finally
            Cropped.Free;
          end;
        end;
        Result := True;
      finally
        Writer.Free;
      end;
    except
      on E: Exception do
      begin
        LogError('PublishImageResolver', 'JPEG_CONVERT_FAIL',
          'source=' + SourcePath + ' error=' + E.Message);
        Result := False;
      end;
    end;
  finally
    Img.Free;
  end;
end;

function TPublishImageResolver.DecodeWebpToPng(const WebpPath,
  PngOut: String): Boolean;
var
  AProcess: TProcess;
begin
  Result := False;
  if FDwebpPath = '' then
  begin
    LogWarn('PublishImageResolver', 'DWEBP_MISSING',
      'dwebp not found in PATH; cannot decode ' + WebpPath);
    Exit;
  end;

  try
    AProcess := TProcess.Create(nil);
    try
      AProcess.Executable := FDwebpPath;
      AProcess.Parameters.Add(WebpPath);
      AProcess.Parameters.Add('-o');
      AProcess.Parameters.Add(PngOut);
      AProcess.Options := [poWaitOnExit, poUsePipes];
      AProcess.Execute;
      Result := (AProcess.ExitStatus = 0) and FileExists(PngOut);
    finally
      AProcess.Free;
    end;
  except
    on E: Exception do
    begin
      LogError('PublishImageResolver', 'DWEBP_FAIL',
        'webp=' + WebpPath + ' error=' + E.Message);
      Result := False;
    end;
  end;
end;

function TPublishImageResolver.Resolve(Item: TRegistryItem;
  const PublicFolder, BaseUrl: String): TResolvedImageArray;
var
  CleanBase, Filename, NameNoExt, Ext: String;
  OriginalPath, WebpPath, JpegPath, TmpPng, JpegFilename: String;
  i: Integer;
  RI: TResolvedImage;
  Folder: String;

  procedure AddResolved(const AUrl, ALocal: String);
  begin
    if Length(Result) >= MAX_CAROUSEL_IMAGES then
      Exit;
    RI.PublicUrl := AUrl;
    RI.LocalPath := ALocal;
    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := RI;
  end;

begin
  SetLength(Result, 0);
  if Item.Images.Count = 0 then
    Exit;

  { Trim trailing slash from base URL }
  CleanBase := BaseUrl;
  while (CleanBase <> '') and (CleanBase[Length(CleanBase)] = '/') do
    CleanBase := Copy(CleanBase, 1, Length(CleanBase) - 1);

  Folder := IncludeTrailingPathDelimiter(PublicFolder);

  for i := 0 to Item.Images.Count - 1 do
  begin
    if Length(Result) >= MAX_CAROUSEL_IMAGES then
      Break;

    Filename := Item.Images[i];
    while (Filename <> '') and (Filename[1] = '/') do
      Filename := Copy(Filename, 2, Length(Filename) - 1);
    if Filename = '' then
      Continue;

    NameNoExt := ChangeFileExt(Filename, '');
    Ext := ExtractFileExt(Filename);
    OriginalPath := Folder + Filename;
    JpegFilename := NameNoExt + '.jpeg';
    JpegPath := Folder + JpegFilename;

    if FileExists(OriginalPath) then
    begin
      { Instagram's content publishing API only accepts JPEG (PNG/WebP are
        rejected with error 36001). Always convert to JPEG; ConvertToJpeg also
        crops to the supported aspect-ratio range when needed. If the source is
        already a .jpg/.jpeg with a valid ratio, use it directly. }
      if ((LowerCase(Ext) = '.jpg') or (LowerCase(Ext) = '.jpeg')) and
         CheckAspectRatio(OriginalPath) then
        AddResolved(CleanBase + '/' + Filename, OriginalPath)
      else if ConvertToJpeg(OriginalPath, JpegPath) then
        AddResolved(CleanBase + '/' + JpegFilename, JpegPath)
      else
        LogWarn('PublishImageResolver', 'JPEG_CONVERT_FAIL', 'file=' + Filename);
      Continue;
    end;

    { Fallback: a .webp sibling }
    WebpPath := Folder + NameNoExt + '.webp';
    if FileExists(WebpPath) then
    begin
      TmpPng := Folder + NameNoExt + '_tmp.png';
      if DecodeWebpToPng(WebpPath, TmpPng) then
      begin
        if ConvertToJpeg(TmpPng, JpegPath) then
          AddResolved(CleanBase + '/' + JpegFilename, JpegPath)
        else
          LogWarn('PublishImageResolver', 'WEBP_JPEG_FAIL', 'file=' + WebpPath);
        if FileExists(TmpPng) then
          DeleteFile(TmpPng);
      end
      else
        LogWarn('PublishImageResolver', 'WEBP_DECODE_FAIL', 'file=' + WebpPath);
      Continue;
    end;

    LogWarn('PublishImageResolver', 'IMAGE_NOT_FOUND',
      'item=' + Item.Name + ' file=' + Filename);
  end;
end;

end.
