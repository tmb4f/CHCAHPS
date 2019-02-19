USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

-- =====================================================================================
-- Create procedure uspSrc_Dash_PatExp_CHCAHPS_Unit
-- =====================================================================================
IF EXISTS (SELECT 1
    FROM INFORMATION_SCHEMA.ROUTINES 
    WHERE ROUTINE_SCHEMA='Rptg'
    AND ROUTINE_TYPE='PROCEDURE'
    AND ROUTINE_NAME='uspSrc_Dash_PatExp_CHCAHPS_Unit')
   DROP PROCEDURE Rptg.[uspSrc_Dash_PatExp_CHCAHPS_Unit]
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
		11/5/2018 - Edit logic used to assign an Epic Department Id value to a survey; retain the CLINIC column as
		            the identifier for an inpatient unit; the UNIT column will contain the unit value assigned by PG
	   11/27/2018 - Use updated CHCAHPS_Goals table; add FY to Goals JOIN
	   11/29/2018 - Set Domain_Goals values for Global Rating Item domains (Rate Hospital, Recommend)
	    12/4/2018 - Extract only surveys with a service type of 'PC'; set SERVICE_LINE abd SUB_SERVICE_LINE values to
		            fixed "Womens and Childrens" and "Children", respectively; for units without specified goals,
					use the "All Units" goal values
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
INTO #chcahps_resp
FROM DS_HSDW_Prod.Rptg.vwFact_PressGaney_Responses resp
LEFT OUTER JOIN (
	SELECT survey_id, value
	FROM DS_HSDW_Stage.PressGaney.PG_Responses_xmlrip
	WHERE VARNAME = 'ITSERVTY'
) rip
ON resp.SURVEY_ID = rip.SURVEY_ID
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
	WHERE PG_DESG = 'PC') resp
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
  CREATE CLUSTERED INDEX IX_chcahps_resp_unit ON #chcahps_resp_unit ([UNIT])

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
    ,resp.UNIT
    ,CASE resp.UNIT
	   WHEN '7CENTRAL (Closed)' THEN '7CENTRAL'
	   WHEN '7N ACUTE' THEN '7NOR'
	   WHEN '7N PICU' THEN 'PIC N'
	   WHEN '7W ACUTE' THEN '7WEST'
	   WHEN 'PICU (Closed)' THEN 'PIC N'
	   ELSE resp.UNIT
	 END AS der_UNIT
INTO #chcahps_resp_unit_der
FROM #chcahps_resp_unit resp
ORDER BY der_UNIT

  -- Create index for temp table #chcahps_resp_unit_der
  CREATE CLUSTERED INDEX IX_chcahps_resp_unit_der ON #chcahps_resp_unit_der ([der_UNIT])

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
    ,resp.UNIT
    ,resp.der_UNIT
	,bscm.[Epic DEPARTMENT_ID]
	,dep.DEPARTMENT_ID
	,dep.sk_Dim_Clrt_DEPt AS dep_sk_Dim_Clrt_DEPt
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
		      ELSE CAST(bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
		    END
ORDER BY resp.SURVEY_ID

SELECT DISTINCT
	  unittemp.SURVEY_ID
	 ,unittemp.sk_Fact_Pt_Acct
	 ,unittemp.RECDATE
	 ,unittemp.DISDATE
	 ,unittemp.FY
	 ,unittemp.Phys_Name
	 ,unittemp.Phys_Dept
	 ,unittemp.Phys_Div
	 ,RespUnit.sk_Dim_Clrt_DEPt
	 ,dept.DEPARTMENT_ID AS EPIC_DEPARTMENT_ID
	 ,11 AS SERVICE_LINE_ID
	 ,'Womens and Childrens' AS SERVICE_LINE
	 ,'Children' AS SUB_SERVICE_LINE
	 ,unittemp.sk_Dim_Clrt_DEPt AS fact_sk_Dim_Clrt_DEPt
	 ,RespUnit.UNIT AS UNIT
	 ,CASE WHEN loc_master.epic_department_name IS NOT NULL AND loc_master.epic_department_name <> 'Unknown' THEN loc_master.epic_department_name + ' [' + CAST(loc_master.epic_department_id AS VARCHAR(250)) + ']'
	       WHEN dept.Clrt_DEPt_Nme IS NOT NULL THEN dept.Clrt_DEPt_Nme + ' [' + CAST(dept.DEPARTMENT_ID AS VARCHAR(250)) + ']'
	       ELSE 'Unknown' + ' [' + CAST(dept.DEPARTMENT_ID AS VARCHAR(250)) + ']'
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
	WHERE Resp.PG_DESG = 'PC'
) AS unittemp
	LEFT OUTER JOIN
	(
		SELECT DISTINCT
			SURVEY_ID
		   ,CASE
		      WHEN sk_Dim_Clrt_DEPt IS NOT NULL AND sk_Dim_Clrt_DEPt > 0 THEN sk_Dim_Clrt_DEPt
			  WHEN der_UNIT IS NULL THEN enc_sk_Dim_Clrt_DEPt
			  WHEN der_UNIT <> 'RN (Closed)' THEN dep_sk_Dim_Clrt_DEPt
			  ELSE enc_sk_Dim_Clrt_DEPt
			END AS sk_Dim_Clrt_DEPt
		   ,UNIT
		FROM #chcahps_resp_epic_id
	) AS RespUnit
	    ON unittemp.SURVEY_ID = RespUnit.SURVEY_ID
    LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dept
	    ON dept.sk_Dim_Clrt_DEPt = RespUnit.sk_Dim_Clrt_DEPt
    LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc AS loc_master
	    ON dept.DEPARTMENT_ID = loc_master.EPIC_DEPARTMENT_ID

------------------------------------------------------------------------------------------

--- JOIN TO DIM_DATE

 SELECT
	'CHCAHPS' AS Event_Type
	,surveys_ch_ip_sl.SURVEY_ID
	,surveys_ch_ip_sl.sk_Fact_Pt_Acct
	,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
	,rec.day_date AS Event_Date
	,dis.day_date AS Event_Date_Disch
	,surveys_ch_ip_sl.sk_Dim_PG_Question
	,surveys_ch_ip_sl.VARNAME
	,surveys_ch_ip_sl.QUESTION_TEXT_ALIAS
	,surveys_ch_ip_sl.EPIC_DEPARTMENT_ID
	,surveys_ch_ip_sl.SERVICE_LINE_ID
	,surveys_ch_ip_sl.SERVICE_LINE
	,surveys_ch_ip_sl.SUB_SERVICE_LINE
	,surveys_ch_ip_sl.UNIT
	,surveys_ch_ip_sl.CLINIC
	,surveys_ch_ip_sl.DOMAIN
	,surveys_ch_ip_sl.Domain_Goals
	,surveys_ch_ip_sl.RECDATE AS Recvd_Date
	,surveys_ch_ip_sl.DISDATE AS Discharge_Date
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
	,rec.month_short_name
INTO #surveys_ch_ip2_sl
FROM
	(SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate) rec
LEFT OUTER JOIN
	(SELECT #surveys_ch_ip_sl.*, goals.GOAL
	 FROM #surveys_ch_ip_sl
     INNER JOIN
	     (SELECT DISTINCT
		      SERVICE_LINE
	         ,UNIT
	      FROM DS_HSDW_App.Rptg.CHCAHPS_Goals
          WHERE SERVICE_LINE = 'Womens and Childrens') units -- Identify surveys with units that have goals documented by Patient Experience
	 ON #surveys_ch_ip_sl.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ch_ip_sl.CLINIC = units.UNIT
     LEFT OUTER JOIN
	     (SELECT
		      GOAL_YR
	         ,SERVICE_LINE
	         ,UNIT
	         ,DOMAIN
	         ,GOAL
	      FROM DS_HSDW_App.Rptg.CHCAHPS_Goals
          WHERE SERVICE_LINE = 'Womens and Childrens') goals
    ON #surveys_ch_ip_sl.FY = goals.GOAL_YR AND #surveys_ch_ip_sl.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ch_ip_sl.CLINIC = goals.UNIT AND #surveys_ch_ip_sl.Domain_Goals = goals.DOMAIN
	 UNION ALL
	 SELECT #surveys_ch_ip_sl.*, goals.GOAL
	 FROM #surveys_ch_ip_sl
     LEFT OUTER JOIN
	     (SELECT DISTINCT
		      SERVICE_LINE
	         ,UNIT
	      FROM DS_HSDW_App.Rptg.CHCAHPS_Goals
          WHERE SERVICE_LINE = 'Womens and Childrens') units -- Identify surveys with units that do not have goals documented by Patient Experience
	 ON #surveys_ch_ip_sl.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ch_ip_sl.CLINIC = units.UNIT
     LEFT OUTER JOIN
	     (SELECT
		      GOAL_YR
	         ,SERVICE_LINE
	         ,UNIT
	         ,DOMAIN
	         ,GOAL
	      FROM DS_HSDW_App.Rptg.CHCAHPS_Goals
          WHERE SERVICE_LINE = 'Womens and Childrens' AND UNIT = 'All Units') goals
    ON #surveys_ch_ip_sl.FY = goals.GOAL_YR AND #surveys_ch_ip_sl.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ch_ip_sl.Domain_Goals = goals.DOMAIN
	WHERE units.UNIT IS NULL
	) surveys_ch_ip_sl
    ON rec.day_date = surveys_ch_ip_sl.RECDATE
FULL OUTER JOIN
	(SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate) dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
    ON dis.day_date = surveys_ch_ip_sl.DISDATE
ORDER BY Event_Date, surveys_ch_ip_sl.SURVEY_ID, surveys_ch_ip_sl.sk_Dim_PG_Question

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
		,#surveys_ch_ip_sl.SUB_SERVICE_LINE
		,#surveys_ch_ip_sl.UNIT
		,CASE WHEN #surveys_ch_ip_sl.SURVEY_ID IS NULL THEN NULL
			ELSE 'All Units' END AS CLINIC
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
		 (SELECT *
		  FROM DS_HSDW_App.Rptg.CHCAHPS_Goals
		  WHERE SERVICE_LINE = 'Womens and Childrens' AND UNIT = 'All Units'
		 ) goals  -- CHANGE BASED ON GOALS FROM BUSH - CREATE NEW CHCAHPS_Goals
		 ON #surveys_ch_ip_sl.FY = goals.GOAL_YR AND #surveys_ch_ip_sl.Domain_Goals = goals.DOMAIN
	 WHERE (dis.day_date >= @startdate AND DIS.day_date <= @enddate) AND (rec.day_date >= @startdate AND rec.day_date <= @enddate) -- THIS IS ALL SERVICE LINES TOGETHER, USE "ALL SERVICE LINES" GOALS TO APPLY SAME GOAL DOMAIN GOAL TO ALL SERVICE LINES
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
   ,[UNIT]
   ,[VALUE]
   ,[Value_Resp_Grp]
   ,[TOP_BOX]
   ,[TOP_BOX_RESPONSE]
   ,[VAL_COUNT]
   ,[quarter_name]
   ,[month_short_name]
  FROM #surveys_ch_ip3_sl

GO


