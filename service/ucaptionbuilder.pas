{ Apothêca - Instagram Auto-Publish

  Caption builder. Composes an Instagram caption from a registry item: name,
  optional brand, description, price, optional discount, store link, and a
  hashtag set, constrained to Instagram's 2200-character limit.

  This source is free software; distributed under the GNU General Public License
  version 2 or (at your option) any later version, without any warranty.
}

unit UCaptionBuilder;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Types, Math, LazUTF8, URegistryItem;

type
  TCaptionBuilder = class(TObject)
  private
    class function CategoryHashtags(const Category: String): TStringArray;
    class function GeneralHashtags(): TStringArray;
    class function BuildBody(Item: TRegistryItem; const Description: String): String;
    class function TruncateDescription(Item: TRegistryItem;
      MaxBodyLen: Integer): String;
  public
    class function Build(Item: TRegistryItem): String;
    class function FormatPriceCop(Amount: Integer): String;   { 25000 -> "$25.000 COP" }
    class function DiscountPercent(Price, OriginalPrice: Integer): Integer; { half-up }
  end;

const
  MAX_CAPTION_LENGTH = 2200;
  MAX_HASHTAGS = 16;

implementation

class function TCaptionBuilder.CategoryHashtags(const Category: String): TStringArray;
begin
  if Category = 'Kits' then
    Result := ['#KitLimpieza', '#MantenimientoTaco',
      '#CuidadoTaco', '#LimpiezaBillar', '#KitBillar']
  else if Category = 'Casquillos' then
    Result := ['#Casquillos', '#CueTip', '#BotanaBillar',
      '#CasquilloProfesional', '#TipsBillar']
  else if Category = 'Tizas' then
    Result := ['#TizaBillar', '#BilliardChalk',
      '#TizaProfesional', '#ChalkPool', '#TizaPool']
  else if Category = 'Guantes' then
    Result := ['#GuanteBillar', '#BilliardGlove',
      '#GuanteProfesional', '#PoolGlove', '#GuantePool']
  else if Category = 'Accesorios' then
    Result := ['#AccesoriosBillar', '#PoolAccessories',
      '#AccesoriosTaco', '#BillarAccesorios', '#EquipoBillar']
  else
    Result := nil;
end;

class function TCaptionBuilder.GeneralHashtags(): TStringArray;
begin
  Result := ['#Billar', '#Pool', '#Carom', '#CueSports',
    '#BillarColombia', '#BillarProfesional', '#TiendaBillar', '#Billiards',
    '#PoolPlayer', '#CueLife'];
end;

class function TCaptionBuilder.FormatPriceCop(Amount: Integer): String;
var
  Digits, Grouped: String;
  i, Count: Integer;
begin
  Digits := IntToStr(Abs(Amount));
  Grouped := '';
  Count := 0;
  { Insert '.' every 3 digits from the right }
  for i := Length(Digits) downto 1 do
  begin
    Grouped := Digits[i] + Grouped;
    Inc(Count);
    if (Count mod 3 = 0) and (i > 1) then
      Grouped := '.' + Grouped;
  end;
  Result := '$' + Grouped + ' COP';
end;

class function TCaptionBuilder.DiscountPercent(Price, OriginalPrice: Integer): Integer;
begin
  if OriginalPrice <= 0 then
    Result := 0
  else
    Result := Floor((OriginalPrice - Price) / OriginalPrice * 100 + 0.5);
end;

class function TCaptionBuilder.BuildBody(Item: TRegistryItem;
  const Description: String): String;
var
  Lines: TStringList;
  DiscountLine: String;
begin
  Lines := TStringList.Create;
  try
    Lines.Add('🎱 ' + Item.Name);

    if (Item.Brand <> '') and (Item.Brand <> 'Don Pulido') then
      Lines.Add('Marca: ' + Item.Brand);

    Lines.Add('');
    Lines.Add(Description);
    Lines.Add('');

    Lines.Add('💰 ' + FormatPriceCop(Item.Price));

    if Item.HasOriginalPrice and (Item.OriginalPrice > Item.Price) then
    begin
      DiscountLine := '~' + FormatPriceCop(Item.OriginalPrice) + '~ ¡Ahorra ' +
        IntToStr(DiscountPercent(Item.Price, Item.OriginalPrice)) + '%!';
      Lines.Add(DiscountLine);
    end;

    Lines.Add('');
    Lines.Add('🛒 Disponible en donpulido.com');

    { Join with LF, no trailing newline }
    Lines.LineBreak := #10;
    Lines.SkipLastLineBreak := True;
    Result := Lines.Text;
  finally
    Lines.Free;
  end;
end;

class function TCaptionBuilder.TruncateDescription(Item: TRegistryItem;
  MaxBodyLen: Integer): String;
var
  Desc, Candidate, Body: String;
  Lo, Hi, Mid, DescLen: Integer;
begin
  Desc := Item.Description;
  DescLen := UTF8Length(Desc);
  Result := '';
  Lo := 0;
  Hi := DescLen;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    Candidate := UTF8Copy(Desc, 1, Mid);
    if Mid < DescLen then
      Candidate := TrimRight(Candidate) + '...';
    Body := BuildBody(Item, Candidate);
    if UTF8Length(Body) <= MaxBodyLen then
    begin
      Result := Candidate;
      Lo := Mid + 1;
    end
    else
      Hi := Mid - 1;
  end;
end;

class function TCaptionBuilder.Build(Item: TRegistryItem): String;
var
  Hashtags: TStringList;
  CatTags, GenTags: TStringArray;
  i, RemainingSlots: Integer;
  HashtagLine, CaptionBody, FullCaption, Suffix, TruncatedDesc: String;
  MaxBodyLen: Integer;
begin
  Hashtags := TStringList.Create;
  try
    Hashtags.Add('#DonPulido');

    CatTags := CategoryHashtags(Item.Category);
    for i := 0 to High(CatTags) do
      if i < 5 then
        Hashtags.Add(CatTags[i]);

    RemainingSlots := MAX_HASHTAGS - Hashtags.Count;
    GenTags := GeneralHashtags();
    for i := 0 to High(GenTags) do
      if i < RemainingSlots then
        Hashtags.Add(GenTags[i]);

    Hashtags.Delimiter := ' ';
    Hashtags.QuoteChar := #0;
    HashtagLine := Hashtags.DelimitedText;

    CaptionBody := BuildBody(Item, Item.Description);
    FullCaption := CaptionBody + #10#10 + HashtagLine;

    if UTF8Length(FullCaption) <= MAX_CAPTION_LENGTH then
    begin
      Result := FullCaption;
      Exit;
    end;

    { Too long: drop trailing hashtags one at a time. }
    while Hashtags.Count > 1 do
    begin
      Hashtags.Delete(Hashtags.Count - 1);
      HashtagLine := Hashtags.DelimitedText;
      FullCaption := CaptionBody + #10#10 + HashtagLine;
      if UTF8Length(FullCaption) <= MAX_CAPTION_LENGTH then
      begin
        Result := FullCaption;
        Exit;
      end;
    end;

    { Only #DonPulido remains and still too long: truncate description. }
    HashtagLine := Hashtags.DelimitedText;
    Suffix := #10#10 + HashtagLine;
    MaxBodyLen := MAX_CAPTION_LENGTH - UTF8Length(Suffix);
    TruncatedDesc := TruncateDescription(Item, MaxBodyLen);
    CaptionBody := BuildBody(Item, TruncatedDesc);
    Result := CaptionBody + Suffix;
  finally
    Hashtags.Free;
  end;
end;

end.
