-- drop index data.object_objects_idx_loi_goi;

create unique index object_objects_idx_loi_goi on data.object_objects(least(parent_object_id, object_id), greatest(parent_object_id, object_id)) where (intermediate_object_ids is null);
