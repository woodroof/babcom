-- drop function api_utils.process_subscribe_message(integer, text, jsonb);

create or replace function api_utils.process_subscribe_message(in_client_id integer, in_request_id text, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_code text := json.get_string(in_message, 'object_id');
  v_actor_id integer;
  v_object_id integer;
  v_full_card_function text;
  v_redirect_object_id integer;
  v_object_exists boolean;
  v_is_visible boolean;
  v_subscription_exists boolean;
  v_object jsonb;
  v_list jsonb;
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

  select id
  into v_object_id
  from data.objects
  where
    code = v_object_code and
    type = 'instance';

  if v_object_id is null then
    perform data.log('warning', format('Attempt to subscribe for non-existing object'' changes with code %s. Redirecting to 404.', v_object_code));
    perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(data.get_integer_param('not_found_object_id')));
    return;
  end if;

  -- Вызываем функцию на получение полной карточки объекта, если есть
  v_full_card_function := json.get_string_opt(data.get_attribute_value(v_object_id, 'full_card_function'), null);

  if v_full_card_function is not null then
    execute format('select %s($1, $2)', v_full_card_function)
    using v_object_id, v_actor_id;
  end if;

  -- Смотрим на наличие redirect'а
  v_redirect_object_id := json.get_integer_opt(data.get_attribute_value(v_object_id, 'redirect', v_actor_id), null);
  if v_redirect_object_id is not null then
    perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(v_redirect_object_id));
    return;
  end if;

  -- Проверяем видимость
  v_is_visible := json.get_boolean_opt(data.get_attribute_value(v_object_id, 'is_visible', v_actor_id), false);
  if not v_is_visible then
    perform api_utils.create_open_object_action_notification(in_client_id, in_request_id, data.get_object_code(data.get_integer_param('not_found_object_id')));
    return;
  end if;

  select true
  into v_subscription_exists
  from data.client_subscriptions
  where
    object_id = v_object_id and
    client_id = in_client_id;

  if v_subscription_exists then
    raise exception 'Can''t create second subscription to object %', v_object_id;
  end if;

  v_object := data.get_object(v_object_id, v_actor_id, 'full', v_object_id);

  insert into data.client_subscriptions(client_id, object_id, data)
  values(in_client_id, v_object_id, v_object);

  -- Получаем список, если есть
  v_list := data.get_next_list(in_client_id, v_object_id);
  if v_list is not null then
    perform api_utils.create_notification(in_client_id, in_request_id, 'object', jsonb_build_object('object', v_object, 'list', v_list));
  else
    perform api_utils.create_notification(in_client_id, in_request_id, 'object', jsonb_build_object('object', v_object));
  end if;
end;
$$
language plpgsql;
