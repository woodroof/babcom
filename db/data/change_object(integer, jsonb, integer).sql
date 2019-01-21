-- drop function data.change_object(integer, jsonb, integer);

create or replace function data.change_object(in_object_id integer, in_changes jsonb, in_actor_id integer default null::integer)
returns jsonb
volatile
as
$$
-- В параметре in_changes приходит массив объектов с полями id, value_object_id, value
-- Если присутствует, value_object_id меняет именно значение, задаваемое для указанного объекта
-- Если value отсутствует (именно отсутствует, а не равно jsonb 'null'!), то указанное значение удаляется, в противном случае - устанавливается

-- Возвращается массив объектов с полями client_id, object и list_changes, поля object и list_changes могут отсутствовать
declare
  v_changes jsonb := data.filter_changes(in_object_id, in_changes);
  v_object_code text;
  v_full_card_function text;
  v_mini_card_function text;
  v_client_id integer;
  v_actor_id integer;
  v_original_values jsonb := jsonb '{}';
  v_list record;
  v_original_list_value jsonb;
  v_original_list_values jsonb := jsonb '{}';
  v_change record;
  v_list_changed boolean := false;
  v_subscription record;
  v_content_attribute_id integer;
  v_new_data jsonb;
  v_default_template jsonb;
  v_attributes jsonb;
  v_actions jsonb;
  v_object_template jsonb;
  v_object jsonb;
  v_list_changes jsonb;
  v_ret_val_element jsonb;
  v_ret_val jsonb[];
begin
  assert in_actor_id is null or data.is_instance(in_actor_id);

  if v_changes = jsonb '[]' then
    return jsonb '[]';
  end if;

  v_object_code := data.get_object_code(in_object_id);
  v_full_card_function := json.get_string_opt(data.get_attribute_value(in_object_id, 'full_card_function'), null);
  v_mini_card_function := json.get_string_opt(data.get_attribute_value(in_object_id, 'mini_card_function'), null);
  v_content_attribute_id := data.get_attribute_id('content');
  v_default_template := data.get_param('template');

  perform *
  from data.objects
  where id = in_object_id
  for update;

  -- Сохраним атрибуты и действия для всех клиентов, подписанных на получение изменений данного объекта
  for v_client_id in
  (
    select client_id
    from data.client_subscriptions
    where object_id = in_object_id
  )
  loop
    v_actor_id := data.get_active_actor_id(v_client_id);

    -- Невидимые объекты должны были пройти через change_object, подписки были бы удалены
    assert json.get_boolean(data.get_attribute_value(in_object_id, 'is_visible', v_actor_id));

    v_original_values :=
      v_original_values ||
      jsonb_build_object(
        v_client_id::text,
        data.get_object_data(in_object_id, v_actor_id, 'full', in_object_id));
  end loop;

  -- Сохраним состояние миникарточек в списках, в которые входит данный объект
  for v_list in
  (
    select
      cso.id,
      cs.client_id,
      cs.object_id,
      cso.is_visible,
      cso.index
    from data.client_subscription_objects cso
    join data.client_subscriptions cs
      on cs.id = cso.client_subscription_id
    where cso.object_id = in_object_id
  )
  loop
    v_actor_id := data.get_active_actor_id(v_list.client_id);

    v_original_list_value :=
      jsonb_build_object(
        v_list.id::text,
        jsonb_build_object(
          'client_id',
          v_list.client_id,
          'object_id',
          v_list.object_id,
          'is_visible',
          v_list.is_visible,
          'index',
          v_list.index));

    if v_list.is_visible then
      -- Изменения невидимых объектов должны были пройти через change_object, атрибут в таблице client_subscription_objects был бы изменён
      assert json.get_boolean(data.get_attribute_value(v_list.object_id, 'is_visible', v_actor_id));

      v_original_list_value :=
        v_original_list_value ||
        jsonb_build_object('data', data.get_object(in_object_id, v_actor_id, 'mini', v_list.object_id));
    end if;

    v_original_list_values := v_original_list_values || v_original_list_value;
  end loop;

  -- Меняем состояние объекта
  for v_change in
  (
    select
      json.get_integer(value, 'id') as id,
      json.get_integer_opt(value, 'value_object_id', null) as value_object_id,
      value->'value' as value
    from jsonb_array_elements(v_changes)
  )
  loop
    if v_change.id = v_content_attribute_id then
      v_list_changed := true;
    end if;

    if v_change.value is null then
      perform data.delete_attribute_value(in_object_id, v_change.id, v_change.value_object_id, in_actor_id);
    else
      perform data.set_attribute_value(in_object_id, v_change.id, v_change.value, v_change.value_object_id, in_actor_id);
    end if;
  end loop;

  -- Берём новые атрибуты и действия для тех же клиентов
  for v_subscription in
  (
    select id, client_id
    from data.client_subscriptions
    where object_id = in_object_id
  )
  loop
    v_actor_id := data.get_active_actor_id(v_subscription.client_id);

    if v_full_card_function is not null then
      execute format('select %s($1, $2)', v_full_card_function)
      using in_object_id, v_actor_id;
    end if;

    -- Объект стал невидимым - отправляем специальный diff и вычищаем подписки
    if not json.get_boolean_opt(data.get_attribute_value(in_object_id, 'is_visible', v_actor_id), false) then
      v_ret_val := array_append(v_ret_val, jsonb_build_object('object_id', v_object_code, 'object', jsonb 'null'));

      delete from data.client_subscription_objects
      where client_subscription_id = v_subscription.id;

      delete from data.client_subscriptions
      where id = v_subscription.id;

      continue;
    end if;

    v_new_data := data.get_object_data(in_object_id, v_actor_id, 'full', in_object_id);

    v_object := null;
    v_list_changes := null;

    -- Сравниваем и при нахождении различий включаем в diff
    if v_new_data != v_original_values->(v_subscription.client_id::text) then
      v_attributes := json.get_object(v_new_data, 'attributes');
      v_actions := json.get_object_opt(v_new_data, 'actions', null);

      v_object_template := data.get_attribute_value(in_object_id, 'template', v_actor_id);
      if v_object_template is null then
        v_object_template := v_default_template;
      end if;
      v_object_template := data.filter_template(v_object_template, v_attributes, v_actions);

      v_object :=
        jsonb_build_object(
          'id',
          v_object_code,
          'attributes',
          v_attributes,
          'actions',
          coalesce(v_actions, jsonb '{}'),
          'template',
          v_object_template);
    end if;

    if v_list_changed then
      -- todo изменение списка, арр!
    end if;

    if v_object is not null or v_list_changes is not null then
      v_ret_val_element := jsonb_build_object('client_id', v_subscription.client_id);

      if v_object is not null then
        v_ret_val_element := v_ret_val_element || jsonb_build_object('object', v_object);
      end if;

      if v_list_changes is not null then
        v_ret_val_element := v_ret_val_element || jsonb_build_object('list_changes', v_list_changes);
      end if;

      v_ret_val := array_append(v_ret_val, v_ret_val_element);
    end if;
  end loop;

  -- Берём новые миникарточки для тех же списков
  for v_list in
  (
    select
      cso.id,
      cs.client_id,
      cs.object_id,
      cso.is_visible,
      cso.index
    from data.client_subscription_objects cso
    join data.client_subscriptions cs
      on cs.id = cso.client_subscription_id
    where cso.object_id = in_object_id
  )
  loop
    v_actor_id := data.get_active_actor_id(v_list.client_id);

    if v_mini_card_function is not null then
      execute format('select %s($1, $2)', v_mini_card_function)
      using in_object_id, v_actor_id;
    end if;

    -- todo и далее
  end loop;

  return to_jsonb(v_ret_val);
end;
$$
language plpgsql;
