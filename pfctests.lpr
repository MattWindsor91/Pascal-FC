program pinttests;

{$mode objfpc}{$H+}

uses
  Interfaces, Forms, GuiTestRunner, TStack, TStrUtil, Treader;

{$R *.res}

begin
  Application.Title:='PFCTests';
  Application.Initialize;
  Application.CreateForm(TGuiTestRunner, TestRunner);
  Application.Run;
end.

