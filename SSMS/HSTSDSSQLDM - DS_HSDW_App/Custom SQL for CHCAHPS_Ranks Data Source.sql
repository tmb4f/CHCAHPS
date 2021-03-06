/****** Script for SelectTopNRows command from SSMS  ******/
SELECT DOMAIN
      ,SK_DIM_PG_QUESTION
      ,[VALUE]
      ,RPT_PRD_BGN
      ,RPT_PRD_END
      ,PERCENTILE_RANK
      ,QUESTION_TEXT_ALIAS
FROM (
	SELECT DOMAIN
          ,SK_DIM_PG_QUESTION
          ,[VALUE]
          ,RPT_PRD_BGN
          ,RPT_PRD_END
          ,PERCENTILE_RANK
          ,QUESTION_TEXT_ALIAS
	      ,ROW_NUMBER() OVER (PARTITION BY DOMAIN, SK_DIM_PG_QUESTION, [VALUE] ORDER BY RPT_PRD_END DESC) AS Seq
     FROM Rptg.CHCAHPS_Ranks) ranks
WHERE ranks.Seq = 1