USE DS_HSDW_Prod

IF OBJECT_ID('tempdb..#PGSurvey ') IS NOT NULL
DROP TABLE #PGSurvey

IF OBJECT_ID('tempdb..#PGQuestion ') IS NOT NULL
DROP TABLE #PGQuestion

IF OBJECT_ID('tempdb..#PGQuestionResponse ') IS NOT NULL
DROP TABLE #PGQuestionResponse

IF OBJECT_ID('tempdb..#PGQuestionResponseSummary ') IS NOT NULL
DROP TABLE #PGQuestionResponseSummary

IF OBJECT_ID('tempdb..#PGQuestionResponseSummaryPlus ') IS NOT NULL
DROP TABLE #PGQuestionResponseSummaryPlus

IF OBJECT_ID('tempdb..#AnalysisPivot ') IS NOT NULL
DROP TABLE #AnalysisPivot

IF OBJECT_ID('tempdb..#YesNoPivot ') IS NOT NULL
DROP TABLE #YesNoPivot

IF OBJECT_ID('tempdb..#YesYesNoPivot ') IS NOT NULL
DROP TABLE #YesYesNoPivot

IF OBJECT_ID('tempdb..#NeverSometimesUsuallyAlwaysPivot ') IS NOT NULL
DROP TABLE #NeverSometimesUsuallyAlwaysPivot

IF OBJECT_ID('tempdb..#DefinitelyProbablyProbablyDefinitelyPivot ') IS NOT NULL
DROP TABLE #DefinitelyProbablyProbablyDefinitelyPivot

IF OBJECT_ID('tempdb..#ZeroToTenPivot ') IS NOT NULL
DROP TABLE #ZeroToTenPivot

IF OBJECT_ID('tempdb..#ExcellentToPoorPivot ') IS NOT NULL
DROP TABLE #ExcellentToPoorPivot

--SELECT [sk_Dim_PG_Question]
--      ,[Svc_Cde]
--      ,[VARNAME]
--      ,[Beg_Dte]
--      ,[End_Dte]
--      ,[QUESTION_TEXT]
--      ,[Survey_count]
--      ,[repeats]
--      ,[UpDte_Dtm]
--      ,[Load_Dtm]
--  FROM [Rptg].[vwDim_PG_Question]
--  WHERE Svc_Cde = 'PD'
--  ORDER BY sk_Dim_PG_Question

--SELECT DISTINCT
--       fact.[sk_Dim_PG_Question]
--      ,fact.[Svc_Cde]
--	  ,fact.RESP_CAT
--      ,dim.[VARNAME]
--      ,fact.VALUE
--  FROM Rptg.vwFact_PressGaney_Responses fact
--  LEFT OUTER JOIN [Rptg].[vwDim_PG_Question] dim
--  ON dim.sk_Dim_PG_Question = fact.sk_Dim_PG_Question
--  WHERE fact.Svc_Cde = 'PD'
--  ORDER BY fact.sk_Dim_PG_Question
--         , fact.VALUE

--SELECT COUNT(fact.SURVEY_ID) AS Survey_Count
--  INTO #PGSurvey
--  FROM (SELECT DISTINCT
--			SURVEY_ID
--	    FROM Rptg.vwFact_PressGaney_Responses
--		WHERE Svc_Cde = 'PD') fact

SELECT fact.Svc_Cde
      ,COUNT(fact.SURVEY_ID) AS Survey_Count
  INTO #PGSurvey
  FROM (SELECT DISTINCT
            fact.Svc_Cde
		   ,fact.SURVEY_ID
	    FROM Rptg.vwFact_PressGaney_Responses fact
        LEFT OUTER JOIN [Rptg].[vwDim_PG_Question] dim
        ON dim.sk_Dim_PG_Question = fact.sk_Dim_PG_Question
		--WHERE fact.Svc_Cde = 'PD'
        --AND fact.RESP_CAT IN ('HCAHPS','ANALYSIS')
        WHERE fact.RESP_CAT IN ('HCAHPS','ANALYSIS')
        AND ((dim.VARNAME NOT LIKE 'OPEN%') AND
             (dim.VARNAME NOT LIKE 'EOPEN%') AND
             (dim.VARNAME NOT LIKE 'SECT%') AND
	         (dim.VARNAME <> 'FLOATING'))) fact
  GROUP BY fact.Svc_Cde

--SELECT *
--FROM #PGSurvey

SELECT fact.Svc_Cde
      ,fact.[sk_Dim_PG_Question]
	  ,fact.RESP_CAT
      ,dim.[VARNAME]
	  ,dim.QUESTION_TEXT
      ,fact.VALUE
	  ,fact.RECDATE
	  ,fact.DISDATE
  FROM Rptg.vwFact_PressGaney_Responses fact
  LEFT OUTER JOIN [Rptg].[vwDim_PG_Question] dim
  ON dim.sk_Dim_PG_Question = fact.sk_Dim_PG_Question
  --WHERE fact.Svc_Cde = 'PD'
  --AND fact.RESP_CAT IN ('HCAHPS','ANALYSIS')
  WHERE fact.RESP_CAT IN ('HCAHPS','ANALYSIS')
  AND ((dim.VARNAME NOT LIKE 'OPEN%') AND
       (dim.VARNAME NOT LIKE 'EOPEN%') AND
       (dim.VARNAME NOT LIKE 'SECT%') AND
	   (dim.VARNAME <> 'FLOATING'))
ORDER BY fact.DISDATE

SELECT fact.Svc_Cde
      ,fact.[sk_Dim_PG_Question]
	  ,fact.RESP_CAT
      ,dim.[VARNAME]
      ,fact.VALUE
	  ,COUNT(*) AS VALUE_COUNT
  INTO #PGQuestionResponse
  FROM Rptg.vwFact_PressGaney_Responses fact
  LEFT OUTER JOIN [Rptg].[vwDim_PG_Question] dim
  ON dim.sk_Dim_PG_Question = fact.sk_Dim_PG_Question
  --WHERE fact.Svc_Cde = 'PD'
  --AND fact.RESP_CAT IN ('HCAHPS','ANALYSIS')
  WHERE fact.RESP_CAT IN ('HCAHPS','ANALYSIS')
  AND ((dim.VARNAME NOT LIKE 'OPEN%') AND
       (dim.VARNAME NOT LIKE 'EOPEN%') AND
       (dim.VARNAME NOT LIKE 'SECT%') AND
	   (dim.VARNAME <> 'FLOATING'))
  GROUP BY fact.Svc_Cde
          ,fact.[sk_Dim_PG_Question]
	      ,fact.RESP_CAT
          ,dim.[VARNAME]
          ,fact.VALUE

  --SELECT *
  --FROM #PGQuestionResponse
  --ORDER BY sk_Dim_PG_Question
  --       , VALUE

SELECT fact.Svc_Cde
      ,fact.[sk_Dim_PG_Question]
	  ,dim.QUESTION_TEXT
	  ,fact.RESP_CAT
      ,dim.[VARNAME]
	  ,COUNT(*) AS VALUE_COUNT
  INTO #PGQuestion
  FROM Rptg.vwFact_PressGaney_Responses fact
  LEFT OUTER JOIN [Rptg].[vwDim_PG_Question] dim
  ON dim.sk_Dim_PG_Question = fact.sk_Dim_PG_Question
  --WHERE fact.Svc_Cde = 'PD'
  --AND fact.RESP_CAT IN ('HCAHPS','ANALYSIS')
  WHERE fact.RESP_CAT IN ('HCAHPS','ANALYSIS')
  AND ((dim.VARNAME NOT LIKE 'OPEN%') AND
       (dim.VARNAME NOT LIKE 'EOPEN%') AND
       (dim.VARNAME NOT LIKE 'SECT%') AND
	   (dim.VARNAME <> 'FLOATING'))
  GROUP BY fact.Svc_Cde
          ,fact.[sk_Dim_PG_Question]
		  ,dim.QUESTION_TEXT
	      ,fact.RESP_CAT
          ,dim.[VARNAME]

  --SELECT *
  --FROM #PGQuestion
  --ORDER BY sk_Dim_PG_Question

SELECT resp.Svc_Cde
      ,resp.[sk_Dim_PG_Question]
	  ,quest.QUESTION_TEXT
	  ,resp.RESP_CAT
      ,resp.[VARNAME]
      ,resp.VALUE
	  ,resp.VALUE_COUNT AS Resp_Count
	  ,quest.VALUE_COUNT AS Quest_Count
	  ,survey.Survey_Count
  INTO #PGQuestionResponseSummary
  FROM #PGQuestionResponse resp
  INNER JOIN #PGQuestion quest
  ON resp.sk_Dim_PG_Question = quest.sk_Dim_PG_Question
  INNER JOIN #PGSurvey survey
  ON resp.Svc_Cde = survey.Svc_Cde

  --SELECT *
  --FROM #PGQuestionResponseSummary
  --ORDER BY sk_Dim_PG_Question
  --       , VALUE

  SELECT VARNAME
        ,QUESTION_TEXT
		,RESP_CAT
		,UPPER(VALUE) AS VALUE
		,Resp_Count
		,Quest_Count
		,CAST((CAST(Resp_Count AS NUMERIC(8,2))/CAST(Quest_Count AS NUMERIC(8,2)))*100.00 AS NUMERIC(5,2)) AS Resp_Prcnt
  INTO #PGQuestionResponseSummaryPlus
  FROM #PGQuestionResponseSummary

  --SELECT *
  --FROM #PGQuestionResponseSummaryPlus
  --ORDER BY VARNAME
  --       , VALUE

  SELECT
     PivotTable.VARNAME
   , PivotTable.QUESTION_TEXT
   , PivotTable.Quest_Count
   , [1] AS [Very Poor]
   , [2] AS [Poor]
   , [3] AS [Fair]
   , [4] AS [Good]
   , [5] AS [Very Good]
  INTO #AnalysisPivot
  FROM
  (SELECT VARNAME
		, QUESTION_TEXT
		, Quest_Count
		, VALUE
		, Resp_Prcnt
   FROM #PGQuestionResponseSummaryPlus
   WHERE RESP_CAT = 'ANALYSIS') resp
  PIVOT
  (
  MAX(resp.Resp_Prcnt)
  FOR VALUE IN ([1], -- very poor
                [2], -- poor
                [3], -- fair
                [4], -- good
                [5]  -- very good
			   )
  ) AS PivotTable

  SELECT VARNAME AS QID
        ,QUESTION_TEXT AS Question
		,Quest_Count AS Responses
		,[Very Poor]
		,Poor
		,Fair
		,Good
		,[Very Good]
  FROM #AnalysisPivot
  ORDER BY VARNAME

  SELECT
     PivotTable.VARNAME
   , PivotTable.QUESTION_TEXT
   , PivotTable.Quest_Count
   , [YES] AS [Yes]
   , [NO] AS [No]
  INTO #YesNoPivot
  FROM
  (SELECT VARNAME
		, QUESTION_TEXT
		, Quest_Count
		, VALUE
		, Resp_Prcnt
   FROM #PGQuestionResponseSummaryPlus
   WHERE RESP_CAT = 'HCAHPS'
   AND VARNAME IN ('CH_1','CH_2','CH_24','CH_26','CH_28','CH_2CL','CH_3','CH_31','CH_38','CH_3CL','CH_44',
                   'CH_54A','CH_54B','CH_54C','CH_54D','CH_54E',
				   'CH_60','CH_61A','CH_61ACL','CH_61B','CH_61BCL','CH_61C','CH_61CCL','CH_61D','CH_61DCL','CH_61E','CH_61ECL',
				   'CH_7','CH_7CL','ER','FSTAY','MATE','ONIGHT')) resp
  PIVOT
  (
  MAX(resp.Resp_Prcnt)
  FOR VALUE IN ([YES], -- Yes
                [NO]   -- No
			   )
  ) AS PivotTable

  SELECT VARNAME AS QID
        ,QUESTION_TEXT AS Question
		,Quest_Count AS Responses
		,Yes
		,[No]
  FROM #YesNoPivot
  ORDER BY VARNAME

  SELECT
     PivotTable.VARNAME
   , PivotTable.QUESTION_TEXT
   , PivotTable.Quest_Count
   , [YES, DEFINITELY] AS [Yes, defintely]
   , [YES, SOMEWHAT] AS [Yes, somewhat]
   , [NO] AS [No]
  INTO #YesYesNoPivot
  FROM
  (SELECT VARNAME
		, QUESTION_TEXT
		, Quest_Count
		, VALUE
		, Resp_Prcnt
   FROM #PGQuestionResponseSummaryPlus
   WHERE RESP_CAT = 'HCAHPS'
   --AND VARNAME IN ('CH_21','CH_30','CH_32','CH_32CL','CH_35','CH_36','CH_37','CH_39','CH_39CL','CH_4','CH_40','CH_40CL',
   --                'CH_41','CH_42','CH_43','CH_45','CH_45CL','CH_46','CH_46CL','CH_47','CH_47CL','CH_4CL',
			--	   'CH_5','CH_5CL','CH_6','CH_6CL')) resp
   AND VARNAME IN ('CH_21','CH_30','CH_32','CH_32CL','CH_35','CH_36','CH_37','CH_39','CH_39CL','CH_4','CH_40','CH_40CL',
                   'CH_41','CH_42','CH_43','CH_46','CH_46CL','CH_47','CH_47CL','CH_4CL',
				   'CH_5','CH_5CL','CH_6','CH_6CL')) resp
  PIVOT
  (
  MAX(resp.Resp_Prcnt)
  FOR VALUE IN ([YES, DEFINITELY], -- Yes, definitely
                [YES, SOMEWHAT], -- Yes, somewhat
                [NO]             -- No
			   )
  ) AS PivotTable

  SELECT VARNAME AS QID
        ,QUESTION_TEXT AS Question
		,Quest_Count AS Responses
		,[Yes, defintely]
		,[Yes, somewhat]
		,[No]
  FROM #YesYesNoPivot
  ORDER BY VARNAME

  SELECT
     PivotTable.VARNAME
   , PivotTable.QUESTION_TEXT
   , PivotTable.Quest_Count
   , [NEVER] AS [Never]
   , [SOMETIMES] AS [Sometimes]
   , [USUALLY] AS [Usually]
   , [ALWAYS] AS [Always]
  INTO #NeverSometimesUsuallyAlwaysPivot
  FROM
  (SELECT VARNAME
		, QUESTION_TEXT
		, Quest_Count
		, VALUE
		, Resp_Prcnt
   FROM #PGQuestionResponseSummaryPlus
   WHERE RESP_CAT = 'HCAHPS'
   AND VARNAME IN ('CH_10','CH_10CL','CH_11','CH_11CL','CH_12','CH_12CL','CH_13','CH_13CL','CH_14','CH_15','CH_16',
                   'CH_17','CH_18','CH_19','CH_20','CH_22','CH_23','CH_25','CH_25CL','CH_25','CH_25CL','CH_27','CH_27CL',
				   'CH_29','CH_29CL','CH_33','CH_34','CH_45','CH_45CL','CH_8','CH_8CL','CH_9','CH_9CL')) resp
  PIVOT
  (
  MAX(resp.Resp_Prcnt)
  FOR VALUE IN ([NEVER],     -- Never
                [SOMETIMES], -- Sometimes
                [USUALLY],   -- Usually
                [ALWAYS]     -- Always
			   )
  ) AS PivotTable

  SELECT VARNAME AS QID
        ,QUESTION_TEXT AS Question
		,Quest_Count AS Responses
		,[Never]
		,Sometimes
		,Usually
		,Always
  FROM #NeverSometimesUsuallyAlwaysPivot
  ORDER BY VARNAME

  SELECT
     PivotTable.VARNAME
   , PivotTable.QUESTION_TEXT
   , PivotTable.Quest_Count
   , [DEFINITELY NO] AS [Definitely no]
   , [PROBABLY NO] AS [Probably no]
   , [PROBABLY YES] AS [Probably yes]
   , [DEFINITELY YES] AS [Definitely yes]
  INTO #DefinitelyProbablyProbablyDefinitelyPivot
  FROM
  (SELECT VARNAME
		, QUESTION_TEXT
		, Quest_Count
		, VALUE
		, Resp_Prcnt
   FROM #PGQuestionResponseSummaryPlus
   WHERE RESP_CAT = 'HCAHPS'
   AND VARNAME IN ('CH_49')) resp
  PIVOT
  (
  MAX(resp.Resp_Prcnt)
  FOR VALUE IN ([DEFINITELY NO],  -- Definitely no
                [PROBABLY NO],    -- Probably no
                [PROBABLY YES],   -- Probably yes
                [DEFINITELY YES]  -- Definitely yes
			   )
  ) AS PivotTable

  SELECT VARNAME AS QID
        ,QUESTION_TEXT AS Question
		,Quest_Count AS Responses
		,[Definitely no]
		,[Probably no]
		,[Probably yes]
		,[Definitely yes]
  FROM #DefinitelyProbablyProbablyDefinitelyPivot
  ORDER BY VARNAME

  SELECT
     PivotTable.VARNAME
   , PivotTable.QUESTION_TEXT
   , PivotTable.Quest_Count
   , [0-WORST HOSP] AS [0]
   , [1] AS [1]
   , [2] AS [2]
   , [3] AS [3]
   , [4] AS [4]
   , [5] AS [5]
   , [6] AS [6]
   , [7] AS [7]
   , [8] AS [8]
   , [9] AS [9]
   , [10-BEST HOSP] AS [10]
  INTO #ZeroToTenPivot
  FROM
  (SELECT VARNAME
		, QUESTION_TEXT
		, Quest_Count
		, VALUE
		, Resp_Prcnt
   FROM #PGQuestionResponseSummaryPlus
   WHERE RESP_CAT = 'HCAHPS'
   AND VARNAME IN ('CH_48')) resp
  PIVOT
  (
  MAX(resp.Resp_Prcnt)
  FOR VALUE IN ([0-WORST HOSP], -- 0-Worst hosp
                [1],            -- 1
                [2],            -- 2
                [3],            -- 3
                [4],            -- 4
                [5],            -- 5
                [6],            -- 6
                [7],            -- 7
                [8],            -- 8
                [9],            -- 9
				[10-BEST HOSP]  -- 10-Best hosp
			   )
  ) AS PivotTable

  SELECT VARNAME AS QID
        ,QUESTION_TEXT AS Question
		,Quest_Count AS Responses
		, [0]
		, [1]
		, [2]
		, [3]
		, [4]
		, [5]
		, [6]
		, [7]
		, [8]
		, [9]
		, [10]
  FROM #ZeroToTenPivot
  ORDER BY VARNAME

  SELECT
     PivotTable.VARNAME
   , PivotTable.QUESTION_TEXT
   , PivotTable.Quest_Count
   , [EXCELLENT] AS [Excellent]
   , [VERY GOOD] AS [Very good]
   , [GOOD] AS [Good]
   , [FAIR] AS [Fair]
   , [POOR] AS [Poor]
  INTO #ExcellentToPoorPivot
  FROM
  (SELECT VARNAME
		, QUESTION_TEXT
		, Quest_Count
		, VALUE
		, Resp_Prcnt
   FROM #PGQuestionResponseSummaryPlus
   WHERE RESP_CAT = 'HCAHPS'
   AND VARNAME IN ('CH_50')) resp
  PIVOT
  (
  MAX(resp.Resp_Prcnt)
  FOR VALUE IN ([EXCELLENT], -- Excellent
                [VERY GOOD], -- Very good
                [GOOD], -- Good
                [FAIR], -- Fair
                [POOR]  -- Poor
			   )
  ) AS PivotTable

  SELECT VARNAME AS QID
        ,QUESTION_TEXT AS Question
		,Quest_Count AS Responses
		,Excellent
		,[Very good]
		,Good
		,Fair
		,Poor
  FROM #ExcellentToPoorPivot
  ORDER BY VARNAME
