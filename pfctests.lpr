program pinttests;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, GuiTestRunner, tstack, IStack;

{$R *.res}

begin
  Application.Title:='PFCTests';
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

