SELECT agg_events.date,
	agg_events.app_id,
	agg_events.app_name,
	agg_events.media_source,
	agg_events.country_code,
	agg_events.os,
	agg_events.media,
	agg_events.campaign_type,
	agg_events.event_name,
	sum(agg_events.agg_installs) AS totals,
	mrs_fin.installs AS fin_installs,
	mrs_fin.spend
	FROM (( SELECT
		CASE
		WHEN ((bime_export_aggregated_events.media_source)::text ~~ '%google%'::text) THEN 'googleadwords'::text
		WHEN ((bime_export_aggregated_events.media_source)::text ~~ '%Organic%'::text) THEN 'organic'::text
		WHEN ((bime_export_aggregated_events.media_source)::text ~~ '%twitter%'::text) THEN 'twitter'::text
		WHEN (((bime_export_aggregated_events.campaign)::text ~~ '%Instagram%'::text) OR ((bime_export_aggregated_events.campaign)::text ~~ '%/_lg%'::text) OR (						(bime_export_aggregated_events.campaign)::text ~~ '%/_lG%'::text)) THEN 'instagram'::text
		WHEN ((bime_export_aggregated_events.media_source)::text ~~ '%Face%'::text) THEN 'facebook'::text
		ELSE 'media buy'::text
	END AS media,
		CASE
		WHEN ((bime_export_aggregated_events.campaign)::text = 'Burst'::text) THEN 'burst'::text
		WHEN ((bime_export_aggregated_events.campaign)::text = 'burst'::text) THEN 'burst'::text
		WHEN ((bime_export_aggregated_events.campaign)::text ~~ '%Re-%'::text) THEN 'retargeting'::text
		WHEN ((bime_export_aggregated_events.campaign)::text ~~ '%Re_%'::text) THEN 'retargeting'::text
		WHEN ((bime_export_aggregated_events.campaign)::text ~~ '%gagement%'::text) THEN 'retargeting'::text
		WHEN ((bime_export_aggregated_events.campaign)::text ~~ '%targeting%'::text) THEN 'retargeting'::text
	ELSE 'performance'::text
	END AS campaign_type,
	bime_export_aggregated_events.date,
	bime_export_aggregated_events.app_id,
	bime_export_aggregated_events.media_source,
	bime_export_aggregated_events.app_name,
	bime_export_aggregated_events.country_code,
	bime_export_aggregated_events.os,
	bime_export_aggregated_events.event_name,
	sum(bime_export_aggregated_events.count) AS agg_installs
	FROM bime_export_aggregated_events
		WHERE ((bime_export_aggregated_events.app_id = ANY (ARRAY[78])) 
		AND (bime_export_aggregated_events.date >= (('now'::text)::date - '93 days'::interval))
		AND ((bime_export_aggregated_events.event_name)::text = ANY (ARRAY[('impressions'::character varying)::text, 
	('clicks'::character varying)::text, 
	('installs'::character varying)::text, 
	('total_revenue'::character varying)::text, 
	('created account (Unique users)'::character varying)::text, 
	('14 day trial started (Unique users)'::character varying)::text, 
	('1 week pass started (Unique users)'::character varying)::text, 
	('subscription started (Unique users)'::character varying)::text, 
	('started workout (Event counter)'::character varying)::text, 
	('finished workout (Event counter)'::character varying)::text,
	('conversions'::character varying)::text])) 
	AND ((bime_export_aggregated_events.country_code)::text = ANY (ARRAY['US'::text])))
	GROUP BY
		CASE
		WHEN ((bime_export_aggregated_events.media_source)::text ~~ '%google%'::text) THEN 'googleadwords'::text
		WHEN ((bime_export_aggregated_events.media_source)::text ~~ '%Organic%'::text) THEN 'organic'::text
		WHEN ((bime_export_aggregated_events.media_source)::text ~~ '%twitter%'::text) THEN 'twitter'::text
		WHEN (((bime_export_aggregated_events.campaign)::text ~~ '%Instagram%'::text) OR ((bime_export_aggregated_events.campaign)::text ~~ '%/_lg%'::text) OR (						(bime_export_aggregated_events.campaign)::text ~~ '%/_lG%'::text)) THEN 'instagram'::text
		WHEN ((bime_export_aggregated_events.media_source)::text ~~ '%Face%'::text) THEN 'facebook'::text
		ELSE 'media buy'::text
	END,
		CASE
		WHEN ((bime_export_aggregated_events.campaign)::text = 'Burst'::text) THEN 'burst'::text
		WHEN ((bime_export_aggregated_events.campaign)::text = 'burst'::text) THEN 'burst'::text
		WHEN ((bime_export_aggregated_events.campaign)::text ~~ '%Re-%'::text) THEN 'retargeting'::text
		WHEN ((bime_export_aggregated_events.campaign)::text ~~ '%Re_%'::text) THEN 'retargeting'::text
		WHEN ((bime_export_aggregated_events.campaign)::text ~~ '%gagement%'::text) THEN 'retargeting'::text
		WHEN ((bime_export_aggregated_events.campaign)::text ~~ '%targeting%'::text) THEN 'retargeting'::text
		ELSE 'performance'::text
	END, 
	bime_export_aggregated_events.date, 
	bime_export_aggregated_events.media_source, 
	bime_export_aggregated_events.app_id, 
	bime_export_aggregated_events.app_name, 
	bime_export_aggregated_events.country_code, 
	bime_export_aggregated_events.os, 
	bime_export_aggregated_events.event_name) agg_events
	LEFT JOIN ( SELECT xxx_mrs.app_id,
	xxx_mrs.app_name,
	xxx_mrs.network_name,
	xxx_mrs.country_code,
	xxx_mrs.install_date,
	xxx_mrs.os,
		CASE
		WHEN ((xxx_mrs.network_type)::text = 'Incent'::text) THEN 'burst'::text
		WHEN ((xxx_mrs.network_publisher)::text ~~ '%burst%'::text) THEN 'burst'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%burst%'::text) THEN 'burst'::text
		WHEN ((xxx_mrs.network_publisher)::text ~~ '%Burst%'::text) THEN 'burst'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%Burst%'::text) THEN 'burst'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%Re-%'::text) THEN 'retargeting'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%Re_%'::text) THEN 'retargeting'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%gagement%'::text) THEN 'retargeting'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%targeting%'::text) THEN 'retargeting'::text
		ELSE 'performance'::text
	END AS campaign_type,
	'media buy'::text AS media,
	sum(xxx_mrs.installs) AS installs,
	round((sum((xxx_mrs.spend * (((1)::numeric + (xxx_mrs.markup_percent / (100)::numeric)))::double precision)))::numeric, 2) AS spend
FROM ( SELECT inner_select.id,
	inner_select.app_id,
	inner_select.network_name,
	inner_select.network_publisher,
	inner_select.network_sub_publisher,
	inner_select.country_code,
	inner_select.country_id,
	inner_select.install_date,
	inner_select.installs,
	inner_select.app_name,
	inner_select.os,
	inner_select.network_type,
	inner_select.cpi,
	inner_select.spend,
	inner_select.created_at,
	inner_select.updated_at,
	inner_select.c_m,
	inner_select.d_m,
		CASE
		WHEN (inner_select.c_m IS NOT NULL) THEN inner_select.c_m
		WHEN (inner_select.d_m IS NOT NULL) THEN inner_select.d_m
		ELSE NULL::numeric
	END AS markup_percent
FROM ( SELECT bime_export_installs.id,
	bime_export_installs.app_id,
	bime_export_installs.network_name,
	bime_export_installs.network_publisher,
	bime_export_installs.network_sub_publisher,
	bime_export_installs.country_code,
	bime_export_installs.country_id,
	bime_export_installs.install_date,
	bime_export_installs.installs,
	bime_export_installs.app_name,
	bime_export_installs.os,
	bime_export_installs.network_type,
	bime_export_installs.cpi,
	bime_export_installs.spend,
	bime_export_installs.created_at,
	bime_export_installs.updated_at,
	custom_markups.markup_percent AS c_m,
	default_markups.markup_percent AS d_m
FROM ((((bime_export_installs
	JOIN apps_flyer_network_names 
		ON (((bime_export_installs.network_name)::text = (apps_flyer_network_names.name)::text)))
	JOIN apps_flyer_networks
		ON (((bime_export_installs.app_id = apps_flyer_networks.app_id) 
 	AND (bime_export_installs.country_id = apps_flyer_networks.country_id) 
	AND (apps_flyer_network_names.id = apps_flyer_networks.apps_flyer_network_name_id))))
	LEFT JOIN mark_ups custom_markups ON (((apps_flyer_networks.id = custom_markups.apps_flyer_network_id) 
		AND (custom_markups.user_id = 40) 
		AND (custom_markups.effective_date = ( SELECT max(mark_ups.effective_date) AS max
FROM mark_ups
	WHERE ((mark_ups.apps_flyer_network_id = apps_flyer_networks.id) 
		AND (mark_ups.effective_date <= bime_export_installs.install_date) 
		AND (mark_ups.user_id = 40)))))))
	LEFT JOIN mark_ups default_markups ON (((default_markups.apps_flyer_network_id IS NULL) 
		AND (default_markups.user_id = 40) 
		AND (default_markups.effective_date = ( SELECT max(mark_ups.effective_date) AS max
		FROM mark_ups
	WHERE ((mark_ups.apps_flyer_network_id IS NULL) 
		AND (mark_ups.effective_date <= bime_export_installs.install_date) 
		AND (mark_ups.user_id = 40)))))))
	WHERE ((bime_export_installs.install_date >= '2016-09-01'::date) 
		AND (bime_export_installs.app_id = ANY (ARRAY[78])))) inner_select) xxx_mrs
	GROUP BY 
	xxx_mrs.app_id, 
	xxx_mrs.app_name, 
	xxx_mrs.network_name, 
	xxx_mrs.country_code, 
	xxx_mrs.install_date, 
	xxx_mrs.os,
	CASE
		WHEN ((xxx_mrs.network_type)::text = 'Incent'::text) THEN 'burst'::text
		WHEN ((xxx_mrs.network_publisher)::text ~~ '%burst%'::text) THEN 'burst'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%burst%'::text) THEN 'burst'::text
		WHEN ((xxx_mrs.network_publisher)::text ~~ '%Burst%'::text) THEN 'burst'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%Burst%'::text) THEN 'burst'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%Re-%'::text) THEN 'retargeting'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%Re_%'::text) THEN 'retargeting'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%gagement%'::text) THEN 'retargeting'::text
		WHEN ((xxx_mrs.network_sub_publisher)::text ~~ '%targeting%'::text) THEN 'retargeting'::text
		ELSE 'performance'::text
	END, 'media buy'::text) mrs_fin ON (((agg_events.media = mrs_fin.media) AND 
	((agg_events.country_code)::text = (mrs_fin.country_code)::text) AND 
	((agg_events.os)::text = (mrs_fin.os)::text) AND 
	(agg_events.app_id = mrs_fin.app_id) AND 
	(agg_events.date = mrs_fin.install_date) AND 
	(agg_events.campaign_type = mrs_fin.campaign_type) AND 
	((agg_events.media_source)::text = (mrs_fin.network_name)::text))))
GROUP BY agg_events.date,
 agg_events.app_id, 
 agg_events.media_source, 
 agg_events.app_name, 
 agg_events.country_code, 
 agg_events.os, 
 agg_events.event_name, 
 mrs_fin.installs, mrs_fin.spend, 
 agg_events.media, 
 agg_events.campaign_type
  ORDER BY agg_events.date, 
  agg_events.app_id, 
  agg_events.app_name, 
  agg_events.media_source, 
  agg_events.country_code, agg_events.os, 
  agg_events.event_name, agg_events.media, 
  agg_events.campaign_type;

