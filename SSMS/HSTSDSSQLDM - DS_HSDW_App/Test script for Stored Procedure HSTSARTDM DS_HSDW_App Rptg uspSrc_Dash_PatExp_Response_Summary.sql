USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

-- =====================================================================================
-- Create procedure uspSrc_Dash_PatExp_Response_Summary
-- =====================================================================================

--CREATE PROCEDURE [Rptg].[uspSrc_Dash_PatExp_Response_Summary]
--AS
/**********************************************************************************************************************
WHAT: Stored procedure for Patient Experience Dashboard - Child HCAHPS (Inpatient)
      Distinct list of received survey units and service lines by domain and discharge and received date
WHO : Tom Burgan
WHEN: 05/03/2019
WHY : Produce surveys results for patient experience dashboard
-----------------------------------------------------------------------------------------------------------------------
INFO: 
      INPUTS:	DS_HSDW_Prod.dbo.Fact_PressGaney_Responses
	            DS_HSDW_Stage.PressGaney.PG_Responses_xmlrip
				DS_HSDW_Prod.Rptg.vwFact_Pt_Enc_Clrt
				DS_HSDW_Prod.Rptg.Balanced_Scorecard_Mapping
				DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt
				DS_HSDW_App.Rptg.PG_Extnd_Attr
				DS_HSDW_Prod.dbo.Dim_Date
				DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc
                  
      OUTPUTS: DS_HSDW_App.Rptg.uspSrc_Dash_PatExp_Response_Summary
   
------------------------------------------------------------------------------------------------------------------------
MODS: 	05/03/2019 - Created procedure
		09/17/2019 - Edit logic that sets PG_DESG value
***********************************************************************************************************************/

SET NOCOUNT ON

--EXEC dbo.usp_TruncateTable @schema = 'Rptg',@Table = 'CHCAHPS_Response_Summary'

---------------------------------------------------

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
	--,SUBSTRING(rip.VALUE,1,2) AS PG_DESG
	,SUBSTRING(resp.Survey_Designator,1,2) AS PG_DESG
INTO #chcahps_resp
FROM DS_HSDW_Prod.Rptg.vwFact_PressGaney_Responses resp
--LEFT OUTER JOIN (
--SELECT seq.SURVEY_ID
--      ,seq.VALUE
--FROM (
--SELECT xmlrip.SURVEY_ID
--      ,xmlrip.VALUE
--	  ,xmlrip.Load_Dtm
--      ,ROW_NUMBER() OVER (PARTITION BY xmlrip.SURVEY_ID, xmlrip.VALUE ORDER BY xmlrip.Load_Dtm DESC) AS Seq
--FROM (
--SELECT DISTINCT
--       [SURVEY_ID]
--      ,[VALUE]
--      ,[Load_Dtm]
--  FROM [DS_HSDW_Stage].[PressGaney].[PG_Responses_xmlrip]
--  WHERE VARNAME = 'ITSERVTY') xmlrip
--) seq
--WHERE seq.Seq = 1) rip
--ON resp.SURVEY_ID = rip.SURVEY_ID
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
		--'2134', -- CH_38	3/6/2019 TMB Exclude responses for questiom "Provider tell child take new meds"
		'2384'  -- UNIT
	)
ORDER BY resp.sk_Fact_Pt_Acct

  -- Create index for temp table #chcahps_resp
  CREATE CLUSTERED INDEX IX_chcahps_resp ON #chcahps_resp ([sk_Fact_Pt_Acct])

SELECT
     resp.SURVEY_ID
	,resp.sk_Dim_PG_Question
	,resp.sk_Fact_Pt_Acct
	,resp.sk_Dim_Pt
	,resp.Svc_Cde
	,resp.RECDATE
	,resp.DISDATE
	,resp.FY
	,resp.VALUE
	,resp.sk_Dim_Clrt_DEPt
	,resp.sk_Dim_Physcn
	,resp.RESP_CAT
	,seq.sk_Dim_Clrt_DEPt AS enc_sk_Dim_Clrt_DEPt
INTO #chcahps_resp_dep
FROM (
	SELECT SURVEY_ID
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
	FROM #chcahps_resp
	WHERE ((PG_DESG IS NULL) OR (PG_DESG = 'PC'))) resp
LEFT OUTER JOIN (
    SELECT enc.sk_Fact_Pt_Acct
	      ,enc.sk_Dim_Clrt_DEPt
	FROM (
		SELECT sk_Fact_Pt_Acct
			  ,sk_Dim_Clrt_DEPt
	          ,ROW_NUMBER() OVER (PARTITION BY sk_Fact_Pt_Acct ORDER BY Appt_Dtm) AS Seq 
	    FROM DS_HSDW_Prod.Rptg.vwFact_Pt_Enc_Clrt) enc
	WHERE enc.Seq = 1) seq
    ON seq.sk_Fact_Pt_Acct = resp.sk_Fact_Pt_Acct
WHERE resp.sk_Dim_Clrt_DEPt > 0
ORDER BY resp.SURVEY_ID

  -- Create index for temp table #chcahps_resp_dep
  CREATE CLUSTERED INDEX IX_chcahps_resp_dep ON #chcahps_resp_dep ([SURVEY_ID])

SELECT
     resp.SURVEY_ID
	,resp.sk_Dim_PG_Question
	,resp.sk_Fact_Pt_Acct
	,resp.sk_Dim_Pt
	,resp.Svc_Cde
	,resp.RECDATE
	,resp.DISDATE
	,resp.FY
	,resp.VALUE
	,resp.sk_Dim_Clrt_DEPt
	,resp.sk_Dim_Physcn
	,resp.RESP_CAT
	,resp.enc_sk_Dim_Clrt_DEPt
    ,MAX(CASE WHEN resp.sk_Dim_PG_Question = 2384 THEN COALESCE(resp.VALUE,'Null Unit') ELSE NULL END) OVER(PARTITION BY resp.SURVEY_ID) AS UNIT
INTO #chcahps_resp_unit
FROM #chcahps_resp_dep resp
ORDER BY UNIT

  -- Create index for temp table #chcahps_resp_unit
  --CREATE CLUSTERED INDEX IX_chcahps_resp_unit ON #chcahps_resp_unit ([UNIT])

--SELECT
--     resp.SURVEY_ID
--	,resp.sk_Dim_PG_Question
--	,resp.sk_Fact_Pt_Acct
--	,resp.sk_Dim_Pt
--	,resp.Svc_Cde
--	,resp.RECDATE
--	,resp.DISDATE
--	,resp.FY
--	,resp.VALUE
--	,resp.sk_Dim_Clrt_DEPt
--	,resp.sk_Dim_Physcn
--	,resp.RESP_CAT
--	,resp.enc_sk_Dim_Clrt_DEPt
--    ,resp.UNIT
--    ,CASE resp.UNIT
--	   WHEN '7CENTRAL (Closed)' THEN '7CENTRAL'
--	   WHEN '7N PICU' THEN 'PIC N'
--	   WHEN '7W ACUTE' THEN '7WEST'
--	   WHEN 'PICU (Closed)' THEN 'PIC N'
--	   ELSE resp.UNIT
--	 END AS der_UNIT
--INTO #chcahps_resp_unit_der
--FROM #chcahps_resp_unit resp
--ORDER BY der_UNIT

  -- Create index for temp table #chcahps_resp_unit_der
  --CREATE CLUSTERED INDEX IX_chcahps_resp_unit_der ON #chcahps_resp_unit_der ([der_UNIT])

SELECT
     resp.SURVEY_ID
	,resp.sk_Dim_PG_Question
	,resp.sk_Fact_Pt_Acct
	,resp.sk_Dim_Pt
	,resp.Svc_Cde
	,resp.RECDATE
	,resp.DISDATE
	,resp.FY
	,resp.VALUE
	,resp.sk_Dim_Clrt_DEPt
	,resp.sk_Dim_Physcn
	,resp.RESP_CAT
	--,resp.enc_sk_Dim_Clrt_DEPt
    ,resp.UNIT
    --,resp.der_UNIT
	--,bscm.[Epic DEPARTMENT_ID]
	--,dep.DEPARTMENT_ID
	,CAST(dep.DEPARTMENT_ID AS VARCHAR(255)) AS DEPARTMENT_ID
	,dep.Clrt_DEPt_Nme
	--,dep.sk_Dim_Clrt_DEPt AS dep_sk_Dim_Clrt_DEPt
	,extd.DOMAIN
	,ddte.Fyear_num AS REC_FY
	,ddte.quarter_name
	,ddte.month_short_name
INTO #chcahps_resp_epic_id
FROM #chcahps_resp_unit resp
INNER JOIN DS_HSDW_Prod.Rptg.vwDim_Date ddte
	ON ddte.day_date = resp.RECDATE
--LEFT OUTER JOIN (SELECT DISTINCT
--					PressGaney_Name
--				   ,[Epic DEPARTMENT_ID]
--                 FROM DS_HSDW_Prod.Rptg.vwBalanced_ScoreCard_Mapping
--				 WHERE PressGaney_Name IS NOT NULL AND LEN(PressGaney_Name) > 0) bscm
--    ON bscm.PressGaney_Name = resp.der_UNIT
--LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep
--    ON dep.DEPARTMENT_ID =
--		    CASE resp.UNIT
--		      WHEN '8TMP' THEN 10243067
--		      WHEN 'PIMU' THEN 10243108
--			  WHEN '7N ACUTE' THEN 10243103
--		      ELSE CAST(bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
--		    END
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep
    ON dep.sk_Dim_Clrt_DEPt = resp.sk_Dim_Clrt_DEPt
LEFT OUTER JOIN
	(
		SELECT DISTINCT sk_Dim_PG_Question, DOMAIN, QUESTION_TEXT, QUESTION_TEXT_ALIAS FROM DS_HSDW_App.Rptg.PG_Extnd_Attr
	) extd
		ON resp.sk_Dim_PG_Question = extd.sk_Dim_PG_Question
WHERE extd.DOMAIN IS NOT NULL
ORDER BY resp.SURVEY_ID

--SELECT DISTINCT
--	sk_Dim_Clrt_DEPt
--  , DEPARTMENT_ID
--  , Clrt_DEPt_Nme
--  , DOMAIN
--FROM #chcahps_resp_epic_id
--ORDER BY DEPARTMENT_ID
--       , DOMAIN

----------------------------------------------------------------------------------------------------

--INSERT INTO Rptg.CHCAHPS_Response_Summary (SERVICE_LINE, CLINIC, EPIC_DEPARTMENT_ID, DOMAIN, sk_Dim_PG_Question, Rpt_Prd,
--                                           Event_Date, Event_Date_Disch, quarter_name, month_short_name
--                                          )
SELECT locations.SERVICE_LINE, locations.CLINIC, locations.EPIC_DEPARTMENT_ID, locations.DOMAIN, locations.sk_Dim_PG_Question, locations.Rpt_Prd, locations.Event_Date
      ,locations.Event_Date_Disch, locations.quarter_name, locations.month_short_name
FROM
(
	SELECT
		CASE WHEN responses.SUB_SERVICE_LINE IS NULL THEN responses.SERVICE_LINE
	         ELSE
		       CASE WHEN responses.SERVICE_LINE <> 'All Service Lines' THEN responses.SERVICE_LINE + ' - ' + responses.SUB_SERVICE_LINE
			        ELSE responses.SERVICE_LINE
			   END
		END AS SERVICE_LINE
	   ,responses.CLINIC
	   ,responses.EPIC_DEPARTMENT_ID
	   ,responses.DOMAIN
	   ,responses.sk_Dim_PG_Question
	   ,responses.Rpt_Prd
	   ,responses.Event_Date
	   ,responses.Event_Date_Disch
	   ,responses.quarter_name
	   ,responses.month_short_name
	FROM
	( 
	    SELECT DISTINCT
	        11 AS SERVICE_LINE_ID
	       ,'Womens and Childrens' AS SERVICE_LINE
	       ,'Children' AS SUB_SERVICE_LINE
	       ,CAST(CASE WHEN RespUnit.Clrt_DEPt_Nme IS NOT NULL THEN RespUnit.Clrt_DEPt_Nme + ' [' + CAST(TRIM(RespUnit.DEPARTMENT_ID) AS VARCHAR(250)) + ']'
	                  ELSE 'Unknown' + ' [' + CAST(TRIM(RespUnit.DEPARTMENT_ID) AS VARCHAR(250)) + ']'
                 END AS VARCHAR(500)) AS CLINIC
		   ,CAST(RespUnit.DEPARTMENT_ID AS VARCHAR(500)) AS EPIC_DEPARTMENT_ID
		   ,RespUnit.DOMAIN
		   ,RespUnit.sk_Dim_PG_Question
		   ,RespUnit.Rpt_Prd
		   ,RespUnit.Event_Date
		   ,RespUnit.Event_Date_Disch
		   ,RespUnit.quarter_name
		   ,RespUnit.month_short_name
	    FROM
		(
		    SELECT DISTINCT
		     --   CASE
		     --     WHEN sk_Dim_Clrt_DEPt IS NOT NULL AND sk_Dim_Clrt_DEPt > 0 THEN sk_Dim_Clrt_DEPt
			    --  WHEN der_UNIT IS NULL THEN enc_sk_Dim_Clrt_DEPt
			    --  WHEN der_UNIT <> 'RN (Closed)' THEN dep_sk_Dim_Clrt_DEPt
			    --  ELSE enc_sk_Dim_Clrt_DEPt
			    --END AS sk_Dim_Clrt_DEPt
		        DEPARTMENT_ID
			   ,Clrt_DEPt_Nme
			   ,UNIT
			   ,DOMAIN
			   ,sk_Dim_PG_Question
		       ,LEFT(DATENAME(MM, RECDATE), 3) + ' ' + CAST(DAY(RECDATE) AS VARCHAR(2)) AS Rpt_Prd
			   ,RECDATE AS Event_Date
			   ,DISDATE AS Event_Date_Disch
		       --,rec.quarter_name
		       --,rec.month_short_name
		       ,resp.quarter_name
		       ,resp.month_short_name
			FROM #chcahps_resp_epic_id resp
			--LEFT OUTER JOIN DS_HSDW_Prod.dbo.Dim_Date rec
			--    ON rec.day_date = RECDATE
		) AS RespUnit
        --LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dept
	       -- ON dept.sk_Dim_Clrt_DEPt = RespUnit.sk_Dim_Clrt_DEPt
        --LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc AS loc_master
	       -- ON dept.DEPARTMENT_ID = loc_master.EPIC_DEPARTMENT_ID
	) responses
) locations
ORDER BY locations.SERVICE_LINE, locations.CLINIC, locations.EPIC_DEPARTMENT_ID, locations.DOMAIN, locations.sk_Dim_PG_Question, locations.Rpt_Prd, locations.Event_Date

GO


