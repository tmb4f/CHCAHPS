SELECT
		fact.SURVEY_ID
		,fact.VALUE
		,CASE fact.VALUE
			WHEN '7CENTRAL (Closed)' THEN '7CENTRAL'
			WHEN '7N ACUTE' THEN '7NOR'
			WHEN '7N PICU' THEN 'PIC N'
			WHEN '7W ACUTE' THEN '7WEST'
			--WHEN '8TMP' THEN 'Other'
			WHEN 'PICU (Closed)' THEN 'PIC N'
			--WHEN 'PIMU' THEN 'Other'
			--WHEN 'RN (Closed)' THEN 'Other'
			ELSE CAST(fact.VALUE AS NVARCHAR(500)) END AS UNIT
		--,bscm.PressGaney_Name
		,CASE fact.VALUE
			WHEN '8TMP' THEN 10243067
			WHEN 'PIMU' THEN 10243108
			ELSE CAST(bscm.[Epic DEPARTMENT_ID] AS NUMERIC(18,0))
		 END AS DEPARTMENT_ID
		FROM DS_HSDW_Prod.dbo.Fact_PressGaney_Responses fact
		LEFT OUTER JOIN [DS_HSDW_Prod].[Rptg].[vwBalanced_ScoreCard_Mapping] bscm
		--ON bscm.PressGaney_Name = REPLACE(fact.VALUE,' (Closed)','')
		--ON bscm.PressGaney_Name = fact.VALUE
		ON bscm.PressGaney_Name =
		  CASE fact.VALUE
			WHEN '7CENTRAL (Closed)' THEN '7CENTRAL'
			WHEN '7N ACUTE' THEN '7NOR'
			WHEN '7N PICU' THEN 'PIC N'
			WHEN '7W ACUTE' THEN '7WEST'
			--WHEN '8TMP' THEN 'Other'
			WHEN 'PICU (Closed)' THEN 'PIC N'
			--WHEN 'PIMU' THEN 'Other'
			--WHEN 'RN (Closed)' THEN 'Other'
			ELSE CAST(fact.VALUE AS NVARCHAR(500))
		  END
		WHERE sk_Dim_PG_Question = '2384'
		--AND bscm.PressGaney_Name IS NULL
		ORDER BY
		  fact.VALUE 
		 ,fact.SURVEY_ID
		 ,CASE fact.VALUE
			WHEN '7W ACUTE' THEN '7WEST'
			WHEN '7N ACUTE' THEN '7NOR'
			WHEN '7N PICU' THEN 'PIC N'
			--WHEN '8TMP' THEN 'Other'
			WHEN 'PICU (Closed)' THEN 'PIC N'
			--WHEN 'PIMU' THEN 'Other'
			--WHEN 'RN (Closed)' THEN 'Other'
			ELSE CAST(fact.VALUE AS NVARCHAR(500)) END
		--,bscm.PressGaney_Name
		  