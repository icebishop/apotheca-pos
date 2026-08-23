unit UFrameExport;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Buttons, Dialogs,
  UExportService, UDataModule, LazLogger;

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
    lblStatus: TLabel;
    procedure btnBrowseFileClick(Sender: TObject);
    procedure btnBrowseDirClick(Sender: TObject);
    procedure btnExportClick(Sender: TObject);
  private
    function GetAppDir: String;
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
end;

function TFrameExport.GetAppDir: String;
begin
  Result := ExtractFilePath(ParamStr(0));
end;

procedure TFrameExport.btnBrowseFileClick(Sender: TObject);
var
  Dlg: TSaveDialog;
begin
  try
  Dlg := TSaveDialog.Create(Self);
  try
    Dlg.Title := 'Select JSON export file';
    Dlg.Filter := 'JSON files (*.json)|*.json';
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
    Dlg.Title := 'Select image output directory';
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
    lblStatus.Caption := 'Error: Select at least one export option (Products or Services).';
    Exit;
  end;

  // Build export options from UI state
  Options.ExportProducts := chkProducts.Checked;
  Options.ExportServices := chkServices.Checked;
  Options.OutputFilePath := edtFilePath.Text;
  Options.ImageOutputDir := edtImageDir.Text;

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
    Msg := 'Export complete: ' +
           IntToStr(ExportResult.ProductCount) + ' products, ' +
           IntToStr(ExportResult.ServiceCount) + ' services exported.';
    lblStatus.Caption := Msg;
  end
  else
    lblStatus.Caption := 'Error: ' + ExportResult.ErrorMessage;
  except
    on E: Exception do DebugLn('[TFrameExport.btnExportClick] ERROR: ' + E.Message);
  end;
end;

end.
