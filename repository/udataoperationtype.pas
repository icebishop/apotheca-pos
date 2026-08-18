unit UDataOperationType;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UData, UOperationType;

  type
  TDataOperationType = class(TData)
  private
    // Data/method defs local to this Unit
  protected
    // Data/method defs local to this class + descendants
  public

    function get(operationTypeId:Integer):TOperationType;
    function getByDescription(description:String):TOperationType;

  published
    // Externally interrogatable public definitions
end;

implementation

   function TDataOperationType.get(operationTypeId:Integer):TOperationType;
   var
      operationType:TOperationType;
   begin
        try
         Self.getQuery().SQL.Text := 'select * from operationType where id = :id';
         Self.getQuery().Params.ParamByName('id').AsInteger := operationTypeId;
         Self.getQuery().Open;

         Self.getQuery().First;
         while not Self.getQuery().EOF do
         begin
              operationType := TOperationType.Create;
              operationType.setId(Self.getQuery().FieldByName('id').AsInteger);
              operationType.setName(Self.getQuery().FieldByName('description').AsString);
              operationType.setTyp(Self.getQuery().FieldByName('type').AsString);
              Self.getQuery().Next;
         end;
         get := operationType;
         Self.getQuery().Close;
        except
         get := nil;
        end;
   end;

   function TDataOperationType.getByDescription(description:String):TOperationType;
   var
      operationType:TOperationType;
   begin
        try
         Self.getQuery().SQL.Text := 'select * from operationType where description = :desc';
         Self.getQuery().Params.ParamByName('desc').AsString := description;
         Self.getQuery().Open;

         operationType := nil;
         Self.getQuery().First;
         if not Self.getQuery().EOF then
         begin
              operationType := TOperationType.Create;
              operationType.setId(Self.getQuery().FieldByName('id').AsInteger);
              operationType.setName(Self.getQuery().FieldByName('description').AsString);
              operationType.setTyp(Self.getQuery().FieldByName('type').AsString);
         end;
         getByDescription := operationType;
         Self.getQuery().Close;
        except
         getByDescription := nil;
        end;
   end;

end.

