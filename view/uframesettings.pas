{ Apothêca - Settings frame

  UI for viewing and editing application parameters (the parameters table),
  loaded through TSettingsService. Values are shown in a grid; credential-flagged
  parameters are masked (their decrypted value is never displayed).

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UFrameSettings;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Grids, StdCtrls, Buttons, ExtCtrls,
  Graphics, Dialogs, LazLogger, USettingsService, UDataModule, UResourceString,
  UAppConfig;

type

  { TFrameSettings }

  TFrameSettings = class(TFrame)
    GridParams: TStringGrid;
    PanelEdit: TPanel;
    lblKey: TLabel;
    lblKeyValue: TLabel;
    lblValue: TLabel;
    edtValue: TEdit;
    btnSave: TBitBtn;
    btnRefresh: TBitBtn;
    lblStatus: TLabel;
    procedure GridParamsSelection(Sender: TObject; aCol, aRow: Integer);
    procedure btnSaveClick(Sender: TObject);
    procedure btnRefreshClick(Sender: TObject);
  private
    FSelectedKey: String;
    FSelectedIsCredential: Boolean;
    FLoading: Boolean;
    procedure LoadGrid;
    procedure SelectRowByKey(const AKey: String);
  public
    constructor Create(AOwner: TComponent); override;
  end;

implementation

{$R *.lfm}

const
  COL_KEY = 0;
  COL_VALUE = 1;
  COL_CREDENTIAL = 2;
  COL_DESC = 3;

{ TFrameSettings }

constructor TFrameSettings.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  GridParams.ColCount := 4;
  GridParams.FixedRows := 1;
  GridParams.RowCount := 1;
  GridParams.Cells[COL_KEY, 0] := RS_SETTINGS_COL_PARAM;
  GridParams.Cells[COL_VALUE, 0] := RS_SETTINGS_COL_VALUE;
  GridParams.Cells[COL_CREDENTIAL, 0] := RS_SETTINGS_COL_CREDENTIAL;
  GridParams.Cells[COL_DESC, 0] := RS_SETTINGS_COL_DESC;
  GridParams.ColWidths[COL_KEY] := 220;
  GridParams.ColWidths[COL_VALUE] := 240;
  GridParams.ColWidths[COL_CREDENTIAL] := 90;
  GridParams.ColWidths[COL_DESC] := 300;
  FSelectedKey := '';
  FSelectedIsCredential := False;
  FLoading := False;
  edtValue.Text := '';
  lblKey.Caption := RS_SETTINGS_LBL_PARAM;
  lblValue.Caption := RS_SETTINGS_LBL_VALUE;
  btnSave.Caption := RS_SETTINGS_BTN_SAVE;
  btnRefresh.Caption := RS_SETTINGS_BTN_REFRESH;
  lblKeyValue.Caption := RS_SETTINGS_SELECT_HINT;
  lblStatus.Caption := '';
  LoadGrid;
end;

procedure TFrameSettings.LoadGrid;
var
  Svc: TSettingsService;
  Views: TParameterViewList;
  i, RowIdx: Integer;
  V: TParameterView;
  PrevKey: String;
begin
  { Remember the current selection so it survives the reload. }
  PrevKey := FSelectedKey;

  { Guard the OnSelection handler while we rebuild the grid, so it does not
    clobber the edit panel / status message during programmatic repopulation. }
  FLoading := True;
  try
    try
      DataModule1.EnsureTransaction;
      Svc := TSettingsService.Create(DataModule1.SQLite3Connection1);
      try
        Views := Svc.GetViews();
        try
          { Row 1 is always the db.file path, sourced from the external config
            file (apotheca.conf), not the parameters table. }
          GridParams.RowCount := 2 + Views.Count;
          GridParams.Cells[COL_KEY, 1] := PARAM_DB_FILE;
          GridParams.Cells[COL_VALUE, 1] :=
            TAppConfig.GetDbFile(DataModule1.CurrentDbPath);
          GridParams.Cells[COL_CREDENTIAL, 1] := RS_SETTINGS_NO;
          GridParams.Cells[COL_DESC, 1] := RS_SETTINGS_DB_FILE_DESC;

          RowIdx := 2;
          for i := 0 to Views.Count - 1 do
          begin
            V := Views[i];
            { db.file is shown from the config file (row 1); skip any stale
              db.file row left in the parameters table by older versions. }
            if V.Key = PARAM_DB_FILE then
              Continue;
            GridParams.Cells[COL_KEY, RowIdx] := V.Key;
            GridParams.Cells[COL_VALUE, RowIdx] := V.Masked;
            if V.IsCredential then
              GridParams.Cells[COL_CREDENTIAL, RowIdx] := RS_SETTINGS_YES
            else
              GridParams.Cells[COL_CREDENTIAL, RowIdx] := RS_SETTINGS_NO;
            GridParams.Cells[COL_DESC, RowIdx] := V.Description;
            Inc(RowIdx);
          end;
          { Shrink if a stale db.file row was skipped. }
          GridParams.RowCount := RowIdx;
        finally
          Views.Free;
        end;
      finally
        Svc.Free;
      end;
    except
      on E: Exception do
        DebugLn('[TFrameSettings.LoadGrid] ERROR: ' + E.Message);
    end;
  finally
    FLoading := False;
  end;

  { Restore the previous selection (re-reads fresh masked value into the grid). }
  if PrevKey <> '' then
    SelectRowByKey(PrevKey);
end;

procedure TFrameSettings.SelectRowByKey(const AKey: String);
var
  r: Integer;
begin
  for r := 1 to GridParams.RowCount - 1 do
    if GridParams.Cells[COL_KEY, r] = AKey then
    begin
      GridParams.Row := r;
      { Refresh the edit panel from the (now reloaded) row. }
      GridParamsSelection(GridParams, COL_KEY, r);
      Exit;
    end;
end;

procedure TFrameSettings.GridParamsSelection(Sender: TObject; aCol, aRow: Integer);
begin
  { Ignore selection events fired while the grid is being repopulated. }
  if FLoading then
    Exit;
  if (aRow < 1) or (aRow >= GridParams.RowCount) then
    Exit;
  FSelectedKey := GridParams.Cells[COL_KEY, aRow];
  FSelectedIsCredential := GridParams.Cells[COL_CREDENTIAL, aRow] = RS_SETTINGS_YES;
  lblKeyValue.Caption := FSelectedKey;
  { For credentials, keep the edit box empty (never prefill with the secret).
    For plain parameters, prefill with the current value for convenient editing. }
  if FSelectedIsCredential then
  begin
    edtValue.Text := '';
    edtValue.PasswordChar := '*';
    lblValue.Caption := RS_SETTINGS_LBL_VALUE_CRED;
  end
  else
  begin
    edtValue.Text := GridParams.Cells[COL_VALUE, aRow];
    edtValue.PasswordChar := #0;
    lblValue.Caption := RS_SETTINGS_LBL_VALUE;
  end;
end;

procedure TFrameSettings.btnSaveClick(Sender: TObject);
var
  Svc: TSettingsService;
  NewDbPath, ReopenErr: String;
begin
  if FSelectedKey = '' then
  begin
    lblStatus.Caption := RS_SETTINGS_MSG_SELECT_FIRST;
    Exit;
  end;
  if FSelectedIsCredential and (edtValue.Text = '') then
  begin
    lblStatus.Caption := RS_SETTINGS_MSG_CRED_BLANK;
    Exit;
  end;
  try
    { The database file path is stored in the external config file
      (apotheca.conf), NOT the parameters table, so it is known before the DB
      opens. Persist it there, then reconnect the data module. }
    if FSelectedKey = PARAM_DB_FILE then
    begin
      NewDbPath := Trim(edtValue.Text);
      if not TAppConfig.SetDbFile(NewDbPath) then
      begin
        lblStatus.Caption := Format(RS_SETTINGS_MSG_SAVE_ERROR, [FSelectedKey]);
        Exit;
      end;
      if DataModule1.ReopenDatabase(NewDbPath, ReopenErr) then
      begin
        LoadGrid;  { new DB may have its own parameter set }
        lblStatus.Caption := Format(RS_SETTINGS_DB_CHANGED, [NewDbPath]);
      end
      else
      begin
        { Reopen failed/refused; the config value was written but the connection
          still points at the previous file. Warn and reload from the old DB. }
        LoadGrid;
        lblStatus.Caption := Format(RS_SETTINGS_DB_NOT_SWITCHED_STATUS, [ReopenErr]);
        MessageDlg(RS_SETTINGS_DB_NOT_SWITCHED_TITLE,
          Format(RS_SETTINGS_DB_NOT_SWITCHED_MSG,
            [NewDbPath, ReopenErr, DataModule1.CurrentDbPath]),
          mtWarning, [mbOK], 0);
      end;
      Exit;
    end;

    DataModule1.EnsureTransaction;
    Svc := TSettingsService.Create(DataModule1.SQLite3Connection1);
    try
      if not Svc.SetValue(FSelectedKey, edtValue.Text) then
      begin
        lblStatus.Caption := Format(RS_SETTINGS_MSG_SAVE_ERROR, [FSelectedKey]);
        Exit;
      end;
    finally
      Svc.Free;
    end;

    { Reload so the grid reflects the persisted value (and re-masks credentials).
      LoadGrid preserves the current selection; set the status afterwards so it
      is not overwritten by the reload. }
    LoadGrid;
    if FSelectedIsCredential then
      edtValue.Text := '';
    lblStatus.Caption := Format(RS_SETTINGS_MSG_SAVED, [FSelectedKey]);
  except
    on E: Exception do
    begin
      DebugLn('[TFrameSettings.btnSaveClick] ERROR: ' + E.Message);
      lblStatus.Caption := Format(RS_SETTINGS_MSG_ERROR, [E.Message]);
    end;
  end;
end;

procedure TFrameSettings.btnRefreshClick(Sender: TObject);
begin
  LoadGrid;
  lblStatus.Caption := RS_SETTINGS_MSG_RELOADED;
end;

end.
