use BI_DEV

GO
/****** Object:  StoredProcedure [dbo].[SP_Matching_Wire_Cashouts_BOToProvider]    Script Date: 7/4/2018 9:49:47 AM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- drop procedure if exists [dbo].[SP_Matching_Wire_Cashouts_BOToProvider]
ALTER PROCEDURE [dbo].[SP_Matching_Wire_Cashouts_BOToProvider] @month int, @year int
AS
/********************************************************************************************
Author:      Guy Manova	
Date:        2018-07-04	
Description:  matching wire deposits from csvs - Cashouts, BO side to Provider side 

**************************
** Change History
**************************
Date         Author       Description 

*/


--declare @month int = 4
--declare @year int = 2018
declare @monthStart date = DATEFROMPARTS(@year, @month, 1)
declare @monthEnd date = DATEFROMPARTS(@year, @month, DAY(EOMONTH(DATEFROMPARTS(@year, @month, 1))))
declare @couttsStart date = dateadd(day,-5,@monthStart)
declare @couttsEnd date = dateadd(day,15,@monthEnd)
declare @BOStart date = @monthStart
declare @BOEnd date = @monthEnd

-- select * from dbo.Matching_Wires_BO_Side
-- select * from dbo.Matching_Wires_Coutts_Side 

drop table if exists #bo
select Date, Withdraw_Processing_ID, Amount, Currency, CID, WithdrawID, BOName1,BOName2,BOName3,BOName4,BOName5 
into #bo 
from dbo.Matching_Wires_BO_Side 
where Date >= @monthStart and Date <= @monthEnd

drop table if exists #coutts
select Date, Description, Currency, Amount, couttsName1, couttsName2,couttsName3,couttsName4, CID 
into #coutts 
from dbo.Matching_Wires_Coutts_Side 
where Date >= @couttsStart and Date <= @couttsEnd


----- fixing import problem of non latin charecters on BO side --------
drop table if exists #nonames

select distinct CID, BOName1, BOName2, BOName3 
into #nonames
from Matching_Wires_BO_Side 
where BOName1 like '%?%' or BOName2 like '%?%' or BOName3 like '%?%' or BOName4 like '%?%' or BOName5 like '%?%'

-- select * from #nonames
-- select * from #bo where CID = 6027138

drop table if exists #bo1

;with "namefix" as
(
select nn.*, dc.FirstName, dc.LastName 
from #nonames nn
left join 
DWH.dbo.Dim_Customer dc
on
nn.CID = dc.RealCID
)
select bo.*, nf.FirstName, nf.LastName
into #bo1
from #bo bo
left join "namefix" nf
on bo.CID = nf.CID


-- select  * from #bo1 where CID = 5634239


alter table  #bo1
alter column BOName1 nvarchar(max)
alter table  #bo1
alter column BOName2 nvarchar(max)



update #bo1 
set BOName1 = FirstName 
where FirstName is not null 

update #bo1 
set	BOName2 = LastName
where FirstName is not null


-- select  * from #bo1 where CID = 5634239
---  this is a dummy step to bypass a bug which prevents creating #bo again in a proc ------

drop table if exists #bo3

select Date, Withdraw_Processing_ID, Amount, Currency, CID, WithdrawID, BOName1, BOName2, BOName3, BOName4, BOName5 
into #bo3 from #bo1 

 --drop table if exists #bo1
 --GO
-- select * from #bo where CID = 5634239

--------  first match: on CID where available, currency and amount, when joined date is not null = match, otherwise non matched -------

drop table if exists #match1

select 
	b.*,
	c.Date as cDate, 
	c.Description, 
	c.Currency as cCurrency,
	c.Amount as cAmount, 
	c.couttsName1, 
	c.couttsName2, 
	c.couttsName3, 
	c.couttsName4
into #match1
from #bo3 b
left join
#coutts c
on
b.CID = c.CID
and b.Currency = c.Currency
and b.Amount = c.Amount
where c.Date is not null

-- select * from #match1
-- select count (distinct Withdraw_Processing_ID) from #match1
-- select * from #coutts
-- select * from #nonmatch1


--------  first nonmatch: what's not matched -------

drop table if exists #nonmatch1

select 
	b.*
into #nonmatch1
from #bo3 b
left join
#coutts c
on
b.CID = c.CID
and b.Currency = c.Currency
and b.Amount = c.Amount
where c.Date is  null

-- select * from #nonmatch1  where CID = 5634239

--------  setting dummy texts instead of empty strings -------

update #nonmatch1 
set BOName1 = 'dummy1' where BOName1 = '' or BOName1 like '%?%'
update #nonmatch1
set BOName2 = 'dummy1' where BOName2 = '' or BOName2 like '%?%'
update #nonmatch1 
set BOName3 = 'dummy1' where BOName3 = '' or BOName3 like '%?%'
update #nonmatch1 
set BOName4 = 'dummy1' where BOName4 = '' or BOName4 like '%?%'
update #nonmatch1 
set BOName5 = 'dummy1' where BOName5 = '' or BOName5 like '%?%'

-- select * from #nonmatch1  where CID = 5634239

update #coutts
set couttsName1 = 'dummy2' where couttsName1 = ''
update #coutts
set couttsName2 = 'dummy2' where couttsName2 = ''
update #coutts
set couttsName3 = 'dummy2' where couttsName3 = ''
update #coutts
set couttsName4 = 'dummy2' where couttsName4 = ''


--------  match 2: matching on amount, currency, and any 2 or more name matches -------

drop table if exists #match2prep

;with "match2" as
(
select n.*,
	c.Date as cDate,
	c.Currency as cCurrency, 
	c.Amount as cAmount,
	c.Description, 
	c.couttsName1, 
	c.couttsName2, 
	c.couttsName3, 
	c.couttsName4,
	case when c.couttsName1 COLLATE Latin1_General_100_BIN= n.BOName1 or c.couttsName1 COLLATE Latin1_General_100_BIN= n.BOName2 or c.couttsName1 COLLATE Latin1_General_100_BIN= n.BOName3  or c.couttsName1 COLLATE Latin1_General_100_BIN= n.BOName4  or c.couttsName1 COLLATE Latin1_General_100_BIN= n.BOName5 then 1 else 0 end as ApproxMatch1,
	case when c.couttsName2 COLLATE Latin1_General_100_BIN= n.BOName1 or c.couttsName2 COLLATE Latin1_General_100_BIN= n.BOName2 or c.couttsName2 COLLATE Latin1_General_100_BIN= n.BOName3  or c.couttsName2 COLLATE Latin1_General_100_BIN= n.BOName4  or c.couttsName2 COLLATE Latin1_General_100_BIN= n.BOName5 then 1 else 0 end as ApproxMatch2,
	case when c.couttsName3 COLLATE Latin1_General_100_BIN= n.BOName1 or c.couttsName3 COLLATE Latin1_General_100_BIN= n.BOName2 or c.couttsName3 COLLATE Latin1_General_100_BIN= n.BOName3  or c.couttsName3 COLLATE Latin1_General_100_BIN= n.BOName4  or c.couttsName3 COLLATE Latin1_General_100_BIN= n.BOName5 then 1 else 0 end as ApproxMatch3,
	case when c.couttsName4 COLLATE Latin1_General_100_BIN= n.BOName1 or c.couttsName4 COLLATE Latin1_General_100_BIN= n.BOName2 or c.couttsName4 COLLATE Latin1_General_100_BIN= n.BOName3  or c.couttsName4 COLLATE Latin1_General_100_BIN= n.BOName4  or c.couttsName4 COLLATE Latin1_General_100_BIN= n.BOName5 then 1 else 0 end as ApproxMatch4
from #nonmatch1 n
left join 
#coutts c
on 
n.Amount = c.Amount 
and n.Currency = c.Currency
)
select *, 
	case when ApproxMatch1 + ApproxMatch2 + ApproxMatch3 + ApproxMatch4 > 1 then 1 else 0 end as ExactMatch 
	into #match2prep
	from "match2"

-- select * from #match2prep


--------  match 2: 2 or more approx matches = exact match -------

drop table if exists #match2

select * 
into #match2
from #match2prep
where ExactMatch = 1

-- select * from #match2
-- select * from #match2prep where ApproxMatch1 + ApproxMatch2 + ApproxMatch3 + ApproxMatch4 = 1 

--------  non match 2: whats not in match 2, deduplicate -------

drop table if exists #nonmatch2

select Date, Withdraw_Processing_ID, max(Amount) Amount, Currency, CID, WithdrawID, 
			BOName1, BOName2, BOName3, BOName4, BOName5 
into #nonmatch2
from #match2prep
where ExactMatch = 0
group by Date, Withdraw_Processing_ID, Currency, CID, WithdrawID, 
			BOName1, BOName2, BOName3, BOName4, BOName5 

-- select * from #nonmatch2 where CID = 5634239

--------  non match 3: aggregate both sides to check for split payments -------
--------  step 1: select only multy-payment CIDs from BO side (per currency) ----------------

drop table if exists #multiTxCID
;with "nonmatch3" as
(
select *, 
		ROW_NUMBER() over (partition by CID, Currency order by CID) as Ranking
from #nonmatch2
)
select CID 
into #multiTxCID
from "nonmatch3"  
group by CID, Currency having max(Ranking) > 1



-- select * from #bo where Amount = 49975.00 
-- select * from #coutts where Amount = 49975.00 

--------  step 3: select transactions of those CIDs, group,and collect the IDs and Amounts in cells for further investigation  ----------------

drop table if exists #match3prep

;with "table" as
(
select  Currency,  CID, BOName1, BOName2, BOName3, BOName4, BOName5,
		sum(Amount) Amount
from #nonmatch2
where CID in (select * from #multiTxCID)
group by  Currency, CID, BOName1, BOName2, BOName3, BOName4, BOName5
), 
"list" as 
( 
SELECT 
   n2.CID, n2.Currency,
   (SELECT '; ' + cast(Withdraw_Processing_ID as varchar (10))
    FROM #nonmatch2 n3
	where n2.CID = n3.CID and n2.Currency = n3.Currency
    FOR XML PATH('')) as WP_IDs,
	(SELECT '; ' + cast(WithdrawID as varchar (10))
    FROM #nonmatch2 n3
	where n2.CID = n3.CID and n2.Currency = n3.Currency
    FOR XML PATH('')) as WithdrawIDs,
	(SELECT '; ' + cast(Amount as varchar (10))
    FROM #nonmatch2 n3
	where n2.CID = n3.CID and n2.Currency = n3.Currency
    FOR XML PATH('')) as TX_Amounts
FROM #nonmatch2 n2
join #nonmatch2 n3
on n2.CID = n3.CID and n2.Currency = n3.Currency
GROUP BY n2.CID, n3.CID, n2.Currency, n3.Currency
)
select t.*, l.WP_IDs, l.WithdrawIDs, l.TX_Amounts 
into #match3prep
from "table" t
left join 
list l
on t.CID = l.CID and t.Currency = l.Currency

-- select * from #match3prep where CID = 6407323
-- select * from #coutts where Currency = 'CAD' and  Description like '%Anna%'

--------  step 2: use the approximation on the grouped by CIDs BO side and Coutts side  ----------------

drop table if exists #match4prep

;with "coutts2" as
(
	select Description, Currency, couttsName1, couttsName2, couttsName3, couttsName4,  Sum(Amount) as TotalAmount
	from #coutts
	group by  Description, Currency, couttsName1, couttsName2, couttsName3, couttsName4 
),
"boGrouped" as
(
	select  CID, Currency, BOName1, BOName2, BOName3, BOName4, BOName5, sum(Amount) as TotalAmount, WP_IDs as Withdraw_Processing_ID, WithdrawIDs as WithdrawID, TX_Amounts 
	from #match3prep -- where CID = 6407323
	group by  CID, Currency, BOName1, BOName2, BOName3, BOName4, BOName5, WP_IDs, WithdrawIDs, TX_Amounts 
 )
select b.*, couttsName1, c.couttsName2, c.couttsName3, c.couttsName4, c.TotalAmount as cTotalAmount, c.Description, c.Currency as cCurrency,
	case when c.couttsName1 COLLATE Latin1_General_100_BIN= b.BOName1 or c.couttsName1 COLLATE Latin1_General_100_BIN= b.BOName2 or c.couttsName1 COLLATE Latin1_General_100_BIN= b.BOName3  or c.couttsName1 COLLATE Latin1_General_100_BIN= b.BOName4  or c.couttsName1 COLLATE Latin1_General_100_BIN= b.BOName5 then 1 else 0 end as ApproxMatch1,
	case when c.couttsName2 COLLATE Latin1_General_100_BIN= b.BOName1 or c.couttsName2 COLLATE Latin1_General_100_BIN= b.BOName2 or c.couttsName2 COLLATE Latin1_General_100_BIN= b.BOName3  or c.couttsName2 COLLATE Latin1_General_100_BIN= b.BOName4  or c.couttsName2 COLLATE Latin1_General_100_BIN= b.BOName5 then 1 else 0 end as ApproxMatch2,
	case when c.couttsName3 COLLATE Latin1_General_100_BIN= b.BOName1 or c.couttsName3 COLLATE Latin1_General_100_BIN= b.BOName2 or c.couttsName3 COLLATE Latin1_General_100_BIN= b.BOName3  or c.couttsName3 COLLATE Latin1_General_100_BIN= b.BOName4  or c.couttsName3 COLLATE Latin1_General_100_BIN= b.BOName5 then 1 else 0 end as ApproxMatch3,
	case when c.couttsName4 COLLATE Latin1_General_100_BIN= b.BOName1 or c.couttsName4 COLLATE Latin1_General_100_BIN= b.BOName2 or c.couttsName4 COLLATE Latin1_General_100_BIN= b.BOName3  or c.couttsName4 COLLATE Latin1_General_100_BIN= b.BOName4  or c.couttsName4 COLLATE Latin1_General_100_BIN= b.BOName5 then 1 else 0 end as ApproxMatch4
into #match4prep
from 
boGrouped b
left join 
coutts2 c
on 
b.TotalAmount = c.TotalAmount
and b.Currency = c.Currency


drop table if exists #match3

select *
into #match3
from #match4prep
where ApproxMatch1 + ApproxMatch2 + ApproxMatch3 + ApproxMatch4 > 1

-- select * from #match3
-- select * from #match4prep where CID = 5634239

drop table if exists #approxmatch

select * 
into #approxmatch
from #match4prep where ApproxMatch1 + ApproxMatch2 + ApproxMatch3 + ApproxMatch4 =1

drop table if exists #approxmatch2

select * 
into #approxmatch2
from #match2prep 
where ApproxMatch1 + ApproxMatch2 + ApproxMatch3 + ApproxMatch4 = 1 

-- select * from #approxmatch
-- select * from #approxmatch2


drop table if exists #unmatchedGrouped

select distinct CID, Withdraw_Processing_ID, WithdrawID, TX_Amounts, Currency,
		BOName1,BOName2, BOName3,BOName4,BOName5
into #unmatchedGrouped
from  #match4prep 
where ApproxMatch1 + ApproxMatch2 + ApproxMatch3 + ApproxMatch4 = 0

-- select * from #unmatchedGrouped  where CID = 5634239



----------   create complete list of all matched  ----------------------------
drop table if exists #matchedFinal

;with "final" as
(
select Date, cast(Withdraw_Processing_ID as varchar (500)) as Withdraw_Processing_ID, cast(Amount as varchar(500)) as Amount, Currency, CID, cast(WithdrawID as varchar (500)) as WithdrawID, BOName1, BOName2, BOName3, BOName4, BOName5, 
			cDate, Description, cCurrency, cAmount, couttsName1, couttsName2, couttsName3, couttsName4, 'CID_Exact' as MatchType  
from #match1
union
select Date, cast(Withdraw_Processing_ID as varchar (500)), cast(Amount as varchar(500)), Currency, CID, cast(WithdrawID as varchar (500)), BOName1, BOName2, BOName3, BOName4, BOName5, 
			cDate, Description, cCurrency, cAmount, couttsName1, couttsName2, couttsName3, couttsName4, 'Name_Exact' as MatchType from #match2
union
select '2000-01-01' as Date, Withdraw_Processing_ID, TX_Amounts, Currency, CID, WithdrawID, BOName1, BOName2, BOName3, BOName4, BOName5, 
			'2000-01-01' as cDate, Description, cCurrency, cTotalAmount, couttsName1, couttsName2, couttsName3, couttsName4, 'MultiTX_Exact' as MatchType from #match3
union
select '2000-01-01' as Date, Withdraw_Processing_ID, TX_Amounts, Currency, CID, WithdrawID, BOName1, BOName2, BOName3, BOName4, BOName5, 
			'2000-01-01' as cDate, Description, cCurrency, cTotalAmount, couttsName1, couttsName2, couttsName3, couttsName4, 'Multi_TX_Approx' as MatchType from #approxmatch
union
select Date, cast(Withdraw_Processing_ID as varchar (500)), cast(Amount as varchar(500)), Currency, CID, cast(WithdrawID as varchar (500)), BOName1, BOName2, BOName3, BOName4, BOName5, 
			cDate, Description, cCurrency, cAmount, couttsName1, couttsName2, couttsName3, couttsName4, 'Name_Approx' as MatchType from #approxmatch2
)
select distinct Date, Withdraw_Processing_ID, Amount, Currency, CID,WithdrawID, BOName1, BOName2, BOName3, BOName4, BOName5,
				cDate, Description, cCurrency, cAmount, couttsName1, couttsName2, couttsName3, couttsName4, MatchType 
into #matchedFinal
from "final"

select * from #matchedFinal
select * from [dbo].[BI_DB_WireCashouts_Matched_BoToProvider]


----------   create complete list of all non-matched  ----------------------------

-------- list of all tx IDs which are either exact or approximate matched ---------

drop table if exists #allMatchedTXID

select Withdraw_Processing_ID 
into #allMatchedTXID 
from #match1
union 
select Withdraw_Processing_ID from #match2
union
select Withdraw_Processing_ID from #approxmatch2
union
SELECT   value 
FROM #unmatchedGrouped 
 CROSS APPLY STRING_SPLIT(Withdraw_Processing_ID, ';')


--------      unmatched left after all match iterations      --------------------

drop table if exists #unmatchedFinal

select distinct Date, Withdraw_Processing_ID, Amount, Currency, CID, WithdrawID, BOName1, BOName2, BOName3, BOName4, BOName5 
into #unmatchedFinal
from #bo 
where Withdraw_Processing_ID not in (select * from #allMatchedTXID)

select * from #matchedFinal 
select * from #unmatchedFinal

 ------ final writes to tables ------

truncate table [dbo].[BI_DB_WireCashouts_Matched_BoToProvider]

insert into [dbo].[BI_DB_WireCashouts_Matched_BoToProvider]
select Date,
Withdraw_Processing_ID,Amount,Currency,CID,WithdrawID,BOName1,BOName2,BOName3,BOName4,BOName5,
		cDate,Description,cCurrency,cAmount,couttsName1,couttsName2,couttsName3,couttsName4,MatchType, getdate() as UpdateDate
from  #matchedFinal

truncate table [dbo].[BI_DB_WireCashouts_NonMatched_BoToProvider]

insert into [dbo].[BI_DB_WireCashouts_NonMatched_BoToProvider]
select Date,Withdraw_Processing_ID,Amount,Currency,CID,WithdrawID,BOName1,BOName2,BOName3,BOName4,BOName5, getdate() as UpdateDate
from #unmatchedFinal

