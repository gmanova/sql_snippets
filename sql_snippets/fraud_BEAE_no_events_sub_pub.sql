create or replace view be_no_events as

select
be.app_id, 
be.app_name,
 be.country_code, 
 be.media_source, 
 be.campaign, 
 max(
   CASE
   WHEN ((be.alt_event_name)::text = 'installs'::text) THEN be.total
   ELSE NULL::numeric
	END) AS installs,
max(
   CASE
   WHEN ((be.alt_event_name)::text = 'events'::text) THEN be.total
   ELSE NULL::numeric
   END) AS events 

from
(
select app_id, 
app_name, country_code, 
media_source, 
campaign, 
	case when event_name = 'installs'
	then 'installs'
	else 'events'
	end as alt_event_name,
sum("count") as total
from bime_export_aggregated_events 
where 
event_name 
not in ('impressions', 'clicks','conversions', 'total_revenue') 
and date >= current_date - interval '5 days'
and media_source not in ('googleadwords_int', 'Facebook Ads')
group by 1,2,3,4,5,6
) be

group by 1,2,3,4,5;

select * from be_no_events 

where installs >=5
and events = 0 
or 
installs >=5
and events is null 
and media_source != 'Organic'

