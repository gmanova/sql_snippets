create or replace view dupe_ip as

select app_id, 
network_name, 
network_publisher, 
network_sub_publisher, 
country_code, count(ip) as total_ips, 
count(distinct(ip)) as distinct_ips
from apps_flyer_data 
where 
install_time >= current_date - interval '2 days'
and source_provider_id not in (3) 
group by 1,2,3,4,5;

select 
a.name, 
di.*, 
cast(di.distinct_ips as numeric)/cast(di.total_ips as numeric) as ratio  
from dupe_ip di, apps a
where cast(di.distinct_ips as numeric)/cast(di.total_ips as numeric) <=0.90
and total_ips >=20
and di.app_id = a.id;

drop view dupe_ip
