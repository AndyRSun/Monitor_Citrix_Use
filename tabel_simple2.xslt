<?xml version="1.0" encoding="UTF-8" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:msxsl="urn:schemas-microsoft-com:xslt" xmlns:user="http://www.eastline.ru/worktime">
	<xsl:output  method="html" encoding="windows-1251" media-type="application/vnd.ms-excel"/>
	<xsl:template match="/Tabel">
		<HTML>
			<HEAD>
				<TITLE>Табель УРВ <xsl:value-of select="@Year"/> год <xsl:value-of select="@Month"/> месяц <xsl:value-of select="@Path"/> (c <xsl:value-of select="@DateFrom"/> по <xsl:value-of select="@DateTo"/>)
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
					<TABLE ID="MyTable">
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
							<!-- <xsl:if test="@TimeResults='0'"> -->
								<TD width="140"> 
									<xsl:attribute name="onclick">f(this);</xsl:attribute>									
									<xsl:call-template name="NewTabelClick"></xsl:call-template>									
								</TD>
							<!-- </xsl:if>	 -->

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
					<xsl:value-of select="@Year"/> год <xsl:value-of select="@Month"/> месяц <xsl:value-of select="@Path"/> (c <xsl:value-of select="@DateFrom"/> по <xsl:value-of select="@DateTo"/>)
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
						<TD rowspan="3" style="border-right: 1px solid red">Норма</TD>
						<TD colspan="10" style="border-right: 1px solid red" >Потери рабочего времени за месяц</TD>
						<TD colspan="7" style="border-right: 1px solid red">Справочно</TD>
						<TD rowspan="2" colspan="4">Понижающий коэффициент абсентеизма (К)</TD>
					</TR>
					<TR align="center" class="TableHeader">
						<TD rowspan="2" border="2">Всего за искл. опл-го отпуска</TD>
						<TD colspan="6">в том числе</TD>
						<TD rowspan="2">Отпуск</TD>
						<TD rowspan="2">Всего</TD>
						<TD colspan="9" style="border-right: 1px solid red">в том числе</TD>
						<TD rowspan="1" colspan="4">Переработка</TD>
						<TD rowspan="1" colspan="3" style="border-right: 1px solid red">Соблюдение графика сменности</TD>
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
						<!-- <TD>НБ</TD> -->
						<TD>Отпуск (ДО)</TD>
						<TD>НН</TD>
						<!-- <TD>Команд.</TD> -->
						<!-- <TD>Обуч.</TD> -->
						<!---->
						<td>Потери по приему и увольнению</td>
						<td>Гос.обяз.</td>
						<td>Абсентеизм</td>
						<td>Незаявл.</td>
						<TD style="border-right: 1px solid red">Прочие</TD>
						<td>Всего</td>
						<td>В зоне турникетов</td>
						<td>В зоне с настенными считывателями</td>
						<td>По ИС Тайм Менеджмент</td>
						
						<td>Коэффициент превышения</td>
						<td>Отношение переработки к Норме</td>
						<td style="border-right: 1px solid red">Отношение отработанного времени к Норме</td>
						
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

							
							<!--Всего-->
								<xsl:call-template name="WriteMonthResult"> <xsl:with-param name="Result" select="format-number(@Vsego, '0.00')"/> </xsl:call-template>
							<!--Фактическое присутствие -->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@Fakt, '0.00')"/></xsl:call-template> 
							<!--Дистанционная работа-->							
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="HasError" select="@PeopleHasRemoteViolation"/><xsl:with-param name="Result" select="format-number((@Distance) , '0.00')"/></xsl:call-template>
							<!--Кр.отсутст. (служебка) -->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@Kratk, '0.00')"/></xsl:call-template> 
							<!--Команд.  -->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@Komandirovka, '0.00')"/></xsl:call-template> 
							<!--Обуч  -->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@Obuchenie, '0.00')"/></xsl:call-template> 
							<!--Гос.обяз. -->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@GosOb_O, '0.00')"/></xsl:call-template> 
							<!-- Отпуск --> 
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@Otpusk, '0.00')"/></xsl:call-template> 
							<!--Норма -->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@Norma, '0.00')"/></xsl:call-template> 
							<!-- Потери рабочего времени за месяц -->							
							<!--Всего-->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PoteriVsego, '0.00')"/></xsl:call-template> 
							<!--Болезнь-->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PoteriBolnichny, '0.00')"/></xsl:call-template> 
							<!--по уходу -->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PoteriBU, '0.00')"/></xsl:call-template> 
							<!--Отпуск без сохранения заработной платы +  Административный отпуск + Отпуск по беременности и родам  -->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PoteriOtpusk, '0.00')"/></xsl:call-template> 
							<!-- НН -->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PoteriNN, '0.00')"/></xsl:call-template> 							

							<!--Потери по приему и увольнению-->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PoteriPriemUvolnenie, '0.00')"/></xsl:call-template> 
							
							<!--Потери по Гособязанностям-->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PoteriGosOb_N, '0.00')"/></xsl:call-template> 							
	
							<!-- Абсентеизм -->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PoteriAbsenteizm, '0.00')"/></xsl:call-template> 

							<!--Незаявл + Прочие -->
							<!--Незаявл = Прогул + опоздание ранний уход /*+ недоработка*/ (МОЖЕТ превышать реальную недоработку,т.к. прогулы берут сразу 8 часов и с ними никто потом не сверяется-->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PoteriUnsignedViolation, '0.00')"/></xsl:call-template> 
							<!--Прочие (личка)-->
								<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PoteriProchie, '0.00')"/></xsl:call-template> 

							<!-- Справочно  -->						
								<!-- Переработка -->
								<!-- Всего -->
									<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PererabotkaItog, '0.00')"/></xsl:call-template> 
								<!--В зоне турникетов-->
									<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PererabotkaTurniket, '0.00')"/></xsl:call-template> 
								<!-- В зоне с настенными считывателями -->
									<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PererabotkaNastenn, '0.00')"/></xsl:call-template> 
								<!-- По Тайм Менеджменту -->
									<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@PererabotkaTM, '0.00')"/></xsl:call-template> 

									
								<!-- Соблюдение графика сменности -->	
								<!-- Коэффициент превышения -->
									<xsl:call-template name="WriteMonthResult2"><xsl:with-param name="Result" select="format-number(@KoefPrevysh, '0.00')"/></xsl:call-template> 
								<!-- Отношение переработки к Норме -->
									<xsl:call-template name="WriteMonthResult2"><xsl:with-param name="Result" select="format-number(@PererabKNorme, '0.00')"/></xsl:call-template> 
								<!-- Отношение отработанного времени к Норме -->
									<xsl:call-template name="WriteMonthResult2"><xsl:with-param name="Result" select="format-number(@VsegoKNorme, '0.00')"/></xsl:call-template> 
								
								<!-- Абсентеизм -->
								<!-- Значение коффициента -->
									<xsl:call-template name="WriteMonthAbsent"><xsl:with-param name="Result" select="format-number(@AbsentKoef, '0.00')"/></xsl:call-template> 
								<!-- Кол-во часов ДО -->
									<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@AbsentDO, '0.00')"/></xsl:call-template> 
								<!-- Кол-во часов НН -->
									<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@AbsentNN, '0.00')"/></xsl:call-template> 
								<!-- Кол-во часов коэф. ДОиНН -->
									<xsl:call-template name="WriteMonthResult"><xsl:with-param name="Result" select="format-number(@AbsentItog, '0.00')"/></xsl:call-template> 
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
		<xsl:if test="@TimeResults='0'">
			<xsl:attribute name="title">Показать табель в формате ЧЧ:ММ:СС</xsl:attribute>
			Табель в формате ЧЧ:ММ:СС
		</xsl:if>
		<xsl:if test="@TimeResults='1'">
			<xsl:attribute name="title">Показать табель в формате Часы (до сотых)</xsl:attribute>
			Табель в формате Часы (до сотых)
		</xsl:if>
	</xsl:template>	

	
	<xsl:template name="DayOfWeek">
		<xsl:param name="CurDay" select="1"/>
		<xsl:param name="ByPeople" select="0"/>
		<TD style="text-align:center;">
			<xsl:if test="$ByPeople=0">
				<xsl:if test="contains(@FreeDays, concat('[', $CurDay, ']'))"> <xsl:attribute name="bgcolor">PeachPuff</xsl:attribute> </xsl:if> 
				<!-- <xsl:if test="contains('[3]','[3],[5]'"> <xsl:attribute name="bgcolor">PeachPuff</xsl:attribute> </xsl:if>  -->
				<xsl:value-of select="$CurDay"/>
			</xsl:if>
			<xsl:if test="$ByPeople=1">
				<xsl:attribute name="onmouseover">
					this.style.cursor='hand';
				</xsl:attribute>
				<xsl:attribute name="onclick">
					window.open('PeopleDay.asp?UIDStaff=<xsl:value-of select="@UIDStaff"/>&amp;DateCalc=<xsl:value-of select="/Tabel/@Year"/>-<xsl:value-of select="/Tabel/@Month"/>-<xsl:value-of select="format-number($CurDay,'00')"/>					<xsl:if test="../@isAdmin!=''">&amp;isAdmin=<xsl:value-of select="../@isAdmin"/></xsl:if>','_blank','location=0,menubar=0,status=1,toolbar=0,resizable=1,scrollbars=1')
				</xsl:attribute>
				<xsl:attribute name="title"><xsl:value-of select="@FIO"/> за <xsl:value-of select="format-number($CurDay,'00')"/>.<xsl:value-of select="/Tabel/@Month"/>.<xsl:value-of select="/Tabel/@Year"/></xsl:attribute>
					<xsl:for-each select="Day/@Number[.=$CurDay]">
						<!--<xsl:attribute name="bgcolor"><xsl:value-of select="../@BGColor"/></xsl:attribute>-->
						<xsl:if test="../@FreeDay!=0">
						<xsl:attribute name="bgcolor">PeachPuff</xsl:attribute>
						</xsl:if> 
						<xsl:element name="FONT">						
							<xsl:attribute name="color"><xsl:value-of select="../@DayColor"/></xsl:attribute><!--Цвет шрифта дня--> 
							<xsl:attribute name="style"><xsl:value-of select="../@DayStyle"/></xsl:attribute><!--Стиль шрифта дня-->
							<xsl:if test="../@Abbrev!=''"><xsl:value-of select="../@Abbrev"/></xsl:if><!--Если есть аббревиатура-->
							<xsl:if test="../@Abbrev=''"><xsl:value-of select="../@DayCellValue"/></xsl:if><!--Если аббревиатуры нет (т.е. нормальный день)-->
						</xsl:element>
					</xsl:for-each>
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
		<xsl:param name="Comment" select="0"/>
		<TD align="right">
			<xsl:if test="$Result!='0.00'">
				<xsl:attribute name="style">
					<xsl:choose>
						<!--Параметр HasError - 0,1 - факт наличия ошибок, по умолчанию 0 -->
						<xsl:when test="$HasError!=0">mso-number-format:Fixed;COLOR: red;</xsl:when>
						<xsl:otherwise>mso-number-format:Fixed;COLOR:blue;</xsl:otherwise>
					</xsl:choose>
				</xsl:attribute>								
				<!-- <xsl:value-of select="$Result"/> -->
				<xsl:if test="../@TimeResults='0'">
					<xsl:value-of select=" format-number($Result div 3600,'0.00')"/>
				</xsl:if>
				<xsl:if test="../@TimeResults!='0'">
					<xsl:value-of select="format-number(floor($Result div 3600), '00')" />
					<xsl:value-of select="format-number(floor($Result div 60) mod 60, ':00')"/>
					<xsl:value-of select="format-number($Result mod 60, ':00')"/> 
				</xsl:if>	
				<xsl:if test="$Comment!='0'">
				
				<span style="color:darkgreen;">				
				<xsl:value-of select="'&#160;(+'"/> <!--  &#160;   - это &nbsp;   , но nbsp - это HTML-ная именованная константа и XML ругается, что не знает её, поэтому кодом -->
				
					<!-- <xsl:value-of select=" format-number( $Comment div 3600 ,'0.00')"/>  -->
					<xsl:value-of select=" format-number( $Comment div 3600 ,'0.00')"/>
					
				<xsl:value-of select="')'"/>
				</span>				
				
				</xsl:if>
				<!--<xsl:value-of select="$HasError"/>-->
			</xsl:if>			
		</TD>
	</xsl:template>
	
			<xsl:template name="WriteMonthResult2">
		<xsl:param name="Result" select="''"/>
		<xsl:param name="HasError" select="0"/>
		<xsl:param name="Comment" select="0"/>
		<TD align="right">
			<xsl:if test="$Result!='0.00'">
				<xsl:attribute name="style">
					<xsl:choose>
						<!--Параметр HasError - 0,1 - факт наличия ошибок, по умолчанию 0 -->
						<xsl:when test="$HasError!=0">mso-number-format:Fixed;COLOR: red;</xsl:when>
						<xsl:otherwise>mso-number-format:Fixed;COLOR:blue;</xsl:otherwise>
					</xsl:choose>
				</xsl:attribute>								
				<!-- <xsl:value-of select="$Result"/> -->
				<xsl:value-of select=" format-number($Result,'0.00')"/> 
				<xsl:if test="$Comment!='0'">
				
				<span style="color:darkgreen;">				
				<xsl:value-of select="'&#160;(+'"/> <!--  &#160;   - это &nbsp;   , но nbsp - это HTML-ная именованная константа и XML ругается, что не знает её, поэтому кодом -->
					<xsl:value-of select=" format-number( $Comment div 3600 ,'0.00')"/> 
					<!--<xsl:value-of select="format-number(floor($Comment div 3600),'00')"/>
					<xsl:value-of select="':'"/>
					<xsl:value-of select="format-number(floor(($Comment mod 3600) div 60),'00')"/>
					<xsl:value-of select="':'"/>
					<xsl:value-of select="format-number(($Comment mod 3600) mod 60,'00')"/> -->
				<xsl:value-of select="')'"/>
				</span>				
				
				</xsl:if>
				<!--<xsl:value-of select="$HasError"/>-->
			</xsl:if>			
		</TD>
	</xsl:template>
	
		<xsl:template name="WriteMonthAbsent">
		<xsl:param name="Result" select="''"/>
		<xsl:param name="HasError" select="0"/>
		<TD align="right">
			<xsl:if test="@AbsentKoef!='1.00'">
				<xsl:if test="@AbsentKoef!='0.00'" >
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
			</xsl:if>			 
		</TD>
	</xsl:template>	
	
	<xsl:template name="MonthResult">
		<xsl:param name="Result" select="0"/>
		<xsl:param name="HasError" select="0"/>
		<xsl:param name="Comment" select="0"/>
		<xsl:call-template name="WriteMonthResult">
			<!--xsl:with-param name="Result" select="format-number(floor($Result div 36) div 100, '0.00')"/-->
			<xsl:with-param name="Result" select="format-number($Result div 3600,'0.00') "/>
			<xsl:with-param name="HasError" select="$HasError"/>
			<xsl:with-param name="Comment" select="$Comment"/>
		</xsl:call-template>
	</xsl:template>
</xsl:stylesheet>