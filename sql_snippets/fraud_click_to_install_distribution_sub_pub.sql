create or replace view hour_diff as


select 
app_id, network_name, network_publisher, network_sub_publisher, country_code,
install_time, raw_data ->> 'Click Time' as click_time, install_time - cast(raw_data ->> 'Click Time' as timestamp) as diff, 
extract(epoch from install_time) as install_epoch, 
extract(epoch from cast(raw_data ->> 'Click Time' as timestamp)) as click_epoch,
(extract(epoch from install_time) - extract(epoch from cast(raw_data ->> 'Click Time' as timestamp)))/3600 as hour_diff,
	CASE WHEN
	(extract(epoch from install_time) - extract(epoch from cast(raw_data ->> 'Click Time' as timestamp)))/3600 <=1
	THEN 'first_hour'
	ELSE
	CASE WHEN
	(extract(epoch from install_time) - extract(epoch from cast(raw_data ->> 'Click Time' as timestamp)))/3600 <=24
	THEN 'first_day'
	ELSE
	CASE WHEN
	(extract(epoch from install_time) - extract(epoch from cast(raw_data ->> 'Click Time' as timestamp)))/3600 <=48
	THEN 'second_day'
	ELSE
	CASE WHEN
	(extract(epoch from install_time) - extract(epoch from cast(raw_data ->> 'Click Time' as timestamp)))/3600 <=72
	THEN 'third_day'
	ELSE 'more_than_3_days'

	END END END END  as classification
from apps_flyer_data
where cast(raw_data ->> 'Click Time' as timestamp) >= current_date - interval '7 days'
and source_provider_id not in (3);
 

select a.name, hd.app_id, hd.network_name, hd.network_publisher, hd. network_sub_publisher, hd.country_code, hd.classification, count(hd.classification) as total_count
from hour_diff hd, apps a
where hd.app_id = a.id
group by 1,2,3,4,5,6,7;

drop view hour_diff


