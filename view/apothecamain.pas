unit ApothecaMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Buttons, ExtCtrls,
  ComCtrls, FileUtil,
  UFramePOS, UFramePurchase, UFrameProducts, UFramePeople, UFrameReports,
  UFrameCredits, UResourceString;

type
  TSectionType = (stPOS, stCredits, stPurchases, stProducts, stPeople, stReports);

  { TFormPrincipal }

  TFormPrincipal = class(TForm)
    BtnPOS: TBitBtn;
    BtnCredits: TBitBtn;
    BtnPurchases: TBitBtn;
    BtnProducts: TBitBtn;
    BtnPeople: TBitBtn;
    BtnReports: TBitBtn;
    PanelSidebar: TPanel;
    PanelContent: TPanel;
    StatusBar: TStatusBar;
    procedure BtnPOSClick(Sender: TObject);
    procedure BtnCreditsClick(Sender: TObject);
    procedure BtnPurchasesClick(Sender: TObject);
    procedure BtnProductsClick(Sender: TObject);
    procedure BtnPeopleClick(Sender: TObject);
    procedure BtnReportsClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FFramePOS: TFramePOS;
    FFrameCredits: TFrameCredits;
    FFramePurchase: TFramePurchase;
    FFrameProducts: TFrameProducts;
    FFramePeople: TFramePeople;
    FFrameReports: TFrameReports;
    FActiveFrame: TFrame;
    FActiveButton: TBitBtn;
    procedure CreateFrames;
    procedure NavigateTo(section: TSectionType);
    procedure HighlightActiveButton(btn: TBitBtn);
  public
    { public declarations }
  end;

var
  FormPrincipal: TFormPrincipal;

implementation

{ TFormPrincipal }

procedure TFormPrincipal.FormCreate(Sender: TObject);
var
  IconPath: String;

  procedure LoadButtonIcon(Btn: TBitBtn; const FileName: String);
  var
    PNG: TPortableNetworkGraphic;
    FullPath: String;
  begin
    FullPath := IconPath + FileName;
    if FileExists(FullPath) then
    begin
      PNG := TPortableNetworkGraphic.Create;
      try
        PNG.LoadFromFile(FullPath);
        Btn.Glyph.Assign(PNG);
      finally
        PNG.Free;
      end;
    end;
  end;

begin
  IconPath := ExtractFilePath(ParamStr(0)) + 'icons' + PathDelim;

  { Set sidebar captions from resource strings }
  BtnPOS.Caption := RS_NAV_SALES;
  BtnCredits.Caption := RS_NAV_CREDITS;
  BtnPurchases.Caption := RS_NAV_PURCHASES;
  BtnProducts.Caption := RS_NAV_PRODUCTS;
  BtnPeople.Caption := RS_NAV_PEOPLE;
  BtnReports.Caption := RS_NAV_REPORTS;

  { Load sidebar icons (24px white for dark background) }
  LoadButtonIcon(BtnPOS, 'ventas_24.png');
  LoadButtonIcon(BtnCredits, 'creditos_24.png');
  LoadButtonIcon(BtnPurchases, 'compras_24.png');
  LoadButtonIcon(BtnProducts, 'productos_24.png');
  LoadButtonIcon(BtnPeople, 'personas_24.png');
  LoadButtonIcon(BtnReports, 'reportes_24.png');

  CreateFrames;

  { Load icons for POS frame buttons (16px dark for light background) }
  LoadButtonIcon(FFramePOS.BtnSelectCustomer, 'customer_16.png');
  LoadButtonIcon(FFramePOS.BtnCompleteSale, 'check_16.png');

  { Load icons for Purchase frame buttons }
  LoadButtonIcon(FFramePurchase.BtnAddItem, 'add_16.png');
  LoadButtonIcon(FFramePurchase.BtnDeleteItem, 'delete_16.png');
  LoadButtonIcon(FFramePurchase.BtnSavePurchase, 'save_16.png');

  { Load icons for Products frame buttons }
  LoadButtonIcon(FFrameProducts.BtnAdd, 'add_16.png');
  LoadButtonIcon(FFrameProducts.BtnEdit, 'edit_16.png');
  LoadButtonIcon(FFrameProducts.BtnDelete, 'delete_16.png');

  { Load icons for People frame buttons }
  LoadButtonIcon(FFramePeople.BtnAdd, 'add_16.png');
  LoadButtonIcon(FFramePeople.BtnEdit, 'edit_16.png');
  LoadButtonIcon(FFramePeople.BtnDelete, 'delete_16.png');

  { Load icons for Reports frame buttons }
  LoadButtonIcon(FFrameReports.BtnRefresh, 'refresh_16.png');
  LoadButtonIcon(FFrameReports.BtnExportCSV, 'export_16.png');

  { Set frame button captions from resource strings }
  FFramePOS.BtnSelectCustomer.Caption := RS_POS_SELECT_CUSTOMER;
  FFramePOS.BtnCompleteSale.Caption := RS_POS_COMPLETE_SALE;
  FFramePOS.CheckCredit.Caption := RS_CREDITS_CHECKBOX;
  FFramePurchase.BtnAddItem.Caption := RS_PURCHASE_ADD;
  FFramePurchase.BtnDeleteItem.Caption := RS_PURCHASE_DELETE_ITEM;
  FFramePurchase.BtnSavePurchase.Caption := RS_PURCHASE_SAVE;
  FFrameProducts.BtnAdd.Caption := RS_PRODUCTS_BTN_NEW;
  FFrameProducts.BtnEdit.Caption := RS_PRODUCTS_BTN_EDIT;
  FFrameProducts.BtnDelete.Caption := RS_PRODUCTS_BTN_DELETE;
  FFramePeople.BtnAdd.Caption := RS_PEOPLE_BTN_NEW;
  FFramePeople.BtnEdit.Caption := RS_PEOPLE_BTN_EDIT;
  FFramePeople.BtnDelete.Caption := RS_PEOPLE_BTN_DELETE;
  FFrameReports.BtnRefresh.Caption := RS_REPORTS_REFRESH;
  FFrameReports.BtnExportCSV.Caption := RS_REPORTS_EXPORT;

  NavigateTo(stPOS);
end;

procedure TFormPrincipal.CreateFrames;
begin
  FFramePOS := TFramePOS.Create(Self);
  FFramePOS.Parent := PanelContent;
  FFramePOS.Align := alClient;
  FFramePOS.Visible := False;

  FFrameCredits := TFrameCredits.Create(Self);
  FFrameCredits.Parent := PanelContent;
  FFrameCredits.Align := alClient;
  FFrameCredits.Visible := False;

  FFramePurchase := TFramePurchase.Create(Self);
  FFramePurchase.Parent := PanelContent;
  FFramePurchase.Align := alClient;
  FFramePurchase.Visible := False;

  FFrameProducts := TFrameProducts.Create(Self);
  FFrameProducts.Parent := PanelContent;
  FFrameProducts.Align := alClient;
  FFrameProducts.Visible := False;

  FFramePeople := TFramePeople.Create(Self);
  FFramePeople.Parent := PanelContent;
  FFramePeople.Align := alClient;
  FFramePeople.Visible := False;

  FFrameReports := TFrameReports.Create(Self);
  FFrameReports.Parent := PanelContent;
  FFrameReports.Align := alClient;
  FFrameReports.Visible := False;
end;

procedure TFormPrincipal.NavigateTo(section: TSectionType);
var
  targetFrame: TFrame;
  targetBtn: TBitBtn;
begin
  case section of
    stPOS:       begin targetFrame := FFramePOS;       targetBtn := BtnPOS; end;
    stCredits:   begin targetFrame := FFrameCredits;   targetBtn := BtnCredits; end;
    stPurchases: begin targetFrame := FFramePurchase;  targetBtn := BtnPurchases; end;
    stProducts:  begin targetFrame := FFrameProducts;  targetBtn := BtnProducts; end;
    stPeople:    begin targetFrame := FFramePeople;    targetBtn := BtnPeople; end;
    stReports:   begin targetFrame := FFrameReports;   targetBtn := BtnReports; end;
  end;

  if FActiveFrame <> nil then
    FActiveFrame.Visible := False;

  targetFrame.Visible := True;
  targetFrame.Align := alClient;
  FActiveFrame := targetFrame;

  { Lazy-init reports when first navigated to }
  if section = stReports then
    FFrameReports.InitReports;

  HighlightActiveButton(targetBtn);
end;

procedure TFormPrincipal.HighlightActiveButton(btn: TBitBtn);
const
  COLOR_SIDEBAR = TColor($00404040);
  COLOR_ACTIVE  = TColor($00606060);
begin
  { Reset all buttons to sidebar base color }
  BtnPOS.Color := COLOR_SIDEBAR;
  BtnCredits.Color := COLOR_SIDEBAR;
  BtnPurchases.Color := COLOR_SIDEBAR;
  BtnProducts.Color := COLOR_SIDEBAR;
  BtnPeople.Color := COLOR_SIDEBAR;
  BtnReports.Color := COLOR_SIDEBAR;

  { Highlight the active button }
  btn.Color := COLOR_ACTIVE;
  FActiveButton := btn;
end;

procedure TFormPrincipal.BtnPOSClick(Sender: TObject);
begin
  NavigateTo(stPOS);
end;

procedure TFormPrincipal.BtnCreditsClick(Sender: TObject);
begin
  NavigateTo(stCredits);
end;

procedure TFormPrincipal.BtnPurchasesClick(Sender: TObject);
begin
  NavigateTo(stPurchases);
end;

procedure TFormPrincipal.BtnProductsClick(Sender: TObject);
begin
  NavigateTo(stProducts);
end;

procedure TFormPrincipal.BtnPeopleClick(Sender: TObject);
begin
  NavigateTo(stPeople);
end;

procedure TFormPrincipal.BtnReportsClick(Sender: TObject);
begin
  NavigateTo(stReports);
end;

initialization
  {$I apothecamain.lrs}

end.
