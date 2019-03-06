USE DS_HSDW_Prod

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
DECLARE @unit_translation TABLE
(
    Goals_Unit NVARCHAR(500)
  , Unit NVARCHAR(500)
);
INSERT INTO @unit_translation
(
    Goals_Unit,
    Unit
)
VALUES
(   '7Central', -- Goals_Unit - nvarchar(500): Value docmented in Goals file
    '7CENTRAL'  -- Unit - nvarchar(500)
),
--(	'7N Acute',
--	'7NOR'
--),
(	'7N PICU',
	'PIC N'
),
(	'7W ACUTE',
	'7WEST'
);
DECLARE @CHCAHPS_PX_Goal_Setting TABLE
(
    GOAL_YR INTEGER
  , SERVICE_LINE VARCHAR(150)
  , UNIT VARCHAR(150)
  , Unit_Goals VARCHAR(150)
  , DOMAIN VARCHAR(150)
  , Domain_Goals VARCHAR(150)
  , GOAL DECIMAL(4,3)
);
INSERT INTO @CHCAHPS_PX_Goal_Setting
SELECT
	[GOAL_YR]
	,'Womens and Childrens' AS SERVICE_LINE
    ,DS_HSDW_App.Rptg.CHCAHPS_PX_Goal_Setting.[UNIT]
    ,COALESCE([@unit_translation].Unit, DS_HSDW_App.Rptg.CHCAHPS_PX_Goal_Setting.UNIT) AS Unit_Goals 
    ,DS_HSDW_App.Rptg.CHCAHPS_PX_Goal_Setting.[DOMAIN]
    ,COALESCE([@domain_translation].DOMAIN, DS_HSDW_App.Rptg.CHCAHPS_PX_Goal_Setting.DOMAIN) AS Domain_Goals
    ,DS_HSDW_App.Rptg.CHCAHPS_PX_Goal_Setting.[GOAL]
FROM [DS_HSDW_App].[Rptg].[CHCAHPS_PX_Goal_Setting]
LEFT OUTER JOIN @domain_translation
    ON [@domain_translation].Goals_Domain = CHCAHPS_PX_Goal_Setting.DOMAIN
LEFT OUTER JOIN @unit_translation
    ON [@unit_translation].Goals_Unit = CHCAHPS_PX_Goal_Setting.UNIT;

DECLARE @CHCAHPS_PX_Goal_Setting_epic_id TABLE
(
    GOAL_YR INTEGER
  , SERVICE_LINE VARCHAR(150)
  , UNIT VARCHAR(150)
  , Unit_Goals VARCHAR(150)
  , DOMAIN VARCHAR(150)
  , Domain_Goals VARCHAR(150)
  , GOAL DECIMAL(4,3)
  , [Epic DEPARTMENT_ID] VARCHAR(50)
  , DEPARTMENT_ID NUMERIC(18,0)
  , dep_sk_Dim_Clrt_DEPt INTEGER
  , CLINIC VARCHAR(250)
  , INDEX IX_CHCAHPS_PX_Goal_Setting_epic_id NONCLUSTERED(GOAL_YR, Unit_Goals, Domain_Goals)
);
INSERT INTO @CHCAHPS_PX_Goal_Setting_epic_id
SELECT
     goals.GOAL_YR
    ,goals.SERVICE_LINE
    ,goals.UNIT
    ,goals.Unit_Goals
    ,goals.DOMAIN
    ,goals.Domain_Goals
    ,goals.GOAL
	,bscm.[Epic DEPARTMENT_ID]
	,dep.DEPARTMENT_ID
	,dep.sk_Dim_Clrt_DEPt AS dep_sk_Dim_Clrt_DEPt
	,CASE WHEN dept.Clrt_DEPt_Nme IS NOT NULL THEN dept.Clrt_DEPt_Nme + ' [' + CAST(dept.DEPARTMENT_ID AS VARCHAR(250)) + ']'
	      ELSE NULL
     END AS CLINIC
FROM @CHCAHPS_PX_Goal_Setting goals
LEFT OUTER JOIN (SELECT DISTINCT
					PressGaney_Name
				   ,[Epic DEPARTMENT_ID]
                 FROM Rptg.vwBalanced_ScoreCard_Mapping
				 WHERE PressGaney_Name IS NOT NULL AND LEN(PressGaney_Name) > 0) bscm
    ON bscm.PressGaney_Name = goals.Unit_Goals
LEFT OUTER JOIN Rptg.vwDim_Clrt_DEPt dep
    ON dep.DEPARTMENT_ID =
		    CASE goals.UNIT
		      WHEN '8TMP' THEN 10243067
		      WHEN 'PIMU' THEN 10243108
			  --WHEN '7N ACUTE' THEN 10243103
			  WHEN '7N Acute' THEN 10243103
		      ELSE CAST(bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
		    END
LEFT OUTER JOIN Rptg.vwDim_Clrt_DEPt dept
	ON dept.sk_Dim_Clrt_DEPt = dep.sk_Dim_Clrt_DEPt
ORDER BY goals.GOAL_YR, goals.Unit_Goals, goals.Domain_Goals;

DECLARE @RptgTbl TABLE
(
    SVC_CDE CHAR(2)
  , GOAL_YR INTEGER
  , SERVICE_LINE VARCHAR(150)
  , UNIT VARCHAR(150)
  , DOMAIN VARCHAR(150)
  , GOAL DECIMAL(4,3)
  , Load_Dtm SMALLDATETIME
);

INSERT INTO @RptgTbl
(
    SVC_CDE,
    GOAL_YR,
    SERVICE_LINE,
    UNIT,
    DOMAIN,
    GOAL,
    Load_Dtm
)
SELECT all_goals.SVC_CDE
     , all_goals.GOAL_YR
	 , all_goals.SERVICE_LINE
	 , all_goals.UNIT
	 , all_goals.DOMAIN
	 , all_goals.GOAL
	 , all_goals.Load_Dtm
FROM
(
-- 2017, 2018, 2019
SELECT DISTINCT
    'PD' AS SVC_CDE
  , CAST(2017 AS INT) AS GOAL_YR
  , CAST(goals.SERVICE_LINE AS VARCHAR(150)) AS SERVICE_LINE
  , CAST(goals.CLINIC AS VARCHAR(150)) AS UNIT
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @CHCAHPS_PX_Goal_Setting_epic_id goals
WHERE goals.GOAL_YR = 2017
AND ((goals.UNIT IS NOT NULL) AND (goals.UNIT <> 'All Units'))
AND goals.DOMAIN IS NOT NULL
AND goals.GOAL IS NOT NULL
UNION ALL
SELECT DISTINCT
    'PD' AS SVC_CDE
  , CAST(2017 AS INT) AS GOAL_YR
  , CAST(goals.SERVICE_LINE AS VARCHAR(150)) AS SERVICE_LINE
  , CAST('All Units' AS VARCHAR(150)) AS UNIT
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @CHCAHPS_PX_Goal_Setting_epic_id goals
WHERE goals.UNIT = 'All Units' AND goals.GOAL_YR = 2017
AND goals.DOMAIN IS NOT NULL
UNION ALL
SELECT DISTINCT
    'PD' AS SVC_CDE
  , CAST(2017 AS INT) AS GOAL_YR
  , CAST('All Service Lines' AS VARCHAR(150)) AS SERVICE_LINE
  , CAST('All Units' AS VARCHAR(150)) AS UNIT
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @CHCAHPS_PX_Goal_Setting_epic_id goals
WHERE UNIT = 'All Units' AND GOAL_YR = 2017
AND goals.DOMAIN IS NOT NULL
UNION ALL
SELECT DISTINCT
    'PD' AS SVC_CDE
  , CAST(2018 AS INT) AS GOAL_YR
  , CAST(goals.SERVICE_LINE AS VARCHAR(150)) AS SERVICE_LINE
  , CAST(goals.CLINIC AS VARCHAR(150)) AS UNIT
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @CHCAHPS_PX_Goal_Setting_epic_id goals
WHERE goals.GOAL_YR = 2018
AND ((goals.UNIT IS NOT NULL) AND (goals.UNIT <> 'All Units'))
AND goals.DOMAIN IS NOT NULL
AND goals.GOAL IS NOT NULL
UNION ALL
SELECT DISTINCT
    'PD' AS SVC_CDE
  , CAST(2018 AS INT) AS GOAL_YR
  , CAST(goals.SERVICE_LINE AS VARCHAR(150)) AS SERVICE_LINE
  , CAST('All Units' AS VARCHAR(150)) AS UNIT
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @CHCAHPS_PX_Goal_Setting_epic_id goals
WHERE goals.UNIT = 'All Units' AND goals.GOAL_YR = 2018
AND goals.DOMAIN IS NOT NULL
UNION ALL
SELECT DISTINCT
    'PD' AS SVC_CDE
  , CAST(2018 AS INT) AS GOAL_YR
  , CAST('All Service Lines' AS VARCHAR(150)) AS SERVICE_LINE
  , CAST('All Units' AS VARCHAR(150)) AS UNIT
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @CHCAHPS_PX_Goal_Setting_epic_id goals
WHERE UNIT = 'All Units' AND GOAL_YR = 2018
AND goals.DOMAIN IS NOT NULL
UNION ALL
SELECT DISTINCT
    'PD' AS SVC_CDE
  , CAST(2019 AS INT) AS GOAL_YR
  , CAST(goals.SERVICE_LINE AS VARCHAR(150)) AS SERVICE_LINE
  , CAST(goals.CLINIC AS VARCHAR(150)) AS UNIT
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @CHCAHPS_PX_Goal_Setting_epic_id goals
WHERE goals.GOAL_YR = 2019
AND ((goals.UNIT IS NOT NULL) AND (goals.UNIT <> 'All Units'))
AND goals.DOMAIN IS NOT NULL
AND goals.GOAL IS NOT NULL
UNION ALL
SELECT DISTINCT
    'PD' AS SVC_CDE
  , CAST(2019 AS INT) AS GOAL_YR
  , CAST(goals.SERVICE_LINE AS VARCHAR(150)) AS SERVICE_LINE
  , CAST('All Units' AS VARCHAR(150)) AS UNIT
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @CHCAHPS_PX_Goal_Setting_epic_id goals
WHERE goals.UNIT = 'All Units' AND goals.GOAL_YR = 2019
AND goals.DOMAIN IS NOT NULL
UNION ALL
SELECT DISTINCT
    'PD' AS SVC_CDE
  , CAST(2019 AS INT) AS GOAL_YR
  , CAST('All Service Lines' AS VARCHAR(150)) AS SERVICE_LINE
  , CAST('All Units' AS VARCHAR(150)) AS UNIT
  , CAST(goals.Domain_Goals AS VARCHAR(150)) AS DOMAIN
  , CAST(goals.GOAL AS DECIMAL(4,3)) AS GOAL
  , CAST(GETDATE() AS SMALLDATETIME) AS Load_Dtm
FROM @CHCAHPS_PX_Goal_Setting_epic_id goals
WHERE UNIT = 'All Units' AND GOAL_YR = 2019
AND goals.DOMAIN IS NOT NULL
) all_goals;

SELECT *
FROM @RptgTbl
ORDER BY GOAL_YR
       , SERVICE_LINE
       , UNIT
	   , DOMAIN

--SELECT DISTINCT
--	GOAL_YR
--  , UNIT
--FROM @RptgTbl
--ORDER BY GOAL_YR
--       , UNIT
