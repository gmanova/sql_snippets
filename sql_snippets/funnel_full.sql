 SELECT fa.app_name_std,
    fa.date,
    fa.country_code,
    fa.os,
    fa.media,
    fa.campaign_type,
    sum(fa.mrs_spend) AS mrs_cost,
    sum(cp.cost) AS gac_fb_cost,
    sum(fa.impressions) AS mrs_impressions,
    sum(cp.impressions) AS gac_fb_impressions,
    sum(fa.clicks) AS mrs_clicks,
    sum(cp.clicks) AS gac_fb_clicks,
    sum(fa.installs) AS total_installs,
    sum(fa.event_1) AS event_1,
    sum(fa.event_2) AS event_2,
    sum(fa.event_3) AS event_3,
    sum(fa.event_4) AS event_4,
    sum(fa.event_5) AS event_5,
    sum(fa.event_6) AS event_6,
    sum(fa.conversions) AS total_conversions,
    sum(fa.total_revenue) AS total_revenue,
        CASE
            WHEN (fa.media = 'media buy'::text) THEN sum(fa.impressions)
            ELSE (sum(cp.impressions))::numeric
        END AS total_impressions,
        CASE
            WHEN (fa.media = 'media buy'::text) THEN sum(fa.clicks)
            ELSE (sum(cp.clicks))::numeric
        END AS total_clicks,
        CASE
            WHEN (fa.media = 'media buy'::text) THEN (sum(fa.mrs_spend))::double precision
            ELSE sum(cp.cost)
        END AS total_cost
   FROM (( SELECT
                CASE
                    WHEN (xxx_funnel_agg.app_id = ANY (ARRAY[69, 70])) THEN 'Fixit Joe'::text
                    ELSE NULL::text
                END AS app_name_std,
            (xxx_funnel_agg.date)::text AS date,
            xxx_funnel_agg.app_id,
            xxx_funnel_agg.app_name,
            xxx_funnel_agg.country_code,
            xxx_funnel_agg.os,
            xxx_funnel_agg.media,
            xxx_funnel_agg.campaign_type,
            xxx_funnel_agg.mrs_spend,
            xxx_funnel_agg.impressions,
            xxx_funnel_agg.clicks,
            xxx_funnel_agg.installs,
            xxx_funnel_agg.event_1,
            xxx_funnel_agg.event_2,
            xxx_funnel_agg.event_3,
            xxx_funnel_agg.event_4,
            xxx_funnel_agg.event_5,
            xxx_funnel_agg.event_6,
            xxx_funnel_agg.conversions,
            xxx_funnel_agg.total_revenue
           FROM xxx_funnel_agg) fa
     FULL JOIN ( SELECT google_campaign_performance.gac_app_name_std AS app_name_std,
            google_campaign_performance.gac_os AS os,
            google_campaign_performance.gac_main_source AS media,
            google_campaign_performance.gac_type AS campaign_type,
            google_campaign_performance.gac_country AS country_code,
            (google_campaign_performance.date)::text AS date,
            google_campaign_performance.costusd2 AS cost,
            google_campaign_performance.impressions,
            google_campaign_performance.clicks
           FROM google_campaign_performance
          WHERE ((google_campaign_performance.gac_app_name_std)::text = 'Fixit Joe'::text)
        UNION
         SELECT facebook_campaign_performance.fb_app_name_std AS app_name_std,
            facebook_campaign_performance.os,
            facebook_campaign_performance.main_source AS media,
            facebook_campaign_performance.campaign_type,
            facebook_campaign_performance.fb_country_ext AS country_code,
            (facebook_campaign_performance.date)::text AS date,
            facebook_campaign_performance.spend AS cost,
            facebook_campaign_performance.impressions,
            facebook_campaign_performance.clicks
           FROM facebook_campaign_performance
          WHERE ((facebook_campaign_performance.fb_app_name_std)::text = 'Fixit Joe'::text)) cp ON (((fa.date = cp.date) AND ((fa.os)::text = (cp.os)::text) AND (fa.app_name_std = (cp.app_name_std)::text) AND ((fa.country_code)::text = (cp.country_code)::text) AND (fa.media = (cp.media)::text) AND (fa.campaign_type = (cp.campaign_type)::text))))
  GROUP BY fa.app_name_std, fa.date, fa.country_code, fa.os, fa.media, fa.campaign_type
  ORDER BY fa.date;