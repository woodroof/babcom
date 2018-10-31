-- drop index data.notifications_idx_client_id;

create index notifications_idx_client_id on data.notifications(client_id);
