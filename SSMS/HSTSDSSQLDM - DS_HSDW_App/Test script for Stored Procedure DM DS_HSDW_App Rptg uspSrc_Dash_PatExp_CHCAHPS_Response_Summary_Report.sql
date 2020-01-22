USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

DECLARE @StartDate DATE
       ,@EndDate DATE

--SET @StartDate = NULL
--SET @EndDate = NULL
SET @StartDate = '7/1/2018'
--SET @EndDate = '12/29/2019'
--SET @StartDate = '7/1/2019'
SET @EndDate = '1/1/2020'

--CREATE PROC [Rptg].[uspSrc_Dash_PatExp_CHCAHPS_Response_Summary_Report]
--    (
--     @StartDate SMALLDATETIME = NULL,
--     @EndDate SMALLDATETIME = NULL,
     --@in_deps VARCHAR(MAX)
--    )
--AS
/**********************************************************************************************************************
WHAT: Stored procedure for Patient Experience Dashboard - Child HCAHPS (Inpatient) - Response Summary
WHO : Tom Burgan
WHEN: 1/1/2020
WHY : Report survey response summary for patient experience dashboard
-----------------------------------------------------------------------------------------------------------------------
INFO: 
      INPUTS:	DS_HSDW_Prod.Rptg.vwFact_PressGaney_Responses
	            DS_HSDW_Prod.Rptg.vwDim_Date
				DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt
				DS_HSDW_Prod.dbo.Dim_PG_Question
                DS_HSDW_Prod.dbo.Fact_Pt_Acct
				DS_HSDW_Prod.dbo.Dim_Pt
                DS_HSDW_Prod.dbo.Dim_Physcn
				DS_HSDW_App.Rptg.PG_Extnd_Attr
				DS_HSDW_App.Rptg.CHCAHPS_Goals
                  
      OUTPUTS: CHCAHPS Survey Results
   
------------------------------------------------------------------------------------------------------------------------
MODS: 	 1/1/2020 - Created procedure
***********************************************************************************************************************/

SET NOCOUNT ON

IF OBJECT_ID('tempdb..#chcahps_resp ') IS NOT NULL
DROP TABLE #chcahps_resp

IF OBJECT_ID('tempdb..#chcahps_resp_dep ') IS NOT NULL
DROP TABLE #chcahps_resp_dep

IF OBJECT_ID('tempdb..#chcahps_resp_unit ') IS NOT NULL
DROP TABLE #chcahps_resp_unit

--IF OBJECT_ID('tempdb..#chcahps_resp_unit_der ') IS NOT NULL
--DROP TABLE #chcahps_resp_unit_der

IF OBJECT_ID('tempdb..#chcahps_resp_epic_id ') IS NOT NULL
DROP TABLE #chcahps_resp_epic_id

IF OBJECT_ID('tempdb..#chcahps_resp_check ') IS NOT NULL
DROP TABLE #chcahps_resp_check

IF OBJECT_ID('tempdb..#surveys_ch_ip_sl ') IS NOT NULL
DROP TABLE #surveys_ch_ip_sl

IF OBJECT_ID('tempdb..#surveys_ch_ip_sl_goals ') IS NOT NULL
DROP TABLE #surveys_ch_ip_sl_goals

IF OBJECT_ID('tempdb..#surveys_ch_ip2_sl ') IS NOT NULL
DROP TABLE #surveys_ch_ip2_sl

IF OBJECT_ID('tempdb..#surveys_ch_ip3_sl ') IS NOT NULL
DROP TABLE #surveys_ch_ip3_sl

IF OBJECT_ID('tempdb..#CHCAHPS_Unit ') IS NOT NULL
DROP TABLE #CHCAHPS_Unit

IF OBJECT_ID('tempdb..#surveys_ch_ip_sl_sum ') IS NOT NULL
DROP TABLE #surveys_ch_ip_sl_sum

---------------------------------------------------
---Default date range is the first day of FY 19 (7/1/2018) to yesterday's date
DECLARE @currdate AS SMALLDATETIME;
--DECLARE @startdate AS DATE;
--DECLARE @enddate AS DATE;

    SET @currdate=CAST(CAST(GETDATE() AS DATE) AS SMALLDATETIME);

    IF @StartDate IS NULL
        AND @EndDate IS NULL
        BEGIN
            SET @StartDate = CAST('7/1/2018' AS DATE);
            SET @EndDate= DATEADD(DAY, -1, CAST(GETDATE() AS DATE)); 
        END; 

----------------------------------------------------
DECLARE @locstartdate SMALLDATETIME,
        @locenddate SMALLDATETIME

SET @locstartdate = @StartDate
SET @locenddate   = @EndDate

DECLARE @response_department_goal_department_translation TABLE
(
    Goal_Fiscal_Yr INT NOT NULL -- Fiscal year for translation
  , Response_Epic_Department_Id NVARCHAR(500) NOT NULL -- Epic department id value assigned to survey
  , Response_Epic_Department_Name NVARCHAR(500) NOT NULL -- Epic department name value assigned to survey
  , Goals_Epic_Department_Id NVARCHAR(500) NULL -- Epic department id value documented in Goals file
  , Goals_Epic_Department_Name NVARCHAR(500) NULL -- Epic department name value documented in Goals file
);
INSERT INTO @response_department_goal_department_translation
(
    Goal_Fiscal_Yr,
    Response_Epic_Department_Id,
    Response_Epic_Department_Name,
    Goals_Epic_Department_Id,
    Goals_Epic_Department_Name
)
VALUES
('2019','10243066','UVHE 8 CENTRAL OB','10243067','UVHE 8 TEMPORARY'),
('2019','10243094','UVHE 8 NORTH OB','10243067','UVHE 8 TEMPORARY'),
('2019','10243118','UVHE 7 NORTH NICU','10243103','UVHE 7NORTH ACUTE'),
('2019','10243043','UVHE PEDIATRIC ICU','10243100','UVHE PICU 7NORTH')
;

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
	,SUBSTRING(resp.Survey_Designator,1,2) AS PG_DESG
INTO #chcahps_resp
FROM DS_HSDW_Prod.Rptg.vwFact_PressGaney_Responses resp
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
AND resp.RECDATE BETWEEN @locstartdate AND @locenddate
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
    ,MAX(CASE WHEN resp.sk_Dim_PG_Question = 2384 THEN COALESCE(resp.VALUE,'Null Unit') ELSE NULL END) OVER(PARTITION BY resp.SURVEY_ID) AS UNIT
INTO #chcahps_resp_unit
FROM #chcahps_resp_dep resp
ORDER BY resp.RECDATE, resp.sk_Dim_Clrt_DEPt

  -- Create index for temp table #chcahps_resp_unit
  CREATE CLUSTERED INDEX IX_chcahps_resp_unit ON #chcahps_resp_unit ([RECDATE],[sk_Dim_Clrt_DEPt])

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
    ,resp.UNIT
	,CAST(dep.DEPARTMENT_ID AS VARCHAR(255)) AS DEPARTMENT_ID
	,dep.Clrt_DEPt_Nme
	,CAST(COALESCE(deptrns.Goals_Epic_Department_Id, dep.DEPARTMENT_ID) AS VARCHAR(255)) AS goal_DEPARTMENT_ID
	,ddte.Fyear_num AS REC_FY
INTO #chcahps_resp_epic_id
FROM #chcahps_resp_unit resp
INNER JOIN DS_HSDW_Prod.Rptg.vwDim_Date ddte
	ON ddte.day_date = resp.RECDATE
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep
    ON dep.sk_Dim_Clrt_DEPt = resp.sk_Dim_Clrt_DEPt
LEFT OUTER JOIN @response_department_goal_department_translation deptrns
	ON deptrns.[Goal_Fiscal_Yr] = ddte.Fyear_num
	AND CAST(deptrns.Response_Epic_Department_Id AS NUMERIC(18,0)) = dep.DEPARTMENT_ID
ORDER BY resp.SURVEY_ID

  -- Create index for temp table ##chcahps_resp_epic_id
  CREATE CLUSTERED INDEX IX_chcahps_resp_epic_id ON #chcahps_resp_epic_id ([SURVEY_ID])

SELECT DISTINCT
	  unittemp.SURVEY_ID
	 ,unittemp.sk_Fact_Pt_Acct
	 ,unittemp.RECDATE
	 ,unittemp.DISDATE
	 ,unittemp.FY
	 ,RespUnit.REC_FY
	 ,unittemp.Phys_Name
	 ,unittemp.Phys_Dept
	 ,unittemp.Phys_Div
	 ,unittemp.sk_Dim_Clrt_DEPt
	 ,RespUnit.DEPARTMENT_ID AS EPIC_DEPARTMENT_ID
	 ,RespUnit.Clrt_DEPt_Nme AS EPIC_DEPARTMENT_NAME
	 ,RespUnit.goal_DEPARTMENT_ID AS goal_EPIC_DEPARTMENT_ID
	 ,11 AS SERVICE_LINE_ID
	 ,'Womens and Childrens' AS SERVICE_LINE
	 ,'Children' AS SUB_SERVICE_LINE
	 ,RespUnit.UNIT AS UNIT
	 ,CASE WHEN RespUnit.Clrt_DEPt_Nme IS NOT NULL THEN RespUnit.Clrt_DEPt_Nme + ' [' + TRIM(RespUnit.DEPARTMENT_ID) + ']'
	       ELSE 'Unknown' + ' [' + TRIM(RespUnit.DEPARTMENT_ID) + ']'
      END AS CLINIC
	 ,unittemp.VALUE
	 ,unittemp.VAL_COUNT
	 ,unittemp.DOMAIN
	 ,unittemp.Domain_Goals
	 ,unittemp.Value_Resp_Grp
	 ,unittemp.TOP_BOX
	 ,unittemp.TOP_BOX_RESPONSE
	 ,unittemp.VARNAME
	 ,unittemp.Svc_Cde
	 ,unittemp.sk_Dim_PG_Question
	 ,unittemp.QUESTION_TEXT
	 ,unittemp.QUESTION_TEXT_ALIAS
	 ,unittemp.MRN_int
	 ,unittemp.NPINumber
	 ,unittemp.Pat_Name
	 ,unittemp.Pat_DOB
	 ,unittemp.Pat_Age
	 ,unittemp.Pat_Age_Survey_Recvd
	 ,unittemp.Pat_Age_Survey_Answer
	 ,unittemp.Pat_Sex
	INTO #surveys_ch_ip_sl
FROM
(
SELECT DISTINCT
	 Resp.SURVEY_ID
	,Resp.sk_Fact_Pt_Acct
	,Resp.RECDATE
	,Resp.DISDATE
	,Resp.FY
	,phys.DisplayName AS Phys_Name
	,phys.DEPT AS Phys_Dept
	,phys.Division AS Phys_Div
	,resp.sk_Dim_Clrt_DEPt AS sk_Dim_Clrt_DEPt
	,CAST(Resp.VALUE AS NVARCHAR(500)) AS VALUE -- prevents Tableau from erroring out on import data source
	,CASE WHEN Resp.VALUE IS NOT NULL THEN 1 ELSE 0 END AS VAL_COUNT
	,extd.DOMAIN
	,CASE WHEN resp.sk_Dim_PG_Question = '2130' THEN 'Quietness'
	      WHEN Resp.sk_Dim_PG_Question = '2129' THEN 'Cleanliness'
	      WHEN Resp.sk_Dim_PG_Question = '2151' THEN 'Rate Hospital'
	      WHEN Resp.sk_Dim_PG_Question = '2152' THEN 'Recommend'
		  ELSE DOMAIN
     END AS Domain_Goals
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
	THEN 'Very Good' -- Top Answer for a 1-5 question
	ELSE
		CASE WHEN resp.sk_Dim_PG_Question = '2151' THEN '10-Best hosp, 9' -- Rate Hospital 0-10
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
			THEN 'Always' -- Top Answer
			ELSE
				CASE WHEN resp.sk_Dim_PG_Question = '2152' THEN 'Definitely Yes' -- Recommend Hospital
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
					THEN 'Yes, definitely'
					ELSE 
						CASE WHEN Resp.sk_Dim_PG_Question IN
						    ( -- Yes/No scale questions
						        '2134'  -- CH_38
						    )
					    THEN 'Yes'
						ELSE NULL
						END
					END
				END
			END
		END
	 END AS TOP_BOX_RESPONSE
	,resp.Svc_Cde
	,resp.RESP_CAT
	,qstn.VARNAME
	,qstn.sk_Dim_PG_Question
	,extd.QUESTION_TEXT
	,extd.QUESTION_TEXT_ALIAS -- Short form of question text
	,fpa.MRN_int
	,phys.NPINumber
	,ISNULL(pat.PT_LNAME + ', ' + pat.PT_FNAME_MI, NULL) AS Pat_Name
	,pat.BIRTH_DT AS Pat_DOB
	,FLOOR((CAST(GETDATE() AS INTEGER) - CAST(pat.BIRTH_DT AS INTEGER)) / 365.25) AS Pat_Age -- actual age today
	,FLOOR((CAST(Resp.RECDATE AS INTEGER) - CAST(pat.BIRTH_DT AS INTEGER)) / 365.25) AS Pat_Age_Survey_Recvd -- Age when survey received
	,Resp_Age.AGE AS Pat_Age_Survey_Answer -- Age Answered on Survey VARNAME Age
	,CASE WHEN pat.PT_SEX = 'F' THEN 'Female'
		  WHEN pat.pt_sex = 'M' THEN 'Male'
	 ELSE 'Not Specified' END AS Pat_Sex
	FROM #chcahps_resp AS Resp
	INNER JOIN DS_HSDW_Prod.dbo.Dim_PG_Question AS qstn
		ON Resp.sk_Dim_PG_Question = qstn.sk_Dim_PG_Question
	LEFT OUTER JOIN
	(
		SELECT SURVEY_ID, CAST(MAX(VALUE) AS NVARCHAR(500)) AS AGE FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses
		WHERE sk_Fact_Pt_Acct > 0 AND sk_Dim_PG_Question = '2092' -- Age question for Inpatient
		GROUP BY SURVEY_ID
	) Resp_Age
		ON Resp.SURVEY_ID = Resp_Age.SURVEY_ID
	LEFT OUTER JOIN DS_HSDW_Prod.dbo.Fact_Pt_Acct AS fpa -- LEFT OUTER, including -1 or survey counts won't match press ganey
		ON Resp.sk_Fact_Pt_Acct = fpa.sk_Fact_Pt_Acct
	LEFT OUTER JOIN DS_HSDW_Prod.dbo.Dim_Pt AS pat
		ON Resp.sk_Dim_Pt = pat.sk_Dim_Pt
	LEFT OUTER JOIN DS_HSDW_Prod.dbo.Dim_Physcn AS phys
		ON Resp.sk_Dim_Physcn = phys.sk_Dim_Physcn
	LEFT OUTER JOIN
	(
		SELECT DISTINCT sk_Dim_PG_Question, DOMAIN, QUESTION_TEXT, QUESTION_TEXT_ALIAS FROM DS_HSDW_App.Rptg.PG_Extnd_Attr
	) extd
		ON RESP.sk_Dim_PG_Question = extd.sk_Dim_PG_Question
	WHERE ((Resp.PG_DESG IS NULL) OR (Resp.PG_DESG = 'PC'))
) AS unittemp
	LEFT OUTER JOIN
	(
		SELECT DISTINCT
			SURVEY_ID
		   ,UNIT
		   ,DEPARTMENT_ID
		   ,Clrt_DEPt_Nme
		   ,goal_DEPARTMENT_ID
		   ,REC_FY
		FROM #chcahps_resp_epic_id
	) AS RespUnit
	    ON unittemp.SURVEY_ID = RespUnit.SURVEY_ID
	ORDER BY REC_FY, SERVICE_LINE, EPIC_DEPARTMENT_ID, goal_EPIC_DEPARTMENT_ID, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID

  -- Create indexes for temp table #surveys_ch_ip_sl
  CREATE NONCLUSTERED INDEX IX_surveyschipsl ON #surveys_ch_ip_sl (REC_FY, SERVICE_LINE, EPIC_DEPARTMENT_ID, goal_EPIC_DEPARTMENT_ID, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID)

------------------------------------------------------------------------------------------
--- GENERATE GOALS

SELECT DISTINCT
       all_goals.REC_FY,
	   all_goals.SERVICE_LINE,
       all_goals.goal_EPIC_DEPARTMENT_ID,
       all_goals.Domain_Goals,
       all_goals.GOAL
INTO #surveys_ch_ip_sl_goals
FROM
(
SELECT
       resp.REC_FY,
       resp.SERVICE_LINE,
       resp.EPIC_DEPARTMENT_ID,
	   resp.goal_EPIC_DEPARTMENT_ID,
       resp.Domain_Goals,
	   goal.GOAL
FROM -- DEPARTMENT_ID values with matching EPIC_DEPARTMENT_ID values in goals table
	(
	SELECT DISTINCT
	       REC_FY,
           SERVICE_LINE,
           EPIC_DEPARTMENT_ID,
		   goal_EPIC_DEPARTMENT_ID,
           Domain_Goals
	FROM #surveys_ch_ip_sl
	) resp
	LEFT OUTER JOIN
	(
	SELECT goals.GOAL_FISCAL_YR
	     , goals.UNIT
		 , goals.EPIC_DEPARTMENT_ID
		 , goals.EPIC_DEPARTMENT_NAME
	     , goals.DOMAIN
		 , goals.GOAL
	FROM Rptg.CHCAHPS_Goals goals
	WHERE goals.EPIC_DEPARTMENT_ID <> 'All Units'
	) goal
	ON goal.GOAL_FISCAL_YR = resp.REC_FY
	AND goal.EPIC_DEPARTMENT_ID = resp.goal_EPIC_DEPARTMENT_ID
	AND goal.DOMAIN = resp.Domain_Goals
	WHERE goal.EPIC_DEPARTMENT_ID IS NOT NULL
UNION ALL -- DEPARTMENT_ID values without matching EPIC_DEPARTMENT_ID values in goals table: use 'All Units' goals for respective service line
SELECT
       goals.REC_FY,
       goals.SERVICE_LINE,
       goals.EPIC_DEPARTMENT_ID,
	   goals.goal_EPIC_DEPARTMENT_ID,
       goals.Domain_Goals,
       goal.GOAL
FROM
(
SELECT
	   resp.REC_FY,
       resp.SERVICE_LINE,
       resp.EPIC_DEPARTMENT_ID,
	   resp.goal_EPIC_DEPARTMENT_ID,
       resp.Domain_Goals,
	   goal.GOAL
FROM
	(
	SELECT DISTINCT
	       REC_FY,
           SERVICE_LINE,
           EPIC_DEPARTMENT_ID,
		   goal_EPIC_DEPARTMENT_ID,
           Domain_Goals
	FROM #surveys_ch_ip_sl
	) resp
	LEFT OUTER JOIN
	(
	SELECT GOAL_FISCAL_YR
	     , UNIT
		 , EPIC_DEPARTMENT_ID
		 , EPIC_DEPARTMENT_NAME
	     , DOMAIN
		 , GOAL
	FROM Rptg.CHCAHPS_Goals
	WHERE EPIC_DEPARTMENT_ID <> 'All Units'
	) goal
	ON goal.GOAL_FISCAL_YR = resp.REC_FY
	AND goal.EPIC_DEPARTMENT_ID = resp.goal_EPIC_DEPARTMENT_ID
	AND goal.DOMAIN = resp.Domain_Goals
	WHERE goal.EPIC_DEPARTMENT_ID IS NULL
) goals
LEFT OUTER JOIN
(
SELECT GOAL_FISCAL_YR
     , SERVICE_LINE
     , UNIT
	 , EPIC_DEPARTMENT_ID
	 , EPIC_DEPARTMENT_NAME
	 , DOMAIN
	 , GOAL
FROM Rptg.CHCAHPS_Goals
WHERE EPIC_DEPARTMENT_ID = 'All Units'
) goal
ON goal.GOAL_FISCAL_YR = goals.REC_FY
AND goal.SERVICE_LINE = 'Womens and Childrens'
AND goal.DOMAIN = goals.Domain_Goals
UNION ALL -- EPIC_DEPARTMENT_ID = 'All Units' goals by service line
  SELECT
       resp.REC_FY,
       resp.SERVICE_LINE,
       'All Units' AS EPIC_DEPARTMENT_ID,
       'All Units' AS goal_EPIC_DEPARTMENT_ID,
       resp.Domain_Goals,
	   goal.GOAL
FROM
	(
	SELECT DISTINCT
	       REC_FY,
           SERVICE_LINE,
           Domain_Goals
	FROM #surveys_ch_ip_sl
	) resp
	LEFT OUTER JOIN
	(
	SELECT goals.GOAL_FISCAL_YR
	     , goals.UNIT
		 , goals.EPIC_DEPARTMENT_ID
		 , goals.EPIC_DEPARTMENT_NAME
		 , goals.SERVICE_LINE
	     , goals.DOMAIN
		 , goals.GOAL
	FROM Rptg.CHCAHPS_Goals goals
	WHERE goals.EPIC_DEPARTMENT_ID = 'All Units'
	) goal
	ON goal.GOAL_FISCAL_YR = resp.REC_FY
	AND goal.SERVICE_LINE = 'Womens and Childrens'
	AND goal.DOMAIN = resp.Domain_Goals
UNION ALL -- EPIC_DEPARTMENT_ID = 'All Units' goals for Service_Line = 'All Service Lines'
  SELECT
       goal.GOAL_FISCAL_YR AS REC_FY,
	   'All Service Lines' AS SERVICE_LINE,
       'All Units' AS EPIC_DEPARTMENT_ID,
       'All Units' AS goal_EPIC_DEPARTMENT_ID,
       goal.DOMAIN AS Domain_Goals,
	   goal.GOAL
FROM
	(
	SELECT goals.GOAL_FISCAL_YR
	     , goals.UNIT
		 , goals.EPIC_DEPARTMENT_ID
		 , goals.EPIC_DEPARTMENT_NAME
		 , goals.SERVICE_LINE
	     , goals.DOMAIN
		 , goals.GOAL
	FROM Rptg.CHCAHPS_Goals goals
	INNER JOIN
	(
	SELECT DISTINCT
		REC_FY
	FROM #surveys_ch_ip_sl
	) resp
	ON goals.GOAL_FISCAL_YR = resp.REC_FY
	WHERE goals.EPIC_DEPARTMENT_ID = 'All Units' AND goals.SERVICE_LINE = 'All Service Lines'
	) goal
) all_goals
ORDER BY REC_FY, all_goals.SERVICE_LINE, goal_EPIC_DEPARTMENT_ID, Domain_Goals

  -- Create indexes for temp table #surveys_ch_ip_sl_goals
  CREATE NONCLUSTERED INDEX IX_surveyschipslgoals ON #surveys_ch_ip_sl_goals (REC_FY, SERVICE_LINE, goal_EPIC_DEPARTMENT_ID, Domain_Goals)

------------------------------------------------------------------------------------------

--- JOIN TO DIM_DATE

 SELECT
	'CHCAHPS' AS Event_Type
	,surveys_ch_ip_sl.SURVEY_ID
	,surveys_ch_ip_sl.sk_Fact_Pt_Acct
	,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
	,rec.day_date AS Event_Date
	,dis.day_date AS Event_Date_Disch
	,rec.Fyear_num AS Event_FY
	,surveys_ch_ip_sl.sk_Dim_PG_Question
	,surveys_ch_ip_sl.VARNAME
	,surveys_ch_ip_sl.QUESTION_TEXT
	,surveys_ch_ip_sl.QUESTION_TEXT_ALIAS
	,surveys_ch_ip_sl.EPIC_DEPARTMENT_ID
	,surveys_ch_ip_sl.EPIC_DEPARTMENT_NAME
	,surveys_ch_ip_sl.SERVICE_LINE_ID
	,surveys_ch_ip_sl.SERVICE_LINE
	,surveys_ch_ip_sl.SUB_SERVICE_LINE
	,surveys_ch_ip_sl.UNIT
	,surveys_ch_ip_sl.CLINIC
	,surveys_ch_ip_sl.DOMAIN
	,surveys_ch_ip_sl.Domain_Goals
	,surveys_ch_ip_sl.RECDATE AS Recvd_Date
	,surveys_ch_ip_sl.DISDATE AS Discharge_Date
	,surveys_ch_ip_sl.REC_FY
	,surveys_ch_ip_sl.MRN_int AS Patient_ID
	,surveys_ch_ip_sl.Pat_Name
	,surveys_ch_ip_sl.Pat_Sex
	,surveys_ch_ip_sl.Pat_DOB
	,surveys_ch_ip_sl.Pat_Age
	,surveys_ch_ip_sl.Pat_Age_Survey_Recvd
	,surveys_ch_ip_sl.Pat_Age_Survey_Answer
	,CASE WHEN surveys_ch_ip_sl.Pat_Age_Survey_Answer < 18 THEN 1 ELSE 0 END AS Peds
	,surveys_ch_ip_sl.NPINumber
	,surveys_ch_ip_sl.Phys_Name
	,surveys_ch_ip_sl.Phys_Dept
	,surveys_ch_ip_sl.Phys_Div
	,surveys_ch_ip_sl.GOAL
	,surveys_ch_ip_sl.VALUE
	,surveys_ch_ip_sl.Value_Resp_Grp
	,surveys_ch_ip_sl.TOP_BOX
	,surveys_ch_ip_sl.TOP_BOX_RESPONSE
	,surveys_ch_ip_sl.VAL_COUNT
	,rec.quarter_name
	,rec.month_num
	,rec.month_short_name
	,rec.year_num
INTO #surveys_ch_ip2_sl
FROM
	(SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @StartDate AND day_date <= @EndDate) rec
LEFT OUTER JOIN
(
SELECT surveys_ch_ip_sl.SURVEY_ID,
       surveys_ch_ip_sl.sk_Fact_Pt_Acct,
       surveys_ch_ip_sl.RECDATE,
       surveys_ch_ip_sl.DISDATE,
       surveys_ch_ip_sl.FY,
       surveys_ch_ip_sl.REC_FY,
       surveys_ch_ip_sl.Phys_Name,
       surveys_ch_ip_sl.Phys_Dept,
       surveys_ch_ip_sl.Phys_Div,
       surveys_ch_ip_sl.sk_Dim_Clrt_DEPt,
       surveys_ch_ip_sl.EPIC_DEPARTMENT_ID,
       surveys_ch_ip_sl.EPIC_DEPARTMENT_NAME,
       surveys_ch_ip_sl.goal_EPIC_DEPARTMENT_ID,
       surveys_ch_ip_sl.SERVICE_LINE_ID,
       surveys_ch_ip_sl.SERVICE_LINE,
       surveys_ch_ip_sl.SUB_SERVICE_LINE,
       surveys_ch_ip_sl.UNIT,
       surveys_ch_ip_sl.CLINIC,
       surveys_ch_ip_sl.VALUE,
       surveys_ch_ip_sl.VAL_COUNT,
       surveys_ch_ip_sl.DOMAIN,
       surveys_ch_ip_sl.Domain_Goals,
       surveys_ch_ip_sl.Value_Resp_Grp,
       surveys_ch_ip_sl.TOP_BOX,
       surveys_ch_ip_sl.TOP_BOX_RESPONSE,
       surveys_ch_ip_sl.VARNAME,
       surveys_ch_ip_sl.Svc_Cde,
       surveys_ch_ip_sl.sk_Dim_PG_Question,
       surveys_ch_ip_sl.QUESTION_TEXT,
       surveys_ch_ip_sl.QUESTION_TEXT_ALIAS,
       surveys_ch_ip_sl.MRN_int,
       surveys_ch_ip_sl.NPINumber,
       surveys_ch_ip_sl.Pat_Name,
       surveys_ch_ip_sl.Pat_DOB,
       surveys_ch_ip_sl.Pat_Age,
       surveys_ch_ip_sl.Pat_Age_Survey_Recvd,
       surveys_ch_ip_sl.Pat_Age_Survey_Answer,
       surveys_ch_ip_sl.Pat_Sex,
       surveys_ch_ip_sl_goals.GOAL
FROM #surveys_ch_ip_sl surveys_ch_ip_sl
LEFT OUTER JOIN
(
SELECT DISTINCT
	REC_FY
  , goal_EPIC_DEPARTMENT_ID
  , SERVICE_LINE
  , Domain_Goals
  , GOAL
FROM #surveys_ch_ip_sl_goals
WHERE goal_EPIC_DEPARTMENT_ID <> 'All Units'
) surveys_ch_ip_sl_goals
ON surveys_ch_ip_sl_goals.REC_FY = surveys_ch_ip_sl.REC_FY
AND surveys_ch_ip_sl_goals.goal_EPIC_DEPARTMENT_ID = surveys_ch_ip_sl.goal_EPIC_DEPARTMENT_ID
AND surveys_ch_ip_sl_goals.SERVICE_LINE = surveys_ch_ip_sl.SERVICE_LINE
AND surveys_ch_ip_sl_goals.Domain_Goals = surveys_ch_ip_sl.Domain_Goals
) surveys_ch_ip_sl
ON rec.day_date = surveys_ch_ip_sl.RECDATE
FULL OUTER JOIN
	(SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date <= @locenddate) dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
    ON dis.day_date = surveys_ch_ip_sl.DISDATE
WHERE rec.day_date BETWEEN @locstartdate and @locenddate 
ORDER BY Event_Date, SURVEY_ID, sk_Dim_PG_Question

-------------------------------------------------------------------------------------------------------------------------------------
-- SELF UNION TO ADD AN "All Units" UNIT

SELECT * INTO #surveys_ch_ip3_sl
FROM #surveys_ch_ip2_sl
UNION ALL

(

	 SELECT
		--'Child HCAHPS' AS Event_Type
		'CHCAHPS' AS Event_Type
		,surveys_ch_ip_sl.SURVEY_ID
		,surveys_ch_ip_sl.sk_Fact_Pt_Acct
		,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
		,rec.day_date AS Event_Date
		,dis.day_date AS Event_Date_Disch
	    ,rec.Fyear_num AS Event_FY
		,surveys_ch_ip_sl.sk_Dim_PG_Question
		,surveys_ch_ip_sl.VARNAME
		,surveys_ch_ip_sl.QUESTION_TEXT
		,surveys_ch_ip_sl.QUESTION_TEXT_ALIAS
	    ,surveys_ch_ip_sl.EPIC_DEPARTMENT_ID
		,surveys_ch_ip_sl.EPIC_DEPARTMENT_NAME
	    ,surveys_ch_ip_sl.SERVICE_LINE_ID
		,surveys_ch_ip_sl.SERVICE_LINE
		,surveys_ch_ip_sl.SUB_SERVICE_LINE
		,surveys_ch_ip_sl.UNIT
		,CASE WHEN surveys_ch_ip_sl.SURVEY_ID IS NULL THEN NULL
			ELSE 'All Units' END AS CLINIC
		,surveys_ch_ip_sl.Domain
		,surveys_ch_ip_sl.Domain_Goals
		,surveys_ch_ip_sl.RECDATE AS Recvd_Date
		,surveys_ch_ip_sl.DISDATE AS Discharge_Date
	    ,surveys_ch_ip_sl.REC_FY
		,surveys_ch_ip_sl.MRN_int AS Patient_ID
		,surveys_ch_ip_sl.Pat_Name
		,surveys_ch_ip_sl.Pat_Sex
		,surveys_ch_ip_sl.Pat_DOB
		,surveys_ch_ip_sl.Pat_Age
		,surveys_ch_ip_sl.Pat_Age_Survey_Recvd
		,surveys_ch_ip_sl.Pat_Age_Survey_Answer
		,CASE WHEN surveys_ch_ip_sl.Pat_Age_Survey_Answer < 18 THEN 1 ELSE 0 END AS Peds
		,surveys_ch_ip_sl.NPINumber
		,surveys_ch_ip_sl.Phys_Name
		,surveys_ch_ip_sl.Phys_Dept
		,surveys_ch_ip_sl.Phys_Div
		,goals.GOAL
		,surveys_ch_ip_sl.VALUE
		,surveys_ch_ip_sl.Value_Resp_Grp
		,surveys_ch_ip_sl.TOP_BOX
		,surveys_ch_ip_sl.TOP_BOX_RESPONSE
		,surveys_ch_ip_sl.VAL_COUNT
		,rec.quarter_name
		,rec.month_num
		,rec.month_short_name
		,rec.year_num
	 FROM
		 (SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @locstartdate AND day_date <= @locenddate) rec
	 LEFT OUTER JOIN #surveys_ch_ip_sl surveys_ch_ip_sl
	     ON rec.day_date = surveys_ch_ip_sl.RECDATE
	 FULL OUTER JOIN
		 (SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date <= @EndDate) dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
	     ON dis.day_date = surveys_ch_ip_sl.DISDATE
	 LEFT OUTER JOIN
		 (SELECT REC_FY
		        ,Domain_Goals
	            ,CASE
	               WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
	               ELSE GOAL
	             END AS GOAL
		  FROM #surveys_ch_ip_sl_goals
		  WHERE SERVICE_LINE = 'Womens and Childrens' AND goal_EPIC_DEPARTMENT_ID = 'All Units'
		 ) goals  -- CHANGE BASED ON GOALS FROM BUSH - CREATE NEW CHCAHPS_Goals
		 ON surveys_ch_ip_sl.REC_FY = goals.REC_FY AND surveys_ch_ip_sl.Domain_Goals = goals.Domain_Goals
	 WHERE (rec.day_date >= @locstartdate AND rec.day_date <= @locenddate) -- THIS IS ALL SERVICE LINES TOGETHER, USE "ALL SERVICE LINES" GOALS TO APPLY SAME GOAL DOMAIN GOAL TO ALL SERVICE LINES
)

----------------------------------------------------------------------------------------------------------------------
-- RESULTS

 SELECT  [Event_Type]
   ,[SURVEY_ID]
   ,CASE WHEN CLINIC IN
	(	SELECT CLINIC
		FROM
		(
			SELECT CLINIC, COUNT(DISTINCT(SERVICE_LINE)) AS SVC_LINES FROM #surveys_ch_ip3_sl 
			WHERE CLINIC <> 'All Units' 
			GROUP BY CLINIC
			HAVING COUNT(DISTINCT(SERVICE_LINE)) > 1
		) a
	) THEN CLINIC + ' - ' + SERVICE_LINE ELSE CLINIC END AS CLINIC -- adds svc line to units that appear in multiple service lines
	,CASE WHEN Sub_Service_Line IS NULL THEN [Service_Line]
	    ELSE
		CASE WHEN SERVICE_LINE <> 'All Service Lines' THEN SERVICE_LINE + ' - ' + Sub_Service_Line
			ELSE SERVICE_LINE
			END
		END AS SERVICE_LINE
   ,SUB_SERVICE_LINE
   ,EPIC_DEPARTMENT_ID
   ,EPIC_DEPARTMENT_NAME
   ,service_line_id
   ,[sk_Fact_Pt_Acct]
   ,[Rpt_Prd]
   ,[Event_Date]
   ,[Event_Date_Disch]
   ,[Event_FY]
   ,[sk_Dim_PG_Question]
   ,[VARNAME]
   ,[QUESTION_TEXT]
   ,[QUESTION_TEXT_ALIAS]
   ,[DOMAIN]
   ,[Domain_Goals]
   ,[Recvd_Date]
   ,[Discharge_Date]
   ,[Patient_ID]
   ,[Pat_Name]
   ,[Pat_Sex]
   ,[Pat_DOB]
   ,[Pat_Age]
   ,[Pat_Age_Survey_Recvd]
   ,[Pat_Age_Survey_Answer]
   ,[Peds]
   ,[NPINumber]
   ,[Phys_Name]
   ,[Phys_Dept]
   ,[Phys_Div]
   ,[GOAL]
   ,[UNIT]
   ,[VALUE]
   ,[Value_Resp_Grp]
   ,[TOP_BOX]
   ,[TOP_BOX_RESPONSE]
   ,[VAL_COUNT]
   ,[quarter_name]
   ,month_num
   ,[month_short_name]
   ,year_num
  INTO #CHCAHPS_Unit
  FROM #surveys_ch_ip3_sl

------------------------------------------------------------------------------------------
--- GENERATE SUMMARY FOR TESTING

SELECT resp.Event_Type,
	   resp.Event_FY,
	   resp.year_num,
       resp.month_num,
       resp.month_short_name,
       resp.CLINIC,
       resp.SERVICE_LINE,
       resp.Domain_Goals,
	   resp.QUESTION_TEXT_ALIAS,
       resp.EPIC_DEPARTMENT_ID,
       resp.epic_department_name,
	   resp.GOAL,
       SUM(resp.TOP_BOX) AS TOP_BOX,
       SUM(resp.VAL_COUNT) AS VAL_COUNT,
	   COUNT(DISTINCT resp.SURVEY_ID) AS SURVEY_ID_COUNT
INTO #surveys_ch_ip_sl_sum
FROM
(
--SELECT DISTINCT
SELECT
	Event_Type,
	Event_FY,
	year_num,
	month_num,
	month_short_name,
    CLINIC,
    SERVICE_LINE,
    EPIC_DEPARTMENT_ID,
    epic_department_name,
	VALUE,
	TOP_BOX,
    VAL_COUNT,
	DOMAIN,
    Domain_Goals,
	QUESTION_TEXT_ALIAS,
	SURVEY_ID,
	GOAL
FROM #CHCAHPS_Unit
WHERE
(Domain_Goals IS NOT NULL
AND Domain_Goals NOT IN
(
'Meals'
,'Overall Assessment'
,'Pediatric ICU/CCU'
,'Personal Issues'
))
) resp
GROUP BY 
	resp.Event_Type,
	resp.Event_FY,
	resp.year_num,
	resp.month_num,
	resp.month_short_name,
    resp.CLINIC,
    resp.SERVICE_LINE,
	resp.Domain_Goals,
	resp.QUESTION_TEXT_ALIAS,
    resp.EPIC_DEPARTMENT_ID,
    resp.epic_department_name,
	resp.GOAL

SELECT Event_Type,
       Event_FY,
	   year_num AS Event_CY,
       month_num AS [Month],
       month_short_name AS Month_Name,
       Service_Line,
       EPIC_DEPARTMENT_ID AS DEPARTMENT_ID,
       EPIC_DEPARTMENT_NAME AS DEPARTMENT_NAME,
       CLINIC,
       Domain_Goals,
       QUESTION_TEXT_ALIAS,
       TOP_BOX,
       VAL_COUNT,
       SURVEY_ID_COUNT AS N,
       GOAL
FROM #surveys_ch_ip_sl_sum
ORDER BY Event_Type
       , Event_FY
	   , year_num
       , month_num
	   , month_short_name
	   , Service_Line
	   , EPIC_DEPARTMENT_ID
	   , EPIC_DEPARTMENT_NAME
	   , CLINIC
	   , Domain_Goals
	   , QUESTION_TEXT_ALIAS

GO


