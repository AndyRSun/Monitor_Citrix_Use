  DisplayName = 'Monitor_Citrix_Use_Service'
  OnContinue = ServiceContinue
  OnExecute = ServiceExecute
  OnPause = ServicePause
  OnStart = ServiceStart
  OnStop = ServiceStop
  Height = 150
  Width = 430
  object FDConnection: TFDConnection
    Params.Strings = (
      'DriverID=MSSQL')
    Left = 104
    Top = 80
  end
  object FDManager: TFDManager
    DriverDefFileAutoLoad = False
    ConnectionDefFileAutoLoad = False
    FormatOptions.AssignedValues = [fvMapRules]
    FormatOptions.OwnMapRules = True
    FormatOptions.MapRules = <>
    Left = 48
    Top = 80
  end
  object FDQuery: TFDQuery
    Connection = FDConnection
    Left = 104
    Top = 24
  end
  object FDStoredProc: TFDStoredProc
    Connection = FDConnection
    Left = 184
    Top = 32
  end
end