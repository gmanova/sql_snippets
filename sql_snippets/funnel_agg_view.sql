 SELECT xxx.date,
    xxx.app_id,
    xxx.app_name,
    xxx.country_code,
    xxx.os,
    xxx.media,
    xxx.campaign_type,
    xxx.spend AS mrs_spend,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'impressions'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS impressions,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'clicks'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS clicks,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'installs'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS installs,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'signup (Unique users)'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS event_1,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'category_choose (Event counter)'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS event_2,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'order_location (Event counter)'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS event_3,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'dummyevent1'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS event_4,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'dummyevent2'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS event_5,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'dummyevent3'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS event_6,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'conversions'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS conversions,
    max(
        CASE
            WHEN ((xxx.event_name)::text = 'total_revenue'::text) THEN xxx.totals
            ELSE NULL::numeric
        END) AS total_revenue
   FROM xxx
  GROUP BY xxx.date, xxx.app_id, xxx.app_name, xxx.country_code, xxx.os, xxx.media, xxx.campaign_type, xxx.fin_installs, xxx.spend
  ORDER BY xxx.date, xxx.app_id, xxx.country_code, xxx.os, xxx.media, xxx.campaign_type, xxx.spend;