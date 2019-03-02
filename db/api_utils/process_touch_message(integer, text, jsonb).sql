-- drop function api_utils.process_touch_message(integer, text, jsonb);

create or replace function api_utils.process_touch_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_message, 'object_id');
  v_object_id integer := data.get_object_id(v_object_code);
  v_actor_id integer;
  v_touch_function text;
begin
  assert in_client_id is not null;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for share;

  if v_actor_id is null then
    raise exception 'Client % has no active actor', in_client_id;
  end if;

  -- Вызываем функцию смахивания уведомления, если есть
  v_touch_function := json.get_string_opt(data.get_attribute_value(v_object_id, 'touch_function'), null);

  if v_touch_function is not null then
    execute format('select %s($1, $2)', v_touch_function)
    using v_object_id, v_actor_id;
  end if;

  perform api_utils.create_ok_notification(in_client_id, in_request_id);
end;
$$
language plpgsql;
