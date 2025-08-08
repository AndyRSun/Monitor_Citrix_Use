<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:msxsl="urn:schemas-microsoft-com:xslt" xmlns:user="http://www.eastline.ru/worktime">
	<xsl:output  method="html" encoding="windows-1251" media-type="application/vnd.ms-excel"/>
	<xsl:template match="/Tabel">
		<HTML>
			<HEAD>
				<TITLE>
					Табель УРВ <xsl:value-of select="@Year"/> год <xsl:value-of select="@Month"/> месяц <xsl:value-of select="@Path"/> (c <xsl:value-of select="@DateFrom"/> по <xsl:value-of select="@DateTo"/>)
				</TITLE>
				<STYLE>
				BODY
				{
					PADDING-RIGHT: 0px;
					PADDING-LEFT: 0px;
					FONT-SIZE: 10pt;
					PADDING-BOTTOM: 0px;
					MARGIN: 0px;
					PADDING-TOP: 0px;
					FONT-FAMILY: Tahoma;
					BACKGROUND-COLOR: #ebebeb
				}
				TABLE
				{
					BORDER-RIGHT: 1px;
					BORDER-TOP: 1px;
					FONT-SIZE: 10pt;
					BORDER-LEFT: 1px;
					BORDER-BOTTOM: 1px;
					TEXT-DECORATION: none
				}
				.TableHeader
				{
					BACKGROUND-COLOR:Gainsboro;
				}

				</STYLE>
				<script> 
				var sel={id:-1,color:''};
				function f(self){
					var tables = document.getElementById('TPeople');
					if (tables.rows.length>4){
						if (sel.id!=self.sectionRowIndex) 
						{
							if (sel.id!=-1) 
							{
								tables.children[0].rows[sel.id].style.backgroundColor=sel.color;
							}
							sel={id:self.sectionRowIndex,color:self.style.backgroundColor};
						}
						self.style.backgroundColor='Pink';
					}
				}				
				</script>
			</HEAD>
			<BODY oncontextmenu="return true;">
				<xsl:attribute name="onload">
					<xsl:if test="@RECALC!=''">
							alert('Перерасчет нарушений произведен');
					</xsl:if>
					Data.Query.value=XMLQuery.innerHTML;
				</xsl:attribute>
				<xsl:if test="@XLS=''">
					<xsl:element name="XML">
						<xsl:attribute name="id">XMLQuery</xsl:attribute>
						<xsl:copy-of select="GetTabel"/>
					</xsl:element>
					<FORM id="Data" Name="Data" method="POST">
						<INPUT id="Query" name="Query" type="hidden"/>
					</FORM>
					<TABLE>
						<TR style="COLOR:white;background-color:#0099ff;FONT-WEIGHT:bolder;text-align:center;">
							<TD width="80" onclick="Data.action='?REFRESH=1';Data.submit();" onmouseover="this.style.cursor='hand';this.style.color='yellow';" onmouseout="this.style.color='white';">
								Обновить
							</TD>
							<TD width="170" onclick="Data.action='?RECALC=1';Data.submit();" onmouseover="this.style.cursor='hand';this.style.color='yellow';" onmouseout="this.style.color='white';">
								Пересчитать нарушения
							</TD>
							<TD width="140" onmouseover="this.style.cursor='hand';this.style.color='yellow';" onmouseout="this.style.color='white';">
								<xsl:attribute name="onclick">Data.action='?XLS=1';Data.submit();</xsl:attribute>
								В формате MS Excel
							</TD>
							<TD width="140"> 
								<xsl:attribute name="onclick">f(this);</xsl:attribute>									
								<xsl:call-template name="NewTabelClick"></xsl:call-template>									
							</TD>
							<xsl:if test="@CanPostprocess=1">
								<TD width="170" onmouseover="this.style.cursor='hand';this.style.color='yellow';" onmouseout="this.style.color='white';">
									<xsl:attribute name="onclick">
										Data.action='?XLS=1&amp;isNew=1';Data.submit();
									</xsl:attribute>
									В формате MS Excel(P)
								</TD>
							</xsl:if>
						</TR>
					</TABLE>
					<BR/>
				</xsl:if>
				<B> 
					<xsl:value-of select="@Year"/> год <xsl:value-of select="@Month"/> месяц <xsl:value-of select="@Path"/> (c <xsl:value-of select="@DateFrom"/> по <xsl:value-of select="@DateTo"/>);
				</B>
				<TABLE id="TPeople">
					<xsl:if test="@XLS!=''">
						<xsl:attribute name="border">1</xsl:attribute>	
					</xsl:if>
					<TR align="center" class="TableHeader">
						<TD rowspan="3">№</TD>
						<TD rowspan="3">ФИО</TD>
						<TD rowspan="3">Табельный номер</TD>
						<TD rowspan="2" colspan="31">Отметки о количестве отработанных часов по числам месяца</TD>
						<TD colspan="8">Оплачиваемое время за месяц, ч.</TD>
						<!-- <TD rowspan="3">Коэффициент оплаты отпуска</TD> -->
						<TD rowspan="3">Норма</TD>
						<TD colspan="10">Потери рабочего времени за месяц</TD>
						<TD colspan="7">Справочно</TD>
						<TD rowspan="2" colspan="4">Понижающий коэффициент абсентеизма (К)</TD>
					</TR>
					<TR align="center" class="TableHeader">
						<TD rowspan="2">Всего за искл. опл-го отпуска</TD>
						<TD colspan="6">в том числе</TD> <!-- Оплачиваемое -->
						<TD rowspan="2">Отпуск</TD>
						<TD rowspan="2">Всего</TD>
						<TD colspan="9">в том числе</TD>  <!-- Потери -->
						<TD rowspan="1" colspan="4">Переработка</TD>
						<TD rowspan="1" colspan="3">Соблюдение графика сменности</TD>
					</TR>
					<TR align="center" class="TableHeader">
						<xsl:call-template name="DayOfWeek"/>
						<TD>Факт</TD>
						<TD>Дистанц.</TD>
						<TD>Кр.отсутст.</TD>
						<TD>Команд.</TD>
						<TD>Обуч.</TD>
						<TD>Гос.обяз.</TD>
						<TD>Болезнь</TD>
						<!--<TD>Отпуск по берем. и родам</TD>-->
						<TD>БУ</TD>
						<!-- <TD>НБ</TD>-->
						<TD>Отпуск (ДО)</TD>
						<TD>НН</TD>
						<!-- <TD>Команд.</TD> -->
						<!-- <TD>Обуч.</TD> -->
						<td>Потери по приему и увольнению</td>
						<td>Гос.обяз.</td>
						<td>Абсентеизм</td>
						<td>Незаявл.</td>
						<Td>Прочие</Td>
						<td>Всего</td>
						<td>В зоне турникетов</td>
						<td>В зоне с настенными считывателями</td>
						<td>По ИС Тайм Менеджмент</td>

						<td>Коэффициент превышения</td>
						<td>Отношение переработки к Норме</td>
						<td>Отношение отработанного времени к Норме</td>

						<td>Значение коэффициента</td>
						<td>Количество часов, приходящихся на причины отсутствия ДО в выходные и праздничные дни</td>
						<td>Количество часов, приходящихся на причины отсутствия НН в выходные и праздничные дни</td>
						<td>Количество часов, приходящихся на причину отсутствия ДО и НН с учетом К </td>						
						
					</TR>
					<xsl:for-each select="People">
						<TR id="PersonRow" class="TableHeader" >
							<xsl:attribute name="style">
								<xsl:if test="@isSmena=2">
								background-color:#ccffcc
								</xsl:if>
								<xsl:if test="@isSmena!=2">
								background-color:white
								</xsl:if> 
							</xsl:attribute>
							<xsl:attribute name="onclick">f(this);</xsl:attribute>
							<TD>
								<xsl:value-of select="position()"/>
							</TD>
							<TD>
								<nobr>
									<xsl:value-of select="@FIO"/>
								</nobr>
							</TD>
							<TD align="center" style="mso-number-format:'\@';">
								<xsl:value-of select="@TabelNumber"/>
							</TD>
							<xsl:call-template name="DayOfWeek">
								<xsl:with-param name="ByPeople" select="1"/>
							</xsl:call-template>


								 <!-- format-number(sum(Day/@PererabotkaT)div 3600, '0.00') -->
							<xsl:variable name="W_week" select="sum(Day/@TotalWorkedUp)" /> 
							<xsl:variable name="N_week" select="sum(Day/@Norma)"/> 
							<xsl:variable name="K_week" select="sum(Day/@Kratk)+sum(Day/@KratkTM)"/> 
							<xsl:variable name="GO_week" select="sum(Day/@GosOb_O)"/> 
							
							<xsl:variable name="R_week" select="sum(Day/@RemoteWorkTotal)"/> 
							<xsl:variable name="C_week" select="sum(Day/@Komand)"/> 
							<xsl:variable name="E_week" select="sum(Day/@Education)+sum(Day/@ShortEducation)"/> 
							<xsl:variable name="L_week" select="sum(Day/@PrivateBolezn)+sum(Day/@PrivateRodi)+sum(Day/@PrivateBU)+sum(Day/@PrivateNB)+sum(Day/@PrivateOtpusk)+sum(Day/@PrivateKomand)+(Day/@PrivateKratk)+sum(Day/@Progul)+sum(Day/@NN)+sum(Day/@GosOb_N)+sum(Day/@PrivateEducation)+sum(Day/@PrivateShortEducation)+sum(Day/@UnsignedViolation)"/> 
							<xsl:variable name="X_week" select="$W_week + $R_week + $C_week + $K_week + $E_week"/> 
							<xsl:variable name="DIFF_week" select="$X_week - $N_week - $L_week"/> 
							
							
							
							
							
							<!-- Запишем итоговые значения переменных для вывода -->
							<!--<xsl:variable name="DIFF_week" select="@Week_Work"/>  -->
							<!-- атрибуты @Week_*  - это суммы соотв. периодов -->
							<xsl:variable name="W_week_result" select="@Week_Work"/>
							
							<xsl:variable name="N_week_result" select="@week_NORMA"/> 
							<xsl:variable name="K_week_result" select="@week_Kratk+@week_KratkTM"/> 
							<xsl:variable name="R_week_result" select="@week_Remote"/> 
							<xsl:variable name="C_week_result" select="@week_Command"/> 
							<xsl:variable name="E_week_result" select="@week_Edu"/> 
							<xsl:variable name="L_week_result" select="@week_Looses"/> 
							<xsl:variable name="X_week_result" select="$W_week_result + $N_week_result + $R_week_result + $C_week_result + $K_week_result +$E_week_result"/> 

							<xsl:variable name="VSEGO">
							<!--Всего-->
								<xsl:choose>
									<xsl:when test="@isSmena!=2"> <!-- СМЕННЫЙ/Ежедневный учёт -->
										<xsl:choose>
											<xsl:when test="sum(Day/@NormaFakt)-sum(Day/@PrivateBolezn)-sum(Day/@PrivateRodi)-sum(Day/@PrivateBU)-sum(Day/@PrivateNB)-sum(Day/@PrivateOtpusk)-sum(Day/@PrivateKomand)-sum(Day/@PrivateKratk)-sum(Day/@Progul)-sum(Day/@NN)-sum(Day/@GosOb_N)-sum(Day/@Bolezn)-sum(Day/@Otpusk)-sum(Day/@PrivateEducation)-sum(Day/@PrivateShortEducation)-sum(Day/@UnsignedViolation)-(@AbsCoef*(@HoursDO_Absent+@HoursNN_Absent)-(@HoursDO_Absent+@HoursNN_Absent)) &gt; 0">	
												<xsl:value-of select="sum(Day/@NormaFakt)-sum(Day/@PrivateBolezn)-sum(Day/@PrivateRodi)-sum(Day/@PrivateBU)-sum(Day/@PrivateNB)-sum(Day/@PrivateOtpusk)-sum(Day/@PrivateKomand)-sum(Day/@PrivateKratk)-sum(Day/@Progul)-sum(Day/@NN)-sum(Day/@GosOb_N)-sum(Day/@Bolezn)-sum(Day/@Otpusk)-sum(Day/@PrivateEducation)-sum(Day/@PrivateShortEducation)-sum(Day/@UnsignedViolation)-(@AbsCoef*(@HoursDO_Absent+@HoursNN_Absent)-(@HoursDO_Absent+@HoursNN_Absent))"/>
											</xsl:when>
											<xsl:otherwise>
												<xsl:value-of select="0.00" />
											</xsl:otherwise>
										</xsl:choose>
									</xsl:when>
									<xsl:otherwise><!-- Суммированный учёт -->
										<xsl:choose>
											<xsl:when test="$X_week - $L_week - $N_week &gt; -1">
											<!-- Если сумма отработки и платных отписок больше нормы (с поправкой на потери)-->
												<xsl:value-of select="$N_week - $L_week" />
											</xsl:when> 
											<xsl:otherwise> <!-- Сумма в порядке (норму не превышает), выводим всю сумму -->
												<xsl:value-of select="$W_week + $K_week + $GO_week + $R_week_result + $C_week_result + $K_week_result + $E_week_result" />
											</xsl:otherwise>
										</xsl:choose>																													
									</xsl:otherwise>
								</xsl:choose>						
							</xsl:variable>
							
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="$VSEGO" /> <!-- X_week -->
							</xsl:call-template>


							<!--Фактическое присутствие -->
							<xsl:choose>
								<xsl:when test="@isSmena!=2">
									<xsl:call-template name="MonthResult">
										<xsl:with-param name="Result" select="sum(Day/@NormaFakt)-sum(Day/@RemoteWorkTotal)-sum(Day/@GosOb_O)-sum(Day/@PrivateBolezn)-sum(Day/@PrivateRodi)-sum(Day/@PrivateBU)-sum(Day/@PrivateNB)-sum(Day/@PrivateOtpusk)-sum(Day/@PrivateKomand)-sum(Day/@PrivateKratk)-sum(Day/@Progul)-sum(Day/@NN)-sum(Day/@GosOb_N)-sum(Day/@Bolezn)-sum(Day/@Otpusk)-sum(Day/@Komand)-sum(Day/@Education)-sum(Day/@ShortEducation)-sum(Day/@UnsignedViolation)"/> 
									</xsl:call-template>
								</xsl:when>
								<xsl:otherwise><!--Суммированный учёт --> 								
									<xsl:choose>
										<xsl:when test="$X_week - $L_week - $N_week &gt; -1">
											<!-- Если сумма отработки и платных отписок больше нормы (с поправкой на потери)-->
											<xsl:call-template name="MonthResult">
												<xsl:with-param name="Result" select="@Week_Work"/>
											</xsl:call-template>	
										</xsl:when> 
										<xsl:otherwise>
										<xsl:call-template name="MonthResult">
											<xsl:with-param name="Result" select="$W_week + $K_week " />
										</xsl:call-template>
										</xsl:otherwise>
									</xsl:choose>
									
								</xsl:otherwise>
							</xsl:choose>

							<!--Отработка на удалёнке  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!-->		
							<xsl:choose>
								<!-- @RemoteRatio  - макс. удалёнка в процентах , например 50 -->
								<!--  (N/100)*@RemoteRatio  -д.б. менее @week_Remote -->
								<xsl:when test="(Day/@SumNorma * @RemoteRatio )  &lt; (Day/@SumRemote * 100)">
									<xsl:call-template name="MonthResult"> 
										<xsl:with-param name="Result" select="@week_Remote" /> <!-- sum(Day/@RemoteWorkTotal)"/>							-->
										<xsl:with-param name="HasError" select="1"/>
									</xsl:call-template>							
								</xsl:when>
								<xsl:otherwise>
									<xsl:call-template name="MonthResult"> 
										<xsl:with-param name="Result" select="@week_Remote" /> <!-- sum(Day/@RemoteWorkTotal)"/>							-->
										<xsl:with-param name="HasError" select="0"/>
									</xsl:call-template>							
								</xsl:otherwise>
							</xsl:choose>

							<!--Кр.отсутст. -->
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="0"/>
							</xsl:call-template>
							<!--Команд.  -->
							<xsl:choose>
								<xsl:when test="@isSmena!=2"> <!-- СМЕННЫЙ/Ежедневный учёт -->
									<xsl:call-template name="MonthResult">
										<xsl:with-param name="Result" select="$C_week"/><!-- sum(Day/@Komand)"/> -->
									</xsl:call-template>									
								</xsl:when>
								<xsl:otherwise>
								<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="$C_week_result"/>
							</xsl:call-template>
								</xsl:otherwise>
							</xsl:choose>
								
							
							
							
							<!--Обуч  -->
							<xsl:choose>
								<xsl:when test="@isSmena!=2"> <!-- СМЕННЫЙ/Ежедневный учёт -->
									<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="$E_week"/><!-- sum(Day/@Education)+sum(Day/@ShortEducation)"/> -->
							</xsl:call-template>									
								</xsl:when>
								<xsl:otherwise>
								<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="$E_week_result"/>
							</xsl:call-template>
								</xsl:otherwise>
							</xsl:choose>
							
							<!-- Гос.обяз. (О) -->
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@GosOb_O)"/>
							</xsl:call-template>	
							
							<!-- Отпуск -->
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@Otpusk)"/>
							</xsl:call-template>
							
							<!--Коэффициент оплаты отпуска-->
							<!-- <xsl:call-template name="WriteMonthResult">
								<xsl:with-param name="Result" select="string(Day[@Correction!=0]/@Correction)"/>
							</xsl:call-template> -->

							<!--Норма -->
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@Norma)+@TimeLost"/>
							</xsl:call-template>

							<!-- Потери рабочего времени за месяц -->
							<!--Всего-->
							<xsl:choose>
								<xsl:when test="@isSmena!=2">
									<xsl:call-template name="MonthResult">
										<xsl:with-param name="Result" select=	
										"sum(Day/@PrivateBolezn)+
										sum(Day/@PrivateRodi)+
										sum(Day/@PrivateBU)+
										sum(Day/@PrivateNB)+
										sum(Day/@PrivateOtpusk)+
										sum(Day/@PrivateKomand)+
										sum(Day/@PrivateKratk)+
										sum(Day/@Progul)+
										sum(Day/@NN)+
										sum(Day/@GosOb_N)+
										sum(Day/@UnsignedViolation)+sum(Day/@NormaNRVDiff)"/>
									</xsl:call-template>
								</xsl:when>
								<xsl:otherwise>
									<xsl:call-template name="MonthResult">
										<xsl:with-param name="Result" select="sum(Day/@PrivateBolezn)+sum(Day/@PrivateRodi)+sum(Day/@PrivateBU)+sum(Day/@PrivateNB)+sum(Day/@PrivateOtpusk)+sum(Day/@PrivateKomand)+(Day/@PrivateKratk)+sum(Day/@Progul)+sum(Day/@NN)+sum(Day/@GosOb_N)+sum(Day/@PrivateEducation)+sum(Day/@PrivateShortEducation)+sum(Day/@UnsignedViolation)"/>
									</xsl:call-template>
								</xsl:otherwise>
							</xsl:choose>

							<!--Болезнь-->
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@PrivateBolezn)"/>
							</xsl:call-template>

							<!--
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@PrivateRodi)"/>
							</xsl:call-template>
              -->
							<!--по уходу -->
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@PrivateBU)"/>
							</xsl:call-template>

							<!--не подтв больничный убран по проекту 1205-->
							<!-- <xsl:call-template name="MonthResult"> 
								<xsl:with-param name="Result" select="sum(Day/@PrivateNB)"/>
							</xsl:call-template> -->

							<!--Отпуск без сохранения заработной платы +  Административный отпуск + Отпуск по беременности и родам  -->
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@PrivateOtpusk)"/>
							</xsl:call-template>
							
							<!-- НН -->
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@NN)"/>
							</xsl:call-template>
							
							<!--Командировка убран по проекту 1205-->
					<!-- 		<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@PrivateKomand)"/>
							</xsl:call-template> -->
							<!--Обуч. убран по проекту 1205-->
					<!-- 		<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@PrivateEducation)+sum(Day/@PrivateShortEducation)"/>
							</xsl:call-template> -->

							<!--Потери по приему и увольнению-->
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="@TimeLost"/>
							</xsl:call-template>

							<!--Потери по Гос.обязанностям-->
							<xsl:call-template name="MonthResult">
								<xsl:with-param name="Result" select="sum(Day/@GosOb_N)"/>
							</xsl:call-template>

							<!-- Абсентеизм -->
							<xsl:call-template name="WriteMonthResult">
								<xsl:with-param name="Result" select="format-number((@AbsCoef*(@HoursDO_Absent+@HoursNN_Absent)-(@HoursDO_Absent+@HoursNN_Absent)) div 3600, '0.00')"/>
							</xsl:call-template> 

							<!--Незаявл + Прочие -->
							<xsl:choose>
								<xsl:when test="@isSmena!=2">
									<xsl:call-template name="MonthResult">
										<xsl:with-param name="Result" select="sum(Day/@UnsignedViolation)+sum(Day/@Progul)"/>
										<!--Незаявл -->
									</xsl:call-template>
									<xsl:call-template name="MonthResult">
										<xsl:with-param name="Result" select="sum(Day/@PrivateKratk)+sum(Day/@NormaNRVDiff)"/>
										<!--Прочие-->
									</xsl:call-template>
								</xsl:when>
								<xsl:otherwise>
									<xsl:call-template name="MonthResult">
										<xsl:with-param name="Result" select="sum(Day/@UnsignedViolation)+sum(Day/@Progul)"/>
										<!--Незаявл = Прогрулы + Недоработки (МОЖЕТ превышать реальную недоработку,т.к. прогулы берут сразу 8 часов и с ними никто потом не сверяется-->
									</xsl:call-template>
									<xsl:call-template name="MonthResult">
										<xsl:with-param name="Result" select="sum(Day/@PrivateKratk)"/>
										<!--Прочие-->
									</xsl:call-template>
								</xsl:otherwise>
							</xsl:choose>

							<!-- Справочно  -->						
							<!-- Переработка -->
							
							
							<!-- Всего -->
							<xsl:variable name="VSEGO_PERERAB">
								<xsl:if test="sum(Day/@PererabotkaT) > 0 or sum(Day/@PererabotkaN) > 0">
									<xsl:value-of select="format-number((sum(Day/@Pererabotka)), '0.00')" 	/>	
								</xsl:if>

								<xsl:if test="not(sum(Day/@PererabotkaT) > 0 or sum(Day/@PererabotkaN) > 0)">
									<xsl:value-of select="format-number(sum(Day/@Pererabotka)+ (@UpNorma), '0.00')"/>
								</xsl:if>
							</xsl:variable>

							<xsl:call-template name="WriteMonthResult">
							   <xsl:with-param name="Result" select="format-number($VSEGO_PERERAB div 3600  , '0.00')" 	/>	
							</xsl:call-template>
							
							<!--В зоне турникетов-->
							<xsl:call-template name="WriteMonthResult">
								<xsl:with-param name="Result" select="format-number(sum(Day/@PererabotkaT)div 3600, '0.00')"/>
								<!---->
							</xsl:call-template>

							<!-- В зоне с настенными считывателями -->
							<xsl:call-template name="WriteMonthResult">
								<xsl:with-param name="Result" select="format-number(sum(Day/@PererabotkaN)div 3600, '0.00')"/>
								<!---->
							</xsl:call-template>			
							
							<!-- По ИС Тайм Менеджменту -->
							<xsl:call-template name="WriteMonthResult">
								<xsl:with-param name="Result" select="format-number(sum(Day/@PererabotkaTM)div 3600, '0.00')"/>
								<!---->
							</xsl:call-template>

							<!-- Коэффициент превышения -->
							<xsl:if test="$VSEGO + sum(Day/@Otpusk) > 0">
								<xsl:call-template name="WriteMonthResult">
									<!-- <xsl:with-param name="Result" select="format-number($VSEGO_PERERAB div ($VSEGO + sum(Day/@Otpusk)) , '0.00')"/>  -->
									<xsl:with-param name="Result" select="format-number(
										(
										round(
											($VSEGO_PERERAB div (sum(Day/@Norma)+@TimeLost))*100
											) div 100
										)
										div
										(
										round(	
											(($VSEGO + sum(Day/@Otpusk)) div (sum(Day/@Norma)+@TimeLost))*100
											) div 100
										)


									, '0.00')"/> 
									
									
								</xsl:call-template>	
							</xsl:if>
							<xsl:if test="$VSEGO + sum(Day/@Otpusk) = 0">
								<xsl:call-template name="WriteMonthResult">
									<xsl:with-param name="Result" select="format-number('0.00' , '0.00')"/> 
								</xsl:call-template>	
							</xsl:if>
							
							<!-- Отношение переработки к Норме -->
							<xsl:if test="sum(Day/@Norma)+@TimeLost > 0">
								<xsl:call-template name="WriteMonthResult">
									<xsl:with-param name="Result" select="format-number($VSEGO_PERERAB div (sum(Day/@Norma)+@TimeLost), '0.00')"/>	
								</xsl:call-template>	
							</xsl:if>
							<xsl:if test="sum(Day/@Norma)+@TimeLost = 0">
								<xsl:call-template name="WriteMonthResult">
									<xsl:with-param name="Result" select="format-number('0.00' , '0.00')"/> 
								</xsl:call-template>	
							</xsl:if>
							
							<!-- Отношение отработанного времени к Норме -->
							<xsl:if test="sum(Day/@Norma)+@TimeLost > 0">
							<xsl:call-template name="WriteMonthResult">
									<xsl:with-param name="Result" select="format-number(($VSEGO + sum(Day/@Otpusk)) div (sum(Day/@Norma)+@TimeLost) , '0.00')"/>
								</xsl:call-template>									
							</xsl:if>
							<xsl:if test="sum(Day/@Norma)+@TimeLost = 0">
								<xsl:call-template name="WriteMonthResult">
									<xsl:with-param name="Result" select="format-number('0.00' , '0.00')"/> 
								</xsl:call-template>	
							</xsl:if>
							
							
							<!-- Абсентеизм -->
							<!-- Значение коффициента -->
							<xsl:call-template name="WriteMonthAbsent">
									<xsl:with-param name="Result" select="format-number(@AbsCoef, '0.00')"/>
							</xsl:call-template>
							
							<!-- Кол-во часов ДО -->
							<xsl:call-template name="WriteMonthAbsent">
								<xsl:with-param name="Result" select="format-number(@HoursDO_Absent div 3600, '0.00')"/>
							</xsl:call-template>
							<!-- Кол-во часов НН -->
							<xsl:call-template name="WriteMonthAbsent">
								<xsl:with-param name="Result" select="format-number(@HoursNN_Absent div 3600, '0.00')"/>
							</xsl:call-template>
							<!-- Кол-во часов коэф. ДОиНН -->
							<xsl:call-template name="WriteMonthAbsent">
								<xsl:with-param name="Result" select="format-number(@AbsCoef*(@HoursDO_Absent+@HoursNN_Absent) div 3600, '0.00')"/>
							</xsl:call-template> 
							
						</TR>
					</xsl:for-each>
				</TABLE>
			</BODY>
		</HTML>
	</xsl:template>
	
	<xsl:template name="NewTabelClick">
		<xsl:attribute name="onmouseover">
			this.style.cursor='hand';
		</xsl:attribute>
		<xsl:attribute name="onclick">
			window.open('<xsl:value-of select="@UrlString"/>')
		</xsl:attribute>
		<xsl:attribute name="title">
			Открыть Новый табель
		</xsl:attribute>
		Новый табель
	</xsl:template>	
	
	<xsl:template name="DayOfWeek">
		<xsl:param name="CurDay" select="1"/>
		<xsl:param name="ByPeople" select="0"/>
		<TD style="text-align:center;">
			<xsl:if test="$ByPeople=0">
		
			<xsl:value-of select="$CurDay"/>
			</xsl:if>
			<xsl:if test="$ByPeople=1">
				<xsl:attribute name="onmouseover">
					this.style.cursor='hand';
				</xsl:attribute>
				<xsl:attribute name="onclick">
					window.open('PeopleDay.asp?UIDStaff=<xsl:value-of select="@UIDStaff"/>&amp;DateCalc=<xsl:value-of select="/Tabel/@Year"/>-<xsl:value-of select="/Tabel/@Month"/>-<xsl:value-of select="format-number($CurDay,'00')"/>
					<xsl:if test="../@isAdmin!=''">&amp;isAdmin=<xsl:value-of select="../@isAdmin"/>
					</xsl:if>','_blank','location=0,menubar=0,status=1,toolbar=0,resizable=1,scrollbars=1')
				</xsl:attribute>
				<xsl:attribute name="title">
					<xsl:value-of select="@FIO"/> за <xsl:value-of select="format-number($CurDay,'00')"/>.<xsl:value-of select="/Tabel/@Month"/>.<xsl:value-of select="/Tabel/@Year"/>
				</xsl:attribute>
				<xsl:if test="@isSmena=2">
					<xsl:for-each select="Day/@Number[.=$CurDay]">
						<xsl:if test="(../@RequestReCalc)='1'">
							<xsl:attribute name="bgcolor">lavender</xsl:attribute>
						</xsl:if>
						<xsl:if test="../@FreeDay!=0">
							<xsl:attribute name="bgcolor">PeachPuff</xsl:attribute>
						</xsl:if> 
						<xsl:element name="FONT">
							<xsl:if test="../@hasViolation='0'">
								<xsl:attribute name="color">green</xsl:attribute>
							</xsl:if>
							<xsl:if test="../@ShortEducation>0">
								<xsl:attribute name="color">blue</xsl:attribute>
								<xsl:attribute name="style">FONT-WEIGHT:bolder;</xsl:attribute>
							</xsl:if>						
							<xsl:if test="../@hasViolation='1'">
								<xsl:attribute name="color">red</xsl:attribute>
							</xsl:if>						
							<xsl:if test="(../@PrivateKratk)!='0'">
								<xsl:attribute name="style">FONT-WEIGHT:bolder;</xsl:attribute>
							</xsl:if>
							<xsl:if test="../@Abbrev!=''">
								<xsl:attribute name="style">PADDING-RIGHT:10px;PADDING-LEFT:10px;</xsl:attribute>
								<xsl:value-of select="../@Abbrev"/>
							</xsl:if>
							<!-- Если за день нет оплачиваемых интервалов КРОМЕ удалёнки - раскрасить фиолетовым -->
							<xsl:if test="(number(../@RemoteWorkTotal) != 0) and (number(../@TotalWorked)=0 ) and (number(../@Kratk)=0 ) and (number(../@KratkTM)=0 ) and (number(../@Komand)=0) and (number(../@Education)) = 0 ">
								<xsl:attribute name="color">darkviolet</xsl:attribute>
							</xsl:if>
							<xsl:if test="../@Abbrev=''">
								<xsl:variable name="PayTime" select="(../@TotalWorked)+(../@Kratk)+(../@KratkTM)+(../@RemoteWorkTotal)"/> 
								<!--изменил Максимов М.А. убрал округление до минут и добавил секунды (Для суммированного графика)
										<xsl:choose>
										<xsl:when test="round(($PayTime mod 3600) div 60)=60">
											<xsl:value-of select="format-number(floor($PayTime div 3600)+1,'00')"/>
											<xsl:value-of select="':00'"/>
										</xsl:when>
										<xsl:otherwise>	
											<xsl:value-of select="format-number(floor($PayTime div 3600),'00')"/>				
											<xsl:value-of select="':'"/>
											<xsl:if test="(($PayTime mod 3600) mod 60) &gt;29">
												<xsl:value-of select="format-number(floor(($PayTime mod 3600) div 60)+1,'00')"/>
											</xsl:if>
											
											<xsl:if test="(($PayTime mod 3600) mod 60) &lt;30">
												<xsl:value-of select="format-number(floor(($PayTime mod 3600) div 60),'00')"/>
											</xsl:if>
										</xsl:otherwise>
										</xsl:choose>-->
								<xsl:value-of select="format-number(floor($PayTime div 3600),'00')"/>
								<xsl:value-of select="':'"/>
								<xsl:value-of select="format-number(floor(($PayTime mod 3600) div 60),'00')"/>
								<xsl:value-of select="':'"/>
								<xsl:value-of select="format-number(($PayTime mod 3600) mod 60,'00')"/>
							</xsl:if>
						</xsl:element>
					</xsl:for-each>
				</xsl:if>
				<xsl:if test="@isSmena!='2'">
					<xsl:for-each select="Day/@Number[.=$CurDay]">
						<xsl:if test="(../@RequestReCalc)='1'">
							<xsl:attribute name="bgcolor">lavender</xsl:attribute>
						</xsl:if>
						<xsl:if test="../@FreeDay!=0">
						<xsl:attribute name="bgcolor">PeachPuff</xsl:attribute>
						</xsl:if> 
						<xsl:element name="FONT">
							<xsl:if test="../@hasViolation='0'">
								<xsl:attribute name="color">green</xsl:attribute>
							</xsl:if>
							<xsl:if test="../@ShortEducation>0">
								<xsl:attribute name="color">blue</xsl:attribute>
								<xsl:attribute name="style">FONT-WEIGHT:bolder;</xsl:attribute>
							</xsl:if>						
							<xsl:if test="../@hasViolation='1'">
								<xsl:attribute name="color">red</xsl:attribute>
							</xsl:if>						
							<xsl:if test="(../@PrivateKratk)!='0'">
								<xsl:attribute name="style">FONT-WEIGHT:bolder;</xsl:attribute>
							</xsl:if>
							
							<!-- Если за день нет оплачиваемых интервалов КРОМЕ удалёнки - раскрасить фиолетовым 
							@isSmena!='2', поэтому здесь RemoteWorkTotal > 0 маловероятно что будет, но тем не менее
							-->
							<xsl:if test="(number(../@RemoteWorkTotal) != 0) and (number(../@TotalWorked)=0 ) and (number(../@Kratk)=0 ) and (number(../@KratkTM)=0 ) and (number(../@Komand)=0) and (number(../@Education)) = 0 ">
								<xsl:attribute name="color">darkviolet</xsl:attribute>
							</xsl:if>
						
							<!--
							<xsl:variable name="PayTime">
								<xsl:choose>
									<xsl:when test="(number(../@NormaNRV) != 0)">
										<xsl:value-of select="(../@NormaNRV)-(../@PrivateKratk)-(../@ShortEducation)-(../@UnsignedViolation)"/>
									</xsl:when>
									<xsl:otherwise>
										<xsl:value-of select="(../@Norma)-(../@PrivateKratk)-(../@ShortEducation)-(../@UnsignedViolation)"/>
									</xsl:otherwise>
								</xsl:choose>	
							</xsl:variable> -->
							
							<xsl:variable name="PayTime" select="(../@NormaFakt)-(../@PrivateKratk)-(../@ShortEducation)-(../@UnsignedViolation)"/>
							
							
							<xsl:if test="../@Abbrev!=''">
								<xsl:attribute name="style">PADDING-RIGHT:6px;PADDING-LEFT:10px;</xsl:attribute>
								<xsl:value-of select="../@Abbrev"/>
								<!--xsl:if test="$PayTime!=../@Norma">
									/
									<xsl:choose>
									<xsl:when test="round(($PayTime mod 3600) div 60)=60">
										<xsl:value-of select="format-number(floor($PayTime div 3600)+1,'00')"/>
										<xsl:value-of select="':00'"/>
									</xsl:when>
									<xsl:otherwise>	
										<xsl:value-of select="format-number(floor($PayTime div 3600),'00')"/>				
										<xsl:value-of select="':'"/>
										<xsl:if test="(($PayTime mod 3600) mod 60) &gt;29">
											<xsl:value-of select="format-number(floor(($PayTime mod 3600) div 60)+1,'00')"/>
										</xsl:if>
										<xsl:if test="(($PayTime mod 3600) mod 60) &lt;30">
											<xsl:value-of select="format-number(floor(($PayTime mod 3600) div 60),'00')"/>
										</xsl:if>
									</xsl:otherwise>
									</xsl:choose>
								</xsl:if-->
							</xsl:if>
							<xsl:if test="../@Abbrev=''">
								<xsl:choose>
									<xsl:when test="round(($PayTime mod 3600) div 60)=60">
										<xsl:value-of select="format-number(floor($PayTime div 3600)+1,'00')"/>
										<xsl:value-of select="':00'"/>
									</xsl:when>
									<xsl:otherwise>	
										<xsl:value-of select="format-number(floor($PayTime div 3600),'00')"/>				
										<xsl:value-of select="':'"/>
										<xsl:if test="(($PayTime mod 3600) mod 60) &gt;29">
											<xsl:value-of select="format-number(floor(($PayTime mod 3600) div 60)+1,'00')"/>
										</xsl:if>
										<xsl:if test="(($PayTime mod 3600) mod 60) &lt;30">
											<xsl:value-of select="format-number(floor(($PayTime mod 3600) div 60),'00')"/>
										</xsl:if>
									</xsl:otherwise>
								</xsl:choose>
							</xsl:if>
						</xsl:element>
					</xsl:for-each>
				</xsl:if>
			</xsl:if>
		</TD>
		<xsl:if test="$CurDay!=31">
			<xsl:call-template name="DayOfWeek">
				<xsl:with-param name="CurDay" select="$CurDay+1"/>
				<xsl:with-param name="ByPeople" select="$ByPeople"/>
			</xsl:call-template>
		</xsl:if>
	</xsl:template>
	<xsl:template name="WriteMonthResult">
		<xsl:param name="Result" select="''"/>
		<xsl:param name="HasError" select="0"/>
		<TD align="right">
			<xsl:if test="$Result!='0.00'">
				<xsl:attribute name="style">
					<xsl:choose>
						<!--Параметр HasError - 0,1 - факт наличия ошибок, по умолчанию 0 -->
						<xsl:when test="$HasError!=0">mso-number-format:Fixed;COLOR: red;</xsl:when>
						<xsl:otherwise>mso-number-format:Fixed;COLOR:blue;</xsl:otherwise>
					</xsl:choose>
				</xsl:attribute>								
				<xsl:value-of select="$Result"/>
				<!--<xsl:value-of select="$HasError"/>-->
			</xsl:if>			
		</TD>
	</xsl:template>
	
	<xsl:template name="WriteMonthAbsent">
		<xsl:param name="Result" select="''"/>
		<xsl:param name="HasError" select="0"/>
		<TD align="right">
			<xsl:if test="(@AbsCoef!='1.00') and (@AbsCoef!='0.00')" >
			
				<xsl:attribute name="style">
					<xsl:choose>
						<!--Параметр HasError - 0,1 - факт наличия ошибок, по умолчанию 0 -->
						<xsl:when test="$HasError!=0">mso-number-format:Fixed;COLOR: red;</xsl:when>
						<xsl:otherwise>mso-number-format:Fixed;COLOR:blue;</xsl:otherwise>
					</xsl:choose>
				</xsl:attribute>								
				<xsl:value-of select="$Result"/>
			</xsl:if>			
		</TD>
	</xsl:template>	
	
	<xsl:template name="MonthResult">
		<xsl:param name="Result" select="0"/>
		<xsl:param name="HasError" select="0"/>
		<xsl:call-template name="WriteMonthResult">
			<!--xsl:with-param name="Result" select="format-number(floor($Result div 36) div 100, '0.00')"/-->
			<xsl:with-param name="Result" select="format-number($Result div 3600,'0.00') "/>
			<xsl:with-param name="HasError" select="$HasError"/>
		</xsl:call-template>
	</xsl:template>
</xsl:stylesheet>