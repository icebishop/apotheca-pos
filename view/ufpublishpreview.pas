{ Apothêca - Instagram Publication preview dialog

  Modal dialog that lists the products/services detected for publishing, with a
  checkbox per row, and asks the user to confirm before anything is posted to
  Instagram. Only checked items are returned for publishing.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UFPublishPreview;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Grids, StdCtrls, Buttons, Graphics,
  UResourceString;

type

  { TFormPublishPreview }

  TFormPublishPreview = class(TForm)
    lblHeader: TLabel;
    GridItems: TStringGrid;
    btnPublish: TBitBtn;
    btnCancel: TBitBtn;
    btnSelectAll: TBitBtn;
    btnSelectNone: TBitBtn;
    procedure btnPublishClick(Sender: TObject);
    procedure btnCancelClick(Sender: TObject);
    procedure btnSelectAllClick(Sender: TObject);
    procedure btnSelectNoneClick(Sender: TObject);
    procedure GridItemsCheckboxToggled(Sender: TObject; aCol, aRow: Integer;
      aState: TCheckboxState);
  private
    FMissingImages: Integer;
    procedure SetupColumns;
    procedure SetAllChecked(AChecked: Boolean);
    procedure UpdateHeader;
    function RowHasImage(ARow: Integer): Boolean;
  public
    { Populates the grid from lines of the form 'CatalogId'#9'Name'.
      All rows start checked. }
    procedure LoadItems(Items: TStrings);
    { Catalog ids whose checkbox is checked. Caller frees. }
    function CheckedIds: TStringList;
  end;

{ Shows the modal preview. Returns True if the user chose to publish.
  Items lines are 'CatalogId'#9'Name'. On OK, CheckedOut receives the checked
  catalog ids (caller frees). }
function ConfirmPublish(AOwner: TComponent; Items: TStrings;
  out CheckedOut: TStringList): Boolean;

implementation

{$R *.lfm}

const
  COL_CHECK = 0;
  COL_ID = 1;
  COL_NAME = 2;
  COL_IMAGE = 3;
  CHECKED = '1';
  UNCHECKED = '0';

function ConfirmPublish(AOwner: TComponent; Items: TStrings;
  out CheckedOut: TStringList): Boolean;
var
  Dlg: TFormPublishPreview;
begin
  CheckedOut := nil;
  Dlg := TFormPublishPreview.Create(AOwner);
  try
    Dlg.LoadItems(Items);
    Result := Dlg.ShowModal = mrOK;
    if Result then
      CheckedOut := Dlg.CheckedIds;
  finally
    Dlg.Free;
  end;
end;

{ TFormPublishPreview }

procedure TFormPublishPreview.SetupColumns;
begin
  { Build columns: a checkbox column + Id + Name + Image status. }
  GridItems.Columns.Clear;
  with GridItems.Columns.Add do
  begin
    Title.Caption := RS_PUBPREVIEW_COL_PUBLISH;
    Width := 64;
    ButtonStyle := cbsCheckboxColumn;
    ValueChecked := CHECKED;
    ValueUnchecked := UNCHECKED;
  end;
  with GridItems.Columns.Add do
  begin
    Title.Caption := RS_PUBPREVIEW_COL_ID;
    Width := 70;
    ReadOnly := True;
  end;
  with GridItems.Columns.Add do
  begin
    Title.Caption := RS_PUBPREVIEW_COL_NAME;
    Width := 300;
    ReadOnly := True;
  end;
  with GridItems.Columns.Add do
  begin
    Title.Caption := RS_PUBPREVIEW_COL_IMAGE;
    Width := 110;
    ReadOnly := True;
  end;
end;

procedure TFormPublishPreview.LoadItems(Items: TStrings);
var
  i: Integer;
  parts: TStringArray;
  cid, itemName, hasImg: String;
  hasImage: Boolean;
begin
  Caption := RS_PUBPREVIEW_TITLE;
  btnPublish.Caption := RS_PUBPREVIEW_BTN_PUBLISH;
  btnCancel.Caption := RS_PUBPREVIEW_BTN_CANCEL;
  btnSelectAll.Caption := RS_PUBPREVIEW_BTN_SELECT_ALL;
  btnSelectNone.Caption := RS_PUBPREVIEW_BTN_SELECT_NONE;

  SetupColumns;
  GridItems.RowCount := 1 + Items.Count;
  FMissingImages := 0;

  for i := 0 to Items.Count - 1 do
  begin
    { Line format: CatalogId<TAB>Name<TAB>HasImage ('1'/'0'). }
    parts := Items[i].Split(#9);
    cid := '';
    itemName := '';
    hasImg := '1';
    if Length(parts) > 0 then cid := parts[0];
    if Length(parts) > 1 then itemName := parts[1];
    if Length(parts) > 2 then hasImg := parts[2];
    hasImage := hasImg <> '0';

    GridItems.Cells[COL_ID, i + 1] := cid;
    GridItems.Cells[COL_NAME, i + 1] := itemName;
    if hasImage then
    begin
      GridItems.Cells[COL_IMAGE, i + 1] := RS_PUBPREVIEW_IMG_OK;
      GridItems.Cells[COL_CHECK, i + 1] := CHECKED;  { checked by default }
    end
    else
    begin
      GridItems.Cells[COL_IMAGE, i + 1] := RS_PUBPREVIEW_IMG_MISSING;
      { Items without an image cannot be published; leave them unchecked. }
      GridItems.Cells[COL_CHECK, i + 1] := UNCHECKED;
      Inc(FMissingImages);
    end;
  end;

  UpdateHeader;
end;

function TFormPublishPreview.RowHasImage(ARow: Integer): Boolean;
begin
  Result := GridItems.Cells[COL_IMAGE, ARow] <> RS_PUBPREVIEW_IMG_MISSING;
end;

function TFormPublishPreview.CheckedIds: TStringList;
var
  r: Integer;
begin
  Result := TStringList.Create;
  for r := 1 to GridItems.RowCount - 1 do
    if GridItems.Cells[COL_CHECK, r] = CHECKED then
      Result.Add(GridItems.Cells[COL_ID, r]);
end;

procedure TFormPublishPreview.SetAllChecked(AChecked: Boolean);
var
  r: Integer;
begin
  for r := 1 to GridItems.RowCount - 1 do
  begin
    { Never check an item that has no image. }
    if AChecked and (not RowHasImage(r)) then
      GridItems.Cells[COL_CHECK, r] := UNCHECKED
    else if AChecked then
      GridItems.Cells[COL_CHECK, r] := CHECKED
    else
      GridItems.Cells[COL_CHECK, r] := UNCHECKED;
  end;
  GridItems.Invalidate;
  UpdateHeader;
end;

procedure TFormPublishPreview.UpdateHeader;
var
  r, n: Integer;
  warn: String;
begin
  n := 0;
  for r := 1 to GridItems.RowCount - 1 do
    if GridItems.Cells[COL_CHECK, r] = CHECKED then
      Inc(n);
  warn := '';
  if FMissingImages > 0 then
    warn := Format(RS_PUBPREVIEW_WARN_NO_IMAGE, [FMissingImages]);
  lblHeader.Caption := Format(RS_PUBPREVIEW_SELECTED,
    [n, GridItems.RowCount - 1, warn]);
  btnPublish.Enabled := n > 0;
end;

procedure TFormPublishPreview.GridItemsCheckboxToggled(Sender: TObject;
  aCol, aRow: Integer; aState: TCheckboxState);
begin
  { Fires AFTER the checkbox cell value has changed (unlike OnButtonClick,
    which fires before), so the count is accurate here. }
  if aCol <> COL_CHECK then
    Exit;
  if (aRow < 1) or (aRow >= GridItems.RowCount) then
    Exit;

  { Do not allow checking an item that has no image; revert it. }
  if (aState = cbChecked) and (not RowHasImage(aRow)) then
    GridItems.Cells[COL_CHECK, aRow] := UNCHECKED;

  UpdateHeader;
end;

procedure TFormPublishPreview.btnSelectAllClick(Sender: TObject);
begin
  SetAllChecked(True);
end;

procedure TFormPublishPreview.btnSelectNoneClick(Sender: TObject);
begin
  SetAllChecked(False);
end;

procedure TFormPublishPreview.btnPublishClick(Sender: TObject);
begin
  ModalResult := mrOK;
end;

procedure TFormPublishPreview.btnCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

end.
