USE [worktime]
GO
/****** Object:  StoredProcedure [dbo].[_XMLTabel_simple2]    Script Date: 08.08.2025 20:32:41 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		ARubanov
-- Create date: 03/04/20214
-- Description:	Очередной табель
-- =============================================
ALTER PROCEDURE [dbo].[_XMLTabel_simple2]
  @Query NTEXT
  , @forOverwork INT = 0
  , @TimeResults INT = 0
AS
BEGIN
  SET DATEFIRST 1;
  -- работа с пришедшим XML
  DECLARE @hdoc INT;
  -- проверка корректности xml?
  EXEC sp_xml_preparedocument @hdoc OUTPUT, @Query;
  
  IF @hdoc = 0 
  BEGIN
    RAISERROR ('_XMLTabel: Error prepare XML document' ,16 ,1)
    RETURN
  END
  
--==============================================   
  -- получаем параметры запроса из xml в @Tabel
  DECLARE @Tabel TABLE(
  	DateFrom VARCHAR(10) 
		,DateTo VARCHAR(10)
		,[Year] VARCHAR(10) 
		,[Month] VARCHAR(10)
		,[Path] VARCHAR(800)
		,isAdmin VARCHAR(255) 
		,Collapse VARCHAR(255)
		,CanPostprocess VARCHAR(255)
		,FreeDays VARCHAR(255)
		,isCoefAbsExists BIT
		) 
	
  INSERT INTO @Tabel
    (DateFrom,DateTo,Path,isAdmin,Collapse,CanPostprocess,[Year],[Month])  
  SELECT DateFrom,DateTo,PATH,ISNULL(isAdmin,'0'),ISNULL(Collapse,0),ISNULL(CanPostprocess,'0'), YEAR(CAST(DateFrom AS DATETIME)), MONTH(CAST(DateFrom AS DATETIME))
    FROM OPENXML(@hdoc ,'/GetTabel' ,1)WITH(
         DateFrom VARCHAR(10)'@DateFrom'
         ,DateTo VARCHAR(10)'@DateTo'
         ,PATH VARCHAR(800)'@Path'
         ,isAdmin VARCHAR(255)'@isAdmin'
         ,collapse VARCHAR(255)'@collapse'
         ,CanPostprocess VARCHAR(255)'@CanPostprocess'
       );
  
   --получим граничные даты
  DECLARE @DateFrom DATETIME, @DateTo DATETIME, @maxTo INT, @validDate DATETIME, @isAdmin VARCHAR, @Collapse VARCHAR, @CanPostprocess VARCHAR
  SELECT TOP 1 @DateFrom = CAST(DateFrom AS DATETIME), @DateTo = CAST(DateTo AS DATETIME) 
							 , @isAdmin = isAdmin, @Collapse = Collapse, @CanPostprocess = CanPostprocess	
  FROM @Tabel;
  SELECT @validDate = DATEADD(DAY ,-2 ,CAST(GETDATE() AS DATE)),@maxTo = DATEPART(DAY ,@validDate);
  IF @DateTo <= @validDate SET @maxTo = 100; --снятие любых ограничений

  --Получим список UIDStaff пользователей, для которых заказан табель. (Их может быть несколько! Табелирующий открывает именно групповые отчёты)
   --У разных сотрудников могут быть разные настройки разрешений на дистанционную работу - загрузим для всех запрошенных в таблицу @Peoples
   --через GetRegulation
   
  DECLARE @Peoples TABLE (
  		UIDStaff VARCHAR(32)
  		,FIO VARCHAR(100)
  		,TabelNumber VARCHAR(20)
  		,isSmena SMALLINT
  		,[Period] VARCHAR(32)
      ,isDistanceWorkAllowed INT NULL
      ,DistanceVsego INT NULL
      ,DistanceLimit INT NULL
      ,NormaVsego INT NULL
      ,AbsCoef NUMERIC(10,2)
  	)
  
  INSERT INTO @Peoples (UIDstaff, FIO, TabelNumber,isSmena,[Period], DistanceLimit, isDistanceWorkAllowed, AbsCoef) --
  SELECT P.UIDStaff, P.Name, P.TabelNumber, R.isSmena, ISNULL(R.[Period],''), ISNULL(R.RemoteWorkLimit,0), ISNULL(R.isRemoteWorkAllowed,0), dbo.GetAbsCoefPerson(P.UIDStaff, @DateTo)
  FROM OPENXML(@hdoc, '/GetTabel/UIDStaff', 1) WITH (UIDStaff VARCHAR(32)'text()') Q
  INNER JOIN _Person AS P ON P.UIDStaff = Q.UIDStaff 
	  CROSS APPLY dbo.GetRegulation(Q.UIDStaff, @DateTo) R 
  
  -- Устанавливаем в @Tabel isCoefAbsExists
  UPDATE @Tabel
  SET isCoefAbsExists = CASE WHEN EXISTS(SELECT 1 FROM @Peoples WHERE AbsCoef <> 1.0) THEN 1 ELSE 0 END 
  
  EXEC sp_xml_removedocument @hdoc
  --Входящий xml разобран, больше не нужен
  --======================================   

  --Создадим таблицу выходных/праздничных и рабочих дней
	DECLARE @WorkDays TABLE ([Date] DATETIME, isWorkDate BIT)
	INSERT INTO @WorkDays(Date,isWorkDate) SELECT Date,isWorkDate FROM dbo.GetWorkDays(@DateFrom, @DateTo)

  DECLARE @freeDays VARCHAR(255)
  SELECT @freeDays = ISNULL(STUFF((SELECT ',' +'[' + CAST(DATEPART(DAY,[Date]) AS VARCHAR) +']'  FROM @WorkDays WHERE isWorkDate = 0  FOR XML PATH('')), 1, 1, ''),'')
  UPDATE @Tabel SET	FreeDays = @freeDays
 
  -- Получаем информацию из _TabelExt по дням по каждому коду _Reference
  IF OBJECT_ID('tempdb..#Day') IS NOT NULL drop table #Day;
        
  SELECT 
  --> IT-SIT_00646.29.2023  MShulgin
    tm.UIDStaff -- сотрудник
    , MAX(P.TabelNumber) AS TabelNumber
		, tm.ID as ID_TabelMain 
		, DATEPART(day, tm.DateCalc) Day -- день месяца
		, MAX(P.Period) AS Period
		, CASE WHEN P.Period = 'week' AND @Collapse<>'1' THEN DATEPART(week, tm.DateCalc) ELSE 0 END AS WeekNumber
		, tm.DateCalc
		, tm.TimeRequestReCalc
		, MAX(P.FIO) AS FIO
		, MAX(R.isViolation) hasViolation
		, ISNULL(STUFF((
					SELECT DISTINCT ',' + Abbrev FROM _Reference WHERE  Abbrev <> '' AND ID in (SELECT DISTINCT IDReference FROM _TabelExt WHERE IDTabelMain= tm.ID) FOR XML PATH('')
			), 1, 1, ''),'')  
			AS Abbrev  
	
		, SUM(CASE WHEN te.IDReference=100 THEN te.LongSecond ELSE 0 END) Norma --Norma
	  , SUM(CASE WHEN te.IDReference=98 THEN te.LongSecond ELSE 0 END) NormaNRV --NormaNRV
		, SUM(CASE WHEN te.IDReference = 1 AND te.isPrivate = 0		THEN te.LongSecond ELSE 0 END) Otpusk  -- Ежегодный отпуск
		--, SUM(CASE WHEN te.IDReference = 1												THEN te.LongSecond ELSE 0 END) rf1  -- Ежегодный отпуск
		,	SUM(CASE WHEN te.IDReference = 2 AND te.isPrivate = 0		THEN te.LongSecond ELSE 0 END) Komandirovka -- Командировка
		,	SUM(CASE WHEN te.IDReference = 2 AND te.isPrivate = 1		THEN te.LongSecond ELSE 0 END) PoteriKomandirovka 
		,	SUM(CASE WHEN te.IDReference = 3		THEN te.LongSecond ELSE 0 END) Bolnichny -- Болезнь
		--,	SUM(CASE WHEN te.IDReference = 3 AND te.isPrivate = 1		THEN te.LongSecond ELSE 0 END) rf3_1
		,	SUM(CASE WHEN te.IDReference = 4												THEN te.LongSecond ELSE 0 END) PoteriOtpusk -- Отпуск без сохранения заработной платы
		,	SUM(CASE WHEN te.IDReference = 5												THEN te.LongSecond ELSE 0 END) OtpuskAdmin-- Административный отпуск
		,	SUM(CASE WHEN te.IDReference = 6												THEN te.LongSecond ELSE 0 END) OtpuskBeremRody-- Отпуск по беременности и родам
		,	SUM(CASE WHEN te.IDReference = 7 and te.isPrivate = 0		THEN te.LongSecond ELSE 0 END) Obuchenie -- Обучение
		,	SUM(CASE WHEN te.IDReference = 7 and te.isPrivate = 1		THEN te.LongSecond ELSE 0 END) PoteriObuchenie -- Обучение не полачиваемое
		,	SUM(CASE WHEN te.IDReference = 8 and te.isPrivate = 0		THEN te.LongSecond ELSE 0 END) ObuchenieKorp -- Корпоративное обучение
		,	SUM(CASE WHEN te.IDReference = 8 and te.isPrivate = 1		THEN te.LongSecond ELSE 0 END) PoteriObuchenieKorp
		,	SUM(CASE WHEN te.IDReference = 9												THEN te.LongSecond ELSE 0 END) PoteriBU-- Больничный по уходу
		--,	SUM(CASE WHEN te.IDReference = 10												THEN te.LongSecond ELSE 0 END) rf10 -- Неподтверждённый больничный
		,	SUM(CASE WHEN te.IDReference = 11												THEN te.LongSecond ELSE 0 END) PoteriNN -- Отсутствие по невыясненным причинам
		,	SUM(CASE WHEN te.IDReference = 12												THEN te.LongSecond ELSE 0 END) Distance  -- Удалённая работа (обнулить если норма = 0)
		,	SUM(CASE WHEN te.IDReference = 13 and te.isPrivate = 0	THEN te.LongSecond ELSE 0 END) KratkTM -- Встреча по ИС Тайм Менеджмент
		,	SUM(CASE WHEN te.IDReference = 50 and te.isPrivate = 0	THEN te.LongSecond ELSE 0 END) Kratk -- Краткосрочное отсутствие (Служебка)
		,	SUM(CASE WHEN te.IDReference = 50 and te.isPrivate = 1	THEN te.LongSecond ELSE 0 END) PoteriKratk -- Краткосрочное отсутствие (Личка) 
		, SUM(CASE WHEN te.IDReference = 55												THEN te.LongSecond ELSE 0 END)	GosOb_N -- Гособязанности неоплачиваемые
		, SUM(CASE WHEN te.IDReference = 56												THEN te.LongSecond ELSE 0 END)	GosOb_O -- Гособязанности оплачиваемые
		
		,	SUM(CASE WHEN te.IDReference = 903  THEN te.LongSecond ELSE 0 END) Progul -- Прогул (недоработка более 3х часов)
		,	SUM(CASE WHEN te.IDReference = 104  THEN te.LongSecond ELSE 0 END) PererabotkaItog -- переработка общая // для ежедн, смен.
		,	SUM(CASE WHEN te.IDReference = 110  THEN te.LongSecond ELSE 0 END) PererabotkaTurniket -- переработка в турникетах
		,	SUM(CASE WHEN te.IDReference = 111  THEN te.LongSecond ELSE 0 END) PererabotkaNastenn -- переаботка в настенных считывателях
		,	SUM(CASE WHEN te.IDReference = 130  THEN te.LongSecond ELSE 0 END) PererabotkaTM -- переработка по Таймменеджменту
		
		,	SUM(CASE WHEN te.IDReference = 900  THEN te.LongSecond ELSE 0 END) Opozdanie -- Опоздание 
		,	SUM(CASE WHEN te.IDReference = 901  THEN te.LongSecond ELSE 0 END) RanniyUhod -- Ранний уход
		,	SUM(CASE WHEN te.IDReference = 902  THEN te.LongSecond ELSE 0 END) Nedorabotka902 -- Недоработка
		,	SUM(CASE WHEN te.IDReference = 908  THEN te.LongSecond ELSE 0 END) Nedorabotka908 -- Недоработка
		,	SUM(CASE WHEN te.IDReference = 102 THEN te.LongSecond ELSE 0 END) Fakt     -- Фактическая отработка в пределах нормы
		,	SUM(CASE WHEN te.IDReference = 103 THEN te.LongSecond ELSE 0 END) FaktFull     -- Фактическая отработка полная
		,	SUM(CASE WHEN te.IDReference = 105 THEN te.LongSecond ELSE 0 END) Obed     -- Неучтенное отсутствие (обед)
		,	SUM(CASE WHEN te.IDReference = 108 THEN te.LongSecond ELSE 0 END) DopustPrevyshNormy      --Допустимое превышение нормы
		,	SUM(CASE WHEN te.IDReference = 106 THEN te.LongSecond ELSE 0 END) AS AdditionalTime -- AdditionalTime (Обед вычитаемый из факт. присутcт.)
		, SUM(CASE WHEN te.IDReference = 107 THEN te.LongSecond ELSE 0 END) AS UpNorm --upnorm--перераб. с предыд. периода
		, SUM(CASE WHEN te.IDReference = 109 THEN te.LongSecond ELSE 0 END) AS UpNorma --UpNorma -- переработка в пределах нормы
		,	MAX(te.Correction) Correction
		,	MAX(P.isSmena) AS isSmena
		, @isAdmin AS isAdmin
		, @Collapse AS Collapse
		, @CanPostprocess AS CanPostprocess
  	, 0 AS compens
  	, CAST('' AS VARCHAR(255)) AS DayColor
		, CAST('' AS VARCHAR(255)) AS DayStyle
		 /* Для сменщиков - коэфициент абсентеизма */
		, MAX(P.AbsCoef) AS AbsCoef -- Коэфициент Абсентеизма на последнюю дату
		--, CASE WHEN (SELECT SUM(te.LongSecond) FROM _kid_WorkDate WHERE Date = tm.DateCalc) > 0 THEN 0 ELSE 1 END AS FreeDay -- рабочий ли это день для 5тидневки
	INTO #Day	
  FROM _TabelExt te
  INNER JOIN _TabelMain tm ON tm.ID = te.IDTabelMain
  INNER JOIN @Peoples P ON P.UIDStaff = tm.UIDStaff
  INNER JOIN _Reference R ON R.ID = te.IDReference
  WHERE tm.DateCalc BETWEEN @DateFrom AND @DateTo
  GROUP BY
		tm.ID
		, tm.UIDStaff
		, tm.DateCalc
		, P.Period
		, tm.TimeRequestReCalc
	
	/*INSERT INTO #day (UIDStaff,Norma,ID_TabelMain, DateCalc, Abbrev,compens) 
	SELECT UIDStaff, 0,0,@DateFrom,'',0 FROM @Peoples WHERE UIDStaff NOT IN (SELECT UIDStaff FROM #day) --test  
	
	SELECT * FROM #day--test	*/
		
		-- Доустановка значений
		UPDATE #day 
			SET Abbrev = 
				CASE WHEN Abbrev = 'ПР' 
							AND dbo.isCitrixConnect(UIDStaff, DateCalc) = 1 
							AND dbo.isMovementExists(TabelNumber,DateCalc) = 0 
					THEN 'ПР(У)' 
					ELSE Abbrev 
				END

	-- Подсчет итогов,
	 IF OBJECT_ID('tempdb..#WeekItogs') IS NOT NULL drop table #WeekItogs;

		SELECT
		  UIDStaff
		  , WeekNumber
		  , MAX(FIO) AS FIO
		  , MAX(TabelNumber) AS TabelNumber
		  , MAX(isSmena) AS isSmena
		  , MIN(DateCalc) AS DateFrom
		  , MAX(DateCalc) AS DateTo 
			, SUM(Norma) AS Norma -- Потом еще нужно прибавить потери при приеме увольнении
			, SUM(NormaNRV) AS NormaNRV
			, SUM(dbo.is0Int(NormaNRV,Norma)) AS NormaItog
			, SUM(CASE WHEN NormaNRV>0 THEN Norma-NormaNRV ELSE 0 END) AS NormaDifference
			, 0 AS Total
			, 0 AS Vsego
			, 0 AS OverworkForCut -- Всего + отпуск + потери - норма = то что свыше нормы отработано -  Необходимо для урезания до нормы
			, SUM(
				CASE WHEN isSmena <> 2 THEN
						0 -- потом через норму и потери
				ELSE	
					Fakt
						+ CASE WHEN isSmena = 2 AND Abbrev = '' THEN UpNorm ELSE 0 END
						- CASE WHEN isSmena = 2 AND Abbrev = '' THEN AdditionalTime ELSE 0 END 
				END		
			) AS Fakt -- Фактическая отработка в пределах нормы; -Обед вычитаемый из факт. присутcт; Краткосрочное отсутствие (Служебка)
			, SUM(Distance) AS Distance
			, SUM(Kratk) AS Kratk -- Идет в факт
			, SUM(KratkTM) AS KratkTM
			, SUM(Komandirovka) AS Komandirovka 
			, SUM(Obuchenie) AS Obuchenie
			, SUM(ObuchenieKorp) AS ObuchenieKorp
			, SUM(GosOb_O) AS GosOb_O
			, SUM(Otpusk) AS Otpusk
			--------------
			, 0 AS PoteriVsego -- *******Потом******
			, SUM(Bolnichny) AS PoteriBolnichny -- Больничный
			, SUM(PoteriBU) AS PoteriBU -- Больничный по уходу
			, SUM(PoteriOtpusk) AS PoteriOtpusk -- Отпуск без сохранения
			, SUM(PoteriNN) AS PoteriNN  -- Невыясненные причины
			, SUM(PoteriKratk) AS PoteriKratk -- Потери по отписке - личка
			, SUM(PoteriObuchenie) AS PoteriObuchenie -- Потери учеба
			, SUM(PoteriObuchenieKorp) AS PoteriObuchenieKorp 
			, SUM(GosOb_N) AS PoteriGosOb_N
			, SUM(CASE WHEN Progul > 0 OR Obed > 10800 /*Прогул > 0 ИЛИ Обед > 3ч*/ THEN dbo.is0Int(NormaNRV,Norma) /*Норма*/ ELSE 0 END) AS PoteriProgul
			,	SUM(CASE WHEN (Progul > 0 OR Obed > 10800) /*Прогул > 0 ИЛИ Обед > 3ч*/ THEN 0
				 		 ELSE dbo.MaxInt(Opozdanie + RanniyUhod,Nedorabotka902 + Nedorabotka908)
						END) AS PoteriUnsignedViolation
			, 0 AS PoteriAbsenteizm -- *******Потом******
			, 0 AS PoteriProchie
			, 0 AS PererabotkaInNorma
			, SUM(CASE WHEN isSmena = 2 THEN 0 ELSE PererabotkaItog END) AS PererabotkaItog
			, SUM(CASE WHEN isSmena = 2 THEN 0 ELSE PererabotkaTurniket END) AS PererabotkaTurniket
			, SUM(CASE WHEN isSmena = 2 THEN 0 ELSE PererabotkaNastenn END) AS PererabotkaNastenn
			, SUM(CASE WHEN isSmena = 2 THEN 0 ELSE PererabotkaTM END) AS PererabotkaTM
			, dbo.GetAbsCoefPerson(UIDStaff, @DateTo) AS AbsentKoef
			, SUM(CASE WHEN wd.isWorkDate = 0 AND PoteriOtpusk > 0 AND dbo.GetAbsCoefPerson(UIDStaff, @DateTo) <> 1 THEN PoteriOtpusk ELSE 0 END) AS AbsentDO 
			, SUM(CASE WHEN wd.isWorkDate = 0 AND PoteriNN > 0 AND dbo.GetAbsCoefPerson(UIDStaff, @DateTo) <> 1 THEN PoteriNN ELSE 0 END) AS AbsentNN 
			, 0 AS AbsentItog
			, 0 AS PoteriPriemUvolnenie
			, 0 AS HasRemoteViolation
		INTO #WeekItogs
		FROM #day 
	  LEFT JOIN @WorkDays wd ON wd.Date = DateCalc
		GROUP BY
			UIDStaff
			, WeekNumber

	--SELECT * FROM #WeekItogs --test
-- Подбиваем оставшиеся итоги
		-- Высчитываем Потери по приему/увольнению 
		--SELECT DATEPART(DAY,DateFrom),DATEPART(DAY, DateTo), DateFrom, DateTo, @validDate FROM #WeekItogs --test
		UPDATE #WeekItogs
		SET PoteriPriemUvolnenie =  dbo.GetWorkTimeLost(UIDStaff, DATEPART(DAY,DateFrom),DATEPART(DAY, DateTo), DateFrom, DateTo, @validDate)
		--Добавляем к Норме потери по приему увольнению
		
		UPDATE #WeekItogs
		SET Norma = Norma + PoteriPriemUvolnenie
				, NormaItog = NormaItog + PoteriPriemUvolnenie
		
		-- Считаем прочие потери
		 UPDATE #WeekItogs 
		 SET PoteriProchie = PoteriKratk + NormaDifference -- Личка плюс потери по неполному рабочему дню		
		-- Считаем итоги потерь. Содержится ли прогул в PoteriUnsignedViolation?
		UPDATE #WeekItogs
		SET PoteriVsego = PoteriBolnichny + PoteriBU + PoteriOtpusk + PoteriNN + PoteriPriemUvolnenie + PoteriProgul + PoteriObuchenie + PoteriObuchenieKorp + PoteriUnsignedViolation + PoteriProchie
		-- Расчитываем фактическое время для ежедн/сменщ через норму  
		UPDATE #WeekItogs
		SET Fakt = NormaItog - Distance - Kratk - Komandirovka - Obuchenie - ObuchenieKorp- GosOb_O - Otpusk - PoteriVsego
		WHERE isSmena <> 2
		-- Подбиваем столбец всего за искл. а также потери абсентеизма 
		UPDATE #WeekItogs
		SET Vsego = CASE WHEN isSmena = 2 THEN Fakt + Distance + Kratk + KratkTM + Komandirovka + Obuchenie + ObuchenieKorp + GosOb_O
																				ELSE Fakt + Distance + Kratk + KratkTM + Komandirovka + Obuchenie + ObuchenieKorp + GosOb_O
				          END
				, AbsentItog = (AbsentDO + AbsentNN) * AbsentKoef
				, PoteriAbsenteizm = (AbsentDO + AbsentNN) * (AbsentKoef - 1)
				
		-- Из Всего минусуем Потери абсентеизма		
		UPDATE #WeekItogs
		SET Vsego = dbo.MaxInt(Vsego - PoteriAbsenteizm, 0)
				WHERE isSmena <> 2
--SELECT * FROM #WeekItogs --test		


    --Занимаемся переработкой 				
		UPDATE #WeekItogs
		SET OverworkForCut = Vsego + Otpusk + PoteriVsego	- Norma 
		WHERE isSmena = 2
		
--SELECT * FROM #WeekItogs --test					
		-- Всю переработку в столбец PererabotkaInNorma (идет в табель)
		UPDATE #WeekItogs SET PererabotkaInNorma = dbo.MaxInt(OverworkForCut, 0)  -- все что сверх нормы - идет в переработку в пределах нормы (смнусуй личку)
		-- Урезаем до нормы
		--SELECT * FROM #WeekItogs

		-- Сначала по удаленке
		UPDATE #WeekItogs SET OverworkForCut = OverworkForCut - Distance, Distance = 0  
			WHERE isSmena = 2 AND OverworkForCut > 0 AND OverworkForCut >= Distance AND Distance > 0  -- переработка больше удаленки - вся удаленка режется, общая переработка уменьшается на длину удаленки
		UPDATE #WeekItogs SET Distance = Distance - OverworkForCut, OverworkForCut = 0  
			WHERE isSmena = 2 AND OverworkForCut > 0 AND OverworkForCut < Distance AND Distance > 0 -- переработка меньше удаленки - переработка в ноль, удаленка уменьшается на длину переработки

    -- Теперь режем служебку
		UPDATE #WeekItogs SET OverworkForCut = OverworkForCut - Kratk, Kratk = 0  
			WHERE isSmena = 2 AND OverworkForCut > 0 AND OverworkForCut >= Kratk AND Kratk > 0 
		UPDATE #WeekItogs SET Kratk = Kratk - OverworkForCut, OverworkForCut = 0
			WHERE isSmena = 2 AND OverworkForCut > 0 AND OverworkForCut < Kratk AND Kratk > 0

		-- Теперь режем обучение
		UPDATE #WeekItogs SET OverworkForCut = OverworkForCut - ObuchenieKorp, ObuchenieKorp = 0  
			WHERE isSmena = 2 AND OverworkForCut > 0 AND OverworkForCut >= ObuchenieKorp AND ObuchenieKorp > 0 
		UPDATE #WeekItogs SET ObuchenieKorp = ObuchenieKorp - OverworkForCut, OverworkForCut = 0
			WHERE isSmena = 2 AND OverworkForCut > 0 AND OverworkForCut < ObuchenieKorp AND ObuchenieKorp > 0

		-- Теперь режем коммандировку
		UPDATE #WeekItogs SET OverworkForCut = OverworkForCut - Komandirovka, Komandirovka = 0  
			WHERE isSmena = 2 AND OverworkForCut > 0 AND OverworkForCut >= Komandirovka AND Komandirovka > 0 
		UPDATE #WeekItogs SET Komandirovka = Komandirovka - OverworkForCut, OverworkForCut = 0
			WHERE isSmena = 2 AND OverworkForCut > 0 AND OverworkForCut < Komandirovka AND Komandirovka > 0

		-- Теперь режем факт
		UPDATE #WeekItogs SET OverworkForCut = OverworkForCut - Fakt, Fakt = 0  
			WHERE isSmena = 2 AND OverworkForCut > 0 AND OverworkForCut >= Fakt AND Fakt > 0 
		UPDATE #WeekItogs SET Fakt = Fakt - OverworkForCut, OverworkForCut = 0
			WHERE isSmena = 2 AND OverworkForCut > 0 AND OverworkForCut < Fakt AND Fakt > 0

		-- Дорезались, больше резать нечего
		-- Пересчитываем Vsego для isSmena = 2 после обрезки
		UPDATE #WeekItogs
		SET Vsego = Fakt + Distance + Kratk + KratkTM + Komandirovka + Obuchenie + ObuchenieKorp + GosOb_O  
		WHERE isSmena = 2

	-- Заполняем @Peoples и Прописываем итоги удаленки и нормы удаленки
	--- ВСЕ ПРОПИСАТЬ в WEEKITOGS!!!
	UPDATE #WeekItogs
		SET HasRemoteViolation = 
			CASE WHEN B.NormaItog <> 0 AND (CAST((100 * B.DistanceItog) AS FLOAT) / B.NormaItog  > DistanceLimit) OR (isDistanceWorkAllowed = 0 AND B.DistanceItog > 0) 
			 THEN 1 
			 ELSE 0 
			END
	FROM @Peoples A
	JOIN (SELECT UIDStaff, SUM(Distance) AS DistanceItog, SUM(NormaItog) AS NormaItog FROM #WeekItogs GROUP BY UIDStaff) B ON B.UIDStaff = A.UIDStaff
	
	
	/*Раскрасим серые дни*/
    UPDATE #day
    SET    DayColor = 'green'
    WHERE  hasViolation = 0--Нет нарушений => шрифт зелёный
    UPDATE #day
    SET    DayStyle = 'FONT-WEIGHT:bolder;'
    WHERE  PoteriKratk > 0 -- Есть отписка по личке => жирным шрифтом 
    UPDATE #day
    SET    DayColor = 'blue',
           DayStyle = 'FONT-WEIGHT:bolder;'
    WHERE  Obuchenie + PoteriObuchenie + ObuchenieKorp + PoteriObuchenieKorp > 0--Есть "короткое" обучение
    UPDATE #day
    SET    DayColor = 'darkviolet'
    WHERE  (Distance > 0)
           AND (Kratk + KratkTM + Obuchenie + PoteriObuchenie + ObuchenieKorp + PoteriObuchenieKorp + Komandirovka + Fakt = 0)--Если за день нет оплачиваемых интервалов КРОМЕ удалёнки - раскрасить фиолетовым 
    UPDATE #day
    SET    DayStyle = 'PADDING-RIGHT:6px;PADDING-LEFT:10px;'
    WHERE  ISNULL(Abbrev, '') <> '' -- Есть аббревиатура -=> выравнивание
    UPDATE #day
    SET    DayColor         = 'red'
    WHERE  hasViolation     = 1--Есть нарушения => шрифт красный	
		
DECLARE @UrlString VARCHAR(MAX)
DECLARE @UIDList VARCHAR(MAX) 

SELECT @UIDList = (SELECT UIDStaff FROM @Peoples FOR XML path('') )

SELECT TOP 1 @UrlString = 
	'tabel_q_simple2' + CASE WHEN @TimeResults = 0 THEN '_' ELSE '' END  + '.asp?QueryAdmin='
		+'<GetTabel DateFrom="' + Tabel.DateFrom + '" DateTo = "' + Tabel.DateTo + '" '
		+ CASE WHEN @collapse='1' THEN 'collapse="1" ' ELSE '' END 
		+ CASE WHEN @isAdmin='1' THEN 'isAdmin="1" ' ELSE '' END 
		+' Path="">' + @UIDList    
		+'</GetTabel>'
FROM @Tabel Tabel		

IF @forOverwork = 0 
BEGIN 
			-- Итоговая таблица табеля
				SELECT
					Tabel.Path
					, Tabel.Month
					, Tabel.Year
					, CONVERT(VARCHAR(10) ,CAST(Tabel.DateFrom AS DATETIME) ,104) AS DateFrom
					, CONVERT(VARCHAR(10) ,CAST(Tabel.DateTo AS DATETIME) ,104) AS DateTo
					, @UrlString AS UrlString
					, @TimeResults AS TimeResults
					, Tabel.FreeDays
					, People.UIDStaff
					, People.FIO
					, People.TabelNumber
					, People.WeekNumber AS Period_Number
					, People.isSmena
					, People.Vsego Vsego
					, (People.Fakt + People.Kratk) Fakt
					, People.Distance Distance
					, 0.00 AS Kratk -- идет в факт
					, People.Komandirovka Komandirovka 
					, People.Obuchenie + People.ObuchenieKorp Obuchenie
					, People.Otpusk Otpusk
					, People.GosOb_O GosOb_O
					, People.Norma Norma
					, People.PoteriVsego PoteriVsego
					, People.PoteriBolnichny PoteriBolnichny
					, People.PoteriBU PoteriBU
					, People.PoteriOtpusk PoteriOtpusk
					, People.PoteriNN PoteriNN
					, People.PoteriPriemUvolnenie PoteriPriemUvolnenie
 					, People.PoteriGosOb_N PoteriGosOb_N
					, People.PoteriAbsenteizm PoteriAbsenteizm
					, People.PoteriUnsignedViolation + People.PoteriProgul PoteriUnsignedViolation
					, People.PoteriProchie PoteriProchie
					, CASE WHEN People.isSmena = 2 THEN People.PererabotkaInNorma ELSE People.PererabotkaItog + People.PererabotkaTM END AS PererabotkaItog
					, People.PererabotkaTurniket AS PererabotkaTurniket
					, People.PererabotkaNastenn AS PererabotkaNastenn
					, People.PererabotkaTM AS PererabotkaTM
					, People.AbsentKoef
					, People.AbsentDO AbsentDO
					, People.AbsentNN AbsentNN
					, People.AbsentItog AbsentItog
					, People.HasRemoteViolation AS PeopleHasRemoteViolation
					-- Соблюдение режима сменности
				 -- , People.Norma AS KoefPrevysh
					,	CASE WHEN People.Norma = 0 OR People.Vsego + People.Otpusk = 0 THEN 0.00 ELSE
	  				ROUND(CAST(CASE WHEN People.isSmena = 2 THEN People.PererabotkaInNorma ELSE People.PererabotkaItog END AS NUMERIC(10,2)) / CAST(People.Norma AS NUMERIC(10,2)), 2)
	  				/
	  				ROUND((People.Vsego + People.Otpusk) / CAST(People.Norma AS NUMERIC(10,2)), 2)
	  	
					END
					AS KoefPrevysh
					, CASE WHEN People.Norma = 0 THEN 0.00 ELSE
							CAST(CASE WHEN People.isSmena = 2 THEN People.PererabotkaInNorma ELSE People.PererabotkaItog END AS NUMERIC(10,2)) 
							/ CAST(People.Norma AS NUMERIC(10,2)) 
							END
						 AS PererabKNorme
					, CASE WHEN People.Norma = 0 THEN 0.00 ELSE (People.Vsego + People.Otpusk) / CAST(People.Norma AS NUMERIC(10,2)) END AS VsegoKNorme 
					, Day.Day Number
					, CASE WHEN People.isSmena = 2 THEN dbo.Seconds_to_Time(Day.Fakt - Day.AdditionalTime + Day.Distance + Day.Kratk + Day.KratkTM + Day.Komandirovka)
								 ELSE dbo.Seconds_to_ShortTime(dbo.is0Int(Day.NormaNRV, DAY.Norma) - Day.PoteriKratk - Day.Obuchenie - Day.PoteriObuchenie - Day.ObuchenieKorp - Day.PoteriObuchenieKorp - dbo.MaxInt(Day.Opozdanie + Day.RanniyUhod,Day.Nedorabotka902 + Day.Nedorabotka908))
								 END 
						AS DayCellValue
					, Day.DayColor
					, Day.DayStyle
					,	CASE Day.isSmena WHEN 2 THEN '#ccffcc' ELSE 'white' END AS BGColor
					, Day.Abbrev
					, Day.hasViolation  
				FROM #day Day
				LEFT JOIN #WeekItogs People ON Day.UIDStaff = People.UIDStaff AND Day.WeekNumber = People.WeekNumber
				CROSS JOIN @Tabel Tabel
				ORDER BY
							Day.FIO,
							Day.UIDStaff,
							Day.Day 
				FOR XML AUTO; 
				
END
ELSE 
BEGIN
	-- Для Переработки		
				SELECT
					Tabel.Path
					, Tabel.Month
					, Tabel.Year
					, CONVERT(VARCHAR(10) ,CAST(Tabel.DateFrom AS DATETIME) ,104) AS DateFrom
					, CONVERT(VARCHAR(10) ,CAST(Tabel.DateTo AS DATETIME) ,104) AS DateTo
					, People.UIDStaff
					, People.FIO
					, People.WeekNumber AS Period_Number
					, People.PoteriPriemUvolnenie PoteriPriemUvolnenie
					, People.isSmena
					, People.TabelNumber
					, People.AbsentKoef
					, People.AbsentDO AbsentDO
					, People.AbsentNN AbsentNN
					, People.Vsego Total_Pay_for_Period_Hours
					, People.Fakt + People.Kratk Total_Fact_for_Period
					, People.Obuchenie + People.ObuchenieKorp Total_Education_for_Period
					, People.Distance Total_Remote_for_Period
					, 0.00 AS Total_Kratk_for_Period -- идет в факт
					, People.Komandirovka Total_Command_for_Period 
					, People.Otpusk OtpuskVacation__REF_1
					, People.GosOb_O GosOb_O
					, People.Norma Total_Norma_for_Period
					, People.PoteriVsego TotalLosses
					, People.PoteriBolnichny Period_ILLNESS
					, People.PoteriBU Period_ILLNESS_Nurse
					, People.PoteriOtpusk Vacation_Private_Ref4
					, People.PoteriUnsignedViolation + People.PoteriProgul Period_Unsigned
					, People.PoteriGosOb_N PoteriGosOb_N
					, People.PoteriProchie Total_PrivateKratk_for_Period
					, CASE WHEN People.isSmena = 2 THEN People.PererabotkaInNorma ELSE People.PererabotkaItog + People.PererabotkaTM END AS Overwork_GrandTotal
					, People.PererabotkaTurniket AS Overwork_Turnik__REF_110
					, People.PererabotkaNastenn AS Overwork_Wall__REF_111
					, People.PererabotkaTM AS Overwork_Wall__REF_130
					, People.PoteriNN Period_NN
					, People.HasRemoteViolation AS HasRemoteViolation
					, Day.Day [Day]
					, Day.DayColor DayColor
					,	CASE Day.isSmena WHEN 2 THEN '#ccffcc' ELSE 'white' END AS BGColor
					, Day.Abbrev Abbrev
					, CASE WHEN People.isSmena = 2 THEN dbo.Seconds_to_Time(Day.Fakt - Day.AdditionalTime + Day.Distance + Day.Kratk + Day.KratkTM + Day.Komandirovka)
								 ELSE dbo.Seconds_to_ShortTime(dbo.is0Int(Day.NormaNRV, DAY.Norma) - Day.PoteriKratk - Day.Obuchenie - Day.PoteriObuchenie - Day.ObuchenieKorp - Day.PoteriObuchenieKorp - dbo.MaxInt(Day.Opozdanie + Day.RanniyUhod,Day.Nedorabotka902 + Day.Nedorabotka908))
								 END 
						AS DayCellValue
				FROM #day Day
				LEFT JOIN #WeekItogs People ON Day.UIDStaff = People.UIDStaff AND Day.WeekNumber = People.WeekNumber
				CROSS JOIN @Tabel Tabel
				ORDER BY
							Day.FIO,
							Day.UIDStaff,
							Day.Day 
		
END

END
