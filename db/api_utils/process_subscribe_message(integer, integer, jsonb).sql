-- drop function api_utils.process_subscribe_message(integer, integer, jsonb);

create or replace function api_utils.process_subscribe_message(in_client_id integer, in_request_id integer, in_message jsonb)
returns void
volatile
as
$$
declare
  v_object_id integer := data.get_object_id(json.get_string(in_message, 'object_id'));
  v_actor_id integer;
  v_visited_object_ids integer[];
  v_full_card_function text;
  v_redirect_object_id integer;
  v_object_exists boolean;
  v_is_visible boolean;
  v_subscription_exists boolean;
  v_object jsonb;
begin
  assert in_client_id is not null;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for update;

  if v_actor_id is null then
    raise exception 'Client %s has no active actor', in_client_id;
  end if;

  perform 1
  from data.objects
  where object_id = v_object_id
  for update;

  loop
    if v_visited_object_ids is not null and array_position(v_visited_object_ids, v_object_id) is not null then
      raise exception 'Redirection cycle detected for object %', v_object_id;
    end if;

    v_visited_object_ids := array_append(v_visited_object_ids, v_object_id);

    -- Вызываем функцию на получение полной карточки объекта, если есть
    v_full_card_function := json.get_string_opt(data.get_attribute_value(v_object_id, 'full_card_function'), null);

    if v_full_card_function is not null then
      execute format('select %s($1, $2)', v_full_card_function)
      using v_object_id, v_actor_id;
    end if;

    -- Смотрим на наличие redirect'а
    v_redirect_object_id := json.get_integer_opt(data.get_attribute_value(v_object_id, 'redirect', v_actor_id), null);
    if v_redirect_object_id is not null then
      v_object_id := v_redirect_object_id;

      -- Проверяем наличие объекта
      select true
      into v_object_exists
      from data.objects
      where id = v_object_id
      for update;

      if v_object_exists is null then
        raise exception 'Object % not found', v_object_id;
      end if;

      continue;
    end if;

    -- Проверяем видимость
    v_is_visible := json.get_boolean_opt(data.get_attribute_value(v_object_id, 'is_visible', in_actor_id), null);
    if v_is_visible is null then
      v_object_id := data.get_integer_param('not_found_object_id');
      continue;
    end if;
  end loop;

  select true
  into v_subscription_exists
  from data.client_subscriptions
  where
    object_id = v_object_id and
    client_id = in_client_id;

  if v_subscriptions_exists is true then
    raise exception 'Can''t create second subscription to object %s', v_object_id;
  end if;

  insert into data.client_subscriptions(client_id, object_id)
  values(in_client_id, v_object_id);

  v_object := data.get_object(v_object_id, v_actor_id, 'full', v_object_id);

  perform api_utils.create_notification(in_client_id, in_request_id, 'object', v_object);
end;
$$
language 'plpgsql';
