unit uServiceThread;

interface

uses
  System.Classes;

type
  TServiceThread = class(TThread)
  private
    { Private declarations }
    FPaused: Boolean;
  protected
    procedure Execute; override;
  public
    procedure Pause;
    procedure Continue;
  end;

implementation
uses uService;
{ 
  Important: Methods and properties of objects in visual components can only be
  used in a method called using Synchronize, for example,

      Synchronize(UpdateCaption);  

  and UpdateCaption could look like,

    procedure ServiceThread.UpdateCaption;
    begin
      Form1.Caption := 'Updated in a thread';
    end; 
    
    or 
    
    Synchronize( 
      procedure 
      begin
        Form1.Caption := 'Updated in thread via an anonymous method' 
      end
      )
    );
    
  where an anonymous method is passed.
  
  Similarly, the developer can call the Queue method with similar parameters as 
  above, instead passing another TThread class as the first parameter, putting
  the calling thread in a queue with the other thread.

}

{ ServiceThread }

procedure TServiceThread.Continue;
begin
  FPaused := False;
end;

procedure TServiceThread.Execute;
begin
  { Place thread code here }
  FPaused := False;
end;

procedure TServiceThread.Pause;
begin
  FPaused := True;
end;

end.
