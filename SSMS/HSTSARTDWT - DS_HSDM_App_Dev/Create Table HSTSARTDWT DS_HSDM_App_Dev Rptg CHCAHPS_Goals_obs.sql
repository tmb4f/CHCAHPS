USE [DS_HSDM_App_Dev]
GO

-- ===========================================
-- Create table Rptg.CHCAHPS_Goals_obs
-- ===========================================
IF EXISTS (SELECT TABLE_NAME 
	       FROM   INFORMATION_SCHEMA.TABLES
	       WHERE  TABLE_SCHEMA = N'Rptg' AND
	              TABLE_NAME = N'CHCAHPS_Goals_obs')
   DROP TABLE [Rptg].[CHCAHPS_Goals_obs]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Rptg].[CHCAHPS_Goals_obs](
	[SVC_CDE] [varchar](2) NULL,
	[GOAL_YR] [int] NULL,
	[SERVICE_LINE] [varchar](150) NULL,
	[UNIT] [varchar](150) NULL,
	[DOMAIN] [varchar](150) NULL,
	[GOAL] [decimal](4, 3) NULL
) ON [PRIMARY]
GO

GRANT DELETE, INSERT, SELECT, UPDATE ON [Rptg].[CHCAHPS_Goals_obs] TO [HSCDOM\Decision Support]
GO


