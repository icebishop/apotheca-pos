unit UPay;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, UPerson;

  type
    TPay = class(TObject)
    private // self access only
        id : Integer;
        date : TDateTime;
        value  : Real;
        person : TPerson;

    public // access by anything
        constructor create();

        procedure setId(newId:Integer);
        procedure setValue(newValue:Real);
        procedure setDate(newDate:TDateTime);
        procedure setPerson(newPerson:TPerson);

        function getId():Integer;
        function getValue():Real;
        function getDate():TDateTime;
        function getPerson():TPerson;
    end;
implementation
        constructor TPay.create();
        begin
             value:= 0;
             date:= Now;
        end;

        procedure TPay.setId(newId:Integer);
        begin
             Self.id:= newId;
        end;

        procedure TPay.setValue(newValue:Real);
        begin
             Self.value:= newValue;
        end;

        procedure TPay.setDate(newDate:TDateTime);
        begin
             Self.date:=  newDate;
        end;

        procedure TPay.setPerson(newPerson:TPerson);
        begin
             Self.person:= newPerson;
        end;

        function TPay.getId():Integer;
        begin
             getId := id;
        end;

        function TPay.getValue():Real;
        begin
             getValue := value;
        end;

        function TPay.getDate():TDateTime;
        begin
             getDate := date;
        end;

        function TPay.getPerson():TPerson;
        begin
             getperson := person;
        end;

end.

