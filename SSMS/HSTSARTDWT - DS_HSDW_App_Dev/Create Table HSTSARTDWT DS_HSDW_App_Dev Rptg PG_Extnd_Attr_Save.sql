USE [DS_HSDW_App_Dev]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [Rptg].[PG_Extnd_Attr_Save](
	[sk_PG_Extend_Attr] [INT] IDENTITY(1,1) NOT NULL,
	[sk_Dim_PG_Question] [INT] NOT NULL,
	[QUESTION_TEXT] [VARCHAR](300) NOT NULL,
	[VARNAME] [VARCHAR](10) NOT NULL,
	[SVC_CODE] [VARCHAR](2) NOT NULL,
	[RESP_CAT] [VARCHAR](15) NOT NULL,
	[DOMAIN] [VARCHAR](100) NULL,
	[TOP_10] [INT] NULL,
	[TOP_BOX] [VARCHAR](100) NULL,
	[QUESTION_ORDER] [INT] NULL,
	[ETL_guid] [VARCHAR](38) NOT NULL,
	[Load_Dtm] [SMALLDATETIME] NOT NULL,
	[QUESTION_TEXT_ALIAS] [VARCHAR](300) NULL,
 CONSTRAINT [pk_PG_Extnd_Attr_Save] PRIMARY KEY CLUSTERED 
(
	[sk_PG_Extend_Attr] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]
GO


