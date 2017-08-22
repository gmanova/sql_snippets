create or replace view pivot_test as 

-- creates a view of entities with classification of time group

 SELECT botinstall.app_id,
    botinstall.network_name,
    botinstall.network_publisher,
    botinstall.network_sub_publisher,
    botinstall.classification,
    count(botinstall.app_id) AS total_installs
   FROM ( select 
	app_id, 
	network_name, 
	network_publisher, 
	network_sub_publisher, 
	CAST(raw_data ->> 'Click Time' as TIMESTAMP) as click_time, 
	install_time,
	(install_time-CAST(raw_data ->> 'Click Time' as TIMESTAMP)) as diff, 
	EXTRACT (epoch from (install_time-CAST(raw_data ->> 'Click Time' as TIMESTAMP))) as sec_diff, 
	 CASE WHEN
	 EXTRACT (epoch from (install_time-CAST(raw_data ->> 'Click Time' as TIMESTAMP)))<=30
	 THEN '<30'
	 ELSE
	 CASE WHEN 
	 EXTRACT (epoch from (install_time-CAST(raw_data ->> 'Click Time' as TIMESTAMP)))<=120
	 THEN '<120' 
   	ELSE '>120'
	 END END as classification
	 from apps_flyer_data where app_id in (1,2,3) and install_time >= current_date - interval '7 days') botinstall
 	 GROUP BY botinstall.app_id, botinstall.network_name, botinstall.network_publisher, botinstall.network_sub_publisher, botinstall.classification;

-- creates a pivot table counting the instances in each classification per entity as a 2nd view so the code will not be impossibly long

create or replace view pivot_test_2 as

select app_id, 
network_name, 
network_publisher, 
network_sub_publisher, 
sum (total_installs) as total_installs,
	(
	select sum(total_installs)
 	from pivot_test pt2 
	where classification = '>120' 
	and pt1.app_id = pt2.app_id
	and pt1.network_name = pt2.network_name
	and pt1.network_publisher = pt2.network_publisher
	and pt1.network_sub_publisher = pt2.network_sub_publisher
	) as ">120",
	(
	select sum(total_installs)
 	from pivot_test pt2 
	where classification = '<120' 
	and pt1.app_id = pt2.app_id
	and pt1.network_name = pt2.network_name
	and pt1.network_publisher = pt2.network_publisher
	and pt1.network_sub_publisher = pt2.network_sub_publisher
	) as "<120",  
	(
	select sum(total_installs)
 	from pivot_test pt2 
	where classification = '<30' 
	and pt1.app_id = pt2.app_id
	and pt1.network_name = pt2.network_name
	and pt1.network_publisher = pt2.network_publisher
	and pt1.network_sub_publisher = pt2.network_sub_publisher
	) as "<30"
from pivot_test pt1
group by 1,2,3,4;

select pt2.*, sum(pt2."<30")/sum(pt2.total_installs) as "<30_volume", a.name from pivot_test_2 pt2, apps a
where pt2.app_id = a.id
group by 1,2,3,4,5,6,7,8,10;


drop view pivot_test_2;
drop view pivot_test;