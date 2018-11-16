-- drop index data.object_objects_idx_poi_oi;

create unique index object_objects_idx_poi_oi on data.object_objects(parent_object_id, object_id) where (intermediate_object_ids is null);
