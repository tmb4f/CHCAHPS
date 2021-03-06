/****** Script for SelectTopNRows command from SSMS  ******/
SELECT [sk_PG_Extend_Attr]
      ,[sk_Dim_PG_Question]
      ,[QUESTION_TEXT]
      ,[VARNAME]
      ,[SVC_CODE]
      ,[RESP_CAT]
      ,[DOMAIN]
      ,[TOP_10]
      ,[TOP_BOX]
      ,[QUESTION_ORDER]
      ,[ETL_guid]
      ,[Load_Dtm]
      ,[QUESTION_TEXT_ALIAS]
  FROM [DS_HSDW_App].[Rptg].[PG_Extnd_Attr]
  WHERE RESP_CAT = 'HCAHPS'
  AND DOMAIN IS NOT null
  ORDER BY DOMAIN
          ,VARNAME