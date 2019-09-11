USE DS_HSDW_App

IF OBJECT_ID('tempdb..#goal ') IS NOT NULL
DROP TABLE #goal

--IF OBJECT_ID('tempdb..#attr ') IS NOT NULL
--DROP TABLE #attr

SELECT goal.UNIT
	   ,ROW_NUMBER() OVER (ORDER BY goal.UNIT) AS INDX
INTO #goal
  FROM
  (
  SELECT DISTINCT
	UNIT
  FROM [DS_HSDW_App].[Rptg].[PX_Goal_Setting]
  WHERE Service = 'CHCAHPS'
  ) goal
  ORDER BY goal.UNIT

--SELECT DISTINCT
--       [DOMAIN]
--	   ,ROW_NUMBER() OVER (ORDER BY attr.DOMAIN) AS INDX
--INTO #attr
--  FROM
--  (
--  SELECT DISTINCT
--	DOMAIN
--  FROM [DS_HSDW_App].[Rptg].[PG_Extnd_Attr]
--  WHERE SVC_CODE = 'PD'
--  ) attr
--  ORDER BY attr.DOMAIN

  SELECT goal.UNIT AS GOAL_UNIT--, attr.DOMAIN AS ATTR_DOMAIN
  FROM #goal goal
  --INNER JOIN #attr attr
  --ON attr.INDX = goal.INDX
  --ORDER BY goal.DOMAIN

