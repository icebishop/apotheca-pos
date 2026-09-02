{ Feature: instagram-auto-publish
  Property 1: New-item detection
  Property 8b: Catalog id mapping

  Property-based tests for the detection rule (visible AND mappable to a
  product.id AND not in the published set) and TDataPublication.TryParseCatalogId.

  **Validates: Requirements 3.2, 4.1, 4.2**
}

unit test_detector_publish;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testregistry,
  URegistryItem, UDataPublication;

type
  TTestDetectorPublish = class(TTestCase)
  private
    { The detection rule as documented in the design (Property 1). }
    function IsNew(Item: TRegistryItem; PublishedIds: TStrings): Boolean;
  published
    procedure Test_TryParseCatalogId_Property;
    procedure Test_Detection_Rule_Property;
    procedure Test_Detection_PreservesOrder;
  end;

implementation

const
  ITERATIONS = 200;

function TTestDetectorPublish.IsNew(Item: TRegistryItem;
  PublishedIds: TStrings): Boolean;
var
  ProductId: Integer;
begin
  Result := False;
  if not Item.IsVisible then
    Exit;
  if not TDataPublication.TryParseCatalogId(Item.Id, ProductId) then
    Exit;
  Result := PublishedIds.IndexOf(IntToStr(ProductId)) < 0;
end;

{ Catalog id maps to product.id: a raw integer id (preferred) or a legacy
  "<p|s><int>" prefixed id; anything else does not map. }
procedure TTestDetectorPublish.Test_TryParseCatalogId_Property;
var
  Iteration, N, Parsed: Integer;
  Prefix: Char;
  Id: String;
begin
  { Fixed cases }
  AssertTrue('42 maps (raw id)', TDataPublication.TryParseCatalogId('42', Parsed));
  AssertEquals('42 -> 42', 42, Parsed);
  AssertTrue('p42 maps (legacy)', TDataPublication.TryParseCatalogId('p42', Parsed));
  AssertEquals('p42 -> 42', 42, Parsed);
  AssertTrue('s3 maps (legacy)', TDataPublication.TryParseCatalogId('s3', Parsed));
  AssertEquals('s3 -> 3', 3, Parsed);
  AssertFalse('p7c does not map', TDataPublication.TryParseCatalogId('p7c', Parsed));
  AssertFalse('empty does not map', TDataPublication.TryParseCatalogId('', Parsed));
  AssertFalse('non-numeric does not map', TDataPublication.TryParseCatalogId('abc', Parsed));
  AssertFalse('x99 wrong prefix', TDataPublication.TryParseCatalogId('x99', Parsed));

  for Iteration := 1 to ITERATIONS do
  begin
    N := Random(1000000);
    { Raw integer id maps to itself. }
    Id := IntToStr(N);
    AssertTrue(Format('Iteration %d: %s should map', [Iteration, Id]),
      TDataPublication.TryParseCatalogId(Id, Parsed));
    AssertEquals(Format('Iteration %d: %s -> %d', [Iteration, Id, N]),
      N, Parsed);

    { Legacy prefixed id still maps. }
    if Random(2) = 0 then Prefix := 'p' else Prefix := 's';
    Id := Prefix + IntToStr(N);
    AssertTrue(Format('Iteration %d: %s should map', [Iteration, Id]),
      TDataPublication.TryParseCatalogId(Id, Parsed));
    AssertEquals(Format('Iteration %d: %s -> %d', [Iteration, Id, N]),
      N, Parsed);

    { A trailing non-digit -> must fail. }
    Id := IntToStr(N) + 'z';
    AssertFalse(Format('Iteration %d: %s should not map', [Iteration, Id]),
      TDataPublication.TryParseCatalogId(Id, Parsed));
  end;
end;

{ Property 1: item is new iff visible AND mappable AND not published. }
procedure TTestDetectorPublish.Test_Detection_Rule_Property;
var
  Iteration, N, Parsed: Integer;
  Item: TRegistryItem;
  Published: TStringList;
  Visible, Mappable, AlreadyPub, Expected: Boolean;
begin
  for Iteration := 1 to ITERATIONS do
  begin
    Published := TStringList.Create;
    Item := TRegistryItem.Create;
    try
      N := 1 + Random(10000);
      Visible := Random(2) = 0;
      Mappable := Random(2) = 0;
      AlreadyPub := Random(2) = 0;

      Item.IsVisible := Visible;
      if Mappable then
        Item.Id := 'p' + IntToStr(N)
      else
        Item.Id := 'p' + IntToStr(N) + 'c';  { non-integer remainder }

      if AlreadyPub then
        Published.Add(IntToStr(N));

      { Expected per the documented rule. }
      Expected := Visible and Mappable and (not AlreadyPub);
      { Note: when not mappable, TryParseCatalogId fails -> not new regardless. }
      if not Mappable then
        Expected := False;

      AssertEquals(
        Format('Iteration %d: id=%s visible=%s mappable=%s published=%s',
          [Iteration, Item.Id, BoolToStr(Visible, True),
           BoolToStr(Mappable, True), BoolToStr(AlreadyPub, True)]),
        Expected, IsNew(Item, Published));

      { Silence unused-var hint for Parsed by touching TryParseCatalogId. }
      TDataPublication.TryParseCatalogId(Item.Id, Parsed);
    finally
      Item.Free;
      Published.Free;
    end;
  end;
end;

{ Property 1 (order): filtering a list keeps source order. }
procedure TTestDetectorPublish.Test_Detection_PreservesOrder;
var
  Items: array of TRegistryItem;
  Published: TStringList;
  NewOrder: TStringList;
  i: Integer;
begin
  SetLength(Items, 5);
  Published := TStringList.Create;
  NewOrder := TStringList.Create;
  try
    for i := 0 to 4 do
    begin
      Items[i] := TRegistryItem.Create;
      Items[i].Id := 'p' + IntToStr(i + 1);
      Items[i].IsVisible := True;
    end;
    { Mark p2 and p4 as already published. }
    Published.Add('2');
    Published.Add('4');

    for i := 0 to 4 do
      if IsNew(Items[i], Published) then
        NewOrder.Add(Items[i].Id);

    { Expected new items in order: p1, p3, p5. }
    AssertEquals('count', 3, NewOrder.Count);
    AssertEquals('first', 'p1', NewOrder[0]);
    AssertEquals('second', 'p3', NewOrder[1]);
    AssertEquals('third', 'p5', NewOrder[2]);
  finally
    for i := 0 to 4 do
      Items[i].Free;
    Published.Free;
    NewOrder.Free;
  end;
end;

initialization
  Randomize;
  RegisterTest(TTestDetectorPublish);

end.
