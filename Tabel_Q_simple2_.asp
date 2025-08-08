<!-- #INCLUDE FILE="UTIL\function.ASP" -->
<!-- #INCLUDE FILE="UTIL\CONNECT.ASP" -->
<%
Response.Expires=-1
if Request.TotalBytes<>0 or Request.QueryString("QueryAdmin")<>"" then 
	Dim Cmd,XMLQuery,XMLDocument,XMLTemplate


	Set XMLQuery=Server.CreateObject("Msxml2.FreeThreadedDOMDocument.4.0")
	
	if Request.QueryString("QueryAdmin")<>"" then 
		XMLQuery.loadxml Request.QueryString("QueryAdmin")
	else 

	if Request.QueryString("REFRESH")<>"" or Request.QueryString("XLS")<>"" or Request.QueryString("RECALC")<>"" then
		XMLQuery.loadxml Request.Form("Query")
	else
		XMLQuery.loadxml GetEncodedPOSTFromUI2toUI1()		
		'XMLQuery.loadxml Request.querystring("Query")
		Response.Write "1"	
		Response.Write XMLQuery.xml
		Response.Write "2"	
	end if
	end if
	

	
Server.ScriptTimeout=30
	

	Set cmd=Server.CreateObject("ADODB.Command")
	Set cmd.ActiveConnection =con
	cmd.CommandTimeOut=0
	if Request.QueryString("RECALC")<>"" then
		Server.ScriptTimeout=1000
		cmd.CommandText="exec _XMLReCalcViolation '"+replace(XMLQuery.xml,"'","''")+"'"
		cmd.Execute 
	end if
	Set XMLDocument=Server.CreateObject("Msxml2.FreeThreadedDOMDocument.4.0")
	
	
	<!--cmd.CommandText="exec _XMLTabel_simple @Query='"+replace(XMLQuery.xml,"'","''")+"'"-->
	cmd.CommandText="exec _XMLTabel_simple2 @Query='"+replace(XMLQuery.xml,"'","''")+"', @forOverwork = 0, @TimeResults = 1 "
	cmd.Properties("Output Stream").Value = XMLDocument
	cmd.Execute ,,1024
	if XMLDocument.xml<>"" then
		if Request.QueryString("XLS")<>"" then
			Response.ContentType = "application/vnd.ms-excel"
			Response.AddHeader "content-disposition","attachment; filename=Табель УРВ.XLS" 
		end if
		XMLDocument.documentElement.appendChild XMLQuery.documentElement 
		XMLDocument.documentElement.setAttribute "XLS",Request.QueryString("XLS")
		XMLDocument.documentElement.setAttribute "RECALC",Request.QueryString("RECALC")
		
		Set XMLTemplate=Server.CreateObject("Msxml2.FreeThreadedDOMDocument.4.0")
		XMLTemplate.async=false

		tableStr="tabel_simple2.xslt"
		if Request.QueryString("IsNew")="1" then tableStr="tabel_new.xslt"
		
		XMLTemplate.load Server.MapPath(tableStr)
		
		XMLDocument.transformNodeToObject XMLTemplate,Response
		'response.Write XMLDocument.xml
	else
		Response.Write "Не верный запрос, данные о сотрудниках не существуют."
	end if
	Set Cmd=nothing
	Set XMLQuery=nothing
	Set XMLDocument=nothing
	Set XMLTemplate=nothing
else
	Response.Write "Воспользуйтесь формой запроса табеля в ИС LN Учет рабочего времени."
end if
%>