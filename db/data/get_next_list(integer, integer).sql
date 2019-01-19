-- drop function data.get_next_list(integer, integer);

create or replace function data.get_next_list(in_client_id integer, in_object_id integer)
returns jsonb
volatile
as
$$
declare
  v_page_size integer := data.get_integer_param('page_size');
  v_actor_id integer;
  v_last_object_id integer;
  v_content text[];
  v_content_length integer;
  v_client_subscription_id integer;
  v_object record;
  v_mini_card_function text;
  v_is_visible boolean;
  v_count integer := 0;
  v_has_more boolean := false;
  v_objects jsonb[] := array[]::jsonb[];
begin
  assert data.is_instance(in_object_id);
  assert v_page_size > 0;

  select actor_id
  into v_actor_id
  from data.clients
  where id = in_client_id
  for update;

  assert v_actor_id is not null;

  v_content = json.get_string_array(data.get_attribute_value(in_object_id, 'content', v_actor_id));
  assert array_utils.is_unique(v_content);

  v_content_length := array_length(v_content, 1);

  select id
  into v_client_subscription_id
  from data.client_subscriptions
  where
    client_id = in_client_id and
    object_id = in_object_id;

  if v_client_subscription_id is null then
    raise exception 'Client % has no subscription for object %', client_id, object_id;
  end if;

  for v_object in
    select
      o.id id,
      c.num as index
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
    order by c.num
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
    v_is_visible := json.get_boolean_opt(data.get_attribute_value(v_object.id, 'is_visible', v_actor_id), null);
    if v_is_visible is null or v_is_visible is false then
      insert into data.client_subscription_objects(client_subscription_id, object_id, index, is_visible)
      values(v_client_subscription_id, v_object.id, v_object.index, false);

      continue;
    end if;

    v_objects := array_append(v_objects, data.get_object(v_object.id, v_actor_id, 'mini', in_object_id));

    v_count := v_count + 1;
  end loop;

  return jsonb_build_object('objects', to_jsonb(v_objects), 'has_more', v_has_more);
end;
$$
language 'plpgsql';
