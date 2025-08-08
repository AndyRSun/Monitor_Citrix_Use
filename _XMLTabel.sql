USE [worktime]
GO
/****** Object:  StoredProcedure [dbo].[_XMLTabel]    Script Date: 08.08.2025 20:31:12 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[_XMLTabel]
	@Query NTEXT
AS
begin
DECLARE @DEBUG_MODE int = 0
 
 declare @Delay int =0
 declare @DT_Speed_Start datetime=GetDate()
 
 
	SET DATEFIRST 1;
 
	DECLARE @hdoc int;
 
 	-- проверка корректности xml?
	EXEC sp_xml_preparedocument @hdoc OUTPUT, @Query;
	IF @hdoc = 0
		BEGIN
				  RAISERROR ('_XMLTabel: Error prepare XML document', 16, 1)
				  RETURN
		END
 IF @DEBUG_MODE=1 BEGIN set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
 set @DT_Speed_Start=GetDate()
 print '[1]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
 END

	-- получаем параметры запроса из xml --переделан месяц/год на с/по
	SELECT DateFrom, DateTo, CAST('' AS VARCHAR(10)) AS Month, CAST('' AS VARCHAR(10)) AS Year, 
		Path, isAdmin, collapse, CanPostprocess
	INTO
		#Tabel
	FROM
		OPENXML(@hdoc, '/GetTabel', 1)with(
			DateFrom varchar(10)'@DateFrom',
			DateTo varchar(10)'@DateTo',
			Path varchar(800)'@Path',
			isAdmin varchar(255)'@isAdmin',
			collapse varchar(255)'@collapse',
			CanPostprocess varchar(255)'@CanPostprocess'
		);
	
	UPDATE  #Tabel SET MONTH = MONTH(CAST(DateFrom as datetime)), YEAR = YEAR(CAST(DateFrom as datetime))	
		
	--получим граничные даты
	declare @DateFrom datetime, @DateTo datetime, @maxTo int, @validDate datetime;
	 --Получим две переменные для генерации УРЛ Симпла
  DECLARE @collapse varchar(255), @isAdmin varchar(255) 
 
   select top 1 @DateFrom = CAST(DateFrom as datetime) , @DateTo = CAST(DateTo as datetime)
   , @collapse = collapse, @isAdmin = isAdmin 
   from #Tabel;
   
   select
		@validDate = dateadd(day, -2, dbo.DateTimeToDate(getdate(), default)),
		@maxTo = datepart(day, @validDate);
 
	if @DateTo <= @validDate set @maxTo = 100; --снятие любых ограничений
 
	--get UIDStaff list
	SELECT
		_Person.UIDstaff UIDStaff,
		Name FIO,
		TabelNumber,
		0 as TimeLost,
		0 as UpNorma,
		0 as SumNorma,
		0 as SumRemote,
		0 as HasRemoteViolation,
		0 as week_Work,
		0 as week_Kratk,
		0 AS week_KratkTM,
		0 as week_Remote,
		0 as week_Command,
		0 as week_Edu,
		0 as week_NORMA,
		0 as week_Looses,
		0 as RemoteRatio
	INTO
		#Peoples
	FROM
		OPENXML(@hdoc,'/GetTabel/UIDStaff',1) with (
			UIDStaff varchar(32)'text()'
		) Query
		INNER JOIN _Person on _Person.UIDStaff = Query.UIDStaff
 
	EXEC sp_xml_removedocument @hdoc
 
 DECLARE @RemoteWorkAllowance TABLE (id int identity(1,1),UNID varchar(32), Allow int null,Limit float null, NewSumNorma int null,RemoteTotal int null,RemoteRatio float null,HasRemoteViolation int null)
 INSERT @RemoteWorkAllowance
 select R.UIDStaff,ISNULL(isRemoteWorkAllowed,0),ISNULL(RemoteWorkLimit,0),null,null,null,null
 from #Peoples P, 
  (
				select UIDStaff,RemoteWorkLimit,isRemoteWorkAllowed
				from (
						select
							R.UIDStaff,
							case
								when ISNULL(isRemoteWorkAllowed,0)=0 then 0
								else ISNULL(RemoteWorkLimit,0)
							end as RemoteWorkLimit,
							ISNULL(isRemoteWorkAllowed,0) isRemoteWorkAllowed,
							row_number() over (partition by R.UIDStaff order by StartDate desc ) rank
						from _Regulation  R JOIN #Peoples P on P.UIDStaff = R.UIDStaff
						WHERE StartDate <= @DateTo
					) a
				where a.rank=1
				) R
		WHERE R.UIDStaff=P.UIDStaff

 --and R.StartDate <= @DateTo
 --ORDER BY R.StartDate DESC

 /*SELECT TOP 1 @isRemoteWorkAllowed=ISNULL(isRemoteWorkAllowed,0), @RemoteWorkLimit=ISNULL(RemoteWorkLimit,0),@IsSmena=isSmena FROM _Regulation
			WHERE
				_Regulation.UIDStaff = @UidStaff and
				_Regulation.StartDate <= @DateTo
			ORDER BY _Regulation.StartDate DESC*/

 IF @DEBUG_MODE=1 BEGIN set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
 set @DT_Speed_Start=GetDate()
 print '[2]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
 END
 
	/*BEGIN: Режим работы: Удалёнка*/
	--Узнаем, можно ли работать удалённо и в каких пределах
	--DECLARE @isRemoteWorkAllowed int
	DECLARE @RemoteWorkLimit float
	DECLARE @UidStaff varchar(32)
	SELECT TOP 1 @UidStaff=UIDSTAFF from #Peoples
	DECLARE @IsSmena int
 
	-- По комментарию Мысина С.В. : "Если меняется режим работы, то для расчета всего месяца брать последнее значение разрешённого процентажа"
	/*SELECT TOP 1 @isRemoteWorkAllowed=ISNULL(isRemoteWorkAllowed,0), @RemoteWorkLimit=ISNULL(RemoteWorkLimit,0),@IsSmena=isSmena FROM _Regulation
			WHERE
				_Regulation.UIDStaff = @UidStaff and
				_Regulation.StartDate <= @DateTo
			ORDER BY _Regulation.StartDate DESC*/
    /*END: Режим работы: Удалёнка*/
 
 
	
 IF @DEBUG_MODE=1 BEGIN set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
 set @DT_Speed_Start=GetDate()
 print '[3]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
 END
	select
--> IT-SIT_00646.29.2023  MShulgin
tm.ID as ID_TabelMain,
--< IT-SIT_00646.29.2023  MShulgin
		tm.UIDStaff, -- сотрудник
		DATEPART(day, tm.DateCalc) Day, -- день месяца
		(SELECT TOP 1 _Regulation.Period FROM _Regulation WHERE _Regulation.UIDStaff = tm.UIDStaff AND _Regulation.StartDate <= tm.DateCalc ORDER BY _Regulation.StartDate DESC) AS Period, -- период на который считается норма выработки только для isSmena = 2
		CASE WHEN (SELECT TOP 1 _Regulation.Period FROM _Regulation WHERE _Regulation.UIDStaff = tm.UIDStaff AND _Regulation.StartDate <= tm.DateCalc ORDER BY _Regulation.StartDate DESC)='week' then DATEPART(week, tm.DateCalc) ELSE 0 END AS weekNumm,
		tm.DateCalc,
		tm.TimeRequestReCalc,
		MAX(rf.isViolation) hasViolation, -- select * from _Reference where ID in (54,100,101,102,103,105,104)
		--(select case Abbrev when '' then '' else Abbrev + ';' end from _Reference where
		--	ID in (select IDReference from _TabelExt where IDTabelMain= _TabelMain.ID) for xml path('')) Abbrev,
		--RTRIM(MAX(rf.Abbrev)) Abbrev, -- сокр. наименование интервала
		(select top 1
			case
				when len(t.Abbrev) > 0 then Left(t.Abbrev, len(t.Abbrev) - 1)
				else ''
			end
		from -- список сокращений через зпт, удалим посл зпт
			(select
				isNull(
					(select Abbrev + ',' from
						(select distinct Abbrev from _Reference where
							Abbrev <> '' and
							ID in (select distinct IDReference from _TabelExt where IDTabelMain= tm.ID)
						) t
						for xml path('')
					)
				,' ') Abbrev
			)t
		) Abbrev,
		--(select cast(IDReference as varchar(max)) + ',' from _TabelExt where IDTabelMain= tm.ID for xml path('')) Abbrev,
		SUM(CASE WHEN te.IDReference=100 THEN te.LongSecond ELSE 0 END) Norma,
		SUM(CASE WHEN te.IDReference=98 THEN te.LongSecond ELSE 0 END) NormaNRV,
		SUM(CASE WHEN te.IDReference in (1) and te.isPrivate=0  THEN te.LongSecond ELSE 0 END) Otpusk,
		SUM(CASE WHEN IDReference in (4,5,6)        THEN LongSecond ELSE 0 END) PrivateOtpusk,
		SUM(CASE WHEN IDReference=2 and isPrivate=0  THEN LongSecond ELSE 0 END) Komand,
		SUM(CASE WHEN IDReference=2 and isPrivate=1  THEN LongSecond ELSE 0 END) PrivateKomand,
		SUM(CASE WHEN IDReference=7 and isPrivate=0  THEN LongSecond ELSE 0 END) Education,
		SUM(CASE WHEN IDReference=7 and isPrivate=1  THEN LongSecond ELSE 0 END) PrivateEducation,
		SUM(CASE WHEN IDReference=8 and isPrivate=0  THEN LongSecond ELSE 0 END) ShortEducation,
		SUM(CASE WHEN IDReference=8 and isPrivate=1  THEN LongSecond ELSE 0 END) PrivateShortEducation,
		SUM(CASE WHEN IDReference=3 and isPrivate=0  THEN LongSecond ELSE 0 END) Bolezn,
		SUM(CASE WHEN IDReference=3 and isPrivate=1  THEN LongSecond ELSE 0 END) PrivateBolezn,
		0 /*SUM(CASE WHEN IDReference=6 /*and isPrivate=1 */  THEN LongSecond ELSE 0 END)*/ PrivateRodi,
		SUM(CASE WHEN IDReference=9 /*and isPrivate=1 */ THEN LongSecond ELSE 0 END) PrivateBU, -- по уходу
		SUM(CASE WHEN IDReference=10 /*and isPrivate=1 */ THEN LongSecond ELSE 0 END) PrivateNB, -- не подтв больничный
		SUM(CASE WHEN te.IDReference=11 THEN te.LongSecond ELSE 0 END) NN, -- отсутствие по не выясн причинам
			/* 1077 */
		SUM(CASE WHEN te.IDReference=55 THEN te.LongSecond ELSE 0 END) GosOb_N,-- Гос обязанности неоплаченные
		SUM(CASE WHEN te.IDReference=56 THEN te.LongSecond ELSE 0 END) GosOb_O,-- Гос обязанности оплаченные
      /* */		                                                                         
		SUM(CASE WHEN te.IDReference=50 and te.isPrivate=0  THEN te.LongSecond ELSE 0 END) Kratk, -- краткосрочное отсутсвтие по служ.
		SUM(CASE WHEN te.IDReference=13 and te.isPrivate=0  THEN te.LongSecond ELSE 0 END) KratkTM, -- краткосрочное отсутсвие по ТМ
		SUM(CASE WHEN te.IDReference=50 and te.isPrivate=1  THEN te.LongSecond ELSE 0 END) PrivateKratk, -- краткосрочное отсутсвие по личке
		SUM(CASE WHEN te.IDReference=903  THEN te.LongSecond ELSE 0 END) Progul,
		SUM(CASE WHEN te.IDReference=104  THEN te.LongSecond ELSE 0 END) Pererabotka, -- переработка общая
		SUM(CASE WHEN te.IDReference=110  THEN te.LongSecond ELSE 0 END) PererabotkaT, -- переработка в турникетах
		SUM(CASE WHEN te.IDReference=111  THEN te.LongSecond ELSE 0 END) PererabotkaN, -- переаботка в настенных считывателях
		SUM(CASE WHEN te.IDReference=130  THEN te.LongSecond ELSE 0 END) PererabotkaTM, -- переработка по Таймменеджменту
		SUM(CASE WHEN te.IDReference IN (900, 901) THEN te.LongSecond ELSE 0 END) UnsignedViolation, -- опоздание ранний уход
		SUM(CASE WHEN te.IDReference IN (902, 908) THEN te.LongSecond ELSE 0 END) UnsignedViolation2, -- недоработка
		SUM(CASE WHEN te.IDReference = 102 THEN te.LongSecond ELSE 0 END) TotalWorked, --Фактическая отработка в пределах нормы
		SUM(CASE WHEN te.IDReference = 103 THEN te.LongSecond ELSE 0 END) Fakt,
		SUM(CASE WHEN te.IDReference = 105 THEN te.LongSecond ELSE 0 END) Obed,
		SUM(CASE WHEN te.IDReference = 108 THEN te.LongSecond ELSE 0 END) AddNorma, --Допустимое превышение нормы
		MAX(te.Correction) Correction,
		(SELECT TOP 1 _Regulation.isSmena FROM _Regulation
			WHERE _Regulation.UIDStaff = tm.UIDStaff AND _Regulation.StartDate<=DateCalc
				ORDER BY _Regulation.StartDate DESC) AS isSmena,
		SUM(CASE WHEN te.IDReference  = 106 THEN te.LongSecond ELSE 0 END) AS AdditionalTime,
		SUM(CASE WHEN te.IDReference  = 107 THEN te.LongSecond ELSE 0 END) AS upnorm,--перераб. с предыд. периода
		SUM(CASE WHEN te.IDReference  = 109 THEN te.LongSecond ELSE 0 END) AS UpNorma, -- переработка в пределах нормы
		0 AS compens
 
		/*BEGIN: Удалённый (дистанционный) режим работы */
		, CASE WHEN  @isSmena=1
				then SUM(CASE WHEN te.IDReference = 12 THEN te.LongSecond-3600 ELSE 0 END)
		        else SUM(CASE WHEN te.IDReference = 12 THEN te.LongSecond      ELSE 0 END)
		  end RemoteWorkTotal
		,case
		    WHEN SUM(CASE WHEN te.IDReference=100 THEN te.LongSecond ELSE 0 END)=0
			THEN /*Если Норма на сегодня =0 */ 0
		    ELSE
		         (
					(100*SUM(CASE WHEN te.IDReference = 12 THEN te.LongSecond ELSE 0 END))/
					(SUM(CASE WHEN te.IDReference=100 THEN te.LongSecond ELSE 0 END) )
				 )
		 END RemoteWorkRatio
		 /*END: Удалённый (дистанционный) режим работы */
		 /* Для сменщиков - коэфициент абсентеизма */
		 , dbo.GetAbsCoefPerson(tm.UIDStaff, @DateTo) AS AbsCoef
		 , CASE WHEN (SELECT SUM(LongSecond) FROM _kid_WorkDate WHERE Date = tm.DateCalc) > 0 THEN 0 ELSE 1 END AS FreeDay -- рабочий ли день для 5тидневки
     , SUM(CASE WHEN IDReference = 4  THEN LongSecond ELSE 0 END) AS HoursDO_Absent
     , SUM(CASE WHEN IDReference = 11 THEN LongSecond ELSE 0 END) AS HoursNN_Absent
	into #day
	from _TabelMain tm
	INNER JOIN _TabelExt te ON te.IDTabelMain = tm.ID
	INNER JOIN _Reference rf ON rf.ID = te.IDReference
	where
		--exists  (select * from #Peoples where #Peoples.UIDStaff=_TabelMain.UIDStaff)
		tm.UIDStaff in (select #Peoples.UIDStaff from #Peoples)
		and tm.DateCalc >= @DateFrom and tm.DateCalc <= @DateTo
	group by
		tm.ID,
		tm.UIDStaff,
		tm.DateCalc,
		tm.TimeRequestReCalc;
 
 IF @DEBUG_MODE=1 BEGIN set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
 set @DT_Speed_Start=GetDate()
 print '[4]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
 END

	/*REMOTE WORK LIMITATION BEGIN  vvvvvvvvv*/
	-- В таблице #day у нас полный перечень рассчитанных значений на каждый день - надо просуммировать и заполнить #Peoples для вывода обобщённой информации за месяц
	--DECLARE @NewSumNorma int
	--DECLARE @SumRemote int
	--DECLARE @HasRemoteViolation int
	
	--SELECT @NewSumNorma=SUM(isnull(Norma,0)), @SumRemote=sum(isNull(RemoteWorkTotal,0)) from #day
	
	

	--DECLARE @RemoteWorkAllowance TABLE (id int identity(1,1),UNID varchar(32), Allow int null,Limit float null, NewSumNorma int null,RemoteTotal int null,RemoteRatio float null)
  UPDATE RWA
		SET RWA.NewSumNorma = Norma, RWA.RemoteTotal=SumRemote
	FROM @RemoteWorkAllowance as RWA, ( 
	Select SUM(isnull(CASE WHEN X.NormaNRV>0 THEN X.NormaNRV ELSE X.Norma END,0)) as Norma,sum(isNull(X.RemoteWorkTotal,0))  as SumRemote, UIDStaff
	FROM #day as X
	GROUP BY UIDStaff ) D
	WHERE RWA.UNID=D.UIDStaff
	/* UPDATE @RemoteWorkAllowance
	set NewSumNorma=SUM(isnull(Norma,0)), @SumRemote=sum(isNull(RemoteWorkTotal,0)) from #day
*/

	UPDATE @RemoteWorkAllowance
	set HasRemoteViolation=0 WHERE  NewSumNorma=0 -- Если выходной и нормы на сегодня нет, то и нарушения быть не может

	UPDATE @RemoteWorkAllowance
	set HasRemoteViolation=1 WHERE  (NewSumNorma>0)AND(Allow=0)AND(RemoteTotal>0) -- Есть норма, удалёнка запрещена, но отработка на удалёнке есть!

	UPDATE @RemoteWorkAllowance/*Кастуем во float чтобы избежать целочисленного деления*/
	set HasRemoteViolation=1 WHERE  (NewSumNorma>0)AND(Allow=1)AND(cast((100*RemoteTotal) as float)/NewSumNorma  > Limit) -- Удалёнка разрешена, но лимит превышен

	UPDATE @RemoteWorkAllowance
	set HasRemoteViolation=0 WHERE  HasRemoteViolation IS NULL -- По остальным ситуациям пока что - "нарушения нет"
	
	/*IF @NewSumNorma=0
		SET @HasRemoteViolation=0
	ELSE
		BEGIN
		 if (@isRemoteWorkAllowed = 0)AND(@SumRemote > 0)
			 BEGIN
				SET @HasRemoteViolation = 1
			 END
		 ELSE
		 BEGIN	
		    
		   --DEBUG: SELECT cast((100*@SumRemote) as float)/@NewSumNorma as Calc,@RemoteWorkLimit as Limit
			IF cast((100*@SumRemote) as float)/@NewSumNorma  > @RemoteWorkLimit
				SET @HasRemoteViolation=1
			ELSE
				SET @HasRemoteViolation=0
		  END
 
		END*/
 
	IF @DEBUG_MODE=1
	BEGIN
		set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
		set @DT_Speed_Start=GetDate()
		print '[4.1]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
	END		
 

 	UPDATE P
		SET P.SumNorma = isnull(RWA.NewSumNorma,0),P.SumRemote=isnull(RWA.RemoteTotal,0),P.HasRemoteViolation=ISNULL(RWA.HasRemoteViolation,0)
		FROM #Peoples as P
			INNER JOIN @RemoteWorkAllowance as RWA ON RWA.UNID=P.UIDStaff


    /*UPDATE #Peoples
		SET SumNorma=isnull(@NewSumNorma,0),SumRemote=isnull(@SumRemote,0),HasRemoteViolation=@HasRemoteViolation*/
	
	IF @DEBUG_MODE=1
	BEGIN
		set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
		set @DT_Speed_Start=GetDate()
		print '[4.2]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
	END		 	
	
	UPDATE #Peoples
		SET RemoteRatio=CurrentRegulation.RemoteWorkLimit
		FROM (
				select UIDStaff,RemoteWorkLimit,isRemoteWorkAllowed
				from (
						select
							R.UIDStaff,
							case
								when ISNULL(isRemoteWorkAllowed,0)=0 then 0
								else ISNULL(RemoteWorkLimit,0)
							end as RemoteWorkLimit,
							ISNULL(isRemoteWorkAllowed,0) isRemoteWorkAllowed,
							row_number() over (partition by R.UIDStaff order by StartDate desc ) rank
						from _Regulation  R JOIN #Peoples P on P.UIDStaff = R.UIDStaff
						WHERE StartDate <= @DateTo
					) a
				where a.rank=1
				) CurrentRegulation
		WHERE CurrentRegulation.UIDStaff=#Peoples.UIDStaff
 
	IF @DEBUG_MODE=1
		BEGIN
			set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
			set @DT_Speed_Start=GetDate()
			print '[5]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
		END		
	
	/*REMOTE WORK LIMITATION END    ^^^^^^^^*/
	--установим потери
	update p
		set TimeLost = dbo.GetWorkTimeLost(p.UIDStaff, isnull(lost.[From], 0), isnull(lost.[To], 0), @DateFrom, @DateTo, @validDate),
		week_Work=W_week,
		week_Kratk=K_week,
		week_KratkTM=KTM_week,
		week_Remote=R_week,
		week_Command=C_week,
		week_Edu=E_week,
		week_NORMA=N_week,
		week_Looses=L_week
		
		-- book 2
   from #Peoples p
	join (
		select UIDStaff, min(Day) as [From], max(Day) as [To]
		,sum(TotalWorked) as W_week
		,sum(Kratk) as K_week
		,sum(KratkTM) AS KTM_week
		,sum(RemoteWorkTotal) as R_week
		,sum(Komand) as C_week
		,sum(Education) as E_week
		,sum(Norma) as N_week
		,sum(PrivateBolezn)+
				sum(PrivateRodi)+
				sum(PrivateBU)+
				sum(PrivateNB)+
				sum(PrivateOtpusk)+
				sum(PrivateKomand)+
				sum(PrivateKratk)+
				sum(Progul)+
				sum(NN)+
				SUM(GosOb_N)+
				sum(PrivateEducation)+
				sum(PrivateShortEducation)+
				sum(UnsignedViolation)		 as L_week
 
 
		 from #day
		group by UIDStaff
		having min(Day) > 0 or max(Day) < @maxTo
   ) lost on p.UIDStaff = lost.UIDStaff;
	 
 --формирование XML  (Результат пока не выдаём, запишем во временную табличку, чтобы высчитать суммарные подитоги по периодам)
 
 IF @DEBUG_MODE=1 BEGIN set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
 set @DT_Speed_Start=GetDate()
 print '[6]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
 END		
 
IF OBJECT_ID('tempdb..#XML_Tbl') IS NOT NULL   drop table #XML_Tbl;
   
	select
	  Path,
      Month,
      Year,
			DateFrom, DateTo,
      People.UIDStaff,
      FIO,
 
      CASE WHEN  isSmena=2 AND Period='week' AND isnull(collapse,0)<>1 THEN  DATEPART(week,DateCalc) ELSE 0 END AS werk,
 
	  CASE WHEN  isSmena=2 THEN
	      week_Work
      ELSE 0 END AS Week_Work,
 
	  CASE WHEN  isSmena=2 THEN
	      week_Kratk
      ELSE 0 END AS week_Kratk,
    CASE WHEN  isSmena=2 THEN
	    week_KratkTM
    ELSE 0 END AS week_KratkTM,
	  CASE WHEN  isSmena=2 THEN
	      week_Remote
      ELSE 0 END AS week_Remote,
	  CASE WHEN  isSmena=2 THEN
	      week_Command
      ELSE 0 END AS week_Command,
	  CASE WHEN  isSmena=2 THEN
	      week_Edu
      ELSE 0 END AS week_Edu,
	  CASE WHEN  isSmena=2 THEN
	      week_NORMA
      ELSE 0 END AS week_NORMA,
	  CASE WHEN  isSmena=2 THEN
	      week_Looses
      ELSE 0 END AS week_Looses,
 
	  CASE WHEN  isSmena=2 THEN
            (SELECT  SUM(Upnorma) FROM #day d2 WHERE isSmena=2 AND d2.UIDStaff=[Day].UIDStaff AND (Period='month' OR DATEPART(week,d2.DateCalc)=DATEPART(week,[Day].DateCalc) OR isnull(collapse,0)=1))
      ELSE 0 END AS UpNorma,
 
					 --CASE WHEN  isSmena<>-1 THEN  isSmena ELSE isSmena END AS isSmena,
        CASE WHEN  isSmena=2 THEN  2 ELSE 0 END AS isSmena,
                TabelNumber,
                dbo.CanRecalcAbsent(People.UIDStaff, @DateFrom, @DateTo) as canRecalc,
                TimeLost,
				
                Day Number,
                TimeRequestReCalc,
                hasViolation,
								CASE 
									WHEN Abbrev = (SELECT TOP 1 Abbrev FROM _Reference WHERE ID = 903)
										AND dbo.isCitrixConnect(People.UIDStaff, Day.DateCalc) = 1 
										AND dbo.isMovementExists(People.TabelNumber, Day.DateCalc) = 0 
									THEN 'ПР(У)' 
									ELSE Abbrev  
								END AS Abbrev,
                Norma,
								NormaNRV,	
                Otpusk,
                PrivateOtpusk,
                Komand,
                PrivateKomand,
                Education,
                PrivateEducation,
                ShortEducation,
                PrivateShortEducation,
                Bolezn,
                PrivateBolezn,
                PrivateRodi,
                PrivateBU,
                PrivateNB,
                NN,
                GosOb_N,
                GosOb_O,
                Kratk,
                KratkTM,
                AdditionalTime,
                --изменил Максимов М.А. 12.04.2013
                CASE WHEN  isSmena=2 THEN
                        (SELECT sum(CASE WHEN  Norma=0 THEN 0
                                                         WHEN Norma-fak-FreeFullDay>0 AND Norma-fak-FreeFullDay>=PrivateKratk THEN PrivateKratk --изменил Максимов М.А. 23.10.2012
                                                         WHEN Norma-fak-FreeFullDay>0 AND Norma-fak-FreeFullDay<PrivateKratk THEN Norma-fak-FreeFullDay
                                                         ELSE 0 END)
                         FROM  (SELECT sum(Fakt+upnorm-AdditionalTime -Pererabotka +Kratk+KratkTM+komand+Education+ShortEducation+Bolezn+otpusk) AS fak, sum(CASE WHEN (Fakt+upnorm -Pererabotka+Kratk+KratkTM+komand+Education+ShortEducation+Bolezn+otpusk<3*3600) THEN Norma-otpusk-PrivateOtpusk-PrivateBolezn-PrivateShortEducation-PrivateEducation ELSE 0 END) AS prog, sum(Norma) AS Norma, sum(PrivateBolezn+PrivateShortEducation+PrivateEducation+PrivateRodi+PrivateBU+PrivateNB+PrivateOtpusk+PrivateKomand+GosOB_N) AS FreeFullDay,sum(PrivateKratk) AS PrivateKratk
                                          FROM #day d2 WHERE isSmena=2 AND d2.UIDStaff=[Day].UIDStaff AND (Period='month' OR DATEPART(week,d2.DateCalc)=DATEPART(week,[Day].DateCalc) OR isnull(collapse,0)=1) GROUP BY weekNumm) AS qwer)
                else
                        case when Norma-PrivateKratk>=0 then PrivateKratk
                                 else Norma-TotalWorked end
                END PrivateKratk,
                --конец изменений
                case when Progul>0 then CASE WHEN NormaNRV>0 THEN NormaNRV ELSE Norma END else 0 end as Progul,
                CASE WHEN isSmena = 2 THEN Pererabotka ELSE Pererabotka + PererabotkaTM END AS Pererabotka, -- ARubanov_2023-03-04 Добавляем переработку по отпискам (130) код в переработку итоговую
								PererabotkaT, -- ARubanov_2023-03-04 Добавляем переработку по отпискам (130) код в переработку по турникетам
								PererabotkaTM, -- Переработка по ТаймМенеджменту
								PererabotkaN,
                CASE WHEN isSmena=2 then
                        UnsignedViolation2
                ELSE
                  case  when progul>0  then 0
                                when UnsignedViolation2>UnsignedViolation then UnsignedViolation2 --2006-02-06
                                else UnsignedViolation END
                END UnsignedViolation,
                Correction,
                isAdmin,
                CanPostprocess,
				case RWA.Allow
				when 1 THEN Fakt
				when 0 THEN Fakt+RemoteWorkTotal
				end as Fakt,
                Obed,
                -- Изменил Максимов М.А.
                --Добавил условие игнорирования отработки за день "за свой счет"
                --CASE WHEN isSmena=2 THEN TotalWorked-AdditionalTime ELSE TotalWorked
                --END AS TotalWorked,
                CASE
                            WHEN isSmena=2 AND Abbrev = ''  THEN TotalWorked - AdditionalTime
                            WHEN isSmena <> 2 THEN TotalWorked
                            ELSE 0
                END AS TotalWorked,
                --конец изменений
 
                CASE
					WHEN isSmena=2  THEN --Суммированный режим
					TotalWorked + upnorm  - AdditionalTime --RemoteWorkTotal    --!!!!!!! Тут была upnorm, а не upNormA
                ELSE 0
                END AS TotalWorkedUp ,
 
 
 
				/*RemoteWork, 20.08.2020 Булгаков М.В.*/
				case RWA.Allow
				when 1 THEN RemoteWorkTotal
				when 0 THEN 0
				end as RemoteWorkTotal
				,RemoteWorkRatio
				/*REMOTE WORK LIMITATION BEGIN  vvvvvvvvv*/
				,SumNorma,SumRemote,RWA.HasRemoteViolation,Day
				/*REMOTE WORK LIMITATION END  ^^^^^^^^^^^*/
				,NULL as ProcessedMark -- Отметка об обработке строчки для цикла WHILE ниже
				,0 as X_Week
				,People.RemoteRatio as RemoteRatio
				,CASE WHEN Day.isSmena = 1 THEN Day.AbsCoef ELSE 1.00 END AS AbsCoef
				, FreeDay 
				,CASE WHEN Day.isSmena = 1 THEN Day.HoursDO_Absent ELSE 0.00 END AS HoursDO_Absent 
				,CASE WHEN Day.isSmena = 1 THEN Day.HoursNN_Absent ELSE 0.00 END AS HoursNN_Absent
        INTO #XML_Tbl
		from
                #Tabel Tabel, #Peoples People
                LEFT JOIN #day Day ON People.UIDStaff=Day.UIDStaff 
				LEFT JOIN @RemoteWorkAllowance RWA on RWA.UNID=People.UIDStaff
		
        order by
                FIO,
                People.UIDStaff,
                Day
 
 IF @DEBUG_MODE=1 BEGIN set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
 set @DT_Speed_Start=GetDate()
 print '[7]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
 END
		
DECLARE
	@W_week int,--TotalWorkedUp
	@N_week int,--" select="sum(Day/@Norma)"/>
	@K_week int,--" select="sum(Day/@Kratk)"/>
	@KTM_week INT,
	@R_week int,--" select="sum(Day/@RemoteWorkTotal)"/>
	@C_week int,--" select="sum(Day/@Komand)"/>
	@E_week int,--" select="sum(Day/@Education)+sum(Day/@ShortEducation)"/>
	@O_week INT, --" select="sum(Day/@Otpusk)"/>
	@G_week INT, --" select="sum(Day/@GosOb_O)"/>
	@L_week int,--" select="sum(Day/@PrivateBolezn)+sum(Day/@PrivateRodi)+sum(Day/@PrivateBU)+sum(Day/@PrivateNB)+sum(Day/@PrivateOtpusk)+sum(Day/@PrivateKomand)+(Day/@PrivateKratk)+sum(Day/@Progul)+sum(Day/@NN)+sum(Day/@PrivateEducation)+sum(Day/@PrivateShortEducation)+sum(Day/@UnsignedViolation)"/>
	@X_week int=0, --select="$W_week + $R_week + $C_week + $K_week + $E_week"/>
	@DIFF_week int=0, --" select="$X_week - $N_week - $L_week"/>
	@PERERAB int=0,
	@D int=-1
 
Declare @werk int=-2,@row_id int=-1,@Cur_werk int=-1
-- DEBUG select * from #XML_Tbl
 --select * from #XML_Tbl
/* return */
 if EXISTS(select 1 from #XML_Tbl where Day is null)
 begin
  print 'Не хватает данных. В TabelExt не для всех есть "расписание"'
 --return
 end
 
DECLARE @User varchar(32)=''
DECLARE @CurUser varchar(32)='-1'
IF @DEBUG_MODE=1
  BEGIN
	set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
	set @DT_Speed_Start=GetDate()
	print '[8]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
  END		
--select * from #XML_Tbl 
while EXISTS (select 1 from #XML_Tbl where ProcessedMark is null and DAY IS not null)
BEGIN
	
	select top 1 
			@row_id=T.Day, 
			@werk=T.werk, 
			@User=UIDStaff
	from #XML_Tbl T
	where  ProcessedMark is null and DAY IS not null
	order by UIDStaff , T.Day Asc

	/*select top 1 
			T.Day, 
			T.werk, 
			UIDStaff
	from #XML_Tbl T
	where  ProcessedMark is null
	order by UIDStaff , T.Day Asc */
 
 
	IF @DEBUG_MODE=1
		print 'ROW='+cast(isnull(@row_id,-777) as varchar(32))+ '  @User='+@User 
 
	IF @Cur_werk=-1
	BEGIN
	   --Первый проход цикла,  мы пока ничего не знаем - обнуляем аккумуляторы и выставляем индикатор недели.
	    print 'Первый проход цикла,  мы пока ничего не знаем - обнуляем аккумуляторы и выставляем индикатор недели.'
		select @N_week=0,@W_week=0,@K_week=0, @KTM_week=0, @R_week=0, @G_week=0, @O_week=0, @C_week=0,@E_week=0,@L_week=0,@X_week=0,@DIFF_Week=0
		SET @Cur_werk=@werk
	END
	
	IF @CurUser='-1'
		SET @CurUser=@User
	
	IF (@Cur_werk < @werk) OR (@CurUser <> @User)
	BEGIN
	 iF @DEBUG_MODE=1
	 BEGIN
	 if (@CurUser <> @User) print 'Смена пользователя!!! с '+cast(isnull(@CurUser,'<NULL>') as varchar(32))+' на '+cast(isnull(@User,'<NULL>') as varchar(32))
	 print 'Рассчитаем итоги недели #'+cast(@werk as varchar(32))+' @DIFF_week='+isnull(cast(@DIFF_week as varchar(32)),'NULL')+ 'CurrDay='+cast(@row_id as varchar(32))
	 print 'было  DIFF_Week='+cast(@DIFF_week as varchar(32))
	 print 'WEEK:      X_week='+cast(@X_week as varchar(32))
	 print 'WEEK:      W_week='+cast(@W_week as varchar(32))
	 print 'WEEK:      R_week='+cast(@R_week as varchar(32))
	 print 'WEEK:      O_week='+cast(@O_week as varchar(32))
	 print 'WEEK:      G_week='+cast(@G_week as varchar(32))
	 print 'WEEK:      N_week='+cast(@N_week as varchar(32))
	 print 'WEEK:      L_week='+cast(@L_week as varchar(32))
	 END
	 SET @DIFF_week= /* @X_week */ @W_week + @K_week + @KTM_week+ @R_week + @O_week + @G_week + @C_Week + @E_Week - @N_week   + @L_week  --+@X_week  - @N_week - @L_week	  ????????????????????????????????????
	 IF @DEBUG_MODE=1
	 print 'Переработка за неделю DIFF_Week='+cast(@DIFF_week as varchar(32))		
     if @DIFF_week > 0
		begin
				IF @DEBUG_MODE=1
					print 'ПРЕВЫШЕНИЕ!!!!!!!!!'
							
				if @R_week > @DIFF_week
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем отписку по удалёнке на @DIFF_week:    @R_week:= '+cast(@R_week as varchar(32))+'-'+cast(@DIFF_week as varchar(32))
					SET @R_week=@R_week-@DIFF_week					
					SET @DIFF_week=0
				end
				else
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем @DIFF_week на длину отписки по удалёнке(вся удалёнка) '+cast(@DIFF_week as varchar(32))+'-'+cast(@R_week as varchar(32))
					SELECT @DIFF_week =@DIFF_week-@R_week,@R_week=0
					IF @DEBUG_MODE=1
						print '@DIFF_week ='+cast(@DIFF_week as varchar(32))
				end
		
				if @K_week > @DIFF_week
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем отписку по служебке на @DIFF_week:    @K_week:=  '+cast(@K_week as varchar(32))+'-'+cast(@DIFF_week as varchar(32))
					SET @K_week=@K_week-@DIFF_week
					SET @DIFF_week=0
				end
				else
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем @DIFF_week на длину отписки по служебке(вся служебка) '+cast(@DIFF_week as varchar(32))+'-'+cast(@K_week as varchar(32))
					SELECT @DIFF_week=@DIFF_week-@K_week, @K_week=0;
					IF @DEBUG_MODE=1	
						print '@DIFF_week ='+cast(@DIFF_week as varchar(32))	
				end
 
				if @E_week > @DIFF_week		
				begin			
					IF @DEBUG_MODE=1
						print 'Уменьшаем отписку по обучению на @DIFF_week:    @@E_week:=  '+cast(@E_week as varchar(32))+'-'+cast(@DIFF_week as varchar(32))
					SET @E_week=@E_week-@DIFF_week
					SET @DIFF_week=0
				end
				else
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем @DIFF_week на длину отписки по обучению(всё обучение) '+cast(@DIFF_week as varchar(32))+'-'+cast(@E_week as varchar(32))
					SELECT @DIFF_week=@DIFF_week-@E_week, @E_week=0;		
					IF @DEBUG_MODE=1
						print '@DIFF_week -@E_week ='+cast(@DIFF_week as varchar(32))	
				end
 
 
				if @C_week > @DIFF_week
					SET @C_week=@C_week-@DIFF_week;
				else
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем @DIFF_week на длину отписки по командировке(вся командировка) '+cast(@DIFF_week as varchar(32))+'-'+cast(@C_week as varchar(32))
					SELECT @DIFF_week=@DIFF_week-@C_week, @C_week=0;		
					IF @DEBUG_MODE=1
						print '@DIFF_week ='+cast(@DIFF_week as varchar(32))	
				end
	
				if @W_week > @DIFF_week
				begin
					IF @DEBUG_MODE=1
						begin
							print '@W_week ='+cast(@W_week as varchar(32))	
							print 'Режем факт присутствие!!!!  '+cast(@W_week as varchar(32))+'-'+cast(@DIFF_week as varchar(32))
						end
					SET @W_week=@W_week-@DIFF_week;
					IF @DEBUG_MODE=1
						begin
							print '@W_week ='+cast(@W_week as varchar(32))	
							print '@DIFF_week ='+cast(@DIFF_week as varchar(32))	
						end
				end
				else
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем @DIFF_week на длину факт.присутствия '+cast(@DIFF_week as varchar(32))+'-'+cast(@W_week as varchar(32))
					SELECT @DIFF_week=@DIFF_week-@W_week, @W_week=0;		
					IF @DEBUG_MODE=1
						print '@DIFF_week ='+cast(@DIFF_week as varchar(32))	
				end
		
			IF @X_WEEK - @N_Week >0
				SET @PERERAB=@PERERAB+@X_WEEK - @N_Week		
		END -- DIFF > 0
 
	 UPDATE #XML_Tbl
	 SET Week_Work=@W_Week,
		week_Kratk=@K_Week,
		week_KratkTM=@KTM_week,
		week_Remote=@R_week,
		week_Command=@C_Week,
		week_Edu=@E_Week,
		week_NORMA=@N_Week,
		week_Looses=@L_Week
	 where Werk=@Cur_Werk and UIDstaff=@CurUser	
	
	IF @DEBUG_MODE=1
		print 'Новая неделя, меняем указатель недели, обнуляем аккумуляторы'
	SET @Cur_werk= @werk
	SET @CurUser= @User
 
	SET @X_week=0
	SET @DIFF_week=0
	select @N_week=0, @W_week=0,@K_week=0,@R_week=0,@O_week=0,@G_week=0,@C_week=0,@E_week=0,@L_week=0,@X_week=0
	
	
	END	 -- Конец недели
	--else
 
	IF @Cur_werk = @werk
	BEGIN
		IF @DEBUG_MODE=1
			begin
				print 'текущая неделя, день '+cast(@row_id as varchar(32))+' увеличиваем аккумуляторы'
				print '      X_week[было]='+cast(@X_week as varchar(32))
			end
		select top 1
			@row_id=T.Day,
			@N_week=@N_week+T.Norma,
			@W_week=@W_week+ T.TotalWorked+T.Kratk+T.KratkTM,
			@K_week=@K_week+0,--T.Kratk,
			@R_week=@R_week+T.RemoteWorkTotal,
			@O_week=@O_week+T.Otpusk,
			@G_week=@G_week+T.GosOb_O,
			@C_week=@C_week+T.Komand,
			@E_week=@E_week+T.Education+T.ShortEducation,
			@L_week=/*@L_week+*/T.PrivateBolezn+T.PrivateRodi+T.PrivateBU+T.PrivateNB+T.PrivateOtpusk+T.PrivateKomand+T.PrivateKratk+T.Progul+T.NN+T.GosOb_N+T.PrivateEducation+T.PrivateShortEducation+T.UnsignedViolation		
		from #XML_Tbl T
		where  ProcessedMark is null and DAY IS not null
		order by UIDStaff , T.Day Asc
   
 		SET @X_week=/*@X_week+*/@W_week + @R_week + @O_week + @G_week + @C_week + @K_week + @E_week -- Сумма отработки и отписок за ЭТОТ день
		print 'Сумма отработки и отписок за ЭТОТ день : '+cast(@X_week as varchar(32))
		--select * from #XML_Tbl
		IF @X_WEEK - @N_Week -@L_Week >0
			SET @PERERAB=@PERERAB+@X_WEEK - @N_Week - @L_Week
 
		IF @DEBUG_MODE=1
		begin
			--print 'было  DIFF_Week='+cast(@DIFF_week as varchar(32))
			print '      W_week='+cast(@W_week as varchar(32))
			print '      R_week='+cast(@R_week as varchar(32))
			print '      O_week='+cast(@O_week as varchar(32))
			print '      G_week='+cast(@G_week as varchar(32))
			print '      C_week='+cast(@C_week as varchar(32))
			print '      K_week='+cast(@K_week as varchar(32))
			print '      E_week='+cast(@E_week as varchar(32))
			print '      N_week='+cast(@N_week as varchar(32))
			print '      L_week='+cast(@L_week as varchar(32))
			--SET @DIFF_week=@DIFF_week +@X_week/*@W_week*/ /*+ @K_week*/- @N_week -@L_week  --+@X_week  - @N_week - @L_week	
			/*print 'стало DIFF_Week='+cast(@DIFF_week as varchar(32))*/
			--SELECT @Cur_Werk as CurWeek,@row_id as Day,@W_week as W_week,@N_week as N,@K_week as K,@R_week as R,@C_week as C,@E_week as E,@L_week as L,@X_week as X,@DIFF_week as DIFF,@PERERAB as Pererab	
		end
 
		
	
	END -- Очередной день текущей недели
    print '!!!!!!!!!!!!!!!!!!!!!!!!!!!!1Убираем из цикла строку Row_id='+cast(@row_id as varchar(32))+' UIDStaff='+@CurUser
	--select * from #XML_Tbl	where Day=@row_id and  UIDstaff=@CurUser
	Update #XML_Tbl
	set ProcessedMark=1
	where Day=@row_id and  UIDstaff=@CurUser
	--select * from #XML_Tbl	where Day=@row_id and  UIDstaff=@CurUser
	
END
  -- Последний период в месяце мы не закрыли, т.к. новая неделя не началась и правило в цикле не ссработало, поэтом вручную запускаем механизм завершения периода
     print 'Последний период в месяце мы не закрыли, т.к. новая неделя не началась и правило в цикле не ссработало, поэтом вручную запускаем механизм завершения периода'
  --print  'Рассчитаем итоги недели[Неделя окнчилась без начала новой] #'+cast(@werk as varchar(32))+' @DIFF_week='+isnull(cast(@DIFF_week as varchar(32)),'NULL')
	 SET @X_week=/*@X_week+*/@W_week + @R_week + @O_week + @G_week + @C_week + @K_week + @E_week --
	 SET @DIFF_week= @W_week+ @R_week + @O_week + @G_week + @C_week + @K_week + @E_week /*   @X_week *//* -@W_week *//*+ @K_week*/- @N_week   + @L_week  --+@X_week  - @N_week - @L_week	  ????????????????????????????????????
	 IF @DEBUG_MODE=1
	 print 'Переработка за неделю DIFF_Week='+cast(@DIFF_week as varchar(32))		
     if @DIFF_week > 0
		begin
				IF @DEBUG_MODE=1
					print 'ПРЕВЫШЕНИЕ!!!!!!!!!'
							
				if @R_week > @DIFF_week
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем отписку по удалёнке на @DIFF_week:    @R_week:= '+cast(@R_week as varchar(32))+'-'+cast(@DIFF_week as varchar(32))
					SET @R_week=@R_week-@DIFF_week					
					SET @DIFF_week=0
				end
				else
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем @DIFF_week на длину отписки по удалёнке '+cast(@DIFF_week as varchar(32))+'-'+cast(@R_week as varchar(32))
					SELECT @DIFF_week =@DIFF_week-@R_week,@R_week=0
					IF @DEBUG_MODE=1
						print '@DIFF_week ='+cast(@DIFF_week as varchar(32))
				end
		
				if @K_week > @DIFF_week
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем отписку по служебке на @DIFF_week:    @K_week:=  '+cast(@K_week as varchar(32))+'-'+cast(@DIFF_week as varchar(32))
					SET @K_week=@K_week-@DIFF_week
					SET @DIFF_week=0
				end
				else
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем @DIFF_week на длину отписки по служебке '+cast(@DIFF_week as varchar(32))+'-'+cast(@K_week as varchar(32))
					SELECT @DIFF_week=@DIFF_week-@K_week, @K_week=0;
					IF @DEBUG_MODE=1	
						print '@DIFF_week ='+cast(@DIFF_week as varchar(32))	
				end
 
				if @E_week > @DIFF_week
					SET @E_week=@E_week-@DIFF_week
				else
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем @DIFF_week на длину отписки по обучению '+cast(@DIFF_week as varchar(32))+'-'+cast(@E_week as varchar(32))
					SELECT @DIFF_week=@DIFF_week-@E_week, @E_week=0;		
					IF @DEBUG_MODE=1
						print '@DIFF_week ='+cast(@DIFF_week as varchar(32))	
				end
 
 
				if @C_week > @DIFF_week
					SET @C_week=@C_week-@DIFF_week;
				else
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем @DIFF_week на длину отписки по командировке '+cast(@DIFF_week as varchar(32))+'-'+cast(@C_week as varchar(32))
					SELECT @DIFF_week=@DIFF_week-@C_week, @C_week=0;		
					IF @DEBUG_MODE=1
						print '@DIFF_week ='+cast(@DIFF_week as varchar(32))	
				end
	
				if @W_week > @DIFF_week
				begin
					IF @DEBUG_MODE=1
						begin
							print '@@W_week ='+cast(@W_week as varchar(32))	
							print 'Режем факт присутствие!!!!  '+cast(@W_week as varchar(32))+'-'+cast(@DIFF_week as varchar(32))
						end
					SET @W_week=@W_week-@DIFF_week;
					IF @DEBUG_MODE=1
						begin
							print '@@W_week ='+cast(@W_week as varchar(32))	
							print '@DIFF_week ='+cast(@DIFF_week as varchar(32))	
						end
				end
				else
				begin
					IF @DEBUG_MODE=1
						print 'Уменьшаем @DIFF_week на длину факт.присутствия '+cast(@DIFF_week as varchar(32))+'-'+cast(@W_week as varchar(32))
					SELECT @DIFF_week=@DIFF_week-@W_week, @W_week=0;		
					IF @DEBUG_MODE=1
						print '@DIFF_week ='+cast(@DIFF_week as varchar(32))	
				end
			
		
	IF @X_WEEK - @N_Week - @L_week >0
		SET @PERERAB=@PERERAB+@X_WEEK - @N_Week - @L_week
		end
 
 IF @DEBUG_MODE=1
		begin
			print '      W_week='+cast(@W_week as varchar(32))
			print '      R_week='+cast(@R_week as varchar(32))
			print '      O_week='+cast(@O_week as varchar(32))
			print '      G_week='+cast(@G_week as varchar(32))
			print '      C_week='+cast(@C_week as varchar(32))
			print '      K_week='+cast(@K_week as varchar(32))
			print '      E_week='+cast(@E_week as varchar(32))
			print '      N_week='+cast(@N_week as varchar(32))
			print '      L_week='+cast(@L_week as varchar(32))
		end


	UPDATE #XML_Tbl
		SET Week_Work	=@X_Week,
			week_Kratk	=@K_Week,
			week_KratkTM  =@KTM_week,
			week_Remote	=@R_week,
			week_Command=@C_Week,
			week_Edu	=@E_Week,
			week_NORMA	=@N_Week,
			week_Looses	=@L_Week
		where Werk=@Cur_Werk  and UIDStaff=@CurUser

 UPDATE #XML_Tbl
	 SET Week_Work=@W_Week,
		week_Kratk=@K_Week,
		week_KratkTM=@KTM_week,
		week_Remote=@R_week,
		week_Command=@C_Week,
		week_Edu=@E_Week,
		week_NORMA=@N_Week,
		week_Looses=@L_Week
	 where Werk=@Cur_Werk and UIDstaff=@CurUser	
 
 IF @DEBUG_MODE=1 BEGIN set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
 set @DT_Speed_Start=GetDate()
 print '[9]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
 END	
 
 --Запишем в HoursDO_Absent и HoursNN_Absent недельные суммы
 DECLARE @table_sum_abs TABLE (UIDStaff VARCHAR(32), werk INT, HoursDO_Absent INT, HoursNN_Absent INT)
 
 INSERT INTO @table_sum_abs
 SELECT UIDStaff, werk
				, SUM(CASE WHEN FreeDay = 1 THEN HoursDO_Absent ELSE 0 END) AS HoursDO_Absent
				, SUM(CASE WHEN FreeDay = 1 THEN HoursNN_Absent ELSE 0 END) AS HoursNN_Absent
 FROM #XML_Tbl
 GROUP BY UIDStaff, werk
 
  
 UPDATE #XML_Tbl   
	SET  HoursDO_Absent = B.HoursDO_Absent 
			, HoursNN_Absent = B.HoursNN_Absent
 FROM  #XML_Tbl A,  @table_sum_abs B 
 WHERE A.UIDStaff = B.UIDStaff AND A.werk = B.werk 
 
 /*Мы могли изменить отписки( в частности - по удаплёнке), если был перебор. Так что пересчитаем sumRemote */
 update t
 set t.SumRemote = a.sumRemote
 from (
 						select UIDStaff,sum(isnull(week_Remote,0)) as sumRemote  from
						(select
							R.UIDStaff,werk,week_Remote,							
							row_number() over (partition by R.UIDStaff,werk order by day desc ) rank
						from #XML_Tbl R) X
						where X.rank=1
						group by UIDStaff
						
						) a
 inner join #XML_Tbl t on t.UIDStaff = a.UIDStaff-- and t.day = a.day -- and t.werk = a.werk
 
 
DECLARE @UrlString VARCHAR(MAX)
DECLARE @UIDList VARCHAR(MAX) 

SELECT @UIDList = (SELECT UIDStaff FROM #Peoples FOR XML path('') )

SELECT TOP 1 @UrlString = 
	'tabel_q_simple2.asp?QueryAdmin='
		+'<GetTabel DateFrom="' + Tabel.DateFrom + '" DateTo = "' + Tabel.DateTo + '" '
		+ CASE WHEN @collapse='1' THEN 'collapse="1" ' ELSE '' END 
		+ CASE WHEN @isAdmin='1' THEN 'isAdmin="1" ' ELSE '' END 
		+' Path="">' + @UIDList    
		+'</GetTabel>'
FROM #Tabel Tabel
 
------- Сформируем итоговый XML -- Или передадим результирующую таблицу
/*DECLARE @isNullDays INT
SELECT @isNullDays = COUNT(*) from #XML_Tbl where Day is NULL
*/
if not EXISTS(select * from #XML_Tbl where Day is NOT NULL)
BEGIN


		select
			Tabel.Path,
			Tabel.Month,
			Tabel.Year,
							CONVERT(VARCHAR(10),CAST(Tabel.DateFrom AS DATETIME),104) AS DateFrom,
							CONVERT(VARCHAR(10),CAST(Tabel.DateTo AS DATETIME),104) AS DateTo,
			@UrlString
			AS UrlString,
				People.UIDStaff,
					People.FIO,
				People.werk,
				People.Week_Work,
				People.week_Kratk,
				People.week_KratkTM,
					People.week_Remote,
				People.week_Command,
				People.week_Edu,
				People.week_NORMA,
				People.week_Looses,
				People.UpNorma,
				People.isSmena,
					People.TabelNumber,
				People.canRecalc,
					People.TimeLost,
				People.RemoteRatio,
				People.AbsCoef,
				People.HoursDO_Absent,
				People.HoursNN_Absent,
	  
										Day.Day Number,
										Day.TimeRequestReCalc,
										Day.hasViolation,
										Day.Abbrev,
										CASE WHEN Day.NormaNRV > 0 THEN Day.NormaNRV ELSE Day.Norma END AS NormaFakt,
										CASE WHEN Day.NormaNRV > 0 THEN Day.Norma - Day.NormaNRV ELSE 0 END AS NormaNRVDiff,
										Day.Norma,
										Day.NormaNRV,
										Day.Otpusk,
										Day.PrivateOtpusk,
										Day.Komand,
										Day.PrivateKomand,
										Day.Education,
										Day.PrivateEducation,
										Day.ShortEducation,
										Day.PrivateShortEducation,
										Day.Bolezn,
										Day.PrivateBolezn,
										Day.PrivateRodi,
										Day.PrivateBU,
										Day.PrivateNB,
										Day.NN,
										Day.GosOb_N,
										Day.GosOb_O,
										Day.Kratk,
										DAY.KratkTM,
										Day.AdditionalTime,
						Day.PrivateKratk,
						Day.Progul,
						Day.Pererabotka,
						Day.PererabotkaT,
						Day.PererabotkaN,
						Day.PererabotkaTM,
						Day.UnsignedViolation,
										Day.Correction,
										Day.isAdmin,
										Day.CanPostprocess,
						Day.Fakt,
										Day.Obed,
						Day.TotalWorked,
						Day.TotalWorkedUp ,
						Day.RemoteWorkTotal,
						Day.RemoteWorkRatio,
						Day.SumNorma,
						Day.SumRemote,
						Day.HasRemoteViolation,
						Day.day 	,
				Day.FreeDay
		FROM 
			#XML_Tbl Tabel, #XML_Tbl People,#XML_Tbl Day
		WHERE 
				/*Tabel.Day=People.Day and
				People.Day=Day.Day   and */
				Tabel.TabelNumber=People.TabelNumber and
				Day.TabelNumber=People.TabelNumber  and
				Tabel.TabelNumber=Day.TabelNumber
		ORDER BY 
				Day.FIO,
				Day.UIDStaff,
				Day.Day
			FOR XML AUTO;
END
ELSE
BEGIN 

		select
			Tabel.Path,
			Tabel.Month,
			Tabel.Year,
							CONVERT(VARCHAR(10),CAST(Tabel.DateFrom AS DATETIME),104) AS DateFrom,
							CONVERT(VARCHAR(10),CAST(Tabel.DateTo AS DATETIME),104) AS DateTo,
			@UrlString
			AS UrlString,
				People.UIDStaff,
					People.FIO,
				People.werk,
				People.Week_Work,
				People.week_Kratk,
				People.week_KratkTM,
					People.week_Remote,
				People.week_Command,
				People.week_Edu,
				People.week_NORMA,
				People.week_Looses,
				People.UpNorma,
				People.isSmena,
					People.TabelNumber,
				People.canRecalc,
					People.TimeLost,
				People.RemoteRatio,
				People.AbsCoef,
				People.HoursDO_Absent,
				People.HoursNN_Absent,
	  
										Day.Day Number,
										Day.TimeRequestReCalc,
										Day.hasViolation,
										Day.Abbrev,
										CASE WHEN Day.NormaNRV > 0 THEN Day.NormaNRV ELSE Day.Norma END AS NormaFakt,
										CASE WHEN Day.NormaNRV > 0 THEN Day.Norma - Day.NormaNRV ELSE 0 END AS NormaNRVDiff,
										Day.Norma,
										Day.NormaNRV,
										Day.Otpusk,
										Day.PrivateOtpusk,
										Day.Komand,
										Day.PrivateKomand,
										Day.Education,
										Day.PrivateEducation,
										Day.ShortEducation,
										Day.PrivateShortEducation,
										Day.Bolezn,
										Day.PrivateBolezn,
										Day.PrivateRodi,
										Day.PrivateBU,
										Day.PrivateNB,
										Day.NN,
										Day.GosOb_N,
										Day.GosOb_O,
										Day.Kratk,
										DAY.KratkTM,
										Day.AdditionalTime,
						Day.PrivateKratk,
						Day.Progul,
						Day.Pererabotka,
						Day.PererabotkaT,
						Day.PererabotkaN,
						Day.PererabotkaTM,
						Day.UnsignedViolation,
										Day.Correction,
										Day.isAdmin,
										Day.CanPostprocess,
						Day.Fakt,
										Day.Obed,
						Day.TotalWorked,
						Day.TotalWorkedUp ,
						Day.RemoteWorkTotal,
						Day.RemoteWorkRatio,
						Day.SumNorma,
						Day.SumRemote,
						Day.HasRemoteViolation,
						Day.day 	,
				Day.FreeDay
		FROM 
			#XML_Tbl Tabel, #XML_Tbl People,#XML_Tbl Day
		Where
				Tabel.Day=People.Day and
				People.Day=Day.Day   and
				Tabel.TabelNumber=People.TabelNumber and
				Day.TabelNumber=People.TabelNumber  and
				Tabel.TabelNumber=Day.TabelNumber

		ORDER BY 
				Day.FIO,
				Day.UIDStaff,
				Day.Day
			FOR XML AUTO;	
	
END

 
IF @DEBUG_MODE=1
BEGIN
	set @Delay=dateDiff(ms,@DT_Speed_Start,GetDate())
	set @DT_Speed_Start=GetDate()
	print '[10]While loop takes : '+cast(Isnull(@Delay,0) as varchar(32))
END		
	
IF OBJECT_ID('tempdb..#XML_Tbl') IS NOT NULL   drop table #XML_Tbl;
	
end
