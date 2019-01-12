-- drop function api_utils.process_unsubscribe_message(integer, text, jsonb);

create or replace function api_utils.process_unsubscribe_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_id integer := data.get_object_id(json.get_string(in_message, 'object_id'));
  v_actor_id integer;
  v_subscription_id integer;
  v_object jsonb;
begin
  assert in_client_id is not null;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for update;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  perform 1
  from data.objects
  where id = v_object_id
  for update;

  select id
  into v_subscription_id
  from data.client_subscriptions
  where
    object_id = v_object_id and
    client_id = in_client_id;

  if v_subscription_id is null then
    raise exception 'Client % has no subscription to object %', in_client_id, v_object_id;
  end if;

  delete from data.client_subscription_objects
  where client_subscription_id = v_subscription_id;

  delete from data.client_subscriptions
  where id = v_subscription_id;

  perform api_utils.create_notification(in_client_id, in_request_id, 'ok', jsonb '{}');
end;
$$
language 'plpgsql';
