USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Rptg].[CHCAHPS_Response_Summary_Test](
	[SERVICE_LINE] [VARCHAR](500) NULL,
	[Epic_Department_Group_Name] [VARCHAR](500) NULL,
	[CLINIC] [VARCHAR](500) NULL,
	[EPIC_DEPARTMENT_ID] [VARCHAR](500) NULL,
	[DOMAIN] [VARCHAR](50) NULL,
	[sk_Dim_PG_Question] [INT] NULL,
	[Rpt_Prd] [VARCHAR](6) NULL,
	[Event_Date] [SMALLDATETIME] NULL,
	[Event_Date_Disch] [SMALLDATETIME] NULL,
	[quarter_name] [VARCHAR](7) NULL,
	[month_short_name] [VARCHAR](8) NULL,
	[Load_Dtm] [SMALLDATETIME] NULL
) ON [PRIMARY]
GO

ALTER TABLE [Rptg].[CHCAHPS_Response_Summary_Test] ADD  DEFAULT (GETDATE()) FOR [Load_Dtm]
GO

GRANT DELETE, INSERT, SELECT, UPDATE ON [Rptg].[CHCAHPS_Response_Summary_Test] TO [HSCDOM\Decision Support]
GO


