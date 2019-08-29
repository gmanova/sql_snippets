USE [BI_DB]
GO
/****** Object:  StoredProcedure [dbo].[SP_AML_Alerts]    Script Date: 8/26/2019 7:07:42 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
      
      
ALTER   PROCEDURE [dbo].[SP_AML_Alerts] @sdate date ---(yesterday)      
AS      
/********************************************************************************************      
Author:      Guy Manova       
Date:        2019-04-21       
Description: This proc generates alerts for AML issues, and runs them against history of past alerts to eliminate raising same alert twice for same user. the output table AMK_Daily_Alerts should be sent      
   via SSIS to AML officers of the company.       
      
**************************      
** Change History      
**************************      
Date         Author       Description       
      
05.05.2019  Guy Manova  added 2 more alert types      
21.05.2019  Guy Manova  commented out: WHERE h.PreviousStatus <> 'Done' OR h.PreviousStatus IS null in the population of alerts table, users want to see all alerts.       
21.05.2019  Guy Manova  exclude BVI from final results      
23.05.2019  Guy Manova  bug fix - i left a getdate()-3 in the code where it should be getdate()-1      
26.05.2019  Guy Manova  bug fix - taking only approved deposits. also taking from fact customer action, faster.       
20.06.2019  Guy Manova  introduced some changes requested by the users after first iteration of usage      
22.07.2019  Guy Manova  substancial changes: adding compensations, lifetime deposits, Income source to all alerts, PEP status, EV Match and docs statuses, fixed underlying data in BI DB tables       
--          so verification date is correct and KYC updates are correct.   
29.07.2019  Guy Manova	made rule changes in accordance with user request on googlesheets 
13.08.2019	Guy Manova	tweaked rules OB7 OB6 OB8 with Stalo's requirements  
14.08.2019	Guy Manova	Bug fix - need () in conditions for High Risk Occupation alert
15.08.2019	Guy Manova	small fix - dont trigger EU bin country mismatch when bin country not available
28.08.2019	Guy Manova	new rules and rule tweaks for DC14 and OB12 (valid credit cards, FINRA)
      
----------    ----------   ------------------------------------*/      
      
begin      
-- exec [dbo].[SP_AML_Alerts] '20190518'      
      
      
--------- bring in credit cards per user from rep -------------      
      
--drop table if exists #cards      
      
-- select *      
-- into #cards      
-- from openquery(ETL_Source, 'SELECT bd.CID, COUNT(DISTINCT bf.SecuredCardData ) AS CountCards, COUNT(DISTINCT bf.FundingTypeID) AS CountOfMOPs      
--  FROM  [etoro_rep].Billing.Deposit bd      
--  JOIN [etoro_rep].Billing.Funding bf      
--  ON bd.FundingID = bf.FundingID      
--  AND bd.PaymentStatusID = 2      
--GROUP BY bd.CID')      
      
DROP TABLE IF EXISTS #cards      
      
SELECT fbd.CID      
 , COUNT(DISTINCT CASE when DATEADD(MONTH,1,DATEFROMPARTS(LEFT(ExpirationDateID,4), RIGHT(ExpirationDateID,2), 1)) >= GETDATE() THEN fbd.SecuredCardDataAsString end) AS CountCards      
 , COUNT(DISTINCT fbd.FundingTypeID) AS CountOfMOPs       
INTO #cards      
FROM DWH..Fact_BillingDeposit fbd      
WHERE fbd.PaymentStatusID = 2 --AND CID = 7457307      
GROUP BY fbd.CID      
ORDER BY 2 DESC      
  
 
      
--SELECT TOP 10000 fbd.DepositID, fbd.CID, fbd.FundingID, fbd.BinCodeAsString, fbd.FundingTypeID       
--FROM DWH..Fact_BillingDeposit fbd ORDER BY fbd.ModificationDateID desc      
      
      
      
DROP TABLE IF EXISTS #cards1      
SELECT DISTINCT fbd.CID, fbd.SecuredCardDataAsString, fbd.ExpirationDateID--, DATEADD(MONTH,1,DATEFROMPARTS(LEFT(ExpirationDateID,4), RIGHT(ExpirationDateID,2), 1)) AS ExpirationDate      
 INTO #cards1      
 FROM DWH..Fact_BillingDeposit fbd      
 WHERE fbd.SecuredCardDataAsString IS NOT NULL      
   
 --  select distinct SecuredCardDataAsString, ExpirationDateID from #cards1 where CID = 1137999 order by 2 desc
 -- select sum(Amount) from DWH..Fact_CustomerAction where RealCID = 1137999 and ActionTypeID = 7
      
 DROP TABLE IF EXISTS #cards2      
 SELECT  CID, COUNT(SecuredCardDataAsString) AS CountCards      
 INTO #cards2      
 FROM #cards1      
 WHERE cast(year(getdate())*100 + month(getdate()) as int) <= cast(ExpirationDateID as int)
 GROUP BY CID     
 having COUNT(DISTINCT SecuredCardDataAsString) >= 2 

 -- select * from #cards2 where CID = 1137999

 CREATE CLUSTERED INDEX #cards2
ON #cards2 (
	CID ASC
)
      
 --SELECT  * FROM #cards1 c where CID = 7793178 ORDER BY 3 DESC   
 --SELECT TOP 100 * FROM #cards2 c where CID = 7793178 ORDER BY 2 DESC      
 --SELECT DISTINCT fbd.SecuredCardDataAsString, fbd.ExpirationDateID FROM DWH..Fact_BillingDeposit fbd WHERE CID = 9040383 AND fbd.FundingTypeID = 1 ORDER BY fbd.ExpirationDateID desc      
      
declare @sdate date = CAST(GETDATE() - 1 as date)      
declare @sdateID int = CAST(CONVERT(varchar(8), @sdate, 112) as int)      
      
-- create unique nonclustered index #ix_cards_CID on #cards (CID asc) INCLUDE (CountCards)      
      
-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate #cards'      
      
      
      
-- select top 10 * from #cards      
--------------------------------------------------------------------------------------------------      
-----------------  MIMO - deposits ---------------------------------------------------------------      
--------------------------------------------------------------------------------------------------      
      
DROP TABLE IF EXISTS #TotalDeposits6Months      
      
SELECT      
 RealCID AS CID      
   ,SUM(Amount) AS TotalDeposits6Months       
INTO #TotalDeposits6Months      
FROM DWH..Fact_CustomerAction fca with (NOLOCK)      
WHERE fca.ActionTypeID = 7      
 AND DateID >= CAST(CONVERT(VARCHAR(8), DATEADD(MONTH, -6, GETDATE()), 112) AS INT)      
GROUP BY RealCID      
      
DROP TABLE IF EXISTS #TotalDeposits12Months      
      
SELECT      
 RealCID AS CID      
   ,SUM(Amount) AS TotalDeposits12Months       
INTO #TotalDeposits12Months      
FROM DWH..Fact_CustomerAction fca with (NOLOCK)      
WHERE fca.ActionTypeID = 7      
 AND DateID >= CAST(CONVERT(VARCHAR(8), DATEADD(MONTH, -12, GETDATE()), 112) AS INT)      
GROUP BY RealCID      
      
DROP TABLE IF EXISTS #TotalDepositsLifetime      
      
SELECT      
 RealCID AS CID      
   ,SUM(Amount) AS TotalDepositsLifetime      
INTO #TotalDepositsLifetime      
FROM DWH..Fact_CustomerAction fca with (NOLOCK)      
WHERE fca.ActionTypeID = 7      
GROUP BY RealCID      
      
DROP TABLE IF EXISTS #TotalCompsLifetime      
      
SELECT      
 RealCID AS CID      
   ,SUM(Amount) AS TotalCompensationsLifetime      
INTO #TotalCompsLifetime      
FROM DWH..Fact_CustomerAction fca with (NOLOCK)      
WHERE fca.ActionTypeID = 36      
GROUP BY RealCID    

---- take only deposits of credit cards not CURRENTLY expired -----

drop table if exists #validCardDep

SELECT bd.*
into #validCardDep
from DWH..Fact_BillingDeposit bd
	join #cards2 c2
		on bd.CID = c2.CID 
where PaymentStatusID = 2
and cast(ExpirationDateID as int) >= cast(year(getdate())*100 + month(getdate()) as int) 

-- SELECT * FROM #validCardDep WHERE CID = 1137999

drop table if exists #AllCardDep

SELECT bd.*
into #AllCardDep
from DWH..Fact_BillingDeposit bd
	join #cards2 c2
		on bd.CID = c2.CID 
where PaymentStatusID = 2
 

-- select top 10 * from #validCardDep

---- sum up lifetime deposits only on currently valid CC -----

drop table if exists #validCardDepPrep

SELECT
CID,
count(DISTINCT CAST(SecuredCardDataAsString AS VARCHAR(1000)) + CAST(cd.ExpirationDateID AS VARCHAR(1000))) as CountCards 
into #validCardDepPrep 
FROM #validCardDep cd
group by CID

DROP TABLE IF EXISTS #allCardDepPrep

SELECT
CID,
 sum(Amount * ExchangeRate) as TotalDepositsValidCreditCards
into #allCardDepPrep  
FROM #AllCardDep acd
group by CID
      
drop table if exists #validCardDep1

SELECT v.CID, v.CountCards, a.TotalDepositsValidCreditCards
INTO #validCardDep1
FROM #validCardDepPrep v
	JOIN #allCardDepPrep a
		ON a.CID = v.CID


-- select * from #validCardDep1 where CID = 1137999

-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate #TotalDeposits12Months + 6Months'      
   
--declare @sdate date = CAST(GETDATE() - 1 as date)      
--declare @sdateID int = CAST(CONVERT(varchar(8), @sdate, 112) as int) 
     
drop table if exists #Dailydepositors      
      
 select bd.CID      
  , bd.FundingType      
  , bd.Provider      
  , bd.BINCountry      
  , bd.[Country (customer)]      
  , bd.CardType      
  , bd.[Country By Reg IP]      
  , bd.[Deposit Risk Status]      
  , bd.RiskStatus      
  , bd.[Bank name by Bincode]      
  , bd.Regulation      
  , bd.DesignatedRegulation      
  , lt.TotalDepositsLifetime      
  , b.TotalDeposits6Months      
  , c.TotalDeposits12Months      
  , SUM(bd.[Amount in $]) as TotalDepositDaily      
  , (      
   select MAX(case       
      when IsFTD = 1      
       then FundingType      
      else null      
      end)      
   from BI_DB_AllDeposits      
   where CID = bd.CID      
   group by CID      
   ) as FTD_FundingType      
  , c2.CountCards      
  , NULL as CountOfMOPs      
  , tcl.TotalCompensationsLifetime
  , vc.TotalDepositsValidCreditCards   
 into #Dailydepositors      
 from BI_DB_AllDeposits bd with (NOLOCK)       
 left join #TotalDeposits6Months b on bd.CID = b.CID      
 left join #TotalDeposits12Months c on bd.CID = c.CID      
 left join #TotalDepositsLifetime lt on bd.CID = lt.CID      
 LEFT JOIN #TotalCompsLifetime tcl ON bd.CID = tcl.CID      
 left join #validCardDep1 vc on bd.CID = vc.CID
 left join #cards2 c2 on bd.CID = c2.CID
 where bd.ModificationDateID = @sdateID      
  AND bd.PaymentStatus = 'Approved'      
 group by bd.CID      
  , bd.FundingType      
  , bd.Provider      
  , bd.BINCountry      
  , bd.[Country (customer)]      
  , bd.CardType      
  , bd.[Country By Reg IP]      
  , bd.[Deposit Risk Status]      
  , bd.RiskStatus      
  , bd.[Bank name by Bincode]      
  , bd.Regulation      
  , bd.DesignatedRegulation      
  , b.TotalDeposits6Months      
  , c.TotalDeposits12Months      
  , c2.CountCards    
  , lt.TotalDepositsLifetime      
  , tcl.TotalCompensationsLifetime
  , vc.TotalDepositsValidCreditCards      
      
-- select * from #Dailydepositors      
      
--------------------------------------------------------------------------------------------------      
-----------------  MIMO - Cashouts ---------------------------------------------------------------      
--------------------------------------------------------------------------------------------------      
--declare @sdate date = CAST(GETDATE() - 1 as date)      
--declare @sdateID int = CAST(CONVERT(varchar(8), @sdate, 112) as int)      
      
drop TABLE if exists #wtf      
      
 select *      
 into #wtf      
 from openquery(ETL_Source, '      
  select  wtf.WithdrawID, bw.CID, wtf.FundingID, wtf.CashoutStatusID, wtf.ProcessCurrencyID, wtf.ExchangeRate, wtf.Amount, wtf.ModificationDate      
   , CAST(wtf.WithdrawData AS NVARCHAR(MAX)) AS WithdrawData, wtf.DepotID, cast(bf.FundingData as nvarchar(max)) as FundingData, bf.FundingTypeID as BFFundingTypeID      
  FROM [etoro_rep].[Billing].[Withdraw] bw      
   join       
  [etoro_rep].[Billing].[WithdrawToFunding] wtf      
   on bw.WithdrawID = wtf.WithdrawID      
  left join etoro_rep.Billing.Funding bf      
   on wtf.FundingID = bf.FundingID      
  where cast(wtf.ModificationDate as Date) >= cast(getdate()-3 as date)      
  ')      
      
DROP TABLE IF EXISTS #wtf1      
      
SELECT       
 fbw.WithdrawID      
   ,fbw.CID      
   ,fbw.FundingID      
   ,fbw.CashoutStatusID_Funding CashoutStatusID      
   ,fbw.ProcessCurrencyID      
   ,fbw.ExchangeRate      
   ,fbw.Amount_WithdrawToFunding Amount      
   ,fbw.ModificationDate_WithdrawToFunding ModificationDate      
   ,fbw.DepotID      
   ,fbw.SecuredCardDataAsString      
   ,fbw.BinCodeAsString      
   ,fbw.BinCountryIDAsInteger      
   ,fbw.CardTypeIDAsInteger      
   ,fbw.ExpirationDateID      
   ,fbw.FundingTypeID_Funding BFFundingTypeID      
INTO #wtf1      
FROM DWH..Fact_BillingWithdraw fbw      
WHERE fbw.ModificationDate_WithdrawToFunding >= cast(getdate()-3 as date)      
      
------------- late addition - checking for new KYC answers from yesterday and adding to MIMOCID (even though it's not MIMO) ------------------      
      
-- DECLARE @sdate DATE = CAST(GETDATE()-1 AS DATE)      
      
DROP TABLE IF EXISTS #newkyc      
      
SELECT DISTINCT dc.RealCID      
INTO #newkyc      
FROM ETL_Source.UserApiDB_rep.History.CustomerAnswers ca      
 JOIN DWH..Dim_Customer dc      
  ON ca.GCID = dc.GCID      
WHERE ca.OccurredAt >= @sdate      
      
-- select * from #newkyc      
      
---------------------------------------------------------------------------------------------------      
----------- interim step inserted - getting complete CID list of ALL MIMO (not just depositors) ---      
---------------------------------------------------------------------------------------------------      
      
DROP TABLE IF EXISTS #mimoCIDs      
      
SELECT d.CID       
INTO #mimoCIDs      
FROM #Dailydepositors d      
UNION       
SELECT CID FROM #wtf1 w      
UNION       
SELECT RealCID FROM #newkyc n      
      
-- select * from #mimoCIDs      
      
-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate  #Dailydepositors'      
      
--------------   checking for user Tax type  -----------------------------      
      
drop TABLE if exists #kyctax      
      
 select dd.CID      
  , dc.Name as CountryTax      
  , dex.Name as TypeName      
  , mt.Name AS TaxRequirement      
 into #kyctax      
 from #mimoCIDs dd      
 inner join DWH..Dim_Customer dc1 with (NOLOCK) on dd.CID = dc1.RealCID      
 left join ETL_Source.[UserApiDB_rep].[Customer].[ExtendedUserField] cex  with (NOLOCK) on dc1.GCID = cex.GCID      
 left join ETL_Source.[UserApiDB_rep].[Dictionary].[ExtendedUserValueType] dex  with (NOLOCK) on cex.TypeId = dex.ValueTypeID      
 left join ETL_Source.etoro_rep.Dictionary.Country dc  with (NOLOCK) on cex.CountryId = dc.CountryID      
 JOIN ETL_Source.[UserApiDB_rep].[KYC].[CountryTaxType] ct  with (NOLOCK) ON cex.CountryId = ct.CountryID      
 JOIN ETL_Source.[UserApiDB_rep].[Dictionary].[MandatoryType] mt  with (NOLOCK) ON ct.TaxIdRequirmentTypeId = mt.MandatoryTypeID      
 where [FieldId] = 6      
  and [FieldTypeID] = 3      
      
-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate #TotalDeposits12Months + #kyctax'      
      
-- SELECT * FROM #kyctax k where TaxRequirement = 'Exempt'      
-------------  lifetime cashouts of depositors -------------------------      
drop table      
      
if exists #cashouts      
 select fca.RealCID      
  , SUM(fca.Amount) as TotalCashouts      
  , sum(case       
    when CONVERT(date, convert(varchar(10), DateID)) >= dateadd(month, - 6, getdate())      
     then fca.Amount      
    else 0      
    end) as CO6Months      
  , sum(case       
    when CONVERT(date, convert(varchar(10), DateID)) >= dateadd(month, - 12, getdate())      
     then fca.Amount        else 0      
    end) as CO12Months      
 into #cashouts      
 from DWH..Fact_CustomerAction fca with (NOLOCK)       
 inner join #Dailydepositors d on fca.RealCID = d.CID      
 where fca.ActionTypeID = 8      
 group by fca.RealCID      
      
      
      
      
-- select * from #cashouts      
--  select * from #Dailydepositors      
-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate #cashouts'      
      
-------------- KYC relevant questions ------------------------------      
      
drop table      
      
if exists #kyc;      
 with NW      
 as (      
  select RealCID      
   , AnswerText as NetWorthAnswer      
   , case       
    when AnswerText = '$50K-$200K'  then 200000       
    when AnswerText = 'Up to $10K'  then 10000      
    when AnswerText = '$10K-$50K'  then 50000      
    when AnswerText = '$200K-$1M'  then 1000000      
    when AnswerText is NULL    then 0      
    when AnswerText = '$200K-$500k'  then 500000      
    when AnswerText = '$1M-$5M'   then 5000000      
    when AnswerText = 'Over $1M'  then 100000000      
    when AnswerText = '$25K-$50K'  then 50000      
    when AnswerText = 'Less than $25K' then 25000      
    when AnswerText = 'More than $500K' then 500000      
    when AnswerText = '$50K-$100K'  then 100000      
    when AnswerText = '$10K-$25K'  then 25000      
    when AnswerText = '$100K-$500K'  then 500000      
    when AnswerText = '$500K-$1M'  then 1000000      
    end as MaxTotalNW      
  from BI_DB_KYCUserRawDataLeveled kr with (NOLOCK)       
  inner join #mimoCIDs dd on kr.RealCID = dd.CID      
  where kr.QuestionId = 11 --and kr.RealCID = 6358227      
  )      
  , MaxInv      
 as (      
  select RealCID      
   , AnswerText as MaxInvestAnswer      
   , case       
    when AnswerText like 'Up to $1k'  then 1000      
    when AnswerText like '$1k - $5k'  then 5000      
    when AnswerText like '$5k - $20k'  then 20000      
    when AnswerText like '$20k - $100k'  then 100000      
    when AnswerText like 'More than $100k' then 300000      
    when AnswerText like '$20k - $50k'  then 50000      
    when AnswerText like '$200k - $500k' then 500000      
    when AnswerText like '$50k-$200k'  then 200000      
    when AnswerText like '$1M-$5M'   then 5000000      
    when AnswerText like '$500k - $1M'  then 1000000      
    when AnswerText like 'Over $1M'   then 5000000      
    when AnswerText like 'Above $1M'  then 5000000      
    when AnswerText is null      
     then 0      
    end as MAXInvDeclared      
  from BI_DB_KYCUserRawDataLeveled kr with (NOLOCK)       
  inner join #mimoCIDs dd on kr.RealCID = dd.CID      
  where kr.QuestionId = 14 --and kr.RealCID = 6358227      
  )      
  , IncomeSource      
 as (      
  select RealCID      
   , QuestionId      
   , AnswerText      
   , ROW_NUMBER() over (      
    partition by RealCID      
    , QuestionId order by AnswerId      
    ) as RN      
  from BI_DB_KYCUserRawDataLeveled kr      
  inner join #mimoCIDs dd on kr.RealCID = dd.CID      
  where kr.QuestionId = 15 --and kr.RealCID = 6358227      
  )      
  , AllIncomeSources      
 as (      
  select *      
  from (      
   select RealCID      
    , AnswerText      
    , CAST(RN as varchar(2)) as RN      
   from IncomeSource      
   ) as IN_TAB      
  PIVOT(MAX(IN_TAB.AnswerText) for RN in ([1], [2], [3], [4], [5])) as PVT      
  )        , Concatincomes      
 as (      
  select RealCID      
   , isnull([1], '_') + ' ' + isnull([2], '_') + ' ' + isnull([3], '_') + ' ' + isnull([4], '_') + ' ' + isnull([5], '_') as IncomeSource      
  from AllIncomeSources      
  )      
  , MinYearlyIncome      
 as (      
  select RealCID      
   , AnswerText as MaxInvestAnswer      
   , case       
    when AnswerText = 'Up to $10K'   then 10000      
    when AnswerText = 'Less than $25K'  then 25000      
    when AnswerText = '$10K-$25K'   then 10000      
    when AnswerText = '$25K-$50K'   then 25000      
    when AnswerText = '$10K-$50K'   then 10000      
    when AnswerText = '$50K-$100K'   then 50000      
    when AnswerText = '$50K-$200K'   then 50000      
    when AnswerText = '$100K-$500K'   then 100000      
    when AnswerText = '$200K-$500k'   then 200000      
    when AnswerText = 'More than $500K'  then 500000      
    when AnswerText = '$200K-$1M'   then 200000      
    when AnswerText = '$500K-$1M'   then 500000      
    when AnswerText = 'Over $1M'   then 1000000      
    when AnswerText = '$1M-$5M'    then 1000000      
    when AnswerText = '$5K - $20K'   then 5000      
    when AnswerText = '$20K - $100K'  then 20000      
    when AnswerText = '$20K - $50K'   then 20000      
    when AnswerText is NULL     then 0      
    end as MinYearlyIncome      
   , case       
    when AnswerText = 'Up to $10K'   then 10000      
    when AnswerText = 'Less than $25K'  then 25000      
    when AnswerText = '$10K-$25K'   then 25000      
    when AnswerText = '$25K-$50K'   then 50000      
    when AnswerText = '$10K-$50K'   then 50000      
    when AnswerText = '$50K-$100K'   then 100000      
    when AnswerText = '$50K-$200K'   then 200000      
    when AnswerText = '$100K-$500K'   then 500000      
    when AnswerText = '$200K-$500k'   then 500000      
    when AnswerText = 'More than $500K'  then 500000      
    when AnswerText = '$200K-$1M'   then 1000000      
    when AnswerText = '$500K-$1M'   then 1000000      
    when AnswerText = 'Over $1M'   then 1000000      
    when AnswerText = '$1M-$5M'    then 5000000      
    when AnswerText = '$5K - $20K'   then 5000      
    when AnswerText = '$20K - $100K'  then 100000      
    when AnswerText = '$20K - $50K'   then 50000      
    when AnswerText is NULL     then 0      
    end as MaxYearlyIncome      
  from BI_DB_KYCUserRawDataLeveled kr with (NOLOCK)       
  inner join #mimoCIDs dd on kr.RealCID = dd.CID      
  where kr.QuestionId = 10 --and kr.RealCID = 6358227      
  )      
  , youngOld      
 as (      
  select RealCID      
   , AnswerText as Occupation      
   , case       
    when kr.AnswerText in ('Student', 'None', 'Unemployed', 'Retired')      
     then 1      
    else 0      
    end as IsStudentOrRetired      
  from BI_DB_KYCUserRawDataLeveled kr with (NOLOCK)       
  inner join #mimoCIDs dd on kr.RealCID = dd.CID      
  where kr.QuestionId = 18 --and kr.RealCID = 6358227      
  )      
  , Credits      
 as (      
  select dd.CID      
   , SUM(hc.[Payment]) Compensations      
  from #mimoCIDs dd      
  inner join ETL_Source.etoro_rep.[History].[Credit] hc  with (NOLOCK) on hc.CID = dd.CID      
  where hc.[CompensationReasonID] in (7, 33) --and hc.CID = 6358227      
  group by dd.CID      
  )  , Finra      
 as (      
  select RealCID      
   , AnswerText as FINRA      
   , case       
    when kr.AnswerId in (93,94,95)      
     then 1      
    else 0      
    end as IsFINRAPositive      
  from BI_DB_KYCUserRawDataLeveled kr with (NOLOCK)       
  inner join #mimoCIDs dd on kr.RealCID = dd.CID      
  where kr.QuestionId = 30 --and kr.RealCID = 6358227      
  )           
 select distinct nw.*      
  , ps.Name as PlayerStatusName      
  , dr.Name as Regulation      
  , mi.MaxInvestAnswer      
  , mi.MAXInvDeclared      
  , my.MinYearlyIncome      
  , my.MaxYearlyIncome      
  , iso.IncomeSource      
  , yo.Occupation      
  , yo.IsStudentOrRetired      
  , isnull(cr.Compensations, 0) as TotalCompensation      
  , case when BirthDate <= '1920-01-01' then 'TBD'       
    when DATEDIFF(YEAR,dc.BirthDate,dc.FirstDepositDate) <22 then '18-22'      
    when DATEDIFF(YEAR,dc.BirthDate,dc.FirstDepositDate) <35 then '23-34'      
    when DATEDIFF(YEAR,dc.BirthDate,dc.FirstDepositDate) <45 then '35-44'      
    when DATEDIFF(YEAR,dc.BirthDate,dc.FirstDepositDate) <55 then '45-54'      
    when DATEDIFF(YEAR,dc.BirthDate,dc.FirstDepositDate) <65 then '55-64'      
    else '65+' end AgeRange 
  ,fin.IsFINRAPositive	     
  , dc.EvMatchStatus      
  , dc.PhoneVerifiedID      
  , dc.IsAddressProof      
  , dc.IsIDProof      
  , dps.Name AS PEPStatus      
  ,tcl.TotalCompensationsLifetime      
  ,tdl.TotalDepositsLifetime      
 into #kyc      
 from NW nw      
 left join MaxInv mi on nw.RealCID = mi.RealCID      
 left join MinYearlyIncome my on nw.RealCID = my.RealCID      
 left join Concatincomes iso on nw.RealCID = cast(iso.RealCID as int)      
 left join youngOld yo on nw.RealCID = yo.RealCID      
 left join Credits cr on nw.RealCID = cr.CID      
 inner join DWH..Dim_Customer dc  with (NOLOCK) on nw.RealCID = dc.RealCID      
 LEFT JOIN DWH..Dim_PEPStatus dps ON dc.PEPStatusID = dps.PEPStatusID      
 left join DWH..Dim_PlayerStatus ps  with (NOLOCK) on dc.PlayerStatusID = ps.PlayerStatusID      
 left join DWH..Dim_Regulation dr  with (NOLOCK) on dc.RegulationID = dr.DWHRegulationID      
 LEFT JOIN BI_DB_KYCUserRawDataLeveled kr with (NOLOCK) ON nw.RealCID = kr.RealCID      
 LEFT JOIN #TotalCompsLifetime tcl ON nw.RealCID = tcl.CID      
 LEFT JOIN #TotalDepositsLifetime tdl ON nw.RealCID = tdl.CID 
 LEFT JOIN Finra fin ON nw.RealCID = fin.RealCID     
      
      
-- select  * from BI_DB_KYCUserRawDataLeveled where RealCID = 8808286      
-- select * from #kyc  where RealCID = 8808286      
-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate #kyc'      
      
------------------  Paypal specific data (different text parsing) -----------      
drop table      
      
if exists #paypal      
 select *      
 into #paypal      
 from openquery(ETL_Source, 'SELECT bd.CID, bd.DepositID,      
  cast(bd.PaymentData as nvarchar(max)) as PaymentData      
  FROM [etoro_rep].[Billing].[Deposit] bd      
   JOIN [etoro_rep].[Billing].[Funding] bf      
  ON bd.FundingID = bf.FundingID       
  where FundingTypeID = 3       
  and bd.PaymentStatusID = 2      
  and cast(bd.ModificationDate as Date) = cast(getdate()-1 as Date)')      
      
-- select * from #paypal      
-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate #paypal'      
      
drop table      
      
if exists #paypalcountry;      
 with pp      
 as (      
  select pp.CID      
   , pp.DepositID      
   , case       
    when CHARINDEX('</CountryIDAsString', PaymentData) = 0      
     then 0      
    else SUBSTRING(PaymentData, (CHARINDEX('<CountryIDAsString', PaymentData) + 19), (CHARINDEX('</CountryIDAsString', PaymentData)) - (CHARINDEX('<CountryIDAsString', PaymentData) + 19))      
    end as PaymentData      
  from #paypal pp      
  )      
 select pp.CID      
  , dc.Name as PaypalCountry      
 into #paypalcountry      
 from pp      
 inner join DWH..Dim_Country dc with (NOLOCK) on pp.PaymentData = dc.CountryID      
 group by pp.CID      
  , dc.Name      
      
-- select * from #kyc      
-- select * from #paypalcountry      
--declare @sdate DATE = CAST(GETDATE()-1 AS DATE)      
--declare @sdateID INT = CAST(CONVERT(VARCHAR(8), @sdate, 112) AS INT)      
-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate #paypalcountry'      
      
--------------  final table -------------------------------------------      
      
--declare @sdate date = CAST(GETDATE() - 1 as date)      
--declare @sdateID int = CAST(CONVERT(varchar(8), @sdate, 112) as int)      
      
-- select top 10 * from #Dailydepositors      
      
drop table      
      
if exists #final      
 select distinct mop.*      
  , dc.Name as Country      
  , vl.RealizedEquity      
  , pl.Name as PlayerStatusName      
  , rs.Name as RiskStatusNamee      
  , cc.VerificationLevelID      
  , cc.EvMatchStatus as EVMatchStatus      
  , dc.EU as IsRegCountryEU      
  , dc.IsHighRiskCountry as RegCountryHighRisk      
  , dc1.EU as IsBinCountryEU      
  , dc1.IsHighRiskCountry as BinCountryHighRisk      
  , dc2.Name as KYC_Country      
  , dc2.EU as IsKYCCountryEU      
  , kt.CountryTax as TaxCountry      
  , c.TotalCashouts as LifetimeCashouts      
  , c.CO6Months as [Cashouts6Months]      
  , c.CO12Months as [Cashouts12Months]      
  , mop.TotalDepositsLifetime - c.TotalCashouts as TotalNetDepositLifeTime      
  , mop.TotalDeposits12Months - c.CO12Months as TotalNetDeposit12Months      
  , mop.TotalDeposits6Months - c.CO6Months as TotalNetDeposit06Months      
  , ky.NetWorthAnswer      
  , ky.MaxInvestAnswer      
  , ky.MaxTotalNW      
  , ky.MAXInvDeclared      
  , ky.MinYearlyIncome      
  , ky.Occupation      
  , ky.IsStudentOrRetired      
  , ky.AgeRange      
  , ky.IncomeSource      
  , ISNULL(mop.TotalDepositsLifetime, 0) - ISNULL(c.TotalCashouts, 0) + ISNULL(ky.TotalCompensation, 0) as NetDeposit      
  , case       
   when mop.TotalDepositsLifetime > 5000      
    and ISNULL(mop.TotalDepositsLifetime, 0) - ISNULL(c.TotalCashouts, 0) + ISNULL(ky.TotalCompensation, 0) > 2 * ky.MAXInvDeclared      
    then 1      
   else 0      
   end Policy_1      
  , case       
   when mop.TotalDepositsLifetime > 5000      
    and ISNULL(mop.TotalDepositsLifetime, 0) - ISNULL(c.TotalCashouts, 0) + ISNULL(ky.TotalCompensation, 0) > 1.5 * ky.MAXInvDeclared      
    and ISNULL(mop.TotalDepositsLifetime, 0) - ISNULL(c.TotalCashouts, 0) + ISNULL(ky.TotalCompensation, 0) < 2 * ky.MAXInvDeclared      
    then 1      
   else 0      
   end Policy_2      
  , case       
   when mop.TotalDepositsLifetime > 5000      
    and ISNULL(mop.TotalDepositsLifetime, 0) - ISNULL(c.TotalCashouts, 0) + ISNULL(ky.TotalCompensation, 0) > ky.MAXInvDeclared      
    then 1      
   else 0      
   end AggDepositVsNW   
  ,ky.IsFINRAPositive    
  , pp.PaypalCountry      
  , dc3.EU as IsPaypalCountryEU      
  , cc.IsDepositor      
  , cc.EvMatchStatus      
  , cc.PhoneVerifiedID      
  , cc.IsAddressProof      
  , cc.IsIDProof      
  , dps.Name AS PEPStatus 
 into #final      
 from #Dailydepositors mop      
 inner join DWH..Dim_Customer cc  with (NOLOCK) on mop.CID = cc.RealCID      
 LEFT JOIN DWH..Dim_PEPStatus dps ON cc.PEPStatusID = dps.PEPStatusID      
 inner join DWH..Dim_Country dc  with (NOLOCK) on cc.CountryID = dc.CountryID      
 left join DWH..Dim_Country dc1  with (NOLOCK) on mop.BINCountry = dc1.Name      
 inner join DWH..Dim_PlayerStatus pl  with (NOLOCK) on cc.PlayerStatusID = pl.PlayerStatusID      
 left join DWH..Dim_RiskStatus rs  with (NOLOCK) on cc.RiskStatusID = rs.RiskStatusID      
 inner join DWH..Dim_Regulation dr  with (NOLOCK) on cc.RegulationID = dr.ID      
 inner join DWH..Dim_Regulation dr1  with (NOLOCK) on cc.DesignatedRegulationID = dr1.ID      
 inner join DWH..V_Liabilities vl  with (NOLOCK) on mop.CID = vl.CID      
  and vl.DateID = @sdateID      
 left join (      
  select distinct RealCID      
   , CountryID      
  from BI_DB_KYCUserRawDataLeveled  with (NOLOCK)      
  ) kr on kr.RealCID = mop.CID      
 left join DWH..Dim_Country dc2  with (NOLOCK) on kr.CountryID = dc2.CountryID      
 left join #kyctax kt on mop.CID = kt.CID      
 left join #cashouts c on cc.RealCID = c.RealCID      
 inner join #kyc ky on cc.RealCID = ky.RealCID      
 left join #paypalcountry pp on mop.CID = pp.CID      
 left join DWH..Dim_Country dc3  with (NOLOCK) on pp.PaypalCountry = dc3.Name      
      
 CREATE NONCLUSTERED INDEX #final ON #final ([CID])      
      
 ---SELECT TOP 10 *  from #final      
      
 --UPDATE #final      
 --SET RegCountryHighRisk = 0, BinCountryHighRisk = 0      
 --WHERE [Country (customer)] = 'Kuwait'      
      
----- also look at specific MOPs in deposits to compare MOPs -----      
      
-- withdrawers --      
      
      
      
DROP TABLE IF EXISTS #COers      
      
SELECT DISTINCT fca.RealCID, fca.FundingTypeID       
INTO #COers      
FROM DWH..Fact_CustomerAction fca  with (NOLOCK)      
WHERE  fca.ActionTypeID = 8       
 AND DateID >= CAST(CONVERT(VARCHAR(8), @sdate, 112) AS INT)      
      
-- select * from #COers      
      
DROP TABLE if exists #alldepositorsFunding      
      
SELECT DISTINCT ad.CID, ad.FundingType, dft.FundingTypeID      
INTO #alldepositorsFunding      
FROM BI_DB_AllDeposits ad with (NOLOCK)      
 JOIN DWH..Dim_FundingType dft with (NOLOCK)      
  ON ad.FundingType = dft.Name      
      
CREATE INDEX  #alldepositorsFundingCIDFunds      
ON #alldepositorsFunding (      
 CID, FundingTypeID ASC -- , ..., columnN ( ASC | DESC ]       
)      
      
DROP TABLE IF EXISTS #noDepMOPMatch      
      
SELECT DISTINCT c.RealCID, c.FundingTypeID AS COFunding, dft.Name AS COFundingType, f1.FundingTypeID AS MOPfunding      
INTO #noDepMOPMatch      
FROM #COers c      
 LEFT JOIN #alldepositorsFunding f1      
  ON c.FundingTypeID = f1.FundingTypeID AND c.RealCID = f1.CID      
 JOIN DWH..Dim_FundingType dft with (NOLOCK)      
  ON c.FundingTypeID = dft.FundingTypeID      
WHERE f1.FundingTypeID IS NULL      
      
-- SELECT * FROM #noDepMOPMatch      
-- SELECT * FROM #alldepositorsFunding f WHERE f.CID = 384172      
      
      
DROP TABLE IF exists #countMOPs      
      
; WITH "details" AS      
(      
SELECT nm.RealCID, nm.COFundingType, COUNT(f.CID) AS LifetimeDepMOPs      
 ,(      
   SELECT DISTINCT       
--    CID      
   FundingType      
   FROM #alldepositorsFunding      
   WHERE CID = nm.RealCID      
   FOR XML RAW      
   ) AS AllPreviousDepMOPs      
FROM #noDepMOPMatch nm      
 JOIN #alldepositorsFunding f      
  ON nm.RealCID = f.CID       
WHERE nm.COFunding <> 27 -- exclude wallet redeems, those are fine      
GROUP BY nm.RealCID,  nm.COFundingType      
HAVING COUNT(f.CID) > 3      
)      
SELECT RealCID      
 ,(      
  SELECT --RealCID      
    COFundingType      
   , LifetimeDepMOPs      
   , AllPreviousDepMOPs      
  FROM "details"      
  WHERE RealCID = dt.RealCID      
  FOR XML RAW      
 ) AS AlertDetails      
INTO #countMOPs       
FROM "details" dt      
      
-- SELECT * FROM #countMOPs      
      
-- SELECT * FROM #finalIncomingOutgoingMOPMatch      
      
      
--------------------------------------------------------------------------------------------------      
-----------------  on boarding ---------------------------------------------------------------      
--------------------------------------------------------------------------------------------------      

--declare @sdate date = CAST(GETDATE() - 1 as date)      
--declare @sdateID int = CAST(CONVERT(varchar(8), @sdate, 112) as int)    
      
drop table      
      
if exists #kycraw;      
 with kycraw      
 as (      
  select distinct ky.RealCID      
   , ky.CountryID      
   , ky.AgeRange      
   , dc1.IsHighRiskCountry      
   , dc1.EU      
   , dc1.Name as Country      
   , dc1.Region      
   , dc2.Name as IPRegCountry      
   , case       
    when QuestionId = 10      
     then case       
       when AnswerText = 'Up to $10K'   then 10000      
       when AnswerText = 'Less than $25K'  then 25000      
       when AnswerText = '$10K-$25K'   then 10000      
       when AnswerText = '$25K-$50K'   then 25000      
       when AnswerText = '$10K-$50K'   then 10000      
       when AnswerText = '$50K-$100K'   then 50000      
       when AnswerText = '$50K-$200K'   then 50000      
       when AnswerText = '$100K-$500K'   then 100000      
       when AnswerText = '$200K-$500k'   then 200000      
       when AnswerText = 'More than $500K'  then 500000      
       when AnswerText = '$200K-$1M'   then 200000      
       when AnswerText = '$500K-$1M'   then 500000      
       when AnswerText = 'Over $1M'   then 1000000      
       when AnswerText = '$1M-$5M'    then 1000000      
       when AnswerText = '$5K - $20K'   then 5000      
       when AnswerText = '$20K - $100K'  then 20000      
       when AnswerText = '$20K - $50K'   then 20000      
       when AnswerText is null     then 0      
       end      
    end as MinYearlyIncome      
   , case       
    when QuestionId = 10      
     then ky.UpdateDate      
    end as YearlyIncomeUpdateDate      
   , case       
    when QuestionId = 18      
     then case       
       when ky.AnswerText in ('Student', 'None', 'Unemployed', 'Retired')      
        then 1      
       else 0      
       end      
    end as IsStudentOrRetired      
   , case       
    when ky.QuestionId = 18      
     then ky.UpdateDate      
    end as OccupationUpdateDate      
   , case       
    when ky.QuestionId = 15      
     then ky.AnswerText      
    end as MainIncomeSource      
   , case       
    when ky.QuestionId = 15      
     then ky.UpdateDate      
    end as IncomeSourceUpdateDate      
   , case       
    when ky.QuestionId = 18      
     then ky.AnswerText      
    end as Occupation  
  , case       
    when QuestionId = 30      
     then case       
       when ky.AnswerId in (93,94,95)      
        then 1      
       else 0      
       end      
    end as IsFINRAPositive    
  from BI_DB_KYCUserRawDataLeveled ky      
  inner join DWH..Dim_Customer dc with (NOLOCK) on ky.RealCID = dc.RealCID      
  inner join DWH..Dim_Country dc1 with (NOLOCK) on dc.CountryID = dc1.CountryID      
  inner join DWH..Dim_Country dc2 with (NOLOCK)on dc.CountryIDByIP = dc2.CountryID      
  INNER JOIN #mimoCIDs dd ON ky.RealCID = dd.CID      
  )      
 select ky.*      
  , dr.Name as Regulation      
  , ps.Name as PlayerStatus      
 into #kycraw      
 from kycraw ky      
 inner join DWH..Dim_Customer dc with (NOLOCK) on ky.RealCID = dc.RealCID      
 inner join DWH..Dim_Regulation dr with (NOLOCK) on dc.RegulationID = dr.DWHRegulationID      
 inner join DWH..Dim_PlayerStatus ps with (NOLOCK) on dc.PlayerStatusID = ps.PlayerStatusID      
 where cast(IncomeSourceUpdateDate as date) = @sdate      
  or cast(OccupationUpdateDate as date) = @sdate      
  or cast(YearlyIncomeUpdateDate as date) = @sdate      
      
-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate #kycraw'      
      
-- select * from #kycraw order by 1      
-- select distinct QuestionId, QuestionText from BI_DB_KYCUserRawDataLeveled where RegisteredReal >= getdate()-1      
-- select distinct AnswerId, AnswerText from BI_DB_KYCUserRawDataLeveled where QuestionId = 18 and RegisteredReal >= getdate()-1      
--declare @sdate DATE = CAST(GETDATE()-1 AS DATE)      
--declare @sdateID INT = CAST(CONVERT(VARCHAR(8), @sdate, 112) AS INT)      
--drop table if exists #ver2      
--; with ver2 as      
--(      
--select fsc.RealCID, dr.FromDateID, ROW_NUMBER() over (partition by fsc.RealCID order by dr.FromDateID) as RN        
--from DWH..Fact_SnapshotCustomer fsc      
-- join DWH..Dim_Range dr      
--  on fsc.DateRangeID = dr.DateRangeID      
--where VerificationLevelID = 2      
--)      
--select RealCID      
--into #ver2      
--from ver2 where RN = 1 and FromDateID = @sdateID      
--select * from #ver2      
--select  * from BI_DB_KYCUserRawDataLeveled where UpdateDate >= '2019-03-25'      
      
      
      
--------------------------------------------------------------------------------------------------      
-----------------  MIMO - Cashouts ---------------------------------------------------------------      
--------------------------------------------------------------------------------------------------      
      
--declare @sdate DATE = CAST(GETDATE()-1 AS DATE)      
--declare @sdateID INT = CAST(CONVERT(VARCHAR(8), @sdate, 112) AS INT)      
      
drop TABLE if exists #finalCOs      
      
  select bw.CID      
   , ps.Name as PlayerStatusName      
   , dco.Name as 'RegCountry'      
   , dco.EU AS RegCountryEU      
   , dco.IsHighRiskCountry AS RegCountryHighRisk      
   , dco1.Name as 'CitizenshiptCountry'      
   , dco2.Name as 'RegCountryByIP'      
   , ft.Name as BWFundingType      
   , COUNT(bw.WithdrawID) as CountWithdrawID      
   , SUM(wtf1.Amount) as Amount      
   , CURR1.Abbreviation as ProcessCurrency      
   , SUM((wtf1.Amount * wtf1.[ExchangeRate])) as Amount$      
   , cs.Name as CashoutStatus      
   , creason.Name as CashoutReason      
   , CONVERT(date, bw.RequestDate) RequestDate      
   , CONVERT(date, bw.ModificationDate) ModificationDate      
   , ft1.Name as FTFundingType      
   , depo.Name Provider      
   , dr.Name as Regulation      
   , dr2.Name as DesignatedRegulation      
   , dco3.Name as BINCountry      
   , dco3.EU AS BinCountryEU      
   , ct.Name as CardType      
   , cbin.CardSubType      
   , dco3.IsHighRiskCountry as BinCountryHighRisk      
   , b.TotalDeposits6Months      
   , c.TotalDeposits12Months      
   , lt.TotalDepositsLifetime      
   , ky.NetWorthAnswer      
   , ky.MaxInvestAnswer      
   , ky.MaxTotalNW      
   , ky.MAXInvDeclared      
   , ky.MinYearlyIncome      
   , ky.Occupation      
   , ky.IsStudentOrRetired      
   , ky.AgeRange      
   , ky.IncomeSource  
   , ky.IsFINRAPositive    
   , cc.VerificationLevelID      
   , cc.IsDepositor      
   , cc.EvMatchStatus      
   , cc.PhoneVerifiedID      
   , cc.IsAddressProof      
   , cc.IsIDProof      
   , dps.Name AS PEPStatus      
   , tcl.TotalCompensationsLifetime      
  into #finalCOs      
  from ETL_Source.etoro_rep.[Billing].[Withdraw] bw      
  left join DWH..Dim_Customer cc  with (NOLOCK) on bw.CID = cc.RealCID      
   and cc.IsValidCustomer = 1      
   and bw.CashoutReasonID not in (12, 15) -- not affiliate payout or foreclosure      
  LEFT JOIN DWH..Dim_PEPStatus dps ON cc.PEPStatusID = dps.PEPStatusID      
  left join DWH..Dim_Country dco  with (NOLOCK) on cc.CountryID = dco.CountryID      
  left join DWH..Dim_Country dco1  with (NOLOCK) on cc.CountryID = dco1.CountryID      
  left join DWH..Dim_Country dco2  with (NOLOCK) on cc.CountryIDByIP = dco2.CountryID      
  left join DWH..Dim_PlayerStatus ps  with (NOLOCK) on cc.PlayerStatusID = ps.PlayerStatusID      
  left join ETL_Source.etoro_rep.Dictionary.FundingType ft on bw.FundingTypeID = ft.FundingTypeID      
  left join #wtf1 wtf1 on bw.WithdrawID = wtf1.WithdrawID      
  left join ETL_Source.etoro_rep.Dictionary.FundingType ft1 on wtf1.BFFundingTypeID = ft1.FundingTypeID      
  left join ETL_Source.etoro_rep.Dictionary.Regulation dr on cc.RegulationID = dr.ID      
  left join ETL_Source.etoro_rep.Dictionary.Regulation dr2 on cc.DesignatedRegulationID = dr2.ID      
  left join ETL_Source.etoro_rep.[Dictionary].[Currency] CURR on CURR.CurrencyID = wtf1.[ProcessCurrencyID]      
  left join ETL_Source.etoro_rep.[Dictionary].CashoutStatus cs on cs.CashoutStatusID = wtf1.CashoutStatusID      
  left join ETL_Source.etoro_rep.[Dictionary].CashoutReason creason on creason.CashoutReasonID = bw.CashoutReasonID      
  left join ETL_Source.etoro_rep.[Dictionary].ClientWithdrawReason clientreason on clientreason.ClientWithdrawReasonID = bw.ClientWithdrawReasonID      
  left join ETL_Source.etoro_rep.[Dictionary].[Currency] CURR1 on CURR1.CurrencyID = wtf1.[ProcessCurrencyID]      
  left join ETL_Source.etoro_rep.Billing.Depot depo on depo.DepotID = wtf1.DepotID      
  left join DWH..Dim_Country dco3  with (NOLOCK) on dco3.CountryID = wtf1.BinCountryIDAsInteger      
  left join ETL_Source.etoro_rep.Dictionary.CountryBin cb on cb.BinCode = wtf1.BinCodeAsString      
  left join ETL_Source.etoro_rep.Dictionary.CardType ct on ct.CardTypeID = wtf1.CardTypeIDAsInteger      
  left join ETL_Source.etoro_rep.Dictionary.CountryBin cbin on cbin.BinCode = wtf1.BinCodeAsString      
  left join #TotalDeposits6Months b on bw.CID = b.CID      
  left join #TotalDeposits12Months c on bw.CID = c.CID      
  left join #TotalDepositsLifetime lt on bw.CID = lt.CID      
  LEFT join #kyc ky on bw.CID = ky.RealCID      
  LEFT JOIN #TotalCompsLifetime tcl ON bw.CID = tcl.CID      
  where CAST(bw.ModificationDate as date) = CAST(GETDATE() - 1 as date)      
   AND cs.Name = 'Processed'      
  group by bw.CID      
   , ft.Name      
   , bw.CurrencyID      
   , dco.Name      
   , dco1.Name      
   , dco2.Name      
   , CURR1.Abbreviation      
   , cs.Name      
   , creason.Name      
   , CONVERT(date, bw.RequestDate)      
   , CONVERT(date, bw.ModificationDate)      
   , ft1.Name      
   , depo.Name      
   , dr.Name      
   , dr2.Name      
   , dco3.Name      
   , ct.Name      
   , cbin.CardSubType      
   , ps.Name      
   , dco3.IsHighRiskCountry      
   , dco.EU      
   , dco.IsHighRiskCountry      
   , dco3.EU      
   , b.TotalDeposits6Months      
   , c.TotalDeposits12Months      
   , lt.TotalDepositsLifetime      
   , ky.NetWorthAnswer      
   , ky.MaxInvestAnswer      
   , ky.MaxTotalNW      
   , ky.MAXInvDeclared      
   , ky.MinYearlyIncome      
   , ky.Occupation      
   , ky.IsStudentOrRetired      
   , ky.AgeRange      
   , ky.IncomeSource  
   , ky.IsFINRAPositive    
   , cc.VerificationLevelID      
   , cc.IsDepositor      
   , cc.EvMatchStatus      
   , cc.PhoneVerifiedID      
   , cc.IsAddressProof      
   , cc.IsIDProof      
   , dps.Name      
   , tcl.TotalCompensationsLifetime      
      
--SELECT * FROM DWH..Fact_CustomerAction fca WHERE fca.ActionTypeID = 8 AND fca.DateID = 20190717 AND fca.WithdrawID = 1337928      
--SELECT * FROM ETL_Source.etoro_rep.Billing.vWithdrawToFunding wtf      
--SELECT * FROM #finalCOs c WHERE c.CashoutStatus = 'Processed'      
      
-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate #finalCOs'      
      
--  SELECT * FROM #finalCOs c  --      
-- select top 10 * from #final f      
-- select top 10 * from #finalCOs c      
-- select top 10 * from #kycraw k      
----- on boarding alerts ----------------      
--drop table      
      
--if exists #OBhighriskcountry      
-- select distinct 'On Boarding ' as AlertCategory      
--  , 'high risk Reg country' as AlertType      
--  , k.RealCID      
--  , @sdate [Date]      
--  , k.Regulation      
--  , null as RelatedAccounts      
--  , k.PlayerStatus      
--  , null as AlertStatus      
--  , null as Assigned      
--  , (      
--   select distinct RealCID      
--    , Country      
--    , IsHighRiskCountry      
--    , IPRegCountry      
--    , Region      
--   from #kycraw      
--   where RealCID = k.RealCID      
--   for xml RAW      
--   ) AlertDetails      
-- into #OBhighriskcountry      
-- from #kycraw k      
-- where IsHighRiskCountry = 1      
      
------------ MIMO alerts ----------------------      
---- lifetime > 500K$      
      
drop table      
      
if exists #lifetimedep500      
 select distinct 'MIMO - Deposit ' as AlertCategory      
  , 'DC3: Lifetime Deposit > 500K$' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct CID      
    , IncomeSource      
    , PEPStatus      
    , [Country (customer)] as CountryCustomer      
    , [Country By Reg IP] as CountryByRegIP      
    , Regulation      
    , TotalNetDepositLifeTime      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , LifetimeCashouts      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #final      
   where CID = k.CID      
   for xml RAW      
   ) as AlertDetails      
 into #lifetimedep500      
 from #final k      
 where TotalNetDepositLifeTime > 500000 AND TotalNetDepositLifeTime <= 999999  
      
-- select * from #lifetimedep500      
-- lifetime > 100K$      
drop table      
      
if exists #lifetimedep100      
 select distinct 'MIMO - Deposit ' as AlertCategory      
  , 'DC2: Lifetime Deposit > 100K$' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct CID      
    , IncomeSource      
    , PEPStatus      
    , [Country (customer)] as CountryCustomer      
    , [Country By Reg IP] as CountryByRegIP      
    , Regulation      
    , TotalNetDeposit12Months      
    , TotalDeposits12Months      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , Cashouts12Months      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #final      
   where CID = k.CID      
   for xml RAW      
   ) as AlertDetails      
 into #lifetimedep100      
 from #final k      
 where k.TotalNetDepositLifeTime between 100000 and 500000      
      
-- 6 months > 100K$      
drop table      
      
if exists #6month100K      
 select distinct 'MIMO - Deposit ' as AlertCategory      
  , 'DC1: 6 month > 100K$' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct CID      
    , IncomeSource      
    , PEPStatus      
    , [Country (customer)] as CountryCustomer      
    , [Country By Reg IP] as CountryByRegIP      
    , Regulation      
    , TotalNetDeposit06Months      
    , TotalDeposits6Months      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , Cashouts6Months      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #final      
   where CID = k.CID      
   for xml RAW      
   ) as AlertDetails      
 into #6month100K      
 from #final k      
 where TotalNetDeposit06Months > 100000      
      
---- 12 months > 150% from intended investment ----      
drop table      
      
if exists #12MonthExceedInvest      
 select distinct 'MIMO - Deposit ' as AlertCategory      
  , 'DC4: 12 months > 150% from declared' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct CID      
    , IncomeSource      
    , PEPStatus      
    , [Country (customer)] as CountryCustomer      
    , [Country By Reg IP] as CountryByRegIP      
    , Regulation      
    , TotalNetDeposit12Months      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , MaxInvestAnswer      
    , MAXInvDeclared      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #final      
   where CID = k.CID      
   for xml RAW      
   ) as AlertDetails      
 into #12MonthExceedInvest      
 from #final k      
 where k.TotalNetDeposit12Months / k.MAXInvDeclared > 1.5      
      
-- select * from #12MonthExceedInvest      
-- select * from #depsWithKyc where CID = 439983      
-- select * from #12MonthExceedInvest where CID = 439983      
-- select * from #kyc where RealCID = 439983      
-- daily > 50K$      
drop table      
      
if exists #daily50;      
 with "temp"      
 as (      
  select distinct 'MIMO - Deposit ' as AlertCategory      
   , 'DC7: Daily Deposit > 50K$' as AlertType      
   , k.CID      
   , @sdate [Date]      
   , k.Regulation      
   , null as RelatedAccounts      
   , k.PlayerStatusName as PlayerStatus      
   , null as AlertStatus      
   , null as Assigned      
   , (      
    select distinct CID      
     , IncomeSource      
     , PEPStatus      
     , [Country (customer)] as CountryCustomer      
     , [Country By Reg IP] as CountryByRegIP      
     , Regulation      
     , sum(TotalDepositDaily) as TotalDailyDeposit      
     , TotalDepositsLifetime      
     , TotalCompensationsLifetime      
     , EvMatchStatus      
     , PhoneVerifiedID      
     , IsAddressProof      
     , IsIDProof      
    from #final      
    where CID = k.CID      
    group by CID      
     , PEPStatus      
     , [Country (customer)]      
     , [Country By Reg IP]      
     , Regulation      
     , IncomeSource      
     , EvMatchStatus      
     , PhoneVerifiedID      
     , IsAddressProof      
     , IsIDProof      
     , TotalDepositsLifetime      
     , TotalCompensationsLifetime      
    having sum(TotalDepositDaily) > 50000      
    for xml RAW      
    ) as AlertDetails      
  from #final k      
  )      
 select *      
 into #daily50      
 from "temp"      
 where AlertDetails is not null      
      
-- MOP is high risk country --      
      
--drop table      
      
--if exists #depmophighrisk      
-- select distinct 'MIMO - Deposit ' as AlertCategory      
--  , 'MOP high risk country' as AlertType      
--  , k.CID      
--  , @sdate [Date]      
--  , k.Regulation      
--  , null as RelatedAccounts      
--  , k.PlayerStatusName as PlayerStatus      
--  , null as AlertStatus      
--  , null as Assigned      
--  , (      
--   select distinct CID      
--    , [Country (customer)] as CountryCustomer      
--    , [Country By Reg IP] as CountryByRegIP      
--    , Regulation      
--    , BINCountry      
--    , BinCountryHighRisk      
--   from #final      
--   where CID = k.CID      
--   for xml RAW      
--   ) as AlertDetails      
-- into #depmophighrisk      
-- from #final k      
-- where BinCountryHighRisk = 1      
      
-- MOP and Bin countries not same --      
--drop table      
      
--if exists #NotExpectedCountry      
-- select distinct 'MIMO - Deposit ' as AlertCategory      
--  , 'MOP Country <> Country, Check funds source' as AlertType      
--  , k.CID      
--  , @sdate [Date]      
--  , k.Regulation      
--  , null as RelatedAccounts      
--  , k.PlayerStatusName as PlayerStatus      
--  , null as AlertStatus      
--  , null as Assigned      
--  , (      
--   select distinct CID      
--    , [Country (customer)] as CountryCustomer      
--    , [Country By Reg IP] as CountryByRegIP      
--    , Regulation      
--    , BINCountry      
--    , BinCountryHighRisk      
--   from #final      
--   where CID = k.CID      
--   for xml RAW      
--   ) as AlertDetails      
-- into #NotExpectedCountry      
-- from #final k      
-- where k.[Country (customer)] <> k.BINCountry      
      
-- too many credit cards --      
drop table if exists #tooManyCards 
     
 select distinct 'MIMO - Deposit ' as AlertCategory      
  , 'DC14: More than 2 Credit Cards' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct CID
	, TotalDepositsValidCreditCards   
    , CountCards         
    , IncomeSource      
    , PEPStatus      
    , [Country (customer)] as CountryCustomer      
    , [Country By Reg IP] as CountryByRegIP      
    , Regulation      
    , BINCountry      
    , BinCountryHighRisk      
    , TotalDepositsLifetime
    , TotalCompensationsLifetime      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #final      
   where CID = k.CID      
   for xml RAW      
   ) as AlertDetails      
 into #tooManyCards      
 from #final k      
 where k.CountCards >= 3 and TotalDepositsValidCreditCards >= 50000

-- select * from #tooManyCards  
      
-- too many MOPs --      
--drop table      
      
--if exists #tooManyMOPs      
-- select distinct 'MIMO - Deposit ' as AlertCategory      
--  , 'DC11: More than 2 MOPs' as AlertType      
--  , k.CID      
--  , @sdate [Date]      
--  , k.Regulation      
--  , null as RelatedAccounts      
--  , k.PlayerStatusName as PlayerStatus      
--  , null as AlertStatus      
--  , null as Assigned      
--  , (      
--   select distinct CID      
--    , IncomeSource      
--    , PEPStatus      
--    , [Country (customer)] as CountryCustomer      
--    , [Country By Reg IP] as CountryByRegIP      
--    , Regulation      
--    , BINCountry      
--    , BinCountryHighRisk      
--    , TotalDepositsLifetime      
--    , TotalCompensationsLifetime      
--    , CountOfMOPs      
--    , EvMatchStatus      
--    , PhoneVerifiedID      
--    , IsAddressProof      
--    , IsIDProof      
--   from #final      
--   where CID = k.CID      
--   for xml RAW      
--   ) as AlertDetails      
-- into #tooManyMOPs      
-- from #final k      
-- where k.CountOfMOPs > 3      
      
-- CO BIN high risk country --      
drop table      
      
if exists #COhighriskcountry      
 select distinct 'MIMO - Cashout ' as AlertCategory      
  , 'DC9: Cashout - High Risk Destination of CashOut' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct CID      
    , IncomeSource      
   , PEPStatus      
    , RegCountry as CountryCustomer      
    , CitizenshiptCountry      
    , RegCountryByIP      
    , CashoutStatus      
    , Amount$      
    , BINCountry      
    , BinCountryHighRisk      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , CashoutReason      
    , BWFundingType      
    , FTFundingType      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #finalCOs      
   where CID = k.CID      
   for xml RAW      
   ) as AlertDetails      
 into #COhighriskcountry      
 from #finalCOs k      
 where k.BinCountryHighRisk = 1 AND k.BINCountry <> k.RegCountry      
    
--- FINRA ----

--declare @sdate DATE = CAST(GETDATE()-1 AS DATE)      
--declare @sdateID INT = CAST(CONVERT(VARCHAR(8), @sdate, 112) AS INT)

drop table if exists #Finra  
    
 select distinct 'FINRA - IsPositive' as AlertCategory      
  , 'OB12: FINRA - Is Positve' as AlertType      
  , isnull(isnull(k.CID, f.CID), k1.RealCID)  CID   
  , @sdate [Date]      
  , isnull(isnull(k.Regulation, f.Regulation COLLATE Latin1_General_100_BIN), k1.Regulation COLLATE Latin1_General_100_BIN) Regulation       
  , null as RelatedAccounts      
  , isnull(isnull(k.PlayerStatusName, f.PlayerStatusName), k1.PlayerStatusName) as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (NULL      
   --select distinct CID      
   -- , IncomeSource      
   --, PEPStatus      
   -- , RegCountry as CountryCustomer      
   -- , CitizenshiptCountry      
   -- , RegCountryByIP      
   -- , CashoutStatus      
   -- , Amount$      
   -- , BINCountry      
   -- , BinCountryHighRisk      
   -- , TotalDepositsLifetime      
   -- , TotalCompensationsLifetime      
   -- , CashoutReason      
   -- , BWFundingType      
   -- , FTFundingType      
   -- , EvMatchStatus      
   -- , PhoneVerifiedID      
   -- , IsAddressProof      
   -- , IsIDProof      
   --from #finalCOs      
   --where CID = k.CID      
   --for xml RAW      
   ) as AlertDetails      
 into #Finra      
 from #finalCOs k 
	FULL OUTER JOIN #final f 
		ON f.CID = k.CID
	FULL OUTER JOIN #kyc k1 
		ON  k.CID =  k1.RealCID  
WHERE f.IsFINRAPositive = 1 OR k.IsFINRAPositive = 1 or k1.IsFINRAPositive = 1

-- SELECT * FROM #Finra f	
	  
--SELECT * FROM BI_DB_KYCUserRawDataLeveled bdkrdl WHERE bdkrdl.RealCID IN(10888297,11872462) AND bdkrdl.QuestionId = 30
--select top 1 * from #finalCOs      
--select top 1 * from #final
--select top 1 * from #kyc
-- select * from #COhighriskcountry      


------ DEP BIN high risk country -----      

drop table      

if exists #DepHighriskcountry      
 select distinct 'MIMO - Deposit ' as AlertCategory      
  , 'DC8: Deposit - High Risk BinCountry' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct CID      
    , IncomeSource      
    , PEPStatus      
    , [Country (customer)]      
    , [Country By Reg IP]      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime          
    , BINCountry      
    , BinCountryHighRisk      
    , IsBinCountryEU      
    , Regulation      
    , FundingType      
    , PlayerStatusName      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #final      
   where CID = k.CID      
   for xml RAW      
   ) as AlertDetails      
 into #DepHighriskcountry      
 from #final k      
 where k.BinCountryHighRisk = 1 AND k.BINCountry <> k.[Country (customer)]    
      
-- high depositor individual --      
      
--drop table      
      
--if exists #NetAnnualHigh      
-- select distinct 'OnBoarding ' as AlertCategory      
--  , 'KYC - High Income Individual' as AlertType      
--  , k.RealCID as CID      
--  , @sdate [Date]      
--  , k.Regulation      
--  , null as RelatedAccounts      
--  , k.PlayerStatusName as PlayerStatus      
--  , null as AlertStatus      
--  , null as Assigned      
--  , (      
--   select distinct CID      
--    , NetWorthAnswer      
--    , PlayerStatusName      
--    , MaxInvestAnswer      
--    , MinYearlyIncome      
--    , MaxYearlyIncome      
--    , Occupation      
--    , IsStudentOrRetired      
--   from #final      
--   where CID = k.RealCID      
--   for xml RAW      
--   ) as AlertDetails      
-- into #NetAnnualHigh      
-- from #kyc k      
-- where k.MaxYearlyIncome > 500000      
-- select * from DWH..Dim_Country  
-- select * from #kyc      
-- select * from #NetAnnualHigh      
-- select top 10 * from #kyc      
-- student > 30K --  
    
drop table      
      
if exists #RichStudent      
 select distinct 'OnBoarding ' as AlertCategory      
  , 'OB6: KYC - Resolve Unjustified High Income-Occupation (student)' as AlertType      
  , k.RealCID as CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct RealCID      
    , IncomeSource      
    , PEPStatus      
    , NetWorthAnswer      
    , PlayerStatusName      
    , MaxInvestAnswer      
    , MinYearlyIncome      
    , MaxYearlyIncome      
    , Occupation      
    , IsStudentOrRetired      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #kyc      
   where RealCID = k.RealCID      
   for xml RAW      
   ) as AlertDetails      
 into #RichStudent      
 from #kyc k      
 where Occupation is null      
  or Occupation = 'Student'      
  and MinYearlyIncome >= 50000  
  and TotalDepositsLifetime >= 30000    
      
-- select * from #RichStudent      
-- select top 10 * from #kyc      
      
--SELECT * FROM #Dailydepositors d WHERE d.CID = 11606547      
--SELECT * FROM #COers  d WHERE d.RealCID = 11606547      
--SELECT * FROM #kyc k WHERE k.RealCID = 11606547      
--SELECT * FROM #kycraw WHERE RealCID = 11606547      
      
drop table      
      
if exists #RetiredSalary      
 select distinct 'OnBoarding ' as AlertCategory      
  , 'OB7: KYC - Resolve Mismatch Occupation-Income (Retiree w-Salary)' as AlertType      
  , k.RealCID as CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct RealCID      
    , IncomeSource      
    , PEPStatus      
    , NetWorthAnswer      
    , PlayerStatusName      
    , MaxInvestAnswer      
    , MinYearlyIncome      
    , MaxYearlyIncome      
    , Occupation      
    , IsStudentOrRetired      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #kyc      
   where RealCID = k.RealCID      
   for xml RAW      
   ) as AlertDetails      
 into #RetiredSalary      
 from #kyc k      
 where Occupation is null      
  or Occupation = 'Retired'      
  and k.IncomeSource = 'Salary'    
  and TotalDepositsLifetime >= 30000  
      
      
-- age (young or old) > 40K --      
drop TABLE if exists #RichWeirdAge      
      
select distinct 'OnBoarding ' as AlertCategory      
  , 'OB8: KYC - Resolve Unjustified High Income- (Age)' as AlertType      
  , k.RealCID as CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct RealCID      
    , IncomeSource      
    , PEPStatus      
    , NetWorthAnswer      
    , PlayerStatusName      
    , MaxInvestAnswer      
    , MinYearlyIncome      
    , MaxYearlyIncome      
    , Occupation      
    , IsStudentOrRetired      
    , AgeRange      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #kyc      
   where RealCID = k.RealCID      
   for xml RAW      
   ) as AlertDetails      
 into #RichWeirdAge      
 from #kyc k      
 where AgeRange IN ('65+', '18-22')      
  and MinYearlyIncome >= 50000      
  and TotalDepositsLifetime >= 30000 

-- select * from #RichWeirdAge where CID = 8808286       
-- select * from #kyc where RealCID = 8808286       
      
-- tax country null and not exempt or optional --      
      
drop TABLE if exists #taxes      
      
select distinct 'OnBoarding ' as AlertCategory      
  , 'KYC - Tax/Residence Control' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct f.RealCID      
    , IncomeSource      
    , PEPStatus      
    , f.PlayerStatusName      
    , kt.TaxRequirement      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , EvMatchStatus      
  , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #kyc f      
    LEFT JOIN #kyctax kt       
     ON f.RealCID = kt.CID      
   where f.RealCID = k.CID      
   for xml RAW      
   ) as AlertDetails      
 into #taxes      
 from #final k      
  LEFT JOIN #kyctax ktax      
   ON k.CID = ktax.CID      
 WHERE  ktax.TaxRequirement = 'Mandatory'       
 AND  k.TaxCountry IS NULL       
     
-- FINRA positive --  
    

	  
-- select top 10 * from #kyc      
      
--drop TABLE if exists #FinanceSector      
      
--select distinct 'OnBoarding ' as AlertCategory      
--  , 'KYC - Forward to Compliance for MAR control (Finance Sector Employee)' as AlertType      
--  , k.RealCID as CID      
--  , @sdate [Date]      
--  , k.Regulation        , null as RelatedAccounts      
--  , k.PlayerStatusName as PlayerStatus      
--  , null as AlertStatus      
--  , null as Assigned      
--  , (      
--   select distinct RealCID      
--    , IncomeSource      
--    , PEPStatus      
--    , Occupation      
--    , NetWorthAnswer      
--    , PlayerStatusName      
--    , MaxInvestAnswer      
--    , MinYearlyIncome      
--    , MaxYearlyIncome      
--    , TotalDepositsLifetime      
--    , TotalCompensationsLifetime      
--    , EvMatchStatus      
--    , PhoneVerifiedID      
--    , IsAddressProof      
--    , IsIDProof      
--   from #kyc      
--   where RealCID = k.RealCID      
--   for xml RAW      
--   ) as AlertDetails      
-- into #FinanceSector      
-- from #kyc k      
-- where Occupation LIKE '%Financ%'      
      
-- EU country registration vs. non EU activity ---      
-- deposits --      
      
drop table      
      
if exists #EURegvsNonEUDeposit      
 select distinct 'MIMO - Deposit ' as AlertCategory      
  , 'OB14: Incoming Funds Geo Mismatch (EU reg non EU deposit)' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct CID      
    , IncomeSource      
    , PEPStatus      
    , [Country (customer)] as CountryCustomer      
    , k.IsRegCountryEU      
    , [Country By Reg IP] as CountryByRegIP      
    , Regulation      
    , BINCountry      
    , k.IsBinCountryEU      
    , BinCountryHighRisk      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #final      
   where CID = k.CID      
   for xml RAW      
   ) as AlertDetails      
 into #EURegvsNonEUDeposit      
 from #final k      
 where k.IsRegCountryEU = 1 AND (k.IsBinCountryEU = 0 OR k.BinCountryHighRisk = 1)  and BINCountry not like '%Not avail%'    
      
-- select top 10 * from #EURegvsNonEUDeposit      
      
-- COs--      
drop table      
      
if exists #EURegvsNonEUCashout      
 select distinct 'MIMO - Cashout ' as AlertCategory      
  , 'OB15: Outgoing Funds Geo Mismatch (EU reg non EU Cashout)' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct CID      
    , IncomeSource      
    , PEPStatus      
    , RegCountry as CountryCustomer      
    , CitizenshiptCountry      
    , RegCountryByIP      
    , k.RegCountryEU      
    , CashoutStatus      
    , Amount$      
    , BINCountry      
    , BinCountryHighRisk      
    , k.BinCountryEU      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #finalCOs      
   where CID = k.CID      
   for xml RAW      
   ) as AlertDetails      
 into #EURegvsNonEUCashout      
 from #finalCOs k      
 where k.RegCountryEU = 1 AND (k.BinCountryEU = 0 OR k.BinCountryHighRisk = 1) and BINCountry not like '%Not avail%' 
     
      
 -- select * from  #finalCOs      
-- COs where Bin Country is diff then Reg country --      
      
--drop table      
      
--if exists #COBinNotSameAsReg      
-- select distinct 'MIMO - Cashout ' as AlertCategory      
--  , 'Check Source of Funds (Cashout BIN <> Reg Country)' as AlertType      
--  , k.CID      
--  , @sdate [Date]      
--  , k.Regulation      
--  , null as RelatedAccounts      
--  , k.PlayerStatusName as PlayerStatus      
--  , null as AlertStatus      
--  , null as Assigned      
--  , (      
--   select distinct CID      
--    , RegCountry as CountryCustomer      
--    , CitizenshiptCountry      
--    , RegCountryByIP      
--    , CashoutStatus      
--    , Amount$      
--    , BINCountry      
--    , BinCountryHighRisk      
--   from #finalCOs      
--   where CID = k.CID      
--   for xml RAW      
--   ) as AlertDetails      
-- into #COBinNotSameAsReg      
-- from #finalCOs k      
-- where k.RegCountry <> k.BINCountry      
      
-- SELECT * FROM #finalCOs       
      
-- COs where MOP is diff than all Deposit MOPs and more than 3 Deposit MOPs --      
drop TABLE if exists #DepCOMOPMatchProblem      
      
 select distinct 'MIMO - Cashout ' as AlertCategory      
  , 'DC12: multiple MOPS - CO not conforming to Deposit' as AlertType      
  , k.CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , m.AlertDetails      
into #DepCOMOPMatchProblem      
FROM #finalCOs k      
 JOIN #countMOPs m      
  ON k.CID = m.RealCID      
      
-- select * from #DepCOMOPMatchProblem      
      
-- high risk occupation -- OB13     
drop table      
      
if exists #highRiskOccupation      
 select DISTINCT 'OnBoarding ' as AlertCategory      
  , 'OB13: KYC - High Risk Occupation' as AlertType      
  , k.RealCID as CID      
  , @sdate [Date]      
  , k.Regulation      
  , null as RelatedAccounts      
  , k.PlayerStatusName as PlayerStatus      
  , null as AlertStatus      
  , null as Assigned      
  , (      
   select distinct RealCID      
    , IncomeSource      
    , PEPStatus      
    , Occupation      
    , NetWorthAnswer      
    , PlayerStatusName      
    , MaxInvestAnswer      
    , MinYearlyIncome      
    , MaxYearlyIncome      
    , TotalDepositsLifetime      
    , TotalCompensationsLifetime      
    , EvMatchStatus      
    , PhoneVerifiedID      
    , IsAddressProof      
    , IsIDProof      
   from #kyc      
   where RealCID = k.RealCID      
   for xml RAW      
   ) as AlertDetails      
 into #highRiskOccupation      
 from #kyc k      
 where (Occupation LIKE '%Construc%' OR Occupation LIKE '%Gambl%' OR Occupation LIKE '%Real estate%' OR Occupation LIKE '%Arts%')      
		AND TotalDepositsLifetime >= 50000


      
--UPDATE #finalCOs      
--SET RegCountryHighRisk = 0, BinCountryHighRisk = 0      
--WHERE RegCountry = 'Kuwait'      
      
-- select distinct Occupation from #kyc order by 1      
-- SELECT * FROM #highRiskOccupation      
-- select * from #DepCOMOPMatchProblem      
----SELECT DISTINCT (AlertType) FROM BI_DB_AML_Daily_Alerts_History bdadah      
----SELECT TOP 1 * FROM BI_DB_AML_Daily_Alerts_History bdadah      
----SELECT * FROM #kyctax      
----SELECT * FROM #final      
----SELECT * FROM #taxes      
-- select * from #RichWeirdAge      
-- select * from #kyc      
/*************************************************************************/      
/****************   alerts flow *****************************************/      
/*************************************************************************/      
drop table if exists #alertTable
      
 select *      
 into #alertTable      
 from #lifetimedep500  WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'
union select * from #lifetimedep100 WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'
-- union select * from #depmophighrisk  WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'
-- union select * from #OBhighriskcountry  WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'
 union select * from #daily50     WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'
 union select * from #6month100K   WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'
 union select * from #12MonthExceedInvest  WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'
-- union select * from #NotExpectedCountry WHERE Regulation NOT IN  ('NFA', 'eToroUS')  AND PlayerStatus = 'Normal'    
 union select * from #tooManyCards WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'    
-- union select * from #tooManyMOPs WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'    
 union select * from #DepHighriskcountry  WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'    
-- union select * from #NetAnnualHigh WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal' -- currently not needed      
 union      
 select *      
 from #COhighriskcountry WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'      
 union      
 (      
  select co.AlertCategory      
   , co.AlertType      
   , co.CID      
   , co.Date      
   , co.Regulation COLLATE Latin1_General_100_BIN Regulation      
   , co.RelatedAccounts      
   , co.PlayerStatus      
   , co.AlertStatus      
   , co.Assigned      
   , co.AlertDetails      
  from #COhighriskcountry co WHERE Regulation NOT IN  ('NFA', 'eToroUS')  AND PlayerStatus = 'Normal'    
  )      
 union select * from #RichStudent WHERE Regulation NOT IN  ('NFA', 'eToroUS')   AND PlayerStatus = 'Normal'  
union select * from #RetiredSalary WHERE Regulation NOT IN  ('NFA', 'eToroUS')  AND PlayerStatus = 'Normal'   
 UNION select * FROM #RichWeirdAge WHERE Regulation NOT IN  ('NFA', 'eToroUS')  AND PlayerStatus = 'Normal'   
 UNION SELECT * FROM #taxes t  WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'
-- UNION SELECT * FROM #FinanceSector  WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'      
 UNION SELECT * FROM #EURegvsNonEUDeposit WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'      
 UNION SELECT * FROM #EURegvsNonEUCashout  WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'    
 UNION SELECT * FROM #highRiskOccupation WHERE Regulation NOT IN  ('NFA', 'eToroUS')  AND PlayerStatus = 'Normal'   
 UNION SELECT AlertCategory, AlertType, CID, Date, Regulation, RelatedAccounts, PlayerStatus, AlertStatus, Assigned
		, 'FINRA TRIGGER' AS AlertDetails FROM #Finra f WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'  
--UNION SELECT * FROM #Finra f WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'  
-- union SELECT * FROM #COBinNotSameAsReg WHERE Regulation NOT IN  ('NFA', 'eToroUS') AND PlayerStatus = 'Normal'     
      
-- SELECT * FROM BI_DB_AML_Daily_Alerts_History bdadah WHERE CID = 11621997 AND bdadah.AlertDate = '20190723' 
-- insert into ##times select cast(datediff(second, @sysstart, SYSDATETIME()) as varchar) + ' to populate #AlertTable'      
    
--SELECT  * FROM #alertTable WHERE AlertDetails = 'FINRA TRIGGER'
--SELECT * FROM #Finra f	
	  
drop table if exists #alertTableFinal      
      
select co.AlertCategory      
  , co.AlertType      
  , co.CID      
  , co.Date      
  , dc.FirstName + ' ' + dc.LastName as Name       
  , dc1.Name as Country      
  , at.Name as AccountType      
  , co.Regulation COLLATE Latin1_General_100_BIN Regulation      
  , isnull(cast(co.RelatedAccounts as nvarchar(max)), '') as RelatedAccounts      
  , co.PlayerStatus      
  , isnull(cast(co.AlertStatus as nvarchar(max)), '') as AlertStatus      
  , isnull(cast(co.Assigned as nvarchar(max)), '') as Assigned      
  ,  REPLACE(REPLACE(REPLACE(co.AlertDetails, '_ ', ''), '  ',''),' _','') AS AlertDetails      
  , isnull(cast(h.PreviousStatus  as nvarchar(max)), '') as PreviousStatus      
into #alertTableFinal      
from #alertTable co      
 left join DWH..Dim_Customer dc with (NOLOCK)      
  on co.CID = dc.RealCID      
 join DWH..Dim_Country dc1 with (NOLOCK)      
  on dc.CountryID = dc1.CountryID      
 join DWH..Dim_AccountType at with (NOLOCK)      
  on dc.AccountTypeID = at.AccountTypeID      
 LEFT JOIN       
  (SELECT DISTINCT AlertType, CID, MAX(AlertStatus) AS PreviousStatus      
   FROM BI_DB_AML_Daily_Alerts_History with (NOLOCK)      
   GROUP BY AlertType, CID      
   ) h      
   ON h.AlertType = co.AlertType      
   AND h.CID = co.CID      
      
-- select * from #alertTableFinal where AlertDetails is null      
      
--SELECT * FROM #mimoCIDs c WHERE c.CID IN (5270683,10410972)      
--SELECT * FROM #kyc k WHERE k.RealCID IN (5270683,10410972)      
--SELECT * FROM #Dailydepositors d WHERE CID IN (5270683,10410972)      
--SELECT * FROM #COers c WHERE RealCID IN (5270683,10410972)      
         
-- update history table with last night googlesheet -----      
      
      
delete      
from BI_DB_AML_Daily_Alerts_History      
where AlertDate = @sdate      
      
      
INSERT INTO [dbo].[BI_DB_AML_Daily_Alerts_History]      
           ([AlertID]      
           ,[AlertCategory]      
           ,[AlertType]      
           ,[CID]      
     ,[Name]       
     ,[Country]       
     ,[AccountType]      
     ,[AlertDate]      
           ,[Regulation]      
           ,[RelatedAccounts]      
           ,[PlayerStatus]      
           ,[AlertStatus]      
           ,[Assigned]      
           ,[AlertDetails]      
     ,[PreviousStatus]      
           ,[UpdateDate])      
select       
[AlertID]      
,[AlertCategory]      
,[AlertType]      
,[CID]      
,[Name]       
,[Country]       
,[AccountType]      
,[AlertDate]      
,[Regulation]      
,RelatedAccounts      
,PlayerStatus      
,AlertStatus      
,Assigned      
,AlertDetails      
,PreviousStatus      
,[UpdateDate]      
from BI_DB_AML_Daily_Alerts_From_Googlesheet      
      
-- select * from BI_DB_AML_Daily_Alerts_From_Googlesheet      
      
drop TABLE if exists #alertWithID;      
      
select  NEWID() as AlertID      
 ,al.AlertCategory      
 ,al.AlertType      
 ,al.CID      
 ,[Name]       
 ,[Country]       
 ,[AccountType]      
 ,al.Date      
 ,al.Regulation      
 ,al.RelatedAccounts      
 ,al.PlayerStatus      
 ,al.AlertStatus      
 ,al.Assigned      
 ,al.AlertDetails      
 ,al.PreviousStatus      
 ,getdate() as UpdateDate      
into #alertWithID      
from #alertTableFinal al      
      
       
 -- select * from #alertWithID      
       
      
truncate table BI_DB_AML_Daily_Alerts      
      
INSERT INTO [dbo].[BI_DB_AML_Daily_Alerts]      
           ([AlertID]      
           ,[AlertCategory]      
           ,[AlertType]      
           ,[CID]      
           ,[Name]      
           ,[Country]      
           ,[AccountType]      
           ,[AlertDate]      
           ,[Regulation]      
           ,[RelatedAccounts]      
           ,[PlayerStatus]      
           ,[AlertStatus]      
           ,[Assigned]      
          ,[AlertDetails]      
           ,[PreviousStatus]      
           ,[UpdateDate])      
      
select AlertID      
 , tb.AlertCategory      
 , tb.AlertType      
 , tb.CID      
 ,tb.[Name]       
 ,tb.[Country]       
 ,tb.[AccountType]      
 ,tb.[Date]      
 ,tb.Regulation      
 ,tb.RelatedAccounts      
 ,tb.PlayerStatus      
 ,tb.AlertStatus      
 ,h.Assigned      
 ,tb.AlertDetails      
 ,h.PreviousStatus as PreviousStatus      
 ,tb.UpdateDate      
FROM  #alertWithID tb      
 LEFT JOIN       
  (SELECT DISTINCT AlertType, CID, MAX(CASE WHEN AlertStatus <> 'NULL' THEN AlertStatus end) AS PreviousStatus,  MAX(Assigned) AS Assigned      
   FROM BI_DB_AML_Daily_Alerts_History with (NOLOCK)      
   GROUP BY AlertType, CID      
   ) h      
   ON h.AlertType = tb.AlertType      
   AND h.CID = tb.CID      
WHERE tb.Regulation <> 'BVI'      
-- WHERE h.PreviousStatus <> 'Done' OR h.PreviousStatus IS null   

DELETE FROM BI_DB_AML_Daily_Alerts
WHERE AlertType = 'OB12: FINRA - Is Positve' AND PreviousStatus in ('Done', 'DONE')

END      