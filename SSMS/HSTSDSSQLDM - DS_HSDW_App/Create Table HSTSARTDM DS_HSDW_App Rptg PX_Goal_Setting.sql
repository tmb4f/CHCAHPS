USE [DS_HSDW_App]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Rptg].[PX_Goal_Setting](
	[Service] [varchar](7) NOT NULL,
	[Epic_Department_Id] [varchar](8) NULL,
	[Epic_Department_Name] [varchar](30) NULL,
	[GOAL_YR] [int] NULL,
	[SERVICE_LINE] [varchar](150) NULL,
	[UNIT] [varchar](150) NULL,
	[DOMAIN] [varchar](150) NULL,
	[GOAL] [decimal](4, 3) NULL
) ON [PRIMARY]
GO


