-- drop function data.change_object(integer, jsonb, integer);

create or replace function data.change_object(in_object_id integer, in_changes jsonb, in_actor_id integer default null::integer)
returns jsonb
volatile
as
$$
-- В параметре in_changes приходит массив объектов с полями id, value_object_id, value
-- Если присутствует, value_object_id меняет именно значение, задаваемое для указанного объекта
-- Если value отсутствует (именно отсутствует, а не равно jsonb 'null'!), то указанное значение удаляется, в противном случае - устанавливается

-- Возвращается массив с полями client_id и object
declare
  v_full_card_function text := json.get_string_opt(data.get_attribute_value(in_object_id, 'full_card_function'), null);
  v_client_id integer;
  v_actor_id integer;
  v_original_values jsonb := jsonb '{}';
  v_change record;
  v_new_data jsonb;
  v_template jsonb := data.get_param('template');
  v_attributes jsonb;
  v_actions jsonb;
  v_filtered_template jsonb;
  v_ret_val jsonb[];
begin
  perform json.get_object_array(in_changes);

  perform *
  from data.objects
  where id = in_object_id
  for update;

  -- todo: Обработать изменение списка

  -- Сохраним атрибуты и действия для всех клиентов, подписанных на получение изменений данного объекта
  for v_client_id in
  (
    select client_id
    from data.client_subscriptions
    where object_id = in_object_id
  )
  loop
    v_actor_id := data.get_active_actor_id(v_client_id);
    v_original_values :=
      v_original_values ||
      jsonb_build_object(
        v_client_id::text,
        data.get_object_data(in_object_id, v_actor_id, 'full', in_object_id));
  end loop;

  -- Меняем состояние объекта
  for v_change in
  (
    select
      json.get_integer(value, 'id') as id,
      json.get_integer_opt(value, 'value_object_id', null) as value_object_id,
      value->'value' as value
    from jsonb_array_elements(in_changes)
  )
  loop
    if v_change.value is null then
      perform data.delete_attribute_value(in_object_id, v_change.id, v_change.value_object_id, in_actor_id);
    else
      perform data.set_attribute_value(in_object_id, v_change.id, v_change.value, v_change.value_object_id, in_actor_id);
    end if;
  end loop;

  -- Берём новые атрибуты и действия для тех же клиентов
  for v_client_id in
  (
    select client_id
    from data.client_subscriptions
    where object_id = in_object_id
  )
  loop
    v_actor_id := data.get_active_actor_id(v_client_id);

    if v_full_card_function is not null then
      execute format('select %s($1, $2)', v_full_card_function)
      using in_object_id, v_actor_id;
    end if;

    v_new_data := data.get_object_data(in_object_id, v_actor_id, 'full', in_object_id);

    -- Сравниваем и при нахождении различий включаем в diff
    if v_new_data != v_original_values->(v_client_id::text) then
      v_attributes := json.get_object(v_new_data, 'attributes');
      v_actions := json.get_object_opt(v_new_data, 'actions', null);
      v_filtered_template := data.filter_template(v_template, v_attributes, v_actions);
      v_ret_val :=
        array_append(
          v_ret_val,
          jsonb_build_object(
            'client_id',
            v_client_id,
            'object',
            jsonb_build_object(
              'id',
              data.get_object_code(in_object_id),
              'attributes',
              v_attributes,
              'actions',
              coalesce(v_actions, jsonb '{}'),
              'template',
              v_filtered_template)));
    end if;
  end loop;

  return to_jsonb(v_ret_val);
end;
$$
language 'plpgsql';
