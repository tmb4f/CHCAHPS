USE [DS_HSDW_App_Dev]
GO

IF EXISTS (SELECT 1 
    FROM INFORMATION_SCHEMA.TABLES 
    WHERE TABLE_SCHEMA='Rptg'
    AND TABLE_TYPE='BASE TABLE' 
    AND TABLE_NAME='CHCAHPS_Ranks')
   DROP TABLE Rptg.CHCAHPS_Ranks
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Rptg].[CHCAHPS_Ranks](
	[VALUE] [numeric](4, 1) NULL,
	[DOMAIN] [varchar](50) NULL,
	[SK_DIM_PG_QUESTION] [varchar](25) NULL,
	[PERCENTILE_RANK] [int] NULL,
	[RPT_PRD_BGN] [date] NULL,
	[RPT_PRD_END] [date] NULL,
	[QUESTION_TEXT_ALIAS] [varchar](250) NULL
) ON [PRIMARY]
GO


