USE DS_HSDW_Prod

--SELECT DISTINCT
--       fact.[sk_Dim_PG_Question]
--	  ,dim.QUESTION_TEXT
--      ,fact.[Svc_Cde]
--	  ,fact.RESP_CAT
--      ,dim.[VARNAME]
--      ,fact.VALUE
SELECT DISTINCT
       fact.[Svc_Cde]
      ,dim.[VARNAME]
	  ,fact.sk_Dim_PG_Question
	  ,dim.QUESTION_TEXT
  FROM Rptg.vwFact_PressGaney_Responses fact
  LEFT OUTER JOIN [Rptg].[vwDim_PG_Question] dim
  ON dim.sk_Dim_PG_Question = fact.sk_Dim_PG_Question
  WHERE fact.Svc_Cde = 'PD'
  --WHERE SUBSTRING(dim.VARNAME,1,2) = 'CH'
  --WHERE dim.VARNAME IN ('CH_1'
  AND dim.VARNAME IN  ('CH_1'
                       ,'CH_2'
                       ,'CH_3'
                       ,'CH_4'
                       ,'CH_5'
                       ,'CH_6'
                       ,'CH_7'
                       ,'CH_8'
                       ,'CH_9'
                       ,'CH_10'
                       ,'CH_11'
                       ,'CH_12'
                       ,'CH_13'
                       ,'CH_14'
                       ,'CH_15'
                       ,'CH_16'
                       ,'CH_17'
                       ,'CH_18'
                       ,'CH_19'
                       ,'CH_20'
                       ,'CH_21'
                       ,'CH_22'
                       ,'CH_23'
                       ,'CH_24'
                       ,'CH_25'
                       ,'CH_26'
                       ,'CH_27'
                       ,'CH_28'
                       ,'CH_29'
                       ,'CH_30'
                       ,'CH_31'
                       ,'CH_32'
                       ,'CH_33'
                       ,'CH_34'
                       ,'CH_35'
                       ,'CH_36'
                       ,'CH_37'
                       ,'CH_38'
                       ,'CH_39'
                       ,'CH_40'
                       ,'CH_41'
                       ,'CH_42'
                       ,'CH_43'
                       ,'CH_44'
                       ,'CH_45'
                       ,'CH_46'
                       ,'CH_47'
                       ,'CH_48'
                       ,'CH_49'
                       ,'CH_50'
                       ,'CH_53'
                       ,'CH_54A'
                       ,'CH_54B'
                       ,'CH_54C'
                       ,'CH_54D'
                       ,'CH_54E'
                       ,'CH_55'
                       ,'CH_56'
                       ,'CH_57'
                       ,'CH_58'
                       ,'CH_59'
                       ,'CH_60'
                       ,'CH_61'
					   ,'M8'
					   ,'M2'
					   ,'M2PR'
					   ,'G9'
					   ,'G10'
					   ,'G33'
					   ,'I35'
					   ,'I49'
					   ,'I50'
					   ,'O2'
					   ,'I4'
					   ,'I4PR'
					   )
  --AND SUBSTRING(dim.VARNAME,1,2) = 'CH'
  --WHERE fact.sk_Dim_PG_Question IN ('14','16','28','29','30')
  --WHERE fact.sk_Dim_PG_Question IN ('4')
  --ORDER BY fact.sk_Dim_PG_Question
  --       , fact.VALUE
  --ORDER BY dim.VARNAME
  --       , fact.sk_Dim_PG_Question
  --       , fact.VALUE
  --ORDER BY fact.Svc_Cde
  --       , dim.VARNAME
  --ORDER BY dim.QUESTION_TEXT
  --       , dim.VARNAME
  --       , fact.sk_Dim_PG_Question
  --       , fact.VALUE
  ORDER BY dim.QUESTION_TEXT
         , dim.VARNAME