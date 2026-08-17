unit UOperationType;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
    TOperationType = class(TObject)
    private // self access only
        id : Integer;
        name : String;
        typ  : String;


    public // access by anything
        constructor Create();overload;
        constructor Create(newId:Integer;newName:String);

        procedure setId(newId:Integer);
        procedure setName(newName:String);
        procedure setTyp(newTyp:String);
        function getId():Integer;
        function getName():String;
        function getTyp():String;
    end;



implementation

    constructor TOperationType.Create(newId:Integer;newName:String);
    begin
         Self.id := newId;
         Self.name:= newName;
    end;

    constructor TOperationType.Create();
    begin
         inherited;
    end;

    procedure TOperationType.setId(newId:Integer);
    begin
         Self.id:=newId;
    end;

    procedure TOperationType.setName(newName:String);
    begin
         Self.name:=newName;
    end;

    procedure TOperationType.setTyp(newTyp:String);
    begin
         Self.typ:=newTyp;
    end;

    function TOperationType.getId():Integer;
    begin
         getId:=Self.id;
    end;

    function TOperationType.getName():String;
    begin
         getName:=Self.name;
    end;

    function TOperationType.getTyp():String;
    begin
         getTyp:=Self.typ;
    end;

end.

