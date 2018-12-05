-- drop index data.attribute_values_nuidx_oi_ai;

create index attribute_values_nuidx_oi_ai on data.attribute_values(object_id, attribute_id);
