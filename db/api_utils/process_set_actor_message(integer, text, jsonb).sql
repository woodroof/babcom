-- drop function api_utils.process_set_actor_message(integer, text, jsonb);

create or replace function api_utils.process_set_actor_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_actor_id integer := data.get_object_id(json.get_string(in_message, 'actor_id'));
  v_login_id integer;
  v_actor_exists boolean;
begin
  assert in_client_id is not null;

  select login_id
  into v_login_id
  from data.clients
  where id = in_client_id
  for update;

  if v_login_id is null then
    v_login_id := data.get_integer_param('default_login_id');
    assert v_login_id is not null;

    update data.clients
    set login_id = v_login_id
    where id = in_client_id;
  end if;

  select true
  into v_actor_exists
  from data.login_actors
  where
    login_id = v_login_id and
    actor_id = v_actor_id;

  if v_actor_exists is null then
    raise exception 'Actor % is not available for client %', v_actor_id, in_client_id;
  end if;

  update data.clients
  set actor_id = v_actor_id
  where id = in_client_id;

  delete from data.client_subscription_objects
  where client_subscription_id in (
    select id
    from data.client_subscriptions
    where client_id = in_client_id);

  delete from data.client_subscriptions
  where client_id = in_client_id;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language 'plpgsql';
