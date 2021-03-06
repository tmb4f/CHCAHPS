USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

--ALTER PROCEDURE [Rptg].[uspSrc_Dash_PatExp_CHCAHPS_Unit]
--AS
/**********************************************************************************************************************
WHAT: Stored procedure for Patient Experience Dashboard - Child HCAHPS (Inpatient) - By Unit
WHO : Tom Burgan
WHEN: 4/17/2018
WHY : Produce surveys results for patient experience dashboard
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
MODS: 	4/17/2018 - Created procedure
        7/26/2018 - Change name of Service_Line column
		10/4/2018 - Format script similar to CGCAHPS
		11/5/2018 - Edit logic used to assign an Epic Department Id value to a survey; retain the CLINIC column as
		            the identifier for an inpatient unit; the UNIT column will contain the unit value assigned by PG
	   11/27/2018 - Use updated CHCAHPS_Goals table; add FY to Goals JOIN
	   11/29/2018 - Set Domain_Goals values for Global Rating Item domains (Rate Hospital, Recommend)
	    12/4/2018 - Extract only surveys with a service type of 'PC'; set SERVICE_LINE abd SUB_SERVICE_LINE values to
		            fixed "Womens and Childrens" and "Children", respectively; for units without specified goals,
					use the "All Units" goal values
	   12/10/2018 - Include responses "10-Best hosp" and "0-Worst hosp" for Rate Hospital question
	   12/11/2018 - Use new CHCAHPS_Goals table
	   12/14/2018 - Correct issue with assignment of '7N ACUTE' surveys to an Epic Department Id
	   12/18/2018 - Include surveys where service type value is NULL
	   02/13/2019 - Add logic for assigning goals to survey locations
	   03/06/2019 - Remove responses for question "Before your child left the hospital, did a provider tell you that your
	                child should take any new medicine that he or she had not been taking when this hospital stay began?;
					Set to null goals equal to 0.0
	   05/20/2019 - Include QUESTION_TEXT in extract
	   09/26/2019 - TMB - changed logic that assigns targets to domains
	   11/19/2019 - TMB - Remove restrictions for discharge date range
***********************************************************************************************************************/

SET NOCOUNT ON

---------------------------------------------------
---Default date range is the first day of the current month 2 years ago until the last day of the current month
DECLARE @currdate AS DATE;
DECLARE @startdate AS DATE;
DECLARE @enddate AS DATE;

SET @startdate = '7/1/2018'
SET @enddate = '6/30/2020'

    SET @currdate=CAST(GETDATE() AS DATE);

    IF @startdate IS NULL
        AND @enddate IS NULL
        BEGIN
            SET @startdate = CAST(DATEADD(MONTH,DATEDIFF(MONTH,0,DATEADD(MONTH,-24,GETDATE())),0) AS DATE); 
            SET @enddate= CAST(EOMONTH(GETDATE()) AS DATE); 
        END; 

----------------------------------------------------
DECLARE @locstartdate SMALLDATETIME,
        @locenddate SMALLDATETIME

SET @locstartdate = @startdate
SET @locenddate   = @enddate

IF OBJECT_ID('tempdb..#chcahps_resp ') IS NOT NULL
DROP TABLE #chcahps_resp

IF OBJECT_ID('tempdb..#chcahps_resp_dep ') IS NOT NULL
DROP TABLE #chcahps_resp_dep

IF OBJECT_ID('tempdb..#chcahps_resp_unit ') IS NOT NULL
DROP TABLE #chcahps_resp_unit

IF OBJECT_ID('tempdb..#chcahps_resp_epic_id ') IS NOT NULL
DROP TABLE #chcahps_resp_epic_id

IF OBJECT_ID('tempdb..#surveys_ch_ip_sl ') IS NOT NULL
DROP TABLE #surveys_ch_ip_sl

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
WHERE unittemp.RECDATE >= '7/1/2019 00:00 AM'
	ORDER BY REC_FY, SERVICE_LINE, EPIC_DEPARTMENT_ID, goal_EPIC_DEPARTMENT_ID, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID

  -- Create indexes for temp table #surveys_ch_ip_sl
  CREATE NONCLUSTERED INDEX IX_surveyschipsl ON #surveys_ch_ip_sl (REC_FY, SERVICE_LINE, EPIC_DEPARTMENT_ID, goal_EPIC_DEPARTMENT_ID, Domain_Goals, sk_Dim_PG_Question, SURVEY_ID)

------------------------------------------------------------------------------------------

SELECT *
FROM DS_HSDW_App.Rptg.PX_Goal_Setting
WHERE Service = 'CHCAHPS'
--AND GOAL_YR = 2020
--AND ((UNIT IS NULL) OR (UNIT IS NOT NULL AND UNIT <> 'All PEDS Units'))
--AND DOMAIN IS NOT NULL
--AND GOAL IS NOT NULL
ORDER BY UNIT
	   , Epic_Department_Id
	   , DOMAIN

------------------------------------------------------------------------------------------
/*	   
DECLARE @domain_translation TABLE
(
    Goals_Domain VARCHAR(100)
  , DOMAIN VARCHAR(100)
);
INSERT INTO @domain_translation
(
    Goals_Domain,
    DOMAIN
)
VALUES
(   'Child Care in ER', -- Goals_Domain - varchar(100): Value docmented in Goals file
    'Child''s Care in ER'  -- DOMAIN - varchar(100)
),
(   'Child''s care in ER',
    'Child''s Care in ER'
),
(	'Comm Child''s Doctor',
	'Comm You Child''s Doctor'
),
(	'Comm Child''s Med',
	'Communication Child''s Med'
),
(	'Comm Child''s Nurse',
	'Comm You Child''s Nurse'
),
(	'Doctor Comm Child',
	'Doctors Communicate Child'
),
(	'Doctors Comm Child',
	'Doctors Communicate Child'
),
(	'Help Child Feel Comfortable',
	'Help Child Feel Comfortab'
),
(	'Nurse Comm Child',
	'Nurses Communicate Child'
),
(	'Nurses Comm Child',
	'Nurses Communicate Child'
),
(	'Overall Rating',
	'Rate Hospital'
),
(	'Prepare Child Leave Hospital',
	'Prepare Child Leave Hosp'
),
(	'Prevent Mistakes RPT Conc',
	'Prevent Mistakes Rpt Conc'
),
(	'Resp to Call Bell',
	'Response to Call Button'
);
	   
DECLARE @CHCAHPS_PX_Goal_Setting TABLE
(
    SVC_CDE VARCHAR(2)
  , GOAL_YR INTEGER
  , SERVICE_LINE VARCHAR(150)
  , Epic_Department_Id VARCHAR(8)
  , Epic_Department_Name VARCHAR(30)
  , UNIT VARCHAR(150)
  , DOMAIN VARCHAR(150)
  , Domain_Goals VARCHAR(150)
  , GOAL DECIMAL(4,3)
);
INSERT INTO @CHCAHPS_PX_Goal_Setting
SELECT
	 'PD' AS [SVC_CDE]
	,Goal.[GOAL_YR]
	,'Womens and Childrens' AS SERVICE_LINE
	,Goal.Epic_Department_Id
	,Goal.Epic_Department_Name
    ,CASE
	   WHEN Goal.[UNIT] = 'All PEDS Units' THEN 'All Units'
	   ELSE Goal.UNIT
	 END AS UNIT
    ,Goal.[DOMAIN]
    ,COALESCE([@domain_translation].DOMAIN, Goal.DOMAIN) AS Domain_Goals
    ,Goal.[GOAL]
FROM [DS_HSDW_App].[Rptg].[PX_Goal_Setting] Goal
LEFT OUTER JOIN @domain_translation
    ON [@domain_translation].Goals_Domain = Goal.DOMAIN
WHERE Goal.Service = 'CHCAHPS'
AND (Goal.UNIT = 'All PEDS Units'
OR Goal.UNIT IS NULL);

SELECT *
FROM @CHCAHPS_PX_Goal_Setting
--WHERE GOAL_YR = 2020
--AND ((UNIT IS NULL) OR (UNIT IS NOT NULL AND UNIT <> 'All Units'))
--AND DOMAIN IS NOT NULL
--AND GOAL IS NOT NULL
--WHERE UNIT = 'All Units' AND GOAL_YR = 2020
--AND DOMAIN IS NOT NULL
WHERE UNIT = 'All Units' AND GOAL_YR = 2020
AND DOMAIN IS NOT NULL
ORDER BY UNIT
       , Domain_Goals

------------------------------------------------------------------------------------------

SELECT DISTINCT
    --SERVICE_LINE,
    --UNIT,
    DOMAIN
FROM DS_HSDW_App.Rptg.PX_Goal_Setting
WHERE Service = 'CHCAHPS'
--AND SERVICE_LINE = '(Woman''s and) Childern''s'
--AND UNIT = 'All  Units'
--ORDER BY SERVICE_LINE
--       , UNIT
--	   , DOMAIN
ORDER BY DOMAIN

SELECT DISTINCT
	resp.Domain_Goals
FROM #surveys_ch_ip_sl resp
WHERE resp.Domain_Goals IS NOT NULL
ORDER BY resp.Domain_Goals

------------------------------------------------------------------------------------------

SELECT DISTINCT
    SERVICE_LINE
FROM DS_HSDW_App.Rptg.PX_Goal_Setting
WHERE Service = 'CHCAHPS'
ORDER BY SERVICE_LINE

SELECT DISTINCT
	resp.SERVICE_LINE
FROM #surveys_ch_ip_sl resp
ORDER BY resp.SERVICE_LINE

------------------------------------------------------------------------------------------

SELECT DISTINCT
    SERVICE_LINE
  , UNIT
FROM DS_HSDW_App.Rptg.PX_Goal_Setting
WHERE Service = 'CHCAHPS'
ORDER BY UNIT

------------------------------------------------------------------------------------------

SELECT DISTINCT
    Epic_Department_Id
FROM DS_HSDW_App.Rptg.PX_Goal_Setting
WHERE Service = 'CHCAHPS'
ORDER BY Epic_Department_Id

SELECT DISTINCT
	resp.EPIC_DEPARTMENT_ID
  , resp.goal_EPIC_DEPARTMENT_ID
FROM #surveys_ch_ip_sl resp
ORDER BY resp.goal_EPIC_DEPARTMENT_ID
*/
GO


