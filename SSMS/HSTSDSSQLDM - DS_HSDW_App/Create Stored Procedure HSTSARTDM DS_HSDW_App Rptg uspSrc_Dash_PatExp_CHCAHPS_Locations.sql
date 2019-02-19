USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER OFF
GO

CREATE PROCEDURE [Rptg].[uspSrc_Dash_PatExp_CHCAHPS_Locations]
AS
/**********************************************************************************************************************
WHAT: Stored procedure for Patient Experience Dashboard - Child HCAHPS (Inpatient)
      Distinct list of units and service lines
WHO : Tom Burgan
WHEN: 10/22/2018
WHY : Produce surveys results for patient experience dashboard
-----------------------------------------------------------------------------------------------------------------------
INFO: 
      INPUTS:	DS_HSDW_Prod.dbo.Fact_PressGaney_Responses
				DS_HSDW_Prod.rptg.Balanced_Scorecard_Mapping
				DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt
				DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc
				DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master
                  
      OUTPUTS: DS_HSDW_App.Rptg.uspSrc_Dash_PatExp_CHCAHPS_Locations
   
------------------------------------------------------------------------------------------------------------------------
MODS: 	10/22/2018 - Created procedure
***********************************************************************************************************************/

SET NOCOUNT ON

EXEC dbo.usp_TruncateTable @schema = 'Rptg',@Table = 'CHCAHPS_Locations'

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

SELECT DISTINCT
    resp.SURVEY_ID
  , resp.VALUE AS UNIT
  , CASE VALUE
	  WHEN '7CENTRAL (Closed)' THEN '7CENTRAL'
	  WHEN '7N ACUTE' THEN '7NOR'
	  WHEN '7N PICU' THEN 'PIC N'
	  WHEN '7W ACUTE' THEN '7WEST'
	  WHEN 'PICU (Closed)' THEN 'PIC N'
	  ELSE CAST(resp.VALUE AS NVARCHAR(500))
	END AS Derived_UNIT
INTO #chcahps_resp
FROM DS_HSDW_Prod.Rptg.vwFact_PressGaney_Responses resp
WHERE resp.sk_Dim_PG_Question IN
	(
		'2384'  -- UNIT
	)
AND resp.Svc_Cde = 'PD'
AND (resp.RECDATE >= @startdate OR resp.DISDATE >= @startdate)

----------------------------------------------------------------------------------------------------

INSERT INTO Rptg.CHCAHPS_Locations (SERVICE_LINE,
                                    UNIT,
								    EPIC_DEPARTMENT_ID
                                   )
SELECT locations.SERVICE_LINE, locations.UNIT_Derived AS UNIT, locations.EPIC_DEPARTMENT_ID
FROM
(
	SELECT
		responses.UNIT
	   ,responses.EPIC_DEPARTMENT_ID
	   ,responses.SERVICE_LINE
	   ,responses.UNIT_Derived
	FROM
	( 
	    SELECT DISTINCT
		    CAST(RespUnit.Derived_UNIT AS VARCHAR(500)) AS UNIT
		   ,CAST(bscm_dept.DEPARTMENT_ID AS VARCHAR(500)) AS EPIC_DEPARTMENT_ID
	       ,CAST(CASE WHEN loc_master.service_line IS NULL OR loc_master.service_line = 'Unknown' THEN 'Other'
		              ELSE loc_master.service_line
	             END AS VARCHAR(500)) AS SERVICE_LINE
	       ,CAST(CASE WHEN loc_master.epic_department_name IS NULL OR loc_master.epic_department_name = 'Unknown' THEN 'Other' ELSE loc_master.epic_department_name + ' [' + CAST(loc_master.epic_department_id AS VARCHAR(250)) + ']' END AS VARCHAR(500)) AS UNIT_Derived
	    FROM #chcahps_resp RespUnit
	    LEFT OUTER JOIN
	    (	
		    SELECT DISTINCT
				[Epic DEPARTMENT_ID]
			   ,PressGaney_Name
		    FROM  DS_HSDW_Prod.Rptg.Balanced_ScoreCard_Mapping
	     ) AS bscm
		    ON RespUnit.Derived_UNIT = bscm.PressGaney_name
        LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwDim_Clrt_DEPt bscm_dept
	        ON bscm_dept.DEPARTMENT_ID =
		        CASE RespUnit.UNIT
		          WHEN '8TMP' THEN 10243067
		          WHEN 'PIMU' THEN 10243108
		          ELSE CAST(bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
		        END
        LEFT OUTER JOIN DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master_EpicSvc AS loc_master
	        ON bscm_dept.DEPARTMENT_ID = loc_master.EPIC_DEPARTMENT_ID
        LEFT OUTER JOIN
	    (
			SELECT
		        EPIC_DEPARTMENT_ID
		       ,MAX(Sub_Service_Line) AS SUB_SERVICE_LINE -- in case more than 1
	        FROM DS_HSDW_Prod.Rptg.vwRef_MDM_Location_Master
	        WHERE SUB_SERVICE_LINE <> 'Unknown'
	        GROUP BY EPIC_DEPARTMENT_ID
	    ) MDM -- MDM_epicsvc view doesn't include sub service line
	        ON loc_master.epic_department_id = MDM.[EPIC_DEPARTMENT_ID]
	) responses
) locations

GO


