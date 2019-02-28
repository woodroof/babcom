-- drop function data.change_objects(jsonb);

create or replace function data.change_objects(in_changes jsonb)
returns jsonb
volatile
as
$$
-- Формат in_changes: [{"id": <object_id>, "changes": <changes>, "add_groups": [<group id>, ...], "remove_groups": [<group id>, ...]}]
declare
  v_object record;
  v_object_id integer;
  v_changes jsonb := jsonb '[]';

  v_ids integer[] := array[]::integer[];

  v_subscriptions jsonb := jsonb '[]';
  v_subscription_objects jsonb := jsonb '[]';
  v_actor_subscriptions jsonb := jsonb '[]';

  v_ret_val jsonb := jsonb '[]';
begin
  for v_object in
  (
    select
      json.get_integer(value, 'id') id,
      value->'changes' as changes,
      coalesce(value->'add_groups', jsonb 'null') as add_groups,
      coalesce(value->'remove_groups', jsonb 'null') as remove_groups
    from jsonb_array_elements(in_changes)
  )
  loop
    declare
      v_change jsonb;
      v_filtered_changes jsonb := data.filter_changes(v_object.id, data.preprocess_changes_with_codes(v_object.changes));
    begin
      if
        v_filtered_changes = jsonb '[]' and
        v_object.add_groups in (jsonb 'null', jsonb '[]') and
        v_object.remove_groups in (jsonb 'null', jsonb '[]')
      then
        continue;
      end if;

      v_ids := array_append(v_ids, v_object.id);

      v_change := jsonb_build_object('id', v_object.id);
      if v_filtered_changes != jsonb '[]' then
        v_change := v_change || jsonb_build_object('changes', v_filtered_changes);
      end if;
      if v_object.add_groups not in (jsonb 'null', jsonb '[]') then
        v_change := v_change || jsonb_build_object('add_groups', v_object.add_groups);
      end if;
      if v_object.remove_groups not in (jsonb 'null', jsonb '[]') then
        v_change := v_change || jsonb_build_object('remove_groups', v_object.remove_groups);
      end if;

      v_changes := v_changes || v_change;
    end;
  end loop;

  if v_changes = jsonb '[]' then
    return jsonb '[]';
  end if;

  for v_object_id in
  (
    select value
    from unnest(v_ids) a(value)
  )
  loop
    -- Сохраним атрибуты и действия для всех клиентов, подписанных на получение изменений объектов
    declare
      v_ids integer[];
    begin
      select array_agg(id)
      into v_ids
      from data.client_subscriptions
      where object_id = v_object_id;

      v_subscriptions := v_subscriptions || data_internal.save_state(v_ids, null, data.get_attribute_id('independent_from_object_list_elements'));
    end;

    -- Сохраним состояние миникарточек в списках, в которые входит данный объект
    declare
      v_minicard_state jsonb;
    begin
      v_minicard_state := data_internal.save_minicard_state(v_object_id, v_ids);
      if v_minicard_state != jsonb '[]' then
        v_subscription_objects := v_subscription_objects || jsonb_build_object('object_id', v_object_id, 'state', v_minicard_state);
      end if;
    end;

    -- Если изменяется актор, то сохраняем подписки его клиентов
    declare
      v_ids integer[];
    begin
      select array_agg(id)
      into v_ids
      from data.client_subscriptions
      where
        client_id in (
          select id
          from data.clients
          where actor_id = v_object_id) and
        object_id not in (
          select value
          from unnest(v_ids) a(value));

      v_actor_subscriptions := v_actor_subscriptions || data_internal.save_state(v_ids, v_ids, data.get_attribute_id('independent_from_actor_list_elements'));
    end;
  end loop;

  for v_object in
  (
    select
      json.get_integer(value, 'id') id,
      json.get_object_array_opt(value, 'changes', null) changes,
      json.get_integer_array_opt(value, 'add_groups', null) add_groups,
      json.get_integer_array_opt(value, 'remove_groups', null) remove_groups
    from jsonb_array_elements(v_changes)
  )
  loop
    -- Меняем состояние объекта
    declare
      v_change record;
    begin
      for v_change in
      (
        select
          json.get_integer(value, 'id') as attribute_id,
          json.get_integer_opt(value, 'value_object_id', null) as value_object_id,
          value->'value' as value
        from jsonb_array_elements(v_object.changes)
      )
      loop
        if v_change.value is null then
          perform data.delete_attribute_value(
            v_object.id,
            v_change.attribute_id,
            v_change.value_object_id);
        else
          perform data.set_attribute_value(
            v_object.id,
            v_change.attribute_id,
            v_change.value,
            v_change.value_object_id);
        end if;
      end loop;
    end;

    -- Меняем группы объекта
    declare
      v_parent_object_id integer;
    begin
      for v_parent_object_id in
      (
        select value
        from unnest(v_object.add_groups) a(value)
      )
      loop
        perform data.add_object_to_object(v_object.id, v_parent_object_id);
      end loop;

      for v_parent_object_id in
      (
        select value
        from unnest(v_object.remove_groups) a(value)
      )
      loop
        perform data.remove_object_from_object(v_object.id, v_parent_object_id);
      end loop;
    end;
  end loop;

  -- Берём новые атрибуты и действия для тех же клиентов
  v_ret_val := v_ret_val || data_internal.process_saved_state(v_subscriptions);

  -- Берём новые миникарточки для тех же списков
  declare
    v_subscription_object record;
  begin
    for v_subscription_object in
    (
      select json.get_integer(value, 'object_id') object_id, json.get_object_array(value, 'state') state
      from jsonb_array_elements(v_subscription_objects)
    )
    loop
      v_ret_val := v_ret_val || data_internal.process_saved_minicard_state(v_subscription_object.object_id, v_subscription_object.state);
    end loop;
  end;

  -- И обрабатываем изменения подписок клиентов изменённого актора
  v_ret_val := v_ret_val || data_internal.process_saved_state(v_actor_subscriptions);

  return v_ret_val;
end;
$$
language plpgsql;
