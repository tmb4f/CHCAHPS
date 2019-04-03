USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

-- =====================================================================================
-- Create procedure uspSrc_Dash_PatExp_CHCAHPS_Locations
-- =====================================================================================
IF EXISTS (SELECT 1
    FROM INFORMATION_SCHEMA.ROUTINES 
    WHERE ROUTINE_SCHEMA='Rptg'
    AND ROUTINE_TYPE='PROCEDURE'
    AND ROUTINE_NAME='uspSrc_Dash_PatExp_CHCAHPS_Locations')
   DROP PROCEDURE Rptg.[uspSrc_Dash_PatExp_CHCAHPS_Locations]
GO

CREATE PROCEDURE [Rptg].[uspSrc_Dash_PatExp_CHCAHPS_Locations]
AS
/**********************************************************************************************************************
WHAT: Stored procedure for Patient Experience Dashboard - Child HCAHPS (Inpatient)
      Distinct list of units and service lines
WHO : Tom Burgan
WHEN: 04/03/2019
WHY : Produce surveys results for patient experience dashboard
-----------------------------------------------------------------------------------------------------------------------
INFO: 
      INPUTS:	DS_HSDW_Prod.dbo.Fact_PressGaney_Responses
	            DS_HSDW_Stage.PressGaney.PG_Responses_xmlrip
				DS_HSDW_Prod.Rptg.vwFact_Pt_Enc_Clrt
				DS_HSDW_Prod.Rptg.Balanced_Scorecard_Mapping
				DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt
				DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc
                  
      OUTPUTS: DS_HSDW_App.Rptg.uspSrc_Dash_PatExp_CHCAHPS_Locations
   
------------------------------------------------------------------------------------------------------------------------
MODS: 	04/03/2019 - Created procedure
***********************************************************************************************************************/

SET NOCOUNT ON

--EXEC dbo.usp_TruncateTable @schema = 'Rptg',@Table = 'CHCAHPS_Locations'

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
			  WHEN '7N ACUTE' THEN 10243103
		      ELSE CAST(bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
		    END
ORDER BY resp.SURVEY_ID

----------------------------------------------------------------------------------------------------

INSERT INTO Rptg.CHCAHPS_Locations (SERVICE_LINE,
                                    CLINIC,
								    EPIC_DEPARTMENT_ID
                                   )
SELECT locations.SERVICE_LINE, locations.CLINIC, locations.EPIC_DEPARTMENT_ID
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
	FROM
	( 
	    SELECT DISTINCT
	        11 AS SERVICE_LINE_ID
	       ,'Womens and Childrens' AS SERVICE_LINE
	       ,'Children' AS SUB_SERVICE_LINE
	       ,CAST(CASE WHEN loc_master.epic_department_name IS NOT NULL AND loc_master.epic_department_name <> 'Unknown' THEN loc_master.epic_department_name + ' [' + CAST(loc_master.epic_department_id AS VARCHAR(250)) + ']'
	                  WHEN dept.Clrt_DEPt_Nme IS NOT NULL THEN dept.Clrt_DEPt_Nme + ' [' + CAST(dept.DEPARTMENT_ID AS VARCHAR(250)) + ']'
	                  ELSE 'Unknown' + ' [' + CAST(dept.DEPARTMENT_ID AS VARCHAR(250)) + ']'
                 END AS VARCHAR(500)) AS CLINIC
		   ,CAST(dept.DEPARTMENT_ID AS VARCHAR(500)) AS EPIC_DEPARTMENT_ID
	    FROM
		(
		    SELECT DISTINCT
		        CASE
		          WHEN sk_Dim_Clrt_DEPt IS NOT NULL AND sk_Dim_Clrt_DEPt > 0 THEN sk_Dim_Clrt_DEPt
			      WHEN der_UNIT IS NULL THEN enc_sk_Dim_Clrt_DEPt
			      WHEN der_UNIT <> 'RN (Closed)' THEN dep_sk_Dim_Clrt_DEPt
			      ELSE enc_sk_Dim_Clrt_DEPt
			    END AS sk_Dim_Clrt_DEPt
			   ,UNIT
			FROM #chcahps_resp_epic_id
		) AS RespUnit
        LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt dept
	        ON dept.sk_Dim_Clrt_DEPt = RespUnit.sk_Dim_Clrt_DEPt
        LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc AS loc_master
	        ON dept.DEPARTMENT_ID = loc_master.EPIC_DEPARTMENT_ID
	) responses
) locations

GO


