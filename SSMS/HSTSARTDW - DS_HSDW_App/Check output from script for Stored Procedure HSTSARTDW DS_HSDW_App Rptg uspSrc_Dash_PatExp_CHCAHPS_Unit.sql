USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

-- =====================================================================================
-- Create procedure uspSrc_Dash_PatExp_CHCAHPS_Unit
-- =====================================================================================
--IF EXISTS (SELECT 1
--    FROM INFORMATION_SCHEMA.ROUTINES 
--    WHERE ROUTINE_SCHEMA='Rptg'
--    AND ROUTINE_TYPE='PROCEDURE'
--    AND ROUTINE_NAME='uspSrc_Dash_PatExp_CHCAHPS_Unit')
--   DROP PROCEDURE Rptg.[uspSrc_Dash_PatExp_CHCAHPS_Unit]
--GO
--ALTER PROCEDURE [Rptg].[uspSrc_Dash_PatExp_CHCAHPS_Unit]
--AS
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
	   12/10/2018 - Include responses "10-Best hosp" and "0-Worst hosp" for Rate Hospital question
	   12/11/2018 - Use new CHCAHPS_Goals table
	   12/14/2018 - Correct issue with assignment of '7N ACUTE' surveys to an Epic Department Id
	   12/18/2018 - Include surveys where service type value is NULL
	   02/13/2019 - Add logic for assigning goals to survey locations
	   03/06/2019 - Remove responses for question "Before your child left the hospital, did a provider tell you that your
	                child should take any new medicine that he or she had not been taking when this hospital stay began?;
					Set to null goals equal to 0.0
***********************************************************************************************************************/

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
/*
WHERE sk_Dim_PG_Question IN
    ( -- sk_Dim_PG_Question, VARNAME, QUESTION_TEXT, DOMAIN, QUESTION_TEXT_ALIAS
      '2092', -- AGE,Patient's Age,NULL,NULL
      '2096', -- CH_10CL,"During this hospital stay, how often did your child's nurses encourage your child to ask questions?",Nurses Communicate Child,Nurses encourage child ask question
      '2098', -- CH_11CL,"During this hospital stay, how often did your child's doctors listen carefully to your child?",Doctors Communicate Child,Doctors listen carefully your child
      '2100', -- CH_12CL,"During this hospital stay, how often did your child's doctors explain things in a way that was easy for your child to understand?",Doctors Communicate Child,Doctors exp in way child understand
      '2102', -- CH_13CL,"During this hospital stay, how often did your child's doctors encourage your child to ask questions?",Doctors Communicate Child,Doctor encourage child ask question
      '2103', -- CH_14,"During this hospital stay, how often did your child's nurses listen carefully to you?",Comm You Child's Nurse,Nurses listen carefully to you
      '2104', -- CH_15,"During this hospital stay, how often did your child's nurses explain things to you in a way that was easy to understand?",Comm You Child's Nurse,Nurses expl in way you understand
      '2105', -- CH_16,"During this hospital stay, how often did your child's nurses treat you with courtesy and respect?",Comm You Child's Nurse,Nurses treat with courtesy/respect
      '2106', -- CH_17,"During this hospital stay, how often did your child's doctors listen carefully to you?",Comm You Child's Doctor,Doctors listen carefully to you
      '2107', -- CH_18,"During this hospital stay, how often did your child's doctors explain things to you in a way that was easy to understand?",Comm You Child's Doctor,Doctors expl in way you understand
      '2108', -- CH_19,"During this hospital stay, how often did your child's doctors treat you with courtesy and respect?",Comm You Child's Doctor,Doctors treat with courtesy/respect
      '2110', -- CH_20,"A provider in the hospital can be a doctor, nurse, nurse practitioner, or physician assistant. During this hospital stay, how often were you given as much privacy as you wanted when discussing your child's care with providers?",Privacy Talk MD/RN,Given privacy discuss child's care
      '2111', -- CH_21,"Things that a family might know best about a child include how the child usually acts, what makes the child comfortable, and how to calm the child's fears. During this hospital stay, did providers ask you about these types of things?",Help Child Feel Comfortab,Provider ask thing family know best
      '2112', -- CH_22,"During this hospital stay, how often did providers talk with and act toward your child in a way that was right for your child's age?",Help Child Feel Comfortab,Providers act appropriate child age
      '2113', -- CH_23,"During this hospital stay, how often did providers keep you informed about what was being done for your child?",Informed Child's Care,Keep you informed done for child
      '2116', -- CH_25CL,How often did providers give you as much information as you wanted about the results of these tests?,Informed Child's Care,Give info wanted about test results
      '2119', -- CH_27CL,"After pressing the call button, how often was help given as soon as you or your child wanted it?",Response to Call Button,Press call button help given soon
      '2122', -- CH_29CL,"Before giving your child any medicine, how often did providers or other hospital staff check your child's wristband or confirm his or her identity in some other way?",Prevent Mistakes Rpt Conc,Before meds check child's identity
      '2125', -- CH_30,"During this hospital stay, did providers or other hospital staff tell you how to report if you had any concerns about mistakes in your child's health care?",Prevent Mistakes Rpt Conc,Staff tell you how report concerns
      '2128', -- CH_32CL,"During this hospital stay, did providers or other hospital staff ask about your child's pain as often as your child needed?",Attention to Child's Pain,Staff ask about child's pain often
      '2129', -- CH_33,"During this hospital stay, how often were your child's room and bathroom kept clean?",Hospital Environment,Cleanliness of hospital environment
      '2130', -- CH_34,"During this hospital stay, how often was the area around your child's room quiet at night?",Hospital Environment,Quietness of hospital environment
      '2131', -- CH_35,"Hospitals can have things like toys, books, mobiles, and games for children from newborns to teenagers. During this hospital stay, did the hospital have things available for your child that were right for your child's age?",Help Child Feel Comfortab,Things available right child's age
      '2132', -- CH_36,"As a reminder, a provider in the hospital can be a doctor, nurse, nurse practitioner, or physician assistant. Before your child left the hospital, did a provider ask you if you had any concerns about whether your child was ready to leave?",Prepare Child Leave Hosp,Ask you concerns child ready leave
      '2133', -- CH_37,"Before your child left the hospital, did a provider talk with you as much as you wanted about how to care for your child's health after leaving the hospital?",Prepare Child Leave Hosp,Provider talk care child leave hosp
      --'2134', -- CH_38,"Before your child left the hospital, did a provider tell you that your child should take any new medicine that he or she had not been taking when this hospital stay began?",Communication Child's Med,Provider tell child take new meds -- 3/6/2019 TMB Exclude responses for questiom "Provider tell child take new meds"
      '2136', -- CH_39CL,"Before your child left the hospital, did a provider or hospital pharmacist explain in a way that was easy to understand how your child should take these new medicines after leaving the hospital?",Communication Child's Med,Provider explain how take new meds
      '2140', -- CH_40CL,"Before your child left the hospital, did a provider or hospital pharmacist explain in a way that was easy to understand about possible side effects of these new medicines?",Communication Child's Med,Staff describe medicine side effect
      '2141', -- CH_41,"Before your child left the hospital, did a provider explain in a way that was easy to understand when your child could return to his or her regular activities?",Prepare Child Leave Hosp,Provider explain child regular acts
      '2142', -- CH_42,"Before your child left the hospital, did a provider explain in a way that was easy to understand what symptoms or health problems to look out for after leaving the hospital?",Prepare Child Leave Hosp,Explain symptoms/prob to look for
      '2143', -- CH_43,"Before your child left the hospital, did you get information in writing about what symptoms or health problems to look out for after your child left the hospital?",Prepare Child Leave Hosp,Symptoms/prob look for in writing
      '2146', -- CH_45CL,"During this hospital stay, how often did providers involve your child in discussions about his or her health care?",Involve Teens in Care,Involve child discuss health care
      '2148', -- CH_46CL,"Before your child left the hospital, did a provider ask your child if he or she had any concerns about whether he or she was ready to leave?",Involve Teens in Care,Ask child had concerns ready leave
      '2150', -- CH_47CL,"Before your child left the hospital, did a provider talk with your child about how to take care of his or her health after leaving the hospital?",Involve Teens in Care,Talk child take care after leaving
      '2151', -- CH_48,"Using any number from 0 to 10, where 0 is the worst hospital possible and 10 is the best hospital possible, what number would you use to rate this hospital during your child's stay?",Global Rating Item,Rate hospital 0-10
      '2152', -- CH_49,Would you recommend this hospital to your friends and family?,Global Rating Item,Recommend the hospital
      '2153', -- CH_4CL,"While your child was in this hospital's Emergency Room, were you kept informed about what was being done for your child?",Child's care in ER,In ER kept informed about what done
      '2167', -- CH_5CL,"During the first day of this hospital stay, were you asked to list or review all of the prescription medicines your child was taking at home?",Communication Child's Med,First day review prescription meds
      '2180', -- CH_6CL,"During the first day of this hospital stay, were you asked to list or review all of the vitamins, herbal medicines, and over-the-counter medicines your child was taking at home?",Communication Child's Med,First day list/review vitamins/meds
      '2184', -- CH_8CL,"During this hospital stay, how often did your child's nurses listen carefully to your child?",Nurses Communicate Child,Nurses listen carefully your child
      '2186', -- CH_9CL,"During this hospital stay, how often did your child's nurses explain things in a way that was easy for your child to understand?",Nurses Communicate Child,Nurses exp in way child understand
      '2204', -- G10,"Degree to which the critical care nurses kept you informed about tests, treatments, and equipment",Pediatric ICU/CCU,PCCU nurses' tests/trtmnts info
      '2205', -- G33,Degree to which the PCCU/PICU nurses involved you in your child's care,Pediatric ICU/CCU,Care involvement w/PCCU nurses
      '2208', -- G9,Friendliness/courtesy of the PCCU/PICU nurses,Pediatric ICU/CCU,PCCU nurse's friendliness
      '2212', -- I35,Safety and security of the hospital,Personal Issues,Safety/security of the hospital
      '2213', -- I4,Response to concerns/complaints made during your child's stay,Personal Issues,Response to concerns/complaints
      '2214', -- I49,Degree to which staff washed their hands before examining/caring for your child,Personal Issues,Staff washed hands before examining
      '2215', -- I4PR,Response to concerns/complaints made during your child's stay,Personal Issues,Response to concerns/complaints
      '2217', -- I50,"Extent to which our staff checked your child's ID bracelet before every treatment, procedure, or giving your child medications",Personal Issues,Staff check child ID before trtment
      '2326', -- M2,"Temperature of the food (e.g. cold foods cold, hot foods hot)",Meals,Temperature of food
      '2327', -- M2PR,"Temperature of the food (e.g. cold foods cold, hot foods hot)",Meals,Temperature of food
      '2330', -- M8,Courtesy of the person who served your child's food,Meals,Courtesy of food service staff
      '2345', -- O2,How well staff worked together to care for your child,Overall Assessment,Staff worked together
      '2384'  -- UNIT,Unit,NULL,NULL
    )
*/
/*
WHERE sk_Dim_PG_Question IN
    ( -- sk_Dim_PG_Question, VARNAME, QUESTION_TEXT, DOMAIN, QUESTION_TEXT_ALIAS
      '2092', -- AGE,Patient's Age,NULL,NULL
      '2111', -- CH_21,"Things that a family might know best about a child include how the child usually acts, what makes the child comfortable, and how to calm the child's fears. During this hospital stay, did providers ask you about these types of things?",Help Child Feel Comfortab,Provider ask thing family know best
      '2112', -- CH_22,"During this hospital stay, how often did providers talk with and act toward your child in a way that was right for your child's age?",Help Child Feel Comfortab,Providers act appropriate child age
      '2131', -- CH_35,"Hospitals can have things like toys, books, mobiles, and games for children from newborns to teenagers. During this hospital stay, did the hospital have things available for your child that were right for your child's age?",Help Child Feel Comfortab,Things available right child's age
      '2384'  -- UNIT,Unit,NULL,NULL
    )
*/
WHERE sk_Dim_PG_Question IN
    ( -- sk_Dim_PG_Question, VARNAME, QUESTION_TEXT, DOMAIN, QUESTION_TEXT_ALIAS
      '2092', -- AGE,Patient's Age,NULL,NULL
      '2151', -- CH_48,"Using any number from 0 to 10, where 0 is the worst hospital possible and 10 is the best hospital possible, what number would you use to rate this hospital during your child's stay?",Global Rating Item,Rate hospital 0-10
      '2152', -- CH_49,Would you recommend this hospital to your friends and family?,Global Rating Item,Recommend the hospital
      '2384'  -- UNIT,Unit,NULL,NULL
    )
AND DATEDIFF(dd,resp.DISDATE,CAST(GETDATE() AS DATE)) <= 366
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
    ,CASE
	   WHEN resp.UNIT = '8NOR' THEN 419 -- 2/12/2019 Goals for unit 8NOR not defined, default to 8TMP goals
	   WHEN resp.UNIT IS NULL AND resp.sk_Dim_Clrt_DEPt = 395 THEN 1002 -- 2/13/2019 Goals for UVHE PEDIATRIC ICU surveys without unit documented
	   ELSE resp.sk_Dim_Clrt_DEPt
	 END AS goal_sk_Dim_Clrt_DEPt
    ,resp.UNIT
    ,CASE resp.UNIT
	   WHEN '7CENTRAL (Closed)' THEN '7CENTRAL'
	   WHEN '7N PICU' THEN 'PIC N'
	   WHEN '7W ACUTE' THEN '7WEST'
	   WHEN 'PICU (Closed)' THEN 'PIC N'
	   ELSE resp.UNIT
	 END AS der_UNIT
    ,CASE resp.UNIT
	   WHEN '7CENTRAL (Closed)' THEN '7CENTRAL'
	   WHEN '7N PICU' THEN 'PIC N'
	   WHEN '7W ACUTE' THEN '7WEST'
	   WHEN 'PICU (Closed)' THEN 'PIC N'
	   WHEN '8NOR' THEN '8TMP' -- 2/12/2019 Goals for unit 8NOR not defined, default to 8TMP goals
	   ELSE resp.UNIT
	 END AS goal_UNIT
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
	,resp.goal_sk_Dim_Clrt_DEPt
	,resp.sk_Dim_Physcn
	,resp.RESP_CAT
	,resp.enc_sk_Dim_Clrt_DEPt
    ,resp.UNIT
    ,resp.der_UNIT
	,resp.goal_UNIT
	,bscm.[Epic DEPARTMENT_ID]
	,goal_bscm.[Epic DEPARTMENT_ID] AS [goal Epic DEPARTMENT_ID]
	,dep.DEPARTMENT_ID
	,dep.sk_Dim_Clrt_DEPt AS dep_sk_Dim_Clrt_DEPt
	,goal_dep.DEPARTMENT_ID AS goal_DEPARTMENT_ID
	,goal_dep.sk_Dim_Clrt_DEPt AS goal_dep_sk_Dim_Clrt_DEPt
INTO #chcahps_resp_epic_id
FROM #chcahps_resp_unit_der resp
LEFT OUTER JOIN (SELECT DISTINCT
					PressGaney_Name
				   ,[Epic DEPARTMENT_ID]
                 FROM DS_HSDW_Prod.Rptg.vwBalanced_ScoreCard_Mapping
				 WHERE PressGaney_Name IS NOT NULL AND LEN(PressGaney_Name) > 0) bscm
    ON bscm.PressGaney_Name = resp.der_UNIT
LEFT OUTER JOIN (SELECT DISTINCT
					PressGaney_Name
				   ,[Epic DEPARTMENT_ID]
                 FROM DS_HSDW_Prod.Rptg.vwBalanced_ScoreCard_Mapping
				 WHERE PressGaney_Name IS NOT NULL AND LEN(PressGaney_Name) > 0) goal_bscm
    ON bscm.PressGaney_Name = resp.goal_UNIT
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dep
    ON dep.DEPARTMENT_ID =
		    CASE resp.UNIT
		      WHEN '8TMP' THEN 10243067
		      WHEN 'PIMU' THEN 10243108
			  WHEN '7N ACUTE' THEN 10243103
		      ELSE CAST(bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
		    END
LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt goal_dep
    ON goal_dep.DEPARTMENT_ID =
		    CASE resp.goal_UNIT
		      WHEN '8TMP' THEN 10243067
		      WHEN 'PIMU' THEN 10243108
			  WHEN '7N ACUTE' THEN 10243103
		      ELSE CAST(goal_bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
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
	 ,goal_RespUnit.sk_Dim_Clrt_DEPt AS goal_sk_Dim_Clrt_DEPt
	 ,dept.DEPARTMENT_ID AS EPIC_DEPARTMENT_ID
	 ,goal_dept.DEPARTMENT_ID AS goal_EPIC_DEPARTMENT_ID
	 ,11 AS SERVICE_LINE_ID
	 ,'Womens and Childrens' AS SERVICE_LINE
	 ,'Children' AS SUB_SERVICE_LINE
	 ,unittemp.sk_Dim_Clrt_DEPt AS fact_sk_Dim_Clrt_DEPt
	 ,RespUnit.UNIT AS UNIT
	 ,goal_RespUnit.UNIT AS goal_UNIT
	 ,CASE WHEN loc_master.epic_department_name IS NOT NULL AND loc_master.epic_department_name <> 'Unknown' THEN loc_master.epic_department_name + ' [' + CAST(loc_master.epic_department_id AS VARCHAR(250)) + ']'
	       WHEN dept.Clrt_DEPt_Nme IS NOT NULL THEN dept.Clrt_DEPt_Nme + ' [' + CAST(dept.DEPARTMENT_ID AS VARCHAR(250)) + ']'
	       ELSE 'Unknown' + ' [' + CAST(dept.DEPARTMENT_ID AS VARCHAR(250)) + ']'
      END AS CLINIC
	 ,CASE WHEN goal_loc_master.epic_department_name IS NOT NULL AND goal_loc_master.epic_department_name <> 'Unknown' THEN goal_loc_master.epic_department_name + ' [' + CAST(goal_loc_master.epic_department_id AS VARCHAR(250)) + ']'
	       WHEN goal_dept.Clrt_DEPt_Nme IS NOT NULL THEN goal_dept.Clrt_DEPt_Nme + ' [' + CAST(goal_dept.DEPARTMENT_ID AS VARCHAR(250)) + ']'
	       ELSE 'Unknown' + ' [' + CAST(goal_dept.DEPARTMENT_ID AS VARCHAR(250)) + ']'
      END AS goal_CLINIC
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
	LEFT OUTER JOIN
	(
		SELECT DISTINCT
			SURVEY_ID
		   ,CASE
		      WHEN goal_sk_Dim_Clrt_DEPt IS NOT NULL AND goal_sk_Dim_Clrt_DEPt > 0 THEN goal_sk_Dim_Clrt_DEPt
			  WHEN goal_UNIT IS NULL THEN enc_sk_Dim_Clrt_DEPt
			  WHEN goal_UNIT <> 'RN (Closed)' THEN dep_sk_Dim_Clrt_DEPt
			  ELSE enc_sk_Dim_Clrt_DEPt
			END AS sk_Dim_Clrt_DEPt
		   ,goal_UNIT AS UNIT
		FROM #chcahps_resp_epic_id
	) AS goal_RespUnit
	    ON unittemp.SURVEY_ID = goal_RespUnit.SURVEY_ID
    LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dept
	    ON dept.sk_Dim_Clrt_DEPt = RespUnit.sk_Dim_Clrt_DEPt
    LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt goal_dept
	    ON goal_dept.sk_Dim_Clrt_DEPt = goal_RespUnit.sk_Dim_Clrt_DEPt
    LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc AS loc_master
	    ON dept.DEPARTMENT_ID = loc_master.EPIC_DEPARTMENT_ID
    LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc AS goal_loc_master
	    ON goal_dept.DEPARTMENT_ID = goal_loc_master.EPIC_DEPARTMENT_ID

--WHERE dept.DEPARTMENT_ID = 10243043

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
--LEFT OUTER JOIN
INNER JOIN
	(SELECT #surveys_ch_ip_sl.*, goals.GOAL
	 FROM #surveys_ch_ip_sl
     INNER JOIN
	     (SELECT DISTINCT
		      SERVICE_LINE
	         ,UNIT
	      FROM DS_HSDW_App.Rptg.CHCAHPS_Goals
          WHERE SERVICE_LINE = 'Womens and Childrens') units -- Identify surveys with units that have goals documented by Patient Experience
	 ON #surveys_ch_ip_sl.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ch_ip_sl.goal_CLINIC = units.UNIT
     LEFT OUTER JOIN
	     (SELECT
		      GOAL_YR
	         ,SERVICE_LINE
	         ,UNIT
	         ,DOMAIN
	         ,CASE
	            WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
	            ELSE GOAL
	          END AS GOAL
	      FROM DS_HSDW_App.Rptg.CHCAHPS_Goals
          WHERE SERVICE_LINE = 'Womens and Childrens') goals
    ON #surveys_ch_ip_sl.FY = goals.GOAL_YR AND #surveys_ch_ip_sl.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ch_ip_sl.goal_CLINIC = goals.UNIT AND #surveys_ch_ip_sl.Domain_Goals = goals.DOMAIN
	 UNION ALL
	 SELECT #surveys_ch_ip_sl.*, goals.GOAL
	 FROM #surveys_ch_ip_sl
     LEFT OUTER JOIN
	     (SELECT DISTINCT
		      SERVICE_LINE
	         ,UNIT
	      FROM DS_HSDW_App.Rptg.CHCAHPS_Goals
          WHERE SERVICE_LINE = 'Womens and Childrens') units -- Identify surveys with units that do not have goals documented by Patient Experience
	 ON #surveys_ch_ip_sl.SERVICE_LINE = units.SERVICE_LINE AND #surveys_ch_ip_sl.goal_CLINIC = units.UNIT
     LEFT OUTER JOIN
	     (SELECT
		      GOAL_YR
	         ,SERVICE_LINE
	         ,UNIT
	         ,DOMAIN
	         ,CASE
	            WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
	            ELSE GOAL
	          END AS GOAL
	      FROM DS_HSDW_App.Rptg.CHCAHPS_Goals
          WHERE SERVICE_LINE = 'Womens and Childrens' AND UNIT = 'All Units') goals
    ON #surveys_ch_ip_sl.FY = goals.GOAL_YR AND #surveys_ch_ip_sl.SERVICE_LINE = goals.SERVICE_LINE AND #surveys_ch_ip_sl.Domain_Goals = goals.DOMAIN
	WHERE units.UNIT IS NULL
	) surveys_ch_ip_sl
    ON rec.day_date = surveys_ch_ip_sl.RECDATE
--FULL OUTER JOIN
INNER JOIN
	(SELECT * FROM DS_HSDW_Prod.dbo.Dim_Date WHERE day_date >= @startdate AND day_date <= @enddate) dis -- Need to report by both the discharge date on the survey as well as the received date of the survey
    ON dis.day_date = surveys_ch_ip_sl.DISDATE
ORDER BY Event_Date, surveys_ch_ip_sl.SURVEY_ID, surveys_ch_ip_sl.sk_Dim_PG_Question

-------------------------------------------------------------------------------------------------------------------------------------
-- SELF UNION TO ADD AN "All Units" UNIT

SELECT * INTO #surveys_ch_ip3_sl
FROM #surveys_ch_ip2_sl
/*
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
		 (SELECT GOAL_YR
		        ,DOMAIN
	            ,CASE
	               WHEN GOAL = 0.0 THEN CAST(NULL AS DECIMAL(4,3))
	               ELSE GOAL
	             END AS GOAL
		  FROM DS_HSDW_App.Rptg.CHCAHPS_Goals
		  WHERE SERVICE_LINE = 'Womens and Childrens' AND UNIT = 'All Units'
		 ) goals  -- CHANGE BASED ON GOALS FROM BUSH - CREATE NEW CHCAHPS_Goals
		 ON #surveys_ch_ip_sl.FY = goals.GOAL_YR AND #surveys_ch_ip_sl.Domain_Goals = goals.DOMAIN
	 WHERE (dis.day_date >= @startdate AND DIS.day_date <= @enddate) AND (rec.day_date >= @startdate AND rec.day_date <= @enddate) -- THIS IS ALL SERVICE LINES TOGETHER, USE "ALL SERVICE LINES" GOALS TO APPLY SAME GOAL DOMAIN GOAL TO ALL SERVICE LINES
)
*/
----------------------------------------------------------------------------------------------------------------------
-- RESULTS
/*
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
  INTO #CHCAHPS_Unit
  FROM #surveys_ch_ip3_sl

  SELECT *
  FROM #CHCAHPS_Unit
  ORDER BY Discharge_Date
 -- SELECT DISTINCT
	--#CHCAHPS_Unit.CLINIC
 -- , EPIC_DEPARTMENT_ID
 -- --, UNIT
 -- SELECT DISTINCT
	--#CHCAHPS_Unit.DOMAIN
 -- , sk_Dim_PG_Question
 -- , QUESTION_TEXT_ALIAS
 -- SELECT DISTINCT
	--DOMAIN
 -- , Domain_Goals
 -- , sk_Dim_PG_Question
 -- , QUESTION_TEXT_ALIAS
 */
 /*
  SELECT
    CLINIC
  --, sk_Dim_PG_Question
  --, DOMAIN
  --, Domain_Goals
  , QUESTION_TEXT_ALIAS
  --, TOP_BOX
  --, COUNT(*) AS TOP_BOX_COUNT
  , [VALUE]
  , COUNT(*) AS VALUE_COUNT
  FROM #CHCAHPS_Unit
  --WHERE #CHCAHPS_Unit.SURVEY_ID IS NOT NULL
  --WHERE #CHCAHPS_Unit.CLINIC IS NOT NULL AND #CHCAHPS_Unit.CLINIC <> 'All Units'
  --WHERE #CHCAHPS_Unit.DOMAIN IS NOT NULL
  WHERE Discharge_Date >= '7/1/2018 00:00 AM'
  --AND VARNAME = 'CH_48'
  --AND Domain_Goals = 'Rate Hospital'
  AND sk_Dim_PG_Question IN
	( -- 1-5 scale questions
		'2204', -- G10
		'2205', -- G33
		--'2208', -- G9
		--'2212', -- I35
		--'2213', -- I4
		--'2214', -- I49
		--'2215', -- I4PR
		--'2217', -- I50
		--'2326', -- M2
		--'2327', -- M2PR
		--'2330', -- M8
		'2345'  -- O2
	)
  AND CLINIC IN ('UVHE PICU 7NORTH [10243100]','UVHE PEDIATRIC ICU [10243043]')
  GROUP BY
    CLINIC
  --, sk_Dim_PG_Question
  --, DOMAIN
  --, Domain_Goals
  , QUESTION_TEXT_ALIAS
  --, TOP_BOX
  , [VALUE]
  --ORDER BY SERVICE_LINE
  --        ,CLINIC
		--  ,SURVEY_ID
		--  ,Event_Date
  --ORDER BY CLINIC
  --        ,SERVICE_LINE
		--  ,SURVEY_ID
		--  ,Event_Date
  --ORDER BY SURVEY_ID
		--  ,Event_Date
  --ORDER BY CLINIC
		--  ,SURVEY_ID
		--  ,Event_Date
  --ORDER BY Event_Date
  --        ,CLINIC
		--  ,SURVEY_ID
  --ORDER BY CLINIC
  --ORDER BY DOMAIN
  --       , sk_Dim_PG_Question
  ORDER BY
    CLINIC
  --, sk_Dim_PG_Question
  --, DOMAIN
  --, Domain_Goals
  , QUESTION_TEXT_ALIAS
  --, TOP_BOX
  , [VALUE]
*/

  --SELECT DISTINCT
  --  DOMAIN
  -- ,Domain_Goals
  -- ,TOP_BOX
  -- ,TOP_BOX_RESPONSE
  --FROM #CHCAHPS_Unit
  --WHERE #CHCAHPS_Unit.SURVEY_ID IS NOT NULL
  ----AND VARNAME = 'CH_48'
  ----AND Domain_Goals = 'Rate Hospital'
  --AND TOP_BOX = 1
  ----ORDER BY DOMAIN
  ----        ,Domain_Goals
  --ORDER BY TOP_BOX_RESPONSE
  --        ,DOMAIN
  --        ,Domain_Goals

 --SELECT
 --   CLINIC
 --  ,[DOMAIN]
 --  ,[sk_Dim_PG_Question]
 --  , QUESTION_TEXT_ALIAS
 --  ,SUM([TOP_BOX]) AS TOP_BOX
 --  ,SUM([VAL_COUNT]) AS VAL_COUNT
 -- INTO #CHCAHPS_Unit
 -- FROM #surveys_ch_ip3_sl
 -- GROUP BY CLINIC
 --        , DOMAIN
 --        , sk_Dim_PG_Question
 --        , QUESTION_TEXT_ALIAS

 SELECT
    CLINIC
   ,Discharge_Date
   ,[DOMAIN]
   ,[sk_Dim_PG_Question]
   , QUESTION_TEXT_ALIAS
  INTO #CHCAHPS_Unit
  FROM #surveys_ch_ip3_sl

 SELECT *
 FROM #CHCAHPS_Unit
 ORDER BY CLINIC
        ,Discharge_Date
        , DOMAIN
		, sk_Dim_PG_Question
        , QUESTION_TEXT_ALIAS
/*
SELECT [VALUE]
      ,[DOMAIN]
      ,[SK_DIM_PG_QUESTION]
      ,[PERCENTILE_RANK]
      ,[RPT_PRD_BGN]
      ,[RPT_PRD_END]
      ,[QUESTION_TEXT_ALIAS]
  FROM [HSTSARTDM\HSTSARTDM].[DS_HSDW_App].[Rptg].[CHCAHPS_Ranks]
  WHERE DOMAIN IN ('Help Child Feel Comfortab')
  AND SK_DIM_PG_QUESTION IN ('2111','2112','2131','Domain')
  AND RPT_PRD_BGN = '10/1/2018'
  ORDER BY DOMAIN
         , SK_DIM_PG_QUESTION
		 , VALUE
		 , PERCENTILE_RANK
		 , RPT_PRD_BGN
*/
GO


