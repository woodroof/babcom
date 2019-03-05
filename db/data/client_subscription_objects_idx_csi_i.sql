-- drop index data.client_subscription_objects_idx_csi_i;

create index client_subscription_objects_idx_csi_i on data.client_subscription_objects(client_subscription_id, index) where (data is not null);
