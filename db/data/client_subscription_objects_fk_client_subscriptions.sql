alter table data.client_subscription_objects add constraint client_subscription_objects_fk_client_subscriptions
foreign key(client_subscription_id) references data.client_subscriptions(id);
