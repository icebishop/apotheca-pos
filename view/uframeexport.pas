unit UFrameExport;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Buttons, Dialogs, ComCtrls,
  UExportService, UPublishOrchestrator, USettingsService, UFPublishPreview,
  UDataModule, UResourceString, LazLogger;

type

  { TFrameExport }

  TFrameExport = class(TFrame)
    chkProducts: TCheckBox;
    chkServices: TCheckBox;
    edtFilePath: TEdit;
    btnBrowseFile: TBitBtn;
    edtImageDir: TEdit;
    btnBrowseDir: TBitBtn;
    btnExport: TBitBtn;
    btnPublishInstagram: TBitBtn;
    lblStatus: TLabel;
    ProgressBar: TProgressBar;
    MemoLog: TMemo;
    procedure btnBrowseFileClick(Sender: TObject);
    procedure btnBrowseDirClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
    procedure btnPublishInstagramClick(Sender: TObject);
  private
    function GetAppDir: String;
    procedure LogLine(const S: String);
    procedure ExportProgress(Current, Total: Integer; const Msg: String);
    procedure PublishProgress(Current, Total: Integer; const Msg: String);
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

{$R *.lfm}

{ TFrameExport }

constructor TFrameExport.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  edtFilePath.Text := GetAppDir + 'export.json';
  edtImageDir.Text := GetAppDir;
  { Captions from resource strings (localizable). }
  chkProducts.Caption := RS_EXPORT_PRODUCTS;
  chkServices.Caption := RS_EXPORT_SERVICES;
  btnBrowseFile.Caption := RS_EXPORT_BROWSE;
  btnBrowseDir.Caption := RS_EXPORT_BROWSE;
  btnExport.Caption := RS_EXPORT_UPDATE_CATALOG;
  btnPublishInstagram.Caption := RS_EXPORT_PUBLISH_INSTAGRAM;
end;

function TFrameExport.GetAppDir: String;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

procedure TFrameExport.LogLine(const S: String);
begin
  MemoLog.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + S);
  { Keep the newest line visible. }
  MemoLog.SelStart := Length(MemoLog.Text);
end;

procedure TFrameExport.ExportProgress(Current, Total: Integer; const Msg: String);
begin
  if Total > 0 then
  begin
    ProgressBar.Max := Total;
    if Current > Total then Current := Total;
    ProgressBar.Position := Current;
  end;
  { Only log noteworthy lines (failures + phase headers), not every OK item,
    to keep the area useful; but show all if it's a failure/skip. }
  if (Pos('failed', LowerCase(Msg)) > 0) or (Pos('Exporting', Msg) > 0) then
    LogLine(Msg);
  Application.ProcessMessages;
end;

procedure TFrameExport.PublishProgress(Current, Total: Integer; const Msg: String);
begin
  if Total > 0 then
  begin
    ProgressBar.Max := Total;
    if Current > Total then Current := Total;
    ProgressBar.Position := Current;
  end;
  { For publishing, log everything (published / skipped / failed) so causes
    are visible. }
  LogLine(Msg);
  Application.ProcessMessages;
end;

procedure TFrameExport.btnBrowseFileClick(Sender: TObject);
var
  Dlg: TSaveDialog;
begin
  try
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := RS_EXPORT_DLG_JSON_TITLE;
    Dlg.Filter := RS_EXPORT_DLG_JSON_FILTER;
    Dlg.DefaultExt := 'json';
    Dlg.FileName := edtFilePath.Text;
    if Dlg.Execute then
      edtFilePath.Text := Dlg.FileName;
    // On cancel, retain current path
  finally
    Dlg.Free;
  end;
  except
    on E: Exception do DebugLn('[TFrameExport.btnBrowseFileClick] ERROR: ' + E.Message);
  end;
end;

procedure TFrameExport.btnBrowseDirClick(Sender: TObject);
var
  Dlg: TSelectDirectoryDialog;
begin
  try
  Dlg := TSelectDirectoryDialog.Create(Self);
  try
    Dlg.Title := RS_EXPORT_DLG_DIR_TITLE;
    Dlg.FileName := edtImageDir.Text;
    if Dlg.Execute then
      edtImageDir.Text := Dlg.FileName;
    // On cancel, retain current path
  finally
    Dlg.Free;
  end;
  except
    on E: Exception do DebugLn('[TFrameExport.btnBrowseDirClick] ERROR: ' + E.Message);
  end;
end;

procedure TFrameExport.btnExportClick(Sender: TObject);
var
  Options: TExportOptions;
  ExportResult: TExportResult;
  ExportSvc: TExportService;
  Msg: String;
begin
  try
  // Validate at least one checkbox is checked
  if (not chkProducts.Checked) and (not chkServices.Checked) then
  begin
    lblStatus.Caption := RS_EXPORT_ERR_SELECT_OPTION;
    Exit;
  end;

  // Build export options from UI state
  Options.ExportProducts := chkProducts.Checked;
  Options.ExportServices := chkServices.Checked;
  Options.OutputFilePath := edtFilePath.Text;
  Options.ImageOutputDir := edtImageDir.Text;
  Options.OnProgress := @ExportProgress;

  MemoLog.Clear;
  LogLine('Starting Update Web Catalog...');
  ProgressBar.Position := 0;
  ProgressBar.Visible := True;
  Application.ProcessMessages;

  // Execute export
  DataModule1.EnsureTransaction;
  ExportSvc := TExportService.Create(DataModule1.SQLite3Connection1);
  try
    ExportResult := ExportSvc.Execute(Options);
  finally
    ExportSvc.Free;
  end;

  // Display result in status label
  if ExportResult.Success then
  begin
    Msg := Format(RS_EXPORT_COMPLETE,
      [ExportResult.ProductCount, ExportResult.ServiceCount]);
    { Warn about items exported without an image. }
    if (ExportResult.ProductsWithoutImage > 0) or
       (ExportResult.ServicesWithoutImage > 0) then
    begin
      Msg := Msg + Format(RS_EXPORT_WARN_NO_IMAGE,
        [ExportResult.ProductsWithoutImage, ExportResult.ServicesWithoutImage]);
      MessageDlg(RS_EXPORT_DLG_MISSING_TITLE,
        Format(RS_EXPORT_DLG_MISSING_MSG,
          [ExportResult.ProductsWithoutImage, ExportResult.ServicesWithoutImage]),
        mtWarning, [mbOK], 0);
    end;
    lblStatus.Caption := Msg;
    LogLine(Msg);
    ProgressBar.Position := ProgressBar.Max;
  end
  else
  begin
    lblStatus.Caption := Format(RS_EXPORT_ERR_PREFIX, [ExportResult.ErrorMessage]);
    LogLine('ERROR: ' + ExportResult.ErrorMessage);
  end;
  except
    on E: Exception do DebugLn('[TFrameExport.btnExportClick] ERROR: ' + E.Message);
  end;
end;

procedure TFrameExport.btnPublishInstagramClick(Sender: TObject);
var
  Options: TPublishOptions;
  Summary: TPublishSummary;
  Orchestrator: TPublishOrchestrator;
  Svc: TSettingsService;
  ResBase: String;
  NewItems: TStringList;
  CheckedIds: TStringList;
  DetectErr: String;
begin
  try
    Options.OnlyIds := nil;
    { Read configuration from the parameters table (Settings). }
    DataModule1.EnsureTransaction;
    Svc := TSettingsService.Create(DataModule1.SQLite3Connection1);
    try
      ResBase := GetAppDir + '..' + PathDelim + 'don-pilido-app' + PathDelim +
                 'src' + PathDelim + 'res' + PathDelim;
      Options.ProductsPath := Svc.GetValue(PARAM_EXPORT_PRODUCTS_PATH,
        ResBase + 'products.json');
      Options.ServicesPath := Svc.GetValue(PARAM_EXPORT_SERVICES_PATH,
        ResBase + 'services.json');
      Options.PublicFolder := Svc.GetValue(PARAM_EXPORT_PUBLIC_FOLDER,
        GetAppDir + '..' + PathDelim + 'don-pilido-app' + PathDelim + 'public');

      { Instagram credentials/config live in the parameters table and are passed
        directly to the orchestrator. }
      Options.AccessToken := Svc.GetValue(PARAM_IG_ACCESS_TOKEN, '');
      Options.BusinessAccountId := Svc.GetValue(PARAM_IG_BUSINESS_ACCOUNT_ID, '');
      Options.ImageBaseUrl := Svc.GetValue(PARAM_IG_IMAGE_BASE_URL, '');
    finally
      Svc.Free;
    end;

    { .env fallback still supported if a parameter is blank. }
    Options.EnvFilePath := GetAppDir + 'export' + PathDelim + '.env';
    Options.IncludeProducts := chkProducts.Checked;
    Options.IncludeServices := chkServices.Checked;
    { Publish from the database: products with available stock. }
    Options.UseDatabase := True;
    Options.OnProgress := @PublishProgress;

    if (not Options.IncludeProducts) and (not Options.IncludeServices) then
    begin
      lblStatus.Caption := RS_PUB_ERR_SELECT_OPTION;
      Exit;
    end;

    DataModule1.EnsureTransaction;
    Orchestrator := TPublishOrchestrator.Create(DataModule1.SQLite3Connection1);
    try
      { Detect what would be published and show a confirmation modal first. }
      DetectErr := '';
      NewItems := Orchestrator.DetectNew(Options, DetectErr);
      try
        if NewItems = nil then
        begin
          lblStatus.Caption := Format(RS_EXPORT_ERR_PREFIX, [DetectErr]);
          Exit;
        end;
        if NewItems.Count = 0 then
        begin
          lblStatus.Caption := RS_PUB_NOTHING;
          Exit;
        end;

        { Modal preview with per-row checkboxes: user selects which to publish. }
        CheckedIds := nil;
        if not ConfirmPublish(Self, NewItems, CheckedIds) then
        begin
          if CheckedIds <> nil then CheckedIds.Free;
          lblStatus.Caption := Format(RS_PUB_CANCELLED, [NewItems.Count]);
          Exit;
        end;
      finally
        NewItems.Free;
      end;

      try
        if (CheckedIds = nil) or (CheckedIds.Count = 0) then
        begin
          lblStatus.Caption := RS_PUB_NONE_SELECTED;
          Exit;
        end;

        lblStatus.Caption := Format(RS_PUB_PUBLISHING, [CheckedIds.Count]);
        MemoLog.Clear;
        LogLine(Format('Publishing %d selected item(s) to Instagram...',
          [CheckedIds.Count]));
        ProgressBar.Position := 0;
        ProgressBar.Max := CheckedIds.Count;
        ProgressBar.Visible := True;
        Application.ProcessMessages;

        Options.OnlyIds := CheckedIds;  { publish only the checked items }
        Summary := Orchestrator.Run(Options);
        ProgressBar.Position := ProgressBar.Max;
      finally
        CheckedIds.Free;
      end;
    finally
      Orchestrator.Free;
    end;

    if Summary.ExitCode = 0 then
      lblStatus.Caption := Format(RS_PUB_RESULT_OK,
        [Summary.Published, Summary.Skipped, Summary.Failed])
    else
      lblStatus.Caption := Format(RS_PUB_RESULT_STOPPED,
        [Summary.Published, Summary.Skipped, Summary.Failed]);
    LogLine('--- ' + lblStatus.Caption + ' ---');
  except
    on E: Exception do
    begin
      DebugLn('[TFrameExport.btnPublishInstagramClick] ERROR: ' + E.Message);
      lblStatus.Caption := Format(RS_EXPORT_ERR_PREFIX, [E.Message]);
      LogLine('ERROR: ' + E.Message);
    end;
  end;
end;

end.
