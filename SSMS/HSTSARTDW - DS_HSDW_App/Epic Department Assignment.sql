USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

SET NOCOUNT ON

IF OBJECT_ID('tempdb..#chcahps_resp ') IS NOT NULL
DROP TABLE #chcahps_resp

IF OBJECT_ID('tempdb..#chcahps_resp_dep ') IS NOT NULL
DROP TABLE #chcahps_resp_dep

IF OBJECT_ID('tempdb..#chcahps_resp_unit ') IS NOT NULL
DROP TABLE #chcahps_resp_unit

IF OBJECT_ID('tempdb..#chcahps_resp_unit_der ') IS NOT NULL
DROP TABLE #chcahps_resp_unit_der

IF OBJECT_ID('tempdb..#chcahps_resp_epic_id ') IS NOT NULL
DROP TABLE #chcahps_resp_epic_id

IF OBJECT_ID('tempdb..#chcahps_resp_check ') IS NOT NULL
DROP TABLE #chcahps_resp_check

IF OBJECT_ID('tempdb..#surveys_ch_ip_sl ') IS NOT NULL
DROP TABLE #surveys_ch_ip_sl

IF OBJECT_ID('tempdb..#surveys_ch_ip2_sl ') IS NOT NULL
DROP TABLE #surveys_ch_ip2_sl

IF OBJECT_ID('tempdb..#surveys_ch_ip3_sl ') IS NOT NULL
DROP TABLE #surveys_ch_ip3_sl

IF OBJECT_ID('tempdb..#CHCAHPS_Unit ') IS NOT NULL
DROP TABLE #CHCAHPS_Unit

IF OBJECT_ID('tempdb..#CHCAHPS_Unit_Summary ') IS NOT NULL
DROP TABLE #CHCAHPS_Unit_Summary

---------------------------------------------------
---Default date range is the first day of the current month 2 years ago until the last day of the current month
DECLARE @currdate AS DATE;
DECLARE @startdate AS DATE;
DECLARE @enddate AS DATE;


    SET @currdate=CAST(GETDATE() AS DATE);

    IF @startdate IS NULL
        AND @enddate IS NULL
        BEGIN
            SET @startdate = CAST(DATEADD(MONTH,DATEDIFF(MONTH,0,DATEADD(MONTH,-24,GETDATE())),0) AS DATE); 
            SET @enddate= CAST(EOMONTH(GETDATE()) AS DATE); 
        END; 

----------------------------------------------------

SELECT
	 resp.SURVEY_ID
	,resp.sk_Dim_PG_Question
	,resp.sk_Fact_Pt_Acct
	,resp.sk_Dim_Pt
	,resp.Svc_Cde
	,resp.RECDATE
	,resp.DISDATE
	,resp.FY
	,CAST(resp.VALUE AS NVARCHAR(500)) AS VALUE
	,resp.sk_Dim_Clrt_DEPt
	,resp.sk_Dim_Physcn
	,resp.RESP_CAT
	,SUBSTRING(rip.VALUE,1,2) AS PG_DESG
	,dept.DEPARTMENT_ID AS Epic_Department_Id
	,dept.Clrt_DEPt_Nme AS Epic_Department_Name
	,dte.month_num
	,dte.month_name
	,dte.year_num
INTO #chcahps_resp
FROM DS_HSDW_Prod.Rptg.vwFact_PressGaney_Responses resp
LEFT OUTER JOIN (
SELECT seq.SURVEY_ID
      ,seq.VALUE
FROM (
SELECT xmlrip.SURVEY_ID
      ,xmlrip.VALUE
	  ,xmlrip.Load_Dtm
      ,ROW_NUMBER() OVER (PARTITION BY xmlrip.SURVEY_ID, xmlrip.VALUE ORDER BY xmlrip.Load_Dtm DESC) AS Seq
FROM (
SELECT DISTINCT
       [SURVEY_ID]
      ,[VALUE]
      ,[Load_Dtm]
  FROM [DS_HSDW_Stage].[PressGaney].[PG_Responses_xmlrip]
  WHERE VARNAME = 'ITSERVTY') xmlrip
) seq
WHERE seq.Seq = 1) rip
    ON resp.SURVEY_ID = rip.SURVEY_ID
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dept
	ON dept.sk_Dim_Clrt_DEPt = resp.sk_Dim_Clrt_DEPt
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Date dte
    --ON dte.day_date = resp.DISDATE
    ON dte.day_date = resp.RECDATE
WHERE sk_Dim_PG_Question IN
	(
		'2092', -- AGE
		'2129', -- CH_33
		'2130', -- CH_34
		'2151', -- CH_48
		'2204', -- G10
		'2205', -- G33
		'2208', -- G9
		'2212', -- I35
		'2213', -- I4
		'2214', -- I49
		'2215', -- I4PR
		'2217', -- I50
		'2326', -- M2
		'2327', -- M2PR
		'2330', -- M8
		'2345', -- O2
		'2184', -- CH_8CL
		'2186', -- CH_9CL
		'2096', -- CH_10CL
		'2098', -- CH_11CL
		'2100', -- CH_12CL
		'2102', -- CH_13CL
		'2103', -- CH_14
		'2104', -- CH_15
		'2105', -- CH_16
		'2106', -- CH_17
		'2107', -- CH_18
		'2108', -- CH_19
		'2110', -- CH_20
		'2112', -- CH_22
		'2113', -- CH_23
		'2116', -- CH_25CL
		'2119', -- CH_27CL
		'2122', -- CH_29CL
		'2129', -- CH_33
		'2130', -- CH_34
		'2146', -- CH_45CL
		'2152', -- CH_49
		'2153', -- CH_4CL
		'2167', -- CH_5CL
		'2180', -- CH_6CL
		'2111', -- CH_21
		'2125', -- CH_30
		'2128', -- CH_32CL
		'2131', -- CH_35
		'2132', -- CH_36
		'2133', -- CH_37
		'2136', -- CH_39CL
		'2140', -- CH_40CL
		'2141', -- CH_41
		'2142', -- CH_42
		'2143', -- CH_43
		'2148', -- CH_46CL
		'2150', -- CH_47CL
		'2134', -- CH_38
		'2384'  -- UNIT
	)
--AND resp.DISDATE >= '7/1/2016 00:00'
--AND resp.DISDATE < '7/1/2019 00:00'
--AND resp.RECDATE >= '7/1/2016 00:00'
--AND resp.RECDATE < '7/1/2019 00:00'
AND resp.RECDATE >= '1/1/2018 00:00'
ORDER BY resp.sk_Fact_Pt_Acct

  -- Create index for temp table #chcahps_resp
  CREATE CLUSTERED INDEX IX_chcahps_resp ON #chcahps_resp ([sk_Fact_Pt_Acct])

--SELECT *
--FROM #chcahps_resp
--WHERE SURVEY_ID = 1229736443
--ORDER BY sk_Dim_PG_Question

SELECT DISTINCT
	resp.SURVEY_ID
   ,resp.sk_Dim_PG_Question
   ,resp.Svc_Cde
   ,resp.FY
   ,resp.VALUE
   ,resp.sk_Dim_Clrt_DEPt
   ,resp.Epic_Department_Id
   ,resp.Epic_Department_Name
   ,resp.month_num
   ,resp.month_name
   ,resp.year_num
   ,resp.PG_DESG
   ,resp.UNIT
INTO #chcahps_resp_unit
FROM (
SELECT
     SURVEY_ID
	,sk_Dim_PG_Question
	,sk_Fact_Pt_Acct
	,sk_Dim_Pt
	,Svc_Cde
	,RECDATE
	,DISDATE
	,FY
	,VALUE
	,sk_Dim_Clrt_DEPt
	,sk_Dim_Physcn
	,RESP_CAT
	,PG_DESG
	,Epic_Department_Id
	,Epic_Department_Name
	,month_num
	,month_name
	,year_num
    ,MAX(CASE WHEN sk_Dim_PG_Question = 2384 THEN COALESCE(VALUE,'Null Unit') ELSE NULL END) OVER(PARTITION BY SURVEY_ID) AS UNIT
FROM #chcahps_resp
WHERE ((PG_DESG IS NULL) OR (PG_DESG = 'PC'))) resp
ORDER BY UNIT

  -- Create index for temp table #chcahps_resp_unit
  CREATE CLUSTERED INDEX IX_chcahps_resp_unit ON #chcahps_resp_unit ([UNIT])

--SELECT *
--FROM #chcahps_resp_unit
--ORDER BY UNIT
--        ,SURVEY_ID

--SELECT *
--FROM #chcahps_resp_unit
--WHERE SURVEY_ID = 1229736443
--ORDER BY sk_Dim_PG_Question

--SELECT Svc_Cde
--     , sk_Dim_Clrt_DEPt
--	 , Epic_Department_Id
--	 , Epic_Department_Name
--	 , UNIT
--FROM #chcahps_resp_unit
--GROUP BY Svc_Cde
--        ,sk_Dim_Clrt_DEPt
--		,Epic_Department_Id
--		,Epic_Department_Name
--		,UNIT
----ORDER BY UNIT
----        ,SURVEY_ID
--ORDER BY Svc_Cde
--        ,sk_Dim_Clrt_DEPt
--		,Epic_Department_Id
--		,Epic_Department_Name
--		,UNIT

SELECT
	 resp.SURVEY_ID
	,resp.sk_Dim_PG_Question
	,resp.Svc_Cde
    ,resp.FY
	,resp.Value_Resp_Grp
	,resp.TOP_BOX
    ,resp.sk_Dim_Clrt_DEPt
    ,resp.PG_DESG
	,resp.Epic_Department_Id
	,resp.Epic_Department_Name
    ,resp.month_num
    ,resp.month_name
    ,resp.year_num
    ,resp.UNIT
    ,CASE resp.UNIT
	   WHEN '7CENTRAL (Closed)' THEN '7CENTRAL'
	   --WHEN '7N ACUTE' THEN '7NOR'
	   WHEN '7N PICU' THEN 'PIC N'
	   WHEN '7W ACUTE' THEN '7WEST'
	   WHEN 'PICU (Closed)' THEN 'PIC N'
	   ELSE resp.UNIT
	 END AS der_UNIT
INTO #chcahps_resp_unit_der
FROM (
SELECT SURVEY_ID
	  ,sk_Dim_PG_Question
	  ,Svc_Cde
      ,FY
	,CASE WHEN Resp.sk_Dim_PG_Question = '2151' THEN -- Rate Hospital 0-10
		CASE WHEN Resp.VALUE IN ('10-Best possible','10-Best hosp','9') THEN 'Very Good'
			WHEN Resp.VALUE IN ('7','8') THEN 'Good'
			WHEN Resp.VALUE IN ('5','6') THEN 'Average'
			WHEN Resp.VALUE IN ('3','4') THEN 'Poor'
			WHEN Resp.VALUE IN ('0-Worst possible','0-Worst hosp','1','2') THEN 'Very Poor'
		END
	 ELSE
		CASE WHEN resp.sk_Dim_PG_Question <> '2092' THEN -- Age
			CASE WHEN Resp.VALUE = '5' THEN 'Very Good'
				WHEN Resp.VALUE = '4' THEN 'Good'
				WHEN Resp.VALUE = '3' THEN 'Average'
				WHEN Resp.VALUE = '2' THEN 'Poor'
				WHEN Resp.VALUE = '1' THEN 'Very Poor'
				ELSE CAST(Resp.VALUE AS NVARCHAR(500)) 
			END
		ELSE CAST(Resp.VALUE AS NVARCHAR(500)) 
		END
	 END AS Value_Resp_Grp
	,CASE WHEN Resp.sk_Dim_PG_Question IN
	( -- 1-5 scale questions
		'2204', -- G10
		'2205', -- G33
		'2208', -- G9
		'2212', -- I35
		'2213', -- I4
		'2214', -- I49
		'2215', -- I4PR
		'2217', -- I50
		'2326', -- M2
		'2327', -- M2PR
		'2330', -- M8
		'2345'  -- O2
	)
	AND Resp.VALUE = '5' THEN 1 -- Top Answer for a 1-5 question
	ELSE
		CASE WHEN resp.sk_Dim_PG_Question = '2151' AND resp.VALUE IN ('10-Best possible','10-Best hosp','9') THEN 1 -- Rate Hospital 0-10
		ELSE
			CASE WHEN resp.sk_Dim_PG_Question IN
				( -- Always, Usually, Sometimes, Never scale questions
					'2184', -- CH_8CL
					'2186', -- CH_9CL
					'2096', -- CH_10CL
					'2098', -- CH_11CL
					'2100', -- CH_12CL
					'2102', -- CH_13CL
					'2103', -- CH_14
					'2104', -- CH_15
					'2105', -- CH_16
					'2106', -- CH_17
					'2107', -- CH_18
					'2108', -- CH_19
					'2110', -- CH_20
					'2112', -- CH_22
					'2113', -- CH_23
					'2116', -- CH_25CL
					'2119', -- CH_27CL
					'2122', -- CH_29CL
					'2129', -- CH_33
					'2130', -- CH_34
					'2146'  -- CH_45CL
				)
			AND Resp.VALUE = 'Always' THEN 1  -- Top Answer
			ELSE
				CASE WHEN resp.sk_Dim_PG_Question = '2152' AND Resp.VALUE = 'Definitely Yes' THEN 1 -- Recommend Hospital
				ELSE
					CASE WHEN Resp.sk_Dim_PG_Question IN
					    ( -- Yes, definitely - No scale questions
						    '2153', -- CH_4CL
						    '2167', -- CH_5CL
						    '2180', -- CH_6CL
						    '2111', -- CH_21
						    '2125', -- CH_30
						    '2128', -- CH_32CL
						    '2131', -- CH_35
						    '2132', -- CH_36
							'2133', -- CH_37
							'2136', -- CH_39CL
							'2140', -- CH_40CL
							'2141', -- CH_41
							'2142', -- CH_42
							'2143', -- CH_43
							'2148', -- CH_46CL
							'2150'  -- CH_47CL
					    )
					AND Resp.VALUE = 'Yes, definitely' THEN 1
					ELSE 
						CASE WHEN Resp.sk_Dim_PG_Question IN
						    ( -- Yes/No scale questions
						        '2134'  -- CH_38
						    )
					    AND Resp.VALUE = 'Yes' THEN 1
						ELSE 0
						END
					END
				END
			END
		END
	 END AS TOP_BOX
      ,sk_Dim_Clrt_DEPt
      ,PG_DESG
	  ,Epic_Department_Name
      ,month_num
      ,month_name
      ,year_num
      ,UNIT
	  ,Epic_Department_Id
FROM #chcahps_resp_unit Resp) resp
ORDER BY der_UNIT

  -- Create index for temp table #chcahps_resp_unit_der
  CREATE CLUSTERED INDEX IX_chcahps_resp_unit_der ON #chcahps_resp_unit_der ([der_UNIT])

--SELECT DISTINCT
--	   SURVEY_ID
--FROM #chcahps_resp_unit_der

SELECT Svc_Cde
     , COUNT(DISTINCT SURVEY_ID) AS Surveys
     , sk_Dim_Clrt_DEPt
	 , Epic_Department_Id
	 , Epic_Department_Name
	 , UNIT
	 , der_UNIT
FROM #chcahps_resp_unit_der
GROUP BY Svc_Cde
        ,sk_Dim_Clrt_DEPt
		,Epic_Department_Id
		,Epic_Department_Name
		,UNIT
		,der_UNIT
--ORDER BY UNIT
--        ,SURVEY_ID
ORDER BY Svc_Cde
        ,sk_Dim_Clrt_DEPt
		,Epic_Department_Id
		,Epic_Department_Name
		,UNIT
		,der_UNIT
/*
SELECT
	 resp.SURVEY_ID
    ,resp.FY
	,resp.Value_Resp_Grp
	,resp.TOP_BOX
    ,resp.sk_Dim_Clrt_DEPt
    ,resp.PG_DESG
	,resp.Epic_Department_Name
    ,resp.month_num
    ,resp.month_name
    ,resp.year_num
    ,resp.UNIT
    ,resp.der_UNIT
	,bscm.[Epic DEPARTMENT_ID]
	,dep.DEPARTMENT_ID
	,dep.sk_Dim_Clrt_DEPt AS dep_sk_Dim_Clrt_DEPt
	,dep.Clrt_DEPt_Nme AS dep_Epic_Department_Name
INTO #chcahps_resp_epic_id
FROM #chcahps_resp_unit_der resp
LEFT OUTER JOIN (SELECT DISTINCT
					PressGaney_Name
				   ,[Epic DEPARTMENT_ID]
                 FROM DS_HSDW_Prod.Rptg.vwBalanced_ScoreCard_Mapping
				 WHERE PressGaney_Name IS NOT NULL AND LEN(PressGaney_Name) > 0) bscm
    ON bscm.PressGaney_Name = resp.der_UNIT
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep
    ON dep.DEPARTMENT_ID =
		    CASE resp.UNIT
		      WHEN '8TMP' THEN 10243067
		      WHEN 'PIMU' THEN 10243108
			  WHEN '7N ACUTE' THEN 10243103
		      ELSE CAST(bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
		    END
ORDER BY resp.SURVEY_ID

SELECT DISTINCT
	 resp.SURVEY_ID AS [PG_SURVEY_ID]
    ,resp.FY AS [PG_Rec_FY]
	,resp.month_num AS [PG_Rec_Month]
	,resp.month_name AS [PG_Rec_Month_Name]
	,resp.year_num AS [PG_Rec_Year]
	,resp.Epic_Department_Name AS [PG_Epic_Department_Name]
    ,resp.PG_DESG AS [PG_PG_DESG]
    ,resp.UNIT AS [PG_UNIT]
    ,resp.der_UNIT AS [Derived_UNIT]
	,resp.dep_Epic_Department_Name AS [Derived_UNIT_Epic_Department_Name]
	,dept.Clrt_DEPt_Nme AS [Dashboard_Epic_Department_Name]
INTO #surveys_ch_ip_sl
FROM #chcahps_resp_epic_id resp
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dept
	ON dept.sk_Dim_Clrt_DEPt = CASE WHEN resp.dep_sk_Dim_Clrt_DEPt IS NULL THEN resp.sk_Dim_Clrt_DEPt ELSE resp.dep_sk_Dim_Clrt_DEPt END
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc AS loc_master
	ON dept.DEPARTMENT_ID = loc_master.EPIC_DEPARTMENT_ID

SELECT
     [PG_Rec_Month]
	,[PG_Rec_Month_Name]
	,[PG_Rec_Year]
	,[PG_Epic_Department_Name]
    ,[PG_PG_DESG]
    ,[PG_UNIT]
    ,[Derived_UNIT]
	,[Derived_UNIT_Epic_Department_Name]
	,[Dashboard_Epic_Department_Name]
	,COUNT(*) AS Survey_Count
INTO #CHCAHPS_Unit_Summary
FROM #surveys_ch_ip_sl
GROUP BY
         [PG_Rec_Year]
		,[PG_Rec_Month]
		,[PG_Rec_Month_Name]
	    ,[PG_Epic_Department_Name]
        ,[PG_PG_DESG]
        ,[PG_UNIT]
        ,[Derived_UNIT]
	    ,[Derived_UNIT_Epic_Department_Name]
	    ,[Dashboard_Epic_Department_Name]
ORDER BY
         [PG_Rec_Year]
		,[PG_Rec_Month]
	    ,COUNT(*) DESC
        ,[PG_Epic_Department_Name]
        ,[PG_PG_DESG]
        ,[PG_UNIT]
        ,[Derived_UNIT]
	    ,[Derived_UNIT_Epic_Department_Name]
	    ,[Dashboard_Epic_Department_Name]

SELECT
     [PG_Rec_Month_Name] AS [Rec_Month]
	,[PG_Rec_Year] AS [Rec_Year]
	,[PG_Epic_Department_Name] AS [PG_Department]
    ,[PG_PG_DESG] AS [PG_SrvcType]
    ,[PG_UNIT] AS [PG_Unit]
    ,[Derived_UNIT] AS [Derived_Unit]
	,[Derived_UNIT_Epic_Department_Name] AS [Derived_Unit_Department]
	,[Dashboard_Epic_Department_Name] AS [Dashboard_Department]
	,Survey_Count
FROM #CHCAHPS_Unit_Summary
ORDER BY
         [Rec_Year]
		,[PG_Rec_Month]
	    ,Survey_Count DESC
        ,[PG_Department]
        ,[PG_SrvcType]
        ,[PG_Unit]
        ,[Derived_Unit]
	    ,[Derived_Unit_Department]
	    ,[Dashboard_Department]

SELECT DISTINCT
     [PG_Epic_Department_Name] AS [PG_Department]
    ,[PG_PG_DESG] AS [PG_SrvcType]
    ,[PG_UNIT] AS [PG_Unit]
    ,[Derived_UNIT] AS [Derived_Unit]
	,[Derived_UNIT_Epic_Department_Name] AS [Derived_Unit_Department]
	,[Dashboard_Epic_Department_Name] AS [Dashboard_Department]
FROM #CHCAHPS_Unit_Summary
ORDER BY
         [PG_Department]
        ,[PG_SrvcType]
        ,[PG_Unit]
        ,[Derived_Unit]
	    ,[Derived_Unit_Department]
	    ,[Dashboard_Department]
*/
/* 
SELECT
	 resp.SURVEY_ID
    ,resp.FY
	,resp.Value_Resp_Grp
	,resp.TOP_BOX
    ,resp.sk_Dim_Clrt_DEPt
    ,resp.PG_DESG
	,resp.Epic_Department_Name
    ,resp.month_num
    ,resp.month_name
    ,resp.year_num
    ,resp.UNIT
    ,CASE resp.UNIT
	   WHEN '7CENTRAL (Closed)' THEN '7CENTRAL'
	   --WHEN '7N ACUTE' THEN '7NOR'
	   WHEN '7N PICU' THEN 'PIC N'
	   WHEN '7W ACUTE' THEN '7WEST'
	   WHEN 'PICU (Closed)' THEN 'PIC N'
	   ELSE resp.UNIT
	 END AS der_UNIT
INTO #chcahps_resp_unit_der
FROM (
SELECT SURVEY_ID
      ,FY
	  ,CASE WHEN VALUE IN ('10-Best possible','10-Best hosp','9') THEN 'Very Good'
			WHEN VALUE IN ('7','8') THEN 'Good'
			WHEN VALUE IN ('5','6') THEN 'Average'
			WHEN VALUE IN ('3','4') THEN 'Poor'
			WHEN VALUE IN ('0-Worst possible','0-Worst hosp','1','2') THEN 'Very Poor'
	   END AS Value_Resp_Grp
	  ,CASE WHEN VALUE IN ('10-Best possible','10-Best hosp','9') THEN 1 ELSE 0 END AS TOP_BOX-- Rate Hospital 0-10
      ,sk_Dim_Clrt_DEPt
      ,PG_DESG
	  ,Epic_Department_Name
      ,month_num
      ,month_name
      ,year_num
      ,UNIT
FROM #chcahps_resp_unit
WHERE sk_Dim_PG_Question = 2151) resp
ORDER BY der_UNIT

  -- Create index for temp table #chcahps_resp_unit_der
  CREATE CLUSTERED INDEX IX_chcahps_resp_unit_der ON #chcahps_resp_unit_der ([der_UNIT])

--SELECT *
--FROM #chcahps_resp_unit_der
----WHERE SURVEY_ID = 1229736443
--ORDER BY UNIT
--        ,SURVEY_ID

SELECT
	 resp.SURVEY_ID
    ,resp.FY
	,resp.Value_Resp_Grp
	,resp.TOP_BOX
    ,resp.sk_Dim_Clrt_DEPt
    ,resp.PG_DESG
	,resp.Epic_Department_Name
    ,resp.month_num
    ,resp.month_name
    ,resp.year_num
    ,resp.UNIT
    ,resp.der_UNIT
	,bscm.[Epic DEPARTMENT_ID]
	,dep.DEPARTMENT_ID
	,dep.sk_Dim_Clrt_DEPt AS dep_sk_Dim_Clrt_DEPt
	,dep.Clrt_DEPt_Nme AS dep_Epic_Department_Name
INTO #chcahps_resp_epic_id
FROM #chcahps_resp_unit_der resp
LEFT OUTER JOIN (SELECT DISTINCT
					PressGaney_Name
				   ,[Epic DEPARTMENT_ID]
                 FROM DS_HSDW_Prod.Rptg.vwBalanced_ScoreCard_Mapping
				 WHERE PressGaney_Name IS NOT NULL AND LEN(PressGaney_Name) > 0) bscm
    ON bscm.PressGaney_Name = resp.der_UNIT
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep
    ON dep.DEPARTMENT_ID =
		    CASE resp.UNIT
		      WHEN '8TMP' THEN 10243067
		      WHEN 'PIMU' THEN 10243108
			  WHEN '7N ACUTE' THEN 10243103
		      ELSE CAST(bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
		    END
ORDER BY resp.SURVEY_ID

--SELECT *
--FROM #chcahps_resp_epic_id
----WHERE SURVEY_ID = 1229736443
--ORDER BY UNIT
--        ,SURVEY_ID

SELECT DISTINCT
	 resp.SURVEY_ID AS [PG_SURVEY_ID]
    ,resp.FY AS [PG_Rec_FY]
	,resp.Value_Resp_Grp
	,resp.TOP_BOX
	,resp.month_num AS [PG_Rec_Month]
	,resp.month_name AS [PG_Rec_Month_Name]
	,resp.year_num AS [PG_Rec_Year]
    --,resp.sk_Dim_Clrt_DEPt AS [PG_sk_Dim_Clrt_DEPt]
	,resp.Epic_Department_Name AS [PG_Epic_Department_Name]
    ,resp.PG_DESG AS [PG_PG_DESG]
    ,resp.UNIT AS [PG_UNIT]
    ,resp.der_UNIT AS [Derived_UNIT]
	--,resp.[Epic DEPARTMENT_ID] AS [Derived_UNIT_Epic_Department_Id]
	--,resp.DEPARTMENT_ID AS [Derived_UNIT_Epic_Department_Id]
	--,resp.dep_sk_Dim_Clrt_DEPt AS [Derived_UNIT_sk_Dim_Clrt_DEPt]
	,resp.dep_Epic_Department_Name AS [Derived_UNIT_Epic_Department_Name]
	--,CASE WHEN resp.dep_sk_Dim_Clrt_DEPt IS NULL THEN resp.sk_Dim_Clrt_DEPt ELSE resp.dep_sk_Dim_Clrt_DEPt END AS der_sk_Dim_Clrt_DEPt
	--,dept.DEPARTMENT_ID AS dept_DEPARTMENT_ID
	,dept.Clrt_DEPt_Nme AS [Dashboard_Epic_Department_Name]
INTO #surveys_ch_ip_sl
FROM #chcahps_resp_epic_id resp
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dept
	ON dept.sk_Dim_Clrt_DEPt = CASE WHEN resp.dep_sk_Dim_Clrt_DEPt IS NULL THEN resp.sk_Dim_Clrt_DEPt ELSE resp.dep_sk_Dim_Clrt_DEPt END
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc AS loc_master
	ON dept.DEPARTMENT_ID = loc_master.EPIC_DEPARTMENT_ID
    --LEFT OUTER JOIN
	   -- (SELECT
		  --   EPIC_DEPARTMENT_ID
		  --  ,MAX(CASE WHEN SUB_SERVICE_LINE = 'Unknown' OR SUB_SERVICE_LINE IS NULL THEN NULL ELSE SUB_SERVICE_LINE END) AS SUB_SERVICE_LINE
	   --  FROM DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master
	   --  GROUP BY EPIC_DEPARTMENT_ID
	   -- ) MDM -- MDM_epicsvc view doesn't include sub service line
	   -- ON loc_master.epic_department_id = MDM.[EPIC_DEPARTMENT_ID]

--SELECT *
--FROM #surveys_ch_ip_sl
--ORDER BY PressGaney_UNIT
--        ,PressGaney_SURVEY_ID

SELECT
     --[PG_Rec_FY]
	 [PG_Rec_Month]
	,[PG_Rec_Month_Name]
	,[PG_Rec_Year]
	,[PG_Epic_Department_Name]
    ,[PG_PG_DESG]
    ,[PG_UNIT]
    ,[Derived_UNIT]
	,[Derived_UNIT_Epic_Department_Name]
	,[Dashboard_Epic_Department_Name]
	,COUNT(*) AS Survey_Count
	,SUM(TOP_BOX) AS Top_Box
INTO #CHCAHPS_Unit_Summary
FROM #surveys_ch_ip_sl
GROUP BY
         --[PG_Rec_FY]
		 [PG_Rec_Year]
		,[PG_Rec_Month]
		,[PG_Rec_Month_Name]
	    ,[PG_Epic_Department_Name]
        ,[PG_PG_DESG]
        ,[PG_UNIT]
        ,[Derived_UNIT]
	    ,[Derived_UNIT_Epic_Department_Name]
	    ,[Dashboard_Epic_Department_Name]
ORDER BY
         --[PG_Rec_FY]
		 [PG_Rec_Year]
		,[PG_Rec_Month]
	    ,COUNT(*) DESC
        ,[PG_Epic_Department_Name]
        ,[PG_PG_DESG]
        ,[PG_UNIT]
        ,[Derived_UNIT]
	    ,[Derived_UNIT_Epic_Department_Name]
	    ,[Dashboard_Epic_Department_Name]

SELECT
     [PG_Rec_Month_Name] AS [Rec_Month]
	,[PG_Rec_Year] AS [Rec_Year]
	,[PG_Epic_Department_Name] AS [PG_Department]
    ,[PG_PG_DESG] AS [PG_SrvcType]
    ,[PG_UNIT] AS [PG_Unit]
    ,[Derived_UNIT] AS [Derived_Unit]
	,[Derived_UNIT_Epic_Department_Name] AS [Derived_Unit_Department]
	,[Dashboard_Epic_Department_Name] AS [Dashboard_Department]
	,Survey_Count
	,Top_Box
FROM #CHCAHPS_Unit_Summary
ORDER BY
         [Rec_Year]
		,[PG_Rec_Month]
	    ,Survey_Count DESC
        ,[PG_Department]
        ,[PG_SrvcType]
        ,[PG_Unit]
        ,[Derived_Unit]
	    ,[Derived_Unit_Department]
	    ,[Dashboard_Department]

SELECT
     [PG_Rec_Month_Name] AS [Rec_Month]
	,[PG_Rec_Year] AS [Rec_Year]
	,SUM(Survey_Count) AS Survey_Count
	,SUM(Top_Box) AS Top_Box
	,CAST(SUM(Top_Box) AS NUMERIC(7,2))/CAST(SUM(Survey_Count) AS NUMERIC(7,2)) AS Top_Box_Pct
FROM #CHCAHPS_Unit_Summary
GROUP BY
         [PG_Rec_Year]
		,[PG_Rec_Month]
		,[PG_Rec_Month_Name]
ORDER BY
         [Rec_Year]
		,[PG_Rec_Month]
--ORDER BY
--         [PG_SrvcType]
--		,[Rec_Year]
--		,[PG_Rec_Month]
--	    ,Survey_Count DESC
--        ,[PG_Department]
--        ,[PG_Unit]
--        ,[Derived_Unit]
--	    ,[Derived_Unit_Department]
--	    ,[Dashboard_Department]

--SELECT DISTINCT
--     [PG_Epic_Department_Name] AS [PG_Department]
--    ,[PG_UNIT] AS [PG_Unit]
--    ,[Derived_UNIT] AS [Derived_Unit]
--	,[Derived_UNIT_Epic_Department_Name] AS [Derived_Unit_Department]
--	,[Dashboard_Epic_Department_Name] AS [Dashboard_Department]
--FROM #CHCAHPS_Unit_Summary
--WHERE PG_Epic_Department_Name = 'UVHE 7 WEST'
--OR PG_UNIT = 'PIMU'
--ORDER BY
--         [PG_Department]
--        ,[PG_Unit]
--        ,[Derived_Unit]
--	    ,[Derived_Unit_Department]
--	    ,[Dashboard_Department]
*/
GO


