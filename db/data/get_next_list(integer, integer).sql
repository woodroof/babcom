-- drop function data.get_next_list(integer, integer);

create or replace function data.get_next_list(in_client_id integer, in_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_page_size integer;
  v_object_code text;
  v_actor_id integer := data.get_active_actor_id(in_client_id);
  v_last_object_id integer;
  v_content_value jsonb;
  v_content text[];
  v_client_subscription_id integer;
  v_object record;
  v_mini_card_function text;
  v_is_visible boolean;
  v_data jsonb;
  v_count integer := 0;
  v_has_more boolean := false;
  v_objects jsonb[] := array[]::jsonb[];
  v_max_index integer;
begin
  assert v_actor_id is not null;

  v_content_value := data.get_attribute_value(in_object_id, 'content', v_actor_id);
  if v_content_value is null then
    return null;
  end if;

  v_page_size := data.get_integer_param('page_size');
  assert v_page_size > 0;

  v_object_code := data.get_object_code(in_object_id);

  v_content = json.get_string_array(v_content_value);
  assert array_utils.is_unique(v_content);
  assert array_position(v_content, v_object_code) is null;

  select id
  into v_client_subscription_id
  from data.client_subscriptions
  where
    client_id = in_client_id and
    object_id = in_object_id;

  if v_client_subscription_id is null then
    raise exception 'Client % has no subscription for object %', client_id, object_id;
  end if;

  select max(index) + 1
  into v_max_index
  from data.client_subscription_objects
  where client_subscription_id = v_client_subscription_id;

  v_max_index := coalesce(v_max_index, 0);

  for v_object in
    select
      o.id id,
      row_number() over(order by c.num) as index
    from (
      select
        row_number() over() as num,
        value
      from unnest(v_content) s(value)) c
    join data.objects o
      on o.code = c.value
    where
      o.id not in (
        select object_id
        from data.client_subscription_objects
        where client_subscription_id = v_client_subscription_id)
    order by index
  loop
    if v_count = v_page_size then
      v_has_more := true;
      exit;
    end if;

    -- Вызываем функцию на получение миникарточки объекта, если есть
    v_mini_card_function := json.get_string_opt(data.get_attribute_value(v_object.id, 'mini_card_function'), null);

    if v_mini_card_function is not null then
      execute format('select %s($1, $2)', v_mini_card_function)
      using v_object.id, v_actor_id;
    end if;

    -- Проверяем видимость
    v_is_visible := json.get_boolean_opt(data.get_attribute_value(v_object.id, 'is_visible', v_actor_id), false);

    if v_is_visible then
      v_data := data.get_object(v_object.id, v_actor_id, 'mini', in_object_id);
    else
      v_data := null;
    end if;

    insert into data.client_subscription_objects(client_subscription_id, object_id, index, data)
    values(v_client_subscription_id, v_object.id, v_object.index + v_max_index, v_data);

    if not v_is_visible then
      continue;
    end if;

    v_objects := array_append(v_objects, v_data);

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('objects', to_jsonb(v_objects), 'has_more', v_has_more);
end;
$$
language plpgsql;
