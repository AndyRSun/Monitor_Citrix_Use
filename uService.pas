unit uService;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Classes, Vcl.Graphics, Vcl.Controls,  Vcl.SvcMgr, Vcl.Dialogs,
  uServiceThread, System.JSON,
  Data.DB, Data.Win.ADODB, System.IniFiles, IdHTTP, IdSSLOpenSSL,
  FireDAC.Stan.Intf, FireDAC.Stan.Option, FireDAC.Stan.Error, FireDAC.UI.Intf,
  FireDAC.Phys.Intf, FireDAC.Stan.Def, FireDAC.Stan.Pool, FireDAC.Stan.Async,
  FireDAC.Phys, FireDAC.Phys.MSSQL, FireDAC.Phys.MSSQLDef, FireDAC.VCLUI.Wait,
  FireDAC.Comp.Client, FireDAC.Stan.Param, FireDAC.DatS, FireDAC.DApt.Intf,
  FireDAC.DApt, FireDAC.Comp.DataSet;

type
  TMonitor_Citrix_Use_Service = class(TService)
    FDConnection: TFDConnection;
    FDManager: TFDManager;
    FDQuery: TFDQuery;
    FDStoredProc: TFDStoredProc;
    procedure ServiceStart(Sender: TService; var Started: Boolean);
    procedure ServiceStop(Sender: TService; var Stopped: Boolean);
    procedure ServicePause(Sender: TService; var Paused: Boolean);
    procedure ServiceContinue(Sender: TService; var Continued: Boolean);
    procedure ServiceExecute(Sender: TService);
  private
    { Private declarations }
    oParams : TStrings;
    FServiceThread: TServiceThread;
    IdHTTPWebApi: TIdHTTP;
    SSL: TIdSSLIOHandlerSocketOpenSSL;

    ServerName   : String;
    BaseName   : String;
    Url : string;
    Tocken : string;
    SQLConnectionString : String;
    NumberDayPreviousMonth : String;
    LastDayOperation : Integer;
    ConfigFileName : string;            // Путь к конфигурационному файлу config.ini
    LogFileName: string;                // Путь к файлам логирования
    OperateService : Boolean;           // Признак работы сервиса
    TimeStartExport : String;            // Время суток начала экспорта данных
    TimePeriod: Integer;
    CountRec : Integer;

    TS : TFormatsettings;

    WorkingFlag: Boolean;

    function GetDisConnectWorkTime():Boolean;
    function GetHalfPreparation():Boolean;
    function GetGlobalParams():Boolean;
    function GetConnectWorkTime():Boolean;
    function SelectFromBase():Boolean;
    function UsingCitrix(ADay:String; AMonth:String; AYear:String; AUIDStaff:String; APeriod:Integer; OUT AResult: String):Boolean;

    procedure GetExportData;
    procedure Log(Text:String);         // Процедура логирования сервиса
    procedure SetIdHTTP;
    procedure RunProcess;
    procedure Command_POST(AURL:String; AJSONSToSring:TStringStream; OUT ARespons:String; var ASResult:string);
    procedure Command_GET(AURL:String; OUT ARespons:String; var ASResult:string);
  public
    function GetServiceController: TServiceController; override;
    procedure AddMinutesToTimeStr(var TimeStr: String; MinutesToAdd: Integer);
    { Public declarations }
  end;

var
  Monitor_Citrix_Use_Service: TMonitor_Citrix_Use_Service;

implementation

{$R *.dfm}

procedure TMonitor_Citrix_Use_Service.AddMinutesToTimeStr(var TimeStr: String; MinutesToAdd: Integer);
var
  TimeVal: TDateTime;
  MinutesInDay: Integer;
begin
  TimeVal := StrToTime(TimeStr);
  MinutesInDay := 24 * 60;
  TimeVal := Frac(TimeVal + MinutesToAdd / MinutesInDay);
  TimeStr := FormatDateTime('hh:nn:ss', TimeVal);
end;


procedure TMonitor_Citrix_Use_Service.Log(Text:String);
var
  F : TextFile;
  sDate : String;
begin
  try
    LogFileName := ExtractFilePath(GetCommandLine) + 'LOG\';
    if not DirectoryExists(LogFileName) then ForceDirectories(LogFileName);
    LogFileName := LogFileName + FormatDateTime('yyyy-mm-dd', NOW) + '.log';
    AssignFile(F, LogFileName);
    if FileExists(LogFileName) then
      Append(F)
      else Rewrite(F);
    sDate := DateToStr(Date);
    sDate := sDate + ' ' + TimeToStr(Time);
    WriteLn(F, sDate + ': ' + Text);
  finally
    CloseFile(F);
  end;
end;

procedure TMonitor_Citrix_Use_Service.Command_POST(AURL:String; AJSONSToSring:TStringStream; OUT ARespons:String; var ASResult:string);
var
FRespons : TMemoryStream;
begin
  try
    SetIdHTTP;
    FRespons := TMemoryStream.Create;
    FRespons.Clear;
    IdHTTPWebApi.POST(AURL, AJSONSToSring, FRespons);
    FRespons.Position:=0;
    SetString(ARespons, PAnsiChar(FRespons.Memory), FRespons.Size);
    ASResult := IdHTTPWebApi.Response.ResponseText;
  finally
    if assigned(FRespons) then FreeAndNil(FRespons);
    if assigned(IdHTTPWebApi) then FreeAndNil(IdHTTPWebApi);
  end;
end;

procedure TMonitor_Citrix_Use_Service.Command_GET(AURL:String; OUT ARespons:String; var ASResult:string);
begin
  try
    SetIdHTTP;
    ARespons := IdHTTPWebApi.GET(AURL);
    ASResult := IdHTTPWebApi.Response.ResponseText;
  finally
    if assigned(IdHTTPWebApi) then FreeAndNil(IdHTTPWebApi);
  end;
end;


procedure TMonitor_Citrix_Use_Service.ServiceContinue(Sender: TService;
  var Continued: Boolean);
begin
   Log(#13#10 +
  '- - - - - - - - - - - - - - - - - - - П А У З А  С Е Р В И С А  - - - - - - - - - - - - - - - - - - -');
  Log('Возобновление работы сервиса фиксации отметок запуска CITRIX в УРВ'+ #13#10  +
      '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >'
  + #13#10);
  FServiceThread.Continue;
  Continued := True;
end;

procedure TMonitor_Citrix_Use_Service.ServiceExecute(Sender: TService);
begin
  while not Terminated do
  begin
//Log('Текущее время: ' + TimeToStr(Time));
    RunProcess;
    ServiceThread.ProcessRequests(false);
    TThread.Sleep(1000);
  end;
end;

procedure TMonitor_Citrix_Use_Service.RunProcess;
begin
//FS.TimeSeparator := ':';
//  GetLocaleFormatSettings(LOCALE_SYSTEM_DEFAULT, TS);
//  Log(TS.TimeSeparator + '; ' + TS.LongTimeFormat + '; ' + TS.ShortTimeFormat + '; ' + TS.TimeAMString + '; ' + TS.TimePMString);

//  Log('Текущее время: '+ TimeToStr(Time, TS));

//  Log('Назначенное время старта переноса данных: '+ TimeStartExport);


  if TimeToStr(Time, TS) = TimeStartExport
   then
    begin
      Log('Сработал таймер на назначенном времени запуска сервиса фиксации отметок запуска CITRIX в УРВ'  + #13#10  +
            '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >');

      if WorkingFlag then
      begin
        AddMinutesToTimeStr(TimeStartExport,5);
        Log('К сожалению предыдущий процесс еще не закончен. Добавим к времени запуска 5 минут. '  + #13#10  +
            'И запустим в: ' + TimeStartExport  + #13#10  +
            '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >' + #13#10  +
            '' + #13#10  +
            '' + #13#10  +
            '' + #13#10
            );
        TIniFile.Create(ConfigFileName).WriteString('Connect', 'TimeStartExport', TimeStartExport);
      end
      else
      begin
        if OperateService then
        begin
          if GetConnectWorkTime then
          begin
            if SelectFromBase then
            begin
              WorkingFlag := True;

              AddMinutesToTimeStr(TimeStartExport,TimePeriod);
              Log('Запускаем процесс. И сразу установим новое время следующего запуска (+' + TimePeriod.ToString + ' мин). '  + #13#10  +
                  'И следующее время запуска: ' + TimeStartExport  + #13#10  +
                  '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >' + #13#10  +
                  '' + #13#10  +
                  '' + #13#10  +
                  '' + #13#10
                  );
              TIniFile.Create(ConfigFileName).WriteString('Connect', 'TimeStartExport', TimeStartExport);

              GetExportData;

              WorkingFlag := False;
            end;
          end;
          GetDisConnectWorkTime;
   //       if Assigned(FDConnection) then FreeAndNil(FDConnection);
          if assigned(SSL) then FreeAndNil(SSL);
          if assigned(IdHTTPWebApi) then FreeAndNil(IdHTTPWebApi);
        end
        else Log('ОШИБКА: фиксации отметок запуска CITRIX в УРВ из-за ошибки обработки данных в Config.ini' + #13#10  +
              '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >');
        Log('Перезапуск таймера до ожидания ' + TimeStartExport + ' запуска сервиса фиксации отметок запуска CITRIX в УРВ'  + #13#10  +
          '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >');
        Log('');
        Log('');
        Log('');
        Log('');
        Log('<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >');

      end;
    end;
end;

function TMonitor_Citrix_Use_Service.UsingCitrix(ADay:String; AMonth:String; AYear:String; AUIDStaff:String; APeriod:Integer; OUT AResult: String):Boolean;
var
  Link, JSONStr, ARespons, Memo_Request: String;
  JSON, JSONRespons: TJSONObject;
  SS: TStringStream;
  SMemo_Request, SMemo_Respons, SMemo_Result : String;
  Line_Number : String;
begin
  Result := False;
  try
    if LENGTH(Tocken) > 0 then
      Link := Url +'/' + AUIDStaff +'&token=' + Tocken
    else
      Link := Url +'/' + AUIDStaff +'/';

    JSON := TJSONObject.Create;
    JSONRespons := TJSONObject.Create;
    SS := TStringStream.Create;

//    case rg_Period.ItemIndex of
//      1 :  JSON.AddPair('period', ADay + AMonth + AYear);
//      2 :  JSON.AddPair('period', ADay + AMonth + AYear);
//    end;

    if APeriod = 2 then JSON.AddPair('period', ADay + AMonth + AYear);

//    JSON.AddPair('period', ADay + AMonth + AYear);
    SS.WriteString(JSON.ToJSON);
    JSONStr := JSON.ToJSON();

    Memo_Request := Line_Number + Link + #13#10 + JSONStr;

    case APeriod of
      1: begin
         Command_GET(Link, ARespons, AResult);
         Log('    Отправлен запрос GET на Link: (' + Link + ') на получение фиксации отметок запуска CITRIX в УРВ ' + JSONStr);
      end;

      2: begin
         Command_POST(Link, SS, ARespons, AResult);
         Log('    Отправлен запрос POST на Link: (' + Link + ') на получение фиксации отметок запуска CITRIX в УРВ ' + JSONStr);
      end;
    end;

    SMemo_Respons := ARespons;
    Log('    Получен  ответ: ' + SMemo_Respons);
    SMemo_Result := AResult;
    Log('    Получен  результат: ' + SMemo_Result);

    AResult := ARespons;
    if Pos('"DATA":{', ARespons) > 0  then
    Result := True;
  finally
//    if assigned(FRespons) then FreeAndNil(FRespons);
    if assigned(JSON) then FreeAndNil(JSON);
    if assigned(JSONRespons) then FreeAndNil(JSONRespons);
    if assigned(SS) then FreeAndNil(SS);
  end;
end;

procedure TMonitor_Citrix_Use_Service.GetExportData;
var Answer : String;
  JSONValue : TJSONValue;
  JSONRespons : TJSONObject;
  i, j, s : integer;
  strBoolean : string;
  strDate : string;
  SL:TStrings;
  Right_away, Last_Month : TDate;
begin
  Right_away := NOW;
  Last_Month := IncMonth(Right_away, -1);
  if not FDQuery.IsEmpty then
  begin
    FDQuery.First;
    while not FDQuery.Eof do
    begin
      Answer := '';
      if (StrToIntDef(FormatDateTime('dd', Right_away),0) <= LastDayOperation) and (LastDayOperation > 0) then
      begin
        if UsingCitrix('',

                       FormatDateTime('mm', Last_Month),
                       FormatDateTime('yyyy', Last_Month),
                       FDQuery.FieldByName('UIDStaff').AsString, 2, Answer) then
        begin
  // ОБРАБОТКА массива данных (за весь месяц) метод POST
          try
            if assigned(SL) then FreeAndNil(SL);

            if assigned(JSONRespons) then FreeAndNil(JSONRespons);
            if assigned(JSONValue) then FreeAndNil(JSONValue);

            SL:=TStringlist.Create;
            SL.Clear;

            JSONRespons:=TJSONObject.Create;
            JSONValue := TJSONValue.Create;

            JSONRespons.Parse(TEncoding.UTF8.GetBytes(Answer),0);

            for i:=0 to TJSONObject(JSONRespons.Values['DATA']).Count -1 do
            begin
              strBoolean := TJSONObject(JSONRespons.Values['DATA']).Pairs[i].JsonValue.TOstring;
              strDATE :=  TJSONObject(JSONRespons.Values['DATA']).Pairs[i].JsonString.ToString;
    //               Логика
  //                    m_Test_Result.lines.add(strDATE+'::'+strBoolean);

              SL.Add(strDATE+'::'+strBoolean);   // Пишим в StringList
            end;

  //                 m_Test_Result.lines.add('');    // Читаем мз StringList
            for s := 0 to SL.Count -1 do
            begin
              if POS('::TRUE', UPPERCASE(SL.Strings[s])) > 0 then
              begin
                try
                  FDStoredProc.Params.Clear;
                  FDStoredProc.Prepared:= False;
                  FDStoredProc.Close;
                  FDStoredProc.StoredProcName := '_RemoteWork_Update';
                  FDStoredProc.Params.Add('@Year', ftString, 4, ptInput);
                  FDStoredProc.Params.Add('@Month', ftString, 2,  ptInput);
                  FDStoredProc.Params.Add('@Day', ftString, 2, ptInput);
                  FDStoredProc.Params.Add('@UIDStaff', ftString, 32, ptInput);
                  FDStoredProc.Prepared:= True;
                  FDStoredProc.ParamByName('@Year').Value := COPY(SL.Strings[s], 6, 4);
                  FDStoredProc.ParamByName('@Month').Value := COPY(SL.Strings[s], 4, 2);
                  FDStoredProc.ParamByName('@Day').Value := COPY(SL.Strings[s], 2, 2);
                  FDStoredProc.ParamByName('@UIDStaff').Value := FDQuery.FieldByName('UIDStaff').AsString;
                  FDStoredProc.ExecProc;
                  Log('        Обработано использованиие CITRIX сотрудником c UIDStaff: [' +
                  FDQuery.FieldByName('UIDStaff').AsString + '] дата: ['
                  + COPY(SL.Strings[s], 6, 4) + '-' +COPY(SL.Strings[s], 4, 2) + '-' + COPY(SL.Strings[s], 2, 2) + ']');
                except
                  Log('ОШИБКА: выполнения процедуры [dbo].[_RemoteWork_Update] в фиксации данных об использовании CITRIX сотрудником c UIDStaff: [' +
                  FDQuery.FieldByName('UIDStaff').AsString + '] дата: ['
                  + COPY(SL.Strings[s], 6, 4) + '-' +COPY(SL.Strings[s], 4, 2) + '-' + COPY(SL.Strings[s], 2, 2) + ']');
                end;
              end;
            end;
            {for s := 0 to SL.Count -1 do
            begin
              if POS('::TRUE', UPPERCASE(SL.Strings[s])) > 0 then
              m_Test_Result.lines.add(SL.Strings[s]);
            end;}
          finally
            if assigned(JSONRespons) then FreeAndNil(JSONRespons);
            if assigned(JSONValue) then FreeAndNil(JSONValue);
            if assigned(SL) then FreeAndNil(SL);
          end;
        end;
      end;
      {if FormatDateTime('dd', NOW) = '01' then  // 1-го числа каждого месяца получить данные за последний день предыдущего (метод GET)
      begin
         if UsingCitrix('', '', '', FDQuery.FieldByName('UIDStaff').AsString, 1,  Answer) then
         begin
    // ОБРАБОТКА одной даты (вчера)
          try
            if assigned(SL) then FreeAndNil(SL);

            if assigned(JSONRespons) then FreeAndNil(JSONRespons);
            if assigned(JSONValue) then FreeAndNil(JSONValue);

            JSONRespons:=TJSONObject.Create;
            JSONValue := TJSONValue.Create;

            SL:=TStringlist.Create;
            SL.Clear;

            JSONRespons.Parse(TEncoding.UTF8.GetBytes(Answer),0);

    //              for j:=0 to JSONRespons.Count -1 do
    //              begin
    //                if sameText(JSONREspons.Pairs[j].JsonString.ToString ,'DATA') then
    //                begin
                for i:=0 to TJSONObject(JSONRespons.Values['DATA']).Count -1 do
                begin
                  strBoolean := TJSONObject(JSONRespons.Values['DATA']).Pairs[i].JsonValue.TOstring;  //....Значение
                  strDATE := TJSONObject(JSONRespons.Values['DATA']).Pairs[i].JsonString.ToString; //Название
    //               Логика   из case ниже
    //                      m_Test_Result.lines.add(strDATE+'::'+strBoolean);

                  SL.Add(strDATE+'::'+strBoolean);   // Пишим в StringList
                end;
    //                end;
    //              end;

    //                m_Test_Result.lines.add('');    // Читаем мз StringList
            for s := 0 to SL.Count -1 do
            begin
              if POS('::TRUE', UPPERCASE(SL.Strings[s])) > 0 then
              begin
                try
                  FDStoredProc.Params.Clear;
                  FDStoredProc.Prepared:= False;
                  FDStoredProc.Close;
                  FDStoredProc.StoredProcName := '_RemoteWork_Update';
                  FDStoredProc.Params.Add('@Year', ftString, 4, ptInput);
                  FDStoredProc.Params.Add('@Month', ftString, 2, ptInput);
                  FDStoredProc.Params.Add('@Day', ftString, 2, ptInput);
                  FDStoredProc.Params.Add('@UIDStaff', ftString, 32, ptInput);
                  FDStoredProc.Prepared:= True;
                  FDStoredProc.ParamByName('@Year').Value := COPY(SL.Strings[s], 6, 4);
                  FDStoredProc.ParamByName('@Month').Value := COPY(SL.Strings[s], 4, 2);
                  FDStoredProc.ParamByName('@Day').Value := COPY(SL.Strings[s], 2, 2);
                  FDStoredProc.ParamByName('@UIDStaff').Value := FDQuery.FieldByName('UIDStaff').AsString;
                  FDStoredProc.ExecProc;
                  Log('        Обработано использованиие CITRIX сотрудником c UIDStaff: [' +
                  FDQuery.FieldByName('UIDStaff').AsString + '] дата: ['
                  + COPY(SL.Strings[s], 6, 4) + '-' +COPY(SL.Strings[s], 4, 2) + '-' + COPY(SL.Strings[s], 2, 2) + ']');
                except
                  Log('ОШИБКА: выполнения процедуры [dbo].[_RemoteWork_Update] в фиксации данных об использовании CITRIX сотрудником c UIDStaff: [' +
                  FDQuery.FieldByName('UIDStaff').AsString + '] дата: ['
                  + COPY(SL.Strings[s], 6, 4) + '-' +COPY(SL.Strings[s], 4, 2) + '-' + COPY(SL.Strings[s], 2, 2) + ']');
                end;
              end;
            end;
          finally
            if assigned(JSONRespons) then FreeAndNil(JSONRespons);
            if assigned(JSONValue) then FreeAndNil(JSONValue);
            if assigned(SL) then FreeAndNil(SL);
          end;
        end;
      end; }
//      else
//     begin
      if UsingCitrix('',
                     FormatDateTime('mm', Right_away),
                     FormatDateTime('yyyy', Right_away),
                     FDQuery.FieldByName('UIDStaff').AsString, 2, Answer) then
      begin
// ОБРАБОТКА массива данных (за весь месяц) метод POST
        try
          if assigned(SL) then FreeAndNil(SL);

          if assigned(JSONRespons) then FreeAndNil(JSONRespons);
          if assigned(JSONValue) then FreeAndNil(JSONValue);

          SL:=TStringlist.Create;
          SL.Clear;

          JSONRespons:=TJSONObject.Create;
          JSONValue := TJSONValue.Create;

          JSONRespons.Parse(TEncoding.UTF8.GetBytes(Answer),0);

          for i:=0 to TJSONObject(JSONRespons.Values['DATA']).Count -1 do
          begin
            strBoolean := TJSONObject(JSONRespons.Values['DATA']).Pairs[i].JsonValue.TOstring;
            strDATE :=  TJSONObject(JSONRespons.Values['DATA']).Pairs[i].JsonString.ToString;
  //               Логика
//                    m_Test_Result.lines.add(strDATE+'::'+strBoolean);

            SL.Add(strDATE+'::'+strBoolean);   // Пишим в StringList
          end;

//                 m_Test_Result.lines.add('');    // Читаем мз StringList
          for s := 0 to SL.Count -1 do
          begin
            if POS('::TRUE', UPPERCASE(SL.Strings[s])) > 0 then
            begin
              try
                FDStoredProc.Params.Clear;
                FDStoredProc.Prepared:= False;
                FDStoredProc.Close;
                FDStoredProc.StoredProcName := '_RemoteWork_Update';
                FDStoredProc.Params.Add('@Year', ftString, 4, ptInput);
                FDStoredProc.Params.Add('@Month', ftString, 2,  ptInput);
                FDStoredProc.Params.Add('@Day', ftString, 2, ptInput);
                FDStoredProc.Params.Add('@UIDStaff', ftString, 32, ptInput);
                FDStoredProc.Prepared:= True;
                FDStoredProc.ParamByName('@Year').Value := COPY(SL.Strings[s], 6, 4);
                FDStoredProc.ParamByName('@Month').Value := COPY(SL.Strings[s], 4, 2);
                FDStoredProc.ParamByName('@Day').Value := COPY(SL.Strings[s], 2, 2);
                FDStoredProc.ParamByName('@UIDStaff').Value := FDQuery.FieldByName('UIDStaff').AsString;
                FDStoredProc.ExecProc;
                Log('        Обработано использованиие CITRIX сотрудником c UIDStaff: [' +
                FDQuery.FieldByName('UIDStaff').AsString + '] дата: ['
                + COPY(SL.Strings[s], 6, 4) + '-' +COPY(SL.Strings[s], 4, 2) + '-' + COPY(SL.Strings[s], 2, 2) + ']');
              except
                Log('ОШИБКА: выполнения процедуры [dbo].[_RemoteWork_Update] в фиксации данных об использовании CITRIX сотрудником c UIDStaff: [' +
                FDQuery.FieldByName('UIDStaff').AsString + '] дата: ['
                + COPY(SL.Strings[s], 6, 4) + '-' +COPY(SL.Strings[s], 4, 2) + '-' + COPY(SL.Strings[s], 2, 2) + ']');
              end;
            end;
          end;
          {for s := 0 to SL.Count -1 do
          begin
            if POS('::TRUE', UPPERCASE(SL.Strings[s])) > 0 then
            m_Test_Result.lines.add(SL.Strings[s]);
          end;}
        finally
          if assigned(JSONRespons) then FreeAndNil(JSONRespons);
          if assigned(JSONValue) then FreeAndNil(JSONValue);
          if assigned(SL) then FreeAndNil(SL);
        end;
      end;
//      end;
      FDQuery.Next;
    end;
  end;

end;

function TMonitor_Citrix_Use_Service.SelectFromBase():Boolean;
begin
  Result := False;
  CountRec := 0;
  if FDConnection.Connected then
  begin
    try
      FDQuery.Filtered := False;
      FDQuery.Active := False;

      //FDQuery.SQL.Text := 'EXEC [dbo].[_GetRemoteWorkAllowed]';
      FDQuery.SQL.Text := 'EXEC [dbo].[_GetRemoteWorkAllowedAndHasNoCitrixInDay] ''' + FormatDateTime('yyyy-mm-dd', NOW) + '''';

      FDQuery.Active := True;
      FDQuery.Last;
      CountRec := FDQuery.RecordCount;
      FDQuery.First;
      if CountRec > 0 then Result := True
      else Result := False;
    except
      FDQuery.Active := False;
      Result := False;
    end;
  end else Result := False;
end;

procedure TMonitor_Citrix_Use_Service.ServicePause(Sender: TService;
  var Paused: Boolean);
begin
  Log(#13#10 +
  '- - - - - - - - - - - - - - - - - - - П А У З А  С Е Р В И С А  - - - - - - - - - - - - - - - - - - -');
  Log('Пауза работы сервиса фиксации отметок запуска CITRIX в УРВ'+ #13#10  +
      '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >'
  + #13#10);
  FServiceThread.Pause;
  Paused := True;
end;


procedure TMonitor_Citrix_Use_Service.ServiceStart(Sender: TService;
  var Started: Boolean);
begin
  Log(#13#10 + '- - - - - - - - - - - - - - - - С Т А Р Т   С Е Р В И С А - - - - - - - - - - - - - - - - - - - - -');
  Log('Старт сервиса фиксации отметок запуска CITRIX в УРВ'+ #13#10  +
  '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >'
  + #13#10);

//  GetLocaleFormatSettings(LOCALE_SYSTEM_DEFAULT, TS);
  TS:=TFormatsettings.Create('en-US');
  TS.TimeSeparator := ':';
  TS.LongTimeFormat := 'h:mm:ss';

  OperateService := False;
  ConfigFileName := ExtractFilePath(GetCommandLine) + 'Config.ini';
  OperateService := GetHalfPreparation;
  if OperateService then
  begin
    Log(#13#10
    + '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >');
    Log('Успешно инициализированны настроечные параметры из фала Config.ini' + #13#10);
    Log('Успешно проверено подключение к серверу УРВ'+ #13#10  +
    '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >'
    + #13#10);
    GetDisConnectWorkTime;
    Log('Ожидание наступления времени: ' + TimeStartExport + ' выполнения фиксации отметок вызова CITRIX в УРВ');
    FServiceThread := TServiceThread.Create(True);
    //FTimerThread.Priority:=tpnormal;
    FServiceThread.Start;
    Started:= True;
    WorkingFlag := False;
  end
  else
  begin
    Log(#13#10
    + '<==================================================================================================>');
    Log('ОШИБКА: Инициализации настроечные параметры из фала Config.ini' + #13#10);
    Log('ОШИБКА: Проверки подключения к серверу УРВ'+ #13#10  +
    '<==================================================================================================>'
    + #13#10);
    GetDisConnectWorkTime;
    if assigned(SSL) then FreeAndNil(SSL);
    if assigned(IdHTTPWebApi) then FreeAndNil(IdHTTPWebApi);
    FDQuery.Active := False;
    FDQuery.Close;

    if assigned(oParams) then FreeAndNil(oParams);
    if Assigned(FDConnection) then FreeAndNil(FDConnection);

    FServiceThread.Terminate;
    Started:= False;
  end;
end;

procedure TMonitor_Citrix_Use_Service.ServiceStop(Sender: TService;
  var Stopped: Boolean);
begin
  Log(#13#10
  + '- - - - - - - - - - - - - - О С Т А Н О В К А  С Е Р В И С А  - - - - - - - - - - - - - - - - - - -');
  Log('Оcтановка сервиса фиксации отметок запуска CITRIX в УРВ'+ #13#10  +
  '<- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - >'
  + #13#10);

  OperateService := False;
  GetDisConnectWorkTime;

  if Assigned(FDConnection) then FreeAndNil(FDConnection);
  if assigned(SSL) then FreeAndNil(SSL);
  if assigned(IdHTTPWebApi) then FreeAndNil(IdHTTPWebApi);

  if assigned(oParams) then FreeAndNil(oParams);
  if Assigned(FDConnection) then FreeAndNil(FDConnection);

  FServiceThread.Terminate;
  FServiceThread.WaitFor;
  FreeAndNil(FServiceThread);

  Stopped:= True;
end;

procedure ServiceController(CtrlCode: DWord); stdcall;
begin
  Monitor_Citrix_Use_Service.Controller(CtrlCode);
end;

function TMonitor_Citrix_Use_Service.GetServiceController: TServiceController;
begin
  Result := ServiceController;
end;

function TMonitor_Citrix_Use_Service.GetDisConnectWorkTime():Boolean;
begin
  Result := False;
  try
    FDQuery.Active := False;
    if FDConnection.Connected then FDConnection.Connected := False;
    Result := True;
    Log('Успешное отключение от сервера УРВ');
  except
    Result := False;
    Log('ОШИБКА: Не удалось отключиться от сервера УРВ');
  end;
end;

function TMonitor_Citrix_Use_Service.GetGlobalParams():Boolean;
begin
  Result := False;
  if FileExists(ConfigFileName) then
  begin
    with TIniFile.Create(ConfigFileName) do
    begin
      ServerName := ReadString('Connect', 'ServerName', '');
      BaseName := ReadString('Connect', 'BaseName', '');
      Url := ReadString('Connect', 'Url', '');
      TimeStartExport := ReadString('Connect', 'TimeStartExport', '');
      TimePeriod := ReadInteger('Connect', 'TimePeriod', 30);
      Tocken := ReadString('Connect', 'Tocken', '');
      NumberDayPreviousMonth := ReadString('Connect', 'NumberDay', '');
    end;

    Log('Получены данные подключения к серверу и базе данных из Config.ini');

    if Length(Trim(ServerName)) > 0 then Log('Имя сервера: ' + ServerName)
    else
    begin
      Log('ОШИБКА: Не указано имя сервера');
      exit;
    end;
    if Length(Trim(BaseName)) > 0 then Log('Название базы данных: ' + BaseName)
    else
    begin
      Log('ОШИБКА: Не указано название базы данных');
      exit;
    end;
    if Length(Trim(Url)) > 0 then Log('Адрес WEB сервиса: ' + Url)
    else
    begin
      Log('ОШИБКА: Не указано адрес WEB сервера');
      exit;
    end;
    if Length(Trim(TimeStartExport)) > 0 then Log('Время начала ежедневнего выполнения фиксации отметок запуска CITRIX в УРВ: ' + TimeStartExport)
    else
    begin
      Log('ОШИБКА: Не указан параметр TimeStartExport время начала ежедневнего выполнения фиксации отметок запуска CITRIX в УРВ');
      exit;
    end;

    if TimePeriod > 0 then Log('Время интервала запуска выполнения фиксации отметок запуска CITRIX в УРВ: ' + TimePeriod.ToString)
    else
    begin
      Log('ОШИБКА: Не указан параметр TimePeriod время интервала запуска выполнения фиксации отметок запуска CITRIX в УРВ');
      exit;
    end;

{
    SQLConnectionString := 'Provider=SQLNCLI11.1;Integrated Security=SSPI;Persist Security Info=False;'
    + 'User ID="";Initial Catalog='+BaseName+ ';Data Source=' +ServerName+';Use Procedure for Prepare=1;'
    + 'Auto Translate=True;Packet Size=4096;Workstation ID=05-mshulgin;Initial File Name="";'
    + 'Use Encryption for Data=False;Tag with column collation when possible=False;MARS Connection=False;'
    + 'DataTypeCompatibility=0;Trust Server Certificate=False;Application Intent=READWRITE;';
}
    SQLConnectionString := 'Provider=SQLOLEDB.1;Integrated Security=SSPI;Persist Security Info=False;'
    + 'Initial Catalog=' +BaseName+ ';Data Source=' +ServerName+ ';';

    if Length(Trim(Tocken)) > 0 then Log('Tocken WEB сервера: ' + Tocken)
    else
    begin
      Log('ОШИБКА: Не указано Tocken WEB сервера');
      exit;
    end;
    if Length(Trim(NumberDayPreviousMonth)) > 0 then
    begin
      LastDayOperation := StrToIntDef(Trim(NumberDayPreviousMonth), 0);
      LastDayOperation := Abs(LastDayOperation);
      if LastDayOperation > 15 then
      begin
        LastDayOperation := 15;
        Log('ОШИБКА: Дата текущего месяца, до которой будут запрашиваться данные из WSSTAT за предыдущий месяц не может быть больще 15-го числа');
        exit;
      end;
      if LastDayOperation > 0 then
      Log('Запрос данных из WSSTAT за предыдущий месяц будет до ' + IntToStr(LastDayOperation) + ' числа текущего месяца')
      else
      Log('Не будут запрашиваться данных из WSSTAT за предыдущий месяц');
    end
    else
    begin
      Log('ОШИБКА: Не указана дата текущего месяца, до которой будут запрашиваться данные из WSSTAT за предыдущий месяц');
      exit;
    end;
    oParams := TStringList.Create;
    oParams.Add('Server=' + ServerName);
    oParams.Add('Database=' + BaseName);
    oParams.Add('OSAuthent=Yes');
    FDManager.AddConnectionDef('CDF', 'MSSQL', oParams);
    FDConnection.ConnectionDefName := 'CDF';

    Result := True;
  end
  else
    Log('ОШИБКА: Не найден конфигурационный файл Config.ini с параметрами сервиса'  + #13#10  +
    '<==================================================================================================>');
end;

function TMonitor_Citrix_Use_Service.GetConnectWorkTime():Boolean;
begin
  Result := False;
  try
    FDConnection.Connected := True;
    Log('Выполнено подключение к SQL серверу ' + #13#10  +
    '<-------------------------------------------------------------------------------------------------->');
    Result := True;
  except
    Result := False;
    FDConnection.Connected := False;
    Log('ОШИБКА: Подключение к SQL серверу не выполнено'+ #13#10  +
    '<-------------------------------------------------------------------------------------------------->');
  end;

  {
  Result := False;                     //Provider=SQLOLEDB.1;Integrated Security=SSPI;Persist Security Info=False;Data Source=SQ41505
  ADOConnection.Connected := False;
  ADOConnection.ConnectionString := SQLConnectionString;
  ADOConnection.LoginPrompt := False;
  try
    ADOConnection.Connected := True;
    Log('Выполнено подключение к SQL серверу: ' + SQLConnectionString + #13#10  +
    '<-------------------------------------------------------------------------------------------------->');
    Result := True;
  except
    Log('ОШИБКА: Подключение к SQL серверу: ' + SQLConnectionString + ' не выполнено'+ #13#10  +
    '<-------------------------------------------------------------------------------------------------->');
    ADOConnection.Connected := False;
  end;
  }
end;


function TMonitor_Citrix_Use_Service.GetHalfPreparation():Boolean;
begin
  Result := False;
  if FileExists(ConfigFileName) then
  begin
    if GetGlobalParams then
    begin
      if GetConnectWorkTime then
      begin
        Result := True;
      end;
    end;
  end
  else
    Log('ОШИБКА: Не найден файл Config.ini с настроечными параметрами'  + #13#10  +
    '<==================================================================================================>');
end;


procedure TMonitor_Citrix_Use_Service.SetIdHTTP;
begin
  if assigned(SSL) then FreeAndNil(SSL);
  if assigned(IdHTTPWebApi) then FreeAndNil(IdHTTPWebApi);

  if not assigned(IdHTTPWebApi) then
    IdHTTPWebApi := TIdHTTP.Create(nil);

  if not assigned(SSL) then
    SSL := TIdSSLIOHandlerSocketOpenSSL.Create(Monitor_Citrix_Use_Service);

  SSL.SSLOptions.Mode := sslmClient;

  SSL.RecvBufferSize := 32768;
  SSL.SendBufferSize := 32768;
  SSL.MaxLineLength := 16384;

  SSL.SSLOptions.SSLVersions := [sslvSSLv2,sslvSSLv3,sslvTLSv1,sslvTLSv1_1,sslvTLSv1_2];
  //SSL.SSLOptions.SSLVersions := [sslvTLSv1_2];
  SSL.SSLOptions.Method := sslvSSLv23;
  //SSL.SSLOptions.Method := sslvTLSv1_2;
  IdHTTPWebApi.IOHandler := SSL;

  IdHTTPWebApi.AllowCookies := True;
  IdHTTPWebApi.Request.ContentType := 'applicatio/json; charset=utf-8';
  IdHTTPWebApi.Request.CharSet := 'utf-8';
  IdHTTPWebApi.Request.UserAgent :='Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.0)';
  IdHTTPWebApi.HandleRedirects :=true;
  IdHTTPWebApi.HTTPOptions := IdHTTPWebApi.HTTPOptions + [hoNoProtocolErrorException];
  IdHTTPWebApi.MaxAuthRetries := 10;
end;

end.
