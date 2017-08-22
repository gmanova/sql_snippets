select
      app_id, 'unconverting_source' as campaign,'unconverting_source' as network_name, 'unconverting_source' as network_publisher, 'unconverting_source' as network_sub_publisher,countries.code as country_code, country_id , date as install_date, 4 as source_provider_id, null as installs , apps.name as app_name,  os,2 as network_type, null as cpi, spend,(CASE WHEN default_markups.markup_percent NOTNULL THEN default_markups.markup_percent else NULL END) as markup_percent
    from unconverting_sources
              inner join apps on
                  unconverting_sources.app_id = apps.id
              inner join countries on
                  unconverting_sources.country_id = countries.id
              left join mark_ups as default_markups on
                  (default_markups.apps_flyer_network_id ISNULL) and
                  default_markups.user_id = 11 and
                  default_markups.effective_date = (SELECT MAX(mark_ups.effective_date) FROM mark_ups WHERE (mark_ups.apps_flyer_network_id ISNULL)  and mark_ups.effective_date <= unconverting_sources.date and mark_ups.user_id = 11 )
    where
            date BETWEEN '2016-12-01 00:00:00' AND '2016-12-09 23:59:59'

    UNION

    select
          app_id, campaign, network_name, network_publisher, network_sub_publisher,country_code, country_id ,
          install_date, source_provider_id, installs , app_name,
          os,network_type,aggregated_cpi as cpi, coalesce((installs * aggregated_cpi),0) as spend, markup_percent
    from (
        select
            daily_installs.*,apps.name as app_name, os, network_type, (CASE WHEN sub_publisher_cpi NOTNULL THEN sub_publisher_cpi WHEN publisher_cpi NOTNULL THEN publisher_cpi WHEN cpi NOTNULL THEN cpi else NULL END) as aggregated_cpi,(CASE WHEN custom_markups.markup_percent NOTNULL THEN custom_markups.markup_percent WHEN default_markups.markup_percent NOTNULL THEN default_markups.markup_percent else NULL END) as markup_percent
              from
      (select
          app_id, campaign, network_name, network_publisher,network_sub_publisher, country_code,
          countries.id as country_id, date(install_time) as install_date,
          source_provider_id, COUNT(install_time) as installs
      from
            apps_flyer_data
            inner join apps_flyer_network_names on
                apps_flyer_network_names.name = apps_flyer_data.network_name
            inner join countries on
                apps_flyer_data.country_code = countries.code
      where
            install_time BETWEEN '2016-12-01 00:00:00' AND '2016-12-09 23:59:59'

      group by
            install_date, source_provider_id, app_id, campaign, network_name, network_publisher,network_sub_publisher, country_code,country_id
      ) as daily_installs

              inner join apps on
                  daily_installs.app_id = apps.id
              inner join apps_flyer_network_names on
                  apps_flyer_network_names.name = daily_installs.network_name
              inner join apps_flyer_networks on
                  apps_flyer_networks.app_id = daily_installs.app_id and
                  apps_flyer_networks.apps_flyer_network_name_id = apps_flyer_network_names.id and
                  apps_flyer_networks.country_id = daily_installs.country_id
              left join apps_flyer_network_attributes on
                  apps_flyer_networks.id = apps_flyer_network_attributes.apps_flyer_network_id and
                  apps_flyer_network_attributes.effective_date = (SELECT MAX(apps_flyer_network_attributes.effective_date) FROM apps_flyer_network_attributes WHERE apps_flyer_network_attributes.apps_flyer_network_id = apps_flyer_networks.id and apps_flyer_network_attributes.effective_date <= daily_installs.install_date )
              left join apps_flyer_network_publishers on
                  apps_flyer_network_publishers.apps_flyer_network_id = apps_flyer_networks.id and
                  apps_flyer_network_publishers.name =  daily_installs.network_publisher
              left join apps_flyer_network_publisher_attributes on
                  apps_flyer_network_publishers.id = apps_flyer_network_publisher_attributes.apps_flyer_network_publisher_id and
                  apps_flyer_network_publisher_attributes.effective_date = (SELECT MAX(apps_flyer_network_publisher_attributes.effective_date) FROM apps_flyer_network_publisher_attributes WHERE apps_flyer_network_publisher_attributes.apps_flyer_network_publisher_id = apps_flyer_network_publishers.id and apps_flyer_network_publisher_attributes.effective_date <= daily_installs.install_date )
              left join apps_flyer_network_sub_publishers on
                  apps_flyer_network_sub_publishers.apps_flyer_network_publisher_id = apps_flyer_network_publishers.id and
                  apps_flyer_network_sub_publishers.name =  daily_installs.network_sub_publisher
              left join apps_flyer_network_sub_publisher_attributes on
                  apps_flyer_network_sub_publishers.id = apps_flyer_network_sub_publisher_attributes.apps_flyer_network_sub_publisher_id and
                  apps_flyer_network_sub_publisher_attributes.effective_date = (SELECT MAX(apps_flyer_network_sub_publisher_attributes.effective_date) FROM apps_flyer_network_sub_publisher_attributes WHERE apps_flyer_network_sub_publisher_attributes.apps_flyer_network_sub_publisher_id = apps_flyer_network_sub_publishers.id and apps_flyer_network_sub_publisher_attributes.effective_date <= daily_installs.install_date )
              left join mark_ups as custom_markups on
                  (apps_flyer_networks.id = custom_markups.apps_flyer_network_id) and
                  custom_markups.user_id = 11 and
                  custom_markups.effective_date = (SELECT MAX(mark_ups.effective_date) FROM mark_ups WHERE (mark_ups.apps_flyer_network_id = apps_flyer_networks.id) and mark_ups.effective_date <= daily_installs.install_date and mark_ups.user_id = 11 )
              left join mark_ups as default_markups on
                  (default_markups.apps_flyer_network_id ISNULL) and
                  default_markups.user_id = 11 and
                  default_markups.effective_date = (SELECT MAX(mark_ups.effective_date) FROM mark_ups WHERE (mark_ups.apps_flyer_network_id ISNULL)  and mark_ups.effective_date <= daily_installs.install_date and mark_ups.user_id = 11 )
      ) as finance_data
      order by install_date desc