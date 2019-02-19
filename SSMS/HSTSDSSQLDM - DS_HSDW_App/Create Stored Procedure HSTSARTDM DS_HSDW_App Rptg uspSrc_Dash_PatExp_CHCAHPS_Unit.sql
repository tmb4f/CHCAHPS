USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [Rptg].[uspSrc_Dash_PatExp_CHCAHPS_Unit]
AS
/**********************************************************************************************************************
WHAT: Stored procedure for Patient Experience Dashboard - Child HCAHPS (Inpatient) - By Unit
WHO : Tom Burgan
WHEN: 4/17/2018
WHY : Produce surveys results for patient experience dashboard
-----------------------------------------------------------------------------------------------------------------------
INFO: 
      INPUTS:	DS_HSDW_Prod.dbo.Fact_PressGaney_Responses
				DS_HSDW_Prod.rptg.Balanced_Scorecard_Mapping
				DS_HSDW_Prod.dbo.Dim_PG_Question
				DS_HSDW_Prod.dbo.Fact_Pt_Acct
				DS_HSDW_Prod.dbo.Dim_Pt
				DS_HSDW_Prod.dbo.Dim_Physcn
				DS_HSDW_Prod.dbo.Dim_Date
				DS_HSDW_App.Rptg.[PG_Extnd_Attr]
                  
      OUTPUTS: CHCAHPS Survey Results
   
------------------------------------------------------------------------------------------------------------------------
MODS: 	4/17/2018 - Created procedure
        7/26/2018 - Change name of Service_Line column
		10/4/2018 - Format script similar to CGCAHPS
***********************************************************************************************************************/

SET NOCOUNT ON

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
	SURVEY_ID
	,sk_Dim_PG_Question
	,sk_Fact_Pt_Acct
	,sk_Dim_Pt
	,Svc_Cde
	,RECDATE
	,DISDATE
	,CAST(VALUE AS NVARCHAR(500)) AS VALUE
	,sk_Dim_Clrt_DEPt
	,sk_Dim_Physcn
	,RESP_CAT
INTO #chcahps_resp
FROM DS_HSDW_Prod.Rptg.vwFact_PressGaney_Responses
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

--SELECT *
--FROM #chcahps_resp
--ORDER BY SURVEY_ID
--       , sk_Dim_PG_Question

----------------------------------------------------------------------------------------------------

CREATE TABLE #GOALS
(
	[SVC_CDE] [VARCHAR](2) NULL,
	[GOAL_YR] [INT] NULL,
	[SERVICE_LINE] [VARCHAR](150) NULL,
	[UNIT] [VARCHAR](150) NULL,
	[DOMAIN] [VARCHAR](150) NULL,
	[GOAL] [DECIMAL](4, 3) NULL,
	[Load_Dtm] [SMALLDATETIME] NULL
)

SELECT DISTINCT
	  unittemp.SURVEY_ID
	 ,unittemp.sk_Fact_Pt_Acct
	 ,unittemp.RECDATE
	 ,unittemp.DISDATE
	 ,unittemp.Phys_Name
	 ,unittemp.Phys_Dept
	 ,unittemp.Phys_Div
	 ,dept.sk_Dim_Clrt_DEPt
	 ,loc_master.EPIC_DEPARTMENT_ID
	 ,loc_master.SERVICE_LINE_ID
	 ,CASE WHEN loc_master.service_line IS NULL OR loc_master.service_line = 'Unknown' THEN 'Other'
		   ELSE loc_master.service_line
	  END AS SERVICE_LINE
	 ,MDM.SUB_SERVICE_LINE
	 ,CASE WHEN RespUnit.UNIT IS NULL THEN 'Other' ELSE RespUnit.UNIT END AS UNIT
	 ,CASE WHEN loc_master.epic_department_name IS NULL OR loc_master.epic_department_name = 'Unknown' THEN 'Other' ELSE loc_master.epic_department_name + ' [' + CAST(loc_master.epic_department_id AS VARCHAR(250)) + ']' END AS CLINIC
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
	,phys.DisplayName AS Phys_Name
	,phys.DEPT AS Phys_Dept
	,phys.Division AS Phys_Div
	,resp.sk_Dim_Clrt_DEPt AS resp_sk_Dim_Clrt_DEPt
	,CAST(Resp.VALUE AS NVARCHAR(500)) AS VALUE -- prevents Tableau from erroring out on import data source
	,CASE WHEN Resp.VALUE IS NOT NULL THEN 1 ELSE 0 END AS VAL_COUNT
	,extd.DOMAIN
	,CASE WHEN resp.sk_Dim_PG_Question = '2130' THEN 'Quietness' WHEN Resp.sk_Dim_PG_Question = '2129' THEN 'Cleanliness' ELSE DOMAIN END AS Domain_Goals
	,CASE WHEN Resp.sk_Dim_PG_Question = '2151' THEN -- Rate Hospital 0-10
		CASE WHEN Resp.VALUE IN ('10-Best possible','9') THEN 'Very Good'
			WHEN Resp.VALUE IN ('7','8') THEN 'Good'
			WHEN Resp.VALUE IN ('5','6') THEN 'Average'
			WHEN Resp.VALUE IN ('3','4') THEN 'Poor'
			WHEN Resp.VALUE IN ('0-Worst possible','1','2') THEN 'Very Poor'
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
		CASE WHEN resp.sk_Dim_PG_Question = '2151' AND resp.VALUE IN ('10-Best possible','9') THEN 1 -- Rate Hospital 0-10
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
		CASE WHEN resp.sk_Dim_PG_Question = '2151' THEN '10-Best possible, 9' -- Rate Hospital 0-10
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
) AS unittemp
	LEFT OUTER JOIN
	(	
		SELECT DISTINCT
		SURVEY_ID
		,CASE VALUE
			WHEN '7CENTRAL (Closed)' THEN '7CENTRAL'
			WHEN '7N ACUTE' THEN '7NOR'
			WHEN '7N PICU' THEN 'PIC N'
			WHEN '7W ACUTE' THEN '7WEST'
			WHEN 'PICU (Closed)' THEN 'PIC N'
			ELSE CAST(VALUE AS NVARCHAR(500)) END AS UNIT
		FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses WHERE sk_Dim_PG_Question = '2384' -- (UNITS in CASE don't have a corresponding match in Balanced Scorecard Mapping, OBS handled separately)
	) AS RespUnit
	    ON unittemp.SURVEY_ID = RespUnit.SURVEY_ID
	LEFT OUTER JOIN
	(	
		SELECT DISTINCT
				 [Epic DEPARTMENT_ID]
				 ,PressGaney_Name
		         FROM  DS_HSDW_Prod.Rptg.Balanced_ScoreCard_Mapping
	) AS bscm
		ON RespUnit.UNIT = bscm.PressGaney_name
    LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt bscm_dept
	    ON bscm_dept.DEPARTMENT_ID =
		CASE RespUnit.UNIT
		   WHEN '8TMP' THEN 10243067
		   WHEN 'PIMU' THEN 10243108
		   ELSE CAST(bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
		END
    LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dept
	    ON CASE WHEN (((unittemp.resp_sk_Dim_Clrt_DEPt IS NOT NULL) AND (unittemp.resp_sk_Dim_Clrt_DEPt = 0)) AND bscm_dept.sk_Dim_Clrt_DEPt IS NOT NULL) THEN bscm_dept.sk_Dim_Clrt_DEPt
		        ELSE unittemp.resp_sk_Dim_Clrt_DEPt
		   END = dept.sk_Dim_Clrt_DEPt
    LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc AS loc_master
	    ON dept.DEPARTMENT_ID = loc_master.EPIC_DEPARTMENT_ID
    LEFT OUTER JOIN
	    (SELECT
		     EPIC_DEPARTMENT_ID
		    ,MAX(Sub_Service_Line) AS SUB_SERVICE_LINE -- in case more than 1
	     FROM DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master
	     WHERE SUB_SERVICE_LINE <> 'Unknown'
	     GROUP BY EPIC_DEPARTMENT_ID
	    ) MDM -- MDM_epicsvc view doesn't include sub service line
	    ON loc_master.epic_department_id = MDM.[EPIC_DEPARTMENT_ID]

INSERT INTO #GOALS
(
    SVC_CDE,
    GOAL_YR,
    SERVICE_LINE,
    UNIT,
    DOMAIN,
    GOAL,
    Load_Dtm
)
SELECT DISTINCT
    Svc_Cde AS SVC_CDE
  , CAST(2018 AS INT) AS GOAL_YR
  , CAST(SERVICE_LINE AS VARCHAR(150)) AS SERVICE_LINE
  , CAST(UNIT AS VARCHAR(150)) AS UNIT
  , CAST(DOMAIN AS VARCHAR(150)) AS DOMAIN
  , CAST(0.750 AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM #surveys_ch_ip_sl
WHERE DOMAIN IS NOT NULL
UNION all
SELECT DISTINCT
    Svc_Cde AS SVC_CDE
  , CAST(2018 AS INT) AS GOAL_YR
  , CAST(SERVICE_LINE AS VARCHAR(150)) AS SERVICE_LINE
  , CAST('All Units' AS VARCHAR(150)) AS UNIT
  , CAST(DOMAIN AS VARCHAR(150)) AS DOMAIN
  , CAST(0.750 AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM #surveys_ch_ip_sl
WHERE DOMAIN IS NOT NULL
UNION all
SELECT DISTINCT
    Svc_Cde AS SVC_CDE
  , CAST(2018 AS INT) AS GOAL_YR
  , CAST('All Service Lines' AS VARCHAR(150)) AS SERVICE_LINE
  , CAST('All Units' AS VARCHAR(150)) AS UNIT
  , CAST(DOMAIN AS VARCHAR(150)) AS DOMAIN
  , CAST(0.750 AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM #surveys_ch_ip_sl
WHERE DOMAIN IS NOT NULL

------------------------------------------------------------------------------------------

--- JOIN TO DIM_DATE

 SELECT
	--'Child HCAHPS' AS Event_Type
	'CHCAHPS' AS Event_Type
	,#surveys_ch_ip_sl.SURVEY_ID
	,#surveys_ch_ip_sl.sk_Fact_Pt_Acct
	,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
	,rec.day_date AS Event_Date
	,dis.day_date AS Event_Date_Disch
	,#surveys_ch_ip_sl.sk_Dim_PG_Question
	,#surveys_ch_ip_sl.VARNAME
	,#surveys_ch_ip_sl.QUESTION_TEXT_ALIAS
	,#surveys_ch_ip_sl.EPIC_DEPARTMENT_ID
	,#surveys_ch_ip_sl.SERVICE_LINE_ID
	,#surveys_ch_ip_sl.SERVICE_LINE
	,#surveys_ch_ip_sl.SUB_SERVICE_LINE
	,#surveys_ch_ip_sl.UNIT
	,#surveys_ch_ip_sl.CLINIC
	,#surveys_ch_ip_sl.DOMAIN
	,#surveys_ch_ip_sl.Domain_Goals
	,#surveys_ch_ip_sl.RECDATE AS Recvd_Date
	,#surveys_ch_ip_sl.DISDATE AS Discharge_Date
	,#surveys_ch_ip_sl.MRN_int AS Patient_ID
	,#surveys_ch_ip_sl.Pat_Name
	,#surveys_ch_ip_sl.Pat_Sex
	,#surveys_ch_ip_sl.Pat_DOB
	,#surveys_ch_ip_sl.Pat_Age
	,#surveys_ch_ip_sl.Pat_Age_Survey_Recvd
	,#surveys_ch_ip_sl.Pat_Age_Survey_Answer
	,CASE WHEN #surveys_ch_ip_sl.Pat_Age_Survey_Answer < 18 THEN 1 ELSE 0 END AS Peds
	,#surveys_ch_ip_sl.NPINumber
	,#surveys_ch_ip_sl.Phys_Name
	,#surveys_ch_ip_sl.Phys_Dept
	,#surveys_ch_ip_sl.Phys_Div
	,goals.GOAL
	,#surveys_ch_ip_sl.VALUE
	,#surveys_ch_ip_sl.Value_Resp_Grp
	,#surveys_ch_ip_sl.TOP_BOX
	,#surveys_ch_ip_sl.TOP_BOX_RESPONSE
	,#surveys_ch_ip_sl.VAL_COUNT
	,rec.quarter_name
	,rec.month_short_name
INTO #surveys_ch_ip2_sl
FROM
	(SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate) rec
LEFT OUTER JOIN #surveys_ch_ip_sl
    ON rec.day_date = #surveys_ch_ip_sl.RECDATE
FULL OUTER JOIN
	(SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate) dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
    ON dis.day_date = #surveys_ch_ip_sl.DISDATE
LEFT OUTER JOIN
	(SELECT * FROM #GOALS WHERE UNIT = 'All Units') goals -- THIS IS SERVICE LINE LEVEL, USE THE SERVICE-LINE SPECIFIC GOAL, DENOTED BY UNIT "ALL UNITS" (ALL UNITS W/I SERVICE LINE GET THE GOAL)
    ON #surveys_ch_ip_sl.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ch_ip_sl.Domain_Goals = goals.DOMAIN
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
		,#surveys_ch_ip_sl.SURVEY_ID
		,#surveys_ch_ip_sl.sk_Fact_Pt_Acct
		,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
		,rec.day_date AS Event_Date
		,dis.day_date AS Event_Date_Disch
		,#surveys_ch_ip_sl.sk_Dim_PG_Question
		,#surveys_ch_ip_sl.VARNAME
		,#surveys_ch_ip_sl.QUESTION_TEXT_ALIAS
	    ,#surveys_ch_ip_sl.EPIC_DEPARTMENT_ID
	    ,#surveys_ch_ip_sl.SERVICE_LINE_ID
		,#surveys_ch_ip_sl.SERVICE_LINE
		--,CASE WHEN #surveys_ch_ip_sl.SURVEY_ID IS NULL THEN NULL
		--	ELSE 'All Service Lines' END AS SERVICE_LINE
		,#surveys_ch_ip_sl.SUB_SERVICE_LINE
		--,#surveys_ch_ip_sl.UNIT
		,CASE WHEN #surveys_ch_ip_sl.SURVEY_ID IS NULL THEN NULL
			ELSE 'All Units' END AS UNIT
		--,#surveys_ch_ip_sl.CLINIC
        ,CAST(NULL AS VARCHAR(254)) AS CLINIC
		,#surveys_ch_ip_sl.Domain
		,#surveys_ch_ip_sl.Domain_Goals
		,#surveys_ch_ip_sl.RECDATE AS Recvd_Date
		,#surveys_ch_ip_sl.DISDATE AS Discharge_Date
		,#surveys_ch_ip_sl.MRN_int AS Patient_ID
		,#surveys_ch_ip_sl.Pat_Name
		,#surveys_ch_ip_sl.Pat_Sex
		,#surveys_ch_ip_sl.Pat_DOB
		,#surveys_ch_ip_sl.Pat_Age
		,#surveys_ch_ip_sl.Pat_Age_Survey_Recvd
		,#surveys_ch_ip_sl.Pat_Age_Survey_Answer
		,CASE WHEN #surveys_ch_ip_sl.Pat_Age_Survey_Answer < 18 THEN 1 ELSE 0 END AS Peds
		,#surveys_ch_ip_sl.NPINumber
		,#surveys_ch_ip_sl.Phys_Name
		,#surveys_ch_ip_sl.Phys_Dept
		,#surveys_ch_ip_sl.Phys_Div
		,goals.GOAL
		,#surveys_ch_ip_sl.VALUE
		,#surveys_ch_ip_sl.Value_Resp_Grp
		,#surveys_ch_ip_sl.TOP_BOX
		,#surveys_ch_ip_sl.TOP_BOX_RESPONSE
		,#surveys_ch_ip_sl.VAL_COUNT
		,rec.quarter_name
		,rec.month_short_name
	 FROM
		 (SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate) rec
	 LEFT OUTER JOIN #surveys_ch_ip_sl
	     ON rec.day_date = #surveys_ch_ip_sl.RECDATE
	 FULL OUTER JOIN
		 (SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate) dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
	     ON dis.day_date = #surveys_ch_ip_sl.DISDATE
	 LEFT OUTER JOIN
		 (SELECT * FROM #GOALS WHERE SERVICE_LINE = 'All Units') goals  -- CHANGE BASED ON GOALS FROM BUSH - CREATE NEW CHCAHPS_Goals
		 ON #surveys_ch_ip_sl.Domain_Goals = goals.DOMAIN
		 WHERE (dis.day_date >= @startdate AND DIS.day_date <= @enddate) AND (rec.day_date >= @startdate AND rec.day_date <= @enddate) -- THIS IS ALL SERVICE LINES TOGETHER, USE "ALL SERVICE LINES" GOALS TO APPLY SAME GOAL DOMAIN GOAL TO ALL SERVICE LINES
)

----------------------------------------------------------------------------------------------------------------------
-- RESULTS

 SELECT  [Event_Type]
   ,[SURVEY_ID]
   ,CASE WHEN UNIT IN
	(	SELECT UNIT
		FROM
		(
			SELECT UNIT, COUNT(DISTINCT(SERVICE_LINE)) AS SVC_LINES FROM #surveys_ch_ip3_sl 
			WHERE UNIT <> 'All Units' 
			GROUP BY UNIT
			HAVING COUNT(DISTINCT(SERVICE_LINE)) > 1
		) a
	) THEN UNIT + ' - ' + SERVICE_LINE ELSE UNIT END AS UNIT -- adds svc line to units that appear in multiple service lines
	,CASE WHEN Sub_Service_Line IS NULL THEN [Service_Line]
	    ELSE
		CASE WHEN SERVICE_LINE <> 'All Service Lines' THEN SERVICE_LINE + ' - ' + Sub_Service_Line
			ELSE SERVICE_LINE
			END
		END AS SERVICE_LINE
   ,SUB_SERVICE_LINE
   ,EPIC_DEPARTMENT_ID
   ,service_line_id
   ,[sk_Fact_Pt_Acct]
   ,[Rpt_Prd]
   ,[Event_Date]
   ,[Event_Date_Disch]
   ,[sk_Dim_PG_Question]
   ,[VARNAME]
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
   ,[CLINIC]
   ,[VALUE]
   ,[Value_Resp_Grp]
   ,[TOP_BOX]
   ,[TOP_BOX_RESPONSE]
   ,[VAL_COUNT]
   ,[quarter_name]
   ,[month_short_name]
  FROM #surveys_ch_ip3_sl

GO


