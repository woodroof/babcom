-- drop index data.notifications_idx_connection_id;

create index notifications_idx_connection_id on data.notifications(connection_id);
