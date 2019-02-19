USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

-- =====================================================================================
-- Create procedure uspSrc_Dash_PatExp_Child_HCAHPS_Units
-- =====================================================================================
IF EXISTS (SELECT 1
    FROM INFORMATION_SCHEMA.ROUTINES 
    WHERE ROUTINE_SCHEMA='Rptg'
    AND ROUTINE_TYPE='PROCEDURE'
    AND ROUTINE_NAME='uspSrc_Dash_PatExp_Child_HCAHPS_Units')
   DROP PROCEDURE Rptg.[uspSrc_Dash_PatExp_Child_HCAHPS_Units]
GO

CREATE PROCEDURE [Rptg].[uspSrc_Dash_PatExp_Child_HCAHPS_Units]
AS
/**********************************************************************************************************************
WHAT: Stored procedure for Patient Experience Dashboard - Child HCAHPS (Inpatient) - By Unit
WHO : Tom Burgan
WHEN: 6/28/2018
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
                  
      OUTPUTS: CH-HCAHPS Survey Results
   
------------------------------------------------------------------------------------------------------------------------
MODS: 	6/28/2018 - Created procedure	
***********************************************************************************************************************/

SET NOCOUNT ON

CREATE TABLE #DOMAIN
(
	sk_Dim_PG_Question	INT,
	DOMAIN				VARCHAR(40),
	QUESTION_TEXT		VARCHAR(800),
	QUESTION_TEXT_ALIAS	VARCHAR(800)
)

INSERT INTO #DOMAIN (sk_Dim_PG_Question, DOMAIN, QUESTION_TEXT, QUESTION_TEXT_ALIAS)
	VALUES (2096,'Nurses Communicate Child','During this hospital stay, how often did your child''s nurses encourage your child to ask questions?','Nurses encourage child ask question')
	      ,(2098,'Doctors Communicate Child','During this hospital stay, how often did your child''s doctors listen carefully to your child?','Doctors listen carefully your child')
		  ,(2100,'Doctors Communicate Child','During this hospital stay, how often did your child''s doctors explain things in a way that was easy for your child to understand?','Doctors exp in way child understand')
		  ,(2102,'Doctors Communicate Child','During this hospital stay, how often did your child''s doctors encourage your child to ask questions?','Doctor encourage child ask question')
		  ,(2103,'Comm You Child''s Nurse','During this hospital stay, how often did your child''s nurses listen carefully to you?','Nurses listen carefully to you')
		  ,(2104,'Comm You Child''s Nurse','During this hospital stay, how often did your child''s nurses explain things to you in a way that was easy to understand?','Nurses expl in way you understand')
		  ,(2105,'Comm You Child''s Nurse','During this hospital stay, how often did your child''s nurses treat you with courtesy and respect?','Nurses treat with courtesy/respect')
		  ,(2106,'Comm You Child''s Doctor','During this hospital stay, how often did your child''s doctors listen carefully to you?','Doctors listen carefully to you')
		  ,(2107,'Comm You Child''s Doctor','During this hospital stay, how often did your child''s doctors explain things to you in a way that was easy to understand?','Doctors expl in way you understand')
		  ,(2108,'Comm You Child''s Doctor','During this hospital stay, how often did your child''s doctors treat you with courtesy and respect?','Doctors treat with courtesy/respect')
		  ,(2110,'Privacy Talk MD/RN','A provider in the hospital can be a doctor, nurse, nurse practitioner, or physician assistant. During this hospital stay, how often were you given as much privacy as you wanted when discussing your child''s care with providers?','Given privacy discuss child''s care')
		  ,(2111,'Help Child Feel Comfortab','Things that a family might know best about a child include how the child usually acts, what makes the child comfortable, and how to calm the child''s fears. During this hospital stay, did providers ask you about these types of things?','Provider ask thing family know best')
		  ,(2112,'Help Child Feel Comfortab','During this hospital stay, how often did providers talk with and act toward your child in a way that was right for your child''s age?','Providers act appropriate child age')
		  ,(2113,'Informed Child''s Care','During this hospital stay, how often did providers keep you informed about what was being done for your child?','Keep you informed done for child')
		  ,(2116,'Informed Child''s Care','How often did providers give you as much information as you wanted about the results of these tests?','Give info wanted about test results')
		  ,(2119,'Response to Call Button','After pressing the call button, how often was help given as soon as you or your child wanted it?','Press call button help given soon')
		  ,(2122,'Prevent Mistakes Rpt Conc','Before giving your child any medicine, how often did providers or other hospital staff check your child''s wristband or confirm his or her identity in some other way?','Before meds check child''s identity')
		  ,(2125,'Prevent Mistakes Rpt Conc','During this hospital stay, did providers or other hospital staff tell you how to report if you had any concerns about mistakes in your child''s health care?','Staff tell you how report concerns')
		  ,(2128,'Attention to Child''s Pain','During this hospital stay, did providers or other hospital staff ask about your child''s pain as often as your child needed?','Staff ask about child''s pain often')
		  ,(2129,'Hospital Environment','During this hospital stay, how often were your child''s room and bathroom kept clean?','Cleanliness of hospital environment')
		  ,(2130,'Hospital Environment','During this hospital stay, how often was the area around your child''s room quiet at night?','Quietness of hospital environment')
		  ,(2131,'Help Child Feel Comfortab','Hospitals can have things like toys, books, mobiles, and games for children from newborns to teenagers. During this hospital stay, did the hospital have things available for your child that were right for your child''s age?','Things available right child''s age')
		  ,(2132,'Prepare Child Leave Hosp','As a reminder, a provider in the hospital can be a doctor, nurse, nurse practitioner, or physician assistant. Before your child left the hospital, did a provider ask you if you had any concerns about whether your child was ready to leave?','Ask you concerns child ready leave')
		  ,(2133,'Prepare Child Leave Hosp','Before your child left the hospital, did a provider talk with you as much as you wanted about how to care for your child''s health after leaving the hospital?','Provider talk care child leave hosp')
		  ,(2134,'Communication Child''s Med','Before your child left the hospital, did a provider tell you that your child should take any new medicine that he or she had not been taking when this hospital stay began?','Provider tell child take new meds')
		  ,(2136,'Communication Child''s Med','Before your child left the hospital, did a provider or hospital pharmacist explain in a way that was easy to understand how your child should take these new medicines after leaving the hospital?','Provider explain how take new meds')
		  ,(2153,'Child''s care in ER','While your child was in this hospital''s Emergency Room, were you kept informed about what was being done for your child?','In ER kept informed about what done')
		  ,(2140,'Communication Child''s Med','Before your child left the hospital, did a provider or hospital pharmacist explain in a way that was easy to understand about possible side effects of these new medicines?','Staff describe medicine side effect')
		  ,(2141,'Prepare Child Leave Hosp','Before your child left the hospital, did a provider explain in a way that was easy to understand when your child could return to his or her regular activities?','Provider explain child regular acts')
		  ,(2142,'Prepare Child Leave Hosp','Before your child left the hospital, did a provider explain in a way that was easy to understand what symptoms or health problems to look out for after leaving the hospital?','Explain symptoms/prob to look for')
		  ,(2143,'Prepare Child Leave Hosp','Before your child left the hospital, did you get information in writing about what symptoms or health problems to look out for after your child left the hospital?','Symptoms/prob look for in writing')
		  ,(2146,'Involve Teens in Care','During this hospital stay, how often did providers involve your child in discussions about his or her health care?','Involve child discuss health care')
		  ,(2148,'Involve Teens in Care','Before your child left the hospital, did a provider ask your child if he or she had any concerns about whether he or she was ready to leave?','Ask child had concerns ready leave')
		  ,(2150,'Involve Teens in Care','Before your child left the hospital, did a provider talk with your child about how to take care of his or her health after leaving the hospital?','Talk child take care after leaving')
		  ,(2151,'Global Rating Item','Using any number from 0 to 10, where 0 is the worst hospital possible and 10 is the best hospital possible, what number would you use to rate this hospital during your child''s stay?','Rate hospital 0-10')
		  ,(2152,'Global Rating Item','Would you recommend this hospital to your friends and family?','Recommend the hospital')
		  ,(2167,'Communication Child''s Med','During the first day of this hospital stay, were you asked to list or review all of the prescription medicines your child was taking at home?','First day review prescription meds')
		  ,(2180,'Communication Child''s Med','During the first day of this hospital stay, were you asked to list or review all of the vitamins, herbal medicines, and over-the-counter medicines your child was taking at home?','First day list/review vitamins/meds')
		  ,(2184,'Nurses Communicate Child','During this hospital stay, how often did your child''s nurses listen carefully to your child?','Nurses listen carefully your child')
		  ,(2186,'Nurses Communicate Child','During this hospital stay, how often did your child''s nurses explain things in a way that was easy for your child to understand?','Nurses exp in way child understand')
		  ,(2204,'Pediatric ICU/CCU','Degree to which the critical care nurses kept you informed about tests, treatments, and equipment','PCCU nurses'' tests/trtmnts info')
		  ,(2205,'Pediatric ICU/CCU','Degree to which the PCCU/PICU nurses involved you in your child''s care','Care involvement w/PCCU nurses')
		  ,(2208,'Pediatric ICU/CCU','Friendliness/courtesy of the PCCU/PICU nurses','PCCU nurse''s friendliness')
		  ,(2212,'Personal Issues','Safety and security of the hospital','Safety/security of the hospital')
		  ,(2213,'Personal Issues','Response to concerns/complaints made during your child''s stay','Response to concerns/complaints')
		  ,(2214,'Personal Issues','Degree to which staff washed their hands before examining/caring for your child','Staff washed hands before examining')
		  ,(2215,'Personal Issues','Response to concerns/complaints made during your child''s stay','Response to concerns/complaints')
		  ,(2217,'Personal Issues','Extent to which our staff checked your child''s ID bracelet before every treatment, procedure, or giving your child medications','Staff check child ID before trtment')
		  ,(2326,'Meals','Temperature of the food (e.g. cold foods cold, hot foods hot)','Temperature of food')
		  ,(2327,'Meals','Temperature of the food (e.g. cold foods cold, hot foods hot)','Temperature of food')
		  ,(2330,'Meals','Courtesy of the person who served your child''s food','Courtesy of food service staff')
		  ,(2345,'Overall Assessment','How well staff worked together to care for your child','Staff worked together');

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
	 Resp.SURVEY_ID
	,Resp.sk_Fact_Pt_Acct
	,Resp.RECDATE
	,Resp.DISDATE
	,phys.DisplayName AS Phys_Name
	,phys.DEPT AS Phys_Dept
	,phys.Division AS Phys_Div
	,CASE WHEN RespUnit.UNIT = 'obs' THEN 'Womens and Childrens'
		  WHEN bcsm.Service_Line IS NULL THEN 'Other'
		  ELSE bcsm.Service_Line
		  END AS Service_Line -- obs appears as both 8nor and 8cob
	,CASE WHEN RespUnit.UNIT IS NULL THEN 'Other' ELSE RespUnit.UNIT END AS UNIT
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
	INTO #surveys_ch_ip_unit
	FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses AS Resp
	INNER JOIN DS_HSDW_Prod.dbo.Dim_PG_Question AS qstn
		ON Resp.sk_Dim_PG_Question = qstn.sk_Dim_PG_Question
	LEFT OUTER JOIN DS_HSDW_Prod.dbo.Fact_Pt_Acct AS fpa -- LEFT OUTER, including -1 or survey counts won't match press ganey
		ON Resp.sk_Fact_Pt_Acct = fpa.sk_Fact_Pt_Acct
	LEFT OUTER JOIN
	(	
		SELECT DISTINCT
		SURVEY_ID
		,CASE VALUE
			WHEN 'ADMT (Closed)' THEN 'Other'
			WHEN 'ER' THEN 'Other'
			WHEN 'ADMT' THEN 'Other'
			WHEN 'MSIC' THEN 'Other'
			WHEN 'MSICU' THEN 'Other'
			WHEN 'NNICU' THEN 'NNIC'
			ELSE CAST(VALUE AS NVARCHAR(500)) END AS UNIT
		FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses WHERE sk_Dim_PG_Question = '2384' -- (UNITS in CASE don't have a corresponding match in Balanced Scorecard Mapping, OBS handled separately)
	) AS RespUnit
	ON Resp.SURVEY_ID = RespUnit.SURVEY_ID
	LEFT OUTER JOIN DS_HSDW_Prod.dbo.Dim_Pt AS pat
		ON Resp.sk_Dim_Pt = pat.sk_Dim_Pt
	LEFT OUTER JOIN DS_HSDW_Prod.dbo.Dim_Physcn AS phys
		ON Resp.sk_Dim_Physcn = phys.sk_Dim_Physcn
	LEFT OUTER JOIN
	(
		SELECT SURVEY_ID, CAST(MAX(VALUE) AS NVARCHAR(500)) AS AGE FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses
		WHERE sk_Fact_Pt_Acct > 0 AND sk_Dim_PG_Question = '2092' -- Age question for Inpatient
		GROUP BY SURVEY_ID
	) Resp_Age
		ON Resp.SURVEY_ID = Resp_Age.SURVEY_ID 
	LEFT OUTER JOIN
	(
		--SELECT DISTINCT sk_Dim_PG_Question, DOMAIN, QUESTION_TEXT_ALIAS FROM DS_HSDW_App.Rptg.PG_Extnd_Attr
		SELECT DISTINCT sk_Dim_PG_Question, DOMAIN, QUESTION_TEXT, QUESTION_TEXT_ALIAS FROM #DOMAIN
	) extd
		ON RESP.sk_Dim_PG_Question = extd.sk_Dim_PG_Question
	LEFT OUTER JOIN DS_HSDW_Prod.Rptg.Balanced_ScoreCard_Mapping bcsm
		ON RespUnit.UNIT = bcsm.PressGaney_name
	WHERE  Resp.Svc_Cde='PD' AND qstn.sk_Dim_PG_Question IN
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
  , CAST(Service_Line AS VARCHAR(150)) AS SERVICE_LINE
  , CAST(UNIT AS VARCHAR(150)) AS UNIT
  , CAST(DOMAIN AS VARCHAR(150)) AS DOMAIN
  , CAST(0.750 AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM #surveys_ch_ip_unit
WHERE DOMAIN IS NOT NULL
UNION all
SELECT DISTINCT
    Svc_Cde AS SVC_CDE
  , CAST(2018 AS INT) AS GOAL_YR
  , CAST(Service_Line AS VARCHAR(150)) AS SERVICE_LINE
  , CAST('All Units' AS VARCHAR(150)) AS UNIT
  , CAST(DOMAIN AS VARCHAR(150)) AS DOMAIN
  , CAST(0.750 AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM #surveys_ch_ip_unit
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
FROM #surveys_ch_ip_unit
WHERE DOMAIN IS NOT NULL

------------------------------------------------------------------------------------------
--- JOIN TO DIM_DATE

 SELECT
	'Child HCAHPS' AS Event_Type
	,SURVEY_ID
	,sk_Fact_Pt_Acct
	,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
	,rec.day_date AS Event_Date
	,dis.day_date AS Event_Date_Disch
	,sk_Dim_PG_Question
	,VARNAME
	,QUESTION_TEXT_ALIAS
	,#surveys_ch_ip_unit.Domain
	,Domain_Goals
	,RECDATE AS Recvd_Date
	,DISDATE AS Discharge_Date
	,MRN_int AS Patient_ID
	,Pat_Name
	,Pat_Sex
	,Pat_DOB
	,Pat_Age
	,Pat_Age_Survey_Recvd
	,Pat_Age_Survey_Answer
	,CASE WHEN Pat_Age_Survey_Answer < 18 THEN 1 ELSE 0 END AS Peds
	,NPINumber
	,Phys_Name
	,Phys_Dept
	,Phys_Div
	,GOAL
	,CASE WHEN #surveys_ch_ip_unit.UNIT = 'SHRTSTAY' THEN 'SSU' ELSE #surveys_ch_ip_unit.UNIT END AS UNIT -- CAN'T MAP SHRTSTAY TO GOALS AND SVC LINE WITHOUT A CHANGE TO BCSM TABLE
	,#surveys_ch_ip_unit.Service_Line
	,VALUE
	,Value_Resp_Grp
	,TOP_BOX
	,TOP_BOX_RESPONSE
	,VAL_COUNT
	,rec.quarter_name
	,rec.month_short_name
INTO #surveys_ch_ip2_unit
FROM DS_HSDW_Prod.dbo.Dim_Date rec
LEFT OUTER JOIN #surveys_ch_ip_unit
ON rec.day_date = #surveys_ch_ip_unit.RECDATE
FULL OUTER JOIN DS_HSDW_Prod.dbo.Dim_Date dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
ON dis.day_date = #surveys_ch_ip_unit.DISDATE
--LEFT OUTER JOIN DS_HSDW_App.Rptg.HCAHPS_Goals
LEFT OUTER JOIN #GOALS goals
ON #surveys_ch_ip_unit.UNIT = goals.UNIT AND #surveys_ch_ip_unit.Domain_Goals = goals.DOMAIN
ORDER BY Event_Date, SURVEY_ID, sk_Dim_PG_Question

-------------------------------------------------------------------------------------------------------------------------------------
-- SELF UNION TO ADD AN "ALL UNITS" UNIT

SELECT * INTO #surveys_ch_ip3_unit
FROM #surveys_ch_ip2_unit
UNION ALL

(

	 SELECT
		'Child HCAHPS' AS Event_Type
		,SURVEY_ID
		,sk_Fact_Pt_Acct
		,LEFT(DATENAME(MM, rec.day_date), 3) + ' ' + CAST(DAY(rec.day_date) AS VARCHAR(2)) AS Rpt_Prd
		,rec.day_date AS Event_Date
		,dis.day_date AS Event_Date_Disch
		,sk_Dim_PG_Question
		,VARNAME
		,QUESTION_TEXT_ALIAS
		,#surveys_ch_ip_unit.Domain
		,Domain_Goals
		,RECDATE AS Recvd_Date
		,DISDATE AS Discharge_Date
		,MRN_int AS Patient_ID
		,Pat_Name
		,Pat_Sex
		,Pat_DOB
		,Pat_Age
		,Pat_Age_Survey_Recvd
		,Pat_Age_Survey_Answer
		,CASE WHEN Pat_Age_Survey_Answer < 18 THEN 1 ELSE 0 END AS Peds
		,NPINumber
		,Phys_Name
		,Phys_Dept
		,Phys_Div
		,GOAL
		,CASE WHEN SURVEY_ID IS NULL THEN NULL ELSE 'All Units' END AS UNIT
		,#surveys_ch_ip_unit.Service_Line
		,VALUE
		,Value_Resp_Grp
		,TOP_BOX
		,TOP_BOX_RESPONSE
		,VAL_COUNT
		,rec.quarter_name
		,rec.month_short_name
	FROM DS_HSDW_Prod.dbo.Dim_Date rec
	LEFT OUTER JOIN #surveys_ch_ip_unit
	ON rec.day_date = #surveys_ch_ip_unit.RECDATE
	FULL OUTER JOIN DS_HSDW_Prod.dbo.Dim_Date dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
	ON dis.day_date = #surveys_ch_ip_unit.DISDATE
	--LEFT OUTER JOIN
	--	(SELECT * FROM DS_HSDW_App.Rptg.HCAHPS_Goals WHERE UNIT = 'All Units' AND SERVICE_LINE = 'All Service Lines') goals -- THIS IS ALL SERVICE LINES TOGETHER, USE "ALL SERVICE LINES" GOALS TO APPLY SAME GOAL DOMAIN GOAL TO ALL SERVICE LINES
	--ON #surveys_ch_ip_unit.Domain_Goals = goals.DOMAIN
	LEFT OUTER JOIN
		(SELECT * FROM #GOALS WHERE UNIT = 'All Units' AND SERVICE_LINE = 'All Service Lines') goals -- THIS IS ALL SERVICE LINES TOGETHER, USE "ALL SERVICE LINES" GOALS TO APPLY SAME GOAL DOMAIN GOAL TO ALL SERVICE LINES
	ON #surveys_ch_ip_unit.Domain_Goals = goals.DOMAIN
)

----------------------------------------------------------------------------------------------------------------------
-- RESULTS
 SELECT  [Event_Type]
   ,[SURVEY_ID]
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
   ,[Service_Line]
   ,[VALUE]
   ,[Value_Resp_Grp]
   ,[TOP_BOX]
   ,[TOP_BOX_RESPONSE]
   ,[VAL_COUNT]
   ,[quarter_name]
   ,[month_short_name]
  FROM #surveys_ch_ip3_unit

GO
