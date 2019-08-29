USE [BI_DB]
GO
/****** Object:  StoredProcedure [dbo].[SP_Verification_Allocations]    Script Date: 4/13/2019 6:36:17 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


ALTER PROCEDURE [dbo].[SP_Verification_Allocations]
AS
/********************************************************************************************
Author:      Guy Manova	
Date:        2018-03-18	
Description: a procedure to auto-allocate new verification cases to the different agent teams. should be run on HOURLY cycle, takes 1.5 minutes. 

**************************
** Change History
**************************
Date         Author       Description 

27.03.2018	Guy Manova		changed the logic of China allocations to only include Chinese speaking countries in Region "China"
27.03.2018	Guy Manova		added conditions for FTDs to also include VerificationLevel 3
28.03.2018	Guy Manova		added limitation of Verification 3 and FTDs to only include DateAdded > past 15 days (at bottom, populating final table)
23.04.2018  Guy Manova		added condition so after 16:00 Ukraine gets allocated nothing, KYC allocated instead
24.04.2018  Guy Manova		added condition so after Sun + Sat the previous condition doesnt apply
25.04.2018	Guy Manova		added new allocation status 'KYC_Afterhours' to distinguish between "true" kyc and ukraine off hours cases. 
10.05.2018	Guy Manova		changed the top of funnel joins to left joins, 6-7 CIDs were missing due to regular join
09.07.2018	Guy Manova		added "12" to the server hour to send files to KYC AfterHours instead of UKR
12.07.2018	Guy Manova		LabelID = 26 is now not excluded and in turn, goes to Cyprus
01.08.2018	Guy Manova		French region now by default will go to Cy not UKR
04.09.2018	Guy Manova		Added Israel logic to when IsDepositor is 1 (before was only when IsDepositor = 0)
13.09.2018	Guy Manova		****IMPORTANT CHANGE**** added RegulationID and planted it in the TotalScore column - this is to avoid data structure changes in GSheets, Tableau and the R scripts.
13.09.2018	Guy Manova		Added logic for FCA regulations to go to KYC instead of UKR
14.10.2018	Guy Manova		****IMPORTANT CHANGE**** switched from Regulation ID in Dim Customer to Designated Regulation ID in Backoffice Customer. 
01.11.2018	Guy Manova		Users requested to add Accountype <> to go to KYC always as part of the logic. 
05.11.2018	Guy Manova		update for winter clock times
17.11.2018	Guy Manova		added logic to allocate wallet users to KYC directly always.
27.11.2018	Guy Manova		added allocation to USA cases 
02.12.2018	Guy Manova		added rules to handoffs between USA to Cy in off hours
04.12.2018	Guy Manova		fixed rules to allocation to USA cases
04.12.2018	Guy Manova		changed a couple of joins to left joins - joins to DWH were eliminating some rows. 
04.12.2018  Guy Manova		added a paranthesis to the and/or conditions in the first query. 
05.12.2018	Guy Manova		changed the logic for initial population - to be regardless of FTD, on Panos request
10.12.2018	Guy Manova		logic for USA afterhours was faulty, fixed
11.12.2018	Guy Manova		replaced Dim_Customer with Backoffice Customer - was causing nulls in some columns.
27.12.2018	Guy Manova		Inputting Designated Regulation ID into TotalScore instead of RegulationID 
14.01.2019	Guy Manova		Added logic to consider higher prioritization for previously pulled data (returning) (*10 so keeps the original prefix, and indicates that has a prior date)
14.01.2019	Guy Manova		Another change to make it so the *10 priority will apply only to return pulls in last 48 hours
22.03.2019	Guy Manova		change in Ukraine shift times. 
04.04.2019	Guy Manova		tweak UKR times again, previous mistake fix 
13.04.2019	Guy Manova		tweak UKR times again, previous mistake fix 
----------    ----------   ------------------------------------*/

-- exec [dbo].[SP_Verification_Allocations]

IF OBJECT_ID('tempdb..#pop') IS NOT NULL
	DROP TABLE #pop

SELECT dc.CID AS RealCID,
	convert(DATE, a.FirstTimeDepositSuccessDate) AS FirstDepositDate,
	cc.RealizedEquity,
	cc.Registered,
	cc.SerialID,
	dc.RiskStatusID,
	rs.Name AS RiskStatus,
	cou.CountryID,
	cou.Name Country,
	dco.RiskGroupID,
	mr.Name AS Region,
	dc.VerificationLevelID,
	cc.PendingClosureStatusID,
	cc.PlayerStatusID,
	ps.Name AS PlayerStatus,
	cc.PlayerStatusReasonID,
	dc.EvMatchStatus,
	ec.Name AS EvStatus,
	CASE WHEN dc.DocumentStatusID = 1 THEN 1 ELSE 0 END AS NewUpload,
	CASE WHEN a.FirstTimeDepositSuccessDate IS NOT NULL THEN 1 ELSE 0 END AS IsDepositor, 
	case when cc.LabelID = 26 then 1 else 0 end as Label26
INTO #pop
FROM [ETL_Source].etoro_rep.BackOffice.Customer dc WITH (NOLOCK)
LEFT JOIN [ETL_Source].etoro_rep.Customer.Customer cc WITH (NOLOCK)
	ON dc.CID = cc.CID
LEFT JOIN [ETL_Source].etoro_rep.Dictionary.Country cou WITH (NOLOCK)
	ON cou.CountryID = cc.CountryID
LEFT JOIN [ETL_Source].etoro_rep.Dictionary.MarketingRegion mr WITH (NOLOCK)
	ON cou.MarketingRegionID = mr.MarketingRegionID
LEFT JOIN ETL_Source.etoro_rep.Dictionary.Country dco WITH (NOLOCK)
	ON cc.CountryID = dco.CountryID
LEFT JOIN [ETL_Source].etoro_rep.BackOffice.CustomerAllTimeAggregatedData a WITH (NOLOCK)
	ON dc.CID = a.CID
LEFT JOIN [ETL_Source].etoro_rep.Dictionary.PlayerStatus ps WITH (NOLOCK)
	ON cc.PlayerStatusID = ps.PlayerStatusID
LEFT JOIN [ETL_Source].etoro_rep.[Dictionary].[RiskStatus] rs WITH (NOLOCK)
	ON dc.RiskStatusID = rs.RiskStatusID
LEFT JOIN [ETL_Source].etoro_rep.[Dictionary].[ElectronicIdentityCheck] ec WITH (NOLOCK)
	ON dc.EvMatchStatus = ec.ElectronicIdentityCheckID
WHERE cc.PlayerLevelID <> 4 AND cc.LabelID NOT IN (30) AND cou.CountryID NOT IN (250,38)
		AND dc.VerificationLevelID in (2,3)
		--((dc.VerificationLevelID in (2,3) and a.FirstTimeDepositSuccessDate is not null) or (dc.VerificationLevelID =2 and a.FirstTimeDepositSuccessDate is null)) 
		and dc.DocumentStatusID = 1
        and dco.RiskGroupID not in (1,2) and cc.PlayerStatusID not in (2,4,6,8,14)




CREATE CLUSTERED COLUMNSTORE INDEX csindx_pop ON #pop

-- select * from #pop where RealCID = 10361643 
-- select * from ETL_Source.etoro_rep.BackOffice.Customer where CID  in (6592202,10302814,10303394,10306108)
-- select * from ETL_Source.etoro_rep.Customer.Customer where CID  in (6592202,10302814,10303394,10306108)

-- select * from ETL_Source.etoro_rep.Dictionary.PlayerStatus

/***********************************************************
has open cashouts
**********************************************************/

IF OBJECT_ID('tempdb..#openCO') IS NOT NULL
	DROP TABLE #openCO

SELECT CID,
	max(ModificationDate) AS Modified
INTO #openCO
FROM [ETL_Source].[etoro_rep].[Billing].[Withdraw] WITH (NOLOCK)
WHERE Approved = 0 AND CashoutStatusID = 1 -- = pending
GROUP BY CID

CREATE CLUSTERED COLUMNSTORE INDEX csindx_openCO ON #openCO

-- select * from #openCO

-- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate #openCO',SYSDATETIME(),@@rowcount

/***********************************************************
joined
**********************************************************/

IF OBJECT_ID('tempdb..#pop2') IS NOT NULL
	DROP TABLE #pop2

SELECT p.*,
	CASE WHEN oc.CID IS NOT NULL THEN 1 ELSE 0 END AS HasOpenCashout
INTO #pop2
FROM #pop p
LEFT JOIN #openCO oc
	ON p.RealCID = oc.CID

CREATE CLUSTERED COLUMNSTORE INDEX csindx_pop2 ON #pop2

-- select * from #pop2 where RealCID = 10361643 
-- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate #pop2',SYSDATETIME(),@@rowcount

/***********************************************************
DOC
**********************************************************/



IF OBJECT_ID('tempdb..#doc') IS NOT NULL
	DROP TABLE #doc

SELECT *
INTO #doc
FROM openquery(ETL_Source, 'SELECT CD.CID, CD.DateAdded, CD.SuggestedDocumentTypeID, CD.Comment, DT.DocumentTypeID, DT.RejectReasonID, DT.DocumentClassificationID, DT.Occurred
											FROM [etoro_rep].[BackOffice].[CustomerDocument] CD with (nolock)
										     LEFT JOIN [etoro_rep].[BackOffice].[CustomerDocumentToDocumentType] DT with (nolock)
											ON CD.DocumentID = DT.DocumentID AND DT.DocumentTypeID IN (1, 2)
											group by CD.CID, CD.DateAdded, CD.SuggestedDocumentTypeID, CD.Comment, DT.DocumentTypeID, DT.RejectReasonID, DT.DocumentClassificationID, DT.Occurred
											having max(DateAdded) >= convert(date,getdate()-180)'
											)

CREATE CLUSTERED COLUMNSTORE INDEX csindx_doc ON #doc


-- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate #doc',SYSDATETIME(),@@rowcount


/***********************************************************
documents
**********************************************************/


IF OBJECT_ID('tempdb..#doc2') IS NOT NULL
	DROP TABLE #doc2

SELECT c.*,
	MAX(CASE WHEN cd.SuggestedDocumentTypeID IN (1) THEN 1 ELSE 0 END) AS SuggestedPOA,
	MAX(CASE WHEN cd.SuggestedDocumentTypeID IN (2) THEN 1 ELSE 0 END) AS SuggestedPOI,
	MAX(CASE WHEN cd.DocumentTypeID IN (1) AND RejectReasonID IS NULL THEN 1 ELSE 0 END) AS ApprovedPOA,
	MAX(CASE WHEN cd.DocumentTypeID IN (2) AND RejectReasonID IS NULL THEN 1 ELSE 0 END) AS ApprovedPOI,
	Max(DateAdded) AS DateOfNewUpload
INTO #doc2
FROM #pop2 c
JOIN #doc cd
	ON c.RealCID = cd.CID
GROUP BY c.RealCID,
	c.Country,
	c.PlayerStatusID,
	c.PlayerStatus,
	c.VerificationLevelID,
	c.EvStatus,
	c.EvMatchStatus,
	c.FirstDepositDate,
	c.Registered,
	c.IsDepositor,
	c.HasOpenCashout,
	c.NewUpload,
	c.PlayerStatus,
	c.Region,
	c.RiskStatus,
	c.RiskStatusID,
	c.PendingClosureStatusID,
	c.PlayerStatusReasonID,
	c.RealizedEquity,
	c.RiskGroupID,
	c.CountryID,
	c.SerialID,
	c.Label26

CREATE CLUSTERED COLUMNSTORE INDEX csindx_doc2 ON #doc2

-- insert into #timelogs SELECT cast(datediff(second, @sysstart, SYSDATETIME()) AS VARCHAR) + ' to populate #doc2', SYSDATETIME(), @@rowcount

delete from #doc2 where IsDepositor = 0 and DateOfNewUpload < CONVERT(date, getdate() - 15)

-- select * from #doc2

/***********************************************************
documents final
**********************************************************/

IF OBJECT_ID('tempdb..#docFinal') IS NOT NULL
	DROP TABLE #docFinal

SELECT *,
	CASE WHEN SuggestedPOA + SuggestedPOI = 2 THEN 1 ELSE 0 END AS UploadedBoth,
	CASE WHEN ApprovedPOA + ApprovedPOI = 2 THEN 1 ELSE 0 END AS BothApproved
INTO #docFinal
FROM #doc2

CREATE CLUSTERED COLUMNSTORE INDEX csindx_docFinal ON #docFinal



-- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate #docFinal',SYSDATETIME(),@@rowcount


/***********************************************************
did CO
**********************************************************/

IF OBJECT_ID('tempdb..#didCO') IS NOT NULL
	DROP TABLE #didCO

SELECT d.*,
	CASE WHEN LastCO IS NOT NULL THEN 1 ELSE 0 END AS DidCO
INTO #didCO
FROM #docFinal d
LEFT JOIN 
	(SELECT CID,
		CashoutStatusID,
		max(ModificationDate) AS LastCO
	FROM ETL_Source.etoro_rep.Billing.Withdraw WITH (NOLOCK)
	GROUP BY CID,
		CashoutStatusID) bw
	ON d.RealCID = bw.CID AND bw.CashoutStatusID = 3

CREATE CLUSTERED COLUMNSTORE INDEX csindx_didCO ON #didCO

-- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate #didCO',SYSDATETIME(),@@rowcount

/***********************************************************
player and closure statuses and priorities
**********************************************************/

IF OBJECT_ID('tempdb..#priorities') IS NOT NULL  DROP TABLE #priorities
SELECT  d.* 
		,case when d.VerificationLevelID < 3 and DidCO = 1 and d.PendingClosureStatusID = 3 and 
				d.PlayerStatusID = 13 and d.PlayerStatusReasonID = 1 then 1 else 0 end as Closed,
		case when d.VerificationLevelID = 3 then 5 
				when (RealizedEquity >=2300 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 10) OR
					 (RealizedEquity between 1000 and 2300 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 4) OR
					 (RealizedEquity between 200 and 1000 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 3) OR
					 (RealizedEquity <=200 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 2) 
			then 1
				when (RealizedEquity >=2300 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 13) OR
					 (RealizedEquity between 1000 and 2300 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 11) OR
					 (RealizedEquity between 200 and 1000 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 7) OR
					 (RealizedEquity <=200 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 4) 
			then 2
				when (RealizedEquity >=2300 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 13) OR
					 (RealizedEquity between 1000 and 2300 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 12) OR
					 (RealizedEquity between 200 and 1000 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 8) OR
					 (RealizedEquity <=200 and 15-DATEDIFF(dd,d.FirstDepositDate ,getdate()) <= 0) 
			then 3
		ELSE 4 end as Priority,
		bc.DesignatedRegulationID,
		dr.Name as RegulationName
into #priorities 
 FROM #didCO d 
--  LEFT join DWH.dbo.Dim_Customer dc with (NOLOCK)
--  on d.RealCID = dc.RealCID
  LEFT join ETL_Source.etoro_rep.BackOffice.Customer bc 
  on d.RealCID = bc.CID
  LEFT join DWH.dbo.Dim_Regulation dr 
  on bc.DesignatedRegulationID = dr.DWHRegulationID

-- select * from #didCO where RealCID = 10361643 
-- select * from #priorities
-- select top 10 * from ETL_Source.etoro_rep.BackOffice.Customer  where CID = 10313742
-- select * from DWH.dbo.Dim_Regulation

CREATE CLUSTERED COLUMNSTORE INDEX csindx_priorities ON #priorities

-- select * from #priorities where RegulationName = 'FCA'

-- select distinct RegulationName from #priorities

 -- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate #priorities',SYSDATETIME(),@@rowcount

 /************************************************************
		Rules of allocation
************************************************************/

IF OBJECT_ID('tempdb..#allocations') IS NOT NULL  DROP TABLE #allocations

select p.RealCID, p.FirstDepositDate ,p.RealizedEquity,p.Registered,p.SerialID,p.RiskStatusID,p.RiskStatus,p.CountryID,p.Country
	 ,p.RiskGroupID,p.Region,p.VerificationLevelID,p.PendingClosureStatusID,p.PlayerStatusID
	,p.PlayerStatus,p.PlayerStatusReasonID,p.EvMatchStatus,p.EvStatus,p.NewUpload,p.IsDepositor,p.Label26,p.HasOpenCashout
	,p.SuggestedPOA,p.SuggestedPOI,p.ApprovedPOA,p.ApprovedPOI,p.DateOfNewUpload,p.UploadedBoth
	,p.BothApproved,p.DidCO,p.Closed,p.Priority, dc.AccountTypeID,
		case when p.RealCID in (select distinct CID from BI_DEV.dbo.Wallet_User_Logins_Backlog) 
			 then 'KYC-WalletUser' 
			-- when p.CountryID = 219 then 'USA'
			when p.IsDepositor = 1 
			  then
				 (case 	when p.RegulationName = 'FCA' 
						then 'KYC'
						WHEN dc.AccountTypeID <> 1
						THEN 'KYC'
						when Label26 = 1 
						then 'KYC-Label26'
						when p.RiskStatusID in (1,10,36) -- "Normal" OR  AffiliateMultipleAccounts" OR “MultipleAccountsPerPrimaryPayPalEmail”
						  and p.PlayerStatusID in (1, 13, 5) -- "Normal" OR Pending Verification" OR “ Warning"	
						  and p.Region = 'China' 
						  and p.Country in ('China', 'Hong Kong', 'Macau', 'Taiwan')
						  then 'China'
				 		when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 
				 		  and p.Region = 'Israel' 
						  then 'Israel'		 
						when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 	
				 		  and p.Region = 'USA'
						  and datepart(hour,getdate()) between 13 and 21 and datepart(DW,getdate()) in (2,3,4,5,6) --mon-fri after 9 to 5 Eastern - US, otherwise Cy 
						  then 'USA'
				   	    when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 	
				 		  and p.Region != 'China'
						  and p.Region != 'French'
						  AND p.Region != 'USA'
						  and ((datepart(hour,getdate()) between 7 and 15 and datepart(DW,getdate()) in (2,3,4,5,6,7)) --mon-fri after 3, Ukraine becomes KYC. rest of time - Ukr select datepart(hour,getdate())
								OR (datepart(hour,getdate()) between 8 and 15 and  datepart(DW,getdate()) in (1)))  
						  then 'Ukraine' 
						when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 	
				 		  and p.Region = 'USA'
						  and datepart(hour,getdate()) in (22,23,0,1,2,3,4,5,6,7,8,9,10,11,12) and datepart(DW,getdate()) in (2,3,4,5,6) 
						  then 'KYC_Afterhours(US)' 
						when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 	
				 		  and p.Region != 'China'
						  and (datepart(hour,getdate()) in (5,6,16,17,18,19,20,21,22) and datepart(DW,getdate()) in (2,3,4,5,6))  OR datepart(DW,getdate()) in (1,7)
						  then 'KYC_Afterhours' 
					Else 'KYC' end)
			 when p.IsDepositor = 0 
			 then 
				 (case 	when p.RegulationName = 'FCA' 
						then 'KYC'
						WHEN dc.AccountTypeID <> 1
						THEN 'KYC'
						when p.Label26 = 1 
						then 'KYC-Label26'
						when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 	
				 		  and p.Region = 'China' 
						  and p.Country in ('China', 'Hong Kong', 'Macau', 'Taiwan')
						  then 'China'	 
				 		when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 
				 		  and p.Region = 'Israel' 
						  then 'Israel'
						when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 	
				 		  and p.Region = 'USA'
						  and datepart(hour,getdate()) between 13 and 21 and datepart(DW,getdate()) in (2,3,4,5,6) --mon-fri after 9 to 5 Eastern - US, otherwise Cy
						  then 'USA'
						when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 	
				 		  and p.Region != 'China' 
						  and p.Region != 'French'
						  AND p.Region != 'USA'
						  and ((datepart(hour,getdate()) between 7 and 15 and datepart(DW,getdate()) in (2,3,4,5,6,7)) --mon-fri after 3, Ukraine becomes KYC. rest of time - Ukr select datepart(hour,getdate())
								OR (datepart(hour,getdate()) between 8 and 15 and  datepart(DW,getdate()) in (1)))  
				 		  then 'Ukraine'
						when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 	
				 		  and p.Region = 'USA'
						  and (datepart(hour,getdate()) in (22,23,0,1,2,3,4,5,6,7,8,9,10,11,12) and datepart(DW,getdate()) in (2,3,4,5,6)) OR datepart(DW,getdate()) in (1,7)
						  then 'KYC_Afterhours(US)' 
						when p.RiskStatusID in (1,10,36) 
				 		  and p.PlayerStatusID in (1, 13, 5) 	
				 		  and p.Region != 'China'
						  and datepart(hour,getdate()) in (5,6,16,17,18,19,20,21,22) and datepart(DW,getdate()) in (2,3,4,5,6) 
						  then 'KYC_Afterhours' 
						else 'KYC' end)
				end as AllocateTo,
			p.DesignatedRegulationID
into #allocations
from
#priorities p
LEFT JOIN ETL_Source.etoro_rep.BackOffice.Customer dc With (NOLOCK)
	ON p.RealCID = dc.CID

-- select * from #allocations

CREATE CLUSTERED COLUMNSTORE INDEX csindx_allocations ON #allocations

 -- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate #allocations',SYSDATETIME(),@@rowcount
 -- select * from #allocations where [AllocateTo] = 'KYC-WalletUser'

/*****************************************************************
		Score Data for additional prioritization
*****************************************************************/
IF OBJECT_ID('tempdb..#Countries') IS NOT NULL  DROP TABLE #Countries

 create table #Countries (CountryID int, Score int)
 insert into #Countries values (183,5)
 ,(154,5),(93,5),(119,5),(197,5),(54,5),(146,5),(126,5),(19,5),(217,5),(208,5),(218,5),(143,5),(12,5),(55,5),(79,5),(184,5),(185,5),(196,5),(38,5)
,(72,5),(102,5),(191,5),(13,5),(57,5),(199,5),(100,5),(106,5),(118,3),(112,3),(52,3),(15,3),(74,3),(167,3),(237,3),(165,3),(130,3),(51,3),(82,3),(43,3)
,(67,3),(44,3),(168,3),(136,3),(164,3),(124,3),(32,3),(0,3),(9,3),(132,3),(101,3),(158,3),(103,3),(192,3),(202,3),(169,3),(190,3),(161,3),(92,3),(64,3)
,(109,3),(155,3),(179,3),(123,3),(188,3),(105,3),(134,1),(216,1),(221,1),(140,1),(10,1),(113,1),(94,1),(31,1),(28,1),(36,1),(73,1),(24,1),(47,1),(80,1)
,(235,1),(62,1),(60,1),(21,1),(2,1),(87,1),(226,1),(107,1),(97,1),(78,1),(14,1),(18,1),(26,1),(156,1),(162,1),(138,1),(225,0),(160,0),(180,0),(231,0)
,(25,0),(35,0),(37,0),(63,0),(201,0),(16,0),(96,0),(229,0),(209,0),(149,0),(116,0),(215,0),(3,0),(99,0),(234,0),(210,0),(104,0),(193,0),(198,0),(98,0)
,(219,0),(232,0),(243,0),(89,0),(7,0),(81,0),(178,0),(233,0),(65,0),(40,0),(133,0),(5,0),(242,0),(135,0),(22,0),(69,0),(153,0),(95,0),(49,0),(117,0),(204,0)
,(131,0),(246,0),(245,0),(84,0),(85,0),(211,0),(139,0),(241,0),(244,0),(128,0),(6,0),(75,0),(145,0),(17,0),(238,0),(203,0),(236,0),(30,0),(249,0),(176,0)
,(170,0),(120,0),(83,0),(77,0),(8,0),(174,0),(88,0),(141,0),(56,0),(11,0),(147,0),(205,0),(230,0),(222,0),(111,0),(181,0),(159,0),(33,0),(68,0),(110,0)
,(194,0),(187,0),(91,0),(1,0),(121,0),(129,0),(90,0),(227,0),(224,0),(23,0),(50,0),(61,0),(70,0),(71,0),(108,0),(157,0),(220,0),(186,0),(214,0),(223,0)
,(34,0),(39,0),(41,0),(48,0),(58,0),(114,0),(115,0),(122,0),(125,0),(148,0),(182,0),(195,0),(200,0),(20,0),(53,0),(59,0),(173,0),(248,0),(171,0),(86,0),(166,0)
,(76,0),(27,0),(175,0),(239,0),(29,0),(66,0),(212,0),(228,0),(127,0),(142,0),(144,0),(213,0),(189,0),(42,0),(250,0),(4,0)

--********************** logins ********************--

IF OBJECT_ID('tempdb..#Logins') IS NOT NULL  DROP TABLE #Logins

select RealCid as CID, count(1) as Logins
into #Logins
from ETL_Source.[STS_rep].Audit.LoginHistory_Active  with (nolock)
where LoggedInOn >= cast(dateadd(day,-14,getdate()) as date)
group by RealCid

CREATE CLUSTERED COLUMNSTORE INDEX csindx_Logins ON #Logins

 -- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate #Logins',SYSDATETIME(),@@rowcount

 --********************** scores ********************--
IF OBJECT_ID('tempdb..#Scores') IS NOT NULL  DROP TABLE #Scores

SELECT a.*,
	isnull(L.Logins, 0) AS LastTwoWeeksLogins,
	isnull(C.Score, 0) AS CountryScore,
	CASE WHEN FD.MarketingExpenseID IN (1, 7, 8, 10, 11) THEN 0 ELSE 2 END AS ChannelScore,
	CASE WHEN a.DateOfNewUpload >= cast(dateadd(day, - 1, getdate()) AS DATE) THEN 4 WHEN a.DateOfNewUpload >= cast(dateadd(day, - 7, getdate()) AS DATE) THEN 3 WHEN a.DateOfNewUpload >= cast(dateadd(day, - 14, getdate()) AS DATE) THEN 1 ELSE 0 END AS DocUploadedScore,
	CASE WHEN L.Logins >= 30 THEN 4 WHEN L.Logins >= 10 THEN 3 WHEN L.Logins >= 1 THEN 1 ELSE 0 END AS EngagementScore
INTO #Scores
FROM #allocations a WITH (NOLOCK)
LEFT JOIN #Countries C WITH (NOLOCK)
	ON a.CountryID = C.CountryID
LEFT JOIN ETL_Source.[fiktivo_rep].[dbo].[tblaff_Affiliates] FD WITH (NOLOCK)
	ON a.SerialID = FD.AffiliateID
LEFT JOIN #Logins L WITH (NOLOCK)
	ON a.RealCID = L.CID

CREATE CLUSTERED COLUMNSTORE INDEX csindx_Scores ON #Scores

-- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate #Scores',SYSDATETIME(),@@rowcount
-- select * from #Scores

 --****** final table ******************--
 
IF OBJECT_ID('tempdb..#finalscores') IS NOT NULL
	DROP TABLE #finalscores

SELECT convert(date, getdate()) as PullDate, 
	a.*,
	CASE WHEN a.RiskGroupID IN (1, 2) THEN 0 ELSE a.CountryScore + a.ChannelScore + a.DocUploadedScore + a.EngagementScore END AS TotalScore, 
	getdate() as UpdateDate
INTO #finalscores
FROM #Scores a
LEFT join ETL_Source.etoro_rep.BackOffice.Customer dc with (NOLOCK)
	on a.RealCID = dc.CID
where (a.IsDepositor = 1 and a.VerificationLevelID = 3 and a.DateOfNewUpload >= convert(date,getdate()-15))
		OR
	  (a.IsDepositor = 1 and a.VerificationLevelID = 2)
		OR
	  a.IsDepositor = 0 

-- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate #finalscores',SYSDATETIME(),@@rowcount
-- select * from #finalscores
-- select * from #Scores

DROP TABLE IF EXISTS #prepFinal

; WITH "previous" AS 
(
SELECT vaa.RealCID, vaa.PullDate, vaa.Outcome, DENSE_RANK() OVER (PARTITION BY RealCID ORDER BY vaa.PullDate DESC) AS Rank
 FROM BI_DEV.dbo.Verifications_Allocations_Archive vaa 
  )
SELECT f.*, pr.PullDate AS PullDate1, pr2.PullDate AS PullDate2,
		CASE WHEN pr.PullDate >= CONVERT(DATE, GETDATE()-2) OR pr2.PullDate >= CONVERT(DATE, GETDATE()-2)
			THEN f.Priority * 10 ELSE f.Priority END AS Priority2
INTO #prepFinal
FROM #finalscores f
	LEFT JOIN (SELECT pr.RealCID, MIN(pr.PullDate) AS PullDate  FROM "previous" pr WHERE pr.Rank = 1 GROUP BY pr.RealCID) pr
		ON f.RealCID = pr.RealCID 
	LEFT JOIN (SELECT pr.RealCID, MIN(pr.PullDate) AS PullDate  FROM "previous" pr WHERE pr.Rank = 2 GROUP BY pr.RealCID) pr2
		ON f.RealCID = pr2.RealCID 

-- select * from #prepFinal

DROP TABLE If EXISTS #finalscores2

SELECT f.PullDate, f.RealCID, f.FirstDepositDate, f.RealizedEquity, f.Registered, f.SerialID, 
	f.RiskStatusID, f.RiskStatus, f.CountryID, f.Country, f.RiskGroupID, f.Region, f.VerificationLevelID,
	 f.PendingClosureStatusID, f.PlayerStatusID, f.PlayerStatus, f.PlayerStatusReasonID, f.EvMatchStatus, 
	 f.EvStatus, f.NewUpload, f.IsDepositor, f.Label26, f.HasOpenCashout, f.SuggestedPOA, f.SuggestedPOI, 
	 f.ApprovedPOA, f.ApprovedPOI, f.DateOfNewUpload, f.UploadedBoth, f.BothApproved, f.DidCO, f.Closed, 
	 f.Priority2 AS Priority, f.AccountTypeID, f.AllocateTo, f.DesignatedRegulationID, f.LastTwoWeeksLogins, 
	 f.CountryScore, f.ChannelScore, f.DocUploadedScore, f.EngagementScore, f.TotalScore, f.UpdateDate
INTO #finalscores2
FROM #prepFinal f

--SELECT * FROM #finalscores f
--SELECT * FROM #finalscores2 f

------------------ truncate and repopulate------------------------

truncate table dbo.BI_DB_VerificationsAllocations
INSERT INTO dbo.BI_DB_VerificationsAllocations
SELECT PullDate
		,RealCID
		,FirstDepositDate
		,RealizedEquity
		,Registered
		,SerialID
		,RiskStatusID
		,RiskStatus
		,CountryID
		,Country
		,RiskGroupID
		,Region
		,VerificationLevelID
		,PendingClosureStatusID
		,PlayerStatusID
		,PlayerStatus
		,PlayerStatusReasonID
		,EvMatchStatus
		,EvStatus
		,NewUpload
		,IsDepositor
		,HasOpenCashout
		,SuggestedPOA
		,SuggestedPOI
		,ApprovedPOA
		,ApprovedPOI
		,DateOfNewUpload
		,UploadedBoth
		,BothApproved
		,DidCO
		,Closed
		,Priority
		,AllocateTo
		,LastTwoWeeksLogins
		,CountryScore
		,ChannelScore
		,DocUploadedScore
		,EngagementScore
		,DesignatedRegulationID as TotalScore --- this is a late change adding a more relevant metric without changing the Tableau, googlesheet and R Script data structure
		,UpdateDate
 FROM #finalscores2

-- insert into #timelogs select cast(datediff(second,@sysstart,SYSDATETIME()) as varchar) + ' to populate dbo.DS_Verifications_Allocations',SYSDATETIME(),@@rowcount






