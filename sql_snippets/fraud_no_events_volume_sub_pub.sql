
create or replace view no_events as

select installs.app_id,
installs.country_code,
installs.network_name,
installs.network_publisher,
installs.network_sub_publisher, 
installs.installs, 
events.events

from

(
select app_id, 
country_code, 
network_name, 
network_publisher, 
network_sub_publisher, 
count(install_time) as installs
from apps_flyer_data
where
install_time > current_date - interval '7 days'
group by 1,2,3,4,5
) 
as installs

left join

(
select  app_id, 
country_code, 
network_name, 
network_publisher, 
network_sub_publisher, 
 count(install_time) as events
from apps_flyer_events
where 
install_time > current_date - interval '7 days'

group by 1,2,3,4,5
) as events

on 
installs.app_id = events.app_id
and
installs.country_code = events.country_code
and
installs.network_name = events.network_name
and
installs.network_publisher = events.network_publisher
and
installs.network_sub_publisher = events.network_sub_publisher

group by 1,2,3,4,5,6,7;

select app_id, network_name, network_publisher, network_sub_publisher, installs, events
from no_events
where installs >=10 
and events is null 
order by 1,2,5

