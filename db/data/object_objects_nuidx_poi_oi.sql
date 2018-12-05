-- drop index data.object_objects_nuidx_poi_oi;

create index object_objects_nuidx_poi_oi on data.object_objects(parent_object_id, object_id);
