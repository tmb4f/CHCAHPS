USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

IF EXISTS (SELECT 1 
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_SCHEMA='Rptg'
    AND TABLE_TYPE='BASE TABLE' 
    AND TABLE_NAME='CHCAHPS_Response_Summary')
   DROP TABLE Rptg.CHCAHPS_Response_Summary
GO

CREATE TABLE [Rptg].[CHCAHPS_Response_Summary](
	[SERVICE_LINE] [VARCHAR](500) NULL,
	[CLINIC] [VARCHAR](500) NULL,
	[EPIC_DEPARTMENT_ID] [VARCHAR](500) NULL,
	[DOMAIN] [varchar](50) NULL,
	[sk_Dim_PG_Question] [INTEGER] NULL,
	[Rpt_Prd] [varchar](6) NULL,
	[Event_Date] [SMALLDATETIME] NULL,
	[Event_Date_Disch] [SMALLDATETIME] NULL,
	[quarter_name] [varchar](7) NULL,
	[month_short_name] [varchar](8) NULL,
	[Load_Dtm] [SMALLDATETIME] NULL
) ON [PRIMARY]
GO

ALTER TABLE [Rptg].[CHCAHPS_Response_Summary] ADD  DEFAULT (GETDATE()) FOR [Load_Dtm]
GO



