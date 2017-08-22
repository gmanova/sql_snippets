 SELECT xxx_ios_funnel.date,
    xxx_ios_funnel.app_id,
    xxx_ios_funnel.app_name,
    xxx_ios_funnel.media_source AS network_name,
    xxx_ios_funnel.country_code,
    xxx_ios_funnel.os,
    xxx_ios_funnel.media,
    xxx_ios_funnel.campaign_type,
    xxx_ios_funnel.spend AS mrs_spend,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = 'impressions'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS impressions,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = 'clicks'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS clicks,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = 'installs'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS installs,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = 'created account (Unique users)'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS event_1,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = '14 day trial started (Unique users)'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS event_2,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = '1 week pass started (Unique users)'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS event_3,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = 'subscription started (Unique users)'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS event_4,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = 'started workout (Event counter)'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS event_5,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = 'finished workout (Event counter)'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS event_6,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = 'conversions'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS conversions,
    max(
        CASE
            WHEN ((xxx_ios_funnel.event_name)::text = 'total_revenue'::text) THEN xxx_ios_funnel.totals
            ELSE NULL::numeric
        END) AS total_revenue
   FROM xxx_ios_funnel
  GROUP BY xxx_ios_funnel.date, xxx_ios_funnel.app_id, xxx_ios_funnel.app_name, xxx_ios_funnel.media_source, xxx_ios_funnel.country_code, xxx_ios_funnel.os, xxx_ios_funnel.media, xxx_ios_funnel.campaign_type, xxx_ios_funnel.fin_installs, xxx_ios_funnel.spend
  ORDER BY xxx_ios_funnel.date, xxx_ios_funnel.app_id, xxx_ios_funnel.media_source, xxx_ios_funnel.country_code, xxx_ios_funnel.os, xxx_ios_funnel.media, xxx_ios_funnel.campaign_type, xxx_ios_funnel.spend;